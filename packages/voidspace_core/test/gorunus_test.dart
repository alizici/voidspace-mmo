@Tags(['kapsam', 'aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// GÖRÜNÜŞ — 15.9 · tasarım ve formasyon NOVA ile.
///
/// Yasağın (15.1) sınırı burada okunuyor: satılan şey güç değil görünüş.
/// Sınanan üç şey — güç vermediği, sahipliğin hesapta seçimin örnekte
/// olduğu, ve iki şeyin hep sahipli kaldığı.
void main() {
  var sayac = 0;
  TxContext tx() => TxContext(id: 'tx${sayac++}', atMillis: 1000 + sayac);

  Hangar hangar({int nova = 0}) =>
      Hangar(accountId: 'a', credits: 1 << 30, premium: nova);

  // KARAR 15.9 s1
  test('görünüş NOVA ile alınıyor; ikinci alım ödetmiyor', () {
    final h = hangar(nova: 10000);
    final once = h.premium;

    expect(
      HangarRules.gorunusAl(h, GorunusKalemi.tasarim, 'elmas', tx()),
      isNull,
    );
    expect(h.premium, once - TasarimGirdileri.tasarimNova);
    expect(h.tasarimaSahip('elmas'), isTrue);

    // Sahip olunanı ikinci kez almak hata değil, işlemsiz.
    expect(
      HangarRules.gorunusAl(h, GorunusKalemi.tasarim, 'elmas', tx()),
      isNull,
    );
    expect(h.premium, once - TasarimGirdileri.tasarimNova);

    expect(
      HangarRules.gorunusAl(h, GorunusKalemi.formasyon, 'ok', tx()),
      isNull,
    );
    expect(
      h.premium,
      once - TasarimGirdileri.tasarimNova - TasarimGirdileri.formasyonNova,
    );
  });

  // KARAR 15.9 s1
  test('formasyon tasarımdan pahalı: geometri de taşıyor', () {
    expect(
      Kazanc.gorunusFiyati(GorunusKalemi.formasyon),
      greaterThan(Kazanc.gorunusFiyati(GorunusKalemi.tasarim)),
    );
    for (final kalem in GorunusKalemi.values) {
      expect(Kazanc.gorunusFiyati(kalem), greaterThan(0));
    }
  });

  // KARAR 15.9 s1
  test('NOVA yetmiyorsa görünüş gelmiyor; tanınmayan kimlik red', () {
    final h = hangar();
    expect(
      HangarRules.gorunusAl(h, GorunusKalemi.tasarim, 'elmas', tx()),
      HangarError.novaYok,
    );
    expect(h.tasarimaSahip('elmas'), isFalse);
    expect(
      HangarRules.gorunusAl(h, GorunusKalemi.tasarim, 'yok', tx()),
      HangarError.notFound,
    );
    expect(
      HangarRules.gorunusAl(h, GorunusKalemi.formasyon, 'yok', tx()),
      HangarError.notFound,
    );
  });

  // KARAR 15.9 s1
  test('iki görünüş HEP sahipli: satılan droidler ve varsayılan formasyon', () {
    final h = hangar();
    expect(h.tasarimaSahip(DroidModeli.ucuz.name), isTrue);
    expect(h.tasarimaSahip(DroidModeli.elit.name), isTrue);
    expect(h.formasyonaSahip(Formasyon.varsayilan.id), isTrue);
    // Gerisi raftan: sekiz tasarım, on dokuz formasyon.
    expect(h.tasarimaSahip(DroidModeli.merdiven.first.name), isFalse);
    expect(HangarRules.formasyonSec(h, Formasyon.varsayilan.id), isNull);
  });

  // KARAR 15.9 s1
  test('sahiplik HESAPTA, seçim ÖRNEKTE: iki droid iki tasarım', () {
    final h = hangar(nova: 10000);
    h.addItem(const ItemInstance(instanceId: 'd0', specId: 'dr1'));
    h.addItem(const ItemInstance(instanceId: 'd1', specId: 'dr1'));
    HangarRules.gorunusAl(h, GorunusKalemi.tasarim, 'elmas', tx());
    HangarRules.gorunusAl(h, GorunusKalemi.tasarim, 'pusula', tx());

    expect(HangarRules.droidTasarimSec(h, 'd0', 'elmas'), isNull);
    expect(HangarRules.droidTasarimSec(h, 'd1', 'pusula'), isNull);
    expect(h.itemOf('d0')!.tasarim, 'elmas');
    expect(h.itemOf('d1')!.tasarim, 'pusula');
    expect(Hangar.fromJson(h.toJson()).itemOf('d0')!.tasarim, 'elmas');

    // Sahip olunmayan tasarım seçilemiyor.
    expect(
      HangarRules.droidTasarimSec(h, 'd0', 'jiroskop'),
      HangarError.notPurchasable,
    );
    // Droid olmayan eşyaya tasarım giydirilemiyor.
    h.addItem(const ItemInstance(instanceId: 'lz', specId: 'pl1'));
    expect(
      HangarRules.droidTasarimSec(h, 'lz', 'elmas'),
      HangarError.wrongSlot,
    );
  });

  // KARAR 15.9 s1 · KARAR 15.1 s3
  test('görünüş GÜÇ vermiyor: savaş puanı kıpırdamıyor', () {
    // Yasağın sınırı: tasarım ve formasyon satılıyor, çünkü ikisi de
    // savaş puanına dokunmuyor. Formasyonun σ takası imzalı ve toplamı
    // sıfır; tasarım yalnız çizim.
    final envanter = {
      'd0': const ItemInstance(instanceId: 'd0', specId: 'dr1'),
      'd1': const ItemInstance(instanceId: 'd1', specId: 'dr1', tasarim: 'elmas'),
    };
    final loadout = Loadout(hullId: HullClass.bastion.id);
    final sade = LoadoutResolver.resolve(
      loadout,
      envanter,
      Catalogue.byId,
      filo: ['d0'],
    );
    final tasarimli = LoadoutResolver.resolve(
      loadout,
      envanter,
      Catalogue.byId,
      filo: ['d1'],
    );
    expect(
      CombatGlossary.battleRating(tasarimli),
      closeTo(CombatGlossary.battleRating(sade), 1e-9),
      reason: 'tasarım savaş puanını değiştirdi',
    );
  });
}
