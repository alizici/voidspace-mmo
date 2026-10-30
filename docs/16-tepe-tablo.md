---
alan: 16
ad: Tepe Tablo
tur: tablo
kural: 16-denge-denetimi.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 16 · Tepe Tablo

Kural belgesi: [16 · Denge Denetimi](16-denge-denetimi.md). Koddan üretilir: 114 girdi, alan başına 7,6. Çakışan girdi: yok; gerekçesiz girdi: yok.

## Girdiler

| Alan | Girdi | Değer | Gerekçe |
|---|---|---:|---|
| 01 | `kritikSansiReferans` | 0,25 | Dört yaylımda bir kritik. |
| 01 | `kritikCarpaniReferans` | 2 | Ekranda okunması en kolay çarpan. |
| 01 | `zirhAzaltmaHedefi` | 0,3 | Referansta %30 — hissedilir ama tekelci değil. |
| 01 | `siyirmaTavani` | 0,4 | Hasar asla sıfırlanmaz. |
| 01 | `siyirmaHedefiReferans` | 0,15 | Zırhın yarısı: kardeş ama baskın değil. |
| 01 | `pvpCarpani` | 1 | Bugün etkisiz, kol duruyor. |
| 01 | `sonHasarTavani` | 0,1 | L5 zinciri ele geçiremez. |
| 04 | `kalkanCapasi` | 8.000 | Gövdenin %67'si — kalkan ikinci havuz. |
| 04 | `hizCapasi` | 320 | Tempo belirliyor; kademeyle neredeyse artmıyor. |
| 04 | `zirhCapasi` | 1.000 | 01'in %30 azaltma hedefini sayıya çeviren referans. |
| 04 | `referansKacinma` | 300 | Aynı işi sıyırma eğrisi için yapıyor. |
| 04 | `referansJeneratorKalkan` | 0,5 | Yarısı kalkan, yarısı hız — takas kararı. |
| 05 | `droidFiloTavani` | 10 | Filo gövdeden bağımsız; on, eski merdivenin tavanı. |
| 05 | `aktarimKatsayisi` | 0,3 | Sıfırda droid erir, birde droid yığmak tek build olur. |
| 05 | `formasyonTakasi` | 0,1 | Yirmi formasyon tek girdi: yön ayrı, miktar bir. |
| 05 | `argeAktarimAdimi` | 0,033 | Üç düğümlük dal, bir formasyon eğilimi kadar. |
| 15 | `tasarimNova` | 100 | Görünüş zaman kazandırmıyor: fiyatı türetilemez, ilan edilir. |
| 15 | `formasyonNova` | 200 | Formasyon geometri de taşıyor; tasarımın iki katı. |
| 05 | `droidYuvasi` | 1 | Tek yuva seçim demek: hasar mı dayanıklılık mı. |
| 05 | `elitDroidYuvasi` | 2 | Elitin tek farkı: seçmek zorunda değil. |
| 05 | `droidAsinmaPayi` | 10 | On ölüm: bir süs değil, filoyu silen bir vergi de değil. |
| 04 | `referansAtisAraligi` | 1,1 | Kurun ikinci ayağı: taban hasar → DPS. |
| 04 | `govdeKademeSayisi` | 8 | Sekiz gemi, sekiz bölge. |
| 04 | `yuvaArtisi` | 1 | Sanat kararı: kademe başına bir yuva; lazere değil. |
| 04 | `hizArtisi` | 1,08 | Hız tempo belirler; rank çarpanıyla büyüseydi savaş bozulurdu. |
| 04 | `lazerYuvaSayisi` | 5 | Sanat kısıtı: çizimdeki kaide sayısı, sekiz tasarımda beş. |
| 04 | `jeneratorYuvaPayi` | 0,6667 | Bastion'ın 4 · 2 dağılımı: kalan yuvaların üçte ikisi jeneratör. |
| 06 | `rankSayisi` | 20 | Altı harf ailesi × üç basamak + Kırmızı ve Parlayan Pembe. Tepesi 1,442^19 ≈ 1.048×, iki yıllık hedefin vardığı yer. |
| 06 | `rankArtisi` | 1,442 | Ölçüldü: bugünkü beş çarpan zaten bu merdiveni izliyor. |
| 06 | `anaStatPayi` | 0,7 | Rank çakışmasına pay bırakıyor: en dar boğaz birin üstünde. |
| 06 | `kaliteAltSiniri` | 0,7 | Kalite makası rank atlamasının altında. |
| 06 | `kaliteAltSiniriSS` | 0,75 | Üst rank sayı olarak değil güvenilirlik olarak da ayrışır. |
| 06 | `kaliteAltSiniriRenk` | 0,8 | Kapak taşı en dar bant; paranın tavanı burada en küçük. |
| 06 | `garantiliAltStatSS` | 1 | Renk kalite güvencesi: bir alt stat bandın tepesinden. |
| 06 | `garantiliAltStatRenk` | 2 | Kapak taşında iki alt stat mükemmel gelir. |
| 08 | `butceCapasi` | 200 | Bütün eşyalar buna göre türüyor. |
| 08 | `payGovde` | 18,34 | Gövde tek eşya ve taban havuzun tamamını taşıyor. |
| 08 | `payLazer` | 26,9 | Katsayı ölçeğinin çapası. |
| 08 | `payJenerator` | 22,63 | Gövde ↔ eşya kolunun tuttuğu yer. |
| 08 | `payRoketatar` | 6,72 | Tek yuva: katkısı büyürse tek eşya oyunu belirler. |
| 08 | `payDroid` | 15 | Altıncı grup; droid DPS payı hedefiyle aynı büyüklükte. |
| 08 | `payCpu` | 10,4 | İki yuva, savunma kanalı. |
| 08 | `payBandi` | 10 | Ölçülen pay ilan edilenden en çok bu kadar sapar; sapma yapısal, üç puan tutmadı. |
| 09 | `referansTTK` | 30 | Kanallar arası kurun KENDİSİ: 1 DPS ≡ 30 EHP. |
| 09 | `brOlcegi` | 1,7926 | Dengeye karışmıyor; sayıyı okunur aralığa taşıyor. |
| 10 | `ilkUnvanEsigi` | 3.600 | Merdivenin tabanı; referansın kanal gücü buraya oturtulur, K ondan çözülür. |
| 09 | `sistemTavani` | 25 | Sistem çarpımsal: sınırsız bırakılırsa baskın olur. |
| 09 | `sistemKatsayisiMenzil` | 0,5 | Hem saldırıya hem kaçışa yarıyor. |
| 09 | `sistemKatsayisiHiz` | 0,4 | Yetişmek ve kaçmak. |
| 09 | `sistemKatsayisiItki` | 0,3 | Yalnız kaçışa yarıyor; şarj sayısıyla sınırlı. |
| 09 | `droidDpsPayi` | 0,15 | Referansta droidlerin saldırıya payı; taban hasar bundan türer. |
| 09 | `droidDayaniklilikKatsayisi` | 0,25 | Geometrik ortalamada iki kez sayılmasın: çeyrek, bir değil. |
| 10 | `hedefSure` | 780 | 1,5 sa/gün × 5 gün × 104 hafta. |
| 10 | `unvanSayisi` | 120 | BR aralığı eşit ORANLARLA bölünüyor. |
| 10 | `gelirUssu` | 0,816 | α < 1: her nesil bir öncekinden uzun. |
| 11 | `gorusYaricapi` | 2.600 | FİZİKSEL: 0,6 yakınlaştırmada ekran + kenar payı. |
| 11 | `dunyaEnBoyOrani` | 1,5 | Alan kaç birim kare olduğunu söylüyor, hangi dikdörtgen olduğunu değil. |
| 11 | `bolgeBasinaHarita` | 3 | Üç tehdit biçimi: yalnız yaratık · yaratık + oyuncu · zamanlı tek hedef. |
| 11 | `girisPayi` | 0,75 | İlk bandı yenebileceği ama derine inemeyeceği nokta. |
| 11 | `esZamanliOyuncu` | 8 | Harita boyutunun üç girdisinden biri; cevaplanabilir soru. |
| 11 | `gorusPaylasimi` | 0,5 | 0,5: ikinci oyuncu görüş alanının yarısı kadar uzakta. |
| 11 | `gorusHedefi` | 4 | Üçten az: hedef arıyor. Beşten çok: mayın tarlası. |
| 11 | `pvpNetPrim` | 0,3 | PvP'den kaçınan yavaşlamalı, durmamalı. |
| 11 | `olumMaliyetiDk` | 5 | Dönüş + onarım. Kredi değil ZAMAN — prim saatlik oran. |
| 11 | `pvpOlumSikligi` | 3 | ÖLÇÜLECEK — playtest. Tepe tablodaki tek ölçüm bekleyen satır. |
| 12 | `siradanOldurmeSuresi` | 1 | Sınıf bir orandır: öldürme süresi her bantta sabit. |
| 12 | `gucluOldurmeSuresi` | 5 | Beş kat — girmek bir karar. |
| 12 | `siradanDogusSuresi` | 8 | Çevrimin çoğu bu; ödül hesabının yarısı. |
| 12 | `gucluDogusSuresi` | 20 | İri hedefin sürekli durması onu sıradan yapardı. |
| 12 | `siradanHizOrani` | 0,3 | Kovalayabilir ama yetişemez. |
| 12 | `gucluHizOrani` | 0,15 | Hiç kovalayamaz — kaçmak her zaman mümkün. |
| 12 | `bossHizOrani` | 0,1 | Yerinde duran hedef; grup ona gider. |
| 12 | `siradanMenzilOrani` | 0,5 | Menzil eşit olsaydı mesafe tutmanın anlamı kalmazdı. |
| 12 | `gucluMenzilOrani` | 0,65 | Daha yakın ama hâlâ oyuncunun altında. |
| 12 | `bossMenzilOrani` | 0,8 | En yakın; yine de kaçış mümkün. |
| 12 | `kacisPenceresi` | 120 | Fark etme + itki + menzil dışına çıkma zincirinin tamamı. |
| 12 | `tehditSayisi` | 3 | Tehdit tek yaratıktan değil, üçünü birden çekmekten. |
| 12 | `gucluRiskPrimi` | 1,15 | Saldırgan olmasının karşılığı; sıradanda prim yok. |
| 12 | `bossGrubu` | 3 | Boss bir grup hedefi. |
| 12 | `bossHedefSuresi` | 120 | Üç oyuncu iki dakika. |
| 12 | `bossPrimi` | 3 | Harcanan oyuncu-saatin katı. |
| 12 | `bossGelirPayi` | 0,15 | Kaçırmak yavaşlatmalı, durdurmamalı. |
| 12 | `tabanSaatlikGelir` | 144.000 | Birinci bandın kredi hedefi; ödül bunun bölünmesi. |
| 12 | `novaOdulu` | 1 | ÖLÇEKLENMEZ — NOVA gerçek parayla rekabet ediyor. |
| 07 | `maliyetHacmi` | 2.489 | c₀ — toplam sink. Eğrinin HACİM kolu. |
| 07 | `maliyetSekli` | 1,2293 | b — değer bozulmasını 44,5 kattan 12 kata indiriyor. |
| 07 | `sentezOrani` | 3 | Verim %48: fazla eşyaya değer, kestirme değil. |
| 07 | `basarisizlikSansi` | 0 | KİLİT — kırılma, koruma satma kapısını açar. |
| 13 | `genelOlumSikligi` | 1 | Onarım payı bundan türüyor; PvP sıklığıyla karıştırılmamalı. |
| 13 | `payArti` | 0,6 | Ekonominin ana gideri — etkin %55. |
| 13 | `paySentez` | 0,15 | Fazla eşyayı ranka çeviren ikinci ayak. |
| 13 | `payMagaza` | 0,15 | Yedek parça ve doğrudan alım. |
| 13 | `payBirikim` | 0,1 | Gider değil TAMPON — sıfırsa tek kötü kararın telafisi yok. |
| 07 | `cevirmeKaliteHedefi` | 0,01 | Mükemmel roll dilimi — ortalama yüz deneme. Eşya düşme oranını çözen kaliteHedefi'nden AYRI: birleştirmek düşüşü yirmi kat artırırdı. |
| 14 | `kaliteHedefi` | 0,2 | En iyi %20 roll = ortalama beş deneme; şans buradan türüyor. |
| 14 | `dusmeGuvenligi` | 1,5 | Tam karşılamak medyan oyuncunun ancak yetişmesi demek. |
| 14 | `parcalamaOrani` | 0,15 | Tamamı verilseydi eşya farmı malzeme farmının yerine geçerdi. |
| 14 | `ustRankSansi` | 0,15 | Olay — PRD ile seri kırılıyor. |
| 14 | `altRankSansi` | 0,2 | Hayal kırıklığı değil, parçalanacak malzeme. |
| 14 | `bossEsyaSayisi` | 3 | İki saat bekleyip grup toplamak boşa çıkamaz. |
| 15 | `magazaEsyaSayisi` | 4 | 14'ün ölçtüğü boşluk: ortalama dört yuva eksik kalıyor. |
| 15 | `tabanEsyaRankFarki` | -1 | Mağaza eşyası en kötü drop'tan bile zayıf olmalı. |
| 15 | `baslangicEsyaSayisi` | 2 | Başlangıç kredisi raftan türüyor: bir eşya yalnız düğmeyi, iki eşya ilk seçimi öğretiyor. |
| 15 | `envanterNova` | 2.000 | Kalıcı genişletme; zaman değil alan satılıyor. |
| 15 | `envanterKademe` | 5 | Beş kademe — sonrası envanteri anlamsızlaştırır. |
| 17 | `mermiTabanFiyati` | 7,67 | Ankraj: ×2 ile sürekli farm referans gelirin ~%15'i. |
| 17 | `mermiFiyatUssu` | 1,631 | ×6 birim hasar bedeli ×2'nin iki katı: 1 + ln2 ÷ ln3. |
| 17 | `mermiCarpanTavani` | 6 | MR-6; üstü PvP'yi tek yaylıma indirir. |
| 17 | `sifonCarpani` | 3 | Yalnız kalkana; MR-3 fiyatına yarım hedef. |
| 18 | `roketAraligi` | 6 | Roket bir vuruş, ritim değil; salvo kadans oranıyla büyür. |
| 15 | `dolarSaatDegeri` | 3,3 | IAP kurunun tek girdisi; tavanı değiştirmiyor. |
| 15 | `paketBonusTavani` | 1,6 | ×2 üstü küçük paketleri anlamsızlaştırır. |
| 15 | `odemeOrani` | 0,03 | Hedef — ARPU bununla ARPPU'nun çarpımı. |
| 15 | `hedefARPPU` | 40 | Ödeyen oyuncu başına hedef. |

## Dağılım

| Alan | Ad | Katman | Girdi |
|---|---|---|---:|
| 01 | Savaş Formülü | savas | 7 |
| 02 | Stat Kütüphanesi | savas | 0 |
| 03 | Stat Değeri | savas | 0 |
| 04 | Gemi ve Yuvalar | savas | 11 |
| 05 | Sağlayıcılar | buyume | 7 |
| 06 | Eşya Kurgusu | buyume | 8 |
| 07 | Güçlendirme | buyume | 5 |
| 08 | Güç Bütçesi | buyume | 8 |
| 09 | Savaş Puanı | buyume | 8 |
| 10 | İlerleme ve Unvan | buyume | 4 |
| 11 | Haritalar | dunya | 10 |
| 12 | Düşman Kurgusu | dunya | 19 |
| 13 | Kaynak Akışı | ekonomi | 5 |
| 14 | Ganimet | ekonomi | 6 |
| 15 | Kazanç | ekonomi | 11 |
| 16 | Denge Denetimi | denge | 0 |
| 17 | Mermi | ekonomi | 4 |
| 18 | Roket | ekonomi | 1 |

## Karar döngüleri

| Soran → cevaplayan | Soru | Karar |
|---|---|---|
| 03 → 09 | savunma statları fiyatlandı ama çapa bilinmiyordu | kur türetildi, StatMod'lar savunma çapasıyla ölçeklendi |
| 04 → 08 | gövde havuzu girdi sanıldı | TTK kısıtından türetildi |
| 06 → 07 | artı kazancında belge ↔ kod çelişkisi | üçüncü seçenek: toplamsal kazanç + çözülmüş maliyet eğrisi |
| 13 → 14 | malzeme talebi ilan edildi, arz bilinmiyordu | arz çözüldü — oran her bantta ×1,63 |

## Sistem durumu

Tamamlanma %100,0, sistem oranı %85,4. Eksik: çizilmiş gövde.

| Sistem | Mevcut | Hedef | Alan |
|---|---:|---:|---|
| rank | 20 | 20 | 06 |
| gövde kademesi | 8 | 8 | 04 |
| çizilmiş gövde | 1 | 8 | 04 |
| harita | 24 | 24 | 11 |
| serpilen yaratık | 32 | 32 | 12 |
| tasarlanmış yaratık | 32 | 32 | 12 |

