@Tags(['aralik', 'turetme'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// GANİMET ÇEKİLİŞİ — alan 14'ün sayıları bir öldürmeye uygulanınca.
///
/// Buradaki testlerin çoğu OLASILIKSAL ve hepsi sabit tohumlu: aynı tohum aynı
/// sonucu veriyor, yani "bazen kırmızı" diye bir şey yok. Örneklem sayıları
/// beklenen değerin etrafındaki bandı istatistiksel olarak güvenli kılacak
/// kadar büyük seçildi; gevşek bir tolerans, bozuk bir dağılımı da geçirirdi.
void main() {
  /// Tek bir çekiliş kurulumu — tekrar eden altı satır.
  GanimetPayi ganimet({
    DusmanSinifi sinif = DusmanSinifi.siradan,
    double hasarPayi = 1.0,
    int rank = 5,
    required PrdRoller prd,
    required math.Random zar,
    int no = 0,
  }) => GanimetCekilisi.cek(
    sinif: sinif,
    hasarPayi: hasarPayi,
    rank: rank,
    prd: prd,
    zar: zar,
    kimlikUret: (d) => 'k$no-$d',
  );

  /// Yalnız düşen EŞYALAR — testlerin çoğu onunla ilgileniyor.
  List<GanimetSonucu> cek({
    DusmanSinifi sinif = DusmanSinifi.siradan,
    double hasarPayi = 1.0,
    int rank = 5,
    required PrdRoller prd,
    required math.Random zar,
    int no = 0,
  }) => ganimet(
    sinif: sinif,
    hasarPayi: hasarPayi,
    rank: rank,
    prd: prd,
    zar: zar,
    no: no,
  ).esyalar;

  PrdRoller yeniPrd() => PrdRoller(TasarimGirdileri.ustRankSansi);

  group('korunum', () {
    test('beklenen eşya sayısı hasar payıyla ORANTILI', () {
      // Ekonominin bozulabileceği tek yer: pay toplamı 1 olduğu sürece bir
      // öldürmeden çıkan toplam eşya grup büyüklüğünden bağımsız kalmalı.
      const deneme = 60000;
      for (final pay in [1.0, 0.5, 0.25]) {
        final zar = math.Random(7);
        final prd = yeniPrd();
        var toplam = 0;
        for (var i = 0; i < deneme; i++) {
          toplam += cek(hasarPayi: pay, prd: prd, zar: zar, no: i).length;
        }
        // Gövde kalemi artı filo kalemi (14.3 s2): ikisi de payla orantılı.
        final beklenen =
            (Ganimet.esyaSansiFor(DusmanSinifi.siradan) +
                Ganimet.droidEsyaSansiFor(DusmanSinifi.siradan)) *
            pay *
            deneme;
        expect(
          toplam / beklenen,
          closeTo(1.0, 0.12),
          reason: 'pay $pay: $toplam düştü, beklenen ${beklenen.round()}',
        );
      }
    });

    test('grup PARÇALANDIĞINDA toplam beklenti değişmiyor', () {
      // Aynı öldürme: tek kişi %100 mü yapmış, dört kişi %25'er mi — toplam
      // beklenen eşya aynı olmak zorunda. Eşik koysaydık bu bozulurdu.
      const deneme = 40000;
      int say(List<double> paylar) {
        final zar = math.Random(11);
        final prd = yeniPrd();
        var toplam = 0;
        for (var i = 0; i < deneme; i++) {
          for (final p in paylar) {
            toplam += cek(hasarPayi: p, prd: prd, zar: zar, no: i).length;
          }
        }
        return toplam;
      }

      final tek = say([1.0]);
      final dort = say([0.25, 0.25, 0.25, 0.25]);
      expect(dort / tek, closeTo(1.0, 0.12), reason: 'tek $tek · dört $dort');
    });
  });

  group('boss', () {
    // Filo AYRI kalem (14.3 s2): droid eşyası kendi zarını atıyor. Boss'un
    // garantisi gövde kaleminin; droid kalemi aynı oranla, kesri zarda.
    bool govde(GanimetSonucu g) =>
        Catalogue.byId[g.specId]!.slot != SlotType.droid;

    // KARAR 14.6 s1
    test('tam hasar payında GARANTİLİ sayıda eşya', () {
      final zar = math.Random(3);
      final prd = yeniPrd();
      for (var i = 0; i < 40; i++) {
        final g = cek(sinif: DusmanSinifi.boss, prd: prd, zar: zar, no: i);
        expect(g.where(govde), hasLength(TasarimGirdileri.bossEsyaSayisi));
        final droid = g.length - g.where(govde).length;
        final beklenen = Ganimet.droidEsyaSansiFor(DusmanSinifi.boss);
        expect(
          droid,
          inInclusiveRange(beklenen.floor(), beklenen.ceil()),
          reason: 'boss droid kalemi orandan sapıyor',
        );
      }
    });

    test('yarım payda ORTALAMA yarısı — kesir zara bırakılıyor', () {
      const deneme = 4000;
      final zar = math.Random(5);
      final prd = yeniPrd();
      var toplam = 0;
      for (var i = 0; i < deneme; i++) {
        toplam += cek(
          sinif: DusmanSinifi.boss,
          hasarPayi: 0.5,
          prd: prd,
          zar: zar,
          no: i,
        ).where(govde).length;
      }
      final beklenen = TasarimGirdileri.bossEsyaSayisi * 0.5 * deneme;
      expect(toplam / beklenen, closeTo(1.0, 0.05));
    });

    // KARAR 14.6 s1
    test('KALİTE TABANI tutuyor — kimlik seçilerek', () {
      final zar = math.Random(13);
      final prd = yeniPrd();
      var bakilan = 0;
      for (var i = 0; i < 200; i++) {
        for (final g in cek(
          sinif: DusmanSinifi.boss,
          prd: prd,
          zar: zar,
          no: i,
        )) {
          bakilan++;
          expect(
            ItemBudget.kaliteRolu(g.instanceId, 0),
            greaterThanOrEqualTo(Ganimet.bossKaliteAltSiniri),
            reason: '${g.instanceId} boss kalite tabanının altında',
          );
        }
      }
      expect(bakilan, greaterThan(100), reason: 'örneklem oluşmadı');
    });

    // KARAR 14.6 s1
    test('üst rank şansı PRD\'siz — ilan edilen orana yakın', () {
      const deneme = 6000;
      final zar = math.Random(17);
      final prd = yeniPrd();
      var ust = 0, hepsi = 0;
      for (var i = 0; i < deneme; i++) {
        for (final g in cek(
          sinif: DusmanSinifi.boss,
          prd: prd,
          zar: zar,
          no: i,
        )) {
          hepsi++;
          if (Catalogue.byId[g.specId]!.tier.index > 5) ust++;
        }
      }
      expect(ust / hepsi, closeTo(Ganimet.bossUstRankSansi, 0.03));
    });
  });

  group('rank çekilişi', () {
    // KARAR 14.4 s1
    test('üç kademe de ÇIKIYOR ve ilan edilen paylara yakın', () {
      const deneme = 30000;
      final zar = math.Random(23);
      final prd = yeniPrd();
      final sayim = <int, int>{};
      var hepsi = 0;
      for (var i = 0; i < deneme; i++) {
        for (final g in cek(
          sinif: DusmanSinifi.guclu,
          prd: prd,
          zar: zar,
          no: i,
        )) {
          hepsi++;
          sayim.update(
            Catalogue.byId[g.specId]!.tier.index,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }
      }
      expect(hepsi, greaterThan(1000), reason: 'örneklem yetersiz');
      // rank 5 çekildi: alt=4, bant=5, üst=6.
      for (final (indeks, beklenen) in [
        (4, Ganimet.sansFor(GanimetRanki.alt)),
        (5, Ganimet.sansFor(GanimetRanki.bant)),
        (6, Ganimet.sansFor(GanimetRanki.ust)),
      ]) {
        expect(
          (sayim[indeks] ?? 0) / hepsi,
          closeTo(beklenen, 0.04),
          reason: 'rank indeksi $indeks payı tutmuyor',
        );
      }
    });

    // KARAR 14.4 s1
    test('PRD üst rankı GARANTİ ediyor — kuru seri yok', () {
      // Acıma sisteminin tek işi bu: `prdGarantisi` düşüşten uzun üst-ranksız
      // seri olmamalı. Bağımsız zarda böyle seriler kaçınılmaz.
      //
      // **Örneklem BÜYÜK olmak zorunda ve bu ölçüldü.** İlk hâli sıradan
      // yaratıkla 20.000 öldürme deniyordu; oradan yalnız ~236 düşüş çıkıyor
      // ve düz zarın beklenen en uzun kuru serisi ≈34 — garanti eşiğinin (32)
      // hemen yanında. Mutasyon sınaması gösterdi: PRD'yi söküp düz zar
      // koyduğumda test GEÇTİ. Güçlü yaratık beş kat sık düşürüyor ve
      // 60.000 öldürme ~3.500 düşüş veriyor; düz zarın beklenen en uzun
      // serisi orada ≈50, yani eşiği rahatça aşıyor ve fark ölçülebilir
      // hâle geliyor.
      final zar = math.Random(29);
      final prd = yeniPrd();
      var seri = 0, enUzun = 0, dusen = 0;
      for (var i = 0; i < 60000; i++) {
        for (final g in cek(
          sinif: DusmanSinifi.guclu,
          prd: prd,
          zar: zar,
          no: i,
        )) {
          dusen++;
          if (Catalogue.byId[g.specId]!.tier.index > 5) {
            enUzun = math.max(enUzun, seri);
            seri = 0;
          } else {
            seri++;
          }
        }
      }
      expect(dusen, greaterThan(2500), reason: 'örneklem PRD\'yi ayırt edemez');
      expect(
        enUzun,
        lessThan(Ganimet.prdGarantisi),
        reason: '$enUzun düşüş boyunca üst rank çıkmadı',
      );
    });

    test('merdivenin UÇLARINDA taşma yok', () {
      final zar = math.Random(31);
      final prd = yeniPrd();
      for (final rank in [0, ItemTier.values.length - 1]) {
        for (var i = 0; i < 300; i++) {
          for (final g in cek(
            sinif: DusmanSinifi.boss,
            rank: rank,
            prd: prd,
            zar: zar,
            no: i,
          )) {
            final t = Catalogue.byId[g.specId]!.tier.index;
            expect(t, inInclusiveRange(0, ItemTier.values.length - 1));
          }
        }
      }
    });

    // KARAR 14.4 s1 · KARAR 14.6 s1
    test('doymuş PRD sayacı sıradan düşüşte GARANTİ, boss\'ta HÜKÜMSÜZ', () {
      // "PRD yalnız üst ranka" ile "boss'ta PRD yok" aynı satırın iki yüzü.
      // Sayaç garanti eşiğine getirildiğinde bir sonraki düşüş üst rank
      // olmak ZORUNDA; boss aynı doymuş sayaçla ilan edilen oranında
      // kalıyor, çünkü boss dalı zarı doğrudan atıyor. Boss'a da PRD
      // uygulansaydı nadirlik iki kez telafi edilirdi.
      const bantRank = 5;
      final doymus = yeniPrd()
        ..kacirmayiGeriYukle(Ganimet.prdGarantisi - 1);
      expect(doymus.currentChance, 1.0, reason: 'sayaç garantiye ulaşmadı');

      final zar = math.Random(101);
      GanimetSonucu? ilk;
      for (var i = 0; i < 5000 && ilk == null; i++) {
        final dusen = cek(
          sinif: DusmanSinifi.guclu,
          rank: bantRank,
          prd: doymus,
          zar: zar,
          no: i,
        );
        if (dusen.isNotEmpty) ilk = dusen.first;
      }
      expect(ilk, isNotNull, reason: 'örneklemde hiç eşya düşmedi');
      expect(
        Catalogue.byId[ilk!.specId]!.tier.index,
        bantRank + 1,
        reason: 'garanti eşiğindeki sayaç üst rankı vermedi',
      );

      // Boss: doymuş sayaç hiç okunmuyor, oran ilan edilen yarı yarıya ve
      // ALT rank hiç çıkmıyor — dağılım yukarı kaymış.
      final bossPrd = yeniPrd()
        ..kacirmayiGeriYukle(Ganimet.prdGarantisi - 1);
      final bossZar = math.Random(103);
      var ust = 0, hepsi = 0, alt = 0;
      for (var i = 0; i < 2000; i++) {
        for (final g in cek(
          sinif: DusmanSinifi.boss,
          rank: bantRank,
          prd: bossPrd,
          zar: bossZar,
          no: i,
        )) {
          hepsi++;
          final t = Catalogue.byId[g.specId]!.tier.index;
          if (t == bantRank + 1) ust++;
          if (t < bantRank) alt++;
        }
      }
      expect(hepsi, greaterThan(1000), reason: 'boss örneklemi yetersiz');
      expect(alt, 0, reason: 'boss alt rank düşürdü');
      expect(
        ust / hepsi,
        closeTo(Ganimet.bossUstRankSansi, 0.03),
        reason: 'boss doymuş sayaçtan etkilendi — PRD sızmış',
      );
      expect(bossPrd.misses, Ganimet.prdGarantisi - 1, reason: 'sayaç okundu');
    });
  });

  group('belirlenimcilik', () {
    test('aynı tohum aynı sonucu veriyor', () {
      List<String> kos() {
        final zar = math.Random(41);
        final prd = yeniPrd();
        return [
          for (var i = 0; i < 500; i++)
            for (final g in cek(
              sinif: DusmanSinifi.guclu,
              prd: prd,
              zar: zar,
              no: i,
            ))
              '${g.specId}/${g.instanceId}',
        ];
      }

      expect(kos(), kos());
    });

    test('düşen her eşya KATALOGDA var', () {
      final zar = math.Random(43);
      final prd = yeniPrd();
      for (var i = 0; i < 500; i++) {
        for (final g in cek(
          sinif: DusmanSinifi.boss,
          prd: prd,
          zar: zar,
          no: i,
        )) {
          expect(
            Catalogue.byId[g.specId],
            isNotNull,
            reason: '${g.specId} katalogda yok — yabancı anahtar kırıldı',
          );
        }
      }
    });

    test('kimlikler BENZERSİZ — iki düşüş aynı örneği üretmiyor', () {
      final zar = math.Random(47);
      final prd = yeniPrd();
      final gorulen = <String>{};
      for (var i = 0; i < 400; i++) {
        for (final g in cek(
          sinif: DusmanSinifi.boss,
          prd: prd,
          zar: zar,
          no: i,
        )) {
          expect(gorulen.add(g.instanceId), isTrue, reason: 'çakışan kimlik');
        }
      }
    });
  });

  group('parçalama', () {
    ItemSpec ornek(ItemTier tier) => Catalogue.items.firstWhere(
      (s) => s.tier == tier && s.slot != SlotType.droid,
    );

    // KARAR 14.5 s1 · KARAR 13.2 s1
    test('eşyanın ikinci hayatı MALZEME — kredi basmıyor', () {
      // Ganimet belgesi bir zamanlar "parçalama krediye çevirir" diyordu;
      // öyle olsaydı ganimet ikinci bir kredi musluğu olur ve 11'in saatlik
      // hedefi hedef olmaktan çıkardı. Kredi bakiyesi parçalamada
      // DEĞİŞMEMELİ.
      final spec = ornek(ItemTier.cI);
      final hangar = Hangar(accountId: 'a', credits: 5000);
      hangar.addItem(ItemInstance(instanceId: 'x', specId: spec.id));
      final (kazanc, hata) = HangarRules.parcala(hangar, 'x');
      expect(hata, isNull);
      expect(hangar.credits, 5000, reason: 'parçalama kredi bastı');
      expect(kazanc, GanimetCekilisi.parcalamaKazanci(spec.tier));
      expect(kazanc, greaterThan(0));
      expect(hangar.malzemeSayisi(Malzeme.forRank(spec.tier)), kazanc);
      expect(hangar.itemOf('x'), isNull, reason: 'eşya envanterde kaldı');
      expect(
        KaynakAkisi.cevrilebilir(Kaynak.malzeme, Kaynak.kredi),
        isFalse,
      );
    });

    // KARAR 14.5 s1
    test('verim öldürme maliyetinin bir PAYI — aşağı yuvarlanıyor', () {
      // Tamamı verilseydi eşya farmı malzeme farmıyla eşitlenirdi. Yukarı
      // yuvarlamak da en ucuz eşyayı alıp parçalayarak malzeme basmayı
      // kârlı kılardı.
      expect(
        Ganimet.parcalamaVerimi,
        closeTo(
          Ganimet.esyaMaliyeti * TasarimGirdileri.parcalamaOrani,
          1e-9,
        ),
      );
      for (final tier in ItemTier.values) {
        expect(
          GanimetCekilisi.parcalamaKazanci(tier),
          (Ganimet.parcalamaVerimi * tier.multiplier).floor(),
        );
        expect(
          GanimetCekilisi.parcalamaKazanci(tier).toDouble(),
          lessThanOrEqualTo(Ganimet.esyaMaliyeti * tier.multiplier),
          reason: '${tier.name}: parçalama öldürme maliyetini geçti',
        );
      }
      // Üst rank eşya daha çok öldürmeye mal oluyor, karşılığı da o kadar.
      expect(
        GanimetCekilisi.parcalamaKazanci(ItemTier.values.last),
        greaterThan(GanimetCekilisi.parcalamaKazanci(ItemTier.values.first)),
      );
    });

    // KARAR 14.5 s1
    test('çevirici YALNIZ parçalamadan geliyor — düşen eşya getirmiyor', () {
      final spec = ornek(ItemTier.cI);
      final hangar = Hangar(accountId: 'a', credits: 0);
      final cevirici = Malzeme.cevirmeFor(spec.tier);
      // Ganimet payında çevirici kalemi yok: bir öldürme eşya ve malzeme
      // veriyor, çevirici vermiyor.
      final zar = math.Random(53);
      final prd = yeniPrd();
      for (var i = 0; i < 300; i++) {
        for (final g in cek(sinif: DusmanSinifi.boss, prd: prd, zar: zar, no: i)) {
          hangar.addItem(
            ItemInstance(instanceId: g.instanceId, specId: g.specId),
          );
        }
      }
      expect(
        hangar.malzemeSayisi(cevirici),
        0,
        reason: 'çevirici ganimetten düştü — nadirliği kalmaz',
      );
      hangar.addItem(ItemInstance(instanceId: 'y', specId: spec.id));
      HangarRules.parcala(hangar, 'y');
      expect(
        hangar.malzemeSayisi(cevirici),
        GanimetCekilisi.parcalamaCeviriciKazanci,
      );
    });
  });
}
