import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import '../design/turetilenler.dart';
import 'hull.dart';
import 'item.dart';
import 'referans_cozumu.dart';

/// REFERANS BUILD — bir kademenin "normal oyuncusu", TEK fonksiyon.
///
/// Alan 04 referansı bir bileşim olarak tanımladı (bütün yuvalar dolu,
/// jeneratörler yarı yarıya); hangi kademede hangi ranka sahip olunduğunu
/// alan 10 söylüyor: `referansBuild(kademe) = { gövde, rank, artı: +15 }`.
///
/// Uzun süre parçalar ayrı yaşadı: rank → gövde kademesi kaynak akışında,
/// rank → referans BR savaş sözlüğünde, artı hiçbir yerde. Üçü burada
/// buluşuyor ve öteki alanlar bölmeyi buradan okuyor: ganimet, kazanç,
/// yükseltme, bölge kapısı, tablolar. İkinci bir "hangi rank hangi kademede"
/// tanımı, iki tablonun sessizce ayrışması demekti.
///
/// **Artı +15 ilan, savaş puanına henüz girmiyor.** Merdivenin tabanı bugün
/// +0 çıplak referansı ölçüyor (`ShipStats.bastion`, 09.7); +15 tam donanım
/// referansına geçiş, referansın eşya havuzunu da açan B1 kararıyla birlikte
/// (borç defteri). O güne kadar [br] yalnız rank çarpanını taşıyor.
/// KARAR 10.6 s2
class ReferansBuild {
  const ReferansBuild._(this.rank);

  /// Merdivendeki rank — 0 tabanlı, `ItemTier.index`.
  final int rank;

  /// [rank]'ın referans build'i.
  static ReferansBuild of(int rank) {
    if (rank < 0 || rank >= Turetilenler.rankSayisi) {
      throw ArgumentError.value(rank, 'rank', 'merdivenin dışında');
    }
    return ReferansBuild._(rank);
  }

  /// [kademe]'nin referans build'i — bandın İLK rankındaki oyuncu.
  static ReferansBuild ofKademe(int kademe) => of(rankiFor(kademe));

  /// Referansın artı seviyesi: her zaman TAVAN.
  ///
  /// Referans "o kademenin normal oyuncusu" ise ve o oyuncu bir sonraki ranka
  /// geçmeden önce eşyasını tamamlıyorsa, yarım yükseltilmiş bir referans
  /// ölçüyü bulanıklaştırırdı. Gerçek oyuncular referansın altında kalır.
  /// Referansın artı seviyesi: beklenen, ilk bandın ulaştığı (10.6, 13.6).
  /// KARAR 10.6 s2
  static int get arti => ReferansCozumu.arti;

  /// Rankın düştüğü gövde kademesi.
  int get kademe => kademeOf(rank);

  /// Kademenin gövdesi.
  HullClass get govde => govdeFor(kademe);

  /// Rankın kendisi, eşya rengi olarak.
  ItemTier get tier => ItemTier.values[rank];

  /// Referansın savaş puanı — merdivenin bu basamağı.
  ///
  /// Bugün rank çarpanı × taban; artı ve tam donanım girmiyor (B1).
  double get br => CombatGlossary.referansBrFor(rank);

  /// [rank]'ın hangi gövde kademesine düştüğü — bölmenin TEK tanımı.
  ///
  /// Sekiz gövde yirmi rankı bölüşüyor, her gövde iki buçuk rank
  /// ([TuretilenTablolar.rankAraligiFor], taban bölme). Bölge de aynı
  /// bölmeyi kullanıyor: bölge = gövde kademesi (11).
  static int kademeOf(int rank) {
    for (var k = 0; k < TasarimGirdileri.govdeKademeSayisi; k++) {
      final (bas, bit) = TuretilenTablolar.rankAraligiFor(
        k,
        rankSayisi: Turetilenler.rankSayisi,
        kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
      );
      if (rank >= bas && rank < bit) return k;
    }
    throw ArgumentError.value(rank, 'rank', 'merdivenin dışında');
  }

  /// [kademe]'nin referans rankı — bandın ilk rankı.
  ///
  /// Bölge kapısı da onu ölçüyor (11.3): kademeye giren oyuncu o bandın
  /// ilk rankındaki referansa göre sınanıyor.
  static int rankiFor(int kademe) => TuretilenTablolar.rankAraligiFor(
    kademe,
    rankSayisi: Turetilenler.rankSayisi,
    kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
  ).$1;

  /// [kademe]'nin gövdesi.
  static HullClass govdeFor(int kademe) {
    if (kademe < 0 || kademe >= HullClass.all.length) {
      throw ArgumentError.value(kademe, 'kademe', 'aralık dışı');
    }
    return HullClass.all[kademe];
  }

  @override
  String toString() => 'ReferansBuild(${tier.label} · ${govde.name} · +$arti)';
}
