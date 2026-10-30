import 'package:flutter/material.dart';

import '../app/palette.dart';
import '../dil/dil_kapsami.dart';
import '../dil/metin.dart';
import 'menu_theme.dart';

/// ONAY PENCERESİ — geri alınamaz bir işlemden önceki tek engel.
///
/// Yalnız "emin misin" diye sormuyor: NEYİ kaybedeceğini de yazıyor. Sayısız
/// bir onay penceresi refleksle geçiliyor ve o an hiçbir işe yaramıyor.
///
/// Ayrı bir dosya çünkü ilk kullanıcısı çevirme ama tek kullanıcısı o
/// kalmayacak: parçalama da geri alınamaz ve bugün sorusuz yapılıyor.
class OnayPenceresi extends StatelessWidget {
  const OnayPenceresi({
    required this.metrics,
    required this.baslik,
    required this.mesaj,
    required this.onayEtiketi,
    required this.onOnay,
    required this.onVazgec,
    super.key,
  });

  final MenuMetrics metrics;
  final String baslik;
  final String mesaj;
  final String onayEtiketi;
  final VoidCallback onOnay;
  final VoidCallback onVazgec;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final width = (m.width - m.gutter * 2).clamp(260.0, 420.0);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Dışarı dokunmak VAZGEÇMEK: kaçış yolu her zaman güvenli tarafa
        // çıkmalı, yıkıcı olana değil.
        onTap: onVazgec,
        child: ColoredBox(
          color: const Color(0xD8040710),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: width,
                padding: EdgeInsets.all(m.gutter),
                decoration: BoxDecoration(
                  color: const Color(0xFF121B2B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Palette.danger.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(baslik, style: MenuType.title(m)),
                    SizedBox(height: m.gap),
                    Text(mesaj, style: MenuType.label(color: Palette.faint)),
                    SizedBox(height: m.gutter),
                    Row(
                      children: [
                        // VAZGEÇ önce ve BASKIN: varsayılan güvenli seçim,
                        // ve refleksle basılan taraf o olmalı.
                        Expanded(
                          child: MenuButton(
                            key: onayVazgecKey,
                            label: Metin.vazgec(context.dil),
                            expand: true,
                            onTap: onVazgec,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MenuButton(
                            key: onayEtKey,
                            label: onayEtiketi,
                            filled: false,
                            color: Palette.danger,
                            expand: true,
                            onTap: onOnay,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Onay penceresinin düğmeleri.
const Key onayVazgecKey = Key('onay-vazgec');
const Key onayEtKey = Key('onay-et');
