import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/metin.dart';
import '../net/hangar_view.dart';
import 'menu_theme.dart';
import 'unvan_amblemi.dart';
import 'unvan_yazisi.dart';

/// PİLOTUN KİMLİĞİ tek satırda: unvan, seviye, savaş puanı.
///
/// Üçü de SUNUCUDAN geliyor: istemci ne unvanı savaş puanından ne seviyeyi
/// kazançtan türetiyor, yalnız yazıyor. Türetseydi iki uç bir gün ayrışır ve
/// oyuncu ekranda "Knight" okurken kapı ona "Squire" derdi.
///
/// Hangar başlığında ve HUD'un hayati değerler panelinde aynı widget: "kimim"
/// sorusunun cevabı iki ekranda aynı biçimde okunuyor. Sunucu henüz ad
/// yollamadıysa (bağlantının ilk karesi) satır hiç çizilmiyor — boş bir
/// unvan yer tutucu değil, yanlış bilgi olurdu.
///
/// Metnin solunda AMBLEM ([UnvanIkonu]): yirmi ad metin olarak birbirine
/// benziyor, amblem adı, kademeyi ve çağı bir bakışta veriyor. İndeks de
/// sunucudan — istemci onu addan geri çözmüyor, çünkü ad bir gün
/// değişebilir (borç defteri B11) ve o gün ikisi ayrışırdı.
/// KARAR 10.4 s2
/// KARAR 10.1 s1
class UnvanSatiri extends StatelessWidget {
  const UnvanSatiri({
    required this.hangar,
    required this.style,
    this.kisa = false,
    this.amblemBoyu = 16,
    super.key,
  });

  final HangarView? hangar;
  final TextStyle style;

  /// Amblemin kenar uzunluğu. Dar başlıkta ve HUD'da küçülüyor: satır
  /// yüksekliğini büyütmemeli, yoksa iki ekranda da taşma üretir.
  final double amblemBoyu;

  /// Yalnız unvan: dar başlıkta seviye ve puana yer yok, ikisi HUD'da ve
  /// geçit isteminde zaten okunuyor.
  final bool kisa;

  /// Adın YANINDAKİ ölçüler: `· SEVİYE 4 · 3.600 BR`. Ad burada YOK, çünkü
  /// adın kendi tipografisi var ([UnvanYazisi]) ve düz metne karışamaz.
  static String olculer(HangarView hangar, Dil dil) => Metin.seviyeVeBr.bicim(
    dil,
    {'seviye': hangar.seviye, 'br': menuNumber(hangar.br.round(), dil)},
  );

  @override
  Widget build(BuildContext context) {
    final h = hangar;
    if (h == null || h.unvanAdi.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UnvanIkonu(
          unvanIndeksi: Unvan.adIndeksi(h.unvan),
          kademe: Unvan.kademe(h.unvan),
          boy: amblemBoyu,
        ),
        const SizedBox(width: 6),
        // Ad KISALMIYOR, ölçüler kısalıyor. İkisi de esnek olduğunda satır
        // daraldıkça ad "SQUIR…" oluyordu: unvanın kendisi okunmaz, yanındaki
        // sayı tam. Dar kipte ölçüler zaten yok, orada ad esneyebilir.
        if (kisa)
          Flexible(
            child: UnvanYazisi(
              ad: h.unvanAdi,
              unvanIndeksi: h.unvan,
              boy: style.fontSize ?? 11,
            ),
          )
        else
          UnvanYazisi(
            ad: h.unvanAdi,
            unvanIndeksi: h.unvan,
            boy: style.fontSize ?? 11,
          ),
        // Ölçüler adın stiline GİRMİYOR: seviye ve puan sabit birer sayı,
        // unvanla birlikte ağırlaşmaları onları da bir rütbe gibi okuturdu.
        if (!kisa) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              olculer(h, context.dil),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}
