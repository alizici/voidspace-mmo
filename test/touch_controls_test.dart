@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app_scope.dart';
import 'package:voidspace3/hud/hud_overlay.dart';
import 'package:voidspace3/hud/minimap.dart';
import 'package:voidspace3/hud/touch_controls.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/net/predicted_ship.dart';
import 'package:voidspace3/perf/frame_monitor.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace3/ship/ship_event.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Parmakla oynanan sürümün denetim şeması.
///
/// Platform testte SORULMUYOR, geçiriliyor: `defaultTargetPlatform`'a widget
/// içinden bakan bir HUD masaüstünde sınanamazdı ve dokunmatik düzen ancak
/// gerçek bir telefonda görülürdü.
void main() {
  Widget hud({
    required bool touch,
    VoidCallback? onCycleTarget,
    int pingMs = 0,
    int nearby = 0,
  }) {
    final bloc = ShipBloc()
      ..add(
        ShipSynced(
          phase: NetPhase.playing,
          state: ShipSimState.spawn(
            ShipStats.bastion,
            GameWorld.standard.centre,
          ).copyWith(weaponTarget: 3),
          world: GameWorld.standard,
          viewSize: const Vec2(3200, 2100),
          pingMs: pingMs,
          nearby: nearby,
        ),
      );
    addTearDown(bloc.close);

    // Bağlanmayan istemci: bu dosya ağı değil DÜZENİ ölçüyor.
    final idle = NetClient(uri: Uri.parse('ws://127.0.0.1:1'));
    addTearDown(idle.dispose);

    return AppScope(
      client: idle,
      frames: FrameMonitor(),
      touchControls: touch,
      onCycleTarget: onCycleTarget,
      child: MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(value: bloc, child: const HudOverlay()),
        ),
      ),
    );
  }

  /// Eylem düğmesindeki yazı — "HEDEF" HUD'da ayrıca bir satır etiketi
  /// olarak da geçiyor, ikisini karıştırmamak gerek.
  Finder action(String label) =>
      find.descendant(of: find.byType(TouchAction), matching: find.text(label));

  /// Yatay telefon; SafeArea'sız ölçüler, en dar gerçekçi durum.
  void landscapePhone(WidgetTester tester, {double width = 667}) {
    tester.view
      ..physicalSize = Size(width, 375)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('çubuk', () {
    testWidgets('yön ve büyüklük üretir, bırakılınca SIFIRLANIR', (
      tester,
    ) async {
      final produced = <Vec2>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Joystick(size: 100, onAxis: produced.add)),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(Joystick));
      // Sağa TAM açılım: merkezden 50 piksel, yarıçapın tamamı.
      await tester.drag(find.byType(Joystick), const Offset(50, 0));
      await tester.pumpAndSettle();

      expect(produced, isNotEmpty);
      // Son değer bırakma: sıfır. Sondan bir önceki, sürüklenen yön.
      expect(produced.last, Vec2.zero, reason: 'çubuk bırakılınca durmalı');
      final dragged = produced[produced.length - 2];
      expect(dragged.x, greaterThan(0.8), reason: 'sağa tam açılım');
      expect(dragged.y.abs(), lessThan(0.05));
      expect(centre, isNotNull);
    });

    testWidgets('ölü bölge: küçük dokunuş gemiyi SÜRÜKLEMEZ', (tester) async {
      // Bu eşik olmadan bırakılmış bir çubuk bile gemiyi kaydırıyor ve oyuncu
      // "kendi kendine gidiyor" diyor.
      final produced = <Vec2>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Joystick(size: 100, onAxis: produced.add)),
          ),
        ),
      );
      await tester.drag(find.byType(Joystick), const Offset(4, 0));
      await tester.pumpAndSettle();
      expect(produced.every((v) => v.isZero), isTrue);
    });
  });

  group('düzen', () {
    testWidgets('dokunmatikte çubuk ve düğmeler var, hata ayıklama YOK', (
      tester,
    ) async {
      landscapePhone(tester);
      await tester.pumpWidget(hud(touch: true));
      await tester.pump();

      expect(find.byType(Joystick), findsOneWidget);
      expect(action('HEDEF'), findsOneWidget);
      expect(action('İTKİ'), findsOneWidget);
      expect(
        find.byKey(hudBoostKey),
        findsNothing,
        reason: 'masaüstü düğme satırı parmak alanını yemesin',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('masaüstünde çubuk YOK, düğme satırı var', (tester) async {
      await tester.pumpWidget(hud(touch: false));
      await tester.pump();
      expect(find.byType(Joystick), findsNothing);
      // `HASAR`/`ONAR` kaldırıldı: hata ayıklama komutlarıydı ve `ONAR` ölü
      // bir gemiyi tam sağlıkla geri getiriyordu. Masaüstü satırında gerçek
      // bir oyun eylemi kaldı.
      expect(find.byKey(hudBoostKey), findsOneWidget);
    });

    testWidgets('harita YUKARIDA, hayati değerlerle aynı hizada', (
      tester,
    ) async {
      // Aşağısı artık parmakların; altta duran bir harita elin altında kalır.
      await tester.pumpWidget(hud(touch: true));
      landscapePhone(tester, width: 812);
      await tester.pump();

      final map = tester.getRect(find.byType(Minimap));
      final deck = tester.getRect(find.byType(Joystick));
      expect(
        map.bottom,
        lessThan(deck.top),
        reason: 'harita güvertenin ÜSTÜNDE',
      );
      expect(map.top, lessThan(120), reason: 'harita ekranın üst bandında');
    });

    for (final width in [667.0, 812.0]) {
      testWidgets('${width.round()}×375 yatay telefonda TAŞMAZ', (
        tester,
      ) async {
        landscapePhone(tester, width: width);
        await tester.pumpWidget(hud(touch: true));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('DİKEY ekranda oyun değil çevirme uyarısı çıkar', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(375, 812)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(hud(touch: true));
      await tester.pump();

      expect(find.byType(RotateHint), findsOneWidget);
      expect(
        find.byType(Joystick),
        findsNothing,
        reason: 'dikeyde menzilin yarısı görünmüyor; oynatmak yanlış olurdu',
      );
    });

    testWidgets('masaüstü dikey pencerede uyarı ÇIKMAZ', (tester) async {
      // Dar bir masaüstü penceresi telefon değildir.
      tester.view
        ..physicalSize = const Size(375, 812)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(hud(touch: false));
      await tester.pump();
      expect(find.byType(RotateHint), findsNothing);
    });
  });

  group('katlanan panel', () {
    testWidgets('dokunmatikte panel İKONA iner ve geri açılır', (tester) async {
      landscapePhone(tester);
      await tester.pumpWidget(hud(touch: true));
      await tester.pump();

      // Mobilde varsayılan KATLI: açılışta karşılayan şey oyun olmalı.
      expect(find.byKey(hudBadgeKey), findsOneWidget);
      expect(find.text('GÖVDE'), findsNothing);

      await tester.tap(find.byKey(hudBadgeKey));
      await tester.pump();
      expect(find.text('GÖVDE'), findsOneWidget, reason: 'rozet paneli açmalı');

      await tester.tap(find.byKey(hudCollapseKey));
      await tester.pump();
      expect(
        find.text('GÖVDE'),
        findsNothing,
        reason: 'katlanan panel dikey alanı bırakmalı',
      );
    });

    testWidgets('panel katlanınca harita KAYMAZ', (tester) async {
      // İlk düzende ikisi aynı esneklik havuzunu paylaşıyordu ve panel
      // küçülünce harita yer değiştiriyordu.
      landscapePhone(tester);
      await tester.pumpWidget(hud(touch: true));
      await tester.pump();

      final collapsed = tester.getRect(find.byType(Minimap));
      await tester.tap(find.byKey(hudBadgeKey));
      await tester.pump();
      expect(
        tester.getRect(find.byType(Minimap)),
        collapsed,
        reason: 'haritanın yeri panelin boyuna bağlı olmamalı',
      );
    });

    testWidgets('mobilde HUD ekranın KENARLARINA yaslanır', (tester) async {
      landscapePhone(tester);
      await tester.pumpWidget(hud(touch: true));
      await tester.pump();

      final screen = tester.getSize(find.byType(HudOverlay));
      final map = tester.getRect(find.byType(Minimap));
      final stick = tester.getRect(find.byType(Joystick));
      expect(map.right, closeTo(screen.width - 8, 0.5));
      expect(map.top, closeTo(8, 0.5));
      expect(stick.left, closeTo(8, 0.5));
      expect(stick.bottom, closeTo(screen.height - 8, 0.5));
    });

    testWidgets('masaüstünde katlama düğmesi YOK', (tester) async {
      await tester.pumpWidget(hud(touch: false));
      await tester.pump();
      expect(find.text('GÖVDE'), findsOneWidget);
      expect(find.byKey(hudCollapseKey), findsNothing);
    });
  });

  testWidgets('çubuk ekseni GEMİYE yazar', (tester) async {
    // Bağın kendisi: HUD'daki parmak, klavyenin yazdığı ALANIN aynısına
    // yazmalı. İki girdi yolu ayrı alanlara yazsaydı uçuş iki yerde
    // tanımlanmış olurdu.
    final idle = NetClient(uri: Uri.parse('ws://127.0.0.1:1'))
      ..ship = PredictedShip(
        world: GameWorld.standard,
        initial: ShipSimState.spawn(
          ShipStats.bastion,
          GameWorld.standard.centre,
        ),
      );
    addTearDown(idle.dispose);

    final bloc = ShipBloc();
    addTearDown(bloc.close);

    landscapePhone(tester);
    await tester.pumpWidget(
      AppScope(
        client: idle,
        frames: FrameMonitor(),
        touchControls: true,
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(value: bloc, child: const HudOverlay()),
          ),
        ),
      ),
    );
    // Bloc'u dünyaya sok ki HUD perde yerine güverteyi kursun.
    bloc.add(
      ShipSynced(
        phase: NetPhase.playing,
        state: ShipSimState.spawn(ShipStats.bastion, GameWorld.standard.centre),
        world: GameWorld.standard,
        viewSize: const Vec2(3200, 2100),
      ),
    );
    await tester.pump();

    expect(idle.ship!.axis, Vec2.zero);
    await tester.drag(find.byType(Joystick), const Offset(0, -55));
    await tester.pump();
    // Sürükleme bitti: eksen sıfırlanmış olmalı, ama ARADA kuzeye gitmişti.
    expect(idle.ship!.axis, Vec2.zero, reason: 'bırakılınca durmalı');

    // Bu kez bırakmadan bak.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Joystick)),
    );
    await gesture.moveBy(const Offset(0, -55));
    await tester.pump();
    expect(
      idle.ship!.axis.y,
      lessThan(-0.5),
      reason: 'çubuk yukarı itilince gemi kuzeye gitmeli',
    );
    await gesture.up();
    await tester.pump();
    expect(idle.ship!.axis, Vec2.zero);
  });

  testWidgets('HEDEF düğmesi oyunun hedef döngüsünü çağırır', (tester) async {
    // Düğme HUD'da, döngü oyunda; ikisini kompozisyon kökü bağlıyor.
    var calls = 0;
    landscapePhone(tester);
    await tester.pumpWidget(hud(touch: true, onCycleTarget: () => calls++));
    await tester.pump();

    await tester.tap(action('HEDEF'));
    await tester.pump();
    expect(calls, 1);
  });
  group('hayati değerler paneli TAŞMAZ', () {
    // GERÇEK bir hataydı ve paket testinde yakalandı: satır `Spacer`
    // kullandığı için iki metin de doğal genişliğinde kalıyordu. Ping üç
    // haneye çıktığında (yüklü makinede ya da kötü bağlantıda — yani oyuncunun
    // HUD'a en çok baktığı anda) 230 piksellik satır 15 piksel taşıyor ve
    // ekranda sarı-siyah şerit çıkıyordu.
    for (final ping in [0, 42, 137, 999, 4321, 99999]) {
      testWidgets('ping $ping ms ile taşma YOK', (tester) async {
        landscapePhone(tester);
        await tester.pumpWidget(hud(touch: false, pingMs: ping, nearby: 64));
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '$ping ms ping paneli taşırdı',
        );
      });
    }

    testWidgets('dokunmatik katlanmış panelde de taşma YOK', (tester) async {
      landscapePhone(tester);
      await tester.pumpWidget(hud(touch: true, pingMs: 4321, nearby: 64));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dört haneli ping TAVANLANIR — satır okunur kalır', (
      tester,
    ) async {
      // Dört haneli ping "bağlantı koptu" demek; okunacak bir sayı değil.
      landscapePhone(tester);
      await tester.pumpWidget(hud(touch: false, pingMs: 4321, nearby: 3));
      await tester.pump();
      expect(find.textContaining('999+ ms'), findsOneWidget);
      expect(find.textContaining('4321'), findsNothing);
    });
  });
}
