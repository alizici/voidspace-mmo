---
alan: 7
ad: Güçlendirme
katman: büyüme
tur: kural
surum: 1.4
tablo: 07-guclendirme-tablosu.md
kaynak: https://claude.ai/code/artifact/10b70bc2-b4fb-4902-994a-f95e89e5040c
---

# 07 · Güçlendirme

Eşya eline geçtikten sonra nasıl büyür: artı basma, sentez, çevirme, ve hiçbirinde kırılma olmaması. Bu alanın tamamı tek bir söze dayanıyor: **garantili başarı, katlanan maliyet.** Belirsizlik alt stat sisteminde zaten var; orada eğlenceli, burada değil.

Bağımlılık: [06 Eşya Kurgusu](06-esya-kurgusu.md) şema · 08 bütçe. Bu belgeye bağlı: 13 · 14 · 15. Sayı tablosu: [07 · Güçlendirme Tablosu](07-guclendirme-tablosu.md).

Sürüm 1.4: artı basmada güçlenen alt stat rastgele, miktar sabit (07.6) kodda; çevrilmiş eşyanın alt statları artı basmada büyümeye devam ediyor, eskiden donuyordu. Sürüm 1.3: çevirme yeniden tanımlandı (07.5): bir çevirme kilitli olmayan bütün alt statları çeviriyor, oyuncu iyi çıkanı kilitliyor, kilit bedeli artırıyor; bedel stat başına × stat sayısı (07.8). Sürüm 1.2: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. 1.1'in çevirme kuralı (kredi almaz, katlanmaz) korundu; tablonun 1.0'daki "1,5 üssü" çevirme maliyeti buna uymuyordu, üretilen tablo artık kodu gösteriyor. Tek rastgele kuralı iki karara ayrıldı, çünkü yarısı kodda değil.

## 07.1 · Üç modül: artı basma, sentez, çevirme
Durum: kodda · s1 · Hangar.upgrade, Hangar.sentezle, Hangar.cevir

| Modül | Ne yapar | Ne tüketir |
|---|---|---|
| Artı basma (强化) | Eşyayı +0'dan +15'e çıkarır; ana stat ve alt statlar birlikte büyür | Kredi ve o rankın malzemesi |
| Sentez (合成) | Aynı ranktan birkaç eşyayı bir üst rank tek eşyaya çevirir; kayıplı | Eşyanın kendisi: üç parça gider, biri gelir |
| Alt stat çevirme (洗练) | Seçtiğin bir alt statı yeniden çevirir; kötü rollü eşyayı çöp olmaktan kurtarır | Yalnız çevirici, o rankın kendi kaynağı; kredi almıyor |

Üçü farklı sorunları çözüyor: artı basma yavaş ve garantili büyüme, sentez fazla eşyayı değere çevirme, çevirme kötü şansı kurtarma. Tükettikleri de farklı ve bu ayrım kasıtlı. Çevirmenin krediden ayrılması bir tercih değil, alan 13'ün sonucu: oranın gider kalemlerinde (artı basma · sentez · mağaza · birikim · onarım) çevirme yok. Ekonomi bu gideri hiç bütçelememişti; kredi almak, modelin görmediği bir musluk açmaktı.

## 07.2 · Başarısızlık ve kırılma yasağı
Durum: kodda · s1 · Yukseltme.basarisizlikSansi, Yukseltme.esyaYokEdilebilir

Bu türdeki oyunların çoğu belirli seviyelerin üstünde yükseltme başarısızlığı ve hatta eşya kırılması koyar. Konmayacak, ve iki sebebi var.

**Sözü bozar.** Başarısızlık tavanı doğrudan paraya çevirir: koruma tılsımı satılır. "Tavanlı orta P2W" sözünü delen en kısa yol budur, ve delindiği an geri alınamaz, çünkü koruma satın almış oyuncular vardır.

**Geri dönüşü yok.** Mağaza yorumlarını kalıcı olarak bozan tek mekanik bu. Bir oyuncu on saatlik emeğini kırılan bir eşyada kaybettiğinde, yazdığı yorum oyunun ömrü boyunca orada kalır.

Doğrusu: garantili başarı, katlanarak artan maliyet. Aynı para sinki, sıfır öfke. `basarisizlikSansi = 0` bir girdi değil, kilit: sıfırdan farklı bir değer değişmez testini kırıyor, yani başarısızlık ancak bilinçli bir kararla ve testi de silerek gelebilir. Kural sentez ve çevirme için de geçerli: sentez her zaman başarılı (kayıp oranda, sonuçta değil), çevirme her zaman bir sonuç verir (kötü olabilir, ama eşyayı yok etmez).

## 07.3 · Artı merdiveni ve kazanç biçimi
Durum: kodda · s1 · ItemLevels.multiplier, TasarimGirdileri.artiKazancBicimi

On beş seviye, üç kademe: kalibrasyon (1–5) seviye başına +%8, yeniden yapım (6–10) +%10, aşırı yükleme (11–15) +%12. Artışlar **toplanıyor, çarpılmıyor**; +15'te 2,50×.

Alan 06 bir çelişki devretmişti: belge kazancı toplamsal ilan ediyor, kod bileşik hesaplıyordu (4,170×) ve ikincisi 06'nın ilan ettiği güç tavanını deliyordu. Üç seçenek ölçüldü. Toplamsal kazanç ile eski maliyet tabanı son seviyeyi ilkinden 44,5 kat kötü değer yapıyordu, yani +11'den sonrası ölü sistem. Bileşik kazanç bunu 12 kata indiriyor ama tavanı 10,75×'ten 17,93×'e çıkarıyordu. Üçüncü yol maliyet eğrisinin iki kolunu ayırınca çıktı (07.4): toplamsal kazanç, yeniden çözülmüş şekil, korunmuş hacim. Kazanç biçimi tepe tabloda duruyor, kodda değil.

## 07.4 · Maliyetin şekil ↔ hacim ayrımı
Durum: kodda · s1 · ItemLevels.upgradeCost, ItemLevels.degerBozulmasi

Maliyet eğrisi c₀ × b^L iki farklı işi birden yapıyor. **Hacim:** toplamda kaç kredi yakılacağı, ekonominin ana gideri. **Şekil:** son seviyelerin ilk seviyelere göre ne kadar kötü değer olduğu. Tek kolla (b) ayarlandığında biri tutturulunca diğeri kayıyordu. Ayrılınca ikisi bağımsız hedefleniyor: `maliyetHacmi = 2.489` hacmi, `maliyetSekli = 1,2293` şekli belirler.

Alanın tek sayılık sağlık ölçüsü değer bozulması: son yükseltmenin kredi/güç oranı ÷ ilk yükseltmeninki. Çok düşükse eşya yükseltmek hiç bitmez ve enflasyon yakalanamaz; çok yüksekse üst seviyeler kimsenin dokunmadığı ölü içerik olur. Bant 8–16 kat. Şekli değiştirebilirsin, ama hacmi bilerek değiştirmen gerekiyor; toplam sink değişince alan 13'ün musluk/gider dengesi sessizce bozulur.

## 07.5 · Çevirme hepsini çevirir, kilit korur
Durum: kodda · s2 · Hangar.cevir, Hangar.kilitle, ItemInstance.kilitler, ItemInstance.altStatRolleri

Bir çevirme, eşyanın kilitli olmayan **bütün** alt statlarını birden yeniden çevirir. Oyuncu iyi çıkan statı kilitler; bir sonraki çevirme yalnız kalanları çevirir. Kilit eşyada kalıcı, koymak da açmak da bedava; bedeli çevirme anında kilit sayısı belirler (07.8). Yeni değerler rankın bandından rastgele, eskisinden kötü de olabilir; eşya hiçbir durumda kaybolmaz. Hepsi kilitliyse çevirme yok ve bedel yok. Saklanan şey değer değil kalite rolü (bandın içinde 0–1): değer her okunuşta rank, gövde katsayısı ve artı adımından türer, gövde değişince kendiliğinden düzelir, artı basma taşımak zorunda kalmaz. Eski kayıtlardaki mutlak değerler yüklemede o anki gövdeyle role çevriliyor.

Tek rastgele kuralı burada da geçerli: hangi statların değişeceği rastgele değil (açık olanların hepsi), ne kadar değişeceği rastgele. Oyuncunun elindeki bilinen kilit: "keşke şuna gelseydi" dedirtir, "hem yanlış stata geldi hem az geldi" dedirtmez. Garantili alt statlar (06.10) da çevrilir; korumak isteyen kilitler.

Belgenin ilk sürümü tek statı çeviriyordu: hedef sabit, sonuç rastgele. Kilit aynı seçimi daha zengin veriyor: oyuncu neyi koruyacağını seçiyor, gerisini şansa bırakıyor, ve korumanın bedelini ödüyor.

Çevirme neden var: kütüphane düzeyinde hiçbir stat ölü olmasa bile, senin build'ine yaramayan bir roll gelebilir. Çevirme, o eşyayı çöpe atmak yerine kurtarmanın yolu ve envanter enflasyonunu da azaltıyor.

## 07.6 · Artı basmada güçlenen alt stat rastgele, miktar sabit
Durum: kodda · s1 · ItemBudget.guclenenIndeks, ItemBudget.altStatTabani; çevrilmiş stat rol × taban, taşıma yok

Tek rastgele kuralının öteki yönü. Artı basmada +3 · +6 · +9 · +12 · +15'te bir alt stat güçlenir: **hangisi** rastgele, **ne kadar** sabit. Oyuncu seçmiyor zaten; sürpriz güçlenmede olsun, miktarda değil. İkisinde de oyuncunun elinde bir bilinen var: artı basmada miktar, çevirmede hedef. "Keşke şuna gelseydi" dedirtiyor, "hem yanlış stata geldi hem az geldi" dedirtmiyor.

Kodda: adımın hangi stata düştüğü örneğin kimliğinden ve adım numarasından türüyor, saklanmıyor; aynı eşya her yüklemede aynı statı büyütmüş görünüyor ve kart bunu rozetle gösteriyor. Miktar sabit ve ilan: her adım alt stat bütçesinin beşte birini tek stata veriyor, beş adım tam bir pay. Toplam, adımı bütün statlara yayan eski kuralla aynı; havuz genişledikçe tek statın sıçraması büyüyor, C ailesinde tek stat olduğu için iki kural özdeş. Sayılar [tabloda](07-guclendirme-tablosu.md).

Çevirme adımlara dokunmuyor: yalnız kalite rolünü yeniliyor, güçlenme kimliğin kendisinden. Çevrilmiş eşya da artı basmada büyüyor: saklanan değer seviyeyle donuyordu, artı basma onu artık aynı oranla taşıyor, kalite rolü korunuyor.

## 07.7 · Sentez oranı ve kaybı
Durum: kodda · s1 · Yukseltme.sentezOrani, Yukseltme.sentezVerimi, Yukseltme.sentezUfku

`sentezOrani = 3`: aynı ranktan üç eşya, bir üst rank bir eşya. Verim rank çarpanı ÷ harcanan eşya, yani bütçenin yarısı kayboluyor: fazla eşyaya değer, ama kestirme değil. İki-bir'de kayıp az ve sentez tercih edilen yükseltme yolu olur, drop değersizleşir; dört-bir ve üstü çoğu oyuncu için erişilemez.

Üç seçilmesinin ikinci sebebi yerellik: bir kademe yukarı 3 eşya, iki kademe 9, üç kademe 27; dördüncüde 81'e çıkıp pratik ufkun dışına düşüyor. Yirmi kademelik merdivenin dibinden tavanına sentezle çıkmak 3¹⁹ eşya demek, yani sentez hiçbir zaman drop'un yerine geçemiyor. Sentez ganimet döngüsünün ikinci ayağı: parçalama krediye çevirir, sentez ranka çevirir. Kötü rollü ama yüksek rank eşya parçalanır; iyi rollü düşük rank eşya sentezlenir.

## 07.8 · Çevirme kaynağı ve nadirliği
Durum: kodda · s2 · Yukseltme.statBasinaCevirici, Yukseltme.cevirmeBedeli

Çevirme kredi almıyor ve maliyeti art arda katlanmıyor. Katlanan maliyet bir "kabul et" kaçışı gerektiriyordu ve o kaçış ücretsiz olduğu an katlanma anlamını yitiriyordu. Yerine geçen şey nadirlik: tek kaynak eşya parçalamak, parçalanan her eşya bir çevirici veriyor.

Bedel üç çarpan: **stat başına** çevirici harf ailesinden, C 1 · B 2 · A 3 · S 4 · SS 5 · SSS ve üstü 6; **stat sayısı**, çünkü çevirme hepsini çeviriyor (07.5); ve **kilit**, doğrusal: bedel × (1 + kilit sayısı). Pembe'de yedi stat: kilitsiz 42 çevirici, altı kilitle tek statı kovalamak 294. İyi rolü koruyup kalanı kovalamak her kilitle bir taban daha pahalı; eski tek stat çevirmesinin yerine geçen şey bu ve bilerek pahalı.

Mükemmel roll `cevirmeKaliteHedefi = 0,01` dilimi, stat başına ortalama yüz deneme. Açgözlü kilitle (hedefe varan stat kilitlenir) bir yuvayı mükemmele çıkarmanın beklenen bedeli tabloda; Pembe'de on binlerce çevirici, bir neslin parçalama arzı yüzlerce. Oyuncunun kararı bu yüzden "hangisini kovalıyorum" oluyor, "hepsini ne zaman bitiririm" değil. Çevirici hiçbir rankta satılmıyor: nadirliği tasarımın kendisi, mağazaya koymak onu paraya açardı.

## 07.9 · Malzemenin rank kapısı rolü
Durum: kodda · s1 · Yukseltme.malzemeMaliyeti, Catalogue.malzemeRafi

Güçlendirme üç şey tüketiyor ve üçünün işi farklı. **Kredi** evrensel yakıt: ne kadar hızlı ilerlediğini belirliyor. **Malzeme** rank kapısı: hangi rankı yükseltebildiğini belirliyor. **Çevirici** çevirmenin kaynağı, rank başına ayrı: mükemmel rollün ne kadar nadir olduğunu belirliyor. Malzeme ile çeviricinin ayrı olması şart; aynı kaynağı harcasalardı oyuncu her çevirmede bir yükseltmeden vazgeçmiş olurdu.

Bir S rank eşyayı yükseltmek S rank malzeme istiyor, ve o malzeme yalnız zor içerikten düşüyor. Miktar krediyle orantılı olduğu için malzeme ikinci bir para birimi olmuyor; kapıyı yapan şey rank kilidi. Kredi biriktiren oyuncu üst rank eşyasını yine de yükseltemiyor, çünkü eksik olan para değil malzeme.

Mağazanın buradaki yeri: ganimet belgesi mağazanın drop'un verdiğini satamayacağını söylüyordu. Malzeme bu kuralı çiğnemiyor: mağaza düşük rank malzeme satabilir, çünkü onlar zaten bol ve satılması yalnız zaman kısaltıyor. Sınır ilan edilmiyor, rafın kendi en yüksek rankından türüyor. Üst rank malzeme mağazada olmuyor; o, zor içeriğin kendi ödülü ve üst rank eşyanın gerçek kapısı.

## 07.10 · Soket ayrılmış
Durum: ayrılmış · s1 · şema yok

Taş takma ve sökme (镶嵌). Şeması ayrıldı, bu sürümde yok. Ayırmanın sebebi diğer ayrılmış sistemlerle aynı: geldiğinde şema değişmesin, ve o güne kadar boşluk görünür kalsın.

## Sınır

Sahiplenmediği: eşyanın şeması ve havuzları → 06 · bir statın kaç ettiği → 03 · malzemenin nereden düştüğü → 14 · malzeme ve kredi fiyatları → 13 · yuvaya düşen bütçe → 08 · NOVA ile kestirme → 15.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Hiçbir işlemin başarısızlık olasılığı yok | Kırılma ya da başarısızlık sızmış; koruma satma kapısı açılmış. |
| Hiçbir işlem eşyayı yok etmiyor | Sentez ya da çevirme eşya siliyor. |
| Her işlemde en fazla bir şey rastgele | Çift rastgelelik geri gelmiş; hayal kırıklığı çarpılıyor. |
| Güçlenme adımı tek stata, sabit miktarda, beş adım bir pay | Miktar rastgeleleşmiş, adım yayılmış ya da toplam kaymış. |
| Kilitli stat çevirmede değişmiyor | Kilit boş vaat; oyuncu koruduğunu kaybediyor. |
| Bedel kilit sayısıyla doğrusal, katlanmıyor | Kilit ya bedava (kovalamak ucuz) ya cezaya dönmüş. |
| Çevirme kredi almıyor | Alan 13'ün görmediği bir musluk açılmış. |
| Çevirme maliyeti katlanmıyor | Katlanma geri gelmiş, onunla birlikte onu iptal eden ücretsiz kaçış. |
| Çevirici hiçbir rankta mağazada yok | Mükemmel rollün nadirliği paraya açılmış. |
| Sentez verimi < 1 | Sentez bedava yükseltme yoluna dönmüş; drop'un anlamı kalmamış. |
| Sentez ufku ≤ 3 kademe | Sentez drop'un yerine geçmiş. |
| +15 kazancı ilan edilen tavan (2,50×) | Kazanç biçimi sessizce değişmiş; güç tavanı kaymış. |
| Her seviyede kazanç artışı ≥ öncekinin | Merdiven ters dönmüş. |
| Değer bozulması 8–16 kat bandında | Son seviyeler ölü sisteme dönmüş ya da fazla ucuzlamış. |
| Toplam sink değişmedi (±%5) | Eğri ayarı ekonominin hacmini kaydırmış; 13 ile ayrışma. |
| Üst rank malzeme mağazada satılmıyor | Rank kapısı paraya açılmış; malzeme ikinci para birimine dönüşmüş. |
