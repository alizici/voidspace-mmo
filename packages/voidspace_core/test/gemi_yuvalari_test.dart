@Tags(['turetme', 'aralik', 'kapsam'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 04 · GEMİ VE YUVALAR — gövdenin verdiği üç şey ve yuva merdiveni.
///
/// Bu dosyanın tamamı tek bir cümleyi koruyor: **gövde elle yazılmıyor.**
/// Statları çapadan, yuvaları sanattan artı bir kuraldan, rank etiketi
/// bölmeden geliyor. Bir gün birisi bir gövdenin canını elle düzeltirse
/// kırmızıya dönmesi gereken yer burası.
void main() {
  final env = <String, ItemInstance>{
    'lz': const ItemInstance(instanceId: 'lz', specId: 'pl1'),
    'kalkan': const ItemInstance(instanceId: 'kalkan', specId: 'df1'),
    'itki': const ItemInstance(instanceId: 'itki', specId: 'th1'),
    'cpu': const ItemInstance(instanceId: 'cpu', specId: 'cpu_repair'),
  };

  ShipStats coz(Map<String, String> yuvalar) => LoadoutResolver.resolve(
    Loadout(hullId: HullClass.bastion.id, slots: yuvalar),
    env,
    Catalogue.byId,
  );

  group('04.1 · gemi üç şey verir', () {
    // KARAR 04.1 s1
    test('birincisi TABAN STAT: eşyasız hâlin zemini sıfırdan büyük', () {
      // Zemin sıfır olsaydı "eşyasız gemi" diye bir şey olmazdı: bütün güç
      // eşyadan gelir ve gövde yalnız bir kap olurdu.
      for (final govde in HullClass.all) {
        expect(govde.baseHull, greaterThan(0), reason: govde.name);
        expect(govde.baseShield, greaterThan(0), reason: govde.name);
        expect(govde.baseSpeed, greaterThan(0), reason: govde.name);
      }
    });

    // KARAR 04.1 s1
    test('ikincisi YUVA SAYISI: kademe ilerledikçe kapasite artıyor', () {
      // "Sayıdan çok daha güçlü bir ödül, kapasite." Üst kademe gövde daha az
      // eşya taşıyorsa yükseltme bir ödül değil ceza olurdu.
      for (var k = 1; k < HullClass.all.length; k++) {
        expect(
          HullClass.all[k].totalSlots,
          greaterThan(HullClass.all[k - 1].totalSlots),
          reason:
              '${HullClass.all[k].name} bir alt kademeden çok yuva vermiyor',
        );
      }
    });

    // KARAR 04.1 s1
    test('üçüncüsü YUVA ÇEŞİDİ: dört tip birden, toplam onların toplamı', () {
      // Gövdenin kimliği çeşitte: tek tip yuvadan ibaret bir gemi, "hangi
      // eşyayı takayım" sorusunu hiç sordurmazdı.
      for (final govde in HullClass.all) {
        final cesitler = [
          for (final tip in SlotType.values)
            if (govde.slotCount(tip) > 0) tip,
        ];
        expect(
          cesitler.length,
          4,
          reason: '${govde.name}: ${cesitler.map((t) => t.name)}',
        );
        expect(
          SlotType.values.fold(0, (t, tip) => t + govde.slotCount(tip)),
          govde.totalSlots,
          reason: '${govde.name}: tiplerin toplamı toplamı tutmuyor',
        );
      }
    });
  });

  group('04.2 · yuva haritası ve yuva↔eşya eşleşmesi', () {
    // KARAR 04.2 s1
    test('bir lazer JENERATÖR yuvasına giremiyor', () {
      // Sunucunun doğrulaması gereken şey: eşleşme bu belgenin kararı.
      final h = Hangar(accountId: 'a')
        ..addItem(const ItemInstance(instanceId: 'lz', specId: 'pl1'));
      expect(
        HangarRules.equip(h, const SlotRef(SlotType.generator, 0), 'lz'),
        HangarError.wrongSlot,
      );
      expect(h.activeLoadout.slots, isEmpty);
      // Doğru yuvaya giriyor: kısıt yasak değil, EŞLEŞME.
      expect(
        HangarRules.equip(h, const SlotRef(SlotType.laser, 0), 'lz'),
        isNull,
      );
    });

    // KARAR 04.2 s1
    test('UYDURMA yuvaya takılamıyor — bedava güç kapısı kapalı', () {
      // "O yuva bütçe hesabında olmadığı için bedava güç olurdu."
      final h = Hangar(accountId: 'a')
        ..addItem(const ItemInstance(instanceId: 'lz', specId: 'pl1'));
      final tavan = HullClass.bastion.laserSlots;
      expect(
        HangarRules.equip(h, SlotRef(SlotType.laser, tavan), 'lz'),
        HangarError.noSuchSlot,
      );
      expect(
        HangarRules.equip(h, const SlotRef(SlotType.laser, -1), 'lz'),
        HangarError.noSuchSlot,
      );
      expect(h.activeLoadout.slots, isEmpty);
    });

    // KARAR 04.2 s1
    test('gövdedeki her yuva tipini kabul eden en az bir eşya VAR', () {
      // Değişmez: "Her yuva tipi en az bir eşya tipini kabul ediyor."
      // Kırılırsa doldurulamayan bir yuva var demek — kapasite ödülü boş
      // çıkıyor.
      for (final tip in SlotType.values) {
        if (HullClass.bastion.slotCount(tip) == 0 && tip != SlotType.droid) {
          continue;
        }
        expect(
          Catalogue.items.where((s) => s.slot == tip),
          isNotEmpty,
          reason: '${tip.name} yuvasına takılacak eşya yok',
        );
      }
    });

    // KARAR 04.2 s1
    test('lazer yuvası boşsa gemi ATEŞ EDEMİYOR', () {
      // "Gemi kapsamında taban hasarın tek kaynağı." Yuva boşken taban hasar
      // gelecek başka bir yer yok.
      final bos = coz({'generator#0': 'kalkan', 'cpu#0': 'cpu'});
      expect(bos.laser.damage, 0);
      expect(CombatGlossary.volley(bos), 0);
      // Tek lazer takılınca ateş ediyor.
      final dolu = coz({'laser#0': 'lz'});
      expect(CombatGlossary.volley(dolu), greaterThan(0));
    });

    // KARAR 04.2 s1
    test('namlu sayısı = DOLU lazer yuvası sayısı', () {
      // "Namlu sayısı = yuva sayısı" — ekranda çizilen namlu, stat veren
      // lazerle aynı listeden geliyor.
      expect(coz({'laser#0': 'lz'}).equippedLasers, 1);
      expect(coz(const {}).equippedLasers, 0);
      expect(coz({'laser#0': 'lz'}).laserSlots, HullClass.bastion.laserSlots);
    });
  });

  group('04.3 · jeneratör ikilemi: kalkan ya da hız', () {
    // KARAR 04.3 s1
    test('AYNI yuvaya iki çeşit: kalkan ve hız', () {
      final jeneratorler = Catalogue.items.where(
        (s) => s.slot == SlotType.generator,
      );
      final cesitler = jeneratorler.map((s) => s.variant).toSet();
      expect(cesitler, containsAll(<String>['kalkan', 'hiz']));
      // İkisi de AYNI yuva tipinde: takas ancak böyle doğuyor.
      for (final cesit in ['kalkan', 'hiz']) {
        expect(
          jeneratorler.where((s) => s.variant == cesit).map((s) => s.slot),
          everyElement(SlotType.generator),
        );
      }
    });

    // KARAR 04.3 s1
    test('EKLEME değil TAKAS: kalkan etkin can, hız kaçış veriyor', () {
      // İkisi de savunma veriyor ama farklı biçimde; oyuncunun kararı hangi
      // ucu istediği. Aynı yuvaya iki farklı sonuç çıkmazsa takas yoktur.
      final kalkanli = coz({'laser#0': 'lz', 'generator#0': 'kalkan'});
      final hizli = coz({'laser#0': 'lz', 'generator#0': 'itki'});
      expect(
        CombatGlossary.ehp(kalkanli),
        greaterThan(CombatGlossary.ehp(hizli)),
        reason: 'kalkan tipi etkin can vermiyor',
      );
      expect(
        hizli.speed,
        greaterThan(kalkanli.speed),
        reason: 'hız tipi kaçış vermiyor',
      );
    });
  });

  group('04.6 · referans zırh ve kaçınma toplamları', () {
    // KARAR 04.6 s1
    test('referansın zırhı ÇAPA, kaçınması 300 — ikisi de hedefi veriyor', () {
      // Dört alan, tek elle yazılmış ara sayı yok: 01 hedefi ilan etti, bu
      // belge referansı, K türedi.
      expect(ShipStats.bastion.armor, TasarimGirdileri.zirhCapasi);
      expect(ShipStats.bastion.evasion, TasarimGirdileri.referansKacinma);
      expect(
        ShipStats.bastion.armorReduction,
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-12),
      );
      expect(
        ShipStats.bastion.graze,
        closeTo(TasarimGirdileri.siyirmaHedefiReferans, 1e-12),
      );
    });

    // KARAR 04.6 s1
    test('referansı 1.000\'den 2.000\'e çıkar: K değişir, %30 KALIR', () {
      // Belgenin kendi cümlesi. Elle yazılmış bir K olsaydı bu test
      // kırılırdı — hedef referansla birlikte kaymak zorunda.
      final ikiKat = TasarimGirdileri.zirhCapasi * 2;
      expect(
        Turetilenler.kZirhFor(ikiKat),
        closeTo(Turetilenler.kZirh * 2, 1e-9),
        reason: 'K referansla ölçeklenmiyor — elle yazılmış',
      );
      expect(
        SavunmaEgrileri.doyum(ikiKat, Turetilenler.kZirhFor(ikiKat)),
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-12),
      );
      final kacinmaIkiKat = TasarimGirdileri.referansKacinma * 2;
      expect(
        SavunmaEgrileri.siyirma(
          kacinmaIkiKat,
          Turetilenler.kSiyirmaFor(kacinmaIkiKat),
        ),
        closeTo(TasarimGirdileri.siyirmaHedefiReferans, 1e-12),
      );
    });
  });

  group('04.7 · gövde statları merdivenden türer', () {
    // KARAR 04.7 s2
    test('sekiz gövdenin canı ve kalkanı ÇAPA × kademe çarpanı', () {
      // Değişmez: "Bir gövdenin statı elle yazılmış" olamaz. Çapa iki sayı:
      // gövde canı TTK kısıtından çözülüyor, kalkan girdi.
      expect(HullClass.all.length, TasarimGirdileri.govdeKademeSayisi);
      for (var k = 0; k < HullClass.all.length; k++) {
        final govde = HullClass.all[k];
        final carpan = Turetilenler.govdeKademeCarpanlari[k];
        expect(govde.kademeCarpani, closeTo(carpan, 1e-12), reason: govde.name);
        expect(
          govde.baseHull,
          closeTo(ReferansCozumu.govdeCapasi * carpan, 1e-6),
          reason: '${govde.name} canı elle yazılmış',
        );
        expect(
          govde.baseShield,
          closeTo(TasarimGirdileri.kalkanCapasi * carpan, 1e-9),
          reason: '${govde.name} kalkanı elle yazılmış',
        );
      }
    });

    // KARAR 04.7 s2
    test('kademe çarpanı KADEME NORMALİZASYONUNDAN — sekiz gövde yirmi rank', () {
      // "Bir kademe eklemek yeni bir sayı değil, aynı formülün bir adımı."
      for (var k = 0; k < TasarimGirdileri.govdeKademeSayisi; k++) {
        expect(
          Turetilenler.govdeKademeCarpanlari[k],
          closeTo(
            TuretilenTablolar.normalizatorFor(
              k,
              rankSayisi: Turetilenler.rankSayisi,
              kademeSayisi: TasarimGirdileri.govdeKademeSayisi,
              artis: TasarimGirdileri.rankArtisi,
            ),
            1e-12,
          ),
          reason: 'kademe $k çarpanı normalizatörden gelmiyor',
        );
      }
      expect(Turetilenler.govdeKademeCarpanlari.first, closeTo(1.0, 1e-12));
      // Her gövde iki buçuk rank kapsıyor: 20 ÷ 8.
      expect(
        Turetilenler.rankSayisi / TasarimGirdileri.govdeKademeSayisi,
        closeTo(2.5, 1e-12),
      );
    });

    // KARAR 04.7 s2
    test('rank etiketi BANDIN İLK RANKI — beşinci gövde SS-I yazmıyor', () {
      // Aile başından (kademe × 3) gelirken beşinci gövde SS-I yazıyor ve
      // S-II oyuncusunun gövdesi oluyordu; etiket güce girmiyor ama yalan
      // söylüyordu (B10).
      for (var k = 0; k < HullClass.all.length; k++) {
        expect(
          HullClass.all[k].tier.index,
          ReferansBuild.rankiFor(k),
          reason: '${HullClass.all[k].name} etiketi bölmeden gelmiyor',
        );
      }
      expect(HullClass.all[4].tier, ItemTier.sII);
      expect(HullClass.all[4].tier, isNot(ItemTier.ssI));
    });
  });

  group('04.8 · yuva merdiveni kesikli, kademe başına bir yuva', () {
    // KARAR 04.8 s1
    test('ilk üç gövdenin TOPLAMI sanata kilitli: 12 · 16 · 18', () {
      // Droid burada YOK: filo gövdeye değil oyuncuya bağlı (04.10).
      expect(HullClass.sanatYuvalari, [12, 16, 18]);
      for (var k = 0; k < HullClass.sanatYuvalari.length; k++) {
        expect(HullClass.yuvaSayisi(k), HullClass.sanatYuvalari[k]);
        expect(HullClass.all[k].totalSlots, HullClass.sanatYuvalari[k]);
      }
    });

    // KARAR 04.8 s1
    test('dördüncüden itibaren kademe başına yuvaArtisi kadar açılıyor', () {
      expect(TasarimGirdileri.yuvaArtisi, 1);
      for (
        var k = HullClass.sanatYuvalari.length;
        k < TasarimGirdileri.govdeKademeSayisi;
        k++
      ) {
        expect(
          HullClass.yuvaSayisi(k) - HullClass.yuvaSayisi(k - 1),
          TasarimGirdileri.yuvaArtisi,
          reason: 'kademe $k merdivenin adımını tutmuyor',
        );
      }
    });

    // KARAR 04.8 s1
    test('merdiven TAM SAYI ve aralık dışı kademe ATIYOR', () {
      // "Formül uydurmak, çizimde beş namlu varken tabloda 5,4 çıkması
      // riskini getirirdi."
      for (var k = 0; k < TasarimGirdileri.govdeKademeSayisi; k++) {
        expect(HullClass.yuvaSayisi(k), isA<int>());
      }
      expect(() => HullClass.yuvaSayisi(-1), throwsArgumentError);
      expect(
        () => HullClass.yuvaSayisi(TasarimGirdileri.govdeKademeSayisi),
        throwsArgumentError,
      );
    });
  });

  group('04.9 · sanat kısıtı: lazer yuvası = çizimdeki namlu', () {
    // Atlasın kaide sayısıyla eşitlik istemci testinde
    // (`test/sanat_kisiti_test.dart`): çekirdek sanatı okuyamaz. Buradaki
    // yarısı sayının kendisi ve dağıtım kuralı.

    // KARAR 04.9 s2
    test('lazer yuvası her kademede SABİT beş — açılan yuva lazere gitmiyor', () {
      // Ölçüldüğünde tutmuyordu: tablo lazeri kademe başına bir artırıp on
      // ikiye çıkarıyordu, sekiz tasarımın hepsi beş kaide taşırken. Sanat
      // kazandı.
      expect(TasarimGirdileri.lazerYuvaSayisi, 5);
      for (final govde in HullClass.all) {
        expect(
          govde.laserSlots,
          TasarimGirdileri.lazerYuvaSayisi,
          reason: '${govde.name} lazer yuvası çizimden ayrılmış',
        );
      }
    });

    // KARAR 04.9 s2
    test('açılan yuvalar jeneratör ile CPU\'ya, üçte iki payıyla', () {
      expect(TasarimGirdileri.jeneratorYuvaPayi, closeTo(2 / 3, 1e-4));
      for (var k = 0; k < HullClass.all.length; k++) {
        final govde = HullClass.all[k];
        final kalan = HullClass.yuvaSayisi(k) - govde.laserSlots - 1;
        expect(
          govde.generatorSlots,
          (kalan * TasarimGirdileri.jeneratorYuvaPayi).round(),
          reason: '${govde.name} jeneratör payı tutmuyor',
        );
        expect(
          govde.generatorSlots + govde.cpuSlots,
          kalan,
          reason: '${govde.name}: kalan yuvalar ikiye bölünmüyor',
        );
      }
    });

    // KARAR 04.9 s2
    test('Bastion\'ın 4 · 2 dağılımı kuralın kendisi', () {
      expect(HullClass.bastion.laserSlots, 5);
      expect(HullClass.bastion.generatorSlots, 4);
      expect(HullClass.bastion.launcherSlots, 1);
      expect(HullClass.bastion.cpuSlots, 2);
    });
  });

  group('04.11 · roketatar her gövdede tam bir yuva', () {
    // KARAR 04.11 s1
    test('sekiz gövdenin sekizinde de roketatar TAM BİR', () {
      // Değişmez: "Roketatar yuvası her gövdede tam 1." Dar bant bilinçli:
      // tek yuva olduğu için katkısı büyürse tek eşya oyunu belirler.
      for (final govde in HullClass.all) {
        expect(govde.launcherSlots, 1, reason: govde.name);
        expect(govde.slotCount(SlotType.launcher), 1, reason: govde.name);
      }
      // Türetilen kademeler birinci gövdenin sayısını AYNEN taşıyor.
      expect(
        HullClass.all.map((g) => g.launcherSlots).toSet(),
        {HullClass.bastion.launcherSlots},
      );
    });

    // KARAR 04.11 s1
    test('ikinci roketatar yuvası YOK — salvo da tek', () {
      final h = Hangar(accountId: 'a')
        ..addItem(const ItemInstance(instanceId: 'r1', specId: 'mk1'));
      expect(
        HangarRules.equip(h, const SlotRef(SlotType.launcher, 1), 'r1'),
        HangarError.noSuchSlot,
      );
    });
  });

  group('04.12 · merdiven çizilmiş gövdeleri açıklar', () {
    // KARAR 04.12 s2
    test('çizilmiş üç gövde de merdivenin ÜSTÜNDE — elle stat yok', () {
      // Elle konan Vanguard 16.000 ve Spectre 21.000 merdivenin 30.000 ve
      // 74.760'ına karşıydı; merdiven kazandı. Elle duran tek şey yuva
      // toplamı ve fiyat.
      for (final govde in HullClass.cizilenler) {
        final k = HullClass.all.indexOf(govde);
        expect(
          govde.baseHull,
          closeTo(
            ReferansCozumu.govdeCapasi * Turetilenler.govdeKademeCarpanlari[k],
            1e-6,
          ),
          reason: '${govde.name} canı merdivenin dışında',
        );
      }
      // Fiyat çizilenlerde var, türetilenlerde yok: içerik gelene kadar
      // satın alınamıyorlar.
      expect(
        HullClass.cizilenler.every((g) => g.satinAlinabilir),
        isTrue,
      );
      expect(
        HullClass.all.skip(HullClass.cizilenler.length).every(
          (g) => !g.satinAlinabilir,
        ),
        isTrue,
      );
    });

    // KARAR 04.12 s2
    test('hız İSTİSNA: kendi merdiveninde, çapa × 1,08^kademe', () {
      // Rank çarpanıyla büyüseydi sekizinci kademe altı yüz kat hızlı olurdu
      // ve savaş kaçış yarışına dönerdi.
      expect(TasarimGirdileri.hizArtisi, 1.08);
      for (var k = 0; k < HullClass.all.length; k++) {
        expect(
          HullClass.all[k].baseSpeed,
          closeTo(
            TasarimGirdileri.hizCapasi *
                math.pow(TasarimGirdileri.hizArtisi, k),
            1e-9,
          ),
          reason: '${HullClass.all[k].name} hızı rank merdivenine binmiş',
        );
      }
      // Son kademe hızı, rank merdiveni kullanılsaydı çıkacak sayının çok
      // altında: ikisi ayrı merdiven.
      expect(
        HullClass.all.last.baseSpeed / HullClass.bastion.baseSpeed,
        lessThan(Turetilenler.govdeKademeCarpanlari.last / 10),
      );
    });

    // KARAR 04.12 s2
    test('bitişik kademeler arasında SIÇRAMA yok — oran sabit', () {
      // Dördüncü kademe 186.819'a sıçrıyordu: bitişik iki gövde arasında
      // dokuz kat. Merdivende her adım aynı orana sahip.
      final oranlar = <double>[
        for (var k = 1; k < HullClass.all.length; k++)
          HullClass.all[k].baseHull / HullClass.all[k - 1].baseHull,
      ];
      for (final oran in oranlar) {
        expect(oran, closeTo(oranlar.first, oranlar.first * 1e-9));
        expect(oran, lessThan(3.0), reason: 'bitişik kademede sıçrama var');
      }
      // Kalkan da aynı adımı izliyor.
      for (var k = 1; k < HullClass.all.length; k++) {
        expect(
          HullClass.all[k].baseShield / HullClass.all[k - 1].baseShield,
          closeTo(oranlar.first, oranlar.first * 1e-9),
        );
      }
    });

    // KARAR 04.12 s2
    test('kademe arttıkça HER stat artıyor — ters merdiven yok', () {
      for (var k = 1; k < HullClass.all.length; k++) {
        final alt = HullClass.all[k - 1];
        final ust = HullClass.all[k];
        expect(ust.baseHull, greaterThan(alt.baseHull), reason: ust.name);
        expect(ust.baseShield, greaterThan(alt.baseShield), reason: ust.name);
        expect(ust.baseSpeed, greaterThan(alt.baseSpeed), reason: ust.name);
      }
    });
  });
}
