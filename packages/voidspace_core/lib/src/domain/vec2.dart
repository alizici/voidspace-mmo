import 'dart:math' as math;

/// Değişmez 2B vektör.
///
/// `dart:ui`'nin `Offset`'i ya da `vector_math`'in `Vector2`'si YERİNE var,
/// çünkü ikisi de bu paketin kabul edemeyeceği bir şey getiriyor: `Offset`
/// Flutter'a bağlı (sunucuda `dart:ui` yok), `Vector2` ise değişken ve
/// `Float32List` üzerinden çalışıyor — tahmin ile otoritenin bit düzeyinde
/// karşılaştırıldığı bir yerde float32 yuvarlaması istenmeyen bir sürpriz.
///
/// Değişmezlik burada süs değil: mutabakat (reconciliation) geçmiş durumları
/// geri sarıp yeniden oynatır. Paylaşılan değişken bir vektör, geri sarılan
/// durumu sessizce bozardı.
class Vec2 {
  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);
  Vec2 operator /(double scalar) => Vec2(x / scalar, y / scalar);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);

  /// Karşılaştırma için: karekök almadan uzaklık kıyaslar.
  double get lengthSquared => x * x + y * y;

  bool get isZero => x == 0 && y == 0;

  Vec2 normalized() {
    final l = length;
    return l == 0 ? zero : Vec2(x / l, y / l);
  }

  double distanceTo(Vec2 other) => (this - other).length;
  double distanceSquaredTo(Vec2 other) => (this - other).lengthSquared;

  /// Doğrusal ara değer. Uzak gemilerin snapshot'lar arasında yürütülmesinin
  /// tamamı bu tek işlem.
  static Vec2 lerp(Vec2 a, Vec2 b, double t) =>
      Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
