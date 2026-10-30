@Tags(['kod-belge'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../tool/belge/kararlar.dart';

/// BELGE ↔ KOD — hangi taraf eskidi.
///
/// Belge kaynak, kod uygulama; ikisi aynı commit'te düzelir. Bu dosya o
/// anlaşmanın bekçisi: kararlar `docs/` altında numaralı ve durumlu, kod onları
/// sürümüyle anıyor, sayılar tepe tablodan etiketli. Kural [docs/README.md].
///
/// Üretilen dosyalar (tablolar, harita, karar izi) eskiyince test onları
/// YENİDEN YAZAR ve DÜŞER. Altın görüntülerle aynı sözleşme: değişiklik
/// commit'te görünsün, sessizce geçmesin. İkinci koşuda geçer.
void main() {
  final depo = BelgeDeposu.oku();
  final bulgular = depo.denetle();

  group('belge ↔ kod', () {
    test('kural belgesi var', () {
      expect(
        depo.kurallar,
        isNotEmpty,
        reason: 'docs/ altında `tur: kural` belge yok',
      );
    });

    for (final tur in BulguTuru.values) {
      test('${tur.etiket} yok', () {
        final bunlar = bulgular.where((b) => b.tur == tur).toList();
        expect(
          bunlar,
          isEmpty,
          reason:
              '${bunlar.length} bulgu:\n${bunlar.map((b) => '  ${b.mesaj}').join('\n')}',
        );
      });
    }

    test('ayrılmış kararlar kodlanacaklar listesinde DEĞİL', () {
      // Rezervasyon ve süreç kuralı kodlanacak iş değil; listede dururlarsa
      // gerçek işi gömerler.
      final harita = depo.haritaUret();
      final kodlanacaklar = harita
          .substring(harita.indexOf('## Kodlanacaklar'))
          .split('\n## ')
          .first;
      final ayrilmis = depo.kararlar.values.where(
        (k) => k.durum == KararDurumu.ayrilmis,
      );
      expect(ayrilmis, isNotEmpty, reason: 'ayrılmış karar yok');
      for (final k in ayrilmis) {
        expect(
          kodlanacaklar,
          isNot(contains('**${k.id} ·')),
          reason: '${k.id} ayrılmış ama kodlanacak iş gibi listelenmiş',
        );
        expect(harita, contains('**${k.id} ·'), reason: '${k.id} haritada yok');
      }
    });

    // KARAR 16.7 s1
    test(
      'türetilen etiketler doğrulanıyor — kayıt boş değil, belge kullanıyor',
      () {
        // Girdi etiketleri eskiden beri; türetilenler yeni. En az bir belge
        // türetilen bir sayıyı etiketle yazmalı, yoksa mekanizma süs.
        final sayim = depo.etiketSayimi();
        expect(sayim['girdi'], greaterThan(0));
        expect(
          sayim['turetilen'],
          greaterThan(0),
          reason: 'türetilen etiket yok',
        );
        expect(TuretilenKaydi.islevler, isNotEmpty);
      },
    );

    // KARAR 16.8 s1
    test('kodda olan HER kararı bir test anıyor — cırcır sıfırda', () {
      // Cırcır sıfıra indi ve kural sertleşti (16.8): artık ilan edilen bir
      // sayı yok, sınanmamış karar doğrudan bulgu. "Kodda" demek bundan
      // sonra "bir test bunu sınıyor" demek.
      //
      // Yeni bir karar kodlanırken testi de yazılmak zorunda; bu satır o
      // zorunluluğun kendisi ve gevşetilmemeli. Gevşetilirse geri dönüş
      // yolu yok: sayı bir kez yükselince cırcır anlamını kaybeder.
      final liste = depo.sinanmamis;
      expect(
        liste,
        isEmpty,
        reason:
            'test yazılmadan kodda denen karar:\n'
            '${liste.map((k) => '  ${k.id} · ${k.baslik}').join('\n')}',
      );
    });

    // KARAR 16.9 s1
    test('borç defteri okunuyor; her madde bir karara ya da alana bağlı', () {
      final (borclar, hatalar) = depo.borclariOku();
      expect(hatalar, isEmpty, reason: hatalar.join('\n'));
      expect(borclar, isNotEmpty, reason: 'defter boş ya da okunamadı');
      for (final m in borclar) {
        expect(
          m.kararlar.isNotEmpty || m.alanlar.isNotEmpty,
          isTrue,
          reason: '${m.id} kaynaksız',
        );
      }
    });

    // KARAR 16.9 s1
    test('yan belgeler README\'de listeli; taşınanların hedefi var', () {
      expect(
        depo.yanBelgeler,
        isNotEmpty,
        reason: 'README yan belge tablosu yok',
      );
      for (final y in depo.yanBelgeler.where((y) => !y.disarida)) {
        expect(
          File('docs/${y.hedef}').existsSync(),
          isTrue,
          reason: '"${y.ad}" taşındı → ${y.hedef} ama dosya yok',
        );
      }
    });

    test('her karar tek bir alanda', () {
      final gorulen = <String, String>{};
      for (final b in depo.kurallar) {
        for (final k in b.kararlar) {
          expect(
            gorulen[k.baslik],
            isNull,
            reason: '"${k.baslik}" hem ${gorulen[k.baslik]} hem ${b.yol}',
          );
          gorulen[k.baslik] = b.yol;
        }
      }
    });
  });

  group('üretilen dosyalar taze', () {
    /// Dosya içeriği [istenen] değilse yeniden yazar ve nedenini döndürür.
    String? tazele(String yol, String istenen) {
      final f = File(yol);
      final mevcut = f.existsSync() ? f.readAsStringSync() : null;
      if (mevcut == istenen) return null;
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(istenen);
      return mevcut == null
          ? '$yol yoktu, üretildi — commit\'e ekle'
          : '$yol eskimişti, yeniden üretildi — diff\'e bak, commit\'e ekle';
    }

    test('sayı tabloları', () {
      final nedenler = <String>[];
      for (final e in BelgeUretici.dosyalar.entries) {
        final n = tazele(e.key, e.value());
        if (n != null) nedenler.add(n);
      }
      expect(nedenler, isEmpty, reason: nedenler.join('\n'));
    });

    test('harita', () {
      final n = tazele(
        '${depo.docs}/${BelgeDeposu.haritaDosyasi}',
        depo.haritaUret(),
      );
      expect(n, isNull, reason: n);
    });

    test('karar izi', () {
      // Şüpheli bağlantı bulgusu varken iz yenilenmez: yenilemek, insanın
      // vermesi gereken kararı (sürüm mü, onay mı) sessizce vermek olurdu.
      final supheli = bulgular.where((b) => b.tur == BulguTuru.supheli);
      if (supheli.isNotEmpty) {
        fail(
          'karar izi bekliyor: önce şüpheli bağlantıları karara bağla\n'
          '${supheli.map((b) => '  ${b.mesaj}').join('\n')}',
        );
      }
      final n = tazele(
        '${depo.docs}/${BelgeDeposu.izDosyasi}',
        depo.izDosyasiUret(),
      );
      expect(n, isNull, reason: n);
    });
  });
}
