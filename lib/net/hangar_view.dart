import 'package:voidspace_core/voidspace_core.dart';

/// Sunucudan gelen hangar durumunun istemci tarafındaki okunur hâli.
///
/// **Hiçbir şey hesaplamıyor.** Para, etkin statlar, sahip olunan gemiler —
/// hepsi sunucunun söylediği. İstemcinin kendi hesabını yapması, hangarda
/// gösterilen sayı ile savaşta inen hasarın ayrışması demekti; ve oyuncunun
/// affetmediği hata türü tam olarak budur.
class HangarView {
  const HangarView({
    required this.credits,
    required this.premium,
    required this.hulls,
    required this.activeHullId,
    required this.inventory,
    this.malzemeler = const {},
    required this.slots,
    required this.effective,
    required this.br,
    this.seviye = 0,
    this.unvan = 0,
    this.unvanAdi = '',
    this.formasyonId,
    this.filo = const [],
    this.droidDonanimi = const {},
    this.argeDugumleri = const {},
    this.tasarimlar = const {},
    this.formasyonlar = const {},
    this.mermi = const {},
    this.seciliMermiId,
    this.roket = const {},
    this.seciliRoketId,

    this.error,
  });

  final int credits;

  /// Kıt para birimi bakiyesi — bkz. [Currency.premium].
  final int premium;

  final Set<String> hulls;
  final String activeHullId;

  /// Örnek kimliği → eşya.
  final Map<String, ItemInstance> inventory;

  /// Malzeme stoğu — kimlik → adet.
  ///
  /// Eşyalardan AYRI, tıpkı sunucudaki gibi: malzemenin örneği yok, yığılıyor.
  /// Aynı haritaya koymak istemcide de şemayı bulandırırdı.
  final Map<String, int> malzemeler;

  /// Yuva kimliği → eşya örneği kimliği.
  final Map<String, String> slots;

  /// Sunucunun hesapladığı ETKİN statlar.
  final Map<String, double> effective;

  /// SAVAŞ PUANI — haritaların kapısını açan sayı.
  ///
  /// Sunucudan geliyor, burada hesaplanmıyor: kapıya karar veren taraf ile
  /// oyuncuya "yetmiyor" diyen taraf aynı sayıyı kullanmak zorunda.
  final double br;

  /// Seviye — içeriğe kapı; sunucunun XP sayacından (10.1).
  final int seviye;

  /// Unvan indeksi ve adı — savaş puanından (10.3, 10.4).
  final int unvan;
  final String unvanAdi;

  /// Seçili droid formasyonu; `null` varsayılan (05.9).
  final String? formasyonId;

  /// Droid FİLOSU — gemiye değil oyuncuya bağlı, en çok on (04.10).
  final List<String> filo;

  /// Droid örneği → içine takılı eşya kimlikleri (05.4 s5). Droid bir
  /// taşıyıcı: standart olanda bir, elitte iki yuva.
  final Map<String, List<String>> droidDonanimi;

  /// ALINAN ArGe DÜĞÜMLERİ (05.7) — sunucunun `argeDugumleri` alanı.
  ///
  /// Kimlik kümesi, çözülmüş düğüm değil: ağacın kendisi çekirdekte
  /// (`ArGe.hepsi`) ve iki uçta da aynı. Sunucunun düğümlerin adını, maliyetini
  /// ya da σ etkisini yollaması, aynı sabit tabloyu ikinci kez taşımak olurdu
  /// — hangar durumu her işlemde baştan gidiyor.
  final Set<String> argeDugumleri;

  /// Bu oyuncunun TOPLAM ArGe puanı — seviye başına bir (05.7, 10.1).
  ///
  /// Üç sayı da (`puan`, `harcanan`, `kalan`) ÇEKİRDEKTEN çıkıyor, burada
  /// toplanmıyor: sunucu düğümü kabul ederken `ArGe.alinabilir`'e soruyor ve
  /// ekranın "yetmiyor" dediği eşik ile sunucunun reddettiği eşik aynı
  /// olmazsa, oyuncu basabildiği bir düğümden ret yer.
  int get argePuani => ArGe.puanFor(seviye);

  int get argeHarcanan => ArGe.harcanan(argeDugumleri);

  int get argeKalan => argePuani - argeHarcanan;

  /// Bu düğüm ALINABİLİR mi — sunucunun kullandığı yordamın ta kendisi.
  bool argeAlinabilir(String dugumId) =>
      ArGe.alinabilir(argeDugumleri, dugumId, seviye);

  /// FİLO TAVANI — ilan edilen tavan artı ArGe'nin izin düğümü (04.10, 05.7).
  ///
  /// Ekran uzun süre `TasarimGirdileri.droidFiloTavani`'nı doğrudan okuyordu
  /// ve o sayı ArGe'yi tanımıyor: izin düğümünü alan oyuncunun sunucusu on bir
  /// droid kabul ederken hangar hâlâ "10/10 · FİLO DOLU" diyordu. Ağacın tek
  /// görünür ödülü, ekranın göstermediği bir yuvaydı.
  /// KARAR 05.7 s2 · KARAR 04.10 s3
  int get filoTavani => ArGe.filoTavani(argeDugumleri);

  /// Sahip olunan görünüşler (15.9): satın alınan tasarım ve formasyonlar.
  /// Satılan iki droidin kendi görünüşü ve varsayılan formasyon listede
  /// olmasa da sahipli sayılıyor.
  final Set<String> tasarimlar;
  final Set<String> formasyonlar;

  bool tasarimaSahip(String id) =>
      tasarimlar.contains(id) ||
      id == DroidModeli.ucuz.name ||
      id == DroidModeli.elit.name;

  bool formasyonaSahip(String id) =>
      formasyonlar.contains(id) || id == Formasyon.varsayilan.id;

  /// Mermi STOKU — kimlik → adet; MR-1 stokta durmaz (17.2).
  final Map<String, int> mermi;

  /// Sunucunun kaydettiği seçim; okunan hâli [seciliMermi].
  final String? seciliMermiId;

  int mermiSayisi(String id) => mermi[id] ?? 0;

  /// Roket STOKU (18.4) — mermi gibi: kimlik → adet, RK-1 stokta durmaz.
  final Map<String, int> roket;
  final String? seciliRoketId;

  int roketSayisi(String id) => roket[id] ?? 0;

  /// Seçili roket — sunucuyla AYNI kural: stoğu biten seçim RK-1'e düşer.
  Roket get seciliRoket {
    final r = Roket.byId(seciliRoketId);
    if (r == null || (!r.bedava && roketSayisi(r.id) <= 0)) {
      return Roket.varsayilan;
    }
    return r;
  }

  /// Seçili mermi — sunucuyla AYNI kural: stoğu biten seçim MR-1'e düşer.
  /// İki taraf farklı okusaydı çubuk gemide olmayan bir mermiyi gösterirdi.
  Mermi get seciliMermi {
    final m = Mermi.byId(seciliMermiId);
    if (m == null || (!m.bedava && mermiSayisi(m.id) <= 0)) {
      return Mermi.varsayilan;
    }
    return m;
  }

  /// Son işlemin reddedilme sebebi — varsa oyuncuya gösterilir.
  final String? error;

  HullClass get activeHull => HullClass.byId(activeHullId) ?? HullClass.starter;

  /// [currency] cinsinden bakiye.
  int balanceOf(Currency currency) => switch (currency) {
    Currency.credit => credits,
    Currency.premium => premium,
  };

  /// Bu fiyat ÖDENEBİLİR mi.
  ///
  /// Karar `Price` üzerinden veriliyor, çıplak bir sayı üzerinden değil:
  /// 2430 NOVA'lık bir eşyayı kredi bakiyesiyle karşılaştıran bir arayüz,
  /// oyuncuya alamayacağı bir düğmeyi açık gösterirdi.
  bool canAfford(Price price) => balanceOf(price.currency) >= price.amount;

  String? itemAt(SlotRef slot) => slots[slot.id];

  ItemInstance? instance(String id) => inventory[id];

  /// Bu yuva tipine TAKILI örnek kimlikleri, yuva sırasına göre.
  ///
  /// `slots` anahtarı `SlotRef.id`; bir yuva tipinin kaç yuvası olduğunu
  /// gövde biliyor. Ekranın sorduğu soru "bu tipte neler takılı" olduğu için
  /// çeviri burada yapılıyor — her çağrı yerinde `SlotRef` kurmak, aynı
  /// döngüyü dört ekrana kopyalamak olurdu.
  List<String> fitted(SlotType type) => [
    for (var i = 0; i < activeHull.slotCount(type); i++)
      ?slots[SlotRef(type, i).id],
  ];

  /// Ekranın gösterdiği TOPLAMLAR — gövde + donanım.
  HangarTotals get totals => HangarTotals(
    hull: (effective['hull'] ?? 0).round(),
    shield: (effective['shield'] ?? 0).round(),
    speed: (effective['speed'] ?? 0).round(),
    damage: (effective['damage'] ?? 0).round(),
    battleRating: br.round(),
    hullBase: activeHull.baseHull.round(),
    shieldBase: activeHull.baseShield.round(),
    speedBase: activeHull.baseSpeed.round(),
  );

  /// Bu eşya HERHANGİ bir droidin içinde mi (05.4 s5).
  bool droidDeMi(String instanceId) =>
      droidDonanimi.values.any((l) => l.contains(instanceId));

  ItemSpec? specOf(String instanceId) {
    final item = inventory[instanceId];
    if (item == null) return null;
    return Catalogue.byId[item.specId];
  }

  /// TAKILI lazer sayısı — gemide kaç top göründüğünü belirler.
  ///
  /// Hesap `LoadoutResolver`'dan, sunucunun kullandığı yordamın TA KENDİSİ.
  /// Burada elle saymak kolay olurdu ve yanlış olurdu: geçerlilik kuralları
  /// (yuva bu gövdede var mı, eşya envanterde mi, tipi uyuyor mu) orada
  /// tanımlı ve iki ayrı sayım, hangarda gösterilen top sayısı ile savaşta
  /// ateş eden namlu sayısının sessizce ayrışması demekti.
  int get equippedLasers => LoadoutResolver.equippedCount(
    Loadout(hullId: activeHullId, slots: slots),
    inventory,
    Catalogue.byId,
    SlotType.laser,
  );

  /// Bu yuvaya takılabilecek, HENÜZ TAKILI OLMAYAN eşyalar.
  List<ItemInstance> candidatesFor(SlotType type) {
    final equipped = slots.values.toSet();
    return [
      for (final item in inventory.values)
        if (!equipped.contains(item.instanceId) &&
            Catalogue.byId[item.specId]?.slot == type)
          item,
    ];
  }

  static HangarView fromJson(Map<String, Object?> json) {
    final loadouts = json['loadouts'] as Map? ?? {};
    final activeHullId =
        json['activeHullId'] as String? ?? HullClass.starter.id;
    final active = (loadouts[activeHullId] as Map?)?['slots'] as Map? ?? {};
    final effective = json['effective'] as Map? ?? {};

    return HangarView(
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      // İKİ kese TOPLANARAK okunuyor.
      //
      // Depoda kazanılan ve satın alınan ayrı duruyor (ters ibraz için şart),
      // ama oyuncunun gördüğü tek bir sayı: cüzdanında ne kadar NOVA var.
      // Ayrımı arayüze taşımak, oyuncuya anlatacak bir şeyi olmayan bir
      // muhasebe ayrıntısını göstermek olurdu.
      premium:
          ((json['premium'] as num?)?.toInt() ?? 0) +
          ((json['premiumPurchased'] as num?)?.toInt() ?? 0),
      hulls: {for (final h in (json['hulls'] as List? ?? [])) h as String},
      activeHullId: activeHullId,
      inventory: {
        for (final e in (json['inventory'] as Map? ?? {}).entries)
          e.key as String: ItemInstance.fromJson(
            (e.value as Map).cast<String, Object?>(),
          ),
      },
      malzemeler: {
        for (final e in (json['malzemeler'] as Map? ?? {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      slots: {
        for (final e in active.entries) e.key as String: e.value as String,
      },
      effective: {
        for (final e in effective.entries)
          e.key as String: (e.value as num).toDouble(),
      },
      br: (json['br'] as num?)?.toDouble() ?? 0,
      seviye: (json['seviye'] as num?)?.toInt() ?? 0,
      unvan: (json['unvan'] as num?)?.toInt() ?? 0,
      unvanAdi: json['unvanAdi'] as String? ?? '',
      formasyonId: json['formasyonId'] as String?,
      filo: [
        for (final id in (json['filo'] as List? ?? const [])) id as String,
      ],
      droidDonanimi: {
        for (final e in (json['droidDonanimi'] as Map? ?? const {}).entries)
          e.key as String: [for (final v in e.value as List) v as String],
      },
      argeDugumleri: {
        for (final v in (json['argeDugumleri'] as List? ?? const []))
          v as String,
      },
      tasarimlar: {
        for (final v in (json['tasarimlar'] as List? ?? const [])) v as String,
      },
      formasyonlar: {
        for (final v in (json['formasyonlar'] as List? ?? const []))
          v as String,
      },
      mermi: {
        for (final e in (json['mermi'] as Map? ?? {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      seciliMermiId: json['seciliMermi'] as String?,
      roket: {
        for (final e in (json['roket'] as Map? ?? {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      seciliRoketId: json['seciliRoket'] as String?,

      error: json['error'] as String?,
    );
  }
}


/// Gemi statlarının EKRANA giden hâli — toplam ve donanımın katkısı.
///
/// **Neden katkı ayrı yazılıyor.** Oyuncunun hangarda sorduğu soru "gemim ne
/// kadar güçlü" değil "TAKTIĞIM ŞEY ne kattı": toplam sayı tek başına
/// donanımın işe yarayıp yaramadığını söylemiyor. Katkı, kararın geri
/// bildirimi.
///
/// **Katkı yoksa boş dize.** `+0` yazmak katkısız bir parçayı katkılı
/// gösterirdi — sıfır bir katkı değil, katkının yokluğu.
class HangarTotals {
  const HangarTotals({
    required this.hull,
    required this.shield,
    required this.speed,
    required this.damage,
    required this.battleRating,
    required this.hullBase,
    required this.shieldBase,
    required this.speedBase,
  });

  final int hull;
  final int shield;
  final int speed;
  final int damage;

  /// Savaş puanı — `sqrt(saldırı × dayanıklılık)` (`CombatGlossary`).
  final int battleRating;

  /// Gövdenin donanımsız hâli; katkı bunlardan çıkıyor.
  final int hullBase;
  final int shieldBase;
  final int speedBase;

  static String _delta(int toplam, int taban) {
    final fark = toplam - taban;
    return fark == 0 ? '' : (fark > 0 ? '+$fark' : '$fark');
  }

  String get hullDelta => _delta(hull, hullBase);
  String get shieldDelta => _delta(shield, shieldBase);
  String get speedDelta => _delta(speed, speedBase);

  /// Hasarın gövde tabanı YOK: silah takılmadan gemi ateş etmiyor, yani
  /// hasarın tamamı donanımın katkısı.
  String get damageDelta => damage == 0 ? '' : '+$damage';
}
