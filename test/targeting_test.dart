@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/targeting.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Hedef kilidinin kuralları.
///
/// Saf mantık olduğu için oyun döngüsü, ağ ya da Flame olmadan sınanıyor —
/// ve sınanması gereken şey tam olarak burada: Tab'ın hangi sırayla gezdiği
/// ve kaybolan hedefin ne olduğu.
void main() {
  const me = Vec2(0, 0);

  Vec2? Function(int) from(Map<int, Vec2> positions) =>
      (id) => positions[id];

  test('kilit yokken EN YAKINDAN başlar', () {
    final positions = {7: const Vec2(500, 0), 3: const Vec2(120, 0)};
    final t = Targeting()..cycle(positions.keys, me, from(positions));
    expect(t.selected, 3);
  });

  test('Tab yakınlık sırasıyla ilerler', () {
    final positions = {
      1: const Vec2(300, 0),
      2: const Vec2(100, 0),
      3: const Vec2(200, 0),
    };
    final t = Targeting()..cycle(positions.keys, me, from(positions));
    expect(t.selected, 2, reason: 'en yakın');
    t.cycle(positions.keys, me, from(positions));
    expect(t.selected, 3);
    t.cycle(positions.keys, me, from(positions));
    expect(t.selected, 1, reason: 'en uzak');
  });

  test('son hedeften sonra BAŞA döner', () {
    final positions = {1: const Vec2(100, 0), 2: const Vec2(200, 0)};
    final t = Targeting()
      ..cycle(positions.keys, me, from(positions))
      ..cycle(positions.keys, me, from(positions))
      ..cycle(positions.keys, me, from(positions));
    expect(
      t.selected,
      1,
      reason: 'döngü kapanmazsa kalabalıkta sürekli baştan başlanırdı',
    );
  });

  test('SIRA basışlar arasında kaymıyor: üç basış üç ayrı hedef', () {
    // Kırılırsa: düğmeye basan oyuncu aynı iki hedef arasında gidip gelir.
    // Sıra mesafeye göre kuruluyor ve uçarken mesafeler kare kare değişiyor;
    // sıra her basışta yeniden kurulsaydı ikinci basış birinciyi geri
    // seçebilirdi. Burada gemi her basışta yer değiştiriyor.
    final positions = {
      1: const Vec2(100, 0),
      2: const Vec2(200, 0),
      3: const Vec2(300, 0),
    };
    final t = Targeting();
    final gezilen = <int>[];
    // Gemi her turda bir öncekinin dibine gidiyor: mesafe sırası her seferinde
    // BAŞKA bir dizilim veriyor.
    for (final nereden in [
      const Vec2(0, 0),
      const Vec2(300, 0),
      const Vec2(200, 0),
    ]) {
      t.cycle(positions.keys, nereden, from(positions));
      gezilen.add(t.selected);
    }
    expect(
      gezilen.toSet(),
      {1, 2, 3},
      reason: 'üç basışta üç ayrı hedef gezilmedi: $gezilen',
    );
  });

  test('küme DEĞİŞİNCE sıra yeniden kuruluyor', () {
    // Sıranın korunması bir donma değil: biri ölünce ya da biri görününce
    // liste o anki mesafeye göre yeniden kurulmalı, yoksa yeni gelen aday
    // sıraya hiç girmez.
    final iki = {1: const Vec2(100, 0), 2: const Vec2(200, 0)};
    final t = Targeting()..cycle(iki.keys, me, from(iki));
    expect(t.selected, 1);

    // 9 en yakın olarak sıraya giriyor, ama tur BAŞA SARMIYOR: seçim
    // nerede kaldıysa oradan devam ediyor. Yeni aday sıradaki yerinde
    // bekliyor ve tur dönünce geliyor.
    final uc = {...iki, 9: const Vec2(50, 0)};
    t.cycle(uc.keys, me, from(uc));
    expect(t.selected, 2, reason: 'tur başa sardı: seçim kaybedildi');
    t.cycle(uc.keys, me, from(uc));
    expect(t.selected, 9, reason: 'yeni aday sıraya hiç girmedi');
  });

  test('clear SIRAYI da unutuyor', () {
    final positions = {
      1: const Vec2(100, 0),
      2: const Vec2(200, 0),
    };
    final t = Targeting()
      ..cycle(positions.keys, me, from(positions))
      ..cycle(positions.keys, me, from(positions));
    expect(t.selected, 2);

    // Kilidi bırakan oyuncunun beklediği şey O ANDA en yakın olan hedef.
    t.clear();
    t.cycle(positions.keys, const Vec2(400, 0), from(positions));
    expect(t.selected, 2, reason: '400 birimden en yakın olan 2');
  });

  test('aday yoksa kilit düşer', () {
    final positions = {1: const Vec2(100, 0)};
    final t = Targeting()..cycle(positions.keys, me, from(positions));
    expect(t.hasTarget, isTrue);
    t.cycle(const <int>[], me, (_) => null);
    expect(t.hasTarget, isFalse);
  });

  test('listeden düşen hedef yerine EN YAKIN seçilir', () {
    final positions = {1: const Vec2(100, 0), 2: const Vec2(200, 0)};
    final t = Targeting()
      ..cycle(positions.keys, me, from(positions))
      ..cycle(positions.keys, me, from(positions));
    expect(t.selected, 2);

    // 2 ayrıldı: seçim listede yok, en yakından yeniden başlamalı.
    final rest = {1: const Vec2(100, 0)};
    t.cycle(rest.keys, me, from(rest));
    expect(t.selected, 1);
  });

  test('konumu bilinmeyen aday atlanır', () {
    final positions = {1: const Vec2(100, 0)};
    final t = Targeting()..cycle([1, 2], me, from(positions));
    expect(t.selected, 1, reason: '2 için konum yok, aday sayılmamalı');
  });

  test('geçersizleşen hedefin kilidi bırakılır', () {
    final positions = {1: const Vec2(100, 0)};
    final t = Targeting()..cycle(positions.keys, me, from(positions));
    expect(t.hasTarget, isTrue);

    // Öldü / ayrıldı / ilgi alanından çıktı.
    t.validate((_) => false);
    expect(
      t.hasTarget,
      isFalse,
      reason: 'sunucu da kilidi düşürüyor; istemci tutarsa boşluğa ışın çizer',
    );
  });

  test('geçerli hedefin kilidi korunur', () {
    final positions = {1: const Vec2(100, 0)};
    final t = Targeting()
      ..cycle(positions.keys, me, from(positions))
      ..validate((_) => true);
    expect(t.selected, 1);
  });

  test('clear kilidi bırakır', () {
    final positions = {1: const Vec2(100, 0)};
    final t = Targeting()
      ..cycle(positions.keys, me, from(positions))
      ..clear();
    expect(t.hasTarget, isFalse);
  });

  group('tıklayarak seçme', () {
    final positions = <int, Vec2>{
      1: const Vec2(100, 100),
      2: const Vec2(400, 100),
      3: const Vec2(410, 108),
    };
    Vec2? at(int id) => positions[id];
    double radius(int id) => 30;

    test('üstüne tıklanan hedef SEÇİLİR', () {
      final targeting = Targeting();
      expect(
        targeting.pick(const Vec2(108, 96), positions.keys, at, radius),
        isTrue,
      );
      expect(targeting.selected, 1);
    });

    test('yarıçapın dışına tıklamak seçmez', () {
      final targeting = Targeting();
      expect(
        targeting.pick(const Vec2(200, 200), positions.keys, at, radius),
        isFalse,
      );
      expect(targeting.selected, 0);
    });

    test('boşluğa tıklamak mevcut kilidi BOZMAZ', () {
      // Kilidi olan oyuncunun haritada gezinmek için attığı her tık hedefini
      // düşürseydi, nişan almak ile yol almak birbirini iptal ederdi.
      final targeting = Targeting()
        ..pick(const Vec2(100, 100), positions.keys, at, radius);
      expect(targeting.selected, 1);
      targeting.pick(const Vec2(2000, 2000), positions.keys, at, radius);
      expect(targeting.selected, 1);
    });

    test('üst üste binenlerde EN YAKIN kazanır', () {
      // Parmak kalın; altındaki iki şeyden hangisinin kastedildiğinin tek
      // makul cevabı en yakın olan.
      final targeting = Targeting();
      targeting.pick(const Vec2(404, 103), positions.keys, at, radius);
      expect(targeting.selected, 2);
      targeting.pick(const Vec2(409, 107), positions.keys, at, radius);
      expect(targeting.selected, 3);
    });

    test('kaybolan aday tıklanamaz', () {
      final targeting = Targeting();
      expect(
        targeting.pick(const Vec2(100, 100), [1], (_) => null, radius),
        isFalse,
      );
    });

    test('yarıçap ADAYA göre değişir', () {
      // Alien küçük, gemi büyük: tek bir sabit yarıçap ya küçüğü tıklanamaz
      // yapar ya büyüğün yanındaki boşluğu tıklanamaz.
      final targeting = Targeting();
      final wide = targeting.pick(
        const Vec2(160, 100),
        positions.keys,
        at,
        (id) => 80,
      );
      expect(wide, isTrue);
      expect(targeting.selected, 1);

      final narrow = Targeting().pick(
        const Vec2(160, 100),
        positions.keys,
        at,
        (id) => 20,
      );
      expect(narrow, isFalse);
    });
  });
}
