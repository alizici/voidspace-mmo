@Tags(['kod-belge'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 02.7 · KAYIT TABLOSU ↔ KOD.
///
/// Belge kaynak, kod uygulama: `docs/02-stat-kutuphanesi.md` içindeki 02.7
/// tablosu satır satır okunuyor ve `Stats.hepsi` ile karşılaştırılıyor.
/// Tablo değişirse kayıt, kayıt değişirse tablo kırılır — ikisi aynı
/// commit'te düzelir.
void main() {
  final metin = File('docs/02-stat-kutuphanesi.md').readAsStringSync();
  final bas = metin.indexOf('## 02.7');
  final son = metin.indexOf('\n## ', bas + 1);
  final bolum = metin.substring(bas, son < 0 ? metin.length : son);
  final satirlar = <List<String>>[];
  for (final s in bolum.split('\n')) {
    if (!s.startsWith('| ')) continue;
    final hucreler = s
        .split('|')
        .map((h) => h.trim().replaceAll('`', ''))
        .toList();
    final h = hucreler.sublist(1, hucreler.length - 1);
    if (h.isEmpty || !RegExp(r'^[a-z_]+$').hasMatch(h.first)) continue;
    satirlar.add(h);
  }

  StatLayer katman(String kod) =>
      StatLayer.values.firstWhere((l) => l.code == kod);
  StatChannel kanal(String ad) => switch (ad) {
    'saldırı' => StatChannel.attack,
    'savunma' => StatChannel.defence,
    'sistem' => StatChannel.system,
    _ => throw ArgumentError('kanal: $ad'),
  };
  StatBirimi birim(String ad) =>
      StatBirimi.values.firstWhere((b) => b.name == ad);
  Set<StatScope> kapsam(String s) => s
      .split('·')
      .map((p) => StatScope.values.firstWhere((k) => k.name == p.trim()))
      .toSet();

  test('02.7 · belgedeki tablo kayıtla satır satır aynı', () {
    expect(satirlar, hasLength(22), reason: 'belgede 22 satır bekleniyor');
    expect(
      satirlar.map((h) => h[0]).toSet(),
      Stats.hepsi.map((s) => s.id).toSet(),
      reason: 'kimlik kümesi ayrışmış',
    );
    for (final h in satirlar) {
      final s = Stats.kayit(h[0])!;
      expect(h, hasLength(7), reason: '${s.id} satırı yedi sütun değil');
      expect(s.layer, katman(h[1]), reason: '${s.id} katman');
      expect(s.channel, kanal(h[2]), reason: '${s.id} kanal');
      expect(s.birim, birim(h[3]), reason: '${s.id} birim');
      expect(s.kapsam, kapsam(h[4]), reason: '${s.id} kapsam');
      expect(s.es.toString(), h[5], reason: '${s.id} eş');
      expect(s.altStat, h[6] == '✓', reason: '${s.id} alt stat');
    }
  });

  test('02.7 · açık ve ayrılmış ayrımı belgeyle aynı', () {
    // İlk tablo açık, ikinci ayrılmış: belgenin sırası kaynağın sırası.
    final acik = satirlar.take(Stats.all.length).map((h) => h[0]).toSet();
    final ayrilmis = satirlar.skip(Stats.all.length).map((h) => h[0]).toSet();
    expect(acik, Stats.all.map((s) => s.id).toSet());
    expect(ayrilmis, Stats.ayrilmis.map((s) => s.id).toSet());
  });
}
