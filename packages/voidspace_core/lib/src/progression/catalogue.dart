import 'currency.dart';
import 'ganimet.dart';
import 'hull.dart';
import 'malzeme.dart';
import 'saglayici.dart';
import 'item.dart';
import 'kazanc.dart';
import 'stat.dart';

/// Oyundaki bütün eşya tasarımları ve fiyatları.
///
/// Tek kayıt: mağaza da hangar da sunucu da buradan okuyor. İki ayrı liste
/// tutmak, mağazada satılan bir eşyanın hangarda tanınmaması demekti.
/// KARAR 06.8 s2 — havuzlar yedili, yuvanın kanalı + sistem statları.
abstract final class Catalogue {
  // ── Lazerler ────────────────────────────────────────────────────────
  // Ana stat TABAN HASAR ve belirlenimci: hangi lazeri aldığını bilirsin.
  /// KARAR 06.7 s1 — havuzlar yuva tipine göre.
  static const pl1 = ItemSpec(
    id: 'pl1',
    name: 'PL-1',
    slot: SlotType.laser,
    tier: ItemTier.cI,
    mainStat: 'taban_hasar',
    subStatPool: [
      'hasar_artisi',
      'atis_hizi',
      'kritik_sansi',
      'kritik_hasari',
      'son_hasar',
      'menzil',
      'hiz',
    ],
  );

  static const pl3 = ItemSpec(
    id: 'pl3',
    name: 'PL-3',
    slot: SlotType.laser,
    tier: ItemTier.cII,
    mainStat: 'taban_hasar',
    subStatPool: [
      'hasar_artisi',
      'atis_hizi',
      'kritik_sansi',
      'kritik_hasari',
      'son_hasar',
      'menzil',
      'hiz',
    ],
  );

  static const pl4 = ItemSpec(
    id: 'pl4',
    name: 'PL-4',
    slot: SlotType.laser,
    tier: ItemTier.cIII,
    mainStat: 'taban_hasar',
    subStatPool: [
      'hasar_artisi',
      'atis_hizi',
      'kritik_sansi',
      'kritik_hasari',
      'son_hasar',
      'menzil',
      'hiz',
    ],
  );

  // ── Jeneratörler ────────────────────────────────────────────────────
  // Aynı yuvaya KALKAN ya da HIZ. Donatımın en iyi kararı: ekleme değil
  // TAKAS üretiyor, ve takas sayıdan çok daha zengin bir karar.
  static const df1 = ItemSpec(
    id: 'df1',
    name: 'DF-1 Kalkan',
    slot: SlotType.generator,
    tier: ItemTier.cI,
    mainStat: 'kalkan',
    variant: 'kalkan',
    subStatPool: [
      'govde_cani',
      'kalkan_yenilenmesi',
      'zirh',
      'kacinma',
      'son_azaltma',
      'menzil',
      'hiz',
    ],
  );

  static const df3 = ItemSpec(
    id: 'df3',
    name: 'DF-3 Kalkan',
    slot: SlotType.generator,
    tier: ItemTier.cII,
    mainStat: 'kalkan',
    variant: 'kalkan',
    subStatPool: [
      'govde_cani',
      'kalkan_yenilenmesi',
      'zirh',
      'kacinma',
      'son_azaltma',
      'menzil',
      'hiz',
    ],
  );

  /// KARAR 04.4 s1 — hız jeneratörü kaçınma da verir: havuzunda `kacinma`.
  static const th1 = ItemSpec(
    id: 'th1',
    name: 'TH-1 İtki',
    slot: SlotType.generator,
    tier: ItemTier.cI,
    mainStat: 'hiz',
    variant: 'hiz',
    subStatPool: [
      'kalkan',
      'govde_cani',
      'kalkan_yenilenmesi',
      'zirh',
      'kacinma',
      'son_azaltma',
      'menzil',
    ],
  );

  /// KARAR 04.4 s1
  static const th3 = ItemSpec(
    id: 'th3',
    name: 'TH-3 İtki',
    slot: SlotType.generator,
    tier: ItemTier.cII,
    mainStat: 'hiz',
    variant: 'hiz',
    subStatPool: [
      'kalkan',
      'govde_cani',
      'kalkan_yenilenmesi',
      'zirh',
      'kacinma',
      'son_azaltma',
      'menzil',
    ],
  );

  // ── Roketatar ───────────────────────────────────────────────────────
  // Tek yuva, bilinçli olarak DAR bant: katkısı büyürse tek eşya oyunu
  // belirler.
  static const mk1 = ItemSpec(
    id: 'mk1',
    name: 'MK-1 Fırlatıcı',
    slot: SlotType.launcher,
    tier: ItemTier.cI,
    // Roketatar bir SİLAH (18.1): ana statı taban hasar, roket kapsamına
    // yazılır ve salvonun tabanı olur. Bir zamanlar hasar artışı veren bir
    // stat eşyasıydı (B20); payı aynı, biçimi değişti.
    mainStat: 'taban_hasar',
    subStatPool: [
      'atis_hizi',
      'kritik_sansi',
      'kritik_hasari',
      'son_hasar',
      'menzil',
      'hiz',
    ],
  );

  // ── CPU ─────────────────────────────────────────────────────────────
  // Fayda yuvası. Çoğu oyunda ölü yuvadır; canlı tutmanın tek yolu ona
  // ÖLÇÜLEBİLİR şeyler koymak.
  static const cpuRepair = ItemSpec(
    id: 'cpu_repair',
    name: 'Tamir Devresi',
    slot: SlotType.cpu,
    tier: ItemTier.cI,
    mainStat: 'kalkan_yenilenmesi',
    subStatPool: [
      'govde_cani',
      'kalkan',
      'zirh',
      'kacinma',
      'son_azaltma',
      'menzil',
      'hiz',
    ],
  );

  static const cpuScope = ItemSpec(
    id: 'cpu_scope',
    name: 'Nişan Devresi',
    slot: SlotType.cpu,
    tier: ItemTier.cI,
    mainStat: 'menzil',
    subStatPool: [
      'atis_hizi',
      'kritik_sansi',
      'hiz',
      'zirh',
      'kacinma',
      'son_azaltma',
      'kalkan_yenilenmesi',
    ],
  );

  // ── Droid ───────────────────────────────────────────────────────────
  // Droid yuvasına droidin KENDİSİ takılıyor: eşyanın bütçesi çarpanlara ve
  // havuza gidiyor, taban hasar ve havuz türetilen (05.5). Ana stat hasar
  // artışı: droidin silah kalitesi. Havuz altı — droid kapsamına yazabilen
  // stat yedi ve biri ana stat (02.7).
  //
  // İKİ ÇEŞİT, on tasarım (05.8 s2): Delta krediyle alınır ve kredi rafının
  // droididir; Hilal NOVA rafında ve bir kademe üstte. Aradaki dört model
  // (Vane, Corona, Taurus, Jove) kaldırıldı — çeşit sayısı ile tasarım
  // sayısı ayrı iki şey ve dördü ikisini birden oynamaya çalışıyordu.
  // KARAR 05.8 s2
  static const dr1 = ItemSpec(
    id: 'dr1',
    name: 'Delta',
    slot: SlotType.droid,
    tier: ItemTier.cI,
    mainStat: 'hasar_artisi',
    variant: 'delta',
    subStatPool: [
      'atis_hizi',
      'kritik_sansi',
      'kritik_hasari',
      'govde_cani',
      'zirh',
      'menzil',
    ],
  );

  /// NOVA rafı — kredi rafının bir kademe üstünde, lazer ve jeneratör gibi.
  /// KARAR 05.8 s2
  static const dr5 = ItemSpec(
    id: 'dr5',
    name: 'Hilal',
    slot: SlotType.droid,
    tier: ItemTier.bI,
    mainStat: 'hasar_artisi',
    variant: 'hilal',
    subStatPool: [
      'atis_hizi',
      'kritik_sansi',
      'kritik_hasari',
      'govde_cani',
      'zirh',
      'menzil',
    ],
    currency: Currency.premium,
  );

  // ── NOVA rafı ────────────────────────────────────────────────────────
  //
  // Kıt parayla alınan eşyalar mağazanın ÜSTÜNE konuyor, İÇİNE değil: kredi
  // rafındaki hiçbir şey buraya taşınmadı. Sebep ekonomik değil tasarımsal —
  // ilerlemenin zorunlu bir basamağı kıt paraya bağlanırsa, oyun oynayarak
  // ilerleyen oyuncu bir duvara çarpar ve o duvarın adı "öde" olur.
  //
  // Buradakiler kredi rafının en üstünden (A tier) bir kademe yukarıda:
  // istenir ama gerekmez.

  static const pl5 = ItemSpec(
    id: 'pl5',
    name: 'PL-5 Nova',
    slot: SlotType.laser,
    tier: ItemTier.bI,
    mainStat: 'taban_hasar',
    subStatPool: [
      'hasar_artisi',
      'atis_hizi',
      'kritik_sansi',
      'kritik_hasari',
      'son_hasar',
      'menzil',
      'hiz',
    ],
    currency: Currency.premium,
  );

  static const df5 = ItemSpec(
    id: 'df5',
    name: 'DF-5 Nova Kalkanı',
    slot: SlotType.generator,
    tier: ItemTier.bI,
    mainStat: 'kalkan',
    subStatPool: [
      'govde_cani',
      'kalkan_yenilenmesi',
      'zirh',
      'kacinma',
      'son_azaltma',
      'menzil',
      'hiz',
    ],
    currency: Currency.premium,
  );

  /// ELLE tasarlanmış tasarımlar — merdivenin dibi (C-I … B-I).
  ///
  /// Bir zamanlar mağazanın rafı buydu ve sabitti; raf artık banda bağlı
  /// ([rafFor]). Liste türetmenin tabanı olarak duruyor: üstü [items] içinde
  /// bundan türetiliyor, tablo (06) bunu basıyor.
  static const List<ItemSpec> rafta = [
    pl1,
    pl3,
    pl4,
    pl5,
    df1,
    df3,
    df5,
    th1,
    th3,
    mk1,
    cpuRepair,
    cpuScope,
    dr1,
    dr5,
  ];

  /// NOVA RAFI — kıt parayla alınan tasarımlar, banda bağlı DEĞİL.
  ///
  /// Kredi rafı (15.2) oyuncunun bandını izliyor: bandın bir altındaki rank,
  /// alt statsız, fiyatı 13'ün mağaza payından. NOVA rafı onun yanında ayrı
  /// duruyor ve üç şeyle sınırlı: yalnız elle yazılmış tasarımlar, yalnız
  /// TABAN eşya (alt stat yok, derinlik satılmıyor) ve kredi rafının bir
  /// kademe üstü. "İstenir ama gerekmez" ölçüsü bu: rank farkı bir kademe,
  /// alt stat farkı sıfır.
  /// KARAR 15.7 s1
  static final List<ItemSpec> novaRafi = [
    for (final s in rafta)
      if (s.currency == Currency.premium) s,
  ];

  /// RAF + merdivenden TÜRETİLEN üst ranklar.
  ///
  /// Gövdedeki desenin aynısı ([HullClass.all]): elle çizilmiş olanların
  /// üstüne, merdivenin geri kalanı türetiliyor. Fiyatı `null` — tanımlı ama
  /// satın alınamaz.
  ///
  /// **Neden gerekliydi:** merdiven yirmi ranka uzayınca mağazanın en iyisi
  /// rank 3'te kaldı, dünya ise rank 20'ye gidiyor. Aradaki on yedi rankta
  /// oyunda TEK BİR eşya yoktu — tam donanımlı geliştirme hesabı bile son
  /// bölgenin kapısını açamıyordu (BR 34.138, kapı 1.360.725). Ganimet ve
  /// sentez oynanışa girdiğinde eşyalar buradan gelecek; bugün merdivenin
  /// üstünü boş bırakmamak için duruyorlar.
  static final List<ItemSpec> items = [
    ...rafta,
    for (final tip in SlotType.values)
      for (final tier in ItemTier.values)
        if (_ustRank(tip, tier)) _turet(tip, tier),
  ];

  /// MAĞAZA RAFI — bandın bir alt rankındaki taban eşyalar (15.2).
  ///
  /// Raf sabit bir liste değil, oyuncunun bandına bağlı: her yuva tipi için
  /// (droid dahil) `Kazanc.tabanEsyaRankiFor(bandRank)` rankındaki
  /// tasarımlar. İlk bantta C-I; C-II ve C-III raftan indi, ganimet ve
  /// sentezden gelir. Bu, 10.7'nin açılış sırasını kendiliğinden koruyor:
  /// raftan alınan hiçbir eşya sahip olunan en yüksek rankı bandın üstüne
  /// çıkaramaz (borç defteri B14). Para birimi rafta HEP kredi, NOVA eşya
  /// satmıyor (15.1); tasarımın `currency` alanı burada okunmuyor.
  /// KARAR 15.2 s1 · KARAR 10.7 s1
  static List<ItemSpec> rafFor(int bandRank) {
    final tier = ItemTier.values[Kazanc.tabanEsyaRankiFor(bandRank)];
    return [
      for (final tip in SlotType.values)
        for (final s in items)
          if (s.slot == tip && s.tier == tier) s,
    ];
  }

  /// Raftaki taban eşyanın fiyatı — 15.2'nin modeli, tasarımın fiyatı değil.
  /// KARAR 15.2 s1
  static Price rafFiyati(int bandRank) =>
      Price.credit(Kazanc.tabanEsyaFiyatiFor(bandRank).round());

  /// [tier] bu yuva tipinin RAFTAKİ en iyisinden yukarıda mı.
  static bool _ustRank(SlotType tip, ItemTier tier) {
    final rafDeki = rafta.where((s) => s.slot == tip);
    if (rafDeki.isEmpty) return false;
    // Elle yazılmış bir tasarım varsa türetme: merdivenin o basamağı zaten
    // dolu.
    if (rafDeki.any((s) => s.tier == tier)) return false;
    final enIyi = rafDeki
        .map((s) => s.tier.index)
        .reduce((a, b) => a > b ? a : b);
    final enDusuk = rafDeki
        .map((s) => s.tier.index)
        .reduce((a, b) => a < b ? a : b);
    // Üstünü türetiyor VE aradaki boşlukları dolduruyor. Boşluk kavramı
    // droidle geldi (05.8 s2): iki çeşit var — Delta C-I'de, Hilal B-I'de —
    // ve aradaki iki basamak elle yazılmıyor. Merdivenin bir basamağı boş
    // kalırsa o bantta raf droidsiz açılır ve ganimet o rankta droid
    // düşüremez.
    return tier.index > enIyi || tier.index > enDusuk;
  }

  /// Rafın en iyisini şablon alıp merdivenin üst basamağına taşı.
  ///
  /// Ana stat, alt stat havuzu ve yuva şablondan; DEĞİŞEN tek şey rank —
  /// gücü zaten rank çarpanı veriyor. Yeni bir eşya İCAT etmiyor, var olanın
  /// merdivendeki devamını yazıyor.
  /// Bir droid tasarımının YUVA sayısı (05.4 s5).
  ///
  /// Elit droid iki, standart droid bir. Elit olmak rank ya da stat farkı
  /// değil, TAŞIMA farkı: elit hem lazer hem jeneratör taşıyabiliyor,
  /// standart olan seçmek zorunda.
  /// KARAR 05.4 s5 · KARAR 15.7 s1
  static int droidYuvaSayisi(ItemSpec spec) =>
      Saglayici.droidYuvaSayisi(spec);

  /// Tasarım kimliğinin oyuncuya görünen adı — sanat katmanıyla aynı adlar,
  /// ama çekirdek sanatı okumuyor: liste burada, testi ikisini eşitliyor.
  /// KARAR 05.8 s2
  static String _droidAdi(String tasarim) => switch (tasarim) {
    'hilal' => 'Hilal',
    'halka' => 'Halka',
    'delta' => 'Delta',
    'elmas' => 'Elmas',
    'damla' => 'Damla',
    'pusula' => 'Pusula',
    'cerceve' => 'Çerçeve',
    'prizma' => 'Prizma',
    'parantez' => 'Parantez',
    'jiroskop' => 'Jiroskop',
    _ => 'Droid',
  };

  static ItemSpec _turet(SlotType tip, ItemTier tier) {
    final sablon = rafta
        .where((s) => s.slot == tip)
        .reduce((a, b) => a.tier.index >= b.tier.index ? a : b);
    // DROİDDE TASARIMI RANK SEÇİYOR (05.8 s2): satın alınan iki droidin
    // kendi görünüşü var (Hilal, Delta), merdivenden gelenler kalan sekiz
    // tasarımı sırayla giyiyor. Böylece rank atlayan oyuncunun filosu da
    // değişiyor ve sekiz tasarım ölü kalmıyor. Öteki yuvalarda şablonun
    // görünüşü aynen taşınıyor.
    final tasarim = tip == SlotType.droid
        ? DroidModeli.merdiven[tier.index % DroidModeli.merdiven.length].name
        : sablon.variant;
    return ItemSpec(
      id: '${tip.name}-${tier.name}',
      name: tip == SlotType.droid
          ? '${_droidAdi(tasarim!)} ${tier.label}'
          : '${sablon.name.split(' ').first} ${tier.label}',
      slot: tip,
      tier: tier,
      mainStat: sablon.mainStat,
      subStatPool: sablon.subStatPool,
      variant: tasarim,
      // DROİD MERDİVENDEN GELİYORSA KREDİ ÇEŞİDİ — ŞABLONUNKİ DEĞİL.
      //
      // `currency` droidde bir fiyat etiketi değil ÇEŞİT: `droidYuvaSayisi`
      // onu okuyup elit droide iki, standarda bir yuva veriyor (05.4 s5).
      // Şablon kopyalandığı sürece merdivenin bütün droidleri elit sayılıyor
      // ve "elit olmanın tek anlamı iki yuva taşıması" cümlesi ilk banttan
      // sonra buharlaşıyordu: katalogdaki yirmi droidin on dokuzu iki
      // yuvalıydı, çünkü droid şablonu rafın en yüksek droidi — yani NOVA
      // rafındaki Hilal.
      //
      // Merdiven droidi ganimetten düşüyor, satın alınmıyor; NOVA ile
      // alınmadığına göre elit de değil. Öteki yuvalarda şablonun para
      // birimini taşımak zararsız — orada `currency` yalnız fiyat, ve
      // merdiven eşyası zaten satılmıyor.
      //
      // Ölçüldü (B25/B42): tek yuvalı merdiven droidi ilk üç bantta iki
      // yuvalı Hilal'in gerisinde (%20 · %15 · %7), dördüncüde öne geçiyor,
      // sonda 3,5 katı. 15.7'nin "istenir ama gerekmez" ölçüsü böyle
      // korunuyor — NOVA rafı erken erişim satıyor, kalıcı güç değil.
      currency: tip == SlotType.droid ? Currency.credit : sablon.currency,
    );
  }

  static final Map<String, ItemSpec> byId = {
    for (final spec in items) spec.id: spec,
  };

  /// MAĞAZANIN MALZEME RAFI — yalnız DÜŞÜK rank.
  ///
  /// Alan 07: *"mağaza düşük rank malzeme satabilir — çünkü onlar zaten bol,
  /// ve satılması yalnız zaman kısaltıyor. Üst rank malzeme mağazada olmuyor.
  /// O, zor içeriğin kendi ödülü — ve üst rank eşyanın gerçek kapısı."*
  ///
  /// **Sınır TÜRETİLEN, ilan edilen değil:** rafın kendi en yüksek rankı.
  /// Mağaza hangi rankta eşya satıyorsa o rankın malzemesini de satabiliyor;
  /// üstü, satmadığı eşyaların kapısı ve ona dokunmuyor. Ayrı bir eşik sayısı
  /// koymak, aynı kararı iki yerde vermek olurdu.
  /// KARAR 07.9 s1
  static final List<Malzeme> malzemeRafi = [
    for (final m in Malzeme.hepsi)
      // YALNIZ yükseltme malzemesi. ÇEVİRİCİ hiçbir rankta satılmıyor.
      //
      // Belge düşük rank malzemenin satılabileceğini söylüyor ve gerekçesi
      // "onlar zaten bol, satılması yalnız zaman kısaltıyor". Çevirici bol
      // DEĞİL: nadirliği tasarımın kendisi ve tek kaynağı eşya parçalamak.
      // Mağazaya koymak o nadirliği paraya açardı — mükemmel roll'ü kovalayan
      // oyuncu, fazla eşyasını eritmek yerine kredi biriktirirdi.
      //
      // Bir ara satılıyordu ve fark edilmesi tesadüf oldu: şemaya tür ekseni
      // eklendiğinde raf filtresi hâlâ yalnız RANKA bakıyordu, tür ayrımı
      // yoktu. Aşağıdaki test onu bir daha sessizce açılamaz yapıyor.
      if (m.tur == MalzemeTuru.yukseltme && m.rank.index <= _rafinTepesi) m,
  ];

  static final int _rafinTepesi = rafta
      .map((s) => s.tier.index)
      .reduce((a, b) => a > b ? a : b);

  /// Bir malzemenin mağaza fiyatı — TAM olarak farm karşılığı.
  ///
  /// [Ganimet.malzemeDegeriFor] "1 malzeme ≡ 1 öldürme ≡ o bandın yaratık
  /// ödülü" diyor. Mağaza tam o fiyata satıyor: ne kâr ne zarar, yalnız
  /// ZAMAN. Belge de bunu istiyor — *"satılması yalnız zaman kısaltıyor"*.
  ///
  /// Üstüne bir pay koymak malzemeyi bir kazanç kalemine çevirirdi; altına
  /// inmek farm etmeyi anlamsız kılardı. İkisi de rank kapısını paraya açar.
  static Price malzemeFiyati(Malzeme malzeme) =>
      Price.credit(Ganimet.malzemeDegeriFor(malzeme.rank.index).round());

  /// Mağaza fiyatı.
  ///
  /// Tier çarpanının KARESİ ile ölçekleniyor: iki kat güçlü bir eşya iki kat
  /// değil, dört kat pahalı. Doğrusal fiyat, en yüksek tier'ı her zaman en
  /// verimli alım yapar ve alt tier'lar ölü ürüne döner.
  static Price priceOf(ItemSpec spec) {
    final m = spec.tier.multiplier;
    return switch (spec.currency) {
      // Kredi rafı: 12.000 tabanlı.
      Currency.credit => Price.credit((12000.0 * m * m).round()),
      // NOVA rafı AYRI bir tabanla ve çok küçük sayılarla ölçekleniyor.
      //
      // İki para birimini aynı sayı düzleminde tutmak (mesela 1 NOVA = 100
      // kredi) ikisini tek bir birimin iki adı yapardı. Kıt paranın kıt
      // HİSSEDİLMESİ için sayılarının da küçük olması gerekiyor: 2430 NOVA,
      // 108.000 kredi ile aynı ekranda dururken bile farklı bir şey.
      //
      // Ölçek ödül hızından türedi: Void Spore başına 1 NOVA ve ~10 saniyelik
      // bir çevrimde saatte ~360 NOVA. S tier bir eşya ~7 saatlik oyun eder
      // — istenir, ama beklenemeyecek kadar uzak değil.
      Currency.premium => Price.premium((270.0 * m * m).round()),
    };
  }

  /// Bir statın okunabilir hâli.
  static String labelOf(String statId) => Stats.byId(statId)?.label ?? statId;

  /// Gövde fiyatı — hangar için.
  /// Gövdenin hangar fiyatı — satın alınamayanlar için `null`.
  static Price? hullPrice(HullClass hull) {
    final price = hull.price;
    return price == null ? null : Price.credit(price);
  }
}
