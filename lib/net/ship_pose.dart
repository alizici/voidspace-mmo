/// Bir geminin ÇİZİLECEK hâli — konum, yön, motor.
///
/// `ShipSimState`'ten ayrı olmasının sebebi: o durum otoriter ve tik hızında
/// (30 Hz) ilerliyor, ekran ise 60/120 Hz çiziyor. Poz, iki tik arasında ara
/// değerlenmiş ve sapma düzeltmesi eklenmiş hâl — yani mantığın değil GÖZÜN
/// gördüğü şey. İkisini karıştırmak, düzeltmeyi simülasyona geri besleyip
/// salınım üretir.
///
/// **DEĞİŞTİRİLEBİLİR ve YENİDEN KULLANILIR.** Değişmez bir poz daha güvenli
/// olurdu ama ölçek buna izin vermiyor: 40 gemi × 120 Hz = saniyede 4800 poz,
/// her biri yanında iki vektörle. Dart'ın çöp toplayıcısı bu hızda düzenli
/// duraklar ve duraklattığı şey kare döngüsüdür — mobilde takılmanın en yaygın
/// sebebi tam olarak budur.
///
/// Sözleşme: bir pozu SAKLAMA. Sahibi (`RemoteEntities`, `PredictedShip`) onu
/// bir sonraki karede üzerine yazar. Kullan ve bırak.
///
/// Konum `Vec2` değil iki `double`: vektör nesnesi de tahsistir ve çizim yolu
/// zaten bileşenleri ayrı ayrı istiyor.
class ShipPose {
  ShipPose();

  double x = 0;
  double y = 0;
  double angle = 0;
  double thrust = 0;
  double shieldFraction = 0;
  bool alive = true;

  /// Nişan alınan kimlik; 0 = yok. Işını çizmek için gerekli.
  int weaponTarget = 0;

  /// Ateş ediyor mu.
  bool firing = false;

  void set({
    required double x,
    required double y,
    required double angle,
    required double thrust,
    required double shieldFraction,
    required bool alive,
    int weaponTarget = 0,
    bool firing = false,
  }) {
    this.x = x;
    this.y = y;
    this.angle = angle;
    this.thrust = thrust;
    this.shieldFraction = shieldFraction;
    this.alive = alive;
    this.weaponTarget = weaponTarget;
    this.firing = firing;
  }
}
