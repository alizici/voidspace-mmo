import 'tasarim_alanlari.dart';

/// TEK TEPE TABLO — elle girilen HER tasarım parametresi burada, TEK bir yerde.
///
/// Tablo güdümlü tasarımın (表格驱动) birinci kuralı: *"En üstte tek bir tablo,
/// çekirdek deneyim parametrelerini o tutar. Her şey ondan aşağı akar."*
/// Bozulursa aynı parametre iki yerde başlar ve ikisi bir sonraki denge turunda
/// ayrışır.
///
/// **Buraya YALNIZ girdi konur.** Türetilen hiçbir sayı bu dosyada duramaz —
/// onlar [Turetilenler]'de hesaplanan alanlar olarak yaşar ve kimse üstlerine
/// yazamaz. Çince kaynakların Excel'de renkle yaptığı ayrımın koddaki karşılığı
/// bu: girdi `const`, türetilen hesap.
///
/// **Denge turunda oynanacak kollar da yalnız bunlar.** Türetilmiş bir değeri
/// "biraz düzeltmek" istediğin an, aslında buradaki girdilerden birinin yanlış
/// olduğunu keşfetmişsindir.
/// KARAR 16.3 s1
abstract final class TasarimGirdileri {
  // ══ ALAN 01 · SAVAŞ ═══════════════════════════════════════════════════
  //
  // Yedi sayı. Zincirin başka hiçbir yerinde elle yazılmış bir sayı yok:
  // kritik PRD sabiti de, zırh eğrisinin K'sı da, sıyırma eğrisi de bu yediden
  // türüyor.

  /// Referans build'in kritik şansı.
  ///
  /// Dört yaylımda bir kritik: görülebilecek kadar sık, sıradanlaşmayacak kadar
  /// seyrek.
  /// KARAR 01.4 s1
  static const double kritikSansiReferans = 0.25;

  /// Referans build'in kritik çarpanı.
  ///
  /// Tam iki katı — ekranda okunması en kolay çarpan. Çapa yuvarlak olsun ki
  /// sapma görünsün.
  /// KARAR 01.4 s1
  static const double kritikCarpaniReferans = 2.00;

  /// Referans oyuncunun ZIRHTAN gördüğü hasar azaltması.
  ///
  /// Hissedilir ama savunmayı tek stata indirgemiyor. Zırh eğrisinin K sabiti
  /// bu hedeften türüyor ([Turetilenler.kZirhCarpani]).
  /// KARAR 01.2 s1
  static const double zirhAzaltmaHedefi = 0.30;

  /// Sıyırmanın TAVANI — kaçınma bunun ötesine geçemez.
  ///
  /// Hasar asla sıfırlanmaz: kaçınma ikili bir zar değil sürekli bir azaltma
  /// (kural belgesi 04). Yeterince yığan oyuncunun hasar almaz hâle gelmesini
  /// engelleyen tek sayı bu.
  /// KARAR 01.5 s1
  static const double siyirmaTavani = 0.40;

  /// Referans build'in KAÇINMADAN gördüğü sıyırma.
  ///
  /// Zırhın yarısı: ikisi kardeş ama zırh baskın olmalı.
  /// KARAR 01.5 s1
  static const double siyirmaHedefiReferans = 0.15;

  /// PvP'de zincirin SONUNA uygulanan tek katsayı.
  ///
  /// Bugün etkisiz — çünkü doğal PvP TTK'sı (22 sn) zaten hedef bantta. Kol
  /// duruyor, çekilmiyor. İki formül yazmamanın bedeli tam olarak bu tek sayı.
  static const double pvpCarpani = 1.00;

  /// L5 düz eklemesinin toplam hasarda alabileceği en büyük pay.
  ///
  /// Onda birini geçerse zincirin geri kalanı anlamsızlaşır: çarpan statları
  /// değersizleşir ve oyuncunun bütün kararı tek bir düz sayıya iner.
  /// KARAR 01.2 s1
  static const double sonHasarTavani = 0.10;

  // ══ MANİFEST ══════════════════════════════════════════════════════════

  /// Tepe tablonun okunabilir hâli — testlerin ve denetimin girdiği kapı.
  // ══ ALAN 03 · STAT DEĞERİ ═════════════════════════════════════════════
  //
  // GİRDİSİ YOK. Fiyatlar zincirin türevinden türüyor ([ItemBudget.fiyatlar]):
  // saldırı çapa taban hasar, savunma kanallar arası kurdan, sistem BR'nin
  // sistem çarpanından. Uzun süre beş saldırı fiyatı burada elle duruyordu ve
  // zincirin söylediğinden 2,5–3,3 kat ucuzdu — karar 03.1 ile türetilene
  // döndüler. Değerleme süresi de ayrı girdi değil: kur süresi (karar 03.5).

  // ══ ALAN 04 · GEMİ VE YUVALAR ═════════════════════════════════════════
  //
  // Gövdenin ÇAPASI ve referans build. Kademe merdiveninin ŞEKLİ burada DEĞİL:
  // her kademenin çarpanı rank merdivenine bağlı (alan 06) ve rank büyüme
  // katmanında, gövde savaş katmanında — "aşağı yalnız yukarıyı okur" kuralı
  // savaş katmanının büyümeden okumasını yasaklıyor.
  //
  // Yani 04 kaç kademe olduğunu ve her kademede kaç yuva açıldığını söylüyor;
  // o kademelerin ne kadar GÜÇLÜ olduğunu alan 08 çözüyor.

  // Gövde canının çapası burada DEĞİL: TTK kısıtından türetiliyor
  // (`Turetilenler.govdeCapasi`, karar 08.5). Uzun süre girdiydi (12.000) ve
  // referans TTK 29,6 çıkıyordu; çözüm kod olunca sapma sıfırlandı.

  /// Kademe 1 kalkanı.
  /// KARAR 04.7 s2
  static const double kalkanCapasi = 8000;

  /// Kademe 1 hızı (dünya birimi/sn).
  ///
  /// Hız kademeyle neredeyse artmıyor ve bu bilinçli: hız oyunun TEMPOSUNU
  /// belirliyor, gücünü değil.
  /// KARAR 04.7 s2
  static const double hizCapasi = 320;

  /// Referans build'in ZIRHI.
  ///
  /// Alan 01'in "referansta %30 azaltma" hedefi ancak referansın zırhı
  /// biliniyorsa sayıya dönüyor. Bu girdi dolduğu an [Turetilenler.kZirh]
  /// kendiliğinden çözülüyor — elle girilmiyor.
  /// KARAR 04.6 s1
  static const double zirhCapasi = 1000;

  /// Referans build'in KAÇINMASI — hız tipi jeneratörlerden.
  ///
  /// [zirhCapasi] ile aynı işi sıyırma eğrisi için yapıyor.
  /// KARAR 04.6 s1
  static const double referansKacinma = 300;

  /// Referans jeneratörlerin kaçı KALKAN tipi; kalanı hız.
  /// KARAR 04.5 s2
  static const double referansJeneratorKalkan = 0.50;

  /// Referans build'in ATIŞ ARALIĞI (sn).
  ///
  /// Kanallar arası kurun ikinci ayağı: bir taban hasar puanının kaç DPS
  /// ürettiği buna bölünüyor. Referans build alan 04'ün tanımı olduğu için
  /// bu sayı da onun — alan 09 onu okuyup kuru çözüyor.
  static const double referansAtisAraligi = 1.10;

  /// Gövde kademesi sayısı.
  ///
  /// Alan 04'ün kendi kararı ("Gövde kademesi ve yuva merdiveni"), alan 10'un
  /// değil: 10 merdivenin NE KADAR SÜRDÜĞÜNÜ söylüyor, kaç basamağı olduğunu
  /// değil.
  ///
  /// **Tasarımın hedefi 8, bugünkü değer 5** ve fark bir eksiklik değil bir
  /// KISIT: her gövde kademesi en az bir rank kapsamak zorunda, ve rank
  /// merdiveni ([ItemTier]) bugün beş kademeli. Sekiz gövdeye beş rank
  /// bölünemiyor — kademe normalizatörü o bölmeyi reddediyor.
  ///
  /// Bir süre 8 yazılıydı ve hiçbir şey yakalamıyordu: iki alan (04 ve 06) tek
  /// tek tutarlıydı ama birlikte imkânsız bir sistem tarif ediyorlardı. Tepe
  /// tablonun alanlar arası tutarlılık testi bunun için eklendi.
  ///
  /// Rank merdiveni yirmiye çıktığı gün sekize çıkacaktı; çıktı. Sıra o
  /// testin dediği gibi işledi: önce 06 kendi merdivenini aldı
  /// ([rankSayisi]), sonra bu sayı yükseldi. Ters sırada denenseydi
  /// `yukseltme_test` "eşya basamağı 5, rank 8" diye durdururdu.
  /// KARAR 04.7 s2
  static const int govdeKademeSayisi = 8;

  /// Kademe başına açılan yeni yuva — dördüncü kademeden itibaren.
  ///
  /// İlk üç gövdenin yuva sayısı (14 · 19 · 22) SANATA kilitli: lazer yuvası
  /// çizimdeki namlu sayısı demek. Dördüncüden sonrası bu artışla gidiyor ve
  /// bu yüzden bir sanat kararı — hesapla çıkmıyor.
  /// KARAR 04.8 s1
  static const int yuvaArtisi = 1;

  /// Hızın kademe merdiveni — kademe başına %8.
  ///
  /// Hız BÜTÇE kanalında değil sistem kanalında ve tempoyu belirliyor; rank
  /// çarpanıyla büyüseydi sekizinci kademe altı yüz kat hızlı olurdu. Eski
  /// tasarımın sayısı; kademe normalizasyonuna geçerken düşmüştü.
  /// KARAR 04.12 s2
  static const double hizArtisi = 1.08;

  /// Lazer yuvası — SANAT KISITI: çizimdeki namlu sayısı.
  ///
  /// Sekiz gövde tasarımının hepsi beş kaide taşıyor; istemcideki
  /// `AtlasLayout.emitterMounts` ile eşitliği test kilitliyor. Karar 04.9:
  /// sanat kazandı, açılan yuvalar lazere gitmiyor.
  /// KARAR 04.9 s2
  static const int lazerYuvaSayisi = 5;

  /// Lazer ve roketatar dışında kalan yuvaların JENERATÖRE giden payı;
  /// kalanı CPU. Bastion'ın 4 · 2 dağılımından: üçte iki.
  /// KARAR 04.9 s2
  static const double jeneratorYuvaPayi = 2 / 3;

  // ══ ALAN 05 · SAĞLAYICILAR ════════════════════════════════════════════
  //
  // Droid geldi, σ da onunla geldi. Olmayan bir sistem için sayı ilan etmek
  // "kod uygulandı" demenin karşılığını boşaltırdı; sistem varken ilan etmemek
  // ise elle sayı demek.

  /// DROİD FİLOSUNUN TAVANI — oyuncu başına en çok droid.
  ///
  /// Filo GEMİYE değil OYUNCUYA bağlı: gemi değişince kalıyor (04.10). On,
  /// eski merdivenin tavanı; bütçe ve saldırı payı tam filoya göre bölünüyor.
  /// KARAR 04.10 s3 · KARAR 05.8 s2
  static const int droidFiloTavani = 10;

  /// AKTARIM KATSAYISI σ — droidin geminin çarpanlarından aldığı pay.
  ///
  /// `droid çarpanı = 1 + σ · (gemi çarpanı − 1)`. Sıfırda droid düz bir
  /// toplam ve geç oyunda erir; birde geminin her çarpanı droid sayısıyla
  /// çarpılır ve droid yığmak tek build olur. 0,30 sağlıklı bandın ortası.
  /// KARAR 05.5 s3
  static const double aktarimKatsayisi = 0.30;

  /// FORMASYON TAKASI — eğilimli formasyonun σ'yı ve droid havuzunu
  /// zıt yönlere ittiği miktar. Yirmi formasyon, tek girdi.
  /// KARAR 05.9 s1
  static const double formasyonTakasi = 0.10;

  /// ArGe DÜĞÜMÜNÜN aktarım adımı — bir düğümün σ'ya kattığı.
  ///
  /// ArGe ham güç vermiyor, kapsam yönlendiriyor (05.7): filo dalı σ'yı
  /// yukarı, gemi dalı aşağı itiyor. Adım formasyon takasının
  /// (`formasyonTakasi = 0,1`) üçte biri: üç düğümlük bir dal, bir
  /// formasyon eğilimi kadar. Daha büyüğü ağacı formasyonun ikizi yapardı,
  /// daha küçüğü düğümü hissedilmez kılardı.
  /// KARAR 05.7 s2
  static const double argeAktarimAdimi = 0.033;

  /// GÖRÜNÜŞ fiyatı — bir droid tasarımı, NOVA (15.9).
  ///
  /// 15.3'ün "fiyat = kazandırdığı zaman" kuralı burada çalışmıyor ve
  /// çalışamaz: görünüş hiçbir bekleme kısaltmıyor, hiçbir güç vermiyor.
  /// Fiyatı bu yüzden türetilemez, ilan edilir. Bir saatlik NOVA gelirinin
  /// yaklaşık dörtte biri: istenir, düşünülür, biriktirilmez.
  /// KARAR 15.9 s1
  static const int tasarimNova = 100;

  /// FORMASYON fiyatı, NOVA (15.9).
  ///
  /// Tasarımın iki katı, çünkü formasyon yalnız görünüş değil GEOMETRİ:
  /// droidlerin dizilişini değiştiriyor ve eğilimiyle σ'yı itiyor (05.9).
  /// Gücü değiştirmiyor — takas imzalı ve toplamı sıfır — ama oyuncunun
  /// kararına giriyor, o yüzden bedava olmamalı.
  /// KARAR 15.9 s1
  static const int formasyonNova = 200;

  /// DROİDİN YUVA SAYISI — standart droid.
  ///
  /// Droid artık yalnız bir stat taşıyıcısı değil, bir TAŞIYICI: içine lazer
  /// ya da kalkan jeneratörü giriyor (05.4 s5). Bir yuva, çünkü seçim
  /// olmalı: hasar mı dayanıklılık mı. İki yuva standart droide verilseydi
  /// elit droidin ayırt edici yanı kalmazdı.
  /// KARAR 05.4 s5
  static const int droidYuvasi = 1;

  /// ELİT DROİDİN yuva sayısı — NOVA rafındaki droid (15.7).
  ///
  /// İki: elit droid seçim yapmak zorunda değil, hem vurur hem dayanır.
  /// Elitin tek farkı bu — rankı ve stat bütçesi kredi droidiyle aynı
  /// merdivenden geliyor.
  /// KARAR 05.4 s5
  static const int elitDroidYuvasi = 2;

  /// DROİD AŞINMA PAYI — ana gemi her öldüğünde droidin dayanıklılığından
  /// düşen puan.
  ///
  /// Droidin canı yok, DAYANIKLILIĞI var (05.10): dövüşte hedef alınmıyor,
  /// sahibinin ölümüyle aşınıyor. Yüzde on, yani on ölüm: bir droid, sahibi
  /// ölmeye devam ederse ölçülen sıklıkta ([genelOlumSikligi]) on saat
  /// dayanıyor. Küçük bir pay (yüzde bir) dayanıklılığı süse çevirirdi;
  /// büyüğü (yüzde elli) filoyu iki ölümde siler ve droid alınmaz olurdu.
  /// KARAR 05.10 s1
  static const int droidAsinmaPayi = 10;

  // ══ ALAN 06 · EŞYA KURGUSU ════════════════════════════════════════════
  //
  // Eşyanın İÇ bölünmesi: gücünün ne kadarı ana stata, ne kadarı alt statlara
  // gidiyor ve kalite rolü hangi bantta oynuyor.
  //
  // Rank MERDİVENİ burada: uzunluğu ve oranı 06'nın kararı. Bir süre değildi
  // ve bu yorum "o iş yapıldığında buraya gelecek" diyordu — iş yapıldı.

  /// RANK MERDİVENİNİN uzunluğu.
  ///
  /// Yirmi: altı harf ailesi × üç basamak (C-I … SSS-III), üstüne iki TEKİL
  /// rank — Kırmızı ve Parlayan Pembe. İkisi kalite değil rank; merdivenin
  /// tepesi 1,442^19 ≈ 1.048×, ve iki yıllık hedefin vardığı yer orası.
  ///
  /// **Burada duruyor çünkü 06'nın kararı.** Bir süre `Turetilenler.rankSayisi`
  /// gövde kademesi sayısını okuyordu: alan 06, alan 04'ün girdisini kendi
  /// kararı gibi kullanıyordu. İkisi eşitken görünmüyordu, ayrıştıkları an
  /// (yirmi rank, sekiz gövde) tepe tablonun kendi yorumu haklı çıktı —
  /// *"kaç rank ya da kaç gövde olduğu burada DEĞİL (06 ve 04'ün kararları)"*.
  static const int rankSayisi = 20;

  /// Eşya bütçesinin ANA stata giden payı; kalanı alt statlara.
  ///
  /// Bir zamanlar bir TAVANA dayandırılmıştı: "alt stat payı %43'ü geçince
  /// rank rengi gücü söylemeyi bırakır". Bugünkü merdivende öyle bir tavan
  /// yok — alt stat payı %100 olsa bile en dar boğaz [rankArtisi] ×
  /// [kaliteAltSiniri] kadar, yani birin üstünde ve çakışma yok (06.6 s2).
  /// %70 artık kendi gerekçesiyle duruyor: ana stat payı büyürse eşyalar
  /// birbirinin aynısı olur, küçülürse aynı eşyanın gücü oyuncudan oyuncuya
  /// oynar. Çakışma kısıdı yine de her turda ölçülüyor.
  /// KARAR 06.5 s1 · KARAR 06.6 s2
  static const double anaStatPayi = 0.70;

  /// Rank merdiveninin ORANI — her basamak bir öncekinin bu katı.
  ///
  /// **Ölçülerek bulundu, ilan edilerek değil.** `ItemTier` çarpanları
  /// (1,00 · 1,45 · 2,10 · 3,00 · 4,30) elle ve farklı zamanlarda konmuştu;
  /// ardışık oranları hesaplandığında 1,450 · 1,448 · 1,429 · 1,433 çıktı —
  /// yani zaten bir merdiveni izliyorlarmış, yalnız kuralı hiçbir yerde
  /// yazılı değilmiş.
  ///
  /// Yazıldığı an altıncı rank eklemek bir tahmin olmaktan çıkıp bir hesap
  /// oluyor. Beş elle yazılmış sayı, tek bir orana indi.
  /// KARAR 06.1 s1
  static const double rankArtisi = 1.442;

  /// Kalite rolünün TABANI — üst sınır her zaman 1,00.
  ///
  /// Bandın genişliği (%30) rank atlamasının (%44,2) altında kalmak zorunda:
  /// kalite hissedilir olmalı ama kapı olmamalı.
  /// KARAR 06.2 s1
  static const double kaliteAltSiniri = 0.70;

  /// SS–SSS kalite bandının tabanı — daha dar, daha güvenilir.
  /// KARAR 06.10 s2
  static const double kaliteAltSiniriSS = 0.75;

  /// Kırmızı ve Parlayan Pembe'nin bandı — en dar.
  /// KARAR 06.10 s2
  static const double kaliteAltSiniriRenk = 0.80;

  /// SS–SSS'de mükemmel (rol 1,0) gelen alt stat sayısı.
  /// KARAR 06.10 s2
  static const int garantiliAltStatSS = 1;

  /// Kapak taşlarında mükemmel gelen alt stat sayısı.
  /// KARAR 06.10 s2
  static const int garantiliAltStatRenk = 2;

  // ══ ALAN 08 · GÜÇ BÜTÇESİ ═════════════════════════════════════════════
  //
  // Toplam gücün yuva gruplarına PAYI. Katsayılar buradan TÜRÜYOR, tersi
  // değil: "bir lazer 200 hasar versin" cümlesi "lazerler gücün %23'ünü
  // alsın" cümlesinden daha somut ve daha kolay doğrulanıyor.

  /// Referans bütçe — C0 bir lazerin toplam bütçe puanı.
  ///
  /// Sayının kendisi keyfî; ÖNEMLİ olan bütün eşyaların ona göre türemesi.
  /// Alan 06 bölünmeyi (%70 ana / %30 alt) ilan ettiğinde bu çapanın ANLAMI
  /// değişti: 200 bütçe artık 200 taban hasar değil, **140** veriyor.
  ///
  /// Çapa yine de 200'de kalıyor ve bu bilinçli bir karar: yükseltmek bütün
  /// eşyaların gücünü %43 artırırdı, oysa bölünme bir GÜÇ kaybı değil bir
  /// DAĞITIM. Kaybolan %30 alt statlara gitti; ölçülen %20'lik DPS düşüşü ise
  /// fiyat tablosunun (alan 03) yeniden türetilmesiyle kapanacak — alan 09
  /// savunma StatMod'larını ×20,28 ölçeklediğinde saldırı tarafı da yeniden
  /// fiyatlanıyor.
  /// KARAR 08.1 s1
  static const double butceCapasi = 200;

  /// Gövdenin bütçe payı (%). Gövde bir yuva değil, yuvaların taşıyıcısı.
  ///
  /// Droid gelince beş pay orantılı düştü (×0,85): 21,58 → 18,34. Belgenin
  /// kendi kuralı, grup eklemek de çıkarmak da aynı muhasebe.
  /// KARAR 08.1 s1
  static const double payGovde = 18.34;

  /// Lazer grubunun payı — katsayı ölçeğinin çapası (1,00). 31,65 → 26,90.
  /// KARAR 08.1 s1
  static const double payLazer = 26.90;

  /// Jeneratör grubunun payı. 26,62 → 22,63.
  /// KARAR 08.1 s1
  static const double payJenerator = 22.63;

  /// Roketatar — tek yuva, dar bant. 7,91 → 6,72.
  /// KARAR 08.1 s1
  static const double payRoketatar = 6.72;

  /// CPU grubunun payı. 12,23 → 10,40.
  /// KARAR 08.1 s1
  static const double payCpu = 10.40;

  /// DROİD grubunun payı — altıncı grup. Droid DPS payı hedefiyle (09.6)
  /// aynı büyüklükte: droid gücün yüzde on beşini taşıyor, bütçenin de.
  /// KARAR 08.1 s1
  static const double payDroid = 15.0;

  /// Ölçülen pay ile ilan edilen payın izin verilen farkı, puan (08.3).
  ///
  /// Üçten ona (borç defteri B12): sapma yapısal. Lazer taban hasarı veriyor,
  /// her çarpan onun üstüne biniyor ve Shapley'nin tamamlayıcılık artığı ona
  /// akıyor; ilanı ölçüme çekmek kovalamaca olurdu, lazer bütçesi büyüdükçe
  /// ölçülen pay yine kaçar. İlan bütçe niyeti, ölçüm bilgi; bant ölçümün
  /// "sağlıklı" dediği yer.
  /// KARAR 08.3 s2
  static const double payBandi = 10;

  // ══ ALAN 09 · SAVAŞ PUANI ═════════════════════════════════════════════
  //
  // Kanallar arası KUR. Saldırı ile dayanıklılığı tek bir sayıda toplamak,
  // aralarında bir değişim oranı ilan etmeyi gerektiriyor — ve o oran ayrı bir
  // girdi değil, hedef TTK'nın kendisi.

  /// Referans build'in hedef ÖLDÜRME SÜRESİ (sn) — kanallar arası kurun KENDİSİ.
  ///
  /// `1 DPS ≡ 30 EHP`. Ayrı bir girdi değil: T saniyede öldüren bir saldırı
  /// ile T saniye dayanan bir savunma, tanım gereği eşit güçtedir.
  ///
  /// Bu sayı aynı zamanda savaşın TEMPOSU: kısaltmak refleks yarışı, uzatmak
  /// yıpratma savaşı üretiyor.
  /// KARAR 09.2 s1
  static const double referansTTK = 30.0;

  /// BR ÖLÇEĞİ — bütün savaş puanlarını aynı oranda çarpan sabit.
  ///
  /// Dengeye HİÇ karışmıyor: sıralamayı değiştirmiyor, yalnız sayıyı okunur
  /// bir aralığa taşıyor. Değeri ilk unvanın eşiğinden geliyor.
  /// KARAR 09.7 s1
  ///
  /// Yeniden çözüldü: gövde çapası TTK'dan türeyince referansta A = D tam
  /// sağlandı ve BR tabanı `A × K` oldu; 3.600 için K = 3.600 ÷ 1.136,36.
  ///
  /// Üçüncü çözüm (04.5 s2): referans tam donanımlı olunca kanal gücü
  /// (sistem çarpansız √(A·D), A = D olduğundan referans DPS'in kendisi)
  /// ölçeksiz 2.008,22 oldu (roket dahil, 18); 3.600 için K = 3.600 ÷ 2.008,22.
  /// İLK UNVANIN EŞİĞİ — merdivenin tabanı, savaş puanı biriminde (10.3).
  ///
  /// Referansın kanal gücü (sistem çarpansız √(A·D) × K) buraya oturtulur:
  /// K bu sayıdan çözülür (09.7). Savaş katmanı merdivenin tabanını buradan
  /// okur; dolu referans büyüme katmanında yaşıyor ve savaş katmanı onu
  /// okuyamaz ("aşağı yalnız yukarıyı okur").
  /// KARAR 09.7 s1 · KARAR 10.3 s1
  static const double ilkUnvanEsigi = 3600;

  static const double brOlcegi = 1.79263;

  /// SİSTEM kanalının tavanı (puan) — çarpan en fazla `1 + tavan/100`.
  ///
  /// Tavan zorunlu: sistem statları ÇARPIMSAL, yani hem saldırıyı hem
  /// dayanıklılığı birden büyütüyorlar. Sınırsız bırakılırsa geometrik
  /// ortalamanın içinde iki kez sayılan şey baskın olur.
  /// KARAR 09.5 s1
  static const double sistemTavani = 25.0;

  /// Menzilin sistem katsayısı — %1 başına kaç sistem puanı.
  ///
  /// En değerlisi: hedefte kalma süresini uzatıyor, hem saldırıya hem kaçışa
  /// yarıyor. ∂DPS/∂menzil = 0 olduğu için saldırı kanalında fiyatlanamıyor.
  /// KARAR 09.5 s1
  static const double sistemKatsayisiMenzil = 0.50;

  /// Hızın sistem katsayısı. Yetişmek ve kaçmak.
  /// KARAR 09.5 s1
  static const double sistemKatsayisiHiz = 0.40;

  /// İtki dolumunun sistem katsayısı. Yalnız kaçışa yarıyor, yetişmeye
  /// değil, ve şarj sayısıyla sınırlı: üçünün en küçüğü. Belge 1.0'da
  /// tasarlanmıştı; stat kütüphaneye girene kadar kodda yeri yoktu.
  /// KARAR 09.5 s1
  static const double sistemKatsayisiItki = 0.30;

  /// Droidlerin referanstaki SALDIRI payı — droid taban hasarı bundan türer,
  /// elle konmaz (05.5).
  /// KARAR 09.6 s1
  static const double droidDpsPayi = 0.15;

  /// Droid dayanıklılığının BR'ye giriş katsayısı. Geometrik ortalamanın
  /// içinde iki kez sayılan şey kareköke rağmen baskın olur; çeyrek bu iki
  /// yönlü kaldıracı kırıyor.
  /// KARAR 09.6 s1
  static const double droidDayaniklilikKatsayisi = 0.25;

  // ══ ALAN 10 · İLERLEME VE UNVAN ═══════════════════════════════════════
  //
  // Merdivenin NE KADAR SÜRDÜĞÜ ve kaç basamağa bölündüğü. Kaç rank ya da kaç
  // gövde olduğu burada DEĞİL (06 ve 04'ün kararları) — 10 yalnız tempoyu ve
  // unvan bölünmesini söylüyor.

  /// Son unvana varmanın hedef SÜRESİ (saat).
  ///
  /// Tek girdi, ve bütün tempo ondan çıkıyor: 1,5 sa/gün × 5 gün × 104 hafta.
  /// Değiştiği an yeniden çözülen şey SÜRE ÖLÇEĞİ, gelir üssü değil
  /// ([TuretilenTablolar.sureOlcegiFor]): ölçek bağıl süreleri hedefe
  /// eşitliyor, yani toplam herhangi bir α'da tam bu sayı çıkıyor (10.5 s2).
  /// KARAR 10.5 s2
  static const double hedefSure = 780.0;

  /// Unvan merdiveninin basamak sayısı.
  ///
  /// BR aralığı bu sayıya EŞİT ORANLARLA bölünüyor: her unvan bir öncekinin
  /// sabit katı. Doğrusal bölmek üst uçta yüzlerce basamağı bir araya
  /// sıkıştırırdı, çünkü BR üstel büyüyor.
  /// KARAR 10.3 s1
  static const int unvanSayisi = 120;

  /// GELİR ÜSSÜ (α) — maliyet ile gelirin büyüme hızları arasındaki fark.
  ///
  /// Maliyet rank çarpanının birinci kuvvetiyle, gelir α'ıncı kuvvetiyle
  /// büyüyor. α < 1 olduğu sürece her nesil bir öncekinden uzun sürüyor.
  ///
  /// α = 0 (gelir sabit) bugünkü hâl ve merdiveni erken durduruyor: harita
  /// kademesi diye bir şey olmadığı için her yaratık aynı krediyi veriyor.
  /// Alan 11 harita kademelerini getirdiğinde bu üs oraya da uygulanacak.
  /// KARAR 10.5 s2
  static const double gelirUssu = 0.816;

  // ══ ALAN 11 · HARİTALAR ═══════════════════════════════════════════════

  /// GÖRÜŞ YARIÇAPI — oyuncunun ilgilendiği dünya parçasının yarıçapı, birim.
  ///
  /// FİZİKSEL girdi, denge kararı değil: 0,6 yakınlaştırmada telefon ekranı
  /// ~3.200 birim görüyor ve 2.600 yarıçap ekranı kenar payıyla kapsıyor.
  /// Ekran ölçüsünden geliyor.
  ///
  /// Buraya TAŞINDI çünkü iki tüketicisi var: ağ katmanı (replikasyon hangi
  /// varlığı gönderecek) ve alan 11 (harita ne kadar büyük olacak). İki yerde
  /// iki kopya, biri değiştiğinde ilgi alanı ile haritanın sessizce ayrışması
  /// demekti — `Protocol.interestRadius` artık buradan okuyor.
  /// KARAR 11.5 s1
  static const double gorusYaricapi = 2600;

  /// DÜNYA EN/BOY ORANI — haritanın kenar oranı.
  ///
  /// Alan formülü yalnız KAÇ birim kare gerektiğini söylüyor; o alanın hangi
  /// dikdörtgene dağıldığı ayrı bir karar. Yatay oyun için 3:2.
  /// KARAR 11.5 s1
  static const double dunyaEnBoyOrani = 1.5;

  /// BÖLGE BAŞINA HARİTA — PvE · PvP · boss.
  ///
  /// Kategorik bir sayı, ayarlanabilir bir kadran değil: üç harita oyunun üç
  /// tehdit biçimine karşılık geliyor (yalnız yaratık · yaratık + oyuncu ·
  /// zamanlı tek hedef). Dördüncüsü yeni bir tehdit biçimi icat etmeden
  /// eklenemez.
  /// KARAR 11.1 s1
  static const int bolgeBasinaHarita = 3;

  /// GİRİŞ PAYI — bölgeye girmek için referans BR'nin kaçı gerekiyor.
  ///
  /// %100 oyuncuyu bir önceki bölgeyi TAMAMEN bitirmeye zorlardı. %75, ilk
  /// bandın yaratıklarını yenebileceği ama derine inemeyeceği nokta: hazır
  /// hissettiği anda risk alabiliyor, girer girmez duvara toslamıyor.
  ///
  /// Kapı BR ile ölçülüyor, seviye ile değil: seviye zamanla artıyor, BR
  /// güçle. İki yıl oynamış ama güçlenmemiş bir oyuncu, seviye kapısından
  /// geçip taşıyamayacağı bir bölgede hiçbir şey yapamaz hâlde kalırdı.
  /// KARAR 11.3 s1
  static const double girisPayi = 0.75;

  /// EŞ ZAMANLI OYUNCU — bir haritada aynı anda kaç oyuncu hedefleniyor.
  ///
  /// Harita boyutunun üç girdisinden biri. Somut ve cevaplanabilir bir soru;
  /// "harita ne kadar büyük olsun" değil.
  /// KARAR 11.5 s1
  static const int esZamanliOyuncu = 8;

  /// GÖRÜŞ PAYLAŞIMI (seyreklik) — görüş alanlarının ne kadar örtüşeceği.
  ///
  /// 1,0 herkese ayrı bir çember demek (ıssız harita), 0,0 hepsi üst üste
  /// demek (kaos). 0,5: ortalama bir oyuncu ikinci bir oyuncuyu görüş
  /// alanının yarısı kadar bir uzaklıkta bulur.
  /// KARAR 11.5 s1
  static const double gorusPaylasimi = 0.50;

  /// GÖRÜŞ HEDEFİ — görüş çemberinde ortalama kaç yaratık.
  ///
  /// Üçten az olursa oyuncu hedef arıyor; beşten çok olursa aynı anda üç
  /// yaratık birden saldırıyor ve harita bir farm alanı değil bir mayın
  /// tarlası oluyor.
  /// KARAR 11.5 s1
  static const int gorusHedefi = 4;

  /// PvP NET PRİMİ — ölümler düşüldükten SONRA kalan kazanç farkı.
  ///
  /// %30'da tutuluyor çünkü daha yükseği PvP'yi seçim olmaktan çıkarır:
  /// PvP'den kaçınan oyuncunun ilerlemesi yavaşlamalı, DURMAMALI.
  /// KARAR 11.6 s1
  static const double pvpNetPrim = 0.30;

  /// ÖLÜM MALİYETİ — bir ölümün geri alınması kaç dakika sürüyor.
  ///
  /// Dönüş yolu ve onarım. Kredi cinsinden değil ZAMAN cinsinden, çünkü prim
  /// saatlik gelir oranı ve iki tarafın aynı birimde olması gerekiyor.
  /// KARAR 11.6 s1
  static const double olumMaliyetiDk = 5.0;

  /// PvP ÖLÜM SIKLIĞI — saatte kaç ölüm. **ÖLÇÜLECEK.**
  ///
  /// Tepe tablodaki tek playtest girdisi. Üçü varsayım; ölçüm geldiğinde
  /// yalnız bu satır değişiyor ve brüt prim kendiliğinden yeniden çözülüyor.
  ///
  /// 8/saati geçerse kayıp oranı %67'ye çıkıyor ve brüt prim ×3,9 oluyor. O
  /// noktada yanlış olan formül değil TASARIM: PvP haritası fazla ölümcül.
  /// KARAR 11.6 s1
  static const double pvpOlumSikligi = 3.0;

  // ══ ALAN 12 · DÜŞMAN KURGUSU ══════════════════════════════════════════

  /// SIRADAN yaratığın ölme süresi, saniye.
  ///
  /// Sınıf bir ORANDIR, bir sayı değil: can `süre × referansDPS(bant)` olduğu
  /// için öldürme süresi yirmi bant boyunca sabit kalıyor. Değişen tek şey
  /// sayıların büyüklüğü — savaşın temposu değişmiyor.
  ///
  /// Sıradan yaratık gelirin taşıyıcısı: görmezden gelinebilir, riski oyuncu
  /// başlatır.
  /// KARAR 12.2 s2
  static const double siradanOldurmeSuresi = 1.0;

  /// GÜÇLÜ yaratığın ölme süresi, saniye.
  ///
  /// Beş kat: girmek bir karar. Kendisi saldırıyor ama kaçamıyor — girmek de
  /// çıkmak da oyuncunun elinde. Tehlikeli yapan hasarı değil, kaçamayacağın
  /// kadar uzun sürmesi.
  /// KARAR 12.2 s2
  static const double gucluOldurmeSuresi = 5.0;

  /// Sıradan yaratığın yeniden doğma süresi, saniye.
  ///
  /// Ödül hesabının yarısı bu: çevrim `doğma + öldürme`, ve sekiz saniye
  /// bugünkü dokuz saniyelik farm çevriminin neredeyse tamamı. Anında doğmak
  /// haritayı ölümsüz kılar, hiç doğmamak birkaç dakikada boşaltır.
  /// KARAR 12.3 s1
  static const double siradanDogusSuresi = 8.0;

  /// Güçlü yaratığın yeniden doğma süresi, saniye.
  /// KARAR 12.3 s1
  static const double gucluDogusSuresi = 20.0;

  /// Sıradan yaratığın HIZI — oyuncunun hızına oran.
  ///
  /// Kovalayabilir ama yetişemez. Kaçmak HER ZAMAN mümkün; bedeli o ana kadar
  /// yatırılan zaman.
  /// KARAR 12.1 s1
  static const double siradanHizOrani = 0.30;

  /// Güçlü yaratığın hız oranı — hiç kovalayamaz.
  /// KARAR 12.1 s1
  static const double gucluHizOrani = 0.15;

  /// Boss'un hız oranı.
  /// KARAR 12.1 s1
  static const double bossHizOrani = 0.10;

  /// Sıradan yaratığın MENZİLİ — oyuncunun menziline oran.
  ///
  /// Hiçbir yaratığın menzili oyuncununkine eşit olamaz: eşit olsaydı mesafe
  /// tutmanın anlamı kalmaz, savaş bir sağlık-çubuğu yarışına dönerdi.
  /// KARAR 12.1 s1
  static const double siradanMenzilOrani = 0.50;

  /// Güçlü yaratığın menzil oranı.
  /// KARAR 12.1 s1
  static const double gucluMenzilOrani = 0.65;

  /// Boss'un menzil oranı — en yakın, ama hâlâ altında.
  /// KARAR 12.1 s1
  static const double bossMenzilOrani = 0.80;

  /// KAÇIŞ PENCERESİ — üç yaratığı birden çeken oyuncunun kaçmak için süresi,
  /// saniye.
  ///
  /// Yaratık hasarı "ne kadar acıtsın" ile ayarlanamaz. Ayarlanabilir soru
  /// bu, ve cevabı bir pencere: oyuncu üç yaratığı üstüne çektiğini fark
  /// ediyor, itkiyi kullanıyor, menzil dışına çıkıyor. 120 saniye o zincirin
  /// TAMAMI için.
  /// KARAR 12.4 s1
  static const double kacisPenceresi = 120.0;

  /// Aynı anda çekilebilen yaratık sayısı — hasar hesabının paydası.
  ///
  /// Tehdit tek yaratıktan değil, üçünü birden çekmekten geliyor.
  /// KARAR 12.4 s1
  static const int tehditSayisi = 3;

  /// GÜÇLÜ yaratığın risk primi — saldırgan olmasının karşılığı.
  ///
  /// Sıradan yaratıkta prim YOK, çünkü riski oyuncu seçiyor.
  /// KARAR 12.3 s1
  static const double gucluRiskPrimi = 1.15;

  /// BOSS grubu — kaç oyuncu.
  /// KARAR 12.5 s1
  static const int bossGrubu = 3;

  /// Boss'un hedef dövüş süresi, saniye.
  ///
  /// Canı bundan çıkıyor: `grup × süre × referansDPS`. Üç oyuncu iki dakika.
  /// KARAR 12.5 s1
  static const double bossHedefSuresi = 120.0;

  /// Boss ödül primi — harcanan oyuncu-saatin kaç katı.
  /// KARAR 12.5 s1
  static const double bossPrimi = 3.0;

  /// Boss'un taşıdığı gelir payı.
  ///
  /// Yeterince büyük ki beklemeye değsin, yeterince küçük ki kaçırmak
  /// ilerlemeyi durdurmasın. Boss'a hiç girmeyen oyuncu %15 yavaş ilerliyor —
  /// DURUYOR değil.
  ///
  /// Doğma aralığı bundan türüyor ve her bantta AYNI çıkıyor: oyuncu hangi
  /// bölgede olursa olsun aynı ritmi öğreniyor.
  /// KARAR 12.5 s1
  static const double bossGelirPayi = 0.15;

  /// TABAN SAATLİK GELİR — birinci bandın kredi hedefi.
  ///
  /// Ölçülen farm hızından geliyor: bir sıradan yaratık, dokuz saniyelik
  /// çevrim, saatte 400 çevrim. Ödül bir tasarım kararı değil bu hedefin
  /// bölünmesi — `hedef × çevrim ÷ 3600`.
  ///
  /// **Açık.** Bu sayının alan 13'ün maliyet merdiveniyle uzlaştırılması
  /// gerekiyor: 780 saat × bu hız, bugünkü katalog fiyatlarının çok üstünde
  /// bir toplam üretiyor. Uzlaştırma 13'ün işi; 12 yalnız bölmeyi yapıyor.
  /// KARAR 12.3 s1
  static const double tabanSaatlikGelir = 144000.0;

  /// Sıradan yaratık başına NOVA — kademeyle ÖLÇEKLENMEZ.
  ///
  /// Kredi bantla yüzlerce kat büyüyor, NOVA büyümüyor. Sebebi tek cümle:
  /// NOVA gerçek parayla rekabet ediyor. Kademeyle ölçeklenirse son bölgedeki
  /// oyuncu saatte yüzlerce kat NOVA basar ve satılan NOVA'nın değeri
  /// sıfırlanır.
  ///
  /// Sonuç: NOVA zamana bağlı, güce değil. Üst bölgedeki oyuncunun avantajı
  /// NOVA kazanmakta değil, NOVA'ya İHTİYACI OLMAMAKTA.
  /// KARAR 12.6 s1
  static const int novaOdulu = 1;

  // ══ ALAN 07 · GÜÇLENDİRME ═════════════════════════════════════════════

  /// ARTI KAZANÇ BİÇİMİ — seviye artışları toplanır mı, çarpılır mı.
  ///
  /// **Kategorik girdi**, sayı değil: bu yüzden [hepsi] listesinde yok
  /// ([TasarimGirdisi.deger] `num`). Yine de bir tepe tablo satırı — alan
  /// 06'nın devrettiği çelişkinin kararı burada veriliyor.
  ///
  /// Belge toplamsal ilan ediyordu (+15'te 2,50×), kod bileşik hesaplıyordu
  /// (4,170×). Üç seçenek ölçüldü ve üçüncüsü seçildi: **toplamsal kazanç,
  /// yeniden çözülmüş maliyet eğrisi**. Böylece hem ilan edilen güç tavanı
  /// (10,75×) hem değer eğrisi (12,0×) aynı anda tutuyor.
  /// KARAR 07.3 s1
  static const ArtiKazancBicimi artiKazancBicimi = ArtiKazancBicimi.toplamsal;

  /// MALİYET HACMİ (c₀) — yükseltme eğrisinin taban kredisi.
  ///
  /// Maliyet eğrisi `c₀ × b^L` İKİ iş birden yapıyordu ve tek kolla
  /// ayarlanıyordu: hacmi tutturmaya çalışırken şekli bozuyor, ya da tersi.
  /// Ayrıldılar — **c₀ hacmi, b şekli** belirliyor.
  ///
  /// Hacim ekonominin ana gideri: bir C-I eşyayı +15 yapmak 229.265 kredi,
  /// ilk haritanın saatlik gelirinde 1,6 saat.
  /// KARAR 07.4 s1
  static const double maliyetHacmi = 2489;

  /// MALİYET ŞEKLİ (b) — son seviyelerin ilk seviyelere göre değer bozulması.
  ///
  /// Bugünkü 1,350 ile son yükseltme ilkinden 44,5 kat kötü değer oluyordu
  /// (toplamsal kazançla): +11'den sonrası kimsenin dokunmadığı ölü sistem.
  /// 1,2293 bunu 12 kata indiriyor ve TOPLAM SİNKİ değiştirmiyor — eğri
  /// düzleşti, hacim korundu.
  /// KARAR 07.4 s1
  static const double maliyetSekli = 1.2293;

  /// SENTEZ ORANI — kaç eşya bir üst rank tek eşyaya dönüşüyor.
  ///
  /// Verim `rankArtisi ÷ oran`: 2→1'de %72 (sentez drop'un yerine geçer),
  /// 3→1'de %48 (fazla eşyaya değer ama kestirme değil), 5→1'de %29 (ölü
  /// sistem). Üçü seçildi.
  ///
  /// Asıl gerekçe YERELLİK: bir kademe yukarı 3 eşya, iki kademe 9, üç kademe
  /// 27 — dördüncüde 81'e çıkıp pratik ufkun dışına düşüyor. Yirmi kademelik
  /// merdivenin dibinden tavanına sentezle çıkmak 3^19 ≈ 1,16 milyar eşya
  /// demek, yani sentez hiçbir zaman drop'un yerine geçemiyor.
  /// KARAR 07.7 s1
  static const int sentezOrani = 3;

  /// ÇEVİRME ARTIŞI — art arda alt stat çevirmede maliyet çarpanı.
  ///
  /// Katlanan maliyet, tek oturumda mükemmel roll kovalamayı pahalı yapıyor;
  /// sonucu KABUL EDİNCE sıfırlanması ise eşyayı kalıcı olarak ölü
  /// bırakmıyor. İkisi birlikte "yeter artık" demenin doğru anı olmasını

  /// BAŞARISIZLIK ŞANSI — **sabit sıfır.**
  ///
  /// Bir girdi değil bir KİLİT. Sıfırdan farklı bir değere ayarlanması
  /// değişmez testini kırıyor, yani başarısızlık ancak bilinçli bir tasarım
  /// kararıyla — testi de silerek — gelebilir.
  ///
  /// İki sebep. Başarısızlık tavanı doğrudan paraya çevirir: koruma tılsımı
  /// satılır ve "tavanlı orta P2W" sözü delinir; delindiği an geri alınamaz,
  /// çünkü koruma satın almış oyuncular vardır. İkincisi, mağaza yorumlarını
  /// kalıcı olarak bozan tek mekanik budur — on saatlik emeğini kırılan bir
  /// eşyada kaybeden oyuncunun yazdığı yorum oyunun ömrü boyunca orada kalır.
  ///
  /// Doğrusu: garantili başarı, katlanarak artan maliyet. Aynı para sinki,
  /// sıfır öfke.
  /// KARAR 07.2 s1
  static const double basarisizlikSansi = 0.0;

  // ══ ALAN 13 · KAYNAK AKIŞI ════════════════════════════════════════════

  /// GENEL ÖLÜM SIKLIĞI — saatte kaç ölüm, oyunun tamamında.
  ///
  /// [pvpOlumSikligi] ile KARIŞTIRILMAMALI: o, PvP haritasındaki sıklık (3) ve
  /// risk primini çözüyor. Bu, oyuncunun ortalama saatindeki sıklık — çünkü
  /// oyunun çoğu PvE'de geçiyor ve onarım bütçesi ortalamaya bakmak zorunda.
  ///
  /// Onarım payı bundan TÜRETİLİYOR, ilan edilmiyor: `sıklık × maliyet ÷ 60`.
  /// Playtest sıklığı ölçtüğünde beş gider kalemi birden yeniden hesaplanıyor
  /// ve elle ayarlanacak tek bir yüzde kalmıyor.
  ///
  /// Ölçülen sıklık 3'ü geçerse onarım payı %25'e çıkıyor — o noktada
  /// düzeltilecek olan ekonomi değil PvP tasarımı.
  /// KARAR 13.3 s1
  static const double genelOlumSikligi = 1.0;

  /// Onarım DÜŞÜLDÜKTEN sonra kalan payın ARTI BASMAYA giden kısmı.
  ///
  /// Ekonominin ana gideri, alan 07'nin öngördüğü gibi. Etkin payı %55.
  /// KARAR 13.3 s1
  static const double payArti = 0.60;

  /// Kalan payın SENTEZE giden kısmı — etkin %13,7.
  /// KARAR 13.3 s1
  static const double paySentez = 0.15;

  /// Kalan payın MAĞAZAYA giden kısmı — etkin %13,7.
  /// KARAR 13.3 s1
  static const double payMagaza = 0.15;

  /// Kalan payın BİRİKİME giden kısmı — etkin %9,2.
  ///
  /// Bir gider değil bir TAMPON: harcanmadan duruyor. Oyuncunun bir sonraki
  /// nesle geçerken elinde bir şey olması ve ekonominin nefes alması için.
  /// Sıfıra indirilirse her oyuncu her an beş parasız olur ve tek bir kötü
  /// kararın telafisi kalmaz.
  /// KARAR 13.3 s1 · KARAR 13.5 s1
  static const double payBirikim = 0.10;

  /// PARA ÇEVİRME — **sabit kapalı.**
  ///
  /// Bir girdi değil bir KİLİT, [basarisizlikSansi] gibi. Açmak değişmez
  /// testini kırıyor.
  ///
  /// Bir ekonominin sağlığı musluk ile giderin eşit olmasına değil, farklı
  /// kaynakların birbirine DÖNÜŞMEMESİNE bağlı: dönüşüm serbest olduğu anda
  /// üç musluk tek musluğa iner ve en verimli olanı diğerlerini öldürür.
  ///
  /// NOVA ↔ kredi özellikle imkânsız: NOVA sabit (saatte 360), kredi bantla
  /// 291 kat büyüyor, yani NOVA'nın kredi cinsinden değeri kendiliğinden 291
  /// kat artıyor. Tek yönlü bir çevirme bile açılsa üst bantlı oyuncu NOVA'yı
  /// 291 kat ucuza alır ve gerçek parayla satılanın karşılığı sıfırlanır.
  /// KARAR 13.2 s1
  static const bool paraCevirmeAcik = false;

  // ══ ALAN 14 · GANİMET ═════════════════════════════════════════════════

  /// ÇEVİRME KALİTE HEDEFİ — MÜKEMMEL sayılan roll dilimi.
  ///
  /// [kaliteHedefi]'nden AYRI ve ayrı olması şart. O, eşya DÜŞME oranını
  /// çözüyor: "oyuncu her yuva için istediği rollü bulabilsin" deniyor ve
  /// düşüş ondan türüyor. Bu ise çevirmenin hedefi — ve çevirme geldiği için
  /// denemeler artık düşüşten gelmek zorunda değil.
  ///
  /// İkisini tek sayıda birleştirmek somut bir hataya yol açardı: hedefi
  /// %1'e çekmek düşme oranını yirmi kat artırırdı ve oyun eşyaya boğulurdu.
  /// Ayrıldıkları için düşüş yerinde kalıyor, nadirleşen şey yalnız MÜKEMMEL
  /// roll oluyor.
  ///
  /// %1 = ortalama YÜZ deneme. Yüksek stat bu yüzden değerli: bir oyuncunun
  /// bütün yuvalarını mükemmele çıkarması bir nesilde imkânsız, ve hangi
  /// yuvayı kovalayacağı gerçek bir karar.
  /// KARAR 07.8 s2
  static const double cevirmeKaliteHedefi = 0.01;

  /// KALİTE HEDEFİ — oyuncunun her yuva için aradığı roll dilimi.
  ///
  /// En iyi %20'lik roll demek, ortalama BEŞ deneme demek. Düşme şansı bundan
  /// türüyor: "şans %1,37 olsun" denmiyor, "oyuncu her yuva için istediği
  /// rollü bulabilsin" deniyor.
  ///
  /// Farkı pratik: yuva sayısı, nesil süresi ya da öldürme hızı değiştiğinde
  /// şans kendiliğinden yeniden çözülüyor.
  /// KARAR 14.3 s2
  static const double kaliteHedefi = 0.20;

  /// DÜŞME GÜVENLİĞİ — hesaplanan ihtiyacın üstüne bırakılan pay.
  ///
  /// İhtiyacı tam karşılamak, medyan oyuncunun ancak yetişmesi demek — yani
  /// yarısının yetişememesi. Yarım kat fazlası, kötü şansın tamponu.
  /// KARAR 14.3 s2
  static const double dusmeGuvenligi = 1.5;

  /// PARÇALAMA ORANI — eşyanın maliyetinin kaçı malzeme olarak geri geliyor.
  ///
  /// Tamamını verseydi eşya farmı malzeme farmıyla eşitlenir, ganimet ayrı
  /// bir musluk olmaktan çıkardı. Altıda biri, eşyanın ikinci hayatını
  /// anlamlı kılacak kadar; yerine geçmeyecek kadar.
  /// KARAR 14.5 s1
  static const double parcalamaOrani = 0.15;

  /// Düşen eşyanın BİR ÜST rankta çıkma olasılığı — PRD ile.
  ///
  /// Heyecan verici olay. Bağımsız zarla bırakılsa bazı oyuncular saatlerce
  /// görmez; PRD seri kırıcı olarak devreye giriyor.
  /// KARAR 14.4 s1
  static const double ustRankSansi = 0.15;

  /// Düşen eşyanın BİR ALT rankta çıkma olasılığı — bağımsız zar.
  ///
  /// Hayal kırıklığı değil: parçalanacak malzeme. PRD uygulanmıyor çünkü sık
  /// gerçekleşiyor ve zaten kötü seri üretmiyor — üstelik varyansı azaltmak
  /// onu tahmin edilebilir yaparak sıkıcılaştırırdı.
  /// KARAR 14.4 s1
  static const double altRankSansi = 0.20;

  /// Boss'un GARANTİLİ düşürdüğü eşya sayısı.
  ///
  /// Şansa bırakılmıyor: iki saatte bir doğuyor ve grup gerektiriyor, yani
  /// boş çıkması iki saatin ve üç oyuncunun boşa gitmesi demek.
  /// KARAR 14.6 s1
  static const int bossEsyaSayisi = 3;

  // ══ ALAN 15 · KAZANÇ ══════════════════════════════════════════════════

  /// Nesil başına kaç TABAN eşya satılıyor.
  ///
  /// Dört, alan 14'ün ölçtüğü boşluk: bolluk ×1,50 iken ortalama dört yuva
  /// eksik kalıyor. Mağaza bir çözüm değil bir TAMPON — güç satarsa ganimet
  /// anlamını yitirir, hiçbir şey satmazsa şanssız oyuncu tıkanır.
  /// KARAR 15.2 s1
  static const int magazaEsyaSayisi = 4;

  /// Taban eşyanın rank farkı — bir ALT.
  ///
  /// Mağaza eşyası bilinçli olarak ikinci sınıf: bandın rankı değil altındaki,
  /// kalite rolü yok (hep taban), alt stat yok. En kötü drop'tan bile zayıf.
  /// Alan oyuncu oyunu kazanmıyor, yalnız boş yuvayla dolaşmıyor.
  /// KARAR 15.2 s1
  static const int tabanEsyaRankFarki = -1;

  /// Başlangıç kredisi KAÇ taban eşya eder.
  ///
  /// Başlangıç parası bir sayı değil bu oran: ilk bandın raf fiyatı × bu
  /// (`Hangar.startingCredits`). İki, çünkü başlangıç gemisinde takılı olan
  /// tek şey bir lazer. Bir eşyalık kredi yalnız "satın al" düğmesini
  /// öğretir ve oyuncuyu ilk alışverişinde sıfırda bırakır — kapı açılır ve
  /// aynı dakikada kapanır. İki eşyalık kredi ilk SEÇİMİ öğretir: ikinci
  /// namlu mu, ilk jeneratör mü — 08'in saldırı/dayanıklılık bölünmesinin
  /// oyuncu tarafındaki ilk hâli. Üç ve üstü hediye olurdu: nesil başına
  /// mağaza payı zaten [magazaEsyaSayisi] eşya ve raf bir zemin, bir kaynak
  /// değil (15.2); eşyanın asıl arzı ganimet döngüsünde (14).
  /// KARAR 15.8 s1
  static const int baslangicEsyaSayisi = 2;

  /// Envanter genişletmenin NOVA fiyatı — kalıcı.
  /// KARAR 15.3 s3
  static const int envanterNova = 2000;

  /// Kaç kademe envanter genişletilebiliyor.
  /// KARAR 15.3 s3
  static const int envanterKademe = 5;

  /// Bir DOLARIN kaç saatlik oyun satın aldığı.
  ///
  /// IAP kurunun tek girdisi: NOVA fiyatı buradan ve saatlik NOVA hızından
  /// çıkıyor. Daha yüksek bir kur paranın TAVANINI değiştirmiyor, yalnız
  /// oraya daha çabuk vardırıyor — tavanın kendisi güvenlik mekanizması.
  /// KARAR 15.5 s1
  static const double dolarSaatDegeri = 3.3;

  /// En büyük paketin bonus çarpanı.
  ///
  /// ×2'yi geçen bonuslar küçük paketleri anlamsızlaştırır ve oyuncuyu tek bir
  /// büyük alışverişe zorlar.
  /// KARAR 15.5 s1
  static const double paketBonusTavani = 1.60;

  /// Hedef ödeme oranı — oyuncuların kaçı ödüyor.
  /// KARAR 15.6 s1
  static const double odemeOrani = 0.03;

  /// Hedef ARPPU — ödeyen oyuncu başına ortalama dolar.
  /// KARAR 15.6 s1
  static const double hedefARPPU = 40.0;

  /// NOVA mağazası ganimet döngüsünün eşyasını satıyor mu — **sabit hayır.**
  ///
  /// Ganimet döngüsü oyunun çekirdeği; eşya satılırsa alan 14'ün bütün arz
  /// hesabı anlamsızlaşır. Kilit ganimetin eşyasını koruyor: alt statlı,
  /// bandın rankında, arz hesabına giren eşya. NOVA rafının üç TABAN
  /// tasarımı (15.7) bu kilidin dışında ve ayrı sayılıyor — alt statı yok,
  /// arz hesabına girmiyor, kredi rafının bir kademe üstünde duruyor.
  /// KARAR 15.1 s3 · KARAR 15.7 s1
  static const bool novaEsyaSatiyor = false;

  /// NOVA mağazası MALZEME satıyor mu — **sabit hayır.**
  ///
  /// Teknik olarak gereksiz: malzeme ve NOVA aynı hızda düşüyor (öldürme
  /// başına birer tane), yani biriyle diğerini almak zaten anlamsız. Yazılı
  /// durmasının sebebi ileriye dönük — biri malzeme düşme hızını
  /// değiştirdiğinde testin uyarması için.
  /// KARAR 15.1 s3
  static const bool novaMalzemeSatiyor = false;

  // ═══════════════════════════════════════════════════════════════════
  // 17 · Mermi
  // ═══════════════════════════════════════════════════════════════════

  /// MERMİ TABAN FİYATI c, kredi — fiyat(m) = c × m^k, MR-1 bedava.
  ///
  /// Ankraj: ×2 ile sürekli farm referans gelirin yaklaşık yüzde on beşi
  /// kadar gider (17.4). Tablo gerçek atış ritmiyle basıyor, ölçüm sapmayı
  /// aralık testiyle tutuyor.
  /// KARAR 17.4 s1
  static const double mermiTabanFiyati = 7.67;

  /// FİYAT ÜSSÜ k — iki ankrajın kesişimi: tavan çarpanın birim hasar
  /// başına bedeli ×2'ninkinin iki katı → k = 1 + ln 2 ÷ ln 3. Türetme testi
  /// [Turetilenler.mermiUsAnkraji] ile karşılaştırıyor.
  /// KARAR 17.4 s1
  static const double mermiFiyatUssu = 1.631;

  /// ÇARPAN TAVANI — MR-6. Üstü PvP'yi tek yaylıma indirir.
  /// KARAR 17.4 s1
  static const int mermiCarpanTavani = 6;

  /// SİFON ÇARPANI — yalnız kalkana; gövdeye sıfır (17.6).
  /// KARAR 17.6 s1
  static const int sifonCarpani = 3;

  // ══ ALAN 18 · ROKET ══════════════════════════════════════════════════

  /// Roket salvosunun aralığı, saniye (18.1).
  ///
  /// Lazerin 1,1 saniyesinin beş katından biraz fazla: roket bir ritim değil
  /// bir vuruş. Salvonun tabanı bu oranla büyüyor (kadans oranı), DPS payı
  /// bütçe payında kalıyor.
  /// KARAR 18.1 s1
  static const double roketAraligi = 6;

  /// RK-1 bedava ve sınırsız — 17.2'nin ikizi (18.3).
  /// KARAR 18.3 s1
  static const bool rk1Bedava = true;

  /// KİLİT: MR-1 bedava ve sınırsız — dengenin çapası. Bütün referans
  /// hesapları ×1 ile kuruldu; ücretli olsaydı hepsi kayardı.
  /// KARAR 17.2 s1
  static const bool mr1Bedava = true;

  /// KİLİT: NOVA mağazası mermi satmıyor — 15'in tavanı yerinde kalsın.
  /// KARAR 17.7 s1
  static const bool novaMermiSatiyor = false;

  ///
  /// Elle tutulan ikinci bir liste değil: her satır yukarıdaki `const`'a
  /// başvuruyor, yani bir girdiyi değiştirmek burayı da değiştiriyor. Bir
  /// girdiyi listeye eklemeyi unutmak MÜMKÜN ama zararsız — denetim eksik
  /// satırı değil, fazla sayıyı arıyor.
  static const List<TasarimGirdisi> hepsi = [
    TasarimGirdisi(
      alan: 1,
      ad: 'kritikSansiReferans',
      deger: kritikSansiReferans,
      gerekce: 'Dört yaylımda bir kritik.',
    ),
    TasarimGirdisi(
      alan: 1,
      ad: 'kritikCarpaniReferans',
      deger: kritikCarpaniReferans,
      gerekce: 'Ekranda okunması en kolay çarpan.',
    ),
    TasarimGirdisi(
      alan: 1,
      ad: 'zirhAzaltmaHedefi',
      deger: zirhAzaltmaHedefi,
      gerekce: 'Referansta %30 — hissedilir ama tekelci değil.',
    ),
    TasarimGirdisi(
      alan: 1,
      ad: 'siyirmaTavani',
      deger: siyirmaTavani,
      gerekce: 'Hasar asla sıfırlanmaz.',
    ),
    TasarimGirdisi(
      alan: 1,
      ad: 'siyirmaHedefiReferans',
      deger: siyirmaHedefiReferans,
      gerekce: 'Zırhın yarısı: kardeş ama baskın değil.',
    ),
    TasarimGirdisi(
      alan: 1,
      ad: 'pvpCarpani',
      deger: pvpCarpani,
      gerekce: 'Bugün etkisiz, kol duruyor.',
    ),
    TasarimGirdisi(
      alan: 1,
      ad: 'sonHasarTavani',
      deger: sonHasarTavani,
      gerekce: 'L5 zinciri ele geçiremez.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'kalkanCapasi',
      deger: kalkanCapasi,
      gerekce: 'Gövdenin %67\'si — kalkan ikinci havuz.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'hizCapasi',
      deger: hizCapasi,
      gerekce: 'Tempo belirliyor; kademeyle neredeyse artmıyor.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'zirhCapasi',
      deger: zirhCapasi,
      gerekce: '01\'in %30 azaltma hedefini sayıya çeviren referans.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'referansKacinma',
      deger: referansKacinma,
      gerekce: 'Aynı işi sıyırma eğrisi için yapıyor.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'referansJeneratorKalkan',
      deger: referansJeneratorKalkan,
      gerekce: 'Yarısı kalkan, yarısı hız — takas kararı.',
    ),
    TasarimGirdisi(
      alan: 5,
      ad: 'droidFiloTavani',
      deger: droidFiloTavani,
      gerekce: 'Filo gövdeden bağımsız; on, eski merdivenin tavanı.',
    ),
    TasarimGirdisi(
      alan: 5,
      ad: 'aktarimKatsayisi',
      deger: aktarimKatsayisi,
      gerekce: 'Sıfırda droid erir, birde droid yığmak tek build olur.',
    ),
    TasarimGirdisi(
      alan: 5,
      ad: 'formasyonTakasi',
      deger: formasyonTakasi,
      gerekce: 'Yirmi formasyon tek girdi: yön ayrı, miktar bir.',
    ),
    TasarimGirdisi(
      alan: 5,
      ad: 'argeAktarimAdimi',
      deger: argeAktarimAdimi,
      gerekce: 'Üç düğümlük dal, bir formasyon eğilimi kadar.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'tasarimNova',
      deger: tasarimNova,
      gerekce: 'Görünüş zaman kazandırmıyor: fiyatı türetilemez, ilan edilir.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'formasyonNova',
      deger: formasyonNova,
      gerekce: 'Formasyon geometri de taşıyor; tasarımın iki katı.',
    ),
    TasarimGirdisi(
      alan: 5,
      ad: 'droidYuvasi',
      deger: droidYuvasi,
      gerekce: 'Tek yuva seçim demek: hasar mı dayanıklılık mı.',
    ),
    TasarimGirdisi(
      alan: 5,
      ad: 'elitDroidYuvasi',
      deger: elitDroidYuvasi,
      gerekce: 'Elitin tek farkı: seçmek zorunda değil.',
    ),
    TasarimGirdisi(
      alan: 5,
      ad: 'droidAsinmaPayi',
      deger: droidAsinmaPayi,
      gerekce: 'On ölüm: bir süs değil, filoyu silen bir vergi de değil.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'referansAtisAraligi',
      deger: referansAtisAraligi,
      gerekce: 'Kurun ikinci ayağı: taban hasar → DPS.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'govdeKademeSayisi',
      deger: govdeKademeSayisi,
      gerekce: 'Sekiz gemi, sekiz bölge.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'yuvaArtisi',
      deger: yuvaArtisi,
      gerekce: 'Sanat kararı: kademe başına bir yuva; lazere değil.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'hizArtisi',
      deger: hizArtisi,
      gerekce: 'Hız tempo belirler; rank çarpanıyla büyüseydi savaş bozulurdu.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'lazerYuvaSayisi',
      deger: lazerYuvaSayisi,
      gerekce: 'Sanat kısıtı: çizimdeki kaide sayısı, sekiz tasarımda beş.',
    ),
    TasarimGirdisi(
      alan: 4,
      ad: 'jeneratorYuvaPayi',
      deger: jeneratorYuvaPayi,
      gerekce:
          'Bastion\'ın 4 · 2 dağılımı: kalan yuvaların üçte ikisi jeneratör.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'rankSayisi',
      deger: rankSayisi,
      gerekce:
          'Altı harf ailesi × üç basamak + Kırmızı ve Parlayan Pembe. '
          'Tepesi 1,442^19 ≈ 1.048×, iki yıllık hedefin vardığı yer.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'rankArtisi',
      deger: rankArtisi,
      gerekce: 'Ölçüldü: bugünkü beş çarpan zaten bu merdiveni izliyor.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'anaStatPayi',
      deger: anaStatPayi,
      gerekce: 'Rank çakışmasına pay bırakıyor: en dar boğaz birin üstünde.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'kaliteAltSiniri',
      deger: kaliteAltSiniri,
      gerekce: 'Kalite makası rank atlamasının altında.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'kaliteAltSiniriSS',
      deger: kaliteAltSiniriSS,
      gerekce: 'Üst rank sayı olarak değil güvenilirlik olarak da ayrışır.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'kaliteAltSiniriRenk',
      deger: kaliteAltSiniriRenk,
      gerekce: 'Kapak taşı en dar bant; paranın tavanı burada en küçük.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'garantiliAltStatSS',
      deger: garantiliAltStatSS,
      gerekce: 'Renk kalite güvencesi: bir alt stat bandın tepesinden.',
    ),
    TasarimGirdisi(
      alan: 6,
      ad: 'garantiliAltStatRenk',
      deger: garantiliAltStatRenk,
      gerekce: 'Kapak taşında iki alt stat mükemmel gelir.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'butceCapasi',
      deger: butceCapasi,
      gerekce: 'Bütün eşyalar buna göre türüyor.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'payGovde',
      deger: payGovde,
      gerekce: 'Gövde tek eşya ve taban havuzun tamamını taşıyor.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'payLazer',
      deger: payLazer,
      gerekce: 'Katsayı ölçeğinin çapası.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'payJenerator',
      deger: payJenerator,
      gerekce: 'Gövde ↔ eşya kolunun tuttuğu yer.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'payRoketatar',
      deger: payRoketatar,
      gerekce: 'Tek yuva: katkısı büyürse tek eşya oyunu belirler.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'payDroid',
      deger: payDroid,
      gerekce: 'Altıncı grup; droid DPS payı hedefiyle aynı büyüklükte.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'payCpu',
      deger: payCpu,
      gerekce: 'İki yuva, savunma kanalı.',
    ),
    TasarimGirdisi(
      alan: 8,
      ad: 'payBandi',
      deger: payBandi,
      gerekce:
          'Ölçülen pay ilan edilenden en çok bu kadar sapar; sapma yapısal, '
          'üç puan tutmadı.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'referansTTK',
      deger: referansTTK,
      gerekce: 'Kanallar arası kurun KENDİSİ: 1 DPS ≡ 30 EHP.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'brOlcegi',
      deger: brOlcegi,
      gerekce: 'Dengeye karışmıyor; sayıyı okunur aralığa taşıyor.',
    ),
    TasarimGirdisi(
      alan: 10,
      ad: 'ilkUnvanEsigi',
      deger: ilkUnvanEsigi,
      gerekce:
          'Merdivenin tabanı; referansın kanal gücü buraya oturtulur, K '
          'ondan çözülür.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'sistemTavani',
      deger: sistemTavani,
      gerekce: 'Sistem çarpımsal: sınırsız bırakılırsa baskın olur.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'sistemKatsayisiMenzil',
      deger: sistemKatsayisiMenzil,
      gerekce: 'Hem saldırıya hem kaçışa yarıyor.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'sistemKatsayisiHiz',
      deger: sistemKatsayisiHiz,
      gerekce: 'Yetişmek ve kaçmak.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'sistemKatsayisiItki',
      deger: sistemKatsayisiItki,
      gerekce: 'Yalnız kaçışa yarıyor; şarj sayısıyla sınırlı.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'droidDpsPayi',
      deger: droidDpsPayi,
      gerekce:
          'Referansta droidlerin saldırıya payı; taban hasar bundan türer.',
    ),
    TasarimGirdisi(
      alan: 9,
      ad: 'droidDayaniklilikKatsayisi',
      deger: droidDayaniklilikKatsayisi,
      gerekce: 'Geometrik ortalamada iki kez sayılmasın: çeyrek, bir değil.',
    ),
    TasarimGirdisi(
      alan: 10,
      ad: 'hedefSure',
      deger: hedefSure,
      gerekce: '1,5 sa/gün × 5 gün × 104 hafta.',
    ),
    TasarimGirdisi(
      alan: 10,
      ad: 'unvanSayisi',
      deger: unvanSayisi,
      gerekce: 'BR aralığı eşit ORANLARLA bölünüyor.',
    ),
    TasarimGirdisi(
      alan: 10,
      ad: 'gelirUssu',
      deger: gelirUssu,
      gerekce: 'α < 1: her nesil bir öncekinden uzun.',
    ),

    // ── Alan 11 · Haritalar ──────────────────────────────────────────
    TasarimGirdisi(
      alan: 11,
      ad: 'gorusYaricapi',
      deger: gorusYaricapi,
      gerekce: 'FİZİKSEL: 0,6 yakınlaştırmada ekran + kenar payı.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'dunyaEnBoyOrani',
      deger: dunyaEnBoyOrani,
      gerekce:
          'Alan kaç birim kare olduğunu söylüyor, hangi dikdörtgen olduğunu değil.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'bolgeBasinaHarita',
      deger: bolgeBasinaHarita,
      gerekce:
          'Üç tehdit biçimi: yalnız yaratık · yaratık + oyuncu · zamanlı tek hedef.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'girisPayi',
      deger: girisPayi,
      gerekce: 'İlk bandı yenebileceği ama derine inemeyeceği nokta.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'esZamanliOyuncu',
      deger: esZamanliOyuncu,
      gerekce: 'Harita boyutunun üç girdisinden biri; cevaplanabilir soru.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'gorusPaylasimi',
      deger: gorusPaylasimi,
      gerekce: '0,5: ikinci oyuncu görüş alanının yarısı kadar uzakta.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'gorusHedefi',
      deger: gorusHedefi,
      gerekce: 'Üçten az: hedef arıyor. Beşten çok: mayın tarlası.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'pvpNetPrim',
      deger: pvpNetPrim,
      gerekce: 'PvP\'den kaçınan yavaşlamalı, durmamalı.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'olumMaliyetiDk',
      deger: olumMaliyetiDk,
      gerekce: 'Dönüş + onarım. Kredi değil ZAMAN — prim saatlik oran.',
    ),
    TasarimGirdisi(
      alan: 11,
      ad: 'pvpOlumSikligi',
      deger: pvpOlumSikligi,
      gerekce: 'ÖLÇÜLECEK — playtest. Tepe tablodaki tek ölçüm bekleyen satır.',
    ),

    // ── Alan 12 · Düşman Kurgusu ─────────────────────────────────────
    TasarimGirdisi(
      alan: 12,
      ad: 'siradanOldurmeSuresi',
      deger: siradanOldurmeSuresi,
      gerekce: 'Sınıf bir orandır: öldürme süresi her bantta sabit.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'gucluOldurmeSuresi',
      deger: gucluOldurmeSuresi,
      gerekce: 'Beş kat — girmek bir karar.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'siradanDogusSuresi',
      deger: siradanDogusSuresi,
      gerekce: 'Çevrimin çoğu bu; ödül hesabının yarısı.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'gucluDogusSuresi',
      deger: gucluDogusSuresi,
      gerekce: 'İri hedefin sürekli durması onu sıradan yapardı.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'siradanHizOrani',
      deger: siradanHizOrani,
      gerekce: 'Kovalayabilir ama yetişemez.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'gucluHizOrani',
      deger: gucluHizOrani,
      gerekce: 'Hiç kovalayamaz — kaçmak her zaman mümkün.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'bossHizOrani',
      deger: bossHizOrani,
      gerekce: 'Yerinde duran hedef; grup ona gider.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'siradanMenzilOrani',
      deger: siradanMenzilOrani,
      gerekce: 'Menzil eşit olsaydı mesafe tutmanın anlamı kalmazdı.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'gucluMenzilOrani',
      deger: gucluMenzilOrani,
      gerekce: 'Daha yakın ama hâlâ oyuncunun altında.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'bossMenzilOrani',
      deger: bossMenzilOrani,
      gerekce: 'En yakın; yine de kaçış mümkün.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'kacisPenceresi',
      deger: kacisPenceresi,
      gerekce: 'Fark etme + itki + menzil dışına çıkma zincirinin tamamı.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'tehditSayisi',
      deger: tehditSayisi,
      gerekce: 'Tehdit tek yaratıktan değil, üçünü birden çekmekten.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'gucluRiskPrimi',
      deger: gucluRiskPrimi,
      gerekce: 'Saldırgan olmasının karşılığı; sıradanda prim yok.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'bossGrubu',
      deger: bossGrubu,
      gerekce: 'Boss bir grup hedefi.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'bossHedefSuresi',
      deger: bossHedefSuresi,
      gerekce: 'Üç oyuncu iki dakika.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'bossPrimi',
      deger: bossPrimi,
      gerekce: 'Harcanan oyuncu-saatin katı.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'bossGelirPayi',
      deger: bossGelirPayi,
      gerekce: 'Kaçırmak yavaşlatmalı, durdurmamalı.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'tabanSaatlikGelir',
      deger: tabanSaatlikGelir,
      gerekce: 'Birinci bandın kredi hedefi; ödül bunun bölünmesi.',
    ),
    TasarimGirdisi(
      alan: 12,
      ad: 'novaOdulu',
      deger: novaOdulu,
      gerekce: 'ÖLÇEKLENMEZ — NOVA gerçek parayla rekabet ediyor.',
    ),

    // ── Alan 07 · Güçlendirme ────────────────────────────────────────
    TasarimGirdisi(
      alan: 7,
      ad: 'maliyetHacmi',
      deger: maliyetHacmi,
      gerekce: 'c₀ — toplam sink. Eğrinin HACİM kolu.',
    ),
    TasarimGirdisi(
      alan: 7,
      ad: 'maliyetSekli',
      deger: maliyetSekli,
      gerekce: 'b — değer bozulmasını 44,5 kattan 12 kata indiriyor.',
    ),
    TasarimGirdisi(
      alan: 7,
      ad: 'sentezOrani',
      deger: sentezOrani,
      gerekce: 'Verim %48: fazla eşyaya değer, kestirme değil.',
    ),
    TasarimGirdisi(
      alan: 7,
      ad: 'basarisizlikSansi',
      deger: basarisizlikSansi,
      gerekce: 'KİLİT — kırılma, koruma satma kapısını açar.',
    ),

    // ── Alan 13 · Kaynak Akışı ───────────────────────────────────────
    TasarimGirdisi(
      alan: 13,
      ad: 'genelOlumSikligi',
      deger: genelOlumSikligi,
      gerekce: 'Onarım payı bundan türüyor; PvP sıklığıyla karıştırılmamalı.',
    ),
    TasarimGirdisi(
      alan: 13,
      ad: 'payArti',
      deger: payArti,
      gerekce: 'Ekonominin ana gideri — etkin %55.',
    ),
    TasarimGirdisi(
      alan: 13,
      ad: 'paySentez',
      deger: paySentez,
      gerekce: 'Fazla eşyayı ranka çeviren ikinci ayak.',
    ),
    TasarimGirdisi(
      alan: 13,
      ad: 'payMagaza',
      deger: payMagaza,
      gerekce: 'Yedek parça ve doğrudan alım.',
    ),
    TasarimGirdisi(
      alan: 13,
      ad: 'payBirikim',
      deger: payBirikim,
      gerekce: 'Gider değil TAMPON — sıfırsa tek kötü kararın telafisi yok.',
    ),

    // ── Alan 14 · Ganimet ────────────────────────────────────────────
    TasarimGirdisi(
      alan: 7,
      ad: 'cevirmeKaliteHedefi',
      deger: cevirmeKaliteHedefi,
      gerekce:
          'Mükemmel roll dilimi — ortalama yüz deneme. Eşya düşme oranını '
          'çözen kaliteHedefi\'nden AYRI: birleştirmek düşüşü yirmi kat '
          'artırırdı.',
    ),
    TasarimGirdisi(
      alan: 14,
      ad: 'kaliteHedefi',
      deger: kaliteHedefi,
      gerekce: 'En iyi %20 roll = ortalama beş deneme; şans buradan türüyor.',
    ),
    TasarimGirdisi(
      alan: 14,
      ad: 'dusmeGuvenligi',
      deger: dusmeGuvenligi,
      gerekce: 'Tam karşılamak medyan oyuncunun ancak yetişmesi demek.',
    ),
    TasarimGirdisi(
      alan: 14,
      ad: 'parcalamaOrani',
      deger: parcalamaOrani,
      gerekce: 'Tamamı verilseydi eşya farmı malzeme farmının yerine geçerdi.',
    ),
    TasarimGirdisi(
      alan: 14,
      ad: 'ustRankSansi',
      deger: ustRankSansi,
      gerekce: 'Olay — PRD ile seri kırılıyor.',
    ),
    TasarimGirdisi(
      alan: 14,
      ad: 'altRankSansi',
      deger: altRankSansi,
      gerekce: 'Hayal kırıklığı değil, parçalanacak malzeme.',
    ),
    TasarimGirdisi(
      alan: 14,
      ad: 'bossEsyaSayisi',
      deger: bossEsyaSayisi,
      gerekce: 'İki saat bekleyip grup toplamak boşa çıkamaz.',
    ),

    // ── Alan 15 · Kazanç ─────────────────────────────────────────────
    TasarimGirdisi(
      alan: 15,
      ad: 'magazaEsyaSayisi',
      deger: magazaEsyaSayisi,
      gerekce: '14\'ün ölçtüğü boşluk: ortalama dört yuva eksik kalıyor.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'tabanEsyaRankFarki',
      deger: tabanEsyaRankFarki,
      gerekce: 'Mağaza eşyası en kötü drop\'tan bile zayıf olmalı.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'baslangicEsyaSayisi',
      deger: baslangicEsyaSayisi,
      gerekce:
          'Başlangıç kredisi raftan türüyor: bir eşya yalnız düğmeyi, iki '
          'eşya ilk seçimi öğretiyor.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'envanterNova',
      deger: envanterNova,
      gerekce: 'Kalıcı genişletme; zaman değil alan satılıyor.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'envanterKademe',
      deger: envanterKademe,
      gerekce: 'Beş kademe — sonrası envanteri anlamsızlaştırır.',
    ),
    TasarimGirdisi(
      alan: 17,
      ad: 'mermiTabanFiyati',
      deger: mermiTabanFiyati,
      gerekce: 'Ankraj: ×2 ile sürekli farm referans gelirin ~%15\'i.',
    ),
    TasarimGirdisi(
      alan: 17,
      ad: 'mermiFiyatUssu',
      deger: mermiFiyatUssu,
      gerekce: '×6 birim hasar bedeli ×2\'nin iki katı: 1 + ln2 ÷ ln3.',
    ),
    TasarimGirdisi(
      alan: 17,
      ad: 'mermiCarpanTavani',
      deger: mermiCarpanTavani,
      gerekce: 'MR-6; üstü PvP\'yi tek yaylıma indirir.',
    ),
    TasarimGirdisi(
      alan: 17,
      ad: 'sifonCarpani',
      deger: sifonCarpani,
      gerekce: 'Yalnız kalkana; MR-3 fiyatına yarım hedef.',
    ),
    TasarimGirdisi(
      alan: 18,
      ad: 'roketAraligi',
      deger: roketAraligi,
      gerekce: 'Roket bir vuruş, ritim değil; salvo kadans oranıyla büyür.',
    ),

    TasarimGirdisi(
      alan: 15,
      ad: 'dolarSaatDegeri',
      deger: dolarSaatDegeri,
      gerekce: 'IAP kurunun tek girdisi; tavanı değiştirmiyor.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'paketBonusTavani',
      deger: paketBonusTavani,
      gerekce: '×2 üstü küçük paketleri anlamsızlaştırır.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'odemeOrani',
      deger: odemeOrani,
      gerekce: 'Hedef — ARPU bununla ARPPU\'nun çarpımı.',
    ),
    TasarimGirdisi(
      alan: 15,
      ad: 'hedefARPPU',
      deger: hedefARPPU,
      gerekce: 'Ödeyen oyuncu başına hedef.',
    ),
  ];

  /// [alan] numaralı alanın tepe tabloya koyduğu satırlar.
  static Iterable<TasarimGirdisi> alanin(int alan) =>
      hepsi.where((g) => g.alan == alan);
}

/// Tepe tablodaki BİR satır.
///
/// Gerekçe alanı süs değil: bir sayının neden o değer olduğu yazılmadığında,
/// bir sonraki denge turunda gerekçe sayıya uydurulmaya başlar.
class TasarimGirdisi {
  const TasarimGirdisi({
    required this.alan,
    required this.ad,
    required this.deger,
    required this.gerekce,
  });

  /// Hangi alanın katkısı — [TasarimHaritasi] numarası.
  final int alan;

  /// Koddaki `const` adı.
  final String ad;

  /// Değer — `num`, `double` DEĞİL.
  ///
  /// Girdilerin çoğu oran ya da çarpan ama hepsi değil: gövde kademesi sayısı
  /// ve kademe başına yuva artışı TAM SAYI, ve onları `double` yapmak
  /// "8,0 kademe" gibi anlamsız bir tip üretirdi. Tepe tablo tasarım
  /// kararlarını taşıyor, hepsinin aynı tipte olması gerekmiyor.
  final num deger;

  /// Neden bu değer.
  final String gerekce;

  @override
  String toString() => '$ad = $deger';
}

/// Seviye artışlarının BİRLEŞME biçimi — alan 07'nin kategorik kararı.
///
/// Aradaki fark küçük görünüyor ama +15'te 2,50× ile 4,17× arasında: ikincisi
/// alan 06'nın "toplam güç farkı %22 bandında kalır" hesabının dayanağı olan
/// tavanı deliyor.
enum ArtiKazancBicimi {
  /// Artışlar TOPLANIR: `1 + Σ adım`. Seçilen biçim.
  toplamsal,

  /// Artışlar ÇARPILIR: `Π (1 + adım)`. Kodun eski davranışı.
  bilesik,
}
