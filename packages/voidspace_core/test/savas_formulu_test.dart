@Tags(['turetme', 'aralik'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 01 · SAVAŞ FORMÜLÜ — kural belgesinin DEĞİŞMEZLERİ.
///
/// Kural belgesi 10'un tablosu birebir burada. Kuralların hiçbiri "dikkat
/// edelim" değil: her biri bir değişmez olarak yazılıyor ve testte koşuyor —
/// bozulduğu an derleme değil, TEST kırılıyor.
///
/// Bu dosyada denge sabiti yok ve olmayacak. Sayı tablosundaki sabitler
/// değişse bile buradaki testler değişmez; hedeflerin ölçümü
/// `savas_sayilari_test.dart`'ta.
void main() {
  group('01 · zincir', () {
    // KARAR 01.1 s1 · KARAR 01.6 s1
    test('katman sayısı 6 — genişleme kuralı', () {
      // Tek gerçek yasak. Ayrılmış katmanları doldurmak serbest, YENİ katman
      // eklemek değil: yeni bir çarpım katmanı oradaki her statı diğer bütün
      // katmanların üstüne çarpar ve zincirin tamamı yeniden dengelenmek
      // zorunda kalır.
      expect(DamageChain.layerCount, 6);
      expect(StatLayer.values.length, DamageChain.layerCount);

      final hit = DamageChain.resolve(baseDamage: 100);
      expect(hit.stages, hasLength(DamageChain.layerCount));
    });

    // KARAR 01.1 s1
    test('katman SIRASI sabit — L0..L5', () {
      expect(StatLayer.base.code, 'L0');
      expect(StatLayer.additive.code, 'L1');
      expect(StatLayer.conditional.code, 'L2');
      expect(StatLayer.critical.code, 'L3');
      expect(StatLayer.mitigation.code, 'L4');
      expect(StatLayer.flat.code, 'L5');
    });

    // KARAR 01.1 s1
    test('her stat TAM BİR katmana ait', () {
      // Katmansız bir stat, nereye çarpıldığı belirsiz bir sayıdır. Tip
      // sistemi katmanı zorunlu kılıyor; burada denetlenen şey KİMLİKLERİN
      // benzersizliği — iki kayıt aynı kimliği taşırsa hangi katmanın
      // geçerli olduğu çağıranın harita sırasına kalır.
      final ids = Stats.all.map((s) => s.id).toList();
      expect(
        ids.toSet(),
        hasLength(ids.length),
        reason: 'yinelenen stat kimliği',
      );

      for (final stat in Stats.all) {
        expect(
          StatLayer.values,
          contains(stat.layer),
          reason: '${stat.id} tanımsız bir katmana ait',
        );
      }
    });

    // KARAR 01.1 s1
    test('L0 taban ÇARPAN değil — boş yuva ateş etmez', () {
      expect(DamageChain.resolve(baseDamage: 0).amount, 0);
      expect(DamageChain.resolve(baseDamage: 0, damageBonus: 5).amount, 0);
    });

    // KARAR 01.2 s1
    test('L1 TOPLAMSAL — iki bonus çarpılmaz', () {
      final ayri = DamageChain.resolve(baseDamage: 100, damageBonus: 0.5 + 0.5);
      expect(ayri.l1, 200);
      // Çarpımsal olsaydı 100 × 1,5 × 1,5 = 225 çıkardı.
      expect(ayri.l1, isNot(225));
    });

    // KARAR 01.2 s1
    test('L2 AYRILMIŞ ve bugün etkisiz — ama zincirde duruyor', () {
      final hit = DamageChain.resolve(baseDamage: 100, damageBonus: 0.2);
      expect(hit.l2, hit.l1, reason: 'ayrılmış katman bugün sabit 1 olmalı');

      // Kütüphanede koşullu stat YOK ve bilerek yok: koşulu ölçen bir
      // simülasyon olmadan konan stat, ölü stat olur.
      expect(Stats.inLayer(StatLayer.conditional), isEmpty);
    });

    // KARAR 01.2 s1
    test('koşullu bonuslar TOPLAMSAL — iki koşul tuttuğunda patlamaz', () {
      // Kendi katmanına kaçan bir koşullu stat, iki koşul birden tuttuğunda
      // hasarı patlatır ve o kombinasyon zorunlu build olur.
      final birlikte = DamageChain.resolve(
        baseDamage: 100,
        conditionalBonus: 0.4 + 0.4,
      );
      expect(birlikte.l2, closeTo(180, 1e-9));
      expect(birlikte.l2, isNot(closeTo(196, 1e-9)));
    });

    // KARAR 01.1 s1
    test('her katman TABLODAKİ hesabı yapıyor — L0..L5 tek tek', () {
      // Belgedeki katman tablosu satır satır. Sıra sabit ve hesap sabit:
      // biri yer değiştirse (ör. düz ekleme kritikten önce gelse) aynı
      // girdiler başka bir sayı verirdi ve ekrandaki rakamın anlamı kayardı.
      const taban = 1000.0;
      const artis = 0.35; // L1
      const kosul = 0.20; // L2
      const k = 0.25, d = 2.0; // L3
      const azaltma = 0.30, siyirma = 0.10, kafes = 0.15; // L4
      const duz = 40.0; // L5
      final hit = DamageChain.resolve(
        baseDamage: taban,
        damageBonus: artis,
        conditionalBonus: kosul,
        critChance: k,
        critMultiplier: d,
        armorReduction: azaltma,
        graze: siyirma,
        cageEffect: kafes,
        flatDamage: duz,
      );
      expect(hit.l0, taban, reason: 'L0 çarpan değil, başlangıç');
      expect(hit.l1, closeTo(taban * (1 + artis), 1e-9));
      expect(hit.l2, closeTo(hit.l1 * (1 + kosul), 1e-9));
      expect(hit.l3, closeTo(hit.l2 * (1 + k * (d - 1)), 1e-9));
      expect(
        hit.l4,
        closeTo(hit.l3 * (1 - azaltma) * (1 - siyirma) * (1 - kafes), 1e-9),
        reason: 'L4 iki çarpan: savunma ve kafes',
      );
      expect(hit.l5, closeTo(hit.l4 + duz, 1e-9), reason: 'L5 düz EKLEME');
      // UYG katmanı formülün DIŞINDA: zincir havuzlara dokunmuyor, tek sayı
      // üretiyor.
      expect(hit.amount, hit.l5);
    });

    // KARAR 01.2 s1
    test('katman ATAMASI kurala uyuyor — yüzdesel saldırı L1, koşullu L2', () {
      // "Yeni bir yüzdesel saldırı statı L1'e girer, kendi katmanını açmaz."
      // Kritik statları ayrı: onların katmanı L3 ve L3'te başka kimse yok.
      for (final s in Stats.all) {
        if (s.channel != StatChannel.attack) continue;
        if (s.birim != StatBirimi.oran) continue;
        expect(
          s.layer,
          anyOf(StatLayer.additive, StatLayer.critical),
          reason: '${s.id} yüzdesel bir saldırı statı ama L1 de L3 de değil',
        );
      }
      expect(Stats.inLayer(StatLayer.critical).map((s) => s.id).toSet(), {
        'kritik_sansi',
        'kritik_hasari',
      });
      // "Bütün koşullu statlar L2'ye ve YALNIZ L2'ye" — bugün ikisi de kapalı.
      for (final s in Stats.hepsi) {
        expect(
          s.layer == StatLayer.conditional,
          s.id.startsWith('durum_'),
          reason: '${s.id} koşullu katmanın yanlış tarafında',
        );
      }
      // Kafes statları L4'e giriyor, YENİ katman açmadan.
      for (final id in ['delici', 'sertlik', 'kirici', 'zirh_katmani']) {
        expect(Stats.kayit(id)!.layer, StatLayer.mitigation, reason: id);
      }
    });

    // KARAR 01.2 s1
    test('referansın gördüğü azaltma ilan edilen hedef — L4 iki eğri', () {
      // "Referans oyuncunun zırhtan gördüğü azaltma zirhAzaltmaHedefi."
      // Katman ölürse (K çözülmemişse) bu sayı sessizce sıfıra düşer.
      const ref = ShipStats.bastion;
      expect(
        ref.armorReduction,
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-12),
      );
      // L4'ün tek "azaltma" terimi iki eğrinin ÇARPIMI: zırh ve sıyırma
      // toplanmıyor, yoksa ikisi birden yığıldığında hasar sıfırlanabilirdi.
      expect(
        ref.totalMitigation,
        closeTo(
          1 -
              (1 - TasarimGirdileri.zirhAzaltmaHedefi) *
                  (1 - TasarimGirdileri.siyirmaHedefiReferans),
          1e-12,
        ),
      );
      expect(ref.totalMitigation, lessThan(1), reason: 'azaltma hasarı yuttu');
    });
  });

  group('02 · uygulama', () {
    // KARAR 01.3 s1
    test('kalkan bitmeden gövde EKSİLMEZ', () {
      final stats = ShipStats.bastion;
      var state = ShipSimState.spawn(stats, const Vec2(0, 0));

      state = ShipSim.applyDamage(state, stats.maxShield / 2);
      expect(state.shield, closeTo(stats.maxShield / 2, 1e-9));
      expect(state.hull, stats.maxHull, reason: 'kalkan varken gövde eridi');
    });

    // KARAR 01.3 s1
    test('kalkanı AŞAN hasar gövdeye taşar — tek vuruşta', () {
      final stats = ShipStats.bastion;
      var state = ShipSimState.spawn(stats, const Vec2(0, 0));
      state = ShipSim.applyDamage(state, stats.maxShield + 500);
      expect(state.shield, 0);
      expect(state.hull, closeTo(stats.maxHull - 500, 1e-9));
    });

    // KARAR 01.3 s1
    test('uygulama FORMÜLÜN DIŞINDA — zincir tek sayı üretir', () {
      // Zincirin çıktısı havuzları görmüyor: aynı sayı hem ekrandaki rakam
      // hem BR hesabındaki beklenen çıktı. Üçü aynı sayıyı görmezse oyuncunun
      // gördüğü rakam ile aldığı hasar sessizce ayrışır.
      final hit = DamageChain.resolve(baseDamage: 1000);
      expect(hit.amount, 1000);
    });

    // KARAR 01.3 s1
    test('zırh havuzların ÇARPANI — uygulama onu İKİNCİ kez indirmiyor', () {
      // Azaltma L4'te, havuzlara girmeden ÖNCE uygulanıyor; zırh kendi başına
      // bir havuz değil. `applyDamage` zincirden çıkmış sayıyı alıyor: orada
      // bir kez daha azaltsaydı zırh iki kez sayılır ve oyuncunun gördüğü
      // rakam ile eriyen havuz sessizce ayrışırdı.
      const zirhli = ShipStats.bastion;
      final zirhsiz = zirhli.copyWith(armor: 0, evasion: 0);
      expect(zirhli.totalMitigation, greaterThan(0), reason: 'katman ölü');
      expect(zirhsiz.totalMitigation, 0);
      for (final stats in [zirhli, zirhsiz]) {
        final state = ShipSim.applyDamage(
          ShipSimState.spawn(stats, const Vec2(0, 0)),
          1000,
        );
        expect(
          stats.maxShield - state.shield,
          closeTo(1000, 1e-9),
          reason: 'havuz zırha göre ayrı eridi — azaltma iki kez uygulandı',
        );
      }
    });

    // KARAR 01.3 s1
    test('kalkan ile gövde AYRI havuzlar — tek birleşik can değil', () {
      // Kalkan yenilenir, gövde yenilenmez: ikisi tek havuz olsaydı gövde de
      // kendiliğinden dolardı ve tamirin anlamı kalmazdı.
      const stats = ShipStats.bastion;
      final acilan = ShipSimState.spawn(stats, const Vec2(0, 0));
      expect(acilan.shield, stats.maxShield);
      expect(acilan.hull, stats.maxHull);
      // Kalkanı bitirip gövdeyi kırpan tek vuruş: taşan pay KAYBOLMUYOR.
      final vurulmus = ShipSim.applyDamage(acilan, stats.maxShield + 700);
      expect(vurulmus.shield, 0);
      expect(vurulmus.hull, closeTo(stats.maxHull - 700, 1e-9));
      // Toplam havuzu aşan hasar gemiyi indiriyor, gövdeyi eksiye düşürmüyor.
      final oldu = ShipSim.applyDamage(
        acilan,
        stats.maxShield + stats.maxHull + 1e6,
      );
      expect(oldu.hull, 0);
      expect(oldu.alive, isFalse);
    });
  });

  group('03 · kritik', () {
    // KARAR 01.4 s1
    test('iki biçim de AYNI katmandan besleniyor', () {
      const k = 0.25;
      const d = 2.0;
      final beklenen = DamageChain.resolve(
        baseDamage: 1000,
        critChance: k,
        critMultiplier: d,
        critMode: CritMode.expected,
      );
      expect(beklenen.l3 / beklenen.l2, closeTo(1 + k * (d - 1), 1e-12));

      final vurdu = DamageChain.resolve(
        baseDamage: 1000,
        critChance: k,
        critMultiplier: d,
        critMode: CritMode.rolled,
        critRoll: true,
      );
      expect(vurdu.l3 / vurdu.l2, closeTo(d, 1e-12));
      expect(vurdu.crit, isTrue);
    });

    // KARAR 01.4 s1
    test('zar ORTALAMASI beklenen değere yakınsar', () {
      // Değişmezin kendisi: çalışma anı ile denge ayrışırsa BR yanlış, bütçe
      // yanlış. Uzun vadede ikisi aynı sayıyı vermek ZORUNDA.
      const k = TasarimGirdileri.kritikSansiReferans;
      const d = TasarimGirdileri.kritikCarpaniReferans;
      final roller = PrdRoller(k);
      final random = math.Random(7);

      var toplam = 0.0;
      const n = 400000;
      for (var i = 0; i < n; i++) {
        toplam += DamageChain.resolve(
          baseDamage: 1000,
          critChance: k,
          critMultiplier: d,
          critMode: CritMode.rolled,
          critRoll: roller.roll(random),
        ).amount;
      }

      final olculen = toplam / n;
      final beklenen = 1000 * Turetilenler.kritikBeklenenDeger;
      expect(
        (olculen - beklenen).abs() / beklenen,
        lessThan(0.005),
        reason: 'zar ile beklenen değer ayrıştı — BR ve bütçe yanlış hesaplar',
      );
    });

    // KARAR 01.4 s1
    test('beklenen değer biçiminde KRİTİK OLAYI yok', () {
      // Zar atan bir formülle bütçe kurulamaz; beklenen değerle oynanan bir
      // oyunda da kritik diye bir HİS yoktur. İkisi karışmamalı.
      final hit = DamageChain.resolve(
        baseDamage: 1000,
        critChance: 1,
        critMultiplier: 3,
        critMode: CritMode.expected,
        critRoll: true,
      );
      expect(hit.crit, isFalse);
    });

    // KARAR 01.4 s1
    test('kritik zarı BAĞIMSIZ değil — PRD kuraklığı kesiyor', () {
      // Bağımsız zar, oyuncuların bir kısmına uzun kritik kuraklıkları
      // yaşatır. PRD sabiti şanstan sayısal ÇÖZÜLÜYOR: ilan edilen oran ile
      // yaşanan oran aynı kalmak zorunda.
      const k = TasarimGirdileri.kritikSansiReferans;
      final c = Turetilenler.kritikPrdSabiti;
      expect(Prd.effectiveChance(c), closeTo(k, 1e-9));
      expect(
        c,
        lessThan(k),
        reason: 'PRD sabiti ilan edilen şansın kendisi olamaz — o bağımsız zar',
      );

      // Garantili taban: `⌈1 ÷ C⌉` yaylımda kritik KESİN. Bağımsız zarda
      // böyle bir üst sınır yoktur.
      final garanti = (1 / c).ceil();
      final roller = PrdRoller(k);
      final random = math.Random(11);
      var artArda = 0;
      var enUzunKuraklik = 0;
      for (var i = 0; i < 60000; i++) {
        if (roller.roll(random)) {
          artArda = 0;
        } else {
          artArda++;
          if (artArda > enUzunKuraklik) enUzunKuraklik = artArda;
        }
      }
      expect(
        enUzunKuraklik,
        lessThan(garanti),
        reason: 'kuraklık kesilmiyor — dağılımın kuyruğu açık',
      );
      // Şans kaçırdıkça büyüyor ve garanti adımında tam 1'e varıyor: kuyruk
      // orada kesiliyor.
      final sayac = PrdRoller(k);
      expect(sayac.currentChance, closeTo(c, 1e-12));
      sayac.kacirmayiGeriYukle(garanti - 2);
      expect(sayac.currentChance, lessThan(1), reason: 'garanti erken geldi');
      sayac.kacirmayiGeriYukle(garanti - 1);
      expect(sayac.currentChance, 1.0, reason: 'garantili taban yok');
    });
  });

  group('04 · kaçınma', () {
    // KARAR 01.5 s1
    test('kaçınma hasarı ASLA sıfırlamaz', () {
      // İkili ıskalama geri gelirse ekran ile sistem çelişir: oyuncu merminin
      // çarptığını görüyor, sistem "ıskaladın" diyor.
      for (final kacinma in [1.0, 100.0, 10000.0, 1e9]) {
        final siyirma = SavunmaEgrileri.siyirma(kacinma, 50);
        final hit = DamageChain.resolve(baseDamage: 1000, graze: siyirma);
        expect(
          hit.amount,
          greaterThan(0),
          reason: 'kaçınma $kacinma hasarı sıfırladı',
        );
      }
    });

    // KARAR 01.5 s1
    test('sıyırma TAVANI aşılamaz', () {
      for (final kacinma in [1.0, 500.0, 1e6, 1e12]) {
        expect(
          SavunmaEgrileri.siyirma(kacinma, 50),
          lessThanOrEqualTo(TasarimGirdileri.siyirmaTavani),
        );
      }
    });

    // KARAR 01.5 s1
    test('kaçınma zırhın KARDEŞİ — ikisi de L4, aynı biçim', () {
      expect(Stats.evasion.layer, StatLayer.mitigation);
      expect(Stats.armor.layer, StatLayer.mitigation);

      // Aynı doyum biçimi, farklı K: eğri tek yerde tanımlı.
      expect(
        SavunmaEgrileri.doyum(100, SavunmaEgrileri.kFor(100, 0.3)),
        closeTo(0.3, 1e-12),
      );
      expect(
        SavunmaEgrileri.doyum(100, SavunmaEgrileri.kFor(100, 0.15)),
        closeTo(0.15, 1e-12),
      );
    });

    // KARAR 01.5 s1
    test('İSABET statı YOK — karşılığı olmayan savunma statı eklenmedi', () {
      expect(
        Stats.all.where((s) => s.id.contains('isabet')),
        isEmpty,
        reason: 'kütüphaneye ölü bir satır eklendi',
      );
    });

    // KARAR 01.5 s1
    test('sıyırma hedefi zırhın YARISI — kardeşler ama zırh baskın', () {
      expect(
        TasarimGirdileri.siyirmaHedefiReferans * 2,
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-12),
      );
      const ref = ShipStats.bastion;
      expect(
        ref.graze,
        closeTo(TasarimGirdileri.siyirmaHedefiReferans, 1e-12),
        reason: 'referans build ilan edilen sıyırmayı görmüyor',
      );
      expect(
        ref.armorReduction,
        greaterThan(ref.graze),
        reason: 'kaçınma zırhı geçmiş — kardeşlik bozuldu',
      );
      // Tavan da eğri de yerinde: eğri hasarın SIFIRLANMAMASINI, tavan
      // yığmanın bir yerde durmasını garanti ediyor.
      expect(
        TasarimGirdileri.siyirmaTavani,
        greaterThan(TasarimGirdileri.siyirmaHedefiReferans),
      );
      expect(TasarimGirdileri.siyirmaTavani, lessThan(1));
    });

    // KARAR 01.5 s1
    test('sıyırma ISKALAMA değil — mermi çarpar, rakam soluk gösterilir', () {
      const ref = ShipStats.bastion;
      final siyiran = DamageChain.resolve(baseDamage: 1000, graze: ref.graze);
      expect(
        siyiran.grazed,
        isTrue,
        reason: 'ekranın soluk rakam çizeceği bayrak yok',
      );
      expect(siyiran.amount, closeTo(1000 * (1 - ref.graze), 1e-9));
      expect(siyiran.amount, greaterThan(0));
      // Sıyırma yoksa bayrak da yok: her vuruşu sıyırma diye göstermek
      // rakamın anlamını yok ederdi.
      expect(DamageChain.resolve(baseDamage: 1000).grazed, isFalse);
    });
  });

  group('05 · genişleme', () {
    // KARAR 01.6 s1
    test('yeni stat MEVCUT bir katmana girer — katman sayısı değişmez', () {
      // Kütüphanenin tamamı altı katmanın içinde durmak zorunda.
      final kullanilan = Stats.all.map((s) => s.layer).toSet();
      expect(kullanilan.length, lessThanOrEqualTo(DamageChain.layerCount));
      expect(StatLayer.values.length, DamageChain.layerCount);
    });

    // KARAR 01.2 s1 · KARAR 01.6 s1
    test('L4 ikinci çarpanı AYRILMIŞ — bugün her zaman 1', () {
      final kafessiz = DamageChain.resolve(baseDamage: 1000);
      expect(kafessiz.l4, kafessiz.l3);

      // Kafes geldiği gün zincirin ŞEKLİ değişmeyecek, yalnız bu çarpan 1
      // olmaktan çıkacak.
      final kafesli = DamageChain.resolve(baseDamage: 1000, cageEffect: 0.2);
      expect(kafesli.l4, closeTo(kafessiz.l4 * 0.8, 1e-9));
      expect(kafesli.stages, hasLength(DamageChain.layerCount));
    });
  });

  group('06 · PvE ↔ PvP', () {
    // KARAR 01.7 s1
    test('TEK formül, tek katsayı', () {
      final pve = DamageChain.resolve(baseDamage: 1000);
      final pvp = DamageChain.resolve(baseDamage: 1000, pvpMultiplier: 0.5);
      expect(pvp.amount, closeTo(pve.amount * 0.5, 1e-9));
      // Katsayı zincirin SONUNDA: katmanların hiçbiri değişmiyor.
      expect(pvp.stages, pve.stages);
    });

    // KARAR 01.7 s1
    test('katsayı bugün ETKİSİZ — kol takılı, çekilmiyor', () {
      // Katsayı tepe tabloda tanımlı ve zincir onu son çarpan olarak okuyor;
      // bugünkü değeri 1, çünkü doğal PvP TTK'sı zaten hedef bantta.
      expect(TasarimGirdileri.pvpCarpani, 1.0);
      final pve = DamageChain.resolve(baseDamage: 1000, damageBonus: 0.4);
      final pvp = DamageChain.resolve(
        baseDamage: 1000,
        damageBonus: 0.4,
        pvpMultiplier: TasarimGirdileri.pvpCarpani,
      );
      expect(pvp.amount, pve.amount);
      expect(pvp.stages, pve.stages, reason: 'katsayı katmanlara sızdı');
      // Kol çekildiğinde ayrı formül DEĞİL, aynı formülde tek çarpan: her
      // katman aynı kalıyor, yalnız çıktı ölçekleniyor.
      final cekilmis = DamageChain.resolve(
        baseDamage: 1000,
        damageBonus: 0.4,
        pvpMultiplier: 0.8,
      );
      expect(cekilmis.stages, pve.stages);
      expect(cekilmis.amount, closeTo(pve.amount * 0.8, 1e-9));
    });
  });

  group('07 · sözlük', () {
    // KARAR 01.8 s1
    test('yaylım · DPS · EHP · TTK tek yerde tanımlı ve tutarlı', () {
      const stats = ShipStats.bastion;
      expect(
        CombatGlossary.dps(stats),
        closeTo(CombatGlossary.volley(stats) / stats.laser.fireInterval, 1e-9),
      );
      expect(
        CombatGlossary.ttk(
          CombatGlossary.ehp(stats),
          CombatGlossary.dps(stats),
        ),
        closeTo(CombatGlossary.ttkBetween(stats, stats), 1e-9),
      );
    });

    // KARAR 01.8 s1
    test('EHP azaltmayı HAVUZLARIN ÇARPANI olarak sayar', () {
      const stats = ShipStats.bastion;
      // Zırh kendi başına bir havuz DEĞİL: kalkanı da gövdeyi de aynı oranda
      // büyütüyor. Bu test bir zamanlar `totalMitigation == 0` diyordu, çünkü
      // eğrinin K'sı alan 04'ü bekliyordu ve azaltma hep sıfır dönüyordu.
      expect(stats.totalMitigation, greaterThan(0), reason: 'katman ölü');
      expect(
        CombatGlossary.ehp(stats),
        closeTo(
          (stats.maxShield + stats.maxHull) / (1 - stats.totalMitigation),
          1e-9,
        ),
      );
      // Azaltma SIFIRSA özdeşlik havuzların toplamına iniyor.
      final zirhsiz = stats.copyWith(armor: 0, evasion: 0);
      expect(
        CombatGlossary.ehp(zirhsiz),
        closeTo(zirhsiz.maxShield + zirhsiz.maxHull, 1e-9),
      );
    });

    // KARAR 01.1 s1 · KARAR 01.8 s1
    test('yaylım TAKILI namludan — kapasiteden değil', () {
      const stats = ShipStats.bastion;
      final tek = stats.copyWith(equippedLasers: 1);
      expect(
        CombatGlossary.volley(tek),
        closeTo(CombatGlossary.volley(stats) / stats.equippedLasers, 1e-9),
      );
      expect(CombatGlossary.volley(stats.copyWith(equippedLasers: 0)), 0);
    });
  });

  group('09 · disiplin', () {
    // KARAR 01.2 s1
    test('L5 payı tavanı AŞAMAZ — düz ekleme zinciri ele geçiremez', () {
      for (final duz in [10.0, 1000.0, 1e6]) {
        final hit = DamageChain.resolve(baseDamage: 1000, flatDamage: duz);
        expect(
          hit.flatShare,
          lessThanOrEqualTo(TasarimGirdileri.sonHasarTavani + 1e-12),
          reason: 'düz ekleme $duz zinciri ele geçirdi',
        );
      }
    });

    // KARAR 01.1 s1
    test('düz AZALTMA hasarı eksiye düşürmez', () {
      final hit = DamageChain.resolve(baseDamage: 100, flatMitigation: 1e6);
      expect(hit.amount, 0);
    });
  });
}
