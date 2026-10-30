@Tags(['disi'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/ledger_store.dart';

/// Deftere EŞZAMANLI yazım.
///
/// `hangar_yazim_yarisi_test.dart`'ın kardeşi ve aynı cümleyi sınıyor:
/// `File.writeAsString(mode: FileMode.append)` eşzamanlı DEĞİL. Her çağrı
/// dosyayı kendi açıyor, açılışta sonu buluyor ve oraya yazıyor; iki çağrı
/// aynı anda açarsa ikisi de aynı sonu buluyor ve aynı yerin üstüne yazıyor.
///
/// Defterde duran şey PARA KAYDI. Hangar bir durum — kaybolan bir satırın
/// yerine bir sonraki yazım geçer. Defter bir geçmiş: kaybolan satırın yerine
/// hiçbir şey geçmiyor, bakiyenin nereden geldiği bir daha açıklanamıyor.
///
/// **Yarış nasıl kuruluyor.** `flush()` kuyruğu SENKRON alıyor: ilk `await`e
/// kadar gövde kesintisiz koşuyor, yani `flush()` döndüğünde `_pending` çoktan
/// boşalmış oluyor. Bu yüzden art arda iki `flush()` yarışmıyor — ikincisi
/// boş kuyruk görüp çıkıyor. Yarış, birinci yazım UÇUŞTAYKEN kuyruğa yeni
/// kayıt girdiğinde kuruluyor: ikinci `flush()` artık dolu bir kuyruk buluyor
/// ve birincinin üstüne yazıyor.
///
/// Bu kurgu uydurma değil, `gateway.dart`'ın kendisi: defter iki yerden
/// `unawaited` yazılıyor — beş saniyelik toplu tur (`_reportClock`) ve oturum
/// kopuşu (`_drop`) — ve aradaki her imha kuyruğa yeni kayıt koyuyor. Toplu
/// tur yazarken kopan bir oturum tam olarak bu.
void main() {
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('voidspace_defter_yarisi');
    path = '${dir.path}/ledger.jsonl';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  LedgerEntry kayit(String id, int delta) => LedgerEntry(
    id: id,
    accountId: 'hesap',
    currency: Currency.credit,
    delta: delta,
    balanceAfter: delta,
    reason: LedgerReason.kill,
    atMillis: 0,
    // Uzunluğu TURA GÖRE değişen bir alan. Eşit uzunluktaki yazımlar
    // birbirini tam örter ve kayıp sessiz olur; farklı uzunluktakiler yırtık
    // bırakır. Test iki hasarı da görebilsin diye satır boyu kasten oynak.
    detail: 'x' * (id.length * 3),
  );

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

  /// [tur] kez "kayıt ekle, beklemeden yaz" — hepsi AYNI ANDA uçuşta.
  ///
  /// Her tur bir öncekinden bir kayıt fazla yazıyor: yığınların bayt uzunluğu
  /// böylece hep farklı oluyor.
  Future<Set<String>> esZamanliYaz(int tur) async {
    final store = LedgerStore(path: path);
    final yazimlar = <Future<void>>[];
    final beklenen = <String>{};
    for (var i = 0; i < tur; i++) {
      final yigin = [
        for (var j = 0; j <= i; j++) kayit('tx-$i-$j', i + j + 1),
      ];
      beklenen.addAll(yigin.map((e) => e.id));
      store.add(yigin);
      yazimlar.add(store.flush());
    }
    await Future.wait(yazimlar);
    return beklenen;
  }

  test('EŞZAMANLI yazımlar defteri yırtmıyor', () async {
    final beklenen = await esZamanliYaz(30);
    expect(
      bozukSatirlar(),
      isEmpty,
      reason: 'eşzamanlı yazımlar defterde yırtık bıraktı',
    );
    // Satır SAYISI da sınanıyor, çünkü yırtık bu yarışın yalnız bir yüzü.
    // Sıralama kaldırılıp ölçüldüğünde çıkan sonuç şuydu: 465 kayıttan
    // dosyada 30 satır kalıyor, YIRTIK SAYISI SIFIR. Otuz yazım da aynı
    // sıfır konumunu açıyor ve en uzunu ötekilerin hepsini eksiksiz
    // örtüyor — yani yalnız yırtığa bakan bir test bu hasarı hiç görmez.
    expect(
      File(path).readAsLinesSync().where((l) => l.trim().isNotEmpty),
      hasLength(beklenen.length),
      reason: 'satır sayısı yazılan kayıt sayısını tutmuyor',
    );
  });

  test('EŞZAMANLI yazımların HİÇBİR kaydı kaybolmuyor', () async {
    // Asıl sessiz hasar bu. Yırtık görülebilir bir iz bırakıyor; kısa bir
    // yazım uzun bir yazımın üstünü tamamen örterse geriye bozuk satır bile
    // kalmıyor ve o para hareketi hiç olmamış gibi oluyor.
    final beklenen = await esZamanliYaz(30);
    final store = LedgerStore(path: path);
    final okunan = await store.readAll();
    expect(
      okunan.map((e) => e.id).toSet(),
      beklenen,
      reason: 'eşzamanlı yazımda para kaydı diskten silindi',
    );
    expect(
      okunan,
      hasLength(beklenen.length),
      reason: 'satır sayısı kayıt sayısını tutmuyor',
    );
  });

  test('ARDIŞIK turlar sırayı koruyor', () async {
    // Sıranın kendisi de bir güvence: defter bir GEÇMİŞ, ve sırası bozuk bir
    // geçmiş "önce ne oldu" sorusunu cevaplayamaz.
    final store = LedgerStore(path: path);
    final yazimlar = <Future<void>>[];
    for (var i = 0; i < 20; i++) {
      store.add([kayit('sira-$i', i)]);
      yazimlar.add(store.flush());
    }
    await Future.wait(yazimlar);

    final okunan = await LedgerStore(path: path).readAll();
    expect(
      okunan.map((e) => e.id).toList(),
      [for (var i = 0; i < 20; i++) 'sira-$i'],
      reason: 'kayıtlar yazıldıkları sırada durmuyor',
    );
  });

  test('YAZILAMAYAN yığın kuyrukta kalıyor — para kaydı kaybolmuyor', () async {
    // Zincirin hatayla KOPMAMASI da sınanıyor: patlayan bir yazımdan sonra
    // depo sağır kalırsa, diskin bir anlığına dolması bütün defteri
    // susturur.
    final store = LedgerStore(path: '${dir.path}/yok/olmayan/ledger.jsonl');
    // Dizin AÇILAMAZ hâle getiriliyor: yazma yolunda bir dosya var.
    File('${dir.path}/yok').writeAsStringSync('bu bir dizin değil');
    store.add([kayit('a', 1)]);
    await expectLater(store.flush(), throwsA(isA<Object>()));
    expect(store.pending, 1, reason: 'yazılamayan kayıt kuyrukta kalmadı');

    // Engel kalkınca aynı depo yazabilmeli — zincir kopmamış olmalı.
    File('${dir.path}/yok').deleteSync();
    await store.flush();
    expect(store.pending, 0, reason: 'zincir hatadan sonra sağır kaldı');
    final okunan = await LedgerStore(
      path: '${dir.path}/yok/olmayan/ledger.jsonl',
    ).readAll();
    expect(okunan.map((e) => e.id), ['a']);
  });
}
