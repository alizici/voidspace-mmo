@Tags(['turetme', 'aralik', 'kapsam'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 10 · İLERLEME VE UNVAN — merdivenin basamakları ve temposu.
///
/// Üç karar: rank merdiveni yirmi basamak ve son ikisi TEKİL renk · unvan
/// eşikleri yüz yirmi basamak, eşit ORANLI · gelir üssü α, ilerlemenin
/// temposunu belirleyen tek sayı.
///
/// Unvan adları ve çağlar `unvan_test`te, yorgunluk `fatigue_test`te.
void main() {
  group('10.2 · rank merdiveni ve renk kapakları', () {
    test('yirmi basamak: altı aile × üç kademe + iki TEKİL renk', () {
      // KARAR 10.2 s1
      // Kırılırsa: iki yerde iki farklı merdiven uzunluğu var.
      expect(TasarimGirdileri.rankSayisi, 20);
      expect(ItemTier.values, hasLength(TasarimGirdileri.rankSayisi));
      expect(
        ItemTier.aileSayisi * ItemTier.aileBasamagi + ItemTier.tekilRank,
        TasarimGirdileri.rankSayisi,
      );
      expect(ItemTier.aileSayisi * ItemTier.aileBasamagi, 18);
      expect(ItemTier.tekilRank, 2);
      // Uçlar: C-I'den SSS-III'e, üstünde iki renk.
      expect(ItemTier.values.first.label, 'C-I');
      expect(ItemTier.values[17].label, 'SSS-III');
      expect(ItemTier.kirmizi.label, 'KIRMIZI');
      expect(ItemTier.parlayanPembe.label, 'PARLAYAN PEMBE');
    });

    test(
      'renkler AİLE DEĞİL — üçer kademeli olsalardı altı rank daha olurdu',
      () {
        // KARAR 10.2 s1
        // Tekil oldukları için oyunun en nadir iki şeyi. Aile sayılsalardı
        // merdiven yirmi dörde çıkardı ve özel olmaktan çıkarlardı.
        for (final t in ItemTier.values) {
          final tekil = t == ItemTier.kirmizi || t == ItemTier.parlayanPembe;
          expect(t.kapakTasi, tekil, reason: '${t.label} kapak taşı mı');
        }
        // Aile sayısı ALTI kalıyor: iki renk yeni aile açmıyor, en üst ailenin
        // devamı sayılıyor.
        expect(
          ItemTier.values.map((t) => t.aile).toSet(),
          hasLength(ItemTier.aileSayisi),
        );
        expect(ItemTier.kirmizi.aile, ItemTier.aileSayisi - 1);
        expect(ItemTier.parlayanPembe.aile, ItemTier.aileSayisi - 1);
        // Aile yapılsalardı: 8 aile × 3 = 24 basamak.
        expect((ItemTier.aileSayisi + 2) * ItemTier.aileBasamagi, 24);
      },
    );

    test(
      'renkler de AYNI ×1,442 oranını izliyor — bütçe matematiği değişmiyor',
      () {
        // KARAR 10.2 s1
        // Değişen tek şey onlara ulaşmanın bir aile bitirmek değil tek bir
        // eşiği geçmek olması; güç eğrisinde bir sıçrama YOK.
        for (var i = 1; i < ItemTier.values.length; i++) {
          expect(
            ItemTier.values[i].multiplier / ItemTier.values[i - 1].multiplier,
            closeTo(TasarimGirdileri.rankArtisi, 1e-9),
            reason: '${ItemTier.values[i].label} oranı kaymış',
          );
        }
        expect(ItemTier.values.first.multiplier, closeTo(1.0, 1e-12));
        expect(
          ItemTier.parlayanPembe.multiplier,
          closeTo(math.pow(TasarimGirdileri.rankArtisi, 19).toDouble(), 1e-6),
        );
      },
    );
  });

  group('10.3 · unvan eşikleri: yüz yirmi basamak', () {
    test('ilk basamak ilan edilen eşik, son basamak sistemin TAVANI', () {
      // KARAR 10.3 s1
      expect(TasarimGirdileri.unvanSayisi, 120);
      expect(CombatGlossary.unvanEsigi(0), TasarimGirdileri.ilkUnvanEsigi);
      expect(CombatGlossary.unvanEsigi(0), 3600);
      expect(
        CombatGlossary.unvanEsigi(TasarimGirdileri.unvanSayisi - 1),
        closeTo(CombatGlossary.brTavani, CombatGlossary.brTavani * 1e-9),
      );
      // Merdivenin dışı YOK: aralık dışı indeks bir sayı uydurmuyor.
      expect(() => CombatGlossary.unvanEsigi(-1), throwsArgumentError);
      expect(
        () => CombatGlossary.unvanEsigi(TasarimGirdileri.unvanSayisi),
        throwsArgumentError,
      );
    });

    test('basamaklar EŞİT ORANLI — eşit aralıklı DEĞİL', () {
      // KARAR 10.3 s1
      // Her unvan bir öncekinin sabit katı. Doğrusal bölmek üst uçta yüzlerce
      // basamağı bir araya sıkıştırırdı, çünkü BR üstel büyüyor.
      final adim = CombatGlossary.unvanAdimi;
      for (var i = 1; i < TasarimGirdileri.unvanSayisi; i++) {
        expect(
          CombatGlossary.unvanEsigi(i) / CombatGlossary.unvanEsigi(i - 1),
          closeTo(adim, 1e-9),
          reason: '$i. basamağın oranı kaymış',
        );
      }
      // Aralıklar ise SABİT DEĞİL: üstte yüzlerce kat açılıyor.
      final ilkFark =
          CombatGlossary.unvanEsigi(1) - CombatGlossary.unvanEsigi(0);
      final sonFark =
          CombatGlossary.unvanEsigi(TasarimGirdileri.unvanSayisi - 1) -
          CombatGlossary.unvanEsigi(TasarimGirdileri.unvanSayisi - 2);
      expect(sonFark / ilkFark, greaterThan(100));
      // Adım tavan ile tabandan çözülüyor, elle yazılmıyor.
      expect(
        math.pow(adim, TasarimGirdileri.unvanSayisi - 1) *
            CombatGlossary.brTabani,
        closeTo(CombatGlossary.brTavani, CombatGlossary.brTavani * 1e-9),
      );
    });

    test('eşikler KESİN ARTAN — düz ya da geri basamak yok', () {
      // KARAR 10.3 s1
      for (var i = 1; i < TasarimGirdileri.unvanSayisi; i++) {
        expect(
          CombatGlossary.unvanEsigi(i),
          greaterThan(CombatGlossary.unvanEsigi(i - 1)),
        );
      }
      expect(CombatGlossary.unvanAdimi, greaterThan(1.0));
    });
  });

  group('10.5 · gelir ölçekleme üssü α', () {
    test('gelir = taban × rank çarpanı^α — maliyet ise birinci kuvvetle', () {
      // KARAR 10.5 s2
      expect(TasarimGirdileri.gelirUssu, 0.816);
      expect(TasarimGirdileri.gelirUssu, lessThan(1.0));
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        final carpan = TuretilenTablolar.rankCarpaniFor(
          r,
          TasarimGirdileri.rankArtisi,
        );
        expect(
          TuretilenTablolar.gelirFor(
            r,
            taban: 1000,
            artis: TasarimGirdileri.rankArtisi,
            us: TasarimGirdileri.gelirUssu,
          ),
          closeTo(1000 * math.pow(carpan, TasarimGirdileri.gelirUssu), 1e-6),
        );
      }
      // Gelir maliyetten YAVAŞ büyüyor: son bantta aradaki fark açık.
      final son = Turetilenler.rankSayisi - 1;
      final maliyet = TuretilenTablolar.rankCarpaniFor(
        son,
        TasarimGirdileri.rankArtisi,
      );
      final gelir = TuretilenTablolar.gelirFor(
        son,
        taban: 1,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
      );
      expect(gelir, lessThan(maliyet));
    });

    test('α ilerlemenin TEMPOSU: 1\'e yaklaştıkça nesiller eşitleniyor', () {
      // KARAR 10.5 s2
      // "α ilerlemenin temposunu belirleyen tek sayı" cümlesinin sınaması:
      // aynı formül üç ayrı α ile üç ayrı tempo veriyor.
      double sureFor(int rank, double us) => TuretilenTablolar.bantSuresiFor(
        rank,
        artis: TasarimGirdileri.rankArtisi,
        us: us,
        olcek: 1,
      );
      final son = Turetilenler.rankSayisi - 1;

      // α = 1: bütün nesiller EŞİT — ilerledikçe hiçbir şey değişmiyor.
      expect(sureFor(son, 1.0), closeTo(sureFor(0, 1.0), 1e-12));
      // α > 1: nesiller KISALIYOR — ilerleme hızlanıyor.
      expect(sureFor(son, 1.2), lessThan(sureFor(0, 1.2)));
      // Bugünkü α: her nesil bir öncekinden UZUN.
      for (var r = 1; r < Turetilenler.rankSayisi; r++) {
        expect(
          Turetilenler.bantSuresi(r),
          greaterThan(Turetilenler.bantSuresi(r - 1)),
          reason: '$r. nesil bir öncekinden kısa',
        );
      }
      // 0'a yaklaştıkça son nesiller imkânsızlaşıyor: α = 0,3'te son nesil
      // ilkinin yüz katından uzun.
      expect(sureFor(son, 0.3) / sureFor(0, 0.3), greaterThan(100));
    });

    test('SABİT gelir iki yıllık krediyi yalnız SEKİZ nesle yetiriyor', () {
      // KARAR 10.5 s2
      // Belgenin "en önemli bulgu" dediği ölçüm. Maliyet rank çarpanının
      // birinci kuvvetiyle büyüyor; gelir sabit kalırsa 780 saat sekiz nesilde
      // bitiyor ve merdivenin kalan on ikisi ulaşılamaz oluyor.
      final ilkNesil = KaynakAkisi.neselButcesi(0);
      final sabitGelir = TasarimGirdileri.tabanSaatlikGelir;
      var saat = 0.0;
      var nesil = 0;
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        saat +=
            ilkNesil *
            TuretilenTablolar.rankCarpaniFor(r, TasarimGirdileri.rankArtisi) /
            sabitGelir;
        if (saat <= TasarimGirdileri.hedefSure) nesil++;
      }
      expect(nesil, 8, reason: 'sabit gelirle finanse edilen nesil sayısı');

      // Gelir de büyüyünce YİRMİSİ birden hedef sürenin içinde.
      var toplam = 0.0;
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        toplam += Turetilenler.bantSuresi(r);
      }
      expect(
        toplam,
        closeTo(TasarimGirdileri.hedefSure, TasarimGirdileri.hedefSure * 1e-9),
      );
    });

    test('her harita kademesinin ödülü α ile ölçekleniyor', () {
      // KARAR 10.5 s2
      // Uygulaması alan 13'ün ama üssü 10 ilan ediyor: bölgenin bant geliri
      // ile nesil bütçesi AYNI üssü okuyor, ikinci bir eğri yok.
      for (final b in Bolge.hepsi) {
        for (var i = 0; i < b.bantSayisi; i++) {
          final carpan = TuretilenTablolar.rankCarpaniFor(
            b.rankOf(i),
            TasarimGirdileri.rankArtisi,
          );
          expect(
            b.gelirCarpaniFor(i),
            closeTo(
              math.pow(carpan, TasarimGirdileri.gelirUssu).toDouble(),
              1e-9,
            ),
            reason: '${b.ad} bant $i geliri α\'yı okumuyor',
          );
        }
      }
      expect(
        KaynakAkisi.saatlikGelirFor(0),
        closeTo(TasarimGirdileri.tabanSaatlikGelir, 1e-9),
      );
    });
  });
}
