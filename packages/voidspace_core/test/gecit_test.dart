@Tags(['kapsam'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 11 · GEÇİT AĞI — yirmi dört haritanın bağlantı grafiği.
///
/// Ağın tamamı üç kuraldan çıkıyor (omurga · yaprak · ayna) ve bu testlerin
/// işi o üç kuralın kenar listesine elle bir şey sızmadan uygulandığını
/// korumak. Grafik bozulduğunda oyuncu bir haritada KAPANIR — ve o hata
/// oynanışta ancak oraya varan biri tarafından bulunur.
void main() {
  group('alan 11 · ağın bütünlüğü', () {
    test('harita ve geçit sayısı BÖLGE sayısından — elle yazılmıyor', () {
      expect(
        Harita.hepsi.length,
        Bolge.hepsi.length * HaritaTipi.values.length,
      );
      // Omurga: her komşu çift için gidiş + geri. Yapraklar: her bölgede iki
      // harita × gidiş-dönüş. İkisi de bölge sayısından çıkıyor.
      final omurga = (Bolge.hepsi.length - 1) * 2;
      final yaprak = Bolge.hepsi.length * 2 * 2;
      expect(GecitAgi.hepsi.length, omurga + yaprak);
    });

    test('HEDEF 24 harita — merdiven açıldı, ağ kendiliğinden büyüdü', () {
      // Bu test bir zamanlar karakterizasyondu: "BUGÜN 15 harita — hedef 24"
      // diyor ve açığı kayda geçiriyordu. Gövde kademesi sekize çıktığında
      // patlayacağı yazılıydı; çıktı ve patladı. Tek bir tepe tablo girdisi
      // 15 haritayı 24'e, 28 geçidi 46'ya taşıdı — hiçbir harita, hiçbir
      // geçit elle yazılmadan.
      expect(Bolge.hepsi.length, DengeDenetimi.hedefKademeSayisi);
      expect(
        Harita.hepsi.length,
        DengeDenetimi.hedefKademeSayisi * TasarimGirdileri.bolgeBasinaHarita,
      );
      expect(Harita.hepsi.length, 24);
    });

    test('hiçbir harita ÇIKMAZ değil — her geçidin dönüşü var', () {
      // Kırılırsa: bir oyuncu girdiği haritadan çıkamıyor. Oynanışta yalnız
      // oraya varan biri bulur; burada her seferinde bulunuyor.
      for (final gecit in GecitAgi.hepsi) {
        expect(
          () => GecitAgi.donusFor(gecit),
          returnsNormally,
          reason: '$gecit dönüşsüz',
        );
      }
    });

    test('her harita ilk bölgeden YÜRÜNEREK erişilebilir', () {
      // Kırılırsa: ağ ikiye ayrılmış ve bir grup harita hiç ulaşılamaz. Sayı
      // testi bunu yakalamaz — kenar sayısı doğru ama grafik kopuk olabilir.
      final baslangic = Harita(Bolge.ilk, HaritaTipi.pve);
      final gorulen = <Harita>{baslangic};
      final sira = <Harita>[baslangic];
      while (sira.isNotEmpty) {
        for (final g in GecitAgi.gecitleriFor(sira.removeLast())) {
          if (gorulen.add(g.hedef)) sira.add(g.hedef);
        }
      }
      expect(gorulen.length, Harita.hepsi.length);
    });

    test('omurga bölge ATLAMIYOR — merdiven sırayla yürünüyor', () {
      // Kırılırsa: bir kısayol açılmış ve BR kapısı baypas edilebilir hâle
      // gelmiş. Kapı bölgeye değil, kapıya giden yola bağlı.
      for (final g in GecitAgi.hepsi) {
        final fark = (g.hedef.bolge.kademe - g.kaynak.bolge.kademe).abs();
        expect(fark, lessThanOrEqualTo(1), reason: '$g bölge atlıyor');
      }
    });

    test('PvP ve boss OMURGADA değil — ikisi de yaprak', () {
      // Kırılırsa: ilerlemek için PvP'den ya da boss'tan geçmek zorunlu
      // olmuş. 11'in kuralı: kaçınan YAVAŞLAMALI, durmamalı.
      for (final g in GecitAgi.hepsi) {
        if (g.kaynak.bolge != g.hedef.bolge) {
          expect(g.kaynak.tip, HaritaTipi.pve, reason: '$g omurgada değil');
          expect(g.hedef.tip, HaritaTipi.pve, reason: '$g omurgada değil');
        }
      }
    });

    test('ilk bölgenin geri, son bölgenin ileri kapısı YOK', () {
      final ilk = GecitAgi.gecitleriFor(Harita(Bolge.ilk, HaritaTipi.pve));
      expect(ilk.where((g) => g.yon == GecitYonu.bati), isEmpty);
      final son = GecitAgi.gecitleriFor(
        Harita(Bolge.hepsi.last, HaritaTipi.pve),
      );
      expect(son.where((g) => g.yon == GecitYonu.dogu), isEmpty);
    });
  });

  group('alan 11 · ayna kuralı', () {
    test('çıkış girişin KARŞI kenarı — ve o kenar dönüş kapısının kendisi', () {
      // Bu iki iddia tek testte, çünkü ayrı ayrı yarısı doğru bir ağ üretiyor:
      // karşı kenarda çıkıp başka bir geçidin üstüne düşmek.
      for (final gecit in GecitAgi.hepsi) {
        final donus = GecitAgi.donusFor(gecit);
        expect(gecit.cikisYonu, gecit.yon.karsi);
        expect(
          donus.yon,
          gecit.cikisYonu,
          reason: '$gecit yanlış kenara çıkıyor',
        );
        expect(gecit.cikisKonumu, donus.konum);
      }
    });

    test('dört yönün karşısı KENDİNE dönüyor — çift yönlü eşleşme', () {
      for (final yon in GecitYonu.values) {
        expect(yon.karsi.karsi, yon);
      }
    });
  });

  group('alan 11 · konum', () {
    test('her geçit haritanın İÇİNDE — kenara sıkışan geçit yok', () {
      // Kırılırsa: geçit kenar payının dışına düşmüş ve gemi merkezine
      // ulaşamıyor — görünen ama girilemeyen bir kapı.
      for (final gecit in GecitAgi.hepsi) {
        final dunya = gecit.kaynak.dunya;
        expect(
          dunya.clamp(gecit.konum),
          gecit.konum,
          reason: '$gecit haritanın dışında',
        );
      }
    });

    test('yarıçap DÜNYANIN kenar payından — sabite çevrilirse yakalanıyor', () {
      // Tek bir dünyada sınamak yetmiyordu: bugünkü değere (140) sabitlenmiş
      // bir sürüm o testten geçerdi. Kenar payını oynatmak sabiti ilk adımda
      // düşürüyor.
      for (final pay in [60.0, 140.0, 400.0]) {
        expect(
          GecitAgi.yaricapFor(GameWorld(margin: pay)),
          pay,
          reason: 'yarıçap $pay kenar payında oynamıyor',
        );
      }
      expect(GecitAgi.yaricap, GecitAgi.yaricapFor(GameWorld.standard));
    });

    test('kapının ağzı duvarın İÇ YÜZÜNE değiyor — merkez iki kenar payı', () {
      // Sonuç testi: yarıçabın nereden geldiğini değil, ne anlama geldiğini
      // ölçüyor. Kenar payı geminin giremediği bant; geçit tam o kalınlıkta
      // ve merkezi kenardan iki pay içeride, yani dış ağzı duvara değiyor.
      for (final dunya in [GameWorld.standard, const GameWorld(margin: 300)]) {
        expect(GecitAgi.kenarPayiFor(dunya), dunya.margin * 2);
        // Kapının dış ağzı: merkez − yarıçap = tam olarak duvarın iç yüzü.
        expect(
          GecitAgi.kenarPayiFor(dunya) - GecitAgi.yaricapFor(dunya),
          dunya.margin,
        );
      }
    });

    test('geçit çapı referans hızda BİR SANİYEYE yakın sürüyor', () {
      // His testi: kazara girilmeyecek kadar dar, nişan almak gerekmeyecek
      // kadar geniş. Yarıçabın kaynağı değişse de bu aralık korunmalı —
      // ölçüsü artık kenar payından geliyor ama his aynı yerde.
      final sure = GecitAgi.yaricap * 2 / ShipStats.bastion.speed;
      expect(sure, greaterThan(0.5));
      expect(sure, lessThan(1.5));
    });

    test(
      'geçit ekranın küçük bir parçası — gidilen yer değil, girilen kapı',
      () {
        // Sonuç testi: ölçeği haritaya değil GÖRÜŞE bağlıyor, çünkü oyuncunun
        // gördüğü şey ekran. Geçit görüş çemberini doldurursa bir kapı olmaktan
        // çıkıp bir yere dönüşür; çok küçülürse aranan bir nokta olur.
        final capOrani = GecitAgi.yaricap * 2 / TasarimGirdileri.gorusYaricapi;
        expect(capOrani, lessThan(0.25));
        expect(capOrani, greaterThan(0.05));
      },
    );

    test('geçit haritanın en dar kenarının YÜZDE BEŞİNDEN küçük', () {
      // İkinci ölçek kontrolü, bu kez dünyaya karşı: geçit büyürse kapılar
      // arası mesafe kaybolur ve harita bir koridora döner.
      for (final harita in Harita.hepsi) {
        expect(
          GecitAgi.yaricap * 2 / harita.dunya.height,
          lessThan(0.05),
          reason: '${harita.ad} geçidi haritaya göre büyük',
        );
      }
    });
  });

  group('alan 11 · kapı', () {
    test('bölge içi geçiş SERBEST — PvP bir karar, sınav değil', () {
      for (final g in GecitAgi.hepsi) {
        if (g.kaynak.bolge == g.hedef.bolge) {
          expect(g.esik, 0, reason: '$g bölge içinde eşik istiyor');
        }
      }
    });

    test('bölgeler arası eşik hedefin KAPISI — ikinci bir sayı yok', () {
      for (final g in GecitAgi.hepsi) {
        if (g.kaynak.bolge != g.hedef.bolge) {
          expect(g.esik, g.hedef.bolge.girisEsigi, reason: '$g ayrı eşik');
        }
      }
    });

    test('kilitli geçit de GÖRÜNÜYOR — kapalı kapı bir hedef', () {
      // Kararın kendisi: oyuncu gidemeyeceği yeri görmeli. Bu test silinmeden
      // geçitler gizlenemez.
      final zayif = 0.0;
      final kilitliler = GecitAgi.hepsi.where((g) => !g.acik(zayif));
      expect(kilitliler, isNotEmpty);
      for (final g in kilitliler) {
        expect(g.gorunur, isTrue, reason: '$g gizleniyor');
      }
    });

    test('bölgeye girebilen oyuncu BİR SONRAKİNİ görüyor ama geçemiyor', () {
      // Sonuç testi: ilerleme okunabilir olmalı. Oyuncu her zaman tam bir
      // adım ötesini görüyor — ne fazlası (hedef bulanıklaşır) ne azı
      // (merdiven görünmez olur).
      for (final bolge in Bolge.hepsi) {
        final br = bolge.girisEsigi;
        final ileri = GecitAgi.gecitleriFor(
          Harita(bolge, HaritaTipi.pve),
        ).where((g) => g.yon == GecitYonu.dogu);
        for (final g in ileri) {
          expect(g.gorunur, isTrue);
          expect(
            g.acik(br),
            isFalse,
            reason: '${bolge.ad} kapısında duran oyuncu bir sonrakine geçiyor',
          );
        }
      }
    });

    test('açık harita sayısı BR ile artıyor — merdiven tek yönlü', () {
      var onceki = -1;
      for (final bolge in Bolge.hepsi) {
        final adet = GecitAgi.acikHaritalar(bolge.girisEsigi).length;
        expect(adet, greaterThan(onceki), reason: '${bolge.ad} açılmıyor');
        onceki = adet;
      }
      // Son bölgenin eşiğinde her şey açık: kilitli kalan harita kalmamalı.
      expect(
        GecitAgi.acikHaritalar(Bolge.hepsi.last.girisEsigi).length,
        Harita.hepsi.length,
      );
    });
  });
}
