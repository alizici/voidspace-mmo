@Tags(['kapsam', 'aralik', 'turetme'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 11 · HARİTALAR — bölge tablosunun değişmezleri.
///
/// Sekiz satırın hepsi belgedeki "Bu tablonun testleri" listesinden geliyor.
/// Bir değişmez kırılırsa yanındaki cümle NE olduğunu söylüyor; "bir sayı
/// değişti" demiyor.
void main() {
  group('alan 11 · bölünme', () {
    test('bölge sayısı = gövde kademesi sayısı', () {
      // KARAR 11.1 s1
      // Kırılırsa: iki alan farklı bir dünya bölünmesi söylüyor.
      expect(Bolge.hepsi, hasLength(TasarimGirdileri.govdeKademeSayisi));
      expect(Turetilenler.bolgeSayisi, TasarimGirdileri.govdeKademeSayisi);
    });

    test('bant sayıları toplamı = rank sayısı', () {
      // KARAR 11.2 s1
      // Kırılırsa: bir rankın haritası yok, ya da iki haritada birden.
      final toplam = Bolge.hepsi.fold(0, (a, b) => a + b.bantSayisi);
      expect(toplam, Turetilenler.rankSayisi);
    });

    test('bantlar boşluksuz ve örtüşmesiz — her rank TAM BİR kez', () {
      // KARAR 11.2 s1
      final gorulen = <int>[];
      for (final b in Bolge.hepsi) {
        for (var i = 0; i < b.bantSayisi; i++) {
          gorulen.add(b.rankOf(i));
        }
      }
      gorulen.sort();
      expect(gorulen, [for (var r = 0; r < Turetilenler.rankSayisi; r++) r]);
    });

    test('bölge adı her kademe için var', () {
      expect(Bolge.adlar.length, greaterThanOrEqualTo(Bolge.hepsi.length));
      expect(
        Bolge.hepsi.map((b) => b.ad).toSet(),
        hasLength(Bolge.hepsi.length),
      );
    });

    test('harita sayısı = bölge × bölge başına harita', () {
      // KARAR 11.1 s1
      expect(
        Turetilenler.haritaSayisi,
        Bolge.hepsi.length * TasarimGirdileri.bolgeBasinaHarita,
      );
      expect(HaritaTipi.values, hasLength(TasarimGirdileri.bolgeBasinaHarita));
    });
    test(
      'üç harita tipi KATEGORİK — dördüncüsü yeni bir tehdit biçimi ister',
      () {
        // KARAR 11.1 s1
        // PvE: saldırı yalnız yaratıklardan · PvP: yaratık ve oyuncu birlikte ·
        // Boss: zamanlı tek hedef. Üçü oyunun kendi tanımından geliyor,
        // `bolgeBasinaHarita` ayarlanabilir bir kadran değil.
        expect(HaritaTipi.values, [
          HaritaTipi.pve,
          HaritaTipi.pvp,
          HaritaTipi.boss,
        ]);
        expect(Harita.hepsi, hasLength(Turetilenler.haritaSayisi));
        expect(Harita.hepsi, hasLength(24));
        // Her bölgede ÜÇÜ de var ve kimlikleri benzersiz.
        for (final b in Bolge.hepsi) {
          final tipler = Harita.hepsi
              .where((h) => h.bolge == b)
              .map((h) => h.tip)
              .toSet();
          expect(tipler, HaritaTipi.values.toSet(), reason: '${b.ad} eksik');
        }
        expect(Harita.hepsi.map((h) => h.id).toSet(), hasLength(24));
      },
    );

    test('bant deseni 2·3·2·3·2·3·2·3 — TABAN BÖLME, yuvarlama değil', () {
      // KARAR 11.2 s1
      // Yuvarlama kipi dile göre değişiyor; taban bölme değişmiyor. Desen
      // bozulursa bir rankın haritası yok ya da iki haritada demektir.
      expect(
        [for (final b in Bolge.hepsi) b.bantSayisi],
        [2, 3, 2, 3, 2, 3, 2, 3],
      );
      for (final b in Bolge.hepsi) {
        expect(b.rankAraligi, (
          b.kademe * Turetilenler.rankSayisi ~/ Turetilenler.bolgeSayisi,
          (b.kademe + 1) * Turetilenler.rankSayisi ~/ Turetilenler.bolgeSayisi,
        ), reason: '${b.ad} aralığı taban bölmeden çıkmıyor');
      }
      // Bölge sınırı yumuşak: bir bölgenin son bandı bir sonrakinin ilk
      // bandının hemen altında, boşluk yok.
      for (var k = 1; k < Bolge.hepsi.length; k++) {
        expect(Bolge.hepsi[k].ilkRank, Bolge.hepsi[k - 1].sonRank + 1);
      }
    });
  });

  group('alan 11 · kapı', () {
    test('BR eşiği = referans BR × giriş payı — İLK bölge hariç', () {
      // KARAR 11.3 s1
      // Kırılırsa: kapı elle ayarlanmış, merdivenle bağı kopmuş.
      for (final b in Bolge.hepsi.skip(1)) {
        expect(
          b.girisEsigi,
          closeTo(
            CombatGlossary.referansBrFor(b.ilkRank) *
                TasarimGirdileri.girisPayi,
            1e-9,
          ),
        );
      }
    });

    test('İLK bölgenin kapısı YOK — doğulan yere girilemezlik olamaz', () {
      // KARAR 11.3 s1
      // Bu istisna tasarlanmadı, BULUNDU. Formül ilk bölgeye 2.700 diyor —
      // referans build'in dörtte üçü. Yeni hesap ise başlangıç lazeriyle
      // 1.050'de: kendi doğduğu bölgeye giremiyordu.
      expect(Bolge.ilk.girisEsigi, 0);
      expect(Bolge.ilk.kabulEder(0), isTrue);
      // Formül olsaydı bu sayı çıkardı — istisnanın büyüklüğü kayıtta dursun.
      expect(
        CombatGlossary.referansBrFor(Bolge.ilk.ilkRank) *
            TasarimGirdileri.girisPayi,
        greaterThan(2000),
      );
    });

    test('İSTİSNA yalnız ilk bölgede — ikincisinden itibaren kapı var', () {
      // KARAR 11.3 s1
      for (final b in Bolge.hepsi.skip(1)) {
        expect(b.girisEsigi, greaterThan(0), reason: '${b.ad} kapısız');
        expect(b.kabulEder(0), isFalse);
      }
    });

    test('eşikler kesin artan — her bölge bir öncekinden pahalı', () {
      for (var k = 1; k < Bolge.hepsi.length; k++) {
        expect(
          Bolge.hepsi[k].girisEsigi,
          greaterThan(Bolge.hepsi[k - 1].girisEsigi),
        );
      }
    });

    test('ilk bölge referans build\'i KABUL EDER', () {
      // %75 payının anlamı bu: taban BR ile ilk bölgeye girilebiliyor.
      expect(Bolge.ilk.kabulEder(CombatGlossary.brTabani), isTrue);
      expect(Bolge.girilebilen(CombatGlossary.brTabani), Bolge.ilk);
    });

    test('kimse dünyasız kalmıyor — sıfır BR bile ilk bölgeye giriyor', () {
      // KARAR 11.3 s1
      expect(Bolge.girilebilen(0), Bolge.ilk);
    });

    // Bir bölgeyi bitirmiş oyuncunun kurabileceği EN GÜÇLÜ build.
    //
    // İç bandın referans BR'si, sistem tavanıyla çarpılmış: rankı bitirmiş ve
    // oran statlarını sonuna kadar yüklemiş oyuncu.
    double tavanBr(Bolge b) =>
        CombatGlossary.referansBrFor(b.sonRank) *
        CombatGlossary.sistemCarpani(TasarimGirdileri.sistemTavani);

    test('her bölgeye BİR ÖNCEKİNDEN ulaşılabiliyor — kapı kilitlemiyor', () {
      // KARAR 11.3 s1
      // Giriş payının asıl işi bu. Kapı, bir önceki bölgenin tavanının
      // üstünde kalırsa oyuncu hiçbir yerde ilerleyemez: girmesi gereken
      // bölgeye girmek için o bölgede oynaması gerekirdi.
      for (var k = 1; k < Bolge.hepsi.length; k++) {
        expect(
          Bolge.hepsi[k].girisEsigi,
          lessThanOrEqualTo(tavanBr(Bolge.hepsi[k - 1])),
          reason: '${Bolge.hepsi[k].ad} bir öncekinin tavanından ulaşılamıyor',
        );
      }
    });

    test('bölge ATLANAMAZ — iki üstteki kapı hep uzakta', () {
      // KARAR 11.3 s1
      // Payın öteki yarısı. Çok gevşek bir kapı, oyuncunun iki bölge birden
      // atlamasına ve arada kalan bölgenin hiç oynanmamasına izin verirdi.
      for (var k = 2; k < Bolge.hepsi.length; k++) {
        expect(
          Bolge.hepsi[k].girisEsigi,
          greaterThan(tavanBr(Bolge.hepsi[k - 2])),
          reason: '${Bolge.hepsi[k].ad} iki alttan doğrudan açılıyor',
        );
      }
    });

    test('girilebilen bölge EN DERİN olanı', () {
      final son = Bolge.hepsi.last;
      expect(Bolge.girilebilen(son.girisEsigi), son);
      // Eşiğin bir tık altı bir öncekine düşürüyor.
      expect(
        Bolge.girilebilen(son.girisEsigi - 1),
        Bolge.hepsi[Bolge.hepsi.length - 2],
      );
    });
  });

  group('alan 11 · boyut', () {
    test('harita alanı = bant × türetilen bant alanı', () {
      // KARAR 11.5 s1
      // Kırılırsa: boyut elle yazılmış, yoğunluk hedefi tutmaz.
      for (final b in Bolge.hepsi) {
        final h = b.harita;
        expect(
          h.width * h.height,
          closeTo(
            Turetilenler.bantAlani * b.bantSayisi,
            1e-6 * Turetilenler.bantAlani,
          ),
        );
      }
    });

    test('en/boy oranı her haritada aynı', () {
      // KARAR 11.5 s1
      for (final b in Bolge.hepsi) {
        final h = b.harita;
        expect(
          h.width / h.height,
          closeTo(TasarimGirdileri.dunyaEnBoyOrani, 1e-9),
        );
      }
    });

    test('boyut YALNIZ bant sayısına bağlı — kademe boyutu değiştirmez', () {
      // Sekizinci bölge birincisinden büyük değil; içindekiler güçlü.
      final gruplar = <int, Set<String>>{};
      for (final b in Bolge.hepsi) {
        final h = b.harita;
        gruplar
            .putIfAbsent(b.bantSayisi, () => <String>{})
            .add('${h.width.round()}×${h.height.round()}');
      }
      for (final entry in gruplar.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason: '${entry.key} bantlı bölgeler ayrışmış',
        );
      }
    });

    test('yoğunluk: hedef sayısı görüş çemberi başına gorusHedefi veriyor', () {
      // KARAR 11.5 s1
      // Kırılırsa: oyuncu ya hedef arıyor ya mayın tarlasında.
      for (final b in Bolge.hepsi) {
        final h = b.harita;
        final cember = math.pi * math.pow(TasarimGirdileri.gorusYaricapi, 2);
        final cemberBasina = b.hedefSayisi / (h.width * h.height / cember);
        expect(
          cemberBasina,
          closeTo(TasarimGirdileri.gorusHedefi.toDouble(), 0.001),
        );
      }
    });

    test('GameWorld.standard = ilk bölgenin haritası', () {
      // KARAR 11.5 s1
      // Dart varsayılan parametre değerini `const` istiyor ve `sqrt` `const`
      // değil; iki sabit türetmenin ÖNBELLEĞİ. Ayrışmayı bu test tutuyor.
      final h = Bolge.ilk.harita;
      expect(GameWorld.standard.width, closeTo(h.width, 1));
      expect(GameWorld.standard.height, closeTo(h.height, 1));
    });

    test('görüş yarıçapı TEK yerde tanımlı — ağ ile harita ayrışamaz', () {
      // KARAR 11.5 s1
      expect(Protocol.interestRadius, TasarimGirdileri.gorusYaricapi);
    });
    test('bant alanı ÜÇ ölçülebilir girdiden — "ne kadar büyük olsun" yok', () {
      // KARAR 11.5 s1
      // Görüş yarıçapı fiziksel, eş zamanlı oyuncu ve görüş paylaşımı
      // cevaplanabilir sorular. Boyut bunların sonucu.
      expect(
        Turetilenler.bantAlani,
        closeTo(
          TasarimGirdileri.esZamanliOyuncu *
              math.pi *
              math.pow(TasarimGirdileri.gorusYaricapi, 2) *
              TasarimGirdileri.gorusPaylasimi,
          1e-6,
        ),
      );
      // Yoğunluk aynı çemberden ve çember sadeleşiyor.
      expect(
        Turetilenler.bantBasinaHedef,
        (TasarimGirdileri.esZamanliOyuncu *
                TasarimGirdileri.gorusPaylasimi *
                TasarimGirdileri.gorusHedefi)
            .round(),
      );
      // Elle konmuş 12.000 × 8.000 her iki kenarda %6 sapıyordu.
      final tek = TuretilenTablolar.haritaBoyutuFor(
        1,
        bantAlani: Turetilenler.bantAlani,
        enBoy: TasarimGirdileri.dunyaEnBoyOrani,
      );
      expect(GameWorld.tekBantGenislik, closeTo(tek.$1, 1));
      expect(GameWorld.tekBantYukseklik, closeTo(tek.$2, 1));
      expect((12000 - tek.$1).abs() / tek.$1, greaterThan(0.05));
    });
  });

  group('alan 11 · gelir', () {
    test('her bant bir öncekinden yüksek gelir veriyor', () {
      // KARAR 11.2 s1
      // Kırılırsa: derine inmenin karşılığı yok.
      var oncekiCarpan = 0.0;
      for (final b in Bolge.hepsi) {
        for (var i = 0; i < b.bantSayisi; i++) {
          final c = b.gelirCarpaniFor(i);
          expect(c, greaterThan(oncekiCarpan));
          oncekiCarpan = c;
        }
      }
    });

    test('yorgunluk eşiği / gelir oranı her bantta AYNI', () {
      // Kırılırsa: eşik ölçeklenmemiş, üst bölgeler tabana çakılı.
      // Bu satır alan 10 öncesinde KIRIKTI: eşik sabit 200.000'di ve son
      // bantta gelirin 210'da biri kalıyordu.
      final oranlar = <double>[];
      for (final b in Bolge.hepsi) {
        for (var i = 0; i < b.bantSayisi; i++) {
          oranlar.add(Fatigue.softCapFor(b.rankOf(i)) / b.gelirCarpaniFor(i));
        }
      }
      // Tolerans `softCapFor`'un `int` dönmesinden: eşik krediye yuvarlanıyor
      // ve tam oran ancak yuvarlama payı kadar tutturulabiliyor.
      for (final o in oranlar) {
        expect(o, closeTo(oranlar.first, oranlar.first * 1e-5));
      }
    });

    test('PvP net primi %30 — ölümler düşüldükten sonra', () {
      // KARAR 11.6 s1
      // Kırılırsa: PvP ya zorunlu ya anlamsız.
      final brut = Turetilenler.pvpBrutPrim;
      final kayip = Turetilenler.pvpKayipOrani;
      expect(kayip, closeTo(0.25, 1e-9));
      expect(brut, closeTo(1.7333333, 1e-6));
      // Net prim geri çözülüyor: brüt × (1 − kayıp) − 1.
      expect(
        brut * (1 - kayip) - 1,
        closeTo(TasarimGirdileri.pvpNetPrim, 1e-9),
      );
    });

    test('PvP haritası PvE\'den yüksek, ama katı değil', () {
      // KARAR 11.6 s1
      for (final b in Bolge.hepsi) {
        for (var i = 0; i < b.bantSayisi; i++) {
          final oran = b.pvpGelirCarpaniFor(i) / b.gelirCarpaniFor(i);
          expect(oran, greaterThan(1.0));
          expect(
            oran,
            lessThan(2.0),
            reason: 'prim ×2\'yi aşarsa PvP zorunlu olur',
          );
        }
      }
    });

    test('ölüm sıklığı saatin tamamını yerse prim ÇÖZÜLEMEZ — atıyor', () {
      // KARAR 11.6 s1
      // Formül değil tasarım yanlış: PvP haritası fazla ölümcül.
      expect(
        () => TuretilenTablolar.pvpBrutPrimFor(netPrim: 0.30, kayipOrani: 1.0),
        throwsArgumentError,
      );
    });
    test('PvP primi HESAPLANABİLİR — kayıp oranı sıklık × maliyet ÷ 60', () {
      // KARAR 11.6 s1
      // Elle ayarlanacak bir şey yok: ölüm sıklığı playtest'ten geldiğinde
      // prim kendiliğinden yeniden hesaplanıyor.
      expect(
        Turetilenler.pvpKayipOrani,
        closeTo(
          TasarimGirdileri.pvpOlumSikligi *
              TasarimGirdileri.olumMaliyetiDk /
              60,
          1e-12,
        ),
      );
      expect(
        Turetilenler.pvpBrutPrim,
        closeTo(
          (1 + TasarimGirdileri.pvpNetPrim) / (1 - Turetilenler.pvpKayipOrani),
          1e-12,
        ),
      );
      // Sıklık ARTINCA prim kendiliğinden yükseliyor.
      expect(
        TuretilenTablolar.pvpBrutPrimFor(
          netPrim: TasarimGirdileri.pvpNetPrim,
          kayipOrani: TuretilenTablolar.pvpKayipOraniFor(
            siklik: 4,
            maliyetDk: TasarimGirdileri.olumMaliyetiDk,
          ),
        ),
        greaterThan(Turetilenler.pvpBrutPrim),
      );
      // Ve saatte SEKİZ ölümde brüt prim dörde yaklaşıyor: o noktada yanlış
      // olan formül değil, PvP haritasının ölümcüllüğü.
      expect(
        TuretilenTablolar.pvpBrutPrimFor(
          netPrim: TasarimGirdileri.pvpNetPrim,
          kayipOrani: TuretilenTablolar.pvpKayipOraniFor(
            siklik: 8,
            maliyetDk: TasarimGirdileri.olumMaliyetiDk,
          ),
        ),
        closeTo(3.9, 0.05),
      );
    });
  });

  group('alan 11 · süre', () {
    test('bölge süreleri toplamı = hedef süre', () {
      // Kırılırsa: bölünme zaman kaybetmiş, alan 10 ile ayrışma var.
      final toplam = Bolge.hepsi.fold(0.0, (a, b) => a + b.sure);
      expect(
        toplam,
        closeTo(TasarimGirdileri.hedefSure, TasarimGirdileri.hedefSure * 0.02),
      );
    });

    test('her nesil bir öncekinden UZUN — α < 1\'in tek sonucu', () {
      for (var r = 1; r < Turetilenler.rankSayisi; r++) {
        expect(
          Turetilenler.bantSuresi(r),
          greaterThan(Turetilenler.bantSuresi(r - 1)),
        );
      }
    });
  });

  group('alan 10 · düzeltme', () {
    test('BR tavanı ULAŞILABİLİR — merdiven boşta basamak bırakmıyor', () {
      // KARAR 10.3 s1
      // Her iki kanal da merdivenle ölçeklenen bir build kurup ölçüyoruz:
      // tavan bu build'in savaş puanına eşit olmak zorunda.
      final m = TuretilenTablolar.rankCarpaniFor(
        Turetilenler.rankSayisi - 1,
        TasarimGirdileri.rankArtisi,
      );
      // Uç build DOLU referansın ölçeklenmişi (04.5 s2): BR tabanı dolu
      // referansın puanı, tavan da onun merdivenin sonundaki hâli.
      final taban = ReferansCozumu.stats;
      final ucBuild = taban.copyWith(
        maxHull: taban.maxHull * m,
        maxShield: taban.maxShield * m,
        // Roket de merdivenle büyüyor (18): salvo tabanı rankla ölçekli.
        roketHasari: taban.roketHasari * m,
        laser: LaserStats(
          id: taban.laser.id,
          name: taban.laser.name,
          damage: taban.laser.damage * m,
          fireInterval: taban.laser.fireInterval,
          range: taban.laser.range,
        ),
      );
      final ulasilan = CombatGlossary.battleRating(
        ucBuild.copyWith(
          speedBonus:
              TasarimGirdileri.sistemTavani /
              (TasarimGirdileri.sistemKatsayisiHiz * 100),
        ),
      );
      expect(
        CombatGlossary.brTavani,
        closeTo(ulasilan, ulasilan * 0.001),
        reason: 'tavan ulaşılamıyorsa üst unvanlar hiçbir build ile alınmaz',
      );
    });

    test('son unvanın eşiği TAM tavanda', () {
      // KARAR 10.3 s1
      expect(
        CombatGlossary.unvanEsigi(TasarimGirdileri.unvanSayisi - 1),
        closeTo(CombatGlossary.brTavani, CombatGlossary.brTavani * 1e-9),
      );
      expect(
        CombatGlossary.unvanIndeksi(CombatGlossary.brTavani),
        TasarimGirdileri.unvanSayisi - 1,
      );
    });

    test('her basamağın eşiği KENDİ indeksini veriyor', () {
      // KARAR 10.3 s1
      // Eşiği tam tutturan oyuncu unvanını almalı. `log`/`pow` gidiş-dönüşü
      // 49,999999996 üretebiliyor ve yalın `floor` onu bir aşağı atardı.
      for (var i = 0; i < TasarimGirdileri.unvanSayisi; i++) {
        expect(CombatGlossary.unvanIndeksi(CombatGlossary.unvanEsigi(i)), i);
      }
    });
  });
}
