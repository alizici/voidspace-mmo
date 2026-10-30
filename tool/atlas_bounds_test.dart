import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/shield_shell.dart';

/// Atlas hücrelerinin GERÇEKTEN yettiğini ölçer.
///
/// Hücre boyutları elle ölçülmüş sabitler. Bir öğe hücreyi taşarsa Flutter
/// hata vermez: `clipRect` onu kenardan keser ve geriye düz bir kesik kenar
/// kalır. Soluk bir parıltı kuyruğunda bu, ekranda "gemi dikdörtgen bir alana
/// hapsedilmiş" gibi okunur.
///
/// Ölçümün iki kuralı var, ikisi de acıyla öğrenildi:
///
///  1. **Eşik sıfır.** Alfa 1/255'lik bir kuyruk bile sert kesilince görünür
///     bir çizgi bırakır. "Görünmez" saydığın piksel, kesildiğinde görünür.
///  2. **Örneklem, pişirilenin TAM kendisi.** Rastgele birkaç zaman/itki değeri
///     yetmez: en geniş kare, örneklemediğin faz olabilir. Aşağıdaki döngüler
///     `tool/ship_atlas_test.dart`'ın pişirdiği ızgaranın aynısıdır.
///  3. **Birim, hücrenin birimi.** Gövde ve motor tasarım uzayında çizilir ama
///     hücre DÜNYA biriminde beyan edilir; arada [AtlasLayout.designScale]
///     vardır. Sonda o ölçeği pişirmenin yaptığı gibi uygular, yoksa ölçüm
///     %15 küçük çıkar ve "sığıyor" der — kırpılırken.
Future<Rect> _alphaBounds(
  void Function(Canvas) draw, {
  required double probe,
}) async {
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
      if (bytes[(y * size + x) * 4 + 3] == 0) continue;
      if (x < minX) minX = x.toDouble();
      if (y < minY) minY = y.toDouble();
      if (x > maxX) maxX = x.toDouble();
      if (y > maxY) maxY = y.toDouble();
    }
  }
  if (maxX == 0 && maxY == 0 && minX == probe) return Rect.zero;
  // Piksel merkezinden kenarına: sağ/alt sınıra +1.
  return Rect.fromLTRB(
    minX - probe / 2,
    minY - probe / 2,
    maxX + 1 - probe / 2,
    maxY + 1 - probe / 2,
  );
}

void main() {
  const probe = 560.0;

  Rect union(Rect a, Rect b) =>
      a == Rect.zero ? b : (b == Rect.zero ? a : a.expandToInclude(b));

  /// Pişirilen ızgaranın aynısı üzerinde birleşik sınır.
  Future<Rect> overGrid(
    int steps,
    int phases,
    void Function(Canvas, double value, double time) draw,
  ) async {
    var bounds = Rect.zero;
    for (var step = 0; step < steps; step++) {
      for (var phase = 0; phase < phases; phase++) {
        bounds = union(
          bounds,
          await _alphaBounds(
            (c) => draw(
              c,
              steps == 1 ? 1 : step / (steps - 1),
              AtlasLayout.baseTime + phase * AtlasLayout.phaseStep,
            ),
            probe: probe,
          ),
        );
      }
    }
    return bounds;
  }

  void expectFits(String name, Rect measured, Size cell, Offset anchor) {
    final inCell = measured.shift(anchor);
    expect(
      inCell.left >= 0 &&
          inCell.top >= 0 &&
          inCell.right <= cell.width &&
          inCell.bottom <= cell.height,
      isTrue,
      reason:
          '$name hücreyi taşıyor → atlas kenardan KESER (hata vermez).\n'
          '  ölçülen (tasarım uzayı): $measured\n'
          '  hücre içi              : $inCell\n'
          '  hücre                  : ${Offset.zero & cell}',
    );
  }

  testWidgets('atlas hücreleri çizimi kırpmıyor', (tester) async {
    // `Picture.toImage` gerçek olay döngüsü ister.
    await tester.runAsync(() async {
      final engine = await overGrid(
        AtlasLayout.engineThrustSteps,
        AtlasLayout.enginePhases,
        (c, value, time) {
          c
            ..scale(AtlasLayout.designScale)
            ..translate(0, Bastion.centreOffset);
          Bastion.paintEngine(c, time: time, thrust: value);
        },
      );
      final hull = await overGrid(
        AtlasLayout.hullThrustSteps,
        AtlasLayout.hullPhases,
        (c, value, time) {
          c
            ..scale(AtlasLayout.designScale)
            ..translate(0, Bastion.centreOffset);
          Bastion.paintHull(c, time: time, thrust: value);
        },
      );
      final shield = await overGrid(
        AtlasLayout.shieldStrengthSteps,
        AtlasLayout.shieldPhases,
        (c, value, time) => ShieldShell.paint(
          c,
          radius: AtlasLayout.shieldRadiusWorld,
          strength: value,
          time: time,
        ),
      );

      // Silah yuvası: "kademe" ekseni itki değil KAİDE İNDEKSİ. Beş kaide
      // aynı hücre boyunu paylaşıyor, o yüzden ölçüm de hepsinin birleşimi —
      // en büyük yuva (merkez top) hücreyi belirliyor.
      final emitter = await overGrid(
        AtlasLayout.emitterMounts,
        AtlasLayout.emitterPhases,
        (c, value, time) {
          c.scale(AtlasLayout.designScale);
          Bastion.paintEmitter(
            c,
            index: (value * (AtlasLayout.emitterMounts - 1)).round(),
            time: time,
          );
        },
      );

      // ignore: avoid_print
      print('ÖLÇÜM  motor=$engine  gövde=$hull  kalkan=$shield  yuva=$emitter');

      // Sanat ile yerleşim aynı sayıyı bilmek ZORUNDA. `AtlasLayout` sanatı
      // içeri alamıyor (döngü olurdu), o yüzden kaide sayısı orada elle
      // yazılı — ve elle yazılan her sayı bir gün ayrışır. Altıncı bir kaide
      // eklendiğinde atlas beş hücre pişirmeye devam ederdi ve altıncı silah
      // ekranda ya kaybolur ya da komşu karenin parçasını çizerdi.
      expect(
        AtlasLayout.emitterMounts,
        Bastion.hardpoints.length,
        reason: 'kaide sayısı yerleşim ile sanat arasında ayrışmış',
      );

      expectFits(
        'motor katmanı',
        engine,
        AtlasLayout.engineCellWorld,
        AtlasLayout.engineAnchorWorld,
      );
      expectFits(
        'gövde katmanı',
        hull,
        AtlasLayout.hullCellWorld,
        AtlasLayout.hullAnchorWorld,
      );
      expectFits(
        'kalkan katmanı',
        shield,
        AtlasLayout.shieldCellWorld,
        AtlasLayout.shieldAnchorWorld,
      );
      expectFits(
        'silah yuvası',
        emitter,
        AtlasLayout.emitterCellWorld,
        AtlasLayout.emitterAnchorWorld,
      );

      // Bloom'un `saveLayer` kutusu da yetmeli. Hücreden AYRI bir ölçüm:
      // hücre bulanıklaşmış sonucu tutuyor, bu kutu ise bulanıklığın
      // HESAPLANDIĞI alan. Küçük kalırsa parıltı kenardan düz kesilir ve
      // hücre taşmadığı için `expectFits` bunu göremez.
      //
      // Ölçüm dünya biriminde, kutu tasarım biriminde — arada
      // [AtlasLayout.designScale] var.
      final glow = Rect.fromLTRB(
        emitter.left / AtlasLayout.designScale,
        emitter.top / AtlasLayout.designScale,
        emitter.right / AtlasLayout.designScale,
        emitter.bottom / AtlasLayout.designScale,
      );
      const box = Bastion.emitterBounds;
      expect(
        box.left <= glow.left &&
            box.top <= glow.top &&
            box.right >= glow.right &&
            box.bottom >= glow.bottom,
        isTrue,
        reason:
            'bloom kutusu yuvanın çizimini tutmuyor — parıltı kesilir.\n'
            '  ölçülen (tasarım): $glow\n'
            '  kutu             : $box',
      );
    });
  });
}
