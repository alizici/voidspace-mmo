---
alan: 10
ad: İlerleme ve Unvan
katman: büyüme
tur: kural
surum: 1.4
tablo: 10-merdiven-olcegi.md
kaynak: https://claude.ai/code/artifact/13ae8493-8f4e-43e6-8d04-9621c2947fe3
---

# 10 · İlerleme ve Unvan

İki ayrı ilerleme, yirmi rank kademesi, ve iki yılın nasıl bölüştüğü. Hedef tek cümle: **normal bir oyuncu son unvana iki yılda ulaşsın.** Bu belgedeki her sayı o cümleden türedi: rank sayısı, gövde kademesi, kredi gelirinin eğrisi.

Bağımlılık: [06](06-esya-kurgusu.md) rank çarpanı · [07](07-guclendirme.md) artı · [08](08-guc-butcesi.md) bütçe · [09](09-savas-puani.md) BR. Bu belgeye bağlı: 11 · 12 · 13 · 16. Sayı tablosu: [10 · Merdiven Ölçeği](10-merdiven-olcegi.md).

Sürüm 1.4: unvanın görsel kimliği kodda (10.4 s2): yirmi amblem, kademe halkası, çağla katmanlanan aparat, adın tipografisi ve pilot kartı. Yeni girdi yok — hepsi var olan üç sayıdan (ad, kademe, çağ) türüyor. Sürüm 1.3: seviye, unvan adları ve açılış sırası kodda (10.1, 10.4, 10.7): XP öldürme kredisi, seviye onun karşıladığı rank; yirmi unvan adı; sistemler sahip olunan en yüksek eşya rankıyla açılıyor. Sürüm 1.2: referans build tek fonksiyon (10.6): rank → kademe, kademe → gövde ve referans rank, artı +15 ilan; savaş puanına artının girmesi referansın tam donanım kararına bağlı. Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. Unvan eşikleri ile isimleri ayrıldı: eşikler kodda, isimler yalnız belgede. Seviye sistemi ve açılış sırası kodda yok.

## 10.1 · Seviye ↔ BR ayrımı
Durum: kodda · s1 · Seviye.of, Hangar.xp; XP yorgunluk sonrası öldürme kredisi

**Seviye** içeriğe kapı: XP ile artar, asla geri gitmez, haritaların giriş şartı; ekipmanını çıkarsan da seviyeni kaybetmezsin. **Savaş puanı** güç ölçüsü: ekipmandan gelir, düşebilir, unvanı belirler. İkisi farklı sorulara cevap veriyor, "nereye girebilirim" ve "ne kadar güçlüyüm"; tek bir sayı ikisini taşıyamaz çünkü biri geri gitmemeli, diğeri gitmeli. Unvan BR'ye bağlı: bir başarı göstergesi, zaman göstergesi değil; iyi oynamakla yükselir ve düşebilir, unvan taşımak o gücü korumak demek. Kodda XP ayrı bir kaynak değil: öldürmeden kazanılan ömür boyu kredi, yorgunluk uygulandıktan sonra; ayrı bir XP tablosu 13'ün musluğunu ikinci kez tanımlamak olurdu ve tepe tabloya girdi eklenmedi. Seviye XP'nin karşıladığı rank: ilk L neslin bütçesi kadar kazanç L. seviye. Referans oyuncu bir bandı bitirdiğinde tam o rankın seviyesine varıyor; sayaç düşmüyor. Harita kapısında BR birincil, seviye ikincil (11.4); sunucu seviyeyi hangar durumuyla gönderiyor.

## 10.2 · Rank merdiveni ve renk kapakları
Durum: kodda · s1 · ItemTier

`rankSayisi = 20`: altı harf ailesi × üç kademe, C-I'den SSS-III'e on sekiz adım, üstünde iki tekil kademe: Kırmızı ve Parlayan Pembe. Renkler tekil çünkü üçer kademeli aile yapılsalardı "altı rank daha" olurlar ve özel olmaktan çıkarlardı; tekil olduklarında oyunun en nadir iki şeyi oluyorlar. Aynı ×1,442 oranını izliyorlar, bütçe matematiği değişmiyor; değişen tek şey onlara ulaşmanın bir aile bitirmek değil tek bir eşiği geçmek olması. Rank eşyanın rengidir (06.1).

## 10.3 · Unvan eşikleri: yüz yirmi basamak, eşit oranlı
Durum: kodda · s1 · CombatGlossary.unvanEsigi, CombatGlossary.brTavani

`unvanSayisi = 120` basamak; ilk basamak `ilkUnvanEsigi = 3.600`, referans build'in kanal gücü oraya oturtulur (09.7); son basamak sistemin üretebildiği en büyük BR. Basamaklar eşit oranlı, eşit aralıklı değil: her unvan bir öncekinin sabit bir katı. Tavan birebir oturuyor: son unvanın eşiği sistemin tavanına eşit, yani merdivende ne ulaşılamaz basamak var ne de boş üst uç. Eski merdivenin tavanı başka bir oyundan gelmişti ve 120 basamağın yalnız ilk 13'ü doldurulabiliyordu.

## 10.4 · Unvan isimleri, çağlar ve görsel kimlik
Durum: kodda · s2 · Unvan.adi, Unvan.adIndeksi, Unvan.kademe, Unvan.cagIndeksi; UnvanAmblemi, UnvanIkonu, UnvanYazisi, UnvanKarti, UnvanSatiri

Dört çağ, her çağda beş kademeli unvanlar: Asalet (Squire … Duke), Kutsallık (… Deity), Yıldız (Starcaller … Vortex), Ölümsüzlük (… Star Marshal, Star Lord). İsimler ve çağ yapısı eski merdivenden korunuyor; değişen tek şey eşik sayıları (10.3). Yirmi ad kodda; yüz yirmi basamak ada altışar kademe veriyor, I'den VI'ya. Uçlar bu belgeden, aradaki on iki ad ilk yerleşim (borç defteri B11); değiştirmek bedava, hiçbir kayıt ada bağlı değil, indekse bağlı. Sunucu unvanı ve adını hangar durumuyla gönderiyor; istemci yalnız gösterir.

Basamak üç sayıya ayrışıyor ve görsel sistem bu üçünü okuyor: AD (0–19) merkez glifi, KADEME (0–5) dış halkanın kaç diliminin yandığını, ÇAĞ (0–3) aparatın kaç katmanı olduğunu seçiyor. Aparat çağla katmanlanıyor — Asalet'te tek halka, Kutsallık'ta veri halkası, Yıldız'da ölçüm bezeli ve segment yayları, Ölümsüzlük'te mesnetler, ışınlar ve atımlar. Rütbe başına ayrı düzenek yirmi farklı aparat demekti ve aradaki fark okunmazdı; çağ başına katman dört net kademe veriyor.

Renk merdiveni AYRI DEĞİL: yirmi unvan ve yirmi eşya rankı (06.1) aynı merdivenin basamakları, unvanın rengi o basamağın eşya rengi. İki ayrı palet oyuncuya iki renk dili öğretmek olurdu.

Adın kendisi de tasarımın parçası: harf ağırlığı çağla artıyor, harf aralığı daralıyor, Yıldız'dan itibaren adın arkasında kendi renginde bir hale, Ölümsüzlük'te ad gradyanla doluyor. Yirmi rank için yirmi yazı tipi değil, tek ailenin ağırlık ve aralık ekseni; ikinci bir aile menünün geri kalanıyla çatışırdı. Yazının içeriği SUNUCUNUN dizesi, indeks yalnız stili seçiyor: istemci adı indeksten kurmuyor, kurduğu gün kapı ile başlık ayrı adlar söylerdi. Kademe ayrıca yazılmıyor, onu amblemin dış halkası sayıyor.

Üç yerde görünüyor. Unvan SATIRI (hangar başlığı ve HUD): amblem, ad ve yanında seviye ile savaş puanı; ölçüler adın stiline girmiyor, çünkü onlar rütbe değil sayı. PİLOT KARTI (satıra dokununca): büyük amblem, çağ, kademe, sıradaki unvan ve eşiği, ve yirmi adın merdiveni dört çağ satırında. MERDİVEN şeridi bütünü gösteriyor — tek amblem "ilerliyorum" der, şerit "ne kadar kaldı" der.

Hareket iki kademeli: küçük ikon durgun (satır her karede yeniden boyanıyor, 06'nın envanter ızgarası için verdiği kararla aynı gerekçe), kart içindeki büyük amblem tek örnek ve dönüyor. Durgun kare bir "donmuş animasyon" değil, o iş için seçilmiş bir kare.

## 10.5 · Gelir ölçekleme üssü α
Durum: kodda · s2 · TasarimGirdileri.gelirUssu, TuretilenTablolar.gelirFor, TuretilenTablolar.sureOlcegiFor

İki yıl hedefini çözerken çıkan en önemli bulgu: sabit gelirle eşya maliyeti rankla büyüdüğünde iki yıllık kredi yalnız sekiz nesle yetiyor. Yirmi nesil için gelirin de büyümesi gerekiyor, ama maliyetten yavaş. Gelir = taban × rank çarpanı^α, maliyet = taban × rank çarpanı; α < 1 olduğu için her nesil bir öncekinden uzun sürer. α ilerlemenin temposunu belirleyen tek sayı: 1'e yaklaştıkça her nesil aynı süreyi alır, 0'a yaklaştıkça son nesiller imkânsızlaşır.

`gelirUssu = 0,816` bir GİRDİ, türetilen değil: tepe tabloda öyle duruyor ve onu çözen bir yordam yok. `hedefSure = 780` saati (1,5 saat/gün × 5 gün × 104 hafta) tutturan da α değil, süre ölçeği: `TuretilenTablolar.sureOlcegiFor` bağıl süreleri toplamları hedefe eşitlenecek biçimde bölüyor, yani toplam herhangi bir α'da tam 780 çıkıyor. α'nın işi toplamı tutturmak değil, o toplamın nesillere NASIL bölüneceğini söylemek: nesillerin birbirine göre uzunluğu ondan geliyor. Hedef süre değişirse yeniden çözülen şey ölçek, α yerinde kalır; α'yı değiştiren tek şey "nesiller ne kadar farklı uzunlukta olsun" sorusunun cevabı. Her harita kademesinin kredi ödülü, o kademenin rank çarpanının α üssüyle ölçeklenir; uygulaması alan 13'ün.

## 10.6 · Referans build fonksiyonu
Durum: kodda · s2 · ReferansBuild.of, ReferansBuild.kademeOf, ReferansBuild.arti, ReferansCozumu.arti

Alan 04 referans build'i bir bileşim olarak tanımlamıştı; hangi kademede hangi ranka sahip olunduğunu bu belge söylüyor: referansBuild(kademe) = { gövde: govdeFor(kademe), rank: adım[kademe], artı: beklenen seviye }. Artı +15 değil, ilk bandın nesil bütçesinin ulaştırdığı seviye (13.6; bugün `referansArti = 11`). Uzun süre +15 ilan edildi: "normal oyuncu bir sonraki ranka geçmeden eşyasını tamamlar" varsayımıyla. 13.6 ölçtü, tamamlamıyor; +15'e çapalanmış bir referans gövde çapasını, yaratık canını ve kapıları gerçek oyuncunun üstüne ayarlardı (borç defteri B1). Gerçek oyuncular yine referansın altında kalabilir; alan 16 bunu "göreli yatırım" olarak ölçer.

Kodda tek fonksiyon: rank → kademe bölmenin tek tanımı, kademe → gövde ve referans rank (bandın ilk rankı; bölge kapısı da onu ölçüyor, 11.3), artı +15 ilan. Ganimet, kazanç, yükseltme, bölge ve tablolar bölmeyi buradan okuyor; eskiden rank → kademe kaynak akışında, rank → BR savaş sözlüğünde ayrı yaşıyordu. Savaş puanı merdiveni bugün +0 çıplak referansı ölçüyor (09.7): artı ve tam donanım referansa girmiyor, ikisi birlikte, referansın eşya havuzunu açan kararla gelecek (borç defteri B1). Gövdenin rank etiketi aile başından geliyor ve üst kademelerde banttan ayrışıyor (B10).

## 10.7 · Sistem açılış sırası
Durum: kodda · s1 · Acilis.acik, HangarError.kilitli; droid kapısı filoya alma (04.10), ArGe için eşik ilan, sistem yok

Her sistem birinci dakikada açık olsaydı yeni oyuncu on iki farklı ekranla karşılaşır ve hiçbirini anlamazdı. Açılış sırası bir öğretim eğrisi: lazer ve jeneratör yuvaları başlangıçta; artı basma ilk rank sonunda; alt stat çevirme ikinci rankta; droid üçüncü rankta; sentez fazla eşya birikince; ArGe orta oyunda. Eşik ranka bağlı, seviyeye değil: sistemler oyuncunun eşya durumuna göre açılıyor, oynadığı süreye göre değil; hızlı oynayan erken, yavaş oynayan geç açıyor, ikisi de doğru anda.

Kodda ölçü sahip olunan en yüksek eşya rankı: artı basma ikinci rankın eşyası görülünce, çevirme üçüncüde, droid dördüncüde, sentez aynı ranktan üç eşya birikince, ArGe merdivenin ortasında. Kapalı sistem hangarda "henüz açık değil" diyor. Droidin kapısı filoya alma: droid eşyası daha erken düşebilir ve depoda durur, filoya ancak eşikten sonra girer (04.10). ArGe için eşik ilan, sistem yok. Mağaza bu sırayı atlatamıyor: raf bandın bir altını satıyor (15.2), raftan alınan eşya sahip olunan en yüksek rankı bandın üstüne çıkaramaz.

## 10.8 · Günlük tavan ve yorgunluk
Durum: kodda · s1 · Fatigue

İki yıllık hedef günde 1,5 saat varsayımına dayanıyor. Günde on saat oynayan biri hedefi altı ayda bitirirse ilan edilen tempo anlamsızlaşır. Yorgunluk bunu yumuşatıyor: belirli bir günlük kazanımdan sonra kredi ve XP kazancı azalıyor. Sert bir duvar değil, azalan verim; sert duvar oyuncuyu oyundan atıyor, azalan verim yalnız yavaşlatıyor. Yorgunluk bir ekonomi aracı gibi görünür ama tempo aracı: "iki yıl" sözünün korunmasını sağlıyor, bu yüzden alan 13'ün değil bu belgenin kararı. Kodda yumuşak tavan ve yarı ömür rankla ölçekleniyor, taban verim sıfıra inmiyor.

## Sınır

Sahiplenmediği: BR formülü → 09 · rank çarpanı → 06 · artı merdiveni → 07 · gelirin uygulanması → 13 · harita kademeleri → 11 · unvanın stat vermemesi → 05.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Son unvana ulaşma süresi = ilan edilen hedef (±%10) | Tempo kaymış; bütün ölçek yeniden çözülmeli. |
| Unvan merdiveni tavanı = sistemin BR tavanı | Ulaşılamaz basamak ya da boş üst uç. |
| Her nesil bir öncekinden uzun | α ≥ 1 olmuş; ilerleme hızlanıyor. |
| Seviye asla düşmüyor | İçerik kapısı geri alınabilir olmuş. |
| BR düşebiliyor | BR bir zaman göstergesine dönüşmüş. |
| Unvan eşikleri kesin artan | Merdivende düz ya da geri basamak var. |
| Açılış eşikleri ranka bağlı, süreye değil | Yavaş oynayan sistemleri erken görüyor. |
| Harita geliri kademeyle ölçekleniyor | 13 uygulamamış; sistem sekizinci nesilde duruyor. |
