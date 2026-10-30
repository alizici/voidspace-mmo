@Tags(['disi'])
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/void_portal.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// GEÇİDİN GÖRÜNEN SINIRI — çizilen halka ile girilebilen alan aynı mı.
///
/// Bu dosya bildirilen bir hatadan doğdu: oyuncu geçidin içinde dururken
/// "geçit menzilinde değilsin" alıyordu. Sebeplerinden biri buradaydı —
/// aksan halkası 1,12 R'de duruyor, sunucu ise 1,0 R'ye bakıyordu. Gördüğü
/// kapıya dokunan oyuncu, aslında dışındaydı.
void main() {
  test('halka tetikleme yarıçapını AŞMIYOR', () {
    // Kırılırsa: halka yeniden yalan söylüyor. Oyuncu için görünmez bir hata
    // — kapı orada duruyor, basıyor, çalışmıyor.
    expect(gecitHalkaCarpani, lessThanOrEqualTo(1.0));
  });

  test('nabız İÇERİ atıyor — dışarı atan aynı yalanı tekrarlar', () {
    // En geniş anında bile sınırı aşmamalı.
    for (var i = 0; i <= 32; i++) {
      final p = i / 32;
      final nabiz =
          gecitHalkaCarpani -
          gecitNabizGenligi * (1 + math.sin(p * 2 * math.pi * 2)) / 2;
      expect(nabiz, lessThanOrEqualTo(gecitHalkaCarpani));
      expect(nabiz, greaterThan(0.9), reason: 'nabız halkayı yutuyor');
    }
  });

  test('nabız GÖRÜNÜR — kapı canlı olduğunu söylemeli', () {
    // Ters yönde bir hata: sınırı aşmasın diye nabzı sıfırlamak, açık kapıyı
    // kilitliden ayırt edilemez yapardı.
    expect(gecitNabizGenligi, greaterThan(0));
    // Piksel cinsinden görünür olmalı: 140 yarıçapta en az bir piksel.
    expect(GecitAgi.yaricap * gecitNabizGenligi, greaterThan(1));
  });
}
