@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/predicted_ship.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// İstemci tarafı tahmin ve mutabakat.
///
/// Ağ olmadan test ediliyor, çünkü test edilen şey ağ değil MUHASEBE: hangi
/// girdiler onaylandı, hangileri yeniden oynatılacak, sapma nereye yazılacak.
/// Bu muhasebe bozulduğunda ortaya çıkan belirti "lastik bant" — gemi her
/// snapshot'ta bir gidiş-dönüş kadar geri sıçrar — ve sebebi ağda aranırken
/// hep buradadır.
void main() {
  const world = GameWorld.standard;
  const stats = ShipStats.bastion;

  PredictedShip make() => PredictedShip(
    world: world,
    initial: ShipSimState.spawn(stats, world.centre),
  );

  /// [ship]'i tam [ticks] adım ilerlet ve üretilen girdileri döndür.
  List<ShipInput> run(PredictedShip ship, int ticks, {Vec2? axis}) {
    final produced = <ShipInput>[];
    for (var i = 0; i < ticks; i++) {
      ship.axis = axis ?? const Vec2(1, 0);
      produced.addAll(ship.advance(ShipSim.fixedDt));
    }
    return produced;
  }

  /// Sunucunun [ackSeq] girdisine kadar işlemiş hâli.
  SelfSnapshot serverAfter(List<ShipInput> inputs, int count) {
    var s = ShipSimState.spawn(stats, world.centre);
    for (var i = 0; i < count; i++) {
      s = ShipSim.step(s, inputs[i], world);
    }
    return SelfSnapshot(acknowledgedSeq: inputs[count - 1].seq, state: s);
  }

  test('sunucuyu beklemeden hareket eder', () {
    final ship = make();
    final start = ship.state.position;
    run(ship, 10);

    expect(
      ship.state.position.x,
      greaterThan(start.x),
      reason: 'tahmin yoksa her tuşa basış bir gidiş-dönüş bekler',
    );
    expect(ship.unacknowledgedCount, 10);
  });

  test('adım başına TAM BİR girdi üretir', () {
    final ship = make();
    // Yarım adımlık kareler: sabit adım korunmazsa yeniden oynatma başka bir
    // sonuç verir ve mutabakat gemiyi zıplatır.
    var produced = 0;
    for (var i = 0; i < 20; i++) {
      produced += ship.advance(ShipSim.fixedDt / 2).length;
    }
    expect(produced, 10);
  });

  test('GERİDE kalan snapshot gemiyi geri sıçratmaz', () {
    // Mutabakatın var olma sebebi. Sunucunun onayladığı durum daima
    // GEÇMİŞTEDİR (bir gidiş-dönüş kadar). Doğrudan yazılsaydı gemi her
    // snapshot'ta geriye ışınlanırdı — "lastik bant" tam olarak budur.
    final ship = make();
    final inputs = run(ship, 12);
    final predicted = ship.state.position;

    ship.reconcile(serverAfter(inputs, 6));

    expect(ship.state.position.x, closeTo(predicted.x, 0.001));
    expect(ship.state.position.y, closeTo(predicted.y, 0.001));
    expect(ship.unacknowledgedCount, 6, reason: 'onaylananlar düşmeli');
    expect(
      ship.correctionDistance,
      lessThan(0.001),
      reason: 'tahmin doğruysa görsel düzeltme olmamalı',
    );
  });

  test('düzeltme TEK PİKSEL oynatmaz — takılmanın kaynağı buydu', () {
    // Mutabakat, ekrandaki gemiyi ANINDA hiç kıpırdatmamalı; yalnız nereye
    // gittiğini değiştirmeli. Kıpırdatırsa, saniyede 30 kez gelen snapshot
    // saniyede 30 küçük sıçrama demek — ve oyun "takılarak" uçuyor görünür.
    final ship = make();
    final inputs = run(ship, 8);
    final server = serverAfter(inputs, 8);
    // Poz nesnesi YENİDEN KULLANILIYOR — karşılaştırma için kopyala.
    final beforeX = ship.pose.x;
    final beforeY = ship.pose.y;

    // Sunucu 40 birim başka yerde olsun (düşen girdi, tekrarlanan girdi).
    final nudged = SelfSnapshot(
      acknowledgedSeq: server.acknowledgedSeq,
      state: server.state.copyWith(
        position: server.state.position + const Vec2(40, 0),
      ),
    );
    ship.reconcile(nudged);

    // Mantık sunucunun dediği yerde…
    expect(ship.state.position.x, closeTo(nudged.state.position.x, 0.001));
    // …ama ÇİZİLEN poz zerre oynamadı.
    expect(ship.pose.x, closeTo(beforeX, 0.001));
    expect(ship.pose.y, closeTo(beforeY, 0.001));
    expect(ship.correctionDistance, closeTo(40, 0.5));

    // Düzeltme sönmeli: yarım saniye sonra iz kalmamalı.
    for (var i = 0; i < 30; i++) {
      ship.advance(ShipSim.fixedDt);
    }
    expect(ship.correctionDistance, lessThan(2));
  });

  test('üretim hızı sunucu kuyruğunu HEDEFTE tutar', () {
    // Sunucu tik başına tam bir girdi işler. İstemci az üretirse kuyruk
    // boşalır ve sunucu son girdiyi tekrarlar; çok üretirse kuyruk taşar ve
    // sunucu girdi düşürür. İkisi de düzeltme demek — yani takılma.
    final ship = make();
    final inputs = run(ship, 4);

    SelfSnapshot withDepth(int depth) => SelfSnapshot(
      acknowledgedSeq: inputs.last.seq,
      pendingInputs: depth,
      state: serverAfter(inputs, 4).state,
    );

    ship.reconcile(withDepth(6));
    expect(ship.inputRate, lessThan(1), reason: 'kuyruk şişmiş → yavaşla');

    ship.reconcile(withDepth(0));
    expect(ship.inputRate, greaterThan(1), reason: 'kuyruk boş → hızlan');

    ship.reconcile(withDepth(2));
    expect(ship.inputRate, closeTo(1, 0.001), reason: 'hedefte → dokunma');

    // Bant dar: ±%6'nın dışına çıkmak gecikmeyi gizlemek yerine görünür kılar.
    ship.reconcile(withDepth(255));
    expect(ship.inputRate, greaterThanOrEqualTo(0.94));
  });

  test('büyük sapma IŞINLANIR — yumuşatmak yalan söylemek olurdu', () {
    final ship = make();
    final inputs = run(ship, 8);
    final server = serverAfter(inputs, 8);

    final teleported = SelfSnapshot(
      acknowledgedSeq: server.acknowledgedSeq,
      state: server.state.copyWith(
        position: server.state.position + const Vec2(3000, 0),
      ),
    );
    ship.reconcile(teleported);

    expect(ship.correctionDistance, 0);
    expect(
      ship.pose.x,
      closeTo(teleported.state.position.x, 1),
      reason: 'yeniden doğuşu yumuşatmak gemiyi haritada süzdürür',
    );
  });

  test('poz iki tik arasında ara değer alır', () {
    final ship = make();
    run(ship, 6);
    final atTickX = ship.pose.x;

    // Yarım adım: poz ilerlemeli ama durum ilerlememeli.
    ship
      ..axis = const Vec2(1, 0)
      ..advance(ShipSim.fixedDt / 2);
    final halfX = ship.pose.x;

    expect(halfX, greaterThan(atTickX));
    expect(
      halfX,
      lessThan(ship.state.position.x + 0.001),
      reason: '30 Hz simülasyon 120 Hz ekranda basamaklı görünmemeli',
    );
  });

  test('ağ ölürse onaylanmamış girdi sınırsız büyümez', () {
    final ship = make();
    run(ship, 300); // 10 saniye sessizlik
    expect(
      ship.unacknowledgedCount,
      lessThanOrEqualTo(PredictedShip.maxUnacked),
    );
  });
}
