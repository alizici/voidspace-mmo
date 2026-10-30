---
alan: 7
ad: Güçlendirme Tablosu
tur: tablo
kural: 07-guclendirme.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 07 · Güçlendirme Tablosu

Kural belgesi: [07 · Güçlendirme](07-guclendirme.md). Koddan üretilir; bugün oyunun yaptığı şey.

## Artı merdiveni · C-I

Kazanç biçimi `toplamsal`; maliyet `maliyetHacmi = 2.489` × rank çarpanı × `maliyetSekli = 1,2293` ^ seviye. Kredi/kat = maliyet ÷ kazanç adımı; değer eğrisi bu sütundan okunur.

| Seviye | Kazanç adımı | Çarpan | Maliyet | Kümülatif | Kredi/kat |
|---:|---:|---:|---:|---:|---:|
| +1 | +%8 | 1,08 | 2.489 | 2.489 | 31.113 |
| +2 | +%8 | 1,16 | 3.060 | 5.549 | 38.250 |
| +3 | +%8 | 1,24 | 3.761 | 9.310 | 47.013 |
| +4 | +%8 | 1,32 | 4.624 | 13.934 | 57.800 |
| +5 | +%8 | 1,40 | 5.684 | 19.618 | 71.050 |
| +6 | +%10 | 1,50 | 6.987 | 26.605 | 69.870 |
| +7 | +%10 | 1,60 | 8.590 | 35.195 | 85.900 |
| +8 | +%10 | 1,70 | 10.559 | 45.754 | 105.590 |
| +9 | +%10 | 1,80 | 12.980 | 58.734 | 129.800 |
| +10 | +%10 | 1,90 | 15.957 | 74.691 | 159.570 |
| +11 | +%12 | 2,02 | 19.616 | 94.307 | 163.467 |
| +12 | +%12 | 2,14 | 24.114 | 118.421 | 200.950 |
| +13 | +%12 | 2,26 | 29.643 | 148.064 | 247.025 |
| +14 | +%12 | 2,38 | 36.440 | 184.504 | 303.667 |
| +15 | +%12 | 2,50 | 44.796 | 229.300 | 373.300 |

Değer bozulması (son ÷ ilk kredi/kat): **12,0 kat**. +15 çarpanı 2,50×.

## Alt stat güçlenmesi

Seviye +3 · +6 · +9 · +12 · +15: bir alt stat güçlenir. Hangisi örneğin kimliğinden, saklanmıyor; miktar sabit: her adım alt stat bütçesinin 5 adımda tam bir payını tamamlayacak kadar, tek stata. Havuz genişledikçe tek statın sıçraması büyür, toplam değişmez.

| Alt stat sayısı | Ranklar | Adım başına tek stata |
|---:|---|---:|
| 1 | C-I … C-III | +%20 |
| 2 | B-I … B-III | +%40 |
| 3 | A-I … A-III | +%60 |
| 4 | S-I … S-III | +%80 |
| 5 | SS-I … SS-III | +%100 |
| 6 | SSS-I … SSS-III | +%120 |
| 7 | KIRMIZI … PARLAYAN PEMBE | +%140 |

## Rank başına +15

Kredi rank çarpanıyla ölçekleniyor; malzeme kredinin malzeme değerine bölümü, yukarı yuvarlı (`Yukseltme.malzemeMaliyeti`).

| Rank | Toplam kredi | Toplam malzeme |
|---|---:|---:|
| C-I | 229.300 | 644 |
| C-II | 330.649 | 690 |
| C-III | 476.795 | 736 |
| B-I | 687.538 | 786 |
| B-II | 991.430 | 842 |
| B-III | 1.429.646 | 900 |
| A-I | 2.061.547 | 962 |
| A-II | 2.972.751 | 1.029 |
| A-III | 4.286.707 | 1.099 |
| S-I | 6.181.432 | 1.174 |
| S-II | 8.913.625 | 1.256 |
| S-III | 12.853.449 | 1.343 |
| SS-I | 18.534.673 | 1.437 |
| SS-II | 26.726.998 | 1.535 |
| SS-III | 38.540.331 | 1.640 |
| SSS-I | 55.575.157 | 1.756 |
| SSS-II | 80.139.375 | 1.879 |
| SSS-III | 115.560.982 | 2.008 |
| KIRMIZI | 166.638.936 | 2.151 |
| PARLAYAN PEMBE | 240.293.344 | 2.296 |

## Sentez

`sentezOrani = 3`; verim rank çarpanı ÷ oran = **%48,1**. Ufuk 3 kademe (30 eşyanın altında kalan son kademe).

| Kademe yukarı | Gereken eşya |
|---:|---:|
| 1 | 3 |
| 2 | 9 |
| 3 | 27 |
| 4 | 81 |

Oran seçenekleri, verim = rank çarpanı ÷ oran:

| Oran | Verim |
|---:|---:|
| 2 → 1 | %72,1 |
| 3 → 1 | %48,1 ◀ seçili |
| 4 → 1 | %36,0 |
| 5 → 1 | %28,8 |

## Çevirme

Kredi almaz. Bir çevirme kilitli olmayan bütün alt statları çevirir; bedel = stat başına (aile + 1) × stat sayısı × (1 + kilit). Mükemmel roll `cevirmeKaliteHedefi = 0,01` dilimi, stat başına beklenen 100 deneme; yuva başına beklenen çevirici açgözlü kilitle.

| Rank | Stat başına | Alt stat | Bedel · 0 kilit | 3 kilit | n−1 kilit | Yuva başına beklenen çevirici | Nesilde yuva | Nesilde gereken |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C-I | 1 | 1 | 1 | — | 1 | 100 | 12 | 1.200 |
| C-II | 1 | 1 | 1 | — | 1 | 100 | 12 | 1.200 |
| C-III | 1 | 1 | 1 | — | 1 | 100 | 16 | 1.600 |
| B-I | 2 | 2 | 4 | — | 8 | 1.000 | 16 | 16.000 |
| B-II | 2 | 2 | 4 | — | 8 | 1.000 | 16 | 16.000 |
| B-III | 2 | 2 | 4 | — | 8 | 1.000 | 18 | 18.000 |
| A-I | 3 | 3 | 9 | — | 27 | 3.900 | 18 | 70.200 |
| A-II | 3 | 3 | 9 | — | 27 | 3.900 | 19 | 74.100 |
| A-III | 3 | 3 | 9 | — | 27 | 3.900 | 19 | 74.100 |
| S-I | 4 | 4 | 16 | 64 | 64 | 10.267 | 19 | 195.067 |
| S-II | 4 | 4 | 16 | 64 | 64 | 10.267 | 20 | 205.333 |
| S-III | 4 | 4 | 16 | 64 | 64 | 10.267 | 20 | 205.333 |
| SS-I | 5 | 5 | 25 | 100 | 125 | 21.750 | 21 | 456.750 |
| SS-II | 5 | 5 | 25 | 100 | 125 | 21.750 | 21 | 456.750 |
| SS-III | 5 | 5 | 25 | 100 | 125 | 21.750 | 21 | 456.750 |
| SSS-I | 6 | 6 | 36 | 144 | 216 | 40.140 | 22 | 883.080 |
| SSS-II | 6 | 6 | 36 | 144 | 216 | 40.140 | 22 | 883.080 |
| SSS-III | 6 | 6 | 36 | 144 | 216 | 40.140 | 23 | 923.220 |
| KIRMIZI | 6 | 7 | 42 | 168 | 294 | 57.720 | 23 | 1.327.560 |
| PARLAYAN PEMBE | 6 | 7 | 42 | 168 | 294 | 57.720 | 23 | 1.327.560 |

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `maliyetHacmi` | 2.489 | c₀ — toplam sink. Eğrinin HACİM kolu. |
| `maliyetSekli` | 1,2293 | b — değer bozulmasını 44,5 kattan 12 kata indiriyor. |
| `sentezOrani` | 3 | Verim %48: fazla eşyaya değer, kestirme değil. |
| `basarisizlikSansi` | 0 | KİLİT — kırılma, koruma satma kapısını açar. |
| `cevirmeKaliteHedefi` | 0,01 | Mükemmel roll dilimi — ortalama yüz deneme. Eşya düşme oranını çözen kaliteHedefi'nden AYRI: birleştirmek düşüşü yirmi kat artırırdı. |

