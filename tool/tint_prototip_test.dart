import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/void_spore.dart';
import 'package:voidspace3/game/art/yaratik_paletleri.dart';

/// Görsel referans: NÖTR pişirilip çizimde boyanan yaratıklar.
///
/// Oyunun çizdiği yolun aynısı: sprite `VoidSpore.notr` ile piştiği için
/// yalnız değer yapısı taşıyor, ton `BlendMode.modulate` ile katman katman
/// veriliyor. Atlas tek bir sprite tutuyor; otuz iki yaratık ondan çıkıyor.
///
/// Sol sütun sporun kendi paleti (karşılaştırma için), sağdakiler kadrodan.
void main() {
  testWidgets('Boyama prototipi', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 340)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('tint-prototip');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(1200, 340), painter: _Prototip()),
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(key), matchesGoldenFile('tint_prototip.png'));
  });
}

/// Nötr çizilmiş bir katmanı [renk] ile çarpar.
///
/// `drawRawAtlas`'ın örnek renkleriyle `BlendMode.modulate` yaparken yaptığı
/// işin aynısı, tek bir sprite için.
void _boya(Canvas canvas, Color renk, void Function(Canvas) ciz) {
  canvas.saveLayer(Rect.fromCircle(center: Offset.zero, radius: 200), Paint());
  ciz(canvas);
  canvas.drawRect(
    Rect.fromCircle(center: Offset.zero, radius: 200),
    Paint()
      ..blendMode = BlendMode.modulate
      ..color = renk,
  );
  canvas.restore();
}

class _Prototip extends CustomPainter {
  const _Prototip();

  static const _ornekler = ['interdictor', 'warray', 'hellborn', 'evokexvi'];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF03050C),
    );
    const r = 52.0;
    final adim = size.width / (_ornekler.length + 1);

    // ── 0 · sporun kendi paleti, aynı yoldan ──
    _tur(canvas, Offset(adim * 0.5, size.height * 0.45), r, VoidSpore.palet);
    _yazi(canvas, Offset(adim * 0.5, size.height * 0.45 + 118), 'SPORE');

    // ── kadro paletleriyle boyanmış ──
    for (var i = 0; i < _ornekler.length; i++) {
      _tur(
        canvas,
        Offset(adim * (i + 1.5), size.height * 0.45),
        r,
        YaratikPaletleri.hepsi[_ornekler[i]]!,
      );
      _yazi(
        canvas,
        Offset(adim * (i + 1.5), size.height * 0.45 + 118),
        _ornekler[i].toUpperCase(),
      );
    }
  }

  /// Bir yaratığı OYUNUN yolundan çizer: nötr sprite + katman tonları.
  void _tur(Canvas canvas, Offset merkez, double r, List<Color> palet) {
    canvas.save();
    canvas.translate(merkez.dx, merkez.dy);
    for (var k = 0; k < VoidSpore.katmanlar.length; k++) {
      final ton = palet[VoidSpore.katmanlar[k].first];
      _boya(canvas, ton, (c) {
        switch (k) {
          case 0:
            VoidSpore.paintHalo(c, r, VoidSpore.notr);
          case 1:
            VoidSpore.paintShell(c, r, VoidSpore.notr);
          case 2:
            VoidSpore.paintDetail(c, r, VoidSpore.notr);
          case 3:
            VoidSpore.paintCore(c, r, VoidSpore.notr);
          default:
            VoidSpore.paintCoreHot(c, r, VoidSpore.notr);
        }
      });
    }
    canvas.restore();
  }

  void _yazi(Canvas canvas, Offset merkez, String metin) {
    final p = TextPainter(
      text: TextSpan(
        text: metin,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7C8A99),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, merkez.translate(-p.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
