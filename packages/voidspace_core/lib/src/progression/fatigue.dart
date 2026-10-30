import 'dart:math' as math;

import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import '../design/turetilenler.dart';

/// FARM SINIRI — 疲劳度 / azalan getiri.
///
/// **Neden gerekli.** Musluk sınırsızdı: alienler 8–20 saniyede doğuyor ve
/// bir bot sonsuza kadar öldürebilir. İki ayrı zararı var:
///
///  * **Enflasyon.** Toplam üretim toplam tüketimi aştığı anda para, para
///    olmaktan çıkıp farm edilen bir kaynağa dönüyor (云风'un tarifi).
///  * **Gerçek para.** Basılan NOVA, satılan NOVA ile rekabet ediyor. Kıt
///    parayı gerçek parayla satacaksan, onu basma hızını bilmek zorundasın.
///
/// **Neden kesme değil AZALAN GETİRİ.** DNF'ten gelen klasik yorgunluk
/// sistemi, kota dolunca ödülü SIFIRA indiriyor ve oyuncuyu oyundan
/// çıkarıyor. Buradaki eğri hiç sıfıra inmiyor: uzun oynayan oyuncu
/// cezalandırılmıyor, yalnız marjinal kazancı düşüyor. Cezalandırmak yerine
/// düzleştirmek, botun kârını da meşru oyuncunun keyfini de aynı anda
/// çözüyor — ve "iki saat sonra hiçbir şey kazanmıyorum" diye bir duvar
/// bırakmıyor.
///
/// **Neden çarpan, tavan değil.** Sert bir günlük tavan, tavanı bilen botun
/// tam tavana kadar farm edip durması demek. Sürekli bir eğride öyle bir
/// nokta yok.
/// KARAR 10.8 s1
class Fatigue {
  Fatigue({this.earned = 0, this.windowStartMillis = 0});

  /// Pencere içinde kazanılmış toplam kredi.
  int earned;

  /// Pencerenin başladığı an.
  int windowStartMillis;

  /// Pencere uzunluğu (ms) — bir saat.
  ///
  /// Gün değil saat: günlük pencere, gün dönümünde sıfırlanan ve o anda
  /// yığılan bir davranış üretiyor. Saatlik pencere hem daha yumuşak hem
  /// oyuncunun oturumuyla aynı ölçekte.
  static const int windowMillis = 60 * 60 * 1000;

  /// Getirinin düşmeye başladığı eşik (kredi).
  ///
  /// Sağlıklı bir oyuncunun saatlik kazancına yakın: Void Spore 400 kredi,
  /// ~10 saniyelik çevrimde saatte ~144.000. Eşik onun biraz üstünde, yani
  /// normal oynayan hiç fark etmiyor.
  static const int softCap = 200000;

  /// [rank] bandındaki bir oyuncunun eşiği.
  ///
  /// **Sabit eşik yirmi kademeli bir merdivende eşik değil DUVAR.** Ölçüldü:
  /// üst bantların saatlik geliri tabanın yüzlerce katı, yani dördüncü
  /// kademeden itibaren her oyuncu ilk dakikada eşiği geçip kalıcı olarak
  /// taban çarpanla oynardı. Yorgunluk, botu yavaşlatmayı bırakıp herkesi
  /// durdururdu.
  ///
  /// Ölçekleme gelirle AYNI üssü VE aynı merdiveni kullanıyor: eşiğin gelire
  /// oranı her bantta tam olarak sabit.
  ///
  /// **Ölçek GÖVDE KADEMESİYDİ ve rank ile kademe eşitken doğruydu.**
  /// Ayrıştıkları gün (yirmi rank, sekiz gövde) tanım gereği bozuldu: eşik
  /// sekiz basamakta zıplarken gelir yirmi rankta sürekli büyüyor, ve bir
  /// kademenin içinde gelir 2,5 rank kadar (≈2,5×) artarken eşik sabit
  /// kalıyordu. Oran 1,39'dan 1,03'e sallandı. Bandın kendi rankından okumak
  /// bunu tanım gereği imkânsız kılıyor.
  /// KARAR 13.4 s1
  static int softCapFor(int rank) => (softCap * _bantOlcegi(rank)).round();

  /// Yarılanma miktarı da aynı ölçekle büyüyor: eğrinin ŞEKLİ korunmalı,
  /// yalnız yeri kaymalı.
  /// KARAR 13.4 s1
  static int halfLifeFor(int rank) => (halfLife * _bantOlcegi(rank)).round();

  static double _bantOlcegi(int rank) => math
      .pow(
        TuretilenTablolar.rankCarpaniFor(
          rank.clamp(0, Turetilenler.rankSayisi - 1),
          TasarimGirdileri.rankArtisi,
        ),
        TasarimGirdileri.gelirUssu,
      )
      .toDouble();

  /// Eşikten sonra çarpanın yarıya indiği miktar.
  static const int halfLife = 200000;

  /// Kazancın en düşük çarpanı. Sıfır DEĞİL: hiçbir zaman "bedava oyna"
  /// noktasına gelinmemeli.
  static const double floor = 0.1;

  /// [now] anında geçerli kazanç çarpanı (0.1 – 1.0).
  /// [now] anında geçerli kazanç çarpanı (0.1 – 1.0).
  ///
  /// [rank] oyuncunun bulunduğu bandın rankı — eşiği ölçekleyen tek şey.
  /// Verilmezse taban bant varsayılıyor.
  double multiplierAt(int now, {int rank = 0}) {
    _roll(now);
    final cap = softCapFor(rank);
    if (earned <= cap) return 1;
    final over = (earned - cap) / halfLifeFor(rank);
    final value = math.pow(0.5, over).toDouble();
    return value < floor ? floor : value;
  }

  /// Kazanılan krediyi pencereye işler.
  void record(int credits, int now) {
    if (credits <= 0) return;
    _roll(now);
    earned += credits;
  }

  /// Pencere dolduysa sıfırlar.
  ///
  /// Kayan değil SABİT pencere: kayan pencere, imha başına zaman damgası
  /// tutmayı gerektirir ve hesap başına binlerce kayıt demektir. Sabit
  /// pencerenin sınırındaki sıçrama, azalan getiri eğrisi zaten yumuşak
  /// olduğu için hissedilmiyor.
  void _roll(int now) {
    if (now - windowStartMillis < windowMillis) return;
    earned = 0;
    windowStartMillis = now;
  }

  Map<String, Object?> toJson() => {
    'earned': earned,
    'windowStart': windowStartMillis,
  };

  static Fatigue fromJson(Map<String, Object?>? json) => Fatigue(
    earned: (json?['earned'] as num?)?.toInt() ?? 0,
    windowStartMillis: (json?['windowStart'] as num?)?.toInt() ?? 0,
  );
}
