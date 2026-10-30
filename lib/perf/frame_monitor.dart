import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Kare süresi ölçer — UI ve raster AYRI.
///
/// Bu ayrım olmadan başarım tahmindir. "Oyun takılıyor" iki bambaşka sorunun
/// aynı belirtisidir ve çözümleri birbirinin tam tersidir:
///
///  * **UI (Dart) uzun** → simülasyon, tahsis, çöp toplama. Çözüm kod tarafında.
///  * **Raster (GPU) uzun** → çizim çağrısı sayısı, `saveLayer`, blur, doku
///    değişimi. Çözüm çizim tarafında.
///
/// Tarayıcıdaki `requestAnimationFrame` ölçümü ikisini tek sayıda topluyordu
/// ve hangisinin suçlu olduğunu söyleyemiyordu. `addTimingsCallback` motorun
/// kendi ölçümüdür; iki iş parçacığını ayrı verir.
///
/// Ölçerin kendisi bir kare bütçesi harcamaz: örnekler sabit boyutlu bir
/// halka tamponda `int` olarak birikir, istatistik yalnız [refreshInterval]'de
/// bir hesaplanır.
class FrameMonitor extends ChangeNotifier {
  FrameMonitor({this.window = 240, this.refreshInterval = 30});

  /// Ölçümü konsola da yazdır:
  /// `flutter run --release --dart-define=PERF_LOG=true`
  ///
  /// Cihazda ölçmenin en kısa yolu. HUD'daki satır insan içindir; bu, kaydı
  /// alınabilir ve karşılaştırılabilir olan.
  static const bool logToConsole = bool.fromEnvironment('PERF_LOG');

  /// Ölçümün alındığı EKRAN — günlüğe damgalanıyor.
  ///
  /// Sayı tek başına suçluyu söylemiyor: 26 ms'lik bir raster süresi savaşta
  /// başka bir şey, hangar menüsünde başka bir şey demek ve çözümleri ayrı
  /// yerlerde. Damgasız bir kayıtta bu ayrım ancak "ben o sırada neredeydim"
  /// diye hatırlamakla yapılabiliyordu — cihazda ölçüm alan kişi ise
  /// oynuyor, not tutmuyor.
  ///
  /// Yalnız GÜNLÜĞE giriyor, HUD satırına değil: oyuncunun ekranındaki satır
  /// zaten bulunduğu yeri gösteriyor.
  String baglam = 'oyun';

  /// Kaç karelik pencere üzerinden istatistik alınır. 240 kare, 120 Hz'de
  /// iki saniye — bir takılmanın yüzdesini anlamlı kılacak kadar uzun,
  /// değişimi geç göstermeyecek kadar kısa.
  final int window;

  /// Kaç karede bir dinleyiciler uyarılır. Her karede bildirmek, ölçerin
  /// kendisini ölçülen soruna dönüştürürdü.
  final int refreshInterval;

  late final Int32List _ui = Int32List(window);
  late final Int32List _raster = Int32List(window);
  late final Int32List _total = Int32List(window);

  int _cursor = 0;
  int _filled = 0;
  int _sinceNotify = 0;
  bool _running = false;

  /// ÜRETİLEN kare hızı — ekranın tazeleme hızı DEĞİL.
  ///
  /// İkisi karıştırılırsa menüdeki asıl bedel görünmez oluyor. Flutter bir
  /// oyun döngüsü değil: hiçbir şey kirlenmezse kare de üretmiyor. Yani duran
  /// bir menünün kare başına maliyeti değil, SANİYEDE KAÇ KARE ürettiği
  /// önemli — biri düşmeden öteki düşebilir.
  ///
  /// Bu ayrım pahalıya öğrenildi: menü animasyonu 30 Hz'e kısıldı ve kare
  /// BAŞINA GPU süresi hiç değişmedi (2,30 → 2,23 ms). Doğal olarak: kısma
  /// karelerin sayısını azaltır, birinin maliyetini değil. Ölçüde o sayı
  /// olmadığı için kısmanın işe yarayıp yaramadığı okunamıyordu.
  final Stopwatch _saat = Stopwatch();
  int _pencereKare = 0;
  double _uretilenFps = 0;

  /// Saniyede ÜRETİLEN kare. Duran bir menüde sıfıra yaklaşması beklenir;
  /// [refreshHz]'e yapışması, bir şeyin durmadan kare istediğini söyler.
  double get uretilenFps => _uretilenFps;

  // Son hesaplanan değerler (mikrosaniye).
  int uiP50 = 0;
  int uiP99 = 0;
  int rasterP50 = 0;
  int rasterP99 = 0;
  int totalP99 = 0;

  /// Bütçeyi aşan kare oranı (0..1).
  double jankRatio = 0;

  /// Ölçülen ekran tazeleme aralığı (mikrosaniye). Bütçe budur — 60 Hz'de
  /// 16667, 120 Hz'de 8333. Sabit varsaymak yerine ölçülüyor: aynı kod
  /// ProMotion'lı bir telefonda da 60 Hz'lik bir tablette de koşacak.
  int budgetMicros = 16667;

  double get refreshHz => 1e6 / budgetMicros;

  void start() {
    if (_running) return;
    _running = true;
    _saat
      ..reset()
      ..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    if (_running) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _running = false;
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _ui[_cursor] = t.buildDuration.inMicroseconds;
      _raster[_cursor] = t.rasterDuration.inMicroseconds;
      // `totalSpan` vsync'ten sunuma kadar geçen süre: oyuncunun gerçekten
      // hissettiği gecikme, iki iş parçacığının toplamı değil.
      _total[_cursor] = t.totalSpan.inMicroseconds;
      _cursor = (_cursor + 1) % window;
      if (_filled < window) _filled++;
    }
    _sinceNotify += timings.length;
    _pencereKare += timings.length;
    if (_sinceNotify < refreshInterval) return;
    _sinceNotify = 0;
    final gecen = _saat.elapsedMicroseconds;
    if (gecen > 0) _uretilenFps = _pencereKare * 1e6 / gecen;
    _pencereKare = 0;
    _saat
      ..reset()
      ..start();
    _recompute();
    if (logToConsole) debugPrint('[perf] $baglam · $summary');
    notifyListeners();
  }

  final List<int> _scratch = [];

  void _recompute() {
    if (_filled == 0) return;

    // Ekran hızını ÖLÇ: kare toplam süresinin medyanı, boşta koşan bir
    // uygulamada tazeleme aralığına oturur. Aşırı uçları dışlamak için
    // medyan, ortalama değil.
    final totalMedian = _percentile(_total, 0.5);
    budgetMicros = _nearestRefresh(totalMedian);

    uiP50 = _percentile(_ui, 0.5);
    uiP99 = _percentile(_ui, 0.99);
    rasterP50 = _percentile(_raster, 0.5);
    rasterP99 = _percentile(_raster, 0.99);
    totalP99 = _percentile(_total, 0.99);

    // Takılma tanımı: iki iş parçacığından BİRİ bütçeyi aştıysa kare düştü.
    var janky = 0;
    for (var i = 0; i < _filled; i++) {
      if (_ui[i] > budgetMicros || _raster[i] > budgetMicros) janky++;
    }
    jankRatio = janky / _filled;
  }

  /// Ölçülen medyanı bilinen tazeleme hızlarına yuvarlar. Ham medyan gürültülü
  /// olabiliyor; bütçenin sabit bir sayı olması karşılaştırmayı anlamlı kılıyor.
  static int _nearestRefresh(int micros) {
    const known = [8333, 11111, 16667, 33333]; // 120, 90, 60, 30 Hz
    var best = known.first;
    var bestDelta = (micros - best).abs();
    for (final candidate in known) {
      final delta = (micros - candidate).abs();
      if (delta < bestDelta) {
        best = candidate;
        bestDelta = delta;
      }
    }
    return best;
  }

  int _percentile(Int32List source, double p) {
    _scratch
      ..clear()
      ..addAll(source.take(_filled))
      ..sort();
    return _scratch[(_scratch.length * p).floor().clamp(
      0,
      _scratch.length - 1,
    )];
  }

  /// Ölçümün ÜRETİLDİĞİ sahne — kaç gemi, kaç mermi.
  ///
  /// Bir kare süresi, onu üreten sahne bilinmeden anlamsız: "GPU 1 ms" boş bir
  /// ekranda övünç değil. Bu not, ölçümü kendi kendini doğrular hâle getiriyor.
  ///
  /// METİN DEĞİL SAYILAR: ölçüm ekranda kalıcı olduğu için çevrilmek zorunda
  /// (bkz. `_FrameStats`), ve bu katman oyuncunun dilini bilmiyor. Cümleyi
  /// dili bilen taraf kuruyor; burası yalnız sayıyor.
  SahneOlcumu? sahne;

  /// Ölçümün DİLSİZ kısmı — süreler, tazeleme hızı. Sayılar ve birim
  /// kısaltmaları her dilde aynı.
  String get olculer =>
      'UI ${_ms(uiP50)}/${_ms(uiP99)} · GPU ${_ms(rasterP50)}/${_ms(rasterP99)}'
      ' · ${uretilenFps.toStringAsFixed(0)}/${refreshHz.round()}fps';

  /// Tek satırlık özet — GÜNLÜK için, ekran için değil.
  ///
  /// Günlük operatöre yazılıyor, oyuncuya değil: burası Türkçe kalıyor.
  ///
  /// HAVADAKİ MERMİ de yazılıyor ve bir süs değil: uçan merminin çizimi
  /// iki `MaskFilter.blur` taşıyor (hale ve burun) ve blur mobil GPU'da
  /// pahalı. Raster süresi havadaki mermiyle birlikte tırmanıyorsa suçlu
  /// orada; tırmanmıyorsa mermi aklanıyor ve başka yere bakılır. Sayıyı
  /// günlüğe koymadan bu iki ihtimal ayırt edilemiyordu.
  String get summary =>
      '$olculer · takılma %${(jankRatio * 100).toStringAsFixed(1)}'
      '${sahne == null ? '' : ' · ${sahne!.gemi} gemi · ${sahne!.alien} alien'
                ' · ${sahne!.havada} mermi'}';

  static String _ms(int micros) => (micros / 1000).toStringAsFixed(1);
}

/// Bir karenin ÜRETİLDİĞİ sahnenin sayıları.
///
/// Kayıt (record) değil sınıf: alanların adı çağrı yerinde okunuyor ve yedi
/// tane `int`i sırayla geçirmek, birini yer değiştirmenin sessizce yanlış bir
/// ölçüm ürettiği bir imza olurdu.
class SahneOlcumu {
  const SahneOlcumu({
    required this.gemi,
    required this.alien,
    required this.alinan,
    required this.tuketilen,
    required this.mermiSn,
    required this.vurusSn,
    required this.havada,
  });

  final int gemi;
  final int alien;
  final int alinan;
  final int tuketilen;
  final int mermiSn;
  final int vurusSn;
  final int havada;
}
