import 'dart:async';
import 'dart:io';

/// Gecikme vekili: gerçek sunucunun önüne oturur ve her çerçeveyi geciktirir.
///
/// **Neden var.** "Global açıldığında ışık hızı dışında kusursuz olmalı"
/// iddiası ancak gecikme ALTINDA sınanabilir. Yerel ağda ping ~0 ms ve o
/// koşulda hiçbir gecikme hatası görünmez — yani hata yokmuş gibi görünür.
/// Gerçek bir tünel açmak tek ve KONTROLSÜZ bir örnek verirdi; burada gecikme,
/// titreşim ve paket kaybı istenen sayıya kurulur ve ölçüm tekrarlanabilir.
///
/// Gecikme HER İKİ YÖNE uygulanır (tek yön = RTT / 2). Tek yöne uygulamak,
/// gerçekte olmayan bir asimetri üretir ve istemcinin ping ölçümünü yanıltır.
class LagProxy {
  LagProxy({
    required this.upstreamPort,
    this.upstreamHost = '127.0.0.1',
    this.rttMs = 120,
    this.jitterMs = 0,
    this.loss = 0,
    this.corruptDownstream,
  });

  final String upstreamHost;
  final int upstreamPort;

  /// Sunucudan istemciye giden çerçeveyi BOZMA kancası — `null` ise dokunmaz.
  ///
  /// Gecikme ve kayıp taklit edilebiliyor ama BOZULMA edilemiyordu, oysa
  /// istemcinin bozuk çerçeveye tepkisi (donmak mı, kopup toparlanmak mı) tam
  /// olarak test edilmesi gereken şey. Dönen `null` çerçeveyi düşürür.
  final Object? Function(Object? data)? corruptDownstream;

  /// Gidiş-dönüş gecikmesi. Tek yöne yarısı uygulanır.
  final int rttMs;

  /// Tek yön gecikmesinin ± saçılımı. Mobil ağın imzası budur: ortalama
  /// gecikme değil, DEĞİŞKENLİĞİ oynanışı bozar.
  final int jitterMs;

  /// Yeniden gönderim tetikleyen olay oranı (0..1).
  ///
  /// TCP'de paket KAYBOLMAZ — kaybolan segment yeniden gönderilir ve bu,
  /// uygulamaya bir GECİKME SIÇRAMASI olarak yansır. Burada da öyle
  /// modelleniyor: çerçeve atılmıyor, bir RTT daha geciktiriliyor.
  final double loss;

  HttpServer? _server;
  final List<WebSocket> _open = [];

  int get port => _server?.port ?? 0;

  /// Deterministik yalancı rastgele.
  ///
  /// `Random()` DEĞİL: iki ölçümü karşılaştırmak, titreşim deseninin aynı
  /// olmasını gerektirir. Rastgele bir desen, iyileşmeyi mi yoksa şansı mı
  /// ölçtüğünü belirsiz bırakırdı.
  int _seed = 0x2545F491;

  int _next() {
    _seed ^= (_seed << 13) & 0xFFFFFFFF;
    _seed ^= _seed >> 17;
    _seed ^= (_seed << 5) & 0xFFFFFFFF;
    return _seed & 0x7FFFFFFF;
  }

  Duration _oneWay() {
    final base = rttMs ~/ 2;
    if (jitterMs == 0) return Duration(milliseconds: base);
    final ms = base + (_next() % (jitterMs + 1)) - jitterMs ~/ 2;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  bool _retransmit() => loss > 0 && (_next() % 10000) / 10000 < loss;

  Future<void> start({String host = '127.0.0.1', int port = 0}) async {
    final server = await HttpServer.bind(host, port);
    _server = server;
    unawaited(_accept(server));
  }

  Future<void> _accept(HttpServer server) async {
    await for (final request in server) {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
        continue;
      }
      unawaited(_pipe(request));
    }
  }

  Future<void> _pipe(HttpRequest request) async {
    final WebSocket client;
    try {
      client = await WebSocketTransformer.upgrade(request);
    } on Object {
      return;
    }
    final WebSocket upstream;
    try {
      upstream = await WebSocket.connect('ws://$upstreamHost:$upstreamPort');
    } on Object {
      await client.close();
      return;
    }
    _open
      ..add(client)
      ..add(upstream);

    // Yön başına TEK SIRALI KUYRUK.
    //
    // İlk sürüm çerçeve başına bir `Timer` kuruyordu ve sıra BOZULUYORDU:
    // Dart'ın zamanlayıcı çözünürlüğü milisaniye, dolayısıyla 300 µs ile
    // 900 µs aynı milisaniyeye yuvarlanıyor ve hangisinin önce ateşleyeceği
    // belirsizleşiyor. Ölçüldü — istemciye ulaşan tikler: 40, 42, 41, 43, 45.
    //
    // Bu, WebSocket'in yapmadığı bir şey: taşıma TCP ve TCP sırayı KORUR.
    // Geciken bir segment arkasındaki her şeyi bekletir (head-of-line
    // blocking), önüne geçirmez. Sıra bozan bir vekil, gerçekte imkânsız bir
    // senaryo üretiyor ve "önceki paket ulaştı" varsayan her tasarımı — delta
    // sıkıştırma dahil — haksız yere kırıyordu.
    //
    // Kuyruk + tek zamanlayıcı bunu kesin olarak çözüyor: teslim sırası
    // gönderim sırasıdır, nokta.
    final queues = <WebSocket, List<(int, Object?)>>{};
    final draining = <WebSocket, bool>{};
    final lastDelivery = <WebSocket, int>{};

    void drain(WebSocket to) {
      final queue = queues[to];
      if (queue == null || queue.isEmpty) {
        draining[to] = false;
        return;
      }
      draining[to] = true;
      final now = DateTime.now().microsecondsSinceEpoch;
      final (at, data) = queue.first;
      if (at <= now) {
        queue.removeAt(0);
        try {
          to.add(data!);
        } on Object {
          // Kapanmış soket; kapanış aşağıda ele alınıyor.
        }
        // Kuyruğun kalanı için hemen yeniden dene.
        scheduleMicrotask(() => drain(to));
        return;
      }
      Timer(Duration(microseconds: at - now), () => drain(to));
    }

    void forward(WebSocket to, Object? data) {
      final now = DateTime.now().microsecondsSinceEpoch;
      var delay = _oneWay().inMicroseconds;
      // Yeniden gönderim: kayıp değil, fazladan bir gidiş-dönüş gecikmesi.
      if (_retransmit()) delay += rttMs * 1000;
      final earliest = now + delay;
      final previous = lastDelivery[to] ?? 0;
      final at = earliest > previous ? earliest : previous;
      lastDelivery[to] = at;
      (queues[to] ??= []).add((at, data));
      if (draining[to] != true) drain(to);
    }

    client.listen(
      (data) => forward(upstream, data),
      onDone: () => upstream.close(),
      onError: (_) => upstream.close(),
    );
    upstream.listen(
      (data) {
        final bozuk = corruptDownstream == null
            ? data
            : corruptDownstream!(data);
        if (bozuk != null) forward(client, bozuk);
      },
      onDone: () => client.close(),
      onError: (_) => client.close(),
    );
  }

  Future<void> stop() async {
    for (final socket in _open) {
      try {
        await socket.close();
      } on Object {
        // zaten kapalı
      }
    }
    _open.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
