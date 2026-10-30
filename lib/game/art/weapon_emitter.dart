import 'dart:math';
import 'dart:ui';

/// Gemiden BAĞIMSIZ silah projektörü — çift raylı enerji topu.
///
/// Eski projeden gelen tasarım ve olduğu gibi geliyor: iki öne uzanan ray,
/// aralarında namluya doğru yürüyen enerji barları, gövdeye oturan zırhlı bir
/// kaide, nefes alan bir güç çekirdeği ve odaklanmış bir namlu merceği.
///
/// **Neden ayrı bir dosya.** Yuvanın hangi gövdeye takıldığıyla işi yok:
/// çağıran hardpoint'e taşır, ölçüyü verir, çizdirir. Aynı projektör her
/// gövdeye düşsün diye — ikinci gövde geldiğinde kopyalanacak bir çizim
/// olmamalı.
///
/// **Neden iki geçiş.** Bu projede kural şu: önce SOĞUK zırh, sonra bütün
/// sıcak öğeleri tek seferde taşıyan additive bloom geçişi. Eski proje
/// projektörü tek çağrıda çiziyordu; burada [paintFrame] (çelik) ve
/// [paintEmissive] (enerji) ayrıldı, böylece bobinler ve namlu merceği
/// geminin geri kalanıyla AYNI bloom'dan geçiyor. Tek çağrıda bıraksaydık ya
/// projektör bloom'suz kalırdı ya da yuva başına ayrı bir `saveLayer` gerekir,
/// ki beş yuva × kırk gemi bunu kare bütçesine yazardı.
///
/// Yerel uzayda çizilir: kaide orijinde, namlu **−y** yönünde.
abstract final class WeaponEmitter {
  static const Color _steelLight = Color(0xFF8A93A0);
  static const Color _steelMid = Color(0xFF39414D);
  static const Color _steelDark = Color(0xFF12161C);

  /// Varsayılan enerji rengi. Gövdenin lav kimliğinden KASTEN ayrı: silah bir
  /// donanım, zırh bir yüzey. Aynı renkte olsalardı projektör gövdeye
  /// kaynaşır ve gemide silah olduğu görülmezdi.
  static const Color accent = Color(0xFF22D3EE);

  /// Raylar arasında yürüyen enerji barı sayısı. Yüksek = daha ağır silah.
  static const int coils = 5;

  /// SOĞUK kısım: raylar + kaide. Zırhla birlikte çizilir.
  static void paintFrame(
    Canvas canvas, {
    required double length,
    required double width,
    Color accent = accent,
  }) {
    _rails(canvas, length, width / 2, accent);
    _breech(canvas, width / 2, accent);
  }

  /// SICAK kısım: aura, bobinler, çekirdek, namlu merceği. Bloom geçişinde.
  ///
  /// [time] (sn) bobinlerin yürüyüşünü ve çekirdeğin nefesini sürer.
  static void paintEmissive(
    Canvas canvas, {
    required double length,
    required double width,
    required double time,
    Color accent = accent,
  }) {
    final pulse = 0.8 + 0.2 * sin(time * 3);

    // Projektörün çevresine yayılan sönük enerji.
    canvas.drawCircle(
      Offset(0, -length * 0.4),
      length * 0.55,
      Paint()
        ..color = accent.withValues(alpha: 0.07 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, length * 0.18),
    );

    _energyCoils(canvas, length, width / 2, accent, time);
    _core(canvas, width / 2, accent, pulse);
    _muzzle(canvas, length, width, accent, time);
  }

  /// Namlu ağzının yerel konumu — ışının/merminin ÇIKTIĞI nokta.
  ///
  /// Çağıranın bunu elle hesaplaması, mermilerin bir gün namludan değil
  /// havadan çıkması demekti.
  static Offset muzzleOf(double length) => Offset(0, -length);

  // ── Soğuk ──────────────────────────────────────────────────────────────

  /// Namluya doğru hafifçe YAKINSAYAN iki diş. Paralel olsalardı bir kutu
  /// gibi okunurdu; yakınsama enerjiyi bir noktaya topluyor.
  static void _rails(Canvas canvas, double l, double hw, Color accent) {
    for (final s in const [-1.0, 1.0]) {
      final rail = Path()
        ..moveTo(s * hw * 0.66, -l * 0.27)
        ..lineTo(s * hw * 0.3, -l)
        ..lineTo(s * hw * 0.1, -l)
        ..lineTo(s * hw * 0.42, -l * 0.27)
        ..close();
      canvas
        ..drawPath(
          rail,
          Paint()
            ..shader = Gradient.linear(
              Offset(s * hw * 0.1, 0),
              Offset(s * hw * 0.66, 0),
              [_steelMid, _steelDark],
            ),
        )
        // Aksanla aydınlanan iç kenar: rayın hangi yüzünün enerjiye baktığını
        // söyleyen tek çizgi.
        ..drawLine(
          Offset(s * hw * 0.42, -l * 0.27),
          Offset(s * hw * 0.1, -l),
          Paint()
            ..strokeWidth = l * 0.034
            ..strokeCap = StrokeCap.round
            ..color = accent.withValues(alpha: 0.85),
        );
    }
  }

  /// Mount noktasını saran kompakt zırhlı kaide.
  static void _breech(Canvas canvas, double hw, Color accent) {
    final bw = hw * 0.62; // kaide ray açıklığından dar
    final h = hw * 0.9;
    final breech = Path()
      ..moveTo(0, h * 0.45)
      ..lineTo(bw, h * 0.17)
      ..lineTo(bw, -h * 0.55)
      ..lineTo(bw * 0.55, -h)
      ..lineTo(-bw * 0.55, -h)
      ..lineTo(-bw, -h * 0.55)
      ..lineTo(-bw, h * 0.17)
      ..close();
    canvas
      ..drawPath(
        breech,
        Paint()
          ..shader = Gradient.linear(
            Offset(-bw, -h * 0.55),
            Offset(bw, h * 0.17),
            [_steelLight, _steelDark],
          ),
      )
      ..drawPath(
        breech,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hw * 0.11
          ..strokeJoin = StrokeJoin.round
          ..color = accent.withValues(alpha: 0.75),
      );
  }

  // ── Sıcak ──────────────────────────────────────────────────────────────

  /// Raylar arasında namluya doğru YÜRÜYEN enerji barları. Silahın şarj
  /// olduğunu söyleyen şey bu; sabit çizgiler yalnız "var" der.
  static void _energyCoils(
    Canvas canvas,
    double l,
    double hw,
    Color accent,
    double time,
  ) {
    final march = (time * 0.5) % 1.0;
    final crest = Color.lerp(accent, const Color(0xFFFFFFFF), 0.4)!;
    for (var i = 0; i < coils; i++) {
      final t = ((i + 0.5) / coils + march) % 1.0; // 0 = kaide, 1 = namlu
      final y = -l * 0.27 - t * l * 0.73;
      // Raylar yakınsadığı için barlar da namluya doğru daralır.
      final railX = (0.42 - 0.32 * t) * hw;
      final glow = 0.5 + 0.5 * sin(time * 5 + i);
      canvas.drawLine(
        Offset(-railX, y),
        Offset(railX, y),
        Paint()
          ..strokeWidth = l * 0.053
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = crest.withValues(alpha: (0.55 + 0.45 * glow) * 0.62),
      );
    }
  }

  /// Kaidedeki nefes alan güç çekirdeği.
  ///
  /// Ölçü genişlikten TÜRETİLİR: eski projede sabit bir sayıydı çünkü bütün
  /// yuvalar aynı boydaydı. Omurga topu yan yuvalardan geniş olunca sabit
  /// çekirdek onun içinde kaybolur.
  static void _core(Canvas canvas, double hw, Color accent, double pulse) {
    final c = Offset(0, -hw * 0.33);
    final r = hw * 0.49 * pulse;
    canvas
      ..drawCircle(
        c,
        r * 2.2,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = accent.withValues(alpha: 0.32 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, hw * 0.44),
      )
      ..drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8),
      );
  }

  /// Rayların birleştiği yerdeki odaklanmış mercek — merminin doğduğu nokta.
  static void _muzzle(
    Canvas canvas,
    double l,
    double w,
    Color accent,
    double time,
  ) {
    final c = Offset(0, -l);
    final flare = w * 0.34 * (0.8 + 0.4 * sin(time * 4.2));
    canvas
      ..drawCircle(
        c,
        flare * 2.2,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = accent.withValues(alpha: 0.26)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.22),
      )
      ..drawCircle(
        c,
        flare,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = accent.withValues(alpha: 0.62),
      )
      ..drawCircle(
        c,
        flare * 0.5,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85),
      );
  }
}
