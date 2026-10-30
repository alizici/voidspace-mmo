@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// DROİD DAYANIKLILIĞI SUNUCUDA (05.10).
///
/// Sayaç ölüm ANINDAN iniyor: kaynak `Zone.deaths`, yani tamir bedeliyle aynı
/// yer ama ayrı bir geçiş. Ölçülen üç şey: ölüm sayacı indiriyor, sıfırlanan
/// droid filodan siliniyor, ve onarım NOVA'yı kesip sayacı dolduruyor.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_droid'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(Gateway, WebSocket, Hangar)> kur({int premium = 0}) async {
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
    if (premium > 0) {
      hangar.earn(
        Currency.premium,
        premium,
        reason: LedgerReason.signup,
        txId: 'fon',
        atMillis: 0,
      );
    }
    // Droid açılışı üçüncü rankta (10.7); filo için bir B-I eşya ve iki droid.
    hangar.addItem(const ItemInstance(instanceId: 'acilis', specId: 'pl5'));
    for (final id in ['d0', 'd1']) {
      hangar.addItem(ItemInstance(instanceId: id, specId: 'dr1'));
      expect(HangarRules.filoyaAl(hangar, id), isNull);
    }
    return (gateway, socket, hangar);
  }

  /// Gemiyi öldürür: kalkan ve gövde sıfır, ölümü bir sonraki tik okuyor.
  void oldur(Gateway gateway) {
    final ship = gateway.zone.ships.values.single;
    ship.state = ship.state.copyWith(shield: 0, hull: 0);
  }

  // KARAR 05.10 s1
  test('ana gemi öldüğünde filodaki her droid bir adım aşınıyor', () async {
    final (gateway, _, hangar) = await kur();
    expect(hangar.itemOf('d0')!.dayaniklilik, ItemInstance.tamDayaniklilik);

    oldur(gateway);
    await _until(() => hangar.itemOf('d0')!.asinmis);

    const beklenen =
        ItemInstance.tamDayaniklilik - TasarimGirdileri.droidAsinmaPayi;
    expect(hangar.itemOf('d0')!.dayaniklilik, beklenen);
    expect(hangar.itemOf('d1')!.dayaniklilik, beklenen, reason: 'ikincisi');
    // Bir ölüm bir adım: yeniden doğuş ikinci kez aşındırmıyor.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(hangar.itemOf('d0')!.dayaniklilik, beklenen);
  });

  // KARAR 05.10 s1
  test('sayacı biten droid filodan ve envanterden siliniyor', () async {
    final (gateway, _, hangar) = await kur();
    // Son adıma kadar elle indir; son adımı ölüm versin.
    for (var i = 1; i < Turetilenler.droidOmruOlum; i++) {
      hangar.filoyuAsindir();
    }
    expect(hangar.filo, hasLength(2));

    oldur(gateway);
    await _until(() => hangar.filo.isEmpty);
    expect(hangar.itemOf('d0'), isNull);
    expect(hangar.itemOf('d1'), isNull);
  });

  // KARAR 05.10 s1 · KARAR 15.3 s3
  test('onarım NOVA kesiyor ve sayacı dolduruyor', () async {
    final (gateway, socket, hangar) = await kur(premium: 100000);
    oldur(gateway);
    await _until(() => hangar.itemOf('d0')!.asinmis);
    final once = hangar.premium;
    final bedel = Kazanc.droidOnarimNovaFor(
      ItemTier.cI,
      puan: TasarimGirdileri.droidAsinmaPayi,
    );

    socket.add(
      ClientHangar(
        action: 'droid_onar',
        payload: {'instanceId': 'd0'},
      ).encode(),
    );
    await _until(() => !hangar.itemOf('d0')!.asinmis);

    expect(hangar.premium, once - bedel);
    expect(hangar.itemOf('d0')!.dayaniklilik, ItemInstance.tamDayaniklilik);
    // Öteki droid onarılmadı: onarım tek eşyaya.
    expect(hangar.itemOf('d1')!.asinmis, isTrue);
  });

  // KARAR 05.10 s1
  test('NOVA yoksa onarım reddediliyor, sayaç aşınmış kalıyor', () async {
    final (gateway, socket, hangar) = await kur();
    // Yeni hesap NOVA ile geliyor (Hangar.startingPremium): kese boşaltılıyor,
    // yoksa onarım başarılı olur ve test yanlış şeyi ölçer.
    expect(
      hangar.spend(
        Currency.premium,
        hangar.premium,
        reason: LedgerReason.purchase,
        txId: 'bosalt',
        atMillis: 0,
      ),
      isTrue,
    );
    oldur(gateway);
    await _until(() => hangar.itemOf('d0')!.asinmis);

    socket.add(
      ClientHangar(
        action: 'droid_onar',
        payload: {'instanceId': 'd0'},
      ).encode(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(hangar.premium, 0);
    expect(hangar.itemOf('d0')!.asinmis, isTrue);
  });
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
