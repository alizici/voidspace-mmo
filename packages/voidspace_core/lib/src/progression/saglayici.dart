import '../design/tasarim_girdileri.dart';
import 'currency.dart';
import 'item.dart';
import 'stat.dart';

/// Sağlayıcı TİPİ — motorun o kaynağı nasıl işleyeceğini tek başına
/// belirliyor (05.1).
enum SaglayiciTipi {
  /// Değer enjekte eder: vektöre sayı ekler, katmanlara toplanır, biter.
  degistirici('Değiştirici'),

  /// Kendi vektörüne sahiptir: kendi statları, kendi canı, kendi zinciri;
  /// σ ile bağlanır. Bir modül bir sayı verir; bir varlık ölebilir.
  varlik('Varlık'),

  /// Diğer ikisinin nasıl çalıştığını değiştirir.
  davranis('Davranış');

  const SaglayiciTipi(this.ad);

  final String ad;
}

/// SAĞLAYICI KAYDI — stat kaydının kardeşi: kimlik, tip, kapsam, kaynak.
///
/// Motor sağlayıcı isimlerini bilmez, yalnız kaydı okur. Kapsamı EŞYA değil
/// YUVA belirliyor (05.4): aynı lazer gemi yuvasındaysa gemiye, droid
/// yuvasındaysa droide yazar; bir eşya aynı anda iki yuvada olamadığı için
/// çift sayım riski yok.
/// KARAR 05.2 s1 · KARAR 05.4 s5
class SaglayiciKaydi {
  const SaglayiciKaydi({
    required this.kimlik,
    required this.tip,
    required this.kapsam,
    required this.kaynak,
  });

  final String kimlik;
  final SaglayiciTipi tip;

  /// Yazdığı kapsam; davranış yazmaz (`null`).
  final StatScope? kapsam;

  /// Denge için: "atış hızının yüzde kırkı nereden geliyor" sorusunun
  /// cevabı bu alanla kurulur.
  final String kaynak;
}

abstract final class Saglayici {
  /// Gemi yuvasındaki eşya — değiştirici, gemi kapsamı.
  static const esya = SaglayiciKaydi(
    kimlik: 'esya',
    tip: SaglayiciTipi.degistirici,
    kapsam: StatScope.gemi,
    kaynak: 'yuvadaki eşya',
  );

  /// Droid — varlık, droid kapsamı. Droid yuvasındaki eşya buraya yazar.
  static const droid = SaglayiciKaydi(
    kimlik: 'droid',
    tip: SaglayiciTipi.varlik,
    kapsam: StatScope.droid,
    kaynak: 'droid yuvasındaki eşya',
  );

  /// Formasyon — davranış; σ'yı ve droid dayanıklılığını iter, stat yazmaz.
  static const formasyon = SaglayiciKaydi(
    kimlik: 'formasyon',
    tip: SaglayiciTipi.davranis,
    kapsam: null,
    kaynak: 'seçili formasyon',
  );

  static const List<SaglayiciKaydi> hepsi = [esya, droid, formasyon];

  /// Droid yuvasına GİREBİLEN eşya tipleri — silah ve kalkan jeneratörü
  /// (05.4 s5).
  ///
  /// Üçüncü bir tip yok ve olmamalı: CPU droide takılsaydı fayda statları
  /// σ'dan geçip gemiye sızardı; roketatar tek yuva (04.11) ve gemiye ait.
  /// KARAR 05.4 s5
  static const Set<SlotType> droidDonanimTipleri = {
    SlotType.laser,
    SlotType.generator,
  };

  /// Bir droidin KAÇ eşya taşıdığı: elit iki, standart bir.
  ///
  /// Kural burada, `Catalogue`'da değil — çünkü onu okuyan iki yer var ve
  /// ikisi ayrı katmanda: hangar TAKARKEN sınırlıyor, çözüm STAT VERİRKEN.
  /// Uzun süre yalnız birincisi vardı ve çözüm listeye güveniyordu; kapasite
  /// değiştiği gün (merdiven droidleri elit sayılmaktan çıktı) diskteki her
  /// iki eşyalı droid ikisini birden vermeye devam etti. Tek kaynak, iki
  /// okuyucu.
  ///
  /// `currency` droidde bir fiyat etiketi değil ÇEŞİT: elit droid NOVA
  /// rafından geliyor (15.7), merdivenden düşen droid kredi çeşidi.
  /// KARAR 05.4 s5
  static int droidYuvaSayisi(ItemSpec spec) {
    if (spec.slot != SlotType.droid) return 0;
    return spec.currency == Currency.premium
        ? TasarimGirdileri.elitDroidYuvasi
        : TasarimGirdileri.droidYuvasi;
  }

  /// [yuva]'daki eşyanın yazdığı kapsam — yuva belirler, eşya değil.
  /// KARAR 05.4 s5
  static StatScope kapsamOf(SlotType yuva) =>
      yuva == SlotType.droid ? StatScope.droid : StatScope.gemi;
}

/// DROİD TASARIMI — on çizim, iki çeşit (05.8 s2).
///
/// Satın alınabilir iki droidin kendi görünüşü var: Hilal NOVA rafında,
/// Delta kredi rafında. Kalan sekizi merdivenden gelen droidlerin görünüşü;
/// rank tasarımı seçiyor ve aynı rank hep aynısını veriyor.
///
/// Eşyanın `variant` alanından okunuyor; tanınmayan varyant ucuz olanı
/// çiziyor — bilinmeyen bir eşyanın elit görünmesi yanlış bilgi olurdu.
/// KARAR 05.8 s2
enum DroidModeli {
  hilal,
  halka,
  delta,
  elmas,
  damla,
  pusula,
  cerceve,
  prizma,
  parantez,
  jiroskop;

  /// Satın alınabilir İKİ droidin tasarımı (05.8 s2): Hilal NOVA rafında,
  /// Delta kredi rafında.
  static const DroidModeli elit = hilal;
  static const DroidModeli ucuz = delta;

  /// Kalan SEKİZ tasarım — merdivenden gelen droidlerin görünüşü. Sıra
  /// sabit: rank tasarımı seçiyor ve aynı rank hep aynı droidi veriyor.
  static const List<DroidModeli> merdiven = [
    halka,
    elmas,
    damla,
    pusula,
    cerceve,
    prizma,
    parantez,
    jiroskop,
  ];

  static DroidModeli ofVariant(String? variant) {
    for (final m in values) {
      if (m.name == variant) return m;
    }
    return ucuz;
  }

  static DroidModeli ofIndex(int i) =>
      i >= 0 && i < values.length ? values[i] : ucuz;
}

/// DROİD SEVİYESİ — altı görsel kademe, güçlenme adımlarından.
///
/// Ayrı bir droid XP'si yok: droidin seviyesi eşyasının artı seviyesi (07).
/// Beş güçlenme adımı altı kademe veriyor: +0 birinci, +3 ikinci … +15
/// altıncı. Kademe ÇİZİMİ seçiyor (metal çekirdek, altıgen şasi, gövde,
/// burun sensörü, yan podlar, tamamlanmış droid); güç artı çarpanından
/// geliyor, kademeden değil.
/// KARAR 05.8 s2
abstract final class DroidSeviyesi {
  static int get tavan => 1 + ItemLevels.adimSayisi;

  /// [level] artı seviyesindeki droidin görsel kademesi, `1..tavan`.
  static int of(int level) => 1 + ItemLevels.adimSayisiFor(level);
}
