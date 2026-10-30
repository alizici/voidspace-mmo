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

/// `ServerSnapshot.decodeWith` HANGİ durumda fırlatıyor — ve fırlatırsa ne
/// oluyor.
///
/// `net_client.dart:471` civarındaki yol çözümü çıplak çağırıyor:
/// `_onSnapshot(ServerSnapshot.decodeWith(...))`. Ne `try` var ne de
/// çağrı `onError`'a düşüyor. Buradaki testler üç ayrı soruyu ölçüyor:
/// fırlatma ÇALIŞIYOR mu, DÜRÜST sunucu onu üretebilir mi, ve fırlarsa
/// istemcide nereye gidiyor.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_cozme'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Elde bir snapshot çerçevesi kur: tek entity, verilen maske.
  Uint8List frame({required int id, required int mask}) {
    final w = ByteWriter(64)
      ..u8(Protocol.msgSnapshot)
      ..u32(1);
    SelfSnapshot(
      acknowledgedSeq: 0,
      state: ShipSimState.spawn(ShipStats.bastion, const Vec2(100, 100)),
      pendingInputs: 0,
    ).write(w);
    w.u16(1);
    EntityDelta.write(w, id, Int32List(EntityDelta.fields), mask);
    w
      ..u8(0) // atış yok
      ..u16(0); // alien yok
    return w.take();
  }

  test('A · FormatException DİRİ: temelsiz kimliğe kısmi maske', () {
    final baseline = EntityBaseline();
    expect(
      () => ServerSnapshot.decodeWith(
        frame(id: 42, mask: EntityDelta.bitX),
        12000,
        8000,
        ShipStats.bastion,
        baseline,
      ),
      throwsA(isA<FormatException>()),
    );

    // Aynı kimlik TAM kayıtla gelirse sorun yok — ve ondan sonra kısmi de
    // sorun değil. Yani fırlatmanın koşulu tam olarak "ilk görüş + kısmi".
    ServerSnapshot.decodeWith(
      frame(id: 42, mask: EntityDelta.full),
      12000,
      8000,
      ShipStats.bastion,
      baseline,
    );
    expect(
      () => ServerSnapshot.decodeWith(
        frame(id: 42, mask: EntityDelta.bitX),
        12000,
        8000,
        ShipStats.bastion,
        baseline,
      ),
      returnsNormally,
    );
  });

  test(
    'B · DÜRÜST sunucu bunu üretmiyor — gerçek oturum çözülüyor',
    () async {
      // Gerçek gateway, gerçek istemci temeli. İki gemi birbirini görüyor,
      // hareket ediyor ve oturum boyunca gelen HER çerçeve istemcinin
      // yaptığının aynısıyla çözülüyor.
      final gateway = Gateway(
        zone: Zone(alienCount: 12),
        accounts: AccountStore(path: '${temp.path}/a.json'),
      );
      await gateway.start(host: '127.0.0.1', port: 0);
      addTearDown(gateway.stop);

      Future<WebSocket> join(String name) async {
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:${gateway.port}',
        );
        final account = await gateway.accounts.register(
          email: '$name@test.local',
          username: name,
          password: 'yeterince-uzun-parola',
        );
        socket.add(
          ClientHello(
            protocolVersion: Protocol.version,
            token: gateway.accounts.issueToken(account),
          ).encode(),
        );
        return socket;
      }

      final neighbour = await join('Komsu');
      neighbour.listen((_) {}, onError: (_) {}, onDone: () {});
      await _until(() => gateway.zone.ships.isNotEmpty);

      final viewer = await join('Izleyici');
      final baseline = EntityBaseline();
      final errors = <Object>[];
      var frames = 0;
      // Çerçeveleri SAKLA: C testi aynı akışı temel sıfırlanmış hâlde yeniden
      // çözecek.
      final captured = <Uint8List>[];
      viewer.listen(
        (data) {
          final bytes = Uint8List.fromList(data as List<int>);
          if (bytes.isEmpty || bytes[0] != Protocol.msgSnapshot) return;
          captured.add(bytes);
          frames++;
          try {
            ServerSnapshot.decodeWith(
              bytes,
              12000,
              8000,
              ShipStats.bastion,
              baseline,
            );
          } on Object catch (e) {
            errors.add(e);
          }
        },
        onError: (_) {},
        onDone: () {},
      );

      var seq = 0;
      final heartbeat = Timer.periodic(const Duration(milliseconds: 20), (_) {
        seq++;
        // İki gemi de sürekli hareket ediyor: hem delta dolu kalsın hem
        // ilgi alanına girip çıkma yaşansın.
        final frame = ClientInput(
          seq: seq,
          input: ShipInput(
            seq: seq,
            moveTarget: Vec2(
              2000 + (seq % 40) * 200.0,
              1000 + (seq % 27) * 200.0,
            ),
            firing: seq.isEven,
            weaponTarget: 1,
          ),
        ).encode();
        for (final socket in [viewer, neighbour]) {
          try {
            socket.add(frame);
          } on Object {
            // kapanmış soket
          }
        }
      });
      try {
        await _until(() => frames >= 150, timeout: const Duration(seconds: 20));
      } finally {
        heartbeat.cancel();
      }
      await viewer.close();
      await neighbour.close();

      // ignore: avoid_print
      print('B · $frames snapshot çözüldü, hata: ${errors.length}');
      expect(errors, isEmpty, reason: 'dürüst sunucu kısmi-temelsiz üretti');
      expect(frames, greaterThan(100));

      // C · AYNI akış, ama temel oturum ORTASINDA sıfırlanmış.
      //
      // `NetClient._reset` tam olarak bunu yapıyor (`_baseline.clear()`).
      // Sunucu için hiçbir şey değişmediğinden bir sonraki kısmi kayıt
      // temelsiz bir kimliğe düşüyor.
      final b2 = EntityBaseline();
      Object? kaza;
      for (var i = 0; i < captured.length; i++) {
        if (i == 40) b2.clear(); // oturum ortasında temel gitti
        try {
          ServerSnapshot.decodeWith(
            captured[i],
            12000,
            8000,
            ShipStats.bastion,
            b2,
          );
        } on Object catch (e) {
          kaza = e;
          // ignore: avoid_print
          print('C · temel sıfırlandıktan ${i - 40} çerçeve sonra: $e');
          break;
        }
      }
      expect(
        kaza,
        isA<FormatException>(),
        reason:
            'temel oturum ortasında silinince kısmi delta ÇÖZÜLEMEZ olmalıydı',
      );
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test('D · fırlatınca nereye gidiyor — `onError` DEĞİL', () async {
    // `net_client.dart` çerçeveleri `channel.stream.listen(onData, onError:)`
    // içinde işliyor ve `_onFrame` çözümü çıplak çağırıyor. Dart'ta onData
    // içinden fırlayan bir istisna onError'a GİTMEZ; kuşatan Zone'a
    // yakalanmamış eşzamansız hata olarak düşer.
    //
    // Sonuç istemci için şu: `_fail(...)` hiç çalışmaz, faz `playing`de
    // kalır, ekran donar — ve konsolda yakalanmamış bir istisna belirir.
    final onErrorCalls = <Object>[];
    final uncaught = <Object>[];
    final controller = StreamController<int>();

    await runZonedGuarded(() async {
      controller.stream.listen(
        (_) => throw const FormatException('temelsiz entity için kısmi delta'),
        onError: onErrorCalls.add,
        cancelOnError: true,
      );
      controller.add(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, (e, _) => uncaught.add(e));

    // ignore: avoid_print
    print(
      'D · onError çağrıldı mı: ${onErrorCalls.isNotEmpty} · '
      'yakalanmamış: ${uncaught.length} (${uncaught.firstOrNull})',
    );
    expect(
      onErrorCalls,
      isEmpty,
      reason: 'onData içinden fırlayan istisna onError\'a düşmüyor',
    );
    expect(uncaught, hasLength(1));
    expect(uncaught.first, isA<FormatException>());
  });
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final limit = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(limit)) {
      throw StateError('koşul zaman aşımına uğradı');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
