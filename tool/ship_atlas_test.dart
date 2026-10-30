import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/govde_tasarimlari.dart';
import 'package:voidspace3/game/art/shield_shell.dart';
import 'package:voidspace3/game/art/void_spore.dart';

/// Gemi atlasının KAYNAĞI.
///
/// `assets/ship_atlas.png` buradan üretilir — tıpkı `app_icon.png` gibi.
/// Depoda kökeni bilinmeyen tek bir ikili dosya yok kuralı bozulmuyor:
/// prosedürel sanat hâlâ tek gerçek, ama artık bir ÇİZİCİ değil bir DOKU
/// ÜRETİCİSİ.
///
/// Neden çalışma zamanında pişirilmiyor: pişirme, kare başına 8 ms'lik
/// bloom geçişini yüzden fazla kare için tekrarlamak demek — telefonda
/// saniyelerce süren bir donma. Derleme zamanında bir kez ödeniyor.
///
/// Yenilemek için:
/// ```bash
/// flutter test --update-goldens tool/ship_atlas_test.dart
/// ```
void main() {
  testWidgets('gemi atlası', (tester) async {
    // Silüetler diskten geliyor ve kod çözme GERÇEK asenkron iş: sahte zaman
    // bölgesinde hiç bitmez, blok boş pişerdi.
    final siluetler = <int, ui.Image>{};
    await tester.runAsync(() async {
      for (final t in GovdeTasarimlari.hepsi) {
        if (t.cizildi) continue;
        final veri = await rootBundle.load(t.ikon);
        final codec = await ui.instantiateImageCodec(
          veri.buffer.asUint8List(),
        );
        siluetler[t.kademe] = (await codec.getNextFrame()).image;
        codec.dispose();
      }
    });

    final size = AtlasLayout.imageSize;
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('ship-atlas');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(size: size, painter: _AtlasPainter(siluetler)),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('../assets/ship_atlas.png'),
    );
  });
}

class _AtlasPainter extends CustomPainter {
  const _AtlasPainter(this.siluetler);

  /// Kademe → önizleme görüntüsü. Tepe kademe YOK: onun gövdesi canlı.
  final Map<int, ui.Image> siluetler;

  @override
  void paint(Canvas canvas, Size size) {
    _block(
      canvas,
      count: AtlasLayout.engineCount,
      steps: AtlasLayout.engineThrustSteps,
      anchor: AtlasLayout.engineAnchor,
      frame: (s, p) => AtlasLayout.engineFrame(s, p),
      draw: (c, value, time) {
        c
          ..scale(AtlasLayout.pixelsPerWorldUnit * AtlasLayout.designScale)
          ..translate(0, Bastion.centreOffset);
        Bastion.paintEngine(c, time: time, thrust: value);
      },
    );

    _block(
      canvas,
      count: AtlasLayout.hullCount,
      steps: AtlasLayout.hullThrustSteps,
      anchor: AtlasLayout.hullAnchor,
      frame: (s, p) => AtlasLayout.hullFrame(s, p),
      draw: (c, value, time) {
        c
          ..scale(AtlasLayout.pixelsPerWorldUnit * AtlasLayout.designScale)
          ..translate(0, Bastion.centreOffset);
        Bastion.paintHull(c, time: time, thrust: value);
      },
    );

    _block(
      canvas,
      count: AtlasLayout.shieldCount,
      steps: AtlasLayout.shieldStrengthSteps,
      anchor: AtlasLayout.shieldAnchor,
      frame: (s, p) => AtlasLayout.shieldFrame(s, p),
      draw: (c, value, time) {
        c.scale(AtlasLayout.pixelsPerWorldUnit);
        ShieldShell.paint(
          c,
          radius: AtlasLayout.shieldRadiusWorld,
          strength: value,
          time: time,
        );
      },
    );

    // Silah yuvaları: her kaide KENDİ hücresine, gövdeden ayrı.
    //
    // Gövde bloğuyla aynı faz sayısını kullanıyor ve aynı zamanları
    // pişiriyor: ikisi çizim anında tek bir tikten faz seçiyor, ayrışırlarsa
    // projektörün nabzı gövdeninkinden kayar.
    _block(
      canvas,
      count: AtlasLayout.emitterCount,
      steps: AtlasLayout.emitterMounts,
      anchor: AtlasLayout.emitterAnchor,
      frame: (s, p) => AtlasLayout.emitterFrame(s, p),
      draw: (c, value, time) {
        c.scale(AtlasLayout.pixelsPerWorldUnit * AtlasLayout.designScale);
        // `value` = kaide indeksi / (kaide-1). `_block` kademeyi 0..1
        // aralığına normalliyor; burada istenen ham indeks.
        Bastion.paintEmitter(
          c,
          index: (value * (AtlasLayout.emitterMounts - 1)).round(),
          time: time,
        );
      },
    );

    // Alien katmanları: faz yok, tek sıra. Dönüş ve nabız çizim anında
    // `RSTransform` ile geliyor (bkz. `AlienSwarm`).
    _block(
      canvas,
      count: AtlasLayout.alienLayers,
      steps: AtlasLayout.alienLayers,
      anchor: AtlasLayout.alienAnchor,
      frame: (s, p) => AtlasLayout.alienFrame(s),
      draw: (c, value, time) {
        c.scale(AtlasLayout.pixelsPerWorldUnit);
        const r = AtlasLayout.alienRadiusWorld;
        // `value` = katman indeksi / (katman-1) → 0, ⅓, ⅔, 1.
        switch ((value * (AtlasLayout.alienLayers - 1)).round()) {
          case 0:
            VoidSpore.paintHalo(c, r, VoidSpore.notr);
          case 1:
            VoidSpore.paintShell(c, r, VoidSpore.notr);
          case 2:
            VoidSpore.paintDetail(c, r, VoidSpore.notr);
          case 3:
            VoidSpore.paintCore(c, r, VoidSpore.notr);
          default:
            VoidSpore.paintCoreHot(c, r, VoidSpore.notr);
        }
      },
    );

    _siluetler(canvas);
  }

  /// GÖVDE SİLÜETLERİ — yedi hareketsiz tasarım, tasarım başına tek kare.
  ///
  /// Ölçek NORMALİZE: her tasarımın kendi erişimi farklı (36 ile 72 arası) ama
  /// ekranda hepsi aynı boyda durmak zorunda. Çarpan
  /// [GovdeTasarimlari.olcekFor]'dan geliyor ve tepe tasarımı çapa alıyor —
  /// yani silüetler canlı gövde bloğunun piştiği ölçüyle AYNI hücreye oturuyor.
  ///
  /// `translate` YOK ve olmamalı: canlı blok gövdeyi `centreOffset` kadar
  /// kaydırıyor çünkü tasarım uzayında burnu −y'de uzakta. PNG'ler ise ZATEN
  /// ortalanmış — kadrajları geminin görünür kutusuna göre kesilmiş. İkinci
  /// bir kaydırma onları hücrede yukarı iterdi.
  void _siluetler(Canvas canvas) {
    for (final t in GovdeTasarimlari.hepsi) {
      final resim = siluetler[t.kademe];
      if (resim == null) continue;
      final rect = AtlasLayout.siluetFrame(t.kademe);
      final kenar =
          GovdeTasarimlari.ikonKutusuFor(t) *
          GovdeTasarimlari.olcekFor(t) *
          AtlasLayout.designScale *
          AtlasLayout.pixelsPerWorldUnit;
      canvas
        ..save()
        ..clipRect(rect)
        ..translate(
          rect.left + AtlasLayout.hullAnchor.dx,
          rect.top + AtlasLayout.hullAnchor.dy,
        )
        ..drawImageRect(
          resim,
          Rect.fromLTWH(
            0,
            0,
            resim.width.toDouble(),
            resim.height.toDouble(),
          ),
          Rect.fromCenter(
            center: Offset.zero,
            width: kenar,
            height: kenar,
          ),
          Paint()..filterQuality = FilterQuality.medium,
        )
        ..restore();
    }
  }

  /// Bir bloğun bütün karelerini çizer.
  ///
  /// Her hücre KIRPILIR: ölçülen sınırlara pay eklendi ama bir gün sanat
  /// büyürse taşma komşu kareye sızar ve hata, oyunda "geminin yanında bir
  /// leke" olarak görünür — kaynağı bulunması en zor türden.
  void _block(
    Canvas canvas, {
    required int count,
    required int steps,
    required Offset anchor,
    required Rect Function(int step, int phase) frame,
    required void Function(Canvas canvas, double value, double time) draw,
  }) {
    for (var i = 0; i < count; i++) {
      final step = i % steps;
      final phase = i ~/ steps;
      final rect = frame(step, phase);
      canvas
        ..save()
        ..clipRect(rect)
        ..translate(rect.left + anchor.dx, rect.top + anchor.dy);
      draw(
        canvas,
        steps == 1 ? 1.0 : step / (steps - 1),
        AtlasLayout.baseTime + phase * AtlasLayout.phaseStep,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AtlasPainter oldDelegate) => false;
}
