import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Rank plakalarının ORTAK saati — yörünge noktalarını süren tek zaman.
///
/// **Neden tek.** Envanter kırk hücreye kadar çıkıyor. Her hücre kendi
/// [AnimationController]'ını taşısaydı kırk ayrı tik, kırk ayrı `setState` ve
/// kırk ayrı yeniden kurulan widget ağacı olurdu. Tek bir saat hepsini
/// sürüyor ve boyacılara `repaint` olarak veriliyor: widget ağacı HİÇ
/// yeniden kurulmuyor, yalnız katman yeniden boyanıyor.
///
/// **Neden abonelik seçmeli.** Saati yalnız yörüngesi olan plakalar okuyor
/// (S ve üstü). C ailesindeki bir eşya boyacısına `null` geçiyor ve o boyacı
/// saatin varlığından habersiz — hiç yeniden boyanmıyor.
///
/// Saat hangar ekranıyla birlikte doğup onunla ölüyor: menü kapalıyken tik
/// yok. Kalıcı bir tekil (singleton) olsaydı oyunun ömrü boyunca çalışırdı.
class RankSaati extends InheritedWidget {
  const RankSaati({required this.faz, required super.child, super.key});

  /// 0..1 arası bir tur. `null` — animasyon yok (test, golden, düşük güç).
  final ValueListenable<double>? faz;

  /// En yakın saat. Bulunamazsa `null`: plaka hareketsiz çiziliyor ve bu
  /// geçerli bir durum — golden testleri bilerek öyle koşuyor.
  static ValueListenable<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RankSaati>()?.faz;

  @override
  bool updateShouldNotify(RankSaati old) => old.faz != faz;
}

/// Saati MENÜ HIZINA kısar — 120 Hz'de 120 kez değil, 30 kez.
///
/// **Neden gerekti.** Gerçek cihazda ölçüldü (iPhone, 120 Hz): hangar açıkken
/// UI iş parçacığı neredeyse boş (p50 0,3 ms) ama GPU her karede 3,2 ms
/// çiziyordu. Yani Dart hiçbir şey yeniden kurmuyor, ekran aynı şeyi saniyede
/// 120 kez yeniden boyuyordu. Karşılaştırma çarpıcı: bütün oyun dünyası —
/// gemiler, alienler, mermiler, arka plan — 1,5 ms tutuyor, menü tek başına
/// 2,3 ms.
///
/// **Neden kare düşmüyorsa da değer.** 3,2 ms 8,33 ms'lik bütçenin altında,
/// yani hiçbir kare kaçmıyordu; kazanılan şey akıcılık değil PİL. Menüde
/// duran oyuncunun telefonunu ısıtan iş, altı saniyede bir tur atan birkaç
/// noktaydı.
///
/// **Neden görüntü değişmiyor.** Altı saniyelik bir turda 30 Hz, tur başına
/// 180 ayrı konum demek — nokta her karede ekranın binde ikisi kadar yol
/// alıyor. 120 Hz'in verdiği 720 konumun 540'ı aynı pikseli boyuyordu.
///
/// **Neden kaynağı yavaşlatmak değil.** [AnimationController] ekranın
/// tazeleme hızında tikliyor ve bu değiştirilemiyor; süresini uzatmak turu
/// yavaşlatırdı, animasyonu değil. Kısılan şey tik değil HABER: değer
/// basamağa yuvarlanıyor ve yalnız basamak değişince dinleyiciler uyarılıyor.
class KisikFaz extends ChangeNotifier implements ValueListenable<double> {
  KisikFaz(this._kaynak, {required double saniye, double hz = 30}) {
    _adim = (saniye * hz).round().clamp(1, 1 << 20);
    _deger = _yuvarla(_kaynak.value);
    _kaynak.addListener(_tik);
  }

  final ValueListenable<double> _kaynak;
  late final int _adim;
  late double _deger;

  double _yuvarla(double v) => (v * _adim).round() % _adim / _adim;

  void _tik() {
    final yeni = _yuvarla(_kaynak.value);
    if (yeni == _deger) return;
    _deger = yeni;
    notifyListeners();
  }

  @override
  double get value => _deger;

  @override
  void dispose() {
    _kaynak.removeListener(_tik);
    super.dispose();
  }
}
