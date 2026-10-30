import 'package:voidspace_core/voidspace_core.dart';

import 'ship_pose.dart';

/// Diğer oyuncular — GEÇMİŞTE oynatılır.
///
/// Uzak bir gemiyi son snapshot'ta geldiği yere koymak, saniyede 30 kez
/// ışınlanan bir gemi demek: paketler asla düzgün aralıklarla gelmez. Çözüm
/// oyunun kabul ettiği bir hile: ötekiler bir tampon kadar GERİDEN gösterilir,
/// böylece her an elde iki gerçek örnek olur ve aradaki kare hesaplanır.
///
/// Tamponun derinliği SABİT DEĞİL, ölçülen titreşime göre uyarlanıyor —
/// gerekçesi ve ölçümü için bkz. [_delay]. En az 66 ms, en çok 200 ms.
///
/// Kestirim (extrapolation) SINIRLI: örnekler bittiğinde son hız birkaç tik
/// sürdürülür, sonra durulur. Sınırsız kestirim duran bir gemiyi duvarın içine
/// sürer ve paket gelince geri çeker — donmaktan çirkin. Ama TCP'de tek bir
/// yeniden gönderim arkasındaki HER ŞEYİ bekletiyor (head-of-line blocking) ve
/// 500 ms'lik bir boşlukta tampon ne kadar derin olursa olsun yetişemiyor;
/// orada donmak yerine kısa süre devam etmek hem daha doğru hem daha az
/// görünür. Bkz. [_maxExtrapolationTicks].
class RemoteEntities {
  /// Oynatma saati hedeften bu kadar SAPARSA yumuşatma bırakılır ve atlanır
  /// (sekme arka planda kaldı, ağ bir saniye durdu).
  ///
  /// Tampon derinliğine BAĞLI olmak zorunda: sabit 8 tik, tampon 2 tikken
  /// doğruydu ama tampon 12 tike çıkabildiğinde uyarlamanın kendisi bu eşiği
  /// aşardı — yani tampon derinleşirken gemiler ışınlanırdı. Düzeltmeye
  /// çalıştığı şeyi üreten bir eşik.
  double get _resyncTicks => _delay * 2 + 6;

  /// Bu kadar tiktir güncellenmeyen iz düşürülür. İlgi alanından çıkan gemi
  /// "yok" değil "görünmüyor" — ama sonsuza kadar ekranda asılı kalamaz.
  static const int _staleTicks = ShipSim.tickRate;

  /// Ara değer tamponunun EN AZ derinliği (tik).
  ///
  /// Taban ORTAK pakette: "iki örnek gerekir" ara değerin tanımı, istemcinin
  /// tercihi değil.
  static const double _minDelay = Protocol.interpolationDelayTicks * 1.0;

  /// Tamponun EN ÇOK derinliği (tik) — 400 ms.
  ///
  /// Tampon derinliği bedava değil: her tik, uzak gemileri o kadar daha
  /// GEÇMİŞTE görmek demek. Tavan bu yüzden var — ama sayısı keyfî değil,
  /// OYUNUN KENDİ ÖLÇÜLERİNDEN türüyor:
  ///
  /// 12 tik = 400 ms. Bir gemi 320 birim/sn gittiğine göre 400 ms'lik görsel
  /// gecikme, hedefi en çok **128 birim** geride göstermek demek. Silah menzili
  /// 1400, yani hata menzilin **%9'u** — ve bu, gecikmenin menzil sınırında
  /// zaten ürettiği belirsizlik bandıyla (ölçüldü: 160 ms'de %6, 400 ms'de
  /// %35) aynı büyüklük mertebesinde. Yani tampon, oyunun halihazırda
  /// taşıdığı belirsizliğin ötesine geçmiyor.
  ///
  /// Karşılığında ±200 ms titreşim ve %2 paket kaybı altında donma bitiyor.
  /// Bu takas bu oyun için açık: 1.1 sn atış aralığı ve tıkla-git dövüşünde
  /// 128 birimlik görsel kayma fark edilmez, DONAN bir gemi ise anında
  /// fark edilir.
  ///
  /// Nişancı bir oyunda (hitscan, anlık isabet) bu takas TERSİNE dönerdi ve
  /// tavan çok daha alçak olmak zorunda kalırdı.
  static const double _maxDelay = 12;

  /// Örnekler bittiğinde kaç tik KESTİRİLİR.
  ///
  /// Üç tik = 100 ms. 320 birim/sn hızda 32 birim, gemi genişliğinin (~112)
  /// üçte biri: yanlış olduğunda bile gözle fark edilmeyecek kadar küçük.
  ///
  /// Sınırın kendisi asıl karar: kestirim uzadıkça hata karesel büyür ve dönen
  /// bir gemi teğet boyunca uçup gider. Üç tikten sonra DURMAK, yanlış yerde
  /// hızla ilerlemekten iyidir — ve zaten o noktada ağ gerçekten kopmuştur.
  static const double _maxExtrapolationTicks = 3;

  /// Ölçülen titreşimin kaç katı tampona eklenir.
  ///
  /// Tahmin edici TEPE tuttuğu için (bkz. [_observeArrival]) bire yakın bir
  /// katsayı yetiyor; 1.5 payı, tepe ile bir sonraki tepe arasındaki farkı
  /// örtüyor.
  static const double _jitterFactor = 1.5;

  final Map<int, _Track> _tracks = {};

  double _renderTick = 0;
  int _latestTick = 0;
  bool _started = false;

  /// UYARLANAN tampon derinliği.
  ///
  /// Sabit derinlik (2 tik = 66 ms) titreşimsiz bir ağ için ölçülmüştü.
  /// `LagProxy` ile ölçülen, ekranda GERÇEKTEN donan kare oranı:
  ///
  /// | koşul                      | sabit tampon | uyarlanan |
  /// |----------------------------|--------------|-----------|
  /// | 0 ms · titreşimsiz (taban) | %0.9         | %0.9      |
  /// | 160 ms · ±40..100          | %1.8–2.5     | ~%1.5     |
  /// | 500 ms · ±200 · %2 kayıp   | **%13–16**   | **~%3.6** |
  /// | 800 ms · ±300 · %5 kayıp   | —            | %3.5      |
  ///
  /// Okunuşu: orta seviye titreşimde sabit tampon zaten iyiydi; UÇ koşulda —
  /// yurt dışı sunucu + mobil ağ — çöküyordu. Tampon boşaldığında ara değerin
  /// ilerleyecek örneği kalmıyor, uzak gemi donuyor ve paket gelince zıplıyor.
  ///
  /// Uyarlanan tampon o çöküşü kaldırırken iyi ağda hiçbir şey ödemiyor:
  /// titreşim yoksa derinleşmiyor, yani görsel gecikme artmıyor.
  double _delay = _minDelay;

  /// Varış zamanlarını ölçen SAAT.
  ///
  /// Kare döngüsünün `dt`'sini biriktirmek yerine gerçek duvar saati: `dt`
  /// toplamak, istemcinin KENDİ zamanlamasını ölçmek demekti ve ölçümde
  /// yakalandı — sakin bir ağda (titreşim sıfır) tampon 11.7 tike şişti,
  /// çünkü makine yüklüyken kare aralıkları düzensizleşiyor ve tahmin edici
  /// bunu ağ titreşimi sanıyordu.
  final Stopwatch _clock = Stopwatch()..start();
  int _lastArrivalMicros = 0;

  /// Son snapshot'tan bu yana İSTEMCİ takıldı mı.
  ///
  /// Uzun bir kare (çöp toplama, arka plana alınma, ısınma kısıtlaması) tek
  /// başına paketleri geciktirmez ama GÖRÜNMELERİNİ geciktirir. Bunu ağ
  /// titreşimi saymak, istemcinin kendi hıçkırığı yüzünden herkesi daha
  /// geriden göstermek olurdu — üstelik en çok, zaten zorlanan cihazda.
  bool _clientStalled = false;

  /// Son karelerdeki EN UZUN süre (tik cinsinden).
  ///
  /// Soket geri çağrısı olay döngüsünde koşuyor: döngü çizimle meşgulse paket
  /// zamanında gelse bile GEÇ işleniyor. Yani ölçtüğümüz sapma iki şeyin
  /// toplamı — ağın titreşimi ve istemcinin kendi zamanlaması.
  ///
  /// Tek uzun kareyi elemek yetmedi (bkz. [_clientStalled]): makine SÜREKLİ
  /// yavaşken hiçbir kare eşiği aşmıyor ama hepsi biraz geciktiriyor ve toplam
  /// ağ titreşimi gibi görünüyor. Ölçümde yakalandı — titreşimsiz bir ağda
  /// tampon 4.97 tike çıktı.
  ///
  /// Çözüm: sapmadan istemcinin KENDİ payını çıkar. Geriye kalan, ağın
  /// açıklayabildiği kısım.
  double _frameCost = 0;
  double _frameCostDecay = 0;

  /// Snapshot varışlarının BEKLENENDEN sapması — TEPE tutan tahmin (tik).
  double _jitter = 0;

  int _lastIngestTick = 0;

  /// Şu anki tampon hedefi (tik). Teşhis ve test için.
  double get delayTicks => _delay;

  /// Ölçülen titreşim (tik). Teşhis ve test için.
  double get jitterTicks => _jitter;

  Iterable<int> get ids => _tracks.keys;

  /// Oynatma saatinin en yeni snapshot'a uzaklığı (tik). Teşhis için: büyümesi
  /// ağın geri kaldığını gösterir.
  double get bufferDepth => _latestTick - _renderTick;

  /// Oynatma saati. Alien sürüsü de BUNU okur — iki ayrı saat, bir geminin
  /// yanından geçtiği alien'in başka bir anda görünmesi demekti.
  double get renderTick => _renderTick;

  void ingest(int serverTick, List<EntitySnapshot> entities) {
    if (serverTick > _latestTick) _latestTick = serverTick;
    if (!_started) {
      _renderTick = (serverTick - _minDelay).toDouble();
      _started = true;
      _lastIngestTick = serverTick;
      _lastArrivalMicros = _clock.elapsedMicroseconds;
    } else {
      _observeArrival(serverTick);
    }
    for (final e in entities) {
      (_tracks[e.id] ??= _Track()).add(serverTick, e);
    }
    _tracks.removeWhere(
      (_, track) => _latestTick - track.lastTick > _staleTicks,
    );
  }

  /// Bir snapshot'ın GECİKMESİNİ ölç ve tamponu ona göre boyutla.
  ///
  /// Ölçülen şey: paket kaç tiklik sunucu zamanı taşıyordu (`beklenen`) ve
  /// gerçekte kaç tiklik duvar saati geçtikten sonra geldi (`gerçek`).
  /// İkisinin farkı, ağın o paketi ne kadar öne/arkaya ittiğidir.
  ///
  /// **Hızlı büyür, yavaş küçülür.** Titreşim arttığında tampon HEMEN
  /// derinleşmeli — geç kalırsa zaten donma yaşanır, yani uyarlamanın amacı
  /// kaçar. Azaldığında ise yavaş sığlaşmalı: hızlı küçülme, bir sonraki
  /// titreşim sıçramasında yeniden donmaya yol açar ve tampon derinliği
  /// salınıma girer. Bu asimetri, titreşim tamponlarının klasik kuralıdır.
  void _observeArrival(int serverTick) {
    final expected = (serverTick - _lastIngestTick).toDouble();
    _lastIngestTick = serverTick;

    final now = _clock.elapsedMicroseconds;
    final actual = (now - _lastArrivalMicros) / 1e6 * ShipSim.tickRate;
    _lastArrivalMicros = now;

    // İstemci kendi takıldıysa bu örnek AĞ hakkında hiçbir şey söylemiyor.
    if (_clientStalled) {
      _clientStalled = false;
      return;
    }

    // İstemcinin kendi zamanlama payını DÜŞ: bir paket, olay döngüsü meşgulse
    // en erken bir sonraki karede işlenebilir. Kalan kısım ağa aittir.
    final raw = (actual - expected).abs();
    final deviation = raw > _frameCostDecay ? raw - _frameCostDecay : 0.0;

    // TEPE TUT, yavaş sal.
    //
    // Üstel ORTALAMA ile başlamıştı ve uç koşulda yetersiz kaldı. Sebep basit:
    // tamponu boşaltan şey ortalama paket değil, EN GEÇ paket. Ortalamayı
    // izleyen bir tahmin edici o kuyruğu sistematik olarak küçük görür.
    //
    // Tepe tutmak o kuyruğu doğrudan ölçüyor; yavaş sönüm (%2/paket, ~1.5 sn
    // yarı ömür) ise ağ gerçekten sakinleştiğinde tamponun sığlaşmasını
    // sağlıyor.
    _jitter = deviation > _jitter ? deviation : _jitter * 0.98;

    final wanted = (_minDelay + _jitter * _jitterFactor).clamp(
      _minDelay,
      _maxDelay,
    );
    _delay = wanted > _delay ? wanted : _delay + (wanted - _delay) * 0.02;
  }

  void remove(int id) => _tracks.remove(id);

  void clear() {
    _tracks.clear();
    _started = false;
    _latestTick = 0;
    _renderTick = 0;
    _delay = _minDelay;
    _jitter = 0;
    _lastIngestTick = 0;
    _lastArrivalMicros = _clock.elapsedMicroseconds;
    _clientStalled = false;
  }

  /// Oynatma saatini ilerlet.
  ///
  /// Saati hedefe doğrudan ÇEKMEK yerine HIZINI ayarlıyoruz (±%15). Çekmek
  /// zamanı geri sardırabilir ve gemiler bir kare geri gider; hız ayarı ise
  /// aynı düzeltmeyi fark edilmeden yapar.
  /// Bu süreden uzun bir kare, istemcinin TAKILDIĞI anlamına gelir.
  ///
  /// 100 ms, 120 Hz'lik bir karenin (8.3 ms) on iki katı: normal dalgalanma
  /// buraya değmez, gerçek bir duraklama ise mutlaka aşar.
  static const double _stallSeconds = 0.1;

  void advance(double dt) {
    if (!_started) return;
    if (dt > _stallSeconds) _clientStalled = true;
    // Tepe tut, yavaş sal — titreşim tahmin edicisiyle aynı gerekçe: bizi
    // ilgilendiren ortalama kare değil, EN UZUN kare.
    final ticks = dt * ShipSim.tickRate;
    if (ticks > _frameCost) {
      _frameCost = ticks;
    } else {
      _frameCost *= 0.99;
    }
    _frameCostDecay = _frameCost;
    final target = _latestTick - _delay;
    final diff = target - _renderTick;

    if (diff.abs() > _resyncTicks) {
      _renderTick = target.toDouble();
      return;
    }
    final rate = (1 + diff * 0.08).clamp(0.85, 1.15);
    _renderTick += dt * ShipSim.tickRate * rate;
  }

  /// [id]'nin ÇİZİLECEK pozu; iz yoksa `null`.
  ///
  /// Dönen nesne İZE AİT ve bir sonraki çağrıda üzerine yazılır. Saklama.
  /// Sebep ölçek: 40 gemi × 120 Hz, kare başına yeni poz ayırmak saniyede
  /// binlerce kısa ömürlü nesne eder ve çöp toplayıcı duraklaması doğrudan
  /// takılma olarak görünür.
  ShipPose? poseOf(int id) {
    final track = _tracks[id];
    final samples = track?.samples;
    if (track == null || samples == null || samples.isEmpty) return null;

    if (_renderTick <= samples.first.tick) {
      return _write(track.pose, samples.first.snap);
    }
    if (_renderTick >= samples.last.tick) {
      return _extrapolate(track, samples);
    }

    for (var i = samples.length - 1; i > 0; i--) {
      final a = samples[i - 1].snap;
      final b = samples[i].snap;
      if (samples[i - 1].tick <= _renderTick &&
          _renderTick <= samples[i].tick) {
        final span = samples[i].tick - samples[i - 1].tick;
        final t = span == 0 ? 1.0 : (_renderTick - samples[i - 1].tick) / span;
        // Ara değer YERİNDE: `EntitySnapshot.lerp` doğru sonucu verir ama
        // kare başına bir nesne ayırır.
        track.pose.set(
          x: a.position.x + (b.position.x - a.position.x) * t,
          y: a.position.y + (b.position.y - a.position.y) * t,
          angle: EntitySnapshot.lerpAngle(a.angle, b.angle, t),
          thrust: a.thrust + (b.thrust - a.thrust) * t,
          shieldFraction:
              a.shieldFraction + (b.shieldFraction - a.shieldFraction) * t,
          // Bayraklar ara değer almaz: en yeni gerçek doğru olandır.
          alive: b.alive,
          weaponTarget: b.weaponTarget,
          firing: b.firing,
        );
        return track.pose;
      }
    }
    return _write(track.pose, samples.last.snap);
  }

  /// Örnekler bitti: son HIZI sınırlı süre sürdür.
  ///
  /// Yalnız KONUM kestiriliyor. Açı, itki ve kalkan için son değer korunuyor:
  /// açıyı kestirmek dönen bir gemiyi kendi etrafında çevirmeye devam ederdi ve
  /// bu, konum hatasının aksine anında göze batar. Bayraklar (ateş, canlı) da
  /// olduğu gibi kalıyor — onlar olay, süreç değil.
  ShipPose _extrapolate(_Track track, List<_Sample> samples) {
    final last = samples.last;
    if (samples.length < 2) return _write(track.pose, last.snap);

    final previous = samples[samples.length - 2];
    final span = last.tick - previous.tick;
    if (span <= 0) return _write(track.pose, last.snap);

    // Ne kadar ileri gidildiği SINIRLI: ağ döndüğünde düzeltme küçük kalsın.
    var ahead = _renderTick - last.tick;
    if (ahead > _maxExtrapolationTicks) ahead = _maxExtrapolationTicks;

    final vx = (last.snap.position.x - previous.snap.position.x) / span;
    final vy = (last.snap.position.y - previous.snap.position.y) / span;

    return track.pose..set(
      x: last.snap.position.x + vx * ahead,
      y: last.snap.position.y + vy * ahead,
      angle: last.snap.angle,
      thrust: last.snap.thrust,
      shieldFraction: last.snap.shieldFraction,
      alive: last.snap.alive,
      weaponTarget: last.snap.weaponTarget,
      firing: last.snap.firing,
    );
  }

  static ShipPose _write(ShipPose pose, EntitySnapshot s) => pose
    ..set(
      x: s.position.x,
      y: s.position.y,
      angle: s.angle,
      thrust: s.thrust,
      shieldFraction: s.shieldFraction,
      alive: s.alive,
      weaponTarget: s.weaponTarget,
      firing: s.firing,
    );
}

class _Sample {
  const _Sample(this.tick, this.snap);

  final int tick;
  final EntitySnapshot snap;
}

/// Tek bir entity'nin son örnekleri.
///
/// Tampon KISA (0.5 sn): daha uzunu belleği değil, yalnız daha eski bir
/// gerçeği saklar. Ara değer için gereken en fazla iki komşu örnek.
class _Track {
  static const int _capacity = 16;

  final List<_Sample> samples = [];

  /// Bu entity'nin TEK poz nesnesi — kare başına üzerine yazılır.
  final ShipPose pose = ShipPose();

  int get lastTick => samples.isEmpty ? 0 : samples.last.tick;

  void add(int tick, EntitySnapshot snap) {
    // Sıra dışı gelen (ya da tekrarlanan) örnek atılır: WebSocket sıralı
    // teslim eder, ama yeniden bağlanma sonrası eski bir çerçeve buraya
    // düşerse ara değeri geri sardırırdı.
    if (samples.isNotEmpty && tick <= samples.last.tick) return;

    // IŞINLANMA: geçmişi at, ara değer yapacak bir şey kalmasın.
    //
    // Gerçekten görüldü: ölen bir gemi doğuş noktasına ışınlanınca istemci iki
    // konum arasını pürüzsüzce dolduruyordu ve gemi enkazdan doğuş noktasına
    // haritayı boydan boya geçerek SÜZÜLÜYORDU — hayalet gibi. Ara değerin
    // işi düzensiz gelen paketleri yumuşatmak; ışınlanmayı yumuşatmak ise
    // olmayan bir hareketi uydurmak.
    //
    // Örnekler arası tik farkıyla ölçekleniyor: paket gecikince iki örnek
    // arasında birden çok tik olabiliyor ve o kadar yol meşru.
    if (samples.isNotEmpty) {
      final span = tick - samples.last.tick;
      final moved = snap.position.distanceTo(samples.last.snap.position);
      if (moved > Protocol.teleportDistancePerTick * span) {
        samples.clear();
      }
    }

    samples.add(_Sample(tick, snap));
    if (samples.length > _capacity) samples.removeAt(0);
  }
}
