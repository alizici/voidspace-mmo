---
ad: Alienler ve ekonomi (ilk sürüm)
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Alienler ve ekonomi (ilk sürüm)

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.
>
> İki yaratıklı İLK sürümü anlatıyor. Bugün kadro otuz iki yaratık, sekiz bölge (karar 12.7); güncel can, hasar ve ödüller [12 · Düşman Tablosu](../12-dusman-tablosu.md), ekonomi [13](../13-akis-tablosu.md) · [14](../14-ganimet-tablosu.md) · [15](../15-kazanc-tablosu.md) tablolarında.

## Alienler

İki tür var ve bilerek BİRBİRİNİN ZITTI:

| | Void Spore | Void Leviathan |
|---|---|---|
| Can | 1.600 (2 yaylım) | 9.000 (9 yaylım) |
| Yarıçap | 24 | 48 |
| Hız | 97 | 46 |
| Sıklık | 5/6 | **1/6** |

Aynı hızda ve canda ikinci bir tür, çeşitlilik değil yalnız KALABALIK katardı —
oyuncunun ayırt edemediği iki hedef. Leviathan'ın seyrek olması da bir denge
kararı: dokuz yaylım süren bir hedef haritanın yarısını kaplasaydı avlanmak bir
işe dönerdi.

Dağılım DETERMİNİSTİK, konumlar gibi: `Random` kullansaydım sunucu her
açılışta farklı bir harita kurardı ve bir hatayı iki kez görmek imkânsızlaşırdı.

Seçim SATIR VE SÜTUNDAN yapılıyor (`(col + row) % 6`), düz sıradan değil — ve
bunun sebebi yaşanmış bir hata. İlk hâli `index % 6 == 5` idi; ızgara da
`ceil(√36) = 6` sütunlu, yani `col = index % 6`. İki bağımsız görünen modulo
aynı periyodu paylaşınca "her altıncı" tam olarak "hep son sütun" oldu: altı
Leviathan da haritanın sağ kenarına dizildi, doğuş noktasından 4900 birim
uzağa. İlgi yarıçapı 2600 — oyuncu hiçbirini göremedi.

"Sayısı doğru" testi bunu KAÇIRDI çünkü sayı gerçekten doğruydu. Yakalayan tek
şey konum dağılımı oldu; artık iki test bunu kilitliyor (yayılım ve "doğan
oyuncu yakınında görebilir").

**İki tür, iki çizim yolu.** Void Spore prosedürel sanattan pişirilmiş atlasta,
dört katman halinde. Leviathan ise hazır çizilmiş bir sprite şeridi
(8 kare × 256², `idle_hover` döngüsü) ve KENDİ dokusunda:

- Atlas bir ÜRETİM çıktısı (`tool/ship_atlas_test.dart`) ve "depoda kökeni
  bilinmeyen ikili dosya yok" kuralı böyle korunuyor. Leviathan'ın üreteci yok;
  kökeni [`assets/leviathan_strip.README.txt`](../../assets/leviathan_strip.README.txt)
  içinde yazılı. İkisini karıştırmak, iki farklı türden dosyayı tek bir
  "üretilmiştir" iddiasının altına sokardı.
- Atlas zaten 2518×2863 ve mobil GPU'ların 4096 tavanı gözetiliyor; 2048×256'lık
  bir şerit o payı gereksiz yere yerdi.

Maliyeti kare başına TEK fazladan çizim çağrısı (toplam 4 → 5) — ve o çağrı,
ekrandaki Leviathan sayısından bağımsız.

**Bakış yönü telde TAŞINMIYOR.** Void Spore bir küre ve yönü yok; Leviathan'ın
ise açık bir önü var ve yan yan süzülmesi yanlış görünür. Sunucuya bir açı
alanı eklemek en fazla bir bayt ederdi ama gereksiz: istemcinin elinde zaten
ardışık iki konum örneği var — ara değeri onlarla hesaplıyor, yön o iki örneğin
farkı. Görsel bir özelliği tele koymak, hiç ödenmesi gerekmeyen bir bant
genişliği.

Yön yumuşatması OYNATMA SAATİNE bağlı, kare sayısına değil. İlk uygulama kare
başına sabit oran kullanıyordu ve testte yakalandı: 120 fps'lik bir cihaz,
12 fps'likten on kat hızlı dönüyordu — aynı oyun, cihaza göre farklı davranan
bir animasyon. Duran alien için de bir ölü bölge var, yoksa gezinme hedefine
varan yaratık kendi etrafında fırıl fırıl dönüyordu.

## Ekonomi — iki para, tek döngü

Oyunun eksik halkası buydu: mağaza aylardır duruyordu ama **kazanma yolu
yoktu.** Kazanma yolu olmayan bir mağaza bir vitrin; ve alienler karşılık
vermediği için ortada risk de yoktu.

### Alienler artık savaşıyor

| | Void Spore | Void Leviathan |
|---|---|---|
| saldırganlık | kışkırtılmadıkça YOK | menziline gireni kendi seçer |
| hasar / aralık | 120 / 2.0 sn | 600 / 2.5 sn |
| menzil | 700 | 900 |
| ödül | 400 kredi · 1 NOVA | 3.000 kredi · 8 NOVA |

**Riski oyuncu başlatıyor.** Void Spore'nin `aggroRange`'i sıfır: haritada
dolaşan, görmezden gelinebilen bir hedef. Ateş açtığın anda karşılık veriyor
ve peşine düşüyor. Leviathan tam tersi — yanından geçmek bile bir karar.

**Kin SÜRELİ** (12 sn, her vuruşta doluyor). Sonsuz kin, vur-kaç yapan
oyuncunun peşine haritanın öbür ucuna kadar düşen bir alien demekti; süreli
olması "kaçmak işe yarar" kuralını kuruyor, ve kaçmanın işe yaraması girmeyi
bir karar hâline getiriyor.

**Hedef seçimi `Zone`'da, `AlienSim`'de değil.** Çekirdek paket gemileri
görmüyor ve görmemeli: aynı kod istemcide de koşuyor ve orada `ships` diye bir
şey yok. `AlienSim` kararın SONUCUNU taşıyor (hedef kimliği, kin süresi,
namlu sayacı); kararı otorite veriyor.

### İki para birimi

| | KREDİ | NOVA |
|---|---|---|
| kaynak | her imha | her imha, çok daha az |
| ölçek | 12.000 tabanlı | 270 tabanlı |
| ne satın alır | mağazanın gövdesi, bütün gövdeler | S tier eşyalar |
| yükseltme | evet | hayır — yükseltme her zaman kredi |

**Kıt para oyun içinde de KAZANILIYOR ve bu bir incelik değil şart.** Yalnız
parayla alınabilen bir birim, oyuncunun ekonominin parçası saymadığı bir
birimdir; görmediği bir şeyi kazanmaya da çalışmaz. Yeni hesap 500 NOVA ile
başlıyor — miktar değil, ikinci bir birimin VAR OLDUĞU bilgisi için.

**NOVA rafı mağazanın ÜSTÜNE konuyor, İÇİNE değil.** Kredi rafındaki hiçbir
şey taşınmadı ve hiçbir gövde kıt paraya bağlanmadı. Sebep ekonomik değil
tasarımsal: ilerlemenin zorunlu bir basamağı kıt paraya bağlanırsa, oyun
oynayarak ilerleyen oyuncu bir duvara çarpar ve o duvarın adı "öde" olur.
`currency_test.dart` bunu kilitliyor — her yuva için krediyle alınabilir en az
bir eşya olmak zorunda.

**Yükseltme her zaman kredi.** NOVA ile alınan bir eşyanın yükseltmesini de
NOVA'ya bağlamak, oyuncuyu aldığı şeyi geliştiremez hâle getirirdi: kıt para
eşyaya gitmişken yükseltmeye kalmıyor. Kıt para EŞYAYI satıyor, ömrünü değil.

### Ödül zinciri

`Zone` ödül diye bir kavram bilmiyor — orası simülasyon, ekonomi `Gateway`'de.
Atış olayı zaten "kim, kimi, öldürdü mü" taşıyor ve ekonomi ondan türüyor.

- **Oyuncu oyuncuyu öldürünce ödül YOK.** İki hesabı olan biri kendi kendini
  öldürerek para basardı. PvP ödülü ancak kaybedenden bir şey EKSİLTEREK
  dengelenir ve o ayrı bir tasarım.
- **`ServerReward` 19 bayt ve yalnız öldürene gider.** Hangar durumu envanteri
  taşıyan bir JSON; her imhada onu yollamak saniyede onlarca kilobayt ederdi
  ve değişen tek şey iki sayı.
- **Hem kazanç hem BAKİYE taşınıyor.** Kazanç arayüz için ("+400"), bakiye
  gerçek için. İstemci kendi sayacını artırsaydı tek bir kayıp mesaj cüzdanı
  kalıcı olarak ayrıştırırdı — ve para söz konusuyken ayrışma, oyuncunun asla
  affetmediği hata türü.
- **Disk yazımı tik yolunda DEĞİL.** İmha başına bir `flush`, 240 oyuncuda
  saniyede onlarca dosya yazması demekti. Kirli hangarlar beş saniyede bir
  toplu yazılıyor, oturum kapanırken de hemen. Bedeli açık: çökme hâlinde en
  fazla beş saniyelik ödül kaybolur.

### Görülmeyen ödül, olmayan ödül

HUD'da cüzdan ve "+400 KREDİ · +1 NOVA" bildirimi var (`RewardFeed`). Bu
olmadan zincir sunucuda çalışıp oyuncuya ulaşmıyordu: hangara girip bakiyenin
değişmiş olduğunu fark etmek bir geri bildirim değil, bir keşif.

Renk ayrımı her iki ekranda aynı: kredi kehribar, NOVA menekşe.
`economy_test.dart` iki eşlemenin ayrışmadığını doğruluyor — aynı paranın
menüde bir, oyunda başka renk olması oyuncunun neye baktığını karıştırırdı.

Aynı hata ganimette ikinci kez yaşandı: sunucu düşen eşyayı ve malzemeyi
hangara yazıp hangar durumunu yolluyordu, HUD susuyordu. Şimdi imhayla
birlikte `ServerGanimet` gidiyor (protokol 17): düşen eşyaların katalog
kimlikleri, malzemenin rankı ve adedi. Şerit eşyayı rank renginde adıyla,
malzemeyi adediyle yazıyor. İstemci hangar durumunu diff'lemiyor — envanter
satın almayla da değişiyor ve satın alınan parça ganimet değil.

### MMO ölçütlerine karşı denetim

Sistem sektör pratiğine karşı tek tek denetlendi. **Tutan yerler:**

- **Otorite gerçekten sunucuda.** İstemci yalnız "şunu hedefliyorum" ve "ateş
  açık" diyor. Hedefin var olduğu, canlı olduğu, menzilde olduğu, namlunun
  dolu olduğu ve hasarın ne kadar olacağı — hepsi sunucuda, sunucunun
  çözdüğü statlardan. İstemci ne imha uydurabiliyor ne ödeme.
- **Ödül çoğaltılamıyor.** `zone.shots` her tikin başında temizleniyor ve
  `_grantKillRewards` onu tam bir kez tüketiyor. Aynı tikte iki oyuncu aynı
  alieni öldüremiyor: silah döngüsü her atıcı için alienin CANLI durumunu
  okuyor, ikincisi onu ölü buluyor ve ateş etmiyor.
- **Çökmenin yönü güvenli.** Tamponlanmış yazım ödül KAYBETTİRİR, asla
  çoğaltmaz. Ekonomiyi yıkan yön çoğaltmadır.
- **Simülasyon ekonomiyi bilmiyor.** `Zone`'un para diye bir kavramı yok;
  ekonomi `Gateway`'de, atış olayından türüyor.
- **PvP ödülü yok.** İki hesabı olan birinin para basma yolu kapalı.

**Kapatılan eksikler.** Dokuz maddenin sekizi kapandı; dokuzuncusu ölçülerek
elendi.

| # | Eksik | Çözüm | Kaynak |
|---|---|---|---|
| 1 | İşlem defteri yok | `LedgerStore` — yalnız eklenen, tekrarlanan kimliği reddeden defter | çift kayıt muhasebesi |
| 2 | Kazanılan/satın alınan ayrılmamış | `premiumEarned` + `premiumPurchased`, harcamada önce kazanılan gider | ters ibraz pratiği |
| 3 | `earn()` eksiyi yutuyor | `adjust()` — eksiye inebilen, deftere yazılan ayrı işlem | ters ibraz pratiği |
| 4 | Ödül son vuruşa | `ThreatTable.split` — hasar payı, toplam korunarak | 归属判定 |
| 5+6 | Sink ve ölüm bedeli yok | `HullClass.repairCost` — gövde canının %1'i | 装备维修 |
| 7 | Farm sınırı yok | `Fatigue` — saatlik pencere, azalan getiri, sıfıra inmeyen taban | 疲劳度 |
| 8 | Tehdit tablosu yok | `ThreatTable.top` — en çok hasar veren hedef | 仇恨列表 |
| 9 | Alien taraması O(n·m) | **Yapılmadı** — ölçüldü, bütçenin binde ikisi | — |

Birkaç kararın gerekçesi:

- **Bakiye ancak KAYIT ÜRETEREK değişebiliyor.** `Hangar`'ın cüzdan alanları
  gizli; `spend`/`earn`/`adjust` üçü de deftere yazıyor ve yazılmamış kayıtlar
  hangarda birikiyor. Yani "deftere yazmayı unutmak" derleme hatası değil ama
  sessiz de değil: test boşaltılmamış kayıt sayısını ölçüyor.
- **Tek yapı iki soruyu birden cevaplıyor.** Tehdit tablosu hem "kimi
  vuracağım" (仇恨列表) hem "ödül kime" (归属判定) — ikisi de aynı hasar
  sayısından türüyor, MMO'larda olduğu gibi. Tehdit sönüyor (kaçmak işe
  yarar), hasar payı sönmüyor (uzun kavgada ödül sona kaymasın).
- **Ödül payında toplam KORUNUYOR.** Üç oyuncuya 400 krediyi bölerken
  133+133+133 = 399; bir kredi buharlaşır ve milyonlarca imhada görünmez bir
  açığa dönüşür. En büyük kalan yöntemi toplamı birebir tutuyor.
- **Farm sınırı KESME değil eğri.** DNF'in klasik yorgunluk sistemi kota
  dolunca ödülü sıfırlıyor ve oyuncuyu oyundan çıkarıyor. Buradaki eğri hiç
  sıfıra inmiyor (taban 0.1): uzun oynayan cezalandırılmıyor, yalnız marjinal
  kazancı düşüyor. Sert bir tavan ayrıca botun tam tavana kadar farm edip
  durması demekti; sürekli eğride öyle bir nokta yok.
- **Ölüm bedeli BORÇ bırakmıyor.** Alımdaki "ya hep ya hiç" kuralının tersi ve
  sebebi farklı: alımda karşılığında bir mal var, burada yok — bu bir vergi.
  Ödeyemeyeni sıfıra indirmek, borçlu bırakmaktan hem basit hem affedici.
- **Gerçek para ayağı hâlâ YOK** ve defter olmadan açılmamalıydı; artık
  altyapısı var (`LedgerReason.topUp` / `clawback`, ayrı keseler). Eksik olan
  mağaza fişi doğrulaması.

### Simülasyon tik maliyetinin BİNDE BİRİ

Denetim sırasında alien ateşinin topaklandığını bulup düzelttim (bütün
alienler `fireCooldown = 0` ile doğuyor, aralıkları eşit, sonsuza kadar kilitli
adımda). Düzeltmeyi ağ üzerinden ölçmeye çalıştım ve **ölçemedim**: aynı
yapılandırmanın ardışık koşularında 120 oyuncu p95'i 10.6 · 12.5 · 13.4 · 14.1
· 16.4 ms çıkıyor. Ölçülmek istenen fark o aralığın içinde kalıyor, yani yük
testi bu soruya cevap veremiyor.

Doğru araç deterministik bir tezgâh: ağ yok, bot yok, soket yok, aynı girdi.
`server/test/tick_bench_test.dart`:

```
TOPAKLI 44.1 µs · KAYDIRILMIŞ 11.4 µs   (60 gemi, 24 alien)
alien sayısı → tik: 0→5.7 · 24→16.8 · 96→10.7 · 384→77.5 µs
```

Kaydırma simülasyon maliyetini gerçekten düşürüyor (~4 kat) — **ama mutlak
değer 33 mikrosaniye.** Ölçülen sunucu tiki 60 oyuncuda ~5–7 **milisaniye**
idi. Yani:

> **`Zone.step()` — bütün hareket, silah, alien yapay zekâsı ve hedef
> taraması — tik maliyetinin binde biri.** Kalan %99.9 snapshot kodlaması ve
> soket yazması.

Bunun iki sonucu var. Birincisi, kaydırmanın gerekçesi performans DEĞİL
oynanış: altı yaylımın tek karede inmesi, dağıldığında tepki verilebilen bir
şeyi verilemez yapıyor. İkincisi ve daha önemlisi: **simülasyona optimizasyon
yapmak boşa emek.** Kapasiteyi büyütecek her şey — öncelikli replikasyon, ilgi
yarıçapı, delta — snapshot tarafında.

### Gerçek para ayağı YOK

NOVA bugün **yalnız oyun içinde kazanılıyor.** Mağaza uygulamalarıyla
(App Store / Google Play) satın alma; ürün kimlikleri, mağaza hesapları ve
**sunucu tarafında fiş doğrulaması** isteyen ayrı bir iş. Doğrulamasız bir
"satın aldım" mesajı, istemcinin kendine bedava para yazması demek — bu
projedeki her şeyin tersi.
