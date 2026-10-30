import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../art/atlas_layout.dart';
import '../art/leviathan_sprite.dart';
import '../art/ship_atlas.dart';
import '../art/void_spore.dart';
import '../art/yaratik_paletleri.dart';
import 'atlas_batch.dart';

/// Haritadaki BÜTÜN alien'leri çizen tek bileşen.
///
/// `ShipSwarm` ile aynı mimari ve aynı sebep: kare başına maliyet alien
/// sayısından bağımsız. Otuz altı alien, dört `drawRawAtlas` çağrısı —
/// katman başına bir tane.
///
/// **Neden katman başına.** Void Spore'nin kabuğu ve detay podları FARKLI
/// hızlarda ters yönlerde dönüyor, korona ile çekirdek farklı ritimlerde
/// nefes alıyor. Tek karede pişirilseydi dönüşlerin ortak katı 63 saniye
/// olduğu için o kadar kare gerekirdi. Dönüşü `RSTransform` ile çizim anında
/// vermek hem bedava hem sürekli.
///
/// Katmanlar ayrı çağrılar çünkü SIRA ve HARMAN farklı: korona additive ve
/// en altta, geri kalanı üstüne sırayla.
class AlienSwarm extends PositionComponent {
  AlienSwarm({required this.atlas, this.leviathan}) : super(priority: 2);

  final ShipAtlas atlas;

  /// Void Leviathan'ın sprite şeridi. Yüklenene kadar `null` — o türdeki
  /// alienler o ana kadar çizilmiyor.
  ///
  /// Atlas gibi bloklamıyor: dokusu gelmeyen bir tür yüzünden bütün sahneyi
  /// bekletmek, tek bir varlığın yükleme hatasını oyunun tamamına yaymak
  /// olurdu.
  LeviathanSprite? leviathan;

  /// Bu karede çizime katılan alien sayısı — testler için.
  int submitted = 0;

  /// Kare başına çizim çağrısı, alien sayısından BAĞIMSIZ.
  ///
  /// Dört Void Spore katmanı + bir Leviathan. Leviathan tek çağrı çünkü tek
  /// katmanlı hazır bir sprite: dönüşü ve karesi `RSTransform` ile çizim
  /// anında veriliyor.
  static const int drawCallsPerFrame = 5;

  final AtlasBatch _halo = AtlasBatch();
  final AtlasBatch _shell = AtlasBatch();
  final AtlasBatch _detail = AtlasBatch();
  final AtlasBatch _core = AtlasBatch();
  final AtlasBatch _coreHot = AtlasBatch();
  final AtlasBatch _leviathan = AtlasBatch();

  /// Bu karede can çubuğu çizilecek alienler.
  final List<_Bar> _bars = [];
  final Paint _barTrack = Paint()..color = const Color(0x99000000);
  final Paint _barFill = Paint()..color = const Color(0xFF45E0A0);

  double _time = 0;

  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _additive = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;

  @override
  void update(double dt) => _time += dt;

  void begin() {
    submitted = 0;
    _bars.clear();
    _halo.begin();
    _shell.begin();
    _detail.begin();
    _core.begin();
    _coreHot.begin();
    _leviathan.begin();
  }

  /// Bir alien'i bu karenin toplu çizimine kat.
  ///
  /// [id] fazı kaydırmak için: aynı fazda nefes alan otuz alien tek bir
  /// organizma gibi görünüyor ve bu, hareketin kendisinden çok dikkat
  /// çekiyor.
  void submit(
    double x,
    double y,
    int id,
    double hullFraction, {
    int kind = 0,
    double heading = 0,
  }) {
    submitted++;
    // Faz kayması kimlikten TÜREVİ: rastgele olsaydı yeniden bağlanmada
    // sürünün ritmi değişirdi.
    final t = _time + id * 0.7;

    if (kind == AlienStats.leviathan.kind) {
      _submitLeviathan(x, y, t, heading, hullFraction);
      return;
    }

    // Yarıçap MODELDEN — sanat sabitinden değil.
    //
    // Bu satır `AlienStats.spore.radius` okuyordu ve tek bir yaratık varken
    // doğruydu. Kadro geldiğinde sessizce yanlış oldu: kadronun yarıçapları
    // 14..19 arasında, spore'unki 24. Yani her yaratığın can çubuğu kendi
    // gövdesinden geniş çiziliyordu.
    final yaricap = YaratikKadrosu.yaricapFor(kind);

    // Çubuk YALNIZ hasarlıda. Dolu bir çubuk hiçbir şey söylemiyor ve otuz
    // alienin üstünde otuz dolu çubuk, haritayı arayüze çeviriyor.
    if (hullFraction < 0.999) {
      _bars.add(_Bar(x, y, hullFraction, yaricap));
    }

    // BOY da kimlikten. Sprite atlasa TEK boyda pişiyor (yarıçap 24) ve
    // buraya kadar tek boyda çiziliyordu: on beş ayrı yaratık ekranda aynı
    // irilikteydi, oysa modelleri 14 ile 19 arasında değişiyor. Bir yaratığın
    // vurulan yeri ile görünen yeri ayrıysa oyuncu gördüğüne güvenemez.
    final olcek = yaricap / AtlasLayout.alienRadiusWorld;

    // Sprite atlasa NÖTR pişiyor; ton burada, katman katman veriliyor.
    //
    // Otuz iki yaratığın hepsi aynı silueti paylaşıyor ama aynı renkte
    // değil — ve bu, otuz iki ayrı sprite pişirmenin bedeli olmadan
    // (atlas 2,6 MB'lık DAĞITILAN bir asset) elde ediliyor.
    final palet = _paletFor(kind);
    _push(_halo, 0, x, y, 0, VoidSpore.haloPulse(t), palet[0], olcek);
    _push(_shell, 1, x, y, VoidSpore.shellSpin * t, 1, palet[1], olcek);
    _push(_detail, 2, x, y, VoidSpore.detailSpin * t, 1, palet[2], olcek);
    _push(_core, 3, x, y, 0, VoidSpore.corePulse(t), palet[3], olcek);
    _push(_coreHot, 4, x, y, 0, VoidSpore.corePulse(t), palet[4], olcek);
  }

  void _submitLeviathan(
    double x,
    double y,
    double t,
    double heading,
    double hullFraction,
  ) {
    final sprite = leviathan;
    if (sprite == null) return;

    if (hullFraction < 0.999) {
      _bars.add(_Bar(x, y, hullFraction, AlienStats.leviathan.radius));
    }

    // `idle_hover` döngüsü: 8 kare, saniyede ~10 kare. Kimliğe göre kaydırılan
    // `t` sayesinde iki Leviathan aynı karede olmuyor — aynı anda nefes alan
    // sürü tek bir organizma gibi görünürdü.
    final index = (t * 10).floor();
    _leviathan.push(
      x: x,
      y: y,
      angle: heading,
      scale: sprite.worldScale,
      frame: sprite.frame(index),
      anchor: sprite.anchor,
      alpha: 1,
    );
  }

  /// Kimlik → KATMAN tonları (hale · kabuk · detay · çekirdek).
  ///
  /// Önceden hesaplanıyor: kare yolunda otuz iki üyelik bir listede arama
  /// yapmak, sürü başına binlerce karşılaştırma ederdi.
  ///
  /// Tanınmayan kimlik sporun kendi paletine düşüyor — eski kayıtlar ve
  /// kadroya girmemiş bir tür ekranda kaybolmasın diye.
  static final Map<int, List<Color>> _tonlar = {
    for (final y in YaratikKadrosu.hepsi)
      if (YaratikPaletleri.hepsi[y.slug] case final p?)
        y.kind: [for (final katman in VoidSpore.katmanlar) p[katman.first]],
  };

  static final List<Color> _varsayilanTon = [
    for (final katman in VoidSpore.katmanlar) VoidSpore.palet[katman.first],
  ];

  List<Color> _paletFor(int kind) => _tonlar[kind] ?? _varsayilanTon;

  void _push(
    AtlasBatch batch,
    int layer,
    double x,
    double y,
    double angle,
    double pulse,
    Color tint,
    double olcek,
  ) => batch.push(
    x: x,
    y: y,
    angle: angle,
    scale: atlas.worldScale * pulse * olcek,
    frame: atlas.alienFrame(layer),
    tint: tint,
    anchor: atlas.alienAnchor,
    alpha: 1,
  );

  @override
  void render(Canvas canvas) {
    // Sıra: korona (additive, en altta) → kabuk → podlar → çekirdek.
    _halo.draw(canvas, atlas.image, _additive);
    _shell.draw(canvas, atlas.image, _paint);
    _detail.draw(canvas, atlas.image, _paint);
    _core.draw(canvas, atlas.image, _paint);
    _coreHot.draw(canvas, atlas.image, _paint);
    if (leviathan case final sprite?) {
      _leviathan.draw(canvas, sprite.image, _paint);
    }
    _drawBars(canvas);
  }

  /// Hasarlı alienlerin can çubukları.
  ///
  /// Toplu çizimin DIŞINDA ve öyle kalmalı: çubuk atlasa giremez (uzunluğu
  /// sürekli), ama sayısı da hasarlı alienlerle sınırlı — dövüşte birkaç
  /// tane. Atlasın kuralı "kare başına saveLayer + blur taşıyan şeyler",
  /// iki dikdörtgen değil.
  void _drawBars(Canvas canvas) {
    const height = 4.0;
    for (final bar in _bars) {
      // Çubuk yaratığın ÖLÇÜSÜNE göre: Leviathan, Void Spore'nin iki katı ve
      // üstünde aynı boyda bir çubuk taşıması onu küçük gösterirdi.
      final width = bar.radius * 1.85;
      final left = bar.x - width / 2;
      final y = bar.y - bar.radius * 1.75;
      canvas
        ..drawRect(Rect.fromLTWH(left, y, width, height), _barTrack)
        ..drawRect(Rect.fromLTWH(left, y, width * bar.hull, height), _barFill);
    }
  }
}

class _Bar {
  const _Bar(this.x, this.y, this.hull, this.radius);
  final double x;
  final double y;
  final double hull;
  final double radius;
}
