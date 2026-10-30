# Tasarım belgeleri

Belge **kaynak**, kod **uygulama**. Karar burada verilir, kod onu izler; kodlarken belgede bir hata çıkarsa ikisi aynı commit'te düzelir. Hangi tarafın eskidiğini insan değil test söyler: `flutter test test/belge_test.dart` ya da `dart run tool/belge/belge.dart`.

## Dosyalar

| Dosya | Kim yazar | Ne |
|---|---|---|
| `NN-ad.md` | insan | Kural belgesi. Numaralı, durumlu, sürümlü kararlar. Kaynak. |
| `NN-ad-tablosu.md` | `BelgeUretici` | Sayı tablosu. Koddan basılır, elle düzenlenmez. Bugün oyunun yaptığı şey. |
| `00-harita.md` | denetim | İzlenebilirlik matrisi: alan → karar → durum → kod. Kodlanacaklar ve ayrılmışlar listesi burada derlenir. |
| `borc-defteri.md` | defter | Kodlarken açığa çıkan sorular, varsayımlar ve borçlar. Elle yazılır; denetim saymaz, en sonda gözden geçirilir. |
| `karar-izi.json` | denetim | Her kararın metin parmak izi. Şüpheli bağlantı denetimi bunu okur. |
| `muhendislik/` | insan | Mühendislik günlüğü: gerekçeler, yaşanmış hatalar, ölçümler (kök README'den taşındı). Tarihsel; denetim alt klasörleri okumaz, karar buraya yazılmaz. |

Dosya adları ASCII, başlık ön bilgide. Türkçe karakterli dosya adı macOS ile Linux arasında normalizasyon sorunu çıkarır.

## Karar biçimi

```markdown
## 06.5 · Ana stat belirlenimci, alt statlar rastgele
Durum: kodda · s1 · ItemBudget.mainStatValue

Bütçe `anaStatPayi = 0,70` ile ikiye bölünür …
```

- Numara `alan.sıra`; alan numarası belgenin ön bilgisindeki `alan:` ile aynı olmak zorunda.
- `Durum:` satırı başlığın hemen altında. Değerler: **kodda** (kod uyguluyor, atıf zorunlu) · **belgede** (tasarlandı, kod izlemiyor, atıf olamaz) · **açık** (karar verilmedi, belge soruyu ve seçenekleri taşır) · **kaldırıldı** (geri alındı, tarih için durur) · **ayrılmış** (bilerek kodsuz: ileriye yer ayıran şema ya da süreç kuralı; atıf olamaz, kodlanacaklara girmez, haritada ayrı listelenir).
- `s1` kararın sürümü. Kararın **anlamı** değişince artar. Anlatım düzeltmesi sürüm artırmaz.
- Üçüncü parça serbest not: uygulayan sembol, açık sorunun özeti.

Karar başlıkları alanın sahiplendiği kararlardır; `tasarim_alanlari.dart` içindeki `sahiplendigi` listesi bu başlıklara eşit olmak zorunda. Belge kaynak, kod onu izler; denetim ayrışınca kodu gösterir.

## Atıf

Bir kararı uygulayan kod onu **sürümüyle** anar:

```dart
/// KARAR 06.5 s1
static double mainStatValue(...)
```

Atıf `packages/voidspace_core/lib`, `lib`, `server/lib` ve `tool/belge` altında aranır. Bir karar birden çok yerden anılabilir; bir yer birden çok karar anabilir. Test dizinleri (`packages/voidspace_core/test`, `test`, `server/test`) de taranır ama ayrı sayılır: test atıfı bir kararı **sınanmış** yapar, **kodda** yapmaz (16.8). Kodda olup hiçbir testin anmadığı kararlar haritada "Sınanmamış" başlığında; kök test bu sayının ilan edileni aşmadığını sınıyor.

## Sayı etiketi

Tepe tablodan gelen bir sayı belgede adıyla yazılır: `` `anaStatPayi = 0,70` ``. Denetim adı `TasarimGirdileri.hepsi` içinde bulur ve değeri yazılan ondalık kadar toleransla karşılaştırır. Türetilen bir sayı da etiketlenir (16.7): `` `mermiPvpTtk(6) = 5` `` ya da argümansız `` `sifonEtkinCarpani = 3,85` ``; ad `TuretilenKaydi.islevler` içinde bulunur, argümanla hesaplanır, aynı toleransla karşılaştırılır. Yüzde yazımı `` `mermiPveKazanci(6) = %10` `` oranı yüzle çarpar. Etiketsiz sayı serbesttir ama denetlenmez; belgedeki bir sayı ya girdi etiketi ya türetilen etiketi ya üretilen tablodadır.

Durumu **belgede** ya da **açık** olan bir kararda henüz kodda olmayan bir girdi etiketlenebilir; denetim orada "tepe tabloda yok" demez. Karar **kodda**ya geçtiği an aynı etiket doğrulanmaya başlar.

## Denetim — dört yön ve bir şüphe

| Bulgu | Ne oldu | Kim düzeltir |
|---|---|---|
| KOD ESKİMİŞ | Kod olmayan bir kararı anıyor, ya da eski bir sürümünü | kod |
| KOD ESKİMİŞ | `sahiplendigi` listesi belgeden ayrışmış | kod |
| BELGE ESKİMİŞ | "kodda" denen kararı kod anmıyor | belge (ya da kod, uygulandıysa) |
| BELGE ESKİMİŞ | "belgede/açık/ayrılmış" denen kararı kod anıyor | belge |
| BELGE ESKİMİŞ | Etiketli sayı tepe tabloyla ya da türetilen kaydıyla tutmuyor | belge |
| BELGE ESKİMİŞ | Borç defteri maddesi kaynaksız, ya da olmayan bir kararı anıyor | belge |
| BELGE ESKİMİŞ | Yan belge "taşındı" diyor ama hedef dosya yok | belge |
| BİÇİM | Borç maddesi durumsuz ya da tarihsiz; yan belge satırı bozuk | belge |
| ŞÜPHELİ | Karar metni değişti, sürüm artmadı | insan: sürümü artır ya da `dart run tool/belge/belge.dart --onayla` ile izi yenile |
| BİÇİM | Başlık, durum ya da ön bilgi bozuk | belge |

Üretilen dosyalar (tablolar, harita, iz) eskiyince denetim onları **yeniden yazar ve düşer**. Düşmesi bilerek: değişiklik commit'te görünmeli, sessizce geçmemeli. İkinci koşuda geçer.

## Obsidian

Vault kökü bu klasör. Ayarlar `.obsidian/app.json` içinde: standart markdown bağlantısı (wiki-link kapalı) ve göreli yol; böylece GitHub da Obsidian da aynı bağı okur. `workspace*.json` git dışı.

## Taşıma durumu

Belgeler claude.ai artifact'larından taşındı; on sekiz alanın on sekizi burada (on yedinci, Mermi, yan belgeden geldi; on sekizinci, Roket, borç defterindeki bir karardan doğdu). Her belgenin eski adresi ön bilgide `kaynak:` olarak durur, aşağıdaki tablo taşıma kaydı.

| Alan | Kural | Tablo | Durum |
|---|---|---|---|
| 01 Savaş Formülü | [01-savas-formulu.md](01-savas-formulu.md) | [01-savas-sayilari.md](01-savas-sayilari.md) | **taşındı** |
| 02 Stat Kütüphanesi | [02-stat-kutuphanesi.md](02-stat-kutuphanesi.md) | [02-stat-kaydi.md](02-stat-kaydi.md) | **taşındı** |
| 03 Stat Değeri | [03-stat-degeri.md](03-stat-degeri.md) | [03-deger-tablosu.md](03-deger-tablosu.md) | **taşındı** |
| 04 Gemi ve Yuvalar | [04-gemi-ve-yuvalar.md](04-gemi-ve-yuvalar.md) | [04-govde-tablosu.md](04-govde-tablosu.md) | **taşındı** |
| 05 Sağlayıcılar | [05-saglayicilar.md](05-saglayicilar.md) | üretici yok: eski tablo droid modeliydi | **taşındı** |
| 06 Eşya Kurgusu | [06-esya-kurgusu.md](06-esya-kurgusu.md) | [06-esya-tablosu.md](06-esya-tablosu.md) | **taşındı** |
| 07 Güçlendirme | [07-guclendirme.md](07-guclendirme.md) | [07-guclendirme-tablosu.md](07-guclendirme-tablosu.md) | **taşındı** |
| 08 Güç Bütçesi | [08-guc-butcesi.md](08-guc-butcesi.md) | [08-pay-tablosu.md](08-pay-tablosu.md) | **taşındı** |
| 09 Savaş Puanı | [09-savas-puani.md](09-savas-puani.md) | [09-br-tablosu.md](09-br-tablosu.md) | **taşındı** |
| 10 İlerleme ve Unvan | [10-ilerleme-ve-unvan.md](10-ilerleme-ve-unvan.md) | [10-merdiven-olcegi.md](10-merdiven-olcegi.md) | **taşındı** |
| 11 Haritalar | [11-haritalar.md](11-haritalar.md) | [11-bolge-tablosu.md](11-bolge-tablosu.md) | **taşındı** |
| 12 Düşman Kurgusu | [12-dusman-kurgusu.md](12-dusman-kurgusu.md) | [12-dusman-tablosu.md](12-dusman-tablosu.md) | **taşındı** |
| 13 Kaynak Akışı | [13-kaynak-akisi.md](13-kaynak-akisi.md) | [13-akis-tablosu.md](13-akis-tablosu.md) | **taşındı** |
| 14 Ganimet | [14-ganimet.md](14-ganimet.md) | [14-ganimet-tablosu.md](14-ganimet-tablosu.md) | **taşındı** |
| 15 Kazanç | [15-kazanc.md](15-kazanc.md) | [15-kazanc-tablosu.md](15-kazanc-tablosu.md) | **taşındı** |
| 16 Denge Denetimi | [16-denge-denetimi.md](16-denge-denetimi.md) | [16-tepe-tablo.md](16-tepe-tablo.md) | **taşındı** |
| 17 Mermi | [17-mermi.md](17-mermi.md) | [17-mermi-tablosu.md](17-mermi-tablosu.md) | **yan belgeden taşındı** |
| 18 Roket | [18-roket.md](18-roket.md) | [18-roket-tablosu.md](18-roket-tablosu.md) | **yeni alan** (B20) |

## Yan belgeler

`docs/` dışında yazılmış tasarımlar. Denetim bu tabloyu okur (16.9): `dışarıda` olanlar haritada "Dışarıda bekleyen" başlığında durur, `taşındı → dosya.md` denenlerin hedefi `docs/` altında olmak zorundadır. Dışarıda bir tasarım yazıldığı gün buraya bir satır; kodlanmadan önce içeri taşınır.

| Belge | Adres | Durum |
|---|---|---|
| Tasarım Alanları Haritası | https://claude.ai/code/artifact/c1f8a059-467c-479d-8f1c-32611c53ef69 | taşındı → 00-harita.md |
| Mermi | https://claude.ai/code/artifact/cae28d7c-a222-4d11-ab61-b0829dad9069 | taşındı → 17-mermi.md |
| Kademe Normalizasyonu | https://claude.ai/code/artifact/aff2df17-17e4-4a0c-90ed-f9f12f137808 | dışarıda |

## Dayanak

Mekanizmalar gereksinim izlenebilirliği alanından ödünç: sürümlü atıf ve eski sürümü anan kodun "eskimiş" sayılması OpenFastTrace'in `req~name~rev` kuralı; metin değişince bağlantının şüpheli olması Doorstop'un parmak izi; durum sözlüğü ADR'nin kabul/uygulandı ayrımı. Belgeyi kodla aynı depoda tutup testle denetlemek docs-as-code.
