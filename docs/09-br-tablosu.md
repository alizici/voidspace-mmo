---
alan: 9
ad: BR Tablosu
tur: tablo
kural: 09-savas-puani.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 09 · BR Tablosu

Kural belgesi: [09 · Savaş Puanı](09-savas-puani.md). Koddan üretilir.

## Kur ve A = D

| Büyüklük | Değer |
|---|---:|
| Referans DPS (A) | 1.606,8 |
| Referans EHP | 60.247 |
| Ölçülen TTK | 37,5 sn |
| `referansTTK` (T) | 30,0 sn |
| D = EHP ÷ T | 2.008,2 |
| A ÷ D | 0,800 |
| Kur: 1 DPS ≡ | 30 EHP |

## Savunma çapası

1 saldırı puanı = 1,1364 DPS = 34,09 EHP; 1 savunma puanı = 20,28 havuz (EHP çarpanı 1,681).

| Stat | Puan başına |
|---|---:|
| `govde_cani` | 20,28409 |
| `kalkan` | 20,28409 |
| `kalkan_yenilenmesi` | 0,00676 |
| `zirh` | 1,88618 |
| `kacinma` | 1,13171 |

## Sistem kanalı

`sistemKatsayisiMenzil = 0,5` · `sistemKatsayisiHiz = 0,4` · `sistemKatsayisiItki = 0,3` · tavan `sistemTavani = 25` puan → çarpan en fazla 1,25. Örnek: %20 hız + %20 menzil = 18,0 puan → ×1,18.

## Ölçek

`brOlcegi = 1,7926`; referans BR (merdivenin tabanı) 3.600.

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `referansTTK` | 30 | Kanallar arası kurun KENDİSİ: 1 DPS ≡ 30 EHP. |
| `brOlcegi` | 1,7926 | Dengeye karışmıyor; sayıyı okunur aralığa taşıyor. |
| `sistemTavani` | 25 | Sistem çarpımsal: sınırsız bırakılırsa baskın olur. |
| `sistemKatsayisiMenzil` | 0,5 | Hem saldırıya hem kaçışa yarıyor. |
| `sistemKatsayisiHiz` | 0,4 | Yetişmek ve kaçmak. |
| `sistemKatsayisiItki` | 0,3 | Yalnız kaçışa yarıyor; şarj sayısıyla sınırlı. |
| `droidDpsPayi` | 0,15 | Referansta droidlerin saldırıya payı; taban hasar bundan türer. |
| `droidDayaniklilikKatsayisi` | 0,25 | Geometrik ortalamada iki kez sayılmasın: çeyrek, bir değil. |

