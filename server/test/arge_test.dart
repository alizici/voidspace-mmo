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

/// ARGE UÇTAN UCA — düğüm alındı, İSTEMCİYE yansıdı (05.7).
///
/// Sunucu `arge_al` ve `arge_sifirla`'yı uzun süredir kabul ediyordu ama
/// hiçbir test alınan düğümün geri DÖNDÜĞÜNÜ ölçmemişti: hangar durumu
/// gidiyor, içinde `argeDugumleri` var mı diye bakan yoktu. Ekran o alanı
/// okuyacak (borç defteri B33) ve alanın sessizce düşmesi, oyuncunun aldığı
/// düğümün ekranda hiç görünmemesi demek.
///
/// Ölçülen üç şey: alınan düğüm hangar durumuyla geri geliyor, sıfırlama onu
/// geri alıyor, ve zincir kopukken sunucu REDDİN SEBEBİNİ kod olarak yolluyor
/// (metin değil — sunucunun dili yok).
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_arge'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(WebSocket, List<Uint8List>, Hangar)> kur({int seviye = 20}) async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);
    final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    addTearDown(socket.close);
    final gelen = <Uint8List>[];
    socket.listen(
      (d) => gelen.add(Uint8List.fromList(d as List<int>)),
      onError: (_) {},
      onDone: () {},
    );
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
    // ArGe puanı SEVİYEDEN (10.1): XP eşiğin bir üstüne konuyor, ağaç için
    // ayrı bir kaynak yok.
    hangar.xpEkle(Seviye.esigi(seviye).ceil());
    return (socket, gelen, hangar);
  }

  /// Gelen paketlerdeki SON hangar durumunun JSON'u — istemcinin gördüğü şey.
  Map<String, Object?>? sonDurum(List<Uint8List> gelen) {
    Map<String, Object?>? son;
    for (final b in gelen) {
      if (b.isEmpty) continue;
      if (ServerMessage.decode(b) case ServerHangarState(:final json)) {
        son = json;
      }
    }
    return son;
  }

  List<String> alinanlar(Map<String, Object?>? json) => [
    for (final v in (json?['argeDugumleri'] as List? ?? const [])) v as String,
  ];

  void yolla(
    WebSocket socket,
    String action, [
    Map<String, Object?> p = const {},
  ]) => socket.add(ClientHangar(action: action, payload: p).encode());

  // KARAR 05.7 s2
  test(
    'alınan düğüm hangar durumuyla İSTEMCİYE dönüyor',
    () async {
      final (socket, gelen, hangar) = await kur();
      gelen.clear();

      yolla(socket, 'arge_al', {'dugumId': 'filo-1'});
      await _until(() => hangar.argeDugumleri.contains('filo-1'));
      await _until(() => alinanlar(sonDurum(gelen)).contains('filo-1'));

      final json = sonDurum(gelen)!;
      expect(json['error'], isNull, reason: 'geçerli düğüm reddedildi');
      // Seviye de aynı durumda: ekran puanı ondan hesaplıyor (`ArGe.puanFor`) ve
      // eksik olsaydı sayaç sıfır gösterirdi.
      expect(json['seviye'], hangar.seviye);
      expect(ArGe.puanFor(json['seviye']! as int), greaterThan(0));

      // Zincir: ikinci düğüm de alınıyor ve İKİSİ birden dönüyor.
      gelen.clear();
      yolla(socket, 'arge_al', {'dugumId': 'filo-2'});
      await _until(() => alinanlar(sonDurum(gelen)).contains('filo-2'));
      expect(alinanlar(sonDurum(gelen)), containsAll(['filo-1', 'filo-2']));
      // Alan JSON'dan geçiyor: protokole yeni bir mesaj ya da sürüm girmedi.
      expect(jsonDecode(jsonEncode(sonDurum(gelen))), isMap);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  // KARAR 05.7 s2
  test(
    'zincir kopuksa REDDİN SEBEBİ kod olarak dönüyor',
    () async {
      final (socket, gelen, hangar) = await kur();
      gelen.clear();

      // Önkoşulu alınmamış düğüm: sunucu reddediyor ve sebebi `HangarError.name`
      // olarak yolluyor — istemci cümleyi kendi dilinde kuruyor.
      yolla(socket, 'arge_al', {'dugumId': 'filo-3'});
      await _until(() => sonDurum(gelen)?['error'] != null);
      expect(sonDurum(gelen)!['error'], HangarError.kilitli.name);
      expect(alinanlar(sonDurum(gelen)), isEmpty);
      expect(hangar.argeDugumleri, isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  // KARAR 05.7 s2
  test(
    'sıfırlama ağacı BOŞALTIYOR ve boş alan JSON\'dan düşüyor',
    () async {
      final (socket, gelen, hangar) = await kur();
      yolla(socket, 'arge_al', {'dugumId': 'gemi-1'});
      await _until(() => hangar.argeDugumleri.contains('gemi-1'));
      gelen.clear();

      yolla(socket, 'arge_sifirla');
      await _until(() => hangar.argeDugumleri.isEmpty);
      await _until(() => sonDurum(gelen) != null);
      // Boş ağaç alanı hiç YAZMIYOR (eski kayıtların biçimi bozulmasın) ve
      // istemci onu boş küme olarak okuyor — iki uçtaki kural aynı.
      expect(sonDurum(gelen)!.containsKey('argeDugumleri'), isFalse);
      expect(alinanlar(sonDurum(gelen)), isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  // KARAR 05.7 s2 · KARAR 04.10 s3
  test(
    'izin düğümü filo tavanını sunucuda da açıyor',
    () async {
      final (socket, gelen, hangar) = await kur();
      final once = hangar.filoTavani;
      for (final id in const ['filo-1', 'filo-2', 'filo-3', 'filo-yuva']) {
        yolla(socket, 'arge_al', {'dugumId': id});
        await _until(() => hangar.argeDugumleri.contains(id));
      }
      expect(hangar.filoTavani, once + 1);
      // İstemcinin okuyacağı küme ile sunucunun saydığı tavan AYNI yordamdan.
      await _until(() => alinanlar(sonDurum(gelen)).contains('filo-yuva'));
      expect(
        ArGe.filoTavani(alinanlar(sonDurum(gelen)).toSet()),
        hangar.filoTavani,
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
