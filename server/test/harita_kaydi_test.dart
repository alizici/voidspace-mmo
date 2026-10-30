@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/harita_kaydi.dart';

/// HARİTA KAYDI — base/cell ayrımının değişmezleri.
///
/// Ayrımın tek gerekçesi var: **simülasyon geçici, durum kalıcı.** Bu
/// testlerin işi o cümlenin iki yarısını da korumak — hücrenin gerçekten
/// gidebildiğini ve giderken durumu götürmediğini.
void main() {
  group('base/cell · hücre ömrü', () {
    test('hücre kendiliğinden AÇILMIYOR — boş harita bedava', () {
      // Kırılırsa: yirmi dört harita baştan kuruluyor ve tik başına 384
      // yaratık adımı dönüyor, hiçbirinde kimse olmasa bile.
      final defter = HaritaDefteri();
      expect(defter.canlilar, isEmpty);
      for (final kayit in defter.hepsi) {
        expect(kayit.canli, isFalse, reason: '${kayit.harita.ad} hücresi açık');
      }
    });

    test('ac() aynı hücreyi veriyor — ikinci oyuncu yeni dünya kurmuyor', () {
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      final ilk = kayit.ac(100);
      expect(identical(kayit.ac(200), ilk), isTrue);
      expect(ilk.tick, 100, reason: 'ikinci çağrı saati geri aldı');
    });

    test('hücre sunucunun SAATİNDEN başlıyor — sıfırdan değil', () {
      // Kırılırsa: geç açılan bir haritaya giren herkes anında "sessiz"
      // sayılıyor, çünkü `tick - lastHeardTick` eksi çıkıyor.
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      expect(kayit.ac(54321).tick, 54321);
    });

    test('DOLU hücre kapanmıyor', () {
      // Kırılırsa: içinde oyuncu olan bir harita yok ediliyor ve o oyuncular
      // dünyadan siliniyor.
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      final hucre = kayit.ac(0);
      hucre.join('Ada');
      expect(kayit.kapat(), isFalse);
      expect(kayit.canli, isTrue);
    });

    test('boş hücre kapanıyor ve tekrar açılabiliyor', () {
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      final ilk = kayit.ac(0);
      expect(kayit.kapat(), isTrue);
      expect(kayit.canli, isFalse);
      expect(identical(kayit.ac(0), ilk), isFalse, reason: 'eski hücre döndü');
    });

    test('aynı harita her açılışta AYNI sürüyü doğuruyor', () {
      // Hücre ömürlü olduğu için tohum haritadan geliyor. Rastgele olsaydı
      // "bir hatayı iki kez görebilmek" özelliği hücre kapandığında kaybolurdu.
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      final once = kayit.ac(0).aliens.map((k, v) => MapEntry(k, v.position));
      kayit.kapat();
      final sonra = kayit.ac(0).aliens.map((k, v) => MapEntry(k, v.position));
      expect(sonra.length, once.length);
      for (final id in once.keys) {
        expect(sonra[id], once[id], reason: '$id başka yerde doğdu');
      }
    });

    test('farklı haritalar farklı sürü — hepsi aynı yerde değil', () {
      final a = HaritaKaydi(Harita(Bolge.ilk, HaritaTipi.pve)).ac(0);
      final b = HaritaKaydi(Harita(Bolge.ilk, HaritaTipi.pvp)).ac(0);
      final ayni = a.aliens.keys.every(
        (id) => a.aliens[id]!.position == b.aliens[id]!.position,
      );
      expect(ayni, isFalse, reason: 'iki harita aynı sürüyü doğuruyor');
    });

    test('yaratık sayısı BÖLGEDEN — elle konmuş 36 değil', () {
      for (final bolge in Bolge.hepsi) {
        final kayit = HaritaKaydi(Harita(bolge, HaritaTipi.pve));
        expect(kayit.ac(0).aliens.length, bolge.hedefSayisi);
      }
    });

    test('hücrenin dünyası BÖLGENİN haritası', () {
      for (final bolge in Bolge.hepsi) {
        final kayit = HaritaKaydi(Harita(bolge, HaritaTipi.boss));
        expect(kayit.ac(0).world.width, bolge.harita.width);
        expect(kayit.ac(0).world.height, bolge.harita.height);
      }
    });
  });

  group('base/cell · kimlik uzayı', () {
    test('iki haritanın gemi kimlikleri ÇAKIŞMIYOR', () {
      // Kırılırsa: `_sessions` gemi kimliğiyle anahtarlı ve bir haritadaki
      // oyuncunun oturumu başka haritadaki gemiye bağlanıyor. Ödüller yanlış
      // hesaba yazılıyor ve hiçbir hata mesajı çıkmıyor.
      final kimlikler = <int>{};
      for (final harita in Harita.hepsi) {
        final hucre = HaritaKaydi(harita).ac(0);
        for (var i = 0; i < 8; i++) {
          final gemi = hucre.join('oyuncu$i');
          expect(gemi, isNotNull);
          expect(
            kimlikler.add(gemi!.id),
            isTrue,
            reason: '${harita.ad} ${gemi.id} kimliğini tekrar dağıttı',
          );
        }
      }
    });

    test('bütün paylar kimlik UZAYINA sığıyor', () {
      // Sonuç testi: harita sayısı arttığında pay daralıyor ama taşma olmuyor.
      final sonHarita = Harita.hepsi.length - 1;
      final ustSinir =
          1 + sonHarita * HaritaKaydi.kimlikAraligi + HaritaKaydi.kimlikAraligi;
      expect(ustSinir, lessThanOrEqualTo(Protocol.maxShipId + 1));
    });

    test('pay KAPASİTEDEN geniş — harita dolduğunda kimlik bitmiyor', () {
      final hucre = HaritaKaydi(HaritaDefteri.baslangic).ac(0);
      expect(HaritaKaydi.kimlikAraligi, greaterThan(hucre.capacity));
    });

    test('gemi kimliği haritayı ELE VERİYOR — hata ayıklama yan faydası', () {
      for (var i = 0; i < Harita.hepsi.length; i++) {
        final gemi = HaritaKaydi(Harita.hepsi[i]).ac(0).join('Ada')!;
        expect((gemi.id - 1) ~/ HaritaKaydi.kimlikAraligi, i);
      }
    });
  });

  group('base/cell · kalıcı durum', () {
    test('boss saati HÜCREYİ AŞIYOR — ayrımın tek gerekçesi', () {
      // Bu test base/cell bölmesinin varlık sebebi. Sayaç hücrede dursaydı
      // burada sıfırlanırdı ve boss ancak birileri iki saat boyunca haritada
      // beklerse doğardı.
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      kayit.ac(0);
      kayit.bossDogdu(1000);
      kayit.kapat();
      kayit.ac(2000);
      expect(kayit.bossSonDogusTik, 1000);
    });

    test('hiç boss doğmamış harita BORÇLU', () {
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      expect(kayit.bossSonDogusTik, isNull);
      expect(kayit.bossBekliyor(0), isTrue);
    });

    test('boş haritada da saat İŞLİYOR — kimse izlemese de', () {
      // Sonuç testi: iki saat kimsenin girmediği haritaya giren oyuncu
      // bekleyen boss'u buluyor. Hücre hiç açılmadı, sayaç yine de doldu.
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      kayit.bossDogdu(0);
      expect(kayit.bossBekliyor(kayit.bossAraligiTik - 1), isFalse);
      expect(kayit.bossBekliyor(kayit.bossAraligiTik), isTrue);
    });

    test('boss aralığı 12\'nin türettiği iki saat — elle yazılmıyor', () {
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      final saat = kayit.bossAraligiTik / Protocol.tickRate / 3600;
      expect(saat, closeTo(2.0, 0.01));
    });

    test('aralık BÜTÜN bölgelerde aynı — öğrenilebilir ritim', () {
      // 12'nin bulgusu: grup, süre, prim ve gelir payı sabit tutulduğunda
      // aralık bantlardan bağımsız çıkıyor. Burada bölgeler arası korunuyor.
      final araliklar = {
        for (final bolge in Bolge.hepsi)
          HaritaKaydi(Harita(bolge, HaritaTipi.boss)).bossAraligiTik,
      };
      expect(araliklar.length, 1, reason: 'aralık bölgeye göre değişiyor');
    });
  });

  group('base/cell · defter', () {
    test('defter BÜTÜN haritaları tanıyor', () {
      final defter = HaritaDefteri();
      expect(defter.hepsi.length, Harita.hepsi.length);
      for (final harita in Harita.hepsi) {
        expect(defter[harita].harita, harita);
      }
    });

    test('canlılar yalnız açık hücreler', () {
      final defter = HaritaDefteri();
      defter[HaritaDefteri.baslangic].ac(0);
      expect(defter.canlilar.length, 1);
      expect(defter.canlilar.first.harita, HaritaDefteri.baslangic);
    });
  });
}
