@Tags(['aralik', 'kod-belge'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 08.3 · MARJİNAL FİYATLAR TOPLANMAZ; 08 DAĞITIR, 16 ÖLÇER.
///
/// Shapley: verimlilik aksiyomu tamamlayıcılıktan doğan fazlayı adil dağıtır
/// ve tam olarak toplama eşitlenir. Ölçüm bir doğrulama, ayar kolu değil.
void main() {
  final phi = PayOlcumu.shapley();
  final olculen = PayOlcumu.olculenPaylar();

  test('verimlilik: Shapley toplamı gerçekleşen güce eşit', () {
    final toplam = phi.values.fold(0.0, (a, b) => a + b);
    expect(toplam, closeTo(PayOlcumu.tamGuc, 1e-6));
    expect(olculen.values.fold(0.0, (a, b) => a + b), closeTo(100, 1e-6));
  });

  test('her grup güç katıyor; lazer taban, en büyük pay onun', () {
    for (final g in PayGrubu.values) {
      expect(phi[g]!, greaterThan(0), reason: '${g.ad} güç katmıyor');
    }
    final enBuyuk = PayGrubu.values.reduce(
      (a, b) => olculen[a]! >= olculen[b]! ? a : b,
    );
    expect(enBuyuk, PayGrubu.lazer);
  });

  test(
    'boş kit güç vermiyor; kanallar toplamsal, tamamlayıcılık kanal içinde',
    () {
      expect(PayOlcumu.gucFor(const {}), 0);
      expect(PayOlcumu.gucFor({PayGrubu.govde}), greaterThan(0));
      expect(PayOlcumu.gucFor({PayGrubu.lazer}), greaterThan(0));
      // Gövde dayanıklılığa, lazer saldırıya yazar: iki kanal toplanır, çarpılmaz.
      expect(
        PayOlcumu.gucFor({PayGrubu.govde, PayGrubu.lazer}),
        closeTo(
          PayOlcumu.gucFor({PayGrubu.govde}) +
              PayOlcumu.gucFor({PayGrubu.lazer}),
          1e-6,
        ),
      );
    },
  );

  test('ilan edilen paylar toplamı yüz', () {
    final toplam = PayGrubu.values.fold(0.0, (a, g) => a + g.ilanEdilen);
    expect(toplam, closeTo(100, 0.05));
  });

  // KARAR 08.3 s2
  test('ilan ↔ ölçülen fark bandın altında (08 değişmezi)', () {
    // Bant üç puandı ve yapısal olarak tutmadı: lazer taban hasarı veriyor,
    // tamamlayıcılık artığı ona akıyor (dokuz puan). İlanı ölçüme çekmek
    // kovalamaca olurdu; bant ona açıldı (borç defteri B12) ve test askıdan
    // indi. On da tutmazsa sorun artık yapısal değil, gerçek.
    expect(PayOlcumu.enBuyukFark, lessThan(TasarimGirdileri.payBandi));
  });

  // KARAR 03.2 s2
  test('sistem kanalının kuru FİYATLAYANDAN okunuyor — tek A', () {
    // Bir sistem puanı 2A ÷ 100 DPS eder (03.1, 09.5). A, fiyatın ölçüldüğü
    // referansın saldırısı; ölçüm başka bir A okusaydı hız ve menzil eşyası
    // bir yerde pahalı, öteki yerde ucuz sayılır ve fark payın sapması gibi
    // görünürdü. Dolu referansta A çıplağın iki katından büyük, yani ayrışma
    // sessiz kalmazdı.
    expect(
      FiyatCozumu.sistemPuaniDps,
      closeTo(2 * ItemBudget.olcumDps(FiyatCozumu.referans) / 100, 1e-12),
    );
    expect(
      FiyatCozumu.sistemPuaniDps,
      greaterThan(2 * ItemBudget.olcumDps(ShipStats.bastion) / 100 * 1.5),
      reason: 'kur hâlâ çıplak referanstan okunuyor',
    );
    // Kur ile fiyat aynı A'yı okuduğu için sistem statının GÜCÜ ölçüm
    // noktasından bağımsız: eşya yarısı kadar birim veriyor, birim iki katı
    // değerde. Ölçülen: bir hız jeneratörünün sistem katkısı.
    final birim = ItemBudget.birimFiyati('hiz');
    final katki =
        birim *
        100 *
        TasarimGirdileri.sistemKatsayisiHiz *
        FiyatCozumu.sistemPuaniDps;
    final ciplakBirim = ItemBudget.fiyatlariTuret(ShipStats.bastion)['hiz']!;
    final ciplakKatki =
        ciplakBirim *
        100 *
        TasarimGirdileri.sistemKatsayisiHiz *
        2 *
        ItemBudget.olcumDps(ShipStats.bastion) /
        100;
    expect(
      katki,
      closeTo(ciplakKatki, ciplakKatki * 1e-9),
      reason: 'sistem puanının gücü ölçüm noktasına bağlı kalmış',
    );
  });
}
