---
alan: 6
ad: Eşya Tablosu
tur: tablo
kural: 06-esya-kurgusu.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 06 · Eşya Tablosu

Kural belgesi: [06 · Eşya Kurgusu](06-esya-kurgusu.md). Bu dosya koddan üretilir; burada görünen her sayı bugün oyunun yaptığı şeydir, tasarlanan değil. Tasarlananla farkı kural belgesindeki kararların durumu söyler.

## Rank merdiveni

Çarpan `rankArtisi = 1,442` üssü. Kapasite `ItemBudget.altStatSayisi`: aile + 1, 7 ile kesik; kapak taşları tavanda. Kalite bandı üç kademe: `kaliteAltSiniri = 0,7` · `kaliteAltSiniriSS = 0,75` · `kaliteAltSiniriRenk = 0,8`; garantili alt stat bandın tepesinden gelir.

| Rank | Çarpan | Aile | Alt stat kapasitesi | Kalite bandı | Garantili |
|---|---:|---:|---:|---|---:|
| C-I | 1,0 | 0 | 1 | %70–100 | 0 |
| C-II | 1,4 | 0 | 1 | %70–100 | 0 |
| C-III | 2,1 | 0 | 1 | %70–100 | 0 |
| B-I | 3,0 | 1 | 2 | %70–100 | 0 |
| B-II | 4,3 | 1 | 2 | %70–100 | 0 |
| B-III | 6,2 | 1 | 2 | %70–100 | 0 |
| A-I | 9,0 | 2 | 3 | %70–100 | 0 |
| A-II | 13,0 | 2 | 3 | %70–100 | 0 |
| A-III | 18,7 | 2 | 3 | %70–100 | 0 |
| S-I | 27,0 | 3 | 4 | %70–100 | 0 |
| S-II | 38,9 | 3 | 4 | %70–100 | 0 |
| S-III | 56,1 | 3 | 4 | %70–100 | 0 |
| SS-I | 80,8 | 4 | 5 | %75–100 | 1 |
| SS-II | 116,6 | 4 | 5 | %75–100 | 1 |
| SS-III | 168,1 | 4 | 5 | %75–100 | 1 |
| SSS-I | 242,4 | 5 | 6 | %75–100 | 1 |
| SSS-II | 349,5 | 5 | 6 | %75–100 | 1 |
| SSS-III | 504,0 | 5 | 6 | %75–100 | 1 |
| KIRMIZI | 726,7 | 5 | 7 | %80–100 | 2 |
| PARLAYAN PEMBE | 1.047,9 | 5 | 7 | %80–100 | 2 |

## Gerçekleşen derinlik

Bir eşyanın gerçekten taşıdığı alt stat sayısı `min(kapasite, havuz.length)`. Hücre biçimi `havuz→gerçek`; aynı yuvada birden çok tasarım varsa nokta ile ayrılır.

| Rank | Kapasite | Lazer | Jeneratör | Roketatar | CPU |
|---|---:|---|---|---|---|
| C-I | 1 | 7→1 | 7→1 · 7→1 | 6→1 | 7→1 · 7→1 |
| C-II | 1 | 7→1 | 7→1 · 7→1 | 6→1 | 7→1 |
| C-III | 1 | 7→1 | 7→1 | 6→1 | 7→1 |
| B-I | 2 | 7→2 | 7→2 | 6→2 | 7→2 |
| B-II | 2 | 7→2 | 7→2 | 6→2 | 7→2 |
| B-III | 2 | 7→2 | 7→2 | 6→2 | 7→2 |
| A-I | 3 | 7→3 | 7→3 | 6→3 | 7→3 |
| A-II | 3 | 7→3 | 7→3 | 6→3 | 7→3 |
| A-III | 3 | 7→3 | 7→3 | 6→3 | 7→3 |
| S-I | 4 | 7→4 | 7→4 | 6→4 | 7→4 |
| S-II | 4 | 7→4 | 7→4 | 6→4 | 7→4 |
| S-III | 4 | 7→4 | 7→4 | 6→4 | 7→4 |
| SS-I | 5 | 7→5 | 7→5 | 6→5 | 7→5 |
| SS-II | 5 | 7→5 | 7→5 | 6→5 | 7→5 |
| SS-III | 5 | 7→5 | 7→5 | 6→5 | 7→5 |
| SSS-I | 6 | 7→6 | 7→6 | 6→6 | 7→6 |
| SSS-II | 6 | 7→6 | 7→6 | 6→6 | 7→6 |
| SSS-III | 6 | 7→6 | 7→6 | 6→6 | 7→6 |
| KIRMIZI | 7 | 7→7 | 7→7 | 6→6 | 7→7 |
| PARLAYAN PEMBE | 7 | 7→7 | 7→7 | 6→6 | 7→7 |

En geniş havuz 7 stat, en çok gerçekleşen alt stat 7. Kapasite tavanına (7) ulaşan tasarım sayısı: 6.

## Alt stat havuzları

Raftaki tasarımlar elle yazılmış; üst ranklar yuvanın raftaki en iyi tasarımının havuzunu aynen kopyalar (`Catalogue._turet`).

| Tasarım | Yuva | Rank | Ana stat | Havuz |
|---|---|---|---|---|
| `pl1` PL-1 | Lazer | C-I | `taban_hasar` | `hasar_artisi` · `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `son_hasar` · `menzil` · `hiz` |
| `pl3` PL-3 | Lazer | C-II | `taban_hasar` | `hasar_artisi` · `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `son_hasar` · `menzil` · `hiz` |
| `pl4` PL-4 | Lazer | C-III | `taban_hasar` | `hasar_artisi` · `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `son_hasar` · `menzil` · `hiz` |
| `pl5` PL-5 Nova | Lazer | B-I | `taban_hasar` | `hasar_artisi` · `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `son_hasar` · `menzil` · `hiz` |
| `df1` DF-1 Kalkan | Jeneratör | C-I | `kalkan` | `govde_cani` · `kalkan_yenilenmesi` · `zirh` · `kacinma` · `son_azaltma` · `menzil` · `hiz` |
| `df3` DF-3 Kalkan | Jeneratör | C-II | `kalkan` | `govde_cani` · `kalkan_yenilenmesi` · `zirh` · `kacinma` · `son_azaltma` · `menzil` · `hiz` |
| `df5` DF-5 Nova Kalkanı | Jeneratör | B-I | `kalkan` | `govde_cani` · `kalkan_yenilenmesi` · `zirh` · `kacinma` · `son_azaltma` · `menzil` · `hiz` |
| `th1` TH-1 İtki | Jeneratör | C-I | `hiz` | `kalkan` · `govde_cani` · `kalkan_yenilenmesi` · `zirh` · `kacinma` · `son_azaltma` · `menzil` |
| `th3` TH-3 İtki | Jeneratör | C-II | `hiz` | `kalkan` · `govde_cani` · `kalkan_yenilenmesi` · `zirh` · `kacinma` · `son_azaltma` · `menzil` |
| `mk1` MK-1 Fırlatıcı | Roketatar | C-I | `taban_hasar` | `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `son_hasar` · `menzil` · `hiz` |
| `cpu_repair` Tamir Devresi | CPU | C-I | `kalkan_yenilenmesi` | `govde_cani` · `kalkan` · `zirh` · `kacinma` · `son_azaltma` · `menzil` · `hiz` |
| `cpu_scope` Nişan Devresi | CPU | C-I | `menzil` | `atis_hizi` · `kritik_sansi` · `hiz` · `zirh` · `kacinma` · `son_azaltma` · `kalkan_yenilenmesi` |
| `dr1` Delta | Droid | C-I | `hasar_artisi` | `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `govde_cani` · `zirh` · `menzil` |
| `dr5` Hilal | Droid | B-I | `hasar_artisi` | `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `govde_cani` · `zirh` · `menzil` |

Türetilen rankların şablonu, yuva başına:

- Lazer: `hasar_artisi` · `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `son_hasar` · `menzil` · `hiz` (16 rank)
- Jeneratör: `govde_cani` · `kalkan_yenilenmesi` · `zirh` · `kacinma` · `son_azaltma` · `menzil` · `hiz` (17 rank)
- Roketatar: `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `son_hasar` · `menzil` · `hiz` (19 rank)
- CPU: `govde_cani` · `kalkan` · `zirh` · `kacinma` · `son_azaltma` · `menzil` · `hiz` (19 rank)
- Droid: `atis_hizi` · `kritik_sansi` · `kritik_hasari` · `govde_cani` · `zirh` · `menzil` (18 rank)

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `rankSayisi` | 20 | Altı harf ailesi × üç basamak + Kırmızı ve Parlayan Pembe. Tepesi 1,442^19 ≈ 1.048×, iki yıllık hedefin vardığı yer. |
| `rankArtisi` | 1,442 | Ölçüldü: bugünkü beş çarpan zaten bu merdiveni izliyor. |
| `anaStatPayi` | 0,7 | Rank çakışmasına pay bırakıyor: en dar boğaz birin üstünde. |
| `kaliteAltSiniri` | 0,7 | Kalite makası rank atlamasının altında. |
| `kaliteAltSiniriSS` | 0,75 | Üst rank sayı olarak değil güvenilirlik olarak da ayrışır. |
| `kaliteAltSiniriRenk` | 0,8 | Kapak taşı en dar bant; paranın tavanı burada en küçük. |
| `garantiliAltStatSS` | 1 | Renk kalite güvencesi: bir alt stat bandın tepesinden. |
| `garantiliAltStatRenk` | 2 | Kapak taşında iki alt stat mükemmel gelir. |

