import '../design/tasarim_girdileri.dart';

/// UNVAN İSİMLERİ VE ÇAĞLAR — 10.4.
///
/// Dört çağ, her çağda beş unvan: yirmi ad. Yüz yirmi basamak ada altışar
/// kademe veriyor (I–VI). Eşikler 10.3'ün, isimler buranın; isim ucuz, eşik
/// pahalı — ikisi ayrı durur.
///
/// Uçlar belgeden: Squire … Duke, … Deity, Starcaller … Vortex, … Star
/// Marshal ve Star Lord. Aradaki on iki ad ilk yerleşim (borç defteri B11);
/// değiştirmek bedava, çünkü hiçbir kayıt ada bağlı değil, indekse bağlı.
/// KARAR 10.4 s2
abstract final class Unvan {
  static const List<String> caglar = [
    'Asalet',
    'Kutsallık',
    'Yıldız',
    'Ölümsüzlük',
  ];

  static const List<String> adlar = [
    // Asalet
    'Squire', 'Knight', 'Baron', 'Count', 'Duke',
    // Kutsallık
    'Acolyte', 'Cleric', 'Bishop', 'Saint', 'Deity',
    // Yıldız
    'Starcaller', 'Comet', 'Pulsar', 'Nebula', 'Vortex',
    // Ölümsüzlük
    'Phoenix', 'Titan', 'Immortal', 'Star Marshal', 'Star Lord',
  ];

  static const List<String> _roma = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
  ];

  /// Çağ başına ad — beş.
  static int get cagBasinaAd => adlar.length ~/ caglar.length;

  /// Ad başına basamak — yüz yirmi bölü yirmi, altı.
  static int get adBasinaBasamak =>
      TasarimGirdileri.unvanSayisi ~/ adlar.length;

  /// [indeks] (0..119) → hangi AD (0..19). Amblem kataloğunun sırası da bu.
  static int adIndeksi(int indeks) {
    _denetle(indeks);
    return indeks ~/ adBasinaBasamak;
  }

  /// [indeks] (0..119) → adın içindeki KADEME (0..5, I–VI).
  static int kademe(int indeks) {
    _denetle(indeks);
    return indeks % adBasinaBasamak;
  }

  /// [indeks] (0..119) → ÇAĞ sırası (0..3).
  static int cagIndeksi(int indeks) =>
      adIndeksi(indeks) ~/ cagBasinaAd;

  /// Kademenin roma rakamı — göstergeler için tek başına.
  static String roma(int kademe) => _roma[kademe.clamp(0, adBasinaBasamak - 1)];

  /// [indeks] numaralı unvanın adı: `Squire III`.
  static String adi(int indeks) =>
      '${adlar[adIndeksi(indeks)]} ${_roma[kademe(indeks)]}';

  /// [indeks] numaralı unvanın çağı.
  static String cagi(int indeks) => caglar[cagIndeksi(indeks)];

  static void _denetle(int indeks) {
    if (indeks < 0 || indeks >= TasarimGirdileri.unvanSayisi) {
      throw ArgumentError.value(indeks, 'indeks', 'aralık dışı');
    }
  }
}
