import 'dart:collection';
import 'dart:math' as math;

import 'package:voidspace_core/voidspace_core.dart';

import 'ship_pose.dart';

/// Kendi gemin — İSTEMCİ TARAFI TAHMİN.
///
/// Sorun şu: girdiyi sunucuya yollayıp cevabı beklemek, her tuşa basışta bir
/// gidiş-dönüş (40-60 ms) gecikme demek. Oynanmaz. Çözüm, istemcinin sunucunun
/// ne yapacağını ÖNCEDEN OYNAMASI — ve sunucu aynı `ShipSim.step`'i koştuğu
/// için tahmin neredeyse daima doğru çıkar.
///
/// "Neredeyse" kısmı mutabakat (reconciliation): snapshot geldiğinde sunucunun
/// onayladığı duruma geri sarılır ve HENÜZ ONAYLANMAMIŞ girdiler yeniden
/// oynatılır. Bu sınıfın tamamı bu tek fikrin muhasebesi.
///
/// Flame ya da Flutter bilmez — bu yüzden oyun döngüsü kurmadan test edilir.
class PredictedShip {
  PredictedShip({
    required this.world,
    required ShipSimState initial,
    int baslangicSirasi = 0,
  }) : _state = initial,
       _previous = initial,
       _seq = baslangicSirasi;

  final GameWorld world;

  /// Bu mesafenin üstündeki sapma GÖRSEL olarak düzeltilemez, ışınlanır.
  ///
  /// Neden bir eşik var: küçük sapmayı anında düzeltmek her snapshot'ta
  /// seğirme üretir, büyük sapmayı yumuşatmak ise gemiyi saniyelerce yanlış
  /// yerde gösterir. Eşik ikisinin arasındaki sınır — gövde genişliğinin
  /// birkaç katı.
  static const double hardSnapDistance = 420;

  /// Görsel sapmanın sönme hızı. ~0.4 sn'de kapanır.
  static const double _offsetDecay = 8;

  /// Sunucunun girdi kuyruğunda tutmayı HEDEFLEDİĞİMİZ derinlik.
  ///
  /// Sıfır olamaz: kuyruk boşalınca sunucu son girdiyi tekrarlar ve
  /// istemcinin tahmin etmediği bir adım atar. Çok da yüksek olamaz: her
  /// bekleyen çerçeve girdi gecikmesi demek. İki, bir paketlik titreşimi
  /// yutan en küçük değer.
  static const double _targetBuffer = 2;

  /// Üretim hızı ayarının bandı. ±%6, bir kareden fazlasında fark edilmez ama
  /// saniyeler içinde kuyruğu hedefe getirir.
  static const double _rateBand = 0.06;

  /// Tek karede en fazla kaç adım koşulur. Uzun bir donmadan sonra yüzlerce
  /// adım koşmak yerine biriken zaman SINIRLANIR — atılmaz, çünkü atmak
  /// istemcinin saatini duvar saatinden koparır ve sunucuya göre sürekli
  /// geri kalmasına yol açar.
  static const int _maxCatchUp = 5;

  /// Onaylanmamış girdi tavanı: 1 saniyelik girdi.
  ///
  /// Ağ ölünce sınırsız büyümemesi bariz sebep. Asıl sebep daha ilginç: bu
  /// sayı, tahminin otoriteden NE KADAR ayrılabileceğinin üst sınırıdır.
  /// İstemci yalnız onaylanmamış girdileri yeniden oynatır, yani daima
  /// "sunucu + en fazla bu kadar adım" kadar ilerde olur. Sunucu tökezlese
  /// bile sapma bir saniyelik yolu aşamaz.
  static const int maxUnacked = ShipSim.tickRate;

  ShipSimState _state;
  ShipSimState _previous;

  /// Onaylanmamış girdiler — geri sarma sonrası TEKRAR oynatılacak olanlar.
  final Queue<ShipInput> _unacked = Queue<ShipInput>();

  Vec2 _renderOffset = Vec2.zero;
  double _renderAngleOffset = 0;

  /// Kare başına yeniden kullanılan poz — bkz. [ShipPose] sözleşmesi.
  final ShipPose _pose = ShipPose();

  double _accumulator = 0;
  /// Yollanan son girdinin sırası.
  ///
  /// **Oturumun özelliği, geminin değil** — geçitte gemi yenileniyor ama bu
  /// sayaç TAŞINIYOR ([sonSira]). Sıfırlandığında iki taraf birden bozuluyor:
  /// sunucudaki yeni gemi de sıfırdan başladığı için geçiş anında yolda kalan
  /// tek bir eski girdi (sıfırdan büyük olduğu için) kabul ediliyor ve
  /// sunucunun sayacını kendi numarasına sıçratıyor; ondan sonra istemcinin
  /// sıfırdan sayan taze girdileri o sayının altında kalıp sessizce
  /// atılıyordu. 30 Hz'de sayacın geri tırmanması yarım dakika — ve o yarım
  /// dakika boyunca gemi hiçbir komuta cevap vermiyor.
  ///
  /// Oyuncunun gördüğü şey ağ sorunu gibi: "portaldan geçtim, gemimi hareket
  /// ettiremiyorum". Ağ kusursuz çalışıyor.
  int _seq;

  /// Yollanan son sıra — geçitte yeni tahmine devredilir.
  int get sonSira => _seq;

  /// Simüle edilen zamanın duvar saatine oranı (zaman genişletme).
  ///
  /// Sunucu tik başına TAM BİR girdi işler; istemci de tam o hızda üretmeli.
  /// Kuyruk derinliğine göre ±%6 ayarlanan bu çarpan, kuyruğun ne boşalmasına
  /// ne taşmasına izin verir — ve düzeltmelerin çoğu böylece hiç doğmaz.
  double _inputRate = 1;

  // ── Girdi toplama ────────────────────────────────────────────────────
  /// Klavye uçuş yönü. Oyun döngüsü her karede yazar.
  Vec2 axis = Vec2.zero;

  Vec2? _pendingTarget;
  bool _pendingBoost = false;

  /// Otoriter (tahmini) durum. HUD ve mantık BUNU okur, pozu değil.
  ShipSimState get state => _state;

  int get unacknowledgedCount => _unacked.length;

  /// Görsel sapmanın büyüklüğü — tahminin ne kadar tuttuğunun ölçüsü.
  double get correctionDistance => _renderOffset.length;

  /// Girdi üretim hızı çarpanı. Teşhis için: 1'den uzaklaşması, istemcinin
  /// sunucu kuyruğunu hedefe çekmeye çalıştığını gösterir.
  double get inputRate => _inputRate;

  /// Kilitli hedefin kimliği; 0 = yok. Seviye tetikli ([axis] gibi): bir kez
  /// kurulur, bozulana kadar her girdi çerçevesinde yeniden bildirilir.
  int weaponTarget = 0;

  /// Ateş açık mı.
  bool firing = false;

  void moveTo(Vec2 point) => _pendingTarget = point;

  void requestBoost() => _pendingBoost = true;

  /// Kareyi ilerlet ve YOLLANACAK girdileri döndür.
  ///
  /// Sabit adım kritik: `dt` ile adımlarsak yeniden oynatma farklı bir sonuç
  /// verir ve mutabakat her snapshot'ta gemiyi zıplatır.
  List<ShipInput> advance(double dt) {
    _accumulator += dt * _inputRate;
    final produced = <ShipInput>[];

    var guard = 0;
    while (_accumulator >= ShipSim.fixedDt && guard < _maxCatchUp) {
      _accumulator -= ShipSim.fixedDt;
      guard++;

      final input = ShipInput(
        seq: ++_seq,
        axis: axis,
        moveTarget: _pendingTarget,
        boost: _pendingBoost,
        weaponTarget: weaponTarget,
        firing: firing,
      );
      // Kenar tetikli alanlar TÜKETİLİR: bir tıklama bir hedef, bir basış bir
      // itki.
      _pendingTarget = null;
      _pendingBoost = false;

      _previous = _state;
      _state = ShipSim.step(_state, input, world);
      _unacked.add(input);
      produced.add(input);
    }
    // Biriken zamanı SINIRLA, sıfırlama: kısa bir tökezlemeden sonra sonraki
    // karede yakalanır, uzun bir donmadan sonra ise sınırsız birikmez.
    final ceiling = ShipSim.fixedDt * _maxCatchUp * 2;
    if (_accumulator > ceiling) _accumulator = ceiling;

    while (_unacked.length > maxUnacked) {
      _unacked.removeFirst();
    }

    // Sapmayı görselde sön: mantık zaten sunucunun durumunda.
    final k = math.min(1.0, dt * _offsetDecay);
    _renderOffset = _renderOffset - _renderOffset * k;
    _renderAngleOffset -= _renderAngleOffset * k;

    return produced;
  }

  /// Sunucunun otoriter durumunu uygula.
  ///
  /// Sunucunun durumunu doğrudan yazmak YANLIŞ olurdu: o durum, istemcinin o
  /// andan beri gönderdiği girdileri henüz görmemiş. Yazsaydık gemi her
  /// snapshot'ta bir gidiş-dönüş kadar geri sıçrardı — "lastik bant" denen şey
  /// tam olarak budur.
  void reconcile(SelfSnapshot snapshot) {
    while (_unacked.isNotEmpty &&
        _unacked.first.seq <= snapshot.acknowledgedSeq) {
      _unacked.removeFirst();
    }

    var replayed = snapshot.state;
    for (final input in _unacked) {
      replayed = ShipSim.step(replayed, input, world);
    }

    // Sunucunun kuyruğunu hedef derinlikte tutacak şekilde üretim hızını
    // ayarla. Düzeltmeleri yumuşatmaktan çok daha iyisi, onların doğmasını
    // engellemek.
    final error = _targetBuffer - snapshot.pendingInputs;
    _inputRate = (1 + error * 0.02).clamp(1 - _rateBand, 1 + _rateBand);

    final drift = _state.position - replayed.position;
    final angleDrift = ShipSim.normalizeAngle(_state.angle - replayed.angle);

    // ÖLÜDEN DİRİYE geçiş = yeniden doğuş. Kesin sinyal, tahmin değil.
    //
    // Mesafe eşiği tek başına yetmiyordu: doğuş noktasına 420 birimden yakın
    // ölen bir oyuncunun gemisi eşiğin altında kalıyor ve ekranda enkazdan
    // doğuş noktasına 0.4 saniye boyunca KAYARAK gidiyordu. Uzakta ölünce
    // doğru, yakında ölünce yanlış davranan bir kural, en sinsi türden:
    // hatayı ancak belirli yerlerde ölünce görüyorsun.
    final respawned = !_state.alive && replayed.alive;

    if (respawned || drift.length > hardSnapDistance) {
      // Işınlan: yeniden doğuş, uzun bir donma ya da gerçek bir ayrışma.
      // Yumuşatmak burada yalan söylemek olurdu.
      _renderOffset = Vec2.zero;
      _renderAngleOffset = 0;
      _previous = replayed;
    } else {
      // Hatayı MANTIĞA değil GÖZE taşı: durum sunucununki olur, ekrandaki
      // gemi eski yerinden yenisine kayarak gider.
      _renderOffset = _renderOffset + drift;
      _renderAngleOffset = ShipSim.normalizeAngle(
        _renderAngleOffset + angleDrift,
      );
      // Ara değer TABANI da aynı miktarda kayar.
      //
      // Bu satır olmadan düzeltme, kaydırdığı kadar pürüzsüz olmuyordu:
      // `_previous` yerinde kalınca ara değerin uzunluğu değişiyor ve poz
      // düzeltmenin GERÇEKLEŞTİĞİ karede sıçrıyordu. Aşağıdaki kaydırmayla
      // mutabakat anında ekrandaki gemi TEK PİKSEL oynamaz; yalnız nereye
      // gittiği değişir. Takılmanın büyük kısmı buradaydı.
      _previous = _previous.copyWith(
        position: _previous.position - drift,
        angle: ShipSim.normalizeAngle(_previous.angle - angleDrift),
      );
    }

    _state = replayed;
  }

  /// Işınlanmayı zorla — yeniden doğuş gibi, yumuşatmanın yanlış olduğu anlar.
  void snapTo(ShipSimState state) {
    _state = state;
    _previous = state;
    _unacked.clear();
    _renderOffset = Vec2.zero;
    _renderAngleOffset = 0;
    _inputRate = 1;
  }

  /// Çizilecek poz: iki tik arasında ara değer + sönen sapma düzeltmesi.
  ///
  /// Ara değer olmasaydı 30 Hz simülasyon 120 Hz ekranda basamaklı görünürdü.
  ShipPose get pose {
    final t = (_accumulator / ShipSim.fixedDt).clamp(0.0, 1.0);
    final delta = ShipSim.normalizeAngle(_state.angle - _previous.angle);
    return _pose..set(
      x:
          _previous.position.x +
          (_state.position.x - _previous.position.x) * t +
          _renderOffset.x,
      y:
          _previous.position.y +
          (_state.position.y - _previous.position.y) * t +
          _renderOffset.y,
      angle: ShipSim.normalizeAngle(
        _previous.angle + delta * t + _renderAngleOffset,
      ),
      thrust: _previous.thrust + (_state.thrust - _previous.thrust) * t,
      shieldFraction: _state.shieldFraction,
      alive: _state.alive,
    );
  }
}
