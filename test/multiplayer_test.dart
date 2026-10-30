@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/net/predicted_ship.dart';
import 'package:voidspace_core/voidspace_core.dart';

import 'game_harness.dart';

/// UÇTAN UCA: gerçek sunucu, gerçek soketler, gerçek tik saati.
///
/// Bu dosya olmadan bütün diğer testler yeşil olabilir ve oyun yine de
/// çalışmayabilir — çünkü netcode'un hataları parçalarda değil PARÇALARIN
/// ARASINDA yaşıyor: kodlayıcının yazdığını çözücünün başka okuması, sunucunun
/// onayladığı sıranın istemcinin beklediğiyle uyuşmaması, ara değer saatinin
/// kayması.
///
/// Yavaş (saniyeler sürer) ve öyle olmak zorunda: sahte zamanla ilerletilen
/// bir netcode testi, kanıtlaması gereken şeyin yanından geçer.
void main() {
  test('iki oyuncu birbirini görür', () async {
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final a = await connectClient(gateway, 'Ada');
    final b = await connectClient(gateway, 'Bora');
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await awaitPlaying([a, b]);
    await pump([a, b], 0.6);

    expect(a.entityId, isNot(b.entityId));
    expect(a.remotes.ids, contains(b.entityId));
    expect(b.remotes.ids, contains(a.entityId));
    // Ad snapshot'ta gitmiyor; ayrı ve güvenilir bir mesajla geliyor.
    expect(a.names[b.entityId], 'Bora');
    expect(b.names[a.entityId], 'Ada');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'bir oyuncunun hareketi ötekinde görünür',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final a = await connectClient(gateway, 'Ada');
      final b = await connectClient(gateway, 'Bora');
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await awaitPlaying([a, b]);
      await pump([a, b], 0.5);

      // Poz nesnesi yeniden kullanılıyor; karşılaştırma için değeri kopyala.
      final seenBeforeX = b.remotes.poseOf(a.entityId)!.x;
      final seenBeforeY = b.remotes.poseOf(a.entityId)!.y;
      a.ship!.axis = const Vec2(1, 0);
      await pump([a, b], 1.2);
      a.ship!.axis = Vec2.zero;
      await pump([a, b], 0.4);

      final seenAfter = b.remotes.poseOf(a.entityId)!;
      expect(
        seenAfter.x - seenBeforeX,
        greaterThan(150),
        reason: 'hareket replike edilmiyor',
      );
      expect(seenAfter.y, closeTo(seenBeforeY, 5));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('tahmin otoriteden KOPAMAZ', () async {
    // Netcode'un can damarı. Tahmin ile otorite ayrışırsa oyuncu ışınlanır;
    // burada ölçülen şey tam olarak o ayrışmanın büyüklüğü.
    //
    // Sapma ADIM cinsinden ölçülüyor, birim cinsinden değil — ve sınır
    // tasarımın kendisinden geliyor: istemci yalnız ONAYLANMAMIŞ girdileri
    // yeniden oynatır, o kuyruk da `PredictedShip.maxUnacked` ile kapalı.
    // Yani sunucu ne kadar tökezlerse tökezlesin sapma bu sayıyı aşamaz.
    //
    // (Bu testte sunucu 30 Hz'in altında koşuyor: `flutter test` sunucuyu,
    // iki istemciyi ve test döngüsünü TEK isolate'te barındırıyor. Bağımsız
    // süreçte ölçüm 30.0 Hz / tik başına ~40µs.)
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final a = await connectClient(gateway, 'Ada');
    addTearDown(a.dispose);

    await awaitPlaying([a]);
    // İlk snapshot'ı bekle. Doğuş noktası SUNUCUDAN geliyor; o gelene kadar
    // istemci geçici olarak haritanın ortasında duruyor ve aradaki 900 birim
    // bir sapma değil, henüz gerçekleşmemiş bir ışınlanma.
    await pump([a], 0.4);

    var worstDrift = 0.0;
    a.ship!.axis = const Vec2(1, -1);
    await pump(
      [a],
      2,
      each: () {
        final authoritative = gateway.zone.ships[a.entityId]?.state.position;
        if (authoritative == null) return;
        final drift = a.ship!.state.position.distanceTo(authoritative);
        if (drift > worstDrift) worstDrift = drift;
      },
    );

    // Sapma sıfır OLAMAZ: istemci daima birkaç tik ileride (gizlediği gecikme
    // kadar). Önemli olan SINIRLI kalması.
    //
    // Ölçülen: ~2 adım (≈21 birim — gövde genişliğinin beşte biri). Aşağıdaki
    // sınır o ölçüm değil SÖZLEŞME: 2'ye çekmek testi yüklü bir CI'da
    // titretirdi, ve zaten kırılması gereken şey "biraz kötüleşti" değil
    // "tavan delindi".
    final stepsAhead = worstDrift / (ShipStats.bastion.speed * ShipSim.fixedDt);
    expect(
      stepsAhead,
      lessThanOrEqualTo(PredictedShip.maxUnacked + 2),
      reason: 'tahmin otoriteden kopuyor → oyuncu ışınlanacak',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'hasarın hakemi SUNUCU — istemci yalnız niyet yollar',
    () async {
      // Hata ayıklama komutları AÇIKÇA açılıyor. Üretimde kapalılar (`ONAR` ölü
      // bir gemiyi tam sağlıkla geri getiriyor), ama otorite döngüsünü — hasarı
      // sunucu hesaplar, istemci yalnız niyet yollar — en yalın kanıtlayan yol
      // hâlâ bu. Testin bilerek açtığı kapı, herkese açık kapıdan farklıdır.
      final gateway = await bootServer(debugCommands: true);
      addTearDown(gateway.stop);
      final a = await connectClient(gateway, 'Ada');
      final b = await connectClient(gateway, 'Bora');
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await awaitPlaying([a, b]);
      await pump([a, b], 0.5);

      expect(a.ship!.state.shieldFraction, closeTo(1, 0.01));
      a.sendDebug(DebugCommandKind.damage);
      await pump([a, b], 0.5);

      // Kendi HUD'ında düşer…
      expect(a.ship!.state.shieldFraction, lessThan(0.95));
      // …ve ÖTEKİ oyuncunun gördüğü kalkan da düşer. İkisi de aynı tek
      // gerçekten, sunucudan geliyor.
      expect(b.remotes.poseOf(a.entityId)!.shieldFraction, lessThan(0.95));

      a.sendDebug(DebugCommandKind.repair);
      await pump([a, b], 0.5);
      expect(a.ship!.state.shieldFraction, closeTo(1, 0.02));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'yaylım uçtan uca: hasar iner, ATIŞ OLAYI iki uca da gelir',
    () async {
      // Silah zincirinin tamamı: istemci niyeti → sunucu doğrulaması → hasar →
      // olay → istemcinin çizeceği sayı. Aradaki her halka ayrı test edilmiş
      // durumda; bu test yalnız halkaların BİRBİRİNE bağlı olduğunu kanıtlıyor.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final a = await connectClient(gateway, 'Ada');
      final b = await connectClient(gateway, 'Bora');
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await awaitPlaying([a, b]);
      await pump([a, b], 0.5);

      // Doğuş noktaları menzilin (1400) DIŞINDA — altın açıyla dağıtılıyorlar.
      // Önce yaklaş, sonra kilitlen.
      a.ship!.moveTo(b.ship!.state.position);
      await pump([a, b], 2.2);
      final gap = a.ship!.state.position.distanceTo(b.ship!.state.position);
      expect(
        gap,
        lessThan(ShipStats.bastion.laser.range),
        reason: 'test menzile giremedi; ölçüm silahı değil yaklaşmayı ölçerdi',
      );

      a.ship!
        ..weaponTarget = b.entityId
        ..firing = true;
      await pump([a, b], 0.7);

      expect(
        b.ship!.state.shield,
        lessThan(ShipStats.bastion.maxShield),
        reason: 'hedefin kalkanı düşmedi',
      );

      // ATIŞ OLAYI: hasarı istemci hesaplamıyor, sunucu söylüyor.
      expect(a.shots, isNotEmpty, reason: 'ateş eden kendi vuruşunu görmeli');
      // Aranan atış SIRAYLA değil HEDEFLE bulunuyor. `first` varsayımı,
      // haritada A ile B'den başka hiçbir şey olmamasına dayanıyordu; boss
      // randevusu bağlandığında merkeze bir Kurvex doğdu ve listenin başına
      // ona atılan yaylım geçti.
      final shot = a.shots.firstWhere(
        (s) => s.targetId == b.entityId,
        orElse: () => throw StateError('B\'ye atılan yaylım yok'),
      );
      expect(shot.shooterId, a.entityId);
      // Hasar, ATICI'NIN KENDİ statlarından çıkıyor — referans gövdeden değil.
      // Sıfırdan başlayan bir hangar TEK lazerle geliyor ve yaylım o tek
      // namludan: `ShipStats.bastion` beş namlulu referans build ve buraya
      // yazılırsa test, oyuncunun sahip olmadığı bir gücü bekler.
      //
      // Eski hâli tam olarak bunu yapıyordu ve geçiyordu, çünkü sunucu da aynı
      // hatayı yapıyordu: tek lazerli gemi beş lazerlik hasar veriyordu.
      final taban = CombatGlossary.volley(a.ship!.state.stats).round();
      // Kritik zarı sunucuda atılıyor: hasar ya taban yaylım ya onun kritik
      // katı. Tek bir sayı beklemek, ölçtüğü şeyi zara bağımlı kılardı.
      expect(
        shot.damage,
        shot.crit
            ? (taban * a.ship!.state.stats.critMultiplier).round()
            : taban,
        reason: 'sunucunun söylediği hasar atıcının yaylımı değil',
      );
      expect(shot.shieldHit, isTrue, reason: 'ilk temas dolu kalkana');
      expect(shot.killed, isFalse);

      // Vurulan da görmeli: hasar sayısı iki tarafın ekranında da çıkar.
      expect(b.shots, isNotEmpty);
      expect(b.shots.first.targetId, b.entityId);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'ayrılan oyuncu ötekinin dünyasından silinir',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final a = await connectClient(gateway, 'Ada');
      final b = await connectClient(gateway, 'Bora');
      addTearDown(b.dispose);

      await awaitPlaying([a, b]);
      await pump([a, b], 0.5);
      expect(b.remotes.ids, contains(a.entityId));

      final goneId = a.entityId;
      a.dispose();
      await pump([b], 0.5);

      // Kopar kopmaz SİLİNMEZ: oyuncu birkaç saniye içinde dönerse aynı gemiye
      // kavuşmalı. İki saniyelik bir ağ kesintisinde gemiyi, konumu ve savaşı
      // kaybettirmek kabul edilebilir değil.
      expect(
        gateway.zone.ships.containsKey(goneId),
        isTrue,
        reason: 'bekleme süresi çalışmıyor',
      );

      // Süre dolunca gerçekten gider.
      await expireOrphan(gateway, goneId);
      await pump([b], 0.8);

      expect(gateway.zone.ships.containsKey(goneId), isFalse);
      expect(b.names.containsKey(goneId), isFalse);
      expect(b.remotes.poseOf(goneId), isNull);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('sürüm uyuşmazlığı reddedilir', () async {
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    // Protokol sürümü tel formatının kilidi: eski bir istemcinin yarı
    // çözülmüş çöp okuması, hata almasından çok daha kötü.
    final rogue = await connectRawClient(gateway, Protocol.version + 1);
    expect(rogue, isA<ServerRejected>());
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'bozuk çerçeve sunucuyu düşürmez',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      await sendGarbage(gateway);

      // Sunucu hâlâ ayakta ve yeni oyuncu kabul ediyor.
      final a = await connectClient(gateway, 'Ada');
      addTearDown(a.dispose);
      await awaitPlaying([a]);
      expect(a.phase, NetPhase.playing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
