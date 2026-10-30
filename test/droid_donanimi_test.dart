@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/item_sheet.dart';
import 'package:voidspace3/hangar/menu_model.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// DROİD DONANIMI EKRANDA (05.4 s5).
///
/// Droid bir taşıyıcı: penceresi kaç yuvası olduğunu, içinde ne olduğunu ve
/// boş yuvaya ne girebileceğini söylüyor. Lazer penceresi de tersini: bu
/// eşya bir droide takılabilir.
void main() {
  NetClient istemci({
    Map<String, List<String>> donanim = const {},
    String droidSpec = 'dr1',
  }) {
    final hangar = Hangar(
      accountId: 'a',
      credits: 1200,
      hulls: [HullClass.starter.id],
      activeHullId: HullClass.starter.id,
      inventory: {
        'd0': ItemInstance(instanceId: 'd0', specId: droidSpec),
        'lz': const ItemInstance(instanceId: 'lz', specId: 'pl1'),
      },
      filo: ['d0'],
      droidDonanimi: donanim,
    );
    return NetClient(uri: Uri.parse('ws://test'))
      ..hangar = HangarView.fromJson({
        ...hangar.toJson(),
        'effective': ServerHangarState.effectiveOf(ShipStats.bastion),
        'br': 4200.0,
      });
  }

  Future<void> ac(WidgetTester tester, NetClient c) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: c, onClose: () {}),
      ),
    );
    await tester.pump();
  }

  /// Filo kendi SEKMESİNDE: sol bölme sekmeye göre değişiyor.
  Future<void> filoyaDokun(WidgetTester tester) async {
    await tester.tap(find.byKey(paneTabKey(HangarTab.droid)));
    await tester.pump();
    await tester.ensureVisible(find.byKey(filoTileKey(0)));
    await tester.pump();
    // UZUN BASMA: filo hücresinde de tek dokunuş SEÇİYOR, pencere uzun
    // basmada — depo hücresiyle aynı kural.
    await tester.longPress(find.byKey(filoTileKey(0)));
    await tester.pump();
  }

  // KARAR 05.4 s5
  testWidgets('boş droidin penceresi yuvayı ve ne gireceğini yazıyor', (
    tester,
  ) async {
    await ac(tester, istemci());
    await filoyaDokun(tester);

    expect(find.text('DROİD YUVASI · 0/1'), findsOneWidget);
    expect(find.text('BOŞ YUVA · LAZER YA DA JENERATÖR'), findsOneWidget);
  });

  // KARAR 05.4 s5
  testWidgets('elit droid İKİ yuva gösteriyor', (tester) async {
    await ac(tester, istemci(droidSpec: 'dr5'));
    await filoyaDokun(tester);

    expect(find.text('DROİD YUVASI · 0/2'), findsOneWidget);
    expect(find.text('BOŞ YUVA · LAZER YA DA JENERATÖR'), findsNWidgets(2));
  });

  // KARAR 05.4 s5
  testWidgets('dolu yuva takılanı adıyla ve ÇIKAR düğmesiyle gösteriyor', (
    tester,
  ) async {
    await ac(
      tester,
      istemci(
        donanim: {
          'd0': ['lz'],
        },
      ),
    );
    await filoyaDokun(tester);

    expect(find.text('DROİD YUVASI · 1/1'), findsOneWidget);
    expect(find.byKey(droidCikarKey('lz')), findsOneWidget);
    expect(find.text('BOŞ YUVA · LAZER YA DA JENERATÖR'), findsNothing);
  });
}
