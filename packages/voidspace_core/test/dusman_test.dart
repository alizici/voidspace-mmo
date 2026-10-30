@Tags(['turetme', 'aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 12 · DÜŞMAN KURGUSU.
///
/// Üç denklem: can bir SÜRE, hasar bir PENCERE, ödül bir HIZ. Buradaki her
/// test o üç denklemden birinin sonucunu ölçüyor — hiçbiri donmuş bir sayı
/// karşılaştırması değil.
void main() {
  final bantlar = [for (var r = 0; r < Turetilenler.rankSayisi; r++) r];

  group('alan 12 · sınıf', () {
    test('ÜÇ SINIF, ÜÇ ROL — tablonun her sayısı sınıfın kendisinde', () {
      // KARAR 12.1 s1
      // Can sütunu SANİYE, hız ve menzil oyuncununkine ORAN. Üçü de
      // kademeden bağımsız: sınıf bir orandır, bir sayı değil.
      expect(DusmanSinifi.values, [
        DusmanSinifi.siradan,
        DusmanSinifi.guclu,
        DusmanSinifi.boss,
      ]);
      expect(DusmanSinifi.siradan.oldurmeSuresi, 1.0);
      expect(DusmanSinifi.guclu.oldurmeSuresi, 5.0);
      expect(DusmanSinifi.boss.oldurmeSuresi, 360.0);
      expect(DusmanSinifi.siradan.hizOrani, 0.30);
      expect(DusmanSinifi.guclu.hizOrani, 0.15);
      expect(DusmanSinifi.boss.hizOrani, 0.10);
      expect(DusmanSinifi.siradan.menzilOrani, 0.50);
      expect(DusmanSinifi.guclu.menzilOrani, 0.65);
      expect(DusmanSinifi.boss.menzilOrani, 0.80);

      // Hiçbir yaratığın menzili ya da hızı oyuncununkine EŞİT olamaz:
      // eşit olsaydı mesafe tutmanın anlamı kalmaz, savaş bir sağlık
      // çubuğu yarışına dönerdi.
      for (final s in DusmanSinifi.values) {
        expect(s.menzilOrani, lessThan(1.0));
        expect(s.hizOrani, lessThan(1.0));
      }
      // Sıradan kovalayabilir ama yetişemez; güçlü hiç kovalayamaz.
      expect(
        DusmanSinifi.guclu.hizOrani,
        lessThan(DusmanSinifi.siradan.hizOrani),
      );

      // Oranlar KADEMEDEN bağımsız — yirmi bantta da aynı çıplak gövdeye
      // ve aynı referans lazerin menziline bağlı.
      for (final r in bantlar) {
        for (final s in DusmanSinifi.values) {
          final d = DusmanTasarimi(rank: r, sinif: s);
          expect(d.hiz, closeTo(ShipStats.bastion.speed * s.hizOrani, 1e-12));
          expect(
            d.menzil,
            closeTo(ShipStats.bastion.laser.range * s.menzilOrani, 1e-12),
          );
        }
      }
    });

    test('can bir SÜREDİR — öldürme süresi her bantta aynı', () {
      // KARAR 12.2 s2
      // Sınıf bir ORANDIR, bir sayı değil. Kırılırsa savaşın temposu bantla
      // değişiyor demektir: üst bölgede ya sünger ya kâğıt hedefler.
      for (final r in bantlar) {
        for (final s in DusmanSinifi.values) {
          final d = DusmanTasarimi(rank: r, sinif: s);
          expect(
            d.can / d.referansDps,
            closeTo(s.oldurmeSuresi, 1e-9),
            reason: '${s.name} @bant $r süresini tutmuyor',
          );
        }
      }
    });

    test('güçlü sıradanın TAM beş katı — sınıflar arası oran sabit', () {
      // KARAR 12.2 s2
      for (final r in bantlar) {
        final siradan = DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan);
        final guclu = DusmanTasarimi(rank: r, sinif: DusmanSinifi.guclu);
        expect(
          guclu.can / siradan.can,
          closeTo(
            TasarimGirdileri.gucluOldurmeSuresi /
                TasarimGirdileri.siradanOldurmeSuresi,
            1e-9,
          ),
        );
      }
    });

    test('referans DPS 09\'un saldırı kanalıyla AYNI tanım — ikincisi yok', () {
      // KARAR 12.2 s2
      // İkinci bir "referans DPS" tanımı, savaş puanı ile yaratık canının
      // sessizce ayrışması demek olurdu.
      for (final r in bantlar) {
        final carpan = TuretilenTablolar.rankCarpaniFor(
          r,
          TasarimGirdileri.rankArtisi,
        );
        expect(
          DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan).referansDps,
          closeTo(
            CombatGlossary.saldiriDps(ReferansCozumu.stats) * carpan,
            1e-6,
          ),
          reason: 'bant $r referans DPS\'i savaş sözlüğünden okumuyor',
        );
      }
      // Yirminci bandın canı bir TAHMİN değil: referans DPS büyüdüğü kadar
      // büyüyor, öldürme süresi her bantta bir saniye kalıyor.
      final ilk = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan);
      for (final r in bantlar) {
        expect(
          DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan).can / ilk.can,
          closeTo(
            TuretilenTablolar.rankCarpaniFor(r, TasarimGirdileri.rankArtisi),
            1e-9,
          ),
        );
      }
    });

    test('hız ve menzil oyuncununkinin ALTINDA — kaçmak hep mümkün', () {
      // KARAR 12.1 s1
      // Menzil eşit olsaydı mesafe tutmanın anlamı kalmaz, savaş bir
      // sağlık-çubuğu yarışına dönerdi.
      for (final s in DusmanSinifi.values) {
        final d = DusmanTasarimi(rank: 0, sinif: s);
        expect(d.hiz, lessThan(ShipStats.bastion.speed));
        expect(d.menzil, lessThan(ShipStats.bastion.laser.range));
      }
    });

    test('sıradan yaratık kendiliğinden SALDIRMAZ', () {
      // KARAR 12.1 s1
      // Oyuncuya haritayı geçme hakkı veren tek şey bu.
      expect(DusmanSinifi.siradan.saldirgan, isFalse);
      expect(DusmanSinifi.guclu.saldirgan, isTrue);
      expect(DusmanSinifi.boss.saldirgan, isTrue);
      expect(AlienStats.spore.aggroRange, 0);
      expect(AlienStats.leviathan.aggroRange, greaterThan(0));
    });

    test('yaratıklarda zırh ve sıyırma YOK — süre iki kez tanımlanmaz', () {
      for (final a in AlienStats.all) {
        expect(a.armor, 0, reason: '${a.name} zırhı canla aynı şeyi söylüyor');
        expect(a.evasion, 0);
      }
    });
  });

  group('alan 12 · hasar', () {
    test('hasar bir KAÇIŞ PENCERESİDİR — üç yaratık, 120 saniye', () {
      // KARAR 12.4 s1
      for (final r in bantlar) {
        final d = DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan);
        final hayatta =
            d.oyuncuHavuzu / (TasarimGirdileri.tehditSayisi * d.hasarDps);
        expect(hayatta, closeTo(TasarimGirdileri.kacisPenceresi, 1e-9));
      }
    });

    test('hasar SINIFLA değil bantla ölçekleniyor', () {
      // KARAR 12.4 s1
      // Güçlü yaratığı tehlikeli yapan hasarı değil, süresi.
      for (final r in bantlar) {
        final ilk = DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan);
        for (final s in DusmanSinifi.values) {
          expect(DusmanTasarimi(rank: r, sinif: s).hasarDps, ilk.hasarDps);
        }
      }
    });

    test('atış aralığı dengeyi DEĞİŞTİRMİYOR — yalnız atışın iriliğini', () {
      // KARAR 12.7 s1
      final d = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan);
      for (final aralik in [1.0, 1.7, 2.5, 3.0]) {
        expect(d.atisHasariFor(aralik) / aralik, closeTo(d.hasarDps, 1e-9));
      }
    });
  });

  group('alan 12 · ödül', () {
    test('sıradan yaratık bandın saatlik hedefini TAM tutturuyor', () {
      // KARAR 12.3 s1
      for (final r in bantlar) {
        final d = DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan);
        final saatlik = d.kredi * 3600 / d.harcananSaniye;
        expect(saatlik, closeTo(d.saatlikHedef, d.saatlikHedef * 0.001));
      }
    });

    test(
      'çevrim YENİDEN DOĞMAYI sayıyor — sayılmasaydı hedefin dokuz katı',
      () {
        // KARAR 12.3 s1
        // Oyuncu bir yaratığı öldürdükten sonra bir sonrakini beklemek zorunda
        // ve bugünkü farm çevriminin çoğu o bekleme.
        expect(TasarimGirdileri.siradanDogusSuresi, 8.0);
        expect(TasarimGirdileri.gucluDogusSuresi, 20.0);
        for (final s in [DusmanSinifi.siradan, DusmanSinifi.guclu]) {
          final d = DusmanTasarimi(rank: 3, sinif: s);
          expect(
            d.harcananSaniye,
            closeTo(d.dogusSuresi + s.oldurmeSuresi, 1e-12),
          );
          expect(
            d.kredi,
            (d.saatlikHedef * d.harcananSaniye / 3600 * s.prim).round(),
          );
        }
        // Yeniden doğma sayılmasaydı sıradan yaratık saatte hedefin DOKUZ
        // katını verirdi — 8 saniyelik bekleme, 1 saniyelik dövüş.
        final d = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan);
        final dogussuz = d.kredi * 3600 / DusmanSinifi.siradan.oldurmeSuresi;
        expect(dogussuz / d.saatlikHedef, closeTo(9.0, 0.01));
      },
    );

    test(
      'güçlü yaratık hedefi RİSK PRİMİ kadar aşıyor — ne eksik ne fazla',
      () {
        // KARAR 12.3 s1
        for (final r in bantlar) {
          final d = DusmanTasarimi(rank: r, sinif: DusmanSinifi.guclu);
          final saatlik = d.kredi * 3600 / d.harcananSaniye;
          expect(
            saatlik / d.saatlikHedef,
            closeTo(TasarimGirdileri.gucluRiskPrimi, 0.001),
          );
        }
      },
    );

    test(
      'NOVA bantla ÖLÇEKLENMİYOR — sert para gerçek parayla rekabet eder',
      () {
        // KARAR 12.6 s1
        // Kredi bantla yüzlerce kat büyüyor. NOVA büyürse satılan NOVA'nın
        // değeri sıfırlanır.
        final ilk = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan).nova;
        for (final r in bantlar) {
          expect(
            DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan).nova,
            ilk,
          );
        }
        // Kredi ise ölçekleniyor — ikisi aynı kural değil.
        expect(
          DusmanTasarimi(rank: bantlar.last, sinif: DusmanSinifi.siradan).kredi,
          greaterThan(
            DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan).kredi,
          ),
        );
      },
    );

    test('saatlik NOVA hızı üç sınıfta da AYNI — zamana bağlı, güce değil', () {
      // KARAR 12.6 s1
      final siradanCevrim =
          TasarimGirdileri.siradanDogusSuresi +
          TasarimGirdileri.siradanOldurmeSuresi;
      final beklenen = TasarimGirdileri.novaOdulu * 3600 / siradanCevrim;

      for (final s in DusmanSinifi.values) {
        final d = DusmanTasarimi(rank: 0, sinif: s);
        // Tolerans TAM SAYIYA yuvarlamadan geliyor, gevşeklikten değil: NOVA
        // bölünemiyor, yani çevrim başına en fazla yarım NOVA sapma olabilir.
        // Çevrim uzadıkça sapma küçülüyor — boss'ta yok.
        final tolerans = 0.5 * 3600 / d.harcananSaniye;
        expect(
          d.nova * 3600 / d.harcananSaniye,
          closeTo(beklenen, tolerans),
          reason: '${s.name} saatlik NOVA hızı ayrışmış',
        );
      }
    });
  });

  group('alan 12 · boss', () {
    test('doğma aralığı her bantta AYNI — öğrenilebilir bir ritim', () {
      // KARAR 12.5 s1
      // Bir seçim değil bir SONUÇ: saatlik hedef pay ediyor ve sadeleşiyor.
      // Yirmi ayrı sayı ezberlemek yerine tek bir ritim.
      final ilk = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.boss);
      for (final r in bantlar) {
        expect(
          DusmanTasarimi(rank: r, sinif: DusmanSinifi.boss).bossAraligiSaat,
          closeTo(ilk.bossAraligiSaat, 1e-9),
        );
      }
      expect(ilk.bossAraligiSaat, closeTo(2.0, 1e-9));
    });

    test('boss canı GRUP × hedef süre × referans DPS — üçü de türetilen', () {
      // KARAR 12.5 s1
      expect(TasarimGirdileri.bossGrubu, 3);
      expect(TasarimGirdileri.bossHedefSuresi, 120.0);
      expect(TasarimGirdileri.bossPrimi, 3.0);
      expect(TasarimGirdileri.bossGelirPayi, 0.15);
      for (final r in bantlar) {
        final d = DusmanTasarimi(rank: r, sinif: DusmanSinifi.boss);
        expect(
          d.can,
          closeTo(
            TasarimGirdileri.bossGrubu *
                TasarimGirdileri.bossHedefSuresi *
                d.referansDps,
            d.can * 1e-12,
          ),
        );
        // Maliyeti bir GRUBUN zamanı: bekleme oyuncunun saatinden düşmüyor,
        // o sırada başka bir şey yapıyor.
        expect(d.harcananSaniye, DusmanSinifi.boss.oldurmeSuresi);
        expect(d.dogusSuresi, closeTo(d.bossAraligiSaat * 3600, 1e-9));
      }
      // Boss'a hiç girmeyen oyuncu %15 yavaş ilerliyor, DURMUYOR.
      expect(TasarimGirdileri.bossGelirPayi, lessThan(0.2));
      expect(TasarimGirdileri.bossGelirPayi, greaterThan(0.0));
    });

    test('boss bandın gelirinin TAM %15\'ini taşıyor', () {
      // KARAR 12.5 s1
      // Yeterince büyük ki beklemeye değsin, yeterince küçük ki kaçırmak
      // ilerlemeyi durdurmasın.
      for (final r in bantlar) {
        final d = DusmanTasarimi(rank: r, sinif: DusmanSinifi.boss);
        final saatlikKatki = d.kredi / d.bossAraligiSaat;
        expect(
          saatlikKatki / d.saatlikHedef,
          closeTo(TasarimGirdileri.bossGelirPayi, 0.001),
        );
      }
    });

    test('gelir payı aralık dışıysa ATIYOR', () {
      // KARAR 12.5 s1
      expect(
        () => TuretilenTablolar.bossAraligiFor(
          odul: 100,
          saatlikHedef: 1000,
          gelirPayi: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('alan 12 · kod', () {
    test('Void Spore ile Void Leviathan TÜRETMEDEN geliyor', () {
      // KARAR 12.2 s2 · KARAR 12.3 s1
      final siradan = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan);
      final guclu = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.guclu);

      expect(AlienStats.spore.maxHull, closeTo(siradan.can, 1e-9));
      expect(AlienStats.spore.creditReward, siradan.kredi);
      expect(AlienStats.spore.premiumReward, siradan.nova);
      expect(AlienStats.spore.speed, closeTo(siradan.hiz, 1e-9));
      expect(AlienStats.spore.range, closeTo(siradan.menzil, 1e-9));
      expect(
        AlienStats.spore.damage / AlienStats.spore.fireInterval,
        closeTo(siradan.hasarDps, 1e-9),
      );

      expect(AlienStats.leviathan.maxHull, closeTo(guclu.can, 1e-9));
      expect(AlienStats.leviathan.creditReward, guclu.kredi);
      expect(
        AlienStats.leviathan.damage / AlienStats.leviathan.fireInterval,
        closeTo(guclu.hasarDps, 1e-9),
      );
    });

    test('iki yaratık da tel sınırlarına sığıyor', () {
      // Can `u32`, ödül `u32`: alan 12 sayıları büyüttü, tel taşımalı.
      for (final a in AlienStats.all) {
        expect(a.maxHull, lessThan(0xFFFFFFFF));
        expect(a.creditReward, lessThan(0xFFFFFFFF));
        expect(a.premiumReward, greaterThanOrEqualTo(0));
      }
    });
  });

  group('alan 12 · kadro', () {
    test('otuz iki kimlik: sekiz bölge × (iki sıradan + güçlü + boss)', () {
      // KARAR 12.7 s1
      expect(YaratikKadrosu.hepsi, hasLength(32));
      for (var b = 0; b < 8; b++) {
        final kadro = YaratikKadrosu.bolgenin(b);
        expect(kadro, hasLength(4), reason: 'bölge ${b + 1} eksik ya da fazla');
        expect(
          kadro.where((y) => y.sinif == DusmanSinifi.siradan),
          hasLength(2),
        );
        expect(kadro.where((y) => y.sinif == DusmanSinifi.guclu), hasLength(1));
        expect(kadro.where((y) => y.sinif == DusmanSinifi.boss), hasLength(1));
      }
    });

    test('kind ve slug BENZERSİZ — tel kimliği çakışamaz', () {
      // KARAR 12.7 s1
      final kindler = YaratikKadrosu.hepsi.map((y) => y.kind).toSet();
      expect(kindler, hasLength(32));
      expect(YaratikKadrosu.hepsi.map((y) => y.slug).toSet(), hasLength(32));
      // Void Spore (0) ve Void Leviathan (1) ile çakışmıyor.
      for (final a in AlienStats.all) {
        expect(kindler.contains(a.kind), isFalse);
      }
      // `u8` sınırı.
      for (final k in kindler) {
        expect(k, inInclusiveRange(0, 255));
      }
    });

    test('sınıfın hız ORTALAMASI tasarımın oranını tutuyor', () {
      // KARAR 12.1 s1 · KARAR 12.7 s1
      // Kimlik sapmayı veriyor, sınıf ortalamayı. Ham hızları olduğu gibi
      // kullanmak sözleşmeyi kırardı: kaynak kadroda bir güçlü yaratık bir
      // sıradandan hızlı olabiliyor.
      for (final s in DusmanSinifi.values) {
        final uyeler = YaratikKadrosu.hepsi.where((y) => y.sinif == s);
        final ortalama =
            uyeler.map(YaratikKadrosu.hizFor).reduce((a, b) => a + b) /
            uyeler.length;
        expect(
          ortalama,
          closeTo(ShipStats.bastion.speed * s.hizOrani, 1e-9),
          reason: '${s.name} sınıfının hız ortalaması kaymış',
        );
      }
    });

    test('hiçbir yaratık oyuncuya YETİŞEMİYOR', () {
      // KARAR 12.1 s1
      // Kaçmak her zaman mümkün; bedeli o ana kadar yatırılan zaman.
      for (final y in YaratikKadrosu.hepsi) {
        expect(
          YaratikKadrosu.hizFor(y),
          lessThan(ShipStats.bastion.speed),
          reason: '${y.ad} oyuncuyu yakalıyor',
        );
      }
      // Ve en hızlı güçlü yaratık bile sıradan ortalamasının altında.
      final enHizliGuclu = YaratikKadrosu.hepsi
          .where((y) => y.sinif == DusmanSinifi.guclu)
          .map(YaratikKadrosu.hizFor)
          .reduce((a, b) => a > b ? a : b);
      expect(
        enHizliGuclu,
        lessThan(ShipStats.bastion.speed * DusmanSinifi.siradan.hizOrani),
      );
    });

    test('kimlik hiçbir DENGE sayısı taşımıyor — hepsi bandından geliyor', () {
      // KARAR 12.7 s1
      // Aynı kimlik iki farklı bantta iki farklı can veriyor: kimlikte
      // saklanmış bir sayı olsaydı ikisi eşit çıkardı.
      final y = YaratikKadrosu.hepsi.first;
      expect(y.statFor(0).maxHull, lessThan(y.statFor(1).maxHull));
      expect(y.statFor(0).creditReward, lessThan(y.statFor(1).creditReward));
      // Ve sınıfının tasarımıyla birebir.
      final t = DusmanTasarimi(rank: 2, sinif: y.sinif);
      expect(y.statFor(2).maxHull, closeTo(t.can, 1e-9));
      expect(y.statFor(2).creditReward, t.kredi);
      expect(y.statFor(2).damage / y.atisAraligi, closeTo(t.hasarDps, 1e-9));
    });

    test('kadro bölge sırasında — kimlik listesi bölgeye göre artıyor', () {
      // KARAR 12.7 s1
      var onceki = 0;
      for (final y in YaratikKadrosu.hepsi) {
        expect(y.bolge, greaterThanOrEqualTo(onceki));
        onceki = y.bolge;
      }
    });
  });

  // ══ SONUÇ testleri ═══════════════════════════════════════════════════
  //
  // Yukarıdaki testlerin çoğu YAPI ölçüyor: sayının tepe tablodan okunduğunu.
  // Mutasyon bunu açıkça gösterdi — `kaçışPenceresi`yi 120'den 90'a çekmek
  // hiçbirini kırmıyordu, çünkü hepsi beklentiyi aynı girdiden türetiyor.
  //
  // Buradakiler girdinin NE ANLAMA GELDİĞİNİ ölçüyor: her biri başka bir
  // alanın sayısına ya da oyuncunun yaşadığı bir şeye bağlanıyor, yani
  // girdiyi değiştirmek gerçekten bir şeyi kırıyor.
  group('alan 12 · sonuç', () {
    test('TEK yaratık oyuncuyu beş dakikadan önce öldüremiyor', () {
      // KARAR 12.4 s1
      // Kaçış penceresinin asıl anlamı: tehdit tek yaratıktan değil, üçünü
      // birden çekmekten geliyor. Tek bir yaratık ölümcül olsaydı sıradan
      // yaratık "görmezden gelinebilir" olmaktan çıkardı.
      for (final r in [0, Turetilenler.rankSayisi - 1]) {
        final d = DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan);
        expect(
          d.oyuncuHavuzu / d.hasarDps,
          greaterThan(300),
          reason: 'bant $r: tek yaratık beş dakikadan hızlı öldürüyor',
        );
      }
    });

    test('üç yaratık ise kaçmaya ZORLUYOR — pencere bir dövüşten kısa', () {
      // KARAR 12.4 s1
      // Öteki uç: pencere çok uzun olursa üç yaratık da tehdit olmaktan
      // çıkar ve oyuncunun harita üstünde bir kararı kalmaz.
      final d = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.guclu);
      final ucuBirden =
          d.oyuncuHavuzu / (TasarimGirdileri.tehditSayisi * d.hasarDps);
      expect(ucuBirden, lessThan(d.sinif.oldurmeSuresi * 60));
    });

    test('güçlü yaratığın primi PvP\'nin NET priminden büyük olamaz', () {
      // İki risk, iki prim — ve PvP daha büyük risk: orada kaybedilen şey
      // zaman değil, başka bir oyuncuya karşı verilmiş bir karar. Yaratık
      // primi onu geçerse PvP haritasının varlık sebebi kalmıyor.
      expect(
        TasarimGirdileri.gucluRiskPrimi - 1,
        lessThanOrEqualTo(TasarimGirdileri.pvpNetPrim),
      );
      expect(TasarimGirdileri.gucluRiskPrimi, greaterThan(1.0));
    });

    test('boss primi güçlünün primini AŞIYOR — sıralama bozulmuyor', () {
      expect(DusmanSinifi.boss.prim, greaterThan(DusmanSinifi.guclu.prim));
      expect(DusmanSinifi.guclu.prim, greaterThan(DusmanSinifi.siradan.prim));
    });

    test(
      'sınıf süreleri SIRALI ve sıradan gerçekten görmezden gelinebilir',
      () {
        // KARAR 12.1 s1
        expect(
          DusmanSinifi.siradan.oldurmeSuresi,
          lessThan(DusmanSinifi.guclu.oldurmeSuresi),
        );
        expect(
          DusmanSinifi.guclu.oldurmeSuresi,
          lessThan(DusmanSinifi.boss.oldurmeSuresi),
        );
        // Sıradan yaratık, yeniden doğmasından KISA sürüyor: farm çevrimini
        // savaş değil bekleme belirliyor. Tersi olsaydı "gelirin taşıyıcısı"
        // bir zaman kuyusu olurdu.
        expect(
          DusmanSinifi.siradan.oldurmeSuresi,
          lessThan(TasarimGirdileri.siradanDogusSuresi),
        );
        // Ve ekranda sayılabilir kalıyor: en çok üç yaylım.
        expect(
          CombatGlossary.volleysToKill(
            ReferansCozumu.stats,
            DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan).can,
          ),
          inInclusiveRange(1, 3),
        );
      },
    );

    test('NOVA kıt kalıyor — en ucuz sert para eşyası saatlerce farm', () {
      // KARAR 12.6 s1
      // NOVA'nın kıtlığı bir his değil bir oran: musluk (yaratık ödülü) ile
      // lavabo (mağaza fiyatı) arasındaki bölüm. Ödül iki katına çıkarsa
      // kıtlık yarıya iner ve satılan NOVA'nın değeri düşer.
      final saatlik =
          DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan).nova *
          3600 /
          DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan).harcananSaniye;

      final novaFiyatlari = [
        for (final spec in Catalogue.items)
          if (spec.currency == Currency.premium) Catalogue.priceOf(spec).amount,
      ];
      expect(novaFiyatlari, isNotEmpty, reason: 'katalogda NOVA eşyası yok');

      final enUcuzSaat =
          novaFiyatlari.reduce((a, b) => a < b ? a : b) / saatlik;
      expect(
        enUcuzSaat,
        greaterThan(1.0),
        reason:
            'en ucuz NOVA eşyası bir saatten kısa sürüyor — sert para kıt değil',
      );
    });
  });
}
