@Tags(['kod-belge', 'turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 16.7 · Türetilen kaydı — belgedeki türetilen etiketlerin hesaplayıcısı.
void main() {
  // KARAR 16.7 s1
  test('kayıttaki her işlev örnek argümanla SONLU bir sayı veriyor', () {
    for (final e in TuretilenKaydi.islevler.entries) {
      final args = List<num>.filled(e.value.argSayisi, 2);
      final v = TuretilenKaydi.hesapla(e.key, args);
      expect(v, isNotNull, reason: '${e.key} hesaplanamadı');
      expect(v!.isFinite, isTrue, reason: '${e.key} sonsuz ya da NaN');
      expect(e.value.aciklama, isNotEmpty, reason: '${e.key} açıklamasız');
    }
  });

  // KARAR 16.7 s1
  test('yanlış argüman sayısı ve bilinmeyen ad NULL', () {
    expect(TuretilenKaydi.hesapla('mermiPvpTtk', const []), isNull);
    expect(TuretilenKaydi.hesapla('yok', const [1]), isNull);
    expect(
      TuretilenKaydi.hesapla('mermiPvpTtk', const [6]),
      TasarimGirdileri.referansTTK / 6,
    );
  });
}
