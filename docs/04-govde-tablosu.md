---
alan: 4
ad: Gövde Tablosu
tur: tablo
kural: 04-gemi-ve-yuvalar.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 04 · Gövde Tablosu

Kural belgesi: [04 · Gemi ve Yuvalar](04-gemi-ve-yuvalar.md). Koddan üretilir; bugün oyunun yaptığı şey.

## Gövde merdiveni

Sekiz gövde de çapa × kademe çarpanı (`Turetilenler.govdeKademeCarpanlari`, rank merdiveninin kademe normalizasyonu); ilk 3 gövdenin elle duran tek şeyi yuva toplamı ve fiyatı. Çapa: gövde canı TTK kısıtından çözülen 15.782 (08.5) · `kalkanCapasi = 8.000` · `hizCapasi = 320`. Fiyatı olmayan gövde satın alınamaz.

| Kademe | Gövde | Rank | N | Gövde canı | Kalkan | Hız | Fiyat | Kaynak |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | Bastion | C-I | 1,00 | 15.782 | 8.000 | 320 | 0 | elle |
| 2 | Vanguard | C-III | 2,50 | 39.408 | 19.976 | 346 | 240.000 | elle |
| 3 | Spectre | B-III | 6,23 | 98.401 | 49.879 | 373 | 980.000 | elle |
| 4 | Aegis | A-II | 15,57 | 245.703 | 124.546 | 403 | — | türetilen |
| 5 | Wraith | S-II | 38,87 | 613.514 | 310.987 | 435 | — | türetilen |
| 6 | Colossus | SS-I | 97,07 | 1.531.925 | 776.526 | 470 | — | türetilen |
| 7 | Nemesis | SSS-I | 242,37 | 3.825.170 | 1.938.960 | 508 | — | türetilen |
| 8 | Sovereign | SSS-III | 605,19 | 9.551.332 | 4.841.523 | 548 | — | türetilen |

## Yuva haritası

İlk 3 gövde sanata kilitli; sonrası kademe başına `yuvaArtisi = 1` yuva, lazer sabit (`lazerYuvaSayisi = 5`), kalanı jeneratör ve CPU'ya. Droid yuvası yok (04.10).

| Gövde | Lazer | Jeneratör | Roketatar | CPU | Toplam |
|---|---:|---:|---:|---:|---:|
| Bastion | 5 | 4 | 1 | 2 | 12 |
| Vanguard | 5 | 7 | 1 | 3 | 16 |
| Spectre | 5 | 8 | 1 | 4 | 18 |
| Aegis | 5 | 9 | 1 | 4 | 19 |
| Wraith | 5 | 9 | 1 | 5 | 20 |
| Colossus | 5 | 10 | 1 | 5 | 21 |
| Nemesis | 5 | 11 | 1 | 5 | 22 |
| Sovereign | 5 | 11 | 1 | 6 | 23 |

## Referans build

| Bileşen | Değer |
|---|---:|
| Gövde | Bastion · C-I |
| Jeneratör bölünmesi | kalkan %50 |
| Referans zırh | 1.000 |
| Referans kaçınma | 300 |
| Zırh azaltması | %30,0 |
| Sıyırma | %15,0 |
| K zırh | 2.333,3 |
| K sıyırma | 1.700,0 |
| Beklenen DPS | 1.607 |
| EHP | 60.247 |
| BR tabanı | 3.600 |

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `kalkanCapasi` | 8.000 | Gövdenin %67'si — kalkan ikinci havuz. |
| `hizCapasi` | 320 | Tempo belirliyor; kademeyle neredeyse artmıyor. |
| `zirhCapasi` | 1.000 | 01'in %30 azaltma hedefini sayıya çeviren referans. |
| `referansKacinma` | 300 | Aynı işi sıyırma eğrisi için yapıyor. |
| `referansJeneratorKalkan` | 0,5 | Yarısı kalkan, yarısı hız — takas kararı. |
| `referansAtisAraligi` | 1,1 | Kurun ikinci ayağı: taban hasar → DPS. |
| `govdeKademeSayisi` | 8 | Sekiz gemi, sekiz bölge. |
| `yuvaArtisi` | 1 | Sanat kararı: kademe başına bir yuva; lazere değil. |
| `hizArtisi` | 1,08 | Hız tempo belirler; rank çarpanıyla büyüseydi savaş bozulurdu. |
| `lazerYuvaSayisi` | 5 | Sanat kısıtı: çizimdeki kaide sayısı, sekiz tasarımda beş. |
| `jeneratorYuvaPayi` | 0,6667 | Bastion'ın 4 · 2 dağılımı: kalan yuvaların üçte ikisi jeneratör. |

