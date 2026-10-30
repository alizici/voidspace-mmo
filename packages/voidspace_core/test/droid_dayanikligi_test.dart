@Tags(['turetme', 'aralik', 'kod-belge'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// DROİD DAYANIKLILIĞI — 05.10 sayaç ve aşınma, 15.3 onarımın NOVA fiyatı.
///
/// Droidin canı yok: dövüşte hedef alınmıyor, hasar almıyor. Kaybı ana
/// geminin ölümünden geliyor ve sayaçla ölçülüyor.
void main() {
  var sayac = 0;
  TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);

  Hangar filolu({int droid = 3, int level = 0, int premium = 0}) {
    final h = Hangar(accountId: 'a', credits: 1 << 40, premium: premium);
    // Droid sistemi üçüncü rankta açılıyor (10.7).
    h.addItem(const ItemInstance(instanceId: 'acilis', specId: 'pl5'));
    for (var i = 0; i < droid; i++) {
      h.addItem(ItemInstance(instanceId: 'd$i', specId: 'dr1', level: level));
      HangarRules.filoyaAl(h, 'd$i');
    }
    return h;
  }

  group('05.10 · sayaç', () {
    // KARAR 05.10 s1
    test('yeni droid TAM sayaçla geliyor; aşınma ölüm başına bir adım', () {
      final h = filolu();
      expect(h.itemOf('d0')!.dayaniklilik, ItemInstance.tamDayaniklilik);
      expect(h.itemOf('d0')!.asinmis, isFalse);

      h.filoyuAsindir();
      expect(
        h.itemOf('d0')!.dayaniklilik,
        ItemInstance.tamDayaniklilik - TasarimGirdileri.droidAsinmaPayi,
      );
      expect(h.itemOf('d0')!.asinmis, isTrue);
    });

    // KARAR 05.10 s1
    test('sayaç bitince droid YOK oluyor — envanterden ve filodan', () {
      final h = filolu();
      for (var i = 1; i < Turetilenler.droidOmruOlum; i++) {
        expect(h.filoyuAsindir(), isEmpty, reason: '$i. ölümde erken gitti');
        expect(h.filo, hasLength(3));
      }
      // Son ölüm: üçü birden.
      final yokOlanlar = h.filoyuAsindir();
      expect(yokOlanlar, ['d0', 'd1', 'd2']);
      expect(h.filo, isEmpty);
      expect(h.itemOf('d0'), isNull, reason: 'ölü droid envanterde kaldı');
    });

    // KARAR 05.10 s1
    test('ömür yüzde bölü aşınma payı; sıklıkla saate çevriliyor', () {
      expect(Turetilenler.droidOmruOlum, 10);
      expect(
        Turetilenler.droidOmruSaat,
        closeTo(
          Turetilenler.droidOmruOlum / TasarimGirdileri.genelOlumSikligi,
          1e-9,
        ),
      );
    });

    // KARAR 05.10 s1
    test('YALNIZ filodaki droid aşınıyor; depodaki bekliyor', () {
      final h = filolu(droid: 1);
      h.addItem(const ItemInstance(instanceId: 'yedek', specId: 'dr1'));
      h.filoyuAsindir();
      expect(h.itemOf('yedek')!.dayaniklilik, ItemInstance.tamDayaniklilik);
      expect(h.itemOf('d0')!.asinmis, isTrue);
    });

    // KARAR 05.10 s1
    test('sayaç GÜCÜ değiştirmiyor: son puanındaki droid tam vuruyor', () {
      final tam = filolu(droid: 2);
      final yipranmis = filolu(droid: 2);
      for (var i = 0; i < Turetilenler.droidOmruOlum - 1; i++) {
        yipranmis.filoyuAsindir();
      }
      expect(
        yipranmis.itemOf('d0')!.dayaniklilik,
        TasarimGirdileri.droidAsinmaPayi,
      );

      DroidGrubu grup(Hangar h) => LoadoutResolver.resolve(
        h.activeLoadout,
        h.inventory,
        Catalogue.byId,
        filo: h.filo,
        formasyon: h.formasyon,
      ).droidler;

      expect(grup(yipranmis).tabanHasar, closeTo(grup(tam).tabanHasar, 1e-12));
      expect(grup(yipranmis).havuz, closeTo(grup(tam).havuz, 1e-12));
      expect(grup(yipranmis).sayi, grup(tam).sayi);
    });

    // KARAR 05.10 s1
    test('sayaç kayıtta yaşıyor; alanı olmayan eski kayıt TAM sayılıyor', () {
      final h = filolu(droid: 1);
      h.filoyuAsindir();
      final geri = Hangar.fromJson(h.toJson());
      expect(
        geri.itemOf('d0')!.dayaniklilik,
        ItemInstance.tamDayaniklilik - TasarimGirdileri.droidAsinmaPayi,
      );

      final eski = ItemInstance.fromJson({
        'instanceId': 'x',
        'specId': 'dr1',
        'level': 0,
      });
      expect(eski.dayaniklilik, ItemInstance.tamDayaniklilik);
      // Tam sayaç dosyaya YAZILMIYOR: eski kayıtların biçimi değişmesin.
      expect(eski.toJson().containsKey('dayaniklilik'), isFalse);
    });
  });

  group('15.3 · onarım NOVA ile', () {
    // KARAR 05.10 s1 · KARAR 15.3 s3
    test('onarım sayacı TAM dolduruyor ve NOVA kesiyor', () {
      final h = filolu(droid: 1, premium: 100000);
      h.filoyuAsindir();
      final once = h.premium;
      final bedel = Kazanc.droidOnarimNovaFor(
        ItemTier.cI,
        puan: TasarimGirdileri.droidAsinmaPayi,
      );

      expect(HangarRules.droidOnar(h, 'd0', tx()), isNull);
      expect(h.itemOf('d0')!.dayaniklilik, ItemInstance.tamDayaniklilik);
      expect(h.premium, once - bedel);

      // Tam sayaçlı droidi onarmak hata DEĞİL ve bedava: boşuna gelen bir tık
      // oyuncuya kırmızı mesaj göstermemeli.
      expect(HangarRules.droidOnar(h, 'd0', tx()), isNull);
      expect(h.premium, once - bedel);
    });

    // KARAR 05.10 s1
    test('NOVA yetmiyorsa sayaç DURUYOR ve hata krediyi işaret etmiyor', () {
      final h = filolu(droid: 1, premium: 0);
      h.filoyuAsindir();
      expect(HangarRules.droidOnar(h, 'd0', tx()), HangarError.novaYok);
      expect(h.itemOf('d0')!.asinmis, isTrue);
      expect(HangarError.novaYok.message, isNot(contains('kredi')));
    });

    // KARAR 05.10 s1
    test('onarım yalnız DROİDE; başka eşya ve olmayan kimlik reddediliyor', () {
      final h = filolu(droid: 1, premium: 100000);
      expect(HangarRules.droidOnar(h, 'acilis', tx()), HangarError.wrongSlot);
      expect(HangarRules.droidOnar(h, 'yok', tx()), HangarError.notOwned);
    });

    // KARAR 15.3 s3
    test('fiyat kaybın SÜRESİ: düşme beklemesi artı artıları basma', () {
      final beklenen = Kazanc.fiyatFor(Ganimet.droidDusmeAraligiDk);
      expect(
        Kazanc.droidOnarimNovaFor(ItemTier.cI),
        beklenen.round(),
        reason: '+0 droidin tek bedeli düşmeyi beklemek',
      );
      // Artı basılmış droid daha pahalı: yenisi +0 gelir, artılar yeniden
      // basılır.
      expect(
        Kazanc.droidOnarimNovaFor(ItemTier.cI, level: 15),
        greaterThan(Kazanc.droidOnarimNovaFor(ItemTier.cI)),
      );
      // Üst rankta artı bedeli büyüyor, bekleme aynı.
      expect(
        Kazanc.droidOnarimNovaFor(ItemTier.parlayanPembe, level: 15),
        greaterThan(Kazanc.droidOnarimNovaFor(ItemTier.cI, level: 15)),
      );
    });

    // KARAR 15.3 s3
    test('fiyat DOĞRUSAL: yarım sayaç yarım bedel', () {
      final tam = Kazanc.droidOnarimNovaFor(ItemTier.aI, level: 8);
      final yarim = Kazanc.droidOnarimNovaFor(ItemTier.aI, level: 8, puan: 50);
      expect(yarim, closeTo(tam / 2, 1));
    });

    // KARAR 15.3 s3
    test('onarım LÜKS: zorunlu gidere girmiyor, toplam gidere giriyor', () {
      final zorunlu = Kazanc.zorunluGiderFor(
        rankSayisi: Turetilenler.rankSayisi,
      );
      final onarim = Kazanc.fiyatiFor(NovaKalemi.droidOnarimi).toDouble();
      expect(onarim, greaterThan(0));
      // Zorunlu gider yalnız ölüm onarımı ve envanter: droid onarımı orada
      // olsaydı "hiç ödemeyen oyuncu" değişmezi filoyu da ödemek zorunda
      // kalırdı.
      final beklenenZorunlu =
          TasarimGirdileri.genelOlumSikligi *
              TasarimGirdileri.hedefSure *
              Kazanc.fiyatiFor(NovaKalemi.onarim) +
          TasarimGirdileri.envanterKademe *
              Kazanc.fiyatiFor(NovaKalemi.envanter);
      expect(zorunlu, closeTo(beklenenZorunlu, 1e-6));
      expect(
        Kazanc.omurBoyuNovaGideri,
        greaterThan(zorunlu),
        reason: 'lüksler toplam gidere giriyor',
      );
    });

    // KARAR 15.3 s3
    test('NOVA droidi SATMIYOR: onarım, yerine koymaktan pahalı değil', () {
      // Değişmez: bir droidi onarmak, yenisini beklemekten daha uzun bir
      // zamana mal olamaz — olsaydı NOVA beklemeyi değil eşyayı satardı.
      final onarimDk = Kazanc.droidOnarimDakikasi(ItemTier.cI);
      expect(onarimDk, closeTo(Ganimet.droidDusmeAraligiDk, 1e-9));
      expect(Kazanc.esyaSatilabilir, isFalse);
    });
  });
}
