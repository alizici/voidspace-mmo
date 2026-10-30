import 'dart:math' as math;

import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import '../design/turetilenler.dart';
import '../domain/ship_stats.dart';
import 'damage_chain.dart';

/// SÖZLÜK — bu oyunun savaş terimleri.
///
/// Beş terim bütün alanlarda aynı anlama gelmek zorunda. Düşman canı bunlarla
/// türetilecek (alan 12), BR bunlarla hesaplanacak (09), denge bunlarla
/// ölçülecek (16).
///
/// **Bunlar sözlük maddesi değil, SÖZLEŞME.** "Boss 40 saniyede ölsün"
/// cümlesinin anlamı TTK'nın tanımına bağlı; tanım burada tek yerde durduğu
/// sürece 11, 12 ve 16 aynı şeyi konuşuyor demektir. İkinci bir TTK tanımı
/// yazıldığı gün üç alan sessizce ayrışır.
abstract final class CombatGlossary {
  /// **Yaylım** — takılı bütün lazerlerin tek seferde verdiği toplam hasar
  /// (L5 sonrası). Oyuncuya gösterilen birim.
  ///
  /// Kritik HARİÇ: ekranda duran sayı bir atışın tabanı, ortalaması değil.
  /// Beklenen değerli karşılığı [expectedVolley].
  /// KARAR 01.8 s1
  static double volley(ShipStats stats) =>
      _chain(stats, CritMode.rolled).amount;

  /// Yaylımın kritik BEKLENEN DEĞERLİ hâli — denge ve BR bunu kullanır.
  static double expectedVolley(ShipStats stats) =>
      _chain(stats, CritMode.expected).amount;

  /// **DPS** — yaylım ÷ atış aralığı. Saniyede verilen hasar.
  ///
  /// Alan 12 düşman canını, alan 09 BR saldırı kanalını bununla hesaplıyor.
  static double dps(ShipStats stats) =>
      volley(stats) / stats.laser.fireInterval;

  /// Kritik dâhil DPS. Tam donanımlı referansta `1.285 × 1,250 = 1.607`;
  /// yalnız lazer, roket [roketDps]'te. Sayı 04 · Gövde Tablosu'nda
  /// duruyor ve referans değiştikçe değişiyor — buradaki üçlü bir örnek,
  /// bir sözleşme değil.
  static double expectedDps(ShipStats stats) =>
      expectedVolley(stats) / stats.laser.fireInterval;

  /// **EHP** — etkin can: `(kalkan + gövde) ÷ (1 − azaltma)`.
  ///
  /// Ham hasar cinsinden dayanıklılık. Zırh kendi başına bir havuz değil,
  /// havuzların ÇARPANI — kalkanı da gövdeyi de aynı oranda büyütüyor.
  /// KARAR 01.8 s1
  static double ehp(ShipStats stats) {
    final pools = stats.maxShield + stats.maxHull;
    final mitigation = stats.totalMitigation;
    return mitigation >= 1 ? double.infinity : pools / (1 - mitigation);
  }

  /// **TTK** — öldürme süresi: hedefin EHP'si ÷ saldıranın DPS'i.
  ///
  /// Alan 11 harita zorluğunu, alan 16 denetimi bununla ölçüyor.
  /// KARAR 01.8 s1
  static double ttk(double targetEhp, double attackerDps) =>
      attackerDps <= 0 ? double.infinity : targetEhp / attackerDps;

  /// Bir gemi diğerini kaç saniyede indirir.
  static double ttkBetween(ShipStats attacker, ShipStats target) =>
      ttk(ehp(target), toplamDps(attacker));

  /// Kritiksiz toplam saldırı: lazer artı roket (18.2).
  static double toplamDps(ShipStats stats) =>
      dps(stats) + roketSalvo(stats) / TasarimGirdileri.roketAraligi;

  /// Roket salvosu, kritik zarla — zincir geminin, taban roketin (18.2).
  static double roketSalvo(ShipStats stats) =>
      stats.roketHasari <= 0 ? 0 : _roketZinciri(stats, CritMode.rolled);

  /// Roket salvosunun beklenen değeri, kritik dahil.
  static double expectedRoketSalvo(ShipStats stats) =>
      stats.roketHasari <= 0 ? 0 : _roketZinciri(stats, CritMode.expected);

  /// Roketin beklenen DPS'i: salvo bölü aralık.
  static double roketDps(ShipStats stats) =>
      expectedRoketSalvo(stats) / TasarimGirdileri.roketAraligi;

  /// Geminin toplam beklenen saldırısı: lazer artı roket (droid ayrı, 09.6).
  /// KARAR 18.2 s1
  static double saldiriDps(ShipStats stats) =>
      expectedDps(stats) + roketDps(stats);

  static double _roketZinciri(ShipStats stats, CritMode mode) =>
      DamageChain.resolve(
        baseDamage: stats.roketHasari,
        damageBonus: stats.damageBonus,
        conditionalBonus: stats.conditionalBonus,
        critChance: stats.critChance,
        critMultiplier: stats.critMultiplier,
        critMode: mode,
        flatDamage: stats.flatDamage,
      ).amount;

  /// Belirli bir can havuzunu indirmek için gereken YAYLIM sayısı.
  ///
  /// Alan 12'nin "iki yaylımda ölsün" cümlesinin sayıya döndüğü yer.
  static int volleysToKill(ShipStats attacker, double targetPool) {
    final v = volley(attacker);
    if (v <= 0) return -1;
    return (targetPool / v).ceil();
  }

  static DamageBreakdown _chain(ShipStats stats, CritMode mode) =>
      DamageChain.resolve(
        baseDamage: stats.baseVolleyDamage,
        damageBonus: stats.damageBonus,
        conditionalBonus: stats.conditionalBonus,
        critChance: stats.critChance,
        critMultiplier: stats.critMultiplier,
        critMode: mode,
        flatDamage: stats.flatDamage,
      );

  /// **SAVAŞ PUANI (BR)** — iki kanalı tek sayıda toplayan ölçü.
  ///
  /// `√(saldırı × dayanıklılık) × sistem × ölçek`
  ///
  /// **Neden geometrik ortalama, toplam değil.** Toplam olsaydı bütün
  /// bütçesini saldırıya yatıran bir build, yarı yarıya bölen bir build ile
  /// aynı puanı alırdı — oysa ilki her dövüşü ya çok hızlı kazanır ya anında
  /// kaybeder. Geometrik ortalama dengeyi ÖDÜLLENDİRİYOR: iki çarpandan biri
  /// sıfıra yaklaştığında sonuç da yaklaşıyor.
  ///
  /// **Neden dayanıklılık EHP değil EHP ÷ T.** İki kanal aynı birimde olmak
  /// zorunda. Kur ayrı bir girdi değil, hedef TTK'nın kendisi: T saniyede
  /// öldüren bir saldırı ile T saniye dayanan bir savunma tanım gereği eşit
  /// güçtedir.
  /// Droid grubu iki kanala da giriyor (09.6): saldırıya beklenen DPS'i
  /// ayakta kalma ile, dayanıklılığa EHP'sinin çeyreği ile. Katsayı bir
  /// olamaz: geometrik ortalamada iki kez sayılan şey baskın olur.
  /// KARAR 08.4 s1 · KARAR 09.1 s1 · KARAR 09.3 s1 · KARAR 09.5 s1 · KARAR 09.6 s1
  static double battleRating(ShipStats stats) {
    // Roket saldırının parçası (18.1): roketatar artık bonus değil silah,
    // bütçe payı DPS olarak buraya giriyor. Roket MERMİSİNİN çarpanı ise
    // mermininki gibi sayılmıyor. KARAR 18.5 s1
    final saldiri = saldiriDps(stats) + droidDps(stats);
    final dayaniklilik =
        (ehp(stats) +
            TasarimGirdileri.droidDayaniklilikKatsayisi * droidEhp(stats)) /
        TasarimGirdileri.referansTTK;
    if (saldiri <= 0 || dayaniklilik <= 0 || !dayaniklilik.isFinite) return 0;
    return math.sqrt(saldiri * dayaniklilik) *
        sistemCarpani(sistemPuaniOf(stats)) *
        TasarimGirdileri.brOlcegi;
  }

  /// Droid grubunun BEKLENEN DPS'i — kendi zinciri, ayakta kalma ile.
  ///
  /// Grup [DroidGrubu.sayi] gövdeli tek bir varlık gibi vuruyor; zincir aynı
  /// [DamageChain], yalnız girdileri droid kapsamından ve σ bağlaşımından.
  /// KARAR 09.6 s1
  static double droidDps(ShipStats stats) {
    final d = stats.droidler;
    if (!d.var_) return 0;
    final yaylim = DamageChain.resolve(
      baseDamage: d.tabanHasar,
      damageBonus: d.damageBonus,
      critChance: d.critChance,
      critMultiplier: d.critMultiplier,
    ).amount;
    return yaylim / d.atisAraligi * d.ayaktaKalma;
  }

  /// Droid grubunun etkin canı — havuz ÷ (1 − zırh azaltması), geminin
  /// K'sıyla. Sıyırma yok: droid kaçınmıyor (02.7, kapsam).
  /// KARAR 09.6 s1
  static double droidEhp(ShipStats stats) {
    final d = stats.droidler;
    if (!d.var_) return 0;
    return d.havuz / (1 - SavunmaEgrileri.doyum(d.armor, Turetilenler.kZirh));
  }

  /// Bir build'in SİSTEM puanı — donanımın oran statlarından.
  ///
  /// Gövdenin taban hızı girmiyor: puan eşyanın verdiği yüzde, referans
  /// gövdeye göre ölçülen fark değil. Uzun süre bu yordam yoktu ve savaş
  /// puanı sistem kanalını hiç görmüyordu — formül vardı, çağıran yoktu;
  /// yalnız menzil ya da hız veren bir parça hangarda yükseltme sayılmıyordu.
  /// KARAR 09.5 s1
  static double sistemPuaniOf(ShipStats s) => sistemPuani(
    menzilYuzde: s.rangeBonus * 100,
    hizYuzde: s.speedBonus * 100,
    itkiYuzde: s.boostRechargeBonus * 100,
  );

  /// SİSTEM kanalının çarpanı — tavanla sınırlı.
  ///
  /// Tavan zorunlu çünkü sistem statları hem saldırıyı hem dayanıklılığı
  /// birden büyütüyor: geometrik ortalamanın İÇİNDE iki kez sayılıyorlar.
  /// Sınırsız bırakılırsa tek bir kanal ötekileri ele geçirir.
  /// KARAR 09.5 s1
  static double sistemCarpani(double sistemPuani) =>
      1 + sistemPuani.clamp(0, TasarimGirdileri.sistemTavani) / 100;

  /// Bir build'in SİSTEM puanı — oran statlarının katsayılı toplamı.
  ///
  /// Menzil en değerlisi: hedefte kalma süresini uzatıyor, hem saldırıya hem
  /// kaçışa yarıyor. ∂DPS/∂menzil = 0 olduğu için saldırı kanalında
  /// fiyatlanamıyor — bu kanal onun yeri.
  ///
  /// Savaş puanı bunu [sistemPuaniOf] üzerinden, donanımın oranlarından
  /// alıyor; buradaki yüzdeler tablo örnekleri ve testler için.
  /// KARAR 09.5 s1
  static double sistemPuani({
    double menzilYuzde = 0,
    double hizYuzde = 0,
    double itkiYuzde = 0,
  }) =>
      menzilYuzde * TasarimGirdileri.sistemKatsayisiMenzil +
      hizYuzde * TasarimGirdileri.sistemKatsayisiHiz +
      itkiYuzde * TasarimGirdileri.sistemKatsayisiItki;

  // ══ UNVAN MERDİVENİ — alan 10 ══════════════════════════════════════

  /// Merdivenin TABANI — referans build'in savaş puanı, ilk unvanın eşiği.
  ///
  /// [TasarimGirdileri.brOlcegi] tam olarak bunu yuvarlak bir sayıya oturtmak
  /// için çözülmüştü; ölçek dengeye karışmıyor, yalnız okunurluğa.
  /// KARAR 09.7 s1
  /// BR tabanı: ilk unvanın eşiği (10.3).
  ///
  /// Referansın kendisi burada okunmuyor: dolu referans büyüme katmanında
  /// yaşıyor ve savaş katmanı onu okuyamaz. Ölçek K, referansın kanal gücünü
  /// (sistem çarpansız √(A·D)) tam bu sayıya oturtacak şekilde çözülüyor
  /// (09.7); `referans_cozumu_test` bağı sınıyor.
  /// KARAR 09.7 s1
  static double get brTabani => TasarimGirdileri.ilkUnvanEsigi;

  /// Referans build'in [rank] rankındaki savaş puanı — merdivenin BİR basamağı.
  ///
  /// Tek çarpan: `rankÇarpanı`. Gövde kademesi AYRI bir çarpan değil, çünkü
  /// statlar TOPLANIYOR — `hull.baseShield + stat`, `hull.baseHull + stat`.
  /// Bir kademe yukarı çıkan oyuncunun hem gövdesi hem eşyaları aynı çarpanla
  /// büyüyor, ama toplamları da o çarpanla büyüyor; çarpımıyla değil.
  ///
  /// Ölçüm bunu doğruluyor: yalnız gövdeyi ×4,324 büyütmek BR'yi ×2,079
  /// yapıyor — tam olarak √4,324, çünkü `BR = √(A × D)` içinde yalnız `D`
  /// ölçeklendi. İki kanal birden ölçeklendiğinde çarpan ×4,324 oluyor.
  static double referansBrFor(int rank) =>
      brTabani *
      TuretilenTablolar.rankCarpaniFor(rank, TasarimGirdileri.rankArtisi);

  /// Sistemin üretebildiği EN BÜYÜK savaş puanı.
  ///
  /// Unvan merdiveninin tavanı bu: son basamağın eşiği buna eşit olmak
  /// zorunda, yoksa merdivende ya ulaşılamaz basamak ya boş üst uç kalır.
  ///
  /// En üst rankın referans BR'si, sistem tavanıyla çarpılmış. Hiçbiri elle
  /// yazılmıyor.
  ///
  /// **Düzeltme (alan 11).** Önceki hâli gövde merdiveniyle rank merdivenini
  /// ÇARPIYORDU. İkisi bugünkü kurulumda birebir aynı liste
  /// (`[1,000 · 1,442 · 2,079 · 2,998 · 4,324]`), yani tavan ×4,324 fazla
  /// çıkıyordu: 84.126, ulaşılabilir en yüksek BR ise 19.457. Sonuç, 120
  /// unvanın üst 56'sının hiçbir build ile alınamaması — belgenin
  /// "ulaşılamaz basamak" diye adlandırdığı hatanın tam kendisi.
  /// KARAR 10.3 s1
  /// BR tavanı: son rankın kanal gücü, sistem tavanında.
  static double get brTavani =>
      referansBrFor(Turetilenler.rankSayisi - 1) *
      sistemCarpani(TasarimGirdileri.sistemTavani);

  /// Unvan başına BR çarpanı — tavan ile tabandan çözülüyor.
  static double get unvanAdimi => math
      .pow(brTavani / brTabani, 1 / (TasarimGirdileri.unvanSayisi - 1))
      .toDouble();

  /// [indeks] numaralı unvanın BR eşiği.
  ///
  /// Basamaklar EŞİT ORANLI, eşit aralıklı değil: her unvan bir öncekinin
  /// sabit katı. Doğrusal bölmek üst uçta yüzlerce basamağı bir araya
  /// sıkıştırırdı — BR üstel büyüyor, yani oyuncunun son yüz saatinde tek bir
  /// unvan atlaması gerekirdi.
  /// KARAR 10.3 s1
  /// KARAR 05.6 s1 — unvan stat vermez, yalnız BR eşiği.
  static double unvanEsigi(int indeks) {
    if (indeks < 0 || indeks >= TasarimGirdileri.unvanSayisi) {
      throw ArgumentError.value(indeks, 'indeks', 'aralık dışı');
    }
    return brTabani * math.pow(unvanAdimi, indeks);
  }

  /// [br] savaş puanının denk geldiği unvan indeksi.
  static int unvanIndeksi(double br) {
    if (br <= brTabani) return 0;
    // Epsilon tam EŞİKTE duran oyuncu için. `unvanEsigi(i)`'yi geri çevirmek
    // `log`/`pow` çiftinden geçiyor ve sonuç 49,999999996 gibi çıkabiliyor;
    // `floor` onu bir basamak aşağı atardı. Yani eşiği tam tutturan oyuncu
    // unvanını ALMAZDI — ve bu en çok tavanda görünür, çünkü orada bir üst
    // basamak yok.
    const pay = 1e-9;
    final i = (math.log(br / brTabani) / math.log(unvanAdimi) + pay).floor();
    return i.clamp(0, TasarimGirdileri.unvanSayisi - 1);
  }
}
