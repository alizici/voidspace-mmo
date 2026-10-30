@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// İKİ para biriminin kuralları.
///
/// Para söz konusuyken hata sınıfları sıradan değil: yanlış keseden düşen bir
/// alım, oyuncunun kazandığı şeyi sessizce yiyor. Buradaki testlerin hepsi o
/// tek cümlenin farklı yüzleri.
void main() {
  /// Testler için sabit bağlam: kimlik ve zaman dış dünyadan geliyor, yani
  /// burada da elle veriliyor. Sabit olması defterin içeriğini doğrulanabilir
  /// kılıyor.
  var counter = 0;
  TxContext tx() => TxContext(id: 'tx${counter++}', atMillis: 1700000000000);

  group('cüzdan', () {
    test('harcama YETMEZSE hiçbir şey değişmez', () {
      // Kısmi düşüm en tehlikeli hata: para gidiyor, eşya gelmiyor.
      final hangar = Hangar(accountId: 'a', credits: 100, premium: 5);
      expect(hangar.spendFor(Currency.credit, 101, tx()), isFalse);
      expect(hangar.credits, 100, reason: 'yetmeyen alım parayı yedi');
      expect(hangar.spendFor(Currency.premium, 6, tx()), isFalse);
      expect(hangar.premium, 5);
    });

    test('harcama DOĞRU keseden düşer', () {
      final hangar = Hangar(accountId: 'a', credits: 100, premium: 50);
      expect(hangar.spendFor(Currency.premium, 20, tx()), isTrue);
      expect(hangar.premium, 30);
      expect(hangar.credits, 100, reason: 'yanlış keseden düşüldü');
    });

    test('eksi kazanç yok sayılır', () {
      // Ödül yolundan gelen bir eksi, ekonomiyi ters yönde besler. Sunucu
      // bugün eksi göndermiyor ama gönderdiği gün burada durur.
      final hangar = Hangar(accountId: 'a', credits: 100)
        ..earnFrom(Currency.credit, -50, tx());
      expect(hangar.credits, 100);
    });

    test('bakiye diske yazılıp geri OKUNUR', () {
      // İkinci birim sonradan geldi; yazılıp okunmayan bir bakiye, her
      // oturumda sıfırlanan bir ödül demek.
      final hangar = Hangar(accountId: 'a', credits: 7, premium: 3);
      final back = Hangar.fromJson(hangar.toJson());
      expect(back.credits, 7);
      expect(back.premium, 3);
    });

    test('ESKİ kayıtta premium alanı yoksa başlangıç bakiyesi verilir', () {
      // Alan sonradan eklendi. Sıfır vermek, eski oyuncuları yenilerden
      // geride bırakırdı — kendi hatamızın bedelini onlara ödetmek olurdu.
      final json = Hangar(accountId: 'a').toJson()..remove('premium');
      expect(Hangar.fromJson(json).premium, Hangar.startingPremium);
    });
  });

  group('fiyat', () {
    test('NOVA rafı KREDİ rafından ayrı ölçekte', () {
      final credit = Catalogue.priceOf(Catalogue.pl4);
      final premium = Catalogue.priceOf(Catalogue.pl5);
      expect(credit.currency, Currency.credit);
      expect(premium.currency, Currency.premium);
      // Kıt paranın kıt HİSSEDİLMESİ sayısının da küçük olmasına bağlı.
      expect(premium.amount, lessThan(credit.amount / 10));
    });

    test('kredi rafındaki hiçbir eşya NOVA istemiyor', () {
      // İlerlemenin zorunlu bir basamağı kıt paraya bağlanırsa, oyun
      // oynayarak ilerleyen oyuncu bir duvara çarpar ve o duvarın adı "öde"
      // olur. NOVA rafı mağazanın ÜSTÜNE konuyor, içine değil.
      // SATIŞTA olanlar: merdivenden türetilen kademelerin fiyatı `null` —
      // henüz alınamıyorlar, yani kıt paraya bağlanmış da sayılmazlar.
      for (final hull in HullClass.all.where((h) => h.satinAlinabilir)) {
        expect(
          Catalogue.hullPrice(hull)!.currency,
          Currency.credit,
          reason: '${hull.name} kıt paraya bağlanmış',
        );
      }
      // Başlangıç gemisinin yuvalarını dolduracak her şey krediyle alınabilir.
      // Raf banda bağlı (15.2) ve HEP kredi: her bantta her yuva tipi için
      // bir taban eşya var, NOVA eşya satmıyor (15.1).
      for (final bolge in Bolge.hepsi) {
        final raf = Catalogue.rafFor(bolge.ilkRank);
        expect(Catalogue.rafFiyati(bolge.ilkRank).currency, Currency.credit);
        for (final slot in SlotType.values) {
          expect(
            raf.where((i) => i.slot == slot),
            isNotEmpty,
            reason: '${bolge.ad}: $slot yuvası için rafta eşya yok',
          );
        }
      }
    });

    test('NOVA eşyası NOVA ile alınır, kredi ile ALINMAZ', () {
      final price = Catalogue.priceOf(Catalogue.pl5);
      final rich = Hangar(accountId: 'a', credits: 10000000, premium: 0);
      final (item, error) = HangarRules.buyItem(rich, 'pl5', 'x', tx());
      expect(item, isNull);
      expect(error, HangarError.notEnoughCredits);
      expect(rich.credits, 10000000, reason: 'kredi kesesine el atıldı');

      final funded = Hangar(accountId: 'b', credits: 0, premium: price.amount);
      final (bought, ok) = HangarRules.buyItem(funded, 'pl5', 'y', tx());
      expect(ok, isNull);
      expect(bought, isNotNull);
      expect(funded.premium, 0);
    });

    test('yükseltme HER ZAMAN kredi — NOVA eşyası da olsa', () {
      // Kıt para EŞYAYI satıyor, eşyanın ömrünü değil. Yükseltmeyi de NOVA'ya
      // bağlamak, oyuncuyu aldığı şeyi geliştiremez hâle getirirdi.
      final hangar = Hangar(accountId: 'a', credits: 5000000, premium: 0)
        ..addItem(const ItemInstance(instanceId: 'i', specId: 'pl5'))
        ..malzemeEkle(Malzeme.forRank(Catalogue.pl5.tier), 100000);
      expect(HangarRules.upgrade(hangar, 'i', tx()), isNull);
      expect(hangar.itemOf('i')!.level, 1);
      expect(hangar.premium, 0, reason: 'yükseltme kıt paraya el attı');
    });
  });

  group('alien ödülleri', () {
    test('her tür KREDİ ve NOVA düşürür', () {
      // Yalnız parayla alınan bir birim, oyuncunun ekonominin parçası
      // saymadığı bir birimdir. Kıt para oyun içinde de kazanılmak ZORUNDA.
      for (final alien in AlienStats.all) {
        expect(alien.creditReward, greaterThan(0), reason: alien.name);
        expect(alien.premiumReward, greaterThan(0), reason: alien.name);
      }
    });

    test('ödül DAYANIKLILIKLA orantılı', () {
      // Büyük hedefe girmenin sebebi olmalı: dokuz yaylım süren bir alien,
      // iki yaylımlık olandan daha çok vermeli.
      expect(
        AlienStats.leviathan.creditReward,
        greaterThan(AlienStats.spore.creditReward),
      );
      expect(
        AlienStats.leviathan.premiumReward,
        greaterThan(AlienStats.spore.premiumReward),
      );
    });
  });
}
