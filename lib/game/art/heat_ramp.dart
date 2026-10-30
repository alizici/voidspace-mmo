import 'dart:ui';

/// Kor rengi paleti — rampanın durakları. Buradaki tek kural: değer (value)
/// yukarı çıkarken renk sıcaklığı da çıkar.
const kEmberDeep = Color(0xFFB91C09);
const kEmberLava = Color(0xFFFF4B0B);
const kEmberHot = Color(0xFFFFC247);
const kEmberCore = Color(0xFFFFF1A6);

/// Kara-cisim benzeri sıcaklık rampası: 0 = soğuk, 1 = beyaz-sıcak.
///
/// Projedeki HER emissive renk buradan örneklenir. Sebebi: okumayı renk tonu
/// değil **değer** karşıtlığı taşımalı. Bir gövdenin kimliğini değiştirmek de
/// böylece on iki rengi yeniden ayarlamak değil, rampayı değiştirmek olur.
class HeatRamp {
  const HeatRamp(this.stops, this.colors);

  final List<double> stops;
  final List<Color> colors;

  Color at(double t, [double alpha = 1]) {
    final u = t.clamp(0.0, 1.0).toDouble();
    var i = 1;
    while (i < stops.length - 1 && u > stops[i]) {
      i++;
    }
    final lo = stops[i - 1];
    final hi = stops[i];
    final k = ((u - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
    return Color.lerp(
      colors[i - 1],
      colors[i],
      k,
    )!.withValues(alpha: alpha.clamp(0.0, 1.0).toDouble());
  }

  /// Erimiş demir — Bastion'un lav kimliği. Beyaz karneye bağlıdır: yalnız
  /// nozzle boğazı ve en sıcak çatlak cepleri oraya ulaşır.
  static const molten = HeatRamp(
    [0.0, 0.20, 0.42, 0.63, 0.82, 0.92, 1.0],
    [
      Color(0xFF1B0402), // soğumuş kabuk
      Color(0xFF6E1003), // mat kızıl
      kEmberDeep,
      kEmberLava,
      kEmberHot,
      kEmberCore,
      Color(0xFFFFF6DC), // beyaz-sıcak
    ],
  );
}
