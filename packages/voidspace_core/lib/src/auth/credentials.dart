import 'kimlik_kodu.dart';

/// Hesap alanlarının kuralları — sunucu ve istemcinin PAYLAŞTIĞI tek gerçek.
///
/// İki tarafta da doğrulanmak zorunda ve sebepleri farklı:
///  * **İstemci** anında geri bildirim için doğrular (kullanıcı yazarken).
///  * **Sunucu** OTORİTE olduğu için doğrular — istemci doğrulaması bir
///    kolaylık, bir güvenlik önlemi değil; düzenlenmiş bir istemci hiçbir
///    kontrolden geçmez.
///
/// Kuralların burada, ortak pakette durması bu ikisinin ayrışmasını imkânsız
/// kılıyor. Ayrışsalardı istemcinin kabul ettiği bir parolayı sunucu reddeder
/// ve kullanıcı sebebini asla göremezdi.
abstract final class Credentials {
  static const int usernameMin = 3;
  static const int usernameMax = 16;

  /// Parola alt sınırı.
  ///
  /// Uzunluk, karmaşıklık kurallarından daha etkilidir: "en az bir büyük harf,
  /// bir rakam, bir sembol" kuralları insanları `Parola1!` yazmaya iter.
  static const int passwordMin = 8;
  static const int passwordMax = 128;

  static const int emailMax = 254;

  /// Harf, rakam, alt çizgi. Boşluk ve noktalama YOK: ad hem HUD'da çizilecek
  /// hem de benzersizlik anahtarı olacak, ikisi de sürprizi kaldırmaz.
  static final RegExp _username = RegExp(r'^[A-Za-z0-9_]+$');

  /// Kasıtlı olarak GEVŞEK.
  ///
  /// E-posta adresinin gerçekten geçerli olup olmadığını tek doğrulama yolu
  /// oraya posta göndermektir; regex ile "doğrulamak" yalnız geçerli adresleri
  /// reddetmeye yarar (tireli alan adları, yeni uzantılar, artı işaretli
  /// takma adlar). Buradaki kontrol yazım hatasını yakalar, kimlik kanıtlamaz.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Kullanıcı adı geçerliyse `null`, değilse sebebin KODU.
  ///
  /// Metin değil kod: bu paket sunucuyla paylaşılıyor ve sunucunun bir dili
  /// yok (bkz. [KimlikKodu]). Cümleyi kuran taraf istemci.
  static KimlikKodu? checkUsername(String value) {
    final v = value.trim();
    if (v.length < usernameMin) return KimlikKodu.kullaniciKisa;
    if (v.length > usernameMax) return KimlikKodu.kullaniciUzun;
    if (!_username.hasMatch(v)) return KimlikKodu.kullaniciBicim;
    return null;
  }

  static KimlikKodu? checkEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return KimlikKodu.epostaGerekli;
    if (v.length > emailMax) return KimlikKodu.epostaUzun;
    if (!_email.hasMatch(v)) return KimlikKodu.epostaBicim;
    return null;
  }

  static KimlikKodu? checkPassword(String value) {
    if (value.length < passwordMin) return KimlikKodu.parolaKisa;
    if (value.length > passwordMax) {
      // Üst sınır güvenlik içindir: parola yavaş bir türetme fonksiyonundan
      // geçiyor ve sınırsız uzunluk, tek istekle CPU yakmanın yolu olurdu.
      return KimlikKodu.parolaUzun;
    }
    return null;
  }

  /// Benzersizlik anahtarı. Büyük/küçük harf ve kenar boşlukları normalize
  /// edilir: "Ada", "ada " ve "ADA" AYNI hesap olmalı, yoksa taklit kolaylaşır.
  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String normalizeEmail(String value) => value.trim().toLowerCase();
}
