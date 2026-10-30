import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Envanter hücresindeki eşya işareti.
///
/// **Neden metin değil şekil.** Klasik envanter ızgarası küçük hücrelerden
/// oluşuyor ve küçük hücreye metin sığmıyor: 56 piksellik bir kutuda 11
/// puntoyla en fazla dört harf var, oysa "Nişan Devresi" on üç. Hücreyi metne
/// göre büyütmek ızgarayı bir listeye çeviriyordu — oyuncunun "kareler büyük"
/// dediği şey buydu.
///
/// **Neden ana stattan türüyor.** İşaret eşyanın YAPTIĞI ŞEYİ göstermeli,
/// adını değil. `mainStat` tam olarak o: aynı yuvaya giren iki jeneratörden
/// biri kalkan biri hız veriyor ve ikisi farklı çiziliyor. Kimliğe göre
/// çizseydik katalog her büyüdüğünde buraya bir satır daha eklemek
/// gerekirdi; stata göre çizince yeni bir kalkan jeneratörü hiçbir şey
/// yazmadan doğru işareti alıyor.
enum ItemGlyph {
  /// Lazer — namlu ve ağız.
  laser,

  /// Kalkan jeneratörü.
  shield,

  /// İtki jeneratörü.
  thrust,

  /// Roketatar.
  launcher,

  /// Onarım devresi.
  repair,

  /// Nişan devresi.
  scope,

  /// Tanınmayan stat — boş kare yerine nötr bir işaret.
  unknown;

  /// Eşyanın ANA STATINDAN işaret.
  static ItemGlyph of(String mainStat) => switch (mainStat) {
    'taban_hasar' => laser,
    'kalkan' => shield,
    'hiz' => thrust,
    'hasar_artisi' => launcher,
    'kalkan_yenilenmesi' => repair,
    'menzil' => scope,
    _ => unknown,
  };

  /// [ItemSpec]'ten işaret.
  static ItemGlyph ofSpec(ItemSpec spec) => of(spec.mainStat);
}

/// Eşya işaretini çizen boyacı.
///
/// Çizim `size` kutusuna göre ölçekleniyor: aynı işaret hücrede küçük,
/// mağaza kartında büyük çiziliyor ve iki yerde aynı şeyi anlatıyor.
class ItemGlyphPainter extends CustomPainter {
  const ItemGlyphPainter(this.glyph, this.color);

  final ItemGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Bütün şekiller 24×24'lük bir kutuya çiziliyor, sonra ölçekleniyor —
    // her işareti ayrı ayrı ölçeklemek yerine tek bir dönüşüm.
    const design = 24.0;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(math.min(size.width, size.height) / design)
      ..translate(-design / 2, -design / 2);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (glyph) {
      case ItemGlyph.laser:
        // Namlu gövdesi + ağız hunisi. Ok DEĞİL: ok "yön" demek, bu ise
        // silah.
        canvas
          ..drawRRect(
            RRect.fromLTRBR(3, 9.5, 15, 14.5, const Radius.circular(1.5)),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(15, 8)
              ..lineTo(21, 12)
              ..lineTo(15, 16)
              ..close(),
            fill,
          );

      case ItemGlyph.shield:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2.5)
            ..lineTo(20, 6)
            ..lineTo(20, 12)
            ..cubicTo(20, 17, 16, 20.5, 12, 22)
            ..cubicTo(8, 20.5, 4, 17, 4, 12)
            ..lineTo(4, 6)
            ..close(),
          stroke,
        );

      case ItemGlyph.thrust:
        // Üç çift ok: hız, tek okla değil TEKRARLA anlatılıyor.
        for (var i = 0; i < 3; i++) {
          final x = 5.0 + i * 6;
          canvas.drawPath(
            Path()
              ..moveTo(x, 6)
              ..lineTo(x + 5, 12)
              ..lineTo(x, 18),
            stroke,
          );
        }

      case ItemGlyph.launcher:
        canvas
          ..drawPath(
            Path()
              ..moveTo(12, 2)
              ..cubicTo(16, 7, 16, 14, 15, 18)
              ..lineTo(9, 18)
              ..cubicTo(8, 14, 8, 7, 12, 2)
              ..close(),
            stroke,
          )
          // Kanatlar.
          ..drawPath(
            Path()
              ..moveTo(9, 14)
              ..lineTo(5.5, 20)
              ..lineTo(9, 18.5),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(15, 14)
              ..lineTo(18.5, 20)
              ..lineTo(15, 18.5),
            stroke,
          )
          ..drawCircle(const Offset(12, 9), 1.6, fill);

      case ItemGlyph.repair:
        // Devre kutusu + artı: onarım.
        canvas
          ..drawRRect(
            RRect.fromLTRBR(5, 5, 19, 19, const Radius.circular(2.5)),
            stroke,
          )
          ..drawLine(const Offset(12, 8.5), const Offset(12, 15.5), stroke)
          ..drawLine(const Offset(8.5, 12), const Offset(15.5, 12), stroke);

      case ItemGlyph.scope:
        canvas
          ..drawCircle(const Offset(12, 12), 6.5, stroke)
          ..drawLine(const Offset(12, 2.5), const Offset(12, 6.5), stroke)
          ..drawLine(const Offset(12, 17.5), const Offset(12, 21.5), stroke)
          ..drawLine(const Offset(2.5, 12), const Offset(6.5, 12), stroke)
          ..drawLine(const Offset(17.5, 12), const Offset(21.5, 12), stroke)
          ..drawCircle(const Offset(12, 12), 1.4, fill);

      case ItemGlyph.unknown:
        canvas.drawRRect(
          RRect.fromLTRBR(6, 6, 18, 18, const Radius.circular(3)),
          stroke,
        );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ItemGlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// Eşya işaretini çizen küçük bileşen.
class ItemGlyphIcon extends StatelessWidget {
  const ItemGlyphIcon({
    required this.glyph,
    required this.color,
    required this.size,
    super.key,
  });

  final ItemGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: ItemGlyphPainter(glyph, color),
  );
}
