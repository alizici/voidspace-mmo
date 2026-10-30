import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'armament.dart';
import 'atlas_layout.dart';
import 'drive_plume.dart';
import 'heat_ramp.dart';
import 'vfx.dart';
import 'weapon_emitter.dart';

/// Bloom katmanının sınırı: tam gazda plumayı ve etek parıltısını içine alacak
/// kadar geniş.
const Rect _fxBounds = Rect.fromLTRB(-86, -104, 86, 184);

/// Gövdenin GÖRSEL sınırı — gövde kutusundan büyüktür, çünkü motor pluması ve
/// bloom taşması arkaya uzanır. Atlas pişiricinin kare boyunu buradan
/// hesaplaması, sınırın tek bir yerde tanımlı kalmasını sağlıyor.
Rect get _publicFxBounds => _fxBounds;

/// Bu gövdenin bütün emissive rengi TEK rampadan gelir.
Color _heat(double t, [double alpha = 1]) => HeatRamp.molten.at(t, alpha);

// ═════════════════════════════════════════════════════════════════════════
// Bastion — C prow + fish-fins, molten VFX kit
// ═════════════════════════════════════════════════════════════════════════
//
// Efekt, bir yığın turuncu fırça darbesi değil; gerçek-zamanlı VFX'in standart
// emissive yığını üzerine kurulu:
//
//  1. TEK sıcaklık rampası — her sıcak piksel tek bir kara-cisim LUT'undan
//     örneklenir (kabuk → koyu kızıl → lav → kehribar → beyaz). Okumayı renk
//     tonu değil *değer* taşır. Beyaz karneye bağlıdır: yalnız nozzle boğazı ve
//     en sıcak çatlak cepleri oraya ulaşabilir.
//  2. kabuk / gövde / çekirdek — her emissive öğe daralan genişlik ve yükselen
//     sıcaklıkla üç kez boyanır; böylece kenarı, kütlesi ve çekirdeği olur, tek
//     düz renk değil.
//  3. taşınım (advection), yürüyen kesik çizgi değil — eriyik akış, çatlağın yay
//     uzunluğu boyunca örneklenen gezici bir fbm dalgasıdır. Isı CEPLERİ
//     yarıktan geçer; kesik çizgiler birbirini kovalamaz.
//  4. TEK gerçek bloom geçişi — emissive katman iki kez kompozit edilir: bir kez
//     bulanık-additive `saveLayer` üzerinden, bir kez üstüne keskin. Çekirdeğin
//     zırha taşmasını sağlayan budur; her şeklin kendi `MaskFilter`'ı yalnız
//     kendini sisler.
//  5. her yerde sönümlenme — çatlaklar uçlarına doğru soğur, şok elmasları
//     türbülanslı kesme altında aşağı doğru söner, korlar yaşlandıkça soğur.
//  6. önce oynanış — itki; çatlak sıcaklığını, pluma boyunu, düğüm sayısını, kor
//     sürüklenmesini ve buğuyu sürer. Geminin durumu tek başına efektten okunur.

// C pruvası + yüzgeç geometrisi. Gövde yolu, zırh maskesi ve halka
// çatlakları hep buradan türer — tek doğruluk kaynağı.
const double _cRo = 21.0, _cRi = 35.0, _cCy = -38.0;
const double _cBetaIn = 0.3, _cBetaOut = 1.1;
const double _cFinBack = 0.35, _cFinLen = 13.0;
const double _cAFin = -pi / 2 + _cBetaOut + _cFinBack;
const double _cRear = 26.0;
// Zırh paleti. Kasten derin ve soğuk: değer aralığının TEPESİ eriyik geçişe
// ait, metale değil. Gövde paletin en açık değerine hiç ulaşmaz.
const _plateMetal = [Color(0xFF7C828C), Color(0xFF24262C), Color(0xFF07080C)];
const _plateEdge = Color(0xDC8E7867);
const _panelSeam = Color(0xCC08090B);

// ── Molten seams ─────────────────────────────────────────────────────────

/// Zırhtaki bir yarık. `Path` değil POLİLİNE olarak tutulur: kare başına maliyet
/// bu noktalar üzerinde `drawLine`lardan ibaret kalsın, çizim döngüsünde
/// `computeMetrics`/`extractPath` tahsisi olmasın.
class _MoltenSeam {
  _MoltenSeam(List<Offset> walk, this.seed, this.weight)
    : points = _resample(walk, 1.4),
      path = _polylinePath(walk);

  final List<Offset> points;
  final double seed;

  /// 1 = ana kırık, düşük = dal/kılcal. Hendek genişliğini, eriyik genişliğini
  /// ve yarığın taşımasına izin verilen ısıyı sürer. Ağın bir HİYERARŞİSİ
  /// olmasını sağlayan budur; yoksa bir düzine özdeş çizgi olurdu.
  final double weight;

  final Path path;
}

/// Eşit aralıklı yeniden örnekleme.
///
/// Kırık yürüyüşü yalnız 8-13 kırılma verir; doğrudan çizilirse her parça o
/// kadar uzun olur ki genişlik ve sıcaklık rampaları basamaklanır ve çatlak bir
/// yumru dizisi gibi okunur. Yeniden örnekleme kırılmaları KORUR (ara değerleme
/// doğrusaldır) ama rampaların üzerlerinden pürüzsüz akmasına izin verir.
List<Offset> _resample(List<Offset> walk, double step) {
  final out = <Offset>[walk.first];
  var carry = 0.0;
  for (var i = 0; i < walk.length - 1; i++) {
    final a = walk[i];
    final b = walk[i + 1];
    final span = (b - a).distance;
    if (span < 1e-6) continue;
    var d = step - carry;
    while (d < span) {
      out.add(Offset.lerp(a, b, d / span)!);
      d += step;
    }
    carry = (carry + span) % step;
  }
  out.add(walk.last);
  return out;
}

Path _polylinePath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  return path;
}

double gRand(double seed, int i) => gHash(seed * 37.1 + i * 11.7);

/// Plaka içinde ilerleyen bir çatlak: her adımda kırılır ama kabaca bir genel
/// yön tutar.
///
/// Köşeli koşular *kırılmış zırh* gibi okunur; yumuşak S-eğrileri ise üstüne
/// boyanmış solucanlar gibi. İkna edici bir eriyik gövdeyi çıkartmadan ayıran
/// en büyük tek etken budur.
List<Offset> _fractureWalk({
  required Offset start,
  required double heading,
  required double length,
  required int steps,
  required double seed,
  double spread = 0.75,
  Rect? bounds,
}) {
  final points = <Offset>[start];
  var h = heading;
  var p = start;
  for (var i = 0; i < steps; i++) {
    h += (gRand(seed, i) - 0.5) * spread * 2;
    final step = length / steps * (0.6 + gRand(seed + 7.7, i) * 0.85);
    p = p.translate(cos(h) * step, sin(h) * step);
    if (bounds != null) {
      p = Offset(
        p.dx.clamp(bounds.left, bounds.right),
        p.dy.clamp(bounds.top, bounds.bottom),
      );
    }
    points.add(p);
    // Özgün yöne doğru geri yaylan ki çatlak yine
    // bir yere varsın, karalamaya dönüşmesin.
    h = h * 0.55 + heading * 0.45;
  }
  return points;
}

/// C halkası zırhı BOYUNCA koşan bir kırık: teğetsel ilerlerken yarıçapı plaka
/// kenarları arasında rastgele yürür. Böylece çatlak, kırdığı yapının üstünde
/// yüzmez, onu TAKİP eder.
List<Offset> _ringFracture({
  required double side,
  required double theta0,
  required double sweep,
  required double r0,
  required int steps,
  required double seed,
}) {
  final points = <Offset>[];
  var r = r0;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    // Düzgün olmayan açısal aralık, pürüzsüz bir yayı kırıklı bir yaya çevirir.
    final theta = theta0 + sweep * (t + (gRand(seed, i) - 0.5) * 0.9 / steps);
    r = (r + (gRand(seed + 3.3, i) - 0.5) * 6.2).clamp(24.5, 31.5);
    points.add(Offset(side * cos(theta) * r, _cCy + sin(theta) * r));
  }
  return points;
}

final List<_MoltenSeam> _seams = _buildSeams();

/// Dal kavşakları — kırıklar birleştiği yerde ısı birikir. Buralara akış
/// dalgasının tepe yapmasını beklemek yerine sabit bir sıcak nokta konur.
final List<Offset> _seamNodes = [];

List<_MoltenSeam> _buildSeams() {
  final seams = <_MoltenSeam>[];
  const bodyBox = Rect.fromLTRB(-6.4, -14, 6.4, 21);

  /// [from]'dan bir dal koparır ve kavşağı kaydeder.
  void branch(
    Offset from,
    double heading,
    double length,
    int steps,
    double seed,
    double weight,
  ) {
    _seamNodes.add(from);
    seams.add(
      _MoltenSeam(
        _fractureWalk(
          start: from,
          heading: heading,
          length: length,
          steps: steps,
          seed: seed,
        ),
        seed,
        weight,
      ),
    );
  }

  // Gövde boyunca omurga kırığı. KASTEN en sıcak yarık değil: merkez çizgide
  // dosdoğru parlak bir hat, siluetin tamamını düzleştirirdi.
  final spine = _fractureWalk(
    start: const Offset(0.6, -9),
    heading: pi / 2,
    length: 20,
    steps: 7,
    seed: 0.41,
    spread: 0.6,
    bounds: bodyBox,
  );
  seams.add(_MoltenSeam(spine, 0.4, 0.5));
  branch(spine[3], pi * 0.8, 7.5, 4, 1.31, 0.36);
  branch(spine[6], pi * 0.14, 6.5, 4, 2.13, 0.32);

  for (final side in const [-1.0, 1.0]) {
    final seed = side > 0 ? 3.8 : 2.7;
    final out = side > 0 ? 0.0 : pi; // outboard heading for this side

    // Hilal kolundan aşağı koşan ana kırık — birincil okuma budur.
    final arm = _ringFracture(
      side: side,
      theta0: -0.80,
      sweep: 1.26,
      r0: 30,
      steps: 12,
      seed: seed,
    );
    seams.add(_MoltenSeam(arm, seed, 1.0));

    // Çatallar. Gerçek kırıklar sert açıyla dallanır ve çabuk söner; ana kırığa
    // paralel koşmazlar.
    branch(arm[2], out - 0.55 * side, 8.5, 4, seed + 0.91, 0.52);
    branch(arm[5], out + pi * 0.85 * side, 7.0, 4, seed + 1.43, 0.42);
    branch(arm[8], out - 0.2 * side, 6.5, 3, seed + 2.27, 0.36);
    // Kılcallar: çatallardan çıkan kısa saç çizgileri ağa ÜÇÜNCÜ bir kademe
    // verir; elle çizilmiş bir kıvrım gibi okunmasını engelleyen şey budur.
    branch(arm[3], out + pi * 0.6 * side, 4.0, 2, seed + 3.11, 0.22);
    branch(arm[7], out + 0.35 * side, 3.6, 2, seed + 3.79, 0.2);
    branch(arm[10], out + pi * 0.75 * side, 4.4, 2, seed + 4.53, 0.24);

    // Kolun aşağısında ikinci bir kırık; böylece ağ
    // plakanın tamamını kırsın, uçta kümelenmesin.
    final keel = _ringFracture(
      side: side,
      theta0: 0.52,
      sweep: 0.95,
      r0: 27,
      steps: 9,
      seed: seed + 5.2,
    );
    seams.add(_MoltenSeam(keel, seed + 5.2, 0.62));
    branch(keel[3], out + pi * 0.7 * side, 5.0, 3, seed + 6.1, 0.28);
    branch(keel[6], out - 0.3 * side, 4.4, 2, seed + 6.9, 0.24);

    // Reaktörün yanında, gövde tarafında böğür yarığı.
    seams.add(
      _MoltenSeam(
        _fractureWalk(
          start: Offset(side * 7.0, 0.5),
          heading: pi / 2,
          length: 15,
          steps: 6,
          seed: seed + 1.67,
          spread: 0.5,
          bounds: Rect.fromLTRB(
            side > 0 ? 4.2 : -8.6,
            0,
            side > 0 ? 8.6 : -4.2,
            16,
          ),
        ),
        seed + 1.6,
        0.55,
      ),
    );
  }
  return seams;
}

/// Ortak genişlik profili.
///
/// Hem oyulmuş hendek hem eriyik dolgu buradan okur; böylece parıltı daima
/// yarığın TAM İÇİNDE oturur. Ayrıca çatlak iki ucunda da saç inceliğine iner —
/// yuvarlak uçlu sabit genişlikte bir çizgi, çatlağı sosis gibi gösteren şeydir.
double _seamWidth(double weight, double s) =>
    (0.32 + weight * 1.18) * (0.2 + 0.8 * pow(sin(s * pi), 0.5).toDouble());

/// Oyulmuş kanal — opak, zırhla birlikte çizilir. Bu olmadan parıltı plakanın
/// İÇİNDE değil ÜSTÜNDE durur.
///
/// Parça parça boyanır ki girinti mercek biçimli olsun; ve saf siyah yerine
/// sıcak bir siyaha yakın renkte: saf siyah kontur mürekkep gibi okunur, çelikte
/// gölgeli bir kesik gibi değil.
ui.Picture? _trenchCache;

/// Hendekler hiç kımıldamaz; bir kez kaydedilip tekrar oynatılır. Bu olmadan
/// gövde geçişi her karede birkaç yüz özdeş `drawLine` yeniden yayınlardı
/// yeniden yayınlardı.
void _seamTrenches(Canvas canvas) {
  canvas.drawPicture(_trenchCache ??= _recordTrenches());
}

ui.Picture _recordTrenches() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas
    ..save()
    ..clipPath(_armour);
  final soot = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x8A140805)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
  final cut = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xF00D0406);
  final lip = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x3FBAA695);

  for (final seam in _seams) {
    final points = seam.points;
    final last = points.length - 1;
    for (var i = 0; i < last; i++) {
      final w = _seamWidth(seam.weight, i / last);
      final a = points[i];
      final b = points[i + 1];
      soot.strokeWidth = w * 3.0;
      cut.strokeWidth = w * 1.75;
      lip.strokeWidth = w * 0.5;
      canvas
        // Kesiğin iki yanında yanık — plaka kırılmadan önce yanar.
        ..drawLine(a, b, soot)
        ..drawLine(a, b, cut)
        // Yontulmuş üst dudak anahtar ışığı yakalar ve derinliği satar.
        ..drawLine(
          a.translate(-w * 0.32, -w * 0.42),
          b.translate(-w * 0.32, -w * 0.42),
          lip,
        );
    }
  }
  canvas.restore();
  return recorder.endRecording();
}

/// Bir yarıktaki her sıcak öğe. Bloom geçişinin içinde koşar.
///
/// Her parça bir KESİT olarak boyanır — is omzu, koyu kızıl kütle, turuncu
/// gövde, ince beyaz çekirdek. Çünkü çatlağı eriyik gösteren şey, ENİNE değer
/// gradyanıdır. Tek genişlikte turuncu bir çizgi, üstüne ne kadar bloom atılırsa
/// atılsın çizilmiş bir çizgi gibi okunur.
void _seamEmissive(Canvas canvas, double time, double thrust) {
  // Yük: sürücü ısıyı zırha boşaltır, yani gemi ne kadar zorlarsa yarıklar o
  // kadar sıcak koşar. Efekt geminin durumunu okur.
  final load = 0.62 + 0.38 * thrust.clamp(0.0, 1.0);
  final breath = 0.5 + 0.5 * sin(time * 2.1);

  final bleed = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.2);
  final deep = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final body = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final core = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  canvas
    ..save()
    ..clipPath(_armour);

  for (final seam in _seams) {
    final points = seam.points;
    final last = points.length - 1;
    if (last < 1) continue;

    // Çevredeki plakaya ısı sızması — yarığın tamamı için
    // tek bulanık çizgi; parça başına blur aynı yumuşak hale için 10 kat pahalı.
    bleed
      ..strokeWidth = 3 + seam.weight * 9
      ..color = _heat(0.46, (0.21 + breath * 0.08) * load * seam.weight);
    canvas.drawPath(seam.path, bleed);

    for (var i = 0; i < last; i++) {
      final s = i / last;
      final w = _seamWidth(seam.weight, s);
      final a = points[i];
      final b = points[i + 1];

      // Eriyik akış: yay uzunluğu boyunca iki gezici dalga —
      // biri büyük sıcak cepler için kaba, diğeri onları kırmak için hızlı ve
      // ince. İkisi de -time ile hareket eder, yani ısı yarığın İÇİNDEN akar.
      // Kazanç eğrisi ise çatlağa sıcak/soğuk yayılımı verir; o olmadan her
      // parça ortalamanın etrafına düşer ve her yer eşit turuncu olur.
      final coarse = gFbm(s * 2.6 - time * 1.35 + seam.seed * 6.1);
      final fine = gNoise(s * 4.6 - time * 2.4 + seam.seed * 3.7);
      final hot = (0.5 + 0.5 * coarse) * (0.62 + 0.38 * (0.5 + 0.5 * fine));
      // İki uçta soğuk: çatlak inceldiği yerde ısı kaybeder.
      final taper = pow(sin(s * pi).clamp(0.0, 1.0), 0.6).toDouble();
      final t = ((0.1 + 0.28 * taper + 0.78 * pow(hot, 1.4)) * load)
          .clamp(0.0, 1.0)
          .toDouble();

      deep
        ..strokeWidth = w * 1.7
        ..color = _heat(0.26 + t * 0.16, 0.40 + t * 0.25);
      canvas.drawLine(a, b, deep);

      body
        ..strokeWidth = w * (0.42 + t * 0.5)
        ..color = _heat(0.42 + t * 0.34, 0.42 + t * 0.45);
      canvas.drawLine(a, b, body);

      // Çekirdek: beyazı yalnız en sıcak cepler hak eder. Göz böylece eşit bir
      // turuncu bulaşığa değil, birkaç noktaya çekilir.
      if (t > 0.72) {
        final k = (t - 0.72) / 0.28;
        core
          ..strokeWidth = w * (0.15 + k * 0.32)
          ..color = _heat(0.9 + k * 0.1, 0.45 + k * 0.55);
        canvas.drawLine(a, b, core);

        // Eriyik bir cep kendi yerel ışığını atar. Karneye bağlı:
        // aralığın tepesiyle sınırlı, yani her an ancak birkaç tane bulunur.
        if (k > 0.35) {
          canvas.drawCircle(
            Offset.lerp(a, b, 0.5)!,
            w * (1.4 + k * 1.6),
            Paint()
              ..blendMode = BlendMode.plus
              ..color = _heat(0.8, 0.14 * k)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
          );
        }
      }
    }
  }

  // Kavşak sıcak noktaları: kırıkların birleştiği yerde ısı birikir; ağa
  // akış nabızları arasında gözün kilitlenebileceği birkaç sabit çıpa verir.
  final node = Paint()..blendMode = BlendMode.plus;
  for (var i = 0; i < _seamNodes.length; i++) {
    final beat = 0.5 + 0.5 * sin(time * 3.1 + i * 1.37);
    node
      ..color = _heat(0.78 + beat * 0.22, (0.22 + beat * 0.3) * load)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.1 + beat * 0.6);
    canvas.drawCircle(_seamNodes[i], 0.7 + beat * 0.45, node);
  }
  canvas.restore();
}

void _drivePlume(Canvas canvas, double time, double thrust) => paintPlume(
  canvas,
  time: time,
  thrust: thrust,
  ramp: HeatRamp.molten,
  length: 1.55,
  jets: const [
    PlumeJet(Offset(-8, 26), power: 0.64),
    PlumeJet(Offset(0, 26)),
    PlumeJet(Offset(8, 26), power: 0.64),
  ],
);
// ── Heat haze ────────────────────────────────────────────────────────────

// TODO(vfx): bu, gerçek kırılmanın yerini tutuyor. Projeye ileride
// bir FragmentProgram hattı gelirse, arkaplanı örnekleyen bir yer değiştirme
// (displacement) shader'ıyla değiştirilmeli.
/// Fragment shader olmadan ucuz kırılma: bir titreşim bandı ÖN kenarında
/// parlak, ARKA kenarında koyudur. Bu ölçekte o ikili, yer değiştirmiş arkaplan
/// gibi okunur — ısı buğusu fiziksel olarak zaten budur.
void _heatHaze(Canvas canvas, double time, double thrust) {
  final motion = thrust.clamp(0.0, 1.0).toDouble();

  void band(Offset origin, double phase, double spread, double strength) {
    final rise = phase * spread;
    final w = 12 + phase * (16 + motion * 24);
    final h = 4 + phase * 8;
    final fade = (1 - phase) * strength * (phase < 0.14 ? phase / 0.14 : 1);
    if (fade <= 0.01) return;
    final rect = Rect.fromCenter(
      center: origin.translate(
        sin(time * 1.9 + phase * 6) * (1 + phase * 4),
        rise,
      ),
      width: w,
      height: h,
    );
    canvas
      ..drawArc(
        rect,
        pi * 0.08,
        pi * 0.84,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..blendMode = BlendMode.plus
          ..color = _heat(0.70, fade * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1),
      )
      ..drawArc(
        rect.shift(const Offset(0, 1.5)),
        pi * 0.08,
        pi * 0.84,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Color.fromARGB((fade * 105).round(), 2, 1, 3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
  }

  // Sürücüden çıkan — güçlü olan, itkiyle ölçeklenir.
  for (var i = 0; i < 4; i++) {
    band(
      const Offset(0, 25),
      (time * (0.44 + i * 0.05) + i * 0.25) % 1.0,
      30 + motion * 52,
      0.24 + motion * 0.44,
    );
  }
}

// ── Embers ───────────────────────────────────────────────────────────────

/// Yarıkların savurduğu kıvılcımlar. Her biri ömrü boyunca AYNI rampadan
/// soğur; böylece sürünün tek düz turuncu yerine bir sıcaklık yayılımı olur.
void _embers(Canvas canvas, double time, double thrust) {
  final motion = thrust.clamp(0.0, 1.0).toDouble();
  final wake = motion * motion * (3 - 2 * motion);
  final seams = _seams;

  for (var i = 0; i < 18; i++) {
    final seam = seams[i % seams.length];
    if (seam.points.isEmpty) continue;
    final source = seam.points[(i * 7 + 3) % seam.points.length];

    final speed = 0.15 + (i % 5) * 0.028 + motion * 0.13;
    final phase = (time * speed + i * 0.137) % 1.0;
    final life = sin(phase * pi).clamp(0.0, 1.0).toDouble();

    // Durgunken korlar dışa ve yavaşça kıça savrulur; itki altında iz kazanır ve
    // doğrudan geriye sürükler. İkisi arasında ara değerleme, itki başlarken
    // geçişin zıplamasını engeller.
    final angle = i * 2.399 + sin(i * 1.7) * 0.6;
    final idle = Offset(
      cos(angle) * phase * (6 + (i % 4) * 2.6),
      sin(angle) * phase * (5 + (i % 3) * 2.2) + phase * 3.5,
    );
    final drag = Offset(
      sin(time * (1.6 + i * 0.03) + i * 2.2) * (1.4 + phase * 4.6),
      phase * (30 + (i % 5) * 6 + motion * 30),
    );
    final p = source + Offset.lerp(idle, drag, wake)!;

    final temp = pow(1 - phase, 0.7).toDouble();
    final fade = pow(life, 1.5).toDouble() * (0.45 + motion * 0.55);
    final radius = 0.32 + (i % 3) * 0.14 + life * 0.22;

    // Önce hale, üstüne kıvılcım: bu boyutta çıplak bir nokta kaybolur.
    canvas.drawCircle(
      p,
      radius * 3.6,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _heat(0.5 + temp * 0.2, fade * 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );

    if (i % 5 == 0) {
      // Tükürülen kabuk: opak, takla atarak, siyaha yakın bir renge soğuyor.
      canvas.save();
      canvas
        ..translate(p.dx, p.dy)
        ..rotate(i * 0.73 + time * (0.8 + i * 0.04));
      canvas.drawPath(
        Path()
          ..moveTo(0, -radius * 1.9)
          ..lineTo(radius * 0.95, 0)
          ..lineTo(0, radius * 1.9)
          ..lineTo(-radius * 0.95, 0)
          ..close(),
        Paint()..color = _heat(0.18 + temp * 0.5, fade),
      );
      canvas.restore();
    } else {
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _heat(0.46 + temp * 0.54, fade),
      );
    }

    // Hareket esnemesi: hızlı bir kıvılcım nokta değil çizgidir. Çizgi
    // korun GERÇEK gidiş yönüne göre eğilir. Kusursuz dikey bir çizgi sütunu,
    // izdeki kıvılcım değil yağan yağmur gibi okunur.
    if (wake > 0.15 && i.isEven) {
      final tail = 1.8 + wake * (4.5 + motion * 4);
      final back = p.translate(-drag.dx * 0.06 * wake, -tail);
      canvas.drawLine(
        p,
        back,
        Paint()
          ..strokeWidth = 0.34 + temp * 0.26
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(p, back, [
            _heat(0.82, fade * 0.6),
            _heat(0.5, 0),
          ]),
      );
    }
  }
}

// ── Ambient heat ─────────────────────────────────────────────────────────

/// Gövdenin çevresindeki uzaya attığı korona. İki frekans kullanılır ki belirgin
/// bir döngüye oturmasın; enden çok boy verilir ki siluetin etrafında balon
/// yapmak yerine C halkasını takip etsin.
void _ambientHeat(Canvas canvas, double time, double thrust) {
  final motion = thrust.clamp(0.0, 1.0).toDouble();
  final pulse = 0.5 + 0.32 * sin(time * 1.7) + 0.18 * sin(time * 4.3 + 1.1);
  canvas
    ..drawOval(
      Rect.fromCenter(
        center: const Offset(0, -22),
        width: 74 + pulse * 6,
        height: 108 + pulse * 9,
      ),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _heat(0.44, 0.035 + pulse * 0.025 + motion * 0.015)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 17 + pulse * 3),
    )
    ..drawOval(
      Rect.fromCenter(
        center: const Offset(0, -38),
        width: 62 + pulse * 4,
        height: 62 + pulse * 4,
      ),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _heat(0.58, 0.032 + pulse * 0.022)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
}

// ── Armour ───────────────────────────────────────────────────────────────

void _paintPlate(Canvas canvas, Path path) {
  final bounds = path.getBounds();
  canvas
    ..drawPath(
      path.shift(const Offset(2.5, 4.5)),
      Paint()
        ..color = const Color(0xD6000103)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    )
    ..drawPath(
      path.shift(const Offset(0, 2.2)),
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          const [Color(0xFF1F2227), Color(0xFF0D0E12), Color(0xFF010204)],
          const [0, 0.52, 1],
        ),
    )
    ..drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          _plateMetal,
          const [0, 0.4, 1],
        ),
    );

  // Yanık, düzensiz yüzey kırılması. Düşük kontrastlı is plakanın içinde kalır
  // ve gövdenin temiz bir vektör çıkartması gibi okunmasını engeller.
  canvas
    ..save()
    ..clipPath(path);
  for (var i = 0; i < 4; i++) {
    final px = bounds.left + bounds.width * (0.16 + i * 0.24);
    final py =
        bounds.top +
        bounds.height * (0.25 + 0.16 * sin(i * 2.4 + bounds.width));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px, py),
        width: 7 + (i % 2) * 5,
        height: 3.5 + (i % 3) * 2,
      ),
      Paint()
        ..color = const Color(0x44100008)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }
  canvas.restore();

  canvas
    // Zırhın yansıttığı eriyik ışık — çepeçevre düzgün turuncu bir kenar değil.
    ..drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          const Offset(0, 2),
          75,
          [_heat(0.62, 0.17), _heat(0.78, 0.05), _heat(0.6, 0)],
          const [0, 0.34, 1],
        ),
    )
    ..drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          bounds.topLeft + Offset(bounds.width * 0.27, bounds.height * 0.18),
          max(bounds.width, bounds.height) * 0.72,
          const [Color(0x24FFFFFF), Color(0x00FFFFFF)],
        ),
    )
    ..drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          const [
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x30E6EEF7),
            Color(0x00FFFFFF),
          ],
          const [0, 0.30, 0.40, 0.52],
        ),
    )
    ..drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round
        ..color = _plateEdge,
    )
    // Sıçrama ışığı: reaktöre bakan kenarlar eriyik rengi alır.
    // çepeçevre düz turuncu bir kenar metal okumasını öldürürdü; bu yüzden
    // düzgün bir çizgi değil, çekirdeğe merkezlenmiş radyal bir shader.
    ..drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          const Offset(0, 4),
          44,
          [_heat(0.78, 0.30), _heat(0.6, 0.08), _heat(0.5, 0)],
          const [0, 0.45, 1],
        ),
    )
    ..drawPath(
      path.shift(const Offset(-0.25, -0.35)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x668F99A2),
    );
}

// ── Reactor ──────────────────────────────────────────────────────────────

/// Opak çerçeve — zırhla birlikte, emissive geçişten ÖNCE çizilir.
void _reactorHousing(Canvas canvas) {
  const center = Offset(0, 7);
  canvas
    ..drawCircle(center, 4.6, Paint()..color = const Color(0xFF07080B))
    ..drawCircle(
      center,
      4.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFFB58A66),
    );
}

/// Reaktörün ışığı. Yarıklarla birlikte bloom geçişinin içinde koşar; böylece
/// gövde ve çekirdek birbiriyle kavga etmek yerine tek bir bloom paylaşır.
void _reactorEmissive(Canvas canvas, double time) {
  const center = Offset(0, 7);
  final pulse = 0.5 + 0.5 * sin(time * 5.4);

  canvas
    ..drawCircle(
      center,
      7.5 + pulse * 1.4,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _heat(0.55, 0.28 + pulse * 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + pulse),
    )
    ..drawCircle(
      center,
      3.3,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          center.translate(-0.8, -0.8),
          4.2,
          [_heat(1.0), _heat(0.84), _heat(0.46)],
          const [0, 0.38, 1],
        ),
    )
    // Karedeki ikinci en parlak noktada mercek çizgisi.
    ..drawOval(
      Rect.fromCenter(center: center, width: 21 + pulse * 5, height: 1.1),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _heat(0.9, 0.22 + pulse * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

  for (var i = 0; i < 3; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 5.2 + i * 1.45),
      time * (1.8 - i * 0.25) + i * 2.1,
      0.7 + i * 0.18,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus
        ..color = _heat(0.66 + i * 0.09, 0.85),
    );
  }
  canvas.drawCircle(
    center.translate(-0.55, -0.7),
    0.8 + pulse * 0.25,
    Paint()
      ..blendMode = BlendMode.plus
      ..color = Colors.white,
  );
}

void _spinalMount(Canvas canvas) {
  final base = RRect.fromRectAndRadius(
    const Rect.fromLTRB(-6.5, 9, 6.5, 20),
    const Radius.circular(3),
  );
  canvas
    ..drawRRect(
      base.shift(const Offset(0, 2)),
      Paint()..color = const Color(0xCC05080A),
    )
    ..drawRRect(
      base,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-6, 9),
          const Offset(6, 20),
          const [Color(0xFF60636A), Color(0xFF27252A), Color(0xFF090A0D)],
          const [0, 0.5, 1],
        ),
    )
    ..drawRRect(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF0A0D10),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-1.1, 11, 1.1, 18.5),
        const Radius.circular(1),
      ),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _heat(0.86)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1),
    );
}

// ── Plate geometry ───────────────────────────────────────────────────────
// Bir kez kurulup paylaşılır ki
// aşağıdaki zırh maskesinin, plakaların gerçekten boyadığı siluetin aynısı
// olması garanti olsun.

Path _bodyPath() => Path()
  ..moveTo(5, _cCy + _cRo)
  ..lineTo(8, -4)
  ..lineTo(9, 10)
  ..lineTo(7, 20)
  ..lineTo(4, 26)
  ..lineTo(-4, 26)
  ..lineTo(-7, 20)
  ..lineTo(-9, 10)
  ..lineTo(-8, -4)
  ..lineTo(-5, _cCy + _cRo)
  ..close();

/// C halkası — ağzı ileri bakar; iç kenar dış kenardan daha ileri uzanır,
/// pruvaya kancasını veren şey budur.
Path _ringPath() {
  const center = Offset(0, _cCy);
  const aROut = -pi / 2 + _cBetaOut;
  const aLIn = -pi / 2 - _cBetaIn;
  const sweepOut = 2 * pi - 2 * _cBetaOut;
  const sweepIn = 2 * pi - 2 * _cBetaIn;
  return Path()
    ..arcTo(
      Rect.fromCircle(center: center, radius: _cRo),
      aROut,
      sweepOut,
      true,
    )
    ..lineTo(center.dx + cos(aLIn) * _cRi, center.dy + sin(aLIn) * _cRi)
    ..arcTo(
      Rect.fromCircle(center: center, radius: _cRi),
      aLIn,
      -sweepIn,
      false,
    )
    ..close();
}

Offset _onArc(double angle, double radius) =>
    Offset(cos(angle) * radius, _cCy + sin(angle) * radius);

/// C'nin [m]=±1 dış kenarındaki balık yüzgeci.
Path _finPath(double m) {
  const aFin = -pi / 2 + _cBetaOut + _cFinBack;
  Offset mx(Offset p) => Offset(p.dx * m, p.dy);
  final r1 = mx(_onArc(aFin - 0.32, _cRo));
  final r2 = mx(_onArc(aFin + 0.32, _cRo));
  final tip = mx(_onArc(aFin, _cRo + _cFinLen));
  final lead = mx(_onArc(aFin - 0.12, _cRo + _cFinLen * 0.7));
  final trail = mx(_onArc(aFin + 0.16, _cRo + _cFinLen * 0.4));
  return Path()
    ..moveTo(r1.dx, r1.dy)
    ..quadraticBezierTo(lead.dx, lead.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(trail.dx, trail.dy, r2.dx, r2.dy)
    ..close();
}

Path _wingPath(double m) => Path()
  ..moveTo(m * 4, 4)
  ..lineTo(m * 20, 9)
  ..lineTo(m * 18, 15)
  ..lineTo(m * 5, 15)
  ..close();

/// Bütün plakaların birleşimi. Eriyik geçiş buna clip'lenir: bir kırık, yarması
/// gereken zırhın DIŞINA asla taşamaz. Parıltı yine dışarı sızar, ama yalnız
/// bloom katmanı üzerinden — ısı zaten böyle davranır.
final Path _armour =
    [
      _ringPath(),
      _finPath(-1),
      _finPath(1),
      _wingPath(-1),
      _wingPath(1),
    ].fold<Path>(
      _bodyPath(),
      (acc, part) => Path.combine(PathOperation.union, acc, part),
    );

/// Yalnız zırh — plakalar, oyulmuş hendekler, sert yuvalar. Her emissive öğe
/// KASTEN [Bastion.paint] içindeki bloom geçişine bırakılmıştır.
void _paintHull(Canvas canvas) {
  _engineBlock(canvas);
  _paintPlate(canvas, _bodyPath());
  _paintPlate(canvas, _ringPath());

  const aFin = -pi / 2 + _cBetaOut + _cFinBack;
  for (final m in const [-1.0, 1.0]) {
    _paintPlate(canvas, _finPath(m));
    Offset mx(Offset p) => Offset(p.dx * m, p.dy);
    final r1 = _onArc(aFin - 0.32, _cRo);
    final r2 = _onArc(aFin + 0.32, _cRo);
    final tip = _onArc(aFin, _cRo + _cFinLen);
    final baseMid = Offset((r1.dx + r2.dx) / 2, (r1.dy + r2.dy) / 2);
    for (final t in const [0.45, 0.8]) {
      canvas.drawLine(
        mx(baseMid),
        mx(
          Offset(
            baseMid.dx + (tip.dx - baseMid.dx) * t,
            baseMid.dy + (tip.dy - baseMid.dy) * t,
          ),
        ),
        Paint()
          ..strokeWidth = 0.7
          ..color = _panelSeam,
      );
    }
  }

  // Spine + flank panel lines.
  canvas.drawLine(
    const Offset(0, -2),
    const Offset(0, 22),
    Paint()
      ..strokeWidth = 1
      ..color = _panelSeam,
  );
  for (final m in const [-1.0, 1.0]) {
    canvas.drawLine(
      Offset(m * 5.5, 2),
      Offset(m * 5, 18),
      Paint()
        ..strokeWidth = 0.65
        ..color = const Color(0x887D4535),
    );
  }

  _seamTrenches(canvas);
  _paintPlate(canvas, _wingPath(-1));
  _paintPlate(canvas, _wingPath(1));
  // Silah yuvaları BURADA DEĞİL: kendi atlas bloklarında pişiyorlar, çünkü
  // sayıları oyuncunun taktığı lazere göre değişiyor (bkz.
  // [Bastion.paintEmitter]). Gövdeye pişirilseydi her namlu sayısı için ayrı
  // bir gövde ızgarası gerekirdi — dört itki × dört faz × dört donanım
  // kademesi, ve atlas 4096 piksel tavanını aşardı.
  _reactorHousing(canvas);
  _spinalMount(canvas);
  _runningLight(canvas, const Offset(-19.5, 9.5), const Color(0xFFFF5050));
  _runningLight(canvas, const Offset(19.5, 9.5), const Color(0xFF3DDB7D));
}

/// Bir silah yuvasının TAMAMI — çelik kaide, enerji ve kendi bloom geçişi.
///
/// **YEREL uzayda çizer:** kaide orijinde, namlu −y'de. Yuvanın gemideki YERİ
/// burada uygulanmıyor. Sebep mimari: her yuva atlasta kendi hücresine
/// pişiyor ve gemideki konumu çizim anında `RSTransform` veriyor. Gemide kaç
/// topun görüneceğinin ÇALIŞMA ZAMANINDA kararlaştırılabilmesinin tek sebebi
/// bu ayrım.
///
/// **Kendi bloom'u.** Eskiden yuvalar gövdenin tek bloom geçişinin içindeydi;
/// ayrı hücreye taşınınca kendi geçişleri gerekiyor. Bulanıklık aynı sigmayla
/// ve aynı tuval ölçeğinde uygulandığı için görünen sonuç değişmiyor —
/// değişen tek şey, parıltının artık gövdenin değil yuvanın hücresine
/// pişmesi.
///
/// Ateş anı burada YOK: namlu koru ve mermiler çalışma zamanında çizilir.
void _paintEmitter(Canvas canvas, int index, double time) {
  final length = Bastion.emitterLengths[index];
  final width = Bastion.emitterWidths[index];
  WeaponEmitter.paintFrame(canvas, length: length, width: width);
  bloom(canvas, Bastion.emitterBounds, () {
    WeaponEmitter.paintEmissive(
      canvas,
      length: length,
      width: width,
      // Faz yuvaya göre kaydırılır: beş projektör aynı anda nabız atarsa gemi
      // tek bir organizma gibi soluk alıp verir ve göz onu hareketin
      // kendisinden önce yakalar.
      time: time + index * 0.37,
    );
  });
}

/// Seyir feneri — burun ışığı YOK, çünkü burun C'nin açık ağzı.
///
/// Hale kasten additive DEĞİL: fenerler bir konum göstergesi, bir ısı kaynağı
/// değil. Additive olsaydı zırhın üstünde parlar ve lav çatlaklarıyla aynı
/// dilde konuşmaya başlardı.
void _runningLight(Canvas canvas, Offset at, Color color) {
  canvas
    ..drawCircle(
      at,
      2.64,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    )
    ..drawCircle(at, 1.2, Paint()..color = color);
}

/// Kıç motor bloğu — üç nozzle yuvası. Pluma bunların ağzından çıkar.
void _engineBlock(Canvas canvas) {
  final block = Path()
    ..moveTo(-9, 15)
    ..lineTo(-12, 26)
    ..lineTo(12, 26)
    ..lineTo(9, 15)
    ..close();
  canvas
    ..drawPath(
      block,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 15),
          const Offset(0, 26),
          [const Color(0xFF5A6470), const Color(0xFF13171E)],
        ),
    )
    ..drawLine(
      const Offset(-9, 15),
      const Offset(9, 15),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFF9AA6B2),
    );
  for (final dx in const [-4.0, 4.0]) {
    canvas.drawLine(
      Offset(dx, 16.5),
      Offset(dx * 1.25, 25),
      Paint()
        ..strokeWidth = 0.8
        ..color = const Color(0x55080A0E),
    );
  }
  canvas.drawPath(
    block,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF090B10),
  );
  for (final dx in const [-8.0, 0.0, 8.0]) {
    canvas
      ..drawCircle(Offset(dx, 25), 3, Paint()..color = const Color(0xFF4C5660))
      ..drawCircle(
        Offset(dx, 24.6),
        2.7,
        Paint()..color = const Color(0xFF262C34),
      )
      ..drawCircle(
        Offset(dx, 25),
        1.9,
        Paint()..color = const Color(0xFF0A0C10),
      )
      ..drawCircle(
        Offset(dx, 25),
        1.6,
        Paint()
          // Nozzle lambası sabit bir armatür rengi, sıcaklık rampasının bir
          // örneği değil: ateşlenmemiş bir motorda da aynı tonda yanar.
          ..color = const Color(0xCCFFB24D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      )
      ..drawCircle(
        Offset(dx, 25),
        0.9,
        Paint()..color = const Color(0xFFFFE9B0),
      );
  }
}

/// Bastion'un çizim yüzeyi.
///
/// Tasarım uzayı gemi-merkezlidir ve −y ileridir. Ölçek/merkezleme çağıranın
/// işi ([reach] ve [centreOffset] ile) — böylece aynı çizim hem oyunda hem
/// önizlemede aynı oranlarla çıkar.
abstract final class Bastion {
  /// Çizimin taştığı sınır (tasarım uzayı, merkez ofseti UYGULANMADAN).
  static Rect get fxBounds => _publicFxBounds;

  /// Burnun (C pruvası) merkeze uzaklığı.
  static final double _forward = () {
    final fwd = (_cCy - _cRi * cos(_cBetaIn)).abs();
    return fwd > _cRear ? fwd : _cRear;
  }();

  /// Silah yuvalarının GÖVDEDEKİ yerleri (tasarım uzayı, −y ileri).
  ///
  /// Sıra sabittir: 0-1 yüzgeç çifti (C kollarında), 2 merkez top, 3-4 kanat
  /// çifti. Yüzgeç yuvaları C halkasının geometrisinden TÜRETİLİR — halka
  /// oynarsa yuva da oynar, elle eşitlenmesi gereken ikinci bir sayı yok.
  static final List<Offset> hardpoints = [
    _finMount(-1),
    _finMount(1),
    const Offset(0, 2),
    const Offset(-14, 9),
    const Offset(14, 9),
  ];

  /// [hardpoints] ile aynı sırada projektör boyları (tasarım uzayı).
  ///
  /// Merkez top daha uzun ve geniş: omurga silahı, yan yuvalar değil.
  static const List<double> emitterLengths = [18, 18, 26, 18, 18];
  static const List<double> emitterWidths = [9, 9, 13, 9, 9];

  /// Merminin çıktığı noktalar — projektörün namlu AĞZI, kaidesi değil.
  ///
  /// Hesap [WeaponEmitter]'dan geliyor: yuvanın nerede bittiğini çizen ile
  /// mermiyi oradan başlatan aynı sayıyı okumak zorunda, yoksa ateş silahtan
  /// değil havadan çıkar.
  static final List<Offset> muzzles = [
    for (var i = 0; i < hardpoints.length; i++)
      hardpoints[i] + WeaponEmitter.muzzleOf(emitterLengths[i]),
  ];

  /// Yuvaların GEMİ-YEREL DÜNYA konumları — projektörün çizildiği yer.
  ///
  /// [worldMuzzles] merminin ÇIKTIĞI nokta (namlu ağzı), bu ise projektörün
  /// OTURDUĞU nokta (kaide). İkisi bir emitter boyu kadar ayrı ve ikisi de
  /// gerekli: biri mermiyi doğuruyor, diğeri silahı çiziyor.
  static final List<Offset> worldHardpoints = [
    for (final h in hardpoints) AtlasLayout.designToWorld(h, centreOffset),
  ];

  /// Bir projektörün çizim sınırı (tasarım uzayı, kaide orijinde).
  ///
  /// Bloom geçişinin `saveLayer` kutusu ve atlas hücresinin ölçüsü buradan
  /// çıkıyor. En BÜYÜK yuvaya (merkez top) göre: hepsi aynı hücre boyunu
  /// paylaşıyor, çünkü ayrı boy sadece birkaç kilobayt kazandırır ve iki ayrı
  /// çapa yönetmek gerektirirdi.
  ///
  /// Ölçülen değil TÜRETİLEN: aura yarıçapı `L·0.55` + bulanıklık `L·0.18`,
  /// namlu merceği `−L`'de ve parlaması `w·0.34·1.2·2.2`. En büyük yuvada
  /// (L=26, w=13) bu, yukarıda ~38 tasarım birimi ediyor; pay bırakıldı.
  /// `tool/atlas_bounds_test.dart` beyanın gerçekten yettiğini ÖLÇÜYOR.
  static const Rect emitterBounds = Rect.fromLTRB(-28, -50, 28, 24);

  /// Yuvaların AÇILMA sırası — bu gövdenin bildirdiği tek şey.
  ///
  /// Önce omurga silahı (merkez top), sonra yüzgeç çifti, sonra kanat çifti:
  /// içten dışa. Kararı veren kural [Armament.active]'te ve gövdeye ait
  /// değil; burada yalnız DİZİLİŞ var. İkinci gövde geldiğinde yazacağı tek
  /// şey de bu liste olacak.
  ///
  /// Gruplar ÇİFT: bir çiftin yalnız yarısını yakmak gemiyi tek kanadı eksik
  /// gösterirdi.
  static const List<List<int>> mountGroups = [
    [2],
    [0, 1],
    [3, 4],
  ];

  /// Lazer sayısı → açık yuvalar, ÖNCEDEN hesaplanmış.
  ///
  /// [Armament.active] her çağrıda yeni bir liste kuruyor ve bu liste kare
  /// yolunda okunuyor: gemi başına bir kez `ShipSwarm`'da, bir kez de ateş
  /// eden her gemi için `CombatLayer`'da. Kırk gemi × 120 Hz = saniyede ~5000
  /// kısa ömürlü liste, ve Dart'ın çöp toplayıcısı duraklattığında
  /// duraklattığı şey tam olarak kare döngüsü.
  ///
  /// Tablo altı satır (0..5) ve süreç ömrü boyunca yaşıyor.
  static final List<List<int>> _byLasers = [
    for (var n = 0; n <= Armament.mountCount(mountGroups); n++)
      List.unmodifiable(Armament.active(mountGroups, n)),
  ];

  /// [lasers] lazer takılıyken HANGİ yuvaların silahı var.
  ///
  /// Tahsis YOK: tablodan okuma. Sınır dışı bir sayı kırpılıyor — yedi yuvalı
  /// bir gövdeden gelen "7" bu sanatta beş kaideye denk düşer.
  static List<int> activeHardpoints(int lasers) =>
      _byLasers[lasers.clamp(0, _byLasers.length - 1)];

  /// Bir silah yuvasını YEREL uzayda çizer — atlas pişiricinin girişi.
  static void paintEmitter(
    Canvas canvas, {
    required int index,
    required double time,
  }) => _paintEmitter(canvas, index, time);

  /// Namlu ağızları GEMİ-YEREL DÜNYA biriminde — merminin doğduğu yer.
  ///
  /// Tasarım uzayından dünyaya geçişin TEK yeri burası. Çağıranın kendi
  /// çevrimini yazması, atlasın kullandığı `centreOffset` kaydırmasını
  /// atlamasına yol açtı: ağızlar 26 birim burna kayıyordu.
  static final List<Offset> worldMuzzles = [
    for (final m in muzzles) AtlasLayout.designToWorld(m, centreOffset),
  ];

  static Offset _finMount(double m) {
    const rad = _cRo + _cFinLen * 0.5;
    return Offset(m * cos(_cAFin) * rad, _cCy + sin(_cAFin) * rad);
  }

  /// Ortalanmış yarı-açıklık — geminin ekranda kapladığı yarıçap budur.
  static double get reach => (_forward + _cRear) / 2;

  /// Gövdeyi orijine oturtan dikey kaydırma.
  static double get centreOffset => (_forward - _cRear) / 2;

  /// Bir kareyi çizer. [thrust] 0..1 — hem plumayı hem çatlak sıcaklığını
  /// sürer, yani geminin durumu efektten okunur.
  ///
  /// Çizim sırası işin tamamı: önce SOĞUK zırh, sonra bütün sıcak öğeleri tek
  /// seferde taşıyan additive bloom geçişi. Kare başına iki `saveLayer`, şekil
  /// başına bir blur değil.
  ///
  /// Yalnız referans ve önizleme için: oyun katmanları ayrı ayrı, atlastan
  /// çizer ([paintEngine] / [paintHull] / [paintEmitter]).
  ///
  /// [lasers] takılı lazer sayısı. Zorunlu ve varsayılanı YOK: gemide kaç top
  /// olduğu artık bir gerçek, çağıranın söylemesi gereken bir şey. Sessiz bir
  /// varsayılan koysaydık, önizlemeler oyunda görülmeyen bir gemi çizmeye
  /// devam eder ve fark ancak ekranda görülürdü.
  static void paint(
    Canvas canvas, {
    required double time,
    required double thrust,
    required int lasers,
  }) {
    paintEngine(canvas, time: time, thrust: thrust);
    paintHull(canvas, time: time, thrust: thrust);
    // Sıra atlasın kompozit sırasıyla aynı: yuvalar gövdenin ÜSTÜNDE.
    for (final index in activeHardpoints(lasers)) {
      final at = hardpoints[index];
      canvas
        ..save()
        ..translate(at.dx, at.dy);
      paintEmitter(canvas, index: index, time: time);
      canvas.restore();
    }
  }

  /// ARKA katman: yalnız egzoz pluması.
  ///
  /// Katmanlar "motor parçası / gövde parçası" diye değil, **opak gövdenin
  /// önünde mi arkasında mı** diye ayrılır — atlas onları bu sırayla üst üste
  /// koyduğu için tek doğru bölme budur.
  ///
  /// Burada yalnız pluma var, çünkü yalnız pluma itki sıfırken GERÇEKTEN
  /// görünmez. Duran bir gemide bu katman atlanabilir ve hiçbir şey kaybolmaz;
  /// ortam koronası ise duran gemide de duruyor, o yüzden gövde katmanında.
  static void paintEngine(
    Canvas canvas, {
    required double time,
    required double thrust,
  }) {
    _drivePlume(canvas, time, thrust);
  }

  /// ÖN katman: ortam koronası, soğuk zırh, tek bloom geçişinde bütün sıcak
  /// öğeler ve en üstte ısı buğusu.
  static void paintHull(
    Canvas canvas, {
    required double time,
    required double thrust,
  }) {
    // Sıra prosedürel orijinalin aynısı: korona zırhın ARKASINDA (opak plakalar
    // onu keser), buğu ise EN ÜSTTE (gövdenin üstünden geçer).
    _ambientHeat(canvas, time, thrust);
    _paintHull(canvas);
    bloom(canvas, _fxBounds, () {
      _seamEmissive(canvas, time, thrust);
      _reactorEmissive(canvas, time);
      _embers(canvas, time, thrust);
    });
    _heatHaze(canvas, time, thrust);
  }
}
