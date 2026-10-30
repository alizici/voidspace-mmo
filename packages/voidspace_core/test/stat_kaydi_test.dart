@Tags(['yabanci-anahtar', 'kapsam', 'kod-belge'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 02 · STAT KÜTÜPHANESİ — kayıt sekiz alan, motor kaydı okur.
///
/// Belge: docs/02-stat-kutuphanesi.md. Kayıt kategorik bir tablo; burada
/// sayı değil YAPI denetleniyor: birim, kapsam, eş, alt stat ve ayrılmış
/// kimliklerin kapalı kalması. Tablonun kendisiyle karşılaştırma kökteki
/// `test/stat_kaydi_belge_test.dart`ta.
void main() {
  group('02.1 · kimlik ile etiket', () {
    // KARAR 02.1 s1
    test('kimlik makine anahtarı, etiket yalnız ekranda', () {
      for (final s in Stats.hepsi) {
        // Kimlik tel ve disk biçiminde: küçük harf, alt çizgi, Türkçe harf
        // yok. Etiket insan biçiminde ve ikisi asla aynı dize değil.
        expect(
          RegExp(r'^[a-z0-9_]+$').hasMatch(s.id),
          isTrue,
          reason: '${s.id} kimliği kayıt anahtarı olamaz',
        );
        expect(s.label, isNotEmpty, reason: s.id);
        expect(
          s.label,
          isNot(s.id),
          reason: '${s.id} etiketi kimliğin kopyası',
        );
        // Aramanın tek anahtarı KİMLİK: etiket yarın başka bir dile çevrilse
        // hiçbir kayıt kopmamalı.
        expect(Stats.byId(s.label), isNull, reason: s.label);
        expect(Stats.kayit(s.label), isNull, reason: s.label);
      }
      // Kimlikler benzersiz: iki satır aynı kimliği taşırsa hangi katmanın
      // geçerli olduğu çağıranın sırasına kalır.
      expect(
        Stats.hepsi.map((s) => s.id).toSet(),
        hasLength(Stats.hepsi.length),
      );
    });

    // KARAR 02.1 s1
    test('diske yazılan şey KİMLİK — etiket serileşmiyor', () {
      const esya = ItemInstance(
        instanceId: 'ornek-01',
        specId: 'pl1',
        altStatRolleri: {'kritik_hasari': 0.8},
      );
      final json = esya.toJson().toString();
      expect(json, contains('kritik_hasari'));
      expect(
        json,
        isNot(contains(Stats.critMultiplier.label)),
        reason: 'etiket diske sızdı — çeviri kayıtları kırar',
      );
      expect(ItemInstance.fromJson(esya.toJson()).altStatRolleri.keys, [
        'kritik_hasari',
      ]);
    });

    // KARAR 02.1 s1
    test(
      'katman ve kanal alan 01\'den — kütüphane kendi katmanını tanımlamaz',
      () {
        // 02 onları KULLANIR, tanımlamaz: katman sayısı ve sırası zincirin
        // kararı. Kütüphanenin kullandığı katmanlar zincirin katmanlarının
        // alt kümesi olmak zorunda.
        expect(StatLayer.values.length, DamageChain.layerCount);
        final kullanilan = Stats.hepsi.map((s) => s.layer).toSet();
        expect(kullanilan.difference(StatLayer.values.toSet()), isEmpty);
        for (final s in Stats.hepsi) {
          expect(
            RegExp(r'^L[0-5]$').hasMatch(s.layer.code),
            isTrue,
            reason: s.id,
          );
          expect(StatChannel.values, contains(s.channel), reason: s.id);
        }
      },
    );
  });

  group('02.2 · birim', () {
    // KARAR 02.2 s1
    test('üç birim, her birinin TEK bir uygulaması var', () {
      expect(StatBirimi.values, hasLength(3));
      expect(StatBirimi.mutlak.uygula(100, 5), 105);
      expect(StatBirimi.oran.uygula(100, 0.5), 150);
      // Eğri: ham puan girer, ORAN çıkar; K kadar puan tam yarısı, sonsuz
      // puan bile bire varmaz.
      final k = Turetilenler.kZirh;
      expect(StatBirimi.egri.uygula(0, k, k: k), closeTo(0.5, 1e-12));
      expect(StatBirimi.egri.uygula(0, 1e9, k: k), lessThan(1));
    });

    // KARAR 02.2 s1 · KARAR 03.6 s1
    test('çözümleyici havuz statlarını KAYDIN birimiyle uyguluyor', () {
      final hull = HullClass.bastion;
      const ref = ShipStats.bastion;
      final v = StatVector()
        ..add('govde_cani', StatScope.gemi, 500)
        ..add('kalkan', StatScope.gemi, 300)
        ..add('hiz', StatScope.gemi, 0.10)
        ..add('itki_dolumu', StatScope.gemi, 0.25)
        ..add('atis_hizi', StatScope.gemi, 0.5)
        ..add('menzil', StatScope.gemi, 0.2)
        ..add('kalkan_yenilenmesi', StatScope.gemi, 0.3)
        ..add('zirh', StatScope.gemi, Turetilenler.kZirh);
      final s = LoadoutResolver.apply(hull, v, equippedLasers: 5);

      // Mutlak: toplanır.
      expect(Stats.maxHull.birim, StatBirimi.mutlak);
      expect(s.maxHull, hull.baseHull + 500);
      expect(Stats.maxShield.birim, StatBirimi.mutlak);
      expect(s.maxShield, hull.baseShield + 300);
      // Oran: çarpar; sürelerde böler.
      expect(Stats.speed.birim, StatBirimi.oran);
      expect(s.speed, closeTo(hull.baseSpeed * 1.10, 1e-9));
      expect(Stats.boostRecharge.birim, StatBirimi.oran);
      expect(s.boostRecharge, closeTo(ref.boostRecharge / 1.25, 1e-9));
      expect(s.laser.fireInterval, closeTo(ref.laser.fireInterval / 1.5, 1e-9));
      expect(s.laser.range, closeTo(ref.laser.range * 1.2, 1e-9));
      expect(
        s.shieldRegenPerSecond,
        closeTo(ref.shieldRegenPerSecond * 1.3, 1e-9),
      );
      // Eğri: ham puan geçer, gemi statında eğriden çıkar; K puan = yarısı.
      expect(Stats.armor.birim, StatBirimi.egri);
      expect(s.armor, Turetilenler.kZirh);
      expect(s.armorReduction, closeTo(0.5, 1e-12));
    });

    // KARAR 02.2 s1
    test('arayüzün "yüzde mi" sorusu birimden türüyor', () {
      for (final s in Stats.hepsi) {
        expect(s.percent, s.birim == StatBirimi.oran, reason: s.id);
      }
    });

    // KARAR 02.2 s1
    test('kayıt SEKİZ alan ve dördü kurucuda zorunlu', () {
      // Kimlik · etiket · katman · kanal · birim · kapsam · eş · alt stat.
      // Katman, kanal, birim ve eş zorunlu olduğu için eksik kayıt
      // DERLENMİYOR; burada denetlenen şey alanların anlamlı dolduğu.
      for (final s in Stats.hepsi) {
        expect(s.id, isNotEmpty);
        expect(s.label, isNotEmpty, reason: s.id);
        expect(StatLayer.values, contains(s.layer), reason: s.id);
        expect(StatChannel.values, contains(s.channel), reason: s.id);
        expect(StatBirimi.values, contains(s.birim), reason: s.id);
        expect(s.kapsam, isNotEmpty, reason: '${s.id} kapsamsız');
        expect(s.es.id, isNotEmpty, reason: '${s.id} eşsiz');
      }
      // Sekizinci alan AYIRT EDİCİ olmak zorunda: hepsi aynı değeri
      // taşısaydı bayrak bir alan değil bir süs olurdu.
      expect(Stats.hepsi.where((s) => s.altStat), isNotEmpty);
      expect(Stats.hepsi.where((s) => !s.altStat), isNotEmpty);
    });
  });

  group('02.3 · kapsam', () {
    // KARAR 02.3 s2
    test('adlar tasarımın dilinde: gemi · droid · roket · küresel', () {
      // Roket üçüncü kapsam (18.1, 02.3 s2): geminin ikinci silahının tabanı.
      expect(StatScope.values.map((s) => s.name), [
        'gemi',
        'droid',
        'roket',
        'kuresel',
      ]);
    });

    // KARAR 02.3 s2
    test('kayıt dışı kapsama yazmak REDDEDİLİYOR', () {
      final v = StatVector();
      // Hız gemiye ait: droid grubunun konumu gemininki, kendi hızı yok.
      // (Kalkan artık iki kapsamda — droide kalkan jeneratörü giriyor,
      // 05.4 s5.)
      expect(Stats.speed.kapsam, {StatScope.gemi});
      expect(() => v.add('hiz', StatScope.droid, 1), throwsArgumentError);
      v.add('hiz', StatScope.gemi, 1);
      expect(v.get('hiz'), 1);
      // Kütüphanede olmayan kimlik burada serbest: yabancı anahtar testinin işi.
      v.add('yok_boyle_stat', StatScope.droid, 1);
    });

    // KARAR 02.3 s2
    test('hiçbir saldırı statı KÜRESEL kapsamda değil', () {
      for (final s in Stats.hepsi) {
        if (s.channel == StatChannel.attack) {
          expect(s.kapsam, isNot(contains(StatScope.kuresel)), reason: s.id);
        }
        expect(s.kapsam, isNotEmpty, reason: '${s.id} kapsamsız');
      }
    });

    // KARAR 02.3 s2
    test('kimlik + kapsam bir yuva: aynı stat iki kapsamda İKİ ayrı sayı', () {
      // Droid'e takılan bir hasar çipi geminin hasarını artırmamalı; tersi
      // de geçerli. Kapsam anahtarın parçası olduğu için çift sayım bir hata
      // olmaktan çıkıp imkânsız hâle geliyor.
      final v = StatVector();
      v.add('hasar_artisi', StatScope.gemi, 0.15);
      expect(v.get('hasar_artisi', StatScope.gemi), closeTo(0.15, 1e-12));
      expect(
        v.get('hasar_artisi', StatScope.droid),
        0,
        reason: 'droid geminin bonusunu gördü — çift sayım kapısı açık',
      );
      v.add('hasar_artisi', StatScope.droid, 0.40);
      expect(v.get('hasar_artisi', StatScope.gemi), closeTo(0.15, 1e-12));
      expect(v.get('hasar_artisi', StatScope.droid), closeTo(0.40, 1e-12));
      // Anahtarın kendisi kapsamı taşıyor: yanlış kapsama yazmak isteyen
      // kodun anahtarı da yanlış üretmesi gerekir.
      expect(
        StatVector.key('hasar_artisi', StatScope.gemi),
        isNot(StatVector.key('hasar_artisi', StatScope.droid)),
      );
    });

    // KARAR 02.3 s2
    test(
      'roket üçüncü kapsam: roketatarın tabanı lazerin yaylımına karışmaz',
      () {
        // `taban_hasar@roket` ile `taban_hasar@gemi` aynı zincirin başına
        // FARKLI silahlar olarak giriyor, aynı anahtara asla.
        final v = StatVector();
        v.add('taban_hasar', StatScope.roket, 300);
        expect(v.get('taban_hasar', StatScope.gemi), 0);
        expect(v.get('taban_hasar', StatScope.roket), 300);
        expect(Stats.baseDamage.kapsam, contains(StatScope.roket));
        // Kalkan roket kapsamı tanımıyor: kayıt ikinci kilit.
        expect(() => v.add('kalkan', StatScope.roket, 1), throwsArgumentError);
      },
    );
  });

  group('02.4 · eş', () {
    // KARAR 02.4 s1
    test('her açık statın eşi AÇIK kütüphanede ve kendisi değil', () {
      for (final s in Stats.all) {
        expect(
          Stats.byId(s.es.id),
          isNotNull,
          reason: '${s.id} eşi (${s.es}) kütüphanede yok — ölü stat adayı',
        );
        expect(s.es.id, isNot(s.id), reason: '${s.id} kendine eş');
      }
    });

    // KARAR 02.4 s1
    test('ayrılmış statların eşi kayıtta', () {
      for (final s in Stats.ayrilmis) {
        expect(
          Stats.kayit(s.es.id),
          isNotNull,
          reason: '${s.id} eşi (${s.es}) kayıtta yok',
        );
      }
    });

    // KARAR 02.4 s1
    test('taşma eşi henüz yok — kafesle gelecek', () {
      expect(Stats.hepsi.where((s) => s.es.tur == EsTuru.tasma), isEmpty);
    });

    // KARAR 02.4 s1
    test('karşı statlar KARŞILIKLI ve iki kanalın iki yüzü', () {
      // Karşı stat rakibin statını iptal ediyor; fark hesabı kafesle gelecek
      // ama ilan bugünden. Tek yönlü bir ilan, kafes yazılırken hangi statın
      // hangisini iptal ettiğini belirsiz bırakırdı.
      const karsiliklilar = {
        'son_hasar': 'son_azaltma',
        'son_azaltma': 'son_hasar',
        'delici': 'sertlik',
        'sertlik': 'delici',
        'kirici': 'zirh_katmani',
        'zirh_katmani': 'kirici',
        'durum_hasari': 'durum_azaltma',
        'durum_azaltma': 'durum_hasari',
      };
      for (final s in Stats.hepsi) {
        if (s.es.tur != EsTuru.karsi) continue;
        final karsi = Stats.kayit(s.es.id);
        expect(karsi, isNotNull, reason: '${s.id} karşısı kayıtta yok');
        expect(
          karsi!.channel,
          isNot(s.channel),
          reason: '${s.id} ↔ ${karsi.id} aynı kanalda — karşı stat olamaz',
        );
        final beklenen = karsiliklilar[s.id];
        if (beklenen != null) {
          expect(s.es.id, beklenen, reason: s.id);
          expect(karsi.es.id, s.id, reason: '${s.id} ↔ ${karsi.id} tek yönlü');
        }
      }
      // Kritik direnci tek yönlü ve bilerek: karşısı AÇIK bir stat ve onun
      // eşi build içi (kritik şansı ↔ kritik hasarı).
      expect(Stats.kritikDirenci.es.id, 'kritik_sansi');
      expect(Stats.critChance.es.tur, EsTuru.buildIci);
    });

    // KARAR 02.4 s1
    test('belgedeki build içi çiftler kayıtta', () {
      // Kafes yok, dolayısıyla açık statlar build içi eşle giriyor: birine
      // yatırım ötekinin türevini büyütüyor.
      const cift = {
        'kritik_sansi': 'kritik_hasari',
        'kritik_hasari': 'kritik_sansi',
        'zirh': 'govde_cani',
        'govde_cani': 'zirh',
        'atis_hizi': 'taban_hasar',
        'hiz': 'itki_dolumu',
        'itki_dolumu': 'hiz',
        'taban_hasar': 'hasar_artisi',
        'hasar_artisi': 'taban_hasar',
        'kalkan': 'kalkan_yenilenmesi',
        'kalkan_yenilenmesi': 'kalkan',
      };
      cift.forEach((id, es) {
        final s = Stats.byId(id);
        expect(s, isNotNull, reason: id);
        expect(s!.es.tur, EsTuru.buildIci, reason: id);
        expect(s.es.id, es, reason: '$id eşi değişmiş');
      });
    });
  });

  group('02.5 · genişleme şartları', () {
    // KARAR 02.5 s1
    test('bir kayıt satırının DÖRT şartı: katman · birim · eş · kanal', () {
      // Yeni bir stat eklemek tek bir kayıt satırı; satırın geçerli olması
      // için dört şart. Dördüncüsü en çok atlananı: ölçülebilir kanala
      // bağlanmayan stat birkaç ay içinde ölü stattır — oyuncu kıyaslayamaz,
      // denge göremez, kimse yatırım yapmaz.
      for (final s in Stats.all) {
        // 1 · katmanı var, ve alan 01'in katmanlarından biri: yeni katman
        // açılmıyor.
        expect(StatLayer.values, contains(s.layer), reason: s.id);
        // 2 · birimi var ve motor ona göre uyguluyor.
        expect(StatBirimi.values, contains(s.birim), reason: s.id);
        // 3 · eşi var ve kütüphanede duruyor (02.4).
        expect(
          Stats.kayit(s.es.id),
          isNotNull,
          reason: '${s.id} eşsiz — ölü stat adayı',
        );
        // 4 · ölçülebilir bir kanala bağlı, yani BR'ye giriyor.
        expect(StatChannel.values, contains(s.channel), reason: s.id);
        expect(
          ItemBudget.birimFiyati(s.id),
          greaterThan(0),
          reason: '${s.id} fiyatsız — bütçe ona dağıtamaz, ölü stat adayı',
        );
      }
      expect(StatLayer.values.length, DamageChain.layerCount);
    });
  });

  group('02.6 · ayrılmış kimlikler', () {
    const beklenen = {
      'delici',
      'sertlik',
      'kirici',
      'zirh_katmani',
      'kritik_direnci',
      'durum_hasari',
      'durum_azaltma',
    };

    // KARAR 02.6 s1
    test('yedi kimlik, kayıtta yazılı', () {
      expect(Stats.ayrilmis.map((s) => s.id).toSet(), beklenen);
      for (final id in beklenen) {
        expect(Stats.kayit(id), isNotNull, reason: id);
      }
    });

    // KARAR 02.6 s1
    test('KAPALI: aramada yok, havuzda yok, ana stat değil, fiyatsız', () {
      for (final id in beklenen) {
        expect(
          Stats.byId(id),
          isNull,
          reason: '$id açık aramada bulundu — sağlayıcı ona ulaşabilir',
        );
        expect(ItemBudget.birimFiyati(id), 0, reason: '$id fiyatlanmış');
        for (final spec in Catalogue.items) {
          expect(
            spec.mainStat,
            isNot(id),
            reason: '${spec.id} ayrılmış statı ana stat yapmış',
          );
          expect(
            spec.subStatPool,
            isNot(contains(id)),
            reason: '${spec.id} havuzuna ayrılmış stat sızmış',
          );
        }
      }
    });

    // KARAR 02.6 s1
    test('koşullu katmanın açık kiracısı yok; ayrılmış ikisi orada', () {
      expect(Stats.inLayer(StatLayer.conditional), isEmpty);
      expect(
        Stats.ayrilmis.where((s) => s.layer == StatLayer.conditional),
        hasLength(2),
      );
    });
  });

  group('02.7 · kayıt tablosu', () {
    // KARAR 02.7 s2
    test('on beş açık, yedi ayrılmış, yirmi iki BENZERSİZ kimlik', () {
      expect(Stats.all, hasLength(15));
      expect(Stats.ayrilmis, hasLength(7));
      final ids = Stats.hepsi.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(22), reason: 'yinelenen kimlik');
    });

    // KARAR 02.7 s2
    test('alt stat bayrağı havuzlarla tutuyor', () {
      for (final spec in Catalogue.items) {
        for (final id in spec.subStatPool) {
          expect(
            Stats.byId(id)?.altStat,
            isTrue,
            reason: '$id ${spec.id} havuzunda ama kayıt alt stat demiyor',
          );
        }
        expect(
          spec.subStatPool,
          isNot(contains('taban_hasar')),
          reason: '${spec.id}: taban hasar lazerin tekelinde (04.2)',
        );
      }
      expect(Stats.baseDamage.altStat, isFalse);
    });

    // KARAR 02.7 s2
    test('itki dolumu AÇIK: sistem kanalı, katsayılı, fiyatlı', () {
      final s = Stats.boostRecharge;
      expect(s.id, 'itki_dolumu');
      expect(s.channel, StatChannel.system);
      expect(
        CombatGlossary.sistemPuani(itkiYuzde: 10),
        closeTo(10 * TasarimGirdileri.sistemKatsayisiItki, 1e-12),
      );
      expect(
        TasarimGirdileri.sistemKatsayisiItki,
        lessThan(TasarimGirdileri.sistemKatsayisiHiz),
      );
      // Katsayısı küçük olan statın puanı daha çok oran alır.
      expect(
        ItemBudget.birimFiyati('itki_dolumu'),
        greaterThan(ItemBudget.birimFiyati('hiz')),
      );
    });

    // KARAR 02.7 s2
    test('yirmi iki satır BİREBİR: katman · kanal · birim · kapsam · eş', () {
      // Belgedeki kayıt tablosu burada. Buradaki bir satır değişirse kayıt,
      // kayıt değişirse burası kırılır — tablo ile kod arasında sessiz bir
      // ayrışma kalmıyor.
      const kanalAdi = {
        StatChannel.attack: 'saldırı',
        StatChannel.defence: 'savunma',
        StatChannel.system: 'sistem',
      };
      const tablo = {
        // AÇIK on beş
        'taban_hasar': 'L0|saldırı|mutlak|gemi droid roket|hasar_artisi|hayır',
        'hasar_artisi': 'L1|saldırı|oran|gemi droid|taban_hasar|evet',
        'atis_hizi': 'L1|saldırı|oran|gemi droid|taban_hasar|evet',
        'kritik_sansi': 'L3|saldırı|oran|gemi droid|kritik_hasari|evet',
        'kritik_hasari': 'L3|saldırı|oran|gemi droid|kritik_sansi|evet',
        'son_hasar': 'L5|saldırı|mutlak|gemi|karşı: son_azaltma|evet',
        'govde_cani': 'L0|savunma|mutlak|gemi droid|zirh|evet',
        'kalkan': 'L0|savunma|mutlak|gemi droid|kalkan_yenilenmesi|evet',
        'kalkan_yenilenmesi': 'L1|savunma|oran|gemi|kalkan|evet',
        'zirh': 'L4|savunma|egri|gemi droid|govde_cani|evet',
        'kacinma': 'L4|savunma|egri|gemi|zirh|evet',
        'son_azaltma': 'L5|savunma|mutlak|gemi|karşı: son_hasar|evet',
        'hiz': 'L1|sistem|oran|gemi|itki_dolumu|evet',
        'itki_dolumu': 'L1|sistem|oran|gemi|hiz|evet',
        'menzil': 'L1|sistem|oran|gemi droid|hiz|evet',
        // AYRILMIŞ yedi (02.6) — katman ve eş ilk yerleşim
        'delici': 'L4|saldırı|oran|gemi droid|karşı: sertlik|evet',
        'sertlik': 'L4|savunma|egri|gemi droid|karşı: delici|evet',
        'kirici': 'L4|saldırı|oran|gemi droid|karşı: zirh_katmani|evet',
        'zirh_katmani': 'L4|savunma|egri|gemi droid|karşı: kirici|evet',
        'kritik_direnci': 'L3|savunma|oran|gemi droid|karşı: kritik_sansi|evet',
        'durum_hasari': 'L2|saldırı|oran|gemi droid|karşı: durum_azaltma|evet',
        'durum_azaltma': 'L2|savunma|oran|gemi droid|karşı: durum_hasari|evet',
      };
      expect(Stats.hepsi.map((s) => s.id).toSet(), tablo.keys.toSet());
      for (final s in Stats.hepsi) {
        final kapsam = s.kapsam.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        final satir = [
          s.layer.code,
          kanalAdi[s.channel],
          s.birim.name,
          kapsam.map((k) => k.name).join(' '),
          s.es.toString(),
          s.altStat ? 'evet' : 'hayır',
        ].join('|');
        expect(satir, tablo[s.id], reason: '${s.id} kaydı tablodan ayrıştı');
      }
    });

    // KARAR 02.7 s2
    test('menzil SİSTEM kanalında — hasarı artırmıyor', () {
      // Sınıflandırma zevki değil ölçüm sonucu: ∂DPS/∂menzil = 0.
      expect(Stats.range.channel, StatChannel.system);
      const ref = ShipStats.bastion;
      expect(
        CombatGlossary.expectedDps(ref.copyWith(rangeBonus: 5)),
        closeTo(CombatGlossary.expectedDps(ref), 1e-9),
      );
    });
  });

  group('02.8 · kritik çarpanının kimliği', () {
    // KARAR 02.8 s3
    test('kimlik kritik_hasari — eski ad hiçbir yerde kalmadı', () {
      // Aynı stat bir süre iki adla yaşadı: tasarım `kritik_hasari`, kod
      // `kritik_carpani`. Belge kaynak, kod uydu. Kimlik artık kararlı:
      // bundan sonra ad değiştirmek göç demek.
      expect(Stats.critMultiplier.id, 'kritik_hasari');
      expect(Stats.critMultiplier.label, 'Kritik hasarı');
      expect(Stats.kayit('kritik_carpani'), isNull, reason: 'eski ad kayıtta');
      expect(ItemBudget.birimFiyati('kritik_carpani'), 0);
      for (final spec in Catalogue.items) {
        expect(spec.mainStat, isNot('kritik_carpani'), reason: spec.id);
        expect(
          spec.subStatPool,
          isNot(contains('kritik_carpani')),
          reason: '${spec.id} havuzunda eski ad',
        );
      }
    });

    // KARAR 02.8 s3
    test('kimlik artık havuzlarda ve fiyatlı — ad değiştirmek göç', () {
      // Değişiklik bedavaydı çünkü stat o gün hiçbir havuzda değildi. Bugün
      // havuzlarda: taşıdığı veri var.
      final yuvalar = {
        for (final spec in Catalogue.items)
          if (spec.subStatPool.contains('kritik_hasari')) spec.slot,
      };
      expect(yuvalar, contains(SlotType.laser));
      expect(yuvalar, contains(SlotType.launcher));
      // Üçüncüsü DROİD, CPU değil: 02.8'in cümlesi buna göre düzeldi.
      expect(yuvalar, contains(SlotType.droid));
      expect(yuvalar, isNot(contains(SlotType.cpu)));
      expect(ItemBudget.birimFiyati('kritik_hasari'), greaterThan(0));
      expect(Stats.byId('kritik_hasari'), isNotNull);
    });
  });

  group('03.6 · birim sözleşmesi', () {
    // KARAR 03.6 s1
    test('fiyat türevinin adımı birimden: oran kesirle, diğerleri puanla', () {
      for (final s in Stats.all) {
        final adim = ItemBudget.turevAdimi(s);
        if (s.birim == StatBirimi.oran) {
          expect(adim, lessThan(1), reason: s.id);
        } else {
          expect(adim, 1, reason: s.id);
        }
      }
    });
  });
}
