@Tags(['kapsam'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 10.4 · UNVAN İSİMLERİ VE ÇAĞLAR.
void main() {
  test('dört çağ, yirmi ad, yüz yirmi basamak — ad başına altı', () {
    expect(Unvan.caglar, hasLength(4));
    expect(Unvan.adlar, hasLength(20));
    expect(TasarimGirdileri.unvanSayisi % Unvan.adlar.length, 0);
    expect(Unvan.adBasinaBasamak, 6);
    expect(Unvan.cagBasinaAd, 5);
  });

  test('her basamağın adı benzersiz ve sıralı', () {
    final adlar = [
      for (var i = 0; i < TasarimGirdileri.unvanSayisi; i++) Unvan.adi(i),
    ];
    expect(adlar.toSet(), hasLength(adlar.length));
    expect(adlar.first, 'Squire I');
    expect(adlar.last, 'Star Lord VI');
    expect(Unvan.adi(6), 'Knight I');
  });

  test(
    'uçlar belgeden: Squire … Duke, … Deity, Starcaller … Vortex, … Star Lord',
    () {
      expect(Unvan.adlar[0], 'Squire');
      expect(Unvan.adlar[4], 'Duke');
      expect(Unvan.adlar[9], 'Deity');
      expect(Unvan.adlar[10], 'Starcaller');
      expect(Unvan.adlar[14], 'Vortex');
      expect(Unvan.adlar[18], 'Star Marshal');
      expect(Unvan.adlar[19], 'Star Lord');
    },
  );

  // KARAR 10.4 s2
  test('basamak üç sayıya ayrışıyor: ad, kademe, çağ', () {
    // Amblem kataloğu bu üç sayıyı okuyor; ad indeksi glifi, kademe dış
    // halkayı, çağ aparatın katmanını seçiyor.
    expect(Unvan.adIndeksi(0), 0);
    expect(Unvan.kademe(0), 0);
    expect(Unvan.adIndeksi(5), 0);
    expect(Unvan.kademe(5), Unvan.adBasinaBasamak - 1);
    expect(Unvan.adIndeksi(6), 1);
    expect(Unvan.kademe(6), 0);
    expect(Unvan.adIndeksi(119), Unvan.adlar.length - 1);
    expect(Unvan.kademe(119), Unvan.adBasinaBasamak - 1);

    for (var i = 0; i < TasarimGirdileri.unvanSayisi; i++) {
      expect(
        Unvan.adi(i),
        '${Unvan.adlar[Unvan.adIndeksi(i)]} ${Unvan.roma(Unvan.kademe(i))}',
        reason: 'ad üç sayıdan yeniden kurulamadı: $i',
      );
      expect(Unvan.cagi(i), Unvan.caglar[Unvan.cagIndeksi(i)]);
    }
    expect(() => Unvan.adIndeksi(120), throwsArgumentError);
    expect(() => Unvan.kademe(-1), throwsArgumentError);
  });

  test('çağlar otuzar basamak', () {
    expect(Unvan.cagi(0), 'Asalet');
    expect(Unvan.cagi(29), 'Asalet');
    expect(Unvan.cagi(30), 'Kutsallık');
    expect(Unvan.cagi(119), 'Ölümsüzlük');
    expect(() => Unvan.adi(120), throwsArgumentError);
    expect(() => Unvan.cagi(-1), throwsArgumentError);
  });
}
