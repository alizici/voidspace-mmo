@Tags(['disi'])
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/bastion.dart';
import 'package:voidspace3/game/art/shield_shell.dart';
import 'package:voidspace3/game/components/combat_layer.dart';

/// Savaş görselinin DAVRANIŞI — piksel değil, ömür.
///
/// Golden almıyoruz ve bu kasıtlı: mermi konumu zamana bağlı ve testin
/// koruması gereken şey "şu piksel şu renkte" değil, "yaylım beş mermi
/// doğurur, mermi hedefe varır, varınca TEK bir hasar sayısı düşer". Golden
/// bunların hiçbirini kırmızıya çevirmezdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Atıcıyı orijine, hedefi [distance] birim sağa koyar.
  ///
  /// [lasers] atıcının TAKILI lazer sayısı — varsayılan tam donanım, çünkü
  /// buradaki testlerin çoğu yaylımın kendisini ölçüyor, donanımı değil.
  CombatLayer duel({double distance = 500, int? lasers}) => CombatLayer()
    ..begin()
    ..track(1, 0, 0, 0, 1, lasers ?? Bastion.hardpoints.length)
    ..track(2, distance, 0, 0);

  /// Katmanı [seconds] kadar 60 Hz ile ilerletir.
  void run(CombatLayer layer, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      layer.update(1 / 60);
    }
  }

  const shot = (
    shooterId: 1,
    targetId: 2,
    damage: 1000,
    shieldHit: true,
    killed: false,
  );

  void fire(CombatLayer layer, {bool killed = false, bool shieldHit = true}) =>
      layer.fire(
        shooterId: shot.shooterId,
        targetId: shot.targetId,
        damage: shot.damage,
        shieldHit: shieldHit,
        killed: killed,
      );

  test('yaylım TAKILI namlu sayısınca mermi doğurur', () {
    // Oyuncunun eski projeden istediği özellik: gemi taktığı kadar silah
    // taşıyor. Ölçülen şey görünüş değil DAVRANIŞ — ateş eden namlu sayısı
    // ile gemide çizilen top sayısı aynı listeden (`activeHardpoints`)
    // geliyor, o yüzden burada mermiyi saymak ikisini birden kilitliyor.
    //
    // Merdiven ÇİFT geliyor: yuvalar simetrik, tek sayıda top gemiyi tek
    // kanadı eksik gibi gösterirdi.
    const ladder = {0: 0, 1: 1, 2: 1, 3: 3, 4: 3, 5: 5, 9: 5};
    for (final entry in ladder.entries) {
      final layer = duel(lasers: entry.key);
      fire(layer);
      expect(
        layer.debugBoltCount,
        entry.value,
        reason: '${entry.key} lazerle ${entry.value} mermi bekleniyordu',
      );
    }
  });

  test('silahsız gemi mermi doğurmaz ama HASAR SAYISI yine düşer', () {
    // Sıfır namlu mermiyi yok ediyor; hasar sayısını yok etmemeli. Sayıyı
    // yaylımın ilk mermisi taşıyordu ve mermi yoksa taşıyıcı da yok —
    // hedefin sebepsiz erimesi tam olarak bu boşluktan çıkardı.
    final layer = duel(lasers: 0);
    fire(layer);
    expect(layer.debugBoltCount, 0);
    run(layer, 0.4);
    expect(layer.debugLabelCount, greaterThan(0));
  });

  test('bir yaylım NAMLU BAŞINA bir mermi doğurur', () {
    final layer = duel();
    fire(layer);
    // Gemide beş yuva var; beşi birden ateşler.
    expect(layer.debugBoltCount, 5);
    expect(layer.debugLabelCount, 0, reason: 'sayı VARIŞTA düşer');
  });

  test('mermi hedefe varır ve TEK hasar sayısı bırakır', () {
    final layer = duel()..let(fire);
    run(layer, 1.0);

    expect(layer.debugBoltCount, 0, reason: 'mermiler varmalı');
    expect(
      layer.debugLabelCount,
      1,
      reason: 'beş mermi beş sayı bassaydı tek vuruş beş kez okunurdu',
    );
  });

  test('hasar sayısı ömrünü doldurunca silinir', () {
    final layer = duel()..let(fire);
    run(layer, 0.6);
    expect(layer.debugLabelCount, 1);
    run(layer, 1.4);
    expect(layer.debugLabelCount, 0, reason: 'sayılar ekranda birikemez');
  });

  test('görülmeyen HEDEFE hiçbir şey çizilmez', () {
    // İlgi alanının dışındaki bir çarpışmanın sayısı ekrana düşerse, oyuncu
    // göremediği bir dövüşün hasarını okur.
    final layer = CombatLayer()
      ..begin()
      ..track(1, 0, 0, 0);
    fire(layer);
    expect(layer.debugBoltCount, 0);
    expect(layer.debugLabelCount, 0);
  });

  test('atıcı görünmüyorsa mermi yok ama SAYI düşer', () {
    // Menzilin ucundan vuran bir gemi ilgi alanına girmemiş olabilir. Hasar
    // yine de gerçek: sayı bastırılmazsa gemi sebepsiz erir.
    final layer = CombatLayer()
      ..begin()
      ..track(2, 500, 0, 0);
    fire(layer);
    expect(layer.debugBoltCount, 0);
    expect(layer.debugLabelCount, 1);
  });

  test('hedef kaçarken mermi onu İZLER', () {
    // Hasar zaten inmiş durumda: ıskalayan bir mermi yalan söyler.
    final layer = duel(distance: 900);
    fire(layer);
    // Hedefi mermi yoldayken dik olarak kaçır.
    for (var t = 0.0; t < 1.0; t += 1 / 60) {
      layer.track(2, 900, 700 * t, 0);
      layer.update(1 / 60);
    }
    expect(layer.debugBoltCount, 0, reason: 'mermi hedefi kaybetti');
    expect(layer.debugLabelCount, 1);
  });

  test('yakalanamayan mermi ömrünü doldurup söner', () {
    // Mermiden HIZLI kaçan bir hedef (itki + ters yön) yakalanamaz. Ömür
    // tavanı olmasaydı o mermiler ekranda sonsuza kadar kalırdı.
    final layer = duel(distance: 600);
    fire(layer);

    var x = 600.0;
    void flee(double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        x += 4200 / 60;
        layer
          ..track(2, x, 0, 0)
          ..update(1 / 60);
      }
    }

    flee(2.0);
    expect(layer.debugBoltCount, 5, reason: 'ömür daha dolmadı');
    flee(0.8);
    expect(layer.debugBoltCount, 0, reason: 'ömür tavanı işlemedi');
    expect(
      layer.debugLabelCount,
      0,
      reason: 'varmayan mermi hasar sayısı BASMAMALI',
    );
  });

  test('yaylım 2 → 1 → 2 sırasıyla çıkar', () {
    // Eski projenin ripple düzeni: uç çifti, merkez top, kanat çifti. Hepsi
    // aynı anda çıkarsa yaylım tek bir kalın mermiye düşer.
    //
    // Hedef UZAK: yakın bir hedefte ilk mermiler sonuncular yola çıkmadan
    // varır ve sayım sırayı değil varışı ölçerdi.
    final layer = duel(distance: 1200)..let(fire);
    expect(layer.debugBoltCount, 5, reason: 'beşi de kuyruğa girmeli');

    layer.update(1 / 60);
    expect(layer.debugLaunchedBoltCount, 2, reason: 'önce uç çifti');

    run(layer, 0.09);
    expect(layer.debugLaunchedBoltCount, 3, reason: 'sonra merkez top');

    run(layer, 0.09);
    expect(layer.debugLaunchedBoltCount, 5, reason: 'sonra kanat çifti');
  });

  test('bir yaylım kabukta TEK darbe açar', () {
    // Beş mermi beş darbe açsaydı kabuk beyaza doyardı: hücre parlaklığı
    // bütün canlı darbelerin TOPLAMI, ve beş cephe her hücreyi tavana
    // vurduruyor. Eski projede de kalkan saldırı başına bir kez uyarılıyor.
    final layer = duel()..let(fire);
    run(layer, 0.6);
    expect(layer.debugShieldHitCount, 1);
  });

  test('kabuk darbeleri TAVANLA sınırlı', () {
    // Üst üste binen yaylımlar sınırsız birikirse hücre başına maliyet
    // doğrusal büyür ve kare bütçesi gider.
    final layer = duel();
    for (var i = 0; i < 14; i++) {
      fire(layer);
      run(layer, 0.05);
    }
    expect(
      layer.debugShieldHitCount,
      lessThanOrEqualTo(ShieldHit.maxPerShield),
    );
  });

  test('kalkanı inmiş hedefte kabuk darbesi YOK', () {
    // Kalkan bittiğinde çizilecek bir kabuk da yok; halka çizmek oyuncuya
    // hâlâ korunduğunu söylerdi.
    final layer = duel();
    fire(layer, shieldHit: false);
    run(layer, 0.6);
    expect(layer.debugShieldHitCount, 0);
    expect(layer.debugLabelCount, 1, reason: 'hasar yine de okunmalı');
  });

  test('kabuk darbesi ömrünü doldurunca silinir', () {
    final layer = duel()..let(fire);
    run(layer, 0.6);
    expect(layer.debugShieldHitCount, greaterThan(0));
    run(layer, 0.8);
    expect(layer.debugShieldHitCount, 0);
  });

  test('çizim yolu gerçek bir tuval üzerinde çalışır', () {
    // Hasar sayısı `Paragraph` diziyor ve mermi shader kullanıyor: ikisi de
    // yalnız GERÇEK bir tuvalde patlar. Sayıları saymak bunu yakalamaz.
    final layer = duel()
      ..let(fire)
      ..aim(0, 0, 0, Bastion.hardpoints.length)
      ..setLock(500, 0);
    // Kabuk darbesi de çizilsin: `Paragraph` ile birlikte yalnız gerçek bir
    // tuvalde patlayabilecek ikinci yol o.
    run(layer, 0.6);

    final recorder = PictureRecorder();
    layer.render(Canvas(recorder));
    expect(recorder.endRecording().approximateBytesUsed, greaterThan(0));
  });

  test('imha eden vuruş AYRI okunur', () {
    final layer = duel();
    fire(layer, killed: true);
    run(layer, 1.0);
    expect(layer.debugLabelCount, 1);
    // Renk ve boy `DamageLabel`'da; burada kanıtlanan, öldüren vuruşun da tek
    // bir sayı bırakması — patlama halkası fazladan bir sayı DOĞURMAZ.
  });

  group('ölüm ilanı', () {
    test('ölüm mermi ÇARPINCA bildirilir, ateş anında değil', () {
      // Hedefi olay gelir gelmez silmek, merminin varmadan boşluğa çarpması
      // demekti; bir saniye beklemek ise ekranda ceset bırakıyordu.
      final layer = duel()..let((l) => fire(l, killed: true));
      expect(layer.takeKills(), isEmpty, reason: 'mermi daha yolda');

      run(layer, 0.6);
      expect(layer.takeKills(), contains(shot.targetId));
    });

    test('öldürmeyen vuruş ölüm İLAN ETMEZ', () {
      final layer = duel()..let(fire);
      run(layer, 0.6);
      expect(layer.takeKills(), isEmpty);
    });

    test('okununca BOŞALIR — aynı ölüm iki kez işlenmez', () {
      // Kare başında temizlemek YANLIŞTI: çarpmalar `update` içinde, yani
      // çağıranın okumasından sonra oluyor; her ölüm okunmadan siliniyordu.
      final layer = duel()..let((l) => fire(l, killed: true));
      run(layer, 0.6);
      expect(layer.takeKills(), isNotEmpty);
      expect(layer.takeKills(), isEmpty);
    });

    test('kare başlangıcı ölümleri SİLMEZ', () {
      final layer = duel()..let((l) => fire(l, killed: true));
      run(layer, 0.6);
      layer.begin();
      expect(
        layer.takeKills(),
        isNotEmpty,
        reason: 'begin() ölümü sildi — çağıran onu hiç göremez',
      );
    });
  });
}

extension on CombatLayer {
  /// `..let(fire)` — kaskad içinde yardımcı çağırmak için.
  void let(void Function(CombatLayer layer) body) => body(this);
}
