@Tags(['disi'])
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'game_harness.dart';

/// Kimlik akışı — uçtan uca, gerçek sunucuyla.
///
/// Buradaki en önemli test bir özelliği değil bir KAPIYI doğruluyor:
/// kimliği olmayan hiç kimse dünyaya giremez. Kayıt ve giriş formu
/// kullanışlılık; o kapı ise oyunun kendisi.
void main() {
  Future<NetClient> raw(Gateway gateway) async {
    final client = NetClient(uri: Uri.parse('ws://127.0.0.1:${gateway.port}'));
    await client.connect();
    await awaitPhase(client, NetPhase.needsAuth);
    return client;
  }

  test(
    'kayıt olan oyuncu dünyaya girer',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final client = await raw(gateway);
      addTearDown(client.dispose);

      await client.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: testPassword,
      );
      await awaitAuthenticated(client);

      expect(client.username, 'Ada');
      await awaitPhase(client, NetPhase.playing);
      // Ad SUNUCUDAN geliyor: istemcinin yazdığı değil, hesabın adı.
      expect(gateway.zone.ships.values.single.name, 'Ada');
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'aynı kullanıcı adı ikinci kez alınamaz',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final first = await connectClient(gateway, 'Ada');
      addTearDown(first.dispose);

      final second = await raw(gateway);
      addTearDown(second.dispose);
      // Büyük/küçük harf farkı yeni bir hesap DEĞİL: iki "ada" ayırt edilemez
      // olurdu ve taklit bedavaya gelirdi.
      await second.register(
        email: 'baska@test.local',
        username: 'ada',
        password: testPassword,
      );

      await _awaitAuthError(second);
      expect(second.authError, isNotNull);
      expect(second.isAuthenticated, isFalse);
      expect(second.phase, NetPhase.needsAuth);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'yanlış parolayla giriş reddedilir',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final registered = await connectClient(gateway, 'Ada');
      addTearDown(registered.dispose);

      final attacker = await raw(gateway);
      addTearDown(attacker.dispose);
      await attacker.login(username: 'Ada', password: 'yanlis-parola-123');

      await _awaitAuthError(attacker);
      expect(attacker.isAuthenticated, isFalse);
      final wrongPassword = attacker.authError;

      // Var OLMAYAN bir hesap AYNI sebebi vermeli.
      //
      // Farklı sebepler dönseydi, hangi kullanıcı adlarının kayıtlı olduğu tek
      // tek öğrenilebilirdi — parolayı kırmadan önceki ilk adım budur.
      attacker.authError = null;
      await attacker.login(
        username: 'HicYokBoyle',
        password: 'yanlis-parola-123',
      );
      await _awaitAuthError(attacker);
      expect(attacker.authError, wrongPassword);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'doğru parolayla ikinci cihazdan girilebilir',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final first = await connectClient(gateway, 'Ada');
      addTearDown(first.dispose);

      final second = await raw(gateway);
      addTearDown(second.dispose);
      await second.login(username: 'ADA@test.local', password: testPassword);
      await awaitAuthenticated(second);
      expect(second.username, 'Ada');
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test('KİMLİKSİZ dünyaya girilemez', () async {
    // Oyunun kapısı. Uydurma bir belirteçle Hello yollayan bir istemci gemi
    // ALAMAZ — yoksa kayıt ekranı bir kapı değil yalnız bir kolaylık olur.
    //
    // Cevap `ServerRejected` değil `ServerAuthError`: bu ayrım kasıtlı.
    // Belirteçler yalnız bellekte yaşadığı için sunucunun her yeniden
    // başlaması eldeki belirteçleri bayatlatıyor, yani bu yol düşman
    // istemcinin değil SIRADAN oyuncunun yolu. "Reddedildin" demek soketi
    // kapatıyordu ve oyuncu bir daha giriş yapamıyordu; "giriş yap" demek
    // kanalı açık bırakıyor. Kapının kendisi aynı kilitte — aşağıdaki iddia
    // onu ölçüyor.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final result = await connectRawClient(gateway, Protocol.version);

    expect(result, isA<ServerAuthError>());
    expect(gateway.zone.ships, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test(
    'geçersiz alanlar sunucuda da reddedilir',
    () async {
      // İstemci doğrulaması bir KOLAYLIK, güvenlik değil: düzenlenmiş bir
      // istemci hiçbir kontrolden geçmez.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final client = await raw(gateway);
      addTearDown(client.dispose);

      await client.register(
        email: 'gecersiz',
        username: 'Ada',
        password: 'kısa',
      );
      await _awaitAuthError(client);
      expect(client.authError, isNotNull);
      expect(gateway.accounts.count, 0);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  _reconnectTests();
}

Future<void> _awaitAuthError(NetClient client) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (client.authError != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('kimlik hatası beklenmişti');
}

/// Ham soketle konuşan küçük bir istemci.
///
/// [NetClient] üzerinden yapılamaz: bağlantıyı testin istediği anda koparmak
/// gerekiyor ve o istemcide böyle bir düğme yok — üretim koduna yalnız test
/// için düğme eklemek, test edilen şeyi değiştirmenin en sinsi yolu.
class _RawClient {
  _RawClient(this.channel);

  final WebSocketChannel channel;
  final _incoming = <ServerMessage>[];
  late final StreamSubscription<dynamic> _sub;

  static Future<_RawClient> open(Gateway gateway) async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${gateway.port}'),
    );
    await channel.ready;
    final client = _RawClient(channel);
    client._sub = channel.stream.listen(
      (data) {
        final bytes = Uint8List.fromList(data as List<int>);
        // Snapshot'lar bu testte ilgilendirmiyor ve çözümü dünya ölçüsü ister.
        if (bytes.isEmpty || bytes[0] == Protocol.msgSnapshot) return;
        client._incoming.add(ServerMessage.decode(bytes));
      },
      onError: (_) {},
      onDone: () {},
    );
    return client;
  }

  void send(ClientMessage message) => channel.sink.add(message.encode());

  /// [T] tipinde ilk mesajı bekler.
  Future<T> waitFor<T extends ServerMessage>() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      for (final message in _incoming) {
        if (message is T) return message;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw StateError('$T gelmedi (gelenler: $_incoming)');
  }

  Future<void> close() async {
    await _sub.cancel();
    await channel.sink.close();
  }
}

void _reconnectTests() {
  Future<(_RawClient, String)> registered(Gateway gateway, String name) async {
    final client = await _RawClient.open(gateway);
    client.send(
      ClientRegister(
        protocolVersion: Protocol.version,
        email: '$name@test.local',
        username: name,
        password: testPassword,
      ),
    );
    final ok = await client.waitFor<ServerAuthOk>();
    return (client, ok.token);
  }

  test(
    'kopan oyuncu AYNI gemiye geri döner',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);

      final (first, token) = await registered(gateway, 'Ada');
      first.send(ClientHello(protocolVersion: Protocol.version, token: token));
      final welcome = await first.waitFor<ServerWelcome>();
      final shipId = welcome.entityId;

      // Gemiyi tanınır bir yere taşı: dönüşte konumun korunduğunu görmek için.
      gateway.zone.ships[shipId]!.state = gateway.zone.ships[shipId]!.state
          .copyWith(position: const Vec2(4321, 1234));

      await first.close();
      // Bekleme süresi içinde geri gel.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final second = await _RawClient.open(gateway);
      addTearDown(second.close);
      second.send(ClientHello(protocolVersion: Protocol.version, token: token));
      final back = await second.waitFor<ServerWelcome>();

      expect(back.entityId, shipId, reason: 'yeni gemi verildi');
      expect(
        gateway.zone.ships[shipId]!.state.position,
        const Vec2(4321, 1234),
        reason: 'konum kaybedildi',
      );
      expect(gateway.zone.ships[shipId]!.isOrphan, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'bekleme süresi dolunca gemi bırakılır',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);

      final (first, token) = await registered(gateway, 'Bora');
      first.send(ClientHello(protocolVersion: Protocol.version, token: token));
      final welcome = await first.waitFor<ServerWelcome>();
      await first.close();

      // ÖNCE sunucunun kopmayı işlemesini bekle: soket kapanışı asenkron ve
      // süreyi erken sıfırlarsak `_drop` onu yeniden kurar.
      final ship = gateway.zone.ships[welcome.entityId]!;
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!ship.isOrphan && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(ship.isOrphan, isTrue, reason: 'kopma işlenmedi');

      // Süreyi elle doldur: gerçek zamanda beklemek testi on saniye uzatırdı.
      ship.orphanUntilTick = 0;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(gateway.zone.ships.containsKey(welcome.entityId), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'ikinci cihazdan giriş birinciyi düşürür',
    () async {
      // Hesap başına tek oturum: iki gemi aynı hesaba bağlı olsaydı hangisinin
      // gerçek olduğu belirsizleşirdi.
      final gateway = await bootServer();
      addTearDown(gateway.stop);

      final (first, token) = await registered(gateway, 'Cem');
      first.send(ClientHello(protocolVersion: Protocol.version, token: token));
      await first.waitFor<ServerWelcome>();
      addTearDown(first.close);

      final second = await _RawClient.open(gateway);
      addTearDown(second.close);
      second.send(ClientHello(protocolVersion: Protocol.version, token: token));
      await second.waitFor<ServerWelcome>();

      // Birinci oturum reddedildiğini ÖĞRENMELİ: sessizce kesilmek, oyuncuya
      // "oyun dondu" gibi görünür.
      final kicked = await first.waitFor<ServerRejected>();
      expect(kicked.reason, KimlikKodu.baskaCihaz.kod);
      expect(gateway.zone.ships.length, 1);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );
}
