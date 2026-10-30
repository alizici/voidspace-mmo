/// BEŞ TEST TÜRÜ — alan 16'nın sınıflandırması, kodda.
///
/// Her test dosyası türünü başında ilan ediyor (`@Tags([...])`), denetim
/// sayıyor ve haritaya basıyor. Tür sayımı bir zamanlar elle yapılıyordu ve
/// elle sayılan her şey eskir: sayı, sınıflandırma taşınmadığı için belgede
/// bayat bir cümle olarak kalıyordu.
///
/// Etiketler `dart test -t aralik` ile de çalışıyor: bir türü tek başına
/// koşturmak mümkün.
/// KARAR 16.1 s1
enum TestTuru {
  /// Atıf yapılan şey var mı: havuzdaki her stat kütüphanede mi.
  yabanciAnahtar('yabanci-anahtar', 'Yabancı anahtar'),

  /// Bir oran bandın içinde mi: A/D bandı, kalite bandı, TTK.
  aralik('aralik', 'Aralık'),

  /// Formülle mi geldi, elle mi yazıldı: en değerlisi. Bir sayı doğru ve
  /// elle yazılmış olabilir; üst alandaki girdi değişince sessizce bozulur.
  turetme('turetme', 'Türetme'),

  /// Hiçbir şey dışarıda kaldı mı: bant sayıları toplamı = rank sayısı.
  kapsam('kapsam', 'Kapsam'),

  /// Çalışan oyun belgeye uyuyor mu.
  kodBelge('kod-belge', 'Kod ↔ belge'),

  /// Alan 16'nın DIŞINDA: ağ, simülasyon, arayüz, güvenlik. Beş türden biri
  /// değil; sayım onları saymıyor, yalnız dışarıda bıraktığını biliyor.
  disi('disi', 'Denetim dışı');

  const TestTuru(this.etiket, this.ad);

  /// `@Tags` içindeki dize.
  final String etiket;

  /// Okunur ad.
  final String ad;

  /// Alan 16'nın beş türü — [disi] hariç.
  static List<TestTuru> get besi => values.where((t) => t != disi).toList();

  static TestTuru? parse(String etiket) {
    for (final t in values) {
      if (t.etiket == etiket) return t;
    }
    return null;
  }
}
