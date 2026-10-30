@Tags(['kapsam', 'aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// NOVA RAFI — 15.7 · kıt parayla üç taban tasarım.
///
/// Rafın kendisi kadar SINIRLARI da sınanıyor: taban eşya (alt statsız), bir
/// kademe üst, üç tasarım. Üçü birden 15.1'i ayakta tutuyor; biri düşerse
/// NOVA ganimetin işini yapmaya başlar.
void main() {
  var sayac = 0;
  TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);

  Hangar hangar({int nova = 0}) =>
      Hangar(accountId: 'a', credits: 1 << 30, premium: nova);

  // KARAR 15.7 s1
  test('raf ÜÇ tasarım: bir lazer, bir jeneratör, bir droid', () {
    final raf = Catalogue.novaRafi;
    expect(raf, hasLength(3));
    expect(
      raf.map((s) => s.slot).toSet(),
      {SlotType.laser, SlotType.generator, SlotType.droid},
      reason: 'NOVA rafı bir yuvaya iki tasarım koyuyor',
    );
    for (final s in raf) {
      expect(s.currency, Currency.premium, reason: '${s.id} krediyle');
      expect(
        Catalogue.priceOf(s).currency,
        Currency.premium,
        reason: '${s.id} fiyatı kredi cinsinden',
      );
    }
    // Elit droid Hilal: oyuncunun NOVA ile aldığı droid (05.8 s2).
    expect(
      raf.singleWhere((s) => s.slot == SlotType.droid).variant,
      DroidModeli.elit.name,
    );
  });

  // KARAR 15.7 s1
  test('NOVA rafı merdivenin DİBİNDE: en üstü B-I', () {
    // "İstenir ama gerekmez": ödeyen oyuncu ilk bantlarda bir adım önde
    // başlıyor, ama merdiven yirmi basamak ve raf üçüncüde duruyor. Rafın
    // yukarı tırmanması, ilerlemenin bir basamağını paraya bağlamak olurdu.
    for (final nova in Catalogue.novaRafi) {
      expect(
        nova.tier.index,
        lessThanOrEqualTo(ItemTier.bI.index),
        reason: '${nova.id} merdivende yukarı çıkmış',
      );
      expect(
        nova.tier.index,
        greaterThan(ItemTier.cI.index),
        reason: '${nova.id} başlangıç rankında: NOVA hiçbir şey vermiyor',
      );
    }
    // Merdiven yirmi basamak; raf ilk beşte kalıyor.
    expect(
      Catalogue.novaRafi
          .map((s) => s.tier.index)
          .reduce((a, b) => a > b ? a : b),
      lessThan(ItemTier.values.length ~/ 4),
    );
  });

  // KARAR 15.7 s1
  test('alınan eşya TABAN: NOVA derinlik satmıyor', () {
    final h = hangar(nova: 1 << 20);
    final spec = Catalogue.novaRafi.first;
    final (item, hata) = HangarRules.novaRafindanAl(h, spec.id, 'x1', tx());
    expect(hata, isNull);
    expect(item!.taban, isTrue, reason: 'NOVA rafı alt statlı eşya sattı');
    expect(
      LoadoutResolver.altStatlariFor(item, spec, h.activeHull),
      isEmpty,
      reason: 'taban eşyanın alt statı çıktı',
    );
  });

  // KARAR 15.7 s1
  test('bedel NOVA kasasından iniyor, kredi kasasına dokunulmuyor', () {
    final h = hangar(nova: 1 << 20);
    final spec = Catalogue.novaRafi.first;
    final krediOnce = h.credits;
    final novaOnce = h.premium;
    expect(HangarRules.novaRafindanAl(h, spec.id, 'x1', tx()).$2, isNull);
    expect(h.premium, novaOnce - Catalogue.priceOf(spec).amount);
    expect(h.credits, krediOnce, reason: 'kredi kasasına dokunuldu');
  });

  // KARAR 15.7 s1
  test('NOVA yetmiyorsa alım yok; raf dışı tasarım reddediliyor', () {
    final h = hangar();
    final spec = Catalogue.novaRafi.first;
    final (item, hata) = HangarRules.novaRafindanAl(h, spec.id, 'x1', tx());
    expect(hata, HangarError.novaYok);
    expect(item, isNull);
    expect(h.inventory, isEmpty);

    // Kredi rafındaki tasarım NOVA rafından alınamıyor: iki raf iki yol.
    final zengin = hangar(nova: 1 << 20);
    expect(
      HangarRules.novaRafindanAl(zengin, 'dr1', 'x2', tx()).$2,
      HangarError.notPurchasable,
    );
    expect(
      HangarRules.novaRafindanAl(zengin, 'yok', 'x3', tx()).$2,
      HangarError.notFound,
    );
  });

  // KARAR 15.1 s3
  test('kilit hâlâ ganimetin eşyasını koruyor', () {
    // NOVA rafı üç taban tasarım; ganimet döngüsünün alt statlı eşyası hâlâ
    // satılamıyor ve kilit bunu söylüyor.
    expect(Kazanc.esyaSatilabilir, isFalse);
    expect(Kazanc.satilabilir(Kaynak.malzeme), isFalse);
    expect(Catalogue.novaRafi.length, lessThan(Catalogue.rafta.length));
  });
}
