import 'bolge.dart';
import 'gecit.dart';

/// Bir haritanın OYUNCUYA GÖRE durumu — galaksi haritasının bir satırı.
///
/// Ayrı bir tip, çünkü "harita" ile "oyuncunun o haritayla ilişkisi" iki ayrı
/// şey: harita herkes için aynı, ilişki her oyuncuda başka.
class HaritaDurumu {
  const HaritaDurumu({
    required this.harita,
    required this.acik,
    required this.burada,
    required this.eksikBr,
  });

  final Harita harita;

  /// Savaş puanı yetiyor mu.
  final bool acik;

  /// Oyuncu şu anda burada mı.
  final bool burada;

  /// Açılmasına ne kadar BR kaldığı — açıksa sıfır.
  ///
  /// "Kilitli" demek yetmiyor: kapalı bir kapı ancak ne kadar uzakta olduğu
  /// bilindiğinde bir HEDEF oluyor. Bu sayı olmadan galaksi haritası bir
  /// duvar listesine dönüşür.
  final double eksikBr;

  @override
  String toString() =>
      '${harita.ad} ${acik ? "açık" : "kilitli (${eksikBr.round()} BR)"}';
}

/// GALAKSİ HARİTASI — bütün dünyanın oyuncuya göre görünümü.
///
/// Tek kuralı var ve o kural bir TASARIM KARARI: **hiçbir harita
/// gizlenmiyor.** Oyuncu gidemeyeceği yeri de görüyor, eşiğiyle birlikte.
///
/// Gizlemek daha "temiz" bir arayüz verirdi ama merdiveni görünmez yapardı:
/// oyuncu nereye gittiğini bilmeden ilerler, ve ilerlemenin bir yönü olduğu
/// hissi kaybolur. 11'in kapı kararının ikinci yüzü bu — kapı BR ölçüyor,
/// ve ölçtüğü şey görünmediği sürece bir kapı değil bir sürpriz.
///
/// Çizim katmanı DEĞİL: burada hangi haritanın var olduğu ve oyuncunun onunla
/// ilişkisi duruyor. Nasıl çizileceği istemcinin işi.
abstract final class GalaksiHaritasi {
  /// [br] gücündeki, [konum]'da duran oyuncunun gördüğü dünya.
  ///
  /// Sıra merdivenin sırası: bölge kademesi, sonra harita tipi. Liste HER
  /// ZAMAN tam — filtreleme yok.
  static List<HaritaDurumu> durumFor({
    required double br,
    int? seviye,
    Harita? konum,
  }) => [
    for (final harita in Harita.hepsi)
      HaritaDurumu(
        harita: harita,
        acik: harita.kabulEder(br, seviye: seviye),
        burada: harita == konum,
        eksikBr: harita.kabulEder(br) ? 0 : harita.girisEsigi - br,
      ),
  ];

  /// Bölge bölge gruplanmış hâli — galaksi haritasının satırları.
  static List<List<HaritaDurumu>> satirlarFor({
    required double br,
    int? seviye,
    Harita? konum,
  }) {
    final durumlar = durumFor(br: br, seviye: seviye, konum: konum);
    return [
      for (final bolge in Bolge.hepsi)
        [
          for (final d in durumlar)
            if (d.harita.bolge == bolge) d,
        ],
    ];
  }

  /// [harita]'nın komşuları — galaksi haritasındaki çizgiler.
  static List<Harita> komsularFor(Harita harita) => [
    for (final g in GecitAgi.gecitleriFor(harita)) g.hedef,
  ];

  /// Oyuncunun BULUNDUĞU haritadan bir adımda gidebilecekleri.
  ///
  /// Kilitli komşular listede YOK: görünürlük ile gidilebilirlik ayrı sorular
  /// ve bu ikincisi.
  static List<Harita> gidilebilirler(Harita konum, double br) => [
    for (final g in GecitAgi.gecitleriFor(konum))
      if (g.acik(br)) g.hedef,
  ];

  /// Dönen oyuncunun UYANDIĞI harita.
  ///
  /// Üç durum, üçü de bir kural:
  ///
  ///  * kayıt yok → başlangıç. Yeni oyuncu ya da eski kayıt.
  ///  * kayıt var ve kapı hâlâ açık → **bıraktığı yer.** Dünya sürekli bir
  ///    yer; çıkış yapmak seni başa döndürmemeli.
  ///  * kayıt var ama kapı kapanmış → girebildiği en ileri bölgenin PvE'si.
  ///
  /// Üçüncüsü olmadan kapı bir kereye mahsus bir sınav olurdu: bir kez girip
  /// sonra teçhizatını satan oyuncu, taşıyamayacağı bir bölgede sonsuza kadar
  /// park edebilirdi. Kapı bir DURUM, bir olay değil.
  ///
  /// Düşülen yer PvE, kayıtlı tip değil: PvP ve boss birer varış noktası,
  /// omurga PvE. Zorla taşınan oyuncu omurgada uyanmalı.
  static Harita girisNoktasi({
    String? kayitliId,
    required double br,
    int? seviye,
  }) {
    final kayitli = Harita.byId(kayitliId);
    if (kayitli == null) return Harita.baslangic;
    if (kayitli.kabulEder(br, seviye: seviye)) return kayitli;
    return Harita(Bolge.girilebilen(br, seviye: seviye), HaritaTipi.pve);
  }

  /// Oyuncunun bugün ulaşabildiği EN İLERİ bölge.
  ///
  /// Merdiven tek yönlü olduğu için bu tek bir sayı: kaç bölge açıldı.
  static Bolge enIleriBolge(double br, {int? seviye}) =>
      Bolge.girilebilen(br, seviye: seviye);
}
