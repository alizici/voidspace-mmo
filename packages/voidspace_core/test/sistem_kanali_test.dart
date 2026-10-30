@Tags(['turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 09.5 · SİSTEM KANALI SAVAŞ PUANINA GİRİYOR.
///
/// Uzun süre formül vardı, çağıran yoktu: sistem kanalı BR'de sıfırdı.
/// Burada denetlenen şey bağlantı — puan donanımın oranlarından çıkıyor,
/// tavanda duruyor, gövdenin taban hızını saymıyor.
void main() {
  const ref = ShipStats.bastion;
  final tabanBr = CombatGlossary.battleRating(ref);

  test(
    'fiyat referansının sistem puanı sıfır; taban dolu referansın kanal gücü',
    () {
      // KARAR 09.5 s1
      // Fiyat referansı çıplak (03.2): sistem puanı sıfır, ölçek onu
      // etkilemiyor. Merdivenin tabanı dolu referansın puanı (04.5, 09.7);
      // referansın kendi sistem puanı ölçekle birlikte 3.600'e çözülüyor.
      expect(CombatGlossary.sistemPuaniOf(ref), 0);
      expect(tabanBr, greaterThan(0));
      expect(CombatGlossary.brTabani, TasarimGirdileri.ilkUnvanEsigi);
      final kanal = CombatGlossary.battleRating(
        ReferansCozumu.stats.copyWith(
          rangeBonus: 0,
          speedBonus: 0,
          boostRechargeBonus: 0,
        ),
      );
      expect(kanal, closeTo(CombatGlossary.brTabani, 1));
    },
  );

  test('donanımın oranları katsayıyla puana, puan çarpana dönüyor', () {
    // KARAR 09.5 s1
    final s = ref.copyWith(rangeBonus: 0.20, speedBonus: 0.20);
    final puan = CombatGlossary.sistemPuaniOf(s);
    expect(
      puan,
      closeTo(
        20 * TasarimGirdileri.sistemKatsayisiMenzil +
            20 * TasarimGirdileri.sistemKatsayisiHiz,
        1e-9,
      ),
    );
    expect(
      CombatGlossary.battleRating(s),
      closeTo(tabanBr * CombatGlossary.sistemCarpani(puan), 1e-6),
    );
    expect(CombatGlossary.battleRating(s), greaterThan(tabanBr));
  });

  test('itki dolumu da sayılıyor, en küçük katsayıyla', () {
    // KARAR 09.5 s1
    final s = ref.copyWith(boostRechargeBonus: 0.10);
    expect(
      CombatGlossary.sistemPuaniOf(s),
      closeTo(10 * TasarimGirdileri.sistemKatsayisiItki, 1e-9),
    );
  });

  test('tavan: %5.200 hız bile çarpanı tavanda bırakıyor', () {
    // KARAR 09.5 s1
    // Parlayan Pembe'de hız oranı 52'ye çıkıyor; sistem yine de en çok
    // sistemTavani puan — çarpımsal kanal sınırsız kalamaz.
    final s = ref.copyWith(speedBonus: 52);
    expect(
      CombatGlossary.battleRating(s),
      closeTo(
        tabanBr * CombatGlossary.sistemCarpani(TasarimGirdileri.sistemTavani),
        1e-6,
      ),
    );
  });

  test('gövdenin taban hızı sistem puanına GİRMİYOR', () {
    // KARAR 09.5 s1
    expect(
      CombatGlossary.battleRating(ref.copyWith(speed: ref.speed * 2)),
      closeTo(tabanBr, 1e-9),
    );
  });

  test('yalnız menzil veren parça artık YÜKSELTME', () {
    // KARAR 09.5 s1
    // Menzil ana statı: cpu_scope. Bir zamanlar alt stat MUTLAK değer olarak
    // saklanıyordu ve test onu enjekte ediyordu; rol saklandığından beri
    // (07.5, borç defteri B3) menzili gerçekten veren parça takılıyor.
    // Lazer İKİSİNDE de takılı: silahsız geminin saldırısı sıfır, savaş
    // puanı sıfır; sıfırla sıfır karşılaştırılamaz.
    const l = ItemInstance(instanceId: 'l', specId: 'pl4');
    const a = ItemInstance(instanceId: 'a', specId: 'cpu_scope');
    final inv = {'l': l, 'a': a};
    const lazer = SlotRef(SlotType.laser, 0);
    const yuva = SlotRef(SlotType.cpu, 0);
    final bos = Loadout(hullId: HullClass.bastion.id)..equip(lazer, 'l');
    final ileA = Loadout(hullId: HullClass.bastion.id)
      ..equip(lazer, 'l')
      ..equip(yuva, 'a');
    final brBos = CombatGlossary.battleRating(
      LoadoutResolver.resolve(bos, inv, Catalogue.byId),
    );
    final brA = CombatGlossary.battleRating(
      LoadoutResolver.resolve(ileA, inv, Catalogue.byId),
    );
    expect(brA, greaterThan(brBos), reason: 'menzil savaş puanına girmiyor');
  });

  test('MENZİL en değerlisi — katsayı sıralaması ilan edildiği gibi', () {
    // KARAR 09.5 s1
    // Menzil hem saldırıya hem kaçışa yarıyor; itki dolumu yalnız kaçışa ve
    // şarj sayısıyla sınırlı. Sıralama bozulursa kanal içi değerleme
    // belgeden kopmuş demektir.
    expect(TasarimGirdileri.sistemKatsayisiMenzil, 0.5);
    expect(TasarimGirdileri.sistemKatsayisiHiz, 0.4);
    expect(TasarimGirdileri.sistemKatsayisiItki, 0.3);
    expect(
      TasarimGirdileri.sistemKatsayisiMenzil,
      greaterThan(TasarimGirdileri.sistemKatsayisiHiz),
    );
    expect(
      TasarimGirdileri.sistemKatsayisiHiz,
      greaterThan(TasarimGirdileri.sistemKatsayisiItki),
    );
    // Ve sıralama savaş puanına GEÇİYOR: aynı yüzde üç statta üç farklı BR.
    const yuzde = 0.10;
    final menzilli = CombatGlossary.battleRating(
      ref.copyWith(rangeBonus: yuzde),
    );
    final hizli = CombatGlossary.battleRating(ref.copyWith(speedBonus: yuzde));
    final itkili = CombatGlossary.battleRating(
      ref.copyWith(boostRechargeBonus: yuzde),
    );
    expect(menzilli, greaterThan(hizli));
    expect(hizli, greaterThan(itkili));
    expect(itkili, greaterThan(tabanBr));
  });

  test('TAVAN zorunlu: çarpan en fazla 1,25 ve orada DÜZ kalıyor', () {
    // KARAR 09.5 s1
    // Sistem çarpımsal: geometrik ortalamanın İÇİNDE iki kez sayılıyor.
    // Tavansız bırakılırsa hem saldırıyı hem dayanıklılığı birden büyütür.
    expect(TasarimGirdileri.sistemTavani, 25.0);
    expect(
      CombatGlossary.sistemCarpani(TasarimGirdileri.sistemTavani),
      closeTo(1.25, 1e-12),
    );
    for (final puan in [30.0, 100.0, 5000.0]) {
      expect(CombatGlossary.sistemCarpani(puan), closeTo(1.25, 1e-12));
    }
    // İki kez sayılmanın ölçüsü: tavandaki sistem BR'yi %25 büyütüyor, oysa
    // TEK kanalı %25 büyütmek karekökten geçtiği için yalnız %11,8 veriyor.
    final tekKanal = CombatGlossary.battleRating(
      ref.copyWith(
        maxHull: (ref.maxHull + ref.maxShield) * 1.25 - ref.maxShield,
      ),
    );
    expect(tekKanal / tabanBr, closeTo(1.118, 0.001));
    expect(
      CombatGlossary.battleRating(ref.copyWith(speedBonus: 10)) / tabanBr,
      closeTo(1.25, 1e-9),
    );
    // Kapı bu yüzden en çok DÖRTTE BİR erken açılıyor: sistem yüklü build
    // eşiğin gerektirdiği kanal gücünün %80'iyle geçiyor.
    expect(1 / 1.25, closeTo(0.8, 1e-12));
  });
}
