---
ad: Tasarım alanları ve sayı mimarisi
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Tasarım alanları ve sayı mimarisi

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.
>
> Kuralların kaynağı artık alan belgeleri: [01 · Savaş Formülü](../01-savas-formulu.md), [16 · Denge Denetimi](../16-denge-denetimi.md); kararların kodu [tasarım haritasında](../00-harita.md). Referans build'in güncel sayıları [01 · Savaş Sayıları](../01-savas-sayilari.md) tablosunda.

Tasarım belgeleri **on sekiz alana** (ilk bölümlemede on altıydı; 17 Mermi ve 18 Roket sonra geldi) bölündü ve her alan iki belge yazıyor:
*kural belgesi* (NE ve NEDEN — nadiren değişir) ve *sayı tablosu* (NE KADAR ve
HANGİ ORANDA — her denge turunda değişir). Sektörde bu bir meslek ayrımı:
系统策划 ve 数值策划 farklı kişilerdir, farklı çıktı üretirler.

İkisini aynı dosyada tutmanın bedeli şu: bir katsayıyı oynatmak için gerekçeyi
de açman gerekir, ve gerekçe zamanla sayıya uydurulmaya başlar — tersi değil.

Alanlar dört katmana yığılı ve **sıra bir tercih değil**: her katman bir üstünün
BİRİMİYLE konuşuyor. Savaş ölçü birimini verir, Büyüme referans build'i, Dünya
hedef zorluğu, Ekonomi öldürme hızını. Boss canı referans build olmadan, düşüş
oranı da boss canı olmadan türetilemez.

| Katman | Alanlar |
|--------|---------|
| Savaş | 01 Savaş Formülü · 02 Stat Kütüphanesi · 03 Stat Değeri · 04 Gemi ve Yuvalar |
| Büyüme | 05 Sağlayıcılar · 06 Eşya Kurgusu · 07 Güçlendirme · 08 Güç Bütçesi · 09 Savaş Puanı · 10 İlerleme |
| Dünya | 11 Haritalar · 12 Düşman Kurgusu |
| Ekonomi | 13 Kaynak Akışı · 14 Ganimet · 15 Kazanç · 17 Mermi · 18 Roket |
| Denge | 16 Denge Denetimi |

Harita `TasarimHaritasi`'nda kod olarak duruyor — bir belge olarak değil, çünkü
denetlenmesi gereken şey tam olarak bu. Her alanın bağımlılık listesi orada ve
[`test/tasarim_mimarisi_test.dart`](../../test/tasarim_mimarisi_test.dart) üç şeyi
birden kırıyor: olmayan bir alandan okumak (yabancı anahtar), aşağıdaki bir
alandan okumak (`下一层级只能引用上一层级`), ve döngü.

## Tek tepe tablo

Elle girilen HER tasarım parametresi
[`tasarim_girdileri.dart`](../../packages/voidspace_core/lib/src/design/tasarim_girdileri.dart)'ta,
tek bir yerde. Türetilen hiçbir sayı orada duramaz — onlar
[`Turetilenler`](../../packages/voidspace_core/lib/src/design/turetilenler.dart)'de
**hesaplanan alan** olarak yaşıyor ve üstlerine yazılabilecek bir alan yok.
Çince kaynakların Excel'de renkle yaptığı ayrımın koddaki karşılığı bu: girdi
`const`, türetilen hesap.

Savaş katmanının o tabloya koyduğu satır sayısı **yedi**. Zincirin başka
hiçbir yerinde elle yazılmış bir sayı yok: kritik PRD sabiti de, zırh eğrisinin
K'sı da, sıyırma eğrisi de bu yediden türüyor.

**Mimarinin tek gerçek ihlali** türetilmiş bir değeri kaynağa sabit yazmak.
Diğer bütün hatalar bir sayının yanlış olduğunu söyler; bu, sistemin bozulduğunu
söyler — kaynağı değiştirmek artık o değeri değiştirmiyor demektir. Bir test
bütün kaynağı tarayıp bu sayıları arıyor.

## Hasar zinciri — altı katman, sabit sıra

```
L0  taban   = Σ takılı lazerin taban hasarı        yuva boşsa gemi ateş edemez
L1  × (1 + Σ hasar artışı)                         toplamsal — ekipmanın ana yeri
L2  × (1 + Σ koşullu bonuslar)                     AYRILMIŞ — bugün 1
L3  × (1 + k·(d−1))  ya da  × d                    kritik: beklenen değer / zar
L4  × (1 − azaltma) × (1 − kafes etkisi)           kafes AYRILMIŞ — bugün 1
L5  + son hasar − son azaltma                      payı en fazla %10
───
UYG önce kalkan, taşan kısım gövde                 formülün DIŞINDA
```

**Katman sayısı asla artmaz, katmanların içeriği sınırsız büyür.** Yeni bir
çarpım katmanı açmak, oradaki her statı diğer bütün katmanların üstüne çarpar —
o stat anında oyunun en değerlisi olur ve kütüphanenin geri kalanı ikinci sınıfa
düşer. Bir kez açılan katman geri kapatılamaz, çünkü kapatmak herkesin build'ini
bozar. Yeni **stat** eklemek ise serbest ve bedava; hangi katmana gireceği
`StatLayer`'da zaten yazıyor.

İki katman bugün BOŞ ama zincirde duruyor: L2 (koşullu bonuslar) ve L4'ün ikinci
çarpanı (protokol kafesi). Çarpılıyorlar ama hiçbir şeyi değiştirmiyorlar.
Maliyeti sıfıra yakın, kazancı büyük — kafes geldiği gün zincirin şekli
değişmeyecek, yalnız bir çarpan 1 olmaktan çıkacak.

**Kritik iki biçimde birden var.** Çalışma anında gerçek zar (sarı büyük rakam
görmek oyunun hissi; beklenen değerle oynanan bir oyunda kritik diye bir şey
yoktur), dengede ve BR'de beklenen değer `1 + k(d−1)` (zar atan bir formülle ne
bütçe kurulur ne BR hesaplanır). İkisi aynı katmandan besleniyor ve bir test
uzun vadeli zar ortalamasının beklenen değere yakınsadığını ölçüyor.

Zar **bağımsız değil**: PRD (sahte rastgele dağılım). Bağımsız zar, oyuncuların
bir kısmına uzun kritik kuraklıkları yaşatır ve o oyuncu sistemin bozuk olduğunu
düşünür — haklı olarak. Sabit `C` elle yazılmıyor, ilan edilen orandan sayısal
olarak çözülüyor; çözücü Valve'ın yayımladığı Dota 2 sabitlerini birebir
üretiyor ve bunu bir test doğruluyor. %25 için `C = 0,084744`, garantili kritik
**12 yaylımda**.

**Iskalama yok — sıyırma var.** Mermiler gerçek zamanlı uçuyor ve oyuncu
merminin gemiye çarptığını görüyor; çarpan bir merminin "ıskaladın" demesi,
ekranın söylediğiyle sistemin söylediğinin çelişmesi demek. Kaçınma statı ikili
değil sürekli: hasarı sıfırlamaz, azaltır — ve rakam soluk çizilir. Matematiksel
olarak zırhın kardeşi: ikisi de L4'te, aynı doyum eğrisinde, farklı K ile. Aynı
gerekçeyle **isabet statı yok**; karşılığı olmayan bir savunma statı kütüphaneye
ölü bir satır eklemekten başka bir şey yapmaz.

**PvE ↔ PvP tek formül.** İki formül, iki denge problemi ve zamanla iki farklı
oyun demek. PvP'de zincirin sonuna tek bir katsayı uygulanıyor (`pvpCarpani`) ve
bugün 1,00 — çünkü doğal PvP TTK'sı zaten hedef bantta (güncel değeri [01 · Savaş Sayıları](../01-savas-sayilari.md) tablosunda). Kol duruyor,
çekilmiyor.

## Sözlük — bu oyunun savaş terimleri

Beş terim bütün alanlarda aynı anlama gelmek zorunda; bunlar sözlük maddesi
değil **sözleşme**. "Boss 40 saniyede ölsün" cümlesinin anlamı TTK'nın tanımına
bağlı.

| Terim | Tanım |
|-------|-------|
| Yaylım | Takılı bütün lazerlerin tek seferde verdiği toplam hasar (L5 sonrası) |
| DPS | Yaylım ÷ atış aralığı |
| EHP | (kalkan + gövde) ÷ (1 − azaltma)(1 − sıyırma) |
| TTK | Hedefin EHP'si ÷ saldıranın DPS'i |

Tanımların kaynağı karar 01.8; referans build'deki güncel değerler koddan üretilen [01 · Savaş Sayıları](../01-savas-sayilari.md) tablosunda.

O tablodaki sayıların hepsi **ölçülen**, yazılan değil:
[`savas_sayilari_test.dart`](../../packages/voidspace_core/test/savas_sayilari_test.dart)
onları koddan hesaplayıp sayı tablosunun ilan ettiğiyle karşılaştırıyor; yaratıkların TTK'sı da aynı tabloda.

## Alan 04'ü bekleyen iki sabit

**Güncelleme:** iki sabit alan 04 yazılınca çözüldü (`Turetilenler.kZirh` ve sıyırma karşılığı); değerleri [01 · Savaş Sayıları](../01-savas-sayilari.md) tablosunda. Aşağıdaki metin çözülmeden önceki hâli anlatıyor.

`Kzırh` ve `Ksıyırma`, referans build tanımlanmadan sayıya dönüşemiyor — çünkü
"referansta %30 azaltma" cümlesi, referansın zırhının kaç olduğunu bilmeyi
gerektiriyor. İkisi de `null` olarak duruyor, tahmin edilmiş bir değerle değil:
tahmin edilen bir sabit, alan geldiğinde kimsenin geri dönüp düzeltmediği bir
sabittir.

Bu bir eksik değil, mimarinin çalıştığının kanıtı — bağımlılık gizli kalmıyor,
adı konmuş bir `null` olarak bekliyor. Bir test şunu da kilitliyor: eğri
çözülmemişken hiçbir varlık zırh ya da kaçınma TAŞIYAMAZ.

## Zincire geçerken düzelen iki hata

**Yaylım beş katına çıkıyordu.** `LoadoutResolver` takılı bütün lazerlerin taban
hasarını topluyor, sonucu `laser.damage`a yazıyordu; `volleyDamage` ise onu yuva
sayısıyla BİR KEZ DAHA çarpıyordu. Tek lazerle uçan bir oyuncu beş lazerlik
hasar veriyordu ve hiçbir belge o sayıyı öngörmüyordu. L0'ın tanımı ("Σ TAKILI
lazerin taban hasarı") hatayı tanımı gereği imkânsız kılıyor — uçtan uca test
düzeltmeyle birlikte 1000'den 200'e düştü, yani oyuncunun gerçekten sahip olduğu
güce.

**Katman disiplini belgede vardı, kodda yoktu.** `StatLayer` tanımlıydı ve
hiçbir yerden çağrılmıyordu; katman matematiği `LoadoutResolver` içinde elle
yazılmıştı ve zincirin bir kopyasıydı. Artık her stat kendi katmanının alanına
yazılıyor, çarpımı tek bir yer yapıyor. Bu arada `StatLayer.rare` — "nadir hasar
çarpanı" — silindi: kural belgesinin tek gerçek yasağı, tek başına bir statın
kendi çarpım katmanını açması.
