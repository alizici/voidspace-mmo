import 'dart:ui';

/// Ekrana düşen hasar sayısı.
///
/// Rengi bilgi taşır ve bu KASITLI: turuncu gövdeye, camgöbeği kalkana,
/// beyaz imhaya. Oyuncunun "kalkanı bitti mi" sorusunu HUD çubuğuna bakmadan
/// cevaplamasının tek yolu bu — dövüşün ortasında kimse çubuğa bakmıyor.
///
/// Kalkan rengi hedef kilidiyle AYNI aileden (mavi) ve mermilerden farklı
/// (turuncu): arayüz mavi, ateş turuncu.
class DamageLabel {
  DamageLabel({
    required this.amount,
    required this.tint,
    required this.fontSize,
    this.dim = false,
  });

  /// Kalkana inen hasar. `Palette.shield` ile aynı aile.
  static const shieldTint = Color(0xFF7FE3FF);

  /// Gövdeye inen hasar.
  static const hullTint = Color(0xFFFFAE3A);

  /// İmha eden vuruş — beyaz-sıcak, ve tek beyaz burada.
  static const killTint = Color(0xFFFFF3D2);

  /// KRİTİK — sarı ve iri.
  ///
  /// Kritiğin tek varlık sebebi bu rakam. Beklenen değerle oynanan bir oyunda
  /// kritik diye bir şey yoktur; oyuncunun kritiği YAŞAMASI, onu sıradan
  /// vuruştan ayıran bir renk ve bir boy demek. Kalkan/gövde ailesinden
  /// (mavi/turuncu) ayrı bir sarı: hangi havuza indiğinden bağımsız okunuyor.
  static const critTint = Color(0xFFFFE04A);

  static const double normalSize = 26;
  static const double critSize = 33;
  static const double killSize = 34;

  /// SIYIRMA rakamının alfa çarpanı.
  ///
  /// Iskalama olmadığı için oyuncuya "az hasar geçti" demenin tek yolu bu:
  /// mermi çarptı, rakam düştü, ama soluk. Sıfır bir rakam gösterip yalan
  /// söylemekten de, hiç göstermeyip sessiz kalmaktan da iyi.
  static const double dimFactor = 0.55;

  final int amount;
  final Color tint;
  final double fontSize;

  /// Sıyırma — rakam soluk çizilir.
  final bool dim;

  Paragraph? _cached;

  /// Solmayı ALFA KOVASINA yuvarlar.
  ///
  /// Metin dizgisi (paragraph layout) kare başına yapılacak kadar ucuz değil,
  /// ama `saveLayer` ile soldurmak da bu kadar küçük bir şey için gereksiz
  /// pahalı. Sekiz kova, sayının ömrü boyunca sekiz dizgi demek — ve
  /// göz sekiz kademeyi sürekli sanıyor.
  static const int _alphaSteps = 8;
  int _bucket = -1;

  /// Sayıyı [at] noktasına, merkezi hizalı çizer.
  void paint(Canvas canvas, Offset at, double opacity, double scale) {
    final bucket = (opacity.clamp(0.0, 1.0) * _alphaSteps).round();
    if (bucket <= 0) return;
    if (bucket != _bucket || _cached == null) {
      _bucket = bucket;
      _cached = _build(bucket / _alphaSteps);
    }
    final paragraph = _cached!;

    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(scale)
      ..drawParagraph(
        paragraph,
        Offset(-paragraph.longestLine / 2, -paragraph.height / 2),
      )
      ..restore();
  }

  Paragraph _build(double rawOpacity) {
    final opacity = dim ? rawOpacity * dimFactor : rawOpacity;
    final builder =
        ParagraphBuilder(
            ParagraphStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              textAlign: TextAlign.center,
            ),
          )
          ..pushStyle(
            TextStyle(
              color: tint.withValues(alpha: opacity),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              // Gölge ŞART: yıldız alanı ve gemi gövdesi üzerinde ince bir
              // rakam okunmaz. Koyu bir dış hat, sayıyı arka plandan bağımsız
              // kılan tek şey.
              shadows: [
                Shadow(
                  color: const Color(
                    0xFF000000,
                  ).withValues(alpha: 0.85 * opacity),
                  blurRadius: 5,
                ),
              ],
            ),
          )
          ..addText(amount.toString());
    return builder.build()..layout(const ParagraphConstraints(width: 220));
  }
}
