import '../domain/vec2.dart';

/// Bir SİMÜLASYON TİKİ için oyuncunun niyeti.
///
/// Ağda gidip gelen tek istemci→sunucu oyun mesajı bu. Kritik ayrım: burada
/// "500 hasar verdim" gibi bir SONUÇ yoktur, yalnız NİYET vardır. Sonucu
/// üretmek sunucunun işi — istemci otorite olsaydı tek bir bellek editörü
/// ekonomiyi bitirirdi.
///
/// [seq] mutabakatın (reconciliation) çivisi: sunucu her snapshot'ta işlediği
/// son sırayı geri söyler, istemci de o noktadan sonrasını yeniden oynatır.
class ShipInput {
  const ShipInput({
    required this.seq,
    this.axis = Vec2.zero,
    this.moveTarget,
    this.boost = false,
    this.weaponTarget = 0,
    this.firing = false,
  });

  static const ShipInput idle = ShipInput(seq: 0);

  /// İstemcinin monotonik girdi sayacı.
  final int seq;

  /// Klavye uçuş yönü (sıfır = tuş basılı değil). Tıkla-git hedefini ezer.
  final Vec2 axis;

  /// YALNIZ tıklanan tikte dolu: "hedefi buraya kur" komutu.
  ///
  /// Hedefin KENDİSİ girdi değil durumdur ([ShipSimState.target]) — bir kez
  /// kurulur, varılana kadar yaşar. Snapshot hedefi de taşıdığı için geri
  /// sarma sırasında kaybolmaz.
  final Vec2? moveTarget;

  /// Kenar tetikli itki isteği: basılı tutmak değil, BASMAK.
  final bool boost;

  /// Seçili hedefin entity kimliği; 0 = hedef yok.
  ///
  /// Seçim istemcide yapılır (Tab), ama sunucuya bildirilmek ZORUNDA: hasarı
  /// uygulayan sunucu, kime ateş edildiğini istemciden başka kimseden
  /// öğrenemez. Sunucu yine de doğrular — kimliği göndermek, hasarı
  /// göndermekle aynı şey değil.
  final int weaponTarget;

  /// Ateş açık mı. Basılı tutma değil AÇMA/KAPAMA: oyuncu bir kez açar,
  /// menzil ve hedef geçerli olduğu sürece ateş sürer.
  final bool firing;

  ShipInput copyWith({int? seq}) => ShipInput(
    seq: seq ?? this.seq,
    axis: axis,
    moveTarget: moveTarget,
    boost: boost,
    weaponTarget: weaponTarget,
    firing: firing,
  );
}
