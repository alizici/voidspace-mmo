@Tags(['kapsam', 'turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// OTOMATİK DONATIM — "elimdekilerin en iyisini tak".
///
/// Donatmak tek tek yapılan bir işti: yuva seç, parça seç, TAK. Yirmi bir
/// yuvalık bir gövdede altmış üç dokunuş, üstelik hangi parçanın nereye
/// gideceğini oyuncunun hesaplaması gerekiyordu. Buradaki testler o hesabın
/// doğru yapıldığını ve BEDAVA OLMADIĞINI — yani gerçekten savaş puanını
/// artırdığını — ölçüyor.
void main() {
  final hull = HullClass.starter;

  /// Katalogdaki gerçek lazerler, rank sırasına göre. Kimlik uydurmuyoruz:
  /// olmayan bir `specId` sessizce elenir ve test hiçbir şey ölçmezdi.
  final lazerler =
      Catalogue.items.where((s) => s.slot == SlotType.laser).toList()
        ..sort((a, b) => a.tier.index.compareTo(b.tier.index));

  /// [n] tane, [sira]. sıradaki lazerden üretir (0 = en düşük rank).
  Map<String, ItemInstance> depo(int sira, int n, {String on = 'x'}) {
    final spec = lazerler[sira.clamp(0, lazerler.length - 1)];
    return {
      for (var i = 0; i < n; i++)
        '$on$i': ItemInstance(instanceId: '$on$i', specId: spec.id),
    };
  }

  double puan(Loadout l, Map<String, ItemInstance> env) =>
      CombatGlossary.battleRating(
        LoadoutResolver.resolve(l, env, Catalogue.byId),
      );

  test('boş gemi DOLUYOR ve savaş puanı artıyor', () {
    final env = depo(0, 3);
    final l = Loadout(hullId: hull.id);
    final once = puan(l, env);

    final plan = LoadoutResolver.enIyiDonanim(l, env, Catalogue.byId);
    expect(plan, isNotEmpty, reason: 'boş gemiye hiçbir şey takılmadı');
    for (final MapEntry(key: yuva, value: id) in plan.entries) {
      l.equip(yuva, id);
    }
    expect(puan(l, env), greaterThan(once));
  });

  test('AYNI parça iki yuvaya takılmıyor', () {
    final env = depo(0, 3);
    final plan = LoadoutResolver.enIyiDonanim(
      Loadout(hullId: hull.id),
      env,
      Catalogue.byId,
    );
    expect(plan.values.toSet(), hasLength(plan.length));
  });

  test('YÜKSEK rank tercih ediliyor', () {
    // Kırılırsa: oyuncu düğmeye basıyor ve elindeki en iyi parça depoda
    // kalıyor — düğmenin verdiği tek söz bu.
    final env = {...depo(0, 2, on: 'd'), ...depo(lazerler.length - 1, 1, on: 'y')};
    final plan = LoadoutResolver.enIyiDonanim(
      Loadout(hullId: hull.id),
      env,
      Catalogue.byId,
    );
    expect(plan.values, contains('y0'), reason: 'en yüksek rank takılmadı');
  });

  test('zaten EN İYİSİ takılıyken plan BOŞ', () {
    // İşlemsiz bir düğme sessiz kalmalı: sunucuya boş yere emir göndermek,
    // her basışta bir tur ağ trafiği demek.
    final env = depo(0, 1);
    final l = Loadout(hullId: hull.id)..equip(const SlotRef(SlotType.laser, 0), 'x0');
    expect(LoadoutResolver.enIyiDonanim(l, env, Catalogue.byId), isEmpty);
  });

  test('YUVA DOLUYKEN kötü parça iyisiyle DEĞİŞİYOR', () {
    // Bütün yuvalar dolu: iyi parçanın girebileceği tek yer, kötü birinin
    // yeri. Boş yuva bırakılsaydı algoritma haklı olarak oraya koyardı ve
    // test değiştirme davranışını hiç ölçmezdi.
    final yuvaSayisi = hull.slotCount(SlotType.laser);
    final env = {
      ...depo(0, yuvaSayisi, on: 'k'),
      ...depo(lazerler.length - 1, 1, on: 'i'),
    };
    final l = Loadout(hullId: hull.id);
    for (var i = 0; i < yuvaSayisi; i++) {
      l.equip(SlotRef(SlotType.laser, i), 'k$i');
    }
    final once = puan(l, env);

    final plan = LoadoutResolver.enIyiDonanim(l, env, Catalogue.byId);
    expect(plan.values, contains('i0'), reason: 'iyi parça depoda kaldı');
    for (final MapEntry(key: yuva, value: id) in plan.entries) {
      l.equip(yuva, id);
    }
    expect(puan(l, env), greaterThan(once));
  });

  test('BÜYÜK depoda makul sürede bitiyor', () {
    // Gerçek bir kayıtta 5.773 parça ölçüldü. Aday listesi kırpılmasaydı
    // düğme dakikalarca düşünürdü.
    final env = depo(0, 4000);
    final saat = Stopwatch()..start();
    LoadoutResolver.enIyiDonanim(Loadout(hullId: hull.id), env, Catalogue.byId);
    saat.stop();
    expect(
      saat.elapsedMilliseconds,
      lessThan(2000),
      reason: 'otomatik donatım ${saat.elapsedMilliseconds} ms sürdü',
    );
  });
}
