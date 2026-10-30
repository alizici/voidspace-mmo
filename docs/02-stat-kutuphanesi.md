---
alan: 2
ad: Stat Kütüphanesi
katman: savaş
tur: kural
surum: 1.4
tablo: 02-stat-kaydi.md
kaynak: https://claude.ai/code/artifact/69fdd74c-0c61-417e-9644-f0805f2ee9de
---

# 02 · Stat Kütüphanesi

Bir statın kimliği neyden oluşur, hangi birimle ölçülür, hangi şartla kütüphaneye girer ve nasıl büyür. Motor stat isimlerini bilmez, yalnız kaydı okur. Yeni bir stat eklemek motoru değiştirmiyorsa, kütüphane doğru kurulmuş demektir.

Bağımlılık: 01 katman ve kanal tanımları. Bu belgeye bağlı: 03 · 04 · 05 · 06 · 09. Kayıt tablosu: [02 · Stat Kaydı](02-stat-kaydi.md), koddan basılır; tasarlanan yirmi iki kimlik 02.7'de ve test ikisini satır satır karşılaştırır.

Bu belgede sayı yok ve olmayacak: kütüphane sayısal değil kategorik bir tablo. Kaç ettikleri alan 03'ün işi. Bu alanın tepe tabloya katkısı sıfır girdi ve bu bir eksiklik değil, alanın doğası.

Sürüm 1.4: `kalkan` droid kapsamı da aldı (02.7 s2) — droide giren iki eşyadan biri kalkan jeneratörü (05.4 s5) ve kapsam alanı artık "bu statı kim taşıyabilir" sorusunun tek yetkilisi. Sürüm 1.3: kayıt sekiz alana çıktı, birim üç tip, eş zorunlu, ayrılmış yedi kimlik kayıtta kapalı, itki dolumu açıldı; 02.2, 02.4, 02.5, 02.6 ve 02.7 kodda. Kapsam adları tasarımın diline döndü (gemi · droid · küresel), P.E.T. gitti. Sürüm 1.2: kritik hasarının kimliği karara bağlandı (02.8), kod belgeye uydu. 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı.

## 02.1 · Kimlik ile etiket ayrı; katman ve kanal 01'den
Durum: kodda · s1 · StatDef

Diske yazılan ve tel üzerinde giden şey kimlik; etiket yalnız ekranda ve serbestçe değişir. Etiket yarın Türkçeden başka bir dile çevrilse hiçbir kaydın bozulmaması gerekiyor. Katman (zincirde nereye çarpıldığı) ve kanal (saldırı · savunma · sistem; BR bunu kullanır) alan 01'den geliyor; bu belge onları kullanır, tanımlamaz.

## 02.2 · Kayıt alanları: birim, kapsam, eş, altStat
Durum: kodda · s1 · StatDef sekiz alan, StatBirimi.uygula, ItemBudget.turevAdimi

Tasarlanan kayıt sekiz alan: kimlik, etiket, katman, kanal, birim, kapsam, eş, altStat. Birim üç tip:

| Birim | Uygulama | Ne için |
|---|---|---|
| mutlak | havuz += değer | Doğrudan eklenen puan: taban hasar, gövde canı, kalkan |
| oran | katmanda toplanır, × (1 + Σ) | Yüzdesel: hasar artışı, atış hızı, hız |
| egri | d / (d + K) → oran | Mutlak puan girer, oran çıkar; doyan savunma statlarının tek doğru biçimi: zırh, kaçınma |

Kural: birim kaydın parçasıdır ve motor onu okumak zorundadır. Bir statın nasıl uygulanacağını çağrı yerindeki kod değil, kaydın kendisi belirler. Bu üçlü ayrım bir incelik değil, bir zamanlar aynı anda yaşanan iki hatanın panzehiri: kalkan mutlak ilan edilip oran gibi uygulanıyor, gövde canı mutlak uygulanıp oran gibi fiyatlanıyordu.

Kodda kayıt sekiz alan; katman, kanal, birim ve eş kurucuda zorunlu olduğu için eksik kayıt derlenmiyor. Birim üç tip ve uygulaması tek yerde: çözümleyici havuz statlarını kaydın birimiyle uyguluyor, süre statlarında oran böler; eğri statlar ham puan olarak geçip gemi statlarında doyum eğrisinden çıkıyor, K'ları alan 04'ün türetileni. Fiyat türevinin adımı da aynı kaydı okuyor (03.6). Arayüzün "yüzde mi" sorusu ayrı bir bayrak değil, birimden türüyor; eğri statın ham puanı gösteriliyor. Kalkan ve gövde canı hataları kapandı.

## 02.3 · Kapsam sistemi ve çift sayım savunması
Durum: kodda · s2 · StatScope, StatVector.key

Droid'e takılan bir hasar artışı çipi geminin hasarını artırmamalı; tersi de geçerli, geminin bonusu droid sayısıyla çarpılıp patlamamalı. Çözüm, stat kimliğini tek başına yeterli saymamak: kimlik + kapsam birlikte bir yuva tanımlar. `hasar_artisi@gemi` ile `hasar_artisi@droid` iki farklı sayıdır; ayrı toplanır, ayrı gösterilir. Kapsamın anahtarın parçası olması çift sayımı bir hata olmaktan çıkarıp imkânsız hâle getiriyor: yanlış kapsama yazmak isteyen kodun anahtarı da yanlış üretmesi gerekir. Üçüncü kapsam roket (18.1): roketatarın taban hasarı `taban_hasar@roket`, lazerinki `taban_hasar@gemi`; ikisi aynı zincirin başına farklı silahlar olarak giriyor, aynı anahtara asla.

İki sert kural: hiçbir hasar statı küresel olamaz, ve kapsamlar arası tek geçiş yolu aktarım katsayısıdır (σ, alan 05). Başka her sızıntı yolu bir hatadır ve fark edilmesi aylar sürer, çünkü sonucu yalnız "droid build'i çok güçlü" gibi bulanık bir şikâyet olarak görünür.

Kapsam adları tasarımın dilinde: `gemi`, `droid`, `kuresel`; P.E.T. kaldırıldı. Kapsam diske yazılmadığı için ad değişikliği veri kırmadı. İkinci kilit kayıtta: her stat yazılabileceği kapsamları taşıyor ve vektör kapsam dışına yazmayı reddediyor. Yanlış kapsama yazmak isteyen kodun artık hem anahtarı yanlış üretmesi hem kaydı değiştirmesi gerekir.

## 02.4 · Giriş şartı: eşi olmayan stat kütüphaneye giremez
Durum: kodda · s1 · StatDef.es zorunlu; test eşin kütüphanede olduğunu doğrular

Bir statın uzun ömürlü olmasının tek yolu, marjinal değerinin başka bir statın artan fonksiyonu olması. Yoksa o stat doyar, doyduğu an ölür ve kütüphanede bir ölü satır olarak kalır. Üç eşleşme türü var ve bir statın en az birine sahip olması zorunlu:

| Tür | Nasıl çalışır | Bugün |
|---|---|---|
| Build içi eş | İki stat aynı çarpımda buluşur; birine yatırım diğerinin türevini büyütür | kullanılabilir |
| Karşı stat | Rakibin savunma statını doğrudan iptal eder; ikisi bir fark olarak hesaplanır | kayıtta ilan (son hasar ↔ son azaltma); fark hesabı kafesle gelecek |
| Taşma hedefi | Doyan statın fazlası tanımlı oranla başka stata akar | kafesle gelecek |

Kafes henüz yok, dolayısıyla açık statlar build içi eşle giriyor: kritik şansı ↔ kritik hasarı, zırh ↔ gövde canı, atış hızı ↔ taban hasar, hız ↔ itki dolumu; son hasar ile son azaltma karşı stat olarak birbirini gösteriyor, fark hesabı kafesle. Bu yeterli ama geçici; kalıcı çözüm karşı stat ve o PvP olgunlaştığında gelecek. Eş kayıtta zorunlu alan: eşsiz bir stat derlenmiyor, eşi kütüphanede olmayan bir stat testi kırıyor ve "eşini bul ya da statı ekleme" kararı o an veriliyor. Kafes geldiğinde geriye dönük düzeltme yok.

## 02.5 · Genişleme şartları
Durum: kodda · s1 · StatDef kurucusu dört şartı zorunlu kılıyor

Yeni bir stat eklemek tek bir kayıt satırı; motorun hiçbir yeri değişmiyor. Satırın geçerli olması için dört şart: **katmanı var** (alan 01'in katmanlarından biri, yeni katman açılmıyor), **birimi var** (mutlak, oran ya da eğri ve motor ona göre uyguluyor), **eşi var** (02.4), **ölçülebilir bir kanala bağlı** (saldırı, savunma ya da sistem, yani BR'ye giriyor). Dördüncü şart en çok atlananı: ölçülebilir kanala bağlanmayan stat birkaç ay içinde ölü stattır, çünkü oyuncu onu kıyaslayamaz, denge onu göremez, kimse ona yatırım yapmaz.

Kodda dört şart da kurucuda zorunlu: katmanı, birimi, eşi ya da kanalı olmayan kayıt derlenmiyor; eşin ve fiyatın var olduğunu test doğruluyor. Kanal şartının ikinci yarısı, kanalın gerçekten savaş puanına girmesi, 09'un işi (09.5).

## 02.6 · Ayrılmış kimlikler
Durum: kodda · s1 · Stats.ayrilmis, kapalı yedi kayıt

Kafesle birlikte gelecek statlar kayıt tablosunda şimdiden yazılı ama kapalı: delici, zırh katmanı, kırıcı, sertlik, kritik direnci, durum hasarı, durum azaltma. Hiçbir sağlayıcı onları veremez, hiçbir eşya havuzunda yoklar. Yazılı durmalarının sebebi kimliklerini rezerve etmek: kafes geldiğinde kimlik çakışması ya da yeniden adlandırma olmayacak, ve o güne kadar hangi boşluğun doldurulacağı görünür kalacak.

Kodda yedisi ayrı bir listede: açık kimlik aramasına girmiyorlar, dolayısıyla havuz ya da ana stat olarak yazıldıkları an yabancı anahtar testi kırılıyor; fiyatları yok, bütçe onlara dağıtamıyor. Katman ve eşleri 02.7'de ilk yerleşim; kafes yazılırken bu karar yeniden açılır.

## 02.7 · Kayıt tablosu: yirmi iki kimlik
Durum: kodda · s2 · Stats.all on beş açık, Stats.ayrilmis yedi kapalı; test tabloyu kayıtla satır satır karşılaştırır

Tasarlanan kütüphane yirmi iki kimlik: on beşi açık, yedisi ayrılmış (02.6). Katman 01'in kodu (L0…L5), kanal savaş puanının kanalı, birim 02.2'nin üç tipi, eş 02.4'ün türü (`karşı:` öneki karşı stat, öneksiz build içi eş).

| Kimlik | Katman | Kanal | Birim | Kapsam | Eş | Alt stat |
|---|---|---|---|---|---|---|
| taban_hasar | L0 | saldırı | mutlak | gemi · droid · roket | hasar_artisi | — |
| hasar_artisi | L1 | saldırı | oran | gemi · droid | taban_hasar | ✓ |
| atis_hizi | L1 | saldırı | oran | gemi · droid | taban_hasar | ✓ |
| kritik_sansi | L3 | saldırı | oran | gemi · droid | kritik_hasari | ✓ |
| kritik_hasari | L3 | saldırı | oran | gemi · droid | kritik_sansi | ✓ |
| son_hasar | L5 | saldırı | mutlak | gemi | karşı: son_azaltma | ✓ |
| govde_cani | L0 | savunma | mutlak | gemi · droid | zirh | ✓ |
| kalkan | L0 | savunma | mutlak | gemi · droid | kalkan_yenilenmesi | ✓ |
| kalkan_yenilenmesi | L1 | savunma | oran | gemi | kalkan | ✓ |
| zirh | L4 | savunma | egri | gemi · droid | govde_cani | ✓ |
| kacinma | L4 | savunma | egri | gemi | zirh | ✓ |
| son_azaltma | L5 | savunma | mutlak | gemi | karşı: son_hasar | ✓ |
| hiz | L1 | sistem | oran | gemi | itki_dolumu | ✓ |
| itki_dolumu | L1 | sistem | oran | gemi | hiz | ✓ |
| menzil | L1 | sistem | oran | gemi · droid | hiz | ✓ |

Ayrılmış yedi (02.6), kapalı. Katman ve eş ilk yerleşim: üç karşı-stat çifti kafesin iki yüzü, kritik direnci kritik şansının karşısı, durum çifti koşullu katmanın ilk kiracısı. Kafes yazılırken 02.6 yeniden açılır ve bu satırlar değişebilir.

| Kimlik | Katman | Kanal | Birim | Kapsam | Eş | Alt stat |
|---|---|---|---|---|---|---|
| delici | L4 | saldırı | oran | gemi · droid | karşı: sertlik | ✓ |
| sertlik | L4 | savunma | egri | gemi · droid | karşı: delici | ✓ |
| kirici | L4 | saldırı | oran | gemi · droid | karşı: zirh_katmani | ✓ |
| zirh_katmani | L4 | savunma | egri | gemi · droid | karşı: kirici | ✓ |
| kritik_direnci | L3 | savunma | oran | gemi · droid | karşı: kritik_sansi | ✓ |
| durum_hasari | L2 | saldırı | oran | gemi · droid | karşı: durum_azaltma | ✓ |
| durum_azaltma | L2 | savunma | oran | gemi · droid | karşı: durum_hasari | ✓ |

Menzil sistem kanalında: alan 03 buldu, ∂DPS/∂menzil = 0, hasarı artırmıyor. Kod da öyle. İtki dolumu açıldı: bir itki şarjının dolma süresini kısaltıyor, sistem kanalında kendi katsayısıyla (09.5).

Kod tabloyu birebir taşıyor ve test iki tabloyu satır satır karşılaştırıyor: buradaki bir satır değişirse kayıt, kayıt değişirse burası kırılır. Üretilen [kayıt tablosu](02-stat-kaydi.md) aynı kaydı havuz ve fiyat sütunlarıyla basıyor.

## 02.8 · Kritik çarpanının kimliği
Durum: kodda · s3 · StatDef kritik_hasari

Aynı stat bir süre iki adla yaşadı: tasarım `kritik_hasari`, kod `kritik_carpani`. Karar: belge kaynak, kimlik `kritik_hasari` (Kritik hasarı); kod uydu. Değişiklik bedavaydı çünkü stat o gün hiçbir havuzda değildi ve kayıtlı veri taşımıyordu; artık lazer, roketatar ve droid havuzlarında (06.8) ve kimliği kararlı: bundan sonra ad değiştirmek göç demek.

## Sınır

Sahiplenmediği: katmanların ne olduğu → 01 · bir statın kaç ettiği → 03 · aktarım katsayısı σ → 05 · hangi eşyanın hangi statı verdiği ve alt stat havuzları → 06 · BR'de kanal ağırlıkları → 09.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Her statın katmanı, kanalı ve birimi dolu | Eksik kayıt var; nereye çarpılacağı ya da nasıl uygulanacağı belirsiz. |
| Her stat kaydındaki birime göre uygulanıyor | Motor kaydı değil, çağrı yerindeki kodu dinliyor. |
| Her aktif statın en az bir eşi var | Ölü stat adayı eklenmiş. |
| Kimlikler benzersiz ve kararlı | Kimlik çakışması ya da yeniden adlandırma; kayıtlı veri kopar. |
| Hiçbir saldırı statı küresel kapsamda değil | Kapsam ayrımı delinmiş; çift sayım kapısı açılmış. |
| Ayrılmış statlar hiçbir sağlayıcıda yok | Kapalı bir stat sızmış; kafes gelmeden yarım çalışıyor. |
| Kodda geçen her stat kimliği kütüphanede var | Yabancı anahtar ihlali: kod kütüphanede olmayan bir statı okuyor. |
