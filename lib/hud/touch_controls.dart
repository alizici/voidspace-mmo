import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil_kapsami.dart';
import '../dil/metin.dart';
import 'hud_dugmeleri.dart';

/// Sol başparmağın uçuş çubuğu.
///
/// Klavyenin karşılığı DEĞİL, dengi: `WASD` yalnız sekiz yön üretir, çubuk
/// sürekli bir eksen üretir. Protokol bunu zaten taşıyordu — girdi ekseni
/// `i8` olarak kodlanıyor ve klavye o aralığın yalnız üç değerini
/// kullanıyordu ("analog bir çubuk geldiğinde biçim değişmesin", bkz.
/// `ClientInput`). Çubuk o boşluğu dolduruyor.
///
/// Oyunu ya da ağı TANIMAZ; ekseni geri veriyor. Böylece bir tuvale ya da
/// sunucuya ihtiyaç duymadan test edilebiliyor.
class Joystick extends StatefulWidget {
  const Joystick({super.key, required this.onAxis, this.size = 136});

  /// Her değişimde çağrılır; bırakıldığında [Vec2.zero].
  final ValueChanged<Vec2> onAxis;

  final double size;

  /// Ölü bölge — yarıçapın oranı.
  ///
  /// Parmağın merkezde durması diye bir şey yok: bu eşik olmadan çubuk
  /// bırakılmış hâlde bile gemiyi sürüklüyor ve oyuncu "kendi kendine
  /// kayıyor" diyor.
  static const double deadZone = 0.14;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;

  double get _radius => widget.size / 2;

  void _drag(Offset local) {
    var delta = local - Offset(_radius, _radius);
    final length = delta.distance;
    // Çubuk halkanın DIŞINA çıkmaz; parmağın dışarı taşması yönü korur,
    // büyüklüğü tavanda tutar — fiziksel bir çubuğun yaptığı.
    if (length > _radius) delta = delta * (_radius / length);
    setState(() => _knob = delta);

    final magnitude = delta.distance / _radius;
    if (magnitude < Joystick.deadZone) {
      widget.onAxis(Vec2.zero);
      return;
    }
    // Yön korunur, büyüklük ölü bölgeden sonra 0..1'e YENİDEN yayılır —
    // aksi hâlde eşiği geçen ilk an gemi birden %14 hızla fırlıyor.
    final scaled = (magnitude - Joystick.deadZone) / (1 - Joystick.deadZone);
    final unit = delta / delta.distance;
    widget.onAxis(Vec2(unit.dx * scaled, unit.dy * scaled));
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onAxis(Vec2.zero);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    // `opaque`: parmağın pedin boş bir yerine değmesi de çubuğu tutmalı,
    // yoksa oyuncu ortayı ıskaladığında dokunuş oyuna geçip "oraya uç"
    // emrine dönüşüyor.
    behavior: HitTestBehavior.opaque,
    onPanStart: (d) => _drag(d.localPosition),
    onPanUpdate: (d) => _drag(d.localPosition),
    onPanEnd: (_) => _release(),
    onPanCancel: _release,
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: _JoystickPainter(_knob)),
    ),
  );
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter(this.knob);

  final Offset knob;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas
      ..drawCircle(centre, radius, Paint()..color = const Color(0x33060B16))
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Palette.line,
      )
      // Merkez işareti: parmağın nereye döneceğini söyler.
      ..drawCircle(
        centre,
        3,
        Paint()..color = Palette.inkDim.withValues(alpha: 0.5),
      );

    final at = centre + knob;
    canvas
      ..drawCircle(
        at,
        radius * 0.38,
        Paint()
          ..color = Palette.shield.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawCircle(
        at,
        radius * 0.3,
        Paint()..color = Palette.shield.withValues(alpha: 0.28),
      )
      ..drawCircle(
        at,
        radius * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Palette.shield,
      );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.knob != knob;
}

/// Sağ başparmağın yuvarlak eylem düğmesi.
class TouchAction extends StatelessWidget {
  const TouchAction({
    super.key,
    required this.label,
    required this.onTap,
    this.glif,
    this.tint = Palette.shield,
    this.active = false,
    this.size = 62,
  });

  final String label;
  final VoidCallback onTap;

  /// Etiketin üstündeki işaret — daire yazıdan önce şekliyle tanınsın.
  final HudGlif? glif;
  final Color tint;

  /// Basılı/etkin görünüm — hedef kilitliyken HEDEF düğmesi yanar.
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Zemin köşe haplarıyla AYNI: bir ekranda iki saydamlık, iki dil.
        color: active ? tint.withValues(alpha: 0.2) : Palette.panel,
        border: Border.all(
          color: active ? tint : Palette.line,
          width: active ? 1.6 : 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glif != null) ...[
            HudGlifIkonu(
              glif!,
              color: active ? tint : tint.withValues(alpha: 0.85),
              size: 18,
            ),
            const SizedBox(height: 3),
          ],
          Text(
            label,
            textAlign: TextAlign.center,
            style: Palette.label(
              9,
            ).copyWith(color: active ? tint : Palette.ink),
          ),
        ],
      ),
    ),
  );
}

/// Dikey ekranda gösterilen çevirme uyarısı.
///
/// **Neden bir perde ve neden yalnız bu.** Gerçek bir kilit yalnız yerel
/// uygulamada mümkün (`SystemChrome`, ve iOS/Android manifestoları). Tarayıcı
/// tarafında yön kilidi mobil Safari'de HİÇ yok; oyun bir bağlantıdan
/// açıldığında elde kalan tek dürüst araç bu perde.
///
/// Dikeyde oynanamaz olmasının sebebi ölçülebilir: görüş alanı 0.6 zoom'da
/// dikeyde ~670 birime düşüyor, silah menzili ise 1400 — oyuncu vurabildiği
/// hedefin yarısını göremiyor.
/// Çevirme işareti — dikey bir telefon ve üstünde dönüş yayı.
///
/// `Icons.*` DEĞİL ve bu kasıtlı: proje Material ikon fontunu paketlemiyor
/// (bkz. `pubspec.yaml`). Tek bir ikon için 1.6 MB font eklemek, oyunu bir
/// bağlantıdan açan oyuncuya ödetilecek bir bedel değil — üstelik font
/// gelmeyince ikon boş bir kutu olarak çiziliyor, ki tam olarak öyle oldu.
class _RotateGlyph extends CustomPainter {
  const _RotateGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    final tint = Palette.shield.withValues(alpha: 0.85);
    final body = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..color = tint;

    // Telefon: DİKEY duruyor, yani oyuncunun şu an tuttuğu hâl.
    final phone = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.62),
      width: 34,
      height: 54,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(phone, const Radius.circular(6)),
        body,
      )
      // Alt çizgi: hangi ucun aşağı olduğunu söyler.
      ..drawLine(
        Offset(phone.center.dx - 7, phone.bottom - 6),
        Offset(phone.center.dx + 7, phone.bottom - 6),
        body..strokeWidth = 1.6,
      );

    // Dönüş yayı ve ucundaki ok.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = tint;
    final orbit = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.62),
      width: 78,
      height: 66,
    );
    canvas.drawArc(orbit, math.pi * 1.08, math.pi * 0.72, false, arc);

    final tip = Offset(orbit.right - 6, orbit.center.dy - 20);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - 7, tip.dy - 4)
        ..lineTo(tip.dx + 1, tip.dy + 1)
        ..lineTo(tip.dx - 6, tip.dy + 7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = tint,
    );
  }

  @override
  bool shouldRepaint(_RotateGlyph old) => false;
}

class RotateHint extends StatelessWidget {
  const RotateHint({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xF203050C),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 96,
            height: 76,
            child: CustomPaint(painter: _RotateGlyph()),
          ),
          const SizedBox(height: 18),
          Text(
            Metin.cihaziYatayCevir(context.dil),
            style: Palette.label(13).copyWith(color: Palette.ink),
          ),
          const SizedBox(height: 8),
          Text(Metin.dikeyEkranUyarisi(context.dil), style: Palette.label()),
        ],
      ),
    ),
  );
}
