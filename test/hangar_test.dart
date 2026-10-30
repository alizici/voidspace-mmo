@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/dil/metin.dart';
import 'package:voidspace3/hangar/gemi_ikonu.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/item_sheet.dart';
import 'package:voidspace3/hangar/menu_model.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace3/hangar/onay_penceresi.dart';
import 'package:voidspace3/hangar/shop_page.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/gateway.dart';

import 'game_harness.dart';

/// Hangarın UÇTAN UCA sözleşmesi.
///
/// Buradaki testlerin ortak sorusu tek: hangar gerçekten oyunu etkiliyor mu,
/// yoksa hiçbir şey yapmayan bir menü mü? Ve ikinci soru: kararı kim veriyor?
void main() {
  cevirmeOnayi();
  seritSayilari();
  yukseltmeOku();
  malzemeGorunurlugu();
  Future<void> until(bool Function() condition, {String? reason}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError(reason ?? 'koşul sağlanmadı');
  }

  test(
    'dünyaya girer girmez hangar durumu GELİR',
    () async {
      // Oyuncunun ayrıca istemesi gerekmemeli: parasını ve donatımını bildiği
      // an, oyuna girdiği an.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);

      await until(() => client.hangar != null, reason: 'hangar gelmedi');
      expect(client.hangar!.credits, Hangar.startingCredits);
      expect(client.hangar!.hulls, contains(HullClass.starter.id));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'satın alınan lazer takılınca SAVAŞAN geminin hasarı artar',
    () async {
      // Bu testin ölçtüğü şey bütün sistemin sebebi: hangardaki karar dünyadaki
      // gemiye ulaşmalı.
      final gateway = await bootServer(devRich: {'Ada'});
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);
      await until(() => client.hangar != null);

      final ship = gateway.zone.ships.values.single;
      // Yeni oyuncu TAKILI bir başlangıç lazeriyle geliyor.
      // YAYLIM ölçülüyor, namlu başına hasar değil: raf bandın bir altını
      // satıyor (15.2) ve ilk bantta alınabilen lazer başlangıçtakiyle aynı
      // C-I; ikinci namlu yaylımı büyütür, namlu başına sayıyı değil.
      final starterVolley = ship.state.stats.baseVolleyDamage;
      expect(starterVolley, greaterThan(0));

      // Daha iyisini al ve tak: hasar ARTMALI.
      client.hangarAction('buy_item', {'specId': 'pl1'});
      await until(
        () => client.hangar!.inventory.length > 1,
        reason: 'eşya envantere düşmedi',
      );

      final bought = client.hangar!.inventory.keys.firstWhere(
        (id) => id != 'starter_laser',
      );
      client.hangarAction('equip', {
        'slot': const SlotRef(SlotType.laser, 1).id,
        'instanceId': bought,
      });

      await until(
        () =>
            gateway.zone.ships.values.single.state.stats.baseVolleyDamage >
            starterVolley,
        reason: 'donatım SAVAŞAN gemiye ulaşmadı',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'takılan lazer geminin SİLAHINA dönüşür — kendinde ve başkalarında',
    () async {
      // Eski projeden istenen özellik: gemi taktığı kadar top taşıyor.
      //
      // Ölçülen şey ÇİZİM DEĞİL: portrenin ve `ShipSwarm`'ın okuduğu sayının
      // hangardan savaşa ve oradan DİĞER OYUNCUYA ulaşıp ulaşmadığı. Tek
      // istemcide ölçmek yetmezdi — asıl kırılgan yer yayın: yanındaki
      // oyuncunun gemisinde beş top görünürken seninkinde bir tane olması,
      // ikisinden birinin yalan söylediği anlamına gelir.
      final gateway = await bootServer(devRich: {'Ada'});
      addTearDown(gateway.stop);
      final ada = await connectClient(gateway, 'Ada');
      addTearDown(ada.dispose);
      final bora = await connectClient(gateway, 'Bora');
      addTearDown(bora.dispose);
      await awaitPlaying([ada, bora]);
      await until(() => ada.hangar != null);

      // Her ikisi de birbirinin namlu sayısını el sıkışmada öğreniyor.
      await until(() => bora.lasers.containsKey(ada.entityId));
      expect(
        ada.lasers[ada.entityId],
        1,
        reason: 'başlangıç gemisinde tek takılı lazer var',
      );
      expect(bora.lasers[ada.entityId], 1, reason: 'meta yayınlanmadı');

      // İkinci lazeri al ve tak.
      ada.hangarAction('buy_item', {'specId': 'pl1'});
      await until(() => ada.hangar!.inventory.length > 1);
      final bought = ada.hangar!.inventory.keys.firstWhere(
        (id) => id != 'starter_laser',
      );
      ada.hangarAction('equip', {
        'slot': const SlotRef(SlotType.laser, 1).id,
        'instanceId': bought,
      });

      // Sunucunun otoriter sayısı, kendi istemcisi ve KOMŞUSU — üçü de.
      await until(
        () =>
            gateway.zone.ships.values
                .firstWhere((s) => s.name == 'Ada')
                .state
                .stats
                .equippedLasers ==
            2,
        reason: 'sunucu takılan lazeri saymadı',
      );
      await until(
        () => ada.lasers[ada.entityId] == 2,
        reason: 'oyuncu kendi silahının arttığını görmüyor',
      );
      await until(
        () => bora.lasers[ada.entityId] == 2,
        reason: 'komşu oyuncu silahın arttığını görmüyor',
      );

      // Sökünce geri iniyor: sayı tek yönlü bir sayaç değil.
      ada.hangarAction('unequip', {
        'slot': const SlotRef(SlotType.laser, 1).id,
      });
      await until(
        () => bora.lasers[ada.entityId] == 1,
        reason: 'sökülen lazer komşuda hâlâ silah olarak duruyor',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'takılan itki İSTEMCİNİN TAHMİNİNE de girer — lastik bant yok',
    () async {
      // Sunucu, dünyaya giren geminin statlarını DONATIMDAN çözüyor. İstemci
      // `ShipStats.bastion`de kalsaydı ikisi farklı hızda koşardı: istemci
      // saniyede 320 birim tahmin ederken sunucu daha fazlasını simüle eder ve
      // her snapshot bir düzeltme getirirdi. Ağda hiçbir sorun yokken oyuncunun
      // "takılıyor, hareket ettiremiyorum" diye tarif ettiği şey tam olarak bu.
      //
      // Sinsi olan yanı: başlangıç donatımı `bastion`e denk düşüyor, yani
      // mağazadan İLK hız eşyası alınana kadar hiçbir belirti vermiyor.
      final gateway = await bootServer(devRich: {'Ada'});
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);
      await until(() => client.hangar != null);

      client.hangarAction('buy_item', {'specId': 'th1'});
      await until(
        () => client.hangar!.inventory.values.any((i) => i.specId == 'th1'),
        reason: 'itki jeneratörü envantere düşmedi',
      );
      final engine = client.hangar!.inventory.values
          .firstWhere((i) => i.specId == 'th1')
          .instanceId;
      client.hangarAction('equip', {
        'slot': const SlotRef(SlotType.generator, 0).id,
        'instanceId': engine,
      });

      await until(
        () =>
            gateway.zone.ships.values.single.state.stats.speed >
            ShipStats.bastion.speed,
        reason: 'itki SAVAŞAN gemiye ulaşmadı',
      );

      // ASIL İDDİA: iki uç AYNI hızda koşuyor.
      final serverSpeed = gateway.zone.ships.values.single.state.stats.speed;
      expect(
        client.stats.speed,
        closeTo(serverSpeed, 0.001),
        reason: 'istemci sunucudan farklı bir hızla tahmin ediyor',
      );

      // Ve ölçülebilir sonucu: uçarken düzeltme birikmiyor.
      client.ship!.axis = const Vec2(1, 0);
      await pump([client], 2);
      expect(
        client.ship!.correctionDistance,
        lessThan(20),
        reason: 'tahmin sunucudan ayrışıyor — lastik bant',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'kalkan takmak kalkanı DOLDURMAZ — oran korunur',
    () async {
      // Aksi hâlde hangar bir tamir istasyonu olurdu: dövüşün ortasında
      // jeneratör değiştirip tam kalkanla dönmek.
      final gateway = await bootServer(devRich: {'Ada'});
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);
      await until(() => client.hangar != null);

      final ship = gateway.zone.ships.values.single;
      ship.state = ShipSim.applyDamage(ship.state, 4000);
      final woundedFraction = ship.state.shieldFraction;
      expect(woundedFraction, lessThan(0.9), reason: 'kurulum başarısız');

      client.hangarAction('buy_item', {'specId': 'df1'});
      await until(() => client.hangar!.inventory.length > 1);
      // Envanterde başlangıç lazeri de var: JENERATÖRÜ seç.
      final generator = client.hangar!.inventory.values
          .firstWhere((i) => i.specId == 'df1')
          .instanceId;
      client.hangarAction('equip', {
        'slot': const SlotRef(SlotType.generator, 0).id,
        'instanceId': generator,
      });

      await until(
        () =>
            gateway.zone.ships.values.single.state.stats.maxShield >
            ShipStats.bastion.maxShield,
        reason: 'kalkan artmadı',
      );
      expect(
        gateway.zone.ships.values.single.state.shieldFraction,
        closeTo(woundedFraction, 0.02),
        reason: 'kalkan takmak gemiyi onardı',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'SAHİP OLMADIĞI eşyayı takamaz — sunucu reddeder',
    () async {
      // İstemci istediğini yollayabilir; kararı veren sunucu.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);
      await until(() => client.hangar != null);

      client.hangarAction('equip', {
        'slot': const SlotRef(SlotType.laser, 0).id,
        'instanceId': 'uydurma',
      });
      await until(() => client.hangar!.error != null, reason: 'red gelmedi');
      expect(
        client.hangar!.itemAt(const SlotRef(SlotType.laser, 0)),
        'starter_laser',
        reason: 'uydurma eşya başlangıç lazerinin yerine geçti',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('PARASI YETMEYEN satın alamaz', () async {
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final client = await connectClient(gateway, 'Ada');
    addTearDown(client.dispose);
    await awaitPlaying([client]);
    await until(() => client.hangar != null);

    final before = client.hangar!.credits;
    // Spectre çok pahalı: başlangıç parası yetmez.
    client.hangarAction('buy_hull', {'hullId': HullClass.spectre.id});
    await until(() => client.hangar!.error != null);

    expect(client.hangar!.credits, before, reason: 'para gitti');
    expect(client.hangar!.hulls, isNot(contains(HullClass.spectre.id)));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('OLMAYAN yuvaya takamaz', () async {
    // Bastion'da 5 lazer yuvası var. Dokuzuncuya takmak, bütçe hesabında
    // olmayan bedava güç olurdu.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final client = await connectClient(gateway, 'Ada');
    addTearDown(client.dispose);
    await awaitPlaying([client]);
    await until(() => client.hangar != null);

    client.hangarAction('equip', {
      'slot': const SlotRef(SlotType.laser, 99).id,
      'instanceId': 'starter_laser',
    });
    await until(() => client.hangar!.error != null, reason: 'red gelmedi');
    expect(
      client.hangar!.slots.keys,
      isNot(contains('laser#99')),
      reason: 'olmayan yuvaya takıldı',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('ilerleme YENİDEN GİRİŞTE durur', () async {
    // Kalıcılığın bütün sebebi. Kaybolan ilerleme, oyuncunun bir daha
    // dönmemesinin en kısa yolu.
    final gateway = await bootServer();
    addTearDown(gateway.stop);

    final first = await connectClient(gateway, 'Ada');
    await awaitPlaying([first]);
    await until(
      () => first.hangar != null,
      reason: 'ADIM: ilk oturuma hangar gelmedi',
    );
    // C tier: başlangıç parasıyla alınabilir. A tier (pl4) 52.920 kredi ve
    // başlangıç 30.000 — ilk yazışta oraya takıldım, yani "parası yetmeyen
    // alamaz" kuralı çalışıyor.
    // Raf 15.2'nin fiyatını istiyor ve başlangıç kredisi yetmiyor (borç
    // defteri B21): hangar sunucu tarafında bir taban eşyalık fonlanıyor.
    // Geliştirme zenginliği burada olmaz: yeniden girişte bakiyeyi tabana
    // çeker ve "para kaldı mı" sorusunu cevaplanamaz kılardı.
    final fonHesabi = gateway.zone.ships.values.first.accountId;
    gateway.hangars
        .of(fonHesabi)
        .earn(
          Currency.credit,
          Catalogue.rafFiyati(0).amount,
          reason: LedgerReason.signup,
          txId: 'fon',
          atMillis: 0,
        );
    first.hangarAction('refresh', {});
    await until(
      () => first.hangar!.credits > Hangar.startingCredits,
      reason: 'ADIM: fon istemciye ulaşmadı',
    );
    first.hangarAction('buy_item', {'specId': 'pl1'});
    await until(
      () => first.hangar!.inventory.length > 1,
      reason: 'ADIM: ilk oturumda eşya alınamadı',
    );
    final credits = first.hangar!.credits;
    final instanceId = first.hangar!.inventory.keys.firstWhere(
      (id) => id != 'starter_laser',
    );
    first.hangarAction('equip', {
      'slot': const SlotRef(SlotType.laser, 1).id,
      'instanceId': instanceId,
    });
    await until(
      () => first.hangar!.slots.isNotEmpty,
      reason: 'ADIM: ilk oturumda donatım yerleşmedi',
    );
    first.dispose();

    // Aynı hesapla YENİDEN gir.
    final second = NetClient(uri: Uri.parse('ws://127.0.0.1:${gateway.port}'));
    addTearDown(second.dispose);
    await second.connect();
    await awaitPhase(second, NetPhase.needsAuth);
    await second.login(username: 'Ada', password: testPassword);
    await awaitAuthenticated(second);
    await awaitPlaying([second]);
    await until(
      () => second.hangar != null,
      reason: 'ADIM: ikinci oturuma hangar gelmedi',
    );

    expect(second.hangar!.credits, credits, reason: 'para kayboldu');
    expect(second.hangar!.inventory, contains(instanceId));
    expect(
      second.hangar!.itemAt(const SlotRef(SlotType.laser, 1)),
      instanceId,
      reason: 'donatım kayboldu',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  _screenTests();
}

/// Hangar EKRANININ sözleşmesi.
///
/// Ekran hiçbir şey hesaplamıyor: gösterdiği her sayı sunucudan geliyor ve
/// her düğme bir niyet yolluyor. Testler bunu doğruluyor.
void _screenTests() {
  testWidgets('hangar sunucudan gelen parayı ve statları GÖSTERİR', (
    tester,
  ) async {
    late NetClient net;
    late Gateway gateway;
    await tester.runAsync(() async {
      gateway = await bootServer();
      net = await connectClient(gateway, 'Ada');
      await awaitPlaying([net]);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (net.hangar == null && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    addTearDown(() async {
      net.dispose();
      await gateway.stop();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: net, onClose: () {}),
      ),
    );
    await tester.pump();

    // Para METİNLE değil ANAHTARLA aranıyor: metinle aramak biçime bağlanmak
    // demek ve binlik ayracı eklendiği gün ekran doğru çalışırken test
    // kırmızıya dönerdi.
    final wallet = tester.widget<Text>(
      find.byKey(walletValueKey(Currency.credit)),
    );
    expect(
      wallet.data,
      menuNumber(Hangar.startingCredits, Dil.turkce),
      reason: 'para sunucudan geldiği gibi gösterilmiyor',
    );
    // Başlangıç lazeri TAKILI gelmeli.
    //
    // Adı hücrede ARANMIYOR: klasik envanter ızgarasında hücre işaret
    // taşıyor, ad değil (56 piksele "Nişan Devresi" sığmıyor). Ad, yuvaya
    // dokununca ayrıntı şeridinde çıkıyor — oyuncunun onu gördüğü yol da bu.
    await tester.tap(find.byKey(slotTileKey(const SlotRef(SlotType.laser, 0))));
    await tester.pump();
    expect(
      find.textContaining('PL-1'),
      findsOneWidget,
      reason: 'takılı lazerin adı hiçbir yerde görünmüyor',
    );
    // Gövdenin her yuva türü DONANIM sütununda yerini almalı.
    for (final type in SlotType.values) {
      final hull = net.hangar!.activeHull;
      if (hull.slotCount(type) == 0) continue;
      expect(
        find.byKey(slotTileKey(SlotRef(type, 0))),
        findsOneWidget,
        reason: '${slotLabel(type, Dil.turkce)} yuvası çizilmedi',
      );
    }
  });

  testWidgets('SATIN AL düğmesi sunucuya gider ve para düşer', (tester) async {
    late NetClient net;
    late Gateway gateway;
    await tester.runAsync(() async {
      gateway = await bootServer();
      net = await connectClient(gateway, 'Ada');
      await awaitPlaying([net]);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (net.hangar == null && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    addTearDown(() async {
      net.dispose();
      await gateway.stop();
    });

    // Fon YOK ve olmamalı: başlangıç kredisi artık raftan türüyor (15.8) ve
    // ilk bandın taban eşyasını karşılıyor. Eskiden burada elle fon
    // basılıyordu, çünkü 30.000 kredi 94.522'lik rafın önünde duruyordu
    // (borç defteri B21, kapandı).

    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: net, onClose: () {}),
      ),
    );
    await tester.pump();

    final before = net.hangar!.credits;
    expect(
      before,
      greaterThanOrEqualTo(Catalogue.rafFiyati(0).amount),
      reason: 'başlangıç kredisi rafın önünde duruyor',
    );

    // Mağaza AYRI bir sekme: hangar sayfasında satın alma düğmesi YOK ve
    // olmamalı — aynı ekranda hem donatım hem alışveriş, ikisini de okunmaz
    // yapıyordu.
    expect(
      find.byKey(shopBuyKey(Catalogue.pl1.id)),
      findsNothing,
      reason: 'mağaza hangar sekmesine sızmış',
    );
    await tester.tap(find.byKey(menuTabKey(MenuTabId.shop)));
    await tester.pump();

    await tester.tap(find.byKey(shopBuyKey(Catalogue.pl1.id)));
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (net.hangar!.credits == before &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(
      net.hangar!.credits,
      // Raf fiyatı 15.2'nin modeli; ilk bant, rank 0.
      before - Catalogue.rafFiyati(0).amount,
      reason: 'satın alma sunucuya ulaşmadı',
    );
  });

  // KARAR 17.2 s1
  testWidgets('MERMİ rafı: paket alınca stok artıyor, MR-1 satılmıyor', (
    tester,
  ) async {
    // Mermi eşya değil: raftan paketle alınıyor, stok sayıyla görünüyor
    // (17.8). MR-1 listede ama düğmesiz — bedava ve sınırsız (17.2).
    final ctx = await _bootScreen(tester);
    await tester.tap(find.byKey(menuTabKey(MenuTabId.shop)));
    await tester.pump();
    await tester.tap(find.byKey(shopCategoryKey('mermi')));
    await tester.pump();

    expect(find.byKey(shopBuyKey('mermi-MR-1')), findsNothing);
    final before = ctx.net.hangar!.credits;
    await tester.tap(find.byKey(shopBuyKey('mermi-MR-2')));
    await _settle(
      tester,
      ctx,
      () => ctx.net.hangar!.mermiSayisi('MR-2') == ShopPage.mermiPaketi,
    );
    expect(ctx.net.hangar!.mermiSayisi('MR-2'), ShopPage.mermiPaketi);
    expect(
      ctx.net.hangar!.credits,
      before - Mermi.byId('MR-2')!.fiyatFor(ShopPage.mermiPaketi),
      reason: 'fiyat sunucununkiyle uyuşmuyor',
    );
  });

  testWidgets('yuvaya TEK dokunuş pencereyi açar, ÇİFT dokunuş çıkarır', (
    tester,
  ) async {
    // **Bu davranış iki kez değişti ve ikisi de yazılı.** Önce dokunmak
    // doğrudan takıp çıkarıyordu: aynı hareket yuvanın doluluğuna göre iki
    // farklı iş yapıyordu. Sonra dokunmak yalnız SEÇİYOR, eylemler ekranın
    // altındaki bir şeritte duruyordu: her iş iki dokunuş ve parmağın ekranı
    // boydan boya geçmesi demekti, üstelik şerit telefonda 84 piksel yiyordu.
    //
    // Şimdi: tek dokunuş parçanın penceresini açıyor (bütün eylemler orada,
    // parçanın sayılarıyla birlikte), çift dokunuş kısayol.
    final ctx = await _bootScreen(tester);

    const slot = SlotRef(SlotType.laser, 0);
    expect(
      ctx.net.hangar!.itemAt(slot),
      isNotNull,
      reason: 'kurulum: başlangıç lazeri takılı olmalı',
    );

    // TEK dokunuş: pencere açılıyor, hiçbir şey çıkmıyor.
    await tester.tap(find.byKey(slotTileKey(slot)));
    await tester.pump();
    expect(find.byType(ItemSheet), findsOneWidget, reason: 'pencere açılmadı');
    expect(
      ctx.net.hangar!.itemAt(slot),
      isNotNull,
      reason: 'tek dokunuş parçayı söktü',
    );

    // ÇİFT dokunuş: çıkarıyor. İkinci dokunuş pencerenin PERDESİNE düşüyor
    // (ilk dokunuş pencereyi açtı ve perde ekranı kapladı) — perde de aynı
    // soruyu sorduğu için kısayol çalışıyor. Bu testin asıl koruduğu şey bu:
    // perde ikinci dokunuşu yutarsa çift dokunuş hiç çalışmaz.
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester, ctx, () => ctx.net.hangar!.itemAt(slot) == null);

    expect(
      ctx.net.hangar!.itemAt(slot),
      isNull,
      reason: 'çift dokunuş sunucuya ulaşmadı',
    );
  });

  testWidgets('depoda tek dokunuş SEÇER, uzun basma BİLGİYİ açar', (
    tester,
  ) async {
    // **Bu davranış üç kez değişti ve üçü de yazılı.** Önce dokunmak
    // doğrudan TAKIYORDU: oyuncu parçanın ne verdiğini takmadan önce hiçbir
    // yerde okuyamıyordu. Sonra dokunmak BİLGİ penceresini açıyordu: körleme
    // gitti ama takmak üç dokunuş oldu (parçaya dokun, pencereyi oku, TAK'a
    // bas) ve pencerenin perdesi ekranı kapattığı için takacağın yuvayı
    // GÖREMİYORDUN.
    //
    // Şimdi: dokunmak SEÇİYOR, uygun boş yuvalar işaretleniyor, yuvaya
    // dokunmak takıyor. Karar hâlâ körleme değil — çünkü seçiliyken nereye
    // gireceğini ekranda görüyorsun — ama pencere açmayı gerektirmiyor.
    // Bilgi kaybolmadı, UZUN BASMAYA taşındı.
    final ctx = await _bootScreen(tester);
    const slot = SlotRef(SlotType.laser, 0);

    // Önce çıkar ki depoda takılabilir bir parça olsun — çift dokunuşla.
    await tester.tap(find.byKey(slotTileKey(slot)));
    await tester.pump();
    await tester.tap(find.byKey(slotTileKey(slot)));
    await _settle(tester, ctx, () => ctx.net.hangar!.itemAt(slot) == null);

    final instanceId = ctx.net.hangar!.inventory.keys.first;

    // UZUN BASMA pencereyi açıyor ve TAKMIYOR.
    await tester.longPress(find.byKey(depotTileKey(instanceId)));
    await tester.pump();
    expect(find.byKey(itemSheetActionKey), findsOneWidget);
    expect(
      ctx.net.hangar!.itemAt(slot),
      isNull,
      reason: 'uzun basma körlemesine taktı',
    );

    // Pencereyi kapat, sonra TEK DOKUNUŞLA seç ve yuvaya tak.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.tap(find.byKey(depotTileKey(instanceId)));
    await tester.pump();
    expect(
      ctx.net.hangar!.itemAt(slot),
      isNull,
      reason: 'seçmek tek başına taktı',
    );

    await tester.tap(find.byKey(slotTileKey(slot)));
    await _settle(tester, ctx, () => ctx.net.hangar!.itemAt(slot) != null);
    expect(
      ctx.net.hangar!.itemAt(slot),
      instanceId,
      reason: 'seçili parça hedef yuvaya girmedi',
    );
  });

  // KARAR 04.10 s3
  testWidgets('droid FİLOYA alınır ve filodan çıkar — gövdeye takılmaz', (
    tester,
  ) async {
    // Droid bir yuvaya değil FİLOYA gidiyor (04.10): pencerenin eylemi TAK
    // değil FİLOYA AL, geri yolu da FİLODAN ÇIKAR. Filo gövdenin dışında
    // duruyor, o yüzden hedef yuva aranmıyor. Droid rank indeksi üçte
    // açılıyor (10.7), yani B-I: fixture'ın C-III'ü yetmiyor, bir B-I eşya
    // daha giriyor. Sunucu reddi sessiz — bekleme bittikten sonra filo
    // ayrıca doğrulanıyor ki kapalı kapı "geçti" diye okunmasın.
    final ctx = await _bootScreen(tester, acilis: true);
    const droidId = 'filo-dr1';
    await tester.runAsync(() async {
      final hesap = await ctx.gateway.accounts.login(
        usernameOrEmail: 'Ada',
        password: testPassword,
      );
      ctx.gateway.hangars.of(hesap.id)
        ..addItem(const ItemInstance(instanceId: 'acilis-pl5', specId: 'pl5'))
        ..addItem(const ItemInstance(instanceId: droidId, specId: 'dr1'));
    });
    ctx.net.hangarAction('refresh');
    await _settle(tester, ctx, () => ctx.net.hangar!.instance(droidId) != null);
    expect(ctx.net.hangar!.filo, isEmpty);

    // Depodan UZUN BAS: tek dokunuş artık seçiyor, pencere uzun basmada.
    await tester.ensureVisible(find.byKey(depotTileKey(droidId)));
    await tester.pump();
    await tester.longPress(find.byKey(depotTileKey(droidId)));
    await tester.pump();
    expect(find.text('FİLOYA AL'), findsOneWidget);
    await tester.ensureVisible(find.byKey(itemSheetActionKey));
    await tester.pump();
    await tester.tap(find.byKey(itemSheetActionKey));
    await _settle(tester, ctx, () => ctx.net.hangar!.filo.contains(droidId));
    expect(
      ctx.net.hangar!.filo,
      contains(droidId),
      reason: 'FİLOYA AL sunucuda reddedildi: ${ctx.net.hangar!.error}',
    );
    expect(ctx.net.hangar!.slots.values, isNot(contains(droidId)));

    // Filodaki droid depoda listelenmiyor, filo kutusunda duruyor.
    expect(find.byKey(depotTileKey(droidId)), findsNothing);
    // Filo DROİD sekmesinde: sol bölme sekmeye göre değişiyor.
    await tester.tap(find.byKey(paneTabKey(HangarTab.droid)));
    await tester.pump();
    await tester.ensureVisible(find.byKey(filoTileKey(0)));
    await tester.pump();
    await tester.longPress(find.byKey(filoTileKey(0)));
    await tester.pump();
    expect(find.text('FİLODAN ÇIKAR'), findsOneWidget);
    await tester.ensureVisible(find.byKey(itemSheetActionKey));
    await tester.pump();
    await tester.tap(find.byKey(itemSheetActionKey));
    await _settle(tester, ctx, () => ctx.net.hangar!.filo.isEmpty);
    expect(ctx.net.hangar!.filo, isEmpty, reason: 'FİLODAN ÇIKAR ulaşmadı');
    expect(ctx.net.hangar!.instance(droidId), isNotNull);
  });

  testWidgets('YÜKSELT pencereyi KAPATMIYOR, sayılar güncelleniyor', (
    tester,
  ) async {
    // Yükseltmek tekrarlanan bir iş — oyuncu +15'e kadar basıyor. Pencere
    // her basışta kapansaydı aynı parçayı on beş kez yeniden açmak gerekirdi.
    // Ve açık kalması sonucu da gösteriyor: pencere hangardan okuyor, yani
    // seviye ile sonraki maliyet basışın ardından değişiyor.
    final ctx = await _bootScreen(tester, acilis: true);
    const slot = SlotRef(SlotType.laser, 0);
    final instanceId = ctx.net.hangar!.itemAt(slot)!;
    final spec = ctx.net.hangar!.specOf(instanceId)!;
    final oncekiSeviye = ctx.net.hangar!.instance(instanceId)!.level;

    // MALZEME KAPISI önce açılıyor — taze hesabın malzemesi yok ve yükseltme
    // sessizce reddediliyordu. Testi ilk yazdığımda `_settle` zaman aşımına
    // uğradı ve seviye sıfırda kaldı; kapı doğru çalışıyordu, eksik olan
    // testin kurulumuydu. Başlangıç lazerinin rankı mağaza rafında, yani
    // oyuncunun kendi yolundan alınabiliyor.
    final malzeme = Malzeme.forRank(spec.tier);
    final gereken = Yukseltme.malzemeMaliyeti(oncekiSeviye, spec.tier);
    ctx.net.hangarAction('malzeme_al', {
      'malzemeId': malzeme.id,
      'adet': gereken,
    });
    await _settle(
      tester,
      ctx,
      () => (ctx.net.hangar!.malzemeler[malzeme.id] ?? 0) >= gereken,
    );

    await tester.longPress(find.byKey(slotTileKey(slot)));
    await tester.pump();
    expect(find.byKey(itemSheetUpgradeKey), findsOneWidget);

    await tester.tap(find.byKey(itemSheetUpgradeKey));
    await _settle(
      tester,
      ctx,
      () => ctx.net.hangar!.instance(instanceId)!.level > oncekiSeviye,
    );

    expect(
      find.byKey(itemSheetUpgradeKey),
      findsOneWidget,
      reason: 'pencere yükseltmeden sonra kapandı',
    );
    // Yeni seviye PENCEREDE: kapanmayan bir pencere sonucu göstermeli.
    // Yeni seviye PENCEREDE: kapanmayan bir pencere sonucu göstermeli.
    expect(
      find.textContaining('+${oncekiSeviye + 1}'),
      findsWidgets,
      reason: 'pencere açık kaldı ama eski seviyeyi gösteriyor',
    );
  });

  testWidgets('bilgi penceresi alt statın ARALIĞINI gösteriyor', (
    tester,
  ) async {
    // Kullanıcının sorusu: "çevirince ne çıkabilir?". Aralık olmadan tek bir
    // sayı hiçbir şey söylemiyor — oyuncu %2,8'in iyi mi kötü mü olduğunu
    // bilemiyor, yani ÇEVİR'e basıp basmamaya karar veremiyor.
    final ctx = await _bootScreen(tester);
    const slot = SlotRef(SlotType.laser, 0);
    final instanceId = ctx.net.hangar!.itemAt(slot)!;
    final spec = ctx.net.hangar!.specOf(instanceId)!;
    final item = ctx.net.hangar!.instance(instanceId)!;
    final statId = LoadoutResolver.altStatlariFor(
      item,
      spec,
      ctx.net.hangar!.activeHull,
    ).keys.first;

    await tester.longPress(find.byKey(slotTileKey(slot)));
    await tester.pump();

    final taban = ItemBudget.altStatTabani(
      spec,
      item.level,
      ctx.net.hangar!.activeHull,
      statId,
      item.instanceId,
    )!;
    final enAz = taban * TasarimGirdileri.kaliteAltSiniri;
    // Ondalık ayracı DİLDEN geliyor (`lib/dil/sayi.dart`): Türkçe virgül,
    // İngilizce nokta. Widget testinde `DilKapsami` yok, yani ekran Türkçeye
    // düşüyor — beklenti de öyle yazılıyor.
    String yuzde(double v) =>
        '%${(v * 100).toStringAsFixed(1).replaceAll('.', ',')}';

    expect(
      find.text(yuzde(enAz)),
      findsOneWidget,
      reason: 'aralığın ALT ucu yazmıyor',
    );
    expect(
      find.text(yuzde(taban)),
      findsOneWidget,
      reason: 'aralığın ÜST ucu yazmıyor',
    );
  });

  testWidgets('bilgi penceresi ANA STATI ve DEĞERİNİ gösteriyor', (
    tester,
  ) async {
    // Pencerenin varlık sebebi: parçanın NE VERDİĞİNİ takmadan önce okumak.
    //
    // **İlk hâli boş bir iddiaydı** ve mutasyon sınaması gösterdi: ana stat
    // satırını pencereden tamamen sildiğimde test GEÇTİ. Yalnız parçanın adını
    // arıyor ve "etiketin adı boş değil" diyordu — ikincisi her zaman doğru.
    // Ölçülmesi gereken şey satırın EKRANDA olması ve DEĞERİN doğru olması.
    final ctx = await _bootScreen(tester);
    const slot = SlotRef(SlotType.laser, 0);
    final instanceId = ctx.net.hangar!.itemAt(slot)!;
    final spec = ctx.net.hangar!.specOf(instanceId)!;

    // Takılı parçanın bilgisi UZUN BASMAYLA — dokunuş seçime ait.
    await tester.longPress(find.byKey(slotTileKey(slot)));
    await tester.pump();

    expect(
      find.byKey(itemSheetCloseKey),
      findsOneWidget,
      reason: 'pencere açılmadı',
    );
    // Etiket BÜYÜK HARF: kartta ana stat, hangardaki stat hücreleriyle
    // (GÖVDE · KALKAN · HIZ) aynı biçimde, büyük sayının üstünde küçük bir
    // başlık olarak duruyor.
    expect(
      find.text(Catalogue.labelOf(spec.mainStat).toUpperCase()),
      findsOneWidget,
      reason: 'ana stat satırı yok',
    );

    // DEĞER de ekranda ve donatım çözücüsünün verdiğiyle AYNI: ikinci bir
    // hesap, pencerede yazan ile gemiye inen arasında sessiz bir ayrışma
    // üretirdi ve ikisi de kendi içinde tutarlı kalacağı için görünmezdi.
    final beklenen = ItemBudget.mainStatValue(
      spec,
      ctx.net.hangar!.instance(instanceId)!.level,
      ctx.net.hangar!.activeHull,
    );
    expect(
      find.textContaining(beklenen.round().toString()),
      findsWidgets,
      reason: 'ana statın değeri ekranda yok',
    );
  });

  testWidgets('filo penceresi BÜTÜN gemileri listeler, kilitliyi seçtirmez', (
    tester,
  ) async {
    // Yalnız sahip olunanları göstermek pencereyi tek kartlık bir boşluğa
    // çeviriyordu ve merdivenin devamını hiç göstermiyordu: oyuncu neyin
    // peşinden gideceğini bilmeden biriktirmez. Kilitliler görünür ama
    // SEÇİLEMEZ.
    final ctx = await _bootScreen(tester);

    await tester.tap(find.byKey(fleetOpenKey));
    await tester.pump();

    final owned = ctx.net.hangar!.hulls;
    expect(owned, isNotEmpty, reason: 'kurulum: en az bir gemi olmalı');
    final locked = HullClass.all.where((h) => !owned.contains(h.id));
    expect(locked, isNotEmpty, reason: 'kurulum: kilitli gemi de olmalı');

    for (final hull in HullClass.all) {
      expect(
        find.byKey(fleetCardKey(hull.id)),
        findsOneWidget,
        reason: 'gemi filoda görünmüyor: ${hull.id}',
      );
    }

    // Kilitli bir gemiye dokunmak AKTİF gemiyi değiştirmemeli.
    final before = ctx.net.hangar!.activeHullId;
    await tester.tap(find.byKey(fleetCardKey(locked.first.id)));
    await tester.pump();
    expect(
      ctx.net.hangar!.activeHullId,
      before,
      reason: 'sahip olunmayan gemi seçilebildi',
    );
    // Pencere de kapanmamalı: dokunuş bir şey yapmadıysa ekran da değişmemeli.
    expect(find.byKey(fleetCardKey(before)), findsOneWidget);

    await tester.tap(find.byKey(fleetCloseKey));
    await tester.pump();
    expect(find.byKey(fleetCardKey(HullClass.starter.id)), findsNothing);
  });

  testWidgets('KAPAT düğmesi menüyü kapatır', (tester) async {
    // Oyuncunun şikâyeti buydu: geri dönmenin yolu görünmüyordu.
    var closed = false;
    final ctx = await _bootScreen(tester, onClose: () => closed = true);
    expect(ctx.net.hangar, isNotNull);

    await tester.tap(find.byKey(hangarCloseKey));
    await tester.pump();

    expect(closed, isTrue, reason: 'menüden çıkış yolu yok');
  });
  testWidgets('düzen ÖLÇEKLENMEZ — telefon yatayda da okunur kalır', (
    tester,
  ) async {
    // Oyuncunun iki şikâyeti aynı kökten geliyordu: menü sabit bir sahneye
    // çizilip ekrana sığdırılıyordu, yani PİKSEL ölçekleniyordu. Telefonda
    // yazı okunmuyor, Mac'te pencere küçüldükçe küçülüyordu.
    //
    // Bu test iki şeyi birden kilitliyor: aynı metin HER ekranda AYNI
    // punto, ve dar ekranda düzen taşmıyor (taşma widget testinde hatadır).
    final ctx = await _bootScreen(tester);

    // Ölçülen metin GEMİ ADI ve o artık GEMİ sekmesinin künyesinde: telefonda
    // üst şerit kalktı. Sekmeye geçmek testin konusunu değiştirmiyor —
    // ölçülen şey hâlâ "aynı metin her pencere boyunda aynı punto".
    Future<double> heroSize() async {
      await tester.tap(find.byKey(paneTabKey(HangarTab.gemi)));
      await tester.pump();
      final punto = tester
          .widget<Text>(
            find.text(ctx.net.hangar!.activeHull.name.toUpperCase()),
          )
          .style!
          .fontSize!;
      // EKİPMAN'a dön: bu yardımcı testin ortasında çağrılıyor ve arkasından
      // gelen beklentiler yuvalara bakıyor. Sekmeyi açık bırakmak, ölçümün
      // yan etkisini sonraki satıra taşımak olurdu.
      await tester.tap(find.byKey(paneTabKey(HangarTab.ekipman)));
      await tester.pump();
      return punto;
    }

    // iPhone 14 yatay.
    tester.view
      ..physicalSize = const Size(844, 390)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 400));
    final onPhone = await heroSize();

    // Yarı genişlikte Mac penceresi — AYNI yükseklik sınıfı.
    tester.view.physicalSize = const Size(700, 400);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      await heroSize(),
      onPhone,
      reason: 'pencere daraldıkça yazı küçülüyor — ölçekleme geri gelmiş',
    );

    // Hiçbir ekranda okunabilir sınırın altına inilmiyor.
    expect(
      onPhone,
      greaterThanOrEqualTo(16),
      reason: 'geminin adı telefonda $onPhone punto',
    );

    // İKİ BÖLME HER ÖLÇÜDE — dar ekranda da.
    //
    // Bu beklenti iki kez değişti ve ikisi de yazılı. Önce dar ekranda iki
    // bölme tek bölmeye iniyordu (Material'ın liste-ayrıntı kuralı) ve sağ
    // sütun sekmeliydi. O düzen kaynak tasarımla çelişiyordu: orada sekme
    // SOL bölmeyi seçiyor, depo sağda KALICI duruyor. Depoyu bir sekmenin
    // arkasına almak, "eldekini takmak" akışını iki dokunuş uzatıyordu —
    // parçayı görmek için bir sekme, takacağın yuvayı görmek için bir sekme.
    //
    // Ölçülen şey: hangi pencere boyunda olursa olsun yuva ile depo AYNI
    // ANDA görünüyor.
    for (final boy in [
      const Size(560, 620),
      const Size(844, 390),
      const Size(1280, 720),
    ]) {
      tester.view.physicalSize = boy;
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(slotTileKey(const SlotRef(SlotType.laser, 0))),
        findsOneWidget,
        reason: '$boy · yuvalar görünmüyor',
      );
      expect(
        find.textContaining('PARÇA'),
        findsWidgets,
        reason: '$boy · depo görünmüyor',
      );
    }

    // Sekmeler SOL bölmeyi seçiyor ve dördü de her ölçüde duruyor.
    tester.view.physicalSize = const Size(1280, 720);
    await tester.pump(const Duration(milliseconds: 400));
    for (final sekme in HangarTab.values) {
      expect(
        find.byKey(paneTabKey(sekme)),
        findsOneWidget,
        reason: '${sekme.name} sekmesi yok',
      );
    }
  });

  testWidgets('gemi HER düzende görünüyor', (tester) async {
    // Oyuncunun sözü: "Bastion'un hemen soluna geminin bir resmini
    // koymalısın". Orada bir roket ikonu ve "LAZER ×5" rozetleri vardı —
    // ekranın konusu olan şey hiç görünmüyordu.
    //
    // Ölçülen şey ÇİZİM DEĞİL VARLIK: portrenin nasıl göründüğüne
    // `tool/menu_preview_test.dart` bakıyor, sınırına
    // `tool/ship_portrait_test.dart`. Burada kilitlenen tek şey, hiçbir
    // pencere boyunda gemisiz kalmamak — çerçeveli portre yer bulamadığında
    // yerine küçüğü geçmeli, hiçbiri değil.
    final ctx = await _bootScreen(tester);
    expect(ctx.net.hangar, isNotNull);
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    // GEMİ SEKMESİNDE, her ölçüde.
    //
    // Bu beklenti değişti ve sebebi bir istek: telefonda üst şerit kalktı —
    // gemi adı, silüeti ve üç düğme bir yuva sırası kadar yer tutuyordu.
    // Gemi kaybolmadı, YERİ değişti: GEMİ sekmesinin sol bölmesinde ve
    // orada eskisinden büyük. Ölçülen şey aynı kaldı — hiçbir pencere
    // boyunda gemisiz kalmamak.
    for (final size in const [
      Size(1280, 720),
      Size(844, 390),
      Size(560, 620),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(paneTabKey(HangarTab.gemi)));
      await tester.pump();
      final gemiler = tester.widgetList<GemiIkonu>(find.byType(GemiIkonu));
      expect(
        gemiler,
        isNotEmpty,
        reason: '${size.width}×${size.height} ekranda gemi görünmüyor',
      );
      // GÖSTERİLEN GEMİ, UÇULAN GEMİ.
      //
      // Eskiden burada portrenin taşıdığı LAZER SAYISI sınanıyordu: portre
      // prosedüreldi ve takılı topları çiziyordu. Ama tek bir gövdeyi
      // (Bastion) çiziyordu da — Yatağan alan oyuncu hangarda hâlâ Bastion
      // görüyordu. Sekiz gövdenin sekiz sanatı varken sabit bir silüet
      // göstermek, ekranın konusu olan soruya yanlış cevap vermekti.
      //
      // Sınama bu yüzden yön değiştirdi ve güçlendi: artık gösterilen
      // geminin AKTİF gövde olduğu doğrulanıyor. Top sayısı DONANIM
      // sekmesindeki grup başlığında (LAZER 3/5) ve sağdaki HASAR
      // sayısında okunuyor.
      for (final g in gemiler) {
        expect(
          g.hullId,
          ctx.net.hangar!.activeHullId,
          reason: 'hangarda uçulmayan bir gemi çiziliyor',
        );
      }
    }
  });
}

/// Ekranı gerçek sunucuya bağlı hâlde kurar.
class _ScreenContext {
  _ScreenContext(this.net, this.gateway);
  final NetClient net;
  final Gateway gateway;
}

Future<_ScreenContext> _bootScreen(
  WidgetTester tester, {
  VoidCallback? onClose,
  // Açılış sırası (karar 10.7): yeni hesap yalnız C-I lazerle başlıyor ve
  // artı basma ile çevirme ikinci ve üçüncü rankın eşyası görülünce açılıyor.
  // Bu iki sistemi sınayan testler hangara sunucu tarafında bir C-III eşya
  // koyduruyor — oyuncunun ganimetten bulacağı şeyin kısayolu.
  bool acilis = false,
}) async {
  late NetClient net;
  late Gateway gateway;
  await tester.runAsync(() async {
    gateway = await bootServer();
    net = await connectClient(gateway, 'Ada');
    await awaitPlaying([net]);
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (net.hangar == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (acilis) {
      final hesap = await gateway.accounts.login(
        usernameOrEmail: 'Ada',
        password: testPassword,
      );
      gateway.hangars
          .of(hesap.id)
          .addItem(const ItemInstance(instanceId: 'acilis-pl4', specId: 'pl4'));
    }
  });
  addTearDown(() async {
    net.dispose();
    await gateway.stop();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: HangarScreen(client: net, onClose: onClose ?? () {}),
    ),
  );
  await tester.pump();
  return _ScreenContext(net, gateway);
}

/// Sunucunun cevabını GERÇEK zamanda bekler, sonra kareyi ilerletir.
///
/// `pump` tek başına yetmez: hangar komutu ağdan gidip geliyor ve widget
/// testinin sahte saati o turu ilerletmiyor.
Future<void> _settle(
  WidgetTester tester,
  _ScreenContext ctx,
  bool Function() done,
) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
}

/// MALZEME ekranda GÖRÜNÜYOR mu.
///
/// Bu testler bir boşluktan doğdu ve boşluğu kullanıcı buldu: parçalama ve
/// öldürme malzeme veriyordu, ama stok hiçbir yerde görünmüyordu. Tek okuma
/// yeri yükseltme satırındaki `elindeki/gereken` çipiydi — o da yalnız seçili
/// eşyanın rankı için. Oyuncu B-I bir parçayı parçalayıp dokuz malzeme alıyor
/// ve onları görebilmek için takılı bir B-I eşya seçmek zorunda kalıyordu.
void malzemeGorunurlugu() {
  testWidgets('stok EKRANDA — parçalar görünmez bir cebe gitmiyor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(
          client: _stokluIstemci({'m-cI': 42, 'm-bI': 3}),
          onClose: () {},
        ),
      ),
    );
    await tester.pump();
    // MALZEME kendi sekmesinde: parçalamanın gittiği yeri görmek bir tıklama
    // uzakta ve bu kasıtlı — depo ile malzeme ayrı kaplar.
    await tester.tap(find.byKey(paneTabKey(HangarTab.materyal)).first);
    await tester.pump();

    // Rank ETİKETİ ve ADET birlikte: yalnız sayı, hangi rank olduğunu
    // söylemiyor ve malzemenin tek ayırt edici özelliği rankı.
    expect(find.text('C-I'), findsWidgets);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('B-I'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('stok BOŞKEN nereden geleceği yazıyor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: _stokluIstemci(const {}), onClose: () {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(paneTabKey(HangarTab.materyal)).first);
    await tester.pump();
    // "Yok" demek yetmiyor: oyuncuya nereden geleceğini söylemeyen bir boşluk,
    // sistemin bozuk olduğunu düşündürür.
    expect(
      find.textContaining('PARÇALA'),
      findsWidgets,
      reason: 'boş stok kaynağını söylemiyor',
    );
  });
}

/// Belirli bir malzeme stoğu taşıyan, AĞSIZ bir istemci.
///
/// Sunucu üzerinden malzeme biriktirmek bu testin konusu değil; ölçülen şey
/// ekranın stoğu GÖSTERİP göstermediği. Hangar haritası yine sunucunun
/// ürettiği biçimden geliyor (`Hangar.toJson`), elle kopya değil — kopya
/// olsaydı ekran, oyuncunun gördüğünden başka bir stoku çizebilirdi.
NetClient _stokluIstemci(Map<String, int> stok) {
  final hangar = Hangar(
    accountId: 'test',
    credits: 50000,
    hulls: [HullClass.starter.id],
    activeHullId: HullClass.starter.id,
    malzemeler: stok,
  );
  return NetClient(uri: Uri.parse('ws://test'))
    ..hangar = HangarView.fromJson(hangar.toJson());
}

/// ŞERİTTEKİ SAYILAR — neyi anlattıkları okunuyor mu.
void seritSayilari() {
  Future<void> kur(WidgetTester tester, {required int seviye}) async {
    final h = Hangar(
      accountId: 'a',
      credits: 50000,
      hulls: [HullClass.starter.id],
      activeHullId: HullClass.starter.id,
      inventory: {
        'i': ItemInstance(instanceId: 'i', specId: 'pl3', level: seviye),
      },
      loadouts: {
        HullClass.starter.id: Loadout(
          hullId: HullClass.starter.id,
          slots: {const SlotRef(SlotType.laser, 0).id: 'i'},
        ),
      },
    );
    final c = NetClient(uri: Uri.parse('ws://test'))
      ..hangar = HangarView.fromJson(h.toJson());
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: c, onClose: () {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(slotTileKey(const SlotRef(SlotType.laser, 0))));
    await tester.pump();
  }

  testWidgets('TAVANDAKİ parçada sıfırlar GÖSTERİLMİYOR', (tester) async {
    // Bulunan hata: düğme YÜKSELT'ken altındaki sayılar ona aitti; eylem
    // pencereye taşınıp düğme BİLGİ olunca sayılar sahipsiz kaldı. Tavandaki
    // bir parçada ise anlatacak bir şey de yoktu — ekranda
    // "BİLGİ / 0 / 72386/0 B-I" çıkıyordu.
    await kur(tester, seviye: ItemLevels.max);
    expect(
      find.textContaining('TAVAN'),
      findsOneWidget,
      reason: 'tavandaki parça tavanda olduğunu söylemiyor',
    );
    expect(
      find.text('YÜKSELTME'),
      findsNothing,
      reason: 'tavanda olmayan bir yükseltme anlatılıyor',
    );
  });

  testWidgets('yükseltilebilir parçada YÜKSELT yolu var', (tester) async {
    // Eskiden bu test ekranın altındaki ayrıntı şeridini ölçüyordu ve orada
    // "YÜKSELTME" diye bir başlık arıyordu. Şerit kalktı; yükseltmenin yeri
    // artık parçanın kendi penceresi. Ölçülen şey aynı kaldı: yükseltilebilir
    // bir parçada yükseltme yolu GÖRÜNÜYOR ve tavan yazısı YOK.
    await kur(tester, seviye: 0);
    expect(find.byType(ItemSheet), findsOneWidget, reason: 'pencere açılmadı');
    expect(
      find.text(Metin.yukselt(Dil.turkce)),
      findsOneWidget,
      reason: 'yükseltilebilir parçada YÜKSELT düğmesi yok',
    );
    expect(find.textContaining('TAVAN'), findsNothing);
  });
}

/// YÜKSELTME OKU — depoda "bu daha iyi" işareti.
void yukseltmeOku() {
  testWidgets('güçlü yedek OK taşıyor, zayıf taşımıyor', (tester) async {
    final h = Hangar(
      accountId: 'a',
      credits: 50000,
      hulls: [HullClass.starter.id],
      activeHullId: HullClass.starter.id,
      inventory: {
        'takili': const ItemInstance(instanceId: 'takili', specId: 'pl3'),
        'guclu': const ItemInstance(instanceId: 'guclu', specId: 'pl4'),
        'zayif': const ItemInstance(instanceId: 'zayif', specId: 'pl1'),
      },
      loadouts: {
        HullClass.starter.id: Loadout(
          hullId: HullClass.starter.id,
          slots: {const SlotRef(SlotType.laser, 0).id: 'takili'},
        ),
      },
    );
    final c = NetClient(uri: Uri.parse('ws://test'))
      ..hangar = HangarView.fromJson(h.toJson());
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: c, onClose: () {}),
      ),
    );
    await tester.pump();

    bool okVar(String id) =>
        tester.widget<EsyaHucresi>(find.byKey(depotTileKey(id))).yukseltme;

    expect(okVar('guclu'), isTrue, reason: 'güçlü yedekte ok yok');
    expect(okVar('zayif'), isFalse, reason: 'zayıf yedekte ok var');
    // TAKILI parça depoda HİÇ görünmüyor — ok taşıyıp taşımadığı sorusu
    // ortadan kalktı, çünkü kutucuğun kendisi yok. Kural bu testin bir
    // satırıydı, artık kabın tanımı: depo "elindekiler" demek.
    expect(
      find.byKey(depotTileKey('takili')),
      findsNothing,
      reason: 'takılı parça depoda görünüyor',
    );
  });

  testWidgets('takılı parçalar depoda HİÇ listelenmiyor', (tester) async {
    // Bu test bir zamanlar "iki parça takılıyken hiçbirinde ok yok" diyordu
    // ve okun takılı kutucuklarda çıkmadığını sınıyordu. Kutucuklar artık
    // hiç çizilmiyor: aynı parçanın donanım ızgarasında ve depoda birden
    // durması, "elindekiler" demesi gereken bir kabı elinde OLMAYAN şeyleri
    // de sayan bir listeye çeviriyordu — üstelik depodaki kopya tıklanamaz,
    // seçilemez, parçalanamazdı.
    //
    // Guard yön değiştirdi ama aynı hatayı yakalıyor: filtre kaldırılırsa
    // kutucuklar geri gelir ve bu test düşer.
    final h = Hangar(
      accountId: 'a',
      credits: 50000,
      hulls: [HullClass.starter.id],
      activeHullId: HullClass.starter.id,
      inventory: {
        'iyi': const ItemInstance(instanceId: 'iyi', specId: 'pl4'),
        'kotu': const ItemInstance(instanceId: 'kotu', specId: 'pl1'),
      },
      loadouts: {
        HullClass.starter.id: Loadout(
          hullId: HullClass.starter.id,
          slots: {
            const SlotRef(SlotType.laser, 0).id: 'iyi',
            const SlotRef(SlotType.laser, 1).id: 'kotu',
          },
        ),
      },
    );
    final c = NetClient(uri: Uri.parse('ws://test'))
      ..hangar = HangarView.fromJson(h.toJson());
    await tester.pumpWidget(
      MaterialApp(
        home: HangarScreen(client: c, onClose: () {}),
      ),
    );
    await tester.pump();

    for (final id in ['iyi', 'kotu']) {
      expect(
        find.byKey(depotTileKey(id)),
        findsNothing,
        reason: '$id takılı olduğu hâlde depoda görünüyor',
      );
    }
  });
}

/// ÇEVİRME ONAYI — iyi bir rolü kaybetmeden önceki tek engel.
void cevirmeOnayi() {
  testWidgets('iyileşen rolü çevirmek ONAY istiyor', (tester) async {
    // Kullanıcının gördüğü kayıp: iyi bir roll çektikten sonra alışkanlıkla
    // bir kez daha basmak. Çevirme geri alınamaz — yeni değer eskisinin
    // üstüne yazılıyor ve eski değer hiçbir yerde durmuyor.
    final ctx = await _bootScreen(tester, acilis: true);
    const slot = SlotRef(SlotType.laser, 0);
    final instanceId = ctx.net.hangar!.itemAt(slot)!;
    final spec = ctx.net.hangar!.specOf(instanceId)!;

    // ÇEVİRİCİ stoğu SUNUCUDAN kuruluyor.
    //
    // Çevirme artık kredi değil kaynak istiyor ve kaynak yalnız eşya
    // parçalayarak düşüyor. Testi önce oyuncunun yolundan yürütmeyi denedim —
    // mağazadan al, parçala — ve tutmadı: taze hesabın 30.000 kredisi var,
    // bir C-I eşya 12.000, yani iki parçalamaya ancak yetiyor. Yirmi çevirme
    // için 240.000 kredi gerekirdi.
    //
    // Kapının kendisi ÇEKİRDEKTE test ediliyor (`cevirme_test`); buranın
    // konusu onay penceresi. Kurulumu doğrudan yapmak, testi konusuna
    // odaklıyor.
    await tester.runAsync(() async {
      final hesap = await ctx.gateway.accounts.login(
        usernameOrEmail: 'Ada',
        password: testPassword,
      );
      ctx.gateway.hangars
          .of(hesap.id)
          .malzemeEkle(Malzeme.cevirmeFor(spec.tier), 200);
    });

    await tester.longPress(find.byKey(slotTileKey(slot)));
    await tester.pump();

    double deger() => LoadoutResolver.altStatlariFor(
      ctx.net.hangar!.instance(instanceId)!,
      spec,
      ctx.net.hangar!.activeHull,
    ).values.first;

    // İYİLEŞENE kadar çevir. İlk çevirmede uyarı YOK — kaybedilecek bir
    // kazanç henüz yok.
    expect(find.byKey(onayEtKey), findsNothing);
    var iyilesti = false;
    for (var i = 0; i < 20 && !iyilesti; i++) {
      final once = deger();
      await tester.tap(find.byKey(itemSheetRerollKey));
      await _settle(tester, ctx, () => deger() != once);
      iyilesti = deger() > once;
      if (!iyilesti) {
        // Uyarı çıktıysa geç: bu tur kötüleşti demek değil, önceki tur
        // iyileşmiş olabilir.
        if (find.byKey(onayEtKey).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(onayVazgecKey));
          await tester.pump();
        }
      }
    }
    expect(iyilesti, isTrue, reason: 'yirmi çevirmede hiç iyileşme olmadı');

    // Şimdi bir kez daha basmak ONAY istiyor.
    await tester.tap(find.byKey(itemSheetRerollKey));
    await tester.pump();
    expect(
      find.byKey(onayEtKey),
      findsOneWidget,
      reason: 'iyileşen rol uyarısız siliniyor',
    );

    // VAZGEÇ değeri KORUYOR.
    final korunan = deger();
    await tester.tap(find.byKey(onayVazgecKey));
    await tester.pump();
    expect(find.byKey(onayEtKey), findsNothing);
    expect(deger(), korunan, reason: 'vazgeçmek yine de çevirdi');
  });
}
