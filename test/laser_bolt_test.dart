@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/laser_bolt.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// GÖRSEL ↔ SAYISAL çivisi.
///
/// `BoltArt.id`'nin tek işi, bir ışın çiziminin hangi lazere ait olduğunu
/// söylemek. Alan bir zamanlar yalnız totolojik bir fabrika tarafından
/// okunuyordu (`id == pl4.id ? pl4 : pl4`) ve o fabrikanın hiç çağıranı yoktu
/// — yani alan pratikte YAZILIYOR ama OKUNMUYORDU.
///
/// Fabrika silindi. Alan kalıyor çünkü belgelediği bağ gerçek; bu dosya o bağı
/// bir iddiaya çeviriyor, yoksa alan sessizce ölü ağırlığa döner.
void main() {
  test('ışın çizimi ile lazer TANIMI aynı kimliği taşıyor', () {
    expect(
      BoltArt.pl4.id,
      LaserStats.pl4.id,
      reason:
          'çizim ile sayısal tanım farklı lazeri adlandırıyor — ekranda bir '
          'silahın ışını, başka bir silahın hasarıyla çiziliyor',
    );
  });

  test('ışın hızı MERMİDEN hızlı — ışın hedefe hasardan sonra varmıyor', () {
    // Işın görseli hasarın habercisi: sunucu vuruşu çözdüğünde oyuncu ışını
    // çoktan görmüş olmalı. Menzili kat etme süresi atış aralığını aşarsa
    // ikinci yaylım birincisi varmadan atılır ve ekran gerçeği geriden anlatır.
    final ucusSuresi = LaserStats.pl4.range / BoltArt.pl4.speed;
    expect(
      ucusSuresi,
      lessThan(LaserStats.pl4.fireInterval),
      reason:
          'ışın menzili ${ucusSuresi.toStringAsFixed(2)} sn\'de kat ediyor, '
          'atış aralığı ${LaserStats.pl4.fireInterval} sn — ışınlar birikiyor',
    );
  });
}
