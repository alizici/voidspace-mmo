import 'package:flutter/widgets.dart';

/// Bir yaşam döngüsü durumunun AĞ karşılığı.
enum LifecycleAction {
  /// Bağlantıyı bilerek kapat — işletim sistemi bizi askıya alıyor.
  suspend,

  /// Bağlantıyı geri kur.
  resume,

  /// Dokunma.
  ignore,
}

/// Yaşam döngüsü durumundan ağ kararına.
///
/// **Neden ayrı bir işlev.** Bu eşleme yanlıştı ve yanlış olduğu üretimde
/// anlaşıldı: karar `didChangeAppLifecycleState`'in içinde gömülü olduğu için
/// sınanamıyordu, sınanmadığı için de kimse "macOS'ta odak kaybı ne
/// gönderiyor" diye sormamıştı. Kararı dışarı almak onu bir tabloya çeviriyor
/// ve tablo sınanabiliyor.
///
/// **Kural: yalnız `paused` ve `detached` askıya alır.**
///
/// Flutter'ın kendi durum makinesi (`ServicesBinding._debugVerifyLifecycleChange`)
/// `hidden`'ı bir ÇATAL olarak tanımlıyor:
///
/// ```
/// hidden → paused    (gerçekten askıya alınıyoruz)
/// hidden → inactive  (geri dönüyoruz)
/// ```
///
/// Yani `hidden` tek başına "askıya alındık" demek DEĞİL. Üstelik Flutter ara
/// durumları kendisi üretiyor (`_generateStateTransitions`), yani gerçek bir
/// askıya almada `paused` her zaman geliyor — `hidden`'ı dinlemenin mobilde
/// kazandırdığı hiçbir şey yok.
///
/// Masaüstünde ise doğrudan zarar. macOS'ta ölçüldü: başka bir uygulamaya
/// geçmek `inactive → hidden` üretiyor ve `paused` HİÇ gelmiyor. `hidden`
/// askıya alsaydı her alt-tab, her pencere boyutlandırma, terminalin arkasına
/// düşen her an bağlantıyı koparırdı. Masaüstünde pencere örtülse de süreç
/// yaşıyor ve soketi kimse geri almıyor; odağı kaybetmiş bir MMO istemcisinin
/// dünyadan düşmesi için hiçbir sebep yok.
///
/// **iOS'ta da ölçüldü** (iPhone 17 Pro simülatörü). Orada `paused` gerçekten
/// geliyor ve askıya alma doğru yerde çalışıyor:
///
/// ```
/// arka plana : inactive → hidden → paused    (tek suspend)
/// öne gelme  : hidden → inactive → resumed   (tek resume)
/// ```
///
/// `hidden`'ın HER İKİ yönde de geçtiğine dikkat: eski kod onu askıya alma
/// saydığı için uygulama ÖNE GELİRKEN de bir `suspend()` çalışıyor ve az
/// sonra kurulacak bağlantı boşuna yıkılıyordu. macOS'ta bu bir kopma
/// döngüsüydü, iOS'ta her dönüşte fazladan bir yıkım.
LifecycleAction actionFor(AppLifecycleState state) => switch (state) {
  AppLifecycleState.paused ||
  AppLifecycleState.detached => LifecycleAction.suspend,
  AppLifecycleState.resumed => LifecycleAction.resume,
  // Geçici: gelen arama, bildirim merkezi, odak kaybı, örtülen pencere.
  AppLifecycleState.inactive ||
  AppLifecycleState.hidden => LifecycleAction.ignore,
};
