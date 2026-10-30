import 'dart:async';
import 'dart:typed_data';

import 'package:voidspace_core/voidspace_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'alien_entities.dart';
import 'durum_kodu.dart';
import 'hangar_view.dart';
import 'net_phase.dart';
import 'predicted_ship.dart';
import 'remote_entities.dart';
import 'token_store.dart';

/// Sunucuya açılan tek kapı.
///
/// Sorumluluğu üç şey: çerçeveleri taşımak, kendi gemimizi TAHMİN etmek
/// ([PredictedShip]) ve ötekileri ARA DEĞERLEMEK ([RemoteEntities]). Oyun
/// döngüsü her karede [update] çağırır ve bileşenler sonucu okur — sıcak yolda
/// stream yok, çünkü kare başına akış olayı bu mimarinin çöp üretme biçimi.
///
/// Flame ve Flutter bilmez; `architecture_test.dart` bunu kilitler.
class NetClient {
  NetClient({
    required this.uri,
    this.stats = ShipStats.bastion,
    TokenStore? tokens,
  }) : _tokens = tokens ?? MemoryTokenStore();

  /// Belirtecin kalıcı deposu. Varsayılan BELLEK: testler ve belirteç
  /// kalıcılığı istemeyen bağlamlar eklenti bağımlılığı taşımasın.
  final TokenStore _tokens;

  /// Derleme sırasında verilebilen sunucu adresi:
  /// `flutter run --dart-define=VOIDSPACE_SERVER=wss://oyun.example.com`
  static const String configuredUrl = String.fromEnvironment(
    'VOIDSPACE_SERVER',
  );

  /// Bağlanılacak adres.
  ///
  /// Verilmediyse ve oyun bir SAYFADAN açıldıysa, adres sayfanın kendi
  /// adresinden türetilir. Sunucu hem istemciyi hem WebSocket'i aynı porttan
  /// verdiği için bu daima doğru adrestir — ve derlemeyi adrese bağımlı
  /// olmaktan kurtarır: aynı derleme localhost'ta, bir tünelin arkasında ve
  /// gerçek alan adında çalışır.
  ///
  /// `https` sayfası `ws://` açamaz (tarayıcı karışık içeriği engeller), o
  /// yüzden şema sayfanınkinden türetiliyor.
  static Uri resolveUri() {
    if (configuredUrl.isNotEmpty) return Uri.parse(configuredUrl);

    // Web'de `Uri.base` sayfanın adresi; native'de bir `file://` yolu.
    final page = Uri.base;
    if (page.scheme == 'http' || page.scheme == 'https') {
      return page.replace(
        scheme: page.scheme == 'https' ? 'wss' : 'ws',
        path: '/',
        query: null,
        fragment: null,
      );
    }
    return Uri.parse('ws://localhost:8080');
  }

  static const Duration _pingInterval = Duration(seconds: 1);
  static const Duration _retryDelay = Duration(seconds: 2);

  final Uri uri;

  /// TAHMİNİN koştuğu gemi statları.
  ///
  /// **Sabit DEĞİL ve olamaz.** Sunucu, dünyaya giren geminin statlarını
  /// oyuncunun DONATIMINDAN çözüyor (`Gateway._statsFor`). İstemci burada
  /// `ShipStats.bastion`de kalsaydı, oyuncu bir itki jeneratörü (`th1`,
  /// `th3`) taktığı an iki uç farklı hızda koşardı: istemci saniyede 320 birim
  /// tahmin ederken sunucu daha fazlasını simüle eder ve her snapshot bir
  /// düzeltme getirirdi. Sonuç, oyuncunun "takılıyor, hareket ettiremiyorum"
  /// diye tarif ettiği şeyin ta kendisi — üstelik ağda hiçbir sorun yokken.
  ///
  /// Bugün bir tuzak: başlangıç donatımı tam olarak `bastion`e denk geliyor,
  /// yani mağazadan İLK hız eşyası alınana kadar hiçbir belirti vermez.
  ShipStats stats;

  final RemoteEntities remotes = RemoteEntities();

  /// Haritadaki alien sürüsü. Gemilerden ayrı bir kimlik uzayı, ama AYNI
  /// oynatma saati (bkz. [AlienEntities]).
  final AlienEntities aliens = AlienEntities();

  /// Entity kimliği → oyuncu adı. Snapshot'ta yeri yok: ad ömürde bir kez
  /// değişir, snapshot ise saniyede 30 kez gider.
  final Map<int, String> names = {};

  /// Kimlik → TAKILI lazer sayısı.
  ///
  /// Adla aynı kanaldan (`ServerEntityMeta`) geliyor ve aynı sebeple: snapshot
  /// saniyede 30 kez gidiyor, bu sayı ise ancak oyuncu hangarda bir lazer takıp
  /// çıkardığında değişiyor.
  ///
  /// Çizim katmanı bunu okuyor: gemi taktığı kadar top taşıyor. Eksik bir
  /// kayıt "silahsız" demek, "bilinmiyor" değil — ve bu doğru varsayılan,
  /// çünkü sunucu dünyadaki her geminin metasını el sıkışmada yolluyor.
  final Map<int, int> lasers = {};

  /// Entity → GÖVDE KADEMESİ (0..7). Hangi gemi çizimiyle görüneceği.
  ///
  /// [lasers] ile aynı kanaldan, aynı sebeple: kademe ancak oyuncu hangarda
  /// gemi değiştirdiğinde değişiyor, snapshot ise saniyede 30 kez gidiyor.
  ///
  /// Eksik kayıt BAŞLANGIÇ gövdesi demek, "bilinmiyor" değil — ve bu doğru
  /// varsayılan: sunucu her geminin metasını el sıkışmada yolluyor, ve bir
  /// kaydın eksik olduğu tek an meta ile snapshot arasındaki tek kare.
  final Map<int, int> govdeler = {};

  /// Entity → droid FİLOSU: her droidin görsel kademesi (1..6) ve modeli,
  /// yuva sırasıyla. [govdeler] ile aynı kanaldan; boş liste droid yok demek.
  final Map<int, List<(int seviye, int model)>> droidler = {};

  /// Entity → seçili formasyonun indeksi (`Formasyon.hepsi`).
  final Map<int, int> formasyonlar = {};

  NetPhase phase = NetPhase.idle;

  /// Reddedilme ya da kopma sebebinin KODU — HUD'a yazılır.
  ///
  /// Metin değil kod: bu katman Flutter bilmiyor, dolayısıyla oyuncunun dilini
  /// de bilmiyor. Kod ya [DurumKodu]'ndan (yerel bir olay) ya da sunucudan
  /// gelen bir `KimlikKodu`'dan; ikisini de `lib/dil/durum_metni.dart`
  /// çeviriyor.
  String? statusMessage;

  int entityId = 0;

  /// Dünya ölçüleri SUNUCUDAN gelir. İstemcinin kendi sabitine güvenmesi,
  /// sunucu haritayı değiştirdiğinde konum kuantalamasını sessizce kaydırırdı.
  GameWorld world = GameWorld.standard;

  String? _gecitHatasi;

  /// Son geçiş denemesinin reddedilme sebebi — yoksa `null`.
  ///
  /// Oturumu ETKİLEMİYOR. İstemci menzili ve kapıyı kendi de biliyor, yani bu
  /// alan doluysa iki uç ayrışmış demektir; oyuncuya söylenmeli ama oyundan
  /// atılmamalı.
  ///
  /// Yazınca BİLDİRİM yapıyor. Sebebi ölçüldü: HUD'ın yeniden kurulması gemi
  /// durumuna bağlı ve `ShipState` bir `Equatable` — geçidin üstünde DURAN
  /// oyuncunun durumu hiç değişmiyor, yani red mesajı ekrana hiç düşmüyordu.
  /// Tam da en çok gerekli olduğu an: duruyorsun, basıyorsun, bir şey olmuyor.
  String? get gecitHatasi => _gecitHatasi;

  set gecitHatasi(String? sebep) {
    if (_gecitHatasi == sebep) return;
    _gecitHatasi = sebep;
    _notify();
  }

  /// Oyuncunun BULUNDUĞU harita.
  ///
  /// Sunucudan geliyor, istemcide tahmin edilmiyor: kapının açılıp
  /// açılmadığına karar veren taraf ile ekranı çizen taraf aynı haritada
  /// olmak zorunda. Galaksi haritası "buradasın" işaretini ve geçit çizimi
  /// hangi kapıların var olduğunu buradan okuyor.
  Harita harita = Harita.baslangic;

  /// Kendi gemimiz. El sıkışma bitene kadar `null`.
  PredictedShip? ship;

  /// Oturum belirteci. Kayıt/giriş karşılığında gelir; yeniden bağlanmada
  /// parola sormadan dünyaya dönmeyi sağlar.
  ///
  /// [TokenStore] üzerinden KALICI. Mobilde işletim sistemi uygulamayı rutin
  /// olarak öldürüyor; bellekte tutulan bir belirteç, oyuncunun her dönüşünde
  /// parola sorulması demekti — ve o parola ekranı, oyuna girmenin önündeki
  /// en sık karşılaşılan engel olurdu.
  String? _token;

  /// Giriş yapmış hesabın adı. Sunucunun bildiği kanonik hâli.
  String? username;

  /// Hangarın SUNUCUDAN gelen hâli.
  ///
  /// İstemci burada hiçbir şey hesaplamıyor — para da, etkin statlar da
  /// sunucunun söylediği. Hangar ekranı bunu çiziyor, kararı sunucu veriyor.
  HangarView? hangar;

  /// Sunucu bizi DÜNYAYA ALDI mı. Alınmadan oyun ekranı GÖSTERİLMEZ.
  ///
  /// **Eskiden bu `username != null` idi ve bir yolu tamamen kaçırıyordu.**
  /// `ServerAuthOk` YALNIZ parola yolundan geliyor; belirteçle dönen bir
  /// istemci (uygulama yeniden açıldı, ağ koptu, sunucu el sıkışmayı
  /// tamamladı) yalnız `ServerWelcome` alıyor. Yani gemi dünyada duruyor ama
  /// istemci kendini "giriş yapmamış" sayıyor ve GİRİŞ EKRANINI gösteriyordu.
  ///
  /// Sessiz olan kısmı daha kötüydü: oyun ağacı hiç kurulmadığı için kare
  /// döngüsü de yok, yani [update] hiç çağrılmıyor ve tek bir girdi çerçevesi
  /// bile gitmiyor. Sunucu on saniye sonra "girdi yok" diye düşürüyor, istemci
  /// iki saniye sonra belirteçle geri dönüyor, aynı sessizlik... Sunucu
  /// günlüğündeki bitmeyen salınım buydu:
  ///
  /// ```
  /// ~ CINAR #1 koptu · 60 sn bekliyor
  /// ↻ CINAR #1 · 1 oyuncu
  /// ~ CINAR #1 koptu · 60 sn bekliyor
  /// ```
  ///
  /// Doğru ölçüt kimliğin ADI değil, sunucunun bizi KABUL ETMİŞ olması —
  /// `ServerWelcome` almak zaten geçerli bir belirteç sunmuş olmak demek.
  bool get isAuthenticated => _admitted;

  bool _admitted = false;

  /// Son kimlik hatasının KODU — kayıt/giriş ekranında gösterilir.
  ///
  /// [statusMessage] ile aynı kural: sunucu `kimlik.hatali-giris` gönderiyor,
  /// cümleyi kuran taraf arayüz.
  String? authError;

  /// Durum değişti bildirimi.
  ///
  /// `ChangeNotifier` DEĞİL: o Flutter'a ait ve bu katmanın Flutter bilmemesi
  /// bir kural (bkz. `architecture_test.dart`). `dart:async` her yerde var,
  /// yani tahmin ve mutabakat hâlâ oyun döngüsü kurmadan test edilebiliyor.
  ///
  /// YALNIZ ayrık durum için: kare başına değişen hiçbir şey buradan
  /// yayınlanmıyor, yoksa saniyede 120 arayüz kurulumu olurdu.
  Stream<void> get changes => _changes.stream;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Son ölçülen gidiş-dönüş süresi (ms).
  int rttMs = 0;

  /// Henüz ÇİZİLMEMİŞ vuruşlar.
  ///
  /// Neden biriktiriliyor: snapshot 30 Hz gelir, ekran 60-120 Hz çizer.
  /// "Bu snapshot'ın olayları" diye bir kare yok — iki kare arasında gelen
  /// olay, oyun döngüsü onu okuyana kadar burada bekler. Döngü her karede
  /// [clearShots] ile boşaltır; boşaltmayan bir çağıran aynı vuruşu iki kez
  /// çizerdi.
  final List<ShotEvent> shots = [];

  /// Bu karede gelen ödüller — arayüz okuyup [takeRewards] ile boşaltır.
  ///
  /// Kalıcı bir sayaç değil OLAY kuyruğu: "+400 KREDİ" yazısı bir kez
  /// gösterilip gidiyor. Bakiye ise [credits]/[premium] içinde ve onu
  /// yalnız sunucu yazıyor.
  final List<ServerReward> _rewards = [];

  /// Bu karede gelen ganimet: düşen eşya ve malzeme, [takeGanimetler] ile
  /// boşaltılır. Ödül gibi OLAY kuyruğu: "C-II PL-2" bir kez gösterilip
  /// gidiyor; envanterin doğrusu [hangar] (14.1).
  final List<ServerGanimet> _ganimetler = [];

  /// Cüzdan — SUNUCUNUN söylediği.
  ///
  /// İstemci kendi sayacını artırmıyor. Artırsaydı tek bir kayıp mesaj
  /// cüzdanı kalıcı olarak ayrıştırırdı, ve para söz konusuyken ayrışma
  /// oyuncunun asla affetmediği hata türü. Ödül mesajı kazancı DA bakiyeyi DE
  /// taşıyor tam bu yüzden.
  int credits = 0;
  int premium = 0;

  /// Bakiyeyi ve ödül kuyruğunu okuyup KUYRUĞU boşaltır.
  List<ServerReward> takeRewards() {
    if (_rewards.isEmpty) return const [];
    final out = List<ServerReward>.of(_rewards);
    _rewards.clear();
    return out;
  }

  /// Ganimet kuyruğunu okuyup BOŞALTIR.
  List<ServerGanimet> takeGanimetler() {
    if (_ganimetler.isEmpty) return const [];
    final out = List<ServerGanimet>.of(_ganimetler);
    _ganimetler.clear();
    return out;
  }

  /// Ağdan ALINAN toplam atış olayı — tüketilenden ayrı sayılır.
  ///
  /// İkisinin ayrı olması teşhis içindir: alınan sıfırsa sorun ağda ya da
  /// çözücüde, alınan doluyken tüketilen sıfırsa sorun oyun döngüsünün
  /// sırasında (biri temizlerken diğeri okuyamıyor).
  int shotsReceived = 0;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;

  /// Kalp atışı — bağlantı canlılığının KARE DÖNGÜSÜNDEN bağımsız kanıtı.
  ///
  /// **Neden zamanlayıcı, oysa ping eskiden [update] içindeydi.** Ölçüldü:
  /// macOS arka plandaki bir pencerenin çizimini durduruyor, yani `update`
  /// hiç çağrılmıyor. Girdi de ping de oradan gittiği için istemci tamamen
  /// susuyor ve sunucu on saniye sonra "girdi yok" diye oturumu düşürüyordu.
  /// Uygulama arka planda beklerken sunucu günlüğü şöyle akıyordu (ölçüm:
  /// 35 saniyede 3 tur):
  ///
  /// ```
  /// ~ gozcu1 #1 koptu · 60 sn bekliyor
  /// ↻ gozcu1 #1 · 1 oyuncu
  /// ```
  ///
  /// Çizmeyen bir istemci ÖLÜ DEĞİL. Zamanlayıcı `dart:async` olay
  /// döngüsünde koşuyor ve o, pencere örtülünce durmuyor — mobilde gerçekten
  /// askıya alındığımızda ise zaten [suspend] devrede.
  ///
  /// Ping'in ikinci işi gidiş-dönüş süresini ölçmek; o da bu yoldan sürüyor
  /// ve artık kare hızından bağımsız, yani daha dürüst.
  Timer? _heartbeat;
  final Stopwatch _clock = Stopwatch()..start();
  bool _sawFirstSnapshot = false;

  /// Delta çözmenin temeli: entity başına EN SON alınan kuantalanmış değerler.
  ///
  /// Sunucu her tikte yalnız DEĞİŞEN alanları yolluyor; okunmayan alanlar
  /// buradan geliyor. Ömrü bağlantıya ait — bkz. [_reset].
  final EntityBaseline _baseline = EntityBaseline();

  /// Bağlantı NESLİ.
  ///
  /// `_subscription.cancel()` ASENKRON: iptal edilmiş bir akışın kuyruğunda
  /// bekleyen çerçeve, iptal tamamlanmadan önce dinleyiciye ulaşabiliyor. Yeni
  /// bağlantı kurulurken gelen böyle bir "hayalet" çerçeve, YENİ oturumun
  /// temeline ESKİ oturumun verisini uygular.
  ///
  /// Gerçekten oldu ve delta bunu yakaladı: temeli sıfırlanmış bir istemciye
  /// kısmi delta düştü ve çözücü haklı olarak reddetti. Delta olmadan aynı
  /// hayalet çerçeve sessizce yanlış bir konum çizerdi — hata görünür değil,
  /// yalnız daha sinsi olurdu.
  ///
  /// Her `connect()` nesli artırıyor; dinleyici kendi neslini kapatıyor ve
  /// eşleşmeyen çerçeveler atılıyor.
  int _generation = 0;

  /// Arka planda mıyız. Bu bayrak açıkken otomatik yeniden bağlanma YOK:
  /// askıya alınmış bir uygulamada bağlanmaya çalışmak yalnız pil yakar.
  bool _suspended = false;

  bool _disposed = false;

  bool get isPlaying => phase == NetPhase.playing && ship != null;

  /// Kayıtlı belirteci yükler. Uygulama açılışında BİR KEZ, [connect]'ten önce.
  ///
  /// Olmadan da çalışır (parola sorulur); olduğunda oyuncu doğrudan dünyaya
  /// düşer.
  Future<void> restoreSession() async {
    _token ??= await _tokens.read();
  }

  /// Uygulama ARKA PLANA alındı: soketi bilerek kapat.
  ///
  /// iOS uygulamayı askıya alırken soket kaynaklarını geri topluyor, yani
  /// bağlantı zaten ölüyor — ama sessizce ve yarım. Bilerek kapatmak sunucuya
  /// düzgün bir kapanış veriyor (gemi sahipsiz olarak bekliyor) ve dönüşte
  /// temiz bir yeniden bağlanma bırakıyor.
  ///
  /// Yeniden deneme zamanlayıcısı da iptal ediliyor: arka planda zamanlayıcı
  /// zaten donuyor, ve dönüşte birikmiş bir deneme selinin anlamı yok.
  void suspend() {
    if (_disposed || _suspended) return;
    _suspended = true;
    _retry?.cancel();
    _retry = null;
    _reset(NetPhase.disconnected, DurumKodu.arkaPlanda.kod);
  }

  /// Uygulama ÖNE geldi: yeniden bağlan.
  void resume() {
    if (_disposed || !_suspended) return;
    _suspended = false;
    unawaited(connect());
  }

  Future<void> connect() async {
    if (_disposed || _suspended || phase == NetPhase.connecting) return;
    _reset(NetPhase.connecting, DurumKodu.baglaniliyor.kod);

    try {
      final generation = _generation;
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready;

      // `ready` BEKLENİRKEN durum değişmiş olabilir: uygulama arka plana
      // alındı, istemci atıldı, ya da yeni bir bağlantı başladı. Üçü de nesli
      // artırıyor.
      //
      // Yalnız `_disposed` bakmak yetmiyordu ve sızıntı üretiyordu: el
      // sıkışma sürerken arka plana geçen bir uygulamada bu soket AÇIK
      // kalıyor, kimse okumuyor ve sunucu tarafında sahte bir oturum
      // duruyordu. Nesil kontrolü üç durumu birden kapatıyor.
      if (_disposed || generation != _generation) {
        await channel.sink.close();
        return;
      }
      _subscription = channel.stream.listen(
        (data) {
          if (generation != _generation) return; // eski bağlantının hayaleti
          _onFrame(data);
        },
        onDone: () {
          if (generation == _generation) _fail(DurumKodu.kapandi.kod);
        },
        onError: (Object e) {
          if (generation == _generation) _fail(DurumKodu.hata.kod);
        },
        cancelOnError: true,
      );

      // Hello ARTIK BURADA DEĞİL. Dünyaya girmek için önce kimlik gerekiyor;
      // elimizde bir belirteç varsa (aynı oturumda yeniden bağlanma) doğrudan
      // kullanılır, yoksa arayüz kayıt/giriş ekranını gösterir.
      _heartbeat = Timer.periodic(_pingInterval, (_) {
        if (generation != _generation) return;
        _send(ClientPing(_clock.elapsedMilliseconds));
      });

      final token = _token;
      if (token != null) {
        _send(ClientHello(protocolVersion: Protocol.version, token: token));
      } else {
        phase = NetPhase.needsAuth;
        statusMessage = null;
        _notify();
      }
    } on Object {
      _fail(DurumKodu.ulasilamadi.kod);
    }
  }

  void dispose() {
    _disposed = true;
    _changes.close();
    _heartbeat?.cancel();
    _retry?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
  }

  /// Kare başına ağ işi: tahmini ilerlet, girdileri yolla, ara değeri sür.
  void update(double dt) {
    final local = ship;
    if (local != null && phase == NetPhase.playing) {
      for (final input in local.advance(dt)) {
        _send(ClientInput(seq: input.seq, input: input));
      }
    }
    remotes.advance(dt);
  }

  /// Çizilen vuruşları düşür. Oyun döngüsü her karede çağırır.
  void clearShots() => shots.clear();

  /// Hangar komutu yolla. Kararı sunucu verir; sonuç [hangar]'a düşer.
  void hangarAction(String action, [Map<String, Object?> payload = const {}]) =>
      _send(ClientHangar(action: action, payload: payload));

  /// Yeni hesap oluştur.
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) => _authenticate(
    ClientRegister(
      protocolVersion: Protocol.version,
      email: email,
      username: username,
      password: password,
    ),
  );

  /// Var olan hesaba gir. [username] e-posta da olabilir.
  Future<void> login({required String username, required String password}) =>
      _authenticate(
        ClientLogin(
          protocolVersion: Protocol.version,
          username: username,
          password: password,
        ),
      );

  /// Kimlik çerçevesini CANLI bir kanaldan yolla.
  ///
  /// **Neden kanalı burada garanti ediyoruz.** Kimlik ekranı yalnız bağlantı
  /// ölüyken görünür hâle gelebiliyor (sunucu yeniden başladı, oyuncu
  /// reddedildi, ağ koptu). Eskiden çerçeve doğrudan yollanıyordu ve
  /// [_send] kanal yokken sessizce yutuyordu: faz "doğrulanıyor"da
  /// kilitleniyor, düğme kapanıyor ve uygulamayı yeniden başlatmaktan başka
  /// çıkış kalmıyordu. "Düğmeye bastım, hiçbir şey olmadı" tam olarak buydu.
  ///
  /// Kilidin kendisi de burada açılıyor: gönderim başarısızsa faz kimlik
  /// ekranına geri düşüyor, çünkü cevabı asla gelmeyecek bir isteği beklemek
  /// arayüzü ölü bırakmanın en sessiz yolu.
  Future<void> _authenticate(ClientMessage message) async {
    if (_disposed || phase == NetPhase.authenticating) return;
    // Zaten oynuyorken kimlik yollamak fazı boşuna "doğrulanıyor"a çeviriyor
    // ve cevabı gelmiyor — arayüzde ulaşılamayan bir yol ama açık bir tuzak.
    if (phase == NetPhase.playing) return;
    if (_channel == null) await connect();

    authError = null;
    phase = NetPhase.authenticating;
    _notify();

    if (!_send(message)) {
      phase = NetPhase.needsAuth;
      authError = DurumKodu.ulasilamadi.kod;
      _notify();
    }
  }

  // TODO(combat): silah katmanı gelince sil. Bugünkü işi, hasarın İSTEMCİDE
  // hesaplanmadığını göstermek — bu düğme yalnız niyet yolluyor.
  /// Üstünde durulan geçit — yoksa `null`.
  ///
  /// İstemcide hesaplanıyor çünkü yalnız ARAYÜZ için: hangi geçit olduğuna
  /// karar veren taraf sunucu. Buradaki cevap yanlış olsa bile oyuncu yanlış
  /// bir yere gidemez, olsa olsa görünmeyen bir düğme görür.
  Gecit? get yakinGecit {
    final konum = ship?.state.position;
    if (konum == null) return null;
    final menzilKare = GecitAgi.yaricap * GecitAgi.yaricap;
    for (final g in GecitAgi.gecitleriFor(harita)) {
      if (g.konum.distanceSquaredTo(konum) <= menzilKare) return g;
    }
    return null;
  }

  /// GEÇ — üstünde durulan geçitten.
  ///
  /// Hangi geçit olduğu SÖYLENMİYOR: sunucu geminin konumundan buluyor.
  void gecitteGec() {
    gecitHatasi = null;
    _send(const ClientGecit());
  }

  void sendDebug(int kind) => _send(ClientDebug(kind));

  void _onFrame(dynamic data) {
    final Uint8List bytes;
    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = Uint8List.fromList(data);
    } else if (data is ByteBuffer) {
      // Tarayıcıda `binaryType = arraybuffer` bu yolu üretebilir.
      bytes = data.asUint8List();
    } else {
      return;
    }

    // Snapshot AYRI ele alınır: çözülmesi dünya ölçülerini bilmeyi gerektiriyor
    // (kuantalama onlara göre yapıldı) ve genel çözücünün böyle bir bağlamı yok.
    if (bytes.isNotEmpty && bytes[0] == Protocol.msgSnapshot) {
      final ServerSnapshot snapshot;
      try {
        snapshot = ServerSnapshot.decodeWith(
          bytes,
          world.width,
          world.height,
          stats,
          _baseline,
        );
      } on Object {
        // ATLAMA DEĞİL, KOPAR.
        //
        // `decodeWith` genel çözücünün try/catch'ini ATLIYOR, yani buradaki
        // istisna hiçbir yere gitmiyordu: `onError` onData'dan fırlayanı
        // yakalamıyor, `_fail` çağrılmıyordu ve faz `playing`de kalıyordu.
        // Ekran, hiçbir hata görünmeden donuyordu.
        //
        // Çerçeveyi atlayıp devam etmek de GÜVENLİ DEĞİL: `EntitySnapshot.read`
        // delta'yı temelin üstüne YERİNDE yazıyor, yani yarıda kalan bir çözme
        // temelin bir kısmını yeni tike ilerletip gerisini eskide bırakıyor.
        // O karışım kalıcı olur ve sonraki bütün delta'lar sessizce yanlış
        // konum üretir.
        //
        // `_fail` doğru yol çünkü zaten bu dosyanın kendi politikası
        // (`MalformedMessage` → `_fail`): temel temizleniyor, yeniden bağlanan
        // oturum sunucudan TAM snapshot alıyor.
        //
        // `on FormatException` DEĞİL: bozuk bir sayaç alanı `ByteReader`'dan
        // `RangeError` attırıyor.
        _fail(DurumKodu.bozukSnapshot.kod);
        return;
      }
      // try DIŞINDA: `_onSnapshot` oyun mantığı, protokol değil. İçeride
      // olsaydı bir çizim hatası "bozuk snapshot" diye raporlanırdı.
      _onSnapshot(snapshot);
      return;
    }

    switch (ServerMessage.decode(bytes)) {
      case ServerWelcome(
        :final entityId,
        :final worldWidth,
        :final worldHeight,
        :final worldMargin,
        :final bolgeKademe,
        :final haritaTipi,
      ):
        this.entityId = entityId;
        // NEREDE uyandığımız karşılamada geliyor. Varsayılana güvenmek,
        // kaydından dönen oyuncuyu yanlış haritada sanmak demekti: çizilen
        // geçitler sunucuda yok ve her deneme "menzilde değilsin" ile
        // dönüyordu.
        harita = Harita(
          Bolge.byKademe(bolgeKademe) ?? Bolge.ilk,
          HaritaTipi.values[haritaTipi.clamp(0, HaritaTipi.values.length - 1)],
        );
        world = GameWorld(
          width: worldWidth,
          height: worldHeight,
          margin: worldMargin,
        );
        ship = PredictedShip(
          world: world,
          // Geçici doğuş noktası: ilk snapshot gerçek konumu getirip
          // ışınlayacak (bkz. `_sawFirstSnapshot`).
          initial: ShipSimState.spawn(stats, world.centre),
        );
        // Karşılama, kabulün KENDİSİ: geçerli bir belirteç sunmadan buraya
        // gelinmiyor.
        _admitted = true;
        phase = NetPhase.playing;
        statusMessage = null;
        _notify();

      // ── HARİTA DEĞİŞTİ ──
      //
      // Welcome'ın küçük kardeşi: oturumu değil yalnız DÜNYAYI yeniliyor.
      // `_admitted` ve `phase` ellenmiyor — oyuncu zaten içeride.
      case ServerHarita(
        :final entityId,
        :final bolgeKademe,
        :final haritaTipi,
        :final worldWidth,
        :final worldHeight,
        :final worldMargin,
        :final x,
        :final y,
      ):
        this.entityId = entityId;
        // Geçiş başardı: eski red mesajı ekranda kalmamalı.
        gecitHatasi = null;
        harita = Harita(
          Bolge.byKademe(bolgeKademe) ?? Bolge.ilk,
          HaritaTipi.values[haritaTipi.clamp(0, HaritaTipi.values.length - 1)],
        );
        world = GameWorld(
          width: worldWidth,
          height: worldHeight,
          margin: worldMargin,
        );
        // Eski haritanın kadrosu SİLİNİYOR. Kalsaydı, artık görülmeyen
        // gemiler ekranda donmuş hâlde asılı kalırdı: sunucu onlar için
        // "gitti" yollamıyor, çünkü giden onlar değil OYUNCU.
        remotes.clear();
        // Tahmin durumu da yeni dünyada kurulmalı: eski dünyanın sınırlarıyla
        // kelepçelenen bir gemi, yeni haritanın kenarında sıkışırdı.
        // SIRA NUMARASI TAŞINIYOR — sıfırdan başlamıyor.
        //
        // Sunucu da geçitte sayacı taşıyor (`Gateway._onGecit`). İkisinden
        // biri eksik kalırsa oyuncu ya sağır kalıyor ya yolda kalan bir eski
        // girdiyi yiyor; gerekçesi [PredictedShip] içinde yazılı.
        // KONUM SUNUCUDAN — tahmin edilmiyor.
        //
        // Burada `world.centre` yazılıydı ve sunucu gemiyi geçidin karşı
        // kenarına koyuyor: aradaki fark ışınlanma eşiğinin yirmi katı, yani
        // her geçişte iki sıçrama (önce merkeze, sonra ilk anlık görüntüyle
        // gerçek yere) ve kamera onları takip ediyordu.
        ship = PredictedShip(
          world: world,
          initial: ShipSimState.spawn(stats, Vec2(x, y)),
          baslangicSirasi: ship?.sonSira ?? 0,
        );
        _notify();

      case ServerGecitRed(:final sebep):
        gecitHatasi = sebep;

      case ServerAuthOk(:final token, :final username):
        _token = token;
        unawaited(_tokens.write(token));
        this.username = username;
        _admitted = true;
        authError = null;
        // Kimlik tamam: şimdi dünyaya gir.
        _send(ClientHello(protocolVersion: Protocol.version, token: token));
        _notify();

      case ServerAuthError(:final reason):
        // Elimizde bir BELİRTEÇLE geldiysek reddedilen şey o belirteçtir:
        // parola denemesinde belirteç yoktur (giriş ekranındayız), yani bu dal
        // yalnız "oturumun bitti" hâlinde açılır.
        //
        // Yalnız belirteci silmek YETMİYOR, ad da silinmeli: arayüz oyun
        // ekranını `username != null` diye gösteriyor. Adı bırakmak, oyuncuyu
        // gemisiz ve snapshot'sız bir dünyada — donmuş bir ekranda, giriş
        // ekranına ulaşamadan — bırakıyordu. "Takılıyor, hareket
        // ettiremiyorum" tarifi tam olarak o hâlin kendisi.
        if (_token != null) _forgetToken();
        authError = reason;
        phase = NetPhase.needsAuth;
        _notify();

      case ServerRejected(:final reason):
        // Belirteç sunucuda geçersiz (yeniden başlatılmış olabilir): unut,
        // kullanıcı yeniden girsin. Aksi hâlde sonsuza kadar reddedilirdik.
        _forgetToken();
        _reset(NetPhase.rejected, reason);

      case ServerPong(:final clientTimeMs):
        rttMs = _clock.elapsedMilliseconds - clientTimeMs;

      case ServerEntityMeta(
        :final id,
        :final name,
        lasers: final barrels,
        govde: final kademe,
        droidler: final kademeler,
        droidModelleri: final modeller,
        :final formasyon,
      ):
        names[id] = name;
        lasers[id] = barrels;
        govdeler[id] = kademe;
        droidler[id] = [
          for (var i = 0; i < kademeler.length; i++)
            (kademeler[i], i < modeller.length ? modeller[i] : 0),
        ];
        formasyonlar[id] = formasyon;
        // Kendi adımız da bu yoldan geliyor — sunucu el sıkışmada bütün
        // kadronun adını, bizimki dahil, yolluyor. Belirteçle dönen istemcinin
        // adı öğrenmesinin tek yolu bu: `ServerAuthOk` o yolda gelmiyor.
        if (id == entityId) username = name;

      case ServerEntityGone(:final id):
        names.remove(id);
        lasers.remove(id);
        govdeler.remove(id);
        droidler.remove(id);
        formasyonlar.remove(id);
        remotes.remove(id);

      case MalformedMessage():
        _fail(DurumKodu.bozukCerceve.kod);

      case final ServerReward reward:
        credits = reward.balanceCredits;
        premium = reward.balancePremium;
        _rewards.add(reward);
        _notify();

      case final ServerGanimet ganimet:
        _ganimetler.add(ganimet);
        _notify();

      case ServerHangarState(:final json):
        final view = HangarView.fromJson(json);
        hangar = view;
        // Cüzdan hangar durumundan da tazeleniyor: satın alma bakiyeyi
        // DÜŞÜRÜYOR ve o düşüş ödül mesajından gelmiyor.
        credits = view.credits;
        premium = view.premium;
        // Donatım TAHMİNE de giriyor. Çözüm ORTAK paketten (`LoadoutResolver`)
        // geliyor, yani sunucunun kullandığı uygulamanın aynısı: iki uçta iki
        // ayrı kod olsaydı sapma kaçınılmaz olurdu ve sapmanın adı "lag"
        // olurdu.
        stats = LoadoutResolver.resolve(
          Loadout(hullId: view.activeHullId, slots: view.slots),
          view.inventory,
          Catalogue.byId,
        );
        _notify();

      case ServerSnapshot():
        break; // yukarıda ele alındı
    }
  }

  void _onSnapshot(ServerSnapshot snapshot) {
    final local = ship;
    if (local == null) return;

    if (!_sawFirstSnapshot) {
      // İlk snapshot GERÇEK doğuş noktası. Yumuşatmak, gemiyi haritanın
      // ortasından oraya süzülerek getirirdi.
      _sawFirstSnapshot = true;
      local.snapTo(snapshot.self.state);
    } else {
      local.reconcile(snapshot.self);
    }
    remotes.ingest(snapshot.serverTick, snapshot.entities);
    aliens.ingest(snapshot.serverTick, snapshot.aliens);
    shots.addAll(snapshot.shots);
    shotsReceived += snapshot.shots.length;
  }

  /// Çerçeveyi yolla. Gidebildiyse `true`.
  ///
  /// Dönüş değeri kimlik yolu içindir ([_authenticate]): girdi çerçevesi
  /// düşerse bir sonraki zaten yolda, ama düşen bir giriş çerçevesi arayüzü
  /// cevap bekler hâlde bırakıyor. Burada `_fail` ÇAĞIRMIYORUZ — bu yol kare
  /// başına otuz kez geçiliyor ve her geçişte yeniden bağlanma zamanlayıcısını
  /// sıfırlamak, bağlantıyı hiç kurulamaz hâle getirirdi.
  bool _send(ClientMessage message) {
    final channel = _channel;
    if (channel == null) return false;
    try {
      channel.sink.add(message.encode());
      return true;
    } on Object {
      _fail(DurumKodu.gonderilemedi.kod);
      return false;
    }
  }

  void _fail(String reason) {
    if (_disposed || phase == NetPhase.rejected) return;
    _reset(NetPhase.disconnected, reason);
    // Yeniden bağlanma otomatik: bir MMO istemcisinde kopan bağlantı normal
    // bir olaydır, hata ekranı değil.
    _retry?.cancel();
    if (_suspended) return;
    _retry = Timer(_retryDelay, connect);
  }

  /// Belirteci geçersiz kıl — sunucu reddettiğinde.
  void _forgetToken() {
    _token = null;
    unawaited(_tokens.clear());
    username = null;
    _admitted = false;
  }

  void _reset(NetPhase next, String? message) {
    // Nesli ÖNCE artır: bu andan sonra eski akıştan gelen her çerçeve atılır.
    _generation++;
    _heartbeat?.cancel();
    _heartbeat = null;
    phase = next;
    statusMessage = message;
    _notify();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    ship = null;
    _sawFirstSnapshot = false;
    // `_token` KASITLI olarak korunuyor: kopan bağlantı parolayı yeniden
    // sormayı gerektirmemeli. Yalnız sunucu reddederse silinir.
    names.clear();
    lasers.clear();
    remotes.clear();
    aliens.clear();
    // Delta TEMELİ de gider. Yeni oturumun ilk snapshot'ı zaten TAM geliyor
    // (sunucu yeni oturumu böyle işaretliyor); eski temeli taşımak, kimlikler
    // yeniden kullanıldığında başka bir geminin geçmişinin üstüne delta
    // uygulamak demek olurdu.
    _baseline.clear();
    // Kopan bağlantının vuruşları YENİ oturuma taşınmaz: kimlikler yeniden
    // kullanılıyor, yani eski bir olay yanlış gemiye sayı bastırırdı.
    shots.clear();
    _rewards.clear();
    _ganimetler.clear();
    credits = 0;
    premium = 0;
  }
}
