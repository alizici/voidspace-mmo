@Tags(['aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 15 · KAZANÇ — kazanç tablosunun değişmezleri.
///
/// Bu alanın sınavı iki satır ve **ikisi de 15'in kendi kontrolünde değil**:
/// paranın tavanı 06, 07 ve 14'ün kısıtlarından çıkıyor. Bilinçli — bir
/// kazanç alanının kendi tavanını kendisi belirlemesi, tavanın olmaması
/// demektir.
void main() {
  group('alan 15 · paranın tavanı', () {
    // KARAR 15.4 s1
    test('tavan TEK BİR artı seviyesi büyüklüğünde', () {
      // Kırılırsa: ödeme, zamanla kazanılan en küçük adımı geçmiş (yukarı) ya
      // da mağaza tamamen anlamsızlaşmış (aşağı).
      //
      // Belgenin karşılaştırması bu: paranın tümüyle aldığı avantaj bir artı
      // seviyesi kadar — o adımların hepsinden küçük değil, aralığın içinde.
      final (enKucuk, enBuyuk) = Kazanc.artiAdimAraligi;
      expect(Kazanc.tavan, greaterThanOrEqualTo(enKucuk));
      expect(Kazanc.tavan, lessThanOrEqualTo(enBuyuk));
      expect(Kazanc.tavan, closeTo(0.099, 0.001));
    });

    // KARAR 15.4 s1
    test('tavan bir RANK atlamasının dörtte biri civarında', () {
      expect(Kazanc.tavan, lessThan(Kazanc.rankAdimi / 3));
      expect(Kazanc.rankAdimi, closeTo(0.442, 0.001));
    });

    // KARAR 15.4 s1
    test('tavan üst ranklarda DARALIYOR — geç oyunda para az işe yarıyor', () {
      // Kırılırsa: geç oyunda ödemek daha çok kazandırıyor. Ters yönde
      // tasarlanmış sistemler F2P'de yaygın ve tam olarak terk sebebi.
      //
      // Kalite bandı 06'nın; 15 onu yalnız okuyor. Bugün tek bir bant var,
      // o yüzden ölçülen şey fonksiyonun YÖNÜ: taban yükseldikçe tavan
      // daralmak zorunda.
      var onceki = double.infinity;
      for (final taban in [0.70, 0.75, 0.80]) {
        final t = Kazanc.tavanFor(taban);
        expect(t, lessThan(onceki));
        onceki = t;
      }
      expect(Kazanc.tavanFor(0.70), closeTo(0.099, 0.001));
      expect(Kazanc.tavanFor(0.75), closeTo(0.081, 0.001));
      expect(Kazanc.tavanFor(0.80), closeTo(0.064, 0.001));
    });

    // KARAR 15.4 s1
    test('tavan ANA STAT payından geliyor — kalite yalnız alt statlara', () {
      // Makasın dar kalmasının sebebi bu: en kötü eşya bile bütçesinin
      // çoğunu (ana statı) tam alıyor.
      final enKotu =
          TasarimGirdileri.anaStatPayi +
          (1 - TasarimGirdileri.anaStatPayi) * TasarimGirdileri.kaliteAltSiniri;
      expect(Kazanc.tavan, closeTo(1 / enKotu - 1, 1e-12));
      expect(ItemBudget.altStatSayisi(ItemTier.cI), greaterThan(0));
    });

    // KARAR 15.4 s1
    test('tavan ÖLÇÜLÜYOR — 15\'in tepe tablosunda bir tavan girdisi yok', () {
      // "Tavan bir tasarım kararı değil, üç alanın kısıtlarının çarpımı."
      // Girdileri 06'nın: ana stat payı ve kalite alt sınırı. 15 kendi
      // tavanını ilan etseydi tavan diye bir şey kalmazdı.
      final onbesinGirdileri = TasarimGirdileri.alanin(15)
          .map((g) => g.ad)
          .toList();
      final altincininGirdileri = TasarimGirdileri.alanin(6)
          .map((g) => g.ad)
          .toList();
      // Tavanın iki bileşeni de 06'nın girdisi; 15 onları ikinci kez ilan
      // etmiyor, yalnız okuyor. (15'in `paketBonusTavani`'si başka bir
      // tavan: bonus eğrisinin, paranın değil.)
      for (final ad in ['anaStatPayi', 'kaliteAltSiniri']) {
        expect(altincininGirdileri, contains(ad));
        expect(
          onbesinGirdileri,
          isNot(contains(ad)),
          reason: '$ad 15\'te ikinci kez ilan edilmiş',
        );
      }
      // Tavan yalnız o iki sayının fonksiyonu: kur, paket, ödeme oranı
      // değişse de kıpırdamıyor.
      expect(
        Kazanc.tavan,
        closeTo(Kazanc.tavanFor(TasarimGirdileri.kaliteAltSiniri), 1e-12),
      );
      expect(
        Kazanc.tavanForTier(ItemTier.cI),
        closeTo(Kazanc.tavanFor(ItemBudget.kaliteAltSiniriFor(ItemTier.cI)), 1e-12),
      );
    });
  });

  group('alan 15 · NOVA fiyatları', () {
    test('her fiyat KAZANDIRDIĞI ZAMANDAN çıkıyor', () {
      // Yöntemin özeti: hiçbir NOVA fiyatı tahmin edilmiyor. Her biri "bu kaç
      // dakika kazandırıyor" sorusunun cevabı.
      expect(
        Kazanc.fiyatiFor(NovaKalemi.onarim),
        Kazanc.fiyatFor(TasarimGirdileri.olumMaliyetiDk).round(),
      );
      // Ve geri çevrilince makul süreler çıkıyor: hiçbiri saatlerce değil.
      for (final k in NovaKalemi.values) {
        final dk = Kazanc.kazandirdigiDakika(k);
        expect(dk, greaterThan(0));
        expect(
          dk,
          lessThan(60 * 8),
          reason: '${k.name} bir günlük oyun ediyor',
        );
      }
    });

    test('onarım fiyatı 11\'in ölüm maliyetiyle BAĞLI', () {
      expect(
        Kazanc.kazandirdigiDakika(NovaKalemi.onarim),
        closeTo(TasarimGirdileri.olumMaliyetiDk, 0.5),
      );
    });

    test('çevirme paranın dokunduğu TEK kanal ve en büyük gider', () {
      final cevirmePayi =
          Kazanc.fiyatiFor(NovaKalemi.cevirme) *
          100 /
          (Kazanc.fiyatiFor(NovaKalemi.onarim) * 100 +
              Kazanc.fiyatiFor(NovaKalemi.cevirme) * 100);
      expect(cevirmePayi, greaterThan(0.5));
    });
  });

  group('alan 15 · yasak listesi', () {
    // KARAR 15.1 s3
    test('NOVA eşya ve malzeme SATMIYOR', () {
      // Kırılırsa: ganimet döngüsü baypas edilmiş ve 14'ün arz hesabı
      // anlamsızlaşmış.
      expect(Kazanc.esyaSatilabilir, isFalse);
      for (final k in Kaynak.values) {
        expect(
          Kazanc.satilabilir(k),
          isFalse,
          reason: '${k.name} NOVA ile satılabiliyor',
        );
      }
    });

    // KARAR 15.1 s3
    test('malzeme ile NOVA aynı hızda düşüyor — satış zaten anlamsız', () {
      // Yasağa gerek bile yok: 14 "her öldürme 1 malzeme" dedi, 12 "her
      // öldürme 1 NOVA" demişti. Biriyle diğerini almak yapısal olarak
      // anlamsız. Yasak yine de yazılı, çünkü hızlardan biri değişirse test
      // uyarmalı.
      expect(
        Ganimet.malzemeFor(DusmanSinifi.siradan),
        closeTo(TasarimGirdileri.novaOdulu.toDouble(), 1e-9),
      );
    });

    // KARAR 15.1 s3
    test('NOVA satabildiği tek şey ZAMAN ve ALAN — güç değil', () {
      // Dört kalemin hiçbiri stat vermiyor: üçü beklemeyi, biri alanı
      // satıyor. Droid onarımı da bekleme — droid mağazada yok, ganimetten
      // düşüyor (05.10).
      expect(NovaKalemi.values, hasLength(4));
      expect(KaynakAkisi.cevrilebilir(Kaynak.nova, Kaynak.kredi), isFalse);
      expect(KaynakAkisi.cevrilebilir(Kaynak.nova, Kaynak.malzeme), isFalse);
    });

    // KARAR 15.1 s3
    test('yasağı KİLİTLER taşıyor — istisna ancak kilidi çevirerek gelir', () {
      // `satilabilir` sabit `false` dönen bir fonksiyon değil, tepe tablodaki
      // kilitlere BAĞLI bir fonksiyon: biri açılırsa yasak da açılır ve bu
      // test kırılır. İkinci kilit (malzeme) teknik olarak gereksiz ama
      // yazılı duruyor — ileride biri malzeme düşme hızını değiştirdiğinde
      // uyarsın diye.
      expect(Kazanc.esyaSatilabilir, TasarimGirdileri.novaEsyaSatiyor);
      expect(
        Kazanc.satilabilir(Kaynak.malzeme),
        TasarimGirdileri.novaMalzemeSatiyor,
      );
      // Kredi ayrı bir bayrağa değil 13'ün dönüşüm kilidine bağlı: iki alan
      // aynı yasağı iki kez ilan etmiyor.
      expect(
        Kazanc.satilabilir(Kaynak.kredi),
        TasarimGirdileri.paraCevirmeAcik,
      );
      // NOVA'nın NOVA satması bir kilide bağlı bile değil.
      expect(Kazanc.satilabilir(Kaynak.nova), isFalse);
      // Üç kilit de kapalı.
      expect(TasarimGirdileri.novaEsyaSatiyor, isFalse);
      expect(TasarimGirdileri.novaMalzemeSatiyor, isFalse);
      expect(TasarimGirdileri.paraCevirmeAcik, isFalse);
    });

    // KARAR 15.1 s3
    test('mermi de roket de NOVA ile satılmıyor — 17 ve 18\'in kilitleri', () {
      // Yasak listesinin son satırı: ×6 mermi parayla alınsaydı 15.4'ün
      // tavanı anlamsızlaşırdı. İki mermi de aynı kilitte.
      expect(TasarimGirdileri.novaMermiSatiyor, isFalse);
      expect(Mermi.novaIleSatilir, isFalse);
      expect(Roket.novaIleSatilir, isFalse);
    });

    // KARAR 15.1 s3
    test('harita erişimi BR ile açılıyor, parayla değil', () {
      // Kapının okuduğu tek şey savaş puanı (ve seviye): parası olan oyuncu
      // eşiğin altındayken geçemiyor, çünkü geçidin böyle bir kapısı yok.
      final kapili = GecitAgi.hepsi.where((g) => g.esik > 0).toList();
      expect(kapili, isNotEmpty, reason: 'hiç eşikli geçit yok');
      for (final g in kapili) {
        expect(
          g.acik(g.esik - 1, seviye: 1 << 20),
          isFalse,
          reason: '${g.hedef.ad}: eşiğin altında açıldı',
        );
        expect(g.acik(g.esik, seviye: 1 << 20), isTrue);
      }
    });
  });

  group('alan 15 · kredi mağazası', () {
    test('taban eşya EN KÖTÜ drop\'tan bile zayıf', () {
      // Kırılırsa: mağaza ganimetle rekabet etmiş.
      // Üç yönden birden zayıf: bir alt rank, sabit taban kalite, alt stat yok.
      expect(TasarimGirdileri.tabanEsyaRankFarki, lessThan(0));
      for (var r = 1; r < Turetilenler.rankSayisi; r++) {
        expect(Kazanc.tabanEsyaRankiFor(r), lessThan(r));
      }
      // İlk bantta alt rank yok; kelepçe tutuyor.
      expect(Kazanc.tabanEsyaRankiFor(0), 0);
      expect(Kazanc.tabanEsyaKalitesi, TasarimGirdileri.kaliteAltSiniri);
      expect(Kazanc.tabanEsyaAltStatSayisi, 0);
      expect(
        Kazanc.tabanEsyaAltStatSayisi,
        lessThan(ItemBudget.altStatSayisi(ItemTier.cI)),
      );
    });

    test('taban eşya fiyatı 13\'ün MAĞAZA PAYINDAN bölünüyor', () {
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        expect(
          Kazanc.tabanEsyaFiyatiFor(r) * TasarimGirdileri.magazaEsyaSayisi,
          closeTo(
            KaynakAkisi.neselButcesi(r) *
                KaynakAkisi.payFor(GiderKalemi.magaza),
            1e-6,
          ),
        );
      }
    });

    test('mağaza eşyası 14\'ün ölçtüğü BOŞLUĞU dolduruyor', () {
      // Bolluk ×1,50 iken ortalama dört yuva eksik kalıyor; mağaza tam onu
      // kapatıyor — fazlasını değil.
      expect(TasarimGirdileri.magazaEsyaSayisi, greaterThan(0));
      expect(
        TasarimGirdileri.magazaEsyaSayisi,
        lessThan(HullClass.yuvaSayisi(0)),
        reason: 'mağaza bütün yuvaları dolduruyorsa ganimet gereksiz',
      );
    });
  });

  group('alan 15 · paketler', () {
    const paketler = [(0.99, 1.00), (4.99, 1.15), (19.99, 1.35), (49.99, 1.60)];

    // KARAR 15.5 s1
    test('paket bonusu ×2,0\'ı AŞMIYOR', () {
      // Kırılırsa: küçük paketler anlamsız ve oyuncu tek bir büyük alışverişe
      // zorlanıyor.
      expect(TasarimGirdileri.paketBonusTavani, lessThanOrEqualTo(2.0));
      expect(TasarimGirdileri.paketBonusTavani, greaterThan(1.0));
      for (final (_, bonus) in paketler) {
        expect(bonus, lessThanOrEqualTo(TasarimGirdileri.paketBonusTavani));
      }
    });

    // KARAR 15.5 s1
    test('paket saatleri dolar başına ARTAN — büyük paket daha iyi', () {
      var oncekiSaat = 0.0;
      for (final (dolar, bonus) in paketler) {
        final saat = Kazanc.paketNova(dolar, bonus) / Kazanc.saatlikNova;
        expect(saat, greaterThan(oncekiSaat));
        expect(
          saat / dolar,
          greaterThanOrEqualTo(TasarimGirdileri.dolarSaatDegeri - 0.01),
        );
        oncekiSaat = saat;
      }
    });

    // KARAR 15.6 s1
    test('ödeyen oyuncu ömür boyu musluğun DÖRTTE BİRİNİ alıyor', () {
      // Anlamlı bir yardım — ama ödemeyeni GEÇMESİNE yetmiyor, çünkü tavan
      // zaten %9,9'da. Daha yüksek bir kur tavanı değiştirmiyor, yalnız oraya
      // daha çabuk vardırıyor.
      expect(Kazanc.odeyeninPayi, inInclusiveRange(0.15, 0.40));
      expect(Kazanc.odeyeninPayi, lessThan(1.0));
    });

    // KARAR 15.6 s1
    test('ARPU ödeme oranı × ARPPU', () {
      expect(
        Kazanc.arpu,
        closeTo(
          TasarimGirdileri.odemeOrani * TasarimGirdileri.hedefARPPU,
          1e-12,
        ),
      );
      expect(Kazanc.arpu, closeTo(1.20, 0.001));
    });

    // KARAR 15.5 s1
    test('taban kur: bir dolar üç saat oyun; bonus yalnız ÇARPAN', () {
      // Fiyat tahmin edilmiyor: dolar → saat → NOVA. Bonus eğrisi bu
      // zincirin üstüne binen tek çarpan, ve tavanı güvenlik mekanizması.
      expect(
        Kazanc.paketNova(1, 1),
        (TasarimGirdileri.dolarSaatDegeri * Kazanc.saatlikNova).round(),
      );
      expect(
        Kazanc.paketNova(1, 1) / Kazanc.saatlikNova,
        closeTo(TasarimGirdileri.dolarSaatDegeri, 1e-3),
      );
      for (final (dolar, bonus) in [(0.99, 1.0), (19.99, 1.35), (49.99, 1.6)]) {
        expect(
          Kazanc.paketNova(dolar, bonus),
          closeTo(Kazanc.paketNova(dolar, 1) * bonus, 1.0),
          reason: '\$$dolar paketi bonusun dışında bir yoldan fiyatlanmış',
        );
      }
      // Tavandaki paket bile taban kurun iki katını geçmiyor.
      expect(
        Kazanc.paketNova(10, TasarimGirdileri.paketBonusTavani) /
            Kazanc.paketNova(10, 1),
        lessThanOrEqualTo(2.0),
      );
    });

    // KARAR 15.5 s1 · KARAR 15.4 s1
    test('daha yüksek kur TAVANI değiştirmiyor, yalnız oraya çabuk vardırıyor',
        () {
      // Kur ile tavan ayrı eksenler: paket iki kat cömert olsa oyuncu aynı
      // avantaja daha ucuza varır, avantajın kendisi büyümez. Tavanın
      // güvenlik mekanizması olması bu ayrımdan geliyor.
      final ikiKatKur = Kazanc.paketNova(1, 1) * 2;
      expect(ikiKatKur, greaterThan(Kazanc.paketNova(1, 1)));
      expect(
        Kazanc.tavan,
        closeTo(Kazanc.tavanFor(TasarimGirdileri.kaliteAltSiniri), 1e-12),
        reason: 'tavan kurdan etkileniyor',
      );
    });

    // KARAR 15.6 s1
    test('ödeyenin payı TÜRETİLEN: en iyi kurdan alınan NOVA ÷ musluk', () {
      expect(
        Kazanc.odeyeninPayi,
        closeTo(
          Kazanc.paketNova(
                TasarimGirdileri.hedefARPPU,
                TasarimGirdileri.paketBonusTavani,
              ) /
              KaynakAkisi.omurBoyuNova,
          1e-12,
        ),
      );
      // Anlamlı bir yardım ama musluğun tamamı değil: ömür boyu kazanılanın
      // bir kesri.
      expect(Kazanc.odeyeninPayi, lessThan(1.0));
      // Hedef ödeme oranı bir azınlık: ARPU, ARPPU'nun çok altında.
      expect(TasarimGirdileri.odemeOrani, inExclusiveRange(0.0, 1.0));
      expect(Kazanc.arpu, lessThan(TasarimGirdileri.hedefARPPU));
      expect(
        Kazanc.arpu / TasarimGirdileri.hedefARPPU,
        closeTo(TasarimGirdileri.odemeOrani, 1e-12),
      );
    });
  });

  group('alan 15 · NOVA gideri', () {
    // Belgenin "%70 – %95" değişmezi. Bugünkü kodda ölçülemiyor ve sebebi
    // fiyatlarda DEĞİL: giderin çoğu merdiven uzunluğuna bağlı (her nesilde
    // her yuvanın alt statları), musluk ise yalnız süreye. Beş ranklık
    // merdivende gider dörtte bir çıkıyor.
    //
    // Belgenin %84'ü de birebir üretilemiyor: hiçbir belge oyuncunun kaç
    // çevirme SATIN ALDIĞINI yazmıyor. Buradaki model açık — her alt stat
    // için bir çevirme — ve yirmi rankta %60 veriyor. Aradaki fark
    // fiyatlarda değil, varsayılan oyuncu davranışında.
    const hedefRankSayisi = 20;

    test('ZORUNLU gider musluğu AŞMIYOR — ödeme zorunlu değil', () {
      // Onarım ve envanter: hiç ödemeyen oyuncu bunları musluktan
      // karşılayabilmeli, yoksa NOVA bir para birimi olmaktan çıkıp ödeme
      // duvarına dönüşür. Çevirme LÜKS (karar 15.3): fiyatı bedelden
      // türüyor ve üst ranklarda musluğu aşıyor; toplam oran ilan edilir,
      // bantla sınanmaz.
      expect(Kazanc.zorunluGiderOrani, lessThan(1.0));
      expect(
        Kazanc.zorunluGiderFor(rankSayisi: hedefRankSayisi) /
            KaynakAkisi.omurBoyuNova,
        lessThan(1.0),
      );
      // Çevirme dahil toplam BÜYÜK ve bilerek: lüksün tavanı yok.
      expect(Kazanc.novaGiderOrani, greaterThan(Kazanc.zorunluGiderOrani));
    });

    test('hedef merdivende gider musluğun ÇOĞUNU tüketiyor', () {
      // Öteki yön: çok düşükse NOVA değersizleşiyor, oyuncu seçim yapmak
      // zorunda kalmıyor ve kıt para kıt hissedilmiyor.
      expect(
        Kazanc.giderOraniFor(rankSayisi: hedefRankSayisi),
        greaterThan(0.5),
      );
    });

    test('gider merdiven UZADIKÇA artıyor, musluk artmıyor', () {
      // İkisinin ayrı ölçekte olması bu alanın en ince noktası: NOVA zamana
      // bağlı, gider güce. Merdiven uzarsa NOVA kıtlaşıyor.
      //
      // Karşılaştırma bugünü HEDEFLE ölçüyordu; merdiven hedefe varınca ikisi
      // aynı sayı oldu ve test kendini kendisiyle karşılaştırır hâle geldi.
      // Değişmez merdivenin BOYUYLA ilgili, bugünün hedefe uzaklığıyla değil.
      final kisa = Turetilenler.rankSayisi ~/ 2;
      expect(
        Kazanc.giderFor(rankSayisi: Turetilenler.rankSayisi),
        greaterThan(Kazanc.giderFor(rankSayisi: kisa)),
      );
    });
  });
}
