import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../../app/palette.dart';
import '../../hangar/menu_cells.dart';
import '../art/void_portal.dart';

/// Haritanın GEÇİTLERİ — dünyadaki kapılar.
///
/// Konumlar sunucudan gelmiyor, [GecitAgi]'ndan TÜRETİLİYOR: ikisi de aynı
/// çekirdek koddan okuduğu için ayrışamıyorlar ve tele tek bayt eklemiyor.
/// Sunucunun geçidi nerede bildiği ile istemcinin çizdiği yer aynı fonksiyon.
///
/// **Kilitli geçit de çiziliyor.** Alan 11'in kararı: kapalı kapı bir hedef,
/// görünmeyen kapı bir boşluk. Kilitliyken sönük ve gereken savaş puanı
/// üstünde yazıyor.
class GecitKatmani extends PositionComponent {
  GecitKatmani({required this.harita, this.br = 0, this.seviye}) {
    // Izgaranın üstünde, gemilerin altında: kapı zeminin bir parçası, sahnenin
    // aktörü değil.
    priority = -80;
  }

  /// Çizilen haritanın geçitleri.
  ///
  /// Bileşen ağı TANIMIYOR: haritayı ve savaş puanını dışarıdan alıyor.
  /// Soketten kendi çekseydi ağsız çizilemez, ve testte bir harita
  /// kurgulamak sunucu ayağa kaldırmayı gerektirirdi.
  Harita harita;

  /// Oyuncunun savaş puanı — hangi kapının açık olduğunu bu belirliyor.
  double br;

  /// Seviye — ikincil kapı (11.4); bilinmiyorsa yalnız savaş puanı.
  int? seviye;

  /// Oyun saati — nabız ve bükülme bundan.
  double _zaman = 0;

  @override
  Future<void> onLoad() async {
    // Şerit ARKA PLANDA pişiyor; hazır olana kadar canlı hesap devrede ve
    // kapı boş kalmıyor. Beklemek ilk kareyi geciktirirdi.
    unawaited(VoidPortal.ensureBaked());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _zaman += dt;
  }

  @override
  void render(Canvas canvas) {
    final yaricap = GecitAgi.yaricap;

    for (final gecit in GecitAgi.gecitleriFor(harita)) {
      final acik = gecit.acik(br, seviye: seviye);
      canvas.save();
      canvas.translate(gecit.konum.x, gecit.konum.y);
      VoidPortal.render(
        canvas,
        radius: yaricap,
        time: _zaman,
        renk: _renkFor(gecit.hedef.tip),
        acik: acik,
      );
      canvas.restore();
      _etiket(
        canvas,
        gecit,
        Offset(gecit.konum.x, gecit.konum.y),
        yaricap,
        acik,
      );
    }
  }

  /// Kapının NEREYE gittiği — ve kapalıysa ne kadar eksik olduğu.
  void _etiket(
    Canvas canvas,
    Gecit gecit,
    Offset merkez,
    double yaricap,
    bool acik,
  ) {
    final hedef = gecit.hedef;
    // Aynı bölgedeyse yalnız tip yazıyor: bölge adını üç kez tekrarlamak
    // haritayı kalabalıklaştırırdı.
    // Tip adı (PvE · PvP · Boss) oyun terimi ve olduğu gibi büyüyor; bölge
    // adı Türkçe, o yüzden [menuUpper]'dan geçiyor — "SESSİZ FENER".
    final ad = hedef.bolge == gecit.kaynak.bolge
        ? hedef.tip.ad.toUpperCase()
        : menuUpper(hedef.bolge.ad);
    final eksik = acik ? null : (gecit.esik - br).round();

    final painter = TextPainter(
      text: TextSpan(
        text: eksik == null ? ad : '$ad\n+$eksik BR',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 46,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: (acik ? Palette.ink : Palette.faint).withValues(alpha: 0.9),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, merkez.translate(-painter.width / 2, yaricap * 1.35));
  }

  static Color _renkFor(HaritaTipi tip) => switch (tip) {
    HaritaTipi.pve => Palette.good,
    HaritaTipi.pvp => Palette.danger,
    HaritaTipi.boss => Palette.boost,
  };
}
