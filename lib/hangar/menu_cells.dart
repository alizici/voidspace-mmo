import 'package:flutter/material.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import 'item_glyph.dart';
import 'menu_theme.dart';

/// Menü yüzeyinin KAP parçaları: hücre, ızgara, bölüm başlığı, büyük harf.
///
/// `menu_theme.dart` tipografiyi ve düğmeyi tutuyor; buradakiler onun üstüne
/// gelen KAPLAR. Ayrı dosya olmasının sebebi tek: hangar, depo, droid ve
/// materyal ekranları aynı hücreyi çiziyor ve o hücrenin ölçüsü tek yerde
/// durmalı. 44'ü bir ekranda 40 yapmak, dokunma alt sınırını sessizce
/// kaybetmenin en kolay yolu.

/// Büyük harf — DİLE GÖRE.
///
/// Dart'ın `toUpperCase()`'i noktalı `i`'yi `I` yapıyor: "Menzil" → "MENZIL",
/// "Kalkan yenilenmesi" → "KALKAN YENILENMESI". Arayüzdeki her stat etiketi
/// bu çağrıdan geçtiği için hata tek tek değil TOPTAN görünüyor — aynı satırda
/// elle yazılmış "KREDİ RAFI" ile yan yana durunca yazım hatası gibi okunuyor.
///
/// **Kural TEK HARFLİK DEĞİL, çünkü oyun üç dilli.** Noktalı `i` kuralı
/// yalnız Türkçede geçerli; İngilizce ve İtalyancada aynı dönüşüm ters
/// yönde bozuyor: `'Shield regen'` → `SHİELD REGEN`, `'Rigenerazione'` →
/// `RİGENERAZİONE`. Bir dili düzeltirken ikisini bozmak, düzeltmenin kendisi
/// olmaz.
///
/// [dil] verilmediğinde TÜRKÇE varsayılıyor. Varsayılan olmasının sebebi
/// geçiş: çağrı yerlerinin çoğunda `dil` zaten kapsamda ve veriliyor, ama
/// kapsamda olmayan bir yerde çağrıyı imkânsız kılmak, o metni hiç
/// büyütmemek demek olurdu.
String menuUpper(String value, [Dil dil = Dil.turkce]) => dil == Dil.turkce
    ? value.replaceAll('i', 'İ').toUpperCase()
    : value.toUpperCase();

/// Kap ölçüleri. ÖLÇEKLENMİYOR — bkz. [MenuMetrics.tile] yorumundaki kural.
abstract final class Cells {
  /// Yuva ve depo hücresi. iOS'un 44 piksellik dokunma alt sınırı.
  static const double tile = 44;

  /// Droid'in TASARIM yuvası. Kasten küçük: takılan şey stat vermiyor,
  /// görünüm veriyor — ve dokunma hedefi olarak ikincil.
  static const double skin = 28;

  /// Hücreler arası boşluk.
  static const double gap = 5;

  /// Bir ızgaranın kaç sütun sığdırdığı. Sütun sayısı GENİŞLİKTEN çıkıyor,
  /// sabit değil: sabit sütun telefonda hücreyi taşırıyordu.
  static int columns(double width) =>
      ((width + gap) / (tile + gap)).floor().clamp(1, 32);
}

/// Bölüm başlığı: DONANIM, DEPO, MATERYAL DEPOSU.
///
/// Sağdaki sayı hep bir ORAN: "6 / 56 DOLU", "8 / 56". Çıplak bir toplam
/// ("56 yuva") kabın ne kadarının kullanıldığını söylemiyor, ki oyuncunun
/// sorduğu tek soru o.
class PaneHead extends StatelessWidget {
  const PaneHead(this.label, {required this.detail, this.style, super.key});

  final String label;
  final String detail;

  /// Başlığın yazı biçimi; verilmezse bölüm başlığı ölçüsü.
  ///
  /// Tek istisna GEMİ sekmesi: oradaki başlık bir bölüm adı değil GEMİNİN
  /// ADI, yani ekranın konusu. 12 puntoluk bölüm başlığı ölçüsü onu bir alt
  /// yazıya çeviriyordu — telefonda geminin adının yazıldığı tek yer orası.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => SizedBox(
    // Yükseklik yazıya UYUYOR: sabit 18, bölüm başlığı ölçüsüne göre
    // seçilmişti ve daha büyük bir başlık verildiğinde onu kesiyordu.
    height: style == null ? 18 : null,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: style ?? MenuType.section()),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MenuType.label(color: Palette.faint),
          ),
        ),
      ],
    ),
  );
}

/// Bir hücrenin GÖRÜNÜŞÜ — dolu, boş ya da hedef.
///
/// Üç hâl ayrı ayrı beyan ediliyor çünkü aralarındaki fark bir stil tercihi
/// değil BİR SÖZ: kesikli kenar bu arayüzde "seçtiğin parça buraya girer"
/// demek. Kalıcı kesikli çizilen bir yuva, tıklandığında hiçbir şey olmayan
/// bir vaat olur.
enum CellState {
  /// Parça takılı.
  filled,

  /// Boş kap. Çiziliyor: "kaç yerim kaldı" sorusunun cevabı bu.
  empty,

  /// Seçili parça buraya GİREBİLİR.
  target,

  /// Kilitli — ilerlemeyle açılacak.
  locked,
}

/// Envanter hücresi: yuva, depo kabı, materyal yığını.
///
/// Metin değil ŞEKİL taşıyor: 44 piksele "Nişan Devresi" sığmıyor, hücreyi
/// metne göre büyütmek ızgarayı listeye çeviriyordu (bkz. [ItemGlyph]).
class GlyphCell extends StatelessWidget {
  const GlyphCell({
    required this.state,
    this.glyph,
    this.color = Palette.accent,
    this.corner,
    this.badge,
    this.size = Cells.tile,
    this.onTap,
    this.tooltip,
    super.key,
  });

  final CellState state;

  /// Boş hücrede `null`.
  final ItemGlyph? glyph;

  /// Yuva türünün rengi. Oyuncu rengi bir kez öğreniyor; yuva, depo ve mağaza
  /// kartı aynı rengi taşıyor.
  final Color color;

  /// Sol üst: kademe harfi. Aynı işareti taşıyan iki eşyayı ayıran şey.
  final String? corner;

  /// Sağ alt: seviye (`+7`) ya da yığın adedi (`148`).
  final String? badge;

  final double size;
  final VoidCallback? onTap;

  /// İşaret NE olduğunu söylüyor, ad HANGİSİ olduğunu. İkincisi hücreye
  /// sığmıyor ama kaybolmamalı.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: switch (state) {
          CellState.filled => color.withValues(alpha: 0.10),
          CellState.target => color.withValues(alpha: 0.08),
          CellState.empty || CellState.locked => const Color(0x3D000000),
        },
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: switch (state) {
            CellState.filled => color.withValues(alpha: 0.70),
            CellState.target => color.withValues(alpha: 0.60),
            CellState.empty => const Color(0x12FFFFFF),
            CellState.locked => const Color(0x0DFFFFFF),
          },
        ),
      ),
      child: Stack(
        children: [
          if (glyph case final g?)
            Center(child: ItemGlyphIcon(glyph: g, color: color, size: size * 0.5)),
          if (corner case final letter?)
            Positioned(
              left: 4,
              top: 1,
              // KÜÇÜLEBİLİR: rank etiketi 44 piksellik hücreye sığmıyor.
              //
              // "C-I" sığıyor ama "SSS-III" 11 puntoda ~50 piksel ediyor ve
              // hücrede kalan 40'a sığmayıp İKİ SATIRA sarıyordu — plakasız
              // bir hücrede rank yalnız bu harften okunduğu için sarma,
              // bilginin kendisini kaybetmek demek. `FittedBox` uzun etiketi
              // bir tık indiriyor, kısası tam puntoda kalıyor.
              child: SizedBox(
                width: size - 8,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    letter,
                    maxLines: 1,
                    style: MenuType.label(
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
          if (badge case final value?)
            Positioned(
              right: 4,
              bottom: 1,
              child: Text(value, style: MenuType.label(color: Palette.muted)),
            ),
        ],
      ),
    );

    final tappable = onTap == null
        ? cell
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: cell,
          );

    return tooltip == null
        ? tappable
        : Tooltip(
            message: tooltip!,
            waitDuration: const Duration(milliseconds: 400),
            child: tappable,
          );
  }
}

/// Sabit hücreli ızgara — depo, materyal, yuva grubu.
///
/// `GridView` DEĞİL: bu ızgaralar sabit ölçülü ve az sayıda hücre taşıyor,
/// tembel oluşturmanın kazancı yok. `Wrap` sütun sayısını genişlikten
/// kendisi çıkarıyor — [Cells.columns] ile aynı hesap, iki yerde tutmaya
/// gerek kalmadan.
class CellGrid extends StatelessWidget {
  const CellGrid({required this.cells, super.key});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: Cells.gap, runSpacing: Cells.gap, children: cells);
}
