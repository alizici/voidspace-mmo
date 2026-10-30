import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/laser_bolt.dart';
import 'package:voidspace3/game/art/shield_shell.dart';
import 'package:voidspace3/game/components/combat_layer.dart';

/// Görsel referans: PL-4 mermisi, kalkan darbesi ve tam bir yaylım.
///
/// Canlı ekrandan yakalanamayan şeyi yakalar. Mermi menzilin ortasında 0.3
/// saniye uçuyor ve yaylım 1.1 saniyede bir çıkıyor — tarayıcıdan alınan
/// rastgele bir kare çoğu zaman boş uzay gösteriyor. Burada zaman SABİT
/// adımlarla ilerletiliyor, yani kare seçilebiliyor.
///
/// Hasar sayısı bilerek YOK: `flutter test` yazı tipi olarak kutu glifleri
/// kullanıyor, sayı goldende siyah dikdörtgen olarak çıkardı. Onun doğrulaması
/// `test/combat_layer_test.dart` ve canlı ekran.
void main() {
  testWidgets('Savaş görsel referansı', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('combat-preview');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(1200, 900), painter: _PreviewPainter()),
      ),
    );
    await tester.pump();

    await expectLater(find.byKey(key), matchesGoldenFile('combat_preview.png'));
  });
}

/// Kalkan darbesinin gösterilen anları (ömrün oranı).
const _impactStages = [0.1, 0.3, 0.55, 0.8];

const _rowA = 190.0;
const _rowB = 520.0;

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071018), Color(0xFF03050C)],
        ).createShader(Offset.zero & size),
    );

    _bolts(canvas, size);
    _rule(canvas, size, _rowA);
    _shieldImpacts(canvas, size);
    _rule(canvas, size, _rowB);
    _volley(canvas, size);
  }

  /// 1 · PL-4 mermisi — dört kat büyütülmüş, üç titreşim anı.
  void _bolts(Canvas canvas, Size size) {
    final art = BoltArt.pl4;
    const ages = [0.0, 0.035, 0.07];
    for (var i = 0; i < ages.length; i++) {
      canvas
        ..save()
        ..translate(size.width * (i + 0.5) / ages.length, _rowA * 0.5)
        ..scale(4)
        ..rotate(-0.35);
      art.render(canvas, ages[i]);
      canvas.restore();
    }
  }

  /// 2 · Kalkan darbesi — dört aşama, gerçek gövdenin üstünde.
  void _shieldImpacts(Canvas canvas, Size size) {
    final cell = size.width / _impactStages.length;
    // Geliş yönü sol üstten: temas noktası kabuğun o yüzünde.
    const incoming = Offset(-0.74, -0.67);
    for (var i = 0; i < _impactStages.length; i++) {
      canvas
        ..save()
        ..translate(cell * (i + 0.5), (_rowA + _rowB) / 2)
        ..scale(1.55);

      canvas
        ..save()
        ..scale(AtlasLayout.designScale)
        ..translate(0, Bastion.centreOffset);
      Bastion.paint(
        canvas,
        time: 1.1,
        thrust: 0.4,
        lasers: Bastion.hardpoints.length,
      );
      canvas.restore();

      const r = AtlasLayout.shieldRadiusWorld;
      ShieldShell.paint(canvas, radius: r, strength: 0.8, time: 1.1);
      // Tek yaylım = tek darbe (bkz. `CombatLayer._impact`).
      ShieldShell.paintImpacts(
        canvas,
        radius: r,
        strength: 0.8,
        hits: [
          ShieldHit(incoming * r)
            ..age = _impactStages[i] * ShieldShell.impactLife,
        ],
      );
      canvas.restore();
    }
  }

  /// 3 · Tam bir yaylım — gerçek [CombatLayer], sabit adımlarla ilerletilmiş.
  ///
  /// Sahne DÜNYA biriminde kuruluyor: mermiler, namlu ağızları ve kabuk
  /// yarıçapı hep o birimde konuşuyor, ve önizlemenin oyundan farklı bir
  /// ölçekte çizilmesi tam da gözden kaçan hataların doğduğu yer.
  void _volley(Canvas canvas, Size size) {
    const shooter = Offset(150, 0);
    const target = Offset(1010, 0);

    final layer = CombatLayer()
      ..begin()
      // Tam donanımlı bir gemi: beş namlu da ateş etsin, referans yaylımın
      // TAMAMINI göstersin.
      ..track(1, shooter.dx, shooter.dy, 1.5708, 1, Bastion.hardpoints.length)
      ..track(2, target.dx, target.dy, -1.5708)
      // Hasar 0: sayı basılmasın (bkz. dosya başı).
      ..fire(
        shooterId: 1,
        targetId: 2,
        damage: 0,
        shieldHit: true,
        killed: false,
      )
      ..aim(shooter.dx, shooter.dy, 1.5708, Bastion.hardpoints.length)
      ..setLock(target.dx, target.dy);
    // 0.30 sn: uç çifti yolun yarısında, kanat çifti henüz namluda.
    for (var i = 0; i < 18; i++) {
      layer.update(1 / 60);
    }

    canvas
      ..save()
      ..translate(0, _rowB + (900 - _rowB) / 2)
      ..scale(size.width / 1160);

    for (final (at, angle) in [(shooter, 1.5708), (target, -1.5708)]) {
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..save()
        ..rotate(angle)
        ..scale(AtlasLayout.designScale)
        ..translate(0, Bastion.centreOffset);
      Bastion.paint(
        canvas,
        time: 1.1,
        thrust: 0.55,
        lasers: Bastion.hardpoints.length,
      );
      canvas.restore();
      ShieldShell.paint(
        canvas,
        radius: AtlasLayout.shieldRadiusWorld,
        strength: 0.85,
        time: 1.1,
      );
      canvas.restore();
    }

    layer.render(canvas);
    canvas.restore();
  }

  void _rule(Canvas canvas, Size size, double y) => canvas.drawLine(
    Offset(0, y),
    Offset(size.width, y),
    Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0x334FE3FF),
  );

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
