import 'dart:typed_data';

import '../sim/ship_sim_state.dart';
import 'byte_io.dart';
import 'quantize.dart';

/// Entity durumunun TELE giden kuantalanmış hâli ve DELTA kodlaması.
///
/// **Neden delta.** Ölçüldü: düz uçan bir gemide, kuantalandıktan sonra ardışık
/// iki tik arasında yalnız **x** değişiyor — y, açı, itki, kalkan, gövde,
/// bayraklar ve hedef %0. Duran gemide hiçbir alan değişmiyor. Yani 14 baytlık
/// tam kaydın 11'i saf tekrar.
///
/// Ölçümü KUANTALANMIŞ değerler üzerinde yapmak şarttı: ham `double`'lara
/// bakıldığında açı ve itki de "%100 değişiyor" görünüyor, çünkü yumuşatma
/// fonksiyonları onları sürekli kıpırdatıyor. Kuantalama o kıpırtıyı yutuyor
/// ve telde hiçbir şey değişmiyor. Yanlış tarafı ölçen biri delta'yı gereksiz
/// sanırdı.
///
/// **Neden Quake 3'ün modeli DEĞİL.** Quake 3 istemci başına anlık görüntü
/// geçmişi tutar ve istemcinin ONAYLADIĞI kareye göre delta üretir. Bunun
/// sebebi UDP: paket kaybolabildiği için sunucu hangi karenin ulaştığını
/// bilemez. Biz WebSocket üzerindeyiz — teslim SIRALI ve GÜVENİLİR. Bir
/// snapshot gönderildiyse ulaşır; ulaşmadıysa bağlantı zaten kopmuştur.
///
/// Bu tek fark bütün makineyi siliyor: onay protokolü yok, istemci başına
/// geçmiş yok, yeniden temellendirme yok. Herkes için TEK ortak temel var —
/// önceki tik. Beş bin oyuncuda istemci başına snapshot geçmişi tutmak
/// başlı başına bir bellek sorunuydu; burada maliyeti sıfır.
///
/// Temelin geçersiz olduğu üç durum var ve üçü de sunucuda açıkça ele alınıyor:
/// entity ilgi alanına YENİ girdi, istemci YENİ bağlandı, ya da yavaş istemci
/// olduğu için bir snapshot ATLANDI. Üçünde de tam kayıt gönderilir.
abstract final class EntityDelta {
  static const int bitX = 1 << 0;
  static const int bitY = 1 << 1;
  static const int bitAngle = 1 << 2;
  static const int bitThrust = 1 << 3;
  static const int bitShield = 1 << 4;
  static const int bitHull = 1 << 5;
  static const int bitFlags = 1 << 6;
  static const int bitTarget = 1 << 7;

  /// Bütün alanlar — temeli olmayan istemci için.
  static const int full = 0xFF;

  /// Kuantalanmış alan sayısı.
  static const int fields = 8;

  // Alan sırası: telde de bu sırayla yazılıyor.
  static const int fx = 0;
  static const int fy = 1;
  static const int fAngle = 2;
  static const int fThrust = 3;
  static const int fShield = 4;
  static const int fHull = 5;
  static const int fFlags = 6;
  static const int fTarget = 7;

  /// Simülasyon durumunu kuantalanmış alanlara çevirir.
  ///
  /// Ara nesne YOK: [out] çağıranın yeniden kullandığı tampon. Tik başına
  /// oyuncu × görünür entity kadar çağrılıyor.
  static void quantize(
    Int32List out,
    ShipSimState s,
    double worldWidth,
    double worldHeight,
  ) {
    out[fx] = Quantize.position(s.position.x, worldWidth);
    out[fy] = Quantize.position(s.position.y, worldHeight);
    out[fAngle] = Quantize.angle(s.angle);
    out[fThrust] = Quantize.unit(s.thrust);
    out[fShield] = Quantize.unit(s.shieldFraction);
    out[fHull] = Quantize.unit(s.hullFraction);
    out[fFlags] = (s.alive ? 1 : 0) | (s.boosting ? 2 : 0) | (s.firing ? 4 : 0);
    out[fTarget] = s.weaponTarget;
  }

  /// [now] ile [previous] arasında değişen alanların maskesi.
  static int maskOf(Int32List now, Int32List previous) {
    var mask = 0;
    for (var i = 0; i < fields; i++) {
      if (now[i] != previous[i]) mask |= 1 << i;
    }
    return mask;
  }

  /// Maskeyi ve YALNIZ değişen alanları yazar.
  ///
  /// Maske sıfır olsa bile kimlik ve maske yazılır (3 bayt): entity'nin hâlâ
  /// görünür olduğunu söylemenin yolu bu. Tamamen atlamak, istemcinin onu bir
  /// saniye sonra bayat sayıp düşürmesine yol açardı — oysa ilgi alanından
  /// çıkmış değil, sadece kıpırdamamış.
  static void write(ByteWriter w, int id, Int32List values, int mask) {
    w
      ..u16(id)
      ..u8(mask);
    if (mask & bitX != 0) w.u16(values[fx]);
    if (mask & bitY != 0) w.u16(values[fy]);
    if (mask & bitAngle != 0) w.u8(values[fAngle]);
    if (mask & bitThrust != 0) w.u8(values[fThrust]);
    if (mask & bitShield != 0) w.u8(values[fShield]);
    if (mask & bitHull != 0) w.u8(values[fHull]);
    if (mask & bitFlags != 0) w.u8(values[fFlags]);
    if (mask & bitTarget != 0) w.u16(values[fTarget]);
  }

  /// Delta'yı [into] temelinin ÜSTÜNE okur. Okunmayan alanlar temelde kalır.
  static void read(ByteReader r, int mask, Int32List into) {
    if (mask & bitX != 0) into[fx] = r.u16();
    if (mask & bitY != 0) into[fy] = r.u16();
    if (mask & bitAngle != 0) into[fAngle] = r.u8();
    if (mask & bitThrust != 0) into[fThrust] = r.u8();
    if (mask & bitShield != 0) into[fShield] = r.u8();
    if (mask & bitHull != 0) into[fHull] = r.u8();
    if (mask & bitFlags != 0) into[fFlags] = r.u8();
    if (mask & bitTarget != 0) into[fTarget] = r.u16();
  }

  /// Tam kayıt boyu: kimlik + maske + sekiz alan.
  static const int fullWireSize = 2 + 1 + 2 + 2 + 1 + 1 + 1 + 1 + 1 + 2;
}

/// İstemcinin tuttuğu KUANTALANMIŞ temel.
///
/// Çözülmüş (`double`) değerleri saklayıp yeniden kuantalamak CAZİP ve YANLIŞ
/// olurdu: kuantalama kayıplı, yani `unposition(position(v))` genelde `v`'yi
/// geri vermez. Bir tur sonra temel sunucununkinden ayrışır ve delta sessizce
/// bozulur — teşhisi en zor hata sınıfı. Telde ne gidiyorsa o saklanıyor.
class EntityBaseline {
  final Map<int, Int32List> _values = {};

  /// [id] için temel; yoksa oluşturulur. [isNew] ilk kez görülüyorsa `true`.
  (Int32List, bool) slot(int id) {
    final existing = _values[id];
    if (existing != null) return (existing, false);
    final fresh = Int32List(EntityDelta.fields);
    _values[id] = fresh;
    return (fresh, true);
  }

  bool has(int id) => _values.containsKey(id);

  void remove(int id) => _values.remove(id);

  void clear() => _values.clear();

  int get length => _values.length;
}

/// Alien'lerin delta kodlaması.
///
/// Gemilerden AYRI çünkü alan kümesi farklı (tür ve gövde var, açı/itki/kalkan
/// yok). Ama aynı [EntityBaseline]'ı paylaşabiliyorlar: alien kimlikleri
/// [Protocol.alienIdBase] üstünde, gemiler altında — iki uzay çakışamaz.
///
/// Ölçüldü (36 alien, ardışık iki tik): alien'lerin **%44'ü hiç kıpırdamıyor**,
/// tür ve gövde oranı **%0** değişiyor. 9 baytlık kaydın çoğu tekrar.
abstract final class AlienDelta {
  static const int bitX = 1 << 0;
  static const int bitY = 1 << 1;
  static const int bitKind = 1 << 2;
  static const int bitHull = 1 << 3;

  static const int full = 0x0F;
  static const int fields = 4;

  static const int fx = 0;
  static const int fy = 1;
  static const int fKind = 2;
  static const int fHull = 3;

  /// Tam kayıt boyu: kimlik + maske + dört alan.
  static const int fullWireSize = 2 + 1 + 2 + 2 + 1 + 1;

  static void quantize(
    Int32List out,
    int kind,
    double x,
    double y,
    double hullFraction,
    double worldWidth,
    double worldHeight,
  ) {
    out[fx] = Quantize.position(x, worldWidth);
    out[fy] = Quantize.position(y, worldHeight);
    out[fKind] = kind;
    out[fHull] = Quantize.unit(hullFraction);
  }

  static int maskOf(Int32List now, Int32List previous) {
    var mask = 0;
    for (var i = 0; i < fields; i++) {
      if (now[i] != previous[i]) mask |= 1 << i;
    }
    return mask;
  }

  static void write(ByteWriter w, int id, Int32List values, int mask) {
    w
      ..u16(id)
      ..u8(mask);
    if (mask & bitX != 0) w.u16(values[fx]);
    if (mask & bitY != 0) w.u16(values[fy]);
    if (mask & bitKind != 0) w.u8(values[fKind]);
    if (mask & bitHull != 0) w.u8(values[fHull]);
  }

  static void read(ByteReader r, int mask, Int32List into) {
    if (mask & bitX != 0) into[fx] = r.u16();
    if (mask & bitY != 0) into[fy] = r.u16();
    if (mask & bitKind != 0) into[fKind] = r.u8();
    if (mask & bitHull != 0) into[fHull] = r.u8();
  }
}
