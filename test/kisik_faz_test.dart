@Tags(['disi'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hangar/rank_saati.dart';

/// MENÜ SAATİNİN KISILMASI — gerçek cihaz ölçümünün sonucu.
///
/// iPhone'da (120 Hz) ölçüldü: hangar açıkken UI iş parçacığı boş (p50
/// 0,3 ms) ama GPU her karede 3,2 ms çiziyordu — bütün oyun dünyası 1,5 ms
/// tutarken. Suçlu, altı saniyede bir tur atan yörünge noktalarının ekran
/// hızında yeniden boyanmasıydı.
void main() {
  test('kaynak 120 kez tiklese de haber SAYILI: 30 Hz', () {
    final kaynak = ValueNotifier<double>(0);
    final kisik = KisikFaz(kaynak, saniye: 6, hz: 30);
    addTearDown(kisik.dispose);
    addTearDown(kaynak.dispose);

    var haber = 0;
    kisik.addListener(() => haber++);

    // Altı saniyelik turu 120 Hz'de sür: 720 tik.
    for (var i = 1; i <= 720; i++) {
      kaynak.value = i / 720;
    }
    // 6 sn × 30 Hz = 180 basamak. Kaynak 720 kez kıpırdadı, haber 180 kez
    // gitti: dörtte bir. Tam eşitlik beklenmiyor (yuvarlama sınırda bir
    // basamağı paylaşabilir), bant dar tutuluyor.
    expect(haber, inInclusiveRange(178, 182), reason: 'haber sayısı kaydı');
    expect(haber, lessThan(720 / 3), reason: 'kısma çalışmıyor');
  });

  test('DEĞER kaynağı izliyor: tur sonunda başa dönüyor', () {
    final kaynak = ValueNotifier<double>(0);
    final kisik = KisikFaz(kaynak, saniye: 6, hz: 30);
    addTearDown(kisik.dispose);
    addTearDown(kaynak.dispose);

    // Basamağa yuvarlanıyor ama SAPMIYOR: her an kaynağın bir basamak
    // yakınında. Sapsaydı iki plaka ayrı hızlarda kayardı.
    //
    // Fark ÇEMBER üzerinde ölçülüyor: faz bir tur ve 0 ile 1 aynı nokta.
    // Düz çıkarma, tur başındaki 0,999 → 0,000 geçişini 0,999'luk dev bir
    // sapma gibi okurdu — oysa orada nokta bir basamak ilerlemiş.
    double cemberFarki(double a, double b) {
      final d = (a - b).abs() % 1;
      return d > 0.5 ? 1 - d : d;
    }

    for (var i = 0; i <= 720; i++) {
      kaynak.value = i / 720;
      expect(
        cemberFarki(kisik.value, kaynak.value),
        lessThan(1 / 180 + 1e-9),
        reason: 'i=$i kaynak=${kaynak.value} kısık=${kisik.value}',
      );
    }
    // Tur BAŞA dönüyor: 1,0 ile 0,0 aynı nokta, iki ayrı basamak değil.
    kaynak.value = 1;
    expect(kisik.value, 0);
  });

  test('atılınca kaynağı dinlemeyi BIRAKIYOR', () {
    final kaynak = ValueNotifier<double>(0);
    final kisik = KisikFaz(kaynak, saniye: 6, hz: 30);
    var haber = 0;
    kisik.addListener(() => haber++);

    kaynak.value = 0.5;
    expect(haber, 1, reason: 'kısık saat kaynağı hiç dinlemedi');

    // Dinleyici kalsaydı kapanan hangarın saati oyunun ömrü boyunca
    // uyarılmaya devam ederdi. `hasListeners` korumalı, o yüzden davranış
    // sınanıyor: atılmış saat artık haber üretmiyor.
    kisik.dispose();
    kaynak.value = 0.9;
    expect(haber, 1, reason: 'atılan saat hâlâ kaynağı dinliyor');
    kaynak.dispose();
  });
}
