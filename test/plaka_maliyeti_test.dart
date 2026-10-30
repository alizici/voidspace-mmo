@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace3/hangar/plaka_onbellegi.dart';
import 'package:voidspace3/hangar/rank_plakasi.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// PLAKANIN KARE BAŞINA MALİYETİ.
///
/// Hangar telefonda kasıyordu ve sebebi ölçüldü: yörünge noktaları döndükçe
/// plakanın TAMAMI yeniden çiziliyordu — gradyanlı zemin, kenarlık, kademe
/// şeridi, işaret — ve bunların içinde kare başına 5 ile 9 arasında
/// `MaskFilter.blur` vardı. Blur, kare içinde ödenebilecek en pahalı
/// çağrılardan biri.
///
/// Buradaki testler o kazancı KİLİTLİYOR. Kırılırlarsa kasma geri gelmiş
/// demektir — ve o kasma bir sonraki sefer de aylarca "telefonda takılıyor"
/// diye bulanık bir şikâyet olarak görünecektir.
void main() {
  test('DÖNEN katmanda blur YOK ve çizim sayısı nokta başına iki', () {
    for (final g in RankGorseli.hepsi) {
      final n = g.yorungeNoktasi;
      if (n == 0) continue;
      final c = SayanCanvas();
      RankPlakasi.yorunge(c, 56, g, 0.3);
      expect(
        c.blur,
        0,
        reason: '${g.tier.label} yörüngesinde blur var: hale pişmiyor',
      );
      expect(
        c.toplam,
        n * 2,
        reason: '${g.tier.label} · nokta başına bir hale bir çekirdek',
      );
    }
  });

  test('DURAN katman zemini TEK çizimle koyuyor', () {
    // Zemin pişmiş bir doku: kare başına iş, bir doku kopyası. Eskiden aynı
    // yerde gradyanlı dolgu, kenarlık ve köşe kolları vardı.
    final c = SayanCanvas();
    PlakaOnbellegi.zemin(
      c,
      56,
      RankGorseli.hepsi.last,
      detay: true,
      oran: 1,
    );
    expect(c.sayac['drawImageRect'], 1);
    expect(c.blur, 0, reason: 'pişmiş zeminde blur olamaz');
  });

  testWidgets('yörüngesiz rank için katman sınırı AÇILMIYOR', (tester) async {
    // `RepaintBoundary` bedava değil. Kıpırdamayan bir hücreye sınır koymak,
    // çözdüğü sorundan pahalıya mal olurdu.
    Future<int> sinirSayisi(ItemTier rank) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SlotTile(
            color: const Color(0xFF88AAFF),
            metrics: const MenuMetrics(Size(1200, 700)),
            rank: rank,
          ),
        ),
      );
      return tester.widgetList(find.byType(RepaintBoundary)).length;
    }

    final durgun = RankGorseli.hepsi.firstWhere((g) => g.yorungeNoktasi == 0);
    final donen = RankGorseli.hepsi.firstWhere((g) => g.yorungeNoktasi > 0);
    expect(
      await sinirSayisi(donen.tier),
      greaterThan(await sinirSayisi(durgun.tier)),
      reason: 'dönen hücre kendi katmanına ayrılmıyor',
    );
  });
}

/// Çizim çağrılarını SAYAN sahte tuval.
///
/// `Canvas` bir arayüz değil ama Dart her sınıfı `implements` etmeye izin
/// veriyor; `noSuchMethod` ile `draw*` çağrıları sayılıyor. Ölçülen şey
/// rasterleştirme değil KAYIT — ama blur'un bedeli kaç kez kaydedildiğiyle
/// doğru orantılı, ve sayının kendisi kesin.
class SayanCanvas implements Canvas {
  final Map<String, int> sayac = {};
  int blur = 0;

  int get toplam => sayac.values.fold(0, (a, b) => a + b);

  @override
  dynamic noSuchMethod(Invocation i) {
    final ad = i.memberName.toString().replaceAll(RegExp(r'Symbol\("|"\)'), '');
    if (!ad.startsWith('draw')) return null;
    sayac[ad] = (sayac[ad] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blur++;
    }
    return null;
  }
}
