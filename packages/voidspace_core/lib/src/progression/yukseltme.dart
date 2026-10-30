import 'dart:math' as math;

import 'budget.dart';

import '../design/tasarim_girdileri.dart';
import 'ganimet.dart';
import 'ganimet_cekilisi.dart';
import 'hull.dart';
import 'item.dart';
import 'referans_build.dart';

/// GÜÇLENDİRME — alan 07'nin üç modülü.
///
/// Artı basma [ItemLevels]'de (eşyanın kendi merdiveni); sentez ve alt stat
/// çevirme burada. Üçü de aynı kaynağı tüketiyor — kredi ve malzeme — ama
/// farklı sorunları çözüyor: artı basma **yavaş ve garantili** büyüme, sentez
/// **fazla eşyayı** değere çevirme, çevirme **kötü şansı** kurtarma.
///
/// **Alanın tamamı tek bir söze dayanıyor: garantili başarı, katlanan
/// maliyet.** Belirsizlik alt stat sisteminde zaten var; orada eğlenceli,
/// burada değil. Hiçbir işlem başarısız olmuyor, hiçbir işlem eşya yok
/// etmiyor — sentez kaybı ORANDA, sonuçta değil; çevirme her zaman bir sonuç
/// veriyor, kötü olabilir ama eşyayı silmiyor.
abstract final class Yukseltme {
  // ══ Sentez ═════════════════════════════════════════════════════════

  /// Bir üst ranka çıkmak için gereken eşya sayısı.
  /// KARAR 07.7 s1
  static int get sentezOrani => TasarimGirdileri.sentezOrani;

  /// SENTEZ VERİMİ — harcanan bütçenin ne kadarı geri geliyor.
  ///
  /// `rankArtışı ÷ oran`. Bire yaklaştıkça sentez drop'un yerine geçiyor ve
  /// ganimetin anlamı kalmıyor; sıfıra yaklaştıkça kimse kullanmıyor.
  ///
  /// Bire eşit ya da büyük olamaz — olsaydı sentez bedava yükseltme yolu
  /// olurdu.
  static double get sentezVerimi => TasarimGirdileri.rankArtisi / sentezOrani;

  /// [kademe] kademe yukarı çıkmak için gereken TABAN eşya sayısı.
  ///
  /// `oran ^ kademe`. Üstel, ve üstel olması sentezi YEREL tutan şey: bir
  /// kademe 3, iki kademe 9, üç kademe 27 — dördüncüde 81'e çıkıp pratik
  /// ufkun dışına düşüyor.
  static int sentezMaliyeti(int kademe) {
    if (kademe < 0) throw ArgumentError.value(kademe, 'kademe', 'eksi olamaz');
    return math.pow(sentezOrani, kademe).toInt();
  }

  /// Sentezle çıkılabilecek EN ÇOK kademe — [ufukSiniri] eşyanın altında
  /// kalan son kademe.
  ///
  /// Sentezin drop'un yerine geçememesini bu sayı garanti ediyor: yirmi
  /// kademelik merdivenin dibinden tavanına sentezle çıkmak 3^19 ≈ 1,16
  /// milyar eşya demek.
  static int get sentezUfku {
    var kademe = 0;
    while (sentezMaliyeti(kademe + 1) <= ufukSiniri) {
      kademe++;
    }
    return kademe;
  }

  /// Bir oyuncunun makul olarak biriktirebileceği eşya sayısı.
  ///
  /// Sentez ufkunun ölçüldüğü sınır. Otuz eşya bir oyun oturumunun ganimeti;
  /// yüz eşya bir haftanınki, ve orada envanter zaten taşıyor.
  static const int ufukSiniri = 30;

  // ══ Malzeme kapısı ═════════════════════════════════════════════════

  /// Bir yükseltmenin MALZEME maliyeti — kredi maliyetinin malzeme karşılığı.
  ///
  /// **Türetilen, ilan edilen değil.** Alan 14 malzeme TALEBİNİ zaten
  /// tanımlamış: `nesil bütçesi × (artı basma + sentez payı) ÷ malzeme
  /// değeri` ([Ganimet.malzemeTalebiFor]). Bir yükseltmenin payı da aynı
  /// bölme: kredi maliyeti ÷ malzeme değeri. Toplam böylece inşaen talebe
  /// eşit çıkıyor — arz/talep oranını ikinci bir sayı bozmuyor.
  ///
  /// **Malzeme İKİNCİ PARA BİRİMİ DEĞİL, kapı.** Miktar krediyle orantılı
  /// olduğu için ayrı bir birikim ekseni açmıyor; kapıyı yapan şey RANK
  /// KİLİDİ: S rank eşya S rank malzeme istiyor ve o malzeme yalnız S rank
  /// içerikten düşüyor. Kredi mübadele edilebilir, malzeme edilemez.
  ///
  /// Yukarı yuvarlanıyor: sıfır malzemeli bir yükseltme kapıyı açık bırakırdı.
  /// KARAR 07.9 s1
  static int malzemeMaliyeti(int seviye, ItemTier tier) {
    final kredi = ItemLevels.upgradeCost(seviye, tier);
    if (kredi <= 0) return 0;
    return (kredi / Ganimet.malzemeDegeriFor(rankOf(tier))).ceil();
  }

  /// [tier]'ın rank merdivenindeki sırası.
  ///
  /// Bugün birebir ([Turetilenler.rankSayisi] = `ItemTier.values.length`) ve
  /// bir test bunu kilitliyor; yine de dolaylı, çünkü eşitliğin kendisi bir
  /// tasarım kararı ve değişebilir.
  static int rankOf(ItemTier tier) => tier.index;

  // ══ Alt stat çevirme ═══════════════════════════════════════════════

  /// STAT BAŞINA çevirici — harf ailesinden.
  ///
  /// **Çevirme KREDİ almıyor.** Alan 13'ün gider kalemlerinde çevirme YOK
  /// (`artiBasma · sentez · magaza · birikim · onarim`); kredi almak modelin
  /// görmediği bir musluk açardı. Sınırlayan şey nadirlik: kaynak yalnız eşya
  /// parçalayarak düşüyor ([GanimetCekilisi.parcalamaCeviriciKazanci]).
  ///
  /// **Merdiven HARF AİLESİNDEN.** Alt stat sayısı da aynı eksende artıyor
  /// ([ItemBudget.altStatSayisi]) ve sebebi aynı: aile KABA niteliklerin
  /// birimi, basamak ise ince güç farkının. C:1 · B:2 · A:3 · S:4 · SS:5 ·
  /// SSS ve üstü:6.
  /// KARAR 07.8 s2
  static int statBasinaCevirici(ItemTier tier) => tier.aile + 1;

  /// Bir ÇEVİRMENİN bedeli.
  ///
  /// Çevirme kilitli olmayan BÜTÜN alt statları birden çeviriyor (karar
  /// 07.5): bedel her stat için ödeniyor, `statBaşına × statSayısı`. Kilit
  /// bedeli DOĞRUSAL artırıyor, `× (1 + kilit)`: iyi rolü koruyup kalanı
  /// kovalamak her kilitle bir taban daha pahalı. Altı kilitle tek statı
  /// çevirmek yedi taban; eski tek stat çevirmesinin yerine geçen şey bu ve
  /// bilerek pahalı.
  ///
  /// [statSayisi] eşyanın GERÇEK alt stat sayısı: roketatar havuzu altı,
  /// kapasitesi yedi; yediye ödetmek olmayan stat için para almak olurdu.
  /// KARAR 07.5 s2 · KARAR 07.8 s2
  static int cevirmeBedeli(ItemTier tier, int statSayisi, {int kilit = 0}) =>
      statBasinaCevirici(tier) * statSayisi * (1 + kilit);

  /// Bir statı MÜKEMMEL role getirmek için beklenen deneme sayısı.
  ///
  /// [TasarimGirdileri.cevirmeKaliteHedefi]'nin tersi — %1 dilim, yüz deneme.
  /// İlk roll eşyayla geldiği için bir eksik değil: mükemmeli kovalayan
  /// oyuncu için ilk roll de bir denemedir ve ortalama yüz denemede geliyor.
  static int get yuvaBasinaCevirme =>
      (1 / TasarimGirdileri.cevirmeKaliteHedefi).round();

  /// Bir yuvayı KİLİTLEYEREK mükemmele çıkarmanın beklenen çevirici bedeli.
  ///
  /// Açgözlü kilit: hedefe varan stat kilitlenir. `k` açık statla bir sonraki
  /// isabet ortalama `1 ÷ (k·p)` çevirmede geliyor ve o sırada bedel
  /// `n − k` kilitle ödeniyor. Ölçü aracı, ayar kolu değil: bu sayı ile bir
  /// neslin ÇEVİRİCİ arzı arasındaki fark, mükemmelin ne kadar nadir olduğu.
  static double yuvaBasinaCevirici(ItemTier tier) {
    final n = ItemBudget.altStatSayisi(tier);
    final p = TasarimGirdileri.cevirmeKaliteHedefi;
    var toplam = 0.0;
    for (var acik = n; acik >= 1; acik--) {
      toplam += 1 / (acik * p) * cevirmeBedeli(tier, n, kilit: n - acik);
    }
    return toplam;
  }

  /// Bir nesilde bütün yuvaları mükemmele çıkarmak kaç çevirici ister.
  static double nesildeGerekenCevirici(int rank) =>
      HullClass.yuvaSayisi(ReferansBuild.kademeOf(rank)) *
      yuvaBasinaCevirici(ItemTier.values[rank]);

  // ══ Kırılma yasağı ═════════════════════════════════════════════════

  /// Her işlemin başarısızlık şansı — **her rankta, her seviyede sıfır.**
  ///
  /// Fonksiyon olması bilinçli: bir gün "yalnız üst ranklarda" diye bir
  /// istisna açılmak istenirse, o istisnanın buraya yazılması ve değişmez
  /// testini kırması gerekiyor.
  /// KARAR 07.2 s1
  static double basarisizlikSansi(ItemTier tier, int seviye) =>
      TasarimGirdileri.basarisizlikSansi;

  /// Hiçbir işlem eşya YOK ETMİYOR.
  ///
  /// Sentez girdileri tüketiyor ama bir çıktı veriyor; çevirme değeri
  /// değiştiriyor ama eşyayı silmiyor; artı basma başarısız olmuyor.
  /// KARAR 07.2 s1
  static const bool esyaYokEdilebilir = false;
}
