import 'dart:collection';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:voidspace_core/voidspace_core.dart';

/// ATEŞİN NİŞAN YAYI — bunun dışında mermi çıkmıyor.
///
/// Elle konmuş bir derece değil, dönüş hızından türüyor: bir tikte dönülen
/// açı `turnRate × fixedDt` (bugün 13,4°), yay onun bir buçuk katı (20°).
///
/// Türetilmiş olması bir incelik değil bir GÜVENCE: sabit bir derece,
/// dönüş hızı düşürüldüğü gün ulaşılamaz hâle gelirdi — gemi tek tikte yayın
/// üstünden atlar ve hiç ateş edemezdi. Bir buçuk kat, tam o sıçramayı
/// soğuruyor.
const double _nisanYayi = ShipSim.turnRate * ShipSim.fixedDt * 1.5;

/// Sunucudaki bir gemi: kimlik + OTORİTER durum + girdi kuyruğu.
class ServerShip {
  ServerShip({required this.id, required this.name, required this.state});

  final int id;
  final String name;

  /// Tek doğruluk kaynağı. İstemcideki karşılığı bunun bir TAHMİNİ, kopyası
  /// değil.
  ShipSimState state;

  /// Sunucunun İŞLEDİĞİ son girdi sırası. Snapshot'ta geri gider; istemci
  /// mutabakatı bu sayıya dayanır.
  int acknowledgedSeq = 0;

  /// Son YAYINLANAN meta'nın imzası (namlu, kademe, filo, formasyon).
  ///
  /// Meta yalnız değiştiğinde yollanıyor; "değişti mi" sorusunun cevabı
  /// burada. Namlu sayısını karşılaştıran eski ölçü formasyonu ve filoyu
  /// görmüyordu: oyuncu formasyon seçiyor, ekranda hiçbir şey olmuyor,
  /// geçitten geçince (o yol meta'yı yeniden yolluyor) düzeliyordu.
  String metaImzasi = '';

  /// SEÇİLİ MERMİ — hangardan geliyor, yaylım başına okunuyor (17.3, 17.8).
  /// Kimlik tüketim için, çarpan ve sifon hasar için; üçü birlikte değişir
  /// (`Gateway._mermiyiUygula`). Zone stoku bilmiyor: orası simülasyon.
  String mermiId = Mermi.varsayilan.id;
  double mermiCarpani = 1;
  bool sifon = false;

  /// ROKET (18): kendi beklemesi, kendi mermisi. Salvo tabanı statlarda
  /// (`roketHasari`), çarpan seçili roket mermisinden; bekleme aralık kadar.
  double roketBeklemesi = 0;
  String roketId = Roket.varsayilan.id;
  double roketCarpani = 1;

  /// Titreşim tamponu (jitter buffer). Ağ paketleri düzgün aralıklarla
  /// gelmez; tik ise gelir. Aradaki farkı bu kuyruk yutar.
  final Queue<ShipInput> pending = Queue<ShipInput>();

  /// Kuyruk boşken tekrarlanan girdi — paket geciktiğinde geminin bir tik
  /// donmasındansa aynı yönde devam etmesi çok daha az fark edilir.
  ShipInput lastApplied = ShipInput.idle;

  /// Son girdi zamanı (sunucu tiki). Ölü bağlantıları düşürmek için.
  int lastInputTick = 0;

  /// Kritik zarının PRD sayacı — ATICI başına.
  ///
  /// Paylaşılsaydı iki oyuncu birbirinin kuraklığını devralırdı; atış başına
  /// kurulsaydı PRD bağımsız zara dönerdi ve bütün amaç kaybolurdu.
  ///
  /// Donatım değişince yeniden kuruluyor (şans değişti, sabit de değişmeli) ve
  /// sayaç sıfırlanıyor — kuraklığın eski build'den taşınması, oyuncunun
  /// göremediği bir borç olurdu.
  PrdRoller? _critRoller;

  /// [chance] şansıyla kritik zarı at.
  bool rollCrit(double chance, math.Random random) {
    if (chance <= 0) return false;
    final roller = _critRoller;
    if (roller == null || roller.chance != chance) {
      _critRoller = PrdRoller(chance);
    }
    return _critRoller!.roll(random);
  }

  /// Sıradaki atışa kalan süre (sn).
  ///
  /// Paylaşılan `ShipSimState`'te DEĞİL, burada: istemci bunu yeniden
  /// üretemez (bir atışın gerçekten isabet edip etmediğini yalnız sunucu
  /// bilir), ve istemcinin doğru tahmin edemeyeceği bir alanı paylaşılan
  /// duruma koymak mutabakatta sessiz sapma üretir.
  double fireCooldown = 0;

  /// Bu gemiyi hangi HESAP kullanıyor.
  ///
  /// Yeniden bağlanmanın çivisi: kopan oyuncu geri geldiğinde aynı gemiye
  /// dönmeli, yeni bir gemi olarak doğmamalı. Kimliği ada bağlamak yetmez —
  /// ad değişebilir, hesap kimliği değişmez.
  String accountId = '';

  /// Oturumu kopmuşsa, geminin dünyadan silineceği tik.
  ///
  /// Kopar kopmaz silmek yanlış: iki saniyelik bir ağ kesintisi oyuncunun
  /// gemisini, konumunu ve savaşını kaybetmesi demek olurdu. Süre dolarsa
  /// gemi gerçekten gider.
  int? orphanUntilTick;

  bool get isOrphan => orphanUntilTick != null;

  /// Ölü geminin yeniden doğacağı tik. Yaşayan gemide `null`.
  int? respawnAtTick;

  /// ŞU AN bu geminin ilgi alanında olan kimlikler.
  ///
  /// Histerezisin belleği: bir gemi listeye [Protocol.interestRadius] ile
  /// girer ama ancak [Protocol.interestExitRadius] ile çıkar. Sınırda seyreden
  /// bir geminin saniyede onlarca kez görünüp kaybolmasını engelleyen tek şey
  /// bu küme.
  final Set<int> visible = {};

  /// Aynı histerezisin alien karşılığı — bkz. [Zone.collectVisibleAliens].
  final Set<int> visibleAliens = {};

  /// Entity kimliği → bu izleyiciye EN SON gönderildiği tik.
  ///
  /// Öncelikli replikasyonun belleği. İzleyici başına bir harita: 240
  /// oyuncunun her biri 240 entity görürken ~57 bin giriş, `visible`
  /// kümesiyle aynı mertebe.
  ///
  /// **Neden izleyici başına.** Gönderim kararı mesafeye bağlı ve mesafe
  /// izleyiciye göre değişiyor; ortak bir sayaç, yakındakini uzaktakiyle aynı
  /// hızda göndermek demekti.
  final Map<int, int> lastSentTick = {};

  /// Temeli BAYATLAMIŞ entity kimlikleri — dönüşte tam kayıt gerekiyor.
  ///
  /// `lastSentTick` tek başına yetmiyor ve bu incelik pahalıya mal oluyordu:
  /// "atladıysam temel bayattır" kuralı FAZLA temkinli. Değişmemiş bir
  /// entity'yi atlamak temeli bozmuyor — sunucunun yeni temeli eskisiyle
  /// aynı. Bayatlatan şey, DEĞİŞMİŞ bir tiki atlamak.
  ///
  /// Entity başına bir bit; izleyici başına bir küme.
  final Set<int> staleBaseline = {};

  /// ÖNCEKİ tikte tele giden kuantalanmış değerler — delta'nın temeli.
  ///
  /// İstemci başına DEĞİL, entity başına TEK kopya. WebSocket sıralı ve
  /// güvenilir teslim ettiği için, geçen tikin snapshot'ını alan her istemcinin
  /// elinde tam olarak bu değerler var. Quake 3'ün istemci başına geçmiş tutma
  /// zorunluluğu UDP'den doğuyordu; burada o maliyet yok.
  Int32List wire = Int32List(EntityDelta.fields);

  /// BU tikin kuantalanmış değerleri.
  ///
  /// Tik başına bir kez doldurulur, bütün izleyiciler aynı diziyi okur.
  /// İzleyici başına kuantalamak, 200 gemide tik başına on binlerce gereksiz
  /// dönüşüm ederdi — oysa değer izleyiciden bağımsız.
  Int32List wireNow = Int32List(EntityDelta.fields);

  /// Bu tikin delta MASKESİ — `wireNow` ile `wire` arasındaki fark.
  ///
  /// Tik başına BİR kez hesaplanıyor çünkü izleyiciden BAĞIMSIZ: maske yalnız
  /// entity'nin kendi iki değerine bakıyor. İzleyici başına hesaplamak 240
  /// oyuncu × 240 entity = tik başına 57 bin çağrı ederdi — ve öncelikli
  /// replikasyon onu üçe katlamıştı (aday elemesi, bayatlık işaretlemesi,
  /// yazma). Ölçüldü: 240 oyuncuda tik p99'u 26'dan 43 ms'ye çıkarmıştı.
  int wireMask = EntityDelta.full;

  /// [wire] gerçek bir geçmişi mi tutuyor. İlk tikte hayır: yeni katılan
  /// geminin temeli yok, tam kayıt gitmeli.
  bool wireValid = false;

  /// Bu tikin değerlerini temel yap. Snapshot'lar gönderildikten SONRA.
  void promoteWire() {
    final previous = wire;
    wire = wireNow;
    wireNow = previous;
    wireValid = true;
  }
}

/// Bir harita: entity kümesi + sabit adımlı otorite döngüsü.
///
/// Süreç değil SINIF olması kasıtlı. Bugün tek bir zone var; ikincisi
/// geldiğinde (komşu haritalar) her biri kendi
/// `Isolate`'inde koşacak ve buradaki hiçbir satır değişmeyecek. Global durum
/// bu geçişi imkânsız kılardı.
class Zone {
  Zone({
    this.world = GameWorld.standard,
    this.capacity = 64,
    this.alienCount = 36,
    int diceSeed = 0,
    int baslangicTik = 0,
    this.serpmeTohumu = 0,
    this.kimlikTabani = 1,
    this.kimlikAraligi = Protocol.maxShipId,
    Bolge? bolge,
  }) : bolge = bolge ?? Bolge.ilk,
       _tick = baslangicTik,
       _nextId = kimlikTabani,
       assert(
         capacity <= Protocol.maxShipId,
         'kapasite gemi kimlik uzayını aşıyor — üstü alien',
       ),
       assert(
         alienCount <= Protocol.maxShipId,
         'alien sayısı kimlik uzayını aşıyor',
       ),
       _dice = math.Random(diceSeed) {
    _spawnAliens();
  }

  final GameWorld world;

  /// Zone başına oyuncu tavanı. Sınır CPU değil OKUNABİLİRLİK: 64 gemi tek
  /// ekranda zaten kalabalık, ve ilgi alanı yarıçapı bu yoğunlukta ayarlandı.
  final int capacity;

  /// Haritaya serpilen alien sayısı.
  ///
  /// Otuz altı, 12000×8000'lik bir haritada altışar sıra demek: iki alien
  /// kümesi arası ~2000 birim, yani ilgi alanı yarıçapının (2600) altında.
  /// Oyuncu nereye giderse gitsin ekranında bir şey oluyor, ama harita da
  /// kalabalık görünmüyor.
  final int alienCount;

  /// SERPME TOHUMU — sürünün haritaya özel kayması.
  ///
  /// Olmadığı sürece aynı ölçüdeki bütün haritalar BİREBİR aynı sürüyü
  /// doğuruyordu: `_scatter` deterministik bir karma ve girdisi yalnız yuva
  /// numarası. Yirmi dört harita, ikisi kadar çeşit demekti — bir bölgeyi
  /// öğrenen oyuncu aynı ölçüdeki hepsini öğrenmiş oluyordu.
  ///
  /// `diceSeed` bunu çözmüyor: o zarlar için ve serpmeye hiç dokunmuyor.
  final int serpmeTohumu;

  /// Bu bölgenin gemi kimlik ARALIĞI — `[kimlikTabani, +kimlikAraligi)`.
  ///
  /// Bölgeler arası çakışmayı önlüyor. `_sessions` gemi kimliğiyle anahtarlı
  /// ve iki bölge aynı kimliği dağıtsaydı, bir haritadaki oyuncunun oturumu
  /// başka bir haritadaki gemiye bağlanırdı — sessizce, ve ödüller yanlış
  /// hesaba yazılırdı.
  ///
  /// Aralık ayırmak, kimlik dağıtıcıyı Gateway'e taşımaktan ucuz ve bir yan
  /// fayda veriyor: kimliğe bakınca geminin hangi haritada olduğu okunuyor.
  /// Uzay `maxShipId` = 32.767 ve 24 harita × 64 kapasite onun çok altında.
  final int kimlikTabani;
  final int kimlikAraligi;

  /// Bu haritanın bölgesi — kadroyu ve bant ölçeğini o veriyor.
  ///
  /// Tek bir dünya varken bu soru yoktu; bugün bölge sabit `AlienStats`
  /// yerine [YaratikKadrosu]'nun o bölgeye ait üyelerini doğuruyor ve statları
  /// BANTTAN çıkıyor. Öncesinde Yas Boşluğu'ndaki yaratık, Sığlık'takiyle
  /// birebir aynıydı — dünya gezilebilir ama her yeri aynıydı.
  final Bolge bolge;

  /// Serpilebilir kadro: bölgenin BOSS OLMAYAN üyeleri.
  ///
  /// Boss dışarıda çünkü serpilmiyor — zamanlı doğuyor (bkz. `HaritaKaydi`).
  late final List<YaratikKimligi> kadro = [
    for (final y in YaratikKadrosu.bolgenin(bolge.kademe))
      if (y.sinif != DusmanSinifi.boss) y,
  ];

  /// Bu bölgenin BOSS'u. Kadroda boss yoksa `null`.
  late final YaratikKimligi? bossKimligi = YaratikKadrosu.bolgenin(
    bolge.kademe,
  ).where((y) => y.sinif == DusmanSinifi.boss).firstOrNull;

  /// Boss'un alien kimliği — sürünün bir üstü.
  ///
  /// Izgaranın dışında, çünkü boss ızgaraya ait değil: serpilmiyor, randevuyla
  /// geliyor. Harita başına kimlik payı 1365 ve sürü 32 kullanıyor; bir tane
  /// daha almak bütçeyi zorlamıyor.
  int get bossId => Protocol.alienIdBase + alienCount;

  /// Boss şu an AYAKTA mı.
  ///
  /// Ölü boss haritadan silinmiyor (kimlik geri dönüşümü gerektirirdi), o
  /// yüzden varlığı değil CANLILIĞI soruluyor.
  bool get bossCanli => aliens[bossId]?.alive ?? false;

  /// Boss'u doğur. Zaten ayaktaysa ya da bu bölgenin boss'u yoksa `false`.
  ///
  /// **Konum KISITTAN türüyor, seçilmiyor.** İki şeyi aynı anda tutmak
  /// zorunda:
  ///
  ///  * **En derin bantta.** Bant metriği dikdörtgen halkalar çiziyor ve
  ///    merkez en derin: boss oranın hakkı. Kenara koymak, en zor içeriği
  ///    geçitten iki adım öteye koymak olurdu.
  ///  * **Doğan oyuncunun menzilinin DIŞINDA.** İlk hâli tam merkezdeydi ve
  ///    yanlıştı: oyuncular merkezden [dogusHalkasi] (900) ötede doğuyor,
  ///    Kurvex'in menzili 1120. Yani doğan HER oyuncu, daha tek tuşa
  ///    basmadan 409.091 canlı bir boss'un ateşi altındaydı.
  ///
  /// `dogusHalkasi + menzil` ikisini birden sağlıyor: halkanın en yakın
  /// noktasına tam menzil kadar uzak, ve en derin bant o kadar geniş
  /// (ölçüldü: 3.250–3.950 birim, gereken 2.020). Bandın içinde kaldığını
  /// `boss_test` her bölge için ayrıca doğruluyor — bir gün dar bir bölge
  /// gelirse orada kırılsın.
  ///
  /// Yeniden doğuş sayacı sonsuz — randevu `HaritaKaydi`'nda. Bkz.
  /// [YaratikKimligi.statFor].
  bool bossDogur() {
    final kimlik = bossKimligi;
    if (kimlik == null || bossCanli) return false;
    // Rank EN DERİN banttan; konum da o bandın içinde kalıyor.
    final stats = kimlik.statFor(
      bolge.rankOf(bandFor(world.centre)),
      dogusSuresi: double.infinity,
    );
    aliens[bossId] = AlienSimState.spawn(
      stats,
      bossKonumu(stats.aggroRange),
      // Tohum sürünün dışında: aynı tohum aynı atış fazını verirdi ve boss
      // merkezdeki bir yaratıkla senkron ateş ederdi.
      alienCount + 1,
    );
    return true;
  }

  /// Boss'un duracağı nokta — [menzil] onun kışkırtılma yarıçapı.
  Vec2 bossKonumu(double menzil) =>
      world.clamp(world.centre + Vec2(dogusHalkasi + menzil, 0));

  /// Doğuş halkasının yarıçapı — oyuncular merkezden bu kadar ötede beliriyor.
  ///
  /// AÇIK bir sabit, çünkü artık iki yerden okunuyor: doğuş noktası ve boss'un
  /// ondan uzak durma kısıtı. Sihirli sayı olarak kaldığı sürece ikincisi
  /// birincisinden habersiz yazılabiliyordu — ve yazıldı.
  static const double dogusHalkasi = 900;

  /// Aralığın dışındaki ilk kimlik.
  int get _kimlikTavani =>
      math.min(kimlikTabani + kimlikAraligi, Protocol.maxShipId + 1);

  final Map<int, ServerShip> ships = {};

  /// Alien'ler. Kimlikleri gemilerden AYRI bir uzayda: istemci ikisini ayrı
  /// haritalarda tutuyor, ve iki uzayı birleştirmek gemi kimliklerini
  /// alien sayısı kadar daraltırdı.
  final Map<int, AlienSimState> aliens = {};

  /// Alien kimliği → saldırganlar tablosu.
  ///
  /// `AlienSimState` DEĞİŞMEZ ve her tik yenisiyle değiştiriliyor; içine
  /// büyüyen bir harita koymak, her tik o haritayı kopyalamak demekti.
  /// Tablonun sahibi bölge — hedef kararını da zaten burası veriyor.
  final Map<int, ThreatTable> _threat = {};

  /// Bir alienin saldırganlar tablosu — testler ve ödül dağıtımı için.
  ThreatTable threatOf(int alienId) => _threat[alienId] ??= ThreatTable();

  /// BU TİKTE çözülen vuruşlar. Her tikin başında temizlenir — bir olay
  /// listesi ancak sahibi onu ne zaman boşaltacağını biliyorsa güvenlidir,
  /// ve o an tikin başlangıcı.
  ///
  /// Süzme burada DEĞİL [Gateway]'de: kimin neyi göreceği ilgi alanına bağlı
  /// ve o hesap oturum başına yapılır. Zone yalnız "ne oldu"yu tutar.
  final List<ShotEvent> shots = [];

  /// BU TİKTE ölen gemiler. Her tik başında temizleniyor, `shots` gibi.
  final List<int> deaths = [];

  /// Kritik zarının kaynağı — TOHUMLU.
  ///
  /// Haritanın kendisinde `Random` yok ve olmaması bilinçli: sunucu yeniden
  /// başladığında sürünün aynı yerde doğması, bir hatayı iki kez görebilmek
  /// demek. Aynı gerekçe zar için de geçerli — tohumlu bir üreteç, kritik
  /// sırası da dâhil bütün tikin yeniden oynatılabilmesini sağlıyor.
  ///
  /// Zarın SUNUCUDA atılmasının sebebi ayrı: istemci kendi kritiğini tahmin
  /// etseydi ekrandaki rakam ile inen hasar ayrışırdı.
  final math.Random _dice;

  /// Bu bölgenin saati.
  ///
  /// Kuruluşta sıfırdan BAŞLAMAYABİLİR: haritalar ilk oyuncu girince tembel
  /// yaratılıyor ve o an sunucunun saati çoktan ilerlemiş oluyor. Sıfırdan
  /// başlasaydı `tick - session.lastHeardTick` eksi çıkar ve yeni bölgeye
  /// giren herkes anında "sessiz" sayılırdı.
  int _tick;
  int _nextId;

  int get tick => _tick;
  bool get isFull => ships.length >= capacity;

  /// Alien'leri haritaya SERPER — bir kez, kuruluşta.
  ///
  /// Düzen jitterlı ızgara: saf rastgelelik kümelenir ve haritanın yarısını
  /// boş bırakır, saf ızgara ise ekilmiş tarla gibi görünür. Hücre başına bir
  /// alien + hücre içinde karma tabanlı kayma, ikisinin arasını tutuyor.
  ///
  /// `Random` YOK: sunucu yeniden başladığında sürünün aynı yerde doğması,
  /// bir hatayı iki kez görebilmek demek.
  void _spawnAliens() {
    if (alienCount <= 0) return;
    final cols = math.sqrt(alienCount).ceil();
    final rows = (alienCount / cols).ceil();
    // Kenar payı alien yarıçapının katı: sınıra yapışan bir alien'in yarısı
    // duvarın içinde kalırdı.
    const inset = 400.0;
    final cellW = (world.width - inset * 2) / cols;
    final cellH = (world.height - inset * 2) / rows;

    for (var i = 0; i < alienCount; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      // Tohum BÜYÜK bir asalla çarpılıyor: ızgaranın periyoduyla (cols)
      // örtüşen bir kayma, dağılımı `_kindAt`'in başına gelenin aynısıyla
      // çizgiye çevirirdi.
      final tohum = serpmeTohumu * 977;
      final home = world.clamp(
        Vec2(
          inset + cellW * (col + 0.15 + 0.7 * _scatter(tohum + i * 2 + 1)),
          inset + cellH * (row + 0.15 + 0.7 * _scatter(tohum + i * 2 + 2)),
        ),
      );
      // Kimlik GEMİLERDEN ayrı aralıkta: hedef alanı tek bir `u16` ve iki
      // varlığı birden göstermek zorunda (bkz. `Protocol.alienIdBase`).
      aliens[Protocol.alienIdBase + i] = AlienSimState.spawn(
        _kindAt(i, cols).statFor(bolge.rankOf(bandFor(home))),
        home,
        i + 1,
      );
    }
  }

  /// [index] numaralı ızgara yuvasına hangi tür düşüyor.
  ///
  /// Seyreklik bir denge kararı: Leviathan dokuz yaylım sürüyor, yani haritanın
  /// yarısı Leviathan olsaydı avlanmak bir işe dönerdi. Altıda bir, oyuncunun
  /// "şuna girmeye değer mi" diye düşünmesini sağlayacak kadar nadir.
  ///
  /// **Seçim SATIR VE SÜTUNDAN, düz sıradan DEĞİL.** İlk hâli `index % 6 == 5`
  /// idi ve haritada tek bir Leviathan görünmüyordu. Sebep örtüşme: ızgara
  /// `ceil(√36) = 6` sütunlu, yani `col = index % 6`. "Her altıncı" demek, tam
  /// olarak "hep son sütun" demekti — altı Leviathan da haritanın sağ kenarına
  /// dizilmişti ve doğuş noktasından 4900 birim uzaktaydı. İlgi yarıçapı 2600;
  /// oyuncu hiçbirini göremiyordu.
  ///
  /// `(col + row)` köşegen bir desen veriyor: her satırda bir tane, farklı
  /// sütunda. Izgara geometrisiyle aynı periyodu paylaşan hiçbir ifade
  /// kullanılmamalı — bağımsız görünen iki modulo aynı periyoda sahip
  /// olduğunda, dağılım sessizce çizgiye dönüşüyor.
  YaratikKimligi _kindAt(int index, int cols) {
    final col = index % cols;
    final row = index ~/ cols;
    final siradanlar = [
      for (final y in kadro)
        if (y.sinif == DusmanSinifi.siradan) y,
    ];
    final guclu = kadro.where((y) => y.sinif == DusmanSinifi.guclu);
    if ((col + row) % 6 == 0 && guclu.isNotEmpty) return guclu.first;
    if (siradanlar.isEmpty) return kadro.first;
    // İki sıradan arasında DAMA TAHTASI. Izgaranın periyoduyla örtüşen her
    // ifade (`index % 2`, sütun sayısı çiftse) ikisini ayrı sütunlara dizer
    // ve harita çizgili görünür — köşegen bunu kırıyor, güçlünün seçiminde
    // olduğu gibi.
    return siradanlar[(col + row) % siradanlar.length];
  }

  /// [konum]'un düştüğü BANT — dıştan içe, sıfırdan başlayarak.
  ///
  /// Bantlar aynı haritanın iç içe halkaları (alan 11): dış bant bölgenin ilk
  /// rankı, iç bant sonuncusu. Yani merkeze uçmak derinleşmek demek — ve
  /// yaratıklar orada sertleşiyor.
  ///
  /// Ölçü DİKDÖRTGEN halka: `max(|dx|/yarıEn, |dy|/yarıBoy)`. Çember
  /// kullanmak köşeleri dış banda bırakırdı ve harita dikdörtgen.
  int bandFor(Vec2 konum) {
    if (bolge.bantSayisi <= 1) return 0;
    final merkez = world.centre;
    final t = math.max(
      (konum.x - merkez.x).abs() / merkez.x,
      (konum.y - merkez.y).abs() / merkez.y,
    );
    final ic = ((1 - t) * bolge.bantSayisi).floor();
    return ic.clamp(0, bolge.bantSayisi - 1);
  }

  static double _scatter(int n) {
    final v = math.sin(n * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// Altın açıyla halka üzerine dağıtılmış doğuş noktası.
  ///
  /// Merkezde üst üste doğmak iki sebeple kötü: gemiler birbirini gizler ve
  /// ilgi alanı filtresi ilk saniyede herkesi herkese gönderir. Altın açı
  /// deterministik olduğu için testte de tahmin edilebilir kalır.
  Vec2 _spawnPoint(int id) {
    const golden = 2.399963229728653;
    final a = id * golden;
    return world.clamp(
      world.centre + Vec2(math.cos(a), math.sin(a)) * dogusHalkasi,
    );
  }

  /// Kopmuş bir oturumun gemisi kaç tik dünyada bekler.
  ///
  /// **On saniyeydi ve mobil için yanlıştı.** Bu bir telefon oyunu: oyuncu
  /// bildirime bakar, WiFi'dan hücresele geçer, asansöre girer, uygulamayı
  /// arka plana alır. Bunların hepsi on saniyeyi rahatça aşıyor ve on saniyede
  /// silinen gemi, "bir dakika başka şeye baktım, oyunu kaybettim" demek.
  ///
  /// Bir dakika bu senaryoların çoğunu örtüyor. Uzun bekleme normalde yer
  /// israfı olurdu — ama etmiyor, çünkü zone dolduğunda sahipsiz gemiler
  /// TAHLİYE ediliyor (bkz. [join]). Yani süre cömert, kapasite riski yok.
  static const int orphanGraceTicks = 60 * Protocol.tickRate;

  /// Ölümden yeniden doğuşa geçen süre.
  ///
  /// Sıfır olamaz: ölümün bir bedeli olmalı, yoksa gemiyi siper gibi kullanmak
  /// bedava olur. Uzun da olamaz: oyuncuyu ekrana bakarak beklemeye zorlamak,
  /// onu oyundan çıkarmanın en hızlı yolu. Beş saniye ikisinin arası.
  static const int respawnDelayTicks = 5 * Protocol.tickRate;

  /// Ölümü zamanlar ve süresi dolanları yeniden doğurur.
  ///
  /// Hasarın KAYNAĞINDAN bağımsız: lazer, alien ya da hata ayıklama komutu —
  /// hepsi buraya düşüyor. Ölümü vuruşun çözüldüğü yerde ele alsaydık her yeni
  /// hasar kaynağı kendi yeniden doğuşunu da yazmak zorunda kalırdı.
  void _handleDeaths() {
    for (final ship in ships.values) {
      if (ship.state.alive) {
        ship.respawnAtTick = null;
        continue;
      }
      final at = ship.respawnAtTick;
      if (at == null) {
        ship.respawnAtTick = _tick + respawnDelayTicks;
        // Ölüm ANI burada, bir kez. Ekonomi katmanı (`Gateway`) bunu okuyup
        // tamir bedelini kesiyor.
        //
        // Kaynağın atış olayı DEĞİL ölüm anı olması bilinçli: yarın bir
        // çarpışma ya da harita tehlikesi gemi öldürdüğünde, bedeli yazan
        // kodun değişmesi gerekmesin.
        deaths.add(ship.id);
        continue;
      }
      if (_tick < at) continue;

      // Yeniden doğuş DOĞUŞ NOKTASINDA, öldüğü yerde değil.
      //
      // Öldüğü yerde doğmak, onu öldüreni hâlâ orada bulmak demek: oyuncu
      // aynı yaylımla tekrar ölür ve kısır bir döngüye girer.
      ship
        ..state = ShipSimState.spawn(ship.state.stats, _spawnPoint(ship.id))
        ..respawnAtTick = null
        // Girdi kuyruğu temizlenir: ölmeden önceki son hamleleri yeniden
        // oynatmak, oyuncuyu doğar doğmaz istemediği yöne sürüklerdi.
        ..pending.clear()
        ..lastApplied = ShipInput.idle;
    }
  }

  /// [accountId]'ye ait, sahipsiz bekleyen gemi. Yoksa `null`.
  ServerShip? reclaim(String accountId) {
    for (final ship in ships.values) {
      if (ship.accountId == accountId && ship.isOrphan) {
        ship
          ..orphanUntilTick = null
          ..lastInputTick = _tick
          // GİRDİ SIRASI BAĞLANTIYA AİT, GEMİYE DEĞİL.
          //
          // Sıfırlanmadığında ölçülen sonuç şuydu: oyuncu arka plandan
          // dönüyor, bağlantı kuruluyor, gemisini geri alıyor — ve gemi
          // KIMILDAMIYOR. İstemci yeni bağlantıda sırayı 1'den başlatıyor,
          // sunucu ise hâlâ kopmadan önceki sayıdan büyüğünü bekliyor, yani
          // aradaki her çerçeve `enqueue`'da sessizce düşüyor. Saniyede otuz
          // girdiyle, kopmadan önce oynanan HER SANİYE dönüşte bir saniyelik
          // felç demek: on beş dakika oynayıp arka plana alan bir oyuncu
          // dönüşünde yarım saat bekler.
          //
          // Yeniden oynatma savunması zayıflamıyor: o savunma bir OTURUM
          // içindeki tekrarları eliyor ve burası yeni bir oturum. Eski
          // çerçeveleri tekrar yollayabilen biri zaten o soketin sahibidir.
          ..acknowledgedSeq = 0
          // Kopmadan önce kuyrukta bekleyen komutlar da gider — yeniden
          // doğuşta olduğu gibi. Kopmuş bir oyuncunun son hamlesini dönüşünde
          // oynatmak, onu istemediği yöne sürüklemek olurdu.
          ..pending.clear();
        return ship;
      }
    }
    return null;
  }

  /// Oturumu koptu: gemiyi SİLME, sahipsiz işaretle.
  void orphan(ServerShip ship) =>
      ship.orphanUntilTick = _tick + orphanGraceTicks;

  /// Bekleme süresi dolmuş sahipsiz gemiler.
  List<ServerShip> expiredOrphans() => [
    for (final ship in ships.values)
      if (ship.orphanUntilTick != null && _tick >= ship.orphanUntilTick!) ship,
  ];

  /// En UZUN süredir sahipsiz bekleyen gemi. Yoksa `null`.
  ///
  /// Bekleme süresini uzatmanın bedelini ödeyen mekanizma bu: dolu bir zone'da
  /// yeni oyuncuyu reddetmek yerine, dönme ihtimali en düşük olanı (en eski
  /// sahipsiz) bırakıyoruz. Oynayan bir oyuncuyu asla etkilemez — yalnız
  /// bağlantısı KOPMUŞ olanları sıraya sokar.
  ServerShip? _oldestOrphan() {
    ServerShip? oldest;
    for (final ship in ships.values) {
      final until = ship.orphanUntilTick;
      if (until == null) continue;
      if (oldest == null || until < oldest.orphanUntilTick!) oldest = ship;
    }
    return oldest;
  }

  /// Dünyaya bir gemi kat.
  ///
  /// [stats] donatımdan çözülüyor: hangarda takılan lazer, gerçekten savaşan
  /// gemiye giriyor. Verilmezse başlangıç gövdesinin taban statları — botlar
  /// ve testler için.
  /// [konum] verilirse gemi doğuş noktasına DEĞİL oraya konur.
  ///
  /// Geçitten gelen oyuncu için: haritanın rastgele bir yerinde belirmek,
  /// geçidin karşı kenarında çıkma kuralını bozardı. [saglik] ile
  /// [kalkan] de taşınıyor — geçitten geçmek onarım olamaz, yoksa kaçış
  /// yolu bedava bir iksire dönerdi.
  ServerShip? join(
    String name, {
    String accountId = '',
    ShipStats? stats,
    Vec2? konum,
    double? saglik,
    double? kalkan,
  }) {
    if (isFull) {
      // Dolu: önce sahipsizleri tahliye et, sonra reddet.
      final evict = _oldestOrphan();
      if (evict == null) return null;
      leave(evict.id);
    }
    // Tahsis tavanı `u16` DEĞİL, bölme sınırı: [Protocol.maxShipId]. Üstündeki
    // her kimlik alien'in, ve bir gemiye verilirse istemci ikisini karıştırır
    // — gemi yanlış konuma çizilir, kimse onu hedefleyemez, ödül alamaz.
    // Üçü de sessiz.
    //
    // 0 da ayrılmış: `weaponTarget` alanında "hedef yok" demek.
    var scanned = 0;
    while (ships.containsKey(_nextId) || _nextId == 0) {
      _nextId = _nextId + 1 >= _kimlikTavani ? kimlikTabani : _nextId + 1;
      // Uzay doluysa SESSİZCE sarma — reddet. Eski döngü burada sonsuza
      // kadar dönerdi.
      if (++scanned > kimlikAraligi) return null;
    }
    final id = _nextId;
    // Sayaç tahsisten sonra İLERİ yürüyor: boşalan kimlik bir sonraki
    // katılımda hemen geri verilmiyor, yeniden kullanılması için bütün uzayın
    // dolaşılması gerekiyor.
    //
    // Sebep uçuştaki referanslar: bir oyuncu ayrıldığı anda yerine geleni
    // hedefleyen bir `weaponTarget` ya da ona ait bir `ShotEvent` hâlâ yolda
    // olabilir. Kuşak sayacı (generational index) bunu kesin çözerdi ama
    // bitleri `weaponTarget`'ın tek `u16` alanından çalmak, yani protokolü
    // kırmak gerekirdi. İleri yürüyen sayaç aynı pencereyi bedavaya kapatıyor.
    _nextId = id + 1 >= _kimlikTavani ? kimlikTabani : id + 1;
    final ship =
        ServerShip(
            id: id,
            name: name,
            state: () {
              final taze = ShipSimState.spawn(
                stats ?? ShipStats.bastion,
                konum ?? _spawnPoint(id),
              );
              if (saglik == null && kalkan == null) return taze;
              return taze.copyWith(
                hull: saglik ?? taze.hull,
                shield: kalkan ?? taze.shield,
              );
            }(),
          )
          ..accountId = accountId
          ..lastInputTick = _tick;
    ships[id] = ship;
    return ship;
  }

  void leave(int id) {
    ships.remove(id);
    // Ayrılanı herkesin görünür kümesinden de düş: kalırsa, aynı kimlik
    // yeniden kullanıldığında yeni gemi "zaten görünüyordu" sayılır ve
    // histerezis yanlış eşikle başlar.
    for (final ship in ships.values) {
      ship.visible.remove(id);
      // Kimlikler artık hemen geri dönmediği için bu iki defter kendiliğinden
      // temizlenmiyor: ileri yürüyen sayaçla her ayrılan kimlik oturum boyunca
      // ölü bir anahtar bırakırdı. Ayrılanı burada düşmek, sayacın bedeli.
      ship.lastSentTick.remove(id);
      ship.staleBaseline.remove(id);
    }
  }

  /// İstemciden gelen bir girdi çerçevesini kuyruğa al.
  ///
  /// İki savunma var ve ikisi de hile içindir:
  ///  * Eski/tekrarlanmış sıralar atılır — yeniden oynatma saldırısı.
  ///  * Kuyruk tavanı aşılırsa EN ESKİ atılır. Tavan olmasaydı istemci
  ///    girdiyi biriktirip sonra boşaltarak hızlanabilirdi; sunucunun tiki
  ///    tek saattir ve öyle kalmalı.
  void enqueue(ServerShip ship, ShipInput input) {
    if (input.seq <= ship.acknowledgedSeq) return;
    if (ship.pending.isNotEmpty && input.seq <= ship.pending.last.seq) return;
    ship.pending.add(input);
    while (ship.pending.length > maxPending) {
      ship.pending.removeFirst();
    }
    ship.lastInputTick = _tick;
  }

  /// Kuyruk derinliği tavanı ≈ 200 ms. Daha derini gecikmeyi gizlemez, yalnız
  /// girdi gecikmesi olarak hissedilir.
  static const int maxPending = 6;

  /// BİR otorite tiki. Sunucudaki tüm zamanın geçtiği tek yer.
  void step() {
    _tick++;
    // Olay listeleri EN BAŞTA temizleniyor — `_handleDeaths` ÖNCESİNDE.
    //
    // Ters sırada yazılmıştı ve ölüm olayları hiç görünmüyordu: `_handleDeaths`
    // listeye yazıyor, hemen ardından gelen `clear()` siliyordu. Tamir bedeli
    // testi bunu yakaladı — "ölüm hiçbir şeye mal olmadı".
    shots.clear();
    deaths.clear();
    _handleDeaths();
    for (final ship in ships.values) {
      // Tik başına TAM BİR girdi. Gecikeni yakalamak için iki işlemek cazip
      // ama o kapı doğrudan hız hilesine açılır: istemci girdiyi biriktirip
      // iki kat yol alırdı.
      final ShipInput input;
      if (ship.isOrphan) {
        // SAHİPSİZ gemi komut tekrarlamaz.
        //
        // Ölçüldü: kopan bir oyuncunun gemisi, seviye tetikli `firing` ve
        // `weaponTarget` korunduğu için kopmadan SONRA da ateş etmeye devam
        // ediyordu (hedefin kalkanı 60 tikte 7000 → 6000). Aynı şekilde son
        // eksen komutuyla uçmayı sürdürüyor, yani oyuncu geri döndüğünde
        // gemisini bıraktığı yerde bulamıyordu.
        //
        // Klavyeyi bırakmış bir oyuncuyla ağı kopmuş bir oyuncu aynı şey
        // değil: birinin niyeti "aynen devam", ötekinin niyeti bilinmiyor.
        // Bilinmeyen niyetin yerine geçecek tek dürüst değer boş komuttur.
        //
        // Gemi yine de dünyada ve VURULABİLİR durumda kalır — kopmak kalkan
        // olsaydı, kaybedilen her düelloda fişi çekmek bir taktik olurdu.
        ship.pending.clear();
        input = ShipInput(seq: ship.lastApplied.seq);
      } else if (ship.pending.isNotEmpty) {
        input = ship.pending.removeFirst();
        ship.acknowledgedSeq = input.seq;
      } else {
        // Tekrarda KENAR TETİKLİ alanlar temizlenir (itki, tıkla-git hedefi):
        // yoksa tek bir basış, paket gecikmesi boyunca her tikte yeniden
        // harcanırdı.
        //
        // SEVİYE TETİKLİ alanlar ise KORUNUR — eksen, silah kilidi ve ateş.
        // Onları da temizlemek, tek bir geciken pakette ateşin kesilmesi
        // demekti: oyuncu tuşu bırakmadığı hâlde ışın titrerdi.
        input = ShipInput(
          seq: ship.lastApplied.seq,
          axis: ship.lastApplied.axis,
          weaponTarget: ship.lastApplied.weaponTarget,
          firing: ship.lastApplied.firing,
        );
      }
      ship.lastApplied = input;
      ship.state = ShipSim.step(ship.state, input, world);
    }
    // Silahlar HERKES hareket ettikten SONRA çözülür.
    _resolveWeapons();

    // Alien'ler en son: hedeflerini gemiler hareket ETTİKTEN sonra görsünler,
    // yoksa bir tik gerideki konuma ateş ederlerdi.
    _stepAliens();
  }

  /// Alien'lerin bir tiki: hedef seç, kovala, ateş et.
  ///
  /// **Hedef seçimi burada, `AlienSim`'de değil.** Çekirdek paket gemileri
  /// görmüyor ve görmemeli — aynı kod istemcide de koşuyor ve orada `ships`
  /// diye bir şey yok. `AlienSim` kararın SONUCUNU (hedef kimliği, kin
  /// süresi) taşıyor; kararı otorite veriyor.
  void _stepAliens() {
    for (final entry in aliens.entries) {
      var alien = entry.value;
      if (!alien.alive) {
        final before = alien;
        aliens[entry.key] = AlienSim.step(alien, world, ShipSim.fixedDt, _tick);
        // Yeniden doğan alien TEMİZ bir tabloyla geliyor: önceki kavganın
        // borcu yeni alienin değil.
        if (aliens[entry.key]!.alive && !before.alive) {
          _threat[entry.key]?.clear();
        }
        continue;
      }
      // Tehdit her tik SÖNÜYOR — "kaçmak işe yarar" kuralının tablo
      // tarafındaki karşılığı.
      _threat[entry.key]?.decay(ShipSim.fixedDt);

      final (foe, renew) = _alienTargetFor(entry.key, alien);

      // Hedef adımdan ÖNCE yazılıyor ve kin YALNIZ tazelenmesi gerekiyorsa
      // tazeleniyor.
      //
      // İlk yazışta bu sıra tersti ve kin hiç sönmüyordu: `step` süresi dolan
      // hedefi bırakıyor, hemen ardından gelen "hedefi yaz" satırı onu geri
      // koyuyordu. Yani her tik kin baştan doluyordu ve kaçmak işe
      // yaramıyordu — testin yakaladığı tam olarak bu.
      if (foe != null && renew) {
        alien = alien.copyWith(
          targetId: foe.id,
          aggroFor: AlienSim.aggroDuration,
        );
      }

      alien = AlienSim.step(
        alien,
        world,
        ShipSim.fixedDt,
        _tick,
        chase: foe?.state.position,
      );

      if (foe != null) alien = _alienFire(entry.key, alien, foe);
      aliens[entry.key] = alien;
    }
  }

  /// Bu alien'in saldıracağı gemi — yoksa `null`.
  ///
  /// İki yol var ve ikisi de tür kimliğinin parçası:
  ///
  ///  * **Kışkırtılmış** ([AlienSimState.hunting]): vuran gemiyi kovalar.
  ///    Pasif türü (Void Spore) savaşa sokan tek yol bu.
  ///  * **Saldırgan** ([AlienStats.aggroRange] > 0): menziline gireni kendisi
  ///    seçer.
  ///
  /// Kışkırtılmışlık önce geliyor: seni vuran alien, yanından geçen başka bir
  /// oyuncuya dönmemeli — yoksa vur-kaç saldırısının bedeli başkasına çıkar.
  /// Dönen ikinci değer: kin TAZELENMELİ mi.
  ///
  /// Ayrım kritik. Kışkırtılmış bir alien hedefini tutar ama kini SÖNMEYE
  /// devam eder — kaçmanın işe yaraması buna bağlı. Saldırgan bir alien ise
  /// menzilinde biri durdukça kinini tazeler; oradan çıkınca sönmeye başlar.
  (ServerShip?, bool) _alienTargetFor(int alienId, AlienSimState alien) {
    // TEHDİT TABLOSU önce: en çok hasar veren hedef olur.
    //
    // Önceki hâl "en son vuran"dı ve alienler saldıranlar arasında gidip
    // geliyordu — kin yönetimi diye bir oyun katmanı kurulamıyordu. Tablo
    // aynı zamanda ödülün payını da veriyor; ikisi tek sayıdan türüyor.
    final table = _threat[alienId];
    if (table != null && !table.isEmpty) {
      final top = table.top((id) => ships[id]?.state.alive ?? false);
      if (top != null) return (ships[top]!, false);
    }
    if (alien.hunting) {
      final held = ships[alien.targetId];
      // Hedef ölmüş ya da ayrılmışsa kin düşer; kaçmışsa DÜŞMEZ, çünkü
      // kovalamanın anlamı o. Tazeleme YOK: süre işlemeye devam etsin.
      if (held != null && held.state.alive) return (held, false);
    }

    final aggro = alien.stats.aggroRange;
    if (aggro <= 0) return (null, false);

    ServerShip? best;
    var bestDistance = aggro * aggro;
    for (final ship in ships.values) {
      if (!ship.state.alive) continue;
      final d = ship.state.position.distanceSquaredTo(alien.position);
      if (d < bestDistance) {
        bestDistance = d;
        best = ship;
      }
    }
    return (best, best != null);
  }

  /// Namlusu dolu ve menzilde bir hedefi olan alien ateş eder.
  AlienSimState _alienFire(int id, AlienSimState alien, ServerShip foe) {
    if (alien.fireCooldown > 0) return alien;
    final range = alien.stats.range;
    if (foe.state.position.distanceSquaredTo(alien.position) > range * range) {
      return alien;
    }

    final before = foe.state;

    // Alien hasarı da AYNI zincirden geçiyor. Ayrı bir yol açmak, düşman
    // hasarının oyuncunun zırhını görmezden gelmesi demekti — ve savunma
    // statları PvE'de ölü stata dönerdi.
    //
    // Kritik YOK: kritik bir saldırı statı ve alienlerin stat kütüphanesi
    // (alan 12) henüz yazılmadı. Katman zincirde duruyor, şans sıfır.
    final hit = DamageChain.resolve(
      baseDamage: alien.stats.damage,
      critMode: CritMode.rolled,
      armorReduction: foe.state.stats.armorReduction,
      graze: foe.state.stats.graze,
    );

    foe.state = ShipSim.applyDamage(before, hit.amount);
    shots.add(
      ShotEvent(
        shooterId: id,
        targetId: foe.id,
        damage: hit.amount.round(),
        shieldHit: before.shield > 0,
        killed: before.alive && !foe.state.alive,
        grazed: hit.grazed,
      ),
    );
    return alien.copyWith(fireCooldown: alien.stats.fireInterval);
  }

  /// Bir tikin silah çözümü.
  ///
  /// **Neden `ShipSim.step` içinde değil:** bir atış iki gemi arasındaki
  /// ETKİLEŞİM, `step` ise tek gemiyi izole işleyen saf bir fonksiyon. Menzili
  /// orada hesaplamak, saf adımın diğer gemileri görmesini gerektirirdi ve
  /// determinizm biterdi.
  ///
  /// **Neden hareketten sonra:** aynı tikte hareket eden iki gemi arasında
  /// sıra bağımlılığı olmasın. Hasar hareketle iç içe uygulansaydı, `ships`
  /// haritasında önce gelen gemi hedefinin ESKİ konumuna ateş ederdi.
  ///
  /// **Sunucu istemciye güvenmez.** İstemci yalnız NİYET yollar (kime, ateş
  /// açık mı); kimliğin geçerliliği, hedefin yaşadığı, menzil ve atış hızı
  /// burada doğrulanır. Aksi hâlde tek bir düzenlenmiş istemci menzilsiz ve
  /// bekleme süresiz ateş ederdi.
  void _resolveWeapons() {
    for (final shooter in ships.values) {
      shooter.fireCooldown = math.max(
        0,
        shooter.fireCooldown - ShipSim.fixedDt,
      );
      shooter.roketBeklemesi = math.max(
        0,
        shooter.roketBeklemesi - ShipSim.fixedDt,
      );

      var state = shooter.state;
      if (state.weaponTarget == 0) {
        // Kilit yok: yönelim serbest kalsın, yoksa gemi son hedefinin
        // bulunduğu boşluğa bakmaya devam eder.
        if (state.aimPoint != null) {
          shooter.state = state.copyWith(clearAim: true);
        }
        continue;
      }

      // Hedef ya bir gemi ya bir alien; hangisi olduğunu KİMLİK ARALIĞI
      // söylüyor. Ayrı bir tür alanı her girdi çerçevesine bir bayt yazardı.
      final targetId = state.weaponTarget;
      final Vec2? targetAt;
      if (Protocol.isAlienId(targetId)) {
        final alien = aliens[targetId];
        targetAt = alien != null && alien.alive ? alien.position : null;
      } else {
        final ship = ships[targetId];
        // Kendine ateş YOK: geçerli bir kimlik ama geçersiz bir hedef.
        targetAt = ship == null || ship.id == shooter.id || !ship.state.alive
            ? null
            : ship.state.position;
      }

      if (targetAt == null) {
        // Kilit DÜŞER: hedef yok, kendisi ya da ölü. Bunu duruma yazmak
        // önemli — `SelfSnapshot` onu taşıdığı için istemci de seçimini
        // bırakır ve boşluğa mermi göndermez.
        shooter.state = state.copyWith(
          weaponTarget: 0,
          firing: false,
          clearAim: true,
        );
        continue;
      }

      // NİŞAN, ateşten bağımsız. Kilitli bir hedef varsa gemi ona döner —
      // menzil dışında da, ateş kapalıyken de. Bu bir görsel tercih değil:
      // namlular gövdenin üstünde duruyor ve başka yöne bakan bir gemiden
      // çıkan mermi silahtan değil boşluktan geliyormuş gibi görünür.
      //
      // Nokta SUNUCUDAN geliyor. İstemcinin kendi bildiği hedef konumuyla
      // dönmesi daha çevik olurdu ve her snapshot'ta açı düzeltmesi
      // doğururdu — mutabakatın en görünür kırıldığı yer gövdenin yönüdür.
      state = state.copyWith(aimPoint: targetAt);
      shooter.state = state;

      if (!state.firing) continue;

      final range = state.stats.laser.range;
      if (targetAt.distanceSquaredTo(state.position) > range * range) {
        // Menzil dışı: kilit DURUR (hedef geri girebilir) ama ateş kesilir.
        shooter.state = state.copyWith(firing: false);
        continue;
      }

      // NİŞAN ALMADAN ATEŞ YOK.
      //
      // Ateş uzun süre yalnız MENZİLE bakıyordu; gemi hedefe dönerken de
      // atıyordu. Mobilde otomatik ateşle bariz: hedefi seçtiğin an, gemi
      // daha yönünü değiştirmeden mermi çıkıyor — ve yaratık tek atışta
      // öldüğü için dönüş hiç tamamlanmıyor, yani gemi ateş ederken hiçbir
      // zaman hedefe bakmıyor.
      //
      // Bu, nişanın kendi gerekçesinin yarım kalmış hâli: `ShipSim` "namlular
      // gövdenin üstünde, başka yöne bakan gemiden çıkan mermi silahtan değil
      // boşluktan geliyormuş gibi görünür" diyor ve gemiyi hedefe döndürüyor.
      // Dönüşü beklemeyen bir ateş, o cümleyi uygulamıyor.
      //
      // YAY DÖNÜŞ HIZINDAN TÜRÜYOR, elle konmuş bir derece değil. Bir tikte
      // dönülen açı `turnRate × fixedDt`; yay bunun bir buçuk katı. Daha dar
      // bir yay ulaşılamaz olurdu — gemi tek tikte yayın üstünden atlayıp
      // hiç ateş edemezdi. Daha genişi, düzeltmeye çalıştığımız görüntüyü
      // geri getirir.
      // ÜSTÜNDE DURDUĞUN HEDEFTE YAY YOK.
      //
      // `ShipSim` bir birimden yakın hedefe DÖNMÜYOR: sıfıra yakın bir
      // vektörün açısı gürültüdür ve gemiyi titretir. Yay o durumu da
      // sınasaydı kilitlenme doğardı — gemi dönmüyor, yay geçmiyor, hiç ateş
      // edilmiyor. Testler bunu yakaladı: boss'un üstüne konan gemi hiç
      // vurmadı.
      final fark = targetAt - state.position;
      final hedefeAci = math.atan2(fark.x, -fark.y);
      final sapma = ShipSim.normalizeAngle(hedefeAci - state.angle).abs();
      if (fark.length > ShipSim.nisanEsigi && sapma > _nisanYayi) {
        // Kilit ve nişan DURUYOR: gemi dönmeye devam ediyor, yalnız bu tikte
        // mermi çıkmıyor. `firing` de duruyor — oyuncu hâlâ ateş istiyor ve
        // dönüş bitince kendiliğinden başlamalı.
        continue;
      }

      // ROKET (18): lazerin beklemesinden bağımsız, aynı hedefe, aynı
      // menzil. Salvo hedefi öldürdüyse bu tik lazer ölüyü vurmaz.
      if (_roketAt(shooter, state, targetId)) continue;

      if (shooter.fireCooldown > 0) continue;
      shooter.fireCooldown = state.stats.laser.fireInterval;

      // ── Hasar zinciri ────────────────────────────────────────────────
      //
      // Yaylım: TAKILI namluların hepsi birden ateşler (L0). Kritik zarı
      // burada atılıyor — atıcının PRD sayacından, bağımsız değil.
      //
      // Savunma hedeften okunuyor (L4) ve PvP katsayısı yalnız oyuncuya karşı
      // uygulanıyor. İki formül DEĞİL: aynı zincirin sonunda tek bir çarpan.
      final againstPlayer = !Protocol.isAlienId(targetId);
      final alienTarget = againstPlayer ? null : aliens[targetId]!;
      final shipTarget = againstPlayer ? ships[targetId]! : null;

      final armorReduction = againstPlayer
          ? shipTarget!.state.stats.armorReduction
          : SavunmaEgrileri.doyum(alienTarget!.stats.armor, Turetilenler.kZirh);
      final graze = againstPlayer
          ? shipTarget!.state.stats.graze
          : SavunmaEgrileri.siyirma(
              alienTarget!.stats.evasion,
              Turetilenler.kSiyirma,
            );
      // Hedef oyuncuysa PvP katsayısı, yaratığa karşı 1. KARAR 01.7 s1
      final pvpMultiplier = againstPlayer ? TasarimGirdileri.pvpCarpani : 1.0;

      final hit = DamageChain.resolve(
        // Mermi YALNIZ taban hasarı çarpıyor (L0): oran bonusları, kritik ve
        // son hasar mermiden etkilenmiyor, droidin zinciri hiç görmüyor.
        // KARAR 17.3 s1
        baseDamage: state.stats.baseVolleyDamage * shooter.mermiCarpani,
        damageBonus: state.stats.damageBonus,
        conditionalBonus: state.stats.conditionalBonus,
        critChance: state.stats.critChance,
        critMultiplier: state.stats.critMultiplier,
        critMode: CritMode.rolled,
        critRoll: shooter.rollCrit(state.stats.critChance, _dice),
        armorReduction: armorReduction,
        graze: graze,
        flatDamage: state.stats.flatDamage,
        pvpMultiplier: pvpMultiplier,
      );

      // Droid grubu aynı hedefe KENDİ zinciriyle (05.1, 09.6): σ ile bağlı
      // çarpanlar, beklenen kritik. Yaylımı geminin vuruşuna ekleniyor ve
      // geminin atış ritmine ölçekleniyor — droidin kendi aralığı farklıysa
      // saniyelik hasar yine doğru. Ayrı mermi olayı yok (borç defteri B17).
      final droidler = state.stats.droidler;
      final droidHasari = droidler.var_
          ? DamageChain.resolve(
                  baseDamage: droidler.tabanHasar,
                  damageBonus: droidler.damageBonus,
                  critChance: droidler.critChance,
                  critMultiplier: droidler.critMultiplier,
                  armorReduction: armorReduction,
                  graze: graze,
                  pvpMultiplier: pvpMultiplier,
                ).amount *
                droidler.ayaktaKalma *
                (state.stats.laser.fireInterval / droidler.atisAraligi)
          : 0.0;
      final gemiHasari = hit.amount;
      final damage = gemiHasari + droidHasari;

      final bool shieldHit;
      final bool killed;
      // İNEN hasar: sifonda geminin payı yalnız kalkana, kalkanı aşan yok
      // olur; olay ekrana ineni söylüyor, hesaplananı değil.
      final double inen;
      if (alienTarget != null) {
        // Alien'in kalkanı YOK: sifon geminin payını hiç indirmez, yalnız
        // droidlerinki iner. KARAR 17.6 s1
        inen = shooter.sifon ? droidHasari : damage;
        // Vuranın kimliği geçiyor: pasif bir alien ancak böyle uyanıyor.
        final after = AlienSim.applyDamage(
          alienTarget,
          inen,
          attacker: shooter.id,
        );
        // Tehdit ve hasar payı AYNI kayıttan: kimi kovalayacağı ve ödülü
        // kimin alacağı tek bir sayıdan türüyor.
        threatOf(targetId).add(shooter.id, inen);
        aliens[targetId] = after;
        // Bütün hasar gövdeye iner, ve ekrandaki sayı kehribar çıkar —
        // oyuncu neyin eridiğini renkten okur.
        shieldHit = false;
        killed = alienTarget.alive && !after.alive;
      } else {
        final target = shipTarget!;
        final before = target.state;
        if (shooter.sifon) {
          // Sifon KALKANA vurur, gövdeye taşmaz; droidler kendi mermisiz
          // zinciriyle her yere. KARAR 17.6 s1
          final kalkanaInen = gemiHasari < before.shield
              ? gemiHasari
              : before.shield;
          target.state = ShipSim.applyDamage(
            ShipSim.applyShieldDamage(before, gemiHasari),
            droidHasari,
          );
          inen = kalkanaInen + droidHasari;
        } else {
          target.state = ShipSim.applyDamage(before, damage);
          inen = damage;
        }
        shieldHit = before.shield > 0;
        killed = before.alive && !target.state.alive;
      }

      // Olay VURUŞTAN sonra üretilir ve hasarı SUNUCU söyler. İstemci kendi
      // statlarından hesaplasaydı zar iki kez atılırdı: kritik ekranda var,
      // hasarda yok olurdu. Kritik ve sıyırma bayrakları da bu yüzden telde —
      // rakamın rengi ile inen hasar tek kaynaktan geliyor.
      shots.add(
        ShotEvent(
          shooterId: shooter.id,
          targetId: targetId,
          damage: inen.round(),
          shieldHit: shieldHit,
          killed: killed,
          crit: hit.crit,
          grazed: hit.grazed,
        ),
      );
    }
  }

  /// Roket salvosu: hedef menzilde ve bekleme dolduysa bir kez vurur (18.2).
  ///
  /// Zincir geminin — bonus, kritik, hedefin savunması, PvP katsayısı —
  /// yalnız taban roketin (salvo tabanı × roket mermisinin çarpanı). Sifon
  /// yok: roket kalkanı aşınca gövdeye geçer, lazer gibi. Ayrı atış olayı:
  /// istemci roketi ayrı çizer (18.6). Öldürdüyse `true`.
  /// KARAR 18.2 s1 · KARAR 18.6 s1
  bool _roketAt(ServerShip shooter, ShipSimState state, int targetId) {
    final taban = state.stats.roketHasari;
    if (taban <= 0 || shooter.roketBeklemesi > 0) return false;
    shooter.roketBeklemesi = TasarimGirdileri.roketAraligi;

    final againstPlayer = !Protocol.isAlienId(targetId);
    final alienTarget = againstPlayer ? null : aliens[targetId];
    final shipTarget = againstPlayer ? ships[targetId] : null;
    if (alienTarget == null && shipTarget == null) return false;

    final armorReduction = againstPlayer
        ? shipTarget!.state.stats.armorReduction
        : SavunmaEgrileri.doyum(alienTarget!.stats.armor, Turetilenler.kZirh);
    final graze = againstPlayer
        ? shipTarget!.state.stats.graze
        : SavunmaEgrileri.siyirma(
            alienTarget!.stats.evasion,
            Turetilenler.kSiyirma,
          );
    final pvpMultiplier = againstPlayer ? TasarimGirdileri.pvpCarpani : 1.0;
    final hit = DamageChain.resolve(
      // Roket mermisi yalnız salvonun tabanını çarpar (17.3'ün kuralı, 18.3).
      baseDamage: taban * shooter.roketCarpani,
      damageBonus: state.stats.damageBonus,
      conditionalBonus: state.stats.conditionalBonus,
      critChance: state.stats.critChance,
      critMultiplier: state.stats.critMultiplier,
      critMode: CritMode.rolled,
      critRoll: shooter.rollCrit(state.stats.critChance, _dice),
      armorReduction: armorReduction,
      graze: graze,
      flatDamage: state.stats.flatDamage,
      pvpMultiplier: pvpMultiplier,
    );
    final damage = hit.amount;
    final bool shieldHit;
    final bool killed;
    if (alienTarget != null) {
      final after = AlienSim.applyDamage(
        alienTarget,
        damage,
        attacker: shooter.id,
      );
      threatOf(targetId).add(shooter.id, damage);
      aliens[targetId] = after;
      shieldHit = false;
      killed = alienTarget.alive && !after.alive;
    } else {
      final target = shipTarget!;
      final before = target.state;
      target.state = ShipSim.applyDamage(before, damage);
      shieldHit = before.shield > 0;
      killed = before.alive && !target.state.alive;
    }
    shots.add(
      ShotEvent(
        shooterId: shooter.id,
        targetId: targetId,
        damage: damage.round(),
        shieldHit: shieldHit,
        killed: killed,
        crit: hit.crit,
        grazed: hit.grazed,
        roket: true,
      ),
    );
    return killed;
  }

  /// Kare başına yeniden kullanılan seçim tamponu.
  ///
  /// Snapshot saniyede 30 kez, oyuncu başına üretiliyor. Her seferinde yeni
  /// bir liste ayırmak 41 oyuncuda saniyede binlerce kısa ömürlü nesne demek
  /// — ve Dart'ın çöp toplayıcısı duraklattığında duraklattığı şey otorite
  /// döngüsünün kendisi.
  final List<ServerShip> _visibleScratch = [];

  /// [viewer]'ın GÖRMESİ GEREKEN gemiler.
  ///
  /// Bant genişliği ikincil sebep — asıl sebep hile. Tüm haritayı gönderen bir
  /// sunucu, radarda herkesi gören bir istemci yazmayı mümkün kılar. Görmediğin
  /// şey sızdırılamaz.
  ///
  /// **Histerezis:** giriş ve çıkış eşikleri farklı. Tek eşikle, sınırda
  /// seyreden bir gemi saniyede onlarca kez snapshot'a girip çıkıyor ve
  /// istemci onun bileşenini durmadan kurup yıkıyordu.
  ///
  /// Son [collectVisible] çağrısında YENİ görünür olanların bayrakları.
  ///
  /// Delta bunu bilmek zorunda: ilgi alanına yeni giren bir entity için
  /// istemcinin temeli yok, tam kayıt gitmeli. Ayrı bir küme tutmak yerine
  /// tarama sırasında zaten hesaplanan `wasVisible` bilgisini dışarı vermek
  /// hem bedava hem de iki verinin ayrışmasını imkânsız kılıyor.
  final List<bool> _freshScratch = [];

  List<bool> get lastVisibleFresh => _freshScratch;

  /// Dönen liste YENİDEN KULLANILIYOR: bir sonraki çağrıya kadar geçerli.
  ///
  /// **Neden hâlâ O(n²) ve neden uzamsal ızgara YOK.**
  ///
  /// Izgara (九宫格) düşünüldü ve ÖLÇÜLEREK elendi. Doğruluk şartı, hücre
  /// boyunun çıkış yarıçapından (2989) küçük olmaması: aksi hâlde 3×3
  /// komşuluk ilgi alanının tamamını kapsamaz ve gemiler sınırda kaybolur.
  /// 12000×8000'lik dünyada bu, yalnız **5×3 = 15 hücre** demek ve bir 3×3
  /// komşuluk dünyanın **%75'ini** kaplıyor.
  ///
  /// Yani ızgara taramanın en fazla dörtte birini eleyebilir. Ölçülen maliyet
  /// 400 gemide 1426 µs (bütçenin %4.3'ü), 200'de 328 µs — dörtte birini
  /// kurtarmak bütçenin ~%1'i eder. Bu karmaşıklığa değmez.
  ///
  /// Sebep geometrik: 九宫格 deseni ilgi yarıçapı dünyaya göre KÜÇÜKKEN
  /// kazandırıyor. Bizde ilgi alanı dünyanın %22'si. Izgara ancak şu üç
  /// durumdan biri olursa anlamlı hâle gelir — o gün bu imza aynı kalır:
  ///  * harita büyürse (ilgi alanı oransal olarak küçülür),
  ///  * ilgi yarıçapı düşerse,
  ///  * entity sayısı mermi/enkaz gibi şeylerle birkaç bine çıkarsa.
  List<ServerShip> collectVisible(ServerShip viewer) {
    const enter = Protocol.interestRadius * Protocol.interestRadius;
    const exit = Protocol.interestExitRadius * Protocol.interestExitRadius;

    _visibleScratch.clear();
    _freshScratch.clear();
    for (final other in ships.values) {
      if (other.id == viewer.id) continue;
      final d2 = other.state.position.distanceSquaredTo(viewer.state.position);
      final wasVisible = viewer.visible.contains(other.id);
      final isVisible = wasVisible ? d2 <= exit : d2 <= enter;

      if (isVisible) {
        if (!wasVisible) viewer.visible.add(other.id);
        _visibleScratch.add(other);
        _freshScratch.add(!wasVisible);
      } else if (wasVisible) {
        viewer.visible.remove(other.id);
      }
    }
    return _visibleScratch;
  }

  /// Alien'lerin ÖNCEKİ ve ŞU ANKİ kuantalanmış değerleri.
  ///
  /// Gemilerde bu alanlar `ServerShip` üstünde duruyor; alien'ler değişmez
  /// (`AlienSimState`) ve her tik yenisiyle değiştiriliyor, o yüzden kimliğe
  /// göre ayrı haritalarda. Kimlikler kuruluşta sabitlendiği için harita
  /// büyümüyor.
  final Map<int, Int32List> _alienWire = {};
  final Map<int, Int32List> _alienWireNow = {};
  final Set<int> _alienWireValid = {};

  /// [id]'nin bu tikteki kuantalanmış değerleri.
  Int32List alienWireNow(int id) =>
      _alienWireNow[id] ??= Int32List(AlienDelta.fields);

  /// [id]'nin ÖNCEKİ tikteki değerleri — delta'nın temeli.
  Int32List alienWire(int id) =>
      _alienWire[id] ??= Int32List(AlienDelta.fields);

  /// [id] için gerçek bir geçmiş var mı.
  bool alienWireValid(int id) => _alienWireValid.contains(id);

  /// Bütün gemilerin ve alien'lerin BU tikteki kuantalanmış değerlerini
  /// hesapla.
  ///
  /// Tik başına BİR kez: değer izleyiciden bağımsız. İzleyici başına
  /// kuantalamak 200 gemide tik başına on binlerce gereksiz dönüşüm ederdi.
  void refreshWire() {
    for (final ship in ships.values) {
      EntityDelta.quantize(ship.wireNow, ship.state, world.width, world.height);
      ship.wireMask = ship.wireValid
          ? EntityDelta.maskOf(ship.wireNow, ship.wire)
          : EntityDelta.full;
    }
    for (final entry in aliens.entries) {
      final alien = entry.value;
      AlienDelta.quantize(
        alienWireNow(entry.key),
        alien.stats.kind,
        alien.position.x,
        alien.position.y,
        alien.hullFraction,
        world.width,
        world.height,
      );
      _alienMask[entry.key] = alienWireValid(entry.key)
          ? AlienDelta.maskOf(alienWireNow(entry.key), alienWire(entry.key))
          : AlienDelta.full;
    }
  }

  /// Alien kimliği → bu tikin delta maskesi. Bkz. [ServerShip.wireMask].
  final Map<int, int> _alienMask = {};

  int alienMask(int id) => _alienMask[id] ?? AlienDelta.full;

  /// Bu tikin değerlerini temel yap — snapshot'lar gönderildikten SONRA.
  void promoteWire() {
    for (final ship in ships.values) {
      ship.promoteWire();
    }
    for (final id in aliens.keys) {
      final previous = alienWire(id);
      _alienWire[id] = alienWireNow(id);
      _alienWireNow[id] = previous;
      _alienWireValid.add(id);
    }
  }

  /// Kare başına yeniden kullanılan alien seçim tamponu.
  final List<int> _alienScratch = [];

  /// [viewer]'ın GÖRMESİ GEREKEN alien'ler (kimlik listesi).
  ///
  /// Gemilerle aynı histerezis: tek eşikle sınırda dolaşan bir alien saniyede
  /// onlarca kez görünüp kayboluyor ve istemcinin ara değer tamponu her
  /// seferinde sıfırlanıyor — ekranda ışınlanan bir sürü.
  /// Son [collectVisibleAliens] çağrısında YENİ görünenlerin bayrakları —
  /// gemilerdeki [lastVisibleFresh] ile aynı gerekçe.
  final List<bool> _alienFreshScratch = [];

  List<bool> get lastVisibleAliensFresh => _alienFreshScratch;

  List<int> collectVisibleAliens(ServerShip viewer) {
    const enter = Protocol.interestRadius * Protocol.interestRadius;
    const exit = Protocol.interestExitRadius * Protocol.interestExitRadius;

    _alienScratch.clear();
    _alienFreshScratch.clear();
    for (final entry in aliens.entries) {
      // Ölü alien GÖNDERİLMEZ: enkaz diye bir şey yok, yeniden doğana kadar
      // haritada yoktur. İstemcinin izi de bayatlayıp düşer.
      if (!entry.value.alive) {
        viewer.visibleAliens.remove(entry.key);
        continue;
      }
      final d2 = entry.value.position.distanceSquaredTo(viewer.state.position);
      final wasVisible = viewer.visibleAliens.contains(entry.key);
      final isVisible = wasVisible ? d2 <= exit : d2 <= enter;

      if (isVisible) {
        if (!wasVisible) viewer.visibleAliens.add(entry.key);
        _alienScratch.add(entry.key);
        _alienFreshScratch.add(!wasVisible);
      } else if (wasVisible) {
        viewer.visibleAliens.remove(entry.key);
      }
    }
    return _alienScratch;
  }

  /// Nesne üreten sürüm — testler ve teşhis için.
  List<EntitySnapshot> visibleTo(ServerShip viewer) => [
    for (final ship in collectVisible(viewer))
      EntitySnapshot.fromSim(ship.id, ship.state),
  ];

  /// Girdisi kesilmiş oturumlar. Bağlantı kopuşu her zaman soket hatası
  /// üretmez — sessizce ölen istemciyi yalnız bu yakalar.
  List<ServerShip> timedOut() {
    final limit = (Protocol.sessionTimeout * Protocol.tickRate).round();
    return [
      for (final s in ships.values)
        // Sahipsiz gemiler BURADA sayılmaz: onların kendi bekleme süresi var
        // ve girdi göndermemeleri kopukluğun sebebi değil sonucu.
        if (!s.isOrphan && _tick - s.lastInputTick > limit) s,
    ];
  }
}
