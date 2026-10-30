/// TASARIM ALANLARI HARİTASI — belge mimarisinin koddaki karşılığı.
///
/// Harita belgesinin kendi cümlesi: *"Bu harita o üst tablo."* Alan sırası bir
/// tercih değil, `aşağı yalnız yukarıyı okur` kuralının ta kendisi — ve bir
/// kural ancak makine denetlediğinde kural olarak kalır. Burada duran şey o
/// denetimin okuduğu tablo.
///
/// **Bir alan, sahiplendiği kararla tanımlanır.** Aynı kararı iki belge
/// veriyorsa ikisi de yanlıştır; bu yüzden her alanın burada TEK bir satırı
/// var ve bağımlılıkları o satırda duruyor.
library;

/// Yığındaki katman. Sıra zorunlu: her katman bir üstünün BİRİMİYLE konuşur.
///
/// Savaş ölçü birimini verir, Büyüme referans build'i, Dünya hedef zorluğu,
/// Ekonomi öldürme hızını. Üsttekini yazmadan alttakini yazamazsın — boss canı
/// referans build olmadan, düşüş oranı da boss canı olmadan türetilemez.
enum TasarimKatmani {
  /// 战斗数值 — ölçü birimi.
  savas('Savaş'),

  /// 成长数值 — oyuncu gücü.
  buyume('Büyüme'),

  /// 关卡 · 怪物数值 — içerik.
  dunya('Dünya'),

  /// 经济数值 — akış.
  ekonomi('Ekonomi'),

  /// 平衡 — doğrulama. Sistem değil, denetim.
  denge('Denge');

  const TasarimKatmani(this.label);

  final String label;
}

/// Bir alanın belge durumu.
///
/// Harita belgesinin `07 · Teşhis` bölümü bunu elle sayıyordu. Elle sayılan
/// her şey eskir; burada duran hâli koddan okunuyor.
enum BelgeDurumu {
  /// Kural belgesi ve sayı tablosu yazıldı, kod uygulandı.
  yazildi,

  /// Henüz yazılmadı — bu alandan sayı çeken kod OLAMAZ.
  bekliyor,
}

/// Haritadaki bir alan.
class TasarimAlani {
  const TasarimAlani({
    required this.no,
    required this.ad,
    required this.katman,
    required this.sahiplendigi,
    required this.bagimlilik,
    required this.durum,
  });

  /// 01..16. Belgelerde geçen numara — kararlı kimlik.
  final int no;

  final String ad;

  final TasarimKatmani katman;

  /// Bu alanın SAHİPLENDİĞİ kararlar. Aynı karar iki alanda geçemez.
  final List<String> sahiplendigi;

  /// Bu alanın okumaya HAKKI olan alanlar.
  ///
  /// Listede olmayan bir alandan sayı çekmek `aşağı yalnız yukarıyı okur`
  /// kuralının ihlali — ve o an bir değişikliğin nereye yayılacağı
  /// hesaplanamaz hâle gelir.
  final List<int> bagimlilik;

  final BelgeDurumu durum;

  /// İki nokta üst üste ile okunabilir kimlik: `01 · Savaş Formülü`.
  String get id => '${no.toString().padLeft(2, '0')} · $ad';
}

/// On altı alan. Oyunda ne varsa o.
abstract final class TasarimHaritasi {
  static const savasFormulu = TasarimAlani(
    no: 1,
    ad: 'Savaş Formülü',
    katman: TasarimKatmani.savas,
    sahiplendigi: [
      'Altı katman, sabit sıra',
      'Katmanların ne tür stat aldığı',
      'Önce kalkan, taşan kısım gövde',
      'Kritiğin iki biçimi',
      'Iskalama yok, sıyırma var',
      'Genişleme kuralı: katman sayısı artmaz',
      'PvE ↔ PvP tek formül, tek katsayı',
      'Sözlük: yaylım · DPS · EHP · TTK',
    ],
    // Kök alan. Her şey buna bağlı, bu hiçbir şeye.
    bagimlilik: [],
    durum: BelgeDurumu.yazildi,
  );

  static const statKutuphanesi = TasarimAlani(
    no: 2,
    ad: 'Stat Kütüphanesi',
    katman: TasarimKatmani.savas,
    sahiplendigi: [
      'Kimlik ile etiket ayrı; katman ve kanal 01\'den',
      'Kayıt alanları: birim, kapsam, eş, altStat',
      'Kapsam sistemi ve çift sayım savunması',
      'Giriş şartı: eşi olmayan stat kütüphaneye giremez',
      'Genişleme şartları',
      'Ayrılmış kimlikler',
      'Kayıt tablosu: yirmi iki kimlik',
      'Kritik çarpanının kimliği',
    ],
    bagimlilik: [1],
    // Bu alanın SAYISI yok ve tepe tabloya bir satır bile koymuyor: içeriği
    // tamamen kategorik (sekiz stat, katmanları, kanalları, birim tipleri).
    // Ayarlanacak bir değeri olmayan bir alan, ayarlanınca bozulmayan bir
    // alandır.
    //
    // Kararı kodda: `kalkan` ile `govde_cani` MUTLAK, toplamsal tüketiliyor.
    durum: BelgeDurumu.yazildi,
  );

  static const statDegeri = TasarimAlani(
    no: 3,
    ad: 'Stat Değeri',
    katman: TasarimKatmani.savas,
    sahiplendigi: [
      'Değer marjinal katkıdır, zincirden türer',
      'Referans noktada ölçme kuralı',
      'Kanal içi fiyatlama, kanallar arası kur 09\'un',
      'StatMod tanımı ve çapa sözleşmesi',
      'Değerleme dövüş süresi',
      'Birim tipine göre uygulama sözleşmesi',
    ],
    bagimlilik: [1, 2],
    // Sekiz fiyat tepe tabloda. Alan 09 kanallar arası kuru çözdüğünde
    // savunma olanları TÜRETİLENE dönecek (×20,28) ve tablodan çıkacaklar.
    durum: BelgeDurumu.yazildi,
  );

  static const gemiVeYuvalar = TasarimAlani(
    no: 4,
    ad: 'Gemi ve Yuvalar',
    katman: TasarimKatmani.savas,
    sahiplendigi: [
      'Gemi üç şey verir: taban stat, yuva sayısı, yuva çeşidi',
      'Yuva haritası ve yuva↔eşya eşleşmesi',
      'Jeneratör ikilemi: kalkan ya da hız',
      'Hız jeneratörü kaçınma da verir',
      'Referans build bileşimi',
      'Referans zırh ve kaçınma toplamları',
      'Gövde statları merdivenden türer',
      'Yuva merdiveni kesikli, kademe başına bir yuva',
      'Sanat kısıtı: lazer yuvası = çizimdeki namlu',
      'Droid filosu gövdeden bağımsız',
      'Roketatar her gövdede tam bir yuva',
      'Merdiven çizilmiş gövdeleri açıklar',
    ],
    bagimlilik: [2, 3],
    // Çapa statları ve referans build tepe tabloda; K sabitleri kendiliğinden
    // çözüldü. Kademelerin ÇARPANI burada değil alan 08'de: rank merdivenine
    // bağlı ve rank büyüme katmanında — savaş katmanı oradan okuyamaz.
    durum: BelgeDurumu.yazildi,
  );

  static const saglayicilar = TasarimAlani(
    no: 5,
    ad: 'Sağlayıcılar',
    katman: TasarimKatmani.buyume,
    sahiplendigi: [
      'İki sağlayıcı tipi, davranış ayrılmış',
      'Sağlayıcı kaydı',
      'Kapsam kuralları ve sızıntı yasağı',
      'Yuva → kapsam eşlemesi; droid bir TAŞIYICI',
      'Aktarım katsayısı σ ve biçimi',
      'Unvan stat vermez',
      'ArGe yeni stat icat etmez; güç değil YÖN veriyor',
      'Droid seviyesi altı kademe, çeşit iki, tasarım on',
      'Formasyon: tek aktif, imzalı takas',
      'Droidin canı yok, dayanıklılığı var',
    ],
    bagimlilik: [2, 4],
    // SAYISI YOK — alan 02 gibi tamamen kategorik. Çekirdeği zaten kodda:
    // `StatScope` (pilot · drone · pet · global) ve `StatVector`ın
    // `stat@kapsam` anahtarı, çift sayımı bir hata olmaktan çıkarıp İMKÂNSIZ
    // hâle getiriyor. Yuva → kapsam eşlemesi `LoadoutResolver`da.
    //
    // Droid σ'sı bir tasarım girdisi olarak eklenmedi: droid SİSTEMİ yok, ve
    // olmayan bir sistem için sayı ilan etmek, "kod uygulandı" demenin
    // karşılığını boşaltırdı. Droid geldiğinde σ buraya gelecek.
    durum: BelgeDurumu.yazildi,
  );

  static const esyaKurgusu = TasarimAlani(
    no: 6,
    ad: 'Eşya Kurgusu',
    katman: TasarimKatmani.buyume,
    sahiplendigi: [
      'Rank ekseni belirlenimci, yirmi basamak',
      'Kalite ekseni rastgele, örneğe özgü',
      'Tasarım, örnek ve malzeme ayrı şemalar',
      'Yükseltme malzemesi ile çevirici ayrı kaynak',
      'Ana stat belirlenimci, alt statlar rastgele',
      'Rank çakışmaz',
      'Alt stat havuzu yuva tipine göre kısıtlı ve fiyatlı',
      'Havuz içerikleri',
      'Alt stat sayısı her aileyle bir artıyor',
      'Kalite bandı rankla daralıyor, garantili alt stat',
      'Set bonusu ayrılmış',
    ],
    bagimlilik: [2, 5],
    // Ana stat ↔ alt stat bölünmesi (%70/%30) ve kalite bandı tepe tabloda,
    // ve alt statlar artık GERÇEKTEN doğuyor: `ItemInstance.subStats` bir
    // zamanlar okunuyor ve serileştiriliyordu ama hiçbir yerde yazılmıyordu.
    //
    // Rank MERDİVENİ (×1,442, yirmi kademe) burada değil: bugün beş tier var
    // ve yirmiye çıkarmak katalog, hangar, mağaza ve serileştirmeyi birden
    // değiştiren bir içerik işi.
    durum: BelgeDurumu.yazildi,
  );

  static const guclendirme = TasarimAlani(
    no: 7,
    ad: 'Güçlendirme',
    katman: TasarimKatmani.buyume,
    sahiplendigi: [
      'Üç modül: artı basma, sentez, çevirme',
      'Başarısızlık ve kırılma yasağı',
      'Artı merdiveni ve kazanç biçimi',
      'Maliyetin şekil ↔ hacim ayrımı',
      'Çevirme hepsini çevirir, kilit korur',
      'Artı basmada güçlenen alt stat rastgele, miktar sabit',
      'Sentez oranı ve kaybı',
      'Çevirme kaynağı ve nadirliği',
      'Malzemenin rank kapısı rolü',
      'Soket ayrılmış',
    ],
    bagimlilik: [6, 8],
    durum: BelgeDurumu.yazildi,
  );

  static const gucButcesi = TasarimAlani(
    no: 8,
    ad: 'Güç Bütçesi',
    katman: TasarimKatmani.buyume,
    sahiplendigi: [
      'Payı ilan et, katsayıyı türet',
      'Katsayı gövdeye bağlı',
      'Marjinal fiyatlar toplanmaz; 08 dağıtır, 16 ölçer',
      'A = D, puanlarda değil gerçekleşende',
      'Gövde havuzu TTK\'dan çözülür',
      'Gövde ↔ eşya kolu',
    ],
    bagimlilik: [3, 4, 6],
    // Paylar tepe tabloda; katsayı onlardan TÜRÜYOR. Ve gövde kademesi
    // merdiveni burada çözüldü — 04'te çözülemezdi, çünkü kademe çarpanı rank
    // merdivenine bağlı ve rank büyüme katmanında. 08 ikisini birden gören
    // ilk alan.
    durum: BelgeDurumu.yazildi,
  );

  static const savasPuani = TasarimAlani(
    no: 9,
    ad: 'Savaş Puanı',
    katman: TasarimKatmani.buyume,
    sahiplendigi: [
      'BR geometrik ortalama',
      'Kanallar arası kur = referans TTK',
      'A = D kısıtının anlamı',
      'Savunma çapası ve ölçekleme',
      'Sistem kanalı değerleri ve tavanı',
      'Droid\'in iki katsayısı',
      'Ölçek sabiti K',
    ],
    bagimlilik: [3],
    // Kanallar arası kur çözüldü ve savunma fiyatları GİRDİ olmaktan çıkıp
    // türetilene döndü. Ölçülmüştü: elle konmuş fiyatla bir savunma puanı,
    // bir saldırı puanının %19,7'si kadar güç alıyordu.
    durum: BelgeDurumu.yazildi,
  );

  static const ilerlemeVeUnvan = TasarimAlani(
    no: 10,
    ad: 'İlerleme ve Unvan',
    katman: TasarimKatmani.buyume,
    sahiplendigi: [
      'Seviye ↔ BR ayrımı',
      'Rank merdiveni ve renk kapakları',
      'Unvan eşikleri: yüz yirmi basamak, eşit oranlı',
      'Unvan isimleri, çağlar ve görsel kimlik',
      'Gelir ölçekleme üssü α',
      'Referans build fonksiyonu',
      'Sistem açılış sırası',
      'Günlük tavan ve yorgunluk',
    ],
    bagimlilik: [8, 9],
    // Unvan merdiveni BR tabanı ile tavanından çözülüyor ve yorgunluk eşiği
    // artık kademeyle ölçekleniyor. Sabit eşik, üst kademelerde eşik olmaktan
    // çıkıp duvar oluyordu.
    durum: BelgeDurumu.yazildi,
  );

  static const haritalar = TasarimAlani(
    no: 11,
    ad: 'Haritalar',
    katman: TasarimKatmani.dunya,
    sahiplendigi: [
      'Bölge = gövde kademesi; her bölgede üç harita',
      'Bant yapısı ve bant başına gelir',
      'Kapı savaş puanı: referansın dörtte üçü',
      'Seviye ikincil kapı',
      'Harita boyutu ve yoğunluk türetilir',
      'PvP primi hesaplanabilir',
    ],
    bagimlilik: [9, 10],
    durum: BelgeDurumu.yazildi,
  );

  static const dusmanKurgusu = TasarimAlani(
    no: 12,
    ad: 'Düşman Kurgusu',
    katman: TasarimKatmani.dunya,
    sahiplendigi: [
      'Üç sınıf, üç rol',
      'Can bir süredir',
      'Ödül bir hızdır',
      'Hasar bir kaçış penceresidir',
      'Boss: iki saatte bir, her bantta',
      'NOVA ölçeklenmez',
      'Kadro: otuz iki yaratık, sekiz bölge',
    ],
    bagimlilik: [4, 11],
    durum: BelgeDurumu.yazildi,
  );

  static const kaynakAkisi = TasarimAlani(
    no: 13,
    ad: 'Kaynak Akışı',
    katman: TasarimKatmani.ekonomi,
    sahiplendigi: [
      'Üç kaynak, üç davranış',
      'Dönüşüm yasağı',
      'Onarım türetiliyor, gerisi bölünüyor',
      'Yorgunluk eşiği ölçekleniyor',
      'Birikim tamponu',
      '+15 nesil içinde ulaşılamaz; endgame kuyruğu',
      'Paralel ekonomi: pazar yok',
    ],
    bagimlilik: [7, 8, 10],
    durum: BelgeDurumu.yazildi,
  );

  static const ganimet = TasarimAlani(
    no: 14,
    ad: 'Ganimet',
    katman: TasarimKatmani.ekonomi,
    sahiplendigi: [
      'Üç düşen, üç ritim',
      'Malzeme kuru: bir öldürme, bir malzeme',
      'Düşme şansı birinci banttan türer',
      'Rank dağılımı ve PRD yalnız üst rankta',
      'Parçalama: eşyanın ikinci hayatı',
      'Boss ganimeti garantili',
    ],
    bagimlilik: [11, 12, 13],
    durum: BelgeDurumu.yazildi,
  );

  static const kazanc = TasarimAlani(
    no: 15,
    ad: 'Kazanç',
    katman: TasarimKatmani.ekonomi,
    sahiplendigi: [
      'Önce ne satılamayacağı',
      'Kredi mağazası: taban eşya',
      'Başlangıç kredisi raftan türüyor',
      'NOVA mağazası: zaman satar',
      'NOVA rafı: üç taban tasarım, bir kademe üstte',
      'Görünüş satılır: tasarım ve formasyon',
      'Paranın tavanı ölçülür',
      'Paketler ve bonus eğrisi',
      'Ödeme oranı ve ARPPU hedefi',
    ],
    bagimlilik: [10, 13],
    durum: BelgeDurumu.yazildi,
  );

  static const mermi = TasarimAlani(
    no: 17,
    ad: 'Mermi',
    katman: TasarimKatmani.ekonomi,
    sahiplendigi: [
      'Mermi PvE\'de değil PvP\'de belirleyici',
      'MR-1 bedava ve sınırsız',
      'Çarpan yalnız taban hasarı çarpar',
      'Fiyat eğrisi iki ankrajdan geçer',
      'Tavan çarpan PvP primini yer',
      'Sifon yalnız kalkana',
      'Mermi NOVA ile satılmaz, BR saymaz',
      'Birim namlu atışı, stok hesapta',
    ],
    // Savaşın kanalını (01) okuyor, PvP primini (11), gelir yapısını (13)
    // ve mağazayı (15). Yan belgeden taşındı; on altıdan sonra geldiği için
    // numarası on yedi ama katmanı ekonomi.
    bagimlilik: [1, 11, 13, 15],
    durum: BelgeDurumu.yazildi,
  );

  static const roket = TasarimAlani(
    no: 18,
    ad: 'Roket',
    // Katman ekonomi, mermi gibi: bütçe payını (08) ve mermi eğrisini (17)
    // okuyor; savaş katmanında dursaydı "aşağı yalnız yukarıyı okur" bozulur.
    // Silah tarafı 01–04'ün kurallarını uyguluyor, kendi kuralı ekonomik.
    katman: TasarimKatmani.ekonomi,
    sahiplendigi: [
      'Roketatar bir silah, kadans oranıyla',
      'Roket zinciri geminin, tabanı roketin',
      'Roket mermisi: RK-1 bedava, üstü mermi eğrisiyle',
      'Stok hesapta, seçim savaş çubuğunda',
      'Roket NOVA ile satılmaz, mermisi BR saymaz',
      'Ayrı atış olayı, ayrı çizim',
    ],
    // Hasar zincirini (01), kapsamı (02), fiyatı (03), yuvayı (04), payı
    // (08) ve mermi eğrisini (17) okuyor. On yediden sonra geldi.
    bagimlilik: [1, 2, 3, 4, 8, 17],
    durum: BelgeDurumu.yazildi,
  );

  static const dengeDenetimi = TasarimAlani(
    no: 16,
    ad: 'Denge Denetimi',
    katman: TasarimKatmani.denge,
    sahiplendigi: [
      'Beş test türü',
      'Karar döngüleri kapalı',
      'Tek tepe tablo: dışında elle sayı yok',
      'Sayı borçları ve eksik sistemler derlenir',
      'Yeni alan ekleme adımları',
      'Denetim tutarlılık ölçer, doğruluk değil',
      'Türetilen sayılar da etiketle doğrulanır',
      'Kodda demek sınanmış demek',
      'Borç defteri ve yan belgeler denetimde',
    ],
    // Hepsine bağlı: en son yazılır, ama ilk kurulan test olmalıdır.
    bagimlilik: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17],
    durum: BelgeDurumu.yazildi,
  );

  static const List<TasarimAlani> hepsi = [
    savasFormulu,
    statKutuphanesi,
    statDegeri,
    gemiVeYuvalar,
    saglayicilar,
    esyaKurgusu,
    guclendirme,
    gucButcesi,
    savasPuani,
    ilerlemeVeUnvan,
    haritalar,
    dusmanKurgusu,
    kaynakAkisi,
    ganimet,
    kazanc,
    dengeDenetimi,
    mermi,
    roket,
  ];

  static TasarimAlani? byNo(int no) {
    for (final alan in hepsi) {
      if (alan.no == no) return alan;
    }
    return null;
  }

  /// Belgesi YAZILMIŞ alanlar. Bugün yalnız 01.
  static Iterable<TasarimAlani> get yazilanlar =>
      hepsi.where((a) => a.durum == BelgeDurumu.yazildi);
}
