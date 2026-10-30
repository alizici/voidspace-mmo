import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import 'droid_grubu.dart';
import 'laser_stats.dart';

/// Bir gövdenin sayısal kimliği. Görsel tasarımdan (art/) ve durumdan
/// (ShipBloc) AYRI: burada yalnız DEĞİŞMEYEN değerler durur, o yüzden `const`.
class ShipStats {
  const ShipStats({
    required this.name,
    required this.maxHull,
    required this.maxShield,
    required this.shieldRegenPerSecond,
    required this.shieldRegenDelay,
    required this.speed,
    required this.boostFactor,
    required this.boostDuration,
    required this.maxBoostCharges,
    required this.boostRecharge,
    required this.laser,
    required this.laserSlots,
    required this.equippedLasers,
    this.govdeKademesi = 0,
    this.damageBonus = 0,
    this.conditionalBonus = 0,
    this.critChance = TasarimGirdileri.kritikSansiReferans,
    this.critMultiplier = TasarimGirdileri.kritikCarpaniReferans,
    this.armor = 0,
    this.evasion = 0,
    this.flatDamage = 0,
    this.flatMitigation = 0,
    this.rangeBonus = 0,
    this.speedBonus = 0,
    this.boostRechargeBonus = 0,
    this.roketHasari = 0,
    this.droidler = DroidGrubu.yok,
  });

  /// Bastion — ağır, lav çekirdekli avcı.
  /// KARAR 04.5 s2
  /// YER TUTUCU ve fiyat yinelemesinin TOHUMU — çıplak gövde, referans silahı.
  ///
  /// Oyuncunun referansı bu DEĞİL: o `ReferansCozumu.stats`, tam donanımlı
  /// build (04.5). Artık fiyat referansı da o (03.2 s2): fiyatlar dolu
  /// build'in marjinal değerinden ölçülüyor ve doğan döngü sabit nokta
  /// yinelemesiyle çözülüyor (`FiyatCozumu`). Bu sabite kalan iki iş:
  /// yinelemenin tohumu olmak — sabit nokta tek, nereden başlandığı sonucu
  /// değiştirmiyor — ve bağlantı gelmeden istemcinin tahmin gemisini
  /// doğurmak; sunucu gerçek statları yolladığı an bu sayılar biter.
  /// Referansın zırhı ile kaçınması da buradan okunuyor (alan 04'ün hedef
  /// değerleri). `const` olmak zorunda: varsayılan parametre.
  static const bastion = ShipStats(
    name: 'Bastion',
    // Havuzlar tepe tablodan: gövde çapası TTK kısıtından çözülmüş (08.5),
    // kalkan çapası girdi. Uzun süre ikisi burada ve `HullClass`ta ayrı ayrı
    // elle duruyordu; bir test ayrışmalarını tutuyordu.
    maxHull: Turetilenler.govdeCapasi,
    maxShield: TasarimGirdileri.kalkanCapasi,
    shieldRegenPerSecond: 340,
    // Vuruştan sonra bu kadar bekler. Gecikme olmadan kalkan "sonsuz can"
    // olurdu; asıl karar penceresini açan şey bu bekleme.
    shieldRegenDelay: 2.4,
    speed: TasarimGirdileri.hizCapasi,
    boostFactor: 1.9,
    boostDuration: 0.85,
    maxBoostCharges: 3,
    boostRecharge: 3.6,
    laser: LaserStats.pl4,
    // Namlu sayısı gövdenin YUVA sayısıyla aynı: `Bastion.hardpoints` beş
    // yuva çiziyor ve her yaylımda beşi birden ateşliyor. İki sayının
    // ayrışması, silahın olmadığı yerden mermi çıkması demek olurdu.
    //
    // Tam kalkanı (8000) düşürmek ~8 yaylım, yani ~9 saniye kesintisiz ateş:
    // kaçmaya, kalkan beklemeye ve karşılık vermeye zaman bırakan bir tempo.
    // Anında ölüm PvP'yi refleks yarışına indirir.
    // Referans build'in ZIRHI ve KAÇINMASI — alan 04'ün ilan ettiği değerler.
    //
    // Uzun süre sıfırdılar ve o hâlde referans build'in etkin canı 20.000'de
    // kalıyordu; belge ise 33.613 diyor. Fark tam olarak azaltma katmanıydı:
    // eğrinin K'sı çözülene kadar (alan 04) zırh yazmanın anlamı yoktu, çünkü
    // `armorReduction` her zaman sıfır dönüyordu.
    armor: TasarimGirdileri.zirhCapasi,
    evasion: TasarimGirdileri.referansKacinma,
    laserSlots: TasarimGirdileri.lazerYuvaSayisi,
    // Referans gövde TAM donanımlı. Gerçek bir oyuncunun gemisinde bu sayı
    // `LoadoutResolver` tarafından takılı lazerlere göre hesaplanıyor.
    equippedLasers: TasarimGirdileri.lazerYuvaSayisi,
  );

  final String name;
  final double maxHull;
  final double maxShield;

  /// Saniyede yenilenen kalkan.
  final double shieldRegenPerSecond;

  /// Son vuruştan sonra yenilenmenin başlaması için geçmesi gereken süre (sn).
  final double shieldRegenDelay;

  /// Taban hız, dünya birimi/sn.
  final double speed;

  /// İtki sırasındaki hız çarpanı.
  final double boostFactor;

  /// Bir itkinin süresi (sn).
  final double boostDuration;

  /// Aynı anda taşınabilen itki şarjı.
  final int maxBoostCharges;

  /// Bir şarjın dolma süresi (sn).
  final double boostRecharge;

  /// Takılı lazer tipi.
  final LaserStats laser;

  /// Gövdenin lazer YUVA sayısı — kapasite.
  final int laserSlots;

  /// Yuvaların kaçının DOLU olduğu — 0..[laserSlots].
  ///
  /// Kapasiteden ayrı bir sayı çünkü oyuncunun gördüğü şey bu: gemi taktığı
  /// kadar namlu taşıyor, boş yuvada silah çizilmiyor. Eski projeden gelen
  /// kural ve doğru olan: beş yuvalı bir gövdede tek lazerle uçan oyuncunun
  /// gemisinde beş top olması, hangarın hiçbir şey yapmadığını söylerdi.
  final int equippedLasers;

  /// Gövde KADEMESİ (0..7) — geminin hangi çizimle görüneceği.
  ///
  /// Sunucuya değil İSTEMCİYE ait bir gerçek ama buradan geçiyor, çünkü
  /// istemcinin bir gemiye bakıp hangisi olduğunu bilmesinin tek yolu
  /// sunucunun söylemesi. Adı taşıyan kanalın (`ServerEntityMeta`) yanına
  /// giriyor.
  ///
  /// Varsayılan 0: elle kurulan referans yapılar (`ShipStats.bastion`) ve
  /// testler kademe bildirmek zorunda kalmasın — hepsi başlangıç gövdesi.
  final int govdeKademesi;

  // ── L1 · toplamsal ───────────────────────────────────────────────────

  /// Toplamsal hasar artışı (L1). Ekipmanın ana yeri.
  ///
  /// Zincire AYRI girdiği için `laser.damage`ın içine gömülmüyor: gömülseydi
  /// L0 ile L1 tek bir sayıya çöker ve katman payını ölçmek imkânsız olurdu.
  final double damageBonus;

  // ── L2 · koşullu · AYRILMIŞ ──────────────────────────────────────────

  /// Koşullu bonusların toplamı (L2). Bugün daima 0.
  ///
  /// Katman ayrılmış ve zincirde duruyor: kafes ve koşullu statlar geldiği gün
  /// zincirin şekli değişmeyecek, yalnız bu çarpan 0 olmaktan çıkacak.
  final double conditionalBonus;

  // ── L3 · kritik ──────────────────────────────────────────────────────

  /// Kritik şansı (k). Varsayılanı tepe tablodan geliyor: referans build'in
  /// kritik şansı bir tasarım GİRDİSİ, geminin icat ettiği bir sayı değil.
  final double critChance;

  /// Kritik çarpanı (d).
  final double critMultiplier;

  // ── L4 · savunma ─────────────────────────────────────────────────────

  /// Ham zırh statı. Doyum eğrisinden geçip azaltmaya dönüşüyor.
  final double armor;

  /// Ham kaçınma statı. Zırhın kardeşi — sıyırma üretiyor, ıskalama değil.
  final double evasion;

  // ── L5 · düz ─────────────────────────────────────────────────────────

  final double flatDamage;
  final double flatMitigation;

  // ── sistem · L1 oran, ÇİĞ ────────────────────────────────────────────
  //
  // Menzil, hız ve itki dolumu zincire girmiyor; [speed], [laser].range ve
  // [boostRecharge] onların UYGULANMIŞ hâli. Oranların kendisi ayrıca
  // duruyor çünkü savaş puanının sistem kanalı bunları okuyor: puan
  // eşyanın verdiği yüzde, referans gövdeye göre ölçülen fark değil.
  // KARAR 09.5 s1

  /// Menzil oranı (L1). Referansta 0.
  final double rangeBonus;

  /// Hız oranı (L1). Gövdenin taban hızı buraya girmiyor.
  final double speedBonus;

  /// İtki dolumu oranı (L1).
  final double boostRechargeBonus;

  /// ROKET salvosunun taban hasarı (18.1): roketatarın taban hasarı × kadans
  /// oranı. Sıfırsa roketatar boş, gemi roket atmıyor. Salvo her
  /// `roketAraligi` saniyede bir, zincirin geri kalanı geminin (18.2).
  final double roketHasari;

  // ── droid grubu · varlık ─────────────────────────────────────────────

  /// Geminin yanında uçan droidler — kendi zinciri, σ ile bağlı (05.1, 05.5).
  /// Savaş puanına ayakta kalma ve çeyrek katsayıyla giriyor (09.6).
  final DroidGrubu droidler;

  // ── türetilenler ─────────────────────────────────────────────────────

  /// **L0** — takılı bütün lazerlerin taban hasarı toplamı.
  ///
  /// `equippedLasers`, `laserSlots` DEĞİL. Kural belgesi 01: *"yuva boşsa gemi
  /// ateş edemez"*. Kapasiteyle çarpmak, silahın olmadığı yuvadan hasar
  /// çıkarırdı — ve hangarın hiçbir şey yapmadığını söylerdi.
  double get baseVolleyDamage => laser.damage * equippedLasers;

  /// Zırhın ÜRETTİĞİ azaltma (L4).
  ///
  /// Eğrinin K'sı ([Turetilenler.kZirh]) alan 04 yazılana kadar `null`du ve o
  /// süre boyunca azaltma SIFIRDI — tahmini bir K ile hesaplamak, alan
  /// geldiğinde kimsenin geri dönüp düzeltmediği bir sayı üretirdi. Alan 04
  /// referans zırhı ilan edince sabit kendiliğinden çözüldü ve katman açıldı.
  double get armorReduction => SavunmaEgrileri.doyum(armor, Turetilenler.kZirh);

  /// Kaçınmanın ürettiği SIYIRMA (L4). Tavanı `siyirmaTavani`.
  /// KARAR 01.5 s1
  double get graze => SavunmaEgrileri.siyirma(evasion, Turetilenler.kSiyirma);

  /// L4'ün toplam azaltması — zırh ve sıyırma birlikte.
  ///
  /// Çarpımsal birleşiyorlar: `1 − (1 − zırh)(1 − sıyırma)`. Toplamsal olsaydı
  /// ikisini birden yığan oyuncu %100'e ulaşabilirdi.
  double get totalMitigation => 1 - (1 - armorReduction) * (1 - graze);

  /// Tek tek alan değiştirerek kopyala.
  ///
  /// Denge simülasyonunun ve testlerin kapısı: "aynı build ama kritiksiz"
  /// gibi bir varyantı elle kurmak, referansın sekiz alanını tekrar yazmak
  /// demekti — ve o kopyalar bir gün asıl referanstan ayrışırdı.
  ShipStats copyWith({
    String? name,
    double? maxHull,
    double? maxShield,
    double? shieldRegenPerSecond,
    double? shieldRegenDelay,
    double? speed,
    double? boostFactor,
    double? boostDuration,
    int? maxBoostCharges,
    double? boostRecharge,
    LaserStats? laser,
    int? laserSlots,
    int? equippedLasers,
    double? damageBonus,
    double? conditionalBonus,
    double? critChance,
    double? critMultiplier,
    double? armor,
    double? evasion,
    double? flatDamage,
    double? flatMitigation,
    double? rangeBonus,
    double? speedBonus,
    double? boostRechargeBonus,
    double? roketHasari,
    DroidGrubu? droidler,
  }) => ShipStats(
    name: name ?? this.name,
    maxHull: maxHull ?? this.maxHull,
    maxShield: maxShield ?? this.maxShield,
    shieldRegenPerSecond: shieldRegenPerSecond ?? this.shieldRegenPerSecond,
    shieldRegenDelay: shieldRegenDelay ?? this.shieldRegenDelay,
    speed: speed ?? this.speed,
    boostFactor: boostFactor ?? this.boostFactor,
    boostDuration: boostDuration ?? this.boostDuration,
    maxBoostCharges: maxBoostCharges ?? this.maxBoostCharges,
    boostRecharge: boostRecharge ?? this.boostRecharge,
    laser: laser ?? this.laser,
    laserSlots: laserSlots ?? this.laserSlots,
    equippedLasers: equippedLasers ?? this.equippedLasers,
    damageBonus: damageBonus ?? this.damageBonus,
    conditionalBonus: conditionalBonus ?? this.conditionalBonus,
    critChance: critChance ?? this.critChance,
    critMultiplier: critMultiplier ?? this.critMultiplier,
    armor: armor ?? this.armor,
    evasion: evasion ?? this.evasion,
    flatDamage: flatDamage ?? this.flatDamage,
    flatMitigation: flatMitigation ?? this.flatMitigation,
    rangeBonus: rangeBonus ?? this.rangeBonus,
    speedBonus: speedBonus ?? this.speedBonus,
    boostRechargeBonus: boostRechargeBonus ?? this.boostRechargeBonus,
    roketHasari: roketHasari ?? this.roketHasari,
    droidler: droidler ?? this.droidler,
  );
}
