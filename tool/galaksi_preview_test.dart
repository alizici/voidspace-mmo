import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hud/galaksi_haritasi.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Görsel referans: galaksi haritası.
///
/// Ölçülen şey DÜZEN: kilitli ile açık düğümün ayırt edilip edilmediği, üç
/// harita tipinin pusula düzeninde durup durmadığı, ve telefon yatayda beş
/// bölgenin sığıp sığmadığı.
Future<void> _loadMono() async {
  for (final path in const [
    '/System/Library/Fonts/Monaco.ttf',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader('monospace')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
    return;
  }
}

const _screens = [
  (name: 'masaustu', size: Size(1280, 720)),
  (name: 'telefon', size: Size(844, 390)),
];

void main() {
  for (final screen in _screens) {
    testWidgets('Galaksi görsel referansı · ${screen.name}', (tester) async {
      await _loadMono();
      tester.view
        ..physicalSize = screen.size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Ortadaki bölgenin eşiğinde duran oyuncu: bir kısmı açık, bir kısmı
      // kilitli. Hepsi açık ya da hepsi kilitli bir ekran düzen hakkında
      // hiçbir şey söylemez — ve "hepsi açık" hâli bildirilen hatanın
      // kendisiydi: ekran hiçbir şey anlatmıyordu.
      final bolge = Bolge.hepsi[Bolge.hepsi.length ~/ 2];
      const key = ValueKey('galaksi-preview');

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: GalaksiEkrani(
              br: bolge.girisEsigi,
              konum: Harita(bolge, HaritaTipi.pve),
              onKapat: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('galaksi_${screen.name}.png'),
      );
    });
  }
}
