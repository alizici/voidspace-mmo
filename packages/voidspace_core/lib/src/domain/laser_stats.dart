/// Bir LAZERİN sayısal kimliği — gövdeden ve görselden AYRI.
///
/// Neden ayrı bir tip: hasar, atış aralığı ve menzil geminin değil SİLAHIN
/// özelliği. Bugün tek bir gövde ve tek bir lazer var; ikinci lazer geldiğinde
/// (PL-3, Hyperplasmoid, Magmadrill) değişmesi gereken tek yer burası olmalı,
/// `ShipStats` değil.
///
/// Görsel BURADA YOK. Bir mermiye hangi renkte çizileceğini söylemek istemci
/// işi; bu paket sunucuda da koşuyor ve orada rengin karşılığı yok. Tasarım
/// eşleşmesi `lib/game/art/laser_bolt.dart`'ta [id] üzerinden kuruluyor.
library;

import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';

class LaserStats {
  const LaserStats({
    required this.id,
    required this.name,
    required this.damage,
    required this.fireInterval,
    required this.range,
  });

  /// PL-4 — hattın standart namlusu ve şu an takılabilen tek lazer.
  ///
  /// **Denge korundu.** Önceki değerler gemiye gömülüydü: atış başına 720,
  /// aralık 0.8 sn → 900 hasar/sn. PL-4 kendi kanonik hasarını (200) taşıyor
  /// ve gövde beş namlu çalıştırıyor, yani yaylım 1000; aralık 1.1 sn ile
  /// saniyelik hasar 909'da kalıyor. Tam kalkanı (8000) düşürmek yine ~9
  /// saniye — değişen tek şey, atışın daha az ama daha iri gelmesi. Hasar
  /// sayısı ekranda göründüğü için bu iyi bir takas: yaylımlar sayılabilir
  /// oluyor.
  static const pl4 = LaserStats(
    id: 'pl-4',
    name: 'PL-4',
    // Namlu hasarı ve aralık TEPE TABLODAN: ikisi referans build'in girdisi
    // (alan 04) ve gövde çapası onlardan çözülüyor. Burada elle dursalar
    // tablo değişince silah değişmezdi.
    damage: Turetilenler.referansLazerHasari,
    fireInterval: TasarimGirdileri.referansAtisAraligi,
    // Menzil ilgi alanı yarıçapından (`Protocol.interestRadius` = 2600)
    // KÜÇÜK olmak zorunda: göremediğin bir gemiye ateş edememelisin, yoksa
    // sunucu istemcinin bilmediği bir hedefe hasar uygular ve ekranda
    // sebepsiz can kaybı görünür.
    range: 1400,
  );

  /// Kayıtlı tüm lazerler. Kimlikten tasarıma ulaşan her yer (istemci sanatı,
  /// ileride envanter) buradan okur.
  static const List<LaserStats> all = [pl4];

  static LaserStats? byId(String id) {
    for (final laser in all) {
      if (laser.id == id) return laser;
    }
    return null;
  }

  /// Kalıcı kimlik — kayıt anahtarı ve görsel eşleşmesinin çivisi.
  final String id;

  /// Arayüzde görünen ad.
  final String name;

  /// TEK namlunun atış başına hasarı.
  final double damage;

  /// İki yaylım arası en kısa süre (sn).
  final double fireInterval;

  /// Ateş menzili, dünya birimi. Hedef bu mesafeyi aşarsa atış kesilir.
  final double range;
}
