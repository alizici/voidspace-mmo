import '../design/turetilenler.dart';
import '../progression/ganimet.dart';
import '../progression/item.dart';
import '../progression/kazanc.dart';
import '../progression/fiyat_cozumu.dart';
import '../progression/referans_cozumu.dart';
import '../progression/roket.dart';
import '../progression/mermi.dart';
import '../world/dusman.dart';

/// Kayıttaki bir türetilen: kaç argüman alır, nasıl hesaplanır.
class TuretilenIslev {
  const TuretilenIslev(this.argSayisi, this.hesap, this.aciklama);

  final int argSayisi;
  final num Function(List<num> args) hesap;
  final String aciklama;
}

/// TÜRETİLEN KAYDI — belgede etiketle anılabilen türetilen değerler (16.7).
///
/// Tepe tablonun girdileri belgede `` `anaStatPayi = 0,70` `` diye etiketlenip
/// doğrulanıyordu; türetilen sayılar düzyazıda çıplak kalıyordu ve girdi
/// değişince sessizce çürüyorlardı. Bu kayıt türetilenlere de ad veriyor:
/// `` `mermiPvpTtk(6) = 5` ``, `` `sifonEtkinCarpani = 3,85` ``, yüzde için
/// `` `mermiPveKazanci(6) = %10` ``. Denetim adı burada bulur, argümanla
/// hesaplar, yazılan ondalık kadar toleransla karşılaştırır.
///
/// Kayıt ELLE büyür: belgeye yeni bir türetilen etiket girmek için önce
/// buraya bir satır. Keyfî ifade yok — Dart'ta çalışma zamanında hesaplanan
/// tek şey bu tablodaki işlevler, yani belge kodun ne dediğini soruyor, kodu
/// yeniden yazmıyor.
/// KARAR 16.7 s1
abstract final class TuretilenKaydi {
  static final Map<String, TuretilenIslev> islevler = {
    // ── 05 · droid ──
    'droidDonanimPayi': TuretilenIslev(
      0,
      (_) => Turetilenler.droidDonanimPayi,
      'Filo payının droide takılana giden kısmı (05.4 s5)',
    ),

    // ── 05 · droid dayanıklılığı ──
    'droidOmruOlum': TuretilenIslev(
      0,
      (_) => Turetilenler.droidOmruOlum,
      'Bir droid kaç ölüm dayanıyor — yüzde bölü aşınma payı (05.10)',
    ),
    'droidOmruSaat': TuretilenIslev(
      0,
      (_) => Turetilenler.droidOmruSaat,
      'Droid ömrü saat, ölçülen ölüm sıklığında (05.10)',
    ),
    'droidDusmeAraligiDk': TuretilenIslev(
      0,
      (_) => Ganimet.droidDusmeAraligiDk,
      'İki droid düşmesi arası, dakika — onarımın zaman değeri (15.3)',
    ),
    'droidOnarimNovasi': TuretilenIslev(
      0,
      (_) => Kazanc.droidOnarimNovaFor(ItemTier.cI),
      'C-I droidin +0\'da tam sayaç onarımı, NOVA (15.3)',
    ),

    // ── 04 · 08 · 09 ──
    'govdeCapasi': TuretilenIslev(
      0,
      (_) => ReferansCozumu.govdeCapasi,
      'Gövde taban havuzu, tam donanımlı referansın TTK kısıtından (08.5)',
    ),
    'referansLazerHasari': TuretilenIslev(
      0,
      (_) => Turetilenler.referansLazerHasari,
      'Referans lazerin namlu hasarı, bütçeden (04.5)',
    ),
    'referansEsyaHavuzu': TuretilenIslev(
      0,
      (_) => ReferansCozumu.referansEsyaHavuzu,
      'Jeneratörlerin referansa kattığı kalkan (08.5, 08.6)',
    ),
    'referansArti': TuretilenIslev(
      0,
      (_) => ReferansCozumu.arti,
      'Referansın artı seviyesi, ilk bandın ulaştığı (10.6)',
    ),
    'fiyatSabitNoktaAdimi': TuretilenIslev(
      0,
      (_) => FiyatCozumu.adim,
      'Fiyat sabit noktasının kaç adımda yakınsadığı (03.2)',
    ),
    'saldiriPuaniDps': TuretilenIslev(
      0,
      (_) => Turetilenler.saldiriPuaniDps,
      'Bir saldırı puanının DPS karşılığı (03.1)',
    ),
    'referansDps': TuretilenIslev(
      0,
      (_) => ReferansCozumu.referansDps,
      'Tam donanımlı referansın beklenen DPS\'i, kritik dahil',
    ),
    'rankSayisi': TuretilenIslev(
      0,
      (_) => Turetilenler.rankSayisi,
      'Merdivendeki rank sayısı (10.1)',
    ),
    // ── 12 · Yaratık ──
    'yaratikCani': TuretilenIslev(
      1,
      (a) => DusmanTasarimi(
        rank: a[0].toInt(),
        sinif: DusmanSinifi.siradan,
      ).can,
      'Sıradan yaratığın canı, bant sırası (12.2)',
    ),
    'yaratikCaniGuclu': TuretilenIslev(
      1,
      (a) => DusmanTasarimi(
        rank: a[0].toInt(),
        sinif: DusmanSinifi.guclu,
      ).can,
      'Güçlü yaratığın canı, bant sırası (12.2)',
    ),
    // ── 18 · Roket ──
    'roketKadansOrani': TuretilenIslev(
      0,
      (_) => Turetilenler.roketKadansOrani,
      'Roket aralığı ÷ lazer aralığı (18.1)',
    ),
    'roketBirimOrani': TuretilenIslev(
      0,
      (_) => Turetilenler.roketBirimOrani,
      'Roket biriminin lazer birim atışına göre hasarı (18.3)',
    ),
    'roketFiyati': TuretilenIslev(
      1,
      (a) => Turetilenler.roketFiyati(a[0].toInt()),
      'Roket mermisinin birim fiyatı, kredi (18.3)',
    ),
    'roketSalvoHasari': TuretilenIslev(
      0,
      (_) => RoketOlcumu.salvoHasari,
      'Referansın salvo tabanı (18.1)',
    ),
    'roketDpsPayi': TuretilenIslev(
      0,
      (_) => RoketOlcumu.dpsPayi,
      'Roketin referans saldırısındaki payı (18.1)',
    ),
    // ── 17 · Mermi ──
    'mermiFiyati': TuretilenIslev(
      1,
      (a) => Turetilenler.mermiFiyati(a[0].toInt()),
      'Birim fiyat, kredi (17.4)',
    ),
    'mermiHasarBedeli': TuretilenIslev(
      1,
      (a) => Turetilenler.mermiHasarBedeli(a[0].toInt()),
      'Birim hasar başına bedel (17.4)',
    ),
    'mermiOldurmeSa': TuretilenIslev(
      1,
      (a) => Turetilenler.mermiOldurmeSa(a[0].toInt()),
      'Sıradan yaratıkta saatte öldürme (17.1)',
    ),
    'mermiCevrim': TuretilenIslev(
      1,
      (a) => 3600 / Turetilenler.mermiOldurmeSa(a[0].toInt()),
      'Sıradan çevrim, saniye (17.1)',
    ),
    'mermiPveKazanci': TuretilenIslev(
      1,
      (a) => Turetilenler.mermiPveKazanci(a[0].toInt()),
      'Sıradan yaratıkta PvE kazancı, oran (17.1)',
    ),
    'mermiPveKazanciGuclu': TuretilenIslev(
      1,
      (a) => Turetilenler.mermiPveKazanci(a[0].toInt(), guclu: true),
      'Güçlü yaratıkta PvE kazancı, oran (17.1)',
    ),
    'mermiPvpTtk': TuretilenIslev(
      1,
      (a) => Turetilenler.mermiPvpTtk(a[0].toInt()),
      'PvP TTK, saniye (17.1)',
    ),
    'mermiUsAnkraji': TuretilenIslev(
      0,
      (_) => Turetilenler.mermiUsAnkraji,
      'Fiyat üssünün ankrajı (17.4)',
    ),
    'mermiSaatlikGider': TuretilenIslev(
      1,
      (a) => MermiOlcumu.saatlikGider(a[0].toInt()),
      'Sürekli farmda saatlik gider, kredi (17.4)',
    ),
    'mermiGelirPayi': TuretilenIslev(
      1,
      (a) => MermiOlcumu.gelirPayi(a[0].toInt()),
      'Giderin referans gelirdeki payı, oran (17.4)',
    ),
    'mermiPvpNetPrim': TuretilenIslev(
      1,
      (a) => MermiOlcumu.pvpNetPrim(a[0].toInt()),
      'PvP net primi, oran (17.5)',
    ),
    'sifonEtkinCarpani': TuretilenIslev(
      0,
      (_) => MermiOlcumu.sifonEtkinCarpani,
      'Sifonun yenilenmeye karşı etkin çarpanı (17.6)',
    ),
    'atisBasinaOldurme': TuretilenIslev(
      0,
      (_) => MermiOlcumu.atisBasinaOldurme,
      'Sıradan yaratığı ×1 ile öldürmek için namlu atışı (17.8)',
    ),
  };

  /// Hesapla — ad yoksa ya da argüman sayısı tutmuyorsa `null`.
  static num? hesapla(String ad, List<num> args) {
    final islev = islevler[ad];
    if (islev == null || args.length != islev.argSayisi) return null;
    return islev.hesap(args);
  }
}
