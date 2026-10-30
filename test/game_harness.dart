import 'dart:io';
import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/ship_atlas.dart';
import 'package:voidspace3/game/voidspace_game.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/hangars.dart';
import 'package:voidspace_server/ledger_store.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Testlerde kullanılan piksel oranı.
///
/// Sabit olması şart: atlas bu değere göre çözülüp önbelleğe alınıyor ve
/// widget testinin sahte saati gerçek bir kod çözme işlemini ilerletemez.
/// Testler atlası [warmAtlas] ile önceden ısıtır.
const double testDevicePixelRatio = 2;

/// Atlası GERÇEK zamanda çöz ve önbelleğe al.
Future<void> warmAtlas() =>
    ShipAtlas.load(devicePixelRatio: testDevicePixelRatio, zoom: 0.6);

/// Testler için GERÇEK bir sunucu.
///
/// Sahte bir taşıma katmanı yazmak cazipti ve yanlış olurdu: bu projede test
/// edilmesi gereken şey tam olarak iki uç arasındaki sözleşme — kodlama,
/// mutabakat, tik zamanlaması. Sahte soket bunların hepsini atlar.
///
/// Port 0: işletim sistemi boş bir port seçer, böylece paralel koşan testler
/// birbirinin portunu kapmaz.
Future<Gateway> bootServer({
  bool debugCommands = false,
  int maxSessionsPerIp = 64,
  int port = 0,
  Directory? dataDir,
  Set<String> devRich = const {},
}) async {
  // Hesaplar GEÇİCİ dizine yazılır: testler ne birbirinin ne geliştiricinin
  // gerçek hesap dosyasına dokunmalı.
  //
  // [dataDir] verilebilir olması SUNUCU YENİDEN BAŞLATMASI içindir: aynı
  // dosyalarla ikinci bir sunucu açmak, hesapların diskte yaşadığını ama
  // belirteçlerin YALNIZ BELLEKTE olduğunu — yani yeniden başlatmanın onları
  // sildiğini — testte gerçekten kurabilmenin tek yolu.
  final dir =
      dataDir ?? Directory.systemTemp.createTempSync('voidspace_test_accounts');
  if (dataDir == null) addTearDown(() => dir.deleteSync(recursive: true));

  // Diskten OKUMAK üretimdeki (`server/bin/server.dart`) sırayla aynı. Boş bir
  // dizinde bedava; paylaşılan bir dizinde ise testin can alıcı noktası —
  // hesapların yeniden başlatmadan sağ çıktığını gösteren şey bu.
  final accounts = AccountStore(path: '${dir.path}/accounts.json');
  await accounts.load();
  // Hangar da GEÇİCİ dizine: varsayılan yol `data/hangars.jsonl`, yani
  // geliştiricinin gerçek ilerlemesi. Testlerin ona dokunması kabul edilemez.
  final hangars = HangarStore(path: '${dir.path}/hangars.jsonl');
  // Defter de GEÇİCİ dizine: varsayılan yol `data/ledger.jsonl` ve testlerin
  // geliştiricinin gerçek para geçmişine yazması kabul edilemez.
  final ledger = LedgerStore(path: '${dir.path}/ledger.jsonl');
  await hangars.load();

  final gateway = Gateway(
    accounts: accounts,
    hangars: hangars,
    ledger: ledger,
    // Varsayılan KAPALI — üretimdekiyle aynı. Açık olmasına ihtiyacı olan
    // testler bunu açıkça ister; böylece "test ortamı gevşek" diye bir şey
    // olmaz ve gerçek yapılandırma her testte sınanır.
    allowDebugCommands: debugCommands,
    // Varsayılan BOŞ — üretimdekiyle aynı. Zengin hesap davranışını ölçen
    // test bunu açıkça istiyor.
    devRichAccounts: devRich,
    // Testlerin hepsi 127.0.0.1'den bağlanıyor, yani üretim tavanı (8) burada
    // yanlış sebeple tetiklenirdi.
    maxSessionsPerIp: maxSessionsPerIp,
  );
  await gateway.start(host: '127.0.0.1', port: port);
  return gateway;
}

/// Test parolası — [Credentials] sınırlarına uyacak kadar uzun.
const String testPassword = 'test-parolasi-123';

/// Bağlanır, KAYIT OLUR ve dünyaya girer.
///
/// Kimlik akışı artık her bağlantının ilk adımı. Testlere arka kapı açsaydık
/// o yol hiç sınanmazdı — oysa artık oyuna giden tek yol orası.
Future<NetClient> connectClient(Gateway gateway, String name) async {
  final client = NetClient(uri: Uri.parse('ws://127.0.0.1:${gateway.port}'));
  await client.connect();
  await awaitPhase(client, NetPhase.needsAuth);
  await client.register(
    email: '$name@test.local',
    username: name,
    password: testPassword,
  );
  await awaitAuthenticated(client);
  return client;
}

/// Kopan bir oyuncunun bekleme süresini ELLE doldurur.
///
/// Kopan gemi artık hemen silinmiyor: oyuncu birkaç saniye içinde dönerse
/// aynı gemiye kavuşuyor. Testte o süreyi gerçekten beklemek her testi on
/// saniye uzatırdı — burada yalnız saat ileri alınıyor, davranış değil.
Future<void> expireOrphan(Gateway gateway, int shipId) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final ship = gateway.zone.ships[shipId];
    if (ship == null) return;
    if (ship.isOrphan) {
      ship.orphanUntilTick = 0;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('gemi $shipId sahipsiz duruma geçmedi');
}

/// [client] verilen faza gelene kadar bekler.
///
/// [within] uzatılabilir çünkü bazı yollar GERÇEK zamanlayıcı bekliyor:
/// yeniden bağlanma iki saniyede bir deneniyor ve sunucunun ayağa kalkması da
/// zaman alıyor. Kısa bir süre orada netcode'la ilgisi olmayan bir
/// başarısızlık üretirdi.
Future<void> awaitPhase(
  NetClient client,
  NetPhase phase, {
  Duration within = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(within);
  while (DateTime.now().isBefore(deadline)) {
    if (client.phase == phase) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('faz $phase gelmedi (şu an ${client.phase})');
}

/// Kimlik doğrulanana kadar bekler.
///
/// Parola türetmesi sunucuda ayrı bir isolate'te ~100 ms sürüyor: bu bekleme
/// uydurma değil, gerçek.
Future<void> awaitAuthenticated(NetClient client) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (client.isAuthenticated) return;
    final error = client.authError;
    if (error != null) throw StateError('kimlik reddedildi: $error');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('kimlik doğrulanamadı');
}

/// [clients]'ı GERÇEK zamanla ilerletir.
///
/// İki ayrıntı bu yardımcıyı doğru yapan şey:
///
///  * `Future.delayed` şart — sunucunun tiki duvar saatine bağlı bir
///    zamanlayıcıda koşuyor, sahte zamanla ilerletilemez. Karşılığında
///    testler saniyeler sürer; netcode testinin dürüst bedeli bu.
///  * `dt` SABİT DEĞİL, gerçekten ölçülen süre. Sabit bir `dt` yollamak
///    (16 ms) istemcinin simülasyon saatini duvar saatinden koparır: yüklü
///    bir olay döngüsünde kare 40 ms sürerken istemci 16 ms saydığında
///    sunucuyla arasındaki fark testin ölçmek istediği sapmayı gölgeler.
///    Gerçek oyun döngüsü de tam olarak bunu yapar (`FlameGame.update(dt)`).
Future<void> pump(
  List<NetClient> clients,
  double seconds, {
  void Function()? each,
}) async {
  const step = Duration(milliseconds: 16);
  final elapsed = Stopwatch()..start();
  var last = 0;
  final limitMs = (seconds * 1000).round();

  while (elapsed.elapsedMilliseconds < limitMs) {
    await Future<void>.delayed(step);
    final now = elapsed.elapsedMilliseconds;
    final dt = (now - last) / 1000;
    last = now;
    for (final client in clients) {
      client.update(dt);
    }
    each?.call();
  }
}

/// [clients]'ın hepsi dünyaya girene kadar bekler.
///
/// Süre CÖMERT ve olmak zorunda: koşullar sağlanır sağlanmaz dönüyor, yani
/// hızlı durumda hiçbir maliyeti yok — ama `flutter test` paketleri PARALEL
/// koşuyor ve her biri gerçek bir sunucu ayağa kaldırıyor. Yüklü bir makinede
/// el sıkışma birkaç saniye gecikebiliyor ve dar bir süre, netcode'la ilgisi
/// olmayan bir başarısızlık üretiyordu.
Future<void> awaitPlaying(List<NetClient> clients) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if (clients.every((c) => c.phase == NetPhase.playing && c.ship != null)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  throw StateError('istemciler dünyaya giremedi');
}

/// Oyunu widget ağacı olmadan ayağa kaldırır.
///
/// `flame_test` paketi kullanılmıyor: yayınlanan sürümü bu Flame sürümüyle
/// derlenmiyor. Aşağıdaki sıra, o paketin kendi `initializeGame`'inin aynısıdır
/// — `load()` ve `mount()` normalde `GameWidget`'ın çağırdığı iç adımlardır ve
/// biri atlanırsa bileşenler ağaca girmeden güncellenmeye başlar.
Future<VoidspaceGame> bootGame(
  NetClient net, {
  ShipBloc? bloc,
  bool touchControls = false,
}) async {
  final game = VoidspaceGame(
    net: net,
    shipBloc: bloc ?? ShipBloc(),
    devicePixelRatio: testDevicePixelRatio,
    touchControls: touchControls,
  );
  game.onGameResize(Vector2(1200, 800));
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  game.update(0);
  await game.ready();
  return game;
}

/// Ham bir soketle el sıkışıp sunucunun İLK cevabını döndürür.
///
/// [NetClient] üzerinden yapılamaz: o istemci daima doğru sürümü yollar. Bu
/// yardımcı, protokolün REDDETME yolunu — yani uyumsuz bir istemcinin yarı
/// çözülmüş çöp okumasını engelleyen tek mekanizmayı — test etmek için var.
Future<ServerMessage> connectRawClient(Gateway gateway, int version) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:${gateway.port}'),
  );
  await channel.ready;
  channel.sink.add(
    ClientHello(protocolVersion: version, token: 'sahte-belirteç').encode(),
  );
  final first = await channel.stream.first as List<int>;
  await channel.sink.close();
  return ServerMessage.decode(Uint8List.fromList(first));
}

/// Sunucuya protokolde YERİ OLMAYAN bayt yığını yollar.
///
/// Ağdan gelen her şey düşmandır. Tek bir kötü niyetli çerçevenin süreci
/// düşürebilmesi, 50 kişilik bir sunucuda kabul edilebilir bir risk değil.
Future<void> sendGarbage(Gateway gateway) async {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:${gateway.port}'),
  );
  await channel.ready;
  channel.sink
    ..add(Uint8List.fromList([0xFF, 0x00, 0x13, 0x37]))
    ..add(Uint8List.fromList([Protocol.msgInput, 0x01]));
  await channel.sink.done.timeout(
    const Duration(seconds: 3),
    onTimeout: () => null,
  );
}

/// Oyun döngüsünü GERÇEK zamanla ilerletir.
///
/// [game.update] kendi içinde `net.update` çağırıyor; ayrıca çağırmak
/// tahminin adımlarını ikiye katlar ve sapmayı uydurma bir yerden yaratır.
/// [others] yalnız komşu istemciler için — onların da girdi yollaması gerek,
/// yoksa sunucu zaman aşımına düşürür.
Future<void> pumpGame(
  VoidspaceGame game,
  double seconds, {
  List<NetClient> others = const [],
}) async {
  const step = Duration(milliseconds: 16);
  final elapsed = Stopwatch()..start();
  var last = 0;
  final limitMs = (seconds * 1000).round();

  while (elapsed.elapsedMilliseconds < limitMs) {
    await Future<void>.delayed(step);
    final now = elapsed.elapsedMilliseconds;
    final dt = (now - last) / 1000;
    last = now;
    for (final client in others) {
      client.update(dt);
    }
    game.update(dt);
  }
}

/// [finder] eşleşene kadar kare pompalar — en fazla [maxFrames] kare.
///
/// Sabit sayıda kare pompalayıp koşulun tuttuğunu UMMAK, testi makinenin o
/// anki hızına bağlar. Gerçekten kırıldı: `hud_input_test` 12 kare pompalıyor
/// ve makine yüklüyken (paralel koşan başka bir test CPU'yu yediğinde) perde
/// henüz kalkmamış oluyordu — tam paket koşusunun ~%40'ında kırmızı, tek
/// başına koşunca daima yeşil. Bu tür bir kırılganlık yalnız kendi testini
/// değil, ONA BAKAN herkesin gerçek hatalara olan güvenini de bozar.
///
/// Koşula kadar pompalamak zamanlamayı testin varsayımı olmaktan çıkarır.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 240,
  Duration frame = const Duration(milliseconds: 32),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(frame);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw StateError(
    '$maxFrames kare pompalandı, "$finder" hâlâ yok — '
    'koşul gerçekten sağlanmıyor',
  );
}
