@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Tehdit tablosu — hem "kimi vuracağım" hem "ödül kime".
void main() {
  bool alive(int _) => true;

  test('en çok hasar veren HEDEF olur, en son vuran değil', () {
    // Önceki hâl "en son vuran"dı: alienler saldıranlar arasında gidip
    // geliyordu ve kin yönetimi diye bir katman kurulamıyordu.
    final table = ThreatTable()
      ..add(1, 1000)
      ..add(2, 50);
    expect(table.top(alive), 1, reason: 'son vuran hedef oldu');
  });

  test('ölü ya da ayrılmış oyuncu HEDEF olmuyor', () {
    // Kovalanamayan bir hedef, alieni haritada donmuş bırakır.
    final table = ThreatTable()
      ..add(1, 1000)
      ..add(2, 50);
    expect(table.top((id) => id != 1), 2);
  });

  test('tehdit SÖNÜYOR — vurup kaçan sonsuza kadar kovalanmıyor', () {
    final table = ThreatTable()..add(1, 100);
    table.decay(ThreatTable.halfLife);
    // Yarı ömür sonunda yarısı.
    expect(table.top(alive), 1);
    table.decay(ThreatTable.halfLife * 10);
    expect(table.top(alive), isNull, reason: 'tehdit hiç sönmedi');
  });

  test('ödül payı HASARA göre — ve toplam KORUNUYOR', () {
    // Payları tek tek yuvarlamak ekonomiye para basar ya da sızdırır.
    // Milyonlarca imhada görünmez bir açık.
    final table = ThreatTable()
      ..add(1, 1)
      ..add(2, 1)
      ..add(3, 1);
    final split = table.split(400);
    expect(split.values.fold<int>(0, (a, b) => a + b), 400);
    expect(split.values.every((v) => v > 0), isTrue);
  });

  test('pay dağıtımı TEKRARLANABİLİR', () {
    // Eşit kalanlarda harita sırasına düşmek, simülasyonun
    // tekrarlanabilirliğini bitirirdi.
    Map<int, int> run() =>
        (ThreatTable()
              ..add(7, 1)
              ..add(3, 1)
              ..add(5, 1))
            .split(100);
    expect(run(), run());
  });

  test('hasarın %99\'unu veren, ödülün %99\'unu alıyor', () {
    final table = ThreatTable()
      ..add(1, 9900)
      ..add(2, 100);
    final split = table.split(1000);
    expect(split[1], 990);
    expect(split[2], 10);
  });

  test('ÖLEN oyuncu da payını alıyor', () {
    // Tehditten düşüyor (kovalanamaz) ama hasar payından DÜŞMÜYOR: o kavgada
    // hasar verdi. İkisini birlikte silmek "vurup ölen hiçbir şey almaz"
    // kuralı yaratırdı.
    final table = ThreatTable()
      ..add(1, 500)
      ..add(2, 500)
      ..forget(1);
    expect(table.top(alive), 2);
    expect(table.split(200)[1], 100, reason: 'ölen oyuncunun payı silindi');
  });

  test('boş tabloda ödül YOK — son vuruşa düşmüyor', () {
    expect(ThreatTable().split(500), isEmpty);
  });
}
