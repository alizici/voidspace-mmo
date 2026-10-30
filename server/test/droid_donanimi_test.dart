@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// DROİD DONANIMI SUNUCUDA (05.4 s5).
///
/// Droid bir taşıyıcı: içine takılan lazer droid kapsamına yazıyor ve
/// savaşan gemiye ORADAN geçiyor. Ölçülen, komutun uçtan uca çalıştığı ve
/// takılan eşyanın geminin kendi yaylımına karışmadığı.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_donanim'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(Gateway, WebSocket, Hangar, String)> kur() async {
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
    // Droid açılışı üçüncü rankta (10.7); bir droid, bir lazer.
    hangar.addItem(const ItemInstance(instanceId: 'acilis', specId: 'pl5'));
    hangar.addItem(const ItemInstance(instanceId: 'd0', specId: 'dr1'));
    hangar.addItem(const ItemInstance(instanceId: 'lz', specId: 'pl1'));
    expect(HangarRules.filoyaAl(hangar, 'd0'), isNull);
    return (gateway, socket, hangar, account.id);
  }

  // KARAR 05.4 s5
  test('droide takılan lazer droid kapsamına geçiyor, gemiye değil', () async {
    final (gateway, socket, hangar, hesap) = await kur();
    final onceki = gateway.hangars.of(hesap);
    expect(onceki.droidinDonanimi('d0'), isEmpty);

    socket.add(
      ClientHangar(
        action: 'droid_tak',
        payload: {'droidId': 'd0', 'instanceId': 'lz'},
      ).encode(),
    );
    await _until(() => hangar.droidinDonanimi('d0').isNotEmpty);

    expect(hangar.droidinDonanimi('d0'), ['lz']);
    final stats = LoadoutResolver.resolve(
      hangar.activeLoadout,
      hangar.inventory,
      Catalogue.byId,
      filo: hangar.filo,
      droidDonanimi: hangar.droidDonanimi,
    );
    expect(
      stats.droidler.tabanHasar,
      greaterThan(0),
      reason: 'takılan lazer filoya güç vermedi',
    );
    // Geminin namlu sayısı DEĞİŞMİYOR: yeni hesabın takılı gelen lazeri
    // duruyor, droide takılan onun yanına eklenmiyor (05.4 s5).
    expect(stats.equippedLasers, 1);
  });

  // KARAR 05.4 s5
  test('droide KALKAN JENERATÖRÜ takmak sunucuyu düşürmüyor', () async {
    // 05.4 s5 droide iki eşya sokuyor: lazer ve kalkan jeneratörü. Kural
    // jeneratöre izin veriyordu ama `kalkan` kaydı droid kapsamı tanımıyordu;
    // takıldığı an stat çözümü ArgumentError atıyor, süreç ölüyordu. Kural
    // ile kayıt arasındaki bu boşluk görünmemişti çünkü hiçbir test takmanın
    // ARDINDAN çözmüyordu.
    final (gateway, socket, hangar, hesap) = await kur();
    hangar.addItem(const ItemInstance(instanceId: 'jen', specId: 'df1'));

    socket.add(
      ClientHangar(
        action: 'droid_tak',
        payload: {'droidId': 'd0', 'instanceId': 'jen'},
      ).encode(),
    );
    await _until(() => hangar.droidinDonanimi('d0').isNotEmpty);

    expect(socket.closeCode, isNull, reason: 'oturum düştü');
    expect(gateway.zone.ships, isNotEmpty, reason: 'sunucu gemiyi kaybetti');

    // Jeneratör droidin havuzuna biniyor: droidin TEK havuzu var ve o havuz
    // zaten gövde artı kalkan olarak ölçülüyor (05.4).
    ShipStats coz() => LoadoutResolver.resolve(
      hangar.activeLoadout,
      hangar.inventory,
      Catalogue.byId,
      filo: hangar.filo,
      droidDonanimi: hangar.droidDonanimi,
    );
    final dolu = coz().droidler.havuz;
    expect(HangarRules.droidenCikar(hangar, 'jen'), isNull);
    expect(dolu, greaterThan(coz().droidler.havuz));
  });

  // KARAR 05.4 s5
  test('çıkarma komutu yuvayı boşaltıyor', () async {
    final (_, socket, hangar, _) = await kur();
    socket.add(
      ClientHangar(
        action: 'droid_tak',
        payload: {'droidId': 'd0', 'instanceId': 'lz'},
      ).encode(),
    );
    await _until(() => hangar.droidinDonanimi('d0').isNotEmpty);

    socket.add(
      ClientHangar(
        action: 'droid_cikar',
        payload: {'instanceId': 'lz'},
      ).encode(),
    );
    await _until(() => hangar.droidinDonanimi('d0').isEmpty);
    expect(hangar.itemOf('lz'), isNotNull, reason: 'eşya silindi');
  });

  // KARAR 05.4 s5
  test('CPU droide girmiyor: sunucu reddediyor', () async {
    final (_, socket, hangar, _) = await kur();
    hangar.addItem(
      const ItemInstance(instanceId: 'cpu', specId: 'cpu_repair'),
    );
    socket.add(
      ClientHangar(
        action: 'droid_tak',
        payload: {'droidId': 'd0', 'instanceId': 'cpu'},
      ).encode(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(hangar.droidinDonanimi('d0'), isEmpty);
  });
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
