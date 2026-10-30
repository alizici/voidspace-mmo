import '../domain/ship_stats.dart';
import 'budget.dart';
import 'referans_cozumu.dart';

/// FİYAT ÇÖZÜMÜ — stat fiyatlarının DOLU referanstaki sabit noktası.
///
/// 03.2 fiyatın tek bir referans noktada ölçülmesini istiyor; 04.5 ise
/// referansı tam donanımlı ilan etti. Uzun süre ikisi ayrı noktaydı: fiyatlar
/// çıplak gövde ile referans silahından (`ShipStats.bastion`) ölçülüyordu,
/// oyuncunun referansı ise [ReferansCozumu] idi (borç defteri B22). Sonucu
/// yüzdesel statlarda görülüyordu — dolu referansta bir yüzde puanı iki
/// katından çok DPS ediyor, yani yüzde statlar fiyatlarından değerliydi ve
/// 08'in Shapley ölçümü bunu payların sapması olarak gösteriyordu.
///
/// Fiyatı dolu referanstan ölçmenin zorluğu bir DÖNGÜ: fiyat → eşyanın ana
/// stat değeri → referansın statları → fiyat. Burada o döngü kesilmiyor,
/// ÇÖZÜLÜYOR — sabit nokta yinelemesiyle:
///
///  0. Tohum: çıplak gövde ile ölçülen fiyatlar (eski ölçüm noktası).
///  1. O fiyatlarla referansın bütün yuvalarını doldur, statlarını çöz.
///  2. Fiyatları o referansta yeniden ölç.
///  3. İki tablo arasındaki en büyük bağıl fark [esik]'in altına inene kadar
///     1–2'yi tekrarla.
///
/// Yakınsıyor ve HIZLI yakınsıyor: bugün [adim] adımda, çünkü ilk bandın
/// rafında yüzdesel ANA stat yok — lazerin ve roketatarın ana statı taban
/// hasar (fiyatı çapa, tam 1,00), jeneratörünki kalkan ve CPU'nunki kalkan
/// yenilenmesi (ikisi de havuz cinsinden, fiyatları referanstan bağımsız).
/// Yani bugünkü rafta geri besleme yok ve ikinci adım birinciyi doğruluyor.
/// Rafa yüzdesel bir ana stat girdiği gün döngü gerçekten kapanır ve
/// yineleme işini yapar: geri besleme NEGATİF (yüzde statlar pahalılaşınca
/// referans zayıflar, zayıflayınca ucuzlarlar), yani daralan bir dizi.
///
/// Yakınsamazsa sessizce yanlış bir tablo dönmüyor, [StateError] atıyor:
/// ıraksayan bir fiyat tablosu bütün eşya değerlerini bozar ve o hatanın
/// sessiz kalması, yanlış dengeyi aylarca taşımak demek olurdu.
/// KARAR 03.2 s2
abstract final class FiyatCozumu {
  /// Yineleme tavanı — aşılırsa çözüm yok sayılıyor.
  static const int adimTavani = 32;

  /// Yakınsama eşiği: iki adım arasındaki en büyük BAĞIL fark.
  ///
  /// Mutlak değil bağıl, çünkü tablodaki fiyatlar dört büyüklük mertebesine
  /// yayılıyor (`kalkan` 20, `hasar_artisi` 0,0007).
  static const double esik = 1e-12;

  static final _Cozum _cozum = _coz();

  /// Sabit noktadaki fiyat tablosu — `ItemBudget.fiyatlar` bunu okuyor.
  static Map<String, double> get fiyatlar => _cozum.fiyatlar;

  /// Fiyatın ölçüldüğü nokta: sabit noktadaki tam donanımlı referans.
  static ShipStats get referans => _cozum.referans;

  /// Kaç adımda yakınsadı — belgeye yazılan sayı, teste bağlanan sayı.
  static int get adim => _cozum.adim;

  /// Son adımdaki en büyük bağıl fark.
  static double get sapma => _cozum.sapma;

  /// Bir SİSTEM puanının DPS karşılığı: `2A ÷ 100` (03.1, 09.5).
  ///
  /// A fiyatın ölçüldüğü referansın saldırısı. Tek yerde durması şart:
  /// fiyatlayan ile ölçen (`PayOlcumu`) aynı kuru okumazsa sistem statı bir
  /// yerde pahalı, öteki yerde ucuz sayılır ve fark payların sapması gibi
  /// görünür.
  /// KARAR 03.2 s2
  static double get sistemPuaniDps => 2 * ItemBudget.olcumDps(referans) / 100;

  static _Cozum _coz() {
    // Tohum: eski ölçüm noktası. Yinelemenin başlangıcı, kendisi bir karar
    // değil — sabit nokta tektir, nereden başlandığı sonucu değiştirmiyor.
    var tablo = ItemBudget.fiyatlariTuret(ShipStats.bastion);
    var referans = ShipStats.bastion;
    for (var adim = 1; adim <= adimTavani; adim++) {
      referans = ReferansCozumu.statsFiyatlarla(tablo);
      final yeni = ItemBudget.fiyatlariTuret(referans);
      final sapma = _sapma(tablo, yeni);
      tablo = yeni;
      if (sapma <= esik) return _Cozum(tablo, referans, adim, sapma);
    }
    throw StateError(
      'fiyat sabit noktası $adimTavani adımda yakınsamadı — 03.2 s2\'nin '
      'yinelemesi ıraksıyor, fiyat referansını düz sayılara çapala',
    );
  }

  /// İki tablo arasındaki en büyük BAĞIL fark.
  static double _sapma(Map<String, double> a, Map<String, double> b) {
    var enBuyuk = 0.0;
    for (final ad in {...a.keys, ...b.keys}) {
      final x = a[ad] ?? 0;
      final y = b[ad] ?? 0;
      final olcek = x.abs() > y.abs() ? x.abs() : y.abs();
      final fark = olcek == 0 ? 0.0 : (x - y).abs() / olcek;
      if (fark > enBuyuk) enBuyuk = fark;
    }
    return enBuyuk;
  }
}

class _Cozum {
  const _Cozum(this.fiyatlar, this.referans, this.adim, this.sapma);

  final Map<String, double> fiyatlar;
  final ShipStats referans;
  final int adim;
  final double sapma;
}
