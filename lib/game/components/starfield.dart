import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:voidspace_core/voidspace_core.dart';

import '../world_geometry.dart';

/// Uzay zemini: yıldızlar + birkaç nebula bulutu.
///
/// Tamamen deterministik (hash tabanlı, `Random` yok) ve [ui.Picture]'lara
/// kaydedilir — her karede binlerce `Offset`/`Paint` yeniden üretmek yerine.
///
/// **KAROLU**, ve bu bir mikro-optimizasyon değil ölçülmüş bir zorunluluktu.
/// `ui.Picture` bir raster DEĞİL görüntüleme listesidir: `drawPicture` o
/// listeyi her karede yeniden oynatır. Tek parça hâlinde bu, kare başına 3260
/// `drawCircle` demekti ve tarayıcıda ölçülen maliyeti **~8 ms** — yani 120 Hz
/// bütçesinin tamamı, tek bir arka plan için.
///
/// Dünya [_cols]×[_rows] karoya bölününce her karede yalnız kameranın gördüğü
/// 2-4 karo oynatılıyor: aynı piksel, onda bir işlem. Görünür alan
/// `canvas.getLocalClipBounds()` ile okunuyor — bileşenin kamerayı ya da oyunu
/// tanımasına gerek yok, tuval zaten dönüşümü taşıyor.
class Starfield extends PositionComponent {
  Starfield({GameWorld world = GameWorld.standard}) : _world = world {
    priority = -100;
  }

  /// Karo sayısı. Daha çok karo = kare başına daha az işlem, ama daha çok
  /// `drawPicture` çağrısı ve daha çok bellek. 6×4, 12000×8000 dünyada
  /// 2000×2000'lik karolar veriyor: görüş alanı (~1300 birim) daima en fazla
  /// dört karoya değiyor.
  static const int _cols = 6;
  static const int _rows = 4;

  final GameWorld _world;

  /// Karolar TEMBEL pişirilir: açılışta 24 karoyu birden kaydetmek, ilk
  /// karede görünür bir donma demek olurdu.
  final List<ui.Picture?> _tiles = List<ui.Picture?>.filled(
    _cols * _rows,
    null,
  );
  ui.Picture? _clouds;

  static double _hash(int n) {
    final s = sin(n * 127.1 + 311.7) * 43758.5453;
    return s - s.floorToDouble();
  }

  Rect get _tileSize =>
      Rect.fromLTWH(0, 0, _world.width / _cols, _world.height / _rows);

  /// Nebula: birkaç büyük, düşük opaklıklı leke. Yıldız alanına derinlik ve
  /// renk verir; onsuz zemin düz siyah bir tuval gibi okunur.
  ///
  /// Karolanmıyor: dört tane var ve her biri karo sınırlarını aşacak kadar
  /// büyük. Dört işlem, ölçülemeyecek kadar ucuz.
  ui.Picture _bakeClouds() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _world.size;

    const clouds = [
      (0.22, 0.30, 2600.0, Color(0x141E4C8A)),
      (0.68, 0.22, 2200.0, Color(0x120E5F6E)),
      (0.46, 0.72, 3000.0, Color(0x12331C6B)),
      (0.86, 0.66, 1900.0, Color(0x101C4E7A)),
    ];
    for (final (fx, fy, radius, color) in clouds) {
      final centre = Offset(size.width * fx, size.height * fy);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(centre, radius, [
            color,
            color.withValues(alpha: 0),
          ]),
      );
    }
    return recorder.endRecording();
  }

  /// [index] numaralı karonun yıldızları.
  ///
  /// Tüm yıldız kümesi taranıp karoya düşenler seçiliyor: pişirme başına
  /// O(3260), karo başına BİR kez. Yıldızların üretimi deterministik olduğu
  /// için sonuç tek parça hâlindekiyle piksel piksel aynı.
  ui.Picture _bakeTile(int index) {
    final tile = _tileSize;
    final origin = Offset(
      (index % _cols) * tile.width,
      (index ~/ _cols) * tile.height,
    );
    final bounds = origin & tile.size;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _world.size;

    // Üç derinlik kademesi: küçük/soluk çoktur, büyük/parlak azdır.
    const tiers = [(2400, 0.9, 0.30), (700, 1.5, 0.55), (160, 2.4, 0.9)];
    var seed = 0;
    for (final (count, radius, alpha) in tiers) {
      final paint = Paint();
      for (var i = 0; i < count; i++) {
        seed++;
        final x = _hash(seed * 3) * size.width;
        final y = _hash(seed * 7 + 11) * size.height;
        // Kenardaki yıldız iki karoya da düşmesin diye yarıçap payı YOK:
        // merkez hangi karodaysa oraya aittir. En fazla 2.4 birimlik bir
        // taşma olur ve karo komşusuyla zaten yan yana çiziliyor.
        if (!bounds.contains(Offset(x, y))) continue;
        // Hafif renk sapması — hepsi bembeyaz olursa alan steril görünür.
        final warm = _hash(seed * 13 + 5);
        paint.color = Color.lerp(
          const Color(0xFFDCE8FF),
          const Color(0xFFFFE6C8),
          warm,
        )!.withValues(alpha: alpha * (0.55 + _hash(seed * 17) * 0.45));
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final view = visibleRect(canvas, _world);

    canvas
      ..drawRect(view, Paint()..color = const Color(0xFF03050C))
      ..drawPicture(_clouds ??= _bakeClouds());

    final tile = _tileSize;
    final firstCol = (view.left / tile.width).floor().clamp(0, _cols - 1);
    final lastCol = (view.right / tile.width).floor().clamp(0, _cols - 1);
    final firstRow = (view.top / tile.height).floor().clamp(0, _rows - 1);
    final lastRow = (view.bottom / tile.height).floor().clamp(0, _rows - 1);

    for (var r = firstRow; r <= lastRow; r++) {
      for (var c = firstCol; c <= lastCol; c++) {
        final index = r * _cols + c;
        canvas.drawPicture(_tiles[index] ??= _bakeTile(index));
      }
    }
  }
}
