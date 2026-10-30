@Tags(['turetme'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// PRD ÇÖZÜCÜSÜNÜN doğrulaması.
///
/// Sayı tablosu 03 şunu iddia ediyor: *"Çözücü doğrulandı: %5 ve %10 için
/// yayımlanmış Dota 2 sabitlerini birebir üretiyor."* İddia burada duruyorsa
/// test de burada durmalı — yoksa iddia bir cümle olarak kalır.
void main() {
  group('PRD sabiti', () {
    /// Valve'ın yayımladığı `C` değerleri. Bizim çözücümüzle üretilmedi;
    /// dışarıdan gelen bağımsız bir referans, ve bir çözücünün
    /// doğrulanabilmesinin tek yolu bu.
    const yayimlanan = [
      (0.05, 0.00380166),
      (0.10, 0.01474584),
      (0.15, 0.03222091),
      (0.20, 0.05570404),
      (0.25, 0.08474409),
      (0.30, 0.11894919),
    ];

    test('yayımlanmış Dota 2 sabitlerini BİREBİR üretir', () {
      for (final (oran, sabit) in yayimlanan) {
        expect(
          Prd.constantFor(oran),
          closeTo(sabit, 1e-7),
          reason: '%${(oran * 100).round()} için sabit tutmadı',
        );
      }
    });

    test('sabit, ilan edilen oranı GERÇEKTEN üretir', () {
      for (final (oran, _) in yayimlanan) {
        expect(
          Prd.effectiveChance(Prd.constantFor(oran)),
          closeTo(oran, 1e-9),
          reason: 'çözücünün kendi tanımına sadakati',
        );
      }
    });

    test('referans girdi sayı tablosundaki değeri veriyor', () {
      // Sayı tablosu 03: `Kritik PRD sabiti C = 0,084744`.
      expect(Turetilenler.kritikPrdSabiti, closeTo(0.084744, 5e-7));
    });

    test('12 yaylımda kritik GARANTİ', () {
      // `1 ÷ C` — bağımsız zarda böyle bir taban yok.
      expect(Prd.guaranteedAt(Turetilenler.kritikPrdSabiti), 12);
    });
  });

  group('PRD zarı', () {
    test('uzun vadeli oran ilan edilen orana yakınsar', () {
      final roller = PrdRoller(TasarimGirdileri.kritikSansiReferans);
      final random = math.Random(1);
      var hits = 0;
      const n = 200000;
      for (var i = 0; i < n; i++) {
        if (roller.roll(random)) hits++;
      }
      expect(
        hits / n,
        closeTo(TasarimGirdileri.kritikSansiReferans, 0.005),
        reason:
            'ilan edilen oran ile YAŞANAN oran ayrışırsa, oyuncu haklı olarak '
            'sistemin bozuk olduğunu düşünür',
      );
    });

    test('kuraklık KESİLİYOR — garanti eşiğinden uzun seri yok', () {
      final roller = PrdRoller(TasarimGirdileri.kritikSansiReferans);
      final random = math.Random(2);
      final tavan = Prd.guaranteedAt(Turetilenler.kritikPrdSabiti);
      var streak = 0;
      var worst = 0;
      for (var i = 0; i < 200000; i++) {
        if (roller.roll(random)) {
          streak = 0;
        } else {
          streak++;
          if (streak > worst) worst = streak;
        }
      }
      expect(
        worst,
        lessThan(tavan),
        reason:
            'bağımsız zarın kuyruğu budanmadı; PRD\'nin var olma sebebi tam '
            'olarak bu kuyruk',
      );
    });

    test('bağımsız zardan DAHA KISA kuraklık üretiyor', () {
      // Sayı tablosu 03'ün karşılaştırma tablosunun testi: PRD'nin p99'u
      // bağımsız zarınkinden küçük olmak ZORUNDA, yoksa değişimin bir
      // gerekçesi kalmaz.
      List<int> araliklar(bool Function(math.Random) at, int seed) {
        final random = math.Random(seed);
        final out = <int>[];
        var bekleyen = 0;
        for (var i = 0; i < 200000; i++) {
          bekleyen++;
          if (at(random)) {
            out.add(bekleyen);
            bekleyen = 0;
          }
        }
        return out..sort();
      }

      int p(List<int> xs, double q) => xs[(xs.length * q).floor()];

      final roller = PrdRoller(TasarimGirdileri.kritikSansiReferans);
      final prd = araliklar(roller.roll, 3);
      final bagimsiz = araliklar(
        (r) => r.nextDouble() < TasarimGirdileri.kritikSansiReferans,
        3,
      );

      expect(p(prd, 0.95), lessThan(p(bagimsiz, 0.95)));
      expect(p(prd, 0.99), lessThan(p(bagimsiz, 0.99)));
    });
  });
}
