import '../design/tasarim_alanlari.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import '../progression/hull.dart';
import '../world/yaratik_kadrosu.dart';

/// Bir KARAR DÖNGÜSÜ — grafiğin geri kenarı.
///
/// Tasarım kuralı katmanlı: her alan yalnız üstündekine bakabilir. Ama
/// bağımlılık grafiği çizildiğinde geri kenarlar çıkıyor — ve hepsi aynı
/// biçimde: **bir değer değil, bir karar taşıyorlar.** Alt alan bir soru
/// yukarı gönderiyor, üst alan cevabı veriyor, ve cevap verildikten sonra
/// kenar kayboluyor.
///
/// Yani grafik ÇALIŞMA ZAMANINDA döngüsüz. Döngüler tasarım sürecinin izleri,
/// veri akışının değil.
///
/// Ayrım kritik: gerçek bir veri döngüsü — A'nın çıktısı B'nin girdisi,
/// B'nin çıktısı A'nın girdisi — çözülemez, sayılar ya yakınsamaz ya keyfî
/// bir başlangıca bağlı kalır. Karar döngüsü bir kez çözülür, kararı yazılır,
/// bir daha çalıştırılmaz.
///
/// Yeni bir alan yeni bir döngü açabilir — **açılması sorun değil,
/// kapatılmadan bırakılması sorun.**
class KararDongusu {
  const KararDongusu({
    required this.soran,
    required this.cevaplayan,
    required this.soru,
    required this.karar,
  });

  /// Soruyu yukarı gönderen alan.
  final int soran;

  /// Cevabı veren — [soran]'ın üstünde olmak zorunda değil, o yüzden döngü.
  final int cevaplayan;

  final String soru;

  /// Verilen karar. Boşsa döngü AÇIK demektir.
  final String karar;

  bool get kapali => karar.isNotEmpty;

  @override
  String toString() => '$soran ↔ $cevaplayan · $soru → $karar';
}

/// Bir sistemin BUGÜNKÜ hâli ile hedefi.
///
/// Sayılar canlı koddan okunuyor, elle yazılmıyor: bir sistem inşa edildikçe
/// açık kendiliğinden kapanıyor. Elle tutulan bir eksik listesi, tamamlanmış
/// bir işi eksik göstermeye devam ederdi.
class SistemDurumu {
  const SistemDurumu({
    required this.ad,
    required this.mevcut,
    required this.hedef,
    required this.alan,
  });

  final String ad;
  final int mevcut;
  final int hedef;

  /// Hangi alanın sorumluluğu.
  final int alan;

  bool get tamam => mevcut >= hedef;

  double get oran => hedef == 0 ? 1 : mevcut / hedef;

  @override
  String toString() => '$ad $mevcut/$hedef (alan $alan)';
}

/// DENGE DENETİMİ — alan 16.
///
/// **Yeni bir kural üretmiyor: var olanları çalıştırılabilir hâle getiriyor.**
/// On beş alan boyunca her belge sonunda aynı tabloyu yazdı — "bu kırılırsa ne
/// olur". 16 o tabloları bir araya getiriyor.
///
/// Sistemin temeli tek cümle: **tepe tabloda olmayan hiçbir sayı elle
/// yazılamaz.** 92 girdiye karşılık binlerce türetilen sayı — bir tasarımcının
/// aklında tutması gereken şey 92 karar, geri kalanı hesap.
///
/// **Denetimin yakalayamadığı şey de yazılı olmalı:** sıkıcı olup olmadığını,
/// savaşın iyi hissettirip hissettirmediğini, ve sayıların DOĞRU olup
/// olmadığını. Bütün sistem tutarlılık üzerine kurulu, doğruluk üzerine değil.
/// "TTK 30 saniye olsun" bir zevk meselesi; 16'nın söyleyebildiği tek şey o
/// kararın her yere aynı şekilde yansıyıp yansımadığı.
abstract final class DengeDenetimi {
  // ══ Karar döngüleri ════════════════════════════════════════════════

  /// Grafiğin geri kenarları — dördü de kapalı.
  /// KARAR 16.2 s1
  static const dongular = [
    KararDongusu(
      soran: 3,
      cevaplayan: 9,
      soru: 'savunma statları fiyatlandı ama çapa bilinmiyordu',
      karar: 'kur türetildi, StatMod\'lar savunma çapasıyla ölçeklendi',
    ),
    KararDongusu(
      soran: 4,
      cevaplayan: 8,
      soru: 'gövde havuzu girdi sanıldı',
      karar: 'TTK kısıtından türetildi',
    ),
    KararDongusu(
      soran: 6,
      cevaplayan: 7,
      soru: 'artı kazancında belge ↔ kod çelişkisi',
      karar: 'üçüncü seçenek: toplamsal kazanç + çözülmüş maliyet eğrisi',
    ),
    KararDongusu(
      soran: 13,
      cevaplayan: 14,
      soru: 'malzeme talebi ilan edildi, arz bilinmiyordu',
      karar: 'arz çözüldü — oran her bantta ×1,63',
    ),
  ];

  // ══ Tepe tablo ═════════════════════════════════════════════════════

  static int get girdiSayisi => TasarimGirdileri.hepsi.length;

  /// Alan → o alanın koyduğu girdi sayısı.
  static Map<int, int> get girdiDagilimi {
    final sonuc = <int, int>{};
    for (final g in TasarimGirdileri.hepsi) {
      sonuc[g.alan] = (sonuc[g.alan] ?? 0) + 1;
    }
    return sonuc;
  }

  /// Girdi koyan alan başına ortalama.
  ///
  /// **Girdi sayısı yüksekse alan muhtemelen kendi kısıtını kendisi
  /// belirliyor demektir** — ve o durumda kısıt kısıt olmaktan çıkar.
  static double get ortalamaGirdi => girdiSayisi / girdiDagilimi.length;

  /// Çakışan girdiler — aynı adı iki kez taşıyanlar.
  ///
  /// Denetimin ilk çalıştırmasında bulduğu hata sınıfı: iki isim aynı kararı
  /// taşıyor, ikisi de aynı değerde olduğu için bugün hiçbir şey bozulmuyor —
  /// ama biri değiştirilirse diğeri sessizce eski değerde kalıyor.
  /// KARAR 16.3 s1
  static List<String> get cakisanGirdiler {
    final gorulen = <String, int>{};
    for (final g in TasarimGirdileri.hepsi) {
      gorulen[g.ad] = (gorulen[g.ad] ?? 0) + 1;
    }
    return [
      for (final e in gorulen.entries)
        if (e.value > 1) e.key,
    ];
  }

  /// Gerekçesi yazılmamış girdiler.
  ///
  /// Gerekçe süs değil: bir sayının neden o değer olduğu yazılmadığında, bir
  /// sonraki denge turunda gerekçe sayıya uydurulmaya başlar.
  static List<String> get gerekcesizGirdiler => [
    for (final g in TasarimGirdileri.hepsi)
      if (g.gerekce.trim().length < 10) g.ad,
  ];

  // ══ Alan durumu ════════════════════════════════════════════════════

  static List<TasarimAlani> get yazilanlar => [
    for (final a in TasarimHaritasi.hepsi)
      if (a.durum == BelgeDurumu.yazildi) a,
  ];

  static double get tamamlanmaOrani =>
      yazilanlar.length / TasarimHaritasi.hepsi.length;

  /// Bağımlılığı henüz yazılmamış bir alandan gelen alanlar.
  ///
  /// Boş olmak zorunda: bir alan, okuduğu alan yazılmadan yazılamaz.
  static List<String> get sirasizYazilanlar => [
    for (final a in yazilanlar)
      for (final ust in a.bagimlilik)
        if (TasarimHaritasi.byNo(ust)?.durum != BelgeDurumu.yazildi)
          '${a.no} ← $ust',
  ];

  // ══ Eksik sistemler ════════════════════════════════════════════════

  /// Hedef merdivenin uzunluğu — belgelerin yazıldığı kurulum.
  static const int hedefRankSayisi = 20;

  /// Hedef gövde kademesi sayısı.
  static const int hedefKademeSayisi = 8;

  /// Bugünkü sistemlerin hedefe göre durumu — hepsi CANLI ölçülüyor.
  /// KARAR 16.4 s1
  static List<SistemDurumu> get sistemler => [
    SistemDurumu(
      ad: 'rank',
      mevcut: Turetilenler.rankSayisi,
      hedef: hedefRankSayisi,
      alan: 6,
    ),
    SistemDurumu(
      ad: 'gövde kademesi',
      mevcut: TasarimGirdileri.govdeKademeSayisi,
      hedef: hedefKademeSayisi,
      alan: 4,
    ),
    // Bu satır da bir kez YANLIŞ ölçtü ve tam olarak yaratık satırıyla aynı
    // hatayla: `cizilenler` uzunluğunu okuyordu ve 3/8 diyordu. O liste elle
    // yazılmış STAT satırları, sanat değil — istemcide tek gövde çizimi var.
    SistemDurumu(
      ad: 'çizilmiş gövde',
      mevcut: HullClass.sanatiOlanKademeSayisi,
      hedef: hedefKademeSayisi,
      alan: 4,
    ),
    SistemDurumu(
      ad: 'harita',
      mevcut: Turetilenler.haritaSayisi,
      hedef: hedefKademeSayisi * TasarimGirdileri.bolgeBasinaHarita,
      alan: 11,
    ),
    // Bu satır bir kez YANLIŞ ölçtü: `AlienStats.all` uzunluğunu okuyordu ve
    // 2/32 diyordu. O liste elle tutulan ESKİ kayıt; sunucu kadrodan
    // doğuruyor. Doğru sayı iki şeyle kısıtlı — bölge sayısı ve boss'un
    // serpilmemesi — ve ikisi de canlı okunuyor.
    SistemDurumu(
      ad: 'serpilen yaratık',
      mevcut: YaratikKadrosu.serpilenler(Turetilenler.bolgeSayisi).length,
      hedef: YaratikKadrosu.hepsi.length,
      alan: 12,
    ),
    SistemDurumu(
      ad: 'tasarlanmış yaratık',
      mevcut: YaratikKadrosu.hepsi.length,
      hedef: hedefKademeSayisi * 4,
      alan: 12,
    ),
  ];

  static List<SistemDurumu> get eksikler => [
    for (final s in sistemler)
      if (!s.tamam) s,
  ];

  /// Sistemlerin ortalama tamamlanma oranı.
  /// KARAR 16.4 s1
  static double get sistemOrani {
    if (sistemler.isEmpty) return 1;
    return sistemler.fold(0.0, (a, s) => a + s.oran.clamp(0.0, 1.0)) /
        sistemler.length;
  }
}
