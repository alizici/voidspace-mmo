import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import '../domain/ship_stats.dart';
import 'referans_cozumu.dart';

/// MERMİ — lazerin taban hasarını çarpan, tüketilen bir kalem (17).
///
/// Altı çarpan ve bir sifon. MR-1 bedava ve sınırsız: dengenin çapası, bütün
/// referans hesapları onunla kuruldu (17.2). Üst çarpanlar krediyle
/// alınıyor, birim hasar başına gittikçe pahalı (17.4). Mermi eşya değil:
/// envanterde örneği yok, yığılıyor, artı basılmıyor; gemi değişince kalıyor.
class Mermi {
  const Mermi._(this.id, this.carpan, {this.sifon = false});

  final String id;

  /// Taban hasarın çarpanı — sifonda yalnız kalkana.
  final int carpan;

  /// Sifon: gövdeye sıfır, kalkana [carpan] (17.6).
  final bool sifon;

  static const Mermi mr1 = Mermi._('MR-1', 1);

  /// Seçim yokken ve stok bitince düşülen mermi.
  static const Mermi varsayilan = mr1;

  static const Mermi sf1 = Mermi._(
    'SF-1',
    TasarimGirdileri.sifonCarpani,
    sifon: true,
  );

  /// MR-1 … MR-tavan, sonra sifon. Tavan tepe tablodan: liste elle sayılmıyor.
  static final List<Mermi> hepsi = [
    for (var m = 1; m <= TasarimGirdileri.mermiCarpanTavani; m++)
      m == 1 ? mr1 : Mermi._('MR-$m', m),
    sf1,
  ];

  static Mermi? byId(String? id) {
    if (id == null) return null;
    for (final m in hepsi) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Birim fiyat, kredi.
  /// KARAR 17.4 s1
  double get fiyat => Turetilenler.mermiFiyati(carpan);

  /// [adet] birimin fiyatı — yuvarlanmış.
  int fiyatFor(int adet) => (fiyat * adet).round();

  /// Bedava mı — MR-1, kilitle. Bedava mermi stokta durmaz, satılmaz.
  /// KARAR 17.2 s1
  bool get bedava => fiyat <= 0;

  /// Kalkana çarpan.
  double get kalkanCarpani => carpan.toDouble();

  /// Gövdeye çarpan: sifon gövdeye dokunmaz.
  /// KARAR 17.6 s1
  double get govdeCarpani => sifon ? 0 : carpan.toDouble();

  /// Kısa etiket: `MR-3 ×3`, `SF-1 ×3 kalkan`.
  String get etiket => sifon ? '$id ×$carpan kalkan' : '$id ×$carpan';

  /// NOVA mağazası mermi satabiliyor mu — hayır (kilit). Mermi krediyle,
  /// kredi zamanla: ×6 parayla değil sabırla.
  /// KARAR 17.7 s1
  static bool get novaIleSatilir => TasarimGirdileri.novaMermiSatiyor;
}

/// MERMİ ÖLÇÜMÜ — referans build'de mermi ne kazandırıyor, neye mal oluyor.
///
/// Tasarım katmanının okuyamadığı şey burada: referansın gerçek atış ritmi
/// ([ShipStats.bastion]). Fiyat ve PvE kazancı [Turetilenler]'de, gider ve
/// prim burada.
abstract final class MermiOlcumu {
  /// Sıradan bir yaratığı ×1 ile öldürmek kaç NAMLU ATIŞI: öldürme süresi ×
  /// referansın saniyedeki atışı. Birim namlu atışı (17.8).
  static double get atisBasinaOldurme =>
      TasarimGirdileri.siradanOldurmeSuresi *
      ShipStats.bastion.equippedLasers /
      ShipStats.bastion.laser.fireInterval;

  /// Saatlik mermi GİDERİ, sıradan çevrimde sürekli farm: öldürme/sa ×
  /// öldürme başına atış ÷ m × birim fiyat. Çarpan öldürme başına atışı
  /// bölüyor; gider birim hasar bedeliyle büyüyor, çarpanla değil.
  /// KARAR 17.4 s1
  static double saatlikGider(int carpan) =>
      Turetilenler.mermiOldurmeSa(carpan) *
      atisBasinaOldurme /
      carpan *
      Turetilenler.mermiFiyati(carpan);

  /// Giderin referans saatlik gelirdeki payı.
  static double gelirPayi(int carpan) =>
      saatlikGider(carpan) / TasarimGirdileri.tabanSaatlikGelir;

  /// PvP NET PRİMİ, ×m sürekli kullanımda: 11'in net primi mermi giderinden
  /// sonra. Tavan çarpanda sıfırın altı — ayarlanmadı, kesişimden çıktı.
  /// KARAR 17.5 s1
  static double pvpNetPrim(int carpan) =>
      (1 + TasarimGirdileri.pvpNetPrim) * (1 - gelirPayi(carpan)) - 1;

  /// Sifonun kalkan YENİLENMESİNE karşı etkin çarpanı: yenilenme sabit bir
  /// çıkarma, hasar büyüdükçe payı küçülüyor; nominalin üstü.
  /// KARAR 17.6 s1
  static double get sifonEtkinCarpani {
    // Referans build'in BEKLENEN DPS'i (kritik dahil), puan başına değer
    // değil: yenilenmeyle aynı birimde olmalı ki fark anlamlı olsun.
    final dps = CombatGlossary.expectedDps(ReferansCozumu.stats);
    final yenilenme = ReferansCozumu.stats.shieldRegenPerSecond;
    return (TasarimGirdileri.sifonCarpani * dps - yenilenme) /
        (dps - yenilenme);
  }
}
