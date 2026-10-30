import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/shield_shell.dart';

/// Atlas ile PROSEDÜREL çizimin yan yana karşılaştırması.
///
/// Çizim mimarisi değişirken sorulması gereken tek soru şuydu: hız kazanırken
/// görüntüden ne kaybettik? Bu referans onu ölçülebilir kılıyor.
///
/// Üst sıra prosedürel (eski, kare başına 8 ms GPU), alt sıra atlastan (yeni,
/// kırk gemi için toplam 0.9 ms). Beklenen tek farklar: itki kademelerinin
/// ayrıklığı (çalışma zamanında çapraz sönümleniyor), doku yeniden örneklemesi
/// ve katmanların additive yerine srcOver kompozit edilmesi.
void main() {
  testWidgets('atlas ↔ prosedürel', (tester) async {
    late final ui.Image atlas;
    await tester.runAsync(() async {
      final data = await rootBundle.load('assets/ship_atlas.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      atlas = (await codec.getNextFrame()).image;
      codec.dispose();
    });

    const size = Size(1200, 620);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('atlas-parity');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(size: size, painter: _ParityPainter(atlas)),
      ),
    );
    await tester.pump();

    await expectLater(find.byKey(key), matchesGoldenFile('atlas_parity.png'));

    // Golden tek başına pariteyi DOĞRULAMAZ, yalnız kaydeder: sanat değişip
    // atlas pişirilmezse golden kırmızıya döner, ama refleksle atılacak
    // `--update-goldens` uyuşmayan sayfayı sessizce kabul eder. Aşağıdaki
    // ölçüm o kapıyı kapatıyor — iki satır arasındaki farkı sayıyla bağlıyor.
    await tester.runAsync(() async {
      final rows = await _rowRms(atlas, size);
      // ignore: avoid_print
      print('RMS ${rows.map((r) => r.toStringAsFixed(4)).join(' · ')}');
      for (var i = 0; i < rows.length; i++) {
        expect(
          rows[i],
          lessThan(_maxCellRms),
          reason:
              'hücre $i: atlas prosedürel çizimden sapmış (RMS ${rows[i].toStringAsFixed(4)}). '
              'Sanat değiştiyse atlası pişir:\n'
              '  flutter test --update-goldens tool/ship_atlas_test.dart',
        );
      }
    });
  });
}

/// Kabul edilen sapma. Bugünkü ölçüm (test koşarken basılıyor):
/// `0.0272 · 0.0296 · 0.0358 · 0.0453` — itki arttıkça büyüyor, çünkü pluma
/// hücrenin en parlak ve en detaylı öğesi.
///
/// Sapmanın tamamı YENİDEN ÖRNEKLEMEDEN: doku 1.8 piksel/birimde pişiyor,
/// referans ise 1.6×'te çiziliyor ve `saveLayer` bulanıklığının sigması
/// CİHAZ pikselinde tanımlı — yani iki ölçekte bloom yarıçapı tasarım
/// biriminde farklı çıkıyor. Parlak bir kenarın bir piksel kayması RMS'e
/// doğrudan yazıyor.
///
/// 0.045 → 0.050: silah yuvaları gövde hücresinden çıkıp kendi hücrelerine
/// taşındı ve artık ikinci bir yeniden örneklemeden geçiyorlar. Ölçüldü:
/// yuvaların katkısı en kötü hücrede 0.0073 (yuvasız aynı sayfa 0.0380).
/// Kayık bir çapa ya da bayat bir atlas bunun kat kat üstünde çıkar — eşik
/// hâlâ o kapıyı kapatıyor.
const double _maxCellRms = 0.05;

/// Sayfayı yeniden çizip üst (prosedürel) ve alt (atlas) satırları hücre hücre
/// karşılaştırır; her hücre için RMS farkı döner.
Future<List<double>> _rowRms(ui.Image atlas, Size size) async {
  final recorder = ui.PictureRecorder();
  _ParityPainter(atlas).paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final w = size.width.round();
  image.dispose();

  const cells = 4;
  const bandHeight = 280;
  const topY = 10, bottomY = 290;
  final cellWidth = w ~/ cells;

  return [
    for (var c = 0; c < cells; c++)
      () {
        var sum = 0.0;
        var n = 0;
        for (var y = 0; y < bandHeight; y++) {
          for (var x = c * cellWidth; x < (c + 1) * cellWidth; x++) {
            final a = ((topY + y) * w + x) * 4;
            final b = ((bottomY + y) * w + x) * 4;
            for (var ch = 0; ch < 3; ch++) {
              final d = (bytes[a + ch] - bytes[b + ch]) / 255.0;
              sum += d * d;
              n++;
            }
          }
        }
        return math.sqrt(sum / n);
      }(),
  ];
}

class _ParityPainter extends CustomPainter {
  const _ParityPainter(this.atlas);

  final ui.Image atlas;

  /// Ölçek: tasarım uzayındaki gemiyi bu referansta okunur büyüklükte göster.
  static const double view = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080D16),
    );

    // Atlasın GERÇEKTEN taşıdığı kademeler. Prosedürel satırı ara değerlerle
    // (0.35, 0.72) çizmek, taban hatayı nicemlemeyle doldurup gerçek sapmayı
    // maskeliyordu; ölçüm ancak eşi eşine karşılaştırınca bir şey söyler.
    final thrusts = [
      for (var i = 0; i < AtlasLayout.engineThrustSteps; i++)
        i / (AtlasLayout.engineThrustSteps - 1),
    ];
    final cell = size.width / thrusts.length;
    // Başlık YOK: golden ortamında gerçek font bulunmuyor ve metin kutulara
    // dönüşüp referansı kirletiyor. Üst sıra prosedürel, alt sıra atlas —
    // sıralama bu dosyada yazılı, görüntüde değil.
    for (var i = 0; i < thrusts.length; i++) {
      final cx = cell * (i + 0.5);
      // ── Üst: prosedürel ─────────────────────────────────────────────
      canvas
        ..save()
        ..translate(cx, 150)
        ..scale(view);
      ShieldShell.paint(
        canvas,
        radius: AtlasLayout.shieldRadiusWorld,
        strength: 1,
        time: AtlasLayout.baseTime,
      );
      canvas
        ..scale(AtlasLayout.designScale)
        ..translate(0, Bastion.centreOffset);
      Bastion.paint(
        canvas,
        time: AtlasLayout.baseTime,
        thrust: thrusts[i],
        lasers: Bastion.hardpoints.length,
      );
      canvas.restore();

      // ── Alt: atlastan ───────────────────────────────────────────────
      canvas
        ..save()
        ..translate(cx, 430)
        ..scale(view / AtlasLayout.pixelsPerWorldUnit);
      _sprite(
        canvas,
        AtlasLayout.shieldFrame(AtlasLayout.shieldStrengthSteps - 1, 0),
        AtlasLayout.shieldAnchor,
      );
      _sprite(canvas, AtlasLayout.engineFrame(i, 0), AtlasLayout.engineAnchor);
      _sprite(canvas, AtlasLayout.hullFrame(i, 0), AtlasLayout.hullAnchor);
      // Silah yuvaları da atlastan — prosedürel satır onları çizdiği için
      // buraya da girmeleri ŞART. Yoksa ölçüm "atlas ile prosedürel ayrıştı"
      // demez, "iki farklı gemi çizdim" der.
      for (var mount = 0; mount < AtlasLayout.emitterMounts; mount++) {
        final at = Bastion.worldHardpoints[mount];
        canvas
          ..save()
          ..translate(
            at.dx * AtlasLayout.pixelsPerWorldUnit,
            at.dy * AtlasLayout.pixelsPerWorldUnit,
          );
        _sprite(
          canvas,
          AtlasLayout.emitterFrame(mount, 0),
          AtlasLayout.emitterAnchor,
        );
        canvas.restore();
      }
      canvas.restore();
    }
  }

  void _sprite(Canvas canvas, Rect frame, Offset anchor) =>
      canvas.drawImageRect(
        atlas,
        frame,
        Rect.fromLTWH(-anchor.dx, -anchor.dy, frame.width, frame.height),
        Paint()..filterQuality = FilterQuality.medium,
      );

  @override
  bool shouldRepaint(_ParityPainter oldDelegate) => false;
}
