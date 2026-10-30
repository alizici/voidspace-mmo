@Tags(['yabanci-anahtar', 'kapsam'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// KİMLİK ÇÖZÜMÜ — bir yaratığın kim olduğunu kim biliyor.
///
/// Bu testler bir HATADAN doğdu ve hatanın şekli önemli: kadro eklendiğinde
/// istemci hâlâ [AlienStats.byKind]'a soruyordu, o da tanımadığı her kimliği
/// SESSİZCE spore'a düşürüyor. Ölçüldüğünde serpilen on beş yaratığın
/// **sıfırı** doğru çözülüyordu — ve hiçbir test kırmızıya dönmemişti, çünkü
/// düşüşün kendisi geçerli bir cevap üretiyor.
///
/// Buradaki testlerin işi o sessizliği bozmak.
void main() {
  group('kadro kimlik çözümü', () {
    test('her kadro üyesi kendi kimliğinden bulunuyor', () {
      for (final y in YaratikKadrosu.hepsi) {
        expect(
          YaratikKadrosu.byKind(y.kind),
          same(y),
          reason: '${y.ad} (kind ${y.kind}) kadroda bulunamadı',
        );
      }
    });

    test('kimlikler benzersiz — çakışma çözümü sessizce yanlış yapardı', () {
      final kindler = YaratikKadrosu.hepsi.map((y) => y.kind).toList();
      expect(kindler.toSet().length, kindler.length);
    });

    test('kadro kimlikleri ESKİ kayıtlarla çakışmıyor', () {
      final eski = AlienStats.all.map((a) => a.kind).toSet();
      for (final y in YaratikKadrosu.hepsi) {
        expect(
          eski.contains(y.kind),
          isFalse,
          reason:
              '${y.ad} kind ${y.kind} eski kayıtla çakışıyor; '
              'yaricapFor onu eski tabloya düşürürdü',
        );
      }
    });

    test('yaricapFor kadro üyesinde MODELİ veriyor, sanat sabitini değil', () {
      for (final y in YaratikKadrosu.hepsi) {
        expect(YaratikKadrosu.yaricapFor(y.kind), y.yaricap);
      }
    });

    test('yaricapFor eski kayıtlarda eski tabloya düşüyor', () {
      for (final a in AlienStats.all) {
        expect(YaratikKadrosu.yaricapFor(a.kind), a.radius);
      }
    });

    test('serpilen her yaratık KENDİ yarıçapını alıyor', () {
      // Hatanın ta kendisi: bu liste bir zamanlar TAMAMEN spore'a düşüyordu.
      //
      // İlk hâli `isNot(spore.radius)` diye yazılmıştı ve mutasyon sınaması
      // kusuru gösterdi: boss Kurvex'in yarıçapı da tam 24, yani "spore'a
      // düştü" ile "tesadüfen aynı genişlikte" ayırt edilemiyordu. Doğru
      // özellik sayı değil ÇÖZÜM: yaratık kendi kaydını buluyor mu.
      final serpilen = YaratikKadrosu.serpilenler(Turetilenler.bolgeSayisi);
      expect(serpilen, isNotEmpty);
      for (final y in serpilen) {
        expect(
          YaratikKadrosu.byKind(y.kind),
          isNotNull,
          reason: '${y.ad} kadroda çözülemiyor',
        );
        expect(
          YaratikKadrosu.yaricapFor(y.kind),
          y.yaricap,
          reason:
              '${y.ad} kendi yarıçapını almıyor — düzeltilen hata geri geldi',
        );
      }
    });
  });

  group('serpilenler', () {
    test('boss DA beliriyor — randevu bağlandı', () {
      // Bir zamanlar tersini söylüyordu. Boss ızgaradan değil randevuyla
      // geliyor (`HaritaKaydi.bossBekliyor` → `Zone.bossDogur`), ama dünyada
      // görünüyor — ölçülen şey doğuş yolu değil, görünürlük.
      final serpilen = YaratikKadrosu.serpilenler(Turetilenler.bolgeSayisi);
      expect(serpilen.any((y) => y.sinif == DusmanSinifi.boss), isTrue);
      // Her bölgenin boss'u sayıda: bölge başına tam bir tane.
      expect(
        serpilen.where((y) => y.sinif == DusmanSinifi.boss).length,
        Turetilenler.bolgeSayisi,
      );
    });

    test('ulaşılamayan bölgenin yaratığı serpilmiyor', () {
      final serpilen = YaratikKadrosu.serpilenler(Turetilenler.bolgeSayisi);
      for (final y in serpilen) {
        expect(y.bolge, lessThan(Turetilenler.bolgeSayisi));
      }
    });

    test('bölge sayısı büyüyünce serpilen de büyüyor', () {
      // Sayıyı SABİTLEMİYOR, İLİŞKİYİ sabitliyor: dünya uzadığında kadro
      // kendiliğinden açılmalı, elle bir liste güncellenmemeli.
      final dar = YaratikKadrosu.serpilenler(1).length;
      final genis = YaratikKadrosu.serpilenler(8).length;
      expect(genis, greaterThan(dar));
      expect(
        genis,
        YaratikKadrosu.hepsi.length,
        reason: 'sekiz bölgede kadronun tamamı belirebilmeli',
      );
    });

    test('sıfır bölgede kimse serpilmiyor', () {
      expect(YaratikKadrosu.serpilenler(0), isEmpty);
    });
  });

  group('denetim satırı', () {
    test('"serpilen yaratık" CANLI ölçüyor, elle liste okumuyor', () {
      final satir = DengeDenetimi.sistemler.firstWhere(
        (s) => s.ad == 'serpilen yaratık',
      );
      expect(
        satir.mevcut,
        YaratikKadrosu.serpilenler(Turetilenler.bolgeSayisi).length,
      );
      expect(satir.hedef, YaratikKadrosu.hepsi.length);
      // Eski hâli buydu ve YANLIŞTI: 2 diyordu, doğrusu 15.
      expect(
        satir.mevcut,
        isNot(AlienStats.all.length),
        reason: 'satır yine elle tutulan eski listeyi ölçüyor',
      );
    });
  });
}
