@Tags(['kod-belge', 'aralik'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/zone.dart';

/// HASAR ZİNCİRİNİN sunucu ucu.
///
/// `savas_formulu_test.dart` zinciri saf olarak ölçüyor; burada ölçülen şey
/// zincirin OTORİTEDE koştuğu: kritik zarı sunucuda atılıyor mu, sonuç tel
/// üzerinde gidiyor mu, PvP katsayısı yalnız oyuncuya karşı mı uygulanıyor.
void main() {
  final world = GameWorld.standard;

  /// [stats] statlı bir atıcıyı hedefine kilitleyip [volleys] yaylım attırır.
  ///
  /// Hedefin canı sürekli tazeleniyor: ölçülen şey hasarın BÜYÜKLÜĞÜ, kaç
  /// yaylımda öldüğü değil.
  List<ShotEvent> fire({
    required ShipStats stats,
    required int volleys,
    int seed = 0,
  }) {
    final zone = Zone(alienCount: 0, diceSeed: seed);
    final shooter = zone.join('A', stats: stats)!;
    final target = zone.join('B', stats: stats)!;
    shooter.state = shooter.state.copyWith(position: world.centre);
    target.state = target.state.copyWith(
      position: world.centre + const Vec2(500, 0),
    );

    final out = <ShotEvent>[];
    final ticksPerVolley =
        (stats.laser.fireInterval * ShipSim.tickRate).ceil() + 1;
    for (var v = 0; v < volleys; v++) {
      for (var t = 0; t < ticksPerVolley; t++) {
        zone
          ..enqueue(
            shooter,
            ShipInput(
              seq: v * ticksPerVolley + t + 1,
              weaponTarget: target.id,
              firing: true,
            ),
          )
          ..step();
        out.addAll(zone.shots.where((s) => s.shooterId == shooter.id));
        target.state = target.state.copyWith(
          shield: stats.maxShield,
          hull: stats.maxHull,
        );
      }
    }
    return out;
  }

  group('kritik', () {
    const stats = ShipStats.bastion;

    test('zar SUNUCUDA atılıyor ve sonucu tel üzerinde geliyor', () {
      final shots = fire(stats: stats, volleys: 60);
      expect(shots, isNotEmpty);
      expect(
        shots.any((s) => s.crit),
        isTrue,
        reason: '60 yaylımda hiç kritik çıkmadı — PRD garantisi 12 yaylım',
      );
    });

    test('kritik vuruş TAM olarak çarpan katı', () {
      // AZALTMADAN SONRAKİ taban: olayda giden hasar, hedefin canından inen
      // miktarla aynı olmak zorunda.
      // Sunucu İNEN hasarı yuvarlıyor: kritik çarpanı yuvarlamadan önce
      // uygulanıyor. Önce yuvarlayıp sonra çarpmak birlik farkı üretirdi.
      for (final shot in fire(stats: stats, volleys: 60)) {
        final beklenen =
            (CombatGlossary.volley(stats) *
                    (shot.crit ? stats.critMultiplier : 1) *
                    (1 - stats.totalMitigation))
                .round();
        expect(
          shot.damage,
          beklenen,
          reason: 'ekrandaki rakam ile inen hasar ayrışmış',
        );
      }
    });

    test('kritik ORANI ilan edilene yakın', () {
      final shots = fire(stats: stats, volleys: 400);
      final oran = shots.where((s) => s.crit).length / shots.length;
      expect(
        oran,
        closeTo(TasarimGirdileri.kritikSansiReferans, 0.06),
        reason: 'oyuncu ilan edilenden farklı sıklıkta kritik alıyor',
      );
    });

    test('kritik şansı SIFIR olan gemi hiç kritik atmaz', () {
      final shots = fire(stats: stats.copyWith(critChance: 0), volleys: 40);
      expect(shots.every((s) => !s.crit), isTrue);
    });

    test('zar TOHUMLU — aynı tohum aynı diziyi verir', () {
      // Haritanın kendi kuralı: bir hatayı iki kez görebilmek. Kritik sırası
      // da o tekrarlanabilirliğin parçası.
      List<bool> dizi(int seed) => fire(
        stats: stats,
        volleys: 30,
        seed: seed,
      ).map((s) => s.crit).toList();
      expect(dizi(5), dizi(5));
    });
  });

  group('PvE ↔ PvP', () {
    test('PvP katsayısı YALNIZ oyuncuya karşı uygulanır', () {
      // Bugün katsayı 1,00 olduğu için iki yol da aynı sayıyı veriyor; test
      // katsayının nereye BAĞLANDIĞINI kilitliyor. Kol çekildiği gün alien
      // hasarının değişmemesi gerektiğini söyleyen tek yer burası.
      final stats = ShipStats.bastion.copyWith(critChance: 0);
      final zone = Zone(alienCount: 0);
      final shooter = zone.join('A', stats: stats)!;
      shooter.state = shooter.state.copyWith(position: world.centre);
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.leviathan,
        world.centre + const Vec2(500, 0),
        1,
      );
      // Ateş nişan yayına bağlı (zone.dart): avcı hedefe DÖNMÜŞ kuruluyor.
      // Bu testin konusu dönüş değil, PvP katsayısının nereye bağlandığı.
      final d = world.centre + const Vec2(500, 0) - shooter.state.position;
      shooter.state = shooter.state.copyWith(angle: math.atan2(d.x, -d.y));

      zone
        ..enqueue(
          shooter,
          const ShipInput(seq: 1, weaponTarget: alienId, firing: true),
        )
        ..step();

      final shot = zone.shots.firstWhere((s) => s.shooterId == shooter.id);
      expect(
        shot.damage,
        CombatGlossary.volley(stats).round(),
        reason: 'aliene inen hasara PvP katsayısı karışmış',
      );
    });
  });

  group('savunma', () {
    test('alien hasarı da AYNI zincirden geçiyor', () {
      // Ayrı bir yol açılsaydı düşman hasarı oyuncunun zırhını görmezden
      // gelirdi ve savunma statları PvE'de ölü stata dönerdi.
      final zone = Zone(alienCount: 0);
      final ship = zone.join('A')!;
      ship.state = ship.state.copyWith(position: world.centre, sinceHit: 0);
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.spore,
        world.centre + const Vec2(300, 0),
        1,
      );

      // Void Spore kışkırtılmadan saldırmaz: önce vur.
      zone
        ..enqueue(
          ship,
          const ShipInput(seq: 1, weaponTarget: alienId, firing: true),
        )
        ..step();

      var alienShot = zone.shots.where((s) => s.shooterId == alienId);
      for (var i = 0; alienShot.isEmpty && i < 200; i++) {
        zone.step();
        alienShot = zone.shots.where((s) => s.shooterId == alienId);
      }

      expect(alienShot, isNotEmpty, reason: 'Void Spore karşılık vermedi');
      final shot = alienShot.first;
      // Bu test bir zamanlar ham hasarı bekliyordu ve yorumu "zırh ve kaçınma
      // bugün sıfır (alan 04 bekliyor)" diyordu. Alan 04 referans zırhı ilan
      // edince eğri çözüldü ve testin KENDİ gerekçesi gerçekleşti: alien
      // hasarı da oyuncunun azaltmasından geçiyor.
      final hedef = ShipStats.bastion;
      expect(hedef.totalMitigation, greaterThan(0), reason: 'katman ölü');
      expect(
        shot.damage,
        (AlienStats.spore.damage * (1 - hedef.totalMitigation)).round(),
      );
      expect(shot.crit, isFalse, reason: 'alienlerin kritik statı yok');
    });
  });
}
