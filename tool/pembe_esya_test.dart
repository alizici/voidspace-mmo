@Tags(['disi'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/dil/dil_kapsami.dart';
import 'package:voidspace3/hangar/esya_karti.dart';
import 'package:voidspace3/hangar/item_sheet.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// EN ÜST RANK, EN ÇOK ALT STAT — pencerenin en dolu hâli.
///
/// **Neden ayrı bir referans.** Alt stat kapasitesi ranktan çıkıyor
/// ([ItemBudget.altStatSayisi]): C ailesi bir tane taşıyor, kapak taşları
/// (KIRMIZI · PARLAYAN PEMBE) YEDİ. Menü referanslarının tamamı C ve B
/// rankındaki fixture parçalarıyla çiziliyor, yani pencerenin en dolu hâli
/// hiçbir yerde görünmüyordu — ve pencerede alt statlar tek tek satır
/// açıyor. Yedi satırın nereye gittiği ölçülmeden bilinmiyor.
/// GERÇEK tek aralıklı yazı tipi.
///
/// Ahem'de her harf bir em kare: metin gerçekte olduğundan çok daha geniş
/// çıkıyor ve düzen testte taşarken uygulamada taşmıyor. Ölçülen şey düzense,
/// yazı tipi de gerçek olmalı.
Future<void> _monoYukle() async {
  for (final yol in const [
    '/System/Library/Fonts/Monaco.ttf',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
  ]) {
    final dosya = File(yol);
    if (!dosya.existsSync()) continue;
    final loader = FontLoader('monospace')
      ..addFont(Future.value(dosya.readAsBytesSync().buffer.asByteData()));
    await loader.load();
    return;
  }
}

void main() {
  final pembe = ItemTier.values.last;
  final spec = Catalogue.items.firstWhere(
    (s) => s.tier == pembe && s.slot == SlotType.laser,
  );

  /// Havuzun TAMAMI basılmış bir örnek: kapasite ne veriyorsa o.
  final ornek = ItemInstance(
    instanceId: 'pembe',
    specId: spec.id,
    level: ItemLevels.max,
    altStatRolleri: {for (final s in spec.subStatPool) s: 0.92},
  );

  Widget pencere(Size boy) => MediaQuery(
    data: MediaQueryData(size: boy),
    child: DilKapsami(
      dil: Dil.turkce,
      degistir: (_) {},
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: Stack(
            children: [
              ItemSheet(
                spec: spec,
                instance: ornek,
                hull: HullClass.all.last,
                metrics: MenuMetrics(boy),
                malzemeStogu: 999,
                ceviriciStogu: 3,
                onClose: () {},
                eylemEtiketi: 'TAK',
                onEylem: () {},
                onYukselt: () {},
                onCevir: () {},
                onParcala: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );

  for (final (ad, boy) in [
    ('telefon', const Size(844, 390)),
    ('masaustu', const Size(1280, 720)),
  ]) {
    testWidgets('pembe eşya · $ad', (tester) async {
      await _monoYukle();
      await tester.binding.setSurfaceSize(boy);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(pencere(boy));
      await tester.pump();

      // YEDİ alt stat da ÇİZİLİYOR.
      //
      // Kırılırsa: kapak taşı bir eşyanın taşıdığı derinliğin bir kısmı
      // pencerede hiç görünmüyor demektir — oyuncunun ödediği şeyin bir
      // kısmı gizli kalır.
      final altStatlar = LoadoutResolver.altStatlariFor(
        ornek,
        spec,
        HullClass.all.last,
      );
      expect(
        altStatlar,
        hasLength(ItemBudget.altStatSayisi(pembe)),
        reason: 'kapak taşı yedi alt stat taşımalı',
      );
      for (final id in altStatlar.keys) {
        expect(
          find.text(Catalogue.labelOf(id)),
          findsOneWidget,
          reason: '$id satırı pencerede yok',
        );
      }

      // PENCERE EKRANIN İÇİNDE ve ORTALI.
      //
      // Kenar payı pencerenin kendi `margin`'iydi: `Center` çocuğa ekran
      // yüksekliği kadar yer veriyor, çocuk o kadar uzuyor, sonra payını
      // ONUN ÜSTÜNE ekliyordu. Toplam ekranı aşınca ortalama pencereyi
      // yukarıdan da aşağıdan da dışarı taşırıyordu — telefonda kartın üstü
      // kesiliyordu. Pay dışarı alındı; bu test onu orada tutuyor.
      final kutu = tester.getRect(find.byType(RankYuzeyi).first);
      expect(
        kutu.top,
        greaterThanOrEqualTo(0),
        reason: 'pencere ÜSTTEN taşıyor',
      );
      expect(
        kutu.bottom,
        lessThanOrEqualTo(boy.height),
        reason: 'pencere ALTTAN taşıyor',
      );
      expect(
        (kutu.center.dy - boy.height / 2).abs(),
        lessThan(2),
        reason: 'pencere dikeyde ortalanmamış',
      );

      await expectLater(
        find.byType(ItemSheet),
        matchesGoldenFile('pembe_esya_$ad.png'),
      );
    });
  }
}
