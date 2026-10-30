import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../art/atlas_layout.dart';
import '../art/bastion.dart';
import '../art/damage_text.dart';
import '../art/heat_ramp.dart';
import '../art/laser_bolt.dart';
import '../art/shield_shell.dart';

/// Savaşın GÖRSEL katmanı: mermiler, çarpma patlamaları, hasar sayıları ve
/// hedef kilidi.
///
/// **Tek bileşen, çok mermi.** Her mermiyi ayrı bir Flame bileşeni yapmak
/// doğal görünür ve bu mimaride yanlıştır: gemiler zaten tek bir toplu
/// çiziciden (`ShipSwarm`) çiziliyor, ve saniyede onlarca bileşen kurup
/// yıkmak ağacı sürekli yeniden düzenlemek demek. Mermiler burada düz bir
/// listede yaşıyor.
///
/// **Otorite burada DEĞİL.** Bu katman hiçbir şeye hasar vermez; sunucunun
/// çözdüğü vuruşları ([fire]) çizer. Mermi hedefe varmadan hasar çoktan
/// inmiştir — mermi o hasarı TAŞIMAZ, yalnız haber verir. Aksi hâlde
/// istemcinin çizim hızı oyunun hızını belirlerdi.
class CombatLayer extends PositionComponent {
  CombatLayer() : super(priority: 4);

  /// Patlama ve namlu parlaması geminin kimliğinden gelir: Bastion lav yakar.
  static const _ramp = HeatRamp.molten;

  /// Gruplar arası gecikme (sn) — eski projedeki `_volleyStagger` ile aynı.
  static const double _volleyStagger = 0.08;

  /// Yaylım içindeki namlu gecikmeleri (sn) — [Bastion.hardpoints] sırasıyla:
  /// `[uç sol, uç sağ, merkez, kanat sol, kanat sağ]`.
  ///
  /// Sıra **2 → 1 → 2**: önce uç çifti, sonra merkez top, sonra kanat çifti.
  /// Eski projenin `_hardpointGroups()` düzeni bu ve tesadüf değil — dıştan
  /// içe, sonra dışa giden bir ripple, beş namlunun ayrı olduğunu tek bakışta
  /// söylüyor. Hepsi aynı anda ateşlerse yaylım tek bir kalın mermiye düşer.
  static const List<double> _volleyDelay = [
    0,
    0,
    _volleyStagger,
    _volleyStagger * 2,
    _volleyStagger * 2,
  ];

  /// Merminin hedefe kilitlenme sıkılığı. Hedef kaçarken mermi onu takip eder
  /// — çünkü hasar zaten inmiş durumda ve ıskalayan bir mermi YALAN söyler.
  static const double _homing = 9;

  /// Kalkanı İNMİŞ bir hedefte merminin patladığı mesafe. Gövde yarıçapından
  /// biraz büyük: mermi gemiye gömülmeden, kabuğunda sönmeli.
  static const double _hullHitRadius = 34;

  /// Kalkan darbesinin ömrü — [ShieldShell.impactLife]'tan gelir; iki sayı
  /// ayrışırsa halka yarıda kesilir ya da sönmüş bir darbe çizilmeye devam
  /// eder.
  static double get _shieldHitLife => ShieldShell.impactLife;

  /// Hedefi kaybeden mermi sonsuza kadar uçmaz.
  static const double _maxLife = 2.4;

  static const double _labelLife = 1.15;
  static const double _labelRise = 52;

  final BoltArt _bolt = BoltArt.pl4;

  final Map<int, _Tracked> _poses = {};
  final List<_Bolt> _bolts = [];
  final List<_Flash> _flashes = [];
  final List<_ShieldHit> _shieldHits = [];
  final List<_Label> _labels = [];
  final List<_Aim> _aims = [];
  Offset? _lock;

  double _time = 0;
  int _frame = 0;
  int _labelSeq = 0;

  // Paylaşılan fırçalar — kare başına `Paint` üretmek, saniyede binlerce kısa
  // ömürlü nesne eder ve çöp toplayıcı duraklaması doğrudan takılma olur.
  final Paint _glowPaint = Paint()..blendMode = BlendMode.plus;
  final Paint _corePaint = Paint()..blendMode = BlendMode.plus;
  final Paint _ringPaint = Paint()
    ..blendMode = BlendMode.plus
    ..style = PaintingStyle.stroke;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  // ── Yoğunluk ölçümü ──────────────────────────────────────────────────
  //
  // ANLIK sayım yanıltıcı: mermi kısa ömürlü, 10 Hz örnekleme çoğu zaman
  // sıfır yakalıyor ve "savaş yok" gibi görünüyor — oysa ekran mermi kaynıyor.
  // Yoğunluğun doğru ölçüsü ORAN.
  int _launchedThisSecond = 0;
  int _hitsThisSecond = 0;
  double _rateWindow = 0;

  /// Saniyede namludan çıkan mermi.
  int boltsPerSecond = 0;

  /// Saniyede karşıya varan vuruş.
  int hitsPerSecond = 0;

  int get debugBoltCount => _bolts.length;

  /// Droidden çıkan mermiler — filonun ateş ettiğinin ölçülebilir izi.

  /// Roket mermileri (18.6).
  int get debugRoketCount =>
      _bolts.where((b) => identical(b.art, BoltArt.roket)).length;

  /// Namlusunu TERK ETMİŞ mermiler. Yaylım sırasının tek ölçülebilir izi:
  /// beş mermi aynı anda kuyruğa girer, gruplar hâlinde yola çıkar.
  int get debugLaunchedBoltCount => _bolts.where((b) => b.launched).length;
  int get debugLabelCount => _labels.length;
  int get debugShieldHitCount => _shieldHits.length;

  /// Bu karede ÖLDÜREN mermilerin çarptığı hedefler.
  ///
  /// Ölümün ne zaman GÖRÜNECEĞİNİ bu katman biliyor, ağ katmanı değil:
  /// sunucu hedefi vuruş anında düşürüyor ama mermi hâlâ yolda. Hedefi olay
  /// gelir gelmez silmek, merminin varmadan boşluğa çarpması demek olurdu.
  ///
  /// Liste okundu­ğunda BOŞALIR, kare başında değil.
  ///
  /// Fark önemliydi ve bir kez ısırdı: çarpmalar `update` içinde, yani oyun
  /// döngüsünün `super.update` adımında oluyor — çağıranın okuduğu andan
  /// SONRA. Kareyi başlatırken temizleyen bir liste, kaydedilen her ölümü bir
  /// sonraki `begin()` ile siliyordu ve hiçbir ölüm hiç okunmuyordu.
  final List<int> _kills = [];

  List<int> takeKills() {
    if (_kills.isEmpty) return const [];
    final taken = List<int>.of(_kills);
    _kills.clear();
    return taken;
  }

  // ── Kare başı besleme ──────────────────────────────────────────────────

  /// Karenin başı: yalnız SEVİYE bilgisi temizlenir (kilit, ateş eden gemiler).
  /// Mermiler ve sayılar OLAYdır — kendi ömürleri boyunca yaşarlar.
  void begin() {
    _aims.clear();
    _lock = null;
    _frame++;
  }

  /// Bir geminin bu karedeki çizim konumu. Mermiler hedefini buradan izler.
  ///
  /// [shield] darbenin ne kadar parlayacağını belirler: yarı inmiş bir kalkan
  /// yarı parlar, ve oyuncu kalkanın bittiğini HUD çubuğuna bakmadan görür.
  /// [lasers] o gemide takılı lazer sayısı; mermiler yalnız GERÇEKTEN var
  /// olan namlulardan çıksın diye. Alienlerde sıfır — silahları bu gövdeye
  /// ait değil.
  ///
  void track(
    int id,
    double x,
    double y,
    double angle, [
    double shield = 1,
    int lasers = 0,
  ]) {
    (_poses[id] ??= _Tracked())
      ..x = x
      ..y = y
      ..angle = angle
      ..shield = shield
      ..lasers = lasers
      // Kimlik ARALIĞINDAN: `Protocol.isAlienId` zaten tel üzerindeki tek
      // ayrımın kaynağı, ve çizim katmanının ikinci bir bayrak taşıması
      // ikisinin ayrışabileceği bir yer açardı.
      ..alien = Protocol.isAlienId(id)
      ..frame = _frame;
  }

  /// Ateşi AÇIK bir gemi — namluları kor hâlinde parlar.
  ///
  /// Mermiler sunucudan geldiği için bir gidiş-dönüş gecikmeli çıkıyor. Bu
  /// parlama ise tahminden: F'ye basıldığı KAREDE görünür. Geri bildirimi
  /// anında, mermiyi otoriter tutan ayrım tam olarak burası.
  void aim(double x, double y, double angle, int lasers) =>
      _aims.add(_Aim(x, y, angle, lasers));

  /// Kilitli hedefin dünya konumu.
  void setLock(double x, double y) => _lock = Offset(x, y);

  /// Sunucunun çözdüğü BİR yaylım. Namlu başına bir mermi doğurur.
  void fire({
    required int shooterId,
    required int targetId,
    required int damage,
    required bool shieldHit,
    required bool killed,
    bool crit = false,
    bool grazed = false,
    bool roket = false,
  }) {
    final target = _poses[targetId];
    // Hedefi göremiyorsak çizecek bir şey de yok: sayı boşlukta asılı kalırdı.
    if (target == null) return;

    final shooter = _poses[shooterId];
    if (shooter != null && roket) {
      // ROKET: tek mermi, geminin merkezinden, iri ve yavaş; sayıyı kendisi
      // taşır. Namlu dalgasına girmiyor, roketatarın kendi atışı.
      // KARAR 18.6 s1
      final (dx, dy) = _dogrultu(shooter.x, shooter.y, target, shooter);
      _bolts.add(
        _Bolt(
          shooterId: shooterId,
          muzzle: _alienMuzzle,
          art: BoltArt.roket,
          x: shooter.x,
          y: shooter.y,
          dx: dx,
          dy: dy,
          targetId: targetId,
          tx: target.x,
          ty: target.y,
          delay: 0,
          hitRadius: shieldHit ? AtlasLayout.shieldRadiusWorld : _hullHitRadius,
          damage: damage,
          shieldHit: shieldHit,
          killed: killed,
          crit: crit,
          grazed: grazed,
        ),
      );
      return;
    }
    if (shooter == null) {
      // Atıcı ilgi alanının dışında (menzilin ucundan vuruyor). Mermiyi
      // çıkaracak namlu yok ama hasar gerçek — sayı yine düşmeli, yoksa
      // oyuncu sebepsiz eriyor.
      _spawnLabel(target.x, target.y, damage, shieldHit, killed, crit, grazed);
      return;
    }

    // Yaylım YALNIZ takılı namlulardan. Gemide çizilen top sayısıyla ateş
    // eden namlu sayısı aynı olmak zorunda: birinin diğerinden fazla olması,
    // ya olmayan bir silahtan mermi çıkması ya da duran bir topun ateş
    // etmemesi demek — ikisi de oyuncunun anında gördüğü türden bir yalan.
    //
    // Alien'in namlusu YOK: tek mermi merkezden çıkıyor. `_alienMuzzle`
    // indeksi gerçek bir kaideye karşılık gelmiyor ve `_muzzleOf` onu
    // ofsetsiz çözüyor.
    final mounts = shooter.alien
        ? const [_alienMuzzle]
        : Bastion.activeHardpoints(shooter.lasers);
    // DROİD ATEŞ ETMEZ (05.1): filo geminin çarpanlarını taşıyor, kendi
    // mermisi yok. Bir süre ekranda droid başına bir mermi çiziliyordu ve
    // yanlıştı — sunucu droid hasarını geminin vuruşuna ekliyor, yani ekranda
    // iki kaynak varmış gibi görünen tek bir hasar vardı. Filo yine görünür,
    // yalnız susar.
    if (mounts.isEmpty) {
      // Silahsız bir gemi ateş etmiş görünüyor (sunucu hasarı sıfır çözer).
      // Mermi yok ama sayı düşmeli — yoksa hedef sebepsiz eriyordu. Droidi
      // olan ama namlusu olmayan gemi de buraya düşüyor.
      _spawnLabel(target.x, target.y, damage, shieldHit, killed, crit, grazed);
      return;
    }

    // Kalkan ayaktaysa mermi KABUĞA çarpar, gövdeye değil. Aradaki 28 birim
    // gözle görülür: mermilerin gemiye girip içeride patlaması, kalkanın
    // orada olmadığını söylerdi.
    final hitRadius = shieldHit
        ? AtlasLayout.shieldRadiusWorld
        : _hullHitRadius;

    // Sayıyı yaylımın İLK mermisi taşır. Hepsi taşısaydı tek vuruş için beş
    // sayı düşerdi; sonuncusu taşısaydı sayı yaylımın en yavaş namlusunu
    // beklerdi.
    //
    // "İlk" 0. namlu DEĞİL, kuyruğa giren ilk mermi: tek lazerle uçan bir
    // gemide yalnız merkez top (indeks 2) ateş ediyor ve `i == 0` kimseye
    // uymadığı için hiçbir sayı düşmezdi.
    var tasiyici = true;
    for (final i in mounts) {
      final (mx, my) = _muzzleOf(shooter, i);
      final (dx, dy) = _dogrultu(mx, my, target, shooter);
      _bolts.add(
        _Bolt(
          shooterId: shooterId,
          muzzle: i,
          art: _bolt,
          x: mx,
          y: my,
          dx: dx,
          dy: dy,
          targetId: targetId,
          tx: target.x,
          ty: target.y,
          delay: _volleyDelay[i % _volleyDelay.length],
          hitRadius: hitRadius,
          damage: tasiyici ? damage : 0,
          shieldHit: shieldHit,
          killed: killed,
          crit: crit,
          grazed: grazed,
        ),
      );
      tasiyici = false;
    }

  }

  /// Çıkış noktasından hedefe birim yön; üst üsteyse geminin burnu.
  (double, double) _dogrultu(
    double mx,
    double my,
    _Tracked target,
    _Tracked shooter,
  ) {
    final dx = target.x - mx;
    final dy = target.y - my;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 1e-3) return (math.cos(shooter.angle), math.sin(shooter.angle));
    return (dx / d, dy / d);
  }

  // ── Simülasyon ─────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    _time += dt;

    // Oranlar bir saniyelik pencerede toplanır. Ölçümün kendisi kare
    // bütçesinden bir şey almasın diye: iki tamsayı artırımı ve saniyede bir
    // sıfırlama.
    _rateWindow += dt;
    if (_rateWindow >= 1) {
      _rateWindow = 0;
      boltsPerSecond = _launchedThisSecond;
      hitsPerSecond = _hitsThisSecond;
      _launchedThisSecond = 0;
      _hitsThisSecond = 0;
    }

    _advanceBolts(dt);

    for (var i = _flashes.length - 1; i >= 0; i--) {
      if ((_flashes[i].age += dt) >= _flashes[i].life) _flashes.removeAt(i);
    }
    for (var i = _shieldHits.length - 1; i >= 0; i--) {
      if ((_shieldHits[i].age += dt) >= _shieldHitLife) {
        _shieldHits.removeAt(i);
      }
    }
    for (var i = _labels.length - 1; i >= 0; i--) {
      if ((_labels[i].age += dt) >= _labelLife) _labels.removeAt(i);
    }

    // İz temizliği: ilgi alanından çıkan ya da ayrılan gemiler haritada
    // sonsuza kadar kalmasın. Seyrek, çünkü tavan zaten oyuncu sayısı.
    if (_frame % 120 == 0) {
      _poses.removeWhere((_, t) => _frame - t.frame > 120);
    }
  }

  void _advanceBolts(double dt) {
    for (var i = _bolts.length - 1; i >= 0; i--) {
      final b = _bolts[i];
      final shooter = _poses[b.shooterId];

      if (!b.launched) {
        b.delay -= dt;
        if (b.delay > 0) {
          // Gecikmeli namlu, gemi hareket ederken ateşleniyor: çıkış noktası
          // gemiyle gitmeli, yoksa mermi geminin ARKASINDA doğar.
          if (shooter != null) {
            final (mx, my) = _cikis(shooter, b);
            b
              ..x = mx
              ..y = my;
          }
          continue;
        }
        b.launched = true;
        _launchedThisSecond++;
        // Roketin namlu parlaması büyük: mermi kadar.
        _flashes.add(
          _Flash(
            b.x,
            b.y,
            identical(b.art, BoltArt.roket) ? 12.0 : 7.5,
            0.11,
          ),
        );
      }

      b.age += dt;
      if (b.age > _maxLife) {
        _bolts.removeAt(i);
        continue;
      }

      final target = _poses[b.targetId];
      if (target != null) {
        b
          ..tx = target.x
          ..ty = target.y;
      }

      final toX = b.tx - b.x;
      final toY = b.ty - b.y;
      final distance = math.sqrt(toX * toX + toY * toY);
      final step = b.art.speed * dt;

      // Vardı ya da geçti: iki koşul da gerekli. Yalnız mesafeye bakmak, hızlı
      // mermide hedefin ÜSTÜNDEN atlayıp arkasında sonsuza dek dönmesine yol
      // açar.
      if (distance <= b.hitRadius + step || (toX * b.dx + toY * b.dy) <= 0) {
        _impact(b);
        _bolts.removeAt(i);
        continue;
      }

      final k = math.min(1.0, dt * _homing);
      b
        ..dx += (toX / distance - b.dx) * k
        ..dy += (toY / distance - b.dy) * k;
      final n = math.sqrt(b.dx * b.dx + b.dy * b.dy);
      b
        ..dx /= n
        ..dy /= n
        ..x += b.dx * step
        ..y += b.dy * step;
    }
  }

  void _impact(_Bolt b) {
    final target = _poses[b.targetId];
    if (b.shieldHit && target != null) {
      // Temas noktası: merminin GELDİĞİ yönde, kabuk yüzeyinin üstünde.
      // Merkezden çizmek kolay olurdu ve her vuruş aynı yerden patlardı —
      // oysa oyuncunun okuması gereken şey tam olarak "nereden vuruldum".
      var nx = b.x - target.x;
      var ny = b.y - target.y;
      final n = math.sqrt(nx * nx + ny * ny);
      if (n < 1e-3) {
        nx = -b.dx;
        ny = -b.dy;
      } else {
        nx /= n;
        ny /= n;
      }
      const r = AtlasLayout.shieldRadiusWorld;
      // Kabuk darbesi yaylım BAŞINA bir tane — mermi başına değil.
      //
      // Beşi birden denendi ve kabuk beyaza doydu: hücre parlaklığı bütün
      // canlı darbelerin TOPLAMI olduğu için beş cephe her hücreyi tavana
      // vurduruyor ve dalga okunmuyordu. Eski projede de kalkan saldırı
      // başına bir kez uyarılıyor. Girişim yine var, ama olması gereken
      // yerde: FARKLI saldırganların vuruşları arasında.
      //
      // Hasarı taşıyan mermi (yaylımın ilki) aynı zamanda ilk varan olduğu
      // için kabuk doğru anda uyanıyor.
      if (b.damage > 0) {
        _shieldHits.add(_ShieldHit(Offset(nx * r, ny * r), b.targetId));
        _capShieldHits(b.targetId);
      }
      // Her merminin KENDİ teması ayrı bir kıvılcım bırakır: beş mermi geldiği
      // yine görünür, kabuğu doyurmadan.
      _flashes.add(_Flash(target.x + nx * r, target.y + ny * r, 8, 0.16));
    } else {
      _flashes.add(
        _Flash(
          b.tx,
          b.ty,
          b.killed ? 26 : 15,
          b.killed ? 0.5 : 0.26,
          ring: b.killed,
        ),
      );
    }
    if (b.damage > 0) {
      _spawnLabel(
        b.tx,
        b.ty,
        b.damage,
        b.shieldHit,
        b.killed,
        b.crit,
        b.grazed,
      );
    }
    // Ölüm merminin ÇARPTIĞI anda ilan edilir — bkz. [_kills].
    if (b.killed) _kills.add(b.targetId);
  }

  void _spawnLabel(
    double x,
    double y,
    int damage,
    bool shieldHit,
    bool killed,
    bool crit,
    bool grazed,
  ) {
    // Yatay kayma DETERMİNİSTİK bir sayaçtan: `Random` kullanmak aynı sahneyi
    // iki kez çizmeyi imkânsız kılar ve golden testleri kararsızlaştırır.
    final drift = ((_labelSeq++ % 5) - 2) * 9.0;
    _hitsThisSecond++;
    _labels.add(
      _Label(
        x: x + drift,
        // Kalkan ayaktaysa sayı kabuğun ÜSTÜNDE durmalı; içine düşerse
        // kabuğun parlaması onu yutar.
        y: y - (shieldHit ? AtlasLayout.shieldRadiusWorld + 16 : 48),
        label: DamageLabel(
          // Renk önceliği: imha > kritik > havuz. İmha zaten oyunun en büyük
          // olayı; kritik onun içinde kaybolursa sorun değil, tersi olursa
          // oyuncu neyin öldüğünü kaçırır.
          amount: damage,
          tint: killed
              ? DamageLabel.killTint
              : crit
              ? DamageLabel.critTint
              : (shieldHit ? DamageLabel.shieldTint : DamageLabel.hullTint),
          fontSize: killed
              ? DamageLabel.killSize
              : crit
              ? DamageLabel.critSize
              : DamageLabel.normalSize,
          // Sıyırma soluk. Kritik ile birlikte gelebilir — sarı ama soluk bir
          // rakam tam olarak olan şeyi anlatıyor: büyük vuruş, iyi savunma.
          dim: grazed,
        ),
      ),
    );
  }

  /// Gövdeye ait olmayan namlu — alien mermisi merkezden çıkar.
  static const int _alienMuzzle = -1;

  (double, double) _muzzleOf(_Tracked ship, int index) {
    // Merkez: ofset yok, dönüş yok. Alien'in yönü zaten çizimde kullanılmıyor
    // (dönüşü `RSTransform` veriyor) ve bir kaide ofseti uydurmak, mermiyi
    // yaratığın yanındaki boşluktan çıkarırdı.
    if (index == _alienMuzzle) return (ship.x, ship.y);
    final cos = math.cos(ship.angle);
    final sin = math.sin(ship.angle);
    // Nokta ZATEN dünya biriminde ([Bastion.worldMuzzles]); burada yalnız
    // geminin dönüşü uygulanır. Atlas karesi de aynı dönüşle çizildiği için
    // namlu ağzı gövdedeki yerinden ayrılmaz.
    final m = Bastion.worldMuzzles[index];
    return (ship.x + m.dx * cos - m.dy * sin, ship.y + m.dx * sin + m.dy * cos);
  }

  /// Kuyrukta bekleyen merminin çıkış noktası — namlu. Gemi mermi uçarken
  /// hareket ettiği için konum kuyruğa girerken değil ÇIKARKEN okunuyor.
  (double, double) _cikis(_Tracked shooter, _Bolt b) =>
      _muzzleOf(shooter, b.muzzle);

  // ── Çizim ──────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    for (final aim in _aims) {
      _drawAim(canvas, aim);
    }
    for (final flash in _flashes) {
      _drawFlash(canvas, flash);
    }
    _drawShieldHits(canvas);
    for (final bolt in _bolts) {
      if (!bolt.launched) continue;
      canvas
        ..save()
        ..translate(bolt.x, bolt.y)
        ..rotate(math.atan2(bolt.dy, bolt.dx));
      bolt.art.render(canvas, bolt.age);
      canvas.restore();
    }
    final lock = _lock;
    if (lock != null) _drawLock(canvas, lock);
    // Sayılar EN ÜSTTE: patlamanın altında kalan bir hasar sayısı, tam
    // okunması gereken anda okunmaz olur.
    for (final label in _labels) {
      _drawLabel(canvas, label);
    }
  }

  /// Aynı kabukta biriken darbeleri tavana çeker — EN ESKİSİNİ düşürerek.
  void _capShieldHits(int targetId) {
    var live = 0;
    for (final hit in _shieldHits) {
      if (hit.targetId == targetId) live++;
    }
    while (live > ShieldHit.maxPerShield) {
      for (var i = 0; i < _shieldHits.length; i++) {
        if (_shieldHits[i].targetId != targetId) continue;
        _shieldHits.removeAt(i);
        live--;
        break;
      }
    }
  }

  /// Kalkan darbeleri — GEMİ BAŞINA tek çağrı.
  ///
  /// Toplu olması efektin yarısı: hücrenin parlaklığı o kabuktaki BÜTÜN canlı
  /// darbelerin toplamı, yani bir yaylımın beş mermisi kabukta girişim yapıyor.
  /// Darbe başına ayrı çağrı, beş bağımsız halka çizerdi.
  ///
  /// Kabuk hedefle birlikte hareket eder: dünya konumu değil kimlik saklanıyor,
  /// çünkü darbe 0.85 saniye yaşıyor ve o sürede gemi 270 birim yol alabiliyor.
  void _drawShieldHits(Canvas canvas) {
    if (_shieldHits.isEmpty) return;
    _hitTargets.clear();
    for (final hit in _shieldHits) {
      _hitTargets.add(hit.targetId);
    }
    for (final id in _hitTargets) {
      final target = _poses[id];
      if (target == null) continue;
      _hitScratch.clear();
      for (final hit in _shieldHits) {
        if (hit.targetId == id) _hitScratch.add(hit);
      }
      canvas
        ..save()
        ..translate(target.x, target.y);
      ShieldShell.paintImpacts(
        canvas,
        radius: AtlasLayout.shieldRadiusWorld,
        // Güç YAŞAYAN değerden: darbe sürerken kalkan biterse halka da söner.
        strength: target.shield,
        hits: _hitScratch,
      );
      canvas.restore();
    }
  }

  /// Ateşi açık geminin namlu koru. Blur YOK: iki içiçe düz daire additive
  /// harmanla zaten parıltı okuyor, ve bu ekranda aynı anda onlarca gemi için
  /// çiziliyor.
  void _drawAim(Canvas canvas, _Aim aim) {
    final pulse = 0.55 + 0.45 * math.sin(_time * 17);
    final tracked = _scratch
      ..x = aim.x
      ..y = aim.y
      ..angle = aim.angle;
    _glowPaint.color = _ramp.at(0.70, 0.26 * pulse);
    _corePaint.color = _ramp.at(1, 0.8 * pulse);
    for (final i in Bastion.activeHardpoints(aim.lasers)) {
      final (mx, my) = _muzzleOf(tracked, i);
      canvas
        ..drawCircle(Offset(mx, my), 4.4 * pulse + 1, _glowPaint)
        ..drawCircle(Offset(mx, my), 1.5, _corePaint);
    }
  }

  final _Tracked _scratch = _Tracked();

  // Kare başına yeniden kullanılan tamponlar — bkz. `_drawShieldHits`.
  final Set<int> _hitTargets = {};
  final List<ShieldHit> _hitScratch = [];

  void _drawFlash(Canvas canvas, _Flash flash) {
    final t = (flash.age / flash.life).clamp(0.0, 1.0);
    final fade = 1 - t;
    final at = Offset(flash.x, flash.y);

    _glowPaint
      ..color = _ramp.at(0.68, 0.55 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, flash.radius * 0.5);
    _corePaint
      ..color = _ramp.at(1, 0.95 * fade * fade)
      ..maskFilter = null;
    canvas
      ..drawCircle(at, flash.radius * (0.55 + t * 0.85), _glowPaint)
      ..drawCircle(at, flash.radius * 0.3 * fade, _corePaint);
    _glowPaint.maskFilter = null;

    // İmha halkası: yayılan ince bir şok dalgası. Yalnız öldüren vuruşta —
    // her çarpmada olsaydı bilgi taşımazdı.
    if (!flash.ring) return;
    _ringPaint
      ..color = _ramp.at(0.86, 0.7 * fade)
      ..strokeWidth = 2.6 * fade;
    canvas.drawCircle(at, flash.radius * (0.8 + t * 3.4), _ringPaint);
  }

  void _drawLabel(Canvas canvas, _Label label) {
    final t = (label.age / _labelLife).clamp(0.0, 1.0);
    // Yükseliş hızlı başlar ve yavaşlar; sönüş ancak son üçte birde başlar —
    // sayı okunmadan solmamalı.
    final rise = _labelRise * (1 - (1 - t) * (1 - t));
    final opacity = t < 0.68 ? 1.0 : 1 - (t - 0.68) / 0.32;
    // Doğuşta kısa bir "pop": göz hareketi olmayan bir nesneyi kaçırır.
    final scale = t < 0.12 ? 0.7 + (t / 0.12) * 0.42 : 1.12 - t * 0.12;
    label.label.paint(canvas, Offset(label.x, label.y - rise), opacity, scale);
  }

  /// Hedef kilidi göstergesi.
  ///
  /// Rengi KASTEN kalkan mavisi: mermiler lav turuncusu, kilit ise bir arayüz
  /// öğesi. Aynı renkte olsalardı "neye ateş ediyorum" ile "ateş nereye
  /// gidiyor" görsel olarak ayrışmazdı.
  void _drawLock(Canvas canvas, Offset at) {
    const tint = Color(0xFF62D8FF);
    const radius = 74.0;
    final pulse = 0.5 + 0.5 * math.sin(_time * 3.2);

    _strokePaint
      ..strokeWidth = 1.4
      ..color = tint.withValues(alpha: 0.22 + pulse * 0.14);
    canvas
      ..drawCircle(at, radius, _strokePaint)
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(_time * 0.5);
    // Dört köşe ayracı: tam halka hedefi kutuya alır ve gemiyi gizler; ayraç
    // aynı bilgiyi siluete dokunmadan verir.
    _strokePaint
      ..strokeWidth = 2.4
      ..color = tint.withValues(alpha: 0.6 + pulse * 0.4);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        a - 0.22,
        0.44,
        false,
        _strokePaint,
      );
    }
    canvas.restore();
  }
}

/// Bir geminin bu karedeki çizim pozu — mermilerin izlediği hedef.
class _Tracked {
  double x = 0;
  double y = 0;
  double angle = 0;
  double shield = 1;

  /// Takılı lazer sayısı — hangi namluların mermi doğuracağını belirler.
  int lasers = 0;

  /// Alien mi. Namlu geometrisi gövdeye ÖZGÜ: Bastion'un beş kaidesi bir
  /// Void Spore'de yok ve olamaz. Alien mermisi merkezden çıkıyor.
  bool alien = false;

  /// Geminin filosu, filo bileşeninin kendi listesi (bkz. [CombatLayer.track]).
  int frame = 0;
}

/// Kabuğa inen bir vuruş, KİME indiği bilgisiyle.
///
/// [ShieldHit]'i genişletiyor çünkü sanat katmanı bir entity kimliği bilmemeli
/// — ama çizim listesi doğrudan bu nesneleri taşıyabilsin: `List<_ShieldHit>`
/// zaten bir `List<ShieldHit>`, yani kare başına kopya çıkmıyor.
class _ShieldHit extends ShieldHit {
  _ShieldHit(super.at, this.targetId);
  final int targetId;
}

/// Ateşi açık bir gemi (namlu koru için).
class _Aim {
  const _Aim(this.x, this.y, this.angle, this.lasers);
  final double x;
  final double y;
  final double angle;

  /// Kaç namlusu var — kor yalnız takılı silahlarda yanar.
  final int lasers;
}

/// Uçan bir lazer mermisi. Hasar TAŞIMAZ — [damage] yalnız varışta basılacak
/// sayıdır ve zaten uygulanmıştır.
class _Bolt {
  _Bolt({
    required this.shooterId,
    required this.muzzle,
    required this.art,
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.targetId,
    required this.tx,
    required this.ty,
    required this.delay,
    required this.hitRadius,
    required this.damage,
    required this.shieldHit,
    required this.crit,
    required this.grazed,
    required this.killed,
  });

  final int shooterId;
  final int muzzle;

  /// Merminin çizimi ve hızı — gemi ile droid mermisi ayrı.
  final BoltArt art;
  final int targetId;

  /// Merminin patladığı mesafe — kalkan ayaktaysa kabuk, değilse gövde.
  final double hitRadius;
  final int damage;
  final bool shieldHit;
  final bool crit;
  final bool grazed;
  final bool killed;

  double x;
  double y;
  double dx;
  double dy;
  double tx;
  double ty;
  double delay;
  double age = 0;
  bool launched = false;
}

class _Flash {
  _Flash(this.x, this.y, this.radius, this.life, {this.ring = false});
  final double x;
  final double y;
  final double radius;
  final double life;
  final bool ring;
  double age = 0;
}

class _Label {
  _Label({required this.x, required this.y, required this.label});
  final double x;
  final double y;
  final DamageLabel label;
  double age = 0;
}
