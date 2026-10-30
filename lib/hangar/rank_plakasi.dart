import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';

/// Bir rankın GÖRSEL kimliği — zemin rengi, çerçeve kademesi, derinlik.
///
/// Merdiven yirmi basamak ve yirmi ayrı renk hiçbir ızgarada ayırt edilmez.
/// Ama merdiven zaten İKİ EKSENLİ: harf ailesi ve o ailenin içindeki basamak.
/// İkon o yapıyı uydurmuyor, görünür kılıyor:
///
///   AİLE      → ZEMİN rengi (geniş alan, uzaktan okunur)
///   BASAMAK   → ÇERÇEVE (I ince gri · II gümüş + iki tırnak · III altın + dört)
///   DERİNLİK  → pip şeridi (kaç alt stat)
///
/// **Sekiz zemin, altı aile.** Kodun mekanik aile ekseni ALTI adım
/// ([ItemTier.aileSayisi]) ve iki kapak taşı SSS ailesini paylaşıyor — çevirme
/// maliyeti ikisinde de 6. Ama o ikisi RENKLE adlandırılmış ("KIRMIZI",
/// "PARLAYAN PEMBE"), yani görsel eksende kendi zeminlerini almak zorundalar.
/// İki eksen bilerek ayrı: mekanik gruplama ile görsel kimlik aynı şey değil.
class RankGorseli {
  const RankGorseli._(
    this.tier,
    this.gorselAile,
    this.acik,
    this.taban,
    this.derin,
  );

  final ItemTier tier;

  /// 0..7 — zemin rengi ve hareket eşikleri buna bakıyor.
  ///
  /// [ItemTier.aile]'den FARKLI: o altı adım, bu sekiz. Kapak taşları orada
  /// SSS'i paylaşıyor, burada ayrılıyor.
  final int gorselAile;

  final Color acik;
  final Color taban;
  final Color derin;

  /// Ailenin içindeki basamak: 0=I · 1=II · 2=III.
  ///
  /// Kapak taşlarında 2 — tek basamaklılar ve en üst çerçeveyi hak ediyorlar.
  int get basamak => kapakTasi ? 2 : tier.index % ItemTier.aileBasamagi;

  /// Tekil rank mı — I/II/III taşımıyor.
  bool get kapakTasi => gorselAile >= ItemTier.aileSayisi;

  /// Bu rankın taşıyabileceği alt stat sayısı — KODDAN, tablodan değil.
  ///
  /// Belge tablosu bir zamanlar "C=1 … SSS=6, renkler=7" diyordu; kod
  /// `min(aile+1, 4)`. Kesiğin sebebi yazılı: alt stat havuzları o kadar geniş
  /// değil ve kesiği kaldırmak üst ranklarda aynı statı iki kez basardı.
  int get derinlik => ItemBudget.altStatSayisi(tier);

  /// SS ve üstü parıldıyor. Eşik burada: altındaki her şey SABİT durmazsa
  /// hiçbiri parlamış görünmez.
  bool get parilti => gorselAile >= 4;

  /// Hücrede yazılan KISA etiket — kapak taşlarında `null`.
  ///
  /// "KIRMIZI" ve "PARLAYAN PEMBE" 56 piksellik bir hücreye sığmıyor ve
  /// kısaltılamıyorlar da: o adlar bir harf-basamak çifti değil, tek başına
  /// birer isim. Ama yazılmamaları bir kayıp değil — o iki rank zaten RENKLE
  /// adlandırılmış ve plakanın zemini tam olarak o rengi taşıyor. Yani
  /// etiketin söyleyeceği şeyi plaka çoktan söylüyor.
  String? get kisaEtiket => kapakTasi ? null : tier.label;

  /// İşaretin etrafında dönen parlak nokta sayısı.
  ///
  /// S'ten itibaren biri açılıyor ve her aileyle bir tane ekleniyor:
  /// S 1 · SS 2 · SSS 3 · Kırmızı 4 · Parlayan Pembe 5. Altındaki dört aile
  /// (C · B · A ve altı) HİÇ almıyor ve bu eşiğin kendisi bir bilgi —
  /// hepsinde bir nokta olsaydı sayı okunmaz, yalnız hareket kalırdı.
  ///
  /// Sayı SAYILABİLİR olmak zorunda, bu yüzden beşte duruyor: altı dönen
  /// nokta bir halkaya dönüşür ve "kaç tane" sorusu cevapsız kalır.
  int get yorungeNoktasi => gorselAile < 3 ? 0 : gorselAile - 2;

  /// Aile renkleri. Sıra gri → mavi → yeşil → mor → sarı → turuncu → kırmızı
  /// → pembe. Son ikisi REZERVE: tablo o rankları renkle adlandırdığı için
  /// kırmızı ve pembe başka bir aileye verilemez.
  static const List<(Color, Color, Color)> _paletler = [
    (Color(0xFFD2DAE6), Color(0xFF74849A), Color(0xFF141A24)),
    (Color(0xFF8FC4FF), Color(0xFF2F7FE8), Color(0xFF071A33)),
    (Color(0xFF8FF3B4), Color(0xFF2FC96A), Color(0xFF05281A)),
    (Color(0xFFD8B4FF), Color(0xFF9A55F5), Color(0xFF1E0838)),
    (Color(0xFFFFEDA0), Color(0xFFF5C61F), Color(0xFF302300)),
    (Color(0xFFFFCE98), Color(0xFFFF8412), Color(0xFF321400)),
    (Color(0xFFFFA8B2), Color(0xFFF52C46), Color(0xFF32020C)),
    (Color(0xFFFFB8E8), Color(0xFFFF4FC4), Color(0xFF320226)),
  ];

  /// Kapak taşlarının merdivendeki ilk indeksi — TÜRETİLEN.
  ///
  /// Elle 18 yazmak, merdiven uzadığı gün sessizce yanlış olurdu.
  static final int _ilkKapakTasi = ItemTier.aileSayisi * ItemTier.aileBasamagi;

  static final List<RankGorseli> _hepsi = [
    for (final t in ItemTier.values)
      () {
        final gorsel = t.index < _ilkKapakTasi
            ? t.index ~/ ItemTier.aileBasamagi
            : ItemTier.aileSayisi + (t.index - _ilkKapakTasi);
        final p = _paletler[gorsel.clamp(0, _paletler.length - 1)];
        return RankGorseli._(t, gorsel, p.$1, p.$2, p.$3);
      }(),
  ];

  static RankGorseli of(ItemTier tier) => _hepsi[tier.index];

  /// Bütün ranklar — görsel referans ve testler için.
  static List<RankGorseli> get hepsi => _hepsi;
}

/// Rank PLAKASI — eşya işaretinin ALTINA giren zemin.
///
/// İşaretin kendisini çizmiyor ([ItemGlyphPainter] o işi yapıyor ve rank
/// değiştiğinde değişmiyor): burada yalnız rankı anlatan katmanlar var.
/// İkisinin ayrı durması bilerek — oyuncu "hangi eşya" ile "hangi kalite"yi
/// ayrı ayrı okuyabilmeli.
///
/// **Hareket YOK ve olmayacak.** Kaynak tasarımda parıltı zamanla kayıyordu.
/// Envanter ızgarası kırk hücreye kadar çıkıyor ve her hücrenin kendi
/// animasyonu, menüyü kare başına yeniden boyanan bir şeye çevirirdi —
/// `ShipPortrait` bu bedeli tam olarak bu yüzden bir kez ödüyor. Parıltı
/// duruyor ama SABİT bir yerde: üst ranklarda zemin yine de camlı görünüyor.
abstract final class RankPlakasi {
  /// Köşe yarıçapı, kenar uzunluğunun oranı olarak.
  ///
  /// Gemi kutusundan geliyor: [ShipBay] 146 piksel yüksekliğinde 14 piksel
  /// yarıçap kullanıyor. Aynı oran, çünkü hangarda ikisi yan yana duruyor ve
  /// farklı yuvarlatılmış iki kutu iki ayrı sistem gibi okunuyordu.
  static const double koseOrani = 14 / 146;

  /// Plakayı çizer. Merkez ORİJİNDE — çağıran hücrenin ortasına taşıyor.
  ///
  /// [detay] küçük hücrede kapalı: pip şeridi 42 pikselde okunmuyor ve
  /// okunmayan bir işaret bilgi vermiyor, yalnız kontrastı düşürüyor.
  static void ciz(Canvas canvas, double s, RankGorseli r, {bool detay = true}) {
    yuzey(
      canvas,
      Rect.fromCenter(center: Offset.zero, width: s, height: s),
      r,
      olcek: s,
    );
    if (detay) _pipler(canvas, r, s);
  }

  /// YÜZEY — zemin, parıltı, kenarlık ve köşe kolları, HERHANGİ bir dikdörtgene.
  ///
  /// Plaka kare, kart dikdörtgen; ikisi aynı yüzeyi paylaşmak zorunda. Bir
  /// süre kart kendi başlık şeridini boyuyordu ve o şerit başka bir yerden
  /// gelmiş gibi duruyordu — rank rengi kartın üstüne dolu bir bant olarak
  /// yayılıyordu, oysa plakada aynı renk bir parıltı ve bir kıl çizgi.
  ///
  /// [olcek] oranların REFERANSI: köşe yarıçapı, kol uzunluğu, kalem
  /// kalınlığı hepsi buna göre. Kare plakada kenar uzunluğu; kartta çağıranın
  /// seçtiği bir uzunluk — kartın kısa kenarı değil, çünkü o zaman 440 piksel
  /// genişliğinde bir kartın köşesi 40 piksel yuvarlanırdı.
  static void yuzey(
    Canvas c,
    Rect kutu,
    RankGorseli r, {
    required double olcek,
  }) {
    final cerceve = RRect.fromRectAndRadius(
      kutu,
      Radius.circular(olcek * koseOrani),
    );
    _zemin(c, cerceve, kutu, r, olcek);
    _koseIsaretleri(c, kutu, r, olcek);
  }

  /// ZEMİN — gemi kutusunun aynısı, rank rengi PARILTIDA.
  ///
  /// **Bir süre dolu bir renk plakasıydı ve yanlıştı.** Aile rengi bütün
  /// yüzeyi kaplıyordu; yirmi hücrelik bir ızgarada bu bir renk duvarı
  /// üretiyor ve ekranın konusu olan EŞYA geri kalıyordu.
  ///
  /// Hangarda zaten bir kutu var ve doğrusunu yapıyor: [ShipBay] geminin
  /// arkasına menü panelinden bir tık KOYU bir zemin koyuyor, rengi geniş
  /// alana değil taban parıltısına veriyor, ve "kutu geri dursun, içindeki
  /// öne çıksın" diyor. Bu plaka onun aynısı — tek farkı parıltının accent
  /// değil RANK rengini taşıması.
  ///
  /// Uydurma bir dil getirmemenin bedeli de var: aynı ailenin üç basamağı
  /// (C-I · C-II · C-III) yalnız köşe işaretleriyle ayrılıyor. Dolu plakada
  /// renk alanı geniş olduğu için fark biraz daha belliydi. Ama o fark zaten
  /// AİLE farkı değildi ve ailenin içindeki basamağı renkle söylemek, iki
  /// ekseni tek kanala sıkıştırmak olurdu.
  static void _zemin(
    Canvas c,
    RRect cerceve,
    Rect kutu,
    RankGorseli r,
    double s,
  ) {
    c
      ..drawRRect(cerceve, Paint()..color = Palette.menuBg)
      // Taban parıltısı — RANK BURADA. Merkez hafif YUKARIDA, çünkü hücrenin
      // ağırlığı orada; tam ortaya konan bir parıltı boşluğu aydınlatıyordu.
      ..drawRRect(
        cerceve,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 0.9,
            colors: [
              r.taban.withValues(alpha: dolguAlfasi),
              r.taban.withValues(alpha: dolguAlfasi * 0.125),
              const Color(0x00000000),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(kutu),
      )
      // Kalınlık ORANSAL ve tabanı YOK.
      //
      // Bir süre `max(1, s * 0.007)` yazıyordu — kıl çizgi kaybolmasın diye.
      // Ama taban, oranı tam da korumak istediği yerde bozuyordu: 56 pikselde
      // istenen 0,39 yerine 1 piksel çiziliyor (iki buçuk kat kalın), 110'da
      // 0,77 yerine 1 (yalnız %30). Aynı plaka küçükken "daha sıkı"
      // görünüyordu ve fark dolgudan sanılıyordu.
      //
      // Tabana gerek de yok: Flutter alt-piksel bir konturu kendiliğinden
      // yumuşatıyor — 0,39 piksellik bir çizgi, 1 piksellik soluk bir çizgi
      // olarak çiziliyor. Yani donanım zaten doğru telafiyi yapıyor ve elle
      // eklenen taban onun üstüne biniyordu.
      ..drawRRect(
        cerceve.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.007
          ..color = r.taban.withValues(alpha: 0.30 + r.gorselAile * 0.075),
      );
  }

  /// Taban parıltısının şiddeti — AİLEYE GÖRE ARTMIYOR.
  ///
  /// Bir süre artıyordu (`0,16 + aile × 0,045`) ve üst ranklarda plaka doygun
  /// bir renk lekesine dönüyordu: Parlayan Pembe'nin dolgusu C'nin üç katıydı
  /// ve hücrenin konusu olan EŞYA onun içinde kayboluyordu.
  ///
  /// Sabit alfa rank farkını yok etmiyor, üç kanala bırakıyor:
  ///   · RENK TONU   parıltının rengi zaten aileden geliyor
  ///   · PARLAKLIK   aynı alfada sarı (#F5C61F) griden (#74849A) çok daha
  ///                 açık; merdiven kendiliğinden ısınıyor
  ///   · KENARLIK    aileyle güçlenmeye devam ediyor
  ///
  /// Değer C ailesinin eski değeri: ölçüt "C-I nişan devresinin iç dolgusu"
  /// ve o zaten doğruydu — yanlış olan üstüne bindirilen artıştı.
  static const double dolguAlfasi = 0.16;

  /// KÖŞE İŞARETLERİ — basamağı SAYAN teknik çizim kolları.
  ///
  /// Gemi kutusunda dört köşede de aynı uzunlukta duruyorlar ve tek işleri
  /// "ölçüm ekranı" hissi vermek. Burada bir bilgi taşıyorlar: I kısa ve
  /// çelik, II orta ve gümüş, III uzun ve altın.
  ///
  /// Uzunluk seçildi, SAYI değil. Kolları saymak (iki köşe / dört köşe) da
  /// mümkündü ama kutunun karakteri tam olarak dört köşesinin işaretli
  /// olması — ikisini silmek onu başka bir çerçeveye çeviriyordu.
  static void _koseIsaretleri(Canvas c, Rect kutu, RankGorseli r, double s) {
    const tonlar = [Color(0xFF7A8899), Color(0xFFC3CEDC), Color(0xFFFFD98A)];
    const uzunluklar = [0.058, 0.078, 0.100];
    const kalinliklar = [0.008, 0.011, 0.014];
    const alfalar = [0.40, 0.60, 0.85];
    final uzunluk = s * uzunluklar[r.basamak];
    final ic = s * 0.055;
    // Kalınlık oransal, taban yok — kenarlıkla aynı sebep.
    final kalem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * kalinliklar[r.basamak]
      ..strokeCap = StrokeCap.round
      ..color = tonlar[r.basamak].withValues(alpha: alfalar[r.basamak]);
    for (final (x, sx) in [(kutu.left + ic, 1.0), (kutu.right - ic, -1.0)]) {
      for (final (y, sy) in [(kutu.top + ic, 1.0), (kutu.bottom - ic, -1.0)]) {
        c
          ..drawLine(Offset(x, y), Offset(x + uzunluk * sx, y), kalem)
          ..drawLine(Offset(x, y), Offset(x, y + uzunluk * sy), kalem);
      }
    }
  }

  /// DERİNLİK — pip = alt stat sayısı. Yuva sayısı [ItemBudget.altStatTavani]
  /// kadar ve o sayı da koddan: yedi, kapak taşlarının derinliği.
  ///
  /// Alt kenarda, köşe işaretlerinin ARASINDA: kollar 0,058–0,100 uzunlukta,
  /// yedi çubuk 0,056 genişliğinde. Toplam 0,52; kolların arasına sığıyor.
  static void _pipler(Canvas c, RankGorseli r, double s) {
    final n = ItemBudget.altStatTavani;
    final g = s * 0.056, bosluk = s * 0.022;
    final toplam = n * g + (n - 1) * bosluk;
    final yanan = Color.lerp(r.taban, r.acik, 0.55)!;
    for (var i = 0; i < n; i++) {
      final merkez = Offset(-toplam / 2 + i * (g + bosluk) + g / 2, s * 0.385);
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: merkez, width: g, height: s * 0.038),
        Radius.circular(s * 0.019),
      );
      if (i >= r.derinlik) {
        c.drawRRect(rr, Paint()..color = const Color(0xFF232B36));
        continue;
      }
      c
        // Yanan pip kendi ışığını veriyor — sönükten ayrımı parlaklık,
        // renk değil. Değer karşıtlığı küçük boyutta renk tonundan güçlü.
        ..drawRRect(
          rr.inflate(s * 0.012),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = yanan.withValues(alpha: 0.28)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.014),
        )
        ..drawRRect(rr, Paint()..color = yanan);
    }
  }

  /// YÖRÜNGE NOKTALARI — işaretin etrafında dönen parlak izler.
  ///
  /// [faz] 0..1 arası bir tur. Zaman DIŞARIDAN geliyor ve gelmek zorunda:
  /// envanter kırk hücreye kadar çıkıyor ve her hücrenin kendi zamanlayıcısı
  /// kırk ayrı tik demekti. Tek bir saat bütün plakaları sürüyor
  /// (`RankSaati`), ve yalnız yörüngesi olan plakalar ona abone oluyor —
  /// C ailesindeki bir eşya hiç yeniden boyanmıyor.
  ///
  /// Yarıçap işaretin DIŞINDA, pip şeridinin İÇİNDE: işaret plakanın %52'sini
  /// kaplıyor (yarıçap 0,26), şerit 0,385'te. Noktalar 0,32'de ikisine de
  /// değmeden dönüyor.
  static void yorunge(Canvas c, double s, RankGorseli r, double faz) {
    final n = r.yorungeNoktasi;
    if (n == 0) return;
    const yaricap = 0.32;
    final nokta = s * 0.030;
    // Hale ÖLÇÜLERİ: disk yarıçapı ve bulanıklık sapması. İkisi de eskiden
    // doğrudan `drawCircle` + `MaskFilter.blur` çiftine gidiyordu; şimdi
    // aynı çift dokuyu bir kez pişiriyor.
    final haleR = nokta * 3.2;
    final sapma = s * 0.030;
    // Bulanıklık diskin DIŞINA taşıyor; doku o taşmayı da içermeli, yoksa
    // hale kenarından kesilir ve nokta sönük görünür.
    final dokuR = haleR + sapma * 3;
    for (var i = 0; i < n; i++) {
      final a = (faz + i / n) * 2 * math.pi;
      final at = Offset(math.cos(a), math.sin(a)) * (s * yaricap);
      c
        // Hale: noktanın kendisinden üç kat geniş ve çok soluk. Çıplak bir
        // beyaz nokta plakanın üstünde bir toz zerresi gibi duruyordu;
        // haleyle birlikte bir ışık kaynağı oluyor.
        //
        // PİŞMİŞ doku, `MaskFilter.blur` değil. Yörünge plakadaki tek
        // hareketli şey, yani buradaki her çağrı kare başına ödeniyor — ve
        // blur kare başına ödenebilecek en pahalı çağrılardan biri. Aynı
        // yumuşamayı radyal bir gradyan zaten veriyor; rank ve boy başına bir
        // kez pişip sonsuza kadar kopyalanıyor.
        ..drawImageRect(
          _hale(r.acik.withValues(alpha: 0.42), haleR, sapma, dokuR),
          Rect.fromLTWH(
            0,
            0,
            (dokuR * 2).ceilToDouble(),
            (dokuR * 2).ceilToDouble(),
          ),
          Rect.fromCircle(center: at, radius: dokuR),
          _haleKalemi,
        )
        ..drawCircle(
          at,
          nokta,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = Color.lerp(r.acik, const Color(0xFFFFFFFF), 0.65)!,
        );
    }
  }

  /// Hale dokularının kabı — renk ve boy başına bir tane.
  static final Map<int, ui.Image> _haleKabi = {};

  /// Hale `BlendMode.plus` ile biniyor: eskiden de öyleydi, plakanın üstünde
  /// ışık gibi durmasının sebebi o.
  static final Paint _haleKalemi = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;

  /// Hale dokusu: bulanıklaştırılmış disk, BİR KEZ.
  ///
  /// Blur burada da var ve olması gerekiyor — görüntünün aynı kalmasının tek
  /// yolu aynı çağrıyı yapmak. Fark, kaç kez yapıldığında: eskiden nokta
  /// başına her karede, şimdi renk ve boy başına bir kez.
  static ui.Image _hale(
    Color renk,
    double yaricap,
    double sapma,
    double dokuR,
  ) {
    final piksel = (dokuR * 2).ceil();
    return _haleKabi[Object.hash(renk.toARGB32(), piksel, yaricap.round())] ??=
        () {
          final kayit = ui.PictureRecorder();
          Canvas(kayit).drawCircle(
            Offset(piksel / 2, piksel / 2),
            yaricap,
            Paint()
              ..color = renk
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, sapma),
          );
          return kayit.endRecording().toImageSync(piksel, piksel);
        }();
  }

  /// BOŞ kutu — rankı olmayan yuva.
  ///
  /// Plaka yok çünkü anlatacak rank yok. Geriye kutunun iskeleti kalıyor:
  /// aynı köşe yarıçapı, aynı kıl çizgi, ama nötr. Izgaranın ritmi bozulmuyor
  /// ve boşluk "burada bir şey OLABİLİR" diyor.
  static void bosKutu(Canvas c, double s) {
    final kutu = Rect.fromCenter(center: Offset.zero, width: s, height: s);
    final cerceve = RRect.fromRectAndRadius(
      kutu,
      Radius.circular(s * koseOrani),
    );
    c
      ..drawRRect(
        cerceve,
        Paint()..color = const Color(0xFF04060B).withValues(alpha: 0.34),
      )
      ..drawRRect(
        cerceve.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.007
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.07),
      );
  }

  /// YÜKSELTME İŞARETİ — "takılı olandan iyi".
  ///
  /// **Eskiden dolu yeşil bir üçgendi ve kutuya ait değildi.** Kutunun bütün
  /// dili kıl çizgi: köşe kolları, kenarlık, pip şeridi. Onların arasına konan
  /// dolu bir üçgen, başka bir arayüzden kopyalanmış gibi duruyordu — üstelik
  /// kendini görünür kılmak için 3 piksellik koyu bir kontura ihtiyaç duyuyor,
  /// yani zeminle kavga ediyordu.
  ///
  /// Yerine ÇİFT ÇEVRON: aynı yuvarlak uçlu kıl çizgi, aynı halelenme. İki
  /// tane, çünkü tek çevron bir ok ucu; iki tane üst üste "daha yukarı" diyor
  /// ve okla karıştırılmıyor.
  ///
  /// Konum SAĞ ÜST — takılı halkasının tam yerinde.
  ///
  /// İkisi aynı köşeyi paylaşabilir çünkü aynı anda olamazlar: takılı bir
  /// parça kendisinin yükseltmesi değil. Ayrı köşelere koymak, boş bir köşeyi
  /// sonsuza kadar rezerve etmek olurdu.
  ///
  /// Bir ara üst ORTAYA konmuştu ve orası boş değilmiş: kademe harfi sol
  /// üstten başlayıp "C-III"te ortaya kadar geliyor, çevronlar harfin üstüne
  /// biniyordu.
  static void yukseltmeIsareti(Canvas c, double s) {
    const renk = Palette.good;
    final merkez = Offset(s * 0.36, -s * 0.36);
    final yariGenislik = s * 0.075;
    final kalem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.032
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = renk;
    final hale = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus
      ..color = renk.withValues(alpha: 0.40)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.030);
    for (final dy in [merkez.dy - s * 0.038, merkez.dy + s * 0.030]) {
      final yol = Path()
        ..moveTo(merkez.dx - yariGenislik, dy + s * 0.038)
        ..lineTo(merkez.dx, dy)
        ..lineTo(merkez.dx + yariGenislik, dy + s * 0.038);
      c
        ..drawPath(yol, hale)
        ..drawPath(yol, kalem);
    }
  }

  /// + BASMA rozeti — sağ üstte, ikonun en yüksek okuma önceliği.
  ///
  /// Rengi AİLEDEN bağımsız: iki eksen karışmamalı ve C ailesinden bir +15 de
  /// dikkat çekmeli. Punto oransal DEĞİL, en az 8,5 — 42 pikselde de okunmalı.
  ///
  /// **Köşe seçilebilir ve seçilmek zorunda.** Kaynak tasarım rozeti sağ üste
  /// koyuyordu; bu projede orası DOLU — yükseltme oku ve takılı noktası orada
  /// duruyor. İki işaret üst üste binince ikisi de okunmuyordu.
  static void artiRozeti(Canvas c, double s, int arti, {bool altKose = true}) {
    if (arti <= 0) return;
    final renk = artiRengi(arti);
    final tp = TextPainter(
      text: TextSpan(
        text: '+$arti',
        style: TextStyle(
          // Menünün her yeri bu aileyi kullanıyor (`MenuType._s`,
          // `Palette`). Belirtilmezse `TextPainter` platformun varsayılanına
          // düşüyor ve rozet menünün geri kalanından farklı bir yazıyla
          // çıkıyor — testte ise Ahem'e düşüp dolu kare oluyor.
          fontFamily: 'monospace',
          // 0,20 → 0,155. İlk oran 220 pikselde rozeti plakanın altıda biri
          // yapıyordu ve tile'ın konusu artı seviyesi değil.
          fontSize: math.max(8.5, s * 0.155),
          fontWeight: FontWeight.w900,
          color: renk,
          letterSpacing: -0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pay = math.max(1.8, s * 0.026);
    final yukseklik = tp.height + pay * 0.9;
    final kutu = Rect.fromLTWH(
      s * 0.47 - tp.width - pay * 2,
      altKose ? s * 0.47 - yukseklik : -s * 0.47,
      tp.width + pay * 2,
      yukseklik,
    );
    final yaricap = Radius.circular(math.max(2.0, s * 0.045));
    final rr = RRect.fromRectAndRadius(kutu, yaricap);
    c
      // Gölge YOK ve bilerek yok. Bir süre vardı: rozeti plakadan ayırmak
      // için altına koyu bir kopya konuyordu. Kutu zemini zaten koyu olduğu
      // için gölge ayırmıyor, kirletiyordu — rozetin altında bulanık bir
      // leke gibi duruyordu.
      ..drawRRect(
        rr,
        Paint()
          ..shader = ui.Gradient.linear(kutu.topCenter, kutu.bottomCenter, [
            const Color(0xFF1A2029),
            const Color(0xFF090D14),
          ]),
      )
      ..drawRRect(
        rr.deflate(math.max(0.5, s * 0.008)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, s * 0.008)
          ..color = renk.withValues(alpha: arti >= 13 ? 0.85 : 0.38),
      );
    if (arti >= 13) {
      c.drawRRect(
        rr.inflate(math.max(1.0, s * 0.02)),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = renk.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.024),
      );
    }
    tp.paint(c, Offset(kutu.left + pay, kutu.top + pay * 0.45));
  }

  /// + kademesinin rengi. Klasik risk merdiveni: yükseldikçe ısınıyor.
  ///
  /// Eşikler [ItemLevels.max]'tan TÜRÜYOR, elle yazılmıyor: tavan değişirse
  /// renkler onunla birlikte yeniden bölünüyor.
  static Color artiRengi(int arti) {
    if (arti <= 0) return const Color(0xFF8A98AA);
    final oran = arti / ItemLevels.max;
    if (oran <= 0.40) return const Color(0xFFDCE6F2);
    if (oran <= 0.60) return const Color(0xFFFFD84A);
    if (oran <= 0.80) return const Color(0xFFFF9A2E);
    if (oran < 1.0) return const Color(0xFFFF4A5E);
    return const Color(0xFFFF6ED8);
  }
}
