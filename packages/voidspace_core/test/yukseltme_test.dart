@Tags(['aralik', 'turetme'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 07 · GÜÇLENDİRME — merdiven tablosunun değişmezleri.
///
/// Alanın tamamı tek bir söze dayanıyor: **garantili başarı, katlanan
/// maliyet.** Buradaki testlerin yarısı o sözü, yarısı maliyet eğrisinin iki
/// kolunun ayrı kalmasını koruyor.
void main() {
  group('alan 07 · kırılma yasağı', () {
    // KARAR 07.2 s1
    test('başarısızlık şansı SIFIR — her rankta, her seviyede', () {
      // Kırılırsa: kırılma sızmış, koruma satma kapısı açılmış. Bu test
      // silinmeden başarısızlık gelemez, ve silinmesi bilinçli bir karar
      // olmak zorunda.
      expect(TasarimGirdileri.basarisizlikSansi, 0.0);
      for (final tier in ItemTier.values) {
        for (var seviye = 0; seviye <= ItemLevels.max; seviye++) {
          expect(
            Yukseltme.basarisizlikSansi(tier, seviye),
            0.0,
            reason: '${tier.name} +$seviye başarısız olabiliyor',
          );
        }
      }
    });

    // KARAR 07.2 s1
    test('hiçbir işlem eşya YOK ETMİYOR', () {
      expect(Yukseltme.esyaYokEdilebilir, isFalse);
    });

    // KARAR 07.5 s2 · KARAR 07.8 s2
    test('çevirme bedeli: stat başına aile, kilitle doğrusal', () {
      // Karar 07.5: çevirme bütün açık statları çeviriyor, bedel her stat için
      // ve kilit sayısıyla doğrusal. Katlanma yok: bedel çağrıdan çağrıya
      // değişmiyor, sayaç yok.
      for (final tier in ItemTier.values) {
        final n = ItemBudget.altStatSayisi(tier);
        expect(Yukseltme.statBasinaCevirici(tier), tier.aile + 1);
        expect(
          Yukseltme.cevirmeBedeli(tier, n),
          Yukseltme.statBasinaCevirici(tier) * n,
        );
        for (var kilit = 1; kilit < n; kilit++) {
          expect(
            Yukseltme.cevirmeBedeli(tier, n, kilit: kilit),
            Yukseltme.cevirmeBedeli(tier, n) * (1 + kilit),
            reason: '${tier.label} $kilit kilit',
          );
        }
      }
      // Pembe: 6 × 7 = 42; altı kilitle 294.
      expect(Yukseltme.cevirmeBedeli(ItemTier.parlayanPembe, 7), 42);
      expect(Yukseltme.cevirmeBedeli(ItemTier.parlayanPembe, 7, kilit: 6), 294);
    });

    // KARAR 07.8 s2
    test('yuva başına beklenen çevirici RANKLA artıyor', () {
      // Açgözlü kilit modeli: k açık statla isabet 1/(k·p) çevirmede.
      var onceki = 0.0;
      for (final tier in ItemTier.values) {
        final beklenen = Yukseltme.yuvaBasinaCevirici(tier);
        expect(beklenen, greaterThanOrEqualTo(onceki), reason: tier.label);
        onceki = beklenen;
      }
      // Tek statlı C-I: yüz deneme × bir çevirici.
      expect(
        Yukseltme.yuvaBasinaCevirici(ItemTier.cI),
        closeTo(Yukseltme.yuvaBasinaCevirme * 1, 1e-9),
      );
    });
  });

  group('alan 07 · artı merdiveni', () {
    // KARAR 07.3 s1
    test('+15 kazancı ilan edilen TAVANI tutuyor', () {
      // Kırılırsa: kazanç biçimi sessizce değişmiş, güç tavanı kaymış.
      expect(TasarimGirdileri.artiKazancBicimi, ArtiKazancBicimi.toplamsal);
      expect(ItemLevels.multiplier(ItemLevels.max), closeTo(2.50, 1e-9));
    });

    // KARAR 07.3 s1
    test('her seviyede kazanç adımı bir öncekinden KÜÇÜK DEĞİL', () {
      // Kırılırsa: merdiven ters dönmüş — üst seviyeler alttan az veriyor.
      for (var l = 2; l <= ItemLevels.max; l++) {
        expect(
          ItemLevels.stepFor(l),
          greaterThanOrEqualTo(ItemLevels.stepFor(l - 1)),
        );
      }
    });

    // KARAR 07.3 s1
    test('çarpan seviyeyle KESİN ARTAN ve tavanda duruyor', () {
      for (var l = 1; l <= ItemLevels.max; l++) {
        expect(
          ItemLevels.multiplier(l),
          greaterThan(ItemLevels.multiplier(l - 1)),
        );
      }
      expect(
        ItemLevels.multiplier(ItemLevels.max + 5),
        ItemLevels.multiplier(ItemLevels.max),
      );
    });

    test('rank × artı tavanı 06 ile AYNI şeyi söylüyor', () {
      // İki alan farklı tavan söylerse, birinin "toplam güç farkı" hesabı
      // dayanaksız kalır. Tavan = en üst rankın çarpanı × +15 kazancı.
      final tavan =
          TuretilenTablolar.rankCarpaniFor(
            Turetilenler.rankSayisi - 1,
            TasarimGirdileri.rankArtisi,
          ) *
          ItemLevels.multiplier(ItemLevels.max);
      final beklenen =
          ItemTier.values.last.multiplier *
          ItemLevels.multiplier(ItemLevels.max);
      expect(tavan, closeTo(beklenen, beklenen * 0.02));
    });
  });

  group('alan 07 · maliyet eğrisi', () {
    int toplamSink(ItemTier tier) {
      var toplam = 0;
      for (var l = 0; l < ItemLevels.max; l++) {
        toplam += ItemLevels.upgradeCost(l, tier);
      }
      return toplam;
    }

    // KARAR 07.4 s1
    test('değer bozulması 8× – 16× BANDINDA', () {
      // Kırılırsa: son seviyeler ölü içerik (çok yüksek) ya da fazla ucuz
      // (çok düşük — eşya yükseltmek hiç bitmez, enflasyon yakalanamaz).
      expect(ItemLevels.degerBozulmasi, inInclusiveRange(8, 16));
    });

    // KARAR 07.4 s1
    test('toplam sink ilan edilen hacimde — ±%5', () {
      // Kırılırsa: eğri ayarı ekonominin HACMİNİ kaydırmış ve alan 13'ün
      // musluk/gider dengesi sessizce bozulmuş. Şekli değiştirebilirsin, ama
      // hacmi bilerek değiştirmen gerekiyor — testin varlık sebebi bu.
      expect(toplamSink(ItemTier.cI), closeTo(229265, 229265 * 0.05));
    });

    // KARAR 07.4 s1
    test('iki kol AYRI — şekil hacimden bağımsız', () {
      // Hacim c₀ ile doğrusal: tier çarpanı da öyle davranmalı, yoksa iki kol
      // yine birbirine karışmış demektir.
      //
      // Tolerans ORANSAL olmak zorunda: mutlak 0,001 beş rankta (tepe 4,3×)
      // makuldü, yirmi rankta (tepe 1.048×) tam sayıya yuvarlamanın kendisi
      // onu aşıyor. Ölçülen sapma 5×10⁻⁶ — şekil bozulmadı, tolerans eskidi.
      for (final tier in ItemTier.values) {
        expect(
          toplamSink(tier) / toplamSink(ItemTier.cI),
          closeTo(tier.multiplier, tier.multiplier * 1e-4),
        );
      }
    });

    // KARAR 07.4 s1
    test('maliyet seviyeyle KESİN ARTAN, tavanda sıfır', () {
      for (var l = 1; l < ItemLevels.max; l++) {
        expect(
          ItemLevels.upgradeCost(l, ItemTier.cI),
          greaterThan(ItemLevels.upgradeCost(l - 1, ItemTier.cI)),
        );
      }
      expect(ItemLevels.upgradeCost(ItemLevels.max, ItemTier.sI), 0);
    });
  });

  group('alan 07 · sentez', () {
    // KARAR 07.7 s1
    test('sentez verimi 1\'in ALTINDA — bedava yükseltme yolu değil', () {
      // Kırılırsa: sentez drop'un yerine geçer ve ganimetin anlamı kalmaz.
      expect(Yukseltme.sentezVerimi, lessThan(1.0));
      expect(Yukseltme.sentezVerimi, greaterThan(0.0));
      expect(
        Yukseltme.sentezVerimi,
        closeTo(
          TasarimGirdileri.rankArtisi / TasarimGirdileri.sentezOrani,
          1e-9,
        ),
      );
    });

    // KARAR 07.7 s1
    test('kayıp BÜTÇENİN YARISI kadar — ne kestirme ne ölü sistem', () {
      // Oranın asıl sonucu bu. 2→1'de verim %72: sentez tercih edilen
      // yükseltme yolu olur ve drop değersizleşir. 5→1'de %29: kimse
      // kullanmaz, sentez ölü sisteme döner. Aradaki bant, "yarısı gider"
      // cümlesinin sayısal karşılığı.
      expect(Yukseltme.sentezVerimi, inInclusiveRange(0.40, 0.60));
    });

    // KARAR 07.7 s1
    test('sentez ufku en çok ÜÇ kademe — drop\'un yerine geçemiyor', () {
      // Kırılırsa: sentezle merdivenin dibinden tavanına çıkılabiliyor.
      expect(Yukseltme.sentezUfku, lessThanOrEqualTo(3));
      expect(Yukseltme.sentezUfku, greaterThanOrEqualTo(1));
      // Dördüncü kademe pratik ufkun dışında.
      expect(
        Yukseltme.sentezMaliyeti(Yukseltme.sentezUfku + 1),
        greaterThan(Yukseltme.ufukSiniri),
      );
    });

    // KARAR 07.7 s1
    test('merdivenin tamamını sentezlemek İMKÂNSIZ', () {
      // Yirmi kademede 3^19 ≈ 1,16 milyar eşya. Bugün beş kademe ama kural
      // aynı: hiçbir oyuncu bunu biriktiremez.
      expect(
        Yukseltme.sentezMaliyeti(Turetilenler.rankSayisi - 1),
        greaterThan(Yukseltme.ufukSiniri * 2),
      );
    });

    // KARAR 07.7 s1
    test('sentez maliyeti ÜSTEL — kademe başına oran katı', () {
      for (var k = 1; k <= 4; k++) {
        expect(
          Yukseltme.sentezMaliyeti(k) / Yukseltme.sentezMaliyeti(k - 1),
          closeTo(TasarimGirdileri.sentezOrani.toDouble(), 1e-9),
        );
      }
    });
  });

  group('alan 07 · maliyet merdiveni banta bağlı', () {
    // Bu iki test bir çifttir ve ayrı ayrı hiçbir şey ispat etmiyor.
    // İlki formülün ne olduğunu, ikincisi o formülün NEDEN o olduğunu
    // koruyor. Biri silinirse diğeri boşa düşer.

    test('tier çarpanları elle YAZILMIYOR — rank merdiveninin üsleri', () {
      // Kırılırsa: birisi 1,00 · 1,45 · 2,10 · 3,00 · 4,30 gibi "belgeden
      // birebir" sayıları geri koymuş. Bugün fark %1'in altında olduğu için
      // hiçbir oynanış testi bunu yakalamaz — yalnız bu test yakalar.
      for (final tier in ItemTier.values) {
        expect(
          tier.multiplier,
          closeTo(
            TuretilenTablolar.rankCarpaniFor(
              tier.index,
              TasarimGirdileri.rankArtisi,
            ),
            1e-12,
          ),
          reason: '${tier.name} çarpanı merdivenden gelmiyor',
        );
      }
    });

    test('basamak sayısı rank sayısına EŞİT — merdiven uzayınca birlikte', () {
      // Kırılırsa: rank merdiveni uzamış ama eşya basamakları uzamamış.
      // O anda maliyet basamak sayısıyla, gelir rank sayısıyla ölçeklenmeye
      // başlıyor ve ikisi sessizce ayrışıyor. Bu testin ASIL işi bugün
      // geçmek değil, o gün patlamak.
      expect(
        ItemTier.values.length,
        Turetilenler.rankSayisi,
        reason:
            'eşya basamağı ${ItemTier.values.length}, '
            'rank ${Turetilenler.rankSayisi} — maliyet gelirden ayrıştı',
      );
    });

    test('HEDEF merdivende +15 hiçbir nesil bütçesine SIĞMIYOR', () {
      // Alanın ilan ettiği söz: "hiçbir nesilde +15'e ulaşılmıyor." Bugünkü
      // beş ranklı merdiven bunu sınamıyor çünkü rank = kademe olduğu sürece
      // iki model çakışıyor. Yirmi rankta çakışmıyor ve fark burada görünüyor.
      //
      // Kırılırsa: maliyet çapası banttan kopmuş. Kademeye bağlansaydı bu
      // test beşinci banttan sonra oranı 1'in ALTINA düşürürdü — yani +15
      // tek nesilde alınabilir olurdu ve tavan sonrası kuyruk buharlaşırdı.
      const rankSayisi = 20;
      const kademeSayisi = 8;
      final artis = TasarimGirdileri.rankArtisi;
      final us = TasarimGirdileri.gelirUssu;
      final olcek = TuretilenTablolar.sureOlcegiFor(
        rankSayisi: rankSayisi,
        artis: artis,
        us: us,
        hedefSure: TasarimGirdileri.hedefSure,
      );

      // Yuva merdiveni kodun kendi kuralı, sekiz kademeye uzatılmış hâli.
      int yuvaFor(int kademe) {
        final cizilen = HullClass.cizilenler;
        if (kademe < cizilen.length) return cizilen[kademe].totalSlots;
        return cizilen.last.totalSlots +
            (kademe - cizilen.length + 1) * TasarimGirdileri.yuvaArtisi;
      }

      final oranlar = <double>[];
      for (var rank = 0; rank < rankSayisi; rank++) {
        final kademe = rank * kademeSayisi ~/ rankSayisi;
        final sure = TuretilenTablolar.bantSuresiFor(
          rank,
          artis: artis,
          us: us,
          olcek: olcek,
        );
        final gelir = TuretilenTablolar.gelirFor(
          rank,
          taban: TasarimGirdileri.tabanSaatlikGelir,
          artis: artis,
          us: us,
        );
        final yuvaBasina =
            sure *
            gelir *
            KaynakAkisi.payFor(GiderKalemi.artiBasma) /
            yuvaFor(kademe);

        // +15'in maliyeti: çapa BANTLA ölçekleniyor — ItemTier ile aynı kural.
        final capa = TuretilenTablolar.rankCarpaniFor(rank, artis);
        var tamMaliyet = 0.0;
        for (var seviye = 0; seviye < ItemLevels.max; seviye++) {
          tamMaliyet +=
              TasarimGirdileri.maliyetHacmi *
              capa *
              math.pow(TasarimGirdileri.maliyetSekli, seviye);
        }
        oranlar.add(tamMaliyet / yuvaBasina);
      }

      for (var rank = 0; rank < rankSayisi; rank++) {
        expect(
          oranlar[rank],
          greaterThan(1.0),
          reason:
              'bant ${rank + 1}: +15 tek nesil bütçesine sığıyor '
              '(×${oranlar[rank].toStringAsFixed(2)})',
        );
      }
      // Üst uç da açık kalmalı: oran büyürse +15 ölü içeriğe dönüşür.
      expect(oranlar.reduce((a, b) => a > b ? a : b), lessThan(5.0));
    });
  });

  group('alan 07 · çevirme', () {
    // KARAR 07.8 s2
    test('stat başına bedel HARF AİLESİYLE artıyor, aile İÇİNDE sabit', () {
      // Aile ekseni: alt stat sayısı da aynı eksende artıyor, ikinci bir
      // merdiven yazmak aynı kararı iki yerde vermek olurdu.
      for (final tier in ItemTier.values) {
        expect(Yukseltme.statBasinaCevirici(tier), tier.aile + 1);
      }
      expect(
        Yukseltme.statBasinaCevirici(ItemTier.cI),
        Yukseltme.statBasinaCevirici(ItemTier.cIII),
      );
      expect(
        Yukseltme.statBasinaCevirici(ItemTier.sssI),
        greaterThan(Yukseltme.statBasinaCevirici(ItemTier.cI)),
      );
    });

    // KARAR 07.8 s2
    test('mükemmel roll YÜZ deneme — eşya düşüşünden AYRI hedef', () {
      expect(Yukseltme.yuvaBasinaCevirme, 100);
      // İki hedef ayrı: birleştirmek eşya düşüşünü yirmi kat artırırdı.
      expect(
        TasarimGirdileri.cevirmeKaliteHedefi,
        isNot(TasarimGirdileri.kaliteHedefi),
      );
    });

    // KARAR 07.8 s2
    test('çevirici ARZI talebin çok altında — nadirlik burada', () {
      // Tasarımın kendisi: bir nesilde bütün yuvaları mükemmele çıkarmak
      // İMKÂNSIZ olmalı, yoksa mükemmel roll değerini kaybeder. Arz
      // parçalanabilen eşya (parçalama başına bir çevirici), talep açgözlü
      // kilitle mükemmele çıkmanın beklenen bedeli.
      for (final rank in [0, 7, 19]) {
        final tier = ItemTier.values[rank];
        final yuva = HullClass.yuvaSayisi(ReferansBuild.kademeOf(rank));
        final arz =
            (Ganimet.esyaSayisiFor(rank) - yuva) *
            GanimetCekilisi.parcalamaCeviriciKazanci;
        expect(
          arz,
          lessThan(Yukseltme.nesildeGerekenCevirici(rank) * 0.25),
          reason: '${tier.label}: bir nesilde çok fazla çevirme yapılabiliyor',
        );
      }
    });

    test('eksi kademe ATIYOR', () {
      expect(() => Yukseltme.sentezMaliyeti(-1), throwsArgumentError);
    });
  });

  group('alan 07 · tek rastgele', () {
    // KARAR 07.6 s1
    test('artı basmada MİKTAR sabit, hangi alt stat rastgele', () {
      // Kırılırsa: çift rastgelelik geri gelmiş ve hayal kırıklığı
      // çarpılıyor — "hem yanlış stata geldi hem az geldi".
      //
      // Miktarın sabit olduğunu ölçmenin yolu: aynı seviye her zaman aynı
      // adımı veriyor, çağrıdan çağrıya değişmiyor.
      for (var l = 1; l <= ItemLevels.max; l++) {
        expect(ItemLevels.stepFor(l), ItemLevels.stepFor(l));
      }
      expect(ItemLevels.stepFor(3), 0.08);
      expect(ItemLevels.stepFor(8), 0.10);
      expect(ItemLevels.stepFor(13), 0.12);
    });

    // KARAR 07.6 s1
    test('alt stat güçlenmesi her ÜÇ seviyede — beş kez', () {
      final adimlar = [
        for (var l = 1; l <= ItemLevels.max; l++)
          if (ItemLevels.isSubStatStep(l)) l,
      ];
      expect(adimlar, [3, 6, 9, 12, 15]);
    });
  });
}
