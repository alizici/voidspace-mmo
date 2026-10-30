import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/palette.dart';
import '../game/art/atlas_layout.dart';
import '../game/art/bastion.dart';
import 'gemi_ikonu.dart';

/// Hangardaki geminin PORTRESİ — oyunda uçurulan gemi sanatının kendisi.
///
/// **Neden jenerik bir ikon değil.** Burası oyuncunun donanımını taktığı ekran
/// ve hemen sağında geminin adı yazıyor. Oraya bir roket ikonu ve "LAZER ×5 /
/// JENERATÖR ×4" rozetleri koymak, ekranın KONUSU olan şeyi hiç göstermemek
/// demekti; üstelik o sayılar donanım ızgarasının grup başlıklarında (LAZER
/// 3/5) zaten yazıyor. Rozetler bilgi değil tekrar üretiyordu.
///
/// **Neden atlastan değil, doğrudan çizerek.** `assets/ship_atlas.png` Flame
/// katmanının varlığı; menüye taşımak arayüze doku yükleme sorumluluğu verirdi
/// — yükleniyor hâli, hata hâli, widget testlerinde asset paketi. Sanatın
/// KAYNAĞI zaten burada duran saf `Canvas` kodu ve atlas onun pişmiş hâli.
/// Menü kaynağı doğrudan boyuyor: hangarda görünen gemi ile uzayda uçan gemi
/// tek koddan geliyor, ayrışamazlar.
///
/// **Tek gövde sanatı var ve bu bir yalan değil.** Katalogda üç gövde kayıtlı
/// (Bastion, Vanguard, Spectre) ama `ShipSwarm` hepsini AYNI atlas bloğundan
/// çiziyor — uzayda üçü de Bastion gibi görünüyor. Portre de öyle: hangarda
/// gösterilen gemi, oyuncunun uçtuğu geminin aynısı. Gövdeye göre farklı bir
/// portre çizmek, olmayan bir sanatı vaat etmek olurdu.
///
/// **Kare bütçesi.** Prosedürel bir gemi 8 ms GPU harcıyor ve tam bu yüzden
/// oyun döngüsünden çıkarıldı — `test/architecture_test.dart` "gemi düğümü
/// gemi çizmez" kuralıyla bunu koruyor. O kural kare YOLU için: 120 Hz'de her
/// karede ödenen bir bedel. Menüde geçerli değil, ama bedava da değil, o
/// yüzden bir kez ödendiğinden emin olunuyor: [RepaintBoundary] portreyi kendi
/// katmanına ayırıyor ve `shouldRepaint` hep `false`. Yuva seçmek, sekme
/// değiştirmek ya da depoyu kaydırmak portreyi yeniden boyamıyor; yalnız
/// pencere ölçüsü değişince boyanıyor.
class ShipPortrait extends StatelessWidget {
  const ShipPortrait({required this.lasers, super.key});

  /// Takılı lazer sayısı — portrede kaç top çizileceği.
  ///
  /// Hangarın en doğrudan geri bildirimi bu: bir lazer takıyorsun ve geminin
  /// üstünde bir top beliriyor. Sayı sabit olsaydı hangar, sonucu hiçbir
  /// yerde görünmeyen bir tablo düzenleme ekranı olurdu.
  final int lasers;

  /// Duran geminin ÖLÇÜLEN görünür sınırı (tasarım uzayı, `centreOffset`
  /// uygulandıktan sonra). Portre bu kutuyu çerçeveye oturtuyor.
  ///
  /// Tahmin değil: `tool/ship_portrait_test.dart` sanatı boyayıp alfa sınır
  /// kutusunu çıkarıyor ve buradaki beyanla karşılaştırıyor. Elle yazılmış bir
  /// sayı, sanat büyüdüğü gün portrenin kenarından kesilmiş bir kanat olurdu.
  ///
  /// **Eşik sıfır DEĞİL, 8/255.** `tool/atlas_bounds_test.dart` sıfır eşik
  /// kullanıyor ve orada haklı: atlas hücresi `clipRect` ile SERT kesiliyor,
  /// alfa 1'lik bir kuyruk bile kesilince düz bir çizgi bırakıyor. Burada
  /// kırpma yok — koronanın görünmez kuyruğu menünün koyu zeminine sızıyor ve
  /// parıltı gibi duruyor. O kuyruğu da kutuya almak (139×170 birim) gemiyi
  /// hiç görünmeyen bir şey uğruna dörtte bir küçültürdü.
  ///
  /// Kutu ORİJİNDE DEĞİL: merkezi 10 birim aşağıda (gövde yukarı, ısı buğusu
  /// aşağı taşıyor). Portre kutunun merkezine göre ortalanıyor, orijine göre
  /// değil — yoksa gemi çerçevede yukarı kaçık dururdu.
  static const Rect artBounds = Rect.fromLTRB(-43, -55, 45, 76);

  /// [artBounds] ölçümünün eşiği — `tool/ship_portrait_test.dart` ile ortak.
  static const int visibleAlpha = 8;

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(painter: _PortraitPainter(lasers)));
}

class _PortraitPainter extends CustomPainter {
  const _PortraitPainter(this.lasers);

  final int lasers;

  @override
  void paint(Canvas canvas, Size size) {
    const art = ShipPortrait.artBounds;
    // İki eksene birden sığdır. `min(w, h)` kısayolu geniş bir çerçevede
    // yatay yeri boşa harcıyordu; portre kutusu kare değil.
    final scale = math.min(size.width / art.width, size.height / art.height);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-art.center.dx, -art.center.dy)
      // Sanat kendi tasarım uzayında burnu −y'de UZAKTA duruyor; atlas
      // pişiricinin yaptığı kaydırmanın aynısı.
      ..translate(0, Bastion.centreOffset);
    // Zaman SABİT: portre deterministik olmalı, yoksa golden her koşuda
    // değişir. İtki SIFIR: gemi hangarda duruyor, motorları kapalı — ve tam
    // gazdaki pluma çerçevenin altından taşardı.
    Bastion.paint(
      canvas,
      time: AtlasLayout.baseTime,
      thrust: 0,
      lasers: lasers,
    );
    canvas.restore();
  }

  /// Yalnız SİLAH SAYISI değişince yeniden boyanıyor.
  ///
  /// Sabit `false` olamaz artık: oyuncu hangarda bir lazer taktığında portre
  /// güncellenmezse, ekranın tek amacı olan geri bildirim kaybolur. Yuva
  /// seçmek ya da depoyu kaydırmak hâlâ boyamıyor — o kadarı zaten
  /// `RepaintBoundary` sayesinde katmana bile gelmiyor.
  @override
  bool shouldRepaint(_PortraitPainter old) => old.lasers != lasers;
}

/// Portreyi taşıyan hangar yuvası: çerçeve, taban parıltısı, köşe işaretleri.
///
/// Çerçeve süs değil ÇEVRELEME: portrenin arka planı menünün arka planıyla
/// aynı olsaydı gemi ekranda serbest yüzüyor gibi dururdu. Kutu ona bir yer
/// veriyor — "bu gemi hangarda duruyor" cümlesini kuran şey o.
///
/// **Genişlik VERİLMİYOR, hesaplanıyor.** Kutunun oranı geminin oranı: yüksekliği
/// söylüyorsun, genişlik [ShipPortrait.artBounds]'tan çıkıyor. Elle yazılan bir
/// genişlik, geminin iki yanında sebepsiz boşluk bırakıyordu — çerçeve gemiyi
/// çevrelemiyor, içinde barındırıyor gibi duruyordu.
/// Gemi kutusu — hangarın GEMİ sekmesinde AKTİF geminin portresi.
///
/// **Neden [ShipPortrait] değil.** Portre prosedürel ve tek bir gövdeyi
/// (Bastion) çiziyor; katalogda ise sekiz gövde var ve her birinin kendi
/// sanatı ([GemiIkonu], `assets/ships/`). Oyuncunun bu ekranda sorduğu soru
/// "hangi gemiyle uçuyorum" ve sabit bir silüet o soruya YANLIŞ cevap
/// veriyordu: Yatağan alan oyuncu hangarda hâlâ Bastion görüyordu.
///
/// Portrenin kendi yorumu bir zamanlar bunu savunuyordu — "gövdeye göre
/// farklı bir portre çizmek, olmayan bir sanatı vaat etmek olurdu" — ve o gün
/// doğruydu: üç gövde kayıtlıydı ve üçünün de sanatı yoktu. Bugün sekizinin
/// de var.
///
/// **Çerçeve kalıyor, içi değişiyor.** Kutunun zemini, taban parıltısı ve
/// kenarı aynı; yalnız içindeki gemi artık aktif gövdenin kendisi.
class ShipBay extends StatelessWidget {
  const ShipBay({required this.hullId, this.height = 146, super.key});

  /// Aktif gövdenin kimliği.
  final String hullId;

  final double height;

  /// Portre ile çerçeve arasındaki nefes payı.
  static const double _pad = 12;

  @override
  Widget build(BuildContext context) {
    final inner = height - _pad * 2;
    final boy = GemiIkonu.portreBoyuFor(inner);
    return SizedBox(
      // Gemi ikonları KARE (512×512), kutu da öyle: portrenin dikdörtgen
      // sınırlarına göre hesaplanan genişlik burada gemiyi yana yaslıyordu.
      height: height,
      width: height,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: const _BayPainter(),
          child: Center(child: GemiIkonu(hullId: hullId, boy: boy)),
        ),
      ),
    );
  }
}

class _BayPainter extends CustomPainter {
  const _BayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final frame = RRect.fromRectAndRadius(box, const Radius.circular(14));

    canvas
      // Zemin: menü panelinden bir tık koyu — kutu ileri değil GERİ dursun,
      // öne çıkan şey gemi olsun.
      ..drawRRect(frame, Paint()..color = Palette.menuBg)
      // Taban parıltısı. Merkez hafif yukarıda çünkü geminin kütlesi orada;
      // tam ortaya konan bir parıltı gemiyi değil boşluğu aydınlatıyordu.
      ..drawRRect(
        frame,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 0.9,
            colors: [
              Palette.accent.withValues(alpha: 0.16),
              Palette.accent.withValues(alpha: 0.02),
              const Color(0x00000000),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(box),
      )
      ..drawRRect(
        frame.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Palette.line,
      );

    // Köşe işaretleri: teknik bir çizim çerçevesi izlenimi. Kenarlığı
    // kalınlaştırmak yerine köşeleri işaretlemek, kutuyu ağırlaştırmadan
    // "ölçüm ekranı" hissini veriyor.
    const arm = 11.0;
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Palette.accent.withValues(alpha: 0.45);
    const inset = 8.0;
    for (final (x, sx) in [(inset, 1.0), (size.width - inset, -1.0)]) {
      for (final (y, sy) in [(inset, 1.0), (size.height - inset, -1.0)]) {
        canvas
          ..drawLine(Offset(x, y), Offset(x + arm * sx, y), tick)
          ..drawLine(Offset(x, y), Offset(x, y + arm * sy), tick);
      }
    }
  }

  @override
  bool shouldRepaint(_BayPainter old) => false;
}
