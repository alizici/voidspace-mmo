/// Sunucu ile istemcinin PAYLAŞTIĞI çekirdek.
///
/// Bu paketin var olma sebebi tek bir cümle: **simülasyon iki yerde
/// yazılamaz.** İstemci kendi gemisini gecikmeyi gizlemek için önceden
/// oynatır (tahmin), sunucu ise otorite olarak aynı adımı koşar. İki taraf
/// aynı fonksiyonu çağırmazsa sonuçlar ayrışır ve oyuncu ışınlanır — netcode'un
/// en pahalı hata sınıfı budur.
///
/// Bu yüzden paket saf Dart'tır: Flutter, Flame ve Bloc'a bağımlılığı YOKTUR,
/// böylece `dart:io` sunucusunda da Flutter istemcisinde de aynı kod koşar.
library;

export 'src/combat/combat_glossary.dart';
export 'src/combat/damage_chain.dart';
export 'src/combat/stat_layer.dart';
export 'src/denetim/belge_uretici.dart';
export 'src/denetim/denge_denetimi.dart';
export 'src/denetim/test_turu.dart';
export 'src/denetim/turetilen_kaydi.dart';
export 'src/denetim/pay_olcumu.dart';
export 'src/denetim/elit_droid_olcumu.dart';
export 'src/design/prd.dart';
export 'src/design/tasarim_alanlari.dart';
export 'src/design/tasarim_girdileri.dart';
export 'src/design/turetilen_tablolar.dart';
export 'src/design/turetilenler.dart';
export 'src/domain/alien_stats.dart';
export 'src/domain/droid_grubu.dart';
export 'src/domain/laser_stats.dart';
export 'src/auth/credentials.dart';
export 'src/auth/kimlik_kodu.dart';
export 'src/net/sunucu_kodu.dart';
export 'src/domain/ship_stats.dart';
export 'src/domain/vec2.dart';
export 'src/domain/world.dart';
export 'src/progression/arge.dart';
export 'src/progression/budget.dart';
export 'src/progression/catalogue.dart';
export 'src/progression/currency.dart';
export 'src/progression/fatigue.dart';
export 'src/progression/fiyat_cozumu.dart';
export 'src/progression/ganimet_cekilisi.dart';
export 'src/progression/ganimet.dart';
export 'src/progression/hangar.dart';
export 'src/progression/hull.dart';
export 'src/progression/item.dart';
export 'src/progression/kaynak_akisi.dart';
export 'src/progression/kazanc.dart';
export 'src/progression/ledger.dart';
export 'src/progression/malzeme.dart';
export 'src/progression/mermi.dart';
export 'src/progression/loadout.dart';
export 'src/progression/acilis.dart';
export 'src/progression/formasyon.dart';
export 'src/progression/referans_build.dart';
export 'src/progression/referans_cozumu.dart';
export 'src/progression/roket.dart';
export 'src/progression/saglayici.dart';
export 'src/progression/seviye.dart';
export 'src/progression/unvan.dart';
export 'src/progression/stat.dart';
export 'src/progression/yukseltme.dart';
export 'src/net/byte_io.dart';
export 'src/net/entity_delta.dart';
export 'src/net/messages.dart';
export 'src/net/protocol.dart';
export 'src/net/quantize.dart';
export 'src/net/replication.dart';
export 'src/world/bolge.dart';
export 'src/world/gecit.dart';
export 'src/world/galaksi.dart';
export 'src/world/dusman.dart';
export 'src/world/yaratik_kadrosu.dart';
export 'src/sim/alien_sim.dart';
export 'src/sim/ship_input.dart';
export 'src/sim/threat.dart';
export 'src/sim/ship_sim.dart';
export 'src/sim/ship_sim_state.dart';
