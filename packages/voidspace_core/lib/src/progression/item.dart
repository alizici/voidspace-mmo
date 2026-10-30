import 'dart:math' as math;

import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import 'currency.dart';

/// Eşya ve gövde kalitesi — **rank merdiveninin bir basamağı**.
///
/// C0 ile son basamağın +15'i arasında 10,75× fark var. Bu bilinçli olarak
/// büyük — aradaki mesafe ilerlemenin yakıtı. Eşya başına büyük olan bu fark,
/// çok yuvaya yayılıp geometrik ortalamadan geçince toplam güç farkı çok daha
/// dar bir banda iniyor.
///
/// Çarpan elle YAZILMIYOR ve yazılamaz: `rankArtisi` üssünün bu basamaktaki
/// değeri. Zorunlu, çünkü bir eşyanın maliyeti ile ait olduğu bandın geliri
/// AYNI merdivenden gelmek zorunda. Ayrı yazıldıklarında — ve bir süre öyleydi
/// (1,00 · 1,45 · 2,10 · 3,00 · 4,30 elle konmuştu) — bugün fark görünmüyor
/// ama merdiven yirmi ranka uzadığında maliyet 13 kat, gelir 1.048 kat büyür:
/// +15 beşinci banttan sonra tek nesil bütçesinin içine düşer ve tavan
/// sonrası kuyruk buharlaşır.
///
/// Bu yüzden basamak sayısı [Turetilenler.rankSayisi] ile EŞİT olmak zorunda.
/// Kademe normalizasyonunun dördüncü uygulaması; testi bunu bekliyor.
///
/// KARAR 06.1 s1 · KARAR 10.2 s1
enum ItemTier {
  cI,
  cII,
  cIII,
  bI,
  bII,
  bIII,
  aI,
  aII,
  aIII,
  sI,
  sII,
  sIII,
  ssI,
  ssII,
  ssIII,
  sssI,
  sssII,
  sssIII,

  /// TEKİL rank, kalite değil. Ailelerin üstünde tek başına duruyor: 726,7×.
  kirmizi,

  /// Merdivenin tepesi: 1.047,9×. İki yıllık hedefin geldiği yer.
  parlayanPembe;

  /// Bu basamağın güç ve maliyet çarpanı — `rankArtisi^index`.
  double get multiplier =>
      TuretilenTablolar.rankCarpaniFor(index, TasarimGirdileri.rankArtisi);

  /// HARF AİLESİ — C·B·A·S·SS·SSS, sıfırdan beşe.
  ///
  /// Ailenin kendisi bir tasarım birimi: eşyanın kaç alt statı olduğu gibi
  /// KABA nitelikler aileye bağlı, ince güç farkı ise ailenin içindeki üç
  /// basamağa. Kırmızı ve Parlayan Pembe tekil rank — ailesizler, ve aile
  /// soran her hesapta en üst ailenin devamı sayılıyorlar.
  int get aile => index ~/ aileBasamagi < aileSayisi
      ? index ~/ aileBasamagi
      : aileSayisi - 1;

  /// KAPAK TAŞI mı — Kırmızı ve Parlayan Pembe. Aile değil, tekil rank:
  /// alt stat sayısı ve kalite bandı ailelerin bir adım üstünde.
  bool get kapakTasi => index >= aileSayisi * aileBasamagi;

  /// Aile başına basamak: C-I · C-II · C-III.
  static const int aileBasamagi = 3;

  /// Harf ailesi sayısı — C·B·A·S·SS·SSS.
  static const int aileSayisi = 6;

  /// Ailelerin ÜSTÜNDEKİ tekil ranklar — Kırmızı ve Parlayan Pembe.
  static const int tekilRank = 2;

  /// Oyuncunun gördüğü ad.
  String get label => switch (this) {
    kirmizi => 'KIRMIZI',
    parlayanPembe => 'PARLAYAN PEMBE',
    _ => '${_harf.toUpperCase()}-$_basamak',
  };

  /// `ssIII` → `ss`. Harf küçük, rakam büyük — ayrım oradan.
  String get _harf => name.substring(0, name.indexOf('I'));

  /// `ssIII` → `III`.
  String get _basamak => name.substring(name.indexOf('I'));
}

/// Bir eşyanın girebileceği yuva türü.
enum SlotType {
  /// Gemi lazer yuvası.
  laser,

  /// Jeneratör — kalkan YA DA hız. Aynı yuvaya iki farklı şey girmesi
  /// donatımın en iyi kararı: ekleme değil TAKAS üretiyor.
  generator,

  /// Roketatar — tek yuva.
  launcher,

  /// CPU modülü — fayda yuvası.
  cpu,

  /// Droid yuvası — droidin kendisi takılır; statı droid kapsamına yazar
  /// (04.10, 05.4).
  droid,
}

/// Bir eşyanın TASARIMI. Örneği değil.
///
/// Motor eşya isimlerini bilmiyor, yalnız bu şemayı okuyor.
/// KARAR 06.3 s1
class ItemSpec {
  const ItemSpec({
    required this.id,
    required this.name,
    required this.slot,
    required this.tier,
    required this.mainStat,
    this.subStatPool = const [],
    this.variant,
    this.currency = Currency.credit,
  });

  final String id;
  final String name;

  /// Hangi yuvaya girer.
  final SlotType slot;

  final ItemTier tier;

  /// Bu eşyanın HANGİ parayla alındığı.
  ///
  /// Varsayılan kredi ve öyle kalmalı: mağazanın gövdesi oynayarak
  /// alınabilir olmak zorunda. Kıt paraya bağlanan bir eşya, ilerlemenin
  /// zorunlu bir basamağı OLAMAZ — yalnız üstüne konan bir katman.
  final Currency currency;

  /// Ana stat BELİRLENİMCİ: hangi lazeri alırsan hasarını bilirsin.
  /// Derinlik alt statlardan gelir.
  final String mainStat;

  /// Alt statların çekilebileceği havuz.
  ///
  /// Havuz KISITLI olmak zorunda: bir lazer kalkan yenilenmesi çeviremez.
  /// Aksi hâlde bütün eşyalar birbirinin aynısı olur ve yuva kimliği kaybolur.
  ///
  /// KARAR 06.7 s1
  final List<String> subStatPool;

  /// Jeneratör için: `kalkan` ya da `hiz`. Diğerlerinde `null`.
  /// KARAR 04.3 s1
  final String? variant;
}

/// Oyuncunun SAHİP OLDUĞU bir eşya.
///
/// Şemadan ayrı: aynı `ItemSpec`'ten yüzlerce örnek olabilir, her biri farklı
/// seviyede ve farklı alt statlarla.
/// KARAR 06.3 s1
class ItemInstance {
  const ItemInstance({
    required this.instanceId,
    required this.specId,
    this.level = 0,
    this.altStatRolleri = const {},
    this.kilitler = const {},
    this.taban = false,
    this.dayaniklilik = tamDayaniklilik,
    this.tasarim,
    this.eskiAltStatlar = const {},
  });

  /// Bu ÖRNEĞİN kimliği — envanterde ve yuvada buna göre bulunuyor.
  final String instanceId;

  /// Hangi tasarımdan.
  final String specId;

  /// 0..15.
  final int level;

  /// Çevrilmiş alt statların KALİTE ROLÜ — stat kimliği → 0…1 (07.5).
  ///
  /// Değer değil rol saklanıyor: değer her okunuşta rank, gövde katsayısı ve
  /// artı adımından türer (`ItemBudget.altStatTabani` × rol), gövde değişince
  /// kendiliğinden düzelir, artı basma taşımak zorunda kalmaz. Bir zamanlar
  /// mutlak değer saklanıyordu ve çevirme anındaki gövdenin katsayısını
  /// donduruyordu (borç defteri B3). Boşsa alt statlar örnek kimliğinden
  /// türetilir.
  final Map<String, double> altStatRolleri;

  /// ESKİ kayıtların mutlak alt stat değerleri — yalnız yüklemede.
  ///
  /// Serileştirilmiyor; `Hangar.fromJson` o anki gövdeyle role çevirip
  /// [altStatRolleri]'ne taşıyor ve bu alan boşalıyor.
  final Map<String, double> eskiAltStatlar;

  /// KİLİTLİ alt statlar — çevirme bunlara dokunmuyor (karar 07.5).
  ///
  /// Eşyada kalıcı: oyuncu iyi çıkan rolü kilitler, kalanı çevirir; açmak
  /// bedava. Bedel çevirme anında kilit sayısına göre hesaplanıyor.
  /// KARAR 07.5 s2
  final Set<String> kilitler;

  /// TABAN eşya — raftan alınmış (15.2): alt statı yok, derinlik satılmıyor.
  ///
  /// Ganimetten düşen eşyadan bu bayrakla ayrılıyor; rank ve ana stat aynı,
  /// eksik olan tek şey alt stat. Bayrak kalıcı: artı basma onu değiştirmez,
  /// çevirme çevirecek stat bulamaz.
  final bool taban;

  /// DAYANIKLILIK — yalnız droidin taşıdığı, sıfırlanınca eşyayı silen sayaç.
  ///
  /// Droidin canı yok (05.10): dövüşte hedef alınmıyor, hasar almıyor. Ama
  /// bedava da değil: sahibi her öldüğünde
  /// [TasarimGirdileri.droidAsinmaPayi] puan iniyor ve sıfırda droid yok
  /// oluyor. Sıfırın üstünde hiçbir şeyi değiştirmiyor — droid son puanında
  /// da tam gücünde vuruyor; azalan güç ikinci bir eğri olurdu ve sayacın
  /// anlamını "ne zaman biteceğim"den "ne kadar zayıfladım"a kaydırırdı.
  ///
  /// Droid dışındaki eşyada hep [tamDayaniklilik]: alan her örnekte duruyor
  /// ama yalnız filoda aşınıyor. Ayrı bir kayıt tutmak, aynı eşya listesini
  /// iki yerden okumak demekti.
  /// KARAR 05.10 s1
  final int dayaniklilik;

  /// Yeni bir droidin dayanıklılığı — yüzdenin tanımı, girdi değil.
  static const int tamDayaniklilik = 100;

  /// SEÇİLİ TASARIM — droidin giydiği çizim (15.9). `null` ise tasarımın
  /// kendi görünüşü (`ItemSpec.variant`) geçerli.
  ///
  /// Örneğe yazılıyor, hesaba değil: aynı oyuncunun iki droidi iki ayrı
  /// tasarım giyebilsin diye. Sahiplik hesapta (`Hangar.tasarimlar`),
  /// seçim örnekte.
  /// KARAR 15.9 s1
  final String? tasarim;

  /// Aşınmış mı — onarım düğmesi bunu soruyor.
  bool get asinmis => dayaniklilik < tamDayaniklilik;

  ItemInstance copyWith({
    int? level,
    Map<String, double>? altStatRolleri,
    Set<String>? kilitler,
    int? dayaniklilik,
    String? tasarim,
  }) => ItemInstance(
    instanceId: instanceId,
    specId: specId,
    level: level ?? this.level,
    altStatRolleri: altStatRolleri ?? this.altStatRolleri,
    kilitler: kilitler ?? this.kilitler,
    taban: taban,
    dayaniklilik: dayaniklilik ?? this.dayaniklilik,
    tasarim: tasarim ?? this.tasarim,
  );

  Map<String, Object?> toJson() => {
    'instanceId': instanceId,
    'specId': specId,
    'level': level,
    // Rol saklanıyor, değer değil (07.5). Anahtar eskisinden farklı: eski
    // `subStats` mutlak değerdi ve yüklemede role çevriliyor.
    if (altStatRolleri.isNotEmpty) 'altStatRolleri': altStatRolleri,
    // Boşken yazılmıyor: eski kayıtların biçimi değişmesin.
    if (kilitler.isNotEmpty) 'kilitler': kilitler.toList(),
    // Yalnız taban eşyada yazılıyor, aynı sebeple.
    if (taban) 'taban': true,
    // Aşınmamış eşya alanı yazmıyor: eski kayıtlar ve bütün gövde eşyaları
    // tam dayanıklılıkta ve dosyada tek bayt yer kaplamıyor.
    if (asinmis) 'dayaniklilik': dayaniklilik,
    if (tasarim != null) 'tasarim': tasarim,
  };

  /// KALDIRILAN tasarımların bugünkü karşılığı — kayıt göçü.
  ///
  /// Bir tasarım katalogdan çıkınca o tasarımı taşıyan eski kayıtlar YETİM
  /// kalıyor: `Catalogue.byId` onları bulamıyor ve okuyan her yer ya çöküyor
  /// ya sessizce atlıyor. İkisi de kabul edilemez — oyuncunun dört bin
  /// droidi bir katalog değişikliğinde buharlaşamaz.
  ///
  /// Bugünkü tek göç: droid çeşidi ikiye indi (05.8 s2) ve C-II ile C-III
  /// droidleri elle yazılan listeden düştü; yerlerine merdivenden türeyen
  /// aynı rankın droidleri geçti. Rank ve yuva aynı, değişen yalnız çizim.
  /// KARAR 05.8 s2
  static const Map<String, String> tasarimGocu = {
    'dr2': 'droid-cII',
    'dr3': 'droid-cIII',
  };

  static ItemInstance fromJson(Map<String, Object?> json) => ItemInstance(
    instanceId: json['instanceId']! as String,
    // Kaldırılan tasarım bugünküne çevriliyor; tanınan kimlik olduğu gibi.
    specId: () {
      final ham = json['specId']! as String;
      return tasarimGocu[ham] ?? ham;
    }(),
    level: (json['level'] as num?)?.toInt() ?? 0,
    altStatRolleri: {
      for (final e in (json['altStatRolleri'] as Map? ?? {}).entries)
        e.key as String: (e.value as num).toDouble(),
    },
    eskiAltStatlar: {
      for (final e in (json['subStats'] as Map? ?? {}).entries)
        e.key as String: (e.value as num).toDouble(),
    },
    kilitler: {
      for (final k in (json['kilitler'] as List? ?? const [])) k as String,
    },
    taban: json['taban'] == true,
    // Alan yoksa TAM: dayanıklılık gelmeden önce yazılmış her droid
    // yıpranmamış sayılıyor. Sıfır yazan kayıt da okunuyor — silinme kararı
    // yükleyicinin değil, aşındıranın.
    dayaniklilik:
        (json['dayaniklilik'] as num?)?.toInt().clamp(0, tamDayaniklilik) ??
        tamDayaniklilik,
    tasarim: json['tasarim'] as String?,
  );
}

/// Seviye matematiği.
///
/// On beş seviye, üç kademe. Artış oranı yükselirken maliyet çok daha hızlı
/// yükseliyor: para harcanacak yer açılıyor ama fark sınırlı kalıyor.
///
/// **Başarısızlık şansı YOK.** Bu tür oyunların çoğu belirli seviyelerin
/// üstünde yükseltme başarısızlığı ve eşya kırılması koyuyor. Konmadı, iki
/// sebeple: başarısızlık tavanı doğrudan paraya çevirir (koruma tılsımı
/// satılır), ve mağaza yorumlarını kalıcı olarak bozan tek mekanik budur.
/// Aynı para sinki katlanan maliyetle kuruluyor — sıfır öfke.
abstract final class ItemLevels {
  static const int max = 15;

  /// [level] sonundaki kümülatif stat çarpanı.
  ///
  /// Kalibrasyon (1-5) seviye başına +%8, yeniden yapım (6-10) +%10, aşırı
  /// yükleme (11-15) +%12.
  ///
  /// **Artışlar TOPLANIYOR, çarpılmıyor** — alan 07'nin kararı. Aradaki fark
  /// +15'te 2,50× ile 4,170× arasında, ve ikincisi alan 06'nın ilan ettiği
  /// güç tavanını deliyordu. Biçim [TasarimGirdileri.artiKazancBicimi]'nden
  /// okunuyor: karar tepe tabloda duruyor, burada değil.
  /// KARAR 07.3 s1
  static double multiplier(int level) {
    final tavan = level.clamp(0, max);
    return switch (TasarimGirdileri.artiKazancBicimi) {
      ArtiKazancBicimi.toplamsal => () {
        var toplam = 0.0;
        for (var l = 1; l <= tavan; l++) {
          toplam += _stepFor(l);
        }
        return 1 + toplam;
      }(),
      ArtiKazancBicimi.bilesik => () {
        var carpim = 1.0;
        for (var l = 1; l <= tavan; l++) {
          carpim *= 1 + _stepFor(l);
        }
        return carpim;
      }(),
    };
  }

  /// Bir seviyenin kazanç ADIMI. Kategorik — üç kademe, üç oran.
  static double stepFor(int level) => _stepFor(level);

  static double _stepFor(int level) {
    if (level <= 5) return 0.08;
    if (level <= 10) return 0.10;
    return 0.12;
  }

  /// [level]'den [level]+1'e çıkmanın maliyeti (kredi).
  ///
  /// `c₀ × tierÇarpanı × b^L`. İki kol AYRI:
  /// [TasarimGirdileri.maliyetHacmi] toplam sinki,
  /// [TasarimGirdileri.maliyetSekli] son seviyelerin değer bozulmasını
  /// belirliyor.
  ///
  /// Tek kolla (yalnız `b`) yapıldığında ikisi birbirini eziyordu: bugünkü
  /// 1,350 hacmi tutturuyor ama son yükseltmeyi ilkinden **44,5 kat** kötü
  /// değer yapıyordu — yani +11'den sonrası ölü sistem. Ayrıldıktan sonra
  /// bozulma 12 kata iniyor ve toplam sink değişmiyor.
  /// KARAR 07.4 s1
  static int upgradeCost(int level, ItemTier tier) {
    if (level >= max) return 0;
    return (TasarimGirdileri.maliyetHacmi *
            tier.multiplier *
            math.pow(TasarimGirdileri.maliyetSekli, level))
        .round();
  }

  /// Bir yükseltmenin GÜÇ BAŞINA kredisi — değer eğrisinin okunduğu sayı.
  ///
  /// `maliyet ÷ kazanç adımı`. Son yükseltmenin bu oranı ilkine bölününce
  /// "değer bozulması" çıkıyor: alanın tek sayılık sağlık ölçüsü.
  static double kredilikKat(int level, ItemTier tier) =>
      upgradeCost(level, tier) / _stepFor(level + 1);

  /// DEĞER BOZULMASI — son yükseltmenin değeri ilkinin kaç katı kötü.
  ///
  /// Çok düşükse eşya yükseltmek hiç bitmez ve enflasyon yakalanamaz; çok
  /// yüksekse üst seviyeler kimsenin dokunmadığı ölü içerik olur.
  static double get degerBozulmasi =>
      kredilikKat(max - 1, ItemTier.cI) / kredilikKat(0, ItemTier.cI);

  /// Sıfırdan [level]'e kadar toplam maliyet.
  static int totalCost(int level, ItemTier tier) {
    var total = 0;
    for (var l = 0; l < level.clamp(0, max); l++) {
      total += upgradeCost(l, tier);
    }
    return total;
  }

  /// Bu seviyede alt statlardan biri güçlenir mi.
  ///
  /// Her üç seviyede bir, toplam beş güçlenme. **Tek rastgele, çift değil:**
  /// hangi alt statın güçleneceği rastgele, NE KADAR güçleneceği sabit.
  /// İkisi de rastgele olunca yanlış stata düşük değer gelmesi çifte hayal
  /// kırıklığı üretiyor.
  /// KARAR 07.6 s1
  static bool isSubStatStep(int level) => level > 0 && level % adimAraligi == 0;

  /// Kaç seviyede bir alt stat güçleniyor.
  static const int adimAraligi = 3;

  /// Toplam güçlenme adımı — on beş seviyede beş.
  static int get adimSayisi => max ~/ adimAraligi;

  /// [level]'e kadar açılmış adım sayısı.
  static int adimSayisiFor(int level) => level.clamp(0, max) ~/ adimAraligi;
}
