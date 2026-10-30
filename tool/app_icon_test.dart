import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/bastion.dart';

/// Uygulama ikonunun KAYNAĞI.
///
/// İkonlar depoda kökeni bilinmeyen ikili dosyalar olarak durmasın diye
/// buradan üretilir. `web/icons/*` ve `web/favicon.png` bunun türevidir.
/// Gemi tuvalin %58'ini kaplar — maskeli (maskable) ikonun güvenli alanına
/// sığması için gereken oran.
void main() {
  testWidgets('uygulama ikonu', (tester) async {
    tester.view
      ..physicalSize = const Size(512, 512)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('app-icon');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(512, 512), painter: _IconPainter()),
      ),
    );
    await tester.pump();

    await expectLater(find.byKey(key), matchesGoldenFile('app_icon.png'));
  });
}

class _IconPainter extends CustomPainter {
  const _IconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    canvas
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.75,
            colors: const [Color(0xFF13202E), Color(0xFF03050C)],
          ).createShader(Offset.zero & size),
      )
      // Lav çekirdeğinin arkadan verdiği sıcak halka — ikonu siyah bir kareden
      // ayıran şey bu.
      ..drawCircle(
        centre,
        size.width * 0.34,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0x33FF4B0B)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46),
      )
      ..save();
    canvas
      ..translate(centre.dx, centre.dy)
      ..scale(size.width * 0.29 / Bastion.reach)
      ..translate(0, Bastion.centreOffset);
    Bastion.paint(
      canvas,
      time: 1.1,
      thrust: 0.62,
      lasers: Bastion.hardpoints.length,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
