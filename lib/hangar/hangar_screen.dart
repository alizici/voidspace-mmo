import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/durum_metni.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../game/art/droid_art.dart';
import '../net/hangar_view.dart';
import '../net/net_client.dart';
import 'arge_karti.dart';
import 'droid_ikonu.dart';
import 'gemi_ikonu.dart';
import 'item_glyph.dart';
import 'item_sheet.dart';
import 'malzeme_ikonu.dart';
import 'menu_cells.dart';
import 'menu_model.dart';
import 'menu_theme.dart';
import 'onay_penceresi.dart';
import 'rank_plakasi.dart';
import 'rank_saati.dart';
import 'ship_portrait.dart';
import 'shop_page.dart';
import 'unvan_karti.dart';
import 'unvan_satiri.dart';

/// Oyun içi menü: HANGAR ve MAĞAZA.
///
/// **Hiçbir karar burada verilmiyor.** Her düğme sunucuya bir NİYET yolluyor
/// ve ekran, geri gelen duruma göre yeniden çiziliyor.
///
/// İyimser güncelleme (önce çiz, sonra doğrula) bilerek YOK: parada ve
/// envanterde iyimser güncelleme, reddedilen bir işlemden sonra oyuncuya sahip
/// olmadığı bir eşyayı ve olmayan bir parayı göstermek demek. Menü gecikmesi
/// bir kare; yanlış bakiye bir güven sorunu.
///
/// Düzen ÖLÇEKLENMİYOR, uyarlanıyor — bkz. [MenuMetrics]. Oyun ağacı bu ekran
/// açıkken sökülmüyor, üstü örtülüyor (bkz. `app.dart`).
class HangarScreen extends StatefulWidget {
  const HangarScreen({required this.client, required this.onClose, super.key});

  final NetClient client;
  final VoidCallback onClose;

  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

/// Menü sekmeleri.
///
/// Etiket enum'da SABİT DURMUYOR: bir `const` alan uygulama açılırken bir kez
/// yazılır ve dil değişince eski dilde kalırdı. Enum kimliği taşıyor, metni
/// [Metin] veriyor.
enum MenuTabId {
  hangar,
  shop;

  String etiket(Dil dil) => switch (this) {
    MenuTabId.hangar => Metin.hangar(dil),
    MenuTabId.shop => Metin.magaza(dil),
  };
}

/// Hangar sekmesinin ETİKETİ — enum'daki sabitten değil, [Metin]'den.
///
/// [HangarTab] etiketini bir `const` alanda taşıyor ve orada durması doğru:
/// o dosya mağazanın raf ağacıyla birlikte tasarımın kelime dağarcığını
/// tutuyor. Ama sabit bir dize uygulama açılırken bir kez yazılır ve dil
/// değişince eski dilde kalır; ekranda görünen metin bu yüzden buradan
/// geçiyor.
///
/// Karşılıklar projenin KENDİ sözlüğü: tasarımın "EKİPMAN"ı burada DONANIM,
/// "MATERYAL"i MALZEME. Aynı ekranda iki ad kullanmak, oyuncuya aynı kabı
/// iki kez öğretmek olurdu.
String _sekmeEtiketi(HangarTab sekme, Dil dil) => switch (sekme) {
  HangarTab.ekipman => Metin.donanim(dil),
  HangarTab.droid => Metin.yuvaDroid(dil),
  HangarTab.materyal => Metin.malzeme(dil),
  HangarTab.gemi => Metin.gemiKisa(dil),
};

class _HangarScreenState extends State<HangarScreen>
    with SingleTickerProviderStateMixin {
  /// Rank plakalarının yörünge saati — TEK, ekranla birlikte doğup ölüyor.
  ///
  /// Süre altı saniye: bir tur. Daha hızlısı noktaları sinek gibi
  /// gösteriyordu, daha yavaşı hareketi hiç fark ettirmiyordu.
  late final AnimationController _rankSaati = AnimationController(
    vsync: this,
    duration: _turSuresi,
  )..repeat();

  /// Bir turun süresi — [_kisikFaz] basamak sayısını buradan çıkarıyor.
  static const Duration _turSuresi = Duration(seconds: 6);

  /// Boyacılara verilen saat: kaynağın kendisi değil, MENÜ HIZINA kısılmışı.
  ///
  /// Denetleyici ekranın tazeleme hızında tikliyor (bu telefonda 120 Hz) ve
  /// abone olan her plaka o hızda yeniden boyanıyordu. Ölçüldü: hangarda GPU
  /// her karede 3,2 ms, oyunun tamamı 1,5 ms. Kısma görüntüyü değiştirmiyor
  /// ([KisikFaz]'in gerekçesi orada), pili değiştiriyor.
  late final KisikFaz _kisikFaz = KisikFaz(
    _rankSaati,
    saniye: _turSuresi.inMilliseconds / 1000,
  );

  @override
  void dispose() {
    _kisikFaz.dispose();
    _rankSaati.dispose();
    super.dispose();
  }

  MenuTabId _tab = MenuTabId.hangar;

  /// Hangarın açık sekmesi — yalnız SOL bölmenin konusunu değiştiriyor.
  ///
  /// Bölme sayısı sekmeye bağlı DEĞİL: hangar her ölçüde iki bölme ve
  /// öğrenilen şey düzenin kendisi. Sekme bir ekran değiştirmiyor, solda
  /// üzerinde çalışılan şeyi değiştiriyor; sağdaki depo yerinde duruyor
  /// (yalnız GEMİ sekmesinde yerini statlara bırakıyor).
  HangarTab _sekme = HangarTab.ekipman;

  /// Ayrıntı şeridinin anlattığı yuva. Seçim EKRANA ait, sunucuya değil:
  /// hangi yuvaya baktığın bir görüş, bir durum değil.
  SlotRef? _selected;

  /// DEPODA SEÇİLİ parça — takma akışının elindeki şey.
  ///
  /// Envanterin klasik hareketi: parçayı al, gideceği yeri işaretle, bırak.
  /// Seçmek oyun durumunu değiştirmiyor, o yüzden sunucuya sorulmuyor;
  /// seçiliyken soldaki UYGUN VE BOŞ yuvalar [CellState.target] çiziliyor ve
  /// kesikli kenar bu arayüzde zaten "seçtiğin parça buraya girer" demek.
  ///
  bool _fleetOpen = false;

  /// PİLOT KARTI açık mı — unvan satırına dokununca (10.4).
  bool _unvanAcik = false;

  /// ARGE AĞACI açık mı — pilot kartındaki düğmeden (05.7).
  ///
  /// Pilot kartından AYRI bir bayrak, onun yerine geçen bir kip değil: ağaç
  /// kartın ÜSTÜNE açılıyor ve kapanınca oyuncu geldiği karta dönüyor. Tek bir
  /// "hangi pencere açık" sayacı olsaydı, ArGe'yi kapatmak oyuncuyu hangarın
  /// köküne atardı — oysa oraya iki dokunuşla gelmişti.
  bool _argeAcik = false;

  /// Bilgi penceresi açıksa hangi parça için.
  ///
  /// Örnek kimliği tutuluyor, örneğin KENDİSİ değil: sunucudan yeni bir hangar
  /// gelince (yükseltme, çevirme) pencere güncel sayıları göstermeli. Nesneyi
  /// saklamak, pencerede eski değerleri dondurmak olurdu.
  String? _bilgiId;

  /// Çevirmeden ÖNCEKİ değer — uyarı bunu karşılaştırıyor.
  ///
  /// Ekrana ait, sunucuya değil: "bir önceki roll neydi" bir oyun durumu
  /// değil, o anki oturumun hafızası. Pencere kapanınca unutuluyor ve
  /// unutulması doğru — yeni bir bakışta yeni bir karar.
  Map<String, double>? _cevirmeOncesi;

  /// Onay bekleyen çevirme: örnek kimliği.
  String? _cevirmeOnayi;

  /// Depoda SEÇİLİ parçalar. TEK bir seçim kümesi.
  ///
  /// **İŞLEM KİPİ KALKTI.** Depo bir süre iki kipli çalışıyordu: normalde
  /// dokunmak seçiyordu, İŞLEM düğmesine basınca aynı dokunuş parçalama
  /// için seçiyordu. Kip, aynı hareketin iki anlamı olduğu için vardı — ama
  /// oyuncunun öğrenmesi gereken fazladan bir kavram ve ekranda kalıcı bir
  /// düğme demekti.
  ///
  /// Kipe gerek yok, çünkü SEÇİM ZATEN BAĞLAMI TAŞIYOR: bir parça seçiliyse
  /// takılabileceği yuvalar işaretleniyor VE parçalanabiliyor. Üç aynı
  /// ranklı parça seçiliyse sentez de açılıyor. Eylem çubuğu seçime göre
  /// beliriyor; seçim yokken hiç yer kaplamıyor.
  final Set<String> _secilenler = {};

  /// Takma akışının kullandığı TEK seçim — yalnız bir parça seçiliyken.
  ///
  /// Birden çok parça seçiliyken hedef yuva çizilmiyor: "bunlardan hangisi
  /// buraya girecek" sorusunun cevabı yok, ve yanlış olanı takmak seçimi
  /// bozmak demek.
  String? get _secilenParca =>
      _secilenler.length == 1 ? _secilenler.first : null;

  set _secilenParca(String? id) {
    _secilenler.clear();
    if (id != null) _secilenler.add(id);
  }

  /// Depoda seçili parçanın tasarımı — seçim yoksa ya da parça artık
  /// envanterde değilse `null`.
  ///
  /// Her okumada hangardan çözülüyor: parçalanan ya da sunucuda reddedilen
  /// bir örneğin kimliği elde kalabiliyor ve o kimlikle hedef çizmek,
  /// olmayan bir parça için yer göstermek olurdu.
  ItemSpec? _secilenSpec(HangarView hangar) {
    final id = _secilenParca;
    return id == null ? null : hangar.specOf(id);
  }

  /// Depodaki bir parçaya dokunmak: SEÇER, aynısına tekrar dokunmak BIRAKIR.
  ///
  /// Seçime EKLİYOR, üzerine yazmıyor: sentez üç parça istiyor ve üçünü
  /// seçmenin başka bir yolu yok. Tek parça seçiliyken takma akışı, üç
  /// parça seçiliyken sentez açılıyor — ikisi aynı kümeden okunuyor.
  void _parcaSec(String id) => setState(() {
    if (!_secilenler.remove(id)) _secilenler.add(id);
    // Seçim ve pencere aynı anda duramaz: pencerenin perdesi bütün ekranı
    // kaplıyor ve seçili parçanın gideceği yuvaya dokunmayı imkânsız
    // kılardı. Seçmek pencereyi kapatıyor.
    _bilgiId = null;
  });

  void _act(String action, [Map<String, Object?> payload = const {}]) {
    // Bir eylem yapıldıysa çift dokunuş penceresi KAPANIYOR.
    //
    // Sayaç duvar saatine bakıyor ve arada başka bir şey olduğunu kendiliğinden
    // bilmiyor: pencereden TAK'a basıp hemen başka bir hücreye dokunan
    // oyuncunun ikinci dokunuşu, ilkinin devamı sayılıp o hücreye eylem
    // uygulardı. Eylem, sayacın sıfırlandığı yer.
    _sonDokunusId = null;
    _sonDokunusAn = null;
    widget.client.hangarAction(action, payload);
  }

  /// Son dokunulan parça ve anı — çift dokunuşu tanımak için.
  String? _sonDokunusId;
  DateTime? _sonDokunusAn;

  /// Bu dokunuş, aynı parçaya yapılan İKİNCİ dokunuş mu.
  ///
  /// **Neden `onDoubleTap` değil.** Bir `GestureDetector`'a hem `onTap` hem
  /// `onDoubleTap` verildiğinde Flutter tek dokunuşu ~300 ms BEKLETİYOR:
  /// ikincisinin gelip gelmeyeceğini bilmesi gerekiyor. Sonuç, her tek
  /// dokunuşta hissedilen bir gecikme — ve envanterdeki en sık hareket tek
  /// dokunuş. Burada sıra tersine çevriliyor: ilk dokunuş ANINDA pencereyi
  /// açıyor, ikincisi gelirse pencere kapanıp eylem yapılıyor. Gecikme yok,
  /// iki hareket de çalışıyor.
  bool _ciftMi(String id) {
    final an = DateTime.now();
    final cift =
        _sonDokunusId == id &&
        _sonDokunusAn != null &&
        an.difference(_sonDokunusAn!) < const Duration(milliseconds: 320);
    // Çift sayıldıysa sayaç sıfırlanıyor: üçüncü dokunuş yeni bir tek
    // dokunuş, yoksa basılı tutulan bir parmak eylemi tekrar tekrar yapardı.
    _sonDokunusId = cift ? null : id;
    _sonDokunusAn = cift ? null : an;
    return cift;
  }

  /// ÇİFT DOKUNUŞUN eylemi — bağlamdan çıkıyor, sorulmuyor.
  ///
  /// Sıra oyuncunun beklediği sıra:
  ///
  ///  1. **Takılıysa ÇIKAR.** Gemide duran bir parçaya çift dokunmanın başka
  ///     bir anlamı yok.
  ///  2. **Droidse FİLOYA AL / FİLODAN ÇIKAR.** Droid gövdeye takılmıyor
  ///     (04.10), filoya giriyor.
  ///  3. **Gemide boş yuva varsa GEMİYE TAK.** Gemi önce geliyor ve bu bir
  ///     tercih: oyuncunun çift dokunduğu parçanın gideceği yer, baktığı
  ///     gemidir.
  ///  4. **Gemi doluysa ve parça droide girebiliyorsa DROİDE TAK.** Lazer ve
  ///     jeneratör iki yere birden girebiliyor (05.4 s5) ve belirsizliğin
  ///     çözümü sormak DEĞİL: on droidli bir filoda "hangisine?" diye bir
  ///     ekran açmak, kısayolu kısayol olmaktan çıkarırdı. Gemi doluyken
  ///     parçanın gidebileceği tek yer zaten droid.
  ///  5. **Hiçbiri olmuyorsa PENCEREYİ AÇ.** Sessizce hiçbir şey yapmamak,
  ///     bu arayüzün en pahalı hatası olurdu — pencere sebebi yazıyor.
  void _hizliEylem(HangarView hangar, String id) {
    final spec = hangar.specOf(id);
    if (spec == null) return;

    final takiliYuva = hangar.slots.entries
        .where((e) => e.value == id)
        .map((e) => e.key)
        .firstOrNull;
    if (takiliYuva != null) {
      _act('unequip', {'slot': takiliYuva});
      setState(() => _bilgiId = null);
      return;
    }

    if (spec.slot == SlotType.droid) {
      if (hangar.filo.contains(id)) {
        _act('filo_cikar', {'instanceId': id});
      } else if (hangar.filo.length < hangar.filoTavani) {
        _act('filo_al', {'instanceId': id});
      } else {
        setState(() => _bilgiId = id);
        return;
      }
      setState(() => _bilgiId = null);
      return;
    }

    // Droidin İÇİNDEKİ bir parçaysa: çıkar.
    if (hangar.droidDeMi(id)) {
      _act('droid_cikar', {'instanceId': id});
      setState(() => _bilgiId = null);
      return;
    }

    final hedef = _targetSlotFor(hangar, spec.slot);
    if (hedef != null) {
      _act('equip', {'slot': hedef.id, 'instanceId': id});
      setState(() {
        _selected = hedef;
        _bilgiId = null;
        _secilenParca = null;
        // Takınca DONANIM sekmesine dön: sonuç orada görünüyor ve oyuncu
        // ayrıca sekme değiştirmemeli. Zaten oradaysa hiçbir şey olmuyor.
        _sekme = HangarTab.ekipman;
      });
      return;
    }

    if (Saglayici.droidDonanimTipleri.contains(spec.slot)) {
      final droid = _bosYuvaliDroid(hangar);
      if (droid != null) {
        _act('droid_tak', {'droidId': droid, 'instanceId': id});
        setState(() => _bilgiId = null);
        return;
      }
    }

    // Gidecek yer yok: pencere sebebini yazsın.
    setState(() => _bilgiId = id);
  }

  @override
  Widget build(BuildContext context) =>
      RankSaati(faz: _kisikFaz, child: _govde());

  Widget _govde() => StreamBuilder<void>(
    stream: widget.client.changes,
    builder: (context, _) {
      final hangar = widget.client.hangar;
      return MenuSurface(
        builder: (context, m) => hangar == null
            ? Center(
                child: Text(
                  Metin.hangarYukleniyor(context.dil),
                  style: MenuType.subtitle(),
                ),
              )
            : Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      m.gutter,
                      m.gutter,
                      m.gutter,
                      // Hata şeridi alttan yer kaplıyor: üstüne binen bir şerit
                      // hem okunmuyor hem altındaki düğmeyi tıklanamaz yapardı.
                      hangar.error == null ? m.gutter : m.gutter + 40,
                    ),
                    child: switch (_tab) {
                      MenuTabId.hangar => _hangar(hangar, m),
                      MenuTabId.shop => ShopPage(
                        hangar: hangar,
                        // Raf oyuncunun bulunduğu banda bağlı (15.2).
                        bandRank: widget.client.harita.bolge.ilkRank,
                        metrics: m,
                        headerBuilder: (sag) =>
                            _header(hangar, m, null, sag: sag),
                        kimlik: _kimlikBlogu(hangar, m),
                        onBuyItem: (id) => _act('buy_item', {'specId': id}),
                        onBuyNova: (id) => _act('nova_al', {'specId': id}),
                        onBuyGorunus: (kalem, id) =>
                            _act('gorunus_al', {'kalem': kalem.name, 'id': id}),
                        onBuyHull: (id) => _act('buy_hull', {'hullId': id}),
                        onSelectHull: (id) =>
                            _act('select_hull', {'hullId': id}),
                        onBuyMermi: (id, adet) =>
                            _act('mermi_al', {'mermiId': id, 'adet': adet}),
                        onBuyRoket: (id, adet) =>
                            _act('roket_al', {'roketId': id, 'adet': adet}),
                      ),
                    },
                  ),
                  if (hangarHataMetni(hangar.error, context.dil)
                      case final message?)
                    _ErrorBar(message: message, metrics: m),
                  _CloseButton(onTap: widget.onClose, metrics: m),
                  if (_unvanAcik)
                    UnvanKarti(
                      hangar: hangar,
                      metrics: m,
                      onArGe: () => setState(() => _argeAcik = true),
                      onClose: () => setState(() {
                        _unvanAcik = false;
                        // Kart kapanırken ağaç da kapanıyor: perdeye dokunmak
                        // "buradan çık" demek ve altında açık kalmış bir
                        // pencere bırakmamalı.
                        _argeAcik = false;
                      }),
                    ),
                  // ARGE PİLOT KARTININ ÜSTÜNDE.
                  //
                  // Yığında sonra geldiği için kartı örtüyor; kart altında
                  // AÇIK kalıyor ve ArGe kapanınca oyuncu iki dokunuşla
                  // geldiği yere tek dokunuşla dönüyor.
                  if (_argeAcik)
                    ArGeKarti(
                      hangar: hangar,
                      metrics: m,
                      onAl: (id) => _act('arge_al', {'dugumId': id}),
                      onSifirla: () => _act('arge_sifirla'),
                      onClose: () => setState(() => _argeAcik = false),
                    ),
                  ?_bilgiPenceresi(hangar, m),
                  ?_cevirmeOnayPenceresi(hangar, m),
                  if (_fleetOpen)
                    _FleetSheet(
                      hangar: hangar,
                      metrics: m,
                      onSelect: (id) {
                        _act('select_hull', {'hullId': id});
                        setState(() => _fleetOpen = false);
                      },
                      onClose: () => setState(() => _fleetOpen = false),
                    ),
                ],
              ),
      );
    },
  );

  // ── HANGAR ────────────────────────────────────────────────────────────

  Widget _hangar(HangarView hangar, MenuMetrics m) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(hangar, m, hangar.activeHull.name),
      SizedBox(height: m.gap),
      // GEMİ ŞERİDİ TELEFONDA YOK.
      //
      // Gemi adı, silüeti ve üç düğme (DONAT · GEMİ · SÖK) 44 piksellik bir
      // satır tutuyordu — 390 piksellik bir ekranda bir yuva sırasının
      // tamamı. Üçü de başka bir yerden ulaşılabiliyor ya da zaten
      // biliniyor: hangi gemide olduğunu GEMİ sekmesi yazıyor, gemi
      // değiştirmek de orada. Kalan iki eylem için bkz. [_donanimCubugu].
      if (!m.dense) ...[_gemiSeridi(hangar, m), SizedBox(height: m.gap)],
      // AYIRICI ÇİZGİ telefonda YOK.
      //
      // Kıl çizginin kendisi bir piksel ama iki yanındaki boşluklarla
      // birlikte 25 piksel ediyor — 390 piksellik bir ekranda bir yuva
      // sırasının yarısı. Ayırdığı şeyi zaten sekme çubuğu ayırıyor: altında
      // başka bir bölüm başladığı oradan da okunuyor.
      if (!m.dense) ...[
        Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        SizedBox(height: m.gap),
      ],
      _sekmeler(hangar, m),
      // Sekme ile bölmeler arası TELEFONDA DAR: kıt olan eksende her piksel
      // bir yuva sırasının parçası ve sekme çubuğu zaten görsel bir ayırıcı.
      SizedBox(height: m.dense ? 6 : m.gap),
      Expanded(child: _bolmeler(hangar, m)),
    ],
  );

  /// Hangarın DÖRT SEKMESİ — yalnız SOL bölmenin konusunu seçiyorlar.
  ///
  /// Bölmelerin ÜSTÜNDE ve tam genişlikte: sol sütuna konsaydı iki bölme
  /// farklı yükseklikten başlardı ve aynı ızgara dilini konuşan iki kap
  /// birbirinden kaymış görünürdü.
  ///
  /// Sekme ayrıca sol bölmenin BAŞLIĞI: seçili çipin adı ve sayacı orada
  /// yazdığı için sol bölme kendi başlık satırını çizmiyor. Aynı adı iki kez
  /// yazmak, listenin başlığını listeye bir kez daha yazmak olurdu — ve
  /// telefonda 30 piksel, bir yuva sırasının üçte ikisi.
  Widget _sekmeler(HangarView hangar, MenuMetrics m) {
    final dil = context.dil;
    return SizedBox(
      // Telefonda 34: satır bir gezinme şeridi ve çipler onun içinde;
      // 40'ın altı burada dokunma hedefini bozmuyor çünkü şeridin kendisi
      // dokunulabilir alanın tamamı.
      height: m.dense ? 34 : 40,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // ÇİPLER ESNEK — ama kendi bölgelerinde.
                //
                // `Flexible` bir satırda çocuğu içeriğine göre değil PAYINA göre
                // ölçüyor: boş alan çipler arasında dağılıyor ve satırın sağında
                // hiç birikmiyordu. Bu yüzden depo sayısı ile menü bir süre
                // ortalarda asılı kalıyordu.
                //
                // Çözüm çipleri sabitlemek değil — o zaman dar pencerede satır
                // taşıyor. Satır artık BÖLME YAPISINI taklit ediyor: sekmeler
                // solun payında, depo sayısı ile menü sağ bölmenin KENDİ
                // genişliğinde. Böylece menü sağ bölmenin sağ kenarına yaslanıyor
                // (yani ekranın kenarına) ve çipler kendi bölgelerinde rahatça
                // esneyebiliyor.
                for (final sekme in HangarTab.values) ...[
                  Flexible(
                    child: ShelfChip(
                      key: paneTabKey(sekme),
                      label: _sekmeEtiketi(sekme, dil),
                      color: sekme.color,
                      selected: sekme == _sekme,
                      trailing: _sekmeSayaci(hangar, sekme),
                      onTap: () => setState(() {
                        _sekme = sekme;
                        // Sekme değişince SEÇİM DÜŞÜYOR: droid sekmesinde elinde
                        // tuttuğun lazer, takılabileceği hiçbir yerin olmadığı bir
                        // ekranda seçili durmamalı.
                        _secilenParca = null;
                      }),
                    ),
                  ),
                  if (sekme != HangarTab.values.last) const SizedBox(width: 5),
                ],
                // DONANIM EYLEMLERİ SEKMELERİN SAĞINDA.
                //
                // Bir süre donanım bölmesinin başındaydılar ve orada kendi
                // satırlarını açıyorlardı — 44 piksel, yuvalardan bir sıra. Sekme
                // satırı zaten 40 piksel yüksekliğinde ve sağ ucu boş: aynı yükü
                // taşıyan ikinci bir satır açmak yerine oradaki boşluk
                // kullanılıyor. Kazanılan yer doğrudan yuvalara ve depoya gidiyor.
                //
                // Sekmelerin SAĞINDA ve daha küçük: bunlar gezinme değil eylem, ve
                // gezinmenin ağırlığını taşımamaları gerekiyor.
                if (m.dense) ...[
                  const SizedBox(width: 4),
                  _donanimEylemi(
                    key: otoDonatKey,
                    label: Metin.donat(dil),
                    color: Palette.good,
                    dolu: true,
                    onTap: () => _otomatikDonat(hangar),
                  ),
                  const SizedBox(width: 5),
                  _donanimEylemi(
                    label: Metin.sokKisa(dil),
                    color: Palette.inkDim,
                    dolu: false,
                    onTap: hangar.slots.isEmpty
                        ? null
                        : () => _stripAll(hangar),
                  ),
                ],
                // DEPO SAYISI ve MENÜSÜ SEKME SATIRINDA.
                //
                // İkisi de deponun kendi bölmesinin başındaydı ve orada bir satır
                // tutuyorlardı — ızgaradan bir sıra hücre. Sekme satırı zaten var
                // ve sağ ucu boş: sayı ile menü oraya taşınınca depo bölmesi
                // doğrudan ızgarayla başlıyor.
                //
                // Sıra anlamlı: solda gezinme (sekmeler), ortada donanım eylemleri,
                // sağda deponun kendi iki parçası — kaç parça var ve onlarla ne
                // yapılabilir.
              ],
            ),
          ),
          // BÖLME AYRIMI: aşağıdaki kıl çizginin tam hizası.
          const SizedBox(width: 14 + 1 + 14),
          SizedBox(
            width: _sagBolme(m),
            child: Row(
              children: [
                const Spacer(),
                Flexible(
                  child: Text(
                    Metin.parcaSayisi.bicim(dil, {'n': _depoSayisi(hangar)}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: MenuType.label(color: Palette.faint),
                  ),
                ),
                _depoMenusu(hangar),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sekme satırındaki küçük eylem düğmesi.
  ///
  /// [MenuButton] DEĞİL: onun 44 piksellik dokunma tabanı var ve bu satır 40
  /// yüksekliğinde. Taban burada gevşiyor çünkü satırın kendisi zaten bir
  /// dokunma şeridi ve iki düğme onun içinde, sekmelerle aynı hizada duruyor.
  Widget _donanimEylemi({
    required String label,
    required Color color,
    required bool dolu,
    required VoidCallback? onTap,
    Key? key,
  }) {
    final acik = onTap != null;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !acik
              ? Colors.white.withValues(alpha: 0.03)
              : (dolu ? color : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: dolu && acik
              ? null
              : Border.all(
                  color: acik
                      ? color.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.08),
                ),
        ),
        child: Text(
          label,
          style: MenuType.label(
            color: !acik ? Palette.inkDim : (dolu ? Palette.space : color),
          ),
        ),
      ),
    );
  }

  /// Sekmedeki sayı ne SAYIYOR: donanımda dolu yuva, droidde filo, malzemede
  /// stoktaki tür. GEMİ'de sayılacak bir şey yok — tek gemi uçuruluyor.
  ///
  /// YALNIZ GENİŞ EKRANDA. Dört sayaç satırdan ~160 piksel alıyor ve satırda
  /// onlardan başka sekmeler, iki eylem, depo sayısı ve menü var. Dar
  /// pencerede sayaçlar ya etiketleri kısaltıyor ("DONANIM" yerine "DO…") ya
  /// satırı taşırıyor — ikisi de sayının söylediğinden fazlasını kaybediyor.
  ///
  /// Ölçüt YÜKSEKLİK DEĞİL GENİŞLİK, çünkü taşan eksen o: 560×620'lik dar
  /// pencere telefondan uzun ama daha dar, ve orada da taşıyordu.
  ///
  /// Kaybolan bilgi yok: oran bölmenin içinde, grup başlıklarında yazılı
  /// ("LAZER 1 / 5").
  String? _sekmeSayaci(HangarView hangar, HangarTab sekme) {
    if (MediaQuery.sizeOf(context).width < 900) return null;
    return _sekmeSayaciTam(hangar, sekme);
  }

  String? _sekmeSayaciTam(
    HangarView hangar,
    HangarTab sekme,
  ) => switch (sekme) {
    HangarTab.ekipman =>
      '${SlotType.values.fold<int>(0, (n, t) => n + _filledCount(hangar, t))}'
          '/${hangar.activeHull.totalSlots}',
    HangarTab.droid => '${hangar.filo.length}/${hangar.filoTavani}',
    HangarTab.materyal => '${_stok(hangar).length}',
    HangarTab.gemi => null,
  };

  /// İKİ BÖLME — TELEFON DAHİL.
  ///
  /// Bir süre dar ekranda tek bölme ve dört sekme vardı (DONANIM · DEPO ·
  /// MALZEME · FİLO) ve yanlıştı: donatmak İKİ kabın arasında geçen bir iş —
  /// depodan al, yuvaya koy — ve o iki kabı aynı anda göremeyen oyuncu her
  /// takma için sekme değiştiriyordu. Telefon yatayda 844 piksel GENİŞ; kıt
  /// olan eksen yükseklik ve iki bölme yüksekliği değil genişliği paylaşıyor.
  ///
  /// Sağ bölme hücre sayısına göre ölçülüyor, ekranın yarısına göre değil —
  /// bkz. [_sagBolme].
  Widget _bolmeler(HangarView hangar, MenuMetrics m) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _sol(hangar, m)),
      const SizedBox(width: 14),
      // KIL ÇİZGİ iki bölmeyi ayırıyor.
      //
      // Boşluk tek başına yetmiyordu: solda yuva ızgarası, sağda depo
      // ızgarası ve ikisi aynı hücreden yapılı — aradaki 32 piksel, tek bir
      // ızgaranın içindeki geniş bir aralık gibi okunuyordu. Bir piksellik
      // çizgi "burada başka bir kap başlıyor" diyor.
      Container(width: 1, color: Colors.white.withValues(alpha: 0.07)),
      const SizedBox(width: 14),
      SizedBox(width: _sagBolme(m), child: _sag(hangar, m)),
    ],
  );

  /// Sağ bölmenin genişliği — YEDİ HÜCRE.
  ///
  /// Tasarımın sayısı 338 ve elle yazılmıyor: yedi hücre artı altı aralık,
  /// [Cells] ile hesaplanıyor. Kalan genişliği ikiye bölmek ızgaranın sağ
  /// ucunda yarım hücrelik bir artık bırakıyordu — kap dolu görünmesi gereken
  /// bir yerde tırtıklı bir kenar.
  ///
  /// Dar pencerede 338 solu ezerdi: orada sol bölmeye en az 300 piksel
  /// bırakılıyor ve sağ bölme kalanı alıyor. Bölme SAYISI değişmiyor, yalnız
  /// payı daralıyor — tek bölmeye inmek donatmayı yine iki ekrana bölerdi.
  double _sagBolme(MenuMetrics m) => math.min(
    _sagBolmeTam,
    math.max(_sagBolmeEnAz, m.width - m.gutter * 2 - 29 - 300),
  );

  /// Yedi hücre + altı aralık = 338.
  static const double _sagBolmeTam = Cells.tile * 7 + Cells.gap * 6;

  /// Dört hücre + üç aralık = 191. Bunun altında depo ızgarası, kap değil
  /// bir sütun gibi okunmaya başlıyor.
  static const double _sagBolmeEnAz = Cells.tile * 4 + Cells.gap * 3;

  /// SOL bölme — sekmenin konusu.
  Widget _sol(HangarView hangar, MenuMetrics m) => switch (_sekme) {
    HangarTab.ekipman => _equipment(hangar, m),
    HangarTab.droid => _filo(hangar),
    HangarTab.materyal => _malzemeler(hangar),
    HangarTab.gemi => _gemiOnizleme(hangar),
  };

  /// SAĞ bölme — DEPO kalıcı, yalnız GEMİ sekmesinde yerini statlara
  /// bırakıyor.
  ///
  /// Depo sağda duruyor çünkü sol bölmedeki her konu ondan besleniyor:
  /// yuvaya takılan da, filoya alınan da, parçalanan da orada. Gemi sekmesi
  /// tek istisna — orada solda bakılan şeyin karşılığı depo değil, o geminin
  /// sayıları.
  Widget _sag(HangarView hangar, MenuMetrics m) => switch (_sekme) {
    HangarTab.gemi => _gemiStatlari(hangar, m),
    _ => _depot(hangar, m),
  };

  /// GEMİ ŞERİDİ İKİNCİL BİLGİ TAŞIYABİLİYOR MU — rozet, sınıf satırı, unvan.
  ///
  /// Şerit tek satır ve içinde üç düğme var; geriye kalan pay geminin ADINA
  /// ait. Ölçüldü: 800 piksellik bir pencerede ad, sınıf satırı ve unvan
  /// kalan 368 pikseli üçe bölüyordu ve üçü de kesiliyordu — ekranın KONUSU
  /// olan ad dâhil. Üç bilginin de bir yedeği var (rozet zaten bilinen bir
  /// şeyi söylüyor, sınıf satırı filo penceresinde, unvan üst çubukta), adın
  /// ise yok.
  ///
  /// Kural TEK YERDE: unvanın iki çağrı yeri de buradan okuyor, yoksa bir
  /// eşikte unvan iki kez, başka bir eşikte hiç çizilmezdi.
  bool _seritGenis(MenuMetrics m) => !m.dense && m.width >= 1000;

  /// Başlık: ekranın adı, sekmeler ve para. Her sekmede AYNI — oyuncunun
  /// parası mağazaya geçince kaybolmamalı.
  /// Üst çubuk. [sag] verilirse kimlik bloğunun (unvan + cüzdan) yerine
  /// geçiyor — mağaza oraya raf şeridini koyuyor ve kimliği kendi başlık
  /// satırına alıyor.
  /// Pilotun unvanı ve iki cüzdan — mağazanın başlık satırına giren blok.
  ///
  /// İki cüzdan HEP BİRLİKTE: NOVA'yı yalnız mağazada göstermek, oyuncunun
  /// onu ekonominin bir parçası değil mağazaya ait bir ayrıntı sanmasına yol
  /// açardı.
  Widget _kimlikBlogu(HangarView hangar, MenuMetrics m) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // UNVAN İLK KISALAN: cüzdanlar sayı ve para birimi taşıyor, ikisi de
      // kısalamaz. Unvan ise zaten kısa bir sürümü olan tek parça.
      Flexible(child: _unvanSatiri(hangar, m)),
      SizedBox(width: m.tightText ? 12 : 20),
      WalletChip(value: menuNumber(hangar.credits, context.dil), metrics: m),
      SizedBox(width: m.tightText ? 12 : 20),
      WalletChip(
        value: menuNumber(hangar.premium, context.dil),
        metrics: m,
        currency: Currency.premium,
      ),
    ],
  );

  /// [esnek] doğruysa çocuğu `Flexible`'a sarıyor, değilse olduğu gibi
  /// bırakıyor. Bir satırda hangi bloğun esneyeceği duruma göre değişiyor ve
  /// bunu koşullu bir sarmalayıcı olmadan yazmak, aynı bloğu iki kez
  /// yazmak olurdu.
  Widget _esnek({required bool esnek, required Widget child}) =>
      esnek ? Flexible(child: child) : child;

  Widget _header(
    HangarView hangar,
    MenuMetrics m,
    String? subtitle, {
    Widget? sag,
  }) => Row(
    children: [
      // SEKME BLOĞU: [sag] varken DOĞAL genişlikte, yokken ESNEK.
      //
      // İkisi de ölçülmüş bir sebeple. Esnekken yanındaki raf şeridiyle boş
      // alanı YARI YARIYA paylaşıyordu ve şerit kalanın yarısını alıp alt
      // satıra sarıyordu — hizalamak için yapılan şey hizayı bozuyordu.
      // Ama [sag] yokken (hangar ekranı) yanında cüzdan var ve o sabit:
      // sekme bloğu da sabit olursa dar pencerede satır taşıyor. Yani
      // esnemesi gereken, satırdaki ÖTEKİ blok neyse onun karşıtı.
      _esnek(
        esnek: sag == null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ekran adı DAR pencerede düşüyor: seçili sekme zaten hangi
            // ekranda olduğunu söylüyor, başlık ikinci kez söylüyor.
            //
            // Esneme payı ayrıca gerekli: test yazı tipiyle (Ahem, her harf
            // 1em) başlık satırı 124 piksel taşıyordu. Ahem bir test
            // ayrıntısı ama tarif ettiği durum gerçek — oyuncunun yazı ölçeği
            // ayarı, daha uzun bir çeviri ya da farklı bir sistem yazı tipi
            // aynı sonucu verir. Sığmayan bir başlık kesilmeli, ekranı
            // kırmızıya boyamamalı.
            if (!m.tightText)
              Flexible(
                child: Text(
                  _tab.etiket(context.dil),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MenuType.title(m),
                ),
              ),
            // Gemi adı YER VARSA: başlık zaten hangi ekranda olduğunu
            // söylüyor, bu ikinci bir bilgi. Dar pencerede `/…` diye kesilmiş
            // bir kırıntıya dönüyordu — hiç göstermemek daha dürüst.
            if (subtitle != null && m.width >= 900) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '/ $subtitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MenuType.subtitle(),
                ),
              ),
            ],
            // BAŞLIK YOKSA BOŞLUK DA YOK.
            //
            // Bu boşluk ekran adını sekmelerden ayırıyordu; ad dar pencerede
            // düşüyor ama boşluk kalıyordu ve sekmeleri 12 piksel sağa
            // itiyordu. Sonuç, üstteki HANGAR düğmesinin altındaki SİLAH
            // rayıyla hizasız durmasıydı — iki sütun aynı soldan başlamalı.
            if (!m.tightText) const SizedBox(width: 20),
            // Sekmeler de ESNEK.
            //
            // Başlık zaten esnekti ama sekmeler sabitti: cüzdan ikiye çıkınca
            // (kredi + NOVA) satır 145 piksel taştı. Sabit genişlikte bir
            // öğe, satıra eklenen her yeni şeyi bir taşma hatasına çeviriyor
            // — ve bir sonraki eklenecek şey her zaman var.
            for (final tab in MenuTabId.values) ...[
              Flexible(
                child: MenuTab(
                  key: menuTabKey(tab),
                  label: tab.etiket(context.dil),
                  selected: tab == _tab,
                  onTap: () => setState(() => _tab = tab),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      // UNVAN telefonda BURADA — gemi satırından taşındı.
      //
      // Üst çubukta sekmelerle cüzdan arasında zaten boş yer var; gemi
      // satırında ise yok, çünkü orada ad, statlar ve iki düğme tek satıra
      // iniyor. Bilgi aynı yerde duruyor gibi görünmüyor ama kaybolmuyor da,
      // ve dokunulunca aynı pencereyi açıyor.
      // `Expanded`, `Flexible` DEĞİL: şerit kalan alanın TAMAMINI almalı.
      // Pay olarak verildiğinde dört raf çipi sığmayıp alt satıra sarıyor ve
      // üst çubuk iki satıra çıkıyordu — sayfa sekmeleriyle hizalamak için
      // yapılan şey, hizayı bozan şey oluyordu.
      if (sag case final widget?) ...[
        SizedBox(width: m.gap),
        Expanded(child: widget),
      ] else if (!_seritGenis(m)) ...[
        Flexible(child: _unvanSatiri(hangar, m)),
        SizedBox(width: m.tightText ? 10 : 16),
      ],
      // Kapat düğmesine yer bırak: üstüne binen bir çip tıklanamaz olurdu.
      //
      // Cüzdan da [sag] verildiğinde çubuktan çıkıyor: mağaza onu kendi
      // başlık satırına alıyor ve iki yerde birden durması, aynı sayıyı iki
      // kez yazmak olurdu.
      if (sag == null)
        Padding(
          padding: const EdgeInsets.only(right: 52),
          // İKİ cüzdan YAN YANA ve hep birlikte.
          //
          // NOVA'yı yalnız mağazada göstermek, oyuncunun onu ekonominin bir
          // parçası değil mağazaya ait bir ayrıntı sanmasına yol açardı.
          // Kazandığı bir şeyin bakiyesini görmesi, kazanmayı sürdürmesinin
          // ön şartı.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WalletChip(
                value: menuNumber(hangar.credits, context.dil),
                metrics: m,
              ),
              SizedBox(width: m.tightText ? 12 : 20),
              WalletChip(
                value: menuNumber(hangar.premium, context.dil),
                metrics: m,
                currency: Currency.premium,
              ),
            ],
          ),
        ),
    ],
  );

  /// Gemi tanıtımı: önizleme, ad, sunucunun hesapladığı ETKİN statlar.
  /// Pilotun unvan satırı — dokunulunca unvan penceresini açıyor.
  ///
  /// Ayrı bir metod çünkü iki yerden çiziliyor: geniş ekranda gemi adının
  /// sağ ucunda, telefonda üst çubukta. Aynı satırın iki kopyası olsaydı
  /// biri güncellenmeden kalırdı.
  Widget _unvanSatiri(HangarView hangar, MenuMetrics m) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    // Satır bir DÜĞME: unvanın tamamı (çağ, kademe, sıradaki eşik) buraya
    // sığmıyor ve ayrı bir sekme açmak, oyuncunun günde bir kez baktığı bir
    // şeye kalıcı yer vermek olurdu.
    onTap: () => setState(() => _unvanAcik = true),
    child: UnvanSatiri(
      key: hangarUnvanKey,
      hangar: hangar,
      // Dar pencerede yalnız unvan; seviye ve puan geçit isteminde ve HUD'da
      // zaten okunuyor.
      kisa: m.width < 700 || m.dense,
      // Başlıkta biraz büyük: satır zaten tek satır ve amblem buradaki tek
      // görsel işaret.
      amblemBoyu: 19,
      style: MenuType.label(
        color: Palette.accent,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
    ),
  );

  /// GEMİ ŞERİDİ: hangi gemi, kim uçuruyor ve onunla yapılabilecek üç iş.
  ///
  /// **STAT KARTLARI burada DEĞİL, GEMİ SEKMESİNDE.** Beş kart bu şeritte
  /// duruyordu ve telefonda ikinci satıra sararak 48 piksel yiyordu — 390
  /// piksellik bir ekranda bir yuva sırasından fazlası. Ama taşınmalarının
  /// asıl sebebi yer kazancı değil: "gemim ne durumda" ayrı bir soru ve artık
  /// ayrı bir sekmesi var. Aynı beş sayıyı hem şeritte hem o sekmede çizmek,
  /// hangisinin gerçek olduğu sorusunu doğururdu.
  ///
  /// **Büyük önizleme de orada.** Şeritte çerçeveli portre yalnız geniş
  /// ekranda çiziliyordu; GEMİ sekmesinin sol bölmesi ona tam yükseklik
  /// veriyor ve her ölçüde aynı yerde duruyor. Şeritte kalan 32 piksellik
  /// silüet kimlik için yeterli — ölçüldü, daha küçüğünde turuncu bir leke
  /// kalıyor.
  ///
  /// Üç düğme SEKMEDEN BAĞIMSIZ: donatmak, gemi değiştirmek ve sökmek hangi
  /// sekmede olunursa olunsun yapılabilmeli.
  Widget _gemiSeridi(HangarView hangar, MenuMetrics m) {
    final dil = context.dil;
    final hull = hangar.activeHull;

    final nameRow = Row(
      children: [
        // Gemi adının HEMEN SOLUNDA gemi. 44 piksellik portre okunuyor.
        // Gemi adının solundaki gemi de AKTİF gövde: iki yerde iki farklı
        // gemi göstermek, ekranın konusunu ikiye bölerdi.
        GemiIkonu(hullId: hangar.activeHullId, boy: GemiIkonu.seritBoyu),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            // [menuUpper] BURADA DEĞİL, ve bu bir unutma değil.
            //
            // O çağrının işi Türkçe noktalı `i`'yi `İ` yapmak ve gemi adları
            // Türkçe değil: "Bastion" ondan geçseydi "BASTİON" olurdu.
            // Kural ETİKETLER için — çevrilen, dile ait metinler. Özel ad
            // çevrilmiyor, o yüzden dilin kuralına da girmiyor.
            hull.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MenuType.hero(m),
          ),
        ),
        // AKTİF rozeti ile GÖVDE SINIFI dar pencerede YOK.
        //
        // Rozet, baktığın geminin zaten aktif olduğunu söylüyor — 70 piksel
        // karşılığında bilinen bir şey. Sınıf satırı ("PARLAYAN PEMBE · 23
        // YUVA") ise kesildiğinde olmayan bir rank uyduruyor. İkisi de
        // satırın KONUSU olan gemi adından önce düşmeli.
        if (_seritGenis(m)) ...[
          const SizedBox(width: 10),
          _Badge(Metin.aktif(dil), Palette.accent),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              Metin.govdeSinifYuva.bicim(dil, {
                'rank': rankEtiketi(hull.tier, dil),
                'yuva': hull.totalSlots,
              }),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MenuType.label(color: Palette.faint),
            ),
          ),
        ],
        // Pilotun unvanı satırın SAĞ ucunda: "hangi gemi" ve "kim uçuruyor"
        // aynı satırda (10.4). Dar pencerede üst çubuğa taşınıyor —
        // bkz. [_seritGenis].
        if (_seritGenis(m)) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _unvanSatiri(hangar, m),
            ),
          ),
        ],
      ],
    );

    // Etiketler telefonda KISALIYOR: aynı satırda üç düğme ve geminin adı
    // var, uzun etiketlerle taşan şey geminin adı oluyordu ("BASTIO…").
    // Kısaltmak düğmeden bir şey eksiltmiyor — dokunulan yer aynı, açılan
    // pencere aynı.
    final fleetButton = MenuButton(
      key: fleetOpenKey,
      label: m.dense ? Metin.gemiKisa(dil) : Metin.gemiDegistir(dil),
      expand: true,
      onTap: () => setState(() => _fleetOpen = true),
    );
    // OTOMATİK DONATIM — tek dokunuşla en iyi dizilim.
    //
    // Donatmak tek tek yapılan bir işti: yuva seç, parça seç, TAK. Yirmi bir
    // yuvalık bir gövdede altmış üç dokunuş, üstelik hangi parçanın nereye
    // gideceğini oyuncunun hesaplaması gerekiyordu. Elle donatma DURUYOR —
    // bilerek yapılan bir takas (kalkan yerine hız) hâlâ mümkün — ama artık
    // zorunlu değil.
    final autoButton = MenuButton(
      key: otoDonatKey,
      label: m.dense ? Metin.donat(dil) : Metin.otomatikDonat(dil),
      expand: true,
      color: Palette.good,
      onTap: () => _otomatikDonat(hangar),
    );
    final stripButton = MenuButton(
      label: m.dense ? Metin.sokKisa(dil) : Metin.tumunuSok(dil),
      filled: false,
      expand: true,
      color: Palette.inkDim,
      onTap: hangar.slots.isEmpty ? null : () => _stripAll(hangar),
    );

    // ÜÇ DÜĞME EŞİT GENİŞLİKTE.
    //
    // Etiketleri farklı uzunlukta (DONAT · GEMİ · SÖK) ve her biri kendi
    // genişliğindeyken üçlü bir merdiven gibi duruyordu. Aynı satırda, aynı
    // ağırlıkta üç eylem; genişliklerinin farkı bir bilgi taşımıyor.
    // DAR PENCEREDE düğmeler de daralıyor.
    //
    // 118 piksellik üç düğme 560 piksellik bir pencerede satırın yüzde
    // yetmişini alıyordu ve geminin adına 128 piksel kalıyordu — ad da,
    // unvan da taşıyordu. Etiketler zaten kısalmış durumda
    // ([MenuMetrics.tightText]); kutu da onlarla birlikte küçülmeli.
    final dugmeEni = m.tightText ? 76.0 : 118.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: nameRow),
        const SizedBox(width: 14),
        SizedBox(
          width: dugmeEni * 3 + 8 * 2,
          child: EsitIzgara(
            enAzGenislik: dugmeEni,
            kutular: [autoButton, fleetButton, stripButton],
          ),
        ),
      ],
    );
  }

  // ── GEMİ SEKMESİ ──────────────────────────────────────────────────────

  /// GEMİ sekmesinin SOL bölmesi — geminin kendisi.
  ///
  /// Portrede çizilen top sayısı TAKILI LAZER sayısından geliyor ve hangarın
  /// en doğrudan geri bildirimi bu: sayı sabit olsaydı hangar, sonucu hiçbir
  /// yerde görünmeyen bir tablo düzenleme ekranı olurdu.
  ///
  /// Gemi SEÇİMİ buradan değil, şeritteki GEMİ DEĞİŞTİR düğmesinden
  /// yapılıyor. Kartları bu bölmeye de sermek aynı listeyi iki yerde
  /// göstermek olurdu — ve pencere, sekme hangisi olursa olsun açılabilmeli.
  /// GEMİ sekmesinin SOL bölmesi — geminin kendisi, ve ona DOKUNULABİLİR.
  ///
  /// Dokunmak gemi seçme penceresini açıyor. Telefonda ayrı bir GEMİ
  /// DEĞİŞTİR düğmesi yok (üst şerit kalktı) ve olmasına gerek de yok:
  /// ekranın ortasında duran şey geminin kendisi, ve "başkasını seç"
  /// demenin en doğrudan yolu ona dokunmak. Geniş ekranda düğme de duruyor,
  /// ikisi aynı pencereyi açıyor.
  Widget _gemiOnizleme(HangarView hangar) => GestureDetector(
    key: gemiOnizlemeKey,
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _fleetOpen = true),
    child: LayoutBuilder(
      builder: (context, box) => Center(
        child: ShipBay(
          hullId: hangar.activeHullId,
          // Yükseklik BÖLMEDEN: gemi kabın tamamını alıyor ama taşmıyor.
          // Üst sınır, çok yüksek pencerelerde portreyi bir afişe
          // çevirmesin diye — okunan şey silüet, ölçüsü değil.
          height: math.min(box.maxHeight, 320),
        ),
      ),
    ),
  );

  /// GEMİ sekmesinin SAĞ bölmesi — geminin KÜNYESİ ve statları.
  ///
  /// Statlar TAKILI parçalardan hesaplanıyor, katalogdan değil: sayının
  /// değişmesi kuşanmanın sonucu ve o sonucu görmek ekranın amacı.
  ///
  /// Depo bu sekmede yerini buraya bırakıyor. Tek istisna ve sebebi açık:
  /// solda gemiye bakan oyuncunun sorusu "elimde ne var" değil, "bu gemi ne
  /// durumda".
  Widget _gemiStatlari(HangarView hangar, MenuMetrics m) {
    final dil = context.dil;
    final t = hangar.totals;
    String stat(String key) =>
        menuNumber((hangar.effective[key] ?? 0).round(), dil);

    // STAT KARTLARI — sayı, DONANIMIN KATKISI ve etiket.
    //
    // Eskiden yalnız etkin değer yazıyordu: "GÖVDE 3.240". Sayı doğruydu ama
    // ekranın sorusuna cevap vermiyordu — oyuncu hangarda "kuşandığım şey ne
    // veriyor" diye bakıyor, "gemim kaç can" diye değil. Katkı
    // ([HangarTotals] delta metinleri) tam olarak o farkı yazıyor.
    //
    // Katkı SIFIRSA hiç yazılmıyor: "+0", katkısı olmayan bir donanımı
    // katkılıymış gibi gösterirdi.
    final stats = [
      (Metin.govde(dil), menuNumber(t.hull, dil), Palette.hull, t.hullDelta),
      (
        Metin.kalkan(dil),
        menuNumber(t.shield, dil),
        Palette.shield,
        t.shieldDelta,
      ),
      (Metin.hiz(dil), menuNumber(t.speed, dil), Palette.boost, t.speedDelta),
      (
        Metin.hasar(dil),
        menuNumber(t.damage, dil),
        Palette.slotLaser,
        t.damageDelta,
      ),
      // MENZİL'in gövde tabanı ile donanım katkısı ayrı ayrı çözülmüyor
      // (`HangarTotals` onu taşımıyor): etkin değer yazılıyor, katkı boş.
      // Uydurma bir delta, olmayan bir hesabı varmış gibi gösterirdi.
      (Metin.menzil(dil), stat('range'), Palette.slotCpu, ''),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Başlığın sağındaki sayı SAVAŞ PUANI: kartlardaki beş stat onu
        // besliyor ve oyuncunun tek cümlelik cevabı o. Yuva oranı burada
        // YOK — onu EKİPMAN sekmesinin çipi zaten yazıyor.
        // Başlık GEMİNİN ADI, "GEMİ" değil.
        //
        // Sekme çipi zaten "GEMİ" yazıyor; bölme başlığında onu tekrar etmek
        // aynı kelimeyi iki kez yazmak olurdu. Telefonda üst şerit kalktığı
        // için geminin adının yazıldığı TEK yer burası — künyenin başlığı da
        // doğal olarak o.
        //
        // [menuUpper] yok: gemi adları çevrilmiyor, "Bastion" ondan geçseydi
        // "BASTİON" olurdu.
        PaneHead(
          hangar.activeHull.name.toUpperCase(),
          style: MenuType.hero(m),
          detail: Metin.savasPuani.bicim(dil, {
            'n': menuNumber(t.battleRating, dil),
          }),
        ),
        SizedBox(height: m.gap),
        Expanded(
          child: _FadingScroll(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value, color, delta) in stats)
                  // İKİ SÜTUN: 338 piksellik bölmede 161'lik kart iki tane
                  // sığıyor (161×2 + 8 = 330). Kartı bölmenin tamamına
                  // yaymak beş satır eder ve beşinci satır kayardı.
                  SizedBox(
                    width: 161,
                    child: _StatCard(
                      label: menuUpper(label, dil),
                      value: value,
                      color: color,
                      delta: delta,
                      metrics: m,
                      cerceveli: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── FİLO ──────────────────────────────────────────────────────────────

  /// Droid FİLOSU — gemiye değil oyuncuya bağlı, en çok on (04.10). Gemi
  /// değişince kalıyor; o yüzden yuvaların değil gövdenin dışında duruyor.
  /// Boş yuvası olan İLK filo droidi; yoksa `null` (05.4 s5).
  ///
  /// Filo sırası oyuncunun kendi sırası: doldurma da o sırayı izliyor.
  String? _bosYuvaliDroid(HangarView hangar) {
    for (final id in hangar.filo) {
      final spec = hangar.specOf(id);
      if (spec == null) continue;
      final dolu = hangar.droidDonanimi[id]?.length ?? 0;
      if (dolu < Catalogue.droidYuvaSayisi(spec)) return id;
    }
    return null;
  }

  /// DROİD FİLOSU — gemiye değil oyuncuya bağlı (04.10).
  ///
  /// Kendi sekmesinde ve YALNIZ orada. Bir süre donanımın altında da
  /// duruyordu ve orası doğru bir yerdi — droid de bir donanım kararı — ama
  /// aynı ızgarayı iki yerde göstermek, hangisinin gerçek olduğu sorusunu
  /// doğuruyordu. Sekme filoya tam yükseklik veriyor; donanım da altına
  /// eklenen bir kuyruk taşımıyor.
  ///
  /// Başlık YOK: adını ve sayacını sekme çipi taşıyor.
  /// Seçili droidi filoya alıp seçimi düşürür.
  void _filoyaAl(String id) {
    _act('filo_al', {'instanceId': id});
    setState(() => _secilenParca = null);
  }

  /// DROİD FİLOSU — her droid bir SATIR.
  ///
  /// Izgara değil satır, çünkü droid tek bir şey değil: kendisi, taşıdığı
  /// ekipman ve giydiği tasarım. Bir hücreye sığdırılmış droid, ekipmanını
  /// ve tasarımını başka bir ekrana itiyordu — oysa üçü aynı kararın
  /// parçası.
  ///
  /// Satırın düzeni: droid · adı ve durumu · EKİPMAN yuvaları · ayırıcı ·
  /// TASARIM yuvası. Ayırıcı bilerek: solundakiler stat veriyor, sağındaki
  /// vermiyor.
  Widget _filo(HangarView hangar) {
    // TAVAN HANGARDAN, ilan edilen sabitten DEĞİL: ArGe'nin izin düğümü
    // tavanı bir artırıyor (05.7) ve sabit onu tanımıyordu — izni alan
    // oyuncunun sunucusu on bir droid kabul ederken ekran "10/10" diyordu.
    final tavan = hangar.filoTavani;
    final acik = hangar.filo.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneHead(
          menuUpper(Metin.droidFilosu(context.dil), context.dil),
          detail: '$acik / $tavan',
        ),
        SizedBox(height: Cells.gap),
        Expanded(
          child: _FadingScroll.kayan(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: tavan,
              separatorBuilder: (_, _) => SizedBox(height: Cells.gap),
              itemBuilder: (_, i) => _filoSatiri(hangar, i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filoSatiri(HangarView hangar, int i) {
    final dil = context.dil;
    final instanceId = i < hangar.filo.length ? hangar.filo[i] : null;
    final spec = instanceId == null ? null : hangar.specOf(instanceId);
    final item = instanceId == null ? null : hangar.instance(instanceId);
    final bos = instanceId == null;

    // YUVA SAYISI DROİDDEN: elit droid iki, standart droid bir (05.4 s5).
    // Sabit iki yazmak, elit olmanın anlamını ekranda silerdi — elitin farkı
    // rank ya da stat değil TAŞIMA farkı.
    final yuvaSayisi = spec == null ? 0 : Catalogue.droidYuvaSayisi(spec);
    final takililar = instanceId == null
        ? const <String>[]
        : (hangar.droidDonanimi[instanceId] ?? const []);

    // Boş filo yeri, seçili parça bir DROİDSE hedef (04.10).
    final hedef =
        bos &&
        _secilenSpec(hangar)?.slot == SlotType.droid &&
        hangar.filo.length < hangar.filoTavani;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x07FFFFFF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          EsyaHucresi(
            key: filoTileKey(i),
            durum: bos
                ? (hedef ? CellState.target : CellState.empty)
                : CellState.filled,
            // Dayanıklılık YALNIZ filoda çiziliyor: aşınan da orası (05.10).
            dayaniklilik: item?.dayaniklilik,
            glyph: spec == null ? null : ItemGlyph.ofSpec(spec),
            droid: droidCizimiOf(spec, item),
            kose: spec == null ? null : _koseRanki(spec.tier, dil),
            arti: item?.level ?? 0,
            renk: Palette.slotDroid,
            tooltip: spec == null ? null : esyaAdi(spec, dil, item: item),
            secili: instanceId != null && _secilenler.contains(instanceId),
            onTap: bos
                ? (hedef ? () => _filoyaAl(_secilenParca!) : null)
                : () {
                    if (_ciftMi(instanceId)) {
                      _hizliEylem(hangar, instanceId);
                    } else {
                      _parcaSec(instanceId);
                    }
                  },
            onLongPress: bos
                ? null
                : () => setState(() => _bilgiId = instanceId),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec == null
                      ? Metin.filoBosYer.bicim(dil, {'no': i + 1})
                      : esyaAdi(spec, dil, item: item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MenuType.body(
                    color: bos ? Palette.faint : Palette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  bos
                      ? Metin.droidSecBos(dil)
                      : '${takililar.length} / $yuvaSayisi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MenuType.label(color: Palette.faint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // EKİPMAN YUVALARI — lazer ve jeneratör giriyor (05.4 s5).
          for (var y = 0; y < math.max(yuvaSayisi, 1); y++) ...[
            if (y > 0) SizedBox(width: Cells.gap),
            _droidYuvasi(hangar, instanceId, takililar, y, acik: !bos),
          ],
          const SizedBox(width: 10),
          // AYIRICI: solundakiler stat veriyor, sağdaki vermiyor.
          Container(width: 1, height: 28, color: const Color(0x14FFFFFF)),
          const SizedBox(width: 10),
          _tasarimYuvasi(hangar, instanceId, spec, item),
        ],
      ),
    );
  }

  /// Droidin bir EKİPMAN yuvası.
  Widget _droidYuvasi(
    HangarView hangar,
    String? droidId,
    List<String> takililar,
    int y, {
    required bool acik,
  }) {
    final dil = context.dil;
    final id = y < takililar.length ? takililar[y] : null;
    final spec = id == null ? null : hangar.specOf(id);
    final item = id == null ? null : hangar.instance(id);
    final secili = _secilenSpec(hangar);
    // Seçili parça bu yuvaya girebiliyorsa HEDEF.
    final hedef =
        acik &&
        id == null &&
        secili != null &&
        Saglayici.droidDonanimTipleri.contains(secili.slot);
    return EsyaHucresi(
      key: droidYuvaKey(droidId ?? 'bos', y),
      durum: !acik
          ? CellState.locked
          : id != null
          ? CellState.filled
          : (hedef ? CellState.target : CellState.empty),
      glyph: spec == null ? null : ItemGlyph.ofSpec(spec),
      kose: spec == null ? null : _koseRanki(spec.tier, dil),
      renk: spec == null ? Palette.slotDroid : slotColor(spec.slot),
      tooltip: spec == null ? null : esyaAdi(spec, dil, item: item),
      onTap: !acik
          ? null
          : id != null
          ? () => _act('droid_cikar', {'instanceId': id})
          : (hedef
                ? () {
                    _act('droid_tak', {
                      'droidId': droidId,
                      'instanceId': _secilenParca,
                    });
                    setState(_secilenler.clear);
                  }
                : null),
    );
  }

  /// Droidin TASARIM yuvası — küçük, çünkü stat vermiyor GÖRÜNÜM veriyor.
  ///
  /// [Cells.skin] 28: ekipman yuvasının altında bir ölçü ve bu bir kaza
  /// değil. Dokunma hedefi olarak da ikincil — buraya basmak gücü değil
  /// görünüşü değiştiriyor.
  Widget _tasarimYuvasi(
    HangarView hangar,
    String? droidId,
    ItemSpec? spec,
    ItemInstance? item,
  ) => EsyaHucresi(
    key: droidTasarimKey(droidId ?? 'bos'),
    durum: droidId == null ? CellState.locked : CellState.filled,
    droid: droidCizimiOf(spec, item),
    renk: Palette.slotDroid,
    boy: Cells.skin,
    tooltip: droidId == null ? null : Metin.magazaTasarim(context.dil),
    onTap: droidId == null ? null : () => setState(() => _bilgiId = droidId),
  );

  Widget _equipment(HangarView hangar, MenuMetrics m) {
    final hull = hangar.activeHull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // Alt kenarda SOLMA. Yuvalar sığmıyor ve sığmamalı: SS gövdede
          // yirmiden fazla yuva var, hiçbir sabit düzen hepsini tutamaz.
          // Kaydırılabilir olması doğru cevap — ama kesik bir kutucuk "bozuk"
          // gibi görünüyordu. Solma, devamı olduğunu söyleyen tek işaret.
          //
          // GRUPLAR ALT ALTA — her ölçüde aynı.
          //
          // Telefonda bir süre yan yana AKIYORLARDI ve sebebi yer kazanmaktı:
          // etiket üstteyken beş grup dikeyde sığmıyordu. Ama akan gruplar
          // hizayı bozuyordu — her grubun yuvaları başka bir soldan
          // başlıyordu. Etiketin altındaki sayaç kalkınca grup başına bir
          // satır kazanıldı ve dikey yığın sığar oldu.
          child: _FadingScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final type in SlotType.values)
                  if (hull.slotCount(type) > 0) ...[
                    _yuvaGrubu(hangar, m, type),
                    SizedBox(height: m.dense ? 4 : m.gap),
                  ],
                // FİLO BURADA DEĞİL, kendi sekmesinde. Bir süre yuvaların
                // altında duruyordu; artık DROİD sekmesi ona tam yükseklik
                // veriyor ve aynı ızgara iki yerde durmuyor. Formasyon da
                // burada YOK: dövüşün ortasında değişen bir seçim, yeri
                // savaş çubuğu (HUD).
              ],
            ),
          ),
        ),
        // ALT AYRINTI ŞERİDİ KALDIRILDI.
        //
        // Ekranın altında duran ve seçili yuvanın TAK · ÇIKAR · BİLGİ
        // düğmelerini taşıyan bir şeritti. Üç sorunu vardı: yer yiyordu
        // (telefonda 84 piksele kadar), seçili bir şey yokken "BİR YUVA SEÇ"
        // diye boş duruyordu, ve her işlem İKİ dokunuş istiyordu — önce
        // yuvayı seç, sonra aşağıdaki düğmeye bas. Aradaki mesafe de fiziksel
        // olarak uzundu: parmak ekranın ortasından altına iniyordu.
        //
        // Yerine geçen şey zaten vardı: parçanın kendi penceresi. Yuvaya bir
        // kez dokunmak onu açıyor, dışarı dokunmak kapatıyor. Aynı üç eylem
        // orada ve parçanın bilgisiyle BİRLİKTE — karar verirken bakılacak
        // sayılar kararın verildiği yerde.
      ],
    );
  }

  /// Bir yuva grubunun TEK SATIRLIK hâli — etiket solda, yuvalar sağda.
  ///
  /// Yalnız dikey yeri kıt ekranda kullanılıyor. Etiketin üstte durması
  /// geniş ekranda doğru (sütun başlığı gibi okunuyor), telefonda ise her
  /// gruba bir satır daha ödetiyordu — beş grup, beş kayıp satır.
  /// Bir yuva grubu: ETİKET ÜSTTE, yuvalar ALTINDA.
  ///
  /// Etiket bir süre satırın SOLUNDAYDI ve sebebi yer kazanmaktı: telefonda
  /// gruplar yan yana akıyordu ve her grubun kendi satırı yoktu. O düzen
  /// gruplar arasındaki hizayı bozuyordu — LAZER'in yuvaları bir yerden,
  /// JENERATÖR'ünkiler başka bir yerden başlıyordu ve ikisi aynı ızgaranın
  /// parçası gibi okunmuyordu. Etiket üste geçince her grubun yuvaları aynı
  /// soldan başlıyor.
  ///
  /// **Sayaç ("1 / 5") YOK.** Dolu ve boş hücreler zaten yan yana duruyor:
  /// kaçının dolu olduğunu saymak için bakılacak yer sayı değil ızgaranın
  /// kendisi. Sayı aynı bilgiyi ikinci kez, daha soluk yazıyordu — ve bir
  /// satır daha yer tutuyordu.
  Widget _yuvaGrubu(HangarView hangar, MenuMetrics m, SlotType type) {
    final hull = hangar.activeHull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          menuUpper(slotLabel(type, context.dil), context.dil),
          style: MenuType.label(
            color: slotColor(type),
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
        const SizedBox(height: 3),
        // YUVALAR SARABİLİR — grup bölmeye sığmıyorsa ikinci sıraya iniyor.
        //
        // Sabit bir sıraydı ve dar bir bölmede taşıyordu: beş lazer 245
        // piksel eder ve iki bölmeli dar bir pencerede sol bölmeye o kadar
        // kalmayabiliyor. Taşan bir sıra "beş yuvam var ama dördünü
        // görüyorum" demek; sarmak yalnız bir satır daha istiyor.
        CellGrid(
          cells: [
            for (var i = 0; i < hull.slotCount(type); i++)
              _slotTile(hangar, SlotRef(type, i)),
          ],
        ),
      ],
    );
  }

  int _filledCount(HangarView hangar, SlotType type) {
    var n = 0;
    for (var i = 0; i < hangar.activeHull.slotCount(type); i++) {
      if (hangar.itemAt(SlotRef(type, i)) != null) n++;
    }
    return n;
  }

  Widget _slotTile(HangarView hangar, SlotRef slot) {
    final instanceId = hangar.itemAt(slot);
    final spec = instanceId == null ? null : hangar.specOf(instanceId);
    final item = instanceId == null ? null : hangar.instance(instanceId);
    // BOŞ YUVA, DEPODA SEÇİLİ PARÇA BURAYA GİRİYORSA hedef.
    //
    // Kesikli kenarın bu arayüzdeki sözü tek: "seçtiğin parça buraya girer".
    // Yuva türü tutmuyorsa hiçbir söz verilmiyor — bir lazer seçiliyken
    // bütün yuvaların kesikli olması, dokunulduğunda hiçbir şey olmayan
    // yirmi bir vaat demekti.
    final uygun = instanceId == null && _secilenSpec(hangar)?.slot == slot.type;
    return EsyaHucresi(
      key: slotTileKey(slot),
      // Dolu bir yuva hedef olamaz — orada zaten bir şey var. Boş yuva,
      // ya elde tutulan parçayı bekliyor ya da bir sonraki parçanın adresi
      // olarak seçilmiş ([_targetSlotFor]).
      durum: instanceId != null
          ? CellState.filled
          : (uygun || _selected == slot ? CellState.target : CellState.empty),
      glyph: spec == null ? null : ItemGlyph.ofSpec(spec),
      droid: droidCizimiOf(spec, item),
      kose: spec == null ? null : _koseRanki(spec.tier, context.dil),
      arti: item?.level ?? 0,
      tooltip: spec == null ? null : esyaAdi(spec, context.dil, item: item),
      renk: slotColor(slot.type),
      secili: _selected == slot,
      // TEK DOKUNUŞ PENCEREYİ AÇAR.
      //
      // İlk tasarımda dokunmak doğrudan takıp çıkarıyordu ve yanlıştı: aynı
      // hareket yuvanın doluluğuna göre iki farklı iş yapıyordu. Sonra
      // dokunmak yalnız SEÇİYORDU ve eylemler ekranın altındaki bir şeride
      // düşüyordu — o da yanlıştı, çünkü her iş iki dokunuş ve parmağın
      // ekranı boydan boya geçmesi demekti.
      //
      // Şimdi: dolu yuvaya dokunmak parçanın penceresini açıyor (tak, çıkar,
      // yükselt, çevir — hepsi orada, parçanın sayılarıyla birlikte), boş
      // yuvaya dokunmak onu HEDEF seçiyor, çünkü boş bir yuvanın anlatacak
      // bir şeyi yok ama depodan seçilecek parçanın gideceği yer o.
      //
      // **Elde bir parça VARSA boş yuvaya dokunmak TAKAR.** Seçim akışının
      // ikinci yarısı bu: al, bırak. Dolu yuvaya dokunmak yine pencereyi
      // açıyor ve orada ÇIKAR duruyor — "dokun, çıksın" kısayolu çift
      // dokunuşta, çünkü tek dokunuşun takılı bir parçada iki farklı iş
      // yapması (kimi zaman anlat, kimi zaman sök) tam olarak vazgeçilen
      // şeydi.
      onTap: () {
        if (instanceId == null) {
          if (uygun) {
            _act('equip', {'slot': slot.id, 'instanceId': _secilenParca});
            setState(() {
              _selected = slot;
              _secilenParca = null;
            });
            return;
          }
          setState(() => _selected = slot);
          return;
        }
        // ÇİFT DOKUNUŞ gemiden ÇIKARIR — pencereye girip düğme aramadan.
        if (_ciftMi(instanceId)) {
          _hizliEylem(hangar, instanceId);
        } else {
          setState(() => _bilgiId = instanceId);
        }
      },
      // Uzun basma da aynı pencereyi açıyor: türün alışkanlığı bu ve tek
      // dokunuşu bilmeyen oyuncu ikinci bir yoldan aynı yere varıyor.
      onLongPress: instanceId == null
          ? null
          : () => setState(() => _bilgiId = instanceId),
    );
  }

  /// Seçili yuvanın ayrıntısı ve İŞLEMLERİ.
  ///
  /// Kutucukların altında sabit duruyor: işlem düğmeleri kutucuğun içine
  /// sığmaz (72 piksel zaten dokunma alt sınırının biraz üstü) ve her kutucuğa
  /// üç düğme koymak ızgarayı okunmaz yapardı.

  /// ÇEVİRME ONAYI — iyi bir rolü silmeden önce sorulan tek soru.
  Widget? _cevirmeOnayPenceresi(HangarView hangar, MenuMetrics m) {
    final id = _cevirmeOnayi;
    if (id == null) return null;
    final item = hangar.instance(id);
    final spec = hangar.specOf(id);
    if (item == null || spec == null) return null;
    final iyilesenler = _iyilesenler(hangar, id, spec, item);
    if (iyilesenler.isEmpty) return null;
    final dil = context.dil;
    final adlar = iyilesenler.map((id) => statAdi(id, dil)).join(', ');
    return OnayPenceresi(
      metrics: m,
      baslik: Metin.buRoluSileceksin(dil),
      // Sayı METİNDE: "emin misin" tek başına bir soru değil, bir engel.
      // Oyuncunun neyi kaybedeceğini görmesi lazım — ve kilitleyebileceğini.
      mesaj: Metin.cevirmeUyarisi.bicim(dil, {'statlar': adlar}),
      onayEtiketi: Metin.yineDeCevir(dil),
      onOnay: () => _cevirmeYap(id, spec, hangar),
      onVazgec: () => setState(() => _cevirmeOnayi = null),
    );
  }

  /// Son çevirmede İYİLEŞEN ve hâlâ AÇIK statlar.
  ///
  /// Karşılaştırma çevirmeden ÖNCEKİ değerlerle: uyarının anlamı "az önce
  /// iyileştin, yine mi çeviriyorsun". Kilitli stat sayılmıyor — çevirme ona
  /// dokunmayacak. Henüz çevirme yapılmadıysa uyarı yok.
  List<String> _iyilesenler(
    HangarView hangar,
    String id,
    ItemSpec spec,
    ItemInstance item,
  ) {
    final onceki = _cevirmeOncesi;
    if (onceki == null) return const [];
    final simdiki = LoadoutResolver.altStatlariFor(
      item,
      spec,
      hangar.activeHull,
    );
    return [
      for (final e in simdiki.entries)
        if (!item.kilitler.contains(e.key) && e.value > (onceki[e.key] ?? 0))
          e.key,
    ];
  }

  void _cevirmeYap(String id, ItemSpec spec, HangarView hangar) {
    final item = hangar.instance(id);
    _act('cevir', {'instanceId': id});
    setState(() {
      _cevirmeOncesi = item == null
          ? null
          : LoadoutResolver.altStatlariFor(item, spec, hangar.activeHull);
      _cevirmeOnayi = null;
    });
  }

  /// Açık EŞYA BİLGİ penceresi — yoksa `null`.
  ///
  /// Eylem BAĞLAMA göre değişiyor ve tek yerde çözülüyor: takılı bir parça
  /// çıkarılır, depodakiler takılır, boş yuva yoksa eylem yoktur. Pencerenin
  /// kendisi bunu bilmiyor ve bilmemeli — onun işi bilgi vermek.
  Widget? _bilgiPenceresi(HangarView hangar, MenuMetrics m) {
    final id = _bilgiId;
    if (id == null) return null;
    final item = hangar.instance(id);
    final spec = hangar.specOf(id);
    if (item == null || spec == null) return null;

    final takiliYuva = hangar.slots.entries
        .where((e) => e.value == id)
        .map((e) => e.key)
        .firstOrNull;
    final hedef = takiliYuva == null ? _targetSlotFor(hangar, spec.slot) : null;
    // Droid gövdeye takılmıyor, FİLOYA alınıyor (04.10): eylem çifti ayrı.
    final droid = spec.slot == SlotType.droid;
    final filoda = droid && hangar.filo.contains(id);
    final filoyaSigar =
        droid && !filoda && hangar.filo.length < hangar.filoTavani;

    void kapat() => setState(() {
      _bilgiId = null;
      // Hafıza pencereyle birlikte gidiyor: yeni bir bakış, yeni bir karar.
      _cevirmeOncesi = null;
      _cevirmeOnayi = null;
    });

    return ItemSheet(
      spec: spec,
      instance: item,
      hull: hangar.activeHull,
      metrics: m,
      malzemeStogu: hangar.malzemeler[Malzeme.forRank(spec.tier).id] ?? 0,
      ceviriciStogu: hangar.malzemeler[Malzeme.cevirmeFor(spec.tier).id] ?? 0,
      // PERDEYE dokunmak pencereyi kapatıyor — AMA ikinci dokunuş oraya
      // düşüyor.
      //
      // Çift dokunuşun ikinci dokunuşu hücreye ulaşamıyor, çünkü ilk dokunuş
      // pencereyi açtı ve pencerenin perdesi bütün ekranı kapladı. Perde onu
      // yutarsa çift dokunuş hiç çalışmaz. Bu yüzden perde de aynı soruyu
      // soruyor: bu, aynı parçaya yapılan ikinci dokunuş mu.
      //
      // Okuduktan sonra kapatmak için dokunan oyuncuyu vurmuyor: o dokunuş
      // 320 ms'lik pencerenin çok dışında kalıyor.
      onClose: () {
        if (_ciftMi(id)) {
          _hizliEylem(hangar, id);
        } else {
          kapat();
        }
      },
      eylemEtiketi: droid
          ? (filoda
                ? Metin.filodanCikar(context.dil)
                : (filoyaSigar ? Metin.filoyaAl(context.dil) : null))
          : takiliYuva != null
          ? Metin.cikar(context.dil)
          : (hedef != null ? Metin.tak(context.dil) : null),
      // GELİŞTİRME eylemleri — kapıyı SUNUCU denetliyor, ekran yalnız
      // ulaşılabilir kılıyor. Malzemesi yetmeyen bir yükseltme sunucudan
      // `notEnoughMaterials` dönüyor ve hata şeridinde görünüyor; düğmeyi
      // burada kapatmak, aynı kararı iki yerde vermek olurdu.
      // YÜKSELT pencereyi KAPATMIYOR.
      //
      // Kapatıyordu ve yanlıştı: yükseltmek tek seferlik bir karar değil,
      // tekrarlanan bir iş — oyuncu +15'e kadar basıyor. Her basışta pencereyi
      // kapatmak, aynı parçayı on beş kez yeniden açtırmak demekti.
      //
      // Açık kalması bedava değil, KAZANÇ: pencere her yeniden çizimde
      // hangardan okuyor, yani seviye, sonraki maliyet ve malzeme sayacı
      // basışın hemen ardından gözün önünde değişiyor. Kapanan bir pencere
      // sonucu da gizliyordu.
      onYukselt: () => _act('upgrade', {'instanceId': id}),
      cevirmeUyarisi: _iyilesenler(hangar, id, spec, item).isNotEmpty,
      kilitler: item.kilitler,
      // KİLİT — iyi çıkan rol korunuyor, kalanı çevriliyor (karar 07.5).
      // Bedava; bedeli çevirme anında kilit sayısı belirliyor.
      onKilit: (statId, kilitli) => _act('kilit', {
        'instanceId': id,
        'statId': statId,
        'kilitli': kilitli,
      }),
      onCevir: () {
        final altStatlar = LoadoutResolver.altStatlariFor(
          item,
          spec,
          hangar.activeHull,
        );
        if (altStatlar.isEmpty) return;
        // İYİLEŞEN bir rolü çevirmek ONAY istiyor.
        //
        // Çevirme geri alınamaz: yeni değer eskisinin üstüne yazılıyor ve
        // eski değer hiçbir yerde durmuyor. Alışkanlıkla basılan bir tuş,
        // kovalanan rolü tam yakalandığı anda siliyordu. Kilitli stat
        // uyarı doğurmuyor: çevirme ona dokunmayacak.
        if (_iyilesenler(hangar, id, spec, item).isNotEmpty) {
          setState(() => _cevirmeOnayi = id);
          return;
        }
        _cevirmeYap(id, spec, hangar);
      },
      // PARÇALAMA yalnız TAKILI OLMAYANA: takılı bir parçayı eritmek,
      // gemiden bir şey sökmek demek ve oyuncu onu bilerek vermeli.
      onParcala: takiliYuva != null || filoda
          ? null
          : () {
              _act('parcala', {'instanceId': id});
              kapat();
            },
      // ONAR pencereyi KAPATMIYOR, YÜKSELT ile aynı sebeple: sayaç hemen
      // yüz oluyor ve oyuncu sonucu gözünün önünde görüyor.
      onOnar: droid && item.asinmis
          ? () => _act('droid_onar', {'instanceId': id})
          : null,
      novaStogu: hangar.premium,
      // DROİD YUVASI (05.4 s5): droidin içindekiler ve boş yuvaları.
      droidYuvaSayisi: Catalogue.droidYuvaSayisi(spec),
      droidDonanimi: [
        for (final tid in hangar.droidDonanimi[id] ?? const <String>[])
          (tid, hangar.specOf(tid)?.name ?? tid),
      ],
      onDroidenCikar: (tid) => _act('droid_cikar', {'instanceId': tid}),
      // Lazer ve jeneratör droide takılabiliyor: boş yuvası olan İLK
      // droide. Hangi droide gideceğini sormak, on droidli bir filoda
      // ikinci bir seçim ekranı demekti; boş yuva sırayla doluyor.
      onDroideTak:
          Saglayici.droidDonanimTipleri.contains(spec.slot) &&
              takiliYuva == null &&
              !hangar.droidDeMi(id)
          ? () {
              final hedef = _bosYuvaliDroid(hangar);
              if (hedef == null) return;
              _act('droid_tak', {'droidId': hedef, 'instanceId': id});
              kapat();
            }
          : null,
      onEylem: droid
          ? (filoda
                ? () {
                    _act('filo_cikar', {'instanceId': id});
                    kapat();
                  }
                : (filoyaSigar
                      ? () {
                          _act('filo_al', {'instanceId': id});
                          kapat();
                        }
                      : null))
          : takiliYuva != null
          ? () {
              _act('unequip', {'slot': takiliYuva});
              kapat();
            }
          : (hedef == null
                ? null
                : () {
                    _act('equip', {'slot': hedef.id, 'instanceId': id});
                    setState(() {
                      _selected = hedef;
                      _bilgiId = null;
                      _secilenParca = null;
                      // Takınca DONANIM sekmesine dön: sonuç orada görünüyor
                      // ve oyuncu ayrıca sekme değiştirmemeli.
                      _sekme = HangarTab.ekipman;
                    });
                  }),
    );
  }

  // ── MALZEME ───────────────────────────────────────────────────────────

  /// MALZEME STOĞU — parçalamanın ve öldürmenin gittiği yer.
  ///
  /// Yalnız STOKTA OLANLAR listeleniyor. Yirmi rankın hepsini göstermek,
  /// on altısı sıfır olan bir tablo demekti; oyuncunun sorduğu soru "hangi
  /// rankta ne kadar var", "kaç rank var" değil.
  ///
  /// Sıra RANKA göre: merdiven zaten sıralı bir şey ve stok ona göre okunuyor.

  /// Stoktaki malzemeler, RANKA göre sıralı.
  ///
  /// Sekme sayacı da buradan okuyor: iki yerde iki farklı süzgeç, "3 TÜR"
  /// yazan bir sekmenin altında iki hücre göstermenin en kolay yolu olurdu.
  List<(Malzeme, int)> _stok(HangarView hangar) => [
    for (final malzeme in Malzeme.hepsi)
      if ((hangar.malzemeler[malzeme.id] ?? 0) > 0)
        (malzeme, hangar.malzemeler[malzeme.id]!),
  ];

  /// Başlık YOK: adını ve tür sayısını sekme çipi taşıyor.
  Widget _malzemeler(HangarView hangar) {
    final stok = _stok(hangar);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stok.isEmpty)
          Text(
            // Boşluk SEBEBİYLE anlatılıyor: "yok" demek, oyuncuya nereden
            // geleceğini söylemiyor.
            Metin.malzemeYok(context.dil),
            style: MenuType.label(color: Palette.faint),
          )
        else
          // MALZEME de aynı hücreden.
          //
          // Çipti: 30 piksellik kutu, yanında rank etiketi ve adet, hepsi bir
          // satır. Kendi başına okunuyordu ama depo ile yan yana durduğunda
          // iki ayrı arayüz gibiydi — biri ızgara, biri liste. Oysa ikisi de
          // "elimde ne var" sorusunun cevabı. Aynı kap, aynı ritim: rank
          // köşede, adet altta.
          Flexible(
            child: SingleChildScrollView(
              child: CellGrid(
                cells: [
                  for (final (malzeme, adet) in stok)
                    _malzemeHucresi(malzeme, adet),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _malzemeHucresi(Malzeme malzeme, int adet) {
    final gorsel = RankGorseli.of(malzeme.rank);
    return EsyaHucresi(
      durum: CellState.filled,
      // Malzemenin YUVASI yok, RANKI var: hücrenin rengini aile taşıyor.
      renk: gorsel.acik,
      kose: _koseRanki(malzeme.rank, context.dil),
      rozet: adet > 999 ? '999+' : '$adet',
      // Fiyal mı kıvılcım mı — YÜKSELTME malzemesi ile ÇEVİRİCİ ayrı kaynak
      // (alan 06'nın değişmezi) ve karıştırıldıklarında yanlış şey harcanıyor.
      malzeme: MalzemeIkonu.of(malzeme.tur),
      rankGorseli: gorsel,
      tooltip: malzemeAdi(malzeme, context.dil),
    );
  }

  // ── DEPO ──────────────────────────────────────────────────────────────

  /// PARÇA DEPOSU — sağ bölmenin kalıcı sakini.
  ///
  /// Solda ne varsa oradan besleniyor: yuvaya takılan da, filoya alınan da,
  /// parçalanan da burada duruyor. Bir süre sekmenin arkasındaydı ve
  /// telefonda donanımla asla aynı anda görünmüyordu — donatmak ise iki kabın
  /// arasında geçen bir iş.
  Widget _depot(HangarView hangar, MenuMetrics m) {
    final equipped = {...hangar.slots.values, ...hangar.filo};
    // Türe göre SIRALI ama gruplanmamış: renk zaten türü söylüyor ve klasik
    // envanter tek bir kaptır. Başlıklarla bölmek, kabı beş küçük kaba
    // çeviriyordu — hangisinde ne kadar yer kaldığı görünmüyordu.
    // TAKILI parçalar depoda GÖRÜNMÜYOR.
    //
    // Bir süre görünüyorlardı, köşelerinde bir "takılı" işaretiyle. İki şeyi
    // birden bozuyordu: aynı parça ekranın iki yerinde birden duruyordu
    // (donanım ızgarasında ve depoda), ve depodaki kopya hiçbir işe
    // yaramıyordu — tıklanamıyor, seçilemiyor, parçalanamıyordu. "Elindekiler"
    // demesi gereken bir kap, elinde OLMAYAN şeyleri de sayıyordu.
    //
    // Çıkarıldığı an geri geliyor: liste her çizimde donatımdan türüyor,
    // ayrıca tutulan bir kayıt yok.
    // TANINMAYAN tasarım listeye GİRMİYOR.
    //
    // Katalogdan çıkmış bir tasarımı taşıyan eski kayıt yetim kalıyor
    // (`ItemInstance.tasarimGocu` bilinenleri çeviriyor, ama gelecekte
    // bilinmeyen biri çıkabilir). Yetim eşya için hücre çizmek `null` bir
    // tasarımı okumak demekti ve ekran o hücrede çöküyordu — envanteri
    // açılamayan bir oyuncu oyunu hiç oynayamaz.
    final items =
        hangar.inventory.values
            .where(
              (i) =>
                  !equipped.contains(i.instanceId) &&
                  Catalogue.byId.containsKey(i.specId),
            )
            .toList()
          ..sort((a, b) {
            final left = Catalogue.byId[a.specId];
            final right = Catalogue.byId[b.specId];
            final byType = (left?.slot.index ?? 99).compareTo(
              right?.slot.index ?? 99,
            );
            return byType != 0 ? byType : a.specId.compareTo(b.specId);
          });

    // YÜKSELTME KÜMESİ burada, kutucuk başına DEĞİL.
    //
    // Karşılaştırma tam donatımı çözüyor (`LoadoutResolver.yukseltmeMi`) ve
    // kutucuk başına çağırmak, her yeniden çizimde kırk çözüm demekti. Bir
    // kez hesaplayıp kümeyi dolaşmak aynı cevabı veriyor.
    final yukseltmeler = _yukseltmeOlanlar(hangar, items, equipped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ÜSTTE BOŞLUK YOK.
        //
        // Burada bir zamanlar depo çubuğu vardı (başlık + eylemler) ve bu
        // boşluk onu sekme satırından ayırıyordu. Çubuk yukarı taşınınca
        // boşluk kaldı ve depo ızgarasını soldaki yuva ızgarasından 12
        // piksel aşağı itiyordu — iki ızgara yan yana duruyor, hizasız
        // durmaları gözle görülüyor.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // Sütun sayısı GENİŞLİKTEN: ızgara kaba sığar, kap ızgaraya
              // değil. Hesap [Cells.columns] ile aynı ve tek yerde duruyor.
              final columns = Cells.columns(box.maxWidth);
              // Kap her zaman DOLU görünür: eşya sayısı ne olursa olsun en az
              // dört sıra hücre çiziliyor. Boş bir depo, üç boş hücre değil
              // BOŞ BİR KAP gibi görünmeli.
              final rows = math.max(
                _depotMinRows,
                (items.length / columns).ceil(),
              );
              final cells = rows * columns;
              // IZGARA TEMBEL — yalnız GÖRÜNEN hücreler kuruluyor.
              //
              // `Wrap` idi ve bütün hücreleri birden kuruyordu: gerçek bir
              // kayıtta ölçüldü, 222 parçalık depoda ekranda 195 hücre
              // widget'ı vardı ve hepsi her karede yaşıyordu. Telefonda aynı
              // anda görünen hücre sayısı otuz civarı; kalan yüz altmışı
              // görünmeyen bir şey için ödenen bedeldi.
              //
              // Sütun sayısı yine elle hesaplanıyor (yukarıda), çünkü hücre
              // KARE ve boyu sabit: ızgara deleget'ine bırakılsa hücreler
              // genişliği paylaşıp dokunma hedefinden büyük ya da küçük
              // olurdu.
              //
              // **[CellGrid] BURADA KULLANILMIYOR** — tek istisna. O bir
              // `Wrap` ve `Wrap` bütün çocuklarını birden kuruyor; ölçülen
              // şikâyet (222 parça, 195 canlı hücre) tam olarak buydu. Yuva
              // grupları, filo ve malzeme sabit ve az sayıda hücre taşıyor,
              // orada `CellGrid` doğru. Depo tek başına sınırsız büyüyen kap.
              return _FadingScroll.kayan(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: Cells.gap,
                    mainAxisSpacing: Cells.gap,
                    mainAxisExtent: Cells.tile,
                  ),
                  itemCount: cells,
                  itemBuilder: (_, i) => i < items.length
                      ? _depotTile(hangar, items[i], equipped, yukseltmeler)
                      : const EsyaHucresi(durum: CellState.empty),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Depo ızgarasının en az sıra sayısı — kap boşken de kap gibi görünsün.
  static const int _depotMinRows = 4;

  /// DEPONUN TEK DENETİM SATIRI — başlık, kip düğmesi ve işlemler.
  ///
  /// **Üç satırdı, bire indi.** Sırasıyla: başlık ("12 PARÇA") ile İŞLEM
  /// düğmesi bir satır, seçim sayacı ("2 SEÇİLİ") ile PARÇALA · SENTEZ ikinci
  /// satır, düğmelerin altındaki notlar üçüncü. Telefonda ölçüldü: 112 piksel,
  /// yani depo ızgarasından iki tam sıra. Üçünün de söylediği şey aynı kabın
  /// aynı anki durumu; ayrı satırlarda durmalarının bir sebebi yoktu.
  ///
  /// Şimdi sol uçta o an geçerli olan sayaç yazıyor — kipe göre "12 PARÇA" ya
  /// da "2 SEÇİLİ" — sağ uçta ise kipten çıkış düğmesi. İŞLEM kipindeyken
  /// aradaki yeri iki eylem alıyor.
  ///
  /// İki işlem, iki ayrı koşul ve ikisi de EKRANDA yazılı:
  ///
  ///  * **Parçala** — seçili her parça rankının malzemesine dönüyor. Kaç
  ///    malzeme geleceği düğmenin altında; parçalamak geri alınamaz ve
  ///    oyuncu ne kazanacağını basmadan önce bilmeli.
  ///  * **Sentez** — tam [Yukseltme.sentezOrani] tane AYNI RANK parça, bir üst
  ///    rank bir parça. Koşul tutmuyorsa düğme kapalı ve sebebi yazılı;
  ///    sessiz ret, kuralı öğrenmeden vazgeçmek demek.
  Widget _depotTile(
    HangarView hangar,
    ItemInstance item,
    Set<String> equipped,
    Set<String> yukseltmeler,
  ) {
    // Liste tanınmayanı zaten eliyor (`_depot`); burada yine de güvenli
    // okuma: hücre bir yerden daha çağrılırsa çökmesin.
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return const EsyaHucresi(durum: CellState.empty);

    // ENGELİN SEBEBİ yazılıyor: sessiz ret, oyuncunun kuralı öğrenemeden
    // vazgeçmesi demek. Droid gövdeye değil filoya gidiyor: onun engeli
    // filonun dolması.
    final not = spec.slot == SlotType.droid
        ? (hangar.filo.length >= hangar.filoTavani
              ? Metin.filoDolu(context.dil)
              : null)
        : (_targetSlotFor(hangar, spec.slot) != null
              ? null
              : Metin.dolu(context.dil));

    // SEÇİLİ Mİ — TEK defter.
    //
    // Bir zamanlar iki ayrı seçim vardı: takma akışının tek parçası ve işlem
    // kipinin çoklu kümesi. İkisi de aynı şeyi söylüyordu ("bir sonraki adım
    // bunun üstünden geçiyor") ve ayrı durmalarının tek sebebi kipin
    // kendisiydi. Kip kalkınca defter de tekleşti.
    return EsyaHucresi(
      key: depotTileKey(item.instanceId),
      durum: CellState.filled,
      glyph: ItemGlyph.ofSpec(spec),
      droid: droidCizimiOf(spec, item),
      kose: _koseRanki(spec.tier, context.dil),
      arti: item.level,
      tooltip: esyaAdi(spec, context.dil, item: item),
      renk: slotColor(spec.slot),
      secili: _secilenler.contains(item.instanceId),
      yukseltme: yukseltmeler.contains(item.instanceId),
      not: not,
      dayaniklilik: item.dayaniklilik,
      // TEK DOKUNUŞ SEÇER — takılacağı yuvalar işaretleniyor.
      //
      // ÇİFT DOKUNUŞ hâlâ TAKAR: gemide boş yuva varsa gemiye, gemi doluysa
      // droide (bkz. [_hizliEylem]). Birinci dokunuş seçiyor, ikincisi 320
      // ms içinde gelirse aynı parçayı bırakacak yeri kendi buluyor — yani
      // kısayol seçim akışıyla çelişmiyor, onu kısaltıyor.
      onTap: () {
        if (_ciftMi(item.instanceId)) {
          _hizliEylem(hangar, item.instanceId);
        } else {
          _parcaSec(item.instanceId);
        }
      },
      // Bilgi UZUN BASMAYLA ulaşılabilir.
      onLongPress: () => setState(() => _bilgiId = item.instanceId),
    );
  }

  /// DEPODA kaç parça var — takılı olanlar ve yetim kayıtlar hariç.
  ///
  /// Aynı süzgeç ızgarayı da kuruyor; sayı ile hücre sayısının ayrışmaması
  /// için tek yerden okunuyor.
  int _depoSayisi(HangarView hangar) {
    final takili = hangar.slots.values.toSet();
    return hangar.inventory.values
        .where(
          (i) =>
              !takili.contains(i.instanceId) &&
              Catalogue.byId.containsKey(i.specId),
        )
        .length;
  }

  /// Deponun ÜÇ NOKTA menüsü — parçala ve sentez.
  ///
  /// **Neden menüde.** İkisi de seçime bağlı, seyrek ve GERİ ALINAMAZ. Ekranda
  /// kalıcı bir çubuk olarak durduklarında iki satır yer tutuyorlardı ve o
  /// yer, oyuncunun asıl baktığı şeyden — ızgaradan — çalınıyordu. Menü
  /// onları bir dokunuş uzağa koyuyor; geri alınamaz bir eylem için bir
  /// dokunuş uzak olmak zaten doğru.
  ///
  /// Menü seçim yokken de duruyor ama içi KAPALI: düğmenin kaybolması
  /// "nereye gitti" sorusu doğurur, kapalı olması ise sebebini yazıyor.
  Widget _depoMenusu(HangarView hangar) {
    final dil = context.dil;
    final secili = [
      for (final id in _secilenler)
        if (hangar.instance(id) case final item?)
          if (Catalogue.byId[item.specId] case final spec?) (id, spec),
    ];

    final kazanc = secili.fold<int>(
      0,
      (a, e) => a + GanimetCekilisi.parcalamaKazanci(e.$2.tier),
    );
    final ranklar = secili.map((e) => e.$2.tier).toSet();
    final tepede =
        ranklar.length == 1 &&
        ranklar.first.index + 1 >= ItemTier.values.length;
    final sentezOlur =
        secili.length == Yukseltme.sentezOrani &&
        ranklar.length == 1 &&
        !tepede;

    final sentezNotu = secili.isEmpty
        ? Metin.ayniRanktanSec.bicim(dil, {'n': Yukseltme.sentezOrani})
        : tepede
        ? Metin.merdiveninTepesi(dil)
        : ranklar.length > 1
        ? Metin.ranklarKarisik(dil)
        : '${secili.length}/${Yukseltme.sentezOrani} '
              '${rankEtiketi(ranklar.first, dil)}';

    Widget kalem(String baslik, String not, Color renk, {required bool acik}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              baslik,
              style: MenuType.button(color: acik ? renk : Palette.inkDim),
            ),
            Text(not, style: MenuType.label(color: Palette.faint)),
          ],
        );

    return PopupMenuButton<void>(
      key: depoMenuKey,
      tooltip: '',
      color: Palette.menuPanel,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          key: parcalaKey,
          enabled: secili.isNotEmpty,
          onTap: () {
            for (final (id, _) in secili) {
              _act('parcala', {'instanceId': id});
            }
            setState(_secilenler.clear);
          },
          child: kalem(
            Metin.parcala(dil),
            secili.isEmpty
                ? Metin.parcaSec(dil)
                : '+$kazanc ${Metin.malzeme(dil)}',
            Palette.danger,
            acik: secili.isNotEmpty,
          ),
        ),
        PopupMenuItem<void>(
          key: sentezKey,
          enabled: sentezOlur,
          onTap: sentezOlur
              ? () {
                  _act('sentez', {
                    'instanceIds': [for (final (id, _) in secili) id],
                  });
                  setState(_secilenler.clear);
                }
              : null,
          child: kalem(
            Metin.sentez(dil),
            sentezNotu,
            Palette.accent,
            acik: sentezOlur,
          ),
        ),
      ],
      // ÜÇ NOKTA ELLE ÇİZİLİYOR, `Icons.more_vert` DEĞİL.
      //
      // Proje Material ikon fontunu paketlemiyor (bkz. `pubspec.yaml`) ve
      // paketlenmeyen bir ikon boş kutu olarak çiziliyor — tam olarak öyle
      // oldu, görsel referansta menü bir kare olarak çıktı. Üç nokta üç
      // daire; font gerektirmiyor.
      child: SizedBox(
        width: 26,
        height: 34,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 3),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _secilenler.isEmpty ? Palette.inkDim : Palette.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Takıldığında savaş puanını ARTIRAN depo parçaları.
  ///
  /// Karşılaştırma hedef yuvaya göre: boş bir yuva varsa oraya, yoksa aynı
  /// tipteki yuvalardan hangisine takılırsa BR artıyorsa ona. İkincisi şart —
  /// bütün yuvalar doluyken "yükseltme yok" demek yanlış olurdu, oysa
  /// oyuncunun elindeki parça takılı olanlardan birinden iyi olabilir.
  /// Yükseltme oklarının ÖNBELLEĞİ ve onu geçersiz kılan anahtar.
  Set<String>? _okOnbellegi;
  int? _okAnahtari;

  Set<String> _yukseltmeOlanlar(
    HangarView hangar,
    List<ItemInstance> items,
    Set<String> equipped,
  ) {
    // ÖNBELLEK — bu hesap kare başına yapılamayacak kadar pahalı.
    //
    // Ölçüldü: 222 parçalık gerçek bir depoda 490 karşılaştırma ve **76 ms**.
    // Her karşılaştırma tam bir `resolve` + `battleRating`, yani geminin
    // bütün statlarının yeniden çözülmesi. Bu hesap depo her kurulduğunda
    // baştan yapılıyordu ve depo, sunucudan gelen her hangar güncellemesinde
    // kuruluyor — 60 Hz'lik bir bütçede 76 ms'lik tek bir iş, dört karenin
    // kaybı demek. Şikâyetin adı "depo kasıyor" idi.
    //
    // Anahtar cevabı değiştirebilecek HER ŞEYİ kapsıyor: hangi gövde, hangi
    // yuvada ne takılı, envanterde neler var ve hangi seviyedeler. Biri
    // değişmedikçe cevap da değişmiyor.
    final anahtar = Object.hash(
      hangar.activeHullId,
      Object.hashAll([
        for (final e in hangar.slots.entries) Object.hash(e.key, e.value),
      ]),
      Object.hashAll([
        for (final i in items) Object.hash(i.instanceId, i.level),
      ]),
    );
    if (anahtar == _okAnahtari && _okOnbellegi != null) return _okOnbellegi!;

    final sonuc = <String>{};
    final loadout = Loadout(
      hullId: hangar.activeHullId,
      slots: {...hangar.slots},
    );
    for (final item in items) {
      if (equipped.contains(item.instanceId)) continue;
      final spec = Catalogue.byId[item.specId];
      if (spec == null) continue;
      for (var i = 0; i < hangar.activeHull.slotCount(spec.slot); i++) {
        final yuva = SlotRef(spec.slot, i);
        // YALNIZ DOLU yuvalarla karşılaştırılıyor.
        //
        // Boş yuvaya takmak da BR artırıyor ve teknik olarak "yükseltme" —
        // ama işaretin anlamı o değil. Başlangıç gövdesinde beş lazer
        // yuvasının dördü boş; boşları da saymak, depodaki HER parçaya ok
        // koyardı ve ok hiçbir şey söylemez olurdu. Boş yuva zaten
        // kutucuğun kendisinden görünüyor.
        //
        // İşaretin tek işi şu: elindeki bir parça, TAKILI olan bir parçadan
        // iyi mi.
        if (hangar.itemAt(yuva) == null) continue;
        if (LoadoutResolver.yukseltmeMi(
          loadout,
          hangar.inventory,
          Catalogue.byId,
          yuva,
          item,
        )) {
          sonuc.add(item.instanceId);
          break;
        }
      }
    }
    _okAnahtari = anahtar;
    _okOnbellegi = sonuc;
    return sonuc;
  }

  /// Bu parçanın gireceği yuva: SEÇİLİ yuva uygunsa o, değilse ilk boş yuva.
  ///
  /// Seçiliyi öncelemek kasıtlı: oyuncu bir yuvaya bakarken depodan bir parça
  /// seçtiyse niyeti onu O yuvaya takmaktır.
  SlotRef? _targetSlotFor(HangarView hangar, SlotType type) {
    final selected = _selected;
    if (selected != null &&
        selected.type == type &&
        hangar.itemAt(selected) == null) {
      return selected;
    }
    for (var i = 0; i < hangar.activeHull.slotCount(type); i++) {
      final slot = SlotRef(type, i);
      if (hangar.itemAt(slot) == null) return slot;
    }
    return null;
  }

  /// EN İYİ dizilimi hesaplayıp uygular.
  ///
  /// Hesap istemcide, KARAR sunucuda: buradan çıkan her değişiklik normal
  /// `equip` emri olarak gidiyor ve sunucu her birini kendi kurallarıyla
  /// yeniden denetliyor. İstemcinin hesabı bir öneri, bir yetki değil.
  void _otomatikDonat(HangarView hangar) {
    final plan = LoadoutResolver.enIyiDonanim(
      Loadout(hullId: hangar.activeHullId, slots: {...hangar.slots}),
      hangar.inventory,
      Catalogue.byId,
    );
    for (final MapEntry(key: yuva, value: id) in plan.entries) {
      _act('equip', {'slot': yuva.id, 'instanceId': id});
    }
  }

  /// Takılı her parçayı çıkar.
  ///
  /// Yuva başına bir niyet gidiyor; toplu bir "hepsini sök" komutu YOK ve
  /// olmamalı — protokolde her komut tek bir kuralı sınıyor, toplu komut o
  /// kuralları sunucuda ikinci kez yazmak olurdu.
  void _stripAll(HangarView hangar) {
    for (final slotId in hangar.slots.keys.toList()) {
      _act('unequip', {'slot': slotId});
    }
  }
}

/// Hücre köşesine giren RANK etiketi.
///
/// Merdivenin on sekiz basamağı zaten bir KOD ("C-I" … "SSS-III") ve olduğu
/// gibi giriyor. İki kapak taşının etiketi ise kod değil bir AD ("KIRMIZI",
/// "PARLAYAN PEMBE") — plakalı hücrede yazılmıyorlardı ve yazılmamaları
/// doğruydu, çünkü orada rankı zeminin rengi söylüyordu
/// ([RankGorseli.kisaEtiket]). Bu hücrenin zemini yuva rengini taşıyor: harf
/// düşerse rank hiçbir yerde okunmaz.
///
/// İki kelimelik ad BAŞ HARFLERİNE iniyor, kesilmiyor: "PARLAY…" iki
/// kelimelik bir adı tek kelimeye indirip ortada olmayan bir rank uydurur.
/// Tam hâli parçanın penceresinde yazılı.
String _koseRanki(ItemTier rank, Dil dil) {
  final ad = rankEtiketi(rank, dil);
  if (!ad.contains(' ')) return ad;
  return ad.split(' ').map((kelime) => kelime[0]).join();
}

/// Envanter hücresi — [GlyphCell]'in HANGARA ait katmanlarla giydirilmiş hâli.
///
/// **Neden [GlyphCell] tek başına yetmiyor.** Kap dört şey biliyor: zemin,
/// işaret, köşe harfi ve rozet. Bu dördü menünün TAMAMINDA aynı ve orada
/// durmaları doğru — mağaza kartı da aynı kabı çiziyor. Hangarın anlatması
/// gereken üç şey daha var ve üçü de yalnız burada bir soruya cevap veriyor:
///
///  * **yükseltme oku** — "elimdeki bu parça, takılı olandan iyi mi"
///  * **ret notu** — "bastım, hiçbir şey olmadı; neden"
///  * **dayanıklılık şeridi** — "hangi droidim bitmek üzere" (05.10)
///
/// Bunları kaba eklemek, mağaza kartına hiç kullanmayacağı üç alan taşımak
/// olurdu. Üstüne katman eklemek ise kabın ölçüsünü ve dilini tek yerde
/// ([Cells]) bırakıyor.
///
/// **Rank nerede.** Hücrenin zemini artık yuva RENGİNİ taşıyor (oyuncu
/// LAZER'i turuncudan tanıyor), rankı ise sol üst köşedeki harf söylüyor.
/// Rank plakası (`RankKutusu`) burada değil ve olmaması bir kayıp değil bir
/// takas: plaka rankı uzaktan okutuyordu ama her hücreye kendi zeminini
/// veriyordu, yani ızgarada yan yana duran beş lazer beş farklı renkti ve
/// "hangi yuva" sorusu renkten okunamıyordu. Harf yakından kesin, renk
/// uzaktan tutarlı.
class EsyaHucresi extends StatelessWidget {
  const EsyaHucresi({
    required this.durum,
    this.renk = Palette.accent,
    this.glyph,
    this.droid,
    this.malzeme,
    this.rankGorseli,
    this.kose,
    this.arti = 0,
    this.rozet,
    this.tooltip,
    this.onTap,
    this.onLongPress,
    this.yukseltme = false,
    this.secili = false,
    this.not,
    this.dayaniklilik,
    this.boy = Cells.tile,
    super.key,
  });

  final CellState durum;

  /// Yuva türünün rengi — malzemede rank ailesinin rengi.
  final Color renk;

  /// Eşyanın işareti. [droid] ya da [malzeme] verildiyse onlar EZİYOR.
  final ItemGlyph? glyph;

  /// Eşya bir DROİDSE tasarımı.
  ///
  /// Glif ana stattan türüyor ve droidin ana statı `hasar_artisi` olduğu için
  /// her droid roketatar işareti alıyordu; on tasarımın onu da aynı yanlış
  /// işaretle duruyordu. Droid, statıyla değil GÖRÜNÜŞÜYLE tanınan tek eşya.
  final DroidCizimi? droid;

  /// Malzemenin silüeti — fiyal (yükseltme) ya da kıvılcım (çevirici).
  final MalzemeIkonu? malzeme;

  /// Silüetin rank rengini okuduğu görsel. Yalnız [malzeme] ile birlikte.
  final RankGorseli? rankGorseli;

  /// Sol üst: kademe harfi. Aynı işareti taşıyan iki eşyayı ayıran şey.
  final String? kose;

  /// Yükseltme seviyesi; 0 ise rozet çizilmiyor.
  final int arti;

  /// Sağ alt rozetin ELLE verilen hâli — malzeme adedi gibi. Verilmezse
  /// [arti]'dan türüyor.
  final String? rozet;

  /// İşaret NE olduğunu söylüyor, ad HANGİSİ olduğunu. İkincisi hücreye
  /// sığmıyor ama kaybolmamalı.
  final String? tooltip;

  final VoidCallback? onTap;

  /// UZUN BASMA — türün standart "bu ne?" hareketi.
  final VoidCallback? onLongPress;

  /// YÜKSELTME İŞARETİ — bu parça takılıysa savaş puanı artıyor.
  ///
  /// Rozet değil OK, çünkü söylediği şey bir nitelik değil bir YÖN.
  final bool yukseltme;

  /// Ayrıntı penceresinin anlattığı hücre.
  final bool secili;

  /// Hücre tıklanamıyorsa SEBEBİ — hücrenin İÇİNE, alt şerit olarak.
  ///
  /// Hücrenin ALTINDA duruyordu ve ızgaranın ritmini bozuyordu: notu olan
  /// sıra ötekilerden yüksek çıkıyordu. İçeride yazınca ızgara hizalı kalıyor.
  final String? not;

  /// DROİD DAYANIKLILIĞI — alt kenarda ince bir şerit (05.10).
  ///
  /// `null` ya da TAM sayaç ise çizilmiyor: her hücrede duran dolu bir çubuk
  /// hiçbir şey söylemez, yalnız ızgarayı gürültüye boğar.
  final int? dayaniklilik;

  /// Hücrenin kenar uzunluğu.
  ///
  /// Tek istisna droidin TASARIM yuvası ([Cells.skin], 28): oraya takılan
  /// şey stat vermiyor görünüm veriyor, ve dokunma hedefi olarak da ikincil.
  /// Ölçünün küçüklüğü o farkı söylüyor.
  final double boy;

  @override
  Widget build(BuildContext context) {
    final boy = this.boy;
    final kutu = Stack(
      children: [
        GlyphCell(
          state: durum,
          // Droid ve malzeme kendi katmanlarında: kap yalnız eşya glifini
          // biliyor ve bilmesi gereken de o kadar.
          glyph: droid == null && malzeme == null ? glyph : null,
          color: renk,
          badge: rozet ?? (arti > 0 ? '+$arti' : null),
        ),
        // Konumlar hücrenin KENDİ ölçüsüne göre veriliyor, yığının ölçüsüne
        // göre değil: depo ızgarası hücreyi genişletebiliyor ve `fill`
        // katmanları o zaman kutunun dışına taşardı.
        if (droid case final model?)
          Positioned(
            left: 0,
            top: 0,
            width: boy,
            height: boy,
            // `DroidIkonu` kutunun kısa kenarını 1,8'e bölüp yarıçap
            // yapıyor; eşya glifiyle (kenarın yarısı) aynı büyüklüğe
            // gelmesi için kutu 0,47 ölçekleniyor. İkisi aynı ızgarada yan
            // yana duruyor ve farklı büyüklükte çizilmeleri, kapların tek
            // kaynaktan gelmesinin amacını bozardı.
            child: Center(
              child: DroidIkonu(model: model, boy: boy * 0.47),
            ),
          ),
        if (malzeme case final ikon?)
          Positioned(
            left: 0,
            top: 0,
            width: boy,
            height: boy,
            child: CustomPaint(
              painter: _MalzemeSiluetBoyaci(
                ikon,
                rankGorseli ?? RankGorseli.of(ItemTier.cI),
              ),
            ),
          ),
        // KADEME HARFİ kabın kendi `corner` alanında DEĞİL.
        //
        // Orası ölçüsüz bir metin: 11 punto tek aralıklı yazıda "SSS-III"
        // yedi karakter, yani ~50 piksel — 44'lük hücrede kalan 40 piksele
        // sığmıyor ve iki satıra sarıp hücrenin yarısını kaplıyor. Sorun
        // kabın kendisinde ve orada çözülmeli (`GlyphCell.corner` bir
        // `FittedBox` istiyor); o gün gelene kadar katman burada ve aynı
        // yerde, aynı renkte duruyor.
        //
        // `scaleDown` yalnız SIĞMAYANI küçültüyor: "C-I" tam puntoda kalıyor,
        // "SSS-III" bir tık iniyor. Hepsini birden küçültmek, en sık görülen
        // rankı en uzun rank yüzünden okunmaz yapmak olurdu.
        if (kose case final harf?)
          Positioned(
            left: 4,
            top: 1,
            width: boy - 8,
            height: 13,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                harf,
                style: MenuType.label(color: renk.withValues(alpha: 0.85)),
              ),
            ),
          ),
        if (yukseltme)
          Positioned(
            left: 0,
            top: 0,
            width: boy,
            height: boy,
            child: const CustomPaint(painter: _YukseltmeOkuBoyaci()),
          ),
        if (secili)
          Positioned(
            left: 0,
            top: 0,
            width: boy,
            height: boy,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Palette.accentBright, width: 2),
                ),
              ),
            ),
          ),
        if (dayaniklilik case final puan?)
          if (puan < ItemInstance.tamDayaniklilik)
            Positioned(
              left: 3,
              bottom: 3,
              width: boy - 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: puan / ItemInstance.tamDayaniklilik,
                  minHeight: 3,
                  backgroundColor: Palette.space.withValues(alpha: 0.75),
                  // Son üç ölüm kırmızı: sayacın bittiği yer, kaybın geri
                  // alınamaz olduğu yer.
                  valueColor: AlwaysStoppedAnimation(
                    puan <= TasarimGirdileri.droidAsinmaPayi * 3
                        ? Palette.danger
                        : Palette.slotDroid,
                  ),
                ),
              ),
            ),
        if (not case final sebep?)
          Positioned(
            left: 0,
            bottom: 0,
            width: boy,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 1),
              color: Colors.black.withValues(alpha: 0.55),
              child: Text(
                sebep,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuType.label(color: Palette.faint),
              ),
            ),
          ),
      ],
    );

    final dokunulabilir = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: kutu,
    );

    return tooltip == null
        ? dokunulabilir
        : Tooltip(
            message: tooltip!,
            waitDuration: const Duration(milliseconds: 400),
            // Uzun basma BİLGİ penceresine ait olduğunda tooltip ona yol
            // veriyor: `Tooltip`'in varsayılan tetikleyicisi uzun basma ve
            // onu KENDİ içinde yutuyor — dıştaki dokunuş dinleyicisi hiç
            // haber almıyordu, yani pencere hiç açılmıyordu.
            triggerMode: onLongPress == null
                ? TooltipTriggerMode.longPress
                : TooltipTriggerMode.manual,
            child: dokunulabilir,
          );
  }
}

/// Malzeme silüetini hücrenin ortasına çizer.
///
/// [MalzemePlakasi.siluet] ORİJİNE göre çiziyor (plakanın kendi boyacısıyla
/// aynı sözleşme); burada yapılan tek şey merkeze taşımak.
/// Alt kenarı soluklaşan kaydırma alanı — devamı olduğunu söyler.
///
/// Kesik bir kutucuk "bozuk" gibi görünüyordu; solma, altta daha fazlası
/// olduğunu söyleyen tek işaret.
class _FadingScroll extends StatelessWidget {
  const _FadingScroll({required this.child}) : kendiKayar = false;

  /// Çocuğu ZATEN kaydırılabilir olan sürüm — solmayı ekliyor, ikinci bir
  /// kaydırma katmanı EKLEMİYOR.
  ///
  /// Tembel bir `GridView` kendi görüş alanını taşıyor; onu bir
  /// `SingleChildScrollView` içine koymak sonsuz yükseklik verir ve tembellik
  /// ölür — ızgara bütün hücreleri birden kurardı.
  const _FadingScroll.kayan({required this.child}) : kendiKayar = true;

  final Widget child;
  final bool kendiKayar;

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Colors.transparent, Colors.black],
      stops: [0, 0.08],
    ).createShader(rect),
    blendMode: BlendMode.dstIn,
    child: kendiKayar ? child : SingleChildScrollView(child: child),
  );
}

class _MalzemeSiluetBoyaci extends CustomPainter {
  const _MalzemeSiluetBoyaci(this.ikon, this.gorsel);

  final MalzemeIkonu ikon;
  final RankGorseli gorsel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    MalzemePlakasi.siluet(canvas, size.shortestSide, ikon, gorsel);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MalzemeSiluetBoyaci old) =>
      old.ikon != ikon || old.gorsel.tier != gorsel.tier;
}

/// Yükseltme oku — rank plakasındakiyle AYNI çizim.
///
/// Kendi ok'unu çizmek iki kaynak demekti: mağazadaki ok ile depodaki ok
/// zamanla ayrışırdı ve ikisi de "yukarı gidersin" diyor.
class _YukseltmeOkuBoyaci extends CustomPainter {
  const _YukseltmeOkuBoyaci();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    RankPlakasi.yukseltmeIsareti(canvas, size.shortestSide);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_YukseltmeOkuBoyaci old) => false;
}

/// Bir stat kutusu: sayı, DONANIMIN KATKISI ve etiket.
///
/// Katkı sayının hemen yanında, altında değil: "3.240" ile "+840" tek bir
/// cümle ("gövden 3.240 ve bunun 840'ı kuşandığın şeylerden"). Ayrı satıra
/// inince iki ayrı sayı gibi okunuyordu.
///
/// Katkı BOŞSA hiç yazılmıyor — `+0`, katkısı olmayan bir donanımı katkılı
/// gibi göstermek olurdu.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.delta,
    required this.metrics,
    required this.cerceveli,
  });

  final String label;
  final String value;
  final Color color;
  final String delta;
  final MenuMetrics metrics;

  /// Zemin ve kenar çizilsin mi — bkz. çağrı yerindeki gerekçe.
  final bool cerceveli;

  @override
  Widget build(BuildContext context) {
    final govde = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: MenuType.number(metrics, color: color)),
            if (delta.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                delta,
                style: MenuType.label(
                  // Eksi katkı da olabiliyor (hız düşüren bir jeneratör):
                  // rengin işareti sayının işaretini izlemeli, yoksa yeşil
                  // bir "-40" oyuncuya kazanç diye okunur.
                  color: delta.startsWith('-') ? Palette.danger : Palette.good,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: MenuType.label(color: Palette.muted)),
      ],
    );

    if (!cerceveli) return govde;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.028),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: govde,
    );
  }
}

/// Yükseltmenin MALZEME kapısı — "elindeki / gereken".
///
/// Fiyattan ayrı bir satır, çünkü ayrı bir şey söylüyor. Fiyat "ne kadar
/// pahalı", bu "hangi içeriği oynadın". Yetmediğinde kırmızı olması yeterli
/// değil; oyuncunun ne biriktireceğini bilmesi için RANK da yazıyor.
class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color, {this.enAz = 0});

  final String text;
  final Color color;

  /// En az genişlik — aynı yerde DÖNÜŞÜMLÜ duran rozetler için.
  ///
  /// Gemi kartındaki rozet üç durumdan birini yazıyor: AKTİF · SEÇ ·
  /// KİLİTLİ. Genişlik yazının uzunluğundan çıkınca aynı ızgaradaki üç kart
  /// üç farklı genişlikte rozet taşıyor ve kartların sağ kenarı tırtıklı
  /// çıkıyordu — oysa rozetin söylediği şey bir DURUM, ve durumların
  /// birbirinden geniş olması için bir sebep yok.
  final double enAz;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minWidth: enAz),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Text(text, style: MenuType.label(color: color)),
  );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, required this.metrics});

  final VoidCallback onTap;
  final MenuMetrics metrics;

  @override
  Widget build(BuildContext context) => Positioned(
    top: metrics.gutter - 6,
    right: metrics.gutter - 6,
    child: GestureDetector(
      key: hangarCloseKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Dokunma hedefi ölçeklenmiyor.
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.menuBg.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        // Metin glifi ('✕') DEĞİL ikon: o glif her tek aralıklı yazı tipinde
        // yok ve olmadığında yerine boş kutu çiziliyor — kapatma düğmesi,
        // oyuncunun bulamamayı en pahalıya ödeyeceği düğme.
        child: const Icon(Icons.close, size: 20, color: Palette.inkDim),
      ),
    ),
  );
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.metrics});

  final String message;
  final MenuMetrics metrics;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: metrics.gutter, vertical: 10),
      color: Palette.danger.withValues(alpha: 0.16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Palette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MenuType.body(color: Palette.danger),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Filo penceresi: bütün gemiler, sahip olunmayanlar kilitli.
class _FleetSheet extends StatelessWidget {
  const _FleetSheet({
    required this.hangar,
    required this.metrics,
    required this.onSelect,
    required this.onClose,
  });

  final HangarView hangar;
  final MenuMetrics metrics;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    // Pencere EKRANA sığar: sabit bir genişlik telefonda kenardan taşardı.
    final width = (m.width - m.gutter * 2).clamp(280.0, 760.0);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: ColoredBox(
          color: Palette.perde,
          // Kenar payı MERKEZİN DIŞINDA: içeride olduğunda `Center` çocuğa
          // ekran yüksekliği kadar yer veriyor, çocuk payını onun üstüne
          // ekliyor ve toplam ekranı aşıyordu — pencere yukarıdan taşıyordu.
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: m.gutter),
              child: Center(
                child: GestureDetector(
                  // Pencerenin İÇİNE dokunmak onu kapatmamalı.
                  onTap: () {},
                  child: Container(
                    width: width,
                    padding: EdgeInsets.all(m.gutter),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0F1B2E), Color(0xFF0A111E)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Palette.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                Metin.aktifGemiyiSec(context.dil),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MenuType.title(m),
                              ),
                            ),
                            const SizedBox(width: 12),
                            MenuButton(
                              key: fleetCloseKey,
                              label: Metin.kapat(context.dil),
                              filled: false,
                              color: Palette.inkDim,
                              onTap: onClose,
                            ),
                          ],
                        ),
                        SizedBox(height: m.gap),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final hull in HullClass.all)
                                  SizedBox(
                                    // Dar ekranda tek sütun, geniş ekranda üç.
                                    width: width < 520
                                        ? width - m.gutter * 2
                                        : (width - m.gutter * 2 - 24) / 3,
                                    child: _FleetCard(
                                      hull: hull,
                                      metrics: m,
                                      owned: hangar.hulls.contains(hull.id),
                                      active: hull.id == hangar.activeHullId,
                                      onSelect: () => onSelect(hull.id),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: m.gap),
                        Text(
                          Metin.kilitliGemilerMagazadan(context.dil),
                          style: MenuType.label(color: Palette.faint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FleetCard extends StatelessWidget {
  const _FleetCard({
    required this.hull,
    required this.metrics,
    required this.owned,
    required this.active,
    required this.onSelect,
  });

  final HullClass hull;
  final MenuMetrics metrics;
  final bool owned;
  final bool active;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final dil = context.dil;
    final (badge, badgeColor) = active
        ? (Metin.aktif(dil), Palette.accent)
        : owned
        ? (Metin.sec(dil), Palette.accent)
        : (Metin.kilitli(dil), Palette.faint);

    return GestureDetector(
      key: fleetCardKey(hull.id),
      behavior: HitTestBehavior.opaque,
      onTap: owned && !active ? onSelect : null,
      child: Opacity(
        opacity: owned ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? Palette.accent.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.028),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? Palette.accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gövdenin kendi silueti. Kartın en hızlı okunan parçası:
                  // ad ve stat okumadan önce hangi gemi olduğu görünüyor.
                  GemiIkonu(hullId: hull.id, boy: GemiIkonu.filoBoyu),
                  const SizedBox(width: 10),
                  Expanded(
                    // Ad KENDİ satırında. İlk denemede ad ile rozet aynı
                    // satırdaydı ve ikon eklenince "Spect…" / "Colos…" diye
                    // kesildi — üç sütunlu ızgarada kart genişliği ikiye
                    // bölünecek kadar geniş değil.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rozet AD satırında: ad kısa (tek kelime), rank
                        // satırı ise uzun ("PARLAYAN PEMBE · 23 YUVA").
                        // Rozeti alta koymak o satırı kesiyordu.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hull.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MenuType.body(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Üç durum da AYNI genişlikte: KİLİTLİ en
                            // uzunu, ötekiler ona hizalanıyor.
                            _Badge(badge, badgeColor, enAz: 62),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Metin.govdeRankYuva.bicim(dil, {
                            'rank': rankEtiketi(hull.tier, dil),
                            'yuva': hull.totalSlots,
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MenuType.label(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(height: 10),
              // İki sütun SABİT: `Wrap` kart genişliğine göre bazen üç satıra
              // düşüyordu ve aynı ekrandaki iki kart farklı yükseklikte
              // görünüyordu.
              Row(
                children: [
                  Expanded(
                    child: StatCell(
                      Metin.govde(dil),
                      menuNumber(hull.baseHull, dil),
                      metrics: metrics,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      Metin.kalkan(dil),
                      menuNumber(hull.baseShield, dil),
                      metrics: metrics,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatCell(
                      Metin.hiz(dil),
                      menuNumber(hull.baseSpeed, dil),
                      metrics: metrics,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      Metin.fiyat(dil),
                      owned
                          ? '—'
                          : hull.satinAlinabilir
                          ? menuNumber(hull.price!, dil)
                          : Metin.yakinda(dil),
                      metrics: metrics,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Test kancaları ──────────────────────────────────────────────────────
//
// Anahtarla aranıyor çünkü METİNLE aramak yanlış şeyi buluyor: PL-1'in fiyatı
// 12000 ve Bastion'un gövdesi de 12000. İlk yazışta test gövde canına basıp
// "satın alma sunucuya ulaşmadı" diyordu.

/// Menüyü kapatan düğme.
const hangarCloseKey = Key('hangar-close');

/// Üst navigasyondaki sekme.
Key menuTabKey(MenuTabId tab) => Key('menu-tab-${tab.name}');

/// Hangarın sekmesi — EKİPMAN · DROİD · MATERYAL · GEMİ.
///
/// Adı `paneTabKey` kaldı ve kalması bilerek: anahtar bir süre dar ekrandaki
/// bölme seçicisini gösteriyordu, şimdi sekmeleri gösteriyor ama işlevi aynı
/// — "sol bölmede ne var" sorusunu değiştiren düğme. Adı değiştirmek, aynı
/// düğmeyi arayan her testi bir kez daha kırardı.
Key paneTabKey(HangarTab sekme) => Key('pane-tab-${sekme.name}');

/// Donanımdaki bir yuva.
Key slotTileKey(SlotRef slot) => Key('slot-${slot.id}');

/// Depodaki bir parça.
Key depotTileKey(String instanceId) => Key('depot-$instanceId');

/// Seçili yuvanın işlem düğmeleri.
const slotEquipKey = Key('slot-equip');

/// Filo penceresi.
const fleetOpenKey = Key('fleet-open');

/// GEMİ sekmesindeki gemiye dokunmak da filo penceresini açıyor: telefonda
/// üst şerit yok, yani GEMİ DEĞİŞTİR düğmesi de yok.
const gemiOnizlemeKey = Key('gemi-onizleme');

/// OTOMATİK DONAT düğmesi — testin ve görsel referansın tutamağı.
const otoDonatKey = Key('oto-donat');
const fleetCloseKey = Key('fleet-close');

/// Gemi adı satırındaki unvan (10.4).
const hangarUnvanKey = Key('hangar-unvan');
Key fleetCardKey(String hullId) => Key('fleet-$hullId');

/// Parçala ve sentez düğmeleri.
const Key parcalaKey = Key('depot-parcala');
const Key sentezKey = Key('depot-sentez');

/// Alt stat çevirme düğmeleri.
const Key cevirKey = Key('slot-cevir');
const Key kabulKey = Key('slot-kabul');

/// Filo kutucuğunun anahtarı — testler için.
Key filoTileKey(int i) => ValueKey('filo-$i');

/// Deponun ÜÇ NOKTA menüsü — parçala ve sentez orada.
const Key depoMenuKey = Key('depo-menu');

/// Droidin bir EKİPMAN yuvası — testler ve görsel referans için.
Key droidYuvaKey(String droidId, int i) => ValueKey('droid-yuva-$droidId-$i');

/// Droidin TASARIM yuvası.
Key droidTasarimKey(String droidId) => ValueKey('droid-tasarim-$droidId');
