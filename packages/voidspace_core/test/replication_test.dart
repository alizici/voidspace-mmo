@Tags(['disi'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Öncelikli replikasyon politikası.
///
/// Bu dosyanın koruduğu tek şey: **hiçbir entity ekrandan kaybolmamalı.**
/// Bant genişliği kazancı ikincil — geç güncellenen bir gemi kabul edilebilir,
/// kaybolan bir gemi değil.
void main() {
  const r = Protocol.interestRadius;
  double at(double distance) => distance * distance;

  test('YAKINDAKİ her tik gidiyor — kavga seyrelmiyor', () {
    // Öncelikli replikasyonun oyuncuya "takılıyor" diye görünmesinin tek
    // yolu, yakındakini seyreltmek olurdu.
    expect(Replication.intervalFor(at(100), r), 1);
    expect(Replication.intervalFor(at(r * 0.2), r), 1);
  });

  test('MARJ: her bant, atlamanın bedelinin en az İKİ KATINI kazanıyor', () {
    // Başa baş tek başına bıçak sırtı: ölçülen kısmi kayıt 7 bayt, tam kayıt
    // 14 — yani `aralık × 7 > 14` sınırı tam olarak aralık 2'de duruyor ve o
    // bandın gerçek akıştaki kazancı ~%0 (düz uçuşta hatta −%1, yani zarar).
    //
    // Bir bandın hakkını vermesi için iki kat marj gerekiyor: N=4 ve N=6
    // ölçümde −%50 ile −%71 arasında kazandırıyor, N=2 ve N=3 kazandırmıyor.
    // Bu eşik bugünkü tabloyu (1/4/6) tam olarak pinliyor.
    for (var d = 0.0; d <= r * 1.5; d += r / 60) {
      final interval = Replication.intervalFor(at(d), r);
      if (interval == 1) continue;
      expect(
        interval * Replication.typicalDeltaBytes,
        greaterThanOrEqualTo(2 * Replication.fullRecordBytes),
        reason: '$d uzaklıkta aralık $interval — kazanç marjı yok',
      );
    }
  });

  test('typicalDeltaBytes ÖLÇÜLEN değer — sezgiyle değiştirilemez', () {
    // Sabit bir zamanlar 5'ti ve bant politikasının bütün gerekçesi ondan
    // türüyordu; ölçüldüğünde 7,05 (düz uçuş) ile 7,94 (dönen+ateş) çıktı.
    // Yanlış girdi, doğru kararı yanlış aritmetikle savunuyordu.
    expect(
      Replication.typicalDeltaBytes,
      inInclusiveRange(7, 8),
      reason: 'ölçüm dışı bir değer — bant gerekçesi yeniden ölçülmeli',
    );
  });

  test('UZAKLAŞTIKÇA aralık büyüyor, monoton', () {
    var previous = 0;
    for (var d = 0.0; d < r; d += r / 40) {
      final interval = Replication.intervalFor(at(d), r);
      expect(interval, greaterThanOrEqualTo(previous));
      previous = interval;
    }
    expect(previous, greaterThan(1), reason: 'uzak da her tik gidiyor');
  });

  test('BEKLEYEN entity öne geçiyor — açlık yok', () {
    // Unreal'in "son replikasyondan beri geçen süreyle çarp" kuralı. Bu
    // çarpan olmadan uzaktaki bir gemi sonsuza kadar sıranın sonunda kalırdı.
    final nearFresh = Replication.priority(1, at(200), r);
    final farWaiting = Replication.priority(12, at(r * 0.9), r);
    expect(farWaiting, greaterThan(nearFresh), reason: 'uzak gemi aç kaldı');
  });

  test('aynı beklemede YAKIN olan önce', () {
    expect(
      Replication.priority(5, at(200), r),
      greaterThan(Replication.priority(5, at(r * 0.9), r)),
    );
  });

  test('SESSİZLİK TAVANI bütçeyi eziyor', () {
    // İstemci 30 tik sessizlikte entity'yi düşürüyor. Tavan onun belirgin
    // altında ve aşıldığında bütçe yok sayılıyor.
    expect(Replication.maxSilenceTicks, lessThan(30));
    expect(Replication.mustSend(Replication.maxSilenceTicks), isTrue);
    expect(Replication.mustSend(Replication.maxSilenceTicks - 1), isFalse);

    // En uzaktaki entity bile tavana ulaşınca aday.
    expect(
      Replication.isCandidate(Replication.maxSilenceTicks, at(r), r),
      isTrue,
    );
  });

  test('HİÇBİR uzaklıkta aralık sessizlik tavanını aşmıyor', () {
    // Aralık tavanı geçseydi entity, bütçe boşken bile istemcide düşerdi.
    for (var d = 0.0; d <= r * 2; d += r / 50) {
      expect(
        Replication.intervalFor(at(d), r),
        lessThan(Replication.maxSilenceTicks),
        reason: '$d uzaklıkta aralık tavanı aşıyor',
      );
    }
  });

  test('aralık dolmadan aday DEĞİL — filtre gerçekten eliyor', () {
    final far = at(r * 0.9);
    expect(Replication.isCandidate(1, far, r), isFalse);
    expect(
      Replication.isCandidate(Replication.intervalFor(far, r), far, r),
      isTrue,
    );
  });
}
