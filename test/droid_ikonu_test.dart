@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/dil/icerik.dart';
import 'package:voidspace3/game/art/droid_art.dart';
import 'package:voidspace3/hangar/droid_ikonu.dart';
import 'package:voidspace3/hangar/item_glyph.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace3/hangar/rank_kutusu.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// DROİDİN RESMİ — mağaza kartında ve envanter hücresinde (05.8 s2).
///
/// Droid, statıyla değil GÖRÜNÜŞÜYLE tanınan tek eşya: on tasarım aynı statı
/// veriyor ve oyuncunun ayırt edebildiği tek şey resim. Buradaki testlerin
/// koruduğu şey o — hem resmin doğru tasarımdan geldiği, hem de eşyanın
/// stat glifine geri düşmediği.
void main() {
  const m = MenuMetrics(Size(1200, 700));

  ItemSpec droidSpec() => Catalogue.items.firstWhere(
    (s) => s.slot == SlotType.droid,
  );

  test('katalogdaki HER droid bir tasarım taşıyor', () {
    // Kırılırsa: mağazada resimsiz bir droid kartı çıkar. Şemanın `variant`
    // alanı boş kalırsa eşleme ilk tasarıma düşer ve iki ayrı droid aynı
    // resimle görünür.
    final droidler = Catalogue.items.where((s) => s.slot == SlotType.droid);
    expect(droidler, isNotEmpty, reason: 'katalogda hiç droid yok');
    for (final spec in droidler) {
      expect(spec.variant, isNotNull, reason: '${spec.id} tasarımsız');
      expect(
        DroidCizimi.values.map((c) => c.name),
        contains(spec.variant),
        reason: '${spec.id} tanınmayan tasarım taşıyor: ${spec.variant}',
      );
    }
  });

  test('çekirdeğin ve sanatın tasarım ADLARI aynı', () {
    // İki ayrı numaralandırma var: `DroidModeli` (çekirdek) ve `DroidCizimi`
    // (sanat). Eşleme AD üzerinden yapılıyor; adlar ayrışırsa her droid
    // sessizce ilk tasarıma düşer ve filo tek tip görünür.
    expect(
      DroidCizimi.values.map((c) => c.name).toSet(),
      DroidModeli.values.map((m) => m.name).toSet(),
    );
  });

  test('örneğin SEÇTİĞİ tasarım şemayı eziyor', () {
    // Oyuncu droidinin görünüşünü değiştirebiliyor; envanterde görmesi
    // gereken şey satın aldığı şema değil elindeki droid.
    final spec = droidSpec();
    const item = ItemInstance(
      instanceId: 'x',
      specId: 'y',
      tasarim: 'jiroskop',
    );
    expect(droidCizimiOf(spec, item), DroidCizimi.jiroskop);
    expect(droidCizimiOf(spec, null), droidCizimiAdiyla(spec.variant));
  });

  test('droid OLMAYAN eşyada resim yok', () {
    final lazer = Catalogue.items.firstWhere(
      (s) => s.slot == SlotType.laser,
    );
    expect(droidCizimiOf(lazer, null), isNull);
    expect(droidCizimiOf(null, null), isNull);
  });

  test('tanınmayan ad ilk tasarıma düşüyor — kart boş kalmıyor', () {
    expect(droidCizimiAdiyla('boyle-bir-tasarim-yok'), isNotNull);
    expect(droidCizimiAdiyla(null), isNotNull);
  });

  testWidgets('hücrede droid RESMİ çiziliyor, stat glifi değil', (
    tester,
  ) async {
    // Kırılırsa: envanterdeki her droid ROKETATAR işareti alır. Glif ana
    // stattan türüyor ve droidin ana statı `hasar_artisi` — yani doğru
    // çalışan bir glif burada yanlış cevabı veriyor.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SlotTile(
          color: Color(0xFF88AAFF),
          metrics: m,
          glyph: ItemGlyph.launcher,
          droid: DroidCizimi.hilal,
        ),
      ),
    );

    final kutu = tester.widget<RankKutusu>(find.byType(RankKutusu));
    expect(
      kutu.isaret,
      isA<DroidIsareti>().having((i) => i.model, 'model', DroidCizimi.hilal),
      reason: 'droid varken glif kazandı',
    );
  });

  testWidgets('droid olmayan hücre glifini KORUYOR', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SlotTile(
          color: Color(0xFF88AAFF),
          metrics: m,
          glyph: ItemGlyph.laser,
        ),
      ),
    );
    final kutu = tester.widget<RankKutusu>(find.byType(RankKutusu));
    expect(kutu.isaret, isA<EsyaIsareti>());
  });

  testWidgets('boş hücrede işaret YOK', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SlotTile(color: Color(0xFF88AAFF), metrics: m),
      ),
    );
    expect(tester.widget<RankKutusu>(find.byType(RankKutusu)).isaret, isNull);
  });

  testWidgets('ikon her tasarımı ÇİZİYOR — hiçbiri çökmüyor', (tester) async {
    // On tasarımın onu da aynı boyacıdan geçiyor; biri bir kenar durumda
    // (sıfır boy, tanınmayan model) atarsa mağaza ızgarası komple boş çıkar.
    for (final model in DroidCizimi.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: DroidIkonu(model: model, boy: DroidIkonu.magazaBoyu),
          ),
        ),
      );
      expect(find.byType(DroidIkonu), findsOneWidget, reason: model.name);
    }
  });

  // KARAR 05.8 s2
  testWidgets('hücrede RESİM ile AD aynı tasarımı gösteriyor', (tester) async {
    // Tutarsızlığın yaşandığı yer tam olarak burası: aynı widget'ta
    // `droidCizimiOf(spec, item)` ile `esyaAdi(spec, dil)` yan yana
    // duruyordu ve ikisi ayrı kural okuyordu. Sınama ikisini BİRLİKTE
    // soruyor — ayrı ayrı doğru olup birlikte yanlış olabildikleri için.
    const spec = Catalogue.dr1;
    for (final model in DroidModeli.merdiven) {
      final item = ItemInstance(
        instanceId: 'd',
        specId: spec.id,
        tasarim: model.name,
      );
      final cizim = droidCizimiOf(spec, item);
      final ad = esyaAdi(spec, Dil.turkce, item: item);
      expect(
        cizim,
        droidCizimiAdiyla(model.name),
        reason: '${model.name}: çizim tasarımı izlemiyor',
      );
      expect(
        ad,
        contains(droidTasarimAdi(model.name, Dil.turkce, yedek: '')),
        reason: '${model.name}: ad tasarımı izlemiyor',
      );
    }
  });
}
