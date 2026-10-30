@Tags(['disi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// GANİMET — çekilişin hangara VARDIĞI yer.
///
/// Çekilişin kendisi `voidspace_core`'da saf olarak test ediliyor: paylar,
/// PRD, kalite tabanı, dağılımlar. Buradaki testlerin işi ayrı ve dar —
/// **bağlantı**. Boss randevusunda tam olarak burası eksikti: mekanizma
/// yazılmış, test edilmiş ve üretimde hiç çağrılmamıştı. Aynı hatayı iki kez
/// yapmamak için ganimetin öldürmeden envantere kadar gittiği ölçülüyor.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_ganimet'));

  /// Testler arasında PAYLAŞILAN sunucu.
  ///
  /// Pay testi iki oyuncu istiyor ve ikisinin AYNI dünyada olması şart —
  /// hasar payı ancak tek bir tehdit tablosunda anlamlı.
  Gateway? paylasilan;

  tearDown(() {
    paylasilan = null;
    temp.deleteSync(recursive: true);
  });

  /// Sunucuya bir hesapla gir. Sürü YOK; ölçülen şey ganimet.

  ///
  /// [gelen] verilirse sunucudan gelen çerçeveler oraya birikir.
  Future<(Gateway, Hangar, int, WebSocket)> gir({
    String ad = 'ganimetci',
    List<Uint8List>? gelen,
  }) async {
    final gateway = paylasilan ??= Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
    );
    if (gateway.port == 0) {
      await gateway.start(host: '127.0.0.1', port: 0);
      addTearDown(gateway.stop);
    }

    final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    addTearDown(socket.close);
    socket.listen(
      (d) => gelen?.add(Uint8List.fromList(d as List<int>)),
      onError: (_) {},
      onDone: () {},
    );
    final account = await gateway.accounts.register(
      email: '$ad@dev.local',
      username: ad,
      password: 'yeterince-uzun-parola',
    );
    socket.add(
      ClientHello(
        protocolVersion: Protocol.version,
        token: gateway.accounts.issueToken(account),
      ).encode(),
    );
    final oncekiler = gateway.zone.ships.keys.toSet();
    await _until(
      () => gateway.zone.ships.keys.toSet().difference(oncekiler).isNotEmpty,
    );
    final shipId = gateway.zone.ships.keys.toSet().difference(oncekiler).first;
    return (gateway, gateway.hangars.of(account.id), shipId, socket);
  }

  /// [shipId]'ye ait olacak şekilde bir BOSS doğur ve öldür.
  ///
  /// Boss seçildi çünkü düşüşü garantili ([TasarimGirdileri.bossEsyaSayisi]):
  /// sıradan yaratıkta şans %1,18 ve test binlerce öldürme sürerdi.
  ///
  /// **Öldürme GERÇEK boru hattından.** Hazır bir vuruş olayı listeye
  /// enjekte etmek denenmezdi bile: `step()` olay listelerini EN BAŞTA
  /// temizliyor, yani dışarıdan eklenen vuruş ödül yoluna hiç ulaşmazdı.
  /// Bunun yerine kurulum gerçeğe yaklaştırılıyor — boss'un canı bire
  /// indiriliyor, gemi yanına konuyor, silah hedefi veriliyor — ve öldürmeyi
  /// simülasyonun kendisi yapıyor. Ölçülen şey de bu: ödül yolu GERÇEK bir
  /// imhayı görüyor mu.
  Future<void> bossOldur(Gateway gateway, int shipId, WebSocket socket) async {
    final zone = gateway.zone;
    // Boss'u test DOĞURMUYOR: randevu zaten doğurdu. İlk hâli `bossDogur()`
    // çağırıyordu ve `false` dönüyordu — çünkü tik döngüsü ilk tikte işini
    // yapmıştı. Testin kendi kurduğu bir dünyada değil, sunucunun kurduğu
    // dünyada ölçmek gerekiyordu; şimdi randevu yolu da bu testin kapsamında.
    await _until(() => zone.bossCanli);
    final bossId = zone.bossId;
    final boss = zone.aliens[bossId]!;

    // Can bire iniyor: boss'un 409.091 canını gerçek yaylımlarla eritmek
    // testi dakikalarca sürdürürdü. Öldürmenin KENDİSİ yine gerçek.
    zone.aliens[bossId] = boss.copyWith(hull: 1);
    final ship = zone.ships[shipId]!;
    ship.state = ship.state.copyWith(position: boss.home);

    // Silah hedefi SOKETTEN. Doğrudan `state.weaponTarget` yazmak denendi ve
    // tutmadı: hedef her tik istemci girdisinden yeniden yazılıyor, yani bir
    // sonraki tikte sıfırlanıyordu. Ölçülen tanı buydu — `hedef=0`.
    socket.add(
      ClientInput(
        seq: 1,
        input: ShipInput(seq: 1, weaponTarget: bossId, firing: true),
      ).encode(),
    );
  }

  /// Gövde kalemi: yeni düşenlerden droid olmayanlar. Filo ayrı kalem
  /// (14.3 s2) ve kendi zarını atıyor; boss'un garantisi gövdenin.
  int govdeDusen(Hangar hangar, Set<String> onceki) => hangar.inventory.keys
      .where((id) => !onceki.contains(id))
      .where(
        (id) =>
            Catalogue.byId[hangar.itemOf(id)!.specId]!.slot != SlotType.droid,
      )
      .length;

  group('bağlantı', () {
    test('boss ganimeti ENVANTERE varıyor', () async {
      final (gateway, hangar, shipId, socket) = await gir();
      final onceki = hangar.inventory.keys.toSet();
      await bossOldur(gateway, shipId, socket);
      await _until(() => hangar.inventory.length > onceki.length);
      expect(
        govdeDusen(hangar, onceki),
        TasarimGirdileri.bossEsyaSayisi,
        reason: 'boss garantili sayıda eşya düşürmedi',
      );
    });

    test('düşen her eşya KATALOGDA çözülüyor', () async {
      final (gateway, hangar, shipId, socket) = await gir();
      final onceki = hangar.inventory.keys.toSet();
      await bossOldur(gateway, shipId, socket);
      await _until(() => hangar.inventory.length > onceki.length);
      for (final id in hangar.inventory.keys.toSet().difference(onceki)) {
        final item = hangar.itemOf(id)!;
        expect(
          Catalogue.byId[item.specId],
          isNotNull,
          reason: '${item.specId} katalogda yok',
        );
      }
    });

    test('düşen eşya BANDIN rankında — sanat sabitinde değil', () async {
      final (gateway, hangar, shipId, socket) = await gir();
      final onceki = hangar.inventory.keys.toSet();
      await bossOldur(gateway, shipId, socket);
      await _until(() => hangar.inventory.length > onceki.length);

      final zone = gateway.zone;
      final rank = zone.bolge.rankOf(zone.bandFor(zone.world.centre));
      for (final id in hangar.inventory.keys.toSet().difference(onceki)) {
        final tier = Catalogue.byId[hangar.itemOf(id)!.specId]!.tier;
        // Boss'ta çekiliş bant ya da üst; alt yok.
        expect(
          tier.index,
          inInclusiveRange(rank, rank + 1),
          reason: '${tier.label} bandın (rank $rank) dışında',
        );
      }
    });

    test('MALZEME de envantere varıyor — her öldürmede', () async {
      // Alan 14'ün ayrımı: malzeme sürekli, eşya seyrek. Boss'ta ikisi de
      // garantili, yani tek bir imha ikisini birden ölçebiliyor.
      final (gateway, hangar, shipId, socket) = await gir();
      expect(hangar.malzemeler, isEmpty, reason: 'taze hangar malzemeli');
      await bossOldur(gateway, shipId, socket);
      await _until(() => hangar.malzemeler.isNotEmpty);

      final zone = gateway.zone;
      final rank = zone.bolge.rankOf(zone.bandFor(zone.world.centre));
      final beklenen = Malzeme.forRank(ItemTier.values[rank]);
      expect(
        hangar.malzemeSayisi(beklenen),
        greaterThan(0),
        reason: 'malzeme bandın rankında gelmedi',
      );
      // Malzeme EŞYA envanterine sızmamalı — iki kap ayrı.
      for (final id in hangar.inventory.keys) {
        expect(Malzeme.byId(id), isNull, reason: '$id eşya envanterinde');
      }
    });

    // KARAR 14.1 s1
    test('düşen ganimet SOKETE de söyleniyor: ne düştüğü, kimden', () async {
      // Hangar durumu envanterin doğrusu ama "ne değişti" demiyor; HUD'un
      // "C-II PL-2 düştü" yazabilmesi için sunucu düşeni ayrıca söylüyor.
      // Ölçülen: mesajdaki liste, hangara GERÇEKTEN düşenle birebir.
      final gelen = <Uint8List>[];
      final (gateway, hangar, shipId, socket) = await gir(gelen: gelen);
      final zone = gateway.zone;
      await _until(() => zone.bossCanli);
      final bossId = zone.bossId;
      final onceki = hangar.inventory.keys.toSet();
      await bossOldur(gateway, shipId, socket);
      await _until(() => hangar.inventory.length > onceki.length);
      await _until(
        () => gelen.any((b) => b.isNotEmpty && b[0] == Protocol.msgGanimet),
      );

      final ganimet =
          ServerMessage.decode(
                gelen.firstWhere(
                  (b) => b.isNotEmpty && b[0] == Protocol.msgGanimet,
                ),
              )
              as ServerGanimet;
      final dusenler = [
        for (final id in hangar.inventory.keys.toSet().difference(onceki))
          hangar.itemOf(id)!.specId,
      ];
      expect(ganimet.sourceId, bossId, reason: 'kaynak boss değil');
      expect(
        ganimet.esyalar,
        unorderedEquals(dusenler),
        reason: 'söylenen ile düşen ayrışıyor',
      );
      final rank = zone.bolge.rankOf(zone.bandFor(zone.world.centre));
      expect(ganimet.malzemeRank, rank);
      expect(
        ganimet.malzeme,
        hangar.malzemeSayisi(Malzeme.forRank(ItemTier.values[rank])),
        reason: 'söylenen malzeme adedi hangardakiyle uyuşmuyor',
      );
    });

    test('PAY bölününce kimse tam sayıda eşya almıyor', () async {
      // Mutasyon sınaması bu testi zorunlu kıldı: `hasarPayi`'yi 1,0'a
      // sabitleyen bir hata TEK oyunculu testlerin hiçbirini kırmıyordu,
      // çünkü orada pay zaten 1,0. Ekonominin bozulacağı yer tam da burası —
      // pay yok sayılırsa dört kişilik bir grup, tek kişinin dört katı eşya
      // basar.
      //
      // Ayrım KESKİN ve olasılıksal değil: tam payda boss garantili
      // `bossEsyaSayisi` (3) veriyor; yarım payda `floor(1,5) = 1` garanti,
      // ikincisi zar. Yani yarım payda ÜÇ imkânsız.
      final (gateway, hangarA, shipA, socketA) = await gir(ad: 'paya');
      final (_, hangarB, shipB, socketB) = await gir(ad: 'payb');
      final zone = gateway.zone;
      await _until(() => zone.bossCanli);

      final bossId = zone.bossId;
      final boss = zone.aliens[bossId]!;
      // İKİSİ de eşit hasar yazmış olsun; öldürücü vuruş sonra geliyor.
      zone.threatOf(bossId)
        ..add(shipA, 1000)
        ..add(shipB, 1000);
      zone.aliens[bossId] = boss.copyWith(hull: 1);
      for (final (shipId, socket) in [(shipA, socketA), (shipB, socketB)]) {
        zone.ships[shipId]!.state = zone.ships[shipId]!.state.copyWith(
          position: boss.home,
        );
        socket.add(
          ClientInput(
            seq: 1,
            input: ShipInput(seq: 1, weaponTarget: bossId, firing: true),
          ).encode(),
        );
      }

      final onceA = hangarA.inventory.keys.toSet();
      final onceB = hangarB.inventory.keys.toSet();
      await _until(
        () =>
            hangarA.inventory.length > onceA.length ||
            hangarB.inventory.length > onceB.length,
      );
      // Ödül aynı tikte dağıtılıyor; ikisi de yazılsın diye bir tik daha.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      for (final (ad, once, hangar) in [
        ('A', onceA, hangarA),
        ('B', onceB, hangarB),
      ]) {
        final dusen = govdeDusen(hangar, once);
        expect(
          dusen,
          lessThan(TasarimGirdileri.bossEsyaSayisi),
          reason: '$ad yarım payla tam sayıda eşya aldı — pay yok sayılıyor',
        );
      }
    });
  });

  group('kalıcılık', () {
    test('PRD sayacı hangara YAZILIYOR ve geri okunuyor', () async {
      // PRD oturumdan uzun bir seriyi kırıyor; sayaç kaydedilmezse her giriş
      // oyuncuyu en düşük şansa atardı — yani acıma sistemi en çok gerektiği
      // anda hiçbir şey yapmazdı.
      final hangar = Hangar(accountId: 'x');
      hangar.ganimetPrd.kacirmayiGeriYukle(7);
      final geri = Hangar.fromJson(hangar.toJson());
      expect(geri.ganimetPrd.misses, 7);
    });

    test('sayaç YOKSA sıfırdan başlıyor — eski kayıtlar bozulmuyor', () {
      final json = Hangar(accountId: 'y').toJson()..remove('ganimetKacirma');
      expect(Hangar.fromJson(json).ganimetPrd.misses, 0);
    });
  });
}

Future<void> _until(bool Function() kosul, {int adim = 400}) async {
  for (var i = 0; i < adim; i++) {
    if (kosul()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('koşul zamanında gerçekleşmedi');
}
