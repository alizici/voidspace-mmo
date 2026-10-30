import 'dart:async';

import 'package:flutter/widgets.dart';

import 'dil.dart';
import 'dil_deposu.dart';

/// Seçili dili widget ağacına açar.
///
/// `AppScope` ile aynı gerekçeyle bir `InheritedWidget`: ağaç zaten bir
/// bağımlılık grafiği. Ayrı bir tekil (singleton) kurmak, dili testte
/// değiştirilemez ve iki dili yan yana sınayamaz hâle getirirdi.
///
/// Dil DEĞİŞTİĞİNDE ağacın yeniden kurulması gerekiyor ve bu kasıtlı: metin
/// yüzlerce widget'ın içinde, ve bir sonraki kareye kadar eski dilde duran
/// tek bir etiket bile "dil değişmedi" hissi veriyor.
class DilKapsami extends InheritedWidget {
  const DilKapsami({
    required this.dil,
    required this.degistir,
    required super.child,
    super.key,
  });

  final Dil dil;

  /// Dili değiştirir ve tercihi diske yazar.
  final ValueChanged<Dil> degistir;

  /// Ağaçtaki kapsam — yoksa TÜRKÇE.
  ///
  /// Fırlatmıyor ve bu bilinçli. Uygulama kökü kapsamı her zaman kuruyor
  /// ([DilSaglayici]); kapsamsız kalan tek yer bir widget'ı tek başına kuran
  /// TEST. Orada patlamak, dille hiç işi olmayan yüzlerce testi bir kurulum
  /// satırı eklemeye zorlardı — ve o satır, testin sınadığı şeyi anlatmıyor.
  ///
  /// Düşülen dil Türkçe: tasarım belgelerinin ve çekirdek etiketlerin kanonik
  /// dili o. Kökün kapsamı gerçekten kurduğunu `test/dil_test.dart` sınıyor —
  /// buradaki hoşgörü, oradaki kilidin karşılığı.
  static DilKapsami of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DilKapsami>() ??
      DilKapsami(
        dil: Dil.turkce,
        degistir: (_) {},
        child: const SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(DilKapsami oldWidget) => oldWidget.dil != dil;
}

/// `Metin.kapat(context.dil)` — çağrı yerinde tek kelime.
extension DilOkuma on BuildContext {
  Dil get dil => DilKapsami.of(this).dil;
}

/// Dili ÇÖZEN ve tutan kök.
///
/// Sıra kasıtlı: kayıtlı tercih → cihazın dili → [Dil.varsayilan]. Cihaz dili
/// DIŞARIDAN geliyor, `PlatformDispatcher`'a buradan uzanılmıyor —
/// `GameScreen.touchControls` ile aynı kural: global platform durumuna widget
/// içinden uzanmak, testte kontrol edilemeyen bir girdi yaratır.
///
/// İlk kare kayıtlı tercih OKUNMADAN çiziliyor (disk erişimi asenkron) ve
/// bu bilerek: açılışı bir kumbara okumasına bağlamak, oyunu her başlatışta
/// boş bir ekranla başlatırdı. Kayıt gelince ağaç bir kez yeniden kuruluyor.
class DilSaglayici extends StatefulWidget {
  const DilSaglayici({
    required this.depo,
    required this.cihazDili,
    required this.child,
    super.key,
  });

  final DilDeposu depo;

  /// Cihazın dil kodu (`tr`, `en-US`, …). Tanınmazsa [Dil.varsayilan].
  final String? cihazDili;

  final Widget child;

  @override
  State<DilSaglayici> createState() => _DilSaglayiciState();
}

class _DilSaglayiciState extends State<DilSaglayici> {
  late Dil _dil = Dil.cozumle(widget.cihazDili);

  @override
  void initState() {
    super.initState();
    unawaited(_kayittanYukle());
  }

  Future<void> _kayittanYukle() async {
    final kod = await widget.depo.oku();
    if (kod == null || !mounted) return;
    final kayitli = Dil.cozumle(kod);
    if (kayitli != _dil) setState(() => _dil = kayitli);
  }

  void _degistir(Dil yeni) {
    if (yeni == _dil) return;
    setState(() => _dil = yeni);
    unawaited(widget.depo.yaz(yeni.kod));
  }

  @override
  Widget build(BuildContext context) =>
      DilKapsami(dil: _dil, degistir: _degistir, child: widget.child);
}
