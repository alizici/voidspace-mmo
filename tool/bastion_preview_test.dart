import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/shield_shell.dart';

/// Görsel referans: gövde + motor + kalkan, tek sayfada.
///
/// Üst sıra itki rampası (durgun → tam gaz): motor plumasının Mach elmasları,
/// çatlak sıcaklığı ve korlar hep itkiyle sürülür, yani geminin durumu efektten
/// okunur. Alt sıra kalkanın üç hâli.
void main() {
  testWidgets('Bastion görsel referansı', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('bastion-preview');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(1200, 760), painter: _PreviewPainter()),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('bastion_preview.png'),
    );
  });
}

const _thrusts = [0.0, 0.35, 0.7, 1.0];
const _times = [0.0, 0.72, 1.44, 2.16];
const _rowA = 420.0;

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071018), Color(0xFF03050C)],
        ).createShader(Offset.zero & size),
    );

    final cell = size.width / _thrusts.length;
    final scale = 120 / Bastion.reach;

    // ── İtki rampası ──────────────────────────────────────────────────────
    for (var i = 0; i < _thrusts.length; i++) {
      canvas
        ..save()
        ..translate(cell * (i + 0.5), _rowA * 0.46)
        ..scale(scale)
        ..translate(0, Bastion.centreOffset);
      Bastion.paint(
        canvas,
        time: _times[i],
        thrust: _thrusts[i],
        lasers: Bastion.hardpoints.length,
      );
      canvas.restore();
      if (i > 0) {
        canvas.drawLine(
          Offset(cell * i, 24),
          Offset(cell * i, _rowA - 24),
          Paint()
            ..strokeWidth = 0.8
            ..color = const Color(0x224FE3FF),
        );
      }
    }
    canvas.drawLine(
      Offset(0, _rowA),
      Offset(size.width, _rowA),
      Paint()
        ..strokeWidth = 0.8
        ..color = const Color(0x334FE3FF),
    );

    // ── Kalkanın üç hâli ──────────────────────────────────────────────────
    // Kabarcık artık bir `ShipState` değil salt ORAN alıyor: gücü nereden
    // geldiğini bilmemesi, aynı bileşenin hem kendi geminde (tahmin) hem uzak
    // gemilerde (snapshot) çalışmasının sebebi.
    final states = <(String, double)>[
      ('tam', 1),
      ('yarım', 0.42),
      ('darbe', 0.8),
    ];
    final shieldCell = size.width / states.length;
    for (var i = 0; i < states.length; i++) {
      // Üçüncü hücre darbe anı: vuruşta kabuk parlar ve halka açılır.
      final strength = i == 2 ? 0.55 : states[i].$2;
      final flash = i == 2 ? 0.87 : 0.0;

      canvas
        ..save()
        ..translate(shieldCell * (i + 0.5), _rowA + 170);
      canvas
        ..save()
        ..scale(scale)
        ..translate(0, Bastion.centreOffset);
      Bastion.paint(
        canvas,
        time: 1.1,
        thrust: 0.55,
        lasers: Bastion.hardpoints.length,
      );
      canvas
        ..restore()
        ..save()
        ..scale(1.9); // kabuk dünya birimindedir; gemiyle aynı orana getir
      ShieldShell.paint(
        canvas,
        radius: 62,
        strength: strength,
        flash: flash,
        time: 1.1,
      );
      canvas
        ..restore()
        ..restore();
      if (i > 0) {
        canvas.drawLine(
          Offset(shieldCell * i, _rowA + 24),
          Offset(shieldCell * i, size.height - 24),
          Paint()
            ..strokeWidth = 0.8
            ..color = const Color(0x224FE3FF),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
