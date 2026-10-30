import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/palette.dart';
import 'package:voidspace3/game/art/droid_art.dart';

/// Görsel referans: on droid tasarımı × altı görsel kademe (05.8 s2).
///
/// Tek tek bakınca hepsi çalışıyor görünür; asıl soru satırlar arasında:
/// kademe dili on ailede AYNI mı okunuyor (L1 çekirdek → L6 enerji), ve on
/// silüet birbirinden ayrılıyor mu. Golden bu iki sorunun cevabını tutuyor.
///
/// Satırın başındaki iki tasarım satın alınabilir olanlar: Hilal NOVA
/// rafında, Delta kredi rafında. Kalan sekizi merdivenden geliyor.
Future<void> _yaziTipi() async {
  for (final path in const [
    '/System/Library/Fonts/Monaco.ttf',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader('monospace')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
    return;
  }
}

void main() {
  testWidgets('Droid tasarımları görsel referansı', (tester) async {
    await _yaziTipi();
    tester.view
      ..physicalSize = const Size(900, 1120)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('droid-tasarimlari');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(900, 1120), painter: _Sayfa()),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('droid_tasarimlari.png'),
    );
  });
}

class _Sayfa extends CustomPainter {
  const _Sayfa();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.menuBg);
    const sol = 150.0, adim = 108.0, ust = 74.0, satir = 100.0;

    for (var k = 0; k < DroidArt.maxLevel; k++) {
      _yaz(
        canvas,
        'L${k + 1}',
        Offset(sol + k * adim, 34),
        Palette.faint,
        11,
        ortala: true,
      );
    }

    for (var i = 0; i < DroidArt.hepsi.length; i++) {
      final art = DroidArt.hepsi[i];
      final y = ust + i * satir;
      _yaz(canvas, art.ad.toUpperCase(), Offset(16, y - 6), art.accent, 12);
      // Satın alınabilir iki tasarımın etiketi: ötekiler merdivenden.
      final not = switch (art.model) {
        DroidCizimi.hilal => 'NOVA',
        DroidCizimi.delta => 'KREDİ',
        _ => 'MERDİVEN',
      };
      _yaz(canvas, not, Offset(16, y + 10), Palette.faint, 9);

      for (var k = 0; k < DroidArt.maxLevel; k++) {
        canvas.save();
        canvas.translate(sol + k * adim, y + 4);
        art.draw(canvas, size: 30, level: k + 1);
        canvas.restore();
      }
    }
  }

  void _yaz(
    Canvas c,
    String metin,
    Offset at,
    Color renk,
    double boy, {
    bool ortala = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: metin,
        style: TextStyle(
          color: renk,
          fontSize: boy,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(ortala ? at.dx - tp.width / 2 : at.dx, at.dy));
  }

  @override
  bool shouldRepaint(_Sayfa oldDelegate) => false;
}
