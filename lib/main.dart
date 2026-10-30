import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobilde YATAY ve bu bir tercih değil bir gereklilik: dikey ekranda görüş
  // alanı 0.6 zoom'da ~670 dünya birimine düşüyor, silah menzili ise 1400.
  // Oyuncu vurabildiği hedefin yarısını göremiyor.
  //
  // Burada YEREL uygulamanın gerçek kilidi kuruluyor; iOS/Android
  // manifestoları da yalnız yatay yönleri açıyor. Tarayıcıda karşılığı YOK —
  // mobil Safari yön kilidini hiç desteklemiyor — orada `RotateHint` perdesi
  // devreye giriyor.
  if (GameScreen.touchControls) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Cihazın dili BURADA okunuyor ve aşağı geçiriliyor: uygulamanın içinden
  // `PlatformDispatcher`'a uzanmak, dili testte kontrol edilemeyen bir girdi
  // yapardı (bkz. `DilSaglayici`).
  runApp(
    VoidspaceApp(cihazDili: PlatformDispatcher.instance.locale.languageCode),
  );
}
