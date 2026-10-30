import 'dart:math' as math;

/// TÜRETİLEN TABLOLAR — merdivenler.
///
/// [Turetilenler] tek tek sayıları çözüyor (kritiğin beklenen değeri, zırh
/// eğrisinin K'sı). Burada MERDİVENLER var: rank çarpanları, gövde
/// kademelerinin kapsadığı rank aralıkları, kademe normalizatörü, bant
/// gelirleri, ve TTK kısıtından çözülen gövde havuzu.
///
/// **Hepsi tam sayı anahtarlı ve parametre alan saf fonksiyon.** İki sebep:
///
/// 1. Mimari testi `design/` altındaki hiçbir dosyanın `progression/` ya da
///    `sim/` import etmesine izin vermiyor ("aşağı yalnız yukarıyı okur").
///    Yani bu katman `HullClass` ya da `ItemTier` göremez — okuma yönü tersi:
///    büyüme katmanı BURADAN okur.
/// 2. Girdiler ait oldukları alan yazılana kadar [TasarimGirdileri]'ne
///    giremiyor. Parametre alan biçim (`...For`) matematiği bugünden test
///    edilebilir kılıyor; alan yazıldığında üstüne ince bir bağlayıcı geliyor
///    — [Turetilenler.kritikBeklenenDeger] ile
///    [Turetilenler.kritikBeklenenDegerFor] çiftinin yaptığı şey.
///
/// Bu dosyada ÇAĞIRAN yok ve olmaması normal: iskelet, bağlayıcılar alanlarla
/// birlikte gelecek.
abstract final class TuretilenTablolar {
  // ══ Rank merdiveni ═════════════════════════════════════════════════

  /// Bir rankın güç çarpanı: `artis ^ kademe`.
  ///
  /// Kademe 0 taban (çarpan 1,0). Merdivenin TEK girdisi [artis]; yirmi rankın
  /// yirmisi de ondan çıkıyor, yani bir rank eklemek yeni bir sayı değil bir
  /// üs demek.
  static double rankCarpaniFor(int kademe, double artis) {
    if (kademe < 0) throw ArgumentError.value(kademe, 'kademe', 'eksi olamaz');
    return math.pow(artis, kademe).toDouble();
  }

  // ══ Gövde kademesi ↔ rank ══════════════════════════════════════════

  /// [kademe]'nin kapsadığı rank aralığı — `[baslangic, bitis)`.
  ///
  /// Bölme TABAN (floor) ile: `baslangic(k) = k × rankSayisi ÷ kademeSayisi`.
  /// Yuvarlama DEĞİL, ve bu bir incelik değil zorunluluk: yuvarlama kipi
  /// dile göre değişiyor (Python bankacı yuvarlaması yapar, Dart sıfırdan
  /// uzağa) ve aynı tasarım iki dilde farklı merdiven üretirdi.
  static (int, int) rankAraligiFor(
    int kademe, {
    required int rankSayisi,
    required int kademeSayisi,
  }) {
    if (kademe < 0 || kademe >= kademeSayisi) {
      throw ArgumentError.value(kademe, 'kademe', 'aralık dışı');
    }
    if (kademeSayisi > rankSayisi) {
      throw ArgumentError(
        'kademe sayısı rank sayısını aşamaz: boş kademe doğar',
      );
    }
    final baslangic = kademe * rankSayisi ~/ kademeSayisi;
    final bitis = (kademe + 1) * rankSayisi ~/ kademeSayisi;
    return (baslangic, bitis);
  }

  /// KADEME NORMALİZATÖRÜ `N(k)` — bütün dönüşüm sabitlerinin çarpanı.
  ///
  /// Tanımı: kademenin kapsadığı rankların çarpanlarının GEOMETRİK ORTASI,
  /// kademe 0'a bölünmüş (yani `N(0) = 1` her zaman).
  ///
  /// **Ne işe yarıyor.** `z / (z + K)` biçimindeki her azalan-getiri eğrisi,
  /// `z` büyürken `K` sabit kalırsa doyuyor. Yirmi ranklık bir merdivende
  /// eşya bütçesi 2.620 kat büyüyor; sabit `K` ile zırh azaltması %99,9'a
  /// çıkıyor ve savaş duruyor. `K(k) = K₀ × N(k)` bunu kapatıyor: oranlar her
  /// kademede aynı kalıyor, büyüyen yalnız mutlak sayılar.
  ///
  /// Aynı sebeple ORAN statları `N`'e bölünüyor — World of Warcraft'ın
  /// *combat rating* sisteminin yaptığı şey.
  static double normalizatorFor(
    int kademe, {
    required int rankSayisi,
    required int kademeSayisi,
    required double artis,
  }) {
    double orta(int k) {
      final (bas, bit) = rankAraligiFor(
        k,
        rankSayisi: rankSayisi,
        kademeSayisi: kademeSayisi,
      );
      // Geometrik ortanın üssü = kapsanan rankların ARİTMETİK ortası, çünkü
      // çarpanların hepsi aynı tabanın kuvvetleri.
      var toplam = 0;
      for (var i = bas; i < bit; i++) {
        toplam += i;
      }
      return toplam / (bit - bas);
    }

    return math.pow(artis, orta(kademe) - orta(0)).toDouble();
  }

  /// Normalizatörün KAPALI FORMU: `artis ^ (kademe × rankSayisi ÷ kademeSayisi)`.
  ///
  /// [normalizatorFor] ile HER ZAMAN aynı sonucu vermiyor — yalnız bölmenin
  /// simetrik olduğu eşleşmelerde. 20 rank × 8 kademe böyle bir eşleşme
  /// (kademe oranı sabit **×2,497**), 20 × 7 ya da 19 × 8 değil.
  ///
  /// Ayrı durmasının sebebi bir kısayol değil bir TEŞHİS: ikisi ayrışıyorsa
  /// seçilen rank/kademe sayıları düzensiz bir merdiven üretiyor demektir ve
  /// bu, gövde kademeleri arasındaki güç sıçramasının eşit olmaması demek.
  /// [uyumluBolme] o soruyu doğrudan cevaplıyor.
  static double normalizatorKapaliFor(
    int kademe, {
    required int rankSayisi,
    required int kademeSayisi,
    required double artis,
  }) => math.pow(artis, kademe * rankSayisi / kademeSayisi).toDouble();

  /// Bölme SİMETRİK Mİ — her gövde kademesi eşit güç sıçraması veriyor mu.
  ///
  /// `true` ise kapalı form geçerli ve merdiven düzgün; `false` ise kademeler
  /// arası sıçrama ragged olur (örn. ×2,50 · ×3,00 · ×2,08).
  static bool uyumluBolme({
    required int rankSayisi,
    required int kademeSayisi,
  }) {
    if (kademeSayisi > rankSayisi) return false;
    const tolerans = 1e-9;
    for (var k = 0; k < kademeSayisi; k++) {
      final a = normalizatorFor(
        k,
        rankSayisi: rankSayisi,
        kademeSayisi: kademeSayisi,
        artis: 2, // taban önemsiz: üsler karşılaştırılıyor
      );
      final b = normalizatorKapaliFor(
        k,
        rankSayisi: rankSayisi,
        kademeSayisi: kademeSayisi,
        artis: 2,
      );
      if ((a - b).abs() > tolerans * math.max(1, b)) return false;
    }
    return true;
  }

  // ══ Gelir bandı ════════════════════════════════════════════════════

  /// Bir bandın saatlik geliri: `taban × rankÇarpanı ^ us`.
  ///
  /// [us] (α) maliyetin ve gelirin büyüme hızları arasındaki farkı yönetiyor:
  /// maliyet rank çarpanının birinci kuvvetiyle, gelir α'ıncı kuvvetiyle
  /// büyüyor. α < 1 olduğu sürece her nesil bir öncekinden uzun sürüyor.
  ///
  /// α = 0 (gelir sabit) bugünkü hâl ve yirmi kademeli bir merdiveni sekizinci
  /// nesilde durduruyor.
  /// KARAR 10.5 s2
  static double gelirFor(
    int rank, {
    required double taban,
    required double artis,
    required double us,
  }) => taban * math.pow(rankCarpaniFor(rank, artis), us);

  /// Aynı üsle ölçeklenen her SABİT EŞİK — yorgunluk eşiği, günlük tavan,
  /// ilk-imha bonusu.
  ///
  /// Ayrı bir formül değil, [gelirFor]'un aynısı; ayrı bir ad taşımasının
  /// sebebi çağrı yerinde ne olduğunun okunması. Sabit kalan bir eşik, gelir
  /// yirmi kat büyüdüğünde eşik olmaktan çıkıp DUVAR oluyor.
  static double esikFor(
    int rank, {
    required double tabanEsik,
    required double artis,
    required double us,
  }) => gelirFor(rank, taban: tabanEsik, artis: artis, us: us);

  // ══ TTK kısıtı ═════════════════════════════════════════════════════

  /// İki savunma kanalının BİRLEŞİK kayıp çarpanı: `(1 − a)(1 − s)`.
  ///
  /// Çarpımsal, toplamsal DEĞİL: %50 azaltma ile %50 sıyırma birlikte %100
  /// yapmıyor, %75 yapıyor. Toplamsal olsaydı hasarı sıfırlayan bir savunma
  /// build'i var olurdu.
  static double kayipCarpaniFor(double azaltma, double siyirma) =>
      (1 - azaltma) * (1 - siyirma);

  /// GÖVDE HAVUZU — TTK kısıtından çözülür, ilan EDİLMEZ.
  ///
  /// Zincir: bir kademenin saldırısı ve hedef TTK'sı biliniyorsa gereken etkin
  /// can bellidir (`A × T`); savunma kanalları o etkin canı büyüttüğü için
  /// gereken HAM havuz `A × T × kayıp`; eşyaların kattığı düşülünce geriye
  /// gövdenin taban havuzu kalıyor.
  ///
  /// Alan 08 bunu bir kez çözmüştü (23.772). Sekiz kademe için sekiz kez
  /// çözmek yeni bir kural gerektirmiyor — merdiven bir sonuç, bir girdi
  /// değil.
  ///
  /// Eksi dönerse kısıt tutmuyor demektir: eşyalar tek başına hedef TTK'yı
  /// aşıyor, yani gövdenin katacağı bir şey yok. Çağıran bunu bir hata olarak
  /// görmeli — sıfıra kelepçelemek kısıdın kırıldığını gizler.
  static double govdeHavuzuFor({
    required double saldiri,
    required double hedefTTK,
    required double kayipCarpani,
    required double esyaHavuzu,
  }) => saldiri * hedefTTK * kayipCarpani - esyaHavuzu;

  // ══ Nesil süresi ═══════════════════════════════════════════════════

  /// Bir rankta geçirilecek süre — [olcek] ile çarpılmış BAĞIL süre.
  ///
  /// Maliyet rank çarpanının birinci kuvvetiyle, gelir α'ıncı kuvvetiyle
  /// büyüyor; süre ikisinin bölümü, yani `çarpan ^ (1 − α)`. α < 1 olduğu
  /// sürece üs artı ve her nesil bir öncekinden uzun — merdivenin yavaşlama
  /// hissi bu tek üsten geliyor, elle konmuş bir eğriden değil.
  ///
  /// α = 1 olsaydı bütün nesiller eşit uzunlukta olurdu ve oyun ilerledikçe
  /// hiçbir şey değişmezdi; α > 1'de nesiller KISALIRDI.
  /// KARAR 10.5 s2
  static double bantSuresiFor(
    int rank, {
    required double artis,
    required double us,
    required double olcek,
  }) => olcek * math.pow(rankCarpaniFor(rank, artis), 1 - us);

  /// Bağıl sürelerin toplamı [hedefSure] olsun diye gereken ölçek.
  ///
  /// Toplam süre bir GİRDİ (alan 10, 780 saat) ve rankların birbirine oranı
  /// türetiliyor; ölçek ikisini birleştiren tek sayı. Rank eklemek toplamı
  /// bozmuyor, yalnız payı yeniden bölüyor.
  static double sureOlcegiFor({
    required int rankSayisi,
    required double artis,
    required double us,
    required double hedefSure,
  }) {
    var toplam = 0.0;
    for (var r = 0; r < rankSayisi; r++) {
      toplam += math.pow(rankCarpaniFor(r, artis), 1 - us);
    }
    return hedefSure / toplam;
  }

  // ══ Harita ölçüsü ══════════════════════════════════════════════════

  /// BİR BANDIN ALANI — birim kare.
  ///
  /// `oyuncu × π × görüş² × seyreklik`. Üç girdinin üçü de cevaplanabilir bir
  /// soru: kaç oyuncu aynı haritada olsun, ne kadar birbirini görsün, görüş
  /// yarıçapı kaç. "Harita ne kadar büyük olsun" diye bir soru yok.
  static double bantAlaniFor({
    required int oyuncu,
    required double gorus,
    required double seyreklik,
  }) => oyuncu * math.pi * gorus * gorus * seyreklik;

  /// [bantSayisi] bant taşıyan haritanın kenarları — `(genişlik, yükseklik)`.
  ///
  /// Alan bant sayısıyla ÇARPILIYOR, bantlar aynı haritanın iç içe halkaları
  /// olduğu için: iki bantlı bir bölge iki bant dolusu oyuncuyu aynı anda
  /// ağırlıyor.
  static (double, double) haritaBoyutuFor(
    int bantSayisi, {
    required double bantAlani,
    required double enBoy,
  }) {
    if (bantSayisi < 1) {
      throw ArgumentError.value(bantSayisi, 'bantSayisi', 'en az bir');
    }
    if (enBoy <= 0) throw ArgumentError.value(enBoy, 'enBoy', 'artı olmalı');
    final alan = bantAlani * bantSayisi;
    return (math.sqrt(alan * enBoy), math.sqrt(alan / enBoy));
  }

  /// Bir BANTTA kaç yaratık — hedef yoğunluğu tutturan sayı.
  ///
  /// Uzun hâli `alan ÷ (π × görüş²) × hedef`, ama bant alanının tanımında da
  /// aynı çember var ve sadeleşiyor: `oyuncu × seyreklik × hedef`.
  ///
  /// Görüş yarıçapının düşmesi tesadüf değil: yoğunluk çemberin BÜYÜKLÜĞÜNE
  /// değil, haritaya kaç çember sığdığına bağlı. Ekran büyürse harita da
  /// büyüyor ve çemberdeki hedef sayısı değişmiyor.
  static int bantBasinaHedefFor({
    required int oyuncu,
    required double seyreklik,
    required int hedef,
  }) => (oyuncu * seyreklik * hedef).round();

  // ══ Düşman ═════════════════════════════════════════════════════════

  /// YARATIK DPS'i — bir kaçış penceresinden çözülür.
  ///
  /// "Ne kadar acıtsın" ayarlanabilir bir soru değil. Ayarlanabilir soru şu:
  /// [tehdit] yaratığı birden üstüne çeken oyuncunun kaçmak için ne kadar
  /// vakti olsun? Cevap bir pencere, ve hasar o pencerenin sonucu.
  ///
  /// [havuz] oyuncunun HAM havuzu (gövde + kalkan), etkin canı değil. Zırh ve
  /// sıyırma bilerek dışarıda: ikisi de pencereyi UZATIYOR, yani savunma
  /// yatırımı bütçeden düşülmüş bir borç değil kazanılmış bir pay oluyor.
  /// KARAR 12.4 s1
  static double yaratikDpsFor({
    required double havuz,
    required int tehdit,
    required double pencere,
  }) => havuz / (tehdit * pencere);

  /// ÖDÜL — saatlik hedefin bölünmesi.
  ///
  /// Ödül bir tasarım kararı değil bir bölme işlemi: 11 her banda saatlik bir
  /// kredi hedefi verdi, yaratık onu tutturmak zorunda.
  ///
  /// [saniye] yaratığın oyuncunun saatinden ne kadarını aldığı. Sıradan ve
  /// güçlü için ÇEVRİM (yeniden doğma + öldürme) — yeniden doğmayı saymak
  /// kritik, çünkü oyuncu bir sonrakini beklemek zorunda. Boss için
  /// oyuncu-saniye (grup × süre), çünkü maliyeti bir grubun zamanı.
  static double odulFor({
    required double saatlikHedef,
    required double saniye,
    required double prim,
  }) => saatlikHedef * saniye / 3600 * prim;

  /// BOSS DOĞMA ARALIĞI, saat — bandın gelirinin [gelirPayi] kadarını taşısın
  /// diye.
  ///
  /// Saatlik hedef pay ediyor ve sadeleşiyor: aralık BANTTAN BAĞIMSIZ çıkıyor.
  /// Yani oyuncu hangi bölgede olursa olsun aynı ritmi öğreniyor —
  /// öğrenilebilir bir ritim, hatırlanması gereken yirmi ayrı sayıdan iyi.
  /// KARAR 12.5 s1
  static double bossAraligiFor({
    required double odul,
    required double saatlikHedef,
    required double gelirPayi,
  }) {
    if (gelirPayi <= 0 || gelirPayi > 1) {
      throw ArgumentError.value(gelirPayi, 'gelirPayi', '(0, 1] aralığında');
    }
    return odul / (gelirPayi * saatlikHedef);
  }

  // ══ PvP risk primi ═════════════════════════════════════════════════

  /// KAYIP ORANI — saatin ne kadarı ölümlere gidiyor.
  static double pvpKayipOraniFor({
    required double siklik,
    required double maliyetDk,
  }) => siklik * maliyetDk / 60;

  /// BRÜT PRİM — PvP haritası saatte kaç KAT vermeli.
  ///
  /// `(1 + net) ÷ (1 − kayıp)`. Oyuncu ölümlerini de saydıktan sonra `net`
  /// kadar kârlı çıksın diye, harita kaybedilen zamanı da karşılamak zorunda.
  ///
  /// Kayıp oranı 1'e dayandığında çözüm yok ve atmak doğru davranış: saatin
  /// tamamı ölmekle geçiyorsa hiçbir prim oyuncuyu kârlı çıkarmaz. O noktada
  /// yanlış olan formül değil, PvP haritasının ölümcüllüğü.
  static double pvpBrutPrimFor({
    required double netPrim,
    required double kayipOrani,
  }) {
    if (kayipOrani >= 1) {
      throw ArgumentError.value(
        kayipOrani,
        'kayipOrani',
        'saatin tamamı ölümde: prim çözülemez',
      );
    }
    return (1 + netPrim) / (1 - kayipOrani);
  }
}
