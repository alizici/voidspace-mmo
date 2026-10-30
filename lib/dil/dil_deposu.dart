/// Seçilen dilin kalıcı deposu.
///
/// [TokenStore] ile aynı gerekçe: arayüz burada, uygulaması kompozisyon
/// kökünde. Dil değiştiren bir widget testi, bir platform kanalı taklidine
/// muhtaç olmamalı.
abstract interface class DilDeposu {
  /// Kayıtlı dil kodu — hiç seçim yapılmadıysa `null`.
  ///
  /// `null` ile "tr" arasındaki fark önemli: seçim YOKSA cihazın dili
  /// kullanılıyor, seçim varsa cihaz ne derse desin oyuncunun tercihi
  /// kazanıyor. İkisini ayırmayan bir depo, Türkçe bir telefonda İngilizce
  /// oynamak isteyen birini her açılışta Türkçeye geri atardı.
  Future<String?> oku();

  Future<void> yaz(String kod);
}

/// Diske yazmayan depo — testlerin varsayılanı.
class BellekDilDeposu implements DilDeposu {
  BellekDilDeposu([this._kod]);

  String? _kod;

  @override
  Future<String?> oku() async => _kod;

  @override
  Future<void> yaz(String kod) async => _kod = kod;
}
