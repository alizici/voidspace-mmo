@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Sürünün davranışı.
///
/// Hepsi DETERMİNİZM üzerine kurulu: adımda `Random` olsaydı "otuz alien bir
/// dakika sonra hâlâ haritada mı" sorusunun cevabı koşudan koşuya değişirdi
/// ve test hiçbir şey kanıtlamazdı.
void main() {
  const world = GameWorld.standard;
  final stats = AlienStats.spore;

  AlienSimState spawn([int seed = 7]) =>
      AlienSimState.spawn(stats, const Vec2(6000, 4000), seed);

  AlienSimState run(AlienSimState s, double seconds, {int from = 0}) {
    var state = s;
    final steps = (seconds / ShipSim.fixedDt).round();
    for (var i = 0; i < steps; i++) {
      state = AlienSim.step(state, world, ShipSim.fixedDt, from + i);
    }
    return state;
  }

  test('alien HAREKET eder', () {
    final moved = run(spawn(), 4);
    expect(
      (moved.position - const Vec2(6000, 4000)).length,
      greaterThan(100),
      reason: 'duran bir sürü manzara değil dekor olurdu',
    );
  });

  test('aynı tohum aynı yolu üretir', () {
    // Sunucu yeniden başladığında sürünün aynı şekilde dolaşması, bir hatayı
    // iki kez görebilmek demek.
    final a = run(spawn(3), 6);
    final b = run(spawn(3), 6);
    expect(a.position.x, b.position.x);
    expect(a.position.y, b.position.y);
  });

  test('farklı tohum farklı yol', () {
    final a = run(spawn(3), 6);
    final b = run(spawn(4), 6);
    expect((a.position - b.position).length, greaterThan(1));
  });

  test('gezinme EVİN çevresinde kalır', () {
    // Harita boyunca dağılan alienler ilgi alanı filtresi yüzünden hiç
    // görünmez; sürünün doğduğu bölgede kalması tasarımın kendisi.
    var s = spawn(11);
    var farthest = 0.0;
    for (var i = 0; i < 60 * 30; i++) {
      s = AlienSim.step(s, world, ShipSim.fixedDt, i);
      final d = (s.position - s.home).length;
      if (d > farthest) farthest = d;
    }
    expect(farthest, lessThanOrEqualTo(stats.roamRange + 1));
  });

  test('bir dakika sonra hâlâ HARİTADA', () {
    // Kenardaki bir alien, kelepçe olmasa duvarın dışına yürürdü.
    var s = AlienSimState.spawn(stats, const Vec2(300, 300), 21);
    for (var i = 0; i < 60 * 60; i++) {
      s = AlienSim.step(s, world, ShipSim.fixedDt, i);
    }
    expect(s.position.x, greaterThanOrEqualTo(world.margin));
    expect(s.position.y, greaterThanOrEqualTo(world.margin));
    expect(s.position.x, lessThanOrEqualTo(world.width - world.margin));
    expect(s.position.y, lessThanOrEqualTo(world.height - world.margin));
  });

  test('varışta DURAKLAR — sürekli hareket mekanik görünüyor', () {
    var s = spawn(5);
    var sawDwell = false;
    for (var i = 0; i < 60 * 20; i++) {
      s = AlienSim.step(s, world, ShipSim.fixedDt, i);
      if (s.dwell > 0) sawDwell = true;
    }
    expect(sawDwell, isTrue);
  });

  group('hasar', () {
    test('kalkan YOK — hasar doğrudan gövdeye iner', () {
      final hit = AlienSim.applyDamage(spawn(), 600);
      expect(hit.hull, stats.maxHull - 600);
      expect(hit.alive, isTrue);
    });

    test('can bitince ölür ve yeniden doğuş sayacı başlar', () {
      final dead = AlienSim.applyDamage(spawn(), stats.maxHull + 10);
      expect(dead.alive, isFalse);
      expect(dead.hull, 0);
      expect(dead.respawnIn, stats.respawnDelay);
    });

    test('ölü alien HAREKET etmez', () {
      final dead = AlienSim.applyDamage(spawn(), 1e9);
      final after = run(dead, 2);
      expect(after.position.x, dead.position.x);
      expect(after.alive, isFalse);
    });

    test('süre dolunca EVİNDE tam canla doğar', () {
      // Öldüğü yerde doğmak, orada bekleyen oyuncuya sonsuz hedef akışı
      // verirdi.
      var s = AlienSim.applyDamage(
        spawn().copyWith(position: const Vec2(9000, 1000)),
        1e9,
      );
      s = run(s, stats.respawnDelay + 0.2);
      expect(s.alive, isTrue);
      expect(s.hull, stats.maxHull);
      expect(s.position.x, s.home.x);
      expect(s.position.y, s.home.y);
    });

    test('ölü alien erken doğmaz', () {
      var s = AlienSim.applyDamage(spawn(), 1e9);
      s = run(s, stats.respawnDelay - 1);
      expect(s.alive, isFalse);
    });
  });
}
