import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'atlas_layout.dart';

/// Derleme zamanında pişirilmiş gemi atlası.
///
/// Bu sınıf artık bir PİŞİRİCİ değil, bir YÜKLEYİCİ. Pişirme `tool/` altında,
/// `app_icon.png` ile aynı desende yapılıyor — çünkü bloom geçişini yüzden
/// fazla kare için çalışma zamanında tekrarlamak telefonda saniyelerce süren
/// bir donma demekti.
///
/// [scale] cihaza göre değişiyor: atlas piksel oranı 3 olan bir ekran için
/// pişirildi, ama piksel oranı 2 olan bir Mac'in o çözünürlüğe ihtiyacı yok.
/// Kod çözerken küçültmek, dokuyu 29 MB'tan 13 MB'a indiriyor ve tek bir
/// pikselin keskinliğini kaybettirmiyor.
class ShipAtlas {
  ShipAtlas._(this.image, this.scale)
    : _engine = _table(AtlasLayout.engineCount, scale, (i) {
        final steps = AtlasLayout.engineThrustSteps;
        return AtlasLayout.engineFrame(i % steps, i ~/ steps);
      }),
      _hull = _table(AtlasLayout.hullCount, scale, (i) {
        final steps = AtlasLayout.hullThrustSteps;
        return AtlasLayout.hullFrame(i % steps, i ~/ steps);
      }),
      _shield = _table(AtlasLayout.shieldCount, scale, (i) {
        final steps = AtlasLayout.shieldStrengthSteps;
        return AtlasLayout.shieldFrame(i % steps, i ~/ steps);
      }),
      _emitter = _table(AtlasLayout.emitterCount, scale, (i) {
        final mounts = AtlasLayout.emitterMounts;
        return AtlasLayout.emitterFrame(i % mounts, i ~/ mounts);
      }),
      _alien = _table(AtlasLayout.alienLayers, scale, AtlasLayout.alienFrame),
      _siluet = _table(
        AtlasLayout.siluetSayisi,
        scale,
        AtlasLayout.siluetFrame,
      );

  /// Ölçeklenmiş kare dikdörtgenleri — ÖNCEDEN hesaplanmış.
  ///
  /// Kare yolunda `frame(...)` gemi başına dokuz kez çağrılıyor (iki gövde,
  /// iki motor, bir kalkan, beşe kadar silah) ve her çağrı iki `Rect`
  /// ayırıyordu: biri yerleşimin, biri ölçeklenmişin. Kırk gemide saniyede
  /// ~86.000 kısa ömürlü nesne, ve bu dosyanın var olma sebebiyle aynı sebep
  /// geçerli — Dart'ın çöp toplayıcısı duraklattığında duraklattığı şey kare
  /// döngüsü.
  ///
  /// Tablo 91 dikdörtgen ve atlasla birlikte bir kez kuruluyor.
  final List<Rect> _engine;
  final List<Rect> _hull;
  final List<Rect> _shield;
  final List<Rect> _emitter;
  final List<Rect> _alien;
  final List<Rect> _siluet;

  static List<Rect> _table(int count, double scale, Rect Function(int) of) => [
    for (var i = 0; i < count; i++)
      () {
        final r = of(i);
        return Rect.fromLTWH(
          r.left * scale,
          r.top * scale,
          r.width * scale,
          r.height * scale,
        );
      }(),
  ];

  final ui.Image image;

  /// Yüklenen dokunun yerleşim boyutuna oranı (≤ 1). Bütün kare
  /// dikdörtgenleri ve çapalar bununla ölçeklenir.
  final double scale;

  static const String assetPath = 'assets/ship_atlas.png';

  /// Süreç ömrü boyunca TEK örnek.
  ///
  /// Atlas 29 MB'a kadar çıkan bir doku; ikinci bir oyun örneği (test, bölünmüş
  /// ekran, yeniden bağlanma) onu yeniden çözerse hem bellek iki katına çıkar
  /// hem de kod çözme yüz milisaniyeler sürer. Doku değişmez olduğu için
  /// paylaşmak güvenli.
  static final Map<int, Future<ShipAtlas>> _cache = {};

  /// Atlası cihazın gerçekten ihtiyaç duyduğu çözünürlükte yükler.
  ///
  /// [devicePixelRatio] ekranın piksel oranı; [zoom] kameranınki. İkisi
  /// birlikte "bir dünya birimi kaç fiziksel piksel eder" sorusunu cevaplıyor
  /// ve atlasın bundan daha keskin olmasının hiçbir faydası yok.
  static Future<ShipAtlas> load({
    required double devicePixelRatio,
    required double zoom,
  }) async {
    final needed = devicePixelRatio * zoom;
    // Asla BÜYÜTME: 1'i aşan bir oran, pişirilmiş çözünürlüğün üstünde
    // keskinlik ister ve bu mümkün değil.
    final ratio = (needed / AtlasLayout.pixelsPerWorldUnit).clamp(0.25, 1.0);

    final target = (AtlasLayout.imageSize.width * ratio).round();
    return _cache.putIfAbsent(target, () => _decode(target));
  }

  static Future<ShipAtlas> _decode(int target) async {
    final data = await rootBundle.load(assetPath);

    // `ui.instantiateImageCodec` DEĞİL: o API'nin `targetWidth` parametresi
    // her arka uçta desteklenmiyor ve desteklenmediğinde sessizce takılıyor.
    // `ImageDescriptor` güncel yol ve ölçekli kod çözmeyi her yerde aynı
    // şekilde yapıyor.
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      data.buffer.asUint8List(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final codec = await descriptor.instantiateCodec(targetWidth: target);
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    // Gerçek ölçek, istenen değil: kod çözücü tam sayıya yuvarlıyor ve
    // yuvarlama hatası kare dikdörtgenlerini kaydırırdı.
    return ShipAtlas._(
      frame.image,
      frame.image.width / AtlasLayout.imageSize.width,
    );
  }

  Rect engineFrame(int thrustStep, int phase) =>
      _engine[phase * AtlasLayout.engineThrustSteps + thrustStep];

  Rect hullFrame(int thrustStep, int phase) =>
      _hull[phase * AtlasLayout.hullThrustSteps + thrustStep];

  Rect shieldFrame(int strengthStep, int phase) =>
      _shield[phase * AtlasLayout.shieldStrengthSteps + strengthStep];

  Rect alienFrame(int layer) => _alien[layer];

  /// [tasarim] numaralı gövde silüeti (0..6).
  ///
  /// Sınır dışı bir kademe BAŞLANGIÇ gövdesine düşüyor. Sunucudan gelen bir
  /// bayta güvenip diziyi taşırmak, bozuk tek bir çerçevenin oyunu
  /// çökertmesi demekti.
  Rect siluetFrame(int tasarim) =>
      _siluet[tasarim.clamp(0, AtlasLayout.siluetSayisi - 1)];

  Rect emitterFrame(int mount, int phase) =>
      _emitter[phase * AtlasLayout.emitterMounts + mount];

  /// Çapalar da ÖNCEDEN: kare yolunda dörtgen başına okunuyorlar ve
  /// `Offset * double` her seferinde yeni bir nesne demek.
  late final Offset engineAnchor = AtlasLayout.engineAnchor * scale;
  late final Offset hullAnchor = AtlasLayout.hullAnchor * scale;
  late final Offset shieldAnchor = AtlasLayout.shieldAnchor * scale;
  late final Offset alienAnchor = AtlasLayout.alienAnchor * scale;
  late final Offset emitterAnchor = AtlasLayout.emitterAnchor * scale;

  /// Atlas pikselinden dünya birimine ölçek.
  late final double worldScale = 1 / (AtlasLayout.pixelsPerWorldUnit * scale);

  /// Kasıtlı olarak YOK: atlas süreç ömrü boyunca yaşar ve paylaşılır.
  /// Bir sahibin onu serbest bırakması, diğerlerinin dokusunu çalardı.
}
