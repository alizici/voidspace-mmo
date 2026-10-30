@Tags(['kapsam', 'kod-belge'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 10.7 · SİSTEM AÇILIŞ SIRASI — ranka bağlı, süreye değil.
void main() {
  Hangar hangarla(List<ItemTier> ranklar) {
    final h = Hangar(accountId: 'a', credits: 1 << 40);
    var i = 0;
    for (final t in ranklar) {
      final spec = Catalogue.items.firstWhere(
        (s) => s.tier == t && s.slot == SlotType.laser,
      );
      h.addItem(ItemInstance(instanceId: 'i${i++}', specId: spec.id));
    }
    return h;
  }

  var sayac = 0;
  TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);

  test('boş hangar: hiçbir sistem açık değil', () {
    expect(Acilis.aciklar(Hangar(accountId: 'x')), isEmpty);
    expect(Acilis.rankOf(Hangar(accountId: 'x')), 0);
  });

  test('sıra ranka bağlı: artı ikinci rankta, çevirme üçüncüde', () {
    expect(Acilis.aciklar(hangarla([ItemTier.cI])), isEmpty);
    expect(Acilis.aciklar(hangarla([ItemTier.cII])), {Sistem.artiBasma});
    expect(Acilis.aciklar(hangarla([ItemTier.cIII])), {
      Sistem.artiBasma,
      Sistem.cevirme,
    });
    expect(Acilis.aciklar(hangarla([ItemTier.bI])), {
      Sistem.artiBasma,
      Sistem.cevirme,
      Sistem.droid,
    });
    final orta = ItemTier.values[Acilis.argeRanki];
    expect(Acilis.aciklar(hangarla([orta])), contains(Sistem.arge));
    expect(Acilis.argeRanki, Turetilenler.rankSayisi ~/ 2);
  });

  test('sentez fazla eşya birikince — aynı ranktan üç', () {
    expect(
      Acilis.acik(Sistem.sentez, hangarla([ItemTier.cI, ItemTier.cI])),
      isFalse,
    );
    expect(
      Acilis.acik(
        Sistem.sentez,
        hangarla(List.filled(Yukseltme.sentezOrani, ItemTier.cI)),
      ),
      isTrue,
    );
  });

  test('en yüksek eşya sayılıyor — süre değil, seviye değil', () {
    final h = hangarla([ItemTier.cI, ItemTier.cIII, ItemTier.cI]);
    expect(Acilis.rankOf(h), ItemTier.cIII.index);
    h.xpEkle(1 << 40);
    expect(Acilis.rankOf(h), ItemTier.cIII.index, reason: 'XP açmıyor');
  });

  test('kapalı sistem hangarda "henüz açık değil" diyor', () {
    final h = hangarla([ItemTier.cI]);
    h.malzemeEkle(Malzeme.forRank(ItemTier.cI), 1 << 20);
    h.malzemeEkle(Malzeme.cevirmeFor(ItemTier.cI), 1 << 20);
    expect(HangarRules.upgrade(h, 'i0', tx()), HangarError.kilitli);
    expect(
      HangarRules.cevir(h, 'i0', math.Random(1), tx()),
      HangarError.kilitli,
    );
    expect(HangarError.kilitli.message, isNotEmpty);

    final acik = hangarla([ItemTier.cI, ItemTier.cIII]);
    acik.malzemeEkle(Malzeme.forRank(ItemTier.cI), 1 << 20);
    expect(HangarRules.upgrade(acik, 'i0', tx()), isNull);
  });
}
