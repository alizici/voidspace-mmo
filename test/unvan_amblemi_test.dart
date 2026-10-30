@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/rank_plakasi.dart';
import 'package:voidspace3/hangar/unvan_amblemi.dart';
import 'package:voidspace3/hangar/unvan_karti.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// UNVAN AMBLEMİ VE PİLOT KARTI — 10.4 s2.
///
/// Ölçülen: satırdaki amblem sunucunun yolladığı İNDEKSTEN geliyor (addan
/// geri çözülmüyor), kart doğru çağı ve sıradaki eşiği yazıyor, merdiven
/// yirmi adın tamamını taşıyor ve tavanda "sonraki" yok.
void main() {
  NetClient istemci({required int unvan, double br = 4200}) {
    final hangar = Hangar(
      accountId: 'a',
      credits: 1200,
      hulls: [HullClass.starter.id],
      activeHullId: HullClass.starter.id,
    );
    return NetClient(uri: Uri.parse('ws://test'))
      ..hangar = HangarView.fromJson({
        ...hangar.toJson(),
        'effective': ServerHangarState.effectiveOf(ShipStats.bastion),
        'br': br,
        'seviye': 7,
        'unvan': unvan,
        'unvanAdi': Unvan.adi(unvan),
      });
  }

  Future<void> ac(WidgetTester tester, NetClient c) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HangarScreen(client: c, onClose: () {})),
    );
    await tester.pump();
  }

  // KARAR 10.4 s2
  testWidgets('satırdaki amblem sunucunun indeksinden: ad ve kademe', (
    tester,
  ) async {
    // 33 = altıncı adın (Acolyte) dördüncü kademesi.
    await ac(tester, istemci(unvan: 33));
    final ikon = tester.widget<UnvanIkonu>(
      find.descendant(
        of: find.byKey(hangarUnvanKey),
        matching: find.byType(UnvanIkonu),
      ),
    );
    expect(ikon.unvanIndeksi, 5);
    expect(ikon.kademe, 3);
    expect(Unvan.adlar[ikon.unvanIndeksi], 'Acolyte');
  });

  // KARAR 10.4 s2
  testWidgets('unvan satırına dokununca pilot kartı açılıyor', (tester) async {
    await ac(tester, istemci(unvan: 33));
    expect(find.byKey(unvanKartiKey), findsNothing);

    await tester.tap(find.byKey(hangarUnvanKey));
    await tester.pump();

    expect(find.byKey(unvanKartiKey), findsOneWidget);
    // Ad kartın İÇİNDE aranıyor: satırdaki ad da aynı yazı, ikisi birden
    // bulunuyor ve bu doğru — kart satırın büyütülmüş hâli.
    expect(
      find.descendant(
        of: find.byKey(unvanKartiKey),
        matching: find.text('ACOLYTE IV'),
      ),
      findsOneWidget,
    );
    expect(find.text('KUTSALLIK ÇAĞI · KADEME IV / VI'), findsOneWidget);
    // Sıradaki ad ve onun eşiği — ikisi de 10.3'ün fonksiyonundan.
    expect(find.text('SONRAKİ · ACOLYTE V'), findsOneWidget);

    // Merdiven yirmi adın hepsini taşıyor: geçilenler de, kalanlar da.
    for (var i = 0; i < Unvan.adlar.length; i++) {
      expect(find.byKey(unvanMerdiveniKey(i)), findsOneWidget, reason: '$i');
    }

    await tester.tap(find.byKey(unvanKartiKapatKey));
    await tester.pump();
    expect(find.byKey(unvanKartiKey), findsNothing);
  });

  // KARAR 10.4 s2
  testWidgets('tavandaki unvanda sıradaki eşik YOK', (tester) async {
    final tepe = TasarimGirdileri.unvanSayisi - 1;
    await ac(tester, istemci(unvan: tepe, br: CombatGlossary.brTavani));
    await tester.tap(find.byKey(hangarUnvanKey));
    await tester.pump();

    expect(find.textContaining('MERDİVENİN TEPESİ'), findsOneWidget);
    expect(find.textContaining('SONRAKİ'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(unvanKartiKey),
        matching: find.text('STAR LORD VI'),
      ),
      findsOneWidget,
    );
  });

  // KARAR 10.4 s2
  testWidgets('amblem rengi eşya merdiveninin aynı basamağından', (
    tester,
  ) async {
    // Unvan ve eşya rankı aynı merdivenin basamakları: ikisine iki ayrı
    // palet vermek oyuncuya iki renk dili öğretmek olurdu.
    for (final i in [0, 7, 19]) {
      expect(
        UnvanPaleti.of(i).taban,
        RankGorseli.of(ItemTier.values[i]).taban,
        reason: 'unvan $i rengi merdivenden ayrışmış',
      );
    }
  });
}
