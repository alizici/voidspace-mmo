import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/palette.dart';

/// HUD düğmelerinin ORTAK dili.
///
/// Bir süre üç ayrı düğme vardı: köşe çipleri (HANGAR, GALAKSİ), masaüstü
/// test düğmesi (İTKİ) ve savaş çubuğunun iki satırlı kutuları. Üçü de
/// "kenarlıklı dikdörtgen içinde büyük harf" idi ve yan yana gelince kaba
/// duruyordu: aynı ekranda üç farklı köşe yarıçapı, üç yazı boyu, sıfır
/// simge. Tek dil: hap biçimi, yarı saydam zemin, ince çizgi, solda bir glif,
/// sağda etiket (ve varsa altında değer). Dokunmatikte 44 piksel, masaüstünde
/// biraz daha kısa; ölçek dışında ikisi aynı.
enum HudGlif { mermi, roket, formasyon, hangar, galaksi, itki, hedef }

class HudPill extends StatelessWidget {
  const HudPill({
    super.key,
    required this.label,
    required this.glif,
    this.value,
    this.color = Palette.accent,
    this.active = false,
    this.compact = false,
    this.onTap,
  });

  final String label;

  /// Etiketin altındaki değer (`MR-2 · 95`); yoksa tek satır.
  final String? value;
  final HudGlif glif;
  final Color color;

  /// Açık panel ya da seçili durum: zemin ve çizgi renge döner.
  final bool active;

  /// Masaüstü: parmak yok, 36 piksel yeter.
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 36.0 : 44.0;
    final ink = onTap == null ? Palette.faint : Palette.ink;
    return GestureDetector(
      // HUD tıklaması ALTTAKİ oyuna sızmamalı: yoksa bir düğmeye basmak aynı
      // zamanda gemiye "oraya uç" emri verir.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : Palette.panel,
          border: Border.all(
            color: active ? color.withValues(alpha: 0.85) : Palette.line,
          ),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HudGlifIkonu(
              glif,
              color: active ? color : color.withValues(alpha: 0.85),
              size: value == null ? 13 : 14,
            ),
            const SizedBox(width: 8),
            if (value == null)
              Text(label, style: Palette.label(10).copyWith(color: ink))
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Palette.label(8).copyWith(letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Palette.mono(
                      11,
                      weight: FontWeight.w600,
                      color: active ? color : Palette.inkBright,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Seçim ŞERİDİ — bir çubuk düğmesinin üstünde açılan seçenek sırası.
///
/// Izgara değil şerit: yirmi formasyonu bir ızgaraya dökmek telefonda oyunun
/// ortasını kapatıyordu. Tek satır yatay kayıyor; genişlik ekrandan, çubuğun
/// iki yanındaki kumandalara dokunmayacak kadar.
class HudSecimSeridi extends StatelessWidget {
  const HudSecimSeridi({
    super.key,
    required this.baslik,
    required this.children,
    this.maxWidth = 560,
  });

  final String baslik;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Palette.panel,
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik, style: Palette.label(8).copyWith(letterSpacing: 1.6)),
          const SizedBox(height: 7),
          // Sağ kenarda SOLMA: kesik bir hap "bozuk" okunuyordu; solma,
          // devamı olduğunu söyleyen tek işaret. Solda yok — ilk seçenek
          // tam görünmeli.
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.9, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 28),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Şeritteki tek seçenek — küçük hap; seçili dolu, kapalı soluk.
class HudSecenek extends StatelessWidget {
  const HudSecenek({
    super.key,
    required this.label,
    required this.color,
    this.secili = false,
    this.etkin = true,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool secili;
  final bool etkin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metin = secili
        ? color
        : etkin
        ? Palette.ink
        : Palette.faint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: etkin && !secili ? onTap : null,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secili ? color.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
            color: secili
                ? color.withValues(alpha: 0.85)
                : etkin
                ? Palette.line
                : Palette.line.withValues(alpha: 0.08),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: Palette.mono(10, weight: FontWeight.w600, color: metin),
        ),
      ),
    );
  }
}

/// HUD glifi — yazı yerine küçük bir işaret, düğmeyi okumadan tanıtıyor.
class HudGlifIkonu extends StatelessWidget {
  const HudGlifIkonu(
    this.glif, {
    super.key,
    required this.color,
    this.size = 14,
  });

  final HudGlif glif;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GlifPainter(glif, color));
}

class _GlifPainter extends CustomPainter {
  const _GlifPainter(this.glif, this.color);

  final HudGlif glif;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.09)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    switch (glif) {
      case HudGlif.mermi:
        // Kapsül: mermi, sivri burun sağda.
        final r = s * 0.2;
        final govde = RRect.fromLTRBR(
          s * 0.08,
          c.dy - r,
          s * 0.7,
          c.dy + r,
          Radius.circular(r),
        );
        canvas.drawRRect(govde, fill);
        final burun = Path()
          ..moveTo(s * 0.68, c.dy - r)
          ..lineTo(s * 0.98, c.dy)
          ..lineTo(s * 0.68, c.dy + r)
          ..close();
        canvas.drawPath(burun, fill);
      case HudGlif.roket:
        // Roket: sivri burun sağda, kısa gövde, iki kanatçık arkada.
        final r = s * 0.16;
        final govde = RRect.fromLTRBR(
          s * 0.22,
          c.dy - r,
          s * 0.72,
          c.dy + r,
          Radius.circular(r),
        );
        canvas.drawRRect(govde, fill);
        final burun = Path()
          ..moveTo(s * 0.7, c.dy - r)
          ..lineTo(s * 0.98, c.dy)
          ..lineTo(s * 0.7, c.dy + r)
          ..close();
        canvas.drawPath(burun, fill);
        final kanat = Path()
          ..moveTo(s * 0.3, c.dy - r)
          ..lineTo(s * 0.08, c.dy - r * 2.1)
          ..lineTo(s * 0.18, c.dy)
          ..lineTo(s * 0.08, c.dy + r * 2.1)
          ..lineTo(s * 0.3, c.dy + r)
          ..close();
        canvas.drawPath(kanat, fill);
      case HudGlif.formasyon:
        // Üç droid, V düzeni.
        final r = s * 0.13;
        canvas.drawCircle(Offset(s * 0.2, s * 0.28), r, fill);
        canvas.drawCircle(Offset(s * 0.8, s * 0.28), r, fill);
        canvas.drawCircle(Offset(s * 0.5, s * 0.76), r, fill);
        canvas.drawLine(
          Offset(s * 0.2, s * 0.28),
          Offset(s * 0.5, s * 0.76),
          stroke..strokeWidth = 1,
        );
        canvas.drawLine(
          Offset(s * 0.8, s * 0.28),
          Offset(s * 0.5, s * 0.76),
          stroke,
        );
      case HudGlif.hangar:
        // Kemer çatı: hangar kapısı.
        final path = Path()
          ..moveTo(s * 0.12, s * 0.9)
          ..lineTo(s * 0.12, s * 0.5)
          ..arcToPoint(
            Offset(s * 0.88, s * 0.5),
            radius: Radius.circular(s * 0.38),
          )
          ..lineTo(s * 0.88, s * 0.9);
        canvas.drawPath(path, stroke);
        canvas.drawLine(
          Offset(s * 0.36, s * 0.9),
          Offset(s * 0.36, s * 0.62),
          stroke,
        );
        canvas.drawLine(
          Offset(s * 0.64, s * 0.9),
          Offset(s * 0.64, s * 0.62),
          stroke,
        );
      case HudGlif.galaksi:
        // Yörünge ve gezegen.
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-0.5);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 0.95,
            height: s * 0.42,
          ),
          stroke,
        );
        canvas.restore();
        canvas.drawCircle(c, s * 0.18, fill);
      case HudGlif.itki:
        // İki çevron yukarı: itki.
        for (final dy in [s * 0.38, s * 0.68]) {
          final path = Path()
            ..moveTo(s * 0.18, dy)
            ..lineTo(c.dx, dy - s * 0.26)
            ..lineTo(s * 0.82, dy);
          canvas.drawPath(path, stroke);
        }
      case HudGlif.hedef:
        // Nişangâh.
        canvas.drawCircle(c, s * 0.3, stroke);
        for (final (dx, dy) in [
          (1.0, 0.0),
          (-1.0, 0.0),
          (0.0, 1.0),
          (0.0, -1.0),
        ]) {
          canvas.drawLine(
            c + Offset(dx * s * 0.34, dy * s * 0.34),
            c + Offset(dx * s * 0.48, dy * s * 0.48),
            stroke,
          );
        }
        canvas.drawCircle(c, s * 0.06, fill);
    }
  }

  @override
  bool shouldRepaint(_GlifPainter old) =>
      old.glif != glif || old.color != color;
}
