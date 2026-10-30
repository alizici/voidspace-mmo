@Tags(['disi'])
library;

import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace3/hud/reward_feed.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/ledger_store.dart';
import 'package:voidspace_server/zone.dart';

import 'game_harness.dart';

/// OYUNUN DÖNGÜSÜ — uçtan uca.
///
/// Bu dosyanın sorduğu tek soru: *vurmak para kazandırıyor mu, ve oyuncu bunu
/// görüyor mu?* Mağaza aylardır duruyordu ama kazanma yolu yoktu; kazanma yolu
/// olmayan bir mağaza, bir vitrin.
///
/// Zincirin tamamı ölçülüyor çünkü kopabileceği her yer ayrı bir katman:
/// simülasyon imhayı üretir, sunucu ödülü yazar, tel onu taşır, istemci
/// cüzdanı günceller, arayüz gösterir. Ortadan biri sessizce koparsa oyuncu
/// yalnız "para gelmiyor" der.
void main() {
  Future<void> until(bool Function() condition, {String? reason}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError(reason ?? 'koşul sağlanmadı');
  }

  /// Oyuncunun ateş menzilinde, canı bir yaylımda bitecek bir alien koyar ve
  /// [shooter]'ı ona kilitler.
  ///
  /// **Ateş SUNUCUNUN kendi tikinde çözülüyor**, testin çağırdığı bir
  /// `zone.step()`'te değil. İlk yazışta öyleydi ve yanlıştı: ödül `zone.shots`
  /// üzerinden dağıtılıyor ve o liste her adımın BAŞINDA temizleniyor, yani
  /// testin ürettiği imha sunucunun bir sonraki tikinde çoktan silinmiş
  /// oluyordu. Testler yine de geçiyordu — ama sekiz saniye sonraki yeniden
  /// doğuşta sunucunun KENDİ öldürmesi sayesinde. Yani ölçtükleri şey
  /// ölçmek istedikleri şey değildi.
  int placeWeakAlien(
    Zone zone,
    NetClient shooter, {
    required double near,
    int hull = 1,
  }) {
    final id = Protocol.alienIdBase + 1;
    final ship = zone.ships.values.firstWhere((s) => s.id == shooter.entityId);
    zone.aliens[id] = AlienSimState.spawn(
      AlienStats.spore,
      ship.state.position + Vec2(near, 0),
      1,
    ).copyWith(hull: hull.toDouble());
    // Girdi KUYRUĞA bırakılıyor; adımı sunucunun kendi saati atıyor.
    //
    // İstemci üzerinden ateşlemek işe yaramaz: girdiyi gönderen şey oyun
    // döngüsü ve testte oyun döngüsü yok. `zone.step()`'i elle çağırmak da
    // yanlış — ödül `zone.shots` üzerinden dağıtılıyor ve o liste her adımın
    // BAŞINDA temizleniyor, yani testin ürettiği imha sunucunun bir sonraki
    // tikinde silinmiş oluyor. Girdi kalıcı (`lastApplied`), o yüzden
    // bırakmak yetiyor.
    zone.enqueue(ship, ShipInput(seq: 900, weaponTarget: id, firing: true));
    return id;
  }

  testWidgets('alien imhası KREDİ ve NOVA kazandırır — cüzdana ve ekrana', (
    tester,
  ) async {
    // Gerçek soket ve gerçek sunucu `runAsync` İÇİNDE koşmak zorunda:
    // `testWidgets` sahte bir saat kuruyor ve onun altında `Future.delayed`
    // hiç tamamlanmıyor — test ağ beklerken sonsuza kadar asılı kalıyor.
    late int startCredits;
    late int startPremium;
    late Gateway gateway;
    late NetClient client;
    await tester.runAsync(() async {
      gateway = await bootServer();
      client = await connectClient(gateway, 'Ada');
      await awaitPlaying([client]);
      await until(() => client.hangar != null);

      startCredits = client.credits;
      startPremium = client.premium;

      placeWeakAlien(gateway.zone, client, near: 400);

      await until(
        () => client.credits > startCredits,
        reason: 'imha kredi kazandırmadı',
      );
    });
    addTearDown(gateway.stop);
    addTearDown(client.dispose);

    expect(startCredits, Hangar.startingCredits);
    expect(startPremium, Hangar.startingPremium);
    expect(
      client.credits - startCredits,
      AlienStats.spore.creditReward,
      reason: 'kredi ödülü katalogla uyuşmuyor',
    );
    expect(
      client.premium - startPremium,
      AlienStats.spore.premiumReward,
      reason: 'NOVA ödülü gelmedi — kıt para yalnız parayla alınır olmuş',
    );

    // Ekran da görmeli: görülmeyen ödül, olmayan ödül.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RewardFeed(client: client)),
      ),
    );
    await tester.pump();
    final shown = tester.widget<Text>(
      find.byKey(hudBalanceKey(Currency.credit)),
    );
    expect(
      shown.data,
      menuNumber(startCredits + AlienStats.spore.creditReward, Dil.turkce),
      reason: 'HUD cüzdanı sunucunun söylediğini göstermiyor',
    );
  });

  test('ödül SUNUCUDAN gelir — istemci kendi sayacını artırmaz', () async {
    // Cüzdanın istemcide artması, tek bir kayıp mesajın bakiyeyi kalıcı
    // olarak ayrıştırması demek. Ölçüt: istemcinin bakiyesi HER ZAMAN
    // sunucudaki hangarla birebir.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final client = await connectClient(gateway, 'Ada');
    addTearDown(client.dispose);
    await awaitPlaying([client]);
    await until(() => client.hangar != null);

    placeWeakAlien(gateway.zone, client, near: 400);
    await until(() => client.credits > Hangar.startingCredits);

    final server = gateway.hangars.of(
      gateway.zone.ships.values.first.accountId,
    );
    expect(client.credits, server.credits);
    expect(client.premium, server.premium);
  });

  test('oyuncu oyuncuyu öldürünce ödül YOK', () async {
    // İki hesabı olan biri kendi kendini öldürerek para basardı. PvP ödülü
    // ancak kaybedenden bir şey EKSİLTEREK dengelenebilir ve o ayrı bir
    // tasarım.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final hunter = await connectClient(gateway, 'Ada');
    addTearDown(hunter.dispose);
    final prey = await connectClient(gateway, 'Bora');
    addTearDown(prey.dispose);
    await awaitPlaying([hunter, prey]);
    await until(() => hunter.hangar != null && prey.hangar != null);

    final zone = gateway.zone;
    final a = zone.ships.values.firstWhere((s) => s.name == 'Ada');
    final b = zone.ships.values.firstWhere((s) => s.name == 'Bora');
    b.state = b.state.copyWith(
      position: a.state.position + const Vec2(300, 0),
      shield: 0,
      hull: 1,
    );
    // Ateş nişan yayına bağlı (zone.dart): avcı hedefe DÖNMÜŞ kuruluyor.
    // Bu testin konusu dönüş değil, PvP'de ödül verilmemesi.
    final d = b.state.position - a.state.position;
    a.state = a.state.copyWith(angle: math.atan2(d.x, -d.y));
    zone
      ..enqueue(a, ShipInput(seq: 50, weaponTarget: b.id, firing: true))
      ..step();

    expect(b.state.alive, isFalse, reason: 'kurulum tutmadı');
    // Birkaç tik geçsin ki ödül yolu koşacaksa koşsun.
    for (var i = 0; i < 5; i++) {
      zone.step();
    }
    expect(gateway.hangars.of(a.accountId).credits, Hangar.startingCredits);
    expect(gateway.hangars.of(a.accountId).premium, Hangar.startingPremium);
  });

  test('DEV_RICH listesindeki hesap zengin başlar', () async {
    // Geliştirme kolaylığı: mağazayı ve NOVA rafını grind etmeden sınamak.
    final gateway = await bootServer(devRich: {'Ada'});
    addTearDown(gateway.stop);
    final rich = await connectClient(gateway, 'Ada');
    addTearDown(rich.dispose);
    final plain = await connectClient(gateway, 'Bora');
    addTearDown(plain.dispose);
    await awaitPlaying([rich, plain]);
    await until(() => rich.hangar != null && plain.hangar != null);

    expect(rich.credits, Gateway.devRichCredits);
    expect(rich.premium, Gateway.devRichPremium);
    // Listede OLMAYAN hesap etkilenmiyor: bu bir ortam anahtarı, bir arka
    // kapı değil.
    expect(plain.credits, Hangar.startingCredits);
    expect(plain.premium, Hangar.startingPremium);
  });

  test('VAR OLAN hesabın envanteri korunur — yalnız bakiye yükselir', () {
    // İstek "var olan CINAR kullanıcısına tanımla" idi. Bakiyeyi yükseltirken
    // hangarı sıfırlamak, oyuncunun biriktirdiği her şeyi silmek olurdu — ve
    // bu, "parayı yükselt" isteğinin verebileceği en kötü cevap.
    //
    // Kayıt ESKİ biçimde (premium alanı yok): gerçek hesap tam olarak öyle.
    final json =
        Hangar.fresh(
            'KcTdvgsNSaIykbiA',
            const TxContext(id: 't', atMillis: 0),
          ).toJson()
          ..['credits'] = 31
          ..remove('premium');
    final existing = Hangar.fromJson(json);
    expect(existing.inventory, isNotEmpty, reason: 'kurulum tutmadı');
    final itemsBefore = existing.inventory.keys.toSet();
    final loadoutBefore = Map.of(existing.activeLoadout.slots);

    // Tabana çekme: `Gateway._applyDevRiches` ile aynı kural — ve artık
    // bakiyeye doğrudan yazılamıyor, yalnız deftere kayıt üreterek.
    const tx = TxContext(id: 'dev', atMillis: 0);
    existing
      ..adjust(
        Currency.credit,
        Gateway.devRichCredits - existing.credits,
        reason: LedgerReason.devGrant,
        txId: tx.id,
        atMillis: tx.atMillis,
      )
      ..adjust(
        Currency.premium,
        Gateway.devRichPremium - existing.premium,
        reason: LedgerReason.devGrant,
        txId: '${tx.id}:p',
        atMillis: tx.atMillis,
      );

    expect(existing.inventory.keys.toSet(), itemsBefore);
    expect(existing.activeLoadout.slots, loadoutBefore);
    expect(existing.hulls, contains(HullClass.starter.id));
  });

  test('DEV_RICH VARSAYILAN kapalı', () async {
    // En önemlisi bu. Açık unutulursa üretimde herkesin parası sonsuz olur
    // ve ekonomi diye bir şey kalmaz.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final client = await connectClient(gateway, 'Ada');
    addTearDown(client.dispose);
    await awaitPlaying([client]);
    await until(() => client.hangar != null);
    expect(client.credits, Hangar.startingCredits);
  });

  test('zengin başlangıç mağazanın EN PAHALISINI karşılıyor', () {
    // Sayının anlamı bu: her rafı sınayabilmek. Katalogla karşılaştırmak,
    // katalog büyüdüğünde sayının sessizce yetersiz kalmasını engelliyor.
    //
    // Ölçülen şey RAF — `Catalogue.items` merdivenden türetilen satılamaz üst
    // rankları da içeriyor ve onların fiyatı 13 milyara çıkıyor. Testin
    // sorduğu soru "mağazayı sınayabiliyor muyum", "merdivenin tepesini satın
    // alabiliyor muyum" değil.
    final priciestCredit = Catalogue.rafta
        .where((i) => i.currency == Currency.credit)
        .map((i) => Catalogue.priceOf(i).amount)
        // SATIŞTA olanlar: merdivenden türetilen kademelerin fiyatı yok.
        .followedBy(
          HullClass.all
              .where((h) => h.satinAlinabilir)
              .map((h) => Catalogue.hullPrice(h)!.amount),
        )
        .reduce((a, b) => a > b ? a : b);
    final priciestPremium = Catalogue.rafta
        .where((i) => i.currency == Currency.premium)
        .map((i) => Catalogue.priceOf(i).amount)
        .reduce((a, b) => a > b ? a : b);
    expect(Gateway.devRichCredits, greaterThan(priciestCredit * 100));
    expect(Gateway.devRichPremium, greaterThan(priciestPremium * 100));
  });

  test('ödül HASAR PAYINA göre bölünüyor — son vuruşa değil', () async {
    // Denetimin 4. maddesi. Önceki hâlde hasarın %99'unu veren değil, son
    // yaylımı atan alıyordu ("kill stealing"). İki oyuncu aynı aliene girdiği
    // gün hissedilen adaletsizlik bu.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final a = await connectClient(gateway, 'Ada');
    addTearDown(a.dispose);
    final b = await connectClient(gateway, 'Bora');
    addTearDown(b.dispose);
    await awaitPlaying([a, b]);
    await until(() => a.hangar != null && b.hangar != null);

    final zone = gateway.zone;
    final ada = zone.ships.values.firstWhere((s) => s.name == 'Ada');
    final bora = zone.ships.values.firstWhere((s) => s.name == 'Bora');
    const alienId = Protocol.alienIdBase + 1;
    zone.aliens[alienId] = AlienSimState.spawn(
      AlienStats.spore,
      ada.state.position + const Vec2(400, 0),
      1,
    );
    bora.state = bora.state.copyWith(position: ada.state.position);
    expect(ada.id, isNot(bora.id));

    // Ada hasarın ezici çoğunluğunu veriyor, Bora son vuruşu yapıyor.
    // Ateşi sunucunun kendi tiki çözüyor.
    zone.threatOf(alienId).add(ada.id, 9000);
    zone.aliens[alienId] = zone.aliens[alienId]!.copyWith(hull: 1);
    zone.enqueue(
      bora,
      ShipInput(seq: 900, weaponTarget: alienId, firing: true),
    );

    await until(() => a.credits > Hangar.startingCredits);
    final adaGain = a.credits - Hangar.startingCredits;
    final boraGain = b.credits - Hangar.startingCredits;

    expect(
      adaGain,
      greaterThan(boraGain),
      reason: 'son vuruşu yapan, hasarı vereni geçti',
    );
    expect(
      adaGain + boraGain,
      AlienStats.spore.creditReward,
      reason: 'yuvarlama ekonomiye para bastı ya da sızdırdı',
    );
  });

  test('ÖLÜM tamir bedeline mal oluyor — tek tekrarlayan sink', () async {
    // Denetimin 5-6. maddeleri, tek hamlede. Üç sink vardı ve üçü de tek
    // seferlik; musluk sınırsızdı. Ve ölüm bedava olduğu için alienlerin
    // yarattığı riskin hiçbir karşılığı yoktu.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final client = await connectClient(gateway, 'Ada');
    addTearDown(client.dispose);
    await awaitPlaying([client]);
    await until(() => client.hangar != null);

    final before = client.credits;
    final ship = gateway.zone.ships.values.first;
    // Gemiyi öldür: bedeli sunucunun kendi tiki kesiyor.
    ship.state = ship.state.copyWith(shield: 0, hull: 0);

    await until(
      () => client.credits < before,
      reason: 'ölüm hiçbir şeye mal olmadı',
    );
    expect(
      before - client.credits,
      HullClass.starter.repairCost,
      reason: 'tamir bedeli gövdeden türemiyor',
    );

    await gateway.ledger.flush();
    final entries = await gateway.ledger.readAll(accountId: ship.accountId);
    expect(
      entries.map((e) => e.reason),
      contains(LedgerReason.repair),
      reason: 'tamir bedeli deftere yazılmadı',
    );
  });

  test('bedel BAKİYEDEN fazla olamaz — borç bırakmıyor', () async {
    // Alımdaki "ya hep ya hiç" kuralının tersi ve sebebi farklı: orada
    // karşılığında bir mal var, burada karşılık yok — bu bir vergi.
    // Ödeyemeyeni borçlu bırakmak yerine sıfıra indirmek hem basit hem
    // affedici.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final client = await connectClient(gateway, 'Ada');
    addTearDown(client.dispose);
    await awaitPlaying([client]);
    await until(() => client.hangar != null);

    final ship = gateway.zone.ships.values.first;
    final hangar = gateway.hangars.of(ship.accountId);
    hangar.spend(
      Currency.credit,
      hangar.credits,
      reason: LedgerReason.purchase,
      txId: 'bosalt',
      atMillis: 0,
    );
    expect(hangar.credits, 0);

    ship.state = ship.state.copyWith(shield: 0, hull: 0);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    expect(hangar.credits, 0, reason: 'bakiye eksiye düştü');
  });

  test('HER para hareketi deftere düşüyor', () async {
    // Zengin hesap: raf 15.2'nin fiyatını istiyor ve başlangıç kredisi ona
    // yetmiyor (borç defteri B21); alım yolunun deftere yazması ölçülüyor,
    // oyuncunun parası değil.
    final gateway = await bootServer(devRich: {'Ada'});
    addTearDown(gateway.stop);
    final client = await connectClient(gateway, 'Ada');
    addTearDown(client.dispose);
    await awaitPlaying([client]);
    await until(() => client.hangar != null);

    final accountId = gateway.zone.ships.values.first.accountId;

    final oncesi = client.credits;
    placeWeakAlien(gateway.zone, client, near: 400);
    await until(() => client.credits > oncesi);

    client.hangarAction('buy_item', {'specId': 'pl1'});
    await until(() => client.hangar!.inventory.length > 1);

    await gateway.ledger.flush();
    final entries = await gateway.ledger.readAll(accountId: accountId);

    expect(
      gateway.hangars.of(accountId).pendingLedgerEntries,
      0,
      reason: 'hangarda boşaltılmamış kayıt kalmış',
    );
    expect(
      entries.map((e) => e.reason).toSet(),
      containsAll([
        LedgerReason.signup,
        LedgerReason.kill,
        LedgerReason.purchase,
      ]),
      reason: 'bir para yolu deftere yazmıyor',
    );

    // Defter KENDİ KENDİNİ denetliyor: son kaydın bakiyesi, gerçek bakiyeye
    // eşit olmalı. Tutmuyorsa arada bir kayıt kaybolmuş demektir.
    final hangar = gateway.hangars.of(accountId);
    for (final currency in Currency.values) {
      final last = entries.lastWhere((e) => e.currency == currency);
      expect(
        last.balanceAfter,
        hangar.balanceOf(currency),
        reason: '${currency.label} defteri bakiyeyle ayrışmış',
      );
    }

    // Kimlikler BENZERSİZ: tekrar, aynı hareketin iki kez işlendiğinin
    // imzası.
    expect(entries.map((e) => e.id).toSet(), hasLength(entries.length));
    expect(gateway.ledger.duplicates, 0);
  });

  test('tekrarlanan işlem kimliği REDDEDİLİR', () {
    // Çoğaltma açıklarının tel üzerindeki imzası bu. Sessizce ikinci kez
    // yazmak, defteri gerçeğin değil hatanın kaydı yapardı.
    final store = LedgerStore(path: '${Directory.systemTemp.path}/yok.jsonl');
    const entry = LedgerEntry(
      id: 'aynı',
      accountId: 'a',
      currency: Currency.credit,
      delta: 100,
      balanceAfter: 100,
      reason: LedgerReason.kill,
      atMillis: 0,
    );
    store.add([entry, entry]);
    expect(store.pending, 1, reason: 'aynı kimlik iki kez yazıldı');
    expect(store.duplicates, 1, reason: 'tekrar sessizce yutuldu');
  });

  group('kese ayrımı — ters ibraz', () {
    test('harcamada ÖNCE kazanılan gidiyor', () {
      // Satın alınan birim cüzdanda ne kadar uzun kalırsa, iade gerektiğinde
      // geri alınacak bakiye o kadar sağlam olur.
      final hangar = Hangar(accountId: 'a', credits: 0, premium: 100)
        ..topUp(50, txId: 'a1', atMillis: 0);
      expect(hangar.premium, 150);

      hangar.spend(
        Currency.premium,
        120,
        reason: LedgerReason.purchase,
        txId: 'a2',
        atMillis: 0,
      );
      expect(hangar.premiumEarned, 0, reason: 'kazanılan önce gitmedi');
      expect(hangar.premiumPurchased, 30);
    });

    test('geri alma EKSİYE inebiliyor ve deftere yazılıyor', () {
      // `earn` eksiyi yutuyor (kaza koruması) — bir geri almayı da yutardı.
      // Gerçek sistemler kullanılmış bir birimin ters ibrazında bakiyeyi
      // eksiye düşürüyor ve oyuncu yeniden satın alana kadar öyle kalıyor.
      final hangar = Hangar(accountId: 'a', credits: 0, premium: 0)
        ..topUp(100, txId: 'b1', atMillis: 0)
        ..spend(
          Currency.premium,
          100,
          reason: LedgerReason.purchase,
          txId: 'b2',
          atMillis: 0,
        );
      expect(hangar.premium, 0);

      hangar.adjust(
        Currency.premium,
        -100,
        reason: LedgerReason.clawback,
        txId: 'b3',
        atMillis: 0,
        detail: 'sipariş-1',
      );
      expect(hangar.premium, -100, reason: 'ters ibraz eksiye inemedi');

      final journal = hangar.takeJournal();
      expect(journal.last.reason, LedgerReason.clawback);
      expect(journal.last.delta, -100);
      expect(journal.last.detail, 'sipariş-1');
    });

    test('earn() kıt parayı KAZANILAN keseye yazıyor', () {
      // İmhadan gelen NOVA satın alınmış sayılamaz: ters ibrazda geri
      // alınacak şey oyuncunun oynayarak kazandığı olmamalı.
      final hangar = Hangar(accountId: 'a', credits: 0, premium: 0)
        ..earn(
          Currency.premium,
          7,
          reason: LedgerReason.kill,
          txId: 'c1',
          atMillis: 0,
        );
      expect(hangar.premiumEarned, 7);
      expect(hangar.premiumPurchased, 0);
    });
  });

  test('iki ekran aynı paraya AYNI rengi veriyor', () {
    // HUD `lib/hangar`'ı içeri alamıyor (menü, oyun ekranının parçası değil),
    // o yüzden renk eşlemesi iki yerde duruyor. Ayrışırlarsa aynı para
    // menüde bir, oyunda başka renk olur — oyuncunun neye baktığını
    // karıştırdığı türden bir hata.
    for (final currency in Currency.values) {
      expect(
        hudCurrencyColor(currency),
        currencyColor(currency),
        reason: '${currency.label} iki ekranda iki renk',
      );
    }
  });
}
