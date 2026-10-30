---
alan: 3
ad: Değer Tablosu
tur: tablo
kural: 03-stat-degeri.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 03 · Değer Tablosu

Kural belgesi: [03 · Stat Değeri](03-stat-degeri.md). Koddan üretilir. Marjinal değer referans build üzerinde sayısal türev; birim fiyatı bugün kodun bir bütçe puanına verdiği miktar.

## Referans

| Beklenen DPS | EHP | Ölçülen TTK | `referansTTK` |
|---:|---:|---:|---:|
| 795,5 | 23.864 | 30,0 sn | 30,0 sn |

## Saldırı · ΔDPS

| Stat | Birim | Marjinal değer (ΔDPS) | Birim fiyatı (puan başına) | Puan başına ΔDPS |
|---|---|---:|---:|---:|
| `hasar_artisi` | oran 1,0 | 795,45 | 0,0007 | 0,563 |
| `kritik_sansi` | oran 1,0 | 636,36 | 0,0009 | 0,563 |
| `kritik_hasari` | oran 1,0 | 159,09 | 0,0035 | 0,563 |
| `son_hasar` | 1 puan | 0,91 | 1,25 | 1,136 |
| `taban_hasar` | 1 puan | 1,136 | 1 | 1,136 |

Çapa taban hasar; bütün fiyatlar zincirin türevinden türüyor (03.1). Hasar artışı ile atış hızı aynı değerde: kanarya, bozulursa sorun zincirde.

## Savunma · ΔEHP

| Stat | Birim | Marjinal değer (ΔEHP) | Birim fiyatı (puan başına) | Puan başına ΔEHP |
|---|---|---:|---:|---:|
| `govde_cani` | 1 puan | 1,681 | 20,284 | 34,09 |
| `kalkan` | 1 puan | 1,681 | 20,284 | 34,09 |
| `zirh` | 1 puan | 7,159 | 1,886 | 13,50 |
| `kacinma` | 1 puan | 11,932 | 1,132 | 13,50 |
| `kalkan_yenilenmesi` | oran 1,0 | — | 0,00676 | — |

Savunma çapası `Turetilenler.savunmaCapasi` = 20,28 havuz/puan; kurdan türüyor (09.4). Bir saldırı puanı 34,09 EHP değerinde.

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|

