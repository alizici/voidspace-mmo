@Tags(['turetme', 'aralik', 'kapsam', 'yabanci-anahtar'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 06 · EŞYA KURGUSU — iki eksen, üç şema, dört değişmez.
///
/// Sektörün tanımı: denge ile biriciklik arasındaki ilişki. Ana stat
/// belirlenimci olduğu için denge kurulabiliyor; alt stat rastgele olduğu için
/// her eşya biricik oluyor. Buradaki testler o iki cümlenin sayısal
/// karşılığını koruyor.
void main() {
  final hull = HullClass.bastion;

  group('06.1 · rank ekseni belirlenimci, yirmi basamak', () {
    // KARAR 06.1 s1
    test('altı aile × üç basamak + iki tekil = yirmi rank', () {
      expect(TasarimGirdileri.rankSayisi, 20);
      expect(ItemTier.values, hasLength(TasarimGirdileri.rankSayisi));
      expect(
        ItemTier.aileSayisi * ItemTier.aileBasamagi + ItemTier.tekilRank,
        TasarimGirdileri.rankSayisi,
      );
      expect(ItemTier.kirmizi.kapakTasi, isTrue);
      expect(ItemTier.parlayanPembe.kapakTasi, isTrue);
      expect(ItemTier.sssIII.kapakTasi, isFalse);
    });

    // KARAR 06.1 s1
    test('rank BELİRLENİMCİ: çarpan tek üsten, örnekten bağımsız', () {
      // "Rank, eşyanın rengidir" — renk gücü söylüyorsa güç örneğe göre
      // oynayamaz. Çarpan elle yazılmıyor: rankArtisi üssü.
      for (final tier in ItemTier.values) {
        expect(
          tier.multiplier,
          closeTo(math.pow(TasarimGirdileri.rankArtisi, tier.index), 1e-9),
          reason: '${tier.label} çarpanı merdivenden gelmiyor',
        );
      }
      expect(TasarimGirdileri.rankArtisi, 1.442);
      expect(ItemTier.cI.multiplier, closeTo(1.0, 1e-12));
      // Tepe 1.048×: iki yıllık hedefin geldiği yer.
      expect(ItemTier.parlayanPembe.multiplier, closeTo(1048, 1));
    });

    // KARAR 06.1 s1
    test('rank ilerledikçe çarpan KESİN ARTAN — renk gücü söylüyor', () {
      for (var i = 1; i < ItemTier.values.length; i++) {
        expect(
          ItemTier.values[i].multiplier,
          greaterThan(ItemTier.values[i - 1].multiplier),
          reason: ItemTier.values[i].label,
        );
      }
    });
  });

  group('06.2 · kalite ekseni rastgele, örneğe özgü', () {
    // KARAR 06.2 s1
    test('roll bandın İÇİNDE: taban 0,70, tavan 1,00', () {
      expect(TasarimGirdileri.kaliteAltSiniri, 0.70);
      for (var i = 0; i < 200; i++) {
        final rol = ItemBudget.kaliteRolu('i-$i', i % 7);
        expect(rol, greaterThanOrEqualTo(TasarimGirdileri.kaliteAltSiniri));
        expect(rol, lessThanOrEqualTo(1.0));
      }
    });

    // KARAR 06.2 s1
    test('roll ÖRNEĞİN KİMLİĞİNDEN: aynı eşya her yüklemede aynı', () {
      // `Random` olsaydı oyuncunun gemisi her girişte başka bir gemi olurdu.
      for (var i = 0; i < 50; i++) {
        expect(
          ItemBudget.kaliteRolu('i-8f2a', i),
          ItemBudget.kaliteRolu('i-8f2a', i),
        );
      }
      expect(
        ItemBudget.kaliteRolu('i-8f2a', 0),
        isNot(ItemBudget.kaliteRolu('i-8f2b', 0)),
      );
    });

    // KARAR 06.2 s1
    test('BİRİCİKLİK: aynı ranktan iki eşya farklı kalitede geliyor', () {
      final roller = {
        for (var i = 0; i < 300; i++) ItemBudget.kaliteRolu('e$i', 0),
      };
      expect(
        roller.length,
        greaterThan(250),
        reason: 'roll kimlikten türemiyor, sabitlenmiş',
      );
      // Bandın iki ucu da gerçekten görülüyor: dağılım tek noktaya çökmemiş.
      expect(roller.reduce(math.min), lessThan(0.75));
      expect(roller.reduce(math.max), greaterThan(0.95));
    });
  });

  group('06.3 · tasarım, örnek ve malzeme ayrı şemalar', () {
    // KARAR 06.3 s1
    test('bir TASARIM, çok ÖRNEK: kayıt tek, statlar örneğe özgü', () {
      // "Aynı tasarımdan yüzlerce örnek olabilir, her biri farklı alt
      // statlarla." Tasarım kataloğu sabit ve küçük; örnekler sayısız.
      final spec = Catalogue.items.firstWhere(
        (s) => ItemBudget.altStatSayisi(s.tier) >= 2 && s.subStatPool.length > 2,
      );
      final ornekler = [for (var i = 0; i < 5; i++) 'ornek-$i'];
      // Ana stat örneğin kimliğini HİÇ sormuyor: imzasında yok, sonucu da
      // her örnek için aynı.
      final anaStatlar = {
        for (var n = 0; n < ornekler.length; n++)
          ItemBudget.mainStatValue(spec, 0, hull),
      };
      expect(
        anaStatlar,
        hasLength(1),
        reason: 'ana stat örneğe göre oynuyor — belirlenimci değil',
      );
      final altHaritalari = [
        for (final id in ornekler)
          ItemBudget.subStatValues(spec, 0, hull, id).values.toList(),
      ];
      expect(
        altHaritalari.toSet(),
        hasLength(greaterThan(1)),
        reason: 'örnekler birbirinin aynısı — biriciklik yok',
      );
      // Katalogda her tasarım kimliği TEK kayıt.
      expect(Catalogue.byId.length, Catalogue.items.length);
    });

    // KARAR 06.3 s1
    test('MALZEME örneği olmayan şema: yığılıyor, ayrı kapta', () {
      // "Malzemeler de eşya ama örneği yok: yığılabilir ve birbirinin
      // aynısı." Aynı kapta tutmak, her malzeme için sahte bir örnek üretmek
      // demekti — ve o an malzemenin artısı, alt statı olabilir hâle gelirdi.
      final h = Hangar(accountId: 'a');
      final m = Malzeme.forRank(ItemTier.cI);
      h.malzemeEkle(m, 7);
      expect(h.malzemeSayisi(m), 7);
      expect(h.inventory, isEmpty, reason: 'malzeme örnek üretti');
      expect(Malzeme.forRank(ItemTier.cI).id, Malzeme.forRank(ItemTier.cI).id);
      // Kimliği türünden ve rankından: ayırt edici üçüncü bir eksen yok.
      expect(m.id, '${MalzemeTuru.yukseltme.onEk}${ItemTier.cI.name}');
      // Eşya kimliği malzeme olarak çözülmüyor: iki şema karışmıyor.
      expect(Malzeme.byId(Catalogue.pl4.id), isNull);
    });
  });

  group('06.4 · yükseltme malzemesi ile çevirici ayrı kaynak', () {
    // KARAR 06.4 s1
    test('yirmi rank × iki tür = kırk kayıt, kimlikleri ayrı', () {
      expect(MalzemeTuru.values, hasLength(2));
      expect(
        Malzeme.hepsi,
        hasLength(MalzemeTuru.values.length * ItemTier.values.length),
      );
      expect(Malzeme.hepsi.map((m) => m.id).toSet(), hasLength(40));
      for (final rank in ItemTier.values) {
        expect(
          Malzeme.forRank(rank).id,
          isNot(Malzeme.cevirmeFor(rank).id),
          reason: '${rank.label}: iki tür aynı kimliğe düşüyor',
        );
        expect(Malzeme.forRank(rank).tur, MalzemeTuru.yukseltme);
        expect(Malzeme.cevirmeFor(rank).tur, MalzemeTuru.cevirme);
      }
    });

    // KARAR 06.4 s1
    test('iki stok BAĞIMSIZ: birini harcamak ötekini eritmiyor', () {
      // Aynı kaynağı harcasalardı oyuncu her çevirmede bir yükseltmeden
      // vazgeçmiş olurdu ve ikisi arasında bir karar değil, ceza hissederdi.
      final h = Hangar(accountId: 'a');
      final malzeme = Malzeme.forRank(ItemTier.cIII);
      final cevirici = Malzeme.cevirmeFor(ItemTier.cIII);
      h.malzemeEkle(malzeme, 10);
      h.malzemeEkle(cevirici, 10);
      h.malzemeEkle(malzeme, -4);
      expect(h.malzemeSayisi(malzeme), 6);
      expect(h.malzemeSayisi(cevirici), 10, reason: 'tek kaynağa dönmüş');
      h.malzemeEkle(cevirici, -10);
      expect(h.malzemeSayisi(cevirici), 0);
      expect(h.malzemeSayisi(malzeme), 6);
    });
  });

  group('06.5 · ana stat belirlenimci, alt statlar rastgele', () {
    // KARAR 06.5 s1
    test('bölünme 0,70 / 0,30 — ana stat bütçenin payı kadar', () {
      expect(TasarimGirdileri.anaStatPayi, 0.70);
      for (final spec in Catalogue.rafta) {
        expect(
          ItemBudget.mainStatValue(spec, 0, hull),
          closeTo(
            ItemBudget.budgetFor(spec, 0, hull) *
                TasarimGirdileri.anaStatPayi *
                ItemBudget.birimFiyati(spec.mainStat),
            1e-9,
          ),
          reason: '${spec.id} ana statı bütçeden gelmiyor',
        );
      }
    });

    // KARAR 06.5 s1
    test('ana stat ÖRNEKTEN bağımsız, alt statlar örneğe göre oynuyor', () {
      // "Hangi lazeri aldığını biliyorsan hasarını da biliyorsun; dengenin
      // dayandığı kısım burası."
      final spec = Catalogue.pl4;
      final ana = ItemBudget.mainStatValue(spec, 3, hull);
      expect(ItemBudget.mainStatValue(spec, 3, hull), ana);
      final a = ItemBudget.subStatValues(spec, 3, hull, 'i-a');
      final b = ItemBudget.subStatValues(spec, 3, hull, 'i-b');
      expect(a.keys, b.keys, reason: 'havuz örneğe göre değişiyor');
      expect(a.values.toList(), isNot(b.values.toList()));
    });

    // KARAR 06.5 s1
    test('DEĞİŞMEZ: ana stat + alt statlar = eşyanın bütçesi', () {
      // Kırılırsa eşya bütçeden fazla ya da az güç veriyor ve 08 ile
      // ayrışıyor. Alt statlar bandın içinde oynadığı için toplam iki uç
      // arasında kalmak zorunda.
      for (final spec in Catalogue.rafta) {
        final butce = ItemBudget.budgetFor(spec, 0, hull);
        final anaPuan =
            ItemBudget.mainStatValue(spec, 0, hull) /
            ItemBudget.birimFiyati(spec.mainStat);
        final altPuan = altStatBudgetOf(spec, 'i-042');
        final taban = ItemBudget.kaliteAltSiniriFor(spec.tier);
        expect(
          anaPuan + altPuan,
          lessThanOrEqualTo(butce * (1 + 1e-9)),
          reason: '${spec.id} bütçesini aşıyor',
        );
        expect(
          anaPuan + altPuan,
          greaterThanOrEqualTo(
            butce *
                (TasarimGirdileri.anaStatPayi +
                    (1 - TasarimGirdileri.anaStatPayi) * taban) *
                (1 - 1e-9),
          ),
          reason: '${spec.id} bütçesinin altında kalıyor',
        );
      }
    });
  });

  group('06.6 · rank çakışmaz', () {
    /// [tier]'ın gerçekleşen gücü, bütçe puanı cinsinden: ana stat sabit,
    /// alt statlar en kötü (bandın tabanı) ya da en iyi (1,0) rolle.
    double gerceklesen(ItemTier tier, {required bool enIyi}) {
      final adet = ItemBudget.altStatSayisi(tier);
      final garanti = ItemBudget.garantiliFor(tier);
      final band = ItemBudget.kaliteAltSiniriFor(tier);
      var rolToplami = 0.0;
      for (var i = 0; i < adet; i++) {
        rolToplami += (enIyi || i < garanti) ? 1.0 : band;
      }
      return tier.multiplier *
          (TasarimGirdileri.anaStatPayi +
              (1 - TasarimGirdileri.anaStatPayi) * rolToplami / adet);
    }

    // KARAR 06.6 s2
    test('en KÖTÜ rollü üst rank, en İYİ rollü alt ranktan güçlü', () {
      // Değişmez: çakışırsa oyuncu "hangisi daha iyi" sorusunu ancak sayıları
      // elle karşılaştırarak cevaplayabilir ve rank renginin tek işi ölür.
      for (var i = 0; i + 1 < ItemTier.values.length; i++) {
        final alt = ItemTier.values[i];
        final ust = ItemTier.values[i + 1];
        expect(
          gerceklesen(ust, enIyi: false),
          greaterThan(gerceklesen(alt, enIyi: true)),
          reason: '${alt.label} ile ${ust.label} çakışıyor',
        );
      }
    });

    // KARAR 06.6 s2
    test('gerçek rollerde de çakışma yok — üç yüz kimlik tarandı', () {
      // Analitik sınır bir şey, motorun ürettiği roller başka bir şey: aynı
      // yuvanın bitişik iki rankı gerçek kimliklerle taranıyor.
      final lazerler = [
        for (final tier in ItemTier.values)
          Catalogue.items.firstWhere(
            (s) => s.slot == SlotType.laser && s.tier == tier,
          ),
      ];
      double toplamPuan(ItemSpec spec, String id) =>
          ItemBudget.mainStatValue(spec, 0, hull) /
              ItemBudget.birimFiyati(spec.mainStat) +
          altStatBudgetOf(spec, id);

      for (var i = 0; i + 1 < lazerler.length; i++) {
        var enIyiAlt = 0.0;
        var enKotuUst = double.infinity;
        for (var n = 0; n < 300; n++) {
          enIyiAlt = math.max(enIyiAlt, toplamPuan(lazerler[i], 'a$n'));
          enKotuUst = math.min(enKotuUst, toplamPuan(lazerler[i + 1], 'b$n'));
        }
        expect(
          enKotuUst,
          greaterThan(enIyiAlt),
          reason:
              '${lazerler[i].tier.label} → ${lazerler[i + 1].tier.label} '
              'çakıştı',
        );
      }
    });

    // KARAR 06.6 s2
    test('alt stat payı çakışma TAVANININ altında', () {
      // Bölünmenin üst sınırını bu kısıt belirliyor: alt stat payı büyüdükçe
      // bitişik ranklar birbirine yaklaşıyor. Pay bugünkü değerinde çakışma
      // yok; %100'e çıkarıldığında bile en dar boğaz burada ölçülüyor.
      expect(
        TasarimGirdileri.anaStatPayi,
        greaterThan(0.5),
        reason: 'ana stat payı yarıyı bırakırsa denge kurulamaz',
      );
      final enDarBogaz = [
        for (var i = 0; i + 1 < ItemTier.values.length; i++)
          gerceklesen(ItemTier.values[i + 1], enIyi: false) /
              gerceklesen(ItemTier.values[i], enIyi: true),
      ].reduce(math.min);
      expect(enDarBogaz, greaterThan(1.0));
    });
  });

  group('06.7 · alt stat havuzu yuva tipine göre kısıtlı ve fiyatlı', () {
    // KARAR 06.7 s1
    test('havuzdaki her statın birim fiyatı SIFIRDAN BÜYÜK', () {
      // Değişmez: "Havuzdaki her statın değeri sıfırdan büyük" — fiyatı sıfır
      // olan stat ölü roll üretir. Gövde canı bir zamanlar jeneratör
      // havuzunda neredeyse bedavaydı.
      for (final spec in Catalogue.items) {
        for (final statId in spec.subStatPool) {
          expect(
            ItemBudget.birimFiyati(statId),
            greaterThan(0),
            reason: '${spec.id} havuzundaki $statId ölü roll',
          );
          expect(
            Stats.byId(statId),
            isNotNull,
            reason: '${spec.id}: $statId kütüphanede yok',
          );
        }
      }
    });

    // KARAR 06.7 s1
    test('havuz YUVA TİPİNE göre: lazer kalkan, CPU taban hasar çeviremez', () {
      for (final spec in Catalogue.items) {
        if (spec.slot == SlotType.laser) {
          expect(
            spec.subStatPool,
            isNot(contains('kalkan_yenilenmesi')),
            reason: '${spec.id} lazeri savunma statı çeviriyor',
          );
          expect(spec.subStatPool, isNot(contains('kalkan')));
        }
        // Taban hasar HİÇBİR havuzda yok: gemi kapsamında lazerin tekelinde
        // (04.2), alt stat olarak çıkmıyor.
        expect(
          spec.subStatPool,
          isNot(contains('taban_hasar')),
          reason: '${spec.id} taban hasar çeviriyor',
        );
      }
    });

    // KARAR 06.7 s1
    test('yuva KİMLİĞİ havuzdan geliyor: iki yuvanın havuzu aynı değil', () {
      // "Havuz kısıtı olmadan bütün eşyalar birbirinin aynısı olur ve yuva
      // kimliği kaybolur." Çevirmenin anlamlı olması da buna bağlı.
      final havuzlar = {
        for (final spec in Catalogue.rafta)
          '${spec.slot.name}/${spec.variant ?? spec.mainStat}':
              spec.subStatPool.toSet(),
      };
      final ayriklar = havuzlar.values.map((h) => h.join('|')).toSet();
      expect(
        ayriklar.length,
        greaterThan(1),
        reason: 'bütün havuzlar aynı — yuva kimliği erimiş',
      );
      expect(
        Catalogue.pl1.subStatPool.toSet(),
        isNot(Catalogue.df1.subStatPool.toSet()),
      );
    });
  });

  group('06.8 · havuz içerikleri', () {
    // Belgedeki tablonun birebir kendisi: yuvanın kendi kanalı + sistem
    // statları (menzil, hız). Sistem statları her havuza girebiliyor.
    const beklenen = <String, List<String>>{
      'pl1': [
        'hasar_artisi',
        'atis_hizi',
        'kritik_sansi',
        'kritik_hasari',
        'son_hasar',
        'menzil',
        'hiz',
      ],
      'df1': [
        'govde_cani',
        'kalkan_yenilenmesi',
        'zirh',
        'kacinma',
        'son_azaltma',
        'menzil',
        'hiz',
      ],
      'th1': [
        'kalkan',
        'govde_cani',
        'kalkan_yenilenmesi',
        'zirh',
        'kacinma',
        'son_azaltma',
        'menzil',
      ],
      'mk1': [
        'atis_hizi',
        'kritik_sansi',
        'kritik_hasari',
        'son_hasar',
        'menzil',
        'hiz',
      ],
      'cpu_repair': [
        'govde_cani',
        'kalkan',
        'zirh',
        'kacinma',
        'son_azaltma',
        'menzil',
        'hiz',
      ],
      'cpu_scope': [
        'atis_hizi',
        'kritik_sansi',
        'hiz',
        'zirh',
        'kacinma',
        'son_azaltma',
        'kalkan_yenilenmesi',
      ],
      'dr1': [
        'atis_hizi',
        'kritik_sansi',
        'kritik_hasari',
        'govde_cani',
        'zirh',
        'menzil',
      ],
    };

    // KARAR 06.8 s2
    test('yedi havuzun yedisi de belgedeki listeyle BİREBİR', () {
      for (final e in beklenen.entries) {
        expect(
          Catalogue.byId[e.key]!.subStatPool,
          e.value,
          reason: '${e.key} havuzu belgeden ayrışmış',
        );
      }
    });

    // KARAR 06.8 s2
    test('havuz YEDİ; roketatar ve droid ALTI — kapak taşı sebebiyle', () {
      // Roketatar: ana statı taban hasar ama roket kapsamında; kapak taşında
      // altı alt statta kalıyor. Droid: droid kapsamına yazabilen stat yedi
      // ve biri ana stat.
      for (final spec in Catalogue.items) {
        final beklenenUzunluk =
            spec.slot == SlotType.launcher || spec.slot == SlotType.droid
            ? 6
            : 7;
        expect(
          spec.subStatPool,
          hasLength(beklenenUzunluk),
          reason: '${spec.id} havuzu ${spec.subStatPool.length}',
        );
      }
    });

    // KARAR 06.8 s2
    test('üst ranklar rafın EN İYİSİNİN havuzunu aynen taşıyor', () {
      for (final tip in SlotType.values) {
        final rafDeki = Catalogue.rafta.where((s) => s.slot == tip);
        if (rafDeki.isEmpty) continue;
        final enIyi = rafDeki.reduce(
          (a, b) => a.tier.index >= b.tier.index ? a : b,
        );
        final turetilenler = Catalogue.items.where(
          (s) => s.slot == tip && s.tier.index > enIyi.tier.index,
        );
        expect(turetilenler, isNotEmpty, reason: '${tip.name} üstü boş');
        for (final s in turetilenler) {
          expect(
            s.subStatPool,
            enIyi.subStatPool,
            reason: '${s.id} havuzu şablondan ayrışmış',
          );
          expect(s.mainStat, enIyi.mainStat, reason: s.id);
        }
      }
    });
  });

  group('06.9 · alt stat sayısı her aileyle bir artıyor', () {
    // KARAR 06.9 s2
    test('C1 · B2 · A3 · S4 · SS5 · SSS6 · kapak taşları 7', () {
      const merdiven = {
        ItemTier.cI: 1,
        ItemTier.cIII: 1,
        ItemTier.bI: 2,
        ItemTier.bIII: 2,
        ItemTier.aII: 3,
        ItemTier.sI: 4,
        ItemTier.ssIII: 5,
        ItemTier.sssII: 6,
        ItemTier.kirmizi: 7,
        ItemTier.parlayanPembe: 7,
      };
      merdiven.forEach((tier, adet) {
        expect(
          ItemBudget.altStatSayisi(tier),
          adet,
          reason: '${tier.label} derinliği',
        );
      });
    });

    // KARAR 06.9 s2
    test('sayı AİLEDEN geliyor, basamaktan değil', () {
      // Aile içindeki üç basamak aynı derinliği taşıyor; ince güç farkı
      // basamağın, kaba nitelik ailenin.
      for (final tier in ItemTier.values) {
        if (tier.kapakTasi) continue;
        expect(
          ItemBudget.altStatSayisi(tier),
          math.min(tier.aile + 1, ItemBudget.altStatTavani),
          reason: tier.label,
        );
      }
      // Değişmez: alt stat sayısı rank ile ARTIYOR, hiç azalmıyor.
      for (var i = 1; i < ItemTier.values.length; i++) {
        expect(
          ItemBudget.altStatSayisi(ItemTier.values[i]),
          greaterThanOrEqualTo(
            ItemBudget.altStatSayisi(ItemTier.values[i - 1]),
          ),
          reason: '${ItemTier.values[i].label} derinliği geriledi',
        );
      }
    });

    // KARAR 06.9 s2
    test('tavan YEDİ — kütüphanenin havuzlara verebildiği en çok', () {
      expect(ItemBudget.altStatTavani, 7);
      expect(ItemBudget.altStatTavani, ItemTier.aileSayisi + 1);
      for (final tier in ItemTier.values) {
        expect(
          ItemBudget.altStatSayisi(tier),
          lessThanOrEqualTo(ItemBudget.altStatTavani),
        );
      }
      // Havuzun kendisi de tavanı taşıyabiliyor: yedili havuzlar olmasaydı
      // gerçekleşen derinlik `min(kapasite, havuz)` ile kilitlenirdi.
      expect(
        Catalogue.pl1.subStatPool,
        hasLength(ItemBudget.altStatTavani),
      );
    });
  });

  group('06.10 · kalite bandı rankla daralıyor, garantili alt stat', () {
    // KARAR 06.10 s2
    test('üç bant: C–S 0,70 · SS–SSS 0,75 · kapak taşları 0,80', () {
      expect(ItemBudget.kaliteAltSiniriFor(ItemTier.cI), 0.70);
      expect(ItemBudget.kaliteAltSiniriFor(ItemTier.sIII), 0.70);
      expect(ItemBudget.kaliteAltSiniriFor(ItemTier.ssI), 0.75);
      expect(ItemBudget.kaliteAltSiniriFor(ItemTier.sssIII), 0.75);
      expect(ItemBudget.kaliteAltSiniriFor(ItemTier.kirmizi), 0.80);
      expect(ItemBudget.kaliteAltSiniriFor(ItemTier.parlayanPembe), 0.80);
      // Band DARALIYOR: yukarı çıktıkça kötü roll ihtimali düşüyor.
      for (var i = 1; i < ItemTier.values.length; i++) {
        expect(
          ItemBudget.kaliteAltSiniriFor(ItemTier.values[i]),
          greaterThanOrEqualTo(
            ItemBudget.kaliteAltSiniriFor(ItemTier.values[i - 1]),
          ),
          reason: '${ItemTier.values[i].label} bandı genişledi',
        );
        expect(
          ItemBudget.kaliteAltSiniriFor(ItemTier.values[i]),
          lessThan(1.0),
        );
      }
    });

    // KARAR 06.10 s2
    test('garantili alt stat: SS–SSS bir, kapak taşları iki, altı sıfır', () {
      expect(ItemBudget.garantiliFor(ItemTier.cI), 0);
      expect(ItemBudget.garantiliFor(ItemTier.sIII), 0);
      expect(
        ItemBudget.garantiliFor(ItemTier.ssI),
        TasarimGirdileri.garantiliAltStatSS,
      );
      expect(
        ItemBudget.garantiliFor(ItemTier.sssIII),
        TasarimGirdileri.garantiliAltStatSS,
      );
      expect(
        ItemBudget.garantiliFor(ItemTier.parlayanPembe),
        TasarimGirdileri.garantiliAltStatRenk,
      );
      for (final tier in ItemTier.values) {
        expect(
          ItemBudget.garantiliFor(tier),
          lessThan(ItemBudget.altStatSayisi(tier)),
          reason: '${tier.label}: her stat garantili olamaz',
        );
      }
    });

    // KARAR 06.10 s2
    test('garantili statlar GERÇEKTEN bandın tepesinden — havuzun ilki', () {
      for (final tier in [ItemTier.ssI, ItemTier.parlayanPembe]) {
        final spec = Catalogue.items.firstWhere(
          (s) => s.slot == SlotType.laser && s.tier == tier,
        );
        final garanti = ItemBudget.garantiliFor(tier);
        final degerler = ItemBudget.subStatValues(spec, 0, hull, 'g-1');
        final adet = math.min(
          ItemBudget.altStatSayisi(tier),
          spec.subStatPool.length,
        );
        for (var i = 0; i < adet; i++) {
          final statId = spec.subStatPool[i];
          final taban = ItemBudget.altStatTabani(
            spec,
            0,
            hull,
            statId,
            'g-1',
          )!;
          if (i < garanti) {
            expect(
              degerler[statId],
              closeTo(taban, taban * 1e-9),
              reason: '${tier.label} garantili $statId rolü 1,0 değil',
            );
          } else {
            expect(
              degerler[statId],
              lessThan(taban),
              reason: '${tier.label} $statId garantisiz olmalıydı',
            );
          }
        }
      }
    });
  });
}

/// Bir örneğin alt statlarının BÜTÇE PUANI toplamı.
double altStatBudgetOf(ItemSpec spec, String instanceId, {int level = 0}) {
  var toplam = 0.0;
  for (final e
      in ItemBudget.subStatValues(
        spec,
        level,
        HullClass.bastion,
        instanceId,
      ).entries) {
    toplam += e.value / ItemBudget.birimFiyati(e.key);
  }
  return toplam;
}
