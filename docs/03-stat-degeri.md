---
alan: 3
ad: Stat Değeri
katman: savaş
tur: kural
surum: 1.4
tablo: 03-deger-tablosu.md
kaynak: https://claude.ai/code/artifact/68757984-4ca6-4c61-a62e-1e10808eca47
---

# 03 · Stat Değeri

Bir statın kaç ettiğini kim, hangi yöntemle ve hangi birimde söyler. Buranın üstü kural, altı fiyat. 08, 09 ve 12 bu belgenin kuruyla konuşuyor; sahipsiz kaldığı için iki hata doğmuştu, bu belge o sahipliği kuruyor.

Bağımlılık: 01 zincir · 02 kayıt ve birim tipi. Bu belgeye bağlı: 08 · 09 · 12 · 16. Sayı tablosu: [03 · Değer Tablosu](03-deger-tablosu.md).

Sürüm 1.4: fiyatın ölçüldüğü nokta çıplak gövdeden DOLU referansa taşındı ve doğan sabit nokta yinelemeyle çözüldü (03.2); borç defteri B22 kapandı. Sürüm 1.3: birim sözleşmesi kodda (03.6): fiyat türevinin adımı ve çözümleyicinin uygulaması kaydın birimini okuyor. Sürüm 1.2: iki açık karar kapandı. Fiyatların tamamı zincirden türüyor (03.1), alan 03'ün tepe tabloya girdisi kalmadı; değerleme süresi kur süresi (03.5). 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı.

## 03.1 · Değer marjinal katkıdır, zincirden türer
Durum: kodda · s2 · ItemBudget.fiyatlar

Bir statın değeri, o statın bir birim artmasının çıktıya kattığı miktar. Uydurulmuyor, alan 01'in formülünün kısmi türevinden türetiliyor: hasar artışının değeri taban × kritik beklentisi ÷ aralık. Türev duruma bağlı, taban hasar büyüdükçe yüzdesel artışın değeri de büyür; bu yüzden değer tek bir referans noktada ölçülür (03.2).

Kod türevi sayısal alıyor ve zincirin kendisinden: analitik bir kopya, zincir değiştiğinde sessizce eskirdi. Saldırı statlarında ∂DPS, savunma statlarında ∂EHP; sistem statlarında (menzil, hız) zincirin türevi sıfır olduğu için değer BR'nin sistem çarpanından geliyor: bir sistem puanı iki A ÷ 100 DPS eder (09.5). Son azaltmanın değeri gelen vuruşun büyüklüğüne bağlı; vuruş referans build'in kendi tek atışı (PvP simetrisi), böylece savaş katmanı dünya katmanını okumadan fiyatlıyor.

Uzun süre saldırı fiyatları tepe tabloda elle girdiydi ve zincirin söylediğinden 2,5–3,3 kat ucuzdu; yüzdesel alt statlar hep zayıf geliyordu. Karar: türetilen kazandı, alan 03'ün tepe tabloya girdisi kalmadı. Hasar artışı ile atış hızının eşit çıkması kanarya: bozulursa sorun bu tabloda değil alan 01'de.

## 03.2 · Referans noktada ölçme kuralı
Durum: kodda · s2 · Turetilenler.saldiriPuaniDps, FiyatCozumu, ItemBudget.fiyatlariTuret

Değerler her build için ayrı hesaplansaydı bütçe kurulamazdı: aynı eşya farklı oyuncularda farklı fiyata gelirdi. Tek referans noktası fiyatın eşyanın özelliği olmasını sağlıyor, oyuncunun değil. Bedeli: referanstan çok uzaklaşan build'lerde fiyat gerçek değeri tam yansıtmaz. Kabul edilebilir, çünkü referansın kendisi "o seviyenin normal oyuncusu" olarak tanımlanıyor (alan 04).

**Ölçüm noktası DOLU referans** — oyuncunun referansının ta kendisi (04.5), çıplak gövde değil. Uzun süre iki ayrı noktaydı: fiyatlar çıplak gövde ile referans silahından (`ShipStats.bastion`) ölçülüyor, havuz ve puan çapaları dolu build'den çözülüyordu. Sonucu yüzdesel statlarda görülüyordu: dolu referansta bir yüzde puanı iki kattan çok DPS ediyor, yani yüzde statlar gerçek oyuncuda fiyatlarından değerliydi ve 08'in Shapley ölçümü bunu payların sapması olarak gösteriyordu (borç defteri B22). Bir stat yalnız kullanıldığı yerde doğru fiyatlanır ve o yer dolu gemi.

**Döngü kesilmiyor, çözülüyor.** Fiyat → eşyanın ana stat değeri → referansın statları → fiyat: bu bir sabit nokta ve kod onu YİNELEYEREK çözüyor (`FiyatCozumu`). Tohum eski ölçüm noktası, her adım o fiyatlarla referansı kurup fiyatı yeniden ölçüyor, iki tablo arasındaki en büyük bağıl fark eşiğin altına inince duruyor. Bugün `fiyatSabitNoktaAdimi = 2` adımda ve tam olarak sıfır sapmayla yakınsıyor; sebebi ilk bandın rafında yüzdesel ANA stat olmaması — lazerin ve roketatarın ana statı taban hasar (çapa, fiyatı 1,00), jeneratörünki kalkan, CPU'nunki kalkan yenilenmesi, üçünün de fiyatı referanstan bağımsız. Rafa yüzdesel bir ana stat girdiği gün döngü gerçekten kapanır ve yineleme işini yapar; geri besleme negatif (yüzde statlar pahalılaşınca referans zayıflar, zayıflayınca ucuzlarlar), yani daralan bir dizi. Yakınsamazsa çözücü sessizce yanlış bir tablo dönmüyor, hata atıyor: ikinci yol — fiyat referansını dolu build'in düz sayılarına çapalayan tek bir girdi — ancak o gün gerekir.

İki sonucu var. Bir: yüzdesel statların puan fiyatı bir kat pahalandı (bir bütçe puanı yarısı kadar yüzde alıyor), düz taban hasar ve havuz çapaları kılını kıpırdatmadı — onların türevi referanstan bağımsız. İki: sistem kanalının kuru (`2A ÷ 100`, 09.5) artık tek yerden okunuyor; fiyatlayan ile ölçen (`PayOlcumu`) aynı A'yı görmezse hız ve menzil eşyası bir yerde pahalı, öteki yerde ucuz sayılır ve fark payın sapması gibi görünürdü.

## 03.3 · Kanal içi fiyatlama, kanallar arası kur 09'un
Durum: kodda · s1 · ItemBudget.fiyatlar, Turetilenler.savunmaCapasi

Saldırı statları DPS cinsinden ölçülebilir, savunma statları EHP cinsinden. Ama "1 DPS kaç EHP eder" sorusunun cevabı ikisinin içinde yok; o, saldırıyla dayanıklılığı bir araya getiren BR formülünün işi. Sistem statları (hız, itki, menzil) ne DPS'e ne EHP'ye giriyor; değerleri 09'da tanımlanıyor. Bu belge iki tablo üretiyor ve üçüncüyü 09'a devrediyor; kur burada tanımlanmaya çalışılsaydı 03 ile 09 arasında döngü doğardı.

Bir zamanlar koddaki fiyat tablosu saldırı ve savunmayı tek ölçekte tutuyor, ilan edilmemiş bir kur ima ediyordu; ölçüldüğünde bir savunma puanı bir saldırı puanının yalnız beşte biri kadar güç alıyordu. Bugün saldırı fiyatları DPS türevinden, savunma fiyatları EHP türevinden ve kurdan çözülüyor; üç kanal tek tabloda birleşiyor.

## 03.4 · StatMod tanımı ve çapa sözleşmesi
Durum: kodda · s1 · taban hasar çapa (fiyat 1), savunma çapası kurdan

Alan 08 eşyalara bütçe puanı dağıtıyor; bu belgenin çıktısı o puanın stata çevrilme kuru: StatMod(stat) = değer(çapa) ÷ değer(stat). Kanal başına bir çapa seçilir ve StatMod'u 1,00 olur. Çapa seçimi bir sözleşme: hangi stat olduğu sonucu değiştirmez, yalnız ölçeği belirler. Saldırı çapası taban hasar; savunma çapası gövde canı ve kalkan, ikisi de bir puanda `savunmaCapasi` kadar havuz alıyor.

## 03.5 · Değerleme dövüş süresi
Durum: kodda · s2 · Turetilenler.puanBasinaKalkanYenilenmesi, kur süresi

Bazı statların değeri dövüşün ne kadar sürdüğüne bağlı. Kalkan yenilenmesi en net örnek: iki saniyelik bir dövüşte hiçbir şey, otuz saniyelik bir dövüşte ikinci bir kalkan. Bu statlar tek bir ilan edilmiş süreyle fiyatlanır; her stata kendi süresini vermek fiyatı build'e bağlar ve bütçeyi çökertir.

Süre ayrı bir girdi değil, kur süresinin kendisi: `referansTTK = 30` saniye. Belgenin ilk sürümü 20 saniyelik ayrı bir girdi ilan etmişti; gerekçesi o günkü oyuncu-oyuncu TTK'sıydı (22 saniye) ve ölçülen TTK bugün 29,6. İki süre tutmak aynı kararı iki yerde vermek olurdu.

## 03.6 · Birim tipine göre uygulama sözleşmesi
Durum: kodda · s1 · ItemBudget.turevAdimi, StatBirimi.uygula

StatMod'un anlamı statın birim tipine bağlı ve o tip alan 02'nin kaydında duruyor: mutlak bir statın StatMod'u puan verir, oran bir statınki kesir verir, eğri bir statınki eğrinin girdisini verir. Birimi kayıttan okumayan bir motor bu tablodaki her sayıyı yanlış uygular. Kayıt üç birim tanıyor (02.2). Fiyat türevi adımını birimden alıyor: oran statı binde birlik kesirle, mutlak ve eğri statı bir puanlık adımla ölçülüyor; çözümleyici de aynı kaydı okuyarak uyguluyor. İki yer tek kaydı okuduğu için bir mutlak stata kesir fiyatı vermek, ya da tersi, tek satırda mümkün değil.

## Sınır

Sahiplenmediği: referans build'in kendisi → 04 · kanallar arası kur ve sistem kanalı değerleri → 09 · yuvalara düşen pay → 08 · hangi statın hangi eşyada olduğu → 06 · zincirin kendisi → 01.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Her açık statın bir değeri var ya da devredildiği alan yazılı | Fiyatsız stat; bütçe onu dağıtamaz, sessizce sıfır alır. |
| Değerler zincirden türüyor, elle yazılmıyor | Birileri bir fiyatı "düzeltmiş"; formül değişince o stat kopar. |
| Aynı kanalda eşit bütçe → eşit marjinal katkı | Kanal içi fiyatlama bozuk; bir stat diğerinden ucuza geliyor. |
| hasar_artisi değeri = atis_hizi değeri | Zincirin L1 katmanı bozulmuş; ikisi aynı tabanı çarpmıyor. |
| Hiçbir StatMod kanallar arası kur içermiyor | 03 ile 09'un sınırı delinmiş. |
| Çapa değişirse oranlar değişmiyor | Çapa bir sözleşme olmaktan çıkıp sonuca karışmış. |
| StatMod, statın birim tipiyle uyumlu | Mutlak bir stata kesir fiyatı verilmiş. |
