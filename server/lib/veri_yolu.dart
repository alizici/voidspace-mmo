import 'dart:io';
import 'dart:isolate';

/// Kalıcı depoların DOSYA YOLU — ve testin üretim verisine yazmasını
/// imkânsız kılan koruma.
///
/// **Neden ayrı bir yer.** Üç deponun da varsayılan yolu kendi kurucusunda
/// sabit duruyordu (`data/hangars.jsonl`, `data/ledger.jsonl`,
/// `data/accounts.json`) ve çevre değişkenlerini yalnız `bin/server.dart`
/// okuyordu. Yani "yolu nereden geliyor" sorusunun cevabı GİRİŞ NOKTASINA
/// göre değişiyordu: sunucudan geçen yol çevreye uyuyor, `Gateway`'in kendi
/// varsayılanından geçen yol uymuyordu. `Gateway({hangars, ledger})` ikisini
/// de isteğe bağlı tutuyor ve vermeyene sessizce üretim yolunu veriyordu.
///
/// Bedeli ölçüldü: `server/test/` altındaki on altı test dosyası `Gateway`
/// kuruyor, `accounts:` için geçici bir yol veriyor ama `hangars:`/`ledger:`
/// vermiyor — hepsi üretim dosyasına yazıyordu. `server/data/` altında 4,9
/// MB hangar ve 49 MB defter birikmişti; kullanıcının GERÇEK
/// `data/hangars.jsonl` dosyasında ise `data/accounts.json` içinde karşılığı
/// olmayan DÖRT hangar bulundu — hesabı başka (geçici) bir dosyada olan, yani
/// bir testin yazdığı kayıtlar.
///
/// **Neden çevreyi okumak TEK BAŞINA yetmiyor.** Belgelenen ve herkesin var
/// sandığı `HANGARS=… dart test` gerçekten çalışsın diye çevre okunuyor, ama
/// bu kazayı önlemiyor: düz `dart test` yine üretim yoluna yazardı. Kusur
/// zaten "geçersiz kılma yanlış" değil "geçersiz kılmayı unutmak SESSİZ"
/// idi. Unutulabilen bir korumanın adı koruma değil, âdet.
///
/// **Bu yüzden ikinci ve asıl kilit: test altında varsayılan yol üretim
/// dosyası OLAMAZ.** Koşucu saptandığında varsayılan, süreç başına bir
/// geçici dizine düşüyor; açıkça üretim yolu istenirse [StateError]
/// atılıyor.
///
/// **Neden varsayılanda atmak yerine yönlendirme.** En güçlü hâli her iki
/// durumda da atmaktı ("test üretim yoluna yazamaz, nokta"). Reddedildi:
/// bugün on altı test dosyası yolu vermiyor, yani varsayılanda atmak on altı
/// dosyayı aynı anda kırar ve hepsinin tek tek düzenlenmesini şart koşardı.
/// Yönlendirme aynı güvenceyi veriyor — üretim dosyasına tek bayt gitmiyor —
/// ama testleri kırmak yerine DOĞRU yapıyor: her dosya kendi geçici verisiyle
/// koşuyor. Atma yalnız yolun AÇIKÇA üretim dosyasını gösterdiği yerde
/// kalıyor; orada sessiz kalmak, insanın yazdığı bir niyeti sessizce
/// değiştirmek olurdu.
///
/// **Geçici dizin süreç başına, çağrı başına değil.** Aynı süreçte varsayılan
/// yolla kurulan iki depo AYNI dosyayı görmeli: bir test yazıp sonra yeni bir
/// depoyla geri okuduğunda (`hangar_yazim_yarisi_test.dart`'ın yaptığı) yol
/// değişseydi test kendi yazdığını bulamazdı. Dizin siliniyor da değil:
/// süreç sonunda güvenilir bir kanca yok ve işletim sistemi `systemTemp`'i
/// zaten süpürüyor — depoyu 49 MB şişirmektense birkaç megabaytı /tmp'de
/// bırakmak.
abstract final class VeriYolu {
  /// ÜRETİM yolları. Bunlar birer varsayılan, birer zorunluluk değil —
  /// çevre değişkeni ya da açık argüman ikisini de geçersiz kılıyor.
  static const String hangarlar = 'data/hangars.jsonl';
  static const String defter = 'data/ledger.jsonl';
  static const String hesaplar = 'data/accounts.json';

  /// Bir deponun kullanacağı yolu belirler.
  ///
  /// Öncelik sırası, en açık niyetten en örtüğüne:
  ///  1. [verilen] — kurucuya elle geçilen yol. İnsan ne istediğini söylemiş.
  ///  2. `Platform.environment[cevre]` — işleten kişi ne istediğini söylemiş.
  ///  3. Varsayılan: testte geçici dizin, üretimde [uretim].
  ///
  /// Çevrenin testten ÖNCE gelmesi kasıtlı: `HANGARS=/tmp/x dart test` bir
  /// kaza değil bir talimat, ve talimatın üstüne yazan bir koruma
  /// öngörülemez olur. Yine de çevre üretim DOSYASINI gösteriyorsa test
  /// altında atılıyor — üçüncü kural (2) için değil, aşağıdaki ortak kilit
  /// için geçerli.
  static String belirle(
    String? verilen, {
    required String uretim,
    required String cevre,
  }) {
    final istenen = verilen ?? Platform.environment[cevre];
    if (istenen == null) {
      if (!testKosuyor) return uretim;
      // Dosya ADI korunuyor: geçici dizindeki dosyanın da `hangars.jsonl`
      // olması, teşhis için dizine bakan insanın hangi deponun ne olduğunu
      // görmesini sağlıyor.
      return '$_gecici/${uretim.split('/').last}';
    }
    if (testKosuyor && _ayniDosya(istenen, uretim)) {
      throw StateError(
        'test ÜRETİM verisine yazamaz: $istenen\n'
        'Bu dosya oyuncunun gerçek ilerlemesi ve para kaydı. Testte yol ya '
        'verilmez (geçici dizine düşer) ya da geçici bir dosya gösterir.',
      );
    }
    return istenen;
  }

  /// `package:test` koşucusunun altında mıyız.
  ///
  /// İki imza birden aranıyor, çünkü ikisi de koşucunun İÇ ayrıntısı ve
  /// birinin bir gün değişmesi korumayı sessizce kaldırmamalı:
  ///
  ///  * `package:test` her test dosyasını kendi izolatında koşturuyor ve o
  ///    izolatı `test_suite:` önekiyle adlandırıyor.
  ///  * Koşucu, süreci `systemTemp` altındaki `dart_test.kernel.*` dizininde
  ///    ürettiği bir `.dill` ile başlatıyor.
  ///
  /// YANLIŞ POZİTİF pratikte imkânsız: üretimde `Platform.script` ya
  /// `bin/server.dart` ya da AOT çıktısı, izolat adı da `main`. Yanlış
  /// NEGATİF ise bugünkü davranışa düşüyor — yani koruma en kötü ihtimalle
  /// hiç yokmuş gibi olur, hiçbir şeyi bozmaz.
  static final bool testKosuyor = _kosucuSaptandi();

  static bool _kosucuSaptandi() {
    final ad = Isolate.current.debugName;
    if (ad != null && ad.startsWith('test_suite:')) return true;
    final betik = Platform.script.path;
    return betik.contains('dart_test.kernel') || betik.endsWith('.dill');
  }

  static Directory? _dizin;

  static String get _gecici =>
      (_dizin ??= Directory.systemTemp.createTempSync('voidspace-test-veri-'))
          .path;

  /// İki yol AYNI dosyayı mı gösteriyor.
  ///
  /// Karşılaştırma mutlaklaştırılmış ve normalleştirilmiş yol üstünde:
  /// üretim yolu göreli (`data/…`) ve testler `server/` dizininden koşuyor,
  /// yani aynı metin farklı çalışma dizinlerinde farklı dosya demek — ve
  /// tam da bu yüzden sızıntının bir kısmı `server/data/`, bir kısmı kök
  /// `data/` altına düşmüştü.
  ///
  /// Sembolik bağlantı ÇÖZÜLMÜYOR: bu bir kaza freni, bir güvenlik sınırı
  /// değil. Kendi verisini bir bağlantının arkasına saklayıp teste yazdırmak
  /// isteyen birini durdurmak bu korumanın işi değil.
  static bool _ayniDosya(String a, String b) => _mutlak(a) == _mutlak(b);

  static String _mutlak(String yol) =>
      Uri.file(File(yol).absolute.path).normalizePath().toFilePath();
}
