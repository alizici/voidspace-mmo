---
alan: 17
ad: Mermi Tablosu
tur: tablo
kural: 17-mermi.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 17 · Mermi Tablosu

Kural belgesi: [17 · Mermi](17-mermi.md). Koddan üretilir.

## Fiyat ve kazanç

Fiyat(m) = `mermiTabanFiyati` × m^`mermiFiyatUssu`; birim bir namlu atışı (17.8). Saatlik gider sıradan çevrimde sürekli farm: öldürme başına 4,5 atış ÷ çarpan × fiyat; gelir payı referans saatlik gelire (144.000) göre.

| Mermi | Çarpan | Birim fiyat | Hasar başına | Sıradan öldürme/sa | PvE kazancı | Güçlü kazancı | PvP TTK | Saatlik gider | Gelirin | PvP net prim |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| MR-1 | ×1 | bedava | — | 400 | ×1,00 | ×1,00 | 30,0 sn | 0 | %0,0 | +%30,0 |
| MR-2 | ×2 | 23,8 | 11,9 | 424 | ×1,06 | ×1,11 | 15,0 sn | 22.867 | %15,9 | +%9,4 |
| MR-3 | ×3 | 46,0 | 15,3 | 432 | ×1,08 | ×1,15 | 10,0 sn | 30.125 | %20,9 | +%2,8 |
| MR-4 | ×4 | 73,6 | 18,4 | 436 | ×1,09 | ×1,18 | 7,5 sn | 36.486 | %25,3 | −%2,9 |
| MR-5 | ×5 | 105,9 | 21,2 | 439 | ×1,10 | ×1,19 | 6,0 sn | 42.258 | %29,3 | −%8,1 |
| MR-6 | ×6 | 142,5 | 23,8 | 441 | ×1,10 | ×1,20 | 5,0 sn | 47.604 | %33,1 | −%13,0 |
| SF-1 · sifon | ×3 kalkan | 46,0 | 15,3 | — | — | — | yalnız kalkan | — | — | — |

Sifonun kalkan yenilenmesine karşı etkin çarpanı ×6,03 (nominal ×3). Üs ankrajı 1,631; tepe tablodaki üs 1,631. Kilitler: MR-1 bedava evet · NOVA mermi satıyor hayır. Savaş puanı mermiyi saymıyor: patlama gücü BR'yi 6 kat aşabilir (17.7).

## Tepe tabloya katkı

| Girdi | Değer | Gerekçe |
|---|---:|---|
| `mermiTabanFiyati` | 7,67 | Ankraj: ×2 ile sürekli farm referans gelirin ~%15'i. |
| `mermiFiyatUssu` | 1,631 | ×6 birim hasar bedeli ×2'nin iki katı: 1 + ln2 ÷ ln3. |
| `mermiCarpanTavani` | 6 | MR-6; üstü PvP'yi tek yaylıma indirir. |
| `sifonCarpani` | 3 | Yalnız kalkana; MR-3 fiyatına yarım hedef. |

