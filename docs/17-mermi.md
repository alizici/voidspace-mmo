---
alan: 17
ad: Mermi
katman: ekonomi
tur: kural
surum: 1.0
tablo: 17-mermi-tablosu.md
kaynak: https://claude.ai/code/artifact/cae28d7c-a222-4d11-ab61-b0829dad9069
---

# 17 · Mermi

Altı çarpan, bir sifon, ve ölçünce çıkan sonuç: mermi bir PvE sistemi değil. Sıradan yaratıkta en pahalı mermi yüzde on kazandırıyor, PvP'de altı kat. Sebep basit ve ölçülebilir: farm çevriminin dokuz saniyesinin sekizi yeniden doğma; daha hızlı öldürmek beklemeyi kısaltmıyor. Belge yan belge olarak yazılmıştı, `docs/` altına taşındı ve kodlandı.

Kullandığı: [01](01-savas-formulu.md) hasar zinciri ve taban hasar · [11](11-haritalar.md) PvP primi · [13](13-kaynak-akisi.md) gelir ve gider yapısı · [15](15-kazanc.md) mağaza ve NOVA kilitleri. Sayı tablosu: [17 · Mermi Tablosu](17-mermi-tablosu.md).

Sürüm 1.0: yan belgeden taşındı; dört girdi ve iki kilit tepe tabloya girdi, fiyatlar ve ölçümler koddan basılıyor. Yan belgenin saatlik gider ve prim sayıları elle hesaplanmıştı; tablo artık referans build'in gerçek atış ritmiyle basıyor, o yüzden birkaç puan oynuyor. Roket kendi alanında, 18 (Sınır).

## 17.1 · Mermi PvE'de değil PvP'de belirleyici
Durum: kodda · s1 · Turetilenler.mermiOldurmeSa, Turetilenler.mermiPveKazanci, Turetilenler.mermiPvpTtk

Mermiyi bir farm hızlandırıcı olarak kurgulama niyetiyle başlandı; ölçüm reddetti. Sıradan yaratığın çevrimi öldürme süresi artı yeniden doğma (12); çarpan yalnız ilkini bölüyor. Tavan çarpanla çevrim dokuz saniyeden `mermiCevrim(6) = 8,2` saniyeye iniyor, saatte öldürme `mermiPveKazanci(6) = %10` artıyor; güçlü yaratıkta `mermiPveKazanciGuclu(6) = %20`. PvP'de rakip yeniden doğmuyor: çarpan doğrudan TTK'ya vuruyor, otuz saniye `mermiPvpTtk(6) = 5` saniyeye iniyor. Yani mermi PvE'de alınabilir ama gerekmiyor, PvP'de belirleyici; fiyatlandırmayı ve kimin ne alacağını bu belirliyor.

## 17.2 · MR-1 bedava ve sınırsız
Durum: kodda · s1 · mr1Bedava kilidi, Mermi.bedava, HangarRules.mermiAl MR-1'i satmıyor

Temel mermi ücretsiz, iki sebeple ve ikincisi teknik. Oynamak vergilendirilmez: zorunlu mermi gideri, gelirden alınan sabit bir kesintiden başka bir şey değil, geliri düşürmenin dolambaçlı yolu. Ve ×1 dengenin çapası: 01'in referans DPS'i, 09'un TTK kısıtı, 12'nin yaratık canları, 13'ün gelir hedefleri, hepsi ×1 ile hesaplandı; bedava ve sınırsız olması o hesapların hiçbirinin değişmemesi demek. Üst çarpanlar isteğe bağlı: 13'ün gider yapısı olduğu gibi kalıyor, mermi birikim ve mağaza paylarından finanse ediliyor. Kilit tepe tabloda; raf MR-1'i listeliyor ama satmıyor, stokta da tutmuyor.

## 17.3 · Çarpan yalnız taban hasarı çarpar
Durum: kodda · s1 · sunucu hasar zinciri: yaylımın taban hasarı × çarpan; droid ve bütçe dışında

Mermi zincirin girişini (L0) çarpıyor; oran bonusları, kritik ve son hasar mermiden etkilenmiyor, droidin kendi zinciri hiç görmüyor. Böylece mermi 08'in bütçe hesabına girmiyor: temiz, doğrusal, ayrı bir kanal. Bütçeyle çarpılsaydı üst rank eşyaların mermi kazancı da katlanır ve A/D dengesi bozulurdu. Zincirin geri kalanı çarpımsal olduğu için vuruşun tamamı çarpanla ölçekleniyor, yalnız son hasarın sabit payı değil; bu 01'in sözleşmesi, mermi ona uyuyor.

## 17.4 · Fiyat eğrisi iki ankrajdan geçer
Durum: kodda · s1 · `mermiTabanFiyati = 7,67`, `mermiFiyatUssu = 1,631`, `mermiCarpanTavani = 6`, Turetilenler.mermiFiyati, Turetilenler.mermiUsAnkraji

Fiyat(m) = c × m^k. İki ankraj: ×2 ile sürekli farm referans gelirin `mermiGelirPayi(2) = %16`'sı kadar gider, hedef on beşti; tavan çarpanın birim hasar başına bedeli ×2'ninkinin iki katı. İkincisi üssü tek başına belirliyor, k = 1 + ln 2 ÷ ln 3, ve türetme testi tepe tablodaki üssün bunu taşıdığını ölçüyor. Sonuç: ×1 en verimli mermi ve hep öyle kalacak; üst çarpanlar verim değil hız satıyor, hızın fiyatı doğrusaldan hızlı artıyor. Birim bir namlu atışı (17.8); saatlik gider, öldürme başına gereken atış çarpana bölündüğü için, çarpanla değil birim hasar bedeliyle büyüyor. Sifonun fiyatı kendi çarpanının fiyatı, yani MR-3 ile aynı.

## 17.5 · Tavan çarpan PvP primini yer
Durum: kodda · s1 · MermiOlcumu.gelirPayi, MermiOlcumu.pvpNetPrim

Alan 11 PvP haritasına brüt bir prim vermişti; ölümler düşüldükten sonra net yüzde otuz. Mermi o hesaba girmiyordu. Girince: sürekli tavan çarpan kullanan oyuncu PvP'den zarar ediyor, net prim `mermiPvpNetPrim(6) = %-13`. Ayarlanmadı; fiyat eğrisi PvE ankrajından, prim 11'den geldi ve kesiştikleri yer burası. Sonuç doğru davranışı üretiyor: ×6 önemli dövüşler için bir patlama aracı, varsayılan değil. Kazanmak istediğin dövüşte ucuz, sürekli kullanımda pahalı.

## 17.6 · Sifon yalnız kalkana
Durum: kodda · s1 · `sifonCarpani = 3`, ShipSim.applyShieldDamage, MermiOlcumu.sifonEtkinCarpani

SF-1 gövdeye hiç hasar vermiyor, kalkana üç kat vuruyor; fiyatı MR-3 ile aynı. Görünüşte kötü bir takas; asıl değeri fiyatın söylemediği yerde: kalkan yenilenmesi sabit bir çıkarma olduğu için hasar büyüdükçe oransal etkisi küçülüyor. Sifon nominal üç vuruyor ama yenilenmeye karşı `sifonEtkinCarpani = 6,03` değerinde. Kalkana yaslanmış bir rakip, düşük DPS'li bir saldırganın hiç kıramayacağı bir duvar olabilir; sifon o duvarı kırıyor ve sonra işe yaramaz hâle geliyor: gövde fazında mermi değiştirmek zorundasın. Bir silah değil, bir açış. Kalkanı aşan pay gövdeye taşmıyor, yok oluyor. Yaratığın kalkanı yok: sifon yaratığa geminin payını hiç indirmiyor, yalnız droidlerinki iniyor.

## 17.7 · Mermi NOVA ile satılmaz, BR saymaz
Durum: kodda · s1 · novaMermiSatiyor kilidi, Mermi.novaIleSatilir; CombatGlossary.battleRating mermiyi okumuyor

15 paranın tavanını ölçmüştü; para yalnız kalite rolüne dokunabiliyordu. Mermi NOVA ile satılabilseydi o tavan anlamsızlaşırdı: tavan çarpan PvP'de altı kat hasar. Mermi krediyle alınıyor, kredi zamanla kazanılıyor; ×6 parayla değil sabırla. Savaş puanı geminin sürdürülebilir gücünü ölçüyor, mermi tüketilebilir ve geçici; sonucu açıkça yazmak gerekiyor: bir oyuncunun patlama gücü BR'sini altı kat aşabilir. Kapılar ve eşleştirme yine çalışıyor, çünkü mermi simetrik: iki taraf da aynı raftan alıyor. Asimetri parada değil, o an ne kadar harcamaya razı olunduğunda.

## 17.8 · Birim namlu atışı, stok hesapta
Durum: kodda · s1 · Hangar.mermiHarca, Hangar.seciliMermi, HangarRules.mermiSec, sunucu yaylım başına tüketiyor

Mermi eşya değil: örneği yok, yığılıyor, artı basılmıyor, düşmüyor. Stok hesapta duruyor ve gemi değişince kalıyor. Birim bir namlu atışı: beş namlulu gemi yaylımda beş birim harcıyor, yani aynı stok büyük gemide daha hızlı biter ve bu doğru, o gemi aynı sürede daha çok hasar veriyor. Seçim hangarda ya da savaş çubuğunda, anında gemiye geçiyor; geçit beklemiyor. Stoğu biten mermi MR-1'e düşüyor: silah susmuyor, bedava olana geçiyor; oyuncu sayacı çubukta görüyor.

## Sınır

Sahiplenmediği: hasar zincirinin kendisi → 01 · yaratık canı ve çevrimi → 12 · PvP primi → 11 · gelir hedefi → 13 · NOVA fiyatları ve paranın tavanı → 15. Roket bu belgenin dışında ve kendi alanında (18): roketatar bir silah, roket mermisi bu belgenin fiyat eğrisini birim oranıyla okuyor (18.3).

## Değişmezler

| Değişmez | Kırılırsa ne demek |
|---|---|
| MR-1 bedava ve sınırsız | 01–16'nın bütün referans hesapları geçersiz. |
| Birim hasar bedeli çarpanla artıyor | Üst mermi hem hızlı hem ucuz olmuş; alt mermiler ölü. |
| Mermi yalnız taban hasarı çarpıyor | 08'in bütçesine girmiş; A/D üst ranklarda bozuluyor. |
| Tavan çarpan sürekli kullanımda PvP net primi ≤ 0 | En pahalı mermi varsayılan olmuş. |
| Mermi NOVA ile satılmıyor | 15'in tavanı delinmiş. |
| Sifon gövdeye 0 hasar | Tek başına öldürebilir hâle gelmiş; mermi değiştirme kararı yok olmuş. |
| Sifonun yenilenmeye karşı etkin çarpanı > nominal | Varlık sebebi kalmamış; MR-3 her yönden üstün. |
| Sıradan yaratıkta PvE kazancı ≤ %15 | Mermi farm zorunluluğuna dönüşmüş; 13'ün gelir hedefleri kaymış. |
| Üs iki ankrajın kesişimi | Fiyat elle konmuş; ankraj cümlesi boş. |
