import 'dart:io';

import 'package:voidspace_core/voidspace_core.dart';

import 'kararlar.dart';

/// Belge denetimi — komut satırından.
///
/// ```bash
/// dart run tool/belge/belge.dart            # denetle, üretilenleri tazele
/// dart run tool/belge/belge.dart --kuru     # yalnız denetle, dosya yazma
/// dart run tool/belge/belge.dart --onayla   # şüpheli bağlantıları onayla: metin
///                                          # değişti ama anlam değişmedi, izi yenile
/// ```
///
/// `test/belge_test.dart` ile aynı çözümleyici, aynı kurallar. Bu giriş
/// Obsidian'da yazarken flutter test beklemeden bakmak için.
void main(List<String> args) {
  final kuru = args.contains('--kuru');
  final onayla = args.contains('--onayla');
  final depo = BelgeDeposu.oku();
  final bulgular = depo.denetle();

  for (final tur in BulguTuru.values) {
    final bunlar = bulgular.where((b) => b.tur == tur).toList();
    if (bunlar.isEmpty) continue;
    stdout.writeln('${tur.etiket} (${bunlar.length})');
    for (final b in bunlar) {
      stdout.writeln('  ${b.mesaj}');
    }
  }

  var yazilan = 0;
  if (!kuru) {
    void yaz(String yol, String icerik) {
      final f = File(yol);
      if (f.existsSync() && f.readAsStringSync() == icerik) return;
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(icerik);
      stdout.writeln('yazıldı: $yol');
      yazilan++;
    }

    for (final e in BelgeUretici.dosyalar.entries) {
      yaz(e.key, e.value());
    }
    yaz('${depo.docs}/${BelgeDeposu.haritaDosyasi}', depo.haritaUret());
    final supheli = bulgular.where((b) => b.tur == BulguTuru.supheli).toList();
    if (supheli.isEmpty || onayla) {
      yaz('${depo.docs}/${BelgeDeposu.izDosyasi}', depo.izDosyasiUret());
      if (supheli.isNotEmpty) {
        stdout.writeln('onaylandı: ${supheli.length} şüpheli bağlantı, iz yenilendi');
        bulgular.removeWhere((b) => b.tur == BulguTuru.supheli);
      }
    } else {
      stdout.writeln(
        'karar izi bekliyor: sürümü artır ya da `--onayla` ile izi yenile',
      );
    }
  }

  final kararlar = depo.kararlar.values;
  stdout.writeln(
    '${depo.kurallar.length} kural belgesi · ${kararlar.length} karar · '
    '${depo.atiflar.length} atıf · ${bulgular.length} bulgu · '
    '$yazilan dosya yazıldı',
  );
  exit(bulgular.isEmpty ? 0 : 1);
}
