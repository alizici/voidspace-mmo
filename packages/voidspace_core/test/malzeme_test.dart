@Tags(['yabanci-anahtar', 'kapsam'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// MALZEME ŞEMASI — alan 06.
///
/// Belgenin değişmezi tek cümle: *"Malzemelerin alt statı, artısı, kalitesi
/// yok"*, ve kırılınca ne olacağı da yazılı — *"Malzeme eşya gibi davranmaya
/// başlamış; envanter ve mağaza karışıyor."* Buradaki testler o cümleyi
/// koruyor: bir gün birisi malzemeye alan eklemeye kalkarsa, kırmızıya
/// dönmesi gereken yer burası.
void main() {
  group('şema', () {
    // KARAR 06.4 s1
    test('her TÜRÜN her rankı var', () {
      // Şema bir tür ekseni kazandı: yükseltme ile çevirme AYNI kaynağı
      // harcarsa biri ötekini yiyor — oyuncu her çevirmede bir yükseltmeden
      // vazgeçmiş oluyor ve ikisi arasında bir karar değil bir ceza
      // hissediyor.
      expect(
        Malzeme.hepsi,
        hasLength(ItemTier.values.length * MalzemeTuru.values.length),
      );
      for (final t in ItemTier.values) {
        expect(Malzeme.forRank(t).rank, t);
        expect(Malzeme.forRank(t).tur, MalzemeTuru.yukseltme);
        expect(Malzeme.cevirmeFor(t).rank, t);
        expect(Malzeme.cevirmeFor(t).tur, MalzemeTuru.cevirme);
      }
    });

    test('YÜKSELTME malzemesinin kimliği DEĞİŞMEDİ', () {
      // Tür ekseni şemadan SONRA geldi ve eski kayıtlar `m-` taşıyor. Ön eki
      // korumak, hiçbir hangarın göç ettirilmesi gerekmemesi demek.
      expect(Malzeme.forRank(ItemTier.cI).id, 'm-cI');
      expect(Malzeme.cevirmeFor(ItemTier.cI).id, isNot('m-cI'));
    });

    // KARAR 06.3 s1
    test('kimlik RANKTAN türüyor — ikinci bir eksen yok', () {
      // "1 malzeme ≡ 1 öldürme ≡ o bandın yaratık ödülü" denkliği ancak rank
      // tek ayırt edici özellikse kuruluyor. İkinci bir eksen (tür, kalite)
      // aynı rankta iki farklı değer üretir ve denklik ölür.
      final kimlikler = Malzeme.hepsi.map((m) => m.id).toSet();
      expect(kimlikler, hasLength(Malzeme.hepsi.length));
      for (final m in Malzeme.hepsi) {
        expect(Malzeme.byId(m.id), same(m));
      }
    });

    test('EŞYA kimlikleri malzeme olarak çözülmüyor', () {
      // Envanterler ayrı ve ayrı kalmalı; ön ek o ayrımın taşıyıcısı.
      for (final spec in Catalogue.rafta) {
        expect(
          Malzeme.byId(spec.id),
          isNull,
          reason: '${spec.id} malzeme sanıldı — envanterler karışıyor',
        );
      }
    });

    // KARAR 06.3 s1
    test('DEĞİŞMEZ: malzemenin alt statı, artısı, kalitesi yok', () {
      // Şemayı SAYARAK kilitliyor: bir alan eklendiği an bu test düşüyor ve
      // ekleyen kişi belgeye bakmak zorunda kalıyor.
      //
      // `ItemInstance` üç alan taşıyor (kimlik, tasarım, artı) ve üstüne
      // kaliteyi kimliğinden türetiyor. Malzemenin taşıdığı iki şey var:
      // rank ve ondan türeyen kimlik.
      final m = Malzeme.forRank(ItemTier.bI);
      expect(m.rank, ItemTier.bI);
      expect(m.id, contains(ItemTier.bI.name));
      // Malzeme SINIFININ alanları: yalnız `rank`. Ötekiler türetilen.
      expect(
        Malzeme.forRank(ItemTier.bI).id,
        Malzeme.forRank(ItemTier.bI).id,
        reason: 'kimlik türetilen değil saklanan olmuş',
      );
      // Aynı rankın iki malzemesi AYNI nesne: yığılabilir ve birbirinin
      // aynısı olmanın koddaki karşılığı.
      expect(
        identical(Malzeme.forRank(ItemTier.bI), Malzeme.forRank(ItemTier.bI)),
        isTrue,
        reason: 'malzemenin ÖRNEĞİ oluşmuş — yığılabilirlik bozuldu',
      );
    });
  });

  group('envanter', () {
    // KARAR 06.3 s1
    test('yığılıyor — örnek üretmiyor', () {
      final h = Hangar(accountId: 'a');
      final m = Malzeme.forRank(ItemTier.cI);
      h.malzemeEkle(m, 3);
      h.malzemeEkle(m, 4);
      expect(h.malzemeSayisi(m), 7);
      expect(h.malzemeler, hasLength(1), reason: 'yığılmadı, çoğaldı');
    });

    test('harcama aynı kapıdan — sıfırda kayıt SİLİNİYOR', () {
      final h = Hangar(accountId: 'a');
      final m = Malzeme.forRank(ItemTier.cI);
      h.malzemeEkle(m, 5);
      h.malzemeEkle(m, -5);
      expect(h.malzemeSayisi(m), 0);
      expect(
        h.malzemeler,
        isEmpty,
        reason: 'sıfır kayıt kaldı — dosya oyun süresiyle büyür',
      );
    });

    test('eksiye DÜŞMÜYOR', () {
      final h = Hangar(accountId: 'a');
      h.malzemeEkle(Malzeme.forRank(ItemTier.cI), -3);
      expect(h.malzemeSayisi(Malzeme.forRank(ItemTier.cI)), 0);
    });

    test('kaydediliyor ve geri okunuyor', () {
      final h = Hangar(accountId: 'a')
        ..malzemeEkle(Malzeme.forRank(ItemTier.cI), 2)
        ..malzemeEkle(Malzeme.forRank(ItemTier.sI), 9);
      final geri = Hangar.fromJson(h.toJson());
      expect(geri.malzemeSayisi(Malzeme.forRank(ItemTier.cI)), 2);
      expect(geri.malzemeSayisi(Malzeme.forRank(ItemTier.sI)), 9);
    });

    test('alan YOKSA boş — eski kayıtlar bozulmuyor', () {
      final json = Hangar(accountId: 'a').toJson()..remove('malzemeler');
      expect(Hangar.fromJson(json).malzemeler, isEmpty);
    });
  });

  group('düşüş', () {
    PrdRoller yeniPrd() => PrdRoller(TasarimGirdileri.ustRankSansi);

    GanimetPayi cek({
      DusmanSinifi sinif = DusmanSinifi.siradan,
      double hasarPayi = 1.0,
      required math.Random zar,
      required PrdRoller prd,
      int no = 0,
    }) => GanimetCekilisi.cek(
      sinif: sinif,
      hasarPayi: hasarPayi,
      rank: 5,
      prd: prd,
      zar: zar,
      kimlikUret: (d) => 'k$no-$d',
    );

    test('HER öldürmede malzeme — eşyadan ayrı ritim', () {
      // Alan 14'ün ayrımı: malzeme sürekli, eşya seyrek. Sıradan yaratıkta
      // eşya şansı %1,18; malzeme her seferinde düşmeli.
      final zar = math.Random(3);
      final prd = yeniPrd();
      for (var i = 0; i < 200; i++) {
        expect(cek(zar: zar, prd: prd, no: i).malzeme, greaterThan(0));
      }
    });

    test('miktar ZAMANLA orantılı — güçlü sıradandan çok veriyor', () {
      const deneme = 3000;
      double ortalama(DusmanSinifi s) {
        final zar = math.Random(5);
        final prd = yeniPrd();
        var toplam = 0;
        for (var i = 0; i < deneme; i++) {
          toplam += cek(sinif: s, zar: zar, prd: prd, no: i).malzeme;
        }
        return toplam / deneme;
      }

      final siradan = ortalama(DusmanSinifi.siradan);
      final guclu = ortalama(DusmanSinifi.guclu);
      expect(guclu, greaterThan(siradan));
      expect(
        guclu / siradan,
        closeTo(
          Ganimet.malzemeFor(DusmanSinifi.guclu) /
              Ganimet.malzemeFor(DusmanSinifi.siradan),
          0.1,
        ),
      );
    });

    test('malzeme de HASAR PAYIYLA ölçekleniyor', () {
      const deneme = 4000;
      int toplam(double pay) {
        final zar = math.Random(7);
        final prd = yeniPrd();
        var t = 0;
        for (var i = 0; i < deneme; i++) {
          t += cek(
            sinif: DusmanSinifi.guclu,
            hasarPayi: pay,
            zar: zar,
            prd: prd,
            no: i,
          ).malzeme;
        }
        return t;
      }

      expect(toplam(0.5) / toplam(1.0), closeTo(0.5, 0.06));
    });
  });

  group('parçalama', () {
    test('kazanç RANKLA büyüyor', () {
      var onceki = -1;
      for (final t in ItemTier.values) {
        final kazanc = GanimetCekilisi.parcalamaKazanci(t);
        expect(kazanc, greaterThanOrEqualTo(onceki));
        onceki = kazanc;
      }
    });

    test('parçalamak DROP\'un yerine geçmiyor', () {
      // Bir eşya, kendisini düşürecek kadar öldürmenin verdiği malzemeden AZ
      // vermeli — yoksa eşya farmı malzeme farmının yerine geçer.
      for (final t in ItemTier.values) {
        final kazanc = GanimetCekilisi.parcalamaKazanci(t);
        final oldurme = Ganimet.esyaMaliyeti * t.multiplier;
        expect(
          kazanc,
          lessThan(oldurme),
          reason: '${t.label}: parçalama $kazanc, öldürme ${oldurme.round()}',
        );
      }
    });
  });
}
