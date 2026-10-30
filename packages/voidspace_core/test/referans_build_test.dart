@Tags(['kapsam', 'turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 10.6 · REFERANS BUILD FONKSİYONU.
///
/// Rank → kademe, kademe → gövde ve referans rank, artı: tek yerde. Eskiden
/// rank → kademe kaynak akışında, rank → BR savaş sözlüğünde ayrı yaşıyordu.
void main() {
  group('10.6 · referans build', () {
    test('her rank TAM BİR kademeye düşüyor, kademeler sırayla', () {
      var onceki = 0;
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        final k = ReferansBuild.kademeOf(r);
        expect(k, inInclusiveRange(0, TasarimGirdileri.govdeKademeSayisi - 1));
        expect(k, greaterThanOrEqualTo(onceki), reason: 'kademe geri gitti');
        expect(k - onceki, lessThanOrEqualTo(1), reason: 'kademe atladı');
        onceki = k;
      }
      expect(ReferansBuild.kademeOf(0), 0);
      expect(
        ReferansBuild.kademeOf(Turetilenler.rankSayisi - 1),
        TasarimGirdileri.govdeKademeSayisi - 1,
      );
      expect(() => ReferansBuild.kademeOf(-1), throwsArgumentError);
      expect(
        () => ReferansBuild.kademeOf(Turetilenler.rankSayisi),
        throwsArgumentError,
      );
    });

    test('bileşim: gövde kademenin, rank kendisi, artı BEKLENEN', () {
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        final ref = ReferansBuild.of(r);
        expect(ref.tier, ItemTier.values[r]);
        expect(ref.govde, HullClass.all[ref.kademe]);
        expect(ref.br, CombatGlossary.referansBrFor(r));
      }
      // Artı tavan değil beklenen seviye (10.6 s2): +15 nesil içinde
      // ulaşılamıyor (13.6).
      expect(ReferansBuild.arti, ReferansCozumu.arti);
      expect(ReferansBuild.arti, lessThan(ItemLevels.max));
      expect(
        () => ReferansBuild.of(Turetilenler.rankSayisi),
        throwsArgumentError,
      );
    });

    test('kademenin referansı bandın İLK rankı — bölge kapısıyla aynı', () {
      for (var k = 0; k < TasarimGirdileri.govdeKademeSayisi; k++) {
        final ref = ReferansBuild.ofKademe(k);
        expect(ref.kademe, k);
        expect(ref.rank, ReferansBuild.rankiFor(k));
        expect(
          ref.rank,
          Bolge.byKademe(k)!.ilkRank,
          reason: 'bölge ayrı bölüyor',
        );
        expect(ref.govde, ReferansBuild.govdeFor(k));
      }
      expect(() => ReferansBuild.govdeFor(-1), throwsArgumentError);
    });

    test('bölmeyi herkes buradan okuyor — yuva zinciri aynı sayı', () {
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        expect(HullYuva.sayisiFor(r), ReferansBuild.of(r).govde.totalSlots);
      }
    });

    test('merdiven kesin artan: her rankın referansı bir öncekinden güçlü', () {
      for (var r = 1; r < Turetilenler.rankSayisi; r++) {
        expect(ReferansBuild.of(r).br, greaterThan(ReferansBuild.of(r - 1).br));
      }
      expect(ReferansBuild.of(0).br, closeTo(CombatGlossary.brTabani, 1e-9));
    });
  });
}
