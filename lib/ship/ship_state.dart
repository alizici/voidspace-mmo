import 'package:equatable/equatable.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../net/net_phase.dart';

/// HUD'ın okuduğu yüzey.
///
/// Eskiden bu sınıf geminin ayrık durumunun SAHİBİYDİ; artık bir PROJEKSİYON.
/// Gerçek `ShipSimState`'te (tahmin edilmiş, sunucu tarafından düzeltilmiş) ve
/// bu sınıf ondan yalnız HUD'ın göstereceği alanları alıyor.
///
/// Ayrı bir sınıf olarak kalmasının iki sebebi var ve ikisi de somut:
///  * `Equatable`: durum eşitse `Bloc.emit` yayını atlar, yani boşta duran bir
///    gemi HUD'ı hiç yeniden kurmaz. `ShipSimState` her tikte yeni bir nesne.
///  * Sunum alanları (ping, faz) simülasyonda yok ve orada işleri de yok.
/// Minimap'e düşen tek bir iz.
///
/// Poz nesnesi DEĞİL değişmez bir kopya: `ShipPose` her karede üzerine
/// yazılıyor ve Bloc'un durumu saklayabilmesi için değişmez bir değere
/// ihtiyacı var. Saniyede on kez ~25 kopya — ölçülemeyecek kadar az.
class MapBlip extends Equatable {
  const MapBlip({
    required this.id,
    required this.x,
    required this.y,
    required this.alive,
  });

  final int id;
  final double x;
  final double y;
  final bool alive;

  @override
  List<Object?> get props => [id, x, y, alive];
}

class ShipState extends Equatable {
  const ShipState({
    required this.stats,
    required this.phase,
    required this.hull,
    required this.shield,
    required this.boostCharges,
    required this.boostRemaining,
    required this.rechargeElapsed,
    required this.pingMs,
    required this.nearby,
    required this.message,
    this.weaponTarget = 0,
    this.firing = false,
    this.world = GameWorld.standard,
    this.position = const Vec2(6000, 4000),
    this.angle = 0,
    this.viewSize = Vec2.zero,
    this.blips = const [],
    this.alienBlips = const [],
  });

  /// Bağlanmadan önceki hâl: dolu havuzlar, ama dünyada değiliz.
  ShipState.initial(this.stats)
    : phase = NetPhase.idle,
      hull = stats.maxHull,
      shield = stats.maxShield,
      boostCharges = stats.maxBoostCharges,
      boostRemaining = 0,
      rechargeElapsed = 0,
      pingMs = 0,
      nearby = 0,
      message = null,
      weaponTarget = 0,
      firing = false,
      world = GameWorld.standard,
      position = GameWorld.standard.centre,
      angle = 0,
      viewSize = Vec2.zero,
      blips = const [],
      alienBlips = const [];

  final ShipStats stats;
  final NetPhase phase;
  final double hull;
  final double shield;
  final int boostCharges;

  /// Devam eden itkiden kalan süre (sn). 0 = itki yok.
  final double boostRemaining;

  /// Sıradaki şarjın dolum sayacı (sn).
  final double rechargeElapsed;

  /// Son ölçülen gidiş-dönüş süresi (ms).
  final int pingMs;

  /// İlgi alanındaki diğer oyuncular.
  final int nearby;

  /// Kilitli hedefin kimliği; 0 = yok.
  final int weaponTarget;

  /// Ateş açık mı.
  final bool firing;

  final String? message;

  // ── Harita yüzeyi ──────────────────────────────────────────────────────
  //
  // Minimap HUD'da yaşıyor ve HUD yalnız Bloc'tan okuyor: konumu oyundan
  // çekmek, çubuklarla haritanın ayrı gerçekler göstermesine açılan kapı.
  // Bedeli açık — konum durumun parçası olduğu için HAREKET EDEN bir gemi
  // artık saniyede on kez yeni durum üretiyor (duran gemi hâlâ üretmiyor).
  // Zaten haritanın güncellenmesi gereken tek an hareket anı.

  /// Oynanabilir alan — sunucudan gelir, istemcinin sabiti değil.
  final GameWorld world;

  /// Geminin dünya konumu (tahmin edilmiş).
  final Vec2 position;

  /// Radyan; 0 = kuzey.
  final double angle;

  /// Kameranın gördüğü alanın DÜNYA boyutu — minimap'teki görüş kutusu.
  final Vec2 viewSize;

  /// İlgi alanındaki diğer gemiler.
  final List<MapBlip> blips;

  /// İlgi alanındaki alien'ler. Ayrı liste çünkü haritada ayrı okunuyorlar:
  /// gemi bir oyuncu, alien bir hedef.
  final List<MapBlip> alienBlips;

  bool get online => phase == NetPhase.playing;
  bool get alive => hull > 0;
  bool get boosting => boostRemaining > 0;

  double get hullFraction => (hull / stats.maxHull).clamp(0.0, 1.0);
  double get shieldFraction => (shield / stats.maxShield).clamp(0.0, 1.0);

  /// Sıradaki şarjın dolum oranı (0..1). Şarj doluysa 1.
  double get rechargeFraction => boostCharges >= stats.maxBoostCharges
      ? 1
      : (rechargeElapsed / stats.boostRecharge).clamp(0.0, 1.0);

  ShipState fromSim(
    ShipSimState sim, {
    required NetPhase phase,
    required int pingMs,
    required int nearby,
    required GameWorld world,
    required Vec2 viewSize,
    required List<MapBlip> blips,
    required List<MapBlip> alienBlips,
    String? message,
  }) => ShipState(
    stats: sim.stats,
    phase: phase,
    hull: sim.hull,
    shield: sim.shield,
    boostCharges: sim.boostCharges,
    boostRemaining: sim.boostRemaining,
    rechargeElapsed: sim.rechargeElapsed,
    pingMs: pingMs,
    nearby: nearby,
    message: message,
    weaponTarget: sim.weaponTarget,
    firing: sim.firing,
    world: world,
    position: sim.position,
    angle: sim.angle,
    viewSize: viewSize,
    blips: blips,
    alienBlips: alienBlips,
  );

  ShipState offline({required NetPhase phase, String? message}) => ShipState(
    stats: stats,
    phase: phase,
    hull: hull,
    shield: shield,
    boostCharges: boostCharges,
    boostRemaining: boostRemaining,
    rechargeElapsed: rechargeElapsed,
    pingMs: 0,
    nearby: 0,
    message: message,
    world: world,
    position: position,
    angle: angle,
    // İzler DÜŞER: bağlantı koptuğunda haritada duran gemiler, hâlâ orada
    // duruyormuş gibi okunur. Bilinmeyen, yanlış bilinenden iyidir.
    viewSize: viewSize,
  );

  @override
  List<Object?> get props => [
    // Ad değil nesnenin KENDİSİ: aynı ada sahip iki farklı yapılandırma
    // eşit sayılmasın (gövde değişimi geldiğinde bu sessizce yanlış olurdu).
    stats,
    phase,
    hull,
    shield,
    boostCharges,
    boostRemaining,
    rechargeElapsed,
    pingMs,
    nearby,
    world,
    position,
    angle,
    viewSize,
    blips,
    alienBlips,
    message,
    weaponTarget,
    firing,
  ];
}
