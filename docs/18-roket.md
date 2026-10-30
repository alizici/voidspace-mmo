---
alan: 18
ad: Roket
katman: ekonomi
tur: kural
surum: 1.0
tablo: 18-roket-tablosu.md
---

# 18 · Roket

Roketatar uzun süre bir stat eşyasıydı: hasar artışı veriyor, hiçbir şey atmıyordu. Savaş çubuğuna ROKET düğmesi istendiğinde seçilecek şey yoktu (borç defteri B20). Karar: roketatar bir silah. Her `roketAraligi = 6` saniyede bir hedefe bir salvo, salvonun tabanı roketatarın taban hasarı, zincirin geri kalanı geminin; roket mermisi mermi gibi alınıyor, seçiliyor, bitiyor. Bütçe payı (08.1) değişmedi: roketatar artık yüzde bonusu değil DPS taşıyor, payı aynı büyüklükte.

Kullandığı: [01](01-savas-formulu.md) hasar zinciri · [02](02-stat-kutuphanesi.md) kapsam · [03](03-stat-degeri.md) fiyat · [04](04-gemi-ve-yuvalar.md) yuva · [08](08-guc-butcesi.md) pay · [17](17-mermi.md) mermi eğrisi. Sayı tablosu: [18 · Roket Tablosu](18-roket-tablosu.md).

Sürüm 1.0: alan açıldı, kodlandı. Bir girdi (`roketAraligi`) ve bir kilit (RK-1 bedava) tepe tabloya girdi; kadans oranı, birim oranı ve fiyatlar türetilen.

## 18.1 · Roketatar bir silah, kadans oranıyla
Durum: kodda · s1 · StatScope.roket, LoadoutResolver.vectorOf, ShipStats.roketHasari, Turetilenler.roketKadansOrani

Roketatar yuvasındaki eşyanın ana statı taban hasar ve roket kapsamına yazılır (02.3'e üçüncü kapsam): gemi kapsamında taban hasar lazerin tekelinde (04.2), roket kapsamında roketatarın; ikisi aynı anahtara yazamaz, çift sayım imkânsız. Eşya bütçesi lazer kadansında fiyatlanıyor (03): bir puan taban hasar, 1,1 saniyede bir vurulan bir hasar. Roket `roketAraligi = 6` saniyede bir vuruyor; salvonun tabanı aynı puanın `roketKadansOrani = 5,45` katı. Böylece roketin DPS'i bütçe payına eşit kalıyor: referansta roket, saldırının `roketDpsPayi = %20`'si (`payRoketatar` bölü lazer payı). Salvo tabanı referansta `roketSalvoHasari = 1.927`. Roketatarın alt statları gemi kapsamına: roketatar geminin silahı, bonusları herkesin.

## 18.2 · Roket zinciri geminin, tabanı roketin
Durum: kodda · s1 · CombatGlossary.roketSalvo, CombatGlossary.saldiriDps, Zone._roketAt

Roket 01'in altı katmanından geçiyor, ayrı bir zincir değil: taban roketin (18.1), hasar artışı, kritik, hedefin zırhı ve sıyırması, PvP katsayısı geminin ve hedefin. Droid gibi σ ile bağlı bir varlık değil (05.5): roket geminin silahı, geminin bütün çarpanlarını taşır. Kritik zarı geminin sayacından; kalkan ve gövde lazer gibi (önce kalkan, taşan gövde, 01.3), sifon yok. Referans DPS artık lazer artı roket; gövde çapası (08.5), yaratık canı (12) ve savaş puanı (09) toplam saldırıyı okuyor.

## 18.3 · Roket mermisi: RK-1 bedava, üstü mermi eğrisiyle
Durum: kodda · s1 · Roket, Turetilenler.roketFiyati, Turetilenler.roketBirimOrani, HangarRules.roketAl

RK-1 bedava ve sınırsız, 17.2'nin gerekçesiyle: oynamak vergilendirilmez ve ×1 dengenin çapası. RK-2 … RK-6 salvonun tabanını çarpar, yalnız tabanı (17.3). Fiyat mermi eğrisinin `roketBirimOrani = 6,8` katı: bir salvo lazer birim atışının o kadar katı hasar taşıyor (kadans oranı × roketatar yuva katsayısı), yani hasar başına bedel iki mermide aynı. Ayrı bir eğri yok; üs ve ankraj 17'nin, roket onları okuyor. Tavan çarpan mermininki (`mermiCarpanTavani`).

## 18.4 · Stok hesapta, seçim savaş çubuğunda
Durum: kodda · s1 · Hangar.roketHarca, Hangar.seciliRoket, HangarRules.roketSec, sunucu salvo başına tüketiyor

Roket mermisi eşya değil: örneği yok, yığılıyor, artı basılmıyor, düşmüyor. Stok hesapta duruyor, gemi değişince kalıyor. Birim bir salvo: gemi kaç namlu taşırsa taşısın roketatar tek (04.11), salvo bir birim. Seçim savaş çubuğunda ROKET düğmesiyle, anında gemiye geçiyor; stoğu biten RK-1'e düşüyor ve sayaç çubukta. Mağazada ROKET rafı, paket yirmi salvo.

## 18.5 · Roket NOVA ile satılmaz, mermisi BR saymaz
Durum: kodda · s1 · novaMermiSatiyor kilidi, Roket.novaIleSatilir; CombatGlossary.battleRating roket mermisini okumuyor

17.7'nin ikizi. Roket mermisi krediyle, kredi zamanla; ×6 salvo parayla değil sabırla. Savaş puanı geminin sürdürülebilir gücünü ölçüyor: roketatarın kendisi (silah, bütçeli) puana giriyor, seçili roket mermisinin çarpanı girmiyor. Kapılar ve eşleştirme yine çalışıyor, çünkü mermi simetrik.

## 18.6 · Ayrı atış olayı, ayrı çizim
Durum: kodda · s1 · ShotEvent.roket, CombatLayer roket mermisi, BoltArt.roket

Sunucu her salvo için ayrı bir atış olayı üretiyor ve bayrağını koyuyor; hasar aynı zincirden, olay yalnız "hangi silah" diyor. Tel üzerinde bedeli sıfır bayt: bayrak baytının beşinci biti. İstemci roketi lazer dalgasının dışında çiziyor: tek mermi, geminin merkezinden, iri ve yavaş, sayıyı kendisi taşıyor. Roket ayrı görünmeseydi altı saniyede bir gelen büyük sayı kaynaksız düşerdi.

## Sınır

Sahiplenmediği: hasar zinciri → 01 · kapsam sistemi → 02 · fiyat → 03 · roketatar yuvası → 04 · bütçe payı → 08 · mermi eğrisinin üssü ve ankrajı → 17. Roketin kendi menzili yok: lazerin menzili (12'nin oranları oradan). Roketin hedef seçimi geminin hedefi; ayrı hedef, güdüm ya da alan hasarı bu belgede yok.

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| RK-1 bedava ve sınırsız | ×1 çapası kaymış; 18.2'nin referans saldırısı geçersiz. |
| Roket DPS payı bütçe payına yakın | Kadans oranı ile fiyat ayrışmış; roketatar yuvası ya ölü ya baskın. |
| Hasar başına bedel mermiyle aynı | İki mermi iki ekonomi olmuş. |
| Roket mermisi yalnız salvonun tabanını çarpıyor | Bütçeye girmiş; üst ranklarda A/D bozuluyor. |
| Roket kapsamında taban hasar lazerin yaylımına girmiyor | Çift sayım; kapsam kilidi (02.3) delinmiş. |
| Salvo başına bir birim | Stok namluyla yanıyor; roketatar tek yuva. |
