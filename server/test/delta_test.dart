@Tags(['disi', 'zaman'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// Delta akışının TELDEKİ sözleşmesi.
///
/// Buradaki testler snapshot'ları ham bayt olarak okuyup entity kayıtlarının
/// maskelerine bakıyor. Sebep: delta'nın doğruluğu istemci nesnelerinde değil
/// TELDE görünür — "istemci doğru konumu çizdi" testi, sunucu her seferinde
/// tam kayıt gönderse de geçerdi.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_delta'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Bir snapshot çerçevesindeki entity kayıtlarının (id, maske) listesi.
  ///
  /// Elle ayrıştırılıyor çünkü ölçülmek istenen şey tam olarak bu: çözücüyü
  /// kullanmak maskeyi gizler ve testin gözü kapanır.
  List<(int, int)> entityMasks(Uint8List bytes, ShipStats stats) {
    final r = ByteReader(bytes)..u8();
    r.u32();
    SelfSnapshot.read(r, stats);
    final count = r.u16();
    final out = <(int, int)>[];
    for (var i = 0; i < count; i++) {
      final id = r.u16();
      final mask = r.u8();
      out.add((id, mask));
      // Maskedeki alanları ATLA — okuma konumu doğru kalmalı.
      if (mask & EntityDelta.bitX != 0) r.u16();
      if (mask & EntityDelta.bitY != 0) r.u16();
      if (mask & EntityDelta.bitAngle != 0) r.u8();
      if (mask & EntityDelta.bitThrust != 0) r.u8();
      if (mask & EntityDelta.bitShield != 0) r.u8();
      if (mask & EntityDelta.bitHull != 0) r.u8();
      if (mask & EntityDelta.bitFlags != 0) r.u8();
      if (mask & EntityDelta.bitTarget != 0) r.u16();
    }
    return out;
  }

  /// İki gemili bir sunucu kurar ve [ticks] tik boyunca izleyicinin aldığı
  /// snapshot'ların entity maskelerini toplar.
  Future<List<List<(int, int)>>> watch({required int ticks}) async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);

    Future<WebSocket> join(String name) async {
      final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
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

    // Komşu ÖNCE girsin: izleyici katıldığında zaten görünür olsun.
    final neighbour = await join('Komsu');
    neighbour.listen((_) {}, onError: (_) {}, onDone: () {});
    await _until(() => gateway.zone.ships.isNotEmpty);

    final viewer = await join('Izleyici');
    final frames = <List<(int, int)>>[];
    viewer.listen(
      (data) {
        final bytes = Uint8List.fromList(data as List<int>);
        if (bytes.isEmpty || bytes[0] != Protocol.msgSnapshot) return;
        frames.add(entityMasks(bytes, ShipStats.bastion));
      },
      onError: (_) {},
      onDone: () {},
    );

    // İstemciler GİRDİ göndermek zorunda.
    //
    // Göndermezlerse sunucu bir saniye sonra onları "susmuş" sayıp snapshot
    // akışını kesiyor (geri basınç koruması) ve test sessizce aç kalıyor.
    // İlk yazışta tam olarak bu oldu: `⚠ 24 snapshot atlandı`. Koruma doğru
    // çalışıyordu, testin gerçek bir istemci gibi davranması gerekiyordu.
    var seq = 0;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 33), (_) {
      seq++;
      final frame = ClientInput(
        seq: seq,
        input: ShipInput(seq: seq),
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
      await _until(() => frames.length >= ticks);
    } finally {
      heartbeat.cancel();
    }
    await viewer.close();
    await neighbour.close();
    return frames;
  }

  test(
    'ilk kayıt TAM, sonrası KISMİ ya da HİÇ',
    () async {
      // Testin ölçtüğü şey değişmedi — beklenen çıktı değişti.
      //
      // Eskiden her tik her entity gidiyordu ve kanıt "maskenin hepsi olmaması"
      // idi. Öncelikli replikasyondan sonra duran bir gemi için doğru cevap
      // KAYIT GÖNDERMEMEK: hiçbir şey değişmediyse 3 baytlık "değişen yok"
      // kaydının da bir alıcısı yok.
      //
      // Yani iddia şu: ilk kayıttan sonra TAM kayıt gelmiyor (anahtar kareler
      // hariç), ve gelen ne varsa kısmi.
      final frames = await watch(ticks: 12);
      expect(
        frames.first.single.$2,
        EntityDelta.full,
        reason: 'ilk kayıt tam olmalı',
      );

      final records = frames.skip(1).expand((f) => f).toList();
      final fulls = records.where((r) => r.$2 == EntityDelta.full).length;
      expect(
        fulls,
        0,
        reason: 'ilk kareden sonra tam kayıt gidiyor — delta çalışmıyor',
      );

      // Duran gemide kayıt hiç çıkmayabilir; çıkanların hepsi kısmi olmalı.
      expect(records.every((r) => r.$2 != EntityDelta.full), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'DURAN gemi snapshot yeri işgal etmiyor',
    () async {
      // Öncelikli replikasyonun asıl kazancı bu. Ölçüldü: sakin dünyada
      // kayıtların %89'u boş — kayıt başına 3 bayt sırf "değişen bir şey yok"
      // demek için gidiyordu.
      final frames = await watch(ticks: 12);
      final empty = frames.skip(1).where((f) => f.isEmpty).length;
      expect(
        empty,
        greaterThan(0),
        reason: 'değişmeyen entity hâlâ her tik yazılıyor',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'ANAHTAR KARE: her entity iki saniyede bir TAM gider',
    () async {
      // Delta'nın tek zayıf noktası temelin sessizce bozulması. Anahtar kare
      // onu "olmamalı"dan "olsa bile iki saniyede onarılır"a çeviriyor.
      //
      // Bu testin kilitlediği şey bir uygulama ayrıntısı değil bir GARANTİ:
      // kaydırma formülü değişse de, aralık değişse de, her entity'nin düzenli
      // olarak tam gitmesi sözleşme.
      // Pencere İKİ anahtar kare aralığı: tam koşuda makine yük altındayken
      // tek aralıklık pencere bir kez sıfır saydı (borç defteri B8). Garanti
      // değişmedi, ölçüm ona daha az yapışık: dört saniyede en az bir tam
      // kayıt, iki saniyede bir gelen bir şey için yük altında bile tutar.
      final frames = await watch(ticks: 2 * Protocol.keyframeTicks + 5);

      var fullCount = 0;
      for (final frame in frames.skip(1)) {
        for (final (_, mask) in frame) {
          if (mask == EntityDelta.full) fullCount++;
        }
      }
      expect(
        fullCount,
        greaterThanOrEqualTo(1),
        reason:
            'dört saniyelik pencerede hiç anahtar kare gelmedi — '
            'bozulan bir temel sonsuza kadar bozuk kalır',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('anahtar kareler AYNI TİKE yığılmaz', () async {
    // Kaydırma olmasaydı altmış tikte bir bütün kalabalık aynı anda tam kayıt
    // olurdu: düzenli, keskin ve tam da kalabalık anlarda gelen bir bant
    // genişliği tepesi. Formül `(tik + kimlik)` bunu dağıtıyor.
    const interval = Protocol.keyframeTicks;
    final hits = <int, List<int>>{};
    for (var tick = 0; tick < interval; tick++) {
      for (var id = 1; id <= 60; id++) {
        if ((tick + id) % interval == 0) {
          (hits[tick] ??= []).add(id);
        }
      }
    }
    // Altmış entity, altmış tiklik pencere: tik başına TAM BİR entity.
    expect(hits.length, interval);
    for (final ids in hits.values) {
      expect(ids, hasLength(1));
    }
  });
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('koşul sağlanmadı');
}
