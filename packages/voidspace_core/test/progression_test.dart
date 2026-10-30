@Tags(['yabanci-anahtar', 'aralik', 'turetme'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// İlerleme sisteminin sözleşmesi.
void main() {
  yukseltmeIsareti();
  var txCounter = 0;
  TxContext tx() => TxContext(id: 'tx${txCounter++}', atMillis: 1700000000000);

  Map<String, ItemInstance> inv(List<ItemInstance> items) => {
    for (final i in items) i.instanceId: i,
  };

  group('eşya bütçesi', () {
    test('lazer katsayısı TANIM GEREĞİ 1,00', () {
      // Bütün katsayılar lazere göre normalleniyor; okunuşu "bir roketatar
      // kaç lazere bedeldir".
      for (final hull in HullClass.all) {
        expect(
          ItemBudget.slotCoefficient(SlotType.laser, hull),
          closeTo(1.0, 1e-9),
          reason: '${hull.name} lazer katsayısı 1 değil',
        );
      }
    });

    test('YUVA SAYISI artınca yuva başına güç DÜŞER', () {
      // Aynı grup payı daha çok yuvaya bölününce yuva başına düşen güç azalır.
      // Bu olmadan gövde yükseltmek tek başına gücü katlardı: hem daha çok
      // yuva hem yuva başına aynı güç.
      final c = ItemBudget.slotCoefficient(
        SlotType.generator,
        HullClass.bastion,
      );
      final a = ItemBudget.slotCoefficient(
        SlotType.generator,
        HullClass.spectre,
      );
      expect(
        a,
        lessThan(c),
        reason: 'daha çok jeneratör yuvası olan gövdede katsayı düşmedi',
      );
    });

    test('katsayılar İLAN EDİLEN paydan türer, elle yazılmaz', () {
      // Yöntemin kendisi: pay / adet, sonra lazere göre normalle.
      final hull = HullClass.bastion;
      final laserRaw = ItemBudget.shares[SlotType.laser]! / hull.laserSlots;
      for (final type in SlotType.values) {
        // Droid gövdeye takılmıyor: payı TAM filoya bölünüyor (04.10).
        final adet = type == SlotType.droid
            ? TasarimGirdileri.droidFiloTavani
            : hull.slotCount(type);
        // Droid payı ikiye bölünüyor (05.4 s5): gövdeye kalan kısım burada,
        // donanıma giden kısım `droidDonanimKatsayisi`'nda.
        final pay = type == SlotType.droid
            ? ItemBudget.shares[type]! * (1 - Turetilenler.droidDonanimPayi)
            : ItemBudget.shares[type]!;
        final expected = (pay / adet) / laserRaw;
        expect(ItemBudget.slotCoefficient(type, hull), closeTo(expected, 1e-9));
      }
    });

    test('C0 lazer referans BÜTÇESİNİN ana stat PAYINI verir', () {
      // Bu test bir zamanlar `mainStatValue == reference` diyordu: bütçenin
      // TAMAMI ana stata gidiyordu, çünkü alt statlar hiçbir yerde
      // yazılmıyordu — bütçenin %30'u kimseye gitmiyordu.
      //
      // Alan 06 bölünmeyi ilan etti (%70 ana / %30 alt) ve özdeşlik kaydı:
      // C0 lazerin ana statı artık 200 değil 140.
      expect(
        ItemBudget.mainStatValue(Catalogue.pl1, 0, HullClass.bastion),
        closeTo(ItemBudget.reference * TasarimGirdileri.anaStatPayi, 0.001),
      );

      // Ve kalan pay GERÇEKTEN alt statlara gidiyor — kaybolmuyor.
      final alt = ItemBudget.subStatValues(
        Catalogue.pl1,
        0,
        HullClass.bastion,
        'test-örnek',
      );
      expect(alt, isNotEmpty, reason: 'alt stat payı kimseye gitmiyor');
    });

    test('ALAN 08e BORÇ: bütçe çapası bölünmeden önceye göre konmuş', () {
      // Alan 08'in belgesi `butceCapasi = 200`ü "C0 lazerin TABAN HASARI"
      // diye tanımlıyor. Bölünme geldikten sonra bu artık doğru değil: 200
      // bütçe, 140 taban hasar veriyor. Belgenin tanımının geçerli kalması
      // için çapa 200 ÷ 0,70 = 285,7 olmalı.
      //
      // Bu alan 08'in kararı ve burada YAPILMIYOR — `reference` onun girdisi.
      // Test borcu görünür tutuyor: 08 yazıldığında ya çapa düzeltilecek ya da
      // belgedeki tanım değişecek, ama ikisi de sessizce olmayacak.
      //
      // Ölçülen bedel: aynı donanımda DPS 1.909 → 1.520 (%20 düşüş). Sebep
      // saldırının bütçe çarpanında KARESEL olması — tabandan yüzdeye para
      // taşımak hem tabanı hem çarpanı küçültüyor.
      expect(
        ItemBudget.reference,
        200,
        reason:
            'çapa değişmiş — alan 08 borcu kapatıyorsa bu testi de güncelle',
      );
      expect(
        ItemBudget.reference * TasarimGirdileri.anaStatPayi,
        closeTo(140, 0.001),
        reason: 'C0 taban hasarı 200 değil 140 — 08 bunu çözecek',
      );
    });
  });

  group('seviye', () {
    test('on beş seviye üç kademeli artış — TOPLAMSAL, kümülatif 2,50×', () {
      // Alan 07'nin kararı. Test bu satırlar yazıldığında 4,170 bekliyordu —
      // yani belgenin ilan ettiği 2,50 tavanı değil, kodun bileşik hesabını
      // ölçüyordu. Alan 06 çelişkiyi 07'ye devretmiş, 07 toplamsalı seçti.
      expect(ItemLevels.multiplier(0), 1.0);
      expect(ItemLevels.multiplier(5), closeTo(1.40, 1e-9));
      expect(ItemLevels.multiplier(10), closeTo(1.90, 1e-9));
      expect(ItemLevels.multiplier(15), closeTo(2.50, 1e-9));
      // Ve gerçekten TOPLAM: adımların toplamı, çarpımı değil.
      var toplam = 0.0;
      for (var l = 1; l <= ItemLevels.max; l++) {
        toplam += ItemLevels.stepFor(l);
      }
      expect(ItemLevels.multiplier(ItemLevels.max), closeTo(1 + toplam, 1e-9));
    });

    test('maliyet ÜSTEL ama değer bozulması bandın içinde', () {
      final first = ItemLevels.upgradeCost(0, ItemTier.cI);
      final last = ItemLevels.upgradeCost(14, ItemTier.cI);
      expect(last, greaterThan(first * 10));
      // Asıl ölçü maliyetin kendisi değil GÜÇ BAŞINA maliyet: eski eğri
      // (b = 1,350) toplamsal kazançla son seviyeyi 44,5 kat kötü değer
      // yapıyordu, yani +11'den sonrası ölü sistemdi.
      expect(ItemLevels.degerBozulmasi, inInclusiveRange(8, 16));
    });

    test('alt stat her ÜÇ seviyede bir güçlenir — beş kez', () {
      final steps = [
        for (var l = 1; l <= ItemLevels.max; l++)
          if (ItemLevels.isSubStatStep(l)) l,
      ];
      expect(steps, [3, 6, 9, 12, 15]);
    });

    test('son seviyenin ötesine yükseltme YOK', () {
      expect(ItemLevels.upgradeCost(ItemLevels.max, ItemTier.aI), 0);
    });
  });

  group('donatım', () {
    test('boş donatım gövdenin TABAN statlarını verir', () {
      final stats = LoadoutResolver.resolve(
        Loadout(hullId: HullClass.bastion.id),
        const {},
        Catalogue.byId,
      );
      expect(stats.maxHull, HullClass.bastion.baseHull);
      expect(stats.maxShield, HullClass.bastion.baseShield);
      expect(stats.speed, HullClass.bastion.baseSpeed);
      // Lazer yuvası boş: gemi ateş edemez.
      expect(stats.laser.damage, 0);
    });

    test('takılan lazer hasarı GERÇEKTEN artırır', () {
      final item = const ItemInstance(instanceId: 'i1', specId: 'pl4');
      final loadout = Loadout(hullId: HullClass.bastion.id)
        ..equip(const SlotRef(SlotType.laser, 0), 'i1');

      final stats = LoadoutResolver.resolve(
        loadout,
        inv([item]),
        Catalogue.byId,
      );
      expect(stats.laser.damage, greaterThan(0));
    });

    test('YANLIŞ yuvadaki eşya SAYILMAZ', () {
      // Sunucu yuva-tür uyumunu doğrulamak zorunda: uydurma bir yerleşim,
      // bütçe hesabında olmayan bedava güç demekti.
      final item = const ItemInstance(instanceId: 'i1', specId: 'pl4');
      final loadout = Loadout(hullId: HullClass.bastion.id)
        // Lazeri CPU yuvasına koymayı dene.
        ..equip(const SlotRef(SlotType.cpu, 0), 'i1');

      final stats = LoadoutResolver.resolve(
        loadout,
        inv([item]),
        Catalogue.byId,
      );
      expect(stats.laser.damage, 0, reason: 'yanlış yuvadaki eşya sayıldı');
    });

    test('OLMAYAN yuvadaki eşya SAYILMAZ', () {
      final item = const ItemInstance(instanceId: 'i1', specId: 'pl4');
      // Bastion'da 5 lazer yuvası var; 9'uncu yok.
      final loadout = Loadout(hullId: HullClass.bastion.id)
        ..equip(const SlotRef(SlotType.laser, 9), 'i1');

      final stats = LoadoutResolver.resolve(
        loadout,
        inv([item]),
        Catalogue.byId,
      );
      expect(stats.laser.damage, 0, reason: 'olmayan yuva güç verdi');
    });

    test('jeneratör İKİLEMİ: kalkan mı hız mı — aynı yuva, farklı sonuç', () {
      // Donatımın en iyi kararı: ekleme değil TAKAS.
      Loadout with_(String id) =>
          Loadout(hullId: HullClass.bastion.id)
            ..equip(const SlotRef(SlotType.generator, 0), id);

      final shieldStats = LoadoutResolver.resolve(
        with_('s'),
        inv([const ItemInstance(instanceId: 's', specId: 'df3')]),
        Catalogue.byId,
      );
      final speedStats = LoadoutResolver.resolve(
        with_('e'),
        inv([const ItemInstance(instanceId: 'e', specId: 'th3')]),
        Catalogue.byId,
      );

      expect(shieldStats.maxShield, greaterThan(speedStats.maxShield));
      expect(speedStats.speed, greaterThan(shieldStats.speed));
    });
  });

  group('kapsam', () {
    test('stat kimliği TEK BAŞINA yetmez — kapsam anahtarın parçası', () {
      // Çift sayım tuzağına karşı tek savunma.
      final v = StatVector()
        ..add('hasar_artisi', StatScope.gemi, 0.15)
        ..add('hasar_artisi', StatScope.droid, 0.40);

      expect(v.get('hasar_artisi', StatScope.gemi), 0.15);
      expect(v.get('hasar_artisi', StatScope.droid), 0.40);
    });

    test('gemi yuvasındaki eşya GEMİ kapsamına yazar', () {
      final loadout = Loadout(hullId: HullClass.bastion.id)
        ..equip(const SlotRef(SlotType.laser, 0), 'i1');
      final v = LoadoutResolver.vectorOf(
        loadout,
        inv([const ItemInstance(instanceId: 'i1', specId: 'pl4')]),
        Catalogue.byId,
      );
      expect(v.get('taban_hasar', StatScope.gemi), greaterThan(0));
      expect(v.get('taban_hasar', StatScope.droid), 0);
    });
  });

  group('hangar kuralları', () {
    Hangar fresh() => Hangar(accountId: 'a');

    test('yeni hesap BAŞLANGIÇ gemisine ve krediye sahip', () {
      final h = fresh();
      expect(h.owns(HullClass.starter.id), isTrue);
      expect(h.credits, Hangar.startingCredits);
    });

    test('SIFIRDAN hangar TAKILI bir lazerle gelir', () {
      // Boş yuva "ateş edemeyen gemi" demek; ateş edemeyen oyuncu kredi
      // kazanamaz, kredi kazanamayan lazer alamaz. Kilitli başlangıç.
      final h = Hangar.fresh('a', tx());
      final stats = LoadoutResolver.resolve(
        h.activeLoadout,
        h.inventory,
        Catalogue.byId,
      );
      expect(
        stats.laser.damage,
        greaterThan(0),
        reason: 'yeni oyuncu ateş edemiyor',
      );
    });

    test('satın alma krediyi DÜŞER ve eşyayı verir', () {
      final h = fresh();
      final before = h.credits;
      final (item, error) = HangarRules.buyItem(h, 'pl1', 'x1', tx());
      expect(error, isNull);
      expect(item, isNotNull);
      expect(h.credits, before - Catalogue.priceOf(Catalogue.pl1).amount);
      expect(h.itemOf('x1'), isNotNull);
    });

    test('parası yetmeyen SATIN ALAMAZ', () {
      final h = Hangar(accountId: 'a', credits: 10);
      final (item, error) = HangarRules.buyItem(h, 'pl4', 'x1', tx());
      expect(item, isNull);
      expect(error, HangarError.notEnoughCredits);
      expect(h.credits, 10, reason: 'para gitti ama eşya gelmedi');
    });

    test('SAHİP OLMADIĞI eşyayı takamaz', () {
      final h = fresh();
      expect(
        HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'yok'),
        HangarError.notOwned,
      );
    });

    test('AYNI eşya iki yuvada olamaz', () {
      // Olsaydı tek lazeri bütün yuvalara takmak bedava güç olurdu.
      final h = fresh();
      HangarRules.buyItem(h, 'pl1', 'x1', tx());
      HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'x1');
      HangarRules.equip(h, const SlotRef(SlotType.laser, 1), 'x1');

      final slots = h.activeLoadout.slots.values.where((v) => v == 'x1');
      expect(slots, hasLength(1), reason: 'eşya iki yuvada birden');
    });

    test('yükseltme krediyi düşer, seviyeyi artırır — BAŞARISIZLIK YOK', () {
      final h = Hangar(accountId: 'a', credits: 1000000);
      // C-II eşya: artı basma ikinci rankın eşyasıyla açılıyor (10.7).
      HangarRules.buyItem(h, 'pl3', 'x1', tx());
      // Kural "rastgele kırılma yok" — "kaynak istemiyor" değil. Malzeme bir
      // KAPI (alan 07) ve kapıyı açmak testin konusu değil.
      h.malzemeEkle(Malzeme.forRank(Catalogue.pl3.tier), 100000);
      for (var i = 0; i < 5; i++) {
        expect(HangarRules.upgrade(h, 'x1', tx()), isNull);
      }
      expect(h.itemOf('x1')!.level, 5);
    });

    test('sahip olunmayan gemiye GEÇİLEMEZ', () {
      final h = fresh();
      expect(h.selectHull(HullClass.spectre.id), isFalse);
      expect(h.activeHullId, HullClass.starter.id);
    });

    test('gemi alınca ona geçilebilir', () {
      final h = Hangar(accountId: 'a', credits: 5000000);
      expect(HangarRules.buyHull(h, HullClass.vanguard.id, tx()), isNull);
      expect(h.selectHull(HullClass.vanguard.id), isTrue);
      expect(h.activeHull.laserSlots, HullClass.vanguard.laserSlots);
    });

    test('aynı gemi İKİ KEZ alınamaz', () {
      final h = Hangar(accountId: 'a', credits: 5000000);
      HangarRules.buyHull(h, HullClass.vanguard.id, tx());
      final before = h.credits;
      expect(
        HangarRules.buyHull(h, HullClass.vanguard.id, tx()),
        HangarError.alreadyOwned,
      );
      expect(h.credits, before, reason: 'ikinci alımda para gitti');
    });

    test('her geminin KENDİ donatımı var', () {
      // Gemi değiştirince donatım kaybolmamalı: yeniden takmak iş olurdu.
      final h = Hangar(accountId: 'a', credits: 5000000);
      HangarRules.buyItem(h, 'pl1', 'x1', tx());
      HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'x1');

      HangarRules.buyHull(h, HullClass.vanguard.id, tx());
      h.selectHull(HullClass.vanguard.id);
      expect(h.activeLoadout.slots, isEmpty, reason: 'donatım taşındı');

      h.selectHull(HullClass.starter.id);
      expect(h.activeLoadout.itemAt(const SlotRef(SlotType.laser, 0)), 'x1');
    });

    test('hangar diske yazılıp geri okunur', () {
      final h = Hangar(accountId: 'a', credits: 5000000);
      HangarRules.buyItem(h, 'pl4', 'x1', tx());
      h.malzemeEkle(Malzeme.forRank(Catalogue.pl4.tier), 100000);
      HangarRules.upgrade(h, 'x1', tx());
      HangarRules.equip(h, const SlotRef(SlotType.laser, 2), 'x1');
      HangarRules.buyHull(h, HullClass.vanguard.id, tx());

      final back = Hangar.fromJson(h.toJson());
      expect(back.credits, h.credits);
      expect(back.owns(HullClass.vanguard.id), isTrue);
      expect(back.itemOf('x1')!.level, 1);
      expect(back.activeLoadout.itemAt(const SlotRef(SlotType.laser, 2)), 'x1');
    });
  });

  group('birim sözleşmesi · alan 02', () {
    /// Bir gövdeye tek bir DF-1 takıp kalkan artışını ve bütçesini ölçer.
    ({double artis, double puan}) kalkanOlc(HullClass hull) {
      final loadout = Loadout(hullId: hull.id)
        ..equip(const SlotRef(SlotType.generator, 0), 'g');
      final stats = LoadoutResolver.resolve(loadout, {
        'g': const ItemInstance(instanceId: 'g', specId: 'df1'),
      }, Catalogue.byId);
      return (
        artis: stats.maxShield - hull.baseShield,
        puan: ItemBudget.budgetFor(Catalogue.byId['df1']!, 0, hull),
      );
    }

    test('bir bütçe puanı HER GÖVDEDE aynı kalkanı alıyor', () {
      // Asıl kusur buydu, gösterge değil. Kalkan `taban × (1 + s)` iken aynı
      // DF-1 Bastion'da puan başına 4,00, Spectre'de 7,50 kalkan veriyordu:
      // daha AZ bütçeyle daha ÇOK güç. Bütçenin tek sözü bir puanın hangi
      // stata konursa konsun aynı marjinal gücü almasıydı.
      final oranlar = [
        for (final hull in HullClass.all)
          () {
            final o = kalkanOlc(hull);
            return o.artis / o.puan;
          }(),
      ];
      for (final oran in oranlar) {
        expect(
          oran,
          closeTo(oranlar.first, 1e-9),
          reason: 'kalkan gövde büyüklüğüne bağlı — oran biçimine dönülmüş',
        );
      }
    });

    test('kalkan ve gövde canı AYNI birimde, AYNI fiyatta', () {
      // İkisi de havuzun kendisi: bir puan havuz, bir puan havuzdur.
      // Ayrıştıklarında biri ölü stata dönüyordu — `govde_cani` toplamsal
      // tüketiliyor ama oran fiyatıyla satılıyordu, yani bir bütçe puanı ona
      // 0,1 can alıyordu.
      expect(Stats.maxShield.percent, isFalse);
      expect(Stats.maxHull.percent, isFalse);
      expect(
        ItemBudget.birimFiyati('kalkan'),
        ItemBudget.birimFiyati('govde_cani'),
        reason: 'iki havuz statı farklı fiyatlanmış',
      );
    });

    test('mağaza kartı GERÇEK sayı gösteriyor — "+0" değil', () {
      // Mağazadaki üç jeneratörün üçü de "+0 KALKAN" yazıyordu: değer bir
      // kesirdi (0,105) ve kart onu mutlak sayı diye yuvarlıyordu.
      for (final id in ['df1', 'df3', 'df5']) {
        final spec = Catalogue.byId[id];
        if (spec == null) continue;
        final deger = ItemBudget.mainStatValue(spec, 0, HullClass.bastion);
        expect(
          deger.round(),
          greaterThan(0),
          reason: '$id kartı hâlâ sıfır gösteriyor',
        );
      }
    });

    test('gövde canı ÖLÜ STAT değil — bir puan görünür can alıyor', () {
      final canPerPuan = ItemBudget.birimFiyati('govde_cani');
      expect(
        200 * canPerPuan,
        greaterThan(100),
        reason: 'bir eşyalık bütçe 100 candan az alıyor — ölü stat',
      );
    });

    test('HIZ oran olarak KALIYOR — havuz değil', () {
      // Hız bir havuz değil bir hız; sözleşmesi `additive` + `percent: true`.
      // Havuz statlarını mutlağa çevirmek onu da çevirmek anlamına gelmiyor.
      expect(Stats.speed.percent, isTrue);
      expect(Stats.speed.layer, StatLayer.additive);
    });
  });

  group('stat değeri · alan 03', () {
    test('fiyatlar ZİNCİRDEN türüyor — alan 03\'ün girdisi yok', () {
      // Karar 03.1: saldırı fiyatları elle girdiyken zincirin söylediğinden
      // 2,5–3,3 kat ucuzdu. Artık on dört statın on dördü türetilen.
      expect(TasarimGirdileri.alanin(3), isEmpty);
      expect(ItemBudget.fiyatlar, hasLength(Stats.all.length));
      for (final stat in Stats.all) {
        expect(
          ItemBudget.birimFiyati(stat.id),
          greaterThan(0),
          reason: '${stat.id} fiyatsız',
        );
      }
      expect(
        ItemBudget.birimFiyati('kalkan'),
        closeTo(Turetilenler.savunmaCapasi, 1e-9),
        reason: 'kalkan fiyatı kurdan türemiyor',
      );
      expect(
        ItemBudget.birimFiyati('govde_cani'),
        closeTo(Turetilenler.savunmaCapasi, 1e-9),
      );
    });

    test('hasar artışı = atış hızı — zincirin kanaryası', () {
      // İkisi L1'de aynı tabanı çarpıyor; eşitlik bir tasarım kararı değil,
      // zincirin sonucu. Bozulursa sorun bu tabloda değil alan 01'de.
      expect(
        ItemBudget.birimFiyati('hasar_artisi'),
        closeTo(ItemBudget.birimFiyati('atis_hizi'), 1e-6),
      );
      // Zincirin türevi: bir yüzde puanının fiyatı fiyat referansının
      // DPS'ine bağlı (03.2). Referans lazer 200 iken 0,001 çıkıyordu
      // (yaylım 1.000); lazer katalogdaki C-I olunca (04.5 s2) sayı değişti.
      // Ölçüm noktası da değişti: çıplak gövde değil DOLU referans (03.2 s2,
      // borç defteri B22), yani yüzde statlar bir kat daha pahalı.
      // KARAR 03.2 s2
      expect(
        ItemBudget.birimFiyati('hasar_artisi'),
        closeTo(
          Turetilenler.saldiriPuaniDps /
              ItemBudget.olcumDps(FiyatCozumu.referans),
          1e-9,
        ),
      );
      expect(
        ItemBudget.birimFiyati('hasar_artisi'),
        lessThan(
          Turetilenler.saldiriPuaniDps /
              CombatGlossary.expectedDps(ShipStats.bastion),
        ),
        reason: 'yüzde statlar hâlâ çıplak referansın ucuz fiyatında',
      );
      // Kritik şansı kritik hasarından dört kat değerli: k = 0,25, d = 2.
      expect(
        ItemBudget.birimFiyati('kritik_hasari') /
            ItemBudget.birimFiyati('kritik_sansi'),
        closeTo(4, 1e-3),
      );
    });

    test('taban hasar ÇAPA: bir puan bir hasar', () {
      // Bütün tablo bu bire bir orana göre ölçekleniyor. Değişirse tablo
      // değil ÖLÇEK değişir — ve o zaman her eşyanın gücü kayar.
      expect(ItemBudget.birimFiyati('taban_hasar'), 1.0);
    });

    test('her fiyatlı statın kütüphanede karşılığı var', () {
      for (final id in ItemBudget.fiyatlar.keys) {
        expect(
          Stats.byId(id),
          isNotNull,
          reason: '$id fiyatlanmış ama kütüphanede yok',
        );
      }
    });

    test('MENZİL sistem kanalında — ∂DPS/∂menzil = 0', () {
      // Saldırı kanalında fiyatlanırsa bedava güç gibi görünür: menzil hasarı
      // büyütmüyor, hedefte KALMA süresini uzatıyor.
      expect(Stats.range.channel, StatChannel.system);
      expect(Stats.range.percent, isTrue);
    });

    test('savunma statları AYNI kanalda ve havuz olanlar aynı fiyatta', () {
      expect(Stats.maxShield.channel, StatChannel.defence);
      expect(Stats.maxHull.channel, StatChannel.defence);
      expect(
        ItemBudget.birimFiyati('kalkan'),
        ItemBudget.birimFiyati('govde_cani'),
      );
    });
  });

  group('gemi ve yuvalar · alan 04', () {
    test('çapa statları TEPE TABLODAN geliyor', () {
      expect(
        HullClass.bastion.baseHull,
        closeTo(
          ReferansCozumu.govdeCapasi * Turetilenler.govdeKademeCarpanlari[0],
          1e-9,
        ),
      );
      expect(HullClass.bastion.baseShield, TasarimGirdileri.kalkanCapasi);
      expect(HullClass.bastion.baseSpeed, TasarimGirdileri.hizCapasi);
    });

    test('K sabitleri ÇÖZÜLDÜ — savunma katmanı artık ölü değil', () {
      // Alan 04 gelene kadar `Turetilenler.kZirh` `null`du ve `armorReduction`
      // her zaman 0 dönüyordu: L4 savunma katmanı tanımlıydı ama ÖLÜYDÜ.
      // Referans zırh ilan edilince eğri çözüldü.
      //
      // Bu bir denge değişikliği DEĞİL: bugün hiçbir varlığın zırhı yok, yani
      // ölçülen hasar aynı. Değişen şey, artık zırh VERİLEBİLİR olması.
      final zirhli = ShipStats.bastion.copyWith(
        armor: TasarimGirdileri.zirhCapasi,
      );
      expect(
        zirhli.armorReduction,
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-9),
        reason: 'referans zırh ilan edilen azaltmayı üretmiyor',
      );
      // Ve referans build ARTIK zırh taşıyor: eğri çözüldüğü için taşıyabilir.
      expect(
        ShipStats.bastion.armorReduction,
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-9),
      );
      // Zırhsız bir gemide hâlâ sıfır — eğri açıldı diye bedava azaltma yok.
      expect(ShipStats.bastion.copyWith(armor: 0).armorReduction, 0);
    });

    test('yuva merdiveni: ilk üçü SANATTAN, sonrası artıştan', () {
      // 12 · 16 · 18 çizime kilitli: lazer yuvası namlu sayısı demek. Droid
      // burada YOK: filo gövdeye değil oyuncuya bağlı (04.10), gövdenin
      // droid yuvası sıfır.
      final gercek = [for (final h in HullClass.cizilenler) h.totalSlots];
      expect(gercek, [12, 16, 18]);
      expect(HullClass.sanatYuvalari, [12, 16, 18]);
      for (var k = 0; k < HullClass.cizilenler.length; k++) {
        expect(HullClass.yuvaSayisi(k), gercek[k]);
        expect(HullClass.all[k].slotCount(SlotType.droid), 0);
      }
      for (var k = 3; k < TasarimGirdileri.govdeKademeSayisi; k++) {
        expect(
          HullClass.yuvaSayisi(k),
          18 + (k - 2) * TasarimGirdileri.yuvaArtisi,
          reason: 'kademe $k merdivenden çıkmış',
        );
      }
    });

    test('kademe sayısı BELLİ ama merdiven alan 08i bekliyor', () {
      // Kaç kademe olacağı alan 04'ün kararı ve verildi. Her kademenin ne
      // kadar GÜÇLÜ olduğu değil: kademe çarpanı rank merdivenine bağlı ve
      // rank BÜYÜME katmanında, gövde SAVAŞ katmanında.
      //
      // Boşluk bir eksiklik değil, katman yönünün doğru sonucu. Tahmini bir
      // merdivenle beş gövde uydurmak, alan 08 geldiğinde kimsenin geri dönüp
      // düzeltmediği beş gövde üretirdi.
      // Alan 08 merdiveni ÇÖZDÜ: kalan kademeler artık uydurulmuyor,
      // çapa × kademe çarpanı ile türetiliyor.
      expect(HullClass.hedefKademeSayisi, TasarimGirdileri.govdeKademeSayisi);
      expect(HullClass.cizilenler, hasLength(3), reason: 'çizimi olan üç gemi');
      expect(HullClass.all, hasLength(TasarimGirdileri.govdeKademeSayisi));
      expect(BekleyenGirdiler.bekleyenler, isEmpty);
      expect(
        Turetilenler.govdeKademeCarpanlari,
        hasLength(TasarimGirdileri.govdeKademeSayisi),
      );
    });

    test('aralık dışı kademe reddediliyor', () {
      expect(() => HullClass.yuvaSayisi(-1), throwsArgumentError);
      expect(
        () => HullClass.yuvaSayisi(TasarimGirdileri.govdeKademeSayisi),
        throwsArgumentError,
      );
    });
  });

  group('alt statlar · alan 05 + 06', () {
    const spec = Catalogue.pl4; // A tier, havuzu üç stat
    final hull = HullClass.bastion;

    test('alt statlar GERÇEKTEN doğuyor — artık ölü yarı sistem değil', () {
      // `ItemInstance.subStats` okunuyor ve serileştiriliyordu ama hiçbir
      // yerde YAZILMIYORDU: bütçenin %30'u kimseye gitmiyordu.
      final alt = ItemBudget.subStatValues(spec, 0, hull, 'örnek-1');
      expect(alt, isNotEmpty);
      expect(alt.keys, everyElement(isIn(spec.subStatPool)));
      for (final deger in alt.values) {
        expect(deger, greaterThan(0), reason: 'sıfır değerli alt stat');
      }
    });

    test('roll KİMLİKTEN türüyor — aynı eşya her yüklemede aynı', () {
      // Rastgelelik saklanmıyor. `Random` olsaydı oyuncunun gemisi her
      // girişte başka bir gemi olurdu; saklanan bir tohum olsaydı kaydedilmiş
      // hangarların göçürülmesi gerekirdi.
      final a = ItemBudget.subStatValues(spec, 0, hull, 'aynı');
      final b = ItemBudget.subStatValues(spec, 0, hull, 'aynı');
      expect(a, b, reason: 'aynı kimlik farklı roll üretti');

      final c = ItemBudget.subStatValues(spec, 0, hull, 'başka');
      expect(
        a.values.toList(),
        isNot(c.values.toList()),
        reason: 'farklı kimlikler aynı rolü üretti — karma çalışmıyor',
      );
    });

    test('kalite rolü BANDIN içinde — taban ile 1,00 arası', () {
      // Bandı doğrudan okuyamıyoruz (roll içeride); tersine çeviriyoruz.
      final tam = ItemBudget.budgetFor(spec, 0, hull);
      final pay = tam * (1 - TasarimGirdileri.anaStatPayi);
      final adet = ItemBudget.altStatSayisi(spec.tier);
      for (var i = 0; i < 40; i++) {
        final alt = ItemBudget.subStatValues(spec, 0, hull, 'kimlik-$i');
        alt.forEach((statId, deger) {
          final birim = ItemBudget.birimFiyati(statId);
          final roll = deger / (pay / adet * birim);
          expect(
            roll,
            inInclusiveRange(TasarimGirdileri.kaliteAltSiniri - 1e-9, 1 + 1e-9),
            reason: '$statId rolü bant dışına çıktı: $roll',
          );
        });
      }
    });

    test('alt stat sayısı TIER ile artıyor', () {
      expect(ItemBudget.altStatSayisi(ItemTier.cI), 1);
      expect(ItemBudget.altStatSayisi(ItemTier.bI), 2);
      expect(ItemBudget.altStatSayisi(ItemTier.aI), 3);
      expect(ItemBudget.altStatSayisi(ItemTier.sI), 4);
      expect(ItemBudget.altStatSayisi(ItemTier.ssI), 5);
      expect(ItemBudget.altStatSayisi(ItemTier.sssIII), 6);
      // Kapak taşları ailelerin bir adım üstünde (karar 06.9).
      expect(ItemBudget.altStatSayisi(ItemTier.kirmizi), 7);
      expect(ItemBudget.altStatSayisi(ItemTier.parlayanPembe), 7);
      expect(ItemBudget.altStatTavani, 7);
    });

    test('kalite bandı rankla daralıyor, garantili alt stat artıyor', () {
      expect(
        ItemBudget.kaliteAltSiniriFor(ItemTier.cI),
        TasarimGirdileri.kaliteAltSiniri,
      );
      expect(
        ItemBudget.kaliteAltSiniriFor(ItemTier.sIII),
        TasarimGirdileri.kaliteAltSiniri,
      );
      expect(
        ItemBudget.kaliteAltSiniriFor(ItemTier.ssI),
        TasarimGirdileri.kaliteAltSiniriSS,
      );
      expect(
        ItemBudget.kaliteAltSiniriFor(ItemTier.sssIII),
        TasarimGirdileri.kaliteAltSiniriSS,
      );
      expect(
        ItemBudget.kaliteAltSiniriFor(ItemTier.kirmizi),
        TasarimGirdileri.kaliteAltSiniriRenk,
      );
      expect(ItemBudget.garantiliFor(ItemTier.sIII), 0);
      expect(
        ItemBudget.garantiliFor(ItemTier.ssI),
        TasarimGirdileri.garantiliAltStatSS,
      );
      expect(
        ItemBudget.garantiliFor(ItemTier.parlayanPembe),
        TasarimGirdileri.garantiliAltStatRenk,
      );
      // Bantlar yukarı çıktıkça daralıyor; genişleyen bant tavanı büyütürdü.
      expect(
        TasarimGirdileri.kaliteAltSiniriSS,
        greaterThan(TasarimGirdileri.kaliteAltSiniri),
      );
      expect(
        TasarimGirdileri.kaliteAltSiniriRenk,
        greaterThan(TasarimGirdileri.kaliteAltSiniriSS),
      );
    });

    test('garantili alt statlar MÜKEMMEL geliyor — rol 1,0', () {
      final pembe = Catalogue.items.firstWhere(
        (s) => s.tier == ItemTier.parlayanPembe && s.slot == SlotType.laser,
      );
      final garanti = ItemBudget.garantiliFor(ItemTier.parlayanPembe);
      for (var i = 0; i < 20; i++) {
        final alt = ItemBudget.subStatValues(pembe, 0, hull, 'kimlik-$i');
        final havuz = pembe.subStatPool;
        for (var g = 0; g < garanti; g++) {
          final taban = ItemBudget.altStatTabani(
            pembe,
            0,
            hull,
            havuz[g],
            'kimlik-$i',
          )!;
          expect(
            alt[havuz[g]],
            closeTo(taban, 1e-6),
            reason: 'garantili stat rol 1,0 değil',
          );
        }
      }
    });

    test('SEVİYE alt statları güçlendiriyor — üçün katlarında', () {
      // `ItemLevels.isSubStatStep` bugüne kadar üretim kodunda hiç
      // çağrılmıyordu. Artık adım sayısı güçlenmeyi belirliyor.
      final l0 = ItemBudget.subStatValues(spec, 0, hull, 'x');
      final l3 = ItemBudget.subStatValues(spec, 3, hull, 'x');
      final l15 = ItemBudget.subStatValues(spec, 15, hull, 'x');
      final stat = l0.keys.first;
      expect(l3[stat]!, greaterThan(l0[stat]!));
      expect(l15[stat]!, greaterThan(l3[stat]!));
      expect(ItemLevels.isSubStatStep(3), isTrue);
      expect(ItemLevels.isSubStatStep(4), isFalse);
    });

    test('SAKLANAN ROL türetileni EZİYOR — çevirmenin yeri', () {
      // Rol saklanıyor, değer değil (07.5): tam rol tabanın kendisini verir,
      // taban da rankı, gövde katsayısını ve artı adımını taşır.
      final loadout = Loadout(hullId: hull.id)
        ..equip(const SlotRef(SlotType.laser, 0), 'i');
      const item = ItemInstance(
        instanceId: 'i',
        specId: 'pl4',
        altStatRolleri: {'hasar_artisi': 1.0},
      );
      final ezilmis = LoadoutResolver.resolve(loadout, {
        'i': item,
      }, Catalogue.byId);
      final taban = ItemBudget.altStatTabani(
        Catalogue.pl4,
        0,
        hull,
        'hasar_artisi',
        'i',
      )!;
      expect(ezilmis.damageBonus, closeTo(taban, 1e-9));
      // Yarım rol yarım değer; türetilen roll (kimlikten) devrede değil.
      final yarim = LoadoutResolver.resolve(loadout, {
        'i': item.copyWith(altStatRolleri: {'hasar_artisi': 0.5}),
      }, Catalogue.byId);
      expect(yarim.damageBonus, closeTo(taban * 0.5, 1e-9));
    });

    test('KAPSAM kuralı: çift sayım İMKÂNSIZ', () {
      // Alan 05'in çekirdeği. Anahtar `stat@kapsam` olduğu için, aynı statı
      // iki kapsama yazmak toplamıyor — ayrı kutulara koyuyor.
      final v = StatVector()
        ..add('taban_hasar', StatScope.gemi, 100)
        ..add('taban_hasar', StatScope.droid, 100);
      expect(v.get('taban_hasar', StatScope.gemi), 100);
      expect(v.get('taban_hasar', StatScope.droid), 100);
      expect(
        StatVector.key('taban_hasar', StatScope.gemi),
        isNot(StatVector.key('taban_hasar', StatScope.droid)),
      );
    });
  });

  group('güç bütçesi · alan 08', () {
    test('paylar TEPE TABLODAN, katsayı onlardan TÜRÜYOR', () {
      expect(ItemBudget.shares[SlotType.laser], TasarimGirdileri.payLazer);
      expect(ItemBudget.hullShare, TasarimGirdileri.payGovde);
      expect(ItemBudget.reference, TasarimGirdileri.butceCapasi);
      // Lazer katsayısı ölçeğin çapası: tam olarak 1,00.
      expect(
        ItemBudget.slotCoefficient(SlotType.laser, HullClass.bastion),
        closeTo(1.0, 1e-12),
      );
    });

    test('GÖVDE MERDİVENİ çözüldü — bekleyen sabit kalmadı', () {
      final merdiven = Turetilenler.govdeKademeCarpanlari;
      expect(merdiven, hasLength(TasarimGirdileri.govdeKademeSayisi));
      expect(merdiven.first, closeTo(1.0, 1e-12), reason: 'çapa 1,00 değil');
      // Her kademe bir öncekinden GÜÇLÜ ve oran sabit: bölme uyumlu.
      //
      // Sıçrama `rankArtisi` DEĞİL, onun kademe başına düşen rank sayısı
      // kuvveti — KADEME NORMALİZASYONU tam olarak bu. Rank ile kademe eşitken
      // (beş/beş) üs 1 oluyordu ve ikisi ayırt edilemiyordu; yirmi rank sekiz
      // kademeye bölününce her gövde 2,5 rank kapsıyor ve sıçrama
      // 1,442^2,5 ≈ 2,497 oluyor.
      final rankBasina = Turetilenler.rankSayisi / merdiven.length;
      final sicrama = math.pow(TasarimGirdileri.rankArtisi, rankBasina);
      for (var k = 1; k < merdiven.length; k++) {
        expect(merdiven[k], greaterThan(merdiven[k - 1]));
        expect(
          merdiven[k] / merdiven[k - 1],
          closeTo(sicrama, sicrama * 1e-6),
          reason: 'kademe ${k - 1}→$k sıçraması merdivenden çıkmış',
        );
      }
      expect(BekleyenGirdiler.bekleyenler, isEmpty);
    });

    test('SEKİZ gövde de ÇAPADAN çıkıyor — elle yazılan stat yok', () {
      // Karar 04.12: merdiven kazandı. Uzun süre ilk üç gövde elle duruyordu
      // ve merdiven onları açıklamıyordu (Spectre 21.000'e karşı 74.760).
      final merdiven = Turetilenler.govdeKademeCarpanlari;
      for (var k = 0; k < HullClass.all.length; k++) {
        final govde = HullClass.all[k];
        expect(
          govde.baseHull,
          closeTo(ReferansCozumu.govdeCapasi * merdiven[k], 1e-6),
          reason: '${govde.name} gövde canı merdivenden çıkmıyor',
        );
        expect(
          govde.baseShield,
          closeTo(TasarimGirdileri.kalkanCapasi * merdiven[k], 1e-6),
        );
        // Hız kendi küçük merdiveninde: rank çarpanıyla büyüseydi sekizinci
        // kademe altı yüz kat hızlı olurdu.
        expect(
          govde.baseSpeed,
          closeTo(
            TasarimGirdileri.hizCapasi *
                math.pow(TasarimGirdileri.hizArtisi, k),
            1e-6,
          ),
          reason: '${govde.name} hızı %8 merdiveninden çıkmıyor',
        );
      }
      // Bitişik kademeler arasında sıçrama yok: oran merdivenin kendisi.
      for (var k = 1; k < HullClass.all.length; k++) {
        expect(
          HullClass.all[k].baseHull / HullClass.all[k - 1].baseHull,
          closeTo(merdiven[k] / merdiven[k - 1], 1e-9),
        );
      }
    });

    test('yuvalar: lazer SANATA sabit, kalan jeneratör ve CPU\'ya', () {
      // Karar 04.9: sanat kazandı. Sekiz tasarımın hepsinde beş kaide var.
      for (final govde in HullClass.all) {
        expect(
          govde.laserSlots,
          TasarimGirdileri.lazerYuvaSayisi,
          reason: govde.name,
        );
        expect(govde.launcherSlots, 1, reason: govde.name);
        expect(
          govde.totalSlots,
          HullClass.yuvaSayisi(HullClass.all.indexOf(govde)),
        );
      }
      // Bastion'ın 4 · 2 dağılımı kuralın kendisi; kural onu yeniden üretmeli.
      expect(HullClass.bastion.generatorSlots, 4);
      expect(HullClass.bastion.cpuSlots, 2);
      // Jeneratör hiçbir kademede azalmıyor.
      for (var k = 1; k < HullClass.all.length; k++) {
        expect(
          HullClass.all[k].generatorSlots,
          greaterThanOrEqualTo(HullClass.all[k - 1].generatorSlots),
        );
      }
    });

    test('türetilen gövdeler SATIN ALINAMAZ — içerik yok', () {
      // Tanımlılar ama fiyatları yok. Ölçülmüş kısıt: haritada tek dünya ve
      // iki yaratık türü var, yani üst kademe bir gemi için içerik YOK.
      for (final govde in HullClass.cizilenler) {
        expect(govde.satinAlinabilir, isTrue, reason: govde.name);
      }
      for (var k = HullClass.cizilenler.length; k < HullClass.all.length; k++) {
        expect(
          HullClass.all[k].satinAlinabilir,
          isFalse,
          reason: '${HullClass.all[k].name} içerik olmadan satışa çıkmış',
        );
      }
    });

    test(
      'satın alma DENENİRSE reddediliyor — istemci kapısı yeterli değil',
      () {
        final kilitli = HullClass.all.lastWhere((h) => !h.satinAlinabilir);
        final hangar = Hangar(accountId: 'a', credits: 999999999, premium: 0);
        expect(
          HangarRules.buyHull(
            hangar,
            kilitli.id,
            const TxContext(id: 't', atMillis: 0),
          ),
          HangarError.notPurchasable,
        );
        expect(hangar.hulls.contains(kilitli.id), isFalse);
      },
    );

    test('RANK MERDİVENİ ölçülen çarpanları %2 içinde açıklıyor', () {
      // `ItemTier` çarpanları elle ve farklı zamanlarda konmuştu; tek bir
      // orandan (`rankArtisi`) türetilince beşinin beşi de tutuyor. Bu, oranın
      // uydurma olmadığının kanıtı: bugünkü sayıları geriye dönük açıklıyor.
      for (var i = 0; i < ItemTier.values.length; i++) {
        final turetilen = TuretilenTablolar.rankCarpaniFor(
          i,
          TasarimGirdileri.rankArtisi,
        );
        final kodda = ItemTier.values[i].multiplier;
        expect(
          (turetilen - kodda).abs() / kodda,
          lessThan(0.02),
          reason:
              '${ItemTier.values[i].label}: türetilen '
              '${turetilen.toStringAsFixed(3)} ↔ kodda $kodda',
        );
      }
    });
  });
}

/// YÜKSELTME İŞARETİ — "bu parça daha iyi mi" sorusunun tek cevabı.
void yukseltmeIsareti() {
  group('yükseltme karşılaştırması', () {
    Hangar kur() {
      final h = Hangar(
        accountId: 'a',
        credits: 100000000,
        hulls: [HullClass.starter.id],
        activeHullId: HullClass.starter.id,
      );
      h.addItem(const ItemInstance(instanceId: 'zayif', specId: 'pl1'));
      h.addItem(const ItemInstance(instanceId: 'guclu', specId: 'pl4'));
      HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'zayif');

      // BAŞKA yuvalar da DOLU: karşılaştırma gerçek bir donatım üzerinde
      // koşuyor, tek parçalık yapay bir kurulumda değil.
      //
      // **Dürüst not — bu testler bir mutasyonu YAKALAMIYOR.** Karşılaştırmayı
      // boş bir donatım üzerinden yapacak şekilde bozduğumda hepsi geçiyor.
      // Sebebi, iddianın kendisinin sınırı: diğer parçalar karşılaştırmanın
      // İKİ tarafında da aynı, yani sonucun BÜYÜKLÜĞÜNÜ etkiliyorlar,
      // İŞARETİNİ değil. Yüzde statların çarpıştığı bir kurulumda işaret de
      // dönebilir ama öyle bir örnek kurmak, testi gerçek bir davranıştan çok
      // kurgulanmış bir tuzağa çevirirdi. Buradaki testler yönü kilitliyor;
      // büyüklüğü kilitleyen bir muhafız YOK.
      h.addItem(const ItemInstance(instanceId: 'jen', specId: 'df3'));
      h.addItem(const ItemInstance(instanceId: 'cpu', specId: 'cpu_scope'));
      HangarRules.equip(h, const SlotRef(SlotType.generator, 0), 'jen');
      HangarRules.equip(h, const SlotRef(SlotType.cpu, 0), 'cpu');
      return h;
    }

    test('GÜÇLÜ yedek yükseltme sayılıyor', () {
      final h = kur();
      expect(
        LoadoutResolver.yukseltmeMi(
          h.activeLoadout,
          h.inventory,
          Catalogue.byId,
          const SlotRef(SlotType.laser, 0),
          h.itemOf('guclu')!,
        ),
        isTrue,
      );
    });

    test('ZAYIF yedek yükseltme SAYILMIYOR', () {
      final h = kur();
      HangarRules.unequip(h, const SlotRef(SlotType.laser, 0));
      HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'guclu');
      expect(
        LoadoutResolver.yukseltmeMi(
          h.activeLoadout,
          h.inventory,
          Catalogue.byId,
          const SlotRef(SlotType.laser, 0),
          h.itemOf('zayif')!,
        ),
        isFalse,
      );
    });

    test('AYNI parça kendisinin yükseltmesi değil', () {
      // Eşitlikte `false`: aynı gücü veren bir parça için oyuncuyu depoya
      // çağırmak işareti değersizleştirirdi.
      final h = kur();
      expect(
        LoadoutResolver.yukseltmeMi(
          h.activeLoadout,
          h.inventory,
          Catalogue.byId,
          const SlotRef(SlotType.laser, 0),
          h.itemOf('zayif')!,
        ),
        isFalse,
      );
    });

    test('ölçüt BR — donatımın tamamı üzerinden', () {
      // Tek başına bir eşyanın gücüne bakmak yanlış cevap verirdi: statlar
      // birbirini çarpıyor, yani bir parçanın değeri yanındakilere bağlı.
      final h = kur();
      final oncekiBr = CombatGlossary.battleRating(
        LoadoutResolver.resolve(h.activeLoadout, h.inventory, Catalogue.byId),
      );
      HangarRules.unequip(h, const SlotRef(SlotType.laser, 0));
      HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'guclu');
      final sonrakiBr = CombatGlossary.battleRating(
        LoadoutResolver.resolve(h.activeLoadout, h.inventory, Catalogue.byId),
      );
      expect(sonrakiBr, greaterThan(oncekiBr));
    });

    test('BOŞ yuvaya her parça yükseltme', () {
      final h = kur();
      expect(
        LoadoutResolver.yukseltmeMi(
          h.activeLoadout,
          h.inventory,
          Catalogue.byId,
          const SlotRef(SlotType.laser, 1),
          h.itemOf('guclu')!,
        ),
        isTrue,
        reason: 'boş yuvaya takmak BR artırmıyor mu',
      );
    });
  });
}
