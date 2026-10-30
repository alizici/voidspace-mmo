@Tags(['turetme'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 03 · STAT DEĞERİ — bir statın kaç ettiğini KİM, hangi YÖNTEMLE ve
/// hangi BİRİMDE söyler.
///
/// Belge: `docs/03-stat-degeri.md`. Burada denge sabiti sınanmıyor; sınanan
/// şey yöntem: fiyat zincirin türevinden mi geliyor, hangi noktada ölçülüyor,
/// kanalın içinde mi kalıyor, çapa sonuca karışıyor mu. Sayı tablosunun
/// kendisi `03-deger-tablosu.md`de ve oranları buradan çıkıyor.
void main() {
  // Ölçüm noktası DOLU referans (03.2 s2): fiyat sabit noktada çözülüyor
  // (`FiyatCozumu`), çıplak gövde artık yalnız yinelemenin tohumu.
  final ref = FiyatCozumu.referans;
  final dps0 = CombatGlossary.expectedDps(ref);
  final ehp0 = CombatGlossary.ehp(ref);

  /// Bir SALDIRI puanının beklenen DPS'i — çapanın değeri.
  final puanDps = Turetilenler.saldiriPuaniDps;

  /// Aynı puanın DAYANIKLILIK karşılığı: kur `1 DPS ≡ referansTTK × EHP`.
  final puanEhp = puanDps * TasarimGirdileri.referansTTK;

  LaserStats lazer({double? hasar, double? aralik}) => LaserStats(
    id: ref.laser.id,
    name: ref.laser.name,
    damage: hasar ?? ref.laser.damage,
    fireInterval: aralik ?? ref.laser.fireInterval,
    range: ref.laser.range,
  );

  /// [puan] bütçe puanını [id] statına yatırmış referans build.
  ///
  /// Puanın kaç BİRİM stat aldığını fiyat söylüyor (StatMod); birimin nasıl
  /// uygulanacağını kaydın kendisi (02.2). İkisi ayrışırsa aşağıdaki marjinal
  /// katkı testleri kırılır.
  ShipStats yatir(String id, [double puan = 1]) {
    final birim = ItemBudget.birimFiyati(id) * puan;
    return switch (id) {
      // Taban hasar NAMLU başına: bir puan yaylımın tabanına bir hasar.
      'taban_hasar' => ref.copyWith(
        laser: lazer(hasar: ref.laser.damage + birim / ref.equippedLasers),
      ),
      'hasar_artisi' => ref.copyWith(damageBonus: ref.damageBonus + birim),
      'atis_hizi' => ref.copyWith(
        laser: lazer(aralik: ref.laser.fireInterval / (1 + birim)),
      ),
      'kritik_sansi' => ref.copyWith(critChance: ref.critChance + birim),
      'kritik_hasari' => ref.copyWith(
        critMultiplier: ref.critMultiplier + birim,
      ),
      'son_hasar' => ref.copyWith(flatDamage: ref.flatDamage + birim),
      'govde_cani' => ref.copyWith(maxHull: ref.maxHull + birim),
      'kalkan' => ref.copyWith(maxShield: ref.maxShield + birim),
      'zirh' => ref.copyWith(armor: ref.armor + birim),
      'kacinma' => ref.copyWith(evasion: ref.evasion + birim),
      'menzil' => ref.copyWith(rangeBonus: ref.rangeBonus + birim),
      'hiz' => ref.copyWith(speedBonus: ref.speedBonus + birim),
      'itki_dolumu' => ref.copyWith(
        boostRechargeBonus: ref.boostRechargeBonus + birim,
      ),
      _ => throw ArgumentError('yatırım yolu yok: $id'),
    };
  }

  /// Zincirden alınan sayısal türev: [id] statının BİR biriminin DPS katkısı.
  double dpsTurevi(String id) {
    final s = Stats.byId(id)!;
    final adim = ItemBudget.turevAdimi(s);
    final itilmis = yatir(id, adim / ItemBudget.birimFiyati(id));
    return (CombatGlossary.expectedDps(itilmis) - dps0) / adim;
  }

  group('03.1 · değer marjinal katkıdır, zincirden türer', () {
    // KARAR 03.1 s2
    test('saldırı fiyatı ZİNCİRİN türevinden — elle yazılmış sayı yok', () {
      // Fiyat = çapanın değeri ÷ statın değeri, ve "değer" zincirin kısmi
      // türevi. Türev burada BAĞIMSIZ olarak yeniden alınıyor: tablodaki sayı
      // formülden koparsa (biri fiyatı "düzeltirse") bu test kırılır.
      for (final id in [
        'hasar_artisi',
        'atis_hizi',
        'kritik_sansi',
        'kritik_hasari',
        'son_hasar',
      ]) {
        final turev = dpsTurevi(id);
        expect(turev, greaterThan(0), reason: '$id zinciri hiç kıpırdatmıyor');
        expect(
          ItemBudget.birimFiyati(id),
          closeTo(puanDps / turev, puanDps / turev * 1e-9),
          reason: '$id fiyatı zincirin türevinden kopmuş',
        );
      }
    });

    // KARAR 03.1 s2
    test('KANARYA: hasar artışı ile atış hızı aynı fiyatta', () {
      // İkisi de aynı tabanı çarpıyor (L1, toplamsal). Eşitlik bozulursa
      // sorun bu tabloda değil alan 01'de: zincirin L1 katmanı bozulmuş.
      expect(
        ItemBudget.birimFiyati('hasar_artisi'),
        closeTo(ItemBudget.birimFiyati('atis_hizi'), 1e-12),
      );
    });

    // KARAR 03.1 s2
    test(
      'sistem statlarında zincirin türevi SIFIR — değer 09\'dan geliyor',
      () {
        // ∂DPS/∂menzil = 0 ve ∂EHP/∂menzil = 0: menzil hasarı büyütmüyor,
        // hedefte kalma süresini uzatıyor. Yine de fiyatı var, çünkü değeri
        // BR'nin sistem çarpanından geliyor (09.5).
        for (final id in ['menzil', 'hiz', 'itki_dolumu']) {
          final s = yatir(id, 1000);
          expect(
            CombatGlossary.expectedDps(s),
            closeTo(dps0, 1e-9),
            reason: id,
          );
          expect(CombatGlossary.ehp(s), closeTo(ehp0, 1e-9), reason: id);
          expect(ItemBudget.birimFiyati(id), greaterThan(0), reason: id);
        }
        // Ve fiyat, 09'un sistem KATSAYISINDAN başka bir şey taşımıyor:
        // fiyat × katsayı üç statta da aynı sayı. Taşısaydı üçü ayrışırdı.
        final carpimlar = {
          'menzil':
              ItemBudget.birimFiyati('menzil') *
              TasarimGirdileri.sistemKatsayisiMenzil,
          'hiz':
              ItemBudget.birimFiyati('hiz') *
              TasarimGirdileri.sistemKatsayisiHiz,
          'itki_dolumu':
              ItemBudget.birimFiyati('itki_dolumu') *
              TasarimGirdileri.sistemKatsayisiItki,
        };
        final ilk = carpimlar['menzil']!;
        carpimlar.forEach((id, carpim) {
          expect(carpim, closeTo(ilk, ilk * 1e-9), reason: id);
        });
      },
    );

    // KARAR 03.1 s2
    test(
      'son azaltmanın vuruşu referansın KENDİ tek atışı — PvP simetrisi',
      () {
        // Düz azaltmanın değeri gelen vuruşun büyüklüğüne bağlı. Vuruş, savaş
        // katmanının dünya katmanını (düşman hasarı, alan 12) okumadan
        // bilebileceği tek sayı: referans build'in kendi tek atışı.
        final vurus = CombatGlossary.expectedVolley(ref) / ref.laserSlots;
        final dayanilanVurus = ehp0 / vurus;
        expect(
          ItemBudget.birimFiyati('son_azaltma'),
          closeTo(puanEhp / dayanilanVurus, 1e-9),
        );
        // Vuruş TEK ATIŞ, yaylımın tamamı değil: yaylımla fiyatlansaydı stat
        // namlu sayısı kadar ucuzlardı.
        expect(
          ItemBudget.birimFiyati('son_azaltma'),
          isNot(
            closeTo(
              puanEhp / (ehp0 / CombatGlossary.expectedVolley(ref)),
              1e-6,
            ),
          ),
        );
      },
    );
  });

  group('03.2 · referans noktada ölçme', () {
    // KARAR 03.2 s2
    test('bir taban hasar puanı = saldiriPuaniDps, referansın aralığından', () {
      expect(
        puanDps,
        closeTo(
          Turetilenler.kritikBeklenenDeger /
              TasarimGirdileri.referansAtisAraligi,
          1e-12,
        ),
      );
      // Ölçüm noktası GERÇEKTEN o build: aralığı ve kritiği referansın.
      expect(ref.laser.fireInterval, TasarimGirdileri.referansAtisAraligi);
      expect(ref.critChance, TasarimGirdileri.kritikSansiReferans);
      expect(ref.critMultiplier, TasarimGirdileri.kritikCarpaniReferans);
      expect(
        CombatGlossary.expectedDps(yatir('taban_hasar')) - dps0,
        closeTo(puanDps, 1e-9),
      );
    });

    // KARAR 03.2 s2
    test(
      'fiyat DOLU referansta ölçülüyor — çıplak gövde yalnız tohum',
      () {
        // Uzun süre ölçüm noktası çıplak gövdeydi (`ShipStats.bastion`) ve
        // oyuncunun referansı doluydu: yüzde statlar gerçek build'de
        // fiyatlarından değerliydi (borç defteri B22). Bugün ikisi aynı
        // nokta ve döngü sabit noktayla çözülüyor.
        const ciplak = ShipStats.bastion;
        expect(
          dps0,
          greaterThan(CombatGlossary.expectedDps(ciplak) * 1.5),
          reason: 'fiyat referansı çıplak gövdeden ayırt edilemiyor',
        );
        const adim = 0.001;
        double fiyatiOlc(ShipStats nokta) {
          final d0 = CombatGlossary.expectedDps(nokta);
          final d1 = CombatGlossary.expectedDps(
            nokta.copyWith(damageBonus: nokta.damageBonus + adim),
          );
          return puanDps / ((d1 - d0) / adim);
        }

        expect(
          ItemBudget.birimFiyati('hasar_artisi'),
          closeTo(fiyatiOlc(ref), 1e-9),
          reason: 'fiyat dolu referansta ölçülmüyor',
        );
        expect(
          ItemBudget.birimFiyati('hasar_artisi'),
          isNot(closeTo(fiyatiOlc(ciplak), 1e-6)),
          reason: 'fiyat hâlâ çıplak gövdeden besleniyor',
        );
      },
    );

    // KARAR 03.2 s2
    test('sabit nokta YAKINSIYOR ve ölçüm noktası oyuncunun referansı', () {
      // Döngü: fiyat → eşyanın ana stat değeri → referansın statları → fiyat.
      // Çözücü onu yineleyerek kırıyor; yakınsama bir varsayım değil ölçülen
      // bir sayı, ve ıraksarsa çözücü sessiz kalmıyor.
      expect(
        FiyatCozumu.adim,
        lessThanOrEqualTo(FiyatCozumu.adimTavani),
        reason: 'yineleme tavana dayandı',
      );
      expect(FiyatCozumu.adim, 2, reason: 'yakınsama adımı kaydı — 03.2 s2');
      expect(FiyatCozumu.sapma, lessThanOrEqualTo(FiyatCozumu.esik));
      // Sabit noktanın kendisi: çözülen fiyatlarla kurulan referans, fiyatın
      // ölçüldüğü referansın TA KENDİSİ.
      expect(
        CombatGlossary.expectedDps(ReferansCozumu.stats),
        closeTo(dps0, dps0 * 1e-9),
        reason: 'fiyat referansı ile oyuncunun referansı ayrışmış',
      );
      expect(
        ItemBudget.fiyatlar,
        equals(ItemBudget.fiyatlariTuret(ReferansCozumu.stats)),
        reason: 'sabit nokta değil: bir adım daha fiyatı değiştiriyor',
      );
    });
  });

  group('03.3 · kanal içi fiyatlama', () {
    // KARAR 03.3 s1
    test('SALDIRI kanalı: eşit bütçe → eşit marjinal DPS', () {
      // Bütçenin tek sözü, bir puanın hangi stata konursa konsun aynı
      // marjinal gücü alması. Saldırıda ölçü DPS ve içinde kur (TTK) YOK.
      for (final id in [
        'taban_hasar',
        'hasar_artisi',
        'atis_hizi',
        'kritik_sansi',
        'kritik_hasari',
        'son_hasar',
      ]) {
        expect(
          CombatGlossary.expectedDps(yatir(id)) - dps0,
          closeTo(puanDps, puanDps * 1e-9),
          reason: '$id bir puana başka güç alıyor',
        );
      }
    });

    // KARAR 03.3 s1
    test('SAVUNMA kanalı: eşit bütçe → eşit marjinal EHP', () {
      // Savunmada ölçü EHP. Bir zamanlar fiyatlar saldırıyla savunmayı tek
      // ölçekte tutuyor, ilan edilmemiş bir kur ima ediyordu: bir savunma
      // puanı bir saldırı puanının beşte biri kadar güç alıyordu.
      for (final id in ['govde_cani', 'kalkan', 'zirh', 'kacinma']) {
        expect(
          CombatGlossary.ehp(yatir(id)) - ehp0,
          closeTo(puanEhp, puanEhp * 1e-9),
          reason: '$id bir puana başka dayanıklılık alıyor',
        );
      }
    });

    // KARAR 03.3 s1
    test('kur TTK\'nın kendisi ve YALNIZ kanal geçişinde', () {
      // Saldırı fiyatlarında TTK yok, savunma fiyatlarında tam bir kez var:
      // "1 DPS ≡ referansTTK × EHP". Kur burada tanımlanmıyor, 09'dan
      // okunuyor; 03 onu yalnız kanalı geçerken kullanıyor.
      expect(puanEhp / puanDps, closeTo(TasarimGirdileri.referansTTK, 1e-12));
      expect(
        Turetilenler.savunmaCapasi,
        closeTo(puanEhp / Turetilenler.referansEhpCarpani, 1e-9),
      );
      // Üç kanalın hepsi tek tabloda: açık statların hiçbiri fiyatsız değil.
      for (final s in Stats.all) {
        expect(ItemBudget.birimFiyati(s.id), greaterThan(0), reason: s.id);
      }
    });
  });

  group('03.4 · StatMod ve çapa sözleşmesi', () {
    // KARAR 03.4 s1
    test('saldırı çapası taban hasar — StatMod 1,00', () {
      expect(ItemBudget.birimFiyati('taban_hasar'), 1.0);
      // Çapa olmanın anlamı: bir bütçe puanı bire bir statın kendisi.
      expect(
        CombatGlossary.expectedVolley(yatir('taban_hasar')) -
            CombatGlossary.expectedVolley(ref),
        closeTo(Turetilenler.kritikBeklenenDeger, 1e-9),
      );
    });

    // KARAR 03.4 s1
    test('savunma çapaları gövde canı ve kalkan — ikisi de savunmaCapasi', () {
      final capa = Turetilenler.savunmaCapasi;
      for (final id in ['govde_cani', 'kalkan']) {
        expect(
          ItemBudget.birimFiyati(id),
          closeTo(capa, capa * 1e-9),
          reason: '$id çapası kurdan çözülmüyor',
        );
      }
      expect(
        ItemBudget.birimFiyati('govde_cani'),
        ItemBudget.birimFiyati('kalkan'),
        reason: 'iki çapa ayrışmış — bir puan iki havuzda farklı güç alıyor',
      );
    });

    // KARAR 03.4 s1
    test('çapa bir SÖZLEŞME: değişirse oranlar değişmiyor', () {
      // StatMod(stat) = değer(çapa) ÷ değer(stat). Çapayı taban hasardan
      // kritik şansına taşımak bütün tabloyu tek bir katsayıyla ölçekler;
      // statların birbirine oranı — yani tablonun söylediği her şey — sabit
      // kalır. Aşağıdaki alternatif tablo zincirden BAĞIMSIZ olarak
      // türetiliyor, mevcut tablodan bölünerek değil.
      const yeniCapa = 'kritik_sansi';
      final capaDegeri = dpsTurevi(yeniCapa);
      final saldiri = [
        'taban_hasar',
        'hasar_artisi',
        'atis_hizi',
        'kritik_sansi',
        'kritik_hasari',
        'son_hasar',
      ];
      final alternatif = {
        for (final id in saldiri) id: capaDegeri / dpsTurevi(id),
      };
      expect(
        alternatif[yeniCapa],
        closeTo(1.0, 1e-9),
        reason: 'çapa 1,00 değil',
      );
      for (final id in saldiri) {
        for (final digeri in saldiri) {
          expect(
            alternatif[id]! / alternatif[digeri]!,
            closeTo(
              ItemBudget.birimFiyati(id) / ItemBudget.birimFiyati(digeri),
              1e-6,
            ),
            reason: 'çapa değişince $id ÷ $digeri oranı kaydı',
          );
        }
      }
    });
  });

  group('03.5 · değerleme dövüş süresi', () {
    // KARAR 03.5 s2
    test('zamana bağlı stat KUR süresiyle fiyatlanıyor — ayrı girdi yok', () {
      // Kalkan yenilenmesi havuzu büyütmüyor, zamana yayıyor: değeri ancak
      // ilan edilmiş bir süreyle sayıya döner. O süre ayrı bir girdi değil,
      // kur süresinin kendisi.
      expect(
        ItemBudget.birimFiyati('kalkan_yenilenmesi'),
        closeTo(
          Turetilenler.savunmaCapasi / TasarimGirdileri.referansTTK / 100,
          1e-12,
        ),
      );
      expect(TasarimGirdileri.referansTTK, 30);
      // Belgenin ilk sürümü 20 saniyelik AYRI bir girdi ilan etmişti; iki
      // süre tutmak aynı kararı iki yerde vermek olurdu.
      expect(
        ItemBudget.birimFiyati('kalkan_yenilenmesi'),
        isNot(closeTo(Turetilenler.savunmaCapasi / 20 / 100, 1e-9)),
        reason: 'değerleme süresi kur süresinden ayrışmış',
      );
    });

    // KARAR 03.5 s2
    test('aynı süre kurun kendisi — savunma çapası da ondan çözülüyor', () {
      expect(
        Turetilenler.savunmaCapasi *
            Turetilenler.referansEhpCarpani /
            Turetilenler.saldiriPuaniDps,
        closeTo(TasarimGirdileri.referansTTK, 1e-9),
      );
      // Süre BUILD'e değil kura bağlı: fiyat tek bir yerden okunuyor.
      expect(
        ItemBudget.birimFiyati('kalkan_yenilenmesi'),
        Turetilenler.puanBasinaKalkanYenilenmesi,
      );
    });
  });

  group('03.6 · birim tipine göre uygulama', () {
    // KARAR 03.6 s1
    test('fiyatın birimi, kaydın birimi: iki okuyucu tek kaydı okuyor', () {
      // Fiyat türevinin ADIMI kayıttan (ItemBudget.turevAdimi), uygulama da
      // aynı kayıttan (StatBirimi.uygula). Bir mutlak stata kesir fiyatı
      // vermek, ya da tersi, tek satırda mümkün değil.
      final hull = HullClass.bastion;
      for (final s in Stats.all) {
        final adim = ItemBudget.turevAdimi(s);
        expect(adim, s.birim == StatBirimi.oran ? 0.001 : 1.0, reason: s.id);
      }

      final v = StatVector()
        ..add(
          'govde_cani',
          StatScope.gemi,
          ItemBudget.birimFiyati('govde_cani'),
        )
        ..add(
          'hasar_artisi',
          StatScope.gemi,
          ItemBudget.birimFiyati('hasar_artisi'),
        )
        ..add('zirh', StatScope.gemi, ItemBudget.birimFiyati('zirh'));
      final s = LoadoutResolver.apply(hull, v, equippedLasers: 5);

      // Mutlak puan: havuza doğrudan ekleniyor.
      expect(Stats.maxHull.birim, StatBirimi.mutlak);
      expect(
        s.maxHull - hull.baseHull,
        closeTo(ItemBudget.birimFiyati('govde_cani'), 1e-9),
      );
      // Oran: kesir olarak çarpana giriyor.
      expect(Stats.damageBonus.birim, StatBirimi.oran);
      expect(
        s.damageBonus,
        closeTo(ItemBudget.birimFiyati('hasar_artisi'), 1e-12),
      );
      expect(s.damageBonus, lessThan(0.01), reason: 'oran puan gibi uygulandı');
      // Eğri: HAM puan giriyor, azaltma oranı eğriden çıkıyor.
      expect(Stats.armor.birim, StatBirimi.egri);
      expect(s.armor, closeTo(ItemBudget.birimFiyati('zirh'), 1e-9));
      expect(
        s.armorReduction,
        closeTo(SavunmaEgrileri.doyum(s.armor, Turetilenler.kZirh), 1e-12),
      );
    });
  });
}
