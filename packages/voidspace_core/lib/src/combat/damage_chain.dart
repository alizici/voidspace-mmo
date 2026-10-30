import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import 'stat_layer.dart';

/// Kritiğin İKİ biçimi. Kural belgesi 03'ün tamamı bu ayrımda.
///
/// İkisi de aynı katmandan (L3) besleniyor; uzun vadede zarların ortalaması
/// beklenen değere yakınsıyor. Sorun ikisinin var olması değil, birinin
/// diğerinden habersiz değişmesi — o yüzden ikisi de tek bir yerden okuyor.
/// KARAR 01.4 s1
enum CritMode {
  /// Çalışma anı: GERÇEK zar. Vurdu ya da vurmadı.
  ///
  /// Sarı büyük rakam görmek oyunun hissi. Beklenen değerle oynanan bir oyunda
  /// kritik diye bir şey yoktur.
  rolled,

  /// Denge · BR: BEKLENEN değer `1 + k(d − 1)`.
  ///
  /// Tek bir sayı gerekir. Zar atan bir formülle ne bütçe kurulur ne BR
  /// hesaplanır.
  expected,
}

/// Bir atışın katman katman hesabı.
///
/// Yalnız sonuç değil ARA değerler de taşınıyor: katman paylarını ölçmek
/// (`L5 payı ≤ sonHasarTavanı`) ancak katmanların çıktısı görünürse mümkün, ve
/// ölçülemeyen bir değişmez değişmez değildir.
class DamageBreakdown {
  const DamageBreakdown({
    required this.stages,
    required this.amount,
    required this.crit,
    required this.grazed,
  });

  /// Her katmanın SONRASINDAKİ değer — `stages[i]` = L`i` çıktısı.
  ///
  /// Uzunluğu daima [DamageChain.layerCount]. Katman sayısını dışarıdan
  /// ölçülebilir kılan tek şey bu liste.
  final List<double> stages;

  /// Zincirin nihai çıktısı (PvP katsayısı dâhil).
  final double amount;

  /// Bu atış kritik miydi. [CritMode.expected] ile daima `false` — beklenen
  /// değerde "kritik atış" diye bir olay yok.
  final bool crit;

  /// Sıyırma gerçekleşti mi (kaçınma hasarı DÜŞÜRDÜ).
  ///
  /// Iskalama DEĞİL: mermi çarptı, hasar düşük geldi. Ekranda soluk bir rakam
  /// çıkması gerektiğini söyleyen bayrak.
  final bool grazed;

  double get l0 => stages[0];
  double get l1 => stages[1];
  double get l2 => stages[2];
  double get l3 => stages[3];
  double get l4 => stages[4];
  double get l5 => stages[5];

  /// L5 düz EKLEMESİNİN nihai hasardaki payı. `sonHasarTavani` bunu denetler.
  ///
  /// Yalnız pozitif katkı sayılıyor: düz azaltma (son azaltma) hasarı
  /// düşürüyor, zinciri ele geçirmiyor — tavanın koruduğu şey o değil.
  double get flatShare {
    if (l5 <= 0) return 0;
    final katki = l5 - l4;
    return katki <= 0 ? 0 : katki / l5;
  }

  @override
  String toString() =>
      'DamageBreakdown(${amount.toStringAsFixed(1)}'
      '${crit ? ' KRİTİK' : ''}${grazed ? ' sıyırma' : ''})';
}

/// HASAR ZİNCİRİ — tek bir atışın hesabı, altı katman, sabit sıra.
///
/// Kural belgesi 01'in tamamı burada ve başka hiçbir yerde. Bir statın hangi
/// katmanda olduğu, kaç puan verdiğinden çok daha önemli; bu dosya o katmanları
/// ve sıralarını sabitliyor.
///
/// ```
/// L0  taban   = Σ lazer taban hasarı
/// L1  × (1 + Σ hasar artışı)              toplamsal
/// L2  × (1 + Σ koşullu bonuslar)          AYRILMIŞ — bugün 1
/// L3  × (1 + k · (d − 1))  ya da × d      kritik
/// L4  × (1 − azaltma) × (1 − kafes)       savunma; kafes AYRILMIŞ — bugün 1
/// L5  + son hasar − son azaltma           düz ekleme
/// ---
/// UYG önce kalkan, taşan kısım gövde      formülün DIŞINDA
/// ```
///
/// **Genişleme kuralı — bu sınıfın tek gerçek yasağı:** katman sayısı asla
/// artmaz, katmanların içeriği sınırsız büyür. Yeni bir çarpım katmanı açmak,
/// oradaki her statı diğer bütün katmanların üstüne çarpar; o stat anında
/// oyunun en değerlisi olur ve kütüphanenin geri kalanı ikinci sınıfa düşer.
/// Bir kez açılan katman geri kapatılamaz, çünkü kapatmak herkesin build'ini
/// bozar. Yeni stat eklemek ise serbest ve bedava — hangi katmana gireceği
/// zaten [StatLayer]'da yazıyor.
///
/// **Sayı YOK.** Bu dosyada tek bir denge sabiti geçmez; hepsi
/// [TasarimGirdileri]'nden okunur. Bir sabit buraya sızdığı an, aynı sayı iki
/// yerde durur ve bir sonraki denge turunda ayrışır.
abstract final class DamageChain {
  /// Katman sayısı. **ASLA artmaz** — değişmez testinin denetlediği sayı.
  /// KARAR 01.1 s1 · KARAR 01.6 s1
  static const int layerCount = 6;

  /// Zinciri koş.
  ///
  /// [critRoll] yalnız [CritMode.rolled]'de okunur ve zarı ÇAĞIRAN atar: bu
  /// fonksiyon saf kalmak zorunda, çünkü aynı hesabı denge simülasyonu da
  /// koşuyor ve orada rastgelelik yok.
  /// KARAR 01.2 s1
  static DamageBreakdown resolve({
    // ── L0 ──
    required double baseDamage,
    // ── L1 ──
    double damageBonus = 0,
    // ── L2 · AYRILMIŞ ──
    double conditionalBonus = 0,
    // ── L3 ──
    double critChance = 0,
    double critMultiplier = 1,
    CritMode critMode = CritMode.expected,
    bool critRoll = false,
    // ── L4 ──
    double armorReduction = 0,
    double graze = 0,
    double cageEffect = 0,
    // ── L5 ──
    double flatDamage = 0,
    double flatMitigation = 0,
    // ── zincirin sonu ──
    double pvpMultiplier = 1,
  }) {
    // L0 — çarpan değil, BAŞLANGIÇ. Yuva boşsa gemi ateş edemez: taban hasar
    // takılı lazerlerden geliyor, gövdenin yuva sayısından değil.
    final l0 = baseDamage <= 0 ? 0.0 : baseDamage;

    // L1 — TOPLAMSAL. Ekipmanın ana yeri. Yeni bir yüzdesel saldırı statı
    // gelirse buraya girer, kendi katmanını açmaz.
    final l1 = l0 * (1 + damageBonus);

    // L2 — AYRILMIŞ, bugün sabit 1. Çarpılıyor ama hiçbir şeyi değiştirmiyor.
    // Maliyeti sıfıra yakın, kazancı büyük: koşullu statlar geldiği gün
    // zincirin ŞEKLİ değişmeyecek, yalnız bir çarpan 1 olmaktan çıkacak.
    // Bütün koşullular buraya ve yalnız buraya girer, toplamsal.
    final l2 = l1 * (1 + conditionalBonus);

    // L3 — kritik. İki biçim, tek katman.
    final crit = critMode == CritMode.rolled && critRoll && critChance > 0;
    final critFactor = switch (critMode) {
      CritMode.expected => Turetilenler.kritikBeklenenDegerFor(
        critChance,
        critMultiplier,
      ),
      CritMode.rolled => crit ? critMultiplier : 1.0,
    };
    final l3 = l2 * critFactor;

    // L4 — savunma. Zırh ve sıyırma KARDEŞ: ikisi de burada, farklı eğrilerle
    // (bkz. `SavunmaEgrileri`). Belgedeki `(1 − azaltma)` terimi ikisinin
    // birleşimi; ikinci çarpan (protokol kafesi) ayrılmış ve bugün 1.
    final armor = armorReduction.clamp(0.0, 1.0);
    // Sıyırma tavanı eğrinin İÇİNDE uygulanıyor; burada yalnız güvenlik
    // kelepçesi var, çünkü çağıran ham bir sayı geçirebilir.
    final grazeAmount = graze.clamp(0.0, TasarimGirdileri.siyirmaTavani);
    final mitigation = 1 - (1 - armor) * (1 - grazeAmount);
    final l4 = l3 * (1 - mitigation) * (1 - cageEffect.clamp(0.0, 1.0));

    // L5 — düz ekleme, bütün çarpanlardan SONRA. KÜÇÜK tutulur: payı
    // `sonHasarTavani`yi geçerse zincirin geri kalanı anlamsızlaşır, yani
    // çarpan statları değersizleşir.
    final flatNet = flatDamage - flatMitigation;
    final tavan = TasarimGirdileri.sonHasarTavani;
    // Pay tam olarak tavanda kalsın diye sınır `tavan/(1−tavan) × L4`:
    // `L5 = L4 + sınır` olduğunda `sınır ÷ L5 = tavan`.
    final maxFlat = l4 * tavan / (1 - tavan);
    final cappedFlat = flatNet > maxFlat ? maxFlat : flatNet;
    final l5 = (l4 + cappedFlat).clamp(0.0, double.infinity);

    // Zincirin SONU — PvP katsayısı. Ayrı formül DEĞİL: aynı formülde tek bir
    // çarpan. İki formül, iki denge problemi ve zamanla iki farklı oyun demek.
    // KARAR 01.7 s1
    final amount = l5 * pvpMultiplier;

    return DamageBreakdown(
      stages: [l0, l1, l2, l3, l4, l5],
      amount: amount,
      crit: crit,
      grazed: grazeAmount > 0,
    );
  }
}
