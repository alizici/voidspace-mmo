---
ad: Güvenlik, hesaplar ve oturum
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Güvenlik, hesaplar ve oturum

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.

## Hile karşıtı duruş

İstemci **hiçbir sonucu** hesaplamaz, yalnız niyet yollar. Bu kod tabanında
somut karşılıkları:

- Hasar, kalkan, itki şarjı: yalnız sunucuda ([`ShipSim`](../../packages/voidspace_core/lib/src/sim/ship_sim.dart)).
- Tik başına **tam bir** girdi; fazlası düşer, eskisi ve tekrarlanmışı atılır.
- İlgi alanı filtresi bant genişliği için değil **maphack** için: görmediğin
  şey sızdırılamaz.
- Bozuk çerçeve istisna fırlatmaz, bağlantıyı kapatır.
- Eksen **normalleştirilir**: `axis: (1000, 0)` yollamak hız kazandırmaz.
- Silahın menzili, atış hızı, hedefin geçerliliği ve yaşadığı **sunucuda**
  doğrulanır; kendine ateş edilemez, ölü gemi ateş edemez.

Denetimden çıkan ve **ölçülerek doğrulanan** üç açık şunlardı:

| Açık | Ölçüm | Kapanış |
|---|---|---|
| Kimlik denemesi sınırı etkisizdi | tek karede 60 deneme → **60'ı da** işlendi, her biri ayrı isolate'te 120 bin tur | sayaç `await`'ten ÖNCE artıyor + oturum başına aynı anda tek türetme + sızdıran kova |
| `ONAR` hata ayıklama komutu herkese açıktı | ölü gemi (0 gövde / 0 kalkan) **tek çerçeveyle** 12000/8000'e ve `alive: true`'ya döndü | üretimde kapalı (`DEBUG_COMMANDS`), düğmeler HUD'dan kaldırıldı |
| Kopan oyuncunun gemisi savaşmaya devam ediyordu | fiş çekildikten 60 tik sonra hedefin kalkanı 7000 → **6000** | sahipsiz gemi komut tekrarlamaz; dünyada ve vurulabilir kalır |

Bunların üstüne, ölçülmeden de kapatılması gereken kapılar: **tek IP'den**
eşzamanlı soket tavanı, oturum başına **çerçeve hızı** sınırı (sızdıran kova),
**4 KB** çerçeve tavanı, belirteç **son kullanma tarihi** (12 saat) ve hesap
başına **tek geçerli belirteç**. Hepsinin testi
[`server/test/security_test.dart`](../../server/test/security_test.dart) içinde ve
her biri saldırıyı canlandırıyor.

**Yanlış pozitif, saldırıdan pahalıdır.** IP tavanı 8 değil **64**: bu bir
mobil oyun ve operatörler CGNAT kullanıyor — bir bölgedeki yüzlerce abone tek
bir genel IP'nin arkasından çıkabiliyor. Sekizlik bir tavan saldırganı değil,
aynı operatördeki dokuzuncu oyuncuyu dışarıda bırakırdı. Aynı sebeple
"normal hızda oynayan istemci ASLA düşürülmez" ayrı bir test.

## Hesaplar ve oturum

Dünyaya giden tek yol kimlik doğrulamadan geçiyor. `ClientHello` artık serbest
bir AD değil bir BELİRTEÇ taşıyor: ad hesaptan geliyor, yani istemcinin
söylediği bir şey değil sunucunun bildiği bir şey.

**Parola.** PBKDF2-HMAC-SHA256, 120.000 tur, hesap başına rastgele tuz. Yavaşlık
özellik: parola listesi deneyen birinin her denemesi bu kadar sürer. Türetme
**ayrı bir isolate'te** koşuyor — ana isolate oyun tikini çeviriyor ve orada
100 ms'lik bir hesap dünyayı üç tik durdururdu.

Kimlik kodunda "sonra düzeltiriz" diye bırakılan şey düzeltilmiyor, sızıyor.
Bu yüzden baştan yapılanlar: sabit zamanlı hash karşılaştırma, kullanıcı adı
sayımına karşı sahte türetme (olmayan hesap için de parola türetilir), oturum
başına deneme sınırı, ve kayıt/giriş mesajlarının `toString`'lerinin parolayı
BASMAMASI.

**Kopan oyuncu gemisini kaybetmez.** Bağlantı koptuğunda gemi silinmiyor,
60 saniye **sahipsiz** bekliyor (ilk sürümde 10'du; bkz. [yaşam döngüsü](yasam-dongusu.md)); aynı hesap dönerse aynı gemiye — aynı konum,
aynı savaş — kavuşuyor. Süre dolarsa gerçekten gidiyor.

Sahipsiz gemi **komut tekrarlamaz**: ne ateş eder ne uçar. Bu ölçülerek
bulundu — seviye tetikli `firing` korunduğu için, fişi çeken oyuncunun gemisi
hedefini dövmeye devam ediyordu. Klavyeyi bırakmış bir oyuncuyla ağı kopmuş
bir oyuncu aynı şey değil: birincinin niyeti "devam", ikincinin niyeti
bilinmiyor. Gemi yine de dünyada ve **vurulabilir** kalır — kopmak kalkan
olsaydı, kaybedilen her düelloda fişi çekmek bir taktik olurdu. Hesap başına tek
oturum: ikinci cihazdan giriş birinciyi düşürür ve düşen oturum bunu ÖĞRENİR
(sessizce kesilmek oyuncuya "oyun dondu" gibi görünür).

**Bayat belirteç bir RED değil.** Belirteçler yalnız bellekte yaşıyor, yani
sunucunun her yeniden başlaması hepsini geçersiz kılıyor — ve `tool/dev.sh`
bunu her `flutter run`'da yapıyor. Yani bu, geliştirmede istisna değil KURAL.

Eskiden sunucu bu duruma `ServerRejected` deyip **soketi kapatıyordu** ve üç
kusur birleşip bir çıkmaz kuruyordu:

1. İstemci kapalı bir kanalla giriş ekranını gösteriyordu.
2. Oyuncunun giriş çerçevesi o kapalı kanala düşüyor, `_send` sessizce
   yutuyordu.
3. Faz sonsuza kadar `authenticating` kalıyor, düğme kapanıyordu.

Oyuncunun gördüğü şey **"ilk girişte oyuna girmiyor, ikinci girişte
giriyor"** idi — ikincisi çalışıyordu çünkü uygulama yeniden başlarken bayat
belirteç silinmiş oluyordu. Aynı kusurun ikinci yüzü daha kötüydü: oturum
biterken **ad silinmediği** için arayüz oyun ekranında kalıyor, oyuncu gemisiz
ve snapshot'sız donmuş bir dünyada, giriş ekranına ulaşamadan bekliyordu —
"takılıyor, hareket ettiremiyorum, sanki bağlantı sorunu" tarifi buydu.

Üçü de kapatıldı: sunucu `ServerAuthError` diyip **soketi açık bırakıyor**
(oyuncu aynı kanaldan giriyor, fazladan tur yok), kimlik yolu gerekirse
bağlantıyı kendisi kuruyor ve gönderemezse fazı serbest bırakıyor, reddedilen
belirteçle birlikte ad da siliniyor. `test/session_recovery_test.dart` üçünü
ayrı ayrı kilitliyor; kapının kendisi (`uydurma belirteçle gemi alınamaz`)
`security_test.dart` ve `auth_test.dart` içinde duruyor.

**Ölüm geçici.** Gövdesi biten gemi 5 saniye sonra doğuş noktasında geri
geliyor — öldüğü yerde değil, çünkü orada onu öldüren hâlâ duruyor olurdu.
Girdi kuyruğu temizleniyor, yoksa oyuncu doğar doğmaz son hamlesiyle
sürüklenirdi.

## Kimlik seli altında — aynı anda 60 oyuncu oynarken

30 saniye boyunca **58.800 giriş denemesi**:

```
60 oyuncu · 30.0 Hz · tik ort 5.0-6.5 ms / 33.3 ms bütçe (%15-19)
```

Tik hızı düşmedi, oyuncu düşmedi. Düzeltmeden önce aynı yükün her denemesi
ayrı bir isolate'te 120 bin turluk PBKDF2 başlatıyordu.

Saldırgan istediği 20 soketten yalnız **4'ünü** açabildi: 60 bot zaten aynı
IP'den bağlıydı ve IP tavanı (64) geri kalanını reddetti. Bu, tavanın
çalıştığının kanıtı — ve aynı zamanda CGNAT uyarısının somut hâli: aynı
adresi paylaşan meşru oyuncular da aynı havuzdan yer alır.
