import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/app_scope.dart';
import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/durum_metni.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../dil/sayi.dart' as bicim;
import '../hangar/menu_cells.dart';
import '../hangar/unvan_satiri.dart';
import '../net/net_phase.dart';
import '../perf/frame_monitor.dart';
import '../ship/ship_bloc.dart';
import '../ship/ship_state.dart';
import 'hud_dugmeleri.dart';
import 'minimap.dart';
import 'reward_feed.dart';
import 'savas_cubugu.dart';
import 'touch_controls.dart';

/// Katlama düğmesinin ve katlanmış rozetin testten bulunabilir kimlikleri.
///
/// Tipler özel (private) ve öyle kalmalı — dışarıdan kurulacak şeyler değil.
/// Anahtar, testin davranışa erişmesi için gereken en dar kapı.
const hudCollapseKey = Key('hud-collapse');
const hudBadgeKey = Key('hud-badge');

/// İtki düğmesi. Anahtarla aranıyor çünkü 'İTKİ' METNİ ekranda iki yerde:
/// biri bu düğme, öteki hayati değerler panelindeki şarj göstergesi. Metne
/// göre aramak testte belirsiz eşleşme üretiyordu — ve o belirsizlik, düğme
/// bir gün kaybolduğunda testin göstergeyi bulup yeşil kalmasına yol açardı.
const hudBoostKey = Key('hud-boost');

/// Hayati değerler panelindeki unvan satırı (10.4).
const hudUnvanKey = Key('hud-unvan');

/// Hangarı açan düğme.
const hudHangarKey = Key('hud-hangar');
const hudGalaksiKey = Key('hud-galaksi');

/// Gemi durumunun okunma yüzeyi.
///
/// Simülasyondan hiçbir şey okumaz — yalnız [ShipBloc]'tan, o da sunucunun
/// otoriter durumunun yansıması. Kalkan çubuğu ile gemideki kabarcık aynı
/// kaynağa baktığı için ikisi asla uyuşmazlık gösteremez.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // Dikey ekranda oyun DEĞİL uyarı: görüş alanı 0.6 zoom'da dikeyde ~670
    // birime düşüyor, silah menzili ise 1400. Oyuncu vurabildiği hedefin
    // yarısını göremiyor — oynanabilir değil.
    if (AppScope.of(context).touchControls &&
        MediaQuery.orientationOf(context) == Orientation.portrait) {
      return const RotateHint();
    }
    return BlocBuilder<ShipBloc, ShipState>(
      // Dünyada değilken HUD hiç KURULMAZ, üstü perdeyle örtülmez.
      //
      // Görünürde aynı şey, davranışta değil: örtülen bir panel hâlâ vuruş
      // testine girer ve dokunulabilir kalır. Dünyada olmayan bir gemiye komut
      // yollayan bir düğme, bugün zararsız olduğu için yarın fark edilmeyecek
      // bir hata sınıfıdır.
      builder: (context, state) =>
          state.online ? _LiveHud(state: state) : _Curtain(state: state),
    );
  }
}

class _LiveHud extends StatelessWidget {
  const _LiveHud({required this.state});

  final ShipState state;

  @override
  Widget build(BuildContext context) {
    final touch = AppScope.of(context).touchControls;
    // Mobilde kenar payı DAR: `SafeArea` çentiği zaten kesiyor, üstüne kalın
    // bir pay eklemek küçük ekranda oyunun kendisinden çalıyor.
    final inset = touch ? 8.0 : 16.0;

    return SafeArea(
      child: Stack(
        children: [
          // Her öğe KENDİ köşesine çivili.
          //
          // Önce tek bir satır/sütun düzeniydi ve panel katlandığında harita
          // kayıyordu: ikisi aynı esneklik havuzunu paylaşıyordu, biri
          // küçülünce boşluk yeniden bölüşülüyordu. Köşeler artık birbirini
          // hiç görmüyor — bir öğenin boyu diğerinin yerini değiştiremez.
          Positioned(
            left: inset,
            top: inset,
            child: _Vitals(state: state),
          ),
          Positioned(
            right: inset,
            top: inset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Minimap(
                  state: state,
                  // Poz KANALI blocdan: durum on Hz, poz her karede.
                  poz: context.read<ShipBloc>().poz,
                  harita: AppScope.of(context).client.harita,
                  width: touch ? 150 : 186,
                ),
                const SizedBox(height: 8),
                // Cüzdan ve ödül bildirimi HARİTANIN ALTINDA.
                //
                // Oyunun döngüsünü kapatan parça: vurmak ve kazanmak sunucuda
                // çalışıyordu ama oyuncunun gördüğü hiçbir yer yoktu.
                // Hangarda bakiyenin değişmiş olduğunu fark etmek geri
                // bildirim değil, keşif.
                //
                // Haritanın ÜSTÜNE konmadı: harita köşeye çivili ve öyle
                // kalmalı (`touch_controls_test.dart` bunu ölçüyor). Üstüne
                // konan her şey onu köşeden uzaklaştırıyor. Altta ayrıca
                // HANGAR düğmesinin yanına düşüyor — para ile mağazanın
                // kapısı aynı yerde.
                RewardFeed(client: AppScope.of(context).client, compact: touch),
                const SizedBox(height: 8),
                // HANGAR düğmesi HER İKİ şemada da burada.
                //
                // Eskiden yalnız masaüstündeki `_TestControls` satırındaydı:
                // dokunmatikte onun yerine joystick geliyor, yani telefonda
                // hangara girmenin HİÇBİR yolu yoktu. Oyun iOS ve Android için
                // geliştiriliyor; erişilemeyen bir ekran, olmayan bir ekran.
                //
                // Sağ ÜST, alttaki eylem yığınının yanı değil: İTKİ ve HEDEF
                // dövüşün ortasında basılan düğmeler ve hangar bir mod
                // değişimi. Yanlışlıkla basılması, savaşın ortasında menüye
                // düşmek demek olurdu.
                //
                // GALAKSİ hangarın YANINDA, minimapın altındaki aynı satırda.
                // Minimap "buradasın" diyor, galaksi "nereye gidebilirsin"
                // diyor — ikisi aynı soruyu iki ölçekte cevaplıyor ve yan yana
                // durmaları o akrabalığı görünür kılıyor. Üst üste dururken
                // sağ sütun telefonda eylem yığınına dayanıyordu; tek satır
                // aşağıya yer açıyor.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HudPill(
                      key: hudHangarKey,
                      label: Metin.hangar(context.dil),
                      glif: HudGlif.hangar,
                      compact: !touch,
                      onTap: AppScope.of(context).onOpenHangar,
                    ),
                    const SizedBox(width: 6),
                    HudPill(
                      key: hudGalaksiKey,
                      label: Metin.galaksi(context.dil),
                      glif: HudGlif.galaksi,
                      color: Palette.accentBright,
                      compact: !touch,
                      onTap: AppScope.of(context).onOpenGalaksi,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: inset,
            bottom: inset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ölçüm satırı YALNIZ ölçüm derlemelerinde:
                // `--dart-define=PERF_LOG=true`. Oyuncunun ekranında kalıcı
                // bir teşhis satırı işi yok, ama geliştirme sırasında "akıcı
                // mı" sorusunun cevabı bir his değil bir sayı olmalı.
                if (FrameMonitor.logToConsole) ...[
                  const _FrameStats(),
                  const SizedBox(height: 8),
                ],
                if (touch)
                  Joystick(
                    size: 118,
                    // Eksen doğrudan tahmine yazılır — klavyenin yazdığı
                    // alanın aynısı. İki girdi yolunun aynı alanda buluşması,
                    // uçuşun tek bir kodda kalmasını sağlıyor.
                    onAxis: (axis) =>
                        AppScope.of(context).client.ship?.axis = axis,
                  )
                else
                  const _TestControls(),
              ],
            ),
          ),
          if (touch)
            Positioned(
              right: inset,
              bottom: inset,
              child: _ActionStack(state: state),
            ),
          // Geçit istemi ALT ORTADA ve yalnız geçidin üstündeyken.
          //
          // Kalıcı bir düğme olamazdı: yirmi dört haritanın hepsinde geçerli
          // olmayan bir eylem, ekranda sürekli durup çoğu zaman hiçbir şey
          // yapmayan bir düğme demekti. Ortada, çünkü sol başparmak yön sağ
          // başparmak eylem — ikisinin arası ikisine de eşit uzaklıkta ve
          // savaşın ortasında kazara basılmıyor.
          // Alt ağacın HİÇBİR yerinde `const` yok ve bu bir üslup tercihi
          // değil. Flutter yeni widget eskisiyle eşitse alt ağacı hiç
          // güncellemiyor; `const` bir kurucu da her karede AYNI nesneyi
          // veriyor. Sonuç: istem ilk karede (geçit uzaktayken) boş dönüyor ve
          // bir daha çalışmıyordu — oyuncu geçidin üstüne gelse de düğme
          // çıkmıyordu. Bu bölümün durumu widget'ta değil `NetClient`'ta
          // olduğu için eşitlik yanıltıcı: alan değişmiyor, cevap değişiyor.
          // SAVAŞ ÇUBUĞU alt ortada, her iki şemada: mermi ve formasyon
          // dövüşün ortasında değişiyor, hangara girmeden (17.8, 05.9).
          // `Align` yalnız çocuğunu vuruş testine sokuyor; şeridin geri
          // kalanı oyuna geçirgen.
          Positioned(
            left: 0,
            right: 0,
            bottom: inset,
            child: const Align(
              alignment: Alignment.bottomCenter,
              child: SavasCubugu(),
            ),
          ),
          // Geçit istemi ÇUBUĞUN ÜSTÜNDE — ikisi de alt ortada, üst üste
          // binselerdi kapı düğmesi mermi düğmesini örterdi.
          Positioned(
            left: 0,
            right: 0,
            bottom: inset + 64,

            // İKİ kaynağı birden dinliyor ve ikisi de gerekli:
            //
            //  * bloc — geminin KONUMU her karede değişiyor, geçide girip
            //    çıkmayı o taşıyor;
            //  * `net.changes` — red mesajı `NetClient`'ta duruyor ve oyuncu
            //    geçidin üstünde dururken gemi durumu HİÇ değişmiyor
            //    (`ShipState` bir `Equatable`), yani bloc yayın yapmıyor.
            //
            // Yalnız biri dinlenseydi ya istem geç kalırdı ya da red mesajı
            // tam gerektiği anda — duruyorsun, basıyorsun — hiç görünmezdi.
            child: Align(
              child: StreamBuilder<void>(
                stream: AppScope.of(context).client.changes,
                builder: (context, _) => _GecitIstemi(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// GEÇİT İSTEMİ — üstünde durulan kapının düğmesi.
///
/// Kilitliyken de görünüyor ama basılamıyor: oyuncu neyin eksik olduğunu
/// görmeli. "Görünmeyen kapı bir boşluk" kuralının oynanıştaki karşılığı.
class _GecitIstemi extends StatelessWidget {
  const _GecitIstemi();

  @override
  Widget build(BuildContext context) {
    final net = AppScope.of(context).client;
    final gecit = net.yakinGecit;
    if (gecit == null) return const SizedBox.shrink();

    final br = net.hangar?.br ?? 0;
    final seviye = net.hangar?.seviye;
    final acik = gecit.acik(br, seviye: seviye);
    final hedef = gecit.hedef;
    final dil = context.dil;
    // Tip adı (PvE · PvP · Boss) oyun terimi, bölge adı Türkçe: yalnız
    // ikincisi [menuUpper]'a giriyor — "Devrik Kule" → "DEVRİK KULE".
    final ad = hedef.bolge == gecit.kaynak.bolge
        ? hedef.tip.ad.toUpperCase()
        : menuUpper(haritaAdi(hedef, dil), dil);
    final renk = acik ? Palette.accent : Palette.faint;

    return GestureDetector(
      onTap: acik ? net.gecitteGec : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.panel,
          border: Border.all(color: renk, width: acik ? 2 : 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            gecitMetni(net.gecitHatasi, dil) ??
                (acik
                    ? Metin.gecitGec.bicim(dil, {'ad': ad})
                    : br >= gecit.esik
                    ? Metin.gecitSeviyeGerek.bicim(dil, {
                        'ad': ad,
                        'n': gecit.seviyeEsigi,
                      })
                    : Metin.gecitBrGerek.bicim(dil, {
                        'ad': ad,
                        'n': (gecit.esik - br).round(),
                      })),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: acik ? Palette.inkBright : Palette.faint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sağ başparmağın eylem yığını.
///
/// Ateş düğmesi YOK ve bu bir eksik değil bir karar — dokunmatikte hedef
/// seçmek ateş etmek demek (bkz. `VoidspaceGame.touchControls`). Üçüncü bir
/// düğme hem ekranda yer hem de elde parmak isterdi.
class _ActionStack extends StatelessWidget {
  const _ActionStack({required this.state});

  final ShipState state;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TouchAction(
          label: Metin.itki(context.dil),
          glif: HudGlif.itki,
          tint: Palette.boost,
          onTap: () => scope.client.ship?.requestBoost(),
        ),
        const SizedBox(height: 10),
        TouchAction(
          label: Metin.hedef(context.dil),
          glif: HudGlif.hedef,
          active: state.weaponTarget != 0,
          onTap: () => scope.onCycleTarget?.call(),
        ),
      ],
    );
  }
}

/// Bağlantı perdesi.
///
/// Tek oyunculu bir geri düşüş YOK ve olmamalı: çevrimdışı uçurulan bir gemi,
/// bağlantı gelince sunucununkiyle uzlaştırılamaz — hangi gerçeğin doğru
/// olduğunu söyleyecek kimse yok.
class _Curtain extends StatelessWidget {
  const _Curtain({required this.state});

  final ShipState state;

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    // Perdenin altındaki oyun tıklanabilir kalmamalı: hedefi olmayan bir
    // gemiye "oraya uç" demek sessizce yok sayılır, ve sessizce yok sayılan
    // girdi hata ayıklaması en zor davranıştır.
    child: ColoredBox(
      color: const Color(0xEE03050C),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(
            color: Palette.panel,
            border: Border.all(color: Palette.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(switch (state.phase) {
                NetPhase.rejected => Metin.reddedildi(context.dil),
                NetPhase.disconnected => Metin.baglantiKoptu(context.dil),
                _ => Metin.baglaniliyorBuyuk(context.dil),
              }, style: Palette.label(13).copyWith(color: Palette.ink)),
              if (durumMetni(state.message, context.dil)
                  case final message?) ...[
                const SizedBox(height: 8),
                Text(message, style: Palette.label()),
              ],
              if (state.phase == NetPhase.disconnected) ...[
                const SizedBox(height: 8),
                Text(
                  Metin.yenidenDeneniyor(context.dil),
                  style: Palette.label(),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Hayati değerler paneli — dokunmatikte KATLANABİLİR.
///
/// Yatay bir telefonda dikey alan 375 piksel ve panel bunun yarısını yiyor.
/// Katlandığında yerine tek bir halka göstergesi kalıyor: dış yay gövde, iç
/// yay kalkan. Sayılar gider, ORAN kalır — dövüşün ortasında zaten okunan şey
/// o. Masaüstünde katlama YOK, çünkü orada yer sorunu da yok.
class _Vitals extends StatefulWidget {
  const _Vitals({required this.state});

  final ShipState state;

  @override
  State<_Vitals> createState() => _VitalsState();
}

class _VitalsState extends State<_Vitals> {
  /// `null` = henüz karar verilmedi; ilk yapımda platforma göre kurulur.
  ///
  /// Mobilde varsayılan KATLI: küçük bir ekranda açılışta karşılayan şey
  /// oyun olmalı, panel değil. Sayılar bir dokunuş uzakta ve halka zaten
  /// dövüşte okunan tek şeyi — oranı — gösteriyor.
  bool? _collapsed;

  ShipState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final touch = AppScope.of(context).touchControls;
    if (!touch) return _panel(context, collapsible: false);
    final collapsed = _collapsed ??= true;
    return collapsed
        ? _VitalsBadge(
            state: state,
            onTap: () => setState(() => _collapsed = false),
          )
        : _panel(context, collapsible: true);
  }

  Widget _panel(
    BuildContext context, {
    required bool collapsible,
  }) => AbsorbPointer(
    // Panel üstündeki tıklama altındaki oyuna geçmemeli. Boş bir `onTap`
    // yerine niyeti doğrudan söyleyen widget.
    //
    // Katlama düğmesi bu emicinin İÇİNDE: kendi dokunuşunu tüketiyor, geri
    // kalan panel yüzeyi ise hâlâ oyuna kapalı.
    absorbing: !collapsible,
    child: Container(
      // Katlama düğmesi başlık satırında yer istiyor; panel onun genişliği
      // kadar büyüyor. Daraltmak yerine büyütmek doğru olan: 260'a sıkıştırmak
      // "12 ms · 3" okumasını kırpardı ve ping bu oyunda süs değil.
      width: collapsible ? 296 : 260,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Palette.panel,
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `Spacer` DEĞİL `Expanded`.
          //
          // Gerçek bir hataydı ve testte yakalandı: `Spacer` boşluğu esnetiyor
          // ama iki metni de DOĞAL genişliğinde bırakıyordu. Ping üç haneye
          // çıktığı anda (yüklü makinede ya da kötü bağlantıda — yani tam da
          // oyuncunun HUD'a en çok baktığı anda) satır 230 piksellik panele
          // sığmıyor ve ekranda sarı-siyah taşma şeridi çıkıyordu.
          //
          // Şimdi kısalabilen taraf AÇIKÇA seçilmiş durumda: gemi adı süs,
          // ping veri. Ad üç noktayla kırpılır, ping kırpılmaz.
          Row(
            children: [
              Expanded(
                child: Text(
                  // [menuUpper] DEĞİL: gövde adları (Bastion, Aegis) her
                  // dilde aynı kalan özel adlar — "BASTİON" olurdu.
                  state.stats.name.toUpperCase(),
                  style: Palette.label(12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Ping bir süs değil: bu oyunun tasarım hedefi düşük gecikme,
              // ve ölçülmeyen hedef tutturulamaz.
              //
              // Dört haneli ping "bağlantı koptu" demektir ve okunacak bir
              // sayı değildir; tavanlamak hem satırı hem anlamı koruyor.
              Text(
                '${state.pingMs > 999 ? '999+' : state.pingMs} ms'
                ' · ${state.nearby}',
                style: Palette.label().copyWith(
                  color: state.pingMs > 120 ? Palette.hull : Palette.inkDim,
                ),
              ),
              if (collapsible) ...[
                const SizedBox(width: 10),
                _CollapseButton(onTap: () => setState(() => _collapsed = true)),
              ],
            ],
          ),
          // Pilotun unvanı geminin adının altında: sunucunun hangar
          // durumuyla yolladığı ad, seviye ve savaş puanı (10.1, 10.4). HUD
          // hesaplamıyor, yazıyor; ad daha gelmediyse satır yok.
          if (AppScope.of(context).client.hangar?.unvanAdi.isNotEmpty ??
              false) ...[
            const SizedBox(height: 4),
            UnvanSatiri(
              key: hudUnvanKey,
              hangar: AppScope.of(context).client.hangar,
              style: Palette.mono(
                10,
                weight: FontWeight.w700,
                color: Palette.accent,
                spacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _Bar(
            label: Metin.govde(context.dil),
            value: state.hullFraction,
            amount: state.hull,
            color: Palette.hull,
          ),
          const SizedBox(height: 7),
          _Bar(
            label: Metin.kalkan(context.dil),
            value: state.shieldFraction,
            amount: state.shield,
            color: Palette.shield,
          ),
          const SizedBox(height: 12),
          _BoostPips(state: state),
          const SizedBox(height: 10),
          _WeaponRow(state: state),
          const SizedBox(height: 8),
          _TargetRow(state: state),
        ],
      ),
    ),
  );
}

/// Paneli katlayan küçük düğme — bir çizgi, ikon fontu yok.
///
/// Proje Material ikon fontunu paketlemiyor (bkz. `pubspec.yaml`); tek bir
/// eksi işareti için 1.6 MB font eklemek, oyunu bir bağlantıdan açan oyuncuya
/// ödetilecek bir bedel değil.
class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.onTap}) : super(key: hudCollapseKey);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 26,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Palette.line),
      ),
      child: Container(width: 11, height: 1.6, color: Palette.inkDim),
    ),
  );
}

/// Katlanmış hâl: tek bir halka göstergesi.
///
/// Dış yay gövde, iç yay kalkan. Sayı yok — dövüşün ortasında okunan şey sayı
/// değil ORAN, ve panelin tamamı o oranı göstermek için yatay telefonda dikey
/// alanın yarısını yiyordu.
class _VitalsBadge extends StatelessWidget {
  const _VitalsBadge({required this.state, required this.onTap})
    : super(key: hudBadgeKey);

  final ShipState state;
  final VoidCallback onTap;

  static const double size = 54;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BadgePainter(
          hull: state.hullFraction,
          shield: state.shieldFraction,
        ),
      ),
    ),
  );
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter({required this.hull, required this.shield});

  final double hull;
  final double shield;

  /// Yaylar TEPEDEN başlar ve saat yönünde dolar — dolu bir yay tam tur.
  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    canvas
      ..drawCircle(centre, radius, Paint()..color = Palette.panel)
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Palette.line,
      );

    _arc(canvas, centre, radius - 5, hull, Palette.hull, 3.4);
    _arc(canvas, centre, radius - 11, shield, Palette.shield, 2.6);

    // Çekirdek: paneli geri açmanın dokunma hedefi olduğunu söyleyen leke.
    canvas.drawCircle(
      centre,
      3,
      Paint()..color = Palette.inkDim.withValues(alpha: 0.7),
    );
  }

  void _arc(
    Canvas canvas,
    Offset centre,
    double radius,
    double value,
    Color tint,
    double width,
  ) {
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = tint.withValues(alpha: 0.16);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final fraction = value.clamp(0.0, 1.0);
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      _start,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = tint,
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.hull != hull || old.shield != shield;
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.amount,
    required this.color,
  });

  final String label;
  final double value;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Palette.label()),
          Text(
            amount.round().toString(),
            style: Palette.label().copyWith(color: color),
          ),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: const Color(0x22FFFFFF),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ],
  );
}

/// Hedef kilidi ve ateş durumu.
///
/// Durum oyundan DEĞİL Bloc'tan okunur: kilit `ShipSimState`'in bir parçası ve
/// sunucu tarafından doğrulanıyor, yani HUD'ın gösterdiği şey oyunun gösterdiği
/// şeyle aynı kaynaktan geliyor. HUD oyunu okusaydı ikisi ayrışabilirdi.
/// Takılı silah ve yaylım hasarı.
///
/// Namlu sayısı adın YANINDA duruyor çünkü bir yaylımın hasarı ikisinin
/// çarpımı: tek başına "PL-4" yazmak, iki namlulu bir gövdeyle beş namlulusu
/// arasındaki farkı gizlerdi. Sağdaki sayı, ekranda uçuşan hasar sayılarının
/// nereden geldiğini açıklayan tek yer.
class _WeaponRow extends StatelessWidget {
  const _WeaponRow({required this.state});

  final ShipState state;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(Metin.silah(context.dil), style: Palette.label()),
      const SizedBox(width: 10),
      Text(
        // TAKILI namlu sayısı, kapasite DEĞİL. Yaylım da ondan hesaplanıyor:
        // boş yuvadan mermi çıkmadığı gibi hasar da çıkmaz.
        '${state.stats.laser.name} ×${state.stats.equippedLasers}',
        style: Palette.label().copyWith(color: Palette.ink),
      ),
      const Spacer(),
      Text(
        // Sözlükteki YAYLIM: takılı bütün lazerlerin tek seferde verdiği
        // toplam hasar, L5 sonrası. Kritik hariç — ekranda duran sayı bir
        // atışın tabanı, ortalaması değil.
        CombatGlossary.volley(state.stats).round().toString(),
        style: Palette.label().copyWith(color: Palette.hull),
      ),
    ],
  );
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.state});

  final ShipState state;

  @override
  Widget build(BuildContext context) {
    final locked = state.weaponTarget != 0;
    return Row(
      children: [
        Text(Metin.hedef(context.dil), style: Palette.label()),
        const SizedBox(width: 10),
        Text(
          locked ? '#${state.weaponTarget}' : '—',
          style: Palette.label().copyWith(
            color: locked ? Palette.shield : Palette.inkDim,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: state.firing
                ? Palette.hull.withValues(alpha: 0.22)
                : const Color(0x14FFFFFF),
          ),
          child: Text(
            state.firing ? Metin.ates(context.dil) : 'TAB · F',
            style: Palette.label(
              10,
            ).copyWith(color: state.firing ? Palette.hull : Palette.inkDim),
          ),
        ),
      ],
    );
  }
}

class _BoostPips extends StatelessWidget {
  const _BoostPips({required this.state});

  final ShipState state;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(Metin.itki(context.dil), style: Palette.label()),
      const SizedBox(width: 10),
      for (var i = 0; i < state.stats.maxBoostCharges; i++)
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Container(
            width: 26,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: const Color(0x22FFFFFF),
            ),
            // Dolmakta olan şarj kısmen dolu görünür: sayaç HUD'da da okunur.
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: i < state.boostCharges
                  ? 1
                  : i == state.boostCharges
                  ? state.rechargeFraction
                  : 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: Palette.boost,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Kare süresi — UI ve raster AYRI.
///
/// HUD'da kalıcı olarak duruyor, çünkü bu projenin hedefi "akıcı hissettiriyor"
/// değil ÖLÇÜLEBİLİR akıcılık. İki sayının ayrı durması da kasıtlı: UI uzunsa
/// suçlu Dart tarafı (tahsis, çöp toplama, simülasyon), raster uzunsa çizim
/// tarafı (çizim çağrısı, `saveLayer`, blur).
class _FrameStats extends StatelessWidget {
  const _FrameStats();

  /// Ölçüm satırını kuran yer.
  ///
  /// `FrameMonitor` sayıyor, cümleyi burası kuruyor — ölçer oyuncunun dilini
  /// bilmiyor ve bilmemeli.
  static String _satir(FrameMonitor frames, Dil dil) {
    final takilma = Metin.perfTakilma.bicim(dil, {
      'oran': bicim.yuzde(frames.jankRatio * 100, dil, basamak: 1),
    });
    final sahne = frames.sahne;
    if (sahne == null) return '${frames.olculer} · $takilma';
    return '${frames.olculer} · $takilma'
        ' · ${sahne.gemi} ${Metin.perfGemi(dil)}'
        ' · ${sahne.alien} ${Metin.perfAlien(dil)}'
        ' · ${sahne.alinan} ${Metin.perfAlindi(dil)}'
        ' · ${sahne.tuketilen} ${Metin.perfTuketildi(dil)}'
        ' · ${sahne.mermiSn} ${Metin.perfMermiSn(dil)}'
        ' · ${sahne.vurusSn} ${Metin.perfVurusSn(dil)}'
        ' · ${sahne.havada} ${Metin.perfHavada(dil)}';
  }

  @override
  Widget build(BuildContext context) {
    final frames = AppScope.of(context).frames;
    return ListenableBuilder(
      listenable: frames,
      builder: (context, _) => AbsorbPointer(
        child: Text(
          _satir(frames, context.dil),
          style: Palette.label(10).copyWith(
            color: frames.jankRatio > 0.02 ? Palette.hull : Palette.inkDim,
          ),
        ),
      ),
    );
  }
}

/// Oyuncunun elindeki hızlı eylemler.
///
/// Buradaki `HASAR` ve `ONAR` düğmeleri KALDIRILDI. Gerekçeleri "henüz bir
/// hasar kaynağı yok" idi; silahlar ve alienler geldiğinde o gerekçe düştü,
/// düğmeler kaldı. Kaldıkları sürece de sunucuda karşılıkları açık kalmak
/// zorundaydı — ve `ONAR`, ölü bir gemiyi tam sağlıkla geri getiren bir
/// komut. Düğmeyi arayüzden gizlemek yetmezdi, çünkü karşılığı PROTOKOLDE:
/// çerçeveyi elle yollamak da aynı işi görürdü. O yüzden ikisi birden gitti —
/// düğme buradan, komut da sunucudan (bkz. `Gateway.allowDebugCommands`).
class _TestControls extends StatelessWidget {
  const _TestControls();

  @override
  Widget build(BuildContext context) {
    final net = AppScope.of(context).client;
    return Row(
      children: [
        // İtki İSTEMCİDE tahmin edilir (gecikme gizlenir) ve aynı girdi
        // sunucuya gider; şarjı harcayan hakem orası.
        HudPill(
          key: hudBoostKey,
          label: Metin.itki(context.dil),
          glif: HudGlif.itki,
          color: Palette.boost,
          compact: true,
          onTap: () => net.ship?.requestBoost(),
        ),
      ],
    );
  }
}
