@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hud/galaksi_haritasi.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// GALAKSİ EKRANI — oyuncunun dünyayı okuduğu yer.
///
/// Bu dosya bildirilen bir hatadan doğdu: "hepsi açık görünüyor, neresi
/// kilitli belli değil ve hangi haritada olduğu da yazmıyor." İkisi de
/// gerçekti — `konum` ekrana hiç geçirilmiyordu, ve açık haritalar yalnız
/// "AÇIK" yazdığı için güçlenen oyuncuda ekran tamamen bilgisizleşiyordu.
void main() {
  Future<void> kur(
    WidgetTester tester, {
    required double br,
    Harita? konum,
  }) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GalaksiEkrani(br: br, konum: konum),
      ),
    );
    await tester.pump();
  }

  testWidgets('BURADASIN işareti çıkıyor — konum geçiriliyor', (tester) async {
    // Kırılırsa: ekran nerede olduğunu söylemiyor. Yirmi dört haritalı bir
    // dünyada bu, haritanın işe yaramaz olması demek.
    final konum = Harita(Bolge.hepsi[1], HaritaTipi.pvp);
    await kur(tester, br: Bolge.hepsi.last.girisEsigi, konum: konum);
    expect(find.text('BURADASIN'), findsOneWidget);
  });

  testWidgets('konum verilmezse hiçbir düğüm BURADASIN demiyor', (
    tester,
  ) async {
    await kur(tester, br: Bolge.hepsi.last.girisEsigi);
    expect(find.text('BURADASIN'), findsNothing);
  });

  testWidgets('HEPSİ açıkken bile eşikler görünüyor', (tester) async {
    // Bildirilen hatanın kendisi. Güçlü oyuncuda her harita açık ve ekran
    // eskiden yalnız "AÇIK" yazıyordu: merdiven görünmez oluyordu.
    await kur(tester, br: Bolge.hepsi.last.girisEsigi * 10);
    // Tam eşleşme: başlık haklı olarak "15/15 HARİTA AÇIK" diyor, düğümler
    // artık demiyor.
    expect(find.text('AÇIK'), findsNothing);
    // Kapısı olan her bölge eşiğini söylüyor.
    for (final bolge in Bolge.hepsi.where((b) => b.girisEsigi > 0)) {
      expect(
        find.textContaining(_binlik(bolge.girisEsigi)),
        findsWidgets,
        reason: '${bolge.ad} eşiği yazmıyor',
      );
    }
    // Kapısız ilk bölge SERBEST diyor — boş bırakmak "bilinmiyor" gibi okunur.
    expect(find.text('SERBEST'), findsNWidgets(HaritaTipi.values.length));
  });

  testWidgets('KİLİTLİ olan eksiğiyle ayrılıyor', (tester) async {
    final durum = GalaksiHaritasi.durumFor(br: CombatGlossary.brTabani);
    final kilitli = durum.where((d) => !d.acik);
    expect(kilitli, isNotEmpty, reason: 'test kurgusu bozuk: hepsi açık');

    await kur(tester, br: CombatGlossary.brTabani);
    // Kilitli düğümler `+` önekiyle: "daha ne kadar gerek" sorusunun cevabı.
    expect(find.textContaining('+'), findsWidgets);
    for (final d in kilitli) {
      expect(
        find.text('+${_binlik(d.eksikBr)} BR'),
        findsWidgets,
        reason: '${d.harita.ad} eksiği yazmıyor',
      );
    }
  });

  testWidgets('başlık NEREDE olduğunu söylüyor', (tester) async {
    final konum = Harita(Bolge.hepsi[1], HaritaTipi.boss);
    await kur(tester, br: Bolge.hepsi.last.girisEsigi, konum: konum);
    expect(find.textContaining(konum.ad.toUpperCase()), findsWidgets);
  });
}

/// Ekrandaki binlik ayraçlı biçim — `menuNumber` ile aynı.
String _binlik(num v) {
  final d = v.round().abs().toString();
  final out = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) out.write('.');
    out.write(d[i]);
  }
  return out.toString();
}
