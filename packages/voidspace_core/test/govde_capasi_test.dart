@Tags(['turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 08.5 · GÖVDE HAVUZU TTK KISITINDAN ÇÖZÜLÜR.
///
/// Gövde çapası girdi değil, çözüm: `A × T × kayıp − kalkan − eşya havuzu`.
/// Burada denetlenen şey çözümün TEK olması (const kopya ile formül aynı),
/// referansın onu taşıması ve kısıtın tam tutması.
void main() {
  group('08.5 · gövde çapası', () {
    test('tepe tabloda ne gövde çapası ne referans lazer hasarı VAR', () {
      // İkisi de türetilen: çapa TTK kısıtından (08.5), namlu hasarı
      // bütçeden (04.5 s2). Girdi olarak dursalardı tablo iki kez söylerdi.
      final adlar = TasarimGirdileri.alanin(4).map((g) => g.ad).toList();
      expect(adlar, isNot(contains('govdeCapasi')));
      expect(adlar, isNot(contains('referansLazerHasari')));
      expect(
        adlar,
        contains('kalkanCapasi'),
        reason: 'kalkan çapası girdi kalır',
      );
    });

    test('const çözüm formülle AYNI — iki kopya ayrışamaz', () {
      final formul = TuretilenTablolar.govdeHavuzuFor(
        saldiri: Turetilenler.referansDps,
        hedefTTK: TasarimGirdileri.referansTTK,
        kayipCarpani: TuretilenTablolar.kayipCarpaniFor(
          TasarimGirdileri.zirhAzaltmaHedefi,
          TasarimGirdileri.siyirmaHedefiReferans,
        ),
        esyaHavuzu:
            TasarimGirdileri.kalkanCapasi + Turetilenler.referansEsyaHavuzu,
      );
      expect(Turetilenler.govdeCapasi, closeTo(formul, 1e-9));
      expect(
        Turetilenler.kritikBeklenenDegerSabiti,
        closeTo(Turetilenler.kritikBeklenenDeger, 1e-12),
      );
      expect(
        Turetilenler.referansDps,
        closeTo(CombatGlossary.expectedDps(ShipStats.bastion), 1e-9),
        reason: 'referans saldırı iki yerde iki farklı sayı',
      );
    });

    test(
      'fiyat referansı çıplak çözümü, gövde merdiveni dolu çözümü taşır',
      () {
        // İki çapa, iki iş (03.2, 04.5 s2): fiyat referansı `const` ve çıplak,
        // gövdenin canı tam donanımlı referansın çözümünden.
        expect(ShipStats.bastion.maxHull, Turetilenler.govdeCapasi);
        expect(
          HullClass.bastion.baseHull,
          closeTo(
            ReferansCozumu.govdeCapasi * Turetilenler.govdeKademeCarpanlari[0],
            1e-6,
          ),
        );
        expect(ShipStats.bastion.maxShield, TasarimGirdileri.kalkanCapasi);
        expect(
          Turetilenler.govdeCapasi,
          greaterThan(0),
          reason: 'kısıt tutmuyor',
        );
      },
    );

    test('kısıt TAM tutuyor: referans TTK = T, A = D', () {
      const ref = ShipStats.bastion;
      final ttk = CombatGlossary.ehp(ref) / CombatGlossary.expectedDps(ref);
      expect(ttk, closeTo(TasarimGirdileri.referansTTK, 1e-9));
      // A = D olunca BR tabanı A × K: ölçek yeniden çözüldü, merdiven yerinde.
      // BR tabanı ilk unvanın eşiği (10.3); K dolu referansın kanal gücünü
      // oraya oturtuyor (09.7, `referans_cozumu_test`).
      expect(CombatGlossary.brTabani, TasarimGirdileri.ilkUnvanEsigi);
      expect(CombatGlossary.brTabani, closeTo(3600, 1));
    });

    test('saldırı büyüyünce çapa BÜYÜR — TTK yerinde kalır', () {
      final bugun = TuretilenTablolar.govdeHavuzuFor(
        saldiri: Turetilenler.referansDps,
        hedefTTK: TasarimGirdileri.referansTTK,
        kayipCarpani: Turetilenler.referansKayipCarpani,
        esyaHavuzu: TasarimGirdileri.kalkanCapasi,
      );
      final roketatarla = TuretilenTablolar.govdeHavuzuFor(
        saldiri: Turetilenler.referansDps * 1.2,
        hedefTTK: TasarimGirdileri.referansTTK,
        kayipCarpani: Turetilenler.referansKayipCarpani,
        esyaHavuzu: TasarimGirdileri.kalkanCapasi,
      );
      expect(roketatarla, greaterThan(bugun));
      // Eşyalar havuza kattıkça gövde düşer: 08.6'nın kolu, terim dolunca.
      final esyayla = TuretilenTablolar.govdeHavuzuFor(
        saldiri: Turetilenler.referansDps,
        hedefTTK: TasarimGirdileri.referansTTK,
        kayipCarpani: Turetilenler.referansKayipCarpani,
        esyaHavuzu: TasarimGirdileri.kalkanCapasi + 1000,
      );
      expect(esyayla, closeTo(bugun - 1000, 1e-9));
    });

    test('referans lazer tepe tablodan okuyor — silah tabloyla değişir', () {
      expect(LaserStats.pl4.damage, Turetilenler.referansLazerHasari);
      expect(LaserStats.pl4.fireInterval, TasarimGirdileri.referansAtisAraligi);
    });
  });
}
