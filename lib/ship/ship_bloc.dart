import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../net/net_phase.dart';
import 'ship_event.dart';
import 'ship_state.dart';

/// HUD'a giden durumun tek sahibi.
///
/// **Artık hiçbir şey HESAPLAMIYOR.** Eski hâlinde kalkan yenilenmesi, itki
/// şarjı ve hasar emilimi buradaydı; hepsi `ShipSim`'e taşındı ve otoritesi
/// sunucuya geçti. Geriye kalan iş yansıtma — ve bu bir kayıp değil, kuralın
/// ağ sınırına uzanmış hâli:
///
/// > Bloc ayrık durumu tutar, Flame sürekli simülasyonu tutar,
/// > **sunucu ise gerçeği tutar.**
class ShipBloc extends Bloc<ShipEvent, ShipState> {
  ShipBloc([ShipStats stats = ShipStats.bastion])
    : super(ShipState.initial(stats)) {
    on<ShipSynced>(_onSynced);
  }

  /// GEMİNİN POZU — durumdan AYRI ve çok daha sık.
  ///
  /// `ShipState` saniyede on kez yayınlanıyor ve bu, çubuklar ile sayılar
  /// için doğru: kalkan yüzdesini 120 kez tazelemek okunan hiçbir şeyi
  /// değiştirmiyor, yalnız bütün HUD ağacını yeniden kuruyor.
  ///
  /// Ama minimap SÜREKLİ bir konum gösteriyor ve on adım saniyede, 120 Hz
  /// bir ekranda takılma olarak okunuyor — oyuncunun tarifi "sanki orası
  /// yavaş kalıyor" idi ve doğruydu.
  ///
  /// Çözüm hızı yükseltmek DEĞİL, kanalı ayırmak: poz her karede buraya
  /// yazılıyor, minimap boyacısı bunu `repaint` olarak dinliyor ve widget
  /// ağacı hiç yeniden kurulmuyor — yalnız küçük radar katmanı yeniden
  /// boyanıyor. Rank plakalarındaki desenin aynısı.
  ///
  /// **İki gerçek doğmuyor:** poz ile durum aynı kaynaktan (`net.ship.state`)
  /// aynı karede okunuyor; ayrılan şey doğruluk değil YAYIN SIKLIĞI. Poz
  /// hiçbir zaman durumdan eski olamaz, yalnız daha taze olabilir.
  /// `null` — HENÜZ POZ YAZILMADI, [ShipState] okunmalı.
  ///
  /// Sıfır bir poz DEĞİL: (0,0) dünyanın meşru bir köşesi. Başlangıç değeri
  /// sıfır olsaydı, ilk kare gelene kadar minimap gemiyi haritanın köşesinde
  /// gösterirdi — görsel referans tam olarak bunu yakaladı.
  final ValueNotifier<GemiPozu?> poz = ValueNotifier(null);

  @override
  Future<void> close() {
    poz.dispose();
    return super.close();
  }

  void _onSynced(ShipSynced event, Emitter<ShipState> emit) {
    final sim = event.state;
    // Gemi yoksa (el sıkışma bitmedi, bağlantı koptu) havuzları OLDUĞU GİBİ
    // bırakıyoruz. Sıfırlamak, geçici bir kopmada oyuncuya "öldün" demek
    // olurdu; sunucudaki gemi ise yaşamaya devam ediyor.
    emit(
      sim == null
          ? state.offline(phase: event.phase, message: event.message)
          : state.fromSim(
              sim,
              phase: event.phase,
              pingMs: event.pingMs,
              nearby: event.nearby,
              message: event.message,
              world: event.world,
              viewSize: event.viewSize,
              blips: event.blips,
              alienBlips: event.alienBlips,
            ),
    );
  }

  /// Bağlantı bekleyen kabuk durumu — testlerin ve HUD'ın başlangıç noktası.
  static ShipState connecting([ShipStats stats = ShipStats.bastion]) =>
      ShipState.initial(stats).offline(phase: NetPhase.connecting);
}

/// Minimap'in çizdiği tek şey: NEREDE ve HANGİ YÖNE.
///
/// Ayrı bir tip, kayıt (record) değil: `==` üzerinden gereksiz boyamayı
/// eleyebilmek için. Aynı pozla ikinci kez bildirim gelirse radar yeniden
/// çizilmiyor — duran bir gemi ekranda hiçbir iş çıkarmıyor.
@immutable
class GemiPozu {
  const GemiPozu(this.konum, this.aci);

  final Vec2 konum;
  final double aci;

  @override
  bool operator ==(Object other) =>
      other is GemiPozu && other.konum == konum && other.aci == aci;

  @override
  int get hashCode => Object.hash(konum, aci);
}
