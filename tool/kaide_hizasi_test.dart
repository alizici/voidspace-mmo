import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/govde_tasarimlari.dart';

/// Görsel referans: sekiz tasarımın silah kaideleri, SİLÜETİN ÜSTÜNDE.
///
/// **Neden var.** Kaide koordinatları voidspace2'den elle taşındı ve tasarım
/// uzayındalar — yani hiçbir birim testi onların GEMİNİN ÜSTÜNDE durduğunu
/// söyleyemez. Aynalık, omurga indeksi, ateş sırası: hepsi doğru olup namlular
/// yine de boşluğa bakıyor olabilir.
///
/// Bu referans tam o soruyu cevaplıyor. Her kart bir tasarımın ikonunu
/// `erisim`e göre ölçekleyip kaideleri (halka) ve namlu ağızlarını (dolu
/// nokta) üstüne basıyor. Omurga topu ayrı renkte.
/// `flutter test` varsayılan olarak Ahem kullanıyor: her harf dolu bir kare.
/// Etiketler onunla okunmuyor — `menu_preview_test.dart` aynı dersi aldı.
Future<void> _loadMono() async {
  for (final yol in const [
    '/System/Library/Fonts/Monaco.ttf',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
  ]) {
    final dosya = File(yol);
    if (!dosya.existsSync()) continue;
    await (FontLoader('monospace')
          ..addFont(Future.value(dosya.readAsBytesSync().buffer.asByteData())))
        .load();
    return;
  }
}

void main() {
  testWidgets('Kaide hizası görsel referansı', (tester) async {
    await _loadMono();
    tester.view
      ..physicalSize = const Size(1280, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final resimler = <int, ui.Image>{};
    await tester.runAsync(() async {
      for (final t in GovdeTasarimlari.hepsi) {
        final veri = await rootBundle.load(t.ikon);
        resimler[t.kademe] = (await ui.instantiateImageCodec(
          veri.buffer.asUint8List(),
        ).then((c) => c.getNextFrame())).image;
      }
    });

    const key = ValueKey('kaide-hizasi');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(
          size: const Size(1280, 700),
          painter: _Painter(resimler),
        ),
      ),
    );
    await tester.pump();

    await expectLater(find.byKey(key), matchesGoldenFile('kaide_hizasi.png'));
  });
}

class _Painter extends CustomPainter {
  const _Painter(this.resimler);

  final Map<int, ui.Image> resimler;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080C13),
    );
    const sutun = 4;
    final hucre = Size(size.width / sutun, size.height / 2);

    for (final t in GovdeTasarimlari.hepsi) {
      final sx = (t.kademe % sutun) * hucre.width;
      final sy = (t.kademe ~/ sutun) * hucre.height;
      canvas
        ..save()
        ..translate(sx + hucre.width / 2, sy + hucre.height * 0.48);

      // İkon, tasarım uzayında `erisim`in iki katını kaplıyor — üretici
      // kadrajı da (%70) burada telafi ediliyor, yoksa katalog PNG'leri
      // kaidelerden farklı ölçekte durur.
      final olcek = hucre.height * 0.62 / (t.erisim * 2);
      canvas.scale(olcek);

      final resim = resimler[t.kademe]!;
      final kutu = t.erisim * 2 / 0.70;
      canvas.drawImageRect(
        resim,
        Rect.fromLTWH(0, 0, resim.width.toDouble(), resim.height.toDouble()),
        Rect.fromCenter(
          center: Offset(0, -t.merkezKaydirmasi),
          width: kutu,
          height: kutu,
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );

      final agiz = t.namluAgizlari;
      for (var i = 0; i < t.kaideler.length; i++) {
        final omurga = i == t.omurgaKaidesi;
        final renk = omurga
            ? const Color(0xFFFFC145)
            : const Color(0xFF4FE3FF);
        // Kaide: halka. Namlu ağzı: dolu nokta. Aralarındaki çizgi projektörün
        // boyu — namlunun nereye kadar uzandığı.
        canvas
          ..drawLine(
            t.kaideler[i],
            agiz[i],
            Paint()
              ..strokeWidth = 1.2
              ..color = renk.withValues(alpha: 0.55),
          )
          ..drawCircle(
            t.kaideler[i],
            omurga ? 3.4 : 2.8,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = renk,
          )
          ..drawCircle(agiz[i], omurga ? 2.6 : 2.0, Paint()..color = renk);
      }
      canvas.restore();

      final adi = TextPainter(
        text: TextSpan(
          text: '${t.kademe + 1} · ${t.ad}',
          style: const TextStyle(
            color: Color(0xFF94A3B9),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: hucre.width - 16);
      adi.paint(
        canvas,
        Offset(sx + (hucre.width - adi.width) / 2, sy + hucre.height - 22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => false;
}
