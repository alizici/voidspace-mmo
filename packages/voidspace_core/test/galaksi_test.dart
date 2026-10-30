@Tags(['kapsam'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 11 · GALAKSİ HARİTASI — dünyanın oyuncuya göre görünümü.
///
/// Tek kural: **hiçbir harita gizlenmiyor.** Testlerin yarısı o kuralı, yarısı
/// "kilitli" ile "görünmez" arasındaki farkı koruyor.
void main() {
  final zayif = 0.0;
  final guclu = Bolge.hepsi.last.girisEsigi;

  group('alan 11 · hiçbir harita gizlenmiyor', () {
    test('en zayıf oyuncu bile BÜTÜN haritaları görüyor', () {
      // Kırılırsa: merdiven görünmez olmuş. Oyuncu nereye gittiğini bilmeden
      // ilerliyor ve ilerlemenin bir yönü olduğu hissi kayboluyor.
      expect(GalaksiHaritasi.durumFor(br: zayif).length, Harita.hepsi.length);
      expect(GalaksiHaritasi.durumFor(br: guclu).length, Harita.hepsi.length);
    });

    test('liste BR ile UZUNLUK değiştirmiyor — yalnız kilitler açılıyor', () {
      // Sonuç testi: filtreleme sızarsa liste kısalır. Uzunluğun sabit,
      // açık sayısının artan olması "gizleme yok, kilit var" demenin ölçülür
      // hâli.
      final uzunluklar = <int>{};
      final acikSayilari = <int>[];
      for (final bolge in Bolge.hepsi) {
        final durum = GalaksiHaritasi.durumFor(br: bolge.girisEsigi);
        uzunluklar.add(durum.length);
        acikSayilari.add(durum.where((d) => d.acik).length);
      }
      expect(uzunluklar.length, 1, reason: 'liste uzunluğu BR ile değişiyor');
      for (var i = 1; i < acikSayilari.length; i++) {
        expect(acikSayilari[i], greaterThan(acikSayilari[i - 1]));
      }
    });

    test('satırlar bölge bölge — hiçbir harita düşmüyor', () {
      final satirlar = GalaksiHaritasi.satirlarFor(br: zayif);
      expect(satirlar.length, Bolge.hepsi.length);
      expect(
        satirlar.fold<int>(0, (a, s) => a + s.length),
        Harita.hepsi.length,
      );
      for (final satir in satirlar) {
        expect(satir.length, HaritaTipi.values.length);
      }
    });
  });

  group('alan 11 · kilit okunabilir', () {
    test('kilitli haritanın EKSİK BR\'si yazılı — kapı bir hedef', () {
      // Kırılırsa: "kilitli" demek kalıyor ama "ne kadar daha" gidiyor. O
      // durumda kapalı kapı bir hedef değil bir duvar.
      final durum = GalaksiHaritasi.durumFor(br: zayif);
      final kilitli = durum.where((d) => !d.acik);
      expect(kilitli, isNotEmpty);
      for (final d in kilitli) {
        expect(d.eksikBr, greaterThan(0), reason: '${d.harita.ad} eksiksiz');
        expect(
          d.eksikBr,
          closeTo(d.harita.girisEsigi - zayif, 1e-9),
          reason: '${d.harita.ad} eksik BR eşikten gelmiyor',
        );
      }
    });

    test('açık haritanın eksiği SIFIR — eksi değil', () {
      for (final d in GalaksiHaritasi.durumFor(br: guclu)) {
        expect(d.acik, isTrue);
        expect(d.eksikBr, 0);
      }
    });

    test('eksik BR eşik yaklaştıkça KÜÇÜLÜYOR', () {
      // Sonuç testi: sayı bir mesafe ölçüsü, bir etiket değil.
      final hedef = Bolge.hepsi.last;
      var onceki = double.infinity;
      for (final bolge in Bolge.hepsi) {
        final durum = GalaksiHaritasi.durumFor(br: bolge.girisEsigi);
        final d = durum.firstWhere((x) => x.harita.bolge == hedef);
        if (!d.acik) {
          expect(d.eksikBr, lessThan(onceki));
          onceki = d.eksikBr;
        }
      }
    });
  });

  group('alan 11 · giriş noktası', () {
    test('kayıt yoksa BAŞLANGIÇ', () {
      expect(GalaksiHaritasi.girisNoktasi(br: guclu), Harita.baslangic);
      expect(
        GalaksiHaritasi.girisNoktasi(kayitliId: null, br: guclu),
        Harita.baslangic,
      );
    });

    test('kapı açıksa BIRAKTIĞI yer — dünya sürekli bir yer', () {
      // Kırılırsa: çıkış yapan oyuncu her seferinde başa dönüyor ve geçitten
      // geçmenin kalıcı hiçbir sonucu kalmıyor.
      for (final harita in Harita.hepsi) {
        expect(
          GalaksiHaritasi.girisNoktasi(kayitliId: harita.id, br: guclu),
          harita,
          reason: '${harita.ad} kaydı geri yüklenmedi',
        );
      }
    });

    test('kapı KAPANMIŞSA girebildiği en ileri bölgeye düşüyor', () {
      // Kararın kendisi: kapı bir DURUM. Bir kez girip sonra teçhizatını satan
      // oyuncu, taşıyamayacağı bir bölgede park edemiyor.
      //
      // Ölçü `brTabani`: donatımsız başlangıç gövdesinin savaş puanı, yani
      // oyunun ürettiği EN DÜŞÜK değer. Sıfır kullanmak kimsenin sahip
      // olamayacağı bir gücü sınamak olurdu.
      final derin = Harita(Bolge.hepsi.last, HaritaTipi.pve);
      final taban = CombatGlossary.brTabani;
      final yer = GalaksiHaritasi.girisNoktasi(kayitliId: derin.id, br: taban);
      expect(yer, isNot(derin));
      expect(yer.kabulEder(taban), isTrue, reason: 'giremeyeceği yere düştü');
    });

    test('BAŞLANGIÇ haritası her zaman ulaşılabilir', () {
      // Kapının altında kalan bir güç bugün üretilemiyor (gövdenin kendisi
      // taban puanı veriyor) ama kural yine de tutmalı: oyuncunun uyanacak bir
      // yeri olmayan hiçbir durum olamaz.
      expect(
        GalaksiHaritasi.girisNoktasi(
          kayitliId: Harita(Bolge.hepsi.last, HaritaTipi.boss).id,
          br: 0,
        ),
        Harita.baslangic,
      );
    });

    test('düşülen yer PvE — PvP ve boss varış noktası, omurga değil', () {
      for (final tip in HaritaTipi.values) {
        final derin = Harita(Bolge.hepsi.last, tip);
        expect(
          GalaksiHaritasi.girisNoktasi(
            kayitliId: derin.id,
            br: CombatGlossary.brTabani,
          ).tip,
          HaritaTipi.pve,
        );
      }
    });

    test('düşülen yer girebildiği EN İLERİ bölge — daha geriye atmıyor', () {
      // Sonuç testi: ceza yalnız fazlasını almak. Üçüncü bölgeye girebilen
      // ama sekizincide kayıtlı oyuncu üçüncüye düşüyor, başa değil.
      final derin = Harita(Bolge.hepsi.last, HaritaTipi.pve);
      for (final bolge in Bolge.hepsi) {
        final yer = GalaksiHaritasi.girisNoktasi(
          kayitliId: derin.id,
          br: bolge.girisEsigi,
        );
        expect(
          yer.bolge,
          bolge,
          reason: '${bolge.ad} eşiğinde başka yere düştü',
        );
      }
    });

    test('BOZUK kayıt oyuncuyu kaybetmiyor', () {
      // Merdiven kısalırsa eski bir kimlik artık var olmayan bir bölgeyi
      // gösterir. Çökmek ya da kilitlenmek yerine başlangıca dönmeli.
      for (final bozuk in ['', 'abc', '99:pve', '0:yok', '0', ':::']) {
        expect(
          GalaksiHaritasi.girisNoktasi(kayitliId: bozuk, br: guclu),
          Harita.baslangic,
          reason: '"$bozuk" kaydı başlangıca düşmedi',
        );
      }
    });

    test('kimlik ADA değil YAPIYA bağlı — bölge adı değişebilir', () {
      // Kırılırsa: kayıt oyuncuya görünen bir metne bağlanmış ve o metin
      // değiştiği gün bütün oyuncuların yeri kayar.
      for (final harita in Harita.hepsi) {
        expect(harita.id, '${harita.bolge.kademe}:${harita.tip.name}');
        expect(harita.id, isNot(contains(harita.bolge.ad)));
        expect(Harita.byId(harita.id), harita);
      }
    });
  });

  group('alan 11 · konum ve komşuluk', () {
    test('oyuncunun bulunduğu harita TEK ve işaretli', () {
      final konum = Harita(Bolge.ilk, HaritaTipi.pvp);
      final burada = GalaksiHaritasi.durumFor(
        br: guclu,
        konum: konum,
      ).where((d) => d.burada);
      expect(burada.length, 1);
      expect(burada.first.harita, konum);
    });

    test('konum verilmezse hiçbir harita işaretli değil', () {
      expect(
        GalaksiHaritasi.durumFor(br: guclu).where((d) => d.burada),
        isEmpty,
      );
    });

    test('komşuluk geçit ağıyla AYNI — ikinci bir grafik yok', () {
      // Kırılırsa: galaksi haritası kendi bağlantı listesini tutmaya başlamış
      // ve iki grafik sessizce ayrışır. Çizilen yol ile yürünen yol farklı
      // olur — bulunması en zor hata türü.
      for (final harita in Harita.hepsi) {
        expect(
          GalaksiHaritasi.komsularFor(harita),
          GecitAgi.gecitleriFor(harita).map((g) => g.hedef).toList(),
        );
      }
    });

    test('GÖRÜNÜR ile GİDİLEBİLİR ayrı sorular', () {
      // Kararın kendisi: zayıf oyuncu ileri bölgeyi GÖRÜYOR ama komşu listesi
      // onu içermiyor. İkisi karışırsa ya harita boşalır ya kapı anlamsızlaşır.
      final ilk = Harita(Bolge.ilk, HaritaTipi.pve);
      final gorunur = GalaksiHaritasi.komsularFor(ilk);
      final gidilebilir = GalaksiHaritasi.gidilebilirler(ilk, zayif);
      expect(gorunur.length, greaterThan(gidilebilir.length));
      // Güçlü oyuncuda ikisi eşitleniyor.
      expect(GalaksiHaritasi.gidilebilirler(ilk, guclu).length, gorunur.length);
    });

    test('en ileri bölge BR ile ilerliyor', () {
      for (final bolge in Bolge.hepsi) {
        expect(GalaksiHaritasi.enIleriBolge(bolge.girisEsigi), bolge);
      }
    });
  });
}
