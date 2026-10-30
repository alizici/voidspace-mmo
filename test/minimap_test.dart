@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app_scope.dart';
import 'package:voidspace3/app/palette.dart';
import 'package:voidspace3/hud/hud_overlay.dart';
import 'package:voidspace3/hud/minimap.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/perf/frame_monitor.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace3/ship/ship_event.dart';
import 'package:voidspace3/ship/ship_state.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Harita, konumu ÇUBUKLARLA aynı anlık görüntüden okumak zorunda.
///
/// Bu dosyanın koruduğu şey bir görüntü değil bir sözleşme: minimap oyuna
/// bakmıyor, `ShipState`'ten besleniyor. Bağ koptuğu an harita ile HUD farklı
/// iki gerçek göstermeye başlar ve bu, ekranda "bir şeyler ters" diye görünen
/// ama hangi sayının yanlış olduğu görünmeyen hata sınıfıdır.
/// Minimap'in kendi tuvali — `MaterialApp` ağacındaki diğer `CustomPaint`
/// katmanlarıyla karışmasın diye kökünden aranır.
final _canvas = find.descendant(
  of: find.byType(Minimap),
  matching: find.byType(CustomPaint),
);

void main() {
  const world = GameWorld.standard;

  group('dönüşüm', () {
    // Kutu DÜNYADAN türetiliyor, elle yazılmıyor. Elle yazılmış 180×120,
    // yalnız dünyanın en/boy oranı tam 3:2 olduğunda köşeye oturuyordu;
    // harita ölçüsü alan 11'den türetildiğinde oran 1,50007 oldu ve test
    // izdüşümü değil kendi varsayımını ölçmeye başladı.
    const genislik = 180.0;
    final yukseklik = MinimapProjection.heightFor(world, genislik);

    test('dünya merkezi haritanın merkezine düşer', () {
      final p = MinimapProjection(world, Size(genislik, yukseklik));
      final m = p.toMap(world.centre.x, world.centre.y);
      expect(m.dx, closeTo(genislik / 2, 0.001));
      expect(m.dy, closeTo(yukseklik / 2, 0.001));
    });

    test('köşeler köşelere düşer', () {
      final p = MinimapProjection(world, Size(genislik, yukseklik));
      expect(p.toMap(0, 0), Offset.zero);
      final son = p.toMap(world.width, world.height);
      expect(son.dx, closeTo(genislik, 0.001));
      expect(son.dy, closeTo(yukseklik, 0.001));
    });

    test('en-boy oranı KORUNUR — tek ölçek', () {
      // İki ayrı ölçek kullanmak, kuzeye gitmeyi haritada doğuya gitmekten
      // farklı hızda gösterirdi.
      final h = MinimapProjection.heightFor(world, 180);
      expect(h, closeTo(180 * world.height / world.width, 0.001));

      final p = MinimapProjection(world, Size(180, h));
      final dx = p.toMap(1000, 0).dx - p.toMap(0, 0).dx;
      final dy = p.toMap(0, 1000).dy - p.toMap(0, 0).dy;
      expect(dx, closeTo(dy, 0.001));
    });

    test('dar bir dünyada da oran korunur', () {
      const narrow = GameWorld(width: 4000, height: 9000);
      expect(MinimapProjection.heightFor(narrow, 100), closeTo(225, 0.001));
    });
  });

  group('durum akışı', () {
    test('Bloc konumu, açıyı ve izleri HUD yüzeyine taşır', () {
      final bloc = ShipBloc();
      final sim = ShipSimState.spawn(
        ShipStats.bastion,
        const Vec2(1234, 5678),
      ).copyWith(angle: 1.1, weaponTarget: 7);

      bloc.add(
        ShipSynced(
          phase: NetPhase.playing,
          state: sim,
          world: world,
          viewSize: const Vec2(3200, 2100),
          blips: const [MapBlip(id: 7, x: 2000, y: 3000, alive: true)],
        ),
      );

      return expectLater(
        bloc.stream,
        emits(
          isA<ShipState>()
              .having((s) => s.position, 'konum', const Vec2(1234, 5678))
              .having((s) => s.angle, 'açı', 1.1)
              .having((s) => s.viewSize, 'görüş', const Vec2(3200, 2100))
              .having((s) => s.blips.single.id, 'iz', 7),
        ),
      );
    });

    test('bağlantı koptuğunda İZLER düşer, konum kalır', () {
      // Duran gemiler haritada asılı kalırsa oyuncu olmayan bir dünyayı okur.
      // Konum ise son bilinen gerçek: onu silmek haritayı boşaltırdı.
      const before = ShipState(
        stats: ShipStats.bastion,
        phase: NetPhase.playing,
        hull: 1,
        shield: 1,
        boostCharges: 1,
        boostRemaining: 0,
        rechargeElapsed: 0,
        pingMs: 10,
        nearby: 3,
        message: null,
        position: Vec2(900, 900),
        blips: [MapBlip(id: 2, x: 1, y: 1, alive: true)],
      );

      final after = before.offline(phase: NetPhase.disconnected);
      expect(after.blips, isEmpty);
      expect(after.position, const Vec2(900, 900));
    });
  });

  group('çizim', () {
    Future<void> pumpHud(WidgetTester tester, ShipState state) async {
      final bloc = ShipBloc();
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Palette.space,
            body: BlocProvider.value(
              value: bloc,
              child: Minimap(state: state),
            ),
          ),
        ),
      );
    }

    ShipState playing({Vec2 at = const Vec2(6000, 4000)}) => ShipState(
      stats: ShipStats.bastion,
      phase: NetPhase.playing,
      hull: 12000,
      shield: 8000,
      boostCharges: 3,
      boostRemaining: 0,
      rechargeElapsed: 0,
      pingMs: 12,
      nearby: 2,
      message: null,
      weaponTarget: 4,
      position: at,
      angle: 0.6,
      viewSize: const Vec2(3200, 2100),
      blips: const [
        MapBlip(id: 4, x: 7000, y: 4200, alive: true),
        MapBlip(id: 5, x: 2000, y: 1200, alive: false),
      ],
    );

    testWidgets('harita dünyanın oranında çizilir', (tester) async {
      await pumpHud(tester, playing());
      final size = tester.getSize(_canvas);
      expect(size.width, 186);
      expect(size.height, closeTo(124, 0.5));
    });

    testWidgets('dar alanda TAŞMAZ, daralır', (tester) async {
      // Telefonda harita düğmelerin üstüne binerse HUD okunmaz olur.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 90, child: Minimap(state: playing())),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_canvas).width, 90);
    });

    testWidgets('TELEFON genişliğinde HUD taşmaz', (tester) async {
      // Düğmeler ve harita aynı satırda. Masaüstünde bol yer var; dar bir
      // ekranda bu satır taşar ve HUD okunmaz olur — kaydırılamayan bir
      // arayüzde taşma sessiz veri kaybıdır.
      tester.view
        ..physicalSize = const Size(375, 750)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final bloc = ShipBloc();
      addTearDown(bloc.close);
      bloc.add(
        ShipSynced(
          phase: NetPhase.playing,
          state: ShipSimState.spawn(ShipStats.bastion, world.centre),
          world: world,
          viewSize: const Vec2(3200, 2100),
        ),
      );

      // Bağlanmayan bir istemci: `AppScope` bir örnek istiyor, bu test ise
      // ağı değil YERLEŞİMİ ölçüyor.
      final idle = NetClient(uri: Uri.parse('ws://127.0.0.1:1'));
      addTearDown(idle.dispose);

      await tester.pumpWidget(
        AppScope(
          client: idle,
          frames: FrameMonitor(),
          child: MaterialApp(
            home: Scaffold(
              body: BlocProvider.value(value: bloc, child: const HudOverlay()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Minimap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
