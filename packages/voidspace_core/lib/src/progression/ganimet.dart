import 'dart:math' as math;

import '../design/prd.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import '../world/dusman.dart';
import 'hull.dart';
import 'kaynak_akisi.dart';
import 'referans_build.dart';

/// Düşen bir şeyin RANKI — bandın rankına göre.
enum GanimetRanki {
  /// Bir alt rank. Hayal kırıklığı değil: parçalanacak malzeme.
  alt,

  /// Bandın kendi rankı. Normal akış; kalite rollü burada oynanıyor.
  bant,

  /// Bir üst rank. OLAY — ve tek PRD'li sonuç.
  ust,
}

/// GANİMET — alan 14.
///
/// Bir ödül sistemi değil, bir **arz sistemi**. Alan 13 talebi ilan etti: bir
/// nesilde şu kadar malzeme, şu kadar eşya gerekiyor. 14'ün tek işi o talebi
/// karşılamak — ve karşılarken kimsenin kötü şansa takılmamasını sağlamak.
///
/// **Üç ayrı ritim bilinçli.** Malzeme her öldürmede (sürekli — oyuncunun her
/// saniye ilerlediğini hissettiren şey), eşya seyrek (nadir ama beklenebilir),
/// NOVA her öldürmede ve sabit. Tek bir ritim olsaydı ya her düşen
/// değersizleşir ya da uzun boşluklar oyunu durdururdu.
///
/// Kredi bu listede YOK: kredi düşmüyor, yaratık ödülü olarak doğrudan
/// geliyor. Ganimet ile kredi ayrı musluklar (alan 13) ve o ayrım burada da
/// korunuyor.
abstract final class Ganimet {
  // ══ Ritim ══════════════════════════════════════════════════════════

  /// Saatte kaç sıradan yaratık öldürülüyor.
  ///
  /// Çevrimden türüyor: yeniden doğma + öldürme. Farmın saati bu.
  static double get oldurmeHizi {
    final cevrim =
        TasarimGirdileri.siradanDogusSuresi +
        TasarimGirdileri.siradanOldurmeSuresi;
    return 3600 / cevrim;
  }

  /// EŞYA DÜŞME ŞANSI — en dar bandın ihtiyacından türetiliyor.
  ///
  /// `(yuva ÷ kaliteHedefi) ÷ (nesilSüresi × öldürmeHızı) × güvenlik`
  ///
  /// İhtiyaç şu: her yuva için en iyi [TasarimGirdileri.kaliteHedefi]'lik
  /// rollü bir eşya bulmak — ortalama beş deneme, yani yuva sayısının beş
  /// katı eşya.
  ///
  /// **Bütün bantlarda AYNI** ve bu bilinçli: üst bantlarda nesiller uzuyor
  /// ama düşme ritmi değişmiyor, oyuncu aynı sıklıkta eşya görmeye devam
  /// ediyor. Sonucu üst bantlarda BOLLUK: gerekenin katı düşüyor, ve o lüks
  /// +15'e ulaşamayan oyuncunun elindeki tek derinleşme yolu.
  ///
  /// İlk bandın ihtiyacından çıkması da bilinçli — orada tutarsa her yerde
  /// tutar.
  /// KARAR 14.3 s2
  static double get dusmeSansi {
    final yuva = HullClass.yuvaSayisi(0);
    final gereken = yuva / TasarimGirdileri.kaliteHedefi;
    final oldurme = Turetilenler.bantSuresi(0) * oldurmeHizi;
    return (gereken / oldurme * TasarimGirdileri.dusmeGuvenligi).clamp(
      0.0,
      1.0,
    );
  }

  /// İki eşya arasında geçen ortalama süre, DAKİKA.
  static double get dusmeAraligiDk => 60 / (dusmeSansi * oldurmeHizi);

  /// FİLO yuvalarının düşme şansı — ayrı kalem, aynı kural (14.3).
  ///
  /// Gövde şansına eklenmiyor, yanında duruyor: on filo yuvası için de yuva
  /// başına aynı deneme sayısı, aynı nesil, aynı öldürme hızı. Gövde kalemi
  /// olduğu gibi kalıyor; droid eşyası kendi zarını atıyor (borç defteri
  /// B19).
  /// KARAR 14.3 s2
  static double get droidDusmeSansi {
    final gereken =
        TasarimGirdileri.droidFiloTavani / TasarimGirdileri.kaliteHedefi;
    final oldurme = Turetilenler.bantSuresi(0) * oldurmeHizi;
    return (gereken / oldurme * TasarimGirdileri.dusmeGuvenligi).clamp(
      0.0,
      1.0,
    );
  }

  /// İki DROİD düşmesi arasında geçen ortalama süre, DAKİKA.
  ///
  /// Kaybedilen droidin yerine konma süresi bu (05.10): filo kalemi kendi
  /// zarını atıyor, yani yeni droid gövde eşyasının kuyruğunda beklemiyor.
  /// NOVA onarımının fiyatı buradan okunuyor — onarım bu beklemeyi satıyor,
  /// droidi değil.
  /// KARAR 14.3 s2 · KARAR 15.3 s3
  static double get droidDusmeAraligiDk => 60 / (droidDusmeSansi * oldurmeHizi);

  /// Bir eşyanın kaç öldürmeye mal olduğu.
  static double get esyaMaliyeti => 1 / dusmeSansi;

  // ══ Malzeme ════════════════════════════════════════════════════════

  /// Bir öldürmenin verdiği malzeme — **ganimet zamanla orantılı.**
  ///
  /// Sıradan yaratık 1, güçlü 5 (canı da beş katı), boss 120 (üç oyuncunun
  /// her birine kendi süresi kadar). Hızlandırma yok: güçlü yaratığa girmenin
  /// karşılığı ganimet hızı değil, 12'nin verdiği risk primi.
  /// KARAR 14.2 s1
  static double malzemeFor(DusmanSinifi sinif) => switch (sinif) {
    DusmanSinifi.boss => TasarimGirdileri.bossHedefSuresi,
    _ => sinif.oldurmeSuresi,
  };

  /// [sinif]'ın eşya düşürme şansı — canıyla orantılı.
  ///
  /// Boss ayrı: şansa bırakılmıyor, garantili
  /// [TasarimGirdileri.bossEsyaSayisi] eşya düşüyor.
  static double esyaSansiFor(DusmanSinifi sinif) => switch (sinif) {
    DusmanSinifi.boss => TasarimGirdileri.bossEsyaSayisi.toDouble(),
    _ => dusmeSansi * sinif.oldurmeSuresi,
  };

  /// Droid eşyasının sınıfa göre beklenen düşüşü — gövde kalemiyle aynı
  /// oranlar, filo şansından. Boss'ta da aynı oran: garantili sayı filo
  /// şansının gövde şansına oranı kadar.
  /// KARAR 14.3 s2
  static double droidEsyaSansiFor(DusmanSinifi sinif) => switch (sinif) {
    DusmanSinifi.boss =>
      TasarimGirdileri.bossEsyaSayisi * droidDusmeSansi / dusmeSansi,
    _ => droidDusmeSansi * sinif.oldurmeSuresi,
  };

  /// PARÇALAMA VERİMİ — bir eşya kaç malzeme veriyor.
  ///
  /// Eşyanın öldürme maliyetinin [TasarimGirdileri.parcalamaOrani] kadarı.
  /// Tamamı verilseydi eşya farmı malzeme farmının yerine geçerdi.
  /// KARAR 14.5 s1
  static double get parcalamaVerimi =>
      esyaMaliyeti * TasarimGirdileri.parcalamaOrani;

  /// BİR MALZEMENİN kredi karşılığı — bir öldürme.
  ///
  /// Seçilmedi, TÜRETİLDİ, ve türetilen değer akılda kalıcı çıktı:
  /// `1 malzeme ≡ 1 öldürme ≡ o bandın yaratık ödülü`.
  ///
  /// Getirisi: hem yaratık ödülü hem gelir hedefi aynı α'yı izlediği için
  /// malzemenin arz/talep oranı bütün bantlarda AYNI kalıyor. Bir bantta bol
  /// olan malzeme diğerinde kıt olmuyor.
  /// KARAR 14.2 s1
  static double malzemeDegeriFor(int rank) =>
      DusmanTasarimi(rank: rank, sinif: DusmanSinifi.siradan).kredi.toDouble();

  // ══ Arz ve talep ═══════════════════════════════════════════════════

  /// [rank] bandında bir nesilde kaç öldürme yapılıyor.
  static double oldurmeSayisiFor(int rank) =>
      Turetilenler.bantSuresi(rank) * oldurmeHizi;

  /// Bir nesilde düşen eşya sayısı.
  static double esyaSayisiFor(int rank) => oldurmeSayisiFor(rank) * dusmeSansi;

  /// Bir nesilde düşen droid eşyası (14.3).
  static double droidEsyaSayisiFor(int rank) =>
      oldurmeSayisiFor(rank) * droidDusmeSansi;

  /// Filo bolluğu: düşen droid ÷ filonun ihtiyacı.
  static double droidBollugFor(int rank) =>
      droidEsyaSayisiFor(rank) /
      (TasarimGirdileri.droidFiloTavani / TasarimGirdileri.kaliteHedefi);

  /// EŞYA BOLLUĞU — düşen ÷ gereken.
  ///
  /// Bire yakınsa oyuncu yuvalarını ancak dolduruyor; birin altındaysa hiç
  /// dolduramıyor.
  static double esyaBollugFor(int rank) {
    final yuva = HullClass.yuvaSayisi(ReferansBuild.kademeOf(rank));
    return esyaSayisiFor(rank) / (yuva / TasarimGirdileri.kaliteHedefi);
  }

  /// MALZEME ARZI — öldürmelerden gelen + parçalamadan gelen.
  static double malzemeArziFor(int rank) {
    final oldurme = oldurmeSayisiFor(rank);
    final yuva = HullClass.yuvaSayisi(ReferansBuild.kademeOf(rank));
    // Parçalanan fazla iki kalemden: gövde yuvalarını aşan eşya ve filoyu
    // aşan droid (14.3).
    final parcalanan =
        math.max(0.0, esyaSayisiFor(rank) - yuva) +
        math.max(
          0.0,
          droidEsyaSayisiFor(rank) - TasarimGirdileri.droidFiloTavani,
        );
    return oldurme * malzemeFor(DusmanSinifi.siradan) +
        parcalanan * parcalamaVerimi;
  }

  /// MALZEME TALEBİ — artı basma ve sentez bütçesinin malzeme karşılığı.
  ///
  /// Malzeme bu iki kalemin ikinci koşulu: kredi yakıt, malzeme kapı. Mağaza
  /// ve onarım malzeme istemiyor, birikim zaten harcanmıyor.
  static double malzemeTalebiFor(int rank) {
    final butce =
        KaynakAkisi.neselButcesi(rank) *
        (KaynakAkisi.payFor(GiderKalemi.artiBasma) +
            KaynakAkisi.payFor(GiderKalemi.sentez));
    return butce / malzemeDegeriFor(rank);
  }

  /// Arz ÷ talep. Bire yakınsa artı basmak ganimetle tıkanıyor.
  static double malzemeOraniFor(int rank) =>
      malzemeArziFor(rank) / malzemeTalebiFor(rank);

  // ══ Rank çekilişi ══════════════════════════════════════════════════

  /// Bandın kendi rankında çıkma olasılığı — kalan pay.
  static double get bantRankSansi =>
      1 - TasarimGirdileri.altRankSansi - TasarimGirdileri.ustRankSansi;

  /// KARAR 14.4 s1
  static double sansFor(GanimetRanki rank) => switch (rank) {
    GanimetRanki.alt => TasarimGirdileri.altRankSansi,
    GanimetRanki.bant => bantRankSansi,
    GanimetRanki.ust => TasarimGirdileri.ustRankSansi,
  };

  /// ÜST RANK PRD SABİTİ — hedef olasılıktan sayısal çözüm.
  ///
  /// İlan edilen olasılık sabitin kendisi DEĞİL: `C` ile ortalama
  /// [TasarimGirdileri.ustRankSansi] çıkıyor — ilk denemeler daha düşük,
  /// sonrakiler daha yüksek, ve `⌈1 ÷ C⌉` denemede kesin.
  /// KARAR 14.4 s1
  static final double ustRankPrdSabiti = Prd.constantFor(
    TasarimGirdileri.ustRankSansi,
  );

  /// Kaçıncı düşmede üst rank GARANTİ.
  static int get prdGarantisi => (1 / ustRankPrdSabiti).ceil();

  /// PRD garantisinin kaç SAAT sürdüğü.
  ///
  /// Seri kırıcı, kırdığı seriden hızlı olmak zorunda: garanti eşiği nesil
  /// süresinden uzunsa PRD hiç devreye girmez ve sistem bağımsız zardan
  /// farksız kalır.
  static double get prdGarantisiSaat => prdGarantisi * dusmeAraligiDk / 60;

  /// [deneme]'nci denemede üst rank olasılığı.
  static double ustRankOlasiligi(int deneme) =>
      math.min(1.0, ustRankPrdSabiti * deneme);

  // ══ Boss ═══════════════════════════════════════════════════════════

  /// Boss'un üst rank olasılığı — PRD YOK.
  ///
  /// Boss zaten iki saatte bir doğuyor ve grup gerektiriyor, yani kendisi bir
  /// seri kırıcı. Üstüne PRD koymak nadirliğin iki kez telafi edilmesi
  /// olurdu.
  /// KARAR 14.6 s1
  static const double bossUstRankSansi = 0.50;

  /// Boss ganimetinin kalite alt sınırı.
  ///
  /// Boss'u sayı olarak değil GÜVENİLİRLİK olarak ayıran şey: dar bant, baştan
  /// yüksek kalite. Alan 06'nın üst ranklara uyguladığı aynı fikir.
  static const double bossKaliteAltSiniri = 0.85;
}
