import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ── Deterministik değer gürültüsü ────────────────────────────────────────
// Saf ve kareden bağımsız (`Random` yok): aynı `time` daima aynı kareyi çizer.
// Bu sayede golden testler kararlı kalır ve efekt tekrar oynatılabilir.
double gHash(double n) {
  final s = sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

double gNoise(double x) {
  final i = x.floorToDouble();
  final f = x - i;
  final u = f * f * (3 - 2 * f);
  return (gHash(i) * (1 - u) + gHash(i + 1) * u) * 2 - 1;
}

/// Üç oktav — bir silueti kırmaya yetecek türbülans, gerçek fbm'in piksel
/// başına maliyeti olmadan.
/// Tohumlanmış tekil örnek — prosedürel geometriye (çatlak yürüyüşü, kıymık
/// boyları) dağılım vermek için.
double gRand(double seed, int i) => gHash(seed * 37.1 + i * 11.7);

double gFbm(double x) =>
    gNoise(x) * 0.55 +
    gNoise(x * 2.17 + 4.7) * 0.30 +
    gNoise(x * 4.63 + 11.9) * 0.15;

// ── Bloom ────────────────────────────────────────────────────────────────

/// [emissive]'i iki kez kompozit eder: bir kez bulanık-additive katmandan
/// (bloom), bir kez üstüne keskin.
///
/// Tüm geçiş için TEK katman. Sıcak çekirdeğin zırha ve arkaplana taşmasını
/// sağlayan adım budur — her şeklin kendi `MaskFilter`'ını taşıması yalnız o
/// şekli sisler, dışarı taşımaz.
///
/// [blurPass] KALİTE KADEMESİDİR ve multiplayer'ın gerektirdiği şeydir:
/// `saveLayer` + blur Skia/Impeller'daki en pahalı çift, ve tek gemide
/// bedava olan şey ekrandaki 40. gemide kare bütçesini yiyor. Kapatıldığında
/// keskin geçiş tek başına çizilir — gemi soluklaşır ama okunur kalır.
void bloom(
  Canvas canvas,
  Rect bounds,
  void Function() emissive, {
  double sigma = 5.0,
  int alpha = 104,
  bool blurPass = true,
}) {
  if (!blurPass) {
    emissive();
    return;
  }
  canvas.saveLayer(
    bounds,
    Paint()
      ..blendMode = BlendMode.plus
      ..color = Color.fromARGB(alpha, 255, 255, 255)
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
  );
  emissive();
  canvas.restore();
  emissive();
}
