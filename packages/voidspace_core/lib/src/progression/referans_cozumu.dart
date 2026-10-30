import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import '../domain/ship_stats.dart';
import 'budget.dart';
import 'catalogue.dart';
import 'hull.dart';
import 'item.dart';
import 'kaynak_akisi.dart';
import 'loadout.dart';
import 'referans_build.dart';
import 'stat.dart';

/// REFERANS ÇÖZÜMÜ — tam donanımlı referans build ve ondan çözülen çapalar.
///
/// 04.5 "bütün yuvalar dolu, jeneratörler yarı yarıya" diyor; uzun süre kod
/// çıplak gövde ile beş lazerle ölçtü ve eşya havuzu terimi sıfırdı (borç
/// defteri B1). Burada referans gerçekten dolu: ilk bandın gövdesi, her
/// yuvada bandın rankındaki katalog tasarımları (raf, 15.2), jeneratörler
/// `referansJeneratorKalkan` oranında kalkan, kalanı hız; artı seviyesi
/// beklenen seviye (10.6), alt stat yok (taban). Filo referansa girmiyor:
/// droid çapası referans yaylımından türüyor (05.5), referansın içine girse
/// kendi kendini ölçerdi.
///
/// Gövde çapası bu build'in TTK kısıtından çözülüyor (08.5): saldırı × T ×
/// kayıp − kalkan (gövdeninki artı jeneratörlerinki). Jeneratör bütçesi
/// büyüyünce gövde çapası küçülüyor; 08.6'nın kolu bu.
///
/// Fiyat referansı da BURASI (03.2 s2): eşya değerleri fiyata, fiyat bu
/// çözüme bağlı, yani ikisi bir sabit nokta — [FiyatCozumu] onu yineleyerek
/// çözüyor ve [statsFiyatlarla] o yinelemenin tek adımı. Gövde canı bu
/// çözümden okunuyor (`HullClass.baseHull`); çözüm gövde canına bağlı değil,
/// çünkü DPS ve kalkan cana bakmıyor — o yönde döngü yok.
/// KARAR 03.2 s2 · KARAR 04.5 s2 · KARAR 08.5 s2 · KARAR 08.6 s1 · KARAR 10.6 s2
abstract final class ReferansCozumu {
  /// Çapanın çözüldüğü rank: merdivenin ilki.
  static const int rank = 0;

  /// Beklenen artı: ilk bandın nesil bütçesinin ulaştırdığı seviye (13.6).
  ///
  /// +15 değil. 13.6 ölçtü: +15 nesil içinde ulaşılamıyor; +15'e çapalanmış
  /// bir referans dünyayı gerçek oyuncunun üstüne ayarlardı.
  static final int arti = KaynakAkisi.ulasilanSeviye(
    rank,
    ItemTier.values[rank],
  );

  static final _Cozum _cozum = _coz();

  /// Referansın [tablo] fiyatlarıyla çözülmüş statları — sabit noktanın bir
  /// adımı ([FiyatCozumu]). Global fiyat tablosunu OKUMUYOR: çağrıldığı anda
  /// o tablo kuruluyor olabilir.
  /// KARAR 03.2 s2
  static ShipStats statsFiyatlarla(Map<String, double> tablo) =>
      _coz(tablo: tablo).stats;

  /// Tam donanımlı referansın statları — oyuncunun referansı.
  static ShipStats get stats => _cozum.stats;

  /// Gövde çapası — ilk kademenin canı bölü kademe çarpanı; sekiz gövde bunu
  /// kendi çarpanıyla okuyor (04.7).
  static double get govdeCapasi => _cozum.govdeCapasi;

  /// Referansın beklenen saldırısı, kritik dahil: lazer artı roket (18).
  static double get referansDps => CombatGlossary.saldiriDps(stats);

  /// Eşya havuzu: jeneratörlerin referansa kattığı kalkan (08.5, 08.6).
  static double get referansEsyaHavuzu => _cozum.esyaHavuzu;

  /// Bir droidin dayanıklılık havuzu — referans havuzunun droid payı, filoya
  /// bölünmüş (05.5).
  static double get droidHavuzu =>
      TasarimGirdileri.droidDpsPayi *
      (govdeCapasi + TasarimGirdileri.kalkanCapasi) /
      TasarimGirdileri.droidFiloTavani;

  /// Referans yuvalarının doldurulma reçetesi: yuva tipi → tasarım → yuva payı.
  ///
  /// Jeneratör: `referansJeneratorKalkan` kadarı kalkan tasarımı, kalanı
  /// ötekiler; diğer tipler bandın rafındaki tasarımlara eşit bölünüyor. Pay
  /// kesirli kalabiliyor: üç jeneratörün yarısı bir buçuk jeneratördür ve
  /// referans bir ortalama, bir envanter değil.
  static Map<ItemSpec, double> recete(HullClass govde) {
    final raf = Catalogue.rafFor(rank);
    final sonuc = <ItemSpec, double>{};
    for (final tip in SlotType.values) {
      if (tip == SlotType.droid) continue;
      final yuva = govde.slotCount(tip);
      if (yuva == 0) continue;
      final adaylar = raf.where((s) => s.slot == tip).toList();
      if (adaylar.isEmpty) continue;
      if (tip == SlotType.generator) {
        final kalkanlar = adaylar
            .where((s) => s.mainStat == Stats.maxShield.id)
            .toList();
        final digerler = adaylar
            .where((s) => s.mainStat != Stats.maxShield.id)
            .toList();
        final kalkanPayi = kalkanlar.isEmpty
            ? 0.0
            : TasarimGirdileri.referansJeneratorKalkan;
        for (final s in kalkanlar) {
          sonuc[s] = yuva * kalkanPayi / kalkanlar.length;
        }
        for (final s in digerler) {
          sonuc[s] = yuva * (1 - kalkanPayi) / digerler.length;
        }
        continue;
      }
      for (final s in adaylar) {
        sonuc[s] = yuva / adaylar.length;
      }
    }
    return sonuc;
  }

  static _Cozum _coz({Map<String, double>? tablo}) {
    final kademe = ReferansBuild.kademeOf(rank);
    final sablon = HullClass.all[kademe];
    // Yer tutucu gövde: canı sıfır. Çözüm canı belirleyecek; DPS ve kalkan
    // cana bağlı değil, dolayısıyla can çözülürken gövde okunmuyor.
    final gecici = HullClass.yerTutucu(sablon);
    final vector = StatVector();
    for (final e in recete(sablon).entries) {
      // Roketatarın ana statı roket kapsamına (18.1): gemi kapsamına
      // yazılsaydı lazerin yaylımına karışır, referans beş namluya altıncı
      // bir namlu eklemiş olurdu.
      vector.add(
        e.key.mainStat,
        e.key.slot == SlotType.launcher ? StatScope.roket : StatScope.gemi,
        ItemBudget.mainStatValue(e.key, arti, sablon, tablo: tablo) * e.value,
      );
    }
    final ham = LoadoutResolver.apply(
      gecici,
      vector,
      equippedLasers: sablon.laserSlots,
    );
    // Saldırı lazer artı roket (18): roketatar referansta dolu ve silah.
    final saldiri = CombatGlossary.saldiriDps(ham);
    final toplamHavuz =
        saldiri *
        TasarimGirdileri.referansTTK *
        Turetilenler.referansKayipCarpani;
    final can = toplamHavuz - ham.maxShield;
    final carpan = Turetilenler.govdeKademeCarpanlari[kademe];
    return _Cozum(
      // Zırh ve kaçınma referans HEDEFLERİNDE (alan 04, `ShipStats.bastion`):
      // ilk bandın rafı ikisini de vermiyor, ama referansın savunması hedef
      // değerlerde ilan edildi ve çözüm o kayıp çarpanıyla yapıldı; statlar
      // aynı şeyi söylemeli, yoksa EHP havuzu kayıpsız okurdu.
      stats: ham.copyWith(
        maxHull: can,
        armor: ShipStats.bastion.armor,
        evasion: ShipStats.bastion.evasion,
      ),
      govdeCapasi: can / carpan,
      esyaHavuzu: ham.maxShield - sablon.baseShield,
    );
  }
}

class _Cozum {
  const _Cozum({
    required this.stats,
    required this.govdeCapasi,
    required this.esyaHavuzu,
  });

  final ShipStats stats;
  final double govdeCapasi;
  final double esyaHavuzu;
}
