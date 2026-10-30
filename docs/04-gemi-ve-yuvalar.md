---
alan: 4
ad: Gemi ve Yuvalar
katman: savaş
tur: kural
surum: 1.6
tablo: 04-govde-tablosu.md
kaynak: https://claude.ai/code/artifact/994d3eb2-5545-4d84-962b-5f7fb9ad7821
---

# 04 · Gemi ve Yuvalar

Geminin eşyasız hâli, yuva haritası, ve ölçünün sıfır noktası: referans build. Gemi bir eşya değil, eşyaların taşıyıcısı. İki şey veriyor: taban statlar ve kapasite. Bu belgenin asıl çıktısı üçüncü bir şey: referans build, 03, 08 ve 12'nin ölçtüğü nokta.

Bağımlılık: 02 kayıt · 03 değer yöntemi. Bu belgeye bağlı: 03 · 05 · 06 · 08 · 10 · 12. Sayı tablosu: [04 · Gövde Tablosu](04-govde-tablosu.md).

Sürüm 1.6: droid filosu gövdeden bağımsız (04.10 s3): yuva değil filo, en çok on, gemi değişince kalır. Sürüm 1.5: droid yuvası açıldı (04.10): kademeyle 2'den 5'e, tasarımın 14 · 19 · 22'si. Sürüm 1.4: gövde çapası TTK kısıtından çözülüyor (08.5), tepe tablodan düştü; referans lazerin namlu hasarı tabloya girdi (04.5). Sürüm 1.3: hız jeneratörü kaçınma veriyor (04.4); 06.8'in yedili havuzlarıyla birlikte kapandı. Sürüm 1.2: iki açık karar kapandı. Merdiven kazandı, sekiz gövdenin sekizi de çapadan türüyor ve hız kendi merdivenini aldı (04.12); sanat kazandı, lazer yuvası beşe sabit ve açılan yuvalar jeneratör ile CPU'ya gidiyor (04.9). 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı.

## 04.1 · Gemi üç şey verir: taban stat, yuva sayısı, yuva çeşidi
Durum: kodda · s1 · HullClass

Gemi üç şey veriyor ve üçü de farklı türden ödül. **Taban statlar:** gövde, kalkan, hız; eşyasız hâlin, yani zeminin. **Yuva sayısı:** kaç lazer, kaç jeneratör takabildiğin; sayıdan çok daha güçlü bir ödül, kapasite. **Yuva çeşidi:** hangi yuvanın hangi eşyayı kabul ettiği; gövdenin kimliği burada.

İkincisi kritik. Bir gövde yükseltmesi yalnız statlarını büyütmüyor, daha fazla eşya taşımanı sağlıyor, ve bu oyuncunun hissettiği en güçlü ilerleme biçimi. Yeni yuva, yeni bir karar demek. Yuva sayısı bütçeyi de değiştirir: aynı grup payı daha çok yuvaya bölününce yuva başına düşen güç azalır. Yuva kazanan bir grupta yuva başına düşen güç azalmak zorunda (08.2); lazerde bu görünmüyor çünkü lazer yuvası her gövdede beş (04.9), jeneratörde ve CPU'da görünüyor, yoksa yuva sayısı artışı tek başına gücü katlar. Bu hesap alan 08'in, ama sebebi burada.

## 04.2 · Yuva haritası ve yuva↔eşya eşleşmesi
Durum: kodda · s1 · HullClass.slotCount, Hangar.equip

| Yuva | Rol | Kural |
|---|---|---|
| Lazer | Silah | Gemi kapsamında taban hasarın tek kaynağı. Yuva boşsa gemi ateş edemez. Namlu sayısı = yuva sayısı. |
| Jeneratör | Kalkan ya da hız | Aynı yuvaya iki farklı şey. Donatımın tek gerçek takası (04.3). |
| Roketatar | İkinci silah | Her gövdede tek yuva (04.11). Taban hasarı roket kapsamına, salvo kadans oranıyla (18.1). |
| CPU | Modül | Fayda yuvası: yenilenme, zırh, menzil. Ölçülebilir kanala bağlanmazsa ölür. |
| Droid | Droid gövdesi | Kendi statı ve alt yuvaları olan varlık; kapsamı alan 05'in. Ayrılmış (04.10). |

Yuva tipi ile eşya tipi arasındaki eşleşme bu belgenin kararı: bir lazer jeneratör yuvasına giremez. Sunucu bunu doğrulamak zorunda; istemci uydurma bir yuvaya takmayı deneyebilir ve o yuva bütçe hesabında olmadığı için bedava güç olurdu.

## 04.3 · Jeneratör ikilemi: kalkan ya da hız
Durum: kodda · s1 · ItemSpec.variant, Catalogue df/th

Aynı yuvaya iki farklı şey takılabilmesi donatımın en iyi tasarım kararı, çünkü ekleme değil takas üretiyor, ve takas sayıdan çok daha zengin bir karar. Kalkan tipi yüksek etkin can verir: boğaz tutmaya, boss dövüşüne, dayanmaya. Hız tipi düşük etkin can, yüksek kaçış: avlanmaya, kaçmaya, mesafe tutmaya.

İkisi de savunma veriyor ama farklı biçimde: kalkan hasarı emiyor, kaçınma hasarı azaltıyor. Etkin canda buluşuyorlar, dolayısıyla ikisi de ölçülebilir; oyun içinde bambaşka hissediyorlar. Bu yüzden dengeli bir referans build ikisinden yarı yarıya taşıyor.

## 04.4 · Hız jeneratörü kaçınma da verir
Durum: kodda · s1 · Catalogue th1, th3 havuzu (06.8)

Hız jeneratörünün kaçınma da vermesi bilinçli ve iki işi birden görüyor. Birincisi tematik: hızlı gemiyi vurmak zordur. İkincisi yapısal: kaçınma statının oyunda bir kaynağı olmasını sağlıyor, ve alan 01'in "sıyırma" kararı ancak böyle anlam kazanıyor. Referansta dört jeneratörün ikisi hız tipi ve toplam `referansKacinma = 300` kaçınma veriyor (04.6).

Havuzda (06.8): hız jeneratörünün ana statı hız, yedi alt statından biri kaçınma; her rankta aynı havuz. Kaçınmanın oyundaki kaynağı artık eşya; referans build'in sabit değeri (04.6) yalnız ölçüm noktası. Uzun süre kaçınma hiçbir eşyada yoktu ve sıyırma kararı kâğıt üstünde kalıyordu; 06'nın havuzları koda geçince bu karar onlarla kapandı.

## 04.5 · Referans build bileşimi
Durum: kodda · s2 · ReferansCozumu.stats, ReferansCozumu.recete, TasarimGirdileri.referansJeneratorKalkan, Turetilenler.referansLazerHasari

Bu belgenin en önemli çıktısı. Referans build bir seviyenin "normal" oyuncusudur: beklenen gövde, beklenen eşya rankı, beklenen artı seviyesi. Neden gerekli: alan 03'ün fiyatları marjinal değere dayanıyor ve marjinal değer duruma bağlı; ölçüm noktası olmadan hiçbir stat fiyatlanamaz. Alan 12 boss canını referans DPS'ten, alan 08 bütçeyi referans üzerinden ölçüyor.

İki kural bu belgenin: **bütün yuvalar dolu** ve **jeneratörler yarı yarıya** (`referansJeneratorKalkan = 0,5`, kalanı hız). Kodda referans gerçekten dolu: ilk bandın gövdesi, her yuvada bandın rafındaki katalog tasarımı (15.2), jeneratörler yarı kalkan yarı hız, artı seviyesi beklenen seviye (10.6), alt stat yok; filo referansa girmiyor, droid çapası referans yaylımından türüyor (05.5). Referansın silahı katalogdaki C-I lazer: beş namlu, namlu başına `referansLazerHasari = 140` bütçeden türüyor (bütçe çapası × ana stat payı), ayrı bir girdi değil; `referansAtisAraligi = 1,1` saniye. Saldırı buradan, gövde çapası o saldırıdan çözülüyor (08.5). Fiyat da bu referanstan ölçülüyor (03.2 s2): eşya değerleri fiyata, fiyat referansa bağlı olduğu için döngü var ve döngü YİNELEMEYLE çözülüyor — iki adımda kapanıyor, çünkü ilk bandın rafında yüzdesel ana stat yok. Bir zamanlar fiyat çıplak gövdeden ölçülüyordu ve yüzde statlar dolu referansta değerinden ucuz kalıyordu (borç defteri B22). Referans yarı boş bir gemi olsaydı, yuva ekleyen bir gövde yükseltmesi referansı zayıflatırdı. Dolu referans, kapasitenin gerçekten güce dönüştüğünü varsayıyor ve bütçe hesabını tutarlı kılıyor. Gerçek oyuncular referansın altında kalır; bu normal ve zaten ölçülmesi gereken şey.

Gövde, eşya rankı ve artı seviyesinin seviyeye eşlenmesi alan 10'un. Bugün referans tek noktada: Bastion · C · +0 · dolu.

## 04.6 · Referans zırh ve kaçınma toplamları
Durum: kodda · s1 · Turetilenler.kZirh, Turetilenler.kSiyirma

Zırh gövdenin tabanı, `zirhCapasi = 1.000`; bugün tek kaynak, ileride CPU modülleri ve alt statlar da ekleyecek. Kaçınma hız tipi jeneratörlerden, referansta `referansKacinma = 300`.

Bu iki değer alan 03'ün bekleyen sabitlerini çözüyor: alan 01 hedefi ilan etti (%30 azaltma, %15 sıyırma), bu belge referansı ilan etti, K sabitleri türedi, 03 fiyatı türetti. Dört alan, tek bir elle yazılmış ara sayı yok. Referans zırhı 1.000'den 2.000'e çıkarırsan K de fiyat da kendiliğinden değişir ve %30 hedefi bozulmadan kalır.

## 04.7 · Gövde statları merdivenden türer
Durum: kodda · s2 · HullClass._kur, Turetilenler.govdeKademeCarpanlari; etiket ReferansBuild bölmesinden

Gövde statları elle konmuyor. Çapa üç sayı: gövde canı girdi değil, TTK kısıtından çözülüyor (08.5); `kalkanCapasi = 8.000` ve `hizCapasi = 320` girdi. Ve `govdeKademeSayisi = 8` kademenin her biri çapa × kademe çarpanı. Kademe çarpanı rank merdiveninin kademe normalizasyonundan geliyor: sekiz gövde yirmi rankı bölüşüyor, her gövde iki buçuk rank kapsıyor. Bir kademe eklemek yeni bir sayı değil, aynı formülün bir adımı. Gövdenin rank etiketi (hangarda "C-III SINIF") de bu bölmeden: bandın ilk rankı, yani referans oyuncunun o gövdeyi aldığı rank (10.6). Aile başından (kademe × 3) gelirken beşinci gövde SS-I yazıyor ve S-II oyuncusunun gövdesi oluyordu; etiket güce girmiyor ama yalan söylemiyor.

Sekiz gövdenin sekizi de böyle türüyor (04.12); ilk üçünün elle duran tek şeyi yuva toplamı ve fiyatı. Türetilen beşin fiyatı yok, çünkü onlara uygun içerik gelene kadar satın alınamıyorlar. Hız bu çarpanı almıyor: sistem kanalında ve tempoyu belirliyor, kendi küçük merdiveni var (04.12).

## 04.8 · Yuva merdiveni kesikli, kademe başına bir yuva
Durum: kodda · s1 · HullClass.yuvaSayisi, TasarimGirdileri.yuvaArtisi

Yuvalar tam sayı ve sanat kısıtına bağlı; toplam formülle türetilmiyor, kesikli bir merdiven olarak duruyor. Formül uydurmak, çizimde beş namlu varken tabloda 5,4 çıkması riskini getirirdi. İlk üç gövdenin toplamı sanata kilitli (droid yuvası olmadan 12 · 16 · 18), dördüncüden itibaren kademe başına `yuvaArtisi = 1` yuva açılıyor. Açılan yuva lazere gitmiyor (04.9): lazer sabit, roketatar bir, kalan yuvaların üçte ikisi jeneratör, gerisi CPU.

## 04.9 · Sanat kısıtı: lazer yuvası = çizimdeki namlu
Durum: kodda · s2 · TasarimGirdileri.lazerYuvaSayisi, HullClass yuva dağılımı, test/sanat_kisiti_test.dart

Lazer yuva sayısı, gövdenin çiziminde kaç namlu olduğuyla aynı olmak zorunda. Ayrışırsa silahın olmadığı yerden mermi çıkar. Sanat ile tablo çakıştığında sanat kazanır; oyuncunun gördüğü o.

Ölçüldüğünde tutmuyordu: sekiz tasarımın hepsi beş kaide taşırken tablo lazer yuvasını kademe başına bir artırıp on ikiye çıkarıyordu. Karar: sanat kazandı. `lazerYuvaSayisi = 5` her kademede sabit; kademeyle açılan yuvalar jeneratör ve CPU'ya gidiyor, `jeneratorYuvaPayi = 0,6667` ile (Bastion'ın 4 · 2 dağılımı kuralın kendisi). Makine denetimi yazıldı: her kademede tasarımın kaide sayısı, gövdenin lazer yuvası ve atlasın kaide sayısı eşit.

## 04.10 · Droid filosu gövdeden bağımsız
Durum: kodda · s3 · Hangar.filo, HangarRules.filoyaAl, TasarimGirdileri.droidFiloTavani

Droid, kendi statı olan varlık; kapsamı ayrı ve alan 05'in. Gemiye takılan bir şey değil: droidler oyuncunun FİLOSU, en çok `droidFiloTavani = 10` tane, ve gemi değişince kalıyor. Gövde haritasında droid yuvası yok; gövde yuvaları sanatın 12 · 16 · 18'i, tasarımın bir zamanki 14 · 19 · 22'si droidi gövdeye bağlayan eski modeldi ve kaldırıldı. Filoya droidin kendisi alınıyor (06.3'teki droid tasarımları) ve statı droid kapsamına yazıyor (05.4); filodaki droid takılı eşya gibi parçalanamaz, önce çıkarılır. Bütçesi ve saldırı payı gövdeye değil tam filoya bölünüyor: on droid gücün yüzde on beşi. Bir süre kademeyle açılan gövde yuvası olarak kodlandı; oyuncunun kararı filoydu, belge ona döndü. Model başına tavan yok: model bir rank basamağı (Vane C-I, Corona C-II, Taurus C-III, Jove B-I), eski merdivendeki gibi ayrı bir sınıf değil; model başına tavan rank başına tavan demek olurdu. Özel droid istenirse ayrı bir eşya ailesi olarak açılır.

## 04.11 · Roketatar her gövdede tam bir yuva
Durum: kodda · s1 · HullClass, her kademede launcherSlots 1

Bilinçli olarak dar bant: tek yuva olduğu için katkısı büyürse tek eşya oyunu belirler. Türetilen kademeler de birinci gövdenin roketatar sayısını aynen taşıyor. Yuvadaki eşya bir silah (18): her salvoda bir roket, salvo başına bir birim mermi; tek yuva olması salvonun da tek olması demek.

## 04.12 · Merdiven çizilmiş gövdeleri açıklar
Durum: kodda · s2 · HullClass._kur, TasarimGirdileri.hizArtisi

Merdiven bir girdi değil, çapadan türeyen bir sonuç; çizilmiş gövdeler de onun dışında duramaz. Uzun süre durdular: elle konan Vanguard 16.000 ve Spectre 21.000, merdivenin 30.000 ve 74.760'ına karşı; dördüncü kademe 186.819'a sıçrıyordu, bitişik iki gövde arasında dokuz kat. Karar: merdiven kazandı. Yaratıklar rank çarpanıyla büyüdüğü için öldürme süresi ancak gövde de aynı merdiveni izlerse sabit kalıyor; üç gövdeye uydurulan bir merdiven yaratıklarla ayrışırdı.

Hız istisna: rank çarpanıyla büyüseydi sekizinci kademe altı yüz kat hızlı olurdu ve savaş kaçış yarışına dönerdi. Hız kendi merdiveninde, kademe başına `hizArtisi = 1,08`; eski tasarımın sayısı, kademe normalizasyonuna geçerken düşmüştü. Test: sekiz gövdenin can ve kalkanı çapa × çarpan, hızı çapa × 1,08^kademe, bitişik kademeler arasında sıçrama yok.

## Sınır

Sahiplenmediği: yuvaya takılanın ne verdiği → 06 · yuvaya düşen güç payı → 08 · hangi seviyede hangi gövde → 10 · gövdenin fiyatı ve tamir ücreti → 13 · droid'in kendi kuralları → 05.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Lazer yuva sayısı = çizimdeki namlu sayısı | Silahın olmadığı yerden mermi çıkıyor. |
| Her yuva tipi en az bir eşya tipini kabul ediyor | Doldurulamayan yuva var; kapasite ödülü boş çıkıyor. |
| Roketatar yuvası her gövdede tam 1 | Dar bant kararı delinmiş. |
| Gövde statları merdiven formülünden çıkıyor | Bir gövdenin statı elle yazılmış; merdiven artık tutmuyor. |
| Sekiz gövde de merdivenden çıkıyor | Bir gövdenin statı elle yazılmış; merdiven artık tutmuyor. |
| Kademe arttıkça her stat artıyor | Ters merdiven; üst kademe gövde zayıf çıkmış. |
| Referans build'in bütün yuvaları dolu | Ölçüm noktası belirsizleşmiş; 03, 08 ve 12'nin sayıları oynar. |
| Referans jeneratör bölünmesi tam yarı yarıya | Referans bir uca kaymış; kaçınma ya da kalkan yanlış fiyatlanıyor. |
| referansZırh → azaltma %30, referansKaçınma → sıyırma %15 | K yanlış türemiş; 01 ile 04 ayrışmış. |
| Üst kademe gövdedeki lazer, alt kademedekinden zayıf | Yuva sayısı artışı gücü katlıyor; 08 ile bu belge ayrışmış. (16'ya ait) |
