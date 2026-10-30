import 'dart:io';

import 'package:voidspace_server/accounts.dart';

/// TEK hesap açar — geliştirme kolaylığı.
///
///   dart run server/bin/hesap_ac.dart ELIANNE 12345678
///
/// Neden ayrı bir betik: hesap açmanın tek doğru yolu `AccountStore.register`
/// (parola türetmesi, kural denetimi, defter kaydı hep orada). Dosyayı elle
/// düzenlemek parola karmasını uydurmak demekti.
///
/// SUNUCU KAPALIYKEN çalıştırın: açıkken hesaplar bellekte tutuluyor ve
/// sunucunun ilk yazımı bu dosyayı geri alır.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('kullanım: dart run server/bin/hesap_ac.dart <ad> <parola>');
    exit(64);
  }
  final ad = args[0];
  final parola = args[1];
  final eposta = args.length > 2 ? args[2] : '${ad.toLowerCase()}@dev.local';
  final yol = Platform.environment['ACCOUNTS'] ?? 'data/accounts.json';

  final store = AccountStore(path: yol);
  await store.load();
  if (store.adiyla(ad) != null) {
    stdout.writeln('· $ad zaten var, dokunulmadı');
    return;
  }
  final hesap = await store.register(
    email: eposta,
    username: ad,
    password: parola,
  );
  stdout.writeln('✓ $ad açıldı (${hesap.id}) · $eposta · $yol');
}
