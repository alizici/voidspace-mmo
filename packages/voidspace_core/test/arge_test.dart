@Tags(['kapsam', 'turetme', 'aralik'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ArGe — 05.7 s2 · güç değil YÖN veriyor.
///
/// Ağacın tek gerçek yasağı sınanıyor: hiçbir düğüm ham güç vermiyor. Onun
/// dışında zincir, puan ve sıfırlama.
void main() {
  /// [seviye]'ye tam ulaşmış hesap: XP eşiğin bir üstünde (10.1).
  Hangar seviyeli(int seviye) {
    final h = Hangar(
      accountId: 'a',
      credits: 1 << 30,
      xp: Seviye.esigi(seviye).ceil(),
    );
    expect(h.seviye, greaterThanOrEqualTo(seviye));
    return h;
  }

  // KARAR 05.7 s2
  test('hiçbir düğüm HAM GÜÇ vermiyor: ya yön ya izin', () {
    // Yasağın kendisi. Bir düğüm stat verseydi 08'in bütçesi yeniden
    // bölünmek zorunda kalırdı.
    for (final d in ArGe.hepsi) {
      final yon = d.aktarimDeltasi != 0;
      final izinli = d.izin != null;
      expect(
        yon ^ izinli,
        isTrue,
        reason: '${d.id} ya iki iş birden yapıyor ya hiçbiri',
      );
      expect(d.maliyet, greaterThan(0));
    }
    expect(ArGe.hepsi.map((d) => d.id).toSet(), hasLength(ArGe.hepsi.length));
  });

  // KARAR 05.7 s2
  test('iki dal σ\'yı ZIT yönlere itiyor, toplamı sıfır', () {
    final filo = ArGe.hepsi
        .where((d) => d.dal == ArGeDali.filo)
        .map((d) => d.id)
        .toSet();
    final gemi = ArGe.hepsi
        .where((d) => d.dal == ArGeDali.gemi)
        .map((d) => d.id)
        .toSet();
    expect(ArGe.aktarimDeltasi(filo), greaterThan(0));
    expect(ArGe.aktarimDeltasi(gemi), lessThan(0));
    expect(
      ArGe.aktarimDeltasi({...filo, ...gemi}),
      closeTo(0, 1e-12),
      reason: 'iki dalın toplamı sıfır değil: ağaç güç veriyor',
    );
    // Bir dal, bir formasyon eğilimi kadar (05.9).
    expect(
      ArGe.aktarimDeltasi(filo),
      closeTo(TasarimGirdileri.formasyonTakasi, 0.005),
    );
  });

  // KARAR 05.7 s2
  test('dal ZİNCİR: önkoşulsuz düğüm alınamıyor', () {
    final h = seviyeli(20);
    expect(HangarRules.argeAl(h, 'filo-2'), HangarError.kilitli);
    expect(HangarRules.argeAl(h, 'filo-1'), isNull);
    expect(HangarRules.argeAl(h, 'filo-2'), isNull);
    expect(HangarRules.argeAl(h, 'yok'), HangarError.notFound);
    // İki kez almak hata değil, işlemsiz.
    expect(HangarRules.argeAl(h, 'filo-1'), isNull);
    expect(h.argeDugumleri, {'filo-1', 'filo-2'});
  });

  // KARAR 05.7 s2
  test('puan SEVİYEDEN: yetmeyen puan parayla kapatılamıyor', () {
    final h = seviyeli(1);
    expect(ArGe.puanFor(h.seviye), 1);
    expect(HangarRules.argeAl(h, 'filo-1'), isNull);
    // İkinci düğüm iki puan; seviye bir, kredi sınırsız — yine olmuyor.
    expect(HangarRules.argeAl(h, 'filo-2'), HangarError.notEnoughMaterials);
    expect(h.credits, greaterThan(0));
  });

  // KARAR 05.7 s2
  test('sıfırlama BEDAVA ve sınırsız', () {
    final h = seviyeli(20);
    HangarRules.argeAl(h, 'filo-1');
    HangarRules.argeAl(h, 'filo-2');
    final para = h.credits;
    final nova = h.premium;

    expect(HangarRules.argeSifirla(h), isNull);
    expect(h.argeDugumleri, isEmpty);
    expect(h.credits, para, reason: 'sıfırlama kredi yedi');
    expect(h.premium, nova, reason: 'sıfırlama NOVA yedi');
    // Yeniden alınabiliyor: puan geri geldi.
    expect(HangarRules.argeAl(h, 'filo-1'), isNull);
  });

  // KARAR 05.7 s2 · KARAR 04.10 s3
  test('izin dalı SAYI değil KAPI açıyor: filo tavanı bir artıyor', () {
    final h = seviyeli(20);
    expect(h.filoTavani, TasarimGirdileri.droidFiloTavani);
    for (final id in ['filo-1', 'filo-2', 'filo-3', 'filo-yuva']) {
      expect(HangarRules.argeAl(h, id), isNull, reason: id);
    }
    expect(h.filoTavani, TasarimGirdileri.droidFiloTavani + 1);
    expect(
      ArGe.izinAcik(h.argeDugumleri, ArGeIzni.filoYuvasi),
      isTrue,
    );
    expect(
      ArGe.izinAcik(h.argeDugumleri, ArGeIzni.ikinciProfil),
      isFalse,
      reason: 'bir dal öteki dalın iznini açtı',
    );
  });

  // KARAR 05.7 s2 · KARAR 05.5 s3
  test('yönlendirme σ\'ya biniyor ve kelepçe tek yerde', () {
    final v = StatVector()
      ..add('hasar_artisi', StatScope.gemi, 1.0)
      ..add('hasar_artisi', StatScope.droid, 0);
    DroidGrubu grup(double arge) => LoadoutResolver.droidGrubuOf(
      v,
      const [1.0],
      Formasyon.varsayilan,
      argeAktarim: arge,
      gemiHasarBonusu: 1.0,
      gemiKritikSansi: 0,
      gemiKritikCarpani: 0,
    );
    // σ arttıkça droid geminin bonusundan daha çok pay alıyor.
    expect(grup(0.2).damageBonus, greaterThan(grup(0).damageBonus));
    expect(grup(-0.2).damageBonus, lessThan(grup(0).damageBonus));
    // Kelepçe: σ birin üstüne çıkmıyor, sıfırın altına inmiyor.
    expect(grup(5).damageBonus, closeTo(1.0, 1e-12));
    expect(grup(-5).damageBonus, closeTo(0, 1e-12));
  });

  // KARAR 05.7 s2
  test('kayıt ağacı taşıyor; boş hesapta alan yok', () {
    final h = seviyeli(20);
    HangarRules.argeAl(h, 'gemi-1');
    expect(Hangar.fromJson(h.toJson()).argeDugumleri, {'gemi-1'});
    expect(
      Hangar(accountId: 'b').toJson().containsKey('argeDugumleri'),
      isFalse,
    );
  });
}
