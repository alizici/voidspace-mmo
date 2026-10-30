@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app_scope.dart';
import 'package:voidspace3/hud/hud_overlay.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/net/predicted_ship.dart';
import 'package:voidspace3/perf/frame_monitor.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace3/ship/ship_event.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// GEÇİT İSTEMİ — HUD'daki geçiş düğmesi.
///
/// Bu dosyanın varlık sebebi bir hata: istem `const` bir alt ağaçta duruyordu
/// ve Flutter, eşit widget'ların alt ağacını hiç güncellemiyor. İlk karede
/// (geçit uzaktayken) boş dönüyor ve BİR DAHA çalışmıyordu — oyuncu geçidin
/// tam üstüne gelse de düğme çıkmıyordu. Hiçbir mevcut test bunu yakalamadı
/// çünkü hepsi tek bir kare kuruyor.
///
/// Buradaki testler geminin KONUMUNU değiştirip HUD'ı yeniden pompalıyor:
/// ölçülen şey "doğru anda doğru görünüyor mu" değil, **"değiştiğinde
/// değişiyor mu"**.
void main() {
  late NetClient net;
  late ShipBloc bloc;

  setUp(() {
    net = NetClient(uri: Uri.parse('ws://test'))
      ..harita = Harita.baslangic
      ..world = Harita.baslangic.dunya;
    bloc = ShipBloc();
  });
  tearDown(() {
    net.dispose();
    bloc.close();
  });

  /// Gemiyi [konum]'a koyup HUD'ı pompalar.
  Future<void> koy(WidgetTester tester, Vec2 konum) async {
    net.ship = PredictedShip(
      world: net.world,
      initial: ShipSimState.spawn(ShipStats.bastion, konum),
    );
    bloc.add(
      ShipSynced(
        phase: NetPhase.playing,
        state: net.ship!.state,
        pingMs: 20,
        nearby: 0,
        world: net.world,
        viewSize: const Vec2(1200, 700),
      ),
    );
    // ÜÇ pompa: `bloc.add` olayı bir mikro görevde işleniyor, `emit` bir
    // sonrakinde aboneye ulaşıyor, `setState` ondan sonraki karede çiziliyor.
    // İki pompa ile bloc durumu güncel oluyor ama ağaç hâlâ eski kalıyordu.
    // `runAsync` ŞART: bloc olayı GERÇEK olay döngüsünde işleniyor. Sahte
    // zamanlı zone'da `add` çağrısı bloc'un durumunu güncelliyor ama
    // aboneliğin geri çağrısı hiç ateşlenmiyordu — ölçüldü, `_LiveHud` bir kez
    // kurulup bir daha çalışmıyordu ve test aradığı hatayı DEĞİL bu tuzağı
    // ölçüyordu.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  Future<void> kur(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Dünyaya GİRMİŞ hâlde başla: HUD perdeyi ancak `online` olunca kaldırıyor
    // ve bu testlerin ölçtüğü şey perde değil, perdenin ardındaki istem.
    net.ship = PredictedShip(
      world: net.world,
      initial: ShipSimState.spawn(ShipStats.bastion, net.world.centre),
    );
    bloc.add(
      ShipSynced(
        phase: NetPhase.playing,
        state: net.ship!.state,
        world: net.world,
        viewSize: const Vec2(1200, 700),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          client: net,
          frames: FrameMonitor(),
          touchControls: false,
          child: BlocProvider.value(value: bloc, child: const HudOverlay()),
        ),
      ),
    );
  }

  Gecit gecitBul(HaritaTipi tip) => GecitAgi.gecitleriFor(
    Harita.baslangic,
  ).firstWhere((g) => g.hedef.tip == tip);

  testWidgets('istem geçide GİRİNCE beliriyor — sabit widget hatası', (
    tester,
  ) async {
    await kur(tester);
    final gecit = gecitBul(HaritaTipi.pvp);

    // Önce UZAKTA: istem yok. Bu ilk kare, ve hatalı sürümde de doğruydu.
    await koy(tester, net.world.centre);
    expect(find.textContaining('GEÇ'), findsNothing);

    // Sonra geçidin ÜSTÜNDE: istem BELİRMELİ.
    //
    // Hatalı sürüm tam burada kalıyordu — alt ağaç `const` olduğu için ilk
    // karenin boş sonucu donuyordu.
    await koy(tester, gecit.konum);
    expect(
      find.textContaining('GEÇ'),
      findsOneWidget,
      reason: 'geçidin üstünde istem çıkmadı',
    );

    // Ve çıkınca KAYBOLMALI: tek yönlü bir güncelleme de hata olurdu.
    await koy(tester, net.world.centre);
    expect(find.textContaining('GEÇ'), findsNothing);
  });

  testWidgets('istem hedefi ADIYLA söylüyor', (tester) async {
    await kur(tester);
    await koy(tester, gecitBul(HaritaTipi.boss).konum);
    expect(find.textContaining('BOSS'), findsOneWidget);
  });

  testWidgets('KİLİTLİ kapıda eksik BR yazıyor, düğme çalışmıyor', (
    tester,
  ) async {
    await kur(tester);
    // İleri kapı ikinci bölgeye açılıyor ve savaş puanı sıfır.
    final ileri = GecitAgi.gecitleriFor(
      Harita.baslangic,
    ).firstWhere((g) => g.yon == GecitYonu.dogu);
    await koy(tester, ileri.konum);
    expect(find.textContaining('KİLİTLİ'), findsOneWidget);
    expect(find.textContaining('BR'), findsOneWidget);
    expect(find.textContaining('GEÇ  →'), findsNothing);
  });

  testWidgets('sunucunun REDDİ oyuncuyu oyundan atmıyor', (tester) async {
    // Bu testin ölçtüğü şey ikinci hata: red önce `ServerRejected` ile
    // gönderiliyordu ve istemci onu alınca belirteci unutup dünyadan çıkıyordu.
    // Geçide iki adım uzak durmanın cezası oturumu kaybetmek olamaz.
    await kur(tester);
    await koy(tester, gecitBul(HaritaTipi.pvp).konum);

    // Gemi KIPIRDAMIYOR — bu testin bütün mesele bu. `ShipState` bir
    // `Equatable` ve konum props'ta; duran oyuncuda bloc hiç yayın yapmıyor.
    // Red mesajı yalnız `net.changes` üstünden gelebilir.
    final oncekiFaz = net.phase;
    net.gecitHatasi = 'geçit menzilinde değilsin';
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    // Red oturuma DOKUNMUYOR. Eski hâlde `ServerRejected` gönderiliyordu ve
    // istemci onu alınca fazı `rejected` yapıp belirteci unutuyordu.
    expect(net.phase, oncekiFaz, reason: 'geçiş reddi oturumu değiştirdi');
    expect(net.phase, isNot(NetPhase.rejected));
    expect(find.textContaining('menzilinde değilsin'), findsOneWidget);
  });
}
