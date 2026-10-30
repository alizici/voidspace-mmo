---
alan: 0
ad: Borç Defteri
tur: defter
---

# Borç Defteri

Kodlarken açığa çıkan sorular, varsayımlar ve borçlar. Elle yazılır; denetim içeriğe karışmaz ama bağı sınar (16.9): her maddenin `Kaynak:` satırında en az bir karar ya da alan durur, o karar var olmak zorundadır, madde durumlu ve tarihlidir. Kapanan madde silinmez, durumu değişir: defter neyin neden ertelendiğini de hatırlar.

Durum: **açık** (karar bekliyor) · **izleniyor** (playtest'te bakılacak) · **kapandı**.

## B1 · Referans build tam donanımı taşısın mı?
Durum: kapandı · Kaynak: 04.5 · 08.5 · 08.6 · 10.6 · 2026-09-02 → 2026-09-03

Karar: evet, tam donanım (`ReferansCozumu`). Referans ilk bandın gövdesi, her yuvada bandın rafındaki tasarım, jeneratörler yarı kalkan yarı hız, alt statsız; gövde çapası bu build'in TTK kısıtından çözülüyor, eşya havuzu terimi artık sıfır değil ve 08.6'nın kolu doğdu. Referansın silahı katalogdaki C-I lazer: 200'lük girdi kalktı, namlu hasarı bütçeden türüyor (140). Fiyat referansı çıplak kaldı (03.2): fiyatı dolu build'den türetmek döngü olurdu.

İki hüküm benim, tek satırla geri alınır: artı seviyesi +15 değil beklenen seviye (10.6 s2, bugün +12; 13.6 +15'in nesil içinde ulaşılamadığını ölçmüştü, +15'e çapalı referans dünyayı oyuncunun üstüne ayarlardı) ve filo referansa girmiyor (droid çapası referans yaylımından türüyor, referansın içine girse kendi kendini ölçerdi). Savaş puanı ölçeği yeniden çözüldü ki referans 3.600'de kalsın (09.7). Eski hâlin sayıları B6'da.

## B2 · Artı basma adımının miktarı
Durum: izleniyor · Kaynak: 07.6 · 2026-09-02

Karar (2026-09-03): beşte bir kalıyor; toplam korunuyor, 06'nın çakışma hesabı bozulmuyor, sıçrama yalnız yedi statlı Pembe'de. Playtest ölçütü: üst rankta artı basan oyuncu tek statın sıçramasını "bozuk" diye mi okuyor, yoksa Pembe'nin lüksü mü.

Belge "miktar sabit" diyor, sayı vermiyordu. Seçilen: her adım alt stat bütçesinin beşte biri tek stata; toplam eski kuralla aynı, C ailesinde eskiyle özdeş. Sonuç: Pembe'de tek stat bir adımda +%140 sıçrıyor, beş adım rastgele dağılınca bir stat 5×, ötekiler 1× kalabiliyor.

- **Öteki okuma:** her adım statın kendi tabanının %20'si. Sıçrama yumuşar; ama üst rankların +15 alt stat toplamı iki pay yerine Pembe'de 1,14 pay olur, +15 gücü düşer ve 06'nın rank çakışma hesabı yeniden ölçülmeli.

Bakılacak: +%140'lık sıçrama oyun hissi olarak fazla mı, yoksa Pembe'nin lüksü mü?

## B3 · Saklanan alt stat değerleri
Durum: kapandı · Kaynak: 07.5 · 07.6 · 2026-09-02 → 2026-09-03

Kapandı: saklanan şey kalite rolü (0–1), değer her okunuşta tabandan türüyor; gövde değişince düzeliyor, artı basma taşımıyor. Eski kayıtlar yüklemede o anki gövdeyle role çevrildi (`Hangar.fromJson`), canlı oyuncu yok.

Çevirme alt statı mutlak değer olarak saklıyor. İki sonucu var:

- Kayıtlı çevrilmiş eşyalar eski düzgün büyümeyle hesaplanmış değerleri taşıyor; artı basma bir sonraki seviyeden itibaren yeni oranla taşıyor, geriye dönük düzeltme yapılmadı.
- Saklanan değer çevirme anındaki gövdenin yuva katsayısını içeriyor; oyuncu gövde değiştirince yeniden hesaplanmıyor. Türetilen alt statlar gövdeyle değişiyor, çevrilmişler değişmiyor.

Çözüm adayı: saklanan şey mutlak değer değil kalite rolü (bant içinde 0–1) olsun; değer her okunuşta tabandan türesin. Kayıt biçimi değişir, göç ister.

## B4 · Ayrılmış yedi statın yerleşimi
Durum: açık · Kaynak: 02.6 · 02.7 · 2026-09-02

Delici, sertlik, kırıcı, zırh katmanı, kritik direnci, durum hasarı, durum azaltma: katman, kanal, birim ve eşleri ilk yerleşim, kafes tasarlanmadan kondu. Üç karşı-stat çifti ve kritik şansının karşısı; durum çifti koşullu katmanda. Kafes yazılırken 02.6 yeniden açılır ve bu satırlar değişebilir.

## B5 · Sistem kanalı savaş puanında
Durum: izleniyor · Kaynak: 09.5 · 09.7 · 2026-09-02

Sistem puanı donanımın oran statlarından; gövdenin taban hızı girmiyor, bu bir varsayım. Sistem statı taşıyan build'ler kapılara en çok dörtte bir erken varıyor; tavan 25 puanda. Ölçek sabiti 3,168'e yeniden çözüldü ki merdiven yerinde kalsın. Playtest'te bakılacak: hız ve menzil eşyası savaş puanını hissedilir kaydırıyor mu?

## B6 · Gövde çapası türetiminin dalgası
Durum: izleniyor · Kaynak: 08.5 · 2026-09-02

Gövde çapası 12.000'den 12.284'e çıktı: sekiz gövdenin canı yüzde 2,4, yaratık hasarı yüzde 1,4 arttı; referans TTK tam otuz. Oyun hissinde bakılacak bir şey yok gibi, ama sayılar oynadı; not düşüldü. İkinci dalga (2026-09-03, B1): referans tam donanıma geçince çapa ve yaratık sayıları yeniden oynadı; yeni değerler pay ve düşman tablolarında, playtest'te birlikte bakılacak.

## B7 · "Ayrılmış" durumu süreç kurallarını da taşıyor
Durum: açık · Kaynak: 16.5 · 16.6 · README · 2026-09-02

Yedi kodsuz karardan beşi gerçek rezervasyon, ikisi süreç kuralı (yeni alan ekleme adımları, denetimin sınırı). İkisine de "ayrılmış" dendi. Süreç kuralları çoğalırsa ayrı bir durum (süreç) daha doğru olur.

## B8 · Jitter testi seğiriyor
Durum: kapandı · Kaynak: 16.1 · test/jitter_test.dart · 2026-09-02 → 2026-09-03

Kapandı: jitter ölçümü iki denemede (gerçek gerileme ikisinde de düşer, seğirme ikisinde birden çok nadir), delta anahtar kare testi iki aralıklık pencerede; ikisi `zaman` etiketi taşıyor ve yük altındaki tam koşudan `--exclude-tags zaman` ile ayrılabiliyor. Sahte saat seçilmedi: gerçek soketin ve işletim sisteminin zamanlamasını taklit edemezdi.

Tam koşuda bir kez 70 ile 60 eşiğini aştı; tek başına üç kez ve tam koşuda ikinci kez geçti; statlara bakmıyor, zamanlamaya bağlı. Eşik ya da ölçüm yöntemi gözden geçirilmeli; seğiren test yeşil kaldıkça inandırıcılığını yitiriyor.

Aynı sınıftan ikinci bir test: sunucuda `delta_test.dart` içindeki "anahtar kare iki saniyede bir" testi tam koşuda bir kez sıfır saydı, tek başına geçti (2026-09-03). İkisi de gerçek zamana bakıyor; sahte saatle koşmaları gerekir.

## B10 · Gövdenin rank etiketi bandından ayrışıyor
Durum: kapandı · Kaynak: 04.7 · 10.6 · 2026-09-02 → 2026-09-03

Kapandı: etiket banttan (04.7 s2). Gövdenin etiketi referans bölmesinin ilk rankı: Bastion C-I, Vanguard C-III, Spectre B-III, dördüncü A-II, beşinci S-II, altıncı SS-I, yedinci SSS-I, sekizinci SSS-III. Güce etkisi yok, hangar ve mağaza kartı yeni etiketi yazıyor.

Gövdenin etiketi (`HullClass.tier`, hangarda "B-I SINIF") aile başından geliyor: kademe × 3, yani Bastion C-I, Vanguard B-I, Spectre A-I, dördüncü S-I, beşinci SS-I, altıncı SSS-I, yedinci Kırmızı, sekizinci Pembe. Referans bölme ise sekiz gövdeye yirmi rankı iki buçukar veriyor (04.7, `ReferansBuild.kademeOf`): beşinci gövdenin bandı S-II ile S-III, altıncının SS-I ile SS-III, yedincinin SSS-I ile SSS-II. İlk dört gövdede etiket bandın içinde, sonraki üçünde dışında. Etiket yalnız görünüşte kullanılıyor, güce girmiyor.

- **Etiket banttan gelsin:** Vanguard C-III, Spectre B-III olur; hangarda görünen isim değişir.
- **Aile başı kalsın:** sekiz gövde sekiz aileyle eşleşir, okunması kolay; ama beşinci gövde "SS-I" yazarken S-II oyuncusunun gövdesi olur.

## B9 · Eski borçlar
Durum: kapandı · Kaynak: 16.4 · 2026-09-02 → 2026-09-03

Kapandı: hangar kaydındaki yarım satır artık yok (dosyanın seksen iki satırı da geçerli JSON), iki `directives_ordering` uyarısı giderildi, önizlemeler yeniden basıldı. Önizleme testleri (`tool/`) düz koşuda referansla piksel karşılaştırması yapıyor ve her görsel değişiklikten sonra kırmızıya dönüyor; bu tasarım, `flutter test --update-goldens tool/` ile basılırlar. Gerçek kırık tekti: dar ekranda mağazanın GEMİ sekmesi tembel şeritte kurulmadığı için önizleme onu bulamıyordu, test artık şeridi kaydırıyor.

- `tool/` altında dört kırık altın görüntü.
- `data/hangars.jsonl` içinde yarım kalmış bir satır.
- `test/hangar_test.dart` iki `directives_ordering` uyarısı.

## B11 · Unvan adlarının on ikisi ilk yerleşim
Durum: açık · Kaynak: 10.4 · 2026-09-02

Belge yalnız uçları veriyordu: Squire … Duke, … Deity, Starcaller … Vortex, … Star Marshal, Star Lord. Aradaki on iki ad (Knight, Baron, Count; Acolyte, Cleric, Bishop, Saint; Comet, Pulsar, Nebula; Phoenix, Titan, Immortal) benim önerim. Değiştirmek bedava: kayıt ada değil indekse bağlı. Arayüz unvanı çiziyor (2026-09-03): hangar başlığında ve HUD panelinde, seviye ve savaş puanıyla; adlar hâlâ ilk yerleşim, karar sizin.

Görsel kimlik geldi (2026-09-04, 10.4 s2): her adın kendi amblemi, kademe halkası, çağla katmanlanan aparat ve adın tipografisi. Ad değişirse AMBLEM de değişmeli — glif kataloğu indekse bağlı ama şekli ada göre seçildi (Comet'in kuyruğu, Vortex'in sarmalı, Immortal'ın lemniskatı). Yani adları değiştirmek artık bedava değil: on iki ad değişirse on iki glif yeniden çizilir. Karar hâlâ sizin, bedeli yazılı.

## B12 · Ölçülen pay ilan edilen bandın dışında
Durum: kapandı · Kaynak: 08.1 · 08.3 · 2026-09-02 → 2026-09-03

Kapandı: bant üç puandan ona açıldı (08.3 s2, `payBandi`), ilan sabit. Sapma yapısal, ilanı ölçüme çekmek kovalamaca olurdu; değişmez testi askıdan indi ve bantla çalışıyor.

Shapley ölçümü (kur biriminde toplamsal güç: saldırı + dayanıklılık ÷ T + sistem) ilan edilen paylardan sapıyor: lazer ilanın yaklaşık sekiz puan üstünde, CPU ve roketatar dörder puan altında, gövde ve jeneratör üçer puan içinde. Belge üç puanlık bant istiyor. Sebep yapısal: lazer taban hasarı veriyor, bütün çarpanlar onun üstüne biniyor ve tamamlayıcılık artığı ona akıyor. Değişmez testi askıda (`pay_olcumu_test.dart`), sayılar pay tablosunda.

- **Payları yeniden ilan et:** lazere daha büyük pay, CPU ve roketatara daha küçük; katsayılar kendiliğinden türer, eşya güçleri kayar.
- **Bandı gevşet:** üç puan yerine on; ölçüm bilgi olarak kalır.
- **Ölçümü değiştir:** lazerin taban rolünü çıkarıp yalnız çarpan gruplarını ölçmek; belgenin sorusunu değiştirir.

## B13 · Droid grubu birlikte bekliyor
Durum: kapandı · Kaynak: 04.10 · 05.1 · 05.2 · 05.4 · 05.5 · 09.6 · 2026-09-02 → 2026-09-03

Kapandı: droid sistemi eski merdivenin altı seviye ve formasyon tasarımıyla geldi; beşi kodda, kalanlar B15, B16, B17.

Beş karar tek sisteme bağlı: sağlayıcı tipi, sağlayıcı kaydı, yuva → kapsam eşlemesi, aktarım katsayısı σ, droidin iki BR katsayısı. Kayıt ve kapsam eşlemesi tek sağlayıcıyla biçimsel kalırdı; σ girdisi olmayan sistem için sayı ilan etmek olurdu (05). Droid varlığı, sanatı ve davranışı gelince beşi birlikte açılır; kapsam kilidi (02.3) o gün hazır.

## B14 · Açılış sırası mağazadan atlanabiliyor
Durum: kapandı · Kaynak: 10.7 · 06.3 · 15.2 · 2026-09-02 → 2026-09-03

Kapandı: raf bandın bir altı (15.2 kodda gerçekten): her yuva tipinde bandın bir alt rankındaki taban eşya, fiyat 15.2'nin modeli, alınan eşya alt statsız; sunucu bandı kendisi okuyor. Sabit on altı tasarımlık raf ve 12.000'lik fiyat gitti. Yeni bir soru doğdu: B21.

Sistemler sahip olunan en yüksek eşya rankıyla açılıyor; mağaza rafı ikinci ve üçüncü rankın eşyasını satıyor (C-II lazer, C-III lazer). Kredisi olan oyuncu raftan alıp artı basmayı ve çevirmeyi ilk dakikada açabiliyor; öğretim eğrisi rafın altında kalıyor. Seçenekler: rafı ilk rankla sınırlamak (mağaza zemin, kestirme değil, 15.2 ile uyumlu), ya da açılışı ganimetten gelen eşyayla saymak (kaynak alanı, 05.2'ye yaklaşır).

## B15 · Droid havuzu saldırı payından türüyor
Durum: kapandı · Kaynak: 05.5 · 09.6 · 2026-09-03 → 2026-09-03

Kapandı: pay ilan edildi, aynı sayı (05.5 s2). Droid havuzu referansta gemi havuzunun `droidDpsPayi` kadarı; ayrı dayanıklılık payı yok, istenirse tek satır.

Belge droid taban hasarını saldırı payından türetiyor ama droid havuzu için pay ilan etmiyordu. Havuz aynı payla gemi havuzundan türetildi: droid grubu referansta gemi havuzunun yüzde on beşi. Ayrı bir dayanıklılık payı ilan edilirse tek satır değişir.

## B16 · Droid yuvasına droidin kendisi giriyor
Durum: kapandı · Kaynak: 05.4 · 06.3 · 2026-09-03 → 2026-09-03

Kapandı: belge koda uydu (05.4 s2). Droid yuvası filoda ve yalnız droid eşyası alır; lazer gemide. Droide modül yuvası 06'nın ileride verebileceği ayrı bir karar.

Belge "aynı lazer hem gemiye hem droide takılabilir" diyor; kodda filoya droid eşyası (Vane, Corona, Taurus, Jove) giriyor, lazer girmiyor. Sebep: droidin silahı türetilen çapa (05.5), lazerin taban hasarı droide binseydi iki droid geminin yaylımının yarısını taşırdı ve saldırı payı hedefi anlamsızlaşırdı. Lazerin droide takılması isteniyorsa droid eşyasına modül yuvası açılmalı (eski merdivende bir modül).

## B17 · Droid ölmüyor
Durum: kapandı · Kaynak: 09.6 · 05.1 · 05.10 · 2026-09-03 → 2026-09-04

Kapandı, ama sorulan yerden değil: droidin canı olmayacak, DAYANIKLILIĞI olacak (05.10). Dövüşte hâlâ hedef alınmıyor ve ayakta kalma bir; kayıp dövüşün içinde değil sonrasında — ana gemi her öldüğünde filodaki her droidin sayacı `droidAsinmaPayi = 10` puan iniyor, sıfırda droid yok oluyor. Onarım NOVA ile (05.10), fiyatı yerine konma süresinden. Ayrı bir mermi olayı da gerekmedi: droid hasar almadığı için tel üzerinde taşınan tek şey bir bayt sayaç.

Ayakta kalma katsayısı bir: droidler hasar almıyor, ölmüyor, hedef alınamıyor. Sunucuda droid yaylımı geminin vuruşuna ekleniyor, ayrı bir mermi olayı üretilmiyor. İstemci droid ateşini bu tek olaydan çiziyor (2026-09-03): her yaylımda droid başına bir mermi, droidin bulunduğu yerden, droidin vurgu renginde, geminin dalgasının peşinden; hasar sayısı yine tek. Kalan: droidin kendi canı ve hedef alınabilmesi, sonra ayakta kalmanın ölçülmesi; droid ölebildiği gün ayrı olay da gerekebilir.

## B18 · Model tavanları ve özel droidler
Durum: kapandı · Kaynak: 04.10 · 05.8 · 2026-09-03 → 2026-09-03

Kapandı: tek tavan kaldı (04.10). Yeni merdivende model bir rank basamağı, ayrı sınıf değil; model başına tavan rank başına tavan olurdu. Özel droid istenirse ayrı eşya ailesi.

Filo tavanı on, tek sayı. Eski merdivende Vane ile Corona birlikte en çok sekizdi, Taurus ve Jove birer tane dokuzuncu ve onuncuydu. Model başına tavan istenirse tepe tabloya kategorik bir kural girer; bugün filoya on Vane alınabiliyor.

## B19 · Filo yuvaları nesil bütçesine girmiyor
Durum: kapandı · Kaynak: 13.6 · 14.3 · 2026-09-03 → 2026-09-03

Kapandı: filo ayrı kalem (13.6 s2, 14.3 s2). Artı payının droid payı kadarı (yüzde on beş) on filo yuvasına, kalanı gövde yuvalarına: gövde yuvası başına bütçe yüzde on beş düştü, yarıya değil. Ganimette droid eşyası kendi zarını atıyor: filo şansı aynı kuraldan (on yuva, aynı kalite hedefi), gövde şansına eklenmeden yanında; gövde zarı artık droid tipi çekmiyor. Endgame kuyruğu filoyu da sayıyor.

Yuva başına artı bütçesi ve ganimet arzı gövde yuvalarını sayıyor; filonun on yuvası sayılmıyor. Droid eşyası ganimetten düşüyor ve artı basıyor ama ekonomi onu yuva olarak görmüyor: on droid eklenirse yuva başına bütçe yarıya iner ve ulaşılan artı seviyesi düşer. Sayılsın mı, ayrı bir kalem mi olsun: 13'ün kararı.

## B20 · Roket sistemi yok
Durum: kapandı · Kaynak: 04.11 · 06 · 17 · 18 · 2026-09-03 → 2026-09-03

Kapandı: alan 18 açıldı ve kodlandı. Roketatar bir silah: taban hasarı roket kapsamına (02.3'e üçüncü kapsam), her altı saniyede bir salvo, zincir geminin; roket mermisi RK-1 bedava, üstü 17'nin eğrisinin birim oranı katı; stok hesapta, seçim savaş çubuğundaki ROKET düğmesinde, mağazada raf; ayrı atış olayı ve çizim. Bir girdi (`roketAraligi`), bir kilit. Roketatarın bütçe payı değişmedi, biçimi değişti: bonus değil DPS.

## B21 · Başlangıç kredisi taban eşyayı karşılamıyor
Durum: kapandı · Kaynak: 15.2 · 15.8 · 13.3 · 2026-09-03 → 2026-09-04

Kapandı: başlangıç kredisi TÜRETİLİYOR (15.8). Sayı değil oran ilan edildi — ilk bandın raf fiyatı × `baslangicEsyaSayisi = 2`, yani bugün 189.044 kredi. İki, çünkü başlangıç gemisinde takılı olan tek şey bir lazer: bir eşyalık kredi yalnız "satın al"ı öğretir ve oyuncuyu ilk alışverişinde sıfırda bırakır, iki eşyalık kredi ilk seçimi öğretir (ikinci namlu mu, ilk jeneratör mü). Üçü hediye olurdu; nesil başına mağaza payı zaten dört eşya. Mağaza payı ya da nesil bütçesi kayınca kredi kendiliğinden kayıyor, elle güncellenecek sayı kalmadı.

Raf 15.2'nin fiyat modeline geçince ilk bandın taban eşyası 94.522 kredi; başlangıç kredisi 30.000 (`Hangar.startingCredits`, tasarım girdisi değil, eski 12.000'lik rafa göre konmuştu). Yeni oyuncu ilk saatinde raftan hiçbir şey alamıyor. Belgeye göre bu kusur olmayabilir: raf "zemin", ganimet on üç dakikada bir düşüyor, mağaza payı nesil başına dört eşya. Seçenekler: başlangıç kredisini bir taban eşyaya çıkarmak (yaklaşık 100.000) ya da olduğu gibi bırakıp rafı nesil ortası dolgusu saymak. Hangar testleri ve önizlemeler alım için geliştirme zenginliğini kullanıyor.

## B22 · Fiyat referansı çıplak, oyuncu referansı dolu
Durum: kapandı · Kaynak: 03.2 · 04.5 · 2026-09-03 → 2026-09-04

Kapandı: fiyat DOLU referansta ölçülüyor ve döngü yinelemeyle çözüldü (03.2 s2, `FiyatCozumu`). Tohum eski ölçüm noktası; her adım o fiyatlarla referansı kurup fiyatı yeniden ölçüyor. İki adımda ve tam sıfır sapmayla yakınsıyor — ilk bandın rafında yüzdesel ANA stat yok, yani bugünkü rafta geri besleme yok; raf değişirse yineleme işini yapar, yakınsamazsa çözücü hata atıyor (ikinci yol, düz sayılara çapalama, o gün gerekir). Ölçülen: yüzde statların puan fiyatı ×0,495 (bir bütçe puanı yarısı kadar yüzde alıyor), zırh ve kaçınma ×0,396, son azaltma ×0,800; düz taban hasar, havuz çapaları ve kalkan yenilenmesi kılını kıpırdatmadı. Referans TTK yine tam 30 (gövde çapası aynı kısıttan çözülüyor). Shapley'de lazerin sapması +8,34'ten +5,16'ya, jeneratörünki −2,80'den −0,71'e, roketatarınki +1,52'den +0,93'e indi; gövdeninki +4,81'den +7,25'e, droidinki −8,03'ten −8,83'e çıktı ve en büyük sapma 8,34 → 8,83 oldu, `payBandi = 10`'un içinde. Droidin ana statı yüzdesel (hasar artışı) ve değeri GEMİDE fiyatlanıyor ama DROİD zincirinde harcanıyor; kapsam farkı B22'nin değil, filo payının sorusu.

Referans tam donanıma geçti (B1) ama fiyatlar çıplak gövde ile katalog C-I lazerden ölçülmeye devam ediyor (`ShipStats.bastion`): eşya değerleri fiyata bağlı, fiyatı dolu build'den türetmek sabit nokta ister (fiyat → eşya değeri → referans DPS → fiyat). Sonuç iki yerde görünüyor. Bir: referans lazer 200'den 140'a inince yüzde statların puan fiyatı ×1,43 pahalandı (bir yüzde puanı çıplak referansın DPS'ine göre değer görüyor); düz taban hasar sabit. İki: dolu referansta bir yüzde puanı daha çok DPS ediyor, yani yüzde statlar gerçek oyuncuda fiyatından değerli; B12'nin Shapley ölçümü bunu payların sapması olarak gösterecek. Çözüm adayı: fiyatı yinelemeli çözmek (birkaç adımda yakınsıyorsa) ya da fiyat referansını dolu build'in düz sayılarına çapalayan tek bir girdi. Karar sizin.

## B23 · Filo bakımı NOVA musluğunun dörtte biri
Durum: izleniyor · Kaynak: 05.10 · 15.3 · 2026-09-04

Ölçüm: tam filo (on droid), her ölümde tam onarılırsa, ilan edilen ölüm sıklığında (`genelOlumSikligi = 1`) saatte 100 NOVA yiyor; musluk saatte 400. Yani en kötü durumda oyuncunun NOVA gelirinin dörtte biri filo bakımına gidiyor. Bu bir tavan, taban değil: onarmayan oyuncu hiç ödemiyor, droidini kaybediyor ve yerine ganimetten geleni alıyor.

Ölüm sıklığı playtest girdisi ve bugün yer tutucu. Saatte üç ölüme çıkarsa bakım musluğun dörtte üçünü yer ve droid tutmak NOVA'nın tek işi olur; o noktada düzeltilecek yer aşınma payı (`droidAsinmaPayi`), onarım fiyatı değil — fiyat kaybın süresinden türüyor ve elle indirilirse NOVA beklemeyi değil eşyayı satmaya başlar.

Bakılacak: gerçek ölüm sıklığı ölçüldüğünde bakım payı nereye oturuyor?

## B24 · Droid tasarımını oyuncu seçemiyor
Durum: kapandı · Kaynak: 05.8 · 15.9 · 2026-09-04 → 2026-09-04

Kapandı: görünüş NOVA ile satılıyor (15.9). Sekiz tasarım ve on dokuz formasyon rafta; sahiplik hesapta, seçim örnekte, yani aynı oyuncunun iki droidi iki ayrı tasarım giyebiliyor. Satın alınan iki droidin kendi görünüşü ve varsayılan formasyon hep sahipli. Fiyat türetilemedi ve nedeni yazıldı: görünüş hiçbir bekleme kısaltmıyor, 15.3'ün formülü sıfır verir.

On tasarım var, oyuncunun seçimi yok: iki satın alınabilir droidin görünüşü sabit (Delta, Hilal), kalan sekizi rank seçiyor. Yani tasarım bir ödül değil, bir sonuç — oyuncu "şu droidi istiyorum" diyemiyor.

Deri sistemi istenirse üç şey gerekir: örnekte bir tasarım alanı (dayanıklılık gibi), bir edinme kuralı (ganimet mi, NOVA mı, unvan mı) ve hangarda bir seçici. Üçü de tasarım kararı; ekonomiye bağlanacaksa 15'in yasak listesi de okunmalı — görünüş güç değil, yani NOVA satabilir.

Bakılacak: tasarım seçimi bir ödül kanalı mı olsun, yoksa rankın işareti olarak mı kalsın?

## B25 · Elit droid parayla güç mü satıyor
Durum: açık · Kaynak: 15.7 · 15.1 · 05.8 · 2026-09-04

NOVA rafı üç taban tasarım satıyor ve biri droid (Hilal, 05.8 s2). Raf üç sınırla çevrili — taban eşya, merdivenin dibi, üç tasarım — ama sınırların içinde kalan gerçek şu: ödeyen oyuncu ilk bantlarda daha iyi bir droidle uçuyor. On beş alan boyunca savunulan "para güç satmaz" cümlesi burada ilk kez esniyor.

İki okuma var. Bir: bu zaten eski tasarımın kabulü — NOVA rafı lazerde ve jeneratörde de var, droid onların üçüncüsü ve fark bir kademe, alt stat yok, ganimet döngüsü dokunulmadı. İki: droid FİLO demek ve filo on yuva; bir kademe fark on yuvada toplanınca lazerdeki bir kademeden büyük çıkabilir. İkincisi ölçülmedi.

**Ölçüldü (2026-09-04) — ikinci okuma gerçekleşmedi.** Ölçüm `core/denetim/elit_droid_olcumu.dart` içinde yaşıyor, eşikleri `core-test/elit_droid_olcumu_test.dart`'ta; kayan bir denge testi kırar. Kurulum: aynı bant, aynı gövde, aynı artı seviyesi, tam filo (on droid), her iki tarafta da alt statsız taban eşya, droidlerin taşıdığı donanım her varyantta kredi rafından. Ölçüt savaş puanı — "hangisi daha iyi" sorusunun oyundaki tek yetkilisi o (`LoadoutResolver.yukseltmeMi` da onu okuyor) — ve BR'nin geometrik ortalaması iki kanala birden yazan droidi kayırmasın diye aynı iki kanalın toplamsal okuması da alındı; ikisi aynı yönü söylüyor.

İlk bantta on NOVA droidi almak BR'yi **%19,89** artırıyor. Aynı bantta beş NOVA lazeri almak **%53,88**. Yani filo alımı lazer alımının **0,37 katı**, ödenen NOVA başına **0,19 katı** (on yuvalık droid alımı beş yuvalık lazer alımının tam iki katı pahalı: 24.270 ↔ 12.135 NOVA). İkinci bantta oran **0,26** (%7,16 ↔ %27,49); üçüncü banttan itibaren NOVA droidi almak DÜŞÜŞ, çünkü raf B-I'de sabit ve kredi rafı bandı izleyerek onu geçiyor — kademe 3'te −%15,71, kademe 7'de −%79,48. Ödeyenin önde olduğu bant sayısı iki. Merdivenin kendi biriminde: droid alımı **0,50 rank adımı**, lazer alımı **1,18 rank adımı** (bir rank adımı %44,2).

Sebebi 05.4 s5'in kendi kararında ve bir kusur değil: droidin rankı taşıdığı lazerin TABAN hasarını büyütmüyor, yalnız kendi statlarını ve havuzunu; gemideki lazerin rankı ise doğrudan yaylımın tabanına biniyor. On yuva beş yuvadan çok ama her yuvanın kaldıracı çok daha küçük.

Elitin farkı yalnız rank değil, ikisi ayrı ayrı ölçüldü (05.4 s5, B25 yazıldığında yoktu): ilk bantta rank farkı **%8,96**, taşıma farkı (bir yuva yerine iki) **%6,98**, ikisinin etkileşimi **%3,94**. Yani "bir kademe fark" hikâyenin yarısından azı; rafın rankını indirmek sorunun ancak yarısını kapatır. Taşıma farkının kapsamı da göründüğünden dar: `Catalogue.droidYuvaSayisi` para birimine bakıyor, merdivenden türetilen droidler şablonu elit Hilal'den aldığı için `currency`'yi de devralıyor, ve katalogdaki tek standart droid Delta. Yani taşıma avantajı YALNIZ ilk bantta var; ikinci banttan sonra kredi droidi de iki yuvalı. Bir yan bulgu daha: ikinci yuvaya hangi tipin gireceğini hiçbir kural bağlamıyor, ve en iyi seçim iki lazer — 05.4'ün "hem vurur hem dayanır" cümlesinin birebir hâli %19,89 yerine %10,37 veriyor.

Kararı verecek kişinin önündeki seçenek: (a) rafı olduğu gibi bırakmak — ikinci okuma ölçüldü ve tutmadı, filo lazerin gerisinde; (b) ölçümün asıl işaret ettiği yere bakmak — rafın en büyük kalemi droid değil LAZER, ilk bantta tek başına bir tam rank adımından fazlasını satıyor, yani "esneme" varsa orada; (c) elit droidin ikinci yuvasına tip şartı koymak — droid alımının kazancını %19,89'dan %10,37'ye indirir ve hiçbir denge sayısına dokunmaz, çünkü değişen bir kural, bir sayı değil.

Bakılacak: tam filo elit droidle ne kadar öne geçiyor, ve bu fark 09'un savaş puanı bandının içinde mi kalıyor?

## B26 · 02.8 havuzu CPU diyor, kod droid diyor
Durum: kapandı · Kaynak: 02.8 · 06.8 · 2026-09-04 → 2026-09-04

Kapandı: belge koda uydu (02.8 s3). Cümle artık "lazer, roketatar ve droid havuzlarında" diyor; kataloğa dokunulmadı, çünkü kritik hasarını CPU'ya sokmak 06.8'in koda uyan havuz tablosunu ve 06.7'nin kanal uyumu kuralını yeniden açmak olurdu — ikisi de sağlam. Kararın sürümü s2'den s3'e çıktı, üç atıf (`stat.dart`, `stat_kaydi_test.dart` ×2) yeni sürüme geçti. Testin droid yuvasını da sorması hâlâ yapılmadı: bugün yalnız lazer ve roketatar sınanıyor, yani cümlenin üçüncü yarısı belgede doğru ama testte değil.

Belge (02.8) kritik hasarının "lazer, roketatar ve CPU havuzlarında" olduğunu söylüyor; kodda lazer, roketatar ve DROİD havuzlarında, hiçbir CPU tasarımında yok. 06.8'in havuz tablosu koda uyuyor, yani bayat olan 02.8'in cümlesi.

Test kapsamı çalışmasında bulundu (2026-09-04) ve dokunulmadı: kod da belge de olduğu gibi duruyor, test yalnız gerçekten tutan yarıyı sınıyor. Düzeltme yönü sizin: ya 02.8'in cümlesi droid der, ya CPU havuzlarına kritik hasarı girer.

## B27 · α türetilen değil, girdi; 780 saati tutturan başka şey
Durum: kapandı · Kaynak: 10.5 · 2026-09-04 → 2026-09-04

Kapandı: belge koda uydu (10.5 s2). α artık "teknik olarak türetilen" değil GİRDİ olarak yazılıyor, ve 780 saati tutturan şeyin süre ölçeği olduğu söyleniyor: `sureOlcegiFor` bağıl süreleri toplamları hedefe eşitlenecek biçimde bölüyor, yani toplam herhangi bir α'da tam 780 çıkıyor. α'ya kalan iş nesillerin birbirine göre uzunluğu; hedef süre değişince yeniden çözülen şey ölçek, α değil. Kod tarafında yalnız `hedefSure`'nin "değiştiği an gelir üssü yeniden çözülüyor" diyen bayat yorumu düzeltildi; α'yı çözen bir yordam yazılmadı, çünkü çözülecek bir şey yok. Sekiz atıf s2'ye geçti.

Belge diyor ki: `gelirUssu = 0,816` teknik olarak türetilen, hedef süreyi tutturan tek değer, hedef süre değişirse kendiliğinden yeniden çözülür. Kodda α bir sabit ve tepe tabloda GİRDİ olarak ilan edilmiş; onu çözen bir yordam yok.

780 saati tutturan şey α değil süre ölçeği: `TuretilenTablolar.sureOlcegiFor` bağıl süreleri hedef süreye bölüyor, yani herhangi bir α için toplam tam 780 çıkıyor. α'nın işi süreyi tutturmak değil, nesillerin BİRBİRİNE göre uzunluğunu belirlemek.

Test kapsamı çalışmasında bulundu (2026-09-04), dokunulmadı. Düzeltme yönü sizin: ya belge α'yı girdi ilan eder ve işini doğru anlatır, ya kod α'yı gerçekten çözer.

## B28 · 12.2'nin örnek sayıları referans değişince bayatladı
Durum: kapandı · Kaynak: 12.2 · 04.5 · 2026-09-04 → 2026-09-04

Kapandı: belge koda uydu (12.2 s2). İki sayı artık elle yazılmıyor, türetilen etiketiyle anılıyor (16.7): `yaratikCani(0)` ve `yaratikCaniGuclu(0)` `TuretilenKaydi.islevler`e eklendi ve `DusmanTasarimi.can`'ı çağırıyor, yani referans bir daha oynadığında belge kendiliğinden eskimeyecek — denetim onları her koşuda yeniden hesaplıyor. Cümle de yönü düzeltiyor: türetilenler bugün elle konanların üstünde, ve bir zamanlar altındaydı. `CombatGlossary.expectedDps`'in "909 × 1,250 = 1.136" örneği de bugünkü referansa çekildi ve bir sözleşme değil örnek olduğu yazıldı. Yedi atıf s2'ye geçti.

Belge "türetilen 1.136 ve 5.682, elle konanlar (1.600 ve 9.000) yüzde kırk ve elli sekiz yüksekti" diyor. Referans tam donanıma geçtiğinden beri (04.5 s2) kodun ürettiği tablo ilk bant için 2.008 ve 10.041 yazıyor: yön tersine döndü, türetilen değerler bugün elle konmuşların üstünde.

Kural (can = süre × referans DPS) bozulmadı ve sınandı; bayat olan yalnız gövde metnindeki iki sayı ve o cümle. Aynı bayatlama `CombatGlossary` yorumunda da var. Sayıları belgeye elle yazmak yerine türetilen etiketle anmak (16.7) bunu bir daha yaşatmaz.

## B29 · 08.2'nin lazer örneği kırılamaz bir değişmez
Durum: kapandı · Kaynak: 08.2 · 04.9 · 2026-09-04 → 2026-09-04

Kapandı: örnek jeneratöre çevrildi (08.2 s2), yuva sayısı gövdeyle değişmedi. Bakılacak iki yoldan ilki seçildi: lazer yuvasını gövdeyle oynatmak 04.9'un sanat kısıtını (kaide sayısı = yuva sayısı) ve sekiz gövde çizimini yeniden açardı, karşılığında kazanılan tek şey bir örnek cümlesiydi. Belge artık kuralın neden yalnız jeneratörle CPU'da GÖRÜNDÜĞÜNÜ de söylüyor ve değişmezi kırılabilir hâline çeviriyor: "adet × katsayı gövdeden bağımsız; yuva kazanan grupta katsayı düşüyor" — testin zaten ölçtüğü iki cümle. `slotCoefficient`'ın aynı bayat örneği taşıyan yorumu da düzeltildi. Altı atıf s2'ye geçti.

Belge diyor ki "SS gövdedeki bir lazer, C gövdedeki bir lazerden zayıf" ve değişmez tablosu da bunu sayıyor. Oysa sekiz gövdenin hepsinde lazer yuvası beş (04.9: yuva sayısı çizimdeki namluya bağlı), yani lazer katsayısı normalizasyon gereği her gövdede tam 1,00 ve o değişmez hiçbir zaman kırılamaz.

Kural yanlış değil, örneği yanlış: katsayı gerçekten gövdeye bağlı ve jeneratör ile CPU'da değişiyor. Test kapsamı çalışmasında bulundu (2026-09-04); kural o iki tipte ve "adet × katsayı gövdeden bağımsız" biçiminde sınandı.

Bakılacak: 08.2'nin örneği jeneratöre mi çevrilsin, yoksa lazer yuvası sayısı gövdeyle değişsin mi (o zaman 04.9'un sanat kısıtı da değişir)?

## B30 · 06.6'nın %43 eşiği bugünkü merdivende bağlayıcı değil
Durum: kapandı · Kaynak: 06.6 · 2026-09-04 → 2026-09-04

Kapandı: belge bugünkü merdivene çekildi (06.6 s2). %43 eşiği gitti; yerine ölçülebilir bir cümle geldi: alt stat payı %100 olsaydı C–S bandında en dar boğaz tam `rankArtisi` × `kaliteAltSiniri` olurdu ve o çarpım birin üstünde, yani çakışmanın başladığı bir eşik yok. İki sayı da girdi etiketiyle yazıldı, bir daha elle çürümeyecekler. Kararın değişmezi ve testleri olduğu gibi duruyor — kısıt bugün bol olduğu için değil, merdiven oranı ya da kalite bandı değişirse ilk kırılacak şey olduğu için sınanmaya devam ediyor. %70'in gerekçesi 06.5'e döndü; `anaStatPayi`'nın aynı %43'ü tekrarlayan yorumu da düzeltildi. Dört atıf s2'ye geçti.

Belge "alt stat payı %43'ü geçtiğinde mükemmel rollü C, berbat rollü B'yi yakalar" diyor ve eşiğin kendiliğinden yeniden hesaplandığını söylüyor. Bugünkü sayılarla (`rankArtisi = 1,442`, `kaliteAltSiniri = 0,70`) en kötü rollü üst rank, en iyi rollü alt rankın 1,0094 katı: ana stat payı sıfır olsa bile çakışma yok, yani %100'ün altında bir eşik yok.

Kural bozulmadı ve sınandı: hiçbir bitişik rank çiftinde çakışma yok, en dar boğaz 1'in üstünde. Bayat olan yalnız %43 sayısı ve onu üreten cümle. Test kapsamı çalışmasında bulundu (2026-09-04), dokunulmadı.

## B31 · Filonun ölçülen DPS payı ilan edilenin üstünde
Durum: açık · Kaynak: 05.4 · 05.5 · 09.6 · 2026-09-04

Droid bir taşıyıcı oldu (05.4 s4) ve filo payı ikiye bölündü: gövdelere kalan kısım ile içine takılana giden kısım. Bölüşüm YAYLIM düzeyinde çözülüyor — tam donanımlı standart filonun taban hasarı, geminin lazer yaylımının tam `droidDpsPayi = %15`'i. Ölçüldü ve tutuyor.

Ama DPS payı %25 çıkıyor. Sebep basit: droid gövdeleri de hasar artışı taşıyor ve o çarpan takılan lazerin tabanını büyütüyor. Yani yaylım payı ilan edilen, DPS payı ilanın 1,68 katı.

İki yol var. Bir: bölüşümü DPS düzeyinde çözmek — gövdenin çarpanı ile donanımın tabanı birbirini beslediği için sabit nokta, sayısal çözüm ister (`brOlcegi` gibi). İki: 09.6'nın payını yaylım payı olarak ilan etmek ve DPS payını ölçülen değer olarak bırakmak.

Bakılacak: ilan edilen pay hangi düzeyde tanımlansın — yaylım mı, DPS mi?

## B32 · ArGe ham güç vermiyor; verecekse 08 yeniden bölünür
Durum: açık · Kaynak: 05.7 · 08.1 · 2026-09-04

ArGe kodlandı (05.7 s2) ve bilerek GÜÇ-NÖTR: iki dal σ'yı zıt yönlere itiyor, üçüncü uç bir izin açıyor. Toplam güç değişmiyor, yeri değişiyor.

Sebep 08'in bütçesi. Bir düğüm "%5 hasar" verseydi ArGe yedinci bir grup olurdu ve altı grubun payı elle düşürülmek zorunda kalırdı — yani ağaç, kendisi için bütün eşya ekonomisini yeniden ölçmeyi gerektirirdi. Güç-nötr ağaç bu hesabı hiç açmıyor.

Karar sizin: ağaç ham güç de versin mi? Verecekse 08.1'e `payArGe` girer, altı pay yeniden normalize edilir ve referans build ArGe'siz mi ArGe'li mi tanımlanır (bugün ArGe referansta yok). Vermeyecekse bugünkü hâli kalıcıdır ve ağaç bir yön aracı olarak kalır.

Bugünkü ağaç küçük: iki yön dalı üçer düğüm, iki izin. Dal ekleme kararı da bu maddeye bağlı — güç-nötr kaldığı sürece dal sayısı bir denge sorusu değil bir içerik sorusu.

## B33 · ArGe ağacının ekranı yok
Durum: kapandı · Kaynak: 05.7 · 10.4 · 04.10 · 2026-09-04 → 2026-09-04

Kapandı: ekran PİLOT KARTINDAN açılıyor (`lib/hangar/arge_karti.dart`). Eksik sayılan üç şeyin üçü de orada — iki dal yan yana, dal başına dört düğümlük zincir ve aralarındaki bağ çizgisi; başlıkta harcanan/toplam ve kalan puan; altta AĞACI SIFIRLA. Üç ekran boyunda görsel referansı var (`tool/menu_{masaustu,telefon,dar}_arge.png`).

Nereye gireceği kararı: PİLOT KARTI, ayrı sekme değil. Gerekçe puanın nereden geldiği — ArGe puanı SEVİYEDEN geliyor (10.1) ve pilot kartı zaten seviyeyi, unvanı ve sıradaki eşiği gösteren yüzey (10.4 s2). "Kaç puanım var" ile "onları nereye harcarım" aynı yerde durmalı. Beşinci bir hangar sekmesi, oyuncunun yalnız seviye atladığında baktığı bir sistem için dört sekmelik düzeni bozardı.

Ağaç kartın İÇİNE gömülmedi, karttan açılan ayrı bir pencere oldu ve bu da ölçülmüş: gövdeye konan bir ArGe bloğu (bölüm etiketi + tam genişlikte düğme) 105 piksel tutuyor ve görsel referans masaüstünde bile dördüncü çağın merdiven satırını kaydırma alanının altına düşürdü — ArGe'yi eklemek merdiveni kırpıyordu. Giriş noktası artık kartın ZATEN var olan alt şeridinde, KAPAT'ın yanında: ikinci düğme hiç yer eklemiyor, sayacı etiketinde taşıyor (`ARGE · 3/6 PUAN`) ve kaydırmadan görünüyor. Ağaç kartın üstüne açılıyor, kart altta açık kalıyor; kapatan oyuncu geldiği yere dönüyor.

Protokol DEĞİŞMEDİ ve sürüm artmadı. `Hangar.toJson()` `argeDugumleri`'ni zaten yazıyordu ve sunucunun tek üreticisi (`Gateway._hangarJson`) onu olduğu gibi yayıyordu; eksik olan tek şey `HangarView`'ün o alanı okumasıydı. Sayıların hiçbiri istemcide türetilmiyor: puan `ArGe.puanFor`, harcanan `ArGe.harcanan`, alınabilirlik `ArGe.alinabilir` — sunucunun kabul ederken sorduğu yordamların ta kendisi. İki ayrı uygulama, oyuncunun basabildiği bir düğümden ret yemesi demekti.

Kapanırken bulunan ve düzeltilen sessiz hata: hangar ekranı filo tavanını `TasarimGirdileri.droidFiloTavani` sabitinden okuyordu ve o sabit ArGe'yi tanımıyor. İzin düğümünü alan oyuncunun sunucusu on bir droid kabul ederken ekran "10/10 · FİLO DOLU" diyordu — ağacın tek görünür ödülü, ekranın göstermediği bir yuvaydı. Hesap `ArGe.filoTavani`'na taşındı; `Hangar.filoTavani` ve `HangarView.filoTavani` aynı yordamı çağırıyor.

Sıfırlamaya ONAY PENCERESİ konmadı ve bu bir eksiklik değil bir sınır: `OnayPenceresi` geri ALINAMAZ işlemler için (çevirme bir rolü siliyor, parçalama eşyayı yok ediyor). ArGe sıfırlaması bedava ve sınırsız (05.7) — puanların hepsi geri geliyor, aynı düğümler yeniden alınabiliyor, kaybedilen tek şey birkaç dokunuş. Bedelsiz bir işlemin önüne onay koymak, onayı refleksle geçilen bir adıma çevirir ve o refleks bir gün gerçekten yıkıcı bir pencerede işler. Yerine geçen koruma daha ucuz: ağaç boşken düğme kapalı.

Üç dil kimlikten çevriliyor (`lib/dil/icerik.dart`): dal adları `ArGeDali` enum'undan `switch` ile — dördüncü bir dal eklendiği gün o satır DERLENMEZ — düğüm adları `ArGeDugumu.id`'den, izin açıklamaları `ArGeIzni`'nden. Çekirdekteki `ad` alanı tasarım belgelerinin kanonik Türkçesi olarak duruyor; ondan çevirmek B36'nın tuzağı olurdu. Ekranda σ harfi YOK: aktarım katsayısını σ diye yazan ilk taslak görsel referansta boş kutu çıktı (menünün tek aralıklı yüzünde Yunan harfi yok) ve kelime zaten daha dürüst — oyuncu σ'yı bilmiyor, "gücün nereye gittiğini" biliyor.

Açık kalan: 10.7 ArGe için bir açılış eşiği ilan ediyor ama sistemi bağlamıyor ("eşik ilan, sistem yok"), yani ağaç birinci dakikadan itibaren görünüyor. Bu ekranın değil o kararın borcu ve kapatılmadı.

## B34 · Yaratık, gövde ve unvan adları çevrilmedi
Durum: açık · Kaynak: 12.7 · 04.12 · 10.4 · 2026-09-04

Üç dil geldi ve bu üç ad kümesi bilerek dışarıda kaldı: otuz iki yaratık (12.7), sekiz gövde (04.12) ve yirmi unvan (10.4) her dilde aynı yazılıyor. Gerekçe özel ad kuralı — "Interdictor'ı kim çekiyor" diye soran bir oyuncuyla "chi tira l'Interdittore" diyen bir oyuncu aynı yaratıktan bahsettiğini anlayamaz; çeviri, oyuncular arası konuşmayı bölerdi. Kodlar (MR-1, C-II) için aynı gerekçe tartışmasız, çünkü onlar zaten ad değil kimlik.

Tartışmalı olan ortadaki kümeler. "Vanguard" bir marka adı gibi duruyor ama "Squire" bir RÜTBE — İtalyanca'da karşılığı var ve oyuncu onu bir ad değil bir aşama olarak okuyor. Yaratıklarda da ikisi karışık: Void Spore bir tür adı, Interdictor bir rol adı.

Bakılacak: İtalyanca oynayan biri unvan merdivenini okuduğunda ilerleme sırasını anlıyor mu, yoksa yirmi yabancı kelime mi görüyor? Ölçüt playtest; bugün karar değişirse maliyeti düşük — üç küme de `lib/dil/icerik.dart` içinde çevrilmiş kardeşlerinin yanında duruyor ve çeviri eklemek bir satır. Ertelemenin sebebi maliyeti değil geri dönüşü: çevrilen bir özel adı geri almak, oyuncunun öğrendiği adı elinden almak demek.

## B35 · Gövde tasarım notları Türkçe ve çevrilmiyor
Durum: açık · Kaynak: 04.12 · 04.9 · 2026-09-04

`lib/game/art/govde_tasarimlari.dart` içindeki sekiz tasarımın her birinde bir `not:` alanı var ("Merdivenin dibi. Tek jet ve en dar kaide açıklığı…") ve hepsi Türkçe. Bugün bir sorun değil: not oyuncuya değil, silüet sırasını savunan sanat kaydına yazılıyor — kararın kendisi 04.12'de, notlar o kararın kademe başına gerekçesi.

Borç olmasının sebebi, bu alanın oyuncuya görünmeye ADAY olması: filo penceresi kilitli gemileri de listeliyor ve bir gövdenin neden o kademede olduğunu anlatan tek metin bu. Görünür kılınırsa üç dilde yazılması gerekir, yani ya `Metin` enum'una sekiz değer girer ya da not alanı üçlüye döner.

Bugün hangisi olacağına karar vermek erken; kaydedilen şey şu: notu ekrana koyan commit aynı zamanda çeviri commit'idir. Sessizce Türkçe bir açıklama gösteren bir menü, "eksik çeviri derlenmiyor" kuralının tek istisnası olurdu ve o istisna derleyiciye görünmez.

## B36 · Droid tasarım adlarının çevirisi kimliğe değil ADA bağlı
Durum: kapandı · Kaynak: 05.8 · 15.9 · 2026-09-04 → 2026-09-04

Kapandı: (a) yapıldı, ama borcun tarif ettiği biçimde değil — `DroidArt`a bir `kimlik` alanı EKLENMEDİ, çünkü gerekmedi. Borcun dayandığı önerme yanlıştı: paylaşılan kimlik uzayı zaten VAR ve zaten kullanılıyor. Tasarımın kimliği `ItemSpec.variant` içinde telden geliyor (`'halka'`), çekirdekteki `DroidModeli` ile sanattaki `DroidCizimi` o kimlikte birebir örtüşüyor ve örtüştüklerini `droid_ikonu_test.dart` kilitliyor; droidin RESMİ de bugün o kimlikten seçiliyor (`droidCizimiAdiyla`). Yani çeviri, sanata dokunmadan ve mimari kuralı hiç yoklamadan kimliğe bağlandı — dil katmanı `lib/game/art`ı zaten okumuyor, okumaya da başlamadı.

Sözlük SÖZLÜK OLMAKTAN da çıktı: `DroidModeli` kapalı bir enum ve çeviri artık onun üstünde bir `switch`. On birinci tasarım eklendiği gün `icerik.dart` DERLENMİYOR (sınandı: `non_exhaustive_switch_expression`). Bu, borcun önerdiği (b) testinden güçlü — test eksik çeviriyi yakalar, derleyici yazılmasına izin vermez. (b) yine de yazıldı, çünkü derleyicinin göremediği bir şeyi koruyor: `dil_test.dart` her kimliğin üç dilde karşılığı olduğunu ve Türkçe sütunun ÇİZİM KATALOGUYLA aynı kaldığını sınıyor. Borcun senaryosu (`'Çerçeve' → 'Kafes'`) artık sessizce Türkçeye düşmüyor, testi kırıyor.

Aynı süpürmede iki kardeş bozulma daha çıktı ve ikisi de kapatıldı. Biri mağazanın tasarım rafındaydı: ad, `DroidCizimi.values[t.index]` ile iki numaralandırmanın bugünkü SIRASINA güvenilerek sanat katalogundan okunuyordu — birine bir tasarım eklendiği gün bütün satırlar sessizce kayardı, ki `droid_ikonu.dart` aynı tuzağı resim tarafında bilerek atlatıyor. Öteki `esyaAdi`deydi ve çeviriyle hiç ilgisi yoktu: çekirdek üst rankları şablonun İLK KELİMESİYLE adlandırıyor, CPU şablonunun ilk kelimesi de Türkçe — İngilizce oynayan oyuncu on dokuz CPU eşyasında "Tamir SS-I" görüyordu. Önek artık YUVADAN çevriliyor (kapalı enum, yine derleyici kilidi). `dr5`in adı `_rafAdlari`ndan da silindi: droidin adı tasarımının adı ve iki tabloda durması, birinin güncellenmeden kalması demekti.

Tarama sonucu: `lib/dil/` altında metinle anahtarlanan başka tablo yok. Statlar, formasyonlar, raf adları ve ArGe düğümleri kimlikle; bölgeler ve ünvan çağları sırayla (kimlikleri kademe); geri kalanı kapalı enum üstünde `switch`. Yeni bir kilit de kondu: `dil_test.dart` artık her katalog eşyasının TÜRKÇE adının çekirdeğinkiyle birebir aynı olduğunu sınıyor — tek eşitlik, ölü kimliği de yanlış yazılmış Türkçeyi de eskiyen öneki de yakalıyor.

Aşağıdaki üç paragraf borcun kapanmadan önceki hâli.

`lib/dil/icerik.dart` içindeki `_droidTasarimlari` sözlüğü on tasarımı (05.8) Türkçe ADLARIYLA anahtarlıyor — `'Halka' → (Halka, Ring, Anello')` — oysa aynı dosyadaki diğer bütün tablolar kararlı KİMLİKLE eşleşiyor. Sebep mimari: çizim katalogu `lib/game/art` altında ve orası çekirdeği tanımıyor (`architecture_test.dart` kilitliyor), yani droid tasarımının paylaşılan bir kimlik uzayı yok.

Bedeli sessiz bir bozulma. Katalogda bir ad düzeltilirse (`'Çerçeve' → 'Kafes'`) sözlük ıskalıyor, `droidTasarimAdi` tanımadığı adı aynen döndürüyor ve İngilizce oynayan bir oyuncu mağazada Türkçe bir droid adı görüyor. Ne derleyici ne test bunu söyler; ilan edilen kural tam da bunun için "görünen metinden değil kimlikten çevir" diyor ve tek istisnası bu.

Bugün kabul edilebilir, çünkü katalog on satır ve sözlüğün hemen yanında duruyor — ama tasarımlar NOVA ile satılıyor (15.9), yani bu liste büyümeye açık. İki çıkış var: `DroidArt`a çekirdek tanımadan bir `kimlik` alanı eklemek (art katmanı kendi kimliğini üretebilir, çekirdeğe bağlanmadan), ya da on adın sözlükte var olduğunu sınayan bir test yazıp bozulmayı sessiz olmaktan çıkarmak. İkincisi bugün beş satır.

## B37 · Sunucu günlükleri Türkçe kalıyor
Durum: kapandı · Kaynak: 16.6 · README · 2026-09-04 → 2026-09-04

Karar: kalsın. `server/lib/gateway.dart` içindeki `stdout` satırları (`· kimlik: …`, `☠ … doğdu`, `⚠ hangar yazılamadı`) çeviriye girmiyor ve bu bir eksik değil, çevirinin sınırının nerede olduğunun ilanı.

Gerekçe okuyucu ayrımı: günlük oyuncuya değil OPERATÖRE yazılıyor. Oyuncuya giden her metin dili bilen tarafta kuruluyor — sunucu kod gönderiyor, istemci cümleyi yazıyor — ama günlüğün okuyucusu bu depoyu açan kişi ve o kişinin dili belgelerin dili. Günlüğü çevirmek, sunucuya bir dil vermek demekti: hangi dilde yazacağını bilmek için bir tercih okuması, o tercihin kime ait olduğunu sorması gerekirdi. Oysa günlüğün oturumla ilgisi yok, süreçle ilgisi var.

Sınır tek cümleyle sınanabilir olsun diye yazılıyor: `stdout`'a giden metin serbest Türkçe, sokete giden metin KOD. Aradaki tek gri alan `kimlik.sunucu-hatasi` — ayrıntısı günlüğe Türkçe yazılıyor, oyuncuya kod olarak gidiyor, ve bu ayrım doğru olanı.

## B38 · Eşzamanlı kayıt hangar günlüğünü yırtıyor
Durum: kapandı · Kaynak: 10.1 · 16.8 · 2026-09-04 → 2026-09-04

`data/hangars.jsonl` yırtık bulundu: 160 satırın 27'si çözülemiyordu. Yırtıkların hepsi bir kaydın KUYRUK parçasıydı — `":769},"seciliMermi":"MR-6"}` gibi, açılış süslü parantezi olmayan yirmi otuz baytlık artıklar — ve hepsi tek bir hesabın, en çok oynayan hesabın kayıtlarının arasına düşmüştü.

Sebep `save()` içindeki `File.writeAsString(mode: FileMode.append)`. `FileMode.append` bir "ekleme" sözü değil, sadece bir AÇILIŞ KONUMU: her çağrı dosyayı kendi açıyor, açılışta sonu buluyor ve oraya yazıyor. İki çağrı aynı anda açarsa ikisi de aynı sonu buluyor ve aynı yerin üstüne yazıyor. Uzun yazım kısa yazımın altından taşıyor, taşan parça yeni bir satır gibi görünüyor; kısa yazım uzun yazımı tamamen örterse geriye yırtık bile kalmıyor ve kayıt sessizce yok oluyor. Çıplak `dart:io` ile ölçüldü: aynı anda başlatılan yirmi yazımdan dosyada tek satır kaldı, on dokuz kayıt hiç yazılmamış gibi oldu; uzunlukları azalan yirmi yazımda ise bir geçerli satır ve on dokuz kuyruk parçası çıktı — gerçek dosyadaki hasarın birebir aynısı.

Eşzamanlılık kuramsal değil: `gateway.dart` hangarı üç ayrı yerden yazıyor ve ikisi `unawaited` — beş saniyelik toplu yazım (`_flushDirtyHangars`) ve oturum kopuşu (`_drop`). Üçüncüsü hangar mesajının içinden geliyor. Toplu yazım sürerken kopan bir oturum tam olarak bu yarışı kuruyor, ve yırtıkların hepsinin en aktif hesapta toplanması bunun izi. `compact()` de aynı yarışın ikinci yüzü: `rename` uçuşta olan bir eklemenin altından dosyayı çekiyor ve o ekleme, artık yerinden kaldırılmış düğüme yazılıp kayboluyordu.

Görülmemesinin sebebi hasarın kılığı. Yükleme bozuk satırı `hangar satırı atlandı (bozuk)` deyip geçiyordu: sayısı okunmayan, kimi vurduğu söylenmeyen, açılış gürültüsüne karışan tek bir satır. Oyuncu tarafında görünen şey bir hata değil, birkaç saniyelik bir geri sarma — 10.1 "sayaç düşmüyor" diyor ama düşen sayacı kimse bir bozulma olarak okumuyor, sunucunun geç kaydettiğini sanıyor. Testler de göremezdi: hepsi yazımları `await` ile sırayla yapıyordu, yani sınanan şey hiç oluşmayan bir durumdu. 16.8'in "kodda demek sınanmış demek" cümlesinin görmediği yer burası — kod doğruydu, sınanan senaryo eksikti.

Düzeltme üç parça. Bir: yazımlar tek bir `Future` zincirinde SIRAYA giriyor; ekleme O(1) kalıyor, sadece çakışma kalkıyor. Bütün dosyayı her yazımda yeniden yazmak da atomik olurdu ama bu deponun bütün gerekçesini bozardı. Zincir hatayla kopmuyor: diski dolu bir sunucuda tek bir patlayan yazım, arkasındaki bütün yazımları sağır bırakırdı. İki: `compact()` aynı sıraya alındı, `rename` artık uçuşta bir ekleme yokken oluyor. Üç: elenen satır sessiz kalmıyor — yükleme sonunda kaç satırın elendiğini ve kaç HESABI vurduğunu yazan görünür bir uyarı basılıyor, hesap yırtığın komşusundan okunuyor. Yırtık bulunan dosya eşiğe bakılmadan sıkıştırılıyor: sıkıştırma yaşayan kaydı tek seferde yazdığı için onarımın kendisi bu, ve eşiğe bırakılsaydı küçük ama yırtık bir dosya sonsuza kadar yırtık kalırdı. Redis'in `aof-load-truncated` davranışıyla aynı: bozuk kuyruğu kes, devam et, dosyayı temiz bırak.

## B39 · Sunucu testleri üretim verisine yazıyor
Durum: kapandı · Kaynak: 16.1 · 16.8 · 2026-09-04 → 2026-09-04

`server/test/` altındaki on altı dosya `Gateway` kuruyor, `accounts:` için geçici bir yol veriyor ve `hangars:`/`ledger:` VERMİYORDU. `Gateway({accounts, hangars, ledger})` üçünü de isteğe bağlı tutuyor, vermeyene kendi varsayılanını veriyor ve o varsayılan üretim dosyasıydı: `HangarStore({this.path = 'data/hangars.jsonl'})`, `LedgerStore({this.path = 'data/ledger.jsonl'})`. Yani her test koşusu oyuncunun gerçek ilerlemesinin ve para kaydının üstüne yazıyordu.

Ölçüldü: `server/data/` altında 4,9 MB hangar ve 49 MB defter birikmişti — testler `server/` dizininden koştuğu için göreli `data/…` oraya düşüyor. Kök `data/hangars.jsonl` de kurtulmamış: içinde `data/accounts.json`'da karşılığı OLMAYAN dört hangar var. Hesabı geçici bir dosyada, hangarı gerçek dosyada olan kayıtlar; başka türlü oluşamazlar. Aynı göreliliğin ikinci yüzü, hasarın neden iki ayrı yere dağıldığı: `dart test` `server/`den koşarsa `server/data/`, kökten koşarsa gerçek `data/` vuruluyor.

Çevre değişkeni bir savunma sanılıyordu ama değildi. `server/lib/` altında hiçbir yer `Platform.environment` okumuyordu; `ACCOUNTS` ve `HANGARS`'ı yalnız `bin/server.dart` okuyup depoya PARAMETRE olarak geçiyordu, `LEDGER` diye bir değişken ise hiç yoktu — defteri `bin/server.dart` kurmuyor bile, `Gateway` kendi varsayılanıyla kuruyor. Yani `ACCOUNTS=… HANGARS=… dart test` yazmak hiçbir şey yapmıyordu: yolun çevreden gelmesi giriş noktasına bağlıydı ve testler tam da o giriş noktasından geçmiyordu.

Düzeltme iki katmanlı ve ikincisi asıl olan. Bir: yolun kararı `server/lib/veri_yolu.dart` içinde TEK yere alındı; üç depo da varsayılanını oradan alıyor, yani `HANGARS`/`LEDGER`/`ACCOUNTS` artık depoyu kim kurarsa kursun çalışıyor. Bu tek başına yetmez — düz `dart test` yine üretime yazardı ve kusur zaten "geçersiz kılma yanlış" değil "geçersiz kılmayı unutmak SESSİZ" idi; unutulabilen bir korumanın adı koruma değil, âdet. İki: `package:test` koşucusu altında varsayılan yol üretim dosyası OLAMIYOR. Koşucu iki bağımsız imzadan saptanıyor (izolatın `test_suite:` önekli adı ve `dart_test.kernel` altındaki `.dill`), saptandığında varsayılan süreç başına bir geçici dizine düşüyor ve yol AÇIKÇA üretim dosyasını gösteriyorsa `StateError` atılıyor.

Varsayılanda yönlendirme, açık istekte ret — ayrım niyette. Her iki durumda da atmak daha güçlü görünüyordu ve reddedildi: yolu vermeyen on altı dosyayı aynı anda kırar, hepsinin tek tek düzenlenmesini şart koşardı. Yönlendirme aynı güvenceyi veriyor (üretim dosyasına tek bayt gitmiyor) ama testleri kırmak yerine doğru yapıyor. Yolu açıkça yazan kişi ise bir niyet bildiriyor ve o niyet testte her zaman bir hata; orada sessizce yön değiştirmek, insanın yazdığını sessizce başka bir şeye çevirmek olurdu. Yol karşılaştırması metin değil DOSYA üstünden: `data/hangars.jsonl`, `./data/…` ve mutlak yazılışı aynı dosya. Sembolik bağlantı çözülmüyor — bu bir kaza freni, güvenlik sınırı değil.

`bin/server.dart` artık çevreyi kendi okumuyor, depolar okuyor; üretim davranışı değişmedi, çevre verilmemişse yol yine `data/…`. `veri_yolu_test.dart` on iki sınamayla kilitliyor: korumanın devrede olduğu (yoksa geri kalan her sınama boşa geçerdi), üç deponun ve `hangars:`/`ledger:` verilmeyen bir `Gateway`'in üretim dosyasını göstermediği, üretim sabitlerinin yerinde durduğu, açık üretim yolunun reddedildiği ve önceliğin açık yol → çevre → varsayılan olduğu. Kanıt: iki tam `dart test` koşusundan önce ve sonra beş veri dosyasının md5'i ve değişim zamanı aynı kaldı. Biriken `server/data/` çöpü SİLİNMEDİ — testin ürettiği veri de olsa silmek bu düzeltmenin işi değil.

## B40 · Aynı yarış defterde de var — para kaydında
Durum: kapandı · Kaynak: 13.1 · 16.8 · 2026-09-04 → 2026-09-04

B38 hangar günlüğünü onarırken `ledger_store.dart` içindeki `flush()` aynı deseni satır satır sürdürüyordu: tek bir `File.writeAsString(mode: FileMode.append)`, sıra yok. `gateway.dart` defteri iki yerden `unawaited` yazıyor — beş saniyelik toplu tur ve oturum kopuşu — yani yarış yapısal olarak orada da vardı. Fark, orada duran şeyin ne olduğu: hangar bir DURUM, kaybolan satırın yerine bir sonraki yazım geçer; defter bir GEÇMİŞ, kaybolan satırın yerine hiçbir şey geçmez ve bir bakiyenin nereden geldiği bir daha açıklanamaz.

Bugünkü `data/ledger.jsonl` temiz — 1883 satır, sıfır bozuk. Bunun sebebi tasarım değil ölçek: `flush()` bir turun bütün kayıtlarını TEK yazımda topluyor, hangar ise kayıt başına bir yazım yapıyordu, yani defterde çarpışacak yazım sayısı çok daha az. "Bugüne kadar olmadı" bir güvence değil ve para kaydında hiç değil.

Yarışın nasıl kurulduğu, neden bugüne kadar hiçbir testin göremediğini de açıklıyor. `flush()` kuyruğu SENKRON alıyor: gövde ilk `await`e kadar kesintisiz koşuyor, yani `flush()` döndüğünde `_pending` çoktan boşalmış oluyor ve art arda iki `flush()` yarışmıyor — ikincisi boş kuyruk görüp çıkıyor. Yarış ancak birinci yazım UÇUŞTAYKEN kuyruğa yeni kayıt girince kuruluyor; ki `gateway.dart`'ta tam olarak bu oluyor, toplu tur ile kopuş arasındaki her imha kuyruğa kayıt koyuyor.

Ölçüldü, ve hasarın şekli B38'inkinden farklı çıktı. Otuz tur, turda bir fazla kayıt, toplam 465 kayıt: dosyada 30 satır kaldı, **yırtık sayısı sıfır**, 435 para kaydı yok oldu. Üç koşuda da aynı. Yani buradaki hasar tamamen SESSİZ: otuz yazım da aynı sıfır konumunu açıyor ve en uzunu ötekilerin hepsini eksiksiz örtüyor, geriye çözülemeyen tek bir satır bile bırakmadan. Yalnız yırtığa bakan bir denetim bu kaybı hiç görmez — nitekim `defter_yazim_yarisi_test.dart`'ın ilk sınaması, satır SAYISI eklenene kadar kusurlu kodda da yeşil geçiyordu. Sıralama konduktan sonra aynı ölçüm 465/465 veriyor.

Düzeltme `hangars.dart`'takiyle aynı: yazımlar tek bir `Future` zincirinde sıraya giriyor, zincir hatayla kopmuyor. İki fark var. Kuyruğun ALINMASI sıranın içinde: dışarıda kalsaydı iki eşzamanlı çağrı iki ayrı yığın kapardı ve birincisi patlayıp yığınını kuyruğun başına geri koyduğunda, o kayıtlar ikinci yığın çoktan yazıldıktan sonra diske düşerdi — sırası bozuk bir geçmiş. İkincisi, kuyruk boşken `flush()` erken dönmüyor, uçuştaki yazımı döndürüyor: yazacak kaydı olmayan bir çağıranın "defter diskte" sanması, önündeki yazım hâlâ uçuştayken yanlış olurdu.

## B41 · ArGe'nin üçüncü dalı tanımlı ama boş
Durum: kapandı · Kaynak: 05.7 · 2026-09-04 → 2026-09-04

`ArGeDali` üç değer ilan ediyordu — `filo`, `gemi`, `izin` — ama sekiz düğümün hiçbiri `izin` dalına ait değildi. İzinler o dalda değil, öteki iki zincirin SONUNDA duruyor: filo zincirinin dördüncü düğümü bir droid yuvası açıyor, gemi zincirininki ikinci donatım profilini. 05.7 zaten böyle diyor.

Zararsız görünüyordu ve ekran onu gizliyordu: dallar `ArGeDali.values` üstünden değil düğümlerin kendi dallarından çıkıyor, boş dal çizilmiyordu. Ama gizlemek çözüm değil örtmekti — enum'da bekleyen boş bir dal, ileride oraya dosyalanan ilk düğümle ekranda üçüncü bir sütun açar ve "izin dalın sonunda" kuralını sessizce bozardı.

Değer kaldırıldı. Hiçbir düğüm kaybolmadı, ekran değişmedi. Sınama da yön değiştirdi: eskiden "boş dal çizilmesin" sınanıyordu, artık "düğümü olmayan dal İLAN EDİLMESİN" — ağacın şekli koddan okunuyor, arayüzün neyi sakladığından değil.

## B42 · Merdivenden gelen droidlerin hepsi "elit" sayılıyor
Durum: kapandı · Kaynak: 05.4 · 05.8 · 15.7 · 2026-09-04 → 2026-09-04

05.4 s5 şunu diyor: *"standart droidde `droidYuvasi = 1`, elit droidde `elitDroidYuvasi = 2` … Elit olmanın tek anlamı bu."* Ölçüldü: katalogdaki **yirmi droidin on dokuzu iki yuvalıydı.** Tek yuvalı droid `dr1` (Delta, C-I).

Sebep `_turet`: merdivenin üstündeki her eşya şablonunu rafın o yuvadaki en yüksek eşyasından alıyor ve `currency` alanını da onunla devralıyordu. Droid rafında en yüksek olan `dr5` — NOVA rafındaki Hilal. `droidYuvaSayisi` para birimine baktığı için merdivenden gelen her droid elit sayılıyordu ve elit olmanın tek anlamı ilk banttan sonra buharlaşıyordu.

Görülmemesinin sebebi iki kararın kesişiminde durması. 05.8 merdiven droidlerinin GÖRÜNÜŞÜNÜ türetiyor ve `_turet` bunun için zaten şablon kopyalıyordu; `currency` o kopyanın yanında sessizce geliyordu. 15.7 ise `novaRafi`'nı yalnız elle yazılmış raftan kuruyor, yani merdiven droidleri mağazaya sızmıyordu — kusurun tek görünür yüzü kapalı kalmıştı. Kimse bir droidi NOVA ile satın alamıyordu; yalnız hepsi iki yuvalıydı.

Düzeltme tek satır SANILDI ve değildi — üç parça sürdü. Bir: merdiven droidi `Currency.credit` doğuyor. `currency` droidde bir fiyat etiketi değil ÇEŞİT, ve merdiven droidi ganimetten düşüyor — NOVA ile alınmadığına göre elit de değil. Öteki yuvalarda şablonun para birimi taşınmaya devam ediyor; orada `currency` yalnız fiyat ve merdiven eşyası zaten satılmıyor.

**Bütçe yeniden çözülmedi ve gerekmedi.** `ItemBudget.droidDonanimKatsayisi` payı `droidFiloTavani × droidYuvasi` yuvaya, yani ONA bölüyor: bütçe baştan beri TEK yuvalı standart filoya göre çözülmüştü. Kusur bütçeyi değil gerçeği kaydırmıştı — on yuvaya fiyatlanan bir filo yirmi eşya taşıyordu. Düzeltme ikisini yeniden hizalıyor.

Ölçüldü (aynı bantta, tam filo, taban eşya, aynı artı):

| kademe | rank | merdiven ×1 | Hilal B-I ×2 | oran |
|---|---|---|---|---|
| 0 | C-I | 3.724 | 4.465 | 1,199 |
| 1 | C-II | 6.873 | 7.933 | 1,154 |
| 2 | B-II | 17.958 | 19.183 | 1,068 |
| 3 | A-I | 42.665 | 41.922 | 0,983 |
| 5 | S-III | 418.581 | 260.373 | 0,622 |
| 7 | SSS-II | 5.668.019 | 1.622.380 | 0,286 |

Ödeyenin avantajı üç bant sürüyor, dördüncüde işaret dönüyor, sonda merdiven droidi 3,5 kat öne geçiyor. 15.7'nin *"istenir ama gerekmez, fark bir kademe"* ölçüsü droidde de tutuyor: satılan şey erken erişim, kalıcı güç değil. B25'in açık sorusuna da bu yandan bakılabilir — ölçüm `packages/voidspace_core/test/elit_droid_olcumu_test.dart` içinde yaşıyor.

İki ve üç, kapatıldıktan SONRA canlı kayıtta görüldü ve düzeltmenin sessizce atlandığını gösterdi. Yuva sayısı yalnız TAKARKEN sınanıyordu (`Hangar.droideTak`); stat çözümü listeye güvenip hepsini okuyordu. Kapasite hiç değişmediği sürece bu güvenliydi — kayda fazlası zaten giremezdi. Kapasite değişince o güven kırıldı: diskteki her iki eşyalı merdiven droidi ikisini birden vermeye devam etti, yani düzeltme yalnız YENİ takmalara işledi. Kusur bir oyuncunun gerçek kaydında yakalandı (`droid-cIII`, içinde bir lazer ve bir jeneratör).

İki: kapasite artık hesabın da kuralı — `LoadoutResolver.vectorOf` droidin taşıyabildiği kadarını okuyor, liste ne derse desin. Üç: `Hangar.fromJson` yüklerken fazlasını droidden çıkarıyor. Fazlası SİLİNMİYOR, envanterde kalıyor: bir kural değişikliğinin bedelini oyuncunun envanterinden ödetmek olurdu. İkisi birden var çünkü ikisi ayrı şeyi düzeltiyor — biri kaydı, öteki hesabı; göç çalışmasa bile fazla eşya güç vermiyor.

Kural da `Catalogue`'dan `Saglayici.droidYuvaSayisi`'na taşındı, droid taşıyıcı kurallarının (`droidDonanimTipleri`, `kapsamOf`) yanına: iki okuyucusu var ve ayrı katmanlarda, tek kaynak olmalıydı.

Bedeli yazılı: bugün iki yuvalı uçan filolar tek yuvaya iniyor ve ileri banttaki bir oyuncu savaş puanının ~%28'ini kaybediyor. O güç ilan edilen paydan fazlasıydı; kayıp, hiç var olmaması gereken bir kazancın geri alınması.

## B43 · Droid tasarımı stat vermiyor
Durum: açık · Kaynak: 05.8 · 15.9 · 2026-09-04

Bugün tasarım tamamen kozmetik: `LoadoutResolver` tasarımı hiç okumuyor, on tasarımın hepsi aynı statı veriyor ve aralarındaki seçim yalnız göze bakıyor. 05.8 da öyle kurmuştu — "çeşit ile tasarım ayrı eksen", çeşit ekonomiye, tasarım göze.

İstenen: her tasarımın kendi stat eğilimi olsun — biri saldırıya, biri cana ağırlık versin. Böylece tasarım seçimi bir karar olur, ve NOVA rafında satılan tasarımlar (15.9) yalnız görünüş değil bir tercih satar.

Karar bekleyen tek şey statın NEREDEN geleceği. İki yol var ve aralarındaki fark 08'in bütçesi. GÜÇ-NÖTR: tasarım droidin mevcut bütçesinden pay kaydırır — biri saldırıya, öteki cana — toplam güç değişmez, yeri değişir; ArGe ağacının mantığının aynısı (05.7) ve 08 hiç açılmaz. EK GÜÇ: tasarım droidin üstüne yeni stat ekler, ArGe için aynı sebeple reddedilen hesabı açar (B32) — tasarım yedinci bir grup olur ve altı grubun payı elle düşürülür.

Güç-nötr olan seçilirse iş küçük ve 08'e dokunmuyor; ek güç seçilirse bütün eşya ekonomisi yeniden ölçülür. Bu borç, o seçimi bekliyor.
