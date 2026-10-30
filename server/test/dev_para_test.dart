@Tags(['disi'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// CANLI PARA UCU — `/dev/para`.
///
/// Hangar dosyası sunucu ayaktayken elle düzenlenemez: kayıtlar açılışta
/// belleğe alınıyor ve sıkıştırma dosyayı bellekten yeniden yazıyor. Canlı
/// bakiye değiştirmenin tek doğru yolu sunucudan geçmek; bu uç o yol.
///
/// Ölçülen: iki kapı (hata ayıklama açık + yerel istek), bakiyenin gerçekten
/// artması ve açık oturuma anında yeni hangar durumunun gitmesi.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_para'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(Gateway, Account)> kur({bool debug = true}) async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
      allowDebugCommands: debug,
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);
    final account = await gateway.accounts.register(
      email: 'ada@test.local',
      username: 'Ada',
      password: 'yeterince-uzun-parola',
    );
    return (gateway, account);
  }

  Future<(int, Map<String, Object?>)> iste(
    Gateway gateway,
    String sorgu,
  ) async {
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.postUrl(
      Uri.parse('http://127.0.0.1:${gateway.port}/dev/para?$sorgu'),
    );
    final res = await req.close();
    final govde = await res.transform(utf8.decoder).join();
    return (res.statusCode, jsonDecode(govde) as Map<String, Object?>);
  }

  test('bakiye artıyor ve defterе yazılıyor', () async {
    final (gateway, account) = await kur();
    final hangar = gateway.hangars.of(account.id);
    final krediOnce = hangar.credits;
    final novaOnce = hangar.premium;

    final (kod, govde) = await iste(
      gateway,
      'hesap=Ada&kredi=1000000&nova=5000',
    );
    expect(kod, HttpStatus.ok);
    expect(govde['kredi'], krediOnce + 1000000);
    expect(govde['nova'], novaOnce + 5000);
    expect(hangar.credits, krediOnce + 1000000);
    expect(hangar.premium, novaOnce + 5000);
  });

  test('hata ayıklama KAPALIYKEN uç yok', () async {
    // Kapalı bir uçtan "yetkin yok" bile demiyoruz: var olduğunu söylemek
    // gereksiz.
    final (gateway, _) = await kur(debug: false);
    final (kod, _) = await iste(gateway, 'hesap=Ada&kredi=100');
    expect(kod, HttpStatus.notFound);
    expect(gateway.hangars.of('yok').credits, isNotNull);
  });

  test('VEKİLDEN geçen istek reddediliyor: tünel dünyaya açıyordu', () async {
    // Tünel sunucuya hep 127.0.0.1'den bağlanıyor; soketin yerel olması tek
    // başına yetmiyor. Vekil kendini başlıkla ilan ediyor, uç da onu görünce
    // kapanıyor — yoksa tünel açıldığı an dünyanın herkesi para basardı.
    final (gateway, account) = await kur();
    final once = gateway.hangars.of(account.id).credits;
    final client = HttpClient();
    addTearDown(client.close);

    for (final baslik in ['cf-connecting-ip', 'x-forwarded-for', 'forwarded']) {
      final req = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${gateway.port}/dev/para?hesap=Ada&kredi=100',
        ),
      );
      req.headers.set(baslik, '203.0.113.7');
      final res = await req.close();
      await res.drain<void>();
      expect(res.statusCode, HttpStatus.notFound, reason: baslik);
    }
    expect(gateway.hangars.of(account.id).credits, once);
  });

  test('olmayan hesap ve boş miktar reddediliyor', () async {
    final (gateway, account) = await kur();
    final once = gateway.hangars.of(account.id).credits;

    final (kod1, _) = await iste(gateway, 'hesap=YokBoyleBiri&kredi=100');
    expect(kod1, HttpStatus.notFound);

    final (kod2, _) = await iste(gateway, 'hesap=Ada&kredi=0&nova=0');
    expect(kod2, HttpStatus.badRequest);
    expect(gateway.hangars.of(account.id).credits, once);
  });

  test('açık oturuma ANINDA yeni hangar durumu gidiyor', () async {
    final (gateway, account) = await kur();
    final socket = await WebSocket.connect(
      'ws://127.0.0.1:${gateway.port}',
    );
    addTearDown(socket.close);
    final gelen = <ServerMessage>[];
    socket.listen(
      (b) => gelen.add(ServerMessage.decode(b as Uint8List)),
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
    gelen.clear();

    await iste(gateway, 'hesap=Ada&kredi=777');
    await _until(() => gelen.whereType<ServerHangarState>().isNotEmpty);

    final durum = gelen.whereType<ServerHangarState>().last;
    expect(durum.json['credits'], gateway.hangars.of(account.id).credits);
  });
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
