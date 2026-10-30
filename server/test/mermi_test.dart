@Tags(['disi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// MERMİ — sunucuda çarpan, sifon, tüketim ve düşüş (17).
void main() {
  final world = GameWorld.standard;

  /// Kritiksiz referans: zar olmadan iki vuruş karşılaştırılabiliyor.
  final stats = ShipStats.bastion.copyWith(critChance: 0);

  ServerShip gemi(Zone zone, String ad, Vec2 konum) {
    final s = zone.join(ad, stats: stats)!;
    s.state = s.state.copyWith(position: konum);
    return s;
  }

  ShotEvent yaylim(Zone zone, ServerShip atici, int hedef) {
    final ticks = (stats.laser.fireInterval * ShipSim.tickRate).ceil() + 1;
    for (var t = 0; t < ticks; t++) {
      zone
        ..enqueue(
          atici,
          ShipInput(seq: t + 1, weaponTarget: hedef, firing: true),
        )
        ..step();
      final vurus = zone.shots.where((s) => s.shooterId == atici.id);
      if (vurus.isNotEmpty) return vurus.first;
    }
    throw StateError('yaylım çıkmadı');
  }

  group('zincir', () {
    // KARAR 17.3 s1
    test('MR-2 vuruşu iki katına çıkarıyor — yalnız taban, kritiksiz', () {
      final zone = Zone(alienCount: 0);
      final a = gemi(zone, 'A', world.centre);
      final b = gemi(zone, 'B', world.centre + const Vec2(0, 600))
        ..mermiCarpani = 2
        ..mermiId = 'MR-2';
      final hedefA = gemi(zone, 'HA', world.centre + const Vec2(300, 0));
      final hedefB = gemi(zone, 'HB', world.centre + const Vec2(300, 600));

      final bir = yaylim(zone, a, hedefA.id);
      final iki = yaylim(zone, b, hedefB.id);
      expect(bir.crit, isFalse);
      expect(iki.crit, isFalse);
      expect(iki.damage, closeTo(bir.damage * 2, 2));
    });

    // KARAR 17.6 s1
    test('sifon KALKANA vurur, gövdeye taşmaz', () {
      final zone = Zone(alienCount: 0);
      final atici = gemi(zone, 'S', world.centre)
        ..sifon = true
        ..mermiCarpani = TasarimGirdileri.sifonCarpani.toDouble()
        ..mermiId = 'SF-1';
      final hedef = gemi(zone, 'H', world.centre + const Vec2(300, 0));
      // Kalkanı NEREDEYSE bitmiş hedef: sifonun payı kalkanı aşıyor.
      // `sinceHit: 0` yenilenmeyi kilitliyor; yoksa vuruştan önceki tikte
      // kalkan büyür ve inen hasar on değil yirmi bir çıkar.
      hedef.state = hedef.state.copyWith(shield: 10, sinceHit: 0);
      final govde = hedef.state.hull;

      final vurus = yaylim(zone, atici, hedef.id);
      expect(hedef.state.shield, 0, reason: 'kalkan inmedi');
      expect(hedef.state.hull, govde, reason: 'sifon gövdeye taştı');
      expect(vurus.damage, 10, reason: 'olay ineni değil hesaplananı söyledi');
    });

    // KARAR 17.6 s1
    test('sifon YARATIĞA geminin payını indirmiyor — kalkanı yok', () {
      final zone = Zone(alienCount: 0);
      final atici = gemi(zone, 'S', world.centre)
        ..sifon = true
        ..mermiCarpani = TasarimGirdileri.sifonCarpani.toDouble()
        ..mermiId = 'SF-1';
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.leviathan,
        world.centre + const Vec2(300, 0),
        1,
      );
      final can = zone.aliens[alienId]!.hull;
      final vurus = yaylim(zone, atici, alienId);
      expect(zone.aliens[alienId]!.hull, can);
      expect(vurus.damage, 0);
    });
  });

  group('hangar', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_mermi'));
    tearDown(() => temp.deleteSync(recursive: true));

    Future<(Gateway, WebSocket, List<Uint8List>, Account)> kur() async {
      final gateway = Gateway(
        zone: Zone(alienCount: 0),
        accounts: AccountStore(path: '${temp.path}/a.json'),
      );
      await gateway.start(host: '127.0.0.1', port: 0);
      addTearDown(gateway.stop);
      final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
      final account = await gateway.accounts.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: 'yeterince-uzun-parola',
      );
      final gelen = <Uint8List>[];
      socket.listen(
        (d) => gelen.add(Uint8List.fromList(d as List<int>)),
        onError: (_) {},
        onDone: () {},
      );
      socket.add(
        ClientHello(
          protocolVersion: Protocol.version,
          token: gateway.accounts.issueToken(account),
        ).encode(),
      );
      await _until(() => gateway.zone.ships.isNotEmpty);
      return (gateway, socket, gelen, account);
    }

    // KARAR 17.2 s1
    test('MR-1 satılmıyor, MR-2 krediyle alınıyor', () async {
      final (gateway, socket, _, account) = await kur();
      final hangar = gateway.hangars.of(account.id);
      final para = hangar.credits;

      socket.add(
        const ClientHangar(
          action: 'mermi_al',
          payload: {'mermiId': 'MR-1', 'adet': 10},
        ).encode(),
      );
      socket.add(
        const ClientHangar(
          action: 'mermi_al',
          payload: {'mermiId': 'MR-2', 'adet': 10},
        ).encode(),
      );
      await _until(() => hangar.mermiSayisi('MR-2') == 10);
      expect(hangar.mermiSayisi('MR-1'), 0, reason: 'bedava mermi stoklandı');
      expect(hangar.credits, para - Mermi.byId('MR-2')!.fiyatFor(10));
    });

    // KARAR 17.8 s1
    test('seçim ANINDA gemiye geçiyor; stoksuz seçim reddediliyor', () async {
      final (gateway, socket, gelen, account) = await kur();
      final hangar = gateway.hangars.of(account.id);
      final gemi = gateway.zone.ships.values.single;
      hangar.mermiEkle('MR-3', 5);

      socket.add(
        const ClientHangar(
          action: 'mermi_sec',
          payload: {'id': 'MR-3'},
        ).encode(),
      );
      await _until(() => gemi.mermiCarpani == 3);
      expect(gemi.mermiId, 'MR-3');
      expect(gemi.sifon, isFalse);

      gelen.clear();
      socket.add(
        const ClientHangar(
          action: 'mermi_sec',
          payload: {'id': 'MR-5'},
        ).encode(),
      );
      await _until(() => _hataVar(gelen));
      expect(hangar.seciliMermi.id, 'MR-3', reason: 'stoksuz mermi seçildi');
      expect(gemi.mermiCarpani, 3);
    });

    // KARAR 17.8 s1
    test('yaylım namlu başına harcıyor; biten mermi MR-1\'e düşüyor', () async {
      final (gateway, _, _, account) = await kur();
      final hangar = gateway.hangars.of(account.id);
      final gemi = gateway.zone.ships.values.single;
      final namlu = gemi.state.stats.equippedLasers;
      // İki yaylımlık stok, artı bir: ilk yaylım namlu kadar düşürür, üçüncü
      // yaylım kalanı bitirir ve seçim düşer.
      hangar
        ..mermiEkle('MR-2', namlu * 2 + 1)
        ..mermiSec('MR-2');
      await _until(() => gateway.zone.ships.isNotEmpty);
      // Seçim hangara doğrudan yazıldı: gemiye geçmesi için donatım yolu.
      gateway.zone.ships.values.single
        ..mermiId = 'MR-2'
        ..mermiCarpani = 2;

      const alienId = Protocol.alienIdBase + 1;
      gateway.zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.leviathan,
        gemi.state.position + const Vec2(300, 0),
        1,
      );
      var seq = 0;
      Future<void> atesEt(bool Function() bitti) => _until(() {
        gateway.zone.enqueue(
          gemi,
          ShipInput(seq: ++seq, weaponTarget: alienId, firing: true),
        );
        return bitti();
      });

      await atesEt(() => hangar.mermiSayisi('MR-2') == namlu + 1);
      await atesEt(() => hangar.mermiSayisi('MR-2') == 0);
      await _until(() => gemi.mermiCarpani == 1);
      expect(hangar.seciliMermi.id, 'MR-1');
      expect(gemi.mermiId, 'MR-1');
    });
  });
}

bool _hataVar(List<Uint8List> gelen) => gelen.any((b) {
  if (b.isEmpty) return false;
  final m = ServerMessage.decode(b);
  return m is ServerHangarState && m.json['error'] != null;
});

Future<void> _until(bool Function() ready, {Duration? timeout}) async {
  final limit = timeout ?? const Duration(seconds: 5);
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > limit) throw StateError('koşul gerçekleşmedi');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
