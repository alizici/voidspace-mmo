import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/void_portal.dart';
import 'package:voidspace3/game/components/gecit_katmani.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Görsel referans: bir haritanın dört geçidi.
///
/// Canlı ekrandan yakalanamayan şey: dört kapı haritanın dört kenarında ve
/// aralarında on bir bin birim var — hepsi tek karede ancak uzaklaştırılmış
/// bir görüntüde görünüyor. Burada dünya ekrana sığdırılıyor.
///
/// Ölçülen şey KODLAMA: açık ile kilitli kapının ayırt edilebilirliği, ve
/// etiketin okunabilirliği.
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

void main() {
  testWidgets('Geçit görsel referansı', (tester) async {
    await _loadMono();
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // İlk bölgenin PvE'si: dört kapısı da var (batı yok, doğu · kuzey · güney)
    // ve doğu kapısı kilitli — yeni oyuncunun savaş puanı ikinci bölgeye
    // yetmiyor. Yani tek karede hem açık hem kilitli kodlama görünüyor.
    final katman = GecitKatmani(harita: Harita.baslangic, br: 0);
    // Şerit pişsin: pişmeden çizim canlı yola düşer ve önizleme oyunun
    // gördüğünden başka bir şeyi ölçer.
    //
    // `runAsync` ŞART. `ensureBaked` future'ı statikte önbellekleniyor ve her
    // `testWidgets` gövdesi kendi sahte zamanlı zone'unda koşuyor: birinci
    // testin zone'unda doğan future, ikinci testte beklendiğinde asla
    // tamamlanmıyor. Ölçüldü — dosya birlikte koştuğunda on dakika asılı
    // kalıyordu, tek tek koştuğunda geçiyordu.
    await tester.runAsync(VoidPortal.ensureBaked);

    const key = ValueKey('gecit-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(
          size: const Size(1200, 800),
          painter: _Onizleme(katman),
        ),
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(key), matchesGoldenFile('gecit_preview.png'));
  });

  testWidgets('Geçit yakın plan · oyuncunun gördüğü ölçek', (tester) async {
    await _loadMono();
    tester.view
      ..physicalSize = const Size(1200, 460)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(VoidPortal.ensureBaked);

    const key = ValueKey('gecit-yakin');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(1200, 460), painter: _Yakin()),
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(key), matchesGoldenFile('gecit_yakin.png'));
  });
}

/// Üç kapı, oyuncunun gördüğü ölçekte: açık PvP, açık boss, kilitli bölge.
///
/// Ekran ~2100 dünya birimi gösteriyor (0,6 yakınlaştırmada görüş çemberinin
/// yaklaşık genişliği); geçit yarıçapı 160, yani kapı ekranın onda biri.
class _Yakin extends CustomPainter {
  const _Yakin();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF03050C),
    );
    // Zemin: portal bir ŞEYİN önünde durmalı, boşlukta duran efekt yüzer.
    final rnd = math.Random(9);
    final yildiz = Paint()..color = const Color(0xFF8FA6C8);
    for (var i = 0; i < 260; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 1.3,
        yildiz
          ..color = const Color(
            0xFF8FA6C8,
          ).withValues(alpha: 0.15 + rnd.nextDouble() * 0.5),
      );
    }

    const olcek = 1200 / 2100.0;
    const durumlar = [
      (Color(0xFFFF4D5E), true, 'PVP'),
      (Color(0xFFFFC247), true, 'BOSS'),
      (Color(0xFF5A6675), false, 'KIRIK HALKA'),
    ];
    for (var i = 0; i < durumlar.length; i++) {
      final (renk, acik, ad) = durumlar[i];
      canvas.save();
      canvas.translate(size.width * (i + 0.5) / 3, size.height * 0.46);
      canvas.scale(olcek);
      VoidPortal.render(
        canvas,
        radius: GecitAgi.yaricap,
        // Kareler farklı fazda: tek bir anın değil HAREKETİN örneği.
        time: 1.4 + i * 2.2,
        renk: renk,
        acik: acik,
      );
      canvas.restore();
      final painter = TextPainter(
        text: TextSpan(
          text: acik ? ad : '$ad\n+2.481 BR',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: (acik ? const Color(0xFFDCE8F5) : const Color(0xFF5A6675))
                .withValues(alpha: 0.9),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          size.width * (i + 0.5) / 3 - painter.width / 2,
          size.height * 0.46 + GecitAgi.yaricap * 1.35 * olcek,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Onizleme extends CustomPainter {
  const _Onizleme(this.katman);

  final GecitKatmani katman;

  @override
  void paint(Canvas canvas, Size size) {
    final dunya = Harita.baslangic.dunya;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF03050C),
    );
    canvas.save();
    // Dünyayı ekrana sığdır — kapılar arası mesafe ancak böyle görünüyor.
    final olcek = size.width / dunya.width;
    canvas.scale(olcek);
    // Harita kenarı: kapıların gerçekten kenarda olduğu görünsün.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, dunya.width, dunya.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = const Color(0x334FE3FF),
    );
    katman.render(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
