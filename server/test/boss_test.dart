@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/harita_kaydi.dart';
import 'package:voidspace_server/zone.dart';

/// BOSS RANDEVUSU — zamanlı doğuş.
///
/// Bu testler bir BAĞLANTI boşluğundan doğdu. Sayaç (`bossSonDogusTik`),
/// aralık (`bossAraligiTik`) ve "hak etti mi" sorusu (`bossBekliyor`) yazılmış
/// ve test edilmişti; tüketen taraf hiç yazılmamıştı. Sekiz boss tasarlanmış,
/// hiçbiri haritaya çıkmıyordu — ve hiçbir test kırmızıya dönmüyordu, çünkü
/// her parça kendi içinde doğruydu.
void main() {
  Zone hucreFor(Harita harita) => HaritaKaydi(harita).ac(0);

  group('boss doğuşu', () {
    test('her bölgenin bir boss kimliği VAR', () {
      for (final b in Bolge.hepsi) {
        final hucre = hucreFor(Harita(b, HaritaTipi.pve));
        expect(
          hucre.bossKimligi,
          isNotNull,
          reason: '${b.ad} boss\'suz — kadro eksik',
        );
        expect(hucre.bossKimligi!.sinif, DusmanSinifi.boss);
      }
    });

    test('doğmadan önce boss YOK', () {
      final hucre = hucreFor(HaritaDefteri.baslangic);
      expect(hucre.bossCanli, isFalse);
      expect(hucre.aliens[hucre.bossId], isNull);
    });

    test('doğunca AYAKTA ve sürünün kimliklerine çakışmıyor', () {
      final hucre = hucreFor(HaritaDefteri.baslangic);
      expect(hucre.bossDogur(), isTrue);
      expect(hucre.bossCanli, isTrue);
      // Sürünün kimlikleri alienIdBase..+alienCount-1; boss bir üstü.
      expect(hucre.bossId, greaterThanOrEqualTo(Protocol.alienIdBase));
      for (var i = 0; i < hucre.alienCount; i++) {
        expect(Protocol.alienIdBase + i, isNot(hucre.bossId));
      }
    });

    test('ayaktayken İKİNCİ boss doğmuyor', () {
      final hucre = hucreFor(HaritaDefteri.baslangic);
      expect(hucre.bossDogur(), isTrue);
      expect(hucre.bossDogur(), isFalse, reason: 'iki boss birden doğdu');
    });

    test('boss KENDİ KENDİNE yeniden doğmuyor — randevu kayıtta', () {
      final hucre = hucreFor(HaritaDefteri.baslangic);
      hucre.bossDogur();
      expect(hucre.aliens[hucre.bossId]!.stats.respawnDelay, double.infinity);
    });

    test('boss EN DERİN bantta — her bölgede', () {
      for (final b in Bolge.hepsi) {
        final hucre = hucreFor(Harita(b, HaritaTipi.pve));
        hucre.bossDogur();
        final boss = hucre.aliens[hucre.bossId]!;
        expect(
          hucre.bandFor(boss.home),
          hucre.bandFor(hucre.world.centre),
          reason: '${b.ad}: boss en derin bandın dışına taştı',
        );
        expect(
          hucre.bandFor(hucre.world.centre),
          greaterThan(
            hucre.bandFor(Vec2(hucre.world.margin, hucre.world.margin)),
          ),
        );
      }
    });

    test('doğan oyuncu boss MENZİLİNDE DEĞİL', () {
      // Hatanın ta kendisi: boss tam merkezdeydi, oyuncular merkezden 900
      // ötede doğuyor, Kurvex'in menzili 1120. Doğan her oyuncu daha tek tuşa
      // basmadan ateş altındaydı.
      for (final b in Bolge.hepsi) {
        final hucre = hucreFor(Harita(b, HaritaTipi.pve));
        hucre.bossDogur();
        final boss = hucre.aliens[hucre.bossId]!;
        final enYakin =
            (boss.home - hucre.world.centre).length - Zone.dogusHalkasi;
        expect(
          enYakin,
          greaterThanOrEqualTo(boss.stats.aggroRange),
          reason:
              '${b.ad}: doğuş halkası boss menzilinin içinde '
              '(${enYakin.round()} < ${boss.stats.aggroRange.round()})',
        );
      }
    });

    test('boss statları BANTTAN — sürüden çok daha dayanıklı', () {
      final hucre = hucreFor(HaritaDefteri.baslangic);
      hucre.bossDogur();
      final boss = hucre.aliens[hucre.bossId]!;
      final siradan = hucre.aliens[Protocol.alienIdBase]!;
      expect(boss.stats.maxHull, greaterThan(siradan.stats.maxHull * 10));
    });

    test('öldükten sonra ölü KALIYOR — sim onu geri getirmiyor', () {
      final hucre = hucreFor(HaritaDefteri.baslangic);
      hucre.bossDogur();
      var boss = hucre.aliens[hucre.bossId]!;
      boss = AlienSim.applyDamage(boss, boss.stats.maxHull * 2);
      expect(boss.alive, isFalse);
      expect(boss.respawnIn, double.infinity);
      // Bir saat simüle et: hâlâ ölü.
      for (var i = 0; i < 3600; i++) {
        boss = AlienSim.step(boss, hucre.world, 1, i);
      }
      expect(boss.alive, isFalse, reason: 'boss kendi kendine dirildi');
    });
  });

  group('randevu — kayıt ile hücre birlikte', () {
    test('ilk oyuncu bekleyen boss\'u BULUYOR', () {
      final kayit = HaritaKaydi(HaritaDefteri.baslangic);
      // Hiç doğmamış: ilk andan itibaren borçlu.
      expect(kayit.bossBekliyor(0), isTrue);
      final hucre = kayit.ac(0);
      expect(hucre.bossDogur(), isTrue);
      kayit.bossDogdu(0);
      expect(kayit.bossBekliyor(0), isFalse);
    });

    test('sayaç hücre ÖLSE DE yaşıyor', () {
      final kayit = HaritaKaydi(Harita(Bolge.hepsi[1], HaritaTipi.pve));
      kayit.ac(0);
      kayit.bossDogdu(0);
      expect(kayit.kapat(), isTrue, reason: 'boş hücre kapanmalıydı');
      // Hücre gitti, sayaç durdu mu?
      expect(kayit.bossBekliyor(kayit.bossAraligiTik - 1), isFalse);
      expect(kayit.bossBekliyor(kayit.bossAraligiTik), isTrue);
    });
  });

  group('bağlantı', () {
    test('TİK DÖNGÜSÜ randevuyu gerçekten tüketiyor', () {
      // Bu testin varlık sebebi: mekanizmanın tamamı yazılmış ve test edilmiş
      // olmasına rağmen `bossBekliyor` üretimde HİÇ çağrılmıyordu. Davranış
      // testi bunu yakalayamaz — `bossDogur()` doğrudan çağrıldığında doğru
      // çalışıyor. Yakalayan tek şey, çağrının tik döngüsünde durduğunu
      // KAYNAKTAN doğrulamak.
      final kaynak = File('lib/gateway.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'^\s*//.*\$', multiLine: true), '');
      final dongu = kaynak.substring(kaynak.indexOf('_tick++;'));
      final govde = dongu.substring(0, dongu.indexOf('_sendSnapshots()'));
      expect(
        govde,
        contains('bossBekliyor'),
        reason: 'tik döngüsü randevuyu sormuyor — boss hiç doğmaz',
      );
      expect(
        govde,
        contains('bossDogdu'),
        reason: 'sayaç ilerlemiyor — her tik yeni boss denenir',
      );
      expect(
        govde,
        contains('bossDogur'),
        reason: 'randevu soruluyor ama boss doğurulmuyor',
      );
    });
  });
}
