import '../design/turetilenler.dart';
import 'kaynak_akisi.dart';

/// SEVİYE — içeriğe kapı; XP ile artar, asla geri gitmez.
///
/// **XP ayrı bir kaynak değil:** öldürmeden kazanılan ÖMÜR BOYU kredi,
/// yorgunluk uygulandıktan sonra. Ayrı bir XP tablosu ilan etmek, alan 13'ün
/// musluğunu ikinci kez tanımlamak olurdu; yorgunluk XP'yi de kendiliğinden
/// kısıyor (10.8) ve tepe tabloya girdi eklenmiyor.
///
/// Seviye, XP'nin karşıladığı rank: L. seviye, ilk L neslin bütçesi kadar
/// kazanılmış demek. Referans oyuncu bir bandı bitirdiğinde tam o rankın
/// seviyesine varıyor; harcanan para geri alınmaz, seviye de düşmez.
/// Savaş puanı ekipmandan gelir ve düşebilir (09); ikisi farklı sorulara
/// cevap veriyor: "nereye girebilirim" ve "ne kadar güçlüyüm".
/// KARAR 10.1 s1
abstract final class Seviye {
  /// En yüksek seviye — rank sayısı kadar.
  static int get tavan => Turetilenler.rankSayisi;

  /// [xp] ile ulaşılan seviye, `0..tavan`.
  static int of(int xp) {
    var seviye = 0;
    var esik = 0.0;
    for (var r = 0; r < Turetilenler.rankSayisi; r++) {
      esik += KaynakAkisi.neselButcesi(r);
      if (xp < esik) break;
      seviye = r + 1;
    }
    return seviye;
  }

  /// [seviye]'ye varmak için gereken toplam XP — ilk [seviye] neslin bütçesi.
  static double esigi(int seviye) {
    var toplam = 0.0;
    for (var r = 0; r < seviye.clamp(0, Turetilenler.rankSayisi); r++) {
      toplam += KaynakAkisi.neselButcesi(r);
    }
    return toplam;
  }
}
