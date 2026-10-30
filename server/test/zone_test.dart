@Tags(['disi'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/zone.dart';

/// Otoritenin kuralları.
///
/// Buradaki testlerin çoğu bir oynanış davranışını değil, bir HİLE YOLUNU
/// kapatıyor. İstemci düşmandır: hızlı girdi yollar, eski girdiyi tekrarlar,
/// görmemesi gereken şeyi ister. Her biri için burada bir satır var.
/// Gemiyi [hedef]e DÖNDÜR — ateş artık nişan yayının içinde olmalı.
///
/// `zone.dart` ateşi nişana bağladı: gemi hedefe dönmeden mermi çıkmıyor
/// (mobilde otomatik ateşle bariz olan hata buydu — yaratık tek atışta
/// ölünce dönüş hiç tamamlanmıyordu). Testler o güne kadar hedefi geminin
/// SAĞINA koyup ilk tikte atış bekliyordu; artık nişan almaları gerekiyor.
///
/// Bir tik adım atmak yerine açıyı doğrudan yazmak bilinçli: sınanan şey
/// dönüş değil, dönüşün ARDINDAN gelen davranış (hasar, ganimet, olay).
void nisanla(ServerShip gemi, Vec2 hedef) {
  final d = hedef - gemi.state.position;
  gemi.state = gemi.state.copyWith(angle: math.atan2(d.x, -d.y));
}

void main() {
  const world = GameWorld.standard;

  ShipInput forward(int seq) => ShipInput(seq: seq, axis: const Vec2(1, 0));

  group('katılma', () {
    test('gemiler ayrı noktalarda doğar', () {
      final zone = Zone();
      final a = zone.join('A')!;
      final b = zone.join('B')!;
      expect(a.id, isNot(b.id));
      expect(
        a.state.position.distanceTo(b.state.position),
        greaterThan(100),
        reason: 'üst üste doğmak gemileri gizler',
      );
    });

    test('kapasite dolunca reddeder', () {
      final zone = Zone(capacity: 2);
      expect(zone.join('A'), isNotNull);
      expect(zone.join('B'), isNotNull);
      expect(zone.join('C'), isNull);

      zone.leave(1);
      expect(zone.join('D'), isNotNull, reason: 'boşalan yer geri verilmeli');
    });
  });

  group('girdi otoritesi', () {
    test('tik başına TAM BİR girdi işlenir — hız hilesi kapalı', () {
      final zone = Zone();
      final ship = zone.join('A')!;
      final start = ship.state.position;

      // İstemci 10 kat hızlı girdi yolluyor.
      for (var i = 1; i <= 10; i++) {
        zone.enqueue(ship, forward(i));
      }
      final queued = ship.pending.length;
      zone.step();

      expect(
        ship.pending.length,
        queued - 1,
        reason: 'tek tikte tek girdi tüketilir',
      );
      // Asıl iddia bu: kaç girdi kuyruğa girerse girsin, BİR tik BİR adımdır.
      expect(
        ship.state.position.distanceTo(start),
        closeTo(ShipStats.bastion.speed * ShipSim.fixedDt, 0.001),
        reason: 'girdi biriktirerek hızlanılabiliyor',
      );
    });

    test('eski ve tekrarlanan sıra atılır', () {
      final zone = Zone();
      final ship = zone.join('A')!;
      zone
        ..enqueue(ship, forward(5))
        ..step();
      expect(ship.acknowledgedSeq, 5);

      // Yeniden oynatma saldırısı: onaylanmış bir sırayı geri yolla.
      zone
        ..enqueue(ship, forward(5))
        ..enqueue(ship, forward(3));
      expect(ship.pending, isEmpty);
    });

    test('kuyruk tavanı var — girdi biriktirilemez', () {
      final zone = Zone();
      final ship = zone.join('A')!;
      for (var i = 1; i <= 100; i++) {
        zone.enqueue(ship, forward(i));
      }
      expect(ship.pending.length, lessThanOrEqualTo(6));
      // En YENİ girdiler tutulur: oyuncunun son niyeti, en eskisinden değerli.
      expect(ship.pending.last.seq, 100);
    });

    test('paket gecikince itki İKİNCİ KEZ harcanmaz', () {
      // Kenar tetikli komut, kuyruk boşken tekrarlanan girdide temizlenmeli.
      // Temizlenmezse tek bir boşluk basışı, ağ tökezlediğinde bütün şarjları
      // yakar — ve bu, gerçek bir istemcide fark edilmesi en zor hatalardan.
      final zone = Zone();
      final ship = zone.join('A')!;
      zone.enqueue(
        ship,
        const ShipInput(seq: 1, axis: Vec2(1, 0), boost: true),
      );
      for (var i = 0; i < 40; i++) {
        zone.step();
      }
      expect(ship.state.boostCharges, ShipStats.bastion.maxBoostCharges - 1);
    });
  });

  group('ilgi alanı', () {
    test('yarıçap dışındaki gemi snapshot\'a girmez', () {
      final zone = Zone();
      final viewer = zone.join('A')!;
      final near = zone.join('B')!;
      final far = zone.join('C')!;

      near.state = near.state.copyWith(
        position: viewer.state.position + const Vec2(400, 0),
      );
      far.state = far.state.copyWith(
        position: world.clamp(
          viewer.state.position + const Vec2(Protocol.interestRadius + 500, 0),
        ),
      );

      final visible = zone.visibleTo(viewer).map((e) => e.id).toSet();
      expect(visible, contains(near.id));
      expect(
        visible,
        isNot(contains(far.id)),
        reason: 'tüm haritayı göndermek radar hilesini mümkün kılar',
      );
      expect(visible, isNot(contains(viewer.id)), reason: 'kendini görmez');
    });

    test('sınırda TİTREMEZ — giriş ve çıkış eşikleri ayrı', () {
      // Tek eşikle, tam sınırda seyreden bir gemi saniyede onlarca kez
      // snapshot'a girip çıkıyor; istemci de her seferinde bileşenini kurup
      // yıkıyor. Çin kaynaklarında AOI'nin klasik tuzağı olarak geçen
      // "边界抖动" bu, ve çözümü histerezis.
      final zone = Zone();
      final viewer = zone.join('A')!;
      final drifter = zone.join('B')!;

      void placeAt(double distance) {
        drifter.state = drifter.state.copyWith(
          position: viewer.state.position + Vec2(distance, 0),
        );
      }

      // Girişin hemen içi: görünür olur.
      placeAt(Protocol.interestRadius - 10);
      expect(zone.visibleTo(viewer).map((e) => e.id), contains(drifter.id));

      // Girişin hemen DIŞI ama çıkışın içi: görünür KALIR.
      placeAt(Protocol.interestRadius + 10);
      expect(
        zone.visibleTo(viewer).map((e) => e.id),
        contains(drifter.id),
        reason: 'histerezis yok — sınırda titreyecek',
      );

      // Çıkışın dışı: artık görünmez.
      placeAt(Protocol.interestExitRadius + 10);
      expect(zone.visibleTo(viewer), isEmpty);

      // Ve geri gelirken ÇIKIŞ eşiği değil GİRİŞ eşiği geçerli olmalı.
      placeAt(Protocol.interestRadius + 10);
      expect(
        zone.visibleTo(viewer),
        isEmpty,
        reason: 'çıktıktan sonra giriş eşiğine kadar gelmeli',
      );
    });

    test('ayrılan gemi görünür kümelerden de düşer', () {
      // Kalırsa, aynı `u16` kimlik yeniden kullanıldığında yeni gemi "zaten
      // görünüyordu" sayılır ve histerezis yanlış eşikle başlar.
      final zone = Zone();
      final viewer = zone.join('A')!;
      final other = zone.join('B')!;
      zone.visibleTo(viewer);
      expect(viewer.visible, contains(other.id));

      zone.leave(other.id);
      expect(viewer.visible, isNot(contains(other.id)));
    });
  });

  test('girdisi kesilen oturum zaman aşımına düşer', () {
    final zone = Zone();
    final ship = zone.join('A')!;
    expect(zone.timedOut(), isEmpty);

    final ticks = (Protocol.sessionTimeout * Protocol.tickRate).round() + 2;
    for (var i = 0; i < ticks; i++) {
      zone.step();
    }
    expect(zone.timedOut(), contains(ship));
  });

  group('silahlar', () {
    /// Referans build'in KRİTİKSİZ hâli.
    ///
    /// Bu gruptaki testler mekaniği ölçüyor (menzil, bekleme, kalkan→gövde
    /// sırası), zarı değil. Kritik açıkken her sayı zarın o anki sonucuna
    /// bağlı olurdu ve testler mekanik yerine `Random`'ı ölçerdi. Kritiğin
    /// KENDİSİ ayrı bir testte, aşağıda.
    final stats = ShipStats.bastion.copyWith(critChance: 0);

    /// İki gemiyi [distance] birim aralıkla kurar ve avcıyı hedefe kilitler.
    ///
    /// Alien YOK (`alienCount: 0`) ve bu ihmal değil: haritanın ortasında
    /// duran bir Leviathan saldırgan ve düellonun tam ortasına düşüyor.
    /// Ölçtüğümüz şey oyuncunun silahı; üçüncü bir ateş kaynağı, her sayıyı
    /// sessizce kaydırırdı.
    (Zone, ServerShip, ServerShip) duel({
      required double distance,
      bool firing = true,
    }) {
      final zone = Zone(alienCount: 0);
      final shooter = zone.join('A', stats: stats)!;
      final target = zone.join('B', stats: stats)!;
      shooter.state = shooter.state.copyWith(position: world.centre);
      target.state = target.state.copyWith(
        position: world.centre + Vec2(distance, 0),
      );
      // Avcı hedefe DÖNMÜŞ kuruluyor: ateş artık nişan yayına bağlı ve bu
      // testlerin konusu dönüş değil, dönüşün ardından gelen hasar zinciri.
      nisanla(shooter, target.state.position);
      zone.enqueue(
        shooter,
        ShipInput(seq: 1, weaponTarget: target.id, firing: firing),
      );
      return (zone, shooter, target);
    }

    // NOT: inen hasar yaylımın TAMAMI değil, azaltmadan sonrası. Zırh eğrisi
    // alan 04 gelene kadar çözülmemişti ve `totalMitigation` hep sıfır
    // dönüyordu — o yüzden bu testler bir zamanlar ham yaylımı bekliyordu.
    // Sabit sayı yerine formülü yazmak, katman açıldığında sessizce yanlış
    // olmalarını engelliyor.
    // NİŞAN ALMADAN ATEŞ YOK.
    test('ARKASINDAKİ hedefe hemen ateş etmiyor, dönünce ediyor', () {
      // Mobilde otomatik ateşle görülen hata: hedefi seçtiğin an, gemi daha
      // yönünü değiştirmeden mermi çıkıyordu — ve yaratık tek atışta öldüğü
      // için dönüş hiç tamamlanmıyordu. Yani gemi ateş ederken hiçbir zaman
      // hedefe bakmıyordu.
      final zone = Zone(alienCount: 0);
      final shooter = zone.join('A')!;
      final target = zone.join('B')!;
      shooter.state = shooter.state.copyWith(position: world.centre);
      // Hedef TAM ARKADA: dönüş en uzun hâlinde.
      target.state = target.state.copyWith(
        position: world.centre + const Vec2(0, 300),
      );
      zone
        ..enqueue(
          shooter,
          ShipInput(seq: 1, weaponTarget: target.id, firing: true),
        )
        ..step();

      expect(
        zone.shots,
        isEmpty,
        reason: 'gemi dönmeden ateş etti',
      );
      // Kilit ve ateş isteği DURUYOR: oyuncu hâlâ ateş istiyor, yalnız bu
      // tikte namlu hedefe bakmıyor.
      expect(shooter.state.weaponTarget, target.id);
      expect(shooter.state.firing, isTrue);

      // Dönüş tamamlanınca kendiliğinden ateş ediyor — oyuncudan yeni bir
      // girdi gerekmeden.
      var atesEdilenTik = 0;
      for (var i = 1; i <= 30 && zone.shots.isEmpty; i++) {
        zone.step();
        atesEdilenTik = i;
      }
      expect(zone.shots, isNotEmpty, reason: 'dönüş bitti ama ateş gelmedi');
      // 180° dönüş 7 rad/sn'de ~450 ms, yani ~14 tik. Bant drift alarmı:
      // dönüş hızı ya da yay değişirse burası haber verir.
      expect(atesEdilenTik, inInclusiveRange(8, 20), reason: 'dönüş süresi kaydı');
    });

    test('menzildeki hedefe ateş kalkanı düşürür', () {
      final (zone, _, target) = duel(distance: 500);
      zone.step();
      expect(
        target.state.shield,
        stats.maxShield -
            CombatGlossary.volley(stats) * (1 - stats.totalMitigation),
      );
      expect(target.state.hull, stats.maxHull, reason: 'kalkan varken gövde');
    });

    test('atış hızı sunucuda — her tik hasar YOK', () {
      final (zone, shooter, target) = duel(distance: 500);
      // İlk tik ateşler, sonraki tikler bekleme süresine takılır.
      for (var i = 0; i < 5; i++) {
        zone
          ..enqueue(
            shooter,
            ShipInput(seq: i + 2, weaponTarget: target.id, firing: true),
          )
          ..step();
      }
      expect(
        target.state.shield,
        stats.maxShield -
            CombatGlossary.volley(stats) * (1 - stats.totalMitigation),
        reason:
            'bekleme süresi yok sayıldı → düzenlenmiş istemci makineli '
            'tüfek gibi ateş ederdi',
      );
    });

    test('bekleme dolunca ikinci atış gelir', () {
      final (zone, shooter, target) = duel(distance: 500);
      final ticks = (stats.laser.fireInterval * ShipSim.tickRate).ceil() + 2;
      for (var i = 0; i < ticks; i++) {
        zone
          ..enqueue(
            shooter,
            ShipInput(seq: i + 2, weaponTarget: target.id, firing: true),
          )
          ..step();
      }
      expect(
        target.state.shield,
        stats.maxShield -
            CombatGlossary.volley(stats) * (1 - stats.totalMitigation) * 2,
      );
    });

    test('menzil dışına hasar YOK ve ışın kesilir', () {
      final (zone, shooter, target) = duel(distance: stats.laser.range + 200);
      zone.step();
      expect(target.state.shield, stats.maxShield);
      expect(
        shooter.state.firing,
        isFalse,
        reason: 'menzil dışında ışın çizilmemeli',
      );
      expect(
        shooter.state.weaponTarget,
        target.id,
        reason: 'kilit DURMALI — hedef menzile geri girebilir',
      );
    });

    test('kendine ateş edilemez', () {
      final zone = Zone();
      final ship = zone.join('A')!;
      final before = ship.state.shield;
      zone
        ..enqueue(ship, ShipInput(seq: 1, weaponTarget: ship.id, firing: true))
        ..step();
      expect(ship.state.shield, before);
      expect(ship.state.weaponTarget, 0, reason: 'geçersiz kilit düşer');
    });

    test('olmayan kimliğe kilit düşer', () {
      final zone = Zone();
      final ship = zone.join('A')!;
      zone
        ..enqueue(
          ship,
          const ShipInput(seq: 1, weaponTarget: 60000, firing: true),
        )
        ..step();
      expect(ship.state.weaponTarget, 0);
      expect(ship.state.firing, isFalse);
    });

    test('ölü hedefe ateş edilmez, kilit düşer', () {
      final (zone, shooter, target) = duel(distance: 500);
      target.state = ShipSim.applyDamage(target.state, 1e9);
      zone.step();
      expect(target.state.alive, isFalse);
      expect(shooter.state.weaponTarget, 0);
    });

    test('ölü gemi ateş edemez', () {
      final (zone, shooter, target) = duel(distance: 500);
      shooter.state = ShipSim.applyDamage(shooter.state, 1e9);
      zone.step();
      expect(target.state.shield, stats.maxShield);
    });

    test('paket gecikmesinde ateş KESİLMEZ (seviye tetikli korunur)', () {
      final (zone, shooter, target) = duel(distance: 500);
      // Tek girdi çerçevesi, sonra kuyruk boş: sunucu son girdiyi tekrarlar.
      // Bekleme süresi dolana kadar hiç yeni girdi göndermiyoruz.
      final ticks = (stats.laser.fireInterval * ShipSim.tickRate).ceil() + 2;
      for (var i = 0; i < ticks; i++) {
        zone.step();
      }
      expect(
        target.state.shield,
        stats.maxShield -
            CombatGlossary.volley(stats) * (1 - stats.totalMitigation) * 2,
        reason: 'tekrarda kilit/ateş düşerse tek geciken pakette ışın titrer',
      );
    });

    group('nişan yönelimi', () {
      test('kilit varken gemi hedefe DÖNER — ateş etmese bile', () {
        final (zone, shooter, target) = duel(distance: 500, firing: false);
        for (var i = 0; i < 25; i++) {
          zone.step();
        }
        expect(shooter.state.aimPoint, isNotNull);
        expect(
          shooter.state.aimPoint!.x,
          closeTo(target.state.position.x, 1),
          reason: 'nişan noktası hedefi izlemeli',
        );
        // Hedef tam doğuda: 0 = kuzey, +π/2 = doğu.
        expect(shooter.state.angle, closeTo(1.5708, 0.05));
      });

      test('menzil dışındaki hedefe de dönülür', () {
        // Kilit menzil dışında DURUYOR; gemi ona bakmazsa oyuncu hangi yöne
        // uçacağını gövdeden okuyamaz.
        final (zone, shooter, _) = duel(
          distance: ShipStats.bastion.laser.range + 600,
          firing: true,
        );
        for (var i = 0; i < 25; i++) {
          zone.step();
        }
        expect(shooter.state.firing, isFalse, reason: 'menzil dışı');
        expect(shooter.state.angle, closeTo(1.5708, 0.05));
      });

      test('kilit düşünce nişan da düşer', () {
        final (zone, shooter, target) = duel(distance: 500);
        for (var i = 0; i < 10; i++) {
          zone.step();
        }
        expect(shooter.state.aimPoint, isNotNull);

        target.state = ShipSim.applyDamage(target.state, 1e9);
        zone.step();
        expect(shooter.state.weaponTarget, 0);
        expect(
          shooter.state.aimPoint,
          isNull,
          reason: 'gemi ölmüş hedefin boşluğuna bakmaya devam edemez',
        );
      });
    });

    group('atış olayları', () {
      test('vuruş bir olay üretir — hasarı SUNUCU söyler', () {
        final (zone, shooter, target) = duel(distance: 500);
        zone.step();

        expect(zone.shots, hasLength(1));
        final shot = zone.shots.single;
        expect(shot.shooterId, shooter.id);
        expect(shot.targetId, target.id);
        // Olayda giden sayı, AZALTMADAN SONRAKİ hasar: oyuncunun ekranında
        // gördüğü rakam ile canından inen miktar aynı olmak zorunda.
        expect(
          shot.damage,
          (CombatGlossary.volley(stats) * (1 - stats.totalMitigation)).round(),
        );
        expect(shot.shieldHit, isTrue, reason: 'kalkan doluydu');
        expect(shot.killed, isFalse);
      });

      test('olaylar her tikin BAŞINDA temizlenir', () {
        final (zone, _, _) = duel(distance: 500);
        zone.step();
        expect(zone.shots, hasLength(1));
        // Bekleme süresi dolmadığı için bu tikte vuruş yok.
        zone.step();
        expect(
          zone.shots,
          isEmpty,
          reason: 'liste birikirse istemci aynı hasarı iki kez çizer',
        );
      });

      test('menzil dışı atış olay ÜRETMEZ', () {
        final (zone, _, _) = duel(distance: stats.laser.range + 200);
        zone.step();
        expect(zone.shots, isEmpty);
      });

      test('kalkanı bitmiş hedefte shieldHit KAPANIR', () {
        final (zone, _, target) = duel(distance: 500);
        target.state = target.state.copyWith(shield: 0, sinceHit: 0);
        zone.step();
        expect(zone.shots.single.shieldHit, isFalse);
      });

      test('öldüren vuruş killed taşır — ve yalnız o vuruş', () {
        final (zone, shooter, target) = duel(distance: 500);
        target.state = target.state.copyWith(shield: 0, hull: 10, sinceHit: 0);
        zone.step();
        expect(zone.shots.single.killed, isTrue);

        // Ölü hedefe ateş sürmez: bir sonraki tikte kilit düşer ve olay
        // üretilmez — yoksa enkaza vurulan her yaylım hasar sayısı basardı.
        zone.step();
        expect(zone.shots, isEmpty);
        expect(shooter.state.weaponTarget, 0);
      });
    });

    test('kalkanı aşan hasar gövdeye TAŞAR', () {
      final (zone, shooter, target) = duel(distance: 500);
      // `sinceHit: 0` şart: aksi hâlde kalkan bu tikte yenilenir (tik başına
      // 11.3) ve test taşma kuralını değil yenilenmeyi ölçer.
      target.state = target.state.copyWith(shield: 100, sinceHit: 0);
      zone.step();
      expect(target.state.shield, 0);
      final inen = CombatGlossary.volley(stats) * (1 - stats.totalMitigation);
      expect(target.state.hull, closeTo(stats.maxHull - (inen - 100), 1e-6));
    });
  });

  group('alienler', () {
    test('harita kuruluşta DOLU doğar', () {
      final zone = Zone(alienCount: 24);
      expect(zone.aliens, hasLength(24));
      for (final alien in zone.aliens.values) {
        expect(alien.position.x, greaterThan(world.margin));
        expect(alien.position.y, greaterThan(world.margin));
        expect(alien.position.x, lessThan(world.width - world.margin));
        expect(alien.position.y, lessThan(world.height - world.margin));
      }
    });

    test('doğuş SERPİLİR — hepsi bir köşede toplanmaz', () {
      // Saf rastgelelik kümelenir ve haritanın yarısını boş bırakır.
      final zone = Zone(alienCount: 36);
      final xs = zone.aliens.values.map((a) => a.position.x).toList()..sort();
      final ys = zone.aliens.values.map((a) => a.position.y).toList()..sort();
      expect(xs.last - xs.first, greaterThan(world.width * 0.6));
      expect(ys.last - ys.first, greaterThan(world.height * 0.6));
    });

    test('alienler kendi kendilerine HAREKET eder', () {
      final zone = Zone(alienCount: 8);
      final before = {
        for (final e in zone.aliens.entries) e.key: e.value.position,
      };
      for (var i = 0; i < 120; i++) {
        zone.step();
      }
      final moved = zone.aliens.entries
          .where((e) => (e.value.position - before[e.key]!).length > 20)
          .length;
      expect(moved, greaterThan(4), reason: 'sürünün çoğu yerinde saydı');
    });

    test('yalnız YAKINDAKİ alienler snapshot\'a girer', () {
      // Bant genişliği ikincil sebep; asıl sebep gemilerdekiyle aynı:
      // görmediğin şey sızdırılamaz.
      final zone = Zone(alienCount: 36);
      final ship = zone.join('A')!;
      ship.state = ship.state.copyWith(position: const Vec2(600, 600));
      zone.step();

      final visible = zone.collectVisibleAliens(ship);
      expect(visible.length, lessThan(zone.aliens.length));
      for (final id in visible) {
        expect(
          zone.aliens[id]!.position.distanceTo(ship.state.position),
          lessThanOrEqualTo(Protocol.interestExitRadius),
        );
      }
    });

    test('alien HEDEFLENİR ve hasar alır', () {
      // Tab'ın alienleri de gezebilmesinin sunucu tarafı: kimlik aralığı
      // hangi haritada aranacağını söylüyor.
      final zone = Zone(alienCount: 0);
      // Kritiksiz referans: ölçülen şey hedeflemenin çalışması, zarın sonucu
      // değil.
      final shooter = zone.join(
        'A',
        stats: ShipStats.bastion.copyWith(critChance: 0),
      )!;
      shooter.state = shooter.state.copyWith(position: world.centre);
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.spore,
        world.centre + const Vec2(500, 0),
        1,
      );
      nisanla(shooter, world.centre + const Vec2(500, 0));

      zone
        ..enqueue(
          shooter,
          const ShipInput(seq: 1, weaponTarget: alienId, firing: true),
        )
        ..step();

      expect(
        zone.aliens[alienId]!.hull,
        AlienStats.spore.maxHull -
            CombatGlossary.volley(ShipStats.bastion.copyWith(critChance: 0)),
      );
      // `single` DEĞİL: Void Spore artık karşılık veriyor ve aynı tikte ikinci
      // bir atış olayı doğuyor. Aranan, oyuncunun atışı.
      final shot = zone.shots.firstWhere((s) => s.shooterId == shooter.id);
      expect(shot.targetId, alienId);
      expect(shot.shieldHit, isFalse, reason: 'alienin kalkanı yok');
    });

    test('vurulan Void Spore KARŞILIK verir ve peşe düşer', () {
      // Oyuncunun döngüsünü kuran şey risk: ödül veren hedef, karşılık
      // vermeyen bir hedef olamaz. Void Spore kendiliğinden saldırmıyor
      // (`aggroRange` sıfır) — kavgayı oyuncu başlatıyor.
      final zone = Zone(alienCount: 0);
      final ship = zone.join('A')!;
      ship.state = ship.state.copyWith(position: world.centre);
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.spore,
        world.centre + const Vec2(400, 0),
        1,
      );
      nisanla(ship, world.centre + const Vec2(400, 0));

      // Kışkırtılmadan önce: hedefi yok, ateşi yok.
      zone.step();
      expect(zone.aliens[alienId]!.targetId, 0, reason: 'kendiliğinden uyandı');
      expect(zone.shots, isEmpty);

      zone
        ..enqueue(
          ship,
          const ShipInput(seq: 1, weaponTarget: alienId, firing: true),
        )
        ..step();

      expect(
        zone.aliens[alienId]!.targetId,
        ship.id,
        reason: 'vurulan alien saldıranı hedeflemedi',
      );
      expect(
        zone.shots.where((s) => s.shooterId == alienId),
        hasLength(1),
        reason: 'alien karşılık vermedi',
      );
      // Alien hasarı da oyuncunun AZALTMASINDAN geçiyor — ayrı bir yol
      // olsaydı savunma statları PvE'de ölü stata dönerdi.
      expect(
        ship.state.shield,
        closeTo(
          ShipStats.bastion.maxShield -
              AlienStats.spore.damage * (1 - ShipStats.bastion.totalMitigation),
          1e-6,
        ),
      );
    });

    test('alienlerin ateşi TOPAKLANMAZ — namlu sayaçları kaydırılmış', () {
      // Ölçüldü: hepsi sıfır sayaçla doğduğunda aynı tikte ateş ediyorlar ve
      // aralıkları eşit olduğu için sonsuza kadar kilitli adımda kalıyorlar.
      // 120 oyuncuda tik p95'i 10.6 → 14.1 ms çıkmıştı; iş artmamış,
      // topaklanmıştı. Oyuncu tarafında da aynı: altı yaylım tek karede.
      final offsets = {
        for (var i = 0; i < 12; i++)
          AlienSimState.spawn(AlienStats.spore, world.centre, i).fireCooldown,
      };
      expect(
        offsets.length,
        greaterThan(8),
        reason: 'namlu sayaçları aynı — ateş kilitli adımda',
      );
      for (final offset in offsets) {
        expect(offset, inInclusiveRange(0, AlienStats.spore.fireInterval));
      }
    });

    test('kaydırma DETERMİNİSTİK — aynı tohum aynı sayaç', () {
      // Simülasyonun tekrarlanabilirliği bu paketin kuralı: rastgelelik
      // tohumdan türüyor, `Random`'dan değil.
      expect(
        AlienSimState.spawn(AlienStats.spore, world.centre, 7).fireCooldown,
        AlienSimState.spawn(AlienStats.spore, world.centre, 7).fireCooldown,
      );
    });

    test('kin SÜRELİ — kaçan oyuncunun peşi bırakılır', () {
      // Sonsuz kin, vur-kaç yapan oyuncunun peşine haritanın öbür ucuna kadar
      // düşen bir alien demek. Süreli olması "kaçmak işe yarar" kuralını
      // kuruyor.
      final zone = Zone(alienCount: 0);
      final ship = zone.join('A')!;
      ship.state = ship.state.copyWith(position: world.centre);
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.spore,
        world.centre + const Vec2(400, 0),
        1,
      );
      nisanla(ship, world.centre + const Vec2(400, 0));
      zone
        ..enqueue(
          ship,
          const ShipInput(seq: 1, weaponTarget: alienId, firing: true),
        )
        ..step();
      expect(zone.aliens[alienId]!.hunting, isTrue);

      // Oyuncu menzilin dışına kaçıyor ve ateşi kesiyor.
      ship.state = ship.state.copyWith(
        position: world.centre + const Vec2(6000, 0),
      );
      zone.enqueue(ship, const ShipInput(seq: 2, firing: false));
      final ticks = (AlienSim.aggroDuration / ShipSim.fixedDt).ceil() + 2;
      for (var i = 0; i < ticks; i++) {
        zone.step();
      }

      expect(zone.aliens[alienId]!.hunting, isFalse, reason: 'kin sönmedi');
      expect(zone.aliens[alienId]!.targetId, 0);
    });

    test('alien ölünce kilit DÜŞER ve snapshottan çıkar', () {
      final zone = Zone(alienCount: 0);
      // Kritiksiz referans: ölçülen şey hedeflemenin çalışması, zarın sonucu
      // değil.
      final shooter = zone.join(
        'A',
        stats: ShipStats.bastion.copyWith(critChance: 0),
      )!;
      shooter.state = shooter.state.copyWith(position: world.centre);
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSimState.spawn(
        AlienStats.spore,
        world.centre + const Vec2(500, 0),
        1,
      ).copyWith(hull: 10);
      nisanla(shooter, world.centre + const Vec2(500, 0));

      zone
        ..enqueue(
          shooter,
          const ShipInput(seq: 1, weaponTarget: alienId, firing: true),
        )
        ..step();

      expect(zone.shots.single.killed, isTrue);
      expect(zone.aliens[alienId]!.alive, isFalse);
      expect(
        zone.collectVisibleAliens(shooter),
        isEmpty,
        reason: 'enkaz diye bir şey yok; ölü alien gönderilmemeli',
      );

      zone.step();
      expect(shooter.state.weaponTarget, 0, reason: 'ölü hedefe kilit kalmaz');
    });

    test('alien yeniden doğunca tekrar görünür', () {
      final zone = Zone(alienCount: 0);
      final ship = zone.join('A')!;
      ship.state = ship.state.copyWith(position: world.centre);
      const alienId = Protocol.alienIdBase + 1;
      zone.aliens[alienId] = AlienSim.applyDamage(
        AlienSimState.spawn(
          AlienStats.spore,
          world.centre + const Vec2(400, 0),
          1,
        ),
        1e9,
      );

      final ticks =
          (AlienStats.spore.respawnDelay * ShipSim.tickRate).ceil() + 2;
      for (var i = 0; i < ticks; i++) {
        zone.step();
      }
      expect(zone.aliens[alienId]!.alive, isTrue);
      expect(zone.collectVisibleAliens(ship), contains(alienId));
    });

    test('histerezis: sınırda gidip gelme YOK', () {
      // Tek eşikte sınırda duran bir alien saniyede onlarca kez görünüp
      // kayboluyor ve istemcinin ara değer tamponu her seferinde sıfırlanıyor.
      final zone = Zone(alienCount: 0);
      final ship = zone.join('A')!;
      ship.state = ship.state.copyWith(position: Vec2.zero);
      zone.aliens[1] = AlienSimState.spawn(
        AlienStats.spore,
        Vec2(Protocol.interestRadius - 10, 0),
        1,
      );
      nisanla(ship, Vec2(Protocol.interestRadius - 10, 0));

      expect(zone.collectVisibleAliens(ship), contains(1));
      // Giriş eşiğinin ÖTESİNE ama çıkış eşiğinin içine kaydır.
      zone.aliens[1] = zone.aliens[1]!.copyWith(
        position: Vec2(Protocol.interestRadius + 40, 0),
      );
      expect(
        zone.collectVisibleAliens(ship),
        contains(1),
        reason: 'çıkış eşiği girişten büyük olmalı',
      );
      zone.aliens[1] = zone.aliens[1]!.copyWith(
        position: Vec2(Protocol.interestExitRadius + 40, 0),
      );
      expect(zone.collectVisibleAliens(ship), isEmpty);
    });
  });

  _lifecycleTests();
}

void _lifecycleTests() {
  group('yeniden doğuş', () {
    test('ölen gemi süre dolunca doğuş noktasında geri gelir', () {
      final zone = Zone();
      final ship = zone.join('Ada')!;
      final spawn = ship.state.position;

      ship.state = ShipSim.applyDamage(ship.state, 1e9);
      expect(ship.state.alive, isFalse);

      // Süre dolmadan DİRİLMEZ: ölümün bedeli olmalı.
      for (var i = 0; i < Zone.respawnDelayTicks - 2; i++) {
        zone.step();
      }
      expect(ship.state.alive, isFalse);

      for (var i = 0; i < 4; i++) {
        zone.step();
      }
      expect(ship.state.alive, isTrue);
      expect(ship.state.hull, ShipStats.bastion.maxHull);
      // Öldüğü yerde değil DOĞUŞ noktasında: yoksa onu öldüren hâlâ orada.
      expect(ship.state.position, spawn);
    });

    test('yeniden doğan gemi eski girdileriyle sürüklenmez', () {
      final zone = Zone();
      final ship = zone.join('Ada')!;
      zone.enqueue(ship, const ShipInput(seq: 1, axis: Vec2(1, 0)));
      ship.state = ShipSim.applyDamage(ship.state, 1e9);

      for (var i = 0; i <= Zone.respawnDelayTicks + 1; i++) {
        zone.step();
      }
      expect(ship.pending, isEmpty);
      expect(ship.lastApplied.axis.isZero, isTrue);
    });
  });

  group('kopmuş oturum', () {
    test('gemi HEMEN silinmez, sahipsiz bekler', () {
      final zone = Zone();
      final ship = zone.join('Ada', accountId: 'hesap-1')!;
      zone.orphan(ship);

      expect(zone.ships.containsKey(ship.id), isTrue);
      expect(ship.isOrphan, isTrue);
      expect(zone.expiredOrphans(), isEmpty);
    });

    test('aynı hesap geri gelince AYNI gemiye döner', () {
      final zone = Zone();
      final ship = zone.join('Ada', accountId: 'hesap-1')!;
      ship.state = ship.state.copyWith(position: const Vec2(1234, 5678));
      zone.orphan(ship);

      final back = zone.reclaim('hesap-1');
      expect(back, same(ship));
      expect(back!.isOrphan, isFalse);
      // Konum KORUNUR: kopan oyuncu savaşın ortasına geri döner.
      expect(back.state.position, const Vec2(1234, 5678));
    });

    test('başka hesap o gemiyi alamaz', () {
      final zone = Zone();
      final ship = zone.join('Ada', accountId: 'hesap-1')!;
      zone.orphan(ship);
      expect(zone.reclaim('hesap-2'), isNull);
    });

    test('bekleme süresi dolunca gemi gerçekten gider', () {
      final zone = Zone();
      final ship = zone.join('Ada', accountId: 'hesap-1')!;
      zone.orphan(ship);

      for (var i = 0; i <= Zone.orphanGraceTicks; i++) {
        zone.step();
      }
      expect(zone.expiredOrphans(), contains(ship));
    });

    test('sahipsiz gemi zaman aşımı listesine GİRMEZ', () {
      // İki mekanizma aynı gemiyi silmeye çalışsaydı, biri diğerinin bekleme
      // süresini anlamsız kılardı.
      final zone = Zone();
      final ship = zone.join('Ada', accountId: 'hesap-1')!;
      zone.orphan(ship);
      for (
        var i = 0;
        i < Protocol.sessionTimeout * Protocol.tickRate + 5;
        i++
      ) {
        zone.step();
      }
      expect(zone.timedOut(), isNot(contains(ship)));
    });

    test('sahipsiz gemi ATEŞ ETMEYİ bırakır', () {
      // Gerçekten kırıktı ve ölçüldü: seviye tetikli `firing` kopmadan sonra
      // da korunduğu için, bağlantısı giden bir oyuncunun gemisi hedefini
      // dövmeye devam ediyordu (kalkan 60 tikte 7000 → 6000). Yani fişi çekmek
      // bedava bir taretti.
      final zone = Zone(alienCount: 0);
      final a = zone.join('Ada', accountId: 'a')!;
      final b = zone.join('Bora', accountId: 'b')!;
      b.state = b.state.copyWith(
        position: a.state.position + const Vec2(200, 0),
      );
      nisanla(a, b.state.position);
      zone.enqueue(a, ShipInput(seq: 1, weaponTarget: b.id, firing: true));
      for (var i = 0; i < 5; i++) {
        zone.step();
      }
      final whileConnected = b.state.shield;
      expect(
        whileConnected,
        lessThan(ShipStats.bastion.maxShield),
        reason: 'kurulum başarısız — bağlıyken de ateş etmiyor',
      );

      zone.orphan(a);
      for (var i = 0; i < 60; i++) {
        zone.step();
      }
      expect(
        b.state.shield,
        whileConnected,
        reason: 'kopmuş oyuncunun gemisi ateş etmeye devam etti',
      );
    });

    test('sahipsiz gemi UÇMAYI bırakır — bıraktığı yerde kalır', () {
      // Son eksen komutunu tekrarlamak, oyuncunun gemisini haritanın öbür
      // ucunda bulmasına yol açıyordu. Klavyeyi bırakmış bir oyuncuyla ağı
      // kopmuş bir oyuncu aynı şey değil: birincinin niyeti "devam", ikincinin
      // niyeti BİLİNMİYOR.
      final zone = Zone(alienCount: 0);
      final ship = zone.join('Ada', accountId: 'a')!;
      zone.enqueue(ship, ShipInput(seq: 1, axis: const Vec2(1, 0)));
      for (var i = 0; i < 5; i++) {
        zone.step();
      }
      zone.orphan(ship);
      final whereItStopped = ship.state.position;
      for (var i = 0; i < 60; i++) {
        zone.step();
      }
      expect(ship.state.position, whereItStopped);
    });

    test('zaman aşımı gemiyi SİLMEZ, sahipsiz bırakır', () {
      // Kopmanın sebebi soket hatası değil SESSİZLİK olduğunda da oyuncuya
      // aynı süre verilmeli. Eskiden burada gemi doğrudan siliniyordu: tünele
      // giren oyuncu on saniye sonra gemisini kaybediyordu.
      final zone = Zone(alienCount: 0);
      final ship = zone.join('Ada', accountId: 'a')!;
      for (
        var i = 0;
        i < Protocol.sessionTimeout * Protocol.tickRate + 5;
        i++
      ) {
        zone.step();
      }
      expect(zone.timedOut(), contains(ship));
      zone.orphan(ship);
      expect(zone.ships.containsKey(ship.id), isTrue, reason: 'gemi silindi');
      expect(ship.isOrphan, isTrue);
    });

    test('DOLU zone yeni oyuncu için sahipsiz gemiyi tahliye eder', () {
      // Bekleme süresini bir dakikaya çıkarmanın bedelini ödeyen mekanizma.
      // Oynayan hiç kimseyi etkilemiyor — yalnız kopmuş olanları sıraya sokuyor.
      final zone = Zone(capacity: 2, alienCount: 0);
      final first = zone.join('Ada', accountId: 'a')!;
      zone.join('Bora', accountId: 'b');
      expect(zone.isFull, isTrue);
      expect(zone.join('Cem', accountId: 'c'), isNull, reason: 'dolu olmalı');

      zone.orphan(first);
      final late = zone.join('Cem', accountId: 'c');
      expect(late, isNotNull, reason: 'sahipsiz gemi tahliye edilmedi');
      expect(zone.ships.containsKey(first.id), isFalse);
    });

    test('tahliye EN ESKİ sahipsizi seçer', () {
      final zone = Zone(capacity: 3, alienCount: 0);
      final a = zone.join('Ada', accountId: 'a')!;
      final b = zone.join('Bora', accountId: 'b')!;
      zone.join('Cem', accountId: 'c');

      zone.orphan(a); // önce a koptu
      zone.step();
      zone.orphan(b); // sonra b

      expect(zone.join('Deniz', accountId: 'd'), isNotNull);
      expect(zone.ships.containsKey(a.id), isFalse, reason: 'en eski gitmeli');
      expect(zone.ships.containsKey(b.id), isTrue, reason: 'yenisi kalmalı');
    });

    test('OYNAYAN oyuncu asla tahliye edilmez', () {
      // Tahliye yalnız sahipsizleri hedefler. Oynayan birini düşürmek,
      // kapasite sorununu çözerken çok daha kötü bir sorun yaratırdı.
      final zone = Zone(capacity: 2, alienCount: 0);
      zone.join('Ada', accountId: 'a');
      zone.join('Bora', accountId: 'b');
      expect(zone.join('Cem', accountId: 'c'), isNull);
      expect(zone.ships, hasLength(2), reason: 'oynayan biri düşürüldü');
    });

    test('sahipsiz gemi VURULABİLİR kalır', () {
      // Kopmak kalkan olsaydı, kaybedilen her düelloda fişi çekmek bir taktik
      // olurdu. Gemi dünyada ve hedeflenebilir kalmalı.
      final zone = Zone(alienCount: 0);
      final victim = zone.join('Ada', accountId: 'a')!;
      final shooter = zone.join('Bora', accountId: 'b')!;
      shooter.state = shooter.state.copyWith(
        position: victim.state.position + const Vec2(200, 0),
      );
      nisanla(shooter, victim.state.position);
      zone.orphan(victim);
      zone.enqueue(
        shooter,
        ShipInput(seq: 1, weaponTarget: victim.id, firing: true),
      );
      for (var i = 0; i < 5; i++) {
        zone.step();
      }
      expect(victim.state.shield, lessThan(ShipStats.bastion.maxShield));
    });
  });

  group('hız hilesi', () {
    test('EKSEN büyüklüğü hızı artıramaz', () {
      // Tel biçimi ekseni i8/127 ile taşıyor, yani bugün 1'i biraz aşabiliyor
      // (±1.008). Yarın biçim f32'ye dönerse istemci `axis: (1000, 0)`
      // yollayabilir. `ShipSim` ekseni NORMALLEŞTİRDİĞİ için büyüklük
      // önemsiz — ve bu testin işi o normalleştirmeyi sökülemez kılmak.
      final honest = Zone(alienCount: 0);
      final cheat = Zone(alienCount: 0);
      final a = honest.join('Ada', accountId: 'a')!;
      final b = cheat.join('Ada', accountId: 'a')!;
      final start = a.state.position;
      expect(b.state.position, start, reason: 'aynı kimlik aynı noktada doğar');

      for (var seq = 1; seq <= 30; seq++) {
        honest.enqueue(a, ShipInput(seq: seq, axis: const Vec2(1, 0)));
        cheat.enqueue(b, ShipInput(seq: seq, axis: const Vec2(1000, 0)));
        honest.step();
        cheat.step();
      }
      expect(
        b.state.position.distanceTo(start),
        closeTo(a.state.position.distanceTo(start), 0.001),
        reason: 'büyük eksen daha çok yol aldırdı — hız hilesi açık',
      );
    });

    test('sıfıra çok yakın eksen ışınlamaz', () {
      // `normalized()` sıfıra bölmemeli: minicik bir eksen tam hız vermeli,
      // sonsuz değil.
      final zone = Zone(alienCount: 0);
      final ship = zone.join('Ada', accountId: 'a')!;
      final start = ship.state.position;
      zone.enqueue(ship, ShipInput(seq: 1, axis: const Vec2(1 / 127, 0)));
      zone.step();
      final moved = ship.state.position.distanceTo(start);
      expect(moved, lessThan(ShipStats.bastion.speed * ShipSim.fixedDt + 1));
      expect(moved.isFinite, isTrue);
    });
  });

  group('kimlik tahsisi', () {
    test('gemi kimliği ALIEN uzayına taşmıyor', () {
      // Tahsis tavanı `u16`'nın 65535'iydi, oysa alien uzayı 32768'de
      // başlıyor. Taşan bir kimlik istemcide gemiyle alien'i karıştırır:
      // gemi yanlış konuma çizilir, kimse onu hedefleyemez, ödül alamaz.
      final zone = Zone(capacity: 8);
      final gorulen = <int>{};
      for (var i = 0; i < 40000; i++) {
        final ship = zone.join('O$i');
        expect(ship, isNotNull, reason: '$i. katılım reddedildi');
        gorulen.add(ship!.id);
        zone.leave(ship.id);
      }
      for (final id in gorulen) {
        expect(
          Protocol.isAlienId(id),
          isFalse,
          reason: 'kimlik $id alien uzayında',
        );
        expect(id, isNot(0), reason: '0 ayrılmış: "hedef yok"');
      }
    });

    test('kapasite kimlik uzayını AŞAMAZ', () {
      // Kapasite ortam değişkeninden geliyor (CAPACITY). Uzayı aşan bir değer,
      // gemilere sessizce alien kimliği dağıtmanın tek gerçek yolu.
      expect(
        () => Zone(capacity: Protocol.maxShipId + 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('boşalan kimlik HEMEN geri dönmüyor', () {
      // Uçuştaki referanslar: bir oyuncu ayrıldığı anda ona ait bir
      // `weaponTarget` ya da `ShotEvent` hâlâ yolda olabilir. Kimlik bir
      // sonraki katılımda geri verilirse o referans YENİ gemiyi gösterir.
      //
      // Sayacın ileri yürümesi bu pencereyi kapatıyor — kuşak sayacı (ve
      // onun gerektirdiği protokol kırılması) olmadan.
      final zone = Zone(capacity: 8);
      final a = zone.join('A')!;
      zone.leave(a.id);
      final b = zone.join('B')!;
      expect(b.id, isNot(a.id), reason: 'kimlik anında geri kullanıldı');
    });

    test('ayrılan gemi izleyicilerin defterlerinden düşüyor', () {
      // İleri yürüyen sayacın bedeli: kimlikler seyrekleşiyor, yani
      // kimlik-anahtarlı her defter temizlenmezse oturum boyunca büyür.
      final zone = Zone(capacity: 8);
      final izleyici = zone.join('Izleyici')!;
      final giden = zone.join('Giden')!;
      izleyici.lastSentTick[giden.id] = 5;
      izleyici.staleBaseline.add(giden.id);
      izleyici.visible.add(giden.id);

      zone.leave(giden.id);

      expect(izleyici.lastSentTick.containsKey(giden.id), isFalse);
      expect(izleyici.staleBaseline.contains(giden.id), isFalse);
      expect(izleyici.visible.contains(giden.id), isFalse);
    });
  });
}
