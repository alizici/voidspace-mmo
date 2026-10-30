import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:voidspace_core/voidspace_core.dart';

import 'accounts.dart';
import 'hangars.dart';
import 'harita_kaydi.dart';
import 'ledger_store.dart';
import 'tick_stats.dart';
import 'zone.dart';

/// Sızdıran kova (漏桶): sabit hızda dolan, çerçeve başına bir jeton harcanan
/// sayaç.
///
/// Sabit bir "saniyede N" sayacı değil, çünkü o, saniye sınırında iki kat
/// patlamaya izin verir. Kova hem ORTALAMA hızı hem de ANLIK patlamayı ayrı
/// ayrı sınırlar: [capacity] patlamanın tavanı, [perSecond] uzun vadeli hız.
class _Bucket {
  _Bucket({required this.capacity, required this.perSecond})
    : _tokens = capacity.toDouble();

  final int capacity;
  final double perSecond;
  double _tokens;
  int _lastMicros = 0;

  /// Bir jeton harca. Kova boşsa `false` — çağıran çerçeveyi atar.
  bool take(int nowMicros) {
    if (_lastMicros != 0) {
      _tokens += (nowMicros - _lastMicros) / 1e6 * perSecond;
      if (_tokens > capacity) _tokens = capacity.toDouble();
    }
    _lastMicros = nowMicros;
    if (_tokens < 1) return false;
    _tokens -= 1;
    return true;
  }
}

/// Bağlı bir istemci. Sokete dokunan TEK yer.
class Session {
  Session(this.socket, this.remote);

  final WebSocket socket;
  final String remote;

  /// Giriş yapmış hesap. Kimlik doğrulanmadan dünyaya girilemez.
  Account? account;

  /// Bu oturumdaki başarısız kimlik denemesi.
  ///
  /// Parola denemesi PAHALIDIR (ayrı isolate'te 120 bin tur). Sınırsız deneme,
  /// hem parola kırma denemesi hem de tek bağlantıyla CPU yakma yolu olurdu.
  int authAttempts = 0;

  /// ŞU AN süren bir parola türetmesi var mı.
  ///
  /// [authAttempts] tek başına YETMEZ ve bu ölçüldü: sayaç `await`'ten SONRA
  /// arttığı için, tek karede gönderilen 60 giriş denemesinin 60'ı da sınır
  /// kontrolünden geçiyordu — 60 eşzamanlı isolate, her biri 120 bin tur.
  /// Tek soketle sunucunun CPU'sunu yakmaya yetiyordu (ölçüm: 60/60 geçti).
  /// Aynı anda tek türetme kuralı bu kapıyı kapatıyor.
  bool authInFlight = false;

  /// El sıkışma tamamlanana kadar `null`. Gemisi olmayan bir oturum yalnız
  /// [ClientHello] gönderebilir — kimliksiz girdi kabul edilmez.
  ServerShip? ship;

  /// Oyuncunun BULUNDUĞU harita.
  ///
  /// Oturumun kendisinde duruyor, gemide değil: geçitten geçerken gemi yeni
  /// hücrede yeniden yaratılıyor ama oturum aynı kalıyor. Ayrıca yayınların
  /// kime gideceğini bu belirliyor — bir haritadaki olay diğerine sızmamalı.
  Harita harita = HaritaDefteri.baslangic;

  /// İstemciden EN SON çerçeve alınan tik.
  ///
  /// Yalnız girdi değil HER çerçeve sayılır: canlılığın ölçüsü "oynuyor mu"
  /// değil "soket akıyor mu". Yavaş istemciyi ayırt eden tek sinyalimiz bu —
  /// `dart:io` WebSocket'i kuyruğunda bekleyen bayt miktarını açmıyor.
  int lastHeardTick = 0;

  /// Bu oturuma bir sonraki snapshot TAM mı gitmeli.
  ///
  /// Delta'nın temeli "geçen tikin snapshot'ı"; bu oturum onu ALMADIYSA temel
  /// yok demektir. İki durumda olur: oturum yeni kuruldu, ya da yavaş istemci
  /// olduğu için bir snapshot atlandı. İkisinde de kısmi kayıt göndermek,
  /// istemcinin olmayan bir geçmişin üstüne delta uygulaması demek olurdu —
  /// yani sessizce yanlış konum.
  bool needsFullSnapshot = true;

  /// Genel çerçeve hızı. 30 Hz girdi + seyrek ping'in çok üstünde bir tavan:
  /// meşru istemci buna hiç değmez, sel gönderen ilk saniyede çarpar.
  final _frames = _Bucket(capacity: 120, perSecond: 90);

  /// Kimlik denemeleri AYRI ve çok daha dar bir kovada: her biri bir isolate
  /// ve 120 bin tur demek.
  final _auth = _Bucket(capacity: 6, perSecond: 0.5);

  bool _closed = false;

  bool allowFrame(int nowMicros) => _frames.take(nowMicros);

  bool allowAuth(int nowMicros) => _auth.take(nowMicros);

  void send(ServerMessage message) => sendBytes(message.encode());

  void sendBytes(List<int> bytes) {
    if (_closed) return;
    try {
      socket.add(bytes);
    } on Object {
      // Kapanmakta olan sokete yazmak istisna atar; kapanış zaten `done`
      // üzerinden ele alınıyor.
      _closed = true;
    }
  }

  Future<void> close([String reason = '']) async {
    if (_closed) return;
    _closed = true;
    await socket.close(WebSocketStatus.normalClosure, reason);
  }
}

/// Soketleri kabul eder, çerçeveleri [Zone]'a çevirir ve tik saatini tutar.
///
/// Oyun mantığı BURADA YOK — bilerek. Zone'un ağdan haberi olmaması, onu
/// soketsiz test edilebilir tutan şey.
class Gateway {
  Gateway({
    Zone? zone,
    AccountStore? accounts,
    HangarStore? hangars,
    LedgerStore? ledger,
    this.devRichAccounts = const {},
    this.devFullAccounts = const {},
    this.webRoot,
    this.allowDebugCommands = false,
    this.maxSessionsPerIp = 64,
    this.maxSessions = 4096,
  }) : defter = HaritaDefteri(baslangicHucresi: zone),
       accounts = accounts ?? AccountStore(),
       hangars = hangars ?? HangarStore(),
       ledger = ledger ?? LedgerStore();

  final AccountStore accounts;

  /// Oyuncuların kalıcı ilerlemesi: para, gemiler, envanter, donatım.
  final HangarStore hangars;

  /// Para hareketlerinin kalıcı defteri — bkz. [LedgerStore].
  final LedgerStore ledger;

  /// Benzersiz işlem kimliği üretir.
  ///
  /// Tik sayacı + oturum kimliği + sayaç: aynı tikte aynı oyuncunun iki
  /// hareketi bile ayrışıyor. Tekrarlanan bir kimlik `LedgerStore` tarafından
  /// reddediliyor, yani üretimdeki bir çakışma sessiz kalmıyor.
  int _txCounter = 0;
  TxContext _tx(String accountId) => TxContext(
    id: '$tick-$accountId-${_txCounter++}',
    atMillis: DateTime.now().millisecondsSinceEpoch,
  );

  /// Hangarın defterini boşaltıp deftere yazar.
  ///
  /// HER para hareketinden sonra çağrılmak zorunda. Çağrılmazsa hareketler
  /// hangarın içinde birikir — `pendingLedgerEntries` sıfırdan farklı kalır ve
  /// test bunu yakalar. Yani "deftere yazmayı unutmak" sessiz bir hata değil.
  void _collectLedger(Hangar hangar) => ledger.add(hangar.takeJournal());

  /// GELİŞTİRME kolaylığı: bu kullanıcı adları zengin başlar.
  ///
  /// **Neden kod içinde bir isim listesi YOK.** "CINAR'ın kredisi yüksek
  /// olsun" isteğinin en kısa cevabı `if (username == 'CINAR')` yazmaktı ve o
  /// satır, sunucuya adı geçen herkesin sınırsız parası olduğu bir arka kapı
  /// olarak DERLENİR. Bu projedeki her şey — otoritenin sunucuda olması, hız
  /// sınırı, ilgi alanı filtresi — o tür bir satırın tersi.
  ///
  /// Onun yerine ortam değişkeni (`DEV_RICH=CINAR,alizi`): varsayılan BOŞ,
  /// üretimde tanımlanmaz, ve tanımlıysa sunucu açılışta bağırır.
  final Set<String> devRichAccounts;

  /// Zengin başlayan hesabın taban bakiyesi — TAM DONANIMIN maliyetinden.
  ///
  /// Tavan değil TABAN: bunun üstündeki bir bakiyeye dokunulmuyor, yoksa
  /// geliştirme oturumunda kazanılan para her girişte silinirdi. Ve harcanan
  /// para geri geliyor, yani mağaza sınamak için tekrar tekrar giriş
  /// gerekmiyor.
  ///
  /// **Elle yazılmış 500.000.000'dı ve bayatladı.** Merdiven yirmi ranka
  /// uzayınca tepe lazerin fiyatı 13,2 MİLYAR oldu (fiyat rank çarpanının
  /// karesi, tepe çarpan 1.048×). Bütün alımlar sessizce başarısız oldu ve
  /// "tam donanımlı" hesap boş yuvalarla açıldı — hiçbir hata mesajı
  /// vermeden, çünkü `buyItem`'ın başarısızlığı `continue` ile yutuluyor.
  ///
  /// Artık maliyetin kendisinden türüyor: merdiven bir daha uzasa da, fiyat
  /// tabanı değişse de birlikte büyüyor.
  static int get devRichCredits => _tamDonanimMaliyeti(Currency.credit);

  static int get devRichPremium => _tamDonanimMaliyeti(Currency.premium);

  /// En iyi gövdeyi en iyi eşyalarla doldurup hepsini tavana çıkarmanın
  /// [para] cinsinden maliyeti, iki katıyla.
  ///
  /// İki kat: yükseltme sırasında ara adımlar da ödeniyor ve geliştirme
  /// oturumunun kendisi harcıyor. Dar bir pay, aynı sessiz başarısızlığı
  /// geri getirirdi.
  static int _tamDonanimMaliyeti(Currency para) {
    final govde = HullClass.all.last;
    var toplam = 0.0;
    for (final tip in SlotType.values) {
      final spec = _enIyiEsya(tip);
      if (spec == null) continue;
      final fiyat = Catalogue.priceOf(spec);
      if (fiyat.currency != para) continue;
      final birim =
          fiyat.amount + ItemLevels.totalCost(ItemLevels.max, spec.tier);
      toplam += birim * govde.slotCount(tip);
    }
    // Gövdenin kendisi de alınıyor.
    final govdeFiyat = Catalogue.hullPrice(govde);
    if (govdeFiyat != null && govdeFiyat.currency == para) {
      toplam += govdeFiyat.amount;
    }
    return (toplam * 2).round();
  }

  /// DÜNYANIN base katmanı — bütün haritaların kalıcı kaydı.
  ///
  /// Simülasyon ([Zone]) bunun içinde tembel yaşıyor: ilk oyuncu girince
  /// açılıyor, son oyuncu çıkınca kapanıyor. Bkz. [HaritaKaydi].
  final HaritaDefteri defter;

  /// BAŞLANGIÇ haritasının hücresi.
  ///
  /// Sunucunun tek dünyası olduğu dönemden kalan ad. Bugün "yeni gelenin
  /// düştüğü harita" demek.
  Zone get zone => defter[HaritaDefteri.baslangic].ac(_tick);

  /// SUNUCUNUN saati — bölgelerin değil.
  ///
  /// Bölgeler tembel açıldığı için her birinin sayacı farklı bir anda
  /// başlıyor olabilirdi; hepsi bu saatten tohumlanıyor ve birlikte adım
  /// atıyor. Oturum canlılığı gibi bölgeler arası karşılaştırmalar buna
  /// bakmak zorunda.
  int _tick = 0;
  int get tick => _tick;

  /// BÜTÜN haritalardaki oyuncu sayısı.
  ///
  /// Tek haritalı dönemde `zone.ships.length` yeterliydi; bugün o yalnız
  /// başlangıç haritasını sayar ve raporda sunucunun yarısını gizlerdi.
  int get toplamOyuncu =>
      defter.canlilar.fold(0, (a, k) => a + k.hucre!.ships.length);

  /// Simülasyonu dönen harita sayısı — tembel kurulumun ölçüsü.
  int get canliHarita => defter.canlilar.length;

  /// İSTEMCİ TAHMİNİNİN sunucudan önde olabileceği en büyük mesafe.
  ///
  /// Onaylanmamış girdi penceresi × tik başına yol. Elle bir "tolerans"
  /// yazmak yerine türetiliyor: pencere ya da hız değişirse pay da değişiyor
  /// ve iki uç yeniden ayrışmıyor.
  static double get _tahminPayi =>
      Zone.maxPending * ShipStats.bastion.speed / Protocol.tickRate;

  /// [session]'ın bulunduğu haritanın hücresi — yoksa açar.
  Zone hucreOf(Session session) => defter[session.harita].ac(_tick);

  /// Bu hesabın sahipsiz gemisini BÜTÜN haritalarda arar.
  ///
  /// Tek haritalı dönemde arama yoktu; oyuncu nerede koptuysa oraya dönüyordu
  /// çünkü tek yer vardı. Çok haritalı dünyada aramamak, altıncı bölgede
  /// kopan oyuncuyu başlangıç haritasında yeni bir gemiyle uyandırmak olurdu.
  (HaritaKaydi, ServerShip)? _sahipsizAra(String accountId) {
    for (final kayit in defter.canlilar) {
      final ship = kayit.hucre!.reclaim(accountId);
      if (ship != null) return (kayit, ship);
    }
    return null;
  }

  /// `HASAR / ONAR` hata ayıklama komutları açık mı. **Üretimde KAPALI.**
  ///
  /// Ölçüldü: açıkken, gövdesi ve kalkanı sıfırlanmış ÖLÜ bir gemi tek bir
  /// istemci çerçevesiyle tam sağlıkla geri geliyor (0 → 12000 gövde, 0 →
  /// 8000 kalkan, `alive` yeniden `true`). Yani sınırsız ölümsüzlük, üstelik
  /// istemcinin arayüzüne değil PROTOKOLE bağlı — düğmeleri kaldırmak hiçbir
  /// şey çözmezdi, çerçeveyi elle yollamak yetiyordu.
  ///
  /// Silinmek yerine kapatılabilir olması kasıtlı: `multiplayer_test.dart`
  /// otorite döngüsünü (hasarı SUNUCU hesaplar, istemci yalnız niyet yollar)
  /// tam olarak bu komutlarla kanıtlıyor. Testin açıkça açtığı bir kapı,
  /// herkese açık bir kapıdan farklıdır.
  final bool allowDebugCommands;

  /// Tek IP'den açılabilecek eşzamanlı bağlantı.
  ///
  /// Oturum başına sınırlar tek bir soketi savunur; bu, ONLARI aşmak için
  /// bin soket açmayı savunur. İkisi olmadan diğeri eksik: kimlik kovası
  /// soket başına dolduğu için, sınırsız soket sınırsız kimlik denemesi
  /// demekti.
  ///
  /// **Neden 8 değil 64.** İlk değer 8'di ve yanlıştı: bu bir MOBİL oyun ve
  /// mobil operatörler CGNAT kullanıyor — bir bölgedeki yüzlerce abone tek bir
  /// genel IP'nin arkasından çıkabiliyor. Sekizlik bir tavan, saldırganı değil
  /// aynı operatördeki dokuzuncu oyuncuyu dışarıda bırakırdı ve bunun
  /// teşhisi neredeyse imkânsız olurdu ("bende açılmıyor").
  ///
  /// 64 soket bir saldırı değil; saldırı bin ve on binlerle ölçülür. Asıl işi
  /// yapan oturum başına kovalar, bu yalnız üst bir duvar. Yanlış pozitif
  /// riski olan bir savunmada gevşek taraf doğru taraftır.
  final int maxSessionsPerIp;

  /// Süreç genelinde eşzamanlı soket tavanı — dosya tanıtıcısı tükenmesin.
  final int maxSessions;

  /// Ayarlıysa, derlenmiş web istemcisi de buradan sunulur.
  ///
  /// Kolaylık için değil DOĞRULUK için: Flutter'ın Wasm derleyicisi (Skwasm)
  /// çizimi bir Web Worker'a taşıyor ve bunun için `SharedArrayBuffer`
  /// gerekiyor. Tarayıcı onu yalnız ÇAPRAZ KÖKEN İZOLASYONU altında açıyor,
  /// yani doğru COOP/COEP başlıkları olmadan istemci sessizce tek iş
  /// parçacığına düşüyor.
  ///
  /// Ölçüldü: başlıklarla 8.3 ms/kare, başlıksız 16.6 ms. Yani bu iki başlık
  /// kare bütçesinin yarısı — ve unutulması en kolay şey.
  final String? webRoot;

  /// Gemisi OLAN oturumlar (gemi kimliğine göre). Snapshot ve yayın yolu.
  final Map<int, Session> _sessions = {};

  /// KABUL EDİLMİŞ her soket — gemisi olsun olmasın.
  ///
  /// [_sessions] tek başına yetmiyordu ve bu bir boşluktu: kimlik doğrulaması
  /// yapmamış bir soket hiçbir yerde sayılmıyordu. Sayılmayan şey ne
  /// sınırlanabilir ne de kapatılabilir — `stop()` bile onları açık bırakıyor,
  /// yani sunucu "kapandıktan" sonra yarım oturumlar asılı kalıyordu.
  final Set<Session> _live = {};

  /// IP → o IP'den açık soket sayısı.
  final Map<String, int> _perIp = {};

  HttpServer? _http;

  /// Gerçekte bağlanılan port. `port: 0` ile başlatıldığında işletim sistemi
  /// boş bir port seçer — testlerin sabit bir port kapmadan koşabilmesi için.
  int get port => _http?.port ?? 0;
  Timer? _clock;
  Timer? _reportClock;
  final Stopwatch _uptime = Stopwatch();

  // Ölçüm penceresi — "yüksek performans" iddiası ölçülmeden yapılmaz.
  int _windowTicks = 0;

  /// Tik İŞ süresinin dağılımı. Ortalama artık tek başına raporlanmıyor —
  /// sebebi [LatencyHistogram] belgesinde.
  final LatencyHistogram _tickCost = LatencyHistogram();

  /// Tik başlarken ÖDENMEMİŞ simülasyon zamanı (µs) — "programın gerisinde
  /// miyim" sorusunun cevabı.
  ///
  /// Tik İŞİ ile tik GECİKMESİ farklı şeyler ve ikisi de gerekli. Her tiki 20
  /// ms'de bitiren bir sunucu bütçenin içindedir; ama tikler 33 ms'de bir
  /// gelmesi gerekirken 40 ms'de bir gelebiliyorsa oyun YAVAŞ akıyordur ve iş
  /// süresi bunu hiç göstermez. Yük üretecini ölçme hatasının sunucu
  /// tarafındaki karşılığı bu: yalnız işi ölçmek, saatin kaydığını gizler.
  ///
  /// Biriktirici `ShipSim.fixedDt`'nin altında kaldığı sürece sunucu
  /// yetişiyordur; büyümeye başladıysa geri kalıyordur.
  final LatencyHistogram _tickLag = LatencyHistogram();
  int _windowBytes = 0;

  /// Pencere boyunca üretilen snapshot sayısı.
  ///
  /// "Oyuncu başına KB/s" bunu bilmek zorunda: baytları pencerenin SONUNDAKİ
  /// oyuncu sayısına bölmek, kalabalık dağıldığı anda sayıyı 40 kat şişiriyor.
  /// Kendi performans iddialarını ölçen aracın yanlış ölçmesi, ölçmemekten
  /// kötü.
  int _windowSnapshots = 0;

  /// Pencere boyunca ÜRETİLEN atış olayı.
  ///
  /// İstemcide "0 mermi" görüldüğünde sorunun sunucuda mı istemcide mi
  /// olduğunu ayıran tek sayı. Onsuz teşhis tahmin zincirine dönüyor.
  int _windowShots = 0;

  /// Snapshot'lara GERÇEKTEN yazılan atış olayı.
  ///
  /// TOPLAM yanıltıcı: 40 bot birbirini görürken tek bir izleyicinin hiçbir
  /// şey almaması toplamda kaybolur (40×25 ≈ 1050, benim payım gürültü).
  /// Bu yüzden İZLEYİCİ BAŞINA dağılım tutuluyor — bir istemcinin dışarıda
  /// kaldığını yalnız en küçük değer gösterir.
  int _windowShotsWritten = 0;
  final Map<int, int> _windowShotsPerViewer = {};

  /// Yavaş/sessiz istemci yüzünden atlanan snapshot. Sıfırdan büyükse birileri
  /// akışa yetişemiyor demektir — ve bunu görmenin başka yolu yok.
  int _windowSkipped = 0;

  /// [certificatePath] ve [keyPath] verilirse sunucu **TLS** konuşur (`wss://`).
  ///
  /// Neden zorunlu: parola, oturum belirteci ve bütün oyun trafiği tel
  /// üzerinden açık gidiyor. Yerel ağda bu bir tercih; internete açıldığı anda
  /// aynı WiFi'daki herkes parolaları okuyabilir. Ayrıca `https` üzerinden
  /// sunulan bir tarayıcı istemcisi `ws://` bağlantısı AÇAMAZ — karışık
  /// içerik olarak engellenir.
  ///
  /// Sertifika sunucuya AİT DEĞİL: Let's Encrypt gibi bir sağlayıcıdan alınır
  /// ve dosya yolu verilir. Sunucu onu üretmeye çalışmaz.
  Future<void> start({
    String host = '0.0.0.0',
    int port = 8080,
    String? certificatePath,
    String? keyPath,
  }) async {
    final secure = certificatePath != null && keyPath != null;
    final server = secure
        ? await HttpServer.bindSecure(
            host,
            port,
            SecurityContext()
              ..useCertificateChain(certificatePath)
              ..usePrivateKey(keyPath),
          )
        : await HttpServer.bind(host, port);
    _http = server;
    _uptime.start();

    stdout.writeln(
      'voidspace sunucu · ${secure ? 'wss' : 'ws'}://$host:${server.port} · '
      '${Protocol.tickRate} Hz tik · '
      '${Protocol.snapshotRate} Hz snapshot · '
      'protokol v${Protocol.version}',
    );

    unawaited(_serve(server));
    _startClock();
  }

  Future<void> stop() async {
    _clock?.cancel();
    // Raporlama saati de durur. Durmazsa, `stop()` çağrılmış bir sunucu
    // testlerde saniyede bir stdout'a yazmayı sürdürür ve her test bir
    // zamanlayıcı sızdırır.
    _reportClock?.cancel();
    _clock = null;
    _reportClock = null;
    // Gemisi OLMAYAN oturumlar da kapanır: `_sessions` yalnız dünyaya girmiş
    // olanları tutuyor, yarım kalmış el sıkışmalar orada yok.
    for (final session in _live.toList()) {
      await session.close('sunucu kapanıyor');
    }
    _live.clear();
    _perIp.clear();
    _reserved = 0;
    await _http?.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      if (request.uri.path == '/health') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('{"players":$toplamOyuncu,"maps":$canliHarita,"tick":$tick}');
        await request.response.close();
        continue;
      }
      if (request.uri.path == '/dev/para') {
        await _devPara(request);
        continue;
      }
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        await _serveStatic(request);
        continue;
      }
      unawaited(_accept(request));
    }
  }

  /// CANLI PARA — açık oyuna anında bakiye (yalnız geliştirme).
  ///
  /// `POST /dev/para?hesap=CINAR&kredi=1000000&nova=5000`
  ///
  /// **Neden bir uç var.** Hangar dosyası (`hangars.jsonl`) sunucu ayaktayken
  /// ELLE düzenlenemez: kayıtlar açılışta belleğe alınıyor ve sıkıştırma
  /// dosyayı bellekten yeniden yazıyor, yani dışarıdan yapılan bir düzenleme
  /// hem görülmüyor hem de ilk sıkıştırmada siliniyor. Canlı bakiye
  /// değiştirmenin tek doğru yolu sunucunun kendisinden geçmek.
  ///
  /// İki kapı: hata ayıklama komutları açık olacak (`DEBUG_COMMANDS=true`) ve
  /// istek YEREL makineden gelecek. İkisi de olmadan uç 404 — kapalı bir
  /// uçtan "yetkin yok" cevabı bile vermiyoruz, çünkü var olduğunu söylemek
  /// gereksiz.
  ///
  /// Bakiye deftere yazılıyor (`LedgerReason.devGrant`) ve oyuncu açıksa
  /// hangar durumu ANINDA gönderiliyor: ekrandaki sayı elle yenilemeden
  /// değişiyor.
  Future<void> _devPara(HttpRequest request) async {
    Future<void> cevap(int kod, String govde) async {
      request.response
        ..statusCode = kod
        ..headers.contentType = ContentType.json
        ..write(govde);
      await request.response.close();
    }

    // YEREL demek "soket loopback'ten geldi" DEĞİL — bir tünel (cloudflared,
    // ngrok) sunucuya hep 127.0.0.1'den bağlanıyor, yani tünel açıldığı anda
    // dünyanın herkesi "yerel" görünür ve para basabilirdi. Vekilden geçmiş
    // her istek bu yüzden reddediliyor: vekil kendini başlıkla ilan ediyor.
    final baglanti = request.connectionInfo?.remoteAddress;
    final vekil =
        request.headers['cf-connecting-ip'] != null ||
        request.headers['x-forwarded-for'] != null ||
        request.headers['forwarded'] != null;
    final yerel = (baglanti?.isLoopback ?? false) && !vekil;
    if (!allowDebugCommands || !yerel) {
      await cevap(HttpStatus.notFound, '{"hata":"yok"}');
      return;
    }

    final q = request.uri.queryParameters;
    final hesapAdi = q['hesap'] ?? '';
    final kredi = int.tryParse(q['kredi'] ?? '') ?? 0;
    final nova = int.tryParse(q['nova'] ?? '') ?? 0;
    final account = accounts.adiyla(hesapAdi);
    if (account == null) {
      await cevap(HttpStatus.notFound, '{"hata":"hesap yok: $hesapAdi"}');
      return;
    }
    if (kredi <= 0 && nova <= 0) {
      await cevap(HttpStatus.badRequest, '{"hata":"kredi ya da nova gerekli"}');
      return;
    }

    final hangar = hangars.of(account.id);
    final tx = _tx(account.id);
    if (kredi > 0) {
      hangar.earn(
        Currency.credit,
        kredi,
        reason: LedgerReason.devGrant,
        txId: '${tx.id}-kredi',
        atMillis: tx.atMillis,
      );
    }
    if (nova > 0) {
      hangar.earn(
        Currency.premium,
        nova,
        reason: LedgerReason.devGrant,
        txId: '${tx.id}-nova',
        atMillis: tx.atMillis,
      );
    }
    _collectLedger(hangar);
    _dirtyHangars.add(account.id);

    // Açık oturuma ANINDA yeni durum: oyuncunun ekranındaki sayı elle
    // yenilemeden değişsin.
    for (final session in _live) {
      if (session.account?.id == account.id) {
        session.send(ServerHangarState(_hangarJson(hangar, null)));
      }
    }

    await cevap(
      HttpStatus.ok,
      '{"hesap":"${account.username}","kredi":${hangar.credits},'
      '"nova":${hangar.premium}}',
    );
  }

  static final Map<String, ContentType> _types = {
    '.html': ContentType.html,
    '.js': ContentType('text', 'javascript', charset: 'utf-8'),
    '.mjs': ContentType('text', 'javascript', charset: 'utf-8'),
    '.json': ContentType.json,
    '.wasm': ContentType('application', 'wasm'),
    '.css': ContentType('text', 'css', charset: 'utf-8'),
    '.png': ContentType('image', 'png'),
    '.ico': ContentType('image', 'x-icon'),
    '.svg': ContentType('image', 'svg+xml'),
    '.ttf': ContentType('font', 'ttf'),
    '.otf': ContentType('font', 'otf'),
    '.symbols': ContentType.json,
  };

  Future<void> _serveStatic(HttpRequest request) async {
    final root = webRoot;
    if (root == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    // Dizin kaçışına kapalı: `..` içeren bir yol sunucunun tüm dosya sistemini
    // açardı. Kanonik yolun kökün altında kaldığını doğrulamak tek güvenilir
    // kontrol — yol parçalarını elemek değil.
    final rootPath = Directory(root).absolute.path;
    final relative = request.uri.path == '/' ? '/index.html' : request.uri.path;
    final file = File('$rootPath$relative').absolute;
    if (!file.path.startsWith(rootPath) || !file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final dot = file.path.lastIndexOf('.');
    request.response.headers
      // Skwasm'ın çok iş parçacıklı çizimini açan iki başlık.
      ..set('Cross-Origin-Opener-Policy', 'same-origin')
      ..set('Cross-Origin-Embedder-Policy', 'credentialless')
      ..contentType =
          _types[dot < 0 ? '' : file.path.substring(dot)] ?? ContentType.binary;
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  Future<void> _accept(HttpRequest request) async {
    final remote = request.connectionInfo?.remoteAddress.address ?? '?';

    // Tavanlar el sıkışmadan ÖNCE: reddedilecek bir bağlantı için WebSocket
    // yükseltmesi yapmak, saldırganın istediği işi yapmaktır.
    if (_reserved >= maxSessions || (_perIp[remote] ?? 0) >= maxSessionsPerIp) {
      request.response.statusCode = HttpStatus.tooManyRequests;
      await request.response.close();
      return;
    }

    // Yer ŞİMDİ ayrılıyor, el sıkışmadan SONRA değil.
    //
    // `upgrade` bir `await` ve arada olay döngüsü başka bağlantıları işliyor:
    // aynı anda gelen yüz istek, hiçbiri henüz sayılmadığı için tavan
    // kontrolünden yüz kere geçerdi. Sayacı önce artırmak o pencereyi kapatıyor.
    _perIp[remote] = (_perIp[remote] ?? 0) + 1;
    _reserved++;

    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
    } on Object {
      _release(remote);
      return;
    }
    final session = Session(socket, remote)..lastHeardTick = tick;
    _live.add(session);

    socket.listen(
      (data) => _onFrame(session, data),
      onDone: () => _forget(session),
      onError: (_) => _forget(session),
      cancelOnError: true,
    );
  }

  /// Ayrılmış ama henüz [_live]'a girmemiş yerler de dahil, açık soket sayısı.
  int _reserved = 0;

  void _release(String remote) {
    _reserved--;
    final count = (_perIp[remote] ?? 1) - 1;
    if (count <= 0) {
      _perIp.remove(remote);
    } else {
      _perIp[remote] = count;
    }
  }

  /// Soket kapandı: sayaçlardan düş, sonra gemiyi ele al.
  void _forget(Session session) {
    if (_live.remove(session)) _release(session.remote);
    _drop(session);
  }

  /// Kabul edilen en büyük istemci çerçevesi.
  ///
  /// En büyük meşru çerçeve kayıt: e-posta + kullanıcı adı + parola, hepsi
  /// [Credentials] sınırlarında, toplam ~300 bayt. 4 KB bunun on katı ve
  /// keyfî büyüklükte bir çerçevenin çözücüye ulaşmasını engelliyor.
  static const int _maxFrameBytes = 4096;

  /// Bir çerçeveyi işle — HATASI O OTURUMDA KALSIN.
  ///
  /// Dinleyicinin içinden fırlayan bir istisna bölgeye çıkıyor ve süreci
  /// öldürüyordu: tek oyuncunun bozuk hangarı BÜTÜN sunucuyu düşürüyor,
  /// dövüşen herkes atılıyordu. Üstelik bozuk durum diskte kaldığı için
  /// sunucu her açılışta o oyuncunun `hello`'sunda yeniden çöküyordu —
  /// düzelmeyen bir döngü.
  ///
  /// Sarmalama hatayı GİZLEMİYOR: günlüğe tam iziyle yazılıyor ve o oturum
  /// kapatılıyor. Kapatılıyor, çünkü istisnadan sonra oturumun durumu
  /// belirsiz; yarım bir oturumu ayakta tutmak sessiz bozulmanın yolu.
  void _onFrame(Session session, Object? data) {
    try {
      _cerceve(session, data);
    } on Object catch (hata, iz) {
      _cerceveHatasi(session, hata, iz);
    }
  }

  /// Eşzamansız işleyicinin hatası da AYNI yere düşsün.
  ///
  /// `unawaited` bir hatayı yutmuyor, bölgeye SALIYOR — ve bölgede yakalayan
  /// yok, süreç ölüyor. `_onFrame`'in try'ı bunları göremez: hata bir
  /// askıya alınmadan sonra geliyor, çağrı yığını çoktan dönmüş oluyor.
  void _oturumda(Session session, Future<void> is_) {
    unawaited(
      is_.catchError((Object hata, StackTrace iz) {
        _cerceveHatasi(session, hata, iz);
      }),
    );
  }

  void _cerceveHatasi(Session session, Object hata, StackTrace iz) {
    final kim = session.account?.username ?? 'kimliksiz';
    stderr.writeln('! çerçeve işlenemedi ($kim): $hata');
    stderr.writeln(iz);
    unawaited(session.close('sunucu hatası'));
  }

  void _cerceve(Session session, Object? data) {
    session.lastHeardTick = tick;

    // Metin çerçevesi protokolde YOK. Kabul etmek, ikili çözücünün hiç
    // görmemesi gereken bir yolu açık bırakmak olurdu.
    if (data is! List<int>) {
      unawaited(session.close('ikili çerçeve bekleniyor'));
      return;
    }
    if (data.length > _maxFrameBytes) {
      unawaited(session.close('çerçeve çok büyük'));
      return;
    }
    if (!session.allowFrame(_uptime.elapsedMicroseconds)) {
      // Sel gönderen istemci UYARILMAZ, düşürülür: hız sınırını bildirmek,
      // saldırgana sınırın tam yerini ölçme imkânı verir.
      unawaited(session.close('çerçeve hızı aşıldı'));
      return;
    }
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);

    switch (ClientMessage.decode(bytes)) {
      case ClientHello(:final protocolVersion, :final token):
        _onHello(session, protocolVersion, token);
      case ClientRegister(
        :final protocolVersion,
        :final email,
        :final username,
        :final password,
      ):
        _oturumda(
          session,
          _onAuth(
            session,
            protocolVersion,
            () => accounts.register(
              email: email,
              username: username,
              password: password,
            ),
          ),
        );
      case ClientLogin(
        :final protocolVersion,
        :final username,
        :final password,
      ):
        _oturumda(
          session,
          _onAuth(
            session,
            protocolVersion,
            () => accounts.login(usernameOrEmail: username, password: password),
          ),
        );
      case ClientInput(:final input):
        final ship = session.ship;
        if (ship != null) hucreOf(session).enqueue(ship, input);
      case ClientPing(:final clientTimeMs):
        session.send(ServerPong(clientTimeMs, _uptime.elapsedMilliseconds));
      case ClientHangar(:final action, :final payload):
        _oturumda(session, _onHangar(session, action, payload));
      case ClientGecit():
        _onGecit(session);
      case ClientDebug(:final kind):
        _onDebug(session, kind);
      case MalformedMessage(:final reason):
        // Bozuk çerçeve = bozuk istemci ya da sonda. İkisiyle de konuşmuyoruz.
        unawaited(session.close('bozuk çerçeve: $reason'));
    }
  }

  /// Bu oturumda izin verilen başarısız kimlik denemesi.
  static const int _maxAuthAttempts = 8;

  /// Kayıt ve giriş ORTAK yol: ikisi de bir hesap üretir ya da sebep döner.
  ///
  /// `async` ve `unawaited` ile çağrılıyor çünkü parola türetmesi ayrı bir
  /// isolate'te ~100 ms sürüyor. Beklenseydi oyun tiki dururdu.
  Future<void> _onAuth(
    Session session,
    int version,
    Future<Account> Function() attempt,
  ) async {
    if (version != Protocol.version) {
      session.send(
        ServerAuthError(
          'Sürüm uyuşmuyor: sunucu v${Protocol.version}, istemci v$version',
        ),
      );
      return;
    }
    if (session.account != null) return; // zaten girmiş

    // AYNI ANDA TEK türetme. Bu kontrol `await`'ten önce ve ilk sırada olmak
    // ZORUNDA: tek karede gelen çerçeveler arasında hiçbir zamanlayıcı turu
    // yok, yani buraya kadar gelen her çerçeve diğerlerinden habersiz.
    if (session.authInFlight) return;
    if (session.authAttempts >= _maxAuthAttempts ||
        !session.allowAuth(_uptime.elapsedMicroseconds)) {
      session.send(ServerAuthError(KimlikKodu.cokFazlaDeneme.kod));
      unawaited(session.close('deneme sınırı'));
      return;
    }

    // Sayaç türetmeden ÖNCE artar.
    //
    // Sonra artırmak, sınırı tamamen etkisiz kılıyordu: 60 çerçeve 60 kez
    // `authAttempts == 0` görüp geçiyor, sayaç ancak 100 ms sonra, iş bittikten
    // sonra artıyordu. Bir sınır, koruduğu işten SONRA sayarsa sınır değildir.
    session.authAttempts++;
    session.authInFlight = true;

    try {
      final account = await attempt();
      session.account = account;
      final token = accounts.issueToken(account);
      session.send(ServerAuthOk(token: token, username: account.username));
      stdout.writeln('· kimlik: ${account.username} (${session.remote})');
    } on AuthFailure catch (failure) {
      session.send(ServerAuthError(failure.reason));
    } on Object catch (error) {
      // Beklenmeyen hata istemciye AYRINTILI dönmez: yığın izi ya da dosya
      // yolu sızdırmak saldırgana harita vermektir. Sunucu günlüğüne ise
      // yazılır — yoksa gerçek bir arıza sessizce "tekrar deneyin"e dönerdi.
      stderr.writeln('kimlik hatası: $error');
      session.send(ServerAuthError(KimlikKodu.sunucuHatasi.kod));
    } finally {
      session.authInFlight = false;
    }
  }

  void _onHello(Session session, int version, String token) {
    if (session.ship != null) return; // ikinci el sıkışma yok sayılır
    if (version != Protocol.version) {
      // Kod, iki sürüm sayısını argüman olarak taşıyor: metni istemci kuruyor
      // ama SUNUCUNUN beklediği sürümü bilemez — ayrışan şey tam olarak o.
      session.send(
        ServerRejected(
          KimlikKodu.surumUyusmazligi.yaz([Protocol.version, version]),
        ),
      );
      unawaited(session.close('sürüm uyuşmazlığı'));
      return;
    }

    // Ad artık İSTEMCİNİN SÖYLEDİĞİ bir şey değil, belirtecin çözdüğü hesabın
    // adı. Taklit bu tek satırla kapanıyor.
    final account = session.account ?? accounts.accountFor(token);
    if (account == null) {
      // Bayat belirteç bir RED DEĞİL, kimlik akışının olağan başlangıcı.
      //
      // Belirteçler yalnız BELLEKTE yaşıyor (bkz. `AccountStore._tokens`),
      // yani sunucunun her yeniden başlaması eldeki bütün belirteçleri
      // geçersiz kılıyor — ve `tool/dev.sh` bunu her `flutter run`'da yapıyor.
      // Yani bu yol geliştirmede istisna değil, KURAL.
      //
      // Eskiden burada soket de KAPANIYORDU. Sonucu şuydu: istemci giriş
      // ekranını gösteriyor, oyuncu parolasını yazıyor, giriş çerçevesi
      // KAPALI kanala düşüyor ve istemci sonsuza kadar "doğrulanıyor" fazında
      // kalıyordu. Oyuncunun gördüğü şey "ilk girişte oyuna girmiyor, ikinci
      // girişte giriyor" idi — ikincisi çalışıyordu çünkü uygulama yeniden
      // başlatılınca bayat belirteç silinmiş oluyordu.
      //
      // Soketi açık bırakmak hem o çıkmazı kapatıyor hem bir turu siliyor:
      // oyuncu AYNI kanaldan giriş yapıp dünyaya giriyor.
      session.send(ServerAuthError(KimlikKodu.oturumDoldu.kod));
      return;
    }
    session.account = account;

    // HESAP BAŞINA TEK OTURUM.
    //
    // İkincisine izin vermek iki gemiyi aynı hesaba bağlar ve hangisinin
    // gerçek olduğu belirsizleşir. Yeni bağlantı kazanır: kullanıcı yeni
    // cihazından giriyordur, eski oturum büyük olasılıkla ölü bir sekmedir.
    final existing = _sessionOfAccount(account.id);
    if (existing != null && existing != session) {
      existing.send(ServerRejected(KimlikKodu.baskaCihaz.kod));
      unawaited(existing.close('başka oturum'));
      _drop(existing, immediate: true);
    }

    final name = _sanitise(account.username);

    // Kopmuş oturumun gemisi hâlâ bekliyorsa ONA DÖN.
    //
    // Yeni gemi vermek, iki saniyelik bir ağ kesintisinde oyuncunun konumunu,
    // hızını ve içinde olduğu savaşı kaybetmesi demekti.
    final sahipsiz = _sahipsizAra(account.id);
    if (sahipsiz != null) {
      // Sahipsiz gemi zaten bir haritada duruyor; kayıt okunmuyor. Kopan
      // oyuncu bıraktığı yerde, hatta bıraktığı KONUMDA uyanıyor.
      session.harita = sahipsiz.$1.harita;
    } else {
      // Kayıttan geri yükle — ama kapıyı YENİDEN sına. Kural çekirdekte
      // (`GalaksiHaritasi.girisNoktasi`) çünkü bir tasarım kararı: kapı bir
      // durum, bir kereye mahsus sınav değil.
      session.harita = GalaksiHaritasi.girisNoktasi(
        kayitliId: hangars.of(account.id).haritaId,
        br: CombatGlossary.battleRating(_statsFor(account.id)),
        seviye: hangars.of(account.id).seviye,
      );
    }
    final hucre = hucreOf(session);
    final reclaimed = sahipsiz?.$2;
    final ship =
        reclaimed ??
        hucre.join(
          name,
          accountId: account.id,
          // Donatım SAVAŞA giriyor: hangarda takılan lazer, dünyadaki geminin
          // hasarı. Bu satır olmadan hangar hiçbir şey yapmayan bir menü.
          stats: _statsFor(account.id),
        );
    if (ship == null) {
      session.send(ServerRejected(KimlikKodu.sunucuDolu.kod));
      unawaited(session.close('dolu'));
      return;
    }

    session.ship = ship;
    _sessions[ship.id] = session;

    session.send(
      ServerWelcome(
        entityId: ship.id,
        tickRate: Protocol.tickRate,
        snapshotRate: Protocol.snapshotRate,
        worldWidth: hucre.world.width,
        worldHeight: hucre.world.height,
        worldMargin: hucre.world.margin,
        bolgeKademe: session.harita.bolge.kademe,
        haritaTipi: session.harita.tip.index,
      ),
    );
    // Mevcut kadro yeni gelene; yeni gelen herkese. Adlar snapshot'ta değil
    // çünkü ömürde bir kez değişiyorlar.
    for (final other in hucre.ships.values) {
      session.send(_metaOf(other));
    }
    final meta = _metaOf(ship);
    ship.metaImzasi = _metaImzasi(meta);
    _broadcast(meta, harita: session.harita, except: ship.id);

    _applyDevRiches(account.username, account.id);
    _applyDevFull(account.username, account.id);
    // Tam donanım hangarı doldurdu ama gemi az önce eski donatımla doğdu:
    // statlar ve meta (filo, formasyon) ŞİMDİ gemiye geçiyor. Hangar
    // değişmediyse iki adım da sessiz: stat aynı, imza aynı.
    _applyLoadout(session);

    // Hangar durumu el sıkışmayla birlikte gidiyor: oyuncu dünyaya girdiği an
    // parasını ve donatımını biliyor, ayrıca bir tur istemesi gerekmiyor.
    session.send(ServerHangarState(_hangarJson(hangars.of(account.id), null)));

    stdout.writeln(
      '${reclaimed != null ? '↻' : '+'} $name #${ship.id} '
      '(${session.remote}) · ${hucre.ships.length} oyuncu · ${session.harita.ad}',
    );
  }

  /// Hangar komutu.
  ///
  /// **Kararı SUNUCU veriyor.** İstemci "şu lazeri şu yuvaya tak" diye niyet
  /// yolluyor; parası yeter mi, eşya onda mı, yuva o gövdede var mı — hepsi
  /// burada, `HangarRules` üzerinden. İstemcide doğrulamak kolaylık; burada
  /// doğrulamak kuralın kendisi.
  ///
  /// Her başarılı işlemden sonra hangar diske yazılıp TAM durum geri
  /// gönderiliyor. Kısmi güncelleme göndermek, istemci ile sunucunun sessizce
  /// ayrışabileceği bir yol açardı — ve envanterde ayrışma, oyuncunun parasını
  /// kaybetmesi demek.
  Future<void> _onHangar(
    Session session,
    String action,
    Map<String, Object?> payload,
  ) async {
    final account = session.account;
    if (account == null) return; // kimliksiz hangar yok

    final hangar = hangars.of(account.id);
    HangarError? error;
    var changed = false;

    String? text(String key) =>
        payload[key] is String ? payload[key]! as String : null;

    switch (action) {
      case 'refresh':
        break;

      case 'buy_item':
        final specId = text('specId');
        if (specId == null) {
          error = HangarError.notFound;
          break;
        }
        // Örnek kimliğini SUNUCU üretiyor: istemcinin verdiği bir kimlik,
        // var olan bir eşyanın üstüne yazmanın yolu olurdu.
        final instanceId = _newInstanceId();
        // Raf oyuncunun BULUNDUĞU bandın bir altı (15.2): bandı sunucu
        // biliyor, istemcinin söylediğine bakılmıyor. KARAR 15.2 s1
        final (item, failure) = HangarRules.raftanAl(
          hangar,
          specId,
          instanceId,
          _tx(account.id),
          bandRank: hucreOf(session).bolge.ilkRank,
        );
        error = failure;
        changed = item != null;

      case 'buy_hull':
        final hullId = text('hullId');
        error = hullId == null
            ? HangarError.notFound
            : HangarRules.buyHull(hangar, hullId, _tx(account.id));
        changed = error == null;

      case 'equip':
        final slot = SlotRef.parse(text('slot') ?? '');
        final instanceId = text('instanceId');
        if (slot == null || instanceId == null) {
          error = HangarError.noSuchSlot;
          break;
        }
        error = HangarRules.equip(hangar, slot, instanceId);
        changed = error == null;

      case 'unequip':
        final slot = SlotRef.parse(text('slot') ?? '');
        error = slot == null
            ? HangarError.noSuchSlot
            : HangarRules.unequip(hangar, slot);
        changed = error == null;

      case 'upgrade':
        final instanceId = text('instanceId');
        error = instanceId == null
            ? HangarError.notFound
            : HangarRules.upgrade(hangar, instanceId, _tx(account.id));
        changed = error == null;

      case 'parcala':
        final instanceId = text('instanceId');
        if (instanceId == null) {
          error = HangarError.notFound;
          break;
        }
        final (_, hata) = HangarRules.parcala(hangar, instanceId);
        error = hata;
        changed = error == null;

      case 'sentez':
        // Kimlikler LİSTE olarak geliyor; gelen her şey düşman, o yüzden
        // tip denetimi burada ve `String` olmayan her eleman atılıyor.
        final ham = payload['instanceIds'];
        final ids = ham is List
            ? [
                for (final e in ham)
                  if (e is String) e,
              ]
            : const <String>[];
        // Yeni örneğin kimliği SUNUCUDAN. İstemciye bıraksaydık, var olan bir
        // eşyanın kimliğini vererek onun üstüne yazdırmak mümkün olurdu.
        final (_, sentezHatasi) = HangarRules.sentezle(
          hangar,
          ids,
          's${account.id}_${_tick}_${hangar.inventory.length}',
        );
        error = sentezHatasi;
        changed = error == null;

      case 'cevir':
        // Bütün açık alt statlar birden (karar 07.5); hangi statın
        // korunacağını kilit söylüyor, istek değil.
        final instanceId = text('instanceId');
        error = instanceId == null
            ? HangarError.notFound
            : HangarRules.cevir(
                hangar,
                instanceId,
                _ganimetZari,
                _tx(account.id),
              );
        changed = error == null;
      case 'kilit':
        final instanceId = text('instanceId');
        final statId = text('statId');
        error = instanceId == null || statId == null
            ? HangarError.notFound
            : HangarRules.kilitle(
                hangar,
                instanceId,
                statId,
                kilitli: payload['kilitli'] == true,
              );
        changed = error == null;

      case 'malzeme_al':
        final malzemeId = text('malzemeId');
        final adet = payload['adet'];
        error = malzemeId == null
            ? HangarError.notFound
            : HangarRules.malzemeAl(
                hangar,
                malzemeId,
                adet is num ? adet.toInt() : 1,
                _tx(account.id),
              );
        changed = error == null;

      case 'select_hull':
        final hullId = text('hullId');
        final ok = hullId != null && hangar.selectHull(hullId);
        error = ok ? null : HangarError.notOwned;
        changed = ok;

      case 'formasyon':
        final id = text('id');
        error = id == null
            ? HangarError.notFound
            : HangarRules.formasyonSec(hangar, id);
        changed = error == null;

      case 'filo_al':
        final instanceId = text('instanceId');
        error = instanceId == null
            ? HangarError.notFound
            : HangarRules.filoyaAl(hangar, instanceId);
        changed = error == null;

      case 'filo_cikar':
        final instanceId = text('instanceId');
        error = instanceId == null
            ? HangarError.notFound
            : HangarRules.filodanCikar(hangar, instanceId);
        changed = error == null;

      case 'mermi_al':
        final mermiId = text('mermiId');
        final adet = payload['adet'];
        error = mermiId == null
            ? HangarError.notFound
            : HangarRules.mermiAl(
                hangar,
                mermiId,
                adet is num ? adet.toInt() : 0,
                _tx(account.id),
              );
        changed = error == null;

      case 'mermi_sec':
        final id = text('id');
        error = id == null
            ? HangarError.notFound
            : HangarRules.mermiSec(hangar, id);
        changed = error == null;

      case 'roket_al':
        final roketId = text('roketId');
        final adet = payload['adet'];
        error = roketId == null
            ? HangarError.notFound
            : HangarRules.roketAl(
                hangar,
                roketId,
                adet is num ? adet.toInt() : 0,
                _tx(account.id),
              );
        changed = error == null;

      case 'roket_sec':
        final id = text('id');
        error = id == null
            ? HangarError.notFound
            : HangarRules.roketSec(hangar, id);
        changed = error == null;

      // NOVA rafı: kıt parayla taban eşya, banttan bağımsız (15.7).
      case 'nova_al':
        final specId = text('specId');
        if (specId == null) {
          error = HangarError.notFound;
        } else {
          final (_, hata) = HangarRules.novaRafindanAl(
            hangar,
            specId,
            _newInstanceId(),
            _tx(account.id),
          );
          error = hata;
        }
        changed = error == null;

      // ArGe: düğüm al ya da ağacı sıfırla (05.7).
      case 'arge_al':
        final dugumId = text('dugumId');
        error = dugumId == null
            ? HangarError.notFound
            : HangarRules.argeAl(hangar, dugumId);
        changed = error == null;

      case 'arge_sifirla':
        error = HangarRules.argeSifirla(hangar);
        changed = error == null;

      // GÖRÜNÜŞ: tasarım ve formasyon NOVA ile alınıyor (15.9).
      case 'gorunus_al':
        final tur = text('kalem');
        final id = text('id');
        final kalem = tur == 'formasyon'
            ? GorunusKalemi.formasyon
            : GorunusKalemi.tasarim;
        error = id == null
            ? HangarError.notFound
            : HangarRules.gorunusAl(hangar, kalem, id, _tx(account.id));
        changed = error == null;

      case 'droid_tasarim':
        final droidId = text('droidId');
        final tasarimId = text('tasarimId');
        error = droidId == null || tasarimId == null
            ? HangarError.notFound
            : HangarRules.droidTasarimSec(hangar, droidId, tasarimId);
        changed = error == null;

      // Droidin yuvasına eşya tak / çıkar (05.4 s5).
      case 'droid_tak':
        final droidId = text('droidId');
        final instanceId = text('instanceId');
        error = droidId == null || instanceId == null
            ? HangarError.notFound
            : HangarRules.droideTak(hangar, droidId, instanceId);
        changed = error == null;

      case 'droid_cikar':
        final instanceId = text('instanceId');
        error = instanceId == null
            ? HangarError.notFound
            : HangarRules.droidenCikar(hangar, instanceId);
        changed = error == null;

      // Droid onarımı: aşınan dayanıklılığı NOVA ile geri alır (05.10).
      case 'droid_onar':
        final instanceId = text('instanceId');
        error = instanceId == null
            ? HangarError.notFound
            : HangarRules.droidOnar(hangar, instanceId, _tx(account.id));
        changed = error == null;

      default:
        error = HangarError.notFound;
    }

    if (changed) {
      _collectLedger(hangar);
      await hangars.save(hangar);
      // Donatım değiştiyse SAVAŞAN gemi de değişmeli. Bir sonraki doğuşta
      // değil ŞİMDİ: oyuncu hangardan çıkınca yeni lazerini kullanabilmeli.
      _applyLoadout(session);
    }
    session.send(ServerHangarState(_hangarJson(hangar, error)));
  }

  /// Oyuncunun gemisine güncel donatım statlarını uygula.
  ///
  /// Havuzlar ORANLARIYLA taşınıyor: kalkanı yarıya inmiş bir oyuncu daha
  /// büyük bir kalkan taktığında tam dolu olarak çıkmamalı — o, hangarı bir
  /// tamir istasyonuna çevirirdi.
  void _applyLoadout(Session session) {
    final ship = session.ship;
    final account = session.account;
    if (ship == null || account == null) return;

    final stats = _statsFor(account.id);
    final hullFraction = ship.state.hullFraction;
    final shieldFraction = ship.state.shieldFraction;
    ship.state = ship.state.copyWith(
      stats: stats,
      hull: stats.maxHull * hullFraction,
      shield: stats.maxShield * shieldFraction,
    );
    _mermiyiUygula(ship, account.id);

    // Meta değiştiyse HERKESE söyle — kendine de.
    //
    // Meta "ömürde bir kez değişen bilgi" kanalıydı; namlu sayısı, kademe,
    // filo ve formasyon onu "nadiren değişen" yapıyor. Snapshot'a taşımak
    // alternatifti ve yanlış olurdu: saniyede otuz kez, entity başına
    // birkaç bayt, yalnız oyuncu hangarda bir şey değiştirdiğinde değişen
    // bilgi için.
    //
    // Yalnız DEĞİŞTİĞİNDE yollanıyor: her hangar tıklaması (satın alma,
    // yükseltme, gemi seçme) buradan geçiyor ve hepsinde yayın yapmak,
    // menüde gezinen tek bir oyuncunun bütün kadroya paket göndermesi
    // demekti. Ölçü namlu sayısı değil meta'nın TAMAMI: namluyu sayan eski
    // ölçü formasyonu ve filoyu görmüyor, ikisi ancak geçitten geçince
    // ekrana geliyordu.
    _metaDegistiyseYayinla(ship, session);
  }

  /// Seçili MERMİYİ gemiye geçir — hangarda ya da savaş çubuğunda seçen
  /// oyuncu bir sonraki yaylımda onu atar, geçit beklemez (17.8). Stoğu
  /// biten seçim hangarda MR-1'e düşüyor; burası onu okuyor.
  /// KARAR 17.8 s1
  void _mermiyiUygula(ServerShip ship, String accountId) {
    final hangar = hangars.of(accountId);
    final mermi = hangar.seciliMermi;
    ship
      ..mermiId = mermi.id
      ..mermiCarpani = mermi.kalkanCarpani
      ..sifon = mermi.sifon;
    // Roket mermisi de aynı yoldan (18.4): seçim ve düşüş mermininki gibi.
    final roket = hangar.seciliRoket;
    ship
      ..roketId = roket.id
      ..roketCarpani = roket.carpan.toDouble();
  }

  /// Yaylım başına MERMİ tüketimi — namlu başına bir birim (17.8).
  ///
  /// Kaynak yine `zone.shots`: zone mermiyi bilmiyor, yalnız çarpanı
  /// taşıyor. Stoğu biten mermi MR-1'e düşüyor ve gemi hemen onu atıyor;
  /// oyuncu sayacı savaş çubuğunda görüyor, o yüzden her tüketimde hangar
  /// durumu gidiyor — yalnız ücretli mermi atan oyuncuya, yaylımda bir kez.
  /// Kayıt diske hemen değil: `_dirtyHangars` ile, ganimet gibi.
  /// KARAR 17.8 s1
  void _mermiHarca(Zone zone) {
    for (final shot in zone.shots) {
      if (Protocol.isAlienId(shot.shooterId)) continue;
      final session = _sessions[shot.shooterId];
      final ship = session?.ship;
      final account = session?.account;
      if (session == null || ship == null || account == null) continue;
      final hangar = hangars.of(account.id);
      if (shot.roket) {
        // Salvo başına bir birim (18.4); biten RK-1'e düşer.
        final roket = Roket.byId(ship.roketId);
        if (roket == null || roket.bedava) continue;
        hangar.roketHarca(roket.id, 1);
        _dirtyHangars.add(account.id);
        if (hangar.roketSayisi(roket.id) <= 0) {
          hangar.roketSec(null);
          _mermiyiUygula(ship, account.id);
        }
        session.send(ServerHangarState(_hangarJson(hangar, null)));
        continue;
      }
      // Namlu başına bir birim (17.8); biten MR-1'e düşer.
      final mermi = Mermi.byId(ship.mermiId);
      if (mermi == null || mermi.bedava) continue;
      hangar.mermiHarca(mermi.id, ship.state.stats.equippedLasers);
      _dirtyHangars.add(account.id);
      if (hangar.mermiSayisi(mermi.id) <= 0) {
        hangar.mermiSec(null);
        _mermiyiUygula(ship, account.id);
      }
      session.send(ServerHangarState(_hangarJson(hangar, null)));
    }
  }

  /// Meta imzası değiştiyse yayınla ve imzayı kaydet.
  void _metaDegistiyseYayinla(ServerShip ship, Session session) {
    final meta = _metaOf(ship);
    final imza = _metaImzasi(meta);
    if (imza == ship.metaImzasi) return;
    ship.metaImzasi = imza;
    _broadcast(meta, harita: session.harita);
  }

  /// Meta'nın "değişti mi" sorusuna cevap veren kısa imzası: ad dışında
  /// istemcinin çizdiği her şey.
  static String _metaImzasi(ServerEntityMeta meta) =>
      '${meta.lasers}|${meta.govde}|${meta.droidler.join(',')}'
      '|${meta.droidModelleri.join(',')}|${meta.formasyon}';

  /// [DEV_RICH] listesindeki hesabın bakiyesini tabana çeker.
  ///
  /// Sessizce çalışmıyor: her uygulama loga düşüyor, çünkü ekonomiyi elle
  /// değiştiren bir şeyin görünmez olması kabul edilemez. Bakiye zaten
  /// tabanın üstündeyse hiçbir şey yapılmıyor — kazanılan para silinmemeli.
  void _applyDevRiches(String username, String accountId) {
    // Karşılaştırma BÜYÜK/KÜÇÜK harf duyarsız: `DEV_RICH=cinar` yazıp
    // hesabın "CINAR" olması, hiçbir hata vermeyen ve sebebi görünmeyen bir
    // sessizlik üretirdi.
    final wanted = username.toLowerCase();
    if (!devRichAccounts.any((n) => n.toLowerCase() == wanted)) return;
    if (!_grantRiches(accountId)) return;
    final hangar = hangars.of(accountId);
    stdout.writeln(
      '⚠ DEV_RICH: $username bakiyesi tabana çekildi '
      '(${hangar.credits} kredi · ${hangar.premium} $premiumName)',
    );
  }

  /// Bakiyeyi tabana çeker — İSİM KONTROLÜ YOK.
  ///
  /// [_applyDevRiches] ve [_applyDevFull] ikisi de buna dayanıyor. Ayrılmasının
  /// sebebi bir hataydı: tam donanım, parayı isim kontrollü yoldan istiyordu
  /// ve `DEV_FULL` listesinde olup `DEV_RICH` listesinde olmayan bir hesap
  /// beş parasız kalıyordu — bütün alımlar sessizce başarısız oluyordu.
  ///
  /// `false` dönerse zaten yeterliydi ve hiçbir hareket yazılmadı.
  bool _grantRiches(String accountId) {
    final hangar = hangars.of(accountId);
    // MALZEME de veriliyor — kredi gibi, ve aynı gerekçeyle.
    //
    // Malzeme kapısı (alan 07) geldiğinde tam donanımlı hesap yuvalarını
    // dolduramaz oldu: kredisi yetiyordu, malzemesi yoktu. Kapının kendisi
    // doğru; geliştirme hesabının o kapıyı beklemesi yanlış — onun işi
    // merdivenin TEPESİNİ sınamak.
    //
    // Miktar türetiliyor: en pahalı yükseltme kaç malzeme istiyorsa, her
    // rankta o kadarının yuva sayısı katı. Merdiven uzasa da birlikte büyür.
    for (final tier in ItemTier.values) {
      var enCok = 0;
      for (var l = 0; l < ItemLevels.max; l++) {
        enCok += Yukseltme.malzemeMaliyeti(l, tier);
      }
      hangar.malzemeEkle(
        Malzeme.forRank(tier),
        enCok * HullClass.all.last.totalSlots,
      );
    }
    if (hangar.credits >= devRichCredits && hangar.premium >= devRichPremium) {
      return false;
    }
    // Defter üzerinden: geliştirme kolaylığı da bir para hareketi ve kayıtsız
    // kalmamalı. Üretim defterinde `devGrant` görmek, bir yapılandırma
    // hatasının kanıtı olur.
    final tx = _tx(accountId);
    hangar
      ..adjust(
        Currency.credit,
        devRichCredits - hangar.credits,
        reason: LedgerReason.devGrant,
        txId: tx.id,
        atMillis: tx.atMillis,
      )
      ..adjust(
        Currency.premium,
        devRichPremium - hangar.premium,
        reason: LedgerReason.devGrant,
        txId: '${tx.id}:p',
        atMillis: tx.atMillis,
      );
    _collectLedger(hangar);
    _dirtyHangars.add(accountId);
    return true;
  }

  /// GELİŞTİRME kolaylığı: bu hesap TAM donanımlı başlar.
  ///
  /// [devRichAccounts] ile aynı gerekçe ve aynı kurulum yolu — isim listesi
  /// kodda DEĞİL ortam değişkeninde, varsayılan boş, açıkken sunucu bağırıyor.
  /// Bir `if (username == ...)` satırı, üretime derlenen bir arka kapıdır.
  ///
  /// **Kurallardan geçiyor.** Hangar elle doldurulmuyor; her gemi, her eşya ve
  /// her yükseltme [HangarRules] üzerinden alınıyor. Böylece "tam donanımlı"
  /// hesap, oyuncunun ULAŞABİLECEĞİ bir durum oluyor — elle kurulsaydı testin
  /// hiç görmediği, oyunda üretilemeyen bir hangar doğardı.
  final Set<String> devFullAccounts;

  void _applyDevFull(String username, String accountId) {
    final wanted = username.toLowerCase();
    if (!devFullAccounts.any((n) => n.toLowerCase() == wanted)) return;
    final hangar = hangars.of(accountId);
    if (_devFullTamam(hangar)) return;

    // Para önce: satın almalar kuraldan geçiyor, yani bakiye gerçekten
    // yetmeli. İsim kontrollü yoldan DEĞİL — `DEV_FULL` listesinde olup
    // `DEV_RICH` listesinde olmayan hesap beş parasız kalırdı.
    _grantRiches(accountId);

    var adim = 0;
    TxContext sonraki() => _tx('$accountId-full-${adim++}');

    // ── SATIŞTAKİ bütün gövdeler, en iyisi seçili ──
    //
    // "Bütün gövdeler" değil: merdivenden türetilen üst kademeler tanımlı ama
    // satışta değil (`Catalogue.hullPrice` null). Ayrıcalık kuralı esnetmiyor,
    // ona uyuyor — ulaşılamayan bir gövdeyi vermek, oyunda üretilemeyen bir
    // hangar yaratırdı.
    for (final hull in _satistakiGovdeler) {
      if (!hangar.owns(hull.id)) {
        HangarRules.buyHull(hangar, hull.id, sonraki());
      }
    }
    final enIyiGovde = _enIyiGovde;
    hangar.selectHull(enIyiGovde.id);

    // ── her yuvaya en iyi eşya, tavan seviyede ──
    for (final tip in SlotType.values) {
      final spec = _enIyiEsya(tip);
      if (spec == null) continue;
      for (var i = 0; i < enIyiGovde.slotCount(tip); i++) {
        final (item, hata) = HangarRules.buyItem(
          hangar,
          spec.id,
          '${accountId}_full_${tip.name}_$i',
          sonraki(),
        );
        if (item == null || hata != null) continue;
        HangarRules.equip(hangar, SlotRef(tip, i), item.instanceId);
        while (hangar.itemOf(item.instanceId)!.level < ItemLevels.max) {
          if (HangarRules.upgrade(hangar, item.instanceId, sonraki()) != null) {
            break;
          }
        }
      }
    }

    // ── tam filo, tavan seviyede ──
    final droid = _enIyiEsya(SlotType.droid);
    if (droid != null) {
      for (var i = 0; i < TasarimGirdileri.droidFiloTavani; i++) {
        final (item, hata) = HangarRules.buyItem(
          hangar,
          droid.id,
          '${accountId}_full_filo_$i',
          sonraki(),
        );
        if (item == null || hata != null) continue;
        HangarRules.filoyaAl(hangar, item.instanceId);
        while (hangar.itemOf(item.instanceId)!.level < ItemLevels.max) {
          if (HangarRules.upgrade(hangar, item.instanceId, sonraki()) != null) {
            break;
          }
        }
      }
    }

    _collectLedger(hangar);
    _dirtyHangars.add(accountId);
    final stats = _statsFor(accountId);
    stdout.writeln(
      '⚠ DEV_FULL: $username tam donatıldı — ${enIyiGovde.name}, '
      'savaş puanı ${CombatGlossary.battleRating(stats).round()}',
    );
  }

  /// Zaten tam donanımlı mı — her girişte yeniden kurmamak için.
  bool _devFullTamam(Hangar hangar) {
    final hull = HullClass.byId(hangar.activeHullId);
    if (hull == null) return false;
    if (hull.id != _enIyiGovde.id) return false;
    if (_enIyiEsya(SlotType.droid) != null &&
        hangar.filo.length < TasarimGirdileri.droidFiloTavani) {
      return false;
    }
    for (final tip in SlotType.values) {
      if (_enIyiEsya(tip) == null) continue;
      for (var i = 0; i < hull.slotCount(tip); i++) {
        final takili = hangar.activeLoadout.slots[SlotRef(tip, i).id];
        final item = takili == null ? null : hangar.itemOf(takili);
        if (item == null || item.level < ItemLevels.max) return false;
      }
    }
    return true;
  }

  /// Mağazada duran gövdeler — türetilen kademeler satışta DEĞİL.
  static List<HullClass> get _satistakiGovdeler => [
    for (final h in HullClass.all)
      if (Catalogue.hullPrice(h) != null) h,
  ];

  /// Satıştaki en iyi gövde.
  static HullClass get _enIyiGovde =>
      _satistakiGovdeler.isEmpty ? HullClass.starter : _satistakiGovdeler.last;

  /// [tip] yuvasının SATIN ALINABİLİR en iyi eşyası.
  static ItemSpec? _enIyiEsya(SlotType tip) {
    ItemSpec? enIyi;
    for (final spec in Catalogue.items) {
      if (spec.slot != tip) continue;
      if (enIyi == null || spec.tier.index > enIyi.tier.index) enIyi = spec;
    }
    return enIyi;
  }

  /// Bu tikte imha edilen alienlerin ödülünü öldürene yazar.
  ///
  /// **Kaynak `zone.shots`.** Zone'un ödül diye bir kavramı yok ve olmamalı:
  /// orası simülasyon, burası hesap. Atış olayı zaten "kim, kimi, öldürdü mü"
  /// taşıyor — ekonomiyi ondan türetmek, simülasyona ikinci bir sorumluluk
  /// eklemeden aynı sonucu veriyor.
  ///
  /// **Oyuncu oyuncuyu öldürünce ödül YOK.** İki hesap arasında para akıtmak,
  /// iki hesabı olan birinin kendi kendini öldürerek para basması demek. PvP
  /// ödülü ancak kaybedenden bir şey EKSİLTEREK dengelenebilir ve o ayrı bir
  /// tasarım.
  /// Bir imhanın ganimetini KATILANLARA dağıt.
  ///
  /// Her oyuncu KENDİ zarını atıyor ve şansı hasar payıyla ölçekli — sahiplik
  /// eşiği yok, çünkü gerekmiyor (bkz. [GanimetCekilisi.cek]). Beklenen toplam
  /// eşya, grubun kaç kişi olduğundan bağımsız.
  ///
  /// **Rank İÇERİĞİN bandından.** Yaratığın öldüğü yerdeki bant ne diyorsa
  /// düşen eşya o rankta: haritanın derinine giren daha iyi eşya buluyor ve
  /// bu, bant ölçeklemesinin oyuncuya görünen tek karşılığı.
  void _ganimetDagit(
    Zone zone,
    int alienId,
    AlienSimState alien,
    ThreatTable table,
  ) {
    final kimlik = YaratikKadrosu.byKind(alien.stats.kind);
    if (kimlik == null) return;
    final rank = zone.bolge.rankOf(zone.bandFor(alien.position));

    for (final entry in table.paylar.entries) {
      final session = _sessions[entry.key];
      final account = session?.account;
      if (session == null || account == null) continue;
      final hangar = hangars.of(account.id);

      final dusen = GanimetCekilisi.cek(
        sinif: kimlik.sinif,
        hasarPayi: entry.value,
        rank: rank,
        prd: hangar.ganimetPrd,
        zar: _ganimetZari,
        // Kimlik ÇAKIŞMASIZ olmak zorunda: hesap + tik + alien + deneme.
        // Tik ve alien birlikte tekil, hesap oyuncular arasında ayırıyor.
        kimlikUret: (d) => 'g${account.id}_${_tick}_${alienId}_$d',
      );
      if (dusen.bos) continue;

      for (final g in dusen.esyalar) {
        hangar.addItem(
          ItemInstance(instanceId: g.instanceId, specId: g.specId),
        );
      }
      if (dusen.malzeme > 0) {
        // Malzemenin rankı BANDIN rankı — düşen eşyanınki gibi. Derine giren
        // hem daha iyi eşya hem daha değerli malzeme buluyor.
        hangar.malzemeEkle(
          Malzeme.forRank(
            ItemTier.values[rank.clamp(0, ItemTier.values.length - 1)],
          ),
          dusen.malzeme,
        );
      }
      _dirtyHangars.add(account.id);
      // Ne düştüğü AYRICA söyleniyor: hangar durumu envanterin doğrusu ama
      // "ne değişti" sorusuna cevap vermiyor ve HUD onu okuyamıyor. Ganimet
      // durumdan ÖNCE gidiyor; durumun gelmesini bekleyen bir taraf, düşeni
      // de görmüş oluyor. KARAR 14.1 s1
      session.send(
        ServerGanimet(
          sourceId: alienId,
          esyalar: [for (final g in dusen.esyalar) g.specId],
          malzemeRank: rank.clamp(0, ItemTier.values.length - 1),
          malzeme: dusen.malzeme,
        ),
      );
      // Hangar ekranı açık olmayabilir; oyuncu düşeni ANINDA görmeli.
      session.send(ServerHangarState(_hangarJson(hangar, null)));
    }
  }

  /// Ganimet zarı — TEK bir kaynak.
  ///
  /// Oyuncu başına ayrı zar tutmak, tohumu hesapla birlikte saklamak demekti
  /// ve hiçbir şey kazandırmazdı: belirlenimcilik PRD sayacında ve kalite
  /// karmasında zaten korunuyor, ikisi de kalıcı.
  final math.Random _ganimetZari = math.Random();

  void _grantKillRewards(Zone zone) {
    for (final shot in zone.shots) {
      if (!shot.killed) continue;
      if (!Protocol.isAlienId(shot.targetId)) continue;
      if (Protocol.isAlienId(shot.shooterId)) continue;

      final alien = zone.aliens[shot.targetId];
      if (alien == null) continue;

      // Ödül SON VURUŞA değil HASAR PAYINA göre.
      //
      // Önceki hâlde hasarın %99'unu veren değil, son yaylımı atan alıyordu —
      // "kill stealing" diye bilinen ve iki oyuncu aynı aliene girdiği gün
      // hissedilen adaletsizlik. Pay, alienin tehdit tablosundan geliyor:
      // kimi kovalayacağı ve ödülün kime gideceği tek sayıdan türüyor.
      //
      // Toplam KORUNUYOR (`ThreatTable.split`): yuvarlama ekonomiye para
      // basmıyor ya da sızdırmıyor.
      final table = zone.threatOf(shot.targetId);

      // GANİMET — kredinin YANINDA, ondan ayrı bir musluk.
      //
      // Alan 14'ün ayrımı burada da korunuyor: kredi yaratığın ödülü olarak
      // doğrudan geliyor, eşya ise çekilişle. Üç ayrı ritim bilinçli — biri
      // her öldürmede, öteki seyrek.
      _ganimetDagit(zone, shot.targetId, alien, table);

      final credits = table.split(alien.stats.creditReward);
      final premium = table.split(alien.stats.premiumReward);
      if (credits.isEmpty && premium.isEmpty) continue;

      for (final shipId in {...credits.keys, ...premium.keys}) {
        final session = _sessions[shipId];
        final account = session?.account;
        if (session == null || account == null) continue;

        final hangar = hangars.of(account.id);

        // FARM SINIRI — azalan getiri (bkz. [Fatigue]).
        //
        // Sınırsız musluk iki şeyi birden bozuyordu: enflasyon ve gerçek para.
        // Basılan NOVA, satılan NOVA ile rekabet ediyor; kıt parayı satacaksan
        // basma hızını bilmek zorundasın. Kesme değil eğri: uzun oynayan
        // cezalandırılmıyor, yalnız marjinal kazancı düşüyor.
        final now = DateTime.now().millisecondsSinceEpoch;
        // Eşik İÇERİĞİN bandıyla ölçekleniyor: sabit bir eşik, üst
        // kademelerde eşik olmaktan çıkıp duvar olurdu.
        //
        // Buranın notu "harita kademesi geldiğinde (alan 11) ölçek oradan
        // gelecek, asıl doğrusu içeriğin kademesi" diyordu ve gövde kademesini
        // vekil olarak kullanıyordu. Alan 11 geldi: oyuncunun hangi haritada
        // olduğu artık biliniyor, ve o haritanın bölgesi kendi rank aralığını
        // veriyor. Vekile gerek kalmadı.
        final hucre = hucreOf(session);
        final scale = hangar.fatigue.multiplierAt(
          now,
          rank: hucre.bolge.ilkRank,
        );
        final creditShare = ((credits[shipId] ?? 0) * scale).round();
        final premiumShare = ((premium[shipId] ?? 0) * scale).round();
        if (creditShare <= 0 && premiumShare <= 0) continue;
        hangar.fatigue.record(creditShare, now);
        // XP = yorgunluk sonrası öldürme kredisi; seviye buradan (10.1).
        hangar.xpEkle(creditShare);

        final tx = _tx(account.id);
        hangar
          ..earn(
            Currency.credit,
            creditShare,
            reason: LedgerReason.kill,
            txId: tx.id,
            atMillis: tx.atMillis,
            detail: alien.stats.name,
          )
          ..earn(
            Currency.premium,
            premiumShare,
            reason: LedgerReason.kill,
            txId: '${tx.id}:p',
            atMillis: tx.atMillis,
            detail: alien.stats.name,
          );
        _collectLedger(hangar);

        // Diske YAZILMIYOR, işaretleniyor.
        //
        // İmha başına bir dosya yazması tik yolunda I/O demek: 240 oyuncuda
        // saniyede onlarca `flush`. Kirli hangarlar beş saniyede bir toplu
        // yazılıyor ve oturum kapanırken de. Bedeli açık: sunucu çökerse en
        // fazla beş saniyelik ödül kaybolur.
        _dirtyHangars.add(account.id);

        session.send(
          ServerReward(
            sourceId: shot.targetId,
            credits: creditShare,
            premium: premiumShare,
            balanceCredits: hangar.credits,
            balancePremium: hangar.premium,
          ),
        );
      }
      // Ödül dağıtıldı: tablo kapanıyor. Kapatmamak, aynı alienin bir sonraki
      // imhasında eski katkıların da ödenmesi demekti.
      table.clear();
    }
  }

  /// Ölen oyunculardan tamir bedelini keser.
  ///
  /// **Ekonominin tek tekrarlayan sinki.** Üç sink vardı ve üçü de tek
  /// seferlik (eşya, gemi, yükseltme); musluk ise sınırsız. Oyuncu her şeye
  /// sahip olduktan sonra kredi amaçsız birikiyordu — 云风'un deyişiyle para,
  /// para olmaktan çıkıp farm edilen bir kaynağa dönüyordu.
  ///
  /// Aynı hamle savaşa ağırlık da veriyor: ölüm bedava olduğu sürece
  /// alienlerin yarattığı riskin hiçbir karşılığı yoktu.
  ///
  /// **Bakiye yetmiyorsa OLAN kadarı kesiliyor.** Alımdaki "ya hep ya hiç"
  /// kuralının tersi ve sebebi farklı: orada karşılığında bir mal var ve
  /// kısmi ödeme malı vermeden parayı yemek olurdu. Burada karşılık yok, bu
  /// bir vergi — ödeyemeyeni borçlu bırakmak yerine sıfıra indirmek hem
  /// basit hem affedici. Kesilen gerçek miktar deftere yazılıyor.
  void _chargeRepairs(Zone zone) {
    for (final shipId in zone.deaths) {
      final session = _sessions[shipId];
      final account = session?.account;
      if (session == null || account == null) continue;

      final hangar = hangars.of(account.id);
      final hull = zone.ships[shipId]?.state.stats.name;
      final cost = HullClass.all
          .firstWhere((h) => h.name == hull, orElse: () => HullClass.starter)
          .repairCost;
      final charged = cost < hangar.credits ? cost : hangar.credits;
      if (charged <= 0) continue;

      final tx = _tx(account.id);
      hangar.spend(
        Currency.credit,
        charged,
        reason: LedgerReason.repair,
        txId: tx.id,
        atMillis: tx.atMillis,
        detail: hull,
      );
      _collectLedger(hangar);
      _dirtyHangars.add(account.id);

      // Ödül mesajının aynısı, eksi yönde: oyuncu ne kaybettiğini görmeli.
      session.send(
        ServerReward(
          sourceId: shipId,
          credits: -charged,
          premium: 0,
          balanceCredits: hangar.credits,
          balancePremium: hangar.premium,
        ),
      );
    }
  }

  /// Ölen oyuncunun FİLOSUNU aşındırır (05.10).
  ///
  /// Tamir bedelinden ayrı bir geçiş ve ayrı olması şart: bedel bakiyeden,
  /// aşınma envanterden; biri yetersiz bakiyede atlanıyor, öteki hiçbir
  /// koşulda atlanmıyor. Aynı döngüye sıkıştırmak, parası bitmiş oyuncunun
  /// droidlerini ölümsüz yapardı.
  ///
  /// Kaynak yine [Zone.deaths]: ölüm anı bir kez okunuyor, sayaç olayla
  /// iniyor.
  void _droidleriAsindir(Zone zone) {
    for (final shipId in zone.deaths) {
      final session = _sessions[shipId];
      final account = session?.account;
      if (session == null || account == null) continue;

      final hangar = hangars.of(account.id);
      if (hangar.filo.isEmpty) continue;
      final yokOlanlar = hangar.filoyuAsindir();
      _dirtyHangars.add(account.id);
      // Droid yok olduysa savaşan gemi de değişti: filo küçüldü, grup
      // yeniden çözülmeli. Bir sonraki hangar ziyaretinde değil ŞİMDİ.
      if (yokOlanlar.isNotEmpty) _applyLoadout(session);
      // Sayaç oyuncunun ekranında: dayanıklılık hangar durumunda taşınıyor,
      // ayrı bir mesaj açmaya gerek yok.
      session.send(ServerHangarState(_hangarJson(hangar, null)));
    }
  }

  /// Ödül yazılmış ama diske düşmemiş hesaplar.
  final Set<String> _dirtyHangars = {};

  /// Kirli hangarları diske yazar. Rapor saatiyle aynı ritimde çağrılıyor.
  Future<void> _flushDirtyHangars() async {
    if (_dirtyHangars.isEmpty) return;
    final pending = _dirtyHangars.toList();
    _dirtyHangars.clear();
    for (final accountId in pending) {
      await _saveHangar(accountId);
    }
  }

  /// Defteri diske yazar; YAZAMAZSA sunucuyu düşürmez.
  ///
  /// Yazılamayan kayıtlar kuyrukta kalıyor ve sonraki turda yeniden
  /// deneniyor — para kaydı kaybolmaz.
  Future<void> _flushLedger() async {
    try {
      await ledger.flush();
    } on Object catch (error) {
      stdout.writeln('⚠ defter yazılamadı: $error');
    }
  }

  /// Hangarı diske yazar; YAZAMAZSA sunucuyu düşürmez.
  ///
  /// Bu çağrı tik yolundan ve oturum kapanışından geliyor, ikisi de
  /// `unawaited`. Yakalanmamış bir dosya hatası orada "işlenmemiş asenkron
  /// hata" olur ve süreci düşürür — yani diskin dolması ya da dizinin
  /// silinmesi, oyunun kendisini durdurur. Kayıp bir yazımın bedeli birkaç
  /// saniyelik ödül; kapanan bir sunucununki herkes.
  Future<void> _saveHangar(String accountId) async {
    try {
      await hangars.save(hangars.of(accountId));
    } on Object catch (error) {
      stdout.writeln('⚠ hangar yazılamadı ($accountId): $error');
    }
  }

  /// Bir geminin meta kaydı — ad, namlu sayısı ve gövde kademesi.
  ///
  /// Tek yerden üretiliyor: katılış üç ayrı yerde meta yolluyor ve birinde
  /// namlu sayısını unutmak, o gemiyi bazı istemcilerde silahsız çizerdi.
  /// Kademe de aynı kanaldan ve aynı sebeple: unutulduğu yerde o gemi
  /// başkasının gemisi gibi görünürdü.
  ServerEntityMeta _metaOf(ServerShip ship) => ServerEntityMeta(
    ship.id,
    ship.name,
    ship.state.stats.equippedLasers,
    ship.state.stats.govdeKademesi,
    // Droid filosu ve formasyonu da aynı kanaldan: ikisi de hangarda
    // değişiyor, snapshot'ta yeri yok.
    droidler: [for (final d in _droidler(ship.accountId)) d.$1],
    droidModelleri: [for (final d in _droidler(ship.accountId)) d.$2],
    formasyon: Formasyon.hepsi.indexOf(hangars.of(ship.accountId).formasyon),
  );

  int _instanceCounter = 0;

  String _newInstanceId() =>
      'i${DateTime.now().microsecondsSinceEpoch}_${_instanceCounter++}';

  /// GEÇİTTEN GEÇ — oyuncunun üstünde durduğu kapıdan öteki haritaya.
  ///
  /// Hangi geçit olduğunu istemci SÖYLEMİYOR, sunucu geminin konumundan
  /// buluyor. İstemci adlandırsaydı üstünde durmadığı bir geçidi adlandırarak
  /// tek çerçevede ışınlanabilir ve BR kapısını atlayabilirdi.
  ///
  /// Sıra önemli: hedef doluluk kontrolü ÖNCE yapılıyor. Önce kaynaktan
  /// çıkıp sonra hedefin dolu olduğunu görmek, oyuncuyu hiçbir haritada
  /// olmayan bir duruma düşürürdü.
  void _onGecit(Session session) {
    final ship = session.ship;
    final account = session.account;
    if (ship == null || account == null) return;

    final kaynakKayit = defter[session.harita];
    final kaynak = kaynakKayit.hucre;
    if (kaynak == null) return;

    // ── üstünde durduğu geçit ──
    //
    // Menzil istemcininkinden GENİŞ ve bu bir gevşeklik değil, bir düzeltme.
    // İstemci tahmin ediyor: kendi gemisini sunucunun bildiği yerin ÖNÜNDE
    // çiziyor ve önde olabileceği mesafenin üst sınırı, onaylanmamış girdi
    // penceresi. Pay olmadan sınıra yakın her deneme "geçit menzilinde
    // değilsin" ile dönüyordu — oyuncu kapının içinde dururken.
    //
    // Kopyalanamaz: pay 64 birim, harita 11.288. Uzaktan ışınlanma hâlâ
    // imkânsız; düzeltilen şey sınırın kendisi değil, sınırın iki uçta
    // farklı yerde olması.
    final menzil = GecitAgi.yaricap + _tahminPayi;
    final yaricapKare = menzil * menzil;
    Gecit? gecit;
    for (final g in GecitAgi.gecitleriFor(session.harita)) {
      if (g.konum.distanceSquaredTo(ship.state.position) <= yaricapKare) {
        gecit = g;
        break;
      }
    }
    if (gecit == null) {
      session.send(ServerGecitRed(GecitKodu.menzilDisi.kod));
      return;
    }

    // ── kapı ──
    //
    // BR sunucuda hesaplanıyor ve istemciye de aynı sayı gidiyor (bkz.
    // `_hangarJson`): kapıyı açan taraf ile oyuncuya "yetmiyor" diyen taraf
    // ayrı sayılar kullansaydı, görünen bir kapıdan geçilemezdi.
    final br = CombatGlossary.battleRating(_statsFor(account.id));
    if (!gecit.acik(br)) {
      session.send(
        ServerGecitRed(GecitKodu.brYetmiyor.yaz([gecit.esik.round()])),
      );
      return;
    }
    // İkincil kapı: SEVİYE (11.4). Para savaş puanını hızlandırır, seviyeyi
    // değil; hangisinin kapalı olduğu oyuncuya ayrı ayrı söyleniyor.
    final seviye = hangars.of(account.id).seviye;
    if (!gecit.acik(br, seviye: seviye)) {
      session.send(
        ServerGecitRed(GecitKodu.seviyeYetmiyor.yaz([gecit.seviyeEsigi])),
      );
      return;
    }

    final hedefKayit = defter[gecit.hedef];
    if (hedefKayit.hucre?.isFull ?? false) {
      session.send(ServerGecitRed(GecitKodu.haritaDolu.kod));
      return;
    }

    // ── taşı ──
    final durum = ship.state;
    kaynak.leave(ship.id);
    _sessions.remove(ship.id);
    _broadcast(ServerEntityGone(ship.id), harita: session.harita);

    final hedef = hedefKayit.ac(_tick);
    final yeni = hedef.join(
      ship.name,
      accountId: account.id,
      stats: _statsFor(account.id),
      // Girişin KARŞI kenarı — geçidin tek kuralı.
      konum: gecit.cikisKonumu,
      // Sağlık taşınıyor: geçit bir onarım istasyonu değil.
      saglik: durum.hull,
      kalkan: durum.shield,
    );
    if (yeni == null) {
      // Buraya düşmek kapasite kontrolüne rağmen kimlik uzayının dolması
      // demek. Oyuncuyu kaynağa geri koymak, onu hiçbir yerde olmayan bir
      // duruma düşürmekten iyi.
      final geri = kaynak.join(
        ship.name,
        accountId: account.id,
        stats: _statsFor(account.id),
        konum: durum.position,
        saglik: durum.hull,
        kalkan: durum.shield,
      );
      if (geri == null) {
        unawaited(session.close('geçiş başarısız'));
        return;
      }
      session.ship = geri;
      _sessions[geri.id] = session;
      session.send(ServerGecitRed(GecitKodu.basarisiz.kod));
      return;
    }

    session.ship = yeni;
    // SIRA NUMARASI GEMİNİN DEĞİL OTURUMUN ÖZELLİĞİ — taşınıyor.
    //
    // Yeni gemi `acknowledgedSeq = 0` ile doğuyordu ve geçiş anında YOLDA
    // olan girdiler geçişten sonra varıyordu. `enqueue` yalnız "sıra
    // ilerlemiş mi" diye bakıyor: 900 taşıyan eski bir girdi sıfırdan
    // büyük olduğu için kabul ediliyor ve sayacı 900'e sıçratıyordu.
    // Ondan sonra istemcinin sıfırdan sayan taze girdileri hep o sayının
    // altında kalıyor ve SESSİZCE atılıyordu — 30 Hz'de sayacın geri
    // tırmanması yarım dakika, ve o yarım dakika boyunca gemi hiçbir
    // komuta cevap vermiyor. Oyuncunun gördüğü şey ağ sorunu gibi:
    // "portaldan geçtim, gemimi hareket ettiremiyorum".
    //
    // Sayaç taşınınca yoldaki eski girdi kendiliğinden reddediliyor
    // (`seq <= acknowledgedSeq`) ve istemci kaldığı yerden devam ediyor.
    // TCP'nin yol değişiminde sıra numarasını sürdürmesiyle aynı fikir:
    // taşıyıcı değişti diye sayaç sıfırlanmaz.
    //
    // İstemci tarafında aynı taşıma `NetClient`'ta yapılıyor; ikisinden
    // biri eksik kalırsa oyuncu ya sağır kalır ya yolda kalan bir girdiyi
    // yer.
    yeni.acknowledgedSeq = ship.acknowledgedSeq;
    // Yeni gemi yeni nesne: mermi seçimi hangardan yeniden okunuyor, yoksa
    // geçitten sonra MR-1'e düşerdi.
    _mermiyiUygula(yeni, yeni.accountId);

    session.harita = gecit.hedef;
    _sessions[yeni.id] = session;
    // Nerede olduğu KALICI: çıkış yapan oyuncu başa dönmemeli. Kapı girişte
    // yeniden sınanıyor, yani buraya yazmak bir hak değil bir kayıt.
    hangars.of(account.id).haritaId = gecit.hedef.id;
    _dirtyHangars.add(account.id);
    // Temel gitti: yeni haritada istemcinin elinde hiçbir entity'nin geçmişi
    // yok, bir sonraki snapshot TAM gitmeli.
    session.needsFullSnapshot = true;

    session.send(
      ServerHarita(
        entityId: yeni.id,
        bolgeKademe: gecit.hedef.bolge.kademe,
        haritaTipi: gecit.hedef.tip.index,
        worldWidth: hedef.world.width,
        worldHeight: hedef.world.height,
        worldMargin: hedef.world.margin,
        // OTORİTER KONUM: istemci geçidin çıkışını kendisi hesaplamasın.
        // Kural (`gecit.cikisKonumu`) burada uygulanıyor; ikinci bir kopya
        // ilk ayrışmada iki geminin iki ayrı yerde durması demekti.
        x: yeni.state.position.x,
        y: yeni.state.position.y,
      ),
    );
    // KENDİ meta'sı da gidiyor ve bu atlanamaz.
    //
    // El sıkışmada olduğu gibi: `ServerEntityMeta` adın yanında NAMLU SAYISINI
    // taşıyor ve istemci mermileri ondan çiziyor. Geçişte kendi kaydını
    // atlayınca gemi ateş ediyor ama hiçbir ışın görünmüyordu — hangarda lazer
    // takıp çıkarmak düzeltiyordu, çünkü o işlem meta'yı yeniden yolluyor.
    for (final other in hedef.ships.values) {
      session.send(_metaOf(other));
    }
    final meta = _metaOf(yeni);
    yeni.metaImzasi = _metaImzasi(meta);
    _broadcast(meta, harita: session.harita, except: yeni.id);

    // Kaynak boşaldıysa simülasyon durur — base kalır.
    kaynakKayit.kapat();

    stdout.writeln(
      '→ ${ship.name} #${yeni.id} · ${gecit.kaynak.ad} ⇒ ${gecit.hedef.ad}',
    );
  }

  /// Hangar durumu + sunucunun hesapladığı türevler.
  ///
  /// Fiyatlar ve etkin statlar da gidiyor: istemci onları kendi hesaplasaydı
  /// iki uç ayrışabilirdi ve oyuncu "yazan fiyat bu değildi" derdi.
  Map<String, Object?> _hangarJson(Hangar hangar, HangarError? error) {
    final stats = LoadoutResolver.resolve(
      hangar.activeLoadout,
      hangar.inventory,
      Catalogue.byId,
    );
    final br = CombatGlossary.battleRating(stats);
    final unvan = CombatGlossary.unvanIndeksi(br);
    return {
      ...hangar.toJson(),
      // Metin değil KOD: sunucunun bir dili yok, cümleyi istemci kuruyor
      // (bkz. `KimlikKodu`). `HangarError.message` çekirdekte kalıyor —
      // tasarım belgelerinin ve sunucu günlüğünün kanonik Türkçesi.
      if (error != null) 'error': error.name,
      'effective': ServerHangarState.effectiveOf(stats),
      // Savaş puanı da SUNUCUDAN. İstemci `effective`'ten kendisi
      // hesaplayabilirdi ama o an iki BR olurdu: kapının açılıp açılmadığına
      // karar veren sunucununki, oyuncuya "yetmiyor" diyen istemcininki. İkisi
      // bir gün ayrışır ve oyuncu görebildiği bir kapıdan geçemez.
      'br': br,
      // Seviye ve unvan da sunucudan: ikisi de sunucunun sayaçlarından
      // türüyor (10.1, 10.4); istemci yalnız gösteriyor.
      'seviye': hangar.seviye,
      'unvan': unvan,
      'unvanAdi': Unvan.adi(unvan),
    };
  }

  /// Hata ayıklama komutu — yalnız [allowDebugCommands] açıkken.
  ///
  /// İşi otorite döngüsünü uçtan uca kanıtlamak: hasar İSTEMCİDE
  /// hesaplanmıyor, istemci yalnız niyet gönderiyor. Üretimde kapalı olması
  /// pazarlık konusu değil — `ONAR` ölü bir gemiyi tam sağlıkla geri getiriyor.
  void _onDebug(Session session, int kind) {
    if (!allowDebugCommands) {
      unawaited(session.close('hata ayıklama komutu kapalı'));
      return;
    }
    final ship = session.ship;
    if (ship == null) return;
    ship.state = switch (kind) {
      DebugCommandKind.damage => ShipSim.applyDamage(ship.state, 2600),
      DebugCommandKind.repair => ShipSim.repair(ship.state),
      _ => ship.state,
    };
  }

  /// [accountId]'nin donatımından çözülmüş gemi statları.
  ///
  /// Çözüm ORTAK pakette (`LoadoutResolver`): hangar ekranının gösterdiği
  /// sayıyla savaşta inen hasarın ayrışmaması için tek uygulama.
  ShipStats _statsFor(String accountId) {
    final hangar = hangars.of(accountId);
    return LoadoutResolver.resolve(
      hangar.activeLoadout,
      hangar.inventory,
      Catalogue.byId,
      // Filo ve formasyon hangar seviyesinde: donatımın değil oyuncunun
      // (04.10, 05.9); gemi değişince ikisi de kalıyor.
      filo: hangar.filo,
      // Droidin İÇİNDEKİLER de droid kapsamına yazıyor (05.4 s5): filo bir
      // taşıyıcı, gücü taşıdığından geliyor.
      droidDonanimi: hangar.droidDonanimi,
      formasyon: hangar.formasyon,
      // ArGe'nin kapsam yönlendirmesi σ'ya biniyor (05.7).
      argeAktarim: ArGe.aktarimDeltasi(hangar.argeDugumleri),
    );
  }

  /// Filodaki droidler, sırasıyla: (görsel kademe, model) (05.8).
  List<(int, int)> _droidler(String accountId) {
    final hangar = hangars.of(accountId);
    return [
      for (final (item, spec) in LoadoutResolver.filoEsyalari(
        hangar.filo,
        hangar.inventory,
        Catalogue.byId,
      ))
        (
          DroidSeviyesi.of(item.level),
          // Oyuncunun SEÇTİĞİ tasarım varsa o, yoksa droidin kendi
          // görünüşü (15.9).
          DroidModeli.ofVariant(item.tasarim ?? spec.variant).index,
        ),
    ];
  }

  Session? _sessionOfAccount(String accountId) {
    for (final session in _sessions.values) {
      if (session.account?.id == accountId) return session;
    }
    return null;
  }

  /// Oturum koptu.
  ///
  /// Gemi HEMEN silinmez, sahipsiz işaretlenir: oyuncu birkaç saniye içinde
  /// geri gelirse aynı gemiye döner. [immediate] yalnız gemiyi gerçekten
  /// bırakması gereken yerlerde (başka cihazdan giriş, zaman aşımı) verilir.
  void _drop(Session session, {bool immediate = false}) {
    final ship = session.ship;
    if (ship == null) return;

    // Kopan oyuncunun ödülü HEMEN diske. Toplu yazım beş saniyede bir
    // koşuyor ve tam o aralıkta kopan bir oturum, kazandığı krediyi
    // kaybederdi — oyuncunun en çok kızdığı kayıp türü.
    final accountId = session.account?.id;
    if (accountId != null && _dirtyHangars.remove(accountId)) {
      unawaited(_saveHangar(accountId));
    }
    // Defter de HEMEN: kopan oturumun para kaydı beş saniyelik tampon
    // penceresinde kaybolmamalı.
    unawaited(_flushLedger());

    session.ship = null;
    _sessions.remove(ship.id);

    if (immediate) {
      final kayit = defter[session.harita];
      kayit.hucre?.leave(ship.id);
      _broadcast(ServerEntityGone(ship.id), harita: session.harita);
      stdout.writeln(
        '- ${ship.name} #${ship.id} · ${kayit.hucre?.ships.length ?? 0} oyuncu',
      );
      // Son oyuncu çıktıysa simülasyon durur — base kalır.
      kayit.kapat();
      return;
    }

    defter[session.harita].hucre?.orphan(ship);
    stdout.writeln(
      '~ ${ship.name} #${ship.id} koptu · '
      '${Zone.orphanGraceTicks ~/ Protocol.tickRate} sn bekliyor',
    );
  }

  /// [harita]'daki oturumlara yayın.
  ///
  /// Harita ZORUNLU: haritasız bir yayın, altıncı bölgedeki bir ölümü
  /// başlangıç haritasındaki herkese duyurmak olurdu. İstemci o gemiyi hiç
  /// görmediği için mesaj sessizce yanlış bir duruma yol açardı — tanımadığı
  /// bir kimlik için "gitti" almak.
  void _broadcast(
    ServerMessage message, {
    required Harita harita,
    int? except,
  }) {
    for (final entry in _sessions.entries) {
      if (entry.key == except) continue;
      if (entry.value.harita != harita) continue;
      entry.value.send(message);
    }
  }

  /// Sabit adımlı saat.
  ///
  /// `Timer.periodic(33ms)` DEĞİL: Dart zamanlayıcıları erken ateşlemez ama
  /// geç ateşler, ve biriken gecikme simülasyonu yavaşlatırdı. Kısa aralıkla
  /// yoklayıp GERÇEK geçen süreyi biriktirmek, tik sayısını duvar saatine
  /// bağlar.
  void _startClock() {
    final elapsed = Stopwatch()..start();
    var lastMicros = 0;
    var accumulator = 0.0;

    _clock = Timer.periodic(const Duration(milliseconds: 4), (_) {
      final now = elapsed.elapsedMicroseconds;
      var delta = (now - lastMicros) / 1e6;
      lastMicros = now;

      // Ölüm sarmalı koruması: süreç bir saniye askıda kalırsa 30 tiki tek
      // karede koşmak yerine zamanı DÜŞÜR. Simülasyon geride kalır, ama
      // sunucu ayakta kalır.
      if (delta > 0.25) delta = 0.25;
      accumulator += delta;

      while (accumulator >= ShipSim.fixedDt) {
        // Bu tik ne kadar GEÇ başlıyor: biriktiricide bir tik payından
        // fazlası varsa, fazlası gecikmedir.
        final lag = accumulator - ShipSim.fixedDt;
        _tickLag.add((lag * 1e6).round());
        accumulator -= ShipSim.fixedDt;
        _tickOnce();
      }
    });

    _reportClock = Timer.periodic(const Duration(seconds: 5), (_) {
      _report();
      unawaited(_flushDirtyHangars());
      unawaited(_flushLedger());
      // Ölü belirteçleri süpür. Bellekte tutulan oturum haritası, sunucu
      // haftalarca ayakta kaldığında giriş sayısı kadar büyürdü.
      accounts.sweepExpiredTokens();
    });
  }

  void _tickOnce() {
    final t0 = _uptime.elapsedMicroseconds;

    // Saat SUNUCUNUN, bölgelerin değil: tembel açılan bir hücre buradan
    // tohumlanıyor ve hepsi birlikte adım atıyor.
    _tick++;

    // `toList()`: döngünün içinde hücre kapanabiliyor ve canlılar listesi
    // altımızdan değişirdi.
    for (final kayit in defter.canlilar.toList()) {
      final hucre = kayit.hucre!;
      hucre.step();

      // BOSS RANDEVUSU. Sayaç `HaritaKaydi`'nda ve hücre ölse de yaşıyor:
      // iki saat kimsenin girmediği bir haritaya giren oyuncu, bekleyen
      // boss'u buluyor.
      //
      // Bu üç satır bir süre YOKTU. Sayaç, aralık, "hak etti mi" sorusu,
      // hepsi yazılmış ve test edilmişti — ama tüketen taraf hiç yazılmadı,
      // ve `bossBekliyor` yalnız testlerden çağrılıyordu. Sekiz boss
      // tasarlanmış, hiçbiri haritaya çıkmamıştı.
      if (kayit.bossBekliyor(_tick) && hucre.bossDogur()) {
        kayit.bossDogdu(_tick);
        stdout.writeln('☠ ${hucre.bossKimligi!.ad} doğdu · ${kayit.harita.ad}');
      }

      // Bekleme süresi dolan sahipsiz gemiler gerçekten gider.
      for (final ship in hucre.expiredOrphans()) {
        hucre.leave(ship.id);
        _broadcast(ServerEntityGone(ship.id), harita: kayit.harita);
        stdout.writeln('- ${ship.name} #${ship.id} (süre doldu)');
      }

      // Girdisi kesilen oturum düşürülür — ama gemi SİLİNMEZ, sahipsiz kalır.
      //
      // Eskiden burada `immediate: true` vardı ve bekleme süresini tamamen
      // atlıyordu: tünele giren, asansöre binen ya da şebeke değiştiren bir
      // oyuncunun gemisi on saniye sonra doğrudan siliniyordu. Yani kopmanın
      // sebebi soket hatasıysa oyuncuya bir dakika veriliyor, sessizlikse hiç
      // verilmiyordu — aynı olayın iki farklı cezası.
      for (final ship in hucre.timedOut()) {
        final session = _sessions[ship.id];
        if (session == null) {
          hucre.orphan(ship);
          continue;
        }

        // SOKET AKIYORSA oturum canlı.
        //
        // Girdi yokluğu tek başına "öldü" demek değil: çizmeyen bir istemci de
        // girdi üretmez. macOS arka plandaki pencerenin çizimini durduruyor ve
        // ölçüldü — uygulama arka planda beklerken oturum on saniyede bir
        // düşürülüp yeniden kuruluyordu (35 saniyede 3 tur). Oyuncu hiçbir şey
        // yapmamıştı; yalnız başka bir pencereye bakıyordu.
        //
        // Kalp atışı bu ayrımı ölçülebilir kılıyor: istemci çizmese de saniyede
        // bir ping yolluyor (bkz. `NetClient._heartbeat`). Ses kesilmediyse
        // düşürecek bir şey yok.
        if (tick - session.lastHeardTick <= _silenceTicks) continue;

        unawaited(session.close('sessiz'));
        _drop(session);
      }

      _mermiHarca(hucre);
      _grantKillRewards(hucre);

      _chargeRepairs(hucre);
      _droidleriAsindir(hucre);
      _windowShots += hucre.shots.length;
    }

    // BOŞALAN hücreleri kapat — simülasyon gider, base kalır.
    //
    // Başlangıç haritası hariç: her yeni oyuncunun düştüğü yer orası, yani
    // sunucu boşken her tik kapanıp ilk bağlantıda yeniden açılırdı. Bir
    // haritalık tik, o gidiş gelişten ucuz.
    for (final kayit in defter.canlilar.toList()) {
      if (kayit.harita == HaritaDefteri.baslangic) continue;
      kayit.kapat();
    }

    if (tick % Protocol.snapshotEveryNTicks == 0) _sendSnapshots();

    final spent = _uptime.elapsedMicroseconds - t0;
    _windowTicks++;
    _tickCost.add(spent);
  }

  /// Snapshot yazıcısı — oturumlar arasında YENİDEN KULLANILIR.
  ///
  /// Tik başına 41 snapshot üretilirken her birine yeni bir tampon açmak,
  /// saniyede binlerce kısa ömürlü `Uint8List` demek.
  final ByteWriter _snapshotWriter = ByteWriter(2048);

  /// Bu snapshot'a girecek entity'lerin `visible` içindeki indeksleri.
  ///
  /// Kare başına yeniden kullanılıyor: izleyici başına yeni bir liste,
  /// 240 oyuncuda saniyede binlerce kısa ömürlü nesne ederdi.
  final List<int> _selection = [];

  /// `visible` indeksine göre "seçildi mi" — O(1) sorgu.
  ///
  /// İlk yazışta bu bir `List.contains` çağrısıydı ve O(n²) ediyordu: 240
  /// görünür entity × 240 izleyici = tik başına 13,8 milyon işlem. ÖLÇÜLDÜ —
  /// bant genişliği %9 düşerken tik p99'u 32'den 45,8 ms'ye fırladı, yani
  /// sıkıştırma kazandırdığından fazlasını CPU'da geri aldı.
  List<bool> _selected = List<bool>.filled(64, false);

  /// İstemciden bu kadar tik ses çıkmazsa snapshot göndermeyi DURDUR.
  ///
  /// `dart:io`'nun WebSocket'i kuyruğunda bekleyen bayt miktarını açmıyor,
  /// yani "istemci yetişemiyor" durumunu doğrudan ÖLÇEMİYORUZ. Elimizdeki tek
  /// dolaylı sinyal ters yön: sağlıklı bir istemci saniyede 30 girdi çerçevesi
  /// yolluyor. Bir saniye boyunca tek çerçeve gelmediyse ya bağlantı ölmüştür
  /// ya da istemci boğulmuştur — ikisinde de saniyede 30 snapshot daha
  /// yığmanın tek etkisi sunucunun belleğini büyütmek olur.
  ///
  /// Çin kaynaklarında yavaş istemci için önerilen sıra tam olarak bu:
  /// komut paketlerini gönder, hareket paketlerini kademeli olarak at
  /// (先尽力发送命令数据包，再循环增量地尝试丢弃移动信息包). Burada
  /// snapshot "hareket", kabul/red/ad mesajları ise "komut" — ve komutlar
  /// bu süzgeçten geçmiyor.
  ///
  /// Oturum tamamen ölmüşse zaten [Protocol.sessionTimeout] düşürüyor; bu eşik
  /// onun çok altında ve GERİ DÖNÜLEBİLİR: istemci konuşmaya başlar başlamaz
  /// snapshot akışı kendiliğinden geri gelir.
  static const int _stallTicks = Protocol.tickRate;

  /// Bu kadar tik boyunca HİÇBİR çerçeve gelmezse oturum gerçekten ölmüştür.
  ///
  /// [_stallTicks]'ten farkı ölçtükleri şey: o, "istemci yetişemiyor mu" diye
  /// sorup snapshot akışını kısıyor ve GERİ DÖNÜLEBİLİR. Bu ise oturumu
  /// kapatıyor, yani ölçütü daha katı olmalı — sessizlik girdi değil BÜTÜN
  /// trafik üzerinden sayılıyor. Kalp atışı saniyede bir attığı için canlı bir
  /// istemci buraya asla değmez.
  //
  // `~/ 1` yalnız double → int çevirimi: `sessionTimeout` saniye cinsinden
  // `double` ve `const` bağlamda `.round()` çağrılamıyor.
  static const int _silenceTicks =
      (Protocol.sessionTimeout * Protocol.tickRate) ~/ 1;

  void _sendSnapshots() {
    // Kuantalama tik başına BİR kez, izleyici başına değil: değer izleyiciden
    // bağımsız ve 200 gemide izleyici başına hesaplamak on binlerce gereksiz
    // dönüşüm ederdi. Hücre başına bir kez — izleyicileri değil HARİTALARI
    // dolaşıyor.
    for (final kayit in defter.canlilar) {
      kayit.hucre!.refreshWire();
    }

    for (final entry in _sessions.entries) {
      final session = entry.value;
      // İzleyicinin KENDİ haritası: bir oyuncu yalnız bulunduğu hücreyi
      // görüyor. Hücreyi burada AÇMIYORUZ — gemisi varsa hücre zaten açık.
      final zone = defter[session.harita].hucre;
      if (zone == null) continue;
      final ship = zone.ships[entry.key];
      if (ship == null) continue;

      if (tick - session.lastHeardTick > _stallTicks) {
        _windowSkipped++;
        // Atlanan snapshot temeli kırar: bu oturum geçen tikin değerlerini
        // ALMADI, dolayısıyla bir sonraki snapshot TAM gitmeli.
        session.needsFullSnapshot = true;
        continue;
      }

      // Mesaj ELDE yazılıyor, `ServerSnapshot` nesnesi kurulmadan: her entity
      // için bir `EntitySnapshot` ayırmak 41 oyuncuda saniyede ~49.000 kısa
      // ömürlü nesne ediyordu. `codec_test.dart` bu yolun nesne kuran yolla
      // birebir aynı baytı ürettiğini kilitliyor.
      final w = _snapshotWriter
        ..reset()
        ..u8(Protocol.msgSnapshot)
        ..u32(tick);
      SelfSnapshot(
        acknowledgedSeq: ship.acknowledgedSeq,
        state: ship.state,
        // Kuyruk derinliği istemciye GERİ söylenir; o da üretim hızını buna
        // göre ayarlar. Tek baytlık bu geri besleme olmadan kuyruk sürekli
        // boşalıp taşar ve her seferinde bir düzeltme doğar.
        pendingInputs: ship.pending.length,
      ).write(w);

      final visible = zone.collectVisible(ship);
      final fresh = zone.lastVisibleFresh;

      // ÖNCELİKLİ REPLİKASYON — hangi entity bu snapshot'a girecek.
      //
      // Ölçüldü: kavgada baytları yiyen şey kodlama değil ORAN. Her görünür
      // entity her tik gidiyor ve konum bilgisi gerçek — küçültülebilecek tek
      // şey sıklık. Politika `Replication`'da (saf, test edilmiş); burada
      // yalnız uygulanıyor.
      _selection.clear();
      if (_selected.length < visible.length) {
        _selected = List<bool>.filled(visible.length * 2, false);
      }
      _selected.fillRange(0, visible.length, false);
      for (var i = 0; i < visible.length; i++) {
        final other = visible[i];
        final since = ship.lastSentTick.containsKey(other.id)
            ? tick - ship.lastSentTick[other.id]!
            : Replication.maxSilenceTicks;
        // Yeni görünen ya da temeli olmayan entity SEÇİMİN DIŞINDA: onu
        // ertelemek, istemcide hiç var olmamış bir gemi demek.
        final forced =
            session.needsFullSnapshot || fresh[i] || !other.wireValid;
        if (!forced &&
            !Replication.isCandidate(
              since,
              other.state.position.distanceSquaredTo(ship.state.position),
              Protocol.interestRadius,
            )) {
          continue;
        }
        _selection.add(i);
        _selected[i] = true;
      }

      // İKİNCİ ELEME: maskesi BOŞ kayıtlar.
      //
      // Bunun bedeli YOK. Hiçbir alan değişmediyse sunucunun yeni temeli
      // eskisiyle aynı, yani atlamak istemcinin temelini bozmuyor. Ölçüldü:
      // sakin dünyada kayıtların %89'u boş — kayıt başına 3 bayt (kimlik +
      // maske) sırf "değişen bir şey yok" demek için gidiyordu.
      //
      // Sessizlik tavanına yaklaşan yine gönderiliyor: istemci bir saniye
      // duymadığı entity'yi düşürüyor.
      _selection.removeWhere((i) {
        final other = visible[i];
        if (session.needsFullSnapshot || fresh[i] || !other.wireValid) {
          return false;
        }
        final since = tick - (ship.lastSentTick[other.id] ?? -1000);
        if (Replication.mustSend(since)) return false;
        if ((tick + other.id) % Protocol.keyframeTicks == 0) return false;
        if (ship.staleBaseline.contains(other.id)) return false;
        if (other.wireMask != 0) return false;
        _selected[i] = false;
        return true;
      });

      // ATLANANLARIN temeli bayatlıyor mu — atlama kararından SONRA.
      //
      // Yalnız DEĞİŞMİŞ bir tiki atlamak bayatlatıyor. Değişmemişi atlamak
      // bedava: sunucunun yeni temeli eskisiyle aynı olduğu için istemcinin
      // temeli hâlâ doğru kalıyor. İlk yazışta kural "atladıysam bayattır"
      // idi ve fazla temkinliydi — duran uzak gemiler her seferinde tam kayıt
      // alıyordu, yani sıkıştırma bant genişliğini ARTIRIYORDU.
      for (var i = 0; i < visible.length; i++) {
        if (_selected[i]) continue;
        final other = visible[i];
        if (!other.wireValid) continue;
        if (other.wireMask != 0) ship.staleBaseline.add(other.id);
      }

      w.u16(_selection.length);
      for (final i in _selection) {
        final other = visible[i];
        ship.lastSentTick[other.id] = tick;
        // TAM kayıt dört durumda: oturumun temeli yok, entity ilgi alanına
        // YENİ girdi, entity daha hiç gönderilmedi, ya da ANAHTAR KARE sırası
        // geldi. İlk üçü temelin bilinen geçersizlik hâlleri; dördüncüsü
        // BİLİNMEYENLER için — bkz. [Protocol.keyframeTicks].
        //
        // Kaydırma `+ other.id` ile: yoksa altmış tikte bir bütün kalabalık
        // aynı anda tam kayıt olur ve düzenli bir bant genişliği tepesi doğar.
        final keyframe = (tick + other.id) % Protocol.keyframeTicks == 0;
        // ATLANMIŞSA TAM KAYIT — öncelikli replikasyonun bedeli bu.
        //
        // Delta'nın temeli HERKES İÇİN ORTAK: önceki tik. Bir entity'yi bir
        // tik atladığımızda istemcinin temeli sunucununkinden geri kalıyor ve
        // ona göre kodlanmış bir delta yanlış konum üretir. İzleyici başına
        // geçmiş tutmak alternatifti ve bu mimaride reddedilmişti (beş bin
        // oyuncuda bellek sorunu). Onun yerine: atlama, dönüşte bir tam kayda
        // mal oluyor. Kazanç ancak atlama yeterince uzunsa gerçek — `since`
        // 2'den küçükken zaten atlama olmamış demektir.
        final baselineStale = ship.staleBaseline.remove(other.id);
        final mask =
            session.needsFullSnapshot ||
                fresh[i] ||
                !other.wireValid ||
                keyframe ||
                baselineStale
            ? EntityDelta.full
            : other.wireMask;
        EntityDelta.write(w, other.id, other.wireNow, mask);
      }

      // Atışlar entity'lerden SONRA: çözücü de aynı sırada okuyor ve iki
      // uzunluk alanı arasında bir dal yok.
      //
      // İki geçiş, çünkü sayaç önce yazılmak zorunda ve liste zaten tikte
      // birkaç öğe uzunluğunda.
      var relevant = 0;
      for (final shot in zone.shots) {
        if (_seesShot(ship, shot)) relevant++;
      }
      if (relevant > ShotEvent.maxPerSnapshot) {
        relevant = ShotEvent.maxPerSnapshot;
      }
      w.u8(relevant);
      var written = 0;
      for (final shot in zone.shots) {
        if (written == relevant) break;
        if (!_seesShot(ship, shot)) continue;
        shot.write(w);
        written++;
        _windowShotsWritten++;
        _windowShotsPerViewer[ship.id] =
            (_windowShotsPerViewer[ship.id] ?? 0) + 1;
      }

      // Alien'ler en sonda — çözücü de aynı sırada okuyor.
      final visibleAliens = zone.collectVisibleAliens(ship);
      final alienFresh = zone.lastVisibleAliensFresh;
      w.u16(visibleAliens.length);
      for (var i = 0; i < visibleAliens.length; i++) {
        final id = visibleAliens[i];
        // Gemilerle AYNI kural — anahtar kare dahil.
        final keyframe = (tick + id) % Protocol.keyframeTicks == 0;
        final mask =
            session.needsFullSnapshot ||
                alienFresh[i] ||
                !zone.alienWireValid(id) ||
                keyframe
            ? AlienDelta.full
            : zone.alienMask(id);
        AlienDelta.write(w, id, zone.alienWireNow(id), mask);
      }

      _windowBytes += w.length;
      _windowSnapshots++;
      session.sendBytes(w.take());
      session.needsFullSnapshot = false;
    }

    // Temeli İLERLET — bütün snapshot'lar gönderildikten SONRA.
    //
    // Sıra kritik: erken ilerletmek, sonraki izleyicilerin bu tikin değerini
    // "geçmiş" sanmasına ve sıfır maskeli boş delta üretmesine yol açardı.
    // Bütün izleyiciler AYNI temele göre kodlanmak zorunda.
    zone.promoteWire();
  }

  /// Bir vuruşun [viewer]'ı ilgilendirip ilgilendirmediği.
  ///
  /// Taraflardan BİRİNİ görmek yeter: menzilin ucundan ateş eden bir gemi
  /// oyuncunun ilgi alanı dışında kalabilir, ama hedefi ekranındaysa hasarın
  /// sayısını görmesi gerekir — yoksa gemiler sebepsiz eriyor.
  ///
  /// [Zone.collectVisible] hemen önce çağrıldığı için `visible` kümesi bu
  /// tikin gerçeğini taşıyor.
  static bool _seesShot(ServerShip viewer, ShotEvent shot) =>
      shot.shooterId == viewer.id ||
      shot.targetId == viewer.id ||
      viewer.visible.contains(shot.shooterId) ||
      viewer.visible.contains(shot.targetId);

  /// İzleyici başına atış dağılımı. Sıfır alan bir izleyici varsa görünürlük
  /// kuralı onu dışarıda bırakıyor demektir.
  String _viewerMin() {
    if (_sessions.isEmpty) return '-';
    var min = 1 << 30;
    for (final id in _sessions.keys) {
      final v = (_windowShotsPerViewer[id] ?? 0) ~/ 5;
      if (v < min) min = v;
    }
    return '$min';
  }

  String _viewerAvg() => _sessions.isEmpty
      ? '-'
      : (_windowShotsWritten / _sessions.length / 5).toStringAsFixed(0);

  String _viewerMax() {
    var max = 0;
    for (final id in _sessions.keys) {
      final v = (_windowShotsPerViewer[id] ?? 0) ~/ 5;
      if (v > max) max = v;
    }
    return '$max';
  }

  void _report() {
    if (_windowTicks == 0) return;
    final budget = 1e6 / Protocol.tickRate;
    // Snapshot BAŞINA ortalama × snapshot hızı = oyuncu başına saniyelik hız.
    final perPlayer = _windowSnapshots == 0
        ? 0.0
        : (_windowBytes / _windowSnapshots) * Protocol.snapshotRate / 1024;

    stdout.writeln(
      '$toplamOyuncu oyuncu · $canliHarita harita · '
      '${(_windowTicks / 5).toStringAsFixed(1)} Hz · '
      'tik ${_tickCost.format()} '
      '(bütçe ${(budget / 1000).toStringAsFixed(1)} ms · '
      'p99 %${(_tickCost.percentile(0.99) / budget * 100).toStringAsFixed(0)}) · '
      'gecikme p99 ${(_tickLag.percentile(0.99) / 1000).toStringAsFixed(1)} ms · '
      'oyuncu başına ${perPlayer.toStringAsFixed(1)} KB/s ↓ · '
      '${(_windowShots / 5).toStringAsFixed(0)} atış/sn üretildi · '
      '${(_windowShotsWritten / 5).toStringAsFixed(0)} yazıldı '
      '(izleyici başına en az ${_viewerMin()} · ortalama ${_viewerAvg()} '
      '· en çok ${_viewerMax()})'
      '${_windowSkipped > 0 ? ' · ⚠ $_windowSkipped snapshot atlandı' : ''}',
    );
    _windowSkipped = 0;
    _windowTicks = 0;
    _tickCost.reset();
    _tickLag.reset();
    _windowBytes = 0;
    _windowSnapshots = 0;
    _windowShots = 0;
    _windowShotsWritten = 0;
    _windowShotsPerViewer.clear();
  }

  /// Ad ağdan geliyor, yani düşman. Uzunluk ve kontrol karakterleri kesilir —
  /// HUD'a doğrudan çizilecek bir metin.
  static String _sanitise(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (cleaned.isEmpty) return 'Pilot';
    return cleaned.length <= 16 ? cleaned : cleaned.substring(0, 16);
  }
}
