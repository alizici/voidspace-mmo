@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/remote_entities.dart';
import 'package:voidspace3/net/ship_pose.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// UZAK GEMİNİN DURUŞU — gerçek ara değer yolu.
///
/// `EntitySnapshot.lerp` kütüphanede duruyor ve doğru çalışıyor ama üretimde
/// ÇAĞIRANI YOK: istemci ara değeri [RemoteEntities] içinde YERİNDE hesaplıyor,
/// çünkü kare başına gemi başına bir nesne ayırmak 40 gemide saniyede binlerce
/// kısa ömürlü nesne ederdi.
///
/// Yani `lerp`i test etmek ölü bir yolu kilitler. Ekranda görünen şeyi
/// kilitleyen tek yer burası.
void main() {
  const world = 12000.0;

  EntitySnapshot poz({
    required int id,
    required double x,
    required bool firing,
    required int target,
    required bool canli,
  }) => EntitySnapshot(
    id: id,
    position: Vec2(x, 4000),
    angle: 0,
    thrust: 0,
    shieldFraction: 1,
    hullFraction: 1,
    alive: canli,
    boosting: false,
    firing: firing,
    weaponTarget: target,
  );

  /// İki örnek besleyip oynatma saatini aralarına getirir — yani ara değer
  /// koluna girmeye zorlar.
  ShipPose? araDegerDurusu({
    required EntitySnapshot a,
    required EntitySnapshot b,
  }) {
    final uzak = RemoteEntities()
      ..ingest(100, [a])
      ..ingest(112, [b]);
    // Oynatma saati gecikmeyle geriden gidiyor; birkaç kare ilerletmek onu
    // iki örneğin arasına taşıyor.
    for (var i = 0; i < 30; i++) {
      uzak.advance(1 / 60);
    }
    return uzak.poseOf(7);
  }

  test('ara değer ATEŞ ve HEDEFİ taşır — en yeni örnekten', () {
    // İkisi de a'da kapalı, b'de açık. Bayraklar ara değer ALMAZ: en yeni
    // gerçek doğru olandır. Düşerlerse uzak gemilerin namlu parlaması ve nişan
    // çizgisi ara değer penceresi boyunca kaybolur — yani neredeyse her zaman.
    final durus = araDegerDurusu(
      a: poz(id: 7, x: 1000, firing: false, target: 0, canli: true),
      b: poz(id: 7, x: 2000, firing: true, target: 42, canli: true),
    );

    expect(durus, isNotNull, reason: 'iz düşmüş — besleme yolu değişmiş');
    expect(durus!.firing, isTrue, reason: 'ateş bayrağı ara değerde düştü');
    expect(durus.weaponTarget, 42, reason: 'hedef kimliği ara değerde düştü');

    // Gerçekten ARA DEĞER kolundayız: konum iki örneğin arasında.
    expect(durus.x, greaterThan(1000.0));
    expect(durus.x, lessThan(2000.0));
    expect(durus.x, lessThan(world));
  });

  test('ara değer İMHAYI geciktirmez — canlılık en yeni örnekten', () {
    // a canlı, b ölü. Bayrak a'dan alınırsa enkaz bütün ara değer penceresi
    // boyunca uçmaya devam eder ve patlama gecikir.
    final durus = araDegerDurusu(
      a: poz(id: 7, x: 1000, firing: true, target: 42, canli: true),
      b: poz(id: 7, x: 2000, firing: false, target: 0, canli: false),
    );

    expect(durus, isNotNull);
    expect(durus!.alive, isFalse, reason: 'imha ara değerde gecikti');
    expect(durus.firing, isFalse, reason: 'ölü gemi hâlâ ateş ediyor');
    expect(durus.weaponTarget, 0);
  });
}
