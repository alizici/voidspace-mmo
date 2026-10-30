@Tags(['disi'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// Sunucuyu KÖTÜ NİYETLE kullanan istemciler.
///
/// Buradaki her test bir saldırıyı canlandırıyor ve çoğu, gerçekten AÇIK olan
/// bir kapıyı kapattıktan sonra yazıldı — yani hiçbiri varsayımsal değil.
/// Ölçülen açıklar dosya içinde tek tek not edildi.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_sec'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<Gateway> boot({
    bool debugCommands = false,
    int maxPerIp = 64,
    Duration tokenTtl = AccountStore.defaultTokenTtl,
  }) async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(
        path: '${temp.path}/accounts.json',
        tokenTtl: tokenTtl,
      ),
      allowDebugCommands: debugCommands,
      maxSessionsPerIp: maxPerIp,
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);
    return gateway;
  }

  Future<WebSocket> open(Gateway gateway) =>
      WebSocket.connect('ws://127.0.0.1:${gateway.port}');

  group('kimlik doğrulama seli', () {
    test('tek karede gönderilen 60 deneme sınırı AŞAMAZ', () async {
      // GERÇEKTEN AÇIKTI. `authAttempts` sayacı `await`'ten SONRA arttığı için
      // aynı karede gelen 60 çerçevenin 60'ı da `authAttempts == 0` görüyor ve
      // geçiyordu. Ölçüm: 60 denemeden 60'ı cevap aldı, "çok fazla" sıfır kez
      // çıktı. Her biri ayrı bir isolate'te 120 bin turluk PBKDF2 demek —
      // yani TEK SOKETLE sunucunun bütün CPU'sunu yakmak.
      final gateway = await boot();
      final socket = await open(gateway);
      var answers = 0;
      var refused = 0;
      socket.listen(
        (data) {
          final message = ServerMessage.decode(
            Uint8List.fromList(data as List<int>),
          );
          if (message is ServerAuthError) {
            answers++;
            if (message.reason == KimlikKodu.cokFazlaDeneme.kod) refused++;
          }
        },
        onError: (_) {},
        onDone: () {},
      );

      for (var i = 0; i < 60; i++) {
        socket.add(
          ClientLogin(
            protocolVersion: Protocol.version,
            username: 'yok$i',
            password: 'deneme-parolasi-123',
          ).encode(),
        );
      }
      await Future<void>.delayed(const Duration(seconds: 3));

      // Patlamadaki çerçeveler SESSİZCE düşer: ilki türetmeye girer, kalan 59'u
      // "zaten bir türetme sürüyor" diye anında eler. Cevap sayısı sınırın
      // ölçüsü — 60'a yakın bir sayı, sınırın yine etkisiz olduğu demek.
      expect(
        answers,
        lessThan(4),
        reason: '$answers deneme işlendi — sınır yine etkisiz',
      );
      expect(refused, 0, reason: 'patlama sessizce elenmeli, cevaplanmamalı');
    });

    test('SIRAYLA denenen parolalar tükenince oturum KAPANIR', () async {
      // Patlama savunması tek başına yetmez: saldırgan her cevabı bekleyip
      // sırayla deneyebilir. Sızdıran kova o yolu da kapatıyor — ve bu, kaba
      // kuvvetle parola deneme hızının tavanı.
      final gateway = await boot();
      final socket = await open(gateway);
      final closed = Completer<void>();
      var refused = 0;
      final answered = <void Function()>[];
      socket.listen(
        (data) {
          final message = ServerMessage.decode(
            Uint8List.fromList(data as List<int>),
          );
          if (message is ServerAuthError) {
            if (message.reason == KimlikKodu.cokFazlaDeneme.kod) refused++;
            if (answered.isNotEmpty) answered.removeAt(0)();
          }
        },
        onDone: closed.complete,
        onError: (_) {},
      );

      for (var i = 0; i < 15 && !closed.isCompleted; i++) {
        socket.add(
          ClientLogin(
            protocolVersion: Protocol.version,
            username: 'yok',
            password: 'deneme-parolasi-$i',
          ).encode(),
        );
        // Cevabı bekle — patlama değil, SIRAYLA deneme.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      expect(refused, greaterThan(0), reason: 'sınır hiç devreye girmedi');
      await expectLater(
        closed.future.timeout(const Duration(seconds: 5)),
        completes,
        reason: 'sınırı aşan oturum kapatılmadı',
      );
    });

    test('çok uzun parola PBKDF2\'ye HİÇ ulaşmaz', () async {
      // Hiçbir hesabın sahip olamayacağı bir parolayı doğrulamak için 120 bin
      // tur harcamak, saldırgana bedava CPU vermektir. Kural `register`'da
      // vardı, `login`'de yoktu.
      final store = AccountStore(path: '${temp.path}/a.json');
      final elapsed = Stopwatch()..start();
      await expectLater(
        store.login(
          usernameOrEmail: 'Ada',
          password: 'x' * (Credentials.passwordMax + 1),
        ),
        throwsA(isA<AuthFailure>()),
      );
      elapsed.stop();
      // Gerçek bir türetme bu makinede ~100 ms. Reddin çok daha hızlı olması
      // türetmenin HİÇ çalışmadığının kanıtı.
      expect(elapsed.elapsedMilliseconds, lessThan(50));
    });
  });

  group('bağlantı tavanı', () {
    test('tek IP tavanı aşan soketi AÇTIRMAZ', () async {
      // Oturum başına sınırlar tek soketi savunur; bu, onları aşmak için bin
      // soket açmayı savunur. İkisi olmadan diğeri eksik.
      final gateway = await boot(maxPerIp: 3);
      final sockets = <WebSocket>[];
      for (var i = 0; i < 3; i++) {
        sockets.add(await open(gateway));
      }
      addTearDown(() async {
        for (final socket in sockets) {
          await socket.close();
        }
      });
      await expectLater(open(gateway), throwsA(isA<Exception>()));
    });

    test('kapanan soket tavandan DÜŞER', () async {
      // Sayaç yalnız artsaydı, sunucu birkaç saat sonra kendi oyuncularını
      // reddetmeye başlardı — ve sebebi hiçbir günlükte görünmezdi.
      final gateway = await boot(maxPerIp: 2);
      final first = await open(gateway);
      final second = await open(gateway);
      await expectLater(open(gateway), throwsA(isA<Exception>()));

      await first.close();
      // Sunucunun kapanışı işlemesini bekle.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      WebSocket? third;
      while (DateTime.now().isBefore(deadline)) {
        try {
          third = await open(gateway);
          break;
        } on Object {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      expect(third, isNotNull, reason: 'kapanan soket sayaçtan düşmedi');
      await third?.close();
      await second.close();
    });
  });

  group('çerçeve savunması', () {
    test('çerçeve seli soketi KAPATIR', () async {
      final gateway = await boot();
      final socket = await open(gateway);
      final closed = Completer<void>();
      socket.listen((_) {}, onDone: closed.complete, onError: (_) {});
      // Meşru istemci saniyede ~31 çerçeve yolluyor. 500 çerçeve tek karede
      // hiçbir meşru istemcinin yapmayacağı şey.
      for (var i = 0; i < 500; i++) {
        socket.add(ClientPing(i).encode());
      }
      await expectLater(
        closed.future.timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('devasa çerçeve soketi KAPATIR', () async {
      final gateway = await boot();
      final socket = await open(gateway);
      final closed = Completer<void>();
      socket.listen((_) {}, onDone: closed.complete, onError: (_) {});
      socket.add(Uint8List(64 * 1024));
      await expectLater(
        closed.future.timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('normal hızda oynayan istemci ASLA düşürülmez', () async {
      // Sınırın asıl riski yanlış pozitif: meşru oyuncuyu düşüren bir savunma,
      // savunduğu şeyden çok zarar verir.
      final gateway = await boot();
      final socket = await open(gateway);
      var dropped = false;
      socket.listen((_) {}, onDone: () => dropped = true, onError: (_) {});
      // 2 saniye boyunca 30 Hz girdi + 1 Hz ping — gerçek oyun hızı.
      for (var i = 0; i < 60; i++) {
        socket.add(
          ClientInput(
            seq: i,
            input: ShipInput(seq: i),
          ).encode(),
        );
        if (i % 30 == 0) socket.add(ClientPing(i).encode());
        await Future<void>.delayed(const Duration(milliseconds: 33));
      }
      expect(dropped, isFalse, reason: 'meşru oyuncu hız sınırına takıldı');
      await socket.close();
    });
  });

  group('hata ayıklama komutları', () {
    test('varsayılan KAPALI — ölü gemi dirilmez', () async {
      // ÖLÇÜLDÜ: açıkken gövdesi ve kalkanı sıfırlanmış ölü bir gemi tek bir
      // çerçeveyle 12000 gövde / 8000 kalkana dönüyor ve `alive` yeniden true
      // oluyordu. Sınırsız ölümsüzlük.
      final gateway = await boot();
      final socket = await open(gateway);
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

      final ship = gateway.zone.ships.values.single;
      ship.state = ShipSim.applyDamage(ship.state, 1e6);
      expect(ship.state.alive, isFalse, reason: 'kurulum başarısız');

      socket.add(ClientDebug(DebugCommandKind.repair).encode());
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(ship.state.alive, isFalse, reason: 'ölü gemi diriltildi');
      expect(ship.state.hull, 0);
    });

    test('açıkken çalışır — testlerin otorite kanıtı korunur', () async {
      final gateway = await boot(debugCommands: true);
      final socket = await open(gateway);
      final account = await gateway.accounts.register(
        email: 'bora@test.local',
        username: 'Bora',
        password: 'yeterince-uzun-parola',
      );
      socket.add(
        ClientHello(
          protocolVersion: Protocol.version,
          token: gateway.accounts.issueToken(account),
        ).encode(),
      );
      await _until(() => gateway.zone.ships.isNotEmpty);

      final ship = gateway.zone.ships.values.single;
      socket.add(ClientDebug(DebugCommandKind.damage).encode());
      await _until(() => ship.state.shield < ShipStats.bastion.maxShield);
      expect(ship.state.shield, lessThan(ShipStats.bastion.maxShield));
      await socket.close();
    });
  });

  group('belirteç', () {
    test('yeni giriş ESKİ belirteci geçersizleştirir', () async {
      // Yoksa her giriş kalıcı bir anahtar daha bırakırdı: bin kez giren bir
      // oyuncu bin geçerli anahtar demek, ve çalınmış eski bir anahtar ilelebet
      // geçerli kalır.
      final store = AccountStore(path: '${temp.path}/a.json');
      final account = await store.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: 'yeterince-uzun-parola',
      );
      final first = store.issueToken(account);
      final second = store.issueToken(account);

      expect(store.accountFor(second), isNotNull);
      expect(store.accountFor(first), isNull, reason: 'eski belirteç yaşıyor');
      expect(store.tokenCount, 1, reason: 'belirteç haritası sızdırıyor');
    });

    test('süresi dolan belirteç ÇALIŞMAZ', () async {
      final store = AccountStore(
        path: '${temp.path}/a.json',
        tokenTtl: Duration.zero,
      );
      final account = await store.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: 'yeterince-uzun-parola',
      );
      final token = store.issueToken(account);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(store.accountFor(token), isNull);
    });

    test('süpürme ölü belirteçleri TEMİZLER', () async {
      // `accountFor` tembel temizlik yapıyor ama yalnız SORULAN belirteci
      // görebiliyor; bir daha hiç sorulmayan belirteç sonsuza kadar kalırdı.
      final store = AccountStore(
        path: '${temp.path}/a.json',
        tokenTtl: Duration.zero,
      );
      for (final name in ['Ada', 'Bora', 'Cem']) {
        final account = await store.register(
          email: '$name@test.local',
          username: name,
          password: 'yeterince-uzun-parola',
        );
        store.issueToken(account);
      }
      expect(store.tokenCount, 3);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(store.sweepExpiredTokens(), 3);
      expect(store.tokenCount, 0);
    });

    test(
      'geçersiz belirteçle dünyaya GİRİLEMEZ — ama soket KAPANMAZ',
      () async {
        // Kapı hâlâ kapalı: uydurma belirteç gemi almıyor. Değişen tek şey
        // CEVABIN TÜRÜ ve soketin kaderi.
        //
        // Bayat belirteç bir saldırı değil, sunucunun yeniden başlamasının
        // olağan sonucu (belirteçler yalnız bellekte yaşıyor). Soketi kapatmak
        // istemcinin giriş çerçevesini kapalı bir kanala düşürüyor, o da
        // sessizce yutuluyor ve oyuncu "doğrulanıyor"da asılı kalıyordu —
        // "ilk girişte oyuna girmiyor, ikincide giriyor"un kaynağı buydu.
        final gateway = await boot();
        final socket = await open(gateway);
        final answered = Completer<ServerMessage>();
        var closed = false;
        socket.listen(
          (data) {
            final message = ServerMessage.decode(
              Uint8List.fromList(data as List<int>),
            );
            if (!answered.isCompleted) answered.complete(message);
          },
          onError: (_) {},
          onDone: () => closed = true,
        );

        socket.add(
          const ClientHello(
            protocolVersion: Protocol.version,
            token: 'uydurma-belirtec',
          ).encode(),
        );
        final message = await answered.future.timeout(
          const Duration(seconds: 5),
        );

        expect(message, isA<ServerAuthError>());
        expect(
          (message as ServerAuthError).reason,
          KimlikKodu.oturumDoldu.kod,
        );
        // ASIL İDDİA: dünyaya girilmedi.
        expect(gateway.zone.ships, isEmpty);

        // Ve kanal açık kaldı — oyuncu AYNI soketten giriş yapabilmeli.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(closed, isFalse, reason: 'giriş yapılacak kanal kapatılmamalı');
      },
    );
  });

  group('geri basınç', () {
    test('SUSAN istemciye snapshot yığılmaz', () async {
      // `dart:io`'nun WebSocket'i kuyruğunda bekleyen bayt miktarını AÇMIYOR,
      // yani "istemci yetişemiyor" durumu doğrudan ölçülemiyor. Elimizdeki tek
      // sinyal ters yön: sağlıklı istemci saniyede 30 çerçeve yolluyor. Bir
      // saniye tam sessizlik ya ölü bağlantı ya boğulmuş istemci demek — ve
      // ikisinde de saniyede 30 snapshot daha yığmanın tek etkisi sunucunun
      // belleğini büyütmek.
      final gateway = await boot();
      final socket = await open(gateway);
      final account = await gateway.accounts.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: 'yeterince-uzun-parola',
      );
      var snapshots = 0;
      socket.listen(
        (data) {
          final bytes = data as List<int>;
          if (bytes.isNotEmpty && bytes[0] == Protocol.msgSnapshot) snapshots++;
        },
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

      // Konuşurken akış GELİR.
      for (var i = 0; i < 30; i++) {
        socket.add(
          ClientInput(
            seq: i,
            input: ShipInput(seq: i),
          ).encode(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 33));
      }
      expect(snapshots, greaterThan(10), reason: 'akış hiç başlamadı');

      // Şimdi SUS. Bir saniyelik eşiğin geçmesini bekle, sonra say.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final afterStall = snapshots;
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(
        snapshots - afterStall,
        lessThan(3),
        reason: 'susan istemciye snapshot yığılmaya devam etti',
      );

      // Ve GERİ DÖNÜLEBİLİR: istemci konuşmaya başlayınca akış geri gelir.
      // Kalıcı olsaydı, tek bir ağ hıçkırığı oyuncuyu oyundan koparırdı.
      final resumed = snapshots;
      for (var i = 100; i < 130; i++) {
        socket.add(
          ClientInput(
            seq: i,
            input: ShipInput(seq: i),
          ).encode(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 33));
      }
      expect(
        snapshots - resumed,
        greaterThan(10),
        reason: 'istemci geri döndü ama akış geri gelmedi',
      );
      await socket.close();
    });
  });

  test('kapanış KİMLİKSİZ soketleri de kapatır', () async {
    // `_sessions` yalnız dünyaya girmiş oturumları tutuyordu; el sıkışmayı
    // tamamlamamış soketler hiçbir yerde sayılmadığı için `stop()` onları
    // açık bırakıyordu.
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/accounts.json'),
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    final closed = Completer<void>();
    socket.listen((_) {}, onDone: closed.complete, onError: (_) {});

    await gateway.stop();
    await expectLater(
      closed.future.timeout(const Duration(seconds: 5)),
      completes,
    );
  });
}

/// [condition] sağlanana kadar bekler.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('koşul sağlanmadı');
}
