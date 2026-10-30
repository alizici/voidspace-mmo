# Voidspace

Flutter + Flame uzay MMO'su. Otorite sunucuda, tahmin istemcide, simülasyon
ikisinin **paylaştığı** çekirdekte.

Bir haritada onlarca oyuncu aynı anda uçar, birbirini görür ve vurur.
Tek oyunculu mod **yok** ve olmayacak.

Hedef platformlar: **macOS, iOS, Android.**

## Mimari kuralı

Projedeki tek yapısal karar buydu:

> **Bloc ayrık durumu tutar. Flame sürekli simülasyonu tutar.**

Multiplayer bu kararı bitirmedi, ağ sınırına taşıdı:

> **Bloc ayrık durumu YANSITIR. Flame sürekli simülasyonu ÇİZER.
> `voidspace_core` simülasyonu TANIMLAR. Sunucu gerçeği TUTAR.**

Kuralı ayakta tutan şey katmanların bağımlılık yönü ve bu bir tartışma konusu
değil, [test/architecture_test.dart](test/architecture_test.dart) ile kilitli.

| Katman | Neyi bilmez |
|---|---|
| `packages/voidspace_core/` | hiçbir paketi — Flutter, Flame, Bloc, hatta `dart:ui` |
| `server/` | Flutter'ı, Flame'i, çizimi |
| `server/lib/gateway.dart` | simülasyonu — oyun mantığı `zone.dart`'ta |
| `lib/net/` | Flutter'ı, Flame'i, HUD'ı |
| `lib/game/art/` | durumu: Bloc, çekirdek, bileşenler, ağ |
| `lib/game/components/` | oyun döngüsünü VE taşıma katmanını — yalnız bir *poz* alır |
| `lib/hud/` | simülasyonu — durumu yalnız Bloc'tan okur |
| `lib/ship/` | taşımayı — Bloc bir replika, soketi bilmez |
| `lib/` | sunucu paketini — `voidspace_server` yalnız test bağımlılığı |
| hepsi | kompozisyon kökünü (`app/app.dart`) |

### Neden tek Dart deposu

Simülasyon iki dilde yazılamaz. İstemci gecikmeyi gizlemek için kendi gemisini
önceden oynatır; sunucu otorite olarak aynı adımı koşar. İki taraf **aynı
fonksiyonu** çağırmazsa sonuçlar kaçınılmaz olarak ayrışır ve oyuncu ışınlanır
— netcode'un en pahalı hata sınıfı. `ShipSim.step` tek bir yerde durduğu için
ayrışamaz.

## Ağ modeli — özet

```
istemci → sunucu   girdi çerçevesi, sıra numaralı, 30 Hz
sunucu             sabit 30 Hz tik — TÜM otorite burada
sunucu → istemci   her tik snapshot, ilgi alanı filtreli, delta sıkıştırmalı
istemci            kendi gemin: tahmin + mutabakat (yeniden oynatma)
                   ötekiler: 2–12 tik (66–400 ms) uyarlanan tamponla ara değer
```

Gerekçeler, ölçümler ve yaşanmış hatalar:
[docs/muhendislik/ag-modeli.md](docs/muhendislik/ag-modeli.md).

## Belgeler

**Tasarım: `docs/`.** On sekiz alanın her birinin insanın yazdığı bir kural
belgesi (numaralı, durumlu, sürümlü kararlar), 05 Sağlayıcılar dışındakilerin
de koddan üretilen bir sayı tablosu var. Kod kararları sürümüyle anıyor (`/// KARAR 06.5 s1`); denetim iki
tarafın ayrışmasını yakalıyor.

- [docs/README.md](docs/README.md): belge biçimi, atıf ve denetim kuralları
- [docs/00-harita.md](docs/00-harita.md): karar → kod → test eşlemesi (üretilir)
- [docs/borc-defteri.md](docs/borc-defteri.md): kodlarken açığa çıkan sorular ve borçlar

**Mühendislik günlüğü: `docs/muhendislik/`.** Kararların gerekçesi, yaşanmış
hatalar ve ölçümler; bu README'nin eski anlatı bölümleri. Tarihseldir: sayılar
yazıldıkları günün değerleri. Güncel tasarım sayıları üretilen tablolarda,
güncel davranış kodda.

| Not | Konu |
|---|---|
| [ag-modeli](docs/muhendislik/ag-modeli.md) | tahmin, mutabakat, uyarlanan tampon, delta, öncelikli replikasyon |
| [yasam-dongusu](docs/muhendislik/yasam-dongusu.md) | arka plan, yeniden bağlanma, macOS ve iOS yaşam döngüsü hataları |
| [guvenlik-ve-oturum](docs/muhendislik/guvenlik-ve-oturum.md) | hile karşıtı duruş, hesaplar, belirteç, kimlik seli |
| [kalicilik](docs/muhendislik/kalicilik.md) | JSON Lines depolar, sıkıştırma, işlem defteri |
| [dil](docs/muhendislik/dil.md) | üç dil, `Metin` enum'u, sayı biçimi |
| [sayi-mimarisi](docs/muhendislik/sayi-mimarisi.md) | tasarım alanları, tek tepe tablo, hasar zinciri |
| [hangar-ve-menu](docs/muhendislik/hangar-ve-menu.md) | hangar ve mağazanın ilk sürümü, menü düzeni |
| [alienler-ve-ekonomi](docs/muhendislik/alienler-ve-ekonomi.md) | ilk yaratıklar, iki para, ödül zinciri, MMO denetimi |
| [cizim-mimarisi](docs/muhendislik/cizim-mimarisi.md) | atlas, gemi sayısından bağımsız çizim maliyeti |
| [olcumler](docs/muhendislik/olcumler.md) | ölçüm komutları, kare süresi, sunucu kapasitesi |
| [sinirlar](docs/muhendislik/sinirlar.md) | bilinen sınırlar ve ertelenen işler |
| [dosya-haritasi](docs/muhendislik/dosya-haritasi.md) | eski ayrıntılı dosya haritası (eksik) |

## Kod haritası

```
packages/voidspace_core/   saf Dart çekirdek: simülasyon, protokol, tasarım girdileri, denetim
server/                    otorite sunucusu — Flutter yok, AOT derlenir
lib/                       Flutter istemcisi: app · auth · dil · game · hangar · hud · net · perf · ship
tool/                      üretilen görüntülerin kaynağı (golden testleri) + belge denetimi (tool/belge/)
test/                      tahmin, uçtan uca ağ, mimari, HUD ve belge testleri
docs/                      tasarım belgeleri + muhendislik/ günlüğü
```

Hangi kararın hangi dosyada uygulandığı: [docs/00-harita.md](docs/00-harita.md).

## Çalıştır

En kısa yol — sunucu ve istemci birlikte açılır, **birlikte kapanır**:

```bash
tool/dev.sh -d macos
```

`flutter run` çıktığı anda (`q`, Ctrl-C ya da çökme) sunucu da kapanıyor.
Betik ayrıca ÖNCEKİ koşudan sızmış bir sunucu varsa onu topluyor: `trap`
SIGKILL'i yakalayamaz, ve arkada unutulmuş bir sunucu portu tutup bir sonraki
koşuyu "Address already in use" ile öldürüyordu.

`BOTS=20 tool/dev.sh` yanına bot da koyar; `PORT` ve `ACCOUNTS` değiştirilebilir.
Geliştirme hesapları, hızlı giriş düğmeleri ve oyun açıkken bakiye verme
seçenekleri `tool/dev.sh` başındaki yorumda.

Elle başlatmak için sunucu:

```bash
PORT=8080 dart run server/bin/server.dart
```

Sonra istemci — `VOIDSPACE_SERVER` sunucunun adresi (telefonda `localhost`
DEĞİL, makinenin LAN adresi):

```bash
flutter run -d macos --release --dart-define=VOIDSPACE_SERVER=ws://localhost:8080
```

```bash
flutter run -d <cihaz> --release --dart-define=VOIDSPACE_SERVER=ws://192.168.1.x:8080
```

TLS ile (üretim):

```bash
TLS_CERT=fullchain.pem TLS_KEY=privkey.pem PORT=443 dart run server/bin/server.dart
```

Sertifika verilmezse sunucu düz `ws://` konuşur. Bu varsayılan kasıtlı:
geliştirmede sertifika üretmeye zorlamak, herkesin kendi kendine imzalı bir
sertifika üretip doğrulamayı kapatmasına — yani TLS'i açıp güvenliği
kapatmasına — yol açar.

Sunucu çevre değişkenleri:

| Değişken | Varsayılan | Ne yapar |
|---|---|---|
| `PORT` / `HOST` | `8080` / `0.0.0.0` | dinlenen adres |
| `ACCOUNTS` | `data/accounts.json` | hesap dosyası |
| `HANGARS` | `data/hangars.jsonl` | hangar dosyası: para, gemiler, envanter, donatım |
| `LEDGER` | `data/ledger.jsonl` | işlem defteri — yalnız eklenir, sıkıştırılmaz |
| `CAPACITY` | `64` | zone başına oyuncu tavanı |
| `ALIENS` | `36` | haritadaki alien sayısı |
| `MAX_PER_IP` | `64` | tek IP'den eşzamanlı soket (CGNAT için gevşek) |
| `DEBUG_COMMANDS` | *kapalı* | `HASAR/ONAR` komutları — **üretimde açma** |
| `DEV_RICH` / `DEV_FULL` | — | virgülle ayrılmış hesaplar zengin / tam donanımlı başlar — **yalnız geliştirme** |
| `TLS_CERT` / `TLS_KEY` | — | ikisi birlikte verilirse `wss://` |
| `WEB_ROOT` | — | derlenmiş web istemcisini de sun |

`DEBUG_COMMANDS=true` yalnız geliştirme içindir ve sunucu açıldığında bunu
ekrana basar: `ONAR`, gövdesi ve kalkanı sıfırlanmış ölü bir gemiyi tam
sağlıkla geri getiriyor.

Gecikme altında denemek için sunucunun önüne vekil koy:

```bash
LAG_MS=500 JITTER_MS=200 LOSS=0.02 UPSTREAM=8080 PORT=8081 dart run server/bin/lagproxy.dart
```

Sonra istemciyi 8081'e bağla. Yük botları da oradan geçebilir; iki filoyu
`PREFIX` ile ayır (aynı adlar aynı hesabı paylaşır ve ikinci filo birincinin
oturumunu düşürür), uzak bir sunucuya bağlanmak için `URL` ver:

```bash
PREFIX=Yavas PORT=8081 dart run server/bin/loadtest.dart 8
```

Kapanış hem `SIGINT` (Ctrl-C) hem `SIGTERM` (`docker stop`) ile düzgün
çalışır — eskiden yalnız `SIGINT` dinleniyordu, yani düzgün kapanış tam da en
çok gerektiği yerde, konteynerde, hiç çalışmıyordu.

Platform yapılandırması hazır ve gereklidir: macOS sandbox'ında
`network.client` izni, Android'de `INTERNET` izni (Flutter şablonu bunu yalnız
debug manifestine koyuyor — sürüm derlemesinde olmayınca oyun hiç bağlanamaz),
iOS'ta ProMotion için `CADisableMinimumFrameDurationOnPhone` ve yerel
sunucuya şifresiz bağlanmak için `NSAllowsLocalNetworking`.

### Cihaz seçmek ve sunucu adresi

`tool/dev.sh -d <cihaz>` cihazı çözüyor ve sunucu adresini ONA GÖRE seçiyor.
İkisi de sessiz tuzaktı:

**`-d ios` bir cihaz değil.** `flutter devices` çıktısındaki `ios`, kimlik
değil PLATFORM sütunu; Flutter `-d` ile yalnız kimlik ve ad eşleştiriyor.
`flutter run -d ios` doğrudan *"No supported devices found with name or id
matching 'ios'"* diyor. Betik artık aile adlarını da kabul ediyor ve
SİMÜLATÖRÜ seçip hangisini seçtiğini yazıyor.

**Sunucu adresi cihaza göre değişir.** Sabit `localhost` yalnız bir durumda
doğru:

| hedef | adres | neden |
|---|---|---|
| macOS, iOS simülatörü, tarayıcı | `localhost` | aynı makine |
| Android emülatörü | `10.0.2.2` | emülatörde `localhost` emülatörün KENDİSİ |
| gerçek telefon | Mac'in yerel ağ adresi | telefonda `localhost` telefondur |

Gerçek bir iPhone'da `ws://localhost:8080`, sunucuyu telefonun kendisinde
aramak demekti — ve simülatörde çalıştığı için teşhisi de zordu.

**Platform tarafında iki engel daha vardı**, ikisi de yalnız GERÇEK cihazda
görünüyor:

* iOS 14+ yerel ağa erişimi ayrıca soruyor; `NSLocalNetworkUsageDescription`
  olmadan istek reddediliyor (`ios/Runner/Info.plist`).
* Android 9+ şifresiz trafiği varsayılan olarak kapatıyor. Bayrak
  `android/app/src/debug/AndroidManifest.xml`'de — **yalnız hata ayıklama
  derlemesinde**. Yayın derlemesi kapalı kalmak zorunda; üretimde adres
  `wss://` olacak. Geliştirme için açılan bir kapının yayına sızmasının tek
  güvenilir yolu, kapıyı yayının göremeyeceği bir yere koymak.

### Atlası yenilemek

Sanat kodu değiştiğinde:

```bash
flutter test --update-goldens tool/
```

### Ölçmek

Yük testi, kapasite taraması ve kare süresi ölçüm komutları:
[docs/muhendislik/olcumler.md](docs/muhendislik/olcumler.md), *Nasıl ölçülür*
bölümü.

## Testler

```bash
dart test packages/voidspace_core   # simülasyon + protokol (saniyenin altında)
dart test server                    # otorite, hile kuralları, SALDIRILAR
flutter test                        # tahmin, uçtan uca ağ, mimari, HUD, belge denetimi
flutter test tool/                  # görsel referans + ikon goldenları
```

Her test dosyası türünü başında `@Tags` ile ilan ediyor (türler
`dart_test.yaml`'da). Tek tür `dart test -t aralik` ile koşar; gerçek zamana
bağlı ve yük altında seğirebilen testler `--exclude-tags zaman` ile ayrılır.

Belge ↔ kod denetimi `flutter test` içinde koşuyor (`test/belge_test.dart`);
komut satırından da:

```bash
dart run tool/belge/belge.dart --kuru   # yalnız denetle, dosya yazma
dart run tool/belge/belge.dart          # denetle, üretilen tabloları ve haritayı tazele
```

Testlerin bir bölümü *değişmez* (invariant): bir kuralın makinece okunabilir
hâli. [01 · Savaş Formülü](docs/01-savas-formulu.md) belgesinin değişmezler
tablosu birebir
[`savas_formulu_test.dart`](packages/voidspace_core/test/savas_formulu_test.dart)'ta
duruyor — katman sayısı 6 · her stat tam bir katmana ait · koşullular toplamsal ·
zar ortalaması beklenen değere yakınsıyor · kaçınma hasarı sıfırlamıyor · kalkan
bitmeden gövde eksilmiyor. Bunların hiçbiri "dikkat edelim" değil: bozulduğu an
derleme değil, TEST kırılıyor.

[`server/test/security_test.dart`](server/test/security_test.dart)
ayrı durur: oradaki her test bir davranışı değil bir SALDIRIYI canlandırıyor —
kimlik seli, bağlantı tavanı, çerçeve seli, devasa çerçeve, hata ayıklama
komutu, belirteç ömrü, geri basınç. Çoğu, gerçekten açık olan bir kapıyı
kapattıktan sonra yazıldı.

Bir testin hatayı GERÇEKTEN yakaladığı, düzeltme geri alınarak doğrulanır.
HUD taşma testleri bu şekilde sınandı: düzeltme geri alınınca 7 test kırmızıya
döndü, geri konunca hepsi yeşil.

Uçtan uca testler **gerçek** bir sunucu ve gerçek soketler kullanıyor ve
saniyeler sürüyor. Sahte bir taşıma katmanı, kanıtlaması gereken şeyin
(kodlama, mutabakat, tik zamanlaması) tam olarak yanından geçerdi.
