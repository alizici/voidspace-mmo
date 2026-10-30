@Tags(['turetme', 'aralik'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 09 · SAVAŞ PUANI — ölçü aletinin kendisi.
///
/// Dört iddia sınanıyor: geometrik ortalama dengeyi ZORUNLU kılıyor ·
/// kanallar arası kur ayrı bir girdi değil, referans TTK'nın kendisi ·
/// "A = D" soyut bir simetri değil, referans dövüşün ilan edilen süre kadar
/// sürmesi · bir bütçe puanı hangi kanala konursa konsun aynı gücü alıyor.
///
/// Sistem kanalının değerleri ve tavanı ayrı dosyada (`sistem_kanali_test`).
void main() {
  const ref = ShipStats.bastion;
  const hedefT = TasarimGirdileri.referansTTK;

  // Savaş puanının İÇİNDEKİ iki kanalın tanımı — ikinci bir tanım yazmamak
  // için `battleRating`'in kullandığı terimlerin aynısı.
  double kanalA(ShipStats s) =>
      CombatGlossary.saldiriDps(s) + CombatGlossary.droidDps(s);
  double kanalD(ShipStats s) =>
      (CombatGlossary.ehp(s) +
          TasarimGirdileri.droidDayaniklilikKatsayisi *
              CombatGlossary.droidEhp(s)) /
      hedefT;

  /// İki kanalı İSTENEN yere oturtulmuş bir build. Saldırı zinciri taban
  /// hasarda doğrusal, EHP havuzda doğrusal; ikisi de ölçülerek doğrulanıyor.
  ShipStats kurgu({required double saldiri, required double dayaniklilik}) {
    final olcek = saldiri / kanalA(ref);
    final havuz = dayaniklilik * hedefT * (1 - ref.totalMitigation);
    return ref.copyWith(
      roketHasari: ref.roketHasari * olcek,
      laser: LaserStats(
        id: ref.laser.id,
        name: ref.laser.name,
        damage: ref.laser.damage * olcek,
        fireInterval: ref.laser.fireInterval,
        range: ref.laser.range,
      ),
      maxHull: havuz - ref.maxShield,
    );
  }

  ShipStats hasarEkle(double puan) => ref.copyWith(
    laser: LaserStats(
      id: ref.laser.id,
      name: ref.laser.name,
      damage:
          ref.laser.damage +
          puan * ItemBudget.birimFiyati('taban_hasar') / ref.equippedLasers,
      fireInterval: ref.laser.fireInterval,
      range: ref.laser.range,
    ),
  );

  group('09.1 · geometrik ortalama', () {
    test('kurgu gerçekten İSTENEN kanalları veriyor', () {
      // Aşağıdaki testlerin dayandığı zemin: kanal değerleri ölçülüyor,
      // varsayılmıyor.
      final s = kurgu(saldiri: 1234, dayaniklilik: 567);
      expect(kanalA(s), closeTo(1234, 1e-6));
      expect(kanalD(s), closeTo(567, 1e-6));
    });

    test('DENGE zorunlu: tek kanala yatırım dengeliden düşük BR alıyor', () {
      // KARAR 09.1 s1
      // Aynı toplam kanal gücü farklı bölüşümlerle dağıtılıyor. Geometrik
      // ortalama tepe noktasını tam ortaya koyuyor; kırılırsa "yalnız
      // saldırıya yatıran oyuncu" dengeli oyuncuyla aynı puanı alıyor demek.
      final toplam = kanalA(ref) + kanalD(ref);
      double brFor(double pay) => CombatGlossary.battleRating(
        kurgu(saldiri: toplam * pay, dayaniklilik: toplam * (1 - pay)),
      );

      final dengeli = brFor(0.5);
      for (final pay in [0.1, 0.25, 0.4, 0.6, 0.75, 0.9]) {
        expect(
          brFor(pay),
          lessThan(dengeli),
          reason: '$pay bölüşümü dengeliyi geçti',
        );
      }
      // Yalnız saldırı: dengelinin belirgin altında — √(0,9×0,1) ÷ 0,5 = 0,6.
      expect(brFor(0.9), closeTo(dengeli * 0.6, dengeli * 1e-6));
      // Simetrik: baskı saldırıya da savunmaya da aynı biniyor.
      expect(brFor(0.25), closeTo(brFor(0.75), dengeli * 1e-9));
    });

    test('ARİTMETİK ortalama bu baskıyı üretmezdi', () {
      // KARAR 09.1 s1
      // Aynı bölüşümlerde iki kanalın aritmetik ortası SABİT kalıyor: toplam
      // olsaydı bütün bütçesini saldırıya yatıran build ile yarı yarıya bölen
      // build aynı puanı alırdı.
      final toplam = kanalA(ref) + kanalD(ref);
      for (final pay in [0.1, 0.5, 0.9]) {
        final s = kurgu(
          saldiri: toplam * pay,
          dayaniklilik: toplam * (1 - pay),
        );
        expect(
          (kanalA(s) + kanalD(s)) / 2,
          closeTo(toplam / 2, toplam * 1e-9),
          reason: 'aritmetik orta bölüşümle değişti',
        );
      }
    });

    test(
      'BR = √(saldırı × dayanıklılık) × SİSTEM × K — üç çarpan da yerinde',
      () {
        // KARAR 09.1 s1
        final ornekler = [
          ref,
          ReferansCozumu.stats,
          kurgu(saldiri: 900, dayaniklilik: 400),
          kurgu(saldiri: 900, dayaniklilik: 400).copyWith(rangeBonus: 0.2),
        ];
        for (final s in ornekler) {
          final beklenen =
              math.sqrt(kanalA(s) * kanalD(s)) *
              CombatGlossary.sistemCarpani(CombatGlossary.sistemPuaniOf(s)) *
              TasarimGirdileri.brOlcegi;
          expect(
            CombatGlossary.battleRating(s),
            closeTo(beklenen, beklenen * 1e-12),
          );
        }
      },
    );

    test('SİSTEM çarpımsal ve KÜÇÜK — saldırının yerine geçemiyor', () {
      // KARAR 09.1 s1
      // "Sistem statları oyuncuyu güçlendirmiyor, oyunu kolaylaştırıyor":
      // tavana dayalı sistem en fazla ×1,25 verirken iki kanalı birden ikiye
      // katlamak ×2 veriyor.
      final taban = CombatGlossary.battleRating(ref);
      final sistemli = CombatGlossary.battleRating(
        ref.copyWith(speedBonus: 10),
      );
      expect(
        sistemli / taban,
        closeTo(1 + TasarimGirdileri.sistemTavani / 100, 1e-9),
      );
      final ikiKat = CombatGlossary.battleRating(
        kurgu(saldiri: 2 * kanalA(ref), dayaniklilik: 2 * kanalD(ref)),
      );
      expect(ikiKat / taban, closeTo(2.0, 1e-9));
      expect(sistemli, lessThan(ikiKat));
    });
  });

  group('09.2 · kanallar arası kur', () {
    test('kur referans TTK\'nın KENDİSİ: 1 DPS ≡ T × 1 EHP', () {
      // KARAR 09.2 s1
      // Bir saldırı puanının aldığı DPS ile bir savunma puanının aldığı EHP
      // arasındaki oran, TTK'nın türevinden çıkan sayının aynısı olmak
      // zorunda: ∂TTK/∂EHP ÷ |∂TTK/∂DPS| = EHP ÷ DPS = TTK.
      final puanDps = Turetilenler.saldiriPuaniDps;
      final puanEhp =
          Turetilenler.savunmaCapasi * Turetilenler.referansEhpCarpani;
      expect(puanEhp / puanDps, closeTo(hedefT, hedefT * 1e-12));

      // Ve türevin kendisi referansta ölçülüyor: EHP ÷ DPS = T.
      expect(
        CombatGlossary.ehp(ref) / kanalA(ref),
        closeTo(hedefT, hedefT * 1e-9),
      );
    });

    test('kur ELLE YAZILMIYOR — tepe tabloda kur girdisi yok', () {
      // KARAR 09.2 s1
      // Kırılırsa: kur iki yerde iki farklı sayı olur.
      final adlar = TasarimGirdileri.alanin(9).map((g) => g.ad).toList();
      expect(adlar, contains('referansTTK'));
      expect(adlar, isNot(contains('savunmaCapasi')));
      expect(adlar, isNot(contains('kanalKuru')));
      // Çapa formülün kendisi, ayrı bir sabit değil.
      expect(
        Turetilenler.savunmaCapasi,
        closeTo(
          Turetilenler.saldiriPuaniDps *
              hedefT /
              Turetilenler.referansEhpCarpani,
          Turetilenler.savunmaCapasi * 1e-12,
        ),
      );
    });

    test('T değişirse kur onunla birlikte KAYAR — bağımsız bir sayı değil', () {
      // KARAR 09.2 s1
      double capaFor(double t) =>
          Turetilenler.saldiriPuaniDps * t / Turetilenler.referansEhpCarpani;
      expect(capaFor(hedefT), closeTo(Turetilenler.savunmaCapasi, 1e-9));
      expect(
        capaFor(2 * hedefT),
        closeTo(2 * Turetilenler.savunmaCapasi, 1e-9),
      );
    });
  });

  group('09.3 · A = D kısıtının anlamı', () {
    test('referans build\'de A = D ve ölçülen TTK ilan edilene %2 içinde', () {
      // KARAR 09.3 s1
      // Kırılırsa: referans TTK ilan edilenden sapmış, yani kur geçersiz.
      final dolu = ReferansCozumu.stats;
      expect(kanalA(dolu) / kanalD(dolu), closeTo(1.0, 0.02));
      expect(
        CombatGlossary.ehp(dolu) / CombatGlossary.saldiriDps(dolu),
        closeTo(hedefT, hedefT * 0.02),
      );
      // Fiyat referansı da aynı kısıdı taşıyor.
      expect(kanalA(ref) / kanalD(ref), closeTo(1.0, 0.02));
    });

    test('DENKLİK her build\'de: TTK ÷ T tam olarak D ÷ A', () {
      // KARAR 09.3 s1
      // "A = D" cümlesinin anlamı bu: dövüş ilan edilen süre kadar sürsün.
      // Dayanıklılığı iki katına çıkaran build'in dövüşü iki kat uzuyor.
      for (final oran in [0.5, 1.0, 2.0, 3.0]) {
        final s = kurgu(saldiri: kanalA(ref), dayaniklilik: kanalD(ref) * oran);
        final ttk = CombatGlossary.ehp(s) / CombatGlossary.saldiriDps(s);
        expect(ttk / hedefT, closeTo(kanalD(s) / kanalA(s), 1e-9));
        expect(ttk / hedefT, closeTo(oran, 1e-9));
      }
    });
  });

  group('09.4 · savunma çapası ve ölçekleme', () {
    test('bir savunma puanı = bir saldırı puanı KADAR kanal gücü', () {
      // KARAR 09.4 s1
      const puan = 500.0;
      final saldiriya = hasarEkle(puan);
      final savunmaya = ref.copyWith(
        maxHull: ref.maxHull + puan * ItemBudget.birimFiyati('govde_cani'),
      );
      final artanA = kanalA(saldiriya) - kanalA(ref);
      final artanD = kanalD(savunmaya) - kanalD(ref);
      expect(artanA, greaterThan(0));
      expect(artanD, closeTo(artanA, artanA * 1e-9));
    });

    test('EŞİT bütçe → EŞİT BR katkısı, her iki kanalda', () {
      // KARAR 09.4 s1
      // Değişmez tablosunun satırı: bir kanal ucuza gelirse çapa yanlış
      // ölçeklenmiş demektir.
      const puan = 500.0;
      final taban = CombatGlossary.battleRating(ref);
      final brSaldiri = CombatGlossary.battleRating(hasarEkle(puan)) - taban;
      final brSavunma =
          CombatGlossary.battleRating(
            ref.copyWith(
              maxHull:
                  ref.maxHull + puan * ItemBudget.birimFiyati('govde_cani'),
            ),
          ) -
          taban;
      expect(brSaldiri, greaterThan(0));
      expect(brSavunma, closeTo(brSaldiri, brSaldiri * 1e-9));
    });

    test('bütün savunma fiyatları AYNI çapadan ölçekleniyor', () {
      // KARAR 09.4 s1
      // Havuz havuzdur: gövde canı ile kalkan aynı fiyatta; kalkan
      // yenilenmesi de çapanın kur süresine bölünmüşü.
      expect(
        ItemBudget.birimFiyati('govde_cani'),
        closeTo(Turetilenler.savunmaCapasi, Turetilenler.savunmaCapasi * 1e-9),
      );
      expect(
        ItemBudget.birimFiyati('kalkan'),
        closeTo(
          ItemBudget.birimFiyati('govde_cani'),
          ItemBudget.birimFiyati('govde_cani') * 1e-9,
        ),
      );
      expect(
        ItemBudget.birimFiyati('kalkan_yenilenmesi'),
        closeTo(
          Turetilenler.savunmaCapasi / hedefT / 100,
          Turetilenler.savunmaCapasi * 1e-9,
        ),
      );
    });

    test('ELLE konmuş eski fiyat kanal gücünün BEŞTE BİRİNİ veriyordu', () {
      // KARAR 09.4 s1
      // Çapa 4,0 iken bir savunma puanı bir saldırı puanının %19,7'si kadar
      // güç alıyordu — ölçüm bu, ve çapanın keyfî olmaktan çıkışının kanıtı.
      const puan = 500.0;
      final artanA = kanalA(hasarEkle(puan)) - kanalA(ref);
      final eskiD =
          kanalD(ref.copyWith(maxHull: ref.maxHull + puan * 4.0)) - kanalD(ref);
      expect(eskiD / artanA, closeTo(0.197, 0.002));
      expect(Turetilenler.savunmaCapasi / 4.0, closeTo(5.07, 0.05));
    });
  });
}
