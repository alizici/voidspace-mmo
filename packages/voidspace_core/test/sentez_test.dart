@Tags(['aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// MALZEME KAPISI · PARÇALAMA · SENTEZ — alan 07'nin üç ayağı.
///
/// Belgenin iki cümlesi bu testlerin tamamını yönetiyor:
///
///  * *"Kredi yakıt, malzeme kapı. Bir S rank eşyayı yükseltmek S rank
///    malzeme istiyor."*
///  * *"Sentez her zaman başarılı (kayıp ORANDA, sonuçta değil)."*
void main() {
  var sayac = 0;
  TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);

  Hangar zenginHangar() => Hangar(accountId: 'a', credits: 100000000);

  /// [tier] rankında, [adet] tane, kimlikleri `e0..`.
  List<String> esyaVer(Hangar h, ItemTier tier, int adet) {
    final spec = Catalogue.items.firstWhere((s) => s.tier == tier);
    return [
      for (var i = 0; i < adet; i++)
        () {
          final id = 'e${sayac++}';
          h.addItem(ItemInstance(instanceId: id, specId: spec.id));
          return id;
        }(),
    ];
  }

  group('malzeme kapısı', () {
    // Eşya C-II: artı basma ikinci rankın eşyasıyla açılıyor (10.7); ilk
    // rankın eşyasıyla kapı değil kilit görünürdü.
    // KARAR 07.9 s1
    test('malzemesi olmayan yükseltemiyor — kredisi yetse bile', () {
      final h = zenginHangar();
      HangarRules.buyItem(h, 'pl3', 'x', tx());
      expect(
        HangarRules.upgrade(h, 'x', tx()),
        HangarError.notEnoughMaterials,
        reason: 'kapı açık kalmış',
      );
      expect(h.itemOf('x')!.level, 0, reason: 'seviye yine de arttı');
    });

    test('kapı kapalıyken KREDİ de yanmıyor', () {
      // Sıra önemli: kontrol harcamadan önce. Ters kurulsaydı malzemesi
      // olmayan oyuncu her denemede parasını kaybederdi.
      final h = zenginHangar();
      HangarRules.buyItem(h, 'pl3', 'x', tx());
      final once = h.credits;
      HangarRules.upgrade(h, 'x', tx());
      expect(h.credits, once);
    });

    test('malzeme varken geçiyor ve DÜŞÜLÜYOR', () {
      final h = zenginHangar();
      HangarRules.buyItem(h, 'pl3', 'x', tx());
      final m = Malzeme.forRank(Catalogue.pl3.tier);
      final gereken = Yukseltme.malzemeMaliyeti(0, Catalogue.pl3.tier);
      h.malzemeEkle(m, gereken);
      expect(HangarRules.upgrade(h, 'x', tx()), isNull);
      expect(h.itemOf('x')!.level, 1);
      expect(h.malzemeSayisi(m), 0, reason: 'malzeme düşülmedi');
    });

    // KARAR 07.9 s1
    test('YANLIŞ RANK malzeme işe yaramıyor — kapı budur', () {
      // Malzemenin ikinci para birimi olmamasını sağlayan tek şey: mübadele
      // edilemez olması. Başka rankın malzemesi bu kapıyı açmamalı.
      final h = zenginHangar();
      HangarRules.buyItem(h, 'pl3', 'x', tx());
      final baska = ItemTier.values[Catalogue.pl3.tier.index + 3];
      h.malzemeEkle(Malzeme.forRank(baska), 1000000);
      expect(HangarRules.upgrade(h, 'x', tx()), HangarError.notEnoughMaterials);
    });

    // KARAR 07.9 s1
    test('maliyet TÜRETİLEN — kredi maliyeti ÷ malzeme değeri', () {
      for (final tier in ItemTier.values) {
        for (final seviye in [0, 5, ItemLevels.max - 1]) {
          final kredi = ItemLevels.upgradeCost(seviye, tier);
          expect(
            Yukseltme.malzemeMaliyeti(seviye, tier),
            (kredi / Ganimet.malzemeDegeriFor(tier.index)).ceil(),
          );
        }
      }
    });

    // KARAR 07.9 s1
    test('hiçbir yükseltme SIFIR malzemeli değil — kapı hep var', () {
      for (final tier in ItemTier.values) {
        for (var l = 0; l < ItemLevels.max; l++) {
          expect(
            Yukseltme.malzemeMaliyeti(l, tier),
            greaterThan(0),
            reason: '${tier.label} +$l bedava geçiyor',
          );
        }
      }
    });
  });

  group('parçalama', () {
    test('eşya gidiyor, malzeme geliyor', () {
      final h = zenginHangar();
      final ids = esyaVer(h, ItemTier.cII, 1);
      final tier = Catalogue.byId[h.itemOf(ids.first)!.specId]!.tier;
      final (kazanc, hata) = HangarRules.parcala(h, ids.first);
      expect(hata, isNull);
      expect(h.itemOf(ids.first), isNull, reason: 'eşya envanterde kaldı');
      expect(kazanc, GanimetCekilisi.parcalamaKazanci(tier));
      expect(h.malzemeSayisi(Malzeme.forRank(tier)), kazanc);
    });

    test('TAKILI eşya parçalanmıyor', () {
      final h = zenginHangar();
      HangarRules.buyItem(h, 'pl1', 'x', tx());
      HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'x');
      expect(HangarRules.parcala(h, 'x').$2, HangarError.equipped);
      expect(h.itemOf('x'), isNotNull, reason: 'takılı eşya eridi');
    });

    test('olmayan eşya parçalanmıyor', () {
      expect(
        HangarRules.parcala(zenginHangar(), 'yok').$2,
        HangarError.notOwned,
      );
    });
  });

  group('sentez', () {
    // KARAR 07.7 s1
    test('N eşya gidiyor, BİR üst rank geliyor', () {
      final h = zenginHangar();
      final ids = esyaVer(h, ItemTier.cI, Yukseltme.sentezOrani);
      final (yeni, hata) = HangarRules.sentezle(h, ids, 'yeni');
      expect(hata, isNull);
      expect(yeni, isNotNull);
      for (final id in ids) {
        expect(h.itemOf(id), isNull, reason: 'girdi tüketilmedi');
      }
      expect(Catalogue.byId[yeni!.specId]!.tier, ItemTier.cII);
    });

    // KARAR 07.2 s1 · KARAR 07.7 s1
    test('HER ZAMAN başarılı — kayıp oranda, sonuçta değil', () {
      // Alan 07'nin sert kuralı. Başarısızlık koymak koruma tılsımı satmanın
      // kapısını açar ve "tavanlı orta P2W" sözünü deler.
      final h = zenginHangar();
      for (var t = 0; t < 50; t++) {
        final ids = esyaVer(h, ItemTier.cI, Yukseltme.sentezOrani);
        expect(HangarRules.sentezle(h, ids, 'y$t').$2, isNull);
      }
    });

    // KARAR 07.7 s1
    test('kayıp ORANDA — verim birden küçük', () {
      // Sentez drop'un yerine geçemez: N eşya verip 1 alıyorsun ve o 1,
      // N eşyanın toplam gücünden az.
      expect(Yukseltme.sentezVerimi, lessThan(1.0));
      final girdi = Yukseltme.sentezOrani * ItemTier.cI.multiplier;
      expect(ItemTier.cII.multiplier, lessThan(girdi));
    });

    test('EKSİK sayıda eşya kabul edilmiyor', () {
      final h = zenginHangar();
      final ids = esyaVer(h, ItemTier.cI, Yukseltme.sentezOrani - 1);
      expect(HangarRules.sentezle(h, ids, 'y').$2, HangarError.notEnoughItems);
    });

    test('AYNI eşya iki kez sayılmıyor', () {
      // Sayılsaydı sentez bedava rank atlatma yolu olurdu.
      final h = zenginHangar();
      final ids = esyaVer(h, ItemTier.cI, 1);
      final tekrar = [
        for (var i = 0; i < Yukseltme.sentezOrani; i++) ids.first,
      ];
      expect(
        HangarRules.sentezle(h, tekrar, 'y').$2,
        HangarError.notEnoughItems,
      );
      expect(h.itemOf(ids.first), isNotNull, reason: 'eşya yine de silindi');
    });

    test('KARIŞIK rank kabul edilmiyor', () {
      final h = zenginHangar();
      final ids = [
        ...esyaVer(h, ItemTier.cI, Yukseltme.sentezOrani - 1),
        ...esyaVer(h, ItemTier.cII, 1),
      ];
      expect(HangarRules.sentezle(h, ids, 'y').$2, HangarError.notEnoughItems);
    });

    test('TAKILI eşya sentezlenmiyor', () {
      final h = zenginHangar();
      HangarRules.buyItem(h, 'pl1', 'x', tx());
      HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'x');
      final ids = [
        'x',
        ...esyaVer(h, Catalogue.pl1.tier, Yukseltme.sentezOrani - 1),
      ];
      expect(HangarRules.sentezle(h, ids, 'y').$2, HangarError.equipped);
    });

    test('merdivenin TEPESİNDE sentez yok', () {
      final h = zenginHangar();
      final ids = esyaVer(h, ItemTier.values.last, Yukseltme.sentezOrani);
      expect(HangarRules.sentezle(h, ids, 'y').$2, HangarError.atTopRank);
    });

    // KARAR 07.2 s1
    test('başarısız sentez HİÇBİR eşyayı tüketmiyor', () {
      final h = zenginHangar();
      final ids = esyaVer(h, ItemTier.values.last, Yukseltme.sentezOrani);
      HangarRules.sentezle(h, ids, 'y');
      for (final id in ids) {
        expect(h.itemOf(id), isNotNull, reason: 'reddedilen sentez eşya yedi');
      }
    });
  });
}
