@Tags(['kapsam', 'aralik'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 07.1 · ÜÇ MODÜL: ARTI BASMA, SENTEZ, ÇEVİRME.
///
/// Üçü farklı sorunları çözüyor — artı basma yavaş ve garantili büyüme,
/// sentez fazla eşyayı değere çevirme, çevirme kötü şansı kurtarma — ve
/// TÜKETTİKLERİ de farklı. Bu ayrım kasıtlı: çevirmenin krediden ayrılması
/// bir tercih değil, alan 13'ün sonucu. Oranın gider kalemlerinde çevirme
/// yok; kredi almak, modelin görmediği bir musluk açmaktı.
void main() {
  var sayac = 0;
  TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);

  /// C-III bir lazerle açılmış hangar: artı basma da çevirme de açık (10.7).
  Hangar hazirHangar() {
    final h = Hangar(accountId: 'a', credits: 100000000);
    HangarRules.buyItem(h, 'pl4', 'x', tx());
    h.malzemeEkle(Malzeme.forRank(Catalogue.pl4.tier), 100000);
    h.malzemeEkle(Malzeme.cevirmeFor(Catalogue.pl4.tier), 100000);
    return h;
  }

  /// Envanterdeki bütün malzeme ve çevirici sayıları.
  ({int malzeme, int cevirici}) stok(Hangar h) => (
    malzeme: h.malzemeSayisi(Malzeme.forRank(Catalogue.pl4.tier)),
    cevirici: h.malzemeSayisi(Malzeme.cevirmeFor(Catalogue.pl4.tier)),
  );

  group('07.1 · üç modül var ve üçü de sonuç veriyor', () {
    // KARAR 07.1 s1
    test('artı basma eşyayı +0\'dan yukarı taşıyor', () {
      final h = hazirHangar();
      expect(h.itemOf('x')!.level, 0);
      expect(HangarRules.upgrade(h, 'x', tx()), isNull);
      expect(h.itemOf('x')!.level, 1);
    });

    // KARAR 07.1 s1
    test('sentez aynı ranktan üç eşyayı BİR ÜST rank tek eşyaya çeviriyor', () {
      final h = hazirHangar();
      for (var i = 0; i < Yukseltme.sentezOrani; i++) {
        h.addItem(ItemInstance(instanceId: 's$i', specId: 'pl4'));
      }
      final (yeni, hata) = HangarRules.sentezle(h, const [
        's0',
        's1',
        's2',
      ], 'yeni');
      expect(hata, isNull);
      expect(
        Catalogue.byId[yeni!.specId]!.tier.index,
        Catalogue.pl4.tier.index + 1,
      );
      for (var i = 0; i < Yukseltme.sentezOrani; i++) {
        expect(h.itemOf('s$i'), isNull, reason: 'girdi tüketilmedi');
      }
    });

    // KARAR 07.1 s1
    test('çevirme alt stat rollerini yeniliyor, eşyayı silmiyor', () {
      final h = hazirHangar();
      final once = LoadoutResolver.altStatlariFor(
        h.itemOf('x')!,
        Catalogue.pl4,
        HullClass.bastion,
      );
      expect(
        HangarRules.cevir(h, 'x', math.Random(7), tx()),
        isNull,
        reason: 'çevirme çalışmıyor',
      );
      expect(h.itemOf('x'), isNotNull, reason: 'eşya yok oldu');
      final sonra = LoadoutResolver.altStatlariFor(
        h.itemOf('x')!,
        Catalogue.pl4,
        HullClass.bastion,
      );
      expect(sonra.keys, once.keys, reason: 'havuz değişti');
      expect(sonra.values.toList(), isNot(once.values.toList()));
    });
  });

  group('07.1 · tükettikleri AYRI', () {
    // KARAR 07.1 s1
    test('artı basma: KREDİ ve o rankın MALZEMESİ; çevirici yerinde', () {
      final h = hazirHangar();
      final krediOnce = h.credits;
      final stokOnce = stok(h);
      expect(HangarRules.upgrade(h, 'x', tx()), isNull);
      expect(h.credits, lessThan(krediOnce), reason: 'kredi harcanmadı');
      expect(
        stok(h).malzeme,
        lessThan(stokOnce.malzeme),
        reason: 'rank kapısı bedava geçildi',
      );
      expect(
        stok(h).cevirici,
        stokOnce.cevirici,
        reason: 'artı basma çeviriciyi yedi — iki eksen tek eksene indi',
      );
    });

    // KARAR 07.1 s1
    test('sentez: EŞYANIN KENDİSİ; kredi ve malzeme yerinde', () {
      // "Üç parça gider, biri gelir." Kaynak eşya; kredi ve malzeme değil.
      final h = hazirHangar();
      for (var i = 0; i < Yukseltme.sentezOrani; i++) {
        h.addItem(ItemInstance(instanceId: 's$i', specId: 'pl4'));
      }
      final krediOnce = h.credits;
      final stokOnce = stok(h);
      final (yeni, hata) = HangarRules.sentezle(h, const [
        's0',
        's1',
        's2',
      ], 'yeni');
      expect(hata, isNull);
      expect(yeni, isNotNull);
      expect(h.credits, krediOnce, reason: 'sentez kredi aldı');
      expect(stok(h).malzeme, stokOnce.malzeme, reason: 'sentez malzeme aldı');
      expect(stok(h).cevirici, stokOnce.cevirici);
    });

    // KARAR 07.1 s1
    test('çevirme: YALNIZ çevirici; kredi ve yükseltme malzemesi yerinde', () {
      final h = hazirHangar();
      final krediOnce = h.credits;
      final stokOnce = stok(h);
      expect(HangarRules.cevir(h, 'x', math.Random(3), tx()), isNull);
      expect(
        h.credits,
        krediOnce,
        reason: 'çevirme kredi aldı — 13\'ün görmediği musluk açıldı',
      );
      expect(
        stok(h).malzeme,
        stokOnce.malzeme,
        reason: 'çevirme yükseltme malzemesi yedi',
      );
      expect(
        stokOnce.cevirici - stok(h).cevirici,
        Yukseltme.cevirmeBedeli(
          Catalogue.pl4.tier,
          ItemBudget.subStatValues(
            Catalogue.pl4,
            0,
            HullClass.bastion,
            'x',
          ).length,
        ),
      );
    });

    // KARAR 07.1 s1
    test('ekonominin gider kalemlerinde ÇEVİRME yok', () {
      // Belgenin gerekçesi: oranın gider kalemleri artı basma · sentez ·
      // mağaza · birikim · onarım. Çevirme hiç bütçelenmemişti.
      expect(
        GiderKalemi.values.map((g) => g.name),
        isNot(contains('cevirme')),
      );
      expect(GiderKalemi.values, contains(GiderKalemi.artiBasma));
      expect(GiderKalemi.values, contains(GiderKalemi.sentez));
      // Defterde de çevirme sebebi yok: kredi hareketi doğmuyor.
      expect(
        LedgerReason.values.map((r) => r.name),
        isNot(contains('cevirme')),
      );
    });
  });

  group('07.1 · artı basma ana statı ve alt statları BİRLİKTE büyütüyor', () {
    // KARAR 07.1 s1
    test('bir seviye artınca ikisi de büyüyor', () {
      const spec = Catalogue.pl4;
      final hull = HullClass.bastion;
      double altToplam(int seviye) {
        var t = 0.0;
        for (final e
            in ItemBudget.subStatValues(spec, seviye, hull, 'x').entries) {
          t += e.value / ItemBudget.birimFiyati(e.key);
        }
        return t;
      }

      expect(
        ItemBudget.mainStatValue(spec, 1, hull),
        greaterThan(ItemBudget.mainStatValue(spec, 0, hull)),
      );
      expect(altToplam(1), greaterThan(altToplam(0)));
      // Tavana kadar ikisi de tek yönde.
      for (var l = 1; l <= ItemLevels.max; l++) {
        expect(
          ItemBudget.mainStatValue(spec, l, hull),
          greaterThan(ItemBudget.mainStatValue(spec, l - 1, hull)),
          reason: '+$l ana stat gerilemiş',
        );
      }
    });
  });
}
