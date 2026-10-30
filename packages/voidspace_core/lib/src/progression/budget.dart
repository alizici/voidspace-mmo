import 'dart:math' as math;

import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import '../domain/ship_stats.dart';
import 'fiyat_cozumu.dart';
import 'hull.dart';
import 'item.dart';
import 'stat.dart';

/// Eşya bütçesi — **türetilen, uydurulan değil**.
///
/// Tasarım belgesinin en önemli yöntemsel kararı. Yanlış yol şu: eşya
/// katsayılarını tahmin et, ortaya çıkan güç paylarını ölç, sonra katsayıları
/// paylar tutana kadar oynat. Bu sistematik değil EĞRİ UYDURMADIR — her yeni
/// yuva eklendiğinde bütün katsayılar yeniden fit edilmek zorunda kalır ve
/// hiçbir sayının neden o değer olduğu açıklanamaz.
///
/// Doğru sıra tersi (World of Warcraft'ın item budget sistemi):
///
///  1. **Payı ilan et.** Toplam gücün her yuva grubuna düşen payı bir TASARIM
///     KARARIDIR, bir hesap sonucu değil.
///  2. **Katsayıyı türet.** Grubun payı, gruptaki eşya sayısına bölününce eşya
///     başına yuva katsayısı çıkar.
///  3. **Ölç.** Ölçüm bir DOĞRULAMADIR, bir ayar kolu değil.
///
/// Bunun bedeli: yeni bir yuva eklemek dengeyi yeniden fit etmeyi
/// gerektirmiyor. Yeni yuvanın payını ilan et, diğerlerinden orantılı düş,
/// katsayıyı adede bölerek türet. Toplam hep %100. Denge bir hesap değil,
/// bir muhasebe.
abstract final class ItemBudget {
  /// İlan edilen paylar.
  ///
  /// Belgedeki yedi gruptan beşi burada: droid ve pilot profili henüz yok.
  /// Belgenin kendi kuralı gereği kalan paylar ORANTILI olarak yeniden
  /// dağıtıldı — grup çıkarmak da eklemek de aynı muhasebe.
  ///
  /// | grup       | belgede | droidsiz | droidli |
  /// |------------|---------|----------|---------|
  /// | Gövde      | %15,0   | %21,6    | %18,3   |
  /// | Lazer      | %22,0   | %31,7    | %26,9   |
  /// | Jeneratör  | %18,5   | %26,6    | %22,6   |
  /// | Roketatar  | %5,5    | %7,9     | %6,7    |
  /// | CPU        | %8,5    | %12,2    | %10,4   |
  /// | Droid      | —       | —        | %15,0   |
  ///
  /// Droid geldi ve beş pay ×0,85 düştü; ArGe geldiğinde aynı muhasebe.
  /// KARAR 08.1 s1
  static const Map<SlotType, double> shares = {
    SlotType.laser: TasarimGirdileri.payLazer,
    SlotType.generator: TasarimGirdileri.payJenerator,
    SlotType.launcher: TasarimGirdileri.payRoketatar,
    SlotType.cpu: TasarimGirdileri.payCpu,
    // Altıncı grup: droid geldi, beş pay ×0,85 düştü (08.1).
    SlotType.droid: TasarimGirdileri.payDroid,
  };

  /// Gövdenin payı. Gövde bir yuva değil, yuvaların taşıyıcısı.
  static const double hullShare = TasarimGirdileri.payGovde;

  /// Referans bütçe. Lazer katsayısı 1,00 olacak şekilde ölçeklendi: C tier,
  /// sıfırıncı seviye bir lazer tam olarak bu kadar taban hasar veriyor.
  ///
  /// Sayının kendisi keyfî — ÖNEMLİ olan bütün eşyaların ona göre türemesi.
  static const double reference = TasarimGirdileri.butceCapasi;

  /// [type] yuvasının [hull] üzerindeki katsayısı.
  ///
  /// Grubun payı gruptaki eşya sayısına bölünüyor, sonra lazer 1,00 olacak
  /// şekilde normalleniyor. Okunuşu: "bir roketatar kaç lazere bedeldir".
  ///
  /// Katsayının gövdeye bağlı olması ZORUNLU: aynı grup payı daha çok yuvaya
  /// bölününce yuva başına düşen güç azalır. SS gövdedeki bir jeneratör, C
  /// gövdedeki bir jeneratörden zayıf olmalı — yoksa yuva sayısı artışı tek
  /// başına gücü katlar. Lazerde görünmüyor: yuvası her gövdede beş (04.9),
  /// yani katsayısı normalizasyon gereği tam 1,00; roketatarda da öyle, tek
  /// yuva (04.11). Korunan şey katsayı değil ÇARPIMI: adet × katsayı gövdeden
  /// bağımsız.
  /// KARAR 08.1 s1 · KARAR 08.2 s2
  static double slotCoefficient(SlotType type, HullClass hull) {
    final laserRaw = shares[SlotType.laser]! / hull.laserSlots;
    // Droid gövdeye takılmıyor: grup payı TAM filoya bölünüyor, gövdeye
    // göre değişmiyor (04.10). Lazer yuvası sanata sabit, ölçek yerinde.
    final count = type == SlotType.droid
        ? TasarimGirdileri.droidFiloTavani
        : hull.slotCount(type);
    if (count == 0) return 0;
    // Filo payı GÖVDE ile DONANIM arasında bölünüyor (05.4 s5): droidin
    // kendi statları payın bir kısmını alıyor, içine takılan eşya gerisini.
    // Bölünmeseydi droid gövdesi eskisi kadar güçlü kalır, donanım da
    // üstüne binerdi — filo payı iki katına çıkardı.
    final pay = type == SlotType.droid
        ? shares[type]! * (1 - Turetilenler.droidDonanimPayi)
        : shares[type]!;
    return (pay / count) / laserRaw;
  }

  /// DROİDİN İÇİNE takılan eşyanın katsayısı (05.4 s5).
  ///
  /// Filo payının donanıma ayrılan kısmı, STANDART filonun toplam yuvasına
  /// bölünüyor: on droid × [TasarimGirdileri.droidYuvasi]. Elit droid daha
  /// çok yuva taşıdığı için daha çok pay topluyor ve farkı tam olarak bu —
  /// rankı ya da stat bütçesi değil, kaç şey taşıdığı.
  ///
  /// Gövdeye bağlı DEĞİL, filo tavanına: droid gövdeye takılmıyor (04.10).
  /// KARAR 05.4 s5 · KARAR 08.2 s2
  static double droidDonanimKatsayisi(HullClass hull) {
    final laserRaw = shares[SlotType.laser]! / hull.laserSlots;
    final yuva =
        TasarimGirdileri.droidFiloTavani * TasarimGirdileri.droidYuvasi;
    if (yuva == 0) return 0;
    final pay =
        shares[SlotType.droid]! * Turetilenler.droidDonanimPayi / yuva;
    return pay / laserRaw;
  }

  /// Bir eşyanın toplam bütçe puanı.
  /// KARAR 08.1 s1
  static double budgetFor(ItemSpec spec, int level, HullClass hull) =>
      reference *
      slotCoefficient(spec.slot, hull) *
      spec.tier.multiplier *
      ItemLevels.multiplier(level);

  /// Bir bütçe puanının kaç BİRİM stat aldığı — HEPSİ TÜRETİLEN.
  ///
  /// Belgedeki `StatMod`. Alan 03'ün kuralı: bir statın değeri, bir birim
  /// artmasının çıktıya kattığı miktar; zincirin kısmi türevi, referans
  /// build'de. Fiyat = çapanın değeri ÷ statın değeri. Uzun süre saldırı
  /// fiyatları elle girdiydi ve zincirin söylediğinden 2,5–3,3 kat ucuzdu
  /// (karar 03.1); artık hiçbir fiyat elle yazılmıyor.
  ///
  /// Türev SAYISAL ve zincirin kendisinden ([CombatGlossary]) alınıyor:
  /// analitik bir kopya, zincir değiştiğinde sessizce eskirdi.
  ///
  ///  * Saldırı: çapa taban hasar, bir puan = bir hasar = [Turetilenler.saldiriPuaniDps]
  ///    DPS. Atış hızı analitik: DPS ∝ (1 + b), türevi DPS'in kendisi.
  ///  * Sistem (menzil, hız): zincirde türevi sıfır; değeri BR'nin sistem
  ///    çarpanından (alan 09). ∂BR/∂S = BR ÷ 100, ∂BR/∂A = BR ÷ 2A, yani bir
  ///    sistem puanı 2A ÷ 100 DPS eder.
  ///  * Savunma: kur `1 DPS ≡ referansTTK EHP`; bir savunma puanı bir saldırı
  ///    puanı kadar EHP almalı. Son azaltma için gelen vuruş referans
  ///    build'in kendi tek atışı (PvP simetrisi, katman kuralı bozulmuyor).
  ///    Kalkan yenilenmesi zamana bağlı: kur süresiyle (karar 03.5).
  ///
  /// Ölçüm noktası DOLU referans (03.2 s2) ve sabit nokta yinelemeyle
  /// çözülüyor ([FiyatCozumu]): fiyat → eşya değeri → referans → fiyat.
  /// KARAR 03.1 s2 · KARAR 03.2 s2 · KARAR 03.3 s1 · KARAR 03.4 s1
  static Map<String, double> get fiyatlar => FiyatCozumu.fiyatlar;

  /// Fiyatın ölçüldüğü SALDIRI büyüklüğü — geminin beklenen lazer DPS'i.
  ///
  /// Roket dahil DEĞİL ve olamaz: saldırı çapası bir puan taban hasar, taban
  /// hasar da gemi kapsamında (18.1), yani roketin zincirine girmiyor. Çapa
  /// ile fiyatlanan stat aynı çıktının türevi olmak zorunda; roket kendi
  /// kapsamında kendi çapasıyla fiyatlanıyor.
  ///
  /// Ayrı bir işlev olması `PayOlcumu` için: sistem kanalının kuru (`2A ÷
  /// 100`) fiyatlarken de ölçerken de aynı A'yı okumalı.
  /// KARAR 03.2 s2
  static double olcumDps(ShipStats ref) => CombatGlossary.expectedDps(ref);

  /// [ref] noktasında ölçülen fiyat tablosu — sabit noktanın TEK ADIMI.
  ///
  /// Ayrı bir işlev, çünkü çözücü onu birden çok kez çağırıyor: önce çıplak
  /// tohumla ([ShipStats.bastion]), sonra o fiyatlarla kurulan dolu
  /// referansla, yakınsayana kadar. İçindeki hiçbir sayı [fiyatlar]'ı
  /// okumuyor — okusaydı statik başlatma kendini çağırırdı.
  /// KARAR 03.2 s2
  static Map<String, double> fiyatlariTuret(ShipStats ref) {
    final dps = olcumDps(ref);
    final ehp = CombatGlossary.ehp(ref);
    final puanDps = Turetilenler.saldiriPuaniDps;
    final puanEhp = puanDps * TasarimGirdileri.referansTTK;
    // Türevin ADIMI kaydın biriminden: oran statı kesirle, mutlak ve eğri
    // statı bir puanla itiliyor. Aynı kaydı çözümleyici de okuyor
    // (`StatBirimi.uygula`); mutlak bir stata kesir fiyatı vermek, ya da
    // tersi, tek satırda mümkün değil.
    // KARAR 03.6 s1
    double dDps(StatDef d, ShipStats s) =>
        (CombatGlossary.expectedDps(s) - dps) / turevAdimi(d);
    double dEhp(StatDef d, ShipStats s) =>
        (CombatGlossary.ehp(s) - ehp) / turevAdimi(d);
    final sistemPuaniDps = 2 * dps / 100;
    double sistem(double katsayi) => puanDps / (sistemPuaniDps * katsayi * 100);
    final vurus = CombatGlossary.expectedVolley(ref) / ref.laserSlots;
    final b = Stats.damageBonus;
    final ks = Stats.critChance;
    final kh = Stats.critMultiplier;
    final sh = Stats.flatDamage;
    final gc = Stats.maxHull;
    final ka = Stats.maxShield;
    final z = Stats.armor;
    final kc = Stats.evasion;
    return {
      'taban_hasar': 1.0,
      'hasar_artisi':
          puanDps /
          dDps(b, ref.copyWith(damageBonus: ref.damageBonus + turevAdimi(b))),
      'atis_hizi': puanDps / dps,
      'kritik_sansi':
          puanDps /
          dDps(ks, ref.copyWith(critChance: ref.critChance + turevAdimi(ks))),
      'kritik_hasari':
          puanDps /
          dDps(
            kh,
            ref.copyWith(critMultiplier: ref.critMultiplier + turevAdimi(kh)),
          ),
      'son_hasar':
          puanDps /
          dDps(sh, ref.copyWith(flatDamage: ref.flatDamage + turevAdimi(sh))),
      'menzil': sistem(TasarimGirdileri.sistemKatsayisiMenzil),
      'hiz': sistem(TasarimGirdileri.sistemKatsayisiHiz),
      'itki_dolumu': sistem(TasarimGirdileri.sistemKatsayisiItki),
      'govde_cani':
          puanEhp /
          dEhp(gc, ref.copyWith(maxHull: ref.maxHull + turevAdimi(gc))),
      'kalkan':
          puanEhp /
          dEhp(ka, ref.copyWith(maxShield: ref.maxShield + turevAdimi(ka))),
      'kalkan_yenilenmesi': Turetilenler.puanBasinaKalkanYenilenmesi,
      'zirh': puanEhp / dEhp(z, ref.copyWith(armor: ref.armor + turevAdimi(z))),
      'kacinma':
          puanEhp /
          dEhp(kc, ref.copyWith(evasion: ref.evasion + turevAdimi(kc))),
      'son_azaltma': puanEhp / (ehp / vurus),
    };
  }

  /// Fiyat türevinin ADIMI — kaydın biriminden.
  ///
  /// Oran statı binde birlik kesirle, mutlak ve eğri statı bir puanla
  /// itiliyor. Adımı kayıt söylediği için bir statın birimi değişince fiyatı
  /// da kendiliğinden doğru birimde ölçülüyor.
  /// KARAR 03.6 s1
  static double turevAdimi(StatDef d) =>
      d.birim == StatBirimi.oran ? 0.001 : 1.0;

  /// Bir statın birim fiyatı. Fiyatsız stat sıfır: bütçe onu dağıtamaz.
  ///
  /// [tablo] yalnız sabit nokta çözülürken doluyor ([FiyatCozumu]): o sırada
  /// [fiyatlar] henüz kurulmamış olur ve okumak döngü olurdu.
  /// KARAR 06.7 s1 · KARAR 09.4 s1
  static double birimFiyati(String statId, {Map<String, double>? tablo}) =>
      (tablo ?? fiyatlar)[statId] ?? 0;

  /// Bir eşyanın ANA statının değeri.
  ///
  /// Bütçenin TAMAMI değil, [TasarimGirdileri.anaStatPayi] kadarı: kalanı alt
  /// statlara gidiyor. Bölünme alan 06'nın kararı ve keyfî değil: pay
  /// büyürse eşyalar birbirinin aynısı olur, küçülürse aynı eşyanın gücü
  /// oyuncudan oyuncuya oynar. Bir zamanlar bir çakışma TAVANINA da
  /// dayandırılmıştı (%43); bugünkü merdivende öyle bir tavan yok (06.6 s2).
  /// KARAR 06.5 s1
  static double mainStatValue(
    ItemSpec spec,
    int level,
    HullClass hull, {
    Map<String, double>? tablo,
  }) {
    final units = birimFiyati(spec.mainStat, tablo: tablo);
    return budgetFor(spec, level, hull) * TasarimGirdileri.anaStatPayi * units;
  }

  /// DROİDE takılı bir eşyanın bütçesi — yuva katsayısı droidin (05.4 s5).
  ///
  /// Aynı lazer gemide başka, droidde başka değer taşıyor ve bu 08.2'nin
  /// kuralının doğrudan sonucu: katsayı yuvadan geliyor, eşyadan değil.
  /// KARAR 05.4 s5
  static double droidDonanimButcesi(ItemSpec spec, int level, HullClass hull) =>
      reference *
      droidDonanimKatsayisi(hull) *
      spec.tier.multiplier *
      ItemLevels.multiplier(level);

  /// Droide takılı eşyanın ANA stat değeri.
  /// KARAR 05.4 s5
  static double droidDonanimAnaStat(
    ItemSpec spec,
    int level,
    HullClass hull,
  ) =>
      droidDonanimButcesi(spec, level, hull) *
      TasarimGirdileri.anaStatPayi *
      birimFiyati(spec.mainStat);

  /// Bir eşyanın ALT STATLARI — türetilen, saklanmayan.
  ///
  /// **Neden türetilen.** `ItemInstance.subStats` bir zamanlar okunuyor ve
  /// serileştiriliyordu ama hiçbir yerde YAZILMIYORDU: yarısı ölü bir sistem.
  /// Yazmak için rastgelelik gerekiyor, rastgelelik için de sunucuda saklanan
  /// bir tohum — ya da hiç saklanmayan bir tane.
  ///
  /// [instanceId] zaten benzersiz ve kalıcı. Ondan türetilen roll, kaydedilmiş
  /// hangarları GÖÇÜRMEDEN çalışıyor: alt statı olmayan eski bir eşya da
  /// kendi kimliğinden aynı rolü üretiyor, ve aynı eşya her yüklemede aynı
  /// statları taşıyor.
  ///
  /// Saklanan harita boş DEĞİLSE o kazanıyor: alan 07'nin çevirmesi (alt stat
  /// yenileme) sonucunu oraya yazacak. Yani türetilen ilk roll, saklanan ise
  /// oyuncunun onu değiştirmiş hâli.
  /// Bir alt statın ROL ÖNCESİ tabanı — kalite çarpanı uygulanmadan.
  ///
  /// Rol `[kaliteAltSiniri, 1,0]` aralığında oynuyor, yani bir statın
  /// alabileceği en düşük ve en yüksek değer `taban × kaliteAltSiniri` ile
  /// `taban`. Oyuncunun "iyi mi çektim" sorusunun cevabı bu iki uç.
  ///
  /// **Ayrı bir fonksiyon, çünkü iki çağıranı var** ve ikisi de aynı tabanı
  /// sormak zorunda: çevirme yeni değeri buradan çekiyor, arayüz de aralığı
  /// buradan yazıyor. Çevirme bir ara tabanı MEVCUT değerden geri çözüyordu
  /// (`değer ÷ beklenen rol`) ve yaklaşıktı — rol saklanmadığı için ortalama
  /// kullanılıyordu. Artık ikisi de kesin ve aynı kaynaktan.
  ///
  /// Artı güçlenmeleri DÂHİL: taban, kimliğe düşen adımlarla büyüyor
  /// (karar 07.6), o yüzden örnek kimliği şart.
  ///
  /// Havuzda olmayan stat için `null`.
  static double? altStatTabani(
    ItemSpec spec,
    int level,
    HullClass hull,
    String statId,
    String instanceId,
  ) {
    final havuz = spec.subStatPool;
    final adet = math.min(altStatSayisi(spec.tier), havuz.length);
    if (adet == 0) return null;
    var indeks = -1;
    for (var i = 0; i < adet; i++) {
      if (havuz[i % havuz.length] == statId) {
        indeks = i;
        break;
      }
    }
    if (indeks < 0) return null;
    final pay =
        budgetFor(spec, level, hull) * (1 - TasarimGirdileri.anaStatPayi);
    return pay /
        adet *
        birimFiyati(statId) *
        guclenme(instanceId, level, adet, indeks);
  }

  /// KARAR 06.5 s1
  static Map<String, double> subStatValues(
    ItemSpec spec,
    int level,
    HullClass hull,
    String instanceId,
  ) {
    final havuz = spec.subStatPool;
    if (havuz.isEmpty) return const {};

    // Kaç alt stat: tier ile artıyor. Üst tier daha çok DERİNLİK veriyor,
    // yalnız daha büyük sayı değil.
    final adet = math.min(altStatSayisi(spec.tier), havuz.length);
    if (adet == 0) return const {};

    // Alt statların TOPLAM bütçesi — ana statın almadığı pay.
    final pay =
        budgetFor(spec, level, hull) * (1 - TasarimGirdileri.anaStatPayi);

    // Sıfırıncı seviyede de statlar VAR — seviyeyle açılan şey güç, statın
    // kendisi değil. Güçlenme adımları (3/6/9/12/15) TEK stata düşüyor ve
    // hangisine düştüğü kimlikten türüyor (karar 07.6, [guclenme]).
    final taban = kaliteAltSiniriFor(spec.tier);
    final garanti = garantiliFor(spec.tier);
    final sonuc = <String, double>{};
    for (var i = 0; i < adet; i++) {
      final statId = havuz[i % havuz.length];
      final birim = birimFiyati(statId);
      // Kalite rolü: rankın bandı ile 1,00 arası, kimlikten türetilen.
      // Garantili indeksler bandın tepesinden (karar 06.10).
      final roll = i < garanti ? 1.0 : kaliteRolu(instanceId, i, taban: taban);
      sonuc[statId] =
          pay / adet * birim * roll * guclenme(instanceId, level, adet, i);
    }
    return sonuc;
  }

  /// Rank başına alt stat SAYISI — HARF AİLESİNDEN.
  ///
  /// Bir zamanlar beş satırlık kesikli bir tabloydu (1·2·3·4·4) ve doc'u
  /// "formül değil" diyordu. Merdiven yirmi ranka uzayınca yirmi satır elle
  /// yazmak gerekecekti — ve on altısı aynı sayıyı söyleyecekti.
  ///
  /// Asıl kural tablonun içinde saklıydı: sayı ailenin sırası, dörtte kesik.
  /// Yirmi rankta da aynı beş değeri üretiyor (C-I·C-II·C-III hepsi 1), çünkü
  /// eski tablonun beş satırı zaten beş AİLEYDİ — basamak değil.
  ///
  /// Kesik neden dört: alt stat havuzu o kadar geniş, ve [_dagit] zaten
  /// `min(altStatSayisi, havuz.length)` ile sınırlıyor. Kesiği kaldırmak üst
  /// ranklarda sessizce aynı statı iki kez basardı.
  /// KARAR 06.9 s2 — C1 · B2 · A3 · S4 · SS5 · SSS6 · renkler 7.
  static int altStatSayisi(ItemTier tier) =>
      tier.kapakTasi ? altStatTavani : math.min(tier.aile + 1, altStatTavani);

  /// Bir eşyanın taşıyabileceği en çok alt stat — kapak taşlarının derinliği.
  ///
  /// Kütüphane on dört stat; havuzlar yediye tamamlanınca (karar 06.8) tavan
  /// yedi. Kesiği aşan bir aile yoktur: SSS altı, üstü kapak taşı.
  static const int altStatTavani = ItemTier.aileSayisi + 1;

  /// Rankın KALİTE BANDI tabanı — üç bant (karar 06.10).
  ///
  /// C–S geniş, SS–SSS dar, kapak taşları en dar: üst ranklar sayı olarak
  /// değil güvenilirlik olarak da ayrışıyor.
  /// KARAR 06.10 s2
  static double kaliteAltSiniriFor(ItemTier tier) => tier.kapakTasi
      ? TasarimGirdileri.kaliteAltSiniriRenk
      : tier.aile >= ItemTier.aileSayisi - 2
      ? TasarimGirdileri.kaliteAltSiniriSS
      : TasarimGirdileri.kaliteAltSiniri;

  /// GARANTİLİ alt stat sayısı — kaç alt stat mükemmel (rol 1,0) geliyor.
  ///
  /// Renk, Çin MMO'larındaki gibi kalite güvencesi: SS–SSS'de bir, kapak
  /// taşlarında iki alt stat bandın tepesinden gelir. Garanti ilk roldedir;
  /// havuzun ilk indeksleri.
  /// KARAR 06.10 s2
  static int garantiliFor(ItemTier tier) => tier.kapakTasi
      ? TasarimGirdileri.garantiliAltStatRenk
      : tier.aile >= ItemTier.aileSayisi - 2
      ? TasarimGirdileri.garantiliAltStatSS
      : 0;

  /// Kimlikten türetilen kalite rolü — `[kaliteAltSiniri, 1,0]` aralığında.
  ///
  /// `Random` DEĞİL: aynı eşya her yüklemede aynı rolü taşımak zorunda, yoksa
  /// oyuncunun gemisi her girişte başka bir gemi olur. Karma, tohumu saklama
  /// ihtiyacını ortadan kaldırıyor.
  /// AÇIK (public), çünkü iki çağıranı var: alt stat dağıtımı ve ganimet
  /// çekilişi. Çekiliş boss'un kalite tabanını ancak kimlik SEÇEREK
  /// tutturabiliyor — ve seçebilmek için aynı karmayı sorması şart. İkinci bir
  /// karma yazmak, kaliteyi iki ayrı yerde tanımlamak olurdu.
  /// KARAR 06.2 s1
  static double kaliteRolu(
    String instanceId,
    int indeks, {
    double taban = TasarimGirdileri.kaliteAltSiniri,
  }) {
    final birimAralik = _karma('$instanceId#$indeks') / 4294967296;
    return taban + birimAralik * (1 - taban);
  }

  /// FNV-1a — kısa, dağılımı iyi, ve platformdan bağımsız (bit işleci yok,
  /// web'de de aynı sonucu veriyor). Kalite rolü ve güçlenme hedefi AYNI
  /// karmayı okuyor: iki karma, rastgeleliğin iki ayrı tanımı olurdu.
  static int _karma(String metin) {
    var karma = 2166136261;
    for (final birim in metin.codeUnits) {
      karma = ((karma ^ birim) * 16777619) % 4294967296;
    }
    return karma;
  }

  // ══ Artı basma güçlenmesi — karar 07.6 ═════════════════════════════
  //
  // Tek rastgele kuralının öteki yönü: +3 · +6 · +9 · +12 · +15'te BİR alt
  // stat güçlenir; hangisi rastgele (kimlikten, saklanmıyor), ne kadar sabit.
  // Miktar: alt stat bütçesinin adım sayısında bir payı, yani her adım payın
  // beşte biri TEK stata. Toplam, adımı bütün statlara yayan eski kuralla
  // aynı; havuz genişledikçe tek statın sıçraması büyüyor, toplam değişmiyor.
  // C ailesinde tek stat var: orada iki kural özdeş.

  /// [indeks] numaralı alt statın [level]'deki güçlenme ÇARPANI.
  ///
  /// `1 + (adet ÷ adım sayısı) × isabet`: her isabet statın kendi tabanının
  /// `adet ÷ adım sayısı` katını ekliyor, böylece bir adım tam olarak payın
  /// beşte birini taşıyor.
  /// KARAR 07.6 s1
  static double guclenme(String instanceId, int level, int adet, int indeks) =>
      1 +
      adet /
          ItemLevels.adimSayisi *
          guclenmeSayisi(instanceId, level, adet, indeks);

  /// [level]'e kadar açılan adımların kaçı [indeks]'e düştü.
  static int guclenmeSayisi(
    String instanceId,
    int level,
    int adet,
    int indeks,
  ) {
    var isabet = 0;
    for (var adim = 1; adim <= ItemLevels.adimSayisiFor(level); adim++) {
      if (guclenenIndeks(instanceId, adim, adet) == indeks) isabet++;
    }
    return isabet;
  }

  /// [adim] numaralı adımın güçlendirdiği alt statın HAVUZ indeksi.
  ///
  /// Kimlikten ve adım numarasından; `Random` değil, saklanmıyor: aynı eşya
  /// her yüklemede aynı statı büyütmüş görünüyor. Çevirme buna dokunmuyor —
  /// yalnız kalite rolünü yeniler, güçlenme kimliğin kendisinden.
  /// KARAR 07.6 s1
  static int guclenenIndeks(String instanceId, int adim, int adet) {
    if (adet <= 0) return 0;
    return _karma('$instanceId#adım$adim') % adet;
  }

  /// [statId]'nin [level]'e kadar kaç kez güçlendiği — arayüzün rozeti.
  /// Havuzda olmayan stat için sıfır.
  static int guclenmeSayisiFor(
    ItemSpec spec,
    int level,
    String statId,
    String instanceId,
  ) {
    final havuz = spec.subStatPool;
    final adet = math.min(altStatSayisi(spec.tier), havuz.length);
    for (var i = 0; i < adet; i++) {
      if (havuz[i % havuz.length] == statId) {
        return guclenmeSayisi(instanceId, level, adet, i);
      }
    }
    return 0;
  }

  /// Bir adımın tek stata verdiği miktar, o statın tabanına oranla.
  static double guclenmeOrani(ItemTier tier) =>
      altStatSayisi(tier) / ItemLevels.adimSayisi;
}
