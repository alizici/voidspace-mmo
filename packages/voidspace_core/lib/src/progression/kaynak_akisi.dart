import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import '../design/turetilenler.dart';
import 'currency.dart';
import 'hull.dart';
import 'item.dart';
import 'referans_build.dart';

/// Oyunun ÜÇ kaynağı — alan 13.
///
/// [Currency] ikisini taşıyor (kredi ve NOVA); üçüncüsü [malzeme] ve o bir
/// para birimi DEĞİL, bu yüzden `Currency`'ye eklenmedi.
///
/// Sebep tek cümle: malzemenin tek bir bakiyesi yok. Bir S rank eşyayı
/// yükseltmek S rank malzeme istiyor, yani malzeme rank başına ayrı bir
/// stok. Tek sayıya indirmek onu ikinci bir krediye çevirirdi — ve o zaman
/// rank kapısı diye bir şey kalmazdı.
/// KARAR 13.1 s1
enum Kaynak {
  /// Yaratık ödülünden. Kademeyle ×291 büyüyor, enflasyona açık, yorgunlukla
  /// kısılıyor. Güçlendirmenin YAKITI: ne kadar hızlı ilerlediğini belirliyor.
  kredi,

  /// Eşya parçalamadan — yalnız ganimetten. Kademeyle ölçekleniyor ama rank
  /// başına ayrı stok. Güçlendirmenin KAPISI: hangi rankı yükseltebildiğini
  /// belirliyor.
  ///
  /// Kredi biriktiren oyuncu üst rank eşyasını yine de yükseltemiyor, çünkü
  /// eksik olan para değil malzeme. Kredi enflasyonuna karşı ikinci koruma
  /// bu.
  malzeme,

  /// Yaratık ödülünden. Kademeyle ÖLÇEKLENMİYOR — gerçek parayla rekabet
  /// ediyor.
  nova;

  /// Kademeyle ölçekleniyor mu.
  bool get olceklenir => this != nova;

  /// Yorgunluk eğrisi uygulanıyor mu.
  ///
  /// Yalnız krediye. NOVA zaten kıt — ikinci kez cezalandırmak anlamsız;
  /// malzemenin arzı ganimet oranlarıyla (alan 14) ayrıca kısıtlanıyor.
  bool get yorgunlugaTabi => this == kredi;
}

/// Bir gider kalemi.
/// KARAR 13.3 s1 · KARAR 13.5 s1
enum GiderKalemi {
  /// Ekonominin ana gideri.
  artiBasma,

  /// Fazla eşyayı ranka çevirmek.
  sentez,

  /// Yedek parça ve doğrudan alım.
  magaza,

  /// Gider DEĞİL, tampon. Harcanmadan duruyor.
  birikim,

  /// TÜRETİLEN — payı alan 11'in ölüm maliyetinden çıkıyor.
  onarim,
}

/// KAYNAK AKIŞI — üç musluk, dönüşüm yasağı, gider yapısı.
///
/// Bir ekonominin sağlığı musluk ile giderin eşit olmasına bağlı değil,
/// **farklı kaynakların birbirine dönüşmemesine** bağlı. Dönüşüm serbest
/// olduğu anda üç musluk tek musluğa iner ve en verimli olanı diğerlerini
/// öldürür.
abstract final class KaynakAkisi {
  // ══ Dönüşüm yasağı ═════════════════════════════════════════════════

  /// [kaynak]'tan [hedef]'e çevirme mümkün mü — **her zaman `false`.**
  ///
  /// Fonksiyon olması bilinçli: bir gün "yalnız kredi → malzeme" gibi bir
  /// istisna açılmak istenirse, o istisnanın buraya yazılması ve değişmez
  /// testini kırması gerekiyor.
  /// KARAR 13.2 s1
  static bool cevrilebilir(Kaynak kaynak, Kaynak hedef) =>
      TasarimGirdileri.paraCevirmeAcik && kaynak != hedef;

  /// Bir [Currency]'nin karşılık geldiği kaynak.
  static Kaynak kaynagi(Currency para) => switch (para) {
    Currency.credit => Kaynak.kredi,
    Currency.premium => Kaynak.nova,
  };

  // ══ Gider payları ══════════════════════════════════════════════════

  /// ONARIM PAYI — türetilen, ilan edilmeyen.
  ///
  /// `sıklık × maliyet ÷ 60`. Beş gider kaleminin yalnız biri türetilen, ama
  /// o biri diğer dördünü belirliyor: playtest sıklığı değiştirdiğinde beşi
  /// birden yeniden hesaplanıyor.
  /// KARAR 13.3 s1
  static double get onarimPayi =>
      TasarimGirdileri.genelOlumSikligi * TasarimGirdileri.olumMaliyetiDk / 60;

  /// Onarım düşüldükten sonra bölünecek pay.
  static double get bolunenPay => 1 - onarimPayi;

  /// [kalem]'in ETKİN payı — toplamları tam 1,0.
  /// KARAR 13.3 s1
  static double payFor(GiderKalemi kalem) => switch (kalem) {
    GiderKalemi.onarim => onarimPayi,
    GiderKalemi.artiBasma => bolunenPay * TasarimGirdileri.payArti,
    GiderKalemi.sentez => bolunenPay * TasarimGirdileri.paySentez,
    GiderKalemi.magaza => bolunenPay * TasarimGirdileri.payMagaza,
    GiderKalemi.birikim => bolunenPay * TasarimGirdileri.payBirikim,
  };

  // ══ Nesil bütçesi ══════════════════════════════════════════════════

  /// [rank] bandının SAATLİK kredi geliri — merdivenin musluğu.
  ///
  /// Üç yerde birden okunuyor (nesil bütçesi, endgame, droid onarımı); üç
  /// ayrı çağrı yerine tek ad, çünkü hepsi aynı sayıyı sormak zorunda.
  static double saatlikGelirFor(int rank) => TuretilenTablolar.gelirFor(
    rank,
    taban: TasarimGirdileri.tabanSaatlikGelir,
    artis: TasarimGirdileri.rankArtisi,
    us: TasarimGirdileri.gelirUssu,
  );

  /// [rank] bandında kazanılan TOPLAM kredi — saatlik gelir × bandın süresi.
  static double neselButcesi(int rank) =>
      saatlikGelirFor(rank) * Turetilenler.bantSuresi(rank);

  /// [rank] bandında BİR YUVAYA düşen artı bütçesi.
  ///
  /// Yuva sayısı bandın gövde kademesinden geliyor ve merdiven boyunca
  /// artıyor — **yuva enflasyonu**: aynı bütçe daha fazla eşyaya bölünüyor.
  /// Artı payının FİLOYA giden kesri — droid grubunun bütçe payı (08.1).
  ///
  /// Filo yuvaları gövde yuvalarıyla aynı kaba girmiyor: on yuva sayıya
  /// katılsaydı yuva başına bütçe yarıya iner, ulaşılan artı düşerdi. Ayrı
  /// kalem, droid payından: gücün yüzde on beşini taşıyan filo, artı
  /// bütçesinin de o kadarını alır (borç defteri B19).
  /// KARAR 13.6 s2
  static double get droidKesri => TasarimGirdileri.payDroid / 100;

  static double yuvaBasinaArti(int rank) {
    final kademe = ReferansBuild.kademeOf(rank);
    return neselButcesi(rank) *
        payFor(GiderKalemi.artiBasma) *
        (1 - droidKesri) /
        HullClass.yuvaSayisi(kademe);
  }

  /// Filo yuvası başına artı bütçesi — ayrı kalem (13.6).
  /// KARAR 13.6 s2
  static double droidBasinaArti(int rank) =>
      neselButcesi(rank) *
      payFor(GiderKalemi.artiBasma) *
      droidKesri /
      TasarimGirdileri.droidFiloTavani;

  /// [rank] bandının bütçesiyle ULAŞILAN artı seviyesi.
  ///
  /// Hiçbir nesilde +15'e ulaşılmıyor ve bu bir kusur değil, endgame'in
  /// TANIMI: 07'nin maliyet eğrisi son seviyeleri bilerek 12 kat pahalı
  /// yaptı.
  ///
  /// Ulaşılan seviye merdiven boyunca DÜŞÜYOR (yuva enflasyonu): erken oyun
  /// derin, geç oyun geniş. Derinlik, tavana varıldığında geri geliyor.
  /// KARAR 13.6 s2
  static int ulasilanSeviye(int rank, ItemTier tier) =>
      _ulasilan(yuvaBasinaArti(rank), tier);

  /// Filodaki droidin bir nesilde ulaştığı artı (13.6).
  static int droidUlasilanSeviye(int rank, ItemTier tier) =>
      _ulasilan(droidBasinaArti(rank), tier);

  static int _ulasilan(double butce, ItemTier tier) {
    var seviye = 0;
    while (seviye < ItemLevels.max &&
        ItemLevels.totalCost(seviye + 1, tier) <= butce) {
      seviye++;
    }
    return seviye;
  }

  // ══ Endgame ════════════════════════════════════════════════════════

  /// Tavana varan oyuncunun bütün yuvalarını +15 yapması kaç SAAT sürer.
  ///
  /// Ana oyunun üstüne binen kuyruk. Yeni bölge, yeni rank, yeni gövde
  /// gerektirmiyor — yalnız var olan eşyaların derinleşmesi. İçerik üretim
  /// hızının en gerildiği noktada nefes alanı: oyuncu tavanı gördüğünde
  /// oyunun bitmesi gerekmiyor.
  /// KARAR 13.6 s2
  static double get endgameSuresi {
    final sonRank = Turetilenler.rankSayisi - 1;
    final kademe = ReferansBuild.kademeOf(sonRank);
    // "Bütün yuvalar": gövdenin yuvaları VE filonun on yuvası (13.6).
    final maliyet =
        (HullClass.yuvaSayisi(kademe) + TasarimGirdileri.droidFiloTavani) *
        ItemLevels.totalCost(ItemLevels.max, ItemTier.values.last);
    final saatlik = saatlikGelirFor(sonRank) * payFor(GiderKalemi.artiBasma);
    return maliyet / saatlik;
  }

  /// Ana oyun + endgame, saat.
  static double get toplamSure => TasarimGirdileri.hedefSure + endgameSuresi;

  // ══ Ömür boyu musluk ═══════════════════════════════════════════════

  /// Bir oyuncunun ömrü boyunca bastığı kredi.
  static double get omurBoyuKredi {
    var toplam = 0.0;
    for (var r = 0; r < Turetilenler.rankSayisi; r++) {
      toplam += neselButcesi(r);
    }
    return toplam;
  }

  /// Ömür boyu basılan NOVA — bantla ölçeklenmediği için yalnız SÜRE.
  ///
  /// Saatlik hız sıradan yaratığın çevriminden çıkıyor ve yirmi bantta da
  /// aynı. Üst bölgedeki oyuncunun avantajı NOVA kazanmakta değil, NOVA'ya
  /// ihtiyacı olmamakta.
  static double get omurBoyuNova {
    final cevrim =
        TasarimGirdileri.siradanDogusSuresi +
        TasarimGirdileri.siradanOldurmeSuresi;
    final saatlik = TasarimGirdileri.novaOdulu * 3600 / cevrim;
    return saatlik * TasarimGirdileri.hedefSure;
  }
}
