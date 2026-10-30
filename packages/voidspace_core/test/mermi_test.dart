@Tags(['turetme', 'aralik', 'kapsam'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 17 · Mermi — belgenin değişmezleri.
void main() {
  group('kapsam', () {
    // KARAR 17.4 s1
    test('MR-1 … MR-tavan ve bir sifon; kimlikler benzersiz', () {
      final duz = Mermi.hepsi.where((m) => !m.sifon).toList();
      expect(duz, hasLength(TasarimGirdileri.mermiCarpanTavani));
      expect(duz.map((m) => m.carpan), List.generate(duz.length, (i) => i + 1));
      expect(Mermi.hepsi.where((m) => m.sifon), hasLength(1));
      expect(
        Mermi.hepsi.map((m) => m.id).toSet(),
        hasLength(Mermi.hepsi.length),
      );
      expect(Mermi.byId('MR-1'), same(Mermi.mr1));
      expect(Mermi.byId('yok'), isNull);
    });
  });

  group('türetme', () {
    // KARAR 17.2 s1
    test('MR-1 bedava ve sınırsız — kilit', () {
      expect(TasarimGirdileri.mr1Bedava, isTrue);
      expect(Mermi.mr1.bedava, isTrue);
      expect(Mermi.mr1.fiyat, 0);
      final hangar = Hangar(accountId: 'a');
      // Stok yokken bile bedava mermi tükenmiyor.
      expect(hangar.mermiHarca('MR-1', 500), 500);
      expect(hangar.seciliMermi, same(Mermi.mr1));
    });

    // KARAR 17.4 s1
    test('fiyat c × m^k; birim hasar bedeli çarpanla ARTIYOR', () {
      for (final m in Mermi.hepsi.where((m) => !m.bedava)) {
        expect(
          m.fiyat,
          closeTo(
            TasarimGirdileri.mermiTabanFiyati *
                math.pow(m.carpan, TasarimGirdileri.mermiFiyatUssu),
            1e-9,
          ),
        );
      }
      var onceki = 0.0;
      for (var c = 2; c <= TasarimGirdileri.mermiCarpanTavani; c++) {
        final bedel = Turetilenler.mermiHasarBedeli(c);
        expect(bedel, greaterThan(onceki), reason: '×$c ucuza gelmiş');
        onceki = bedel;
      }
      // Sifonun fiyatı kendi çarpanının fiyatı: MR-3 ile aynı.
      expect(Mermi.sf1.fiyat, Turetilenler.mermiFiyati(Mermi.sf1.carpan));
    });

    // KARAR 17.4 s1
    test('üs iki ankrajın kesişimi: k = 1 + ln2 ÷ ln(tavan ÷ 2)', () {
      expect(
        TasarimGirdileri.mermiFiyatUssu,
        closeTo(Turetilenler.mermiUsAnkraji, 0.002),
      );
      // Ankrajın kendisi: tavanın birim hasar bedeli ×2'ninkinin iki katı.
      expect(
        Turetilenler.mermiHasarBedeli(TasarimGirdileri.mermiCarpanTavani) /
            Turetilenler.mermiHasarBedeli(2),
        closeTo(2, 0.01),
      );
    });

    // KARAR 17.1 s1
    test('PvP TTK referans ÷ m; PvE kazancı öldürme hızından', () {
      expect(Turetilenler.mermiPvpTtk(1), TasarimGirdileri.referansTTK);
      expect(
        Turetilenler.mermiPvpTtk(TasarimGirdileri.mermiCarpanTavani),
        TasarimGirdileri.referansTTK / TasarimGirdileri.mermiCarpanTavani,
      );
      expect(Turetilenler.mermiPveKazanci(1), 0);
      expect(Turetilenler.mermiPveKazanci(2), greaterThan(0));
    });

    // KARAR 17.6 s1
    test('sifonun yenilenmeye karşı etkin çarpanı nominalin ÜSTÜNDE', () {
      expect(
        MermiOlcumu.sifonEtkinCarpani,
        greaterThan(TasarimGirdileri.sifonCarpani),
      );
    });
  });

  group('aralık', () {
    // KARAR 17.1 s1
    test('sıradan yaratıkta PvE kazancı ≤ %15 — mermi farm sistemi değil', () {
      expect(
        Turetilenler.mermiPveKazanci(TasarimGirdileri.mermiCarpanTavani),
        lessThanOrEqualTo(0.15),
      );
    });

    // KARAR 17.4 s1
    test('×2 sürekli farm gelirin %10–20\'si — ankraj ~%15', () {
      expect(MermiOlcumu.gelirPayi(2), inInclusiveRange(0.10, 0.20));
    });

    // KARAR 17.5 s1
    test('tavan çarpan sürekli kullanımda PvP net primi ≤ 0', () {
      expect(
        MermiOlcumu.pvpNetPrim(1),
        closeTo(TasarimGirdileri.pvpNetPrim, 1e-9),
      );
      expect(
        MermiOlcumu.pvpNetPrim(TasarimGirdileri.mermiCarpanTavani),
        lessThanOrEqualTo(0),
      );
    });

    // KARAR 17.7 s1
    test('NOVA mermi satmıyor — kilit', () {
      expect(TasarimGirdileri.novaMermiSatiyor, isFalse);
      expect(Mermi.novaIleSatilir, isFalse);
    });
  });

  group('hangar', () {
    TxContext tx() => TxContext(id: 't', atMillis: 0);

    // KARAR 17.2 s1 · KARAR 17.7 s1
    test('MR-1 satılmıyor; MR-2 krediyle, adet fiyatı yuvarlanmış', () {
      final hangar = Hangar(accountId: 'a', credits: 10000);
      expect(
        HangarRules.mermiAl(hangar, 'MR-1', 5, tx()),
        HangarError.notPurchasable,
      );
      expect(HangarRules.mermiAl(hangar, 'yok', 5, tx()), HangarError.notFound);
      expect(
        HangarRules.mermiAl(hangar, 'MR-2', 0, tx()),
        HangarError.notFound,
      );
      expect(HangarRules.mermiAl(hangar, 'MR-2', 10, tx()), isNull);
      expect(hangar.mermiSayisi('MR-2'), 10);
      expect(hangar.credits, 10000 - Mermi.byId('MR-2')!.fiyatFor(10));
      final fakir = Hangar(accountId: 'b', credits: 1);
      expect(
        HangarRules.mermiAl(fakir, 'MR-2', 10, tx()),
        HangarError.notEnoughCredits,
      );
    });

    // KARAR 17.8 s1
    test('seçim stok ister; biten stok MR-1\'e düşer', () {
      final hangar = Hangar(accountId: 'a', credits: 10000);
      expect(HangarRules.mermiSec(hangar, 'MR-3'), HangarError.mermiYok);
      expect(HangarRules.mermiSec(hangar, 'MR-1'), isNull);
      hangar.mermiEkle('MR-3', 7);
      expect(HangarRules.mermiSec(hangar, 'MR-3'), isNull);
      expect(hangar.seciliMermi.id, 'MR-3');
      // Beş namlulu yaylım: yedi stoktan beş, sonra kalan iki.
      expect(hangar.mermiHarca('MR-3', 5), 5);
      expect(hangar.mermiHarca('MR-3', 5), 2);
      expect(hangar.mermiSayisi('MR-3'), 0);
      expect(hangar.seciliMermi.id, 'MR-1', reason: 'biten mermi düşmedi');
    });

    // KARAR 17.8 s1
    test('stok ve seçim kayıtta gidip geliyor', () {
      final hangar = Hangar(accountId: 'a', credits: 10000);
      hangar
        ..mermiEkle('MR-2', 3)
        ..mermiSec('MR-2');
      final geri = Hangar.fromJson(hangar.toJson());
      expect(geri.mermiSayisi('MR-2'), 3);
      expect(geri.seciliMermi.id, 'MR-2');
      // Boş hangarın kaydında mermi alanı yok: eski kayıtların biçimi aynı.
      expect(Hangar(accountId: 'b').toJson().containsKey('mermi'), isFalse);
    });
  });

  group('sifon', () {
    // KARAR 17.6 s1
    test('kalkana vurur, gövdeye taşmaz', () {
      final s = ShipSimState.spawn(ShipStats.bastion, Vec2.zero);
      final vurulan = ShipSim.applyShieldDamage(s, s.stats.maxShield * 10);
      expect(vurulan.shield, 0);
      expect(vurulan.hull, s.hull, reason: 'kalkanı aşan pay gövdeye indi');
      expect(Mermi.sf1.govdeCarpani, 0);
      expect(Mermi.sf1.kalkanCarpani, TasarimGirdileri.sifonCarpani);
    });
  });
}
