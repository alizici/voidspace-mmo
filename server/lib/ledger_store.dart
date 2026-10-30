import 'dart:convert';
import 'dart:io';

import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/veri_yolu.dart';

/// Para hareketlerinin KALICI defteri.
///
/// **Neden ayrı bir dosya, hangarın içinde değil.** Hangar bir DURUM: "şu an
/// ne var". Defter bir GEÇMİŞ: "nasıl oldu". İkisini birleştirmek, durumu her
/// yazdığında geçmişi de yeniden yazmak demek — ve geçmişin yeniden
/// yazılabilir olması, onu kanıt olmaktan çıkarır.
///
/// **Yalnız EKLENİR.** Hiçbir kayıt güncellenmiyor ya da siliniyor. Bir hata
/// düzeltilecekse üstüne TERS kayıt yazılıyor ([LedgerReason.clawback]) —
/// muhasebenin yüzyıllardır yaptığı şey ve sebebi aynı: silinebilen bir defter
/// hiçbir soruyu cevaplayamaz.
///
/// **Tampon.** Tik yolunda dosya yazması yok; kayıtlar bellekte birikip
/// [flush] ile toplu yazılıyor. `hangars.jsonl` ile aynı desen ve aynı bedel:
/// çökme hâlinde son birkaç saniye kaybolur. Para açısından kabul edilebilir
/// olan yön bu — kaybolan kayıt fark edilir, uydurulan kayıt edilmez.
class LedgerStore {
  /// Yol VERİLMEZSE [VeriYolu] karar veriyor: `LEDGER` çevre değişkeni,
  /// yoksa üretimde `data/ledger.jsonl` ve testte geçici bir dosya.
  ///
  /// `LEDGER` diye bir değişken daha önce HİÇ yoktu: `bin/server.dart`
  /// defteri kurmuyor bile, `Gateway` kendi varsayılanıyla kuruyor. Yani
  /// deftere giden yolu dışarıdan söylemenin bir yolu yoktu ve `Gateway`
  /// kuran her test, oyuncunun gerçek para kaydının üstüne yazıyordu.
  LedgerStore({String? path})
    : path = VeriYolu.belirle(
        path,
        uretim: VeriYolu.defter,
        cevre: 'LEDGER',
      );

  final String path;

  final List<LedgerEntry> _pending = [];

  /// Bu oturumda görülen işlem kimlikleri.
  ///
  /// Tekrarlanan bir kimlik, aynı hareketin iki kez işlendiği anlamına gelir —
  /// çoğaltma açıklarının imzası. Sessizce ikinci kez yazmak, defteri gerçeğin
  /// değil hatanın kaydı yapardı.
  final Set<String> _seen = {};

  /// Yazılamamış kayıt sayısı.
  int get pending => _pending.length;

  /// Bu oturumda reddedilen (tekrarlanan kimlikli) kayıt sayısı.
  ///
  /// Sıfırdan farklı olması bir HATA sinyali: ya kimlik üretimi çakışıyor ya
  /// da bir yol iki kez koşuyor. İkisi de sessiz kalmamalı.
  int duplicates = 0;

  /// Kayıtları kuyruğa alır. Tekrarlanan kimlik REDDEDİLİR.
  void add(Iterable<LedgerEntry> entries) {
    for (final entry in entries) {
      if (!_seen.add(entry.id)) {
        duplicates++;
        continue;
      }
      _pending.add(entry);
    }
  }

  /// Sıradaki yazımın bekleyeceği son yazım.
  ///
  /// **Yazımlar SIRAYA giriyor** — `hangars.dart` ile birebir aynı gerekçe ve
  /// birebir aynı desen. `File.writeAsString(mode: append)` her çağrıda
  /// dosyayı kendi açıyor, açılışta sonu buluyor ve oraya yazıyor; iki çağrı
  /// aynı anda açarsa İKİSİ DE aynı sonu buluyor ve aynı yerin üstüne
  /// yazıyor. `FileMode.append` bir "ekleme" sözü değil, sadece bir açılış
  /// konumu.
  ///
  /// Çağrı sahiden eşzamanlı: `gateway.dart` defteri iki yerden `unawaited`
  /// yazıyor — beş saniyelik toplu tur ve oturum kopuşu (`_drop`). Toplu tur
  /// yazarken kopan bir oturum tam olarak bu yarışı kuruyor.
  ///
  /// **Neden hangar yırtıldı da defter yırtılmadı.** Bugünkü
  /// `data/ledger.jsonl` temiz (1883 satır, 0 bozuk) ve bu şans: [flush] bir
  /// turun bütün kayıtlarını TEK yazımda topluyor, hangar ise kayıt başına
  /// bir yazım yapıyordu — yani defterde çarpışacak yazım sayısı çok daha az.
  /// Ama "az" sıfır değil ve burada duran şey PARA KAYDI: kaybolan bir defter
  /// satırı, bir hesabın bakiyesinin nereden geldiğini açıklayamaz hâle
  /// getirir. Yapısal olarak aynı yarış olduğu için düzeltmesi de aynı olmalı;
  /// "bugüne kadar olmadı" bir güvence değil.
  ///
  /// Zincir bir HATAYLA KOPMAMALI: diski dolu bir sunucuda patlayan tek bir
  /// yazım, arkasındaki bütün yazımları kalıcı olarak sağır bırakırdı.
  Future<void> _writeQueue = Future<void>.value();

  /// [work]'ü sıradaki tek yazım olarak koşturur.
  Future<void> _serialized(Future<void> Function() work) {
    final next = _writeQueue.then((_) => work());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  /// Kuyruğu diske yazar.
  ///
  /// Yazamazsa kayıtlar kuyruğa GERİ konuyor: diskin dolması bir para
  /// kaydını kaybettirmemeli. Sunucuyu da düşürmemeli — çağıran hatayı
  /// yakalıyor.
  ///
  /// Kuyruk BOŞSA sıraya girmek yerine uçuştaki yazım döndürülüyor. `return`
  /// demek daha kısa olurdu ama yanlış olurdu: yazacak kaydı olmayan bir
  /// çağıran "defter diskte" sanır, oysa önündeki yazım hâlâ uçuşta olabilir.
  /// Uçuşta bir şey yoksa `_writeQueue` zaten tamamlanmış bir gelecek, yani
  /// bu dal da beklemiyor.
  Future<void> flush() {
    if (_pending.isEmpty) return _writeQueue;
    return _serialized(_flushNow);
  }

  /// [flush]'ın sıraya girmeyen gövdesi.
  ///
  /// Kuyruğun ALINMASI da sıranın içinde, dışında değil. Dışarıda kalsaydı
  /// iki eşzamanlı çağrı iki ayrı yığın kapar, biri yazarken öteki beklerdi;
  /// birincisi PATLADIĞINDA yığınını kuyruğun başına geri koyardı ve o
  /// kayıtlar, ikinci yığın çoktan yazıldıktan SONRA diske düşerdi — deftere
  /// zaman sırası bozuk giren bir geçmiş. İçeride alınınca her an tek bir
  /// al-yaz döngüsü uçuşta oluyor ve geri konan yığın, bir sonraki turun
  /// başında yerini koruyor.
  Future<void> _flushNow() async {
    if (_pending.isEmpty) return;
    final batch = List<LedgerEntry>.of(_pending);
    _pending.clear();
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${batch.map((e) => jsonEncode(e.toJson())).join('\n')}\n',
        mode: FileMode.append,
        flush: true,
      );
    } on Object {
      _pending.insertAll(0, batch);
      rethrow;
    }
  }

  /// Defteri baştan okur — denetim ve teşhis için.
  ///
  /// Sıcak yol DEĞİL: sunucu çalışırken defteri okumuyor. Bu, "bu hesaba ne
  /// oldu" sorusunu cevaplamak için var.
  Future<List<LedgerEntry>> readAll({String? accountId}) async {
    final file = File(path);
    if (!file.existsSync()) return const [];
    final out = <LedgerEntry>[];
    for (final line in await file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final entry = LedgerEntry.fromJson(
          jsonDecode(line) as Map<String, Object?>,
        );
        if (accountId != null && entry.accountId != accountId) continue;
        out.add(entry);
      } on Object {
        // Bozuk satır defteri okunamaz yapmamalı: geri kalan kayıtlar hâlâ
        // kanıt. Sessizce atlanıyor ama sayılıyor.
        corrupt++;
      }
    }
    return out;
  }

  /// Okunamayan satır sayısı.
  int corrupt = 0;
}
