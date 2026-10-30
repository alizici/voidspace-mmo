import 'package:flutter/widgets.dart';

import '../net/net_client.dart';
import '../perf/frame_monitor.dart';

/// Uygulama ömrü boyunca yaşayan tekilleri widget ağacına açar.
///
/// HUD'ın bir düğmesi sunucuya bir şey söylemek zorunda (bugün hata ayıklama
/// komutu, yarın "ateş et"), ve kare ölçümünü göstermek için ölçere erişmesi
/// gerekiyor. Alternatifler daha kötüydü: global bir locator test
/// edilebilirliği bitirir, Bloc üzerinden dolaştırmak ise durum katmanına
/// soket ve ölçüm sorumluluğu yükler.
///
/// Ağacın kendisi zaten bir bağımlılık grafiği — kullanmamak için sebep yok.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.client,
    required this.frames,
    required super.child,
    this.touchControls = false,
    this.onCycleTarget,
    this.onOpenHangar,
    this.onOpenGalaksi,
    super.key,
  });

  final NetClient client;

  /// Dokunmatik denetim şeması açık mı (telefon/tablet).
  ///
  /// Platformu HUD'ın kendisi SORMUYOR, kompozisyon kökü söylüyor. Sebep
  /// `devicePixelRatio` ile aynı: global platform durumuna widget içinden
  /// uzanmak, testte kontrol edilemeyen bir girdi yaratır — ve dokunmatik
  /// düzeni masaüstünde de sınayabilmek gerekiyor.
  final bool touchControls;

  /// "Sıradaki hedef" niyeti. Kökten gelen bir kapı, çünkü hedef seçimi oyun
  /// döngüsünde yaşıyor ve HUD'ın oyuna bakması yasak
  /// (bkz. `architecture_test.dart`). Kapıyı açan yer ikisini de kuran yer.
  final VoidCallback? onCycleTarget;

  /// Galaksi haritasını açar.
  ///
  /// Hangardan ayrı bir kapı: hangar geminin, galaksi DÜNYANIN ekranı. İkisini
  /// aynı düğmenin altına koymak, "nereye gideceğim" sorusunu "ne takacağım"
  /// sorusunun içine gömerdi.
  final VoidCallback? onOpenGalaksi;

  /// Hangarı aç. HUD'dan çağrılıyor; ekranın sahibi kompozisyon kökü.
  final VoidCallback? onOpenHangar;

  /// Kare süresi ölçer. HUD'ın buna erişmesi kasıtlı: "akıcı mı" sorusunun
  /// cevabı bir his değil, ekranda duran bir sayı olmalı.
  final FrameMonitor frames;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope ağaçta yok');
    return scope!;
  }

  // İstemci ÖRNEĞİ değişmez, içi değişir. Bağımlıları yeniden kurmanın anlamı
  // yok: durum akışı Bloc'tan geçiyor, buradan değil.
  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.client != client ||
      oldWidget.frames != frames ||
      oldWidget.touchControls != touchControls ||
      oldWidget.onCycleTarget != onCycleTarget ||
      oldWidget.onOpenHangar != onOpenHangar;
}
