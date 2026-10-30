import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import 'unvan_amblemi.dart';

/// UNVAN YAZISI — adın tipografisi de merdivenin bir parçası (10.4).
///
/// Unvan uzun süre tek renkte, tek ağırlıkta bir etiketti: "SQUIRE III" ile
/// "STAR LORD VI" ekranda aynı görünüyordu. Oysa yirmi adım boyunca değişen
/// tek şey harflerin dizilişi değil, oyuncunun ne kadar yol aldığı. Yazı bunu
/// üç kanaldan söylüyor:
///
///   RENK    — amblemin paleti ([UnvanPaleti]), yani eşya merdiveninin aynı
///             basamağı. Ad ile amblem asla farklı renkte olmuyor.
///   AĞIRLIK — çağla artıyor: Asalet ince ve geniş aralıklı, Ölümsüzlük kalın
///             ve sıkı. İlerleme harflerin KÜTLESİNDE okunuyor.
///   IŞIK    — Yıldız çağından itibaren adın arkasında kendi renginde bir
///             hale; Ölümsüzlük'te ad bir gradyanla dolduruluyor.
///
/// **Ad SUNUCUNUN dizesi, indeks yalnız STİL seçiyor.** İstemci adı
/// indeksten kurmuyor ve kurmamalı (10.4): kurduğu gün sunucunun yolladığı
/// ad ile ekranda yazan ad sessizce ayrışırdı — kapı "Acolyte" derken başlık
/// "Bishop" yazardı. Buradaki indeksin işi yalnız rengi, ağırlığı ve haleyi
/// seçmek. Kademe rakamı da adın içinde geliyor; ayrıca çizilmiyor, çünkü
/// onu amblemin dış halkası zaten sayıyor.
///
/// Yazı tipi PROJENİN yazı tipi: ayrı bir aile yüklemiyor. Yirmi rank için
/// yirmi yazı tipi değil, tek ailenin ağırlık ve aralık ekseni kullanılıyor —
/// ikinci bir aile menünün geri kalanıyla çatışırdı.
class UnvanYazisi extends StatelessWidget {
  const UnvanYazisi({
    required this.ad,
    required this.unvanIndeksi,
    required this.boy,
    super.key,
  });

  /// SUNUCUNUN yolladığı ad — `Acolyte IV`. Olduğu gibi yazılıyor.
  final String ad;

  /// Basamak (0..119) — yalnız stil için: renk, ağırlık, aralık, hale.
  final int unvanIndeksi;

  /// Adın punto boyu.
  final double boy;

  /// Adın stili — çağ arttıkça ağırlaşıyor, aralık daralıyor.
  ///
  /// Aralığın DARALMASI bilinçli: geniş aralık genç bir unvanda ferah, üst
  /// çağda ise kütlesiz duruyor. Kalın ve sıkı bir ad daha "ağır" okunuyor.
  static TextStyle adStili(int unvanIndeksi, double boy) {
    final cag = Unvan.cagIndeksi(unvanIndeksi);
    final k = UnvanPaleti.of(Unvan.adIndeksi(unvanIndeksi));
    return Palette.mono(
      boy,
      weight: switch (cag) {
        0 => FontWeight.w500,
        1 => FontWeight.w600,
        2 => FontWeight.w700,
        _ => FontWeight.w900,
      },
      color: k.acik,
      spacing: switch (cag) {
        0 => boy * .12,
        1 => boy * .10,
        2 => boy * .08,
        _ => boy * .06,
      },
    ).copyWith(
      // Hale YILDIZ çağından itibaren: aşağıda hiçbir şey yapmıyor gibi
      // görünen bir gölge, üst çağda adı zeminden ayırıyor.
      shadows: cag >= 2
          ? [
              Shadow(
                color: k.taban.withValues(alpha: cag >= 3 ? .85 : .55),
                blurRadius: boy * (cag >= 3 ? .9 : .55),
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adIndeksi = Unvan.adIndeksi(unvanIndeksi);
    final k = UnvanPaleti.of(adIndeksi);

    Widget metin = Text(
      // [menuUpper] DEĞİL: unvan adı çevrilmeyen bir özel ad (Squire,
      // Knight, Star Lord). Noktalı `i` kuralı burada "KNİGHT" yazardı.
      ad.toUpperCase(),
      style: adStili(unvanIndeksi, boy),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // ÖLÜMSÜZLÜK çağı: ad kendi renginden kora giden bir gradyanla
    // dolduruluyor. Yalnız son çağda, çünkü etkisi ancak nadir olduğunda
    // etki: her rankta gradyan varsa hiçbir rank gradyanlı değildir.
    if (Unvan.cagIndeksi(unvanIndeksi) >= 3) {
      metin = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [k.acik, k.kor, k.acik],
        ).createShader(r),
        child: metin,
      );
    }
    return metin;
  }
}
