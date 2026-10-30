import '../world/dusman.dart';

/// Bir alien türünün sayısal kimliği.
///
/// [ShipStats] ile aynı desen ve aynı sebep: burada yalnız DEĞİŞMEYEN değerler
/// durur, o yüzden `const`. Görsel yok — bu paket sunucuda da koşuyor.
class AlienStats {
  const AlienStats({
    required this.kind,
    required this.name,
    required this.radius,
    required this.speed,
    required this.roamRange,
    required this.maxHull,
    required this.respawnDelay,
    required this.damage,
    required this.fireInterval,
    required this.range,
    required this.aggroRange,
    required this.creditReward,
    required this.premiumReward,
    this.armor = 0,
    this.evasion = 0,
  });

  /// Void Spore — haritanın en küçük yaratığı: dönen, asit yeşili bir küre.
  ///
  /// **Bölge 1'in SIRADAN yaratığı.** Kışkırtılmadıkça saldırmaz: haritada
  /// dolaşan, istersen görmezden gelebileceğin bir hedef. Ateş açtığın anda
  /// karşılık veriyor — yani riski OYUNCU başlatıyor, ve bu oyuncuya haritayı
  /// geçme hakkı veriyor.
  ///
  /// Sayıların hiçbiri burada YAZILI DEĞİL: canı bir süre, hasarı bir kaçış
  /// penceresi, ödülü bir bölme işlemi — üçü de [DusmanTasarimi]'ndan geliyor.
  /// Burada duran yalnız KİMLİK: adı, yarıçapı, ateş ritmi, dolaşma yarıçapı.
  static final spore = _turet(
    kind: 0,
    name: 'Void Spore',
    rank: 0,
    sinif: DusmanSinifi.siradan,
    radius: 24,
    // Ritim bir kimlik özelliği, denge değil: aralık ne olursa olsun
    // [DusmanTasarimi.hasarDps] korunuyor, yalnız atışın iriliği değişiyor.
    fireInterval: 2,
    // Yeni gezinme noktası bu yarıçap içinden seçilir. Küçük tutmak sürüyü
    // doğduğu yerde tutuyor — harita boyunca dağılan alienler, ilgi alanı
    // filtresi yüzünden hiç görünmez.
    roamRange: 1500,
  );

  /// Void Leviathan — dokunaçlı, zırhlı, çekirdeği parlayan büyük yaratık.
  ///
  /// **Bölge 1'in GÜÇLÜ yaratığı.** Void Spore'un karşıtı: menziline giren
  /// oyuncuya kendisi başlıyor, ama kaçamıyor. Girmek de çıkmak da oyuncunun
  /// elinde — biri geçilebilir, öteki bir karar.
  ///
  /// Tehlikeli yapan hasarı değil SÜRESİ: sıradan yaratığın beş katı sürüyor
  /// ve o sürenin tamamında ateş ediyor. Hasarı sıradanınkiyle aynı, çünkü
  /// kaçış penceresi sınıfla değil bantla ölçekleniyor.
  static final leviathan = _turet(
    kind: 1,
    name: 'Void Leviathan',
    rank: 0,
    sinif: DusmanSinifi.guclu,
    // Void Spore'un iki katı: sprite'ın kendisi de öyle okunuyor.
    radius: 48,
    fireInterval: 2.5,
    // Dar dolaşma: yuvasında duran bir bekçi gibi.
    roamRange: 900,
  );

  /// Bir KİMLİĞİ, bandının ve sınıfının sayılarıyla birleştirir.
  ///
  /// Tek üretici. İkinci bir yol açmak, bir yaratığın canını elle yazmayı
  /// mümkün kılardı — ve elle yazılan tek bir can, bandın öldürme süresini
  /// sessizce kaydırır.
  static AlienStats _turet({
    required int kind,
    required String name,
    required int rank,
    required DusmanSinifi sinif,
    required double radius,
    required double fireInterval,
    required double roamRange,
  }) {
    final t = DusmanTasarimi(rank: rank, sinif: sinif);
    return AlienStats(
      kind: kind,
      name: name,
      radius: radius,
      speed: t.hiz,
      roamRange: roamRange,
      maxHull: t.can,
      respawnDelay: t.dogusSuresi,
      damage: t.atisHasariFor(fireInterval),
      fireInterval: fireInterval,
      range: t.menzil,
      // Saldırgan olmayan yaratık YALNIZ karşılık verir; menzili aggro
      // olarak da kullanmak onu saldırgan yapardı.
      aggroRange: sinif.saldirgan ? t.menzil : 0,
      creditReward: t.kredi,
      premiumReward: t.nova,
    );
  }

  /// Tel üzerinde taşınan tür kimliği. `u8`; 256 tür bu oyunun ufkunun
  /// ötesinde.
  final int kind;

  final String name;

  /// Görsel/çarpışma yarıçapı (dünya birimi).
  final double radius;

  /// Gezinme hızı, dünya birimi/sn.
  final double speed;

  /// Gezinme hedefinin doğuş noktasına en fazla uzaklığı.
  final double roamRange;

  final double maxHull;

  /// İmha edildikten sonra yeniden doğmaya kadar geçen süre (sn).
  final double respawnDelay;

  /// Bir atışın hasarı.
  final double damage;

  /// İki atış arasındaki süre (sn).
  final double fireInterval;

  /// Ateş menzili (dünya birimi).
  final double range;

  /// KENDİLİĞİNDEN saldırmaya başladığı mesafe. Sıfır = yalnız karşılık verir.
  ///
  /// Kışkırtma ile saldırganlık arasındaki fark türün kimliği: oyuncunun
  /// haritada nereye girip nereye girmeyeceğine karar vermesini sağlayan şey
  /// bu sayı.
  final double aggroRange;

  /// Ham ZIRH statı (L4). **Alan 12 sıfırda BIRAKTI.**
  ///
  /// Bekleyen bir sayı değil, verilmiş bir karar: yaratığın canı zaten hedef
  /// ÖLDÜRME SÜRESİNDEN türüyor. Üstüne zırh koymak aynı süreyi ikinci kez
  /// tanımlamak olurdu — ve iki tanım, biri değiştiğinde sessizce ayrışır.
  ///
  /// Katman duruyor: bir yaratığa zırh vermek istenirse canı o kadar
  /// azaltılmak zorunda, yoksa sınıfın anlamı kayboluyor.
  final double armor;

  /// Ham KAÇINMA statı (L4). Sıfır — [armor] ile aynı sebeple.
  final double evasion;

  /// İmha edildiğinde düşen kredi.
  final int creditReward;

  /// İmha edildiğinde düşen NOVA.
  ///
  /// Kıt para OYUN İÇİNDE de kazanılıyor ve bu bir incelik değil şart:
  /// yalnız parayla alınabilen bir birim, oyuncunun ekonominin parçası
  /// saymadığı bir birimdir.
  final int premiumReward;

  /// ESKİ kayıtlar — kadroya girmemiş, elle çizilmiş iki tür.
  ///
  /// Bu liste bir zamanlar "sunucunun doğurduğu türler"di ve doc'u öyle
  /// diyordu. Sunucu [YaratikKadrosu]'ndan doğurmaya geçti, liste ve yorum
  /// olduğu yerde kaldı — ve yanlış bir yorum, yanlış bir sayıdan daha
  /// pahalıya patladı: denetim katmanı burayı "doğan türler" sanıp 2/32
  /// raporladı, istemci de [byKind] üzerinden kadronun HİÇBİR üyesini
  /// çözemedi.
  ///
  /// `const` değil `final`: sayılar türetiliyor ve `pow` `const` olamıyor.
  static final List<AlienStats> all = [spore, leviathan];

  /// ESKİ kayıtlar arasında ara; tanınmayan kimlikte spore'a düş.
  ///
  /// Sessiz düşüş TEHLİKELİ ve bir kez ısırdı: kadro geldiğinde bu metod
  /// otuz iki yeni kimliği de sessizce spore yaptı, kimse bir hata görmedi.
  /// Yarıçap sormak için [YaratikKadrosu.yaricapFor] kullanılmalı — düşüşü
  /// yalnız gerçekten eski olan kimlikler için yapıyor.
  static AlienStats byKind(int kind) {
    for (final alien in all) {
      if (alien.kind == kind) return alien;
    }
    return spore;
  }
}
