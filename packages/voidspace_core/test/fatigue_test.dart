@Tags(['aralik', 'turetme'])
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// FARM SINIRI — sınırsız musluğun kapağı.
///
/// 10.8 · GÜNLÜK TAVAN VE YORGUNLUK. Yorgunluk bir ekonomi aracı gibi görünür
/// ama TEMPO aracı: "iki yıl" sözünün korunmasını sağlıyor. Sert duvar değil
/// azalan verim, ve eşik rankla ölçekleniyor — yoksa üst bantta eşik değil
/// duvar olurdu.
void main() {
  test('normal oynayan hiç FARK ETMİYOR', () {
    // KARAR 10.8 s1
    // Eşik, sağlıklı bir saatlik kazancın üstünde: sınırın varlığı meşru
    // oyuncuya değil bota dokunmalı.
    final f = Fatigue()..record(Fatigue.softCap ~/ 2, 0);
    expect(f.multiplierAt(0), 1.0);
  });

  test('eşiğin ÜSTÜNDE getiri azalıyor ama SIFIRLANMIYOR', () {
    // KARAR 10.8 s1
    // DNF'in klasik yorgunluk sistemi kota dolunca ödülü sıfırlıyor ve
    // oyuncuyu oyundan çıkarıyor. Buradaki eğri hiç sıfıra inmiyor —
    // "iki saat sonra hiçbir şey kazanmıyorum" diye bir duvar yok.
    final f = Fatigue()..record(Fatigue.softCap + Fatigue.halfLife, 0);
    expect(f.multiplierAt(0), closeTo(0.5, 0.01));

    final heavy = Fatigue()..record(Fatigue.softCap + Fatigue.halfLife * 50, 0);
    expect(heavy.multiplierAt(0), Fatigue.floor);
    expect(heavy.multiplierAt(0), greaterThan(0));
  });

  test('çarpan MONOTON azalıyor — farmladıkça artan bir nokta yok', () {
    // KARAR 10.8 s1
    var previous = 1.1;
    for (var earned = 0; earned < 2000000; earned += 50000) {
      final m = (Fatigue()..record(earned, 0)).multiplierAt(0);
      expect(m, lessThanOrEqualTo(previous));
      previous = m;
    }
  });

  test('pencere dolunca SIFIRLANIYOR', () {
    final f = Fatigue()..record(Fatigue.softCap * 10, 0);
    expect(f.multiplierAt(0), lessThan(1));
    expect(f.multiplierAt(Fatigue.windowMillis + 1), 1.0);
  });

  test('sınır DİSKE yazılıyor — yeniden başlatma sıfırlamıyor', () {
    // Sunucu yeniden başlayınca sıfırlanan bir sınır, sınır değildir.
    final hangar = Hangar(accountId: 'a');
    hangar.fatigue.record(Fatigue.softCap * 3, 1000);
    final back = Hangar.fromJson(hangar.toJson());
    expect(back.fatigue.earned, hangar.fatigue.earned);
    expect(back.fatigue.multiplierAt(1000), lessThan(1));
  });

  test('yumuşak tavan ve yarı ömür RANKLA ölçekleniyor', () {
    // KARAR 10.8 s1
    // Sabit eşik yirmi kademeli bir merdivende eşik değil DUVAR: üst bantın
    // saatlik geliri tabanın yüzlerce katı, yani her oyuncu ilk dakikada
    // eşiği geçip kalıcı olarak taban çarpanla oynardı. Eğrinin ŞEKLİ
    // korunmalı, yalnız yeri kaymalı — bu yüzden yarı ömür de ölçekleniyor.
    for (var r = 0; r < Turetilenler.rankSayisi; r++) {
      final olcek = math.pow(
        TuretilenTablolar.rankCarpaniFor(r, TasarimGirdileri.rankArtisi),
        TasarimGirdileri.gelirUssu,
      );
      expect(
        Fatigue.softCapFor(r),
        closeTo(Fatigue.softCap * olcek, Fatigue.softCap * olcek * 1e-6 + 1),
        reason: 'bant $r eşiği gelir eğrisinden koptu',
      );
      expect(
        Fatigue.halfLifeFor(r) / Fatigue.softCapFor(r),
        closeTo(Fatigue.halfLife / Fatigue.softCap, 1e-6),
        reason: 'bant $r eğrisinin şekli değişti',
      );
    }
    expect(Fatigue.softCapFor(19), greaterThan(Fatigue.softCapFor(0) * 100));
  });

  test(
    'TEMPO aracı: ilan edilen hızda oynayan görmüyor, on katı yavaşlıyor',
    () {
      // KARAR 10.8 s1
      // İki yıllık hedef günde 1,5 saat varsayımına dayanıyor. Bandın saatlik
      // hedefi kadar kazanan oyuncu yorgunluğa hiç değmiyor; on katını
      // toplayan yavaşlıyor ama DURMUYOR — taban verim sıfıra inmiyor.
      for (var r = 0; r < Turetilenler.rankSayisi; r++) {
        final saatlik = KaynakAkisi.saatlikGelirFor(r);
        final normal = Fatigue()..record(saatlik.round(), 0);
        expect(
          normal.multiplierAt(0, rank: r),
          1.0,
          reason: 'bant $r: hedef hızda oynayan cezalandırılıyor',
        );
        final yigan = Fatigue()..record((saatlik * 10).round(), 0);
        final carpan = yigan.multiplierAt(0, rank: r);
        expect(
          carpan,
          lessThan(0.5),
          reason: 'bant $r: on kat farm yavaşlamıyor',
        );
        expect(carpan, greaterThanOrEqualTo(Fatigue.floor));
        expect(carpan, greaterThan(0), reason: 'sert duvar olmuş');
      }
    },
  );
}
