import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import '../domain/ship_stats.dart';
import '../progression/referans_cozumu.dart';

/// Yaratık SINIFI — alan 12.
///
/// Üç sınıf, üç rol. Hepsi ORAN cinsinden tanımlı, sayı cinsinden değil:
/// canı bir süre, hızı ve menzili oyuncununkine bir kesir. Bu yüzden sınıf
/// bantla değişmiyor — bir sıradan yaratık yirminci bantta da bir saniyede
/// ölüyor, yalnız o bir saniyedeki sayılar 2.277 kat büyük.
///
/// Savaşın temposu yirmi bant boyunca sabit; değişen tek şey büyüklük.
/// KARAR 12.1 s1
enum DusmanSinifi {
  /// Gelirin taşıyıcısı. Görmezden gelinebilir; riski OYUNCU başlatır.
  siradan,

  /// Bir karar. Kendisi başlatır ama kaçamaz — girmek de çıkmak da oyuncunun
  /// elinde. Tehlikeli yapan hasarı değil, kaçamayacağın kadar uzun sürmesi.
  guclu,

  /// Grup hedefi. Zamanlı doğar, bandın ganimet tavanıdır.
  boss;

  /// Referans build'in kaç saniyede indireceği.
  ///
  /// Boss'unki türetiliyor: bir grubun toplam süresi, `grup × hedefSüre`.
  double get oldurmeSuresi => switch (this) {
    siradan => TasarimGirdileri.siradanOldurmeSuresi,
    guclu => TasarimGirdileri.gucluOldurmeSuresi,
    boss => TasarimGirdileri.bossGrubu * TasarimGirdileri.bossHedefSuresi,
  };

  /// Oyuncunun hızına oran. Kovalayabilir ama yetişemez.
  double get hizOrani => switch (this) {
    siradan => TasarimGirdileri.siradanHizOrani,
    guclu => TasarimGirdileri.gucluHizOrani,
    boss => TasarimGirdileri.bossHizOrani,
  };

  /// Oyuncunun menziline oran — hiçbiri 1'e ulaşamaz.
  double get menzilOrani => switch (this) {
    siradan => TasarimGirdileri.siradanMenzilOrani,
    guclu => TasarimGirdileri.gucluMenzilOrani,
    boss => TasarimGirdileri.bossMenzilOrani,
  };

  /// Kendiliğinden saldırıyor mu.
  ///
  /// Sıradan yaratıkta hayır, ve bu oyuncuya haritayı GEÇME hakkı veriyor:
  /// farm etmek zorunda değil, geçebilir de.
  bool get saldirgan => this != siradan;

  /// Ödül primi. Sıradanda yok — riski oyuncu seçiyor.
  double get prim => switch (this) {
    siradan => 1.0,
    guclu => TasarimGirdileri.gucluRiskPrimi,
    boss => TasarimGirdileri.bossPrimi,
  };
}

/// Bir BANTTAKİ bir sınıfın sayıları — hiçbiri elle konmadan.
///
/// Üç denklem:
/// * **can** bir SÜRE — `sınıfSüresi × referansDPS(bant)`
/// * **hasar** bir PENCERE — `havuz ÷ (tehdit × kaçışPenceresi)`
/// * **ödül** bir HIZ — `saatlikHedef × çevrim ÷ 3600`
///
/// Üçü de zaten ilan edilmiş hedeflerden çıkıyor: 11'in saatlik kredi hedefi,
/// 01'in referans DPS'i, 04'ün havuzu. Yaratık tasarımı bir sayı uydurma işi
/// değil, üç denklemi çözme işi.
class DusmanTasarimi {
  const DusmanTasarimi({required this.rank, required this.sinif});

  /// KÜRESEL bant numarası — bölgenin değil, merdivenin.
  final int rank;

  final DusmanSinifi sinif;

  /// Bandın güç çarpanı.
  double get _merdiven =>
      TuretilenTablolar.rankCarpaniFor(rank, TasarimGirdileri.rankArtisi);

  /// Bandın referans build'inin saniyelik hasarı.
  ///
  /// Alan 09'un saldırı kanalıyla AYNI tanım — `CombatGlossary.expectedDps`.
  /// İkinci bir "referans DPS" tanımı, savaş puanı ile yaratık canının
  /// sessizce ayrışması demek olurdu.
  double get referansDps =>
      CombatGlossary.saldiriDps(ReferansCozumu.stats) * _merdiven;

  /// Bandın referans oyuncusunun HAM havuzu — gövde + kalkan.
  double get oyuncuHavuzu =>
      (ReferansCozumu.stats.maxHull + ReferansCozumu.stats.maxShield) *
      _merdiven;

  /// Bandın saatlik kredi hedefi — alan 11'in α eğrisi.
  /// KARAR 12.3 s1
  double get saatlikHedef => TuretilenTablolar.gelirFor(
    rank,
    taban: TasarimGirdileri.tabanSaatlikGelir,
    artis: TasarimGirdileri.rankArtisi,
    us: TasarimGirdileri.gelirUssu,
  );

  /// CAN — bir süre.
  /// KARAR 12.2 s2
  double get can => sinif.oldurmeSuresi * referansDps;

  /// Yaratığın saniyelik hasarı — kaçış penceresinden.
  ///
  /// Sınıfla DEĞİŞMİYOR, bantla değişiyor: boss ve güçlü yaratıkta pencere
  /// daralmıyor. Güçlü yaratığı tehlikeli yapan hasarı değil, süresi.
  /// KARAR 12.4 s1
  double get hasarDps => TuretilenTablolar.yaratikDpsFor(
    havuz: oyuncuHavuzu,
    tehdit: TasarimGirdileri.tehditSayisi,
    pencere: TasarimGirdileri.kacisPenceresi,
  );

  /// [atisAraligi] saniyede bir ateş eden bir yaratığın ATIŞ BAŞINA hasarı.
  ///
  /// Atış aralığı bir SANAT/kimlik özelliği (yaratığın ritmi), denge değil:
  /// denge [hasarDps]'te duruyor ve aralık ne olursa olsun korunuyor.
  double atisHasariFor(double atisAraligi) => hasarDps * atisAraligi;

  /// Hız ve menzil ÇIPLAK gövdeye oranlı (12): donanımın hız ve menzil
  /// eklentileri yaratığı hızlandırmaz; can ve hasar dolu referanstan (04.5).
  double get hiz => ShipStats.bastion.speed * sinif.hizOrani;

  double get menzil => ShipStats.bastion.laser.range * sinif.menzilOrani;

  /// Yeniden doğma süresi, saniye.
  ///
  /// Boss'unki TÜRETİLİYOR — bandın gelirinin [TasarimGirdileri.bossGelirPayi]
  /// kadarını taşısın diye çözülen aralık. Her bantta aynı çıkıyor.
  double get dogusSuresi => switch (sinif) {
    DusmanSinifi.siradan => TasarimGirdileri.siradanDogusSuresi,
    DusmanSinifi.guclu => TasarimGirdileri.gucluDogusSuresi,
    DusmanSinifi.boss => bossAraligiSaat * 3600,
  };

  /// Oyuncunun saatinden aldığı süre — ödülün payı.
  ///
  /// Sıradan ve güçlü için ÇEVRİM: yeniden doğmayı saymak şart, çünkü oyuncu
  /// bir sonrakini beklemek zorunda ve bugünkü farm çevriminin çoğu o.
  /// Boss için OYUNCU-SANİYE: maliyeti bir grubun zamanı, ve bekleme süresi
  /// oyuncunun zamanını almıyor — o sırada başka bir şey yapıyor.
  double get harcananSaniye => switch (sinif) {
    DusmanSinifi.boss => sinif.oldurmeSuresi,
    _ => dogusSuresi + sinif.oldurmeSuresi,
  };

  /// İmha edildiğinde düşen kredi.
  /// KARAR 12.3 s1
  int get kredi => TuretilenTablolar.odulFor(
    saatlikHedef: saatlikHedef,
    saniye: harcananSaniye,
    prim: sinif.prim,
  ).round();

  /// İmha edildiğinde düşen NOVA — kademeyle ÖLÇEKLENMEZ.
  ///
  /// Krediden tek farkı bu ve sebebi tek cümle: NOVA gerçek parayla rekabet
  /// ediyor. Kademeyle ölçeklenirse son bölgedeki oyuncu saatte yüzlerce kat
  /// NOVA basar ve satılan NOVA'nın değeri sıfırlanır.
  ///
  /// Sınıfla ölçekleniyor ama yalnız ZAMANLA: saatlik NOVA hızı üç sınıfta da
  /// aynı. Üst bölgedeki oyuncunun avantajı NOVA kazanmakta değil, NOVA'ya
  /// ihtiyacı olmamakta.
  /// KARAR 12.6 s1
  int get nova {
    final siradanCevrim =
        TasarimGirdileri.siradanDogusSuresi +
        TasarimGirdileri.siradanOldurmeSuresi;
    return (TasarimGirdileri.novaOdulu * harcananSaniye / siradanCevrim)
        .round();
  }

  /// Boss'un doğma aralığı, saat. Sınıf boss değilse anlamsız.
  /// KARAR 12.5 s1
  double get bossAraligiSaat => TuretilenTablolar.bossAraligiFor(
    odul: TuretilenTablolar.odulFor(
      saatlikHedef: saatlikHedef,
      saniye: sinif.oldurmeSuresi,
      prim: TasarimGirdileri.bossPrimi,
    ),
    saatlikHedef: saatlikHedef,
    gelirPayi: TasarimGirdileri.bossGelirPayi,
  );

  @override
  String toString() =>
      '${sinif.name} @bant $rank · can ${can.round()} · '
      '${hasarDps.round()} dps · \$kredi kr · \$nova NOVA';
}
