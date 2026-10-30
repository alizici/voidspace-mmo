import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../hangar/menu_cells.dart';
import '../ship/ship_bloc.dart';
import '../ship/ship_state.dart';

/// Dünya koordinatından minimap pikseline dönüşüm.
///
/// Ayrı bir tip, çünkü haritanın TEK doğru olması gereken şeyi bu: oyuncu,
/// izler, görüş kutusu ve ızgara aynı dönüşümden geçmezse harita kendi
/// içinde yalan söyler. Saf olduğu için tuval kurmadan test edilir.
class MinimapProjection {
  MinimapProjection(this.world, this.size) : scale = size.width / world.width;

  final GameWorld world;
  final Size size;

  /// Tek ölçek: minimap dünyanın EN-BOY ORANINI korur, yoksa kuzeye gitmek
  /// haritada doğuya gitmekten farklı hızda görünür.
  final double scale;

  /// [world] için verilen genişlikte minimap yüksekliği.
  static double heightFor(GameWorld world, double width) =>
      width * world.height / world.width;

  Offset toMap(double x, double y) => Offset(x * scale, y * scale);
}

/// Sağ-alt radar — eski projedeki minimap'in bu mimarideki karşılığı.
///
/// **Oyunu OKUMAZ.** Eski proje `VoidspaceGame`'i doğrudan okuyordu; burada
/// HUD'ın oyuna bakması yasak (bkz. `architecture_test.dart`), o yüzden
/// harita da tek bir kaynaktan — [ShipState] — besleniyor. Kazancı somut:
/// çubuklar ile harita aynı anlık görüntüden çizildiği için asla farklı iki
/// gerçek gösteremezler.
///
/// **İki hız.** Çerçeve, ızgara ve düşman izleri HUD tikiyle (on Hz) geliyor;
/// oyuncunun kendi pozu [poz] üzerinden HER KAREDE. Ayrım oyuncunun tarifiyle
/// doğdu: "minimap yavaş kalıyor gibi, takılıyor gibi". Doğruydu — 120 Hz bir
/// ekranda saniyede on adım ilerleyen bir nokta zıplıyor.
///
/// Bütün HUD'ı hızlandırmak yanlış cevap olurdu: kalkan yüzdesini 120 kez
/// tazelemek okunan hiçbir şeyi değiştirmez, yalnız ağacı yeniden kurar.
/// Burada yeniden kurulan hiçbir şey yok — [poz] boyacıya `repaint` olarak
/// veriliyor, yalnız radar katmanı yeniden boyanıyor.
class Minimap extends StatelessWidget {
  const Minimap({
    super.key,
    required this.state,
    this.poz,
    this.harita,
    this.width = 186,
  });

  final ShipState state;

  /// Oyuncunun pozu — kare hızında.
  ///
  /// Kanalın kendisi ya da içindeki değer `null` ise [state]'inki
  /// kullanılıyor: testler ve görsel referanslar kanalsız koşuyor, ve ilk
  /// kare gelmeden önce kanal boş.
  final ValueListenable<GemiPozu?>? poz;

  /// Oyuncunun bulunduğu harita — başlığında yazıyor.
  ///
  /// Yirmi dört haritalı bir dünyada "neredeyim" sorusunun cevabı ekranda
  /// olmalı. Tek dünya varken gereksizdi; bugün minimap ile galaksi haritası
  /// aynı soruyu iki ölçekte cevaplıyor ve ikisinde de yazmalı.
  final Harita? harita;

  /// İstenen genişlik; dar ekranda daraltılır.
  final double width;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = math.min(width, constraints.maxWidth);
      return IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (harita case final h?) ...[
              SizedBox(
                width: w,
                child: Text(
                  // Harita adı bölge adını taşıyor ve o Türkçe:
                  // "DEVRIK KULE" yerine "DEVRİK KULE".
                  menuUpper(h.ad),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Palette.label(10).copyWith(
                    color: _tipRengi(h.tip),
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: w,
              height: MinimapProjection.heightFor(state.world, w),
              // Harita HUD'ın geri kalanından AYRI bir rasterda: on Hz'de
              // yeniden çizilen tek şey o, ve komşularını da yeniden çizmesi
              // gereksiz.
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _MinimapPainter(state, poz),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Harita tipinin rengi — galaksi haritasındakiyle AYNI kod.
///
/// İki ekran aynı şeyi başka renkte gösterirse kod bir kod olmaktan çıkar.
Color _tipRengi(HaritaTipi tip) => switch (tip) {
  HaritaTipi.pve => Palette.good,
  HaritaTipi.pvp => Palette.danger,
  HaritaTipi.boss => Palette.boost,
};

class _MinimapPainter extends CustomPainter {
  _MinimapPainter(this.state, this.poz) : super(repaint: poz);

  final ShipState state;

  /// Kare hızındaki poz kanalı; `null` ise [state] okunuyor.
  final ValueListenable<GemiPozu?>? poz;

  /// Çizilecek poz — kanal varsa ondan, yoksa durumdan.
  GemiPozu get _poz =>
      poz?.value ?? GemiPozu(state.position, state.angle);

  /// Sektör ızgarası — 4×3. Bir haritayı okunur yapan şey
  /// ölçek çubuğu değil, tekrar eden bir referans deseni.
  static const _sectorsX = 4;
  static const _sectorsY = 3;

  static const _ground = Color(0xFF060B16);

  /// Zemin tozu — BİRİM karede (0..1) deterministik noktalar.
  ///
  /// Boş bir dikdörtgen harita gibi değil, kapatılmış bir panel gibi okunuyor.
  /// `Random` YOK: aynı harita her açılışta aynı görünmeli, yoksa toz
  /// oynadıkça göz onu bir iz sanıyor.
  static final List<Offset> _dust = _makeDust();

  static List<Offset> _makeDust() {
    // Küçük bir karma; iki bağımsız kanal için iki farklı tohum.
    double h(int i, double seed) {
      final v = math.sin(i * 127.1 + seed) * 43758.5453;
      return v - v.floorToDouble();
    }

    return [for (var i = 0; i < 70; i++) Offset(h(i, 311.7), h(i, 74.7))];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final projection = MinimapProjection(state.world, size);
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    canvas
      ..save()
      ..clipRRect(frame)
      ..drawRect(Offset.zero & size, Paint()..color = _ground);

    _dustLayer(canvas, size);
    _grid(canvas, size);
    _viewBox(canvas, size, projection);
    _alienBlips(canvas, projection);
    _blips(canvas, projection);
    _player(canvas, projection);

    canvas.restore();
    _border(canvas, frame);
    _readout(canvas, size);
  }

  /// Tek `drawPoints` çağrısı: yetmiş ayrı `drawCircle` yerine yetmiş nokta.
  void _dustLayer(Canvas canvas, Size size) => canvas.drawPoints(
    PointMode.points,
    [for (final d in _dust) Offset(d.dx * size.width, d.dy * size.height)],
    Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1
      ..color = Palette.ink.withValues(alpha: 0.16),
  );

  void _grid(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = Palette.line;
    for (var i = 1; i < _sectorsX; i++) {
      final x = size.width * i / _sectorsX;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < _sectorsY; i++) {
      final y = size.height * i / _sectorsY;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// Kameranın gördüğü alan. Haritayı bir konum göstergesinden NAVİGASYON
  /// aracına çeviren şey bu: oyuncu ekranda gördüğünün haritanın neresine
  /// düştüğünü ancak böyle bilir.
  /// Oyuncunun EKRANDA gördüğü alan — haritadaki karşılığı.
  ///
  /// **Merkez işaretle AYNI pozdan.** Kutu bir zamanlar [ShipState]'ten
  /// okuyordu; işaret kare hızına geçince ikisi ayrı hızlarda kaldı ve kutu,
  /// akan bir işaretin çevresinde saniyede on kez zıplamaya başladı. Aynı
  /// şeyi gösteren iki çizimin iki ayrı zamandan beslenmesi, en görünür
  /// türden tutarsızlık.
  ///
  /// **Kenarlar piksele oturtuluyor.** Bir piksellik saç çizgisi ara piksel
  /// konumlarında yumuşatmayla çiziliyor: kutu kayarken kenarın parlaklığı
  /// kare kare değişiyor ve göz bunu TİTREME olarak okuyor. Yarım piksellik
  /// kaydırma çizgiyi tam bir piksel sınırına oturtuyor — konum olarak
  /// fark edilmez, parlaklık olarak sabit.
  void _viewBox(Canvas canvas, Size size, MinimapProjection p) {
    final view = state.viewSize;
    if (view.x <= 0 || view.y <= 0) return;
    final poz = _poz;
    final centre = p.toMap(poz.konum.x, poz.konum.y);
    final kutu = Rect.fromCenter(
      center: centre,
      width: view.x * p.scale,
      height: view.y * p.scale,
    );
    double otur(double v) => v.roundToDouble() + 0.5;
    canvas.drawRect(
      Rect.fromLTRB(
        otur(kutu.left),
        otur(kutu.top),
        otur(kutu.right),
        otur(kutu.bottom),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x4DFFFFFF),
    );
  }

  /// Alien izleri — kendi YEŞİLLERİNDE.
  ///
  /// Oyuncu izleriyle aynı renkte olsalardı harita "kim insan kim değil"
  /// sorusunu cevaplayamazdı; ve o soru, nereye uçacağını belirleyen soru.
  /// Gemilerden ÖNCE çizilir: kalabalıkta oyuncu üstte kalmalı.
  void _alienBlips(Canvas canvas, MinimapProjection p) {
    if (state.alienBlips.isEmpty) return;
    final dot = Paint()..color = const Color(0xFF45E0A0);
    for (final blip in state.alienBlips) {
      final at = p.toMap(blip.x, blip.y);
      canvas.drawCircle(at, 1.8, dot);
      if (blip.id != state.weaponTarget) continue;
      // Kilitli alien de ekrandaki ayraçla AYNI maviyi konuşur: gösterge
      // hedefin TÜRÜNÜ değil, seçilmiş olduğunu söylüyor.
      canvas.drawCircle(
        at,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Palette.shield,
      );
    }
  }

  void _blips(Canvas canvas, MinimapProjection p) {
    final halo = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final dot = Paint();
    for (final blip in state.blips) {
      final at = p.toMap(blip.x, blip.y);
      final locked = blip.id == state.weaponTarget;
      if (!blip.alive) {
        // Enkaz İÇİ BOŞ: haritada canlı bir tehditle aynı ağırlıkta durmamalı,
        // ama tamamen kaybolması da "orada bir şey vardı" bilgisini siler.
        canvas.drawCircle(
          at,
          2.4,
          dot
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Palette.inkDim.withValues(alpha: 0.5),
        );
        dot.style = PaintingStyle.fill;
        continue;
      }
      // Hale şart: 3 pikselik düz bir nokta bu zeminde kayboluyor.
      canvas
        ..drawCircle(at, 4, halo..color = Palette.ink.withValues(alpha: 0.35))
        ..drawCircle(at, 2.4, dot..color = Palette.ink);
      if (!locked) continue;
      // Kilitli hedef, ekrandaki ayraçla AYNI mavi: iki gösterge aynı şeyi
      // söylüyorsa aynı rengi konuşmalı.
      canvas.drawCircle(
        at,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Palette.shield,
      );
    }
  }

  void _player(Canvas canvas, MinimapProjection p) {
    final poz = _poz;
    final at = p.toMap(poz.konum.x, poz.konum.y);
    canvas
      ..drawCircle(
        at,
        6,
        Paint()
          ..color = Palette.hull.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..save()
      ..translate(at.dx, at.dy)
      // Aynı açı sözleşmesi: 0 = kuzey. Üçgen −y'ye bakar.
      ..rotate(poz.aci);
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, -5.5)
          ..lineTo(3.6, 4)
          ..lineTo(-3.6, 4)
          ..close(),
        Paint()..color = Palette.boost,
      )
      ..restore();
  }

  void _border(Canvas canvas, RRect frame) {
    canvas
      // Yumuşak dış hale…
      ..drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Palette.shield.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      // …üstünde keskin kenar.
      ..drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Palette.line,
      );
  }

  /// Konum okuması. X ve Y AYRI satırlarda: birindeki basamak değişimi
  /// diğerini kaydırmasın.
  void _readout(Canvas canvas, Size size) {
    final x = _label('X', state.position.x);
    final y = _label('Y', state.position.y);
    const left = 7.0;
    final bottom = size.height - 5;
    y.paint(canvas, Offset(left, bottom - y.height));
    x.paint(canvas, Offset(left, bottom - y.height - x.height));
  }

  TextPainter _label(String axis, double value) => TextPainter(
    text: TextSpan(
      text: '$axis ${value.round()}',
      style: Palette.label(9).copyWith(
        color: Palette.ink,
        // Gölge şart: harita zemini sabit değil, izler altından geçebiliyor.
        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  // Poz DEĞİŞİKLİĞİ `repaint` üzerinden geliyor, buradan değil: `shouldRepaint`
  // yalnız widget yeniden kurulduğunda soruluyor (on Hz), oysa poz her karede
  // değişiyor.
  bool shouldRepaint(_MinimapPainter old) =>
      old.state != state || old.poz != poz;
}
