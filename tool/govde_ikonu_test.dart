import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/bastion.dart';

/// Kademe 8'in İKONUNU üretir — `assets/ships/bastion_molten.png`.
///
/// **Neden üretiliyor, elle çizilmiyor.** Kalan yedi kademenin ikonu
/// voidspace2 katalogundan gelen hazır PNG'ler. Sekizincisinin çizimi bu
/// projede KOD (`bastion.dart`) ve PNG'si yok. İki seçenek vardı: ikonu
/// menüde prosedürel boyamak, ya da bir kez pişirip PNG olarak koymak.
///
/// Pişirmek seçildi, iki sebeple. Biri tutarlılık: sekiz kart aynı yoldan
/// çizilince ızgarada biri diğerlerinden farklı görünmüyor. Diğeri depo
/// kuralı — `assets/ship_atlas.png` de böyle üretiliyor, yani "kökeni
/// bilinmeyen ikili dosya yok" bozulmuyor: kaynağı bu test.
///
/// Kadraj katalog PNG'leriyle AYNI: 512×512, saydam zemin, gemi tuvalin
/// ortasında ve genişliğin ~%70'ini kaplıyor. Pluma YOK — katalog önizlemeleri
/// de gövde-only, egzoz oyunda ayrı katmanda çiziliyor.
void main() {
  test('kademe 8 ikonu üretiliyor', () async {
    const tuval = 512.0;
    // Gemi tuvalin %70'ini kaplasın — katalog PNG'lerinin kadrajı bu.
    final olcek = tuval * 0.70 / (Bastion.reach * 2);

    final kayit = ui.PictureRecorder();
    final canvas = Canvas(kayit)
      ..translate(tuval / 2, tuval / 2)
      ..scale(olcek)
      // Gövde tasarım uzayında orijinde DEĞİL; burnu −y'de uzakta.
      // `centreOffset` onu tuvalin ortasına oturtuyor — aynı kaydırmayı
      // `ShipPortrait` ve atlas pişiricisi de yapıyor.
      ..translate(0, Bastion.centreOffset);
    // Durgun hâl: itki 0, zaman 0. İkon bir kare, bir animasyon değil —
    // ama eriyik dikişler ve reaktör itki sıfırken de yanıyor, o yüzden
    // ikon ölü bir silüet değil.
    Bastion.paintHull(canvas, time: 0, thrust: 0);

    final resim = await kayit.endRecording().toImage(
      tuval.toInt(),
      tuval.toInt(),
    );
    final bayt = await resim.toByteData(format: ui.ImageByteFormat.png);
    expect(bayt, isNotNull);

    final dosya = File('assets/ships/bastion_molten.png');
    dosya.writeAsBytesSync(bayt!.buffer.asUint8List());
    expect(dosya.lengthSync(), greaterThan(1000));
  });
}
