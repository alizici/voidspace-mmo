@Tags(['turetme', 'kapsam', 'yabanci-anahtar'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// DROİD SİSTEMİ — 04.10 filo, 05.1–05.5 sağlayıcı ve σ, 05.8 seviye,
/// 05.9 formasyon, 08.1 pay, 09.6 savaş puanı.
void main() {
  final hull = HullClass.bastion;

  Hangar acikHangar() {
    final h = Hangar(accountId: 'a', credits: 1 << 40);
    // Droid üçüncü rankta açılıyor (10.7): açılış için bir B-I eşya.
    h.addItem(const ItemInstance(instanceId: 'acilis', specId: 'pl5'));
    return h;
  }

  group('04.10 · droid filosu gövdeden bağımsız', () {
    // KARAR 04.10 s3
    test('gövdede droid yuvası yok; filo tavanı on', () {
      for (final h in HullClass.all) {
        expect(h.slotCount(SlotType.droid), 0);
      }
      expect(hull.totalSlots, 12);
      expect(TasarimGirdileri.droidFiloTavani, 10);
      expect(
        () =>
            Loadout(hullId: hull.id).hasSlot(const SlotRef(SlotType.droid, 0)),
        returnsNormally,
      );
      expect(
        Loadout(hullId: hull.id).hasSlot(const SlotRef(SlotType.droid, 0)),
        isFalse,
      );
    });

    // KARAR 04.10 s3
    test('filoya alınan droid gemi değişince KALIYOR; tavan on', () {
      final h = acikHangar();
      for (var i = 0; i < 12; i++) {
        h.addItem(ItemInstance(instanceId: 'd$i', specId: 'dr1'));
      }
      for (var i = 0; i < 10; i++) {
        expect(HangarRules.filoyaAl(h, 'd$i'), isNull, reason: 'd$i');
      }
      expect(HangarRules.filoyaAl(h, 'd10'), HangarError.filoDolu);
      expect(h.filo, hasLength(10));
      // Aynı droid iki kez sayılmıyor.
      expect(HangarRules.filoyaAl(h, 'd0'), isNull);
      expect(h.filo, hasLength(10));

      h.grantHull(HullClass.vanguard.id);
      expect(h.selectHull(HullClass.vanguard.id), isTrue);
      expect(h.filo, hasLength(10), reason: 'gemi değişince filo gitti');

      expect(HangarRules.filodanCikar(h, 'd3'), isNull);
      expect(h.filo, hasLength(9));
      expect(HangarRules.filodanCikar(h, 'd3'), HangarError.notFound);
      // Kayıt gidiş-dönüş.
      expect(Hangar.fromJson(h.toJson()).filo, h.filo);
      expect(Hangar(accountId: 'b').toJson().containsKey('filo'), isFalse);
    });

    // KARAR 04.10 s3
    test('yalnız droid filoya girer; filodaki droid parçalanamaz', () {
      final h = acikHangar();
      h.addItem(const ItemInstance(instanceId: 'l', specId: 'pl1'));
      h.addItem(const ItemInstance(instanceId: 'd', specId: 'dr1'));
      expect(HangarRules.filoyaAl(h, 'l'), HangarError.wrongSlot);
      expect(HangarRules.filoyaAl(h, 'yok'), HangarError.notOwned);
      expect(HangarRules.filoyaAl(h, 'd'), isNull);
      expect(HangarRules.parcala(h, 'd').$2, HangarError.equipped);
      expect(HangarRules.filodanCikar(h, 'd'), isNull);
      expect(HangarRules.parcala(h, 'd').$2, isNull);
      expect(h.filo, isEmpty, reason: 'silinen droid filodan düşmeli');
    });

    test('droid gövde yuvasına takılamıyor', () {
      final h = acikHangar();
      h.addItem(const ItemInstance(instanceId: 'd', specId: 'dr1'));
      expect(
        HangarRules.equip(h, const SlotRef(SlotType.droid, 0), 'd'),
        HangarError.noSuchSlot,
      );
      expect(
        HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'd'),
        HangarError.wrongSlot,
      );
    });
  });

  group('05.2 · sağlayıcı kaydı ve 05.4 · yuva → kapsam', () {
    // KARAR 05.2 s1 · KARAR 05.4 s5
    test('üç tip, üç kayıt; kapsamı yuva belirliyor', () {
      expect(
        Saglayici.hepsi.map((k) => k.tip).toSet(),
        SaglayiciTipi.values.toSet(),
      );
      expect(Saglayici.kapsamOf(SlotType.droid), StatScope.droid);
      for (final t in SlotType.values.where((t) => t != SlotType.droid)) {
        expect(Saglayici.kapsamOf(t), StatScope.gemi);
      }
      expect(
        Saglayici.formasyon.kapsam,
        isNull,
        reason: 'davranış stat yazmaz',
      );
    });

    // KARAR 05.4 s5
    test('filodaki droid DROİD kapsamına yazıyor, gemiye değil', () {
      final loadout = Loadout(hullId: hull.id);
      final v = LoadoutResolver.vectorOf(
        loadout,
        {'d': const ItemInstance(instanceId: 'd', specId: 'dr1')},
        Catalogue.byId,
        filo: const ['d', 'yok'],
      );
      expect(v.get('hasar_artisi', StatScope.droid), greaterThan(0));
      expect(v.get('hasar_artisi', StatScope.gemi), 0, reason: 'sızıntı');
    });

    test('droid eşyaları kütüphaneyi ve kapsam kilidini bozmuyor', () {
      final droidler = Catalogue.items.where((s) => s.slot == SlotType.droid);
      expect(droidler.where((s) => s.tier == ItemTier.cI), isNotEmpty);
      for (final s in droidler) {
        for (final id in [s.mainStat, ...s.subStatPool]) {
          expect(
            Stats.byId(id)!.kapsam,
            contains(StatScope.droid),
            reason: '${s.id}: $id droid kapsamına yazamaz',
          );
        }
        expect(
          s.subStatPool,
          hasLength(6),
          reason: '${s.id} havuzu altı değil',
        );
      }
      // İki çeşit (05.8 s2): dört model tasarımla karıştırılıyordu.
      expect(
        Catalogue.rafta.where((s) => s.slot == SlotType.droid),
        hasLength(2),
      );
    });
  });

  group('05.4 s5 · droid bir taşıyıcı', () {
    Hangar donanimli() {
      final h = Hangar(accountId: 'a', credits: 1 << 30);
      h.addItem(const ItemInstance(instanceId: 'acilis', specId: 'pl5'));
      h.addItem(const ItemInstance(instanceId: 'd', specId: 'dr1'));
      h.addItem(const ItemInstance(instanceId: 'elit', specId: 'dr5'));
      h.addItem(const ItemInstance(instanceId: 'lazer', specId: 'pl1'));
      h.addItem(const ItemInstance(instanceId: 'lazer2', specId: 'pl1'));
      h.addItem(const ItemInstance(instanceId: 'jen', specId: 'df1'));
      h.addItem(const ItemInstance(instanceId: 'cpu', specId: 'cpu_repair'));
      return h;
    }

    // KARAR 05.4 s5
    test('standart droid BİR, elit droid İKİ yuva taşıyor', () {
      expect(Catalogue.droidYuvaSayisi(Catalogue.dr1), 1);
      expect(Catalogue.droidYuvaSayisi(Catalogue.dr5), 2);
      expect(Catalogue.droidYuvaSayisi(Catalogue.pl1), 0);

      final h = donanimli();
      expect(HangarRules.droideTak(h, 'd', 'lazer'), isNull);
      expect(
        HangarRules.droideTak(h, 'd', 'jen'),
        HangarError.filoDolu,
        reason: 'standart droid ikinci eşyayı aldı',
      );
      expect(HangarRules.droideTak(h, 'elit', 'jen'), isNull);
      expect(HangarRules.droideTak(h, 'elit', 'lazer2'), isNull);
      expect(h.droidinDonanimi('elit'), hasLength(2));
    });

    // KARAR 05.4 s5
    test('kapasiteyi aşan ESKİ kayıt: fazlası oyuncuya geri veriliyor', () {
      // Yuva sayısı yalnız takarken sınanıyordu, yani kayda kapasiteyi aşan
      // bir liste hiç giremezdi — kapasite değişene kadar. Merdiven
      // droidleri elit sayılmaktan çıkıp tek yuvaya inince, o günden önce
      // iki eşya takılmış her droid kaydında ikisini taşıyor kaldı.
      final h = donanimli();
      // İki yuvalı ELİT droide iki eşya tak, sonra kaydı tek yuvalı bir
      // droidle yeniden kur: eski kaydın birebir taklidi.
      expect(HangarRules.filoyaAl(h, 'elit'), isNull);
      expect(HangarRules.droideTak(h, 'elit', 'lazer'), isNull);
      expect(HangarRules.droideTak(h, 'elit', 'jen'), isNull);
      final json = h.toJson();
      // Elit droidi tek yuvalı çeşitle değiştir — kapasite düşmüş gibi.
      final env = (json['inventory']! as Map).cast<String, Object?>();
      final elit = (env['elit']! as Map).cast<String, Object?>();
      env['elit'] = {...elit, 'specId': Catalogue.dr1.id};

      final geri = Hangar.fromJson(json);
      expect(
        geri.droidinDonanimi('elit'),
        ['lazer'],
        reason: 'fazla eşya droidde kaldı',
      );
      // SİLİNMEDİ: envanterde duruyor ve yeniden takılabilir.
      expect(geri.itemOf('jen'), isNotNull, reason: 'fazla eşya silindi');
      expect(geri.droiddeMi('jen'), isFalse);
    });

    // KARAR 05.4 s5
    test('çözüm kapasiteyi AŞAN listeden fazlasını saymıyor', () {
      // Göç çalışmasa bile fazla eşya güç vermemeli: kapasite hesabın da
      // kuralı, yalnız kaydın değil.
      final h = donanimli();
      expect(HangarRules.filoyaAl(h, 'd'), isNull);
      expect(HangarRules.droideTak(h, 'd', 'lazer'), isNull);

      ShipStats coz(Map<String, List<String>> donanim) =>
          LoadoutResolver.resolve(
            h.activeLoadout,
            h.inventory,
            Catalogue.byId,
            filo: h.filo,
            droidDonanimi: donanim,
          );

      final tek = coz({'d': const ['lazer']});
      // Elle kurulmuş BOZUK kayıt: tek yuvalı droidde iki eşya.
      final iki = coz({'d': const ['lazer', 'jen']});
      expect(
        iki.droidler.havuz,
        tek.droidler.havuz,
        reason: 'kapasite dışı jeneratör havuza bindi',
      );
      expect(iki.droidler.tabanHasar, tek.droidler.tabanHasar);
    });

    // KARAR 05.4 s5
    test('kalkan jeneratörü takılmış droid ÇÖZÜLÜYOR ve havuzu büyütüyor', () {
      // Kural jeneratörü droide sokmaya izin veriyordu ama kayıt kalkanı
      // gemiye hapsetmişti: çözüm ArgumentError atıyor, sunucu düşüyordu.
      // Hiçbir test takmanın ARDINDAN çözmediği için görülmemişti.
      final h = donanimli();
      expect(HangarRules.filoyaAl(h, 'd'), isNull);

      ShipStats coz() => LoadoutResolver.resolve(
        h.activeLoadout,
        h.inventory,
        Catalogue.byId,
        filo: h.filo,
        droidDonanimi: h.droidDonanimi,
      );

      final bos = coz().droidler.havuz;
      expect(HangarRules.droideTak(h, 'd', 'jen'), isNull);
      final dolu = coz().droidler.havuz;
      expect(dolu, greaterThan(bos), reason: 'jeneratör havuza binmedi');
    });

    // KARAR 05.4 s5
    test('droidin kullanamadığı alt stat droid kapsamına YAZILMIYOR', () {
      // Hız, kaçınma, kalkan yenilenmesi, son azaltma ve son hasar droide
      // giren eşyaların alt stat havuzunda var ama droid grubunun karşılığı
      // yok. Kaydın kapsamı bu sorunun tek yetkilisi.
      for (final id in const [
        'hiz',
        'kacinma',
        'kalkan_yenilenmesi',
        'son_azaltma',
        'son_hasar',
      ]) {
        expect(
          Stats.byId(id)!.kapsam.contains(StatScope.droid),
          isFalse,
          reason: '$id droid kapsamı aldı; droidGrubuOf onu okumuyor',
        );
        final v = StatVector();
        LoadoutResolver.droidYaz(v, id, 5);
        expect(v.get(id, StatScope.droid), 0, reason: id);
      }
      // Kalkan İSTİSNA: droide kalkan jeneratörü giriyor.
      final v = StatVector();
      LoadoutResolver.droidYaz(v, 'kalkan', 5);
      expect(v.get('kalkan', StatScope.droid), 5);
    });

    // KARAR 05.4 s5
    test('yalnız lazer ve jeneratör giriyor; CPU ve droid giremiyor', () {
      final h = donanimli();
      expect(HangarRules.droideTak(h, 'd', 'cpu'), HangarError.wrongSlot);
      expect(HangarRules.droideTak(h, 'd', 'elit'), HangarError.wrongSlot);
      expect(HangarRules.droideTak(h, 'lazer', 'jen'), HangarError.wrongSlot);
      expect(
        Saglayici.droidDonanimTipleri,
        {SlotType.laser, SlotType.generator},
      );
    });

    // KARAR 05.4 s5
    test('aynı eşya iki yerde olamaz: gemide takılıysa droide girmiyor', () {
      final h = donanimli();
      h.activeLoadout.equip(const SlotRef(SlotType.laser, 0), 'lazer');
      expect(HangarRules.droideTak(h, 'd', 'lazer'), HangarError.equipped);

      h.activeLoadout.unequip(const SlotRef(SlotType.laser, 0));
      expect(HangarRules.droideTak(h, 'd', 'lazer'), isNull);
      // İkinci droide de giremiyor.
      expect(HangarRules.droideTak(h, 'elit', 'lazer'), HangarError.equipped);
      expect(HangarRules.droidenCikar(h, 'lazer'), isNull);
      expect(HangarRules.droideTak(h, 'elit', 'lazer'), isNull);
    });

    // KARAR 05.4 s5
    test('droid silinince donanımı serbest kalıyor, eşya envanterde', () {
      final h = donanimli();
      expect(HangarRules.droideTak(h, 'd', 'lazer'), isNull);
      h.removeItem('d');
      expect(h.droidinDonanimi('d'), isEmpty);
      expect(h.itemOf('lazer'), isNotNull, reason: 'içindeki eşya da silindi');
      expect(h.droiddeMi('lazer'), isFalse);
    });

    // KARAR 05.4 s5
    test('kayıt donanımı taşıyor; eski kayıtta alan yok', () {
      final h = donanimli();
      HangarRules.droideTak(h, 'd', 'lazer');
      final geri = Hangar.fromJson(h.toJson());
      expect(geri.droidinDonanimi('d'), ['lazer']);

      final bos = Hangar(accountId: 'b');
      expect(bos.toJson().containsKey('droidDonanimi'), isFalse);
    });

    // KARAR 05.4 s5
    test('takılan lazer droid kapsamına yazıyor, gemiye değil', () {
      final h = donanimli();
      HangarRules.droideTak(h, 'd', 'lazer');
      HangarRules.filoyaAl(h, 'd');
      final v = LoadoutResolver.vectorOf(
        h.activeLoadout,
        h.inventory,
        Catalogue.byId,
        filo: h.filo,
        droidDonanimi: h.droidDonanimi,
      );
      expect(v.get(Stats.baseDamage.id, StatScope.droid), greaterThan(0));
      expect(v.get(Stats.baseDamage.id, StatScope.gemi), 0);
    });
  });

  group('05.8 s2 · kayıt göçü', () {
    // KARAR 05.8 s2
    test('kaldırılan droid kimlikleri bugünkünün karşılığına çevriliyor', () {
      // Droid çeşidi ikiye inince C-II ve C-III elle yazılan listeden düştü.
      // Oyuncunun envanterinde binlerce tane vardı: yetim kalsalardı depo
      // ekranı onları okuyup çöküyordu.
      for (final e in ItemInstance.tasarimGocu.entries) {
        final yeni = Catalogue.byId[e.value];
        expect(yeni, isNotNull, reason: '${e.key} → ${e.value} yok');
        expect(yeni!.slot, SlotType.droid);
      }

      final eski = ItemInstance.fromJson({
        'instanceId': 'x',
        'specId': 'dr3',
        'level': 4,
      });
      expect(eski.specId, 'droid-cIII');
      expect(Catalogue.byId[eski.specId]!.tier, ItemTier.cIII);
      expect(eski.level, 4, reason: 'göç artı seviyesini yedi');

      // Tanınan kimlik olduğu gibi kalıyor.
      expect(
        ItemInstance.fromJson({'instanceId': 'y', 'specId': 'dr1'}).specId,
        'dr1',
      );
    });

    // KARAR 05.8 s2
    test('göçen eşya RANKINI koruyor: güç kaybı yok', () {
      final eski = ItemInstance.fromJson({
        'instanceId': 'x',
        'specId': 'dr2',
        'level': 0,
      });
      expect(Catalogue.byId[eski.specId]!.tier, ItemTier.cII);
    });
  });

  group('05.5 · aktarım katsayısı', () {
    // KARAR 05.4 s5 · KARAR 05.5 s3
    test('BOŞ droid vurmuyor: yaylım takılandan geliyor', () {
      // Eskiden türetilen bir çapa vardı ve donanımsız droid de vuruyordu.
      // Droid artık bir taşıyıcı: içi boşsa yaylımı sıfır.
      final v = StatVector()..add('hasar_artisi', StatScope.droid, 0.20);
      final g = LoadoutResolver.droidGrubuOf(
        v,
        const [1.0, 1.0],
        Formasyon.varsayilan,
        gemiHasarBonusu: 0,
        gemiKritikSansi: 0,
        gemiKritikCarpani: 0,
      );
      expect(g.sayi, 2);
      expect(g.tabanHasar, 0, reason: 'boş droid vurdu');
      expect(g.havuz, greaterThan(0), reason: 'gövde havuzu yine duruyor');
    });

    // KARAR 05.4 s5
    test('donanım payı ÇÖZÜLÜYOR: tam filo ilan edilen payı veriyor', () {
      // Bölüşüm elle konsaydı ölçülen pay ilandan kayardı; çözülünce tam
      // donanımlı standart filonun yaylımı geminin lazer yaylımının
      // `droidDpsPayi` katı çıkıyor.
      final hull = HullClass.bastion;
      final oran =
          ItemBudget.droidDonanimKatsayisi(hull) /
          ItemBudget.slotCoefficient(SlotType.laser, hull);
      final filoPayi =
          TasarimGirdileri.droidFiloTavani *
          TasarimGirdileri.droidYuvasi *
          oran /
          TasarimGirdileri.lazerYuvaSayisi;
      expect(filoPayi, closeTo(TasarimGirdileri.droidDpsPayi, 1e-9));
      expect(
        Turetilenler.droidDonanimPayi,
        inExclusiveRange(0, 1),
        reason: 'pay bölüşümü aralığın dışına çıktı',
      );
      expect(ReferansCozumu.droidHavuzu, greaterThan(0));
    });

    // KARAR 05.5 s3
    test('σ bağlaşımı: droid bonusu = kendi + σ × geminin', () {
      final v = StatVector()
        ..add('hasar_artisi', StatScope.gemi, 0.50)
        ..add('hasar_artisi', StatScope.droid, 0.10);
      final g = LoadoutResolver.droidGrubuOf(
        v,
        const [1.0],
        Formasyon.varsayilan,
        gemiHasarBonusu: 0.50,
        gemiKritikSansi: 0,
        gemiKritikCarpani: 0,
      );
      expect(g.sayi, 1);
      expect(
        g.damageBonus,
        closeTo(0.10 + TasarimGirdileri.aktarimKatsayisi * 0.50, 1e-12),
      );
      expect(TasarimGirdileri.aktarimKatsayisi, inExclusiveRange(0, 1));
    });

    // KARAR 05.4 s5
    test('tam DONANIMLI filo referansta saldırının payı kadar', () {
      // Çıplak filo değil DONANIMLI filo: droid artık taşıyıcı ve payı
      // içindekinden geliyor. Ölçü aynı — geminin yaylımına oran.
      const ref = ShipStats.bastion;
      final envanter = <String, ItemInstance>{};
      final filo = <String>[];
      final donanim = <String, List<String>>{};
      for (var i = 0; i < TasarimGirdileri.droidFiloTavani; i++) {
        envanter['d$i'] = ItemInstance(instanceId: 'd$i', specId: 'dr1');
        envanter['l$i'] = ItemInstance(instanceId: 'l$i', specId: 'pl1');
        filo.add('d$i');
        donanim['d$i'] = ['l$i'];
      }
      final stats = LoadoutResolver.resolve(
        Loadout(hullId: hull.id),
        envanter,
        Catalogue.byId,
        filo: filo,
        droidDonanimi: donanim,
      );
      expect(stats.droidler.sayi, TasarimGirdileri.droidFiloTavani);
      // Bölüşüm YAYLIM düzeyinde çözülüyor: donanımın tabanı geminin lazer
      // yaylımının `droidDpsPayi` katı. Ölçülen DPS payı bunun ÜSTÜNDE,
      // çünkü droid gövdeleri de hasar artışı taşıyor ve o çarpan takılan
      // lazerin tabanını büyütüyor (borç defteri B31).
      final dpsPayi =
          CombatGlossary.droidDps(stats) / CombatGlossary.expectedDps(ref);
      expect(dpsPayi, greaterThan(TasarimGirdileri.droidDpsPayi));
      expect(
        dpsPayi,
        lessThan(2 * TasarimGirdileri.droidDpsPayi),
        reason: 'filo ilan edilen payın iki katını aştı',
      );
    });

    test('çözücü filoyu gövdeden bağımsız okuyor', () {
      final inv = {
        for (var i = 0; i < 3; i++)
          'd$i': ItemInstance(instanceId: 'd$i', specId: 'dr1', level: 3 * i),
      };
      final bastion = LoadoutResolver.resolve(
        Loadout(hullId: HullClass.bastion.id),
        inv,
        Catalogue.byId,
        filo: inv.keys.toList(),
      );
      final vanguard = LoadoutResolver.resolve(
        Loadout(hullId: HullClass.vanguard.id),
        inv,
        Catalogue.byId,
        filo: inv.keys.toList(),
      );
      expect(bastion.droidler.sayi, 3);
      expect(vanguard.droidler.sayi, 3);
      expect(
        vanguard.droidler.tabanHasar,
        closeTo(bastion.droidler.tabanHasar, 1e-9),
        reason: 'droid çapası gövdeyle değişmemeli',
      );
      // Artı çarpanı droidden: +6 droid +0 droidden güçlü.
      expect(
        LoadoutResolver.droidCarpanlariOf(['d2'], inv, Catalogue.byId).first,
        greaterThan(
          LoadoutResolver.droidCarpanlariOf(['d0'], inv, Catalogue.byId).first,
        ),
      );
    });
  });

  group('05.8 · droid seviyesi', () {
    // KARAR 05.8 s2
    test('altı kademe, güçlenme adımlarından', () {
      expect(DroidSeviyesi.tavan, 6);
      expect(DroidSeviyesi.of(0), 1);
      expect(DroidSeviyesi.of(2), 1);
      expect(DroidSeviyesi.of(3), 2);
      expect(DroidSeviyesi.of(ItemLevels.max), 6);
      expect(DroidSeviyesi.of(99), 6);
      expect(DroidModeli.ofVariant('hilal'), DroidModeli.hilal);
      expect(DroidModeli.ofVariant(null), DroidModeli.ucuz);
    });

    // KARAR 05.8 s2
    test('iki çeşit satılıyor, on tasarım var, sekizi merdivenden', () {
      // Çeşit PARANIN, tasarım RANKIN: krediyle alınan Delta, NOVA ile
      // alınan Hilal; kalan sekiz tasarım merdivenden gelen droidlerde.
      final satilan = Catalogue.rafta.where((s) => s.slot == SlotType.droid);
      expect(satilan, hasLength(2));
      expect(
        satilan.map((s) => s.variant).toSet(),
        {DroidModeli.ucuz.name, DroidModeli.elit.name},
      );
      expect(
        satilan.singleWhere((s) => s.variant == DroidModeli.elit.name).currency,
        Currency.premium,
        reason: 'elit droid NOVA rafında değil',
      );
      expect(
        satilan.singleWhere((s) => s.variant == DroidModeli.ucuz.name).currency,
        Currency.credit,
      );

      expect(DroidModeli.values, hasLength(10));
      expect(DroidModeli.merdiven, hasLength(8));
      expect(
        DroidModeli.merdiven,
        isNot(contains(DroidModeli.elit)),
        reason: 'satılan tasarım merdivende de çıkıyor',
      );
      expect(DroidModeli.merdiven, isNot(contains(DroidModeli.ucuz)));

      // Merdivenden türeyen her droid sekiz tasarımdan birini giyiyor ve
      // aynı rank hep aynısını veriyor.
      final turetilen = Catalogue.items.where(
        (s) => s.slot == SlotType.droid && !Catalogue.rafta.contains(s),
      );
      expect(turetilen, isNotEmpty);
      for (final s in turetilen) {
        expect(
          DroidModeli.merdiven.map((m) => m.name),
          contains(s.variant),
          reason: '${s.id} tanınmayan tasarım taşıyor: ${s.variant}',
        );
      }
    });
  });

  group('05.9 · formasyon', () {
    // KARAR 05.9 s1
    test('yirmi formasyon, kimlikler benzersiz, geometri hepsinde ayrı', () {
      expect(Formasyon.hepsi, hasLength(20));
      expect(Formasyon.hepsi.map((f) => f.id).toSet(), hasLength(20));
      expect(Formasyon.hepsi.map((f) => f.sekil).toSet(), hasLength(20));
      expect(Formasyon.ofId('yok-boyle'), Formasyon.varsayilan);
      expect(Formasyon.byId('ok')!.egilim, FormasyonEgilimi.saldiri);
    });

    // KARAR 05.9 s1
    test('imzalı takas: σ bir yöne, havuz öteki yöne; denge dokunmuyor', () {
      final sigma = TasarimGirdileri.aktarimKatsayisi;
      final takas = TasarimGirdileri.formasyonTakasi;
      final saldiri = Formasyon.hepsi.firstWhere(
        (f) => f.egilim == FormasyonEgilimi.saldiri,
      );
      final savunma = Formasyon.hepsi.firstWhere(
        (f) => f.egilim == FormasyonEgilimi.savunma,
      );
      expect(saldiri.aktarim, closeTo(sigma + takas, 1e-12));
      expect(saldiri.havuzCarpani, closeTo(1 - takas, 1e-12));
      expect(savunma.aktarim, closeTo(sigma - takas, 1e-12));
      expect(savunma.havuzCarpani, closeTo(1 + takas, 1e-12));
      expect(Formasyon.varsayilan.aktarim, sigma);
      expect(Formasyon.varsayilan.havuzCarpani, 1.0);
    });

    test(
      'hangarda tek aktif, SAHİPLİ olan seçilir, kayda giriyor',
      () {
        final h = Hangar(accountId: 'a');
        expect(h.formasyon, Formasyon.varsayilan);
        // Varsayılan hep sahipli; gerisi NOVA rafından (15.9). Sahip
        // olunmayan formasyon seçilemiyor.
        expect(
          HangarRules.formasyonSec(h, 'halka'),
          HangarError.notPurchasable,
        );
        h
          ..formasyonEkle('halka')
          ..formasyonEkle('ok');
        expect(HangarRules.formasyonSec(h, 'halka'), isNull);
        expect(HangarRules.formasyonSec(h, 'ok'), isNull);
        expect(h.formasyon.id, 'ok', reason: 'ikincisi birinciyi değiştirmeli');
        expect(HangarRules.formasyonSec(h, 'yok'), HangarError.notFound);
        expect(Hangar.fromJson(h.toJson()).formasyon.id, 'ok');
        expect(
          Hangar(accountId: 'b').toJson().containsKey('formasyonId'),
          isFalse,
        );
      },
    );
  });

  group('08.1 · droid payı', () {
    // KARAR 08.1 s1
    test('altı grup, toplam yüz; droid katsayısı filo tavanından', () {
      final toplam =
          ItemBudget.hullShare +
          ItemBudget.shares.values.fold(0.0, (a, b) => a + b);
      expect(toplam, closeTo(100, 0.05));
      expect(ItemBudget.shares[SlotType.droid], TasarimGirdileri.payDroid);
      expect(
        TasarimGirdileri.payDroid / 100,
        closeTo(TasarimGirdileri.droidDpsPayi, 1e-9),
      );
      // Gövdeye kalan pay: filo payının donanıma gitmeyen kısmı (05.4 s5).
      final beklenen =
          (TasarimGirdileri.payDroid *
              (1 - Turetilenler.droidDonanimPayi) /
              TasarimGirdileri.droidFiloTavani) /
          (TasarimGirdileri.payLazer / hull.laserSlots);
      expect(
        ItemBudget.slotCoefficient(SlotType.droid, hull),
        closeTo(beklenen, 1e-12),
      );
      expect(
        ItemBudget.slotCoefficient(SlotType.droid, HullClass.spectre),
        closeTo(beklenen, 1e-12),
        reason: 'droid bütçesi gövdeyle değişmemeli',
      );
    });
  });

  group('09.6 · droidin iki katsayısı', () {
    // KARAR 09.6 s1
    test('saldırıya ayakta kalma ile, dayanıklılığa çeyrek ile giriyor', () {
      const ref = ShipStats.bastion;
      final droidli = ref.copyWith(
        droidler: LoadoutResolver.droidGrubuOf(
          StatVector(),
          const [1.0, 1.0],
          Formasyon.varsayilan,
          gemiHasarBonusu: 0,
          gemiKritikSansi: 0,
          gemiKritikCarpani: 0,
        ),
      );
      final taban = CombatGlossary.battleRating(ref);
      final br = CombatGlossary.battleRating(droidli);
      expect(br, greaterThan(taban));
      final a =
          CombatGlossary.expectedDps(droidli) +
          CombatGlossary.droidDps(droidli);
      final d =
          (CombatGlossary.ehp(droidli) +
              TasarimGirdileri.droidDayaniklilikKatsayisi *
                  CombatGlossary.droidEhp(droidli)) /
          TasarimGirdileri.referansTTK;
      expect(br / TasarimGirdileri.brOlcegi, closeTo(math.sqrt(a * d), 1e-6));
      expect(CombatGlossary.droidDps(ref), 0);
      expect(CombatGlossary.droidEhp(ref), 0);
      expect(CombatGlossary.brTabani, closeTo(3600, 1));
    });
  });

  group('10.7 · droid üçüncü rankta', () {
    // KARAR 10.7 s1
    test('filoya almak açılış ister', () {
      final h = Hangar(accountId: 'a', credits: 1 << 40);
      h.addItem(const ItemInstance(instanceId: 'd', specId: 'dr1'));
      expect(HangarRules.filoyaAl(h, 'd'), HangarError.kilitli);
      h.addItem(const ItemInstance(instanceId: 'u', specId: 'pl5'));
      expect(HangarRules.filoyaAl(h, 'd'), isNull);
    });
  });
}
