@Tags(['aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/harita_kaydi.dart';
import 'package:voidspace_server/zone.dart';

/// KADRO — hangi haritada hangi yaratık, hangi güçte.
///
/// Portal işi bir açık ortaya çıkarmıştı: dünya gezilebilir hâle geldi ama her
/// yeri aynıydı. Sunucu sabit iki `AlienStats` serpiyordu, yani BR 11.674
/// kapısını geçip en derin bölgeye varan oyuncu, başlangıç haritasındakiyle
/// birebir aynı yaratığı buluyordu.
///
/// Buradaki testler iki şeyi ayrı ayrı koruyor: **kimlik** (bölgenin kendi
/// yaratıkları) ve **güç** (bandın ölçeği).
void main() {
  Zone hucreFor(Bolge bolge, {HaritaTipi tip = HaritaTipi.pve}) =>
      HaritaKaydi(Harita(bolge, tip)).ac(0);

  group('kadro · kimlik', () {
    test('her bölge YALNIZ kendi yaratıklarını doğuruyor', () {
      // Kırılırsa: kadro bağlanmamış ya da yanlış bölgeden okunuyor. Dünya
      // yine gezilebilir ama yine her yeri aynı.
      for (final bolge in Bolge.hepsi) {
        final beklenen = {
          for (final y in YaratikKadrosu.bolgenin(bolge.kademe)) y.ad,
        };
        final dogan = {
          for (final a in hucreFor(bolge).aliens.values) a.stats.name,
        };
        expect(dogan, isNotEmpty, reason: '${bolge.ad} boş');
        expect(
          dogan.difference(beklenen),
          isEmpty,
          reason:
              '${bolge.ad} yabancı yaratık doğurdu: '
              '${dogan.difference(beklenen)}',
        );
      }
    });

    test('BOSS serpilmiyor — zamanlı doğuyor', () {
      // Boss haritaya dağılan bir yaratık değil, bir randevu. Serpilseydi
      // "iki saatte bir" kuralı anlamsızlaşırdı.
      for (final bolge in Bolge.hepsi) {
        final bosslar = YaratikKadrosu.bolgenin(
          bolge.kademe,
        ).where((y) => y.sinif == DusmanSinifi.boss).map((y) => y.ad).toSet();
        expect(bosslar, isNotEmpty, reason: '${bolge.ad} boss tanımlamamış');
        for (final a in hucreFor(bolge).aliens.values) {
          expect(bosslar, isNot(contains(a.stats.name)));
        }
      }
    });

    test('iki sıradanın İKİSİ de görünüyor — dama tahtası tutuyor', () {
      // Kırılırsa: seçim ızgaranın periyoduyla örtüşmüş ve biri hiç
      // doğmuyor — ya da haritada çizgi hâlinde diziliyor.
      for (final bolge in Bolge.hepsi) {
        final siradanlar = {
          for (final y in YaratikKadrosu.bolgenin(bolge.kademe))
            if (y.sinif == DusmanSinifi.siradan) y.ad,
        };
        final dogan = {
          for (final a in hucreFor(bolge).aliens.values) a.stats.name,
        };
        expect(
          dogan.intersection(siradanlar),
          hasLength(siradanlar.length),
          reason: '${bolge.ad}: sıradanlardan biri hiç doğmadı',
        );
      }
    });

    test('güçlü NADİR — altıda bir civarı', () {
      // Alanın kararı: güçlüye girmek bir karar olmalı. Yarısı güçlü olsaydı
      // avlanmak bir işe dönerdi; hiç olmasaydı karar ortadan kalkardı.
      for (final bolge in Bolge.hepsi) {
        final guclu = YaratikKadrosu.bolgenin(
          bolge.kademe,
        ).firstWhere((y) => y.sinif == DusmanSinifi.guclu);
        final hucre = hucreFor(bolge);
        final adet = hucre.aliens.values
            .where((a) => a.stats.name == guclu.ad)
            .length;
        final oran = adet / hucre.aliens.length;
        expect(oran, greaterThan(0.05), reason: '${bolge.ad} güçlüsüz');
        expect(oran, lessThan(0.34), reason: '${bolge.ad} güçlü kalabalığı');
      }
    });
  });

  group('kadro · güç', () {
    test('derin bölgenin yaratığı SERT — dünya artık düz değil', () {
      // Portal işinin ortaya çıkardığı açık tam olarak buydu.
      var onceki = 0.0;
      for (final bolge in Bolge.hepsi) {
        final enZayif = hucreFor(bolge).aliens.values
            .map((a) => a.stats.maxHull)
            .reduce((a, b) => a < b ? a : b);
        expect(
          enZayif,
          greaterThan(onceki),
          reason: '${bolge.ad} bir öncekinden sert değil',
        );
        onceki = enZayif;
      }
    });

    test('can BANDIN referans DPS\'inden — elle yazılmıyor', () {
      for (final bolge in Bolge.hepsi) {
        final hucre = hucreFor(bolge);
        for (final a in hucre.aliens.values) {
          final kimlik = YaratikKadrosu.hepsi.firstWhere(
            (y) => y.ad == a.stats.name,
          );
          final rank = bolge.rankOf(hucre.bandFor(a.position));
          expect(
            a.stats.maxHull,
            closeTo(kimlik.statFor(rank).maxHull, 1e-6),
            reason: '${a.stats.name} canı bandından gelmiyor',
          );
        }
      }
    });

    test('ödül de banda bağlı — gelir eğrisi haritaya taşındı', () {
      // Kırılırsa: derin bölgede sert yaratıklar aynı krediyi veriyor ve
      // oyuncu ilerledikçe saatlik geliri DÜŞÜYOR.
      var onceki = 0;
      for (final bolge in Bolge.hepsi) {
        final enDusuk = hucreFor(bolge).aliens.values
            .map((a) => a.stats.creditReward)
            .reduce((a, b) => a < b ? a : b);
        expect(
          enDusuk,
          greaterThan(onceki),
          reason: '${bolge.ad} ödülü artmadı',
        );
        onceki = enDusuk;
      }
    });
  });

  group('kadro · derinlik bandı', () {
    test('merkez EN DERİN, kenar en dış', () {
      // Alan 11'in cümlesi: "dış bant bölgenin ilk rankı, iç bant sonuncusu."
      // Merkeze uçmak derinleşmek demek.
      for (final bolge in Bolge.hepsi) {
        final hucre = hucreFor(bolge);
        expect(hucre.bandFor(hucre.world.centre), bolge.bantSayisi - 1);
        expect(hucre.bandFor(const Vec2(0, 0)), 0);
        expect(hucre.bandFor(Vec2(hucre.world.width, hucre.world.height)), 0);
      }
    });

    test('bant HER ZAMAN geçerli bir rank veriyor', () {
      // Kırılırsa: kenardaki bir yaratık `rankOf` içinde patlıyor ve harita
      // hiç kurulamıyor.
      for (final bolge in Bolge.hepsi) {
        final hucre = hucreFor(bolge);
        for (var x = 0.0; x <= hucre.world.width; x += hucre.world.width / 17) {
          for (
            var y = 0.0;
            y <= hucre.world.height;
            y += hucre.world.height / 13
          ) {
            final bant = hucre.bandFor(Vec2(x, y));
            expect(bant, inInclusiveRange(0, bolge.bantSayisi - 1));
            expect(() => bolge.rankOf(bant), returnsNormally);
          }
        }
      }
    });

    test('HALKALAR doğdu — her bölge birden çok bant', () {
      // Karakterizasyondu: "BUGÜN her bölge tek bant", ve beş rank / beş bölge
      // kurulumunda halka ölçeklemesi çalışmıyor ama görünmüyordu. Yirmi rank
      // sekiz bölgeye 2·3·2·3·2·3·2·3 diye bölününce halkalar doğdu.
      for (final bolge in Bolge.hepsi) {
        expect(
          bolge.bantSayisi,
          greaterThan(1),
          reason: '${bolge.ad} hâlâ tek bant — halka ölçeklemesi görünmez',
        );
      }
      // Bantların TOPLAMI merdivenin kendisi: hiçbir rank bölgesiz kalmıyor,
      // hiçbir rank iki bölgeye birden düşmüyor.
      expect(
        Bolge.hepsi.fold(0, (a, b) => a + b.bantSayisi),
        Turetilenler.rankSayisi,
      );
    });
  });
}
