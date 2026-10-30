import '../domain/ship_stats.dart';
import '../domain/vec2.dart';

/// Bir geminin TAM durumu — sürekli (konum, yön, itki rampası) ve ayrık
/// (havuzlar, şarjlar) birlikte.
///
/// Tek parçada durmasının sebebi ağ: mutabakat, sunucunun onayladığı ana geri
/// sarıp oradan yeniden oynatır. Durum iki nesneye bölünmüş olsaydı geri sarma
/// yarısını kaçırırdı. İSTEMCİDE bu ayrım hâlâ var ama artık başka bir yerde:
/// `ShipBloc` bu durumun yalnız AYRIK yüzünü HUD'a yansıtır.
///
/// Değişmez: `step` yeni bir örnek döndürür, mevcut olanı bozmaz. Geçmiş
/// durumları saklayıp geri sarabilmek bunun doğrudan sonucu.
class ShipSimState {
  const ShipSimState({
    required this.stats,
    required this.position,
    required this.angle,
    required this.thrust,
    required this.target,
    required this.hull,
    required this.shield,
    required this.boostCharges,
    required this.boostRemaining,
    required this.rechargeElapsed,
    required this.sinceHit,
    required this.weaponTarget,
    required this.firing,
    this.aimPoint,
  });

  ShipSimState.spawn(this.stats, this.position)
    : angle = 0,
      thrust = 0,
      target = null,
      hull = stats.maxHull,
      shield = stats.maxShield,
      boostCharges = stats.maxBoostCharges,
      boostRemaining = 0,
      rechargeElapsed = 0,
      sinceHit = stats.shieldRegenDelay,
      weaponTarget = 0,
      firing = false,
      aimPoint = null;

  final ShipStats stats;

  // ── Sürekli ────────────────────────────────────────────────────────────
  final Vec2 position;

  /// Radyan. 0 = kuzey (gövde burnu yukarı), saat yönünde artar.
  final double angle;

  /// Motor alevinin ve çatlak sıcaklığının sürücüsü (0..1).
  final double thrust;

  /// Tıkla-git hedefi; varılınca `null` olur.
  final Vec2? target;

  // ── Ayrık ──────────────────────────────────────────────────────────────
  final double hull;
  final double shield;
  final int boostCharges;

  /// Devam eden itkiden kalan süre (sn). 0 = itki yok.
  final double boostRemaining;

  /// Sıradaki şarjın dolum sayacı (sn).
  final double rechargeElapsed;

  /// Son vuruştan bu yana geçen süre (sn).
  final double sinceHit;

  /// Kilitli hedefin entity kimliği; 0 = hedef yok.
  ///
  /// Girdi değil DURUM: `moveTarget` gibi bir kez kurulur ve bozulana kadar
  /// yaşar. Snapshot'ta taşındığı için hem geri sarmada kaybolmaz hem de
  /// diğer istemciler kimin kime nişan aldığını görüp ışını çizebilir.
  final int weaponTarget;

  /// Ateş açık mı.
  final bool firing;

  /// Kilitli hedefin SON BİLİNEN konumu; `null` = serbest yönelim.
  ///
  /// Neden bir KİMLİK değil bir NOKTA: `ShipSim.step` tek gemiyi izole işleyen
  /// saf bir fonksiyon ve başka gemilerin konumunu göremez. Kimliği taşımak,
  /// adımın gemi listesine uzanmasını gerektirirdi — determinizmin bittiği yer
  /// tam olarak orası.
  ///
  /// Noktayı SUNUCU koyuyor (`Zone`), istemci yalnız mutabakatla alıyor. Tel
  /// üzerinde taşınmasının sebebi de bu: taşınmazsa istemcinin yeniden
  /// oynatması hedefi olmayan bir gemi simüle eder ve gemi her snapshot'ta
  /// yön değiştirirdi.
  final Vec2? aimPoint;

  bool get alive => hull > 0;
  bool get boosting => boostRemaining > 0;
  bool get canBoost => alive && !boosting && boostCharges > 0;

  double get hullFraction => (hull / stats.maxHull).clamp(0.0, 1.0);
  double get shieldFraction => (shield / stats.maxShield).clamp(0.0, 1.0);

  /// Sıradaki şarjın dolum oranı (0..1). Şarj doluysa 1.
  double get rechargeFraction => boostCharges >= stats.maxBoostCharges
      ? 1
      : (rechargeElapsed / stats.boostRecharge).clamp(0.0, 1.0);

  ShipSimState copyWith({
    /// Gemi statları — DONATIM değiştiğinde.
    ///
    /// Simülasyonun içinde asla değişmiyor (saf adım aynı statlarla koşuyor);
    /// yalnız oyuncu hangarda bir şey taktığında sunucu bunu yazıyor. Havuzları
    /// da birlikte ölçeklemek çağıranın işi: daha büyük bir kalkan takmak
    /// kalkanı DOLDURMAMALI, yoksa hangar bir tamir istasyonuna döner.
    ShipStats? stats,
    Vec2? position,
    double? angle,
    double? thrust,
    Vec2? target,
    bool clearTarget = false,
    double? hull,
    double? shield,
    int? boostCharges,
    double? boostRemaining,
    double? rechargeElapsed,
    double? sinceHit,
    int? weaponTarget,
    bool? firing,
    Vec2? aimPoint,
    bool clearAim = false,
  }) => ShipSimState(
    stats: stats ?? this.stats,
    position: position ?? this.position,
    angle: angle ?? this.angle,
    thrust: thrust ?? this.thrust,
    // `target` nullable olduğu için `??` ile "temizle"yi ifade edemez —
    // ayrı bir bayrak olmadan hedefi silmek imkânsız olurdu.
    target: clearTarget ? null : (target ?? this.target),
    hull: hull ?? this.hull,
    shield: shield ?? this.shield,
    boostCharges: boostCharges ?? this.boostCharges,
    boostRemaining: boostRemaining ?? this.boostRemaining,
    rechargeElapsed: rechargeElapsed ?? this.rechargeElapsed,
    sinceHit: sinceHit ?? this.sinceHit,
    weaponTarget: weaponTarget ?? this.weaponTarget,
    firing: firing ?? this.firing,
    // `target` ile aynı sebep: nullable bir alan `??` ile temizlenemez.
    aimPoint: clearAim ? null : (aimPoint ?? this.aimPoint),
  );
}
