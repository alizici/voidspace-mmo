import 'package:voidspace_core/voidspace_core.dart';

import '../net/net_phase.dart';
import 'ship_state.dart';

/// [ShipBloc]'un kabul ettiği TEK giriş kümesi.
///
/// Tek elemanlı olması, mimarideki en büyük değişikliğin özeti: eskiden burada
/// `ShipTicked`, `ShipHit`, `BoostRequested`, `ShipRepaired` vardı — yani
/// istemci havuzları KENDİ hesaplıyordu. PvP'de bu, tek bir bellek editörünün
/// ekonomiyi bitirmesi demek. Hasarın da itkinin de tek hakemi artık sunucu;
/// istemcinin işi sonucu YANSITMAK.
sealed class ShipEvent {
  const ShipEvent();
}

/// Ağ katmanından gelen replikasyon. Oyun döngüsü KARE BAŞINA DEĞİL, kısılmış
/// bir hızda gönderir (bkz. `VoidspaceGame._hudHz`): 60 Hz durum yayını bu
/// mimarinin en bilinen çöp üretme biçimidir ve HUD'ın saniyede 60 kez
/// yeniden kurulması için hiçbir sebep yok.
final class ShipSynced extends ShipEvent {
  const ShipSynced({
    required this.phase,
    this.state,
    this.pingMs = 0,
    this.nearby = 0,
    this.message,
    this.world = GameWorld.standard,
    this.viewSize = Vec2.zero,
    this.blips = const [],
    this.alienBlips = const [],
  });

  final NetPhase phase;

  /// Tahmin edilen gemi durumu; el sıkışma bitmeden `null`.
  final ShipSimState? state;

  final int pingMs;

  /// İlgi alanındaki diğer oyuncular.
  final int nearby;

  /// Bağlantı durumuna dair insan okunur not (red sebebi, kopma).
  final String? message;

  /// Oynanabilir alan — sunucudan gelir.
  final GameWorld world;

  /// Kameranın gördüğü alanın dünya boyutu (minimap görüş kutusu).
  final Vec2 viewSize;

  /// İlgi alanındaki gemilerin harita izleri.
  final List<MapBlip> blips;

  /// Alien'lerin harita izleri.
  final List<MapBlip> alienBlips;
}
