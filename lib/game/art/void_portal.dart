import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'portal_field.dart';

/// VOID GEÇİDİ — haritalar arası kapının görüntüsü.
///
/// Tasarım voidspace2'nin `tool/portal_vfx.dart` keşfinden geldi (7 · VOID) ve
/// oradaki gerekçesi aynen geçerli: **negatif uzay.** Gövde gerçekten siyah;
/// okunmasını sağlayan tek şey arkadaki yıldız ışığının kenarda BÜKÜLMESİ. En
/// az elemanla en yüksek değer aralığını veren tasarım, ve bir geçidin
/// yapması gereken şey tam olarak bu — parlamak değil, **delik açmak.**
///
/// Renk kodlaması gövdeye DEĞİL çevresine konuyor. Void yeşil ya da kırmızı
/// olmaz; nereye açıldığı halkasında ve etiketinde yazar. Tasarımın kimliği
/// böyle korunuyor: içerisi her kapıda aynı, tabelası farklı.
///
/// ## Ölçek
///
/// Alan hesabı ucuz değil: 20×48 mesh × köşe başına bir fbm örneği ≈ kapı
/// başına 4 bin örnek. Haritada dört kapı varsa 60 FPS'te saniyede bir
/// milyondan fazla eder ve buna bloom'un `saveLayer` + blur'u da eklenir.
///
/// Çözüm nebula geçidinin çözümünün aynısı: **bir kez bake et, sonra blit.**
/// Bake edilen şey gövde + fresnel halkası + iç kıpırtı; canlı kalan şey
/// bükülen yıldız ışığı. O ayrım keyfî değil — yıldız izleri tasarımın
/// İKİNCİL HAREKETİ ve saniyede üç kareye düşerse "ucuz" görünmenin bir
/// numaralı sebebi geri gelir.
abstract final class VoidPortal {
  const VoidPortal._();

  /// Tam bir çevrim. Geçit SAKİN olmalı: keşif GIF'i hızlı bir tempoyla
  /// üretilmişti, haritada o tempo huzursuz duruyor.
  static const double periodSeconds = 9;

  /// Şeritteki benzersiz kare sayısı.
  ///
  /// Çapraz geçiş olduğu için düşük tutulabiliyor: komşu iki kare alfa ile
  /// karıştırılınca 3,5 fps'lik bir şerit sürekli hareket olarak okunuyor.
  static const int frames = 32;
  static const int _tex = 192;

  static ui.Image? _strip;
  static Future<void>? _baking;

  static bool get isReady => _strip != null;

  /// Şeridi (yoksa) pişirir. Yeniden çağırmak güvenli.
  ///
  /// **Testte `tester.runAsync` içinden çağır.** Future statikte
  /// önbellekleniyor ve `testWidgets` gövdeleri kendi sahte zamanlı
  /// zone'larında koşuyor: bir testin zone'unda doğan future, başka bir testte
  /// beklendiğinde asla tamamlanmıyor.
  static Future<void> ensureBaked() => _baking ??= _bake();

  static Future<void> _bake() async {
    const r = _tex / 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < frames; i++) {
      canvas
        ..save()
        ..translate(_tex * (i + 0.5), r);
      paintVoidCore(canvas, r * 0.9, i / frames);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    _strip = await picture.toImage(_tex * frames, _tex);
    picture.dispose();
  }

  /// Geçidi çizer. Merkez (0,0) varsayılıyor.
  ///
  /// [renk] kapının NEREYE açıldığını söyleyen aksan — gövdeye değil dış
  /// halkaya uygulanıyor. [acik] false ise kapı sönük ve nabzı durmuş:
  /// hareket bir davet ve gidilemeyen yere davet etmek yanlış sinyal.
  static void render(
    Canvas canvas, {
    required double radius,
    required double time,
    required Color renk,
    bool acik = true,
  }) {
    final p = (time / periodSeconds) % 1.0;
    final sonme = acik ? 1.0 : 0.35;

    // ── canlı: bükülen yıldız ışığı ──
    //
    // Gövdenin ARKASINA çiziliyor; blit `srcOver` olduğu için iç kısımları
    // kapanıyor ve ışık gerçekten kenarda bükülüyor gibi okunuyor.
    paintVoidLensing(canvas, radius, p, sonme: sonme);

    final strip = _strip;
    final dst = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2 / 0.9,
      height: radius * 2 / 0.9,
    );
    if (strip != null) {
      final x = p * frames;
      final i = x.floor() % frames;
      final f = x - x.floor();
      // ÇAPRAZ GEÇİŞ: komşu iki kare. `srcOver` olduğu için sırayla
      // çiziliyorlar — ikincisi birincinin üstüne kendi ağırlığıyla biniyor.
      for (final (idx, w) in [(i, 1 - f), ((i + 1) % frames, f)]) {
        if (w <= 0.001) continue;
        canvas.drawImageRect(
          strip,
          Rect.fromLTWH(
            idx * _tex.toDouble(),
            0,
            _tex.toDouble(),
            _tex.toDouble(),
          ),
          dst,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: (w * sonme).clamp(0.0, 1.0)),
        );
      }
    } else {
      // Yedek: şerit hazır değilse canlı hesap. Doğru görünür, sadece
      // pahalıdır — kapı asla boş kalmaz.
      canvas.saveLayer(
        dst,
        Paint()..color = Color(0xFFFFFFFF).withValues(alpha: sonme),
      );
      paintVoidCore(canvas, radius, p);
      canvas.restore();
    }

    // ── canlı: nereye açıldığını söyleyen aksan halkası ──
    paintVoidAccent(canvas, radius, p, renk: renk, acik: acik);
  }
}

/// PAHALI katman — bake edilen şey budur.
///
/// Gövde + fresnel halkası + iç kıpırtı. Üçü birlikte pişiyor çünkü gövdenin
/// arkadakini KAPATMASI gerekiyor: ayrı ayrı toplamalı harmanla çizilseydi
/// siyah hiçbir şey örtmezdi ve "negatif uzay" fikri çökerdi.
void paintVoidCore(Canvas canvas, double R, double p) {
  final b = Rect.fromCircle(center: Offset.zero, radius: R * 1.6);

  // Fresnel halkası: yalnız KENARDA, çok ince, çok parlak.
  bloom(canvas, b, sigma: R * 0.13, strength: 0.7, (c) {
    c.drawCircle(
      Offset.zero,
      R * 0.99,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * 0.02
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFEAF2FF).withValues(alpha: 0.9),
    );
  });

  // Gövde: gerçekten siyah, arkasındakini KAPATIR. Değer çapası bu — parlaklık
  // her yere yayılırsa hiçbir yer parlak olmaz.
  canvas.drawCircle(
    Offset.zero,
    R * 0.985,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        R * 0.985,
        [
          const Color(0xFF000000),
          const Color(0xFF000000),
          const Color(0xFF04060C),
        ],
        const [0, 0.86, 1],
      ),
  );

  // İçeride yalnız bir kıpırtı — boşluğun "canlı" olduğunu söyleyen tek işaret.
  portalField(
    canvas,
    radius: R * 0.9,
    rings: 20,
    sectors: 48,
    shade: (n, turn) {
      final f = voidFbm.sample(turn * 2 + p, n * 1.5 - p);
      final v = contrast(f, 6) * (1 - n) * 0.55;
      return const Color(0xFF6A4AFF).withValues(alpha: v);
    },
  );
}

/// UCUZ ve CANLI katman: kenarda bükülen yıldız ışığı.
///
/// Bake EDİLMEZ. Tasarımın ikincil hareketi bu ve saniyede üç kareye
/// düşürülürse efekt "döner ama etrafında hiçbir şey yaşamaz" hâline gelir —
/// ucuz görünmenin bir numaralı sebebi.
void paintVoidLensing(Canvas canvas, double R, double p, {double sonme = 1}) {
  final rnd = Random(303);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  for (var i = 0; i < 70; i++) {
    final a = rnd.nextDouble() * 2 * pi;
    final base = R * (1 + rnd.nextDouble() * 0.75);
    // Yakınlaştıkça çok bükülür — merceklenmenin tek satırlık hâli.
    final bend = pow(R / base, 3).toDouble();
    final sweep = (0.05 + 0.55 * bend) * (1 + 0.3 * sin(p * 2 * pi + i));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: base),
      a + p * 2 * pi * 0.15 * bend,
      sweep,
      false,
      paint
        ..strokeWidth = R * (0.004 + 0.008 * bend)
        ..color = const Color(
          0xFFDCE8FF,
        ).withValues(alpha: ((0.10 + 0.55 * bend) * sonme).clamp(0.0, 1.0)),
    );
  }
}

/// Kapının NEREYE açıldığını söyleyen aksan halkası.
///
/// Void'in kendisi renklendirilmiyor — bir boşluk yeşil ya da kırmızı olmaz.
/// Oyun bilgisi çevreye konuyor: ince bir halka ve (çağıranın çizdiği)
/// etiket.
/// Aksan halkasının yarıçap çarpanı — **birden büyük olamaz.**
///
/// Halka oyuncuya "geçit burada biter" diyor ve sunucu 1,0 R'ye bakıyor. Daha
/// büyük bir halka yalan söyler: dokunan kendini içeride sanır, sunucu
/// reddeder. Bildirilen hatanın birinci sebebi tam olarak buydu (1,12 idi).
const double gecitHalkaCarpani = 1.0;

/// Nabzın genliği — İÇERİ atıyor, dışarı değil.
const double gecitNabizGenligi = 0.025;

void paintVoidAccent(
  Canvas canvas,
  double R,
  double p, {
  required Color renk,
  required bool acik,
}) {
  // Halka TAM yarıçapı işaretliyor, dışını değil.
  //
  // Önce 1,12 R'de duruyordu ve bu bir yalan söylüyordu: oyuncu halkaya
  // dokunduğunda geçidin İÇİNDE olduğunu sanıyor ama tetikleme yarıçapı
  // 1,0 R. Bildirilen hata tam buydu — "geçit menzilinde değilsin" alan
  // oyuncu, gördüğü kapının içindeydi.
  //
  // Nabız da İÇERİ atıyor: dışarı atan bir nabız aynı yalanı küçük ölçekte
  // tekrarlardı.
  final nabiz = acik
      ? gecitHalkaCarpani - gecitNabizGenligi * (1 + sin(p * 2 * pi * 2)) / 2
      : gecitHalkaCarpani;
  canvas.drawCircle(
    Offset.zero,
    R * nabiz,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = R * (acik ? 0.045 : 0.03)
      ..color = renk.withValues(alpha: acik ? 0.8 : 0.3),
  );
}

/// Void'in gürültü kaynağı.
///
/// Tohum keşifteki `_fbmC` ile AYNI (47/5/0.58): değiştirilirse haritadaki
/// görüntü, onaylanan görüntüden başka çıkar.
final voidFbm = PortalFbm(seed: 47, octaves: 5, gain: 0.58);
