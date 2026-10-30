import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/palette.dart';
import 'package:voidspace3/hangar/unvan_amblemi.dart';
import 'package:voidspace3/hangar/unvan_yazisi.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Görsel referans: yirmi unvan ambleminin tamamı, tek sayfada.
///
/// Amblemler tek tek bakıldığında değil YAN YANA yargılanabiliyor: bir çağın
/// aparatı bir öncekinden ayırt edilebiliyor mu, merkez glifler yirmi adım
/// boyunca birbirine benzemeye başlıyor mu, renk merdiveni okunuyor mu.
/// Golden bu sorunun cevabını kayıt altına alıyor.
///
/// Kare DURGUN çiziliyor (`zaman: null`): animasyonlu bir golden ölçümü
/// zamanlamaya bağlar ve her koşuda başka bir kare yakalardı.
/// Golden'ın yazıları KUTU çıkmasın diye sistem yazı tipi — menü
/// önizlemesinin kullandığı yükleyicinin aynısı.
Future<void> _yaziTipi() async {
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

void main() {
  testWidgets('Unvan amblemleri görsel referansı', (tester) async {
    await _yaziTipi();
    tester.view
      ..physicalSize = const Size(1200, 980)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('unvan-amblemleri');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(1200, 980), painter: _Sayfa()),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('unvan_amblemleri.png'),
    );
  });

  testWidgets('Unvan yazısı görsel referansı', (tester) async {
    await _yaziTipi();
    tester.view
      ..physicalSize = const Size(760, 460)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('unvan-yazilari');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        // `Scaffold` şart: Material atası olmayan metin, hata ayıklama
        // altı çizgisiyle çiziliyor ve referans yanlış görünüyor.
        home: Scaffold(
          body: RepaintBoundary(key: key, child: _yaziSayfasi()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(find.byKey(key), matchesGoldenFile('unvan_yazilari.png'));
  });
}

/// İkinci referans: adın TİPOGRAFİSİ. Amblem "hangi unvan" diyor, yazı
/// "ne kadar yol" diyor — ağırlık, harf aralığı, hale ve son çağda gradyan.
/// Dört çağdan ikişer örnek: her çağın başı ve sonu.
Widget _yaziSayfasi() => ColoredBox(
  color: Palette.menuBg,
  child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final basamak in const [0, 29, 30, 59, 60, 89, 90, 119])
          Row(
            children: [
              UnvanIkonu(
                unvanIndeksi: Unvan.adIndeksi(basamak),
                kademe: Unvan.kademe(basamak),
                boy: 26,
              ),
              const SizedBox(width: 14),
              UnvanYazisi(
                ad: Unvan.adi(basamak),
                unvanIndeksi: basamak,
                boy: 22,
              ),
              const Spacer(),
              Text(
                '${Unvan.cagi(basamak).toUpperCase()} · BASAMAK $basamak',
                style: Palette.mono(11, color: Palette.faint, spacing: 1.2),
              ),
            ],
          ),
      ],
    ),
  ),
);

class _Sayfa extends CustomPainter {
  const _Sayfa();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.menuBg);

    // Üst blok: yirmi ad, beşerli dört sıra — sıralar çağlar.
    const sutun = 5, boy = 68.0;
    final adimX = size.width / sutun;
    for (var i = 0; i < Unvan.adlar.length; i++) {
      final sx = adimX * (i % sutun) + adimX / 2;
      final sy = 92 + (i ~/ sutun) * 196.0;
      canvas.save();
      canvas.translate(sx, sy);
      unvanAmblemiCiz(
        canvas,
        boy,
        unvanIndeksi: i,
        // Kademe adla birlikte ilerliyor: ilk ad I, son ad VI. Tek bir
        // kademede çizmek dış halkanın ne yaptığını gizlerdi.
        kademe: (i * 6 / Unvan.adlar.length).floor(),
      );
      canvas.restore();
      _yaz(
        canvas,
        Unvan.adlar[i].toUpperCase(),
        Offset(sx, sy + boy + 14),
        UnvanPaleti.of(i).acik,
        11,
      );
      _yaz(
        canvas,
        Unvan.caglar[i ~/ 5].toUpperCase(),
        Offset(sx, sy + boy + 30),
        Palette.faint,
        9,
      );
    }

    // Alt şerit: tek adın altı kademesi, küçük ikon boyunda.
    _yaz(
      canvas,
      'KÜÇÜK İKON · ALTI KADEME',
      Offset(size.width / 2, size.height - 76),
      Palette.muted,
      10,
    );
    for (var kademe = 0; kademe < 6; kademe++) {
      canvas.save();
      canvas.translate(size.width / 2 + (kademe - 2.5) * 46, size.height - 40);
      unvanIkonuCiz(canvas, 16, unvanIndeksi: 12, kademe: kademe);
      canvas.restore();
    }
  }

  void _yaz(Canvas c, String metin, Offset at, Color renk, double boy) {
    final tp = TextPainter(
      text: TextSpan(
        text: metin,
        style: TextStyle(
          color: renk,
          fontSize: boy,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(_Sayfa oldDelegate) => false;
}
