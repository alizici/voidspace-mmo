@Tags(['aralik'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALT STAT ÇEVİRME ve MAĞAZANIN MALZEME RAFI — alan 07'nin son iki ayağı.
void main() {
  var sayac = 0;
  TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);

  Hangar hangarla() {
    final h = Hangar(accountId: 'a', credits: 100000000);
    HangarRules.buyItem(h, 'pl4', 'x', tx());
    // ÇEVİRİCİ veriliyor: çevirme artık kredi değil kaynak istiyor ve
    // kaynağın nadirliği bu testlerin konusu değil.
    h.malzemeEkle(Malzeme.cevirmeFor(Catalogue.pl4.tier), 100000);
    return h;
  }

  String ilkStat(Hangar h) => LoadoutResolver.altStatlariFor(
    h.itemOf('x')!,
    Catalogue.pl4,
    HullClass.starter,
  ).keys.first;

  Map<String, double> statlar(Hangar h) => LoadoutResolver.altStatlariFor(
    h.itemOf('x')!,
    Catalogue.pl4,
    HullClass.starter,
  );

  group('çevirme', () {
    // KARAR 07.2 s1 · KARAR 07.5 s2
    test('eşya YOK OLMUYOR ve sonuç HER ZAMAN geliyor', () {
      // Alan 07'nin kırılma yasağı. Bedel katlanmıyor, sayaç yok: elli
      // çevirme elli bedel.
      final h = hangarla();
      final zar = math.Random(3);
      for (var i = 0; i < 50; i++) {
        expect(HangarRules.cevir(h, 'x', zar, tx()), isNull);
        expect(h.itemOf('x'), isNotNull, reason: 'eşya yok oldu');
      }
    });

    /// Çok statlı bir eşya — kilit ancak birden çok statla sınanabilir.
    (Hangar, ItemSpec) coklu() {
      final h = Hangar(accountId: 'a', credits: 100000000);
      final spec = Catalogue.items.firstWhere(
        (sp) =>
            ItemBudget.altStatSayisi(sp.tier) > 2 && sp.subStatPool.length > 2,
      );
      h.addItem(ItemInstance(instanceId: 'c', specId: spec.id));
      h.malzemeEkle(Malzeme.cevirmeFor(spec.tier), 1000000);
      return (h, spec);
    }

    Map<String, double> oku(Hangar h, ItemSpec spec) =>
        LoadoutResolver.altStatlariFor(h.itemOf('c')!, spec, HullClass.starter);

    // KARAR 07.5 s2
    test('AÇIK statların HEPSİ değişiyor — karar 07.5', () {
      // Eski kural tek statı çeviriyordu; yeni kural kilitli olmayanların
      // hepsini birden. Mutasyon sınaması: yalnız ilk statı çeviren bir
      // uygulamada bu test düşmeli.
      final (h, spec) = coklu();
      final once = Map<String, double>.from(oku(h, spec));
      expect(once.length, greaterThan(2), reason: 'test boş iddia');
      expect(HangarRules.cevir(h, 'c', math.Random(5), tx()), isNull);
      final sonra = oku(h, spec);
      for (final anahtar in once.keys) {
        expect(
          sonra[anahtar],
          isNot(closeTo(once[anahtar]!, 1e-9)),
          reason: '$anahtar değişmedi',
        );
      }
    });

    // KARAR 07.5 s2
    test('KİLİTLİ stat değişmiyor, kalanlar değişiyor', () {
      final (h, spec) = coklu();
      final once = Map<String, double>.from(oku(h, spec));
      final kilit = once.keys.first;
      expect(HangarRules.kilitle(h, 'c', kilit, kilitli: true), isNull);
      expect(h.itemOf('c')!.kilitler, {kilit});
      expect(HangarRules.cevir(h, 'c', math.Random(9), tx()), isNull);
      final sonra = oku(h, spec);
      expect(
        sonra[kilit],
        closeTo(once[kilit]!, 1e-9),
        reason: 'kilit tutmadı',
      );
      for (final anahtar in once.keys.where((k) => k != kilit)) {
        expect(sonra[anahtar], isNot(closeTo(once[anahtar]!, 1e-9)));
      }
      // Açmak bedava ve geri alınabilir.
      expect(HangarRules.kilitle(h, 'c', kilit, kilitli: false), isNull);
      expect(h.itemOf('c')!.kilitler, isEmpty);
    });

    // KARAR 07.5 s2 · KARAR 07.8 s2
    test('bedel: stat başına × stat sayısı × (1 + kilit)', () {
      final (h, spec) = coklu();
      final cevirici = Malzeme.cevirmeFor(spec.tier);
      final n = oku(h, spec).length;
      int stok() => h.malzemeSayisi(cevirici);
      var once = stok();
      HangarRules.cevir(h, 'c', math.Random(1), tx());
      expect(once - stok(), Yukseltme.cevirmeBedeli(spec.tier, n));
      expect(
        Yukseltme.cevirmeBedeli(spec.tier, n),
        Yukseltme.statBasinaCevirici(spec.tier) * n,
      );
      // İki kilit üç taban.
      final anahtarlar = oku(h, spec).keys.toList();
      HangarRules.kilitle(h, 'c', anahtarlar[0], kilitli: true);
      HangarRules.kilitle(h, 'c', anahtarlar[1], kilitli: true);
      once = stok();
      HangarRules.cevir(h, 'c', math.Random(2), tx());
      expect(once - stok(), Yukseltme.cevirmeBedeli(spec.tier, n, kilit: 2));
      expect(
        Yukseltme.cevirmeBedeli(spec.tier, n, kilit: 2),
        3 * Yukseltme.cevirmeBedeli(spec.tier, n),
      );
    });

    // KARAR 07.5 s2
    test('HEPSİ kilitliyse çevrilmiyor ve bedel alınmıyor', () {
      final (h, spec) = coklu();
      final cevirici = Malzeme.cevirmeFor(spec.tier);
      for (final k in oku(h, spec).keys) {
        HangarRules.kilitle(h, 'c', k, kilitli: true);
      }
      final once = h.malzemeSayisi(cevirici);
      expect(
        HangarRules.cevir(h, 'c', math.Random(1), tx()),
        HangarError.wrongSlot,
      );
      expect(h.malzemeSayisi(cevirici), once);
    });

    // KARAR 07.5 s2
    test('OLMAYAN stat kilitlenmiyor', () {
      final h = hangarla();
      expect(
        HangarRules.kilitle(h, 'x', 'boyle_bir_stat_yok', kilitli: true),
        HangarError.wrongSlot,
      );
    });

    // KARAR 07.5 s2
    test('kilit KAYITTA kalıcı — JSON gidiş dönüş', () {
      final (h, spec) = coklu();
      final kilit = oku(h, spec).keys.first;
      HangarRules.kilitle(h, 'c', kilit, kilitli: true);
      final geri = ItemInstance.fromJson(h.itemOf('c')!.toJson());
      expect(geri.kilitler, {kilit});
      // Kilitsiz eşyanın kaydı eski biçimde: anahtar hiç yazılmıyor.
      expect(
        ItemInstance(
          instanceId: 'e',
          specId: spec.id,
        ).toJson().containsKey('kilitler'),
        isFalse,
      );
    });

    test('değer GERÇEKTEN oynuyor', () {
      final h = hangarla();
      final hedef = ilkStat(h);
      final zar = math.Random(7);
      final gorulen = <double>{};
      for (var i = 0; i < 30; i++) {
        HangarRules.cevir(h, 'x', zar, tx());
        gorulen.add(statlar(h)[hedef]!);
      }
      expect(gorulen.length, greaterThan(20), reason: 'çevirme donuk');
    });

    // KARAR 07.5 s2
    test('çevrilen değer ARALIĞIN İÇİNDE kalıyor — kayma yok', () {
      // **Kayma gerçek bir hataydı.** Taban, mevcut değerden geri çözülüyordu
      // (`değer ÷ beklenen rol`) ve rol saklanmadığı için ortalama
      // kullanılıyordu: her çevirme değeri sessizce ortalamaya doğru
      // kaydırıyordu. Yüz çevirmeden sonra aralığın uçlarına hiç
      // ulaşılamıyordu.
      //
      // Taban artık DOĞRUDAN hesaplanıyor ([ItemBudget.altStatTabani]) ve
      // aralık sabit kalıyor.
      final h = hangarla();
      final hedef = ilkStat(h);
      final taban = ItemBudget.altStatTabani(
        Catalogue.pl4,
        h.itemOf('x')!.level,
        HullClass.starter,
        hedef,
        'x',
      )!;
      final enAz = taban * TasarimGirdileri.kaliteAltSiniri;
      final zar = math.Random(19);
      var enDusuk = double.infinity;
      var enYuksek = 0.0;
      for (var i = 0; i < 200; i++) {
        HangarRules.cevir(h, 'x', zar, tx());
        final v = statlar(h)[hedef]!;
        expect(
          v,
          inInclusiveRange(enAz - 1e-9, taban + 1e-9),
          reason: '$i. çevirmede değer aralığın dışına çıktı',
        );
        enDusuk = math.min(enDusuk, v);
        enYuksek = math.max(enYuksek, v);
      }
      // İki uca da YAKLAŞIYOR: kayma olsaydı aralık ortada sıkışırdı.
      expect(enDusuk, lessThan(enAz + (taban - enAz) * 0.1));
      expect(enYuksek, greaterThan(taban - (taban - enAz) * 0.1));
    });

    test(
      'aralık SEVİYEYLE büyüyor — artı basmak alt statı da güçlendiriyor',
      () {
        // Adım TEK stata düşüyor (karar 07.6): üçüncü seviyenin sıçramasını
        // görmek için ilk adımın kimlikten seçtiği stata bakılıyor.
        const id = 'x';
        final havuz = Catalogue.pl4.subStatPool;
        final adet = math.min(
          ItemBudget.altStatSayisi(Catalogue.pl4.tier),
          havuz.length,
        );
        final statId = havuz[ItemBudget.guclenenIndeks(id, 1, adet)];
        double taban(int seviye) => ItemBudget.altStatTabani(
          Catalogue.pl4,
          seviye,
          HullClass.starter,
          statId,
          id,
        )!;
        expect(taban(3), greaterThan(taban(0)));
        expect(taban(ItemLevels.max), greaterThan(taban(3)));
        // Ölçüt FARK değil ORAN: bütçe üstel büyüyor, adım üçte bir biniyor.
        expect(
          taban(3) / taban(2),
          greaterThan(taban(2) / taban(1)),
          reason: 'üçüncü seviyedeki alt stat adımı görünmüyor',
        );
      },
    );
  });

  group('mağaza malzeme rafı', () {
    // KARAR 07.9 s1
    test('DÜŞÜK rank var, ÜST rank YOK', () {
      // Belge: "Üst rank malzeme mağazada olmuyor. O, zor içeriğin kendi
      // ödülü — ve üst rank eşyanın gerçek kapısı."
      expect(Catalogue.malzemeRafi, isNotEmpty);
      expect(
        Catalogue.malzemeRafi.length,
        lessThan(Malzeme.hepsi.length),
        reason: 'bütün merdiven satılıyor — kapı paraya açılmış',
      );
      expect(
        Catalogue.malzemeRafi.contains(Malzeme.forRank(ItemTier.values.last)),
        isFalse,
        reason: 'merdivenin tepesi mağazada',
      );
    });

    // KARAR 07.9 s1
    test('sınır RAFIN KENDİ tepesinden türüyor', () {
      final rafTepesi = Catalogue.rafta
          .map((s) => s.tier.index)
          .reduce((a, b) => a > b ? a : b);
      // Kural İKİ kısıt: tür YÜKSELTME ve rank rafın tepesinin altında.
      // İlk hâli yalnız ranka bakıyordu ve tür ekseni geldiğinde çeviriciyi
      // sessizce rafa aldı.
      for (final m in Malzeme.hepsi) {
        expect(
          Catalogue.malzemeRafi.contains(m),
          m.tur == MalzemeTuru.yukseltme && m.rank.index <= rafTepesi,
          reason: '${m.id} sınırın yanlış tarafında',
        );
      }
    });

    // KARAR 07.8 s2
    test('ÇEVİRİCİ hiçbir rankta SATILMIYOR', () {
      // Onaylanan tasarım: çevirici yalnız eşya parçalayarak geliyor.
      // Nadirliği tasarımın kendisi; mağazaya koymak onu paraya açardı ve
      // mükemmel roll kovalayan oyuncu fazla eşyasını eritmek yerine kredi
      // biriktirirdi.
      //
      // Bir ara satılıyordu: şemaya tür ekseni eklendiğinde raf filtresi
      // hâlâ yalnız RANKA bakıyordu. Bu test onu bir daha sessizce
      // açılamaz yapıyor.
      for (final m in Catalogue.malzemeRafi) {
        expect(
          m.tur,
          MalzemeTuru.yukseltme,
          reason: '${m.id} mağazada — çevirici satılıyor',
        );
      }
      for (final t in ItemTier.values) {
        expect(
          HangarRules.malzemeAl(
            Hangar(accountId: 'a', credits: 1000000000),
            Malzeme.cevirmeFor(t).id,
            1,
            tx(),
          ),
          HangarError.notPurchasable,
          reason: '${t.label} çeviricisi satın alınabiliyor',
        );
      }
    });

    test('fiyat TAM farm karşılığı — ne kâr ne zarar', () {
      for (final m in Catalogue.malzemeRafi) {
        expect(
          Catalogue.malzemeFiyati(m).amount,
          Ganimet.malzemeDegeriFor(m.rank.index).round(),
        );
        expect(Catalogue.malzemeFiyati(m).currency, Currency.credit);
      }
    });

    test('satın alma stoğa YAZIYOR', () {
      final h = Hangar(accountId: 'a', credits: 10000000);
      final m = Catalogue.malzemeRafi.first;
      expect(HangarRules.malzemeAl(h, m.id, 5, tx()), isNull);
      expect(h.malzemeSayisi(m), 5);
    });

    // KARAR 07.9 s1
    test('ÜST rank malzeme satın ALINAMIYOR — kapı budur', () {
      final h = Hangar(accountId: 'a', credits: 1000000000);
      final ust = Malzeme.forRank(ItemTier.values.last);
      expect(
        HangarRules.malzemeAl(h, ust.id, 1, tx()),
        HangarError.notPurchasable,
      );
      expect(h.malzemeSayisi(ust), 0);
    });

    test('parası yetmeyene VERİLMİYOR', () {
      final h = Hangar(accountId: 'a', credits: 0);
      final m = Catalogue.malzemeRafi.first;
      expect(
        HangarRules.malzemeAl(h, m.id, 1, tx()),
        HangarError.notEnoughCredits,
      );
      expect(h.malzemeSayisi(m), 0);
    });
  });
}
