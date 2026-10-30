---
ad: Bilinen sınırlar ve sıradaki adımlar
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Bilinen sınırlar ve sıradaki adımlar

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.
>
> Bir maddeyi "sıradaki adım" diye önermeden önce kodda doğrula: bu listenin ilk maddesi bir süre bayat kaldı ve yapılmış bir iş yeniden önerildi.

- ~~**Alien'ler delta'sız.**~~ **YAPILDI** — ve bu satır bir süre BAYAT kaldı.
  Ölçüldü (`server/test/wire_budget_test.dart`): 240 alien kaydının 240'ı
  kısmi, sıfırı tam; kayıt başına ortalama 4,0 bayt (tam kayıt 8). Notun bayat
  kalması gerçek bir zarar verdi: yapılmış bir iş "sıradaki adım" diye
  önerildi ve ancak koda bakınca fark edildi.
- **İlgi alanı O(n²) — ve uzamsal ızgara ÖLÇÜLEREK elendi.** Doğruluk şartı
  hücre boyunun çıkış yarıçapından (2989) küçük olmaması; 12000×8000'lik
  dünyada bu yalnız 5×3 = 15 hücre demek ve bir 3×3 komşuluk dünyanın **%75'ini**
  kaplıyor. Yani ızgara taramanın en fazla dörtte birini eler — ölçülen maliyet
  400 gemide bütçenin %4.3'ü olduğuna göre kazanç ~%1. 九宫格 deseni ilgi
  yarıçapı dünyaya göre küçükken parlıyor; bizde ilgi alanı dünyanın %22'si.
  Harita büyürse, yarıçap düşerse ya da mermilerle entity sayısı birkaç bine
  çıkarsa yeniden değerlendirilir.
- **Değişmeyen kayıt yine de 3 bayt.** Bir entity'nin "hiçbir şey değişmedi"
  demesi bile kimlik + maske ediyor. Fırsatın büyüklüğü dünyanın ne kadar
  hareketli olduğuna bağlı ve ÖLÇÜLDÜ: sakin dünyada kayıtların %89'u
  değişmiyor, herkesin hareket ettiği kavgada yalnız %10. Kapasite ölçümündeki
  52,5 KB/s ikinci koşuldan geliyor — yani "değişmeyeni hiç gönderme" iyi bir
  iş ama kavgadaki bant genişliğini kurtaran şey değil. İstemci tarafı hazır:
  `RemoteEntities._staleTicks` bir saniyelik sessizliğe dayanıyor.
- ~~**Öncelikli replikasyon YOK.**~~ **YAPILDI** — bkz. [ağ modeli](ag-modeli.md),
  *Öncelikli replikasyon*.
- **Taşıma WebSocket (TCP).** Tarayıcıda başka seçenek yok ve bu ölçekte
  yeterli. Yerel istemcilerde KCP ya da WebTransport ortalama gecikmeyi
  %30-40, tepe gecikmeyi üç kat düşürür — asıl kazanç ise sunucunun coğrafyası.
- **Tek zone — ölçülen tavan 240–320 oyuncu.** `Zone` bir sınıf, süreç değil:
  ikinci harita kendi isolate'inde koşacak ve bu dosyaların hiçbiri
  değişmeyecek. Ama sıradaki adım o değil: ölçüm, ilgi alanının bu haritada
  hiçbir şey elemediğini ve bant genişliğinin CPU'dan önce bittiğini gösterdi
  (bkz. [ölçümler](olcumler.md), *Kapasite: tek bölge nereye kadar*).
- **Hesap dosyası tek süreçlik.** `data/accounts.json` doğru çalışıyor ama
  ikinci sunucu süreci açıldığı gün biter — iki süreç aynı dosyaya yazamaz.
- **Oturum belirteci sunucuda bellekte.** Sunucu yeniden başlayınca herkes
  yeniden giriş yapar. İstemci tarafında belirteç artık DİSKTE (bkz. [yaşam
  döngüsü](yasam-dongusu.md)).
- **İlerleme kalıcı değil.** Hesap kalıcı ama gemi durumu değil: sunucu
  yeniden başladığında herkes doğuş noktasında, tam gövdeyle başlar.
- **Atlas ayrık kademeler taşıyor.** İtki dört kademe (çapraz sönümleniyor),
  titreşim altı kare (gidip geliyor). Yakından bakıldığında prosedürel
  sürümdeki sürekli gürültü yerine kısa bir çevrim var. Kare eklemenin
  maliyeti yalnız doku belleği.
- **Atlas 2518×2863, çözüldüğünde ~29 MB.** Piksel oranı düşük cihazlarda
  daha küçük çözülüyor. Mobil GPU'ların 4096 piksel tavanı gözetildi.
- **Android gerçek cihazda ölçülmedi.** Emülatörün sayısı geçersiz (yukarıda).
  macOS ve iOS aynı Impeller/Metal arka ucunu kullanıyor; Android'de arka uç
  Vulkan ve orada da doğrulanmalı.
- **Gerçek geri basınç yok.** `dart:io`'nun WebSocket'i kuyruğunda bekleyen
  bayt miktarını AÇMIYOR, yani "istemci yetişemiyor" durumu doğrudan
  ölçülemiyor. Bugünkü savunma dolaylı ama işe yarıyor: bir saniye hiç çerçeve
  göndermeyen istemciye snapshot yığılmıyor, konuşmaya başlayınca akış geri
  geliyor. Gerçek çözüm ham soket ya da farklı bir taşıma.
- **Sunucuda geri sarma (回溯) yok.** Menzil kontrolü hedefin ŞU ANKİ konumunu
  kullanıyor ([`Zone._resolveWeapons`](../../server/lib/zone.dart)), istemcinin
  gördüğü konumu değil. Ölçüldü ve bu oyunda etkisi KÜÇÜK: menzil 1400, hız
  320, atış aralığı 1.1 sn — iki görüşün uyuşmadığı süre 160 ms'de 118 tikte 3,
  400 ms'de 108 tikte 13. Kaybolan yaylım ~0.

  FPS'lerde geri sarma şart çünkü isabet anlıktır ve hedef bir piksel; burada
  hedef kilitli ve menzil geniş. Silah tasarımı değişirse (mermi uçuşu, dar
  koni, anlık isabet) bu sıralama değişir — o gün gereken altyapı hazır:
  `LagProxy` ile ölçüm, snapshot'ta tik numarası.

  Geri sarmanın bedeli de kayıtlara geçsin: düşük pingli oyuncu cezalanır
  ("siperin arkasında öldüm"), ve Çin kaynakları telafiyi 200–300 ms ile
  sınırlamayı öneriyor tam da bu yüzden.
- **Parola değiştirme yok.** Hesap oluşturulduktan sonra parolası
  değiştirilemiyor — depo bunu destekleyecek biçimde (satır ekleyerek, son
  satır kazanır) ama ne protokolde ne arayüzde karşılığı var.
