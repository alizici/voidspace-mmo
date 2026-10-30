@Tags(['disi'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MİMARİ KURALLARI — kod büyüdükçe kendiliğinden korunsun diye teste bağlı.
///
/// Projedeki tek yapısal karar "Bloc ayrık durumu, Flame sürekli simülasyonu
/// tutar" idi. Multiplayer o kararı bitirmedi, AĞ SINIRINA taşıdı:
///
/// > Bloc ayrık durumu yansıtır, Flame sürekli simülasyonu ÇİZER,
/// > çekirdek paket simülasyonu TANIMLAR, sunucu ise gerçeği TUTAR.
///
/// Bu dört cümleyi ayakta tutan şey katmanların BAĞIMLILIK YÖNÜ. Aşağıdaki
/// kurallardan biri kırıldığı an, kırılma bir tasarım tartışmasına dönüşmeden
/// önce burada kırmızıya döner.
void main() {
  /// [dir] altındaki dosyaların paket-içi ve paket-dışı import'ları.
  Map<String, List<String>> importsUnder(String path) {
    final result = <String, List<String>>{};
    final target = FileSystemEntity.isFileSync(path)
        ? <FileSystemEntity>[File(path)]
        : Directory(path).listSync(recursive: true);
    for (final entity in target) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      result[entity.path] = RegExp(
        r"^import '([^']+)'",
        multiLine: true,
      ).allMatches(entity.readAsStringSync()).map((m) => m.group(1)!).toList();
    }
    return result;
  }

  void expectNoImport(
    String dir,
    bool Function(String) forbidden, {
    required String reason,
  }) {
    final violations = <String>[];
    importsUnder(dir).forEach((file, imports) {
      for (final i in imports) {
        if (forbidden(i)) violations.add('$file → $i');
      }
    });
    expect(violations, isEmpty, reason: reason);
  }

  // ── Paylaşılan çekirdek ─────────────────────────────────────────────
  group('voidspace_core', () {
    test('saf Dart kalır — Flutter, Flame, Bloc ve dart:ui bilmez', () {
      expectNoImport(
        'packages/voidspace_core/lib',
        (i) => i.startsWith('package:') || i == 'dart:ui',
        reason:
            'bu paketin TEK işi aynı simülasyonun hem sunucuda hem istemcide '
            'koşması. `dart:ui` bile Flutter\'a ait ve `dart:io` sunucusunda '
            'yok — tek bir `Offset` import\'u paketi sunucudan koparır',
      );
    });
  });

  // ── Sunucu ──────────────────────────────────────────────────────────
  group('sunucu', () {
    test('Flutter ve Flame bilmez', () {
      for (final dir in ['server/lib', 'server/bin']) {
        expectNoImport(
          dir,
          (i) =>
              i.contains('flutter') ||
              i.contains('flame') ||
              i.contains('bloc') ||
              i == 'dart:ui',
          reason:
              'otorite sunucusu başsız koşar ve AOT derlenir ($dir); bir UI '
              'bağımlılığı bunu bitirir',
        );
      }
    });

    test('oyun mantığı zone\'da kalır — gateway soketten ibarettir', () {
      final gateway = File('server/lib/gateway.dart').readAsStringSync();
      expect(
        gateway.contains('ShipSim.step'),
        isFalse,
        reason:
            'simülasyonu ağ katmanına sızdırmak, Zone\'u soketsiz test '
            'edilemez hâle getirir',
      );
    });
  });

  // ── İstemci ─────────────────────────────────────────────────────────
  group('istemci · bağlantı', () {
    // Widget doğru olup BAĞLANTISI eksik olabiliyor ve o hata sınıfı bu
    // projede iki kez yaşandı: geçit istemi `const` bir alt ağaçta hiç
    // güncellenmedi, galaksi ekranına `konum` hiç geçirilmedi. İkisinde de
    // bileşenin kendi testi yeşildi — eksik olan onu KURAN satırdı.
    String kaynak(String yol) => File(yol).readAsStringSync();

    test('galaksi ekranı NEREDE olduğunu istemciden alıyor', () {
      final app = kaynak('lib/app/app.dart');
      final cagri = RegExp(
        r'GalaksiEkrani\((.*?)\)',
        dotAll: true,
      ).firstMatch(app)?.group(1);
      expect(cagri, isNotNull, reason: 'galaksi ekranı hiç kurulmuyor');
      expect(
        cagri,
        contains('konum:'),
        reason: 'konum geçirilmiyor — "buradasın" işareti hiç çıkmaz',
      );
      expect(
        cagri,
        contains('br:'),
        reason: 'savaş puanı geçirilmiyor — her harita kilitli görünür',
      );
    });

    test('minimap hangi haritada olduğumuzu alıyor', () {
      final hud = kaynak('lib/hud/hud_overlay.dart');
      // Parantez DENGELİ okunuyor, tembel bir düzenli ifadeyle değil.
      //
      // Eskiden `Minimap\((.*?)\)` yazıyordu ve argümanların içindeki İLK
      // kapanan paranteze takılıyordu: çağrıya `context.read<ShipBloc>()`
      // eklenince test kırıldı ve söylediği şey yanlıştı — "harita adı
      // yazılamaz" diyordu, oysa harita yerindeydi, okuma yanlıştı. Kuralı
      // koruyan bir testin, kuralla ilgisi olmayan bir düzenlemede kırmızıya
      // dönmemesi gerekir.
      final cagri = _dengeliArguman(hud, 'Minimap(');
      expect(cagri, isNotNull, reason: 'minimap hiç kurulmuyor');
      expect(cagri, contains('harita:'), reason: 'harita adı yazılamaz');
    });
  });

  group('istemci', () {
    test('ağ katmanı Flutter ve Flame bilmez', () {
      expectNoImport(
        'lib/net',
        (i) => i.contains('flutter') || i.contains('flame'),
        reason:
            'tahmin ve mutabakat oyun döngüsü kurmadan test edilebilmeli; '
            'bir widget bağımlılığı `prediction_test.dart`\'ı bitirir',
      );
    });

    test('ağ katmanı çizime ve HUD\'a bakmaz', () {
      expectNoImport(
        'lib/net',
        (i) =>
            i.contains('/game/') || i.contains('/hud/') || i.contains('app/'),
        reason: 'bağımlılık tek yönlü: sunum → ağ, asla tersi',
      );
    });

    test('sanat katmanı DURUM bilmez — yalnız Canvas boyar', () {
      expectNoImport(
        'lib/game/art',
        (i) =>
            i.contains('bloc') ||
            i.contains('flame') ||
            i.contains('voidspace_core') ||
            i.contains('/net/') ||
            i.contains('components/'),
        reason:
            'çizim kodu neyi çizdiğini bilmeli, KİMİN durumundan geldiğini '
            'değil — aksi hâlde bir gövde eklemek durum katmanına dokunmayı '
            'gerektirir',
      );
    });

    test('bileşenler oyun döngüsünü içeri almaz', () {
      expectNoImport(
        'lib/game/components',
        (i) => i.contains('voidspace_game'),
        reason:
            'bağımlılık tek yönlü olmalı (oyun → bileşen). Ters yön, bileşeni '
            'oyun olmadan test edilemez hâle getirir',
      );
    });

    test('gemi DÜĞÜMÜ gemi ÇİZMEZ', () {
      // Mimarinin merkezi kuralı. Ölçüldü: prosedürel çizilen tek bir gemi
      // 8 ms GPU harcıyor (120 Hz bütçesinin tamamı), çünkü kare başına
      // `saveLayer` + blur var. Çizim tek bir toplu çiziciye (`ShipSwarm`)
      // ait ve orada kalmalı.
      //
      // "Şu gemiyi özel çizelim" fikri güzel görünür ve kare bütçesini
      // sessizce bitirir. Bu satır onu bir tasarım tartışmasına dönüşmeden
      // önce kırar.
      expectNoImport(
        'lib/game/components/ship_component.dart',
        (i) => i.contains('/art/'),
        reason:
            'gemi düğümü sanat katmanını içeri alıyorsa çizebiliyor demektir '
            '— ve prosedürel çizim kare yolundan tamamen çıkmalı',
      );
    });

    test('bileşenler TAŞIMA katmanını içeri almaz — yalnız pozu bilir', () {
      // Yeni ve multiplayer'a özgü kural. Bir gemi bileşeni kendi pozunu
      // soketten çekmeye başlarsa iki şey birden kaybedilir: uzak gemilerle
      // kendi gemin arasındaki tek-kod ortaklığı, ve bileşeni ağsız çizebilme.
      expectNoImport(
        'lib/game/components',
        (i) =>
            i.contains('net_client') ||
            i.contains('predicted_ship') ||
            i.contains('remote_entities'),
        reason:
            'bileşen bir POZ alır ve onu çizer; pozu kimin ürettiği (tahmin mi '
            'ara değer mi) onu ilgilendirmez',
      );
    });

    test('HUD oyun içine sızmaz — durumu yalnız Bloc\'tan okur', () {
      expectNoImport(
        'lib/hud',
        (i) => i.contains('/game/') || i.contains('flame'),
        reason:
            'HUD simülasyondan okursa çubuklarla efektler ayrı gerçekler '
            'göstermeye başlar',
      );
    });

    test('durum katmanı taşımayı içeri almaz', () {
      expectNoImport(
        'lib/ship',
        (i) => i.contains('net_client') || i.contains('web_socket'),
        reason:
            'Bloc bir replika; soketin varlığından haberi olmamalı, yoksa '
            'durum testleri bir sunucu ister',
      );
    });

    test('istemci sunucu paketini İÇERİ ALMAZ', () {
      expectNoImport(
        'lib',
        (i) => i.contains('voidspace_server'),
        reason:
            'sunucu yalnız test bağımlılığı. Üretim koduna girmesi, otoritenin '
            'istemciye kopyalanmasının ilk adımıdır',
      );
    });

    test('yalnız app katmanı her şeyi bilir', () {
      for (final dir in ['lib/ship', 'lib/game', 'lib/hud', 'lib/net']) {
        expectNoImport(
          dir,
          (i) => i.contains('app/app.dart'),
          reason: 'kompozisyon kökü ($dir) tarafından içeri alınamaz',
        );
      }
    });
  });
}

/// [ad] ile başlayan çağrının argüman metnini DENGELİ parantezle çıkarır.
///
/// `null` — çağrı hiç yok.
String? _dengeliArguman(String kaynak, String ad) {
  final bas = kaynak.indexOf(ad);
  if (bas < 0) return null;
  var derinlik = 0;
  for (var i = bas + ad.length - 1; i < kaynak.length; i++) {
    final c = kaynak[i];
    if (c == '(') derinlik++;
    if (c == ')') {
      derinlik--;
      if (derinlik == 0) return kaynak.substring(bas + ad.length, i);
    }
  }
  return null;
}
