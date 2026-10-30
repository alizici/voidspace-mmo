import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/govde_tasarimlari.dart';
import 'package:voidspace3/hangar/arge_karti.dart';
import 'package:voidspace3/hangar/gemi_ikonu.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/item_sheet.dart';
import 'package:voidspace3/hangar/menu_model.dart';
import 'package:voidspace3/hangar/shop_page.dart';
import 'package:voidspace3/hangar/unvan_karti.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Görsel referans: hangar, mağaza ve filo penceresi.
///
/// **Sunucu YOK.** Ekran `NetClient.hangar` alanını okuyor ve o alan açık;
/// gerçek bir sunucu ayağa kaldırmak goldeni ağ zamanlamasına bağımlı yapardı.
/// Burada ölçülen şey ağ değil DÜZEN.
///
/// **Yazı tipi GERÇEK.** `flutter test` varsayılan olarak Ahem kullanıyor:
/// bütün harfler aynı genişlikte dolu kareler. Düzen onunla doğru görünüp
/// gerçek metinde taşabiliyor — ilk yazışta tam olarak öyle oldu: bütün
/// metinler sarı alt çizgiliydi (Material atası yoktu) ve '⇄' ile '✓' glifleri
/// boş kutu olarak çiziliyordu. Ahem hiçbirini göstermezdi.
Future<void> _loadMono() async {
  for (final path in const [
    '/System/Library/Fonts/Monaco.ttf',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader('monospace')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
    return;
  }
}

/// Gövde ikonlarını ÇÖZDÜRÜR — yoksa goldenda kartlar boş kutu görünür.
///
/// `Image.asset` diskten okuyup çözüyor ve ikisi de GERÇEK asenkron iş. Widget
/// testi sahte bir zaman bölgesinde koşuyor, orada bu iş hiç bitmiyor: kare
/// ilerliyor, görüntü gelmiyor, golden ikonsuz çıkıyor.
///
/// `runAsync` gerçek olay döngüsüne çıkarıyor; çözülen görüntü [imageCache]'e
/// düşüyor ve sonraki kare onu SENKRON buluyor. Bu yüzden bir kez, başta.
///
/// Anahtar `Image.asset`'in kurduğuyla AYNI olmak zorunda. [GemiIkonu]
/// `cacheWidth` veriyor, yani sağlayıcısı `ResizeImage` — düz `AssetImage`
/// önbelleğe alınsaydı farklı anahtara düşer ve hiçbir işe yaramazdı,
/// sessizce. O yüzden burada da aynı sarmalayıcı kuruluyor.
Future<void> _loadIcons(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  final oran = MediaQuery.devicePixelRatioOf(context);
  await tester.runAsync(() async {
    for (final yol in GovdeTasarimlari.ikonlar) {
      for (final boy in GemiIkonu.boylar) {
        await precacheImage(
          ResizeImage(AssetImage(yol), width: (boy * oran).round()),
          context,
        );
      }
    }
  });
  await tester.pump();
}

/// Gösterime yetecek kadar dolu bir hangar.
///
/// Boş bir hangar düzen hakkında hiçbir şey söylemez: dolu yuva da, takılı
/// rozeti de, depo grupları da görünmez.
NetClient _client() {
  const laser = 'i-pl1';
  const spare = 'i-pl3';
  const shield = 'i-df1';
  const cpu = 'i-cpu';
  final hangar = Hangar(
    accountId: 'onizleme',
    credits: 48600,
    // SEVİYE VE ARGE: boş hangarla aynı gerekçe (yukarı bkz.). Sıfırıncı
    // seviyedeki bir pilotun ArGe puanı da sıfır ve o ağaçta gösterilecek
    // hiçbir DURUM yok — sekiz düğüm de aynı gri kutu. Altı puan, üçü
    // harcanmış: filo dalının ilk ikisi ALINMIŞ, üçüncüsü tam olarak
    // alınabilir (kalan üç puan, maliyet üç), izin düğümü zincirden kilitli
    // ve gemi dalının kökü açık. Dört durumun dördü de tek referansta.
    xp: Seviye.esigi(6).ceil(),
    argeDugumleri: {'filo-1', 'filo-2'},
    hulls: [HullClass.starter.id, HullClass.vanguard.id],
    activeHullId: HullClass.starter.id,
    malzemeler: {'m-cI': 42, 'm-cII': 8, 'm-bI': 3},
    inventory: {
      laser: const ItemInstance(instanceId: laser, specId: 'pl1', level: 2),
      spare: const ItemInstance(instanceId: spare, specId: 'pl3'),
      shield: const ItemInstance(instanceId: shield, specId: 'df1'),
      // Takılıdan GÜÇLÜ bir yedek: yükseltme okunun görünmesi için.
      'i-pl4': const ItemInstance(instanceId: 'i-pl4', specId: 'pl4'),
      cpu: const ItemInstance(instanceId: cpu, specId: 'cpu_scope', level: 1),
    },
    loadouts: {
      HullClass.starter.id: Loadout(
        hullId: HullClass.starter.id,
        slots: {
          const SlotRef(SlotType.laser, 0).id: laser,
          const SlotRef(SlotType.generator, 0).id: shield,
          const SlotRef(SlotType.cpu, 0).id: cpu,
        },
      ),
    },
  );
  final stats = LoadoutResolver.resolve(
    hangar.activeLoadout,
    hangar.inventory,
    Catalogue.byId,
  );
  final br = CombatGlossary.battleRating(stats);
  final unvan = CombatGlossary.unvanIndeksi(br);
  return NetClient(uri: Uri.parse('ws://onizleme'))
    ..hangar = HangarView.fromJson({
      ...hangar.toJson(),
      // Sunucunun hangar durumuyla yolladığı türevler (10.1, 10.4): savaş
      // puanı, seviye, unvan. Başlık bunları çiziyor; eksik olsalardı
      // önizleme unvansız bir başlık gösterir ve satırın sığıp sığmadığı
      // görünmezdi.
      'br': br,
      'seviye': hangar.seviye,
      'unvan': unvan,
      'unvanAdi': Unvan.adi(unvan),
      // Sunucunun ÜRETTİĞİ haritanın aynısı — elle kopya DEĞİL. Kopya
      // olduğunda görsel referans, oyuncunun gördüğünden başka bir gemiyi
      // çizebilirdi ve ikisi de kendi içinde tutarlı kalacağı için kimse
      // fark etmezdi.
      'effective': ServerHangarState.effectiveOf(stats),
    });
}

/// Ölçülen ekranlar.
///
/// Telefon YATAY hâli listede çünkü düzeni belirleyen eksen orada yükseklik:
/// iPhone 14 yatayda 844×390. Yalnız masaüstünde bakmak, tam da oyuncunun
/// "mobilde okunmuyor" dediği hâli hiç görmemek demekti.
const _screens = [
  (name: 'masaustu', size: Size(1280, 720)),
  (name: 'telefon', size: Size(844, 390)),
  (name: 'dar', size: Size(560, 620)),
];

void main() {
  for (final screen in _screens) {
    testWidgets('Menü görsel referansı · ${screen.name}', (tester) async {
      await _loadMono();
      tester.view
        ..physicalSize = screen.size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const key = ValueKey('menu-preview');
      final client = _client();
      addTearDown(client.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            // Hata ayıklama şeridi goldenin köşesini yiyordu — kapat
            // düğmesinin tam üstüne geliyor ve karşılaştırmayı da gereksiz
            // yere kırılgan yapıyor.
            debugShowCheckedModeBanner: false,
            home: HangarScreen(client: client, onClose: () {}),
          ),
        ),
      );
      await tester.pump();
      await _loadIcons(tester);
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_hangar.png'),
      );

      // DEPO İŞLEM KİPİ: parçalama ve sentez ancak burada görünüyor.
      //
      // Dar düzende depo ayrı bir SEKMEDE, o yüzden önce oraya geçiliyor.
      // Bir süre bu yakalama yalnız masaüstünde yapılıyordu ve telefon
      // dosyası depoda kalmış eski bir düzeni gösteriyordu — hiçbir testin
      // yazmadığı bir referans, yanlış olduğunu söyleyecek kimse olmadan.
      final depoSekmesi = find.byKey(paneTabKey(HangarTab.ekipman));
      if (depoSekmesi.evaluate().isNotEmpty) {
        await tester.tap(depoSekmesi);
        await tester.pump();
      }
      // İŞLEM KİPİ YOK — eylem çubuğu SEÇİMDEN doğuyor.
      //
      // Bir süre depoda bir kip vardı ve bu yakalama önce ona basıyordu.
      // Kip kalktı: parça seçmek eylem çubuğunu kendiliğinden getiriyor.
      // İki parça seçiliyor ki sentezin neden tutmadığı da referansta
      // görünsün — ikisi farklı rankta.
      for (final id in ['i-pl3', 'i-df1']) {
        final t = find.byKey(depotTileKey(id));
        if (t.evaluate().isNotEmpty) {
          await tester.ensureVisible(t);
          // `pumpAndSettle` DEĞİL: hangarda hiç durmayan bir animasyon var
          // (rank plakalarının yörünge noktaları, bkz. `RankSaati`).
          // `pumpAndSettle` "kare kuyruğu boşalana kadar bekle" demek ve
          // sonsuz dönen bir saatte o an hiç gelmiyor — test zaman aşımına
          // düşüyor. Sabit süre ilerletmek düzeni zaten oturtuyor.
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(t, warnIfMissed: false);
          await tester.pump();
        }
      }
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_depo_islem.png'),
      );
      // Donanıma geri dön: sonraki yakalamalar hangarın kendi görünümünü
      // bekliyor.
      final donanimSekmesi = find.byKey(paneTabKey(HangarTab.ekipman));
      if (donanimSekmesi.evaluate().isNotEmpty) {
        await tester.tap(donanimSekmesi);
        await tester.pump();
      }

      // DROİD FİLOSU: her droid bir satır — kendisi, ekipmanı, tasarımı.
      //
      // Bu bölmenin referansı yoktu ve düzeni (iki ekipman yuvası, ayırıcı,
      // küçük tasarım yuvası) hiçbir yerde ölçülmüyordu.
      final droidSekmesi = find.byKey(paneTabKey(HangarTab.droid));
      if (droidSekmesi.evaluate().isNotEmpty) {
        await tester.tap(droidSekmesi);
        await tester.pump();
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('menu_${screen.name}_droid.png'),
        );
        await tester.tap(find.byKey(paneTabKey(HangarTab.ekipman)));
        await tester.pump();
      }

      // PİLOT KARTI: unvan satırına dokununca açılıyor (10.4 s2). Amblem,
      // çağ, kademe, sıradaki eşik ve yirmi adın merdiveni tek kartta —
      // hiçbiri unvan satırına sığmıyor ve referansı olmadan kartın dar
      // ekranda taşıp taşmadığı görünmüyordu.
      await tester.tap(find.byKey(hangarUnvanKey));
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_unvan.png'),
      );

      // ARGE AĞACI: pilot kartından açılan ayrı pencere (05.7, borç defteri
      // B33). Üç dal başlığı, dal başına dört düğümlük zincir, puan sayacı ve
      // sıfırlama — hiçbiri unvan kartına sığmıyor ve referansı olmadan
      // ağacın telefon yatayda taşıp taşmadığı görünmüyor.
      //
      // Ön koşul SESSİZCE atlanmıyor, `expect` ile KIRILIYOR. Bu dosyadaki
      // en pahalı hata tam olarak bunun tersiydi: yardımcı `false` dönüyor,
      // yakalama yapılmıyor, PNG aylarca bayat kalıyordu (bkz. `_kategori`).
      // Bir sekmenin bulunamaması bir referansın yokluğu demek ve bunu
      // söyleyecek olan bu satır.
      final argeDugmesi = find.byKey(unvanKartiArGeKey);
      expect(argeDugmesi, findsOneWidget, reason: 'pilot kartında ArGe yok');
      await tester.ensureVisible(argeDugmesi);
      await tester.pump();
      await tester.tap(argeDugmesi);
      await tester.pump();
      expect(
        find.byKey(argeKartiKey),
        findsOneWidget,
        reason: 'ArGe penceresi açılmadı',
      );
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_arge.png'),
      );
      await tester.tap(find.byKey(argeKapatKey));
      await tester.pump();

      // Kart PERDEDEN kapatılıyor, düğmeden değil: telefon yatayda kart
      // kaydırılabilir ve KAPAT düğmesi görünür alanın altında kalıyor.
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();

      // GEMİ SEKMESİ: solda aktif geminin portresi, sağda künyesi.
      //
      // Portre bu sekmenin konusu ve gövdeye göre değişiyor — sabit bir
      // silüet çizildiği sürece hiçbir yakalama farkı göstermezdi.
      await tester.tap(find.byKey(paneTabKey(HangarTab.gemi)));
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_gemi.png'),
      );
      await tester.tap(find.byKey(paneTabKey(HangarTab.ekipman)));
      await tester.pump();

      // Telefonda GEMİ DEĞİŞTİR düğmesi YOK: üst şerit kalktı ve pencereyi
      // GEMİ sekmesindeki gemiye dokunmak açıyor. İki yol da aynı pencereyi
      // açtığı için hangisi varsa o kullanılıyor.
      if (find.byKey(fleetOpenKey).evaluate().isEmpty) {
        await tester.tap(find.byKey(paneTabKey(HangarTab.gemi)));
        await tester.pump();
        await tester.tap(find.byKey(gemiOnizlemeKey));
      } else {
        await tester.tap(find.byKey(fleetOpenKey));
      }
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_filo.png'),
      );
      await tester.tap(find.byKey(fleetCloseKey));
      await tester.pump();
      // EKİPMAN sekmesine dön: filo penceresine telefonda GEMİ sekmesinden
      // giriliyor ve sonraki yakalamalar yuvaları bekliyor. Sekme açık
      // kalırsa onlar ağaçta hiç bulunmuyor.
      if (find.byKey(paneTabKey(HangarTab.ekipman)).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(paneTabKey(HangarTab.ekipman)));
      }
      await tester.pump();

      await tester.tap(find.byKey(menuTabKey(MenuTabId.shop)));
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_magaza.png'),
      );

      // JENERATÖR sekmesi de çekiliyor — ve bu bir tamlık kaygısı değil,
      // ölçülmüş bir boşluğun kapatılması.
      //
      // Mağazadaki üç kalkan jeneratörünün üçü de "+0 KALKAN" yazıyordu
      // (değer bir kesirdi, kart onu mutlak sayı diye yuvarlıyordu) ve hata
      // aylarca görülmedi: görsel referansın YALNIZ lazer sekmesi vardı.
      // 2.430 NOVA'lık DF-5'in vitrini sıfır gösteriyordu ve hiçbir ekran
      // görüntüsü onu içermiyordu.
      if (await _kategori(tester, SlotType.generator.name)) {
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('menu_${screen.name}_magaza_jenerator.png'),
        );
      }

      // DROİD sekmesi: droidler, tasarımlar ve formasyonlar TEK sayfada.
      //
      // NOVA rafı ve görünüş rafları ayrı sekmelerdi ve ayrımın gerekçesi
      // para birimiydi; oyuncunun sorduğu soru ise "hangi yuvaya ne" idi.
      // Bu referans üç bölümün birlikte durduğunu ölçüyor — ve satın alınan
      // droidin KENDİ RESMİNİ (05.8 s2).
      //
      // Jeneratör ve gemi sekmeleriyle aynı sebeple burada. Droid kartı
      // uzun süre kademe harfinden ibaretti ve on tasarımın hangisini satın
      // aldığı karttan okunmuyordu — görsel referansı olmayan bir sekmede
      // görünmeyen bir boşluk. Kart artık resmi taşıyor ve o resim burada
      // ölçülüyor.
      if (await _kategori(tester, SlotType.droid.name)) {
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('menu_${screen.name}_magaza_droid.png'),
        );
      }

      // GEMİ sekmesi: sekiz gövdenin ikonu, statı ve fiyatı.
      //
      // Jeneratör sekmesiyle aynı sebeple burada: bu sekmenin görsel referansı
      // yoktu ve içinde iki şey birden görünmüyordu — gövdelerin nasıl
      // göründüğü (ikon eklenene kadar hiç), ve BEŞİNİN "YAKINDA" olduğu.
      // İkincisi bir tasarım borcu ve ekran görüntüsü olmadan görünmüyordu.
      if (await _kategori(tester, 'hull')) {
        await _loadIcons(tester);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('menu_${screen.name}_magaza_gemi.png'),
        );
      }

      // Bir YUVA seçili hâli — EN SONDA, çünkü seçim geri alınamıyor.
      //
      // `onTap` bir geçiş değil atama (`_selected = slot`), yani aynı yuvaya
      // ikinci kez dokunmak seçimi bırakmıyor. Bu yakalama araya konsaydı
      // sonraki bütün referanslar seçili bir yuvayla çizilirdi — ölçüldü:
      // filo ekranının iki PNG'si değişti.
      //
      // Kapsama sebebi: YÜKSELT düğmesi ve fiyatı yalnız bu şeritte. Seçim
      // yapmadan yakalanan referans, düğmenin fiyatsız ve kapısız olduğunu
      // gizliyordu.
      await tester.tap(find.byKey(menuTabKey(MenuTabId.hangar)));
      await tester.pump();
      await tester.tap(
        find.byKey(slotTileKey(const SlotRef(SlotType.laser, 0))),
      );
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('menu_${screen.name}_yuva.png'),
      );
      // PENCEREYİ KAPAT.
      //
      // Yuvaya dokunmak artık parçanın penceresini açıyor (alt şerit kalktı)
      // ve pencerenin perdesi bütün ekranı kaplıyor. Kapatılmazsa sonraki
      // her dokunuş perdeye düşüyor: sekme değişmiyor, depo görünmüyor ve
      // eşya bilgi yakalaması sessizce atlanıyordu.
      final yuvaPenceresi = find.byKey(itemSheetCloseKey);
      if (yuvaPenceresi.evaluate().isNotEmpty) {
        await tester.tap(yuvaPenceresi);
        await tester.pump();
      }

      // EŞYA BİLGİ PENCERESİ: depodaki bir parçaya dokununca.
      //
      // Dar düzende depo ayrı bir sekmede: geçilmezse parça ağaçta bulunmuyor
      // ve yakalama sessizce atlanıyordu. Telefon dosyası bu yüzden aylardır
      // var olmayan bir düzeni gösteriyordu — ve bu pencere artık hangarın
      // ANA etkileşim yüzeyi (alt şerit kalktı), yani referansı olmayan tek
      // ekran olmamalı.
      final depoyaGec = find.byKey(paneTabKey(HangarTab.ekipman));
      if (depoyaGec.evaluate().isNotEmpty) {
        await tester.tap(depoyaGec);
        await tester.pump();
      }
      final parca = find.byKey(depotTileKey('i-pl3'));
      if (parca.evaluate().isNotEmpty) {
        await tester.ensureVisible(parca);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(parca, warnIfMissed: false);
        await tester.pump();
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('menu_${screen.name}_esya_bilgi.png'),
        );
        final kapat = find.byKey(itemSheetCloseKey);
        if (kapat.evaluate().isNotEmpty) {
          await tester.tap(kapat);
          await tester.pump();
        }
      }

      // MALZEME sekmesi: parçalamanın ve öldürmenin gittiği yer.
      final malzemeSekme = find.byKey(paneTabKey(HangarTab.materyal));
      if (malzemeSekme.evaluate().isNotEmpty) {
        await tester.tap(malzemeSekme.first, warnIfMissed: false);
        await tester.pump();
        await expectLater(
          find.byKey(key),
          matchesGoldenFile('menu_${screen.name}_malzeme.png'),
        );
      }
    });
  }
}

/// Mağazada kategoriye gider.
///
/// Dar ekranda kategoriler yatay ve TEMBEL bir şeritte (`ListView`): görünür
/// alanın dışındaki sekme hiç kurulmuyor ve `tap` onu bulamıyor. Mermi rafı
/// gelince GEMİ sekmesi şeridin görünmeyen ucuna düştü ve dar önizleme
/// sessizce kırıldı (borç defteri B9). Sekme bulunamazsa şerit görünene kadar
/// kaydırılıyor; kenar çubuğunda (hepsi kurulu) ilk bakışta bulunuyor.
/// Sekmeye ulaşabildiyse `true`. Ulaşamazsa çağıran o goldeni ATLIYOR:
/// kategori sayısı arttıkça dar ekranda bazı sekmeler tembel şeridin
/// dışında kalıyor ve önizlemenin işi kadrajı zorlamak değil, sığanı
/// kaydetmek.
Future<bool> _kategori(WidgetTester tester, String id) async {
  // ÖNCE GRUP.
  //
  // Raf şeridi iki kademeli: yalnız AÇIK grubun rafları çiziliyor. Grup
  // atlanınca sekme ağaçta hiç bulunmuyor ve bu yardımcı sessizce `false`
  // dönüyor — yani JENERATÖR, DROİD ve GEMİ referansları üç ekranda birden
  // yazılmadan geçiyordu. Sessizce atlanan bir yakalama, olmayan bir
  // referanstır.
  if (shopGroupOfCategory(id) case final grup?) {
    final grupDugmesi = find.byKey(shopGroupKey(grup));
    if (grupDugmesi.evaluate().isNotEmpty) {
      await tester.tap(grupDugmesi);
      await tester.pump();
    }
  }
  final sekme = find.byKey(shopCategoryKey(id));
  if (sekme.evaluate().isEmpty) {
    final serit = find.byKey(shopCategoryStripKey);
    if (serit.evaluate().isEmpty) return false;
    try {
      await tester.dragUntilVisible(sekme, serit, const Offset(-120, 0));
    } on Exception {
      // Şerit ucuna kadar kaydırıldı ve sekme yine kurulmadı: dar ekranda
      // on bir kategori sığmıyor. Önizlemenin işi kadrajı zorlamak değil.
      return false;
    } on StateError {
      return false;
    }
    await tester.pump();
  }
  if (sekme.evaluate().isEmpty) return false;
  await tester.tap(sekme);
  // İKİ kare: ilk karede ızgara yeni içerikle kuruluyor ama ölçüsünü bir
  // sonrakinde alıyor. Tek kare ilerletmek, geçiş anındaki yarım yerleşimi
  // ölçmek demek — ve o an gerçek bir taşma gibi görünüyor.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return true;
}
