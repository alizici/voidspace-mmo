@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/components/combat_layer.dart';

/// DROİD ATEŞ ETMEZ (05.1).
///
/// Droid bir silah değil sağlayıcı: geminin çarpanlarını taşıyor, kendi
/// mermisi yok. Bir süre ekranda droid başına bir mermi çiziliyordu ve
/// yanlıştı — sunucu droid hasarını geminin vuruşuna ekliyor, yani ekranda
/// iki ateş kaynağı görünürken inen tek bir hasar vardı.
///
/// Ölçülen: yaylım namlu sayısı kadar mermi üretiyor, ne bir fazla ne bir
/// eksik; filodaki droid sayısı bu sayıyı DEĞİŞTİRMİYOR.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CombatLayer duel({int lasers = 5, double distance = 500}) => CombatLayer()
    ..begin()
    ..track(1, 0, 0, 0, 1, lasers)
    ..track(2, distance, 0, 0);

  void vur(CombatLayer c, {int damage = 100}) => c.fire(
    shooterId: 1,
    targetId: 2,
    damage: damage,
    shieldHit: true,
    killed: false,
  );

  // KARAR 05.1 s1
  test('yaylım YALNIZ namlu sayısı kadar mermi üretiyor', () {
    for (final namlu in [1, 3, Bastion.hardpoints.length]) {
      final c = duel(lasers: namlu);
      vur(c);
      expect(
        c.debugBoltCount,
        namlu,
        reason: '$namlu namlulu gemi $namlu mermiden başkasını çıkardı',
      );
    }
  });

  // KARAR 05.1 s1
  test('namlusuz gemi mermi üretmiyor ama sayı yine düşüyor', () {
    final c = duel(lasers: 0);
    vur(c, damage: 250);
    expect(c.debugBoltCount, 0, reason: 'silahsız gemi ateş etti');
    expect(
      c.debugLabelCount,
      1,
      reason: 'mermi yok diye hasar sayısı da kayboldu',
    );
  });
}
