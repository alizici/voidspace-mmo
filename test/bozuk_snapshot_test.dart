@Tags(['disi'])
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/lag_proxy.dart';

import 'game_harness.dart';

/// BOZUK SNAPSHOT — istemci donmuyor, kopup toparlanıyor.
///
/// Snapshot çözme yolu genel çözücünün try/catch'ini ATLIYOR: `decodeWith`
/// dünya ölçülerini bilmeyi gerektirdiği için ayrı çağrılıyor. Fırlayan
/// istisna hiçbir yere gitmiyordu — `onError` `onData`'dan fırlayanı
/// yakalamıyor, yani `_fail` hiç çalışmıyor, faz `playing`de kalıyor ve ekran
/// sessizce donuyordu.
///
/// **Neden atlamak değil koparmak.** `EntitySnapshot.read` delta'yı temelin
/// üstüne YERİNDE yazıyor. Yarıda kalan bir çözme, temelin bir kısmını yeni
/// tike ilerletip gerisini eskide bırakıyor; o karışım kalıcı olur ve sonraki
/// bütün delta'lar hiçbir istisna atmadan yanlış konum üretir. Tek güvenli
/// davranış temeli atıp yeniden senkronize olmak — `_fail` zaten bunu yapıyor.
void main() {
  // Varsayılan 30 sn YETMİYOR: test gerçek soketlerle koşuyor ve içinde bir
  // kopma + yeniden bağlanma turu var. Tek başına ~2 sn sürüyor ama tam takım
  // altında, diğer ağ testleriyle port ve CPU paylaşırken uzuyor.
  test(
    'bozuk snapshot istemciyi DONDURMUYOR — kopuyor ve dönüyor',
    timeout: const Timeout(Duration(seconds: 90)),
    () async {
      final gateway = await bootServer();
      final komsu = await connectClient(gateway, 'Komsu');
      await awaitPlaying([komsu]);

      // İlk snapshot'tan sonrakini boz: entity sayacını şişirmek çözücüyü
      // olmayan kayıtları okumaya zorluyor.
      var bozulan = 0;
      // BOZMA KAPISI. İstemci `playing`e girene kadar hiçbir çerçeve
      // bozulmuyor.
      //
      // Kapı olmadan test ara sıra kendi kendini yeniyordu: ilk snapshot,
      // istemcinin fazı `playing`e dönmeden önce gelebiliyor. O an istemci
      // doğru davranıp kopuyor ve yeniden bağlanıyor, `awaitPlaying` sonradan
      // başarılı oluyor — ama bozulacak TEK çerçeve çoktan harcanmış oluyor
      // ve test sonsuza kadar gelmeyecek bir kopmayı bekliyordu.
      //
      // Yani "istemci dondu" diyen satır, aslında donmayan bir istemciyi
      // suçluyordu.
      var bozmayaHazir = false;
      final proxy = LagProxy(
        upstreamPort: gateway.port,
        rttMs: 0,
        corruptDownstream: (data) {
          if (data is! List<int> || data.isEmpty) return data;
          if (data[0] != Protocol.msgSnapshot) return data;
          if (!bozmayaHazir) return data;
          // Yalnız BİR çerçeve bozuluyor: sonrasında sunucu dürüst, yani
          // istemcinin toparlanabilmesi gerekiyor.
          if (bozulan > 0) return data;
          bozulan++;
          final bytes = Uint8List.fromList(data);
          // Çerçeve BAŞLIĞIN hemen ardından kesiliyor: tip (1) + tik (4), ve
          // bir bayt daha. Ardından gelen `SelfSnapshot` tek baytta bitmiyor,
          // yani çözücü kesin olarak eksik bayt okuyor.
          //
          // Önceki hâli çerçeveyi YARIYA kırpıyordu ve bu bozmayı garanti
          // ETMİYORDU: snapshot boyu varlık sayısıyla değişiyor, az varlık
          // varken yarım çerçeve hâlâ çözülebiliyordu. Test o yüzden tam takım
          // altında ara sıra "istemci dondu" diyordu — donan istemci değil,
          // bozulmamış çerçeveydi.
          return Uint8List.sublistView(bytes, 0, 6);
        },
      );
      await proxy.start();
      addTearDown(proxy.stop);

      final istemci = NetClient(uri: Uri.parse('ws://127.0.0.1:${proxy.port}'));
      addTearDown(istemci.dispose);

      // Yakalanmamış istisna sayacı: eski davranışta bu 0'dan büyük olurdu ve
      // faz `playing`de kalırdı.
      // Gövde İÇERİDE yakalanıyor, dışarıda değil. Sebebi bir üslup tercihi
      // değil: `runZonedGuarded`'ın gövdesi fırlarsa hata işleyiciye gidiyor
      // ve dönen future HİÇ tamamlanmıyor — yani başarısız bir `expect`,
      // okunur bir hata yerine 90 saniyelik bir `TimeoutException` olarak
      // görünüyordu. Yan faydası: `yakalanmamis` artık gerçekten YAKALANMAMIŞ
      // eşzamansız hataları sayıyor, testin kendi iddialarını değil.
      var yakalanmamis = 0;
      Object? hata;
      StackTrace? iz;
      final bitti = Completer<void>();
      unawaited(
        runZonedGuarded(() async {
          try {
            await istemci.connect();
            await awaitPhase(istemci, NetPhase.needsAuth);
            await istemci.register(
              email: 'bozuk@test.local',
              username: 'Bozuk',
              password: testPassword,
            );
            await awaitPlaying([istemci]);
            bozmayaHazir = true;

            // Bozuk çerçevenin gelmesini bekle.
            final basladi = DateTime.now();
            while (bozulan == 0 &&
                DateTime.now().difference(basladi) <
                    const Duration(seconds: 5)) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
            expect(bozulan, 1, reason: 'proxy hiç snapshot bozamadı');

            // Kopmalı — donmamalı.
            //
            // Pencere GENİŞ (15 sn) ve bu bir gevşetme değil: ölçülen şey
            // kopma GECİKMESİ değil, kopmanın gerçekleşip gerçekleşmediği.
            // Tam takım altında bir düzine ağ testi aynı CPU'yu paylaşıyor ve
            // istemcinin olay döngüsü saniyelerce aç kalabiliyor; dar bir
            // pencere orada donmayı değil YAVAŞLIĞI ölçmeye başlıyor.
            final koptu = await _fazBekle(
              istemci,
              (p) => p != NetPhase.playing,
              const Duration(seconds: 15),
            );
            expect(
              koptu,
              isTrue,
              reason: 'istemci `playing` fazında DONDU — `_fail` çalışmadı',
            );

            // Ve toparlanmalı: sonraki snapshot'lar dürüst, yeniden bağlanan oturum
            // sunucudan TAM snapshot alıyor.
            final dondu = await _fazBekle(
              istemci,
              (p) => p == NetPhase.playing,
              const Duration(seconds: 15),
            );
            expect(dondu, isTrue, reason: 'istemci yeniden bağlanamadı');
          } catch (e, st) {
            hata = e;
            iz = st;
          } finally {
            if (!bitti.isCompleted) bitti.complete();
          }
        }, (_, _) => yakalanmamis++)!,
      );
      await bitti.future;
      if (hata != null) fail('$hata\n$iz');

      expect(
        yakalanmamis,
        0,
        reason: 'istisna kaçtı — snapshot yolu hâlâ try/catch dışında',
      );
      komsu.dispose();
    },
  );
}

Future<bool> _fazBekle(
  NetClient client,
  bool Function(NetPhase) kosul,
  Duration sure,
) async {
  final basladi = DateTime.now();
  while (DateTime.now().difference(basladi) < sure) {
    if (kosul(client.phase)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return kosul(client.phase);
}
