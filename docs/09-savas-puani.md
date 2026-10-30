---
alan: 9
ad: Savaş Puanı
katman: büyüme
tur: kural
surum: 1.3
tablo: 09-br-tablosu.md
kaynak: https://claude.ai/code/artifact/cc406a21-feeb-491e-91d0-74a5d80a5663
---

# 09 · Savaş Puanı

Bütün statları tek sayıya indiren ölçü aleti, ve kanallar arası kurun nereden geldiği. Kur ilan edilmiyor, türetiliyor; türediği yer şaşırtıcı derecede basit: referans TTK'nın kendisi.

Bağımlılık: [03](03-stat-degeri.md) kanal içi değerler · [04](04-gemi-ve-yuvalar.md) referans build. Bu belgeye bağlı: 08 · 10 · 11 · 16. Sayı tablosu: [09 · BR Tablosu](09-br-tablosu.md).

Sürüm 1.3: droidin iki katsayısı kodda (09.6): saldırıya ayakta kalma ile, dayanıklılığa çeyrek ile. Sürüm 1.2: itki dolumu kütüphaneye girince katsayısı tepe tabloya döndü ve sistem puanı savaş puanına bağlandı (09.5): o güne kadar formül vardı, çağıran yoktu. Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. Sistem katsayılarından itki dolumu o gün koddan düşmüştü, çünkü stat kütüphanede yoktu (02.7).

## 09.1 · BR geometrik ortalama
Durum: kodda · s1 · CombatGlossary.battleRating

BR = √(SALDIRI × DAYANIKLILIK) × SİSTEM × K. Saldırı DPS; dayanıklılık EHP ÷ T; sistem 1 + Σ sistem katkısı ÷ 100; K ölçek sabiti. Geometrik ortalama seçildi çünkü dengeyi zorunlu kılıyor: yalnız saldırıya ya da yalnız savunmaya yatırım yapan oyuncu, ikisini dengeleyenden düşük BR alıyor. Aritmetik ortalama bu baskıyı üretmezdi. Sistem çarpımsal ve küçük: hız ve menzil BR'yi yükseltiyor ama saldırı ya da dayanıklılığın yerini alamıyor; sistem statları oyuncuyu güçlendirmiyor, oyunu kolaylaştırıyor.

## 09.2 · Kanallar arası kur = referans TTK
Durum: kodda · s1 · TasarimGirdileri.referansTTK, Turetilenler.savunmaCapasi

Alan 03 "1 DPS kaç EHP eder" sorusunu buraya devretmişti. Cevap uydurulmuyor, TTK'nın türevinden çıkıyor: TTK = EHP ÷ DPS, ∂TTK/∂DPS = −EHP ÷ DPS², ∂TTK/∂EHP = 1 ÷ DPS; oran EHP ÷ DPS = TTK. Bir DPS'in TTK'ya katkısı, bir EHP'nin katkısının TTK katı: 1 DPS ≡ T × 1 EHP. Kur `referansTTK = 30` saniyenin kendisi; ayrı bir girdi değil, ayrı bir varsayım değil. Dövüşün ne kadar sürdüğü, saldırıyla dayanıklılığın kurunu zaten belirliyor.

## 09.3 · A = D kısıtının anlamı
Durum: kodda · s1 · CombatGlossary.battleRating dayanıklılık = EHP ÷ T

A = D ⟺ DPS = EHP ÷ T ⟺ TTK = T. "Saldırı ile dayanıklılık dengede olsun" cümlesi aslında "referans dövüş, ilan edilen süre kadar sürsün" demek. Soyut bir simetri kısıtı değil, oyunun temposu. Referans build'in ölçülen TTK'sı ilan edilene yüzde iki içinde tutmalı; bugünkü değer [tabloda](09-br-tablosu.md).

## 09.4 · Savunma çapası ve ölçekleme
Durum: kodda · s1 · Turetilenler.savunmaCapasi, ItemBudget.birimFiyati

Alan 03 iki kanalı ayrı normalize etmişti: saldırıda taban hasar 1,00, savunmada gövde canı 1,00. İkinci çapa bir sözleşmeydi, çünkü onu belirleyecek bilgi orada yoktu. Kur türetildikten sonra keyfî olmaktan çıkıyor: bir bütçe puanı her iki kanalda da aynı gücü almalı. Bir saldırı puanı = bir taban hasar = beklenen DPS = o DPS × T kadar EHP; bir savunma puanı eşit güç için aynı EHP'yi almalı, havuz cinsinden EHP ÷ azaltma çarpanı. Savunma fiyatlarının hepsi bu çapayla ölçekleniyor; oranlar değişmiyor, yalnız ölçek yerine oturuyor. Ölçüldüğünde eski elle konmuş fiyat bir savunma puanına saldırı puanının beşte biri kadar güç veriyordu.

## 09.5 · Sistem kanalı değerleri ve tavanı
Durum: kodda · s1 · CombatGlossary.sistemCarpani, CombatGlossary.sistemPuaniOf

Hız ve menzil ne saldırıya ne dayanıklılığa giriyor; kaçmayı, yetişmeyi, mesafe tutmayı besliyorlar. Değerleri sistem çarpanından: her stat ilan edilmiş bir katsayıyla sistem puanına dönüşüyor, `sistemKatsayisiMenzil = 0,5` · `sistemKatsayisiHiz = 0,4` · `sistemKatsayisiItki = 0,3`, ve sistem puanı BR'yi çarpımsal büyütüyor. Menzil en değerlisi: hedefte kalma süresini uzatıyor, hem saldırıya hem kaçışa yarıyor; ∂DPS/∂menzil = 0 olduğu için saldırı kanalında fiyatlanamıyor, bu kanal onun yeri.

Sistem tavanlı olmak zorunda: `sistemTavani = 25` puan, çarpan en fazla 1,25. Çarpımsal olduğu için sınırsız bırakılırsa hem saldırıyı hem dayanıklılığı birden büyütür; geometrik ortalamanın içinde iki kez sayılan şey baskın olur. İtki dolumu en küçüğü: yalnız kaçışa yarıyor, yetişmeye değil, ve şarj sayısıyla sınırlı. Sistem puanı donanımın oran statlarından çıkıyor: menzil, hız ve itki dolumu yüzdeleri katsayılarıyla toplanıp savaş puanını çarpıyor. Gövdenin taban hızı girmiyor; puan eşyanın verdiği yüzde, referans gövdeye göre ölçülen fark değil. Uzun süre formül vardı, çağıran yoktu: sistem kanalı savaş puanında sıfırdı ve yalnız menzil ya da hız veren bir parça hangarda yükseltme sayılmıyordu. Bugün sayılıyor; kapılar sistem statı taşıyan build'e en çok dörtte bir erken açılıyor ve merdivenin tavanı bunu zaten taşıyordu (10.3).

## 09.6 · Droid'in iki katsayısı
Durum: kodda · s1 · CombatGlossary.droidDps, CombatGlossary.droidEhp, battleRating

Droid saldırıya ayakta kalma ile, dayanıklılığa çeyrek katsayı ile girer. İkincisi matematiksel zorunluluk: geometrik ortalamanın içinde iki kez sayılan şey, kareköke rağmen baskın olur. Çeyrek katsayı bu iki yönlü kaldıracı kırar; droid'lerin gerçekten bir miktar hasar emdiğini kabul eder ama katsayı bir olamaz. Kodda: saldırı kanalına droid grubunun beklenen DPS'i ayakta kalma ile giriyor (bir: droid dövüşte hedef alınmıyor, kaybı sahibinin ölümüyle aşınan dayanıklılıktan — 05.10), dayanıklılığa droid etkin canının `droidDayaniklilikKatsayisi = 0,25` katı. Droid taban hasarı `droidDpsPayi = 0,15` payından türüyor (05.5): referans gövdenin çıplak droidleri referans yaylımın bu kadarını veriyor.

## 09.7 · Ölçek sabiti K
Durum: kodda · s1 · TasarimGirdileri.brOlcegi, CombatGlossary.brTabani

K hiçbir dengeyi etkilemiyor: bütün BR'leri aynı oranda çarpıyor, sıralamayı ve oranları değiştirmiyor. Tek işi sayıyı okunabilir kılmak. Değeri unvan merdiveninden geliyor: `brOlcegi = 1,79263`, referans oyuncuyu ilk unvanın eşiğine, 3.600'e oturtuyor. Gövde havuzu TTK'dan çözülünce (08.5) referansta A = D tam sağlandı, BR tabanı A × K oldu ve K yeniden çözüldü; referans tam donanıma geçince (04.5) bir kez daha çözüldü. Merdiven yerinden oynamadı: taban hep 3.600. Taban bir girdi (`ilkUnvanEsigi = 3.600`, 10.3) ve K dolu referansın kanal gücünü, yani sistem çarpansız √(A·D)'yi oraya oturtuyor; referansın kendisi menzil ve hız eklentisiyle biraz üstünde durur. Savaş katmanı referansı okuyamadığı için taban oradan değil girdiden okunuyor. Merdiven basamakları 10'un, ama basamakların hangi sayıda olduğunu belirleyen ölçek 09'un, çünkü BR'yi üreten formül burada.

## Sınır

Sahiplenmediği: statın kanal içi değeri → 03 · yuvalara düşen pay → 08 · unvan eşikleri → 10 · harita giriş eşiği → 11 · referans build → 04 · hedef TTK bantları → 12 · mermi → 17 (BR mermiyi saymıyor; patlama gücü BR'yi aşabilir). Son satır önemli: 09 referans TTK'yı kur olarak kullanıyor ama harita başına hedef TTK'ları 12 belirliyor. İkisi karışırsa BR'nin ölçüsü içeriğe göre kayar.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Referans build'de A = D (±%2) | Referans TTK ilan edilenden sapmış; kur geçerli değil. |
| Kanallar arası kur = referans TTK | Kur elle yazılmış; iki yerde iki farklı sayı. |
| Eşit bütçe → eşit BR katkısı, her iki kanalda | Çapa yanlış ölçeklenmiş; bir kanal ucuza geliyor. |
| K değişince BR sıralaması değişmiyor | K dengeye karışmış. |
| SİSTEM çarpanı tavanı aşmıyor | Sistem statları saldırı ve dayanıklılığı birden büyütüyor. |
| Droid havuz katsayısı < 1 | Droid geometrik ortalamada iki kez sayılıyor. (09.6 belgede) |
| Unvan statı BR'ye girmiyor | Ölçü aleti kendini ölçüyor. (05.6) |
| Yalnız saldırıya yatırım, dengeli yatırımdan düşük BR veriyor | Geometrik ortalamanın denge baskısı kaybolmuş. |
