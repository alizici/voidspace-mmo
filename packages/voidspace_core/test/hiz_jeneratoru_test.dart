@Tags(['yabanci-anahtar'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 04.4 · HIZ JENERATÖRÜ KAÇINMA DA VERİR.
///
/// Tematik: hızlı gemiyi vurmak zordur. Yapısal: kaçınmanın oyunda bir
/// kaynağı olmalı, yoksa sıyırma (01.5) kâğıt üstünde kalır. Uzun süre
/// kaçınma hiçbir eşyada yoktu.
void main() {
  // KARAR 04.4 s1
  test('hız tipi her jeneratörün havuzunda kaçınma var', () {
    final hizJeneratorleri = Catalogue.items.where(
      (s) => s.slot == SlotType.generator && s.mainStat == 'hiz',
    );
    expect(hizJeneratorleri, isNotEmpty);
    for (final s in hizJeneratorleri) {
      expect(
        s.subStatPool,
        contains('kacinma'),
        reason: '${s.id}: hızlı gemiyi vurmak zor olmalı',
      );
    }
  });

  // KARAR 04.4 s1
  test('kaçınmanın kaynağı eşya — referans değeri yalnız ölçüm noktası', () {
    expect(
      Catalogue.items.any((s) => s.subStatPool.contains('kacinma')),
      isTrue,
      reason: 'kaçınma hiçbir eşyada yok; sıyırma kararı kâğıtta',
    );
    expect(ShipStats.bastion.evasion, TasarimGirdileri.referansKacinma);
  });
}
