import 'dart:math' as math;

/// Bir alienin SALDIRGANLAR tablosu — kim ne kadar hasar verdi.
///
/// **Tek yapı, iki soruyu birden cevaplıyor** ve bu tesadüf değil; MMO'larda
/// ikisi de aynı sayıdan türer:
///
///  * **Kimi vuracağım?** (仇恨列表 / threat table) En çok tehdit üreten.
///    Önceki hâl "en son vuran"dı ve alienler saldıranlar arasında gidip
///    geliyordu; kin yönetimi diye bir oyun katmanı kurulamıyordu.
///  * **Ödül kime?** (归属判定) Hasar payına göre. Önceki hâl "son vuruş"tu:
///    hasarın %99'unu veren değil, son yaylımı atan alıyordu. İki oyuncu aynı
///    aliene girdiği gün hissedilecek türden bir adaletsizlik.
///
/// **Tehdit SÖNÜYOR.** Sabit bir tablo, bir kez vurup giden oyuncuyu sonsuza
/// kadar listede tutar ve alien onu kovalamaya devam eder. Sönme, "kaçmak işe
/// yarar" kuralının tablo tarafındaki karşılığı.
///
/// **Ödül payı SÖNMEMİŞ hasardan hesaplanmıyor.** Pay için toplam hasar
/// ayrı tutuluyor: bir dakika süren bir kavgada erken verilen hasar sönerdi ve
/// ödül, kavgayı bitiren kişiye kayardı — düzeltmeye çalıştığımız şeyin ta
/// kendisi.
class ThreatTable {
  /// Tehdit yarı ömrü (sn). Bu süre sonunda birikmiş tehdit yarıya iner.
  ///
  /// Kinin toplam süresinden ([AlienSim.aggroDuration]) uzun: kin "hedefim var
  /// mı" sorusunu, sönme "hangisi" sorusunu yönetiyor. Sönme daha hızlı
  /// olsaydı alien uzun bir kavganın ortasında hedefini kaybederdi.
  static const double halfLife = 20;

  /// Bir saldırganın altına düştüğünde listeden düşürüldüğü eşik.
  ///
  /// Sıfıra hiç inmeyen üstel sönme, tabloyu sonsuza kadar büyütür — ve tablo
  /// alien başına tutuluyor.
  static const double forgetBelow = 1;

  /// Gemi kimliği → SÖNEN tehdit (kimi vuracağım).
  final Map<int, double> _threat = {};

  /// Gemi kimliği → TOPLAM hasar (ödül payı).
  final Map<int, double> _damage = {};

  bool get isEmpty => _threat.isEmpty;

  /// Tabloyu okumak için — kopyasız, değiştirilemez.
  Map<int, double> get damage => Map.unmodifiable(_damage);

  /// [shipId] alienimize [amount] hasar verdi.
  void add(int shipId, double amount) {
    if (amount <= 0) return;
    _threat[shipId] = (_threat[shipId] ?? 0) + amount;
    _damage[shipId] = (_damage[shipId] ?? 0) + amount;
  }

  /// EN ÇOK tehdit üreten gemi; tablo boşsa `null`.
  ///
  /// [alive] hangi kimliklerin hâlâ hedeflenebilir olduğunu söylüyor: ölmüş ya
  /// da ayrılmış bir oyuncuyu kovalamak, alieni haritada donmuş bırakırdı.
  int? top(bool Function(int) alive) {
    int? best;
    var bestThreat = 0.0;
    for (final entry in _threat.entries) {
      if (entry.value <= bestThreat) continue;
      if (!alive(entry.key)) continue;
      best = entry.key;
      bestThreat = entry.value;
    }
    return best;
  }

  /// Tehdidi zamanla söndürür ve eşiğin altına düşenleri unutur.
  void decay(double dt) {
    if (_threat.isEmpty) return;
    // Üstel sönme: `0.5^(dt/yarıÖmür)`. Doğrusal sönme, büyük tehditleri
    // küçüklerle aynı hızda eritir ve sıralamayı bozardı.
    // `exp(-dt·ln2/yarıÖmür)`. İlk yazışta bu, `dart:math` bağımlılığı
    // eklememek için elle Taylor açılımıydı ve YANLIŞTI: seri yalnız |x| küçük
    // olduğunda yakınsıyor, oysa çağrılar 10 yarı ömürlük aralıklarla
    // geliyordu ve sonuç ıraksıyordu — tehdit hiç sönmüyordu. Test bunu
    // yakaladı. `dart:math` zaten bu pakette (`alien_sim.dart`) kullanılıyor.
    final factor = math.exp(-dt * math.ln2 / halfLife);
    _threat.updateAll((_, value) => value * factor);
    _threat.removeWhere((_, value) => value < forgetBelow);
  }

  /// Bir gemiyi tablodan tamamen çıkarır (ayrıldı, öldü).
  ///
  /// Yalnız TEHDİT siliniyor, hasar payı DEĞİL: ölen oyuncu da o kavgada
  /// hasar verdi ve ödülü hak ediyor. İkisini birlikte silmek, "vurup ölen
  /// hiçbir şey almaz" gibi bir kural yaratırdı.
  void forget(int shipId) => _threat.remove(shipId);

  /// Tabloyu tamamen boşaltır — alien öldü ya da yeniden doğdu.
  void clear() {
    _threat.clear();
    _damage.clear();
  }

  /// Hasar PAYLARI — kimlik → oran, toplamı 1.
  ///
  /// [split] ile aynı kaynağı okuyor ama yuvarlamıyor: ganimet bir tam sayıya
  /// bölünmüyor, her oyuncunun kendi zarına ölçek veriyor. Ayrı bir dağıtım
  /// yazmak, sahipliği ikinci bir yerde tanımlamak olurdu.
  Map<int, double> get paylar {
    final sum = _damage.values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return const {};
    return {for (final e in _damage.entries) e.key: e.value / sum};
  }

  /// [total] ödülü hasar payına göre böler.
  ///
  /// **Toplam KORUNUYOR.** Payları tek tek yuvarlamak, ekonomiye para basar ya
  /// da sızdırır: üç oyuncuya 400 krediyi bölerken 133+133+133 = 399, bir
  /// kredi buharlaşır. Küçük görünür ve milyonlarca imhada görünmez bir
  /// açıktır. En büyük kalan yöntemi (largest remainder) toplamı birebir
  /// tutuyor.
  ///
  /// Boş tabloda boş harita döner — çağıran son vuruşa düşmemeli, hiç
  /// ödememeli.
  Map<int, int> split(int total) {
    if (total <= 0 || _damage.isEmpty) return const {};
    final sum = _damage.values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return const {};

    final shares = <int, int>{};
    final remainders = <int, double>{};
    var handed = 0;
    for (final entry in _damage.entries) {
      final exact = total * entry.value / sum;
      final floor = exact.floor();
      shares[entry.key] = floor;
      remainders[entry.key] = exact - floor;
      handed += floor;
    }

    // Kalan birimler en büyük kesirli paya sahip olanlara, sırayla.
    final order = remainders.keys.toList()
      ..sort((a, b) {
        final byRemainder = remainders[b]!.compareTo(remainders[a]!);
        // Eşitlikte KİMLİĞE göre: yoksa dağıtım harita sırasına bağlı olur ve
        // simülasyonun tekrarlanabilirliği biter.
        return byRemainder != 0 ? byRemainder : a.compareTo(b);
      });
    for (var i = 0; handed < total && i < order.length; i++, handed++) {
      shares[order[i]] = shares[order[i]]! + 1;
    }

    shares.removeWhere((_, value) => value <= 0);
    return shares;
  }
}
