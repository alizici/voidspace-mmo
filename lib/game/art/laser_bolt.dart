import 'dart:math';
import 'dart:ui';

/// Bir lazer MERMİSİNİN görsel tasarımı — ışın değil, uçan cisim.
///
/// **Neden ışın değil.** Sürekli çizgi bedava görünür ama iki şeyi birden
/// öldürür: atışın TEMPOSUNU (bir yaylımın nerede başlayıp bittiği
/// anlaşılmaz) ve MESAFEYİ (çizgi anında varır, uzak hedef yakın hedefle aynı
/// hissettirir). Uçan mermi ikisini de geri veriyor — ve hasar sayısının
/// çarpma ANINDA çıkmasını mümkün kılan tek şey de bu.
///
/// **Neden atlasa girmiyor.** Gemi atlasa girdi çünkü kare başına `saveLayer`
/// + blur taşıyordu. Mermi öyle değil: sabit boyda, tek yönde çizilen küçük
/// bir kapsül. Onu pişirmek her uzunluk ve her açı için ayrı kare isterdi —
/// yani atlasın kazandırdığından fazlasını harcardı.
///
/// Mermi +x boyunca, MERKEZİ orijinde olacak şekilde çizilir; burun `+length/2`.
/// Döndürmeyi çağıran yapar.
class BoltArt {
  BoltArt({
    required this.id,
    required this.halo,
    required this.body,
    required this.hot,
    required this.speed,
    this.length = 34,
    this.width = 6.6,
  }) {
    _hl = length / 2;

    // Gövde bir KAPSÜL DEĞİL damla. Kapsül denendi ve düz kırmızı bir hap
    // gibi okundu: iki ucu da aynı genişlikte olan bir cisim hareket etmiyor,
    // duruyor. Sivri kuyruk + yuvarlak burun, mermiye yön veriyor.
    final nose = _hl + width * 0.34;
    _body = Path()
      ..moveTo(-_hl, 0)
      ..cubicTo(
        -_hl * 0.35,
        -width * 0.34,
        _hl * 0.2,
        -width * 0.5,
        _hl * 0.62,
        -width * 0.5,
      )
      ..quadraticBezierTo(nose, -width * 0.34, nose, 0)
      ..quadraticBezierTo(nose, width * 0.34, _hl * 0.62, width * 0.5)
      ..cubicTo(_hl * 0.2, width * 0.5, -_hl * 0.35, width * 0.34, -_hl, 0)
      ..close();

    _bodyPaint = Paint()
      ..blendMode = BlendMode.plus
      // Kuyruk ŞEFFAF başlar: sert kesilen bir arka uç, merminin uçtuğunu
      // değil bir çubuğun kaydığını gösterir.
      ..shader = Gradient.linear(
        Offset(-_hl, 0),
        Offset(nose, 0),
        [halo.withValues(alpha: 0), halo, body, hot],
        const [0.0, 0.42, 0.82, 1.0],
      );

    // Parıltı AYNI şeklin bulanığı — ayrı bir kapsül çizmek, merminin
    // etrafına ondan bağımsız bir hale koyuyordu ve o hale hareket etmiyordu.
    _haloPaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = halo.withValues(alpha: 0.62)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Beyaz KARNEYE bağlı: yalnız burun cebi ve filaman oraya ulaşır. Gövdenin
    // tamamı beyaza çıksaydı mermi bir çizgiye düşer ve motor alevinden
    // ayrışmazdı.
    _filamentRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(_hl * 0.1, -width * 0.13, _hl * 0.94, width * 0.13),
      Radius.circular(width * 0.13),
    );
    _filamentPaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = hot.withValues(alpha: 0.9);

    _nose = Offset(_hl * 0.86, 0);
    // Haç merminin ENİYLE ölçekli: PL-4'te 6,5 ve 4,2 (eski sabitler), droid
    // mermisinde onun yarısı. Sabit kalsaydı küçük mermide haç gövdeden taşar
    // ve mermi bir yıldıza dönerdi.
    _flareX = width * 0.985;
    _flareY = width * 0.636;
    _nosePaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = halo
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    _noseCorePaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = hot;

    // Objektif haçı: aşırı parlaklığın işareti. İki ince çizgi, blur yok.
    _flarePaint = Paint()
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = hot.withValues(alpha: 0.55);

    _nodePaint = Paint()..blendMode = BlendMode.plus;
  }

  /// PL-4 — hattın standart namlusu.
  ///
  /// Renk kanonik: kızıl-turuncu bir cisim, altın-beyaz burun. Motorun lav
  /// plumasıyla aynı aileden ama ondan iki noktada ayrılıyor — siluet SERT
  /// (pluma yumuşak ve geniş) ve DEĞER daha yüksek. Bu proje okumayı renk
  /// tonuna değil değer karşıtlığına yıktığı için ayrışmayı taşıyan şey bu.
  static final BoltArt pl4 = BoltArt(
    id: 'pl-4',
    halo: const Color(0xFFFF2A12),
    body: const Color(0xFFFF7A2E),
    hot: const Color(0xFFFFF3D2),
    // Dünya birimi/sn — eski projenin sayısı, BU projenin ölçeğine çevrilmiş.
    //
    // Orada mermi 1400, gemi 230 birim/sn koşuyordu: mermi gemiden 6.1 kat
    // hızlı. Burada gemi 320, yani aynı oran 1950 ediyor. Çeviriyi bu orandan
    // yapmak şart — çıplak 1400'ü taşımak, mermiyi bu projede gemiye göre
    // yavaşlatır ve kaçarak sıyrılmayı mümkün kılardı.
    //
    // Menzilin (1400) ucundaki hedefe 0.72 sn'de, tipik 600 birimlik dövüş
    // mesafesinde 0.31 sn'de varır. Daha hızlısı mermiyi ışına çevirir — ki
    // ışından kurtulmak için yola çıkmıştık.
    speed: 1950,
  );


  /// ROKET — geminin ikinci silahının mermisi (18.6).
  ///
  /// Lazer mermisinden üç şeyle ayrılıyor: iri (bir salvo beş namlunun
  /// toplamı kadar vuruyor, boyu onu söylemeli), yavaş (altı saniyede bir
  /// gelen bir vuruş bekleniyor, uçuşu okunmalı) ve rengi roketatarın: koyu
  /// turuncu gövde, beyaz burun. Aynı değer karşıtlığı, farklı silüet.
  static final BoltArt roket = BoltArt(
    id: 'roket',
    halo: const Color(0xFFFF6A1A),
    body: const Color(0xFFFFB066),
    hot: const Color(0xFFFFF6E6),
    speed: 1250,
    length: 46,
    width: 11,
  );

  /// `LaserStats.id` ile aynı — görselin sayısal tanıma çivilendiği yer.
  ///
  /// Bu alanın tek işi o çivi ve `laser_bolt_test.dart` onu kilitliyor:
  /// sayısal tanım ile görsel farklı lazeri adlandırırsa test düşüyor.
  ///
  /// Burada bir zamanlar `forLaser(String id)` fabrikası vardı ve iki dalı da
  /// aynı nesneyi döndürüyordu (`id == pl4.id ? pl4 : pl4`) — üstelik hiç
  /// çağrılmıyordu: iki gerçek tüketici doğrudan [pl4]'e gidiyor. Üçlü ifade,
  /// yordamın bir yer tutucu olduğunu gizliyordu.
  ///
  /// İkinci lazer geldiğinde (Hyperplasmoid, Magmadrill) burası bir haritaya
  /// dönüşecek. O gün gelene kadar var olmayan bir dağıtım noktası,
  /// olmayandan kötü: varmış gibi duruyor.
  final String id;

  final Color halo;
  final Color body;
  final Color hot;

  /// Dünya birimi/sn. Simülasyonda YOK: hasarı sunucu çözüyor, bu yalnız
  /// merminin ekranda ne kadar yol aldığı.
  final double speed;

  final double length;
  final double width;

  late final double _hl;
  late final Offset _nose;
  late final double _flareX;
  late final double _flareY;
  late final Path _body;
  late final Paint _bodyPaint;
  late final Paint _haloPaint;
  late final RRect _filamentRRect;
  late final Paint _filamentPaint;
  late final Paint _nosePaint;
  late final Paint _noseCorePaint;
  late final Paint _flarePaint;
  late final Paint _nodePaint;

  /// Mermiyi çizer. [age] (sn) titreşimi sürer.
  ///
  /// Doğuş/sönüş sönümü YOK ve olmamalı: mermi namlu parlamasının içinde
  /// doğuyor, çarpma patlamasının içinde ölüyor. Ayrıca sönümlenseydi gövde
  /// gradyanı (shader) buna uyamaz, yalnız parıltı solar ve mermi iki parçaya
  /// ayrılmış gibi görünürdü.
  void render(Canvas canvas, double age) {
    canvas
      ..drawPath(_body, _haloPaint)
      ..drawPath(_body, _bodyPaint);

    // Gövde boyunca ilerleyen sıcak cepler: mermiyi CANLI tutar. Sabit bir
    // kapsül plastik görünür.
    for (var i = 0; i < 2; i++) {
      final k = 0.4 + 0.6 * sin(age * 30 + i * 2.4);
      _nodePaint.color = body.withValues(alpha: 0.42 * k);
      canvas.drawCircle(
        Offset(i * length * 0.26, 0),
        width * 0.2 * k + 0.4,
        _nodePaint,
      );
    }

    canvas
      ..drawRRect(_filamentRRect, _filamentPaint)
      ..drawCircle(_nose, width * 0.85, _nosePaint)
      ..drawCircle(_nose, width * 0.26, _noseCorePaint)
      ..drawLine(
        Offset(_nose.dx - _flareX, 0),
        Offset(_nose.dx + _flareX, 0),
        _flarePaint,
      )
      ..drawLine(
        Offset(_nose.dx, -_flareY),
        Offset(_nose.dx, _flareY),
        _flarePaint,
      );
  }
}
