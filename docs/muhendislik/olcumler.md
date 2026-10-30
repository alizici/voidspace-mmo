---
ad: Ölçümler
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Ölçümler

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.
>
> *Nasıl ölçülür* bölümü kök README'nin *Ölçmek* bölümüdür; ölçüm tabloları ölçüldükleri günün kodundan.

## Nasıl ölçülür

Kalabalık üret:

```bash
dart run server/bin/loadtest.dart 40
```

Kapasite taraması — oyuncu sayısını basamaklayıp tavanı arar:

```bash
RAMP=40,80,120,180,240,320,400 HOLD=35 dart run server/bin/loadtest.dart
```

Sunucuyu ayrı veriyle ve gevşek tavanlarla başlatmak gerekiyor, yoksa ölçüm
`CAPACITY` (64) ve `MAX_PER_IP` (64) duvarlarına çarpar — ve o duvarlar
sunucunun kapasitesi değil, yapılandırması:

```bash
PORT=8099 CAPACITY=600 MAX_PER_IP=900 ACCOUNTS=/tmp/yuk.json HANGARS=/tmp/yuk.jsonl dart run server/bin/server.dart
```

Yayılma da bir ölçüm parametresi: `SPREAD=600` (varsayılan) herkesi tek
yumakta toplar, `SPREAD=4000` haritaya dağıtır. İkisi farklı sorular soruyor —
bkz. *Kapasite: tek bölge nereye kadar*.

Ölçüm derlemesi — HUD'a kare süresi satırı koyar ve konsola yazar:

```bash
flutter run -d <cihaz> --release --dart-define=VOIDSPACE_SERVER=ws://192.168.1.x:8080 --dart-define=PERF_LOG=true
```

Gerçek Android sayısı **fiziksel cihazda** alınmalı: emülatörün ölçtüğü şey
oyun değil, kendi çeviri katmanı.

## İstemci — kare süresi

Hepsi bu depoda üretilebilir (bkz. *Nasıl ölçülür*). Kare süresi, motorun kendi
ölçümünden (`addTimingsCallback`) alınıyor ve **UI ile raster ayrı** — bu
ayrım olmadan başarım tahmindir:

* **UI (Dart) uzun** → simülasyon, tahsis, çöp toplama. Çözüm kod tarafında.
* **Raster (GPU) uzun** → çizim çağrısı, `saveLayer`, blur. Çözüm çizim
  tarafında.

### macOS Release · 41 gemi ekranda

```
UI 0.6/1.1 ms · GPU 0.9/1.6 ms · 120 Hz · takılma %0.0
```

Bütçe 8.3 ms; iki iş parçacığı da onun sekizde birini kullanıyor.

### Kök nedene giden ölçüm

Yol boyunca yapılan tek şey, tahmin etmek yerine **ölçüp bisect etmekti.**
macOS Release, aynı sahne, 41 gemi:

| Yapılandırma | UI | GPU | Sonuç |
|---|---|---|---|
| 5 gemi prosedürel çiziliyor | 3.3 ms | **40.0 ms** | 30 Hz, %97 takılma |
| 1 gemi prosedürel (yalnız seninki) | 1.1 ms | **8.7 ms** | 90 Hz |
| hepsi atlastan | 0.9 ms | **0.9 ms** | **120 Hz, %0** |

Yani **prosedürel çizilen tek bir gemi 8 ms GPU harcıyordu** — 120 Hz
bütçesinin tamamı. Sebep, gemi başına kare başına iki `saveLayer` +
`ImageFilter.blur` ve yirmiden fazla ayrı `MaskFilter.blur`; bunlar
tile-based bir mobil GPU'daki en pahalı işlerdir.

Bu tabloda "en yakın birkaç gemi tam kalitede çizilsin" gibi bir kalite
kademesinin yeri yok: **beş gemi zaten 40 ms.** Tek kalıcı çözüm prosedürel
çizimi kare yolundan tamamen çıkarmaktı.

### Diğer hedefler

| Platform | Ölçüm | Not |
|---|---|---|
| iOS 26 simülatörü (debug) | UI 2.3 · GPU 1.3 ms · %0 | UI değeri JIT'ten; release'de düşer |
| Android emülatörü | GPU 16.4 ms · içerikten BAĞIMSIZ | ölçüm geçersiz — aşağıya bak |

Android emülatörünün sayısı oyunu ölçmüyor: **tek gemiyle de 41 gemiyle de
16.4 ms** çıkıyor, yani ölçülen şey emülatörün OpenGL ES → Metal çeviri
katmanı. (Varsayılan yapılandırmada durum daha kötü: emülatör SwiftShader'a,
yani CPU yazılım rasterleştiricisine düşüyor ve boş bir bağlantı ekranı bile
47 ms sürüyor.) Gerçek Android sayısı ancak fiziksel cihazda alınır —
komutu *Nasıl ölçülür* bölümünde.

## Sunucu — tik ve bant genişliği

### Sunucu — 41 oyuncu, hepsi birbirini görürken

```
41 oyuncu · 30.0 Hz · tik ort 3.1 ms tepe 10.5 ms / 33.3 ms bütçe (%9.4)
          · oyuncu başına 14.5 KB/s ↓
```

Boşta tik maliyeti ~40 µs. Sunucu tik hızını hiç kaybetmedi.

### Sunucu — 60 bot, hepsi ateş ederken (güvenlik katmanı eklendikten SONRA)

```
60 oyuncu · 30.0 Hz · tik ort 5.9 ms tepe 13.7 ms / 33.3 ms bütçe (%17.6)
          · oyuncu başına 27.7 KB/s ↓ · ~2900 atış yazıldı
```

Hız sınırı, IP tavanı ve geri basınç kontrolü ölçülebilir bir maliyet
getirmedi: sayılar güvenlik katmanı öncesindeki 64 oyuncu ölçümüyle (6.0 ms,
%18) aynı. Hiçbir snapshot atlanmadı, yani **60 gerçek istemcinin hiçbiri
yanlışlıkla "yavaş" sayılmadı**.

## Kapasite: tek bölge nereye kadar

Soru mimari: **çok bölgeli yapıya (zone-per-isolate) geçmek gerekiyor mu?**
Cevap ancak tek bölgenin tavanı ölçülünce verilebilir — ve o tavan bugüne
kadar ölçülmemişti. `CAPACITY=64` bir yapılandırma satırıydı, ölçülmüş bir
duvar değil.

**Ölçüm aracının kendisi önce doğrulandı.** Kapasite ölçümünün en yaygın
hatası, yük üretecinin sunucudan önce tıkanması: tek makinede koşan bir üreteç
50–200 sanal oyuncudan sonra kendi olay döngüsünde boğulur, botlar girdi
göndermeyi bırakır, sunucu daha az iş yapar ve ölçüm **"her şey yolunda"**
der. Yani araç, sınırı bulmak yerine sınırı gizler. Gil Tene'nin *koordineli
ihmal* (coordinated omission) dediği şeyin yük üreteci tarafındaki hâli.
İki savunma kuruldu:

- **Çok isolate.** Botlar `ISOLATES` (varsayılan: çekirdek − 2) isolate'e
  bölünüyor. İki çekirdek işletim sistemine ve sunucuya bırakılıyor; üreteç
  makineyi doldurursa ölçülen şey sunucunun kapasitesi değil makinenin olur.
- **Üretecin KENDİ saati ölçülüyor.** Bot saati açık döngü: `gerçek −
  hedeflenen`. Bu sayı bir tiki (33.3 ms) aşarsa rapor **ÜRETEÇ TIKALI —
  sunucu ölçümü GEÇERSİZ** yazıyor. Aşağıdaki koşuların hiçbirinde aşmadı
  (p95 4–6 ms, yapısal taban 4 ms'lik yoklama aralığı).

**Sunucu tarafında ortalama bırakıldı, yüzdelik alındı.** "Tik ortalama 6 ms"
cümlesi, tiklerin yüzde birinin 40 ms sürdüğü bir sunucuda da doğrudur — ve
oyuncunun hissettiği tam olarak o yüzde bir (30 Hz'de dakikada 18 takılma).
`LatencyHistogram` tahsissiz kova sayacıyla p50/p95/p99/max veriyor.

**Ve tik İŞİ ile tik GECİKMESİ ayrıldı.** Bu ayrım ölçümün belkemiği çıktı:
320 oyuncuda sunucu hâlâ **29.9 Hz** raporluyordu, çünkü biriktirici geride
kalan tikleri arka arkaya koşturup açığı kapatıyor. Yalnız Hz'e bakan bir
ölçüm "sunucu sağlam" derdi. Gecikme ise 222 ms — simülasyon çeyrek saniye
geriden geliyor. Kırılma noktasını gösteren sayı bu oldu.

### Ölçülen — 10 çekirdekli MacBook, sunucu ve botlar AYNI makinede

Botlar birbirine ateş ediyor, her basamak 35 sn tutuluyor, ilk iki rapor
penceresi (ısınma) atılıyor, basamak değeri pencerelerin medyanı.

| oyuncu | Hz | p50 | p95 | p99 | gecikme p99 | KB/s/oyuncu | durum |
|---|---|---|---|---|---|---|---|
| 40 | 30.0 | 3.4 | 5.4 | 7.7 | 4.6 | 12.4 | güvenli |
| 80 | 30.0 | 7.1 | 8.0 | 8.6 | 4.9 | 19.8 | güvenli |
| 120 | 30.0 | 9.6 | 10.6 | 13.6 | 12.9 | 28.0 | güvenli |
| 180 | 30.0 | 14.5 | 16.3 | 24.8 | 4.6 | 40.9 | güvenli |
| 240 | 30.0 | 21.0 | 22.9 | 26.5 | 5.0 | 52.5 | **sınırda** |
| 320 | 29.9 | 31.6 | 34.7 | 39.4 | **222.6** | 67.5 | **kırık** |
| 400 | 21.7 | 43.5 | 48.7 | 54.0 | 247.7 | 80.9 | kırık |

Süreler ms; bütçe 33.3 ms. "Kırık" ölçütü: p99 bütçeyi aşıyor **ya da**
gecikme bir tiki geçiyor **ya da** Hz 29.5'in altına düşüyor.

### Oyuncular DAĞILINCA ne değişiyor — neredeyse hiçbir şey

Yukarıdaki koşuda botlar tek yumakta (`SPREAD=600`): herkes herkesi görüyor,
ilgi alanı hiçbir şey elemiyor. Bu en kötü hâl. Gerçek bir bölgede oyuncular
dağınık olur, o yüzden ikinci koşu `SPREAD=4000` ile tekrarlandı:

| oyuncu | yumak p50 / görünür | dağınık p50 / görünür |
|---|---|---|
| 40 | 3.4 ms / 39 | 4.2 ms / 30 |
| 120 | 9.6 ms / 102 | 9.8 ms / 79 |
| 240 | 21.0 ms / 203 | 21.8 ms / 193 |
| 320 | 31.6 ms / 282 | 33.6 ms / 282 |
| 400 | 43.5 ms / 348 | 48.0 ms / 325 |

**Fark yok** — ve sebebi ölçüyle açıklanıyor: ilgi alanı yarıçapı 2600, dünya
12000×8000. Bir ilgi diski 21.2M birim², yani dünyanın **%22'si**. Oyuncular
dağılsa bile birbirlerinin ilgi alanından çıkamıyorlar.

Bunun mimari sonucu doğrudan: **ilgi alanı bu haritada işini yapmıyor.**
Kapasiteyi artırmanın en ucuz yolu çok bölgeli mimari değil, önce şu ikisi —
haritayı büyütmek ya da ilgi yarıçapını düşürmek. İkisi de bir sabit
değiştirmekten ibaret ve ikisi de ölçülebilir.

### Bant genişliği CPU'dan ÖNCE bitiyor

Oyuncu başına 52.5 KB/s (240 oyuncu) demek, saatte **190 MB** demek. Mobil bir
oyunda 5 GB'lık bir paket 26 saatte biter; sunucu tarafında 240 oyuncu 12.6
MB/s (101 Mbit/s) giden trafik eder. CPU tavanı 240–320 iken bant genişliği
çoktan sorun olmuş durumda.

Sebep aynı: snapshot maliyeti GÖRÜNÜR entity sayısıyla doğru orantılı, ve
görünür sayı oyuncu sayısına eşit. Standart çözüm çok bölge değil, **öncelikli
replikasyon**: yakın entity'ler her tik, uzaklar seyrek; kapasite aşılırsa
dondurmak yerine sırayla (round-robin) göndermek. Delta ve kaydırmalı anahtar
kare altyapısı zaten kurulu.

### Karar

Çok bölgeli mimari **şimdilik ertelendi.** Gerekçe ölçüm: bugün tek bölge
güvenli 180, sert tavan 240–320 oyuncu taşıyor ve eşzamanlı gerçek oyuncu
sayısı sıfır. Ondan önce sırasıyla: oyun döngüsü (alien savaşı + kredi),
ilgi yarıçapı/harita ölçüsü, öncelikli replikasyon, kalıcılık. Çok bölge
bunların hiçbirinin yerine geçmiyor; hepsinin üstüne geliyor.

**İki sayı çıkıyor, biri değil:**

- **Sert tavan ~240–320 oyuncu.** 240'ta p99 bütçenin %80'i ve sunucu hâlâ
  tam hızda; 320'de saat geriye düşüyor.
- **Güvenli işletim kapasitesi ~180.** Ölçüt p95'in bütçenin yarısının
  altında kalması. Pay keyfi değil: gerçek oyuncular botlardan düzensiz, çöp
  toplayıcı duraklar, ve bütçesini tamamen doldurmuş bir sunucunun hiçbir
  sürprize yeri yoktur. Sektör pratiği de aynı yerde duruyor — "bir dakikadaki
  tiklerin %5'inden fazlası bütçeyi aşıyorsa incele".
