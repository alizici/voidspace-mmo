@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app_scope.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/unvan_satiri.dart';
import 'package:voidspace3/hud/hud_overlay.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/perf/frame_monitor.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace3/ship/ship_event.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// UNVAN VE SEVİYE EKRANDA — sunucunun söylediği, istemcinin yazdığı.
///
/// Sunucu unvanı, adını ve seviyeyi hangar durumuyla gönderiyor (10.1,
/// 10.4); uzun süre gönderdi ve hiçbir ekran çizmedi (borç defteri B11).
/// Burada ölçülen: hangar başlığı ve HUD paneli sunucunun yolladığı adı
/// olduğu gibi gösteriyor, kendisi türetmiyor — ad sahte ve puana uymuyor,
/// ekranda yine o okunmalı.
void main() {
  /// Sunucunun `_hangarJson`'u ile aynı şemada, AĞSIZ bir istemci. Unvan adı
  /// puanla uyumsuz seçildi: istemci puandan türetseydi başka bir ad yazardı.
  NetClient istemci({String unvanAdi = 'Bishop IV'}) {
    final hangar = Hangar(
      accountId: 'a',
      credits: 1200,
      hulls: [HullClass.starter.id],
      activeHullId: HullClass.starter.id,
    );
    return NetClient(uri: Uri.parse('ws://test'))
      ..hangar = HangarView.fromJson({
        ...hangar.toJson(),
        'effective': ServerHangarState.effectiveOf(ShipStats.bastion),
        'br': 4200.0,
        'seviye': 7,
        'unvan': 33,
        'unvanAdi': unvanAdi,
      });
  }

  // KARAR 10.4 s2
  testWidgets('hangar başlığı sunucunun unvanını yazıyor', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = istemci();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: c, onClose: () {}),
      ),
    );
    await tester.pump();

    final satir = tester.widget<UnvanSatiri>(find.byKey(hangarUnvanKey));
    expect(satir.kisa, isFalse, reason: 'geniş pencerede satırın tamamı');
    // Ad ve ölçüler AYRI iki yazı (10.4 s2): adın kendi tipografisi var,
    // seviye ile puan sabit birer sayı ve o stile girmiyor.
    expect(find.text('BISHOP IV'), findsOneWidget);
    expect(find.text('· SEVİYE 7 · 4.200 BR'), findsOneWidget);
  });

  testWidgets('dar pencerede yalnız unvan', (tester) async {
    // Seviye ve puan geçit isteminde ve HUD'da zaten okunuyor; dar başlıkta
    // sekmeleri ezmesinler.
    tester.view
      ..physicalSize = const Size(560, 620)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = istemci();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: c, onClose: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('BISHOP IV'), findsOneWidget);
    expect(find.textContaining('SEVİYE'), findsNothing);
  });

  // KARAR 10.1 s1
  testWidgets('HUD paneli unvan, seviye ve puanı yazıyor', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = istemci();
    addTearDown(c.dispose);
    final bloc = ShipBloc()
      ..add(
        ShipSynced(
          phase: NetPhase.playing,
          state: ShipSimState.spawn(
            ShipStats.bastion,
            GameWorld.standard.centre,
          ),
          world: GameWorld.standard,
          viewSize: const Vec2(3200, 2100),
          pingMs: 41,
          nearby: 1,
        ),
      );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      AppScope(
        client: c,
        frames: FrameMonitor(),
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(value: bloc, child: const HudOverlay()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(hudUnvanKey), findsOneWidget);
    expect(find.text('BISHOP IV'), findsOneWidget);
    expect(find.text('· SEVİYE 7 · 4.200 BR'), findsOneWidget);
  });

  testWidgets('sunucu ad yollamadıysa satır yok', (tester) async {
    // Boş bir unvan yer tutucu değil yanlış bilgi olurdu; bağlantının ilk
    // karesinde satır hiç çizilmiyor.
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = istemci(unvanAdi: '');
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: c, onClose: () {}),
      ),
    );
    await tester.pump();
    expect(find.textContaining(' BR'), findsNothing);
    expect(find.textContaining('SEVİYE'), findsNothing);
  });
}
