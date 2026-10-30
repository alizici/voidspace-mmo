import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/void_spore.dart';
import 'package:voidspace3/game/art/yaratik_paletleri.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Görsel referans: bugün SERPİLEN on beş yaratık, kendi boylarında.
///
/// Bu görüntüden önce hepsi tek boyda çiziliyordu — modelleri 14 ile 19
/// arasında değişirken. Alt satır eski hâli (hepsi 24) gösteriyor: iki sıra
/// arasındaki fark, "vurulan yer" ile "görünen yer" arasındaki farktı.
void main() {
  testWidgets('Serpilen yaratıklar, model boyunda', (tester) async {
    final serpilen = YaratikKadrosu.serpilenler(Turetilenler.bolgeSayisi);
    final genislik = 84.0 * serpilen.length + 40;
    tester.view
      ..physicalSize = Size(genislik, 360)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('boy');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(genislik, 360), painter: _Boy(serpilen)),
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(key), matchesGoldenFile('yaratik_boy.png'));
  });
}

class _Boy extends CustomPainter {
  const _Boy(this.uyeler);

  final List<YaratikKimligi> uyeler;

  /// Dünya biriminden piksele.
  static const _olcek = 1.55;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF03050C),
    );
    final adim = size.width / uyeler.length;
    for (var i = 0; i < uyeler.length; i++) {
      final y = uyeler[i];
      final x = adim * (i + 0.5);
      // Üst: MODEL boyu. Alt: eski tek boy (spore'un 24'ü).
      _ciz(canvas, Offset(x, 95), y, y.yaricap);
      _ciz(canvas, Offset(x, 265), y, AlienStats.spore.radius);
    }
    // İki sırayı ayıran çizgi — hangisinin hangisi olduğu konumdan belli.
    canvas.drawLine(
      Offset(0, 180),
      Offset(size.width, 180),
      Paint()
        ..color = const Color(0xFF1B2636)
        ..strokeWidth = 1,
    );
  }

  void _ciz(Canvas canvas, Offset merkez, YaratikKimligi y, double yaricap) {
    final palet = YaratikPaletleri.hepsi[y.slug]!;
    final r = yaricap * _olcek;
    canvas
      ..save()
      ..translate(merkez.dx, merkez.dy);
    VoidSpore.paintHalo(canvas, r, palet);
    VoidSpore.paintShell(canvas, r, palet);
    VoidSpore.paintDetail(canvas, r, palet);
    VoidSpore.paintCore(canvas, r, palet);
    VoidSpore.paintCoreHot(canvas, r, palet);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
