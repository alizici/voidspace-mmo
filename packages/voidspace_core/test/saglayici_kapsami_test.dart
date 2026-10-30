@Tags(['kapsam', 'yabanci-anahtar'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ALAN 05 · SIZINTI YASAĞI ve UNVANIN SESSİZLİĞİ.
///
/// Alanın bir numaralı hatası sızıntı: droide takılan bir çipin gemiyi de
/// büyütmesi, ya da geminin bonusunun droid sayısıyla çarpılıp patlaması.
/// Kötülüğü fark edilmesinin uzun sürmesi — sonucu yalnız "droid build'i çok
/// güçlü" gibi bulanık bir şikâyet olarak görünüyor. Kapsam anahtarın parçası
/// olduğu için tek denetim bütün sağlayıcıları koruyor.
void main() {
  final hull = HullClass.bastion;

  /// Gemi yuvalarındaki eşyalar — dört tipin dördü de dolu.
  final gemiEnvanteri = <String, ItemInstance>{
    'lz': const ItemInstance(instanceId: 'lz', specId: 'pl1'),
    'jn': const ItemInstance(instanceId: 'jn', specId: 'df1'),
    'rk': const ItemInstance(instanceId: 'rk', specId: 'mk1'),
    'cp': const ItemInstance(instanceId: 'cp', specId: 'cpu_repair'),
  };
  const gemiYuvalari = {
    'laser#0': 'lz',
    'generator#0': 'jn',
    'launcher#0': 'rk',
    'cpu#0': 'cp',
  };

  /// [key]'in `stat@kapsam` biçimindeki kapsam eki.
  StatScope kapsamOfKey(String key) => StatScope.values.firstWhere(
    (s) => key.endsWith('@${s.name}'),
    orElse: () => throw StateError('kapsamsız anahtar: $key'),
  );

  group('05.3 · kapsam kuralları ve sızıntı yasağı', () {
    // KARAR 05.3 s1
    test('kapsam ANAHTARIN parçası — aynı stat iki kapsamda ayrı sayı', () {
      // Sızıntı testini tek denetime indiren şey bu: kapsam anahtarda
      // olmasaydı her sağlayıcı için ayrı bir muhasebe gerekirdi.
      expect(
        StatVector.key('zirh', StatScope.gemi),
        isNot(StatVector.key('zirh', StatScope.droid)),
      );
      final v = StatVector()..add('zirh', StatScope.gemi, 40);
      expect(v.get('zirh', StatScope.gemi), 40);
      expect(v.get('zirh', StatScope.droid), 0, reason: 'kapsam sızdı');
    });

    // KARAR 05.3 s1
    test('gemi yuvalarındaki eşya DROİD kapsamına hiçbir şey yazmıyor', () {
      // "Bugün tek sağlayıcı yuvadaki eşya ve tek kapsam gemi; çözücü bütün
      // eşya statlarını o kapsama yazıyor."
      final v = LoadoutResolver.vectorOf(
        Loadout(hullId: hull.id, slots: gemiYuvalari),
        gemiEnvanteri,
        Catalogue.byId,
      );
      expect(v.entries, isNotEmpty);
      for (final e in v.entries) {
        expect(
          kapsamOfKey(e.key),
          isNot(StatScope.droid),
          reason: '${e.key} gemi eşyasından droid kapsamına sızdı',
        );
      }
    });

    // KARAR 05.3 s1
    test('filodaki droid GEMİ kapsamına hiçbir şey yazmıyor', () {
      final v = LoadoutResolver.vectorOf(
        Loadout(hullId: hull.id),
        {'d': const ItemInstance(instanceId: 'd', specId: 'dr1')},
        Catalogue.byId,
        filo: const ['d'],
      );
      expect(v.entries, isNotEmpty);
      for (final e in v.entries) {
        expect(
          kapsamOfKey(e.key),
          StatScope.droid,
          reason: '${e.key} droidden gemi kapsamına sızdı',
        );
      }
    });

    // KARAR 05.3 s1
    test('her anahtarın kapsamı SAĞLAYICI KAYDINDAKİ kapsam', () {
      // Kayıt: eşya → gemi, droid → droid. Tek istisna roketatarın ana statı
      // (05.4, 18.1) ve o da kaydın değil yuvanın kararı.
      final v = LoadoutResolver.vectorOf(
        Loadout(hullId: hull.id, slots: gemiYuvalari),
        {
          ...gemiEnvanteri,
          'd': const ItemInstance(instanceId: 'd', specId: 'dr1'),
        },
        Catalogue.byId,
        filo: const ['d'],
      );
      final gorulen = {for (final e in v.entries) kapsamOfKey(e.key)};
      expect(gorulen, contains(Saglayici.esya.kapsam));
      expect(gorulen, contains(Saglayici.droid.kapsam));
      // Küresel kapsama kimse yazmıyor: küresel bir hasar statı kapsam
      // ayrımını tek satırda anlamsız kılardı.
      expect(gorulen, isNot(contains(StatScope.kuresel)));
      final roketAnahtarlari = [
        for (final e in v.entries)
          if (kapsamOfKey(e.key) == StatScope.roket) e.key,
      ];
      expect(
        roketAnahtarlari,
        [StatVector.key(Catalogue.mk1.mainStat, StatScope.roket)],
        reason: 'roket kapsamı yalnız roketatarın ana statını taşımalı',
      );
    });

    // KARAR 05.3 s1
    test('geminin bonusu DROİD SAYISIYLA çarpılmıyor', () {
      // Alanın adıyla andığı ikinci sızıntı biçimi. Filoyu on katına
      // çıkarmak gemi kapsamındaki hiçbir sayıyı kıpırdatmamalı.
      final envanter = <String, ItemInstance>{
        ...gemiEnvanteri,
        for (var i = 0; i < TasarimGirdileri.droidFiloTavani; i++)
          'd$i': ItemInstance(instanceId: 'd$i', specId: 'dr1'),
      };
      Map<String, double> gemiKapsami(List<String> filo) {
        final v = LoadoutResolver.vectorOf(
          Loadout(hullId: hull.id, slots: gemiYuvalari),
          envanter,
          Catalogue.byId,
          filo: filo,
        );
        return {
          for (final e in v.entries)
            if (kapsamOfKey(e.key) == StatScope.gemi) e.key: e.value,
        };
      }

      final filosuz = gemiKapsami(const []);
      final doluFilo = gemiKapsami([
        for (var i = 0; i < TasarimGirdileri.droidFiloTavani; i++) 'd$i',
      ]);
      expect(filosuz, isNotEmpty);
      expect(doluFilo, filosuz, reason: 'filo gemi kapsamını büyüttü');
    });

    // KARAR 05.3 s1
    test('sağlayıcı kaydının tanımadığı kapsama yazmak REDDEDİLİYOR', () {
      // "Yanlış kapsama yazmak isteyen kodun önce kaydı değiştirmesi
      // gerekiyor" — sızıntı sessizce açılamıyor.
      final tabanHasar = Stats.byId('taban_hasar')!;
      final yasak = StatScope.values.firstWhere(
        (s) => !tabanHasar.kapsam.contains(s),
      );
      expect(
        () => StatVector().add('taban_hasar', yasak, 1),
        throwsArgumentError,
      );
    });
  });

  group('05.6 · unvan stat vermez', () {
    // KARAR 05.6 s1
    test('unvan sağlayıcı DEĞİL: kayıtta yok', () {
      // Sağlayıcı kaydı motorun okuduğu tek liste; unvan orada olmadığı için
      // hiçbir vektöre yazamıyor.
      expect(Saglayici.hepsi, hasLength(3));
      for (final kayit in Saglayici.hepsi) {
        expect(kayit.kimlik, isNot('unvan'), reason: kayit.kaynak);
        expect(kayit.kaynak.toLowerCase(), isNot(contains('unvan')));
      }
    });

    // KARAR 05.6 s1
    test('unvan YALNIZ BR\'den okunuyor — tek girdi, tek yön', () {
      // Döngü: statlar → BR → unvan eşiği → unvan statı → statlar. Son ok
      // yoksa döngü yok; unvan sorgusunun BR dışında bir girdisi de yok.
      for (var i = 0; i < TasarimGirdileri.unvanSayisi; i++) {
        expect(
          CombatGlossary.unvanIndeksi(CombatGlossary.unvanEsigi(i)),
          i,
          reason: 'unvan $i eşiğini tutturan oyuncu unvanını almıyor',
        );
        if (i > 0) {
          expect(
            CombatGlossary.unvanEsigi(i),
            greaterThan(CombatGlossary.unvanEsigi(i - 1)),
          );
        }
      }
      // Unvan yalnız ad ve çağ veriyor: erişim ve görünüm, güç değil.
      expect(Unvan.adi(0), isNotEmpty);
      expect(Unvan.caglar, hasLength(4));
    });

    // KARAR 05.6 s1
    test('unvanı yükselten eşya BR\'yi büyütüyor, statı unvan büyütmüyor', () {
      // Ölçüt: aynı donatım aynı statları veriyor; oyuncunun ilerleme durumu
      // (xp, seviye, dolayısıyla unvan bandı) hiçbir sayıya girmiyor.
      final envanter = {
        'lz': const ItemInstance(instanceId: 'lz', specId: 'pl1'),
      };
      final loadout = Loadout(hullId: hull.id, slots: const {'laser#0': 'lz'});
      final zayif = LoadoutResolver.resolve(loadout, envanter, Catalogue.byId);

      // Merdivenin tepesindeki tasarımlarla TAM dolu bir gövde: unvan
      // bandını gerçekten geçsin diye.
      final ustEnvanter = <String, ItemInstance>{};
      final ustYuvalar = <String, String>{};
      for (final tip in SlotType.values.where((t) => t != SlotType.droid)) {
        final enIyi = Catalogue.items
            .where((s) => s.slot == tip)
            .reduce((a, b) => a.tier.index >= b.tier.index ? a : b);
        for (var i = 0; i < hull.slotCount(tip); i++) {
          final kimlik = '${tip.name}$i';
          ustEnvanter[kimlik] = ItemInstance(
            instanceId: kimlik,
            specId: enIyi.id,
            level: ItemLevels.max,
          );
          ustYuvalar['${tip.name}#$i'] = kimlik;
        }
      }
      final guclu = LoadoutResolver.resolve(
        Loadout(hullId: hull.id, slots: ustYuvalar),
        ustEnvanter,
        Catalogue.byId,
      );
      final zayifUnvan = CombatGlossary.unvanIndeksi(
        CombatGlossary.battleRating(zayif),
      );
      final gucluUnvan = CombatGlossary.unvanIndeksi(
        CombatGlossary.battleRating(guclu),
      );
      expect(
        gucluUnvan,
        greaterThan(zayifUnvan),
        reason: 'kurulum unvan eşiği geçmiyor — test bir şey ölçmüyor',
      );

      // Unvanı yükselen oyuncunun statları, aynı donatımın verdiğinin
      // AYNISI: unvan geri beslemiyor.
      for (final xp in [0, 1 << 40]) {
        final hangar = Hangar(
          accountId: 'a',
          xp: xp,
          inventory: {...envanter},
          loadouts: {hull.id: loadout},
        );
        final tekrar = LoadoutResolver.resolve(
          hangar.activeLoadout,
          hangar.inventory,
          Catalogue.byId,
        );
        expect(tekrar.maxHull, zayif.maxHull);
        expect(tekrar.maxShield, zayif.maxShield);
        expect(tekrar.speed, zayif.speed);
        expect(
          CombatGlossary.battleRating(tekrar),
          CombatGlossary.battleRating(zayif),
          reason: 'seviye/unvan BR\'ye sızdı',
        );
      }
    });
  });
}
