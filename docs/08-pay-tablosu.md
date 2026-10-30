---
alan: 8
ad: Pay Tablosu
tur: tablo
kural: 08-guc-butcesi.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 08 · Pay Tablosu

Kural belgesi: [08 · Güç Bütçesi](08-guc-butcesi.md). Koddan üretilir; paylar tepe tabloda, katsayılar türetilen.

## Paylar

| Grup | Pay |
|---|---:|
| Gövde | %18,34 |
| Lazer | %26,90 |
| Jeneratör | %22,63 |
| Roketatar | %6,72 |
| CPU | %10,40 |
| Droid | %15,00 |
| **Toplam** | %99,99 |

Bütçe çapası `butceCapasi = 200`: Bastion üstünde sıfırıncı seviye C-I lazerin bütçesi 200 puan.

## Yuva katsayıları · gövde başına

Katsayı = (grup payı ÷ yuva sayısı) ÷ (lazer payı ÷ lazer sayısı); lazer 1,00. Aynı pay daha çok yuvaya bölününce katsayı düşer.

| Gövde | Lazer | Jeneratör | Roketatar | CPU | C-I lazer bütçesi |
|---|---:|---:|---:|---:|---:|
| Bastion | 1,000 | 1,052 | 1,249 | 0,967 | 200,0 |
| Vanguard | 1,000 | 0,601 | 1,249 | 0,644 | 200,0 |
| Spectre | 1,000 | 0,526 | 1,249 | 0,483 | 200,0 |
| Aegis | 1,000 | 0,467 | 1,249 | 0,483 | 200,0 |
| Wraith | 1,000 | 0,467 | 1,249 | 0,387 | 200,0 |
| Colossus | 1,000 | 0,421 | 1,249 | 0,387 | 200,0 |
| Nemesis | 1,000 | 0,382 | 1,249 | 0,387 | 200,0 |
| Sovereign | 1,000 | 0,382 | 1,249 | 0,322 | 200,0 |

## Ölçülen paylar · Shapley

08 dağıtır, 16 ölçer (08.3). Gerçekleşen güç kur biriminde toplamsal: saldırı + dayanıklılık ÷ T + sistem. Referans kit C-I rafı, +0. Fark bir doğrulama, ayar kolu değil; en büyük fark 8,8 puan.

| Grup | İlan | Ölçülen | Fark |
|---|---:|---:|---:|
| Gövde | %18,34 | %25,59 | 7,25 |
| Lazer | %26,90 | %32,06 | 5,16 |
| Jeneratör | %22,63 | %21,92 | -0,71 |
| Roketatar | %6,72 | %7,65 | 0,93 |
| CPU | %10,40 | %6,63 | -3,77 |
| Droid | %15,00 | %6,17 | -8,83 |

## Gövde havuzu · TTK kısıtından

Gövde çapası girdi değil, çözüm: `A × T × kayıp − kalkan − eşya havuzu` (08.5). Saldırı büyüdükçe çapa kendiliğinden büyür.

| Referans DPS (A) | T | Kayıp çarpanı | Gereken ham havuz | Kalkan çapası | Eşya havuzu | Gövde çapası |
|---:|---:|---:|---:|---:|---:|---:|
| 2.008,2 | 30,0 sn | 0,595 | 35.847 | 8.000 | 12.064 | **15.782** |

Eşya havuzu bugün sıfır: referans build çıplak gövde + beş lazer, kalkan jeneratörlerinin katkısı referansa girmiyor. Referans tam donanımı taşıdığında (04.5) bu sütun dolar ve gövde ↔ eşya kolu (08.6) doğar.

## TTK sınavı

| Referans DPS | EHP | Ölçülen TTK | İlan edilen T | Sapma |
|---:|---:|---:|---:|---:|
| 795,5 | 23.864 | 30,0 sn | 30,0 sn | %-0,0 |

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `butceCapasi` | 200 | Bütün eşyalar buna göre türüyor. |
| `payGovde` | 18,34 | Gövde tek eşya ve taban havuzun tamamını taşıyor. |
| `payLazer` | 26,9 | Katsayı ölçeğinin çapası. |
| `payJenerator` | 22,63 | Gövde ↔ eşya kolunun tuttuğu yer. |
| `payRoketatar` | 6,72 | Tek yuva: katkısı büyürse tek eşya oyunu belirler. |
| `payDroid` | 15 | Altıncı grup; droid DPS payı hedefiyle aynı büyüklükte. |
| `payCpu` | 10,4 | İki yuva, savunma kanalı. |
| `payBandi` | 10 | Ölçülen pay ilan edilenden en çok bu kadar sapar; sapma yapısal, üç puan tutmadı. |

