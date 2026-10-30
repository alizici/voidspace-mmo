@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// RAF SUNUCUNUN BANDINDAN (15.2).
///
/// İstemci rafı gösteriyor, sunucu satıyor; ikisi aynı bandı okumak zorunda
/// ve bandı sunucu biliyor: oyuncunun bulunduğu haritanın bölgesi. Ölçülen,
/// alım yolunun raftan geçtiği — bandın üstü reddediliyor, alınan eşya taban,
/// fiyat 15.2'nin modeli.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_raf'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(Gateway, WebSocket, Hangar)> kur() async {
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
    // Raf 15.2'nin fiyatını istiyor, başlangıç kredisi yetmiyor (B21).
    hangar.earn(
      Currency.credit,
      1 << 30,
      reason: LedgerReason.signup,
      txId: 'fon',
      atMillis: 0,
    );
    return (gateway, socket, hangar);
  }

  void al(WebSocket socket, String specId) => socket.add(
    ClientHangar(action: 'buy_item', payload: {'specId': specId}).encode(),
  );

  // KARAR 15.2 s1
  test('raftan alınan eşya taban, fiyat modelin, band sunucunun', () async {
    final (gateway, socket, hangar) = await kur();
    final para = hangar.credits;
    al(socket, 'pl1');
    await _until(() => hangar.inventory.length > 1);
    final alinan = hangar.inventory.values.firstWhere(
      (i) => i.instanceId != 'starter_laser',
    );
    expect(alinan.specId, 'pl1');
    expect(alinan.taban, isTrue, reason: 'raftan gelen eşya taban değil');
    final band = gateway.zone.bolge.ilkRank;
    expect(
      hangar.credits,
      para - Catalogue.rafFiyati(band).amount,
      reason: 'fiyat 15.2 modelinden değil',
    );
  });

  // KARAR 10.7 s1
  test('bandın üstü raftan alınamıyor — açılış sırası atlanamaz', () async {
    final (_, socket, hangar) = await kur();
    final para = hangar.credits;
    // Önce bandın üstü, sonra bandın kendisi: ikincisi gelince birincisi
    // çoktan işlenmiş oluyor, sıra korunuyor.
    al(socket, 'pl3');
    al(socket, 'pl1');
    await _until(() => hangar.inventory.length > 1);
    expect(
      hangar.inventory.values.any((i) => i.specId == 'pl3'),
      isFalse,
      reason: 'C-II lazer raftan alındı',
    );
    expect(hangar.credits, para - Catalogue.rafFiyati(0).amount);
    expect(
      Acilis.acik(Sistem.artiBasma, hangar),
      isFalse,
      reason: 'raf açılış sırasını atlattı',
    );
  });
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
