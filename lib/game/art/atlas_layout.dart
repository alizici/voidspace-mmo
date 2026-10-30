import 'dart:ui';

/// Gemi atlasının YERLEŞİMİ — üretici ile çalışma zamanının paylaştığı tek
/// gerçek.
///
/// Ayrı bir meta dosyası (JSON) yok: kare dikdörtgenleri buradaki sabitlerden
/// hesaplanıyor, yani üreticinin yazdığı yerleşimle okuyucunun beklediği
/// yerleşim aynı koddan geliyor ve ayrışamaz.
///
/// **Neden atlas.** Ölçüldü (macOS Release, Impeller, 41 gemi): prosedürel
/// çizilen TEK bir gemi 8 ms GPU harcıyor — 120 Hz bütçesinin tamamı. Sebep
/// kare başına `saveLayer` + `ImageFilter.blur` artı yirmiden fazla ayrı
/// `MaskFilter.blur`; bunlar tile-based bir GPU'da en pahalı işlerdir. Aynı
/// sahne tamamen atlastan çizildiğinde GPU 0.9 ms.
///
/// Yani bu bir kalite kademesi ya da optimizasyon değil: **oyunun çizim
/// mimarisi.** Prosedürel kod artık bir çizici değil, bir DOKU ÜRETİCİSİ.
abstract final class AtlasLayout {
  /// Tasarım uzayı → dünya birimi. `ShipComponent` ve üretici aynı sayıyı
  /// kullanmak zorunda.
  static const double designScale = 1.15;

  /// Tasarım uzayındaki bir noktanın GEMİ-YEREL dünya karşılığı.
  ///
  /// İki adım var ve ikincisi bir kez atlandı. Üretici gövdeyi önce
  /// `centreOffset` kadar kaydırıyor — gövde tasarım uzayında orijinde
  /// DEĞİL, burnu −y'de uzakta; hücrenin ortasına oturması için kaydırılıyor
  /// — sonra [designScale] ile ölçekliyor.
  ///
  /// Kaydırmayı atlayan bir hesap bütün noktaları 26 birim BURNA doğru
  /// taşıyor. Mermiler o zaman silahtan değil, geminin önündeki boşluktan
  /// çıkıyor: gövde boyunun dörtte biri kadar bir sapma, ve tam olarak
  /// "namlu noktaları doğru değil gibi" diye görünen şey.
  ///
  /// `tool/muzzle_alignment_test.dart` bu dönüşümü PİKSELDEN doğruluyor.
  static Offset designToWorld(Offset design, double centreOffset) =>
      (design + Offset(0, centreOffset)) * designScale;

  /// Dünya birimi başına doku pikseli.
  ///
  /// Gemi 112 dünya birimi genişliğinde, kamera zoom'u 0.6 → ekranda 67
  /// mantıksal piksel. Piksel oranı 3 olan bir telefonda bu 201 fiziksel
  /// piksel eder, yani birim başına 1.79. 1.8 seçildi: bugünkü en yoğun
  /// ekranda bile büyütme YOK, yalnız küçültme — ve küçültme bedava.
  static const double pixelsPerWorldUnit = 1.8;

  /// Blok başına sütun sayısı.
  ///
  /// Tek bir uzun sütun daha basit olurdu ama doku 4096 pikseli aşardı ve
  /// birçok mobil GPU'nun tavanı tam olarak orası. Sekiz sütun, her iki
  /// boyutu da güvenli aralıkta tutuyor.
  static const int columns = 8;

  // ── Arka katman: pluma ───────────────────────────────────────────────
  //
  // Hücre boyutları TAHMİN DEĞİL: `tool/atlas_bounds_test.dart` her katmanın
  // alfa sınır kutusunu ölçer ve buradaki beyanla karşılaştırır. Bir öğe
  // hücreyi taşarsa Flutter hata vermez, kenardan keser — o test o sessiz
  // kırpmayı kırmızıya çevirir.
  //
  // Ölçülen (DÜNYA birimi): x[-51, 51] y[30, 140] — `atlas_bounds_test.dart`,
  // sıfır alfa eşiğiyle ve pişirilen ızgaranın TAMAMI üzerinde. 3 birim paylı.

  /// İtki kademesi. Dört yeterli, çünkü aradaki değerler iki komşu kare
  /// ÇAPRAZ SÖNÜMLENEREK elde ediliyor — kademe atlaması görünmüyor.
  static const int engineThrustSteps = 4;

  /// Titreşim karesi sayısı. Pluma karedeki en hızlı değişen şey; gövdeden
  /// daha fazla kareye ihtiyacı var.
  static const int enginePhases = 6;

  static const Size engineCellWorld = Size(108, 116);

  /// Y bileşeni NEGATİF ve bu doğru: pluma geminin orijinine hiç değmez, 30
  /// birim aşağıda başlar. Hücreyi orijini kapsamaya zorlamak, atlasın ve her
  /// karede boyanan dolgunun dörtte birini boşa harcardı.
  static const Offset engineAnchorWorld = Offset(54, -27);

  // ── Ön katman: korona + zırh + kor + buğu ────────────────────────────
  //
  // Ölçülen (DÜNYA birimi): x[-83, 83] y[-100, 153]. Plumadan çok daha geniş, çünkü ortam
  // koronası ve ısı buğusu da burada — ikisi de gemi dururken görünür, pluma
  // değil. Genişliğin çoğu koronanın SOLUK kuyruğu: alfa 1/255'lik bir kuyruk
  // bile sert kesilince düz bir kenar bırakır ve gemi kutuya hapsedilmiş gibi
  // görünür.

  static const int hullThrustSteps = 4;
  static const int hullPhases = 4;
  static const Size hullCellWorld = Size(172, 259);
  static const Offset hullAnchorWorld = Offset(86, 103);

  // ── Kalkan katmanı ───────────────────────────────────────────────────
  //
  // Ölçülen sınır (dünya birimi, darbe anında): ±75.

  static const int shieldStrengthSteps = 5;
  static const int shieldPhases = 4;
  static const double shieldRadiusWorld = 62;
  // Ölçülen: ±63. Kabuk darbe parlamasını taşımıyor (atlas yalnız güç
  // kademesi pişiriyor), o yüzden eski 156'lık hücre gereğinden genişti.
  static const Size shieldCellWorld = Size(132, 132);
  static const Offset shieldAnchorWorld = Offset(66, 66);

  // ── Silah yuvası katmanı ─────────────────────────────────────────────
  //
  // **Neden gövdeden AYRI bir blok.** Gemide görünen top sayısı oyuncunun
  // taktığı lazere göre değişiyor. Gövdeye pişirilmiş olsalardı her donanım
  // kademesi için ayrı bir gövde ızgarası gerekirdi: 4 itki × 4 faz × 4
  // kademe = 64 hücre, ve gövde hücresi 310×466 piksel — doku 4096 piksel
  // tavanını (çok sayıda mobil GPU'nun sınırı) rahatça aşardı.
  //
  // Ayrı blok bunu kare BAŞINA birkaç dörtgene çeviriyor: gemi başına en çok
  // beş, kırk gemide 200 — ölçülemeyecek kadar az.

  /// Kaç kaide çizili. [Bastion.hardpoints] uzunluğuyla AYNI olmak zorunda;
  /// `tool/atlas_bounds_test.dart` iki sayının ayrışmadığını doğruluyor.
  ///
  /// Buradan okunamamasının sebebi yön: sanat bu dosyayı içeri alıyor, tersi
  /// döngü olurdu.
  /// KARAR 04.9 s2 — sanat kısıtı: lazer yuvası bu sayıya sabit.
  static const int emitterMounts = 5;

  /// Yuvanın titreşim karesi sayısı GÖVDEYLE aynı ve olmak zorunda: ikisi tek
  /// bir tikten faz seçiyor. Farklı olsalardı projektörün nabzı gövdenin
  /// nabzından kayar ve gemi iki ayrı hızda soluk alırdı.
  static const int emitterPhases = hullPhases;

  /// Ölçülen (dünya birimi): x[-26, 26] y[-47, 18] — 3 birim paylı.
  ///
  /// Kutu ORİJİNDE DEĞİL: kaide orijinde duruyor ve namlu −y'de uzanıyor, o
  /// yüzden çizimin çoğu yukarıda. Çapa bunu telafi ediyor.
  static const Size emitterCellWorld = Size(58, 71);
  static const Offset emitterAnchorWorld = Offset(29, 50);

  // ── Alien katmanı ────────────────────────────────────────────────────
  //
  // Faz YOK ve gerek de yok: Void Spore'nin hareketi tamamen DÖNÜŞ ve ÖLÇEK,
  // ikisi de `RSTransform` ile çizim anında uygulanıyor. Gemi plumasında ise
  // hareket gürültünün kendisiydi — onu dönüşle taklit etmek imkânsızdı, o
  // yüzden orada kare pişiriliyor.

  static const double alienRadiusWorld = 24;

  /// Korona, kabuk, detay, çekirdek gövdesi, çekirdek koru — `alienFrame`
  /// sırası. Bkz. `VoidSpore.katmanlar`.
  static const int alienLayers = 5;

  /// En geniş katman: detay podları (r·1.22 + pod·1.8 + bulanıklık).
  /// Hücre ölçüden TÜRETİLİR; elle yazılan bir sayı sanat büyüdüğünde sessiz
  /// bir kırpmaya dönüşür (`tool/atlas_bounds_test.dart` yine de ölçüyor).
  static const Size alienCellWorld = Size(96, 96);
  static const Offset alienAnchorWorld = Offset(48, 48);

  /// Titreşim kareleri arasındaki süre (sn). Pişirme zamanları bundan türer.
  static const double phaseStep = 0.13;

  /// Pişirmenin başlangıç anı. Sabit — atlas deterministik olmalı, yoksa
  /// golden testi her koşuda değişir.
  static const double baseTime = 1.7;

  // ── Türetilen piksel geometrisi ──────────────────────────────────────

  static Size _px(Size world) =>
      Size(world.width * pixelsPerWorldUnit, world.height * pixelsPerWorldUnit);

  static final Size engineCell = _px(engineCellWorld);
  static final Size emitterCell = _px(emitterCellWorld);
  static final Size hullCell = _px(hullCellWorld);
  static final Size shieldCell = _px(shieldCellWorld);
  static final Size alienCell = _px(alienCellWorld);

  static final Offset engineAnchor = engineAnchorWorld * pixelsPerWorldUnit;
  static final Offset emitterAnchor = emitterAnchorWorld * pixelsPerWorldUnit;
  static final Offset hullAnchor = hullAnchorWorld * pixelsPerWorldUnit;
  static final Offset shieldAnchor = shieldAnchorWorld * pixelsPerWorldUnit;
  static final Offset alienAnchor = alienAnchorWorld * pixelsPerWorldUnit;

  static final int engineCount = engineThrustSteps * enginePhases;
  static final int emitterCount = emitterMounts * emitterPhases;
  static final int hullCount = hullThrustSteps * hullPhases;
  static final int shieldCount = shieldStrengthSteps * shieldPhases;

  static int _rows(int count, [int cols = columns]) => (count / cols).ceil();

  /// Yuva bloğunun sütun sayısı — atlasın GENİŞLİĞİNİ doldurur.
  ///
  /// Sabit 8 sütun ölçüldü ve 2.5 MB israf ediyordu: yuva hücresi 104 piksel,
  /// sekiz sütun 835 piksel eder, oysa atlas gövde bloğu yüzünden 2477 piksel
  /// geniş. Aradaki 1642 piksel × 3 satır tamamen boş — ama doku kod
  /// çözüldüğünde o boşluk da bellek. Yirmi hücre tek satıra sığıyor ve blok
  /// 383 pikselden 128'e iniyor.
  ///
  /// Diğer bloklar için aynı şey yapılmıyor çünkü onların hücresi zaten
  /// atlasın genişliğini dolduruyor; buradaki fark hücrenin küçük olması.
  static final int emitterColumns = () {
    final fit = (_bodyWidth / emitterCell.width).floor();
    return fit < 1 ? 1 : fit;
  }();

  static const double engineTop = 0;
  static final double hullTop =
      engineTop + _rows(engineCount) * engineCell.height;
  static final double shieldTop = hullTop + _rows(hullCount) * hullCell.height;
  static final double alienTop =
      shieldTop + _rows(shieldCount) * shieldCell.height;
  static final double emitterTop =
      alienTop + _rows(alienLayers) * alienCell.height;

  // ── Gövde silüeti katmanı ────────────────────────────────────────────
  //
  // **Neden CANLI gövde bloğundan ayrı.** Gövde bloğu 4 itki × 4 faz = 16 kare
  // pişiriyor ve hücresi 310×466 piksel: tek bir tasarım 932 piksel yükseklik
  // yiyor. Sekiz tasarımı aynı biçimde pişirmek 7.456 piksel eder ve doku 4096
  // tavanını — çok sayıda mobil GPU'nun sınırı — ikiye katlayarak aşardı.
  //
  // Ayrım şuradan geliyor: yedi tasarımın gövdesi HAREKETSİZ. Kaynakları
  // 512×512 PNG ve animasyonları yok; hareketi motor pluması taşıyor ve o
  // zaten AYRI bir blokta, paylaşılıyor. Yani yedisine 16'şar kare pişirmek
  // aynı kareyi on altı kez yazmak olurdu.
  //
  // Sonuç: tasarım başına TEK kare, tek satır, 466 piksel. Sekizinci tasarım
  // (bu projenin eriyik Bastion'u) canlı blokta kalıyor — onun on altı karesi
  // gerçekten farklı.
  static const int siluetSayisi = 7;

  static final double siluetTop =
      emitterTop + _rows(emitterCount, emitterColumns) * emitterCell.height;

  /// Atlasın genişliği: en geniş hücre × [columns].
  ///
  /// Yuva bloğu bu hesabın DIŞINDA ve olmak zorunda: genişliği o belirlemiyor,
  /// tersine kendi sütun sayısını ([emitterColumns]) bu genişliğe göre
  /// seçiyor. Listeye girseydi hesap kendi kendine bağlı olurdu.
  static final double _bodyWidth = [
    engineCell.width,
    hullCell.width,
    shieldCell.width,
    alienCell.width,
  ].map((w) => w * columns).reduce((a, b) => a > b ? a : b);

  static final Size imageSize = Size(
    _bodyWidth,
    siluetTop + _rows(siluetSayisi) * hullCell.height,
  );

  static Rect _frame(int index, Size cell, double top, [int cols = columns]) =>
      Rect.fromLTWH(
        (index % cols) * cell.width,
        top + (index ~/ cols) * cell.height,
        cell.width,
        cell.height,
      );

  /// [thrustStep] ve [phase] için motor karesi.
  static Rect engineFrame(int thrustStep, int phase) =>
      _frame(phase * engineThrustSteps + thrustStep, engineCell, engineTop);

  static Rect hullFrame(int thrustStep, int phase) =>
      _frame(phase * hullThrustSteps + thrustStep, hullCell, hullTop);

  static Rect shieldFrame(int strengthStep, int phase) =>
      _frame(phase * shieldStrengthSteps + strengthStep, shieldCell, shieldTop);

  /// [layer] 0..3 — korona, kabuk, detay, çekirdek.
  static Rect alienFrame(int layer) => _frame(layer, alienCell, alienTop);

  /// [tasarim] numaralı gövde silüeti — kademe sırasıyla, 0..6.
  ///
  /// Sekizinci kademe BURADA DEĞİL: onun gövdesi canlı ve [hullFrame]'den
  /// geliyor. İndeksler kademeyle birebir çakışıyor (0..6) ve yedincisi
  /// dışarıda kalıyor — `govde_tasarimlari_test.dart` bunu doğruluyor.
  static Rect siluetFrame(int tasarim) => _frame(tasarim, hullCell, siluetTop);

  /// [mount] 0..[emitterMounts]-1, [phase] 0..[emitterPhases]-1.
  static Rect emitterFrame(int mount, int phase) => _frame(
    phase * emitterMounts + mount,
    emitterCell,
    emitterTop,
    emitterColumns,
  );

  /// Titreşim karesini GİDİP GELEN bir dizide seç.
  ///
  /// Düz döngü (0,1,2,3,0,…) son kareden ilkine atlarken görünür bir sıçrama
  /// yapar, çünkü prosedürel gürültü periyodik değil. Gidip gelme (0,1,2,3,2,1)
  /// iki uçta da sürekli — ve kor titreşimi zaten gürültü olduğu için yönün
  /// tersine dönmesi fark edilmiyor.
  static int pingPongPhase(int tick, int phases) {
    if (phases <= 1) return 0;
    final cycle = phases * 2 - 2;
    final i = tick % cycle;
    return i < phases ? i : cycle - i;
  }
}
