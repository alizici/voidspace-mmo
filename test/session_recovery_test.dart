@Tags(['disi'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/lifecycle.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/net/token_store.dart';
import 'package:voidspace_core/voidspace_core.dart';

import 'game_harness.dart';

/// BAYAT BELİRTEÇ — oyuncunun gördüğü "ilk girişte girmiyor, ikincide giriyor".
///
/// Şikâyet tek cümleydi ama arkasında üç ayrı kusur vardı ve üçü birlikte
/// çıkmaz üretiyordu:
///
///  1. Belirteçler yalnız BELLEKTE. Sunucunun her yeniden başlaması hepsini
///     siliyor — `tool/dev.sh` bunu her `flutter run`'da yapıyor, yani bu yol
///     geliştirmede istisna değil kural.
///  2. Sunucu bayat belirtece "reddedildin" deyip SOKETİ KAPATIYORDU.
///  3. İstemcinin giriş çerçevesi kapalı kanala düşüyor, `_send` onu sessizce
///     yutuyor ve faz sonsuza kadar "doğrulanıyor"da kalıyordu. Düğme
///     kapanıyor, uygulamayı yeniden başlatmaktan başka çıkış kalmıyordu —
///     ve yeniden başlatma çalışıyordu çünkü bayat belirteç bu arada
///     silinmiş oluyordu. "İkinci giriş" tam olarak buydu.
///
/// Buradaki testler üçünü de ayrı ayrı kilitliyor. Hiçbiri "bağlanabiliyor
/// mu" diye sormuyor; hepsi OYUNCUNUN yaşadığı diziyi kuruyor.
void main() {
  test(
    'bayat belirteçle açılan oyuncu İLK girişte dünyaya girer',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);

      // Uygulama önceki oturumdan kalma bir belirteçle açılıyor. Sunucu onu
      // tanımıyor: tam olarak yeniden başlatılmış bir sunucunun hâli.
      final tokens = MemoryTokenStore();
      await tokens.write('onceki-oturumdan-kalan-belirtec');

      final client = NetClient(
        uri: Uri.parse('ws://127.0.0.1:${gateway.port}'),
        tokens: tokens,
      );
      addTearDown(client.dispose);

      await client.restoreSession();
      await client.connect();

      // Bayat belirteç bir RED değil: oyuncu giriş ekranını görmeli, kapalı bir
      // bağlantıyla baş başa kalmamalı.
      await awaitPhase(client, NetPhase.needsAuth);
      expect(
        client.phase,
        isNot(NetPhase.rejected),
        reason: 'bayat belirteç oyuncuyu çıkmaza sokmamalı',
      );

      // Ve İLK giriş denemesi tutmalı — ikincisi değil.
      await client.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: testPassword,
      );
      await awaitPhase(
        client,
        NetPhase.playing,
        within: const Duration(seconds: 15),
      );

      // Reddedilen belirteç saklanmamalı: kalsaydı her açılış aynı çıkmazı
      // yeniden kurardı.
      expect(await tokens.read(), isNot('onceki-oturumdan-kalan-belirtec'));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'kapalı kanala yollanan giriş fazı KİLİTLEMEZ',
    () async {
      final gateway = await bootServer();
      addTearDown(gateway.stop);

      final client = NetClient(
        uri: Uri.parse('ws://127.0.0.1:${gateway.port}'),
      );
      addTearDown(client.dispose);

      // Hiç bağlanmadan giriş: kanal yok. Eskiden çerçeve sessizce yutuluyor,
      // faz "doğrulanıyor"da asılı kalıyor ve düğme kapanıyordu — çıkış yok.
      //
      // Artık kimlik yolu kanalı kendisi kuruyor. Kanıt fazın kurtulması değil,
      // çerçevenin sunucuya GERÇEKTEN ulaşması: böyle bir hesap olmadığı için
      // sunucudan bir kimlik hatası dönmeli.
      await client.login(username: 'Ada', password: testPassword);
      await awaitPhase(
        client,
        NetPhase.needsAuth,
        within: const Duration(seconds: 15),
      );

      expect(
        client.authError,
        isNotNull,
        reason: 'giriş çerçevesi sunucuya ulaşmalı, sessizce yutulmamalı',
      );
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'sunucu yeniden başlayınca oyuncu giriş ekranına DÜŞER',
    () async {
      // Hesap dosyası iki sunucu arasında PAYLAŞILIYOR: hesap diskte yaşıyor,
      // belirteç bellekte. Yeniden başlatmanın gerçek etkisi tam olarak bu.
      final dir = Directory.systemTemp.createTempSync('voidspace_restart');
      addTearDown(() => dir.deleteSync(recursive: true));

      final first = await bootServer(dataDir: dir);
      final port = first.port;

      final tokens = MemoryTokenStore();
      final client = NetClient(
        uri: Uri.parse('ws://127.0.0.1:$port'),
        tokens: tokens,
      );
      addTearDown(client.dispose);

      await client.connect();
      await awaitPhase(client, NetPhase.needsAuth);
      await client.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: testPassword,
      );
      await awaitPhase(client, NetPhase.playing);
      expect(await tokens.read(), isNotNull);

      // `tool/dev.sh`'in her koşuda yaptığı şey: aynı adres, YENİ sunucu, boş
      // belirteç tablosu.
      await first.stop();
      final second = await bootServer(dataDir: dir, port: port);
      addTearDown(second.stop);

      // Yeniden bağlanma iki saniyede bir deneniyor; süre onun için cömert.
      await awaitPhase(
        client,
        NetPhase.needsAuth,
        within: const Duration(seconds: 25),
      );

      // ASIL İDDİA. Arayüz oyun ekranını `username != null` diye gösteriyor.
      // Ad silinmezse oyuncu gemisiz, snapshot'sız, giriş ekranına ULAŞAMADAN
      // donmuş bir dünyada kalıyor — "takılıyor, hareket ettiremiyorum"
      // tarifi tam olarak o hâlin kendisi.
      expect(
        client.isAuthenticated,
        isFalse,
        reason: 'oturum bittiğinde oyun ekranı değil giriş ekranı görünmeli',
      );
      expect(client.ship, isNull);

      // Ve oyuncu aynı kanaldan geri dönebilmeli.
      await client.login(username: 'Ada', password: testPassword);
      await awaitPhase(
        client,
        NetPhase.playing,
        within: const Duration(seconds: 15),
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'BELİRTEÇLE dönen istemci giriş ekranında kalmaz',
    () async {
      // `ServerAuthOk` YALNIZ parola yolundan geliyor. Belirteçle dönen istemci
      // (uygulama yeniden açıldı, ağ koptu) yalnız `ServerWelcome` alıyor —
      // gemisi dünyada, ama kendini "giriş yapmamış" sayıyordu.
      //
      // Sessiz olan kısmı daha kötüydü: oyun ağacı `isAuthenticated` ile
      // kuruluyor, kurulmayınca kare döngüsü de yok, yani istemci tek bir girdi
      // çerçevesi bile yollamıyor. Sunucu on saniyede "girdi yok" diye
      // düşürüyor, istemci iki saniyede geri dönüyor, aynı sessizlik —
      // sonu gelmeyen ~/↻ salınımı.
      final gateway = await bootServer();
      addTearDown(gateway.stop);

      final tokens = MemoryTokenStore();
      final first = NetClient(
        uri: Uri.parse('ws://127.0.0.1:${gateway.port}'),
        tokens: tokens,
      );
      await first.connect();
      await awaitPhase(first, NetPhase.needsAuth);
      await first.register(
        email: 'ada@test.local',
        username: 'Ada',
        password: testPassword,
      );
      await awaitPhase(first, NetPhase.playing);
      first.dispose();

      // Uygulama yeniden açıldı: elde YALNIZ belirteç var, parola yok.
      final second = NetClient(
        uri: Uri.parse('ws://127.0.0.1:${gateway.port}'),
        tokens: tokens,
      );
      addTearDown(second.dispose);
      await second.restoreSession();
      await second.connect();
      await awaitPhase(
        second,
        NetPhase.playing,
        within: const Duration(seconds: 15),
      );

      expect(
        second.isAuthenticated,
        isTrue,
        reason: 'dünyaya alınan istemci giriş ekranında kalıyor',
      );
      // Ad da gelmeli: arayüz onu gösteriyor ve belirteç yolunda `ServerAuthOk`
      // gelmediği için tek kaynağı varlık künyesi.
      expect(second.username, 'Ada');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  group('yaşam döngüsü', () {
    // macOS'ta ÖLÇÜLDÜ: başka bir uygulamaya geçmek `inactive → hidden`
    // üretiyor, `paused` hiç gelmiyor. `hidden` askıya alsaydı — ki alıyordu —
    // her alt-tab bağlantıyı koparırdı.
    test('odak kaybı ve örtülen pencere bağlantıyı KOPARMAZ', () {
      expect(actionFor(AppLifecycleState.inactive), LifecycleAction.ignore);
      expect(actionFor(AppLifecycleState.hidden), LifecycleAction.ignore);
    });

    test('gerçek askıya alma bağlantıyı kapatır', () {
      // Flutter ara durumları kendisi üretiyor, yani gerçekten askıya
      // alındığımızda `paused` HER ZAMAN geliyor: `hidden`'ı dinlemeye gerek
      // yok.
      expect(actionFor(AppLifecycleState.paused), LifecycleAction.suspend);
      expect(actionFor(AppLifecycleState.detached), LifecycleAction.suspend);
    });

    test('öne gelmek bağlantıyı geri kurar', () {
      expect(actionFor(AppLifecycleState.resumed), LifecycleAction.resume);
    });

    test('iOS turu: TEK askıya alma, TEK geri dönüş', () {
      // Diziler UYDURMA DEĞİL, iPhone 17 Pro simülatöründe ölçüldü. Kural
      // tablosunu tek tek doğrulamak yetmiyordu: asıl mesele SIRA.
      //
      // `hidden` her İKİ yönde de geliyor. Eski kod onu askıya alma sayıyordu,
      // yani uygulama ÖNE GELİRKEN de bir `suspend()` çalışıyor ve az sonra
      // kurulacak bağlantı boşuna yıkılıyordu. Tabloya bakan biri bunu
      // göremez; diziye bakan görür.
      const toBackground = [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ];
      const toForeground = [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ];

      List<LifecycleAction> acted(List<AppLifecycleState> states) => [
        for (final state in states)
          if (actionFor(state) != LifecycleAction.ignore) actionFor(state),
      ];

      expect(
        acted(toBackground),
        [LifecycleAction.suspend],
        reason: 'arka plana geçerken tam olarak bir kez askıya alınmalı',
      );
      expect(acted(toForeground), [
        LifecycleAction.resume,
      ], reason: 'öne gelirken askıya alma OLMAMALI');
    });
  });

  test(
    'ÇİZMEYEN ama canlı istemci düşürülmez',
    () async {
      // Girdi kare döngüsünden üretiliyor; macOS arka plandaki pencerenin
      // çizimini durduruyor. O hâlde istemci hiç girdi yollamıyor ve sunucu
      // "girdi yok" diye oturumu düşürüyordu — ölçüldü: uygulama arka planda
      // beklerken 35 saniyede 3 kopma/dönüş turu. Oyuncu hiçbir şey yapmamıştı,
      // yalnız başka bir pencereye bakıyordu.
      //
      // Kalp atışı kare döngüsünden BAĞIMSIZ olduğu için soket akmaya devam
      // ediyor; sunucu da artık girdiye değil SESE bakıyor.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);

      // OLAYI say, son durumu DEĞİL.
      //
      // İlk yazışta "14 saniye sonra oynuyor ve gemi sahipsiz değil" diyordum ve
      // hiçbir şeyi kanıtlamıyordu: oturum düşürülse bile istemci iki saniyede
      // geri dönüp gemisini geri alıyor, yani son durum İKİ HÂLDE DE aynı
      // görünüyor. Testi kalp atışını söküp sınadım — yine yeşildi. Kopmayı
      // saymak o boşluğu kapatıyor.
      var drops = 0;
      final sub = client.changes.listen((_) {
        if (client.phase == NetPhase.disconnected) drops++;
      });
      addTearDown(sub.cancel);

      // Kare döngüsü YOK: `update` hiç çağrılmıyor, yani tek bir girdi çerçevesi
      // bile gitmiyor. Sunucunun zaman aşımı 10 saniye; 14 onun ötesi.
      await Future<void>.delayed(const Duration(seconds: 14));

      expect(drops, 0, reason: 'çizmeyen istemci $drops kez düşürüldü');
      expect(client.phase, NetPhase.playing);
      expect(gateway.zone.ships.values.single.isOrphan, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'yeniden bağlanan gemi HEMEN hareket eder',
    () async {
      // Oyuncunun tarifi: "uygulamayı alta aldım, geri girdim, gemiyi 15 saniye
      // hareket ettiremedim, sonra düzeldi." Bağlantı kurulmuştu — sunucu
      // günlüğünde tek bir temiz `~` / `↻` turu vardı. Kaybolan şey bağlantı
      // değil GİRDİYDİ.
      final gateway = await bootServer();
      addTearDown(gateway.stop);
      final client = await connectClient(gateway, 'Ada');
      addTearDown(client.dispose);
      await awaitPlaying([client]);

      // Bir süre OYNA: girdi sıra sayacı yükselsin.
      client.ship!.axis = const Vec2(1, 0);
      await pump([client], 3);
      final playedSeq = gateway.zone.ships.values.single.acknowledgedSeq;
      expect(
        playedSeq,
        greaterThan(60),
        reason: 'kurulum: sunucu girdi işlemiş olmalı',
      );

      // Arka plana al ve geri gel — iOS'un yaptığı şey.
      client.suspend();
      await _until(() => gateway.zone.ships.values.single.isOrphan);
      client.resume();
      await awaitPlaying([client]);

      // ŞİMDİ uç ve KONUMUN gerçekten değiştiğini ölç.
      final from = gateway.zone.ships.values.single.state.position;
      client.ship!.axis = const Vec2(1, 0);
      await pump([client], 2);
      final moved =
          (gateway.zone.ships.values.single.state.position - from).length;

      expect(
        moved,
        greaterThan(100),
        reason:
            'iki saniyede $moved birim gitti — sunucu girdiyi kabul etmiyor '
            '(oynanan sıra $playedSeq)',
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('koşul sağlanmadı');
}
