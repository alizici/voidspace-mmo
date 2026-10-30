@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/net/token_store.dart';

import 'game_harness.dart';

/// MOBİL yaşam döngüsü sözleşmesi.
///
/// Bu dosya bir özelliği değil bir platformu doğruluyor: oyun iOS, Android ve
/// macOS için geliştiriliyor ve mobilde uygulama sürekli arka plana alınıyor,
/// öldürülüyor, ağ değiştiriyor. Bunların hiçbiri ele alınmıyordu — kodda tek
/// bir `WidgetsBindingObserver` yoktu.
void main() {
  test(
    'arka plana alınınca bağlantı KAPANIR, öne gelince geri gelir',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);
      expect(gateway.zone.ships, hasLength(1));

      client.suspend();
      expect(client.phase, NetPhase.disconnected);

      // Sunucudaki gemi SİLİNMEZ, sahipsiz bekler: oyuncu geri gelince aynı
      // gemiye dönmeli.
      await _until(() => gateway.zone.ships.values.single.isOrphan);
      expect(gateway.zone.ships, hasLength(1), reason: 'gemi silindi');

      client.resume();
      await awaitPlaying([client]);
      expect(gateway.zone.ships, hasLength(1), reason: 'ikinci gemi doğdu');
      expect(
        gateway.zone.ships.values.single.isOrphan,
        isFalse,
        reason: 'gemi geri alınmadı',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'askıdayken yeniden bağlanmaya ÇALIŞMAZ',
    () async {
      // Askıya alınmış bir uygulamada bağlanmayı denemek yalnız pil yakar —
      // üstelik zamanlayıcılar arka planda zaten donuyor, yani dönüşte birikmiş
      // bir deneme seli oluşurdu.
      final client = NetClient(uri: Uri.parse('ws://127.0.0.1:1'));
      addTearDown(client.dispose);
      await client.connect();
      client.suspend();

      // FAZI değil DENEME SAYISINI say.
      //
      // İlk yazışta "3 saniye sonra faz `disconnected` olmalı" diyordum ve
      // hiçbir şeyi kanıtlamıyordu: yeniden deneme açıkken de faz sürekli
      // `connecting` ↔ `disconnected` arasında gidip geliyor, üç saniye sonra
      // hangisinde olduğu şansa kalıyordu. Testi iki korumayı da kaldırarak
      // sınadım — yine yeşildi. Sayaç o boşluğu kapatıyor.
      var attempts = 0;
      final sub = client.changes.listen((_) {
        if (client.phase == NetPhase.connecting) attempts++;
      });
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(seconds: 3));
      expect(
        attempts,
        0,
        reason: 'askıdayken $attempts kez yeniden bağlanmaya çalışıldı',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'el sıkışma SÜRERKEN arka plana geçmek soket SIZDIRMAZ',
    () async {
      // Gerçek bir sızıntıydı: `connect()` içinde `await channel.ready`
      // beklenirken uygulama arka plana alınırsa, soket açılıp AÇIK kalıyordu —
      // kimse okumuyor, sunucu tarafında sahte bir oturum duruyordu. Mobilde bu
      // sık: bağlanma anı tam da oyuncunun uygulamayı açıp kapattığı an.
      final gateway = await bootServer();
      addTearDown(gateway.stop);

      final client = NetClient(
        uri: Uri.parse('ws://127.0.0.1:${gateway.port}'),
      );
      addTearDown(client.dispose);

      // BEKLEMEDEN askıya al: el sıkışma hâlâ uçuşta.
      final connecting = client.connect();
      client.suspend();
      await connecting;

      // Sunucuda asılı kalan bir soket olmamalı.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
        gateway.zone.ships,
        isEmpty,
        reason: 'yarım kalan el sıkışmadan gemi doğdu',
      );
      expect(client.phase, NetPhase.disconnected);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'belirteç DİSKTE kalır — uygulama öldürülse de parola sorulmaz',
    () async {
      // Mobilde işletim sistemi uygulamayı rutin olarak öldürüyor. Bellekte
      // tutulan bir belirteç, oyuncunun her dönüşünde parola ekranı demekti.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final store = MemoryTokenStore();

      final first = NetClient(
        uri: Uri.parse('ws://127.0.0.1:${gateway.port}'),
        tokens: store,
      );
      await first.connect();
      await awaitPhase(first, NetPhase.needsAuth);
      await first.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: testPassword,
      );
      await awaitAuthenticated(first);
      await awaitPlaying([first]);
      expect(await store.read(), isNotNull, reason: 'belirteç yazılmadı');
      first.dispose();

      // Uygulama ÖLDÜ ve yeniden açıldı: yepyeni bir istemci, aynı depo.
      final second = NetClient(
        uri: Uri.parse('ws://127.0.0.1:${gateway.port}'),
        tokens: store,
      );
      addTearDown(second.dispose);
      await second.restoreSession();
      await second.connect();

      // Parola SORULMADAN dünyaya girmeli.
      await awaitPlaying([second]);
      expect(second.phase, NetPhase.playing);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('koşul sağlanmadı');
}
