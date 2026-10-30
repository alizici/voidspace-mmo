GÖVDE TASARIM SPRITE'LARI
═════════════════════════

Köken: ~/voidspace2 — `assets/ships/previews/*.png`, katalog gemilerinin
üstten görünüş çizimleri. Bu depoda "kökeni bilinmeyen ikili dosya yok"
kuralı gereği kaynağı buraya yazılı (bkz. leviathan_strip.README.txt).

Her biri 512×512 RGBA. Tasarım uzayındaki ölçüleri koda gömülü DEĞİL —
`lib/game/art/govde_tasarimlari.dart` içinde ileri/geri erişim olarak
duruyor ve sprite oraya göre ölçekleniyor.

DİKKAT — İSİM ÇAKIŞMASI
───────────────────────
`bastion.png` bu projenin `lib/game/art/bastion.dart` gemisi DEĞİLDİR.

  · assets/ships/bastion.png   → voidspace2 katalog sprite'ı, kademe 3
                                 (gövde adı "Spectre")
  · lib/game/art/bastion.dart  → bu projenin prosedürel eriyik-VFX gemisi,
                                 kademe 8 (gövde adı "Sovereign")

Üçüncü bir "Bastion" daha var ve o da başka: kademe 1 gövdesinin ADI
"Bastion" (HullClass.adlar[0]). Üçü ayrı şey; kayıt dosyasındaki test
ayrıştıklarını doğruluyor.

Prosedürel iki tasarımın (Dagon · E-Ambassador) sprite'ı YOK ve olmayacak:
gövdeleri kodla çiziliyor. Kodları henüz bu projeye taşınmadı.
