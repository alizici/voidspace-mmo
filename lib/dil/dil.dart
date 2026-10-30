/// Oyunun konuştuğu diller.
///
/// **Neden bir enum, neden `Locale` değil.** Flutter'ın `Locale`'ü açık uçlu:
/// `pt_BR` da bir `Locale`, `zz` de. Açık uçlu bir tip, "bu dil için metin var
/// mı" sorusunu her çağrı yerine dağıtır. Kapalı bir enum ise soruyu bir kez
/// sorduruyor — cihazın dilini [cozumle] çözer, o noktadan sonra elde HER
/// metnin karşılığı bulunan bir değer var.
///
/// Kod ile ad AYRI: [kod] diske ve `Locale`'e giden kararlı anahtar, [ad] ise
/// dil seçicide görünen isim. Ad her dilde KENDİ dilinde yazılı ("Italiano",
/// "English") — dil seçen kişi seçtiği dili tanımak zorunda, seçmediği dili
/// değil.
enum Dil {
  turkce('tr', 'Türkçe'),
  ingilizce('en', 'English'),
  italyanca('it', 'Italiano');

  const Dil(this.kod, this.ad);

  /// ISO 639-1 kodu. Diske yazılan ve `Locale`'e verilen anahtar; [ad]'dan
  /// AYRI ve öyle kalmalı — görünen adı değiştirmek kayıtlı tercihi bozmasın.
  final String kod;

  /// Dil seçicide görünen, kendi dilindeki adı.
  final String ad;

  /// Karşılığı olmayan bir cihaz dilinde düşülen dil.
  ///
  /// Türkçe DEĞİL: oyun Türkçe yazıldı ama Türkçe bilmeyen birine Türkçe
  /// göstermek, hiç çeviri yapmamakla aynı sonucu verir. Bilinmeyen bir dil
  /// için en geniş ortak zemin İngilizce.
  static const Dil varsayilan = Dil.ingilizce;

  /// Kayıtlı ya da cihazdan gelen koddan dili çözer.
  ///
  /// `tr_TR`, `it-IT` gibi bölgeli kodlar da çalışıyor: yalnız ilk iki harfe
  /// bakılıyor. Tanınmayan kod [varsayilan]'a düşüyor — bozuk bir tercih
  /// dosyası oyunu açılmaz hâle getirmemeli.
  static Dil cozumle(String? kod) {
    if (kod == null || kod.length < 2) return varsayilan;
    final kisa = kod.substring(0, 2).toLowerCase();
    for (final d in values) {
      if (d.kod == kisa) return d;
    }
    return varsayilan;
  }
}
