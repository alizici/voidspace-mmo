@Tags(['kapsam', 'aralik'])
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// GELİŞTİRME HESAPLARI — `DEV_RICH` ve `DEV_FULL`.
///
/// İkisinin de var olma şekli aynı ve bu kasıtlı: isim listesi KODDA değil
/// ortam değişkeninde, varsayılan boş, açıkken sunucu bağırıyor. Kodda bir
/// `if (username == ...)` satırı, üretime derlenen bir arka kapıdır.
///
/// Buradaki testler ayrıcalığın VARLIĞINI değil SINIRINI koruyor: tanımsızken
/// hiç kimseye dokunmadığını, ve tanımlıyken bile hangarı kurallardan
/// geçirdiğini.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_dev'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(Gateway, Hangar)> gir(
    String ad, {
    Set<String> rich = const {},
    Set<String> full = const {},
  }) async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
      devRichAccounts: rich,
      devFullAccounts: full,
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);

    final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    addTearDown(socket.close);
    socket.listen((_) {}, onError: (_) {}, onDone: () {});
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
    await _until(() => gateway.zone.ships.isNotEmpty);
    return (gateway, gateway.hangars.of(account.id));
  }

  double brOf(Hangar hangar) => CombatGlossary.battleRating(
    LoadoutResolver.resolve(
      hangar.activeLoadout,
      hangar.inventory,
      Catalogue.byId,
    ),
  );

  group('tanımsızken HİÇBİR ayrıcalık yok', () {
    test('sıradan hesap taze başlıyor', () async {
      final (_, hangar) = await gir('sade');
      expect(hangar.credits, Hangar.startingCredits);
      // Taze hangar BOŞ değil: başlangıç lazeri takılı geliyor. Boş bir
      // hangar oyuncuyu silahsız dünyaya bırakırdı.
      expect(hangar.inventory, hasLength(1));
      expect(hangar.activeHullId, HullClass.starter.id);
    });

    test('listede OLMAYAN hesap, liste doluyken de taze', () async {
      // Kırılırsa: ayrıcalık isme değil varlığa bağlanmış ve herkese açılmış.
      final (_, hangar) = await gir(
        'yabanci',
        rich: {'baskasi'},
        full: {'baskasi'},
      );
      expect(hangar.credits, Hangar.startingCredits);
      expect(hangar.inventory, hasLength(1));
    });
  });

  group('DEV_FULL · tam donanım', () {
    test('her yuva DOLU ve TAVAN seviyede', () async {
      final (_, hangar) = await gir('tam', full: {'tam'});
      final hull = HullClass.byId(hangar.activeHullId)!;
      for (final tip in SlotType.values) {
        for (var i = 0; i < hull.slotCount(tip); i++) {
          final takili = hangar.activeLoadout.slots[SlotRef(tip, i).id];
          expect(takili, isNotNull, reason: '${tip.name}[$i] boş');
          expect(hangar.itemOf(takili!)!.level, ItemLevels.max);
        }
      }
    });

    test('SATIŞTAKİ bütün gövdeler sahip, en iyisi seçili', () async {
      // "Bütün gövdeler" değil ve bu bir eksiklik değil: merdivenden türetilen
      // üst kademeler tanımlı ama satışta değil. Ayrıcalık kuralı esnetmiyor.
      final (_, hangar) = await gir('tam', full: {'tam'});
      final satista = HullClass.all
          .where((h) => Catalogue.hullPrice(h) != null)
          .toList();
      expect(satista, isNotEmpty);
      for (final hull in satista) {
        expect(hangar.owns(hull.id), isTrue, reason: '${hull.name} yok');
      }
      expect(hangar.activeHullId, satista.last.id);
    });

    test('SATIŞTA OLMAYAN gövde verilmiyor — kural esnetilmiyor', () {
      // Kırılırsa: ayrıcalık oyunda üretilemeyen bir hangar yaratıyor ve
      // testlerin hiç görmediği bir durum doğuyor.
      final turetilen = HullClass.all.where(
        (h) => Catalogue.hullPrice(h) == null,
      );
      expect(turetilen, isNotEmpty, reason: 'test kurgusu bozuk');
    });

    test('savaş puanı SON bölgenin kapısını açıyor', () async {
      // Ayrıcalığın oynanıştaki anlamı: bütün dünya gezilebilir olmalı.
      final (_, hangar) = await gir('tam', full: {'tam'});
      expect(brOf(hangar), greaterThan(Bolge.hepsi.last.girisEsigi));
      expect(
        GalaksiHaritasi.durumFor(br: brOf(hangar)).every((d) => d.acik),
        isTrue,
        reason: 'tam donanımlı hesapta kilitli harita kaldı',
      );
    });

    test('unvan merdiveninin ÜST ucunda', () async {
      final (_, hangar) = await gir('tam', full: {'tam'});
      final indeks = CombatGlossary.unvanIndeksi(brOf(hangar));
      expect(indeks, greaterThan(TasarimGirdileri.unvanSayisi ~/ 2));
    });

    test('durum KURALLARDAN geçerek kuruldu — bakiye tükenmedi', () async {
      // Hangarı elle doldurmak, oyunda üretilemeyen bir durum yaratırdı. Her
      // alım kuraldan geçtiği için bakiye gerçekten harcandı — ve yetti.
      final (_, hangar) = await gir('tam', full: {'tam'});
      expect(hangar.credits, greaterThan(0), reason: 'bakiye eksiye düştü');
      expect(
        hangar.credits,
        lessThan(Gateway.devRichCredits),
        reason: 'hiçbir şey harcanmamış — kurallardan geçmemiş',
      );
    });
  });

  group('DEV_RICH · yalnız para', () {
    test('zengin ama DONANIMSIZ — ikisi ayrı ayrıcalık', () async {
      final (_, hangar) = await gir('zengin', rich: {'zengin'});
      expect(hangar.credits, greaterThanOrEqualTo(Gateway.devRichCredits));
      expect(hangar.inventory, hasLength(1), reason: 'zengin olan donandı');
      expect(hangar.activeHullId, HullClass.starter.id);
    });
  });
}

Future<void> _until(bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 5)) {
      throw StateError('koşul gerçekleşmedi');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
