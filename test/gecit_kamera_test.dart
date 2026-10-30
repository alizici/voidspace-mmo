@Tags(['disi'])
library;

import 'package:flame/camera.dart';
import 'package:flame/experimental.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/world_geometry.dart';
import 'package:voidspace3/net/net_client.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/net/predicted_ship.dart';
import 'package:voidspace_core/voidspace_core.dart';

import 'game_harness.dart';

/// GEÇİT SONRASI KAMERA — "gemimi hareket ettiremiyorum"un asıl sebebi.
///
/// Bölge haritaları aynı ölçüde DEĞİL: bant sayısı arttıkça büyüyorlar ve
/// iki ölçü dönüşümlü geliyor (15.964 × 10.643 ile 19.552 × 13.034). Sahne
/// bir kez kuruluyor, `camera.setBounds` yalnız orada çağrılıyordu ve sahne
/// geçitte yeniden kurulmuyordu. Sonuç: büyük haritaya geçen oyuncunun
/// kamerası eski haritanın dikdörtgeninde kalıyor ve gemi o sınırı aşınca
/// kamera onu takip edemiyor.
///
/// Belirti ağ gibi görünüyor — "harita senkron olmadı, ağır lag" — oysa ağ
/// kusursuz çalışıyor; yalnız kamera yanlış yere bakıyor. Bu testin varlık
/// sebebi o yanlış teşhis.
void main() {
  // Atlas gerçekten yükleniyor ([bootGame]) ve `rootBundle` bağlama muhtaç.
  // Bağlama kurulmazsa atlas sessizce null kalıyor, sahne hiç kurulmuyor ve
  // test kameranın yokluğunu ölçüyordu — yani kusuru değil kendi eksiğini.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iki bölge ölçüsü GERÇEKTEN farklı: testin dayanağı', () {
    // Test bu farkın üstüne kurulu. Bir gün bütün haritalar eşitlenirse bu
    // sınama sessizce anlamsızlaşır — o yüzden dayanağı ayrıca ilan ediliyor.
    final olculer = {
      for (final b in Bolge.hepsi) (b.harita.width, b.harita.height),
    };
    expect(olculer.length, greaterThan(1), reason: 'bütün haritalar aynı ölçüde');
  });

  // `testWidgets` DEĞİL düz `test`: [bootGame] atlası gerçekten yüklüyor ve
  // sahte zamanlı bir test ortamında o future hiç tamamlanmıyor — sınama on
  // dakika asılı kalıp zaman aşımına düşüyordu. Bu testin widget ağacına
  // ihtiyacı da yok; ölçtüğü şey kameranın sınırı.
  test('geçitten sonra kamera YENİ haritanın sınırlarını alıyor', () async {
    final net = NetClient(uri: Uri.parse('ws://127.0.0.1:1'));
    addTearDown(net.dispose);

    // İki ayrı ölçüde bölge seç: geçidin karşı tarafı daha büyük.
    final kucuk = Bolge.hepsi.firstWhere(
      (b) => b.harita.width < Bolge.hepsi.last.harita.width,
    );
    final buyuk = Bolge.hepsi.firstWhere(
      (b) => b.harita.width > kucuk.harita.width,
    );

    net
      ..world = kucuk.harita
      ..harita = Harita(kucuk, HaritaTipi.pve)
      ..phase = NetPhase.playing;
    final game = await bootGame(net);
    // Atlas ASENKRON yükleniyor ve sahne onsuz kurulmuyor. Sahte bir kare
    // yetmiyor: gerçek zaman geçmeli, yoksa test kameranın yokluğunu ölçüp
    // kusuru değil kendi eksiğini gösterir.
    await pumpGame(game, 0.4);

    // Kamera sınırı `BoundedPositionBehavior` içinde duruyor: `setBounds`
    // onu oraya yazıyor. Görünen dikdörtgeni ölçmek yanıltıcı olurdu —
    // o, kameranın o anki konumuna bağlı.
    double sinirEni() {
      final b = game.camera.viewfinder
          .firstChild<BoundedPositionBehavior>()!
          .bounds;
      return (b as Rectangle).toRect().width;
    }

    double sinirBoyu() {
      final b = game.camera.viewfinder
          .firstChild<BoundedPositionBehavior>()!
          .bounds;
      return (b as Rectangle).toRect().height;
    }

    // Sınır ham harita ölçüsü DEĞİL: `considerViewport: true` onu görüş alanı
    // kadar içeri alıyor (sınır kameranın MERKEZİ için). O yüzden mutlak
    // sayı değil, haritalar arasındaki FARK ölçülüyor — hem görüş alanından
    // bağımsız, hem de sınanan şeyin ta kendisi: sınır yeni haritayla
    // birlikte büyüdü mü.
    final oncekiEn = sinirEni();
    final oncekiBoy = sinirBoyu();

    // ── GEÇİT: daha büyük haritaya ──
    net
      ..world = buyuk.harita
      ..harita = Harita(buyuk, HaritaTipi.pve);
    await pumpGame(game, 0.2);

    expect(
      sinirEni() - oncekiEn,
      closeTo(buyuk.harita.bounds.width - kucuk.harita.bounds.width, 1),
      reason: 'kamera ESKİ haritanın sınırında kaldı',
    );
    expect(
      sinirBoyu() - oncekiBoy,
      closeTo(buyuk.harita.bounds.height - kucuk.harita.bounds.height, 1),
      reason: 'kamera ESKİ haritanın sınırında kaldı',
    );
  });

  test('geçitte SIRA NUMARASI taşınıyor: istemci sağır kalmıyor', () {
    // Sunucu tarafındaki eşi `server/test/gecit_test.dart` içinde. İkisi
    // birden gerekiyor: yalnız sunucu taşırsa istemcinin sıfırdan sayan
    // girdileri reddedilir, yalnız istemci taşırsa yolda kalan eski girdi
    // sunucunun sayacını sıçratır. Yarım düzeltme, düzeltmeme kadar kötü.
    final dunya = Bolge.ilk.harita;
    final gemi = PredictedShip(
      world: dunya,
      initial: ShipSimState.spawn(ShipStats.bastion, dunya.centre),
    );
    // Bir süre uç: sayaç ilerlesin.
    for (var i = 0; i < 40; i++) {
      gemi.advance(1 / 30);
    }
    expect(gemi.sonSira, greaterThan(0), reason: 'sayaç hiç ilerlemedi');

    // GEÇİT: yeni dünyada yeni tahmin, sıra DEVRALINIYOR.
    final yeniDunya = Bolge.hepsi[1].harita;
    final yeniGemi = PredictedShip(
      world: yeniDunya,
      initial: ShipSimState.spawn(ShipStats.bastion, yeniDunya.centre),
      baslangicSirasi: gemi.sonSira,
    );
    expect(yeniGemi.sonSira, gemi.sonSira, reason: 'sıra devralınmadı');

    // Ve ilerlemeye ESKİNİN ÜSTÜNDEN devam ediyor.
    yeniGemi.advance(1 / 30);
    expect(
      yeniGemi.sonSira,
      greaterThan(gemi.sonSira),
      reason: 'yeni gemi sırayı ileri taşımıyor',
    );
  });
}
