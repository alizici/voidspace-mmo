@Tags(['aralik', 'turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 14 · GANİMET — ganimet tablosunun değişmezleri.
///
/// Ganimet bir ödül sistemi değil bir ARZ sistemi: 13 talebi ilan etti, 14
/// onu karşılamak zorunda. Testlerin çoğu o dengeyi, gerisi kötü şansın
/// nerede durdurulduğunu ölçüyor.
void main() {
  final bantlar = [for (var r = 0; r < Turetilenler.rankSayisi; r++) r];

  group('alan 14 · malzeme dengesi', () {
    // KARAR 14.2 s1
    test('arz/talep oranı 1,4 – 2,0 — HER bantta', () {
      // Kırılırsa: bir bantta artı basmak ganimetle tıkanıyor (düşük) ya da
      // malzeme değersizleşiyor (yüksek).
      //
      // 13'ün doğrulanamadan bıraktığı değişmez bu ve burada kapanıyor.
      for (final r in bantlar) {
        expect(
          Ganimet.malzemeOraniFor(r),
          inInclusiveRange(1.4, 2.0),
          reason: 'bant $r oranı ${Ganimet.malzemeOraniFor(r)}',
        );
      }
    });

    // KARAR 14.2 s1
    test('oran bantlar arasında SABİT — ±%5', () {
      // Birinci testle aynı şeyi başka açıdan ölçüyor: o SEVİYEYİ, bu
      // TUTARLILIĞI. Yalnız ilki tutarsa ganimet çalışır ama bantlar arası
      // geçiş sarsıntılı olur.
      //
      // Sabitliğin sebebi kurun kendisi: hem yaratık ödülü hem gelir hedefi
      // aynı α'yı izliyor, yani oran sadeleşiyor.
      final oranlar = [for (final r in bantlar) Ganimet.malzemeOraniFor(r)];
      for (final o in oranlar) {
        expect(o, closeTo(oranlar.first, oranlar.first * 0.05));
      }
    });

    // KARAR 14.2 s1
    test('malzeme kuru TÜRETİLİYOR — bir malzeme bir öldürme', () {
      for (final r in bantlar) {
        expect(
          Ganimet.malzemeDegeriFor(r),
          DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan).kredi.toDouble(),
        );
      }
      // Ve kur bantla ölçekleniyor — malzeme sabit bir sayı değil.
      expect(
        Ganimet.malzemeDegeriFor(Turetilenler.rankSayisi - 1),
        greaterThan(Ganimet.malzemeDegeriFor(0)),
      );
    });

    // KARAR 14.2 s1
    test('bir öldürme BİR malzeme — miktar da öldürme süresinden', () {
      // Kurun iki ucu: MİKTAR (bir öldürme bir malzeme) ve DEĞER (o bandın
      // yaratık ödülü). İkisi de seçilmedi, öldürme süresinden ve ödülden
      // türedi.
      expect(Ganimet.malzemeFor(DusmanSinifi.siradan), 1.0);
      expect(
        Ganimet.malzemeFor(DusmanSinifi.siradan),
        closeTo(TasarimGirdileri.siradanOldurmeSuresi, 1e-12),
      );
      expect(
        Ganimet.malzemeFor(DusmanSinifi.siradan),
        closeTo(DusmanSinifi.siradan.oldurmeSuresi, 1e-12),
        reason: 'miktar sınıfın süresinden kopmuş',
      );
    });

    // KARAR 14.2 s1
    test('kurun getirisi: malzeme ÷ gelir oranı bantlar arası sabit', () {
      // Kurun seçilmeyip türetilmesinin karşılığı bu. Hem yaratık ödülü hem
      // gelir hedefi aynı α'yı izlediği için malzemenin bir saatlik gelire
      // oranı her bantta aynı; bir bantta bol olan malzeme diğerinde kıt
      // olmuyor. Yaratık ödülü tam sayıya yuvarlandığı için tolerans binde
      // bir.
      final oranlar = [
        for (final r in bantlar)
          Ganimet.malzemeDegeriFor(r) / KaynakAkisi.saatlikGelirFor(r),
      ];
      for (final o in oranlar) {
        expect(o, closeTo(oranlar.first, oranlar.first * 1e-3));
      }
      // Talep de aynı kurdan okunuyor: kredi cinsinden bütçe ÷ kur.
      for (final r in bantlar) {
        expect(
          Ganimet.malzemeTalebiFor(r) * Ganimet.malzemeDegeriFor(r),
          closeTo(
            KaynakAkisi.neselButcesi(r) *
                (KaynakAkisi.payFor(GiderKalemi.artiBasma) +
                    KaynakAkisi.payFor(GiderKalemi.sentez)),
            1e-6,
          ),
          reason: 'bant $r: talep kurdan geçmiyor',
        );
      }
    });

    // KARAR 14.5 s1
    test('parçalama verimi eşyanın öldürme MALİYETİNİN altında', () {
      // Kırılırsa: eşya farmı malzeme farmının yerine geçmiş ve ganimet ayrı
      // bir musluk olmaktan çıkmış.
      expect(Ganimet.parcalamaVerimi, lessThan(Ganimet.esyaMaliyeti));
      expect(
        Ganimet.parcalamaVerimi / Ganimet.esyaMaliyeti,
        closeTo(TasarimGirdileri.parcalamaOrani, 1e-9),
      );
    });
  });

  group('alan 14 · ritim', () {
    test('eşya bolluğu 1,0\'İN ÜSTÜNDE — yuvalar dolabiliyor', () {
      for (final r in bantlar) {
        expect(
          Ganimet.esyaBollugFor(r),
          greaterThanOrEqualTo(1.0),
          reason: 'bant $r: oyuncu yuvalarını dolduramıyor',
        );
      }
    });

    test('düşme şansı BÜTÜN bantlarda aynı — tek bir sayı', () {
      // Bir fonksiyon değil bir sabit olması tasarımın kendisi: üst bantlarda
      // nesiller uzasa da oyuncu aynı sıklıkta eşya görüyor.
      expect(Ganimet.dusmeSansi, inExclusiveRange(0.0, 1.0));
      expect(Ganimet.dusmeAraligiDk, greaterThan(0));
    });

    test('kredi ganimette YOK — ayrı musluk', () {
      // 13'ün ayrımı burada da korunuyor: kredi düşmüyor, yaratık ödülü
      // olarak doğrudan geliyor.
      expect(Kaynak.values, contains(Kaynak.malzeme));
      expect(Ganimet.malzemeFor(DusmanSinifi.siradan), greaterThan(0));
      // Parçalama krediye DEĞİL malzemeye çeviriyor — 13'ün düzelttiği hata.
      expect(Ganimet.parcalamaVerimi, greaterThan(0));
      expect(KaynakAkisi.cevrilebilir(Kaynak.malzeme, Kaynak.kredi), isFalse);
    });
  });

  group('alan 14 · sınıf orantısı', () {
    // KARAR 14.6 s1
    test('güçlü yaratığın ganimeti CANIYLA orantılı — hızlandırma yok', () {
      // Kırılırsa: bir sınıf ganimet için diğerinden verimli olmuş.
      final oran =
          TasarimGirdileri.gucluOldurmeSuresi /
          TasarimGirdileri.siradanOldurmeSuresi;
      expect(
        Ganimet.malzemeFor(DusmanSinifi.guclu) /
            Ganimet.malzemeFor(DusmanSinifi.siradan),
        closeTo(oran, 1e-9),
      );
      expect(
        Ganimet.esyaSansiFor(DusmanSinifi.guclu) /
            Ganimet.esyaSansiFor(DusmanSinifi.siradan),
        closeTo(oran, 1e-9),
      );
    });

    // KARAR 14.6 s1
    test('boss ganimeti %100 — iki saat ve grup boşa çıkamaz', () {
      expect(
        Ganimet.esyaSansiFor(DusmanSinifi.boss),
        TasarimGirdileri.bossEsyaSayisi.toDouble(),
      );
      expect(Ganimet.esyaSansiFor(DusmanSinifi.boss), greaterThanOrEqualTo(1));
    });

    // KARAR 14.6 s1
    test('boss malzemesi OYUNCU BAŞINA — grup payı değil', () {
      // Boss 360 saniye sürüyor ama üç oyuncuyla: her birine kendi 120
      // saniyesi kadar malzeme düşüyor.
      expect(
        Ganimet.malzemeFor(DusmanSinifi.boss),
        TasarimGirdileri.bossHedefSuresi,
      );
      expect(
        Ganimet.malzemeFor(DusmanSinifi.boss) * TasarimGirdileri.bossGrubu,
        closeTo(DusmanSinifi.boss.oldurmeSuresi, 1e-9),
      );
    });

    // KARAR 14.6 s1
    test('boss kalite bandı DAR ve yüksek — güvenilirlik', () {
      expect(
        Ganimet.bossKaliteAltSiniri,
        greaterThan(TasarimGirdileri.kaliteAltSiniri),
      );
      expect(
        Ganimet.bossUstRankSansi,
        greaterThan(TasarimGirdileri.ustRankSansi),
      );
    });
  });

  group('alan 14 · rank çekilişi', () {
    // KARAR 14.4 s1
    test('üç sonucun olasılıkları TAM 1,0', () {
      final toplam = GanimetRanki.values.fold(
        0.0,
        (a, r) => a + Ganimet.sansFor(r),
      );
      expect(toplam, closeTo(1.0, 1e-12));
      // Bandın payı TÜRETİLEN: kalan. Bir literale sabitlemek, iki girdiden
      // birini değiştirmeyi sessizce imkânsız yapardı.
      expect(
        Ganimet.bantRankSansi,
        closeTo(
          1 - TasarimGirdileri.altRankSansi - TasarimGirdileri.ustRankSansi,
          1e-12,
        ),
      );
    });

    // KARAR 14.4 s1
    test('bandın kendi rankı EN OLASI sonuç', () {
      for (final r in GanimetRanki.values) {
        if (r == GanimetRanki.bant) continue;
        expect(Ganimet.bantRankSansi, greaterThan(Ganimet.sansFor(r)));
      }
    });

    // KARAR 14.4 s1
    test('PRD ortalaması İLAN EDİLEN olasılığı veriyor', () {
      // İlan edilen olasılık sabitin kendisi değil: C ile ortalama %15
      // çıkıyor. Sayısal çözüm, elle yazılmış bir sabit değil.
      var beklenen = 0.0;
      var kalan = 1.0;
      for (var n = 1; n <= Ganimet.prdGarantisi; n++) {
        final p = Ganimet.ustRankOlasiligi(n);
        beklenen += kalan * p * n;
        kalan *= 1 - p;
      }
      expect(1 / beklenen, closeTo(TasarimGirdileri.ustRankSansi, 1e-4));
    });

    // KARAR 14.4 s1
    test('PRD seri KIRIYOR — garanti nesil süresinden kısa', () {
      // Kırılırsa: seri kırıcı kırdığı seriden yavaş, yani işlevsiz ve sistem
      // bağımsız zardan farksız.
      expect(
        Ganimet.prdGarantisiSaat,
        lessThan(Turetilenler.bantSuresi(0)),
        reason: 'PRD garantisi ilk nesilden uzun — hiç devreye girmiyor',
      );
      expect(Ganimet.ustRankOlasiligi(Ganimet.prdGarantisi), 1.0);
      expect(
        Ganimet.ustRankOlasiligi(1),
        lessThan(TasarimGirdileri.ustRankSansi),
      );
    });

    // KARAR 14.4 s1
    test('PRD YALNIZ üst ranka — diğer ikisi bağımsız zar', () {
      // Alt ve bant rankı sık gerçekleşiyor, zaten kötü seri üretmiyorlar; ve
      // PRD'nin varyans azaltması onları tahmin edilebilir yaparak
      // sıkıcılaştırırdı.
      expect(Ganimet.ustRankPrdSabiti, lessThan(TasarimGirdileri.ustRankSansi));
      expect(Ganimet.ustRankPrdSabiti, closeTo(0.03222, 0.0001));
    });
  });

  group('alan 14 · düşme aralığı', () {
    // Belgenin "≤ 15 dakika" değişmezi. Alan 13'teki gibi HEDEF merdivende
    // ölçülüyor: şans nesil süresine ters orantılı ve bugünkü beş ranklık
    // merdivende nesiller yedi kat uzun, yani şans yedi kat seyrek.
    const hedefRankSayisi = 20;
    const hedefIlkYuva = 14;

    double hedefSans() {
      final olcek = TuretilenTablolar.sureOlcegiFor(
        rankSayisi: hedefRankSayisi,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
        hedefSure: TasarimGirdileri.hedefSure,
      );
      final sure = TuretilenTablolar.bantSuresiFor(
        0,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
        olcek: olcek,
      );
      return hedefIlkYuva /
          TasarimGirdileri.kaliteHedefi /
          (sure * Ganimet.oldurmeHizi) *
          TasarimGirdileri.dusmeGuvenligi;
    }

    test('hedef merdivende 11 dakikada bir — nadir ama beklenebilir', () {
      final aralik = 60 / (hedefSans() * Ganimet.oldurmeHizi);
      expect(aralik, lessThanOrEqualTo(15));
      expect(
        aralik,
        greaterThan(5),
        reason: 'çok sıksa nadirlik anlamını yitirir',
      );
      expect(hedefSans(), closeTo(0.0137, 0.0005));
    });

    test('hedef merdivende bolluk ARTIYOR — geç oyunda seçme lüksü', () {
      // Şans sabit, nesiller uzuyor: üst bantlarda gerekenin katı düşüyor.
      // O lüks, +15'e ulaşamayan oyuncunun elindeki tek derinleşme yolu.
      //
      // Bugünkü beş ranklık merdivende bu eğri düz DEĞİL: yuva merdiveni
      // (12 → 20) nesil uzamasından hızlı büyüyor ve bolluk ortada dipliyor.
      // Yirmi rankta ikisi ayrışıyor ve eğri düzgün çıkıyor.
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
      final olcek = TuretilenTablolar.sureOlcegiFor(
        rankSayisi: hedefRankSayisi,
        artis: TasarimGirdileri.rankArtisi,
        us: TasarimGirdileri.gelirUssu,
        hedefSure: TasarimGirdileri.hedefSure,
      );
      double bolluk(int r) {
        final sure = TuretilenTablolar.bantSuresiFor(
          r,
          artis: TasarimGirdileri.rankArtisi,
          us: TasarimGirdileri.gelirUssu,
          olcek: olcek,
        );
        final esya = sure * Ganimet.oldurmeHizi * hedefSans();
        return esya / (hedefYuva[r] / TasarimGirdileri.kaliteHedefi);
      }

      expect(bolluk(0), closeTo(1.5, 0.05));
      expect(bolluk(hedefRankSayisi - 1), greaterThan(bolluk(0) * 1.5));
      for (final r in [0, 5, 10, 15, 19]) {
        expect(bolluk(r), greaterThanOrEqualTo(1.0));
      }
    });
  });

  group('alan 14 · nesil ölçeği', () {
    test('bir nesilde düşen eşya yuva sayısını AŞIYOR', () {
      for (final r in bantlar) {
        expect(
          Ganimet.esyaSayisiFor(r),
          greaterThan(
            HullClass.yuvaSayisi(ReferansBuild.kademeOf(r)).toDouble(),
          ),
          reason: 'bant $r: parçalanacak eşya kalmıyor',
        );
      }
    });

    // KARAR 14.5 s1
    test('parçalama arzın anlamlı bir PARÇASI ama çoğunluğu değil', () {
      for (final r in bantlar) {
        final oldurmeden = Ganimet.oldurmeSayisiFor(r);
        final pay = 1 - oldurmeden / Ganimet.malzemeArziFor(r);
        expect(pay, greaterThan(0.0));
        expect(
          pay,
          lessThan(0.5),
          reason: 'bant $r: malzemenin çoğu parçalamadan geliyor',
        );
      }
    });

    test('öldürme hızı çevrimden TÜRÜYOR', () {
      final cevrim =
          TasarimGirdileri.siradanDogusSuresi +
          TasarimGirdileri.siradanOldurmeSuresi;
      expect(Ganimet.oldurmeHizi, closeTo(3600 / cevrim, 1e-9));
      expect(Ganimet.oldurmeHizi, closeTo(400, 1));
    });
  });
}
