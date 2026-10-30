import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../dil/sayi.dart' as bicim;
import '../net/hangar_view.dart';
import 'droid_ikonu.dart';
import 'gemi_ikonu.dart';
import 'item_glyph.dart';
import 'item_row.dart';
import 'menu_cells.dart';
import 'menu_model.dart';
import 'menu_theme.dart';

/// Mağaza: grup rayı solda, raf şeridi üstte, ürün SATIRLARI altta.
///
/// Kararı yine SUNUCU veriyor. Buradaki `onBuy*` geri çağrıları birer niyet;
/// parası yeter mi, eşya zaten var mı — hepsi `HangarRules`'ta sınanıyor.
/// Fiyat da kataloğun kendisinden okunuyor, burada hesaplanmıyor: iki uçta iki
/// ayrı fiyat hesabı olsaydı oyuncu "yazan fiyat bu değildi" derdi.
class ShopPage extends StatefulWidget {
  const ShopPage({
    required this.hangar,
    required this.bandRank,
    required this.metrics,
    required this.headerBuilder,
    required this.kimlik,
    required this.onBuyItem,
    required this.onBuyNova,
    required this.onBuyGorunus,
    required this.onBuyHull,
    required this.onSelectHull,
    required this.onBuyMermi,
    required this.onBuyRoket,
    super.key,
  });

  /// Bir PAKET mermi — birim fiyat kuralın, paket büyüklüğü rafın. Yüz:
  /// beş namlulu gemide yirmi yaylım, bir dövüşlük.
  static const int mermiPaketi = 100;

  final HangarView hangar;

  /// Oyuncunun bulunduğu bandın ilk rankı — raf ona bağlı (15.2): her yuva
  /// tipinde bandın bir altındaki taban eşya. Sunucu da aynı bandı okuyor;
  /// istemcinin gösterdiği raf sunucunun sattığı raf.
  final int bandRank;

  final MenuMetrics metrics;

  /// Başlık satırı hangarla ORTAK: sekmeler ve para her iki yüzeyde de aynı
  /// yerde durmalı, yoksa sekme değiştirmek ekranı sıfırdan okumak olur.
  /// Üst çubuğu KURAN işlev — sağ ucuna raf şeridi giriyor.
  ///
  /// Şerit bir süre kendi satırındaydı ve üstündeki sayfa sekmeleriyle
  /// (HANGAR · MAĞAZA) aynı hizada değildi; iki satır, kıt olan eksenden
  /// yaklaşık 50 piksel yiyordu. Şerit ekranın durumunu anlatıyor, sekmeler
  /// de öyle — ikisi aynı satırda durabilir. Çubuğu mağaza kendisi
  /// kuramıyor (sayfa sekmeleri hangar ekranının durumu), o yüzden dışarıdan
  /// bir işlev geliyor ve şeridi ona veriyoruz.
  final Widget Function(Widget? sag) headerBuilder;

  /// Pilotun unvanı ve iki cüzdan.
  ///
  /// Üst çubuktaydı; artık KATEGORİLER başlığıyla aynı satırda, sağ uçta.
  /// Sebebi hiza: üst çubukta sekmelerle aynı satırı paylaşıyordu ve altındaki
  /// hiçbir sütunla hizalanmıyordu.
  final Widget kimlik;

  final ValueChanged<String> onBuyItem;

  /// NOVA rafından alım — kredi rafından ayrı bir yol, çünkü fiyat modeli ve
  /// kasa ayrı (15.7).
  final ValueChanged<String> onBuyNova;

  /// Görünüş alımı — tasarım ya da formasyon (15.9).
  final void Function(GorunusKalemi kalem, String id) onBuyGorunus;
  final ValueChanged<String> onBuyHull;

  /// Mermi alımı: kimlik ve adet. Sunucu fiyatı kendisi hesaplıyor (17.4).
  final void Function(String mermiId, int adet) onBuyMermi;

  /// Roket alımı: kimlik ve adet; sunucu fiyatı kendisi hesaplıyor (18.3).
  final void Function(String roketId, int adet) onBuyRoket;

  /// Bir PAKET roket — salvo başına bir birim, paket küçük.
  static const int roketPaketi = 20;

  final ValueChanged<String> onSelectHull;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

/// Rafın PROJEYE bakan yüzü — kimlik, yuva, çevrilmiş etiket.
///
/// [ShopShelf] mağazanın ağacını (hangi raf hangi grupta, hangi renkte)
/// biliyor; bu projenin kategori kimliklerini ve üç dilini bilmiyor. İkisini
/// birbirine bağlayan yer burası — modele dokunmadan.
extension RafAlanlari on ShopShelf {
  /// Rafın KİMLİĞİ — eski kategori kimlikleriyle birebir aynı.
  ///
  /// Aynı olması şart: `shopCategoryKey` bu dizeden kuruluyor ve testler ile
  /// görsel referanslar sekmeyi onunla arıyor. Kimlik değişseydi hepsi
  /// "bulunamadı" demeden, var olmayan bir sekmeyi aramaya devam ederdi.
  String get kimlik => switch (this) {
    ShopShelf.laser => 'laser',
    ShopShelf.launcher => 'launcher',
    ShopShelf.generator => 'generator',
    ShopShelf.cpu => 'cpu',
    ShopShelf.droid => 'droid',
    ShopShelf.rocket => 'roket',
    ShopShelf.ammo => 'mermi',
    ShopShelf.hull => 'hull',
  };

  /// Rafın yuva türü; mermi, roket ve gemide `null`.
  ///
  /// [ShopShelf.slot] droidde boş — tasarımın yazıldığı gün droid bir yuva
  /// türü değildi. Bu projede öyle, ve raf katalogdan okunuyor.
  SlotType? get yuva => this == ShopShelf.droid ? SlotType.droid : slot;

  /// Rafın etiketi — ÜÇ DİLDE.
  ///
  /// [ShopShelf.etiket] yuvası olan raflarda zaten çeviriden geçiyor
  /// (`slotLabel`), yuvası olmayan dördünde ise modelin içine yazılmış sabit
  /// Türkçe dizeyi döndürüyor. Mağazanın geri kalanı üç dilde: İngilizce
  /// oynayan biri o dört rafta "FÜZE" görürdü. Karşılıkları `Metin`'de zaten
  /// var, buradan okunuyor.
  String etiketi(Dil dil) => switch (this) {
    ShopShelf.rocket => Metin.magazaRoket(dil),
    ShopShelf.ammo => Metin.magazaMermi(dil),
    ShopShelf.hull => Metin.magazaGemi(dil),
    ShopShelf.droid => slotLabel(SlotType.droid, dil),
    _ => etiket(dil),
  };
}

/// Grubun etiketi. İkisi çeviriden, biri modelden.
///
/// `ShopGroup.label` sabit Türkçe — model dil kapsamını bilmiyor. İki grubun
/// karşılığı `Metin`'de var ve oradan okunuyor; SİSTEM'in yok, `metin.dart`
/// bu çalışmanın dışında ve orada modelin dizesi duruyor. Eksik olan tek
/// şey bir `Metin` satırı.
String _grupAdi(ShopGroup grup, Dil dil) => switch (grup) {
  ShopGroup.silah => Metin.silah(dil),
  ShopGroup.gemi => Metin.magazaGemi(dil),
  ShopGroup.sistem => Metin.magazaSistem(dil),
};

/// NOVA RAFI ve GÖRÜNÜŞ rafları AYRI SEKME DEĞİL.
///
/// NOVA ile alınan taban eşyalar bir süre kendi sekmesindeydi ("NOVA RAFI") ve
/// ayrımın gerekçesi para birimiydi. Ama oyuncunun mağazada sorduğu soru
/// "hangi keseden ödeyeceğim" değil "hangi yuvaya ne alacağım": bir lazer
/// arayan kişi lazerlere bakıyor ve NOVA'lı olanı orada görmeli. Ayrı sekme,
/// aynı sorunun cevabını iki yere bölüyor ve NOVA'lıları görünmez yapıyordu.
///
/// Para birimi kaybolmuyor, YERİ değişiyor: fiyat etiketi hangi keseden
/// ödendiğini zaten rengiyle ve birimiyle söylüyor.
///
/// Aynı gerekçeyle tasarım ve formasyon da DROİD rafının içinde, ayrı
/// başlıklı bölümler olarak duruyor: ikisi de droidin görünüşünü seçtiriyor
/// ve droidini arayan oyuncu ikisini de orada buluyor.

class _ShopPageState extends State<ShopPage> {
  /// Açık RAF. Grup ayrıca tutulmuyor, RAFTAN türüyor ([_grup]): iki ayrı
  /// seçim tutulsaydı "grup SİSTEM ama raf LAZER" gibi imkânsız bir hâl
  /// yazılabilirdi ve o hâlde şerit seçili olmayan bir kümeyi çizerdi.
  ShopShelf _raf = ShopShelf.laser;

  /// Ray genişliği.
  ///
  /// Eski kenar çubuğu 176'ydı çünkü on bir kategoriyi ALT ALTA taşıyordu.
  /// Rayda artık üç grup var; 150 en uzun grup adını ve sayacını kesmeden
  /// alıyor ve kazanılan 26 piksel satırın kendisine gidiyor.
  static const double _rayGenisligi = 150;

  ShopGroup get _grup =>
      ShopGroup.values.firstWhere((g) => g.shelves.contains(_raf));

  /// Bandın rafı (15.2).
  List<ItemSpec> get _raflik => Catalogue.rafFor(widget.bandRank);

  /// Bir yuva tipinin rafı — KREDİ ve NOVA birlikte.
  ///
  /// Kredi tarafı banda bağlı (15.2), NOVA tarafı sabit rankta (15.7). İkisi
  /// aynı listede çünkü ikisi de aynı yuvaya giriyor; ayıran tek şey fiyatın
  /// hangi keseden ödendiği ve onu fiyat etiketi söylüyor.
  List<ItemSpec> _yuvaRafi(SlotType tip) => [
    for (final s in _raflik)
      if (s.slot == tip && s.currency != Currency.premium) s,
    for (final s in Catalogue.novaRafi)
      if (s.slot == tip) s,
  ];

  int _sayi(ShopShelf raf) => switch (raf) {
    ShopShelf.ammo => Mermi.hepsi.length,
    ShopShelf.rocket => Roket.hepsi.length,
    ShopShelf.hull => HullClass.all.length,
    // Droid rafı ÜÇ bölüm taşıyor: droidler, tasarımlar, formasyonlar.
    // Varsayılan formasyon satılmıyor — bir eksik.
    ShopShelf.droid =>
      _yuvaRafi(SlotType.droid).length +
          DroidModeli.merdiven.length +
          Formasyon.hepsi.length -
          1,
    _ => _yuvaRafi(raf.yuva!).length,
  };

  int _grupSayisi(ShopGroup grup) =>
      grup.shelves.fold<int>(0, (toplam, raf) => toplam + _sayi(raf));

  /// Gruba dokunmak o grubun İLK rafını açıyor.
  ///
  /// Grubun kendisi bir içerik değil bir kap; bir kaba dokunup boş bir
  /// gövde görmek, dokunuşun hiçbir şey yapmadığı hissini verirdi.
  void _grubaGec(ShopGroup grup) => setState(() => _raf = grup.shelves.first);

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final dil = context.dil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.headerBuilder(
          _ustSerit(m) ? _rafSeridi(dil, sayac: m.width >= 1000) : null,
        ),
        SizedBox(height: m.gap),
        // RAY HER ÖLÇÜDE SOLDA.
        //
        // Bir süre dar ekranda yatay bir şeride dönüyordu ve gerekçesi
        // "dikey ray sığmıyor" idi. O gerekçe sekiz kategori tek raydayken
        // doğruydu; gruplama gelince rayda üç satır kaldı ve 142 piksel
        // ediyor. Yatay şerit ise KIT OLAN EKSENDEN yiyordu: telefonda
        // yükseklik 390 ve şerit, altındaki raf şeridiyle birlikte iki satır
        // — yaklaşık 100 piksel, ürün listesinin dörtte biri. Ray solda
        // duruyorsa bol olan eksenden (genişlik) 150 piksel alıyor ve
        // yükseklikten hiç almıyor.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: _rayGenisligi, child: _ray(m, dil)),
              SizedBox(width: m.gutter),
              Expanded(child: _bolme(m, dil)),
            ],
          ),
        ),
      ],
    );
  }

  /// Birinci kademe — GRUP rayı.
  ///
  /// Sekiz kategori dikey bir raya sığmıyordu: 8 × 44 + boşluklar 408 piksel
  /// eder, telefon yatayda kullanılabilir yükseklik 358. Kaydırılabilir bir
  /// ray iki kategoriyi ekranın altında bırakıyordu — ilerlemede ne olduğunu
  /// göstermemek demek. Üç grup 142 piksel ediyor ve kaydırmaya hiç ihtiyaç
  /// duymuyor.
  ///
  /// Gruplama keyfî değil, KARARIN kendisine göre: mermi ve roket silahla
  /// aynı karar setinde (ne atacağım), droid ve cpu sistemle.
  Widget _ray(MenuMetrics m, Dil dil) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionLabel(Metin.kategoriler(dil)),
      SizedBox(height: m.gap),
      for (final grup in ShopGroup.values) ...[
        MenuTab(
          key: shopGroupKey(grup),
          label: _grupAdi(grup, dil),
          selected: grup == _grup,
          trailing: '${_grupSayisi(grup)}',
          expand: true,
          onTap: () => _grubaGec(grup),
        ),
        const SizedBox(height: Cells.gap),
      ],
      const Spacer(),
      // Neyin ne kadar ettiğini burada söylemek, her satıra bir açıklama
      // koymaktan ucuz.
      Text(
        Metin.fiyatlarSunucudan(dil),
        style: MenuType.label(color: Palette.faint),
      ),
    ],
  );

  /// Raf şeridi ÜST ÇUBUĞA çıkabilir mi.
  ///
  /// Çıkabildiğinde bir satır kazanılıyor ve pilotun kimliği çubuktan inip
  /// raf başlığıyla aynı hizaya geçiyor. Dar pencerede o hiza mümkün değil:
  /// iki cüzdan ile unvan, raf adının yanına taşıyor — ölçüldü.
  ///
  /// Ölçüt EKRAN genişliği değil, İÇERİĞE KALAN genişlik: rayın 150 pikseli
  /// ile kenar boşlukları düşüldükten sonra kalan. İkisi ayrışabiliyor ve
  /// ekrana bakan bir eşik, 800 piksellik bir pencerede sığmayan bir hizayı
  /// sığar sanıyordu.
  bool _ustSerit(MenuMetrics m) =>
      m.width - m.gutter * 3 - _rayGenisligi >= 620;

  Widget _bolme(MenuMetrics m, Dil dil) {
    final sayi = _sayi(_raf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_ustSerit(m)) ...[_rafSeridi(dil), SizedBox(height: m.gap)],
        // BAŞLIK SATIRI: solda rafın adı, sağ uçta pilotun kimliği.
        //
        // Kimlik üst çubuktaydı ve altındaki hiçbir sütunla hizalanmıyordu.
        // Burada KATEGORİLER başlığıyla aynı satırda duruyor — iki başlık
        // ve bir kimlik, tek bir yatay çizgi üstünde.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: PaneHead(
                _raf.etiketi(dil),
                detail: Metin.urunSayisi.bicim(dil, {'n': sayi}),
              ),
            ),
            if (_ustSerit(m)) ...[
              SizedBox(width: m.gap),
              Flexible(child: widget.kimlik),
            ],
          ],
        ),
        SizedBox(height: m.gap),
        Expanded(child: _liste(m, dil, sayi)),
      ],
    );
  }

  /// İkinci kademe — açık grubun RAF şeridi.
  ///
  /// KAYDIRILMIYOR, sarıyor. Bir grupta en çok dört raf var ve dördü dar
  /// ekranda da yan yana duruyor; kaydırılabilir bir şerit, ucundaki rafı
  /// yine görünmez yapardı — mağazanın on bir sekmeli hâlindeki asıl hata
  /// oydu.
  Widget _rafSeridi(Dil dil, {bool sayac = true}) => Wrap(
    key: shopCategoryStripKey,
    spacing: Cells.gap,
    runSpacing: Cells.gap,
    children: [
      for (final raf in _grup.shelves)
        ShelfChip(
          key: shopCategoryKey(raf.kimlik),
          label: raf.etiketi(dil),
          color: raf.color,
          selected: raf == _raf,
          // Sayaç ÜST ÇUBUKTA düşüyor: dört çip sayaçlarıyla birlikte
          // sayfa sekmelerinin yanına sığmıyor ve alt satıra sarıyor —
          // sarma, hizalamak için yapılan şeyi bozuyor. Sayı içerik
          // başlığında zaten yazılı ("LAZER 2 ÜRÜN").
          trailing: sayac ? '${_sayi(raf)}' : null,
          onTap: () => setState(() => _raf = raf),
        ),
    ],
  );

  Widget _liste(MenuMetrics m, Dil dil, int sayi) {
    // Boş durum SAYIDAN çıkıyor, modeldeki bayraktan değil.
    //
    // [ShelfEmpty] tasarımın yazıldığı gündeki boşluğu anlatıyor ve o gün
    // füze, mühimmat ve droid rafları henüz yoktu. Bu projede üçünün de içi
    // dolu; bayrağa bakmak dolu bir rafa "kapalı" yazmak olurdu. Sayı sıfır
    // olduğu gün metin kendiliğinden geri gelir.
    if (sayi == 0) {
      if (_raf.empty case final bos?) {
        return EmptyPane(title: bos.title, body: bos.body);
      }
    }
    return switch (_raf) {
      ShopShelf.hull => _gemiListesi(m, dil),
      ShopShelf.ammo => _mermiListesi(m, dil),
      ShopShelf.rocket => _roketListesi(m, dil),
      ShopShelf.droid => _droidRafi(m, dil),
      _ => _esyaListesi(_raf.yuva!, m, dil),
    };
  }

  /// Satırlar arası boşluk — hücre ritmiyle aynı.
  ///
  /// Satırların kendi çerçevesi var; aralarına bölüm boşluğu ([MenuMetrics.gap])
  /// koymak listeyi kopuk kutulara bölüyordu. Liste bir liste gibi dursun.
  static Widget _ara(BuildContext context, int index) =>
      const SizedBox(height: Cells.gap);

  // ── Eşya rafları ────────────────────────────────────────────────────

  /// Bir eşyanın FİYATI — hangi raftan geldiğine göre.
  ///
  /// Kredi rafında fiyat 15.2'nin modelinden geliyor ve BANDA bağlı; sunucu
  /// aynı modeli okuyor (`HangarRules.raftanAl`). NOVA'lı eşyada fiyat
  /// tasarımın kendi NOVA fiyatı (15.7). İki ekonomi tek fiyat modeline
  /// bağlanamaz — ama aynı listede durabilirler.
  Price _fiyat(ItemSpec spec) => spec.currency == Currency.premium
      ? Catalogue.priceOf(spec)
      : Catalogue.rafFiyati(widget.bandRank);

  /// Satın alma emri de rafına göre: NOVA'lı eşya ayrı bir sunucu eylemi.
  void _satinAl(ItemSpec spec) => spec.currency == Currency.premium
      ? widget.onBuyNova(spec.id)
      : widget.onBuyItem(spec.id);

  Widget _esyaListesi(SlotType yuva, MenuMetrics m, Dil dil) {
    final specler = _yuvaRafi(yuva);
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: specler.length,
      separatorBuilder: _ara,
      itemBuilder: (_, i) =>
          _esyaSatiri(specler[i], m, dil, birimliFiyat: _birimliRaf(specler)),
    );
  }

  /// Bu rafta NOVA'lı bir ürün var mı.
  ///
  /// Fiyat sütununun genişliğini LİSTE belirliyor, satır değil: satır başına
  /// hesaplanınca kredili satır dar, NOVA'lı satır geniş sütun alıyor ve
  /// solundaki stat sütunu her satırda başka yere düşüyordu.
  bool _birimliRaf(List<ItemSpec> specler) =>
      specler.any((s) => s.currency == Currency.premium);

  Widget _esyaSatiri(
    ItemSpec spec,
    MenuMetrics m,
    Dil dil, {
    bool birimliFiyat = false,
  }) {
    final fiyat = _fiyat(spec);
    // Ana stat BELİRLENİMCİ: hangi parçayı aldığını bilirsin. Değeri gövdeye
    // göre değiştiği için gövdeyle birlikte hesaplanıyor — mağazada gösterilen
    // sayı, taktığında göreceğin sayı.
    final deger = ItemBudget.mainStatValue(spec, 0, widget.hangar.activeHull);
    // DROİD KENDİ RESMİYLE satılıyor, gemilerde olduğu gibi (05.8 s2).
    // Hücrede eskiden yalnız kademe harfi vardı ve o harf satırda zaten iki
    // kez geçiyordu: adın sonunda ("Hilal B-I") ve rank renginde. Oyuncunun
    // bilmediği tek şey NE ALDIĞI idi — on tasarımın hangisi.
    final droid = droidCizimiOf(spec, null);
    return ItemRow(
      metrics: m,
      birimliFiyat: birimliFiyat,
      leading: droid == null
          ? null
          : DroidIkonu(model: droid, boy: DroidIkonu.magazaBoyu),
      glyph: glyphOf(spec),
      tier: spec.tier.label,
      color: slotColor(spec.slot),
      title: esyaAdi(spec, dil),
      // Raftaki her şey TABAN (15.2): alt statı yok, derinlik satılmıyor.
      // Havuzu yazmak olmayanı vaat etmek olurdu — ve bu not KAPALI satırda
      // duruyor, açılan bir bölümde değil: satın alma kararının parçası.
      summary: Metin.tabanAltStatYok(dil),
      mainValue: _statMetni(spec, deger, dil),
      mainLabel: statAdi(spec.mainStat, dil),
      price: fiyat,
      affordable: widget.hangar.canAfford(fiyat),
      actKey: shopBuyKey(spec.id),
      actLabel: Metin.satinAl(dil),
      onAct: () => _satinAl(spec),
    );
  }

  /// Ana statın okunabilir hâli. Yüzdesel statlar `%` ile yazılıyor: `0.12`
  /// diye bir sayı oyuncuya hiçbir şey söylemez.
  String _statMetni(ItemSpec spec, double value, Dil dil) {
    final stat = Stats.byId(spec.mainStat);
    if (stat != null && stat.percent) {
      return '+${bicim.yuzde(value * 100, dil, basamak: 1)}';
    }
    return '+${menuNumber(value, dil)}';
  }

  // ── Droid rafı ──────────────────────────────────────────────────────

  /// DROİD RAFI — droidler, tasarımlar ve formasyonlar TEK sayfada.
  ///
  /// Üçü de aynı şeye bakan oyuncunun işi: droidini alıyor, nasıl göründüğünü
  /// ve filosunun nasıl dizildiğini seçiyor. Ayrı sekmelerdeydiler ve
  /// aralarındaki bağ sekme çubuğunda kayboluyordu — üstelik ikisi mağazanın
  /// en sonundaki, dar ekranda hiç görünmeyen sekmeleriydi.
  ///
  /// Bölümler BAŞLIKLI: tek bir listeye karıştırmak, droid satın almakla
  /// görünüş satın almayı aynı şey gibi gösterirdi. İkincisi güç vermiyor
  /// (15.9) ve o ayrım korunmalı.
  Widget _droidRafi(MenuMetrics m, Dil dil) {
    final droidler = _yuvaRafi(SlotType.droid);
    final tasarimlar = _gorunusler(GorunusKalemi.tasarim, dil);
    final formasyonlar = _gorunusler(GorunusKalemi.formasyon, dil);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final spec in droidler) ...[
          _esyaSatiri(spec, m, dil, birimliFiyat: _birimliRaf(droidler)),
          const SizedBox(height: Cells.gap),
        ],
        SizedBox(height: m.gap),
        PaneHead(
          Metin.magazaTasarim(dil),
          detail: Metin.urunSayisi.bicim(dil, {'n': tasarimlar.length}),
        ),
        SizedBox(height: m.gap),
        for (final (id, ad) in tasarimlar) ...[
          _gorunusSatiri(GorunusKalemi.tasarim, id, ad, m, dil),
          const SizedBox(height: Cells.gap),
        ],
        SizedBox(height: m.gap),
        PaneHead(
          Metin.magazaFormasyon(dil),
          detail: Metin.urunSayisi.bicim(dil, {'n': formasyonlar.length}),
        ),
        SizedBox(height: m.gap),
        for (final (id, ad) in formasyonlar) ...[
          _gorunusSatiri(GorunusKalemi.formasyon, id, ad, m, dil),
          const SizedBox(height: Cells.gap),
        ],
      ],
    );
  }

  /// Bir görünüş bölümünün kalemleri — kimlik ve çevrilmiş ad (15.9).
  List<(String, String)> _gorunusler(GorunusKalemi kalem, Dil dil) =>
      kalem == GorunusKalemi.tasarim
      ? [
          // Ad SANATTAN değil kimlikten okunuyor. Eskisi
          // `DroidCizimi.values[t.index]` ile sanat katalogunun adını alıp onu
          // çeviriyordu ve iki ayrı hata birden taşıyordu: iki
          // numaralandırmanın bugünkü SIRASINA güveniyordu (birine bir tasarım
          // eklendiği gün bütün satırlar sessizce kayardı — resim tarafında
          // aynı tuzağı [droidCizimiAdiyla] zaten atlatıyor), ve çeviriyi
          // görünen ADA soruyordu.
          for (final t in DroidModeli.merdiven)
            (t.name, droidTasarimAdi(t.name, dil, yedek: t.name)),
        ]
      : [
          for (final f in Formasyon.hepsi)
            if (f.id != Formasyon.varsayilan.id) (f.id, formasyonAdi(f, dil)),
        ];

  /// GÖRÜNÜŞ satırı — tasarım ya da formasyon (15.9).
  ///
  /// Sahip olunan kalem listede KALIYOR ve "SAHİP" yazıyor: raftan düşen bir
  /// satır, oyuncuya neyi topladığını göstermez.
  Widget _gorunusSatiri(
    GorunusKalemi kalem,
    String id,
    String ad,
    MenuMetrics m,
    Dil dil,
  ) {
    final tasarim = kalem == GorunusKalemi.tasarim;
    final sahip = tasarim
        ? widget.hangar.tasarimaSahip(id)
        : widget.hangar.formasyonaSahip(id);
    final fiyat = Price.premium(Kazanc.gorunusFiyati(kalem));
    return ItemRow(
      key: shopBuyKey('gorunus-$id'),
      metrics: m,
      // Formasyonun RESMİ YOK: satılan şey bir görünüş değil bir dizilim, ve
      // onu tek kareyle çizmek yanlış bir söz olurdu. Boş hücre o sözü
      // vermiyor ama satırın hizasını da bozmuyor.
      leading: tasarim
          ? DroidIkonu(model: droidCizimiAdiyla(id), boy: DroidIkonu.magazaBoyu)
          : const GlyphCell(state: CellState.empty),
      color: Palette.slotDroid,
      title: menuUpper(ad, dil),
      // Görünüş STAT VERMİYOR (15.9) ve stat sütunu bu yüzden hiç açılmıyor:
      // boş bir sütun, doldurulacakmış gibi okunurdu.
      price: sahip ? null : fiyat,
      affordable: widget.hangar.canAfford(fiyat),
      priceOverride: sahip ? Metin.sahip(dil) : null,
      actLabel: sahip ? null : Metin.satinAl(dil),
      actFilled: false,
      onAct: () => widget.onBuyGorunus(kalem, id),
    );
  }

  // ── Mühimmat rafları ────────────────────────────────────────────────

  /// MERMİ rafı — altı çarpan ve sifon; MR-1 listede ama satılmıyor (17.2).
  Widget _mermiListesi(MenuMetrics m, Dil dil) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: Mermi.hepsi.length,
    separatorBuilder: _ara,
    itemBuilder: (_, i) {
      final mermi = Mermi.hepsi[i];
      final fiyat = Price.credit(mermi.fiyatFor(ShopPage.mermiPaketi));
      return _muhimmatSatiri(
        m: m,
        dil: dil,
        onek: 'mermi',
        id: mermi.id,
        // Sifon kalkana vuruyor, ötekiler gövdeye: rengi de oradan.
        glyph: mermi.sifon ? ItemGlyph.shield : ItemGlyph.laser,
        renk: mermi.sifon ? Palette.shield : Palette.slotLaser,
        carpan: mermi.carpan,
        birim: mermi.sifon ? Metin.kalkan(dil) : Metin.hasar(dil),
        aciklama: mermi.sifon
            ? Metin.kalkanaCarpan.bicim(dil, {'n': mermi.carpan})
            : Metin.tabanHasarCarpan.bicim(dil, {'n': mermi.carpan}),
        bedava: mermi.bedava,
        stok: widget.hangar.mermiSayisi(mermi.id),
        fiyat: fiyat,
        paket: ShopPage.mermiPaketi,
        onAl: () => widget.onBuyMermi(mermi.id, ShopPage.mermiPaketi),
      );
    },
  );

  /// ROKET rafı — 17'nin ikizi (18.3).
  Widget _roketListesi(MenuMetrics m, Dil dil) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: Roket.hepsi.length,
    separatorBuilder: _ara,
    itemBuilder: (_, i) {
      final roket = Roket.hepsi[i];
      final fiyat = Price.credit(roket.fiyatFor(ShopPage.roketPaketi));
      return _muhimmatSatiri(
        m: m,
        dil: dil,
        onek: 'roket',
        id: roket.id,
        glyph: ItemGlyph.launcher,
        renk: Palette.slotRocket,
        carpan: roket.carpan,
        birim: Metin.hasar(dil),
        aciklama: Metin.salvoTabani.bicim(dil, {'n': roket.carpan}),
        bedava: roket.bedava,
        stok: widget.hangar.roketSayisi(roket.id),
        fiyat: fiyat,
        paket: ShopPage.roketPaketi,
        onAl: () => widget.onBuyRoket(roket.id, ShopPage.roketPaketi),
      );
    },
  );

  /// MÜHİMMAT satırı — mermi ve roket AYNI satır (18.3).
  ///
  /// İkisi ayrı tip ama aynı raf dilini konuşuyor: çarpan, stok, paket
  /// fiyatı. İki ayrı satır yazmak, ikisinin zamanla ayrışması demekti.
  Widget _muhimmatSatiri({
    required MenuMetrics m,
    required Dil dil,
    required String onek,
    required String id,
    required ItemGlyph glyph,
    required Color renk,
    required int carpan,
    required String birim,
    required String aciklama,
    required bool bedava,
    required int stok,
    required Price fiyat,
    required int paket,
    required VoidCallback onAl,
  }) => ItemRow(
    metrics: m,
    glyph: glyph,
    color: renk,
    title: id,
    summary: aciklama,
    mainValue: '×$carpan',
    mainLabel: birim,
    // Bedava mühimmatın ne fiyatı var ne düğmesi: satılmayan bir şeyin
    // kapalı düğmesi "bozuk" okunur, olmayan düğme "satılık değil" okunur.
    price: bedava ? null : fiyat,
    affordable: !bedava && widget.hangar.canAfford(fiyat),
    stateNote: bedava
        ? Metin.bedavaSinirsiz(dil)
        : Metin.stokAdedi.bicim(dil, {'n': stok}),
    stateColor: bedava ? Palette.good : Palette.muted,
    actKey: shopBuyKey('$onek-$id'),
    actLabel: bedava ? null : Metin.paketAl.bicim(dil, {'paket': paket}),
    onAct: onAl,
  );

  // ── Gemi rafı ───────────────────────────────────────────────────────

  Widget _gemiListesi(MenuMetrics m, Dil dil) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: HullClass.all.length,
    separatorBuilder: _ara,
    itemBuilder: (_, i) => _gemiSatiri(HullClass.all[i], m, dil),
  );

  Widget _gemiSatiri(HullClass hull, MenuMetrics m, Dil dil) {
    final sahip = widget.hangar.hulls.contains(hull.id);
    final etkin = widget.hangar.activeHullId == hull.id;
    // Satışta olmayan gövdenin fiyatı `null`, yani karşılanabilir de değil.
    // Satır duruyor — oyuncu merdivenin nereye gittiğini görüyor, ama düğme
    // kapalı ve sebebi fiyatın yerinde yazıyor.
    final fiyat = Catalogue.hullPrice(hull);
    return ItemRow(
      metrics: m,
      // Mağazada gövde satın alınırken tek görünen şey sayılardı. Silüet,
      // "hangi gemi" sorusunu stat tablosundan önce cevaplıyor.
      leading: GemiIkonu(hullId: hull.id, boy: GemiIkonu.magazaBoyu),
      color: Palette.accent,
      title: hull.name,
      summary: Metin.govdeRankYuva.bicim(dil, {
        'rank': hull.tier.label,
        'yuva': '${hull.totalSlots}',
      }),
      // Ana stat GÖVDE CANI: geminin en büyük tek sayısı ve satırın konusu.
      // Kalkan, hız ve onarım açılan bölümde — orada ana statın söylemediği
      // şeyler duruyor.
      mainValue: menuNumber(hull.baseHull, dil),
      mainLabel: Metin.govde(dil),
      price: sahip || !hull.satinAlinabilir ? null : fiyat,
      affordable: sahip
          ? !etkin
          : fiyat != null && widget.hangar.canAfford(fiyat),
      priceOverride: sahip
          ? Metin.sahipsin(dil)
          : hull.satinAlinabilir
          ? null
          : Metin.yakinda(dil),
      priceColor: sahip ? Palette.good : Palette.faint,
      // Sahip olunanda "SATIŞTA" yazılmıyor: alt satırda zaten "SAHİPSİN"
      // yazıyor ve ikisi birlikte çelişir gibi okunuyordu.
      stateNote: !sahip && hull.satinAlinabilir ? Metin.satista(dil) : null,
      actKey: shopBuyKey(hull.id),
      // Sahip olunan ve ETKİN olan gemide düğme bir DURUM, eylem değil.
      actLabel: sahip
          ? (etkin ? Metin.etkin(dil) : Metin.sec(dil))
          : Metin.satinAl(dil),
      actColor: etkin ? Palette.good : Palette.accent,
      actFilled: !etkin,
      onAct: sahip
          ? () => widget.onSelectHull(hull.id)
          : () => widget.onBuyHull(hull.id),
      // ETKİN geminin satırı AÇIK doğuyor.
      //
      // Keyfî değil: oyuncunun kendi gemisinin sayıları, listedeki her
      // satırın karşılaştırıldığı taban. Kapalı olsaydı "bu gemi benimkinden
      // iyi mi" sorusu iki dokunuş ve bir hafıza işi olurdu.
      acik: etkin,
      // Gövde sadece stat değil KAPASİTE de veriyor: her kademe bir yuva
      // daha açıyor, ve kapasite sayıdan çok daha güçlü bir ödül hissi.
      chips: [
        for (final tip in SlotType.values)
          if (hull.slotCount(tip) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: slotColor(tip).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${slotLabel(tip, dil)} ×${hull.slotCount(tip)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuType.label(color: slotColor(tip)),
              ),
            ),
      ],
      panel: [
        RowEntry(Metin.kalkan(dil), menuNumber(hull.baseShield, dil)),
        RowEntry(Metin.hiz(dil), menuNumber(hull.baseSpeed, dil)),
        RowEntry(Metin.onarimBasligi(dil), menuNumber(hull.repairCost, dil)),
      ],
    );
  }
}

// ── Test kancaları ──────────────────────────────────────────────────────

/// Mağazadaki satın alma / seçme düğmesi.
Key shopBuyKey(String id) => Key('shop-buy-$id');

/// Raf şeridindeki düğme. Kimlik [ShopShelf] rafının proje kimliği
/// (`laser`, `mermi`, `hull`, …) — eski kategori kimlikleriyle aynı.
Key shopCategoryKey(String id) => Key('shop-cat-$id');

/// Grup rayındaki düğme — birinci kademe.
///
/// Raf şeridi YALNIZ açık grubun raflarını taşıyor: başka bir gruptaki rafa
/// gitmek isteyen (test ya da görsel referans) önce buraya basmalı. İki
/// kademenin bedeli bu, ve karşılığı sekiz kategorinin hiçbirinin ekran
/// dışında kalmaması.
Key shopGroupKey(ShopGroup grup) => Key('shop-group-${grup.name}');

/// Bir raf KİMLİĞİNİN hangi grupta durduğu.
///
/// Testler ve görsel referanslar rafa kimliğiyle gidiyor ("generator",
/// "droid", "hull") ama raf şeridi yalnız AÇIK grubun raflarını taşıyor.
/// Eşlemeyi dışa açmak, her çağrı yerinde grup listesini elle yazmaktan iyi:
/// bir raf grup değiştirdiğinde tek yer değişiyor, ve değişmezse yakalama
/// sessizce atlanır — tam olarak bir kez öyle oldu.
ShopGroup? shopGroupOfCategory(String kimlik) {
  for (final grup in ShopGroup.values) {
    for (final raf in grup.shelves) {
      if (raf.kimlik == kimlik) return grup;
    }
  }
  return null;
}

/// Raf şeridinin kendisi.
const shopCategoryStripKey = Key('shop-cat-strip');
