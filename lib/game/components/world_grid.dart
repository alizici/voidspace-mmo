import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:voidspace_core/voidspace_core.dart';

import '../world_geometry.dart';

/// Taktik ızgara + parlayan harita kenarı.
///
/// Amacı süs değil okunabilirlik: boş uzayda hareket hissi ancak sabit bir
/// referans varsa oluşur, ve oyuncunun oynanabilir alanın nerede bittiğini
/// görmesi gerekir.
///
/// **Kameraya göre kırpılır.** Eski hâli her karede haritanın tamamını
/// çiziyordu: 50 tam boy çizgi artı 12000×8000'lik bulanık maskeli bir kenar
/// dikdörtgeni. Ekranda görünen kısmı bunun yüzde biriydi ve tarayıcıda
/// ölçülen maliyeti **~8 ms** — yani 120 Hz bütçesinin tamamı. Görünmeyeni
/// çizmemek, görünenin görüntüsünü değiştirmiyor.
class WorldGrid extends PositionComponent {
  WorldGrid({GameWorld world = GameWorld.standard, this.cell = 400})
    : _world = world {
    priority = -90;
  }

  final GameWorld _world;
  final double cell;

  // Kare başına tahsis yok: boyalar bir kez kurulur.
  final Paint _line = Paint()
    ..strokeWidth = 1
    ..color = const Color(0x0F3A6BFF);
  final Paint _major = Paint()
    ..strokeWidth = 1.6
    ..color = const Color(0x1A3A6BFF);
  final Paint _border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..color = const Color(0x553A8BFF)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  /// Kenarın bulanık maskesi bu kadar uzaktan görünür. Kamera bu bandın
  /// dışındaysa kenar hiç çizilmez — dev bir dikdörtgene uygulanan
  /// `MaskFilter.blur` karedeki en pahalı tek işlemdi.
  static const double _borderReach = 120;

  @override
  void render(Canvas canvas) {
    final bounds = _world.bounds;
    final view = visibleRect(canvas, _world).intersect(bounds);
    if (view.isEmpty) return;

    // Çizgiler görünür aralıkta ve görünür UZUNLUKTA. İkisi de gerekli:
    // ekran dışındaki çizgiyi atlamak kadar, görünen çizgiyi 8000 birim boyu
    // çizmemek de önemli.
    final first = (view.left / cell).floor();
    final last = (view.right / cell).ceil();
    for (var i = first; i <= last; i++) {
      final x = i * cell;
      if (x < 0 || x > bounds.width) continue;
      // Her beşinci çizgi kalın: ölçek hissi tek kalınlıkta ızgarada kaybolur.
      canvas.drawLine(
        Offset(x, view.top),
        Offset(x, view.bottom),
        i % 5 == 0 ? _major : _line,
      );
    }

    final firstRow = (view.top / cell).floor();
    final lastRow = (view.bottom / cell).ceil();
    for (var i = firstRow; i <= lastRow; i++) {
      final y = i * cell;
      if (y < 0 || y > bounds.height) continue;
      canvas.drawLine(
        Offset(view.left, y),
        Offset(view.right, y),
        i % 5 == 0 ? _major : _line,
      );
    }

    if (bounds.deflate(_borderReach).containsRect(view)) return;
    canvas.drawRect(bounds, _border);
  }
}

extension on Rect {
  bool containsRect(Rect other) =>
      other.left >= left &&
      other.top >= top &&
      other.right <= right &&
      other.bottom <= bottom;
}
