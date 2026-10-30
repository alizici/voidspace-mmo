import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';

/// Görsel referans: gemi TAKILI lazer sayısına göre kaç top taşıyor.
///
/// **Atlastan çiziliyor, prosedürel değil.** Bu ayrım testin bütün değeri:
/// prosedürel çizim yalnız sanatın doğru olduğunu gösterirdi, oysa burada
/// sorulan soru yerleşim ve dönüş matematiği — yuva doğru hücreden mi
/// geliyor, kaidesinin üstüne mi oturuyor, gemi dönünce onunla mı dönüyor.
/// `ShipSwarm`'ın kare yolunda yaptığının aynısı.
///
/// Alt sıra DÖNMÜŞ gemiler: dönüş hatası düz duran bir gemide görünmez, çünkü
/// hardpoint ofseti (0, y) ekseninde kalır. Yamuk duran bir gemide silahlar
/// gövdenin yanında yüzer.
const _levels = [0, 1, 2, 3, 4, 5];

void main() {
  testWidgets('Donanım görsel referansı', (tester) async {
    late ui.Image atlas;
    await tester.runAsync(() async {
      final data = await rootBundle.load('assets/ship_atlas.png');
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        data.buffer.asUint8List(),
      );
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final codec = await descriptor.instantiateCodec();
      atlas = (await codec.getNextFrame()).image;
    });

    const size = Size(1080, 560);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('armament-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(size: size, painter: _ArmamentPainter(atlas)),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('armament_preview.png'),
    );
  });
}

class _ArmamentPainter extends CustomPainter {
  const _ArmamentPainter(this.atlas);

  final ui.Image atlas;

  /// Referansta okunur büyüklük.
  static const double view = 1.15;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080D16),
    );

    final cell = size.width / _levels.length;
    for (var i = 0; i < _levels.length; i++) {
      final cx = cell * (i + 0.5);
      _ship(canvas, Offset(cx, 150), _levels[i], 0);
      _ship(canvas, Offset(cx, 410), _levels[i], 0.6);
    }
  }

  void _ship(Canvas canvas, Offset at, int lasers, double angle) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      // Atlas piksellerinden ekrana. `ShipSwarm` aynı ölçeği
      // `atlas.worldScale` üzerinden uyguluyor.
      ..scale(view / AtlasLayout.pixelsPerWorldUnit);

    _sprite(canvas, AtlasLayout.engineFrame(0, 0), AtlasLayout.engineAnchor);
    _sprite(canvas, AtlasLayout.hullFrame(0, 0), AtlasLayout.hullAnchor);
    for (final mount in Bastion.activeHardpoints(lasers)) {
      // Yuvanın gemideki yeri DÜNYA biriminde; bu tuval atlas pikselinde.
      final p = Bastion.worldHardpoints[mount] * AtlasLayout.pixelsPerWorldUnit;
      canvas
        ..save()
        ..translate(p.dx, p.dy);
      _sprite(
        canvas,
        AtlasLayout.emitterFrame(mount, 0),
        AtlasLayout.emitterAnchor,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _sprite(Canvas canvas, Rect frame, Offset anchor) =>
      canvas.drawImageRect(
        atlas,
        frame,
        Rect.fromLTWH(-anchor.dx, -anchor.dy, frame.width, frame.height),
        Paint()..filterQuality = FilterQuality.medium,
      );

  @override
  bool shouldRepaint(_ArmamentPainter old) => false;
}
