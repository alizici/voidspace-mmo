/// UNVAN AMBLEMİ — yirmi adın görsel karşılığı (10.4).
///
/// Unvan bugüne kadar yalnız metindi: "SQUIRE III". Ad ucuz bir bilgi ve
/// metin onu doğru taşıyor, ama unvanın işi ilerlemeyi GÖRÜNÜR kılmak ve
/// yirmi adım metin olarak birbirinin aynı görünüyor. Amblem üç şeyi bir
/// bakışta veriyor: hangi ad (merkez glif), hangi kademe (dış halkanın kaç
/// dilimi yanıyor), hangi çağ (aparatın kaç katmanı var).
///
/// **Renk merdiveni YENİ DEĞİL.** Yirmi unvan ve yirmi eşya rankı aynı
/// merdivenin basamakları; unvana ayrı bir palet açmak oyuncuya iki ayrı
/// renk dili öğretmek olurdu. `RankGorseli` ne diyorsa o: ilk unvan C-I'in
/// grisi, sonuncusu Parlayan Pembe'nin pembesi.
///
/// **Hareket İKİ KADEMELİ ve sebebi ölçüm.** Küçük ikon ([UnvanIkonu]) durgun
/// çiziliyor: unvan satırı hangarda ve HUD'da her karede yeniden boyanıyor,
/// [RankPlakasi]'nın envanter ızgarası için verdiği kararla aynı gerekçe.
/// Büyük amblem ([UnvanAmblemi]) tek örnek ve modal bir kartın içinde;
/// oradaki dönüş ve nefes bir kez ödeniyor, `ShipPortrait`in bedeli gibi.
/// Durgun kare bir "donmuş animasyon" değil: [_zaman] `null` iken her yardımcı
/// afiş değerini veriyor, yani nefes tepesinde, dönüş sıfırda.
///
/// Çizim sözleşmesi projenin geri kalanıyla aynı: yerel merkez `(0,0)`,
/// `boy` yarıçap referansı, açı yok (amblem simetrik, çağıran döndürmez).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import 'rank_plakasi.dart';


// ═══════════════════════════════════════════════════════════════════════
// Palet — merdivenden okunuyor, elle yazılmıyor
// ═══════════════════════════════════════════════════════════════════════

/// Bir unvanın üç rengi: taban, açık, kor.
///
/// Üçü de [RankGorseli]'nden türüyor. Kor rengi ayrı bir girdi değil, açığın
/// beyaza yaklaştırılmışı: uçlar ve çekirdekler için tek bir "en parlak"
/// gerekiyor ve onu palete dördüncü sütun olarak eklemek, sekiz aile için
/// sekiz yeni renk seçmek demekti.
class UnvanPaleti {
  const UnvanPaleti(this.taban, this.acik, this.kor);

  /// [unvanIndeksi] 0..19 — merdivenin aynı basamağının eşya rengi.
  factory UnvanPaleti.of(int unvanIndeksi) {
    final i = unvanIndeksi.clamp(0, ItemTier.values.length - 1);
    final g = RankGorseli.of(ItemTier.values[i]);
    return UnvanPaleti(g.taban, g.acik, Color.lerp(g.acik, Colors.white, .55)!);
  }

  final Color taban;
  final Color acik;
  final Color kor;
}

// ═══════════════════════════════════════════════════════════════════════
// Çizim ilkelleri
// ═══════════════════════════════════════════════════════════════════════

Color _a(Color c, double o) => c.withValues(alpha: (c.a * o).clamp(0.0, 1.0));

Offset _kut(double aci, double r, [double cx = 0, double cy = 0]) =>
    Offset(cx + math.cos(aci) * r, cy + math.sin(aci) * r);

Path _cokgen(int n, double r, {double don = -math.pi / 2, List<Offset>? uclar}) {
  final p = Path();
  for (var i = 0; i < n; i++) {
    final o = _kut(don + i * 2 * math.pi / n, r);
    uclar?.add(o);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

Path _yildiz(int n, double dis, double ic, {double don = -math.pi / 2}) {
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final o = _kut(don + i * math.pi / n, i.isOdd ? ic : dis);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Taç yaprağı: ucu [aci] yönünde [r]'de, tabanı merkeze [tabanOrani] kadar
/// yakın; iki kuadratik eğri kenarları [acilim] radyan açıyor.
Path _yaprak(
  double aci,
  double r,
  double acilim,
  double tabanOrani, {
  double cy = 0,
}) {
  final uc = _kut(aci, r, 0, cy);
  final taban = _kut(aci, r * tabanOrani, 0, cy);
  final sol = _kut(aci + acilim, r * .65, 0, cy);
  final sag = _kut(aci - acilim, r * .65, 0, cy);
  return Path()
    ..moveTo(taban.dx, taban.dy)
    ..quadraticBezierTo(sol.dx, sol.dy, uc.dx, uc.dy)
    ..quadraticBezierTo(sag.dx, sag.dy, taban.dx, taban.dy)
    ..close();
}

/// Gerçek lemniskat (r² = a²·cos2θ), örneklenmiş. Elle çizilen iki bezier
/// yerine formülün kendisi: sekiz rakamı merkezde doğru kapanıyor.
Path _lemniskat(double genlik, {int adim = 88}) {
  final p = Path();
  var basladi = false;
  for (var i = 0; i <= adim; i++) {
    final th = i / adim * 2 * math.pi;
    final c2 = math.cos(2 * th);
    if (c2 <= 0) continue;
    final r = genlik * math.sqrt(c2);
    final o = Offset(r * math.cos(th), r * math.sin(th));
    basladi ? p.lineTo(o.dx, o.dy) : p.moveTo(o.dx, o.dy);
    basladi = true;
  }
  return p;
}

void _ciz(
  Canvas c,
  Path p,
  double kalinlik,
  Color renk,
  double op, {
  StrokeCap uc = StrokeCap.round,
}) => c.drawPath(
  p,
  Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = kalinlik
    ..strokeCap = uc
    ..strokeJoin = StrokeJoin.round
    ..color = _a(renk, op),
);

void _dolgu(Canvas c, Path p, Color renk, double op) =>
    c.drawPath(p, Paint()..color = _a(renk, op));

void _nokta(Canvas c, Offset at, double r, Color renk, double op) =>
    c.drawCircle(at, r, Paint()..color = _a(renk, op));

void _halka(Canvas c, double r, double w, Color renk, double op) => c.drawCircle(
  Offset.zero,
  r,
  Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = _a(renk, op),
);

Path _yay(double r, double a0, double a1) =>
    Path()..addArc(Rect.fromCircle(center: Offset.zero, radius: r), a0, a1 - a0);

/// Kesikli halka. Desen statik: eleman döndükçe tümü döner, iç faz yok.
void _kesikliHalka(
  Canvas c,
  double r,
  double w,
  Color renk,
  double op,
  double cizgi,
  double bosluk,
) {
  final n = math.max(1, (2 * math.pi * r / (cizgi + bosluk)).round());
  final boya = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.butt
    ..color = _a(renk, op);
  for (var i = 0; i < n; i++) {
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r),
      -math.pi / 2 + i * 2 * math.pi / n,
      cizgi / r,
      false,
      boya,
    );
  }
}

/// Ölçüm bezeli: [n] küçük çentik, her [buyukAdim]'da bir uzun.
void _bezel(Canvas c, double r, int n, int buyukAdim, Color renk, double op) {
  final kucuk = Path(), buyuk = Path();
  for (var i = 0; i < n; i++) {
    final aci = i / n * 2 * math.pi - math.pi / 2;
    final uzun = i % buyukAdim == 0;
    final p0 = _kut(aci, r), p1 = _kut(aci, r + (uzun ? 8.8 : 4));
    final hedef = uzun ? buyuk : kucuk;
    hedef
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy);
  }
  _ciz(c, kucuk, 1, renk, op * .55, uc: StrokeCap.butt);
  _ciz(c, buyuk, 1.7, renk, op, uc: StrokeCap.butt);
}

void _mesnetler(Canvas c, double r, double s, Color renk, double op) {
  for (var i = 0; i < 4; i++) {
    final aci = -math.pi / 4 + i * math.pi / 2;
    final at = _kut(aci, r);
    c
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(aci);
    _ciz(
      c,
      Path()
        ..moveTo(-s, -s)
        ..lineTo(0, -s)
        ..lineTo(0, s)
        ..lineTo(-s, s),
      1.5,
      renk,
      op,
    );
    c.restore();
  }
}

void _isinlar(Canvas c, double r0, double r1, int n, Color renk, double op) {
  final p = Path();
  for (var i = 0; i < n; i++) {
    final aci = i / n * 2 * math.pi;
    final p0 = _kut(aci, r0), p1 = _kut(aci, r1);
    p
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy);
  }
  _ciz(c, p, .7, renk, op, uc: StrokeCap.butt);
}

// ── Zaman yardımcıları ─────────────────────────────────────────────────
//
// [t] `null` ise AFİŞ karesi: nefes tepesinde, ölçek bir, dönüş sıfır.
// Durgun amblem böylece "duran bir animasyon" değil, o iş için seçilmiş bir
// kare oluyor.

double _faz(double t, double gecikme, double sure) => ((t + gecikme) / sure) % 1;

double _donus(double? t, double sure, [double gecikme = 0]) =>
    t == null ? 0 : 2 * math.pi * (t + gecikme) / sure;

double _nefes(double? t, double sure, [double gecikme = 0]) => t == null
    ? .95
    : .625 - .375 * math.cos(2 * math.pi * _faz(t, gecikme, sure));

double _nabiz(double? t, double sure, [double genlik = .035]) => t == null
    ? 1
    : 1 + genlik * (1 - math.cos(2 * math.pi * _faz(t, 0, sure)));

/// Genişleyip sönen atım halkası: (ölçek, opaklık). Durgunda orta kare.
(double, double) _atim(double? t, double sure, [double gecikme = 0]) {
  final u = t == null ? .45 : _faz(t, gecikme, sure);
  return (.5 + 1.05 * u, .8 * (1 - u));
}

// ═══════════════════════════════════════════════════════════════════════
// Merkez glifleri — yirmi ad, her biri ayrı
// ═══════════════════════════════════════════════════════════════════════
//
// Alt çağlar SAF GEOMETRİ: üçgen, kare, beşgen, altıgen. Kalkan, kale, taç
// gibi somut nesne YOK — unvanlar bir ordunun rütbeleri değil, bir gücün
// basamakları. Üst çağlar taç yaprağı, mandala, facet ve lemniskatla
// zenginleşiyor: aynı dilin daha uzun cümleleri.

typedef _Glif = void Function(Canvas c, UnvanPaleti k, double? t);

// 01 · Squire — çıplak üçgen, tek çekirdek.
void _gSquire(Canvas c, UnvanPaleti k, double? t) {
  _ciz(c, _cokgen(3, 34), 2, k.taban, .8);
  _nokta(c, const Offset(0, 4), 6, k.kor, .9 * _nefes(t, 3.2));
  _nokta(c, const Offset(0, 4), 2.4, Colors.white, .9);
}

// 02 · Knight — çapraz iki hat, ortada elmas.
void _gKnight(Canvas c, UnvanPaleti k, double? t) {
  for (final p in [
    Path()
      ..moveTo(-40, 40)
      ..lineTo(40, -40),
    Path()
      ..moveTo(40, 40)
      ..lineTo(-40, -40),
  ]) {
    _ciz(c, p, 2, k.taban, .65);
  }
  final elmas = _cokgen(4, 11, don: -math.pi / 4);
  _dolgu(c, elmas, k.taban, .5);
  _ciz(c, elmas, 1.6, k.kor, .95 * _nefes(t, 3.4));
}

// 03 · Baron — kare çerçeve, tek kuşak hattı.
void _gBaron(Canvas c, UnvanPaleti k, double? t) {
  _ciz(c, _cokgen(4, 40, don: -math.pi / 4), 2, k.taban, .82);
  _ciz(c, _yay(50, .2 * math.pi, .8 * math.pi), 1.2, k.taban, .4);
  _nokta(c, Offset.zero, 4.4, k.kor, .9 * _nefes(t, 2.8));
}

// 04 · Count — beşgen, köşeleri sırayla tutuşan.
void _gCount(Canvas c, UnvanPaleti k, double? t) {
  final uclar = <Offset>[];
  _ciz(c, _cokgen(5, 42, uclar: uclar), 2, k.taban, .8);
  for (var i = 0; i < uclar.length; i++) {
    _nokta(c, uclar[i], 4, k.kor, .95 * _nefes(t, 2.4, i * .3));
  }
  _nokta(c, Offset.zero, 3.2, k.taban, .5);
}

// 05 · Duke — kapalı altıgen: birinci çağın tamamlanmış biçimi.
void _gDuke(Canvas c, UnvanPaleti k, double? t) {
  final alti = _cokgen(6, 46);
  _dolgu(c, alti, k.taban, .12);
  _ciz(c, alti, 2.1, k.taban, .9);
  _halka(c, 24, 1, k.taban, .4);
  _nokta(c, Offset.zero, 5 * _nabiz(t, 3), k.kor, .9);
}

// 06 · Acolyte — kısa yay, üstünde tek kıvılcım.
void _gAcolyte(Canvas c, UnvanPaleti k, double? t) {
  c.save();
  c.translate(0, 8);
  _ciz(c, _yay(42, .18 * math.pi, .82 * math.pi), 2, k.taban, .78);
  c.save();
  c.rotate(_donus(t, 5.5));
  _nokta(c, const Offset(0, -42), 3, k.kor, .95);
  c.restore();
  _nokta(c, Offset.zero, 4.4, k.kor, .85 * _nefes(t, 2.4));
  c.restore();
}

// 07 · Cleric — dört uçlu ışık yıldızı, kesikli hale.
void _gCleric(Canvas c, UnvanPaleti k, double? t) {
  c.save();
  c.rotate(-_donus(t, 20));
  _kesikliHalka(c, 40, 1, k.taban, .32, 12, 7);
  c.restore();
  final s = _nabiz(t, 4);
  final st = _yildiz(4, 52 * s, 15 * s);
  _dolgu(c, st, k.taban, .3);
  _ciz(c, st, 1.7, k.kor, .95);
  _nokta(c, Offset.zero, 4.5, Colors.white, .95);
}

// 08 · Bishop — yükselen açı, altından doğan ışık.
void _gBishop(Canvas c, UnvanPaleti k, double? t) {
  _ciz(
    c,
    Path()
      ..moveTo(-26, 20)
      ..lineTo(0, -30)
      ..lineTo(26, 20),
    2,
    k.taban,
    .85,
  );
  final u = t == null ? .35 : _faz(t, 0, 2.9);
  final dy = -56 * u;
  final op = u < .2 ? u / .2 : (1 - (u - .2) / .8);
  _ciz(
    c,
    Path()
      ..moveTo(0, 24 + dy)
      ..lineTo(0, 6 + dy),
    2.4,
    k.kor,
    .9 * op,
  );
  _nokta(c, const Offset(0, -30), 3.4, k.kor, .95 * _nefes(t, 2.8));
}

// 09 · Saint — lotus halesi: altı taç yaprağı, gradyanlı.
void _gSaint(Canvas c, UnvanPaleti k, double? t) {
  c.save();
  c.rotate(t == null ? 0 : -(5 * math.pi / 180) * math.cos(2 * math.pi * _faz(t, 0, 6)));
  for (var i = 0; i < 6; i++) {
    final yp = _yaprak(-math.pi / 2 + i * math.pi / 3, 44, .46, .22);
    final b = yp.getBounds();
    c.drawPath(
      yp,
      Paint()
        ..shader = ui.Gradient.linear(b.bottomCenter, b.topCenter, [
          _a(k.taban, .85),
          _a(k.acik, .35),
        ]),
    );
    _ciz(c, yp, .8, k.taban, .5);
  }
  c.restore();
  _halka(c, 20, .8, k.taban, .35);
  _nokta(c, Offset.zero, 5.5, k.kor, .9 * _nefes(t, 2.8));
  _nokta(c, Offset.zero, 2.4, Colors.white, .9);
}

// 10 · Deity — mandala: sekiz düğüm, altı kesişen halka.
void _gDeity(Canvas c, UnvanPaleti k, double? t) {
  final (as_, aop) = _atim(t, 3.9);
  _halka(c, 34 * as_, 1.6, k.taban, .7 * aop);
  for (var i = 0; i < 8; i++) {
    final p = _kut(-math.pi / 2 + i * math.pi / 4, 30);
    c.drawCircle(
      p,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _a(k.taban, .55 * _nefes(t, 3.2, i * .22)),
    );
  }
  c.save();
  c.rotate(-_donus(t, 24));
  for (var i = 0; i < 6; i++) {
    final p = _kut(i * math.pi / 3, 11);
    c.drawCircle(
      p,
      12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = _a(k.taban, .38),
    );
  }
  c.restore();
  _halka(c, 20, 1, k.taban, .5);
  final s = _nabiz(t, 2.6);
  _nokta(c, Offset.zero, 10 * s, k.kor, .95);
  _nokta(c, Offset.zero, 4.6 * s, Colors.white, 1);
}

// 11 · Starcaller — altı uçlu yıldız.
void _gStarcaller(Canvas c, UnvanPaleti k, double? t) {
  c.save();
  c.rotate(-_donus(t, 14));
  _kesikliHalka(c, 34, 1, k.taban, .35, 4, 6);
  c.restore();
  final s = _nabiz(t, 2.4);
  final st = _yildiz(6, 46 * s, 15 * s);
  _dolgu(c, st, k.taban, .35);
  _ciz(c, st, 1.6, k.kor, .95);
  _nokta(c, Offset.zero, 4.5, Colors.white, 1);
}

// 12 · Comet — yörüngede süzülen kütle, kuyruğu gradyan.
void _gComet(Canvas c, UnvanPaleti k, double? t) {
  const r = 34.0;
  _kesikliHalka(c, r, 1, k.taban, .25, 3, 8);
  c.save();
  c.rotate(_donus(t, 6.5));
  const a0 = -math.pi / 2 - 2.2, a1 = -math.pi / 2;
  c.drawPath(
    _yay(r, a0, a1),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(_kut(a0, r), _kut(a1, r), [
        _a(k.taban, 0),
        _a(k.kor, .9),
      ]),
  );
  _nokta(c, const Offset(0, -r), 9, k.kor, .4);
  _nokta(c, const Offset(0, -r), 5.5, Colors.white, 1);
  c.restore();
  _nokta(c, Offset.zero, 10, k.taban, .4);
  _halka(c, 10, 1.2, k.taban, .7);
  _nokta(c, Offset.zero, 4.4, k.kor, _nefes(t, 2.6));
}

// 13 · Pulsar — süpüren çift ışın.
void _gPulsar(Canvas c, UnvanPaleti k, double? t) {
  final isin = Path()
    ..moveTo(0, 0)
    ..lineTo(52, -11)
    ..lineTo(82, 0)
    ..lineTo(52, 11)
    ..close();
  final boya = Paint()
    ..shader = ui.Gradient.linear(Offset.zero, const Offset(82, 0), [
      _a(k.kor, .9),
      _a(k.taban, 0),
    ]);
  c.save();
  c.rotate(_donus(t, 4.6));
  c.drawPath(isin, boya);
  c.save();
  c.rotate(math.pi);
  c.drawPath(isin, boya);
  c.restore();
  c.restore();
  _halka(c, 22, 1.4, k.taban, .6);
  _halka(c, 15, 1, k.taban, .35);
  final s = _nabiz(t, 1.5);
  _nokta(c, Offset.zero, 11 * s, k.kor, 1);
  _nokta(c, Offset.zero, 5.5 * s, Colors.white, 1);
}

/// Nebula'nın tozu: konumlar KARARLI, her karede yeniden rastgelelenmiyor.
final List<({Offset yer, double r, double op})> _nebulaTozu = (() {
  final rnd = math.Random(7);
  return List.generate(
    8,
    (_) => (
      yer: Offset(-44 + rnd.nextDouble() * 88, -40 + rnd.nextDouble() * 80),
      r: .8 + rnd.nextDouble() * 1.4,
      op: .5 + rnd.nextDouble() * .5,
    ),
  );
})();

// 14 · Nebula — üst üste binen bulut kütleleri.
void _gNebula(Canvas c, UnvanPaleti k, double? t) {
  void bulut(Offset yer, double rx, double ry, double derece, double gecikme) {
    final kayma = t == null
        ? Offset.zero
        : Offset(
            4.5 * math.sin(2 * math.pi * _faz(t, gecikme, 9)),
            -4 * math.sin(2 * math.pi * _faz(t, gecikme, 9) + .9),
          );
    c
      ..save()
      ..translate(yer.dx + kayma.dx, yer.dy + kayma.dy)
      ..rotate(derece * math.pi / 180);
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );
    c
      ..drawOval(r, Paint()..color = _a(k.taban, .22))
      ..drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = _a(k.taban, .5),
      )
      ..restore();
  }

  bulut(const Offset(-16, -8), 30, 21, -18, 0);
  bulut(const Offset(14, 6), 27, 19, 14, 1.4);
  bulut(const Offset(0, -14), 23, 15, 6, 2.8);
  for (final d in _nebulaTozu) {
    _nokta(c, d.yer, d.r, k.kor, d.op);
  }
  _nokta(c, Offset.zero, 6.5, k.kor, .9 * _nefes(t, 3.4));
  _nokta(c, Offset.zero, 3, Colors.white, _nefes(t, 3.4));
}

// 15 · Vortex — üç kollu sarmal, göz sabit ve karanlık.
void _gVortex(Canvas c, UnvanPaleti k, double? t) {
  c.save();
  c.rotate(_donus(t, 9));
  for (var kol = 0; kol < 3; kol++) {
    final p = Path();
    for (var i = 0; i <= 22; i++) {
      final u = i / 22;
      final o = _kut(kol * 2.094 + u * 3.5, 13 + u * 39);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    _ciz(c, p, 3 - kol * .2, k.taban, .55);
    _ciz(c, p, 1.1, k.kor, .85);
  }
  c.restore();
  c.save();
  c.rotate(-_donus(t, 5.5));
  _kesikliHalka(c, 21, 1.3, k.taban, .6, 8, 6);
  c.restore();
  _nokta(c, Offset.zero, 12, Palette.space, 1);
  _halka(c, 12, 1.9, k.kor, .95);
  _nokta(c, Offset.zero, 4.5, Colors.white, _nefes(t, 2.2));
}

// 16 · Phoenix — alev tacı, yükselen korlar.
void _gPhoenix(Canvas c, UnvanPaleti k, double? t) {
  for (var i = -3; i <= 3; i++) {
    final yp = _yaprak(
      -math.pi / 2 + i * .3,
      30 + (3 - i.abs()) * 9,
      .2,
      .12,
      cy: 8,
    );
    final b = yp.getBounds();
    c.drawPath(
      yp,
      Paint()
        ..shader = ui.Gradient.linear(b.bottomCenter, b.topCenter, [
          _a(k.taban, .85),
          _a(k.acik, .35),
        ]),
    );
    _ciz(c, yp, .8, k.kor, i == 0 ? .9 : .45);
  }
  for (final (x, gecikme) in const [
    (-14.0, 0.0),
    (14.0, .9),
    (0.0, 1.8),
    (-6.0, 2.6),
  ]) {
    final u = t == null ? .45 : _faz(t, gecikme, 3.4);
    final op = u < .25 ? u / .25 : (1 - (u - .25) / .75);
    _nokta(c, Offset(x, 46 - 52 * u), 2.2 * (.6 - .35 * u), k.kor, op);
  }
  final op = _nefes(t, 2.4);
  _nokta(c, const Offset(0, 4), 6, k.kor, .95 * op);
  _nokta(c, const Offset(0, 4), 2.6, Colors.white, op);
}

// 17 · Titan — kesme mücevher: sekizgen kütle, facetler, tepe parlaması.
void _gTitan(Canvas c, UnvanPaleti k, double? t) {
  final uclar = <Offset>[];
  final sekiz = _cokgen(8, 42, uclar: uclar);
  _dolgu(c, sekiz, k.taban, .16);
  _ciz(c, sekiz, 2.2, k.taban, .9);
  final facet = Path();
  for (final v in uclar) {
    facet
      ..moveTo(0, 0)
      ..lineTo(v.dx, v.dy);
  }
  _ciz(c, facet, .6, k.taban, .3);
  _dolgu(
    c,
    Path()
      ..moveTo(0, -42)
      ..lineTo(-14, -30)
      ..lineTo(14, -30)
      ..close(),
    Colors.white,
    .18,
  );
  _halka(c, 26, 1, k.taban, .35);
  _nokta(c, Offset.zero, 8, k.kor, .55 * _nefes(t, 4.4));
  _nokta(c, Offset.zero, 4 * _nabiz(t, 4.4), Colors.white, .85);
}

// 18 · Immortal — sonsuzluk: gerçek lemniskat, iki kalınlıkta.
void _gImmortal(Canvas c, UnvanPaleti k, double? t) {
  final inf = _lemniskat(46);
  _ciz(c, inf, 4.4, k.taban, .2);
  _ciz(c, inf, 1.7, k.taban, .75);
  // Dolaşan ışık yerine sabit iki kor: yol üzerinde `PathMetric` ile parça
  // çıkarmak her karede yolu ölçmek demek ve bu amblem HUD'da da çiziliyor.
  final u = t == null ? .25 : _faz(t, 0, 4.2);
  for (final yon in [1, -1]) {
    final th = yon * (math.pi / 4) * math.sin(2 * math.pi * u);
    final r = 46 * math.sqrt(math.max(0, math.cos(2 * th)));
    _nokta(c, Offset(r * math.cos(th), r * math.sin(th)), 3.2, k.kor, .95);
  }
  _nokta(c, Offset.zero, 4.4, k.kor, _nefes(t, 3.2));
}

// 19 · Star Marshal — beş uçlu yıldız, sabit ince halka.
void _gStarMarshal(Canvas c, UnvanPaleti k, double? t) {
  _halka(c, 52, 1, k.taban, .45);
  final st = _yildiz(5, 44, 17);
  _dolgu(c, st, k.taban, .32);
  _ciz(c, st, 1.8, k.kor, .95);
  _nokta(c, Offset.zero, 6 * _nabiz(t, 3), Colors.white, .95);
}

// 20 · Star Lord — süpernova: on altı ışın, beyaz-sıcak çekirdek.
void _gStarLord(Canvas c, UnvanPaleti k, double? t) {
  final s = _nabiz(t, 3.6);
  final ince = Path(), kalin = Path();
  for (var i = 0; i < 16; i++) {
    final aci = i * math.pi / 8;
    final p0 = _kut(aci, 12 * s), p1 = _kut(aci, (i.isOdd ? 34.0 : 54.0) * s);
    final hedef = i.isOdd ? ince : kalin;
    hedef
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy);
  }
  _ciz(c, ince, 1.3, k.taban, .5);
  _ciz(c, kalin, 2.2, k.kor, .85);
  final s2 = _nabiz(t, 2.2);
  _nokta(c, Offset.zero, 14 * s2, k.taban, .5);
  _nokta(c, Offset.zero, 9 * s2, k.kor, 1);
  _nokta(c, Offset.zero, 4.5 * s2, Colors.white, 1);
}

/// Katalog sırası [Unvan.adlar] sırası. Değiştirmek ikisini de bozar.
const List<_Glif> _glifler = [
  _gSquire, _gKnight, _gBaron, _gCount, _gDuke,
  _gAcolyte, _gCleric, _gBishop, _gSaint, _gDeity,
  _gStarcaller, _gComet, _gPulsar, _gNebula, _gVortex,
  _gPhoenix, _gTitan, _gImmortal, _gStarMarshal, _gStarLord,
];

// ═══════════════════════════════════════════════════════════════════════
// Aparat — ÇAĞLA katmanlanıyor, rütbeyle değil
// ═══════════════════════════════════════════════════════════════════════

/// Kademe halkası: altı dilim, [kademe]'ye kadar (dahil) yanıyor.
///
/// Kademe I–VI unvanın içindeki basamak (10.4) ve tek okunması gereken sayı
/// bu: ad zaten yazıyor, çağ aparattan belli. Sönük dilimler DURUYOR —
/// çıkarılsaydı oyuncu kaçının kaldığını sayamazdı.
void _kademeHalkasi(Canvas c, double r, int kademe, UnvanPaleti k) {
  for (var i = 0; i < 6; i++) {
    final a0 = -math.pi / 2 + i * math.pi / 3 + .1, a1 = a0 + math.pi / 3 - .2;
    final yanik = i <= kademe;
    _ciz(
      c,
      _yay(r, a0, a1),
      yanik ? 4.4 : 2.4,
      yanik ? k.acik : k.taban,
      yanik ? .95 : .18,
      uc: StrokeCap.butt,
    );
    if (yanik) _nokta(c, _kut(a1, r), 2.7, k.kor, .95);
  }
}

/// Aparat: çağ arttıkça katman ekleniyor.
///
/// Rütbe başına ayrı katman (eski tasarımın yaptığı) yirmi farklı düzenek
/// demekti ve aradaki fark okunmuyordu; çağ başına katman dört net kademe
/// veriyor — oyuncu "çağ atladım"ı bir bakışta görüyor.
void _aparat(Canvas c, UnvanPaleti k, int unvanIndeksi, double? t, bool zengin) {
  final cag = unvanIndeksi ~/ 5;

  // Arka ışıma: blur değil radyal gradyan (bkz. ShipSwarm'ın ölçümü).
  c.drawCircle(
    Offset.zero,
    92,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        92,
        [_a(k.taban, .18), _a(k.taban, .05), _a(k.taban, 0)],
        const [0, .6, 1],
      ),
  );

  // İç halka ve haç — her çağda.
  _halka(c, 56, 1, k.taban, .38);
  final hac = Path();
  for (final (x0, y0, x1, y1) in const [
    (-62.0, 0.0, -46.0, 0.0),
    (46.0, 0.0, 62.0, 0.0),
    (0.0, -62.0, 0.0, -46.0),
    (0.0, 46.0, 0.0, 62.0),
  ]) {
    hac
      ..moveTo(x0, y0)
      ..lineTo(x1, y1);
  }
  _ciz(c, hac, 1.2, k.taban, .55);

  // Kutsallık: veri halkası, ters yönde döner.
  if (cag >= 1) {
    c.save();
    c.rotate(-_donus(t, 26));
    _kesikliHalka(c, 82, 1.1, k.taban, .5, cag >= 2 ? 16 : 10, cag >= 2 ? 9 : 12);
    c.restore();
  }
  // Yıldız: ölçüm bezeli ve segment yayları.
  if (cag >= 2) {
    c.save();
    c.rotate(_donus(t, 90));
    _bezel(c, 94, zengin ? 72 : 36, 6, k.taban, .55);
    c.restore();
    c.save();
    c.rotate(_donus(t, 16));
    for (var i = 0; i < 3; i++) {
      final a0 = -math.pi / 2 + i * 2 * math.pi / 3 + .17;
      _ciz(
        c,
        _yay(70, a0, a0 + 2 * math.pi / 3 - .34),
        3,
        k.taban,
        .55,
        uc: StrokeCap.butt,
      );
    }
    c.restore();
  }
  // Ölümsüzlük: mesnetler, ışınlar, enerji atımları.
  if (cag >= 3) {
    _mesnetler(c, 92, 6, k.taban, .55);
    c.save();
    c.rotate(-_donus(t, 50));
    _isinlar(c, 60, 94, zengin ? 24 : 12, k.taban, .28);
    c.restore();
    for (final gecikme in const [0.0, 1.5, 3.0]) {
      final (s, op) = _atim(t, 4.5, gecikme);
      _halka(c, 60 * s, 1.6, k.taban, .55 * op);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Genel API
// ═══════════════════════════════════════════════════════════════════════

/// Bir unvanın BÜYÜK amblemini çizer. Merkez `(0,0)`, [boy] yarıçap
/// referansı (≈70–120). [zaman] `null` ise afiş karesi (durgun).
void unvanAmblemiCiz(
  Canvas canvas,
  double boy, {
  required int unvanIndeksi,
  required int kademe,
  double? zaman,
  bool zengin = false,
}) {
  final k = UnvanPaleti.of(unvanIndeksi);
  canvas.save();
  canvas.scale(boy / 108);
  _aparat(canvas, k, unvanIndeksi, zaman, zengin);
  _kademeHalkasi(canvas, 108, kademe.clamp(0, 5), k);
  // Glif iç halkayı DOLDURUYOR (yarıçapı ~46, halka 56): daha küçüğünde
  // amblemin ortası boş bir kuyu gibi okunuyordu, özellikle aparatı yalın
  // olan ilk çağda.
  canvas.save();
  canvas.scale(1.12);
  _glifler[unvanIndeksi.clamp(0, _glifler.length - 1)](canvas, k, zaman);
  canvas.restore();
  canvas.restore();
}

/// KÜÇÜK ikon: tek halka, kademe yayları, küçültülmüş glif.
///
/// Aparatı ATLIYOR ve durgun çiziliyor. Unvan satırı her karede yeniden
/// boyanabiliyor (HUD), yani buradaki her katman kare bütçesinden yiyor.
void unvanIkonuCiz(
  Canvas canvas,
  double boy, {
  required int unvanIndeksi,
  required int kademe,
}) {
  final k = UnvanPaleti.of(unvanIndeksi);
  final t = kademe.clamp(0, 5);
  canvas.save();
  canvas.scale(boy / 16);
  for (var i = 0; i <= t; i++) {
    final a0 = -math.pi / 2 + i * math.pi / 3 + .12;
    _ciz(
      canvas,
      _yay(15.2, a0, a0 + math.pi / 3 - .24),
      1.6,
      k.kor,
      .9,
      uc: StrokeCap.butt,
    );
  }
  // Halka HER unvanda var: yalnız üst yarıda çizilseydi ilk rankların
  // ikonu tek bir yay olurdu ve "bozuk mu" diye bakılırdı. Üst yarıda
  // kesikleniyor, yani halka bir kademe daha taşıyor.
  if (unvanIndeksi >= _glifler.length ~/ 2) {
    _kesikliHalka(canvas, 12.6, 1.2, k.taban, .6, 4, 3);
  } else {
    _halka(canvas, 12.6, 1.1, k.taban, .5);
  }
  canvas.save();
  canvas.scale(.24);
  _glifler[unvanIndeksi.clamp(0, _glifler.length - 1)](canvas, k, null);
  canvas.restore();
  canvas.restore();
}

/// Unvan ikonu widget'ı — satır içinde, metnin solunda.
class UnvanIkonu extends StatelessWidget {
  const UnvanIkonu({required this.unvanIndeksi, required this.kademe, this.boy = 18, super.key});

  final int unvanIndeksi;
  final int kademe;
  final double boy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: boy,
    height: boy,
    child: CustomPaint(
      painter: _IkonBoyaci(unvanIndeksi: unvanIndeksi, kademe: kademe),
    ),
  );
}

class _IkonBoyaci extends CustomPainter {
  const _IkonBoyaci({required this.unvanIndeksi, required this.kademe});

  final int unvanIndeksi;
  final int kademe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    unvanIkonuCiz(
      canvas,
      size.shortestSide / 2,
      unvanIndeksi: unvanIndeksi,
      kademe: kademe,
    );
  }

  @override
  bool shouldRepaint(_IkonBoyaci eski) =>
      eski.unvanIndeksi != unvanIndeksi || eski.kademe != kademe;
}

/// Büyük amblem widget'ı — pilot kartında, tek örnek.
///
/// Zamanı DIŞARIDAN alıyor: kendi `Ticker`'ını kurmuyor, çünkü kartın kendisi
/// zaten bir animasyon sürücüsü taşıyor ve iki saat iki farklı faz demek.
class UnvanAmblemi extends StatelessWidget {
  const UnvanAmblemi({
    required this.unvanIndeksi,
    required this.kademe,
    this.boy = 108,
    this.zaman,
    this.zengin = true,
    super.key,
  });

  final int unvanIndeksi;
  final int kademe;
  final double boy;
  final double? zaman;
  final bool zengin;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: boy * 2,
    height: boy * 2,
    child: CustomPaint(
      painter: _AmblemBoyaci(
        unvanIndeksi: unvanIndeksi,
        kademe: kademe,
        zaman: zaman,
        zengin: zengin,
      ),
    ),
  );
}

class _AmblemBoyaci extends CustomPainter {
  const _AmblemBoyaci({
    required this.unvanIndeksi,
    required this.kademe,
    required this.zaman,
    required this.zengin,
  });

  final int unvanIndeksi;
  final int kademe;
  final double? zaman;
  final bool zengin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    unvanAmblemiCiz(
      canvas,
      size.shortestSide / 2,
      unvanIndeksi: unvanIndeksi,
      kademe: kademe,
      zaman: zaman,
      zengin: zengin,
    );
  }

  @override
  bool shouldRepaint(_AmblemBoyaci eski) =>
      eski.unvanIndeksi != unvanIndeksi ||
      eski.kademe != kademe ||
      eski.zaman != zaman ||
      eski.zengin != zengin;
}
