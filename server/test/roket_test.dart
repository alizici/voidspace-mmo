@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// ROKET SUNUCUDA (18): kendi beklemesi, ayrı olay, salvo başına bir birim.
void main() {
  final world = GameWorld.standard;

  /// Roketatarlı bir gemi: bir lazer ve MK-1; kritik kapalı, sayı düz olsun.
  ShipStats donanimli() {
    final h = Hangar(accountId: 'a', credits: 1);
    h.addItem(const ItemInstance(instanceId: 'l', specId: 'pl1'));
    h.addItem(const ItemInstance(instanceId: 'r', specId: 'mk1'));
    h.activeLoadout
      ..equip(const SlotRef(SlotType.laser, 0), 'l')
      ..equip(const SlotRef(SlotType.launcher, 0), 'r');
    return LoadoutResolver.resolve(
      h.activeLoadout,
      h.inventory,
      Catalogue.byId,
    ).copyWith(critChance: 0);
  }

  /// [saniye] boyunca hedefe ateş eder, roket olaylarını toplar.
  List<ShotEvent> roketler(Zone zone, ServerShip atici, int hedef, double sn) {
    final ticks = (sn * ShipSim.tickRate).ceil();
    final sonuc = <ShotEvent>[];
    for (var t = 0; t < ticks; t++) {
      zone
        ..enqueue(
          atici,
          ShipInput(seq: t + 1, weaponTarget: hedef, firing: true),
        )
        ..step();
      sonuc.addAll(zone.shots.where((s) => s.shooterId == atici.id && s.roket));
    }
    return sonuc;
  }

  group('zincir', () {
    // KARAR 18.2 s1
    test('salvo aralıkla geliyor, tabanı statlardan, ayrı olay', () {
      final zone = Zone(alienCount: 0);
      final stats = donanimli();
      final atici = zone.join('A', stats: stats)!;
      atici.state = atici.state.copyWith(position: world.centre);
      final hedef = zone.join('H', stats: stats)!;
      hedef.state = hedef.state.copyWith(
        position: world.centre + const Vec2(300, 0),
      );
      final olaylar = roketler(zone, atici, hedef.id, 13);
      // On üç saniyede üç salvo: sıfır, altı, on iki.
      expect(olaylar, hasLength(3), reason: 'roket aralığı tutmadı');
      for (final o in olaylar) {
        expect(o.roket, isTrue);
        expect(
          o.damage,
          closeTo(stats.roketHasari * (1 + stats.damageBonus), 1),
          reason: 'salvo tabanı statlardaki değil',
        );
      }
    });

    // KARAR 18.3 s1
    test('RK-2 salvonun tabanını ikiye katlıyor, lazere dokunmuyor', () {
      final zone = Zone(alienCount: 0);
      final stats = donanimli();
      final a = zone.join('A', stats: stats)!;
      a.state = a.state.copyWith(position: world.centre);
      final b = zone.join('B', stats: stats)!
        ..roketId = 'RK-2'
        ..roketCarpani = 2;
      b.state = b.state.copyWith(position: world.centre + const Vec2(0, 600));
      final hedefA = zone.join('HA', stats: stats)!;
      hedefA.state = hedefA.state.copyWith(
        position: world.centre + const Vec2(300, 0),
      );
      final hedefB = zone.join('HB', stats: stats)!;
      hedefB.state = hedefB.state.copyWith(
        position: world.centre + const Vec2(300, 600),
      );
      final bir = roketler(zone, a, hedefA.id, 1).single;
      final iki = roketler(zone, b, hedefB.id, 1).single;
      expect(iki.damage, closeTo(bir.damage * 2, 2));
      // Lazer olayları aynı: roket mermisi lazerin tabanını çarpmaz.
      final lazerA = zone.shots.where((s) => s.shooterId == a.id && !s.roket);
      final lazerB = zone.shots.where((s) => s.shooterId == b.id && !s.roket);
      if (lazerA.isNotEmpty && lazerB.isNotEmpty) {
        expect(lazerB.first.damage, lazerA.first.damage);
      }
    });
  });

  group('hangar', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_roket'));
    tearDown(() => temp.deleteSync(recursive: true));

    Future<(Gateway, WebSocket, Account)> kur() async {
      final gateway = Gateway(
        zone: Zone(alienCount: 0),
        accounts: AccountStore(path: '${temp.path}/a.json'),
      );
      await gateway.start(host: '127.0.0.1', port: 0);
      addTearDown(gateway.stop);
      final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
      addTearDown(socket.close);
      final account = await gateway.accounts.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: 'yeterince-uzun-parola',
      );
      socket.listen((_) {}, onError: (_) {}, onDone: () {});
      socket.add(
        ClientHello(
          protocolVersion: Protocol.version,
          token: gateway.accounts.issueToken(account),
        ).encode(),
      );
      await _until(() => gateway.zone.ships.isNotEmpty);
      return (gateway, socket, account);
    }

    // KARAR 18.4 s1
    test('RK-1 satılmıyor, RK-2 alınıyor ve seçim ANINDA gemide', () async {
      final (gateway, socket, account) = await kur();
      final hangar = gateway.hangars.of(account.id)
        ..earn(
          Currency.credit,
          1 << 30,
          reason: LedgerReason.signup,
          txId: 'fon',
          atMillis: 0,
        );
      final para = hangar.credits;
      final gemi = gateway.zone.ships.values.single;
      socket.add(
        const ClientHangar(
          action: 'roket_al',
          payload: {'roketId': 'RK-1', 'adet': 10},
        ).encode(),
      );
      socket.add(
        const ClientHangar(
          action: 'roket_al',
          payload: {'roketId': 'RK-2', 'adet': 10},
        ).encode(),
      );
      await _until(() => hangar.roketSayisi('RK-2') == 10);
      expect(hangar.roketSayisi('RK-1'), 0, reason: 'bedava roket stoklandı');
      expect(hangar.credits, para - Roket.byId('RK-2')!.fiyatFor(10));

      socket.add(
        const ClientHangar(
          action: 'roket_sec',
          payload: {'id': 'RK-2'},
        ).encode(),
      );
      await _until(() => gemi.roketCarpani == 2);
      expect(gemi.roketId, 'RK-2');
    });
  });
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
