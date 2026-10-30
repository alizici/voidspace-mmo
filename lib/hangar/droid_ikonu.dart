import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../dil/icerik.dart';
import '../game/art/droid_art.dart';

/// Bir droidin menü RESMİ — mağaza kartında ve envanter hücresinde.
///
/// **Neden PNG değil.** Gövdeler ([GemiIkonu]) PNG çünkü gemi sanatı
/// prosedürel boyandığında kart başına ~8 ms GPU yiyor ve mağazada sekiz
/// gemi birden duruyor. Droid çizimleri o sanat değil: birkaç yay, birkaç
/// çizgi ve bir dolgudan ibaret vektör şekiller. Onları dosyaya pişirmek on
/// tasarım × iki boy = yirmi varlık demek olurdu ve tasarımın rengi
/// değiştiğinde hepsinin yeniden pişirilmesi gerekirdi. Aynı çizim kodunu
/// kullanmak, mağazadaki droidin savaşta göreceğinle AYNI şey olmasını da
/// bedavaya garantiliyor.
///
/// **Ad ile aranıyor, indeksle değil.** Çekirdek [DroidModeli], sanat
/// [DroidCizimi] — iki ayrı numaralandırma ve ikisi bugün aynı sırada.
/// Sıraya güvenip indeksle eşlemek, birine bir tasarım eklendiği gün bütün
/// droidleri sessizce yanlış resme kaydırırdı. Ad eşlemesi o günü hatasız
/// geçiriyor: tanınmayan ad ilk tasarıma düşüyor, kart boş kalmıyor.
class DroidIkonu extends StatelessWidget {
  const DroidIkonu({required this.model, required this.boy, super.key});

  /// Mağaza eşya kartındaki resim boyu — kademe kutusunun yerini alıyor.
  static const double magazaBoyu = 42;

  /// Görünüş (tasarım) kartındaki boy.
  static const double gorunusBoyu = 52;

  final DroidCizimi model;

  /// Kenar uzunluğu (mantıksal piksel).
  final double boy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: boy,
    height: boy,
    child: CustomPaint(painter: DroidIkonuBoyaci(model)),
  );
}

/// Droid çizimini bir kutunun ortasına oturtan boyacı — durgun, tek kare
/// (05.8 s2). Menüde dönen bir droid dikkat çalar; burada anlatılan şey
/// hareket değil KİMLİK.
class DroidIkonuBoyaci extends CustomPainter {
  const DroidIkonuBoyaci(this.model, {this.dolgu = 1.8});

  final DroidCizimi model;

  /// Kutunun kısa kenarı bu sayıya bölünüp çizim YARIÇAPI oluyor — küçük
  /// sayı büyük resim.
  ///
  /// Neden 2 değil. Çizimler yarıçaplarının tamamını kullanmıyor: hilalin
  /// ucu ile kutunun kenarı arasında art arda iki boşluk kalıyordu, biri
  /// çizimin kendi payı biri kutunun. Sonuç, komşusundaki kademe harfinden
  /// belirgin biçimde sönük duran bir resimdi.
  final double dolgu;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    DroidArt.of(model).draw(canvas, size: size.shortestSide / dolgu);
  }

  @override
  bool shouldRepaint(DroidIkonuBoyaci eski) =>
      eski.model != model || eski.dolgu != dolgu;
}

/// Tasarım ADINDAN çizim modeli; tanınmayan ad ilk tasarım.
///
/// Tek yerde durması önemli: aynı eşleme mağaza kartında, envanter
/// hücresinde ve filo hücresinde ayrı ayrı yazılsaydı biri güncellenmeden
/// kalırdı — ve o hücre komşusundan başka bir droid gösterirdi.
DroidCizimi droidCizimiAdiyla(String? ad) => DroidCizimi.values.firstWhere(
  (m) => m.name == ad,
  orElse: () => DroidCizimi.values.first,
);

/// Bu eşya bir DROİD mi, öyleyse hangi tasarım.
///
/// Örneğin seçtiği tasarım şemanınkini EZİYOR: oyuncu droidinin görünüşünü
/// değiştirebiliyor (05.8 s2) ve envanterde görmesi gereken şey satın aldığı
/// şema değil, elindeki droid.
DroidCizimi? droidCizimiOf(ItemSpec? spec, ItemInstance? item) {
  final kimlik = droidTasarimKimligi(spec, item);
  return kimlik == null ? null : droidCizimiAdiyla(kimlik);
}
