@Tags(['turetme', 'aralik'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 08 · GÜÇ BÜTÇESİ — katsayının gövdeye bağlılığı ve A = D kısıtı.
///
/// "Toplam bütçe" diye korunan bir miktar yok; korunan şey GRUP PAYI. Bu
/// dosya iki kararı sınıyor: katsayı yuva sayısından türediği için gövde
/// büyüdükçe yuva başına güç düşmek zorunda (08.2), ve dağıtımın doğruluk
/// sınavı puanlarda değil GERÇEKLEŞEN değerlerde okunuyor (08.4).
void main() {
  group('08.2 · katsayı gövdeye bağlı', () {
    // KARAR 08.2 s2
    test('grup payı korunuyor: yuva sayısı × katsayı gövdeden BAĞIMSIZ', () {
      // Kararın çekirdeği. Katsayı ilan edilmiyor, `pay ÷ yuva` olarak
      // türüyor; dolayısıyla yuva sayısı ne olursa olsun grubun toplamı aynı
      // kalmak zorunda. Kırılırsa gövde yükseltmek tek başına gücü katlıyor.
      for (final tip in SlotType.values) {
        if (tip == SlotType.droid) continue;
        final beklenen =
            ItemBudget.shares[tip]! /
            ItemBudget.shares[SlotType.laser]! *
            HullClass.all.first.laserSlots;
        for (final govde in HullClass.all) {
          final adet = govde.slotCount(tip);
          if (adet == 0) continue;
          expect(
            ItemBudget.slotCoefficient(tip, govde) * adet,
            closeTo(beklenen, 1e-9),
            reason:
                '${govde.name} · ${tip.name}: grup toplamı gövdeyle değişti',
          );
        }
      }
    });

    // KARAR 08.2 s2
    test('yuva sayısı ARTINCA yuva başına katsayı DÜŞÜYOR', () {
      // "SS gövdedeki bir jeneratör, C gövdedeki bir jeneratörden zayıf."
      // Eşit yuvalı iki kademede katsayı da eşit: düşüşün sebebi kademe
      // değil, yuva sayısı.
      for (final tip in SlotType.values) {
        if (tip == SlotType.droid) continue;
        var oncekiAdet = 0;
        var oncekiKatsayi = double.infinity;
        var azalanVar = false;
        for (final govde in HullClass.all) {
          final adet = govde.slotCount(tip);
          if (adet == 0) continue;
          final katsayi = ItemBudget.slotCoefficient(tip, govde);
          if (oncekiAdet > 0) {
            if (adet > oncekiAdet) {
              expect(
                katsayi,
                lessThan(oncekiKatsayi),
                reason: '${govde.name} · ${tip.name}: yuva arttı katsayı '
                    'düşmedi',
              );
              azalanVar = true;
            } else if (adet == oncekiAdet) {
              expect(katsayi, closeTo(oncekiKatsayi, 1e-12));
            }
          }
          oncekiAdet = adet;
          oncekiKatsayi = katsayi;
        }
        if (tip == SlotType.generator || tip == SlotType.cpu) {
          expect(
            azalanVar,
            isTrue,
            reason: '${tip.name} merdiven boyunca hiç yuva kazanmıyor',
          );
        }
      }
    });

    // KARAR 08.2 s2
    test('gövde büyüyünce AYNI eşyanın bütçesi düşüyor', () {
      // Katsayı bütçeye çarpan olarak giriyor: aynı tasarım, daha çok yuvalı
      // gövdede daha az puan alıyor. Bedeli sıfır — elle bir şey yazılmıyor,
      // katsayı gövde değişince kendiliğinden yeniden hesaplanıyor.
      final jenerator = Catalogue.items.firstWhere(
        (s) => s.slot == SlotType.generator,
      );
      final dar = HullClass.all.first;
      final genis = HullClass.all.last;
      expect(
        genis.slotCount(SlotType.generator),
        greaterThan(dar.slotCount(SlotType.generator)),
        reason: 'merdivenin iki ucunda jeneratör yuvası eşit — sınav yok',
      );
      expect(
        ItemBudget.budgetFor(jenerator, 0, genis),
        lessThan(ItemBudget.budgetFor(jenerator, 0, dar)),
      );
      // Ana stat de aynı yoldan küçülüyor: bütçe → stat zinciri kopmuyor.
      expect(
        ItemBudget.mainStatValue(jenerator, 0, genis),
        lessThan(ItemBudget.mainStatValue(jenerator, 0, dar)),
      );
    });

    // KARAR 08.2 s2
    test('istisna DROİD: filo tavanına bölünüyor, gövdeye bakmıyor', () {
      // Kuralın sınırı da kuralın parçası. Droid gövdeye takılmıyor; payı tam
      // filoya bölünüyor, yani gövde kademesi katsayısını oynatmıyor.
      final katsayilar = {
        for (final govde in HullClass.all)
          ItemBudget.slotCoefficient(SlotType.droid, govde),
      };
      expect(katsayilar, hasLength(1), reason: 'droid katsayısı gövdeye kaydı');
      // Gövdeye kalan pay filo payının DONANIMA gitmeyen kısmı (05.4 s5):
      // droid bir taşıyıcı oldu, payını içindekiyle paylaşıyor.
      expect(
        katsayilar.first *
            TasarimGirdileri.droidFiloTavani *
            ItemBudget.shares[SlotType.laser]! /
            HullClass.all.first.laserSlots,
        closeTo(
          ItemBudget.shares[SlotType.droid]! *
              (1 - Turetilenler.droidDonanimPayi),
          1e-9,
        ),
      );
      // Donanım katsayısı da gövdeye bakmıyor: aynı sebep, aynı bölme.
      final donanim = {
        for (final govde in HullClass.all)
          ItemBudget.droidDonanimKatsayisi(govde),
      };
      expect(donanim, hasLength(1));
    });
  });

  group('08.4 · A = D, puanlarda değil gerçekleşende', () {
    final ref = ReferansCozumu.stats;
    final a = CombatGlossary.saldiriDps(ref);
    final d = CombatGlossary.ehp(ref) / TasarimGirdileri.referansTTK;

    // KARAR 08.4 s1
    test('referans TTK ilan edilen T — dağıtımın tek sınavı', () {
      // 08'in değişmezi: referans TTK = T (±%2). Tutmadığında düzeltilecek
      // yer gövde havuzu (08.5), bütçe payları değil.
      final ttk = CombatGlossary.ttk(CombatGlossary.ehp(ref), a);
      expect(
        ttk,
        closeTo(
          TasarimGirdileri.referansTTK,
          TasarimGirdileri.referansTTK * 0.02,
        ),
        reason: 'dağıtım A = D\'yi bozmuş',
      );
      expect(a, closeTo(d, d * 1e-9), reason: 'A ile D ayrışmış');
    });

    // KARAR 08.4 s1
    test('A = D ⟺ TTK = T — kısıt gerçekleşen değerlerde', () {
      // Denkliğin kendisi sınanıyor: saldırıyı iki katına çıkaran build'de
      // TTK yarıya iniyor ve A tam olarak 2D oluyor. Kısıt puanlarda
      // yazılsaydı bu oran tutmazdı.
      final hizli = ref.copyWith(
        laser: LaserStats(
          id: ref.laser.id,
          name: ref.laser.name,
          damage: ref.laser.damage * 2,
          fireInterval: ref.laser.fireInterval,
          range: ref.laser.range,
        ),
        roketHasari: ref.roketHasari * 2,
      );
      final hizliA = CombatGlossary.saldiriDps(hizli);
      final hizliD = CombatGlossary.ehp(hizli) / TasarimGirdileri.referansTTK;
      expect(hizliA, closeTo(2 * a, a * 1e-9));
      expect(hizliD, closeTo(d, d * 1e-9), reason: 'saldırı savunmaya sızdı');
      expect(
        CombatGlossary.ttk(CombatGlossary.ehp(hizli), hizliA),
        closeTo(TasarimGirdileri.referansTTK / 2, 1e-6),
      );
      // Ters yön: havuzu iki katına çıkarınca D iki katı, TTK iki katı.
      final kalin = ref.copyWith(
        maxHull: 2 * ref.maxHull + ref.maxShield,
      );
      expect(
        CombatGlossary.ehp(kalin) / TasarimGirdileri.referansTTK,
        closeTo(2 * d, d * 1e-9),
      );
      expect(
        CombatGlossary.ttk(
          CombatGlossary.ehp(kalin),
          CombatGlossary.saldiriDps(kalin),
        ),
        closeTo(2 * TasarimGirdileri.referansTTK, 1e-6),
      );
    });

    // KARAR 08.4 s1
    test('bir savunma puanı, bir saldırı puanıyla AYNI gerçekleşen gücü alıyor',
        () {
      // Savunma çapası elle konmuş bir fiyat değil, A = D kurundan çözülüyor:
      // bir puanın aldığı havuz, azaltmayla EHP'ye dönüp T'ye bölününce
      // saldırı puanının DPS'ine eşit çıkmak zorunda.
      final savunmaD =
          Turetilenler.savunmaCapasi *
          Turetilenler.referansEhpCarpani /
          TasarimGirdileri.referansTTK;
      expect(
        savunmaD,
        closeTo(Turetilenler.saldiriPuaniDps, Turetilenler.saldiriPuaniDps * 1e-12),
        reason: 'puan başına güç kanallar arasında ayrışmış',
      );
      expect(Turetilenler.savunmaCapasi, greaterThan(0));
    });

    // KARAR 08.4 s1
    test('savaş puanı dayanıklılığı EHP değil EHP ÷ T okuyor', () {
      // İki kanalın aynı birime çevrildiği yer burası; kur ayrı bir girdi
      // değil, hedef TTK'nın kendisi. Referansta A = D olduğu için savaş
      // puanı tam olarak A × sistem × ölçeğe iniyor.
      expect(
        CombatGlossary.droidDps(ref),
        0,
        reason: 'filo referansa girmiş — ölçüm kendi kendini sayıyor',
      );
      final beklenen =
          math.sqrt(a * d) *
          CombatGlossary.sistemCarpani(CombatGlossary.sistemPuaniOf(ref)) *
          TasarimGirdileri.brOlcegi;
      expect(CombatGlossary.battleRating(ref), closeTo(beklenen, 1e-6));
      expect(
        CombatGlossary.battleRating(ref),
        closeTo(
          a *
              CombatGlossary.sistemCarpani(CombatGlossary.sistemPuaniOf(ref)) *
              TasarimGirdileri.brOlcegi,
          1e-6,
        ),
      );
    });
  });
}
