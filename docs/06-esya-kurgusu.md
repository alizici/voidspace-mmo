---
alan: 6
ad: Eşya Kurgusu
katman: büyüme
tur: kural
surum: 1.3
tablo: 06-esya-tablosu.md
kaynak: https://claude.ai/code/artifact/5eb53529-1eda-4efd-8657-744f1242a1cc
---

# 06 · Eşya Kurgusu

Eşyanın şeması: kademesi, kalitesi, ana statı, alt statları ve neyin rastgele olduğu. Sektörün tanımı: denge ile biriciklik arasındaki ilişki. Ana stat belirlenimci olduğu için denge kurulabiliyor; alt stat rastgele olduğu için her eşya biricik oluyor.

Bağımlılık: [02 Stat Kütüphanesi](README.md#taşıma-durumu) kayıt · 03 değer · 04 yuva haritası · 05 kapsam. Bu belgeye bağlı: 07 · 08 · 13 · 14. Sayı tablosu: [06 · Eşya Tablosu](06-esya-tablosu.md).

Sürüm 1.3: üç açık karar kapandı; yedili havuzlar, yedili kapasite, üç kalite bandı ve garantili alt stat kodda (06.8, 06.9, 06.10). Sürüm 1.2: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. 1.1'in "üçüncü satır bugün kırık" notu kapandı; alt stat merdiveni ile kalite bandı, kodla çeliştikleri görülünce durumlarıyla ayrıldı.

## 06.1 · Rank ekseni belirlenimci, yirmi basamak
Durum: kodda · s1 · ItemTier, TasarimGirdileri.rankArtisi

Bir eşya için üç şey sayıldı: rank, nadirlik, kalite. Tasarıma oturtunca ikisi tek eksende birleşiyor ve geriye iki eksen kalıyor. Birincisi rank: belirlenimci, eşyanın kendisi.

Altı harf ailesi × üç basamak (C-I … SSS-III), üstüne iki tekil rank: Kırmızı ve Parlayan Pembe. `rankSayisi = 20` basamak, tek çarpan `rankArtisi = 1,442` üssü; tepe 1.048×. Rank, bütçe çarpanını belirliyor; alt stat sayısını ve kalite bandını da belirlemesi tasarlandı (06.9 ve 06.10).

Pratik sonucu: rank, eşyanın rengidir. Arayüzde gördüğün renk gücü de nadirliği de aynı anda söylüyor, çünkü ikisi aynı şey.

## 06.2 · Kalite ekseni rastgele, örneğe özgü
Durum: kodda · s1 · ItemBudget.kaliteRolu

İkinci eksen kalite: alt statların ne kadar iyi çıktığı. Aynı ranktan iki eşya farklı kalitede gelir; biriciklik buradan doğuyor. Roll bandının tabanı `kaliteAltSiniri = 0,70`, tavanı 1,00; roll örneğin kimliğinden türer ki aynı eşya her yüklemede aynı statı taşısın.

**Nadirlik neden üçüncü eksen değil.** Nadirlik iki farklı şeyi birden anlatıyor: eşyanın gücü ve düşme sıklığı. Birincisini zaten rank söylüyor; ikincisi eşyanın özelliği değil, düşüş tablosunun özelliği ve o alan 14'e ait. Her zaman birlikte hareket eden iki ekseni ayrı tutmak fazladan defter tutmaktan başka bir şey üretmez. "Bir eşya ne kadar nadir" sorusu "S rank ne sıklıkla düşüyor" sorusuyla aynı şey ve o soru 14'te tek bir yerde cevaplanıyor.

## 06.3 · Tasarım, örnek ve malzeme ayrı şemalar
Durum: kodda · s1 · ItemSpec, ItemInstance, Malzeme

```text
// TASARIM — kaç örneği olursa olsun tek kayıt
{ kimlik: "pl4", yuvaTipi: lazer, rank: C-III,
  anaStat: "taban_hasar",            // belirlenimci
  altHavuz: ["hasar_artisi", "atis_hizi", "menzil"] }

// ÖRNEK — oyuncunun sahip olduğu tek bir eşya
{ ornekKimligi: "i-8f2a", tasarim: "pl4",
  arti: 0,                            // alan 07
  altStatlar: { "hasar_artisi": 0.031 } }

// MALZEME — örneği yok, yığılıyor
{ tur: malzeme | çevirici, rank: A-II }   // alt statı, artısı, kalitesi YOK
```

Ayrım zorunlu: aynı tasarımdan yüzlerce örnek olabilir, her biri farklı alt statlarla. Tasarım kataloğu sabit ve küçük; örnekler oyuncunun envanterinde ve sayısız. Malzemeler de eşya ama örneği yok: yığılabilir ve birbirinin aynısı. Kaydı daha kısa, tür ve rank; kimliği bu ikisinden türüyor.

## 06.4 · Yükseltme malzemesi ile çevirici ayrı kaynak
Durum: kodda · s1 · MalzemeTuru

Tür ekseni bir düzeltme. Şema önce yalnız rank taşıyordu ve o gün doğruydu, tek bir malzeme vardı. Alan 07 çevirmeyi kendi kaynağına bağladığında yetmedi: yükseltme ile çevirme aynı kaynağı harcasaydı oyuncu her çevirmede bir yükseltmeden vazgeçmiş olurdu ve ikisi arasında bir karar değil bir ceza hissederdi.

| Tür | Ne için | Nereden | Mağaza |
|---|---|---|---|
| Malzeme | Yükseltmenin rank kapısı | Öldürme + parçalama | Düşük rank satılabilir |
| Çevirici | Alt stat çevirmenin kaynağı | Yalnız parçalama | Hiçbir rankta yok |

Yirmi rank × iki tür = kırk kayıt, ve hiçbiri elle yazılmıyor.

## 06.5 · Ana stat belirlenimci, alt statlar rastgele
Durum: kodda · s1 · ItemBudget.mainStatValue, ItemBudget.subStatValues

Eşyanın bütçesi ikiye bölünüyor ve iki parça bambaşka işler görüyor. Ana stat belirlenimci: hangi lazeri aldığını biliyorsan hasarını da biliyorsun; dengenin dayandığı kısım burası. Alt statlar rastgele: hangileri geleceği ve ne kadar iyi geleceği belli değil; oyuncunun aynı eşyayı defalarca istemesinin sebebi.

Bölünme oranı `anaStatPayi = 0,70`, kalanı alt statlara. Ana stat payı büyürse eşyalar birbirinin aynısı olur ve drop'un anlamı kalmaz; alt stat payı büyürse denge kurulamaz hâle gelir çünkü aynı eşyanın gücü oyuncudan oyuncuya oynar.

## 06.6 · Rank çakışmaz
Durum: kodda · s2 · TasarimGirdileri.anaStatPayi; çakışma taraması esya_kurgusu_test

En kötü rollü bir üst rank, en iyi rollü bir alt ranktan güçlü olmak zorunda. Çakışırsa oyuncu "hangisi daha iyi" sorusunu ancak sayıları elle karşılaştırarak cevaplayabilir ve o an rank sisteminin tek işi olan bir bakışta anlaşılırlık ölür.

Kısıt ana/alt bölünmesine bir üst sınır koyar: alt stat payı büyüdükçe bitişik ranklar birbirine yaklaşır. Bugünkü merdivende o sınır BAĞLAYICI DEĞİL. Alt stat payı %100 olsaydı, C–S bandında en kötü rollü üst rank en iyi rollü alt rankın tam `rankArtisi = 1,442` × `kaliteAltSiniri = 0,70` katı olurdu — merdivenin en dar boğazı, ve o çarpım birin üstünde. Yani ana stat payı sıfıra inse bile çakışma yok; %100'ün altında bir eşik aramak anlamsız ve %30 seçilmesinin sebebi bir tavana pay bırakmak değil, 06.5'in kendi gerekçesi. Kısıt yine de her turda ölçülüyor, çünkü merdiven oranı ya da kalite bandı değişirse ilk kırılacak şey bu: bitişik her rank çifti hem analitik sınırda hem üç yüz gerçek rollü kimlikle taranıyor.

## 06.7 · Alt stat havuzu yuva tipine göre kısıtlı ve fiyatlı
Durum: kodda · s1 · ItemSpec.subStatPool, ItemBudget.birimFiyati

Bir lazer kalkan yenilenmesi çeviremez; bir CPU taban hasar çeviremez. Havuz kısıtı olmadan bütün eşyalar birbirinin aynısı olur ve yuva kimliği kaybolur: jeneratör ile lazer arasındaki fark yalnız ana stata iner. Havuz yuva tipine göre tanımlanıyor. Aynı yuvaya giren iki eşyayı ayıran şey çoğu zaman ana stat değil, çekebileceği alt statlar; bu, satın alma kararının gerçek parçası.

**Havuzdaki her stat gerçekten işe yaramalı.** Havuza o yuvanın build'ine yaramayan bir stat koymak ölü roll üretir. Alan 03 bir statın kaç ettiğini söylüyor; havuz kurulurken o değere bakılmak zorunda ve fiyatı sıfır olan stat havuza giremez. Sürüm 1.1 bu satırı "bugün kırık" diye işaretlemişti: gövde canı jeneratör havuzunda duruyor ve neredeyse bedavaydı. Alan 03 savunma fiyatını saldırı kanalına kurdan türetince kapandı; test bugün her havuz statının fiyatını soruyor ve geçiyor.

Kısıtın ikinci işlevi, yeniden çevirme ayağını anlamlı kılmak: havuz dar olduğu için çevirme gerçekten farklı bir sonuç üretiyor. Sınırsız havuzda çevirme piyango olur.

## 06.8 · Havuz içerikleri
Durum: kodda · s2 · Catalogue rafı, Catalogue._turet

Her yuvanın havuzu yedi stat: yuvanın kendi kanalı, üstüne sistem statları (hız, menzil). Sistem statları her havuza girebilir; kanal uyumu kuralı (06.7) onlar için geçerli değil, çünkü ne saldırı ne savunma.

| Yuva (ana stat) | Havuz |
|---|---|
| Lazer (taban hasar) | hasar artışı · atış hızı · kritik şansı · kritik hasarı · son hasar · menzil · hız |
| Jeneratör kalkan (kalkan) | gövde canı · kalkan yenilenmesi · zırh · kaçınma · son azaltma · menzil · hız |
| Jeneratör hız (hız) | kalkan · gövde canı · kalkan yenilenmesi · zırh · kaçınma · son azaltma · menzil |
| Roketatar (taban hasar, roket kapsamı) | atış hızı · kritik şansı · kritik hasarı · son hasar · menzil · hız |
| CPU tamir (kalkan yenilenmesi) | gövde canı · kalkan · zırh · kaçınma · son azaltma · menzil · hız |
| CPU nişan (menzil) | atış hızı · kritik şansı · hız · zırh · kaçınma · son azaltma · kalkan yenilenmesi |
| Droid (hasar artışı) | atış hızı · kritik şansı · kritik hasarı · gövde canı · zırh · menzil |

Roketatar altı: ana statı taban hasar ama roket kapsamında (18.1), gemi kapsamındaki taban hasar lazerin tekelinde (04.2); kapak taşında altı alt statta kalır. Droid de altı: droid kapsamına yazabilen stat yedi (02.7) ve biri ana stat. Üst ranklar yuvanın raftaki en iyi tasarımının havuzunu aynen taşır. Belgenin 1.1'deki havuzları (kritik hasarı, itki dolumu, droid) kütüphanede olmayan iki stat içeriyordu ve dört genişliğindeydi; yedili merdiven onlara sığmazdı.

## 06.9 · Alt stat sayısı her aileyle bir artıyor
Durum: kodda · s2 · ItemBudget.altStatSayisi, ItemBudget.altStatTavani

C 1 · B 2 · A 3 · S 4 · SS 5 · SSS 6 · Kırmızı ve Parlayan Pembe 7. Sayı aileden geliyor, basamaktan değil; kapak taşları ailelerin bir adım üstünde. Tavan yedi: kütüphanenin havuzlara verebildiği en çok (06.8), roketatarda altı.

Uzun süre üç sayı birden yaşadı: belge yedi, kodun kesiği dört, katalog iki; çünkü havuzlar hiç genişletilmemişti ve gerçekleşen derinlik `min(kapasite, havuz)` ile havuza kilitleniyordu. Karar: belgenin merdiveni. Plakadaki pip sayısı ve kartın "alt stat n/m" satırı buradan okunuyor.

## 06.10 · Kalite bandı rankla daralıyor, garantili alt stat
Durum: kodda · s2 · ItemBudget.kaliteAltSiniriFor, ItemBudget.garantiliFor

Üç bant: C–S `kaliteAltSiniri = 0,7`, SS–SSS `kaliteAltSiniriSS = 0,75`, kapak taşları `kaliteAltSiniriRenk = 0,8`; hepsi 1,0'a kadar. Üst ranklar sayı olarak değil güvenilirlik olarak da ayrışıyor: yukarı çıktıkça kötü roll ihtimali düşüyor. Yirmi kademelik merdivende çakışma riski birikir; bant daralması o riski üst uçta sıfıra yakın tutuyor. Paranın tavanı (15.4) aynı bantlardan daralıyor.

Garantili alt stat: renk, Çin MMO'larındaki gibi kalite güvencesi. SS–SSS'de `garantiliAltStatSS = 1`, kapak taşlarında `garantiliAltStatRenk = 2` alt stat bandın tepesinden gelir (rol 1,0); havuzun ilk indeksleri. Garanti ilk rol içindir: çevirme garantili statı da yeniden çevirir; korumak isteyen kilitler (07.5). Ganimet çekilişi kimliği rankın bandına göre seçer, boss tabanı bantla birleşir.

## 06.11 · Set bonusu ayrılmış
Durum: ayrılmış · s1 · eşya kaydında set alanı yok

Set bonusları bu sürümde yok, ama şeması ayrılıyor: eşya kaydında bir set alanı duracak ve bugün boş olacak. Geldiğinde uyacağı iki kural:

- Hiçbir set bonusu yeni çarpım katmanı açamaz. Mevcut katmanları besler ya da katsayı değiştirir. Bu kural bir kez delinirse o set zorunlu build olur.
- En üst kademe set bonusu sayı değil davranış verir. Sayısal set bonusu yalnız enflasyon üretir; davranışsal set bonusu build kimliği üretir ve oyuncunun anlatacağı şey olur.

Bugünden yazılmasının sebebi alan 02'deki ayrılmış statlarla aynı: geldiğinde şemanın değişmemesi, ve o güne kadar hangi boşluğun doldurulacağının görünür kalması.

## Sınır

Sahiplenmediği: yuvaya düşen bütçe → 08 · artı merdiveni ve çevirme → 07 · hangi statın kaç ettiği → 03 · düşme sıklığı → 14 · fiyat → 13 · yuva sayısı → 04.

## Değişmezler

Bu kuralları makine denetler; kırılınca ne anlama geldiği yanında.

| Değişmez | Kırılırsa ne demek |
|---|---|
| En kötü rollü üst rank > en iyi rollü alt rank | Rank çakışmış; renk artık gücü söylemiyor. |
| Her alt stat havuzu, yuvanın kanalıyla uyumlu | Lazer kalkan statı çeviriyor; yuva kimliği erimiş. |
| Havuzdaki her statın değeri sıfırdan büyük | Ölü roll üreten bir stat havuzda. |
| Havuzdaki her stat kütüphanede var | Yabancı anahtar ihlali. |
| Ana stat + alt statlar = eşyanın bütçesi | Eşya bütçeden fazla ya da az güç veriyor; 08 ile ayrışmış. |
| Alt stat sayısı rank ile artıyor | Üst rank daha az derinlik veriyor. |
| Malzemelerin alt statı, artısı, kalitesi yok | Malzeme eşya gibi davranmaya başlamış; envanter ve mağaza karışıyor. |
| Yükseltme malzemesi ile çevirici AYRI kaynak | Tek kaynağa dönmüş; çevirmek bir yükseltmeden vazgeçmek olmuş. |
| Set alanı bütün eşyalarda boş | Ayrılmış sistem sızmış; yarım çalışan set bonusu var. |
