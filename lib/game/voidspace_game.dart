import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../net/durum_kodu.dart';
import '../net/net_client.dart';
import '../net/net_phase.dart';
import '../net/predicted_ship.dart';
import '../perf/frame_monitor.dart';
import '../ship/ship_bloc.dart';
import '../ship/ship_event.dart';
import '../ship/ship_state.dart';
import 'art/atlas_layout.dart';
import 'art/leviathan_sprite.dart';
import 'art/ship_atlas.dart';
import 'components/alien_swarm.dart';
import 'components/combat_layer.dart';
import 'components/droid_filosu.dart';
import 'components/gecit_katmani.dart';
import 'components/ship_component.dart';
import 'components/ship_swarm.dart';
import 'components/starfield.dart';
import 'components/world_grid.dart';
import 'targeting.dart';
import 'world_geometry.dart';

/// Oyun dünyası. Tıklama BURADA yakalanır: [World] zaten dünya uzayında
/// olduğu için `event.localPosition` doğrudan hedef koordinattır — kamera
/// dönüşümünü elle çevirmeye gerek kalmaz.
class VoidspaceWorld extends World with TapCallbacks {
  /// Oyun döngüsü kurulumda bağlar. Dünyanın oyunu içeri almaması kasıtlı:
  /// bağımlılık tek yönlü (oyun → dünya → bileşen).
  void Function(Vector2)? onTapWorld;

  @override
  void onTapDown(TapDownEvent event) => onTapWorld?.call(event.localPosition);
}

/// Oyun döngüsü: kamera, girdi, ağ tahmini ve HUD'a giden kısılmış tik.
///
/// Simülasyon BURADA YOK. Eskiden `PlayerShip` uçuşu kendi koşuyordu; artık
/// uçuş `ShipSim`'de ve otoritesi sunucuda. Bu döngünün işi üç şey:
/// girdiyi toplamak, [NetClient]'ın ürettiği pozları bileşenlere dağıtmak ve
/// kalite kademesine karar vermek.
class VoidspaceGame extends FlameGame<VoidspaceWorld> with KeyboardEvents {
  VoidspaceGame({
    required this.net,
    required this.shipBloc,
    this.touchControls = false,
    double? devicePixelRatio,
  }) : devicePixelRatio =
           devicePixelRatio ??
           ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ??
           2,
       super(world: VoidspaceWorld());

  /// HUD'a durum yayınlama hızı. Simülasyon 30 Hz koşar, ekran 60+ Hz çizer,
  /// ama AYRIK durumun o hızda yayınlanması için hiçbir sebep yok: çubuklar ve
  /// şarj göstergeleri bu hızda pürüzsüz, maliyeti altıda biri.
  static const double _hudHz = 10;

  /// Kırpma payı (dünya birimi). Geminin görsel yarıçapından büyük olmalı,
  /// yoksa kenardan giren gemi görünür alana tamamen girene kadar çizilmez ve
  /// ekranın kıyısında beliriverir.
  static const double _cullMargin = 150;

  final NetClient net;
  final ShipBloc shipBloc;

  /// Dokunmatik denetim şeması. Tek oynanış farkı OTOMATİK ATEŞ: parmakla
  /// oynarken ayrı bir ateş tuşu, hem ekranda yer hem de elde parmak istiyor.
  /// Hedef seçmek ateş etmek demek.
  ///
  /// Platform buradan SORULMUYOR, kompozisyon kökünden geliyor — testte
  /// kontrol edilemeyen bir girdi olmasın (bkz. [devicePixelRatio]).
  final bool touchControls;

  /// Atlasın hangi çözünürlükte çözüleceğini belirler.
  ///
  /// Yapıcıdan geçiyor, `PlatformDispatcher`'dan doğrudan OKUNMUYOR: oyun
  /// döngüsünün içinden global platform durumuna uzanmak, testte kontrol
  /// edilemeyen bir girdi yaratır — ve tam olarak öyle oldu, atlas testte
  /// başka bir ölçekle çözülüp sonsuza kadar bekledi.
  final double devicePixelRatio;

  ShipComponent? _local;
  final Map<int, ShipComponent> _remotes = {};

  /// Droid filoları — gemiyle aynı hayat, ayrı bileşen (05.9 geometri).
  DroidFilosu? _yerelFilo;
  final Map<int, DroidFilosu> _filolar = {};

  /// EKRANDAKİ HER geminin çizicisi — kendi gemin dahil.
  ShipSwarm? _swarm;
  AlienSwarm? _aliens;

  /// Geçit katmanı — haritası ve savaş puanı BURADAN besleniyor.
  ///
  /// Bileşenin kendisi ağı tanımıyor (bkz. `architecture_test.dart`); veriyi
  /// oyuna itmek, bileşeni ağsız çizilebilir tutuyor.
  GecitKatmani? _gecitler;

  /// Leviathan şeridi — atlastan ayrı yükleniyor, sahne kurulurken hazır
  /// olmayabilir. Sahne kurulduktan sonra gelirse doğrudan sürüye takılıyor.
  LeviathanSprite? _leviathan;
  CombatLayer? _combat;

  /// Dünyanın ÖLÇÜSÜNE bağlı katmanlar — geçitte yeniden kuruluyorlar.
  Starfield? _yildizlar;
  WorldGrid? _izgara;

  /// Hedef kilidi. Seçim İSTEMCİDE yapılır; sunucu yalnız kimliği alır ve
  /// doğrular.
  final Targeting targeting = Targeting();

  /// Derleme zamanında pişirilmiş atlas. Yükleme el sıkışmadan önce, bağlantı
  /// perdesi ekrandayken yapılıyor.
  ShipAtlas? _atlas;

  /// Atlas yüklenemediyse sebebi. Perdeye yazılır; sessiz siyah ekran yok.
  String? _atlasError;

  /// Ağdan SANİYEDE alınan atış olayı.
  ///
  /// Sunucunun ürettiği ile ekranda çizilen arasındaki zincirin orta halkası:
  /// bu sıfırsa sorun ağda, doluyken mermi sıfırsa sorun çizimde.
  int shotsPerSecond = 0;
  int _shotsThisSecond = 0;
  double _shotWindow = 0;

  /// Kare ölçeri — verilirse sahne yoğunluğu ona bildirilir.
  ///
  /// Zorunlu DEĞİL: oyun döngüsü ölçüm olmadan da koşmalı, yoksa testler bir
  /// ölçer kurmak zorunda kalır.
  FrameMonitor? frames;

  double _hudAccumulator = 0;
  bool _sceneBuilt = false;

  /// Sahnenin kurulduğu DÜNYA — geçit sonrası tazelemenin ölçütü.
  ///
  /// Sahne bir kez kuruluyordu ve `_sceneBuilt` hiç sıfırlanmıyordu. Bölge
  /// haritaları AYNI ÖLÇÜDE DEĞİL: bant sayısı arttıkça büyüyorlar (15.964 ×
  /// 10.643 ve 19.552 × 13.034 diye iki ölçü dönüşümlü geliyor). Geçitten
  /// büyük bir haritaya geçen oyuncunun kamerası eski haritanın dikdörtgenine
  /// kilitli kalıyor, gemi o sınırın ötesine çıkınca kamera onu TAKİP
  /// EDEMİYORDU: ekran duruyor, gemi kaçıyor ve oyuncunun gördüğü şey
  /// "gemimi hareket ettiremiyorum".
  ///
  /// Belirtinin ağ gibi görünmesi tuzağın kendisi: her şey doğru gidiyor,
  /// yalnız kamera yanlış yere bakıyor.
  GameWorld? _kuruluDunya;

  @override
  Color backgroundColor() => const Color(0xFF03050C);

  /// HER OYUNCU AYNI KADAR DÜNYA GÖRÜR — ölçek ekrandan TÜRETİLİYOR.
  ///
  /// Zoom uzun süre sabit 0,6 idi ve bu, görünen alanı ekranın insafına
  /// bırakmak demekti: masaüstü penceresi (1280×720) 2133 × 1200 birim
  /// görürken telefon (844×390) 1407 × 650 görüyordu — dikeyde **%46 daha
  /// az**. Telefondaki oyuncu "ekranda çok az şey görünüyor" derken haklıydı
  /// ve sebep kameranın yakınlığı değil, ölçeğin ekrana hiç bakmamasıydı.
  ///
  /// **Bu bir konfor meselesi değil ADALET meselesi.** Oyun çok oyunculu:
  /// daha geniş gören oyuncu düşmanı önce görüyor, kaçacak yeri önce
  /// buluyor. Cihaz farkının rekabete girmesi, ekran boyutunu bir stat
  /// yapardı.
  ///
  /// Kural: [_gorusKutusu] her ekranda TAMAMEN görünür. Ölçek iki eksenin
  /// SIĞDIRANINDAN çıkıyor (`min`), yoksa kutunun bir kenarı taşardı. Geniş
  /// bir telefon (2,16:1) böylece fazladan GENİŞLİK görüyor — kimseden az
  /// görmüyor, çünkü kutunun tamamı içeride.
  ///
  /// Alt sınır neden yok: sığdırmak zorunlu, ve bir cihaz kutuyu ancak çok
  /// küçük bir ölçekle sığdırıyorsa doğru cevap gemiyi büyütmek değil, o
  /// ekranda gerçekten daha az görünür olduğunu kabul etmek — ama üst sınır
  /// VAR: küçük bir pencerede ölçek 1'i aşarsa doku büyütülür ve bulanıklaşır.
  double get _kameraOlcegi {
    final boyut = size;
    if (boyut.x <= 0 || boyut.y <= 0) return _olcekTavani;
    final olcek = math.min(
      boyut.x / _gorusKutusu.width,
      boyut.y / _gorusKutusu.height,
    );
    return olcek.clamp(0.05, _olcekTavani);
  }

  /// Her oyuncunun EN AZ göreceği dünya dikdörtgeni (dünya birimi).
  ///
  /// Sayı keyfî değil: bugünkü masaüstü deneyiminin ta kendisi (1280×720
  /// pencerede 0,6 ölçek). Yani masaüstünde hiçbir şey değişmiyor, telefon
  /// ona yetişiyor. Değiştirilirse HERKESİN görüşü değişir — tek sayı, tek
  /// karar.
  static const Size _gorusKutusu = Size(1280 / 0.6, 720 / 0.6);

  /// Ölçek tavanı: dokular 0,6 için pişirildi, üstü büyütme demek.
  static const double _olcekTavani = 0.6;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Pencere ya da yönelim değişince ölçek yeniden türetiliyor: sabit bir
    // sayı olsaydı telefonu yan çevirmek görüşü bozardı.
    camera.viewfinder.zoom = _kameraOlcegi;
  }

  @override
  Future<void> onLoad() async {
    debugPrint('[boot] onLoad başladı');
    camera.viewfinder.zoom = _kameraOlcegi;
    world.onTapWorld = _onTapWorld;
    // Atlas, cihazın piksel oranına göre çözülür: keskinlikten kaybetmeden
    // dokuyu küçültmek, düşük yoğunluklu ekranlarda megabaytlar demek.
    // Atlas yüklemesi BEKLENMİYOR.
    //
    // `onLoad` tamamlanana kadar Flame hiçbir şey çizmiyor — HUD'ı ve bağlantı
    // perdesini de. Yüklemeyi burada beklemek, dokunun yavaş çözüldüğü ya da
    // hiç çözülemediği her durumda oyuncuya TEK KELİME ETMEYEN siyah bir ekran
    // gösteriyordu; teşhis edilmesi en zor arıza türü.
    //
    // Doğru sıra: arayüz hemen çizilsin, sahne atlas hazır olunca kurulsun,
    // yükleme başarısız olursa sebebi perdede yazsın.
    unawaited(_loadAtlas());
    debugPrint('[boot] onLoad bitti');
  }

  /// Hata YUTULMAZ ama yeniden de FIRLATILMAZ.
  ///
  /// `unawaited` bir future'ı yok sayar; içinden çıkan hata sahipsiz kalır ve
  /// zone'un hata işleyicisine düşer. Sebebi perdeye taşımak, onu sessiz bir
  /// çökmeye çevirmekten çok daha iyi.
  Future<void> _loadAtlas() async {
    try {
      _atlas = await ShipAtlas.load(
        devicePixelRatio: devicePixelRatio,
        zoom: camera.viewfinder.zoom,
      );
      debugPrint('[boot] atlas hazır');
    } on Object catch (error) {
      _atlasError = DurumKodu.atlasYuklenemedi.kod;
      debugPrint('[boot] ATLAS HATASI: $error');
    }
    unawaited(_loadLeviathan());
  }

  /// Void Leviathan'ın şeridi — atlastan AYRI ve BLOKLAMIYOR.
  ///
  /// Hatası perdeye taşınmıyor, yalnız günlüğe yazılıyor: tek bir alien
  /// türünün dokusu gelmediği için oyunun tamamını durdurmak, küçük bir
  /// eksikliği toplam bir arızaya çevirmek olurdu. O tür o oturumda
  /// görünmüyor, gerisi çalışıyor.
  Future<void> _loadLeviathan() async {
    try {
      final sprite = await LeviathanSprite.load(
        devicePixelRatio: devicePixelRatio,
        zoom: camera.viewfinder.zoom,
      );
      _leviathan = sprite;
      _aliens?.leviathan = sprite;
      debugPrint('[boot] leviathan hazır');
    } on Object catch (error) {
      debugPrint('[boot] LEVIATHAN HATASI: $error');
    }
  }

  @override
  void update(double dt) {
    // SIRA KRİTİK ve tek oyunculu sürümde önemi yoktu.
    //
    // `super.update` kamerayı da günceller (takip davranışı bileşen ağacında
    // yaşıyor). Pozları ondan SONRA uygulamak, kameranın bir önceki karenin
    // konumunu takip etmesi demekti: gemi ekranda sabit durması gerekirken
    // her karede bir kare geriden gelen kameraya göre titriyordu. Tek
    // oyuncuda gemi kendi `update`'inde hareket ettiği için bu sıra doğaldı;
    // konum artık dışarıdan geldiği için açıkça kurulmak zorunda.
    net.update(dt);

    _buildSceneIfReady();
    _syncLocal();
    _syncRemotes();
    _applyPoses();
    // Geçit katmanı ağı tanımıyor: haritası ve savaş puanı buradan besleniyor.
    // Harita geçitte DEĞİŞİYOR, savaş puanı hangar işlemlerinde — ikisi de
    // kare içinde değişebiliyor, yani her karede itilmek zorunda.
    _gecitler
      ?..harita = net.harita
      ..br = net.hangar?.br ?? 0
      ..seviye = net.hangar?.seviye;
    // Vuruşlar TÜKETİLİR. Sahne henüz kurulmadıysa da düşürülür: birikmiş
    // olaylar dünyaya girer girmez topluca patlardı.
    net.clearShots();

    super.update(dt);

    // POZ HER KAREDE, durum on Hz'de.
    //
    // Minimap sürekli bir konum gösteriyor; on adım saniyede 120 Hz bir
    // ekranda takılma olarak okunuyor. Bütün HUD'ı 120 Hz'de yeniden kurmak
    // ise pahalı ve gereksiz — kalkan yüzdesi o hızda tazelenmeyi hak
    // etmiyor. Ayrılan şey doğruluk değil yayın sıklığı: ikisi de aynı
    // karede aynı kaynaktan okunuyor (bkz. [ShipBloc.poz]).
    final yerel = net.ship?.state;
    if (yerel != null) {
      shipBloc.poz.value = GemiPozu(yerel.position, yerel.angle);
    }

    _hudAccumulator += dt;
    if (_hudAccumulator < 1 / _hudHz) return;
    _hudAccumulator = 0;
    // Yoğunluk ORAN olarak: anlık mermi sayısı kısa ömürlü olduğu için
    // örneklemede çoğu zaman sıfır çıkıyor ve savaşı yok gibi gösteriyor.
    _shotWindow += 1 / _hudHz;
    if (_shotWindow >= 1) {
      _shotWindow = 0;
      shotsPerSecond = _shotsThisSecond;
      _shotsThisSecond = 0;
    }
    frames?.sahne = SahneOlcumu(
      gemi: _swarm?.submittedShips ?? 0,
      alien: _aliens?.submitted ?? 0,
      alinan: net.shotsReceived,
      tuketilen: shotsPerSecond,
      mermiSn: _combat?.boltsPerSecond ?? 0,
      vurusSn: _combat?.hitsPerSecond ?? 0,
      havada: _combat?.debugBoltCount ?? 0,
    );
    final blocked = _atlasError;
    final view = camera.visibleWorldRect;
    shipBloc.add(
      ShipSynced(
        // Atlas yoksa dünyada DEĞİLİZ: ağ bağlansa bile çizilecek hiçbir şey
        // olmadığı için perdenin kalkması yalan olurdu.
        phase: blocked == null ? net.phase : NetPhase.rejected,
        state: blocked == null ? net.ship?.state : null,
        pingMs: net.rttMs,
        nearby: _remotes.length,
        message: blocked ?? net.statusMessage,
        world: net.world,
        viewSize: Vec2(view.width, view.height),
        blips: _mapBlips(),
        alienBlips: _alienBlips(),
      ),
    );
  }

  /// Alien sürüsünü bu karenin toplu çizimine kat.
  ///
  /// Kırpma gemilerdekiyle aynı sebeple: ilgi alanı 2600 birim, telefonda
  /// dikey görüş ~670. Görünmeyeni toplu çizime katmak, mobil GPU'da bedeli
  /// en yüksek şeyi — saydam dolgu — boşuna ödemek.
  void _submitAliens({required Rect view}) {
    final swarm = _aliens;
    if (swarm == null) return;
    swarm.begin();
    final tick = net.remotes.renderTick;
    for (final id in net.aliens.ids) {
      final pose = net.aliens.poseOf(id, tick);
      if (pose == null) continue;
      // İzleme kırpmaya TABİ DEĞİL: ekranın dışına çıkan bir alien'e uçan
      // mermi onu izlemeye devam etmeli, yoksa son görüldüğü yerde patlar.
      _combat?.track(id, pose.x, pose.y, 0, 0);
      if (!view.contains(Offset(pose.x, pose.y))) continue;
      swarm.submit(
        pose.x,
        pose.y,
        id,
        pose.hullFraction,
        kind: pose.kind,
        heading: pose.heading,
      );
    }
  }

  /// Minimap'e giden izler.
  ///
  /// Saniyede on kez kuruluyor, kare başına değil: harita HUD hızında
  /// yaşıyor. Poz nesneleri yeniden kullanıldığı için burada KOPYALANMALI —
  /// saklanan bir poz bir sonraki karede üzerine yazılır ve Bloc'un durumu
  /// altından değişirdi.
  List<MapBlip> _mapBlips() {
    final blips = <MapBlip>[];
    for (final id in net.remotes.ids) {
      final pose = net.remotes.poseOf(id);
      if (pose == null) continue;
      blips.add(MapBlip(id: id, x: pose.x, y: pose.y, alive: pose.alive));
    }
    return blips;
  }

  /// Minimap'e giden alien izleri.
  List<MapBlip> _alienBlips() {
    final tick = net.remotes.renderTick;
    final blips = <MapBlip>[];
    for (final id in net.aliens.ids) {
      final pose = net.aliens.poseOf(id, tick);
      if (pose == null) continue;
      blips.add(MapBlip(id: id, x: pose.x, y: pose.y, alive: true));
    }
    return blips;
  }

  /// Zemin ve ızgara YALNIZ dünya ölçüleri sunucudan geldikten sonra kurulur.
  ///
  /// İstemcinin kendi sabitiyle önden kurup sonra düzeltmek cazip ama yanlış:
  /// sunucu haritayı büyütmüşse ızgara bir kare boyunca yanlış yerde olur ve
  /// yıldız alanının yeniden pişirilmesi ~3300 çizim işlemi demek.
  void _buildSceneIfReady() {
    final atlas = _atlas;
    if (atlas == null || net.phase != NetPhase.playing) return;
    if (_sceneBuilt) {
      _dunyayiTazele();
      return;
    }
    _sceneBuilt = true;
    _kuruluDunya = net.world;
    final swarm = ShipSwarm(atlas: atlas);
    _swarm = swarm;
    final aliens = AlienSwarm(atlas: atlas, leviathan: _leviathan);
    _aliens = aliens;
    final combat = CombatLayer();
    _combat = combat;
    world.addAll([
      _yildizlar = Starfield(world: net.world),
      _izgara = WorldGrid(world: net.world),
      _gecitler = GecitKatmani(
        harita: net.harita,
        br: net.hangar?.br ?? 0,
        seviye: net.hangar?.seviye,
      ),
      aliens,
      swarm,
      combat,
    ]);
    camera.setBounds(
      Rectangle.fromRect(net.world.bounds),
      considerViewport: true,
    );
  }

  /// Harita DEĞİŞTİYSE dünyaya bağlı olan her şeyi yeniden kur.
  ///
  /// Sahnenin tamamı değil, yalnız ölçüye bağlı üç şey: kamera sınırı, yıldız
  /// alanı ve ızgara. Gemiler, yaratıklar ve savaş katmanı ölçüden bağımsız —
  /// onları da yıkmak, geçitte bir kare boyunca boş bir uzay göstermek
  /// olurdu. Geçit katmanı zaten her karede tazeleniyor.
  ///
  /// Ölçüt DÜNYA, harita kimliği değil: aynı ölçüdeki iki bölge arasında
  /// geçerken yeniden pişirmenin bir kazancı yok ve yıldız alanı pahalı.
  void _dunyayiTazele() {
    final dunya = net.world;
    final onceki = _kuruluDunya;
    if (onceki != null &&
        onceki.width == dunya.width &&
        onceki.height == dunya.height &&
        onceki.margin == dunya.margin) {
      return;
    }
    _kuruluDunya = dunya;

    _yildizlar?.removeFromParent();
    _izgara?.removeFromParent();
    world.addAll([
      _yildizlar = Starfield(world: dunya),
      _izgara = WorldGrid(world: dunya),
    ]);
    camera.setBounds(
      Rectangle.fromRect(dunya.bounds),
      considerViewport: true,
    );
  }

  void _syncLocal() {
    final predicted = net.ship;
    if (predicted == null) {
      // Bağlantı koptu: gemiyi kaldır ama sahneyi bırakma — yeniden bağlanma
      // saniyeler içinde, ve boş uzayı yeniden pişirmenin anlamı yok.
      _local?.removeFromParent();
      _local = null;
      _yerelFilo?.removeFromParent();
      _yerelFilo = null;
      return;
    }
    if (_local != null) return;

    final ship = ShipComponent(isLocal: true)
      ..position = Vector2(
        predicted.state.position.x,
        predicted.state.position.y,
      );
    _local = ship;
    world.add(ship);
    final filo = DroidFilosu();
    _yerelFilo = filo;
    world.add(filo);
    camera.follow(ship);
  }

  void _syncRemotes() {
    // İlgi alanından çıkan ya da bağlantısı kopan gemiler.
    _remotes.removeWhere((id, component) {
      if (net.remotes.poseOf(id) != null) return false;
      component.removeFromParent();
      _filolar.remove(id)?.removeFromParent();
      return true;
    });

    for (final id in net.remotes.ids) {
      if (_remotes.containsKey(id)) continue;
      final component = ShipComponent(isLocal: false, name: net.names[id]);
      _remotes[id] = component;
      world.add(component);
      final filo = DroidFilosu();
      _filolar[id] = filo;
      world.add(filo);
    }
  }

  void _applyPoses() {
    // Savaş katmanının karesi ERKEN açılır — aşağıdaki erken dönüşten de
    // önce. Bağlantı koptuğunda `_local` düşüyor ve fonksiyon oracıkta
    // dönüyor; `begin()` orada kalsaydı kilit ayracı ile namlu koru boşlukta
    // DONAR ve yeniden bağlanana kadar öyle kalırdı.
    final combat = _combat?..begin();

    final local = _local;
    final predicted = net.ship;
    final swarm = _swarm;
    if (local == null || predicted == null || swarm == null) return;

    swarm.begin();
    _submitAliens(view: camera.visibleWorldRect.inflate(_cullMargin));

    final pose = predicted.pose;
    local.applyPose(pose);
    _yerelFilo?.hedefle(
      x: pose.x,
      y: pose.y,
      aci: pose.angle,
      droidler: net.droidler[net.entityId] ?? const [],
      formasyon: net.formasyonlar[net.entityId] ?? 0,
    );
    swarm.submit(
      pose,
      net.entityId,
      lasers: net.lasers[net.entityId] ?? 0,
      govde: net.govdeler[net.entityId] ?? 0,
    );
    combat?.track(
      net.entityId,
      pose.x,
      pose.y,
      pose.angle,
      pose.shieldFraction,
      net.lasers[net.entityId] ?? 0,
    );

    // GÖRÜNÜR ALAN KIRPMASI.
    //
    // İlgi alanı yarıçapı 2600 birim ama telefonda dikey görüş alanı ~670
    // birim genişliğinde: sunucunun yolladığı gemilerin çoğu ekranda DEĞİL.
    // Onları da toplu çizime katmak, mobil GPU'da bedeli en yüksek şeyi —
    // saydam dolgu — boşuna ödemek demek.
    final view = camera.visibleWorldRect.inflate(_cullMargin);

    // Uzak gemiler: poz araması (ara değer, iki örnek arası tarama) gemi
    // başına BİR kez yapılır — hem düğüm hem toplu çizici aynı sonucu okur.
    for (final entry in _remotes.entries) {
      final remotePose = net.remotes.poseOf(entry.key);
      if (remotePose == null) continue;
      final node = entry.value..applyPose(remotePose);
      final visible = view.contains(Offset(remotePose.x, remotePose.y));
      node.onScreen = visible;
      _filolar[entry.key]
        ?..gorunur = visible
        ..hedefle(
          x: remotePose.x,
          y: remotePose.y,
          aci: remotePose.angle,
          droidler: net.droidler[entry.key] ?? const [],
          formasyon: net.formasyonlar[entry.key] ?? 0,
        );
      final barrels = net.lasers[entry.key] ?? 0;
      if (visible) {
        swarm.submit(
          remotePose,
          entry.key,
          lasers: barrels,
          govde: net.govdeler[entry.key] ?? 0,
        );
      }
      // İzleme kırpmaya TABİ DEĞİL: ekranın dışına çıkan bir hedefe uçan
      // mermi onu izlemeye devam etmeli, yoksa son görüldüğü yerde patlar.
      combat?.track(
        entry.key,
        remotePose.x,
        remotePose.y,
        remotePose.angle,
        remotePose.shieldFraction,
        barrels,
      );
    }

    _applyCombat(predicted);
  }

  /// Kilidi tazeler, namlu korunu sürer ve sunucunun çözdüğü yaylımları
  /// sahneye kor.
  void _applyCombat(PredictedShip predicted) {
    final combat = _combat;
    if (combat == null) return;

    // Kilit her karede doğrulanır: hedef ölmüş, ayrılmış ya da ilgi alanından
    // çıkmış olabilir. Sunucu da aynı kararı verir — iki uç böylece anlaşır.
    targeting.validate((id) => _targetPosition(id) != null);
    net.ship?.weaponTarget = targeting.selected;
    if (touchControls) {
      // Dokunmatikte ayrı ateş tuşu YOK: hedef seçmek ateş etmektir. Klavyede
      // F anlamlı çünkü bedava; parmakla oynarken üçüncü bir düğme hem ekranda
      // yer hem de elde parmak istiyor.
      net.ship?.firing = targeting.hasTarget;
    } else if (!targeting.hasTarget) {
      net.ship?.firing = false;
    }

    final lock = targeting.hasTarget
        ? _targetPosition(targeting.selected)
        : null;
    if (lock != null) combat.setLock(lock.x, lock.y);

    // Namlu koru TAHMİNDEN: F'ye basıldığı karede yanar. Mermiler otoriter
    // olduğu için bir gidiş-dönüş gecikmeli çıkıyor; bu parlama o boşluğu
    // dolduran şey — ve yalan söylemiyor, çünkü ateşin AÇIK olduğu gerçekten
    // istemcinin bildiği bir şey.
    if (predicted.firing && targeting.hasTarget && predicted.state.alive) {
      final self = predicted.pose;
      combat.aim(self.x, self.y, self.angle, net.lasers[net.entityId] ?? 0);
    }
    for (final id in net.remotes.ids) {
      final shooter = net.remotes.poseOf(id);
      if (shooter == null || !shooter.firing || !shooter.alive) continue;
      combat.aim(shooter.x, shooter.y, shooter.angle, net.lasers[id] ?? 0);
    }

    // Mermiler ve hasar sayıları YALNIZ sunucunun çözdüğü vuruşlardan doğar.
    //
    // Kendi atışlarımı tahmin etmek daha çevik hissettirirdi ve yanlış
    // olurdu: atış anını sunucudaki bekleme sayacı belirliyor, ve o sayaç
    // menzil doğrulamasına bağlı olduğu için saf `ShipSim.step` içinden
    // üretilemiyor. Tahmin etseydik menzilden çıkan bir hedefe hayalet
    // mermiler uçar, ekrandaki hasar ile inen hasar ayrışırdı.
    _shotsThisSecond += net.shots.length;
    for (final shot in net.shots) {
      combat.fire(
        shooterId: shot.shooterId,
        targetId: shot.targetId,
        damage: shot.damage,
        shieldHit: shot.shieldHit,
        killed: shot.killed,
        crit: shot.crit,
        grazed: shot.grazed,
        roket: shot.roket,
      );
    }

    // Ölen alienler MERMİ ÇARPINCA kaybolur.
    //
    // Sunucu onları vuruş anında snapshot'tan çıkarıyor; istemci ise izleri
    // ancak bir saniye sessizlikten sonra düşürüyordu (`_staleTicks`) ve
    // ekranda bir saniyelik bir ceset kalıyordu — "vurdum ama sonra öldü"
    // diye görünen şey buydu. O bekleme İLGİ ALANINDAN ÇIKMA içindir, ölüm
    // için değil.
    for (final id in combat.takeKills()) {
      if (Protocol.isAlienId(id)) net.aliens.remove(id);
    }
  }

  /// Dünyaya tıklandı: önce HEDEF, olmazsa hareket.
  ///
  /// Sıra kritik. Tersi olsaydı canavara tıklayan oyuncu onu seçer ve aynı
  /// anda üstüne uçardı. Tıklamanın anlamını altındaki şey belirler,
  /// altındaki boşluk değil.
  ///
  /// DOKUNMATİKTE HİÇ ÇALIŞMIYOR. Telefonda bu yolun iki ucu da sahipsiz:
  /// hareketi joystick sürüyor, ateşi hedef kilidi açıyor. Geriye tek bir
  /// etki kalıyordu — parmağın değdiği yerdeki hedefi SESSİZCE seçmek. Parmak
  /// payı dokunmatikte 30 birim (`_tapSlack`) ve yaratık yarıçapıyla birlikte
  /// ~50 birime çıkıyor; kalabalıkta ekrana atılan hemen her tık yeni bir
  /// hedef yakalıyor, otomatik ateş de anında ona dönüyordu. Oyuncunun
  /// gördüğü şey buydu: kilit kendi kendine geziniyor. Dokunmatikte hedef
  /// YALNIZ HEDEF düğmesiyle değişiyor.
  void _onTapWorld(Vector2 point) {
    if (touchControls) return;
    final at = Vec2(point.x, point.y);
    if (_pickTarget(at)) return;
    net.ship?.moveTo(at);
  }

  /// Parmak/imleç payı (dünya birimi).
  ///
  /// Dokunmatikte cömert: parmak ucu ekranda ~9 mm. Pay DÜNYA biriminde
  /// ölçülüyor ama parmak EKRANDA duruyor, yani ölçek değişince payın da
  /// değişmesi gerekiyor — sabit 30 birim, 0,6 ölçeğe gömülü bir sayıydı.
  /// Telefon uzaklaştıkça (ölçek düşünce) aynı parmak daha çok dünya
  /// kaplıyor; pay ölçeğe bölünmezse oyuncu ıskalamaya başlardı.
  ///
  /// Bölen ölçek DEĞİL ölçeğin tavana oranı: 0,6'da eski davranış birebir
  /// korunuyor (30 ve 10), altına inildikçe pay büyüyor.
  double get _tapSlack {
    final taban = touchControls ? 30.0 : 10.0;
    final olcek = camera.viewfinder.zoom;
    if (olcek <= 0) return taban;
    return taban * (_olcekTavani / olcek);
  }

  bool _pickTarget(Vec2 at) {
    _targetScratch
      ..clear()
      ..addAll(net.remotes.ids)
      ..addAll(net.aliens.ids);
    return targeting.pick(at, _targetScratch, _targetPosition, _tapRadius);
  }

  /// Tıklamanın hedefe sayıldığı yarıçap.
  ///
  /// Kaynak KADRO, eski `AlienStats.byKind` değil. O metod tanımadığı her
  /// kimliği sessizce spore'a düşürüyor ve kadro geldiğinde serpilen on beş
  /// yaratığın HİÇBİRİNİ çözemez oldu: gerçek yarıçaplar 14..19 iken hepsi
  /// spore'un 24'ünü alıyordu — tıklama alanı yaratıktan %26..71 büyüktü,
  /// yani yaratığın yanına basmak da onu hedefliyordu.
  double _tapRadius(int id) {
    if (Protocol.isAlienId(id)) {
      final pose = net.aliens.poseOf(id, net.remotes.renderTick);
      final yaricap = pose == null
          ? AlienStats.spore.radius
          : YaratikKadrosu.yaricapFor(pose.kind);
      return yaricap + _tapSlack;
    }
    // Gemide tıklanabilir alan KALKAN KABUĞU: ekranda görünen dış sınır o,
    // ve oyuncu gördüğü şeye tıklıyor.
    return AtlasLayout.shieldRadiusWorld + _tapSlack;
  }

  /// Sıradaki hedefe geç — oyuncular VE alienler arasında.
  ///
  /// İki kimlik uzayı [Protocol.alienIdBase] ile ayrıldığı için tek listede
  /// karışabiliyorlar, ve karışmaları gerekiyor: Tab'ın sorduğu soru
  /// "sıradaki HEDEF ne", "sıradaki oyuncu kim" değil.
  ///
  /// AÇIK (public), çünkü iki çağıranı var: Tab tuşu ve dokunmatik HEDEF
  /// düğmesi. Düğme HUD'da yaşıyor ve HUD oyuna bakamıyor — kompozisyon kökü
  /// bu metodu `AppScope.onCycleTarget` olarak geçiriyor.
  void cycleTarget() {
    final predicted = net.ship;
    if (predicted == null) return;
    _targetScratch
      ..clear()
      ..addAll(net.remotes.ids)
      ..addAll(net.aliens.ids);
    targeting.cycle(_targetScratch, predicted.state.position, _targetPosition);
  }

  /// Kare başına yeniden kullanılan aday listesi.
  final List<int> _targetScratch = [];

  /// Hedefin dünya konumu — gemi ya da alien; ölü/kayıp ise `null`.
  ///
  /// Kilit doğrulaması da bunu kullanıyor: "hedef hâlâ var mı" sorusunun tek
  /// bir cevabı olmalı, yoksa Tab'ın seçebildiği ama kilidin bıraktığı bir
  /// hedef sınıfı doğar.
  Vec2? _targetPosition(int id) {
    if (Protocol.isAlienId(id)) {
      final pose = net.aliens.poseOf(id, net.remotes.renderTick);
      return pose == null ? null : Vec2(pose.x, pose.y);
    }
    final pose = net.remotes.poseOf(id);
    return pose == null || !pose.alive ? null : Vec2(pose.x, pose.y);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    var dx = 0.0;
    var dy = 0.0;
    if (_any(
      keysPressed,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.arrowUp,
    )) {
      dy -= 1;
    }
    if (_any(
      keysPressed,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.arrowDown,
    )) {
      dy += 1;
    }
    if (_any(
      keysPressed,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.arrowLeft,
    )) {
      dx -= 1;
    }
    if (_any(
      keysPressed,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowRight,
    )) {
      dx += 1;
    }
    net.ship?.axis = Vec2(dx, dy);

    // İtki YALNIZ basış anında. `keysPressed.contains(space)` demek, boşluk
    // basılı kaldığı sürece HER tuş olayında (tekrar olayları ve başka tuşların
    // basılıp bırakılması dahil) yeniden tetiklemek olurdu — tek bir basış
    // sessizce iki şarj harcıyordu.
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      net.ship?.requestBoost();
    }

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.tab:
          cycleTarget();
        case LogicalKeyboardKey.keyF:
          // AÇMA/KAPAMA, basılı tutma değil: PvP'de tuşu saniyelerce basılı
          // tutmak elle yorucu ve hiçbir karar eklemiyor.
          final ship = net.ship;
          if (ship != null) ship.firing = !ship.firing && targeting.hasTarget;
        case LogicalKeyboardKey.escape:
          targeting.clear();
          net.ship?.firing = false;
      }
    }
    return dx == 0 && dy == 0 ? KeyEventResult.ignored : KeyEventResult.handled;
  }

  static bool _any(
    Set<LogicalKeyboardKey> pressed,
    LogicalKeyboardKey a,
    LogicalKeyboardKey b,
  ) => pressed.contains(a) || pressed.contains(b);
}
