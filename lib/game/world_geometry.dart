import 'dart:ui';

import 'package:flame/components.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// [GameWorld]'ün `dart:ui` karşılıkları.
///
/// Çekirdek paket `Offset`/`Rect`/`Size` KULLANAMAZ: `dart:ui` Flutter'a ait
/// ve aynı kod `dart:io` sunucusunda da koşuyor. Çizim tarafının bu tiplere
/// ihtiyacı var, o yüzden dönüşüm tam sınırda — burada — duruyor.
/// Tuvalin ŞU AN gördüğü dünya dikdörtgeni.
///
/// Kamera dönüşümü zaten tuvalde olduğu için görünür alan kırpma sınırlarından
/// okunabiliyor — bileşenin kamerayı, oyunu ya da görüş penceresini tanımasına
/// gerek yok. Bu, "bileşenler oyun döngüsünü içeri almaz" kuralını bozmadan
/// kameraya göre kırpmanın (culling) tek yolu.
///
/// Kırpma sınırı sonsuz ya da geçersiz dönerse dünyanın tamamına düşülür:
/// yavaş ama daima doğru.
Rect visibleRect(Canvas canvas, GameWorld world) {
  final clip = canvas.getLocalClipBounds();
  if (!clip.isFinite || clip.isEmpty) return world.bounds;
  return clip;
}

extension GameWorldGeometry on GameWorld {
  Size get size => Size(width, height);

  Rect get bounds => Rect.fromLTWH(0, 0, width, height);

  Vector2 get centreVector => Vector2(centre.x, centre.y);
}
