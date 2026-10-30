import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/sayi.dart' as bicim;
import '../game/art/droid_art.dart';
import 'item_glyph.dart';
import 'rank_kutusu.dart';

/// Menü yüzeyinin ortak parçaları: ölçüler, tipografi, çip, düğme, kutucuk.
///
/// Hangar ve mağaza aynı ekranın iki sekmesi; ortak parçaların tek dosyada
/// durması, ikisinin zamanla birbirinden ayrılmasını engelliyor.

/// Pencere sınıfı — Material'ın uyarlanabilir düzen eşikleri.
enum MenuSize {
  /// Telefon yatay: yükseklik 480'in altında.
  compact,

  /// Tablet, küçük pencere.
  medium,

  /// Masaüstü, tam ekran tablet.
  expanded,
}

/// Ekranın ölçüleri ve onlardan çıkan düzen kararları.
///
/// **Sabit sahne + `FittedBox` KALDIRILDI.** Menü 1280×720'lik bir sahneye
/// çizilip ekrana sığdırılıyordu; bu, düzeni değil PİKSELİ ölçekliyor.
/// Sonuçları oyuncunun ikisini de gördüğü iki hâlde:
///
///  * Telefonda ölçek 0.66 — 9 piksellik bir etiket parmağın altında 6
///    piksele iniyor ve okunmuyor. Mobil kılavuzların gövde metni için alt
///    sınırı 14sp; ölçeklenen bir tasarımda o sınırı tutmak imkânsız, çünkü
///    sayı ekranla birlikte küçülüyor.
///  * Mac'te pencere küçüldükçe yazı da küçülüyor. Oysa küçülen pencerede
///    beklenen şey daha AZ İÇERİK görmek, aynı içeriği daha küçük görmek
///    değil.
///
/// Yerine geçen kural: **tipografi ve dokunma hedefleri SABİT, düzen
/// değişken.** Yer azaldığında yazı küçülmüyor; parçalar yeniden diziliyor,
/// sıkışıyor ya da kayboluyor.
/// EŞİT IZGARA — kutu kümelerinin tek düzeni.
///
/// Düğmeler ve çipler için: hepsi aynı genişlikte, satırlar hizalı.
///
/// **Neden var.** Düğmeler `Wrap` içinde, her biri kendi genişliğinde
/// duruyordu. Sonuç ölçülebilir bir düzensizlikti: parça penceresinde altı
/// düğme dört-iki diye sarıyor, satırlar farklı uzunlukta bitiyor, sağ kenar
/// tırtıklı çıkıyordu. Etiket uzunluğu düğmenin genişliğini belirlediği için
/// düzen içeriğe göre her eşyada değişiyordu — aynı pencere iki parçada iki
/// farklı şekil alıyordu.
///
/// Burada düzen İÇERİKTEN BAĞIMSIZ: bütün düğmeler aynı genişlikte, sütun
/// sayısı yerden çıkıyor, satırlar hizalı. "ÇEVİR" ile "DROİDE TAK" aynı
/// kutuya giriyor.
///
/// **Son satır dolmuyorsa boş kalıyor, esnetilmiyor.** Tek kalan düğmeyi tam
/// genişliğe yaymak ona hak etmediği bir ağırlık verirdi — ve o düğme çoğu
/// zaman PARÇALA gibi yıkıcı bir eylem oluyor.
class EsitIzgara extends StatelessWidget {
  const EsitIzgara({
    required this.kutular,
    this.enAzGenislik = 132,
    this.aralik = 8,
    super.key,
  });

  final List<Widget> kutular;

  /// Bir düğmenin altına düşmemesi gereken genişlik — sütun sayısı bundan
  /// çıkıyor. Etiketler kısa ve tek aralıklı; 132 piksel "DROİDE TAK"ı
  /// kesmeden alıyor.
  final double enAzGenislik;

  final double aralik;

  @override
  Widget build(BuildContext context) {
    if (kutular.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final sutun = box.maxWidth.isFinite
            ? math.max(
                1,
                math.min(
                  kutular.length,
                  ((box.maxWidth + aralik) / (enAzGenislik + aralik)).floor(),
                ),
              )
            : kutular.length;
        final genislik = box.maxWidth.isFinite
            ? (box.maxWidth - aralik * (sutun - 1)) / sutun
            : enAzGenislik;
        final satirlar = <Widget>[];
        for (var i = 0; i < kutular.length; i += sutun) {
          final dilim = kutular.sublist(
            i,
            math.min(i + sutun, kutular.length),
          );
          satirlar.add(
            Row(
              children: [
                for (var j = 0; j < dilim.length; j++) ...[
                  if (j > 0) SizedBox(width: aralik),
                  SizedBox(width: genislik, child: dilim[j]),
                ],
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < satirlar.length; i++) ...[
              if (i > 0) SizedBox(height: aralik),
              satirlar[i],
            ],
          ],
        );
      },
    );
  }
}

/// Ekran DİKEYDE kıt mı — bileşenin kendi kendine sorabildiği hâli.
///
/// [MenuMetrics.dense] ile aynı eşik ve aynı sebep. Ayrı bir işlev, çünkü
/// düğme ve sekme ölçüleri her çağrı yerine `metrics` geçirmeden de
/// daralabilmeli: aksi hâlde ekrandaki her düğmenin imzası değişirdi ve
/// değişmeyenler sessizce eski boyda kalırdı.
bool kisaEkran(BuildContext context) =>
    MediaQuery.maybeSizeOf(context)?.height != null &&
    MediaQuery.sizeOf(context).height < 480;

class MenuMetrics {
  const MenuMetrics(this.size);

  final Size size;

  double get width => size.width;
  double get height => size.height;

  /// Yükseklik sınıfı.
  ///
  /// Yatay kilitli bir oyunda DAR OLAN yükseklik: iPhone yatayda ~390dp
  /// yüksekliğe karşılık ~844dp genişlik. Düzeni belirleyen eksen bu — ve
  /// genişliğe bakan bir tasarım telefonda yanlış cevabı verir.
  MenuSize get vertical => height < 480
      ? MenuSize.compact
      : height < 900
      ? MenuSize.medium
      : MenuSize.expanded;

  /// Telefon yatay — dikey yer kıt.
  bool get dense => vertical == MenuSize.compact;

  /// Büyük başlıklar KÜÇÜK ÖLÇÜYE düşsün mü.
  ///
  /// Ölçekleme değil, kırılma noktası: 26 piksellik gemi adı 560 piksellik
  /// bir pencerede düğmelerle yarışıp `GOLIA…` diye kesiliyordu. Sayfanın
  /// KONUSU olan metni kesmektense bir kademe küçültmek doğru — ama kademe
  /// belli ve okunabilir sınırın üstünde, pencereyle sürekli değişen bir
  /// katsayı değil.
  bool get tightText => dense || width < 700;

  /// İki bölme yan yana sığmıyor: DONANIM ve DEPO sekmeye dönüşüyor.
  ///
  /// Material'ın liste-ayrıntı kuralı: dar sınıfta iki bölme tek bölmeye
  /// iner. Yan yana sıkıştırmak ikisini de okunmaz yapardı.
  /// Ölçüt genişlik VE yükseklik.
  ///
  /// Genişlik tek başına yanlış cevabı veriyordu: yatay kilitli bir telefon
  /// 844 piksel GENİŞ ama 390 piksel KISA, yani iki bölme yan yana rahatça
  /// sığıyor ve ikisi de dikeyde eziliyordu. Kıt olan eksen yükseklik; iki
  /// bölmeyi tek bölmeye indirmek o eksende yer açmıyor ama sekme, her
  /// bölmeye TAM yüksekliği veriyor ve kaydırma ihtiyacını kaldırıyor.
  bool get singlePane => width < 640 || dense;

  /// Mağaza kategorileri DİKEY kenar çubuğu olarak durabilir mi.
  ///
  /// Ölçüt genişlik DEĞİL yükseklik: kenar çubuğu dikey bir liste ve beş
  /// kategori × 44 piksel + boşluklar ~294 piksel ediyor. Telefon yatayda
  /// 390 piksel yükseklik var, başlık ve boşluklar düşünce kalan 302 —
  /// golden testinde tam olarak 21 piksel taştı. Orada liste yatay bir şeride
  /// dönüyor.
  bool get sideCategories => !dense && !singlePane;

  /// Gövde önizlemesi YALNIZ yer varken. Süs değil ama zorunlu da değil;
  /// dikey yer kıtken yerini yuvalara bırakıyor.
  bool get showPreview => !dense && width >= 820;

  /// Kenar boşluğu — 8'in katları.
  double get gutter => dense ? 16 : 24;

  /// Bölümler arası dikey boşluk.
  double get gap => dense ? 12 : 18;

  /// Envanter hücresi. ÖLÇEKLENMİYOR: dokunma hedefi ekranla küçülemez.
  ///
  /// 72'den 56'ya indi. 72, hücreye eşya ADINI sığdırmak için gerekiyordu ve
  /// ızgarayı listeye çeviriyordu; ad yerine işaret çizilince (bkz.
  /// [ItemGlyph]) o gereklilik düştü. 56 hâlâ iOS'un 44 piksellik dokunma
  /// alt sınırının üstünde — daha aşağısı klasik görünürdü ama basılamazdı.
  ///
  /// Telefonda 48. Ölçekleme değil, İKİ kademe: 56 masaüstünde, 48 dikey yeri
  /// kıt ekranda. 48 hâlâ iOS'un 44 piksellik dokunma alt sınırının üstünde,
  /// yani kural çiğnenmiyor — yalnız payı daralıyor. Karşılığında bir sıra
  /// 8 piksel, üç sıra 24 piksel kazanıyor ve ızgara kaydırmadan sığıyor.
  double get tile => dense ? 48 : 56;

  /// Hücreler arası boşluk.
  double get cellGap => dense ? 4 : 6;

  /// Mağaza kartının en küçük genişliği — sütun sayısı buradan çıkıyor.
  double get cardWidth => 250;
}

/// Menünün tipografisi.
///
/// **Tek aralıklı ve SABİT.** Tek aralıklı çünkü menüdeki her sayı bir
/// başkasıyla karşılaştırılmak için orada; orantılı bir yazı tipinde rakamlar
/// farklı genişlikte olduğu için sütunlar kayıyor. Sabit çünkü okunabilirlik
/// pencere boyutuna bağlı olamaz.
///
/// Ölçek mobil kılavuzlara göre: gövde 14, etiket 11, hiçbir şey 10'un altında
/// değil. Eski tasarımda 8 ve 9 piksellik etiketler vardı ve ölçeklendiklerinde
/// okunmuyorlardı.
abstract final class MenuType {
  static TextStyle _s(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = Palette.ink,
    double spacing = 0,
    double? height,
  }) => TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );

  /// Ekran adı.
  static TextStyle title(MenuMetrics m) => _s(
    m.tightText ? 17 : 20,
    weight: FontWeight.w700,
    color: Palette.inkBright,
    spacing: 4,
  );

  /// Başlığın yanındaki ikincil metin.
  static TextStyle subtitle() => _s(13, color: Palette.faint, spacing: 2);

  /// DONANIM, DEPO, KATEGORİLER.
  static TextStyle section() =>
      _s(12, weight: FontWeight.w700, color: Palette.faint, spacing: 2.5);

  /// Eşya adı, gemi adı — gövde metni.
  static TextStyle body({Color color = Palette.ink}) =>
      _s(14, weight: FontWeight.w600, color: color);

  /// Etiket, birim, açıklama. Mobil alt sınırı.
  static TextStyle label({Color color = Palette.muted}) =>
      _s(11, color: color, spacing: 0.5);

  /// Kutucuğun içindeki eşya adı.
  static TextStyle tile({required Color color}) =>
      _s(11, weight: FontWeight.w700, color: color, height: 1.2);

  /// Büyük sayı — stat değeri.
  static TextStyle number(MenuMetrics m, {Color color = Palette.ink}) =>
      _s(m.dense ? 16 : 19, weight: FontWeight.w700, color: color, height: 1);

  /// Düğme yazısı.
  static TextStyle button({Color color = Palette.ink}) =>
      _s(13, weight: FontWeight.w700, color: color, spacing: 1);

  /// Geminin adı — bannerdaki en büyük metin.
  static TextStyle hero(MenuMetrics m) => _s(
    m.tightText ? 20 : 26,
    weight: FontWeight.w700,
    color: Colors.white,
    spacing: 4,
    height: 1,
  );
}

/// Menü yüzeyi: kendi zeminini ve metin varsayılanını kurar, ölçüleri hesaplar.
class MenuSurface extends StatelessWidget {
  const MenuSurface({required this.builder, super.key});

  final Widget Function(BuildContext, MenuMetrics) builder;

  @override
  Widget build(BuildContext context) => Material(
    // `Material` şart, süs değil: Material atası olmayan bir ağaçta `Text`
    // varsayılan biçimi kullanıyor ve o biçim SARI ALT ÇİZGİLİ. Menü tam ekran
    // bir yüzey, yani kendi metin varsayılanını kendisi kurmalı — çağıranın
    // ağacında bir `Scaffold` bulunduğunu VARSAYMAK, ekranı nereden açıldığına
    // bağımlı yapardı.
    color: Palette.menuBg,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.menuPanel, Palette.menuBg],
        ),
      ),
      // Çentik ve ev çubuğu: telefonda yatayken çentik SOLDA ya da SAĞDA
      // kalıyor ve altına düşen bir düğme tıklanamıyor.
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              builder(context, MenuMetrics(constraints.biggest)),
        ),
      ),
    ),
  );
}

/// Binlik ayraçlı sayı. Menüdeki her sayı karşılaştırılmak için orada;
/// `120000` ile `12000`'i ayırmak ayraçsız gözle yapılamıyor.
///
/// Ayraç DİLE bağlı ve bu bir süs değil: `12.400` Türkçe'de on iki bin dört
/// yüz, İngilizce'de on iki nokta dört okunuyor (bkz. `lib/dil/sayi.dart`).
String menuNumber(num value, Dil dil) => bicim.sayi(value, dil);

/// Bölüm etiketi — DONANIM, DEPO, KATEGORİLER.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // İKİSİ DE ESNEK.
      //
      // Sabit genişlikte iki metin, satıra sığmadığı anda taşma hatası
      // veriyor: mağazanın 150 piksellik rayında "KATEGORİLER" başlığı tam
      // olarak öyle yaptı. Bir başlık, dar bir sütuna konduğunda kısalmalı —
      // ekranı kırmızıya boyamamalı.
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MenuType.section(),
        ),
      ),
      if (trailing case final value?) ...[
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: MenuType.label(color: Palette.faint),
          ),
        ),
      ],
    ],
  );
}

/// Bir para biriminin RENGİ.
///
/// İki birim aynı renkte olamaz: oyuncu ekranda hangi keseye baktığını
/// sayıdan değil renkten okuyor. Kredi kehribar (bol, sıcak), NOVA ise
/// menekşe (kıt, soğuk) — ve bu ayrım fiyat etiketinden cüzdana kadar aynı.
Color currencyColor(Currency currency) => switch (currency) {
  Currency.credit => Palette.boost,
  Currency.premium => Palette.slotLauncher,
};

/// Para göstergesi.
class WalletChip extends StatelessWidget {
  const WalletChip({
    required this.value,
    required this.metrics,
    this.currency = Currency.credit,
    super.key,
  });

  final String value;
  final MenuMetrics metrics;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final color = currencyColor(currency);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Dar ekranda birimin ADI DÜŞÜYOR: nokta ve renk zaten neyin
        // sayıldığını söylüyor. Sayının kendisi düşemez — küçültülemez de.
        if (!metrics.dense) ...[
          Text(paraAdi(currency, context.dil), style: MenuType.label()),
          const SizedBox(width: 8),
        ],
        Text(
          value,
          key: walletValueKey(currency),
          style: MenuType.number(metrics, color: color),
        ),
      ],
    );
  }
}

/// Fiyat etiketi: sayı + hangi para.
///
/// Ayrı bir bileşen çünkü mağazadaki her kart aynı iki soruyu soruyor —
/// "ne kadar" ve "hangi keseden". İkincisini kartlara bırakmak, NOVA rafının
/// kredi rengiyle çizildiği bir ekran demekti.
class PriceTag extends StatelessWidget {
  const PriceTag({
    required this.price,
    required this.affordable,
    this.metrics,
    super.key,
  });

  final Price price;

  /// Ödenebiliyor mu. Yetmeyen fiyat SOLUK çiziliyor — düğme zaten kapalı,
  /// ama kapalı bir düğmenin sebebini söyleyen tek şey bu.
  final bool affordable;

  final MenuMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics ?? MenuMetrics(MediaQuery.sizeOf(context));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            menuNumber(price.amount, context.dil),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MenuType.number(
              m,
              color: affordable ? currencyColor(price.currency) : Palette.faint,
            ),
          ),
        ),
        // Kredi rafında birim adı YAZILMIYOR: mağazanın gövdesi kredi ve her
        // karta "KREDİ" yazmak, ayırt edici olan tek şeyi (NOVA) gürültüye
        // gömerdi.
        if (price.currency != Currency.credit) ...[
          const SizedBox(width: 6),
          // BİRİM ADI DA ESNEK.
          //
          // Sayı esnekti, birim adı değildi: dar bir kartta sayı sıfıra
          // kadar kısılsa bile "NOVA" sabit kalıyor ve satır taşıyordu.
          // Ölçüldü — dar ekranda görünüş kartında 8 piksel. Sabit
          // genişlikte bir öğe, satıra eklenen her şeyi bir taşmaya
          // çeviriyor; buradaki iki öğenin ikisi de kısalabilmeli.
          Flexible(
            child: Text(
              paraAdi(price.currency, context.dil),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MenuType.label(
                color: affordable
                    ? currencyColor(price.currency)
                    : Palette.faint,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bir cüzdanın SAYISI — testler metni değil bunu arıyor.
///
/// Metinle aramak biçime bağlanmak demek: binlik ayracı eklendiği gün
/// `'6000 kredi'` arayan test, ekran doğru çalışırken kırmızıya dönerdi.
Key walletValueKey(Currency currency) => Key('menu-wallet-${currency.key}');

/// Menünün düğmesi.
class MenuButton extends StatelessWidget {
  const MenuButton({
    required this.label,
    required this.onTap,
    this.filled = true,
    this.color = Palette.accent,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 44 iOS'un dokunma alt sınırı — ve ölçeklenmiyor.
        //
        // YÜKSEKLİK küçülmüyor, YATAY DOLGU küçülüyor. Telefonda aynı satırda
        // üç düğme, beş stat ve gemi adı var; kazanılması gereken şey
        // genişlik. Yüksekliği kırpmak dokunma hedefini alt sınırın altına
        // indirirdi ve o sınırın altındaki bir "TÜMÜNÜ SÖK" düğmesi yanlışlıkla
        // basılan bir düğmedir.
        constraints: const BoxConstraints(minHeight: 44),
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: kisaEkran(context) ? 10 : 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.white.withValues(alpha: 0.04)
              : (filled ? color : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: (!enabled || !filled)
              ? Border.all(
                  color: enabled
                      ? color.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.09),
                )
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MenuType.button(
            color: !enabled ? Palette.faint : (filled ? Palette.space : color),
          ),
        ),
      ),
    );
  }
}

/// Sekme düğmesi — üst navigasyon, bölme seçici ve kategori listesi.
class MenuTab extends StatelessWidget {
  const MenuTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.expand = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Sağdaki sayı — kategori listesinde kaç ürün olduğu.
  final String? trailing;

  /// Tam genişlik (kenar çubuğu / bölme seçici) mi, içerik kadar mı.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Palette.space : Palette.inkDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Sekme telefonda 38'e iniyor, düğmeler 44'te kalıyor.
        //
        // Ayrım kasıtlı: yanlış sekmeye basmanın bedeli bir dokunuş, yanlış
        // düğmeye basmanınki donatımın sökülmesi. Dokunma alt sınırından
        // ödün verilecekse, bedeli en ucuz olan yerde verilir.
        constraints: BoxConstraints(minHeight: kisaEkran(context) ? 38 : 44),
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: kisaEkran(context) ? 9 : 14),
        decoration: BoxDecoration(
          color: selected
              ? Palette.accent
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: expand
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuType.button(color: ink),
              ),
            ),
            if (trailing case final count?) ...[
              const SizedBox(width: 10),
              Text(
                count,
                style: MenuType.label(
                  color: selected ? Palette.space : Palette.faint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yuva türünün rengi. Yuva, depo ve mağaza kartı aynı rengi taşıyor —
/// oyuncu rengi bir kez öğreniyor, üç yerde işine yarıyor.
Color slotColor(SlotType type) => switch (type) {
  SlotType.laser => Palette.slotLaser,
  SlotType.generator => Palette.slotGenerator,
  SlotType.launcher => Palette.slotLauncher,
  SlotType.cpu => Palette.slotCpu,
  SlotType.droid => Palette.slotDroid,
};

/// Yuva türünün okunabilir adı.
/// Bir stat değerini BİRİMİYLE yazar.
///
/// Oran statları yüzde, mutlak olanlar tam sayı. Ayrımı STAT KÜTÜPHANESİ
/// söylüyor ([StatDef.percent]) — tahmin edilmiyor.
///
/// **Bir süre tahmin ediliyordu ve yanlış çıktı.** Eski kural "değer 1'den
/// küçükse yüzdedir" idi ve C ailesinde tutuyordu: hasar artışı %2,8, yani
/// 0,028. Merdiven yirmi ranka uzayınca aynı stat Parlayan Pembe'de 52'ye
/// çıktı — %5.200 — ve kart onu "52" diye, birimsiz bir tam sayı gibi yazdı.
/// S-II'de daha da kötüydü: 0,94 → "%94,0" ama 1,0 → "1". Aynı satırda aralık
/// "%94,0 – 1" okunuyordu.
///
/// Kütüphane zaten biliyor; buraya kopyalanan bir eşik, kütüphaneden
/// sessizce ayrışan ikinci bir gerçekti.
String bicimliStat(String statId, double deger, Dil dil) {
  final oran = Stats.byId(statId)?.percent ?? false;
  if (!oran) return menuNumber(deger.round(), dil);
  final puan = deger * 100;
  // %100'ün altında BİR ondalık, üstünde tam sayı. C ailesinde alt statlar
  // %1,7 ile %4,0 arasında ve tam sayıya yuvarlamak aralığı yiyor: "%2,4 –
  // %3,5" "%2 – %4" oluyor, roll çubuğunun iki ucu anlamını kaybediyor.
  // %5.200'de ise ondalık gürültü.
  //
  // Yüzde işaretinin YERİ de dilden geliyor: Türkçe `%2,4`, İngilizce `2.4%`.
  if (puan.abs() < 100) return bicim.yuzde(puan, dil, basamak: 1);
  return bicim.yuzde(puan.round(), dil);
}

String slotLabel(SlotType type, Dil dil) => yuvaAdi(type, dil);

/// Envanter hücresi: bir yuva ya da depodaki bir parça.
///
/// Boş hücre de ÇİZİLİYOR. Klasik envanterin çalışma biçimi bu: kap görünür,
/// içi dolar. Yalnız dolu hücreleri çizmek "kaç yerim kaldı" sorusunu
/// cevapsız bırakıyordu.
class SlotTile extends StatelessWidget {
  const SlotTile({
    required this.color,
    required this.metrics,
    this.glyph,
    this.droid,
    this.tier,
    this.tooltip,
    this.onTap,

    /// UZUN BASMA — türün standart "bu ne?" hareketi.
    ///
    /// Dokunuş zaten dolu (yuvada seçer, depoda bilgi açar) ve üçüncü bir
    /// eylem için yeni bir düğme koymak ızgarayı okunmaz yapardı. Uzun basma
    /// hiçbir şeyi bozmadan ekliyor.
    this.onLongPress,
    this.upgrade = false,
    this.selected = false,
    this.level = 0,
    this.note,
    this.rank,
    this.dayaniklilik,
    super.key,
  });

  /// Boş hücrede `null`.
  final ItemGlyph? glyph;

  /// Eşya bir DROİDSE tasarımı; değilse `null`.
  ///
  /// [glyph]'i EZİYOR. Glif ana stattan türüyor ve droidin ana statı
  /// `hasar_artisi` olduğu için her droid roketatar işareti alıyordu; on
  /// tasarımın onu da aynı yanlış işaretle duruyordu. Droid, statıyla değil
  /// GÖRÜNÜŞÜYLE tanınan tek eşya — oyuncu onu satın alırken de savaşta da
  /// resmiyle görüyor.
  final DroidCizimi? droid;

  /// Kademe harfi — köşede. Aynı işareti taşıyan iki eşyayı ayıran şey.
  final String? tier;

  /// Eşyanın RANKI — hücrenin zemin plakası bundan geliyor.
  ///
  /// Harften ayrı ve ikisi birden duruyor: plaka rankı UZAKTAN okutuyor (aile
  /// rengi + basamak çerçevesi), harf ise yakından kesinleştiriyor. Yirmi
  /// basamağı yalnız renkle ayırmak, "S-II mi S-III mü" sorusunu bir ton
  /// farkına indirgerdi.
  ///
  /// `null` — boş yuva ya da rankı olmayan bir şey. O zaman eski düz zemin.
  final ItemTier? rank;

  /// Uzun basınca / üstüne gelince görünen tam ad.
  ///
  /// İşaret ne olduğunu söylüyor, ad hangisi olduğunu. İkincisi hücreye
  /// sığmıyor ama kaybolmamalı.
  final String? tooltip;

  final Color color;
  final MenuMetrics metrics;
  final VoidCallback? onTap;

  /// UZUN BASMA — türün standart "bu ne?" hareketi.
  final VoidCallback? onLongPress;

  /// YÜKSELTME İŞARETİ — bu parça takılıysa savaş puanı artıyor.
  ///
  /// Küçük ve YEŞİL: türün ortak dili. Rozet değil OK, çünkü söylediği şey
  /// bir nitelik değil bir YÖN — "buna geçersen yukarı gidersin".
  final bool upgrade;

  /// Seçili yuva — ayrıntı şeridi bunu anlatıyor.
  final bool selected;

  /// Yükseltme seviyesi; 0 ise rozet çizilmiyor.
  final int level;

  /// Hücre tıklanamıyorsa SEBEBİ — hücrenin İÇİNE, alt şerit olarak.
  ///
  /// Sessiz ret yok: "bastım, hiçbir şey olmadı" bu arayüzün en pahalı hatası
  /// olurdu — oyuncu kuralı öğrenemeden vazgeçer.
  ///
  /// Hücrenin ALTINDA duruyordu ve ızgaranın ritmini bozuyordu: notu olan
  /// sıra ötekilerden yüksek çıkıyor, klasik envanterin en belirgin özelliği
  /// olan hizalı kap görüntüsü kayboluyordu. İçeride yazınca ızgara hizalı
  /// kalıyor ve sebep yine görünüyor.
  final String? note;

  /// DROİD DAYANIKLILIĞI — hücrenin alt kenarında ince bir şerit (05.10).
  ///
  /// `null` ya da tam sayaç ise çizilmiyor: her hücrede duran dolu bir çubuk
  /// hiçbir şey söylemez, yalnız ızgarayı gürültüye boğar. Sayı pencerede;
  /// buradaki şerit tek bir soruyu cevaplıyor — "hangisi bitmek üzere".
  final int? dayaniklilik;

  @override
  Widget build(BuildContext context) {
    // Kutunun KENDİSİ artık burada çizilmiyor: zemin, çerçeve, köşe kolları,
    // yörünge, artı rozeti, takılı halkası ve yükseltme işareti tek bir
    // bileşende ([RankKutusu]). Burada kalan tek şey hücrenin dokunma
    // davranışı ve kutuya girmeyen iki katman — kademe harfi ve ret notu.
    final cell = Stack(
      children: [
        RankKutusu(
          boy: metrics.tile,
          rank: rank,
          arti: level,
          yukseltme: upgrade,
          secili: selected,
          secimRengi: Palette.accentBright,
          isaret: switch ((droid, glyph)) {
            (final DroidCizimi model?, _) => KutuIsareti.droid(model),
            (_, final ItemGlyph glif?) => KutuIsareti.esya(glif, color),
            _ => null,
          },
        ),
        if (tier case final letter?)
          Positioned(
            left: 4,
            top: 2,
            child: Text(
              letter,
              style: MenuType.label(color: color.withValues(alpha: 0.85)),
            ),
          ),
        if (dayaniklilik case final puan?)
          if (puan < ItemInstance.tamDayaniklilik)
            Positioned(
              left: 3,
              right: 3,
              bottom: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: puan / ItemInstance.tamDayaniklilik,
                  minHeight: 3,
                  backgroundColor: Palette.space.withValues(alpha: 0.75),
                  // Son üç ölüm kırmızı: sayacın bittiği yer, kaybın
                  // geri alınamaz olduğu yer.
                  valueColor: AlwaysStoppedAnimation(
                    puan <= TasarimGirdileri.droidAsinmaPayi * 3
                        ? Palette.danger
                        : Palette.slotDroid,
                  ),
                ),
              ),
            ),
        if (note case final reason?)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 1),
              color: Colors.black.withValues(alpha: 0.55),
              child: Text(
                reason,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuType.label(color: Palette.faint),
              ),
            ),
          ),
      ],
    );

    return SizedBox(
      width: metrics.tile,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPress: onLongPress,
            child: tooltip == null
                ? cell
                : Tooltip(
                    message: tooltip!,
                    waitDuration: const Duration(milliseconds: 400),
                    // Uzun basma BİLGİ penceresine ait olduğunda tooltip
                    // ona yol veriyor.
                    //
                    // `Tooltip`'in varsayılan tetikleyicisi uzun basma ve onu
                    // KENDİ içinde yutuyor: dıştaki `GestureDetector` hiç
                    // haber almıyordu, yani pencere hiç açılmıyordu. Üstelik
                    // ikisi aynı şeyi anlatıyor — tooltip tam adı, pencere
                    // adı ve statları. Pencere varken tooltip yalnız fare
                    // üstüne gelmede kalıyor.
                    triggerMode: onLongPress == null
                        ? TooltipTriggerMode.longPress
                        : TooltipTriggerMode.manual,
                    child: cell,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Sayı üstte büyük, etiket altta küçük — istatistik gösterimi.
class StatCell extends StatelessWidget {
  const StatCell(this.label, this.value, {required this.metrics, super.key});

  final String label;
  final String value;
  final MenuMetrics metrics;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Uzun sayı SARMAZ, KÜÇÜLÜR.
      //
      // Gövde merdiveni sekiz kademeye uzayınca üst kademelerin canı yedi
      // haneye çıktı ("1.164.788") ve filo kartında ikiye bölünüyordu:
      // "1.164.78" alt satırda "8". Sarmak bir sayıyı okunamaz yapıyor —
      // rakamın nerede bittiği belirsizleşiyor.
      //
      // `FittedBox` yerine tek satır + küçültme: `FittedBox` hücreyi
      // genişliğine göre ölçekliyor ve aynı satırdaki iki hücre farklı
      // punto çıkıyordu.
      Text(
        value,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: MenuType.number(
          metrics,
        ).copyWith(fontSize: value.length > 8 ? 15 : null),
      ),
      const SizedBox(height: 2),
      Text(label, style: MenuType.label(color: Palette.faint)),
    ],
  );
}
