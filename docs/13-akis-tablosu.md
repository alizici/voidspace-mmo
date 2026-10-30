---
alan: 13
ad: Akış Tablosu
tur: tablo
kural: 13-kaynak-akisi.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 13 · Akış Tablosu

Kural belgesi: [13 · Kaynak Akışı](13-kaynak-akisi.md). Koddan üretilir.

## Gider payları

| Kalem | Pay | Bant 1 nesil | Bant 20 nesil |
|---|---:|---:|---:|
| artiBasma | %55,0 | 1.512.344 | 1.584.858.865 |
| sentez | %13,7 | 378.086 | 396.214.716 |
| magaza | %13,7 | 378.086 | 396.214.716 |
| birikim | %9,2 | 252.057 | 264.143.144 |
| onarim (türetilen) | %8,3 | 229.143 | 240.130.131 |
| **Toplam** | %100,0 | | |

Onarım payı `genelOlumSikligi = 1` × ölüm maliyeti ÷ 60 = %8,3; kalan %91,7 dört kaleme bölünüyor.

## Artı erişimi

| Rank | Nesil bütçesi | Yuva | Yuva başına artı | Ulaşılan | Filo başına artı | Filo ulaşılan | +15 maliyeti | Kat |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C-I | 2.749.717 | 12 | 107.124 | +11 | 22.685 | +5 | 229.300 | ×2,1 |
| C-II | 3.965.092 | 12 | 154.473 | +11 | 32.712 | +5 | 330.649 | ×2,1 |
| C-III | 5.717.662 | 16 | 167.063 | +10 | 47.171 | +5 | 476.795 | ×2,9 |
| B-I | 8.244.869 | 16 | 240.905 | +10 | 68.020 | +5 | 687.538 | ×2,9 |
| B-II | 11.889.100 | 16 | 347.385 | +10 | 98.085 | +5 | 991.430 | ×2,9 |
| B-III | 17.144.083 | 18 | 445.270 | +9 | 141.439 | +5 | 1.429.646 | ×3,2 |
| A-I | 24.721.768 | 18 | 642.079 | +9 | 203.955 | +5 | 2.061.547 | ×3,2 |
| A-II | 35.648.789 | 19 | 877.148 | +9 | 294.103 | +5 | 2.972.751 | ×3,4 |
| A-III | 51.405.553 | 19 | 1.264.847 | +9 | 424.096 | +5 | 4.286.707 | ×3,4 |
| S-I | 74.126.808 | 19 | 1.823.910 | +9 | 611.546 | +5 | 6.181.432 | ×3,4 |
| S-II | 106.890.857 | 20 | 2.498.574 | +9 | 881.850 | +5 | 8.913.625 | ×3,6 |
| S-III | 154.136.616 | 20 | 3.602.943 | +9 | 1.271.627 | +5 | 12.853.449 | ×3,6 |
| SS-I | 222.265.001 | 21 | 4.948.042 | +9 | 1.833.686 | +5 | 18.534.673 | ×3,7 |
| SS-II | 320.506.131 | 21 | 7.135.077 | +9 | 2.644.176 | +5 | 26.726.998 | ×3,7 |
| SS-III | 462.169.841 | 21 | 10.288.781 | +9 | 3.812.901 | +5 | 38.540.331 | ×3,7 |
| SSS-I | 666.448.911 | 22 | 14.162.039 | +8 | 5.498.204 | +5 | 55.575.157 | ×3,9 |
| SSS-II | 961.019.329 | 22 | 20.421.661 | +8 | 7.928.409 | +5 | 80.139.375 | ×3,9 |
| SSS-III | 1.385.789.872 | 23 | 28.167.685 | +8 | 11.432.766 | +5 | 115.560.982 | ×4,1 |
| KIRMIZI | 1.998.308.996 | 23 | 40.617.802 | +8 | 16.486.049 | +5 | 166.638.936 | ×4,1 |
| PARLAYAN PEMBE | 2.881.561.572 | 23 | 58.570.871 | +8 | 23.772.883 | +5 | 240.293.344 | ×4,1 |

Endgame kuyruğu 344 saat; toplam 1.124 saat.

## NOVA kuru

| Rank | Kredi/sa | NOVA/sa | 1 NOVA ≡ kredi |
|---|---:|---:|---:|
| C-I | 144.000 | 400 | 360 |
| S-I | 2.117.402 | 400 | 5.294 |
| SSS-III | 23.095.565 | 400 | 57.739 |
| PARLAYAN PEMBE | 41.972.022 | 400 | 104.930 |

Bu tablo bir çevirme oranı değil: `paraCevirmeAcik` kapalı, çevirme yok.

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `genelOlumSikligi` | 1 | Onarım payı bundan türüyor; PvP sıklığıyla karıştırılmamalı. |
| `payArti` | 0,6 | Ekonominin ana gideri — etkin %55. |
| `paySentez` | 0,15 | Fazla eşyayı ranka çeviren ikinci ayak. |
| `payMagaza` | 0,15 | Yedek parça ve doğrudan alım. |
| `payBirikim` | 0,1 | Gider değil TAMPON — sıfırsa tek kötü kararın telafisi yok. |

