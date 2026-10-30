@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/item_sheet.dart';
import 'package:voidspace3/hangar/menu_model.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// DROİD DAYANIKLILIĞI EKRANDA (05.10).
///
/// Sayaç sunucudan geliyor, istemci hesaplamıyor. Ölçülen: filo hücresinde
/// aşınan droidin şeridi çıkıyor, tam olanınki çıkmıyor; bilgi penceresi
/// sayacı ve NOVA bedelini yazıyor, ONAR düğmesi NOVA yetmiyorsa ölü.
void main() {
  NetClient istemci({required int dayaniklilik, int premium = 100000}) {
    final hangar = Hangar(
      accountId: 'a',
      credits: 1200,
      premium: premium,
      hulls: [HullClass.starter.id],
      activeHullId: HullClass.starter.id,
      inventory: {
        'd0': ItemInstance(
          instanceId: 'd0',
          specId: 'dr1',
          dayaniklilik: dayaniklilik,
        ),
      },
      filo: ['d0'],
    );
    return NetClient(uri: Uri.parse('ws://test'))
      ..hangar = HangarView.fromJson({
        ...hangar.toJson(),
        'effective': ServerHangarState.effectiveOf(ShipStats.bastion),
        'br': 4200.0,
      });
  }

  /// Filo artık kendi SEKMESİNDE: sol bölme sekmeye göre değişiyor ve droid
  /// filosu DROİD sekmesinde. Bir zamanlar donanım sütununun en altındaydı;
  /// o düzende dokunmadan önce yalnız kaydırmak yetiyordu.
  Future<void> droidSekmesi(WidgetTester tester) async {
    await tester.tap(find.byKey(paneTabKey(HangarTab.droid)));
    await tester.pump();
  }

  Future<void> filoyaDokun(WidgetTester tester) async {
    await droidSekmesi(tester);
    await tester.ensureVisible(find.byKey(filoTileKey(0)));
    await tester.pump();
    // UZUN BASMA: filo hücresinde de tek dokunuş SEÇİYOR, pencere uzun
    // basmada — depo hücresiyle aynı kural.
    await tester.longPress(find.byKey(filoTileKey(0)));
    await tester.pump();
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

  // KARAR 05.10 s1
  testWidgets('filo hücresinde şerit YALNIZ aşınmış droidde', (tester) async {
    await ac(tester, istemci(dayaniklilik: ItemInstance.tamDayaniklilik));
    await droidSekmesi(tester);
    expect(
      tester.widget<EsyaHucresi>(find.byKey(filoTileKey(0))).dayaniklilik,
      ItemInstance.tamDayaniklilik,
    );
    expect(
      find.descendant(
        of: find.byKey(filoTileKey(0)),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
      reason: 'tam sayaçta da şerit çizilmiş',
    );

    await ac(tester, istemci(dayaniklilik: 40));
    final serit = tester.widget<LinearProgressIndicator>(
      find
          .descendant(
            of: find.byKey(filoTileKey(0)),
            matching: find.byType(LinearProgressIndicator),
          )
          .first,
    );
    expect(serit.value, closeTo(0.4, 1e-9));
  });

  // KARAR 05.10 s1
  testWidgets('bilgi penceresi sayacı, kalan ölümü ve bedeli yazıyor', (
    tester,
  ) async {
    await ac(tester, istemci(dayaniklilik: 40));
    await filoyaDokun(tester);

    expect(find.text('DAYANIKLILIK'), findsOneWidget);
    expect(find.text('%40 · 4 ÖLÜM'), findsOneWidget);
    final bedel = Kazanc.droidOnarimNovaFor(ItemTier.cI, puan: 60);
    expect(find.text('${menuNumber(bedel, Dil.turkce)} NOVA'), findsOneWidget);
    expect(find.byKey(itemSheetOnarKey), findsOneWidget);
  });

  // KARAR 15.3 s3
  testWidgets('NOVA yetmiyorsa ONAR düğmesi ÖLÜ, sessiz ret yok', (
    tester,
  ) async {
    await ac(tester, istemci(dayaniklilik: 40, premium: 0));
    await filoyaDokun(tester);
    final dugme = tester.widget<MenuButton>(find.byKey(itemSheetOnarKey));
    expect(dugme.onTap, isNull);
  });

  // KARAR 05.10 s1
  testWidgets('tam sayaçlı droidde ONAR düğmesi YOK', (tester) async {
    await ac(tester, istemci(dayaniklilik: ItemInstance.tamDayaniklilik));
    await filoyaDokun(tester);
    expect(find.byKey(itemSheetOnarKey), findsNothing);
    expect(find.text('%100 · 10 ÖLÜM'), findsOneWidget);
  });
}
