import 'dart:convert';
import 'dart:typed_data';

/// Tel formatının ilkel okuma/yazma katmanı.
///
/// JSON DEĞİL, çünkü snapshot saniyede 30 kez gidiyor: JSON hem ~5 kat şişik
/// hem de ayrıştırması istemcinin kare bütçesinde görünecek kadar pahalı.
/// Elle yazılmış ikili biçim burada makul, çünkü mesaj kümesi küçük ve iki
/// ucu da biz yazıyoruz — kodlayıcı ile çözücü aynı dosyada durduğu sürece
/// ayrışamazlar (ve `codec_test.dart` gidiş-dönüşü kilitler).
///
/// Her yerde küçük-son (little endian): `ByteData`'nın varsayılanı büyük-son
/// olduğu için bu AÇIKÇA belirtilmeli, yoksa tek bir unutulmuş parametre
/// sessizce bozuk sayı üretir.
class ByteWriter {
  ByteWriter([int capacity = 512])
    : _bytes = Uint8List(capacity),
      _view = ByteData(0) {
    _view = ByteData.view(_bytes.buffer);
  }

  Uint8List _bytes;
  ByteData _view;
  int _length = 0;

  int get length => _length;

  void _ensure(int extra) {
    if (_length + extra <= _bytes.length) return;
    var capacity = _bytes.length * 2;
    while (capacity < _length + extra) {
      capacity *= 2;
    }
    final grown = Uint8List(capacity)..setRange(0, _length, _bytes);
    _bytes = grown;
    _view = ByteData.view(grown.buffer);
  }

  void u8(int v) {
    _ensure(1);
    _view.setUint8(_length, v);
    _length += 1;
  }

  void i8(int v) {
    _ensure(1);
    _view.setInt8(_length, v);
    _length += 1;
  }

  void u16(int v) {
    _ensure(2);
    _view.setUint16(_length, v, Endian.little);
    _length += 2;
  }

  void u32(int v) {
    _ensure(4);
    _view.setUint32(_length, v, Endian.little);
    _length += 4;
  }

  /// 64-bit işaretsiz — İKİ `u32` olarak, düşük yarı önce.
  ///
  /// `setUint64` DEĞİL, ve bu bir üslup tercihi değil: web hedefinde Dart'ın
  /// tamsayıları JavaScript sayıları (çift duyarlıklı kayan nokta) olduğu için
  /// `ByteData.setUint64` `UnsupportedError` atıyor. Bölme ve mod ile yazmak
  /// her platformda çalışıyor.
  ///
  /// Güvenli tavan `2^53` (JavaScript'in tam sayı sınırı) — ömür boyu kredi
  /// musluğu ~9,4 milyar, yani beş büyüklük mertebesi payımız var.
  void u64(int v) {
    u32(v % 0x100000000);
    u32(v ~/ 0x100000000);
  }

  void f32(double v) {
    _ensure(4);
    _view.setFloat32(_length, v, Endian.little);
    _length += 4;
  }

  void boolean(bool v) => u8(v ? 1 : 0);

  /// UTF-8, `u16` uzunluk önekiyle.
  void str(String v) {
    final encoded = utf8.encode(v);
    u16(encoded.length);
    _ensure(encoded.length);
    _bytes.setRange(_length, _length + encoded.length, encoded);
    _length += encoded.length;
  }

  /// Tamponu boşaltır ama BELLEĞİ tutar — aynı yazıcının yeniden
  /// kullanılabilmesi için. Snapshot yolunda tik başına onlarca mesaj
  /// yazılıyor ve her birine yeni tampon açmak saniyede binlerce kısa ömürlü
  /// `Uint8List` ederdi.
  void reset() => _length = 0;

  /// Yazılanı KOPYALAYARAK döndürür.
  ///
  /// Kopya kasıtlı ve pazarlık konusu değil: dönen tampon soketin gönderim
  /// kuyruğuna giriyor ve orada ne zaman okunacağı belli değil. Görünüm
  /// (`sublistView`) döndürmek, yazıcı [reset] ile yeniden kullanıldığında
  /// kuyrukta bekleyen paketin içeriğini altından değiştirirdi — teşhisi en
  /// zor hata sınıfı: bozulma yalnız yük altında ve rastgele görünür.
  Uint8List take() => _bytes.sublist(0, _length);
}

/// [ByteWriter]'ın aynadaki hâli. Aynı sırayla okunmadığında sessizce çöp
/// üretir — bu yüzden her mesajın kodlayıcısı ile çözücüsü yan yana durur.
class ByteReader {
  ByteReader(Uint8List bytes)
    : _bytes = bytes,
      _view = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );

  final Uint8List _bytes;
  final ByteData _view;
  int _offset = 0;

  int get remaining => _view.lengthInBytes - _offset;
  bool get atEnd => remaining <= 0;

  int u8() => _view.getUint8(_offset++);

  int i8() => _view.getInt8(_offset++);

  int u16() {
    final v = _view.getUint16(_offset, Endian.little);
    _offset += 2;
    return v;
  }

  int u32() {
    final v = _view.getUint32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  /// [ByteWriter.u64]'in karşılığı — düşük yarı önce, çarpmayla birleştirir.
  int u64() {
    final low = u32();
    final high = u32();
    return low + high * 0x100000000;
  }

  double f32() {
    final v = _view.getFloat32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  bool boolean() => u8() != 0;

  String str() {
    final length = u16();
    final start = _bytes.offsetInBytes + _offset;
    _offset += length;
    return utf8.decode(Uint8List.view(_bytes.buffer, start, length));
  }
}
