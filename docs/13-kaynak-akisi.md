---
alan: 13
ad: Kaynak Akışı
katman: ekonomi
tur: kural
surum: 1.1
tablo: 13-akis-tablosu.md
kaynak: https://claude.ai/code/artifact/8d1913cc-4282-4ea7-9705-6d1c6d8ddca8
---

# 13 · Kaynak Akışı

Üç musluk, üç para birimi, ve hiçbirinin diğerine dönüşmemesinin sebebi. Bir ekonominin sağlığı musluk ile giderin eşit olmasına bağlı değil; farklı kaynakların birbirine dönüşmemesine bağlı. Dönüşüm serbest olduğu anda üç musluk tek musluğa iner, ve en verimli olanı diğerlerini öldürür.

Kullandığı: [11](11-haritalar.md) ölüm maliyeti ve saatlik hedef · [12](12-dusman-kurgusu.md) yaratık ödülleri · [10](10-ilerleme-ve-unvan.md) α. Devredilen: 14 → malzeme arzı artı talebini karşılamalı · 15 → NOVA kuru bantla kayıyor. Sayı tablosu: [13 · Akış Tablosu](13-akis-tablosu.md).

Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. 1.0'ın "eşya maliyeti banta mı kademeye mi" açığı kapandı: rank çarpanı merdivenden türüyor (06.1).

## 13.1 · Üç kaynak, üç davranış
Durum: kodda · s1 · Kaynak

| Kaynak | Nereden | Kademeyle | Rolü |
|---|---|---:|---|
| Kredi | Yaratık ödülü | ×291 | Güçlendirmenin yakıtı. Enflasyona açık, yorgunlukla kısılıyor. |
| Malzeme | Öldürme ve eşya parçalama | ×291 | Güçlendirmenin ikinci koşulu. Yalnız ganimetten gelir. |
| NOVA | Yaratık ödülü | ×1 | Sert para. Gerçek parayla rekabet ediyor, ölçeklenmiyor. |

Kredi zamandan, malzeme ganimetten geliyor ve ikisi de gerekiyor: farm etmek iki boyutlu.

## 13.2 · Dönüşüm yasağı
Durum: kodda · s1 · KaynakAkisi.cevrilebilir, TasarimGirdileri.paraCevirmeAcik

Bu alanın tek sert kuralı: hiçbir kaynak diğerine çevrilemez. Ne kredi NOVA'ya, ne NOVA krediye, ne malzeme krediye. NOVA sabit, kredi bantla yüzlerce kat büyüyor; yani NOVA'nın kredi cinsinden değeri kendiliğinden yüzlerce kat artıyor. Tek yönlü bir çevirme bile açılsa üst bantlı bir oyuncu NOVA'yı yüzlerce kat ucuza almış olur ve gerçek parayla satılan NOVA'nın karşılığı sıfırlanır. Malzemenin krediye çevrilememesi ayrı bir sebep taşıyor: ganimet belgesi bir zamanlar "parçalama krediye çevirir" diyordu; öyle olsaydı ganimet ikinci bir kredi musluğu olurdu ve 11'in saatlik hedefi hedef olmaktan çıkardı. Parçalama malzemeye çeviriyor (14.5). Kilit tepe tabloda: `paraCevirmeAcik` yanlış, ve değişmez testi onu koruyor; dönüşüm ancak bilinçli bir kararla, testi de silerek gelebilir.

## 13.3 · Onarım türetiliyor, gerisi bölünüyor
Durum: kodda · s1 · KaynakAkisi.onarimPayi, KaynakAkisi.payFor

Gider payları serbestçe seçilebilir sayılar değil; biri zaten belirlenmiş. Alan 11 ölüm maliyetini beş dakika olarak ilan etti, genel ölüm sıklığı `genelOlumSikligi = 1` saatte; ikisi çarpılınca onarımın payı çıkıyor (türetilen, ilan edilmiyor). Kalan pay dört yere bölünüyor: `payArti = 0,6` · `paySentez = 0,15` · `payMagaza = 0,15` · `payBirikim = 0,1`. Onarımın türetilmesi neden önemli: ölüm sıklığı playtest'te ölçüldüğünde onarım payı kendiliğinden değişiyor, diğer dört pay orantılı sıkışıyor, elle ayarlanacak bir şey yok. Ölçülen sıklık saatte üçü geçerse onarım payı dörtte bire çıkıyor; o noktada ekonomi değil PvP tasarımı düzeltilecek.

## 13.4 · Yorgunluk eşiği ölçekleniyor
Durum: kodda · s1 · Fatigue.softCapFor, Fatigue.halfLifeFor

Yorgunluk eşiği sabit kaldığında dördüncü bölgeden itibaren her oyuncu ilk dakikada eşiği geçip kalıcı olarak taban çarpanla oynuyordu: sistem botu yavaşlatmayı bırakıp herkesi durduruyordu. Düzeltme gelirle aynı üssü kullanıyor: eşik = taban × rank çarpanı^α; yarı ömür de aynı çarpanı alır, eğrinin şekli korunmalı. Ayrı bir ölçek sayısı yok, 10'un α'sı yeniden kullanılıyor; ayrı bir değer verilseydi gelir ile eşik zamanla ayrışırdı. Yorgunluk yalnız krediye uygulanır: NOVA zaten kıt, malzemenin oranları 14'te ayrı kısıtlanıyor. Eşiğin gelire oranı her bantta aynı: normal oynayan oyuncu eğriyi hiç görmüyor, iki katı farm eden yarı çarpana düşüyor.

## 13.5 · Birikim tamponu
Durum: kodda · s1 · GiderKalemi.birikim

Birikim bir gider değil, bir tampon. Payı harcanmadan duruyor: oyuncunun bir sonraki nesle geçerken elinde bir şey olması ve ekonominin nefes alması için. Sıfıra indirilirse her oyuncu her an beş parasız olur ve tek bir kötü kararın telafisi kalmaz.

## 13.6 · +15 nesil içinde ulaşılamaz; endgame kuyruğu
Durum: kodda · s2 · KaynakAkisi.ulasilanSeviye, KaynakAkisi.droidBasinaArti, KaynakAkisi.endgameSuresi

Artı basma gelirin en büyük payını alıyor, ama o pay yuvalara bölününce hiçbir nesilde +15'e ulaşılamıyor. Sebep yuva enflasyonu: gövde kademesi başına bir yuva açılıyor, aynı bütçe daha fazla eşyaya bölünüyor; ulaşılan seviye yukarı çıktıkça düşüyor. Bu bir kusur değil, endgame'in tanımı: +15 ana oyunun içinde ulaşılacak bir hedef olarak tasarlanmadı. Parlayan Pembe'ye vardıktan sonra bütün yuvaları +15 yapmak ana oyunun üstüne bir kuyruk ekliyor ve o iş yeni içerik gerektirmiyor. Ulaşılan seviyenin düşmesi de doğru yönde: erken oyunda az eşyaya derin yatırım, geç oyunda çok eşyaya yayılan yatırım; derinlik tavana varıldığında geri geliyor. Filo ayrı kalem: artı payının droid payı kadarı (`payDroid = 15` yüzde) on filo yuvasına, kalanı gövde yuvalarına; on yuvayı gövde yuvalarıyla aynı kaba katmak yuva başına bütçeyi yarıya indirirdi. Endgame kuyruğu filoyu da sayıyor. İki kalemin ulaştığı seviye [tabloda](13-akis-tablosu.md).

## 13.7 · Paralel ekonomi: pazar yok
Durum: ayrılmış · s1 · takas ve pazar yok; eklenirse önce bu belge

Ömür boyu bir oyuncunun bastığı kredinin onda biri birikim olarak duruyor ve oyuncu ayrılırsa oyunda kalıyor. Bu bir enflasyon değil, çünkü kredi oyuncular arasında el değiştirmiyor: takas yok, pazar yok. Her oyuncunun kredisi kendi hesabında basılıyor ve yakılıyor; ekonomi paylaşılan değil paralel. Pazar açılırsa bu belge geçersiz: kredi paylaşılan bir kaynak olur, birikim payı enflasyona dönüşür ve bir çıkış musluğu gerekir (işlem vergisi, açık artırma ücreti). NOVA'nın dengesi burada değil alan 15'te, çünkü sorusu "ne kadar basılıyor" değil "ne kadara satılıyor".

## Sınır

Sahiplenmediği: ne düşer ve hangi oranla, malzeme arzının yeterliliği → 14 · NOVA fiyatları, paketler, mağazada ne satılır → 15 · yaratık ödülleri → 12 · isteğe bağlı mermi gideri → 17. 13 kaynakların nasıl aktığını söylüyor, ne kadar aktığını değil.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Hiçbir para birimi diğerine çevrilmiyor | Üç musluk tek muslukta birleşmiş. |
| Payların toplamı %100 | Kalem eklenmiş ama diğerlerinden düşülmemiş. |
| Onarım payı 11'den türüyor | Elle yazılmış; ölüm sıklığı değişince ekonomi kaymaz. |
| Yorgunluk eşiği / gelir oranı bantlar arası sabit | Eşik ölçeklenmemiş; üst bölgeler tabana çakılı. |
| NOVA musluğu bantlar arası sabit | Sert para enflasyona açılmış. |
| Nesil bütçesi < tam +15 maliyeti | +15 nesil içinde ulaşılabilir olmuş; endgame kuyruğu yok olmuş. |
| Birikim payı > 0 | Tampon kalkmış. |
| Malzeme talebi ≤ 14'ün arzı | Artı basmak krediyle değil ganimetle tıkanıyor. |
