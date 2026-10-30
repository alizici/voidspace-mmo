@Tags(['kapsam', 'kod-belge'])
library;

import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/govde_tasarimlari.dart';
import 'package:voidspace_core/voidspace_core.dart';

void main() {
  group('gövde tasarımları · kapsam', () {
    test('sekiz kademenin sekizinin de tasarımı var', () {
      expect(
        GovdeTasarimlari.hepsi.length,
        TasarimGirdileri.govdeKademeSayisi,
        reason:
            'kademe sayısı tepe tablodan geliyor; kayıt onunla eşit '
            'olmak zorunda — bir kademe artarsa burada boş bir sıra kalır',
      );
      expect(HullClass.all.length, GovdeTasarimlari.hepsi.length);
    });

    test('kademe alanı listedeki indeksle aynı', () {
      for (var k = 0; k < GovdeTasarimlari.hepsi.length; k++) {
        expect(GovdeTasarimlari.hepsi[k].kademe, k);
        expect(GovdeTasarimlari.byKademe(k).kademe, k);
      }
    });

    test('tasarım adları TEKİL', () {
      final adlar = GovdeTasarimlari.hepsi.map((t) => t.ad).toSet();
      expect(adlar.length, GovdeTasarimlari.hepsi.length);
    });
  });

  group('gövde tasarımları · kullanıcının verdiği iki uç', () {
    // Bu iki test sıralamanın TAMAMINI değil, oyuncunun kendi verdiği iki
    // kararı koruyor. Aradaki altısı sanat kararı ve değişebilir; uçlar
    // değişirse bu testler kırılmalı.
    test('en güçsüz kademe FIREBIRD', () {
      expect(GovdeTasarimlari.hepsi.first.ad, 'Firebird');
      expect(
        GovdeTasarimlari.hepsi.first.motorSayisi,
        1,
        reason: 'tek jet — katalogdaki en hafif silüet',
      );
    });

    test('en güçlü kademe bu projenin ERİYİK BASTION\'u', () {
      final tepe = GovdeTasarimlari.hepsi.last;
      expect(tepe.ad, 'Bastion (eriyik VFX)');
      expect(tepe.prosedurel, isTrue);
      expect(
        tepe.cizildi,
        isTrue,
        reason: 'tepe kademe zaten çizili olan tek gövde',
      );
    });

    test('tepe tasarımın ölçüsü Bastion sanatından geliyor, elle değil', () {
      final tepe = GovdeTasarimlari.hepsi.last;
      expect(tepe.erisim, closeTo(Bastion.reach, 0.05));
      expect(tepe.merkezKaydirmasi, closeTo(Bastion.centreOffset, 0.05));
    });
  });

  group('gövde tasarımları · çizim durumu', () {
    test('bugün YALNIZ bir gövde çizili', () {
      expect(
        GovdeTasarimlari.cizilenler.length,
        1,
        reason:
            'atlas tek gövde bloğu pişiriyor ve istemcinin her yeri '
            'doğrudan bastion.dart çağırıyor — ikinci bir çizim eklendiği gün '
            'bu sayı da atlas mimarisi de değişmek zorunda',
      );
      expect(GovdeTasarimlari.cizilenler.single.kademe, 7);
    });

    test('her tasarımın gerekçesi ve ikonu var', () {
      for (final t in GovdeTasarimlari.hepsi) {
        expect(t.not.length, greaterThan(20), reason: '${t.ad} gerekçesiz');
        expect(t.ikon, startsWith('assets/ships/'));
      }
    });

    test('üretilen ikon SANATTAN geliyor, depoya elle konmadı', () {
      // Yedi ikon voidspace2 katalogundan geldi; sekizincisinin kaynağı bu
      // projenin kendi kodu. `tool/govde_ikonu_test.dart` onu pişiriyor —
      // dosya silinirse o test yeniden üretir, elle çizilmesi gerekmez.
      expect(
        GovdeTasarimlari.byKademe(7).ikon,
        'assets/ships/bastion_molten.png',
      );
      expect(File('tool/govde_ikonu_test.dart').existsSync(), isTrue);
      expect(
        File('assets/ships/README.txt').readAsStringSync(),
        contains('bastion.png'),
        reason: 'ikonların kökeni yazılı olmak zorunda',
      );
    });

    test('prosedürel bayrağı ikondan AYRI bir şey söylüyor', () {
      // Dagon'un ikonu PNG ama gövdesi kodla çizilecek. İkisi tek alanda
      // taşınsaydı ("sprite yoksa prosedüreldir") bu tasarım yanlış
      // sınıflanırdı — ve sınıf, sanatın nasıl taşınacağını belirliyor.
      final dagon = GovdeTasarimlari.byKademe(3);
      expect(dagon.ad, 'Dagon');
      expect(dagon.prosedurel, isTrue);
      expect(dagon.ikon, 'assets/ships/dagon.png');
      final prosedurelSayisi = GovdeTasarimlari.hepsi
          .where((t) => t.prosedurel)
          .length;
      expect(
        prosedurelSayisi,
        3,
        reason: 'Dagon · E-Ambassador · eriyik Bastion — kalan beşi sprite',
      );
    });
  });

  group('gövde tasarımları · sanat ile kod ayrışmasın', () {
    test('sekiz ikonun sekizi de DOSYA olarak var', () {
      expect(GovdeTasarimlari.ikonlar.length, 8);
      expect(
        GovdeTasarimlari.ikonlar.toSet().length,
        8,
        reason: 'iki kademe aynı ikonu gösterirse ızgarada ayırt edilemezler',
      );
      for (final yol in GovdeTasarimlari.ikonlar) {
        expect(
          File(yol).existsSync(),
          isTrue,
          reason: '$yol pubspec\'te bildirildi ama depoda yok',
        );
      }
    });

    test('ikonlar pubspec\'te bildirildi', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/ships/'));
    });

    test('kaide sayısı atlas silah bloğuyla AYNI', () {
      expect(GovdeTasarimlari.kaideSayisi, AtlasLayout.emitterMounts);
      expect(
        Bastion.hardpoints.length,
        GovdeTasarimlari.kaideSayisi,
        reason:
            'sekiz tasarımın da beş kaidesi var; bir tasarım altı '
            'kaideyle gelirse atlas silah bloğu genişlemek zorunda',
      );
    });

    test('çekirdeğin bildirdiği sanat sayısı istemcinin gerçeğiyle aynı', () {
      // Çekirdek istemciyi okuyamaz — yön yanlış olurdu. O yüzden sayı orada
      // BİLDİRİLİYOR, burada DOĞRULANIYOR. Denetim katmanının `çizilmiş gövde`
      // açığı doğrudan bu sayıyı okuyor; ayrıştıkları gün denetim yalan söyler.
      expect(
        HullClass.sanatiOlanKademeSayisi,
        GovdeTasarimlari.cizilenler.length,
        reason:
            'ikinci bir gövde çizildiğinde hull.dart\'taki bildirim de '
            'artmalı — yoksa denetim eski sayıyı raporlar',
      );
      expect(
        HullClass.cizilenler.length,
        isNot(HullClass.sanatiOlanKademeSayisi),
        reason:
            'bu iki sayı AYRI şeyleri sayıyor (elle yazılmış stat satırı '
            'vs gövde çizimi) ve bugün ayrıklar; eşitlendikleri gün bu test '
            'silinmeli — o gün üç gövdenin de sanatı var demektir',
      );
    });

    test('üç ayrı "Bastion" birbirine karışmıyor', () {
      // Depoda bu ad üç ayrı şeye takılı ve üçü de farklı:
      //   · HullClass.adlar[0]   → kademe 1 gövdesinin oyuncuya görünen adı
      //   · assets/ships/bastion.png → voidspace2 sprite'ı, kademe 3
      //   · lib/game/art/bastion.dart → bu projenin gemisi, kademe 8
      expect(HullClass.adlar.first, 'Bastion');
      expect(GovdeTasarimlari.byKademe(0).ad, isNot('Bastion'));
      expect(GovdeTasarimlari.byKademe(2).ikon, 'assets/ships/bastion.png');
      expect(GovdeTasarimlari.byKademe(2).cizildi, isFalse);
      expect(GovdeTasarimlari.byKademe(7).prosedurel, isTrue);
      expect(
        GovdeTasarimlari.byKademe(2).ad,
        isNot(GovdeTasarimlari.byKademe(7).ad),
      );
    });
  });

  group('gövde tasarımları · silah kaideleri', () {
    test('sekiz tasarımın da BEŞ kaidesi var', () {
      for (final t in GovdeTasarimlari.hepsi) {
        expect(t.kaideler.length, 5, reason: t.ad);
        expect(t.kaideBoylari.length, 5, reason: t.ad);
        expect(t.kaideGenislikleri.length, 5, reason: t.ad);
      }
      expect(GovdeTasarimlari.kaideSayisi, 5);
    });

    test('TOPOLOJİ sekizinde de aynı: aynalı çift · omurga · aynalı çift', () {
      // Ateş grupları ve yuva açılma sırası bu topolojiden TÜRÜYOR. Bir
      // tasarım üç aynasız kaide getirseydi türetme sessizce yanlış gruplar
      // üretirdi — bu yüzden kural burada, tek tek grup listelerinde değil.
      for (final t in GovdeTasarimlari.hepsi) {
        final k = t.kaideler;
        expect(t.omurgaKaidesi, 2, reason: '${t.ad}: omurga topu 2. indekste');
        expect(k[2].dx, closeTo(0, 0.01), reason: '${t.ad}: omurga ORTADA');
        for (final (a, b) in [(0, 1), (3, 4)]) {
          expect(
            k[a].dx,
            closeTo(-k[b].dx, 0.01),
            reason: '${t.ad}: $a ↔ $b çifti aynalı değil',
          );
          expect(k[a].dy, closeTo(k[b].dy, 0.01), reason: t.ad);
        }
        expect(
          k[0].dy,
          lessThan(k[3].dy),
          reason: '${t.ad}: ön çift burna daha yakın olmalı',
        );
      }
    });

    test('omurga topu GENİŞLİKTEN türüyor, yazılmıyor', () {
      for (final t in GovdeTasarimlari.hepsi) {
        expect(
          t.kaideGenislikleri[2],
          greaterThanOrEqualTo(GovdeTasarimi.omurgaEsigi),
          reason: '${t.ad}: merkez top eşiğin altında',
        );
        for (final i in const [0, 1, 3, 4]) {
          expect(
            t.kaideGenislikleri[i],
            lessThan(GovdeTasarimi.omurgaEsigi),
            reason: '${t.ad}: $i. kaide yanlışlıkla omurga sayılıyor',
          );
        }
      }
    });

    test('ateş grupları içten dışa — omurga · ön · arka', () {
      for (final t in GovdeTasarimlari.hepsi) {
        expect(t.atesGruplari, [
          [2],
          [0, 1],
          [3, 4],
        ], reason: t.ad);
      }
    });

    test('tepe tasarımın kaideleri SANATTAN geliyor, kopya değil', () {
      final tepe = GovdeTasarimlari.hepsi.last;
      expect(tepe.kaideler, same(Bastion.hardpoints));
      expect(tepe.kaideBoylari, same(Bastion.emitterLengths));
      expect(tepe.kaideGenislikleri, same(Bastion.emitterWidths));
    });

    test('namlu ağzı kaideden İLERİDE', () {
      // Ağız ile kaide karıştırılırsa ateş silahtan değil gövdenin içinden
      // çıkar. Ağız her zaman kaidenin burun tarafında (küçük y).
      for (final t in GovdeTasarimlari.hepsi) {
        final agiz = t.namluAgizlari;
        expect(agiz.length, t.kaideler.length);
        for (var i = 0; i < agiz.length; i++) {
          expect(
            agiz[i].dy,
            lessThan(t.kaideler[i].dy),
            reason: '${t.ad}: $i. namlu ağzı kaidenin gerisinde',
          );
          expect(agiz[i].dx, closeTo(t.kaideler[i].dx, 0.01), reason: t.ad);
        }
      }
    });

    test('bu projenin ateş sırası ile eski projeninki AYRI', () {
      // voidspace2 dıştan içe ateşliyordu: [0,1] → [2] → [3,4]. Bu proje
      // sırayı çevirdi (omurga önce) ve `CombatLayer._volleyDelay` o çevrilmiş
      // sırayı taşıyor. Kod taşınırken eski sıranın geri sızması, yaylımın
      // ağır silahını sona atardı.
      expect(GovdeTasarimlari.hepsi.first.atesGruplari.first, [2]);
      expect(Bastion.mountGroups.first, [2]);
    });
  });

  group('gövde tasarımları · atlas', () {
    test('silüet bloğu tepe tasarımı DIŞARIDA bırakıyor', () {
      // Yedi hareketsiz tasarım silüet bloğunda, sekizinci canlı gövde
      // bloğunda. İkisi karışırsa ya tepe gemi donar ya da bir silüet
      // olmayan bir karenin indeksine düşer.
      expect(AtlasLayout.siluetSayisi, GovdeTasarimlari.hepsi.length - 1);
      expect(
        GovdeTasarimlari.cizilenler.single.kademe,
        AtlasLayout.siluetSayisi,
        reason:
            'canlı gövde silüet indekslerinin BİR ÜSTÜNDE olmalı — '
            'ShipSwarm ayrımı tam bu karşılaştırmayla yapıyor',
      );
    });

    test('silüet kareleri atlasın İÇİNDE ve üst üste binmiyor', () {
      final kutu = Rect.fromLTWH(
        0,
        0,
        AtlasLayout.imageSize.width,
        AtlasLayout.imageSize.height,
      );
      final kareler = [
        for (var i = 0; i < AtlasLayout.siluetSayisi; i++)
          AtlasLayout.siluetFrame(i),
      ];
      for (final k in kareler) {
        expect(kutu.contains(k.topLeft), isTrue);
        expect(kutu.contains(k.bottomRight - const Offset(0.5, 0.5)), isTrue);
      }
      for (var i = 0; i < kareler.length; i++) {
        for (var j = i + 1; j < kareler.length; j++) {
          expect(
            kareler[i].overlaps(kareler[j]),
            isFalse,
            reason: '$i ve $j aynı pikselleri paylaşıyor',
          );
        }
      }
    });

    test('atlas mobil GPU tavanının ALTINDA', () {
      // 4096 çok sayıda mobil GPU'nun doku sınırı. Silüet bloğu eklenince
      // atlas 2573'ten 3039'a çıktı; sekiz tasarımı canlı blokta pişirmek
      // 7.456 piksel ederdi ve tam bu sınırı aşardı.
      expect(AtlasLayout.imageSize.width, lessThan(4096));
      expect(AtlasLayout.imageSize.height, lessThan(4096));
    });

    test('dünya kaideleri tepe tasarımda Bastion ile BİREBİR aynı', () {
      final tepe = GovdeTasarimlari.hepsi.last.dunyaKaideleri;
      expect(tepe.length, Bastion.worldHardpoints.length);
      for (var i = 0; i < tepe.length; i++) {
        expect(tepe[i].dx, closeTo(Bastion.worldHardpoints[i].dx, 0.001));
        expect(tepe[i].dy, closeTo(Bastion.worldHardpoints[i].dy, 0.001));
      }
    });

    test('normalizasyon kaideyi gövdeyle BİRLİKTE taşıyor', () {
      // Kaide dünya biriminde gövdenin yarı-açıklığını aşamaz: aşarsa top
      // geminin dışında, boşlukta durur. Sınır atlasın gövde hücresi.
      final yariGenislik = AtlasLayout.hullCellWorld.width / 2;
      for (final t in GovdeTasarimlari.hepsi) {
        for (final k in t.dunyaKaideleri) {
          expect(
            k.dx.abs(),
            lessThan(yariGenislik),
            reason: '${t.ad}: kaide gövde hücresinin dışında',
          );
        }
      }
    });

    test('her tasarımın ateş sırası Bastion tablosuyla AYNI', () {
      // `ShipSwarm._pushEmitters` bütün tasarımlar için `Bastion`'un
      // önceden hesaplanmış tablosunu okuyor — tahsis etmemek için. Bu ancak
      // sekizinin dizilişi aynıysa doğru, ve topolojiden türediği için aynı.
      for (final t in GovdeTasarimlari.hepsi) {
        expect(t.atesGruplari, Bastion.mountGroups, reason: t.ad);
      }
    });
  });
}
