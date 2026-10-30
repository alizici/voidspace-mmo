import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/hangar/ship_portrait.dart';

/// Hangar portresinin çerçeveye SIĞDIĞINI ölçer.
///
/// [ShipPortrait.artBounds] sanatı çerçeveye oturtan tek sayı. Sanat büyürse
/// Flutter hata vermez — portre kutunun kenarından kesilir ve geriye kanadı
/// düz kesilmiş bir gemi kalır. `tool/atlas_bounds_test.dart` aynı sessiz
/// kırpmayı atlas hücreleri için yakalıyor; bu, menü için aynısını yapar.
///
/// Eşik SIFIR DEĞİL ve sebebi [ShipPortrait.artBounds] içinde yazılı: burada
/// `clipRect` yok, koronanın görünmez kuyruğu menü zeminine sızıyor. Ölçülen
/// şey "hiçbir piksel taşmıyor" değil, "GÖRÜNEN gemi kutuya sığıyor".
Future<Rect> _alphaBounds(void Function(Canvas) draw, double probe) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(probe / 2, probe / 2);
  draw(canvas);
  final size = probe.round();
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  image.dispose();

  var minX = probe, minY = probe, maxX = 0.0, maxY = 0.0;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (bytes[(y * size + x) * 4 + 3] < ShipPortrait.visibleAlpha) continue;
      if (x < minX) minX = x.toDouble();
      if (y < minY) minY = y.toDouble();
      if (x > maxX) maxX = x.toDouble();
      if (y > maxY) maxY = y.toDouble();
    }
  }
  return Rect.fromLTRB(
    minX - probe / 2,
    minY - probe / 2,
    maxX + 1 - probe / 2,
    maxY + 1 - probe / 2,
  );
}

void main() {
  test('portre sınırı beyan edilen kutuya sığar', () async {
    // Ölçek 2: alt piksel kuyruğu tek piksellik bir ızgarada kaybolmasın.
    const scale = 2.0;
    const probe = 640.0;
    final measured = await _alphaBounds((canvas) {
      canvas
        ..scale(scale)
        ..translate(0, Bastion.centreOffset);
      // Portrenin çizdiğinin AYNISI: sabit zaman, itki sıfır.
      Bastion.paint(
        canvas,
        time: AtlasLayout.baseTime,
        thrust: 0,
        lasers: Bastion.hardpoints.length,
      );
    }, probe);

    final design = Rect.fromLTRB(
      measured.left / scale,
      measured.top / scale,
      measured.right / scale,
      measured.bottom / scale,
    );

    const declared = ShipPortrait.artBounds;
    // `Rect.contains` sağ/alt kenarda DIŞLAYICI: ölçüm beyanla birebir
    // eşitken bile `false` döner. Kenarları tek tek karşılaştırmak hem doğru
    // hem de hangi kenarın taştığını söylüyor.
    final inside =
        declared.left <= design.left &&
        declared.top <= design.top &&
        declared.right >= design.right &&
        declared.bottom >= design.bottom;
    expect(
      inside,
      isTrue,
      reason:
          'sanat beyan edilen kutuyu taşıyor — portre kenardan kesilecek.\n'
          'Ölçülen: $design\n'
          'Beyan  : $declared\n'
          'Düzeltmek için `ShipPortrait.artBounds` değerini ölçülene eşitle.',
    );

    // Ters yön de ölçülüyor. Kutu ölçümden büyükse portre KÜÇÜLÜR: gemi
    // çerçevenin ortasında, etrafında sebepsiz boşlukla durur. Bu, kırpma
    // kadar göze batmadığı için fark edilmeden kalabilecek türden bir hata.
    const slack = 12.0;
    expect(
      declared.width - design.width < slack &&
          declared.height - design.height < slack,
      isTrue,
      reason:
          'kutu ölçümden gereksiz büyük — portre boşluğa küçültülüyor.\n'
          'Ölçülen: $design\n'
          'Beyan  : $declared',
    );
  });
}
