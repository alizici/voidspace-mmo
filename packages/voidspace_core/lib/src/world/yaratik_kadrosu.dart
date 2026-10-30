import '../domain/alien_stats.dart';
import '../domain/ship_stats.dart';
import 'dusman.dart';

/// Bir yaratığın KİMLİĞİ — sanat ve ritim, denge değil.
///
/// Burada bir tek can, hasar ya da ödül yok ve olmayacak: onlar
/// [DusmanTasarimi]'ndan, bandın ve sınıfın matematiğinden geliyor. Kimlik
/// yalnız yaratığın NE OLDUĞUNU söylüyor — adı, biçimi, iriliği, ateş ritmi
/// ve sürünün içindeki göreli çevikliği.
///
/// Ayrımın sebebi pratik: bir sanatçı yeni bir yaratık eklerken hiçbir denge
/// sayısına dokunmuyor, bir tasarımcı dengeyi değiştirirken hiçbir sanat
/// dosyasına dokunmuyor.
class YaratikKimligi {
  const YaratikKimligi({
    required this.kind,
    required this.slug,
    required this.ad,
    required this.bicim,
    required this.bolge,
    required this.sinif,
    required this.yaricap,
    required this.atisAraligi,
    required this.hamHiz,
  });

  /// Tel üzerinde taşınan tür kimliği (`u8`).
  final int kind;

  /// Sanat katmanının anahtarı — palet ve çizici bununla bulunuyor.
  final String slug;

  /// Oyuncuya görünen ad.
  final String ad;

  /// Silüet ailesi. Çizici bununla seçiliyor; denge hiç okumuyor.
  final String bicim;

  /// Hangi bölgede yaşıyor — 0 tabanlı, `Bolge.kademe` ile aynı.
  final int bolge;

  final DusmanSinifi sinif;

  final double yaricap;

  /// İki atış arası, saniye.
  ///
  /// Dengeyi DEĞİŞTİRMİYOR: atış başına hasar `hasarDps × aralık` olduğu için
  /// hızlı ateş eden küçük, yavaş ateş eden iri vuruyor. Değişen tek şey
  /// yaratığın ritmi.
  final double atisAraligi;

  /// Kaynak kadrodaki ham hız değeri — TEK BAŞINA anlamlı değil.
  ///
  /// Sınıfın hız oranı bir ORTALAMA: [YaratikKadrosu.hizFor] bu sayıları
  /// sınıf içinde ölçekliyor, böylece sürünün içindeki çeviklik farkı
  /// korunurken sınıfın sözleşmesi ("sıradan kovalar ama yetişemez, güçlü hiç
  /// kovalayamaz") bozulmuyor.
  ///
  /// Ham hâlini kullanmak sözleşmeyi kırardı: kaynak kadroda bir güçlü
  /// yaratık, bir sıradan yaratıktan hızlı olabiliyor.
  final double hamHiz;

  /// Bu kimliğin [rank] bandındaki sayıları.
  DusmanTasarimi tasarimFor(int rank) =>
      DusmanTasarimi(rank: rank, sinif: sinif);

  /// Kimlik + sayı → sunucunun doğurabileceği tam kayıt.
  ///
  /// [dogusSuresi] verilirse sim'in KENDİ yeniden doğuş sayacını eziyor.
  /// Tek kullanıcısı boss: randevusu `HaritaKaydi`'nda duruyor ve orada
  /// durmasının sebebi hücrenin ölmesi — sayaç hücreyle birlikte sıfırlansaydı
  /// boss ancak birileri iki saat haritada beklerse doğardı.
  ///
  /// İki sayacı BİRDEN çalıştırmak yarış üretir: kayıt doğuş→doğuş ölçüyor,
  /// sim ölüm→doğuş. İki saat yaşayan bir boss öldüğünde kayıt "vakti çoktan
  /// geldi" deyip anında yenisini doğururdu ve aralık anlamını yitirirdi.
  /// `double.infinity` sim'i susturuyor: `∞ - dt` hep pozitif, ölü boss ölü
  /// kalıyor ve tek sahip kayıt oluyor.
  AlienStats statFor(int rank, {double? dogusSuresi}) {
    final t = tasarimFor(rank);
    return AlienStats(
      kind: kind,
      name: ad,
      radius: yaricap,
      speed: YaratikKadrosu.hizFor(this),
      // Dolaşma yarıçapı iriliğe bağlı: iri yaratık yuvasında duran bir
      // bekçi, küçük olan gezgin. Ayrı bir sayı olması gerekmiyor.
      roamRange: yaricap * _dolasmaKatsayisi,
      maxHull: t.can,
      respawnDelay: dogusSuresi ?? t.dogusSuresi,
      damage: t.atisHasariFor(atisAraligi),
      fireInterval: atisAraligi,
      range: t.menzil,
      aggroRange: sinif.saldirgan ? t.menzil : 0,
      creditReward: t.kredi,
      premiumReward: t.nova,
    );
  }

  /// Void Spore 24 yarıçap ile 1.500 dolaşıyordu; oran buradan.
  static const _dolasmaKatsayisi = 62.5;

  @override
  String toString() => '$ad (${sinif.name} · bölge ${bolge + 1})';
}

/// YİRMİ DÖRT YARATIK, SEKİZ BOSS — sekiz bölgenin kadrosu.
///
/// Her bölgede dört: iki sıradan, bir güçlü, bir boss. Belge üç yazıyordu
/// (sıradan · güçlü · boss); kadro geldiğinde farm katmanında iki tür çıktı ve
/// fazlası kabul edildi — aynı ekonomi, daha az tekrar. PvE ve PvP haritaları
/// AYNI kadroyu paylaşıyor: farkları ödülde ve rakipte, sanat bütçesinin en
/// büyük tasarrufu burada.
///
/// **Bu kadro DOĞUYOR.** `Zone` her serpmede buradan bir kimlik seçip
/// [YaratikKimligi.statFor] ile bandın sayılarını veriyor. Bir süre öyle
/// değildi ve bu yorum "sunucu hâlâ Spore ile Leviathan doğuruyor" diyordu;
/// sunucu değişti, yorum değişmedi. Yorumun bayatlaması ucuz görünüyor ama
/// bedeli ölçüldü: denetim katmanı [AlienStats.all]'ı "doğan türler" sanıp
/// 2/32 raporladı, oysa serpilen 15'ti.
/// KARAR 12.7 s1
abstract final class YaratikKadrosu {
  static const interdictor = YaratikKimligi(
    kind: 2,
    slug: 'interdictor',
    ad: 'Interdictor',
    bicim: 'torusGate',
    bolge: 0,
    sinif: DusmanSinifi.siradan,
    yaricap: 16,
    atisAraligi: 2.0,
    hamHiz: 66,
  );

  static const barraguda = YaratikKimligi(
    kind: 3,
    slug: 'barraguda',
    ad: 'Barraguda',
    bicim: 'eelSpindle',
    bolge: 0,
    sinif: DusmanSinifi.siradan,
    yaricap: 16,
    atisAraligi: 1.6,
    hamHiz: 118,
  );

  static const warray = YaratikKimligi(
    kind: 4,
    slug: 'warray',
    ad: 'Warray',
    bicim: 'rayGlider',
    bolge: 0,
    sinif: DusmanSinifi.guclu,
    yaricap: 17,
    atisAraligi: 1.7,
    hamHiz: 96,
  );

  static const kurvex = YaratikKimligi(
    kind: 5,
    slug: 'kurvex',
    ad: 'Kurvex',
    bicim: 'coiledSerpent',
    bolge: 0,
    sinif: DusmanSinifi.boss,
    yaricap: 24,
    atisAraligi: 2.4,
    hamHiz: 52,
  );

  static const subverter = YaratikKimligi(
    kind: 6,
    slug: 'subverter',
    ad: 'Subverter',
    bicim: 'boxWard',
    bolge: 1,
    sinif: DusmanSinifi.siradan,
    yaricap: 15,
    atisAraligi: 1.9,
    hamHiz: 72,
  );

  static const drifter = YaratikKimligi(
    kind: 7,
    slug: 'drifter',
    ad: 'Drifter',
    bicim: 'jellyBell',
    bolge: 1,
    sinif: DusmanSinifi.siradan,
    yaricap: 17,
    atisAraligi: 2.1,
    hamHiz: 58,
  );

  static const obliterator = YaratikKimligi(
    kind: 8,
    slug: 'obliterator',
    ad: 'Obliterator',
    bicim: 'cloverMaw',
    bolge: 1,
    sinif: DusmanSinifi.guclu,
    yaricap: 19,
    atisAraligi: 2.2,
    hamHiz: 54,
  );

  static const psychebehemot = YaratikKimligi(
    kind: 9,
    slug: 'psychebehemot',
    ad: 'Psyche Behemot',
    bicim: 'convolutedMass',
    bolge: 1,
    sinif: DusmanSinifi.boss,
    yaricap: 27,
    atisAraligi: 2.6,
    hamHiz: 42,
  );

  static const ghostfin = YaratikKimligi(
    kind: 10,
    slug: 'ghostfin',
    ad: 'Ghostfin',
    bicim: 'finGhost',
    bolge: 2,
    sinif: DusmanSinifi.siradan,
    yaricap: 15,
    atisAraligi: 1.7,
    hamHiz: 104,
  );

  static const prong = YaratikKimligi(
    kind: 11,
    slug: 'prong',
    ad: 'Prong',
    bicim: 'forkTine',
    bolge: 2,
    sinif: DusmanSinifi.siradan,
    yaricap: 15,
    atisAraligi: 1.6,
    hamHiz: 102,
  );

  static const glowfin = YaratikKimligi(
    kind: 12,
    slug: 'glowfin',
    ad: 'Glowfin',
    bicim: 'anglerLure',
    bolge: 2,
    sinif: DusmanSinifi.guclu,
    yaricap: 16,
    atisAraligi: 1.8,
    hamHiz: 80,
  );

  static const gyremoverlord = YaratikKimligi(
    kind: 13,
    slug: 'gyremoverlord',
    ad: 'Gyrem Overlord',
    bicim: 'crownedDisc',
    bolge: 2,
    sinif: DusmanSinifi.boss,
    yaricap: 25,
    atisAraligi: 2.5,
    hamHiz: 46,
  );

  static const spear = YaratikKimligi(
    kind: 14,
    slug: 'spear',
    ad: 'Spear',
    bicim: 'lanceNeedle',
    bolge: 3,
    sinif: DusmanSinifi.siradan,
    yaricap: 14,
    atisAraligi: 1.4,
    hamHiz: 128,
  );

  static const reaver = YaratikKimligi(
    kind: 15,
    slug: 'reaver',
    ad: 'Reaver',
    bicim: 'talonHook',
    bolge: 3,
    sinif: DusmanSinifi.siradan,
    yaricap: 16,
    atisAraligi: 1.5,
    hamHiz: 110,
  );

  static const exile = YaratikKimligi(
    kind: 16,
    slug: 'exile',
    ad: 'Exile',
    bicim: 'horseshoe',
    bolge: 3,
    sinif: DusmanSinifi.guclu,
    yaricap: 17,
    atisAraligi: 2.0,
    hamHiz: 68,
  );

  static const sovereigni = YaratikKimligi(
    kind: 17,
    slug: 'sovereigni',
    ad: 'Sovereign I',
    bicim: 'capitalSpine',
    bolge: 3,
    sinif: DusmanSinifi.boss,
    yaricap: 26,
    atisAraligi: 2.6,
    hamHiz: 40,
  );

  static const buccaneer = YaratikKimligi(
    kind: 18,
    slug: 'buccaneer',
    ad: 'Buccaneer',
    bicim: 'twinHull',
    bolge: 4,
    sinif: DusmanSinifi.siradan,
    yaricap: 17,
    atisAraligi: 1.8,
    hamHiz: 88,
  );

  static const rowdy = YaratikKimligi(
    kind: 19,
    slug: 'rowdy',
    ad: 'Rowdy',
    bicim: 'amoeba',
    bolge: 4,
    sinif: DusmanSinifi.siradan,
    yaricap: 16,
    atisAraligi: 1.7,
    hamHiz: 84,
  );

  static const despoiler = YaratikKimligi(
    kind: 20,
    slug: 'despoiler',
    ad: 'Despoiler',
    bicim: 'pincerJaw',
    bolge: 4,
    sinif: DusmanSinifi.guclu,
    yaricap: 18,
    atisAraligi: 1.9,
    hamHiz: 76,
  );

  static const agathon = YaratikKimligi(
    kind: 21,
    slug: 'agathon',
    ad: 'Agathon',
    bicim: 'wombEye',
    bolge: 4,
    sinif: DusmanSinifi.boss,
    yaricap: 28,
    atisAraligi: 2.7,
    hamHiz: 38,
  );

  static const inmate = YaratikKimligi(
    kind: 22,
    slug: 'inmate',
    ad: 'Inmate',
    bicim: 'boundOrb',
    bolge: 5,
    sinif: DusmanSinifi.siradan,
    yaricap: 15,
    atisAraligi: 1.9,
    hamHiz: 74,
  );

  static const charscar = YaratikKimligi(
    kind: 23,
    slug: 'charscar',
    ad: 'Charscar',
    bicim: 'scarredEgg',
    bolge: 5,
    sinif: DusmanSinifi.siradan,
    yaricap: 16,
    atisAraligi: 1.8,
    hamHiz: 82,
  );

  static const hellborn = YaratikKimligi(
    kind: 24,
    slug: 'hellborn',
    ad: 'Hellborn',
    bicim: 'hornedMass',
    bolge: 5,
    sinif: DusmanSinifi.guclu,
    yaricap: 18,
    atisAraligi: 2.0,
    hamHiz: 70,
  );

  static const skorr = YaratikKimligi(
    kind: 25,
    slug: 'skorr',
    ad: 'Skorr',
    bicim: 'stingerArc',
    bolge: 5,
    sinif: DusmanSinifi.boss,
    yaricap: 25,
    atisAraligi: 2.3,
    hamHiz: 58,
  );

  static const smelter = YaratikKimligi(
    kind: 26,
    slug: 'smelter',
    ad: 'Smelter',
    bicim: 'crucible',
    bolge: 6,
    sinif: DusmanSinifi.siradan,
    yaricap: 18,
    atisAraligi: 2.2,
    hamHiz: 56,
  );

  static const sentryraptor = YaratikKimligi(
    kind: 27,
    slug: 'sentryraptor',
    ad: 'Sentry Raptor',
    bicim: 'sweptRaptor',
    bolge: 6,
    sinif: DusmanSinifi.siradan,
    yaricap: 15,
    atisAraligi: 1.5,
    hamHiz: 124,
  );

  static const engorger = YaratikKimligi(
    kind: 28,
    slug: 'engorger',
    ad: 'Engorger',
    bicim: 'gorgedSac',
    bolge: 6,
    sinif: DusmanSinifi.guclu,
    yaricap: 19,
    atisAraligi: 2.3,
    hamHiz: 50,
  );

  static const barbtail = YaratikKimligi(
    kind: 29,
    slug: 'barbtail',
    ad: 'Barbtail',
    bicim: 'flailBall',
    bolge: 6,
    sinif: DusmanSinifi.boss,
    yaricap: 24,
    atisAraligi: 2.4,
    hamHiz: 54,
  );

  static const veilprowler = YaratikKimligi(
    kind: 30,
    slug: 'veilprowler',
    ad: 'Veil Prowler',
    bicim: 'veiledCowl',
    bolge: 7,
    sinif: DusmanSinifi.siradan,
    yaricap: 17,
    atisAraligi: 1.8,
    hamHiz: 80,
  );

  static const hexorsimulacra = YaratikKimligi(
    kind: 31,
    slug: 'hexorsimulacra',
    ad: 'Hexor Simulacra',
    bicim: 'cloneTriad',
    bolge: 7,
    sinif: DusmanSinifi.siradan,
    yaricap: 16,
    atisAraligi: 1.7,
    hamHiz: 90,
  );

  static const magmaprowler = YaratikKimligi(
    kind: 32,
    slug: 'magmaprowler',
    ad: 'Magma Prowler',
    bicim: 'segmentedWorm',
    bolge: 7,
    sinif: DusmanSinifi.guclu,
    yaricap: 17,
    atisAraligi: 1.9,
    hamHiz: 78,
  );

  static const evokexvi = YaratikKimligi(
    kind: 33,
    slug: 'evokexvi',
    ad: 'Evoke XVI',
    bicim: 'haloTower',
    bolge: 7,
    sinif: DusmanSinifi.boss,
    yaricap: 26,
    atisAraligi: 2.5,
    hamHiz: 44,
  );

  /// Otuz iki kimlik, bölge sırasıyla.
  static const hepsi = <YaratikKimligi>[
    interdictor,
    barraguda,
    warray,
    kurvex,
    subverter,
    drifter,
    obliterator,
    psychebehemot,
    ghostfin,
    prong,
    glowfin,
    gyremoverlord,
    spear,
    reaver,
    exile,
    sovereigni,
    buccaneer,
    rowdy,
    despoiler,
    agathon,
    inmate,
    charscar,
    hellborn,
    skorr,
    smelter,
    sentryraptor,
    engorger,
    barbtail,
    veilprowler,
    hexorsimulacra,
    magmaprowler,
    evokexvi,
  ];

  /// [bolge] numaralı bölgenin kadrosu — iki sıradan, bir güçlü, bir boss.
  static List<YaratikKimligi> bolgenin(int bolge) =>
      hepsi.where((y) => y.bolge == bolge).toList();

  /// [sinif]'ın kadrodaki ham hız ortalaması.
  static double hamOrtalama(DusmanSinifi sinif) {
    final uyeler = hepsi.where((y) => y.sinif == sinif);
    return uyeler.fold(0.0, (a, y) => a + y.hamHiz) / uyeler.length;
  }

  /// Bir yaratığın GERÇEK hızı — sınıf ortalamayı, kimlik sapmayı veriyor.
  ///
  /// Kaynak kadro hızları başka bir oyunun dengesinden geliyor ve sınıf
  /// sözleşmesini tutmuyor: orada bir güçlü yaratık bir sıradandan hızlı
  /// olabiliyor. Atmak yerine ÖLÇEKLİYORUZ — sınıfın ortalaması tasarımın
  /// istediği oran oluyor, sürünün içindeki çeviklik farkı korunuyor.
  static double hizFor(YaratikKimligi y) {
    final hedef = ShipStats.bastion.speed * y.sinif.hizOrani;
    return y.hamHiz / hamOrtalama(y.sinif) * hedef;
  }

  /// Kimlik numarasından kadro üyesi. Tanınmayan kimlikte `null`.
  ///
  /// Önceden hesaplanıyor: istemci bunu KARE YOLUNDA soruyor (her alienin
  /// tıklama yarıçapı, her alienin çizim ölçeği) ve otuz iki üyelik bir
  /// listeyi taramak sürü başına binlerce karşılaştırma ederdi.
  static YaratikKimligi? byKind(int kind) => _kimlikler[kind];

  static final Map<int, YaratikKimligi> _kimlikler = {
    for (final y in hepsi) y.kind: y,
  };

  /// Kimlik → yarıçap, ESKİ kayıtlara düşerek.
  ///
  /// İstemcinin tek doğru kaynağı bu. Önceden [AlienStats.byKind] soruluyordu
  /// ve o, tanımadığı her kimliği sessizce spore'a düşürüyor: kadronun on beş
  /// serpilen üyesinin **hiçbiri** doğru çözülmüyordu, hepsi 14..19 yerine
  /// spore'un 24'ünü alıyordu. Tıklama hedefi yaratıktan %26..71 büyüktü.
  ///
  /// Sessiz düşüş burada da var ama artık YALNIZ eski kayıtlar için: kadroya
  /// girmemiş spore ve leviathan hâlâ doğabiliyor.
  static double yaricapFor(int kind) =>
      byKind(kind)?.yaricap ?? AlienStats.byKind(kind).radius;

  /// Bugün gerçekten dünyada BELİREBİLEN kimlikler.
  ///
  /// Tek kısıt bölge sayısı: kadro sekiz bölgelik, dünya ondan kısa olabilir.
  ///
  /// Boss bir süre dışarıdaydı ve gerekçesi *"randevu yazılmadı"*ydı — sayaç,
  /// aralık ve "hak etti mi" sorusu yazılmış ama tik döngüsünde onları tüketen
  /// taraf hiç yazılmamıştı. Yazıldı; boss artık beliriyor, yalnız ızgaradan
  /// değil randevuyla. "Serpilme" burada DOĞUŞ YOLUNU değil, dünyada
  /// görünmeyi ölçüyor.
  ///
  /// Denetim katmanı "serpilen yaratık" satırını buradan okuyor — elle tutulan
  /// bir listeden değil, çünkü elle tutulan liste bir kez zaten bayatladı.
  static List<YaratikKimligi> serpilenler(int bolgeSayisi) => [
    for (final y in hepsi)
      if (y.bolge < bolgeSayisi) y,
  ];
}
