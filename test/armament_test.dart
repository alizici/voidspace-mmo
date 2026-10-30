@Tags(['disi'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/armament.dart';
import 'package:voidspace3/game/art/bastion.dart';

/// Gemide kaç silahın GÖRÜNECEĞİ kuralı.
///
/// Kural tek satırlık görünüyor ve tam olarak bu yüzden test ediliyor: iki
/// ayrı yer onu okuyor (`ShipSwarm` topu çiziyor, `CombatLayer` mermiyi o
/// namludan doğuruyor) ve ikisi ayrışırsa ya olmayan bir silahtan mermi
/// çıkar ya da duran bir top ateş etmez.
void main() {
  group('donanım merdiveni', () {
    test('grup ya TAMAMEN açılır ya hiç', () {
      // Yuvalar simetrik geliyor. Yarım açılan bir çift, gemiyi tek kanadı
      // eksik gösterirdi — eski projede merdivenin var olma sebebi bu.
      const groups = [
        [2],
        [0, 1],
        [3, 4],
      ];
      expect(Armament.active(groups, 0), isEmpty);
      expect(Armament.active(groups, 1), [2]);
      expect(Armament.active(groups, 2), [2], reason: 'çift yarım açıldı');
      expect(Armament.active(groups, 3), [2, 0, 1]);
      expect(Armament.active(groups, 4), [2, 0, 1], reason: 'çift yarım');
      expect(Armament.active(groups, 5), [2, 0, 1, 3, 4]);
    });

    test('fazla lazerin karşılığı YOK — sanat tavanı belirler', () {
      // SS gövdede yedi lazer yuvası var ama Bastion sanatında beş kaide
      // çizili. Altıncı silah havada dururdu.
      expect(
        Armament.active(Bastion.mountGroups, 99),
        hasLength(Bastion.hardpoints.length),
      );
    });

    test('eksi ve sıfır silahsız gemi verir', () {
      expect(Armament.active(Bastion.mountGroups, 0), isEmpty);
      expect(Armament.active(Bastion.mountGroups, -3), isEmpty);
    });

    test('gruplar gövdenin BÜTÜN kaidelerini tam olarak bir kez kapsar', () {
      // Sessiz hata sınıfı: bir gruptan indeks düşerse o top HİÇ çizilmez ve
      // hiçbir şey kırmızıya dönmez — oyuncu yalnız "beşinci silahım yok"
      // der. İki grupta birden geçerse iki kez çizilir.
      final flat = [for (final group in Bastion.mountGroups) ...group]..sort();
      expect(flat, [
        for (var i = 0; i < Bastion.hardpoints.length; i++) i,
      ], reason: 'kaide grupları sanatla ayrışmış');
      expect(
        Armament.mountCount(Bastion.mountGroups),
        Bastion.hardpoints.length,
      );
    });

    test('açılan yuvalar SANATIN sınırları içinde', () {
      // `worldHardpoints[i]` ile indekslenen her sayı geçerli olmalı; aksi
      // hâlde çizim yolunda aralık dışı hatası.
      for (var lasers = 0; lasers <= 10; lasers++) {
        for (final mount in Bastion.activeHardpoints(lasers)) {
          expect(mount, inInclusiveRange(0, Bastion.hardpoints.length - 1));
        }
      }
    });
  });
}
