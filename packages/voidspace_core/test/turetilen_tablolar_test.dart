@Tags(['turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// TÜRETİLEN TABLOLAR — merdiven matematiği.
///
/// Bu dosyanın işi, tasarım belgelerinin ilan ettiği sayıları formülün
/// GERÇEKTEN ürettiğini kilitlemek. Belgedeki bir tablo ile koddaki bir
/// fonksiyon ayrıştığında ikisinden hangisinin doğru olduğunu kimse
/// bilemiyor — ve o an sayı, gerekçesi ona uydurulan bir sayıya dönüşüyor.
///
/// Girdiler burada AÇIKÇA yazılı, `TasarimGirdileri`'nden okunmuyor: ait
/// oldukları alanlar (06 · rank, 10 · merdiven ölçeği) henüz `bekliyor` ve
/// mimari testi yazılmamış alanın girdisini tepe tabloya sokmuyor. Alanlar
/// yazıldığında bu sayılar oradan gelecek ve bu dosya bağlayıcıyı sınayacak.
void main() {
  // Tasarım belgelerinin ilan ettiği ölçek.
  const rankArtisi = 1.442;
  const rankSayisi = 20;
  const kademeSayisi = 8;
  const gelirUssu = 0.816;
  const tabanGelir = 144000.0;

  group('rank merdiveni', () {
    test('kademe 0 taban, sonrası üs', () {
      expect(TuretilenTablolar.rankCarpaniFor(0, rankArtisi), 1.0);
      expect(
        TuretilenTablolar.rankCarpaniFor(1, rankArtisi),
        closeTo(1.442, 1e-9),
      );
    });

    test('yirmi rankın çarpanları belgeyle uyuşuyor', () {
      // Belgedeki tablo — harf aileleri ve iki kapak taşı.
      const beklenen = {
        0: 1.0, // C-I
        2: 2.079, // C-III
        5: 6.235, // B-III
        8: 18.695, // A-III
        11: 56.055, // S-III
        14: 168.06, // SS-III
        17: 503.90, // SSS-III
        18: 726.62, // Kırmızı
        19: 1047.79, // Parlayan Pembe
      };
      beklenen.forEach((kademe, deger) {
        expect(
          TuretilenTablolar.rankCarpaniFor(kademe, rankArtisi),
          closeTo(deger, deger * 0.001),
          reason: 'rank $kademe',
        );
      });
    });

    test('eksi kademe reddediliyor', () {
      expect(
        () => TuretilenTablolar.rankCarpaniFor(-1, rankArtisi),
        throwsArgumentError,
      );
    });
  });

  group('gövde kademesi ↔ rank aralığı', () {
    test('sekiz kademe yirmi rankı BOŞLUKSUZ ve ÇAKIŞMASIZ bölüyor', () {
      var beklenenBaslangic = 0;
      final kapsanan = <int>{};
      for (var k = 0; k < kademeSayisi; k++) {
        final (bas, bit) = TuretilenTablolar.rankAraligiFor(
          k,
          rankSayisi: rankSayisi,
          kademeSayisi: kademeSayisi,
        );
        expect(bas, beklenenBaslangic, reason: 'kademe $k boşluk/çakışma');
        expect(bit, greaterThan(bas), reason: 'kademe $k boş');
        for (var i = bas; i < bit; i++) {
          kapsanan.add(i);
        }
        beklenenBaslangic = bit;
      }
      expect(beklenenBaslangic, rankSayisi, reason: 'son rank kapsanmadı');
      expect(kapsanan, hasLength(rankSayisi));
    });

    test('kademeler 2 ve 3 rank arasında dönüşümlü', () {
      final boyutlar = [
        for (var k = 0; k < kademeSayisi; k++)
          () {
            final (b, s) = TuretilenTablolar.rankAraligiFor(
              k,
              rankSayisi: rankSayisi,
              kademeSayisi: kademeSayisi,
            );
            return s - b;
          }(),
      ];
      expect(boyutlar, [2, 3, 2, 3, 2, 3, 2, 3]);
    });

    test('kademe sayısı rank sayısını AŞAMAZ — boş kademe doğar', () {
      expect(
        () =>
            TuretilenTablolar.rankAraligiFor(0, rankSayisi: 5, kademeSayisi: 8),
        throwsArgumentError,
      );
    });
  });

  group('kademe normalizatörü', () {
    test('N(0) her zaman 1', () {
      for (final k in [4, 5, 7, 8]) {
        expect(
          TuretilenTablolar.normalizatorFor(
            0,
            rankSayisi: rankSayisi,
            kademeSayisi: k,
            artis: rankArtisi,
          ),
          closeTo(1.0, 1e-12),
          reason: '$k kademe',
        );
      }
    });

    test('20 rank × 8 kademe UYUMLU — kademe oranı sabit ×2,497', () {
      expect(
        TuretilenTablolar.uyumluBolme(
          rankSayisi: rankSayisi,
          kademeSayisi: kademeSayisi,
        ),
        isTrue,
      );

      final n = [
        for (var k = 0; k < kademeSayisi; k++)
          TuretilenTablolar.normalizatorFor(
            k,
            rankSayisi: rankSayisi,
            kademeSayisi: kademeSayisi,
            artis: rankArtisi,
          ),
      ];
      for (var k = 1; k < kademeSayisi; k++) {
        expect(
          n[k] / n[k - 1],
          closeTo(2.497, 0.001),
          reason: 'kademe ${k - 1}→$k sıçraması eşit değil',
        );
      }
      // Tavan: sekizinci kademe, birincinin 605 katı.
      expect(n.last, closeTo(605.19, 0.1));
    });

    test('UYUMSUZ bölmede kapalı form ayrışıyor — teşhis çalışıyor', () {
      // 20 × 7 ve 19 × 8 düzensiz merdiven üretiyor: kademeler arası güç
      // sıçraması eşit olmuyor. Bu testin işi kapalı formu doğrulamak değil,
      // AYRIŞMANIN görülebildiğini kilitlemek.
      for (final (r, k) in [(20, 7), (19, 8), (20, 6)]) {
        expect(
          TuretilenTablolar.uyumluBolme(rankSayisi: r, kademeSayisi: k),
          isFalse,
          reason: '$r rank × $k kademe uyumlu çıktı',
        );
      }
    });

    test('uyumlu bölmede kapalı form BİREBİR tutuyor', () {
      for (var k = 0; k < kademeSayisi; k++) {
        expect(
          TuretilenTablolar.normalizatorKapaliFor(
            k,
            rankSayisi: rankSayisi,
            kademeSayisi: kademeSayisi,
            artis: rankArtisi,
          ),
          closeTo(
            TuretilenTablolar.normalizatorFor(
              k,
              rankSayisi: rankSayisi,
              kademeSayisi: kademeSayisi,
              artis: rankArtisi,
            ),
            1e-9,
          ),
          reason: 'kademe $k',
        );
      }
    });
  });

  group('gelir bandı', () {
    test('ilk bant taban geliri, son bant 42M', () {
      double gelir(int r) => TuretilenTablolar.gelirFor(
        r,
        taban: tabanGelir,
        artis: rankArtisi,
        us: gelirUssu,
      );
      expect(gelir(0), closeTo(144000, 1));
      expect(gelir(1), closeTo(194124, 200));
      expect(gelir(19), closeTo(41972022, 50000));
    });

    test('α = 0 geliri DÜZLEŞTİRİYOR — bugünkü hâl', () {
      // Sabit gelir, yirmi kademeli bir merdiveni sekizinci nesilde durduruyor.
      // Testin işi α'nın ne yaptığını görünür kılmak.
      for (final r in [0, 10, 19]) {
        expect(
          TuretilenTablolar.gelirFor(
            r,
            taban: tabanGelir,
            artis: rankArtisi,
            us: 0,
          ),
          closeTo(tabanGelir, 1e-6),
        );
      }
    });

    test('eşik gelirle AYNI üsle ölçekleniyor', () {
      // Yorgunluk eşiği sabit kalırsa dördüncü bölgeden itibaren her oyuncu
      // ilk dakikada tabana çakılıyor. Oran her bantta sabit olmalı.
      const tabanEsik = 200000.0;
      for (final r in [0, 7, 13, 19]) {
        final gelir = TuretilenTablolar.gelirFor(
          r,
          taban: tabanGelir,
          artis: rankArtisi,
          us: gelirUssu,
        );
        final esik = TuretilenTablolar.esikFor(
          r,
          tabanEsik: tabanEsik,
          artis: rankArtisi,
          us: gelirUssu,
        );
        expect(
          esik / gelir,
          closeTo(tabanEsik / tabanGelir, 1e-9),
          reason: 'bant $r · eşik/gelir oranı kaymış',
        );
      }
    });
  });

  group('TTK kısıtı', () {
    test('kayıp çarpanı ÇARPIMSAL — %50 + %50 sıfır etmiyor', () {
      expect(TuretilenTablolar.kayipCarpaniFor(0.5, 0.5), closeTo(0.25, 1e-12));
      expect(TuretilenTablolar.kayipCarpaniFor(0, 0), 1.0);
      // Referans build: %30 azaltma, %15 sıyırma.
      expect(
        TuretilenTablolar.kayipCarpaniFor(0.30, 0.15),
        closeTo(0.595, 1e-9),
      );
    });

    test('alan 08in çözdüğü havuzu yeniden üretiyor', () {
      // 08 tek kademe için çözmüştü: A = 1.791, T = 30, kayıp = 0,595,
      // eşyalardan gelen 11.154 → gövde taban havuzu 20.823.
      final havuz = TuretilenTablolar.govdeHavuzuFor(
        saldiri: 1791,
        hedefTTK: 30,
        kayipCarpani: TuretilenTablolar.kayipCarpaniFor(0.30, 0.15),
        esyaHavuzu: 11154,
      );
      // Tolerans oransal (%0,1): belge A'yı 1.791 diye yayımlıyor ama
      // hesabında 1.791,4 kullanmış (53.743 = 1.791,4 × 30). Fark yuvarlamada,
      // formülde değil — sıkı bir mutlak tolerans yayımlanmış BASAMAK
      // sayısını test etmiş olurdu, formülü değil.
      expect(havuz, closeTo(20823, 20823 * 0.001));
    });

    test('kısıt tutmuyorsa EKSİ dönüyor — kelepçelemiyor', () {
      // Eşyalar tek başına hedef TTK'yı aşıyorsa gövdenin katacağı bir şey
      // yok. Sıfıra kelepçelemek kısıdın kırıldığını gizlerdi.
      final havuz = TuretilenTablolar.govdeHavuzuFor(
        saldiri: 100,
        hedefTTK: 30,
        kayipCarpani: 0.595,
        esyaHavuzu: 999999,
      );
      expect(havuz, lessThan(0));
    });
  });
}
