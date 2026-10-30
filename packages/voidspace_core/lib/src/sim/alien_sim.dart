import 'dart:math' as math;

import '../domain/alien_stats.dart';
import '../domain/vec2.dart';
import '../domain/world.dart';

/// Bir alien'in TAM durumu. Değişmez — [ShipSimState] ile aynı sebeple.
class AlienSimState {
  const AlienSimState({
    required this.stats,
    required this.home,
    required this.position,
    required this.roamTarget,
    required this.dwell,
    required this.seed,
    required this.hull,
    required this.respawnIn,
    required this.targetId,
    required this.aggroFor,
    required this.fireCooldown,
  });

  /// Doğuş anı: alien evinde durur ve ilk hedefini bir sonraki adımda seçer.
  ///
  /// **Namlu sayacı SIFIR DEĞİL, tohuma göre kaydırılmış.** Sıfır olduğunda
  /// aynı anda uyanan bütün alienler aynı tikte ateş ediyor ve aralıkları eşit
  /// olduğu için sonsuza kadar kilitli adımda kalıyorlar. İki sonucu var,
  /// ikisi de ölçüldü:
  ///
  ///  * **Sunucu:** 120 oyuncuda tik p95'i 10.6 → 14.1 ms, p99'u 13.6 → 21.0
  ///    ms çıktı. Medyan hiç değişmedi — iş ARTMADI, TOPAKLANDI.
  ///  * **Oyuncu:** altı alienin yaylımı tek karede iniyor. Aynı toplam hasar,
  ///    ama dağıldığında tepki verilebilir, topaklandığında verilemez.
  ///
  /// Aynı ilkenin çizim katmanındaki karşılığı zaten vardı ("faz gemi
  /// kimliğine göre kayıyor"); burası simülasyondaki hâli.
  AlienSimState.spawn(this.stats, this.home, this.seed)
    : position = home,
      roamTarget = home,
      dwell = 0,
      hull = stats.maxHull,
      respawnIn = 0,
      targetId = 0,
      aggroFor = 0,
      fireCooldown = AlienSim.spawnFireOffset(stats, seed);

  final AlienStats stats;

  /// Doğuş noktası. Gezinme bunun etrafında kalır — bkz. [AlienStats.roamRange].
  final Vec2 home;

  final Vec2 position;

  /// Şu an gidilen nokta.
  final Vec2 roamTarget;

  /// Hedefe varıldıktan sonra beklenen süre (sn). Sürekli hareket eden bir
  /// sürü mekanik görünüyor; duraklamalar onlara ağırlık veriyor.
  final double dwell;

  final double hull;

  /// Yeniden doğmaya kalan süre (sn). 0 = yaşıyor.
  ///
  /// Ölü alien haritadan SİLİNMİYOR, sayaçla bekliyor: silmek kimlik geri
  /// dönüşümü gerektirirdi ve istemcideki iz o kimliği hâlâ taşıyor olurdu.
  final double respawnIn;

  /// Peşine düştüğü geminin kimliği; 0 = yok.
  ///
  /// Hedef SEÇİMİ burada değil `Zone`'da: bu paket gemileri görmüyor ve
  /// görmemeli. Burada yalnız kararın SONUCU ve ömrü duruyor.
  final int targetId;

  /// Kışkırtılmışlığın kalan süresi (sn). Sıfıra inince hedef bırakılır.
  ///
  /// Neden süreli: sonsuz kin, vurup kaçan oyuncunun peşine haritanın öbür
  /// ucuna kadar düşen bir alien demek. Süreli olması "kaçmak işe yarar"
  /// kuralını kuruyor — ve kaçmanın işe yaraması, girmenin bir karar
  /// olmasını sağlıyor.
  final double aggroFor;

  /// Bir sonraki atışa kalan süre (sn).
  final double fireCooldown;

  bool get alive => hull > 0;

  /// Kışkırtılmış ve hedefi olan bir alien.
  bool get hunting => alive && targetId != 0 && aggroFor > 0;

  double get hullFraction => (hull / stats.maxHull).clamp(0.0, 1.0);

  /// Bu alien'e ÖZGÜ tohum. Rastgeleliğin tek kaynağı bu: aynı tohum aynı
  /// yolu üretir, yani sunucu yeniden başlatıldığında sürü aynı şekilde
  /// dolaşır ve test edilebilir kalır.
  final int seed;

  AlienSimState copyWith({
    Vec2? position,
    Vec2? roamTarget,
    double? dwell,
    double? hull,
    double? respawnIn,
    int? targetId,
    double? aggroFor,
    double? fireCooldown,
  }) => AlienSimState(
    stats: stats,
    home: home,
    position: position ?? this.position,
    roamTarget: roamTarget ?? this.roamTarget,
    dwell: dwell ?? this.dwell,
    seed: seed,
    hull: hull ?? this.hull,
    respawnIn: respawnIn ?? this.respawnIn,
    targetId: targetId ?? this.targetId,
    aggroFor: aggroFor ?? this.aggroFor,
    fireCooldown: fireCooldown ?? this.fireCooldown,
  );
}

/// Bir alien'in BİR adımı. Saf: aynı girdi daima aynı çıktıyı verir.
///
/// **Neden `Random` yok.** Sürünün davranışı sunucunun yeniden başlatılmasına
/// ya da tik sırasına bağlı olmamalı; ayrıca test "otuz alien haritayı terk
/// etmiyor" gibi bir şeyi ancak deterministik bir yürüyüşte kanıtlayabilir.
/// Rastgelelik tohum + adım sayacından türetilen bir karmadan geliyor.
abstract final class AlienSim {
  /// Hedefe bu kadar yaklaşınca varılmış sayılır.
  static const double arriveRadius = 40;

  /// Varışta beklenen süre aralığı (sn).
  static const double minDwell = 0.6;
  static const double maxDwell = 3.2;

  /// Alien'e hasar uygula. YALNIZ sunucu çağırır.
  ///
  /// Kalkan YOK: alien'in tek havuzu gövde. Kalkan bir oyuncu mekaniği —
  /// alien'e vermek, onu oyuncunun küçük bir kopyası yapardı.
  /// Doğan alienin namlu sayacına konan KAYDIRMA (sn).
  ///
  /// Tohumdan türüyor: aynı alien her doğuşta aynı kaymayı alıyor (yani
  /// simülasyon deterministik kalıyor) ama komşusundan farklı.
  static double spawnFireOffset(AlienStats stats, int seed) =>
      _hash(seed * 2654435761) * stats.fireInterval;

  /// Kışkırtılan alien bu kadar süre peşini bırakmaz (sn).
  ///
  /// Her vuruşta baştan doluyor: kavga sürdükçe alien vazgeçmiyor, kesildiği
  /// anda saymaya başlıyor. Sabit bir "kavga süresi" olsaydı uzun bir dövüşün
  /// ortasında alien sebepsiz dönüp giderdi.
  static const double aggroDuration = 12;

  /// Alien'e hasar uygula. YALNIZ sunucu çağırır.
  ///
  /// Kalkan YOK: alien'in tek havuzu gövde. Kalkan bir oyuncu mekaniği —
  /// alien'e vermek, onu oyuncunun küçük bir kopyası yapardı.
  ///
  /// [attacker] vuran geminin kimliği. Sıfırdan farklıysa alien KIŞKIRTILIR
  /// ve peşine düşer; pasif bir türü (Void Spore) savaşa sokan tek yol bu.
  static AlienSimState applyDamage(
    AlienSimState s,
    double amount, {
    int attacker = 0,
  }) {
    if (!s.alive || amount <= 0) return s;
    final hull = (s.hull - amount).clamp(0.0, s.stats.maxHull);
    final dead = hull <= 0;
    return s.copyWith(
      hull: hull,
      respawnIn: dead ? s.stats.respawnDelay : s.respawnIn,
      // Ölürken hedef tutmanın anlamı yok; doğuş zaten sıfırlıyor ama ölü
      // durumun tutarlı olması, "ölü alien hâlâ nişan alıyor" gibi bir ara
      // hâli baştan imkânsız kılıyor.
      targetId: dead ? 0 : (attacker != 0 ? attacker : s.targetId),
      aggroFor: dead ? 0 : (attacker != 0 ? aggroDuration : s.aggroFor),
    );
  }

  /// Bir alien'in BİR adımı.
  ///
  /// [chase] kışkırtılmışsa hedefin KONUMU, değilse `null`. Konumu `Zone`
  /// veriyor: bu paket gemileri görmüyor ve görmemeli — aynı kod sunucuda ve
  /// istemcide koşuyor, istemcide `ships` diye bir şey yok.
  static AlienSimState step(
    AlienSimState s,
    GameWorld world,
    double dt,
    int tick, {
    Vec2? chase,
  }) {
    if (!s.alive) {
      final remaining = s.respawnIn - dt;
      if (remaining > 0) return s.copyWith(respawnIn: remaining);
      // Yeniden doğuş EVDE: öldüğü yerde doğmak, orada bekleyen oyuncuya
      // sonsuz bir hedef akışı verirdi.
      return AlienSimState.spawn(s.stats, s.home, s.seed);
    }

    // Sayaçlar HER tik iniyor — gezinme durumundan bağımsız. Bekleme
    // (`dwell`) içindeyken de kin soğumalı ve namlu dolmalı; yoksa duran bir
    // alien sonsuza kadar kızgın kalırdı.
    final cooldown = math.max(0.0, s.fireCooldown - dt);
    final aggro = math.max(0.0, s.aggroFor - dt);
    s = s.copyWith(
      fireCooldown: cooldown,
      aggroFor: aggro,
      // Kin bitti: hedefi bırak ve evine dön.
      targetId: aggro <= 0 ? 0 : s.targetId,
    );

    // KOVALAMA gezinmenin yerine geçer.
    //
    // Alien'in evine bağlı kalması (`roamRange`) barış hâlinin kuralı;
    // kavgada geçerli değil. Kovalarken dünya sınırı dışında bir sınır yok —
    // ama kin süreli olduğu için alien haritanın öbür ucuna sürüklenemiyor.
    if (chase != null) {
      final toFoe = chase - s.position;
      final gap = toFoe.length;
      // Menzilin İÇİNDE dur: üstüne binen bir alien hem çirkin duruyor hem de
      // oyuncunun kaçış yönünü kapatıyor. Menzilin %70'i, atışı kesmeden
      // mesafe bırakıyor.
      final standOff = s.stats.range * 0.7;
      if (gap > standOff) {
        final step = s.stats.speed * dt;
        final position = gap <= step ? chase : s.position + toFoe / gap * step;
        return s.copyWith(position: world.clamp(position), dwell: 0);
      }
      return s;
    }

    if (s.dwell > 0) {
      return s.copyWith(dwell: math.max(0, s.dwell - dt));
    }

    final toTarget = s.roamTarget - s.position;
    final distance = toTarget.length;
    if (distance <= arriveRadius) {
      // Vardı: bekle ve yeni bir nokta seç.
      final roll = _hash(s.seed * 7919 + tick);
      final angle = _hash(s.seed * 104729 + tick * 31) * 2 * math.pi;
      final reach = s.stats.roamRange * (0.25 + 0.75 * roll);
      return s.copyWith(
        dwell: minDwell + (maxDwell - minDwell) * _hash(s.seed + tick * 13),
        roamTarget: world.clamp(
          s.home + Vec2(math.cos(angle) * reach, math.sin(angle) * reach),
        ),
      );
    }

    final step = s.stats.speed * dt;
    final position = distance <= step
        ? s.roamTarget
        : s.position + toTarget / distance * step;
    return s.copyWith(position: world.clamp(position));
  }

  /// 0..1 arası deterministik karma. `dart:math`'in `Random`'ı DEĞİL: durum
  /// taşımıyor, yani adımın saflığını bozmuyor.
  static double _hash(int n) {
    final v = math.sin(n * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }
}
