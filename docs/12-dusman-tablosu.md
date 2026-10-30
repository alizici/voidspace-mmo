---
alan: 12
ad: Düşman Tablosu
tur: tablo
kural: 12-dusman-kurgusu.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 12 · Düşman Tablosu

Kural belgesi: [12 · Düşman Kurgusu](12-dusman-kurgusu.md). Koddan üretilir; her sütun bandın referans DPS'inden (09) ve saatlik hedefinden (11) türüyor.

## Merdiven

| Bant | Bölge | Sıradan can | ödül | Güçlü can | ödül | Yaratık DPS | Boss canı | Boss ödülü | Boss aralığı |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C-I | Sığlık | 2.008 | 360 | 10.041 | 1.150 | 100 | 722.961 | 43.200 | 2,0 sa |
| C-II | Sığlık | 2.896 | 485 | 14.479 | 1.550 | 144 | 1.042.509 | 58.237 | 2,0 sa |
| C-III | Kırık Halka | 4.176 | 654 | 20.879 | 2.090 | 207 | 1.503.298 | 78.508 | 2,0 sa |
| B-I | Kırık Halka | 6.022 | 882 | 30.108 | 2.817 | 299 | 2.167.756 | 105.835 | 2,0 sa |
| B-II | Kırık Halka | 8.683 | 1.189 | 43.415 | 3.798 | 431 | 3.125.905 | 142.674 | 2,0 sa |
| B-III | Solgun Geçit | 12.521 | 1.603 | 62.605 | 5.120 | 621 | 4.507.554 | 192.337 | 2,0 sa |
| A-I | Solgun Geçit | 18.055 | 2.161 | 90.276 | 6.902 | 895 | 6.499.893 | 259.285 | 2,0 sa |
| A-II | Kor Sahanlığı | 26.036 | 2.913 | 130.178 | 9.305 | 1.291 | 9.372.846 | 349.537 | 2,0 sa |
| A-III | Kor Sahanlığı | 37.543 | 3.927 | 187.717 | 12.544 | 1.862 | 13.515.644 | 471.204 | 2,0 sa |
| S-I | Kor Sahanlığı | 54.138 | 5.294 | 270.688 | 16.910 | 2.684 | 19.489.559 | 635.221 | 2,0 sa |
| S-II | Yas Boşluğu | 78.067 | 7.136 | 390.333 | 22.796 | 3.871 | 28.103.944 | 856.328 | 2,0 sa |
| S-III | Yas Boşluğu | 112.572 | 9.620 | 562.860 | 30.731 | 5.582 | 40.525.887 | 1.154.399 | 2,0 sa |
| SS-I | Devrik Kule | 162.329 | 12.969 | 811.643 | 41.427 | 8.049 | 58.438.329 | 1.556.222 | 2,0 sa |
| SS-II | Devrik Kule | 234.078 | 17.483 | 1.170.390 | 55.847 | 11.606 | 84.268.071 | 2.097.912 | 2,0 sa |
| SS-III | Devrik Kule | 337.540 | 23.568 | 1.687.702 | 75.286 | 16.736 | 121.514.558 | 2.828.153 | 2,0 sa |
| SSS-I | Sessiz Fener | 486.733 | 31.771 | 2.433.667 | 101.492 | 24.134 | 175.223.993 | 3.812.576 | 2,0 sa |
| SSS-II | Sessiz Fener | 701.869 | 42.830 | 3.509.347 | 136.820 | 34.801 | 252.672.998 | 5.139.658 | 2,0 sa |
| SSS-III | Son Eşik | 1.012.096 | 57.739 | 5.060.479 | 184.444 | 50.183 | 364.354.463 | 6.928.669 | 2,0 sa |
| KIRMIZI | Son Eşik | 1.459.442 | 77.837 | 7.297.210 | 248.645 | 72.364 | 525.399.136 | 9.340.400 | 2,0 sa |
| PARLAYAN PEMBE | Son Eşik | 2.104.515 | 104.930 | 10.522.577 | 335.193 | 104.349 | 757.625.554 | 12.591.607 | 2,0 sa |

NOVA ödülü her bantta 1; saatte 400 NOVA. Sınıf oranları: hız siradan 0,30 · guclu 0,15 · boss 0,10; menzil siradan 0,50 · guclu 0,65 · boss 0,80.

## Kadro · 32 yaratık

| Bölge | Sıradan | Güçlü | Boss |
|---|---|---|---|
| 1 · Sığlık | Interdictor · Barraguda | Warray | Kurvex |
| 2 · Kırık Halka | Subverter · Drifter | Obliterator | Psyche Behemot |
| 3 · Solgun Geçit | Ghostfin · Prong | Glowfin | Gyrem Overlord |
| 4 · Kor Sahanlığı | Spear · Reaver | Exile | Sovereign I |
| 5 · Yas Boşluğu | Buccaneer · Rowdy | Despoiler | Agathon |
| 6 · Devrik Kule | Inmate · Charscar | Hellborn | Skorr |
| 7 · Sessiz Fener | Smelter · Sentry Raptor | Engorger | Barbtail |
| 8 · Son Eşik | Veil Prowler · Hexor Simulacra | Magma Prowler | Evoke XVI |

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `siradanOldurmeSuresi` | 1 | Sınıf bir orandır: öldürme süresi her bantta sabit. |
| `gucluOldurmeSuresi` | 5 | Beş kat — girmek bir karar. |
| `siradanDogusSuresi` | 8 | Çevrimin çoğu bu; ödül hesabının yarısı. |
| `gucluDogusSuresi` | 20 | İri hedefin sürekli durması onu sıradan yapardı. |
| `siradanHizOrani` | 0,3 | Kovalayabilir ama yetişemez. |
| `gucluHizOrani` | 0,15 | Hiç kovalayamaz — kaçmak her zaman mümkün. |
| `bossHizOrani` | 0,1 | Yerinde duran hedef; grup ona gider. |
| `siradanMenzilOrani` | 0,5 | Menzil eşit olsaydı mesafe tutmanın anlamı kalmazdı. |
| `gucluMenzilOrani` | 0,65 | Daha yakın ama hâlâ oyuncunun altında. |
| `bossMenzilOrani` | 0,8 | En yakın; yine de kaçış mümkün. |
| `kacisPenceresi` | 120 | Fark etme + itki + menzil dışına çıkma zincirinin tamamı. |
| `tehditSayisi` | 3 | Tehdit tek yaratıktan değil, üçünü birden çekmekten. |
| `gucluRiskPrimi` | 1,15 | Saldırgan olmasının karşılığı; sıradanda prim yok. |
| `bossGrubu` | 3 | Boss bir grup hedefi. |
| `bossHedefSuresi` | 120 | Üç oyuncu iki dakika. |
| `bossPrimi` | 3 | Harcanan oyuncu-saatin katı. |
| `bossGelirPayi` | 0,15 | Kaçırmak yavaşlatmalı, durdurmamalı. |
| `tabanSaatlikGelir` | 144.000 | Birinci bandın kredi hedefi; ödül bunun bölünmesi. |
| `novaOdulu` | 1 | ÖLÇEKLENMEZ — NOVA gerçek parayla rekabet ediyor. |

