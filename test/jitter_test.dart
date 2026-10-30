@Tags(['disi', 'zaman'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/lag_proxy.dart';

import 'game_harness.dart';

/// ZAYIF AĞ altında uzak gemilerin pürüzsüzlüğü.
///
/// Ara değer tamponu SABİT 2 tikken (66 ms) ölçülen, ekranda GERÇEKTEN donan
/// kare oranı:
///
/// | koşul                       | sabit tampon | uyarlanan |
/// |-----------------------------|--------------|-----------|
/// | 160 ms · ±40..100 titreşim  | %1.8–2.5     | ~%1.5     |
/// | 500 ms · ±200 · %2 kayıp    | **%13–16**   | **~%3.6** |
///
/// Yani orta seviye titreşimde sabit tampon zaten iyiydi; UÇ koşulda —
/// yurt dışı sunucu + mobil ağ — çöküyordu. Uyarlanan tampon o uçtaki
/// çöküşü kaldırıyor ve iyi ağda hiçbir şey ödemiyor (sakin ağda derinleşmez).
///
/// Buradaki iki test de AYIRT EDİCİ: uyarlama kapatıldığında ikisi de
/// kırmızıya döner. Ayırt etmeyen bir test, koruduğunu sandığın şeyi
/// korumaz — o yüzden orta seviye titreşim için ayrı bir test YOK, çünkü
/// orada iki tasarım arasında ölçülebilir fark yok.
///
/// Testler gerçek soketler ve [LagProxy] üzerinden koşuyor: gecikmeyi taklit
/// edemeden gecikme düzeltmesi doğrulanamaz.
///
/// `zaman` etiketi: ölçüm gerçek zamana bağlı ve tam koşuda makine yük
/// altındayken seğirebiliyor (borç defteri B8). Etiket tür değil nitelik;
/// `flutter test --exclude-tags zaman` yük altındaki koşudan ayırır.
void main() {
  /// Ölçümü bir kez daha dener.
  ///
  /// Tam koşuda bir kez eşiği aştı, tek başına hep geçti. Sahte saat çare
  /// değil: gerçek soketin ve işletim sisteminin zamanlamasını taklit
  /// edemez. Gerçek bir gerileme iki denemede de düşer; seğirme ikisinde
  /// birden çok nadir.
  Future<void> ikiDenemede(Future<void> Function() olc) async {
    try {
      await olc();
    } on TestFailure catch (e) {
      // ignore: avoid_print
      print('ilk deneme düştü, ikinci deneniyor: ${e.message}');
      await olc();
    }
  }

  /// SUNUCUNUN kendi tikini tutturduğu bir pencere ölçülene kadar dener.
  ///
  /// **Bu test ağı ölçüyor, MAKİNEYİ değil.** Sunucu burada ayrı bir kutuda
  /// değil, testin kendi sürecinde koşuyor; yerel makine tıkanırsa sunucunun
  /// 30 Hz tiki de kayıyor ve anlık görüntüler geç, öbek öbek geliyor. O
  /// pencerede ara değer tamponu gerçekten kuruyor ve donan kare oranı
  /// fırlıyor — ama ölçtüğü şey kötü bir ağ değil, meşgul bir makine. Üretimde
  /// sunucu başka bir kutuda ve istemcinin CPU'suyla hiç ilgisi yok.
  ///
  /// [ikiDenemede] bunu kurtarmıyor ve sebebi mekanizmada: o, GEÇİCİ gürültüye
  /// karşı çalışıyor — gerçek bir gerileme iki denemede de düşer, tek seferlik
  /// bir sıçrama düşmez. Tam koşunun yükü ise geçici değil SÜREKLİ; iki deneme
  /// de aynı tıkalı makinede geçiyor ve ikisi birden kayabiliyor.
  ///
  /// Bu yüzden pencere ölçülmeden ÖNCE değil, ölçüldükten SONRA yargılanıyor:
  /// sunucu kendi tikini tutturamadıysa örnek geçersiz, ölçüm yenileniyor.
  /// Eşiği gevşetmek yerine bu seçildi, çünkü 0,17 eşiği testin ayırt edici
  /// gücünün ta kendisi: doğru tasarım %8–13,3, bozuk tasarım %20,3–26,4
  /// ölçüyor ve eşiği yukarı itmek testi iki dağılımı ayırt edemez hâle
  /// getirirdi.
  ///
  /// Üç deneme sonunda hâlâ sağlıklı pencere yoksa test AÇIKÇA "ölçüm
  /// yapılamadı" diye düşüyor — sessizce geçmek, koruduğunu sandığın şeyi
  /// korumamak olurdu.
  Future<T> saglikli<
    T extends ({double frozen, double maxStep, double delay, double sunucuHz})
  >(Future<T> Function() olc) async {
    // 30 Hz hedefin %93'ü. Altı, sunucunun aç kaldığı pencere.
    const enAzHz = 28.0;
    for (var deneme = 1; deneme <= 3; deneme++) {
      final r = await olc();
      if (r.sunucuHz >= enAzHz) return r;
      // ignore: avoid_print
      print(
        'ölçüm geçersiz: sunucu ${r.sunucuHz.toStringAsFixed(1)} Hz '
        '(hedef 30) — makine tıkalı, $deneme. deneme',
      );
    }
    fail('sunucu üç denemede de tikini tutturamadı: ölçüm yapılamadı');
  }

  /// [rtt]/[jitter] altında komşu bir gemiyi izler ve pürüzsüzlüğü ölçer.
  Future<({double frozen, double maxStep, double delay, double sunucuHz})> fly({
    required int rtt,
    required int jitter,
    double loss = 0,
    double seconds = 4,
  }) async {
    final gateway = await bootServer();
    final neighbour = await connectClient(gateway, 'Komsu');
    await awaitPlaying([neighbour]);
    // Komşu SABİT HIZLA uçuyor: ekranda da sabit hızla ilerlemeli.
    neighbour.ship!.axis = const Vec2(1, 0);

    final proxy = LagProxy(
      upstreamPort: gateway.port,
      rttMs: rtt,
      jitterMs: jitter,
      loss: loss,
    );
    await proxy.start();
    addTearDown(proxy.stop);

    final laggy = NetClient(uri: Uri.parse('ws://127.0.0.1:${proxy.port}'));
    addTearDown(laggy.dispose);
    await laggy.connect();
    await awaitPhase(laggy, NetPhase.needsAuth);
    await laggy.register(
      email: 'gecikmeli@test.local',
      username: 'Gecikmeli',
      password: testPassword,
    );
    await awaitAuthenticated(laggy);
    await awaitPlaying([laggy]);
    addTearDown(neighbour.dispose);
    addTearDown(gateway.stop);

    // Sunucunun tik sayacı ölçümün BAŞINDA: pencerenin sonunda kaç tik
    // attığı, o pencerede yerel makinenin sunucuyu aç bırakıp bırakmadığını
    // söylüyor (aşağıya bkz. [saglikli]).
    final tikBasi = gateway.tick;
    var frames = 0;
    var frozen = 0;
    var maxStep = 0.0;
    var maxDelay = 0.0;
    double? lastX;

    await pump(
      [laggy, neighbour],
      seconds,
      each: () {
        frames++;
        if (laggy.remotes.delayTicks > maxDelay) {
          maxDelay = laggy.remotes.delayTicks;
        }
        final pose = laggy.remotes.poseOf(neighbour.entityId);
        if (pose == null) return;
        if (lastX != null) {
          final step = (pose.x - lastX!).abs();
          // Donma: kare ilerlemedi.
          if (step < 0.01) frozen++;
          if (step > maxStep) maxStep = step;
        }
        lastX = pose.x;
      },
    );

    return (
      frozen: frames == 0 ? 1.0 : frozen / frames,
      maxStep: maxStep,
      delay: maxDelay,
      sunucuHz: (gateway.tick - tikBasi) / seconds,
    );
  }

  test(
    'titreşim tamponu BÜYÜTÜR, sakin ağda büyütmez',
    () => ikiDenemede(() async {
      // Uyarlamanın kendisi: tampon derinliği ölçülen titreşimin sonucu olmalı,
      // sabit bir sayı değil.
      final calm = await saglikli(() => fly(rtt: 60, jitter: 0));
      final rough = await saglikli(() => fly(rtt: 160, jitter: 120));

      expect(
        calm.delay,
        lessThan(4),
        reason:
            'sakin ağda tampon boşuna derinleşti — görsel gecikme bedava değil',
      );
      expect(
        rough.delay,
        greaterThan(calm.delay + 1),
        reason: 'titreşim altında tampon derinleşmedi — uyarlama çalışmıyor',
      );
    }),
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    '500 ms ve %2 kayıpta bile ne DONMA ne IŞINLANMA',
    () async {
      // Uç koşul: yurt dışı sunucu + mobil ağ. Burada hedef "iyi ping" değil,
      // OYNANABİLİRLİK — gemi pürüzsüz gitsin, ışınlanmasın.
      //
      // Eşik TAHMİN değil, iki dağılımın ölçülmüş arasından seçildi:
      //
      //   uyarlanan tampon (doğru) : %8 – 13.3
      //   sabit tampon    (bozuk)  : %20.3 – 26.4
      //
      // %17 ikisinin ortasında: doğru tasarım hiçbir koşuda buraya değmiyor,
      // bozuk tasarım hiçbir koşuda altına inmiyor. Eşiği iyileşen tarafa
      // yapıştırmak testi makine yüküne duyarlı hâle getirirdi — ölçüm gerçek
      // soketler üzerinde koşuyor.
      await ikiDenemede(() async {
        final r = await saglikli(() => fly(rtt: 500, jitter: 200, loss: 0.02));
        expect(
          r.frozen,
          lessThan(0.17),
          reason: 'donan kare %${(r.frozen * 100).toStringAsFixed(1)}',
        );
        // 320 birim/sn hızda 16 ms'lik kare ~5 birim ilerler. 60 birim,
        // normal adımın on katı: ışınlanma eşiği.
        expect(
          r.maxStep,
          lessThan(60),
          reason: 'tek karede ${r.maxStep.toStringAsFixed(1)} birim sıçradı',
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
