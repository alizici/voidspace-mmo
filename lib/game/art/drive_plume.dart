import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'heat_ramp.dart';
import 'vfx.dart';

// ── Egzoz pluması ────────────────────────────────────────────────────────

/// Gemi tasarım uzayında tek bir nozzle. [power] jetin TAMAMINI ölçekler —
/// boy, boğaz yarıçapı, düğüm aralığı ve parlaklık birlikte. Böylece bir
/// gövdenin sürücü dizisi yalnız geometriyle tarif edilir ve her jet kendi
/// içinde tutarlı kalır.
class PlumeJet {
  const PlumeJet(this.origin, {this.power = 1});
  final Offset origin;
  final double power;
}

/// Vakum tipi, eksik-genleşmiş (under-expanded) egzoz.
///
/// Gözün okuduğu sırayla yapısı:
///  * **zarf** — boğazın hemen ardında açılır, kuyruğa doğru çöker ve mesafeyle
///    artan türbülansla saçaklanır;
///  * **namlu-şok çekirdeği** — düğümlerin üzerine oturduğu dar sıcak omurga;
///  * **Mach elmasları** — düğüm ölçeği aşağı doğru doğrusal büyür, türbülanslı
///    kesme ise parlaklığı öldürür; gerçek bir plumanın üç-dört düğüm gösterip
///    yumuşamasının sebebi budur;
///  * **boğaz** — karedeki en parlak nokta, artı patlamış bir vurgunun mercekten
///    aldığı yatay çizgi.
///
/// Tamamı tek bir additive bloom katmanından geçer. [ramp] yakıttır: pluma
/// geometrisi gövdeden bağımsızdır, kimliği yalnız sıcaklık rampası taşır.
void paintPlume(
  Canvas canvas, {
  required double time,
  required double thrust,
  required List<PlumeJet> jets,
  required HeatRamp ramp,
  double length = 1,
  double bloomSigma = 6.0,
  int bloomAlpha = 118,
}) {
  final motion = thrust.clamp(0.0, 1.0).toDouble();
  final wake = motion * motion * (3 - 2 * motion); // smoothstep
  if (wake <= 0.01 || jets.isEmpty) return;

  // Sınır TAM GAZA göre hesaplanır ki itki değişirken katmanın boyu sabit
  // kalsın. Her kare yeniden boyutlanan bir `saveLayer`, görsel bir kazanç
  // sağlamadan raster önbelleğini çöpe atar.
  var l = double.infinity, r = -double.infinity;
  var t0 = double.infinity, b = -double.infinity;
  for (final jet in jets) {
    final reach = 14 * jet.power;
    final tail = 45 * jet.power * length;
    l = min(l, jet.origin.dx - reach);
    r = max(r, jet.origin.dx + reach);
    t0 = min(t0, jet.origin.dy - 10 * jet.power);
    b = max(b, jet.origin.dy + tail + 18);
  }
  final bounds = Rect.fromLTRB(l - 24, t0 - 24, r + 24, b + 24);

  bloom(
    canvas,
    bounds,
    () => _paintPlume(canvas, time, wake, jets, ramp, length),
    sigma: bloomSigma,
    alpha: bloomAlpha,
  );
}

void _paintPlume(
  Canvas canvas,
  double time,
  double wake,
  List<PlumeJet> jets,
  HeatRamp ramp,
  double lengthScale,
) {
  final flicker = 0.9 + 0.1 * sin(time * 31);
  var spanL = double.infinity, spanR = -double.infinity;
  var wash = -double.infinity;
  var washY = 0.0;

  for (final jet in jets) {
    final power = jet.power;
    final x = jet.origin.dx;
    final y0 = jet.origin.dy;
    final len = (11 + wake * 34) * power * lengthScale * flicker;
    final r0 = 4.0 * power;

    spanL = min(spanL, x);
    spanR = max(spanR, x);
    if (len > wash) {
      wash = len;
      washY = y0;
    }

    // Zarf tek bir eğri değil, örneklenerek kurulur: genleşme, kuyruk çöküşü
    // ve türbülans ayrı terimlerdir, böylece her biri tek başına ayarlanır.
    const steps = 18;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final flare = 0.42 + 0.95 * sin(t * pi * 0.7); // under-expansion
      final decay = pow(1 - t, 0.55).toDouble(); // tail collapse
      final turb = gFbm(t * 5.2 - time * 4.1 + x * 3.1) * t * t * 2.6 * wake;
      final rad = r0 * flare * (0.34 + 0.66 * decay) + turb * power;
      final y = y0 + t * len;
      left.add(Offset(x - rad, y));
      right.add(Offset(x + rad, y));
    }

    final shell = Path()..moveTo(left.first.dx, left.first.dy);
    for (var i = 1; i < left.length; i++) {
      shell.lineTo(left[i].dx, left[i].dy);
    }
    for (var i = right.length - 1; i >= 0; i--) {
      shell.lineTo(right[i].dx, right[i].dy);
    }
    shell.close();

    // Dış kabuk orta sıcaklıkta ve yarı saydam kalır; parlak olsaydı pluma
    // dolu bir koni gibi okunur ve değer bütçesinin tamamını yerdi.
    canvas.drawPath(
      shell,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(x, y0),
          Offset(x, y0 + len),
          [
            ramp.at(0.88, 0.75),
            ramp.at(0.74, 0.52),
            ramp.at(0.58, 0.26),
            ramp.at(0.40, 0.0),
          ],
          const [0, 0.22, 0.58, 1],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );

    // Namlu-şok çekirdeği: dar, sıcak ve kısa — Mach düğümlerinin üzerine
    // oturduğu parlak omurga.
    final coreLen = len * 0.62;
    canvas.drawPath(
      Path()
        ..moveTo(x - r0 * 0.5, y0)
        ..quadraticBezierTo(x, y0 + coreLen * 1.05, x + r0 * 0.5, y0)
        ..close(),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(x, y0),
          Offset(x, y0 + coreLen),
          [ramp.at(1.0, 0.95), ramp.at(0.88, 0.6), ramp.at(0.7, 0)],
          const [0, 0.42, 1],
        ),
    );

    // Mach elmasları.
    var distance = 3.0 * power;
    var gap = 5.0 * power * (0.55 + wake * 0.9);
    for (var k = 0; k < 5; k++) {
      final p = distance / len;
      if (p > 0.68) break;
      final w = r0 * (0.5 + 0.85 * p) * 1.6;
      final h = gap * 0.6;
      final bright = pow(1 - p / 0.68, 1.5).toDouble() * wake;
      final cy = y0 + distance;
      final node = Path()
        ..moveTo(x, cy - h)
        ..quadraticBezierTo(x + w, cy, x, cy + h)
        ..quadraticBezierTo(x - w, cy, x, cy - h)
        ..close();
      canvas
        ..drawPath(
          node,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = ramp.at(0.90, 0.62 * bright)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.9),
        )
        ..drawPath(
          node,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.45
            ..blendMode = BlendMode.plus
            ..color = ramp.at(0.97, 0.4 * bright),
        );
      distance += gap;
      gap *= 1.24;
    }

    // Boğaz: karedeki en parlak nokta, artı patlamış bir vurgunun mercekten
    // aldığı yatay çizgi.
    final throat = Offset(x, y0 + 1.2 * power);
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: throat,
          width: 26 * power * wake,
          height: 1.2 * power,
        ),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = ramp.at(0.94, 0.40 * wake)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
      )
      ..drawOval(
        Rect.fromCenter(
          center: throat,
          width: 4.4 * power,
          height: 3.4 * power,
        ),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = ramp.at(1.0, 0.9 * wake),
      );
  }

  // Çok nozzle'lı diziyi tek bir sürücü kütlesine bağlayan yumuşak yıkama.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset((spanL + spanR) / 2, washY + 3 + wash * 0.32),
      width: (spanR - spanL) + 16 + wake * 12,
      height: 12 + wash * 0.55,
    ),
    Paint()
      ..blendMode = BlendMode.plus
      ..color = ramp.at(0.52, 0.07 + wake * 0.09)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + wake * 5),
  );
}
