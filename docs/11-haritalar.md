---
alan: 11
ad: Haritalar
katman: dünya
tur: kural
surum: 1.2
tablo: 11-bolge-tablosu.md
kaynak: https://claude.ai/code/artifact/afdfd09c-c39b-4d3e-8ca2-4297e6ea35bc
---

# 11 · Haritalar

Dünyanın kaç parçaya bölüneceği, her parçanın kimi kabul edeceği ve neden o kadar büyük olduğu. Harita bir zorluk kabı değil, bir eşleştirme aracı. Görevi tek: oyuncuyu, gücüne denk hedeflerin ve gücüne denk rakiplerin olduğu yere koymak. Bunu yapabiliyorsa harita doğru; yapamıyorsa ne kadar güzel çizilmiş olursa olsun yanlış.

Kullandığı: [04](04-gemi-ve-yuvalar.md) sekiz gövde kademesi · [09](09-savas-puani.md) referans BR · [10](10-ilerleme-ve-unvan.md) α. Devredilen: 12 → bölge başına saatlik kredi hedefi · 13 → yorgunluk eşiği. Sayı tablosu: [11 · Bölge Tablosu](11-bolge-tablosu.md).

Sürüm 1.2: seviye ikincil kapı kodda (11.4): eşik bandın ilk rankının bir altı, sunucu iki kapıyı sırayla sınıyor. Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. 1.0'ın "kapanan bulgu" bölümü (yorgunluk eşiği) alan 13'ün kararı olarak oraya taşındı; kapı koşulunun seviye ayağı ayrı karar oldu çünkü seviye yok.

## 11.1 · Bölge = gövde kademesi; her bölgede üç harita
Durum: kodda · s1 · Bolge, HaritaTipi, Harita, Turetilenler.bolgeSayisi

Kaç harita olacağı sorusunun yanlış cevabı bir sayı seçmektir. Doğru cevap zaten var olan bir bölünmeyi kullanmak: alan 04 dünyayı sekiz gövde kademesine böldü, ve bir gövde kademesi tam olarak "aynı ligde oynayan oyuncular" demek. Sekiz bölge; yeni bir sayı eklenmedi, `govdeKademeSayisi = 8` ikinci kez kullanıldı.

Her bölgede `bolgeBasinaHarita = 3` harita ve üçü de oyunun kendi tanımından: **PvE** ana farm alanı, saldırı yalnız yaratıklardan; **PvP** aynı yaratıklar, daha yüksek ödül ve başka oyuncular, girmek bir karar; **Boss** zamanlı doğan tek hedef, grup gerektirir, ganimeti bölgenin tavanıdır. Yirmi dört harita. Yirmi rank için yirmi harita çizmek gerekmiyor, çünkü iki komşu rank arasındaki fark oyuncunun yeni bir dünya görmesini gerektirecek kadar büyük değil; gövde değişimi öyle: yeni gemi, yeni siluet, yeni yuva.

## 11.2 · Bant yapısı ve bant başına gelir
Durum: kodda · s1 · Bolge.rankAraligi, Bolge.gelirCarpaniFor

Bir bölge iki ya da üç rank taşıyor ve o rankların gelirleri farklı olmak zorunda, yoksa alan 10'un gelir eğrisi kırılır. Çözüm haritayı bölmek: derinlik bandı. Merkeze doğru gidildikçe bant değişiyor, yaratıklar sertleşiyor, ödül yükseliyor. Bant sayısı bölgenin taşıdığı rank sayısı; bant geliri o rankın kendi geliri, 10'un eğrisi bozulmadan taşınıyor. Rank aralıkları taban bölmeyle: başlangıç(k) = k × rank sayısı ÷ kademe sayısı, kalanı atarak; yuvarlama kipi dile göre değiştiği için yuvarlama değil. Sonuç 2·3·2·3·2·3·2·3.

Bu, bölge içinde ikinci bir ilerleme üretiyor: yeni gemi almadan da ilerliyorsun, yalnız daha derine giriyorsun; ve derine girmek bir yetenek sınavı, satın alma değil. Yan etki: bölge sınırı yumuşuyor, geçiş bir uçurum değil bir eğim.

## 11.3 · Kapı savaş puanı: referansın dörtte üçü
Durum: kodda · s1 · Bolge.girilebilen, Bolge.girisEsigi

Bölgeye girmek için o bölgenin ilk rankının referans BR'sinin `girisPayi = 0,75` katı gerekiyor. Neden seviye değil BR: seviye zamanla artıyor, BR güçle; bir harita zamanı değil gücü ölçmek zorunda, yoksa iki yıl oynamış ama hiç güçlenmemiş bir oyuncu taşıyamayacağı bir bölgeye girer ve orada hiçbir şey yapamaz. Neden tam değil dörtte üç: tam eşik oyuncuyu bir önceki bölgeyi tamamen bitirmeye zorlar; pay bırakmak hazır hissettiği anda risk alabilmesi demek, ve %75 ilk bandın yaratıklarını yenebileceği ama derinlere inemeyeceği nokta.

## 11.4 · Seviye ikincil kapı
Durum: kodda · s1 · Bolge.seviyeEsigi, Gecit.acik(seviye), GalaksiHaritasi.girisNoktasi

BR birincil kapı, seviye ikincil: BR'yi para ile hızlandırmak mümkün, seviyeyi değil. İkisi birlikte ödeyerek çok öne fırlamayı sınırlıyor. Kodda: bölgenin seviye eşiği bandın ilk rankının bir altı; referans oyuncu için hiç bağlayıcı değil, yalnız parayla öne geçen için, ilk bölge herkese açık. Sunucu iki kapıyı sırayla sınıyor ve hangisinin kapalı olduğunu ayrı söylüyor; istemci seviyeyi bilmiyorsa yalnız BR'yi gösterir, karar sunucunun.

## 11.5 · Harita boyutu ve yoğunluk türetilir
Durum: kodda · s1 · GameWorld.tekBantGenislik, Turetilenler.bantAlani, Turetilenler.bantBasinaHedef

Harita boyutu estetik bir seçim değil; üç ölçülebilir şeyden çıkıyor: görüş yarıçapı `gorusYaricapi = 2.600` (fiziksel: 0,6 yakınlaştırmada ekran artı pay, protokolün ilgi yarıçapı da oradan okuyor), eş zamanlı oyuncu `esZamanliOyuncu = 8`, ve oyuncuların görüş alanını paylaşma seyrekliği `gorusPaylasimi = 0,5`. Bant alanı = oyuncu × π × görüş² × seyreklik; kenarlar `dunyaEnBoyOrani = 1,5` ile; harita alanı bant sayısıyla çarpılıyor. Türetilen tek bant boyutu kodun varsayılan dünyası oldu; elle konmuş 12.000 × 8.000 her iki kenarda yüzde altı sapıyordu ve kaldırıldı.

Yoğunluk aynı çemberden: görüş çemberinde ortalama `gorusHedefi = 4` hedef. Üçten az olursa oyuncu hedef arıyor; beşten çok olursa aynı anda üç yaratık birden saldırıyor ve harita bir farm alanı değil bir mayın tarlası oluyor.

## 11.6 · PvP primi hesaplanabilir
Durum: kodda · s1 · Turetilenler.pvpKayipOrani, Turetilenler.pvpBrutPrim

PvP haritası daha çok vermeli ama "daha çok" bir his sorusu değil, beklenen değer sorusu. Ölüm maliyeti `olumMaliyetiDk = 5` dakika (dönüş + onarım), ölüm sıklığı `pvpOlumSikligi = 3` saatte (ölçülecek, playtest), hedeflenen net prim `pvpNetPrim = 0,3`. Kayıp oranı sıklık × maliyet ÷ 60; brüt prim (1 + net) ÷ (1 − kayıp). Ölüm sıklığı playtest'ten geldiğinde prim kendiliğinden yeniden hesaplanıyor; elle ayarlanacak bir şey yok.

Prim çok yükselirse PvP zorunlu olur. Net prim %30'da tutuluyor çünkü daha yükseği PvP'yi seçim olmaktan çıkarır: PvP'den kaçınan oyuncunun ilerlemesi %30 yavaşlamalı, durmamalı. Ölçülen sıklık saatte sekizi geçerse brüt prim dörde yaklaşır ve o noktada formül değil tasarım yanlıştır: PvP haritası fazla ölümcül demektir.

## Sınır

Sahiplenmediği: yaratıkların statları, boss doğma aralığı ve ganimeti → 12 · kredinin nereye harcandığı ve yorgunluk eşiği → 13 · ne düşeceği ve hangi oranla → 14 · haritanın nasıl göründüğü → sanat. 11 dünyanın kabını tanımlıyor, içindekini değil; bir bölgenin geliri burada belirleniyor ama o gelirin hangi yaratıktan kaç saniyede geleceği 12'nin işi.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Bölge sayısı = gövde kademesi sayısı | İki alan farklı dünya bölünmesi söylüyor. |
| Bant sayıları toplamı = rank sayısı | Bir rankın haritası yok ya da iki haritada. |
| Bölge süreleri toplamı = hedef süre (±%2) | Bölünme zaman kaybetmiş; 10 ile ayrışma. |
| Her bantta gelir bir öncekinden yüksek | Derine inmenin karşılığı yok. |
| BR eşiği = referans BR × girişPayı | Kapı elle ayarlanmış; merdivenle bağı kopmuş. |
| Harita alanı = bant × türetilen bant alanı | Boyut elle yazılmış; yoğunluk hedefi tutmaz. |
| PvP net primi %30 (±5 puan) | PvP ya zorunlu ya anlamsız hâle gelmiş. |
