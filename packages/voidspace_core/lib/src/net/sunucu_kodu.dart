/// SUNUCUDAN GELEN METİNLERİN ORTAK BİÇİMİ — `kod|arg|arg`.
///
/// Sunucu oyuncuya cümle göndermiyor, OLAY gönderiyor: `gecit.br|4200`.
/// Cümleyi dili bilen taraf — istemci — kuruyor. Bu dosya yalnız o olayın
/// dizeye nasıl yazıldığını tanımlıyor; hangi olaylar olduğu `KimlikKodu` ve
/// [GecitKodu] gibi enum'larda.
///
/// **Argüman istisna, kural değil.** Çoğu sayı zaten istemcide var: kurallar
/// bu PAYLAŞILAN pakette duruyor. Argüman yalnız değeri sunucunun bildiği
/// yerlerde taşınıyor — geçidin eşiği gibi, çünkü eşiği sunucunun katalogu
/// belirliyor ve istemcinin okuduğu değer bir kare eski olabilir.
library;

/// Kodu, varsa argümanlarıyla tek dizeye yazar.
String sunucuKoduYaz(String kod, [List<Object?> argumanlar = const []]) =>
    argumanlar.isEmpty ? kod : '$kod|${argumanlar.join('|')}';

/// [sunucuKoduYaz]'ın tersi: `(kod, argümanlar)`.
///
/// Ayırıcı taşıyan bir argüman gelirse fazlası argüman listesinde kalıyor —
/// veri kaybolmuyor, yalnız bölünüyor. Bugün hiçbir argüman metin değil.
(String, List<String>) sunucuKoduCoz(String ham) {
  final parcalar = ham.split('|');
  return (parcalar.first, parcalar.skip(1).toList());
}

/// GEÇİT REDDİNİN KODLARI.
///
/// Geçit isteği sunucuda beş ayrı sebeple düşebiliyor ve oyuncunun hangisi
/// olduğunu bilmesi şart: "menzilde değilsin" gemiyi yaklaştırmakla,
/// "savaş puanı yetmiyor" donanım değiştirmekle çözülüyor. İkisini tek bir
/// "geçilemedi"ye indirmek, oyuncuyu ne yapacağını bilmeden bırakır.
enum GecitKodu {
  menzilDisi('gecit.menzil'),

  /// Argüman: gereken savaş puanı.
  brYetmiyor('gecit.br'),

  /// Argüman: gereken seviye.
  seviyeYetmiyor('gecit.seviye'),

  haritaDolu('gecit.harita-dolu'),
  basarisiz('gecit.basarisiz');

  const GecitKodu(this.kod);

  final String kod;

  String yaz([List<Object?> argumanlar = const []]) =>
      sunucuKoduYaz(kod, argumanlar);

  static GecitKodu? koddan(String? kod) {
    if (kod == null) return null;
    for (final g in values) {
      if (g.kod == kod) return g;
    }
    return null;
  }

  /// Tanınmayan dize `(null, [])` — arayüz onu ham gösteriyor.
  static (GecitKodu?, List<String>) coz(String? ham) {
    if (ham == null) return (null, const []);
    final (kod, argumanlar) = sunucuKoduCoz(ham);
    final gecit = koddan(kod);
    return gecit == null ? (null, const []) : (gecit, argumanlar);
  }
}
