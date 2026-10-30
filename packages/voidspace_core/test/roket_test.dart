@Tags(['turetme', 'kod-belge'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 18 · ROKET — roketatar bir silah, mermisi 17'nin ikizi.
///
/// Uzun süre stat eşyasıydı (borç defteri B20). Burada ölçülen: ana stat
/// roket kapsamına gidiyor ve lazerin yaylımına karışmıyor, salvo kadans
/// oranıyla büyüyor ve DPS payı bütçe payında kalıyor, fiyat mermi eğrisinin
/// birim oranı katı, stok ve seçim mermi gibi, savaş puanı roketi sayıyor
/// ama mermisini saymıyor.
void main() {
  TxContext tx() => const TxContext(id: 't', atMillis: 0);

  Hangar donanimli() {
    final h = Hangar(accountId: 'a', credits: 1 << 40);
    h.addItem(const ItemInstance(instanceId: 'l', specId: 'pl1'));
    h.addItem(const ItemInstance(instanceId: 'r', specId: 'mk1'));
    h.activeLoadout
      ..equip(const SlotRef(SlotType.laser, 0), 'l')
      ..equip(const SlotRef(SlotType.launcher, 0), 'r');
    return h;
  }

  ShipStats statlar(Hangar h) =>
      LoadoutResolver.resolve(h.activeLoadout, h.inventory, Catalogue.byId);

  group('18.1 · roketatar bir silah', () {
    // KARAR 18.1 s1
    test('ana stat ROKET kapsamına: lazerin yaylımı değişmiyor', () {
      final h = donanimli();
      final v = LoadoutResolver.vectorOf(
        h.activeLoadout,
        h.inventory,
        Catalogue.byId,
      );
      final roketTaban = v.get('taban_hasar', StatScope.roket);
      expect(roketTaban, greaterThan(0), reason: 'roketatar taban yazmadı');
      expect(
        v.get('taban_hasar', StatScope.gemi),
        closeTo(
          ItemBudget.mainStatValue(Catalogue.pl1, 0, HullClass.starter),
          1e-9,
        ),
        reason: 'roketatarın tabanı lazerin yaylımına karıştı',
      );
      // Salvo tabanı kadans oranıyla.
      final s = statlar(h);
      expect(
        s.roketHasari,
        closeTo(roketTaban * Turetilenler.roketKadansOrani, 1e-9),
      );
      expect(
        Turetilenler.roketKadansOrani,
        closeTo(
          TasarimGirdileri.roketAraligi / TasarimGirdileri.referansAtisAraligi,
          1e-12,
        ),
      );
    });

    test('roketatar boşken salvo yok', () {
      final h = Hangar(accountId: 'a', credits: 1);
      h.addItem(const ItemInstance(instanceId: 'l', specId: 'pl1'));
      h.activeLoadout.equip(const SlotRef(SlotType.laser, 0), 'l');
      final s = statlar(h);
      expect(s.roketHasari, 0);
      expect(CombatGlossary.roketDps(s), 0);
      expect(CombatGlossary.saldiriDps(s), CombatGlossary.expectedDps(s));
    });

    test('roketin DPS payı bütçe payında — referansta yüzde yirmi', () {
      // Roketatar 6,72'lik payla lazer grubunun (26,9) beşte biri: DPS payı da
      // aynı oran olmalı, yoksa kadans oranı fiyatla ayrışmış demek.
      final beklenen =
          TasarimGirdileri.payRoketatar /
          (TasarimGirdileri.payRoketatar + TasarimGirdileri.payLazer);
      expect(RoketOlcumu.dpsPayi, closeTo(beklenen, 1e-6));
      expect(RoketOlcumu.salvoHasari, greaterThan(0));
    });
  });

  group('18.2 · zincir geminin', () {
    // KARAR 18.2 s1
    test('hasar artışı ve kritik salvoyu lazer gibi çarpıyor', () {
      final h = donanimli();
      final s = statlar(h);
      final duz = s.copyWith(damageBonus: 0, critChance: 0);
      final bonuslu = s.copyWith(damageBonus: 0.5, critChance: 0);
      expect(
        CombatGlossary.roketSalvo(bonuslu),
        closeTo(CombatGlossary.roketSalvo(duz) * 1.5, 1e-6),
      );
      expect(
        CombatGlossary.expectedRoketSalvo(s.copyWith(critChance: 1)),
        closeTo(
          CombatGlossary.roketSalvo(s.copyWith(critChance: 0)) *
              s.critMultiplier,
          1e-6,
        ),
      );
      // Toplam saldırı ve savaş puanı roketi sayıyor.
      expect(
        CombatGlossary.saldiriDps(s),
        closeTo(
          CombatGlossary.expectedDps(s) + CombatGlossary.roketDps(s),
          1e-9,
        ),
      );
      expect(
        CombatGlossary.battleRating(s),
        greaterThan(CombatGlossary.battleRating(s.copyWith(roketHasari: 0))),
        reason: 'savaş puanı roketi saymıyor',
      );
    });
  });

  group('18.3 · roket mermisi', () {
    // KARAR 18.3 s1
    test('RK-1 bedava, üstü mermi eğrisinin birim oranı katı', () {
      expect(Roket.rk1.bedava, isTrue);
      expect(Roket.hepsi, hasLength(TasarimGirdileri.mermiCarpanTavani));
      for (final r in Roket.hepsi.skip(1)) {
        expect(r.bedava, isFalse);
        expect(
          r.fiyat,
          closeTo(
            Turetilenler.mermiFiyati(r.carpan) * Turetilenler.roketBirimOrani,
            1e-9,
          ),
        );
        // Hasar başına bedel mermiyle aynı.
        expect(
          Turetilenler.roketHasarBedeli(r.carpan),
          closeTo(Turetilenler.mermiHasarBedeli(r.carpan), 1e-9),
          reason: '${r.id}: iki mermi iki ekonomi',
        );
      }
      expect(
        Turetilenler.roketBirimOrani,
        closeTo(
          Turetilenler.roketKadansOrani * Turetilenler.roketatarYuvaKatsayisi,
          1e-12,
        ),
      );
      expect(Roket.novaIleSatilir, isFalse);
    });

    test('alım krediyle, RK-1 satılmıyor', () {
      final h = Hangar(accountId: 'a', credits: 1 << 40);
      expect(
        HangarRules.roketAl(h, 'RK-1', 5, tx()),
        HangarError.notPurchasable,
      );
      final onceki = h.credits;
      expect(HangarRules.roketAl(h, 'RK-3', 4, tx()), isNull);
      expect(h.roketSayisi('RK-3'), 4);
      expect(onceki - h.credits, Roket.byId('RK-3')!.fiyatFor(4));
    });
  });

  group('18.4 · stok ve seçim', () {
    // KARAR 18.4 s1
    test('stoksuz seçilemez, biten RK-1\'e düşer, kayıt gidip geliyor', () {
      final h = Hangar(accountId: 'a', credits: 1 << 40);
      expect(HangarRules.roketSec(h, 'RK-2'), HangarError.roketYok);
      h.roketEkle('RK-2', 2);
      expect(HangarRules.roketSec(h, 'RK-2'), isNull);
      expect(h.seciliRoket.id, 'RK-2');
      expect(h.roketHarca('RK-2', 1), 1);
      expect(h.roketHarca('RK-2', 1), 1);
      expect(h.roketSayisi('RK-2'), 0);
      expect(h.seciliRoket.id, 'RK-1', reason: 'biten RK-1\'e düşmedi');
      expect(h.roketHarca('RK-1', 1), 1, reason: 'bedava roket stok yedi');

      h.roketEkle('RK-4', 3);
      h.roketSec('RK-4');
      final geri = Hangar.fromJson(h.toJson());
      expect(geri.roketSayisi('RK-4'), 3);
      expect(geri.seciliRoket.id, 'RK-4');
    });
  });

  group('18.5 · NOVA satmıyor, mermisi BR saymıyor', () {
    // KARAR 18.5 s1
    test('kilit kapalı: roket mermisi krediyle alınıyor, NOVA kıpırdamıyor', () {
      // 17.7'nin ikizi: mermi krediyle, kredi zamanla. ×6 salvo parayla
      // değil sabırla. Kilit açılırsa 15.4'ün tavanı anlamsızlaşır.
      expect(TasarimGirdileri.novaMermiSatiyor, isFalse);
      expect(Roket.novaIleSatilir, isFalse);
      expect(
        Roket.novaIleSatilir,
        TasarimGirdileri.novaMermiSatiyor,
        reason: 'roket kilidi mermininkinden ayrışmış',
      );
      expect(Mermi.novaIleSatilir, Roket.novaIleSatilir);

      final h = Hangar(accountId: 'a', credits: 1 << 40, premium: 5000);
      final krediOncesi = h.credits;
      expect(HangarRules.roketAl(h, 'RK-3', 4, tx()), isNull);
      expect(h.premium, 5000, reason: 'roket NOVA hesabından ödendi');
      expect(krediOncesi - h.credits, Roket.byId('RK-3')!.fiyatFor(4));
      // NOVA mağazasının dört kaleminin hiçbiri roket değil.
      expect(
        NovaKalemi.values.map((k) => k.name),
        isNot(contains('roket')),
      );
    });

    // KARAR 18.5 s1
    test('savaş puanı roketATARI sayıyor, roket MERMİSİNİ saymıyor', () {
      // Puan geminin SÜRDÜRÜLEBİLİR gücünü ölçüyor: bütçeli bir silah olan
      // roketatar puana giriyor, stoktan yenen mermi çarpanı girmiyor.
      // Kapılar ve eşleştirme yine çalışıyor, çünkü mermi simetrik.
      final h = donanimli();
      final once = CombatGlossary.battleRating(statlar(h));
      expect(once, greaterThan(0));
      // Roketatarın kendisi puanda: söküldüğünde puan düşüyor.
      expect(
        once,
        greaterThan(
          CombatGlossary.battleRating(statlar(h).copyWith(roketHasari: 0)),
        ),
        reason: 'roketatar puana girmiyor',
      );

      final tavan = Roket.hepsi.last;
      h.roketEkle(tavan.id, 10);
      expect(HangarRules.roketSec(h, tavan.id), isNull);
      expect(h.seciliRoket.id, tavan.id);
      expect(
        CombatGlossary.battleRating(statlar(h)),
        once,
        reason: 'seçili roket mermisi savaş puanına sızdı',
      );

      // Oysa mermi gerçek salvoyu çarpıyor: fark puanda değil hasarda.
      // Çarpan stata yazılsaydı puan da büyürdü — sınav bu.
      final s = statlar(h);
      final carpanli = s.copyWith(roketHasari: s.roketHasari * tavan.carpan);
      expect(
        CombatGlossary.roketSalvo(carpanli),
        closeTo(CombatGlossary.roketSalvo(s) * tavan.carpan, 1e-6),
      );
      expect(CombatGlossary.battleRating(carpanli), greaterThan(once));
      expect(tavan.carpan, TasarimGirdileri.mermiCarpanTavani);
    });
  });

  group('18.6 · tel', () {
    // KARAR 18.6 s1
    test('atış olayı roket bayrağını sıfır baytla taşıyor', () {
      final w = ByteWriter(16);
      const olay = ShotEvent(
        shooterId: 3,
        targetId: 40001,
        damage: 4164,
        shieldHit: true,
        killed: false,
        crit: true,
        roket: true,
      );
      olay.write(w);
      final bytes = w.take();
      expect(bytes, hasLength(ShotEvent.wireSize));
      final geri = ShotEvent.read(ByteReader(bytes));
      expect(geri.roket, isTrue);
      expect(geri.crit, isTrue);
      expect(geri.shieldHit, isTrue);
      expect(geri.damage, 4164);
      const lazer = ShotEvent(
        shooterId: 3,
        targetId: 4,
        damage: 1,
        shieldHit: false,
        killed: false,
      );
      final w2 = ByteWriter(16);
      lazer.write(w2);
      expect(ShotEvent.read(ByteReader(w2.take())).roket, isFalse);
    });
  });
}
