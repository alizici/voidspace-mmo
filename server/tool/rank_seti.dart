import 'dart:io';

import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/hangars.dart';

/// Bir hesaba HER RANKTAN bir eşya koyar — ikon merdivenini oyunda görmek için.
///
/// **Neden `HangarStore` üzerinden.** Dosya JSONL ve elle bir satır eklemek
/// mümkün, ama biçim `Hangar.toJson`'dan geliyor ve o değiştiği gün elle
/// yazılmış satır sessizce eskir. Depo EKLEMELİ (append-only) ve yükleyici
/// hesap başına SON kaydı alıyor: yani bu araç var olan hiçbir satıra
/// dokunmuyor, sonuna bir tane daha yazıyor.
///
/// ```bash
/// dart run server/tool/rank_seti.dart <hesapId> [--uygula]
/// ```
/// `--uygula` verilmeden HİÇBİR ŞEY YAZILMIYOR: ne eklendiğini önce
/// gösteriyor. Oyuncunun kalıcı verisi, kuru çalıştırma varsayılan olmalı.
Future<void> main(List<String> args) async {
  final hesap = args.isEmpty ? null : args.first;
  if (hesap == null) {
    stderr.writeln('kullanım: rank_seti.dart <hesapId> [--uygula]');
    exit(2);
  }
  final uygula = args.contains('--uygula');

  final store = HangarStore(
    path: Platform.environment['HANGARS'] ?? 'data/hangars.jsonl',
  );
  await store.load();

  final hangar = store.of(hesap);
  final oncesi = hangar.inventory.length;

  final eklenen = <ItemSpec>[];
  for (final rank in ItemTier.values) {
    // Rank başına LAZER: yuva tipi sabit kalınca ızgarada değişen tek şey
    // rank oluyor ve merdiven okunuyor. Yirmi farklı yuva tipi karıştırmak,
    // görülmek istenen ekseni gizlerdi.
    final spec = Catalogue.items.firstWhere(
      (s) => s.tier == rank && s.slot == SlotType.laser,
      orElse: () => Catalogue.items.firstWhere((s) => s.tier == rank),
    );
    // Kimlik BELİRLENİMCİ ve tanınabilir.
    //
    // İkisi de gerekli: kalite rolü kimlikten türüyor (`ItemBudget.kaliteRolu`)
    // yani aynı kimlik her çalıştırmada aynı statı veriyor — araç iki kez
    // koşarsa envanterde ikiz değil aynı eşya oluşuyor. Ve 'rankseti-' öneki
    // bunların ganimetten değil buradan geldiğini söylüyor.
    final id = 'rankseti-${rank.name}';
    if (hangar.itemOf(id) != null) continue;
    hangar.addItem(ItemInstance(instanceId: id, specId: spec.id));
    eklenen.add(spec);
  }

  for (final s in eklenen) {
    stdout.writeln('  + ${s.tier.label.padRight(15)} ${s.id}  (${s.name})');
  }
  stdout.writeln(
    '${eklenen.length} eşya · envanter $oncesi → ${hangar.inventory.length}',
  );

  if (!uygula) {
    stdout.writeln('KURU ÇALIŞTIRMA — hiçbir şey yazılmadı (--uygula ile yaz)');
    return;
  }
  await store.save(hangar);
  stdout.writeln('yazıldı: ${store.path}');
}
