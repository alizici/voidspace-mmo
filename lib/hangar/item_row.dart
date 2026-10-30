import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import 'item_glyph.dart';
import 'menu_cells.dart';
import 'menu_theme.dart';

/// Mağazadaki BİR ÜRÜN — parça, mühimmat, görünüş ya da gemi.
///
/// **Neden kart değil satır.** Kart ızgarası telefon yatayda 250 piksellik
/// kartlar üretiyordu ve o genişlikte eşya adı kesiliyor, fiyatla düğme
/// alt alta yığılıyordu. Yatay kilitli bir oyunda bol olan şey GENİŞLİK:
/// tek bir satır adı, statı, fiyatı ve düğmeyi aynı hizada taşıyor ve
/// hiçbirini kırpmıyor. Üstelik kartın altındaki geniş boşluk da kalkıyor —
/// mağazanın telefondaki asıl sorunu oydu.
///
/// **Neden tek bileşen.** Lazer, jeneratör, mermi, tasarım ve GEMİ aynı
/// satır. Gemiye ayrı bir kart yazmak, iki tasarımın zamanla birbirinden
/// ayrılması demekti — ve ayrıldığı gün oyuncu iki farklı mağaza öğrenmek
/// zorunda kalır. Tipe özel olan şey DÜZEN değil VERİ: açılan bölüm iki
/// jenerik listeden ([chips] ve [panel]) kuruluyor, ikisi de boşsa satır hiç
/// açılmıyor ve oku da çizilmiyor.
///
/// **Neden büyüme dikeyde.** Kapalı satırın boyu içindeki en uzun şeyden
/// çıkıyor ([Cells.tile] kadar hücre, [MenuButton] kadar düğme) ve sabit;
/// yuva haritası ile taban statlar açılınca geliyor. Yeni bir stat eklemek
/// kapalı satırı bozmuyor, yalnız açılan bölümü uzatıyor.
///
/// **Metin DIŞARIDAN geliyor.** Satırın kendi sözlüğü yok: düğme yazısı,
/// durum notu, etiketler — hepsi çağıranın `Metin`'den okuduğu dizeler.
/// İçeride elle yazılmış tek bir Türkçe dize kalsaydı, üç dilin ikisi o
/// satırda sessizce eksik olurdu.
class ItemRow extends StatefulWidget {
  const ItemRow({
    required this.metrics,
    required this.title,
    required this.color,
    required this.actLabel,
    required this.onAct,
    this.leading,
    this.glyph,
    this.tier,
    this.summary,
    this.mainValue,
    this.mainLabel,
    this.price,
    this.birimliFiyat = false,
    this.affordable = true,
    this.priceOverride,
    this.priceColor,
    this.stateNote,
    this.stateColor = Palette.good,
    this.actKey,
    this.actColor = Palette.accent,
    this.actFilled = true,
    this.chips = const [],
    this.panel = const [],
    this.acik = false,
    super.key,
  });

  final MenuMetrics metrics;

  final String title;

  /// Yuva türünün rengi — hücre, satır ve yuva aynı rengi taşıyor. Oyuncu
  /// rengi bir kez öğreniyor, üç yerde işine yarıyor.
  final Color color;

  /// Eylem düğmesinin yazısı. `null` ise DÜĞME HİÇ ÇİZİLMİYOR.
  ///
  /// Satılmayan bir şeyin kapalı düğmesi "bozuk" okunur; olmayan düğme
  /// "satılık değil" okunur. Bedava mühimmat ve sahip olunan görünüş tam
  /// olarak bu durumda.
  final String? actLabel;

  final VoidCallback? onAct;

  /// Sol baştaki resim — gemi silüeti, droid çizimi. Verilmezse [glyph]'ten
  /// bir hücre kuruluyor; o da yoksa satır resimsiz başlıyor.
  ///
  /// Ayrı bir alan, çünkü satılan şeylerin bir kısmı KENDİ RESMİYLE tanınıyor
  /// (gemi ve droid), geri kalanı ise ana statının işaretiyle.
  final Widget? leading;

  final ItemGlyph? glyph;

  /// Kademe harfi — hücrenin köşesinde. Aynı işareti taşıyan iki eşyayı
  /// ayıran şey.
  final String? tier;

  /// Adın altındaki tek satır: rafın notu, mühimmatın çarpanı, geminin rankı.
  final String? summary;

  /// Ana stat: mağazada yazan sayı, taktığında göreceğin sayı. `null` ise
  /// stat sütunu hiç açılmıyor — görünüş satan bir satır stat vermiyor
  /// (15.9) ve boş bir sütun vaat gibi okunurdu.
  final String? mainValue;
  final String? mainLabel;

  final Price? price;

  /// Fiyat sütunu BİRİM ADINA da yer ayırsın mı ("2.427 NOVA").
  ///
  /// Karar SATIRIN değil LİSTENİN: genişlik satır başına hesaplanınca
  /// kredili bir satır dar, NOVA'lı bir satır geniş fiyat sütunu alıyor ve
  /// solundaki stat sütunu her satırda başka yere düşüyordu — aynı listede
  /// iki satır hizasız duruyordu. Listede NOVA'lı tek bir ürün varsa
  /// sütun hepsinde geniş: hizayı bozan şey, sütunun içeriği değil
  /// içeriğe göre değişmesi.
  final bool birimliFiyat;

  /// Ödenebiliyor mu. Bakiye DEĞİL kararın kendisi: satırın "hangi keseden"
  /// sorusunu kendi başına cevaplaması, NOVA rafı geldiğinde sessizce yanlış
  /// olurdu — 2.430 NOVA'lık eşya 48.000 kredilik cüzdana bakıp "alınabilir"
  /// derdi.
  final bool affordable;

  /// Fiyatın YERİNE yazılan metin — "SAHİPSİN", "YAKINDA".
  final String? priceOverride;
  final Color? priceColor;

  /// Fiyatın altındaki durum — "STOK 148", "SATIŞTA", "BEDAVA · SINIRSIZ".
  final String? stateNote;
  final Color stateColor;

  /// Eylem düğmesinin anahtarı. Düğmenin ÜSTÜNDE, satırın değil: testler ve
  /// görsel referanslar satın alma düğmesine basıyor, satırın gövdesine
  /// basmak yalnız açıp kapatır.
  final Key? actKey;

  final Color actColor;
  final bool actFilled;

  /// Açılan bölümün üst kümesi — geminin yuva haritası. Çipler [EsitIzgara]
  /// ile diziliyor, yani hepsi aynı genişlikte.
  final List<Widget> chips;

  /// Açılan bölümün alt listesi — geminin taban statları.
  final List<RowEntry> panel;

  /// Satır ilk kurulduğunda açık mı.
  final bool acik;

  @override
  State<ItemRow> createState() => _ItemRowState();
}

/// Açılan bölümdeki bir satır: etiket + değer.
///
/// Etiket ve değer YAN YANA duruyor, sığmazsa alt satıra sarıyor. Değeri
/// koşulsuz alt satıra almak "HIZ / 240" gibi üç karakter için bir satır
/// harcıyordu.
class RowEntry {
  const RowEntry(this.label, this.value);

  final String label;
  final String value;
}

/// Satırın kendi ölçüleri.
///
/// Hücre ve aralık [Cells]'ten, kırılma noktası [MenuMetrics]'ten geliyor;
/// burada yalnız o ikisinden türemeyen dört ölçü var ve dördü de tek yerde.
/// Dağıtılmış bir sabit, bir ekranda 44'ü 40 yapmanın en kolay yolu.
abstract final class _Satir {
  /// Yatay iç dolgu.
  static const double yatay = 14;

  /// Dikey iç dolgu. KAPALI SATIRIN BOYUNU BU BELİRLİYOR: içerideki en uzun
  /// şey 44 piksellik hücre ([Cells.tile]) ya da düğme ([MenuButton]) ve
  /// üstüne 17+17 binince satır 78'e oturuyor. Ayrıca bir `minHeight`
  /// sabiti tutmak aynı sayıyı iki yerde tutmak olurdu — ve ikisi ayrışınca
  /// satır sessizce kısalırdı.
  static const double dikey = 17;

  /// Sütunlar arası boşluk. Dar ekranda KISILAN tek şey bu: sütunların
  /// içindeki yazı ölçüsü sabit ve öyle kalmalı.
  static double aralik(MenuMetrics m) => m.tightText ? 8 : 12;

  /// Ana stat sütunu — sayı ve altında statın adı.
  ///
  /// Ad iki satıra sarabiliyor ("KALKAN YENİLENMESİ" hiçbir makul genişliğe
  /// tek satırda girmiyor); sütunu ada göre genişletmek satırın kalanını
  /// yerdi. Sayı ise kesilmemeli, ve en uzunu ("+12.400") 19 puntoda 80
  /// pikselin altında.
  static double stat(MenuMetrics m) => m.tightText ? 68 : 92;

  /// Fiyat sütunu. En uzun fiyat yedi hane ("980.000") ve 19 puntoda ~80
  /// piksel ediyor; altındaki durum notu da aynı sütunda.
  ///
  /// [birimli] NOVA fiyatlarında doğru: onlarda sayının yanında bir de birim
  /// adı yazılıyor ("2.427 NOVA") ve kredi genişliği ona yetmiyordu — sayı
  /// kısalıp "2.4… NOVA" oluyordu. Okunamayan bir fiyat, fiyat değil.
  /// Ana stat sütununun düştüğü genişlik.
  ///
  /// Altında ad, fiyat ve düğme kalıyor; üçü de vazgeçilmez. 430, mağazanın
  /// rayı solda dururken dar bir pencerede satıra kalan alanın hemen
  /// üstünde — ölçüldü.
  static const double statEsigi = 430;

  static double fiyat(MenuMetrics m, {required bool birimli}) =>
      birimli ? (m.tightText ? 124 : 148) : (m.tightText ? 88 : 104);
}

class _ItemRowState extends State<ItemRow> {
  late bool _acik = widget.acik;

  /// Açılacak bir şey var mı. Yoksa ok da çizilmiyor: tıklanınca hiçbir şey
  /// olmayan bir ok, bu arayüzün en pahalı hatası olan sessiz reddin ta
  /// kendisi.
  bool get _detayVar => widget.chips.isNotEmpty || widget.panel.isNotEmpty;

  bool get _fiyatVar =>
      widget.price != null ||
      widget.priceOverride != null ||
      widget.stateNote != null;

  Widget? get _onIsaret {
    if (widget.leading case final ozel?) return ozel;
    if (widget.glyph case final isaret?) {
      return GlyphCell(
        state: CellState.filled,
        glyph: isaret,
        color: widget.color,
        corner: widget.tier,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x07FFFFFF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_detayVar)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _acik = !_acik),
              child: _bas(m),
            )
          else
            _bas(m),
          if (_detayVar && _acik) _detay(m),
        ],
      ),
    );
  }

  Widget _bas(MenuMetrics m) {
    final aralik = _Satir.aralik(m);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _Satir.yatay,
        vertical: _Satir.dikey,
      ),
      // SATIR KENDİ GENİŞLİĞİNE bakıyor, ekranınkine değil.
      //
      // Sütun ölçüleri bir süre [MenuMetrics] üzerinden EKRAN genişliğine
      // bakıyordu ve o iki sayı ayrışabiliyor: mağazanın rayı sola geçince
      // ekran aynı kaldı ama satıra kalan alan 150 piksel daraldı ve satır
      // taşıdı. Satırın sığıp sığmadığını yalnız satırın kendi kutusu
      // bilebilir.
      child: LayoutBuilder(
        builder: (context, box) {
          // ANA STAT İLK DÜŞEN sütun: sayı satırın en soluk parçası ve
          // açılan bölümde zaten çetvelde yazılı. Fiyat ile düğme
          // düşemez — biri kararın kendisi, öteki eylemin tek yolu.
          final statVar =
              widget.mainValue != null && box.maxWidth >= _Satir.statEsigi;
          return Row(
            children: [
              if (_onIsaret case final isaret?) ...[
                isaret,
                SizedBox(width: aralik),
              ],
              Expanded(child: _adBlogu()),
              if (statVar) ...[
                SizedBox(width: aralik),
                SizedBox(
                  width: _Satir.stat(m),
                  child: _statBlogu(m, widget.mainValue!),
                ),
              ],
              if (_fiyatVar) ...[
                SizedBox(width: aralik),
                SizedBox(
                  width: _Satir.fiyat(
                    m,
                    birimli: widget.birimliFiyat,
                  ),
                  child: _fiyatBlogu(m),
                ),
              ],
              if (widget.actLabel case final etiket?) ...[
                SizedBox(width: aralik),
                MenuButton(
                  key: widget.actKey,
                  label: etiket,
                  filled: widget.actFilled,
                  color: widget.actColor,
                  onTap: widget.affordable ? widget.onAct : null,
                ),
              ],
              if (_detayVar) ...[SizedBox(width: aralik), _Ok(acik: _acik)],
            ],
          );
        },
      ),
    );
  }

  Widget _adBlogu() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MenuType.body(),
      ),
      if (widget.summary case final ozet?) ...[
        const SizedBox(height: Cells.gap),
        Text(
          ozet,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MenuType.label(color: Palette.muted),
        ),
      ],
    ],
  );

  Widget _statBlogu(MenuMetrics m, String deger) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        deger,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MenuType.number(m, color: widget.color),
      ),
      if (widget.mainLabel case final etiket?) ...[
        const SizedBox(height: Cells.gap),
        // Etiket [menuUpper]'dan geçiyor: Dart'ın `toUpperCase()`'i noktalı
        // `i`'yi bozuyor ve stat adlarının yarısı noktalı `i` taşıyor
        // ("MENZIL", "KALKAN YENILENMESI"). Dil de veriliyor — kural yalnız
        // Türkçede geçerli, İngilizce bir etikette ters yönde bozardı.
        Text(
          menuUpper(etiket, context.dil),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MenuType.label(color: Palette.muted),
        ),
      ],
    ],
  );

  Widget _fiyatBlogu(MenuMetrics m) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.priceOverride case final metin?)
        // Durum SAYI DEĞİL: "SAHİPSİN" 19 puntoda hem sütunu taşırıyor hem
        // de yanındaki fiyatlarla aynı ağırlıkta okunuyor — oysa okunan şey
        // bir rakam değil bir hâl.
        Text(
          metin,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MenuType.button(color: widget.priceColor ?? Palette.good),
        )
      else if (widget.price case final fiyat?)
        PriceTag(price: fiyat, affordable: widget.affordable, metrics: m),
      if (widget.stateNote case final not?) ...[
        const SizedBox(height: Cells.gap),
        Text(
          not,
          maxLines: 2,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: MenuType.label(color: widget.stateColor),
        ),
      ],
    ],
  );

  Widget _detay(MenuMetrics m) => Container(
    decoration: const BoxDecoration(
      color: Color(0x38000000),
      border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: _Satir.yatay,
      vertical: _Satir.dikey,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.chips.isNotEmpty)
          // ÇİPLER EŞİT GENİŞLİKTE.
          //
          // `Wrap` idi ve her çip kendi etiketinin genişliğindeydi: "CPU ×2"
          // ile "ROKETATAR ×1" yan yana durunca satırlar farklı yerlerde
          // bitiyor, küme merdiven gibi görünüyordu. Çipler bir LİSTE — hepsi
          // aynı şeyi söylüyor (hangi yuvadan kaç tane) ve genişliklerinin
          // farkı bir bilgi taşımıyor.
          //
          // 88, en uzun etiketi ("ROKETATAR ×1") kesmeden alan en küçük
          // genişlik. Satır genişledikçe artan şey SÜTUN SAYISI: çipler
          // uzamıyor, çoğalıyor.
          EsitIzgara(
            enAzGenislik: 88,
            aralik: Cells.gap,
            kutular: widget.chips,
          ),
        if (widget.chips.isNotEmpty && widget.panel.isNotEmpty)
          const SizedBox(height: _Satir.dikey),
        if (widget.panel.isNotEmpty)
          // İkiden uzun liste İKİ SÜTUN: tek sütunda açılan bölüm satırın
          // kendisinden uzun oluyor ve altındaki ürünleri ekrandan itiyor.
          _Cetvel(
            entries: widget.panel,
            columns: widget.panel.length > 2 ? 2 : 1,
          ),
      ],
    ),
  );
}

/// Etiket + değer listesi, bir ya da iki sütun.
class _Cetvel extends StatelessWidget {
  const _Cetvel({required this.entries, required this.columns});

  final List<RowEntry> entries;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final dil = context.dil;
    final satirlar = <Widget>[];
    for (var i = 0; i < entries.length; i += columns) {
      final dilim = entries.skip(i).take(columns).toList();
      satirlar.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + columns < entries.length ? Cells.gap * 2 : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: _Satir.yatay),
                Expanded(
                  child: c < dilim.length
                      ? _kutu(dilim[c], dil)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: satirlar,
    );
  }

  Widget _kutu(RowEntry entry, Dil dil) => Wrap(
    spacing: Cells.gap + 3,
    runSpacing: 2,
    crossAxisAlignment: WrapCrossAlignment.end,
    children: [
      Text(
        menuUpper(entry.label, dil),
        style: MenuType.label(color: Palette.muted),
      ),
      if (entry.value.isNotEmpty)
        Text(
          entry.value,
          style: MenuType.label(
            color: Palette.ink,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
    ],
  );
}

/// Açık/kapalı işareti. Satırın tıklanabilir olduğunu söyleyen tek şey.
class _Ok extends StatelessWidget {
  const _Ok({required this.acik});

  final bool acik;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    child: Transform.rotate(
      angle: acik ? math.pi : 0,
      child: CustomPaint(size: const Size(11, 7), painter: _OkBoyaci()),
    ),
  );
}

class _OkBoyaci extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(1, 1)
        ..lineTo(size.width / 2, size.height - 1)
        ..lineTo(size.width - 1, 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.faint,
    );
  }

  @override
  bool shouldRepaint(_OkBoyaci old) => false;
}
