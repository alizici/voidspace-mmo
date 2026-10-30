import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import 'referans_cozumu.dart';

/// ROKET MERMİSİ — RK-1 … RK-6, 17'nin ikizi (18.3).
///
/// Roketatar bir silah (18.1) ve her salvoda bir birim yiyor; birim mermi
/// gibi hesapta duruyor, gemi değişince kalıyor, artı basılmıyor, düşmüyor.
/// Çarpan yalnız salvonun tabanını çarpıyor (17.3'ün kuralı); fiyat mermi
/// eğrisinin `roketBirimOrani` katı, çünkü bir salvo lazer birim atışının o
/// kadar katı hasar taşıyor — hasar başına bedel ikisinde aynı.
/// KARAR 18.3 s1
class Roket {
  const Roket._(this.id, this.carpan);

  final String id;

  /// Salvonun taban hasarını çarpan.
  final int carpan;

  static const Roket rk1 = Roket._('RK-1', 1);
  static const Roket varsayilan = rk1;

  /// Tavan mermininki (17.4): iki mermi ayrı eğri taşımıyor.
  static final List<Roket> hepsi = [
    for (var m = 1; m <= TasarimGirdileri.mermiCarpanTavani; m++)
      m == 1 ? rk1 : Roket._('RK-$m', m),
  ];

  static Roket? byId(String? id) {
    if (id == null) return null;
    for (final r in hepsi) {
      if (r.id == id) return r;
    }
    return null;
  }

  double get fiyat => Turetilenler.roketFiyati(carpan);
  int fiyatFor(int adet) => (fiyat * adet).round();
  bool get bedava => fiyat <= 0;
  String get etiket => '$id ×$carpan';

  /// NOVA roket de satmıyor: 17.7'nin kilidi.
  /// KARAR 18.5 s1
  static bool get novaIleSatilir => TasarimGirdileri.novaMermiSatiyor;
}

/// Roketin ÖLÇÜLERİ — referansta ne kadar vuruyor, gücün ne kadarı (18.1).
abstract final class RoketOlcumu {
  /// Referans build'in salvo tabanı (kadans oranı uygulanmış).
  static double get salvoHasari => ReferansCozumu.stats.roketHasari;

  /// Referansın roket DPS'i, kritik dahil.
  static double get dps => CombatGlossary.roketDps(ReferansCozumu.stats);

  /// Roketin referans saldırısındaki payı: bütçe payına yakın olmalı.
  static double get dpsPayi =>
      dps / CombatGlossary.saldiriDps(ReferansCozumu.stats);
}
