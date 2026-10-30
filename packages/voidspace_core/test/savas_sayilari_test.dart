@Tags(['turetme', 'aralik'])
library;

import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 01 · SAVAŞ SAYILARI — sayı tablosunun DEĞİŞMEZLERİ.
///
/// Kural belgesi kuralların değişmezlerini ilan ediyordu; burada HEDEFLERİN
/// değişmezleri var: ilan edilen sayı ile ölçülen sonuç aynı mı?
///
/// Tablonun kendi cümlesi: *"Bu tablo bile kaynağı değil, aynası."* Test de
/// öyle — ölçülen satırları koddan okuyor, tabloya bakarak değil.
void main() {
  group('02 · girdi', () {
    test('savaş katmanının tepe tabloya katkısı YEDİ satır', () {
      final savas = TasarimGirdileri.alanin(1).toList();
      expect(savas, hasLength(7));
      expect(savas.map((g) => g.ad).toSet(), {
        'kritikSansiReferans',
        'kritikCarpaniReferans',
        'zirhAzaltmaHedefi',
        'siyirmaTavani',
        'siyirmaHedefiReferans',
        'pvpCarpani',
        'sonHasarTavani',
      });
    });

    test('her girdinin GEREKÇESİ var', () {
      // Gerekçesiz bir sayı, bir sonraki denge turunda gerekçesi sayıya
      // uydurulan bir sayıdır.
      for (final girdi in TasarimGirdileri.hepsi) {
        expect(
          girdi.gerekce.trim(),
          isNotEmpty,
          reason: '${girdi.ad} gerekçesiz',
        );
      }
    });

    test('girdiler ilan edilen değerleri taşıyor', () {
      expect(TasarimGirdileri.kritikSansiReferans, 0.25);
      expect(TasarimGirdileri.kritikCarpaniReferans, 2.00);
      expect(TasarimGirdileri.zirhAzaltmaHedefi, 0.30);
      expect(TasarimGirdileri.siyirmaTavani, 0.40);
      expect(TasarimGirdileri.siyirmaHedefiReferans, 0.15);
      expect(TasarimGirdileri.pvpCarpani, 1.00);
      expect(TasarimGirdileri.sonHasarTavani, 0.10);
    });

    test('sıyırma hedefi zırhın YARISI — kardeş ama baskın değil', () {
      expect(
        TasarimGirdileri.siyirmaHedefiReferans * 2,
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-12),
      );
    });
  });

  group('03 · türetilen', () {
    test('kritik beklenen değeri 1,250', () {
      expect(Turetilenler.kritikBeklenenDeger, closeTo(1.250, 1e-12));
    });

    test('K çarpanları hedeflerden türüyor', () {
      // Sayı tablosu: `Kzırh = referansZırh × 2,333`, `Ksıyırma = × 5,667`.
      expect(Turetilenler.kZirhCarpani, closeTo(2.3333333, 1e-6));
      expect(Turetilenler.kSiyirmaCarpani, closeTo(5.6666667, 1e-6));
    });

    test('K sabitleri alan 04 ile ÇÖZÜLDÜ — elle yazılmadan', () {
      // Uzun süre `null` durdular ve bu bir eksiklik değil, bağımlılığın
      // gizlenmemesiydi: tahmin edilmiş bir sabit, alan geldiğinde kimsenin
      // geri dönüp düzeltmediği sabittir.
      //
      // Alan 04 referans zırhı (1.000) ve kaçınmayı (300) ilan etti; iki sabit
      // de kendiliğinden çıktı. Hiçbir yere 2.333,3 yazılmadı.
      expect(Turetilenler.kZirh, closeTo(2333.3333, 1e-3));
      expect(Turetilenler.kSiyirma, closeTo(1700.0, 1e-9));
      expect(
        Turetilenler.kZirh,
        BekleyenGirdiler.referansZirh * Turetilenler.kZirhCarpani,
        reason: 'K elle yazılmış — çarpandan türemiyor',
      );

      // Bekleyenler listesi "hâlâ bekleyenler": çözülen sabit ÇIKAR. Bugün
      // yalnız gövde kademesi merdiveni bekliyor ve o alan 08'i bekliyor,
      // çünkü kademe çarpanı rank merdivenine bağlı ve rank büyüme
      // katmanında — savaş katmanı oradan okuyamaz.
      // Alan 08 gövde merdivenini de çözdü; bekleyen sabit KALMADI.
      expect(BekleyenGirdiler.bekleyenler, isEmpty);
    });

    test('özdeşlik referanstan BAĞIMSIZ — hangi sayı gelirse gelsin', () {
      // Referans zırh ne olursa olsun, türetilen K referansta tam olarak
      // ilan edilen azaltmayı vermek zorunda. Alan 04 bir sayı yazdığı an bu
      // özdeşlik onu doğrulayacak — elle bir K girilmeyecek.
      for (final referans in [50.0, 400.0, 3200.0]) {
        expect(
          SavunmaEgrileri.doyum(referans, Turetilenler.kZirhFor(referans)),
          closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-12),
        );
        expect(
          SavunmaEgrileri.doyum(referans, Turetilenler.kSiyirmaFor(referans)),
          closeTo(TasarimGirdileri.siyirmaHedefiReferans, 1e-12),
        );
      }
    });
  });

  group('01 · ölçülen — bugünkü taban', () {
    // Referans DOLU build (04.5 s2): sayılar formülle, çünkü bütçe ya da
    // artı seviyesi oynadığında hepsi birlikte oynuyor; tabloda görünen
    // sayı buradaki formülün sonucu, elle yazılmış bir sabit değil.
    final referans = ReferansCozumu.stats;
    test(
      'yaylım — beş namlu, namlu başına katalog C-I lazerin artılı hasarı',
      () {
        expect(referans.equippedLasers, 5);
        expect(
          referans.laser.damage,
          closeTo(
            ItemBudget.mainStatValue(
              Catalogue.pl1,
              ReferansCozumu.arti,
              HullClass.bastion,
            ),
            1e-6,
          ),
          reason: 'referansın namlusu katalogdaki C-I lazer değil',
        );
        expect(
          CombatGlossary.volley(referans),
          greaterThanOrEqualTo(5 * referans.laser.damage - 1e-9),
          reason: 'yaylım beş namlunun altında',
        );
      },
    );
    test('atış aralığı 1,10 sn', () {
      expect(referans.laser.fireInterval, closeTo(1.10, 1e-9));
    });
    test('DPS — yaylım ÷ aralık', () {
      expect(
        CombatGlossary.dps(referans),
        closeTo(
          CombatGlossary.volley(referans) / referans.laser.fireInterval,
          1e-9,
        ),
      );
    });
    test('kritikli referans DPS — DPS × 1,250', () {
      expect(
        CombatGlossary.expectedDps(referans),
        closeTo(
          CombatGlossary.dps(referans) * Turetilenler.kritikBeklenenDeger,
          1e-9,
        ),
      );
      // Referans saldırısı lazer artı roket (18.2).
      expect(
        CombatGlossary.saldiriDps(referans),
        closeTo(ReferansCozumu.referansDps, 1e-9),
      );
    });
    test('EHP — havuz × azaltma çarpanı, havuz TTK kısıtından', () {
      final havuz = referans.maxHull + referans.maxShield;
      expect(
        CombatGlossary.ehp(referans),
        closeTo(havuz / ((1 - 0.30) * (1 - 0.15)), 1e-6),
      );
      expect(
        CombatGlossary.ehp(referans),
        closeTo(
          CombatGlossary.saldiriDps(referans) * TasarimGirdileri.referansTTK,
          1e-6,
        ),
        reason: 'A = D kırılmış — gövde çapası TTK\'dan çözülmüyor',
      );
      expect(
        referans.maxShield,
        greaterThan(TasarimGirdileri.kalkanCapasi),
        reason: 'jeneratörler referansa kalkan katmıyor (08.6)',
      );
    });
    test('kalkanı düşürme — kalkan ÷ DPS', () {
      expect(
        CombatGlossary.ttk(referans.maxShield, CombatGlossary.dps(referans)),
        closeTo(referans.maxShield / CombatGlossary.dps(referans), 1e-9),
      );
    });
    test('oyuncu ↔ oyuncu TTK 37,5 sn — kritik HARİÇ', () {
      expect(
        CombatGlossary.ttkBetween(referans, referans),
        closeTo(
          TasarimGirdileri.referansTTK * Turetilenler.kritikBeklenenDeger,
          1e-6,
        ),
      );
      expect(CombatGlossary.ttkBetween(referans, referans), closeTo(37.5, 0.1));
      final kritikliTtk =
          CombatGlossary.ehp(referans) / CombatGlossary.saldiriDps(referans);
      expect(
        kritikliTtk,
        closeTo(TasarimGirdileri.referansTTK, 1e-6),
        reason: 'A = D kırılmış — gövde çapası TTK\'dan çözülmüyor',
      );
    });
    test('Void Spore SIRADAN sınıfının süresini tutuyor', () {
      // Yaratık canı referansın TOPLAM saldırısından (12, 18.2): lazer artı
      // roket. Yalnız lazerle ölçseydik roketatarlı referans "yavaş" görünürdü.
      expect(
        CombatGlossary.ttk(
          AlienStats.spore.maxHull,
          CombatGlossary.saldiriDps(referans),
        ),
        closeTo(TasarimGirdileri.siradanOldurmeSuresi, 0.01),
      );
      expect(
        CombatGlossary.volleysToKill(referans, AlienStats.spore.maxHull),
        inInclusiveRange(1, 3),
        reason: 'sıradan yaratık birkaç yaylımda inmeli',
      );
    });
    test('Void Leviathan GÜÇLÜ sınıfının süresini tutuyor', () {
      expect(
        CombatGlossary.ttk(
          AlienStats.leviathan.maxHull,
          CombatGlossary.saldiriDps(referans),
        ),
        closeTo(TasarimGirdileri.gucluOldurmeSuresi, 0.01),
      );
      // Sıradanın TAM beş katı — sınıf bir oran, bir sayı değil.
      expect(
        AlienStats.leviathan.maxHull / AlienStats.spore.maxHull,
        closeTo(
          TasarimGirdileri.gucluOldurmeSuresi /
              TasarimGirdileri.siradanOldurmeSuresi,
          1e-9,
        ),
      );
    });

    test('PvP TTK hedef bantta — pvpÇarpanı bu yüzden 1,00', () {
      // Kol bugün çekilmiyor çünkü doğal süre zaten hedefte. Çarpan 1'den
      // farklı olsaydı ölçülen TTK ile ilan edilen banda uymazdı.
      final dogal = CombatGlossary.ttkBetween(referans, referans);
      expect(dogal * TasarimGirdileri.pvpCarpani, closeTo(dogal, 1e-12));
    });
  });

  group('06 · değişmezler', () {
    test('kritik EV = 1 + k(d−1), sapma < %0,1', () {
      for (final (k, d) in [(0.1, 1.5), (0.25, 2.0), (0.6, 3.0)]) {
        final hit = DamageChain.resolve(
          baseDamage: 1000,
          critChance: k,
          critMultiplier: d,
          critMode: CritMode.expected,
        );
        final beklenen = 1000 * (1 + k * (d - 1));
        expect((hit.amount - beklenen).abs() / beklenen, lessThan(0.001));
      }
    });

    test('PRD ortalama oranı = kritikŞansıReferans', () {
      expect(
        Prd.effectiveChance(Turetilenler.kritikPrdSabiti),
        closeTo(TasarimGirdileri.kritikSansiReferans, 1e-9),
      );
    });

    test('sıyırma ≤ sıyırmaTavanı, HER ZAMAN', () {
      for (var kacinma = 0.0; kacinma < 1e6; kacinma = kacinma * 2 + 1) {
        expect(
          SavunmaEgrileri.siyirma(kacinma, 120),
          lessThanOrEqualTo(TasarimGirdileri.siyirmaTavani),
        );
      }
    });

    test('L5 payı ≤ sonHasarTavanı', () {
      for (var duz = 1.0; duz < 1e7; duz *= 10) {
        expect(
          DamageChain.resolve(baseDamage: 1000, flatDamage: duz).flatShare,
          lessThanOrEqualTo(TasarimGirdileri.sonHasarTavani + 1e-12),
        );
      }
    });

    test('referans zırh → azaltma = zirhAzaltmaHedefi', () {
      // Alan 04 yazılana kadar `kZirh` `null`du ve bu test iki kola
      // ayrılıyordu: çözülmemiş eğriye dayanan zırh hiçbir varlıkta olamazdı.
      // Alan 04 referans zırhı ilan edince eğri çözüldü ve o kol öldü —
      // artık ölçülecek gerçek bir hedef var.
      expect(
        SavunmaEgrileri.doyum(
          BekleyenGirdiler.referansZirh,
          Turetilenler.kZirh,
        ),
        closeTo(TasarimGirdileri.zirhAzaltmaHedefi, 1e-12),
        reason: 'referans zırh ilan edilen azaltmayı üretmiyor',
      );
      expect(
        SavunmaEgrileri.siyirma(
          BekleyenGirdiler.referansKacinma,
          Turetilenler.kSiyirma,
        ),
        closeTo(TasarimGirdileri.siyirmaHedefiReferans, 1e-12),
        reason: 'referans kaçınma ilan edilen sıyırmayı üretmiyor',
      );
    });
  });

  group('10 · ilerleme ve unvan', () {
    test('BR TABANI ilk unvanın eşiği — brOlcegi bunun için çözüldü', () {
      expect(CombatGlossary.brTabani, closeTo(3600, 1));
      expect(CombatGlossary.unvanEsigi(0), CombatGlossary.brTabani);
    });

    test('TAVAN merdivenin sonuna BİREBİR oturuyor', () {
      // Merdivende ne ulaşılamaz basamak var ne boş üst uç: son unvanın eşiği
      // sistemin üretebildiği en büyük BR'ye eşit.
      expect(
        CombatGlossary.unvanEsigi(TasarimGirdileri.unvanSayisi - 1),
        closeTo(CombatGlossary.brTavani, CombatGlossary.brTavani * 1e-9),
      );
    });

    test('basamaklar EŞİT ORANLI, eşit aralıklı değil', () {
      // Doğrusal bölmek üst uçta yüzlerce basamağı bir araya sıkıştırırdı.
      for (var i = 1; i < TasarimGirdileri.unvanSayisi; i++) {
        expect(
          CombatGlossary.unvanEsigi(i) / CombatGlossary.unvanEsigi(i - 1),
          closeTo(CombatGlossary.unvanAdimi, 1e-9),
          reason: 'unvan $i adımı merdivenden çıkmış',
        );
      }
      expect(CombatGlossary.unvanAdimi, greaterThan(1));
    });

    test('BR → unvan → BR gidiş dönüşü tutarlı', () {
      for (final i in [0, 1, 47, 118, TasarimGirdileri.unvanSayisi - 1]) {
        expect(CombatGlossary.unvanIndeksi(CombatGlossary.unvanEsigi(i)), i);
      }
      // Taban altı ve tavan üstü kelepçeleniyor.
      expect(CombatGlossary.unvanIndeksi(0), 0);
      expect(
        CombatGlossary.unvanIndeksi(CombatGlossary.brTavani * 100),
        TasarimGirdileri.unvanSayisi - 1,
      );
    });

    test('YORGUNLUK eşiği BANTLA ölçekleniyor — sabit eşik DUVAR olurdu', () {
      // Sabit 200.000 ile üst bantların geliri eşiği ilk dakikada geçiyordu:
      // yorgunluk botu yavaşlatmayı bırakıp herkesi durduruyordu.
      //
      // Ölçek GÖVDE KADEMESİYDİ; rank ile kademe ayrıştığı gün eşik sekiz
      // basamakta zıplarken gelir yirmi rankta sürekli büyüdü ve oran
      // sallandı. Artık ikisi de aynı merdivenden.
      var onceki = 0;
      for (var k = 0; k < Turetilenler.rankSayisi; k++) {
        final esik = Fatigue.softCapFor(k);
        expect(esik, greaterThan(onceki), reason: 'bant $k eşiği artmadı');
        onceki = esik;
      }
      expect(Fatigue.softCapFor(0), Fatigue.softCap);

      // Eğrinin ŞEKLİ korunuyor: eşik/yarılanma oranı her kademede aynı.
      for (var k = 0; k < TasarimGirdileri.govdeKademeSayisi; k++) {
        expect(
          Fatigue.softCapFor(k) / Fatigue.halfLifeFor(k),
          closeTo(Fatigue.softCap / Fatigue.halfLife, 1e-6),
          reason: 'kademe $k eğrinin şekli kaymış',
        );
      }
    });

    test('bant ölçeği GELİRLE aynı üssü kullanıyor', () {
      // Ayrı bir üs verilseydi eşik ile gelir zamanla ayrışırdı.
      //
      // Ölçek GÖVDE KADEMESİ merdiveninden okunuyordu; rank ile kademe
      // ayrıştığı gün yanlış oldu. Eşik artık bandın kendi rankından
      // ölçekleniyor, gelir de öyle — ikisi aynı merdivende.
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        final beklenen = math
            .pow(
              TuretilenTablolar.rankCarpaniFor(r, TasarimGirdileri.rankArtisi),
              TasarimGirdileri.gelirUssu,
            )
            .toDouble();
        // Tolerans ORANSAL: `softCapFor` tam sayıya yuvarlıyor ve mutlak bir
        // eşik, yuvarlamayı bir sapma sanardı.
        expect(
          Fatigue.softCapFor(r) / Fatigue.softCap,
          closeTo(beklenen, beklenen * 1e-5),
          reason: 'bant $r ölçeği α ile uyuşmuyor',
        );
      }
    });
  });
}
