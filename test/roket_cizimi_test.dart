@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/components/combat_layer.dart';

/// ROKET ÇİZİMİ (18.6): roket olayı lazer dalgasının dışında, tek mermi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CombatLayer duel() => CombatLayer()
    ..begin()
    ..track(1, 0, 0, 0, 1, Bastion.hardpoints.length)
    ..track(2, 600, 0, 0);

  void run(CombatLayer layer, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      layer.update(1 / 60);
    }
  }

  // KARAR 18.6 s1
  test('roket olayı TEK mermi doğurur, namlu dalgasına girmez', () {
    final layer = duel();
    layer.fire(
      shooterId: 1,
      targetId: 2,
      damage: 4000,
      shieldHit: true,
      killed: false,
      roket: true,
    );
    expect(layer.debugBoltCount, 1, reason: 'roket beş namludan çıktı');
    expect(layer.debugRoketCount, 1);
    run(layer, 1.5);
    expect(layer.debugBoltCount, 0, reason: 'roket hedefe varmadı');
    expect(layer.debugLabelCount, 1, reason: 'roketin sayısı düşmedi');
  });

  test('lazer olayı roket mermisi doğurmaz', () {
    final layer = duel();
    layer.fire(
      shooterId: 1,
      targetId: 2,
      damage: 100,
      shieldHit: true,
      killed: false,
    );
    expect(layer.debugRoketCount, 0);
    expect(layer.debugBoltCount, Bastion.hardpoints.length);
  });
}
