@Tags(['disi'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_server/accounts.dart';

/// Hesapların sözleşmesi.
///
/// Buradaki testlerin yarısı bir davranışı değil bir SALDIRIYI kapatıyor:
/// parolanın diskte durmaması, kullanıcı adı sayımının engellenmesi,
/// büyük/küçük harfle taklit edilememesi. Kimlik kodunda "sonra düzeltiriz"
/// diye bırakılan şey düzeltilmiyor, sızıyor.
void main() {
  late Directory temp;
  late AccountStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('voidspace_accounts');
    store = AccountStore(path: '${temp.path}/accounts.json');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Future<Account> register([String name = 'Ada']) => store.register(
    email: '$name@ornek.com',
    username: name,
    password: 'yeterince-uzun-parola',
  );

  group('kayıt', () {
    test('hesap oluşur ve giriş yapılabilir', () async {
      final account = await register();
      expect(account.username, 'Ada');
      expect(store.count, 1);

      final again = await store.login(
        usernameOrEmail: 'Ada',
        password: 'yeterince-uzun-parola',
      );
      expect(again.id, account.id);
    });

    test('kullanıcı adı BÜYÜK/küçük harften bağımsız benzersiz', () async {
      await register('Ada');
      // "ada" ile kayıt olunabilseydi HUD'da iki ayırt edilemez oyuncu olurdu
      // ve taklit bedava hâle gelirdi.
      expect(
        () => store.register(
          email: 'baska@ornek.com',
          username: 'ada',
          password: 'yeterince-uzun-parola',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('aynı e-posta ikinci kez kullanılamaz', () async {
      await register('Ada');
      expect(
        () => store.register(
          email: 'ADA@ornek.com',
          username: 'Bora',
          password: 'yeterince-uzun-parola',
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('geçersiz alanlar ORTAK kurallarla reddedilir', () async {
      Future<void> expectFail(String email, String user, String pass) =>
          expectLater(
            () => store.register(email: email, username: user, password: pass),
            throwsA(isA<AuthFailure>()),
          );

      await expectFail('gecersiz', 'Ada', 'yeterince-uzun-parola');
      await expectFail('a@b.com', 'ab', 'yeterince-uzun-parola'); // kısa ad
      await expectFail(
        'a@b.com',
        'Ada Bora',
        'yeterince-uzun-parola',
      ); // boşluk
      await expectFail('a@b.com', 'Ada', 'kısa'); // kısa parola
    });
  });

  group('giriş', () {
    test('yanlış parola reddedilir', () async {
      await register();
      expect(
        () => store.login(usernameOrEmail: 'Ada', password: 'yanlis-parola'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('e-posta ile de girilebilir', () async {
      await register();
      final account = await store.login(
        usernameOrEmail: 'ada@ORNEK.com',
        password: 'yeterince-uzun-parola',
      );
      expect(account.username, 'Ada');
    });

    test('olmayan hesap ile yanlış parola AYNI sebebi döner', () async {
      await register();
      // Farklı sebepler dönseydi, hangi kullanıcı adlarının var olduğu tek tek
      // öğrenilebilirdi.
      final missing = await _reasonOf(
        () => store.login(usernameOrEmail: 'YokBoyle', password: 'bir-parola'),
      );
      final wrong = await _reasonOf(
        () => store.login(usernameOrEmail: 'Ada', password: 'bir-parola'),
      );
      expect(missing, wrong);
    });
  });

  group('depolama', () {
    test('parola DİSKTE düz metin durmaz', () async {
      await register();
      final raw = File('${temp.path}/accounts.json').readAsStringSync();
      expect(raw, isNot(contains('yeterince-uzun-parola')));
      // Tuz ve türetilmiş anahtar var, parola yok.
      //
      // Biçim satır başına bir hesap (JSON Lines) — tek bir dizi değil.
      // Sebep ölçüm: diziyi her kayıtta baştan kodlamak 20.000 hesapta
      // 29 ms sürüyordu ve `jsonEncode` eşzamanlı, yani oyun tikini bloklardı.
      final entry =
          jsonDecode(const LineSplitter().convert(raw).first)
              as Map<String, Object?>;
      expect(entry.containsKey('salt'), isTrue);
      expect(entry.containsKey('hash'), isTrue);
      expect(entry.containsKey('password'), isFalse);
    });

    test('ESKİ dizi biçimi okunur ve yeni biçime geçer', () async {
      // Bu değişiklik yayınlanmış bir sunucunun hesap dosyasını bulabilir.
      // "Biçim değişti" gerekçesiyle gerçek oyuncuları silmek kabul edilemez,
      // o yüzden eski biçim okunmaya devam ediyor ve ilk fırsatta dönüştürülüyor.
      final file = File('${temp.path}/accounts.json');
      const legacy =
          '[{"id":"eski-1","email":"cinar@test.local","username":"CINAR",'
          '"salt":"uCLQDW1ppQc1pDKRNNStqg==",'
          '"hash":"KlnhHujNcWkY8YOzq1C3NQQM0f8i6IhHUr6EWm0FA48=",'
          '"iterations":120000,"createdAt":"2026-08-29T21:51:41.078664Z"}]';
      file.writeAsStringSync(legacy);

      final store = AccountStore(path: file.path);
      await store.load();
      expect(store.count, 1, reason: 'eski hesap kayboldu');

      // Dosya artık satır biçiminde ve hesap hâlâ orada.
      final rewritten = file.readAsStringSync();
      expect(rewritten.trimLeft().startsWith('['), isFalse);
      final again = AccountStore(path: file.path);
      await again.load();
      expect(again.count, 1);
    });

    test('kayıt dosyayı BAŞTAN yazmaz, satır EKLER', () async {
      // Bütün listeyi yeniden kodlamak 20.000 hesapta 29 ms sürüyordu ve
      // `jsonEncode` eşzamanlı — yani o sırada oynayan HERKES bir kare
      // kaybederdi. Bu test maliyeti ölçmüyor (ölçüm kırılgan olurdu),
      // EKLEME anlamını kilitliyor: ilk satır bayt bayt aynı kalmalı.
      await register('Ada');
      final file = File('${temp.path}/accounts.json');
      final firstLine = const LineSplitter().convert(file.readAsStringSync())
        ..removeWhere((l) => l.trim().isEmpty);
      await register('Bora');
      final lines = const LineSplitter()
          .convert(file.readAsStringSync())
          .where((l) => l.trim().isNotEmpty)
          .toList();

      expect(lines.length, 2);
      expect(
        lines.first,
        firstLine.first,
        reason: 'ilk hesap yeniden yazıldı — ekleme değil, baştan yazma',
      );
    });

    test('bozuk son satır DEPOYU okunamaz yapmaz', () async {
      // Süreç yazarken ölürse yarım bir satır kalabilir. Onun yüzünden bütün
      // hesapları kaybetmek, korumaya çalıştığımız şeyi kaybetmek olurdu.
      await register('Ada');
      final file = File('${temp.path}/accounts.json');
      file.writeAsStringSync('{"id":"yarim","userna', mode: FileMode.append);

      final store = AccountStore(path: file.path);
      await store.load();
      expect(store.count, 1, reason: 'sağlam hesap da kayboldu');
    });

    test('aynı parola iki hesapta FARKLI hash üretir', () async {
      // Tuz olmasaydı aynı parolalar aynı hash'i verirdi ve tek bir gökkuşağı
      // tablosu bütün hesapları birden açardı.
      final a = await register('Ada');
      final b = await register('Bora');
      expect(a.hash, isNot(b.hash));
      expect(a.salt, isNot(b.salt));
    });

    test('yeniden yüklenince hesaplar durur', () async {
      await register();
      final reloaded = AccountStore(path: '${temp.path}/accounts.json');
      await reloaded.load();
      expect(reloaded.count, 1);
      final account = await reloaded.login(
        usernameOrEmail: 'Ada',
        password: 'yeterince-uzun-parola',
      );
      expect(account.username, 'Ada');
    });
  });

  group('belirteç', () {
    test('üretilir, çözülür, iptal edilir', () async {
      final account = await register();
      final token = store.issueToken(account);
      expect(store.accountFor(token)?.id, account.id);
      store.revoke(token);
      expect(store.accountFor(token), isNull);
    });

    test('belirteçler tahmin edilebilir değil', () async {
      final account = await register();
      final tokens = {for (var i = 0; i < 20; i++) store.issueToken(account)};
      expect(tokens.length, 20, reason: 'belirteç tekrar ediyor');
      expect(tokens.every((t) => t.length >= 40), isTrue);
    });
  });

  test('hesap nesnesi parolayı günlüğe basmaz', () async {
    final account = await register();
    expect(account.toString(), 'Account(Ada)');
  });
}

Future<String> _reasonOf(Future<void> Function() action) async {
  try {
    await action();
    return '(hata yok)';
  } on AuthFailure catch (failure) {
    return failure.reason;
  }
}
