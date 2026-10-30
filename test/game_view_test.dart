@Tags(['disi'])
library;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/components/ship_component.dart';
import 'package:voidspace3/game/components/ship_swarm.dart';
import 'package:voidspace3/game/voidspace_game.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace_core/voidspace_core.dart';

import 'game_harness.dart';

/// Ağdan gelen dünyanın EKRANA dönüşü.
///
/// `multiplayer_test.dart` verinin doğru geldiğini kanıtlıyor; burada
/// kanıtlanan şey o verinin doğru sayıda düğüme ve doğru MALİYETE dönüştüğü.
void main() {
  // Atlas `rootBundle`'dan yükleniyor; varlık paketine erişim için bağlama
  // gerekli. `testWidgets` yerine düz `test` kullanılıyor çünkü bu testler
  // gerçek soketlerle çalışıyor ve sahte zaman istemiyoruz.
  TestWidgetsFlutterBinding.ensureInitialized();

  List<ShipComponent> shipsIn(VoidspaceGame game) =>
      game.world.children.query<ShipComponent>().toList();

  ShipSwarm swarmIn(VoidspaceGame game) =>
      game.world.children.query<ShipSwarm>().single;

  test(
    'uzak oyuncular sahneye girer ve çıkar',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final me = await connectClient(gateway, 'Ada');
      final other = await connectClient(gateway, 'Bora');
      addTearDown(me.dispose);

      await awaitPlaying([me, other]);
      final game = await bootGame(me);
      await pumpGame(game, 0.8, others: [other]);

      final ships = shipsIn(game);
      expect(ships, hasLength(2), reason: 'kendi gemin + bir uzak gemi');
      expect(ships.where((s) => s.isLocal), hasLength(1));

      // Uzak gemi sunucunun söylediği yerde (ara değer gecikmesi payıyla).
      final remote = ships.firstWhere((s) => !s.isLocal);
      final truth = gateway.zone.ships[other.entityId]!.state.position;
      expect(remote.position.x, closeTo(truth.x, 60));
      expect(remote.position.y, closeTo(truth.y, 60));

      final goneId = other.entityId;
      other.dispose();
      // Bekleme süresi boyunca gemi SAHNEDE KALIR — oyuncu dönebilir.
      await pumpGame(game, 0.5);
      expect(shipsIn(game), hasLength(2), reason: 'bekleme süresi çalışmıyor');

      await expireOrphan(gateway, goneId);
      await pumpGame(game, 0.8);
      expect(shipsIn(game), hasLength(1), reason: 'ayrılan gemi sahnede kaldı');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'KALABALIK tek toplu çizimden geçer — kare maliyetinin tavanı',
    () async {
      // Mimarinin tek cümlelik iddiası: kare başına çizim çağrısı gemi
      // sayısından BAĞIMSIZ. Ölçüldü (macOS Release, Impeller, 41 gemi):
      // prosedürel çizilen tek bir gemi 8 ms GPU, hepsi atlastan 0.9 ms.
      //
      // Bu test bir performans ölçümü değil, o iddianın yapısal kilidi: biri
      // "şu gemiyi özel çizelim" dediğinde burada kırmızıya döner.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final me = await connectClient(gateway, 'Ada');
      addTearDown(me.dispose);

      final crowd = <NetClient>[];
      for (var i = 0; i < 9; i++) {
        crowd.add(await connectClient(gateway, 'Pilot$i'));
      }
      addTearDown(() {
        for (final c in crowd) {
          c.dispose();
        }
      });

      await awaitPlaying([me, ...crowd]);
      final game = await bootGame(me);
      await pumpGame(game, 1.2, others: crowd);

      final ships = shipsIn(game);
      expect(ships.length, greaterThan(5), reason: 'kalabalık oluşmadı');

      // EKRANDAKİ HER gemi — kendi gemin dahil — aynı toplu çizimden geçer,
      // ve YALNIZ ekrandakiler geçer.
      final onScreen = ships.where((s) => s.isLocal || s.onScreen).length;
      expect(
        swarmIn(game).submittedShips,
        onScreen,
        reason: 'bir gemi toplu çizimin dışında ya da fazladan içinde',
      );
      // Sayı 3 → 4: silah yuvaları gövde hücresinden çıkıp kendi atlas
      // bloklarına taşındı, çünkü gemide görünen top sayısı oyuncunun taktığı
      // lazere göre değişiyor. Kilidin ANLAMI değişmedi: çağrı sayısı hâlâ
      // gemi sayısından bağımsız, sabit ve elle sayılabilir. Değişebilir bir
      // sayıya bakmak yerine sabite bakmak, "şu gemiyi özel çizelim" fikrini
      // hâlâ burada kırmızıya çeviriyor.
      expect(ShipSwarm.drawCallsPerFrame, 4);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test('ekran DIŞINDAKİ gemi çizilmez', () async {
    // İlgi alanı yarıçapı 2600 birim; telefonda dikey görüş alanı ~670 birim.
    // Sunucunun yolladığı gemilerin çoğu ekranda değil ve mobil GPU'da bedeli
    // en yüksek şey saydam dolgu — görünmeyeni çizmek doğrudan kare bütçesi.
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final me = await connectClient(gateway, 'Ada');
    final far = await connectClient(gateway, 'Uzak');
    addTearDown(me.dispose);
    addTearDown(far.dispose);

    await awaitPlaying([me, far]);
    final game = await bootGame(me);
    await pumpGame(game, 0.6, others: [far]);

    // Uzaktakini ilgi alanının içinde ama görüş alanının DIŞINA taşı.
    final mine = gateway.zone.ships[me.entityId]!;
    gateway.zone.ships[far.entityId]!.state = gateway
        .zone
        .ships[far.entityId]!
        .state
        .copyWith(position: mine.state.position + const Vec2(2000, 0));
    await pumpGame(game, 0.8, others: [far]);

    expect(
      far.entityId,
      isIn(me.remotes.ids),
      reason: 'ilgi alanının içinde kalmalı — test yanlış kurulmuş',
    );
    final node = shipsIn(game).firstWhere((s) => !s.isLocal);
    expect(
      node.onScreen,
      isFalse,
      reason: 'ekran dışı gemi çizilmeye devam ediyor',
    );
    expect(
      swarmIn(game).submittedShips,
      1,
      reason: 'yalnız kendi gemin toplu çizimde olmalı',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  /// Dokunmatikte ayrı bir ateş tuşu yok — bu testin koruduğu kural o.
  ///
  /// Gerçek sunucuyla koşuyor çünkü hedef seçimi ilgi alanındaki gemilere
  /// bakıyor: sahte bir istemciyle kurulan bu test, koruması gereken zinciri
  /// atlardı.
  Future<(VoidspaceGame, NetClient, NetClient)> duel({
    required bool touchControls,
  }) async {
    final gateway = await bootServer();
    addTearDown(gateway.stop);
    final me = await connectClient(gateway, 'Ada');
    final other = await connectClient(gateway, 'Bora');
    addTearDown(me.dispose);
    addTearDown(other.dispose);

    await awaitPlaying([me, other]);
    final game = await bootGame(me, touchControls: touchControls);
    await pumpGame(game, 0.8, others: [other]);
    return (game, me, other);
  }

  test(
    'dokunmatikte hedef seçmek ATEŞ açar',
    () async {
      final (game, me, other) = await duel(touchControls: true);
      expect(me.ship!.firing, isFalse, reason: 'hedefsiz ateş olamaz');

      game.cycleTarget();
      await pumpGame(game, 0.4, others: [other]);
      expect(game.targeting.hasTarget, isTrue, reason: 'hedef seçilemedi');
      expect(
        me.ship!.firing,
        isTrue,
        reason: 'parmakla oynarken üçüncü bir düğme istemiyoruz: hedef = ateş',
      );

      // Kilit bırakılınca ateş de kesilir — aksi hâlde gemi boşluğa ateş eder.
      game.targeting.clear();
      await pumpGame(game, 0.4, others: [other]);
      expect(me.ship!.firing, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  /// Dokunmatikte hedefin KENDİ KENDİNE değişmemesi.
  ///
  /// Telefonda dünyaya atılan tık, üstünde bir şey varsa onu sessizce
  /// hedefliyordu; parmak payı 30 birim olduğu için kalabalıkta neredeyse her
  /// tık yeni bir hedef yakalıyor, otomatik ateş de anında ona dönüyordu.
  /// Ekranda görünen şey "kilit kendi kendine geziniyor" idi.
  ///
  /// Aynı tıkın MASAÜSTÜNDE hâlâ seçmesi de sınanıyor: kural dokunmatiğe
  /// özel, ve fareyle hedefe tıklamak kalması gereken bir şey.
  test(
    'dokunmatikte dünyaya tık hedefi DEĞİŞTİRMEZ, masaüstünde değiştirir',
    () async {
      for (final touch in [true, false]) {
        final (game, me, _) = await duel(touchControls: touch);
        expect(game.targeting.hasTarget, isFalse, reason: 'temiz başlamalı');

        final id = me.remotes.ids.first;
        final pose = me.remotes.poseOf(id);
        expect(pose, isNotNull, reason: 'rakibin pozu gelmedi');

        // Tam ÜSTÜNE tık: payı bile gerektirmeyen, kasıtlı bir seçim.
        game.world.onTapWorld!(Vector2(pose!.x, pose.y));

        if (touch) {
          expect(
            game.targeting.hasTarget,
            isFalse,
            reason: 'dokunmatikte hedefi yalnız HEDEF düğmesi değiştirir',
          );
        } else {
          expect(game.targeting.selected, id);
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'klavyede hedef seçmek ateş AÇMAZ — F ayrı bir karar',
    () async {
      final (game, me, other) = await duel(touchControls: false);
      game.cycleTarget();
      await pumpGame(game, 0.4, others: [other]);

      expect(game.targeting.hasTarget, isTrue);
      expect(
        me.ship!.firing,
        isFalse,
        reason: 'masaüstünde nişan almak ile ateş etmek AYRI iki karar',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
