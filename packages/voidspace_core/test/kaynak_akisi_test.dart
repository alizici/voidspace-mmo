@Tags(['aralik', 'turetme'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 13 · KAYNAK AKIŞI — akış tablosunun değişmezleri.
///
/// Bir ekonominin sağlığı musluk ile giderin eşit olmasına değil, farklı
/// kaynakların birbirine DÖNÜŞMEMESİNE bağlı. Testlerin ilk grubu o kuralı
/// koruyor; gerisi payların ve musluğun şeklini.
void main() {
  final bantlar = [for (var r = 0; r < Turetilenler.rankSayisi; r++) r];

  group('alan 13 · dönüşüm yasağı', () {
    // KARAR 13.2 s1
    test('hiçbir kaynak diğerine çevrilemiyor', () {
      // Kırılırsa: üç musluk tek muslukta birleşmiş ve en verimlisi
      // diğerlerini öldürmüş.
      expect(TasarimGirdileri.paraCevirmeAcik, isFalse);
      for (final a in Kaynak.values) {
        for (final b in Kaynak.values) {
          expect(
            KaynakAkisi.cevrilebilir(a, b),
            isFalse,
            reason: '${a.name} → ${b.name} açılmış',
          );
        }
      }
    });

    // KARAR 13.1 s1 · KARAR 13.2 s1
    test(
      'NOVA ölçeklenmiyor, kredi ölçekleniyor — kur kendiliğinden kayıyor',
      () {
        // Çevirmenin imkânsız olmasının SEBEBİ bu. Kredi bantla yüzlerce kat
        // büyürken NOVA sabit kalıyor, yani NOVA'nın kredi cinsinden değeri
        // kendiliğinden aynı oranda artıyor. Tek yönlü bir çevirme bile üst
        // bantlı oyuncuya o oranda indirim yapardı.
        expect(Kaynak.nova.olceklenir, isFalse);
        expect(Kaynak.kredi.olceklenir, isTrue);
        expect(Kaynak.malzeme.olceklenir, isTrue);

        final ilk = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan);
        final son = DusmanTasarimi(
          rank: Turetilenler.rankSayisi - 1,
          sinif: DusmanSinifi.siradan,
        );
        expect(son.nova, ilk.nova);
        expect(son.kredi / ilk.kredi, greaterThan(2));
      },
    );

    // KARAR 13.1 s1 · KARAR 13.4 s1
    test('yorgunluk YALNIZ krediye — NOVA ikinci kez cezalandırılmıyor', () {
      expect(Kaynak.kredi.yorgunlugaTabi, isTrue);
      expect(Kaynak.nova.yorgunlugaTabi, isFalse);
      expect(Kaynak.malzeme.yorgunlugaTabi, isFalse);
    });

    // KARAR 13.1 s1
    test('malzeme bir PARA BİRİMİ değil — rank kapısı', () {
      // `Currency` iki değer taşıyor; malzeme onlardan biri DEĞİL. Tek bir
      // bakiyeye indirmek onu ikinci bir krediye çevirirdi ve rank kapısı
      // diye bir şey kalmazdı.
      expect(Currency.values, hasLength(2));
      expect(Kaynak.values, hasLength(3));
      for (final para in Currency.values) {
        expect(KaynakAkisi.kaynagi(para), isNot(Kaynak.malzeme));
      }
    });

    // KARAR 13.2 s1
    test('yasağın TEK kapısı `paraCevirmeAcik` — kilit yükü taşıyor', () {
      // Yasak bir `false` dönen fonksiyon değil, kilide BAĞLI bir fonksiyon:
      // çevrilebilirlik başka hiçbir koşula bakmıyor, yani dönüşüm ancak
      // bilinçli bir kararla — kilidi çevirip bu testi silerek — gelebilir.
      // Kilit sessizce açılırsa altı yön birden açılır ve test onu görür.
      for (final a in Kaynak.values) {
        for (final b in Kaynak.values) {
          expect(
            KaynakAkisi.cevrilebilir(a, b),
            TasarimGirdileri.paraCevirmeAcik && a != b,
            reason: '${a.name} → ${b.name} kilidin dışında bir yola bağlı',
          );
        }
      }
      // Aynı kilit 15'in yasak listesinde de okunuyor: NOVA'nın kredi
      // satması ayrı bir bayrağa değil buna bağlı (15.1).
      expect(
        Kazanc.satilabilir(Kaynak.kredi),
        TasarimGirdileri.paraCevirmeAcik,
      );
      expect(Kazanc.satilabilir(Kaynak.kredi), isFalse);
    });

    // KARAR 13.1 s1
    test('üç kaynak, ÜÇ davranış: kredi ×291, malzeme ×291, NOVA ×1', () {
      // Belgenin tablosu. Kredi ve malzeme kademeyle aynı üssü izliyor —
      // malzeme kuru zaten yaratık ödülü (14.2) — NOVA hiç ölçeklenmiyor.
      // Kırılırsa NOVA'nın kredi cinsinden değeri sabitlenir ve sert para
      // enflasyona açılır.
      final son = Turetilenler.rankSayisi - 1;
      double gelir(int r) => TuretilenTablolar.gelirFor(
        r,
        taban: TasarimGirdileri.tabanSaatlikGelir,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
      );
      final krediOlcegi = gelir(son) / gelir(0);
      final malzemeOlcegi =
          Ganimet.malzemeDegeriFor(son) / Ganimet.malzemeDegeriFor(0);
      expect(krediOlcegi, closeTo(291, 1));
      expect(
        malzemeOlcegi,
        closeTo(krediOlcegi, krediOlcegi * 1e-4),
        reason: 'malzeme kredinin üssünden ayrışmış',
      );
      final novaOlcegi =
          DusmanTasarimi(rank: son, sinif: DusmanSinifi.siradan).nova /
          DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan).nova;
      expect(novaOlcegi, 1);
      // Ve roller: kredi zamandan (yorgunluğa tabi), malzeme ganimetten
      // (yalnız öldürme ve parçalama), NOVA ölçeksiz.
      expect(Kaynak.kredi.yorgunlugaTabi, isTrue);
      expect(Ganimet.malzemeFor(DusmanSinifi.siradan), greaterThan(0));
      expect(Ganimet.parcalamaVerimi, greaterThan(0));
      expect(Kaynak.nova.olceklenir, isFalse);
    });
  });

  group('alan 13 · gider payları', () {
    // KARAR 13.3 s1
    test('payların toplamı TAM %100', () {
      // Kırılırsa: kalem eklenmiş ama diğerlerinden düşülmemiş.
      final toplam = GiderKalemi.values.fold(
        0.0,
        (a, k) => a + KaynakAkisi.payFor(k),
      );
      expect(toplam, closeTo(1.0, 1e-9));
    });

    // KARAR 13.3 s1
    test('onarım payı 11\'DEN TÜRÜYOR — elle yazılmamış', () {
      // Kırılırsa: ölüm sıklığı playtest'te değiştiğinde ekonomi kaymaz ve
      // beş kalemin dördü elle ayarlanmayı bekler.
      expect(
        KaynakAkisi.payFor(GiderKalemi.onarim),
        closeTo(
          TasarimGirdileri.genelOlumSikligi *
              TasarimGirdileri.olumMaliyetiDk /
              60,
          1e-12,
        ),
      );
      expect(KaynakAkisi.onarimPayi, closeTo(0.0833, 0.0001));
    });

    // KARAR 13.3 s1
    test('artı basma ekonominin ANA gideri', () {
      final arti = KaynakAkisi.payFor(GiderKalemi.artiBasma);
      for (final k in GiderKalemi.values) {
        if (k == GiderKalemi.artiBasma) continue;
        expect(arti, greaterThan(KaynakAkisi.payFor(k)));
      }
      expect(arti, closeTo(0.55, 0.005));
    });

    // KARAR 13.5 s1
    test('birikim payı SIFIRDAN büyük — tampon duruyor', () {
      // Kırılırsa: her oyuncu her an beş parasız ve tek bir kötü kararın
      // telafisi yok.
      expect(KaynakAkisi.payFor(GiderKalemi.birikim), greaterThan(0));
    });

    // KARAR 13.3 s1
    test('onarım payı %25\'i aşarsa PvP tasarımı bozulmuş demektir', () {
      // Belgenin kendi alarm eşiği. Bugün %8,3; sıklık 3/saati bulursa %25.
      expect(KaynakAkisi.onarimPayi, lessThan(0.25));
      // Eşik bir tahmin değil, aynı türetmenin başka bir sıklıkla okunuşu.
      expect(
        3 * TasarimGirdileri.olumMaliyetiDk / 60,
        closeTo(0.25, 1e-12),
      );
    });

    // KARAR 13.3 s1
    test('kalan pay DÖRDE bölünüyor — onarım değişince dördü sıkışıyor', () {
      // Kararın asıl cümlesi: onarım türetilen, gerisi ilan edilen paylar
      // ama ETKİN payları bölünen paydan geçiyor. Elle yazılsalardı ölüm
      // sıklığı değiştiğinde toplam %100'ü aşardı.
      const ilanlar = {
        GiderKalemi.artiBasma: TasarimGirdileri.payArti,
        GiderKalemi.sentez: TasarimGirdileri.paySentez,
        GiderKalemi.magaza: TasarimGirdileri.payMagaza,
        GiderKalemi.birikim: TasarimGirdileri.payBirikim,
      };
      expect(
        ilanlar.values.fold(0.0, (a, b) => a + b),
        closeTo(1.0, 1e-12),
        reason: 'ilan edilen dört pay kendi içinde %100 değil',
      );
      for (final e in ilanlar.entries) {
        expect(
          KaynakAkisi.payFor(e.key),
          closeTo(KaynakAkisi.bolunenPay * e.value, 1e-12),
          reason: '${e.key.name} bölünen paydan geçmiyor',
        );
      }
      expect(
        KaynakAkisi.bolunenPay,
        closeTo(1 - KaynakAkisi.onarimPayi, 1e-12),
      );
      // Dördünün BİRBİRİNE oranı onarımdan bağımsız: sıklık değişince
      // hepsi aynı çarpanla sıkışıyor, sıralama bozulmuyor.
      expect(
        KaynakAkisi.payFor(GiderKalemi.artiBasma) /
            KaynakAkisi.payFor(GiderKalemi.birikim),
        closeTo(TasarimGirdileri.payArti / TasarimGirdileri.payBirikim, 1e-12),
      );
    });

    // KARAR 13.5 s1
    test('birikim GİDER değil tampon — harcanan dört kalemin dışı', () {
      // Tampon, gelirin harcanmayan payı: dört gider kalemi artı onarım
      // toplamı birden küçük ve aradaki fark tam olarak birikim. Sıfıra
      // inerse oyuncu her an beş parasız ve kötü kararın telafisi yok.
      final harcanan = [
        GiderKalemi.onarim,
        GiderKalemi.artiBasma,
        GiderKalemi.sentez,
        GiderKalemi.magaza,
      ].fold(0.0, (a, k) => a + KaynakAkisi.payFor(k));
      expect(harcanan, lessThan(1.0), reason: 'gelirin tamamı harcanıyor');
      expect(
        1 - harcanan,
        closeTo(KaynakAkisi.payFor(GiderKalemi.birikim), 1e-12),
      );
      expect(KaynakAkisi.payFor(GiderKalemi.birikim), greaterThan(0));
      // Ömür boyu duran miktar: nesiller boyunca biriken tampon.
      expect(
        KaynakAkisi.omurBoyuKredi * KaynakAkisi.payFor(GiderKalemi.birikim),
        greaterThan(0),
      );
    });
  });

  group('alan 13 · yorgunluk', () {
    // KARAR 13.4 s1
    test('eşik / gelir oranı bantlar arası SABİT', () {
      // Kırılırsa: eşik ölçeklenmemiş ve üst bölgeler tabana çakılı.
      // Ölçek ayrı bir sayı DEĞİL, 10'un α'sını yeniden kullanıyor — ayrı
      // verilseydi gelir ile eşik zamanla ayrışırdı.
      final oranlar = [
        for (final r in bantlar)
          Fatigue.softCapFor(r) /
              TuretilenTablolar.gelirFor(
                r,
                taban: TasarimGirdileri.tabanSaatlikGelir,
                artis: TasarimGirdileri.rankArtisi,
                us: TasarimGirdileri.gelirUssu,
              ),
      ];
      for (final o in oranlar) {
        expect(o, closeTo(oranlar.first, oranlar.first * 1e-5));
      }
    });

    // KARAR 13.4 s1
    test('normal oyuncu eğriyi GÖRMÜYOR — eşik gelirin üstünde', () {
      for (final r in bantlar) {
        final gelir = TuretilenTablolar.gelirFor(
          r,
          taban: TasarimGirdileri.tabanSaatlikGelir,
          artis: TasarimGirdileri.rankArtisi,
          us: TasarimGirdileri.gelirUssu,
        );
        expect(Fatigue.softCapFor(r), greaterThan(gelir));
      }
    });

    // KARAR 13.4 s1
    test('yarı ömür AYNI ölçekle büyüyor — eğrinin şekli korunuyor', () {
      // Eşik kayıyor ama eğri değişmiyor: yarı ömür eşikle aynı çarpanı
      // almazsa üst bantlarda düşüş dikleşir ya da düzleşir.
      for (final r in bantlar) {
        expect(
          Fatigue.halfLifeFor(r) / Fatigue.softCapFor(r),
          closeTo(Fatigue.halfLife / Fatigue.softCap, 1e-4),
          reason: 'bant $r: eğrinin şekli kaymış',
        );
      }
      // Ölçek AYRI bir girdi değil: 10'un α'sı yeniden kullanılıyor.
      for (final r in bantlar) {
        final olcek = math.pow(
          TuretilenTablolar.rankCarpaniFor(r, TasarimGirdileri.rankArtisi),
          TasarimGirdileri.gelirUssu,
        );
        expect(
          Fatigue.softCapFor(r),
          (Fatigue.softCap * olcek).round(),
          reason: 'bant $r eşiği gelirin üssünden ayrışmış',
        );
      }
    });

    // KARAR 13.4 s1
    test('iki katı farm eden HER bantta yarı çarpana düşüyor', () {
      // Eşiğin gelire oranı sabit olmasının oynanıştaki karşılığı bu: aynı
      // davranış her bantta aynı cezayı alıyor. Eşik sabit kalsaydı üst
      // bantlarda oyuncu ilk dakikada tabana çakılırdı.
      for (final r in bantlar) {
        final normal = Fatigue(earned: Fatigue.softCapFor(r) ~/ 2);
        expect(normal.multiplierAt(0, rank: r), 1.0, reason: 'bant $r');
        final ikiKat = Fatigue(earned: 2 * Fatigue.softCapFor(r));
        expect(
          ikiKat.multiplierAt(0, rank: r),
          closeTo(0.5, 1e-6),
          reason: 'bant $r: iki katı farm eden yarı çarpanda değil',
        );
        // Ve hiçbir bantta sıfıra inmiyor: duvar değil eğri.
        final bot = Fatigue(earned: 1000 * Fatigue.softCapFor(r));
        expect(bot.multiplierAt(0, rank: r), Fatigue.floor);
      }
    });
  });

  group('alan 13 · musluk', () {
    test('NOVA musluğu bantlar arası SABİT', () {
      // Kırılırsa: sert para enflasyona açılmış ve 15'in fiyatları geçersiz.
      final hizlar = [
        for (final r in bantlar)
          DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan).nova,
      ];
      expect(hizlar.toSet(), hasLength(1));
      expect(KaynakAkisi.omurBoyuNova, greaterThan(0));
    });

    test('nesil bütçesi merdiven boyunca ARTIYOR', () {
      for (var r = 1; r < Turetilenler.rankSayisi; r++) {
        expect(
          KaynakAkisi.neselButcesi(r),
          greaterThan(KaynakAkisi.neselButcesi(r - 1)),
        );
      }
    });

    test('her rank BİR gövde kademesine düşüyor', () {
      for (final r in bantlar) {
        expect(
          ReferansBuild.kademeOf(r),
          inInclusiveRange(0, TasarimGirdileri.govdeKademeSayisi - 1),
        );
      }
      expect(() => ReferansBuild.kademeOf(-1), throwsArgumentError);
      expect(
        () => ReferansBuild.kademeOf(Turetilenler.rankSayisi),
        throwsArgumentError,
      );
    });
  });

  group('alan 13 · +15 nesil içinde ulaşılamaz', () {
    // Belgenin TERS YÖNDE çalışan tek testi: bir şeyin ULAŞILAMAZ kalmasını
    // ölçüyor. Ekonomi ucuzlarsa +15 nesil içine girer ve tavan sonrası
    // kuyruk buharlaşır.
    //
    // Bugünkü kodda merdiven beş rank; belge yirmi rank için yazıldı ve
    // ikisi aynı ekonomiyi ÜRETMİYOR: 780 saat beşe bölününce bant başına
    // bütçe üç buçuk kat büyüyor ve +15 her bantta ulaşılabilir hâle
    // geliyor. Bu yüzden değişmez HEDEF merdivende ölçülüyor — saf
    // fonksiyonlar zaten parametreli.
    const hedefRankSayisi = 20;
    const hedefYuva = [
      14,
      14,
      19,
      19,
      19,
      22,
      22,
      22,
      23,
      23,
      24,
      24,
      25,
      25,
      25,
      26,
      26,
      26,
      27,
      27,
    ];

    double yuvaBasinaArti(int rank) {
      final olcek = TuretilenTablolar.sureOlcegiFor(
        rankSayisi: hedefRankSayisi,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
        hedefSure: TasarimGirdileri.hedefSure,
      );
      final gelir = TuretilenTablolar.gelirFor(
        rank,
        taban: TasarimGirdileri.tabanSaatlikGelir,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
      );
      final sure = TuretilenTablolar.bantSuresiFor(
        rank,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
        olcek: olcek,
      );
      // Filo ayrı kalem (13.6 s2): artı payının droid payı kadarı filoya.
      return gelir *
          sure *
          KaynakAkisi.payFor(GiderKalemi.artiBasma) *
          (1 - TasarimGirdileri.payDroid / 100) /
          hedefYuva[rank];
    }

    /// Rankın kendi eşyasının tam +15 maliyeti.
    double tamArtiMaliyeti(int rank) =>
        ItemLevels.totalCost(ItemLevels.max, ItemTier.cI) *
        math.pow(TasarimGirdileri.rankArtisi, rank).toDouble();

    test('hiçbir nesilde +15\'e ulaşılmıyor — ×2 ile ×5 arası', () {
      for (var r = 0; r < hedefRankSayisi; r++) {
        final kat = tamArtiMaliyeti(r) / yuvaBasinaArti(r);
        expect(
          kat,
          inInclusiveRange(2.0, 5.0),
          reason: 'bant ${r + 1}: +15 nesil bütçesinin ×$kat katı',
        );
      }
    });

    test('erişilebilirlik merdiven boyunca DÜŞÜYOR — yuva enflasyonu', () {
      // Erken oyun derin, geç oyun geniş. Aynı para iki kat fazla eşyaya
      // bölünüyor; derinlik tavana varıldığında geri geliyor.
      final ilk = tamArtiMaliyeti(0) / yuvaBasinaArti(0);
      final son =
          tamArtiMaliyeti(hedefRankSayisi - 1) /
          yuvaBasinaArti(hedefRankSayisi - 1);
      expect(son, greaterThan(ilk));
      expect(hedefYuva.last, greaterThan(hedefYuva.first));
    });

    test('endgame kuyruğu VAR — tavandan sonra oynanacak süre kalıyor', () {
      expect(KaynakAkisi.endgameSuresi, greaterThan(0));
      expect(KaynakAkisi.toplamSure, greaterThan(TasarimGirdileri.hedefSure));
    });
  });

  group('alan 13 · 14\'e devredilen', () {
    test('malzeme TALEBİ hesaplanabiliyor — arz 14\'ten gelecek', () {
      // Belgenin son değişmezi ("malzeme talebi ≤ 14'ün arzı") bugün
      // doğrulanamıyor: arz henüz tanımlı değil. Testi şimdiden yazmak, 14
      // yazıldığında ilk bakılacak yerin belli olmasını sağlıyor.
      //
      // Talep tarafı hazır: artı basma payı ve rank kapısı biliniyor.
      expect(KaynakAkisi.payFor(GiderKalemi.artiBasma), greaterThan(0));
      expect(Kaynak.malzeme.olceklenir, isTrue);
      expect(
        Kaynak.values.where((k) => k == Kaynak.malzeme),
        hasLength(1),
        reason: 'malzeme kaynağı tanımlı değil — 14 neye yaslanacak?',
      );
    });
  });
}
