import 'package:shared_preferences/shared_preferences.dart';

import '../net/token_store.dart';

/// Belirteci uygulama kumbarasında tutan depo.
///
/// **Neden anahtarlık (Keychain/Keystore) değil.** Belirteç bir parola değil:
/// on iki saat ömürlü, sunucu tarafından iptal edilebilir, ve yeni bir giriş
/// eskisini geçersiz kılıyor. Depo zaten uygulamaya özel — başka bir uygulama
/// okuyamaz. Anahtarlık daha güçlü olurdu ama yerel bir eklenti daha, üç
/// platformda ayrı davranışlar ve Android'de bilinen sorunlar demek.
/// Korunan şeyin değerine göre orantısız.
///
/// Parola BURAYA HİÇ yazılmıyor ve yazılmamalı; o farklı bir karar olurdu.
class PrefsTokenStore implements TokenStore {
  static const String _key = 'voidspace.session.token';

  @override
  Future<String?> read() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } on Object {
      // Depo okunamıyorsa (kurumsal kısıt, bozuk kumbara) belirteç yok sayılır
      // ve oyuncuya parola sorulur. Açılışı ENGELLEMEK doğru olmaz.
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, token);
    } on Object {
      // Yazamadıysak oyuncu bir dahakine parola girer — oyunu durdurmaz.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } on Object {
      // yok sayılır
    }
  }
}
