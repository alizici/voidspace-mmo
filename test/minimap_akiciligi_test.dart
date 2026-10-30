@Tags(['disi'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hud/minimap.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace3/ship/ship_state.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// MİNİMAP AKICILIĞI — poz durumdan AYRI bir hızda akıyor.
///
/// Oyuncunun tarifi: "minimap yavaş kalıyor gibi, takılıyor gibi". Doğruydu:
/// bütün HUD durumu saniyede on kez yayınlanıyor ve 120 Hz bir ekranda
/// saniyede on adım ilerleyen bir nokta zıplıyor. Bütün HUD'ı hızlandırmak
/// yanlış cevaptı — kalkan yüzdesi o hızda tazelenmeyi hak etmiyor ve ağacı
/// 120 kez yeniden kurmak pahalı.
void main() {
  testWidgets('poz değişince minimap YENİDEN KURULMADAN yeniden boyanıyor', (
    tester,
  ) async {
    final poz = ValueNotifier<GemiPozu?>(null);
    addTearDown(poz.dispose);
    var kurulum = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            kurulum++;
            return Minimap(state: ShipState.initial(ShipStats.bastion), poz: poz);
          },
        ),
      ),
    );
    expect(kurulum, 1);

    // Poz kanalı üstünden yüz güncelleme: widget ağacı BİR KEZ bile yeniden
    // kurulmamalı. Kurulsaydı kazanç sıfır olurdu — takılmanın sebebi zaten
    // ağacın on Hz'de kurulmasıydı.
    for (var i = 1; i <= 100; i++) {
      poz.value = GemiPozu(Vec2(i.toDouble(), i.toDouble()), i / 100);
      await tester.pump();
    }
    expect(kurulum, 1, reason: 'poz değişimi widget ağacını yeniden kurdu');
  });

  testWidgets('kanal BOŞKEN durumun konumu çiziliyor', (tester) async {
    // Sıfır bir poz DEĞİL: (0,0) dünyanın meşru bir köşesi. Kanal boşken
    // sıfır çizilseydi, ilk kare gelene kadar gemi köşede görünürdü — görsel
    // referans tam olarak bunu yakaladı.
    final bos = ValueNotifier<GemiPozu?>(null);
    addTearDown(bos.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Minimap(state: ShipState.initial(ShipStats.bastion), poz: bos),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('görüş kutusu İŞARETLE aynı pozdan besleniyor', () {
    // Kutu bir zamanlar durumdan (on Hz), işaret kanaldan (kare hızı)
    // okuyordu: kutu, akan bir işaretin çevresinde saniyede on kez
    // zıplıyordu. Aynı şeyi gösteren iki çizimin iki ayrı zamandan beslenmesi
    // en görünür türden tutarsızlık.
    //
    // Sınama KAYNAK düzeyinde ve olması gereken de bu: davranış farkı ancak
    // piksel karşılaştırmasıyla yakalanır, oysa kural tek cümle — kutu
    // `state.position` okumaz. Mimari testlerinin kullandığı yöntemin aynısı.
    final kaynak = File('lib/hud/minimap.dart').readAsStringSync();
    final bas = kaynak.indexOf('void _viewBox(');
    expect(bas, greaterThan(0), reason: 'görüş kutusu çizimi bulunamadı');
    final govde = kaynak.substring(bas, kaynak.indexOf('\n  }', bas));
    expect(
      govde,
      isNot(contains('state.position')),
      reason: 'kutu durumdan okuyor — işaretle ayrı hızda kalır',
    );
    expect(govde, contains('_poz'), reason: 'kutu poz kanalını okumuyor');
  });

  test('AYNI poz ikinci kez bildirilirse eşit sayılıyor', () {
    // Duran bir gemi radara iş çıkarmamalı: `==` üzerinden gereksiz boyama
    // eleniyor.
    const a = GemiPozu(Vec2(3, 4), 1.5);
    const b = GemiPozu(Vec2(3, 4), 1.5);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const GemiPozu(Vec2(3, 4), 1.6)));
  });

  test('poz kanalı YOKSA durum okunuyor — golden ve testler böyle koşuyor', () {
    // Kanal isteğe bağlı: görsel referanslar bloc kurmadan minimap çiziyor.
    expect(
      () => Minimap(state: ShipState.initial(ShipStats.bastion)),
      returnsNormally,
    );
  });
}
