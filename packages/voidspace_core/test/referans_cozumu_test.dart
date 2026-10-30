@Tags(['turetme', 'kod-belge'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// REFERANS ÇÖZÜMÜ — tam donanımlı referans ve ondan çözülen çapalar.
///
/// 04.5 "bütün yuvalar dolu" diyordu, kod çıplak gövdeyle ölçüyordu (borç
/// defteri B1). Burada ölçülen: referans gerçekten dolu, TTK kısıtı tam otuz,
/// eşya havuzu sıfır değil, silah katalogdaki C-I lazer, artı beklenen
/// seviye, gövde merdiveni çözümü okuyor ve fiyat referansı çıplak kaldı.
void main() {
  // KARAR 08.5 s2
  test('TTK kısıtı: referansın toplam havuzu saldırı × T × kayıp', () {
    final s = ReferansCozumu.stats;
    // Saldırı lazer artı roket (18.2): roketatar referansta dolu.
    final saldiri = CombatGlossary.saldiriDps(s);
    expect(
      s.maxHull + s.maxShield,
      closeTo(
        saldiri *
            TasarimGirdileri.referansTTK *
            Turetilenler.referansKayipCarpani,
        1e-6,
      ),
    );
    expect(s.maxHull, greaterThan(0), reason: 'çözüm eksiye düştü');
  });

  // KARAR 08.6 s1
  test('eşya havuzu SIFIR DEĞİL: jeneratörler referansa kalkan katıyor', () {
    expect(ReferansCozumu.referansEsyaHavuzu, greaterThan(0));
    expect(
      ReferansCozumu.stats.maxShield,
      closeTo(
        HullClass.bastion.baseShield + ReferansCozumu.referansEsyaHavuzu,
        1e-6,
      ),
    );
    // Jeneratör payı: yarı yarıya (04.5) — reçetede kalkan tasarımlarının
    // toplam yuva payı jeneratör yuvasının yarısı.
    final recete = ReferansCozumu.recete(HullClass.bastion);
    final kalkanYuvasi = recete.entries
        .where((e) => e.key.mainStat == Stats.maxShield.id)
        .fold(0.0, (a, e) => a + e.value);
    expect(
      kalkanYuvasi,
      closeTo(
        HullClass.bastion.generatorSlots *
            TasarimGirdileri.referansJeneratorKalkan,
        1e-9,
      ),
    );
  });

  // KARAR 04.5 s2
  test('bütün yuvalar dolu: her gövde yuva tipi reçetede, filo değil', () {
    final recete = ReferansCozumu.recete(HullClass.bastion);
    for (final tip in SlotType.values) {
      final pay = recete.entries
          .where((e) => e.key.slot == tip)
          .fold(0.0, (a, e) => a + e.value);
      if (tip == SlotType.droid) {
        expect(pay, 0, reason: 'filo referansa girdi');
        continue;
      }
      expect(
        pay,
        closeTo(HullClass.bastion.slotCount(tip), 1e-9),
        reason: '$tip yuvaları dolu değil',
      );
    }
    // Rafın rankında: ilk bantta C-I.
    for (final spec in recete.keys) {
      expect(
        spec.tier,
        ItemTier.cI,
        reason: '${spec.id} bandın rankında değil',
      );
    }
  });

  test('referansın silahı katalogdaki C-I lazer — girdi değil', () {
    expect(
      Turetilenler.referansLazerHasari,
      closeTo(
        ItemBudget.mainStatValue(Catalogue.pl1, 0, HullClass.bastion),
        1e-9,
      ),
      reason: 'referans lazer katalogdan ayrıştı',
    );
    expect(LaserStats.pl4.damage, Turetilenler.referansLazerHasari);
    expect(
      TasarimGirdileri.alanin(4).map((g) => g.ad),
      isNot(contains('referansLazerHasari')),
      reason: 'türetilen sayı tepe tabloda girdi olarak duruyor',
    );
  });

  // KARAR 10.6 s2
  test('artı beklenen seviye: ilk bandın ulaştığı, +15 değil', () {
    expect(ReferansCozumu.arti, KaynakAkisi.ulasilanSeviye(0, ItemTier.cI));
    expect(ReferansBuild.arti, ReferansCozumu.arti);
    expect(ReferansCozumu.arti, lessThan(ItemLevels.max));
    expect(ReferansCozumu.arti, greaterThan(0));
  });

  test('gövde merdiveni çözümü okuyor; fiyat referansı çıplak', () {
    final carpanlar = Turetilenler.govdeKademeCarpanlari;
    for (var k = 0; k < HullClass.all.length; k++) {
      expect(
        HullClass.all[k].baseHull,
        closeTo(ReferansCozumu.govdeCapasi * carpanlar[k], 1e-6),
        reason: '${HullClass.all[k].name} çapayı okumuyor',
      );
    }
    // Fiyat referansı (03.2) çıplak ve `const`: eşyasız, kendi çözümüyle.
    expect(ShipStats.bastion.maxHull, Turetilenler.govdeCapasi);
    expect(ShipStats.bastion.damageBonus, 0);
    expect(ShipStats.bastion.speedBonus, 0);
  });

  // KARAR 09.7 s1
  test('K çözümü: referansın kanal gücü ilk unvanın eşiğinde', () {
    // Savaş katmanı referansı okuyamıyor; taban bir girdi (10.3) ve K, dolu
    // referansın sistem çarpansız puanını tam oraya oturtacak şekilde
    // çözülüyor. Referansın kendisi menzil ve hız eklentisiyle biraz üstünde.
    final s = ReferansCozumu.stats;
    final kanal = CombatGlossary.battleRating(
      s.copyWith(rangeBonus: 0, speedBonus: 0, boostRechargeBonus: 0),
    );
    expect(kanal, closeTo(TasarimGirdileri.ilkUnvanEsigi, 1));
    expect(CombatGlossary.brTabani, TasarimGirdileri.ilkUnvanEsigi);
    expect(
      CombatGlossary.battleRating(s),
      greaterThanOrEqualTo(CombatGlossary.brTabani),
      reason: 'dolu referans kendi eşiğinin altında',
    );
  });
}
