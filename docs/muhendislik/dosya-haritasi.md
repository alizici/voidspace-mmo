---
ad: Dosya haritası (eski)
tur: muhendislik
kaynak: README.md
tasindi: 2026-09-11
---

# Dosya haritası (eski)

> **Mühendislik günlüğü · tarihsel.** Bu not kök README'den taşındı (2026-09-11). Gerekçeler kalıcı; sayılar yazıldıkları ya da ölçüldükleri günün değerleri. Güncel tasarım sayıları `docs/` altındaki üretilen tablolarda, güncel davranış kodda: çelişki olursa onlar geçerli.
>
> Bu harita eksik: `packages/voidspace_core/lib/src/` altında `auth/`, `denetim/`, `world/`; `lib/` altında `app/`, `auth/`, `dil/`, `hangar/` yok. Yapı için koda, kararların kodu için [tasarım haritasına](../00-harita.md) bak.

```
packages/voidspace_core/     saf Dart — sunucu ve istemcinin ORTAK çekirdeği
  src/design/                  TEK TEPE TABLO ve alan haritası
    tasarim_alanlari.dart        16 alan, katmanları, bağımlılıkları
    tasarim_girdileri.dart       elle girilen HER parametre — başka yerde yok
    turetilenler.dart            hesaplanan alanlar; üstlerine yazılamaz
    prd.dart                     sahte rastgele dağılım + sabit çözücüsü
  src/combat/                  alan 01 · Savaş Formülü
    stat_layer.dart              L0..L5 — katman sırası ve sayısı
    damage_chain.dart            zincir; içinde tek bir denge sabiti YOK
    combat_glossary.dart         yaylım · DPS · EHP · TTK sözleşmesi
  src/domain/                  vec2, dünya sınırları, gövde sayıları
  src/progression/             stat kütüphanesi, eşya, bütçe, hangar
  src/sim/                     ShipSim — TEK hareket ve havuz matematiği
  src/net/                     ikili protokol: kodlayıcı ve çözücü yan yana

server/                      otorite sunucusu — Flutter YOK, AOT derlenir
  lib/zone.dart                harita: entity kümesi, 30 Hz tik, ilgi alanı
  lib/gateway.dart             soket, oturum, tik saati, statik dosya
  bin/loadtest.dart            N sahte oyuncu — "40 kişi" ölçülebilir olsun diye

lib/                         istemci
  net/                         Flutter bilmez, oyun döngüsü olmadan test edilir
    predicted_ship.dart          tahmin + mutabakat + zaman genişletme
    remote_entities.dart         ara değer tamponu ve oynatma saati
    net_client.dart              soket, el sıkışma, yeniden bağlanma
  game/
    voidspace_game.dart          kamera, girdi, görünür alan kırpması
    components/
      ship_component.dart          gemi DÜĞÜMÜ — çizmez, yalnız konum ve ad
      ship_swarm.dart              EKRANDAKİ HER gemi, üç drawRawAtlas
      starfield.dart / world_grid.dart   kameraya kırpılmış zemin
    art/                         çizici DEĞİL, doku üreticisi
      bastion.dart               gövde + eriyik zırh + kor
      shield_shell.dart            kalkan kabuğu
      atlas_layout.dart            atlas yerleşimi — üretici ve okuyucu ortak
      ship_atlas.dart              pişmiş atlası cihaza göre yükler
  perf/frame_monitor.dart      UI ve raster süresi AYRI
  ship/                        Bloc — artık hesaplamaz, YANSITIR
  hud/                         durumun okunma yüzeyi (+ bağlantı perdesi)

tool/                        ÜRETİLEN ikili varlıkların kaynağı
  ship_atlas_test.dart         assets/ship_atlas.png
  atlas_parity_test.dart       atlas ↔ prosedürel görsel karşılaştırma
  app_icon_test.dart           uygulama ikonu
```
