import 'dart:math' as math;

import 'prd.dart';
import 'turetilen_tablolar.dart';
import 'tasarim_girdileri.dart';

/// BAŞKA ALANI BEKLEYEN girdiler.
///
/// Sayı tablosunun "bekliyor" rozeti taşıyan satırları. Bir alan yazılmadan
/// çözülemeyen sabitler burada `null` olarak duruyor — tahmin edilmiş bir
/// değerle DEĞİL.
///
/// Neden `null` ve neden bir tahmin değil: tahmin edilen bir sabit, alan
/// geldiğinde kimsenin geri dönüp düzeltmediği bir sabittir. `null` ise onu
/// okuyan her yeri derleme zamanında dallanmaya zorluyor.
abstract final class BekleyenGirdiler {
  /// Referans build'in ZIRHI — alan 04 · Gemi ve Yuvalar. **ÇÖZÜLDÜ.**
  ///
  /// Uzun süre `null` durdu ve bu bir eksiklik değil mimarinin çalıştığının
  /// kanıtıydı: "referansta %30 azaltma" cümlesi ancak referansın zırhı
  /// biliniyorsa sayıya döner, ve referans build alan 04'ün kararı.
  ///
  /// Alan 04 yazıldığı an [Turetilenler.kZirh] KENDİLİĞİNDEN çözüldü — elle
  /// hiçbir yere sabit yazılmadı.
  static const double referansZirh = TasarimGirdileri.zirhCapasi;

  /// Referans build'in KAÇINMASI — alan 04. **ÇÖZÜLDÜ.**
  static const double referansKacinma = TasarimGirdileri.referansKacinma;

  /// Hangi sabitin hangi alanı beklediği — denetimin okuduğu liste.
  ///
  /// Çözülen bir sabit buradan ÇIKAR: liste "hâlâ bekleyenler", "bir zamanlar
  /// bekleyenler" değil. Bugün BOŞ — bekleyen sabit kalmadı.
  static const Map<String, int> bekleyenler = {};
}

/// TÜRETİLENLER — girdilerden çıkan, elle ASLA yazılmayan sayılar.
///
/// Tepe tablonun ikinci yarısı. Girdi `const` durur ([TasarimGirdileri]),
/// türetilen burada HESAPLANAN alan olarak yaşar: kimse üstlerine yazamaz,
/// çünkü yazılabilecek bir alan yok.
///
/// **Mimarinin tek gerçek ihlali** türetilmiş bir değeri kaynağa sabit olarak
/// yazmak. Diğer bütün hatalar bir sayının yanlış olduğunu söyler; bu, sistemin
/// bozulduğunu söyler — kaynağı değiştirmek artık o değeri değiştirmiyor
/// demektir, ve bu aylar sonra sebebi bulunamayan dengesizliklerin bir numaralı
/// kaynağı.
abstract final class Turetilenler {
  /// Kritiğin BEKLENEN değeri: `1 + k(d − 1)`.
  ///
  /// Zincirin L3 katmanı denge ve BR tarafında bu biçimi kullanır. Çalışma
  /// anında gerçek zar atılır; ikisi aynı katmandan beslendiği için uzun vadede
  /// zarların ortalaması buna yakınsar.
  ///
  /// Referans girdilerle: `1 + 0,25 × 1,00 = 1,250`.
  static double get kritikBeklenenDeger => kritikBeklenenDegerFor(
    TasarimGirdileri.kritikSansiReferans,
    TasarimGirdileri.kritikCarpaniReferans,
  );

  // ══ Gövde çapası — TTK kısıtından ═══════════════════════════════════
  //
  // Aşağıdakiler `const`, getter değil: `ShipStats.bastion` const ve referans
  // build bu sayıyı taşımak zorunda — iki kayıt, tek doğruluk. Formüller
  // [kritikBeklenenDegerFor] ve [TuretilenTablolar.govdeHavuzuFor] ile aynı;
  // test ikisini eşitliyor, sessizce ayrışamazlar.

  /// [kritikBeklenenDeger]'in const hâli: `1 + k(d − 1)`.
  static const double kritikBeklenenDegerSabiti =
      1 +
      TasarimGirdileri.kritikSansiReferans *
          (TasarimGirdileri.kritikCarpaniReferans - 1);

  /// Referans build'in saldırısı — beş namlunun kritik dâhil DPS'i.
  ///
  /// `CombatGlossary.expectedDps(ShipStats.bastion)` ile aynı sayı; oradan
  /// OKUNAMAZ, çünkü `ship_stats.dart` bu dosyayı okuyor.
  /// KARAR 04.5 s2
  /// Referans lazerin NAMLU hasarı — katalogdaki C-I lazerin ana statı.
  ///
  /// Uzun süre ayrı bir girdiydi (200) ve katalogdaki C-I lazer 140 veriyordu:
  /// referansın silahı katalogda yoktu (borç defteri B1). Artık bütçeden
  /// türüyor: bütçe çapası × ana stat payı, lazer yuva katsayısı bir ve taban
  /// hasarın fiyatı bir (08.1, 03.6). `ItemBudget.mainStatValue(pl1)` ile
  /// aynı sayı; test ikisini bağlıyor.
  /// KARAR 04.5 s2
  static const double referansLazerHasari =
      TasarimGirdileri.butceCapasi * TasarimGirdileri.anaStatPayi;

  static const double referansDps =
      TasarimGirdileri.lazerYuvaSayisi *
      referansLazerHasari /
      TasarimGirdileri.referansAtisAraligi *
      kritikBeklenenDegerSabiti;

  /// Referans savunmasının kayıp çarpanı: `(1 − azaltma)(1 − sıyırma)`.
  static const double referansKayipCarpani =
      (1 - TasarimGirdileri.zirhAzaltmaHedefi) *
      (1 - TasarimGirdileri.siyirmaHedefiReferans);

  /// Referans build'in EŞYALARDAN aldığı havuz — bugün SIFIR.
  ///
  /// Referans build çıplak gövde + beş lazer (`ShipStats.bastion`); kalkan
  /// jeneratörlerinin katkısı referansa girmiyor. Referans tam donanımı
  /// taşıdığında (04.5) bu terim dolar ve 08.6'nın gövde ↔ eşya kolu doğar:
  /// eşyaların havuza kattığı her puan gövdeden bir puan düşürür.
  static const double referansEsyaHavuzu = 0;

  /// GÖVDE ÇAPASI — kademe 1 gövde canı, TTK kısıtından ÇÖZÜLMÜŞ.
  ///
  /// `A × T × kayıp − kalkan − eşya havuzu`: referansın saldırısı ve hedef
  /// TTK gereken etkin canı veriyor; savunma kanalları onu büyüttüğü için
  /// gereken HAM havuz kayıpla çarpılıyor; kalkan çapası ve eşyaların kattığı
  /// düşülünce geriye gövdenin taban havuzu kalıyor. Saldırı büyüdükçe
  /// (roketatar, droid, ArGe) çapa kendiliğinden büyür ve TTK yerinde kalır.
  ///
  /// Uzun süre girdiydi (12.000) ve referans TTK 29,6 çıkıyordu; çözülünce
  /// sapma sıfırlandı. Alan 04'ün merdiveni geçerli: kademeler arası oran
  /// oradan, çapanın nereden geldiği buradan.
  /// KARAR 08.5 s2
  static const double govdeCapasi =
      referansDps * TasarimGirdileri.referansTTK * referansKayipCarpani -
      TasarimGirdileri.kalkanCapasi -
      referansEsyaHavuzu;

  // ══ Droid — türetilen taban ═════════════════════════════════════════
  //
  // Droid taban hasarı ve havuzu ELLE konmuyor (05.5): referans gövdenin
  // TAM filo kadar çıplak droid, referans yaylımın droidDpsPayi kadarını
  // veriyor. Rank ve artı çarpanı eşyadan geliyor, çapa buradan.


  /// FİLO bütçesinin DONANIMA giden payı — ÇÖZÜLÜYOR, ilan edilmiyor.
  ///
  /// Droid bir taşıyıcı oldu (05.4 s5) ve filo payı ikiye bölünüyor: droid
  /// gövdelerinin kendi statlarına, bir de içlerine takılana. Bölüşüm elle
  /// konsaydı tam donanımlı filonun payı 09.6'nın ilan ettiği orandan
  /// kayardı — yarı yarıya bölünce ölçülen pay %27,9 çıkıyordu, ilan %15.
  ///
  /// Çözüm tek satır: donanıma giden pay, tam donanımlı standart filonun
  /// yaylımı geminin lazer yaylımının `droidDpsPayi` katı olacak şekilde.
  /// `droidDpsPayi × payLazer ÷ payDroid`, bugün 0,269.
  /// KARAR 05.4 s5 · KARAR 05.5 s3
  static const double droidDonanimPayi =
      TasarimGirdileri.droidDpsPayi *
      TasarimGirdileri.payLazer /
      TasarimGirdileri.payDroid;

  /// Bir droid KAÇ ÖLÜM dayanıyor — yüzde bölü aşınma payı.
  ///
  /// Sayaç puanla tutuluyor ama oyuncunun okuduğu sayı bu: "on ölümüm var".
  /// Girdi aşınma payı, ömür onun tersi; ikisi ayrı yazılsaydı biri
  /// değiştiğinde öteki sessizce yalan söylerdi.
  /// KARAR 05.10 s1
  /// Yüz, sayacın ölçeği: dayanıklılık YÜZDE tutuluyor ve tam bir droid yüz
  /// puan (`ItemInstance.tamDayaniklilik`). Girdi değil, yüzdenin tanımı —
  /// bu yüzden tepe tabloda yok.
  static const int droidOmruOlum = 100 ~/ TasarimGirdileri.droidAsinmaPayi;

  /// Bir droidin ömrü SAAT olarak — ölçülen ölüm sıklığında.
  ///
  /// Sıklık playtest girdisi (13.3); ömür onunla oynayacak. Onarım fiyatının
  /// pahalı mı ucuz mu olduğu ancak bu sayıyla okunuyor: droid ömründen kısa
  /// sürede yerine konabiliyorsa onarım lüks, uzun sürüyorsa zorunlu gider.
  /// KARAR 05.10 s1
  static double get droidOmruSaat =>
      droidOmruOlum / TasarimGirdileri.genelOlumSikligi;

  /// Herhangi bir (şans, çarpan) çifti için beklenen değer.
  ///
  /// Referans değil GERÇEK build de bu formülü kullanır — tek bir yerde
  /// durmasının sebebi bu.
  static double kritikBeklenenDegerFor(double sans, double carpan) =>
      1 + sans * (carpan - 1);

  /// Kritik PRD sabiti — `1 ÷ E[N] = kritikSansiReferans` olacak şekilde
  /// sayısal çözüm.
  ///
  /// Referans girdiyle `0,084744`; garantili kritik `⌈1 ÷ C⌉ = 12` yaylımda.
  /// `final`, `const` DEĞİL: kapalı formülü yok, çözülüyor.
  static final double kritikPrdSabiti = Prd.constantFor(
    TasarimGirdileri.kritikSansiReferans,
  );

  /// Zırh eğrisinin K ÇARPANI: `K = z · (1/hedef − 1)`.
  ///
  /// `z/(z + K) = zirhAzaltmaHedefi` denkleminin çözümü. Referans hedefle
  /// `2,3333`.
  static double get kZirhCarpani =>
      _kCarpani(TasarimGirdileri.zirhAzaltmaHedefi);

  /// Sıyırma eğrisinin K çarpanı. Referans hedefle `5,6667`.
  static double get kSiyirmaCarpani =>
      _kCarpani(TasarimGirdileri.siyirmaHedefiReferans);

  /// Zırh eğrisinin K SABİTİ — çarpan × referans build'in zırhı.
  ///
  /// **ÇÖZÜLDÜ** — alan 04 yazıldığında [BekleyenGirdiler.referansZirh] doldu
  /// ve bu sabit kendiliğinden hesaplandı: `1.000 × 2,3333 = 2.333,3`.
  ///
  /// Uzun süre `null` durması bir eksiklik değil, bağımlılığın gizlenmemesiydi:
  /// tahmin edilmiş bir sabit, alan geldiğinde kimsenin geri dönüp
  /// düzeltmediği sabittir. `null` ise onu okuyan her yeri derleme zamanında
  /// dallanmaya zorluyordu.
  /// KARAR 04.6 s1
  static double get kZirh => kZirhFor(BekleyenGirdiler.referansZirh);

  /// Sıyırma eğrisinin K sabiti — [kZirh] ile aynı sebeple ÇÖZÜLDÜ.
  static double get kSiyirma => kSiyirmaFor(BekleyenGirdiler.referansKacinma);

  static double kZirhFor(double referansZirh) => referansZirh * kZirhCarpani;

  static double kSiyirmaFor(double referansKacinma) =>
      referansKacinma * kSiyirmaCarpani;

  static double _kCarpani(double hedef) => 1 / hedef - 1;

  /// GÖVDE KADEMESİ ÇARPANLARI — **çözüldü** (alan 08).
  ///
  /// Uzun süre `null` durdu ve sebebi katman yönüydü: kademe çarpanı rank
  /// merdivenine bağlı (alan 06, BÜYÜME katmanı), gövde ise SAVAŞ katmanında.
  /// "Aşağı yalnız yukarıyı okur" kuralı savaşın büyümeden okumasını
  /// yasaklıyor, yani bu merdiven alan 04'te çözülemezdi.
  ///
  /// Alan 08 ("Rank ve artı → bütçe eğrisi", bağımlılığı `[3, 4, 6]`) ikisini
  /// birden gören ilk alan — ve merdiveni bir sayı yazarak değil, kademe
  /// normalizatörünü çağırarak çözüyor.
  ///
  /// Bugün beş kademe: rank merdiveni beş basamaklı ve her gövde kademesi en
  /// az bir rank kapsamak zorunda. Merdiven yirmiye çıktığında bu liste
  /// sekize uzayacak ve BU KOD değişmeyecek.
  // ══ KANALLAR ARASI KUR — alan 09 ═══════════════════════════════════

  /// SAVUNMA ÇAPASI: bir bütçe puanının kaç HAVUZ birimi aldığı.
  ///
  /// Elle konmuş bir fiyat DEĞİL — kurdan çözülüyor, ve kur da ayrı bir girdi
  /// değil hedef TTK'nın kendisi: `1 DPS ≡ referansTTK × EHP`.
  ///
  /// Zincir:
  /// 1. Bir saldırı puanı = bir taban hasar = [saldiriPuaniDps] beklenen DPS.
  /// 2. Kur: o DPS, `referansTTK` katı EHP'ye denk.
  /// 3. Bir savunma puanı EŞİT güç almalı; havuz, azaltma çarpanıyla EHP'ye
  ///    dönüştüğü için puan başına havuz = EHP ÷ çarpan.
  ///
  /// Ölçüldü: elle konmuş 4,0 ile bir savunma puanı bir saldırı puanının
  /// yalnız **%19,7'si** kadar güç alıyordu. Bütçenin tek sözü ise bir puanın
  /// hangi stata konursa konsun aynı marjinal gücü almasıydı.
  /// KARAR 03.3 s1 · KARAR 03.4 s1 · KARAR 08.4 s1 · KARAR 09.2 s1 · KARAR 09.4 s1
  static double get savunmaCapasi =>
      saldiriPuaniDps * TasarimGirdileri.referansTTK / referansEhpCarpani;

  /// Bir TABAN HASAR puanının ürettiği beklenen DPS.
  ///
  /// Referans build'in atış aralığından (alan 04) ve kritiğin beklenen
  /// değerinden (alan 01) çıkıyor; burada elle yazılan bir şey yok.
  ///
  /// Hiçbir gemiden OKUMUYOR ve okuyamaz: `ship_stats.dart` zaten bu dosyayı
  /// okuyor (K sabitleri için), yani ters yön döngü olurdu. Gerek de yok —
  /// çapanın değeri build'e bağlı değil: bir puan taban hasar, hangi gemide
  /// olursa olsun kritik beklentisi bölü atış aralığı kadar DPS ediyor.
  /// Fiyatın ölçüldüğü NOKTA ise dolu referans (`FiyatCozumu`), ve statların
  /// türevi orada alınıyor.
  /// KARAR 03.2 s2
  static double get saldiriPuaniDps =>
      kritikBeklenenDeger / TasarimGirdileri.referansAtisAraligi;

  /// Referans build'in EHP çarpanı — havuzu etkin cana çeviren oran.
  ///
  /// `1 ÷ (1 − azaltma)(1 − sıyırma)`. Referans zırh ve kaçınma alan 04'ten,
  /// hedef oranlar alan 01'den geliyor; ikisi de burada elle yazılmıyor.
  static double get referansEhpCarpani =>
      1 /
      ((1 - TasarimGirdileri.zirhAzaltmaHedefi) *
          (1 - TasarimGirdileri.siyirmaHedefiReferans));

  /// Kalkan yenilenmesinin fiyatı — çapanın oranı.
  ///
  /// Yenilenme havuzu BÜYÜTMÜYOR, zamana yayıyor: referans dövüş süresinde
  /// geri gelen miktar kadar değerli.
  /// KARAR 03.5 s2 — değerleme süresi kur süresi, ayrı girdi yok.
  static double get puanBasinaKalkanYenilenmesi =>
      savunmaCapasi / TasarimGirdileri.referansTTK / 100;

  /// Rank merdiveninin basamak sayısı — ALAN 06'nın girdisi.
  ///
  /// Gövde kademesi sayısını okuyordu ve "merdiven uzadığında bu ayrışacak"
  /// diyordu. Ayrıştı: yirmi rank, sekiz gövde. Normalizatör kademeleri rank
  /// aralıklarına bölüyor — her gövde 2,5 rank kapsıyor.
  static int get rankSayisi => TasarimGirdileri.rankSayisi;

  /// KARAR 04.7 s2
  static List<double> get govdeKademeCarpanlari => [
    for (var k = 0; k < TasarimGirdileri.govdeKademeSayisi; k++)
      TuretilenTablolar.normalizatorFor(
        k,
        rankSayisi: rankSayisi,
        kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
        artis: TasarimGirdileri.rankArtisi,
      ),
  ];

  // ══ Alan 11 · Haritalar ════════════════════════════════════════════

  /// BÖLGE SAYISI — yeni bir girdi DEĞİL.
  ///
  /// Bölge = gövde kademesi. Alan 04 dünyayı zaten kademeye bölmüştü ve bir
  /// kademe tam olarak "aynı ligde oynayan oyuncular" demek. Kaç harita
  /// olacağı sorusunun yanlış cevabı bir sayı seçmek; doğru cevabı var olan
  /// bölünmeyi ikinci kez kullanmak. Gövde kademesi eklenirse bölge de
  /// eklenir, elle bir şey yazılmaz.
  /// KARAR 11.1 s1
  static int get bolgeSayisi => TasarimGirdileri.govdeKademeSayisi;

  /// Toplam harita sayısı — bölge başına PvE · PvP · boss.
  static int get haritaSayisi =>
      bolgeSayisi * TasarimGirdileri.bolgeBasinaHarita;

  /// Bağıl nesil sürelerini [TasarimGirdileri.hedefSure]'ye oturtan ölçek.
  static double get sureOlcegi => TuretilenTablolar.sureOlcegiFor(
    rankSayisi: rankSayisi,
    artis: TasarimGirdileri.rankArtisi,
    us: TasarimGirdileri.gelirUssu,
    hedefSure: TasarimGirdileri.hedefSure,
  );

  /// [rank]'ta geçirilecek süre, saat.
  static double bantSuresi(int rank) => TuretilenTablolar.bantSuresiFor(
    rank,
    artis: TasarimGirdileri.rankArtisi,
    us: TasarimGirdileri.gelirUssu,
    olcek: sureOlcegi,
  );

  /// BİR BANDIN ALANI — birim kare.
  /// KARAR 11.5 s1
  static double get bantAlani => TuretilenTablolar.bantAlaniFor(
    oyuncu: TasarimGirdileri.esZamanliOyuncu,
    gorus: TasarimGirdileri.gorusYaricapi,
    seyreklik: TasarimGirdileri.gorusPaylasimi,
  );

  /// Bir BANTTA kaç yaratık — hedef yoğunluğu tutturan sayı.
  /// KARAR 11.5 s1
  static int get bantBasinaHedef => TuretilenTablolar.bantBasinaHedefFor(
    oyuncu: TasarimGirdileri.esZamanliOyuncu,
    seyreklik: TasarimGirdileri.gorusPaylasimi,
    hedef: TasarimGirdileri.gorusHedefi,
  );

  /// Saatin ne kadarı PvP ölümlerine gidiyor.
  /// KARAR 11.6 s1
  static double get pvpKayipOrani => TuretilenTablolar.pvpKayipOraniFor(
    siklik: TasarimGirdileri.pvpOlumSikligi,
    maliyetDk: TasarimGirdileri.olumMaliyetiDk,
  );

  /// PvP haritası saatte kaç KAT vermeli — ölümler dahil.
  /// KARAR 11.6 s1
  static double get pvpBrutPrim => TuretilenTablolar.pvpBrutPrimFor(
    netPrim: TasarimGirdileri.pvpNetPrim,
    kayipOrani: pvpKayipOrani,
  );

  // ═══════════════════════════════════════════════════════════════════
  // 17 · Mermi
  // ═══════════════════════════════════════════════════════════════════

  /// Mermi BİRİM FİYATI, kredi: c × m^k. MR-1 bedava (kilit): fiyat sıfır.
  /// KARAR 17.4 s1 · KARAR 17.2 s1
  static double mermiFiyati(int carpan) {
    if (carpan <= 1 && TasarimGirdileri.mr1Bedava) return 0;
    return TasarimGirdileri.mermiTabanFiyati *
        math.pow(carpan, TasarimGirdileri.mermiFiyatUssu);
  }

  /// Birim HASAR başına bedel: fiyat ÷ çarpan. Çarpanla artıyor: üst mermi
  /// hız satıyor, verim değil.
  static double mermiHasarBedeli(int carpan) => mermiFiyati(carpan) / carpan;

  /// Üssün ANKRAJI: tavan çarpanın birim hasar bedeli ×2'ninkinin iki katı
  /// → (tavan ÷ 2)^(k − 1) = 2 → k = 1 + ln 2 ÷ ln(tavan ÷ 2). Tepe tablodaki
  /// üs bunu taşımalı; türetme testi ölçüyor.
  /// KARAR 17.4 s1
  static double get mermiUsAnkraji =>
      1 + math.log(2) / math.log(TasarimGirdileri.mermiCarpanTavani / 2);

  /// Saatte ÖLDÜRME, çarpan m ile: çevrim = öldürme süresi ÷ m + doğma.
  /// Daha hızlı öldürmek beklemeyi kısaltmıyor — mermi bu yüzden PvE
  /// sistemi değil.
  /// KARAR 17.1 s1
  static double mermiOldurmeSa(int carpan, {bool guclu = false}) {
    final oldurme = guclu
        ? TasarimGirdileri.gucluOldurmeSuresi
        : TasarimGirdileri.siradanOldurmeSuresi;
    final dogus = guclu
        ? TasarimGirdileri.gucluDogusSuresi
        : TasarimGirdileri.siradanDogusSuresi;
    return 3600 / (oldurme / carpan + dogus);
  }

  /// PvE KAZANCI: ×m'in ×1'e göre saatlik öldürme fazlası.
  /// KARAR 17.1 s1
  static double mermiPveKazanci(int carpan, {bool guclu = false}) =>
      mermiOldurmeSa(carpan, guclu: guclu) / mermiOldurmeSa(1, guclu: guclu) -
      1;

  /// PvP TTK, ×m ile: referans ÷ m. Rakip yeniden doğmuyor; çarpan doğrudan.
  /// KARAR 17.1 s1
  static double mermiPvpTtk(int carpan) =>
      TasarimGirdileri.referansTTK / carpan;

  // ══ Roket — türetilen (18) ══════════════════════════════════════════

  /// Kadans oranı: roket aralığı bölü lazer aralığı (18.1).
  ///
  /// Eşya bütçesi lazer kadansında fiyatlanıyor (03): bir puan taban hasar,
  /// 1,1 saniyede bir vurulan bir hasar. Roket altı saniyede bir vuruyor;
  /// aynı puan salvoda bu oran kadar büyük, DPS'i aynı.
  static const double roketKadansOrani =
      TasarimGirdileri.roketAraligi / TasarimGirdileri.referansAtisAraligi;

  /// Roketatar yuvasının bütçe katsayısı, lazer yuvası birken (08.1).
  static const double roketatarYuvaKatsayisi =
      TasarimGirdileri.payRoketatar /
      (TasarimGirdileri.payLazer / TasarimGirdileri.lazerYuvaSayisi);

  /// Bir roket biriminin lazer birim atışına göre hasar oranı (18.3): kadans
  /// oranı × yuva katsayısı. Roket mermisinin fiyatı mermininkinin bu katı,
  /// birim hasar bedeli ikisinde aynı.
  static const double roketBirimOrani =
      roketKadansOrani * roketatarYuvaKatsayisi;

  /// Roket mermisinin birim fiyatı (18.3): mermi eğrisi × birim oranı.
  static double roketFiyati(int carpan) {
    if (carpan <= 1 && TasarimGirdileri.rk1Bedava) return 0;
    return mermiFiyati(carpan) * roketBirimOrani;
  }

  /// Hasar başına bedel — mermininkiyle aynı sayı olmalı.
  static double roketHasarBedeli(int carpan) =>
      roketFiyati(carpan) / (carpan * roketBirimOrani);
}

/// Savunma eğrileri — L4'ün iki kardeşi.
///
/// Zırh ve kaçınma matematiksel olarak aynı biçimi paylaşıyor, farklı K ile:
/// `stat / (stat + K)`. Doyumlu, asla 1'e ulaşmayan bir eğri — kural belgesi
/// 04'ün "hasar asla sıfırlanmaz" kuralı bu biçimin doğrudan sonucu, ayrıca
/// konmuş bir tavan değil.
abstract final class SavunmaEgrileri {
  /// Doyum eğrisi. [k] sıfır ya da negatifse azaltma yok.
  ///
  /// Sonuç MATEMATİKSEL olarak `[0, 1)` aralığında: `stat` ne kadar büyürse
  /// büyüsün pay paydadan küçük kalır. Hasarı sıfırlayan bir savunma statı bu
  /// yüzden var olamaz.
  static double doyum(double stat, double k) {
    if (stat <= 0 || k <= 0) return 0;
    return stat / (stat + k);
  }

  /// [referansStat] kadar stat taşıyan bir build'de [hedef] oranını veren K.
  ///
  /// `doyum(referansStat, kFor(referansStat, hedef)) == hedef` — testin
  /// doğruladığı özdeşlik.
  static double kFor(double referansStat, double hedef) {
    if (referansStat <= 0 || hedef <= 0 || hedef >= 1) return 0;
    return referansStat * (1 / hedef - 1);
  }

  /// Kaçınmadan gelen SIYIRMA. Doyum eğrisi, üstüne ilan edilmiş tavan.
  ///
  /// Tavan eğriye ek bir güvenlik değil, ayrı bir tasarım kararı: eğri 1'e
  /// yaklaşabilir ama oyuncunun yığarak varabileceği yer `siyirmaTavani` ile
  /// sınırlı. İkisi birden olmak zorunda — eğri hasarın SIFIRLANMAMASINI,
  /// tavan da yığmanın bir yerde durmasını garanti ediyor.
  /// KARAR 01.5 s1
  static double siyirma(double kacinma, double k) =>
      math.min(doyum(kacinma, k), TasarimGirdileri.siyirmaTavani);
}
