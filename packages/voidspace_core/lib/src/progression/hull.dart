import 'dart:math' as math;

import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import '../design/turetilenler.dart';
import 'referans_cozumu.dart';
import 'item.dart';

/// Gövde sınıfı ve YUVA HARİTASI.
///
/// Yuva sayısının kademeyle artması, gövdenin sadece istatistik değil
/// KAPASİTE de vermesini sağlıyor — ve kapasite, sayıdan çok daha güçlü bir
/// ödül hissi.
///
/// **Sekiz kademenin sekizi de aynı yerden türüyor** (alan 04): can, kalkan
/// ve hız çapa × kademe çarpanı; yuvalar toplamdan dağıtılıyor; lazer yuvası
/// çizimdeki namlu sayısına sabit. Elle duran yalnız üç şey var: ilk üç
/// gövdenin yuva TOPLAMI (çizime kilitli), fiyatları ve adları.
///
/// Uzun süre ilk üç gövdenin statları elle yazılıydı ve merdiven onları
/// açıklamıyordu: Vanguard 16.000'de dururken merdiven 30.000, Spectre
/// 21.000'de dururken 74.760 diyordu ve dördüncü kademe 186.819'a sıçrıyordu.
/// Karar 04.12: merdiven kazandı. Yaratıklar rank çarpanıyla büyüdüğü için
/// öldürme süresi ancak gövde de aynı merdiveni izlerse sabit kalıyor.
///
/// Tasarım belgesindeki tablo droid'leri de içeriyor (SS gövdede 47 yuva).
/// Buradaki harita bugün karşılığı olan kısım: droid sistemi gelmeden droid
/// yuvası açmak, doldurulamayan bir kap olurdu.
/// KARAR 04.1 s1 · KARAR 04.11 s1 · KARAR 04.12 s2
class HullClass {
  const HullClass({
    required this.id,
    required this.name,
    required this.tier,
    required this.laserSlots,
    required this.generatorSlots,
    required this.launcherSlots,
    required this.cpuSlots,
    required this.kademeCarpani,
    double? baseHull,
    required this.baseShield,
    required this.baseSpeed,
    required this.price,
  }) : _baseHull = baseHull;

  /// Yer tutucu: [sablon]ın yuvaları ve kalkanıyla, canı SIFIR bir kopya.
  ///
  /// Referans çözümü gövde canını çözerken gövdeyi okuyamaz (döngü); DPS ve
  /// kalkan cana bağlı olmadığı için sıfır canlı bir kopya yeter.
  HullClass.yerTutucu(HullClass sablon)
    : this(
        id: sablon.id,
        name: sablon.name,
        tier: sablon.tier,
        laserSlots: sablon.laserSlots,
        generatorSlots: sablon.generatorSlots,
        launcherSlots: sablon.launcherSlots,
        cpuSlots: sablon.cpuSlots,
        kademeCarpani: sablon.kademeCarpani,
        baseHull: 0,
        baseShield: sablon.baseShield,
        baseSpeed: sablon.baseSpeed,
        price: sablon.price,
      );

  final String id;
  final String name;
  final ItemTier tier;

  final int laserSlots;
  final int generatorSlots;
  final int launcherSlots;
  final int cpuSlots;

  /// Kademe çarpanı — rank merdiveninin kademe normalizasyonu (04.7).
  final double kademeCarpani;

  final double? _baseHull;

  /// Taban can: gövde çapası × kademe çarpanı.
  ///
  /// Çapa tam donanımlı referansın TTK kısıtından çözülüyor (08.5,
  /// `ReferansCozumu`); burada saklanmıyor, okunuyor. Alan olsaydı gövde
  /// kurulurken çözüm, çözüm kurulurken gövde gerekir ve ikisi birbirini
  /// beklerdi. KARAR 08.5 s2
  double get baseHull =>
      _baseHull ?? ReferansCozumu.govdeCapasi * kademeCarpani;
  final double baseShield;
  final double baseSpeed;

  /// Hangar fiyatı (kredi). `null` = SATIN ALINAMAZ.
  ///
  /// Sıfır ile `null` farklı: sıfır "bedava" (başlangıç gemisi), `null`
  /// "henüz satışta değil". Merdivenden türetilen kademeler `null` taşıyor —
  /// tanımlılar ama alınamıyorlar, çünkü onlara uygun içerik (harita, yaratık
  /// kademesi) yok.
  final int? price;

  /// Bu gövde hangarda SATIN ALINABİLİR mi.
  bool get satinAlinabilir => price != null;

  /// KARAR 04.2 s1
  int slotCount(SlotType type) => switch (type) {
    SlotType.laser => laserSlots,
    SlotType.generator => generatorSlots,
    SlotType.launcher => launcherSlots,
    SlotType.cpu => cpuSlots,
    // Droid GÖVDEYE takılmaz: filo oyuncunun, gemi değişince kalır (04.10).
    SlotType.droid => 0,
  };

  int get repairCost => (baseHull * 0.01).round();

  int get totalSlots => laserSlots + generatorSlots + launcherSlots + cpuSlots;

  /// Başlangıç gemisi — kademe 1, çapa. Her hesap bununla açılıyor.
  static final bastion = _kur(0, id: 'bastion', price: 0);
  static final vanguard = _kur(1, id: 'vanguard', price: 240000);
  static final spectre = _kur(2, id: 'spectre', price: 980000);

  /// ÇİZİME KİLİTLİ üç gövde — yuva TOPLAMLARI sanattan.
  ///
  /// Toplam sanattan geliyor ama dağılımı ve statları merdivenden: bu üçünün
  /// öteki beşten tek farkı toplamlarının elle konması ve fiyatlarının olması.
  /// Sanat sayısı ayrı duruyor: [sanatiOlanKademeSayisi].
  static final List<HullClass> cizilenler = [bastion, vanguard, spectre];

  /// İlk üç kademenin yuva toplamı — çizime kilitli.
  ///
  /// 12 · 16 · 18: lazer yuvası namlu sayısı demek ve o sayı modelden değil
  /// çizimden geliyor. Droid burada YOK: filo gövdeye değil oyuncuya bağlı
  /// (04.10); tasarımın 14 · 19 · 22'si eski droid-yuvası modeliydi.
  static const List<int> sanatYuvalari = [12, 16, 18];

  /// GÖVDE ÇİZİMİ olan kademe sayısı.
  ///
  /// Çekirdek pakette bildiriliyor ama gerçeği istemci biliyor: sayı
  /// `lib/game/art/govde_tasarimlari.dart` kaydındaki `cizildi` bayrağından
  /// geliyor ve `test/govde_tasarimlari_test.dart` ikisinin ayrışmadığını
  /// doğruluyor. Çekirdek istemciyi okuyamaz (yön yanlış olurdu), o yüzden
  /// bildirim burada, doğrulama orada.
  ///
  /// Bugün BİR. Sekiz kademenin tasarımı belli ve yeri belli — atlas tek gövde
  /// bloğu pişirdiği için kalan yedisinin sanatı taşınamadı.
  static const int sanatiOlanKademeSayisi = 1;

  /// SEKİZ gövdenin adı — çizimi gelmemiş olanlarınki de.
  ///
  /// Bölge adları gibi: ad ucuz, çizim pahalı. Adı hazır tutmak, türetilen
  /// gövdenin ekranda "Gövde 4" diye görünmesini engelliyor — o ad oyuncuya
  /// bir gemi değil bir yer tutucu olduğunu söylerdi.
  static const List<String> adlar = [
    'Bastion',
    'Vanguard',
    'Spectre',
    'Aegis',
    'Wraith',
    'Colossus',
    'Nemesis',
    'Sovereign',
  ];

  /// BÜTÜN gövde kademeleri.
  ///
  /// Türetilenlerin fiyatı `null` — SATIN ALINAMIYORLAR. Sebebi ölçülmüş bir
  /// kısıt: üst kademe bir gemi için içerik henüz yok.
  ///
  /// `late final`, getter DEĞİL: liste türetilirken `pow` çağrılıyor ve
  /// [byId] her `Loadout.hull` erişiminde bu listeyi geziyor — mağaza ekranı
  /// da kare başına indeksliyor. Her erişimde yeniden kurmak, sabit bir
  /// tabloyu sıcak yola koymak olurdu.
  static final List<HullClass> all = [
    ...cizilenler,
    for (var k = cizilenler.length; k < TasarimGirdileri.govdeKademeSayisi; k++)
      _kur(k, id: 'govde-${k + 1}', price: null),
  ];

  /// [kademe] numaralı gövdeyi merdivenden kur.
  ///
  /// Statlar: çapa × kademe çarpanı; hız kendi küçük merdiveniyle
  /// ([TasarimGirdileri.hizArtisi]) — hız sistem kanalında, bütçe dışı ve
  /// tempo belirliyor; rank çarpanıyla büyüseydi sekizinci kademe altı yüz kat
  /// hızlı olurdu.
  ///
  /// Yuvalar: lazer sanata sabit ([TasarimGirdileri.lazerYuvaSayisi]),
  /// roketatar bir, kalan yuvalar jeneratör ile CPU arasında
  /// [TasarimGirdileri.jeneratorYuvaPayi] ile bölünüyor (karar 04.9: sanat
  /// kazandı, açılan yuva lazere gitmiyor).
  ///
  /// Gövde kademesi rank AİLESİYLE ilerliyor, ham indisle değil: Bastion C-I,
  /// Vanguard B-I, Spectre A-I. Merdiven yirmiye uzayınca `values[kademe]`
  /// dördüncü gövdeye C ailesinin dördüncü basamağını verecekti.
  /// KARAR 04.7 s2 · KARAR 04.8 s1 · KARAR 04.9 s2
  static HullClass _kur(int kademe, {required String id, required int? price}) {
    final carpan = Turetilenler.govdeKademeCarpanlari[kademe];
    final lazer = TasarimGirdileri.lazerYuvaSayisi;
    const roketatar = 1;
    final kalan = yuvaSayisi(kademe) - lazer - roketatar;
    final jenerator = (kalan * TasarimGirdileri.jeneratorYuvaPayi).round();
    return HullClass(
      id: id,
      name: adlar[kademe],
      // Etiket BANDIN İLK RANKI: referans oyuncunun bu gövdeyi aldığı rank
      // (04.7, 10.6). Aile başından (kademe × 3) gelirken beşinci gövde
      // "SS-I" yazıyor ve S-II oyuncusunun gövdesi oluyordu; etiket güce
      // girmiyor ama yalan söylüyordu (borç defteri B10). KARAR 04.7 s2
      tier:
          ItemTier.values[TuretilenTablolar.rankAraligiFor(
            kademe,
            rankSayisi: Turetilenler.rankSayisi,
            kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
          ).$1],
      laserSlots: lazer,
      generatorSlots: jenerator,
      launcherSlots: roketatar,
      cpuSlots: kalan - jenerator,

      // Gövde çapası TTK kısıtından çözülmüş (08.5) ve okunuşta türüyor
      // (`baseHull`); kalkan çapası girdi.
      kademeCarpani: carpan,
      baseShield: TasarimGirdileri.kalkanCapasi * carpan,
      baseSpeed:
          TasarimGirdileri.hizCapasi *
          math.pow(TasarimGirdileri.hizArtisi, kademe),
      price: price,
    );
  }

  /// Gövde kademesi sayısı — [TasarimGirdileri.govdeKademeSayisi].
  static int get hedefKademeSayisi => TasarimGirdileri.govdeKademeSayisi;

  /// [kademe] numaralı gövdenin yuva TOPLAMI.
  ///
  /// İlk üçü SANATA kilitli ([sanatYuvalari]); dördüncüden itibaren kademe
  /// başına [TasarimGirdileri.yuvaArtisi] kadar açılıyor.
  /// KARAR 04.8 s1
  static int yuvaSayisi(int kademe) {
    if (kademe < 0 || kademe >= TasarimGirdileri.govdeKademeSayisi) {
      throw ArgumentError.value(kademe, 'kademe', 'aralık dışı');
    }
    if (kademe < sanatYuvalari.length) return sanatYuvalari[kademe];
    return sanatYuvalari.last +
        (kademe - sanatYuvalari.length + 1) * TasarimGirdileri.yuvaArtisi;
  }

  static HullClass? byId(String id) {
    for (final hull in all) {
      if (hull.id == id) return hull;
    }
    return null;
  }

  /// Başlangıç gemisi — her hesap bununla açılıyor.
  static final HullClass starter = bastion;
}
