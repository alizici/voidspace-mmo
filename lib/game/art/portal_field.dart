import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// ═════════════════════════════════════════════════════════════════════════
// POLAR ALAN — geçit dokusunun çekirdeği
// ═════════════════════════════════════════════════════════════════════════
//
// **Kaynak.** Bu kütüphane voidspace2'nin `lib/game/render/portal_field.dart`
// dosyasından birebir taşındı. Yeniden yazılmadı ve yazılmamalı: keşifte
// onaylanan görüntü aynı tohumlara ve aynı interpolasyona bağlı, ve bir
// "temizleme" turu görüntüyü sessizce değiştirirdi.
//
// Gerçek-zamanlı VFX'te bu iş bir shader'da yapılır: polar koordinata geçilir,
// açı yarıçapa göre makaslanır (`θ + f(r)`), sonuç bir gürültü dokusundan
// örneklenir. Flutter'da fragment shader yok; aynı matematiği [portalField]
// bir POLAR MESH'in her köşesinde çalıştırıyor, ara pikselleri de
// `drawVertices` interpole ediyor. Yani "daire üstüne daire" değil, alan hesabı.
//
// DÖNGÜ DİKİŞSİZ: gürültü SARMALI bir kafeste tanımlı — θ ekseni bir turda,
// r ekseni bir tekrarda başa döner. Kaydırma tam sayı olduğu sürece son kare
// ilk kareye tam oturur; bake edilen kare şeridi bu yüzden zıplamadan döner.

/// Sarmalı polar değer gürültüsü. θ ekseni bir TURDA, r ekseni bir TEKRARDA
/// başa döner; bu yüzden tam sayı kaydırma dikişsizdir.
class PortalNoise {
  PortalNoise({this.sectors = 12, this.rings = 6, int seed = 7}) {
    final rnd = Random(seed);
    _v = Float32List(sectors * rings);
    for (var i = 0; i < _v.length; i++) {
      _v[i] = rnd.nextDouble();
    }
  }

  final int sectors;
  final int rings;
  late final Float32List _v;

  double _at(int ri, int si) =>
      _v[(ri % rings + rings) % rings * sectors +
          (si % sectors + sectors) % sectors];

  /// [turn] = θ (tur cinsinden), [rad] = r (tekrar cinsinden).
  double sample(double turn, double rad) {
    final x = turn * sectors, y = rad * rings;
    final xi = x.floor(), yi = y.floor();
    final fx = _smooth(x - xi), fy = _smooth(y - yi);
    final a = _at(yi, xi), b = _at(yi, xi + 1);
    final c = _at(yi + 1, xi), d = _at(yi + 1, xi + 1);
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy;
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);
}

/// Fraktal toplam — oktavlar iki katına çıkan kafeslerde, hepsi sarmalı.
class PortalFbm {
  PortalFbm({int octaves = 4, int seed = 7, this.gain = 0.5})
    : _layers = [
        for (var i = 0; i < octaves; i++)
          PortalNoise(
            sectors: 8 * (1 << i),
            rings: 4 * (1 << i),
            seed: seed * 131 + i * 17,
          ),
      ];

  final List<PortalNoise> _layers;
  final double gain;

  double sample(double turn, double rad) {
    var sum = 0.0, amp = 1.0, norm = 0.0;
    for (var i = 0; i < _layers.length; i++) {
      sum += _layers[i].sample(turn * (1 << i), rad * (1 << i)) * amp;
      norm += amp;
      amp *= gain;
    }
    return sum / norm;
  }
}

/// Polar alan çizici — shader'ın CPU karşılığı.
///
/// [shade] her köşede çağrılır: `n01` normalize yarıçap (0 merkez, 1 kenar),
/// `turn` açı (tur cinsinden, 0..1). Dönen değer o köşenin rengidir; ara
/// pikseller `drawVertices` tarafından interpole edilir.
///
/// [inner] merkezde bir delik bırakır (olay ufku ayrı çizilecekse).
void portalField(
  Canvas canvas, {
  required double radius,
  required Color Function(double n01, double turn) shade,
  int rings = 34,
  int sectors = 72,
  double inner = 0,
  BlendMode blend = BlendMode.plus,
}) {
  // DEJENERE ALAN: yarıçap [inner]'a eşit/altındaysa normalize etme
  // `(r-inner)/(radius-inner)` sıfıra bölünür, gürültü NaN alır ve
  // `PortalNoise.sample` içindeki `floor()` "Infinity or NaN toInt" ile
  // ÇÖKER. Bu çağrı sıfırdan büyüyen her efektte (yeteneğin ilk karesi,
  // kapanan portal) doğal olarak oluşur — çizecek bir şey yoksa sessizce çık.
  if (!(radius > inner) || rings <= 0 || sectors <= 0) return;

  final pos = Float32List(rings * sectors * 12);
  final col = Int32List(rings * sectors * 6);
  var p = 0, c = 0;

  double rAt(int i) => inner + (radius - inner) * (i / rings);

  for (var ri = 0; ri < rings; ri++) {
    final r0 = rAt(ri), r1 = rAt(ri + 1);
    final n0 = (r0 - inner) / (radius - inner);
    final n1 = (r1 - inner) / (radius - inner);
    for (var si = 0; si < sectors; si++) {
      final t0 = si / sectors, t1 = (si + 1) / sectors;
      final a0 = t0 * 2 * pi, a1 = t1 * 2 * pi;
      final ca0 = cos(a0), sa0 = sin(a0), ca1 = cos(a1), sa1 = sin(a1);

      final c00 = shade(n0, t0).toARGB32();
      final c01 = shade(n0, t1).toARGB32();
      final c10 = shade(n1, t0).toARGB32();
      final c11 = shade(n1, t1).toARGB32();

      void v(double r, double ca, double sa, int color) {
        pos[p++] = ca * r;
        pos[p++] = sa * r;
        col[c++] = color;
      }

      v(r0, ca0, sa0, c00);
      v(r0, ca1, sa1, c01);
      v(r1, ca0, sa0, c10);
      v(r1, ca1, sa1, c11);
      v(r1, ca0, sa0, c10);
      v(r0, ca1, sa1, c01);
    }
  }

  canvas.drawVertices(
    ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: col),
    blend,
    Paint(),
  );
}

/// HDR taklidi: katmanı bir kez BULANIK + toplamalı, bir kez NET çizer.
/// Gerçek bloom'un ucuz ama dürüst karşılığı — parlak yerler taşar, koyu
/// yerler taşmaz, yani değer aralığı korunur.
void bloom(
  Canvas canvas,
  Rect bounds,
  void Function(Canvas) draw, {
  double sigma = 14,
  double strength = 0.85,
}) {
  canvas.saveLayer(
    bounds,
    Paint()
      ..blendMode = BlendMode.plus
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
      ..colorFilter = ColorFilter.mode(
        const Color(0xFFFFFFFF).withValues(alpha: strength),
        BlendMode.modulate,
      ),
  );
  draw(canvas);
  canvas.restore();
  draw(canvas);
}

/// Kontrast eğrisi — shader'daki `pow(col, k)`. Ortayı bastırır, tepeyi
/// bırakır; bloom'a giren şey ancak böyle "sıcak" olur.
double contrast(double v, double k) => pow(v.clamp(0.0, 1.0), k).toDouble();

/// SIRTLI gürültü: `1-|2f-1|`. Düz fbm yumru verir, girdap ise FİLAMENT ister
/// — sırtlı hâli tepeleri keskin ince şeritlere çevirir. Anizotropi ile
/// birlikte (r'de yüksek, θ'da düşük frekans) şeritler açı boyunca uzar ve
/// twist onları spirale büker. Portal dokusunu "doku" yapan kombinasyon budur.
double ridged(double f) => 1 - (2 * f - 1).abs();

/// Aralık genişletme: gürültü 0.5 çevresinde toplanır; ham hâlini alfaya
/// vermek her şeyi gri yapar. Tabanı kesip tepeyi 1'e çeker.
double expand(double v, double lo, double hi) =>
    ((v - lo) / (hi - lo)).clamp(0.0, 1.0);

/// İki durak arası renk rampası + parlaklık (HDR yerine alfa taşırma).
Color ramp(Color cold, Color mid, Color hot, double v) {
  final x = v.clamp(0.0, 1.0);
  return x < 0.5
      ? Color.lerp(cold, mid, x * 2)!
      : Color.lerp(mid, hot, (x - 0.5) * 2)!;
}
