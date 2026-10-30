import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../auth/auth_screen.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../game/voidspace_game.dart';
import '../hangar/hangar_screen.dart';
import '../hud/galaksi_haritasi.dart';
import '../hud/hud_overlay.dart';
import '../net/net_client.dart';
import '../perf/frame_monitor.dart';
import '../ship/ship_bloc.dart';
import 'app_scope.dart';
import 'lifecycle.dart';
import 'palette.dart';
import 'prefs_dil_deposu.dart';
import 'prefs_token_store.dart';

class VoidspaceApp extends StatelessWidget {
  const VoidspaceApp({required this.cihazDili, super.key});

  /// Cihazın dil kodu — `main`den geliyor.
  ///
  /// Uygulamanın KENDİSİ `PlatformDispatcher`'a uzanmıyor: dil, testte
  /// verilebilir bir girdi olmalı. Üç dilin üçünü de bir widget testinde
  /// koşturabilmenin tek yolu bu.
  final String? cihazDili;

  @override
  Widget build(BuildContext context) => DilSaglayici(
    depo: PrefsDilDeposu(),
    cihazDili: cihazDili,
    // `Builder` şart: `MaterialApp`in `locale`i seçili dilden okunuyor ve o
    // dil bu widget'ın ÜSTÜNDE değil, hemen üstündeki [DilSaglayici]'da.
    child: Builder(
      builder: (context) => MaterialApp(
        title: 'Voidspace',
        debugShowCheckedModeBanner: false,
        // Oyunun metinleri `lib/dil/` altında; buradaki yerelleştirme
        // ÇERÇEVENİN kendi dizeleri için (metin seçme menüsü, erişilebilirlik
        // etiketleri). İkisi ayrı sözlük ama tek dil — `locale` ikisini
        // birbirine bağlıyor.
        locale: Locale(context.dil.kod),
        supportedLocales: [for (final d in Dil.values) Locale(d.kod)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(scaffoldBackgroundColor: Palette.space),
        home: const GameScreen(),
      ),
    ),
  );
}

/// Kompozisyon kökü: Bloc'un, ağ istemcisinin ve oyun döngüsünün ömrünü tutan
/// tek yer.
///
/// Hiçbiri diğerine SAHİP değil, hepsi burada bir araya geliyor — bu yüzden
/// `VoidspaceGame` bir testte sahte bir istemciyle, `ShipBloc` ise oyun
/// olmadan kurulabilir.
/// Klavye odağı OYUNA dönmeli mi.
///
/// Ayrı bir işlev, `actionFor` ile aynı sebeple (bkz. `lifecycle.dart`):
/// karar `setState`in içine gömülü olduğu sürece sınanamıyor, ve sınanmayan
/// bir odak kuralı sessizce bozuluyor — belirtisi de "klavye çalışmıyor"
/// gibi bulanık bir şikâyet oluyor.
///
/// Kural tek cümle: üstte bir perde varsa odak ORADA kalır. Hangarda ya da
/// galakside dokunan biri odağını oyuna kaptırsaydı o ekranların kendi
/// tuşları çalışmazdı.
bool odakOyunaDonmeli({required bool hangarAcik, required bool galaksiAcik}) =>
    !tamEkranMenuAcik(hangarAcik: hangarAcik, galaksiAcik: galaksiAcik);

/// Üstte OYUNU TAMAMEN ÖRTEN bir menü var mı.
///
/// Hangar da galaksi de `Positioned.fill` ve ikisinin de zemini opak
/// (`MenuSurface` düz `Palette.menuBg` boyuyor). Yani bu doğruyken oyunun
/// çizdiği hiçbir piksel ekrana ulaşmıyor.
///
/// Ayrı bir işlev çünkü iki ayrı kuralı besliyor — odak ve ÇİZİM — ve ikisi
/// de aynı gerçeğe dayanıyor: perde varsa altı görünmüyor.
bool tamEkranMenuAcik({
  required bool hangarAcik,
  required bool galaksiAcik,
}) => hangarAcik || galaksiAcik;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  /// Dokunmatik şema: telefon ve tablet.
  ///
  /// Tarayıcıdan açıldığında da doğru cevabı verir — `defaultTargetPlatform`
  /// web'de ANA CİHAZI bildiriyor, yani iPhone'daki Safari `iOS` döner.
  ///
  /// Tek yerde durması önemli: yön kilidi (`main`), oyunun otomatik ateşi ve
  /// HUD'ın denetim düzeni aynı cevabı okumak zorunda.
  static bool get touchControls =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final ShipBloc _shipBloc = ShipBloc();
  late final NetClient _net = NetClient(
    uri: NetClient.resolveUri(),
    tokens: PrefsTokenStore(),
  );
  late final VoidspaceGame _game = VoidspaceGame(
    net: _net,
    shipBloc: _shipBloc,
    touchControls: GameScreen.touchControls,
  );
  final FrameMonitor _frames = FrameMonitor();

  /// Hangar AÇIK mı.
  ///
  /// Oyun ağacı bu sırada SÖKÜLMÜYOR, üstü örtülüyor: sökmek bağlantıyı ve
  /// tahmin durumunu sıfırlar, yani hangara girip çıkmak sunucuda yeniden
  /// doğmak demek olurdu. Örtülen oyun tik almaya devam ediyor ve oyuncu
  /// dünyada kalıyor: hangar oyunun DIŞINDA bir ekran değil, içinde bir yer.
  bool _hangarOpen = false;

  /// Galaksi haritası AÇIK mı — hangarla aynı kural: oyun ağacı sökülmüyor.
  bool _galaksiOpen = false;

  /// OYUNUN KLAVYE ODAĞI.
  ///
  /// Flame tuşları yalnız `GameWidget`in odağı varken görüyor
  /// (`KeyboardEvents`). HUD'daki bir düğmeye, hangarın bir alanına ya da
  /// masaüstünde pencerenin boş bir yerine dokunmak odağı başka bir düğüme
  /// taşıyabiliyor ve o andan sonra gemi tuşlara cevap vermiyor — oyun
  /// donmuş gibi görünüyor ama yalnız sağır.
  ///
  /// Düğüm burada tutuluyor ki geri istenebilsin: perde kapanınca ve oyun
  /// alanına her dokunuşta odak geri alınıyor.
  final FocusNode _oyunOdagi = FocusNode(debugLabel: 'oyun');

  /// Odağı oyuna geri ver — kural [odakOyunaDonmeli]'de.
  void _odagiOyunaVer() {
    if (!odakOyunaDonmeli(hangarAcik: _hangarOpen, galaksiAcik: _galaksiOpen)) {
      return;
    }
    if (!_oyunOdagi.hasFocus) _oyunOdagi.requestFocus();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _frames.start();
    // Ölçer oyuna bağlanıyor: kare süresini üreten sahnenin yoğunluğu da
    // ölçümün parçası.
    _game.frames = _frames;
    // Kayıtlı belirteç varsa parola sorulmadan dünyaya dönülür.
    _net.restoreSession().whenComplete(_net.connect);
  }

  /// Uygulama arka plana alındığında bağlantıyı BİLEREK kapat, öne gelince
  /// yeniden kur.
  ///
  /// Bu bir mobil oyun ve iOS uygulamayı askıya alırken soket kaynaklarını
  /// geri topluyor: bağlantı zaten ölüyor, ama sessizce ve yarım. Hiçbir şey
  /// yapmamak, dönen oyuncuyu ölü bir soketle baş başa bırakıyordu.
  ///
  /// Hangi durumun ne anlama geldiği [actionFor]'da — orada, çünkü orası
  /// sınanabilir bir tablo. Buradaki hata tam olarak sınanmadığı için
  /// üretime çıkmıştı.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (actionFor(state)) {
      case LifecycleAction.suspend:
        _net.suspend();
      case LifecycleAction.resume:
        _net.resume();
      case LifecycleAction.ignore:
        break;
    }
  }

  @override
  void dispose() {
    _oyunOdagi.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _net.dispose();
    _frames.dispose();
    _shipBloc.close();
    super.dispose();
  }

  /// Ölçümün hangi ekranda alındığı — [FrameMonitor.baglam].
  ///
  /// Kurulumda değil `build`'de yazılıyor: menü açılıp kapanması `setState`
  /// ile geliyor ve ölçer bir sonraki kareden itibaren doğru damgayı
  /// taşımalı. Yazma bedelsiz (bir dize ataması) ve yalnız PERF_LOG açıkken
  /// okunuyor.
  String get _olcumBaglami => _hangarOpen
      ? 'hangar'
      : _galaksiOpen
      ? 'galaksi'
      : 'oyun';

  @override
  Widget build(BuildContext context) {
    _frames.baglam = _olcumBaglami;
    return _govde(context);
  }

  Widget _govde(BuildContext context) => AppScope(
    client: _net,
    frames: _frames,
    touchControls: GameScreen.touchControls,
    onCycleTarget: _game.cycleTarget,
    onOpenHangar: () => setState(() => _hangarOpen = true),
    onOpenGalaksi: () => setState(() => _galaksiOpen = true),
    child: BlocProvider.value(
      value: _shipBloc,
      // Kimlik doğrulanmadan oyun ağacı HİÇ KURULMAZ.
      //
      // Perdeyle örtmek yerine kurmamak kasıtlı — HUD perdesinde verilen
      // kararın aynısı: örtülen bir oyun hâlâ tik alır, girdi dinler ve
      // sunucuya bağlanmaya çalışır. Kimliği olmayan birinin dünyaya komut
      // yollayabildiği bir yol bırakmamak istiyoruz.
      child: StreamBuilder<void>(
        stream: _net.changes,
        builder: (context, _) => _net.isAuthenticated
            ? Scaffold(
                // HER DOKUNUŞTA odak oyuna dönüyor.
                //
                // HUD düğmeleri odak alabiliyor ve aldıklarında Flame tuşları
                // görmez oluyor: gemi sağırlaşıyor, oyuncu "klavye çalışmıyor"
                // diyor. `Listener` dokunuşu TÜKETMİYOR, yalnız duyuyor —
                // altındaki düğme işini yapmaya devam ediyor.
                body: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _odagiOyunaVer(),
                  child: Stack(
                    children: [
                      // PERDE VARKEN OYUN ÇİZİLMİYOR.
                      //
                      // Hangar açıkken telefon bütün dünyayı — yıldız alanı,
                      // gemiler, droidler, efektler — saniyede 60 kez
                      // çiziyordu ve tek bir pikseli bile görünmüyordu, çünkü
                      // üstündeki menü opak. Masaüstünde fark edilmiyordu;
                      // telefonda hangarın kasmasının en büyük tek sebebi
                      // buydu.
                      //
                      // `Opacity` ile, `pauseEngine` ile DEĞİL: ağ istemcisi
                      // oyun döngüsünden besleniyor (`net.update(dt)`),
                      // motoru durdurmak hangardayken bağlantıyı kör ederdi.
                      // `RenderOpacity` sıfırda çocuğu hiç boyamıyor ama
                      // yerleşimi ve tikleri sürdürüyor: dünya dönmeye devam
                      // ediyor, yalnız çizilmiyor. Birde ise katman
                      // açmıyor, yani perde kapalıyken bedeli sıfır.
                      Opacity(
                        opacity: tamEkranMenuAcik(
                              hangarAcik: _hangarOpen,
                              galaksiAcik: _galaksiOpen,
                            )
                            ? 0
                            : 1,
                        child: GameWidget<VoidspaceGame>(
                          game: _game,
                          // Odak DÜĞÜMÜ dışarıdan: perde kapandığında geri
                          // istenebilsin diye (bkz. [_odagiOyunaVer]).
                          focusNode: _oyunOdagi,
                          autofocus: true,
                          overlayBuilderMap: {
                            'hud': (_, _) => const HudOverlay(),
                          },
                          initialActiveOverlays: const ['hud'],
                        ),
                      ),
                      if (_hangarOpen)
                        Positioned.fill(
                          child: HangarScreen(
                            client: _net,
                            onClose: () {
                              setState(() => _hangarOpen = false);
                              _odagiOyunaVer();
                            },
                          ),
                        ),
                      if (_galaksiOpen)
                        Positioned.fill(
                          // Savaş puanı SUNUCUDAN: hangar yüklenmeden galaksi
                          // açılırsa sıfır gösteriyor ve her harita kilitli
                          // görünüyor — yanlış değil, henüz bilinmiyor.
                          child: GalaksiEkrani(
                            br: _net.hangar?.br ?? 0,
                            seviye: _net.hangar?.seviye,
                            // Nerede olduğu SUNUCUDAN: karşılamada ve her
                            // geçişte geliyor. Geçirmemek, haritada "buradasın"
                            // işaretinin hiç çıkmaması demekti.
                            konum: _net.harita,
                            onKapat: () {
                              setState(() => _galaksiOpen = false);
                              _odagiOyunaVer();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : AuthScreen(client: _net),
      ),
    ),
  );
}
