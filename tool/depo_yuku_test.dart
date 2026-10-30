@Tags(['disi'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hangar/hangar_screen.dart';
import 'package:voidspace3/hangar/plaka_onbellegi.dart';
import 'package:voidspace3/net/hangar_view.dart';
import 'package:voidspace3/net/net_client.dart';

/// GERÇEK KAYITLA DEPO YÜKÜ — hangar telefonda kasıyor mu.
///
/// **Neden uydurma veriyle değil.** Kasma şikâyeti dolu bir depodan geldi ve
/// dolu bir deponun neye benzediğini yalnız gerçek kayıt biliyor: kaç parça,
/// hangi ranklarda, kaçı yörüngeli. Elle kurulan bir envanterde yörüngeli
/// hücre sayısını da elle seçmek gerekir ve o seçim ölçümü ölçen kişinin
/// beklentisine göre eğer.
///
/// `data/hangars.jsonl` yoksa (taze klon, CI) test SESSİZCE atlanıyor: bu bir
/// ölçüm aracı, bir kapı değil.
///
/// **Ne ölçülüyor.** Kare başına Dart tarafındaki iş: kurulum, yerleşim ve
/// çizim KAYDI. Rasterleştirme (GPU) buraya girmiyor — ama düzeltilen şey tam
/// da kayıt tarafındaydı: plakanın her karede yeniden çizilmesi ve kare başına
/// düşen `MaskFilter.blur` sayısı.
void main() {
  final dosya = File('data/hangars.jsonl');
  if (!dosya.existsSync()) {
    // ignore: avoid_print
    print('data/hangars.jsonl yok — ölçüm atlandı.');
    return;
  }

  /// EN DOLU hangar: hangi hesap olduğu önemli değil, yükü olan önemli.
  Map<String, Object?>? enDolu() {
    Map<String, Object?>? en;
    var enSayi = 0;
    // Son kayıt kazanıyor: dosya bir günlük, aynı hesap birden çok kez
    // yazılmış olabilir.
    final sonlar = <String, Map<String, Object?>>{};
    for (final satir in dosya.readAsLinesSync()) {
      if (satir.trim().isEmpty) continue;
      try {
        final j = jsonDecode(satir) as Map<String, Object?>;
        sonlar[j['accountId'] as String? ?? ''] = j;
      } on FormatException {
        continue;
      }
    }
    for (final j in sonlar.values) {
      final n = (j['inventory'] as Map?)?.length ?? 0;
      if (n > enSayi) {
        enSayi = n;
        en = j;
      }
    }
    return en;
  }

  testWidgets('DOLU depo telefonda kare bütçesini aşmıyor', (tester) async {
    final kayit = enDolu();
    if (kayit == null) {
      // ignore: avoid_print
      print('kayıt okunamadı — ölçüm atlandı.');
      return;
    }
    final hangar = HangarView.fromJson(kayit);
    final parca = hangar.inventory.length;
    expect(parca, greaterThan(0), reason: 'boş depoyla ölçüm anlamsız');

    // Telefon yatay: kıt olan eksen yükseklik.
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final net = NetClient(uri: Uri.parse('ws://olcum'))..hangar = hangar;
    addTearDown(net.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HangarScreen(client: net, onClose: () {})),
    );
    await tester.pump();

    // Sekmeye geçmeye gerek YOK: depo artık sağ bölmede kalıcı, hangi sekme
    // açık olursa olsun ekranda. Bir zamanlar buraya bir sekme dokunuşu
    // gerekiyordu ve o dokunuş, ölçülen sahnenin kurulmasının şartıydı.

    // Isınma: ilk kareler pişmemiş dokuları ve ilk yerleşimi içeriyor ve
    // sürekli hâli temsil etmiyor.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final saat = Stopwatch();
    final sureler = <int>[];
    for (var i = 0; i < 60; i++) {
      saat
        ..reset()
        ..start();
      await tester.pump(const Duration(milliseconds: 16));
      saat.stop();
      sureler.add(saat.elapsedMicroseconds);
    }
    sureler.sort();
    final ortalama = sureler.reduce((a, b) => a + b) / sureler.length / 1000;
    final p95 = sureler[(sureler.length * 0.95).floor()] / 1000;
    final enKotu = sureler.last / 1000;

    // ignore: avoid_print
    print(
      'DEPO YÜKÜ · $parca parça · ${PlakaOnbellegi.dokuSayisi} pişmiş doku · '
      'kare ort ${ortalama.toStringAsFixed(2)} ms · '
      'p95 ${p95.toStringAsFixed(2)} ms · en kötü ${enKotu.toStringAsFixed(2)} ms',
    );

    // BÜTÇE 6 ms — 60 Hz'in 16,7 ms'sinin epey altı, ve bilerek öyle.
    //
    // Ölçülen şey yalnız Dart tarafı; rasterleştirme buna dâhil değil ve
    // gerçek telefon bu Mac'ten yavaş. Bütçe bu yüzden bir "yeter" sınırı
    // değil bir NÖBETÇİ: bugünkü değer 0,8 ms, yani sekiz kat pay var. Bu
    // testin yakalayacağı şey ölçüldü ve gerçekti — yükseltme oku hesabının
    // her karede yapılması (p95 19,6 ms) ve ızgaranın bütün hücreleri birden
    // kurması (p95 14,7 ms).
    expect(
      p95,
      lessThan(6),
      reason:
          '$parca parçalık depoda kare p95 ${p95.toStringAsFixed(2)} ms — '
          'depo yeniden ağırlaştı',
    );
  });
}
