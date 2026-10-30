import '../net/sunucu_kodu.dart';

/// KİMLİK AKIŞININ HATA KİMLİKLERİ — telde metin değil KOD taşınır.
///
/// **Neden.** Sunucu üç dilde konuşamaz ve konuşmamalı: hangi dili
/// konuşacağını bilmek için oturumun diline bakması, oyuncunun tercihi
/// değişince ona uyması ve her metni üç kez taşıması gerekirdi. Oysa
/// sunucunun söylediği şey bir CÜMLE değil, bir OLAY: "bu kullanıcı adı
/// alınmış". Cümleyi kuran taraf, dili bilen taraf olmalı.
///
/// Kodlar KALICI. Bir kodu yeniden adlandırmak, eski bir istemcide o hatanın
/// çevrilemez hâle gelmesi demek; istemci tanımadığı kodu ham göstererek
/// düşüyor, yani hata kaybolmuyor ama okunaksızlaşıyor.
///
/// **Sayı taşımıyorlar.** "En az 8 karakter" mesajındaki sekiz, telden
/// gelmiyor — istemci [Credentials.passwordMin] değerini zaten biliyor, çünkü
/// kurallar bu pakette PAYLAŞILIYOR. Telde sayı taşımak, aynı gerçeği iki
/// yerden söylemek olurdu.
enum KimlikKodu {
  // ── Alan kuralları (`Credentials`) ──────────────────────────────────
  kullaniciKisa('kimlik.kullanici-kisa'),
  kullaniciUzun('kimlik.kullanici-uzun'),
  kullaniciBicim('kimlik.kullanici-bicim'),
  epostaGerekli('kimlik.eposta-gerekli'),
  epostaUzun('kimlik.eposta-uzun'),
  epostaBicim('kimlik.eposta-bicim'),
  parolaKisa('kimlik.parola-kisa'),
  parolaUzun('kimlik.parola-uzun'),

  // ── Hesap durumu ────────────────────────────────────────────────────
  kullaniciAlinmis('kimlik.kullanici-alinmis'),
  epostaAlinmis('kimlik.eposta-alinmis'),

  /// Kasten KABA TANELİ: hangisinin yanlış olduğunu söylemiyor. Söyleseydi
  /// bir saldırgan hangi kullanıcı adlarının var olduğunu tek tek öğrenirdi.
  hataliGiris('kimlik.hatali-giris'),

  /// Beklenmeyen sunucu arızası. Ayrıntı İSTEMCİYE dönmez (yığın izi bir
  /// haritadır); sunucu günlüğüne yazılır.
  sunucuHatasi('kimlik.sunucu-hatasi'),

  /// Deneme sınırı aşıldı — kaba kuvvete karşı.
  cokFazlaDeneme('kimlik.cok-fazla-deneme'),

  /// Belirteç eskidi: on iki saat doldu ya da yeni bir giriş onu geçersiz
  /// kıldı. `hataliGiris`ten AYRI — burada parola yanlış değil, oturum bitmiş.
  oturumDoldu('kimlik.oturum-doldu'),

  // ── El sıkışma reddi ────────────────────────────────────────────────
  sunucuDolu('kimlik.sunucu-dolu'),
  baskaCihaz('kimlik.baska-cihaz'),
  surumUyusmazligi('kimlik.surum');

  const KimlikKodu(this.kod);

  /// Telde ve günlükte görünen kararlı anahtar.
  final String kod;

  /// Tanınmayan kod `null` — istemci onu ham metin olarak gösteriyor.
  static KimlikKodu? koddan(String? kod) {
    if (kod == null) return null;
    for (final k in values) {
      if (k.kod == kod) return k;
    }
    return null;
  }

  /// Kodu, varsa argümanlarıyla tek dizeye yazar: `kod|arg|arg`.
  ///
  /// Argüman İSTİSNA, kural değil. Neredeyse her hata sayısız: "en az 8
  /// karakter" mesajındaki sekizi istemci zaten biliyor. Ama sürüm
  /// uyuşmazlığında iki sayı da KARŞI TARAFA ait — istemci sunucunun
  /// beklediği sürümü bilemez, çünkü tam olarak o bilgi ayrışmış durumda.
  String yaz([List<Object?> argumanlar = const []]) =>
      sunucuKoduYaz(kod, argumanlar);

  /// [yaz]'ın tersi. Tanınmayan dize `(null, [])` döner ve arayüz onu ham
  /// gösterir — bilinmeyen bir hata, kaybolan bir hatadan iyidir.
  static (KimlikKodu?, List<String>) coz(String? ham) {
    if (ham == null) return (null, const []);
    final (kod, argumanlar) = sunucuKoduCoz(ham);
    final kimlik = koddan(kod);
    return kimlik == null ? (null, const []) : (kimlik, argumanlar);
  }
}
