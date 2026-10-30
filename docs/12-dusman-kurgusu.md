---
alan: 12
ad: Düşman Kurgusu
katman: dünya
tur: kural
surum: 1.1
tablo: 12-dusman-tablosu.md
kaynak: https://claude.ai/code/artifact/51cf8fa4-7199-4133-af5a-4444e4c1a498
---

# 12 · Düşman Kurgusu

Yaratıkların canı, hasarı ve ödülü, hiçbiri elle konmadan. Bir yaratığın canı bir süre, ödülü bir hız, hasarı bir pencere. Üçü de zaten ilan edilmiş hedeflerden çıkıyor: 11'in saatlik kredi hedefi, 01'in referans DPS'i, 04'ün havuzu. Yaratık tasarımı bir sayı uydurma işi değil, üç denklemi çözme işi.

Kullandığı: [01](01-savas-formulu.md) referans DPS · [04](04-gemi-ve-yuvalar.md) havuz · [11](11-haritalar.md) saatlik hedef. Devredilen: 14 → yaratık başına ganimet bütçesi · 13 → NOVA musluğu sabit. Sayı tablosu: [12 · Düşman Tablosu](12-dusman-tablosu.md).

Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. 1.0'ın açık bıraktığı iki şey kapandı: sunucu otuz iki yaratığı kadrodan doğuruyor ve boss saati haritada tutuluyor.

## 12.1 · Üç sınıf, üç rol
Durum: kodda · s1 · DusmanSinifi

| Sınıf | Can | Saldırganlık | Hız | Menzil | Rolü |
|---|---:|---|---:|---:|---|
| Sıradan | 1 sn | pasif | 0,30× | 0,50× | Gelirin taşıyıcısı. Görmezden gelinebilir; riski oyuncu başlatır. |
| Güçlü | 5 sn | saldırgan | 0,15× | 0,65× | Bir karar. Kendisi başlatır ama kaçamaz; girmek de çıkmak da oyuncunun elinde. |
| Boss | 360 sn | saldırgan | 0,10× | 0,80× | Grup hedefi. Zamanlı doğar, bandın ganimet tavanıdır. |

Can sütunu saniye: referans build'in kaç saniyede indireceği. Hız ve menzil oyuncununkine oran: `siradanHizOrani = 0,3` · `gucluHizOrani = 0,15` · `bossHizOrani = 0,1`; `siradanMenzilOrani = 0,5` · `gucluMenzilOrani = 0,65` · `bossMenzilOrani = 0,8`. Üçü de kademeden bağımsız; sınıf bir orandır, bir sayı değil. Oran çıplak gövdenin taban hızına ve referans lazerin menziline (fiyat referansı, 03.2): donanımın hız ve menzil eklentileri yaratığı hızlandırmaz, yoksa hız jeneratörü takan oyuncu yaratıkları da hızlandırırdı. Can ve hasar ise dolu referanstan (04.5): yaratık, o bandın normal oyuncusuna göre ölçülür.

Hiçbir yaratığın menzili oyuncununkine eşit olamaz; eşit olsaydı mesafe tutmanın anlamı kalmaz, savaş bir sağlık çubuğu yarışına dönerdi. Hız da öyle: sıradan yaratık kovalayabilir ama yetişemez, güçlü olan hiç kovalayamaz. Kaçmak her zaman mümkün; bedeli, o ana kadar yatırılan zaman. Saldırganlık sıradan yaratıkta sıfır: haritada dolaşıyor, ateş edilene kadar uyumuyor. Bu, oyuncuya haritayı geçme hakkı veriyor.

## 12.2 · Can bir süredir
Durum: kodda · s2 · DusmanTasarimi.can

Can = sınıf süresi × bandın referans DPS'i. Referans DPS savaş sözlüğünün beklenen DPS'i × rank çarpanı; 09'un saldırı kanalıyla aynı tanım, ikinci bir "referans DPS" olamaz. `siradanOldurmeSuresi = 1` ve `gucluOldurmeSuresi = 5` saniye.

Elle konmuş değerler Void Spore 1.600 ve Void Leviathan 9.000 idi; ilk bandın türetilenleri bugün `yaratikCani(0) = 2.008` ve `yaratikCaniGuclu(0) = 10.041`, yani elle konanların ÜSTÜNDE. Yön bir zamanlar tersineydi, türetilenler elle konanların altında kalıyordu; referans tam donanıma geçince (04.5 s2) döndü. Elle konan sayının derdi yalnız bir kez yanlış olması değil, hangi tarafta yanlış olduğunun da referans değiştikçe değişmesi — bu yüzden iki sayı artık belgeye yazılmıyor, türetilen etiketiyle anılıyor (16.7). İkisi de "iki yaylımda ölsün" ve "dokuz yaylımda ölsün" diye konmuştu; süre cinsinden düşünmek zaten yapılıyormuş, yalnız formülü yazılmamış. Asıl kazanç ileriye dönük: yirminci bandın sıradan yaratığının canı bir tahmin değil; referans DPS büyüdüğü kadar büyüyor ve öldürme süresi her bantta bir saniye kalıyor. Savaşın temposu yirmi bant boyunca sabit, değişen tek şey sayıların büyüklüğü.

## 12.3 · Ödül bir hızdır
Durum: kodda · s1 · DusmanTasarimi.saatlikHedef, DusmanTasarimi.kredi

11 her banda saatlik bir kredi hedefi verdi; birinci bandınki `tabanSaatlikGelir = 144.000`, üstü α ile. Yaratık ödülü o hedefi tutturmak zorunda: ödül = saatlik hedef × çevrim süresi ÷ 3600, çevrim = yeniden doğma + öldürme süresi. `siradanDogusSuresi = 8` ve `gucluDogusSuresi = 20` saniye. Çevrimin yeniden doğma içermesi kritik: oyuncu bir yaratığı öldürdükten sonra bir sonrakini beklemek zorunda.

Güçlü yaratığın ödülü risk primiyle, `gucluRiskPrimi = 1,15`: saldırgan olmasının karşılığı; sıradan yaratıkta prim yok çünkü riski oyuncu seçiyor. Elle konan Leviathan ödülü 3.000 idi, türetilen 1.150: yalnız Leviathan farm eden bir oyuncu saatte hedefin üç katını kazanıyor, alan 10'un iki yıllık takvimi üçte bire iniyordu. İki kayıt da artık formülden.

## 12.4 · Hasar bir kaçış penceresidir
Durum: kodda · s1 · DusmanTasarimi.hasarDps, TuretilenTablolar.yaratikDpsFor

Yaratık hasarı "ne kadar acıtsın" sorusuyla ayarlanamaz. Ayarlanabilir soru: üç yaratığı birden üstüne çeken oyuncunun kaçmak için ne kadar vakti olsun? Yaratık DPS = havuz ÷ (`tehditSayisi = 3` × `kacisPenceresi = 120`). Kodun eski yorumu tam olarak bu formülün cümle hâliydi: "tehdit tek alienden değil, üçünü birden çekmekten geliyor". İki dakikalık pencere kaçış anında başlamıyor: oyuncu üç yaratığı üstüne çektiğini fark ediyor, itkiyi kullanıyor, menzil dışına çıkıyor; pencere o zincirin tamamı. Hasar sınıfla değil bantla ölçekleniyor; güçlü yaratığı tehlikeli yapan hasarı değil, kaçamayacağın kadar uzun sürmesi.

## 12.5 · Boss: iki saatte bir, her bantta
Durum: kodda · s1 · DusmanTasarimi.bossAraligiSaat, HaritaKaydi.bossAraligiTik

Boss üç sayıyla tanımlanıyor ve üçü de türetilen: canı (`bossGrubu = 3` × `bossHedefSuresi = 120` × referans DPS), ödülü (harcanan oyuncu-saatin `bossPrimi = 3` katı), doğma aralığı (bandın gelirinin `bossGelirPayi = 0,15` kadarını taşıyacağı). Aralık her bantta aynı çıkıyor ve bu bir seçim değil, bir sonuç: grup, süre, prim ve pay sabit tutulduğunda aralık bantlardan bağımsız oluyor. Oyuncu hangi bölgede olursa olsun aynı ritmi öğreniyor; öğrenilebilir bir ritim, hatırlanması gereken yirmi ayrı sayıdan iyi. Boss'a hiç girmeyen oyuncu %15 yavaş ilerliyor, duruyor değil. Boss saati sunucuda haritanın kaydında tutuluyor: kimse izlemediği için doğmamış olamaz.

## 12.6 · NOVA ölçeklenmez
Durum: kodda · s1 · DusmanTasarimi.nova, TasarimGirdileri.novaOdulu

Kredi bantla yüzlerce kat büyüyor; NOVA büyümüyor, sıradan yaratık her bantta `novaOdulu = 1` NOVA veriyor. Sebebi tek cümle: NOVA gerçek parayla rekabet ediyor. Kredi oyunun içinde basılan ve yakılan bir kaynak; NOVA'nın karşılığı satılan bir şey. Kademeyle ölçeklenirse son bölgedeki oyuncu saatte yüzlerce kat NOVA basar ve satılan NOVA'nın değeri sıfırlanır. NOVA zamana bağlı, güce değil; üst bölgedeki oyuncunun avantajı NOVA kazanmakta değil, NOVA'ya ihtiyacı olmamakta. Aynı sebeple yorgunluk eğrisi krediye uygulanır, NOVA'ya uygulanmaz.

## 12.7 · Kadro: otuz iki yaratık, sekiz bölge
Durum: kodda · s1 · YaratikKadrosu

Her bölgede dört yaratık: iki sıradan, bir güçlü, bir boss. İki sıradan olmasının sebebi haritanın dolgusu: aynı silueti yan yana on kez görmek bir bölgeyi tek yaratıktan ibaret gösteriyor. PvE ve PvP haritaları aynı yaratıkları paylaşıyor; farkları ödülde ve rakipte, yeni bir sürü çizmeye gerek yok. Otuz ikisinin de kimliği, sınıfı, yarıçapı ve atış aralığı kadroda yazılı; statları ranktan türüyor. Sunucu kadrodan doğuruyor; kadro [tabloda](12-dusman-tablosu.md).

## Sınır

Sahiplenmediği: hangi eşyanın düşeceği ve oranlar → 14 · kredinin harcanacağı yer → 13 · NOVA fiyatları → 15 · yaratıkların nasıl göründüğü → sanat. 12 yaratığın ne kadar verdiğini söylüyor, ne verdiğini değil.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Her sınıfın öldürme süresi bantlar arası sabit | Savaşın temposu kaymış; üst bölgeler sünger ya da kâğıt. |
| Her yaratığın saatlik verimi = bandın hedefi (±%5) | Bir yaratık farm için diğerlerinden kârlı; gelir eğrisi delinmiş. |
| Yaratık menzili < oyuncu menzili | Mesafe tutmanın anlamı kalmamış. |
| Yaratık hızı < oyuncu hızı | Kaçmak imkânsız hâle gelmiş. |
| Üç yaratık × kaçış penceresi = havuz | Hasar elle ayarlanmış; tehdit hesabı kopmuş. |
| Boss aralığı her bantta iki saat (±%10) | Boss geliri bandın payından sapmış. |
| Sıradan yaratık pasif | Haritayı geçme hakkı kalkmış. |
| NOVA ödülü bantlar arası sabit | Sert para enflasyona açılmış; 15'in fiyatları geçersiz. |
