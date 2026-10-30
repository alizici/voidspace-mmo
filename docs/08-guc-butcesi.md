---
alan: 8
ad: Güç Bütçesi
katman: büyüme
tur: kural
surum: 1.4
tablo: 08-pay-tablosu.md
kaynak: https://claude.ai/code/artifact/75fcd47f-d9ad-4fa3-a0ea-4c7551b773d5
---

# 08 · Güç Bütçesi

Toplam gücün yuvalara nasıl bölüştüğü, ve bütçenin neden bir korunum yasası olmadığı. "Toplam bütçe" diye korunan bir miktar yok. Bütçenin söylediği tek şey: referansta bir puan, hangi stata konursa konsun aynı marjinal gücü alır.

Bağımlılık: 03 StatMod · [04 yuva haritası](04-gemi-ve-yuvalar.md) · [06](06-esya-kurgusu.md)/[07](07-guclendirme.md) çarpanlar · 09 kur. Bu belgeye bağlı: 13 · 16. Sayı tablosu: [08 · Pay Tablosu](08-pay-tablosu.md).

Sürüm 1.4: droid altıncı grup (08.1): beş pay orantılı düştü, droid payı girdi. Sürüm 1.3: Shapley ölçümü kodda (08.3): ölçülen paylar tabloda, ilk ölçüm ilan edilen bandın dışında ve değişmezi askıda (borç defteri B12). Sürüm 1.2: gövde havuzu TTK kısıtından çözülüyor (08.5); gövde çapası tepe tablodan düştü, referans TTK tam otuz. Gövde ↔ eşya kolu (08.6) referansın eşya havuzunu bekliyor. Sürüm 1.1: belge `docs/` altına taşındı, kararlar numaralandı ve durum aldı. Pay tablosunun 1.0'daki yedi grubu (droid, ArGe dahil) kodda beş grup; eksik gruplar orantılı düşüldü ve paylar tepe tabloda o hâliyle duruyor.

## 08.1 · Payı ilan et, katsayıyı türet
Durum: kodda · s1 · ItemBudget.shares, ItemBudget.slotCoefficient, ItemBudget.budgetFor

Yanlış yol: eşya katsayılarını tahmin et, ortaya çıkan güç paylarını ölç, sonra katsayıları paylar tutana kadar oynat. Bu sistematik değil eğri uydurmadır; her yeni yuva eklendiğinde bütün katsayılar yeniden fit edilir ve hiçbir sayının neden o değer olduğu açıklanamaz. Doğru sıra tersi ve World of Warcraft'ın item budget sisteminden alınıyor: **payı ilan et** (toplam gücün her yuva grubuna düşen payı bir tasarım kararıdır), **katsayıyı türet** (grubun payı gruptaki yuva sayısına bölününce yuva başına katsayı çıkar), **ölç** (ölçüm bir doğrulamadır, ayar kolu değil).

Bütçe(eşya) = `butceCapasi = 200` × yuva katsayısı × rank çarpanı × artı çarpanı. Yuva katsayısı = (grup payı ÷ yuva sayısı) ÷ (lazer payı ÷ lazer sayısı); lazer 1,00. Paylar tepe tabloda: `payGovde = 18,34` · `payLazer = 26,9` · `payJenerator = 22,63` · `payRoketatar = 6,72` · `payCpu = 10,4` · `payDroid = 15`. Droid geldiğinde beş pay ×0,85 orantılı düştü ve droid payı girdi; belgenin kendi kuralı, grup eklemek de çıkarmak da aynı muhasebe. Droid payı droidin saldırı payı hedefiyle (09.6) aynı büyüklükte ve gövdeye değil tam filoya bölünüyor: bir droidin katsayısı filo tavanından, gövde değişince değişmiyor. ArGe gelince aynı yol.

## 08.2 · Katsayı gövdeye bağlı
Durum: kodda · s2 · ItemBudget.slotCoefficient

Aynı grup payı daha çok yuvaya bölününce yuva başına düşen güç azalır. SS gövdedeki bir jeneratör, C gövdedeki bir jeneratörden zayıf olmak zorunda, yoksa yuva sayısı artışı tek başına gücü katlar. Kural bütün gruplarda çalışıyor ama yalnız jeneratörle CPU'da görünüyor: lazer yuvası her gövdede beş (04.9), roketatar her gövdede bir (04.11), yani onların katsayısı merdiven boyunca hiç oynamıyor ve lazerinki normalizasyon gereği tam 1,00. Bu yüzden kuralın sınanabilir hâli katsayının kendisi değil ÇARPIMI: adet × katsayı her gövdede aynı, yani grubun toplam payı gövdeyle değişmiyor; yuva kazanan grupta katsayı da düşmek zorunda. Bedeli sıfır: katsayı zaten yuva sayısından türüyor, gövde değişince kendiliğinden yeniden hesaplanıyor.

## 08.3 · Marjinal fiyatlar toplanmaz; 08 dağıtır, 16 ölçer
Durum: kodda · s2 · PayOlcumu.shapley, PayOlcumu.olculenPaylar, TasarimGirdileri.payBandi; ölçülen paylar pay tablosunda

Alan 03 her statı marjinal katkısıyla fiyatlıyor. Doğru bir yöntem, ama marjinal fiyatlar toplandığında gerçekleşen gücü aşıyor: EHP = havuz ÷ ((1 − zırh)(1 − sıyırma)) içinde üç stat birbirini tamamlıyor, havuz büyüdükçe zırhın değeri artıyor. Referans savunmasında ölçüldü: harcanan marjinal puanların toplamı gerçekleşen gücü %45 aşıyor. Bu bir hata değil, çarpımsal statların doğası.

Sonuç iki farklı araç: 08 marjinal fiyatla **dağıtır**; "bir puan her yerde aynı marjinal gücü alsın" dağıtım için doğru ve yeterli. 16 Shapley ile **ölçer**; verimlilik aksiyomu tamamlayıcılıktan doğan fazlayı adil dağıtır ve tam olarak toplama eşitlenir. "İlan edilen pay ≠ ölçülen pay" farkı her zaman olacak ve küçük kaldığı sürece sağlıklı; sağlık ölçüsü farkın büyüklüğü, `payBandi = 10` puanın altında. Kodda ikisi de: dağıtım bütçede, Shapley ölçümü denetimde ve [pay tablosunda](08-pay-tablosu.md). Ölçüm gerçekleşen gücü kur biriminde toplamsal alıyor, saldırı artı dayanıklılık bölü T artı sistem kanalı; savaş puanının geometrik ortalaması burada kullanılmıyor, çünkü iki kanalı birden isteyen bir ölçü lazeri ve gövdeyi veto oyuncusu yapar ve payı onlara yığar. İlk ölçümde en büyük fark lazerde, dokuz puan: lazer taban hasarı verdiği için her çarpan onun üstüne biniyor, tamamlayıcılık artığı ona akıyor. Bu yapısal; ilanı ölçüme çekmek kovalamaca olurdu, lazer bütçesi büyüdükçe ölçülen pay yine kaçar. Bant üç puandan ona açıldı (borç defteri B12): ilan bütçe niyeti, ölçüm bilgi, değişmez testi bantla çalışıyor.

## 08.4 · A = D, puanlarda değil gerçekleşende
Durum: kodda · s1 · CombatGlossary.battleRating, Turetilenler.savunmaCapasi

Toplanamazlığın doğrudan sonucu: saldırı puanları ile dayanıklılık puanlarını eşitlemek A = D'yi sağlamıyor. Kısıt alan 09'un tanımladığı yerde, gerçekleşen değerlerde: A = DPS, D = EHP ÷ T, A = D ⟺ TTK = T. Bütçe dağıtımının doğruluk sınavı tek bir sayı: referans build'in TTK'sı ilan edilen `referansTTK = 30` saniyeye eşit mi. Tutmadığında düzeltilecek yer gövde havuzu (08.5).

## 08.5 · Gövde havuzu TTK'dan çözülür
Durum: kodda · s2 · ReferansCozumu.govdeCapasi; HullClass.baseHull oradan okuyor, ShipStats.bastion çıplak fiyat referansı

Alan 04 gövde taban havuzunu bir girdi olarak ilan etmişti. Aslında türetilen: bütün eşya bütçeleri ilan edildikten sonra gövdenin taban havuzu, TTK'yı hedefe oturtacak değere çözülür, elle konmaz. Saldırı tarafı büyüdükçe (roketatar, droid, ArGe eklendikçe) gövde havuzu da TTK'yı korumak için büyümek zorunda. Bu 04'ün merdivenini geçersiz kılmıyor; merdiven kademeler arası oranı veriyor, değişen tek şey çapanın nereden geldiği.

Kodda çözüm: gövde çapası = referans saldırı × T × kayıp çarpanı − kalkan çapası − eşya havuzu; sayılar [pay tablosunda](08-pay-tablosu.md). Referans tam donanımlı (04.5): eşya havuzu jeneratörlerin kattığı kalkan ve sıfır değil; referans lazerin namlu hasarı bütçeden türüyor, tepe tabloda girdi olarak durmuyor. Gövde merdiveni çözümü okunuşta okuyor; gövde kurulurken çözüm, çözüm kurulurken gövde gerekmiyor, çünkü DPS ve kalkan cana bağlı değil. Referans TTK ölçülmüyor, kurulumla tam otuz.

Eşya havuzu terimi bugün sıfır: referans build çıplak gövde ile beş lazer, kalkan jeneratörlerinin katkısı referansa girmiyor. Referans tam donanımı taşıdığında (04.5) terim dolar ve 08.6'nın kolu doğar; o gün gövde çapası düşer ve gücün çoğu eşyaya geçer.

## 08.6 · Gövde ↔ eşya kolu
Durum: kodda · s1 · ReferansCozumu.referansEsyaHavuzu; jeneratör bütçesi eşya havuzunu, o da gövde çapasını iter

"Gücün çoğu eşyadan gelsin" tercihi tek bir kolla ayarlanır: kalkan jeneratörlerinin bütçesi. Gövde havuzu TTK kısıtından çözüldüğü için eşyaların havuza kattığı her puan gövdeden bir puan düşürür; jeneratör payını büyütmek gövde payını doğrudan küçültür, başka hiçbir şeyi bozmadan. İki farklı "pay" karıştırılmamalı: **bütçe payı** (gövde grubunun toplam bütçeden aldığı yüzde, zırh dahil) ve **havuz kaynağı** (etkin canın yüzde kaçının gövdenin taban havuzundan geldiği). Kolun sınırı var: çıplak gemi de savaşabilmeli; yeni oyuncu ilk saatini eşyasız geçirir. Kol ancak havuz kısıttan çözülünce (08.5) var olur.

## Sınır

Sahiplenmediği: bir puanın kaç birim stat aldığı → 03 · kanallar arası kur → 09 · yuva sayıları → 04 · rank ve artı çarpanları → 06 · 07 · ölçülen payın Shapley ile hesabı → 16 · fiyatlar → 13.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| Paylar toplamı = %100 | Bir grup eklenmiş ama diğerlerinden düşülmemiş. |
| Katsayılar paylardan türüyor, yazılmıyor | Eğri uydurmaya dönülmüş. |
| Referans TTK = T (±%2) | Dağıtım A = D'yi bozmuş. |
| Adet × katsayı gövdeden bağımsız; yuva kazanan grupta katsayı düşüyor | Yuva sayısı artışı gücü katlıyor. |
| Ölçülen pay ↔ ilan edilen pay farkı < `payBandi = 10` puan | Tamamlayıcılık artığı bandın dışına çıkmış. |
| Hiçbir grubun payı sıfır değil | Ölü yuva grubu var. |
| Gövde havuzu TTK'dan türetiliyor | Elle yazılmış; saldırı büyüyünce TTK kayacak. |
| Çıplak gemi TTK'sı bir tabanın üstünde | Eşyasız gemi oynanamaz hâle gelmiş. |
