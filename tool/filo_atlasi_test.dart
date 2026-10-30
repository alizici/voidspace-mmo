import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/govde_tasarimlari.dart';

/// Görsel referans: sekiz gövdenin ATLASTAN çizilmiş hâli, silahlarıyla.
///
/// **Neden var.** Silüet bloğu atlasa girdi ve kaideler normalize edildi, ama
/// hiçbir birim testi topların gövdenin ÜSTÜNDE durduğunu söyleyemez: kare
/// dikdörtgenleri doğru, ölçek doğru, kaide dünya birimi doğru olup silah yine
/// de kanadın yanında boşlukta durabilir.
///
/// Her hücre bir gövdeyi oyundaki gibi çiziyor: silüet (ya da tepe kademede
/// canlı gövdenin ilk karesi) + beş silah yuvası, hepsi atlastan.
/// `flutter test` varsayılan olarak Ahem kullanıyor: her harf dolu bir kare.
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
  testWidgets('Filo atlası görsel referansı', (tester) async {
    await _loadMono();
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ui.Image atlas;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File('assets/ship_atlas.png').readAsBytesSync(),
      );
      atlas = (await codec.getNextFrame()).image;
    });

    const key = ValueKey('filo-atlasi');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(
          size: const Size(1280, 720),
          painter: _Painter(atlas),
        ),
      ),
    );
    await tester.pump();

    await expectLater(find.byKey(key), matchesGoldenFile('filo_atlasi.png'));
  });
}

class _Painter extends CustomPainter {
  const _Painter(this.atlas);

  final ui.Image atlas;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060A11),
    );
    const sutun = 4;
    final hucre = Size(size.width / sutun, size.height / 2);
    final boya = Paint()..filterQuality = FilterQuality.medium;

    for (final t in GovdeTasarimlari.hepsi) {
      final sx = (t.kademe % sutun) * hucre.width;
      final sy = (t.kademe ~/ sutun) * hucre.height;
      canvas
        ..save()
        ..translate(sx + hucre.width / 2, sy + hucre.height * 0.46);

      // Atlas pikselinden dünya birimine, sonra hücreye sığacak kadar.
      final olcek = 1.6 / AtlasLayout.pixelsPerWorldUnit;
      canvas.scale(olcek);

      // Gövde: yedisi silüet, sekizincisi canlı bloğun durgun karesi.
      final govde = t.cizildi
          ? AtlasLayout.hullFrame(0, 0)
          : AtlasLayout.siluetFrame(t.kademe);
      canvas.drawImageRect(
        atlas,
        govde,
        Rect.fromLTWH(
          -AtlasLayout.hullAnchor.dx,
          -AtlasLayout.hullAnchor.dy,
          govde.width,
          govde.height,
        ),
        boya,
      );

      // Silah yuvaları — dünya biriminde, atlas pikseline çevrilerek.
      //
      // Kare İNDEKSE göre: 2. kaide omurga topu ve daha iri çiziliyor.
      // Hepsini onunla çizmek gemiyi beş ağır topla göstermek olurdu.
      final kaideler = t.dunyaKaideleri;
      for (var i = 0; i < kaideler.length; i++) {
        final at = kaideler[i];
        final kare = AtlasLayout.emitterFrame(i, 0);
        canvas
          ..save()
          ..translate(
            at.dx * AtlasLayout.pixelsPerWorldUnit,
            at.dy * AtlasLayout.pixelsPerWorldUnit,
          )
          ..drawImageRect(
            atlas,
            kare,
            Rect.fromLTWH(
              -AtlasLayout.emitterAnchor.dx,
              -AtlasLayout.emitterAnchor.dy,
              kare.width,
              kare.height,
            ),
            boya,
          )
          ..restore();
      }
      canvas.restore();

      final adi = TextPainter(
        text: TextSpan(
          text: '${t.kademe + 1} · ${t.ad}',
          style: const TextStyle(
            color: Color(0xFF8FA0B8),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: hucre.width - 16);
      adi.paint(
        canvas,
        Offset(sx + (hucre.width - adi.width) / 2, sy + hucre.height - 24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => false;
}
