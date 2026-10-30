import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Tek bir `drawRawAtlas` çağrısının tamponları — SÜRÜLER ARASINDA ORTAK.
///
/// Gemiler ve alien'ler aynı `RSTransform` matematiğini kullanıyor. İki
/// kopyada tutmak, birinde düzeltilen bir çeviri hatasının diğerinde
/// yaşamaya devam etmesi demekti — ve o hata (bir çapa kayması) ekranda
/// "bir şeyler ters" diye görünüp hangi sayının yanlış olduğunu göstermiyor.
///
/// Üç `Float32List`/`Int32List` yeniden kullanılıyor; kare başına tahsis
/// yalnız kapasite büyürken, yani ilk birkaç karede oluyor.
class AtlasBatch {
  Float32List _xform = Float32List(4 * 64);
  Float32List _rects = Float32List(4 * 64);
  Int32List _colors = Int32List(64);
  int _count = 0;

  void begin() => _count = 0;

  void push({
    required double x,
    required double y,
    required double angle,
    required double scale,
    required Rect frame,
    required Offset anchor,
    required double alpha,
    Color tint = const Color(0xFFFFFFFF),
  }) {
    _ensure(_count + 1);

    final scos = math.cos(angle) * scale;
    final ssin = math.sin(angle) * scale;

    // `RSTransform.fromComponents`'in hesabı, nesne kurmadan.
    final i = _count * 4;
    _xform[i] = scos;
    _xform[i + 1] = ssin;
    _xform[i + 2] = x - scos * anchor.dx + ssin * anchor.dy;
    _xform[i + 3] = y - ssin * anchor.dx - scos * anchor.dy;

    _rects[i] = frame.left;
    _rects[i + 1] = frame.top;
    _rects[i + 2] = frame.right;
    _rects[i + 3] = frame.bottom;

    // `modulate` kaynağı renkle ÇARPAR; beyaz üzerinden yalnız alfa geçer.
    //
    // [tint] beyaz DEĞİLSE sprite o renge boyanıyor. Mekanizma bu satırda
    // baştan beri vardı ama kullanılmıyordu: sprite atlasa kendi renginde
    // pişiyordu, yani çarpmak onu yalnız karartabilirdi. Sprite NÖTR (gri)
    // piştiğinde aynı çarpma bir renk haritasına dönüşüyor — değer yapısı
    // sprite'ta, ton burada.
    final a = (alpha.clamp(0.0, 1.0) * 255).round();
    _colors[_count] =
        (a << 24) |
        ((tint.r * 255).round() << 16) |
        ((tint.g * 255).round() << 8) |
        (tint.b * 255).round();
    _count++;
  }

  void _ensure(int needed) {
    if (_colors.length >= needed) return;
    var capacity = _colors.length * 2;
    while (capacity < needed) {
      capacity *= 2;
    }
    _xform = Float32List(capacity * 4)..setRange(0, _count * 4, _xform);
    _rects = Float32List(capacity * 4)..setRange(0, _count * 4, _rects);
    _colors = Int32List(capacity)..setRange(0, _count, _colors);
  }

  void draw(Canvas canvas, ui.Image image, Paint paint) {
    if (_count == 0) return;
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_xform, 0, _count * 4),
      Float32List.sublistView(_rects, 0, _count * 4),
      Int32List.sublistView(_colors, 0, _count),
      BlendMode.modulate,
      null,
      paint,
    );
  }
}
