/// DROİD TASARIMLARI — on aile, altı görsel kademe (05.8).
///
/// Tasarım dili tek: güçlü geometrik silüet, tek metal, silüeti izleyen ince
/// aksan çizgisi, uçlarda ışık, merkezde mercek. Organik biçim yok, itici ve
/// alev yok — droid bir gemi değil, geminin yanında duran bir aparat.
///
/// **Kademe çizimi seçiyor, gücü değil (05.8).** L1 küçük çekirdek biçim,
/// L2 aksan kenarı, L3 tam gövde ve dikiş, L4 mercek, L5 ikinci geometri,
/// L6 enerji ve hareket. Güç eşyanın artı çarpanından geliyor; buradaki her
/// katman yalnız görünüş.
///
/// **Çeşit iki, tasarım on (05.8 s2).** Satın alınabilir iki droid var:
/// Hilal NOVA ile, Delta krediyle. Kalan sekiz tasarım merdivenden gelen
/// droidlerin görünüşü — rank değişince filo da değişiyor.
///
/// Yerel merkez (0,0), ileri yön −y: geminin çizimiyle aynı sözleşme.
/// Çağıran translate/rotate/scale eder, `size` yarıçap referansıdır.
///
/// Perf notu: her çağrı Paint/Path/Shader üretiyor (küçük alan, blur yok).
/// Gemide sabit duracaksa bir kez `PictureRecorder` → `ui.Image` pişirmek en
/// ucuzu — bkz. `ShipSwarm`ın atlas ölçümü.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';



/// Çizimi olan on tasarım — sanat katmanının kendi listesi.
///
/// Çekirdekteki `DroidModeli` ile AYNI SIRADA; eşleme filo bileşeninde
/// yapılıyor, çünkü sanat katmanı durum bilmez ve çekirdeği okumaz. Test
/// ikisinin uzunluğunu ve sırasını bağlıyor.
enum DroidCizimi {
  hilal,
  halka,
  delta,
  elmas,
  damla,
  pusula,
  cerceve,
  prizma,
  parantez,
  jiroskop,
}

/// Bir droid ailesinin çizici imzası.
typedef DroidBoyaci =
    void Function(
      Canvas canvas,
      double size,
      double time,
      int level,
      double opacity,
    );

/// Tek droid tasarımı: kimlik, vitrin rengi ve altı kademeli çizici.
class DroidArt {
  const DroidArt({
    required this.model,
    required this.ad,
    required this.accent,
    required DroidBoyaci boyaci,
    this.radius = 15,
  }) : _boyaci = boyaci;

  final DroidCizimi model;

  /// Oyuncunun gördüğü ad — katalogdaki tasarım adıyla aynı.
  final String ad;

  /// Arayüzde (liste, rozet, seçim çerçevesi) kullanılan vitrin rengi;
  /// çizimdeki enerji rengiyle aynı.
  final Color accent;

  final DroidBoyaci _boyaci;
  final double radius;

  /// Altı kademe — çekirdekteki `DroidSeviyesi.tavan` ile aynı; sanat onu
  /// okuyamaz, test eşitliyor.
  static const int maxLevel = 6;

  static int normalizeLevel(int level) => level.clamp(1, maxLevel);

  /// HİLAL — mor alaşım, iç kenarda aksan, uçlar arasında enerji yayı.
  /// NOVA ile alınan elit droidin görünüşü.
  static const hilal = DroidArt(
    model: DroidCizimi.hilal,
    ad: 'Hilal',
    accent: Color(0xFFA78BFA),
    boyaci: _paintCrescent,
  );

  /// HALKA — gunmetal tor, jant podları, dönen iç halka.
  static const halka = DroidArt(
    model: DroidCizimi.halka,
    ad: 'Halka',
    accent: Color(0xFFE879F9),
    boyaci: _paintTorus,
  );

  /// DELTA — karbon üçgen plaka, omurga enerjisi. Krediyle alınan ucuz
  /// droidin görünüşü.
  static const delta = DroidArt(
    model: DroidCizimi.delta,
    ad: 'Delta',
    accent: Color(0xFFF97316),
    boyaci: _paintDelta,
  );

  /// ELMAS — buz kristali rombus, iki faset, dikey enerji.
  static const elmas = DroidArt(
    model: DroidCizimi.elmas,
    ad: 'Elmas',
    accent: Color(0xFF67E8F9),
    boyaci: _paintRhombus,
  );

  /// DAMLA — yeşim damla plaka, omurga dikişi, uç ışığı.
  static const damla = DroidArt(
    model: DroidCizimi.damla,
    ad: 'Damla',
    accent: Color(0xFF4ADE80),
    boyaci: _paintDrop,
  );

  /// PUSULA — altın dört köşeli yıldız, ikincil uçlar, pusula halkası.
  static const pusula = DroidArt(
    model: DroidCizimi.pusula,
    ad: 'Pusula',
    accent: Color(0xFFFDE68A),
    boyaci: _paintCompass,
  );

  /// ÇERÇEVE — bakır içi boş altıgen, köşe ışıkları, ters dönen iç altıgen.
  static const cerceve = DroidArt(
    model: DroidCizimi.cerceve,
    ad: 'Çerçeve',
    accent: Color(0xFF34D399),
    boyaci: _paintHexFrame,
  );

  /// PRİZMA — kızıl içi boş üçgen, köşe ışıkları, dönen iç üçgen.
  static const prizma = DroidArt(
    model: DroidCizimi.prizma,
    ad: 'Prizma',
    accent: Color(0xFF60A5FA),
    boyaci: _paintPrism,
  );

  /// PARANTEZ — çelik iki yay, dört uç ışığı, dönen iç yaylar.
  static const parantez = DroidArt(
    model: DroidCizimi.parantez,
    ad: 'Parantez',
    accent: Color(0xFFF472B6),
    boyaci: _paintBracket,
  );

  /// JİROSKOP — çelik çekirdek, bir çember ve bir eğik halka.
  static const jiroskop = DroidArt(
    model: DroidCizimi.jiroskop,
    ad: 'Jiroskop',
    accent: Color(0xFFF2FBFF),
    boyaci: _paintGyro,
  );

  /// Katalog sırası [DroidCizimi] sırası; değiştirmek çekirdeği de bozar.
  static const List<DroidArt> hepsi = [
    hilal,
    halka,
    delta,
    elmas,
    damla,
    pusula,
    cerceve,
    prizma,
    parantez,
    jiroskop,
  ];

  static DroidArt of(DroidCizimi model) => hepsi[model.index];

  /// Çekirdeğin model indeksinden çizim; tanınmayan indeks ilk tasarım.
  static DroidArt ofIndex(int i) =>
      i >= 0 && i < hepsi.length ? hepsi[i] : hepsi.first;

  void draw(
    Canvas canvas, {
    double? size,
    double t = 0,
    int level = 1,
    double opacity = 1,
  }) => _boyaci(
    canvas,
    size ?? radius,
    t,
    normalizeLevel(level),
    opacity.clamp(0, 1),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Malzeme paletleri — her aile kendi metalini taşır.
// ═══════════════════════════════════════════════════════════════════════════

class _Pal {
  const _Pal(this.lit, this.mid, this.dark);
  final Color lit;
  final Color mid;
  final Color dark;
}

const _steel = _Pal(Color(0xFF9AA4B2), Color(0xFF4A525E), Color(0xFF11151C));
const _gun = _Pal(Color(0xFF7C8794), Color(0xFF3A414B), Color(0xFF0E1116));
const _copper = _Pal(Color(0xFFE8A07A), Color(0xFF9A4F30), Color(0xFF2E140B));
const _jade = _Pal(Color(0xFF8FD3B5), Color(0xFF3E8A67), Color(0xFF0F2A1E));
const _crimson = _Pal(Color(0xFFD46A6A), Color(0xFF7A2E2E), Color(0xFF240C0C));
const _gold = _Pal(Color(0xFFF3D27A), Color(0xFFA8802A), Color(0xFF3A2A0A));
const _violet = _Pal(Color(0xFFB8A5E6), Color(0xFF5F4A9E), Color(0xFF1B1233));
const _ice = _Pal(Color(0xFFDFF6FF), Color(0xFF8FC3DB), Color(0xFF1C3A4A));

// ═══════════════════════════════════════════════════════════════════════════
// Ortak fırçalar
// ═══════════════════════════════════════════════════════════════════════════

Color _a(Color c, double o) => c.withValues(alpha: (c.a * o).clamp(0.0, 1.0));

double _pulse(double t, [double phase = 0]) =>
    0.6 + 0.4 * math.sin(t * 3.2 + phase);

/// Görsel seviye → gövde ölçeği (L1 0.55 … L6 1.0).
double _grow(int lv) => 0.55 + (lv - 1) * 0.09;

Offset _pol(double angle, double r) =>
    Offset(math.cos(angle) * r, math.sin(angle) * r);

Path _pts(List<Offset> points) => Path()..addPolygon(points, true);

Path _rr(double cx, double cy, double w, double h, double radius) => Path()
  ..addRRect(RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
    Radius.circular(radius),
  ));

Path _circle(double r, [Offset at = Offset.zero]) =>
    Path()..addOval(Rect.fromCircle(center: at, radius: r));

/// Düzgün çokgen; `inner` verilirse yıldız (n uç, iç yarıçap inner).
Path _poly(
  int n,
  double r, {
  double rot = -math.pi / 2,
  Offset at = Offset.zero,
  double inner = 0,
}) {
  final p = Path();
  final total = inner > 0 ? n * 2 : n;
  for (var i = 0; i < total; i++) {
    final rr = (inner > 0 && i.isOdd) ? inner : r;
    final pt = at + _pol(rot + i / total * 2 * math.pi, rr);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// İçi boş çokgen (çerçeve).
Path _polyRing(int n, double rOut, double rIn, {double rot = -math.pi / 2}) =>
    Path.combine(ui.PathOperation.difference, _poly(n, rOut, rot: rot),
        _poly(n, rIn, rot: rot));

/// İçi boş daire.
Path _annulus(double rOut, double rIn) =>
    Path.combine(ui.PathOperation.difference, _circle(rOut), _circle(rIn));

Path _line(Offset a, Offset b) => Path()
  ..moveTo(a.dx, a.dy)
  ..lineTo(b.dx, b.dy);

void _rot(Canvas c, double angle, void Function() body) {
  c.save();
  c.rotate(angle);
  body();
  c.restore();
}

/// Metal plaka: sol-üstten aydınlanan gradyan + koyu kontur + jant ışığı
/// + (rim verilirse) sağ-alttan sızan aksan renkli kenar ışığı.
void _plate(
  Canvas c,
  Path p,
  _Pal pal,
  double op, {
  double stroke = 0.9,
  Offset? from,
  Offset? to,
  Color? rim,
}) {
  final b = p.getBounds();
  final f = from ?? b.topLeft;
  final e = to ?? b.bottomRight;
  c.drawPath(
    p,
    Paint()
      ..shader = ui.Gradient.linear(
        f,
        e,
        [_a(pal.lit, op), _a(pal.mid, op), _a(pal.dark, op)],
        const [0.0, 0.5, 1.0],
      ),
  );
  c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = _a(pal.dark, 0.9 * op),
  );
  c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.6
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        f,
        e,
        [_a(pal.lit, 0.85 * op), _a(pal.lit, 0)],
        const [0.0, 0.6],
      ),
  );
  if (rim != null) {
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.8
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(
          e,
          f,
          [_a(rim, 0.6 * op), _a(rim, 0)],
          const [0.0, 0.55],
        ),
    );
  }
}

/// Küresel metal gövde (radyal aydınlatma).
void _orbFill(Canvas c, Offset at, double r, _Pal pal, double op, {Color? rim}) {
  c.drawCircle(
    at,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        at + Offset(-r * 0.35, -r * 0.35),
        r * 1.35,
        [_a(pal.lit, op), _a(pal.mid, op), _a(pal.dark, op)],
        const [0.0, 0.45, 1.0],
      ),
  );
  c.drawCircle(
    at,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _a(pal.dark, 0.9 * op),
  );
  if (rim != null) {
    c.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = ui.Gradient.linear(
          at + Offset(r, r),
          at + Offset(-r, -r),
          [_a(rim, 0.6 * op), _a(rim, 0)],
          const [0.0, 0.5],
        ),
    );
  }
}

/// Yumuşak ışık halesi (blur yerine radyal gradyan — Impeller'da ucuz).
void _glow(Canvas c, Offset at, double r, Color col, double op) {
  if (op <= 0 || r <= 0) return;
  c.drawCircle(
    at,
    r,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(at, r, [_a(col, op), _a(col, 0)]),
  );
}

/// Beyaz-sıcak enerji noktası.
void _hot(Canvas c, Offset at, double r, Color col, double op, double pulse) {
  _glow(c, at, r * 2.6, col, 0.55 * pulse * op);
  c.drawCircle(at, r, Paint()..color = _a(col, op));
  c.drawCircle(at, r * 0.5, Paint()..color = _a(Colors.white, 0.95 * op));
}

/// Cam mercek.
void _lens(Canvas c, Offset at, double r, Color col, double op, double pulse) {
  _glow(c, at, r * 2.2, col, 0.5 * pulse * op);
  final dark = Color.lerp(col, Colors.black, 0.6)!;
  c.drawCircle(
    at,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        at + Offset(-r * 0.3, -r * 0.3),
        r * 1.15,
        [_a(Colors.white, op), _a(col, op), _a(dark, op)],
        const [0.0, 0.45, 1.0],
      ),
  );
  c.drawCircle(
    at,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _a(dark, 0.9 * op),
  );
  c.drawCircle(
    at + Offset(-r * 0.35, -r * 0.35),
    r * 0.2,
    Paint()..color = _a(Colors.white, 0.95 * op),
  );
}

/// Merkez: L4'ten sonra mercek, öncesinde sıcak nokta.
void _core(Canvas c, Offset at, double r, Color ac, double op, double p, int lv) {
  if (lv >= 4) {
    _lens(c, at, r, ac, op, p);
  } else {
    _hot(c, at, r * 0.8, ac, op, p);
  }
}

void _seam(Canvas c, Offset a, Offset b, Color col, double op, [double w = 0.6]) {
  c.drawLine(
    a,
    b,
    Paint()
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = _a(col, op),
  );
}

void _stroke(Canvas c, Path p, double w, Color col, double op,
    {BlendMode blend = BlendMode.srcOver}) {
  c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = blend
      ..color = _a(col, op),
  );
}

void _ring(Canvas c, Offset at, double r, double w, Color col, double op) {
  c.drawCircle(
    at,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = _a(col, op),
  );
}

/// Perçin (yalnız birkaç ailede, düğüm noktası olarak).
void _bolt(Canvas c, Offset at, double r, _Pal pal, double op) {
  c.drawCircle(at, r, Paint()..color = _a(pal.dark, op));
  c.drawCircle(
    at + Offset(-r * 0.25, -r * 0.25),
    r * 0.55,
    Paint()..color = _a(pal.lit, 0.9 * op),
  );
}

/// Koyu + açık iki katlı çubuk (jant teli, ince kol).
void _strut(Canvas c, Path p, double w, _Pal pal, double op, [Color? lit]) {
  _stroke(c, p, w, pal.dark, op);
  _stroke(c, p, w * 0.45, lit ?? pal.lit, 0.85 * op);
}

/// Silüeti izleyen ince aksan çizgisi (Hilal'in iç kenarı gibi).
void _edge(Canvas c, Path p, Color ac, double op, double w, {bool glow = false}) {
  if (glow) _stroke(c, p, w * 3, ac, 0.25 * op, blend: BlendMode.plus);
  _stroke(c, p, w, ac, 0.75 * op);
}

/// İnce metal bant/halka: koyu taban + açık şerit + aksan çizgisi.
void _band(Canvas c, Path p, _Pal pal, Color ac, double w, double op) {
  _stroke(c, p, w, pal.dark, op);
  _stroke(c, p, w * 0.5, pal.lit, 0.9 * op);
  _stroke(c, p, w * 0.16, ac, 0.85 * op);
}

/// Enerji çizgisi: kalın soluk plus-katman + ince parlak öz.
void _energy(Canvas c, Path p, Color ac, double w, double op, double pulse) {
  _stroke(c, p, w * 3.2, ac, 0.3 * pulse * op, blend: BlendMode.plus);
  _stroke(c, p, w, Color.lerp(ac, Colors.white, 0.5)!, 0.9 * op);
}

/// Parçanın altına düşen sert gölge (derinlik katmanı).
void _shadow(Canvas c, Path p, double dy, double op) {
  c.save();
  c.translate(0, dy);
  c.drawPath(p, Paint()..color = _a(Colors.black, 0.35 * op));
  c.restore();
}

/// Boyalı yüzey üst parlaması.
void _sheen(Canvas c, Path p, Offset from, Offset to, double op) {
  c.save();
  c.clipPath(p);
  c.drawPath(
    p,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(
        from,
        to,
        [_a(Colors.white, 0.22 * op), _a(Colors.white, 0)],
      ),
  );
  c.restore();
}

/// Bir silüetin büyütülmüş ince çerçevesi (L5 "ikinci geometri").
void _frame(Canvas c, Path p, double scale, _Pal pal, Color ac, double w, double op) {
  c.save();
  c.scale(scale);
  _band(c, p, pal, ac, w / scale, op);
  c.restore();
}

// ═══════════════════════════════════════════════════════════════════════════
// 1 · HİLAL — mor alaşım hilal, iç kenarda aksan, uçlar arasında enerji yayı.
// ═══════════════════════════════════════════════════════════════════════════
void _paintCrescent(Canvas c, double size, double t, int lv, double op) {
  const pal = _violet;
  const ac = Color(0xFFA78BFA);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final k = lv >= 2 ? 0.8 : 0.88;
  const d = 0.35;
  final ty = (k * k - 1 - d * d) / (2 * d);
  final tx = math.sqrt(math.max(0.0, 1 - ty * ty));

  final outer = _circle(s);
  final inner = _circle(s * k, Offset(0, -s * d));
  final cres = Path.combine(ui.PathOperation.difference, outer, inner);

  if (lv >= 6) {
    final arc = Path()
      ..moveTo(-tx * s, ty * s)
      ..quadraticBezierTo(0, -s * 1.4, tx * s, ty * s);
    _stroke(c, arc, s * 0.2, ac, 0.35 * p * op, blend: BlendMode.plus);
    _stroke(c, arc, s * 0.045, Color.lerp(ac, Colors.white, 0.6)!, 0.9 * op);
  }
  _shadow(c, cres, s * 0.05, op);
  _plate(c, cres, pal, op, from: Offset(-s, -s), to: Offset(s, s), rim: ac);
  if (lv >= 3) {
    c.save();
    c.clipPath(cres);
    _ring(c, Offset(0, -s * d), s * k, s * 0.07, ac, 0.75 * op);
    _ring(c, Offset.zero, s * 0.86, 0.6, pal.dark, 0.6 * op);
    for (var i = -3; i <= 3; i++) {
      final a = math.pi / 2 + i * 0.36;
      _seam(c, _pol(a, s * 0.78), _pol(a, s * 1.0), pal.dark, 0.5 * op, 0.5);
      if (i.isEven) _bolt(c, _pol(a, s * 0.92), s * 0.04, pal, op);
    }
    c.restore();
    _sheen(c, cres, Offset(-s, -s * 0.2), Offset(0, s), op);
    final hubR = s * 0.36;
    _orbFill(c, Offset(0, s * 0.4), hubR, pal, op);
    _ring(c, Offset(0, s * 0.4), hubR * 0.78, 0.6, pal.dark, 0.6 * op);
  }
  if (lv >= 5) {
    for (final m in const [-1.0, 1.0]) {
      _hot(c, Offset(m * tx * s, ty * s), s * 0.09, ac, op, p);
    }
  }
  if (lv >= 4) {
    _lens(c, Offset(0, s * 0.4), s * 0.2, ac, op, p);
  } else {
    _hot(c, Offset(0, s * 0.32), s * 0.15, ac, op, p);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2 · HALKA — gunmetal tor, jant podları, üç tel, dönen iç halka.
// ═══════════════════════════════════════════════════════════════════════════
void _paintTorus(Canvas c, double size, double t, int lv, double op) {
  const pal = _gun;
  const ac = Color(0xFFE879F9);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final rad = lv >= 3 ? s * 1.0 : (lv == 2 ? s * 0.85 : s * 0.62);
  final wid = lv >= 3 ? s * 0.32 : s * 0.24;

  final ring = _annulus(rad + wid / 2, rad - wid / 2);
  _shadow(c, ring, s * 0.05, op);
  _plate(c, ring, pal, op, from: Offset(-rad, -rad), to: Offset(rad, rad), rim: ac);
  _ring(c, Offset.zero, rad, 0.5, pal.dark, 0.5 * op);
  if (lv == 1) {
    for (var i = 0; i < 3; i++) {
      _bolt(c, _pol(-math.pi / 2 + i * 2 * math.pi / 3, rad), s * 0.06, pal, op);
    }
  }
  _sheen(c, ring, Offset(-rad, -rad), Offset(0, 0), op);
  final pods = lv >= 5 ? 6 : (lv >= 3 ? 3 : 0);
  for (var i = 0; i < pods; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / pods;
    final at = _pol(a, rad);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(a);
    final pod = _rr(0, 0, s * 0.36, s * 0.24, s * 0.06);
    _plate(c, pod, pal, op);
    _seam(c, Offset(-s * 0.1, 0), Offset(s * 0.1, 0), pal.dark, 0.5 * op, 0.5);
    c.restore();
    if (lv >= 6) {
      _hot(c, _pol(a, rad + wid * 0.6), s * 0.05, ac, op, p);
    } else {
      _bolt(c, at, s * 0.045, pal, op);
    }
  }
  if (lv >= 2) {
    const spokes = 3;
    for (var i = 0; i < spokes; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / spokes + (lv >= 6 ? t * 0.5 : 0);
      _strut(c, _line(_pol(a, s * 0.2), _pol(a, rad - wid / 2)), s * 0.11, pal, op, lv >= 6 ? ac : null);
    }
    _orbFill(c, Offset.zero, s * 0.3, pal, op);
  }
  if (lv >= 6) {
    final spin = -t * 0.9;
    for (var i = 0; i < 3; i++) {
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: s * 0.58), spin + i * 2 * math.pi / 3, 1.6, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = s * 0.06..strokeCap = StrokeCap.round..color = _a(ac, 0.85 * op));
    }
  }
  if (lv >= 4) {
    _lens(c, Offset.zero, s * 0.17, ac, op, p);
  } else {
    _hot(c, Offset.zero, s * (lv >= 2 ? 0.1 : 0.16), ac, op, p);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4 · DELTA — karbon üçgen plaka, arka çentik, omurga enerjisi.
// ═══════════════════════════════════════════════════════════════════════════
void _paintDelta(Canvas c, double size, double t, int lv, double op) {
  const pal = _gun;
  const ac = Color(0xFFF97316);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final h = s * (lv >= 3 ? 1.15 : 0.9);
  final w = s * (lv >= 3 ? 0.8 : 0.62);
  final notch = lv >= 3 ? s * 0.25 : 0.0;
  final body = _pts([Offset(0, -h), Offset(w, s * 0.55), Offset(0, s * 0.55 - notch), Offset(-w, s * 0.55)]);
  _shadow(c, body, s * 0.05, op);
  _plate(c, body, pal, op, from: Offset(-w, -h), to: Offset(w, s * 0.55), rim: ac);
  if (lv >= 2) _edge(c, body, ac, op, 0.55);
  if (lv >= 3) {
    _seam(c, Offset(0, -h + s * 0.25), Offset(0, s * 0.2), pal.lit, 0.35 * op, 0.5);
    _sheen(c, body, Offset(-w, -h), Offset(0, s * 0.2), op);
  }
  if (lv >= 5) {
    final inner = _pts([Offset(0, -h * 0.55), Offset(w * 0.5, s * 0.3), Offset(0, s * 0.3 - notch * 0.5), Offset(-w * 0.5, s * 0.3)]);
    _stroke(c, inner, 0.5, pal.lit, 0.45 * op);
    _hot(c, Offset(w * 0.86, s * 0.48), s * 0.05, ac, op, p);
    _hot(c, Offset(-w * 0.86, s * 0.48), s * 0.05, ac, op, p);
  }
  if (lv >= 6) {
    _energy(c, _line(Offset(0, -h * 0.85), Offset(0, s * 0.15)), ac, s * 0.045, op, p);
    _hot(c, Offset(0, -h), s * 0.05, ac, op, p);
  }
  _core(c, Offset(0, -s * 0.15), s * 0.17, ac, op, p, lv);
}

// ═══════════════════════════════════════════════════════════════════════════
// 6 · ELMAS — buz kristali rombus, iki faset, dış çerçeve, dikey enerji.
// ═══════════════════════════════════════════════════════════════════════════
void _paintRhombus(Canvas c, double size, double t, int lv, double op) {
  const pal = _ice;
  const ac = Color(0xFF67E8F9);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final h = s * (lv >= 3 ? 1.15 : 0.9);
  final w = s * (lv >= 3 ? 0.58 : 0.5);
  final dia = _pts([Offset(0, -h), Offset(w, 0), Offset(0, h), Offset(-w, 0)]);
  if (lv >= 5) _frame(c, dia, 1.3, pal, ac, s * 0.06, op);
  _shadow(c, dia, s * 0.05, op);
  c.drawPath(_pts([Offset(0, -h), Offset(w, 0), Offset(-w, 0)]),
      Paint()..shader = ui.Gradient.linear(Offset(-w, -h), Offset(w, 0), [_a(pal.lit, op), _a(pal.mid, op)]));
  c.drawPath(_pts([Offset(-w, 0), Offset(w, 0), Offset(0, h)]),
      Paint()..shader = ui.Gradient.linear(Offset(-w, 0), Offset(w, h), [_a(pal.mid, op), _a(pal.dark, op)]));
  _stroke(c, dia, 0.8, pal.dark, 0.9 * op);
  c.drawPath(dia, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.7..strokeJoin = StrokeJoin.round
    ..shader = ui.Gradient.linear(Offset(w, h), Offset(-w, -h), [_a(ac, 0.6 * op), _a(ac, 0)], const [0.0, 0.5]));
  if (lv >= 2) _edge(c, dia, ac, op, 0.5);
  if (lv >= 3) {
    _seam(c, Offset(0, -h), Offset(0, h), pal.lit, 0.55 * op, 0.6);
    _seam(c, Offset(-w, 0), Offset(w, 0), pal.dark, 0.6 * op, 0.6);
    c.drawPath(_pts([Offset(s * 0.03, -h * 0.85), Offset(w * 0.55, -h * 0.28), Offset(w * 0.4, -h * 0.12), Offset(s * 0.03, -h * 0.5)]),
        Paint()..color = _a(Colors.white, 0.28 * op));
  }
  if (lv >= 6) {
    _energy(c, _line(Offset(0, -h * 0.8), Offset(0, h * 0.8)), ac, s * 0.045, op, p);
    _hot(c, Offset(0, -h * 1.3), s * 0.05, ac, op, p);
    _hot(c, Offset(0, h * 1.3), s * 0.05, ac, op, p);
  }
  _core(c, Offset.zero, s * 0.19, ac, op, p, lv);
}

// ═══════════════════════════════════════════════════════════════════════════
// 7 · DAMLA — yeşim damla plaka; omurga dikişi, dış çerçeve, uç ışığı.
// ═══════════════════════════════════════════════════════════════════════════
Path _dropPath(double len, double r) => Path()
  ..moveTo(0, -len)
  ..quadraticBezierTo(r * 1.15, -len * 0.15, r, len * 0.25)
  ..arcToPoint(Offset(-r, len * 0.25), radius: Radius.circular(r), clockwise: true)
  ..quadraticBezierTo(-r * 1.15, -len * 0.15, 0, -len)
  ..close();

void _paintDrop(Canvas c, double size, double t, int lv, double op) {
  const pal = _jade;
  const ac = Color(0xFF4ADE80);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final len = s * (lv >= 3 ? 1.15 : 0.9);
  final r = s * (lv >= 3 ? 0.6 : 0.5);
  final body = _dropPath(len, r);
  if (lv >= 5) _frame(c, body, 1.28, pal, ac, s * 0.06, op);
  _shadow(c, body, s * 0.05, op);
  _plate(c, body, pal, op, from: Offset(-r, -len), to: Offset(r, len * 0.25 + r), rim: ac);
  if (lv >= 2) _edge(c, body, ac, op, 0.5);
  if (lv >= 3) {
    _seam(c, Offset(0, -len * 0.85), Offset(0, len * 0.25 + r * 0.6), pal.lit, 0.35 * op, 0.5);
    _sheen(c, body, Offset(-r, -len), Offset(0, len * 0.2), op);
  }
  if (lv >= 6) {
    _energy(c, _line(Offset(0, -len * 0.8), Offset(0, len * 0.25 + r * 0.5)), ac, s * 0.045, op, p);
    _hot(c, Offset(0, -len * 1.28), s * 0.05, ac, op, p);
  }
  _core(c, Offset(0, -len * 0.05), s * 0.19, ac, op, p, lv);
}

// ═══════════════════════════════════════════════════════════════════════════
// 11 · PUSULA — altın dört köşeli yıldız, ikincil uçlar, pusula halkası.
// ═══════════════════════════════════════════════════════════════════════════
void _paintCompass(Canvas c, double size, double t, int lv, double op) {
  const pal = _gold;
  const ac = Color(0xFFFDE68A);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final r = s * (lv >= 3 ? 1.15 : 0.9);
  const rot = -math.pi / 2;
  final star = _poly(4, r, inner: r * 0.28, rot: rot);
  if (lv >= 5) {
    final minor = _poly(4, r * 0.62, inner: r * 0.2, rot: rot + math.pi / 4);
    _shadow(c, minor, s * 0.04, op);
    _plate(c, minor, pal, op, stroke: 0.6);
  }
  if (lv >= 6) _band(c, _circle(r * 0.62), pal, ac, s * 0.06, op);
  _shadow(c, star, s * 0.05, op);
  _plate(c, star, pal, op, rim: ac);
  if (lv >= 2) _edge(c, star, ac, op, 0.5);
  if (lv >= 3) {
    for (var i = 0; i < 4; i++) {
      final a = rot + i * math.pi / 2;
      _seam(c, Offset.zero, _pol(a, r * 0.97), pal.dark, 0.5 * op, 0.5);
      _seam(c, Offset.zero, _pol(a + math.pi / 4, r * 0.27), pal.lit, 0.4 * op, 0.5);
    }
    _sheen(c, star, Offset(-r, -r), Offset(0, r * 0.3), op);
  }
  if (lv >= 6) {
    for (var i = 0; i < 4; i++) {
      _hot(c, _pol(rot + i * math.pi / 2, r), s * 0.05, ac, op, p);
    }
  }
  _core(c, Offset.zero, s * 0.19, ac, op, p, lv);
}

// ═══════════════════════════════════════════════════════════════════════════
// 12 · ÇERÇEVE — bakır içi boş altıgen, köşe ışıkları, ters dönen iç altıgen.
// ═══════════════════════════════════════════════════════════════════════════
void _paintHexFrame(Canvas c, double size, double t, int lv, double op) {
  const pal = _copper;
  const ac = Color(0xFF34D399);
  final s = size * _grow(lv);
  final p = _pulse(t);
  const rot = -math.pi / 2;
  final rOut = s * (lv >= 3 ? 1.12 : 0.9);
  final wid = s * (lv >= 3 ? 0.3 : 0.22);
  final rIn = rOut - wid / math.cos(math.pi / 6);
  final ring = _polyRing(6, rOut, rIn, rot: rot);
  _shadow(c, ring, s * 0.05, op);
  _plate(c, ring, pal, op, rim: ac);
  if (lv >= 2) _edge(c, _poly(6, rIn * 1.03, rot: rot), ac, op, 0.5);
  if (lv >= 3) {
    for (var i = 0; i < 6; i++) {
      final a = rot + i * math.pi / 3;
      _seam(c, _pol(a, rIn), _pol(a, rOut), pal.dark, 0.5 * op, 0.5);
    }
    _sheen(c, ring, Offset(-rOut, -rOut), Offset(0, rOut * 0.2), op);
  }
  if (lv >= 5) {
    for (var i = 0; i < 6; i++) {
      _hot(c, _pol(rot + i * math.pi / 3, rOut * 0.98), s * 0.045, ac, op, p);
    }
  }
  if (lv >= 6) {
    _rot(c, -t * 0.4, () {
      final inner = _poly(6, rIn * 0.72, rot: rot);
      _band(c, inner, pal, ac, s * 0.06, op);
      _stroke(c, inner, s * 0.14, ac, 0.2 * p * op, blend: BlendMode.plus);
    });
  }
  if (lv >= 4) _orbFill(c, Offset.zero, s * 0.28, pal, op);
  _core(c, Offset.zero, s * 0.17, ac, op, p, lv);
}

// ═══════════════════════════════════════════════════════════════════════════
// 13 · PRİZMA — kızıl içi boş üçgen, köşe ışıkları, dönen iç üçgen.
// ═══════════════════════════════════════════════════════════════════════════
void _paintPrism(Canvas c, double size, double t, int lv, double op) {
  const pal = _crimson;
  const ac = Color(0xFF60A5FA);
  final s = size * _grow(lv);
  final p = _pulse(t);
  const rot = -math.pi / 2;
  final rOut = s * (lv >= 3 ? 1.3 : 1.0);
  final wid = s * (lv >= 3 ? 0.3 : 0.22);
  final rIn = rOut - 2 * wid;
  final ring = _polyRing(3, rOut, rIn, rot: rot);
  _shadow(c, ring, s * 0.05, op);
  _plate(c, ring, pal, op, rim: ac);
  if (lv >= 2) _edge(c, _poly(3, rIn * 1.05, rot: rot), ac, op, 0.5);
  if (lv >= 3) {
    for (var i = 0; i < 3; i++) {
      final a = rot + i * 2 * math.pi / 3;
      _seam(c, _pol(a, rIn), _pol(a, rOut), pal.dark, 0.5 * op, 0.5);
    }
    _sheen(c, ring, Offset(-rOut, -rOut), Offset(0, rOut * 0.2), op);
  }
  if (lv >= 5) {
    for (var i = 0; i < 3; i++) {
      _hot(c, _pol(rot + i * 2 * math.pi / 3, rOut * 0.9), s * 0.05, ac, op, p);
    }
  }
  if (lv >= 6) {
    _rot(c, t * 0.4, () {
      final inner = _poly(3, rIn * 0.62, rot: rot);
      _band(c, inner, pal, ac, s * 0.06, op);
      _stroke(c, inner, s * 0.14, ac, 0.2 * p * op, blend: BlendMode.plus);
    });
  }
  if (lv >= 4) _orbFill(c, Offset(0, rOut * 0.05), s * 0.28, pal, op);
  _core(c, Offset(0, rOut * 0.05), s * 0.17, ac, op, p, lv);
}

// ═══════════════════════════════════════════════════════════════════════════
// 14 · PARANTEZ — çelik iki yay, dört uç ışığı, dönen iç yaylar.
// ═══════════════════════════════════════════════════════════════════════════
Path _arcBand(double rOut, double rIn, double a0, double sweep) => Path()
  ..addArc(Rect.fromCircle(center: Offset.zero, radius: rOut), a0, sweep)
  ..arcTo(Rect.fromCircle(center: Offset.zero, radius: rIn), a0 + sweep, -sweep, false)
  ..close();

void _paintBracket(Canvas c, double size, double t, int lv, double op) {
  const pal = _steel;
  const ac = Color(0xFFF472B6);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final r = s * (lv >= 3 ? 1.05 : 0.85);
  final wid = s * (lv >= 3 ? 0.3 : 0.2);
  final sweep = lv >= 3 ? 2.0 : 1.6;
  if (lv >= 6) {
    _rot(c, t * 0.6, () {
      for (final a in const [math.pi / 2, -math.pi / 2]) {
        final inner = Path()..addArc(Rect.fromCircle(center: Offset.zero, radius: r - wid - s * 0.16), a - 0.6, 1.2);
        _band(c, inner, pal, ac, s * 0.06, op);
        _stroke(c, inner, s * 0.14, ac, 0.2 * p * op, blend: BlendMode.plus);
      }
    });
  }
  for (final m in const [0.0, math.pi]) {
    final band = _arcBand(r + wid / 2, r - wid / 2, m - sweep / 2, sweep);
    _shadow(c, band, s * 0.05, op);
    _plate(c, band, pal, op, from: Offset(-r, -r), to: Offset(r, r), rim: ac);
    if (lv >= 2) {
      _edge(c, Path()..addArc(Rect.fromCircle(center: Offset.zero, radius: r - wid * 0.5 + s * 0.06), m - sweep / 2 + 0.05, sweep - 0.1), ac, op, 0.5);
    }
    if (lv >= 3) {
      _seam(c, _pol(m, r - wid / 2), _pol(m, r + wid / 2), pal.dark, 0.5 * op, 0.5);
      _sheen(c, band, Offset(-r, -r), Offset(0, r * 0.2), op);
    }
    if (lv >= 5) {
      _hot(c, _pol(m - sweep / 2, r), s * 0.05, ac, op, p);
      _hot(c, _pol(m + sweep / 2, r), s * 0.05, ac, op, p);
    }
  }
  if (lv >= 2) _orbFill(c, Offset.zero, s * 0.32, pal, op);
  _core(c, Offset.zero, s * 0.18, ac, op, p, lv);
}

// ═══════════════════════════════════════════════════════════════════════════
// 20 · JİROSKOP — çelik çekirdek, bir çember + bir eğik halka, dört düğüm.
// ═══════════════════════════════════════════════════════════════════════════
void _paintGyro(Canvas c, double size, double t, int lv, double op) {
  const pal = _steel;
  const ac = Color(0xFFF2FBFF);
  final s = size * _grow(lv);
  final p = _pulse(t);
  final r = s * (lv >= 3 ? 1.15 : 0.9);
  final tilt = lv >= 6 ? t * 0.7 : 0.55;
  if (lv >= 3) {
    _rot(c, tilt, () {
      final e = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.55));
      _band(c, e, pal, ac, s * 0.1, op);
      if (lv >= 6) _stroke(c, e, s * 0.2, ac, 0.18 * p * op, blend: BlendMode.plus);
    });
  }
  final coreR = s * (lv >= 2 ? 0.38 : 0.5);
  _shadow(c, _circle(coreR), s * 0.04, op);
  _orbFill(c, Offset.zero, coreR, pal, op, rim: ac);
  if (lv >= 2) {
    final ring = _circle(r);
    _band(c, ring, pal, ac, s * 0.1, op);
    if (lv >= 6) _stroke(c, ring, s * 0.2, ac, 0.15 * p * op, blend: BlendMode.plus);
  }
  if (lv >= 5) {
    for (var i = 0; i < 4; i++) {
      _hot(c, _pol(i * math.pi / 2, r), s * 0.05, ac, op, p);
    }
  }
  _core(c, Offset.zero, coreR * 0.5, ac, op, p, lv);
}
