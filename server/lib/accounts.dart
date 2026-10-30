import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/veri_yolu.dart';

/// Kimlik doğrulama reddi — istemciye gönderilecek hata KODU.
///
/// Metin değil kod taşıyor (bkz. [KimlikKodu]): sunucu üç dil bilmiyor,
/// cümleyi kuran taraf istemci.
///
/// Kodlar kasten kaba taneli: `hataliGiris` "kullanıcı adı ya da parola
/// hatalı" der, hangisinin yanlış olduğunu söylemez. Söyleseydi, bir saldırgan
/// hangi kullanıcı adlarının var olduğunu tek tek öğrenebilirdi.
class AuthFailure implements Exception {
  const AuthFailure(this.kod);

  final KimlikKodu kod;

  /// Telde giden değer.
  String get reason => kod.kod;

  @override
  String toString() => kod.kod;
}

/// Bir hesap.
///
/// Parola YOK — yalnız tuz ve türetilmiş anahtar var. Bu ayrım kayıtsız
/// şartsız: veritabanı sızsa bile parolaların kendisi orada değil.
class Account {
  Account({
    required this.id,
    required this.email,
    required this.username,
    required this.salt,
    required this.hash,
    required this.iterations,
    required this.createdAt,
  });

  final String id;

  /// Normalize edilmiş (küçük harf) e-posta — benzersizlik anahtarı.
  final String email;

  /// Kanonik kullanıcı adı: kaydedildiği hâliyle. Benzersizlik küçük harfe
  /// göre, gösterim buna göre.
  final String username;

  final Uint8List salt;
  final Uint8List hash;
  final int iterations;
  final DateTime createdAt;

  String get usernameKey => Credentials.normalizeUsername(username);

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'salt': base64.encode(salt),
    'hash': base64.encode(hash),
    'iterations': iterations,
    'createdAt': createdAt.toIso8601String(),
  };

  static Account fromJson(Map<String, Object?> json) => Account(
    id: json['id']! as String,
    email: json['email']! as String,
    username: json['username']! as String,
    salt: base64.decode(json['salt']! as String),
    hash: base64.decode(json['hash']! as String),
    iterations: json['iterations']! as int,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  /// Parolayı asla basma.
  @override
  String toString() => 'Account($username)';
}

/// Bir belirtecin arkasındaki oturum: hesap + son kullanma.
class _Session {
  _Session(this.account, this.expiresAt);

  final Account account;
  final DateTime expiresAt;
}

/// Hesap deposu: kayıt, giriş, belirteç.
///
/// **Dosya tabanlı ve bu geçici.** Gerçek bir veritabanı gelene kadar yeterli
/// çünkü yazma seyrek (kayıt başına bir kez) ve okuma tamamen bellekten.
/// Arayüz o günü düşünerek dar tutuldu: `register` / `login` / `accountFor`
/// dışında hiçbir şey depoya dokunmuyor.
///
/// **Biçim: JSON Lines (satır başına bir hesap), dizi DEĞİL.**
///
/// Sebep ölçüldü. Tüm listeyi tek bir JSON dizisi olarak yazmak, her yeni
/// kayıtta dosyanın TAMAMINI yeniden kodlamak demekti ve `jsonEncode` eşzamanlı
/// çalışır — yani oyun tikini bloklar:
///
/// | hesap  | encode+yaz | 33 ms tik bütçesinin |
/// |--------|-----------|----------------------|
/// | 1.000  | 1.8 ms    | %6                   |
/// | 5.000  | 6.1 ms    | %18                  |
/// | 20.000 | 29.0 ms   | %87                  |
///
/// Yirmi bin hesapta tek bir kayıt bütün kareyi yerdi ve bunu hisseden, o
/// sırada oynayan HERKES olurdu. Satır ekleme ise hesap sayısından bağımsız:
/// maliyet O(1).
///
/// Aynı kullanıcı adı için birden çok satır varsa SONUNCU kazanır. Bu, ileride
/// parola değişikliği ya da ilerleme kaydı geldiğinde güncellemenin de aynı
/// ucuz yoldan (satır ekleyerek) yapılabilmesi demek. Dosya zamanla şişerse
/// sıkıştırma gerekir; bugün için 20.000 hesap ≈ 4 MB.
class AccountStore {
  /// Yol VERİLMEZSE [VeriYolu] karar veriyor: `ACCOUNTS` çevre değişkeni,
  /// yoksa üretimde `data/accounts.json` ve testte geçici bir dosya.
  ///
  /// Bugün her test `accounts:` ile geçici bir yol veriyor, yani buradan
  /// sızan bir şey YOK. Yine de hangarla defterin yanına alındı: sızıntının
  /// sebebi yolun yanlış olması değil, "vermeyi unutmanın SESSİZ olması"ydı
  /// ve o sessizlik burada da duruyordu. Üç depodan ikisini korumak, üçüncü
  /// deponun unutulacağı günü beklemek olurdu.
  AccountStore({
    String? path,
    Random? random,
    this.tokenTtl = defaultTokenTtl,
  }) : path = VeriYolu.belirle(
         path,
         uretim: VeriYolu.hesaplar,
         cevre: 'ACCOUNTS',
       ),
       _random = random ?? Random.secure();

  final String path;
  final Random _random;

  final Map<String, Account> _byUsername = {};
  final Map<String, Account> _byEmail = {};

  /// Belirteç → oturum. BELLEKTE: sunucu yeniden başladığında herkes yeniden
  /// giriş yapar. Kalıcı oturum, gerçek veritabanıyla birlikte gelecek.
  final Map<String, _Session> _tokens = {};

  /// Hesap başına GEÇERLİ belirteç. Yeni giriş eskisini geçersiz kılar.
  ///
  /// Olmasaydı her giriş haritaya kalıcı bir kayıt daha eklerdi: bir oyuncunun
  /// bin kez girip çıkması bin geçerli belirteç bırakırdı. İkisi de kötü —
  /// bellek sonsuza kadar büyür ve çalınmış eski bir belirteç ilelebet geçerli
  /// kalır.
  final Map<String, String> _tokenOfAccount = {};

  /// Belirteç ömrü. Sonsuz olamaz: sızan bir belirteç, parolayı değiştirmenin
  /// bile kapatamayacağı kalıcı bir arka kapı olurdu.
  ///
  /// Ayarlanabilir olması TEST içindir: on iki saati gerçekten beklemeden
  /// süre dolmasının doğru çalıştığını kanıtlamanın başka yolu yok, ve
  /// kanıtlanmayan bir son kullanma tarihi yok sayılabilir.
  static const Duration defaultTokenTtl = Duration(hours: 12);

  final Duration tokenTtl;

  /// PBKDF2 tur sayısı.
  ///
  /// Yavaşlık ÖZELLİKTİR: parola listesini deneyen birinin her denemesi bu
  /// kadar sürer. 120 bin tur bu makinede ~100 ms — kullanıcı için görünmez,
  /// saldırgan için felaket.
  static const int iterations = 120000;

  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  int get count => _byUsername.length;

  /// Kullanıcı adından hesap — YALNIZ okuma, parola yok.
  ///
  /// Geliştirme uçları için (bkz. `Gateway` `/dev/para`): kimlik doğrulama
  /// yolundan geçmiyor, o yüzden burada zamanlama kanalı kaygısı da yok —
  /// çağıran zaten sunucunun sahibi.
  Account? adiyla(String username) =>
      _byUsername[Credentials.normalizeUsername(username.trim())];

  Future<void> load() async {
    final file = File(path);
    if (!file.existsSync()) return;
    final text = await file.readAsString();
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return;

    // ESKİ biçim: tek bir JSON dizisi. Okumaya devam ediyoruz çünkü bu
    // değişiklik yayınlanmış bir sunucunun hesap dosyasını bulabilir ve
    // "biçim değişti" gerekçesiyle gerçek oyuncuları silmek kabul edilemez.
    // İlk yeni kayıtta dosya kendiliğinden yeni biçime geçer.
    if (trimmed.startsWith('[')) {
      for (final entry in jsonDecode(trimmed) as List<Object?>) {
        _remember(Account.fromJson(entry! as Map<String, Object?>));
      }
      await _rewrite();
      return;
    }

    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      // Bozuk son satır süreç yazarken öldüğünde oluşur. Onu atlamak, bütün
      // depoyu okunamaz saymaktan iyidir.
      try {
        _remember(Account.fromJson(jsonDecode(line) as Map<String, Object?>));
      } on FormatException {
        stderr.writeln('hesap satırı atlandı (bozuk)');
      }
    }
  }

  void _remember(Account account) {
    _byUsername[account.usernameKey] = account;
    _byEmail[account.email] = account;
  }

  /// Tek hesabı dosyanın SONUNA ekler — maliyet hesap sayısından bağımsız.
  Future<void> _append(Account account) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(account.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Dosyayı baştan yazar — yalnız eski biçimden geçişte.
  ///
  /// ÖNCE geçici dosyaya, SONRA yerine taşı: yazma sırasında süreç ölürse
  /// yarım bir hesap dosyası kalmaz, çünkü taşıma atomiktir.
  Future<void> _rewrite() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final temp = File('$path.tmp');
    await temp.writeAsString(
      _byUsername.values.map((a) => '${jsonEncode(a.toJson())}\n').join(),
      flush: true,
    );
    await temp.rename(path);
  }

  Future<Account> register({
    required String email,
    required String username,
    required String password,
  }) async {
    // Kurallar ORTAK pakette: istemcinin gördüğü kurallarla burası ayrışamaz.
    final problem =
        Credentials.checkEmail(email) ??
        Credentials.checkUsername(username) ??
        Credentials.checkPassword(password);
    if (problem != null) throw AuthFailure(problem);

    final emailKey = Credentials.normalizeEmail(email);
    final usernameKey = Credentials.normalizeUsername(username);

    if (_byUsername.containsKey(usernameKey)) {
      throw const AuthFailure(KimlikKodu.kullaniciAlinmis);
    }
    if (_byEmail.containsKey(emailKey)) {
      throw const AuthFailure(KimlikKodu.epostaAlinmis);
    }

    final salt = _bytes(_saltBytes);
    final hash = await _derive(password, salt, iterations);
    final account = Account(
      id: base64Url.encode(_bytes(12)),
      email: emailKey,
      username: username.trim(),
      salt: salt,
      hash: hash,
      iterations: iterations,
      createdAt: DateTime.now().toUtc(),
    );

    _remember(account);
    await _append(account);
    return account;
  }

  Future<Account> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    // Uzunluk PBKDF2'DEN ÖNCE kontrol edilir.
    //
    // `register` kuralları zaten uyguluyor ama `login` uygulamıyordu: hiçbir
    // hesabın sahip olamayacağı 10 MB'lık bir "parola" doğrudan türetmeye
    // gidiyordu. Var olamayacak bir parolayı doğrulamak için 120 bin tur
    // harcamak, saldırgana bedava CPU vermektir.
    if (usernameOrEmail.length > Credentials.usernameMax + 64 ||
        password.length > Credentials.passwordMax) {
      throw const AuthFailure(KimlikKodu.hataliGiris);
    }

    final key = usernameOrEmail.trim();
    final account =
        _byUsername[Credentials.normalizeUsername(key)] ??
        _byEmail[Credentials.normalizeEmail(key)];

    // Hesap yoksa da parola TÜRETİLİR.
    //
    // Yoksa "kullanıcı yok" cevabı anında, "parola yanlış" cevabı 100 ms sonra
    // dönerdi; aradaki fark, hangi kullanıcı adlarının var olduğunu ölçerek
    // öğrenmeye yeter. Zamanlama kanalını kapatmanın bedeli bir sahte türetme.
    if (account == null) {
      await _derive(password, _bytes(_saltBytes), iterations);
      throw const AuthFailure(KimlikKodu.hataliGiris);
    }

    final hash = await _derive(password, account.salt, account.iterations);
    if (!_constantTimeEquals(hash, account.hash)) {
      throw const AuthFailure(KimlikKodu.hataliGiris);
    }
    return account;
  }

  /// Oturum belirteci üret. 32 rastgele bayt — tahmin edilebilir bir belirteç,
  /// parolayı korumanın tamamını boşa çıkarır.
  ///
  /// Aynı hesabın ÖNCEKİ belirteci geçersizleşir: bir hesabın aynı anda tek
  /// geçerli belirteci olur. Bu, "hesap başına tek oturum" kuralının depo
  /// tarafındaki yarısı — [Gateway] soketi düşürür, burası anahtarı iptal eder.
  String issueToken(Account account) {
    final previous = _tokenOfAccount[account.id];
    if (previous != null) _tokens.remove(previous);

    final token = base64Url.encode(_bytes(32));
    _tokens[token] = _Session(account, DateTime.now().toUtc().add(tokenTtl));
    _tokenOfAccount[account.id] = token;
    return token;
  }

  /// Belirtecin hesabı. Süresi dolmuşsa `null` — ve kayıt da silinir.
  Account? accountFor(String token) {
    final session = _tokens[token];
    if (session == null) return null;
    if (DateTime.now().toUtc().isAfter(session.expiresAt)) {
      _tokens.remove(token);
      _tokenOfAccount.remove(session.account.id);
      return null;
    }
    return session.account;
  }

  void revoke(String token) {
    final session = _tokens.remove(token);
    if (session != null) _tokenOfAccount.remove(session.account.id);
  }

  /// Süresi dolmuş belirteçleri temizler.
  ///
  /// [accountFor] tembel temizlik yapıyor ama yalnız SORULAN belirteci
  /// görebiliyor: bir daha hiç kullanılmayan belirteç sonsuza kadar kalırdı.
  /// Sunucu haftalarca ayakta duran bir süreç, ve sızıntının ölçüsü giriş
  /// sayısıdır.
  int sweepExpiredTokens() {
    final now = DateTime.now().toUtc();
    final dead = [
      for (final entry in _tokens.entries)
        if (now.isAfter(entry.value.expiresAt)) entry.key,
    ];
    for (final token in dead) {
      revoke(token);
    }
    return dead.length;
  }

  /// Geçerli belirteç sayısı — sızıntıyı testte ölçebilmek için.
  int get tokenCount => _tokens.length;

  Uint8List _bytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  /// Parola türetmesi AYRI BİR ISOLATE'te.
  ///
  /// Bu sunucunun ana isolate'i oyun tikini koşuyor. 120 bin turluk bir
  /// PBKDF2 orada çalışsaydı ~100 ms boyunca dünya DURURDU — tek bir giriş
  /// denemesi üç tik düşürürdü. Yavaşlığın parola için özellik, oyun döngüsü
  /// için felaket olması bu ayrımı zorunlu kılıyor.
  static Future<Uint8List> _derive(
    String password,
    Uint8List salt,
    int iterations,
  ) => Isolate.run(() => _pbkdf2(password, salt, iterations, _keyBytes));

  /// PBKDF2-HMAC-SHA256 (RFC 8018). Tek bloklu: [length] 32 bayt.
  static Uint8List _pbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    // İlk tur: HMAC(parola, tuz ‖ blok numarası)
    final block = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..[salt.length + 3] = 1;

    var current = Uint8List.fromList(hmac.convert(block).bytes);
    final result = Uint8List.fromList(current);
    for (var i = 1; i < iterations; i++) {
      current = Uint8List.fromList(hmac.convert(current).bytes);
      for (var j = 0; j < result.length; j++) {
        result[j] ^= current[j];
      }
    }
    return Uint8List.view(result.buffer, 0, length);
  }

  /// Sabit zamanlı karşılaştırma.
  ///
  /// `==` ilk farklı baytta döner ve dönüş süresi kaç baytın tuttuğunu
  /// sızdırır; yeterince deneme ile hash bayt bayt bulunabilir.
  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
