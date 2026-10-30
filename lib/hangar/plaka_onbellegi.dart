import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'rank_plakasi.dart';

/// Rank plakasının PİŞMİŞ zemini — aynı rank ve boy bir kez çiziliyor.
///
/// **Neden var.** Plakanın zemini bir rank ve bir boy için SABİT: gradyanlı
/// dolgu, kenarlık, köşe kolları, kademe şeridi. Buna karşılık plaka her
/// karede sıfırdan boyanıyordu, çünkü üstündeki yörünge noktaları dönüyor ve
/// tek bir boyacı ikisini birden çiziyordu. Ölçüldü: bir S plakası kare
/// başına 24 çizim çağrısı ve 5 `MaskFilter.blur`, SSS plakası 30 çağrı ve 9
/// blur. Ekranda yirmi tane böyle hücre varken telefon bunu 60 Hz'de
/// yapamıyor.
///
/// **Neden görüntü, neden katman önbelleği değil.** Bir [RepaintBoundary]
/// yalnız yeniden KAYDI önlüyor; katman yine her karede rasterize ediliyor ve
/// blur'un bedeli orada. Üstelik aynı rankta yirmi hücre varsa yirmi ayrı
/// katman doğuyor. Pişmiş görüntüde ise aynı rank ve boydaki bütün hücreler
/// TEK dokuyu paylaşıyor: kare başına iş, bir doku kopyası.
///
/// Teknik bu projede yeni değil, yalnız menüye hiç girmemişti: `starfield`,
/// `void_portal`, `bastion` ve `shield_shell` sanatı zaten böyle pişiriyor.
///
/// [ui.Picture.toImageSync] kullanılıyor, `toImage` değil: ikincisi bir
/// `Future` ve 8-25 ms sürebiliyor, yani bir kare içinde çağrılamaz.
/// `toImageSync` görüntüyü GPU'da bırakıyor ve tekrar tekrar çizilmesi ucuz.
///
/// **Kap neden sınırsız büyümüyor.** Anahtar (rank, piksel boyu, ayrıntı).
/// Boylar ayrık ve sayılı (hücre, bilgi ekranı, malzeme çipi), rank yirmi
/// küsur. Yani kap birkaç düzine küçük dokuda duruyor.
abstract final class PlakaOnbellegi {
  static final Map<int, ui.Image> _zeminler = {};

  /// Pişmiş dokular NASIL çizilir.
  ///
  /// Doku hedef boyunda pişiyor, yani ölçekleme yok ve bilineer süzgeç
  /// yalnız yarım piksellik hizalamayı yumuşatıyor.
  static final Paint _kalem = Paint()..filterQuality = FilterQuality.low;

  /// Testlerin ve görsel referansların ölçebilmesi için: kapta kaç doku var.
  static int get dokuSayisi => _zeminler.length;

  /// ZEMİNİ çizer — merkez orijinde, tıpkı [RankPlakasi.ciz] gibi.
  ///
  /// [oran] cihazın piksel oranı: doku ekrandaki gerçek piksel sayısında
  /// pişsin diye. Mantıksal boyda pişen bir doku yüksek yoğunluklu bir
  /// telefonda bulanık çıkardı.
  static void zemin(
    Canvas c,
    double s,
    RankGorseli r, {
    required bool detay,
    required double oran,
  }) {
    final piksel = (s * oran).round();
    if (piksel <= 0) return;
    final anahtar = Object.hash(r.tier.index, piksel, detay);
    final doku = _zeminler[anahtar] ??= _zeminPisir(r, s, piksel, detay, oran);
    c.drawImageRect(
      doku,
      Rect.fromLTWH(0, 0, piksel.toDouble(), piksel.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: s, height: s),
      _kalem,
    );
  }

  static ui.Image _zeminPisir(
    RankGorseli r,
    double s,
    int piksel,
    bool detay,
    double oran,
  ) {
    final kayit = ui.PictureRecorder();
    final c = Canvas(kayit)
      ..scale(oran)
      // [RankPlakasi.ciz] merkezi ORİJİNDE bekliyor; doku ise sol üstten
      // başlıyor.
      ..translate(s / 2, s / 2);
    RankPlakasi.ciz(c, s, r, detay: detay);
    return kayit.endRecording().toImageSync(piksel, piksel);
  }

  /// Kabı boşaltır — yalnız testler için.
  @visibleForTesting
  static void temizle() {
    for (final d in _zeminler.values) {
      d.dispose();
    }
    _zeminler.clear();
  }
}
