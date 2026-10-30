@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hud/reward_feed.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

import 'game_harness.dart';

/// GANİMET BİLDİRİMİ — düşen şey ekrana düşüyor mu.
///
/// Sunucu düşeni hangara yazıyor ve hangar durumunu yolluyordu; HUD yalnız
/// krediyi gösteriyordu. Oyuncu bir malzeme kazandığını ancak hangara girip
/// sayacı görünce anlıyordu: geri bildirim değil, keşif. Ölçülen: gerçek bir
/// imhadan düşen malzeme, sunucunun söylediği adla ödül şeridinde.
///
/// Malzeme seçildi çünkü her imhada düşüyor (14.1); eşya şansa bağlı ve
/// sıradan yaratıkta yüzde bir. Eşya listesinin telden geçişi çekirdekte,
/// sunucunun doğru listeyi yolladığı sunucu testinde ölçülüyor.
void main() {
  Future<void> until(bool Function() condition, {String? reason}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError(reason ?? 'koşul sağlanmadı');
  }

  /// Menzilde, tek yaylımda ölecek bir KADRO yaratığı; `economy_test.dart`
  /// ile aynı sebeple girdi kuyruğa bırakılıyor: imhayı sunucunun kendi tiki
  /// çözmeli, ödül listesi her adımın başında temizleniyor.
  ///
  /// Spore DEĞİL: ganimet kadrodan doğan yaratığa bağlı (14.1), kadroda
  /// olmayan eski tür kredi verir ama hiçbir şey düşürmez. Dünyanın kendi
  /// doğurduğu bir yaratık alınıp canı bire indiriliyor ve geminin yanına
  /// getiriliyor.
  int placeWeakAlien(Zone zone, NetClient shooter, {required double near}) {
    final ship = zone.ships.values.firstWhere((s) => s.id == shooter.entityId);
    final id = zone.aliens.keys.firstWhere(
      (k) =>
          k != zone.bossId &&
          YaratikKadrosu.byKind(zone.aliens[k]!.stats.kind) != null,
    );
    zone.aliens[id] = zone.aliens[id]!.copyWith(
      hull: 1,
      position: ship.state.position + Vec2(near, 0),
    );
    zone.enqueue(ship, ShipInput(seq: 900, weaponTarget: id, firing: true));
    return id;
  }

  // KARAR 14.1 s1
  testWidgets('düşen MALZEME ödül şeridine düşer — adıyla', (tester) async {
    late Gateway gateway;
    late NetClient client;
    // Gerçek soket `runAsync` içinde: widget testinin sahte saati altında
    // `Future.delayed` hiç tamamlanmıyor.
    await tester.runAsync(() async {
      gateway = await bootServer();
      client = await connectClient(gateway, 'Ada');
      await awaitPlaying([client]);
      await until(() => client.hangar != null);
    });
    addTearDown(gateway.stop);
    addTearDown(client.dispose);

    // Şerit İMHADAN ÖNCE kuruluyor: bildirim bir olay, kuyruğu şerit
    // boşaltıyor. Sonradan kurulan şerit olayı görür ama gerçek oyunda da
    // şerit hep önce var.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RewardFeed(client: client)),
      ),
    );
    await tester.pump();

    await tester.runAsync(() async {
      placeWeakAlien(gateway.zone, client, near: 400);
      // Ganimet mesajı hangar durumundan ÖNCE gidiyor; stok göründüğünde
      // bildirim çoktan işlenmiş oluyor.
      await until(
        () => client.hangar!.malzemeler.isNotEmpty,
        reason: 'imha malzeme düşürmedi',
      );
    });
    await tester.pump();

    final id = client.hangar!.malzemeler.keys.single;
    final malzeme = Malzeme.byId(id)!;
    expect(
      find.byKey(hudGanimetKey(id)),
      findsOneWidget,
      reason: 'düşen malzeme şeritte yok — görülmeyen ödül, olmayan ödül',
    );
    expect(
      find.textContaining(malzeme.ad.toUpperCase()),
      findsOneWidget,
      reason: 'malzemenin adı yazılmıyor',
    );
  });
}
