@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app_scope.dart';
import 'package:voidspace3/hud/savas_cubugu.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/perf/frame_monitor.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/gateway.dart';

import 'game_harness.dart';

/// SAVAŞ ÇUBUĞU — mermi ve formasyon HUD'dan, hangara girmeden.
///
/// İddialar SUNUCUDA: çubuk niyet gönderiyor, seçim orada tutuluyor ve gemiye
/// oradan iniyor. İstemcide bir şey gösterilmiş olması yetmez.
void main() {
  Future<(NetClient, Gateway, Hangar)> kur(WidgetTester tester) async {
    late NetClient net;
    late Gateway gateway;
    late Hangar hangar;
    await tester.runAsync(() async {
      gateway = await bootServer();
      net = await connectClient(gateway, 'Ada');
      await awaitPlaying([net]);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (net.hangar == null && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final hesap = await gateway.accounts.login(
        usernameOrEmail: 'Ada',
        password: testPassword,
      );
      hangar = gateway.hangars.of(hesap.id);
    });
    addTearDown(() async {
      net.dispose();
      await gateway.stop();
    });
    await tester.pumpWidget(
      AppScope(
        client: net,
        frames: FrameMonitor(),
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SavasCubugu(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (net, gateway, hangar);
  }

  Future<void> bekle(WidgetTester tester, bool Function() bitti) async {
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!bitti() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
  }

  // KARAR 05.9 s1
  testWidgets('FORMASYON çubuktan seçiliyor, sunucuya iniyor', (tester) async {
    final (net, gateway, hangar) = await kur(tester);
    final secim = Formasyon.hepsi[3];
    // Formasyon artık NOVA rafından (15.9): varsayılan dışındakiler
    // sahiplenilmeden seçilemiyor. Sunucu tarafında sahiplen, sonra seç.
    hangar.formasyonEkle(secim.id);
    net.hangarAction('refresh', {});
    // SABİT UYKU DEĞİL, KOŞUL BEKLEMESİ.
    //
    // Burada 200 ms uyunuyordu ve sayı bir tahmindi: sunucuya gidip gelen
    // `refresh`in boş makinede ne kadar sürdüğü. Tam koşuda paketler paralel
    // koştuğu için gidiş dönüş uzuyor, uyku bitince istemci hâlâ eski
    // formasyon listesini taşıyor ve seçim düğmesi ağaçta hiç bulunmuyordu —
    // test kırmızıya dönüyor ama söylediği şey yanlış: "formasyon sunucuya
    // inmedi" değil, "yeterince beklemedim".
    //
    // Uykuyu uzatmak da çözüm değil; yalnız eşiği ileri iter ve testi
    // yavaşlatır. Beklenen ŞEY beklendiğinde ise makine ne kadar tıkalı
    // olursa olsun doğru: dosyanın kendi [bekle] yardımcısı koşulu on saniye
    // boyunca yokluyor ve koşul sağlanır sağlanmaz dönüyor — hızlı makinede
    // 200 ms'den de ucuz.
    await bekle(
      tester,
      () => net.hangar?.formasyonlar.contains(secim.id) ?? false,
    );
    expect(find.byKey(hudSecimPaneliKey), findsNothing);

    await tester.tap(find.byKey(hudFormasyonKey));
    await tester.pump();
    expect(find.byKey(hudSecimPaneliKey), findsOneWidget);

    await tester.tap(find.byKey(hudFormasyonSecimKey(secim.id)));
    await bekle(tester, () => hangar.formasyonId == secim.id);
    expect(hangar.formasyonId, secim.id, reason: 'seçim sunucuya ulaşmadı');
    expect(
      find.byKey(hudSecimPaneliKey),
      findsNothing,
      reason: 'panel seçimle kapanmadı',
    );
    // GEMİ DE TAŞIYOR: meta imzası formasyonu söylüyor.
    //
    // Beklemesiz sınanıyordu ve tam koşuda düşen satır buydu: hangar durumu
    // istemciye ulaştıktan SONRA sunucunun donatımı uçan gemiye uygulaması
    // ayrı bir adım, ve tıkalı makinede o adım aynı milisaniyeye sığmıyor —
    // imza `1|0|||0` kalıyor. Test kırmızıya dönüyor ama söylediği şey
    // yanlış: "formasyon gemiye inmedi" değil, "henüz inmedi".
    //
    // Bekleme iddiayı ZAYIFLATMIYOR. Sınanan şey imzanın sıfır gecikmeyle
    // güncellenmesi değil, formasyonun ölüp yeniden doğmayı BEKLEMEDEN
    // gemiye inmesi (05.9): gemi aynı örnek, imza değişiyor.
    await bekle(
      tester,
      () => gateway.zone.ships.values.single.metaImzasi.endsWith('|3'),
    );
    final gemi = gateway.zone.ships.values.single;
    expect(gemi.metaImzasi, endsWith('|3'), reason: 'formasyon gemiye inmedi');
    expect(net.hangar!.formasyonId, secim.id);
  });

  // KARAR 17.8 s1
  testWidgets('MERMİ: stoksuz seçilemez, stoklu seçim ANINDA gemide', (
    tester,
  ) async {
    final (net, gateway, hangar) = await kur(tester);
    final gemi = gateway.zone.ships.values.single;

    await tester.tap(find.byKey(hudMermiKey));
    await tester.pump();
    expect(find.byKey(hudSecimPaneliKey), findsOneWidget);

    // Stok yok: seçenek görünüyor ama basınca hiçbir şey gitmiyor.
    await tester.tap(find.byKey(hudMermiSecimKey('MR-2')));
    await tester.pump();
    expect(find.byKey(hudSecimPaneliKey), findsOneWidget);
    expect(gemi.mermiCarpani, 1);

    // Stok geldi (mağaza yolu ayrı sınanıyor): seçim gemiye iniyor.
    hangar.mermiEkle('MR-2', 10);
    net.hangarAction('refresh');
    await bekle(tester, () => net.hangar!.mermiSayisi('MR-2') == 10);

    await tester.tap(find.byKey(hudMermiSecimKey('MR-2')));
    // SUNUCU İLE İSTEMCİ AYNI ANDA DEĞİL.
    //
    // Yalnız `gemi.mermiCarpani` bekleniyordu — o SUNUCU tarafı. Altındaki
    // iki sınama ise İSTEMCİNİN görüşünü okuyor (`net.hangar`) ve panelin
    // kapanması da ona bağlı. İkisi ayrı gidiş dönüş; tıkalı makinede sunucu
    // güncellenmiş, istemciye daha ulaşmamış oluyor. İkisini birden beklemek
    // iddiayı değiştirmiyor, yalnız "aynı milisaniye" varsayımını kaldırıyor.
    await bekle(
      tester,
      () => gemi.mermiCarpani == 2 && net.hangar?.seciliMermi.id == 'MR-2',
    );
    expect(gemi.mermiId, 'MR-2', reason: 'seçim gemiye inmedi');
    expect(net.hangar!.seciliMermi.id, 'MR-2');
    expect(find.byKey(hudSecimPaneliKey), findsNothing);
  });

  // KARAR 18.4 s1
  testWidgets('ROKET: stoksuz seçilemez, stoklu seçim ANINDA gemide', (
    tester,
  ) async {
    // Uzun süre çubukta roket düğmesi yoktu: seçilecek şey yoktu (borç
    // defteri B20). Roketatar silah olunca mermisi mermi gibi seçiliyor.
    final (net, gateway, hangar) = await kur(tester);
    final gemi = gateway.zone.ships.values.single;

    await tester.tap(find.byKey(hudRoketKey));
    await tester.pump();
    expect(find.byKey(hudSecimPaneliKey), findsOneWidget);

    await tester.tap(find.byKey(hudRoketSecimKey('RK-2')));
    await tester.pump();
    expect(find.byKey(hudSecimPaneliKey), findsOneWidget);
    expect(gemi.roketCarpani, 1);

    hangar.roketEkle('RK-2', 5);
    net.hangarAction('refresh');
    await bekle(tester, () => net.hangar!.roketSayisi('RK-2') == 5);

    await tester.tap(find.byKey(hudRoketSecimKey('RK-2')));
    // Mermideki ile aynı sebep: sunucu ile istemci ayrı gidiş dönüş.
    await bekle(
      tester,
      () => gemi.roketCarpani == 2 && net.hangar?.seciliRoket.id == 'RK-2',
    );
    expect(gemi.roketId, 'RK-2', reason: 'seçim gemiye inmedi');
    expect(net.hangar!.seciliRoket.id, 'RK-2');
    expect(find.byKey(hudSecimPaneliKey), findsNothing);
  });
}
