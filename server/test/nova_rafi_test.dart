@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// NOVA RAFI SUNUCUDA (15.7).
///
/// Kredi rafından ayrı bir yol: `nova_al` tasarımın kendi NOVA fiyatını
/// kesiyor ve bandı sormuyor. Ölçülen, alımın gerçekten NOVA kasasından
/// geçtiği ve kredi rafının bu yoldan satılamadığı.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_nova'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(WebSocket, Hangar)> kur({int nova = 0}) async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);
    final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    addTearDown(socket.close);
    socket.listen((_) {}, onError: (_) {}, onDone: () {});
    final account = await gateway.accounts.register(
      email: 'ada@test.local',
      username: 'Ada',
      password: 'yeterince-uzun-parola',
    );
    socket.add(
      ClientHello(
        protocolVersion: Protocol.version,
        token: gateway.accounts.issueToken(account),
      ).encode(),
    );
    await _until(() => gateway.zone.ships.isNotEmpty);
    final hangar = gateway.hangars.of(account.id);
    if (nova > 0) {
      hangar.earn(
        Currency.premium,
        nova,
        reason: LedgerReason.signup,
        txId: 'fon',
        atMillis: 0,
      );
    }
    return (socket, hangar);
  }

  void al(WebSocket socket, String specId) => socket.add(
    ClientHangar(action: 'nova_al', payload: {'specId': specId}).encode(),
  );

  // KARAR 15.7 s1
  test('elit droid NOVA ile alınıyor: kasa NOVA, eşya taban', () async {
    final droid = Catalogue.novaRafi.singleWhere(
      (s) => s.slot == SlotType.droid,
    );
    final (socket, hangar) = await kur(nova: 1 << 20);
    final once = hangar.premium;
    final krediOnce = hangar.credits;

    al(socket, droid.id);
    await _until(
      () => hangar.inventory.values.any((i) => i.specId == droid.id),
    );

    final alinan = hangar.inventory.values.firstWhere(
      (i) => i.specId == droid.id,
    );
    expect(alinan.taban, isTrue, reason: 'NOVA rafı alt statlı eşya sattı');
    expect(hangar.premium, once - Catalogue.priceOf(droid).amount);
    expect(hangar.credits, krediOnce, reason: 'kredi kasasına dokunuldu');
  });

  // KARAR 15.7 s1
  test('kredi rafının tasarımı bu yoldan alınamıyor', () async {
    final (socket, hangar) = await kur(nova: 1 << 20);
    final once = hangar.premium;
    al(socket, 'dr1');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(hangar.inventory.values.any((i) => i.specId == 'dr1'), isFalse);
    expect(hangar.premium, once);
  });

  // KARAR 15.7 s1
  test('NOVA yetmiyorsa alım yok', () async {
    final droid = Catalogue.novaRafi.singleWhere(
      (s) => s.slot == SlotType.droid,
    );
    final (socket, hangar) = await kur();
    // Yeni hesabın başlangıç NOVA'sı rafın fiyatını karşılamamalı; kese yine
    // de boşaltılıyor ki ölçülen şey fiyat değil YETERSİZLİK olsun.
    hangar.spend(
      Currency.premium,
      hangar.premium,
      reason: LedgerReason.purchase,
      txId: 'bosalt',
      atMillis: 0,
    );
    al(socket, droid.id);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(hangar.inventory.values.any((i) => i.specId == droid.id), isFalse);
    expect(hangar.premium, 0);
  });
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
