@Tags(['kod-belge'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/atlas_layout.dart';
import 'package:voidspace3/game/art/govde_tasarimlari.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// SANAT KISITI — karar 04.9: lazer yuvası = çizimdeki namlu sayısı.
///
/// Çekirdek istemciyi okuyamaz (yön yanlış olurdu), o yüzden sayı orada
/// bildiriliyor ([TasarimGirdileri.lazerYuvaSayisi]) ve eşitlik burada,
/// ikisini de görebilen tek yerde doğrulanıyor. Ölçüldüğünde tutmuyordu:
/// sekiz tasarımın hepsinde beş kaide varken tablo yuvayı on ikiye
/// çıkarıyordu. Sanat kazandı; bu test o kararın kilidi.
void main() {
  // KARAR 04.9 s2
  test('her kademede lazer yuvası = tasarımın kaide sayısı = atlas kaidesi', () {
    expect(GovdeTasarimlari.hepsi.length, HullClass.all.length);
    for (var k = 0; k < HullClass.all.length; k++) {
      final govde = HullClass.all[k];
      final tasarim = GovdeTasarimlari.hepsi[k];
      expect(
        govde.laserSlots,
        tasarim.kaideler.length,
        reason:
            '${govde.name}: ${govde.laserSlots} yuva, ${tasarim.ad} ${tasarim.kaideler.length} kaide',
      );
      expect(govde.laserSlots, AtlasLayout.emitterMounts, reason: govde.name);
    }
    expect(TasarimGirdileri.lazerYuvaSayisi, AtlasLayout.emitterMounts);
  });
}
