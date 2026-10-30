---
ad: Çizim mimarisi
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Çizim mimarisi

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.

Tek cümle: **kare başına çizim maliyeti gemi sayısından bağımsızdır.**

Prosedürel sanat hâlâ tek gerçek ama artık bir ÇİZİCİ değil, bir **doku
üreticisi.** `tool/ship_atlas_test.dart` gemiyi üç katman ve bütün
kademeleriyle `assets/ship_atlas.png`'ye pişiriyor — `app_icon.png` ile aynı
desen, yani depoda kökeni bilinmeyen ikili dosya yok kuralı duruyor.

Çalışma zamanında geriye kalan üç çağrı:

```
drawRawAtlas(motorlar)  ·  drawRawAtlas(gövdeler)  ·  drawRawAtlas(kalkanlar)
```

Bunu ayakta tutan kararlar:

- **Katmanlar ayrı pişiyor.** Motorun itkiye tepkisi (pluma üç katına çıkar,
  hızlı titrer) gövdeninkinden bambaşka. Aynı hücreye pişirilselerdi plumanın
  ihtiyaç duyduğu kare sayısı gövdeye de ödetilir ve atlas üç katı olurdu.
  Hücre boyutları tahmin değil: her katman ayrı ayrı çizilip saydam olmayan
  sınırı ölçüldü.
- **Kademeler çapraz sönümleniyor.** İtki için dört kademe var; en yakınını
  seçmek rampa boyunca dört görünür sıçrama üretiyordu. İki komşu kareyi üst
  üste harmanlamak sürekli bir geçiş veriyor, bedeli iki kat dörtgen.
- **Titreşim kareleri gidip geliyor** (0,1,2,3,2,1). Düz döngü son kareden
  ilkine atlarken sıçrardı, çünkü prosedürel gürültü periyodik değil.
- **Faz gemi kimliğine göre kayıyor.** Aynı fazdaki kırk gemi tek bir organizma
  gibi nefes alır ve bu, hareketin kendisinden çok dikkat çeker.
- **Ekran dışı çizilmiyor.** İlgi alanı yarıçapı 2600 birim ama telefonda
  dikey görüş alanı ~670 birim: sunucunun yolladığı gemilerin çoğu ekranda
  değil ve mobil GPU'da bedeli en yüksek şey saydam dolgu.
- **Boştaki gemide motor katmanı atlanıyor.** En büyük dörtgen o ve duran
  gemide taşıdığı tek şey görünmeyen bir parıltı.
- **Kare yolunda tahsis yok.** Pozlar havuzlanmış, çizim tamponları
  `Float32List` ve yeniden kullanılıyor. 40 gemi × 120 Hz'de kare başına
  nesne ayırmak saniyede binlerce kısa ömürlü nesne eder; Dart'ın çöp
  toplayıcısı duraklattığında duraklattığı şey kare döngüsüdür.

Kaliteden ne kaybedildiği [tool/atlas_parity.png](../../tool/atlas_parity.png)
görsel referansında yan yana duruyor: üst sıra prosedürel, alt sıra atlas.
