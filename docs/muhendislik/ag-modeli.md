---
ad: Ağ modeli ve replikasyon
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Ağ modeli ve replikasyon

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.
>
> Aşağıdaki ilk özet ilk sürümün şemasıdır: ara değer tamponu bugün sabit değil uyarlanıyor, snapshot delta sıkıştırmalı. İkisi de bu notun ilerleyen bölümlerinde anlatılıyor.

```
istemci → sunucu   girdi çerçevesi, sıra numaralı, 30 Hz      (~8 bayt)
sunucu             sabit 30 Hz tik — TÜM otorite burada
sunucu → istemci   snapshot, 30 Hz, ilgi alanı filtreli       (entity başına 11 bayt)
istemci            kendi gemin: tahmin + mutabakat (yeniden oynatma)
                   ötekiler: 66 ms tamponla geçmişte ara değer
```

Ölçülmüş sapma (tahmin ↔ otorite): **~2-3 simülasyon adımı**, yani 21-32 dünya
birimi — gövde genişliğinin beşte biri. Tavan tasarımdan geliyor:
`PredictedShip.maxUnacked` (1 saniyelik girdi) aşılamaz.

Üç ayrıntı, "takılarak uçuyor" ile "pürüzsüz" arasındaki farkı yapıyor ve
üçü de ölçülerek bulundu:

1. **Poz, kameradan ÖNCE uygulanır.** Flame'in takip davranışı bileşen ağacında
   yaşıyor; `super.update`'ten sonra konum yazmak kameranın bir kare geriden
   gelmesi demekti.
2. **Mutabakat tek piksel oynatmaz.** Sunucu düzeltmesi geldiğinde durum
   değişir ama ara değer tabanı da aynı miktarda kaydırılır; ekrandaki gemi
   yerinde kalır, yalnız *nereye gittiği* değişir. Kilitli:
   [prediction_test.dart](../../test/prediction_test.dart).
3. **Zaman genişletme.** Sunucu tik başına *tam bir* girdi işler (fazlası
   simüle edilen zamanı hızlandırırdı — hız hilesi). İstemci de tam o hızda
   üretmeli, yoksa kuyruk ya boşalır (sunucu son girdiyi tekrarlar) ya taşar
   (sunucu girdi düşürür); ikisi de düzeltme, yani takılma. Sunucu kuyruk
   derinliğini tek baytla geri söylüyor, istemci üretim hızını ±%6 ayarlıyor.

## Gecikme altında oynanış

İstemci gecikmeyi üç katmanda gizliyor: **tahmin** (kendi gemisi anında tepki
verir), **mutabakat** (sunucu düzeltmesi tek piksel oynatmadan uygulanır) ve
**ara değer** (ötekiler bir tampon kadar geriden gösterilir).

Tamponun derinliği SABİT DEĞİL. Ölçülen titreşime göre 2–12 tik (66–400 ms)
arasında kendini ayarlıyor: hızlı derinleşir, yavaş sığlaşır. Asimetri kasıtlı —
geç derinleşen tampon zaten donmayı yaşar; hızlı sığlaşan tampon bir sonraki
sıçramada yeniden donar ve salınıma girer.

Tahmin edici **tepe tutuyor**, ortalama izlemiyor: tamponu boşaltan şey ortalama
paket değil EN GEÇ paket, ve ortalamayı izleyen bir tahmin edici o kuyruğu
sistematik olarak küçük görür.

Bir ayrıntı ölçümde yakalandı ve düzeltildi: titreşim önce kare döngüsünün
`dt`'si biriktirilerek ölçülüyordu, yani **istemcinin kendi takılması ağ
titreşimi sanılıyordu** — sakin bir ağda tampon 11.7 tike (390 ms) şişiyordu.
Artık varış zamanı gerçek duvar saatiyle ölçülüyor ve uzun bir kareden (>100 ms:
çöp toplama, arka plana alınma, ısınma kısıtlaması) sonraki örnek ağ ölçümüne
katılmıyor. Aksi hâlde en çok, zaten zorlanan cihaz cezalandırılırdı.

Tavan (400 ms) keyfî değil, oyunun kendi ölçülerinden: 320 birim/sn hızda
400 ms görsel gecikme hedefi en çok 128 birim geride gösterir — silah menzilinin
%9'u, yani gecikmenin menzil sınırında zaten ürettiği belirsizlikle aynı
mertebe. Nişancı bir oyunda bu takas tersine döner ve tavan çok daha alçak
olmak zorunda kalır.

## Bant genişliği — delta sıkıştırma

Ölçüm önce yapıldı, tasarım sonra. Kuantalanmış (yani TELDE giden) değerler
üzerinde, ardışık iki tikte değişen alanlar:

| | düz uçan gemi | duran gemi |
|---|---|---|
| x | %100 | %0 |
| y, açı, itki, kalkan, gövde, bayrak, hedef | **%0** | %0 |

13 baytlık kaydın 11'i saf tekrar. Ham `double`'lara bakıldığında açı ve itki
de "%100 değişiyor" görünüyor — yumuşatma fonksiyonları onları sürekli
kıpırdatıyor ama kuantalama o kıpırtıyı yutuyor. **Yanlış tarafı ölçen biri
delta'yı gereksiz sanırdı.**

**Quake 3'ün modeli DEĞİL.** Quake 3 istemci başına snapshot geçmişi tutar ve
istemcinin ONAYLADIĞI kareye göre delta üretir; sebebi UDP'nin paket
kaybetmesi. Bu oyun WebSocket üzerinde — teslim **sıralı ve güvenilir**. O tek
fark bütün makineyi siliyor: onay protokolü yok, istemci başına geçmiş yok,
yeniden temellendirme yok. Herkes için **tek ortak temel**: önceki tik. Beş bin
oyuncuda istemci başına geçmiş tutmak başlı başına bir bellek sorunuydu.

Temelin geçersiz olduğu üç durum açıkça ele alınıyor ve üçünde de tam kayıt
gider: entity ilgi alanına yeni girdi, istemci yeni bağlandı, ya da yavaş
istemci olduğu için bir snapshot atlandı.

Ölçülen sonuç (60 bot, hepsi ateş ederken):

| | oyuncu başına | tik |
|---|---|---|
| delta öncesi | 27.7 KB/s | %17.6 |
| delta sonrası | **17.5 KB/s** | %17.5 |

Toplamda %37, gemi kısmında %55 düşüş. Alien'ler de aynı mekanizmaya alındı
(ölçüldü: alien'lerin **%44'ü tikte hiç kıpırdamıyor**, tür ve gövde %0
değişiyor) ve oyuncu başına **~17.0 KB/s**'ye indi.

**Anahtar kare.** Delta'nın tek zayıf noktası temelin sessizce bozulmasıydı:
o andan sonra istemci hatalı geçmişin üstüne fark uygular ve **hiçbir hata
mesajı çıkmadan** yanlış konum çizer. Sunucu temelin geçersiz olduğu üç durumu
da ele alıyor, ama dördüncü bir yolun olmadığının garantisi yoktu. Artık her
entity iki saniyede bir TAM gidiyor: her sapma en geç iki saniyede kendi
kendine onarılıyor. Kimliğe göre kaydırıldığı için maliyeti tikte bir entity.

## Zayıf ağ — uzak gemilerin pürüzsüzlüğü

Gecikme ancak taklit edilebiliyorsa düzeltilebilir: yerel ağda ping ~0 ms ve o
koşulda hiçbir gecikme hatası GÖRÜNMEZ. [`LagProxy`](../../server/lib/lag_proxy.dart)
gerçek sunucunun önüne oturup her çerçeveyi geciktiriyor — gecikme, titreşim ve
paket kaybı istenen sayıya kuruluyor, ölçüm tekrarlanabilir oluyor.

```bash
LAG_MS=500 JITTER_MS=200 LOSS=0.02 UPSTREAM=8080 PORT=8081 \
  dart run server/bin/lagproxy.dart
```

Ölçülen şey **ekranda gerçekten donan kare** oranı (uzak gemi sabit hızla
uçarken kare ilerlemedi):

| koşul | sabit tampon | uyarlanan tampon |
|---|---|---|
| 0 ms · titreşimsiz (taban) | %0.9 | %0.9 |
| 160 ms · ±40–100 titreşim | %1.8–2.5 | ~%1.5 |
| 500 ms · ±200 · %2 kayıp | **%13–16** | **~%3.6** |
| 800 ms · ±300 · %5 kayıp | — | %3.5 |

Hiçbir koşulda ışınlanma yok: tek karedeki en büyük adım 21 birim, normal
adımın (~5 birim) dört katı.

Okunuşu önemli: **gecikmenin kendisi neredeyse zararsız, oynanışı bozan
DEĞİŞKENLİĞİ.** Orta seviye titreşimde sabit tampon zaten iyiydi; uç koşulda —
yurt dışı sunucu + mobil ağ — çöküyordu.

## Öncelikli replikasyon

Kavgada baytları yiyen şey kodlama değil **ORAN**: her görünür entity her tik
gidiyordu. İskelet Unreal'in replikasyon önceliğiyle aynı — oran filtresi
(`NetUpdateFrequency`), öncelik × bekleme (`GetNetPriority`, açlığı önler),
doygunlukta öncelik sırası. Politika `Replication` sınıfında ve saf; sunucu
yalnız uyguluyor.

Ama bu mimaride iki kısıt var ve ikisi de tasarımı şekillendirdi.

**1. Paylaşılan temel.** Delta'nın temeli herkes için ortak (önceki tik).
Bir entity atlandığında istemcinin temeli geri kalıyor ve dönüşte TAM kayıt
göndermek gerekiyor. Yani atlamanın bir bedeli var:

```
kazanç = atlanan tik × kısmi kayıt (~5 bayt)
bedel  = tam kayıt (13 bayt) − kısmi kayıt
→ başa baş: aralık ≥ 3
```

Bantları önce sezgiyle 1/2/4/6 yazdım. Hesap yapılınca **bant 2'nin zarar
ettiği** çıktı (2×5 = 10 < 13) ve kaldırıldı; bantlar 1/4/6.
`replication_test.dart` her bandın başa baş noktasını geçtiğini kilitliyor.

**2. Atlamak temeli her zaman bayatlatmıyor.** İlk kural "atladıysam bayattır"
idi ve FAZLA temkinliydi: değişmemiş bir entity'yi atlamak temeli bozmuyor,
çünkü sunucunun yeni temeli eskisiyle aynı. O kuralla duran uzak gemiler her
seferinde tam kayıt alıyordu — yani sıkıştırma bant genişliğini ARTIRIYORDU.

Doğrusu: bayatlatan şey **değişmiş** bir tiki atlamak. İzleyici başına entity
başına bir bit (`ServerShip.staleBaseline`) bunu tam olarak izliyor.

Bu ayrım ikinci ve bedelsiz mekanizmayı açtı: **maskesi boş kayıtları hiç
göndermemek.** Ölçüldü — sakin dünyada kayıtların %89'u boş, kavgada %10.

### Ölçülen

240 oyuncu, botlar birbirine ateş ederken:

| | yumak (SPREAD=600) | dağınık (SPREAD=4000) |
|---|---|---|
| bant genişliği | 51,4 → **49,1** KB/s | 54,9 → **43,1** KB/s (−21%) |
| tik p99 | 48,9 → **23,0** ms | 25,9 → 28,7 ms |
| gecikme p99 | 74,9 → **4,6** ms | — → 4,5 ms |
| durum | KIRIK → **SINIRDA** | SINIRDA |

Yumakta bant kazancı küçük ve olması gereken bu: botların hepsi toplanma
noktasının 600 birim içinde, yani hepsi "her tik" bandında ve hepsi hareketli
— ne oran filtresi ne boş-maske ataması devreye giriyor. Kazanç, mesafelerin
gerçekten dağıldığı senaryoda.

### Tavan nereye gitti

Kademeli tarama (düzeltilmiş kod, botlar ateş ederken):

| oyuncu | Hz | p50 | p95 | p99 | gecikme | KB/s | durum |
|---|---|---|---|---|---|---|---|
| 120 | 30,0 | 10,2 | 11,8 | 18,6 | 5,4 | 28,0 | güvenli |
| 200 | 30,0 | 16,8 | 18,2 | 21,6 | 3,9 | 41,5 | sınırda |
| 260 | 30,0 | 24,9 | 26,9 | 29,8 | 4,2 | 53,4 | sınırda |
| 320 | 29,2 | 33,1 | 35,9 | 38,4 | **242,9** | 61,4 | **kırık** |

Üç durumun karşılaştırması dürüst okunmalı:

| | 240 oyuncu | tavan |
|---|---|---|
| alien savaşı ÖNCESİ | p99 26,5 · sınırda | 240–320 |
| alien savaşı + ekonomi SONRASI | p99 48,9 · **kırık** | ~200 |
| öncelikli replikasyon + maske hoist | p99 ~23 · sınırda | **260–320** |

Yani bu iş, alien savaşının ve ekonominin götürdüğü kapasiteyi **geri aldı** ve
biraz üstüne çıktı. Tavanın kendisi kaymadı — kayan şey, aynı tavanda taşınan
oyun miktarı.

**Ve bant genişliği hâlâ bağlayıcı kısıt.** 260 oyuncuda 53,4 KB/s, yani
saatte ~190 MB. Öncelikli replikasyon bunu yalnız mesafelerin dağıldığı
senaryoda düşürüyor (−%21); gerçek bir kavgada herkes zaten yakın ve oran
filtresi devreye girmiyor. Kavgadaki bant genişliğini düşürecek şey kalan üç
seçenekten biri: snapshot hızını düşürmek, görünür entity sayısına tavan
koymak, ya da ilgi yarıçapını küçültmek. Üçü de oyuncunun GÖRDÜĞÜ bir takas
ve ölçülerek seçilmeli.

### Asıl tik kazancı buradan DEĞİL geldi

Tik p99'undaki %53'lük düşüş öncelikli replikasyonun değil, onu yazarken
görülen bir gediğin sonucu: **`EntityDelta.maskOf` izleyiciden BAĞIMSIZ
olmasına rağmen izleyici başına hesaplanıyordu.** 240 oyuncuda tik başına
57.600 çağrı; artık 240.

Gedik yeni değildi, baştan beri oradaydı — öncelikli replikasyon onu üçe
katladığı için (aday elemesi, bayatlık işaretlemesi, yazma) ölçümde görünür
hâle geldi. Üstelik doğru kural aynı dosyada, `refreshWire`'ın belgesinde
zaten yazılıydı: *"Tik başına BİR kez: değer izleyiciden bağımsız."*
Kuantalama hoist edilmişti, maske edilmemişti.

Ders, bu projede tekrar eden bir desen: **bir optimizasyon eklerken en büyük
kazanç, çoğu zaman o optimizasyonun görünür kıldığı eski bir gedikten
geliyor.**

**Sessizlik tavanı.** İstemci bir saniye (30 tik) duymadığı entity'yi
düşürüyor (`RemoteEntities._staleTicks`). Tavan 18 tik: bant ne olursa olsun
o eşiğe yaklaşan gönderiliyor. Hiçbir aralık tavanı aşmıyor ve bunu da bir
test kilitliyor — ekrandan kaybolan bir gemi, geç güncellenen bir gemiden kat
kat kötü.
