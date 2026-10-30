@Tags(['turetme', 'kapsam'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// FİLO AYRI KALEM — artı bütçesi ve ganimet (13.6, 14.3).
///
/// On filo yuvası gövde yuvalarıyla aynı kaba girmiyor (borç defteri B19):
/// artı payının droid payı kadarı filoya, ganimette droid kendi zarını
/// atıyor. Ölçülen: kalemlerin toplamı bütçeyi aşmıyor, filo şansı gövde
/// şansıyla aynı kuraldan, çekilişte gövde zarı droid çekmiyor.
void main() {
  // KARAR 13.6 s2
  test('artı bütçesi iki kaleme bölünüyor, toplam korunuyor', () {
    for (var r = 0; r < Turetilenler.rankSayisi; r++) {
      final kademe = ReferansBuild.kademeOf(r);
      final toplam =
          KaynakAkisi.yuvaBasinaArti(r) * HullClass.yuvaSayisi(kademe) +
          KaynakAkisi.droidBasinaArti(r) * TasarimGirdileri.droidFiloTavani;
      expect(
        toplam,
        closeTo(
          KaynakAkisi.neselButcesi(r) *
              KaynakAkisi.payFor(GiderKalemi.artiBasma),
          1e-6,
        ),
        reason: 'rank $r: kalemler artı payını aşıyor ya da eksik bırakıyor',
      );
      expect(
        KaynakAkisi.droidBasinaArti(r) * TasarimGirdileri.droidFiloTavani,
        closeTo(toplam * TasarimGirdileri.payDroid / 100, 1e-6),
        reason: 'filo kalemi droid payı kadar değil',
      );
    }
  });

  test('filodaki droid de artı basıyor — nesil içinde ulaşılan seviye', () {
    for (var r = 0; r < Turetilenler.rankSayisi; r++) {
      final t = ItemTier.values[r];
      expect(
        KaynakAkisi.droidUlasilanSeviye(r, t),
        greaterThan(0),
        reason: 'rank $r: filo hiç artı basamıyor',
      );
      expect(
        KaynakAkisi.droidUlasilanSeviye(r, t),
        lessThanOrEqualTo(KaynakAkisi.ulasilanSeviye(r, t)),
      );
    }
  });

  // KARAR 14.3 s2
  test('filo düşme şansı gövdeyle AYNI kuraldan — yuva başına aynı deneme', () {
    final yuva = HullClass.yuvaSayisi(0);
    expect(
      Ganimet.droidDusmeSansi / Ganimet.dusmeSansi,
      closeTo(TasarimGirdileri.droidFiloTavani / yuva, 1e-9),
    );
    expect(Ganimet.droidDusmeSansi, inExclusiveRange(0.0, 1.0));
    for (var r = 0; r < Turetilenler.rankSayisi; r++) {
      final govdeYuva = HullClass.yuvaSayisi(ReferansBuild.kademeOf(r));
      // Filo şansı ilk bandın gövdesinden türüyor (on yuva ÷ on iki), bolluk
      // ise o bandın gövde yuvasıyla ölçülüyor; oran gövde yuvası ÷ ilk yuva.
      expect(
        Ganimet.droidBollugFor(r),
        closeTo(Ganimet.esyaBollugFor(r) * govdeYuva / yuva, 1e-9),
        reason: 'rank $r: filo bolluğu gövdeyle aynı kuraldan değil',
      );
    }
  });

  test('çekilişte gövde zarı droid çekmiyor, droid zarı yalnız droid', () {
    final zar = math.Random(3);
    final prd = PrdRoller(TasarimGirdileri.ustRankSansi);
    var droid = 0;
    var govde = 0;
    const deneme = 4000;
    for (var i = 0; i < deneme; i++) {
      final pay = GanimetCekilisi.cek(
        sinif: DusmanSinifi.boss,
        hasarPayi: 1,
        rank: 0,
        prd: prd,
        zar: zar,
        kimlikUret: (d) => 'g${i}_$d',
      );
      for (final g in pay.esyalar) {
        if (Catalogue.byId[g.specId]!.slot == SlotType.droid) {
          droid++;
        } else {
          govde++;
        }
      }
    }
    // Boss: gövde garantili üç, filo aynı oranla (10 ÷ 12 × 3 = 2,5).
    expect(govde / deneme, closeTo(TasarimGirdileri.bossEsyaSayisi, 0.05));
    expect(
      droid / deneme,
      closeTo(Ganimet.droidEsyaSansiFor(DusmanSinifi.boss), 0.15),
    );
  });
}
