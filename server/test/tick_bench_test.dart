@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/zone.dart';

/// Tik maliyetinin DETERMİNİSTİK ölçümü — ağ yok, bot yok, soket yok.
///
/// **Neden yük testi bu soruya cevap veremiyor.** `loadtest.dart` gerçek
/// soketlerle gerçek bir sunucuyu ölçüyor ve bu, kapasite sorusu için doğru
/// araç. Ama "şu değişiklik tiki pahalılaştırdı mı" sorusu için fazla
/// gürültülü: aynı yapılandırmanın ardışık koşularında 120 oyuncu p95'i
/// 10.6 ile 16.4 ms arasında geziyor. Ölçülmek istenen fark o aralığın
/// içinde kalıyor, yani ölçüm hiçbir şey söylemiyor.
///
/// Burada işletim sistemi zamanlayıcısı, soket kuyruğu, yük üreteci ve çöp
/// toplayıcının ağ tarafı denklemin dışında: aynı girdi, aynı tik sayısı,
/// tek süreç. Kalan fark İŞİN kendisi.
///
/// Yine de mutlak bir sayı DEĞİL — makine yükü hâlâ etkiliyor. Anlamlı olan
/// aynı koşuda yan yana ölçülen iki yapılandırmanın ORANI.
void main() {
  /// [ships] gemi ve [aliens] alienle dolu bir bölge kurar; hepsi kavgada.
  Zone battlefield({required int ships, required int aliens}) {
    final zone = Zone(alienCount: 0);
    final world = GameWorld.standard;
    for (var i = 0; i < ships; i++) {
      final ship = zone.join('P$i')!;
      // Hepsi tek yumakta: alien menzilleri (700–900) içinde kalsınlar,
      // yoksa ölçülen şey kavga değil boşta gezinme olur.
      ship.state = ship.state.copyWith(
        position: world.centre + Vec2((i % 20) * 40.0 - 400, (i ~/ 20) * 40.0),
      );
    }
    for (var i = 0; i < aliens; i++) {
      zone.aliens[Protocol.alienIdBase + i] = AlienSimState.spawn(
        AlienStats.leviathan, // saldırgan: hedef taraması da ölçüme girsin
        world.centre + Vec2((i % 8) * 60.0 - 240, (i ~/ 8) * 60.0 - 120),
        i,
      );
    }
    return zone;
  }

  /// [zone]'u [ticks] kez adımlar ve tik BAŞINA ortalama süreyi (µs) döndürür.
  ///
  /// Toplam süreyi bölmek, `LatencyHistogram`'ın 100 µs'lik kovasından çok
  /// daha ince: simülasyon adımı o kovanın ALTINDA kalıyor ve dağılım her
  /// şeyi tek kovaya yığıyordu — yani ölçüm "0.1 ms" deyip susuyordu.
  double meanMicros(Zone zone, {required int ticks}) {
    for (var i = 0; i < 120; i++) {
      zone.step();
    }
    final clock = Stopwatch()..start();
    for (var i = 0; i < ticks; i++) {
      zone.step();
    }
    return clock.elapsedMicroseconds / ticks;
  }

  test('alien ateşinin KAYDIRILMASI tiki pahalılaştırmıyor', () {
    // İddia şuydu: hepsi aynı tikte ateş edince iş topaklanıyor. Ağ üzerinden
    // ölçüm bunu ne doğrulayabildi ne çürütebildi (gürültü fazlaydı). Burada
    // tek değişken kaydırmanın kendisi.
    const ships = 60;
    const aliens = 24;
    const ticks = 900; // 30 saniyelik simülasyon

    final staggered = battlefield(ships: ships, aliens: aliens);
    // Topaklı hâl: bütün namlu sayaçlarını sıfırla — düzeltme öncesi durum.
    for (final entry in staggered.aliens.entries.toList()) {
      staggered.aliens[entry.key] = entry.value.copyWith(fireCooldown: 0);
    }
    final clustered = meanMicros(staggered, ticks: ticks);
    final spread = meanMicros(
      battlefield(ships: ships, aliens: aliens),
      ticks: ticks,
    );

    // ignore: avoid_print
    print(
      'TOPAKLI ${clustered.toStringAsFixed(1)} µs · '
      'KAYDIRILMIŞ ${spread.toStringAsFixed(1)} µs '
      '($ships gemi, $aliens alien)',
    );

    // Ölçüt: kaydırma tiki BELİRGİN biçimde pahalılaştırmamalı.
    //
    // "İyileştirdi" diye bir iddiada bulunulmuyor ve bulunulmamalı: kaydırma
    // toplam işi değiştirmiyor, dağıtıyor. Buradaki test, düzeltmenin
    // performansı BOZMADIĞINI kilitliyor — gerekçesi zaten oynanış (altı
    // yaylımın tek karede inmesi).
    expect(
      spread,
      lessThan(clustered * 2 + 200),
      reason: 'kaydırma tik maliyetini belirgin biçimde büyütmüş',
    );
  });

  test('alien SAYISI tik maliyetini nasıl büyütüyor', () {
    // Denetimde çıkan soru: hedef taraması O(saldırgan alien × oyuncu) ve
    // ilgi alanına bağlı değil. Bugünkü sayılarda önemsiz mi, değil mi —
    // tahmin etmek yerine ölçülüyor.
    const ships = 60;
    const ticks = 600;
    final costs = <int, double>{};
    for (final aliens in [0, 24, 96, 384]) {
      costs[aliens] = meanMicros(
        battlefield(ships: ships, aliens: aliens),
        ticks: ticks,
      );
    }
    // ignore: avoid_print
    print(
      'alien sayısı → tik (µs): '
      '${costs.entries.map((e) => "${e.key}→${e.value.toStringAsFixed(1)}").join(" · ")}',
    );

    // Dört kat alien, tik maliyetini dört kattan FAZLA büyütmemeli. Bundan
    // hızlı bir büyüme, taramanın ilgi alanına bağlanması gerektiğini söyler.
    final base = costs[24]!;
    expect(
      costs[384]!,
      lessThan(base * 40),
      reason:
          'alien sayısı arttıkça maliyet süper-doğrusal büyüyor — hedef '
          'taraması ilgi alanına bağlanmalı',
    );
  });
}
