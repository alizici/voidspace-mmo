import 'dart:convert';
import 'dart:io';

import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/veri_yolu.dart';

/// Hangar deposu — oyuncunun oturumlar arası ilerlemesi.
///
/// Biçim ve gerekçe [AccountStore] ile aynı: satır başına bir kayıt, son satır
/// kazanır. Hesaplarda EKLEME baskındı; burada GÜNCELLEME baskın — her satın
/// alma, her yükseltme bir yazma. Satır ekleme bunu da O(1) yapıyor: bütün
/// hangarları yeniden kodlamak, oyuncu sayısıyla büyüyen bir maliyeti her
/// işleme bağlamak olurdu.
///
/// **Şişme ve SIKIŞTIRMA.** Satır ekleme yazmayı O(1) yapıyor ama dosyayı
/// zamanla büyütüyor. Bu takas bir kez kabul edilmişti — o zaman yazmalar
/// oyuncu EYLEMİYLE oluyordu (satın alma, yükseltme: seyrek). Ödül sistemi
/// bunu temelden değiştirdi: aktif oyuncu artık her imhada kirleniyor, yani
/// beş saniyede bir tam hangar satırı ekleniyor.
///
/// Ölçüldü: 107 satırlık dosyada 4 hesap — %96 ölü satır. 60 oyuncuda saatte
/// ~15 MB, bir ayda ~4 GB ve açılış 25 saniye. Oyuncu sayısıyla değil
/// ZAMANLA büyüyen bir maliyet.
///
/// Çözüm Redis'in AOF yeniden yazımı ve Kafka'nın log compaction'ıyla aynı:
///
///  * **Anahtar başına son değer.** Yaşayan kayıtlar zaten bellekte; sıkıştırma
///    onları tek seferde yazmaktan ibaret.
///  * **Oran tetikli.** Zamanla ya da her yazımda değil, ölü satır oranı
///    eşiği aşınca. Redis'in `auto-aof-rewrite-percentage` + `min-size`
///    ikilisinin aynısı: küçük dosyayı sıkıştırmanın anlamı yok.
///  * **Atomik değiştirme.** Geçici dosyaya yaz, sonra `rename`. Yerinde
///    kısaltmak, çökme hâlinde yarım bir dosya ve kaybolmuş bir ilerleme
///    demekti; `rename` POSIX'te atomik — ya eski dosya bütün hâlde kalır ya
///    yeni.
class HangarStore {
  /// Yol VERİLMEZSE [VeriYolu] karar veriyor: `HANGARS` çevre değişkeni,
  /// yoksa üretimde `data/hangars.jsonl` ve testte geçici bir dosya.
  /// Sabit bir varsayılan, testlerin oyuncunun gerçek ilerlemesini
  /// kirletmesi demekti — gerekçesi orada.
  HangarStore({String? path})
    : path = VeriYolu.belirle(
        path,
        uretim: VeriYolu.hangarlar,
        cevre: 'HANGARS',
      );

  final String path;

  final Map<String, Hangar> _byAccount = {};

  int get count => _byAccount.length;

  /// Dosyadaki TOPLAM satır sayısı — yaşayan kayıt sayısıyla farkı ölü satır.
  int _lines = 0;

  /// Sıkıştırmanın altında hiç denenmediği satır sayısı.
  ///
  /// Redis'in `auto-aof-rewrite-min-size`'ı: küçük bir dosyayı sıkıştırmak
  /// kazanç değil, sırf I/O. Yüz satır birkaç yüz kilobayt eder.
  static const int compactMinLines = 200;

  /// Ölü satırlar yaşayanların bu katını aşınca sıkıştır.
  ///
  /// Redis'in `auto-aof-rewrite-percentage 100`'ü: dosya, son sıkıştırmadan
  /// beri iki katına çıktığında yenile. Daha agresif bir eşik, sürekli
  /// yeniden yazma; daha gevşeği, uzun süre şişkin dosya.
  static const int compactGrowthFactor = 2;

  /// Sıkıştırmanın GEREKİP gerekmediği.
  bool get needsCompaction =>
      _lines >= compactMinLines &&
      _lines > _byAccount.length * compactGrowthFactor;

  /// Bu oturumda kaç kez sıkıştırıldı — teşhis ve test için.
  int compactions = 0;

  /// Son yüklemede ELENEN satır sayısı.
  int corruptLines = 0;

  /// Elenen satırların vurduğu hesaplar.
  final Set<String> corruptAccounts = {};

  /// Yırtık bir satırın içinde sahibini arayan kalıp.
  ///
  /// Yalnız BAŞ parçasında işe yarıyor: `accountId` kaydın ilk alanı, yani
  /// başı ezilmiş bir satırda o alan da gitmiş oluyor. Yine de denemeye
  /// değer, çünkü bulduğunda cevap TAHMİN değil kesin.
  static final RegExp _accountIdPattern = RegExp('"accountId":"([^"]+)"');

  Future<void> load() async {
    final file = File(path);
    if (!file.existsSync()) return;
    corruptLines = 0;
    corruptAccounts.clear();
    // Yırtığın sahibini komşusundan okuyoruz. Gerekçe hasarın şekli: bir
    // kaydın üstüne yazan ikinci kayıt onu ortasından kesiyor ve artakalan
    // kuyruk, kendisini ezen satırın HEMEN ARDINDA duruyor. Yani yırtığın
    // sahibi, neredeyse her zaman bir önceki geçerli satırın sahibi.
    // Tahmin olduğu için `_accountIdPattern` önce deneniyor; o kesin.
    String? oncekiHesap;
    // Dosyanın BAŞINDAKİ yırtığın öncesinde komşu yok — sahibini ancak
    // sonraki geçerli satır söyleyebilir.
    var sahipsizYirtik = 0;
    for (final line in const LineSplitter().convert(
      await file.readAsString(),
    )) {
      if (line.trim().isEmpty) continue;
      try {
        final hangar = Hangar.fromJson(
          jsonDecode(line) as Map<String, Object?>,
        );
        _byAccount[hangar.accountId] = hangar;
        _lines++;
        oncekiHesap = hangar.accountId;
        if (sahipsizYirtik > 0) {
          corruptAccounts.add(hangar.accountId);
          sahipsizYirtik = 0;
        }
      } on FormatException {
        _lines++;
        // Süreç yazarken ölürse yarım bir satır kalabilir. Onun yüzünden
        // bütün ilerlemeyi kaybetmek, korumaya çalıştığımız şeyi kaybetmek.
        corruptLines++;
        final sahip = _accountIdPattern.firstMatch(line)?.group(1) ??
            oncekiHesap;
        if (sahip == null) {
          sahipsizYirtik++;
        } else {
          corruptAccounts.add(sahip);
        }
      }
    }
    // Elenen satır SESSİZ kalmamalı. Eskiden her yırtık için tek bir
    // `hangar satırı atlandı (bozuk)` satırı basılıyordu: açılış
    // gürültüsünün içinde kaybolan, sayısı okunmayan, kimi vurduğu
    // söylenmeyen bir satır. Oysa bildirilen şey bir oyuncunun EN SON
    // ilerlemesinin yok olması — açılışta görülmesi gereken tek şey buysa
    // o kadar görünür olmalı.
    if (corruptLines > 0) _reportCorruption();
    // AÇILIŞTA sıkıştır. Sunucu zaten bekliyor, oyuncu yok ve dosya en
    // şişkin hâlinde: sıkıştırmanın en ucuz olduğu an burası.
    //
    // Yırtık bulunduysa EŞİĞE BAKMADAN sıkıştır. Sıkıştırma yaşayan kaydı
    // tek seferde yazıyor, yani yırtıkları dosyadan söküp atmanın kendisi
    // bu — onarım için ayrı bir yol yazmaya gerek yok. Eşiğe bırakılsaydı
    // küçük ama yırtık bir dosya (bugünkü `data/hangars.jsonl` gibi: 160
    // satır, eşik 200) sonsuza kadar yırtık kalır ve her açılışta aynı
    // uyarıyı basardı. Redis'in `aof-load-truncated` davranışıyla aynı:
    // bozuk kuyruğu kes, devam et, dosyayı temiz bırak.
    if (corruptLines > 0 || needsCompaction) await compact();
  }

  /// Elenen satırları AÇIKÇA bildirir.
  void _reportCorruption() {
    final hesaplar = corruptAccounts.isEmpty
        ? 'saptanamadı'
        : corruptAccounts.join(', ');
    stderr.writeln('');
    stderr.writeln('══ ⚠ HANGAR GÜNLÜĞÜ YIRTIK ═══════════════════════════');
    stderr.writeln('  $path');
    stderr.writeln('  $corruptLines satır çözülemedi ve ELENDİ.');
    stderr.writeln('  Etkilenen hesap: ${corruptAccounts.length} → $hesaplar');
    stderr.writeln('  Bu hesaplar EN SON kaydını kaybetti; bir önceki kayda');
    stderr.writeln('  dönüldü. Dosya bu açılışta yeniden yazılıp onarıldı.');
    stderr.writeln('══════════════════════════════════════════════════════');
    stderr.writeln('');
  }

  /// [accountId]'nin hangarı. Yoksa BAŞLANGIÇ hangarı kurulur.
  ///
  /// Kurulan hangar hemen diske yazılmıyor: yazma gerçekten bir şey
  /// değiştiğinde oluyor, yoksa her giriş bir disk yazması ederdi.
  Hangar of(String accountId) => _byAccount[accountId] ??= Hangar.fresh(
    accountId,
    // Açılış bakiyesi de deftere düşüyor. Kimlik hesaba özgü ve tek
    // seferlik: aynı hesap ikinci kez "yeni" olamaz, yani tekrarlanan
    // kimlik burada bir hatanın işareti olur.
    TxContext(
      id: 'signup-$accountId',
      atMillis: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  /// Hesap kimliği → EN SON yazılan satır.
  ///
  /// Aynı içeriği ikinci kez yazmayı engelliyor. Kazanç ödül yolunda değil
  /// (bakiye gerçekten değişiyor), kirli işaretlenip aslında değişmemiş
  /// hangarlarda — ve o durum, ödül payı sıfıra yuvarlandığında gerçekten
  /// oluyor.
  final Map<String, String> _lastWritten = {};

  /// Sıradaki yazımın bekleyeceği son yazım.
  ///
  /// **Yazımlar SIRAYA giriyor.** `File.writeAsString(mode: append)` her
  /// çağrıda dosyayı kendi açıyor, açılışta sonu buluyor ve oraya yazıyor.
  /// İki çağrı aynı anda açarsa ikisi de AYNI sonu buluyor ve aynı yerin
  /// üstüne yazıyor: uzun olan kısa olanın altından taşıyor, taşan parça
  /// yeni bir satır gibi görünüyor; kısa olan uzun olanı tamamen örterse
  /// geriye yırtık bile kalmıyor, kayıt sessizce yok oluyor. `FileMode.append`
  /// bir "ekleme" sözü DEĞİL, sadece bir açılış konumu.
  ///
  /// Bu varsayım değil, ölçüm: gerçek `data/hangars.jsonl` 160 satırın
  /// 27'si çözülemez hâlde bulundu ve hepsi bir kaydın kuyruk parçasıydı.
  ///
  /// **Neden kuyruk, neden tek atomik yazım değil.** Bütün dosyayı her
  /// yazımda yeniden yazmak (yaz-ve-`rename`) atomik olurdu ama satır
  /// eklemenin O(1) olmasını bozardı — bu deponun bütün gerekçesi o. Kuyruk,
  /// eklemeyi olduğu gibi bırakıp yalnız ÇAKIŞMAYI kaldırıyor.
  ///
  /// **Sıcak yolda değil.** Sunucu 30 Hz tik atıyor ama hangar yazımı tikten
  /// gelmiyor: toplu yazım beş saniyelik zamanlayıcıda, tekil yazım oturum
  /// kopuşunda ve hangar mesajında. Zaten `_flushDirtyHangars` kirli
  /// hangarları `await`'li bir döngüde tek tek yazıyordu; kuyruk o sırayı
  /// bozmuyor, üstüne binen ikinci bir yazıcıyı sıraya sokuyor.
  Future<void> _writeQueue = Future<void>.value();

  /// [work]'ü sıradaki tek yazım olarak koşturur.
  ///
  /// Zincir bir HATAYLA KOPMAMALI: diski dolu bir sunucuda bir yazım
  /// patlarsa arkasındaki bütün yazımlar da patlardı ve depo kalıcı olarak
  /// sağır olurdu. Zincirin kendi kopyası hatayı yutuyor, çağırana dönen
  /// gelecek hatayı olduğu gibi taşıyor — `gateway._saveHangar` onu zaten
  /// yakalıyor ve sunucuyu düşürmüyor.
  Future<void> _serialized(Future<void> Function() work) {
    final next = _writeQueue.then((_) => work());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  /// Değişen hangarı diske yaz.
  Future<void> save(Hangar hangar) {
    _byAccount[hangar.accountId] = hangar;
    final encoded = jsonEncode(hangar.toJson());
    // Kuyruğa girmeden önce bir kez bakılıyor: değişmemiş hangar sık ve
    // onun için sıra beklemek gereksiz. Kesin karar kuyruğun İÇİNDE
    // veriliyor, çünkü aynı hangarı aynı anda iki kez yazan iki çağrı
    // burada da aynı cevabı alır ve ikisi birden geçerdi.
    if (_lastWritten[hangar.accountId] == encoded) return Future<void>.value();
    return _serialized(() => _append(hangar.accountId, encoded));
  }

  Future<void> _append(String accountId, String encoded) async {
    if (_lastWritten[accountId] == encoded) return;
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('$encoded\n', mode: FileMode.append, flush: true);
    _lastWritten[accountId] = encoded;
    _lines++;

    // Sıkıştırma da bu sıranın İÇİNDE. Dışarıda kalsaydı `rename`, uçuşta
    // olan bir eklemenin altından dosyayı çekerdi: ekleme artık yerinden
    // kaldırılmış eski dosyaya yazılır ve kimsenin okumadığı bir düğümde
    // kaybolurdu. Bu yüzden dış yüzey `compact()` değil `_compactNow()`
    // çağrılıyor — `compact()` kuyruğa girer, biz zaten kuyruktayız ve
    // kendini bekleyen bir yazım kilitlenirdi.
    if (needsCompaction) await _compactNow();
  }

  /// Dosyayı YAŞAYAN kayıtlarla yeniden yazar.
  ///
  /// Yaşayan hâl zaten bellekte (`_byAccount`), yani sıkıştırma dosyayı
  /// okumayı bile gerektirmiyor — Kafka'nın "anahtar başına son değer"
  /// kuralının en ucuz hâli.
  ///
  /// **Atomik.** Geçici dosyaya yazılıp `rename` ile yerine konuyor. Yerinde
  /// kısaltmak, tam o anda çöken bir süreçte bütün ilerlemenin kaybolması
  /// demekti. `rename` POSIX'te atomik: ya eski dosya bütün hâlde durur ya
  /// yeni.
  ///
  /// Eklemelerle AYNI sırada koşuyor: `rename` uçuşta olan bir eklemenin
  /// altından dosyayı çekerse o ekleme sessizce kaybolur.
  Future<void> compact() => _serialized(_compactNow);

  /// [compact]'in sıraya girmeyen gövdesi — sıradayken çağrılan hâli.
  Future<void> _compactNow() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final temp = File('$path.tmp');
    final buffer = StringBuffer();
    for (final hangar in _byAccount.values) {
      buffer.writeln(jsonEncode(hangar.toJson()));
    }
    await temp.writeAsString(buffer.toString(), flush: true);
    await temp.rename(path);
    _lines = _byAccount.length;
    _lastWritten.clear();
    compactions++;
  }
}
