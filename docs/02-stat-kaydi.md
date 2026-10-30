---
alan: 2
ad: Stat Kaydı
tur: tablo
kural: 02-stat-kutuphanesi.md
---
<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->

# 02 · Stat Kaydı

Kural belgesi: [02 · Stat Kütüphanesi](02-stat-kutuphanesi.md). Koddan üretilir: kütüphanenin bugünkü hâli, sekiz alanıyla. Tasarlanan tablo kural belgesinde (02.7); test ikisini satır satır karşılaştırır.

## Açık · 15 kimlik

| Kimlik | Etiket | Katman | Kanal | Birim | Kapsam | Eş | Alt stat | Havuzda | Fiyatlı |
|---|---|---|---|---|---|---|---|---|---|
| `taban_hasar` | Taban hasar | L0 | saldırı | mutlak | gemi · droid · roket | hasar_artisi | — | — | evet |
| `hasar_artisi` | Hasar artışı | L1 | saldırı | oran | gemi · droid | taban_hasar | ✓ | pl1 · pl3 · pl4 · pl5 | evet |
| `atis_hizi` | Atış hızı | L1 | saldırı | oran | gemi · droid | taban_hasar | ✓ | pl1 · pl3 · pl4 · pl5 · mk1 · cpu_scope · dr1 · dr5 | evet |
| `menzil` | Menzil | L1 | sistem | oran | gemi · droid | hiz | ✓ | pl1 · pl3 · pl4 · pl5 · df1 · df3 · df5 · th1 · th3 · mk1 · cpu_repair · dr1 · dr5 | evet |
| `govde_cani` | Gövde | L0 | savunma | mutlak | gemi · droid | zirh | ✓ | df1 · df3 · df5 · th1 · th3 · cpu_repair · dr1 · dr5 | evet |
| `kalkan` | Kalkan | L0 | savunma | mutlak | gemi · droid | kalkan_yenilenmesi | ✓ | th1 · th3 · cpu_repair | evet |
| `kalkan_yenilenmesi` | Kalkan yenilenmesi | L1 | savunma | oran | gemi | kalkan | ✓ | df1 · df3 · df5 · th1 · th3 · cpu_scope | evet |
| `hiz` | Hız | L1 | sistem | oran | gemi | itki_dolumu | ✓ | pl1 · pl3 · pl4 · pl5 · df1 · df3 · df5 · mk1 · cpu_repair · cpu_scope | evet |
| `itki_dolumu` | İtki dolumu | L1 | sistem | oran | gemi | hiz | ✓ | — | evet |
| `kritik_sansi` | Kritik şansı | L3 | saldırı | oran | gemi · droid | kritik_hasari | ✓ | pl1 · pl3 · pl4 · pl5 · mk1 · cpu_scope · dr1 · dr5 | evet |
| `kritik_hasari` | Kritik hasarı | L3 | saldırı | oran | gemi · droid | kritik_sansi | ✓ | pl1 · pl3 · pl4 · pl5 · mk1 · dr1 · dr5 | evet |
| `zirh` | Zırh | L4 | savunma | egri | gemi · droid | govde_cani | ✓ | df1 · df3 · df5 · th1 · th3 · cpu_repair · cpu_scope · dr1 · dr5 | evet |
| `kacinma` | Kaçınma | L4 | savunma | egri | gemi | zirh | ✓ | df1 · df3 · df5 · th1 · th3 · cpu_repair · cpu_scope | evet |
| `son_hasar` | Son hasar | L5 | saldırı | mutlak | gemi | karşı: son_azaltma | ✓ | pl1 · pl3 · pl4 · pl5 · mk1 | evet |
| `son_azaltma` | Son azaltma | L5 | savunma | mutlak | gemi | karşı: son_hasar | ✓ | df1 · df3 · df5 · th1 · th3 · cpu_repair · cpu_scope | evet |

## Ayrılmış · 7 kimlik

Kayıtta yazılı, kapalı (02.6): kimlik aramasında yok, hiçbir havuzda yok, fiyatsız. Katman ve eş ilk yerleşim; kafes yazılırken yeniden açılır.

| Kimlik | Etiket | Katman | Kanal | Birim | Kapsam | Eş | Alt stat |
|---|---|---|---|---|---|---|---|
| `delici` | Delici | L4 | saldırı | oran | gemi · droid | karşı: sertlik | ✓ |
| `sertlik` | Sertlik | L4 | savunma | egri | gemi · droid | karşı: delici | ✓ |
| `kirici` | Kırıcı | L4 | saldırı | oran | gemi · droid | karşı: zirh_katmani | ✓ |
| `zirh_katmani` | Zırh katmanı | L4 | savunma | egri | gemi · droid | karşı: kirici | ✓ |
| `kritik_direnci` | Kritik direnci | L3 | savunma | oran | gemi · droid | karşı: kritik_sansi | ✓ |
| `durum_hasari` | Durum hasarı | L2 | saldırı | oran | gemi · droid | karşı: durum_azaltma | ✓ |
| `durum_azaltma` | Durum azaltma | L2 | savunma | oran | gemi · droid | karşı: durum_hasari | ✓ |

Kapsamlar (`StatScope`): `gemi` · `droid` · `roket` · `kuresel`. Anahtar `kimlik@kapsam`; kayıt dışı kapsama yazmak reddedilir.

