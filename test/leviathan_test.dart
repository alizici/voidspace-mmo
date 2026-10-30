@Tags(['disi'])
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/alien_entities.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/zone.dart';

/// GÜÇLÜ YARATIK — sürünün seyrek, sert, iri üyesi.
///
/// Dosya adı `leviathan` ve tarihsel: sunucu bir zamanlar iki sabit tür
/// (`Void Spore` + `Void Leviathan`) serpiyordu. Bugün her bölgenin kendi
/// kadrosu var ve bu testler tek bir yaratığa değil SINIFA bakıyor —
/// koruduğu değişmezler tür değişince kaybolmamalı.
void main() {
  /// Bir bölgenin güçlü üyesi — kadrodan, adla değil SINIFLA bulunuyor.
  YaratikKimligi gucluOf(Bolge bolge) => YaratikKadrosu.bolgenin(
    bolge.kademe,
  ).firstWhere((y) => y.sinif == DusmanSinifi.guclu);

  final ilk = Bolge.ilk;
  final gucluAd = gucluOf(ilk).ad;

  group('sürü', () {
    test('haritada BİRDEN FAZLA tür var', () {
      final zone = Zone(alienCount: 36);
      final kinds = zone.aliens.values.map((a) => a.stats.kind).toSet();
      expect(kinds.length, greaterThan(1), reason: 'tek tür doğdu');
    });

    test('güçlü SEYREK — sürünün yaklaşık altıda biri', () {
      // Seyreklik bir denge kararı: dokuz yaylım süren bir hedefin haritanın
      // yarısını kaplaması, avlanmayı bir işe çevirirdi.
      final zone = Zone(alienCount: 36);
      final gucluler = zone.aliens.values
          .where((a) => a.stats.name == gucluAd)
          .length;
      expect(gucluler, inInclusiveRange(4, 8));
      expect(zone.aliens, hasLength(36));
    });

    test('güçlüler haritaya YAYILMIŞ — tek sütuna dizilmiyor', () {
      // Bu testin var olma sebebi gerçek bir hata: tür seçimi `index % 6 == 5`
      // idi ve ızgara da `ceil(√36) = 6` sütunluydu. İki bağımsız görünen
      // modulo aynı periyodu paylaşınca dağılım sessizce ÇİZGİYE döndü —
      // altı Leviathan da haritanın sağ kenarında, doğuş noktasından 4900
      // birim uzakta. İlgi yarıçapı 2600; oyuncu hiçbirini göremiyordu.
      //
      // "Sayısı doğru" testi bunu kaçırdı çünkü sayı gerçekten doğruydu.
      // Yakalayan tek şey KONUM dağılımı.
      final zone = Zone(alienCount: 36);
      final spots = [
        for (final a in zone.aliens.values)
          if (a.stats.name == gucluAd) a.position,
      ];
      expect(spots.length, greaterThan(2));

      double spread(Iterable<double> v) =>
          v.reduce(math.max) - v.reduce(math.min);

      final w = zone.world.width;
      final h = zone.world.height;
      expect(
        spread(spots.map((p) => p.x)),
        greaterThan(w * 0.5),
        reason: 'Leviathanlar yatayda tek bir şeride sıkışmış',
      );
      expect(
        spread(spots.map((p) => p.y)),
        greaterThan(h * 0.5),
        reason: 'Leviathanlar dikeyde tek bir şeride sıkışmış',
      );
    });

    test('doğan oyuncu YAKININDA güçlü görebilir', () {
      // Asıl kullanıcı şikâyetinin testi: "mob haritada görünmüyor".
      // Sayısı, statları ve çizimi doğru olsa bile ilgi alanının DIŞINDA
      // duran bir yaratık, oyuncu için yok demektir.
      final zone = Zone(alienCount: 36);
      final ship = zone.join('Ada', accountId: 'a')!;
      final seen = zone.collectVisibleAliens(ship);
      final gucluler = seen
          .where((id) => zone.aliens[id]!.stats.name == gucluAd)
          .length;
      expect(
        gucluler,
        greaterThan(0),
        reason: 'doğuş noktasından hiç güçlü yaratık görünmüyor',
      );
    });

    test('tür dağılımı DETERMİNİSTİK — sunucu aynı haritayı kurar', () {
      // `Random` kullansaydım bir hatayı iki kez görmek imkânsızlaşırdı.
      List<int> kindsOf(Zone z) => [
        for (final id in z.aliens.keys.toList()..sort())
          z.aliens[id]!.stats.kind,
      ];
      expect(kindsOf(Zone(alienCount: 36)), kindsOf(Zone(alienCount: 36)));
    });
  });

  group('istatistikler', () {
    test('Leviathan Void Spore\'den DAYANIKLI, İRİ ve YAVAŞ', () {
      // Aynı hızda ve canda ikinci bir tür, çeşitlilik değil yalnız kalabalık
      // katardı — oyuncunun ayırt edemediği iki hedef.
      final l = AlienStats.leviathan;
      final k = AlienStats.spore;
      expect(l.maxHull, greaterThan(k.maxHull * 4));
      expect(l.radius, greaterThan(k.radius));
      expect(l.speed, lessThan(k.speed));
    });

    test('kimlikten türe ulaşılır — tel u8 taşıyor', () {
      expect(AlienStats.byKind(1).name, AlienStats.leviathan.name);
      expect(AlienStats.byKind(0).name, AlienStats.spore.name);
    });
  });

  group('dövüş', () {
    test('Leviathan Void Spore\'den ÇOK DAHA FAZLA yaylım sürer', () {
      int volleysToKill(AlienStats stats) {
        var state = AlienSimState.spawn(stats, const Vec2(1000, 1000), 1);
        var shots = 0;
        while (state.alive && shots < 100) {
          state = AlienSim.applyDamage(
            state,
            // Kritiksiz yaylım: ölçülen şey iki türün can farkı, zar değil.
            // Yaratık dolu referansa ölçekli (04.5 s2); yaylım da onun.
            CombatGlossary.volley(ReferansCozumu.stats.copyWith(critChance: 0)),
          );
          shots++;
        }
        return shots;
      }

      final easy = volleysToKill(AlienStats.spore);
      final hard = volleysToKill(AlienStats.leviathan);
      expect(easy, 2);
      // Can oranı SINIF oranı: güçlü yaratık sıradanın beş katı sürüyor.
      // Yaylım sayısı yukarı yuvarlandığı için oran birebir çıkmıyor —
      // ölçülebilir olan, üç katın altına düşemeyeceği.
      expect(hard, greaterThanOrEqualTo(easy * 3));
      expect(
        AlienStats.leviathan.maxHull / AlienStats.spore.maxHull,
        closeTo(
          TasarimGirdileri.gucluOldurmeSuresi /
              TasarimGirdileri.siradanOldurmeSuresi,
          1e-9,
        ),
      );
    });

    test('güçlü hedeflenip ÖLDÜRÜLEBİLİR', () {
      final zone = Zone(alienCount: 36);
      final entry = zone.aliens.entries.firstWhere(
        (e) => e.value.stats.name == gucluAd,
      );
      // Referans gemi: güçlü yaratık dolu referansa göre beş saniye (12);
      // çıplak gövde on beş saniyeyi aşar ve döngü ona yetmez.
      final ship = zone.join(
        'Ada',
        accountId: 'a',
        stats: ReferansCozumu.stats,
      )!;
      ship.state = ship.state.copyWith(
        position: entry.value.position + const Vec2(200, 0),
      );
      zone.enqueue(
        ship,
        ShipInput(seq: 1, weaponTarget: entry.key, firing: true),
      );
      for (var i = 0; i < 30 * 15; i++) {
        zone.step();
        if (!zone.aliens[entry.key]!.alive) break;
      }
      expect(zone.aliens[entry.key]!.alive, isFalse, reason: 'ölmedi');
    });
  });

  group('bakış yönü', () {
    /// [dx],[dy] yönünde hareket eden bir alien'in çizilen açısı.
    ///
    /// Gerçek döngüyü taklit ediyor: her tik bir örnek gelir ve ARADA kareler
    /// çizilir. Tek bir `poseOf` çağrısı, yumuşatmanın hiç ilerlemediği bir an
    /// ölçerdi.
    double headingAfter(double dx, double dy, {int steps = 60}) {
      final aliens = AlienEntities();
      var x = 3000.0;
      var y = 3000.0;
      var heading = 0.0;
      for (var tick = 0; tick < steps; tick++) {
        aliens.ingest(tick, [
          AlienSnapshot(
            id: Protocol.alienIdBase,
            kind: AlienStats.leviathan.kind,
            position: Vec2(x, y),
            hullFraction: 1,
          ),
        ]);
        x += dx;
        y += dy;
        if (tick >= 2) {
          // Tik başına dört kare — 120 Hz çizim, 30 Hz snapshot.
          for (var f = 1; f <= 4; f++) {
            final pose = aliens.poseOf(
              Protocol.alienIdBase,
              tick - 1 + f * 0.25,
            );
            if (pose != null) heading = pose.heading;
          }
        }
      }
      return heading;
    }

    test('hareket yönüne DÖNER — telde açı taşınmadan', () {
      // Görsel bir özelliği tele koymak, hiç ödenmesi gerekmeyen bir bant
      // genişliği: istemcinin elinde zaten ardışık iki konum var.
      expect(headingAfter(0, -8), closeTo(0, 0.25), reason: 'yukarı');
      expect(headingAfter(8, 0), closeTo(math.pi / 2, 0.25), reason: 'sağa');
      expect(headingAfter(0, 8), closeTo(math.pi, 0.3), reason: 'aşağı');
    });

    test('DURAN alien fırıl fırıl DÖNMEZ', () {
      // Ölü bölge olmadan, gezinme hedefine varıp duran bir alien'in yön
      // farkı sıfıra iniyor ve açı gürültüye dönüyor.
      final aliens = AlienEntities();
      for (var tick = 0; tick < 40; tick++) {
        aliens.ingest(tick, [
          const AlienSnapshot(
            id: Protocol.alienIdBase,
            kind: 1,
            position: Vec2(3000, 3000),
            hullFraction: 1,
          ),
        ]);
      }
      final a = aliens.poseOf(Protocol.alienIdBase, 20)!.heading;
      final b = aliens.poseOf(Protocol.alienIdBase, 30)!.heading;
      expect(a, b, reason: 'duran alien kendi etrafında dönüyor');
    });

    test('yön DÖNÜŞÜ kare hızından bağımsız', () {
      // İlk uygulama kare başına sabit oranla yumuşatıyordu: 120 fps'lik bir
      // cihaz, 12 fps'likten on kat hızlı dönüyordu. Aynı oyun, cihaza göre
      // farklı davranan bir animasyon.
      double turnAt(int framesPerTick) {
        final aliens = AlienEntities();
        var heading = 0.0;
        for (var tick = 0; tick < 12; tick++) {
          aliens.ingest(tick, [
            AlienSnapshot(
              id: Protocol.alienIdBase,
              kind: 1,
              // Sabit hızla SAĞA: hedef açı π/2.
              position: Vec2(3000 + tick * 8.0, 3000),
              hullFraction: 1,
            ),
          ]);
          if (tick < 2) continue;
          for (var f = 1; f <= framesPerTick; f++) {
            final pose = aliens.poseOf(
              Protocol.alienIdBase,
              tick - 1 + f / framesPerTick,
            );
            if (pose != null) heading = pose.heading;
          }
        }
        return heading;
      }

      expect(turnAt(1), closeTo(turnAt(8), 0.02));
    });
  });
}
