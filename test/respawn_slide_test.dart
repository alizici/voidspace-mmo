@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/predicted_ship.dart';
import 'package:voidspace3/net/remote_entities.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Yeniden doğan bir geminin EKRANDAKİ davranışı.
///
/// Sunucu ölen gemiyi doğuş noktasına ışınlıyor. İstemci ise iki örnek
/// arasını pürüzsüzce dolduruyor — ve ışınlanma iki örnek arasında olduğunda
/// "pürüzsüz" demek, enkazdan doğuş noktasına SÜZÜLEN bir hayalet demek.
void main() {
  EntitySnapshot at(Vec2 p, {bool alive = true}) => EntitySnapshot(
    id: 7,
    position: p,
    angle: 0,
    thrust: 0,
    shieldFraction: alive ? 1 : 0,
    hullFraction: alive ? 1 : 0,
    alive: alive,
    boosting: false,
  );

  /// Ölüm noktasından doğuş noktasına ışınlanan bir gemiyi izler ve ARADA
  /// kaç kare çizildiğini sayar.
  ({int between, double maxStep}) fly() {
    final remotes = RemoteEntities();
    const death = Vec2(2000, 2000);
    const spawn = Vec2(9000, 6000);

    var between = 0;
    var maxStep = 0.0;
    Vec2? last;

    // GERÇEK akış: her tik bir örnek gelir ve arada kareler çizilir.
    // Snapshot'ları toplu gönderip sonra çizmek, ölüm örneğinin tampondan
    // düşmesine yol açıyor ve hatayı gizliyordu.
    void render(int frames) {
      for (var i = 0; i < frames; i++) {
        remotes.advance(1 / 120);
        final pose = remotes.poseOf(7);
        if (pose == null) continue;
        final p = Vec2(pose.x, pose.y);
        // İki uçtan da uzaksa gemi ARADA bir yerde çiziliyor demektir.
        if (p.distanceTo(death) > 50 && p.distanceTo(spawn) > 50) between++;
        final previous = last;
        if (previous != null) {
          final step = p.distanceTo(previous);
          if (step > maxStep) maxStep = step;
        }
        last = p;
      }
    }

    var tick = 0;
    for (; tick < 12; tick++) {
      remotes.ingest(tick, [at(death)]);
      render(4); // 30 Hz tik, 120 Hz çizim
    }
    // Sunucu ışınladı — ölüm örneği HÂLÂ tamponda.
    for (; tick < 24; tick++) {
      remotes.ingest(tick, [at(spawn)]);
      render(4);
    }
    return (between: between, maxStep: maxStep);
  }

  test('yeniden doğan gemi enkazdan doğuş noktasına SÜZÜLMEZ', () {
    final r = fly();
    // Işınlanma TEK karede olmalı: arada çizilen kare olmamalı.
    expect(
      r.between,
      0,
      reason:
          'gemi ${r.between} kare boyunca ölüm ile doğuş noktası ARASINDA '
          'çizildi — ekranda hayalet gibi süzülüyor',
    );
  });

  test('KENDİ gemin de süzülmez — doğuş noktasına YAKIN ölsen bile', () {
    // Mesafe eşiği (420) tek başına yetmiyordu: yakında ölünce eşiğin altında
    // kalıyor ve gemi ekranda kayarak gidiyordu. Kesin sinyal ölüden diriye
    // geçiş.
    const world = GameWorld.standard;
    const stats = ShipStats.bastion;
    const deathAt = Vec2(6000, 4000);
    // Doğuş noktası eşiğin İÇİNDE: 300 birim uzakta.
    const spawnAt = Vec2(6300, 4000);

    final ship = PredictedShip(
      world: world,
      initial: ShipSimState.spawn(stats, deathAt),
    );

    // Sunucu gemiyi öldürdü.
    final dead = ShipSim.applyDamage(ShipSimState.spawn(stats, deathAt), 1e6);
    ship.reconcile(SelfSnapshot(acknowledgedSeq: 0, state: dead));
    ship.advance(1 / 30);
    expect(ship.state.alive, isFalse, reason: 'kurulum: gemi ölmeli');

    // Sunucu yeniden doğurdu — YAKINDA.
    ship.reconcile(
      SelfSnapshot(
        acknowledgedSeq: 0,
        state: ShipSimState.spawn(stats, spawnAt),
      ),
    );

    // Çizilen poz DOĞRUDAN doğuş noktasında olmalı, arada değil.
    final drawn = ship.pose;
    expect(
      Vec2(drawn.x, drawn.y).distanceTo(spawnAt),
      lessThan(1),
      reason: 'gemi ölüm ile doğuş noktası arasında çiziliyor — kayıyor',
    );
  });

  test('NORMAL hareket hâlâ ara değerden geçer', () {
    // Bu testin varlık sebebi: yukarıdaki hatayı "ara değeri tamamen kapat"
    // diyerek de düzeltebilirdim ve o test yine yeşil olurdu. Bu, o kaçamağı
    // kapatıyor — pürüzsüzlük ışınlanma yakalandı diye feda edilemez.
    final remotes = RemoteEntities();
    const start = Vec2(2000, 2000);
    final positions = <Vec2>[];

    // Tik başına 10 birim: meşru hızın (tik başına ~20) altında.
    for (var tick = 0; tick < 24; tick++) {
      remotes.ingest(tick, [at(start + Vec2(tick * 10, 0))]);
      for (var f = 0; f < 4; f++) {
        remotes.advance(1 / 120);
        final pose = remotes.poseOf(7);
        if (pose != null) positions.add(Vec2(pose.x, pose.y));
      }
    }

    // Ara değer çalışıyorsa örnekler ARASINDA da kare üretilmeli: yani
    // çizilen x değerlerinin çoğu tam 10'un katı OLMAMALI.
    final onSample = positions
        .where((p) => ((p.x - start.x) % 10).abs() < 0.01)
        .length;
    expect(
      onSample,
      lessThan(positions.length ~/ 2),
      reason:
          'çizilen konumların çoğu tam örnek noktasında — ara değer '
          'çalışmıyor, gemiler tik tik zıplıyor',
    );
  });
}
