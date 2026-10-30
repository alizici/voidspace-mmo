import 'dart:math';
import 'dart:ui';

/// Void Spore — eski projenin "orb" arketipi.
///
/// Dört katman, ve ayrılmalarının sebebi hareket: kabuk ile detay podları
/// FARKLI hızlarda dönüyor, korona ile çekirdek ise farklı ritimlerde nefes
/// alıyor. Hepsi tek bir karede pişirilseydi, dönüşlerin ortak katı 63 saniye
/// olduğu için o kadar kare pişirmek gerekirdi.
///
/// Bu yüzden katmanlar atlasa AYRI hücreler olarak giriyor ve dönüş çizim
/// anında `RSTransform` ile uygulanıyor — alien başına dört dörtgen, ama
/// katman başına TEK çizim çağrısı (bkz. `AlienSwarm`).
///
/// Her katman orijine, verilen [r] yarıçapıyla çizilir.
abstract final class VoidSpore {
  // Palet eski projeden birebir: asit yeşili bir kabuk, beyaz-sıcak çekirdek.
  static const _halo = Color(0xFF45E0A0);
  static const _shellLight = Color(0xFF7CFFC6);
  static const _shellMid = Color(0xFF2FA877);
  static const _shellDark = Color(0xFF124A38);
  static const _edge = Color(0xFFBFFFE6);
  static const _podGlow = Color(0xFFB6FFEA);
  static const _coreHot = Color(0xFFFFFFFF);
  static const _coreMid = Color(0xFF6BFFC2);
  static const _coreCold = Color(0xFF0C3A2C);

  /// Sporun kendi paleti — `YaratikPaletleri` sırasıyla.
  static const List<Color> palet = [
    _halo,
    _shellLight,
    _shellMid,
    _shellDark,
    _edge,
    _podGlow,
    _coreHot,
    _coreMid,
    _coreCold,
  ];

  /// Katmanların palet indeksleri: hale · kabuk · detay · çekirdekGövde ·
  /// çekirdekKor.
  ///
  /// İlk indeks o katmanın TEMSİLCİSİ: nötr pişirmede beyaza çekilen ve
  /// çizimde boyanacak olan renk.
  ///
  /// **Çekirdek neden İKİ katman.** Tek renkle boyanan bir katman, iki tonlu
  /// bir gradyanı taşıyamıyor: çekirdek beyaz-sıcak bir merkez ile renkli bir
  /// gövdeden oluşuyor ve tek tonda ikisinden biri kayboluyordu. Ölçüldü —
  /// tek katmanken otuz iki yaratığın da çekirdeği aynı beyazdı, yani
  /// sprite'ın en dikkat çeken parçası hiçbir kimlik taşımıyordu.
  ///
  /// Bedeli bir atlas hücresi (173 px, 2.572'de %0,7). Otuz iki varyant
  /// pişirmenin bedeli +2.764 px idi.
  static const List<List<int>> katmanlar = [
    [0],
    [1, 2, 3, 4],
    [5],
    [7, 8],
    [6],
  ];

  /// NÖTR palet — atlasa pişirilen hâl.
  ///
  /// Elle gri yazılmıyor: her katmanın temsilcisi beyaza çekiliyor, kalanı
  /// aynı oranla soluyor. Yani sprite'ta yalnız DEĞER yapısı kalıyor, ton
  /// çizim anındaki çarpmadan geliyor.
  ///
  /// `modulate` yalnız karartabildiği için nötr sprite olabildiğince parlak
  /// olmalı — normalize etmenin sebebi estetik değil, aritmetik.
  static final List<Color> notr = () {
    final out = List<Color>.filled(palet.length, const Color(0xFFFFFFFF));
    for (final katman in katmanlar) {
      final tepe = _parlaklik(palet[katman.first]);
      for (final i in katman) {
        final v = tepe <= 0
            ? 1.0
            : (_parlaklik(palet[i]) / tepe).clamp(0.0, 1.0);
        out[i] = Color.from(alpha: palet[i].a, red: v, green: v, blue: v);
      }
    }
    return out;
  }();

  /// Algısal parlaklık — kanalların eşit ağırlıklı ortalaması DEĞİL.
  ///
  /// Yeşil göze en parlak, mavi en sönük gelir. Düz ortalama, yeşil bir
  /// sprite'ı olduğundan koyu gösterip nötr hâlini gereğinden fazla
  /// karartırdı.
  static double _parlaklik(Color c) =>
      0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

  /// Kabuk dönüşü (rad/sn). NEGATİF: detay podlarıyla ters yönde dönüyor ve
  /// asıl "canlı" hissini veren şey o karşıtlık.
  static const double shellSpin = -2 * pi / 7;

  /// Detay podlarının dönüşü (rad/sn).
  static const double detailSpin = 2 * pi / 4.5;

  /// Koronanın nabzı — çizim anında ÖLÇEK olarak uygulanır.
  static double haloPulse(double t) => 1.06 + 0.06 * sin(t * 2.6);

  /// Çekirdeğin nabzı; koronadan hızlı, ki ikisi senkron görünmesin.
  static double corePulse(double t) => 1 + 0.08 * sin(t * 4.8);

  /// Katmanın taştığı en geniş yarıçap — [r]'nin katı.
  ///
  /// Atlas hücresi bundan türetiliyor; elle bir sayı yazmak, sanat büyüdüğünde
  /// sessiz bir kırpma demek olurdu.
  static const double reachFactor = 1.7;

  /// 1 · Dış korona. Additive harmanla çizilir.
  static void paintHalo(Canvas canvas, double r, [List<Color>? p]) {
    final palet = p ?? VoidSpore.palet;
    final rad = r * reachFactor;
    canvas.drawCircle(
      Offset.zero,
      rad,
      Paint()
        ..shader = Gradient.radial(Offset.zero, rad, [
          palet[0].withValues(alpha: 0.7),
          palet[0].withValues(alpha: 0),
        ]),
    );
  }

  /// 2 · Dişli kabuk halkası. Dönen katman.
  static void paintShell(Canvas canvas, double r, [List<Color>? p]) {
    final palet = p ?? VoidSpore.palet;
    final ro = r * 1.5;
    final ri = r * 1.05;
    const teeth = 8;
    final bounds = Rect.fromCircle(center: Offset.zero, radius: ro);

    final toothPaint = Paint()
      ..shader = Gradient.linear(
        Offset(0, bounds.top),
        Offset(0, bounds.bottom),
        [palet[1], palet[2]],
      );
    for (var i = 0; i < teeth; i++) {
      canvas
        ..save()
        ..rotate(i / teeth * 2 * pi)
        ..drawPath(
          Path()
            ..moveTo(-ro * 0.16, -ro)
            ..lineTo(ro * 0.16, -ro)
            ..lineTo(ro * 0.10, -ro * 1.18)
            ..lineTo(-ro * 0.10, -ro * 1.18)
            ..close(),
          toothPaint,
        )
        ..restore();
    }

    // Halka: iki oval ve `evenOdd` — içi boş kalsın ki çekirdek görünsün.
    canvas
      ..drawPath(
        Path()
          ..addOval(bounds)
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: ri))
          ..fillType = PathFillType.evenOdd,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, bounds.top),
            Offset(0, bounds.bottom),
            [palet[2], palet[3]],
          ),
      )
      ..drawCircle(
        Offset.zero,
        ro,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..color = palet[4].withValues(alpha: 0.7),
      );
  }

  /// 3 · Üç detay podu. Kabuğun TERSİNE döner.
  static void paintDetail(Canvas canvas, double r, [List<Color>? p]) {
    final palet = p ?? VoidSpore.palet;
    final podR = r * 0.26;
    for (var k = 0; k < 3; k++) {
      final a = k / 3 * 2 * pi;
      final c = Offset(cos(a) * r * 1.22, sin(a) * r * 1.22);
      canvas
        ..drawCircle(
          c,
          podR * 1.8,
          Paint()
            ..color = palet[5].withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.13),
        )
        ..drawCircle(
          c,
          podR,
          Paint()
            // Duraklar AÇIK: `dart:ui`'nin gradyanı ikiden fazla renkte
            // durak istiyor (Flutter'ın `RadialGradient`'i eşit dağıtıyordu).
            ..shader = Gradient.radial(
              c,
              podR,
              [palet[6], palet[1], palet[3]],
              const [0, 0.5, 1],
            ),
        );
    }
  }

  /// 4 · Çekirdek: göz. Dikey elips gözbebeği bu alien'i bir topaçtan
  /// ayıran tek detay.
  /// 4 · Çekirdek GÖVDESİ — renkli halka ve yarık.
  static void paintCore(Canvas canvas, double r, [List<Color>? p]) {
    final palet = p ?? VoidSpore.palet;
    final radius = r * 0.72;
    canvas
      ..drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = Gradient.radial(
            Offset.zero,
            radius,
            [palet[7], palet[7], palet[8]],
            const [0, 0.55, 1],
          ),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 0.30,
          height: radius * 1.1,
        ),
        Paint()..color = palet[8].withValues(alpha: 0.9),
      );
  }

  /// 5 · Çekirdek KORU — beyaz-sıcak merkez.
  ///
  /// Gövdeden ayrı katman: ikisi tek renkle boyandığında biri kayboluyordu.
  static void paintCoreHot(Canvas canvas, double r, [List<Color>? p]) {
    final palet = p ?? VoidSpore.palet;
    final radius = r * 0.72;
    canvas
      ..drawCircle(
        Offset.zero,
        radius * 0.55,
        Paint()
          ..shader = Gradient.radial(Offset.zero, radius * 0.55, [
            palet[6],
            palet[6].withValues(alpha: 0),
          ]),
      )
      ..drawCircle(Offset.zero, radius * 0.12, Paint()..color = palet[6]);
  }
}
