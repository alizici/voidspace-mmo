import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Void Leviathan'ın sprite şeridi.
///
/// **Neden atlasa girmiyor.** `assets/ship_atlas.png` bir ÜRETİM çıktısı:
/// `tool/ship_atlas_test.dart` prosedürel sanatı pişiriyor ve depoda kökeni
/// bilinmeyen ikili dosya bırakmama kuralı böyle korunuyor. Leviathan ise
/// hazır çizilmiş bir varlık — üreteci yok, kaynağı `assets/
/// leviathan_strip.README.txt` içinde yazılı. Onu üretilmiş atlasa karıştırmak
/// iki farklı türden dosyayı tek bir "üretilmiştir" iddiasının altına
/// sokardı.
///
/// Ayrı doku olmasının ikinci sebebi ölçü: atlas zaten 2518×2863 ve mobil
/// GPU'ların 4096 tavanı gözetiliyor. 2048×256'lık bir şerit eklemek o payı
/// gereksiz yere yerdi.
///
/// Maliyeti tek bir fazladan çizim çağrısı — ve o çağrı, ekrandaki Leviathan
/// SAYISINDAN bağımsız.
class LeviathanSprite {
  const LeviathanSprite._(this.image, this.frameSize);

  final ui.Image image;

  /// Tek karenin kaynak boyu (piksel).
  final double frameSize;

  /// Şeritteki kare sayısı — `idle_hover` döngüsü.
  static const int frameCount = 8;

  /// Kaynak şeridin kare boyu.
  static const double sourceFrame = 256;

  /// Sprite'ın DÜNYA birimindeki genişliği.
  ///
  /// `AlienStats.leviathan.radius` 48, yani çap 96. Sprite'ın kendisi
  /// çerçevesini tam doldurmuyor (dokunaçların ucu kenara değiyor, gövde
  /// ortada), o yüzden çizim kutusu çarpma yarıçapından biraz büyük: 132.
  /// Eşitlemek, yaratığı gövde ölçüsünde göstermek olurdu — dokunaçlar
  /// görsel, gövde ise vurulan yer.
  static const double worldSize = 132;

  static const String assetPath = 'assets/leviathan_strip.png';

  static final Map<int, Future<LeviathanSprite>> _cache = {};

  /// Cihaz oranına göre çözülmüş şerit.
  ///
  /// Atlas ile aynı gerekçe: ekranda 132 birim kaplayan bir şeyi 256 piksel
  /// çözmek, düşük yoğunluklu bir ekranda boşa harcanan doku belleği.
  static Future<LeviathanSprite> load({
    required double devicePixelRatio,
    required double zoom,
  }) {
    final needed = devicePixelRatio * zoom * worldSize / sourceFrame;
    final ratio = needed.clamp(0.25, 1.0);
    final target = (sourceFrame * frameCount * ratio).round();
    return _cache.putIfAbsent(target, () => _decode(target));
  }

  static Future<LeviathanSprite> _decode(int targetWidth) async {
    final data = await rootBundle.load(assetPath);
    // `ImageDescriptor` yolu — bkz. `ShipAtlas._decode`: `instantiateImageCodec`
    // her arka uçta ölçekli çözmüyor ve desteklenmediğinde sessizce takılıyor.
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      data.buffer.asUint8List(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final codec = await descriptor.instantiateCodec(targetWidth: targetWidth);
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    // GERÇEK kare boyu, istenen değil: çözücü tam sayıya yuvarlıyor ve
    // yuvarlama hatası kare dikdörtgenlerini kaydırırdı.
    return LeviathanSprite._(frame.image, frame.image.width / frameCount);
  }

  /// [index] numaralı karenin kaynak dikdörtgeni.
  ui.Rect frame(int index) {
    final i = index % frameCount;
    return ui.Rect.fromLTWH(i * frameSize, 0, frameSize, frameSize);
  }

  /// Çizim ölçeği: kaynak pikselden dünya birimine.
  double get worldScale => worldSize / frameSize;

  /// Sprite'ın merkezi — dönüş ekseni.
  ui.Offset get anchor => ui.Offset(frameSize / 2, frameSize / 2);
}
