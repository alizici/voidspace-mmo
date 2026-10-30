@Tags(['disi'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/zone.dart';

/// GEMİ deltasının GERÇEK boyu — `Replication.typicalDeltaBytes` doğru mu.
///
/// `wire_budget_test.dart` aynı ölçümü ALIENLER için yapıyor. Bandların başa
/// baş aritmetiği ise gemilerin (`EntityDelta`) sayısına dayanıyor ve o sayı
/// bugüne kadar ölçülmemiş, elle 5 yazılmıştı.

/// Bir maskenin telde kaç bayt ettiği — yazıcıya SORARAK, tablo ezberleyerek
/// değil. Alan boyları değişirse ölçüm kendiliğinden düzeliyor.
int recordBytes(int mask) {
  final w = ByteWriter(32);
  EntityDelta.write(w, 1, Int32List(EntityDelta.fields), mask);
  return w.length;
}

/// Bir gemiye tik başına verilecek girdi.
typedef Driver = ShipInput? Function(int tick, int index, ServerShip ship);

/// Tik başına, gemi başına delta maskesi toplayan koşum.
///
/// Maskeler `Zone.refreshWire`'ın hesapladığı gerçek `wireMask` — gateway'in
/// snapshot yazarken okuduğu alanın ta kendisi.
List<List<int>> maskStream({
  required int ticks,
  required List<Vec2> places,
  required Driver drive,
  int alienCount = 0,
  int warmup = 5,
}) {
  final world = GameWorld.standard;
  final zone = Zone(alienCount: alienCount);
  final ships = <ServerShip>[];
  for (var i = 0; i < places.length; i++) {
    final s = zone.join('P$i')!;
    s.state = s.state.copyWith(position: places[i]);
    ships.add(s);
  }
  // Isınma: `wireValid` ancak bir promote sonrası doğru oluyor.
  for (var t = 0; t < warmup; t++) {
    zone
      ..step()
      ..refreshWire()
      ..promoteWire();
  }
  final out = <List<int>>[];
  var seq = 1;
  for (var t = 0; t < ticks; t++) {
    for (var i = 0; i < ships.length; i++) {
      final input = drive(t, i, ships[i]);
      if (input != null) zone.enqueue(ships[i], input.copyWith(seq: seq++));
    }
    zone
      ..step()
      ..refreshWire();
    out.add([for (final s in ships) s.wireMask]);
    zone.promoteWire();
    // Dünya sınırı: konum tamponu kaymasın diye ölçüm merkezde tutuluyor.
    if (world.width < 0) break; // ölü dal, `world` kullanımı için
  }
  return out;
}

({double average, int records, int zero, Map<int, int> byMask}) summarise(
  List<List<int>> masks,
) {
  var bytes = 0;
  var records = 0;
  var zero = 0;
  final byMask = <int, int>{};
  for (final row in masks) {
    for (final m in row) {
      if (m == 0) {
        zero++;
        continue;
      }
      records++;
      bytes += recordBytes(m);
      byMask[m] = (byMask[m] ?? 0) + 1;
    }
  }
  return (
    average: records == 0 ? 0 : bytes / records,
    records: records,
    zero: zero,
    byMask: byMask,
  );
}

/// Gateway'in seçim kurallarını AYNEN uygulayan bayt sayacı.
///
/// Girdi, gerçek simülasyondan alınmış maske akışı; çıktı, verilen bant
/// aralığıyla telde kaç bayt gideceği. İki politikayı aynı akış üzerinde
/// karşılaştırmanın tek dürüst yolu bu — tahmin değil, tekrar oynatma.
int replay(List<int> masks, int interval, {int id = 7, int startTick = 0}) {
  var bytes = 0;
  var lastSent = -Replication.maxSilenceTicks;
  var stale = false;
  for (var i = 0; i < masks.length; i++) {
    final tick = startTick + i;
    final mask = masks[i];
    final since = tick - lastSent;
    final keyframe = (tick + id) % Protocol.keyframeTicks == 0;

    // BİRİNCİ ELEME — oran filtresi.
    if (!Replication.isCandidate(since, 0, 1) && since < interval) {
      if (mask != 0) stale = true;
      continue;
    }
    if (since < interval && !Replication.mustSend(since)) {
      if (mask != 0) stale = true;
      continue;
    }
    // İKİNCİ ELEME — boş maske bedava atlanır.
    if (!Replication.mustSend(since) && !keyframe && !stale && mask == 0) {
      continue;
    }
    bytes += (keyframe || stale) ? EntitySnapshot.wireSize : recordBytes(mask);
    stale = false;
    lastSent = tick;
  }
  return bytes;
}

void main() {
  final world = GameWorld.standard;
  final c = world.centre;

  test('1 · boş olmayan gemi deltasının ORTALAMA boyu', () {
    // Üç rejim, aynı koşum, tek fark girdi.
    final places = [
      for (var i = 0; i < 8; i++) c + Vec2(i * 120.0, (i % 3) * 90.0),
    ];

    final duran = summarise(
      maskStream(ticks: 120, places: places, drive: (t, i, s) => null),
    );
    final duz = summarise(
      maskStream(
        ticks: 120,
        places: places,
        // Tek hedef, uzağa: gemi düz uçuyor.
        drive: (t, i, s) => t == 0
            ? ShipInput(seq: 0, moveTarget: c + Vec2(5000, 200.0 * i))
            : null,
      ),
    );
    final donen = summarise(
      maskStream(
        ticks: 120,
        places: places,
        // Hedef her tik dönüyor + ateş açık: açı, itki ve bayraklar oynuyor.
        drive: (t, i, s) {
          final a = (t * 0.21) + i;
          return ShipInput(
            seq: 0,
            moveTarget: c + Vec2(math.cos(a) * 1400, math.sin(a) * 1400),
            firing: true,
            weaponTarget: i == 0 ? 2 : 1,
          );
        },
      ),
    );

    void report(
      String ad,
      ({double average, int records, int zero, Map<int, int> byMask}) r,
    ) {
      final top = r.byMask.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      // ignore: avoid_print
      print(
        '$ad → ortalama ${r.average.toStringAsFixed(2)} bayt · '
        'boş olmayan ${r.records} · boş ${r.zero} '
        '(%${(100 * r.zero / (r.zero + r.records)).toStringAsFixed(0)} boş) · '
        'en sık maske ${top.take(4).map((e) => '0x${e.key.toRadixString(16)}×${e.value}').join(' ')}',
      );
    }

    report('DURAN     ', duran);
    report('DÜZ UÇAN  ', duz);
    report('DÖNEN+ATEŞ', donen);

    expect(duz.records, greaterThan(0));

    // BEKÇİ İDDİASI — bu dosyanın ölçüm olmaktan çıkıp test olduğu yer.
    //
    // `Replication.typicalDeltaBytes` bu ölçümden geliyor ve bant tablosunun
    // (1/4/6) bütün gerekçesi ona dayanıyor. `EntityDelta`nın alan kümesi ya
    // da kuantalaması değiştiğinde sabit sessizce çürür ve bantlar yanlış
    // aritmetikle savunulmuş kalır — tam olarak 5'in başına gelen şey.
    final duzOrt = duz.average;
    expect(
      duzOrt,
      inInclusiveRange(6.5, 7.5),
      reason:
          'düz uçuşta delta ortalaması ${duzOrt.toStringAsFixed(2)} B — '
          'Replication.typicalDeltaBytes (${Replication.typicalDeltaBytes}) '
          'yeniden ölçülmeli',
    );
    expect(
      Replication.typicalDeltaBytes,
      closeTo(duzOrt, 1.0),
      reason: 'sabit ile ölçüm ayrışmış',
    );
  });

  test('2 · intervalFor tablosu', () {
    const r = Protocol.interestRadius;
    // ignore: avoid_print
    print('ilgi yarıçapı r = $r');
    for (final f in [
      0.0,
      0.1,
      0.25,
      0.4,
      0.49,
      0.5,
      0.501,
      0.6,
      0.7,
      0.74,
      0.75,
      0.751,
      0.9,
      1.0,
      1.15,
    ]) {
      final d = r * f;
      // ignore: avoid_print
      print(
        '  d = ${d.toStringAsFixed(0)} (%${(f * 100).toStringAsFixed(1)} r) '
        '→ aralık ${Replication.intervalFor(d * d, r)}',
      );
    }
  });

  test('3 · her bant için başa baş — ÖLÇÜLEN ortalamayla', () {
    // Ölçüm 1'in dönen+ateş rejimi (en kötü hâl) ve düz uçuş (tipik hâl)
    // ayrı ayrı besleniyor.
    final places = [for (var i = 0; i < 8; i++) c + Vec2(i * 120.0, 0)];
    final duz = summarise(
      maskStream(
        ticks: 120,
        places: places,
        drive: (t, i, s) => t == 0
            ? ShipInput(seq: 0, moveTarget: c + Vec2(5000, 200.0 * i))
            : null,
      ),
    ).average;
    final donen = summarise(
      maskStream(
        ticks: 120,
        places: places,
        drive: (t, i, s) {
          final a = (t * 0.21) + i;
          return ShipInput(
            seq: 0,
            moveTarget: c + Vec2(math.cos(a) * 1400, math.sin(a) * 1400),
            firing: true,
            weaponTarget: i == 0 ? 2 : 1,
          );
        },
      ),
    ).average;

    for (final entry in {'düz': duz, 'dönen': donen}.entries) {
      // ignore: avoid_print
      print(
        '${entry.key} · ölçülen ortalama ${entry.value.toStringAsFixed(2)} B '
        '→ BAŞA BAŞ aralık = ${EntitySnapshot.wireSize} / '
        '${entry.value.toStringAsFixed(2)} = '
        '${(EntitySnapshot.wireSize / entry.value).toStringAsFixed(2)} '
        '(kodun varsaydığı: ${EntitySnapshot.wireSize} / '
        '${Replication.typicalDeltaBytes} = '
        '${(EntitySnapshot.wireSize / Replication.typicalDeltaBytes).toStringAsFixed(2)})',
      );
      for (final n in [2, 3, 4, 5, 6]) {
        final gain = n * entry.value;
        // ignore: avoid_print
        print(
          '${entry.key} · aralık $n → kazanç ${gain.toStringAsFixed(1)} vs '
          'tam kayıt ${EntitySnapshot.wireSize} → '
          '${gain > EntitySnapshot.wireSize ? 'KÂR' : 'ZARAR'} '
          '(${(gain - EntitySnapshot.wireSize).toStringAsFixed(1)} bayt)',
        );
      }
    }
  });

  test('4 · bant 2 gerçekten zarar mı — akış tekrar oynatılarak', () {
    final places = [for (var i = 0; i < 6; i++) c + Vec2(i * 150.0, 0)];
    final rejimler = <String, List<List<int>>>{
      'duran': maskStream(ticks: 300, places: places, drive: (t, i, s) => null),
      'düz': maskStream(
        ticks: 300,
        places: places,
        drive: (t, i, s) => t == 0
            ? ShipInput(seq: 0, moveTarget: c + Vec2(5200, 150.0 * i))
            : null,
      ),
      'dönen+ateş': maskStream(
        ticks: 300,
        places: places,
        drive: (t, i, s) {
          final a = (t * 0.21) + i;
          return ShipInput(
            seq: 0,
            moveTarget: c + Vec2(math.cos(a) * 1500, math.sin(a) * 1500),
            firing: true,
            weaponTarget: i == 0 ? 2 : 1,
          );
        },
      ),
    };

    for (final e in rejimler.entries) {
      final perShip = <List<int>>[
        for (var s = 0; s < places.length; s++)
          [for (final row in e.value) row[s]],
      ];
      final line = <int, int>{};
      for (final n in [1, 2, 3, 4, 6]) {
        var total = 0;
        for (var s = 0; s < perShip.length; s++) {
          total += replay(perShip[s], n, id: s + 1);
        }
        line[n] = total;
      }
      // ignore: avoid_print
      print(
        '${e.key.padRight(11)} '
        '${line.entries.map((x) => 'N=${x.key}:${x.value}B').join('  ')}  '
        '→ N=2 vs N=1: '
        '${((line[2]! - line[1]!) / line[1]! * 100).toStringAsFixed(1)}%',
      );
    }
  });

  test('5 · ilgi yarıçapının HALKALARI — delta boyu mesafeye bağlı mı', () {
    // Konum kuantalaması DÜNYAYA göre (`Quantize.position`), izleyiciye göre
    // değil. Yani halkanın delta boyunu değiştirmesi için bir sebep YOK — ama
    // bu iddia da ölçülüyor, varsayılmıyor: gemiler üç halkaya konup AYNI
    // hareketi yapıyor.
    const r = Protocol.interestRadius;
    final rings = {
      'yakın (%25 r)': 0.25,
      'orta (%60 r)': 0.60,
      'uzak (%90 r)': 0.90,
    };
    final results = <String, double>{};
    final effective = <String, double>{};

    // İki yön: eksene PARALEL (yalnız x değişir) ve ÇAPRAZ (x ve y).
    // Ayrımı ölçmek şart — `typicalDeltaBytes = 5` tam olarak eksene paralel
    // hareketin sayısı, ve gerçek uçuşun sayısı değil.
    for (final yon in {
      'eksen': const Vec2(4000, 0),
      'çapraz': const Vec2(3400, 2100),
    }.entries) {
      for (final ring in rings.entries) {
        final d = r * ring.value;
        // İzleyici merkezde (index 0), diğer altı gemi halkanın üstünde.
        final places = <Vec2>[c];
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          places.add(c + Vec2(math.cos(a) * d, math.sin(a) * d));
        }
        final masks = maskStream(
          ticks: 240,
          places: places,
          // Halkadaki gemilerin hepsi aynı yönde düz uçuyor; izleyici duruyor.
          drive: (t, i, s) => (i == 0 || t != 0)
              ? null
              : ShipInput(seq: 0, moveTarget: s.state.position + yon.value),
        );
        // İzleyicinin kendi kaydı sayılmıyor (kendini görmez).
        final others = [for (final row in masks) row.sublist(1)];
        final sum = summarise(others);
        results[ring.key] = sum.average;

        // Bandın atadığı aralıkla TELDE ne oluyor — tekrar oynatma.
        final interval = Replication.intervalFor(d * d, r);
        var bytes = 0;
        for (var s = 0; s < 6; s++) {
          bytes += replay(
            [for (final row in others) row[s]],
            interval,
            id: s + 2,
          );
        }
        effective[ring.key] = bytes / (240 * 6);

        // ignore: avoid_print
        print(
          '${yon.key.padRight(7)} ${ring.key.padRight(14)} d=${d.toStringAsFixed(0)} '
          'aralık=$interval · boş olmayan delta ort. '
          '${sum.average.toStringAsFixed(2)} B '
          '(boş %${(100 * sum.zero / (sum.zero + sum.records)).toStringAsFixed(0)}) '
          '· TELDE gemi-tik başına ${effective[ring.key]!.toStringAsFixed(2)} B',
        );
      }
    }

    // Aynı hareket, farklı halka: delta boyu değişmemeli.
    final values = results.values.toList();
    for (final v in values) {
      expect(
        (v - values.first).abs(),
        lessThan(0.5),
        reason:
            'delta boyu mesafeye bağlı çıktı — kuantalama izleyiciye göre mi?',
      );
    }
  });
}
