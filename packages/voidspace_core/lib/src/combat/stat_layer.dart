/// KATMAN TANIMI — alan 01 · Savaş Formülü'nün sahiplendiği karar.
///
/// Stat kütüphanesinde (alan 02) DEĞİL, savaş katmanında duruyor ve bu bilinçli:
/// haritanın kuralı "bir alan, sahiplendiği kararla tanımlanır". Katman sırası
/// ve sayısı 01'in kararı; 02 yalnız hangi statın hangi katmana girdiğini
/// söylüyor. Enum aşağıda dursaydı, 01 kendi kararını okumak için 02'ye bakmak
/// zorunda kalırdı — "aşağı yalnız yukarıyı okur" kuralının ihlali.
library;

/// Hasar zincirindeki KATMAN — L0..L5, altı tane, sabit sıra.
///
/// Bir statın hangi katmanda olduğu, kaç puan verdiğinden çok daha önemli:
/// katman, statın diğer bütün statlarla nasıl çarpıldığını belirliyor. Zincirin
/// kendisi [DamageChain]'de; burada duran şey her statın o zincirdeki YERİ.
///
/// **Katman sayısı ASLA artmaz.** Yeni bir çarpım katmanı açmak, oradaki her
/// statı diğer bütün katmanların üstüne çarpar — o stat anında oyunun en
/// değerlisi olur ve kütüphanenin geri kalanı ikinci sınıfa düşer. Bir kez
/// açılan katman geri kapatılamaz, çünkü kapatmak herkesin build'ini bozar.
///
/// Yeni STAT eklemek serbest ve bedava; her yeni stat mevcut bir katmana girer:
///
/// | ileride gelirse                    | katman           |
/// |------------------------------------|------------------|
/// | yeni yüzdesel hasar statı          | [additive]       |
/// | koşullu bonus (boss'a karşı, vb.)  | [conditional]    |
/// | delici kritik, kritik direnci      | [critical]       |
/// | zırh delme, kalkan delme, kafes    | [mitigation]     |
/// | set bonusu, ArGe, unvan statı      | hangi statı veriyorsa o katman |
///
/// Tek gerçek yasak: "nadir hasar çarpanı" gibi TEK BAŞINA bir çarpan. Bir
/// statın kendi çarpım katmanını hak ettiğini düşündüğün an o stat zaten
/// dengesizdir — ve [additive]'e toplamsal olarak koyulduğunda aynı işi yapar,
/// sadece patlamadan.
/// KARAR 01.1 s1 · KARAR 01.2 s1
enum StatLayer {
  /// **L0** — taban. Silahın kendi hasarı, havuzun kendi büyüklüğü. Çarpan
  /// değil, başlangıç.
  base,

  /// **L1** — toplamsal artış. Ekipmanın ana yeri.
  additive,

  /// **L2** — koşullu bonuslar. AYRILMIŞ, bugün boş.
  ///
  /// Bütün koşullu statlar — "boss'a karşı", "kritik ısıda", "canı düşük
  /// hedefe" — buraya ve yalnız buraya girer, toplamsal. Koşullu bir stat asla
  /// kendi çarpım katmanını açamaz: açarsa iki koşul birden tuttuğunda hasar
  /// patlar ve o kombinasyon zorunlu build olur.
  conditional,

  /// **L3** — kritik. Çalışma anında zar, dengede beklenen değer; ikisi de bu
  /// katmandan.
  critical,

  /// **L4** — savunma: azaltma ve protokol kafesi.
  ///
  /// Zırh ve kaçınma KARDEŞ — ikisi de burada, farklı eğrilerle. Kafes ikinci
  /// çarpan olarak ayrılmış, bugün 1.
  mitigation,

  /// **L5** — düz ekleme, bütün çarpanlardan SONRA.
  ///
  /// Küçük tutulur; payı `sonHasarTavani`yi geçerse zincirin geri kalanı
  /// anlamsızlaşır.
  flat;

  /// Belgelerdeki adı: `L0`..`L5`.
  String get code => 'L$index';
}
