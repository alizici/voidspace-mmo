@Tags(['turetme', 'aralik'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 07.6 · ARTI BASMADA GÜÇLENEN ALT STAT RASTGELE, MİKTAR SABİT.
///
/// Tek rastgele kuralının öteki yönü: +3 · +6 · +9 · +12 · +15'te bir alt
/// stat güçlenir; hangisi kimlikten, ne kadar sabit. Toplam, adımı bütün
/// statlara yayan eski kuralla aynı. Eskiden her adım bütün alt statlara
/// eşit biniyordu ve rastgele seçilen bir stat yoktu.
void main() {
  final hull = HullClass.bastion;
  // Çok statlı bir tasarım: tek statta iki kural özdeş, ayrım görünmez.
  final spec = Catalogue.items.firstWhere(
    (s) => ItemBudget.altStatSayisi(s.tier) >= 3 && s.subStatPool.length >= 3,
  );
  final adet = math.min(
    ItemBudget.altStatSayisi(spec.tier),
    spec.subStatPool.length,
  );
  final havuz = spec.subStatPool.take(adet).toList();

  /// Seviye çarpanından arındırılmış taban: geriye yalnız güçlenme kalır.
  double cig(int level, String statId, String id) =>
      ItemBudget.altStatTabani(spec, level, hull, statId, id)! /
      ItemLevels.multiplier(level);

  group('07.6 · güçlenme adımı', () {
    // KARAR 07.6 s1
    test('adımlar 3 · 6 · 9 · 12 · 15 — beş tane', () {
      expect(ItemLevels.adimSayisi, 5);
      expect(
        [
          for (var l = 1; l <= ItemLevels.max; l++)
            if (ItemLevels.isSubStatStep(l)) l,
        ],
        [3, 6, 9, 12, 15],
      );
      expect(ItemLevels.adimSayisiFor(2), 0);
      expect(ItemLevels.adimSayisiFor(3), 1);
      expect(ItemLevels.adimSayisiFor(ItemLevels.max), 5);
    });

    test(
      'hedef KİMLİKTEN: aynı kimlik aynı stat, kimlikler arasında dağılıyor',
      () {
        for (var adim = 1; adim <= ItemLevels.adimSayisi; adim++) {
          final a = ItemBudget.guclenenIndeks('e', adim, adet);
          expect(a, ItemBudget.guclenenIndeks('e', adim, adet));
          expect(a, inInclusiveRange(0, adet - 1));
        }
        final gorulen = {
          for (var i = 0; i < 200; i++)
            ItemBudget.guclenenIndeks('k$i', 1, adet),
        };
        expect(
          gorulen,
          hasLength(adet),
          reason: 'ilk adım bazı statlara hiç düşmüyor',
        );
      },
    );

    // KARAR 07.6 s1
    test('her adımda TEK stat büyüyor, ötekiler yerinde', () {
      const id = 'tek';
      for (var adim = 1; adim <= ItemLevels.adimSayisi; adim++) {
        final once = adim * ItemLevels.adimAraligi - 1;
        final sonra = adim * ItemLevels.adimAraligi;
        final hedef = ItemBudget.guclenenIndeks(id, adim, adet);
        for (var i = 0; i < adet; i++) {
          final oran = cig(sonra, havuz[i], id) / cig(once, havuz[i], id);
          if (i == hedef) {
            expect(
              oran,
              greaterThan(1),
              reason: '$adim. adımın hedefi büyümedi',
            );
          } else {
            expect(
              oran,
              closeTo(1, 1e-9),
              reason: '$adim. adım ${havuz[i]} statına da sıçradı',
            );
          }
        }
      }
    });

    // KARAR 07.6 s1
    test('miktar SABİT: her adım alt stat payının beşte biri, tek stata', () {
      const id = 'sabit';
      for (var adim = 1; adim <= ItemLevels.adimSayisi; adim++) {
        final hedef = havuz[ItemBudget.guclenenIndeks(id, adim, adet)];
        final once = cig(adim * ItemLevels.adimAraligi - 1, hedef, id);
        final sonra = cig(adim * ItemLevels.adimAraligi, hedef, id);
        final taban = cig(0, hedef, id);
        // Statın kendi tabanının `adet ÷ 5` katı — payın beşte biri.
        expect(
          sonra - once,
          closeTo(taban * ItemBudget.guclenmeOrani(spec.tier), 1e-9),
        );
      }
      expect(ItemBudget.guclenmeOrani(ItemTier.cI), closeTo(0.2, 1e-12));
      expect(
        ItemBudget.guclenmeOrani(ItemTier.parlayanPembe),
        closeTo(7 / 5, 1e-12),
      );
    });

    // KARAR 07.6 s1
    test('TOPLAM eski kuralla aynı — beş adım tam bir pay', () {
      // Bütçe biriminde toplam: +15'te alt statların toplamı +0'ın iki katı,
      // hangi statlara düştüğünden bağımsız.
      double toplam(int level, String id) {
        var t = 0.0;
        for (final s in havuz) {
          t += cig(level, s, id) / ItemBudget.birimFiyati(s);
        }
        return t;
      }

      for (final id in ['a', 'b', 'c', 'd']) {
        expect(
          toplam(ItemLevels.max, id),
          closeTo(2 * toplam(0, id), 1e-9),
          reason: 'kimlik $id: toplam kaymış',
        );
      }
    });

    // KARAR 07.6 s1
    test('rozet: stat başına isabet sayısı toplamı adım sayısı', () {
      const id = 'rozet';
      var toplam = 0;
      for (final s in havuz) {
        toplam += ItemBudget.guclenmeSayisiFor(spec, ItemLevels.max, s, id);
      }
      expect(toplam, ItemLevels.adimSayisi);
      expect(ItemBudget.guclenmeSayisiFor(spec, 2, havuz.first, id), 0);
      expect(ItemBudget.guclenmeSayisiFor(spec, 15, 'yok_boyle_stat', id), 0);
    });

    // KARAR 07.6 s1 · KARAR 07.5 s2
    test('çevirme ROL saklar; artı basma değeri tabandan türetir', () {
      // Rol saklanıyor (07.5): artı basma rolü değiştirmez, değer yeni
      // seviyenin tabanından türer; hedef stat güçlenme adımıyla sıçrar,
      // ötekiler yalnız seviye çarpanı kadar büyür.
      var sayac = 0;
      TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);
      final h = Hangar(accountId: 'a', credits: 1 << 40);
      h.addItem(ItemInstance(instanceId: 'g', specId: spec.id));
      h.malzemeEkle(Malzeme.forRank(spec.tier), 1 << 30);
      h.malzemeEkle(Malzeme.cevirmeFor(spec.tier), 1 << 30);
      HangarError? yukselt() => HangarRules.upgrade(h, 'g', tx());

      expect(yukselt(), isNull);
      expect(yukselt(), isNull);
      expect(HangarRules.cevir(h, 'g', math.Random(7), tx()), isNull);
      final roller = Map<String, double>.from(h.itemOf('g')!.altStatRolleri);
      expect(roller, isNotEmpty, reason: 'çevirme rol saklamadı');
      final onceki = LoadoutResolver.altStatlariFor(h.itemOf('g')!, spec, hull);

      expect(yukselt(), isNull); // +3 — ilk adım.
      final item = h.itemOf('g')!;
      expect(item.level, 3);
      expect(item.altStatRolleri, roller, reason: 'artı basma rolü değiştirdi');
      final hedef = havuz[ItemBudget.guclenenIndeks('g', 1, adet)];
      final carpanOrani = ItemLevels.multiplier(3) / ItemLevels.multiplier(2);
      final simdiki = LoadoutResolver.altStatlariFor(item, spec, hull);
      for (final e in roller.entries) {
        expect(
          simdiki[e.key]!,
          closeTo(
            ItemBudget.altStatTabani(spec, 3, hull, e.key, 'g')! * e.value,
            1e-9,
          ),
          reason: '${e.key} rol × taban değil',
        );
        final oran = simdiki[e.key]! / onceki[e.key]!;
        if (e.key == hedef) {
          expect(
            oran,
            greaterThan(carpanOrani + 1e-9),
            reason: 'hedef sıçramadı',
          );
        } else {
          expect(
            oran,
            closeTo(carpanOrani, 1e-9),
            reason: '${e.key} hedef değilken sıçradı',
          );
        }
      }
    });
  });
}
