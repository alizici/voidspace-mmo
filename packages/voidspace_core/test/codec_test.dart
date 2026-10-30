@Tags(['disi'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Tel formatı.
///
/// Elle yazılmış ikili bir protokolde en sinsi hata, kodlayıcı ile çözücünün
/// alan sırasında ayrışması: bağlantı kopmaz, sayılar sessizce saçmalar. Bu
/// dosya her mesajın gidiş-dönüşünü kilitler, yani ayrışma derlemede değil
/// burada yakalanır.
void main() {
  const stats = ShipStats.bastion;
  const world = GameWorld.standard;

  group('istemci → sunucu', () {
    test('Hello gidiş-dönüş', () {
      final decoded = ClientMessage.decode(
        const ClientHello(protocolVersion: 7, token: 'tok-Çınar-123').encode(),
      );
      expect(decoded, isA<ClientHello>());
      final hello = decoded as ClientHello;
      expect(hello.protocolVersion, 7);
      // ASCII dışı içerik: `str` UTF-8 olmasaydı burada bozulurdu.
      expect(hello.token, 'tok-Çınar-123');
    });

    test('Register ve Login gidiş-dönüş', () {
      final reg =
          ClientMessage.decode(
                const ClientRegister(
                  protocolVersion: 7,
                  email: 'ada@örnek.com',
                  username: 'Ada_99',
                  password: 'parola-uzun-yeter',
                ).encode(),
              )
              as ClientRegister;
      expect(reg.email, 'ada@örnek.com');
      expect(reg.username, 'Ada_99');
      expect(reg.password, 'parola-uzun-yeter');

      final login =
          ClientMessage.decode(
                const ClientLogin(
                  protocolVersion: 7,
                  username: 'Ada_99',
                  password: 'parola-uzun-yeter',
                ).encode(),
              )
              as ClientLogin;
      expect(login.username, 'Ada_99');
      expect(login.password, 'parola-uzun-yeter');
    });

    test('kimlik mesajları parolayı GÜNLÜĞE sızdırmaz', () {
      // Varsayılan `toString` bütün alanları basar. Bir istisna izi ya da
      // hata ayıklama satırı parolayı diske yazabilirdi.
      const reg = ClientRegister(
        protocolVersion: 7,
        email: 'ada@ornek.com',
        username: 'Ada',
        password: 'cok-gizli-parola',
      );
      expect(reg.toString(), isNot(contains('cok-gizli-parola')));
      const login = ClientLogin(
        protocolVersion: 7,
        username: 'Ada',
        password: 'cok-gizli-parola',
      );
      expect(login.toString(), isNot(contains('cok-gizli-parola')));
    });

    test('AuthOk ve AuthError gidiş-dönüş', () {
      final ok =
          ServerMessage.decode(
                const ServerAuthOk(token: 'abc123', username: 'Ada').encode(),
              )
              as ServerAuthOk;
      expect(ok.token, 'abc123');
      expect(ok.username, 'Ada');
      expect(
        (ServerMessage.decode(const ServerAuthError('parola yanlış').encode())
                as ServerAuthError)
            .reason,
        'parola yanlış',
      );
    });

    test('Input gidiş-dönüş — hedefli ve hedefsiz', () {
      final withTarget =
          ClientMessage.decode(
                const ClientInput(
                  seq: 4242,
                  input: ShipInput(
                    seq: 4242,
                    axis: Vec2(-1, 1),
                    moveTarget: Vec2(1234.5, 6789.25),
                    boost: true,
                  ),
                ).encode(),
              )
              as ClientInput;

      expect(withTarget.seq, 4242);
      expect(withTarget.input.axis.x, closeTo(-1, 0.01));
      expect(withTarget.input.axis.y, closeTo(1, 0.01));
      expect(withTarget.input.boost, isTrue);
      expect(withTarget.input.moveTarget!.x, closeTo(1234.5, 0.01));
      expect(withTarget.input.moveTarget!.y, closeTo(6789.25, 0.01));

      final plain =
          ClientMessage.decode(
                const ClientInput(seq: 1, input: ShipInput(seq: 1)).encode(),
              )
              as ClientInput;
      expect(plain.input.moveTarget, isNull);
      expect(plain.input.boost, isFalse);
      // Hedefsiz girdi çerçevesi: tip + seq + 2 eksen + bayrak + silah
      // hedefi (u16) = 10 bayt.
      expect(
        const ClientInput(seq: 1, input: ShipInput(seq: 1)).encode(),
        hasLength(10),
      );
    });

    test('Input silah niyetini taşır — kimlik ve ateş bayrağı', () {
      final armed =
          ClientMessage.decode(
                const ClientInput(
                  seq: 7,
                  input: ShipInput(seq: 7, weaponTarget: 4321, firing: true),
                ).encode(),
              )
              as ClientInput;
      expect(armed.input.weaponTarget, 4321);
      expect(armed.input.firing, isTrue);

      // Kilit var ama ateş kapalı: ikisi BAĞIMSIZ olmalı, yoksa hedef seçmek
      // ateş açmak anlamına gelirdi.
      final locked =
          ClientMessage.decode(
                const ClientInput(
                  seq: 8,
                  input: ShipInput(seq: 8, weaponTarget: 9),
                ).encode(),
              )
              as ClientInput;
      expect(locked.input.weaponTarget, 9);
      expect(locked.input.firing, isFalse);
    });

    test('Ping ve Debug gidiş-dönüş', () {
      expect(
        (ClientMessage.decode(const ClientPing(999).encode()) as ClientPing)
            .clientTimeMs,
        999,
      );
      expect(
        (ClientMessage.decode(
                  const ClientDebug(DebugCommandKind.repair).encode(),
                )
                as ClientDebug)
            .kind,
        DebugCommandKind.repair,
      );
    });
  });

  group('sunucu → istemci', () {
    test('Welcome gidiş-dönüş', () {
      final w =
          ServerMessage.decode(
                const ServerWelcome(
                  entityId: 17,
                  tickRate: 30,
                  snapshotRate: 30,
                  worldWidth: 12000,
                  worldHeight: 8000,
                  worldMargin: 140,
                ).encode(),
              )
              as ServerWelcome;
      expect(w.entityId, 17);
      expect(w.tickRate, 30);
      expect(w.worldWidth, 12000);
      expect(w.worldMargin, 140);
    });

    test('Ödül EKSİ tutarı da taşıyor — tamir bedeli', () {
      // Tamir bedeli aynı mesajla gidiyor. `u32` eksiyi taşıyamaz; maskeleyip
      // göndermek −120'yi 4.294.967.176 gibi gösterirdi, yani oyuncuya
      // dört milyarlık bir kazanç.
      for (final amount in [400, 0, -120, -1, 1 << 20]) {
        final back =
            ServerMessage.decode(
                  ServerReward(
                    sourceId: 9,
                    credits: amount,
                    premium: -amount,
                    balanceCredits: 5,
                    balancePremium: 6,
                  ).encode(),
                )
                as ServerReward;
        expect(back.credits, amount);
        expect(back.premium, -amount);
        expect(back.sourceId, 9);
        expect(back.balanceCredits, 5);
      }
    });

    // KARAR 14.1 s1
    test('Ganimet gidiş-dönüş: eşya listesi, malzeme rankı ve adedi', () {
      // Boş liste de telden geçmeli: yalnız malzeme düşen sıradan imha en
      // sık hâl. Aynı kimlik iki kez de gelebilir — boss üç eşya düşürüyor.
      for (final esyalar in [
        <String>[],
        ['pl2'],
        ['pl2', 'sg3', 'pl2'],
      ]) {
        final geri =
            ServerMessage.decode(
                  ServerGanimet(
                    sourceId: 40001,
                    esyalar: esyalar,
                    malzemeRank: 5,
                    malzeme: 2,
                  ).encode(),
                )
                as ServerGanimet;
        expect(geri.sourceId, 40001);
        expect(geri.esyalar, esyalar);
        expect(geri.malzemeRank, 5);
        expect(geri.malzeme, 2);
      }
    });

    test('Meta, Gone ve Rejected gidiş-dönüş', () {
      // Ad ve namlu sayısı BİRLİKTE doğrulanıyor: tel sırası (id, namlu, ad)
      // ile yapıcı sırası (id, ad, namlu) farklı ve yalnız adı ölçen bir test
      // sırayı karıştıran bir okuyucuyu geçirirdi.
      final meta =
          ServerMessage.decode(
                const ServerEntityMeta(3, 'Kaptan', 4, 6).encode(),
              )
              as ServerEntityMeta;
      expect(meta.id, 3);
      expect(meta.name, 'Kaptan');
      expect(meta.lasers, 4);
      // Kademe de aynı sebeple: telde namlu ile ad ARASINDA duruyor ve
      // okunmazsa adın baytları bir kayar.
      expect(meta.govde, 6);
      expect(meta.droidler, isEmpty);
      expect(meta.formasyon, 0);

      // Droid kademeleri ve formasyon da ad ile kademe ARASINDA: sayı
      // okunmazsa ad kayar. Değişken uzunluk: droid sayısı önce gidiyor.
      final droidli =
          ServerMessage.decode(
                const ServerEntityMeta(
                  7,
                  'Filo',
                  5,
                  2,
                  droidler: [1, 6, 3],
                  droidModelleri: [0, 3, 1],
                  formasyon: 13,
                ).encode(),
              )
              as ServerEntityMeta;
      expect(droidli.name, 'Filo');
      expect(droidli.droidler, [1, 6, 3]);
      expect(droidli.droidModelleri, [0, 3, 1]);
      expect(droidli.formasyon, 13);
      expect(
        (ServerMessage.decode(const ServerEntityGone(3).encode())
                as ServerEntityGone)
            .id,
        3,
      );
      expect(
        (ServerMessage.decode(const ServerRejected('sürüm eski').encode())
                as ServerRejected)
            .reason,
        'sürüm eski',
      );
    });

    test('Snapshot gidiş-dönüş — kendi gemi TAM, ötekiler kuantalı', () {
      var self = ShipSimState.spawn(stats, const Vec2(1111.5, 2222.25));
      self = ShipSim.applyDamage(
        self,
        1500,
      ).copyWith(angle: 1.234, thrust: 0.61, target: const Vec2(4000, 5000));

      // Konumlar DÜNYADAN türetiliyor, elle yazılmıyor: kuantalama aralığı
      // dünya genişliği ve sabit bir yayılım, harita ölçüsü değiştiğinde
      // sessizce kenarın dışına taşıp kelepçelenirdi — ve kelepçe hatası
      // kuantalama hatası gibi görünürdü.
      const adet = 24;
      final others = [
        for (var i = 0; i < adet; i++)
          EntitySnapshot.fromSim(
            i + 2,
            ShipSimState.spawn(
              stats,
              Vec2(world.width * i / adet, world.height * i / adet),
            ),
          ),
      ];

      final bytes = ServerSnapshot(
        serverTick: 90210,
        self: SelfSnapshot(acknowledgedSeq: 555, state: self),
        entities: others,
        worldWidth: world.width,
        worldHeight: world.height,
      ).encode();

      final back = ServerSnapshot.decodeWith(
        bytes,
        world.width,
        world.height,
        stats,
      );

      expect(back.serverTick, 90210);
      expect(back.self.acknowledgedSeq, 555);

      // Kendi gemi kuantalanmaz: üzerine yeniden oynatılacak, çizilmeyecek.
      expect(back.self.state.position.x, closeTo(1111.5, 0.001));
      expect(back.self.state.shield, closeTo(self.shield, 0.01));
      expect(back.self.state.target!.y, closeTo(5000, 0.001));

      expect(back.entities, hasLength(24));
      for (var i = 0; i < others.length; i++) {
        expect(back.entities[i].id, others[i].id);
        expect(
          back.entities[i].position.distanceTo(others[i].position),
          lessThan(0.25),
          reason: 'kuantalama hatası gövde genişliğinin binde ikisini aşmamalı',
        );
      }

      // Bütçe: bu paket saniyede 30 kez gidiyor.
      //
      // Bu TAM kayıt yolu — entity başına 14 bayt (13 + maske). Maske baytı
      // delta'nın bedeli ve yalnız burada görünüyor: tam kayıt ancak entity
      // ilgi alanına yeni girdiğinde gönderiliyor. SÜREKLİ durumda düz uçan
      // bir gemi 5 bayt (kimlik + maske + x), duran gemi 3 bayt ediyor.
      // Yani bir baytlık bu artış, sekiz baytlık kalıcı tasarrufun bedeli.
      expect(
        bytes.length,
        lessThan(420),
        reason: '24 görünür gemi TAM kayıtla 420 baytın altında kalmalı',
      );
    });

    test('nişan noktası kendi snapshot\'ında gidip gelir', () {
      // Taşınmazsa istemcinin yeniden oynatması hedefsiz bir gemi simüle eder
      // ve gövde her snapshot\'ta yön değiştirir — hem de tam ateş ederken.
      const stats = ShipStats.bastion;
      final aimed = ShipSimState.spawn(
        stats,
        const Vec2(1000, 1000),
      ).copyWith(weaponTarget: 12, aimPoint: const Vec2(2500, 900));

      for (final state in [aimed, aimed.copyWith(clearAim: true)]) {
        final w = ByteWriter();
        SelfSnapshot(acknowledgedSeq: 3, state: state).write(w);
        final back = SelfSnapshot.read(ByteReader(w.take()), stats).state;
        expect(back.aimPoint?.x, state.aimPoint?.x);
        expect(back.aimPoint?.y, state.aimPoint?.y);
      }
    });

    test('atış olayları snapshot ile gidip gelir', () {
      const stats = ShipStats.bastion;
      final self = ShipSimState.spawn(stats, const Vec2(600, 700));
      final shots = [
        const ShotEvent(
          shooterId: 7,
          targetId: 9,
          damage: 1000,
          shieldHit: true,
          killed: false,
        ),
        const ShotEvent(
          shooterId: 9,
          targetId: 7,
          damage: 340,
          shieldHit: false,
          killed: true,
        ),
      ];

      final bytes = ServerSnapshot(
        serverTick: 12,
        self: SelfSnapshot(acknowledgedSeq: 1, state: self),
        entities: [EntitySnapshot.fromSim(9, self)],
        worldWidth: world.width,
        worldHeight: world.height,
        shots: shots,
      ).encode();

      final back = ServerSnapshot.decodeWith(
        bytes,
        world.width,
        world.height,
        stats,
      );

      expect(back.shots, hasLength(2));
      expect(back.shots[0].shooterId, 7);
      expect(back.shots[0].targetId, 9);
      expect(back.shots[0].damage, 1000);
      expect(back.shots[0].shieldHit, isTrue);
      expect(back.shots[0].killed, isFalse);
      expect(back.shots[1].shieldHit, isFalse);
      expect(back.shots[1].killed, isTrue);
    });

    test('atış olayı 9 bayt — ve DÖRT bayrağı karışmaz', () {
      // Dördü de tek bayta sığdı: kalkan · imha · kritik · sıyırma. İki bitin
      // yer değiştirmesi, kalkan vuruşunu ölüm ya da sıradan vuruşu kritik
      // sanmak demek: sessiz ve yalnız ekranda görünür.
      //
      // Kritik ve sıyırma tel üzerinde SIFIR bayta mal oldu — `wireSize`
      // değişmedi. Rakamın rengi ile inen hasar tek kaynaktan geliyor ve
      // bunun bedeli yok.
      for (final shieldHit in [false, true]) {
        for (final killed in [false, true]) {
          for (final crit in [false, true]) {
            for (final grazed in [false, true]) {
              final w = ByteWriter();
              ShotEvent(
                shooterId: 1,
                targetId: 2,
                damage: 3,
                shieldHit: shieldHit,
                killed: killed,
                crit: crit,
                grazed: grazed,
              ).write(w);
              expect(w.length, ShotEvent.wireSize);
              final back = ShotEvent.read(ByteReader(w.take()));
              expect(back.shieldHit, shieldHit);
              expect(back.killed, killed);
              expect(back.crit, crit);
              expect(back.grazed, grazed);
            }
          }
        }
      }
    });

    test('TEL TAVANLARI — sessiz kelepçe ve sarma yok', () {
      // Dördü de bir zamanlar SESSİZDİ: hata düşmüyor, sayı bozuluyor. Sekiz
      // kademeli gövde merdiveni bu tavanların hepsini aşıyor, o yüzden her
      // biri protokol 11'de genişletildi ve burada kilitlendi.

      // 1 · Hasar. Tepe yaylım ~1.220.000; u16 tavanı 65.535'ti ve
      // `damage.clamp(0, 65535)` fark ettirmeden kesiyordu — üst kademelerde
      // ekrandaki her rakam donar, kritik ile sıradan vuruş aynı görünürdü.
      const tepeYaylim = 1220000;
      final w = ByteWriter();
      const ShotEvent(
        shooterId: 1,
        targetId: 2,
        damage: tepeYaylim,
        shieldHit: false,
        killed: false,
      ).write(w);
      expect(
        ShotEvent.read(ByteReader(w.take())).damage,
        tepeYaylim,
        reason: 'hasar telde kelepçelendi — u16 tavanına geri dönülmüş',
      );

      // 2 · Bakiye. Ömür boyu kredi musluğu 9.394.710.567 (alan 13); u32
      // 4.294.967.295'te SARIYORDU — ölçülen sonuç 804.775.975, yani cüzdan
      // on ikide birine iniyor ve hiçbir hata düşmüyordu.
      const omurBoyuKredi = 9394710567;
      const odul = ServerReward(
        sourceId: 1,
        credits: 1000,
        premium: 1,
        balanceCredits: omurBoyuKredi,
        balancePremium: 280800,
      );
      final geri = ServerMessage.decode(odul.encode()) as ServerReward;
      expect(
        geri.balanceCredits,
        omurBoyuKredi,
        reason: 'bakiye telde sarmış — u32 tavanına geri dönülmüş',
      );
      expect(geri.balancePremium, 280800);
      // Kazanç alanları u32 zigzag KALIYOR: tek olayın kazancı, toplam değil.
      expect(geri.credits, 1000);

      // 3 · İlan edilen boyut = yazılan boyut. İkisi ayrıştığında bant
      // genişliği bütçesi eksik ölçer ve tampon yeniden tahsis eder; ikisi de
      // sessiz, ikisi de yanlış.
      final we = ByteWriter();
      EntitySnapshot.writeFrom(
        we,
        7,
        ShipSimState.spawn(ShipStats.bastion, world.centre),
        world.width,
        world.height,
        Int32List(EntityDelta.fields),
      );
      expect(
        we.length,
        EntitySnapshot.wireSize,
        reason: 'EntitySnapshot ilan ettiği boyutu yazmıyor',
      );

      final wa = ByteWriter();
      const AlienSnapshot(
        id: 1,
        kind: 0,
        position: Vec2(5, 5),
        hullFraction: 1,
      ).write(wa, world.width, world.height);
      expect(
        wa.length,
        AlienSnapshot.wireSize,
        reason: 'AlienSnapshot ilan ettiği boyutu yazmıyor',
      );
    });

    test('alien listesi snapshot ile gidip gelir', () {
      const stats = ShipStats.bastion;
      final self = ShipSimState.spawn(stats, world.centre);
      final bytes = ServerSnapshot(
        serverTick: 5,
        self: SelfSnapshot(acknowledgedSeq: 1, state: self),
        entities: const [],
        worldWidth: world.width,
        worldHeight: world.height,
        aliens: const [
          AlienSnapshot(
            id: Protocol.alienIdBase + 3,
            kind: 0,
            position: Vec2(2500, 1750),
            hullFraction: 1,
          ),
          AlienSnapshot(
            id: Protocol.alienIdBase + 9,
            kind: 0,
            position: Vec2(11000, 7500),
            hullFraction: 0.4,
          ),
        ],
      ).encode();

      final back = ServerSnapshot.decodeWith(
        bytes,
        world.width,
        world.height,
        stats,
      );
      expect(back.aliens, hasLength(2));
      expect(back.aliens[0].id, Protocol.alienIdBase + 3);
      expect(back.aliens[0].kind, 0);
      expect(
        back.aliens[0].position.distanceTo(const Vec2(2500, 1750)),
        lessThan(0.25),
        reason: 'kuantalama hatası gövde genişliğinin binde ikisini aşmamalı',
      );
      expect(back.aliens[1].id, Protocol.alienIdBase + 9);
      expect(back.aliens[1].hullFraction, closeTo(0.4, 0.01));
    });

    test('alien nesne kurma ile elde yazma AYNI baytı üretir', () {
      // Sunucu hızlı yolu kullanıyor; iki yol ayrışırsa alienler sessizce
      // yanlış yerde belirir.
      const alien = AlienSnapshot(
        id: Protocol.alienIdBase + 12,
        kind: 0,
        position: Vec2(777, 3333),
        hullFraction: 0.72,
      );
      final viaObject = ByteWriter();
      alien.write(viaObject, world.width, world.height);

      // Sunucunun SICAK yolu: kuantala, sonra maskeyle yaz.
      final values = Int32List(AlienDelta.fields);
      AlienDelta.quantize(
        values,
        alien.kind,
        alien.position.x,
        alien.position.y,
        alien.hullFraction,
        world.width,
        world.height,
      );
      final viaStream = ByteWriter();
      AlienDelta.write(viaStream, alien.id, values, AlienDelta.full);

      expect(viaStream.length, AlienDelta.fullWireSize);
      expect(viaStream.take(), viaObject.take());
    });

    test('DEĞİŞMEYEN alien üç bayt eder', () {
      // Ölçüldü: alien'lerin %44'ü tikte hiç kıpırdamıyor, tür ve gövde ise
      // hiç değişmiyor. 8 baytlık kaydın çoğu tekrar.
      final values = Int32List(AlienDelta.fields);
      AlienDelta.quantize(values, 3, 1000, 2000, 1, world.width, world.height);
      final w = ByteWriter();
      AlienDelta.write(w, 0x8001, values, AlienDelta.maskOf(values, values));
      expect(w.length, 3);
    });

    test('alien delta gidiş-dönüş: tür ve gövde TEMELDEN gelir', () {
      final baseline = EntityBaseline();
      final before = Int32List(AlienDelta.fields);
      AlienDelta.quantize(
        before,
        5,
        3000,
        4000,
        0.5,
        world.width,
        world.height,
      );
      final full = ByteWriter();
      AlienDelta.write(full, 0x8002, before, AlienDelta.full);
      AlienSnapshot.read(
        ByteReader(full.take()),
        world.width,
        world.height,
        baseline,
      );

      final after = Int32List(AlienDelta.fields);
      AlienDelta.quantize(after, 5, 3400, 4000, 0.5, world.width, world.height);
      final delta = ByteWriter();
      AlienDelta.write(delta, 0x8002, after, AlienDelta.maskOf(after, before));
      final back = AlienSnapshot.read(
        ByteReader(delta.take()),
        world.width,
        world.height,
        baseline,
      );

      expect(back.position.x, closeTo(3400, 0.3));
      expect(back.position.y, closeTo(4000, 0.3), reason: 'y temelden');
      expect(back.kind, 5, reason: 'tür temelden');
      expect(back.hullFraction, closeTo(0.5, 0.01), reason: 'gövde temelden');
    });

    test('olaysız snapshot tek bayt sayaç ekler', () {
      const stats = ShipStats.bastion;
      final self = ShipSimState.spawn(stats, world.centre);
      final bytes = ServerSnapshot(
        serverTick: 1,
        self: SelfSnapshot(acknowledgedSeq: 0, state: self),
        entities: const [],
        worldWidth: world.width,
        worldHeight: world.height,
      ).encode();
      expect(
        ServerSnapshot.decodeWith(
          bytes,
          world.width,
          world.height,
          stats,
        ).shots,
        isEmpty,
      );
    });
  });

  group('kuantalama', () {
    test('konum hatası gövde genişliğinin altında', () {
      // Son iki değer dünyanın SINIRI: kuantalama aralığın tam ucunda da
      // dönmeli. Elle yazılmış olsalardı harita küçüldüğünde aralığın dışında
      // kalır ve test kelepçeyi ölçmeye başlardı.
      for (final v in [
        0.0,
        1.0,
        140.0,
        world.width / 2,
        world.width - 1,
        world.width,
      ]) {
        final back = Quantize.unposition(
          Quantize.position(v, world.width),
          world.width,
        );
        expect((back - v).abs(), lessThan(0.2));
      }
    });

    test('açı ±π sınırında sarılır, kopmaz', () {
      // -π ile +π aynı yön. Kuantalama bunları KOMŞU tutmalı, yoksa gemi
      // batıya bakarken her karede tam tur atar.
      final low = Quantize.angle(-math.pi);
      final high = Quantize.angle(math.pi);
      expect(low == 0 || low == 255, isTrue);
      expect(high == 0 || high == 255, isTrue);

      for (var k = -8; k <= 8; k++) {
        final a = k * math.pi / 8;
        final back = Quantize.unangle(Quantize.angle(a));
        final delta = math.atan2(math.sin(back - a), math.cos(back - a));
        expect(delta.abs(), lessThan(0.03), reason: '$a rad');
      }
    });

    test('açı ara değeri kısa yaydan gider', () {
      EntitySnapshot at(double angle) => EntitySnapshot(
        id: 1,
        position: Vec2.zero,
        angle: angle,
        thrust: 0,
        shieldFraction: 1,
        hullFraction: 1,
        alive: true,
        boosting: false,
      );

      // 175° → -175°: kısa yol 10°, uzun yol 350°. Düz `lerp` uzun yoldan
      // giderdi ve gemi tam tur atardı.
      final mid = EntitySnapshot.lerp(at(3.05), at(-3.05), 0.5);
      expect(mid.angle.abs(), greaterThan(3.0));
    });

    test('ara değer DÖRT bayrağı da taşır — ateş ve hedef düşmez', () {
      // `lerp` bir zamanlar yalnız `alive` ile `boosting`i taşıyordu; `firing`
      // ile `weaponTarget` varsayılanlarına düşüyordu. Sonuç: ara değer alınan
      // her uzak gemi ATEŞ ETMİYOR görünüyordu — namlu parlaması ve nişan
      // çizgisi yalnız tam kare denk geldiğinde çiziliyordu.
      //
      // Yorum "en yeni gerçek doğru olandır" diyordu ve doğruydu; eksik olan
      // şey kuralın kendisi değil, ikisinin unutulmasıydı.
      // DÖRT bayrağın dördü de a ile b arasında FARKLI: aynı olsalardı test
      // `a.alive` ile `b.alive` ayrımını yapamaz, bayrağı a'dan almaya
      // "sadeleştiren" bir düzenleme yeşil geçerdi.
      EntitySnapshot poz({
        required bool firing,
        required int target,
        required bool canli,
      }) => EntitySnapshot(
        id: 1,
        position: Vec2.zero,
        angle: 0,
        thrust: 0,
        shieldFraction: 1,
        hullFraction: 1,
        alive: canli,
        boosting: canli,
        firing: firing,
        weaponTarget: target,
      );

      for (final t in [0.0, 0.5, 1.0]) {
        final mid = EntitySnapshot.lerp(
          poz(firing: false, target: 0, canli: false),
          poz(firing: true, target: 42, canli: true),
          t,
        );
        expect(mid.firing, isTrue, reason: 't=$t · ateş bayrağı düştü');
        expect(mid.weaponTarget, 42, reason: 't=$t · hedef kimliği düştü');
        expect(mid.alive, isTrue, reason: 't=$t · canlılık a\'dan alınmış');
        expect(mid.boosting, isTrue, reason: 't=$t · itki a\'dan alınmış');
      }
    });

    test('u64 telde KÜÇÜK-SON, DÜŞÜK yarı önce — altın baytlar', () {
      // Sınır gidiş-dönüşleri tek başına yetmiyor: `setUint64`e "sadeleştiren"
      // simetrik bir mutasyon gidiş-dönüşü bozmaz ama TEL BİÇİMİNİ değiştirir
      // — ve sürüm hâlâ 11 olduğu için el sıkışma o istemciyi kabul eder.
      // Bayt dizisini kilitlemek, biçimi kilitlemenin tek yolu.
      //
      // Ayrıca `setUint64` web'de UnsupportedError atıyor; bu test VM'de
      // koştuğu için onu YAKALAMAZ, o yüzden biçim iddiası burada duruyor.
      final w = ByteWriter()..u64(0x0123456789ABCDEF);
      expect(
        w.take(),
        orderedEquals([0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01]),
        reason: 'u64 bayt sırası değişmiş — eski istemci çöp okur',
      );

      for (final v in [0, 1, 0xFFFFFFFF, 0x100000000, 9394710567]) {
        expect(ByteReader((ByteWriter()..u64(v)).take()).u64(), v);
      }
    });

    test('EKSİ kazanç bitsel işleçsiz çözülüyor — web tuzağı', () {
      // `_unzigzag` bir zamanlar `(v >> 1) ^ -(v & 1)` idi. VM'de doğru,
      // web'de DEĞİL: dart2js bit işleçlerini `(# ^ #) >>> 0` olarak derliyor,
      // yani −120 tamir bedeli tarayıcıda +4.294.967.176 olarak çözülüyordu.
      //
      // Bu test VM'de koşuyor ve o hâliyle de GEÇERDİ — asıl koruma
      // `_unzigzag`'in üstündeki gerekçe. Buradaki iddia, aritmetik biçimin
      // eksiyi doğru taşıdığını kilitliyor.
      for (final v in [-1, -2, -120, -12600000, -999999999, 0, 1, 120]) {
        final geri =
            ServerMessage.decode(
                  ServerReward(
                    sourceId: 1,
                    credits: v,
                    premium: 0,
                    balanceCredits: 29880,
                    balancePremium: 500,
                  ).encode(),
                )
                as ServerReward;
        expect(geri.credits, v, reason: 'kazanç $v telde bozuldu');
        expect(geri.balanceCredits, 29880);
      }
    });
  });

  _deltaTests();
  _fastPathParity();

  group('düşmanca girdi', () {
    test('bozuk çerçeve istisna fırlatmaz', () {
      // Ağdan gelen her şey düşmanca kabul edilir: çözücü çökerse tek bir
      // kötü niyetli paket sunucuyu düşürür.
      expect(
        ClientMessage.decode(Uint8List.fromList([])),
        isA<MalformedMessage>(),
      );
      expect(
        ClientMessage.decode(Uint8List.fromList([0xEE, 1, 2, 3])),
        isA<MalformedMessage>(),
      );
      // Doğru tip, eksik gövde: okuyucu tamponun dışına taşar.
      expect(
        ClientMessage.decode(Uint8List.fromList([Protocol.msgInput, 1])),
        isA<MalformedMessage>(),
      );
      expect(
        ServerMessage.decode(Uint8List.fromList([Protocol.msgWelcome])),
        isA<MalformedMessage>(),
      );
    });
  });
}

/// DELTA kodlaması — telin en çok bayt kazandıran katmanı.
void _deltaTests() {
  group('delta', () {
    const world = GameWorld.standard;

    Int32List quantOf(ShipSimState s) {
      final v = Int32List(EntityDelta.fields);
      EntityDelta.quantize(v, s, world.width, world.height);
      return v;
    }

    test('DEĞİŞMEYEN entity üç bayt eder', () {
      final ship = ShipSimState.spawn(ShipStats.bastion, const Vec2(500, 500));
      final v = quantOf(ship);
      final w = ByteWriter();
      EntityDelta.write(w, 42, v, EntityDelta.maskOf(v, v));
      // Kimlik (2) + maske (1). Tam kayıt 14 bayt.
      expect(w.length, 3);
    });

    test('yalnız x değişince beş bayt eder', () {
      final a = ShipSimState.spawn(ShipStats.bastion, const Vec2(500, 500));
      final b = a.copyWith(position: const Vec2(700, 500));
      final before = quantOf(a);
      final after = quantOf(b);
      final mask = EntityDelta.maskOf(after, before);
      expect(mask, EntityDelta.bitX, reason: 'yalnız x bitinin dönmesi gerek');

      final w = ByteWriter();
      EntityDelta.write(w, 42, after, mask);
      expect(w.length, 5, reason: 'kimlik 2 + maske 1 + x 2');
    });

    test('delta gidiş-dönüş: okunmayan alanlar TEMELDEN gelir', () {
      final a = ShipSimState.spawn(
        ShipStats.bastion,
        const Vec2(1000, 2000),
      ).copyWith(angle: 1.2, thrust: 0.8);
      final b = a.copyWith(position: const Vec2(1400, 2000));

      final baseline = EntityBaseline();
      // 1) Tam kayıt.
      final full = ByteWriter();
      EntityDelta.write(full, 7, quantOf(a), EntityDelta.full);
      final first = EntitySnapshot.read(
        ByteReader(full.take()),
        world.width,
        world.height,
        baseline,
      );
      expect(first.position.x, closeTo(1000, 0.3));
      expect(first.angle, closeTo(1.2, 0.03));

      // 2) Yalnız x değişti.
      final before = quantOf(a);
      final after = quantOf(b);
      final delta = ByteWriter();
      EntityDelta.write(delta, 7, after, EntityDelta.maskOf(after, before));
      final second = EntitySnapshot.read(
        ByteReader(delta.take()),
        world.width,
        world.height,
        baseline,
      );

      expect(second.position.x, closeTo(1400, 0.3), reason: 'x güncellenmedi');
      expect(
        second.position.y,
        closeTo(2000, 0.3),
        reason: 'y temelden gelmeli',
      );
      expect(second.angle, closeTo(1.2, 0.03), reason: 'açı temelden gelmeli');
      expect(second.thrust, closeTo(0.8, 0.01));
    });

    test('TEMELSİZ kısmi delta REDDEDİLİR', () {
      // Sessizce yanlış konum çizmektense çerçeveyi reddetmek doğru: temeli
      // olmayan bir entity için kısmi kayıt, protokolün bozulduğu anlamına
      // gelir ve o an fark edilmezse ekranda "ışınlanan gemi" olarak çıkar.
      final v = Int32List(EntityDelta.fields)..[EntityDelta.fx] = 1234;
      final w = ByteWriter();
      EntityDelta.write(w, 9, v, EntityDelta.bitX);
      expect(
        () => EntitySnapshot.read(
          ByteReader(w.take()),
          world.width,
          world.height,
          EntityBaseline(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('temel olmadan çözmek yalnız TAM kayıtla çalışır', () {
      final ship = ShipSimState.spawn(ShipStats.bastion, const Vec2(600, 700));
      final w = ByteWriter();
      EntityDelta.write(w, 3, quantOf(ship), EntityDelta.full);
      final back = EntitySnapshot.read(
        ByteReader(w.take()),
        world.width,
        world.height,
      );
      expect(back.id, 3);
      expect(back.position.x, closeTo(600, 0.3));
    });
  });
}

/// Hızlı yol ile nesne kuran yol AYNI baytı üretmeli.
///
/// Sunucu snapshot'ları ara nesne üretmeden yazıyor (saniyede ~49.000 kısa
/// ömürlü nesneden kaçınmak için). İki yol ayrışırsa hızlı yol sessizce bozuk
/// snapshot üretir ve bunu yalnız yük altındaki gerçek bir istemci fark eder.
void _fastPathParity() {
  test('elde yazma ile nesne kurma birebir aynı baytı üretir', () {
    const world = GameWorld.standard;
    var ship = ShipSimState.spawn(ShipStats.bastion, const Vec2(3333, 1777));
    ship = ShipSim.applyDamage(ship, 900).copyWith(angle: -2.1, thrust: 0.44);

    final viaObject = ByteWriter();
    EntitySnapshot.fromSim(
      77,
      ship,
    ).write(viaObject, world.width, world.height);

    final viaStream = ByteWriter();
    EntitySnapshot.writeFrom(
      viaStream,
      77,
      ship,
      world.width,
      world.height,
      Int32List(EntityDelta.fields),
    );

    expect(viaStream.take(), viaObject.take());
    expect(viaStream.length, EntityDelta.fullWireSize);
  });

  test('take() KOPYA döndürür — yeniden kullanılan yazıcı paketi bozmaz', () {
    // Bu tam olarak bir kez kırıldı: `take()` görünüm döndürüyordu ve yazıcı
    // yeniden kullanılınca soket kuyruğunda bekleyen paketin içeriği altından
    // değişiyordu.
    final w = ByteWriter()..u32(0xAABBCCDD);
    final first = w.take();
    w
      ..reset()
      ..u32(0x11223344);
    expect(first, Uint8List.fromList([0xDD, 0xCC, 0xBB, 0xAA]));
  });

  group('hangar durumu · effective', () {
    ShipStats donanim(List<String> lazerler) {
      final loadout = Loadout(hullId: HullClass.bastion.id);
      final envanter = <String, ItemInstance>{};
      for (var i = 0; i < lazerler.length; i++) {
        envanter['l$i'] = ItemInstance(instanceId: 'l$i', specId: lazerler[i]);
        loadout.equip(SlotRef(SlotType.laser, i), 'l$i');
      }
      return LoadoutResolver.resolve(loadout, envanter, Catalogue.byId);
    }

    test('HASAR alanı YAYLIM taşıyor — namlu başına değil', () {
      // Hangar ekranı bu alanı okuyor, HUD ise `CombatGlossary.volley`.
      // Ayrıştıklarında aynı gemi için iki sayı görünüyordu: beş PL-4'te
      // hangar 420, HUD 2.100.
      final tam = donanim(List.filled(5, 'pl4'));
      expect(
        ServerHangarState.effectiveOf(tam)['damage'],
        CombatGlossary.volley(tam),
        reason: 'hangar ile HUD aynı gemi için farklı hasar söylüyor',
      );
      expect(
        ServerHangarState.effectiveOf(tam)['damage'] as double,
        greaterThan(tam.laser.damage * 4),
        reason: 'namlu başına sayıya geri dönülmüş',
      );
    });

    test('ZAYIF ikinci lazer gösterilen hasarı DÜŞÜRMÜYOR', () {
      // Asıl zarar buradaydı. `LoadoutResolver` toplam tabanı namlu sayısına
      // böldüğü için, zayıf bir ikinci lazer takmak namlu ORTALAMASINI
      // düşürüyordu — arayüz, güçlenen oyuncuya zayıfladığını söylüyordu.
      final tek = donanim(['pl4']);
      final iki = donanim(['pl4', 'pl1']);

      final tekHasar = ServerHangarState.effectiveOf(tek)['damage'] as double;
      final ikiHasar = ServerHangarState.effectiveOf(iki)['damage'] as double;

      expect(
        ikiHasar,
        greaterThan(tekHasar),
        reason:
            'ikinci lazer takınca gösterilen hasar düştü '
            '($tekHasar → $ikiHasar) — namlu ortalamasına dönülmüş',
      );
      // Namlu başına sayı gerçekten DÜŞÜYOR: testin ayırt ediciliği bu.
      expect(iki.laser.damage, lessThan(tek.laser.damage));
    });

    test('TEK üretici — sunucu ve görsel referans aynı haritayı kuruyor', () {
      // Harita bir zamanlar iki yerde elle yazılıydı. Anahtar kümesi
      // ayrışırsa `HangarView.fromJson` sessizce eksik okur.
      final harita = ServerHangarState.effectiveOf(donanim(['pl4']));
      expect(harita.keys, containsAll(['hull', 'shield', 'speed', 'damage']));
    });
  });
}
