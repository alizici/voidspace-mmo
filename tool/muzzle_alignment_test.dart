import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/weapon_emitter.dart';

/// Merminin ÇIKTIĞI nokta ile namlunun ÇİZİLDİĞİ nokta aynı mı.
///
/// Bu tam olarak bir kez kırıldı ve sessizce kırıldı: `CombatLayer` tasarım
/// noktalarını yalnız [AtlasLayout.designScale] ile ölçekliyordu, ama atlas
/// gövdeyi bir de `centreOffset` kadar KAYDIRARAK pişiriyor. Sonuç, bütün
/// ağızların 26 dünya birimi burna kayması — mermiler silahtan değil geminin
/// önündeki boşluktan çıkıyordu. Ekranda "bir şeyler ters" diye görünür,
/// hangi sayının yanlış olduğu görünmez.
///
/// Bu yüzden test HESAPTAN değil PİKSELDEN doğruluyor: projektör atlasın
/// birebir dönüşümüyle çiziliyor, namlu merceğinin ışık merkezi ölçülüyor ve
/// [Bastion.worldMuzzles] ile karşılaştırılıyor. Sanat da hesap da değişse
/// ikisi ayrıştığı an kırmızıya döner.
void main() {
  testWidgets('namlu ağızları çizimle AYNI yerde', (tester) async {
    final cell = AtlasLayout.hullCell;
    final anchor = AtlasLayout.hullAnchor;

    for (var i = 0; i < Bastion.hardpoints.length; i++) {
      final measured = await tester.runAsync(
        () => _lensCentre(i, cell, anchor),
      );
      final expected = Bastion.worldMuzzles[i];

      expect(
        (measured! - expected).distance,
        lessThan(2),
        reason:
            'yuva $i: mermi (${expected.dx.toStringAsFixed(1)}, '
            '${expected.dy.toStringAsFixed(1)}) noktasından çıkıyor ama '
            'mercek (${measured.dx.toStringAsFixed(1)}, '
            '${measured.dy.toStringAsFixed(1)}) noktasında çizilmiş',
      );
    }

    // Kaydırmayı atlayan ESKİ hesap gerçekten yanlış olmalı; yoksa bu test
    // hiçbir şeyi korumuyor demektir.
    final naive = Bastion.muzzles[2] * AtlasLayout.designScale;
    expect(
      (naive - Bastion.worldMuzzles[2]).distance,
      greaterThan(20),
      reason: 'centreOffset kaydırması anlamlı olmalı, yoksa test boş',
    );
  });
}

/// [index] numaralı projektörü atlasın BİREBİR dönüşümüyle çizer ve namlu
/// merceğinin ışık merkezini dünya biriminde döndürür.
Future<Offset> _lensCentre(int index, Size cell, Offset anchor) async {
  const ppwu = AtlasLayout.pixelsPerWorldUnit;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..translate(anchor.dx, anchor.dy)
    // `tool/ship_atlas_test.dart`'ın gövde bloğuyla aynı sıra.
    ..scale(ppwu * AtlasLayout.designScale)
    ..translate(0, Bastion.centreOffset)
    ..translate(Bastion.hardpoints[index].dx, Bastion.hardpoints[index].dy);
  WeaponEmitter.paintEmissive(
    canvas,
    length: Bastion.emitterLengths[index],
    width: Bastion.emitterWidths[index],
    time: AtlasLayout.baseTime,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(cell.width.round(), cell.height.round());
  picture.dispose();
  final data = (await image.toByteData())!;
  final width = image.width;
  final height = image.height;
  image.dispose();

  var peak = 0;
  for (var p = 0; p < width * height; p++) {
    final i = p * 4;
    final lum = data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
    if (lum > peak) peak = lum;
  }

  // Tepenin %90'ı üstündeki piksellerin AĞIRLIK MERKEZİ. Tek "en parlak
  // piksel" almak, doymuş bir çekirdeğin düz platosunda taramanın ilk
  // rastladığı köşeyi seçer ve bir-iki piksel kayar.
  var sumX = 0.0, sumY = 0.0, sumW = 0.0;
  final floor = peak * 0.985;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final lum =
          data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2);
      if (lum < floor) continue;
      sumX += x * lum;
      sumY += y * lum;
      sumW += lum;
    }
  }
  return Offset(
    (sumX / sumW - anchor.dx) / ppwu,
    (sumY / sumW - anchor.dy) / ppwu,
  );
}
