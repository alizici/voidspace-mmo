import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../game/art/govde_tasarimlari.dart';

/// Bir gövde kademesinin menü İKONU.
///
/// **Neden portre değil.** [ShipPortrait] geminin sanatını prosedürel boyuyor
/// ve bir gemi 8 ms GPU harcıyor. Hangarda tek bir portre var, orada bedeli
/// bir kez ödemek doğru. Filo ızgarası ve mağaza gövde ızgarası ise SEKİZ kart
/// gösteriyor — hepsini prosedürel boyamak aynı karede 64 ms ederdi.
///
/// İkonlar bu yüzden PNG: yedisi voidspace2 katalogundan, sekizincisi bu
/// projenin kendi sanatından `tool/govde_ikonu_test.dart` ile pişirilmiş.
///
/// **[cacheWidth] neden var.** Dosyalar 512×512 ve kart içindeki ikon 56–96
/// mantıksal piksel. Ham çözünürlükte çözülen sekiz görüntü 8 MB tutardı;
/// çözüm anında küçültmek onu otuzda birine indiriyor. Küçültme bedava,
/// büyütme değil — o yüzden istenen boy piksel oranıyla çarpılıyor.
class GemiIkonu extends StatelessWidget {
  const GemiIkonu({required this.hullId, required this.boy, super.key});

  /// Hangar filo kartındaki boy.
  static const double filoBoyu = 48;

  /// Mağaza gövde kartındaki boy.
  static const double magazaBoyu = 52;

  /// Gemi adının solundaki küçük gemi (gemi şeridi).
  static const double seritBoyu = 44;

  /// GEMİ sekmesindeki büyük portrenin BASAMAKLARI.
  ///
  /// Kutunun yüksekliği bölmeyle değişiyor ama ikonun boyu değişemez:
  /// [cacheWidth] önbellek anahtarına giriyor ve sürekli değişen bir boy her
  /// karede yeni bir çözümleme demek olurdu. Bunun yerine sığan en büyük
  /// basamak seçiliyor ([portreBoyuFor]) — kutu akışkan, ikon ayrık.
  static const List<double> portreBoylari = [96, 144, 200, 264];

  /// [alan] piksele sığan en büyük portre basamağı.
  static double portreBoyuFor(double alan) {
    var secim = portreBoylari.first;
    for (final b in portreBoylari) {
      if (b <= alan) secim = b;
    }
    return secim;
  }

  /// Kullanılan BÜTÜN boylar.
  ///
  /// Liste süs değil: `Image.asset` [cacheWidth] verdiği için önbellek
  /// anahtarına BOY giriyor. Golden testi ikonları önceden çözerken aynı
  /// boyları kullanmak zorunda — bir boy listede yoksa o kart goldende
  /// SESSİZCE boş çıkıyor. Tam olarak bir kez öyle oldu: test 48 ve 64
  /// çözüyordu, mağaza kartı 52 istiyordu.
  static const List<double> boylar = [
    filoBoyu,
    magazaBoyu,
    seritBoyu,
    ...portreBoylari,
  ];

  /// Gövde kimliği. Kademeye çeviren adım BURADA, sanat katmanında değil:
  /// `test/architecture_test.dart` çizim kodunun durum katmanını okumasını
  /// yasaklıyor — bir gövde eklemek sanat dosyasına dokunmayı gerektirmemeli.
  /// Kayıt yalnız kademeyi biliyor; kimliği bilen arayüz.
  final String hullId;

  /// Kenar uzunluğu (mantıksal piksel).
  final double boy;

  @override
  Widget build(BuildContext context) {
    final kademe = HullClass.all.indexWhere((h) => h.id == hullId);
    if (!GovdeTasarimlari.gecerli(kademe)) {
      return SizedBox(width: boy, height: boy);
    }
    final tasarim = GovdeTasarimlari.byKademe(kademe);
    final oran = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return SizedBox(
      width: boy,
      height: boy,
      child: Image.asset(
        tasarim.ikon,
        width: boy,
        height: boy,
        cacheWidth: (boy * oran).round(),
        fit: BoxFit.contain,
        // Menüde bir kare bile boş kalmasın: ikon yüklenene kadar yer
        // tutuluyor, kart zıplamıyor.
        gaplessPlayback: true,
        // Asset eksikse kart çökmesin — ızgara sekiz gövdeyi de göstermeye
        // devam etsin. Sessiz kalmıyor: `test/govde_tasarimlari_test.dart`
        // sekiz dosyanın da depoda olduğunu doğruluyor.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
