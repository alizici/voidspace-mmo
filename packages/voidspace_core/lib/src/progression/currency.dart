/// Oyunun İKİ para birimi.
///
/// **Neden iki.** Tek para birimiyle bir oyunun ekonomisinde tek bir kaldıraç
/// olur: her şey aynı havuzdan alınır ve oynama süresi ile satın alma
/// arasındaki fark yalnız bir çarpandır. İki birim, aynı ekonomiye iki AYRI
/// soru sordurur — "bunu kazanmaya değer mi" ve "buna beklemeye değer mi".
///
/// Model, türün klasik bol/kıt ikilisi:
///
///  * [credit] — bol. Öldürülen her alienden düşer, mağazanın gövdesi bununla
///    alınır. Oyuncunun harcamaktan çekinmediği para.
///  * [premium] — kıt. Aynı alienlerden ama çok daha az düşer; oyun içinde
///    KAZANILABİLİR olması şart, yoksa ikinci birim "para ödemeyenin
///    göremediği bir raf" olur ve oyuncu onu ekonominin parçası saymaz.
///
/// **Wire ve depo adı NÖTR.** JSON anahtarı `premium`, görünen ad ise
/// [premiumName] sabitinde. Ekonomiye bir gün başka bir ad verilirse
/// değişecek tek yer orası — kayıtlı hesapların diskteki alanı değil. Bir
/// para biriminin adını değiştirmek, kimsenin bakiyesini bozmamalı.
enum Currency {
  credit,
  premium;

  /// Arayüzde görünen ad.
  String get label => switch (this) {
    Currency.credit => creditName,
    Currency.premium => premiumName,
  };

  /// Kalıcı depo ve tel anahtarı. [label]'dan AYRI ve öyle kalmalı.
  String get key => name;

  static Currency? byKey(String key) {
    for (final c in values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

/// Bol para biriminin görünen adı.
const String creditName = 'KREDİ';

/// Kıt para biriminin görünen adı.
///
/// Tek yerde duruyor: adı değiştirmek bir sabit düzenlemek olmalı, arayüzü
/// taramak değil.
const String premiumName = 'NOVA';

/// Bir fiyat: miktar VE hangi parayla.
///
/// Ayrı bir `int` ve ayrı bir `Currency` taşımak yerine tek tip: ikisini ayrı
/// taşıyan her çağrı, bir gün yanlış cüzdandan düşme fırsatı. 2400 NOVA'lık
/// bir eşyayı 2400 krediye satmak, ekonominin sessizce çöktüğü yerdir.
class Price {
  const Price(this.amount, this.currency);

  /// Kredi cinsinden fiyat — mağazanın gövdesi.
  const Price.credit(this.amount) : currency = Currency.credit;

  /// Kıt para cinsinden fiyat.
  const Price.premium(this.amount) : currency = Currency.premium;

  final int amount;
  final Currency currency;

  bool get isFree => amount <= 0;

  @override
  String toString() => '$amount ${currency.label}';

  @override
  bool operator ==(Object other) =>
      other is Price && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);
}
