---
ad: Yaşam döngüsü
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Yaşam döngüsü

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.

## Mobil yaşam döngüsü

Oyun iOS, Android ve macOS için geliştiriliyor — ve mobilde uygulama sürekli
arka plana alınıyor, öldürülüyor, ağ değiştiriyor. Bunların hiçbiri ele
alınmıyordu: kodda tek bir `WidgetsBindingObserver` yoktu.

**Arka plan.** iOS uygulamayı askıya alırken soket kaynaklarını geri topluyor,
yani bağlantı zaten ölüyor — ama sessizce ve yarım. Artık arka plana geçerken
soket BİLEREK kapanıyor (sunucu düzgün bir kapanış görüyor, gemi sahipsiz
bekliyor) ve öne gelince yeniden kuruluyor. `hidden` de sayılıyor: iOS'ta
`paused` bazen hiç gelmiyor.

**Süreler mobile göre.** Sahipsiz bekleme **10 sn → 60 sn**. On saniye bu oyun
için yanlıştı: oyuncu bildirime bakar, WiFi'dan hücresele geçer, asansöre
girer. Uzun bekleme normalde yer israfı olurdu — etmiyor, çünkü zone
dolduğunda **en eski sahipsiz gemi tahliye ediliyor**. Oynayan hiç kimse
etkilenmiyor.

**Zaman aşımı artık silmiyor.** Girdisi kesilen oturumun gemisi doğrudan
siliniyordu (`immediate: true`), yani bekleme süresini tamamen atlıyordu:
kopmanın sebebi soket hatasıysa oyuncuya bir dakika veriliyor, SESSİZLİKSE hiç
verilmiyordu — aynı olayın iki farklı cezası. Artık ikisi de sahipsiz bırakıyor.

**Belirteç diskte.** Mobil işletim sistemi uygulamayı rutin olarak öldürüyor ve
bellekteki belirteç her dönüşte parola ekranı demekti. Anahtarlık değil uygulama
kumbarası kullanılıyor: belirteç 12 saat ömürlü, iptal edilebilir ve depo zaten
uygulamaya özel — anahtarlık korunan şeyin değerine göre orantısız olurdu.
Parola oraya HİÇ yazılmıyor.

Bir sızıntı da bu iş sırasında bulundu: `connect()` içinde el sıkışma
beklenirken arka plana geçilirse soket açılıp AÇIK kalıyordu, kimse okumuyordu.
Mobilde bu sık — bağlanma anı tam da oyuncunun uygulamayı açıp kapattığı an.

## Yaşam döngüsü — üç kusur, aynı belirti

Oyuncunun tarifi tek cümleydi: *"pencereyi büyüttüm, oyun arka plana alınmış
gibi bağlantıyı kesti."* Sunucu günlüğünde bitmeyen bir salınım vardı ve
BOTLAR hiç kopmuyordu — yani sebep ağda değil, istemcinin kendisindeydi:

```
~ CINAR #21 koptu · 60 sn bekliyor
↻ CINAR #21 · 21 oyuncu
~ CINAR #21 koptu · 60 sn bekliyor
```

Arkasında üç ayrı kusur çıktı ve üçü de aynı kökten geliyordu: **istemcinin
canlılığı yanlış şeylere bağlanmıştı.**

**1. `hidden` askıya alıyordu.** macOS'ta ölçüldü: başka bir uygulamaya geçmek
`inactive → hidden` üretiyor, `paused` HİÇ gelmiyor. Yani her alt-tab
bağlantıyı koparıyordu. Flutter'ın kendi durum makinesi `hidden`'ı bir çatal
olarak tanımlıyor (`hidden → paused` ya da `hidden → inactive`), yani tek
başına "askıya alındık" demek değil — ve ara durumlar sentezlendiği için
gerçek bir askıya almada `paused` her zaman geliyor. Karar artık
[`actionFor`](../../lib/app/lifecycle.dart)'da: saf bir eşleme, çünkü gömülü olduğu
sürece sınanamıyordu.

**2. Kimlik ADA bağlıydı.** `ServerAuthOk` yalnız parola yolundan geliyor;
belirteçle dönen istemci yalnız `ServerWelcome` alıyor. Gemi dünyada, ama
istemci kendini "giriş yapmamış" sayıp giriş ekranını gösteriyordu. Sessiz
olan kısmı daha kötüydü: oyun ağacı kurulmayınca kare döngüsü de yok, yani tek
bir girdi çerçevesi bile gitmiyor. Ölçüt artık ad değil KABUL — `ServerWelcome`
almak zaten geçerli bir belirteç sunmuş olmak demek.

**3. Canlılık ÇİZİME bağlıydı.** Girdi de ping de `NetClient.update`'ten
gidiyordu, o da kare döngüsünden. macOS arka plandaki pencerenin çizimini
durduruyor → istemci tamamen susuyor → sunucu on saniyede "girdi yok" diye
düşürüyor. Ölçüm: uygulama arka planda beklerken **35 saniyede 3 kopma/dönüş
turu**. Kalp atışı artık kare döngüsünden bağımsız bir zamanlayıcıda; sunucu da
girdiye değil SESE bakıyor. Çizmeyen bir istemci ölü değildir.

Düzeltmeden sonra ölçüm: **40 saniye arka planda + 8 alt-tab = 0 kopma.**

**iOS'ta da ölçüldü** (iPhone 17 Pro simülatörü) çünkü orada yaşam döngüsü
farklı işliyor: iOS gerçekten `paused` gönderiyor ve askıya alma DOĞRU
davranış — işletim sistemi soketi zaten geri alıyor. Ölçülen dizi:

```
arka plana : inactive → hidden → paused    (tek suspend)
öne gelme  : hidden → inactive → resumed   (tek resume)
```

**Dönüş "geç" düzeliyordu ve sebebi ağ değildi.** Bağlantı kuruluyor, gemi
geri alınıyor — ama gemi kımıldamıyordu. Ölçüm: yeniden bağlandıktan sonra iki
saniyede **0 birim**.

Sebep girdi sıra sayacı. `ServerShip.acknowledgedSeq` gemiyle birlikte
yaşıyordu; istemci ise yeni bağlantıda sayacı 1'den başlatıyor. `enqueue`
kuralı `input.seq <= acknowledgedSeq` olanı atıyor, yani aradaki her çerçeve
SESSİZCE düşüyordu. Saniyede otuz girdiyle, kopmadan önce oynanan her saniye
dönüşte bir saniyelik felç demek — on beş saniye oynayan on beş saniye bekler,
on beş dakika oynayan yarım saat.

Sıra numarası BAĞLANTIYA ait, gemiye değil: `reclaim` gemiyi geri veriyor,
eski girdi akışını değil. Sayaç artık orada sıfırlanıyor (bekleyen kuyrukla
birlikte). Yeniden oynatma savunması zayıflamıyor — o savunma bir oturum
içindeki tekrarları eliyor ve burası yeni bir oturum.

`hidden`'ın HER İKİ yönde de geçtiğine dikkat. Eski kod onu askıya alma
saydığı için uygulama ÖNE GELİRKEN de bir `suspend()` çalışıyordu: macOS'ta
bitmeyen bir kopma döngüsü, iOS'ta her dönüşte az sonra kurulacak bağlantının
boşuna yıkılması. Kural tablosunu tek tek doğrulamak bunu göstermiyor; testte
DİZİNİN kendisi sınanıyor.

Testlerin hiçbiri "bağlanabiliyor mu" diye sormuyor; üçü de kopma OLAYINI
sayıyor. İlk yazışta son duruma bakıyordum ve hiçbir şey kanıtlamıyordu:
oturum düşürülse bile istemci iki saniyede dönüp gemisini geri alıyor, yani
son durum iki hâlde de aynı görünüyor.
