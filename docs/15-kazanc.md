---
alan: 15
ad: Kazanç
katman: ekonomi
tur: kural
surum: 1.3
tablo: 15-kazanc-tablosu.md
kaynak: https://claude.ai/code/artifact/02f213be-9a28-4da2-8380-42e8b14d78e1
---

# 15 · Kazanç

İki mağaza, bir yasak, ve paranın satın alabileceği en büyük avantajın ölçüsü. Başlangıç sorusu tasarımın ilk gününden beri açıktı: mağazada ne satacağız? Cevabı ancak on dört alan boyunca ne satılamayacağı tek tek belirlendikten sonra verilebiliyor.

Kullandığı: [06](06-esya-kurgusu.md) kalite bantları · [07](07-guclendirme.md) çevirme kuralı · [12](12-dusman-kurgusu.md) NOVA musluğu · [13](13-kaynak-akisi.md) mağaza payı · [14](14-ganimet.md) eşya bolluğu. Sayı tablosu: [15 · Kazanç Tablosu](15-kazanc-tablosu.md).

Sürüm 1.3: başlangıç kredisi elle yazılmış bir sayı olmaktan çıktı ve rafın fiyatından türüyor (15.8); borç defteri B21 kapandı. Sürüm 1.2: NOVA çevirme fiyatı sabit 150'den çıkıp çevirici bedelinden türüyor; çevirme lüks sayıldı ve gider bandı zorunlu kalemlere daraltıldı (15.3). Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. 1.0'ın "çevirme katlanan kredi maliyetini atlıyor" cümlesi düştü: çevirme artık kredi almıyor ve katlanmıyor (07.8); NOVA çevirmesi katlanmayan tek sabit fiyat olarak kalıyor.

## 15.1 · Önce ne satılamayacağı
Durum: kodda · s3 · Kazanc.satilabilir, novaEsyaSatiyor ve novaMalzemeSatiyor kilitleri

| Satılamaz | Neden | Kaynak |
|---|---|---|
| Eşya (ganimet döngüsünden) | Ganimet döngüsü oyunun çekirdeği; satılırsa 14'ün arz hesabı anlamsızlaşır. Tek istisna NOVA rafındaki üç TABAN tasarım (15.7): alt statsız, bir kademe üstte, ganimetle rekabet etmiyor. | 14 · 15.7 |
| Malzeme | Malzeme ve NOVA aynı hızda düşüyor, öldürme başına birer; biriyle diğerini almak yapısal olarak anlamsız. | 14 |
| Rank · artı · gövde | Güç merdiveni zamanla kazanılıyor; satılırsa takvim çöker. | 10 |
| Harita erişimi | Kapı BR ile açılıyor, parayla değil. | 11 |
| Kredi | NOVA ↔ kredi çevirmesi kilitli; kur bantla kayıyor. | 13 |
| Görünüş | SATILIR (15.9): tasarım ve formasyon güç değil, savaş puanına dokunmuyor. | 15.9 |
| Mermi (NOVA ile) | Kilit 17'de: mermi krediyle, kredi zamanla; ×6 parayla alınsaydı 15.4'ün tavanı anlamsızlaşırdı. | 17 |

Geriye ne kalıyor: zaman, alan ve dar bir raf. NOVA'nın satabileceği şey beklememek; sattığı tek eşya kendi rafındaki taban tasarımlar ve onların da derinliği yok (15.7). İki kilit tepe tabloda: `novaEsyaSatiyor` ve `novaMalzemeSatiyor` yanlış; ikincisi teknik olarak gereksiz ama yazılı durması, ileride biri malzeme düşme hızını değiştirdiğinde testin uyarmasını sağlıyor.

## 15.2 · Kredi mağazası: taban eşya
Durum: kodda · s1 · Kazanc.tabanEsyaFiyatiFor, Kazanc.tabanEsyaRankiFor, Catalogue.rafFor, HangarRules.raftanAl, ItemInstance.taban

Oyuncu bir yuvayı dolduramadığında mağaza bir zemin sunuyor. Taban eşyanın üç özelliği var ve üçü de onu bilinçli olarak ikinci sınıf yapıyor: bir alt rank (`tabanEsyaRankFarki = -1`, en kötü drop'tan bile zayıf), kalite tabanı sabit (roll yok, hep bandın en alt değeri), alt stat yok (derinlik satılmıyor). Fiyatı 13'ün mağaza payından çıkıyor: nesil bütçesinin mağaza payı, nesil başına `magazaEsyaSayisi = 4` taban eşyaya bölünüyor; dört, 14'ün ölçtüğü boşluk. Mağaza bir çözüm değil, bir tampon: taban eşya alan oyuncu oyunu kazanmıyor, yalnız boş yuvayla dolaşmıyor.

Raf oyuncunun bandına bağlı: her yuva tipinde (droid dahil) bandın bir alt rankındaki tasarımlar, hep krediyle ve bu modelin fiyatıyla; alınan eşya alt statsız. Elle yazılmış tasarımlar 06.3'te, üstü türetilen. Bandın üstü raftan alınamaz; 10.7'nin açılış sırası böyle korunuyor. Uzun süre raf sabit on altı tasarımdı ve fiyatı tasarımın kendi sayısıydı (12.000 × rank çarpanı²), 13'ün nesil bütçesiyle ölçeksiz; model kodda vardı, raf onu okumuyordu.

## 15.8 · Başlangıç kredisi raftan türüyor
Durum: kodda · s1 · Kazanc.baslangicKredisi, Hangar.startingCredits, baslangicEsyaSayisi

Yeni hesabın parası bir sayı değil, rafın fiyatına bağlı bir ORAN: ilk bandın taban eşya fiyatı (15.2'nin modeli) × `baslangicEsyaSayisi = 2`. Elle yazılmış 30.000 kredi uzun süre "bir C tier lazer alacak kadar" diyordu; raf bu belgenin fiyat modeline geçince o cümle yalan oldu — ilk bandın taban eşyası 94.522 kredi, yani yeni oyuncu ilk oturumunda raftan hiçbir şey alamıyordu ve mağaza ona kapalı bir kapı gösteriyordu (borç defteri B21).

Neden iki: başlangıç gemisinde takılı olan tek şey bir lazer. Bir eşyalık kredi yalnız "satın al" düğmesini öğretir ve oyuncuyu ilk alışverişinde sıfırda bırakır — kapı açılır ve aynı dakikada kapanır. İki eşyalık kredi ilk SEÇİMİ öğretir: ikinci namlu mu, ilk jeneratör mü, yani 08'in saldırı ile dayanıklılık arasındaki bölünmesinin oyuncu tarafındaki ilk hâli. Üç ve üstü hediye olurdu; nesil başına mağaza payı zaten `magazaEsyaSayisi = 4` eşya ve raf bir zemin, bir kaynak değil. Eşyanın asıl arzı ganimet döngüsünde (14).

Türetmenin bedeli yok, faydası şu: mağaza payı ya da nesil bütçesi değiştiğinde başlangıç kredisi kendiliğinden kayıyor. Elle güncellenecek bir sayı kalmadığı için "raf pahalandı, başlangıç kredisi eskidi" hatası bir daha doğamaz. Başlangıç parası aynı zamanda bir MUSLUK: ekonomiye giren her birim gibi deftere `signup` sebebiyle yazılıyor.

## 15.3 · NOVA mağazası: zaman satar
Durum: kodda · s3 · Kazanc.fiyatFor, Kazanc.cevirmeNovaFor, Kazanc.droidOnarimNovaFor, Kazanc.zorunluGiderOrani

NOVA fiyatları tahmin edilmiyor, kazandırdıkları zamandan çıkıyor: fiyat = kazandırdığı dakika ÷ 60 × saatlik NOVA. Anında onarım beş dakikalık ölüm maliyetini atlıyor; envanter genişletme `envanterNova = 2.000` × `envanterKademe = 5`, kalıcı.

Dördüncü kalem droid onarımı (05.10) ve aynı kuralın en uzun türetimi: onarılmayan droid kayboluyor, yerine geleni beklemek `droidDusmeAraligiDk = 15,3` dakika, üstündeki artıları yeniden basmak rankın gelirinden bir o kadar. Fiyat ikisinin toplamı — C-I ve +0'da `droidOnarimNovasi = 102` NOVA. Burada da satılan şey bekleme: droid mağazada yok, NOVA onu üretmiyor.

Çevirme de aynı kuraldan ve sabit değil: bir çevirici bir eşya düşmesi kadar zaman (parçalama başına bir çevirici), fiyat rankın çevirici bedeli × o zaman. Kilit bedeli artırdığı için fiyatı da artırıyor. Sabit 150 iken bedelden kopuktu: Pembe'de bir çevirme kırk iki çevirici, yani yüzlerce dakika farm ederken NOVA fiyatı C-I ile aynıydı.

**Çevirme ve droid onarımı LÜKS.** Çevirici parçalamadan geliyor, droid ganimetten; ikisinde de NOVA ihtiyaç değil kestirme. Bu yüzden "hiç ödemeyen oyuncu istediğini alabilmeli" değişmezi yalnız zorunlu kalemlere, onarım ve envantere bakıyor: onların ömür boyu toplamı musluğun altında kalmalı. Lüksler dahil toplam tabloda ilan edilir, üst ranklarda musluğu aşar ve aşması bilerek: lüksün tavanı yok. Modelleri açıkça yazılı — her nesilde her yuva için bir tam çevirme, ve nesil başına filonun bir tam sayacı; ölçülen ölüm sayısı bunun katı, aradaki fark onarmadan bırakılan droidler. Katlanan NOVA fiyatı yine yok: art arda çevirme pahalılaşmıyor, yalnız kilit.

## 15.7 · NOVA rafı: üç taban tasarım, bir kademe üstte
Durum: kodda · s1 · Catalogue.novaRafi, Catalogue.priceOf, HangarRules.novaRafindanAl, ItemSpec.currency

Kredi rafının (15.2) yanında ikinci bir raf: kıt parayla alınan üç tasarım — bir lazer, bir jeneratör, bir droid (Hilal). Kredi rafı oyuncunun bandını izliyor, NOVA rafı sabit; ikisi aynı ekranda ama aynı kasada değil.

Üç sınırı var ve üçü birden 15.1'i ayakta tutuyor. Bir: gelen eşya TABAN, alt statı yok — NOVA derinlik satmıyor, ganimetin verdiğini vermiyor. İki: raf merdivenin DİBİNDE duruyor — en üstü B-I, yani yirmi basamaklı merdivenin üçüncüsü. Ödeyen oyuncu ilk bantlarda bir adım önde başlıyor; rafın yukarı tırmanması ilerlemenin bir basamağını paraya bağlamak olurdu ve o basamak burada yok. Üç: raf üç tasarımdan ibaret ve büyümüyor — 14'ün arz hesabı gövde yuvalarını ganimetten dolduruyor, buradan değil.

"İstenir ama gerekmez" ölçüsü tam olarak bu: ödeyen oyuncu bir kademe önden başlıyor, ödemeyen aynı eşyayı bir bant sonra ganimetten ya da raftan alıyor ve alt statlarıyla alıyor. Fiyat tasarımın kendi NOVA fiyatı (`priceOf`, 270 tabanlı), kredi rafının modeli değil: iki raf iki ekonomi.

Sınır: droidin elit olması bir güç kararı ve tartışmalı (borç defteri B25); bu karar yalnız RAFI tanımlıyor, rafın ne kadar güçlü olduğunu 06 ve 08 belirliyor.

## 15.9 · Görünüş satılır: tasarım ve formasyon
Durum: kodda · s1 · Kazanc.gorunusFiyati, GorunusKalemi, HangarRules.gorunusAl, HangarRules.droidTasarimSec, Hangar.tasarimlar

NOVA'nın sattığı üçüncü şey: görünüş. On droid tasarımı (05.8 s2) ve yirmi formasyon (05.9) kredi ile değil NOVA ile alınıyor. Bu 15.1'in yasak listesine aykırı değil, tersine listenin gerekçesini doğruluyor: yasak GÜCÜ koruyor, görünüş güç değil. Tasarım droidin çizimini, formasyon filonun dizilişini değiştiriyor; ikisi de savaş puanına dokunmuyor, ikisi de bir dövüşü kazandırmıyor.

**Fiyatı TÜRETİLEMEZ ve bu bir istisna.** 15.3'ün kuralı "fiyat = kazandırdığı dakika" ve görünüş hiçbir bekleme kısaltmıyor: kazandırdığı dakika sıfır, o formül sıfır fiyat verir. Bu yüzden iki sayı ilan ediliyor: `tasarimNova = 100` ve `formasyonNova = 200`. Formasyon iki katı, çünkü yalnız görünüş değil geometri — droidlerin dizilişini değiştiriyor ve eğilimiyle σ'yı itiyor (05.9). O takas imzalı ve toplamı sıfır, yani güç vermiyor; ama oyuncunun kararına giriyor ve bedava olmamalı.

Sahiplik HESAPTA, seçim ÖRNEKTE. Bir tasarım alındıktan sonra oyuncunun bütün droidlerine takılabiliyor — eşyaya bağlansaydı aynı görünüşü on kez almak gerekirdi. Hangi droidin hangi tasarımı giydiği örneğin kendi alanında, çünkü iki droid iki ayrı tasarım giyebilmeli.

İki şey hep sahipli ve satılmıyor: satın alınan iki droidin kendi görünüşü (Hilal ve Delta — onları alan zaten droidi almış) ve varsayılan formasyon (filo bir şekilde dizilmek zorunda). Geri kalan on sekiz formasyon ve sekiz tasarım raftan geliyor.

## 15.4 · Paranın tavanı ölçülür
Durum: kodda · s1 · Kazanc.tavanFor, Kazanc.tavan

Paranın dokunabildiği tek kanal kalite rolü olduğu için tavan hesaplanabilir: sınırsız çevirme yapan oyuncu her eşyada mükemmel roll tutturur, hiç çevirmeyen bandın tabanını alır; aradaki fark 06'nın kalite makası. Karşılaştırma için bir rank atlaması yüzde kırk dört, bir artı seviyesi sekiz ile on iki: ödeyen oyuncunun bütün parasıyla aldığı avantaj tek bir artı seviyesinden az. Tavan bir tasarım kararı değil, üç alanın kısıtlarının çarpımı; değiştirmek için kalite bandını genişletmek gerekir ve o da 06'nın rank çakışma testini kırar. Kalite bandı üst ranklarda daraldığında (06.10) tavan da daralır: oyun ilerledikçe para daha az işe yarar. Ters yönde tasarlanmış bir sistem F2P'de yaygındır ve tam olarak oyuncuların terk sebebidir.

## 15.5 · Paketler ve bonus eğrisi
Durum: kodda · s1 · Kazanc.paketNova

Taban kur `dolarSaatDegeri = 3,3`: bir dolar üç saat üç dakika oyun. Büyük paketler bonusla ucuzluyor, tavan `paketBonusTavani = 1,6`. Sınırı var: iki katı geçen bonuslar küçük paketleri anlamsızlaştırır ve oyuncuyu tek bir büyük alışverişe zorlar. Daha yüksek bir kur tavanı değiştirmiyor, yalnız oraya daha çabuk vardırıyor; tavanın kendisi güvenlik mekanizması. Ara paketlerin bonusları (1,15 · 1,35) belgede tasarlandı, kodda yalnız iki uç var.

## 15.6 · Ödeme oranı ve ARPPU hedefi
Durum: kodda · s1 · Kazanc.arpu, Kazanc.odeyeninPayi

Hedef ödeme oranı `odemeOrani = 0,03`, ödeyen başına `hedefARPPU = 40` dolar; oyuncu başına ortalama gelir ikisinin çarpımı. Kırk dolarlık bir oyuncu en iyi kurdan aldığı NOVA ile ömür boyu musluğun bir kesrini bir alışverişte alıyor: anlamlı bir yardım, ama ödemeyeni geçmesine yetmiyor, çünkü tavan zaten küçük.

## Sınır

Sahiplenmediği: kalite bantları → 06 · çevirme maliyeti → 07 · NOVA musluğu → 12 · mağaza payı → 13 · fatura doğrulama → mühendislik. Paranın tavanı bu alanın kararı değil; 15 onu yalnız ölçüyor ve ilan ediyor, ve ilan etmek onu bir teste dönüştürüyor.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Paranın tavanı ≤ bir artı seviyesi | Ödeme, zamanla kazanılan en küçük adımı geçmiş. |
| Tavan üst ranklarda daralıyor | Geç oyunda para daha çok işe yarıyor. (06.10 belgede) |
| Taban eşya < en kötü drop | Mağaza ganimetle rekabet etmiş. |
| Zorunlu NOVA gideri musluğun altında | Onarım ya da envanter için ödeme zorunlu olmuş. |
| Çevirme fiyatı = rankın bedeli × çevirici zamanı | Fiyat bedelden kopmuş; üst rankta NOVA çevirmesi bedava. |
| NOVA eşya ve malzeme satmıyor | Ganimet döngüsü baypas edilmiş. |
| Çevirme NOVA fiyatı sabit | Katlanan eğri sömürüye dönmüş. |
| Paket bonusu ≤ ×2 | Küçük paketler anlamsız; ödeme oranı düşüyor. |
| Her NOVA fiyatı = kazandırdığı zaman | Fiyat elle konmuş. |
