import '../design/tasarim_girdileri.dart';
import 'seviye.dart';

/// ArGe DALI — ağacın iki kolu (05.7).
///
/// Dal bir tema değil bir YÖN: her dal σ'yı bir tarafa çekiyor. Üçüncü bir
/// dal eklemek yeni bir yön ilan etmek demek.
///
/// İZİN AYRI BİR DAL DEĞİL. Bir zamanlar üçüncü bir `izin` değeri vardı ve
/// hiçbir düğüm ona ait değildi: izinler 05.7'nin dediği yerde, iki zincirin
/// SONUNDA duruyor — filo dalının ucu bir droid yuvası, gemi dalının ucu
/// ikinci donatım profili açıyor. Boş bir dalın enum'da beklemesi zararsız
/// görünüyordu ama bir davetiyeydi: oraya dosyalanan ilk düğüm ekranda
/// üçüncü bir sütun açar ve "izin dalın SONUNDA" kuralını sessizce bozardı.
enum ArGeDali {
  /// Filoya yatırım: σ yukarı, güç droid tarafına kayıyor.
  filo('Filo'),

  /// Gemiye yatırım: σ aşağı, güç gemide kalıyor.
  gemi('Gemi');

  const ArGeDali(this.ad);

  final String ad;
}

/// ArGe'nin AÇTIĞI izinler (05.7).
///
/// "Sayı değil izin": bu düğümler hiçbir stat vermiyor, bir şeyi mümkün
/// kılıyor. Bugün ikisi var ve ikisi de var olan bir sınırı bir adım
/// gevşetiyor.
enum ArGeIzni {
  /// Filoya bir droid daha — filo tavanı bir artıyor (04.10).
  filoYuvasi,

  /// İkinci donatım profili: aynı gemide iki kayıtlı donatım.
  ikinciProfil,
}

/// Bir ArGe düğümü.
///
/// Düğüm ya kapsam yönlendiriyor ([aktarimDeltasi]) ya izin açıyor ([izin]);
/// ikisini birden yapan düğüm yok, çünkü o düğümün maliyeti iki farklı şeyin
/// fiyatı olurdu.
class ArGeDugumu {
  const ArGeDugumu({
    required this.id,
    required this.ad,
    required this.dal,
    required this.maliyet,
    this.onkosul,
    this.aktarimDeltasi = 0,
    this.izin,
  });

  final String id;
  final String ad;
  final ArGeDali dal;

  /// Kaç ArGe puanı — puan seviyeden geliyor (10.1).
  final int maliyet;

  /// Bundan önce alınması gereken düğüm; `null` ise dalın kökü.
  final String? onkosul;

  /// AKTARIM KATSAYISINA (σ) eklenen miktar; artı filoya, eksi gemiye.
  final double aktarimDeltasi;

  /// Açtığı izin; sayı veren düğümlerde `null`.
  final ArGeIzni? izin;
}

/// ArGe — pasif ağaç, YENİ STAT İCAT ETMEZ (05.7).
///
/// Ağacın tamamı iki şey yapıyor ve üçüncüsünü yapmıyor:
///
///   KAPSAM YÖNLENDİRME — filo dalı σ'yı yukarı, gemi dalı aşağı itiyor.
///   Toplam güç değişmiyor, YERİ değişiyor: aynı çarpanlar ya gemide kalıyor
///   ya droid grubuna geçiyor (05.5).
///   EŞİK AÇICI — yeterince düğüm alındığında bir izin: bir droid yuvası
///   daha, ikinci donatım profili. Sayı değil izin.
///
/// Yapmadığı: HAM GÜÇ vermek. Bir düğüm "+%5 hasar" verseydi 08'in bütçesi
/// yeniden bölünmek zorunda kalırdı — ArGe yedinci bir grup olurdu ve altı
/// grubun payı elle düşürülürdü. Ağaç bugün bilerek güç-nötr: ne verdiği
/// değil neyi nereye taşıdığı önemli. Ham güç istenirse 08.1'e bir pay
/// eklemek gerekir ve bu bu belgenin değil oranın kararı (borç defteri B32).
///
/// Puan SEVİYEDEN: her seviye bir puan (10.1). Ayrı bir para birimi ya da
/// ayrı bir sayaç ikinci bir ilerleme kanalı açardı; seviye zaten var ve
/// zaten oynayarak kazanılıyor.
///
/// Sıfırlama BEDAVA ve sınırsız: pahalı sıfırlama yanlış yatırımı kalıcı ölü
/// stata çevirir ve oyuncuyu ağaca dokunmamaya iter.
/// KARAR 05.7 s2
abstract final class ArGe {
  /// Ağacın düğümleri — üç dal, dal başına dört düğüm zinciri.
  ///
  /// Zincir ŞART: her düğüm bir öncekini istiyor, yani oyuncu bir dala
  /// yatırım yapmayı seçiyor. Serbest seçim olsaydı herkes üç dalın en
  /// ucuzlarını alır ve ağaç bir alışveriş listesine dönerdi.
  static const List<ArGeDugumu> hepsi = [
    // ── Filo dalı: σ yukarı ──
    ArGeDugumu(
      id: 'filo-1',
      ad: 'Bağlaşım I',
      dal: ArGeDali.filo,
      maliyet: 1,
      aktarimDeltasi: TasarimGirdileri.argeAktarimAdimi,
    ),
    ArGeDugumu(
      id: 'filo-2',
      ad: 'Bağlaşım II',
      dal: ArGeDali.filo,
      maliyet: 2,
      onkosul: 'filo-1',
      aktarimDeltasi: TasarimGirdileri.argeAktarimAdimi,
    ),
    ArGeDugumu(
      id: 'filo-3',
      ad: 'Bağlaşım III',
      dal: ArGeDali.filo,
      maliyet: 3,
      onkosul: 'filo-2',
      aktarimDeltasi: TasarimGirdileri.argeAktarimAdimi,
    ),
    ArGeDugumu(
      id: 'filo-yuva',
      ad: 'Ek Yuva',
      dal: ArGeDali.filo,
      maliyet: 5,
      onkosul: 'filo-3',
      izin: ArGeIzni.filoYuvasi,
    ),

    // ── Gemi dalı: σ aşağı ──
    ArGeDugumu(
      id: 'gemi-1',
      ad: 'Yalıtım I',
      dal: ArGeDali.gemi,
      maliyet: 1,
      aktarimDeltasi: -TasarimGirdileri.argeAktarimAdimi,
    ),
    ArGeDugumu(
      id: 'gemi-2',
      ad: 'Yalıtım II',
      dal: ArGeDali.gemi,
      maliyet: 2,
      onkosul: 'gemi-1',
      aktarimDeltasi: -TasarimGirdileri.argeAktarimAdimi,
    ),
    ArGeDugumu(
      id: 'gemi-3',
      ad: 'Yalıtım III',
      dal: ArGeDali.gemi,
      maliyet: 3,
      onkosul: 'gemi-2',
      aktarimDeltasi: -TasarimGirdileri.argeAktarimAdimi,
    ),
    ArGeDugumu(
      id: 'gemi-profil',
      ad: 'İkinci Profil',
      dal: ArGeDali.gemi,
      maliyet: 5,
      onkosul: 'gemi-3',
      izin: ArGeIzni.ikinciProfil,
    ),
  ];

  static final Map<String, ArGeDugumu> byId = {
    for (final d in hepsi) d.id: d,
  };

  /// [seviye]'deki oyuncunun toplam ArGe puanı — seviye başına bir.
  /// KARAR 05.7 s2
  static int puanFor(int seviye) => seviye.clamp(0, Seviye.tavan);

  /// [alinanlar]'ın harcadığı puan.
  static int harcanan(Set<String> alinanlar) {
    var toplam = 0;
    for (final id in alinanlar) {
      toplam += byId[id]?.maliyet ?? 0;
    }
    return toplam;
  }

  /// [alinanlar] ile σ'ya eklenen toplam — artı filoya, eksi gemiye.
  ///
  /// Toplam kelepçeli DEĞİL burada: kelepçe σ'nun kendisinde (05.5), çünkü
  /// formasyon takası da aynı sayıya biniyor ve iki kelepçe iki ayrı yerde
  /// birbirini gizlerdi.
  /// KARAR 05.7 s2
  static double aktarimDeltasi(Set<String> alinanlar) {
    var toplam = 0.0;
    for (final id in alinanlar) {
      toplam += byId[id]?.aktarimDeltasi ?? 0;
    }
    return toplam;
  }

  /// [izin] açık mı.
  /// KARAR 05.7 s2
  static bool izinAcik(Set<String> alinanlar, ArGeIzni izin) =>
      alinanlar.any((id) => byId[id]?.izin == izin);

  /// [alinanlar]'ın açtığı FİLO TAVANI — ilan edilen tavan artı izin.
  ///
  /// Burada, `Hangar`'ın içinde değil, çünkü tavanı SORAN iki taraf var:
  /// sunucunun hangarı ve istemcinin okunur görünümü. İki yerde ayrı
  /// yazıldığında ekran on droid der, sunucu on biri kabul eder — ve
  /// ArGe'nin tek görünür ödülü, oyuncunun ulaşamadığı bir yuva olur.
  /// KARAR 05.7 s2 · KARAR 04.10 s3
  static int filoTavani(Set<String> alinanlar) =>
      TasarimGirdileri.droidFiloTavani +
      (izinAcik(alinanlar, ArGeIzni.filoYuvasi) ? 1 : 0);

  /// Bu düğüm [alinanlar]'a EKLENEBİLİR mi: bilinen, alınmamış, önkoşulu
  /// tamam ve puanı yetiyor.
  /// KARAR 05.7 s2
  static bool alinabilir(Set<String> alinanlar, String id, int seviye) {
    final dugum = byId[id];
    if (dugum == null || alinanlar.contains(id)) return false;
    if (dugum.onkosul != null && !alinanlar.contains(dugum.onkosul)) {
      return false;
    }
    return harcanan(alinanlar) + dugum.maliyet <= puanFor(seviye);
  }
}
