---
alan: 16
ad: Denge Denetimi
katman: denetim
tur: kural
surum: 1.5
tablo: 16-tepe-tablo.md
kaynak: https://claude.ai/code/artifact/01cb2edd-be15-46d4-83a7-9112616b93d7
---

# 16 · Denge Denetimi

On beş alan boyunca her belge sonunda aynı tabloyu yazdı: bu kırılırsa ne olur. 16 o tabloları bir araya getiriyor. Yeni bir kural üretmiyor; var olanları çalıştırılabilir hâle getiriyor. Sayılar (girdi sayısı, sistem oranı, döngüler, borçlar) [tepe tabloda](16-tepe-tablo.md) koddan basılıyor; bu belgede yalnız kurallar var.

Sürüm 1.5: üç mekanizma daha: türetilen sayılar da etiketle doğrulanıyor (16.7), kodda demek sınanmış demek (16.8), borç defteri ve yan belgeler denetimde (16.9). Sürüm 1.4: beş test türü kodda (16.1): her test dosyası türünü ilan ediyor, denetim sayıp haritaya basıyor. Sürüm 1.3: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. 1.2'nin elle saydığı her sayı (93 girdi, 198 değişmez, %85,4) üretilen tabloya taşındı; belgede sayı yok. Kod ↔ belge denetimi artık ayrı bir sistem: karar izlenebilirliği (`docs/README.md`), bu belgenin "kod belgeye uyuyor mu" sorusunu her karar için ayrı ayrı soruyor.

## 16.1 · Beş test türü
Durum: kodda · s1 · TestTuru; her test dosyası @Tags ile ilan eder, BelgeDeposu.testTuruSayimi sayar, harita basar

**Yabancı anahtar:** atıf yapılan şey var mı (havuzdaki her stat kütüphanede mi). **Aralık:** bir oran bandın içinde mi (A/D bandı). **Türetme:** formülle mi geldi, elle mi yazıldı. **Kapsam:** hiçbir şey dışarıda kaldı mı (bant sayıları toplamı = rank sayısı). **Kod ↔ belge:** çalışan oyun belgeye uyuyor mu. En kalabalık tür aralık, en değerlisi türetme: aralık testi bir sayının makul olup olmadığını sorar, türetme testi nereden geldiğini. Bir sayı doğru ve elle yazılmış olabilir; o durumda bugün her şey çalışır, ama bir üst alandaki girdi değiştiğinde sessizce bozulur. Bulunan bayat sabitlerin hepsi tam olarak böyleydi: gövde merdiveni, K sabitleri, yorgunluk eşiği; üçü de yazıldıkları gün doğruydu. Testler sınıflandırmayı artık taşıyor: her test dosyası başında türünü ilan ediyor, bir dosya birden çok tür taşıyabiliyor; ilan etmeyen dosya denetimde biçim hatası. Sayım koddan, [haritada](00-harita.md). Beşin dışında kalan testler (ağ, simülasyon, arayüz, güvenlik) altıncı bir etiketle ayrılıyor: sayım onları saymıyor, yalnız dışarıda bıraktığını biliyor. Bir tür tek başına da koşturulabiliyor. Tür sayımı bir zamanlar elle yapılmıştı ve elle sayılan her şey eskir. `zaman` etiketi tür değil nitelik: gerçek zamana bağlı ölçüm yapan test (ağ titreşimi, anahtar kare aralığı) türünün yanına onu da yazar; yük altındaki tam koşudan `--exclude-tags zaman` ile ayrılır, denetim türleri sayarken onu görmez.

## 16.2 · Karar döngüleri kapalı
Durum: kodda · s1 · DengeDenetimi.dongular

Tasarım kuralı katmanlıydı: her alan yalnız üstündekine bakabilir. Bağımlılık grafiği çizildiğinde geri kenarlar çıkıyor, ama hepsi aynı biçimde: geri kenar bir değer değil, bir karar taşıyor. Alt alan bir soru yukarı gönderiyor, üst alan cevabı veriyor, cevap verildikten sonra kenar kayboluyor. Grafik çalışma zamanında döngüsüz; döngüler tasarım sürecinin izleri, veri akışının değil. Gerçek bir veri döngüsü (A'nın çıktısı B'nin girdisi, B'ninki A'nın) çözülemez: sayılar ya yakınsamaz ya keyfî bir başlangıca bağımlı kalır. Karar döngüsü bir kez çözülür, kararı yazılır ve bir daha çalıştırılmaz. Bir alan eklendiğinde yeni bir karar döngüsü açılabilir; açılması sorun değil, kapatılmadan bırakılması sorun. Kapanan döngüler kayıt olarak kodda ve tabloda.

## 16.3 · Tek tepe tablo: dışında elle sayı yok
Durum: kodda · s1 · TasarimGirdileri.hepsi, DengeDenetimi.cakisanGirdiler

On altı alan boyunca ilan edilen her tasarım kararı tek bir dosyada toplanıyor. Bu dosyanın dışındaki her sayı türetilmiş olmak zorunda. Kural tek cümle ve bütün sistemin temeli: **tepe tabloda olmayan hiçbir sayı elle yazılamaz.** Rank çarpanları rank artışından, gövde havuzları çapadan, yaratık statları sınıf sürelerinden ve gelir hedefinden, unvan eşikleri BR tavanından, harita boyutları görüş yarıçapından, NOVA fiyatları kazandırdıkları zamandan. Onlarca girdiye karşılık binlerce türetilen sayı; oran bu belge dizisinin asıl çıktısı: bir tasarımcının aklında tutması gereken şey girdiler, geri kalanı hesap. Her girdi tam bir alana ait, adı benzersiz, gerekçesi yazılı; denetim çakışan ve gerekçesiz girdileri listeler.

## 16.4 · Sayı borçları ve eksik sistemler derlenir
Durum: kodda · s1 · DengeDenetimi.sistemler, DengeDenetimi.sistemOrani

Denetimin ilk işi mevcut kodu belgelere karşı sınamak. Sonuç iki liste: sayı borçları (değiştirilecek sabitler) ve eksik sistemler (hiç yazılmamış). Hiçbir sayı borcu bir hata değildi: hepsi yazıldıkları gün doğruydu ve bir üst alandaki karar değiştiğinde bayatladı; denetimin varlık sebebi tam olarak bu. Eksik sistemlerin çoğu tek bir karardan çıktı: rank merdiveni beşte duruyordu, hedef yirmi; gövde kademesi, harita ve serpilen yaratık sayıları hep ona bağlıydı ve merdiven uzatılınca üçü birden kendiliğinden yerine oturdu.

Denetimin kendi ölçüm satırı da denetlenmeli: "çizilmiş gövde" bir zamanlar elle yazılmış stat satırlarının uzunluğunu okuyordu, sanatı olan gövdeleri değil; serpilen yaratık satırında aynı hata bir kez daha olmuştu. Elle tutulan bir listenin uzunluğu, ölçülmesi gereken şeyin yerine geçmemeli. Bugünkü liste ve oran tabloda; elle sayılmıyor.

## 16.5 · Yeni alan ekleme adımları
Durum: ayrılmış · s1 · süreç kuralı

Kimin altında olduğunu yaz: hangi alanların çıktısını okuyor, o alanlar yazılmış olmalı. Girdilerini ilan et: elle konacak her sayı tepe tabloya, adıyla ve gerekçesiyle; beşten fazlaysa muhtemelen türetilebilecek bir şey girdi sanılıyor. Türetilenleri hesapla: girdi olmayan her sayı yazılı bir formülden. Değişmezleri yaz: "bu kırılırsa ne olur" tablosu, sekiz satır tipik. Geri bildirimleri kaydet: üst alanda değişmesi gereken bir şey bulduysan onu yaz ve o alanı güncelle, kapatılmamış döngü bırakma. Denetimi çalıştır: yeni değişmezler geçmeli, eskiler kırılmamalı. Girdi sayısı yüksekse alan muhtemelen kendi kısıtını kendisi belirliyor demektir, ve o durumda kısıt kısıt olmaktan çıkar.

## 16.6 · Denetim tutarlılık ölçer, doğruluk değil
Durum: ayrılmış · s1 · sınır ilanı

16 yakalar: elle yazılmış sayı, bayatlamış sabit, kopmuş yabancı anahtar, bant dışına çıkmış oran, kapsam boşluğu, kapatılmamış döngü, tekilleşmemiş girdi. 16 yakalamaz: sıkıcı olup olmadığını, savaşın iyi hissettirip hissettirmediğini, sayıların doğru olup olmadığını (yalnız tutarlı), oyuncunun ne yapacağını, sanatın çalışıp çalışmadığını, kendi ölçüm satırının doğru şeyi saydığını. Bütün sistem tutarlılık üzerine kurulu, doğruluk üzerine değil. TTK otuz saniye olsun kararı bir zevk meselesi; 16'nın söyleyebildiği tek şey o kararın her yere aynı şekilde yansıyıp yansımadığı. Ölçüm playtest'ten gelecek ve o an tepe tablodaki birkaç sayı değişecek; sistemin kazancı burada: bir sayı değiştiğinde neyin yeniden hesaplanacağı belli, neyin kırıldığı otomatik görünüyor.

## 16.7 · Türetilen sayılar da etiketle doğrulanır
Durum: kodda · s1 · TuretilenKaydi.islevler, BelgeDeposu.etiketSayimi; etiket `` `ad(arg) = değer` ``, yüzde için `%`

Girdiler belgede etiketle doğrulanıyordu, türetilenler düzyazıda çıplak kalıyordu: "otuz saniye beşe iniyor" gibi bir cümle referans TTK değişince sessizce çürüyor, denetim bakmıyordu. Türetilen kaydı türetilenlere ad veriyor: belge `` `mermiPvpTtk(6) = 5` `` yazıyor, denetim adı kayıtta bulup argümanla hesaplıyor ve yazılan ondalık kadar toleransla karşılaştırıyor; yüzde yazımı `` `mermiPveKazanci(6) = %10` `` oranı yüz ile çarpıyor. Kayıt elle büyür: belgeye yeni bir türetilen etiket girmek için önce kayda bir satır, keyfî ifade yok. Kural: kural belgesindeki bir sayı ya girdi etiketi ya türetilen etiketi ya üretilen tablodadır; etiketsiz sayı hâlâ serbest ama artık bir tercih, zorunluluk değil.

## 16.8 · Kodda demek sınanmış demek
Durum: kodda · s1 · BelgeDeposu.sinanmamis, testAtifHaritasi; harita "Sınanmamış" listesi, kök testte cırcır

Bir kararın kodda olması atıfının yerinde durmasıydı; atıf kodun hâlâ o cümleyi yaptığını söylemez, onu yalnız test söyler. Denetim artık test dizinlerini de tarıyor: `// KARAR 17.6 s1` bir test dosyasında da geçerli ve haritada ayrı sütunda. Kodda olup hiçbir testin anmadığı kararlar "sınanmamış" listesinde; liste bir cırcırdı: kök test ilan edilen sayıyı aşmadığını sınıyor, atıf eklendikçe sayı düşürülüyor, artamıyordu. Test atıfı "kodda" için sayılmıyor: kod atıfı olmadan kodda denemez, test atıfı olmadan sınanmış denemez. **Sayı 2026-09-04'te sıfıra indi ve cırcır kalktı:** sınanmamış karar artık doğrudan bulgu, kök test de sıfırı sınıyor. "Kodda" demek bundan sonra "bir test bunu sınıyor" demek.

## 16.9 · Borç defteri ve yan belgeler denetimde
Durum: kodda · s1 · BelgeDeposu.borclariOku, YanBelge; README yan belge tablosu, harita "Borç defteri" ve "Dışarıda bekleyen"

Borç defteri serbest metindi ve `docs/` dışındaki tasarımlar görünmezdi; mermi belgesi bir yan belge olarak aylarca ne haritada ne kodlanacaklar listesindeydi. İki bağ: defterin her maddesi durumlu ve tarihli, `Kaynak:` satırında en az bir karar ya da alan anıyor ve o karar var olmak zorunda; kaldırılan bir karar defterde kalamaz. README'nin yan belge tablosu dışarıda yazılmış her tasarımı `dışarıda` ya da `taşındı → dosya.md` durumuyla listeliyor; taşındı denen dosya `docs/` altında olmalı, dışarıda kalanlar haritada "Dışarıda bekleyen" başlığında duruyor. Defter yine elle yazılıyor; denetim içeriğe karışmıyor, yalnız bağı sınıyor.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Her girdi tam bir alana ait | İki alan aynı kararı veriyor; biri sessizce eskiyor. |
| Türetilen etiket kayıttaki hesabı tutuyor | Düzyazıdaki sayı koddan kopmuş; girdi değişti, cümle kaldı. |
| Sınanmamış kodda karar sayısı ilan edileni aşmıyor | Yeni bir karar test yazılmadan kodda denmiş. |
| Borç defterinin her maddesi var olan bir karara ya da alana bağlı | Borç sahipsiz; kimin kararı olduğu belli değil. |
| Girdi adları benzersiz | Aynı karar iki isimle. |
| Tepe tablo dışında elle sayı yok | Sistemin dışında bir sabit var; türetme zinciri kopuk. |
| Her alan ≤ 12 girdi | Alan kendi kısıtını kendisi belirliyor. |
| Bağımlılık grafiği döngüsüz (karar kenarları hariç) | Gerçek veri döngüsü var; sayılar yakınsamıyor. |
| Her karar döngüsü kapalı | Bir alan soru sormuş, cevap gelmemiş. |
| Her alanın ≥ 5 değişmezi var | Alan kendini sınamıyor. |
| Kod ↔ belge farkı listelenmiş | Uygulama borcu görünmez olmuş. (karar izlenebilirliği, `00-harita.md`) |
