@Tags(['turetme', 'aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 10.1 · SEVİYE ↔ BR AYRIMI ve 11.4 · SEVİYE İKİNCİL KAPI.
///
/// XP ayrı bir kaynak değil: öldürmeden kazanılan ömür boyu kredi. Seviye
/// XP'nin karşıladığı rank; düşmez. Kapı: BR birincil, seviye ikincil.
void main() {
  group('10.1 · seviye', () {
    test('sıfır XP sıfır seviye; eşikler nesil bütçelerinin toplamı', () {
      expect(Seviye.of(0), 0);
      expect(Seviye.esigi(0), 0);
      expect(Seviye.esigi(1), closeTo(KaynakAkisi.neselButcesi(0), 1e-6));
      expect(
        Seviye.esigi(2),
        closeTo(
          KaynakAkisi.neselButcesi(0) + KaynakAkisi.neselButcesi(1),
          1e-6,
        ),
      );
    });

    test('eşiğe varan tam o seviyede, bir eksiği bir altında', () {
      for (var k = 1; k <= Seviye.tavan; k++) {
        final esik = Seviye.esigi(k).ceil();
        expect(Seviye.of(esik), k, reason: 'seviye $k eşiği');
        expect(Seviye.of(esik - 1), k - 1, reason: 'seviye $k eşiğinin altı');
      }
    });

    test('kesin artan, tavanda duruyor — referans oyuncu bandı bitirince', () {
      var onceki = 0;
      for (var xp = 0; xp < Seviye.esigi(Seviye.tavan) * 1.5; xp += 50000000) {
        final s = Seviye.of(xp);
        expect(s, greaterThanOrEqualTo(onceki));
        onceki = s;
      }
      expect(Seviye.of(1 << 62), Seviye.tavan);
      expect(Seviye.tavan, Turetilenler.rankSayisi);
    });

    test('hangar sayacı: XP kayda giriyor, geri gitmiyor', () {
      final h = Hangar(accountId: 'a');
      expect(h.xp, 0);
      expect(h.seviye, 0);
      h.xpEkle(100);
      h.xpEkle(-50);
      h.xpEkle(0);
      expect(h.xp, 100);
      final geri = Hangar.fromJson(h.toJson());
      expect(geri.xp, 100);
      // Eski kayıt: alan yok, sıfır.
      expect(Hangar.fromJson({'accountId': 'e'}).xp, 0);
      // Boş sayaç kayda yazılmıyor: eski biçim korunur.
      expect(Hangar(accountId: 'b').toJson().containsKey('xp'), isFalse);
    });
  });

  group('11.4 · seviye ikincil kapı', () {
    test('ilk bölge herkese açık; eşik bandın ilk rankının bir altı', () {
      // KARAR 11.4 s1
      // Referans oyuncu için hiç bağlayıcı değil, yalnız parayla öne geçen
      // için: BR'yi para ile hızlandırmak mümkün, seviyeyi değil.
      expect(Bolge.ilk.seviyeEsigi, 0);
      for (final b in Bolge.hepsi.skip(1)) {
        expect(b.seviyeEsigi, b.ilkRank - 1);
        expect(b.seviyeEsigi, lessThan(b.ilkRank), reason: 'referansı bağlar');
      }
    });

    test(
      'BR yeterken seviye yetmiyorsa kapı kapalı; seviye bilinmiyorsa BR yeter',
      () {
        // KARAR 11.4 s1
        final b = Bolge.hepsi[2];
        final br = b.girisEsigi;
        expect(b.kabulEder(br), isTrue);
        expect(b.kabulEder(br, seviye: b.seviyeEsigi), isTrue);
        expect(b.kabulEder(br, seviye: b.seviyeEsigi - 1), isFalse);
        expect(b.kabulEder(br - 1, seviye: 99), isFalse, reason: 'BR birincil');
      },
    );

    test('geçit ve giriş noktası aynı kapıyı sınıyor', () {
      // KARAR 11.4 s1
      // Sunucu iki kapıyı SIRAYLA sınıyor ve hangisinin kapalı olduğunu ayrı
      // söylüyor; istemci seviyeyi bilmiyorsa yalnız BR'yi gösterir.
      final hedef = Bolge.hepsi[2];
      final gecit = GecitAgi.hepsi.firstWhere(
        (g) => g.hedef.bolge == hedef && g.kaynak.bolge != hedef,
      );
      expect(gecit.seviyeEsigi, hedef.seviyeEsigi);
      expect(gecit.acik(gecit.esik, seviye: hedef.seviyeEsigi - 1), isFalse);
      expect(gecit.acik(gecit.esik, seviye: hedef.seviyeEsigi), isTrue);
      final ayniBolge = GecitAgi.hepsi.firstWhere(
        (g) => g.hedef.bolge == g.kaynak.bolge,
      );
      expect(ayniBolge.seviyeEsigi, 0, reason: 'bölge içi geçiş serbest');

      final kayitli = Harita(hedef, HaritaTipi.pve).id;
      final dusen = GalaksiHaritasi.girisNoktasi(
        kayitliId: kayitli,
        br: hedef.girisEsigi,
        seviye: hedef.seviyeEsigi - 1,
      );
      expect(
        dusen.bolge.kademe,
        lessThan(hedef.kademe),
        reason: 'seviyesiz oyuncu geri düşmeli',
      );
      final kalan = GalaksiHaritasi.girisNoktasi(
        kayitliId: kayitli,
        br: hedef.girisEsigi,
        seviye: hedef.seviyeEsigi,
      );
      expect(kalan.bolge, hedef);
    });
  });
}
