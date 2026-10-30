import 'dart:math' as math;

/// SAHTE RASTGELE DAĞILIM — bağımsız zarın yerine geçen şans yönetimi.
///
/// Kural belgesi 03'ün gerekçesi: bağımsız zar, oyuncuların bir kısmına uzun
/// kritik kuraklıkları yaşatır ve o oyuncu sistemin bozuk olduğunu düşünür —
/// haklı olarak, çünkü ilan edilen oran ile YAŞADIĞI oran farklıdır.
///
/// Yöntem: art arda kaçırılan her denemede şans `C` kadar artar. `n`inci
/// denemede şans `C·n`. Bu, dağılımın kuyruğunu keser: `1 ÷ C` denemede kritik
/// GARANTİ. Karşılığında da kuyruğun öbür ucu kesilir — arka arkaya üç kritik
/// bağımsız zarda mümkün, burada değil.
///
/// **`C` elle yazılmaz.** İlan edilen oran `p` verildiğinde, uzun vadeli
/// ortalamanın tam olarak `p` çıkması için gereken `C` sayısal olarak çözülür
/// ([constantFor]). Elle yazılan bir `C`, oyuncunun ilan edilenden farklı
/// sıklıkta kritik alması demektir ve bunu kimse fark etmez.
/// KARAR 01.4 s1
abstract final class Prd {
  /// [c] artışıyla bir kritiğe kadar geçen deneme sayısının BEKLENEN değeri.
  ///
  /// `E[N] = Σ n · P(N = n)`, `P(N = n) = min(1, C·n) · Π(1 − C·i)`.
  /// Dizi `n > 1/C` olduğunda kesin biter: o adımda şans 1'e ulaşır.
  static double expectedAttempts(double c) {
    if (c <= 0) return double.infinity;
    if (c >= 1) return 1;
    var failChance = 1.0;
    var expected = 0.0;
    // `1/c` adımda şans 1'i geçiyor; `+2` yuvarlama payı.
    final limit = (1 / c).ceil() + 2;
    for (var n = 1; n <= limit && failChance > 0; n++) {
      final p = math.min(1.0, c * n);
      expected += n * failChance * p;
      failChance *= 1 - p;
    }
    return expected;
  }

  /// [c] artışının GERÇEKTEN ürettiği ortalama oran: `1 ÷ E[N]`.
  static double effectiveChance(double c) => 1 / expectedAttempts(c);

  /// İlan edilen [chance] oranını üreten `C` sabiti.
  ///
  /// İkiye bölme (bisection): [effectiveChance] `c` içinde kesin artan olduğu
  /// için kök tektir ve arama daima yakınsar. Kapalı bir formül yok — bu
  /// yüzden sabit ÇÖZÜLÜR, yazılmaz.
  ///
  /// Çözücü doğrulandı: Dota 2'nin yayımlanmış sabitlerini birebir üretiyor
  /// (bkz. `prd_test.dart`).
  static double constantFor(double chance) {
    if (chance <= 0) return 0;
    if (chance >= 1) return 1;
    var lo = 0.0;
    var hi = 1.0;
    // 80 yineleme `double`ın çözünürlüğünün çok altına iniyor; sabit bir üst
    // sınır, yakınsamayan bir eşiğe göre çok daha güvenli.
    for (var i = 0; i < 80; i++) {
      final mid = (lo + hi) / 2;
      if (effectiveChance(mid) < chance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// [c] artışıyla kritiğin GARANTİ olduğu deneme sayısı — `⌈1 ÷ C⌉`.
  static int guaranteedAt(double c) => c <= 0 ? -1 : (1 / c).ceil();
}

/// Bir atıcının PRD sayacı — art arda kaçırılan deneme.
///
/// **Atıcı başına tutulur, atış başına değil.** Sayaç paylaşılırsa iki oyuncu
/// birbirinin kuraklığını devralır; her atışta sıfırlanırsa PRD bağımsız zara
/// döner ve bütün amaç kaybolur.
///
/// Sunucuda yaşar. İstemci kritiği TAHMİN ETMEZ — hasarı sunucu söyler
/// (`ShotEvent`), çünkü tahmin edilen bir kritik ile inen hasarın ayrışması
/// oyuncunun asla affetmediği hata türü.
class PrdRoller {
  PrdRoller(this.chance) : _c = Prd.constantFor(chance);

  /// İlan edilen oran.
  final double chance;

  final double _c;

  /// Art arda kaçırılan deneme sayısı.
  int _misses = 0;

  int get misses => _misses;

  /// Bu atışın ŞU ANKİ şansı — `C · (kaçırılan + 1)`, tavanı 1.
  double get currentChance => math.min(1.0, _c * (_misses + 1));

  /// Zar at. Tuttuysa sayaç sıfırlanır, tutmadıysa bir artar.
  bool roll(math.Random random) {
    if (chance <= 0) return false;
    if (random.nextDouble() < currentChance) {
      _misses = 0;
      return true;
    }
    _misses++;
    return false;
  }

  /// Sayacı sıfırla — gemi öldü ya da donatım değişti.
  void reset() => _misses = 0;

  /// Kaydedilmiş seriyi geri yükle.
  ///
  /// PRD'nin durumu tek bir sayı ve o sayı KALICI olmak zorunda: seri
  /// oturumdan uzun, oturumda sıfırlanan bir acıma sistemi her girişte
  /// oyuncuyu en düşük şansa atardı.
  void kacirmayiGeriYukle(int kacirma) => _misses = math.max(0, kacirma);
}
