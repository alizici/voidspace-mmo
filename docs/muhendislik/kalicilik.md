---
ad: Kalıcılık
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Kalıcılık

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.

## Veri nerede

**Veri nerede.** Bugün `data/accounts.json` — tek süreç için doğru çalışan bir
dosya. Biçim **satır başına bir hesap** (JSON Lines), tek bir dizi değil; sebep
ölçüldü:

| hesap | `jsonEncode` + yaz | 33 ms tik bütçesinin |
|---|---|---|
| 1.000 | 1.8 ms | %6 |
| 5.000 | 6.1 ms | %18 |
| 20.000 | 29.0 ms | **%87** |

Diziyi her kayıtta baştan kodlamak, yirmi bin hesapta tek bir kaydın bütün
kareyi yemesi demekti — ve bunu hisseden, o sırada oynayan herkes olurdu.
Satır eklemenin maliyeti hesap sayısından bağımsız. Eski dizi biçimi **okunmaya
devam ediyor** ve ilk fırsatta dönüştürülüyor: biçim değişikliği yüzünden
gerçek oyuncuları silmek kabul edilemez.

Değiştirmenin gerçek tetikleyicisi ikinci sunucu süreci: iki süreç aynı
dosyaya yazamaz. O gün PostgreSQL gelecek; konum ve kalkan gibi kare başına
değişen hiçbir şey oraya YAZILMAYACAK, yalnız ilerleme ve hesap.

## Sıkıştırma — ödül sisteminin açtığı gedik

Satır ekleme yazmayı O(1) yapıyor ve şişme bir kez KABUL EDİLMİŞTİ. O karar,
yazmaların oyuncu EYLEMİYLE olduğu zamandan: satın alma, yükseltme — seyrek.
**Ödül sistemi bunu temelden değiştirdi:** aktif oyuncu her imhada kirleniyor,
yani beş saniyede bir tam hangar satırı ekleniyor.

Ölçüldü — `data/hangars.jsonl`: **107 satır, 4 hesap. %96 ölü satır, 383 KB.**
Yükleme maliyeti doğrusal (5.000 satır 53 ms · 80.000 satır 214 ms), yani
yansıtınca:

| süre (60 oyuncu) | satır | boyut | açılış |
|---|---|---|---|
| 1 saat | 43 bin | 15 MB | ~110 ms |
| 1 hafta | 2,4 milyon | 890 MB | ~6 sn |
| 1 ay | ~10 milyon | 3,8 GB | ~25 sn |

Oyuncu sayısıyla değil **ZAMANLA** büyüyen bir maliyet — ve PostgreSQL şeklinde
bir sorun değil, sıkıştırma şeklinde. Çözüm Redis'in AOF yeniden yazımı ve
Kafka'nın log compaction'ıyla aynı üç parça:

- **Anahtar başına son değer.** Yaşayan hâl zaten bellekte; sıkıştırma onları
  tek seferde yazmaktan ibaret, dosyayı okumayı bile gerektirmiyor.
- **Oran tetikli, zamanla değil.** `compactMinLines` (200) + `compactGrowthFactor`
  (2): Redis'in `auto-aof-rewrite-min-size` + `auto-aof-rewrite-percentage`
  ikilisinin aynısı. Küçük dosyayı sıkıştırmak kazanç değil sırf I/O.
- **Atomik değiştirme.** Geçici dosyaya yaz, `rename` ile yerine koy. Yerinde
  kısaltmak, tam o anda çöken bir süreçte bütün ilerlemenin kaybolması
  demekti; `rename` POSIX'te atomik — ya eski dosya bütün hâlde kalır ya yeni.

Ayrıca aynı içerik iki kez yazılmıyor ve açılışta sıkıştırılıyor (sunucu zaten
bekliyor, oyuncu yok, dosya en şişkin hâlinde).

Gerçek veri üzerinde doğrulandı: **383 KB → 6 KB**, dört hesabın hepsi yerinde.

**`ledger.jsonl` sıkıştırılMIYOR ve bu bilinçli.** O bir durum değil GEÇMİŞ;
silinebilen bir defter kanıt olmaz. Büyümesi doğru ve kaçınılmaz — ona gereken
şey tarihe göre döndürme, ve çalışma zamanında hiç okunmadığı için acil değil.
`accounts.json` da dokunulmadı: 40 satır, 40 hesap — ekleme baskın, ölü satır
yok.
