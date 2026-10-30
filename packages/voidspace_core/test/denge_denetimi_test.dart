@Tags(['kod-belge', 'kapsam'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 16 · DENGE DENETİMİ — sistemin kendi kendini kontrol ettiği yer.
///
/// Bu dosya yeni bir kural üretmiyor: on beş alanın "bu kırılırsa ne olur"
/// tablolarını bir araya getiriyor ve sistemin BÜTÜNÜNE dair olanları
/// çalıştırıyor.
///
/// **Denetimin yakalayamadığı şey de yazılı olmalı:** sıkıcı olup olmadığını,
/// savaşın iyi hissettirip hissettirmediğini, ve sayıların DOĞRU olup
/// olmadığını. Bütün sistem tutarlılık üzerine kurulu, doğruluk üzerine
/// değil.
void main() {
  group('alan 16 · tepe tablo', () {
    test('her girdi BENZERSİZ — iki isim aynı kararı taşımıyor', () {
      // Denetimin ilk çalıştırmasında bulduğu hata sınıfı: iki isim aynı
      // kararı taşıyor, ikisi de aynı değerde olduğu için bugün hiçbir şey
      // bozulmuyor — ama biri değiştirilirse diğeri sessizce eski değerde
      // kalıyor.
      expect(DengeDenetimi.cakisanGirdiler, isEmpty);
    });

    test('her girdinin GEREKÇESİ yazılı', () {
      // Gerekçe süs değil: bir sayının neden o değer olduğu yazılmadığında,
      // bir sonraki denge turunda gerekçe sayıya uydurulmaya başlar.
      expect(DengeDenetimi.gerekcesizGirdiler, isEmpty);
    });

    // KARAR 16.3 s1
    test('girdi sayısı ilan edilen 107\'de', () {
      // Sayı değiştiğinde bu test PATLAMALI: her yeni girdi bilinçli bir karar
      // ve bu satır onu görünür kılıyor.
      //
      // Bir ara 93 oldu: geçit yarıçapı için `gecisSaniyesi` eklenmişti.
      // Gereksizdi — ölçü zaten var olan `GameWorld.margin`'den çıkıyor.
      // Girdi eklemek en son çare; önce var olanlardan türetilebiliyor mu
      // diye bakılmalı.
      // 94: alan 03'ün beş fiyat girdisi türetilene döndü (karar 03.1), alan 04'e
      // hız merdiveni ve sanat kısıtı (04.9, 04.12), alan 06'ya kalite bantları ve
      // garantili alt stat (06.10) geldi; NOVA çevirme fiyatı türetilene döndü
      // (15.3).
      // 95: itki dolumu kütüphaneye girdi, sistem katsayısı tepe tabloya döndü
      // (09.5). Sonra gövde çapası TTK'dan türetilene döndü ve referans lazerin
      // namlu hasarı koddaki sabitten tabloya taşındı (08.5): sayı değişmedi.
      // 101: droid geldi — filo tavanı (04.10), σ ve formasyon takası
      // (05.5, 05.9), droid payı (08.1), droidin iki katsayısı (09.6).
      // Sayı ilan: her yeni girdi bilinçli olsun.
      // 105: mermi geldi (17) — taban fiyat, üs, çarpan tavanı, sifon
      // çarpanı. İki kilit (MR-1 bedava, NOVA mermi satmıyor) sayılmıyor:
      // kilitler tepe tablonun girdisi değil, öteki kilitler gibi.
      // 106: pay bandı (08.3 s2) — üç puan yapısal olarak tutmadı, on oldu.
      // 105: referans lazer hasarı girdi olmaktan çıktı, bütçeden türüyor
      // (04.5 s2); referans katalogdaki C-I lazeri kullanıyor.
      // 106: ilk unvan eşiği girdi oldu (10.3); savaş katmanı referansı
      // okuyamıyor, tabanı buradan okuyor.
      // 107: roket aralığı (18.1); roketatar silah oldu.
      // 108: droid aşınma payı (05.10); droidin canı değil sayacı var.
      // 110: droid yuvası ve elit droid yuvası (05.4 s5); droid bir
      // taşıyıcı oldu. Donanım payı girdi DEĞİL, çözülüyor.
      // 111: başlangıç eşya sayısı (15.8); başlangıç kredisi raftan türüyor.
      // 113: tasarım ve formasyon NOVA fiyatı (15.9); görünüş satılıyor.
      // 114: ArGe aktarım adımı (05.7 s2); ağaç yön veriyor, güç değil.
      expect(DengeDenetimi.girdiSayisi, 114);
    });

    test('hiçbir alan kendi kısıtını kendisi belirlemiyor', () {
      // Girdi sayısı çok yüksekse alan muhtemelen kendi kısıtını kendisi
      // koyuyor demektir — ve o durumda kısıt kısıt olmaktan çıkar.
      //
      // Eşik gevşek çünkü bazı alanların girdileri KATEGORİK: alan 12'nin
      // on dokuz girdisinin dokuzu üç sınıfın hız/menzil/süre oranları, yani
      // üç karar değil bir kararın dokuz yüzü.
      for (final e in DengeDenetimi.girdiDagilimi.entries) {
        expect(
          e.value,
          lessThanOrEqualTo(20),
          reason: 'alan ${e.key} ${e.value} girdi koyuyor',
        );
      }
      expect(DengeDenetimi.ortalamaGirdi, lessThan(10));
    });

    test('girdiler yalnız YAZILMIŞ alanlardan geliyor', () {
      for (final g in TasarimGirdileri.hepsi) {
        expect(
          TasarimHaritasi.byNo(g.alan)?.durum,
          BelgeDurumu.yazildi,
          reason: '${g.ad} yazılmamış alan ${g.alan}\'dan geliyor',
        );
      }
    });
  });

  group('alan 16 · karar döngüleri', () {
    // KARAR 16.2 s1
    test('dört döngünün DÖRDÜ de kapalı', () {
      // Geri kenar bir değer değil bir KARAR taşıyor: alt alan soruyu yukarı
      // gönderiyor, üst alan cevabı veriyor, ve cevap verildikten sonra kenar
      // kayboluyor. Grafik çalışma zamanında döngüsüz.
      //
      // Kapatılmamış bir döngü ise gerçek bir veri döngüsüdür ve çözülemez:
      // sayılar ya yakınsamaz ya keyfî bir başlangıca bağlı kalır.
      expect(DengeDenetimi.dongular, hasLength(4));
      for (final d in DengeDenetimi.dongular) {
        expect(d.kapali, isTrue, reason: '$d açık kalmış');
      }
    });

    test('her döngünün iki ucu da YAZILMIŞ alan', () {
      for (final d in DengeDenetimi.dongular) {
        for (final no in [d.soran, d.cevaplayan]) {
          expect(TasarimHaritasi.byNo(no)?.durum, BelgeDurumu.yazildi);
        }
      }
    });
  });

  group('alan 16 · yazılma sırası', () {
    test('hiçbir alan okuduğu alandan ÖNCE yazılmamış', () {
      expect(DengeDenetimi.sirasizYazilanlar, isEmpty);
    });

    test('on altı alanın hepsi yazıldı', () {
      expect(DengeDenetimi.tamamlanmaOrani, 1.0);
      expect(DengeDenetimi.yazilanlar.length, TasarimHaritasi.hepsi.length);
    });
  });

  // ══ Belgenin ilan ettiği sekiz SAYI BORCU ══════════════════════════
  //
  // Hiçbiri bir hata değildi: hepsi yazıldıkları gün doğruydu ve bir üst
  // alandaki karar değiştiğinde bayatladı. Denetimin varlık sebebi tam olarak
  // bu — doğru sayıların ne zaman yanlışa döndüğünü yakalamak.
  group('alan 16 · sayı borçları kapandı mı', () {
    test('1 · Void Leviathan ödülü bandın HEDEFİNİ tutuyor', () {
      // Kodda 3.000'di; yalnız Leviathan farm eden oyuncu hedefin üç katını
      // kazanıyordu.
      final guclu = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.guclu);
      expect(AlienStats.leviathan.creditReward, guclu.kredi);
      final saatlik =
          AlienStats.leviathan.creditReward * 3600 / guclu.harcananSaniye;
      expect(
        saatlik / guclu.saatlikHedef,
        closeTo(TasarimGirdileri.gucluRiskPrimi, 0.01),
      );
    });

    test('2 · yorgunluk eşiği kademeyle ÖLÇEKLENİYOR', () {
      // Sabitti; dördüncü bölgeden sonra herkes tabana çakılıyordu.
      final ilk = Fatigue.softCapFor(0);
      final son = Fatigue.softCapFor(Turetilenler.rankSayisi - 1);
      expect(son, greaterThan(ilk));
    });

    test('3 · artı kazanç biçimi TOPLAMSAL', () {
      expect(TasarimGirdileri.artiKazancBicimi, ArtiKazancBicimi.toplamsal);
      expect(ItemLevels.multiplier(ItemLevels.max), closeTo(2.50, 1e-9));
    });

    test('4 · artı maliyet HACMİ tepe tablodan', () {
      expect(TasarimGirdileri.maliyetHacmi, 2489);
      expect(
        ItemLevels.upgradeCost(0, ItemTier.cI),
        TasarimGirdileri.maliyetHacmi.round(),
      );
    });

    test('5 · artı maliyet ŞEKLİ değer eğrisini düzeltti', () {
      expect(TasarimGirdileri.maliyetSekli, closeTo(1.2293, 1e-9));
      expect(ItemLevels.degerBozulmasi, inInclusiveRange(8, 16));
    });

    test('6 · gövde merdiveni TÜRETİLİYOR — elle konmuş ×1,32 değil', () {
      // Sekiz kademede 7× veriyordu, gereken 727×.
      final merdiven = Turetilenler.govdeKademeCarpanlari;
      for (var k = 1; k < merdiven.length; k++) {
        expect(
          merdiven[k] / merdiven[k - 1],
          closeTo(
            TuretilenTablolar.normalizatorKapaliFor(
              1,
              rankSayisi: Turetilenler.rankSayisi,
              kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
              artis: TasarimGirdileri.rankArtisi,
            ),
            1e-9,
          ),
        );
      }
      expect(merdiven.last / merdiven.first, greaterThan(4));
    });

    test('7 · K sabitleri kademe NORMALİZATÖRÜYLE ölçekleniyor', () {
      // Sabit K ile üst kademede azaltma %99,9'a çıkıyor ve savaş donuyor.
      final ilk = TuretilenTablolar.normalizatorFor(
        0,
        rankSayisi: Turetilenler.rankSayisi,
        kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
        artis: TasarimGirdileri.rankArtisi,
      );
      final son = TuretilenTablolar.normalizatorFor(
        TasarimGirdileri.govdeKademeSayisi - 1,
        rankSayisi: Turetilenler.rankSayisi,
        kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
        artis: TasarimGirdileri.rankArtisi,
      );
      expect(ilk, 1.0);
      expect(son, greaterThan(1.0));
    });

    test('8 · kalkan statı YÜZDE değil', () {
      // Mağazada "+0 KALKAN" görünüyordu.
      expect(Stats.byId('kalkan')?.percent, isFalse);
      expect(Stats.byId('govde_cani')?.percent, isFalse);
    });
  });

  group('alan 16 · eksik sistemler', () {
    // KARAR 16.4 s1
    test('eksikler CANLI ölçülüyor — elle tutulan liste yok', () {
      // Bir sistem inşa edildikçe açık kendiliğinden kapanıyor. Elle tutulan
      // bir eksik listesi, tamamlanmış bir işi eksik göstermeye devam ederdi.
      final kadro = DengeDenetimi.sistemler.firstWhere(
        (s) => s.ad == 'tasarlanmış yaratık',
      );
      expect(kadro.mevcut, YaratikKadrosu.hepsi.length);
      expect(kadro.tamam, isTrue, reason: 'kadro 32\'ye tamamlandı');
    });

    test('merdiven HEDEFE VARDI — rank ve gövde kademesi yerinde', () {
      // Bu test bir zamanlar tersini söylüyordu: "bilinen açıkların hepsi TEK
      // bir kökten — rank merdiveni", ve `rankSayisi < hedef` bekliyordu.
      // Merdiven yirmiye çıktı, kök kapandı; testin işi artık kapalı kalmasını
      // sağlamak.
      expect(Turetilenler.rankSayisi, DengeDenetimi.hedefRankSayisi);
      expect(
        TasarimGirdileri.govdeKademeSayisi,
        DengeDenetimi.hedefKademeSayisi,
      );
      // Kalan eksikler yalnız SANAT olabilir (çizilmiş gövde) ya da
      // serpilmemiş boss — ikisi de sayıyla kapanmaz.
      for (final s in DengeDenetimi.eksikler) {
        expect(
          ['çizilmiş gövde', 'serpilen yaratık'],
          contains(s.ad),
          reason: '${s.ad} beklenmedik bir açık — merdiven kapandı',
        );
      }
    });

    test('hiçbir sistem HEDEFİ AŞMIYOR', () {
      // Aşan bir sistem, hedefin bayatladığı anlamına gelir.
      for (final s in DengeDenetimi.sistemler) {
        expect(
          s.mevcut,
          lessThanOrEqualTo(s.hedef),
          reason: '${s.ad} hedefi aşmış — hedef mi bayat?',
        );
      }
    });
  });

  group('alan 16 · beş test türü', () {
    /// Çekirdeğin test dizini — koşu ister paket kökünden ister depo
    /// kökünden başlasın aynı dizini bulur.
    Directory testDizini() {
      for (final yol in ['test', 'packages/voidspace_core/test']) {
        final d = Directory(yol);
        if (d.existsSync() &&
            d.listSync().whereType<File>().any(
              (f) => f.path.endsWith('_test.dart'),
            )) {
          return d;
        }
      }
      throw StateError('test dizini bulunamadı');
    }

    List<File> testDosyalari() =>
        testDizini().listSync().whereType<File>().where(
          (f) => f.path.endsWith('_test.dart'),
        ).toList();

    final tagsDeseni = RegExp(r'@Tags\(\[([^\]]*)\]\)');

    List<String> etiketleriOku(File f) {
      final m = tagsDeseni.firstMatch(f.readAsStringSync());
      if (m == null) return const [];
      return m
          .group(1)!
          .split(',')
          .map((e) => e.trim().replaceAll("'", '').replaceAll('"', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // KARAR 16.1 s1
    test('beş tür artı bir DIŞI — sayım beşi sayıyor, dışını saymıyor', () {
      // Sınıflandırma kodda: elle sayılan her şey eskir. `disi` altıncı
      // etiket ve BİLEREK beşin dışında — sayım onu saymıyor ama dışarıda
      // bıraktığını biliyor.
      expect(TestTuru.besi, hasLength(5));
      expect(TestTuru.besi, isNot(contains(TestTuru.disi)));
      expect(TestTuru.values, hasLength(6));
      expect(
        TestTuru.values.map((t) => t.etiket).toSet(),
        hasLength(TestTuru.values.length),
        reason: 'iki tür aynı etiketi taşıyor — tek başına koşturulamaz',
      );
      for (final t in TestTuru.values) {
        expect(TestTuru.parse(t.etiket), t);
        expect(t.ad, isNotEmpty);
      }
      expect(TestTuru.parse('boyle-bir-tur-yok'), isNull);
    });

    // KARAR 16.1 s1
    test('her test dosyası TÜRÜNÜ ilan ediyor — ilan etmeyen biçim hatası', () {
      // Kararın çalıştırılabilir hâli: dosya başında `@Tags` yoksa denetim
      // biçim hatası veriyor ve sayım o dosyayı göremiyor.
      final dosyalar = testDosyalari();
      expect(dosyalar, isNotEmpty, reason: 'test dosyası bulunamadı');
      final ilansiz = <String>[];
      final tanimsiz = <String>[];
      for (final f in dosyalar) {
        final etiketler = etiketleriOku(f);
        if (etiketler.isEmpty) {
          ilansiz.add(f.path);
          continue;
        }
        for (final e in etiketler) {
          // `zaman` tür değil NİTELİK: türün yanına yazılıyor.
          if (e == 'zaman') continue;
          if (TestTuru.parse(e) == null) tanimsiz.add('${f.path}: $e');
        }
        expect(
          etiketler.any((e) => TestTuru.parse(e) != null),
          isTrue,
          reason: '${f.path}: yalnız nitelik yazmış, tür yazmamış',
        );
      }
      expect(ilansiz, isEmpty, reason: 'türünü ilan etmeyen dosya:\n'
          '${ilansiz.join('\n')}');
      expect(tanimsiz, isEmpty, reason: 'tanımsız etiket:\n'
          '${tanimsiz.join('\n')}');
    });

    // KARAR 16.1 s1
    test('`zaman` tür DEĞİL nitelik — sayıma girmiyor, ayrılabiliyor', () {
      // Gerçek zamana bağlı ölçüm yapan test türünün yanına `zaman` da
      // yazıyor; yük altındaki tam koşudan `--exclude-tags zaman` ile
      // ayrılıyor. Bir tür olsaydı sayım altı tür sayardı.
      expect(TestTuru.parse('zaman'), isNull);
      for (final f in testDosyalari()) {
        final etiketler = etiketleriOku(f);
        if (!etiketler.contains('zaman')) continue;
        expect(
          etiketler.where((e) => TestTuru.parse(e) != null),
          isNotEmpty,
          reason: '${f.path}: yalnız `zaman` yazmış, türü yok',
        );
      }
    });

    // KARAR 16.1 s1
    test('beş türün HEPSİ kullanılıyor — ölü sınıflandırma yok', () {
      // Sınıflandırma taşınmıyorsa süs demektir. Her türü en az bir dosya
      // ilan etmeli; en kalabalık tür aralık, en değerlisi türetme.
      final sayim = {for (final t in TestTuru.values) t: 0};
      for (final f in testDosyalari()) {
        for (final e in etiketleriOku(f)) {
          final t = TestTuru.parse(e);
          if (t != null) sayim[t] = sayim[t]! + 1;
        }
      }
      for (final t in TestTuru.besi) {
        expect(
          sayim[t],
          greaterThan(0),
          reason: '${t.ad} türünü hiçbir dosya ilan etmiyor',
        );
      }
    });
  });

  group('alan 16 · denetimin sınırı', () {
    test('denetim TUTARLILIK ölçüyor, DOĞRULUK değil', () {
      // Bu grubun tek testi ve belgenin en dürüst cümlesi: "TTK 30 saniye
      // olsun" bir zevk meselesi. 16'nın söyleyebildiği tek şey o kararın her
      // yere aynı şekilde yansıyıp yansımadığı.
      //
      // Ölçülebilir hâli: referans TTK bir GİRDİ olmak zorunda. Türetilseydi
      // bir zevk kararı hesaplanmış gibi görünürdü.
      expect(TasarimGirdileri.hepsi.map((g) => g.ad), contains('referansTTK'));
      // Ve o girdiden çıkan her şey ona bağlı kalmalı: savunma çapası TTK'yı
      // okuyor.
      expect(
        Turetilenler.savunmaCapasi,
        closeTo(
          Turetilenler.saldiriPuaniDps *
              TasarimGirdileri.referansTTK /
              Turetilenler.referansEhpCarpani,
          1e-9,
        ),
      );
    });
  });
}
