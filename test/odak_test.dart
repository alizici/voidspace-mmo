@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app.dart';

/// KLAVYE ODAĞI — oyun tuşları ne zaman dinliyor.
///
/// Flame tuşları yalnız `GameWidget`in odağı varken görüyor. HUD düğmeleri
/// odak alabildiği için oyun sağırlaşabiliyordu: gemi tuşlara cevap vermiyor
/// ama ekran canlı, yani "klavye çalışmıyor" gibi görünüyor. Kural bir işleve
/// alındı ki sınanabilsin (`lifecycle.dart`ın deseni).
void main() {
  test('perde yokken odak oyuna döner', () {
    expect(odakOyunaDonmeli(hangarAcik: false, galaksiAcik: false), isTrue);
  });

  test('perde varken odak PERDEDE kalır', () {
    // Hangarda dokunan biri odağını oyuna kaptırsaydı o ekranın kendi
    // tuşları çalışmazdı.
    expect(odakOyunaDonmeli(hangarAcik: true, galaksiAcik: false), isFalse);
    expect(odakOyunaDonmeli(hangarAcik: false, galaksiAcik: true), isFalse);
    expect(odakOyunaDonmeli(hangarAcik: true, galaksiAcik: true), isFalse);
  });
}
