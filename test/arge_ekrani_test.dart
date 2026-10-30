@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/dil/icerik.dart';
import 'package:voidspace3/dil/metin.dart';
import 'package:voidspace3/hangar/arge_karti.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/menu_cells.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace3/hangar/unvan_karti.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ARGE AĞACININ EKRANI (05.7, borç defteri B33).
///
/// ArGe uzun süre yalnız protokolden kullanılabiliyordu: çekirdek düğümü
/// veriyor, sunucu `arge_al` / `arge_sifirla` kabul ediyor, σ kayıyor — ama
/// hiçbir ekran ağacı çizmiyordu. Burada ölçülen dört şey ekranın var
/// olmasının gerekçesi: dallar ve ZİNCİR görünüyor, kilitli düğüm alınmıyor,
/// puan sayacı çekirdeğin saydığını yazıyor, sıfırlama çalışıyor.
///
/// Kararlar ekranda DEĞİL: her dokunuş sunucuya bir niyet. O yüzden testler
/// [ArGeKarti]'nın geri çağrılarını dinliyor — "sunucuya ne söylendi" sorusu,
/// "istemci ne hesapladı" sorusundan başka bir soru.
void main() {
  /// Sunucunun `_hangarJson`'u ile aynı şemada bir görünüm.
  ///
  /// `Hangar.toJson()` GERÇEK üretici: elle yazılmış bir harita, alanın adı
  /// değişse bile geçmeye devam eder ve test yeşilken ekran boş kalırdı.
  HangarView gorunum({int seviye = 6, Set<String> alinan = const {}}) =>
      HangarView.fromJson({
        ...Hangar(accountId: 'a', argeDugumleri: alinan).toJson(),
        'effective': ServerHangarState.effectiveOf(ShipStats.bastion),
        'br': 4200.0,
        'seviye': seviye,
        'unvan': 33,
        'unvanAdi': 'Bishop IV',
      });

  /// Ağacı tek başına kurar; alınan düğüm ve sıfırlama istekleri kaydediliyor.
  Future<(List<String>, List<int>)> agac(
    WidgetTester tester, {
    int seviye = 6,
    Set<String> alinan = const {},
    Size boy = const Size(1280, 720),
  }) async {
    tester.view
      ..physicalSize = boy
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final alinanlar = <String>[];
    final sifirlamalar = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Stack(
            children: [
              ArGeKarti(
                hangar: gorunum(seviye: seviye, alinan: alinan),
                metrics: MenuMetrics(boy),
                onAl: alinanlar.add,
                onSifirla: () => sifirlamalar.add(1),
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return (alinanlar, sifirlamalar);
  }

  // KARAR 05.7 s2
  testWidgets('ağaç çiziliyor: her dal, her düğüm ve zincirin sırası', (
    tester,
  ) async {
    await agac(tester);

    // Dolu her dal başlıklı; boş dal (izin) çizilmiyor — olmayan bir yolu
    // göstermek, oyuncuya ulaşamayacağı bir hedef vaat etmek olurdu.
    final dallar = ArGeKarti.dallar;
    expect(dallar, isNotEmpty);
    for (final dal in dallar) {
      expect(find.byKey(argeDaliKey(dal)), findsOneWidget, reason: dal.name);
      expect(
        find.text(menuUpper(argeDaliAdi(dal, Dil.turkce), Dil.turkce)),
        findsOneWidget,
      );
    }
    // İLAN EDİLEN HER DALIN DÜĞÜMÜ VAR.
    //
    // Eskiden tersi sınanıyordu: boş bir dal çizilmesin diye. O gün enum'da
    // düğümsüz bir `izin` dalı duruyordu ve ekran onu gizliyordu. Dal
    // kaldırıldı (05.7 s2) ve sınama yön değiştirdi — gizlemek yerine BOŞ
    // DAL OLMAMASI. Ekranın bir dalı saklaması, ağacın şeklinin koddan değil
    // arayüzden okunması demekti.
    expect(
      dallar.toSet(),
      ArGeDali.values.toSet(),
      reason: 'düğümü olmayan dal ilan edilmiş',
    );

    // Her düğüm ekranda ve ADIYLA — kimlikle değil.
    for (final dugum in ArGe.hepsi) {
      expect(find.byKey(argeDugumKey(dugum.id)), findsOneWidget);
      expect(
        find.text(argeDugumAdi(dugum, Dil.turkce)),
        findsOneWidget,
        reason: dugum.id,
      );
    }

    // İzin düğümü SAYI değil sonucunu yazıyor (05.7): "Ek Yuva" tek başına
    // neyin ek olduğunu söylemiyor.
    expect(
      find.text(argeIzniAciklamasi(ArGeIzni.filoYuvasi, Dil.turkce)),
      findsOneWidget,
    );
  });

  // KARAR 05.7 s2
  testWidgets('ZİNCİR: önkoşulsuz düğüme dokunmak hiçbir şey yollamıyor', (
    tester,
  ) async {
    final (alinanlar, _) = await agac(tester);

    // Dalın kökü açık, ikinci düğüm kapalı: puan yeter ama zincir kopuk.
    await tester.tap(find.byKey(argeDugumKey('filo-2')));
    await tester.pump();
    expect(alinanlar, isEmpty, reason: 'kilitli düğüm sunucuya gitti');
    expect(find.text(Metin.argeOncekiGerek(Dil.turkce)), findsWidgets);

    await tester.tap(find.byKey(argeDugumKey('filo-1')));
    await tester.pump();
    expect(alinanlar, ['filo-1']);
  });

  // KARAR 05.7 s2
  testWidgets('kilidin SEBEBİ yazılıyor: zincir mi, puan mı', (tester) async {
    // Sessiz ret, oyuncunun kuralı öğrenemeden vazgeçmesi demek. Seviye bir,
    // kök alınmış: ikinci düğümün önkoşulu tamam ama puanı yok.
    await agac(tester, seviye: 1, alinan: {'filo-1'});

    expect(find.text(Metin.argeAlindi(Dil.turkce)), findsOneWidget);
    expect(find.text(Metin.argePuanYetmiyor(Dil.turkce)), findsWidgets);
    // Zincir kopuk olan düğümler yine kendi sebebini yazıyor.
    expect(find.text(Metin.argeOncekiGerek(Dil.turkce)), findsWidgets);
  });

  // KARAR 05.7 s2 · KARAR 10.1 s1
  testWidgets('puan sayacı ÇEKİRDEĞİN saydığını yazıyor', (tester) async {
    // Seviye altı → altı puan (seviye başına bir). Alınan iki düğüm 1 + 2 = 3.
    await agac(tester, alinan: {'filo-1', 'filo-2'});

    final gorunumu = gorunum(alinan: {'filo-1', 'filo-2'});
    expect(gorunumu.argePuani, ArGe.puanFor(6));
    expect(gorunumu.argeHarcanan, ArGe.harcanan({'filo-1', 'filo-2'}));
    expect(gorunumu.argeKalan, 3);

    expect(
      find.text(
        Metin.argePuanSayaci.bicim(Dil.turkce, {
          'harcanan': '3',
          'toplam': '6',
        }),
      ),
      findsOneWidget,
    );
    expect(
      find.text(Metin.argeKalanPuan.bicim(Dil.turkce, {'n': '3'})),
      findsOneWidget,
    );
  });

  // KARAR 05.7 s2
  testWidgets('sıfırlama: doluyken yolluyor, BOŞKEN düğme kapalı', (
    tester,
  ) async {
    final (_, sifirlamalar) = await agac(tester, alinan: {'filo-1'});
    await tester.tap(find.byKey(argeSifirlaKey));
    await tester.pump();
    expect(sifirlamalar, hasLength(1));

    // Boş ağaçta düğme kapalı: onay penceresi yok (sıfırlama geri alınabilir,
    // 05.7) ve yerine geçen koruma bu.
    await agac(tester);
    expect(tester.widget<MenuButton>(find.byKey(argeSifirlaKey)).onTap, isNull);
  });

  // KARAR 05.7 s2
  testWidgets('üç ekran boyunda da ağacın tamamı kuruluyor', (tester) async {
    // Telefon yatay (844×390) ve dar pencere (560×620): kart kaydırılıyor ama
    // hiçbir düğüm ağaçtan düşmüyor. `SingleChildScrollView` kaydırıyor,
    // `ListView` gibi tembel değil — düşen bir düğüm sessizce alınamaz olurdu.
    for (final boy in const [Size(844, 390), Size(560, 620)]) {
      await agac(tester, boy: boy);
      for (final dugum in ArGe.hepsi) {
        expect(
          find.byKey(argeDugumKey(dugum.id)),
          findsOneWidget,
          reason: '${boy.width}×${boy.height} · ${dugum.id}',
        );
      }
      expect(find.byKey(argeSifirlaKey), findsOneWidget);
      expect(find.byKey(argeKapatKey), findsOneWidget);
    }
  });

  // KARAR 05.7 s2
  testWidgets('GİRİŞ NOKTASI pilot kartı: unvan satırı → ARGE AĞACI', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = NetClient(uri: Uri.parse('ws://test'))
      ..hangar = gorunum(alinan: {'filo-1'});
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HangarScreen(client: client, onClose: () {}),
      ),
    );
    await tester.pump();

    // Hangarda ArGe'nin başka bir kapısı YOK: beşinci bir sekme açmak yerine
    // pilot kartı seçildi (05.7 puanı seviyeden veriyor, 10.4 s2 seviyeyi
    // orada gösteriyor).
    expect(find.byKey(argeKartiKey), findsNothing);
    await tester.tap(find.byKey(hangarUnvanKey));
    await tester.pump();

    final dugme = find.byKey(unvanKartiArGeKey);
    expect(dugme, findsOneWidget, reason: 'pilot kartında ArGe girişi yok');
    // Karttaki sayaç ağaçtakiyle AYNI kaynaktan: iki yerde ayrı sayılsaydı
    // oyuncu düğmeye basınca başka bir sayı görürdü.
    expect(
      find.text(
        Metin.argeOzeti.bicim(Dil.turkce, {'harcanan': '1', 'toplam': '6'}),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(dugme);
    await tester.pump();
    await tester.tap(dugme);
    await tester.pump();
    expect(find.byKey(argeKartiKey), findsOneWidget);

    // Pilot kartı ALTTA açık kalıyor: ağacı kapatan oyuncu geldiği yere
    // dönüyor, hangarın köküne atılmıyor.
    expect(find.byKey(unvanKartiKey), findsOneWidget);
    await tester.tap(find.byKey(argeKapatKey));
    await tester.pump();
    expect(find.byKey(argeKartiKey), findsNothing);
    expect(find.byKey(unvanKartiKey), findsOneWidget);
  });

  // KARAR 05.7 s2 · KARAR 04.10 s3
  test('izin düğümü FİLO TAVANINI ekranda da artırıyor', () {
    // Ekran uzun süre ilan edilen sabiti okuyordu ve o sabit ArGe'yi
    // tanımıyor: izni alan oyuncunun sunucusu on bir droid kabul ederken
    // hangar "10/10 · FİLO DOLU" diyordu — ağacın tek görünür ödülü
    // görünmüyordu.
    expect(gorunum().filoTavani, TasarimGirdileri.droidFiloTavani);
    expect(
      gorunum(alinan: {'filo-1', 'filo-2', 'filo-3', 'filo-yuva'}).filoTavani,
      TasarimGirdileri.droidFiloTavani + 1,
    );
    // Sunucunun hangarı ile aynı sayı — tek uygulama (`ArGe.filoTavani`).
    final hangar = Hangar(
      accountId: 'a',
      argeDugumleri: {'filo-1', 'filo-2', 'filo-3', 'filo-yuva'},
    );
    expect(hangar.filoTavani, gorunum(alinan: hangar.argeDugumleri).filoTavani);
  });

  // KARAR 05.7 s2
  test('alınan düğümler sunucunun HANGAR JSON\'undan okunuyor', () {
    // Protokole yeni bir alan girmedi: `Hangar.toJson()` `argeDugumleri`'ni
    // zaten yazıyor ve sunucunun `_hangarJson`'u onu olduğu gibi yayıyor.
    // Eksik olan tek şey istemcinin OKUMASIYDI.
    final hangar = Hangar(accountId: 'a', argeDugumleri: {'gemi-1'});
    expect(hangar.toJson()['argeDugumleri'], ['gemi-1']);
    expect(gorunum(alinan: {'gemi-1'}).argeDugumleri, {'gemi-1'});
    // Boş ağaç alanı hiç yazmıyor (eski kayıtların biçimi bozulmasın) ve
    // istemci onu boş küme olarak okuyor.
    expect(Hangar(accountId: 'b').toJson().containsKey('argeDugumleri'), false);
    expect(gorunum().argeDugumleri, isEmpty);
  });
}
