---
ad: Üç dil
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Üç dil

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.

Türkçe, İngilizce, İtalyanca. Dil cihazdan çözülüyor, oyuncu kimlik ekranından
değiştiriyor, tercih diske yazılıyor — kayıtlı seçim cihazın dilini YENER.
Tanınmayan bir cihaz dilinde düşülen yer İngilizce, Türkçe DEĞİL: Türkçe
bilmeyene Türkçe göstermek, hiç çeviri yapmamakla aynı sonucu verir.

**Eksik çeviri DERLENMİYOR.** 201 arayüz metni tek bir enum'da
([`Metin`](../../lib/dil/metin.dart)) ve her değer üç dizeyi BİRDEN taşıyor; ikisini
verip üçüncüsünü unutmak çalışma zamanı boşluğu değil derleme hatası. Dize
anahtarlı bir sözlükte aynı hatayı ancak İtalyanca oynayan biri bulurdu.

**Sunucunun dili yok ve olmayacak.** Telde cümle değil KOD gidiyor —
`kimlik.hatali-giris`, `gecit.br|4200` — cümleyi dili bilen taraf kuruyor;
sayılar bile telden gelmiyor, kurallar zaten paylaşılan pakette. Aynı kararla
`voidspace_core` dile hiç dokunmadı: oradaki Türkçe etiket tasarım
belgelerinin kanonik adı. Oyuncunun gördüğü içerik adları
([`icerik.dart`](../../lib/dil/icerik.dart)) KİMLİKTEN çevriliyor — görünen metne
bakan bir çeviri, çekirdekte bir etiket düzeltilince sessizce Türkçeye düşerdi.

**Sayı da dile bağlı.** `12.400` Türk ve İtalyan için on iki bin dört yüz,
İngiliz için on iki nokta dört: çeviri hatası değil VERİ hatası. Yüzdenin
işareti de dilin koyduğu yerde (`%15` ↔ `15%`). Çevrilmeyenler kasıtlı —
gövdeler (Bastion), yaratıklar (Interdictor), unvanlar (Squire) ve kodlar
(MR-1, C-II, NOVA) özel ad; çevirmek onları konuşulamaz hâle getirirdi.
