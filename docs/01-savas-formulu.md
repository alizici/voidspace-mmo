---
alan: 1
ad: Savaş Formülü
katman: savaş
tur: kural
surum: 1.2
tablo: 01-savas-sayilari.md
kaynak: https://claude.ai/code/artifact/c47f4081-92f5-4612-ad33-9bd7b1d10520
---

# 01 · Savaş Formülü

Hasarın taban değerden nihai sayıya kadar geçtiği zincir, katmanların sırası, ve zincirin nasıl büyüyeceği. Bir statın hangi katmanda olduğu, kaç puan verdiğinden çok daha önemlidir. Bu belge o katmanları ve sıralarını sabitliyor; sayılar ayrı belgede.

Kök alan, hiçbir alana bağlı değil. Bu belgeye bağlı: 02 · 03 · 04 · 09 · 12 · 16. Sayı tablosu: [01 · Savaş Sayıları](01-savas-sayilari.md).

Sürüm 1.2: PvP katsayısı kodda bulundu (01.7): zincir onu son çarpan olarak okuyor, sunucu hedef oyuncuysa geçiyor; belge "uygulanmıyor" derken bayatlamıştı. Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. Sayı tablosunun 1.0'da alan 04'ü bekleyen iki sabiti (K zırh, K sıyırma) çözüldü ve üretilen tabloda. PvP katsayısı o gün belgedeydi.

## 01.1 · Altı katman, sabit sıra
Durum: kodda · s1 · DamageChain.layerCount, StatLayer

| Katman | Hesap | Ne |
|---|---|---|
| L0 | taban = Σ lazer taban hasarı | Çarpan değil, başlangıç. Takılı her lazerin taban hasarı toplanır; yuva boşsa gemi ateş edemez. |
| L1 | × (1 + Σ hasar artışı) | Toplamsal. Ekipmanın ana yeri. |
| L2 | × (1 + Σ koşullu bonuslar) | Ayrılmış, bugün boş. |
| L3 | × (1 + k · (d − 1)) | Kritik beklenen değeri; k şans, d çarpan. |
| L4 | × (1 − azaltma) × (1 − kafes etkisi) | Savunma. İkinci çarpan ayrılmış, bugün 1. |
| L5 | + son hasar − son azaltma | Düz ekleme, bütün çarpanlardan sonra. |
| UYG | önce kalkan, taşan gövde | Formülün dışında (01.3). |

Altı katman ve sıraları sabit. İkisi bugün boş ama listede duruyor; sonradan katman eklemek ile önceden ayrılmış katmanı doldurmak arasında büyük fark var (01.6).

## 01.2 · Katmanların ne tür stat aldığı
Durum: kodda · s1 · StatLayer, DamageChain.resolve

Yeni bir yüzdesel saldırı statı L1'e girer, kendi katmanını açmaz. Bütün koşullu statlar ("boss'a karşı", "kritik ısıda", "canı düşük hedefe") L2'ye ve yalnız L2'ye girer, toplamsal. Kritik statları L3'te. Karşı stat kafesi geldiğinde L4'ün ikinci çarpanına girer, yeni katman açmadan; zırh ve kalkan delme L4'te azaltmayı düşürür. Set bonusu, ArGe, unvan statı hangi statı veriyorsa o katman. Referans oyuncunun zırhtan gördüğü azaltma `zirhAzaltmaHedefi = 0,3`.

L5 düz eklemesi küçük tutulur: payı `sonHasarTavani = 0,1`'i geçemez, geçerse zincirin geri kalanı anlamsızlaşır. L2 ve L4'ün ikinci çarpanı kodda da sabit 1 olarak duruyor: çarpılıyor ama hiçbir şeyi değiştirmiyor; kafes geldiği gün zincirin şekli değişmeyecek.

## 01.3 · Önce kalkan, taşan kısım gövde
Durum: kodda · s1 · ShipSim.applyDamage

Zincir bir sayı üretir; o sayının nereye gittiği ayrı bir karar. Bunu formülün içine katmamak önemli, çünkü aynı hasar sayısı üç ayrı yerde kullanılıyor: havuzlara uygulanırken, ekranda hasar rakamı olarak, ve BR hesabında beklenen çıktı olarak. Üçü aynı sayıyı görmezse oyuncunun gördüğü rakam ile aldığı hasar sessizce ayrışır ve bu, oyuncunun asla affetmediği hata türü.

Kalkan ve gövde ayrı havuzlar, tek bir birleşik can değil. Kalkan yenilenir, gövde yenilenmez (tamir gerekir); kalkan sürdürülebilirlik, gövde hata payı. Zırh azaltması (L4) her ikisine de havuza girmeden önce uygulanır; zırh kendi başına bir havuz değil, havuzların çarpanıdır.

## 01.4 · Kritiğin iki biçimi
Durum: kodda · s1 · CritMode, Prd

Çalışma anında gerçek zar: sarı büyük rakam görmek oyunun hissi, beklenen değerle oynanan bir oyunda kritik diye bir şey yoktur. Denge ve BR'de beklenen değer 1 + k(d − 1): tek bir sayı gerekir, zar atan bir formülle ne bütçe kurulur ne BR hesaplanır. İkisi aynı katmandan (L3) beslendiği sürece sorun yok; sorun birinin diğerinden habersiz değişmesi, o yüzden ikisi de bu belgeye bağlı. Referans `kritikSansiReferans = 0,25` (dört yaylımda bir) ve `kritikCarpaniReferans = 2` (tam iki katı, ekranda okunması en kolay çapa).

Kritik zarı bağımsız atılmıyor: sahte rastgele dağılım (PRD). Bağımsız zar oyuncuların bir kısmına uzun kritik kuraklıkları yaşatır ve o oyuncu sistemin bozuk olduğunu düşünür. PRD sabiti şanstan sayısal çözülür ve garantili bir kritik tabanı verir; ölçüm tabloda.

## 01.5 · Iskalama yok, sıyırma var
Durum: kodda · s1 · SavunmaEgrileri.siyirma, ShipStats.graze

Klasik MMORPG'de isabet ve kaçınma ikili bir zardır. Bu oyunda çalışmaz ve sebebi tasarım değil görsel: mermiler gerçek zamanlı uçuyor ve oyuncu merminin gemiye çarptığını görüyor. Çarpan bir merminin "ıskaladın" demesi, ekranın söylediğiyle sistemin söylediğinin çelişmesi; oyuncu bunu hile ya da hata olarak okur, haklı olarak.

Kaçınma statı var ama ikili değil sürekli: hasarı sıfırlamaz, azaltır. Yüksek kaçınma sıyırma üretir; mermi çarpar, hasar düşük gelir, rakam soluk gösterilir. Tavan `siyirmaTavani = 0,4`: hasar asla sıfırlanmaz. Referansta `siyirmaHedefiReferans = 0,15`, zırhın yarısı; ikisi kardeş ama zırh baskın. Aynı gerekçeyle isabet statı yok; kaçınmanın karşı statı ileride kafes içinde gelecek.

## 01.6 · Genişleme kuralı: katman sayısı artmaz
Durum: kodda · s1 · DamageChain.layerCount sabit

Sistemin ömrünü belirleyen kural iki cümle: **katman sayısı asla artmaz, katmanların içeriği sınırsız büyür.** Yeni bir çarpım katmanı açmak oradaki her statı diğer bütün katmanların üstüne çarpar; o stat anında oyunun en değerlisi olur ve kütüphanenin geri kalanı ikinci sınıfa düşer. Bir kez açılan katman geri kapatılamaz, çünkü kapatmak herkesin build'ini bozar. Yeni stat eklemek ise serbest ve bedava; her muhtemel stat mevcut bir katmana girer (01.2). Tek gerçek yasak "nadir hasar çarpanı" gibi tek başına bir çarpan: bir statın kendi katmanını hak ettiğini düşündüğün an o stat zaten dengesizdir, L1'e toplamsal konduğunda aynı işi patlamadan yapar.

## 01.7 · PvE ↔ PvP tek formül, tek katsayı
Durum: kodda · s1 · DamageChain.resolve son çarpan; Zone hedef oyuncuysa pvpCarpani geçiyor

PvP haritaları geldiğinde ilk refleks ayrı bir formül yazmak olur. Yapılmayacak: iki formül, iki denge problemi ve zamanla iki farklı oyun demek. Formül aynı; PvP'de zincirin sonuna tek bir katsayı uygulanır, `pvpCarpani = 1`. Bugün etkisiz, çünkü doğal PvP TTK'sı zaten hedef bantta; kol duruyor, çekilmiyor. Kafes statları geldiğinde ayrım biraz derinleşecek (kafes NPC'lere karşı zayıf, oyunculara karşı tam) ama bu bile ayrı formül değil, aynı formülde bir çarpanın hedefe göre değişmesi. Katsayı tepe tabloda tanımlı ve zincir onu son çarpan olarak okuyor; sunucu hedef oyuncuysa onu, yaratığa karşı 1 geçiyor. PvP haritası yok; kol takılı, çekilmiyor. Belge bir süre "zincirde okuyan yer yok" dedi ve bayattı: belgede durumu ile atıfsız kod denetime tutarlı görünür, o boşluğu yalnız okuyan insan yakalar.

## 01.8 · Sözlük: yaylım · DPS · EHP · TTK
Durum: kodda · s1 · CombatGlossary

| Terim | Tanım | Nerede |
|---|---|---|
| Yaylım | Takılı bütün lazerlerin tek seferde verdiği toplam hasar (L5 sonrası) | Oyuncuya gösterilen birim |
| DPS | Yaylım ÷ atış aralığı | 12 düşman canı · 09 saldırı kanalı |
| EHP | (kalkan + gövde) ÷ (1 − azaltma)(1 − sıyırma) | 12 düşman hasarı · 09 dayanıklılık kanalı |
| TTK | Hedefin EHP'si ÷ saldıranın DPS'i | 11 harita zorluğu · 16 denetim |
| Referans build | Bir seviyenin "normal" oyuncusu | 04'te tanımlanır, her yerde kullanılır |

Bu terimler sözlük maddesi değil, sözleşme. "Boss 40 saniyede ölsün" cümlesinin anlamı TTK'nın tanımına bağlı; tanım tek yerde durduğu sürece 11, 12 ve 16 aynı şeyi konuşuyor.

## Sınır

Sahiplenmediği: hangi statların var olduğu → 02 · bir statın kaç ettiği → 03 · taban statlar ve referans build → 04 · harita başına zorluk hedefi → 11 · düşman canı ve hasarı → 12 · taban hasarı çarpan mermi → 17. Bu belgede sayı yok; katman sırası yılda bir bile değişmez, sabitler her denge turunda değişir.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Katman sayısı = 6 | Biri yeni çarpım katmanı açtı; zincirin tamamı yeniden dengelenmeli. |
| Her stat tam bir katmana ait | Katmansız stat var; nereye çarpıldığı belirsiz. |
| Koşullu statların hepsi L2'de | Bir koşullu stat kendi katmanına kaçmış. |
| Kritik: zar ortalaması ≈ beklenen değer | Çalışma anı ile denge ayrışmış; BR ve bütçe yanlış. |
| Kaçınma hiçbir zaman hasarı 0 yapmaz | İkili ıskalama geri gelmiş. |
| Kalkan bitmeden gövde eksilmez | Havuz sırası bozulmuş; kalkan statları değerini kaybetmiş. |
| L5 payı ≤ sonHasarTavani | Düz ekleme zinciri ele geçirmiş. |
| Bu belgede türetilmiş sayı yok | Sabit sızmış; aynı sayı iki yerde duruyor. |
