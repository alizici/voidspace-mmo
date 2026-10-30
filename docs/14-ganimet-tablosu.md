---
alan: 14
ad: Ganimet Tablosu
tur: tablo
kural: 14-ganimet.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 14 · Ganimet Tablosu

Kural belgesi: [14 · Ganimet](14-ganimet.md). Koddan üretilir.

Düşme şansı %1,18 (`kaliteHedefi = 0,2`, `dusmeGuvenligi = 1,5`); eşya aralığı 12,7 dakika; bir eşya 85 öldürmeye mal oluyor. Filo yuvaları ayrı kalem: droid düşme şansı %0,98 (`droidFiloTavani = 10` yuva, aynı kural).

## Arz ve talep

| Rank | Nesil | Öldürme | Düşen eşya | Bolluk | Düşen droid | Malzeme arzı | Talep | Oran |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C-I | 19 sa | 7.638 | 90 | ×1,50 | 75 | 9.459 | 5.251 | ×1,80 |
| C-II | 20 sa | 8.170 | 96 | ×1,60 | 80 | 10.137 | 5.621 | ×1,80 |
| C-III | 22 sa | 8.739 | 103 | ×1,29 | 86 | 10.812 | 6.011 | ×1,80 |
| B-I | 23 sa | 9.348 | 110 | ×1,38 | 92 | 11.588 | 6.427 | ×1,80 |
| B-II | 25 sa | 10.000 | 118 | ×1,47 | 98 | 12.419 | 6.874 | ×1,81 |
| B-III | 27 sa | 10.696 | 126 | ×1,40 | 105 | 13.281 | 7.353 | ×1,81 |
| A-I | 29 sa | 11.442 | 135 | ×1,50 | 112 | 14.231 | 7.865 | ×1,81 |
| A-II | 31 sa | 12.239 | 144 | ×1,52 | 120 | 15.235 | 8.414 | ×1,81 |
| A-III | 33 sa | 13.091 | 154 | ×1,62 | 129 | 16.322 | 9.000 | ×1,81 |
| S-I | 35 sa | 14.003 | 165 | ×1,74 | 138 | 17.485 | 9.626 | ×1,82 |
| S-II | 37 sa | 14.979 | 176 | ×1,76 | 147 | 18.716 | 10.298 | ×1,82 |
| S-III | 40 sa | 16.023 | 189 | ×1,89 | 157 | 20.047 | 11.015 | ×1,82 |
| SS-I | 43 sa | 17.139 | 202 | ×1,92 | 168 | 21.457 | 11.782 | ×1,82 |
| SS-II | 46 sa | 18.333 | 216 | ×2,06 | 180 | 22.980 | 12.604 | ×1,82 |
| SS-III | 49 sa | 19.610 | 231 | ×2,20 | 193 | 24.608 | 13.482 | ×1,83 |
| SSS-I | 52 sa | 20.976 | 247 | ×2,25 | 206 | 26.337 | 14.421 | ×1,83 |
| SSS-II | 56 sa | 22.438 | 264 | ×2,40 | 220 | 28.201 | 15.426 | ×1,83 |
| SSS-III | 60 sa | 24.001 | 283 | ×2,46 | 236 | 30.181 | 16.501 | ×1,83 |
| KIRMIZI | 64 sa | 25.673 | 303 | ×2,63 | 252 | 32.313 | 17.650 | ×1,83 |
| PARLAYAN PEMBE | 69 sa | 27.462 | 324 | ×2,81 | 270 | 34.594 | 18.880 | ×1,83 |

## Rank çekilişi ve PRD

| Sonuç | Olasılık | Yöntem |
|---|---:|---|
| alt | %20,0 | bağımsız |
| bant | %65,0 | bağımsız |
| ust | %15,0 | PRD |

PRD sabiti C = 0,03222; garanti 32. düşmede, yaklaşık 6,8 saat.

## Kaynak başına

| Sınıf | Eşya şansı | Malzeme |
|---|---:|---:|
| siradan | %1,18 | 1 |
| guclu | %5,89 | 5 |
| boss | %300,00 | 120 |

Boss: `bossEsyaSayisi = 3` eşya, üst rank %50, kalite tabanı %85. Parçalama verimi 12,7 malzeme (C-I: 12, Parlayan Pembe: 13340) ve 1 çevirici.

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `kaliteHedefi` | 0,2 | En iyi %20 roll = ortalama beş deneme; şans buradan türüyor. |
| `dusmeGuvenligi` | 1,5 | Tam karşılamak medyan oyuncunun ancak yetişmesi demek. |
| `parcalamaOrani` | 0,15 | Tamamı verilseydi eşya farmı malzeme farmının yerine geçerdi. |
| `ustRankSansi` | 0,15 | Olay — PRD ile seri kırılıyor. |
| `altRankSansi` | 0,2 | Hayal kırıklığı değil, parçalanacak malzeme. |
| `bossEsyaSayisi` | 3 | İki saat bekleyip grup toplamak boşa çıkamaz. |

