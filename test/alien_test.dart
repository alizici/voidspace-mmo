@Tags(['disi'])
library;

import 'dart:io';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/components/alien_swarm.dart';
import 'package:voidspace3/net/alien_entities.dart';
import 'package:voidspace_core/voidspace_core.dart';

import 'game_harness.dart';

/// Alien sürüsünün istemci tarafı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  kimlikBaglantisi();

  group('ara değer', () {
    AlienSnapshot at(int id, double x) =>
        AlienSnapshot(id: id, kind: 0, position: Vec2(x, 500), hullFraction: 1);

    test('iki örnek ARASINI hesaplar', () {
      // Son gelen örneğe oturtmak, saniyede otuz kez ışınlanan bir sürü demek.
      final aliens = AlienEntities()
        ..ingest(10, [at(1, 1000)])
        ..ingest(20, [at(1, 2000)]);

      expect(aliens.poseOf(1, 15)!.x, closeTo(1500, 0.5));
      expect(aliens.poseOf(1, 10)!.x, closeTo(1000, 0.5));
      expect(aliens.poseOf(1, 20)!.x, closeTo(2000, 0.5));
    });

    test('tamponun DIŞINDA son bilinen yerde durur', () {
      // Kestirim BİLEREK yok: duran bir alieni duvara sürer, paket gelince
      // geri çeker — donmaktan çirkin.
      final aliens = AlienEntities()..ingest(10, [at(1, 1000)]);
      expect(aliens.poseOf(1, 40)!.x, closeTo(1000, 0.5));
    });

    test('bayat iz DÜŞER', () {
      final aliens = AlienEntities()..ingest(1, [at(1, 500), at(2, 900)]);
      expect(aliens.count, 2);
      // 2 numara güncellenmiyor; bir saniye sonra düşmeli.
      aliens.ingest(1 + ShipSim.tickRate + 2, [at(1, 700)]);
      expect(aliens.ids, [1]);
    });

    test('geriye giden örnek yok sayılır', () {
      // Yeniden bağlanma sonrası eski bir çerçeve ara değeri geri sardırırdı.
      final aliens = AlienEntities()
        ..ingest(20, [at(1, 2000)])
        ..ingest(12, [at(1, 100)]);
      expect(aliens.poseOf(1, 20)!.x, closeTo(2000, 0.5));
    });
  });

  test('çizim yarıçapı ile simülasyon yarıçapı AYNI', () {
    // İkisi ayrışırsa alien çizildiğinden başka bir yerde "var" olur — tam
    // olarak namlu ağızlarında yaşanan hata sınıfı.
    expect(AlienStats.spore.radius, AtlasLayout.alienRadiusWorld);
  });

  test(
    'sunucudaki sürü İSTEMCİYE ulaşır ve çizilir',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final me = await connectClient(gateway, 'Ada');
      addTearDown(me.dispose);

      await awaitPlaying([me]);
      final game = await bootGame(me);
      await pumpGame(game, 1.0);

      expect(
        me.aliens.count,
        greaterThan(0),
        reason: 'ilgi alanında hiç alien yok — sunucu göndermiyor',
      );

      final swarm = game.world.children.query<AlienSwarm>().single;
      expect(
        swarm.submitted,
        greaterThan(0),
        reason: 'alienler geldi ama toplu çizime katılmadı',
      );
      expect(
        swarm.submitted,
        lessThanOrEqualTo(me.aliens.count),
        reason: 'ekran dışındakiler de çiziliyor',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'Tab alienleri de gezer ve ateş onları vurur',
    () async {
      // Bu tam olarak eksik olan şeydi: hedef döngüsü yalnız oyuncu gemilerini
      // geziyordu, alienler manzaraydı.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final me = await connectClient(gateway, 'Ada');
      addTearDown(me.dispose);

      await awaitPlaying([me]);
      final game = await bootGame(me);
      await pumpGame(game, 1.0);

      // En yakın hedefe kilitlen; ortalıkta oyuncu yok, yani bir alien olmalı.
      game.cycleTarget();
      await pumpGame(game, 0.3);
      expect(game.targeting.hasTarget, isTrue, reason: 'alien seçilemedi');
      expect(
        Protocol.isAlienId(game.targeting.selected),
        isTrue,
        reason: 'seçilen kimlik alien aralığında değil',
      );

      final alienId = game.targeting.selected;
      final before = gateway.zone.aliens[alienId]!.hull;

      me.ship!.firing = true;
      await pumpGame(game, 1.2);

      expect(
        gateway.zone.aliens[alienId]!.hull,
        lessThan(before),
        reason: 'kilit kuruldu ama hasar inmedi',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'ölen alien EKRANDAN da hemen kalkar',
    () async {
      // Sunucu ölen alieni anında snapshot'tan çıkarıyor, ama istemcinin izi
      // bir saniye daha yaşıyordu (`AlienEntities._staleTicks`) — oyuncunun
      // gördüğü gecikme buydu. Ölüm artık öldüren merminin çarptığı anda ilan
      // ediliyor.
      //
      // Ölçüm PENCERESİ dar ve olmak zorunda: bir saniyeden sonra iz zaten
      // bayatlayıp düşüyor, yani geniş bir bekleme hatayı gizler (ilk yazımda
      // gizledi de).
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final me = await connectClient(gateway, 'Ada');
      addTearDown(me.dispose);

      await awaitPlaying([me]);
      final game = await bootGame(me);
      await pumpGame(game, 1.0);

      game.cycleTarget();
      await pumpGame(game, 0.3);
      final alienId = game.targeting.selected;
      expect(Protocol.isAlienId(alienId), isTrue);

      // Gemiyi alienin DİBİNE koy: mermi uçuşu kısalsın ki ölüm ile bayatlama
      // arasındaki pencere geniş kalsın.
      final alien = gateway.zone.aliens[alienId]!;
      final ship = gateway.zone.ships[me.entityId]!;
      ship.state = ship.state.copyWith(
        position: alien.position + const Vec2(150, 0),
      );
      // Tek yaylımda ölecek kadar can bırak.
      gateway.zone.aliens[alienId] = alien.copyWith(hull: 50);

      me.ship!.firing = true;
      var elapsed = 0.0;
      while (gateway.zone.aliens[alienId]!.alive && elapsed < 3) {
        await pumpGame(game, 0.1);
        elapsed += 0.1;
      }
      expect(gateway.zone.aliens[alienId]!.alive, isFalse, reason: 'ölmedi');

      // Merminin varması için yeter, bayatlamanın (1 sn) devreye girmesi için
      // yetmez.
      await pumpGame(game, 0.45);
      expect(
        me.aliens.ids,
        isNot(contains(alienId)),
        reason: 'ölü alienin izi hâlâ ekranda — bir saniyelik ceset',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'canavarın ÜSTÜNE tıklamak onu hedef yapar, gemiyi göndermez',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final me = await connectClient(gateway, 'Ada');
      addTearDown(me.dispose);

      await awaitPlaying([me]);
      final game = await bootGame(me);
      await pumpGame(game, 1.0);

      // İlgi alanındaki bir alienin ÜSTÜNE tıkla.
      final alienId = me.aliens.ids.first;
      final pose = me.aliens.poseOf(alienId, me.remotes.renderTick)!;
      final before = me.ship!.state.position;

      game.world.onTapWorld!(Vector2(pose.x, pose.y));
      await pumpGame(game, 0.3);

      expect(
        game.targeting.selected,
        alienId,
        reason: 'tıklanan alien seçilmedi',
      );
      expect(
        me.ship!.state.target,
        isNull,
        reason: 'hedef seçmek aynı zamanda hareket emri olmamalı',
      );
      expect(
        (me.ship!.state.position - before).length,
        lessThan(5),
        reason: 'gemi canavarın üstüne uçtu',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'BOŞLUĞA tıklamak gemiyi gönderir',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final me = await connectClient(gateway, 'Ada');
      addTearDown(me.dispose);

      await awaitPlaying([me]);
      final game = await bootGame(me);
      await pumpGame(game, 0.6);

      final before = me.ship!.state.position;
      // Alienlerden UZAK bir nokta.
      game.world.onTapWorld!(Vector2(before.x + 400, before.y));
      await pumpGame(game, 0.8);

      expect(
        (me.ship!.state.position - before).length,
        greaterThan(100),
        reason: 'boşluğa tıklamak artık gemiyi hareket ettirmiyor',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

/// ─────────────────────────────────────────────────────────────────────────
/// KİMLİK BAĞLANTISI — istemci doğan yaratığı tanıyor mu.
///
/// Bu bölüm bir BAĞLANTI hatasından doğdu, davranış hatasından değil. Kadro
/// eklendi, sunucu otuz iki türü doğurmaya başladı, ama istemcinin iki ayrı
/// yeri hâlâ `AlienStats.byKind`'a soruyordu — o da tanımadığı kimliği
/// sessizce spore'a düşürüyor. Serpilen on beş yaratığın sıfırı doğru
/// çözülüyordu ve tek bir test kırmızıya dönmemişti.
///
/// Davranışı test etmek bunu yakalamıyor: test kendi `kind`'ını geçiyor,
/// çizici de ona doğru cevap veriyor. Yakalayan tek şey KAYNAĞA bakmak —
/// çağrının hangi tabloyu okuduğu.
void kimlikBaglantisi() {
  group('istemci kimlik bağlantısı', () {
    /// Dosyayı YORUMSUZ oku.
    ///
    /// Kaynak muhafızının zaafı: metin araması kod ile yorumu ayırt etmiyor.
    /// İlk hâli tam buna takıldı — kaldırılan çağrıyı ANLATAN yorum, çağrının
    /// kendisi sayıldı ve test yanlış yere kırmızıya döndü. Yorumu atınca
    /// muhafız yalnız çalışan koda bakıyor.
    String oku(String yol) => File(yol)
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

    test('tıklama yarıçapı KADRODAN geliyor', () {
      final kaynak = oku('lib/game/voidspace_game.dart');
      final govde = kaynak.substring(kaynak.indexOf('double _tapRadius('));
      final metot = govde.substring(0, govde.indexOf('\n  }'));
      expect(
        metot,
        contains('YaratikKadrosu.yaricapFor'),
        reason: 'tıklama yarıçapı kadroyu okumuyor',
      );
      expect(
        metot,
        isNot(contains('AlienStats.byKind')),
        reason: 'sessizce spore\'a düşüren eski çağrı geri geldi',
      );
    });

    test('çizim ölçeği ve can çubuğu MODELDEN geliyor', () {
      final kaynak = oku('lib/game/components/alien_swarm.dart');
      final govde = kaynak.substring(kaynak.indexOf('void submit('));
      final metot = govde.substring(
        0,
        govde.indexOf('\n  void _submitLeviathan'),
      );
      expect(
        metot,
        contains('YaratikKadrosu.yaricapFor'),
        reason: 'çizim yarıçapı kadroyu okumuyor',
      );
      expect(
        metot,
        isNot(contains('AlienStats.spore.radius')),
        reason: 'can çubuğu yine tek bir sanat sabitine bağlı',
      );
    });

    test('ölçek gerçekten yaratıktan yaratığa DEĞİŞİYOR', () {
      // Kaynak muhafızı "doğru tabloyu okuyor" der, "sonuç farklı" demez.
      // Serpilen kadroda en az iki ayrı yarıçap olmazsa bütün iş boşa gider.
      final serpilen = YaratikKadrosu.serpilenler(Turetilenler.bolgeSayisi);
      final yaricaplar = serpilen.map((y) => y.yaricap).toSet();
      expect(
        yaricaplar.length,
        greaterThan(1),
        reason: 'kadroda tek yarıçap var; boy ayrımı görünmez',
      );
    });
  });
}
