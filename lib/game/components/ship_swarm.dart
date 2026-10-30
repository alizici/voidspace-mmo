import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../net/ship_pose.dart';
import '../art/atlas_layout.dart';
import '../art/bastion.dart';
import '../art/govde_tasarimlari.dart';
import '../art/ship_atlas.dart';
import 'atlas_batch.dart';

/// Ekrandaki BÜTÜN gemileri çizen tek bileşen — seninki dahil.
///
/// Bu bir optimizasyon değil, oyunun çizim mimarisi. Ölçüm (macOS Release,
/// Impeller, 41 gemi):
///
/// | Yapılandırma        | GPU     |
/// |---------------------|---------|
/// | 5 gemi prosedürel   | 40.0 ms |
/// | 1 gemi prosedürel   |  8.7 ms |
/// | hepsi atlastan      |  0.9 ms |
///
/// Prosedürel çizilen tek bir gemi 120 Hz bütçesinin tamamını yiyor: kare
/// başına `saveLayer` + `ImageFilter.blur` ve yirmiden fazla ayrı
/// `MaskFilter.blur` var. "En yakın birkaç gemi parlasın" gibi bir kalite
/// kademesi bu tabloda işe yaramaz — beş gemi zaten 40 ms. Tek kalıcı çözüm
/// prosedürel çizimi kare yolundan TAMAMEN çıkarmaktı.
///
/// Kare başına maliyet gemi sayısından bağımsız: üç `drawRawAtlas` çağrısı
/// (motor, gövde, kalkan). Ham sürüm (`drawAtlas` değil) kasıtlı — nesne
/// alan sürüm gemi başına `RSTransform` ve `Rect` tahsis ederdi ve Dart'ın
/// çöp toplayıcısı duraklattığında duraklattığı şey kare döngüsü.
class ShipSwarm extends PositionComponent {
  ShipSwarm({required this.atlas}) : super(priority: 3);

  final ShipAtlas atlas;

  /// Titreşim karesi hızı. Prosedürel sanat sürekli değişiyordu; atlas ayrık
  /// kareler taşıyor ve bu hız onların ne kadar canlı okunduğunu belirliyor.
  /// 14, kor titreşiminin "yanıyor" okunduğu, ama karelerin tek tek
  /// seçilemediği aralık.
  static const double phaseHz = 14;

  /// Bunun altındaki itkide motor katmanı hiç çizilmez. Ortam parıltısı bu
  /// eşikte zaten görünmez.
  static const double _engineCutoff = 0.02;

  final AtlasBatch _engine = AtlasBatch();
  final AtlasBatch _hull = AtlasBatch();
  final AtlasBatch _shield = AtlasBatch();
  final AtlasBatch _emitter = AtlasBatch();

  double _time = 0;

  /// Bu karede toplu çizime katılan gemi sayısı. Testler için: ekrandaki her
  /// geminin çizildiğini doğrulamanın tek yolu.
  int submittedShips = 0;

  /// Kare başına çizim çağrısı sayısı — gemi sayısından BAĞIMSIZ.
  /// Mimarinin tek cümlelik özeti bu sabit.
  ///
  /// 3 → 4: silah yuvaları gövdeden ayrı bir blokta çizilmeye başladı, çünkü
  /// gemide görünen top sayısı oyuncunun taktığı lazere göre değişiyor.
  /// Değişen tek şey ÇAĞRI sayısı; dörtgen sayısı gemi başına en çok beş
  /// artıyor ve o da toplu çizimin içinde.
  static const int drawCallsPerFrame = 4;

  /// Doku örneklemesi: atlas cihazın ihtiyacından keskin olabilir (küçültme),
  /// asla bulanık değil. `medium` küçültmede mipmap kullanır — `low` ile
  /// hareket hâlindeki gemide gözle görülür bir parıldama farkı var.
  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void update(double dt) => _time += dt;

  void begin() {
    submittedShips = 0;
    _engine.begin();
    _hull.begin();
    _shield.begin();
    _emitter.begin();
  }

  /// Bir gemiyi bu karenin toplu çizimine kat.
  ///
  /// [id] titreşim fazını kaydırmak için: aynı fazda çizilen kırk gemi tek
  /// bir organizma gibi nefes alır ve bu, hareketin kendisinden daha çok
  /// dikkat çeker.
  ///
  /// [lasers] o gemide TAKILI lazer sayısı — kaç top çizileceğini belirler.
  /// Poz'un içinde değil ayrı bir parametre: poz ara değerlenmiş, sürekli,
  /// kare başına üzerine yazılan bir şey; namlu sayısı ise ancak oyuncu
  /// hangarda bir şey taktığında değişen ayrık bir gerçek. İkisini aynı
  /// nesneye koymak, ara değerlenmeyen bir alanı ara değerlenen bir yapının
  /// içine gizlemek olurdu.
  void submit(
    ShipPose pose,
    int id, {
    required int lasers,
    required int govde,
  }) {
    submittedShips++;
    final tick = (_time * phaseHz).floor() + id * 3;
    final thrust = pose.alive ? pose.thrust.clamp(0.0, 1.0) : 0.0;

    // Motor dörtgeni EN BÜYÜĞÜ (gövdenin iki katı yükseklikte, çoğu saydam) ve
    // duran bir gemide taşıdığı tek şey sönük bir ortam parıltısı. Mobil
    // GPU'da saydam piksel de boyanır: atlamak, boştaki gemilerde en büyük
    // dolgu maliyetini sıfırlıyor.
    if (thrust > _engineCutoff) {
      _pushBlended(
        _engine,
        pose,
        value: thrust,
        steps: AtlasLayout.engineThrustSteps,
        phase: AtlasLayout.pingPongPhase(tick, AtlasLayout.enginePhases),
        frame: atlas.engineFrame,
        anchor: atlas.engineAnchor,
      );
    }
    // Gövde: CANLI mı, SİLÜET mi.
    //
    // Sekiz tasarımın yedisi hareketsiz — kaynakları tek kare ve atlasta tek
    // hücre kaplıyorlar (bkz. [AtlasLayout.siluetFrame]). Onlar için itki
    // kademesi ile faz seçmek anlamsız: dört kademe de aynı kareyi gösterir,
    // ve çapraz sönümleme aynı kareyi kendisiyle harmanlayıp dörtgen sayısını
    // boşuna ikiye katlardı.
    //
    // Hareketi yine de var: motor pluması AYRI blokta ve paylaşılıyor, yani
    // silüet bir gemi de tam gazda alev püskürtüyor.
    if (govde == AtlasLayout.siluetSayisi) {
      _pushBlended(
        _hull,
        pose,
        value: thrust,
        steps: AtlasLayout.hullThrustSteps,
        phase: AtlasLayout.pingPongPhase(tick, AtlasLayout.hullPhases),
        frame: atlas.hullFrame,
        anchor: atlas.hullAnchor,
      );
    } else {
      _hull.push(
        x: pose.x,
        y: pose.y,
        angle: pose.angle,
        scale: atlas.worldScale,
        frame: atlas.siluetFrame(govde),
        anchor: atlas.hullAnchor,
        // Tam opak: harmanlanacak ikinci bir kare yok.
        alpha: 1,
      );
    }
    // Silah yuvaları GÖVDENİN ÜSTÜNE, kaidelerinin üstünde.
    //
    // Ölü gemide çizilmiyor: enkazın üstünde nabız atan bir enerji topu,
    // geminin hâlâ ayakta olduğunu söylerdi.
    if (pose.alive) {
      _pushEmitters(
        pose,
        lasers,
        AtlasLayout.pingPongPhase(tick, AtlasLayout.emitterPhases),
        govde,
      );
    }
    if (pose.shieldFraction > 0.01) {
      _pushBlended(
        _shield,
        pose,
        value: pose.shieldFraction,
        steps: AtlasLayout.shieldStrengthSteps,
        phase: AtlasLayout.pingPongPhase(tick, AtlasLayout.shieldPhases),
        frame: atlas.shieldFrame,
        anchor: atlas.shieldAnchor,
        // Kalkan kabuğu küre: dönmesinin görsel karşılığı yok, ve dönmemesi
        // gemi dönerken kabuğun sabit durmasını sağlıyor.
        rotate: false,
      );
    }
  }

  /// Kademe → dünya kaideleri, ÖNCEDEN hesaplanmış.
  ///
  /// `dunyaKaideleri` her çağrıda beş `Offset` ve bir liste ayırıyor; burası
  /// ateş eden her gemi için kare başına okunuyor. Kırk gemide saniyede
  /// ~29.000 kısa ömürlü nesne — bu dosyanın var olma sebebiyle aynı sebep.
  static final List<List<Offset>> _kaideTablosu = [
    for (final t in GovdeTasarimlari.hepsi) List.unmodifiable(t.dunyaKaideleri),
  ];

  static List<Offset> _kaideleri(int govde) =>
      _kaideTablosu[govde.clamp(0, _kaideTablosu.length - 1)];

  /// İki komşu kademeyi ÇAPRAZ SÖNÜMLEYEREK yazar.
  ///
  /// Atlas ayrık kademeler taşıyor (itki için dört tane). Doğrudan en yakın
  /// kademeyi seçmek, itki rampası boyunca dört görünür sıçrama üretiyordu —
  /// tam olarak kaçınmaya çalıştığımız "takılma" hissi. İki kareyi üst üste
  /// harmanlamak sürekli bir geçiş veriyor ve maliyeti yalnız iki kat dörtgen
  /// (41 gemide 246 dörtgen, GPU için ölçülemeyecek kadar az).
  void _pushBlended(
    AtlasBatch batch,
    ShipPose pose, {
    required double value,
    required int steps,
    required int phase,
    required Rect Function(int, int) frame,
    required Offset anchor,
    bool rotate = true,
  }) {
    final exact = value.clamp(0.0, 1.0) * (steps - 1);
    final low = exact.floor().clamp(0, steps - 1);
    final high = (low + 1).clamp(0, steps - 1);
    final t = exact - low;

    batch.push(
      x: pose.x,
      y: pose.y,
      angle: rotate ? pose.angle : 0,
      scale: atlas.worldScale,
      frame: frame(low, phase),
      anchor: anchor,
      alpha: 1 - t,
    );
    if (high != low && t > 0.001) {
      batch.push(
        x: pose.x,
        y: pose.y,
        angle: rotate ? pose.angle : 0,
        scale: atlas.worldScale,
        frame: frame(high, phase),
        anchor: anchor,
        alpha: t,
      );
    }
  }

  /// Takılı lazer sayısına göre silah yuvalarını yaz.
  ///
  /// Yuvanın gemideki yeri tasarımın `dunyaKaideleri`'nde GEMİ-YEREL dünya
  /// biriminde duruyor; burada yalnız geminin dönüşü uygulanıyor — atlas
  /// karesi de aynı açıyla çizildiği için top, kaidesinden ayrılmıyor.
  /// Hesap `CombatLayer._muzzleOf` ile birebir aynı ve öyle kalmalı: biri
  /// silahı çiziyor, diğeri mermiyi oradan doğuruyor.
  ///
  /// **Yuvanın KENDİSİ ölçeklenmiyor, yalnız yeri.** Sekiz tasarımın projektör
  /// boyları 13 ile 18 arasında değişiyor ama atlas tek boyda pişiriyor ve
  /// öyle kalıyor: aynı silah her gövdede aynı büyüklükte görünmeli. Gövde
  /// normalizasyonu kaideyi taşır, silahı büyütmez.
  void _pushEmitters(ShipPose pose, int lasers, int phase, int govde) {
    final mounts = Bastion.activeHardpoints(lasers);
    if (mounts.isEmpty) return;
    final kaideler = _kaideleri(govde);
    final cos = math.cos(pose.angle);
    final sin = math.sin(pose.angle);
    for (final mount in mounts) {
      final at = kaideler[mount];
      _emitter.push(
        x: pose.x + at.dx * cos - at.dy * sin,
        y: pose.y + at.dx * sin + at.dy * cos,
        angle: pose.angle,
        scale: atlas.worldScale,
        frame: atlas.emitterFrame(mount, phase),
        anchor: atlas.emitterAnchor,
        alpha: 1,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    // Sıra: motor (gövdenin ARKASINDA), gövde, silahlar, kalkan (en üstte,
    // yarı saydam). Silahlar gövdenin ÜSTÜNDE çünkü kaidelerinin üstüne
    // oturuyorlar; kalkanın ALTINDA çünkü kabuk gemiyi bütünüyle sarıyor.
    _engine.draw(canvas, atlas.image, _paint);
    _hull.draw(canvas, atlas.image, _paint);
    _emitter.draw(canvas, atlas.image, _paint);
    _shield.draw(canvas, atlas.image, _paint);
  }
}
