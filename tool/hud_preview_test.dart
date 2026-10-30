import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app_scope.dart';
import 'package:voidspace3/app/palette.dart';
import 'package:voidspace3/hud/hud_overlay.dart';
import 'package:voidspace3/hud/savas_cubugu.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/perf/frame_monitor.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace3/ship/ship_event.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Görsel referans: HUD, telefon ve masaüstü.
///
/// Sunucu YOK; savaş çubuğu ve paneller sahte bir hangar görünümüyle çiziliyor.
/// Ölçülen şey ağ değil DÜZEN: düğmeler nerede, ne kadar yer yiyor, telefonda
/// başparmağa uzak mı.
Future<void> _loadFonts() async {
  // Yazı tipi GERÇEK: `flutter test` Ahem kullanıyor, bütün harfler dolu
  // kare. Düğmenin genişliği ve satırın sığması ancak gerçek harflerle
  // görünüyor. 'Roboto', MaterialApp'in varsayılan ailesi — Palette'in
  // aile vermeyen stilleri oradan okuyor.
  for (final (aile, yollar) in const [
    ('monospace', ['/System/Library/Fonts/Monaco.ttf']),
    ('Roboto', ['/System/Library/Fonts/Supplemental/Arial.ttf']),
  ]) {
    for (final path in yollar) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final loader = FontLoader(aile)
        ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      await loader.load();
      break;
    }
  }
}

const _screens = [
  (name: 'masaustu', size: Size(1280, 720), touch: false),
  (name: 'telefon', size: Size(844, 390), touch: true),
];

NetClient _client() {
  final hangar = Hangar(accountId: 'onizleme', credits: 48600)
    ..mermiEkle('MR-2', 95)
    ..mermiEkle('SF-1', 40)
    ..mermiSec('MR-2')
    ..formasyonId = Formasyon.hepsi[4].id;
  final br = CombatGlossary.battleRating(ShipStats.bastion);
  final unvan = CombatGlossary.unvanIndeksi(br);
  return NetClient(uri: Uri.parse('ws://onizleme'))
    ..hangar = HangarView.fromJson({
      ...hangar.toJson(),
      'effective': ServerHangarState.effectiveOf(ShipStats.bastion),
      // Unvan ve seviye sunucudan gelir (10.1, 10.4); panel onları çiziyor.
      // Seviye sahte: yeni hangarın sayacı sıfır, önizleme dolu satır ister.
      'br': br,
      'seviye': 3,
      'unvan': unvan,
      'unvanAdi': Unvan.adi(unvan),
    });
}

Widget _hud(NetClient client, {required bool touch}) {
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
        pingMs: 41,
        nearby: 2,
      ),
    );
  addTearDown(bloc.close);
  return AppScope(
    client: client,
    frames: FrameMonitor(),
    touchControls: touch,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Palette.space,
        body: BlocProvider.value(value: bloc, child: const HudOverlay()),
      ),
    ),
  );
}

void main() {
  for (final screen in _screens) {
    testWidgets('HUD görsel referansı · ${screen.name}', (tester) async {
      await _loadFonts();
      tester.view
        ..physicalSize = screen.size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const key = ValueKey('hud-preview');
      final client = _client();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _hud(client, touch: screen.touch),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('hud_${screen.name}.png'),
      );

      await tester.tap(find.byKey(hudMermiKey));
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('hud_${screen.name}_mermi.png'),
      );

      await tester.tap(find.byKey(hudFormasyonKey));
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('hud_${screen.name}_formasyon.png'),
      );
    });
  }
}
