import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import 'rank_plakasi.dart';

/// Malzeme ve çevirici işareti — YIĞILABİLİR kaynakların silüeti.
///
/// **Ekipmandan farkı ekseni tersine çeviriyor.** Eşyada dört eksen var (aile ·
/// basamak · artı · çevirme) ve kalem hep aynıydı: ayrımı ÇERÇEVE taşıyordu,
/// çünkü oyuncu "hangi kalite" diye sorar.
///
/// Malzemede yalnız iki bilgi var: TÜR ve RANK. Ve tür sorusu daha keskin —
/// yükseltme malzemesiyle çevirici AYRI kaynak (alan 06'nın değişmezi) ve
/// karıştırıldıklarında oyuncu yanlış şeyi harcıyor. O yüzden ayrım yükü
/// SİLUETE geçiyor: iki tür, iki apayrı dış hat.
///
///   FİYAL     yükseltme malzemesi — boyunlu şişe, içi dolu
///   KIVILCIM  çevirici — sekiz kollu yıldız, ortası beyaz sıcak
///
/// 40 pikselde iç detay kaybolur, dış hat kalır: biri yuvarlak ve dikey, diğeri
/// köşeli ve ışınsal. Tek renkli bir lekeye indirildiklerinde bile ayrılıyorlar.
enum MalzemeIkonu {
  fiyal,
  kivilcim;

  /// Malzemenin TÜRÜNDEN işaret — kimliğinden değil.
  ///
  /// Kırk kayıt var (20 rank × 2 tür) ve kimliğe göre çizmek kırk satır
  /// isterdi. Türe göre çizince merdiven uzadığında hiçbir şey yazılmıyor.
  static MalzemeIkonu of(MalzemeTuru tur) => switch (tur) {
    MalzemeTuru.yukseltme => fiyal,
    MalzemeTuru.cevirme => kivilcim,
  };
}

/// Malzeme plakası — rank zemini + silüet + adet.
abstract final class MalzemePlakasi {
  /// FİYAL — CAM. Boyunlu şişe, içinde rank rengiyle parlayan sıvı.
  ///
  /// İlk hâli düz bir dolgu artı siyah konturdu ve bir çıkartma gibi
  /// duruyordu. Camı cam yapan üç şey var ve üçü de burada:
  ///   · gövde YARI SAYDAM — arkasındaki plaka içinden geçiyor
  ///   · sol kenarda dikey bir SPEKÜLER şerit — tek ışık kaynağı yansıması
  ///   · sıvının üstünde MENİSKÜS — düz bir çizgi değil, hafif kavis
  static void _fiyal(Canvas c, double s, RankGorseli r) {
    final govde = Path()
      ..moveTo(-s * 0.12, -s * 0.38)
      ..lineTo(s * 0.12, -s * 0.38)
      ..lineTo(s * 0.12, -s * 0.14)
      ..lineTo(s * 0.26, s * 0.20)
      ..quadraticBezierTo(s * 0.26, s * 0.38, 0, s * 0.38)
      ..quadraticBezierTo(-s * 0.26, s * 0.38, -s * 0.26, s * 0.20)
      ..lineTo(-s * 0.12, -s * 0.14)
      ..close();
    final sivi = Path()
      ..moveTo(-s * 0.215, s * 0.09)
      ..quadraticBezierTo(0, s * 0.005, s * 0.215, s * 0.09)
      ..quadraticBezierTo(s * 0.225, s * 0.33, 0, s * 0.33)
      ..quadraticBezierTo(-s * 0.225, s * 0.33, -s * 0.215, s * 0.09)
      ..close();

    c
      // Cam gövdesi: yarı saydam, üstte açık altta koyu.
      ..drawPath(
        govde,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(-s * 0.2, -s * 0.35),
            Offset(s * 0.2, s * 0.35),
            [
              const Color(0xFFE8F0FA).withValues(alpha: 0.42),
              const Color(0xFF8DA0B6).withValues(alpha: 0.26),
              const Color(0xFF2A3440).withValues(alpha: 0.55),
            ],
            const [0, 0.5, 1],
          ),
      )
      // Sıvı — rank rengi BURADA. Aynı şişe her rankta aynı şişe;
      // değişen içindekiler.
      ..drawPath(
        sivi,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, s * 0.05),
            Offset(0, s * 0.33),
            [Color.lerp(r.acik, const Color(0xFFFFFFFF), 0.30)!, r.taban],
          ),
      )
      // Sıvının kendi ışıması — üst ranklarda daha güçlü.
      ..drawPath(
        sivi,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = r.acik.withValues(alpha: 0.10 + r.gorselAile * 0.030)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.045),
      )
      // Menisküs — sıvı yüzeyinin parlak kavisi.
      ..drawPath(
        Path()
          ..moveTo(-s * 0.215, s * 0.09)
          ..quadraticBezierTo(0, s * 0.005, s * 0.215, s * 0.09),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            r.acik,
            const Color(0xFFFFFFFF),
            0.6,
          )!.withValues(alpha: 0.8),
      )
      // Speküler şerit — camın SOL kenarında, ışık sol üstten.
      ..drawPath(
        Path()
          ..moveTo(-s * 0.085, -s * 0.33)
          ..lineTo(-s * 0.045, -s * 0.33)
          ..lineTo(-s * 0.115, s * 0.10)
          ..lineTo(-s * 0.165, s * 0.10)
          ..close(),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.42)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.010),
      )
      // Kenar: siyah kontur DEĞİL — üstte ışık, altta gölge alan bir cam ağzı.
      ..drawPath(
        govde,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.020
          ..shader =
              ui.Gradient.linear(Offset(0, -s * 0.38), Offset(0, s * 0.38), [
                const Color(0xFFDCE6F2).withValues(alpha: 0.75),
                const Color(0xFF090D14).withValues(alpha: 0.85),
              ]),
      );

    // Metal tıpa — kendi pahıyla.
    final tipa = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -s * 0.375),
        width: s * 0.30,
        height: s * 0.10,
      ),
      Radius.circular(s * 0.022),
    );
    c
      ..drawRRect(
        tipa,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, -s * 0.425),
            Offset(0, -s * 0.325),
            [const Color(0xFFB6C2D0), const Color(0xFF4B5563)],
          ),
      )
      ..drawRRect(
        tipa,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.014
          ..color = const Color(0xFF090D14).withValues(alpha: 0.7),
      );
  }

  /// KIVILCIM — METAL. Sekiz kollu yıldız, her kolu ayrı fasetli.
  ///
  /// İlk hâli tek bir dolgu artı siyah konturdu: sekiz kol da aynı renkteydi
  /// ve şekil düz bir yıldız lekesine düşüyordu. Metali metal yapan şey
  /// kolların BİRBİRİNDEN farklı aydınlanması — ışık sol üstte, o yöne bakan
  /// yüzler parlak, ters yüzler koyu.
  static void _kivilcim(Canvas c, double s, RankGorseli r) {
    const kol = 8;
    final dis = s * 0.40, ic = s * 0.145;
    // On altı köşe: dış uç, iç oyuk, dış uç… Tek bir döngü, tek bir sıra.
    //
    // İlk yazışta iki ayrı indeks hesabı iç içe geçmişti ve dış hat
    // düzensiz çıkıyordu — yıldız simetrik değil, tırtıklıydı.
    Offset kose(int i) {
      final a = i / (kol * 2) * 2 * math.pi - math.pi / 2;
      final yaricap = i.isEven ? dis : ic;
      return Offset(math.cos(a) * yaricap, math.sin(a) * yaricap);
    }

    final tam = Path()..moveTo(kose(0).dx, kose(0).dy);
    for (var i = 1; i < kol * 2; i++) {
      tam.lineTo(kose(i).dx, kose(i).dy);
    }
    tam.close();

    // Dışa taşan bloom — çevirici NADİR bir kaynak, ızgarada kendini belli
    // etmeli. Üst ranklarda güçleniyor.
    c.drawPath(
      tam,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = r.taban.withValues(alpha: 0.30 + r.gorselAile * 0.035)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.070),
    );

    // Her kol İKİ faset. Işık SOL ÜSTTE: o yöne bakan yüz parlak, ters yüz
    // koyu. Aynı renkte iki faset, şekli düz bir lekeye düşürüyordu.
    for (var i = 0; i < kol * 2; i++) {
      final a = kose(i), b = kose((i + 1) % (kol * 2));
      final orta = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final uzunluk = orta.distance;
      final aydinlik = uzunluk == 0
          ? 0.5
          : (0.5 + (-orta.dx - orta.dy) / (uzunluk * 1.4142) * 0.5).clamp(
              0.0,
              1.0,
            );
      c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..close(),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF39434F),
            Color.lerp(const Color(0xFFEDF3FA), r.acik, 0.32)!,
            aydinlik,
          )!,
      );
    }

    c
      ..drawPath(
        tam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.015
          ..strokeJoin = StrokeJoin.miter
          ..color = const Color(0xFF090D14).withValues(alpha: 0.75),
      )
      // Çekirdek: beyaz sıcak, kendi halesiyle.
      ..drawCircle(
        Offset.zero,
        s * 0.13,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = r.acik.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.055),
      )
      ..drawCircle(
        Offset.zero,
        s * 0.062,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.96),
      );
  }

  /// Yalnız SİLUETİ çizer — merkez orijinde, plaka ÇAĞIRANIN işi.
  ///
  /// Plaka bir süre burada da çiziliyordu ve iki kopya vardı: biri eşyanın,
  /// biri malzemenin. Aynı zeminin iki kaynağı, ayrışmayı bekleyen bir
  /// borçtu — nitekim ayrıştılar da. Artık tek kaynak [RankKutusu].
  static void siluet(
    Canvas canvas,
    double s,
    MalzemeIkonu ikon,
    RankGorseli r,
  ) {
    switch (ikon) {
      case MalzemeIkonu.fiyal:
        _fiyal(canvas, s, r);
      case MalzemeIkonu.kivilcim:
        _kivilcim(canvas, s, r);
    }
  }
}
