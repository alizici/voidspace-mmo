@Tags(['disi'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/hangars.dart';

/// Şişen ilerleme dosyasının SIKIŞTIRILMASI.
///
/// Ölçüldü: 107 satırlık dosyada 4 hesap — %96 ölü satır. Sebep, ödül
/// sisteminin yazma desenini değiştirmesi: yazmalar artık oyuncu eylemiyle
/// (seyrek) değil, her imhada (beş saniyede bir) oluyor. 60 oyuncuda saatte
/// ~15 MB, bir ayda ~4 GB ve 25 saniyelik açılış.
///
/// Buradaki testlerin hepsi tek bir cümlenin yüzleri: **sıkıştırma hiçbir
/// ilerlemeyi kaybetmemeli.** Veri kaybettiren bir sıkıştırma, çözdüğü
/// sorundan kat kat kötüdür.
void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('voidspace_compact');
    path = '${dir.path}/hangars.jsonl';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// [accounts] hesabı [writes] kez yazarak şişmiş bir dosya üretir.
  Future<HangarStore> bloat({
    required int accounts,
    required int writes,
  }) async {
    final store = HangarStore(path: path);
    for (var w = 0; w < writes; w++) {
      for (var a = 0; a < accounts; a++) {
        final hangar = store.of('hesap$a')
          ..earn(
            Currency.credit,
            1,
            reason: LedgerReason.kill,
            txId: 'w$w-a$a',
            atMillis: 0,
          );
        await store.save(hangar);
      }
    }
    return store;
  }

  test('KÜÇÜK dosya sıkıştırılmıyor — sırf I/O olurdu', () {
    // Redis'in `auto-aof-rewrite-min-size`'ı: birkaç yüz kilobayt için
    // yeniden yazma yapmanın kazancı yok.
    final store = HangarStore(path: path);
    expect(store.needsCompaction, isFalse);
  });

  test('dosya SINIRLI kalıyor — yazma sayısıyla büyümüyor', () async {
    // Verilen garanti "dosya yaşayan kayıt sayısına iner" DEĞİL: sıkıştırma
    // eşiği aşınca çalışıyor ve arkasından yazmalar devam ediyor. Garanti,
    // boyutun ZAMANLA değil EŞİKLE sınırlı olması — asıl sorun buydu.
    const writes = 80;
    const accounts = 4;
    final store = await bloat(accounts: accounts, writes: writes);
    expect(store.compactions, greaterThan(0), reason: 'hiç sıkıştırmadı');

    final lines = File(
      path,
    ).readAsLinesSync().where((l) => l.trim().isNotEmpty).length;
    expect(
      lines,
      lessThan(HangarStore.compactMinLines + accounts),
      reason: 'dosya eşiğin üstünde büyümeye devam etti',
    );
    expect(
      lines,
      lessThan(writes * accounts ~/ 2),
      reason: 'sıkıştırma yazma sayısına göre kazanç sağlamadı',
    );
  });

  test('sıkıştırma HİÇBİR ilerlemeyi kaybetmiyor', () async {
    // En önemli test. Veri kaybettiren bir sıkıştırma, çözdüğü sorundan kat
    // kat kötü.
    final store = await bloat(accounts: 5, writes: 100);
    final before = {
      for (var a = 0; a < 5; a++) 'hesap$a': store.of('hesap$a').credits,
    };
    expect(store.compactions, greaterThan(0));

    final reloaded = HangarStore(path: path);
    await reloaded.load();
    for (final entry in before.entries) {
      expect(
        reloaded.of(entry.key).credits,
        entry.value,
        reason: '${entry.key} bakiyesi sıkıştırmada değişti',
      );
    }
    expect(reloaded.count, 5);
  });

  test('AÇILIŞTA sıkıştırıyor — en ucuz an orası', () async {
    // Şişmiş bir dosyayı elle kur: sunucu açılırken oyuncu yok ve dosya en
    // şişkin hâlinde.
    final line = jsonEncode(Hangar(accountId: 'a', credits: 5).toJson());
    await File(path).writeAsString('${List.filled(400, line).join('\n')}\n');
    expect(File(path).readAsLinesSync().length, 400);

    final store = HangarStore(path: path);
    await store.load();

    expect(store.compactions, 1);
    expect(
      File(path).readAsLinesSync().where((l) => l.isNotEmpty),
      hasLength(1),
    );
    expect(store.of('a').credits, 5, reason: 'açılış sıkıştırması veri yedi');
  });

  test('geçici dosya ARKADA KALMIYOR', () async {
    // `rename` atomik ve geçici dosyayı tüketiyor. Kalan bir `.tmp`, bir
    // sonraki sıkıştırmanın yarım veriyle başlaması demekti.
    await bloat(accounts: 3, writes: 100);
    expect(File('$path.tmp').existsSync(), isFalse);
  });

  test('AYNI içerik iki kez yazılmıyor', () async {
    // Kirli işaretlenip aslında değişmemiş hangar — ödül payı sıfıra
    // yuvarlandığında gerçekten oluyor.
    final store = HangarStore(path: path);
    final hangar = store.of('a');
    await store.save(hangar);
    final first = File(path).lengthSync();
    await store.save(hangar);
    await store.save(hangar);
    expect(
      File(path).lengthSync(),
      first,
      reason: 'değişmemiş hangar tekrar tekrar yazıldı',
    );
  });

  test('BOZUK satır sıkıştırmadan sağ çıkıyor', () async {
    // Süreç yazarken ölürse yarım bir satır kalabilir. Onun yüzünden bütün
    // ilerlemeyi kaybetmek, korumaya çalıştığımız şeyi kaybetmek.
    final good = jsonEncode(Hangar(accountId: 'a', credits: 9).toJson());
    await File(path).writeAsString('$good\n{yarım\n$good\n');
    final store = HangarStore(path: path);
    await store.load();
    expect(store.of('a').credits, 9);
  });
}
