/// DROİD GRUBU — geminin yanında uçan varlıkların TOPLU sayısal kimliği.
///
/// Droid bir değiştirici değil VARLIK (05.1): kendi vektörü, kendi havuzu,
/// kendi hasar zinciri var. Ama tek tek değil grup olarak çözülüyor: droid
/// kapsamı ([StatScope.droid]) tek bir vektör ve o vektöre bütün droid
/// eşyaları yazıyor. Grup, [sayi] gövdeli tek bir varlık gibi vuruyor ve
/// dayanıyor.
///
/// Geminin çarpanlarından payını AKTARIM KATSAYISI ile alıyor (05.5):
/// `droid çarpanı = 1 + σ · (gemi çarpanı − 1)`. Sıfırda düz toplam, birde
/// geminin her çarpanı droid sayısıyla çarpılır; ikisi de yanlış.
/// KARAR 05.1 s1 · KARAR 05.5 s3
class DroidGrubu {
  const DroidGrubu({
    required this.sayi,
    required this.tabanHasar,
    required this.damageBonus,
    required this.critChance,
    required this.critMultiplier,
    required this.atisAraligi,
    required this.havuz,
    required this.armor,
    this.ayaktaKalma = 1,
  });

  /// Droid yok: bütün alanlar sıfır, zincir hiç çağrılmaz.
  static const DroidGrubu yok = DroidGrubu(
    sayi: 0,
    tabanHasar: 0,
    damageBonus: 0,
    critChance: 0,
    critMultiplier: 1,
    atisAraligi: 1,
    havuz: 0,
    armor: 0,
  );

  /// Takılı droid sayısı — grubun gövde sayısı.
  final int sayi;

  /// Grubun YAYLIMI (L0): droidlerin taban hasarları toplamı.
  final double tabanHasar;

  /// L1 — kendi bonusu artı geminin bonusunun σ payı.
  final double damageBonus;

  /// L3 — referans artı kendi artı geminin fazlasının σ payı.
  final double critChance;
  final double critMultiplier;

  /// Grubun atış aralığı (sn) — referans aralık, kendi atış hızıyla.
  final double atisAraligi;

  /// Grubun HAM havuzu — türetilen taban × sayı, artı droid kapsamındaki
  /// gövde canı.
  final double havuz;

  /// Ham zırh — droid kapsamından; eğri geminin K'sıyla.
  final double armor;

  /// Saldırıya giriş katsayısı: droidler dövüşün ne kadarında ayakta (09.6).
  /// Bugün bir: droidler ölmüyor, borç defterinde.
  final double ayaktaKalma;

  bool get var_ => sayi > 0;
}
