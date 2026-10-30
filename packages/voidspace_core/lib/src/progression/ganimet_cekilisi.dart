import 'dart:math' as math;

import '../design/prd.dart';
import '../world/dusman.dart';
import 'budget.dart';
import 'catalogue.dart';
import 'ganimet.dart';
import 'item.dart';

/// Bir öldürmeden çıkan ganimet.
class GanimetSonucu {
  const GanimetSonucu({required this.specId, required this.instanceId});

  /// Düşen eşyanın katalog kimliği.
  final String specId;

  /// Üretilen örneğin kimliği. Kalite bundan TÜRÜYOR — saklanmıyor.
  final String instanceId;
}

/// Bir öldürmenin TOPLAM ganimeti: eşyalar ve malzeme.
///
/// İkisi ayrı alanda, çünkü alan 14 ritimlerini bilerek ayırmış — *"Malzeme
/// her öldürmede (sürekli), eşya seyrek (nadir ama beklenebilir)."* Tek bir
/// listede toplamak, çağıranı "bu ne düştü" diye ayıklamaya zorlardı.
class GanimetPayi {
  const GanimetPayi({required this.esyalar, required this.malzeme});

  final List<GanimetSonucu> esyalar;

  /// Düşen malzeme adedi. Rankı bandın rankı.
  final int malzeme;

  bool get bos => esyalar.isEmpty && malzeme <= 0;
}

/// GANİMET ÇEKİLİŞİ — alan 14'ün sayılarını bir öldürmeye uygulayan taraf.
///
/// Alan 14 arzı ilan etti (kaç eşya, hangi rankta, hangi olasılıkla);
/// burası o ilanı tek bir öldürmeye çeviriyor. Sayı YOK: hepsi [Ganimet]'ten
/// ve tepe tablodan geliyor, bu dosya yalnız sırayı kuruyor.
///
/// **Saf ve sunucudan bağımsız.** Zar dışarıdan veriliyor, kimlik dışarıdan
/// veriliyor; test aynı tohumla aynı sonucu alıyor ve `Zone`'a ihtiyaç yok.
abstract final class GanimetCekilisi {
  /// [sinif] öldürüldüğünde [hasarPayi] kadar katkısı olan bir oyuncunun
  /// aldığı ganimet.
  ///
  /// **Şans HASAR PAYIYLA ölçekleniyor ve bu bir tercih değil, mevcut sayının
  /// sonucu.** Alan 14 "kişisel ganimet" diyor ama tepe tabloda bir hasar
  /// eşiği yok — ve gerekmiyor: kredi zaten hasar payına bölünüyor
  /// (`ThreatTable.split`), aynı payı şansa uygulamak hem sahipliği hem
  /// korunumu birden çözüyor. %10 hasar veren şansın %10'unu alıyor, bir
  /// öldürmeden beklenen toplam eşya grup büyüklüğünden BAĞIMSIZ kalıyor.
  ///
  /// Eşik koymak iki şeyi birden bozardı: eşiğin altındakinin katkısı
  /// kaybolur (ekonomi sızdırır), üstündekilerin her biri tam şans alır
  /// (ekonomi para basar).
  ///
  /// [rank] bandın rankı, [prd] oyuncunun üst-rank acıma sayacı, [kimlikUret]
  /// aday örnek kimliği üreten sayaç — kalite kimlikten türediği için boss'un
  /// kalite tabanı ancak kimlik seçilerek tutturulabiliyor.
  /// KARAR 14.1 s1
  static GanimetPayi cek({
    required DusmanSinifi sinif,
    required double hasarPayi,
    required int rank,
    required PrdRoller prd,
    required math.Random zar,
    required String Function(int deneme) kimlikUret,
  }) {
    // MALZEME her öldürmede ve zamanla orantılı — eşyadan ayrı bir ritim.
    // Payla ölçekleniyor, eşyayla aynı gerekçe: bir öldürmeden çıkan toplam
    // malzeme grup büyüklüğünden bağımsız.
    final malzeme = _adet(Ganimet.malzemeFor(sinif) * hasarPayi, zar);

    final beklenen = Ganimet.esyaSansiFor(sinif) * hasarPayi;
    final adet = _adet(beklenen, zar);
    // Filo AYRI kalem (14.3): droid eşyası kendi zarını atıyor, gövde
    // kalemine karışmıyor; gövde zarı yalnız gövde yuvalarının tiplerini
    // çeker.
    final droidAdet = _adet(Ganimet.droidEsyaSansiFor(sinif) * hasarPayi, zar);
    if (adet == 0 && droidAdet == 0) {
      return GanimetPayi(esyalar: const [], malzeme: malzeme);
    }

    final sonuc = <GanimetSonucu>[];
    for (var i = 0; i < adet + droidAdet; i++) {
      final ganimetRanki = _rankCek(sinif: sinif, prd: prd, zar: zar);
      final spec = _specSec(
        rank: rank,
        ganimetRanki: ganimetRanki,
        zar: zar,
        droid: i >= adet,
      );
      if (spec == null) continue;
      sonuc.add(
        GanimetSonucu(
          specId: spec.id,
          instanceId: _kimlikSec(
            sinif: sinif,
            tier: spec.tier,
            kimlikUret: (d) => kimlikUret(sonuc.length * 64 + d),
          ),
        ),
      );
    }
    return GanimetPayi(esyalar: sonuc, malzeme: malzeme);
  }

  /// Beklenen sayıdan ADET.
  ///
  /// Boss'unki bir olasılık değil, bir SAYI (`bossEsyaSayisi`), ve hasar
  /// payıyla çarpılınca kesirli oluyor. Tam kısmı garanti, kesirli kısmı zar:
  /// tek bir oyuncu boss'un tamamını yaptığında tam üç eşya, yarısını
  /// yaptığında ortalama bir buçuk.
  static int _adet(double beklenen, math.Random zar) {
    final tam = beklenen.floor();
    final artik = beklenen - tam;
    return tam + (zar.nextDouble() < artik ? 1 : 0);
  }

  /// Alt · bant · üst çekilişi.
  ///
  /// Üst rank tek PRD'li sonuç: acıma sistemi yalnız OLAY'a uygulanıyor, çünkü
  /// seri kırıcının işi nadir olanı beklenebilir kılmak. Alt ve bant zaten
  /// sık, onlara PRD koymak sistemi bağımsız zardan ayırt edilemez yapardı.
  ///
  /// **Boss'ta PRD YOK** — [Ganimet.bossUstRankSansi] doğrudan zar. Boss iki
  /// saatte bir doğuyor ve kendisi bir seri kırıcı; üstüne PRD koymak
  /// nadirliğin iki kez telafi edilmesi olurdu.
  static GanimetRanki _rankCek({
    required DusmanSinifi sinif,
    required PrdRoller prd,
    required math.Random zar,
  }) {
    if (sinif == DusmanSinifi.boss) {
      return zar.nextDouble() < Ganimet.bossUstRankSansi
          ? GanimetRanki.ust
          : GanimetRanki.bant;
    }
    if (prd.roll(zar)) return GanimetRanki.ust;
    // Üst çıkmadı: kalan pay alt ile bant arasında, kendi oranlarında.
    final altPayi =
        Ganimet.sansFor(GanimetRanki.alt) /
        (Ganimet.sansFor(GanimetRanki.alt) +
            Ganimet.sansFor(GanimetRanki.bant));
    return zar.nextDouble() < altPayi ? GanimetRanki.alt : GanimetRanki.bant;
  }

  /// Rank + ganimet kademesi → katalog kaydı.
  ///
  /// Yuva tipi düz zar: hangi yuvanın düşeceği bir denge kararı değil, ve
  /// ağırlıklandırmak yuva sayısını ikinci bir yere yazmak olurdu.
  static ItemSpec? _specSec({
    required int rank,
    required GanimetRanki ganimetRanki,
    required math.Random zar,
    required bool droid,
  }) {
    final hedef =
        (rank +
                switch (ganimetRanki) {
                  GanimetRanki.alt => -1,
                  GanimetRanki.bant => 0,
                  GanimetRanki.ust => 1,
                })
            .clamp(0, ItemTier.values.length - 1);
    final tier = ItemTier.values[hedef];
    final adaylar = [
      for (final s in Catalogue.items)
        if (s.tier == tier && (s.slot == SlotType.droid) == droid) s,
    ];
    if (adaylar.isEmpty) return null;
    return adaylar[zar.nextInt(adaylar.length)];
  }

  /// Kalite tabanını tutturan örnek kimliği.
  ///
  /// Kalite `instanceId`'nin karmasından türüyor ve HİÇBİR YERDE saklanmıyor —
  /// aynı eşya her yüklemede aynı rolü taşısın diye (bkz. `ItemBudget`). Boss
  /// ganimetinin [Ganimet.bossKaliteAltSiniri] tabanı bu yüzden bir alan
  /// eklenerek değil, kimlik SEÇİLEREK tutturuluyor: taban altında kalan
  /// kimlik atlanıyor.
  ///
  /// Ucuz: taban 0,85, kalite aralığı [0,70 · 1,00], yani adayların yaklaşık
  /// yarısı geçiyor — ortalama iki deneme. [_kimlikDenemeSiniri] sonsuz
  /// döngüyü imkânsız kılıyor; sınıra dayanan kimlik yine de geçerli bir eşya
  /// üretiyor, yalnız tabanı garanti etmiyor.
  static String _kimlikSec({
    required DusmanSinifi sinif,
    required ItemTier tier,
    required String Function(int deneme) kimlikUret,
  }) {
    final bant = ItemBudget.kaliteAltSiniriFor(tier);
    final taban = sinif == DusmanSinifi.boss
        ? math.max(Ganimet.bossKaliteAltSiniri, bant)
        : bant;
    for (var d = 0; d < _kimlikDenemeSiniri; d++) {
      final aday = kimlikUret(d);
      if (ItemBudget.kaliteRolu(aday, 0, taban: bant) >= taban) return aday;
    }
    return kimlikUret(0);
  }

  /// Kalite tabanı için en çok kaç kimlik denenir.
  static const int _kimlikDenemeSiniri = 32;

  /// Bir eşyayı PARÇALAMANIN verdiği malzeme.
  ///
  /// [Ganimet.parcalamaVerimi] eşyanın öldürme maliyetinin bir payı — tamamı
  /// olsaydı eşya farmı malzeme farmının yerine geçerdi. Rank çarpanıyla
  /// ölçekleniyor: üst rank bir eşya daha çok öldürmeye mal oluyor, karşılığı
  /// da o kadar.
  ///
  /// Aşağı yuvarlanıyor ve bu KASITLI: yukarı yuvarlamak, en ucuz eşyayı alıp
  /// parçalayarak malzeme basmayı kârlı kılardı.
  /// KARAR 14.5 s1
  static int parcalamaKazanci(ItemTier rank) =>
      (Ganimet.parcalamaVerimi * rank.multiplier).floor();

  /// Bir eşyayı parçalamanın verdiği ÇEVİRİCİ — rankından bağımsız BİR.
  ///
  /// Bu sayı bir denge kararı değil, seçilen BİRİM: arz-talep denkleminin
  /// (`parçalanan × verim = gereken çevirme × maliyet`) bir tarafı birim
  /// olmak zorunda, öteki taraf ondan türüyor. Verimi bir tutmak en yalın
  /// zihinsel modeli veriyor — "bir eşya erittin, bir çevirici aldın" — ve
  /// rank farkını maliyet tarafına bırakıyor
  /// ([Yukseltme.statBasinaCevirici]).
  static const int parcalamaCeviriciKazanci = 1;
}
