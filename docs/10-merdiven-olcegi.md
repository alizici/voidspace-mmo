---
alan: 10
ad: Merdiven Ölçeği
tur: tablo
kural: 10-ilerleme-ve-unvan.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 10 · Merdiven Ölçeği

Kural belgesi: [10 · İlerleme ve Unvan](10-ilerleme-ve-unvan.md). Koddan üretilir. Hedef `hedefSure = 780` saat, gelir üssü `gelirUssu = 0,816`. Referans build (10.6): kademenin gövdesi, rank, artı +11; savaş puanı sütunu bugün rank çarpanını taşıyor, artıyı ve tam donanımı değil (borç defteri B1).

## Rank merdiveni

| # | Rank | Çarpan | Kademe | Gövde | Nesil süresi | Kümülatif | Nesil bütçesi | Referans BR |
|---:|---|---:|---:|---|---:|---:|---:|---:|
| 1 | C-I | 1,0 | 1 | Bastion | 19 sa | 19 sa | 2.749.717 | 3.600 |
| 2 | C-II | 1,4 | 1 | Bastion | 20 sa | 40 sa | 3.965.092 | 5.191 |
| 3 | C-III | 2,1 | 2 | Vanguard | 22 sa | 61 sa | 5.717.662 | 7.486 |
| 4 | B-I | 3,0 | 2 | Vanguard | 23 sa | 85 sa | 8.244.869 | 10.794 |
| 5 | B-II | 4,3 | 2 | Vanguard | 25 sa | 110 sa | 11.889.100 | 15.566 |
| 6 | B-III | 6,2 | 3 | Spectre | 27 sa | 136 sa | 17.144.083 | 22.445 |
| 7 | A-I | 9,0 | 3 | Spectre | 29 sa | 165 sa | 24.721.768 | 32.366 |
| 8 | A-II | 13,0 | 4 | Aegis | 31 sa | 196 sa | 35.648.789 | 46.672 |
| 9 | A-III | 18,7 | 4 | Aegis | 33 sa | 228 sa | 51.405.553 | 67.301 |
| 10 | S-I | 27,0 | 4 | Aegis | 35 sa | 263 sa | 74.126.808 | 97.049 |
| 11 | S-II | 38,9 | 5 | Wraith | 37 sa | 301 sa | 106.890.857 | 139.944 |
| 12 | S-III | 56,1 | 5 | Wraith | 40 sa | 341 sa | 154.136.616 | 201.800 |
| 13 | SS-I | 80,8 | 6 | Colossus | 43 sa | 384 sa | 222.265.001 | 290.995 |
| 14 | SS-II | 116,6 | 6 | Colossus | 46 sa | 430 sa | 320.506.131 | 419.615 |
| 15 | SS-III | 168,1 | 6 | Colossus | 49 sa | 479 sa | 462.169.841 | 605.085 |
| 16 | SSS-I | 242,4 | 7 | Nemesis | 52 sa | 531 sa | 666.448.911 | 872.532 |
| 17 | SSS-II | 349,5 | 7 | Nemesis | 56 sa | 587 sa | 961.019.329 | 1.258.191 |
| 18 | SSS-III | 504,0 | 8 | Sovereign | 60 sa | 647 sa | 1.385.789.872 | 1.814.312 |
| 19 | KIRMIZI | 726,7 | 8 | Sovereign | 64 sa | 711 sa | 1.998.308.996 | 2.616.238 |
| 20 | PARLAYAN PEMBE | 1.047,9 | 8 | Sovereign | 69 sa | 780 sa | 2.881.561.572 | 3.772.615 |

Toplam 780 saat; hedef 780. Endgame dahil toplam 1.124 saat.

## Unvan merdiveni

`unvanSayisi = 120` basamak, unvan başına ×1,0622; taban 3.600, tavan 4.715.768.

| # | BR eşiği |
|---:|---:|
| 1 | 3.600 |
| 5 | 4.582 |
| 20 | 11.324 |
| 40 | 37.837 |
| 60 | 126.424 |
| 80 | 422.413 |
| 100 | 1.411.383 |
| 115 | 3.487.993 |
| 120 | 4.715.768 |

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `ilkUnvanEsigi` | 3.600 | Merdivenin tabanı; referansın kanal gücü buraya oturtulur, K ondan çözülür. |
| `hedefSure` | 780 | 1,5 sa/gün × 5 gün × 104 hafta. |
| `unvanSayisi` | 120 | BR aralığı eşit ORANLARLA bölünüyor. |
| `gelirUssu` | 0,816 | α < 1: her nesil bir öncekinden uzun. |

