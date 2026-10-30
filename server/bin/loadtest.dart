import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:voidspace_core/voidspace_core.dart';

/// Yük üreteci: N sahte oyuncuyu sunucuya bağlar ve gerçek istemci gibi
/// hareket ettirir.
///
/// "40-50 kişi aynı ekranda" hedefinin ÖLÇÜLEBİLİR olması için var. Tahminle
/// "herhalde yeter" demek yerine, tarayıcıdaki gerçek istemcinin yanına 40 gemi
/// koyup kare süresine bakıyoruz.
///
/// Botlar birbirine ATEŞ EDER. Bu şart: savaş katmanı (mermiler, çarpma
/// parlamaları, kalkan vuruşları, hasar sayıları) kare bütçesinin ölçülmemiş
/// tek parçasıydı ve ateş etmeyen bir yük testi onu hiç uyandırmıyordu.
///
/// ```bash
/// dart run server/bin/loadtest.dart 40        # ateş ederek
/// PEACE=1 dart run server/bin/loadtest.dart 40  # yalnız uçarak
/// ```
/// Botların bağlanacağı adres.
///
/// `URL` verilirse doğrudan o kullanılır — tünel ya da gerçek sunucu
/// (`wss://...`) karşısında ölçüm yapabilmek için. Yerel ölçüm gecikmesiz
/// olduğu için tek başına yeterli değil: "global açıldığında nasıl" sorusunun
/// cevabı ancak gerçek bir yol üzerinden alınır.
String endpoint(int port) =>
    Platform.environment['URL'] ?? 'ws://127.0.0.1:$port';

/// Ölçümün kendisi: yük üreteci SUNUCUYU ölçmeli, kendini değil.
///
/// **Kapasite ölçümünün en yaygın hatası bu.** Tek makinede koşan bir yük
/// üreteci 50–200 sanal oyuncudan sonra kendi tıkanır: CPU dolar, olay
/// döngüsü gecikir, botlar girdi göndermeyi bırakır. Sunucu o anda DAHA AZ iş
/// yapar ve ölçüm "her şey yolunda" der — yani araç, sınırı bulmak yerine
/// sınırı gizler. Gil Tene'nin "koordineli ihmal" (coordinated omission)
/// dediği şeyin yük üreteci tarafındaki hâli.
///
/// İki savunma var ve ikisi de burada:
///
///  1. **Çok isolate.** Botlar `ISOLATES` kadar isolate'e bölünüyor. Dart'ta
///     isolate gerçek paralellik demek; tek olay döngüsünde saniyede binlerce
///     snapshot çözmek mümkün değil.
///  2. **Üretecin KENDİ gecikmesi ölçülüyor.** Bot saati 33 ms'de bir
///     ateşlenmeli; ölçülen şey `gerçek − hedeflenen`, yani açık döngü
///     (open-loop) gecikmesi. Bu sayı büyüdüyse sunucu ölçümü ÇÖPTÜR ve
///     rapor bunu söylüyor.
///
/// ```bash
/// dart run server/bin/loadtest.dart 240
/// RAMP=60,120,240,400 HOLD=30 dart run server/bin/loadtest.dart
/// PEACE=1 dart run server/bin/loadtest.dart 40   # yalnız uçarak
/// ```
Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final peaceful = Platform.environment['PEACE'] == '1';
  final rally = Vec2(
    double.tryParse(Platform.environment['RALLY_X'] ?? '') ?? 6000,
    double.tryParse(Platform.environment['RALLY_Y'] ?? '') ?? 4000,
  );

  // Basamaklar. Tek sayı verilirse tek basamaklı bir rampa.
  final ramp = (Platform.environment['RAMP'] ?? '')
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList();
  final steps = ramp.isNotEmpty
      ? ramp
      : [args.isEmpty ? 40 : int.parse(args.first)];
  final hold = int.tryParse(Platform.environment['HOLD'] ?? '') ?? 30;

  // İki çekirdek İŞLETİM SİSTEMİNE ve sunucuya bırakılıyor: yük üreteci
  // makineyi tamamen doldurursa sunucunun tikini de o geciktirir ve ölçtüğümüz
  // şey artık sunucunun kapasitesi değil, makinenin.
  final isolates =
      int.tryParse(Platform.environment['ISOLATES'] ?? '') ??
      math.max(1, Platform.numberOfProcessors - 2);

  stdout.writeln(
    'basamaklar ${steps.join(" → ")} · her biri $hold sn · '
    '$isolates isolate · ${endpoint(port)} · toplanma $rally'
    '${peaceful ? " · ateş YOK" : " · ateş VAR"}',
  );

  final inbox = ReceivePort();
  final workers = <SendPort>[];
  final ready = <Completer<SendPort>>[
    for (var i = 0; i < isolates; i++) Completer<SendPort>(),
  ];
  var reportsIn = 0;
  var connected = 0;
  var visible = 0.0;
  var withTarget = 0;
  var shots = 0;
  var lagP95 = 0;
  var lagMax = 0;

  inbox.listen((Object? message) {
    if (message is List && message.first == 'hazır') {
      ready[message[1] as int].complete(message[2] as SendPort);
      return;
    }
    if (message is! Map) return;
    // Bütün işçilerin raporu toplanınca TEK satır basılır: her isolate ayrı
    // yazsaydı sunucunun kendi satırları arasında kaybolurdu.
    reportsIn++;
    connected += message['bağlı']! as int;
    visible += message['görünür']! as double;
    withTarget += message['hedefli']! as int;
    shots += message['atış']! as int;
    final p95 = message['gecikmeP95']! as int;
    final max = message['gecikmeMax']! as int;
    if (p95 > lagP95) lagP95 = p95;
    if (max > lagMax) lagMax = max;
    if (reportsIn < workers.length) return;

    // Sağlık eşiği BİR TİK (33.3 ms).
    //
    // Altında kalan gecikme ölçümü bozmuyor: saat 4 ms'de bir yokluyor, yani
    // yapısal olarak 0–4 ms'lik bir taban zaten var, ve yarım tiklik bir
    // gecikmede botlar hâlâ saniyede 30 girdi yolluyor. Bozan şey, bir tikten
    // fazla geri kalıp girdi hızının DÜŞMESİ — sunucu o anda daha az iş yapar
    // ve ölçüm sunucuyu değil üreteci gösterir.
    const tickMicros = 33333;
    final healthy = lagP95 < tickMicros;
    stdout.writeln(
      'ÜRETEÇ · bağlı $connected · hedefi olan $withTarget · '
      'ortalama görünür ${(visible / (connected == 0 ? 1 : connected)).toStringAsFixed(1)} · '
      'çözülen atış $shots · '
      'saat gecikmesi p95 ${(lagP95 / 1000).toStringAsFixed(1)} ms '
      'max ${(lagMax / 1000).toStringAsFixed(1)} ms'
      '${healthy ? "" : "  ⚠ ÜRETEÇ TIKALI — sunucu ölçümü GEÇERSİZ"}',
    );
    reportsIn = 0;
    connected = 0;
    visible = 0;
    withTarget = 0;
    shots = 0;
    lagP95 = 0;
    lagMax = 0;
  });

  for (var i = 0; i < isolates; i++) {
    await Isolate.spawn(_worker, [
      inbox.sendPort,
      i,
      port,
      rally.x,
      rally.y,
      peaceful,
      _Bot.defaultPrefix,
    ]);
    workers.add(await ready[i].future);
  }

  var running = 0;
  for (final step in steps) {
    final add = step - running;
    if (add > 0) {
      stdout.writeln('\n══ BASAMAK $step oyuncu (+$add) ══');
      // Yeni botlar isolate'lere SIRAYLA dağıtılıyor; her isolate'in yükü
      // eşit kalsın.
      for (var i = 0; i < add; i++) {
        workers[i % workers.length].send(['ekle', running + i]);
        // Aynı anda yüzlerce el sıkışma sunucuyu değil, işletim sisteminin
        // dinleme kuyruğunu ölçerdi.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      running = step;
    }
    // Isınma: yeni botlar ilgi alanına girip hedef bulana kadar geçen süre
    // ölçüme girmemeli. Bu yüzden basamağın İLK raporu kirlidir ve rapor
    // pencereleri 5 saniye olduğu için ilk iki pencere atlanmalı.
    await Future<void>.delayed(Duration(seconds: hold));
  }

  // Rampa bitince ÇIK.
  //
  // Eskiden burada SIGINT bekleniyordu ve arka planda koşan bir ölçümde o
  // sinyal hiç gelmiyordu: yük üreteci sonsuza kadar yaşıyor, onu bekleyen
  // betik sunucuyu hiç öldürmüyor ve BİR SONRAKİ koşu portu meşgul buluyordu.
  // Sunucu bağlanamadan çöküyor, botlar ESKİ sunucuya bağlanıyor ve ölçüm
  // sessizce başka bir süreci ölçüyordu. Sessiz, çünkü botlar mutlu ve
  // sayılar makul — yalnız ölçtüğün sunucu yanlış.
  //
  // `HOLD_OPEN=1` elle inceleme için açık bırakıyor.
  if (Platform.environment['HOLD_OPEN'] == '1') {
    stdout.writeln('\nrampa bitti — açık tutuluyor, durdurmak için Ctrl-C');
    await ProcessSignal.sigint.watch().first;
  } else {
    stdout.writeln('\nrampa bitti');
  }
  for (final worker in workers) {
    worker.send(['dur']);
  }
  exit(0);
}

/// Bir isolate'in içindeki bot filosu.
///
/// Kendi saatini ve kendi gecikme dağılımını tutuyor. Ana isolate'e beş
/// saniyede bir özet yolluyor; ham veriyi yollamak, ölçümün kendisini
/// pahalılaştırırdı.
Future<void> _worker(List<Object?> config) async {
  final reply = config[0]! as SendPort;
  final index = config[1]! as int;
  final port = config[2]! as int;
  final rally = Vec2(config[3]! as double, config[4]! as double);
  final peaceful = config[5]! as bool;
  final prefix = config[6]! as String;

  final commands = ReceivePort();
  reply.send(['hazır', index, commands.sendPort]);

  final bots = <_Bot>[];
  final lag = _Lag();

  commands.listen((Object? message) async {
    if (message is! List) return;
    switch (message.first) {
      case 'ekle':
        final id = message[1]! as int;
        try {
          bots.add(await _Bot.connect(port, id, rally, peaceful, prefix));
        } on Object {
          // Bağlanamayan bot ölçümü durdurmamalı; sayım zaten raporlanıyor.
        }
      case 'dur':
        for (final bot in bots) {
          bot.close();
        }
        Isolate.exit();
    }
  });

  // AÇIK DÖNGÜ. Saat, botların yetişip yetişmediğine bakmadan sabit hızda
  // ilerliyor ve ölçülen şey `gerçek − hedeflenen`. Kapalı döngüde (bir tur
  // bitince sonrakini başlat) üretecin kendi duraklaması ölçüme hiç girmez —
  // tam olarak gizlemek istemediğimiz şey.
  final clock = Stopwatch()..start();
  var due = 0;
  const periodMicros = 33333;
  Timer.periodic(const Duration(milliseconds: 4), (_) {
    while (clock.elapsedMicroseconds >= due) {
      lag.add(clock.elapsedMicroseconds - due);
      due += periodMicros;
      for (final bot in bots) {
        bot.tick();
      }
    }
  });

  Timer.periodic(const Duration(seconds: 5), (_) {
    reply.send({
      'bağlı': bots.length,
      'görünür': bots.fold<int>(0, (a, b) => a + b.visibleCount).toDouble(),
      'hedefli': bots.where((b) => b.foe != 0).length,
      'atış': bots.fold<int>(0, (a, b) => a + b.shotsSeen),
      'gecikmeP95': lag.p95,
      'gecikmeMax': lag.max,
    });
    lag.reset();
  });
}

/// Üretecin kendi saat gecikmesi — kaba ama tahsissiz bir dağılım.
///
/// `LatencyHistogram`'ın kopyası değil sadeleştirilmişi: burada gereken tek
/// şey "üreteç tıkandı mı" sorusunun cevabı, ve o soru 1 ms çözünürlükte
/// cevaplanıyor.
class _Lag {
  static const int _buckets = 512; // 0..512 ms
  final List<int> _counts = List.filled(_buckets, 0);
  int _count = 0;
  int max = 0;

  void add(int micros) {
    _count++;
    if (micros > max) max = micros;
    final b = micros ~/ 1000;
    _counts[b >= _buckets ? _buckets - 1 : b]++;
  }

  int get p95 {
    if (_count == 0) return 0;
    final rank = (_count * 0.95).ceil();
    var seen = 0;
    for (var i = 0; i < _buckets; i++) {
      seen += _counts[i];
      if (seen >= rank) return (i + 1) * 1000;
    }
    return max;
  }

  void reset() {
    for (var i = 0; i < _buckets; i++) {
      _counts[i] = 0;
    }
    _count = 0;
    max = 0;
  }
}

class _Bot {
  _Bot(this.socket, this.index, this.rally, this.peaceful, this.prefix);

  static Future<_Bot> connect(
    int port,
    int index,
    Vec2 rally,
    bool peaceful,
    String prefix,
  ) async {
    final socket = await WebSocket.connect(endpoint(port));
    final bot = _Bot(socket, index, rally, peaceful, prefix)
      // Tohum kimliğe bağlı: her bot farklı bir yol izler ama koşular
      // arasında aynı yolu izler.
      .._rngState = (index + 1) * 7919;
    socket.listen(bot._onFrame, onError: (_) {}, onDone: () {});
    // Botlar da GERÇEK kimlik akışından geçiyor: önce giriş, olmazsa kayıt.
    // Yük testinin ayrıcalıklı bir arka kapısı olsaydı, kimlik yolu asla yük
    // altında sınanmazdı — ve o yol artık her bağlantının ilk adımı.
    socket.add(
      ClientLogin(
        protocolVersion: Protocol.version,
        username: bot._name,
        password: _botPassword,
      ).encode(),
    );
    return bot;
  }

  final WebSocket socket;
  final int index;
  final Vec2 rally;
  final bool peaceful;

  /// Toplanma noktası etrafındaki yayılma yarıçapı (dünya birimi).
  static final double spread =
      double.tryParse(Platform.environment['SPREAD'] ?? '') ?? 600;

  /// Bot adı öneki. `Platform.environment`'tan STATİK okumak yerine
  /// taşınıyor: isolate'lerde ortam okunabilir ama ölçüm parametrelerinin tek
  /// bir yerden akması, yapılandırmanın nereden geldiğini belirsiz
  /// bırakmıyor.
  final String prefix;

  /// Yük botlarının ortak parolası. Bunlar gerçek hesap değil; ayrı bir hesap
  /// dosyasında yaşasınlar diye sunucu `ACCOUNTS` ortam değişkeniyle
  /// başlatılmalı.
  static const String _botPassword = 'loadtest-bot-parola';

  /// Bot adı — `PREFIX` ile ayrıştırılabilir.
  ///
  /// Önek gerekiyor çünkü iki filo AYNI ANDA koşabilmeli: biri doğrudan
  /// sunucuya, öteki gecikme vekilinin arkasından. Aynı adları kullandıklarında
  /// ikinci filo birincinin HESABINI devralıyor ("hesap başına tek oturum"
  /// kuralı doğru çalışıyor) ve ölçüm sessizce anlamsızlaşıyor — sunucuda
  /// oyuncu sayısı artmıyor, iki filo aynı gemileri paylaşıyor.
  static final String defaultPrefix = Platform.environment['PREFIX'] ?? 'Bot';

  /// Ad ÜÇ haneli: yüzü aşan filolarda `Bot01` ile `Bot010` çakışırdı ve
  /// çakışan adlar "hesap başına tek oturum" kuralı yüzünden sessizce
  /// birbirini düşürürdü — sunucuda oyuncu sayısı artmaz, ölçüm yalan söyler.
  String get _name => '$prefix${index.toString().padLeft(3, '0')}';

  /// Delta çözmenin temeli — bkz. `EntityBaseline`.
  final EntityBaseline _baseline = EntityBaseline();

  bool _registered = false;

  int _seq = 0;

  /// Sunucunun bu bota verdiği kimlik — `ServerWelcome`'dan okunur.
  int _id = 0;

  /// Şu anki hedef.
  int _foe = 0;

  int get foe => _foe;
  int get visibleCount => _visible.length;
  bool get hasId => _id != 0;

  /// Görüş alanındaki kimlikler; hedef buradan seçilir. Uydurma bir kimliğe
  /// ateş etmek sunucuda sessizce düşer ve savaş katmanı hiç uyanmaz.
  final List<int> _visible = [];

  /// Görünen gemilerin konumları — menzil içindeki en yakını seçmek için.
  final Map<int, Vec2> _positions = {};
  Vec2 _self = Vec2.zero;

  /// Lazer menzili. Hedef bunun dışındaysa sunucu ateşi kesiyor.
  static const double _weaponRange = 1400;

  GameWorld _world = GameWorld.standard;
  int _snapshots = 0;

  /// Çözülen snapshot'larda görülen atış olayı. Sunucunun yazdığı ile
  /// istemcinin okuduğu arasındaki zinciri kapatan son sayı.
  int _shotsSeen = 0;
  int get shotsSeen => _shotsSeen;

  /// Gelen çerçeveler PAYLAŞILAN çözücüyle okunur.
  ///
  /// Bir kez elle ofset sayarak yazıldı ve sessizce yanlış oldu: kendi
  /// bloğunun boyu "hedef var mı" bayrağına göre değişiyor ve sabit 43 bayt
  /// varsayımı entity listesini kaydırıyordu. Botlar var olmayan kimliklere
  /// ateş ediyor, sunucu onları düşürüyor ve yük testi 64 gemiyle **beş
  /// mermi** üretiyordu — yani ölçmek istediği şeyi hiç uyandırmıyordu.
  ///
  /// Ders, simülasyonunkiyle aynı: tel formatının tek bir okuyucusu olmalı.
  void _onFrame(dynamic data) {
    if (data is! List<int> || data.isEmpty) return;
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);

    if (bytes[0] == Protocol.msgAuthOk) {
      final ok = ServerMessage.decode(bytes) as ServerAuthOk;
      _send(
        ClientHello(
          protocolVersion: Protocol.version,
          token: ok.token,
        ).encode(),
      );
      return;
    }
    if (bytes[0] == Protocol.msgAuthError) {
      // İlk koşuda hesap yok: giriş başarısız olur, kayıt olunur.
      if (_registered) return;
      _registered = true;
      _send(
        ClientRegister(
          protocolVersion: Protocol.version,
          email: '$_name@loadtest.local',
          username: _name,
          password: _botPassword,
        ).encode(),
      );
      return;
    }

    if (bytes[0] == Protocol.msgWelcome) {
      final welcome = ServerMessage.decode(bytes);
      if (welcome is ServerWelcome) {
        _id = welcome.entityId;
        _world = GameWorld(
          width: welcome.worldWidth,
          height: welcome.worldHeight,
          margin: welcome.worldMargin,
        );
      }
      return;
    }
    if (bytes[0] != Protocol.msgSnapshot) return;

    // HER snapshot çözülmek ZORUNDA — delta'nın bedeli bu.
    //
    // Eskiden her onuncu snapshot çözülüyordu (hedef seçmek için saniyede üç
    // güncelleme yeterli). Delta geldikten sonra bu sessizce YANLIŞ olurdu:
    // maske "geçen tike göre ne değişti" diyor, dolayısıyla araya dokuz
    // snapshot atlamak, on tik öncesinin değerlerinin üstüne tek tikin
    // farkını uygulamak demek. Konumlar bozulur ve hiçbir hata mesajı çıkmaz.
    //
    // Ayrıştırma zorunlu ama PAHALI İŞ değil: asıl maliyet hedef seçimiydi ve
    // o hâlâ seyrek. Delta ayrıştırmayı zaten ucuzlattı — entity başına 13
    // bayt yerine çoğu zaman 3-5 bayt okunuyor.
    _snapshots++;
    try {
      final snapshot = ServerSnapshot.decodeWith(
        bytes,
        _world.width,
        _world.height,
        ShipStats.bastion,
        _baseline,
      );
      if (_snapshots % 10 != 0) return;
      // Hedef seçimi MENZİLE göre yapılmalı.
      //
      // Önce görüş alanından (2600 birim) rastgele bir hedef seçiliyordu ama
      // lazerin menzili 1400: seçilen hedeflerin çoğu menzil dışındaydı ve
      // sunucu ateşi kesiyordu. Yük testi "herkes ateş ediyor" sanırken
      // aslında saniyede birkaç atış üretiyordu.
      _visible.clear();
      _self = snapshot.self.state.position;
      for (final e in snapshot.entities) {
        if (!e.alive) continue;
        _visible.add(e.id);
        _positions[e.id] = e.position;
      }
      _shotsSeen += snapshot.shots.length;
    } on Object {
      // Bozuk çerçeve yük testini durdurmamalı.
    }
  }

  /// Bota özel doğrusal eşleşmeli üreteç.
  ///
  /// `Random()` yerine: yük testi bir ÖLÇÜM aracı ve ölçüm tekrarlanabilir
  /// olmalı. Aynı bot her koşuda aynı yolu izler, ama komşusundan bağımsız.
  int _rngState = 0;
  double _rng() {
    _rngState = (_rngState * 1103515245 + 12345) & 0x7FFFFFFF;
    return _rngState / 0x7FFFFFFF;
  }

  Vec2 _target = Vec2.zero;
  int _repathAt = 0;
  int _retargetAt = 0;

  void tick() {
    _seq++;

    // BAĞIMSIZ hareket. Eskiden hepsi tek bir daire üzerinde, sabit faz
    // farkıyla dönüyordu: kırk gemi tek bir organizma gibi hareket ediyordu ve
    // ne çarpışan yörüngeler ne de değişen komşuluklar oluşuyordu — yani ilgi
    // alanı, kırpma ve savaş katmanı gerçek yüklerini hiç görmüyordu.
    //
    // Artık her bot kendi rastgele noktasına gidiyor ve oraya varmadan yenisini
    // seçiyor. Kalabalık sürekli karışıyor.
    if (_seq >= _repathAt) {
      _repathAt = _seq + 25 + (_rng() * 50).round();
      final angle = _rng() * math.pi * 2;
      // Yarıçap DAR tutuluyor (ilgi alanının yarısı). Geniş yayılınca botlar
      // birbirinin görüşünden çıkıyor, hedefsiz kalıyor ve ateş kesiliyor —
      // yani tam olarak ölçmek istediğimiz yük buharlaşıyor.
      // Yarıçap silah menzilinin YARISINDAN küçük: iki bot arasındaki mesafe
      // böylece menzili nadiren aşıyor ve kavga kesilmiyor.
      //
      // `SPREAD` ile genişletilebilir ve kapasite ölçümünde İKİ koşu birden
      // gerekiyor:
      //
      //  * dar (varsayılan) — herkes tek yumakta, herkes herkesi görüyor.
      //    İlgi alanı hiçbir şey elemediği için bu EN KÖTÜ hâl ve bulunan
      //    tavan gerçek tavanın alt sınırı.
      //  * geniş (`SPREAD=4000`) — oyuncular haritaya yayılmış. Gerçek bir
      //    bölgede olan bu ve maliyet çok daha düşük; ama yalnız bunu ölçmek,
      //    bir savaşta herkesin aynı kapıya yığıldığı anı hiç görmemek olur.
      final radius = 80 + _rng() * spread;
      _target = rally + Vec2(math.cos(angle), math.sin(angle)) * radius;
    }
    final target = _target;
    // Hedef SIK değişiyor (~0.5 sn). Sabit hedef, yaylımların hep aynı iki
    // gemi arasında gidip gelmesi demekti; oysa maliyet yaratan şey mermilerin
    // haritaya YAYILMASI ve her yeni hedefte kilit/namlu efektinin baştan
    // kurulması.
    if (!peaceful && _visible.isNotEmpty) {
      // Hedef her ~0.2 sn'de değişiyor ve ARADA BOŞ KALMIYOR: hedefsiz geçen
      // her tik, ölçülmeyen bir yaylım demek.
      if (_seq >= _retargetAt || _foe == 0) {
        _retargetAt = _seq + 4 + (_rng() * 4).round();
        _foe = _nearestInRange();
      }
    } else {
      _foe = 0;
    }

    _send(
      ClientInput(
        seq: _seq,
        input: ShipInput(
          seq: _seq,
          moveTarget: _seq >= _repathAt - 1 ? target : null,
          // İtki: dağınık ve seyrek, ama sürekli. Motor katmanı boştaki
          // gemide atlanıyor; hep duran bir kalabalık o dalı hiç ölçmezdi.
          boost: _rng() < 0.004,
          weaponTarget: _foe,
          firing: _foe != 0,
        ),
      ).encode(),
    );
  }

  /// Menzil İÇİNDEKİ en yakın gemi. Yoksa 0.
  int _nearestInRange() {
    var best = 0;
    var bestDistance = _weaponRange * _weaponRange;
    for (final id in _visible) {
      if (id == _id) continue;
      final at = _positions[id];
      if (at == null) continue;
      final d = at.distanceSquaredTo(_self);
      if (d < bestDistance) {
        bestDistance = d;
        best = id;
      }
    }
    return best;
  }

  void _send(Uint8List bytes) {
    try {
      socket.add(bytes);
    } on Object {
      // Kapanan sokete yazmak: yük testinde sessizce geçilir.
    }
  }

  void close() => socket.close();
}
