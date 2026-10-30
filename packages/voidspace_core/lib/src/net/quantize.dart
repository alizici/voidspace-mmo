import 'dart:math' as math;

/// Sayıları tele sığdırma.
///
/// Neden hiç `f32` göndermiyoruz: bir konum 4 bayt yerine 2 bayta indiğinde,
/// 30 Hz × 25 görünür gemi × 50 oyuncu ölçeğinde bu tek karar saniyede yüz
/// kilobaytları siler.
///
/// Kayıp KABUL EDİLEBİLİR olmalı, "yeterince küçük" değil — ölçelim:
/// 12000 birimlik dünyada `u16` adım genişliği 0.18 birim, gemi ise ~112 birim
/// genişliğinde. Yani hata gövdenin altı yüzde birinin altında. Açıda `u8`
/// adımı 1.4°'dir ve zaten istemcide interpolasyondan geçtiği için görünmez.
abstract final class Quantize {
  static const int _u16Max = 65535;
  static const int _u8Max = 255;

  /// Dünya koordinatı → `u16`. [span] eksenin tam genişliği.
  static int position(double v, double span) =>
      ((v / span) * _u16Max).round().clamp(0, _u16Max);

  static double unposition(int q, double span) => q / _u16Max * span;

  /// [-π, π] → `u8`. Sarma kasıtlı: 255 ile 0 komşudur, tıpkı açının kendisi
  /// gibi.
  static int angle(double radians) {
    final normalized = (radians + math.pi) / (2 * math.pi);
    return ((normalized % 1.0) * _u8Max).round().clamp(0, _u8Max);
  }

  static double unangle(int q) => q / _u8Max * 2 * math.pi - math.pi;

  /// 0..1 oranı → `u8`. İtki, kalkan ve gövde oranları için.
  static int unit(double v) => (v.clamp(0.0, 1.0) * _u8Max).round();

  static double ununit(int q) => q / _u8Max;
}
