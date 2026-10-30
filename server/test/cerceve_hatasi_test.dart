@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/hangars.dart';
import 'package:voidspace_server/zone.dart';

/// BİR OTURUMUN HATASI SUNUCUYU DÜŞÜRMÜYOR.
///
/// Yaşanan: kalkan jeneratörü takılmış bir droid stat çözümünü patlatıyordu.
/// İstisna dinleyicinin içinden bölgeye çıkıyor, süreç ölüyordu — o anda
/// dövüşen HERKES atılıyordu. Üstelik bozuk durum diskte kaldığı için sunucu
/// her açılışta aynı oyuncunun `hello`'sunda yeniden ölüyordu.
///
/// Ölçülen, hatanın kendisi değil KAPSANMASI: hangi kusur olursa olsun
/// yalnız onu yaşayan oturum kapanmalı, sunucu ve öteki oyuncular ayakta
/// kalmalı. Kusur burada diskten geliyor (yazılamayan hangar dosyası),
/// çünkü sınanan şey nedeni değil sonucu.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_cerceve'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('yazılamayan hangar tek oturumu düşürüyor, sunucu ayakta', () async {
    // Hangar dosyasının ÜST DİZİNİ bir dosya: her kayıt denemesi patlıyor.
    final engel = File('${temp.path}/engel')..writeAsStringSync('x');
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
      hangars: HangarStore(path: '${engel.path}/h.jsonl'),
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);

    Future<(WebSocket, Account)> gir(String ad) async {
      final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
      addTearDown(socket.close);
      socket.listen((_) {}, onError: (_) {}, onDone: () {});
      final account = await gateway.accounts.register(
        email: '$ad@test.local',
        username: ad,
        password: 'yeterince-uzun-parola',
      );
      socket.add(
        ClientHello(
          protocolVersion: Protocol.version,
          token: gateway.accounts.issueToken(account),
        ).encode(),
      );
      return (socket, account);
    }

    final (soket, hesap) = await gir('Ada');
    final (izleyici, _) = await gir('Bora');
    await _until(() => gateway.zone.ships.length == 2);

    // Kaydı patlatan bir hangar eylemi: gemi değiştir.
    final hangar = gateway.hangars.of(hesap.id);
    hangar.addItem(const ItemInstance(instanceId: 'lz', specId: 'pl1'));
    soket.add(
      ClientHangar(
        action: 'equip',
        payload: {'slot': 'laser#0', 'instanceId': 'lz'},
      ).encode(),
    );

    // O oturum kapanıyor…
    await _until(() => soket.closeCode != null);
    // …ama sunucu ayakta ve öteki oyuncu duruyor.
    expect(izleyici.closeCode, isNull, reason: 'ilgisiz oturum da düştü');
    final yeni = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    addTearDown(yeni.close);
    expect(yeni.closeCode, isNull, reason: 'sunucu yeni bağlantı almıyor');
  });
}

Future<void> _until(bool Function() kosul) async {
  for (var i = 0; i < 400; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
