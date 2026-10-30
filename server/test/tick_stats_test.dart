@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_server/tick_stats.dart';

/// Kapasite kararını bu sayı verecek; sayının kendisi de doğrulanmalı.
///
/// Yanlış bir p99, yanlış bir mimari kararına dönüşür: "tek bölge 400 oyuncu
/// taşıyor" deyip çok bölgeyi ertelemek ya da tersi.
void main() {
  group('gecikme dağılımı', () {
    test('boş dağılım sıfır döner, patlamaz', () {
      final h = LatencyHistogram();
      expect(h.count, 0);
      expect(h.percentile(0.99), 0);
      expect(h.mean, 0);
    });

    test('yüzdelik KUYRUĞU okur, ortalamayı değil', () {
      // Kapasite ölçümünün bütün meselesi bu: 99 tik ucuz, 1 tik bütçeyi
      // aşıyor. Ortalama "her şey yolunda" der (1.3 ms), p99 gerçeği söyler.
      final h = LatencyHistogram();
      for (var i = 0; i < 99; i++) {
        h.add(1000);
      }
      h.add(40000);

      expect(h.mean, lessThan(1500), reason: 'ortalama sorunu gizliyor');
      expect(h.percentile(0.99), greaterThanOrEqualTo(1000));
      expect(h.percentile(1.0), greaterThanOrEqualTo(40000));
      expect(h.max, 40000);
    });

    test('yüzdelik kovanın ÜST kenarını verir — kötümser yönde', () {
      // 1250 µs, 12. kovaya (1200–1300) düşüyor ve 1300 olarak raporlanıyor.
      // Yön önemli: kapasite kararında olduğundan iyi görünmek tehlikeli.
      final h = LatencyHistogram()..add(1250);
      expect(h.percentile(0.5), 1300);
      expect(h.percentile(0.5), greaterThanOrEqualTo(1250));
    });

    test('kova dışına taşan tik p99\'u kilitlemez', () {
      // Taşanları son kovaya yığmak, 500 ms süren bir tiki 102 ms gibi
      // gösterirdi — yani sunucu çökerken grafik düzelirdi.
      final h = LatencyHistogram();
      for (var i = 0; i < 90; i++) {
        h.add(1000);
      }
      for (var i = 0; i < 10; i++) {
        h.add(500000); // 500 ms
      }
      expect(h.percentile(0.99), greaterThan(102400));
      expect(h.max, 500000);
    });

    test('sıfırlama gerçekten sıfırlar — pencereler sızmaz', () {
      // Rapor beş saniyelik pencerelerle çıkıyor. Sızan bir kova, yükü
      // kaldırdıktan sonra da kötü p99 göstermeye devam ederdi.
      final h = LatencyHistogram()
        ..add(50000)
        ..reset()
        ..add(1000);
      expect(h.max, 1000);
      expect(h.percentile(0.99), lessThanOrEqualTo(1100));
    });

    test('yüzdelikler MONOTON', () {
      final h = LatencyHistogram();
      for (var i = 0; i < 1000; i++) {
        h.add(i * 37 % 20000);
      }
      expect(h.percentile(0.5), lessThanOrEqualTo(h.percentile(0.95)));
      expect(h.percentile(0.95), lessThanOrEqualTo(h.percentile(0.99)));
      expect(h.percentile(0.99), lessThanOrEqualTo(h.max + 100));
    });
  });
}
