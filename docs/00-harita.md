---
alan: 0
ad: Tasarım Alanları Haritası
tur: harita
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# Tasarım Alanları Haritası

Belgelerden ve koddan derlenen izlenebilirlik matrisi. Belge kaynak, kod uygulama; ikisinin arası bu tablo. Kural: [README](README.md). Kodlarken açığa çıkan sorular ve borçlar: [Borç Defteri](borc-defteri.md).

**Kapsama:** 144 karar · kodda 139 · belgede 0 · açık 0 · kaldırıldı 0 · ayrılmış 5 · kod atıfı 458 · test atıfı 575 · sınanmış 139/139 kodda · etiket 132 girdi, 23 türetilen.

## 01 · Savaş Formülü

[Kural](01-savas-formulu.md) · [Tablo](01-savas-sayilari.md) · katman: savas

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 01.1 · Altı katman, sabit sıra | kodda | s1 | `core/combat/damage_chain.dart`, `core/combat/stat_layer.dart` | `core-test/savas_formulu_test.dart` |
| 01.2 · Katmanların ne tür stat aldığı | kodda | s1 | `core/combat/damage_chain.dart`, `core/combat/stat_layer.dart`, `core/design/tasarim_girdileri.dart` | `core-test/savas_formulu_test.dart` |
| 01.3 · Önce kalkan, taşan kısım gövde | kodda | s1 | `core/sim/ship_sim.dart` | `core-test/savas_formulu_test.dart` |
| 01.4 · Kritiğin iki biçimi | kodda | s1 | `core/combat/damage_chain.dart`, `core/design/prd.dart`, `core/design/tasarim_girdileri.dart` | `core-test/savas_formulu_test.dart` |
| 01.5 · Iskalama yok, sıyırma var | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/domain/ship_stats.dart` | `core-test/savas_formulu_test.dart` |
| 01.6 · Genişleme kuralı: katman sayısı artmaz | kodda | s1 | `core/combat/damage_chain.dart` | `core-test/savas_formulu_test.dart` |
| 01.7 · PvE ↔ PvP tek formül, tek katsayı | kodda | s1 | `core/combat/damage_chain.dart`, `server/lib/zone.dart` | `core-test/savas_formulu_test.dart` |
| 01.8 · Sözlük: yaylım · DPS · EHP · TTK | kodda | s1 | `core/combat/combat_glossary.dart` | `core-test/savas_formulu_test.dart` |

## 02 · Stat Kütüphanesi

[Kural](02-stat-kutuphanesi.md) · [Tablo](02-stat-kaydi.md) · katman: savas

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 02.1 · Kimlik ile etiket ayrı; katman ve kanal 01'den | kodda | s1 | `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |
| 02.2 · Kayıt alanları: birim, kapsam, eş, altStat | kodda | s1 | `core/progression/loadout.dart`, `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |
| 02.3 · Kapsam sistemi ve çift sayım savunması | kodda | s2 | `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |
| 02.4 · Giriş şartı: eşi olmayan stat kütüphaneye giremez | kodda | s1 | `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |
| 02.5 · Genişleme şartları | kodda | s1 | `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |
| 02.6 · Ayrılmış kimlikler | kodda | s1 | `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |
| 02.7 · Kayıt tablosu: yirmi iki kimlik | kodda | s2 | `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |
| 02.8 · Kritik çarpanının kimliği | kodda | s3 | `core/progression/stat.dart` | `core-test/stat_kaydi_test.dart` |

## 03 · Stat Değeri

[Kural](03-stat-degeri.md) · [Tablo](03-deger-tablosu.md) · katman: savas

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 03.1 · Değer marjinal katkıdır, zincirden türer | kodda | s2 | `core/progression/budget.dart` | `core-test/stat_degeri_test.dart` |
| 03.2 · Referans noktada ölçme kuralı | kodda | s2 | `core/denetim/pay_olcumu.dart`, `core/design/turetilenler.dart`, `core/progression/budget.dart`, `core/progression/fiyat_cozumu.dart`, `core/progression/referans_cozumu.dart` | `core-test/pay_olcumu_test.dart`, `core-test/progression_test.dart`, `core-test/stat_degeri_test.dart` |
| 03.3 · Kanal içi fiyatlama, kanallar arası kur 09'un | kodda | s1 | `core/design/turetilenler.dart`, `core/progression/budget.dart` | `core-test/stat_degeri_test.dart` |
| 03.4 · StatMod tanımı ve çapa sözleşmesi | kodda | s1 | `core/design/turetilenler.dart`, `core/progression/budget.dart` | `core-test/stat_degeri_test.dart` |
| 03.5 · Değerleme dövüş süresi | kodda | s2 | `core/design/turetilenler.dart` | `core-test/stat_degeri_test.dart` |
| 03.6 · Birim tipine göre uygulama sözleşmesi | kodda | s1 | `core/progression/budget.dart`, `core/progression/loadout.dart`, `core/progression/stat.dart` | `core-test/stat_degeri_test.dart`, `core-test/stat_kaydi_test.dart` |

## 04 · Gemi ve Yuvalar

[Kural](04-gemi-ve-yuvalar.md) · [Tablo](04-govde-tablosu.md) · katman: savas

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 04.1 · Gemi üç şey verir: taban stat, yuva sayısı, yuva çeşidi | kodda | s1 | `core/progression/hull.dart` | `core-test/gemi_yuvalari_test.dart` |
| 04.2 · Yuva haritası ve yuva↔eşya eşleşmesi | kodda | s1 | `core/progression/hangar.dart`, `core/progression/hull.dart` | `core-test/gemi_yuvalari_test.dart` |
| 04.3 · Jeneratör ikilemi: kalkan ya da hız | kodda | s1 | `core/progression/item.dart` | `core-test/gemi_yuvalari_test.dart` |
| 04.4 · Hız jeneratörü kaçınma da verir | kodda | s1 | `core/progression/catalogue.dart` | `core-test/hiz_jeneratoru_test.dart` |
| 04.5 · Referans build bileşimi | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/domain/ship_stats.dart`, `core/progression/referans_cozumu.dart` | `core-test/referans_cozumu_test.dart` |
| 04.6 · Referans zırh ve kaçınma toplamları | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart` | `core-test/gemi_yuvalari_test.dart` |
| 04.7 · Gövde statları merdivenden türer | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/progression/hull.dart` | `core-test/gemi_yuvalari_test.dart` |
| 04.8 · Yuva merdiveni kesikli, kademe başına bir yuva | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/hull.dart` | `core-test/gemi_yuvalari_test.dart` |
| 04.9 · Sanat kısıtı: lazer yuvası = çizimdeki namlu | kodda | s2 | `lib/game/art/atlas_layout.dart`, `core/design/tasarim_girdileri.dart`, `core/progression/hull.dart` | `core-test/gemi_yuvalari_test.dart`, `test/sanat_kisiti_test.dart` |
| 04.10 · Droid filosu gövdeden bağımsız | kodda | s3 | `lib/net/hangar_view.dart`, `core/design/tasarim_girdileri.dart`, `core/progression/arge.dart`, `core/progression/hangar.dart` | `core-test/arge_test.dart`, `core-test/droid_test.dart`, `server/test/arge_test.dart`, `test/arge_ekrani_test.dart`, `test/hangar_test.dart` |
| 04.11 · Roketatar her gövdede tam bir yuva | kodda | s1 | `core/progression/hull.dart` | `core-test/gemi_yuvalari_test.dart` |
| 04.12 · Merdiven çizilmiş gövdeleri açıklar | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/progression/hull.dart` | `core-test/gemi_yuvalari_test.dart` |

## 05 · Sağlayıcılar

[Kural](05-saglayicilar.md) · katman: buyume

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 05.1 · İki sağlayıcı tipi, davranış ayrılmış | kodda | s1 | `core/domain/droid_grubu.dart` | `test/droid_atesi_test.dart` |
| 05.2 · Sağlayıcı kaydı | kodda | s1 | `core/progression/saglayici.dart` | `core-test/droid_test.dart` |
| 05.3 · Kapsam kuralları ve sızıntı yasağı | kodda | s1 | `core/progression/loadout.dart` | `core-test/saglayici_kapsami_test.dart` |
| 05.4 · Yuva → kapsam eşlemesi; droid bir TAŞIYICI | kodda | s5 | `core/denetim/elit_droid_olcumu.dart`, `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/progression/budget.dart`, `core/progression/catalogue.dart`, `core/progression/hangar.dart`, `core/progression/loadout.dart`, `core/progression/saglayici.dart` | `core-test/droid_test.dart`, `core-test/elit_droid_olcumu_test.dart`, `server/test/droid_donanimi_test.dart`, `test/droid_donanimi_test.dart` |
| 05.5 · Aktarım katsayısı σ ve biçimi | kodda | s3 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/domain/droid_grubu.dart`, `core/progression/loadout.dart` | `core-test/arge_test.dart`, `core-test/droid_test.dart` |
| 05.6 · Unvan stat vermez | kodda | s1 | `core/combat/combat_glossary.dart` | `core-test/saglayici_kapsami_test.dart` |
| 05.7 · ArGe yeni stat icat etmez; güç değil YÖN veriyor | kodda | s2 | `lib/hangar/arge_karti.dart`, `lib/net/hangar_view.dart`, `core/design/tasarim_girdileri.dart`, `core/progression/arge.dart`, `core/progression/hangar.dart` | `core-test/arge_test.dart`, `server/test/arge_test.dart`, `test/arge_ekrani_test.dart` |
| 05.8 · Droid seviyesi altı kademe, çeşit iki, tasarım on | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/progression/catalogue.dart`, `core/progression/hangar.dart`, `core/progression/item.dart`, `core/progression/saglayici.dart` | `core-test/droid_test.dart`, `test/dil_test.dart`, `test/droid_ikonu_test.dart` |
| 05.9 · Formasyon: tek aktif, imzalı takas | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/formasyon.dart`, `core/progression/hangar.dart`, `core/progression/loadout.dart` | `core-test/droid_test.dart`, `test/savas_cubugu_test.dart` |
| 05.10 · Droidin canı yok, dayanıklılığı var | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/progression/hangar.dart`, `core/progression/item.dart` | `core-test/droid_dayanikligi_test.dart`, `server/test/droid_dayanikligi_test.dart`, `test/droid_dayanikligi_test.dart` |

## 06 · Eşya Kurgusu

[Kural](06-esya-kurgusu.md) · [Tablo](06-esya-tablosu.md) · katman: buyume

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 06.1 · Rank ekseni belirlenimci, yirmi basamak | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/item.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.2 · Kalite ekseni rastgele, örneğe özgü | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/budget.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.3 · Tasarım, örnek ve malzeme ayrı şemalar | kodda | s1 | `core/progression/item.dart`, `core/progression/malzeme.dart` | `core-test/esya_kurgusu_test.dart`, `core-test/malzeme_test.dart` |
| 06.4 · Yükseltme malzemesi ile çevirici ayrı kaynak | kodda | s1 | `core/progression/malzeme.dart` | `core-test/esya_kurgusu_test.dart`, `core-test/malzeme_test.dart` |
| 06.5 · Ana stat belirlenimci, alt statlar rastgele | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/budget.dart`, `tool/belge/kararlar.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.6 · Rank çakışmaz | kodda | s2 | `core/design/tasarim_girdileri.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.7 · Alt stat havuzu yuva tipine göre kısıtlı ve fiyatlı | kodda | s1 | `core/progression/budget.dart`, `core/progression/catalogue.dart`, `core/progression/item.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.8 · Havuz içerikleri | kodda | s2 | `core/progression/catalogue.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.9 · Alt stat sayısı her aileyle bir artıyor | kodda | s2 | `core/progression/budget.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.10 · Kalite bandı rankla daralıyor, garantili alt stat | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/progression/budget.dart` | `core-test/esya_kurgusu_test.dart` |
| 06.11 · Set bonusu ayrılmış | ayrılmış | s1 | — | — |

## 07 · Güçlendirme

[Kural](07-guclendirme.md) · [Tablo](07-guclendirme-tablosu.md) · katman: buyume

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 07.1 · Üç modül: artı basma, sentez, çevirme | kodda | s1 | `core/progression/hangar.dart` | `core-test/guclendirme_modulleri_test.dart` |
| 07.2 · Başarısızlık ve kırılma yasağı | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/yukseltme.dart` | `core-test/cevirme_test.dart`, `core-test/sentez_test.dart`, `core-test/yukseltme_test.dart` |
| 07.3 · Artı merdiveni ve kazanç biçimi | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/item.dart` | `core-test/yukseltme_test.dart` |
| 07.4 · Maliyetin şekil ↔ hacim ayrımı | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/item.dart` | `core-test/yukseltme_test.dart` |
| 07.5 · Çevirme hepsini çevirir, kilit korur | kodda | s2 | `core/progression/hangar.dart`, `core/progression/item.dart`, `core/progression/yukseltme.dart` | `core-test/cevirme_test.dart`, `core-test/guclenme_test.dart`, `core-test/yukseltme_test.dart` |
| 07.6 · Artı basmada güçlenen alt stat rastgele, miktar sabit | kodda | s1 | `core/progression/budget.dart`, `core/progression/item.dart` | `core-test/guclenme_test.dart`, `core-test/yukseltme_test.dart` |
| 07.7 · Sentez oranı ve kaybı | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/yukseltme.dart` | `core-test/sentez_test.dart`, `core-test/yukseltme_test.dart` |
| 07.8 · Çevirme kaynağı ve nadirliği | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/progression/yukseltme.dart` | `core-test/cevirme_test.dart`, `core-test/yukseltme_test.dart` |
| 07.9 · Malzemenin rank kapısı rolü | kodda | s1 | `core/progression/catalogue.dart`, `core/progression/yukseltme.dart` | `core-test/cevirme_test.dart`, `core-test/sentez_test.dart` |
| 07.10 · Soket ayrılmış | ayrılmış | s1 | — | — |

## 08 · Güç Bütçesi

[Kural](08-guc-butcesi.md) · [Tablo](08-pay-tablosu.md) · katman: buyume

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 08.1 · Payı ilan et, katsayıyı türet | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/budget.dart` | `core-test/droid_test.dart` |
| 08.2 · Katsayı gövdeye bağlı | kodda | s2 | `core/progression/budget.dart` | `core-test/guc_butcesi_test.dart` |
| 08.3 · Marjinal fiyatlar toplanmaz; 08 dağıtır, 16 ölçer | kodda | s2 | `core/denetim/pay_olcumu.dart`, `core/design/tasarim_girdileri.dart` | `core-test/pay_olcumu_test.dart` |
| 08.4 · A = D, puanlarda değil gerçekleşende | kodda | s1 | `core/combat/combat_glossary.dart`, `core/design/turetilenler.dart` | `core-test/guc_butcesi_test.dart` |
| 08.5 · Gövde havuzu TTK'dan çözülür | kodda | s2 | `core/design/turetilenler.dart`, `core/progression/hull.dart`, `core/progression/referans_cozumu.dart` | `core-test/referans_cozumu_test.dart` |
| 08.6 · Gövde ↔ eşya kolu | kodda | s1 | `core/progression/referans_cozumu.dart` | `core-test/referans_cozumu_test.dart` |

## 09 · Savaş Puanı

[Kural](09-savas-puani.md) · [Tablo](09-br-tablosu.md) · katman: buyume

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 09.1 · BR geometrik ortalama | kodda | s1 | `core/combat/combat_glossary.dart` | `core-test/savas_puani_test.dart` |
| 09.2 · Kanallar arası kur = referans TTK | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart` | `core-test/savas_puani_test.dart` |
| 09.3 · A = D kısıtının anlamı | kodda | s1 | `core/combat/combat_glossary.dart` | `core-test/savas_puani_test.dart` |
| 09.4 · Savunma çapası ve ölçekleme | kodda | s1 | `core/design/turetilenler.dart`, `core/progression/budget.dart` | `core-test/savas_puani_test.dart` |
| 09.5 · Sistem kanalı değerleri ve tavanı | kodda | s1 | `core/combat/combat_glossary.dart`, `core/design/tasarim_girdileri.dart`, `core/domain/ship_stats.dart`, `core/progression/loadout.dart` | `core-test/sistem_kanali_test.dart` |
| 09.6 · Droid'in iki katsayısı | kodda | s1 | `core/combat/combat_glossary.dart`, `core/design/tasarim_girdileri.dart` | `core-test/droid_test.dart` |
| 09.7 · Ölçek sabiti K | kodda | s1 | `core/combat/combat_glossary.dart`, `core/design/tasarim_girdileri.dart` | `core-test/referans_cozumu_test.dart` |

## 10 · İlerleme ve Unvan

[Kural](10-ilerleme-ve-unvan.md) · [Tablo](10-merdiven-olcegi.md) · katman: buyume

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 10.1 · Seviye ↔ BR ayrımı | kodda | s1 | `lib/hangar/unvan_satiri.dart`, `core/progression/hangar.dart`, `core/progression/seviye.dart` | `test/arge_ekrani_test.dart`, `test/unvan_gosterimi_test.dart` |
| 10.2 · Rank merdiveni ve renk kapakları | kodda | s1 | `core/progression/item.dart` | `core-test/ilerleme_test.dart` |
| 10.3 · Unvan eşikleri: yüz yirmi basamak, eşit oranlı | kodda | s1 | `core/combat/combat_glossary.dart`, `core/design/tasarim_girdileri.dart` | `core-test/bolge_test.dart`, `core-test/ilerleme_test.dart` |
| 10.4 · Unvan isimleri, çağlar ve görsel kimlik | kodda | s2 | `lib/hangar/unvan_satiri.dart`, `core/progression/unvan.dart` | `core-test/unvan_test.dart`, `test/unvan_amblemi_test.dart`, `test/unvan_gosterimi_test.dart` |
| 10.5 · Gelir ölçekleme üssü α | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/design/turetilen_tablolar.dart` | `core-test/ilerleme_test.dart` |
| 10.6 · Referans build fonksiyonu | kodda | s2 | `core/progression/referans_build.dart`, `core/progression/referans_cozumu.dart` | `core-test/referans_cozumu_test.dart` |
| 10.7 · Sistem açılış sırası | kodda | s1 | `core/progression/acilis.dart`, `core/progression/catalogue.dart`, `core/progression/hangar.dart` | `core-test/droid_test.dart`, `core-test/magaza_rafi_test.dart`, `server/test/raf_test.dart` |
| 10.8 · Günlük tavan ve yorgunluk | kodda | s1 | `core/progression/fatigue.dart` | `core-test/fatigue_test.dart` |

## 11 · Haritalar

[Kural](11-haritalar.md) · [Tablo](11-bolge-tablosu.md) · katman: dunya

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 11.1 · Bölge = gövde kademesi; her bölgede üç harita | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/world/bolge.dart`, `core/world/gecit.dart` | `core-test/bolge_test.dart` |
| 11.2 · Bant yapısı ve bant başına gelir | kodda | s1 | `core/world/bolge.dart` | `core-test/bolge_test.dart`, `server/test/gecit_test.dart` |
| 11.3 · Kapı savaş puanı: referansın dörtte üçü | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/world/bolge.dart` | `core-test/bolge_test.dart` |
| 11.4 · Seviye ikincil kapı | kodda | s1 | `core/world/bolge.dart` | `core-test/seviye_test.dart` |
| 11.5 · Harita boyutu ve yoğunluk türetilir | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/domain/world.dart` | `core-test/bolge_test.dart` |
| 11.6 · PvP primi hesaplanabilir | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart` | `core-test/bolge_test.dart` |

## 12 · Düşman Kurgusu

[Kural](12-dusman-kurgusu.md) · [Tablo](12-dusman-tablosu.md) · katman: dunya

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 12.1 · Üç sınıf, üç rol | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/world/dusman.dart` | `core-test/dusman_test.dart` |
| 12.2 · Can bir süredir | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/world/dusman.dart` | `core-test/dusman_test.dart` |
| 12.3 · Ödül bir hızdır | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/world/dusman.dart` | `core-test/dusman_test.dart` |
| 12.4 · Hasar bir kaçış penceresidir | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilen_tablolar.dart`, `core/world/dusman.dart` | `core-test/dusman_test.dart` |
| 12.5 · Boss: iki saatte bir, her bantta | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilen_tablolar.dart`, `core/world/dusman.dart`, `server/lib/harita_kaydi.dart` | `core-test/dusman_test.dart` |
| 12.6 · NOVA ölçeklenmez | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/world/dusman.dart` | `core-test/dusman_test.dart` |
| 12.7 · Kadro: otuz iki yaratık, sekiz bölge | kodda | s1 | `core/world/yaratik_kadrosu.dart` | `core-test/dusman_test.dart` |

## 13 · Kaynak Akışı

[Kural](13-kaynak-akisi.md) · [Tablo](13-akis-tablosu.md) · katman: ekonomi

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 13.1 · Üç kaynak, üç davranış | kodda | s1 | `core/progression/kaynak_akisi.dart` | `core-test/kaynak_akisi_test.dart` |
| 13.2 · Dönüşüm yasağı | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/kaynak_akisi.dart` | `core-test/ganimet_cekilisi_test.dart`, `core-test/kaynak_akisi_test.dart` |
| 13.3 · Onarım türetiliyor, gerisi bölünüyor | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/kaynak_akisi.dart` | `core-test/kaynak_akisi_test.dart` |
| 13.4 · Yorgunluk eşiği ölçekleniyor | kodda | s1 | `core/progression/fatigue.dart` | `core-test/kaynak_akisi_test.dart` |
| 13.5 · Birikim tamponu | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/kaynak_akisi.dart` | `core-test/kaynak_akisi_test.dart` |
| 13.6 · +15 nesil içinde ulaşılamaz; endgame kuyruğu | kodda | s2 | `core/progression/kaynak_akisi.dart` | `core-test/filo_kalemi_test.dart` |
| 13.7 · Paralel ekonomi: pazar yok | ayrılmış | s1 | — | — |

## 14 · Ganimet

[Kural](14-ganimet.md) · [Tablo](14-ganimet-tablosu.md) · katman: ekonomi

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 14.1 · Üç düşen, üç ritim | kodda | s1 | `lib/hud/reward_feed.dart`, `core/net/messages.dart`, `core/progression/ganimet_cekilisi.dart`, `server/lib/gateway.dart` | `core-test/codec_test.dart`, `server/test/ganimet_test.dart`, `test/ganimet_bildirimi_test.dart` |
| 14.2 · Malzeme kuru: bir öldürme, bir malzeme | kodda | s1 | `core/progression/ganimet.dart` | `core-test/ganimet_test.dart` |
| 14.3 · Düşme şansı birinci banttan türer | kodda | s2 | `core/design/tasarim_girdileri.dart`, `core/progression/ganimet.dart` | `core-test/filo_kalemi_test.dart` |
| 14.4 · Rank dağılımı ve PRD yalnız üst rankta | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/ganimet.dart` | `core-test/ganimet_cekilisi_test.dart`, `core-test/ganimet_test.dart` |
| 14.5 · Parçalama: eşyanın ikinci hayatı | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/ganimet.dart`, `core/progression/ganimet_cekilisi.dart` | `core-test/ganimet_cekilisi_test.dart`, `core-test/ganimet_test.dart` |
| 14.6 · Boss ganimeti garantili | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/ganimet.dart` | `core-test/ganimet_cekilisi_test.dart`, `core-test/ganimet_test.dart` |

## 15 · Kazanç

[Kural](15-kazanc.md) · [Tablo](15-kazanc-tablosu.md) · katman: ekonomi

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 15.1 · Önce ne satılamayacağı | kodda | s3 | `core/design/tasarim_girdileri.dart`, `core/progression/kazanc.dart` | `core-test/gorunus_test.dart`, `core-test/kazanc_test.dart`, `core-test/nova_rafi_test.dart` |
| 15.2 · Kredi mağazası: taban eşya | kodda | s1 | `core/denetim/elit_droid_olcumu.dart`, `core/design/tasarim_girdileri.dart`, `core/progression/catalogue.dart`, `core/progression/hangar.dart`, `core/progression/kazanc.dart`, `core/progression/loadout.dart`, `server/lib/gateway.dart` | `core-test/magaza_rafi_test.dart`, `server/test/raf_test.dart` |
| 15.8 · Başlangıç kredisi raftan türüyor | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/hangar.dart`, `core/progression/kazanc.dart` | `core-test/magaza_rafi_test.dart` |
| 15.3 · NOVA mağazası: zaman satar | kodda | s3 | `core/design/tasarim_girdileri.dart`, `core/progression/ganimet.dart`, `core/progression/hangar.dart`, `core/progression/kazanc.dart` | `core-test/droid_dayanikligi_test.dart`, `server/test/droid_dayanikligi_test.dart`, `test/droid_dayanikligi_test.dart` |
| 15.7 · NOVA rafı: üç taban tasarım, bir kademe üstte | kodda | s1 | `core/denetim/elit_droid_olcumu.dart`, `core/design/tasarim_girdileri.dart`, `core/progression/catalogue.dart`, `core/progression/hangar.dart`, `core/progression/kazanc.dart` | `core-test/elit_droid_olcumu_test.dart`, `core-test/nova_rafi_test.dart`, `server/test/nova_rafi_test.dart` |
| 15.9 · Görünüş satılır: tasarım ve formasyon | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/hangar.dart`, `core/progression/item.dart`, `core/progression/kazanc.dart` | `core-test/gorunus_test.dart` |
| 15.4 · Paranın tavanı ölçülür | kodda | s1 | `core/progression/kazanc.dart` | `core-test/elit_droid_olcumu_test.dart`, `core-test/kazanc_test.dart` |
| 15.5 · Paketler ve bonus eğrisi | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/kazanc.dart` | `core-test/kazanc_test.dart` |
| 15.6 · Ödeme oranı ve ARPPU hedefi | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/kazanc.dart` | `core-test/kazanc_test.dart` |

## 16 · Denge Denetimi

[Kural](16-denge-denetimi.md) · [Tablo](16-tepe-tablo.md) · katman: denge

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 16.1 · Beş test türü | kodda | s1 | `core/denetim/test_turu.dart`, `tool/belge/kararlar.dart` | `core-test/denge_denetimi_test.dart` |
| 16.2 · Karar döngüleri kapalı | kodda | s1 | `core/denetim/denge_denetimi.dart` | `core-test/denge_denetimi_test.dart` |
| 16.3 · Tek tepe tablo: dışında elle sayı yok | kodda | s1 | `core/denetim/denge_denetimi.dart`, `core/design/tasarim_girdileri.dart` | `core-test/denge_denetimi_test.dart`, `test/tasarim_mimarisi_test.dart` |
| 16.4 · Sayı borçları ve eksik sistemler derlenir | kodda | s1 | `core/denetim/denge_denetimi.dart` | `core-test/denge_denetimi_test.dart` |
| 16.5 · Yeni alan ekleme adımları | ayrılmış | s1 | — | — |
| 16.6 · Denetim tutarlılık ölçer, doğruluk değil | ayrılmış | s1 | — | — |
| 16.7 · Türetilen sayılar da etiketle doğrulanır | kodda | s1 | `core/denetim/turetilen_kaydi.dart` | `core-test/turetilen_kaydi_test.dart`, `test/belge_test.dart` |
| 16.8 · Kodda demek sınanmış demek | kodda | s1 | `tool/belge/kararlar.dart` | `test/belge_test.dart` |
| 16.9 · Borç defteri ve yan belgeler denetimde | kodda | s1 | `tool/belge/kararlar.dart` | `test/belge_test.dart` |

## 17 · Mermi

[Kural](17-mermi.md) · [Tablo](17-mermi-tablosu.md) · katman: ekonomi

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 17.1 · Mermi PvE'de değil PvP'de belirleyici | kodda | s1 | `core/design/turetilenler.dart` | `core-test/mermi_test.dart` |
| 17.2 · MR-1 bedava ve sınırsız | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/progression/hangar.dart`, `core/progression/mermi.dart` | `core-test/mermi_test.dart`, `server/test/mermi_test.dart`, `test/hangar_test.dart` |
| 17.3 · Çarpan yalnız taban hasarı çarpar | kodda | s1 | `server/lib/zone.dart` | `server/test/mermi_test.dart` |
| 17.4 · Fiyat eğrisi iki ankrajdan geçer | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/design/turetilenler.dart`, `core/progression/mermi.dart` | `core-test/mermi_test.dart` |
| 17.5 · Tavan çarpan PvP primini yer | kodda | s1 | `core/progression/mermi.dart` | `core-test/mermi_test.dart` |
| 17.6 · Sifon yalnız kalkana | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/mermi.dart`, `core/sim/ship_sim.dart`, `server/lib/zone.dart` | `core-test/mermi_test.dart`, `server/test/mermi_test.dart` |
| 17.7 · Mermi NOVA ile satılmaz, BR saymaz | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/hangar.dart`, `core/progression/mermi.dart` | `core-test/mermi_test.dart` |
| 17.8 · Birim namlu atışı, stok hesapta | kodda | s1 | `core/progression/hangar.dart`, `server/lib/gateway.dart` | `core-test/mermi_test.dart`, `server/test/mermi_test.dart`, `test/savas_cubugu_test.dart` |

## 18 · Roket

[Kural](18-roket.md) · [Tablo](18-roket-tablosu.md) · katman: ekonomi

| Karar | Durum | Sürüm | Kod | Test |
|---|---|---|---|---|
| 18.1 · Roketatar bir silah, kadans oranıyla | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/loadout.dart` | `core-test/roket_test.dart` |
| 18.2 · Roket zinciri geminin, tabanı roketin | kodda | s1 | `core/combat/combat_glossary.dart`, `server/lib/zone.dart` | `core-test/roket_test.dart`, `server/test/roket_test.dart` |
| 18.3 · Roket mermisi: RK-1 bedava, üstü mermi eğrisiyle | kodda | s1 | `core/design/tasarim_girdileri.dart`, `core/progression/hangar.dart`, `core/progression/roket.dart` | `core-test/roket_test.dart`, `server/test/roket_test.dart` |
| 18.4 · Stok hesapta, seçim savaş çubuğunda | kodda | s1 | `core/progression/hangar.dart` | `core-test/roket_test.dart`, `server/test/roket_test.dart`, `test/savas_cubugu_test.dart` |
| 18.5 · Roket NOVA ile satılmaz, mermisi BR saymaz | kodda | s1 | `core/combat/combat_glossary.dart`, `core/progression/roket.dart` | `core-test/roket_test.dart` |
| 18.6 · Ayrı atış olayı, ayrı çizim | kodda | s1 | `lib/game/components/combat_layer.dart`, `core/net/messages.dart`, `server/lib/zone.dart` | `core-test/roket_test.dart`, `test/roket_cizimi_test.dart` |

## Kodlanacaklar

Belgedeki her karar kodda.


## Sınanmamış

Kodda olan her kararı en az bir test anıyor (16.8).


## Borç defteri

[Defter](borc-defteri.md): 43 madde, 13 açık ya da izleniyor. Her madde bir karara ya da alana bağlı; denetim bağı sınıyor (16.9).

- **B2 · Artı basma adımının miktarı** — izleniyor · 07.6
- **B4 · Ayrılmış yedi statın yerleşimi** — açık · 02.6 · 02.7
- **B5 · Sistem kanalı savaş puanında** — izleniyor · 09.5 · 09.7
- **B6 · Gövde çapası türetiminin dalgası** — izleniyor · 08.5
- **B7 · "Ayrılmış" durumu süreç kurallarını da taşıyor** — açık · 16.5 · 16.6
- **B11 · Unvan adlarının on ikisi ilk yerleşim** — açık · 10.4
- **B23 · Filo bakımı NOVA musluğunun dörtte biri** — izleniyor · 05.10 · 15.3
- **B25 · Elit droid parayla güç mü satıyor** — açık · 15.7 · 15.1 · 05.8
- **B31 · Filonun ölçülen DPS payı ilan edilenin üstünde** — açık · 05.4 · 05.5 · 09.6
- **B32 · ArGe ham güç vermiyor; verecekse 08 yeniden bölünür** — açık · 05.7 · 08.1
- **B34 · Yaratık, gövde ve unvan adları çevrilmedi** — açık · 12.7 · 04.12 · 10.4
- **B35 · Gövde tasarım notları Türkçe ve çevrilmiyor** — açık · 04.12 · 04.9
- **B43 · Droid tasarımı stat vermiyor** — açık · 05.8 · 15.9

## Dışarıda bekleyen

`docs/` dışında yazılmış, henüz taşınmamış tasarımlar (16.9). Kodlanacaklar listesine girmezler: önce belge açılır.

- **Kademe Normalizasyonu** — https://claude.ai/code/artifact/aff2df17-17e4-4a0c-90ed-f9f12f137808

## Test türleri

Alan 16'nın beş türü (16.1). Her test dosyası türünü başında ilan ediyor; bir dosya birden çok tür taşıyabilir. 138 test dosyası, 79 tanesi denetim dışı.

| Tür | Dosya |
|---|---:|
| Yabancı anahtar | 9 |
| Aralık | 31 |
| Türetme | 33 |
| Kapsam | 26 |
| Kod ↔ belge | 15 |

## Ayrılmışlar

Bilerek kodsuz: ileriye yer ayıran şemalar ve süreç kuralları. Kodlanacak iş değil; sistem geldiğinde önce belge açılır.

- **06.11 · Set bonusu ayrılmış** — eşya kaydında set alanı yok
- **07.10 · Soket ayrılmış** — şema yok
- **13.7 · Paralel ekonomi: pazar yok** — takas ve pazar yok; eklenirse önce bu belge
- **16.5 · Yeni alan ekleme adımları** — süreç kuralı
- **16.6 · Denetim tutarlılık ölçer, doğruluk değil** — sınır ilanı

