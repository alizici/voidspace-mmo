import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'armament.dart';
import 'atlas_layout.dart';
import 'drive_plume.dart';
import 'heat_ramp.dart';
import 'vfx.dart';
import 'weapon_emitter.dart';

// ═════════════════════════════════════════════════════════════════════════
// Goliath X — çapraz omurga, ark plazması VFX kiti
// ═════════════════════════════════════════════════════════════════════════
//
// Bu gövde [Bastion]'ın İKİZİ DEĞİL, KARŞITI. İkisi de aynı emissive yığınını
// (tek rampa · kabuk/gövde/çekirdek · tek bloom geçişi) kullanıyor ama
// anlattıkları şey ayrı:
//
//  · Bastion ERİYİK bir gemi: zırhı çatlamış, ısı kırıklardan sızıyor.
//    Emissive dili KIRIK — rastgele yürüyen, gövdeye ait olmayan bir yarık ağı.
//  · Goliath X YÜKLÜ bir gemi: zırhı sağlam, enerji hatlardan AKIYOR.
//    Emissive dili HAT — reaktörden çıkıp silahlara giden düz, panele oturan
//    kanallar. Gözün gördüğü hareket rastgele değil YÖNLÜ: yük hep dışa gider.
//
// Adındaki X bir süs değil, gövdenin taşıyıcı yapısı: iki uzun çapraz kol
// çekirdeğin üstünde kesişiyor, pruva bıçaklarını kıç kanatlarına bağlıyor ve
// reaktör tam o kavşakta duruyor. Silüetin okunması gereken tek şey bu — bu
// yüzden hem zırhın en kalın yeri hem de en parlak hattı orası.
//
// Ölçü tek yönlü: sanat → kayıt. [GoliathX.reach] ve [GoliathX.centreOffset]
// zırh yolunun sınır kutusundan ÇALIŞMA ZAMANINDA çıkıyor; elle yazılmış bir
// sayı bir gün çizimden sessizce ayrışırdı (kayıt dosyası bu dersi zaten
// almış: `GovdeTasarimlari.hepsi`'nin tepe girdisi de ölçüsünü sanattan okur).

// ── Sıcaklık rampası ─────────────────────────────────────────────────────

/// Ark plazması — Goliath X'in kimliği.
///
/// [HeatRamp.molten]'ın yanına konması gereken yer `heat_ramp.dart`; ikinci bir
/// gövde bu rampayı ödünç aldığı gün oraya taşınmalı. Bugün TEK kullanıcısı
/// var ve rampa gövdenin kimliği olduğu için burada duruyor.
///
/// Kural rampanın kendisinde yazılı ve burada da geçerli: değer yukarı
/// çıkarken renk sıcaklığı da çıkıyor. Beyaz yine karneye bağlı — yalnız
/// reaktör çekirdeği, nozzle boğazı ve yükün tepe noktası oraya ulaşır.
const _arkRampasi = HeatRamp(
  [0.0, 0.18, 0.38, 0.58, 0.78, 0.91, 1.0],
  [
    Color(0xFF04060F), // sönük hat
    Color(0xFF161046), // mor kabuk
    Color(0xFF3320C8), // indigo
    Color(0xFF4B63F5), // ark moru
    Color(0xFF2FB6FF), // ark mavisi
    Color(0xFFA6ECFF), // buz çekirdeği
    Color(0xFFF4FDFF), // beyaz-sıcak
  ],
);

/// Bu gövdenin bütün emissive rengi TEK rampadan gelir.
Color _ark(double t, [double alpha = 1]) => _arkRampasi.at(t, alpha);

/// Zırh paleti — Bastion'ınkinden KASTEN daha soğuk.
///
/// Bastion'da metalin en açık değeri sıcak bir kenardı (`_plateEdge`
/// kehribar); burada titanyum-mavi. Sebep okunabilirlik: emissive dil zaten
/// mavi-mor, kenar da kehribar olsaydı iki dil birbiriyle kavga ederdi. Soğuk
/// kenar, sıcak hattı kontrast olarak DESTEKLİYOR.
const _plakaMetal = [Color(0xFF6B7590), Color(0xFF191E2A), Color(0xFF03050A)];
const _plakaKenari = Color(0xB07E92B6);
const _panelDikisi = Color(0xCC060810);

// ── Gövde geometrisi ─────────────────────────────────────────────────────
// Tek doğruluk kaynağı: zırh yolu, kanal ağı, silah kaideleri ve geminin
// ekran ölçüsü hep buradan türüyor.

/// Çekirdek gövdenin burnu ve kıçı.
const double _burun = -46, _kic = 30;

/// Pruva bıçağının ucu — geminin en ileri noktası, ileri erişimi bu belirler.
const double _bicakUcu = -63;

/// Kıç kanadının en dış noktası — geminin görsel AĞIRLIĞI buradan geliyor.
const double _kanatUcu = 44;

/// X kolunun uçları, m=+1 tarafı için. Kol ÇAPRAZ: ön ucu sağdaysa arka ucu
/// solda. Silueti X yapan tek şey bu işaret farkı.
const Offset _kolOn = Offset(31, -45), _kolArka = Offset(-37, 21);

/// İki kolun kesiştiği nokta — reaktör burada.
///
/// SİMETRİDEN çözülüyor, elle yazılmıyor: kollar birbirinin aynası olduğu için
/// kesişim x=0'da ve y'si tek bir orandan çıkıyor. Kol uçları oynadığında
/// reaktör kendiliğinden onunla birlikte oynuyor; elle yazılmış bir y, kolları
/// bir kez ayarladıktan sonra reaktörü havada bırakırdı.
final Offset _kavsak = () {
  final t = _kolOn.dx / (_kolOn.dx - _kolArka.dx);
  return Offset(0, _kolOn.dy + (_kolArka.dy - _kolOn.dy) * t);
}();

/// Kolun [m] tarafındaki ön/arka uç noktaları.
Offset _kolUcu(double m, bool on) =>
    Offset((on ? _kolOn : _kolArka).dx * m, (on ? _kolOn : _kolArka).dy);

// ── Plaka geometrisi ─────────────────────────────────────────────────────
// Bir kez kurulup paylaşılıyor ki zırh maskesi, plakaların gerçekten boyadığı
// siluetin aynısı olsun.

/// Çekirdek gövde — dar, uzun, kendi başına neredeyse silahsız bir omurga.
Path _govdeYolu() => Path()
  ..moveTo(0, _burun)
  ..lineTo(9, -32)
  ..lineTo(15, -8)
  ..lineTo(16, 12)
  ..lineTo(13, _kic - 2)
  ..lineTo(-13, _kic - 2)
  ..lineTo(-16, 12)
  ..lineTo(-15, -8)
  ..lineTo(-9, -32)
  ..close();

/// Pruva bıçağı — İLERİ süpürülmüş. Kanat değil bıçak: ucu sivri, arkası geniş.
///
/// İleri süpürme bir sanat kararı ve okunması gereken şey şu: ağır bir gemi
/// ileri gitmek zorunda. Geriye süpürülmüş bir pruva Goliath'ı bir avcıya
/// benzetirdi.
Path _bicak(double m) => Path()
  ..moveTo(m * 9, -30)
  ..lineTo(m * 19, _bicakUcu)
  ..lineTo(m * 27, -55)
  ..lineTo(m * 33, -38)
  ..lineTo(m * 34, -22)
  ..lineTo(m * 26, -12)
  ..lineTo(m * 12, -14)
  ..close();

/// Kıç kanadı — GERİ süpürülmüş, bıçağın tersi. X'in alt yarısı bu.
Path _kanat(double m) => Path()
  ..moveTo(m * 12, -6)
  ..lineTo(m * 38, 8)
  ..lineTo(m * _kanatUcu, 22)
  ..lineTo(m * 30, 26)
  ..lineTo(m * 18, 28)
  ..lineTo(m * 13, 16)
  ..close();

/// X'in bir kolu — ortada kalın, uçlarda ince taşıyıcı kiriş.
///
/// Kalınlık kavşakta zirve yapıyor çünkü yükü orada taşıyor; ucunda incelmesi
/// hem yapısal olarak doğru hem de silueti bir çarpıdan bir GEMİYE çeviren şey.
Path _kolYolu(double m) {
  final a = _kolUcu(m, true);
  final b = _kolUcu(m, false);
  final yon = (b - a) / (b - a).distance;
  final dik = Offset(-yon.dy, yon.dx);
  final orta = Offset.lerp(a, b, 0.5)!;
  const ucYari = 2.4, ortaYari = 5.4;
  return Path()
    ..moveTo(a.dx + dik.dx * ucYari, a.dy + dik.dy * ucYari)
    ..lineTo(orta.dx + dik.dx * ortaYari, orta.dy + dik.dy * ortaYari)
    ..lineTo(b.dx + dik.dx * ucYari, b.dy + dik.dy * ucYari)
    ..lineTo(b.dx - dik.dx * ucYari, b.dy - dik.dy * ucYari)
    ..lineTo(orta.dx - dik.dx * ortaYari, orta.dy - dik.dy * ortaYari)
    ..lineTo(a.dx - dik.dx * ucYari, a.dy - dik.dy * ucYari)
    ..close();
}

/// Kıç motor bloğu — dört nozzle yuvası. Pluma bunların ağzından çıkıyor.
Path _motorYolu() => Path()
  ..moveTo(-12, 15)
  ..lineTo(-20, _kic)
  ..lineTo(20, _kic)
  ..lineTo(12, 15)
  ..close();

/// Bütün plakaların birleşimi.
///
/// İki işi var ve ikisi de kritik. Biri MASKE: enerji hatları buna clip'leniyor
/// (bir kanal, taşıdığı zırhın dışına çıkamaz — parıltı yine sızar ama yalnız
/// bloom katmanı üzerinden, ısı zaten böyle davranır). Diğeri ÖLÇÜ: geminin
/// erişimi bu yolun sınır kutusundan okunuyor.
final Path _zirh =
    [
      _bicak(-1),
      _bicak(1),
      _kanat(-1),
      _kanat(1),
      _kolYolu(-1),
      _kolYolu(1),
      _motorYolu(),
    ].fold<Path>(
      _govdeYolu(),
      (acc, parca) => Path.combine(PathOperation.union, acc, parca),
    );

/// Bloom katmanının sınırı: tam gazda plumayı ve kanat parıltısını içine alacak
/// kadar geniş. Atlas pişirici kare boyunu buradan hesaplıyor, yani sınır tek
/// bir yerde tanımlı kalıyor.
const Rect _fxSiniri = Rect.fromLTRB(-88, -100, 88, 150);

// ── Enerji hatları ───────────────────────────────────────────────────────

/// Zırhın üstündeki bir enerji kanalı.
///
/// `Path` değil POLİLİNE olarak tutuluyor: kare başına maliyet bu noktalar
/// üzerinde `drawLine`lardan ibaret kalsın, çizim döngüsünde
/// `computeMetrics`/`extractPath` tahsisi olmasın. Aynı karar Bastion'ın
/// yarıklarında da alındı ve sebebi aynı.
class _Hat {
  _Hat(List<Offset> yol, this.tohum, this.agirlik)
    : noktalar = _yenidenOrnekle(yol, 1.5),
      yolu = _poliYol(yol);

  /// Eşit aralıklı örneklenmiş nokta dizisi — genişlik ve yük rampaları bunun
  /// üzerinden pürüzsüz akıyor.
  final List<Offset> noktalar;

  final double tohum;

  /// 1 = ana kanal, düşük = besleme dalı. Kanal genişliğini ve taşıyabileceği
  /// yükün tavanını sürüyor. Ağa HİYERARŞİ veren şey bu; yoksa on bir özdeş
  /// çizgi olurdu.
  final double agirlik;

  final Path yolu;
}

/// Eşit aralıklı yeniden örnekleme.
///
/// Kanallar 2-3 noktalı düz koşular; doğrudan çizilirse tek parça o kadar uzun
/// olur ki yük paketi bir noktadan diğerine ışınlanır. Örnekleme paketin kanal
/// boyunca AKMASINI mümkün kılan şey.
List<Offset> _yenidenOrnekle(List<Offset> yol, double adim) {
  final cikti = <Offset>[yol.first];
  var tasima = 0.0;
  for (var i = 0; i < yol.length - 1; i++) {
    final a = yol[i];
    final b = yol[i + 1];
    final acik = (b - a).distance;
    if (acik < 1e-6) continue;
    var d = adim - tasima;
    while (d < acik) {
      cikti.add(Offset.lerp(a, b, d / acik)!);
      d += adim;
    }
    tasima = (tasima + acik) % adim;
  }
  cikti.add(yol.last);
  return cikti;
}

Path _poliYol(List<Offset> noktalar) {
  final yol = Path()..moveTo(noktalar.first.dx, noktalar.first.dy);
  for (var i = 1; i < noktalar.length; i++) {
    yol.lineTo(noktalar[i].dx, noktalar[i].dy);
  }
  return yol;
}

/// Kanal ağı — HEPSİ reaktörden başlıyor.
///
/// Bu kısıt ağın tamamının anlamı: her hattın `s=0`'ı kavşak, `s=1`'i bir uç.
/// Yük paketi `s` boyunca ilerlediği için gözün gördüğü hareket tek yönlü —
/// çekirdekten silaha. Hatlardan biri ters yönde kurulsaydı, o tek hat bütün
/// okumayı bozardı; "her hat reaktörden çıkar" kuralı bu yüzden burada, hattın
/// kendi içinde bir yön alanı olarak değil.
final List<_Hat> _hatlar = () {
  final cikti = <_Hat>[];
  var tohum = 0.0;
  void hat(List<Offset> yol, double agirlik) {
    tohum += 1.7;
    cikti.add(_Hat(yol, tohum, agirlik));
  }

  for (final m in const [-1.0, 1.0]) {
    final on = _kolUcu(m, true);
    final arka = _kolUcu(m, false);
    // Ana kollar: kavşaktan bıçağa ve kıç kanadına.
    hat([_kavsak, on], 1);
    hat([_kavsak, arka], 1);
    // Silah beslemeleri: koldan ayrılıp kaideye iniyor. Kol ÇAPRAZ olduğu için
    // m=-1 kolunun arka ucu SAĞ kanatta — besleme de sağ kaideye gidiyor.
    hat([
      Offset.lerp(_kavsak, on, 0.58)!,
      GoliathX.hardpoints[m < 0 ? 0 : 1],
    ], 0.45);
    hat([
      Offset.lerp(_kavsak, arka, 0.52)!,
      GoliathX.hardpoints[m < 0 ? 4 : 3],
    ], 0.45);
  }
  // Omurga hattı: kavşaktan omurga topuna, oradan motor bloğuna.
  hat([_kavsak, const Offset(0, 4), const Offset(0, 23)], 0.75);
  return cikti;
}();

/// Kanal genişliği — kavşakta kalın, uçta ince.
///
/// Süs değil: kesit, taşıdığı yükle birlikte daralıyor. Sabit genişlikte bir ağ
/// gövdeye ÇİZİLMİŞ gibi durur; daralan ağ gövdenin İÇİNDEN geçiyormuş gibi.
double _hatGenisligi(double agirlik, double s) =>
    (1.0 + agirlik * 1.7) * (1 - 0.42 * s);

/// Kanalların zırha oyulmuş SOĞUK hendekleri. Zırhla birlikte, emissive
/// geçişten ÖNCE çizilir — ışık boşluğa değil, oyuğun içine oturur.
void _hatKanallari(Canvas canvas) {
  canvas
    ..save()
    ..clipPath(_zirh);
  final oyuk = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xE8020308);
  final pah = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x4093A6C6);
  for (final hat in _hatlar) {
    oyuk.strokeWidth = 1.4 + hat.agirlik * 2.6;
    canvas
      ..drawPath(hat.yolu, oyuk)
      ..drawPath(
        hat.yolu.shift(const Offset(-0.5, -0.7)),
        pah..strokeWidth = 0.5,
      );
  }
  canvas.restore();
}

/// Hatların SICAK geçişi — yük paketleri kanallardan akıyor.
///
/// Bastion'ın taşınımıyla aynı üç geçiş (kabuk / gövde / çekirdek) ama sürücü
/// işlev başka: orada gezici bir fbm dalgası ısı CEPLERİ üretiyor, burada dar
/// bir darbe treni ayrık PAKETLER üretiyor. Fark kasıtlı — biri erimiş bir
/// yüzey, diğeri yüklü bir devre.
void _hatEmissive(Canvas canvas, double time, double thrust) {
  final itki = thrust.clamp(0.0, 1.0).toDouble();
  // Duran gemi de yüklü: taban 0,55. İtki yalnız yükü YÜKSELTİYOR, açmıyor —
  // motoru kapalı bir gemi karanlık bir kabuk olsaydı hangarda ölü görünürdü.
  final yuk = 0.55 + 0.45 * itki;
  final nefes = 0.5 + 0.5 * sin(time * 2.2);

  final sizinti = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
  final kabuk = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final govde = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final cekirdek = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  canvas
    ..save()
    ..clipPath(_zirh);

  for (final hat in _hatlar) {
    final noktalar = hat.noktalar;
    final son = noktalar.length - 1;
    if (son < 1) continue;

    // Çevredeki plakaya ışık sızması — kanalın tamamı için TEK bulanık çizgi;
    // parça başına blur aynı yumuşak hale için on kat pahalı.
    sizinti
      ..strokeWidth = 2.5 + hat.agirlik * 7
      ..color = _ark(0.44, (0.16 + nefes * 0.06) * yuk * hat.agirlik);
    canvas.drawPath(hat.yolu, sizinti);

    for (var i = 0; i < son; i++) {
      final s = i / son;
      final w = _hatGenisligi(hat.agirlik, s);
      final a = noktalar[i];
      final b = noktalar[i + 1];

      // Yük paketi: dar bir darbe treni. Üs (14) paketin GENİŞLİĞİ — düşük üs
      // kanalı baştan sona eşit parlatır ve hareket kaybolur.
      final faz =
          s * 2.3 - time * (0.85 + hat.agirlik * 0.45) + hat.tohum * 0.31;
      final darbe = pow(max(0.0, sin(faz * 2 * pi)), 14).toDouble();
      // Taban akım: paketler arasında kanal sönmüyor, kısılıyor.
      final taban = 0.26 + 0.09 * gNoise(s * 3.1 - time * 0.7 + hat.tohum);
      // Uçta soğuma — yük kaideye varana kadar bir miktarını yolda bırakıyor.
      final sonum = 1 - 0.35 * s;
      final t =
          ((taban + 0.68 * darbe) * yuk * sonum * (0.55 + hat.agirlik * 0.45))
              .clamp(0.0, 1.0)
              .toDouble();

      kabuk
        ..strokeWidth = w * 1.8
        ..color = _ark(0.22 + t * 0.14, 0.34 + t * 0.22);
      canvas.drawLine(a, b, kabuk);

      govde
        ..strokeWidth = w * (0.44 + t * 0.46)
        ..color = _ark(0.40 + t * 0.36, 0.40 + t * 0.45);
      canvas.drawLine(a, b, govde);

      // Beyazı yalnız paketin tepesi hak ediyor. Göz böylece eşit bir mavi
      // bulaşığa değil, kanaldan geçen birkaç noktaya kilitleniyor.
      if (t > 0.70) {
        final k = (t - 0.70) / 0.30;
        cekirdek
          ..strokeWidth = w * (0.16 + k * 0.30)
          ..color = _ark(0.90 + k * 0.10, 0.45 + k * 0.55);
        canvas.drawLine(a, b, cekirdek);

        if (k > 0.4) {
          canvas.drawCircle(
            Offset.lerp(a, b, 0.5)!,
            w * (1.5 + k * 1.7),
            Paint()
              ..blendMode = BlendMode.plus
              ..color = _ark(0.74, 0.13 * k)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
          );
        }
      }
    }

    // Uç terminali: paket vardığında parlıyor. `s=1` fazı, yukarıdaki darbe
    // treninin tam olarak aynı ifadesi — terminal kendi ritmini uydurmuyor,
    // kanalın ritmini OKUYOR.
    final ucFaz = 2.3 - time * (0.85 + hat.agirlik * 0.45) + hat.tohum * 0.31;
    final varis = pow(max(0.0, sin(ucFaz * 2 * pi)), 14).toDouble();
    if (varis > 0.05) {
      canvas.drawCircle(
        noktalar.last,
        (0.9 + hat.agirlik * 1.1) * (1 + varis * 1.4),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _ark(0.88, (0.25 + varis * 0.6) * yuk)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 + varis * 1.6),
      );
    }
  }
  canvas.restore();
}

// ── Reaktör ──────────────────────────────────────────────────────────────

/// Opak çerçeve — zırhla birlikte, emissive geçişten ÖNCE çizilir.
void _reaktorYuvasi(Canvas canvas) {
  final govde = Path();
  for (var i = 0; i < 6; i++) {
    final a = -pi / 2 + i * pi / 3;
    final p = _kavsak + Offset(cos(a), sin(a)) * 8.2;
    i == 0 ? govde.moveTo(p.dx, p.dy) : govde.lineTo(p.dx, p.dy);
  }
  govde.close();
  canvas
    ..drawPath(govde, Paint()..color = const Color(0xFF05070E))
    ..drawPath(
      govde,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF7E92B8),
    );
}

/// Reaktörün ışığı. Hatlarla birlikte bloom geçişinin içinde koşuyor; böylece
/// gövde ve çekirdek birbiriyle kavga etmek yerine tek bloom paylaşıyor.
void _reaktorEmissive(Canvas canvas, double time) {
  final nabiz = 0.5 + 0.5 * sin(time * 4.6);

  canvas
    ..drawCircle(
      _kavsak,
      9 + nabiz * 1.8,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _ark(0.52, 0.26 + nabiz * 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + nabiz),
    )
    ..drawCircle(
      _kavsak,
      4.0,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          _kavsak.translate(-0.9, -0.9),
          5.0,
          [_ark(1.0), _ark(0.86), _ark(0.44)],
          const [0, 0.36, 1],
        ),
    )
    // Karedeki en parlak noktada mercek çizgisi.
    ..drawOval(
      Rect.fromCenter(center: _kavsak, width: 26 + nabiz * 6, height: 1.2),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _ark(0.9, 0.20 + nabiz * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
    );

  // Yüklemeyi GÖSTEREN şey: dört kola giden enjeksiyon dilimleri. Reaktörün
  // ışığı ağa nereden giriyorsa göz de oraya bakıyor.
  for (final m in const [-1.0, 1.0]) {
    for (final on in const [true, false]) {
      final hedef = _kolUcu(m, on);
      final yon = (hedef - _kavsak) / (hedef - _kavsak).distance;
      final vurus = 0.5 + 0.5 * sin(time * 3.4 - (on ? 0 : 1.6) - m * 0.8);
      canvas.drawLine(
        _kavsak + yon * 5.0,
        _kavsak + yon * (9.5 + vurus * 4),
        Paint()
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = _ark(0.70 + vurus * 0.22, 0.30 + vurus * 0.45),
      );
    }
  }

  // Ters yönde dönen iki yay: dönme yönü tek olsaydı gemi bir pervane gibi
  // okunurdu; karşıt çift bir ALAN gibi okunuyor.
  for (var i = 0; i < 2; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: _kavsak, radius: 5.8 + i * 1.6),
      time * (i.isEven ? 1.9 : -1.4) + i * 2.4,
      0.85 + i * 0.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus
        ..color = _ark(0.72 + i * 0.12, 0.85),
    );
  }

  canvas.drawCircle(
    _kavsak.translate(-0.6, -0.7),
    0.85 + nabiz * 0.25,
    Paint()
      ..blendMode = BlendMode.plus
      ..color = Colors.white,
  );
}

/// Kollar arasında atlayan ark — kavşağın hemen üstünde, kısa ve SEYREK.
///
/// Karneye bağlı olması bütün mesele: sürekli çakan bir ark bir arıza gibi
/// okunur, ara sıra çakan bir ark GÜÇ gibi. Zamanı kovalara bölüp kovanın
/// hash'ine bakıyoruz — `Random` yok, aynı `time` daima aynı kareyi çiziyor ve
/// golden testler kararlı kalıyor.
void _arkSicramasi(Canvas canvas, double time, double thrust) {
  final itki = thrust.clamp(0.0, 1.0).toDouble();
  const kovaHizi = 7.0;
  final kova = (time * kovaHizi).floorToDouble();
  final yerel = time * kovaHizi - kova;

  for (var n = 0; n < 2; n++) {
    final kapi = gHash(kova * 3.1 + n * 17.3);
    // İtkiyle açılan karne: duran gemide ~%12, tam gazda ~%40 kare ark taşıyor.
    if (kapi > 0.12 + itki * 0.28) continue;
    // Kovanın içinde doğup sönüyor: ark bir kare boyu sabit durmuyor.
    final omur = sin(yerel * pi);
    if (omur < 0.05) continue;

    final tohum = kova * 0.77 + n * 5.3;
    final yay = 12.0 + gHash(tohum) * 16;
    final aci = -pi / 2 + (gHash(tohum + 1.9) - 0.5) * 2.6;
    final a = _kavsak + Offset(cos(aci), sin(aci)) * yay;
    final b = _kavsak + Offset(-cos(aci), sin(aci) * 0.55) * (yay * 0.85);

    // Kırık yol: düz bir çizgi ark değil, tel olurdu.
    final yol = <Offset>[a];
    for (var i = 1; i < 5; i++) {
      final p = Offset.lerp(a, b, i / 5)!;
      final sapma = (gRand(tohum, i) - 0.5) * 9;
      yol.add(p + Offset(-sapma * 0.4, sapma));
    }
    yol.add(b);

    final parlaklik = omur * (0.55 + itki * 0.45);
    for (var g = 0; g < 3; g++) {
      final boya = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus
        ..strokeWidth = [3.4, 1.5, 0.6][g]
        ..color = _ark([0.46, 0.74, 1.0][g], parlaklik * [0.30, 0.55, 0.9][g]);
      if (g == 0) {
        boya.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6);
      }
      canvas.drawPath(_poliYol(yol), boya);
    }
  }
}

/// Omuz bacaları — çekirdeğin yanlarındaki soğutma yarıkları.
///
/// Yalnız İTKİYLE açılıyor: duran gemide kapalı bir yarık, gaza basınca yanan
/// bir yarık. Geminin durumu efektten okunsun diye ([GoliathX.paint] itkiyi
/// hem plumaya hem hatlara hem buraya sürüyor).
void _omuzBacalari(Canvas canvas, double time, double thrust) {
  final itki = thrust.clamp(0.0, 1.0).toDouble();
  if (itki < 0.02) return;
  for (final m in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y = -4.0 + i * 7;
      final titreme = 0.5 + 0.5 * sin(time * 6.2 + i * 1.7 + m * 0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(m * 11.0, y), width: 2.2, height: 4.6),
          const Radius.circular(1.1),
        ),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = _ark(0.62 + titreme * 0.25, itki * (0.35 + titreme * 0.35))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.1 + titreme * 0.7),
      );
    }
  }
}

/// Ortam koronası — zırhın ARKASINDA. Duran gemide de duruyor: reaktör kapalı
/// değil, gemi yalnız hızlanmıyor.
void _ortamKoronasi(Canvas canvas, double time, double thrust) {
  final itki = thrust.clamp(0.0, 1.0).toDouble();
  final nefes = 0.5 + 0.5 * sin(time * 1.7);
  canvas
    ..drawOval(
      Rect.fromCenter(
        center: _kavsak.translate(0, 6),
        width: 132 + nefes * 8,
        height: 150 + nefes * 8,
      ),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _ark(0.40, 0.030 + nefes * 0.020 + itki * 0.016)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 19 + nefes * 3),
    )
    ..drawOval(
      Rect.fromCenter(
        center: _kavsak,
        width: 58 + nefes * 5,
        height: 58 + nefes * 5,
      ),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _ark(0.56, 0.030 + nefes * 0.022)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
}

/// İyonizasyon buğusu — kıç kenarında, gövdenin EN ÜSTÜNDE.
///
/// Bastion'ın ısı buğusuyla aynı hile (ön kenarı parlak, arka kenarı koyu bir
/// bant, yer değiştirmiş arkaplan gibi okunur) ama burada bant motorun
/// arkasında değil kanatların İZİNDE: plazma gemiyi sıyırıp geçiyor.
void _iyonBugusu(Canvas canvas, double time, double thrust) {
  final itki = thrust.clamp(0.0, 1.0).toDouble();
  if (itki < 0.04) return;
  for (final m in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final kayma = (time * 34 + i * 21) % 46;
      final y = 12 + kayma;
      final genislik = (30 - i * 5) * (0.6 + itki * 0.4);
      final merkez = Offset(m * (30 - kayma * 0.24), y);
      final solma = (1 - kayma / 46) * itki * 0.5;
      canvas
        ..drawOval(
          Rect.fromCenter(
            center: merkez.translate(0, -1.1),
            width: genislik,
            height: 2.4,
          ),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = _ark(0.58, 0.055 * solma)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
        )
        ..drawOval(
          Rect.fromCenter(
            center: merkez.translate(0, 1.1),
            width: genislik,
            height: 2.4,
          ),
          Paint()
            ..color = const Color(0xFF000000).withValues(alpha: 0.05 * solma)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
        );
    }
  }
}

// ── Zırh ─────────────────────────────────────────────────────────────────

void _plakaBoya(Canvas canvas, Path yol) {
  final kutu = yol.getBounds();
  canvas
    ..drawPath(
      yol.shift(const Offset(2.2, 4.0)),
      Paint()
        ..color = const Color(0xD6000104)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    )
    ..drawPath(
      yol.shift(const Offset(0, 2.0)),
      Paint()
        ..shader = ui.Gradient.linear(
          kutu.topLeft,
          kutu.bottomRight,
          const [Color(0xFF232838), Color(0xFF0E1119), Color(0xFF010306)],
          const [0, 0.52, 1],
        ),
    )
    ..drawPath(
      yol,
      Paint()
        ..shader = ui.Gradient.linear(
          kutu.topLeft,
          kutu.bottomRight,
          _plakaMetal,
          const [0, 0.4, 1],
        ),
    );

  // Düzensiz yüzey kırılması. Düşük kontrastlı is plakanın içinde kalıyor ve
  // gövdenin temiz bir vektör çıkartması gibi okunmasını engelliyor.
  canvas
    ..save()
    ..clipPath(yol);
  for (var i = 0; i < 4; i++) {
    final px = kutu.left + kutu.width * (0.18 + i * 0.23);
    final py =
        kutu.top + kutu.height * (0.24 + 0.17 * sin(i * 2.1 + kutu.width));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px, py),
        width: 7 + (i % 2) * 5,
        height: 3.2 + (i % 3) * 2,
      ),
      Paint()
        ..color = const Color(0x3A040A16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }
  canvas.restore();

  canvas
    // Zırhın yansıttığı ark ışığı — reaktöre MERKEZLENMİŞ radyal shader.
    // Çepeçevre düzgün mavi bir kenar metal okumasını öldürürdü; ışığın bir
    // KAYNAĞI olması gerekiyor ve o kaynak kavşaktaki çekirdek.
    ..drawPath(
      yol,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          _kavsak,
          58,
          [_ark(0.58, 0.11), _ark(0.72, 0.035), _ark(0.5, 0)],
          const [0, 0.34, 1],
        ),
    )
    ..drawPath(
      yol,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          kutu.topLeft + Offset(kutu.width * 0.28, kutu.height * 0.18),
          max(kutu.width, kutu.height) * 0.72,
          const [Color(0x14FFFFFF), Color(0x00FFFFFF)],
        ),
    )
    ..drawPath(
      yol,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round
        ..color = _plakaKenari,
    )
    ..drawPath(
      yol,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          _kavsak,
          48,
          [_ark(0.76, 0.28), _ark(0.58, 0.08), _ark(0.5, 0)],
          const [0, 0.45, 1],
        ),
    )
    ..drawPath(
      yol.shift(const Offset(-0.25, -0.35)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x6688A0C4),
    );
}

/// Omurga topunun beşiği — top kendisi burada DEĞİL, kendi atlas hücresinde.
void _omurgaBesigi(Canvas canvas) {
  final taban = RRect.fromRectAndRadius(
    const Rect.fromLTRB(-7.5, 1, 7.5, 18),
    const Radius.circular(3),
  );
  canvas
    ..drawRRect(
      taban.shift(const Offset(0, 2)),
      Paint()..color = const Color(0xCC03060C),
    )
    ..drawRRect(
      taban,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-7, 1),
          const Offset(7, 18),
          const [Color(0xFF666F80), Color(0xFF252A36), Color(0xFF080A11)],
          const [0, 0.5, 1],
        ),
    )
    ..drawRRect(
      taban,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF080B12),
    );
}

/// Seyir feneri — kanat uçlarında. Hale kasten additive DEĞİL: fener bir konum
/// göstergesi, bir enerji kaynağı değil. Additive olsaydı enerji hatlarıyla
/// aynı dilde konuşmaya başlardı.
void _seyirFeneri(Canvas canvas, Offset nokta, Color renk) {
  canvas
    ..drawCircle(
      nokta,
      2.6,
      Paint()
        ..color = renk.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    )
    ..drawCircle(nokta, 1.2, Paint()..color = renk);
}

/// Kıç motor bloğu — DÖRT nozzle. Bastion'ın üçüne karşı dört, ve bu tek fark
/// silüetin ağırlığını taşıyan şey: motor sayısı katalogdaki en okunur güç
/// göstergesi (`GovdeTasarimi.motorSayisi` sıralamayı bununla açıklıyor).
void _motorBloku(Canvas canvas) {
  final blok = _motorYolu();
  canvas
    ..drawPath(
      blok,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 15),
          const Offset(0, _kic),
          [const Color(0xFF5D6879), const Color(0xFF11151D)],
        ),
    )
    ..drawLine(
      const Offset(-12, 15),
      const Offset(12, 15),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFF9DA9BC),
    )
    ..drawPath(
      blok,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF080A11),
    );
  for (final dx in const [-14.5, -5.0, 5.0, 14.5]) {
    canvas
      ..drawCircle(
        Offset(dx, _kic - 3.6),
        3,
        Paint()..color = const Color(0xFF4E5A6B),
      )
      ..drawCircle(
        Offset(dx, _kic - 4),
        2.7,
        Paint()..color = const Color(0xFF242B37),
      )
      ..drawCircle(
        Offset(dx, _kic - 3.6),
        1.9,
        Paint()..color = const Color(0xFF090B11),
      )
      ..drawCircle(
        Offset(dx, _kic - 3.6),
        1.6,
        Paint()
          // Nozzle lambası sabit bir armatür rengi, rampanın bir örneği değil:
          // ateşlenmemiş bir motorda da aynı tonda yanıyor.
          ..color = const Color(0xCC6FD8FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      )
      ..drawCircle(
        Offset(dx, _kic - 3.6),
        0.9,
        Paint()..color = const Color(0xFFE8FBFF),
      );
  }
}

/// Yalnız zırh — plakalar, oyulmuş kanallar, sert yuvalar. Her emissive öğe
/// KASTEN [GoliathX.paintHull] içindeki bloom geçişine bırakılmıştır.
void _paintHull(Canvas canvas) {
  _motorBloku(canvas);
  // Sıra silueti kuruyor: bıçaklar ve kanatlar gövdenin ALTINDA, X kolları
  // ÜSTÜNDE. Kollar en üstte olmasaydı X yapı değil desen gibi okunurdu.
  for (final m in const [-1.0, 1.0]) {
    _plakaBoya(canvas, _bicak(m));
    _plakaBoya(canvas, _kanat(m));
  }
  _plakaBoya(canvas, _govdeYolu());
  for (final m in const [-1.0, 1.0]) {
    _plakaBoya(canvas, _kolYolu(m));
  }

  // Panel çizgileri: omurga, bıçak nervürleri, kanat kirişleri.
  canvas.drawLine(
    const Offset(0, -30),
    const Offset(0, 26),
    Paint()
      ..strokeWidth = 1
      ..color = _panelDikisi,
  );
  for (final m in const [-1.0, 1.0]) {
    canvas
      ..drawLine(
        Offset(m * 13, -30),
        Offset(m * 33, -52),
        Paint()
          ..strokeWidth = 0.7
          ..color = _panelDikisi,
      )
      ..drawLine(
        Offset(m * 15, 4),
        Offset(m * 38, 19),
        Paint()
          ..strokeWidth = 0.7
          ..color = _panelDikisi,
      )
      ..drawLine(
        Offset(m * 6, -20),
        Offset(m * 6.5, 12),
        Paint()
          ..strokeWidth = 0.6
          ..color = const Color(0x7A4E5F82),
      );
  }

  _hatKanallari(canvas);
  // Silah yuvaları BURADA DEĞİL: kendi atlas bloklarında pişiyorlar, çünkü
  // sayıları oyuncunun taktığı lazere göre değişiyor (bkz.
  // [GoliathX.paintEmitter]). Gövdeye pişirilseydi her namlu sayısı için ayrı
  // bir gövde ızgarası gerekirdi.
  _reaktorYuvasi(canvas);
  _omurgaBesigi(canvas);
  _seyirFeneri(canvas, const Offset(-41.5, 20), const Color(0xFFFF5050));
  _seyirFeneri(canvas, const Offset(41.5, 20), const Color(0xFF3DDB7D));
}

/// Bir silah yuvasının TAMAMI — çelik kaide, enerji ve kendi bloom geçişi.
///
/// YEREL uzayda çiziyor: kaide orijinde, namlu −y'de. Yuvanın gemideki YERİ
/// burada uygulanmıyor; her yuva atlasta kendi hücresine pişiyor ve konumu
/// çizim anında `RSTransform` veriyor.
void _paintEmitter(Canvas canvas, int index, double time) {
  final boy = GoliathX.emitterLengths[index];
  final genislik = GoliathX.emitterWidths[index];
  WeaponEmitter.paintFrame(
    canvas,
    length: boy,
    width: genislik,
    accent: GoliathX.silahRengi,
  );
  bloom(canvas, GoliathX.emitterBounds, () {
    WeaponEmitter.paintEmissive(
      canvas,
      length: boy,
      width: genislik,
      accent: GoliathX.silahRengi,
      // Faz yuvaya göre kaydırılıyor: beş projektör aynı anda nabız atarsa gemi
      // tek bir organizma gibi soluk alıp veriyor ve göz onu hareketin
      // kendisinden önce yakalıyor.
      time: time + index * 0.37,
    );
  });
}

void _drivePlume(Canvas canvas, double time, double thrust) => paintPlume(
  canvas,
  time: time,
  thrust: thrust,
  ramp: _arkRampasi,
  // Bastion'dan KISA (1,55 → 1,35): ağır gemi daha az çevik görünmeli. Pluma
  // boyu ivmenin görsel karşılığı, gücün değil.
  length: 1.35,
  jets: const [
    PlumeJet(Offset(-14.5, _kic - 3.6), power: 0.6),
    PlumeJet(Offset(-5, _kic - 3.6)),
    PlumeJet(Offset(5, _kic - 3.6)),
    PlumeJet(Offset(14.5, _kic - 3.6), power: 0.6),
  ],
);

/// Goliath X'in çizim yüzeyi.
///
/// Tasarım uzayı gemi-merkezli ve −y ileri. Ölçek/merkezleme çağıranın işi
/// ([reach] ve [centreOffset] ile) — böylece aynı çizim hem oyunda hem
/// önizlemede aynı oranlarla çıkıyor.
///
/// Yüzeyi [Bastion] ile BİREBİR aynı: aynı isimler, aynı imzalar, aynı
/// sıralamalar. Sebep mimari — atlas pişirici, kayıt dosyası ve savaş katmanı
/// gövdeyi bu yüzey üzerinden tanıyor. İkinci bir gövdenin farklı bir yüzeyi
/// olsaydı çağıran taraf `if (govde is Bastion)` yazmak zorunda kalırdı.
abstract final class GoliathX {
  /// Çizimin taştığı sınır (tasarım uzayı, merkez ofseti UYGULANMADAN).
  static Rect get fxBounds => _fxSiniri;

  /// Silahın enerji rengi.
  ///
  /// [WeaponEmitter.accent]'ten AYRI tutulmasının sebebi, oradaki kuralın
  /// aynısı ters yönde: silah gövdeye kaynaşmamalı. Bastion'da gövde turuncu,
  /// silah camgöbeğiydi; burada gövde zaten mavi-mor, o yüzden silah camgöbeği
  /// kalsaydı projektör zırha karışırdı. Sıcak beyaz-yeşil, ark diliyle akraba
  /// ama ondan bir adım ayrı.
  static const Color silahRengi = Color(0xFF7CF3D0);

  /// Zırh yolunun sınır kutusu — geminin ölçüsü BURADAN çıkıyor.
  ///
  /// Elle yazılmış bir erişim ilk denemede tutmaz ve tuttuğunda da çizim bir
  /// gün onsuz büyür. Sanat büyüdüğünde kayıt kendiliğinden büyüsün diye
  /// ölçü çalışma zamanında okunuyor.
  static final Rect _kutu = _zirh.getBounds();

  /// Burnun merkeze uzaklığı.
  static double get _ileri => -_kutu.top;

  /// Kıçın merkeze uzaklığı.
  static double get _geri => _kutu.bottom;

  /// Silah yuvalarının GÖVDEDEKİ yerleri (tasarım uzayı, −y ileri).
  ///
  /// Sıra ve topoloji katalogun kuralı, bu gövdenin tercihi değil: aynalı ön
  /// çift · omurga topu · aynalı arka çift. `GovdeTasarimi.atesGruplari` ve
  /// yuva açılma sırası bu topolojiden TÜRÜYOR.
  ///
  /// Ön çift bıçakların üstünde, arka çift kanatların üstünde — ikisi de X'in
  /// bir kolunun ucunda, yani her top kendi besleme hattının sonunda duruyor.
  static const List<Offset> hardpoints = [
    Offset(-27, -34),
    Offset(27, -34),
    Offset(0, 4),
    Offset(-33, 15),
    Offset(33, 15),
  ];

  /// [hardpoints] ile aynı sırada projektör boyları ve genişlikleri.
  ///
  /// Bastion'ın zarfıyla BİREBİR aynı ve bu bir kopyala-yapıştır değil, bir
  /// kısıt: atlasın silah bloğu tek hücre boyu pişiriyor
  /// ([AtlasLayout.emitterCellWorld]) ve o hücre en büyük yuvaya göre
  /// ölçülmüş. Daha uzun bir omurga topu hücreyi taşırır ve atlasın yeniden
  /// ölçülmesini gerektirirdi — kazancı yok, bedeli var.
  ///
  /// Genişlik bir süs değil SINIF: 12 ve üstü omurga topu demek
  /// (`GovdeTasarimi.omurgaEsigi`) ve o namlu daha yoğun bobinle çiziliyor.
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
  static final List<Offset> worldHardpoints = [
    for (final h in hardpoints) AtlasLayout.designToWorld(h, centreOffset),
  ];

  /// Namlu ağızları GEMİ-YEREL DÜNYA biriminde — merminin doğduğu yer.
  static final List<Offset> worldMuzzles = [
    for (final m in muzzles) AtlasLayout.designToWorld(m, centreOffset),
  ];

  /// Bir projektörün çizim sınırı (tasarım uzayı, kaide orijinde).
  ///
  /// Zarf Bastion'la aynı olduğu için sınır da aynı; `tool/atlas_bounds_test.dart`
  /// beyanın gerçekten yettiğini ÖLÇÜYOR.
  static const Rect emitterBounds = Rect.fromLTRB(-28, -50, 28, 24);

  /// Yuvaların AÇILMA sırası — bu gövdenin bildirdiği tek şey.
  ///
  /// Önce omurga topu, sonra ön çift, sonra arka çift: içten dışa. Kararı veren
  /// kural [Armament.active]'te ve gövdeye ait değil; burada yalnız DİZİLİŞ
  /// var. Gruplar ÇİFT: bir çiftin yalnız yarısını yakmak gemiyi tek kanadı
  /// eksik gösterirdi.
  static const List<List<int>> mountGroups = [
    [2],
    [0, 1],
    [3, 4],
  ];

  /// Lazer sayısı → açık yuvalar, ÖNCEDEN hesaplanmış.
  ///
  /// [Armament.active] her çağrıda yeni bir liste kuruyor ve bu liste kare
  /// yolunda okunuyor. Tablo altı satır (0..5) ve süreç ömrü boyunca yaşıyor.
  static final List<List<int>> _lazereGore = [
    for (var n = 0; n <= Armament.mountCount(mountGroups); n++)
      List.unmodifiable(Armament.active(mountGroups, n)),
  ];

  /// [lasers] lazer takılıyken HANGİ yuvaların silahı var. Tahsis YOK.
  static List<int> activeHardpoints(int lasers) =>
      _lazereGore[lasers.clamp(0, _lazereGore.length - 1)];

  /// Bir silah yuvasını YEREL uzayda çizer — atlas pişiricinin girişi.
  static void paintEmitter(
    Canvas canvas, {
    required int index,
    required double time,
  }) => _paintEmitter(canvas, index, time);

  /// Ortalanmış yarı-açıklık — geminin ekranda kapladığı yarıçap.
  static double get reach => (_ileri + _geri) / 2;

  /// Gövdeyi orijine oturtan dikey kaydırma.
  static double get centreOffset => (_ileri - _geri) / 2;

  /// Bir kareyi çizer. [thrust] 0..1 — plumayı, hat yükünü, baca parlaklığını
  /// ve ark karnesini birlikte sürüyor, yani geminin durumu efektten okunuyor.
  ///
  /// Yalnız referans ve önizleme için: oyun katmanları ayrı ayrı, atlastan
  /// çiziyor ([paintEngine] / [paintHull] / [paintEmitter]).
  ///
  /// [lasers] takılı lazer sayısı. Zorunlu ve varsayılanı YOK: gemide kaç top
  /// olduğu bir gerçek, çağıranın söylemesi gereken bir şey.
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
      final nokta = hardpoints[index];
      canvas
        ..save()
        ..translate(nokta.dx, nokta.dy);
      paintEmitter(canvas, index: index, time: time);
      canvas.restore();
    }
  }

  /// ARKA katman: yalnız egzoz pluması.
  ///
  /// Katmanlar "motor parçası / gövde parçası" diye değil, opak gövdenin ÖNÜNDE
  /// mi ARKASINDA mı diye ayrılıyor — atlas onları bu sırayla üst üste koyduğu
  /// için tek doğru bölme bu. Burada yalnız pluma var çünkü yalnız pluma itki
  /// sıfırken gerçekten görünmez; ortam koronası duran gemide de duruyor.
  static void paintEngine(
    Canvas canvas, {
    required double time,
    required double thrust,
  }) {
    _drivePlume(canvas, time, thrust);
  }

  /// ÖN katman: ortam koronası, soğuk zırh, tek bloom geçişinde bütün sıcak
  /// öğeler ve en üstte iyon buğusu.
  static void paintHull(
    Canvas canvas, {
    required double time,
    required double thrust,
  }) {
    _ortamKoronasi(canvas, time, thrust);
    _paintHull(canvas);
    // TEK gerçek bloom geçişi: emissive katman bir kez bulanık-additive
    // `saveLayer` üzerinden, bir kez üstüne keskin. Çekirdeğin zırha taşmasını
    // sağlayan bu; her şeklin kendi `MaskFilter`'ı yalnız kendini sisler.
    bloom(
      canvas,
      _fxSiniri,
      () {
        _hatEmissive(canvas, time, thrust);
        _reaktorEmissive(canvas, time);
        _arkSicramasi(canvas, time, thrust);
        _omuzBacalari(canvas, time, thrust);
      },
      sigma: 4.6,
      alpha: 98,
    );
    _iyonBugusu(canvas, time, thrust);
  }
}
