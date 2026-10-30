---
alan: 1
ad: Savaş Sayıları
tur: tablo
kural: 01-savas-formulu.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 01 · Savaş Sayıları

Kural belgesi: [01 · Savaş Formülü](01-savas-formulu.md). Koddan üretilir: ölçülen referanstan okunur, türetilen formülden çıkar.

## Ölçülen · referans build

| Büyüklük | Değer |
|---|---:|
| Yaylım (beklenen kritikle) | 1.414 |
| Atış aralığı `referansAtisAraligi` | 1,10 sn |
| Beklenen DPS | 1.606,8 |
| Gövde · kalkan | 15.782 · 20.064 |
| Ham havuz | 35.847 |
| Zırh azaltması · sıyırma | %30,0 · %15,0 |
| EHP | 60.247 |
| Kalkanı düşürme | 12,5 sn |
| Oyuncu ↔ oyuncu TTK | 37,5 sn |

## Türetilen

| Sabit | Değer | Formül |
|---|---:|---|
| Kritik beklenen değeri | 1,250 | 1 + k(d − 1) |
| Kritik PRD sabiti C | 0,084744 | etkin şans = k olacak şekilde çözüm; garantili kritik 12. yaylımda |
| K zırh | 2.333,3 | referans zırh × (1 ÷ hedef − 1) |
| K sıyırma | 1.700,0 | referans kaçınma × (1 ÷ hedef − 1) |

## Yaratıklar

| Yaratık | Can | Zırh · kaçınma | EHP | TTK | Yaylım |
|---|---:|---:|---:|---:|---:|
| Void Spore | 2.008 | 0 · 0 | 2.008 | 1,25 sn | 2 |
| Void Leviathan | 10.041 | 0 · 0 | 10.041 | 6,25 sn | 8 |

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `kritikSansiReferans` | 0,25 | Dört yaylımda bir kritik. |
| `kritikCarpaniReferans` | 2 | Ekranda okunması en kolay çarpan. |
| `zirhAzaltmaHedefi` | 0,3 | Referansta %30 — hissedilir ama tekelci değil. |
| `siyirmaTavani` | 0,4 | Hasar asla sıfırlanmaz. |
| `siyirmaHedefiReferans` | 0,15 | Zırhın yarısı: kardeş ama baskın değil. |
| `pvpCarpani` | 1 | Bugün etkisiz, kol duruyor. |
| `sonHasarTavani` | 0,1 | L5 zinciri ele geçiremez. |

