---
ad: Hangar, mağaza ve menü
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Hangar, mağaza ve menü

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.
>
> İlk bölüm alan belgelerinden (02 · 05 · 06 · 10) ÖNCEKİ sürümü anlatıyor; eşya payları bugün [08 · Pay Tablosu](../08-pay-tablosu.md)'nda. *Menü yüzeyi* bölümü arayüz düzeni kararlarını anlatıyor.

## Hangar, mağaza ve ilerleme (ilk sürüm)

Tasarım kaynağı: alan belgeleri (Stat Kütüphanesi, Sağlayıcı Mimarisi, Yuva ve
Eşya, Unvan Merdiveni) — [tasarım haritasında](../00-harita.md) 02, 05, 06 ve 10. Bu not
yazıldığında yalnız **alan 01 · Savaş** yazılmıştı; bugün on sekiz alanın
hepsi `docs/` altında. Aşağıdaki bölüm o belgelerden ÖNCEKİ sürümü
anlatıyor; güncel kurallar alan belgelerinde.

Belgeler bugünkü oyundan çok daha
büyük bir sistem anlatıyor — droid, P.E.T., gacha, ısı, protokol kafesi.
Kurulan şey **taşıyıcı yapı**: bugün var olan statlarla çalışıyor, yarın
gelecekler için yeri hazır. Belgenin kendi kuralı bu — *motor eşya isimlerini
bilmez, yalnız şemayı okur*.

**Stat kimliği tek başına yetmez: `stat@kapsam` bir yuva tanımlar.**
`hasar_artisi@pilot` ile `hasar_artisi@drone` iki farklı sayı, ayrı toplanıyor.
Bu, bu tür sistemlerin en sinsi hatasına karşı tek savunma: droid çipinin
geminin de hasarını artırması. Kapsam anahtarın parçası olduğu için yanlış
kapsama yazmak bir hata değil, İMKÂNSIZ.

**Eşya gücü türetiliyor, uydurulmuyor.** Yanlış yol: katsayıları tahmin et,
payları ölç, katsayıları paylar tutana kadar oynat — bu eğri uydurmadır ve her
yeni yuvada baştan başlanır. Doğru sıra (WoW'un item budget sistemi):

1. **Payı ilan et** — bir tasarım kararı. Lazer %31,7 · Jeneratör %26,6 ·
   Gövde %21,6 · CPU %12,2 · Roketatar %7,9.
2. **Katsayıyı türet** — pay ÷ yuva adedi, lazere göre normalle.
3. **Ölç** — ölçüm bir doğrulama, bir ayar kolu değil.

Yeni yuva eklemek dengeyi yeniden fit etmeyi gerektirmiyor: payını ilan et,
diğerlerinden orantılı düş. Toplam hep %100. Denge bir hesap değil, muhasebe.

**Katsayı gövdeye bağlı.** Aynı grup payı daha çok yuvaya bölününce yuva
başına düşen güç azalıyor. Bu olmadan gövde yükseltmek gücü katlardı: hem daha
çok yuva, hem yuva başına aynı güç.

**Yükseltmede başarısızlık YOK.** 15 seviye, üç kademe (+%8 / +%10 / +%12),
garantili başarı ve üstel maliyet. Başarısızlık şansı koymak tavanı doğrudan
paraya çevirir (koruma tılsımı satılır) ve mağaza yorumlarını kalıcı bozan tek
mekanik odur. Aynı para sinki, sıfır öfke.

**Jeneratör ikilemi.** Aynı yuvaya kalkan ya da hız giriyor: ekleme değil
TAKAS. Takas, sayıdan çok daha zengin bir karar.

**Kararı sunucu veriyor.** İstemci "şu lazeri şu yuvaya tak" diye niyet
yolluyor; parası yeter mi, eşya onda mı, yuva o gövdede var mı — hepsi
sunucuda. Hangar ekranı iyimser güncelleme YAPMIYOR: reddedilen bir işlemden
sonra oyuncuya olmayan bir parayı göstermek, bir kare gecikmeden çok daha
pahalı.

Donatım çözümü ORTAK pakette (`LoadoutResolver`): hangarda gösterilen sayı ile
savaşta inen hasarın ayrışmaması için tek uygulama. Ve donatım gerçekten
savaşa giriyor — hangarda taktığın lazer, dünyadaki geminin hasarı.

**Donatım TAHMİNE de giriyor** ve bunu atlamak sinsi bir tuzaktı. Sunucu
dünyaya giren geminin statlarını donatımdan çözüyor; istemci ise
`ShipStats.bastion`de kalmıştı. Başlangıç donatımı tam olarak `bastion`e
denk düştüğü için hiçbir belirti yoktu — ta ki oyuncu mağazadan ilk itki
jeneratörünü (`th1`) alana kadar. O andan sonra istemci saniyede 320 birim
tahmin ederken sunucu 337 simüle ediyor ve her snapshot bir düzeltme
getiriyor: ağda hiçbir sorun yokken lastik bant. İstemci artık hangar durumu
her geldiğinde statlarını `LoadoutResolver` ile — sunucununkiyle aynı
uygulamayla — yeniden çözüyor.

**Yeni oyuncu TAKILI bir lazerle geliyor.** Boş yuva "ateş edemeyen gemi"
demek; ateş edemeyen oyuncu kredi kazanamaz, kredi kazanamayan lazer alamaz —
kilitli bir başlangıç. Testlerde tam olarak böyle yakalandı: üç dövüş testi
birden "hasar inmedi" dedi.

Gövde yuva sayıları belgedeki merdivenden bir kademe kaymış durumda (C'de 4
değil 5 lazer): Bastion'un sanatında beş namlu var ve kodun zaten bir kuralı
vardı — namlu sayısı yuva sayısıyla aynı olmak zorunda, yoksa silahın olmadığı
yerden mermi çıkıyor. Sanat ile tablo çakıştığında sanat kazanıyor.

Hangarlar `data/hangars.jsonl`'de, hesaplardan AYRI dosyada: biri kimlik, öteki
ilerleme — ayrı hızlarda değişiyorlar ve ayrı yedeklenmeleri gerekiyor.

## Menü yüzeyi — hangar ve mağaza

Tasarım `voidspace2`'nin menü kabuğundan alındı ve bu projenin veri modeline
oturtuldu: sabit sahne, üst navigasyon, cüzdan çipi, DONANIM | DEPO sütunları,
kart ızgaralı mağaza, filo penceresi. Görsel referanslar
[`tool/menu_masaustu_hangar.png`](../../tool/menu_masaustu_hangar.png),
[`tool/menu_telefon_hangar.png`](../../tool/menu_telefon_hangar.png) ve
[`tool/menu_dar_magaza.png`](../../tool/menu_dar_magaza.png) — üç ekran, dokuz
görüntü.

**Düzen uyarlanıyor, ÖLÇEKLENMİYOR.** İlk sürüm menüyü 1280×720'lik sabit bir
sahneye çizip `FittedBox` ile ekrana sığdırıyordu. İki şikâyet aynı kökten
geldi: telefonda yazılar okunmuyordu, Mac'te pencere küçüldükçe yazı da
küçülüyordu. Sebep aynı — ölçeklenen şey düzen değil PİKSELDİ.

Yerine geçen kural: **tipografi ve dokunma hedefleri SABİT, düzen değişken.**
Yer azalınca yazı küçülmüyor; parçalar yeniden diziliyor, sıkışıyor ya da
kayboluyor. Tipografi ölçeği mobil kılavuzlara göre: gövde 14, etiket 11,
hiçbir şey 10'un altında değil (eski tasarımda 8 ve 9 piksellik etiketler
vardı ve 0.66 ölçekle 6 piksele iniyorlardı).

**Belirleyici eksen YÜKSEKLİK.** Oyun yatay kilitli: iPhone yatayda ~390dp
yüksekliğe karşılık ~844dp genişlik. Genişliğe bakan bir tasarım telefonda
yanlış cevabı verir. Kırılma noktaları ([`MenuMetrics`](../../lib/hangar/menu_theme.dart)):

| ölçüt | eşik | etkisi |
|---|---|---|
| yükseklik < 480 | `dense` | önizleme düşer, düğmeler yan yana, boş ayrıntı şeridi çizilmez |
| genişlik < 640 | `singlePane` | DONANIM ve DEPO sekmeye iner |
| yükseklik < 480 **ya da** genişlik < 640 | `sideCategories` kapalı | mağaza kenar çubuğu yatay şeride döner |
| genişlik < 700 | `tightText` | başlık düşer, gemi adı bir kademe küçülür |

Kenar çubuğunun ölçütünün YÜKSEKLİK olması ölçüldü: beş kategori × 44 piksel
+ boşluklar 294 piksel ediyor ve telefon yatayda kalan 302 piksele sığmıyordu
— golden testinde tam 21 piksel taştı.

**Görsel referanslar üç ekranda** üretiliyor: masaüstü (1280×720), telefon
yatay (844×390), dar pencere (560×620). Yalnız masaüstünde bakmak, tam da
oyuncunun şikâyet ettiği hâli hiç görmemek demekti.

**Esneme payı zorunlu.** Başlık satırının hiç payı yoktu ve test yazı tipiyle
(Ahem, her harf 1em) 124 piksel taşıyordu. Ahem bir test ayrıntısı ama tarif
ettiği durum gerçek: oyuncunun yazı ölçeği ayarı, daha uzun bir çeviri ya da
farklı bir sistem yazı tipi aynı sonucu verir. Sığmayan bir başlık kesilir,
ekranı kırmızıya boyamaz.

**Depo KLASİK ızgara: boş hücreler de çizilir.** Kap görünür, içi dolar.
Yalnız dolu hücreleri çizmek "kaç yerim kaldı" sorusunu cevapsız bırakıyordu.
Izgara türe göre sıralı ama GRUPLANMAMIŞ — renk zaten türü söylüyor, başlıkla
bölmek tek kabı beş küçük kaba çeviriyordu.

**Hücrede ad değil İŞARET var.** Hücre 72'den 56 piksele indi ve bunu mümkün
kılan şey bu: 56 piksellik kutuya 11 puntoyla dört harf sığıyor, oysa "Nişan
Devresi" on üç. Adı sığdırmak için hücreyi büyütmek ızgarayı bir listeye
çeviriyordu.

İşaret eşyanın ANA STATINDAN türüyor ([`ItemGlyph`](../../lib/hangar/item_glyph.dart)):
lazer namlusu, kalkan, itki okları, roket, onarım devresi, nişangâh. Kimliğe
göre çizseydik katalog her büyüdüğünde buraya bir satır eklemek gerekirdi;
stata göre çizince yeni bir kalkan jeneratörü hiçbir şey yazmadan doğru
işareti alıyor. Kademe harfi köşede, seviye `+N` olarak, takılı olan bir
noktayla işaretli — aynı işareti taşıyan iki eşyayı ayıran şey bunlar. Tam ad
ipucunda ve ayrıntı şeridinde.

**Tek dokunuş SEÇER, işlem yapmaz.** İlk tasarımda yuvaya dokunmak doğrudan
takıp çıkarıyordu: aynı hareket yuvanın doluluğuna göre iki farklı iş yapıyor
ve yükseltmeye hiç yol kalmıyordu. Seçim, üç işlemi de (tak / çıkar / yükselt)
kutucukların altındaki tek şeritte topluyor.

**Sessiz ret yok.** Tıklanamayan her kutucuğun altında sebebi yazıyor
(`TAKILI`, `YUVA DOLU`). "Bastım, hiçbir şey olmadı" bu arayüzün en pahalı
hatası olurdu: oyuncu kuralı öğrenemeden vazgeçer.

**Kilitli gemiler de listeleniyor.** Filo penceresi yalnız sahip olunanları
gösterdiğinde tek kartlık bir boşluğa dönüşüyordu ve merdivenin devamını hiç
göstermiyordu — oyuncu neyin peşinden gideceğini bilmeden biriktirmez.

**HANGAR düğmesi her iki girdi şemasında da var.** Eskiden yalnız masaüstündeki
denetim satırındaydı; dokunmatikte onun yerine joystick geliyor, yani telefonda
hangara girmenin hiçbir yolu yoktu. Erişilemeyen bir ekran, olmayan bir ekran.

Görsel referanslar GERÇEK yazı tipiyle üretiliyor. `flutter test` varsayılan
olarak Ahem kullanıyor — bütün harfler aynı genişlikte dolu kareler — ve düzen
onunla doğru görünüp gerçek metinde bozulabiliyor. İlk turda tam olarak öyle
oldu: bütün metinler sarı alt çizgiliydi (`Material` atası yoktu) ve `⇄` ile
`✓` glifleri boş kutu olarak çiziliyordu. Ahem hiçbirini göstermezdi.
