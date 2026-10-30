@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/auth/auth_screen.dart';
import 'package:voidspace3/net/net_client.dart';

/// HIZLI GİRİŞ TANIMI — `--dart-define=DEV_LOGIN=ad:parola,...`.
///
/// Kimlik bilgisi kodda DEĞİL, tanımsızsa düğme yok. Buradaki testler
/// ayrıcalığın varlığını değil SINIRINI koruyor: kapalıyken gerçekten kapalı,
/// bozuk tanımda sessizce kapalı.
void main() {
  test('tanımsızken düğme YOK', () {
    // Kırılırsa: üretim derlemesinde bir giriş kapısı beliriyor.
    expect(devLoginCozumle(''), isEmpty);
    expect(devLoginCozumle('   '), isEmpty);
  });

  test('bozuk tanım sessizce KAPALI — yanlış kimlikle denemekten iyi', () {
    for (final bozuk in ['cinar2', ':parola', 'cinar2:', 'a,b,c', ':::']) {
      expect(devLoginCozumle(bozuk), isEmpty, reason: '"$bozuk" kabul edildi');
    }
  });

  test('iki hesap çözülüyor', () {
    final g = devLoginCozumle('cinar2:gizli,cinar3:gizli2');
    expect(g, hasLength(2));
    expect(g[0].ad, 'cinar2');
    expect(g[1].ad, 'cinar3');
    expect(g[1].parola, 'gizli2');
  });

  test('ad kırpılıyor, PAROLA kırpılmıyor', () {
    // Parolanın başındaki boşluk parolanın parçası olabilir; kırpmak çalışan
    // bir parolayı sessizce bozardı.
    final g = devLoginCozumle(' cinar2 : bosluklu ');
    expect(g.single.ad, 'cinar2');
    expect(g.single.parola, ' bosluklu ');
  });

  test('parolada iki nokta olabilir — İLK ayraçta bölünüyor', () {
    final g = devLoginCozumle('ada:a:b:c');
    expect(g.single.ad, 'ada');
    expect(g.single.parola, 'a:b:c');
  });

  test('bozuk giriş sağlamları DÜŞÜRMÜYOR', () {
    final g = devLoginCozumle('bozuk,cinar3:gecerli');
    expect(g, hasLength(1));
    expect(g.single.ad, 'cinar3');
  });

  _alanTestleri();
}

/// Alanların DOLU açılması ayrı bir iş: tanım çözülüyor olabilir ama forma
/// hiç yazılmıyor olabilir. Test yapısı hata ayıklama kipinde koştuğu için
/// varsayılan tanım burada geçerli.
void _alanTestleri() {
  testWidgets('giriş formu ilk geliştirme hesabıyla DOLU açılıyor', (
    tester,
  ) async {
    final client = NetClient(uri: Uri.parse('ws://test'));
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(client: client)));
    await tester.pump();

    final alanlar = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(alanlar, isNotEmpty, reason: 'form hiç alan çizmedi');
    final dolu = alanlar
        .where((a) => (a.controller?.text ?? '').isNotEmpty)
        .length;
    expect(
      dolu,
      greaterThanOrEqualTo(2),
      reason: 'kullanıcı adı ve parola boş açıldı',
    );
  });
}
