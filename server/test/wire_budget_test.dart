@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/zone.dart';

/// Snapshot baytları NEREYE gidiyor.
///
/// Kapasite ölçümü bant genişliğinin CPU'dan önce bittiğini söyledi (240
/// oyuncuda 52,5 KB/s/oyuncu). Sıradaki iş onu küçültmek — ama önce baytların
/// kimde olduğunu bilmek gerekiyor. "Alienler delta'sız" diye bir not vardı ve
/// BAYATTI; tahminle optimize etmek tam olarak bu yüzden tehlikeli.
void main() {
  test('alien delta GERÇEKTEN kısmi maske üretiyor', () {
    // Duran bir alien telde hiçbir alan değiştirmemeli. Maske sıfırsa kayıt
    // 3 bayta (kimlik + maske) iniyor.
    final zone = Zone(alienCount: 12);
    final viewer = zone.join('A')!;
    viewer.state = viewer.state.copyWith(position: GameWorld.standard.centre);

    zone
      ..step()
      ..refreshWire()
      ..collectVisibleAliens(viewer)
      ..promoteWire();

    var partial = 0;
    var full = 0;
    for (var tick = 0; tick < 60; tick++) {
      zone
        ..step()
        ..refreshWire();
      final visible = zone.collectVisibleAliens(viewer);
      for (final id in visible) {
        if (!zone.alienWireValid(id)) continue;
        final mask = AlienDelta.maskOf(
          zone.alienWireNow(id),
          zone.alienWire(id),
        );
        if (mask == AlienDelta.full) {
          full++;
        } else {
          partial++;
        }
      }
      zone.promoteWire();
    }

    // ignore: avoid_print
    print('alien kaydı: $partial kısmi · $full tam');
    expect(
      partial,
      greaterThan(full),
      reason: 'alien delta çalışmıyor — kayıtların çoğu tam gidiyor',
    );
  });

  test('DEĞİŞMEYEN kayıtların oranı — taban maliyetinin fırsatı', () {
    // Ölçülen taban: kayıt başına 3 bayt (kimlik + maske), yani "hiçbir şey
    // değişmedi" demenin bile bedeli var. 240 görünür entity'de bu 21 KB/s —
    // ölçülen 52,5 KB/s'nin %40'ı.
    //
    // Fırsat, o kayıtları HİÇ göndermemek: istemci zaten bir saniye
    // sessizliğe dayanıyor (`RemoteEntities._staleTicks`). Ama fırsatın
    // büyüklüğü, kaç kaydın gerçekten değişmediğine bağlı — ve hareket eden
    // bir gemide delta zaten dolu. Tahmin etmek yerine iki uç da ölçülüyor.
    ({int zero, int total}) sample({required bool moving}) {
      final world = GameWorld.standard;
      final zone = Zone(alienCount: 36);
      for (var i = 0; i < 40; i++) {
        final ship = zone.join('P$i')!;
        ship.state = ship.state.copyWith(
          position: world.centre + Vec2((i % 8) * 60.0, (i ~/ 8) * 60.0),
        );
      }
      final viewer = zone.ships.values.first;
      var zero = 0;
      var total = 0;
      for (var tick = 0; tick < 120; tick++) {
        if (moving) {
          var seq = tick + 1;
          for (final ship in zone.ships.values) {
            zone.enqueue(
              ship,
              ShipInput(
                seq: seq++,
                moveTarget: world.centre + Vec2(tick * 3.0, ship.id * 7.0),
              ),
            );
          }
        }
        zone
          ..step()
          // Kuantalanmış değerleri tik başına BİR kez hesaplayan çağrı.
          // Gateway'in snapshot yolunda yapılıyor; testte atlanınca `wireNow`
          // hiç dolmuyor ve her kayıt "değişmemiş" görünüyordu — ölçüm %100
          // diyordu ve bu açıkça yanlıştı.
          ..refreshWire();
        for (final other in zone.collectVisible(viewer)) {
          if (!other.wireValid) continue;
          total++;
          if (EntityDelta.maskOf(other.wireNow, other.wire) == 0) zero++;
        }
        for (final id in zone.collectVisibleAliens(viewer)) {
          if (!zone.alienWireValid(id)) continue;
          total++;
          if (AlienDelta.maskOf(zone.alienWireNow(id), zone.alienWire(id)) ==
              0) {
            zero++;
          }
        }
        zone.promoteWire();
      }
      return (zero: zero, total: total);
    }

    final idle = sample(moving: false);
    final busy = sample(moving: true);
    // ignore: avoid_print
    print(
      'DURAN   %${(100 * idle.zero / idle.total).toStringAsFixed(0)} kayıt '
      'değişmiyor (${idle.zero}/${idle.total})',
    );
    // ignore: avoid_print
    print(
      'HAREKET %${(100 * busy.zero / busy.total).toStringAsFixed(0)} kayıt '
      'değişmiyor (${busy.zero}/${busy.total})',
    );

    // Sakin dünyada fırsat büyük, kavgada küçük. İkisini de kilitlemek,
    // ileride "değişmeyeni gönderme" işi yapıldığında beklenen kazancın
    // hangi koşulda geçerli olduğunu belgeliyor.
    expect(
      idle.zero / idle.total,
      greaterThan(0.5),
      reason: 'sakin dünyada bile kayıtlar değişiyor — delta bozulmuş olabilir',
    );
    expect(
      busy.zero / busy.total,
      lessThan(0.5),
      reason: 'hareket eden gemide delta boş çıkıyor — ölçüm yanlış kurulmuş',
    );
  });

  test('bir alien kaydının ORTALAMA boyu tam kaydın altında', () {
    // Tam kayıt 9 bayt ([AlienSnapshot.wireSize]); ölçülen ortalama ~4,0.
    //
    // Eşik tam kayda BAĞLI ve bu bir zayıflık: sabit büyüdüğünde sınır
    // sessizce gevşiyor — 8'den 9'a çıktığında tam olarak bu oldu. Aşağıdaki
    // ikinci iddia o gevşemeyi kapatıyor: ölçülen ortalama, tam kaydın
    // YARISININ altında kalmak zorunda.
    final zone = Zone(alienCount: 24);
    final viewer = zone.join('A')!;
    viewer.state = viewer.state.copyWith(position: GameWorld.standard.centre);
    zone
      ..step()
      ..refreshWire()
      ..collectVisibleAliens(viewer)
      ..promoteWire();

    var bytes = 0;
    var records = 0;
    for (var tick = 0; tick < 90; tick++) {
      zone
        ..step()
        ..refreshWire();
      final visible = zone.collectVisibleAliens(viewer);
      final w = ByteWriter(1024);
      for (final id in visible) {
        final mask = zone.alienWireValid(id)
            ? AlienDelta.maskOf(zone.alienWireNow(id), zone.alienWire(id))
            : AlienDelta.full;
        AlienDelta.write(w, id, zone.alienWireNow(id), mask);
        records++;
      }
      bytes += w.length;
      zone.promoteWire();
    }

    final average = bytes / records;
    // ignore: avoid_print
    print(
      'alien kaydı ortalama ${average.toStringAsFixed(2)} bayt '
      '(tam kayıt ${AlienSnapshot.wireSize})',
    );
    expect(average, lessThan(AlienSnapshot.wireSize.toDouble()));

    // Ve gevşemeyen bir tavan: delta'nın DEĞERİ, tam kaydın yarısının altında
    // kalmasında. Yalnız üstteki iddia dursaydı `AlienSnapshot.wireSize` her
    // büyüdüğünde sınır kendiliğinden gevşerdi — 8'den 9'a çıktığında ortalama
    // 8,5'e fırlasa bile test yeşil kalırdı, yani alien bandı iki katına
    // çıkar ve kimse görmezdi.
    expect(
      average,
      lessThan(AlienSnapshot.wireSize / 2),
      reason: 'delta kazancı erimiş: kayıt ortalaması tam kaydın yarısını aştı',
    );
  });
}
