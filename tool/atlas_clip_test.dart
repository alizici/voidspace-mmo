import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/ship_atlas.dart';

/// Pişmiş atlasta kırpma var mı — ÜRÜNE bakarak.
///
/// `atlas_bounds_test.dart` kaynağı ölçer: çizim hücreye sığıyor mu. Ama o
/// ölçüm, sondanın pişirmeyle aynı ölçeği kullanmasına bağlı; bir birim hatası
/// (tasarım birimi ↔ dünya birimi) testi yeşil bırakırken atlası kırptırabilir.
/// Bu test o sınıfın tamamını kapatıyor: hücre kenarında saydam olmayan tek bir
/// piksel varsa, orada içerik kesilmiştir — nasıl olduğu fark etmez.
///
/// Belirti: gemi görünmez dikdörtgen bir alana hapsedilmiş gibi görünür,
/// koronanın ve plumanın soluk kuyrukları düz bir kenarla biter.
void main() {
  testWidgets('atlas hücre kenarlarında kesilmiş içerik yok', (tester) async {
    late final Uint8List alpha;
    late final int width;

    await tester.runAsync(() async {
      final data = await rootBundle.load(ShipAtlas.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      width = image.width;
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      final bytes = raw!.buffer.asUint8List();
      alpha = Uint8List(bytes.length ~/ 4);
      for (var i = 0; i < alpha.length; i++) {
        alpha[i] = bytes[i * 4 + 3];
      }
    });

    int at(int x, int y) => alpha[y * width + x];

    void checkBlock(String name, int count, Rect Function(int) frameOf) {
      var worst = 0;
      var worstFrame = -1;
      for (var i = 0; i < count; i++) {
        final f = frameOf(i);
        final l = f.left.round();
        final t = f.top.round();
        final r = f.right.round() - 1;
        final b = f.bottom.round() - 1;
        var m = 0;
        for (var x = l; x <= r; x++) {
          m = m > at(x, t) ? m : at(x, t);
          m = m > at(x, b) ? m : at(x, b);
        }
        for (var y = t; y <= b; y++) {
          m = m > at(l, y) ? m : at(l, y);
          m = m > at(r, y) ? m : at(r, y);
        }
        if (m > worst) {
          worst = m;
          worstFrame = i;
        }
      }
      expect(
        worst,
        0,
        reason:
            '$name: kare $worstFrame hücre kenarına değiyor (alfa $worst/255) '
            '→ içerik KESİLMİŞ.\n'
            'Hücreyi büyüt (AtlasLayout) ve atlası yeniden pişir:\n'
            '  flutter test --update-goldens tool/ship_atlas_test.dart',
      );
    }

    checkBlock(
      'motor',
      AtlasLayout.engineCount,
      (i) => AtlasLayout.engineFrame(
        i % AtlasLayout.engineThrustSteps,
        i ~/ AtlasLayout.engineThrustSteps,
      ),
    );
    checkBlock(
      'gövde',
      AtlasLayout.hullCount,
      (i) => AtlasLayout.hullFrame(
        i % AtlasLayout.hullThrustSteps,
        i ~/ AtlasLayout.hullThrustSteps,
      ),
    );
    checkBlock(
      'kalkan',
      AtlasLayout.shieldCount,
      (i) => AtlasLayout.shieldFrame(
        i % AtlasLayout.shieldStrengthSteps,
        i ~/ AtlasLayout.shieldStrengthSteps,
      ),
    );
    checkBlock('alien', AtlasLayout.alienLayers, AtlasLayout.alienFrame);
  });
}
