@Tags(['disi'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Uçuş mekaniği — artık oyun döngüsü OLMADAN.
///
/// Bu dosya `test/flight_test.dart`'ın devamı: aynı sözleşmeler, ama Flutter
/// ya da Flame kurmadan milisaniyeler içinde koşuyor. Simülasyonun paylaşılan
/// bir pakete taşınmasının ilk somut kazancı bu.
///
/// Sözleşme değişmedi: **gemi tıklanan yere gider ve orada durur.** Girdiyi
/// ezen hiçbir kural yok; sınır bile hareketi engellemez, yalnız sonucunu
/// kelepçeler.
void main() {
  const stats = ShipStats.bastion;
  const world = GameWorld.standard;

  ShipSimState spawn() => ShipSimState.spawn(stats, world.centre);

  /// [seconds] kadar sabit adımla ilerlet. Her adımda [input] uygulanır;
  /// [first] verilirse YALNIZ ilk adımda (kenar tetikli komutlar için).
  ShipSimState advance(
    ShipSimState s,
    double seconds, {
    ShipInput input = ShipInput.idle,
    ShipInput? first,
  }) {
    final steps = (seconds * ShipSim.tickRate).round();
    var state = s;
    for (var i = 0; i < steps; i++) {
      state = ShipSim.step(state, i == 0 ? (first ?? input) : input, world);
    }
    return state;
  }

  group('hareket', () {
    test('tıklanan noktaya gider ve TAM orada durur', () {
      final target = world.centre + const Vec2(300, -180);
      final s = advance(
        spawn(),
        2.5,
        first: ShipInput(seq: 1, moveTarget: target),
      );

      expect(s.position.distanceTo(target), lessThan(0.001));
      expect(s.target, isNull, reason: 'varışta hedef bırakılmalı');
      expect(s.thrust, lessThan(0.02), reason: 'varışta itki sönmeli');
    });

    test('hedefe giderken itki mesafeyi artırır', () {
      final start = spawn();
      final far = world.centre + const Vec2(4000, 0);

      // Menzil dışında bir hedef: pencere boyunca hiç durmasın.
      final plain = advance(
        start,
        0.5,
        first: ShipInput(seq: 1, moveTarget: far),
      );
      final boosted = advance(
        start,
        0.5,
        first: ShipInput(seq: 1, moveTarget: far, boost: true),
      );

      final plainDistance = plain.position.distanceTo(start.position);
      final boostedDistance = boosted.position.distanceTo(start.position);
      expect(boostedDistance / plainDistance, closeTo(stats.boostFactor, 0.05));
      expect(boosted.boostCharges, stats.maxBoostCharges - 1);
    });

    test('klavye yönü tıkla-git hedefini ezer', () {
      final start = spawn();
      final s = advance(
        start,
        0.4,
        // Kuzeye tıkla ama doğuya bas: aynı girdi çerçevesinde bile klavye
        // kazanmalı.
        first: ShipInput(
          seq: 1,
          moveTarget: world.centre + const Vec2(0, -2000),
          axis: const Vec2(1, 0),
        ),
        input: const ShipInput(seq: 2, axis: Vec2(1, 0)),
      );

      expect(s.position.x, greaterThan(start.position.x));
      expect(s.position.y, closeTo(start.position.y, 0.001));
      expect(s.target, isNull);
    });

    test('harita dışına tıklamak gemiyi duvarda yakmaz', () {
      // Hedef DÜNYAYA GÖRELİ. Sihirli bir koordinattı (-9000, 4000) ve
      // haritanın o günkü boyuna göre seçilmişti: harita büyüyünce y ekseninde
      // 238 birimlik yolculuk 1.321 birime çıktı, gemi x duvarına vardığında
      // hâlâ y'de gidiyordu ve test bunu "duvarda itki yakıyor" sandı.
      //
      // y merkezde: yalnız x yolculuğu ölçülüyor, testin sorduğu şey o.
      final w = world;
      final s = advance(
        spawn(),
        60,
        first: ShipInput(seq: 1, moveTarget: Vec2(-w.width, w.centre.y)),
      );

      expect(s.position.x, closeTo(world.margin, 0.001));
      expect(
        s.thrust,
        lessThan(0.02),
        reason: 'gemi duvara yaslanıp sonsuza kadar itki yakıyor',
      );
    });

    test('açı daima [-π, π] içinde kalır', () {
      // Sekiz yöne sırayla dön: sarılmayan bir açı burada büyümeye başlardı ve
      // `u8` kuantalaması sessizce hassasiyet kaybederdi.
      var s = spawn();
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        s = advance(
          s,
          0.6,
          input: ShipInput(seq: k, axis: Vec2(math.cos(a), math.sin(a))),
        );
        expect(s.angle, inInclusiveRange(-math.pi, math.pi));
      }
    });
  });

  group('havuzlar', () {
    test('kalkan gecikme dolmadan yenilenmez', () {
      final hit = ShipSim.applyDamage(spawn(), 3000);
      expect(hit.sinceHit, 0);

      final duringDelay = advance(hit, stats.shieldRegenDelay - 0.2);
      expect(duringDelay.shield, hit.shield, reason: 'gecikmede yenilenmemeli');

      final after = advance(duringDelay, 1);
      expect(after.shield, greaterThan(hit.shield));
    });

    test('kalkan önce emer, taşan gövdeye iner', () {
      final s = ShipSim.applyDamage(spawn(), stats.maxShield + 500);
      expect(s.shield, 0);
      expect(s.hull, stats.maxHull - 500);
    });

    test('imha edilmiş gemi ne uçar ne yenilenir', () {
      final dead = ShipSim.applyDamage(
        spawn(),
        stats.maxShield + stats.maxHull,
      );
      expect(dead.alive, isFalse);

      final s = advance(
        dead,
        3,
        first: ShipInput(seq: 1, moveTarget: world.centre + const Vec2(900, 0)),
        input: const ShipInput(seq: 2, axis: Vec2(1, 0)),
      );
      expect(s.position, dead.position);
      expect(s.shield, 0);
    });
  });

  // ── Ağın bağlı olduğu iki özellik ───────────────────────────────────
  //
  // Aşağıdaki ikisi görsel bir davranış test etmiyor; TAHMİNİN ÇALIŞMASININ
  // ÖN KOŞULUNU test ediyor. Biri kırılırsa oyuncu ışınlanır ve sebebi
  // netcode'da değil burada olur.
  group('determinizm', () {
    test('aynı girdi dizisi aynı sonucu verir', () {
      final inputs = [
        for (var i = 0; i < 60; i++)
          ShipInput(
            seq: i,
            axis: Vec2(math.sin(i * 0.3), math.cos(i * 0.17)),
            boost: i == 5 || i == 40,
          ),
      ];

      ShipSimState run() {
        var s = spawn();
        for (final input in inputs) {
          s = ShipSim.step(s, input, world);
        }
        return s;
      }

      final a = run();
      final b = run();
      expect(a.position, b.position);
      expect(a.angle, b.angle);
      expect(a.thrust, b.thrust);
      expect(a.boostCharges, b.boostCharges);
    });

    test('geri sarıp yeniden oynatmak aynı duruma varır', () {
      // Mutabakatın (reconciliation) tamamı bu: sunucu 10. girdiyi işlediğini
      // söyler, istemci o duruma geri sarar ve 11..30'u YENİDEN OYNATIR.
      // Sonuç ileri koşuşla birebir aynı değilse her snapshot bir sıçrama
      // üretir.
      final inputs = [
        for (var i = 0; i < 30; i++)
          ShipInput(
            seq: i,
            axis: Vec2(math.sin(i * 0.4), 0),
            boost: i == 3,
            moveTarget: i == 12 ? world.centre + const Vec2(500, 500) : null,
          ),
      ];

      var straight = spawn();
      late ShipSimState checkpoint;
      for (var i = 0; i < inputs.length; i++) {
        if (i == 10) checkpoint = straight;
        straight = ShipSim.step(straight, inputs[i], world);
      }

      var replayed = checkpoint;
      for (var i = 10; i < inputs.length; i++) {
        replayed = ShipSim.step(replayed, inputs[i], world);
      }

      expect(replayed.position, straight.position);
      expect(replayed.angle, straight.angle);
      expect(replayed.thrust, straight.thrust);
      expect(replayed.target, straight.target);
      expect(replayed.boostCharges, straight.boostCharges);
      expect(replayed.shield, straight.shield);
    });
  });

  group('nişan yönelimi', () {
    /// Kuzeydeki sabit bir hedef.
    final aim = world.centre + const Vec2(0, -1000);

    /// O hedefe kilitli gemi.
    ShipSimState locked() => spawn().copyWith(aimPoint: aim);

    /// [s]'in nişan noktasına bakması gereken açı. Gemi doğuya kaydıkça bu
    /// açı da kayar — sabit bir sayı beklemek testi yanlış yapar.
    double wanted(ShipSimState s) =>
        math.atan2(aim.x - s.position.x, -(aim.y - s.position.y));

    /// Doğuya doğru [ticks] adım uçur.
    ShipSimState flyEast(ShipSimState s, int ticks) {
      var state = s;
      for (var i = 0; i < ticks; i++) {
        state = ShipSim.step(
          state,
          const ShipInput(seq: 1, axis: Vec2(1, 0)),
          world,
        );
      }
      return state;
    }

    test('nişan HAREKET YÖNÜNÜ ezer', () {
      final s = flyEast(locked(), 40);

      expect(
        s.position.x,
        greaterThan(world.centre.x),
        reason: 'nişan hareketi engellememeli, yalnız yönelimi belirlemeli',
      );
      expect(
        s.angle,
        closeTo(wanted(s), 0.05),
        reason: 'kilitli gemi hedefe bakmalı',
      );
      // …ve gittiği yöne (doğu = +π/2) BAKMAMALI.
      expect((s.angle - math.pi / 2).abs(), greaterThan(1.0));
    });

    test('nişan yokken hareket yönüne döner', () {
      final s = flyEast(spawn(), 40);
      expect(s.angle, closeTo(math.pi / 2, 0.1), reason: 'doğu = +π/2');
    });

    test('nişan düşünce yönelim serbest kalır', () {
      // Kilit koptuğunda gemi son hedefine bakmaya devam edemez.
      final aimed = flyEast(locked(), 40);
      final freed = flyEast(aimed.copyWith(clearAim: true), 40);
      expect(freed.angle, closeTo(math.pi / 2, 0.1));
    });

    test('üstünde durduğu hedefe dönmeye ÇALIŞMAZ', () {
      // Sıfıra yakın bir vektörün açısı gürültüdür; gemi titrerdi.
      var s = spawn().copyWith(aimPoint: world.centre, angle: 1.2);
      for (var i = 0; i < 10; i++) {
        s = ShipSim.step(s, const ShipInput(seq: 1), world);
      }
      expect(s.angle, closeTo(1.2, 1e-9));
    });

    test('ölen gemi nişanı bırakır', () {
      final dead = ShipSim.applyDamage(locked(), 1e9);
      final s = ShipSim.step(dead, const ShipInput(seq: 1), world);
      expect(s.aimPoint, isNull);
    });
  });
}
