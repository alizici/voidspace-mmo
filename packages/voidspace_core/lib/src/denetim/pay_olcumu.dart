import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../progression/budget.dart';
import '../progression/fiyat_cozumu.dart';
import '../progression/catalogue.dart';
import '../progression/hull.dart';
import '../progression/item.dart';
import '../progression/loadout.dart';

/// Ölçülen gruplar: gövde ve dört yuva grubu — 08'in pay ilan ettiği beşli.
enum PayGrubu {
  govde('Gövde', null),
  lazer('Lazer', SlotType.laser),
  jenerator('Jeneratör', SlotType.generator),
  roketatar('Roketatar', SlotType.launcher),
  cpu('CPU', SlotType.cpu),
  droid('Droid', SlotType.droid);

  const PayGrubu(this.ad, this.yuva);

  final String ad;

  /// Gövdenin yuvası yok: o, yuvaların taşıyıcısı.
  final SlotType? yuva;

  /// İlan edilen pay (08.1), yüzde.
  double get ilanEdilen =>
      yuva == null ? ItemBudget.hullShare : ItemBudget.shares[yuva]!;
}

/// PAY ÖLÇÜMÜ — yuva gruplarının GERÇEKLEŞEN payı, Shapley ile.
///
/// 08 marjinal fiyatla DAĞITIR, 16 Shapley ile ÖLÇER. Marjinal fiyatlar
/// toplandığında gerçekleşen gücü aşıyor: çarpımsal statlar birbirini
/// tamamlıyor, havuz büyüdükçe zırhın değeri artıyor. Shapley'nin verimlilik
/// aksiyomu tamamlayıcılıktan doğan fazlayı adil dağıtıyor ve tam olarak
/// toplama eşitleniyor; "ilan edilen pay ≠ ölçülen pay" farkı her zaman var
/// ve küçük kaldığı sürece sağlıklı.
///
/// Oyun: v(S) = yalnız S'deki grupları taşıyan referans kitin gerçekleşen
/// gücü, kur biriminde toplamsal (saldırı + dayanıklılık ÷ T + sistem). Gövde yoksa
/// havuzlar sıfır, lazer yoksa saldırı sıfır. Payların ilanla karşılaştırılması
/// bir doğrulama, ayar kolu değil (08.1).
/// KARAR 08.3 s2
abstract final class PayOlcumu {
  static const List<PayGrubu> gruplar = PayGrubu.values;

  /// Referans kit: her yuvaya C-I rafındaki tasarım, +0, kimlikten roll;
  /// jeneratörler yarı yarıya kalkan ve hız, CPU'lar yarı yarıya tamir ve
  /// nişan (04.5).
  static Map<String, ItemInstance> referansKit(HullClass hull) {
    final kit = <String, ItemInstance>{};
    // Droid filosu TAM: filo tavanı kadar standart droid, gövdeden bağımsız.
    // Her droid DONATILMIŞ (05.4 s5): droid bir taşıyıcı ve boş droid
    // vurmuyor; ölçüm boş filoyla yapılsaydı filo payı sıfır çıkardı ve
    // ilan edilen pay ile ölçülen arasındaki fark modelin değil kitin
    // eksikliğinden gelirdi.
    for (var i = 0; i < TasarimGirdileri.droidFiloTavani; i++) {
      final id = 'ref-filo-$i';
      kit[id] = ItemInstance(instanceId: id, specId: Catalogue.dr1.id);
      final donanimId = 'ref-filo-donanim-$i';
      kit[donanimId] = ItemInstance(
        instanceId: donanimId,
        specId: Catalogue.pl1.id,
      );
    }
    for (final yuva in SlotType.values) {
      for (var i = 0; i < hull.slotCount(yuva); i++) {
        final spec = switch (yuva) {
          SlotType.laser => Catalogue.pl1,
          SlotType.generator => i.isEven ? Catalogue.df1 : Catalogue.th1,
          SlotType.launcher => Catalogue.mk1,
          SlotType.cpu =>
            i.isEven
                ? Catalogue.byId['cpu_repair']!
                : Catalogue.byId['cpu_scope']!,
          SlotType.droid => Catalogue.dr1,
        };
        final id = 'ref-${yuva.name}-$i';
        kit[id] = ItemInstance(instanceId: id, specId: spec.id);
      }
    }
    return kit;
  }

  /// [gruplar]'daki yuvaları doldurulmuş donatım.
  static Loadout loadoutFor(Set<PayGrubu> gruplar, HullClass hull) {
    final loadout = Loadout(hullId: hull.id);
    for (final g in gruplar) {
      final yuva = g.yuva;
      if (yuva == null) continue;
      for (var i = 0; i < hull.slotCount(yuva); i++) {
        loadout.equip(SlotRef(yuva, i), 'ref-${yuva.name}-$i');
      }
    }
    return loadout;
  }

  /// v(S): yalnız [gruplar]'ı taşıyan build'in gerçekleşen gücü.
  static double gucFor(Set<PayGrubu> gruplar) {
    final hull = HullClass.bastion;
    final kit = referansKit(hull);
    final loadout = loadoutFor(gruplar, hull);
    final filo = gruplar.contains(PayGrubu.droid)
        ? [
            for (var i = 0; i < TasarimGirdileri.droidFiloTavani; i++)
              'ref-filo-$i',
          ]
        : const <String>[];
    final vector = LoadoutResolver.vectorOf(
      loadout,
      kit,
      Catalogue.byId,
      filo: filo,
      droidDonanimi: {
        for (final id in filo)
          id: ['ref-filo-donanim-${id.split('-').last}'],
      },
    );
    // Gövde oyunda değilse havuzları sıfır: aynı yuvalar, boş gemi.
    final tasiyici = gruplar.contains(PayGrubu.govde)
        ? hull
        : HullClass(
            id: hull.id,
            name: hull.name,
            tier: hull.tier,
            kademeCarpani: hull.kademeCarpani,
            laserSlots: hull.laserSlots,
            generatorSlots: hull.generatorSlots,
            launcherSlots: hull.launcherSlots,
            cpuSlots: hull.cpuSlots,

            baseHull: 0,
            baseShield: 0,
            baseSpeed: hull.baseSpeed,
            price: hull.price,
          );
    final stats = LoadoutResolver.apply(
      tasiyici,
      vector,
      equippedLasers: LoadoutResolver.equippedCount(
        loadout,
        kit,
        Catalogue.byId,
        SlotType.laser,
      ),
      droidCarpanlari: LoadoutResolver.droidCarpanlariOf(
        filo,
        kit,
        Catalogue.byId,
      ),
    );
    // Gerçekleşen güç KUR biriminde ve TOPLAMSAL: A = DPS, D = EHP ÷ T
    // (09.2, 1 DPS ≡ T EHP). Savaş puanının geometrik ortalaması burada
    // kullanılmıyor: o bir sıralama ölçüsü, pay muhasebesi değil — iki kanalı
    // birden istediği için lazeri ve gövdeyi veto oyuncusu yapar ve payı
    // onlara yığar. Tamamlayıcılık kanal İÇİNDE ölçülüyor: havuz × zırh.
    // Sistem kanalı da kur biriminde: bir sistem puanı 2A ÷ 100 DPS eder
    // (03.1, 09.5); A referansın saldırısı. Hız jeneratörleri ve nişan CPU'su
    // yalnız buraya yazıyor — sayılmasalar payları yok görünürdü.
    //
    // Kur FİYATLAYANDAN okunuyor (`FiyatCozumu.sistemPuaniDps`), çıplak
    // referanstan değil: fiyat dolu referansta ölçülüyor (03.2 s2), yani bir
    // sistem puanı orada daha çok DPS ediyor ve eşya daha az birim veriyor.
    // İki taraf farklı A okusaydı hız ve menzil eşyası bir yerde pahalı,
    // öteki yerde ucuz sayılır, fark da payın sapması gibi görünürdü.
    // KARAR 03.2 s2
    final sistemDps =
        CombatGlossary.sistemPuaniOf(stats) * FiyatCozumu.sistemPuaniDps;
    // Droid grubu iki kanala savaş puanındaki katsayılarıyla (09.6).
    // Roketatar silah (18.1): gücü DPS olarak, bonus olarak değil.
    return CombatGlossary.saldiriDps(stats) +
        CombatGlossary.droidDps(stats) +
        (CombatGlossary.ehp(stats) +
                TasarimGirdileri.droidDayaniklilikKatsayisi *
                    CombatGlossary.droidEhp(stats)) /
            TasarimGirdileri.referansTTK +
        sistemDps;
  }

  /// Shapley değerleri — grup başına güç katkısı; toplamı v(N).
  static Map<PayGrubu, double> shapley() {
    final n = gruplar.length;
    final onbellek = <int, double>{};
    double v(int maske) => onbellek.putIfAbsent(maske, () {
      final s = {
        for (var i = 0; i < n; i++)
          if (maske & (1 << i) != 0) gruplar[i],
      };
      return gucFor(s);
    });
    int faktoriyel(int k) => k <= 1 ? 1 : k * faktoriyel(k - 1);
    final sonuc = <PayGrubu, double>{};
    for (var i = 0; i < n; i++) {
      var toplam = 0.0;
      for (var maske = 0; maske < (1 << n); maske++) {
        if (maske & (1 << i) != 0) continue;
        var boyut = 0;
        for (var j = 0; j < n; j++) {
          if (maske & (1 << j) != 0) boyut++;
        }
        final agirlik =
            faktoriyel(boyut) * faktoriyel(n - boyut - 1) / faktoriyel(n);
        toplam += agirlik * (v(maske | (1 << i)) - v(maske));
      }
      sonuc[gruplar[i]] = toplam;
    }
    return sonuc;
  }

  /// Tam kitin gerçekleşen gücü — verimlilik: Shapley toplamı buna eşit.
  static double get tamGuc => gucFor(gruplar.toSet());

  /// Ölçülen paylar, yüzde.
  static Map<PayGrubu, double> olculenPaylar() {
    final phi = shapley();
    final toplam = tamGuc;
    return {for (final g in gruplar) g: phi[g]! / toplam * 100};
  }

  /// İlan ile ölçülen arasındaki en büyük fark, puan.
  static double get enBuyukFark {
    final olculen = olculenPaylar();
    var fark = 0.0;
    for (final g in gruplar) {
      final d = (olculen[g]! - g.ilanEdilen).abs();
      if (d > fark) fark = d;
    }
    return fark;
  }
}
