import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../net/ship_pose.dart';

/// Ekrandaki bir geminin DÜĞÜMÜ — çizicisi değil.
///
/// Gemiyi [ShipSwarm] çiziyor; bu bileşenden geriye üç iş kaldı: kameranın
/// takip edebileceği bir konum, ad etiketi, ve ileride vuruş testi.
///
/// Eskiden burada `Bastion.paint` çağrısı vardı ve ölçüldüğünde tek bir gemi
/// 8 ms GPU harcıyordu (120 Hz bütçesinin tamamı). Çizimin buradan çıkması
/// bir kalite kademesi değil, mimarinin kendisi: kare başına maliyet artık
/// gemi sayısından bağımsız.
class ShipComponent extends PositionComponent {
  ShipComponent({required this.isLocal, String? name})
    : _name = name,
      super(anchor: Anchor.center, priority: isLocal ? 5 : 4);

  final bool isLocal;
  final String? _name;

  /// Kamera bu gemiyi görüyor mu. Görmüyorsa alt ağaç (ad etiketi) hiç
  /// çizilmez — Flame görünürlük kırpması yapmaz, ekran dışındaki kırk metin
  /// de her karede boyanır.
  bool onScreen = true;

  TextComponent? _label;

  @override
  Future<void> onLoad() async {
    final name = _name;
    // Ad YALNIZ uzak gemilerde: kendi adını okumak için bir sebep yok ve
    // ekranın ortasında sürekli duran bir metin gürültüdür.
    if (name == null || isLocal) return;
    _label = TextComponent(
      text: name,
      anchor: Anchor.center,
      position: Vector2(0, -74),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 13,
          height: 1,
          letterSpacing: 0.6,
          color: Color(0xCCBFD8E8),
        ),
      ),
    );
    await add(_label!);
  }

  @override
  void renderTree(Canvas canvas) {
    if (!onScreen) return;
    super.renderTree(canvas);
  }

  void applyPose(ShipPose pose) {
    position.setValues(pose.x, pose.y);
    angle = pose.angle;
    // Ad etiketi gövdeyle dönmemeli: okunabilirlik dönüşten önce gelir.
    _label?.angle = -pose.angle;
  }
}
