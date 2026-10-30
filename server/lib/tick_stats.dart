import 'dart:typed_data';

/// Tik maliyetinin DAĞILIMI — ortalama değil.
///
/// **Neden ortalama yetmiyor.** Kapasite ölçümünde ortalama, cevaplamamız
/// gereken soruyu cevaplamıyor. "Tik ortalama 6 ms" cümlesi, tiklerin
/// yüzde birinin 40 ms sürdüğü bir sunucuda da doğrudur — ve oyuncunun
/// hissettiği şey tam olarak o yüzde bir. Saniyede 30 tikte %1, dakikada 18
/// takılma demek.
///
/// Pencere TEPESİ de yetmiyor: tek bir örnek, gürültü. Bir koşuda 40 ms, bir
/// sonrakinde 12 ms çıkar ve hangisinin gerçek olduğu anlaşılmaz. p99 ise
/// pencere büyüdükçe kararlı hâle gelir.
///
/// **Neden kova.** Her tik süresini saklayıp sıralamak tahsis demek ve bu kod
/// tik döngüsünün İÇİNDE çalışıyor. 100 µs çözünürlüklü sabit bir sayaç
/// dizisi tahsissiz: `add` bir bölme ve bir artırma.
///
/// Yüzdelikler kovanın ÜST kenarını döndürüyor — yani rapor edilen değer
/// gerçek değerden en çok 100 µs büyük. Kapasite kararında bu yön doğru
/// yöndür: iyimser değil kötümser yanılıyoruz.
class LatencyHistogram {
  /// Kova genişliği (µs). 100 µs, 33.333 µs'lik bütçenin binde üçü.
  static const int bucketMicros = 100;

  /// Kova sayısı → 0–102.4 ms doğrudan kaydediliyor. Bütçenin üç katı;
  /// bunun üstü zaten "sunucu koşamıyor" bölgesi ve orada çözünürlük değil
  /// yalnız sayı önemli.
  static const int buckets = 1024;

  final Int32List _counts = Int32List(buckets);

  /// Kovaların dışına taşan tikler. Ayrı sayılıyor çünkü onları son kovaya
  /// yığmak p99'u sessizce 102 ms'de kilitlerdi.
  int _overflow = 0;

  int _count = 0;
  int _sum = 0;
  int _max = 0;

  int get count => _count;
  int get max => _max;

  /// Kovaların dışına taşan (>102.4 ms) tik sayısı.
  ///
  /// Ayrı raporlanıyor çünkü bunlar artık "yavaş tik" değil DURMA: 102 ms,
  /// üç tiklik bütçe. Bir tanesi bile oyuncuda görünür bir takılmadır ve
  /// yüzdelik içinde kaybolmamalı.
  int get overflow => _overflow;
  double get mean => _count == 0 ? 0 : _sum / _count;

  void add(int micros) {
    if (micros < 0) return;
    _count++;
    _sum += micros;
    if (micros > _max) _max = micros;
    final bucket = micros ~/ bucketMicros;
    if (bucket >= buckets) {
      _overflow++;
      return;
    }
    _counts[bucket]++;
  }

  /// [p] 0..1 arası yüzdelik (0.99 = p99), µs cinsinden.
  ///
  /// Taşan tikler dağılımın EN ÜSTÜNDE sayılıyor ve değerleri bilinmiyor; o
  /// bölgeye düşen bir yüzdelik için [max] döndürülüyor. Uydurma bir ara
  /// değer vermektense ölçülmüş en kötü değeri vermek dürüst olan.
  int percentile(double p) {
    if (_count == 0) return 0;
    final rank = (p * _count).ceil().clamp(1, _count);
    var seen = 0;
    for (var i = 0; i < buckets; i++) {
      seen += _counts[i];
      if (seen >= rank) return (i + 1) * bucketMicros;
    }
    return _max;
  }

  void reset() {
    _counts.fillRange(0, buckets, 0);
    _overflow = 0;
    _count = 0;
    _sum = 0;
    _max = 0;
  }

  /// `p50 5.1 · p95 11.2 · p99 18.4 · max 41.0 ms` biçiminde.
  String format() {
    String ms(int micros) => (micros / 1000).toStringAsFixed(1);
    final tail = _overflow > 0 ? ' · ⚠ $_overflow tik >102 ms' : '';
    return 'p50 ${ms(percentile(0.50))} · p95 ${ms(percentile(0.95))} · '
        'p99 ${ms(percentile(0.99))} · max ${ms(_max)} ms$tail';
  }
}
