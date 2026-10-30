import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Kalkan kabuğunun ÇİZİMİ — durumdan bağımsız.
///
/// `ShieldBubble` bileşeninden ayrıldı, çünkü aynı çizimin iki müşterisi var:
/// canlı bileşen (kare başına, tam kalite) ve atlas pişirici (bir kez, sonra
/// `drawAtlas` ile onlarca gemiye). `art/` katmanının kuralı burada da geçerli
/// — bu dosya kalkanın KİMDEN geldiğini bilmez, yalnız nasıl göründüğünü.
///
/// Dört katman:
///  1. **Fresnel kenarı** — merkezde şeffaf, kenarda parlak. Bir küreyi diskten
///     ayıran tek şey budur.
///  2. **Altıgen kafes** — enerji alanı dili. SABİT: dönmüyor, çünkü darbe
///     gerçek hücreleri yakıyor ve dönen bir kafeste hangi hücrenin yanacağı
///     hesaplanamaz (kafes atlasta pişiyor, faz kareleri arasında dönüş
///     kayardı).
///  3. **Darbe** — [paintImpacts]; temas noktasından yayılan dalga cepheleri
///     hücreleri TEK TEK yakar.
///  4. **Zayıflama** — opaklık kalkan oranıyla ölçeklenir; yarım kalkan görsel
///     olarak da yarımdır.
abstract final class ShieldShell {
  static const Color tint = Color(0xFF6FE8FF);

  /// Krest rengi — hücrelerin sıcak ucu. Beyaz DEĞİL: kalkan camgöbeği
  /// kalmalı, yoksa ateşten ayrışmaz.
  static const Color crest = Color(0xFF9DF0FF);

  /// Altıgen hücre boyu — yarıçapın ~0.21'i.
  ///
  /// Oran eski projeden: orada 48 yarıçapa 10 birimlik hücre düşüyordu, yani
  /// kabuk boyunca ~28 hücre. Yoğunluk okunabilirliğin kendisi — daha ince bir
  /// kafes dalga cephesini tel örgüye, daha kabası çizgi filme çeviriyor.
  static const double latticeCell = 13.0;

  /// Bir darbenin ömrü (sn).
  static const double impactLife = 0.85;

  /// Dalga cephesinin kalınlığı ve hızı — ikisi de yarıçaptan türer, yani
  /// kabuk büyüdüğünde efekt aynı ORANDA kalır.
  static double _waveWidth(double radius) => radius * 0.4167;
  static double _waveSpeed(double radius) => radius * 2.8;

  static ui.Picture? _lattice;
  static double _latticeRadius = -1;

  /// Kafes hücrelerinin MERKEZLERİ — pişirilen kafesle birebir aynı formülden.
  ///
  /// İki liste ayrışırsa darbe, kafeste OLMAYAN hücreleri yakar ve efekt
  /// yüzeye yapıştırılmış ayrı bir katman gibi görünür.
  static List<Offset>? _cells;
  static double _cellsRadius = -1;
  static Path? _unitHex;

  /// Altıgen kafes sabit geometridir — bir kez pişirilip her karede döndürülür.
  static ui.Picture _bakeLattice(double radius) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const cell = latticeCell;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = tint.withValues(alpha: 0.5);

    canvas
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
      );
    final cols = (radius / (cell * 1.5)).ceil() + 1;
    final rows = (radius / (cell * sqrt(3))).ceil() + 1;
    for (var c = -cols; c <= cols; c++) {
      for (var r = -rows; r <= rows; r++) {
        final centre = Offset(
          c * cell * 1.5,
          (r + (c.isOdd ? 0.5 : 0.0)) * cell * sqrt(3),
        );
        final hex = Path();
        for (var k = 0; k < 6; k++) {
          final a = k * pi / 3;
          final p = centre + Offset(cos(a) * cell, sin(a) * cell);
          k == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(hex..close(), paint);
      }
    }
    canvas.restore();
    return recorder.endRecording();
  }

  /// Kabuğu orijine çizer.
  ///
  /// [glow] kafes katmanını (bir `saveLayer`) açıp kapatır. Atlas pişirilirken
  /// AÇIK olur — maliyeti bir kez ödenir, sonra onlarca gemi bedavaya alır.
  static void paint(
    Canvas canvas, {
    required double radius,
    required double strength,
    double flash = 0,
    double time = 0,
    bool glow = true,
  }) {
    if (strength <= 0.001 && flash <= 0.001) return;

    // Nefes: sabit duran bir kabuk arayüz kaplaması gibi okunur.
    final breath = 0.5 + 0.5 * sin(time * 1.9);
    final live = (strength + flash * 0.6).clamp(0.0, 1.0);
    final r = radius * (1 + flash * 0.05);

    // 1 · Fresnel: içi boş, kenarı dolu.
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            tint.withValues(alpha: 0),
            tint.withValues(alpha: 0.05 * live),
            tint.withValues(alpha: (0.23 + breath * 0.07) * live),
          ],
          const [0, 0.72, 1],
        ),
    );

    if (glow) {
      if (_lattice == null || _latticeRadius != radius) {
        _lattice = _bakeLattice(radius);
        _latticeRadius = radius;
      }
      canvas
        // 2 · Altıgen kafes — SABİT. Dönüş kaldırıldı: darbe gerçek hücreleri
        // yakıyor ve hizalanabilmesi için kafesin dünyada sabit durması şart.
        ..save()
        ..saveLayer(
          Rect.fromCircle(center: Offset.zero, radius: r),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = Colors.white.withValues(
              alpha: (0.11 + flash * 0.34) * live,
            ),
        )
        ..drawPicture(_lattice!)
        ..restore()
        ..restore();
    }

    // 3 · Kenar çizgisi: kabuğun sınırı.
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + flash * 1.6
        ..blendMode = BlendMode.plus
        ..color = tint.withValues(alpha: (0.38 + flash * 0.5) * live),
    );

    // 4 · Darbe halkası: dışa açılır ve söner.
    if (flash > 0.01) {
      final t = 1 - flash;
      canvas.drawCircle(
        Offset.zero,
        r * (1 + t * 0.22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * flash
          ..blendMode = BlendMode.plus
          ..color = Colors.white.withValues(alpha: 0.55 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + t * 6),
      );
    }
  }

  // ── Darbe ──────────────────────────────────────────────────────────────

  static final Paint _cellStroke = Paint()
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;
  static final Paint _cellFill = Paint()..blendMode = BlendMode.plus;
  static final Paint _bloomPaint = Paint()..blendMode = BlendMode.plus;
  static final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..blendMode = BlendMode.plus
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  /// Hücre parlaklığının çizim eşiği. Altındaki hücreler atlasın pişirdiği
  /// taban kafesten ayırt edilemiyor; çizmek boşuna dolgu.
  static const double _cellFloor = 0.02;

  /// Kabuğa inen vuruşlar — hepsi BİR ARADA.
  ///
  /// **Neden hepsi birden.** Her darbeyi ayrı çizmek kolay olurdu ve efektin
  /// yarısını kaybederdi: eski projede hücrenin parlaklığı BÜTÜN canlı
  /// darbelerin toplamı. İki cephe aynı hücrede kesiştiğinde orası beyaza
  /// yaklaşıyor — bir yaylımın beş mermisi kabukta girişim yapıyor ve
  /// gördüğün şey tek tek beş halka değil, tek bir enerji olayı.
  ///
  /// [hits] ÇAĞIRANA ait ve yeniden kullanılıyor; burada saklanmıyor.
  static void paintImpacts(
    Canvas canvas, {
    required double radius,
    required double strength,
    required List<ShieldHit> hits,
  }) {
    if (hits.isEmpty) return;
    final live = strength.clamp(0.0, 1.0);
    if (live <= 0.001) return;

    final cells = _cellsFor(radius);
    final hex = _unitHex!;
    final waveWidth = _waveWidth(radius);
    final waveSpeed = _waveSpeed(radius);

    canvas
      ..save()
      // Kırpma ŞART: cepheler kabuğun dışına taşarsa kalkan bir küre değil
      // bir sis bulutu gibi görünür.
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
      );

    // 1 · Hücre hücre yanma.
    for (final centre in cells) {
      var level = 0.0;
      for (final hit in hits) {
        final d = (centre - hit.at).distance;
        final fade = 1 - hit.age / impactLife;

        // Birincil ve DAHA YAVAŞ ikincil cephe. Tek halka bir arayüz
        // animasyonu gibi, iki halka bir malzeme gibi okunuyor.
        for (var k = 0; k < 2; k++) {
          final waveR =
              (hit.age - k * 0.13) * waveSpeed * (k == 0 ? 1.0 : 0.66);
          if (waveR < 0) continue;
          final band = (d - waveR).abs();
          if (band >= waveWidth) continue;
          level +=
              cos(band / waveWidth * (pi / 2)) * fade * (k == 0 ? 0.95 : 0.45);
        }

        // Temas noktasında ilk anların keskin çakması. Cepheler yola çıkana
        // kadar geçen boşluğu dolduran şey bu; olmadan darbe gecikmeli
        // başlıyormuş gibi duruyor.
        final origin = (1 - hit.age / 0.12).clamp(0.0, 1.0);
        if (origin > 0) {
          level += (1 - (d / (radius * 0.45)).clamp(0.0, 1.0)) * origin * 0.85;
        }
      }
      level = level.clamp(0.0, 1.0);
      if (level <= _cellFloor) continue;

      canvas
        ..save()
        ..translate(centre.dx, centre.dy);
      // Yanan hücre hafifçe BÜYÜR: kafes düz bir doku değil, gerilen bir yüzey.
      final pop = 1 + 0.2 * ((level - 0.3) / 0.7).clamp(0.0, 1.0);
      if (pop != 1) canvas.scale(pop);

      // Camgöbeği KALIR, beyaza kaçmaz: parlaklık additive alfadan ve daha
      // açık bir camgöbeği krestten gelir. Beyaz bu projede karneye bağlı ve
      // karne ateşin.
      _cellStroke
        ..color = Color.lerp(
          tint,
          crest,
          (level * 0.9).clamp(0.0, 1.0),
        )!.withValues(alpha: level * live)
        ..strokeWidth = 1 + level * 0.7;
      canvas.drawPath(hex, _cellStroke);
      if (level > 0.35) {
        _cellFill.color = crest.withValues(alpha: (level - 0.35) * 0.45 * live);
        canvas.drawPath(hex, _cellFill);
      }
      canvas.restore();
    }

    // 2 · Temas parlaması — vuruşun NEREDE olduğunu tek bakışta veren şey.
    //
    // TODO(perf): gradyan darbe başına kare başına kuruluyor. Aynı anda
    //   yaşayan darbe sayısı tavanlı ([ShieldHit.maxPerShield]) olduğu için
    //   ölçümde görünmüyor; boss odalarında alfa kovalarına göre önbelleğe
    //   alınacak.
    for (final hit in hits) {
      final fade = 1 - hit.age / impactLife;
      if (fade <= 0) continue;
      final gr = radius * 0.5;
      _bloomPaint.shader = ui.Gradient.radial(hit.at, gr, [
        crest.withValues(alpha: 0.5 * fade * live),
        crest.withValues(alpha: 0),
      ]);
      canvas.drawCircle(hit.at, gr, _bloomPaint);
    }
    _bloomPaint.shader = null;

    canvas.restore(); // kırpma

    // 3 · Kenar parlaması: enerji kabuğun TAMAMINA dağılır. Kırpmanın dışında,
    // çünkü sınırın kendisini çiziyor. Yalnız FAZLASI çizilir — taban kenar
    // zaten atlasta pişmiş durumda.
    var flare = 0.0;
    for (final hit in hits) {
      final f = (1 - hit.age * 2.5).clamp(0.0, 1.0);
      if (f > flare) flare = f;
    }
    if (flare <= 0.001) return;
    _rimPaint.color = tint.withValues(alpha: flare * 0.7 * live);
    canvas.drawCircle(Offset.zero, radius, _rimPaint);
  }

  /// [radius] için hücre merkezleri — bir kez kurulur.
  static List<Offset> _cellsFor(double radius) {
    if (_cells != null && _cellsRadius == radius) return _cells!;
    const cell = latticeCell;
    final cols = (radius / (cell * 1.5)).ceil() + 1;
    final rows = (radius / (cell * sqrt(3))).ceil() + 1;
    final list = <Offset>[];
    for (var c = -cols; c <= cols; c++) {
      for (var r = -rows; r <= rows; r++) {
        final centre = Offset(
          c * cell * 1.5,
          (r + (c.isOdd ? 0.5 : 0.0)) * cell * sqrt(3),
        );
        // Merkezi kabuğun dışında kalan hücre atılır; kenarda kalanlar
        // kırpmayla kesilir (eski projedeki kural).
        if (centre.distanceSquared > (radius - 1) * (radius - 1)) continue;
        list.add(centre);
      }
    }
    final hex = Path();
    for (var k = 0; k < 6; k++) {
      final a = k * pi / 3;
      final p = Offset(cos(a) * cell, sin(a) * cell);
      k == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    _unitHex = hex..close();
    _cellsRadius = radius;
    return _cells = list;
  }
}

/// Kabuğa inen TEK bir vuruş.
///
/// Konum kabuk merkezine göre YEREL: darbe ömrü boyunca gemi yol alıyor ve
/// dünya konumu saklansaydı halka gemiden ayrılıp arkasında asılı kalırdı.
class ShieldHit {
  ShieldHit(this.at);

  /// Aynı kabukta aynı anda yaşayabilecek darbe tavanı.
  ///
  /// Eski projedeki sayı. Hücre başına maliyet darbe sayısıyla doğrusal;
  /// tavan olmadan üst üste binen yaylımlar kare bütçesini yiyor. Sekiz zaten
  /// gözün ayırt edebildiğinden fazla.
  static const int maxPerShield = 8;

  /// Temas noktası — kabuk merkezine göre.
  final Offset at;

  /// Saniye. Çağıran ilerletir.
  double age = 0;
}
