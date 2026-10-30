---
alan: 5
ad: Sağlayıcılar
katman: büyüme
tur: kural
surum: 1.8
kaynak: https://claude.ai/code/artifact/21967d4b-4fa6-46e3-ad0e-6c31afddaf2b
---

# 05 · Sağlayıcılar

Bir statı kim verebilir, hangi kapsama yazar, ve kapsamlar arasında ne kadar sızıntı olur. Bir sağlayıcı yalnız kendi kapsamına yazabilir. Kapsamlar arası tek geçiş yolu aktarım katsayısıdır; başka her yol bir hatadır ve fark edilmesi aylar sürer.

Bağımlılık: [02 kayıt ve kapsam](02-stat-kutuphanesi.md) · [04 yuva haritası](04-gemi-ve-yuvalar.md). Bu belgeye bağlı: 06 · 08 · 09 · 10.

Sayı tablosu yok: eski Aktarım Tablosu baştan sona droid modeliydi ve sayıları 09'un tablosuna gitti. Tepe tabloya üç girdi: `aktarimKatsayisi = 0,3`, `formasyonTakasi = 0,1` ve `droidAsinmaPayi = 10`; droid geldi, σ onunla geldi, dayanıklılık en son.

Sürüm 1.8: droidin kullanabildiği stat kaydın kapsamıyla belirlendi (05.4 s5, 02.7 s2): `kalkan` droid kapsamı aldı ve jeneratörün kalkanı droidin tek havuzuna biniyor; droidin okumadığı beş alt stat droid kapsamına hiç yazılmıyor. Kuralın izin verdiği eşya ile kaydın tanıdığı kapsam ayrışınca stat çözümü fırlatıyor, sunucu her girişte ölüyordu. Sürüm 1.7: ArGe kodda (05.7 s2) ve güç vermiyor: iki dal σ'yı zıt yönlere itiyor, üçüncü dalın ucu izin açıyor; puan seviyeden, sıfırlama bedava. Sürüm 1.6: droid bir TAŞIYICI oldu (05.4 s4, 05.5 s3): standart droidde bir, elitte iki yuva; içine lazer ya da jeneratör giriyor; filo payı gövde ile donanım arasında bölünüyor (bölüşüm türetilen) ve yaylım artık çapadan değil takılandan geliyor. İki girdi, bir türetilen. Sürüm 1.5: droid ateş etmiyor (05.1) ve çeşit ile tasarım ayrıldı (05.8 s2): iki satın alınabilir droid (Delta kredi, Hilal NOVA), on tasarım, sekizi merdivenden. Sürüm 1.4: droidin dayanıklılığı kodda (05.10): can değil sayaç, ana geminin ölümüyle aşınıyor, sıfırda droid yok oluyor, NOVA ile onarılıyor. Bir girdi (`droidAsinmaPayi`) ve dört türetilen; borç defteri B17 kapandı. Sürüm 1.3: droid filoya taşındı (04.10 s3): yuva → kapsam eşlemesinde droid yuvası filo yuvası, taban ve havuz tam filoya bölünüyor. Sürüm 1.2: droid ve formasyon kodda: üç sağlayıcı tipi, kayıt, yuva → kapsam eşlemesi, σ ve iki yeni karar (05.8 droid seviyesi, 05.9 formasyon). Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. Yedi karardan ikisi kodda; kalanı droid, ArGe ve set sistemleriyle birlikte gelecek.

## 05.1 · İki sağlayıcı tipi, davranış ayrılmış
Durum: kodda · s1 · SaglayiciTipi; değiştirici eşya, varlık DroidGrubu, davranış Formasyon

**Değiştirici** değer enjekte eder: stat vektörüne sayı ekler, katmanlara toplanır, biter. Eşya, ArGe, pasif skill, set bonusu. **Varlık** kendi vektörüne sahiptir: kendi statları, kendi canı, kendi hasar zinciri; ayrı zincirden geçer, σ ile bağlanır. Droid. **Davranış** ayrılmış: diğer ikisinin nasıl çalıştığını değiştirir, formasyon geldiğinde açılır.

Tip, motorun o kaynağı nasıl işleyeceğini tek başına belirliyor. Ayrım kritik çünkü ikisi aynı matematikten geçemez: bir modül bir sayı verir; bir droid ölebilir, dolayısıyla katkısı olasılıksaldır ve ayrı bir zincirden geçmek zorundadır. Kodda üçü de var: eşya değiştirici, droid grubu varlık (kendi zinciri, kendi havuzu, σ ile bağlı), formasyon davranış. Droid grubu tek tek değil toplu çözülüyor: droid kapsamı tek vektör ve grup, droid sayısı kadar gövdeli tek bir varlık gibi vuruyor. Grubun ayrı bir ATIŞI yok ve ekranda ayrı mermisi de yok: hasar geminin vuruşuna biniyor, tek olay ve tek sayı. Bir süre filo başına bir mermi çiziliyordu ve yanlıştı — ekranda iki ateş kaynağı görünürken inen tek bir hasar vardı. Droid dövüşte ölmüyor ve ayakta kalma bir; ama kalıcı da değil — sahibinin ölümüyle aşınıyor ve sayacı bitince kayboluyor (05.10).

## 05.2 · Sağlayıcı kaydı
Durum: kodda · s1 · SaglayiciKaydi, Saglayici.hepsi

Kayıt: kimlik, tip, kapsam, kaynak; statlar kayıttan değil eşyadan gelir. Stat kaydının (alan 02) kardeşi ve aynı veri odaklı mantık: motor sağlayıcı isimlerini bilmez, yalnız kaydı okur. Kodda üç kayıt: yuvadaki eşya, droid, formasyon. Yeni bir ArGe düğümü ya da set bonusu eklemek motorun hiçbir yerini değiştirmez. Kaynak alanı denge için: "atış hızının %40'ı ArGe'den geliyor" cümlesi ancak bu alanla kurulabilir ve alan 16 tam olarak bunu ölçüyor.

## 05.3 · Kapsam kuralları ve sızıntı yasağı
Durum: kodda · s1 · LoadoutResolver.vectorOf, StatVector.key

Hiçbir sağlayıcı kendi kapsamı dışına yazmaz. Bu alanın bir numaralı hatası sızıntı: droid'e takılan "%15 hasar" çipinin geminin de hasarını artırması, ya da geminin bonusunun droid sayısıyla çarpılıp patlaması. Kötülüğü fark edilmesinin uzun sürmesi; sonucu yalnız "droid build'i çok güçlü" gibi bulanık bir şikâyet olarak görünür.

Kapsam anahtarın parçası olduğu için (02.3) sızıntı testi tek bir denetimle bütün sağlayıcıları korur: her sağlayıcının ürettiği anahtarların kapsam eki, kaydındaki kapsamla aynı mı. Bugün tek sağlayıcı yuvadaki eşya ve tek kapsam gemi; çözücü bütün eşya statlarını o kapsama yazıyor.

## 05.4 · Yuva → kapsam eşlemesi; droid bir TAŞIYICI
Durum: kodda · s5 · Saglayici.kapsamOf, Saglayici.droidDonanimTipleri, Catalogue.droidYuvaSayisi, HangarRules.droideTak, ItemBudget.droidDonanimKatsayisi, LoadoutResolver.vectorOf

Statını hangi kapsama yazacağını eşya değil yuva belirler: gemi yuvasındaki eşya gemi kapsamına, filodaki droid droid kapsamına. Böylece tek bir eşya listesi iki yeri birden besler ve çift sayım riski kalmaz, çünkü bir eşya aynı anda iki yerde olamaz. Droid yuvası gövdede değil filoda (04.10) ve yalnız droid eşyası alır. Ama droidin KENDİ yuvası var: standart droidde `droidYuvasi = 1`, elit droidde `elitDroidYuvasi = 2`, ve içine yalnız lazer ya da kalkan jeneratörü giriyor. Elit olmanın tek anlamı bu — rankı ve stat bütçesi kredi droidiyle aynı merdivenden geliyor, farkı kaç şey taşıdığı.

Bu, 1.x'te bilerek reddedilen fikrin geri gelmesi ve reddin gerekçesi hâlâ geçerli: lazerin taban hasarı olduğu gibi droide binseydi on droid geminin yaylımını ikiye katlar, saldırı payı hedefi (09.6) anlamsızlaşırdı. Cevap yasak değil AĞIRLIK: droid yuvasındaki eşya filo payının donanıma ayrılan kısmıyla ölçülüyor, yani aynı lazer gemide başka, droidde başka değer taşıyor. O pay elle konmuyor, ÇÖZÜLÜYOR: `droidDonanimPayi = %26,9`, tam donanımlı standart filonun yaylımı geminin lazer yaylımının `droidDpsPayi` katı olsun diye. Yarı yarıya bölünseydi ölçülen pay %27,9 çıkardı, ilan %15. Bu 08.2'nin kuralının doğrudan sonucu, istisnası değil: katsayı yuvadan gelir, eşyadan değil.

Droidin TEK havuzu var ve kalkan da oraya biniyor: droid havuzu zaten "gemi havuzunun (gövde artı kalkan)" payı olarak ölçülüyor, dolayısıyla jeneratörün kalkanı gövde canıyla aynı sayıya ekleniyor — droide ayrı bir kalkan havuzu açmak ölçülen payı ikiye bölerdi. Droidin KULLANAMADIĞI stat ise droid kapsamına hiç yazılmıyor: `hiz`, `kacinma`, `kalkan_yenilenmesi`, `son_azaltma` ve `son_hasar` droide giren eşyaların alt stat havuzunda var ama droid grubunun karşılığı yok, ve yazılmayan bir stat okunmayan bir stattan dürüst. Yetkili kaydın `kapsam` alanı (02.3): droid kapsamı tanımayan stat droidde yoktur. Bu kural boşluğu pahalıya patladı — kural jeneratörü droide sokmaya izin verirken kayıt kalkanı gemiye hapsettiği için stat çözümü fırlatıyor, sunucu her `hello`'da ölüyordu; hiçbir test takmanın ARDINDAN çözmediği için de görülmemişti.

Üçüncü bir tip yok ve olmamalı: CPU droide takılsaydı fayda statları σ'dan geçip gemiye sızardı; roketatar tek yuva (04.11) ve gemiye ait. Droidin içindeki eşya droid kapsamına yazıyor, yani σ'nın öbür tarafında kalıyor. Bir istisna roketatar (18.1): yuvanın ana statı roket kapsamına, alt statları gemiye; roket geminin ikinci silahı, tabanı ayrı, bonusları ortak.

## 05.5 · Aktarım katsayısı σ ve biçimi
Durum: kodda · s3 · TasarimGirdileri.aktarimKatsayisi, ReferansCozumu.droidHavuzu, LoadoutResolver.droidGrubuOf

Droid'in hasarı geminin çarpanlarından ne kadar pay almalı? İki uç da yanlış. Hiç pay almazsa droid düz bir toplamdır; gemi çarpanları büyüdükçe payı erir ve geç oyunda bütün droid statları ölür. Tam pay alırsa geminin her çarpanı droid sayısıyla çarpılır; droid yığmak tek doğru build olur.

Biçim: varlığın etkin çarpanı = 1 + σ · (sahibin çarpanı − 1). Ölçüldü: σ droid'in bugünkü payını değil, payın zamanla ayakta kalıp kalmadığını belirliyor. Gemi çarpanı 1,25'ten 8,0'a çıktığında droid payı σ = 0'da %14'ten %2,5'e düşüyor, σ = 1'de sabit kalıyor. Değer `aktarimKatsayisi = 0,3`; sağlıklı bantın ortası. Droid DPS payı hedefi ve havuz katsayısı 09.6'da. **Droidin yaylımı artık türetilen bir çapa değil (05.4 s4):** boş droid vurmuyor, lazer takılmış droid takılan lazerin yaylımını taşıyor — filo payının donanıma ayrılan kısmıyla ölçülmüş olarak. Eskiden bir çapa vardı (`droidTabanHasari`) ve donanım yokken de vuruyordu; artık filo ne taşıyorsa onu veriyor. `droidDpsPayi` bir türetme kaynağı olmaktan çıkıp ÖLÇÜM HEDEFİ oldu: 16 tam donanımlı filonun payını ölçüyor, 08 de bütçeyi ona göre bölüyor. Havuzu da aynı paydan: droid grubunun havuzu referansta gemi havuzunun (gövde artı kalkan) `droidDpsPayi = 0,15` kadarı, filoya bölünmüş. Ayrı bir havuz payı ilan edilmiyor; tek sayı iki kanalı birden taşıyor ve ayrı bir pay istenirse tek satır değişir. Havuz ile DAYANIKLILIK ayrı iki şey ve karıştırılmamalı: havuz dövüşteki soğurma, dayanıklılık droidin ömrü (05.10). Rank ve artı çarpanı droid eşyasından geliyor, çapa türetilen. Formasyon geldi ve σ'yı iter (05.9): eğilimli formasyon σ'yı bir yöne, droid havuzunu öteki yöne.

## 05.6 · Unvan stat vermez
Durum: kodda · s1 · CombatGlossary.unvanEsigi, unvan yalnız BR'den okunur

Unvan doğal bir sağlayıcı adayı ama vermiyor, sebebi bir geri besleme döngüsü: statlar → BR → unvan eşiği → unvan statı → statlar. Döngü ıraksamaz ama BR'yi kendine referans veren bir ölçü aleti hâline getirir; ve BR bu haritada üç alanın terazisi: merdiven (10), harita giriş eşiği (11), denge denetimi (16). Unvan güç vermez; erişim ve görünüm verir: harita kapıları, mağaza kademeleri, isim rengi. Alternatif, unvan statı verip BR'den çıkarmak, iki ayrı BR tanımı üretir ve iki tanım bir süre sonra iki farklı sayı demektir.

## 05.7 · ArGe yeni stat icat etmez; güç değil YÖN veriyor
Durum: kodda · s2 · ArGe, ArGeDugumu, ArGeIzni, HangarRules.argeAl, HangarRules.argeSifirla, ArGe.filoTavani, Hangar.filoTavani, LoadoutResolver.droidGrubuOf; ekran ArGeKarti, girişi UnvanKarti

ArGe ve pasif skiller saf değiştirici: varlığı yok, davranışı yok, yalnız değer veriyorlar. Tavizsiz kural: her düğüm kütüphanede zaten var olan bir statı verir. ArGe'ye özel bir stat o statı denetimin dışına çıkarır ve denetim dışı her stat ileride ölü ya da baskın çıkar.

Kodlanan ağaç bu kuralı bir adım ileri götürüyor ve **ham güç hiç vermiyor**. İki şey yapıyor. KAPSAM YÖNLENDİRME: filo dalı σ'yı `argeAktarimAdimi = 0,033` kadar yukarı, gemi dalı aynı kadar aşağı itiyor; toplam güç değişmiyor, yeri değişiyor (05.5). Adım formasyon takasının üçte biri — üç düğümlük bir dal, bir formasyon eğilimi kadar. EŞİK AÇICI: dalın sonundaki düğüm bir izin veriyor, sayı değil — filo dalı bir droid yuvası daha (04.10'un tavanı bir artıyor), gemi dalı ikinci donatım profili.

Ham güç bilerek dışarıda. Bir düğüm "%5 hasar" verseydi 08'in bütçesi yeniden bölünmek zorunda kalırdı: ArGe yedinci bir grup olur ve altı grubun payı elle düşürülürdü. Güç-nötr bir ağaç bu hesabı hiç açmıyor ve ArGe'yi olması gereken şey yapıyor: ne kadar değil, NEREYE.

Puan seviyeden, seviye başına bir (10.1). Ayrı bir para birimi ya da ayrı bir sayaç ikinci bir ilerleme kanalı açardı. Dallar ZİNCİR: her düğüm bir öncekini istiyor, yani oyuncu bir dala yatırım yapmayı seçiyor; serbest seçimde herkes üç dalın en ucuzlarını alır ve ağaç bir alışveriş listesine döner. Sıfırlama bedava ve sınırsız; pahalı sıfırlama yanlış yatırımı kalıcı ölü stata çevirir.

## 05.8 · Droid seviyesi altı kademe, çeşit iki, tasarım on
Durum: kodda · s2 · DroidSeviyesi.of, DroidModeli, Catalogue.dr1 (Delta) ve Catalogue.dr5 (Hilal), DroidArt

Droidin ayrı bir XP'si yok: droid bir eşya (06.3; filo en çok on, gövdeden bağımsız) ve seviyesi eşyasının artı seviyesi (07). Altı görsel kademe güçlenme adımlarından türüyor: +0 birinci, her üç seviyede bir kademe, +15 altıncı. Kademe çizimi seçiyor, metal çekirdekten tamamlanmış droide; güç artı çarpanından geliyor, kademeden değil. Eski merdivenin ayrı XP sayacı ve düz modül katkısı buraya taşınmadı: ikinci bir ilerleme sayacı 13'ün musluğunu ikinci kez tanımlamak olurdu, düz katkı ise bütçenin dışında elle sayı.

**Çeşit İKİ, tasarım ON ve ikisi ayrı eksen.** Satın alınabilir iki droid var: Delta krediyle, kredi rafının droidi; Hilal NOVA rafında, bir kademe üstte (15.1'in "eşya satılamaz" yasağı kredi rafını korur, NOVA rafı zaten lazerde ve jeneratörde var). Dört model (Vane, Corona, Taurus, Jove) kaldırıldı: dördü hem çeşit hem tasarım olmaya çalışıyordu ve ikisi de eksik kalıyordu — dört çeşit ekonomiye fazla, dört tasarım göze az.

Kalan sekiz tasarım MERDİVENDEN gelen droidlerin görünüşü: rank tasarımı seçiyor, aynı rank hep aynı droidi veriyor. Böylece rank atlayan oyuncunun filosu da değişiyor ve tasarımlar ölü kalmıyor. Tasarımı oyuncunun seçmesi (deri sistemi) bu belgenin kararı değil; istenirse örneğe bir alan ve bir edinme kuralı gerekir (borç defteri B24).

## 05.9 · Formasyon: tek aktif, imzalı takas
Durum: kodda · s1 · Formasyon, Hangar.formasyonId, HangarRules.formasyonSec

Formasyon droid grubunun davranışı (05.1) ve aynı anda yalnız biri aktif. Etkisi imzalı bir takas: saldırı eğilimli formasyon aktarım katsayısını `formasyonTakasi = 0,1` kadar yukarı, droid havuzunu aynı oranda aşağı iter; savunma eğilimli tersini yapar; denge eğilimli dokunmaz. Yirmi formasyon, tek girdi: her formasyona ayrı yüzdeler yazmak tepe tabloya kırk sayı koymak olurdu ve kırk sayı kırk ayar kolu demek. Formasyonlar birbirinden geometriyle ve eğilimle ayrılıyor, sayıyla değil; geometri sanatın, adları eski merdivenden. Seçim savaş çubuğunda, dövüşün ortasında, bedava ve her an değişir; hangarda seçici yok, aynı karar iki yerde verilmez. Bugün eşya kapasitesine etkisi yok; ölçülüp bandın dışına çıkarsa takas ilk düzeltilecek yer.

## 05.10 · Droidin canı yok, dayanıklılığı var
Durum: kodda · s1 · ItemInstance.dayaniklilik, Hangar.filoyuAsindir, HangarRules.droidOnar, Gateway._droidleriAsindir

Droid dövüşte hedef alınmıyor: canı, kalkanı, ölüm anı yok. Yerine bir sayaç. Dayanıklılık yüzde başlıyor, ANA GEMİ her öldüğünde `droidAsinmaPayi = 10` puan iniyor, sıfıra inince droid yok oluyor ve yenisi gerekiyor. `droidOmruOlum = 10` ölüm; ölçülen ölüm sıklığında (13.3) `droidOmruSaat = 10` saat.

Can yerine sayaç, üç sebeple. Birincisi ölçü: dövüşte ölebilen droid, 09.6'nın ayakta kalma katsayısını rastgele bir değişkene çevirir ve savaş puanı artık geminin sürdürülebilir gücünü değil son dövüşünün şansını ölçer. İkincisi kayıp bir KARAR doğurmalı — onar mı, yenisini mi al — ve dövüşün ortasında verilen bir karar değil; sayaç kaybı hangara taşıyor. Üçüncüsü tel: hedef alınabilen droid demek her droid için konum, can ve hasar olayı demek, yani filo başına on kat trafik ve on kat isabet hesabı; taşınan bilgi bir bayt.

Sayaç GÜCÜ değiştirmiyor: son puanındaki droid de tam vuruyor. Azalan güç ikinci bir eğri olurdu, üstelik yanlış yönde — ölmeye başlayan oyuncunun filosu zayıflayınca daha da çok ölür. Sayaç yalnız "ne zaman biteceğim" diyor.

Yalnız FİLODAKİ droid aşınıyor; hangarda bekleyen yedek yıpranmıyor, çünkü o dövüşte değildi. Aşınma ölüm ANINDAN, hasardan değil: kaynak tamir bedeliyle aynı yer (11.6), ve tamir bedelinden ayrı bir geçişte — parası bitmiş oyuncunun droidleri ölümsüz olmasın.

Sayaç NOVA ile tam dolduruluyor ([HangarRules.droidOnar]); fiyat bu belgenin değil 15.3'ün kuralından ve orada türetiliyor — kısaca: onarılmayan droid kaybediliyor, yerine geleni beklemek ve artılarını yeniden basmak ne kadar sürüyorsa o kadar. Kısmi onarım yok, eksik puanın tamamı tek işlemde kapanıyor: parça parça onarım aynı toplamı ödetip oyuncuya hep aynı cevabı verdiği bir karar yaratırdı. Onarım LÜKS: hiç NOVA harcamayan oyuncu filosunu ganimetle döndürür ve yalnız artılarını kaybeder.

## Sınır

Sahiplenmediği: bir sağlayıcının ne kadar verdiği → 08 · eşyanın şeması → 06 · ArGe düğüm sırası ve açılışı → 10 · ArGe maliyetleri → 13 · unvanın ne açtığı → 10 ve 11 · BR formülü → 09 · NOVA fiyat kuralı → 15.3 · droidin düşme şansı → 14.3 · ölüm sıklığı ve tamir bedeli → 13.3 ve 11.6.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Hiçbir sağlayıcı kendi kapsamı dışına yazmıyor | Sızıntı; tek testle yakalanabilir olan. |
| Kapsamlar arası tek geçiş σ'dan | İkinci bir geçiş yolu açılmış; çift sayım kapısı. |
| Eşyanın kapsamı takıldığı yuvadan geliyor | Eşya kendi kapsamını dayatıyor. |
| Droide yalnız lazer ve jeneratör giriyor | CPU'nun fayda statları σ'dan gemiye sızıyor. |
| Droiddeki eşya filo payıyla ölçülüyor | On droid geminin yaylımını katlıyor; 09.6'nın payı anlamsız. |
| Her sağlayıcının verdiği stat kütüphanede var | Yabancı anahtar ihlali. |
| Unvan hiçbir stat vermiyor | Geri besleme döngüsü açılmış; BR kendine referans veriyor. |
| ArGe HAM GÜÇ vermiyor | Ağaç yedinci bütçe grubu olmuş; 08'in payları elle düşürülmeli. |
| ArGe sıfırlaması bedava | Yanlış yatırım kalıcı ölü stat olmuş. |
| 0 < σ < 1 | Uca gidilmiş: droid ya dekorasyon ya zorunlu build. |
| Dayanıklılık gücü değiştirmiyor | İkinci bir eğri açılmış; ölen oyuncu daha da zayıflıyor. |
| Yalnız filodaki droid aşınıyor | Hangardaki yedek de eriyor; depo bir ceza kutusu olmuş. |
| Sıfırlanan droid envanterden siliniyor | Ölü droid uçuyor; filo sayısı yalan söylüyor. |
| Onarım fiyatı yerine konma süresinden | NOVA droidi satıyor, beklemeyi değil (15.1). |
