@Tags(['disi'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/harita_kaydi.dart';
import 'package:voidspace_server/zone.dart';

/// GEÇİŞ — portalın uçtan uca zinciri.
///
/// Buradaki testler tasarım katmanını değil OYNANIŞI ölçüyor: gemi gerçekten
/// başka bir hücreye geçiyor mu, kapı kapalıyken durduruyor mu, ve geride
/// kalan hücre kapanıyor mu. Tasarım katmanının doğruluğu `gecit_test.dart`
/// içinde (çekirdek); burada onun sunucuya bağlandığı yer sınanıyor.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_gecit'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Bağlı bir oyuncusu olan sunucu.
  Future<(Gateway, WebSocket, List<Uint8List>, Account)> kur() async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);

    final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    final account = await gateway.accounts.register(
      email: 'ada@test.local',
      username: 'Ada',
      password: 'yeterince-uzun-parola',
    );
    final gelen = <Uint8List>[];
    socket.listen(
      (d) => gelen.add(Uint8List.fromList(d as List<int>)),
      onError: (_) {},
      onDone: () {},
    );
    socket.add(
      ClientHello(
        protocolVersion: Protocol.version,
        token: gateway.accounts.issueToken(account),
      ).encode(),
    );
    await _until(() => gateway.zone.ships.isNotEmpty);
    return (gateway, socket, gelen, account);
  }

  /// Gemiyi [gecit]'in üstüne koy — oyuncunun oraya uçmasının kısayolu.
  void gecideKoy(Gateway gateway, Gecit gecit) {
    final gemi = gateway.zone.ships.values.single;
    gemi.state = gemi.state.copyWith(position: gecit.konum);
  }

  Gecit gecitBul(Harita kaynak, HaritaTipi hedefTipi) =>
      GecitAgi.gecitleriFor(kaynak).firstWhere((g) => g.hedef.tip == hedefTipi);

  group('geçiş · bölge içi', () {
    test('geçitten geçen oyuncu HEDEF hücrede beliriyor', () async {
      final (gateway, socket, _, _) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      gecideKoy(gateway, gecit);

      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);

      final hedef = gateway.defter[gecit.hedef].hucre!;
      expect(hedef.ships, hasLength(1));
      // Çıkış GİRİŞİN KARŞI kenarı — ağın tek kuralı, uçtan uca.
      expect(hedef.ships.values.single.state.position, gecit.cikisKonumu);
    });

    test(
      'geride kalan hücre KAPANIYOR — simülasyon durur, base kalır',
      () async {
        final (gateway, socket, _, _) = await kur();
        final gecit = gecitBul(Harita.baslangic, HaritaTipi.boss);
        gecideKoy(gateway, gecit);
        // Başlangıç haritası bilerek kalıcı; ondan çıkıp GERİ dönerek ölçüyoruz.
        socket.add(const ClientGecit().encode());
        await _until(() => gateway.defter[gecit.hedef].canli);

        final donus = GecitAgi.donusFor(gecit);
        final gemi = gateway.defter[gecit.hedef].hucre!.ships.values.single;
        gemi.state = gemi.state.copyWith(position: donus.konum);
        socket.add(const ClientGecit().encode());

        await _until(() => !gateway.defter[gecit.hedef].canli);
        expect(gateway.defter[gecit.hedef].hucre, isNull);
        expect(gateway.defter[Harita.baslangic].hucre!.ships, hasLength(1));
      },
    );

    test('sağlık TAŞINIYOR — geçit onarım istasyonu değil', () async {
      final (gateway, socket, _, _) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      final gemi = gateway.zone.ships.values.single;
      final yarali = gemi.state.stats.maxHull * 0.4;
      gemi.state = gemi.state.copyWith(position: gecit.konum, hull: yarali);

      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);

      final sonra = gateway.defter[gecit.hedef].hucre!.ships.values.single;
      expect(sonra.state.hull, closeTo(yarali, 0.01));
    });

    test('yeni harita YENİ kimlik veriyor — aralıklar ayrı', () async {
      final (gateway, socket, _, _) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      final onceki = gateway.zone.ships.values.single.id;
      gecideKoy(gateway, gecit);

      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);

      final yeni = gateway.defter[gecit.hedef].hucre!.ships.values.single.id;
      expect(yeni, isNot(onceki));
      // Kimlik hangi haritada olduğunu ele veriyor.
      final pay = HaritaKaydi.kimlikAraligi;
      expect((yeni - 1) ~/ pay, Harita.hepsi.indexOf(gecit.hedef));
    });
  });

  group('geçiş · kapı', () {
    test('geçidin ÜSTÜNDE değilken reddediliyor', () async {
      final (gateway, socket, gelen, _) = await kur();
      // Gemi haritanın ortasında; hiçbir geçidin menzilinde değil.
      gelen.clear();
      socket.add(const ClientGecit().encode());
      await _until(
        () => gelen.any((b) => b.isNotEmpty && b[0] == Protocol.msgGecitRed),
      );
      // Hiçbir hücre açılmadı: reddedilen geçiş yan etki bırakmıyor.
      expect(gateway.defter.canlilar, hasLength(1));
    });

    test('BR yetmeyen bölgeye geçilemiyor — kapı sunucuda', () async {
      final (gateway, socket, gelen, _) = await kur();
      final ileri = GecitAgi.gecitleriFor(
        Harita.baslangic,
      ).where((g) => g.yon == GecitYonu.dogu).toList();
      // İlk bölgenin doğu kapısı ikinci bölgeye açılıyor ve yeni oyuncunun
      // savaş puanı yetmiyor.
      expect(ileri, hasLength(1));
      gecideKoy(gateway, ileri.single);
      gelen.clear();
      socket.add(const ClientGecit().encode());
      await _until(
        () => gelen.any((b) => b.isNotEmpty && b[0] == Protocol.msgGecitRed),
      );
      expect(gateway.defter[ileri.single.hedef].canli, isFalse);
      expect(gateway.zone.ships, hasLength(1), reason: 'oyuncu kayboldu');
    });
  });

  group('geçiş · kimlik kaydı', () {
    test(
      'oyuncu KENDİ meta\'sını da alıyor — ışınlar yoksa çizilemiyor',
      () async {
        // Bulunan hata: geçişten sonra gemi ateş ediyor ama hiçbir ışın
        // görünmüyordu. `ServerEntityMeta` adın yanında NAMLU SAYISINI taşıyor;
        // geçişte kendi kaydı atlanınca istemcinin elinde çizecek sayı kalmıyor.
        // Hangarda lazer takıp çıkarmak düzeltiyordu — çünkü o işlem meta'yı
        // yeniden yolluyor. Yani hata kalıcı değil ama görünmez.
        final (gateway, socket, gelen, _) = await kur();
        final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
        gecideKoy(gateway, gecit);
        gelen.clear();
        socket.add(const ClientGecit().encode());
        await _until(() => gateway.defter[gecit.hedef].canli);
        await _until(
          () => gelen.any((b) => b.isNotEmpty && b[0] == Protocol.msgHarita),
        );

        final yeniKimlik = gateway.defter[gecit.hedef].hucre!.ships.keys.single;
        final metalar = <int>[];
        for (final b in gelen) {
          if (b.isEmpty || b[0] != Protocol.msgEntityMeta) continue;
          final m = ServerMessage.decode(b);
          if (m is ServerEntityMeta) metalar.add(m.id);
        }
        expect(
          metalar,
          contains(yeniKimlik),
          reason: 'oyuncu yeni haritadaki kendi kaydını almadı',
        );
      },
    );
  });

  group('geçiş · kalıcılık', () {
    test('geçiş HANGARA yazılıyor', () async {
      final (gateway, socket, _, account) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      gecideKoy(gateway, gecit);
      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);

      expect(gateway.hangars.of(account.id).haritaId, gecit.hedef.id);
    });

    test('YENİDEN giren oyuncu bıraktığı haritada uyanıyor', () async {
      // Bu testin ölçtüğü şey oturumun ötesi: sahipsiz gemi bekleme süresi
      // dolmuş, yani "kopan oyuncu geri döner" yolu DEĞİL kayıt yolu işliyor.
      final (gateway, socket, _, account) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.boss);
      gecideKoy(gateway, gecit);
      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);

      // Gemiyi tamamen kaldır: dünyada hiçbir iz kalmasın.
      final hedefHucre = gateway.defter[gecit.hedef].hucre!;
      hedefHucre.leave(hedefHucre.ships.keys.single);
      await socket.close();

      final ikinci = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
      ikinci.listen((_) {}, onError: (_) {}, onDone: () {});
      addTearDown(ikinci.close);
      ikinci.add(
        ClientHello(
          protocolVersion: Protocol.version,
          token: gateway.accounts.issueToken(account),
        ).encode(),
      );

      await _until(
        () => gateway.defter[gecit.hedef].hucre?.ships.isNotEmpty ?? false,
      );
      expect(
        gateway.defter[gecit.hedef].hucre!.ships,
        hasLength(1),
        reason: 'oyuncu bıraktığı haritada uyanmadı',
      );
    });
  });

  group('geçiş · menzil', () {
    test('KENARDA duran oyuncu geçebiliyor — tahmin payı', () {
      // Bildirilen hata: "geçit menzilinde değilsin" alan oyuncu kapının
      // içindeydi. İki sebebi vardı ve bu ikincisi — istemci kendi gemisini
      // sunucunun bildiği yerin ÖNÜNDE çiziyor, yani sınıra yakın her deneme
      // sunucuda menzil dışına düşüyordu.
      //
      // Payın türetildiği yeri sınıyoruz, değerini değil: pencere ya da hız
      // değişirse test de onunla değişmeli.
      final pay = Zone.maxPending * ShipStats.bastion.speed / Protocol.tickRate;
      expect(pay, greaterThan(0));
      // Pay yarıçapın yarısından büyük olmalı ki sınır gerçekten yumuşasın,
      // ama yarıçaptan küçük kalmalı ki kapı bir yer olmaktan çıkmasın.
      expect(pay, greaterThan(GecitAgi.yaricap * 0.25));
      expect(pay, lessThan(GecitAgi.yaricap));
    });

    test('UZAKTAN ışınlanma hâlâ imkânsız', () {
      // Payın kabul edilebilir olmasının tek sebebi ölçeği: 64 birim, harita
      // 11.288. Bu oran bozulursa pay bir kapı olmaktan çıkıp bir bölge olur.
      final pay = Zone.maxPending * ShipStats.bastion.speed / Protocol.tickRate;
      final menzil = GecitAgi.yaricap + pay;
      expect(
        menzil / Harita.baslangic.dunya.height,
        lessThan(0.05),
        reason: 'geçiş menzili haritaya göre büyüdü',
      );
    });

    test('geçidin ORTASINDA duran her zaman geçebiliyor', () async {
      final (gateway, socket, gelen, _) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      gecideKoy(gateway, gecit);
      gelen.clear();
      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);
      expect(
        gelen.any((b) => b.isNotEmpty && b[0] == Protocol.msgGecitRed),
        isFalse,
        reason: 'ortada dururken reddedildi',
      );
    });

    test('yarıçapın hemen DIŞINDA duran da geçebiliyor', () async {
      // Tahmin payının oynanıştaki karşılığı: halkaya değen oyuncu geçiyor.
      final (gateway, socket, _, _) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      final gemi = gateway.zone.ships.values.single;
      gemi.state = gemi.state.copyWith(
        position: Vec2(gecit.konum.x + GecitAgi.yaricap * 1.1, gecit.konum.y),
      );
      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);
      expect(gateway.defter[gecit.hedef].hucre!.ships, hasLength(1));
    });

    test('haritanın ÖBÜR UCUNDAN geçilemiyor', () async {
      final (gateway, socket, gelen, _) = await kur();
      final gemi = gateway.zone.ships.values.single;
      gemi.state = gemi.state.copyWith(position: gateway.zone.world.centre);
      gelen.clear();
      socket.add(const ClientGecit().encode());
      await _until(
        () => gelen.any((b) => b.isNotEmpty && b[0] == Protocol.msgGecitRed),
      );
      expect(gateway.defter.canlilar, hasLength(1));
    });
  });

  group('geçiş · karşılama', () {
    test('karşılama NEREDE uyandığını söylüyor', () async {
      // Bildirilen ikinci hata: harita kalıcı olduğu için dönen oyuncu
      // bıraktığı yerde uyanıyor, ama istemci bunu yalnız `ServerHarita`'dan
      // öğreniyordu — o da geçişte gidiyor. Sunucu bir haritaya, istemci
      // başkasına bakıyordu; çizilen geçitler sunucuda yoktu ve her deneme
      // "geçit menzilinde değilsin" ile dönüyordu, kapının tam üstünde.
      final (gateway, socket, gelen, account) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.boss);
      gecideKoy(gateway, gecit);
      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);

      // Dünyada hiçbir iz bırakma: kayıt yolu işlesin, sahipsiz gemi değil.
      final hedefHucre = gateway.defter[gecit.hedef].hucre!;
      hedefHucre.leave(hedefHucre.ships.keys.single);
      await socket.close();

      final ikinci = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
      addTearDown(ikinci.close);
      final gelen2 = <Uint8List>[];
      ikinci.listen(
        (d) => gelen2.add(Uint8List.fromList(d as List<int>)),
        onError: (_) {},
        onDone: () {},
      );
      ikinci.add(
        ClientHello(
          protocolVersion: Protocol.version,
          token: gateway.accounts.issueToken(account),
        ).encode(),
      );
      await _until(
        () => gelen2.any((b) => b.isNotEmpty && b[0] == Protocol.msgWelcome),
      );

      final welcome =
          ServerMessage.decode(
                gelen2.firstWhere((b) => b[0] == Protocol.msgWelcome),
              )
              as ServerWelcome;
      expect(welcome.bolgeKademe, gecit.hedef.bolge.kademe);
      expect(welcome.haritaTipi, gecit.hedef.tip.index);
    });

    test('BAŞLANGIÇTA da doğru — yeni oyuncu boşa bakmıyor', () async {
      final (gateway, _, gelen, _) = await kur();
      final welcome =
          ServerMessage.decode(
                gelen.firstWhere((b) => b[0] == Protocol.msgWelcome),
              )
              as ServerWelcome;
      expect(welcome.bolgeKademe, Harita.baslangic.bolge.kademe);
      expect(welcome.haritaTipi, Harita.baslangic.tip.index);
      expect(gateway.zone.ships, hasLength(1));
    });
  });

  group('geçiş · yalıtım', () {
    test('haritalar birbirinin yayınını DUYMUYOR', () async {
      final (gateway, socket, _, _) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      gecideKoy(gateway, gecit);
      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);

      // İkinci oyuncu başlangıç haritasına giriyor; birincisi PvP'de.
      final ikinci = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
      final account = await gateway.accounts.register(
        email: 'bora@test.local',
        username: 'Bora',
        password: 'yeterince-uzun-parola',
      );
      final gelen2 = <Uint8List>[];
      ikinci.listen(
        (d) => gelen2.add(Uint8List.fromList(d as List<int>)),
        onError: (_) {},
        onDone: () {},
      );
      ikinci.add(
        ClientHello(
          protocolVersion: Protocol.version,
          token: gateway.accounts.issueToken(account),
        ).encode(),
      );
      await _until(() => gateway.zone.ships.isNotEmpty);

      // İki harita, iki hücre, her birinde bir gemi.
      expect(gateway.defter.canlilar, hasLength(2));
      expect(gateway.toplamOyuncu, 2);
      expect(gateway.zone.ships, hasLength(1));
      expect(gateway.defter[gecit.hedef].hucre!.ships, hasLength(1));
    });
  });
  // KARAR 11.2 s1
  group('geçitten sonra GİRDİ', () {
    /// YOLDAKİ ESKİ GİRDİ YENİ GEMİYİ SAĞIR BIRAKMASIN.
    ///
    /// Geçitte sunucu YENİ bir gemi yaratıyor (`hedef.join`) ve o gemi
    /// `acknowledgedSeq = 0` ile başlıyor; istemci de yeni bir tahmin nesnesi
    /// kurup sırasını sıfırdan sayıyor. Ama geçiş anında YOLDA olan eski
    /// girdiler yüksek sıra numarası taşıyor ve geçişten sonra varıyorlar —
    /// `session.ship` artık yeni gemi olduğu için onlara uygulanıyorlar.
    ///
    /// `enqueue` yalnız "sıra ilerlemiş mi" diye bakıyor (`seq <=
    /// acknowledgedSeq` ise at). Eski bir girdi 900 taşıyorsa kabul ediliyor
    /// ve sayaç 900'e sıçrıyor. Ondan sonra istemcinin taze girdileri (1, 2,
    /// 3…) hep o sayının altında kalıyor ve SESSİZCE atılıyor: 30 Hz'de
    /// sayacın geri tırmanması yarım dakika sürüyor ve o süre boyunca gemi
    /// hiçbir komuta cevap vermiyor.
    ///
    /// Oyuncunun gördüğü şey ağ sorunu gibi: "portaldan geçtim, gemiyi
    /// hareket ettiremiyorum". Oysa ağ kusursuz çalışıyor.
    test('sıra numarası geçitte SIFIRLANMIYOR, taşınıyor', () async {
      final (gateway, socket, gelen, _) = await kur();
      final gecit = gecitBul(Harita.baslangic, HaritaTipi.pvp);
      gecideKoy(gateway, gecit);

      // Oyuncu geçide kadar uçtu: sayaç yüksek. Gerçek oyunda kaçınılmaz —
      // 30 Hz'de bir dakikalık uçuş 1800 girdi demek.
      const ucusSirasi = 900;
      socket.add(
        ClientInput(
          seq: ucusSirasi,
          input: const ShipInput(seq: ucusSirasi, axis: Vec2(1, 0)),
        ).encode(),
      );
      await _until(
        () => gateway.zone.ships.values.single.acknowledgedSeq == ucusSirasi,
      );

      socket.add(const ClientGecit().encode());
      await _until(() => gateway.defter[gecit.hedef].canli);
      final hedef = gateway.defter[gecit.hedef].hucre!;
      await _until(() => hedef.ships.isNotEmpty);

      // OTORİTER KONUM İSTEMCİYE GİDİYOR.
      //
      // İstemci geçidin çıkışını kendisi hesaplamamalı: hesaplasaydı kural
      // iki yerde yazılı olurdu ve ilk ayrışmada iki gemi iki ayrı yerde
      // dururdu. Konum yollanmadığı sürece istemcinin tek seçeneği tahmin
      // etmekti — yeni dünyanın merkezi — ve aradaki fark ışınlanma eşiğinin
      // yirmi katıydı.
      final haritaMesaji = gelen
          .map(
            (b) => ServerMessage.decode(Uint8List.fromList(b)),
          )
          .whereType<ServerHarita>()
          .last;
      // Tolerans `f32`den: mesaj tek duyarlıklı yazıyor ve 10.362,6 gibi bir
      // sayıda son basamak kayıyor. Konum için bu kayıp önemsiz — gemi
      // genişliği bile bundan bin kat büyük.
      expect(
        haritaMesaji.x,
        closeTo(gecit.cikisKonumu.x, 0.01),
        reason: 'geçit mesajı otoriter konumu taşımıyor',
      );
      expect(haritaMesaji.y, closeTo(gecit.cikisKonumu.y, 0.01));

      // DEĞİŞMEZ: yeni gemi sayacı SIFIRDAN değil kaldığı yerden alıyor.
      expect(
        hedef.ships.values.single.acknowledgedSeq,
        ucusSirasi,
        reason: 'geçitte sayaç sıfırlandı: istemci sağır kalır',
      );

      // Ve süren sıra işlenmeye devam ediyor.
      socket.add(
        ClientInput(
          seq: ucusSirasi + 1,
          input: ShipInput(seq: ucusSirasi + 1, axis: const Vec2(0, 1)),
        ).encode(),
      );
      await _until(
        () => hedef.ships.values.single.acknowledgedSeq == ucusSirasi + 1,
        timeout: const Duration(seconds: 3),
      );
    });
  });

}

Future<void> _until(bool Function() ready, {Duration? timeout}) async {
  final limit = timeout ?? const Duration(seconds: 5);
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > limit) throw StateError('koşul gerçekleşmedi');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
