@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/ship_atlas.dart';

/// KARE YOLU TAHSİS ETMEZ.
///
/// Bu dosyanın ölçtüğü şey hız değil ÇÖP. Kırk gemi × 120 Hz'de her gemi
/// dokuz dörtgen yazıyor (iki gövde, iki motor, bir kalkan, beşe kadar silah);
/// dörtgen başına tek bir kısa ömürlü nesne bile saniyede ~50.000 tahsis eder
/// ve Dart'ın çöp toplayıcısı duraklattığında duraklattığı şey kare
/// döngüsüdür. Mobilde "takılıyor" diye tarif edilen şeyin en yaygın sebebi
/// bu — ağ değil.
///
/// Ölçüm KİMLİK üzerinden: aynı çağrı aynı nesneyi döndürüyorsa arada tahsis
/// yok. Bir gün biri `Rect.fromLTWH(...)`'i geri koyarsa test kırmızıya döner
/// ve bunu profil almadan öğrenmiş oluruz.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('atlas kare dikdörtgenleri ÖNCEDEN hesaplanmış', () async {
    final atlas = await ShipAtlas.load(devicePixelRatio: 2, zoom: 0.6);

    expect(identical(atlas.hullFrame(1, 2), atlas.hullFrame(1, 2)), isTrue);
    expect(identical(atlas.engineFrame(0, 3), atlas.engineFrame(0, 3)), isTrue);
    expect(identical(atlas.shieldFrame(2, 1), atlas.shieldFrame(2, 1)), isTrue);
    expect(
      identical(atlas.emitterFrame(4, 2), atlas.emitterFrame(4, 2)),
      isTrue,
    );
    expect(identical(atlas.alienFrame(2), atlas.alienFrame(2)), isTrue);

    // Çapalar da: dörtgen başına bir kez okunuyorlar.
    expect(identical(atlas.hullAnchor, atlas.hullAnchor), isTrue);
    expect(identical(atlas.emitterAnchor, atlas.emitterAnchor), isTrue);

    // Tablo GERÇEKTEN farklı kareler taşıyor — hepsi aynı nesne olsaydı
    // yukarıdaki kimlik testleri de geçerdi ve gemi tek kareye donardı.
    expect(atlas.hullFrame(0, 0), isNot(atlas.hullFrame(1, 0)));
    expect(atlas.emitterFrame(0, 0), isNot(atlas.emitterFrame(2, 0)));
    expect(atlas.emitterFrame(0, 0), isNot(atlas.emitterFrame(0, 1)));
  });

  test('donanım merdiveni tablodan okunuyor', () {
    // `ShipSwarm` gemi başına, `CombatLayer` ateş eden gemi başına çağırıyor.
    for (var n = 0; n <= Bastion.hardpoints.length; n++) {
      expect(
        identical(Bastion.activeHardpoints(n), Bastion.activeHardpoints(n)),
        isTrue,
        reason: '$n lazerde her çağrı yeni liste kuruyor',
      );
    }
  });

  test('yerleşim türevleri BİR KEZ hesaplanıyor', () {
    // `emitterColumns` en tehlikelisiydi: bir liste kurup `map`/`reduce`
    // çalıştırıyordu ve `emitterFrame` her çağrısında okunuyor.
    expect(identical(AtlasLayout.emitterCell, AtlasLayout.emitterCell), isTrue);
    expect(identical(AtlasLayout.hullCell, AtlasLayout.hullCell), isTrue);
    expect(identical(AtlasLayout.imageSize, AtlasLayout.imageSize), isTrue);
    expect(AtlasLayout.emitterColumns, greaterThan(AtlasLayout.columns));
  });

  test('silah bloğu atlasın GENİŞLİĞİNİ dolduruyor', () {
    // Sabit sekiz sütun ölçüldü ve 2.5 MB israf ediyordu: yuva hücresi küçük,
    // atlas ise gövde bloğu yüzünden geniş. Tek satıra sığan yirmi hücre üç
    // satır yer kaplıyordu.
    final rows = (AtlasLayout.emitterCount / AtlasLayout.emitterColumns).ceil();
    expect(rows, 1, reason: 'yuva bloğu birden fazla satıra taşmış');
    expect(
      AtlasLayout.emitterColumns * AtlasLayout.emitterCell.width,
      lessThanOrEqualTo(AtlasLayout.imageSize.width),
      reason: 'blok atlasın dışına taşıyor',
    );
  });
}
