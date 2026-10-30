---
alan: 15
ad: Kazanç Tablosu
tur: tablo
kural: 15-kazanc.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 15 · Kazanç Tablosu

Kural belgesi: [15 · Kazanç](15-kazanc.md). Koddan üretilir.

## Taban eşya

| Rank | Nesil bütçesi | Taban eşya fiyatı | Taban eşyanın rankı | Bütçenin |
|---|---:|---:|---|---:|
| C-I | 2.749.717 | 94.522 | C-I | %3,4 |
| C-II | 3.965.092 | 136.300 | C-I | %3,4 |
| C-III | 5.717.662 | 196.545 | C-II | %3,4 |
| B-I | 8.244.869 | 283.417 | C-III | %3,4 |
| B-II | 11.889.100 | 408.688 | B-I | %3,4 |
| B-III | 17.144.083 | 589.328 | B-II | %3,4 |
| A-I | 24.721.768 | 849.811 | B-III | %3,4 |
| A-II | 35.648.789 | 1.225.427 | A-I | %3,4 |
| A-III | 51.405.553 | 1.767.066 | A-II | %3,4 |
| S-I | 74.126.808 | 2.548.109 | A-III | %3,4 |
| S-II | 106.890.857 | 3.674.373 | S-I | %3,4 |
| S-III | 154.136.616 | 5.298.446 | S-II | %3,4 |
| SS-I | 222.265.001 | 7.640.359 | S-III | %3,4 |
| SS-II | 320.506.131 | 11.017.398 | SS-I | %3,4 |
| SS-III | 462.169.841 | 15.887.088 | SS-II | %3,4 |
| SSS-I | 666.448.911 | 22.909.181 | SS-III | %3,4 |
| SSS-II | 961.019.329 | 33.035.039 | SSS-I | %3,4 |
| SSS-III | 1.385.789.872 | 47.636.527 | SSS-II | %3,4 |
| KIRMIZI | 1.998.308.996 | 68.691.872 | SSS-III | %3,4 |
| PARLAYAN PEMBE | 2.881.561.572 | 99.053.679 | KIRMIZI | %3,4 |

Taban eşyanın kalitesi %70, alt statı 0. Satılabilir kaynaklar: kredi hayır · malzeme hayır · nova hayır; NOVA eşya satıyor mu: hayır.

## NOVA giderleri

Saatte 400 NOVA; bir NOVA 9,0 saniye oyun. Fiyat = kazandırdığı dakika ÷ 60 × saatlik NOVA.

| Kalem | Kazandırdığı dakika | Fiyat |
|---|---:|---:|
| onarim | 5,0 | 33 |
| cevirme · C-I | 12,8 | 85 |
| cevirme · A-I | 114,6 | 764 |
| cevirme · PARLAYAN PEMBE | 534,6 | 3.564 |
| envanter | 300,0 | 2.000 |
| droidOnarimi | 15,3 | 102 |
| cevirme · PARLAYAN PEMBE, 6 kilit | 3.742,6 | 24.951 |

Ömür boyu NOVA musluğu 312.000. Zorunlu gider (onarım, envanter) 35.740, musluğun %11,5'i. Çevirme dahil (her nesilde her yuva için bir tam çevirme) 701.711, oran %224,9: çevirme lüks, tavanı yok (15.3).

## Paketler

| Fiyat | Bonus | NOVA | Oyun saati |
|---:|---:|---:|---:|
| $0,99 | ×1,00 | 1.307 | 3 sa |
| $40,00 | ×1,60 | 84.480 | 211 sa |

Ödeyen oyuncunun payı musluğun %27,1'i; ARPU $1,20.

## Paranın tavanı

Kalite tabanı `kaliteAltSiniri = 0,7` ile **%9,9**; bir rank adımı %44,2. SS–SSS bandında (`kaliteAltSiniriSS = 0,75`) %8,1, kapak taşlarında (`kaliteAltSiniriRenk = 0,8`) %6,4; tavan yukarı çıktıkça daralıyor.

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `tasarimNova` | 100 | Görünüş zaman kazandırmıyor: fiyatı türetilemez, ilan edilir. |
| `formasyonNova` | 200 | Formasyon geometri de taşıyor; tasarımın iki katı. |
| `magazaEsyaSayisi` | 4 | 14'ün ölçtüğü boşluk: ortalama dört yuva eksik kalıyor. |
| `tabanEsyaRankFarki` | -1 | Mağaza eşyası en kötü drop'tan bile zayıf olmalı. |
| `baslangicEsyaSayisi` | 2 | Başlangıç kredisi raftan türüyor: bir eşya yalnız düğmeyi, iki eşya ilk seçimi öğretiyor. |
| `envanterNova` | 2.000 | Kalıcı genişletme; zaman değil alan satılıyor. |
| `envanterKademe` | 5 | Beş kademe — sonrası envanteri anlamsızlaştırır. |
| `dolarSaatDegeri` | 3,3 | IAP kurunun tek girdisi; tavanı değiştirmiyor. |
| `paketBonusTavani` | 1,6 | ×2 üstü küçük paketleri anlamsızlaştırır. |
| `odemeOrani` | 0,03 | Hedef — ARPU bununla ARPPU'nun çarpımı. |
| `hedefARPPU` | 40 | Ödeyen oyuncu başına hedef. |

