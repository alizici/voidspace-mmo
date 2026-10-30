import '../design/turetilenler.dart';
import 'catalogue.dart';
import 'hangar.dart';
import 'yukseltme.dart';

/// Açılış sırasına bağlı sistemler.
enum Sistem {
  artiBasma('Artı basma'),
  cevirme('Çevirme'),
  droid('Droid'),
  sentez('Sentez'),
  arge('ArGe');

  const Sistem(this.ad);

  final String ad;
}

/// SİSTEM AÇILIŞ SIRASI — öğretim eğrisi, RANKA bağlı.
///
/// Her sistem birinci dakikada açık olsaydı yeni oyuncu on iki ekranla
/// karşılaşır ve hiçbirini anlamazdı. Eşik ranka bağlı, seviyeye değil:
/// sistemler oyuncunun EŞYA durumuna göre açılıyor, oynadığı süreye göre
/// değil; hızlı oynayan erken, yavaş oynayan geç açıyor, ikisi de doğru anda.
///
/// Ölçü sahip olunan en yüksek eşya rankı. Artı basma ilk rankın sonunda,
/// yani ikinci rankın eşyası görülünce; çevirme üçüncüde; droid dördüncüde;
/// sentez aynı ranktan yeterince eşya birikince; ArGe merdivenin ortasında.
/// Droid ve ArGe için eşik ilan, sistem yok. Kapalı sistem hangarda
/// [HangarError.kilitli] ile "henüz açık değil" diyor.
/// KARAR 10.7 s1
abstract final class Acilis {
  /// Artı basmanın açıldığı rank indeksi — ilk rankın sonu.
  static const int artiBasmaRanki = 1;

  /// Çevirmenin açıldığı rank indeksi — ikinci rankta.
  static const int cevirmeRanki = 2;

  /// Droid FİLOSUNUN açıldığı rank indeksi — üçüncü rankta. Kapı filoya
  /// alma: droid eşyası depoda durur, filoya eşikten sonra girer (04.10).
  static const int droidRanki = 3;

  /// ArGe'nin açıldığı rank indeksi — orta oyun. Sistem yok.
  static int get argeRanki => Turetilenler.rankSayisi ~/ 2;

  /// Hangarın rankı: sahip olunan en yüksek eşya rankı, eşya yoksa ilk rank.
  static int rankOf(Hangar hangar) {
    var enYuksek = 0;
    for (final item in hangar.inventory.values) {
      final spec = Catalogue.byId[item.specId];
      if (spec != null && spec.tier.index > enYuksek) {
        enYuksek = spec.tier.index;
      }
    }
    return enYuksek;
  }

  static bool acik(Sistem sistem, Hangar hangar) => switch (sistem) {
    Sistem.artiBasma => rankOf(hangar) >= artiBasmaRanki,
    Sistem.cevirme => rankOf(hangar) >= cevirmeRanki,
    Sistem.droid => rankOf(hangar) >= droidRanki,
    Sistem.sentez => fazlaEsyaVar(hangar),
    Sistem.arge => rankOf(hangar) >= argeRanki,
  };

  /// Aynı ranktan en az [Yukseltme.sentezOrani] eşya var mı.
  static bool fazlaEsyaVar(Hangar hangar) {
    final sayim = <int, int>{};
    for (final item in hangar.inventory.values) {
      final spec = Catalogue.byId[item.specId];
      if (spec == null) continue;
      final n = (sayim[spec.tier.index] ?? 0) + 1;
      if (n >= Yukseltme.sentezOrani) return true;
      sayim[spec.tier.index] = n;
    }
    return false;
  }

  /// Bugün açık sistemler.
  static Set<Sistem> aciklar(Hangar hangar) => {
    for (final s in Sistem.values)
      if (acik(s, hangar)) s,
  };
}
