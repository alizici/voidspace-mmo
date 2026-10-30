@Tags(['disi'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/hangars.dart';

/// Hangar günlüğüne EŞZAMANLI yazım.
///
/// Gerçek `data/hangars.jsonl` yırtılmış olarak bulundu: 160 satırın 27'si
/// çözülemiyordu ve hepsi bir kaydın KUYRUK parçasıydı — `":769},"seciliMermi"
/// :"MR-6"}` gibi, açılış süslü parantezi olmayan otuz baytlık artıklar.
///
/// Sebebi `File.writeAsString(mode: FileMode.append)` çağrısının eşzamanlı
/// olmaması: her çağrı dosyayı kendi açıyor, açılışta sonu buluyor ve oraya
/// yazıyor. İki çağrı aynı anda açarsa İKİSİ DE aynı sonu buluyor ve aynı
/// yerin üstüne yazıyor. Uzun olan kısa olanın altından taşıyor, taşan parça
/// ayrı bir satır gibi görünüyor. Kısa yazım uzun yazımı tamamen örterse
/// ortada yırtık bile kalmıyor — kayıt sessizce YOK oluyor.
///
/// Çağrı sahiden eşzamanlı: `gateway.dart` hangarı üç ayrı yerden yazıyor ve
/// ikisi `unawaited` — beş saniyelik toplu yazım (`_flushDirtyHangars`) ve
/// oturum kopuşu (`_drop`). Üçüncüsü hangar mesajının içinden geliyor. Toplu
/// yazım sürerken kopan bir oturum, tam olarak bu yarışı kuruyor.
///
/// Buradaki testlerin hepsi tek bir cümlenin yüzleri: **hiçbir yazım
/// sırası, daha önce yazılmış bir ilerlemeyi bozamaz.**
void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('voidspace_yarisi');
    path = '${dir.path}/hangars.jsonl';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Dosyadaki çözülemeyen satırlar.
  List<String> bozukSatirlar() => File(path)
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .where((l) {
        try {
          jsonDecode(l);
          return false;
        } on FormatException {
          return true;
        }
      })
      .toList();

  /// [n] hesabı AYNI ANDA yazar — `await` yok, tıpkı `unawaited(_saveHangar)`.
  ///
  /// Hesap kimlikleri bilerek farklı UZUNLUKTA: eşit uzunlukta satırlar
  /// birbirini tam örter ve kayıp sessiz olur, farklı uzunluktakiler yırtık
  /// bırakır. Test iki hasarı da görsün istiyoruz.
  Future<HangarStore> esZamanliYaz(int n) async {
    final store = HangarStore(path: path);
    final yazimlar = <Future<void>>[];
    for (var i = 0; i < n; i++) {
      final hangar = store.of('hesap${'x' * i}$i')
        ..earn(
          Currency.credit,
          i + 1,
          reason: LedgerReason.kill,
          txId: 'tx$i',
          atMillis: 0,
        );
      yazimlar.add(store.save(hangar));
    }
    await Future.wait(yazimlar);
    return store;
  }

  test('EŞZAMANLI yazımlar birbirini yırtmıyor', () async {
    final store = await esZamanliYaz(40);
    expect(
      bozukSatirlar(),
      isEmpty,
      reason: 'eşzamanlı yazımlar dosyada yırtık bıraktı',
    );
    expect(
      File(path).readAsLinesSync().where((l) => l.trim().isNotEmpty),
      hasLength(40),
      reason: 'kırk yazımdan kırk satır çıkmadı',
    );
    expect(store.count, 40);
  });

  test('EŞZAMANLI yazımların HİÇBİRİ kaybolmuyor', () async {
    // Yırtık görünür bir hasar; asıl sessiz hasar bu. Kısa bir yazım uzun
    // bir yazımın üstünü tamamen örterse geriye bozuk satır bile kalmıyor —
    // o oyuncunun kaydı hiç yazılmamış gibi oluyor ve sunucu bir sonraki
    // açılışta bir önceki kayda dönüyor.
    //
    // Ölçüt "bakiye sıfırdan büyük" DEĞİL: kaydı bulunamayan hesaba `of()`
    // yepyeni bir hangar kuruyor ve o hangarın açılış bakiyesi zaten
    // sıfırdan büyük. Kaybı görebilmek için bakiyenin TAM değeri sorulmalı.
    final store = await esZamanliYaz(40);
    final beklenen = {
      for (var i = 0; i < 40; i++)
        'hesap${'x' * i}$i': store.of('hesap${'x' * i}$i').credits,
    };

    final yeniden = HangarStore(path: path);
    await yeniden.load();
    for (final girdi in beklenen.entries) {
      expect(
        yeniden.of(girdi.key).credits,
        girdi.value,
        reason: '${girdi.key} eşzamanlı yazımda diskten silindi',
      );
    }
  });

  test('AYNI hesabın art arda yazımlarında SON yazım kazanıyor', () async {
    // Sıralama garantisi: `_flushDirtyHangars` bir hangarı yazarken oturum
    // koparsa `_drop` aynı hangarı ikinci kez yazıyor. İkinci yazım daha
    // yeni bakiyeyi taşıyor; dosyada o kalmalı, çünkü yükleme "son satır
    // kazanır" diyor.
    final store = HangarStore(path: path);
    final yazimlar = <Future<void>>[];
    for (var i = 1; i <= 10; i++) {
      final hangar = store.of('a')
        ..earn(
          Currency.credit,
          100,
          reason: LedgerReason.kill,
          txId: 'tx$i',
          atMillis: 0,
        );
      yazimlar.add(store.save(hangar));
    }
    await Future.wait(yazimlar);

    final yeniden = HangarStore(path: path);
    await yeniden.load();
    expect(
      yeniden.of('a').credits,
      store.of('a').credits,
      reason: 'son yazım diske düşmedi — oyuncunun ilerlemesi geri gitti',
    );
  });

  test('SIKIŞTIRMA eşzamanlı yazımın altından dosyayı çekmiyor', () async {
    // `compact()` geçici dosyaya yazıp `rename` ediyor. O sırada uçuşta olan
    // bir ekleme, artık yerinden kaldırılmış dosyaya yazılıyor ve `rename`
    // ile birlikte çöpe gidiyor. Eşiği aşacak kadar yaz, sonra eşzamanlı
    // yazımla sıkıştırmayı aynı ana getir.
    final store = HangarStore(path: path);
    for (var w = 0; w < HangarStore.compactMinLines + 20; w++) {
      final hangar = store.of('a')
        ..earn(
          Currency.credit,
          1,
          reason: LedgerReason.kill,
          txId: 'w$w',
          atMillis: 0,
        );
      await store.save(hangar);
    }
    expect(store.compactions, greaterThan(0), reason: 'hiç sıkıştırmadı');

    final yazimlar = <Future<void>>[];
    for (var i = 0; i < 10; i++) {
      final hangar = store.of('b${'x' * i}')
        ..earn(
          Currency.credit,
          i + 1,
          reason: LedgerReason.kill,
          txId: 'b$i',
          atMillis: 0,
        );
      yazimlar.add(store.save(hangar));
    }
    await Future.wait(yazimlar);

    expect(bozukSatirlar(), isEmpty, reason: 'sıkıştırma yarışı yırttı');
    final yeniden = HangarStore(path: path);
    await yeniden.load();
    for (var i = 0; i < 10; i++) {
      expect(
        yeniden.of('b${'x' * i}').credits,
        greaterThan(0),
        reason: 'b$i sıkıştırma yarışında kayboldu',
      );
    }
  });

  /// Gerçek dosyadaki hasarın birebir kopyası: geçerli bir satır, ardından
  /// onu ezen yazımdan artakalan KUYRUK parçaları.
  Future<void> yirtikDosyaKur() async {
    final saglam = jsonEncode(Hangar(accountId: 'a', credits: 500).toJson());
    final ikinci = jsonEncode(Hangar(accountId: 'b', credits: 7).toJson());
    await File(path).writeAsString(
      '$saglam\n'
      '":769},"seciliMermi":"MR-6"}\n'
      '-6":769},"seciliMermi":"MR-6"}\n'
      '00,"MR-6":769},"seciliMermi":"MR-6"}\n'
      '$ikinci\n',
    );
  }

  test('BOZUK satırlar sessizce elenmiyor — sayısı ve hesabı bildiriliyor', () async {
    await yirtikDosyaKur();
    final store = HangarStore(path: path);
    await store.load();

    expect(store.corruptLines, 3, reason: 'elenen satır sayılmadı');
    expect(
      store.corruptAccounts,
      contains('a'),
      reason: 'yırtığın hangi hesabı vurduğu bildirilmedi',
    );
    expect(store.of('a').credits, 500, reason: 'sağlam kayıt da yendi');
    expect(store.of('b').credits, 7);
  });

  test('SIKIŞTIRMA yırtıkları temizliyor — onarım yolu bu', () async {
    // Kullanıcının gerçek dosyasını onarma yolu. Yırtıklar yükleme sırasında
    // zaten eleniyor; `compact()` yaşayan kayıtları tek seferde yazınca
    // dosyada yırtıktan eser kalmıyor.
    await yirtikDosyaKur();
    final store = HangarStore(path: path);
    await store.load();
    await store.compact();

    expect(bozukSatirlar(), isEmpty, reason: 'sıkıştırma yırtığı temizlemedi');
    final yeniden = HangarStore(path: path);
    await yeniden.load();
    expect(yeniden.corruptLines, 0);
    expect(yeniden.of('a').credits, 500);
    expect(yeniden.of('b').credits, 7);
  });
}
