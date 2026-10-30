@Tags(['disi'])
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app_scope.dart';
import 'package:voidspace3/game/voidspace_game.dart';
import 'package:voidspace3/hud/hud_overlay.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/perf/frame_monitor.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace_server/gateway.dart';

import 'game_harness.dart';

/// HUD ile oyunun GİRDİ sınırı.
///
/// Bir kez gerçekten kırıldı: düğmeler vuruş testine kapalı olmadığı için hem
/// tetiklenmiyorlardı hem de tıklama altındaki dünyaya sızıp gemiye "oraya uç"
/// emri veriyordu. Tarayıcıda yakalanan bir hataydı; artık burada kilitli.
///
/// Test gerçek bir sunucuya bağlanıyor, çünkü HUD artık bağlantı olmadan
/// perdeyle kapalı — ve o perde de test edilmesi gereken bir davranış:
/// **tek oyunculu bir geri düşüş yok ve olmamalı.**
void main() {
  testWidgets(
    'HUD düğmesi sunucuya ulaşır ve tıklama oyuna SIZMAZ',
    (tester) async {
      late Gateway gateway;
      late NetClient net;
      // `runAsync`: sunucunun tiki GERÇEK zamanlayıcıda koşuyor, widget testinin
      // sahte saatiyle ilerletilemez.
      await tester.runAsync(() async {
        gateway = await bootServer();
        net = await connectClient(gateway, 'Ada');
        await awaitPlaying([net]);
        // Atlas GERÇEK zamanda çözülmeli: `rootBundle` ve görüntü kod çözücüsü
        // widget testinin sahte saatiyle ilerlemez. Bir kez çözülüp
        // önbelleklendiği için oyunun `onLoad`'u sonra anında bulur.
        await warmAtlas();
      });
      addTearDown(() async {
        net.dispose();
        await gateway.stop();
      });

      final bloc = ShipBloc();
      addTearDown(bloc.close);
      final game = VoidspaceGame(
        net: net,
        shipBloc: bloc,
        devicePixelRatio: testDevicePixelRatio,
      );

      await tester.pumpWidget(
        AppScope(
          client: net,
          frames: FrameMonitor(),
          child: MaterialApp(
            home: BlocProvider.value(
              value: bloc,
              child: Scaffold(
                body: GameWidget<VoidspaceGame>(
                  game: game,
                  overlayBuilderMap: {'hud': (_, _) => const HudOverlay()},
                  initialActiveOverlays: const ['hud'],
                ),
              ),
            ),
          ),
        ),
      );
      // Oyun döngüsünün ağ fazını Bloc'a taşıması için KOŞULA KADAR pompala.
      //
      // Sabit sayıda kare pompalamak bu testi bir zamanlama yarışına sokuyordu:
      // paket tam koşusunda, makine yüklüyken ~%40 kırmızı; tek başına daima
      // yeşil. Kırılgan test, gerçek hatalara olan güveni de yanında götürür.
      await pumpUntilFound(tester, find.byKey(hudBoostKey));

      final ship = gateway.zone.ships.values.single;
      final before = ship.state.boostCharges;

      await tester.tap(find.byKey(hudBoostKey));
      await tester.runAsync(() => pump([net], 0.6));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }

      // İddia SUNUCUDA doğrulanıyor: düğme istemcide bir şey göstermiş olabilir,
      // önemli olan niyetin OTORİTEYE ulaşması ve şarjı ORADA harcaması.
      //
      // Bu test eskiden `HASAR` düğmesini kullanıyordu; o düğme bir hata
      // ayıklama komutu yolluyordu ve komut artık üretimde kapalı (`ONAR` ölü
      // bir gemiyi tam sağlıkla geri getiriyordu). Gerçek bir oyun girdisiyle
      // ölçmek zaten daha doğruydu: sınanan yol artık oyuncuların kullandığı yol.
      expect(
        ship.state.boostCharges,
        lessThan(before),
        reason: 'düğme tetiklenmedi ya da sunucuya ulaşmadı',
      );

      // Tıklama dünyaya sızsaydı gemi düğmenin bulunduğu köşeye bir hedef alırdı.
      expect(
        net.ship!.state.target,
        isNull,
        reason: 'HUD tıklaması gemiye hareket emri verdi',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets('bağlantı yokken oyun PERDE arkasında kalır', (tester) async {
    // Tek oyunculu geri düşüş yok: çevrimdışı uçurulan bir gemi, bağlantı
    // gelince sunucununkiyle uzlaştırılamaz.
    final net = NetClient(uri: Uri.parse('ws://127.0.0.1:1'));
    addTearDown(net.dispose);
    final bloc = ShipBloc();
    addTearDown(bloc.close);

    await tester.pumpWidget(
      AppScope(
        client: net,
        frames: FrameMonitor(),
        child: MaterialApp(
          home: BlocProvider.value(value: bloc, child: const HudOverlay()),
        ),
      ),
    );

    expect(find.text('BAĞLANILIYOR'), findsOneWidget);
    expect(find.byKey(hudBoostKey), findsNothing);
  });
}
