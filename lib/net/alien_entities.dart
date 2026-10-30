import 'dart:math' as math;

import 'package:voidspace_core/voidspace_core.dart';

/// Bir alien'in ÇİZİLECEK hâli. Yeniden kullanılır — bkz. [ShipPose]
/// sözleşmesi: sahibinden alıp kullan, saklama.
class AlienPose {
  double x = 0;
  double y = 0;
  int kind = 0;

  /// Baktığı yön (radyan). Telden GELMEZ, hareketten türetilir.
  ///
  /// Void Spore bir küre ve yönü yok; Void Leviathan'ın ise açık bir önü var
  /// (çene aşağıda, taç yukarıda) ve yan yan süzülmesi yanlış görünür.
  ///
  /// Sunucuya bir açı alanı eklemek en fazla bir bayt ederdi ama GEREKSİZ:
  /// istemcinin elinde zaten ardışık iki konum örneği var — ara değeri onlarla
  /// hesaplıyor. Yön, o iki örneğin farkı. Görsel bir özelliği tele koymak,
  /// hiç ödenmesi gerekmeyen bir bant genişliği.
  double heading = 0;

  /// Kalan can oranı. Kalkan yok — alien'in tek havuzu gövde.
  double hullFraction = 1;
}

/// Alien sürüsü — gemilerle AYNI geçmişte oynatılır.
///
/// Ayrı bir sınıf ama ayrı bir SAAT değil: oynatma tiki [RemoteEntities]'ten
/// geliyor. İki ayrı saat, bir geminin yanından geçtiği alien'in başka bir
/// anda görünmesi demekti — göz bunu "kayıyor" diye okur.
///
/// Gemilerden farkı ne taşıdığı: alien'in AÇISI yok. Void Spore bir küre;
/// kabuğu ve podları istemcinin kendi saatinde dönüyor, tel üzerinde
/// taşınacak bir yön yok.
class AlienEntities {
  /// Bu kadar tiktir güncellenmeyen iz düşürülür — ilgi alanından çıkan
  /// alien "yok" değil "görünmüyor", ama sonsuza kadar ekranda asılı kalamaz.
  ///
  /// Bu süre ÖLÜM için kullanılamaz ve bir kez öyle kullanıldı: ölen alien
  /// snapshot'tan anında çıkıyor, iz ise bir saniye daha yaşıyordu. Sonuç,
  /// oyuncunun "vurdum ama bir saniye sonra öldü" diye gördüğü gecikmeydi.
  /// Ölüm artık [remove] ile, öldüren merminin ÇARPTIĞI anda bildiriliyor.
  static const int _staleTicks = ShipSim.tickRate;

  static const int _capacity = 16;

  final Map<int, _Track> _tracks = {};
  int _latestTick = 0;

  Iterable<int> get ids => _tracks.keys;

  int get count => _tracks.length;

  void ingest(int serverTick, List<AlienSnapshot> aliens) {
    if (serverTick > _latestTick) _latestTick = serverTick;
    for (final alien in aliens) {
      (_tracks[alien.id] ??= _Track()).add(serverTick, alien);
    }
    _tracks.removeWhere(
      (_, track) => _latestTick - track.lastTick > _staleTicks,
    );
  }

  /// İzi HEMEN düşür — öldüren mermi çarptığında.
  void remove(int id) => _tracks.remove(id);

  void clear() {
    _tracks.clear();
    _latestTick = 0;
  }

  /// [id]'nin [renderTick] anındaki pozu; iz yoksa `null`.
  ///
  /// [renderTick] gemilerin oynatma saatinden gelir — bkz. sınıf açıklaması.
  AlienPose? poseOf(int id, double renderTick) {
    final track = _tracks[id];
    final samples = track?.samples;
    if (track == null || samples == null || samples.isEmpty) return null;

    if (renderTick <= samples.first.tick) {
      return _write(track.pose, samples.first.snap, track.heading);
    }
    if (renderTick >= samples.last.tick) {
      // Yön BURADA da hesaplanıyor.
      //
      // İlk yazışta yalnız ara değer dalında hesaplanıyordu ve testte
      // yakalandı: oynatma saati en yeni örneğin ucunda oturduğunda (sığ
      // tamponda olağan durum) o dala hiç girilmiyor, yön güncellenmiyor ve
      // yaratık ne yaparsa yapsın kuzeye bakıyordu.
      if (samples.length >= 2) {
        final previous = samples[samples.length - 2].snap.position;
        final last = samples.last.snap.position;
        track.steer(last.x - previous.x, last.y - previous.y, renderTick);
      }
      return _write(track.pose, samples.last.snap, track.heading);
    }

    for (var i = samples.length - 1; i > 0; i--) {
      if (samples[i - 1].tick > renderTick || renderTick > samples[i].tick) {
        continue;
      }
      final a = samples[i - 1];
      final b = samples[i];
      final span = b.tick - a.tick;
      final t = span == 0 ? 1.0 : (renderTick - a.tick) / span;
      final dx = b.snap.position.x - a.snap.position.x;
      final dy = b.snap.position.y - a.snap.position.y;
      return track.pose
        ..x = a.snap.position.x + dx * t
        ..y = a.snap.position.y + dy * t
        ..kind = b.snap.kind
        ..heading = track.steer(dx, dy, renderTick)
        // Can ara değer ALMAZ: en yeni gerçek doğru olandır, ve bir can
        // çubuğunun geçmişe doğru yumuşaması yalan söylemek olurdu.
        ..hullFraction = b.snap.hullFraction;
    }
    return _write(track.pose, samples.last.snap, track.heading);
  }

  /// Ara değer YAPILMADAN çizilen poz.
  ///
  /// [heading] ayrıca geçiliyor çünkü yön örnekte YOK — hareketten türetiliyor
  /// ve izin belleğinde duruyor. İlk yazışta burada yazılmıyordu ve sonuç
  /// testte çıktı: oynatma saati en yeni örneğin ucundayken (sığ tamponda
  /// sürekli olan durum) Leviathan yönünü kaybedip kuzeye bakıyordu.
  static AlienPose _write(AlienPose pose, AlienSnapshot s, double heading) =>
      pose
        ..x = s.position.x
        ..y = s.position.y
        ..kind = s.kind
        ..heading = heading
        ..hullFraction = s.hullFraction;
}

class _Sample {
  const _Sample(this.tick, this.snap);
  final int tick;
  final AlienSnapshot snap;
}

class _Track {
  final List<_Sample> samples = [];
  final AlienPose pose = AlienPose();

  /// Yumuşatılmış bakış yönü.
  ///
  /// Ham yön kullanılamaz: alien gezinme hedefine varınca duruyor ve fark
  /// sıfıra iniyor — o karede açı gürültüye dönüşüp yaratık kendi etrafında
  /// fırıl fırıl dönerdi. Kayda değer bir hareket YOKSA son yön korunuyor,
  /// varsa en kısa yaydan yumuşatılıyor.
  double _heading = 0;

  /// Son bilinen bakış yönü — ara değer yapılamayan karelerde de kullanılıyor.
  double get heading => _heading;

  /// Bu kadar birimin altındaki hareket yön BİLDİRMEZ.
  static const double _deadZone = 0.35;

  /// Dönüşün zaman sabiti (tik). ~4 tik = 133 ms.
  ///
  /// Yumuşatma OYNATMA SAATİNE bağlı, kare sayısına değil. İlk yazışta kare
  /// başına sabit bir oran kullanmıştım ve testte yakalandı: o hâliyle 120
  /// fps'lik bir cihazda yaratık 12 fps'lik cihazdakinin on katı hızlı
  /// dönüyordu — aynı oyun, cihaza göre farklı davranan bir animasyon.
  static const double _turnTau = 4;

  double _lastRenderTick = double.nan;

  double steer(double dx, double dy, double renderTick) {
    final previous = _lastRenderTick;
    _lastRenderTick = renderTick;
    if (dx.abs() < _deadZone && dy.abs() < _deadZone) return _heading;

    // Sprite'ın "önü" YUKARI bakıyor, o yüzden atan2(x, -y).
    final wanted = math.atan2(dx, -dy);
    if (previous.isNaN) {
      // İlk kare: yumuşatacak bir geçmiş yok, doğrudan yönüne bak. Sıfırdan
      // süzülerek dönmek, sahneye giren her yaratığı kuzeye bakarken
      // gösterirdi.
      _heading = wanted;
      return _heading;
    }

    final elapsed = (renderTick - previous).clamp(0.0, 30.0);
    final delta = math.atan2(
      math.sin(wanted - _heading),
      math.cos(wanted - _heading),
    );
    // Üstel yaklaşma: her adım büyüklüğü için doğru, yani kare hızından
    // bağımsız.
    _heading += delta * (1 - math.exp(-elapsed / _turnTau));
    return _heading;
  }

  int get lastTick => samples.isEmpty ? 0 : samples.last.tick;

  void add(int tick, AlienSnapshot snap) {
    // Sıra dışı ya da tekrarlanan örnek atılır: yeniden bağlanma sonrası eski
    // bir çerçeve ara değeri geri sardırırdı.
    if (samples.isNotEmpty && tick <= samples.last.tick) return;

    // IŞINLANMA: geçmişi at — gemilerdeki ile aynı gerekçe. Alien de ölüp
    // yuvasında yeniden doğuyor, ve iki konum arasını yumuşatmak onu da
    // haritada süzülen bir hayalete çevirir.
    if (samples.isNotEmpty) {
      final span = tick - samples.last.tick;
      final moved = snap.position.distanceTo(samples.last.snap.position);
      if (moved > Protocol.teleportDistancePerTick * span) {
        samples.clear();
      }
    }

    samples.add(_Sample(tick, snap));
    if (samples.length > AlienEntities._capacity) samples.removeAt(0);
  }
}
