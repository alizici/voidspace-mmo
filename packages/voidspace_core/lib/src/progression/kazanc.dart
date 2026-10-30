import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import 'budget.dart';
import 'ganimet.dart';
import 'hull.dart';
import 'item.dart';
import 'ganimet_cekilisi.dart';
import 'kaynak_akisi.dart';
import 'yukseltme.dart';
import 'referans_build.dart';

/// NOVA ile satın alınabilen şey.
///
/// Üçünün de ortak yanı: hiçbiri GÜÇ değil. Eşya, malzeme, rank, artı, gövde
/// ve harita erişimi satılamaz — on dört alan boyunca tek tek elendiler.
/// Geriye zaman ve alan kaldı: NOVA'nın satabileceği tek şey **beklememek**.
enum NovaKalemi {
  /// Anında onarım — 5 dakikalık ölüm maliyetini atlıyor.
  onarim,

  /// Ekstra çevirme — çevirici bedelini atlıyor.
  ///
  /// Paranın dokunabildiği tek kanal bu, çünkü çevirme kalite rolünü
  /// etkiliyor. Fiyatı sabit değil: rankın çevirici bedelinden ve kilit
  /// sayısından türüyor ([Kazanc.cevirmeNovaFor]).
  cevirme,

  /// Envanter genişletme — kalıcı, beş kademe. Zaman değil ALAN.
  envanter,

  /// DROİD ONARIMI — aşınmış droidin dayanıklılığını geri veriyor (05.10).
  ///
  /// Satılan şey yine bekleme: onarılmayan droid sıfırda yok oluyor ve
  /// yerine yenisi ganimetten geliyor. NOVA o düşmeyi beklemeyi ve basılmış
  /// artıları yeniden basmayı atlatıyor; droidin kendisini satmıyor.
  /// Fiyatı sabit değil, droidin rankından ve artı seviyesinden türüyor
  /// ([Kazanc.droidOnarimNovaFor]).
  droidOnarimi,
}

/// NOVA ile satılan GÖRÜNÜŞ kalemi (15.9).
///
/// İkisinin ortak yanı: hiçbiri güç değil. Tasarım droidin çizimini,
/// formasyon filonun dizilişini değiştiriyor; ikisi de savaş puanına
/// dokunmuyor. Bu yüzden 15.1'in yasak listesinde yoklar.
enum GorunusKalemi {
  /// Droid tasarımı — on çizimden biri (05.8 s2).
  tasarim,

  /// Formasyon — yirmi geometriden biri (05.9).
  formasyon,
}

/// KAZANÇ — iki mağaza, bir yasak, ve paranın tavanı.
///
/// Bu alanın başlangıç sorusu tasarımın ilk gününden beri açıktı: mağazada ne
/// satacağız? Cevabı ancak en sonda verilebiliyor, çünkü on dört alan boyunca
/// ne **satılamayacağı** tek tek belirlendi.
///
/// **NOVA'nın hiçbir fiyatı tahmin edilmiyor.** Her biri "bu kaç dakika
/// kazandırıyor" sorusunun cevabı, ve o dakika saatlik NOVA kuruyla
/// çarpılıyor.
abstract final class Kazanc {
  // ══ Kur ════════════════════════════════════════════════════════════

  /// Saatte kazanılan NOVA — alan 12'nin musluğu.
  static double get saatlikNova =>
      TasarimGirdileri.novaOdulu * Ganimet.oldurmeHizi;

  /// Bir NOVA kaç SANİYE oyun eder.
  static double get novaSaniyesi => 3600 / saatlikNova;

  /// [dakika] kazandıran bir kalemin NOVA fiyatı.
  /// KARAR 15.3 s3
  static double fiyatFor(double dakika) => dakika / 60 * saatlikNova;

  /// Bir NOVA kaleminin fiyatı.
  ///
  /// Onarım TÜRETİLİYOR (alan 11'in ölüm maliyeti); çevirme ve envanter
  /// girdi, çünkü kazandırdıkları zaman tek bir sayıyla ifade edilemiyor —
  /// biri katlanan bir eğriyi atlıyor, öteki kalıcı bir alan açıyor.
  /// KARAR 15.3 s3
  static int fiyatiFor(NovaKalemi kalem, {ItemTier tier = ItemTier.cI}) =>
      switch (kalem) {
        NovaKalemi.onarim => fiyatFor(TasarimGirdileri.olumMaliyetiDk).round(),
        NovaKalemi.cevirme => cevirmeNovaFor(tier),
        NovaKalemi.envanter => TasarimGirdileri.envanterNova,
        NovaKalemi.droidOnarimi => droidOnarimNovaFor(tier),
      };

  /// Bir ÇEVİRİCİNİN kaç dakika oyun ettiği.
  ///
  /// Çevirici yalnız parçalamadan geliyor (07.8) ve her parçalama
  /// [GanimetCekilisi.parcalamaCeviriciKazanci] veriyor; bir eşya düşmesi
  /// ortalama [Ganimet.dusmeAraligiDk] dakika. Yani bir çevirici bir eşyanın
  /// düşme süresi kadar zaman.
  static double get ceviriciDakikasi =>
      Ganimet.dusmeAraligiDk / GanimetCekilisi.parcalamaCeviriciKazanci;

  /// NOVA ile bir ÇEVİRME — 15.3 kuralı: fiyat, kazandırdığı zaman.
  ///
  /// Çevirmenin çevirici bedeli rankla ve kilitle büyüyor (karar 07.5);
  /// fiyat da onunla. Sabit 150 iken bedelden kopuktu: Pembe'de bir çevirme
  /// kırk iki çevirici, yani yüzlerce dakika farm ederken NOVA fiyatı C-I ile
  /// aynıydı.
  /// KARAR 15.3 s3
  static int cevirmeNovaFor(ItemTier tier, {int kilit = 0}) => fiyatFor(
    Yukseltme.cevirmeBedeli(
          tier,
          ItemBudget.altStatSayisi(tier),
          kilit: kilit,
        ) *
        ceviriciDakikasi,
  ).round();

  /// Bir droidin YERİNE KONMASI kaç dakika sürüyor — onarımın zaman değeri.
  ///
  /// İki kalem: droidin kendisi ve üstündeki artılar. Droid ganimetten
  /// geliyor, krediyle değil — bu yüzden bedeli kredi fiyatı değil
  /// [Ganimet.droidDusmeAraligiDk], yani filo kaleminin bekleme süresi.
  /// Artılar krediyle basılıyor ve yenisinde sıfırdan basılacak; onların
  /// süresi rankın saatlik gelirinin artı payından.
  ///
  /// Rank hangisi: eşyanın kendi rankı değil SATILDIĞI bant (15.2, taban
  /// eşya bir alt rankta). Oyuncu o bandın gelirini kazanırken o droidi
  /// taşıyor.
  /// KARAR 15.3 s3
  static double droidOnarimDakikasi(ItemTier tier, {int level = 0}) {
    final band = (tier.index - TasarimGirdileri.tabanEsyaRankFarki).clamp(
      0,
      Turetilenler.rankSayisi - 1,
    );
    final saatlik =
        KaynakAkisi.saatlikGelirFor(band) *
        KaynakAkisi.payFor(GiderKalemi.artiBasma);
    final artiDakika = ItemLevels.totalCost(level, tier) / saatlik * 60;
    return Ganimet.droidDusmeAraligiDk + artiDakika;
  }

  /// [puan] kadar dayanıklılığı geri vermenin NOVA fiyatı.
  ///
  /// Doğrusal: tam sayaç yerine konma süresinin tamamı, yarısı yarısı. Eğri
  /// olsaydı ya son puanlar bedavaya gelirdi (onarımı ertelemek doğru hamle)
  /// ya da ilk puanlar (parça parça onarmak doğru hamle); ikisi de oyuncuyu
  /// sayaca bakıp aritmetik yapmaya zorlar.
  /// KARAR 15.3 s3
  static int droidOnarimNovaFor(
    ItemTier tier, {
    int level = 0,
    int puan = 100,
  }) => fiyatFor(droidOnarimDakikasi(tier, level: level) * puan / 100).round();

  /// Bir kalemin kaç DAKİKA kazandırdığı — fiyatın tersi.
  ///
  /// Her fiyatın zaman değeriyle bağının kopmadığını ölçmenin yolu bu:
  /// fiyatı geri çevirince makul bir süre çıkmalı.
  static double kazandirdigiDakika(
    NovaKalemi kalem, {
    ItemTier tier = ItemTier.cI,
  }) => fiyatiFor(kalem, tier: tier) / saatlikNova * 60;

  // ══ Ömür boyu gider ════════════════════════════════════════════════

  /// Bir oyuncunun ömrü boyunca NOVA'ya harcayacağı toplam.
  ///
  /// Kazanılanın %70–95'i olmak zorunda: altındaysa NOVA değersizleşiyor,
  /// üstündeyse ödeme ZORUNLU oluyor. Hedef aralığın içinde, oyuncu istediği
  /// her şeyi alabiliyor ama TAM DA alabiliyor — seçim yapmak zorunda.
  static double get omurBoyuNovaGideri =>
      giderFor(rankSayisi: Turetilenler.rankSayisi);

  /// Ömür boyu NOVA gideri, [rankSayisi] uzunluğunda bir merdiven için.
  ///
  /// Parametreli, çünkü giderin çoğu MERDİVEN UZUNLUĞUNA bağlı (her nesilde
  /// her yuvanın alt statları) ama musluk yalnız SÜREYE bağlı (NOVA
  /// ölçeklenmiyor). İkisi ayrı ölçekte olduğu için oran merdivenle değişiyor
  /// ve testin hedef merdivende ölçülmesi gerekiyor.
  ///
  /// Çevirme modeli: **her alt stat için bir çevirme.** Oyuncu bir eşyayı
  /// kabul etmeden önce her alt statına bir şans daha veriyor; alt stat sayısı
  /// rankla artıyor ([ItemBudget.altStatSayisi]), yani üst ranklarda daha çok
  /// çevirme. Ana NOVA gideri bu ve bilinçli: çevirme kalite rolünü
  /// etkiliyor — paranın dokunabildiği tek kanal.
  static double giderFor({required int rankSayisi}) {
    var cevirmeNova = 0.0;
    var droidOnarimNova = 0.0;
    for (var r = 0; r < rankSayisi; r++) {
      final tier =
          ItemTier.values[(r * ItemTier.values.length ~/ rankSayisi).clamp(
            0,
            ItemTier.values.length - 1,
          )];
      // Çevirme modeli: her nesilde her yuva için BİR tam çevirme, kilitsiz.
      // Çevirme bütün alt statları birden çevirdiği için (07.5) "her alt stat
      // için bir çevirme" ile aynı şey; fiyatı rankın bedelinden.
      cevirmeNova +=
          HullYuva.sayisiFor(
            (r * Turetilenler.rankSayisi ~/ rankSayisi).clamp(
              0,
              Turetilenler.rankSayisi - 1,
            ),
          ) *
          cevirmeNovaFor(tier);
      // Droid onarımı modeli: **her nesilde filonun bir tam sayacı.** Bir
      // bantta ölçülen ölüm sayısı bunun birkaç katı; aradaki fark onarmadan
      // bırakılan droidler, yani ganimetten gelen yenisi. Onarım da çevirme
      // gibi lüks (15.3): hiç onarmayan oyuncu filosunu ganimetle döndürür,
      // yalnız artılarını kaybeder.
      droidOnarimNova += TasarimGirdileri.droidFiloTavani *
          droidOnarimNovaFor(tier);
    }
    return zorunluGiderFor(rankSayisi: rankSayisi) +
        cevirmeNova +
        droidOnarimNova;
  }

  /// ZORUNLU NOVA gideri — onarım ve envanter; çevirme hariç.
  ///
  /// Karar 15.3: çevirme LÜKS. Çevirici zaten parçalamadan geliyor, NOVA
  /// çevirmesi bir ihtiyaç değil bir kestirme; fiyatı bedelden türediği için
  /// üst ranklarda musluğu aşıyor ve aşması sorun değil. "Ödeme zorunlu
  /// olmasın" değişmezi bu yüzden yalnız zorunlu kalemlere bakıyor.
  static double zorunluGiderFor({required int rankSayisi}) {
    final olum = TasarimGirdileri.genelOlumSikligi * TasarimGirdileri.hedefSure;
    return olum * fiyatiFor(NovaKalemi.onarim) +
        TasarimGirdileri.envanterKademe * fiyatiFor(NovaKalemi.envanter);
  }

  /// Zorunlu gider ÷ musluk — bunun birin altında kalması şart.
  static double get zorunluGiderOrani =>
      zorunluGiderFor(rankSayisi: Turetilenler.rankSayisi) /
      KaynakAkisi.omurBoyuNova;

  /// [rankSayisi] uzunluğunda bir merdivende gider ÷ musluk.
  static double giderOraniFor({required int rankSayisi}) =>
      giderFor(rankSayisi: rankSayisi) / KaynakAkisi.omurBoyuNova;

  /// Gider ÷ musluk.
  static double get novaGiderOrani =>
      omurBoyuNovaGideri / KaynakAkisi.omurBoyuNova;

  // ══ Paranın tavanı ═════════════════════════════════════════════════

  /// PARANIN TAVANI — sınırsız ödeyenin, hiç ödemeyene karşı avantajı.
  ///
  /// Bu sayı **15'in kararı değil**: paranın dokunabildiği tek kanal kalite
  /// rolü, ve o kanalın genişliğini alan 06'nın kalite bandı belirliyor.
  /// 15 onu yalnız ÖLÇÜYOR ve ilan ediyor — ve ilan etmek onu bir teste
  /// dönüştürüyor. Tavan yükselirse bir yerde bir kısıt gevşemiş demektir.
  ///
  /// Kalite yalnız ALT statlara uygulanıyor; ana stat
  /// ([TasarimGirdileri.anaStatPayi]) rolden bağımsız. Yani en kötü eşya bile
  /// bütçesinin çoğunu alıyor ve makas dar kalıyor.
  ///
  /// Bir kazanç alanının kendi tavanını kendisi belirlemesi, tavanın olmaması
  /// demektir.
  /// KARAR 15.4 s1
  static double tavanFor(double kaliteAltSiniri) {
    final enKotu =
        TasarimGirdileri.anaStatPayi +
        (1 - TasarimGirdileri.anaStatPayi) * kaliteAltSiniri;
    return 1 / enKotu - 1;
  }

  /// Bugünkü kalite bandındaki tavan.
  static double get tavan => tavanFor(TasarimGirdileri.kaliteAltSiniri);

  /// Bir rankın tavanı — bandı daraldıkça tavan daralır (karar 06.10).
  static double tavanForTier(ItemTier tier) =>
      tavanFor(ItemBudget.kaliteAltSiniriFor(tier));

  /// Karşılaştırma: bir RANK atlamasının kazandırdığı.
  static double get rankAdimi => TasarimGirdileri.rankArtisi - 1;

  /// Karşılaştırma: bir ARTI seviyesinin kazandırdığı — `(en az, en çok)`.
  ///
  /// Tavanın ölçüldüğü birim bu. Paranın tümü, zamanla kazanılan TEK BİR
  /// adımın büyüklüğünde kalmak zorunda: altındaysa mağaza anlamsız,
  /// üstündeyse merdiven paraya açılmış olur.
  static (double, double) get artiAdimAraligi {
    var enKucuk = double.infinity;
    var enBuyuk = 0.0;
    for (var l = 1; l <= ItemLevels.max; l++) {
      final adim = ItemLevels.stepFor(l);
      if (adim < enKucuk) enKucuk = adim;
      if (adim > enBuyuk) enBuyuk = adim;
    }
    return (enKucuk, enBuyuk);
  }

  // ══ Paketler ═══════════════════════════════════════════════════════

  /// [dolar] karşılığı NOVA — [bonus] büyük paketin indirimi.
  /// KARAR 15.5 s1
  static int paketNova(double dolar, double bonus) =>
      (dolar * TasarimGirdileri.dolarSaatDegeri * saatlikNova * bonus).round();

  /// Ödeyen oyuncunun bir alışverişte aldığı NOVA'nın, ömür boyu musluğa oranı.
  /// KARAR 15.6 s1
  static double get odeyeninPayi =>
      paketNova(
        TasarimGirdileri.hedefARPPU,
        TasarimGirdileri.paketBonusTavani,
      ) /
      KaynakAkisi.omurBoyuNova;

  /// Oyuncu başına ortalama gelir.
  /// KARAR 15.6 s1
  static double get arpu =>
      TasarimGirdileri.odemeOrani * TasarimGirdileri.hedefARPPU;

  // ══ Kredi mağazası ═════════════════════════════════════════════════

  /// [rank] bandındaki TABAN eşyanın kredi fiyatı.
  ///
  /// Alan 13'ün mağaza payı, nesil başına
  /// [TasarimGirdileri.magazaEsyaSayisi] eşyaya bölünüyor. Seçilmiş bir fiyat
  /// değil, ilan edilmiş bir payın bölünmesi.
  /// KARAR 15.2 s1
  static double tabanEsyaFiyatiFor(int rank) =>
      KaynakAkisi.neselButcesi(rank) *
      KaynakAkisi.payFor(GiderKalemi.magaza) /
      TasarimGirdileri.magazaEsyaSayisi;

  /// YENİ HESABIN başlangıç kredisi — raftan türüyor, elle yazılmıyor.
  ///
  /// Uzun süre `Hangar`da elle yazılmış 30.000 durdu ve gerekçesi "bir C
  /// tier lazer alacak kadar"dı; raf 15.2'nin fiyat modeline geçince o cümle
  /// yalan oldu, çünkü ilk bandın taban eşyası 94.522 kredi ve yeni oyuncu
  /// ilk saatinde raftan hiçbir şey alamıyordu (borç defteri B21).
  ///
  /// Artık sayı değil ORAN ilan ediliyor: ilk bandın raf fiyatı ×
  /// [TasarimGirdileri.baslangicEsyaSayisi]. Raf fiyatı 13'ün mağaza
  /// payından türediği için başlangıç kredisi de nesil bütçesiyle birlikte
  /// kayıyor; elle güncellenecek bir sayı kalmıyor.
  /// Yuvarlama EŞYA BAŞINA, toplamda değil: rafın kasası her eşyada ayrı
  /// yuvarlıyor (`Catalogue.rafFiyati`), yani toplamı yuvarlamak oyuncuyu bir
  /// krediyle ikinci eşyanın dışında bırakabilirdi. İlan edilen cümle "tam
  /// bu kadar eşya" ve tam olması bir kuruşa bakıyor.
  /// KARAR 15.8 s1
  static int get baslangicKredisi =>
      tabanEsyaFiyatiFor(0).round() * TasarimGirdileri.baslangicEsyaSayisi;

  /// GÖRÜNÜŞ fiyatları — tasarım ve formasyon, NOVA (15.9).
  ///
  /// 15.3'ün kuralının dışında duran tek raf: görünüş hiçbir bekleme
  /// kısaltmıyor, yani "kazandırdığı dakika" sıfır ve fiyatı türetilemez.
  /// Bu onu satılamaz yapmıyor, tersine: güç satmadığı için 15.1'in yasak
  /// listesine hiç girmiyor. İlan edilen iki sayı, ikisi de tepe tabloda.
  /// KARAR 15.9 s1
  static int gorunusFiyati(GorunusKalemi kalem) => switch (kalem) {
    GorunusKalemi.tasarim => TasarimGirdileri.tasarimNova,
    GorunusKalemi.formasyon => TasarimGirdileri.formasyonNova,
  };

  /// [rank] bandında satılan taban eşyanın RANKI — bir alt.
  ///
  /// Bandın rankı değil altındaki: mağaza eşyası en kötü drop'tan bile zayıf
  /// olmak zorunda, yoksa ganimet döngüsüyle rekabet etmeye başlar.
  ///
  /// İlk bantta bir alt rank yok; orada eşya bandın kendi rankında ama kalite
  /// ve alt stat yoksunluğu onu yine ikinci sınıf tutuyor.
  /// KARAR 15.2 s1
  static int tabanEsyaRankiFor(int rank) =>
      (rank + TasarimGirdileri.tabanEsyaRankFarki).clamp(
        0,
        Turetilenler.rankSayisi - 1,
      );

  // ══ Yasak listesi ══════════════════════════════════════════════════

  /// NOVA mağazası [kaynak]'ı satabiliyor mu — **hiçbirini satamıyor.**
  ///
  /// Fonksiyon olması bilinçli, [KaynakAkisi.cevrilebilir] ile aynı sebeple:
  /// bir istisna açılmak istenirse buraya yazılması ve testi kırması
  /// gerekiyor.
  /// KARAR 15.1 s3
  static bool satilabilir(Kaynak kaynak) => switch (kaynak) {
    Kaynak.malzeme => TasarimGirdileri.novaMalzemeSatiyor,
    // Kredi 13'ün dönüşüm kilidiyle zaten kapalı.
    Kaynak.kredi => TasarimGirdileri.paraCevirmeAcik,
    Kaynak.nova => false,
  };

  /// NOVA mağazası GANİMET DÖNGÜSÜNÜN eşyasını satabiliyor mu — hayır.
  ///
  /// Kilit alt statlı, bandın rankındaki, 14'ün arz hesabına giren eşyayı
  /// koruyor. NOVA rafının üç taban tasarımı (15.7) bunun dışında: alt statı
  /// yok, merdivenin dibinde ve raf büyümüyor.
  /// KARAR 15.1 s3 · KARAR 15.7 s1
  static bool get esyaSatilabilir => TasarimGirdileri.novaEsyaSatiyor;

  /// Taban eşyanın kalite rolü — SABİT, bandın en altı. Sürpriz yok.
  static double get tabanEsyaKalitesi => TasarimGirdileri.kaliteAltSiniri;

  /// Taban eşyanın alt stat sayısı — sıfır. Derinlik satılmıyor.
  static const int tabanEsyaAltStatSayisi = 0;
}

/// Yuva sayısını ranka göre veren küçük yardımcı.
///
/// [ReferansBuild.kademeOf] ile [HullClass.yuvaSayisi] zincirini tek yerde
/// tutuyor; iki çağrının ayrı ayrı yazılması kademe eşlemesini ikinci kez
/// tanımlamak olurdu.
abstract final class HullYuva {
  static int sayisiFor(int rank) =>
      HullClass.yuvaSayisi(ReferansBuild.kademeOf(rank));
}
