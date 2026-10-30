@Tags(['yabanci-anahtar', 'turetme', 'kod-belge'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// BELGE MİMARİSİ — haritanın kendi kurallarının denetimi.
///
/// Tasarım Alanları Haritası dört kural ilan ediyor (04 · Otomasyon): tek tepe
/// tablo · aşağı yalnız yukarıyı okur · girdi ile türetilen fiziksel olarak
/// ayrı · sıfır tekrar. Dördü de burada koşuyor.
///
/// Haritanın kendi cümlesi: *"hiçbir alan kendi doğruluğunu kendi iddia
/// etmeyecek."* Bu dosya o iddiaları dışarıdan ölçüyor.
void main() {
  /// Yorumları ve dizgileri atılmış kaynak — sayı aramaları bunun üstünde
  /// yapılıyor.
  ///
  /// Yorum içindeki bir sayı belgedir, kod içindeki bir sayı sabittir; ikisini
  /// ayırmadan yapılan bir denetim, açıklamayı yasaklayıp asıl ihlali kaçırır.
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r"'[^']*'"), "''");

  List<String> dartFilesUnder(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .toList();

  // ══ Alan haritası ═══════════════════════════════════════════════════
  group('alan haritası', () {
    test('on sekiz alan, numaralar 1..18 ve BENZERSİZ', () {
      expect(TasarimHaritasi.hepsi, hasLength(18));
      final nolar = TasarimHaritasi.hepsi.map((a) => a.no).toList();
      expect(nolar.toSet(), hasLength(18));
      expect(nolar..sort(), List.generate(18, (i) => i + 1));
    });

    test('yabancı anahtar: her bağımlılık VAR OLAN bir alana işaret eder', () {
      for (final alan in TasarimHaritasi.hepsi) {
        for (final no in alan.bagimlilik) {
          expect(
            TasarimHaritasi.byNo(no),
            isNotNull,
            reason: '${alan.id} olmayan bir alandan ($no) okuyor',
          );
        }
      }
    });

    test('AŞAĞI YALNIZ YUKARIYI OKUR — katman yönü ihlal edilemez', () {
      // Bir katman yalnız üstündekine bakabilir. Yana ve geriye bakmak yasak:
      // döngü oluştuğu an bir değişikliğin nereye yayılacağı hesaplanamaz.
      for (final alan in TasarimHaritasi.hepsi) {
        for (final no in alan.bagimlilik) {
          final ust = TasarimHaritasi.byNo(no)!;
          expect(
            ust.katman.index,
            lessThanOrEqualTo(alan.katman.index),
            reason:
                '${alan.id} (${alan.katman.label}) kendinden AŞAĞIDAKİ '
                '${ust.id} (${ust.katman.label}) alanından okuyor',
          );
        }
      }
    });

    test('bağımlılık grafiğinde DÖNGÜ yok', () {
      final durum = <int, int>{}; // 0 ziyaret edilmedi · 1 yolda · 2 bitti
      final yol = <int>[];

      void gez(int no) {
        if (durum[no] == 2) return;
        expect(
          durum[no],
          isNot(1),
          reason: 'döngü: ${[...yol, no].join(' → ')}',
        );
        durum[no] = 1;
        yol.add(no);
        for (final bagli in TasarimHaritasi.byNo(no)!.bagimlilik) {
          gez(bagli);
        }
        yol.removeLast();
        durum[no] = 2;
      }

      for (final alan in TasarimHaritasi.hepsi) {
        gez(alan.no);
      }
    });

    test('YAZILMA SIRASI: bağımlılığı bekleyen alan yazılamaz', () {
      // Grafiğin kendisi bir sıra ilan ediyor ama hiçbir şey onu zorlamıyordu.
      // Bir alanı, okuduğu alan henüz karara bağlanmadan yazmak şu demek:
      // altındaki sayılar değiştiğinde üsttekinin gerekçesi sessizce çürür ve
      // kimse geri dönüp bakmaz.
      //
      // Bu test sırayı KODUN kuralı yapıyor: 17 alanın hangi sırayla
      // uygulanabileceği artık bir tercih değil, grafikten okunan bir sonuç.
      for (final alan in TasarimHaritasi.hepsi) {
        if (alan.durum != BelgeDurumu.yazildi) continue;
        for (final no in alan.bagimlilik) {
          expect(
            TasarimHaritasi.byNo(no)!.durum,
            BelgeDurumu.yazildi,
            reason:
                '${alan.id} yazılmış ama okuduğu '
                '${TasarimHaritasi.byNo(no)!.id} hâlâ bekliyor',
          );
        }
      }
    });

    test('kök alan 01 hiçbir şeye bağlı DEĞİL', () {
      expect(TasarimHaritasi.savasFormulu.bagimlilik, isEmpty);
    });

    test('16 · Denge Denetimi diğer HEPSİNİ denetler', () {
      // On yedi alan, biri kendisi: on altı bağımlılık. Mermi (17) sonradan
      // geldi ve 16 onu da denetliyor — numara sırası yazılma sırası değil.
      expect(TasarimHaritasi.dengeDenetimi.bagimlilik, hasLength(16));
    });

    test('bir karar İKİ alanda sahiplenilemez', () {
      final sahiplenilen = <String, String>{};
      for (final alan in TasarimHaritasi.hepsi) {
        for (final karar in alan.sahiplendigi) {
          expect(
            sahiplenilen[karar],
            isNull,
            reason:
                '"$karar" hem ${sahiplenilen[karar]} hem ${alan.id} '
                'tarafından sahiplenilmiş — ikisi de yanlış',
          );
          sahiplenilen[karar] = alan.id;
        }
      }
    });
  });

  // ══ Tek tepe tablo ══════════════════════════════════════════════════
  group('tepe tablo', () {
    test('her girdi VAR OLAN bir alana ait', () {
      for (final girdi in TasarimGirdileri.hepsi) {
        expect(
          TasarimHaritasi.byNo(girdi.alan),
          isNotNull,
          reason: '${girdi.ad} olmayan bir alana yazılmış',
        );
      }
    });

    test('GİRDİLER BİRBİRİYLE ÇELİŞMİYOR — alanlar arası tutarlılık', () {
      // Tepe tablo her girdinin kendi alanına ait olduğunu doğruluyordu ama
      // İKİ girdinin birbiriyle tutarlı olduğunu hiçbir şey doğrulamıyordu.
      // Her alan kendi içinde tutarlı kalıp birlikte imkânsız bir sistem
      // tarif edebilir — ve bu, tek tek bakınca görülmeyen tek hata sınıfı.
      //
      // Ölçüldü: `govdeKademeSayisi` (alan 04) bir süre 8'di, oysa rank
      // merdiveni (alan 06) beş kademeli. Kademe normalizatörü o bölmeyi
      // reddediyor — sekiz gövdeye beş rank bölünemiyor, boş kademe doğuyor.
      expect(
        TasarimGirdileri.govdeKademeSayisi,
        lessThanOrEqualTo(ItemTier.values.length),
        reason:
            'gövde kademesi (${TasarimGirdileri.govdeKademeSayisi}) rank '
            'sayısını (${ItemTier.values.length}) aşıyor — her kademe en az '
            'bir rank kapsamak zorunda',
      );

      // Ana stat payı, alt statların rank çakışması yaratmayacağı bandın
      // içinde: alt stat payı %43'ü geçtiğinde mükemmel rollü bir alt tier,
      // berbat rollü bir üst tier'i yakalıyor.
      expect(
        1 - TasarimGirdileri.anaStatPayi,
        lessThan(0.43),
        reason: 'alt stat payı çakışma tavanını aştı — rank rengi güç söylemez',
      );

      // Kalite bandı rank atlamasından DAR olmak zorunda, yoksa kalite bir
      // renk atlamasını taklit eder.
      final kaliteMakasi = 1 / TasarimGirdileri.kaliteAltSiniri - 1;
      final rankMakasi = ItemTier.values[1].multiplier - 1;
      expect(
        kaliteMakasi,
        lessThan(rankMakasi),
        reason: 'kalite makası rank atlamasını yakalıyor',
      );
    });

    test('girdi adları BENZERSİZ — sıfır tekrar', () {
      final adlar = TasarimGirdileri.hepsi.map((g) => g.ad).toList();
      expect(adlar.toSet(), hasLength(adlar.length));
    });

    test('yalnız BELGESİ YAZILMIŞ alanların girdisi var', () {
      // Belgesiz bir alanın tepe tabloya satır koyması, sayının gerekçesiz
      // olması demek — ve gerekçesiz sayı, bir sonraki turda gerekçesi ona
      // uydurulan sayıdır.
      final yazilan = TasarimHaritasi.yazilanlar.map((a) => a.no).toSet();
      for (final girdi in TasarimGirdileri.hepsi) {
        expect(
          yazilan,
          contains(girdi.alan),
          reason: '${girdi.ad}, belgesi yazılmamış bir alandan geliyor',
        );
      }
    });

    // KARAR 16.3 s1
    test('KURAL dosyalarında DENGE SABİTİ yok', () {
      // Kural belgesi 08'in değişmezi: *"Bu belgede tek bir sayı yok ve
      // olmayacak."* Buraya bir sabit girdiği an aynı sayı iki yerde durur ve
      // bir sonraki denge turunda ayrışır.
      //
      // Aranan şey ONDALIK sabit: bu alanın bütün ayar kolları oran ya da
      // çarpan (0,25 · 2,00 · 0,30). Tam sayılar kural: katman sayısı 6, katman
      // indeksi 3. İkisi farklı şeyler — biri denge turunda değişir, diğeri
      // yılda bir kez bile değişmez.
      const kuralDosyalari = [
        'packages/voidspace_core/lib/src/combat/damage_chain.dart',
        'packages/voidspace_core/lib/src/combat/combat_glossary.dart',
        'packages/voidspace_core/lib/src/combat/stat_layer.dart',
      ];
      // `0.0` ve `1.0` sabit değil kimlik: toplamanın ve çarpmanın etkisiz
      // elemanları, kelepçelerde geçiyorlar.
      final ondalik = RegExp(r'(?<![\w.])\d+\.\d+');

      for (final path in kuralDosyalari) {
        final ihlal = ondalik
            .allMatches(codeOf(path))
            .map((m) => m.group(0)!)
            .where((s) => s != '0.0' && s != '1.0')
            .toList();
        expect(
          ihlal,
          isEmpty,
          reason:
              '$path içine denge sabiti sızmış: $ihlal — sabitler '
              'tasarim_girdileri.dart\'ta durur',
        );
      }
    });

    test('zincir sabitlerini TEPE TABLODAN okuyor', () {
      // Sayı yokluğu tek başına yetmez: dosya sabitleri bir yerden okumak
      // ZORUNDA, yoksa "sayı yok" testi kuralı kaldırarak da geçilir.
      final code = codeOf(
        'packages/voidspace_core/lib/src/combat/damage_chain.dart',
      );
      expect(code, contains('TasarimGirdileri.siyirmaTavani'));
      expect(code, contains('TasarimGirdileri.sonHasarTavani'));

      // Alan 03'ün fiyat tablosu da aynı kuralda: `budget.dart` sayıyı
      // TUTMUYOR, tepe tablodan okuyor. Sayısızlık tek başına yetmez — burayı
      // bir literalle doldurmak testi kaldırmadan mümkün olmamalı.
      final butce = codeOf(
        'packages/voidspace_core/lib/src/progression/budget.dart',
      );
      for (final girdi in TasarimGirdileri.alanin(3)) {
        // Sınır (`\b`) ŞART, düz `contains` değil: `puanBasinaKalkan`
        // aranırken `puanBasinaKalkanYenilenmesi` satırı onu alt dize olarak
        // içeriyor ve kardeş satır, silinmiş bir okumayı örtüyor. Bu bekçi
        // ilk yazıldığında tam olarak bu yüzden mutasyonu kaçırdı.
        expect(
          butce,
          matches(RegExp('TasarimGirdileri\\.${girdi.ad}\\b')),
          reason: '${girdi.ad} bütçe tablosunda okunmuyor — elle mi yazılmış?',
        );
      }

      // Alan 07 de öyle, iki dosyaya yayılmış: artı merdiveni `item.dart`'ta,
      // sentez ve çevirme `yukseltme.dart`'ta. Bu alanın sayıları elle
      // yazılmaya en açık olanlar, çünkü hepsi "makul görünen" büyüklükte —
      // 900 ile 2489 arasındaki farkı gözle ayırmak mümkün değil.
      final guclendirme =
          codeOf('packages/voidspace_core/lib/src/progression/item.dart') +
          codeOf('packages/voidspace_core/lib/src/progression/yukseltme.dart');
      for (final girdi in TasarimGirdileri.alanin(7)) {
        expect(
          guclendirme,
          matches(RegExp('TasarimGirdileri\\.${girdi.ad}\\b')),
          reason: '${girdi.ad} güçlendirmede okunmuyor — elle mi yazılmış?',
        );
      }
      // Kategorik karar `hepsi` listesinde yok (deger `num`), ama okunmak
      // zorunda: kazanç biçimi koda gömülürse 06'nın çelişkisi geri gelir.
      expect(
        guclendirme,
        contains('TasarimGirdileri.artiKazancBicimi'),
        reason: 'artı kazanç biçimi koda gömülmüş',
      );

      // Alan 11 — harita ve geçit. Girdiler tek dosyada değil: ölçü
      // `bolge`de, yoğunluk ve PvP primi `turetilenler`de, geçit `gecit`te.
      // Birleşimlerinde okunmaları yeterli — ama okunmaları ZORUNLU, çünkü
      // bu alanın çıktılarının hepsi (harita boyutu, kapı eşiği, geçit
      // yarıçapı) bugünkü değerlerine sabitlenebilecek kadar sade sayılar.
      final harita = [
        'packages/voidspace_core/lib/src/world/bolge.dart',
        'packages/voidspace_core/lib/src/world/gecit.dart',
        'packages/voidspace_core/lib/src/design/turetilenler.dart',
        'packages/voidspace_core/lib/src/progression/kaynak_akisi.dart',
        'packages/voidspace_core/lib/src/net/protocol.dart',
      ].map(codeOf).join('\n');
      for (final girdi in TasarimGirdileri.alanin(11)) {
        expect(
          harita,
          matches(RegExp('TasarimGirdileri\\.${girdi.ad}\\b')),
          reason: '${girdi.ad} harita katmanında okunmuyor — elle mi yazılmış?',
        );
      }
      // Geçit yarıçapı DÜNYANIN KENAR PAYINDAN geliyor ve bunun için ayrı bir
      // tepe tablo girdisi YOK — bir ara vardı (`gecisSaniyesi`) ve gereksiz
      // olduğu için kaldırıldı: ölçü zaten var olan bir sayıdan çıkıyordu.
      // Değerini sabitlemek testlerle ayırt edilemiyor (140 = margin), bu
      // yüzden bağı burada, kaynakta tutuyoruz.
      expect(
        codeOf('packages/voidspace_core/lib/src/world/gecit.dart'),
        contains('dunya.margin'),
        reason: 'geçit yarıçapı kenar payından kopmuş — sabite mi çevrildi?',
      );

      // Alan 13 — gider payları ve dönüşüm kilidi.
      final akis = codeOf(
        'packages/voidspace_core/lib/src/progression/kaynak_akisi.dart',
      );
      for (final girdi in TasarimGirdileri.alanin(13)) {
        expect(
          akis,
          matches(RegExp('TasarimGirdileri\\.${girdi.ad}\\b')),
          reason: '${girdi.ad} akışta okunmuyor — elle mi yazılmış?',
        );
      }
      expect(
        akis,
        contains('TasarimGirdileri.paraCevirmeAcik'),
        reason: 'dönüşüm kilidi koda gömülmüş — kapalı olduğu okunmuyor',
      );

      // Alan 14 — ganimet arzı.
      final ganimet = codeOf(
        'packages/voidspace_core/lib/src/progression/ganimet.dart',
      );
      for (final girdi in TasarimGirdileri.alanin(14)) {
        expect(
          ganimet,
          matches(RegExp('TasarimGirdileri\\.${girdi.ad}\\b')),
          reason: '${girdi.ad} ganimette okunmuyor — elle mi yazılmış?',
        );
      }

      // Alan 15 — kazanç. Kilitler de okunmak zorunda: NOVA'nın ne SATMADIĞI
      // koda gömülürse yasak listesi bir yorum satırına dönüşür.
      final kazanc = codeOf(
        'packages/voidspace_core/lib/src/progression/kazanc.dart',
      );
      for (final girdi in TasarimGirdileri.alanin(15)) {
        expect(
          kazanc,
          matches(RegExp('TasarimGirdileri\\.${girdi.ad}\\b')),
          reason: '${girdi.ad} kazançta okunmuyor — elle mi yazılmış?',
        );
      }
    });

    test('TÜRETİLEN hiçbir değer kaynakta sabit değil', () {
      // Mimarinin tek gerçek ihlali. Bir kez türetilmiş değer elle yazıldığında
      // kaynağı değiştirmek artık o değeri değiştirmiyor demektir — ve bu,
      // aylar sonra sebebi bulunamayan dengesizliklerin bir numaralı kaynağı.
      final turetilmis = {
        '0.084744': 'kritikPrdSabiti',
        '2.3333': 'kZirhCarpani',
        '5.6666': 'kSiyirmaCarpani',
        '5.6667': 'kSiyirmaCarpani',
        // ── Merdiven katmanı ([TuretilenTablolar]) ───────────────────
        //
        // Buraya YALNIZ türetilenler girer. `rankArtisi` (1,442), `gelirUssu`
        // (0,816) ve `maliyetSekli` (1,2293) GİRDİ: alanları yazıldığında
        // tepe tabloya yazılacaklar, yani yasaklanamazlar.
        '2333.3': 'K_zırh — kZirhCarpani × referansZirh',
        '1700.0': 'K_sıyırma — kSiyirmaCarpani × referansKaçınma',
        '2.497': 'gövde kademesi oranı — rankArtisi ^ (rank ÷ kademe)',
        '605.19': 'N(8) — kademe normalizatörünün tavanı',
        '0.595': 'referans kayıp çarpanı — (1−0,30)(1−0,15)',
        '12284': 'gövde çapası — TTK kısıtından (A × T × kayıp − kalkan)',
        '34090': 'referans EHP — A × T',
        // ── Harita katmanı (alan 11) ─────────────────────────────────
        //
        // `GameWorld.tekBantGenislik`/`tekBantYukseklik` bilerek DIŞARIDA:
        // Dart varsayılan parametre değerini `const` istiyor, `sqrt` `const`
        // değil, yani o iki sayı türetmenin zorunlu önbelleği. Ayrışmalarını
        // `bolge_test.dart` tutuyor — burası değil.
        '84948665': 'bant alanı — oyuncu × π × görüş² × seyreklik',
        '1.7333': 'PvP brüt primi — (1 + net) ÷ (1 − kayıp)',
        '19456': 'BR tavanı — referansBR(son rank) × sistem tavanı',
        // ── Düşman katmanı (alan 12) ─────────────────────────────────
        //
        // Yaratık sayılarının hiçbiri yazılamaz: can bir SÜRE, hasar bir
        // PENCERE, ödül bir BÖLME. Elle yazılan tek bir can, o bandın
        // öldürme süresini sessizce kaydırır ve savaşın temposu bozulur.
        '5682': 'güçlü yaratık canı — 5 sn × referansDPS',
        '409091': 'boss canı — grup × süre × referansDPS',
        '43200': 'boss ödülü — oyuncu-saat × saatlikHedef × prim',
      };

      final kaynaklar = [
        ...dartFilesUnder('lib'),
        ...dartFilesUnder('server/lib'),
        ...dartFilesUnder('packages/voidspace_core/lib'),
      ];

      for (final path in kaynaklar) {
        final code = codeOf(path);
        turetilmis.forEach((sayi, ad) {
          expect(
            code.contains(sayi),
            isFalse,
            reason:
                '$path içinde $ad ($sayi) elle yazılmış — türetilen değer '
                'hesaplanan alandır, sabit değil',
          );
        });
      }
    });

    test('savaş katmanı bağımsız: 01 kendi altındaki alanları OKUMAZ', () {
      // Kural belgesi kök alan; stat kütüphanesini (02) ya da gövdeyi (04)
      // içeri alması, kökün altına bağlanması demek.
      for (final path in [
        ...dartFilesUnder('packages/voidspace_core/lib/src/combat'),
        ...dartFilesUnder('packages/voidspace_core/lib/src/design'),
      ]) {
        final imports = RegExp(
          r"^import '([^']+)'",
          multiLine: true,
        ).allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!);
        for (final i in imports) {
          expect(
            i.contains('progression/') || i.contains('sim/'),
            isFalse,
            reason:
                '$path → $i · savaş katmanı büyüme katmanından okuyor '
                '("aşağı yalnız yukarıyı okur" ihlali)',
          );
        }
      }
    });
  });

  // ══ Yabancı anahtar ═════════════════════════════════════════════════
  group('yabancı anahtar', () {
    test('her eşyanın ANA statı kütüphanede var', () {
      for (final spec in Catalogue.items) {
        expect(
          Stats.byId(spec.mainStat),
          isNotNull,
          reason: '${spec.id} olmayan bir stata (${spec.mainStat}) bağlı',
        );
      }
    });

    test('her ALT STAT havuzu kütüphanede var', () {
      for (final spec in Catalogue.items) {
        for (final sub in spec.subStatPool) {
          expect(
            Stats.byId(sub),
            isNotNull,
            reason: '${spec.id} havuzunda olmayan bir stat: $sub',
          );
        }
      }
    });

    test('eşyanın kullandığı her statın FİYATI var', () {
      // Fiyatsız bir stat, bütçesi olmayan bir stattır: eşya onu verir ama
      // güç bütçesinde karşılığı yoktur, yani bedava güç.
      for (final spec in Catalogue.items) {
        for (final id in [spec.mainStat, ...spec.subStatPool]) {
          // Fiyat iki yerden gelebiliyor: saldırı tarafı GİRDİ
          // (`unitsPerPoint`), savunma tarafı TÜRETİLEN (kanallar arası kur).
          // `birimFiyati` ikisini birleştiriyor.
          expect(
            ItemBudget.birimFiyati(id),
            greaterThan(0),
            reason: '$id fiyatsız — ${spec.id} bedava güç veriyor',
          );
        }
      }
    });

    test('fiyat listesindeki her kimlik kütüphanede var', () {
      for (final id in ItemBudget.fiyatlar.keys) {
        expect(
          Stats.byId(id),
          isNotNull,
          reason: '$id fiyatlanmış ama kütüphanede yok',
        );
      }
    });

    test('her YUVA TÜRÜNÜN bütçe payı var', () {
      for (final type in SlotType.values) {
        expect(
          ItemBudget.shares.containsKey(type),
          isTrue,
          reason: '${type.name} yuvası paysız — katsayısı türetilemiyor',
        );
      }
    });

    test('kimlikler BENZERSİZ: eşya · gövde · lazer · düşman', () {
      expect(
        Catalogue.items.map((s) => s.id).toSet(),
        hasLength(Catalogue.items.length),
      );
      expect(
        HullClass.all.map((h) => h.id).toSet(),
        hasLength(HullClass.all.length),
      );
      expect(
        LaserStats.all.map((l) => l.id).toSet(),
        hasLength(LaserStats.all.length),
      );
      expect(
        AlienStats.all.map((a) => a.kind).toSet(),
        hasLength(AlienStats.all.length),
      );
    });

    test('her gövdenin her yuva türü SAYILABİLİR', () {
      for (final hull in HullClass.all) {
        for (final type in SlotType.values) {
          expect(hull.slotCount(type), greaterThanOrEqualTo(0));
        }
        expect(hull.totalSlots, greaterThan(0));
      }
    });

    test('AYNI GÖVDE İKİ KAYITTA AYRIŞMIYOR — HullClass ↔ ShipStats', () {
      // Bastion'ın taban statları bugün iki ayrı `const`ta duruyor:
      // `HullClass.bastion` (katalog, alan 04) ve `ShipStats.bastion`
      // (referans build, çalışma zamanı). İkisini tek kayda indirmek bugün
      // MÜMKÜN DEĞİL — sayılar alan 04'e ait ve o alan `bekliyor`, yani tepe
      // tabloya giremiyorlar; birleştirmek `domain/`i `progression/`den
      // okutmak demek olurdu ve bu, kurulu katman yönünün tersi.
      //
      // O yüzden tek kayıt yerine tek DOĞRULUK: ayrıştıkları an bu test
      // düşüyor. Alan 04 yazıldığında (adım 7) ikisi de türetme katmanından
      // okuyacak ve bu test kendiliğinden gereksizleşecek — o zamana kadar
      // koruyan tek şey bu.
      //
      // Neden önemli: ayrışma testleri YEŞİL bırakırken istemci tahminini
      // sunucu simülasyonundan ayırır. Oyuncunun gördüğü hata "gemi takılıyor,
      // hareket ettiremiyorum" olur ve sebebi hiçbir yerde görünmez.
      final hull = HullClass.bastion;
      const stats = ShipStats.bastion;

      expect(stats.name, hull.name, reason: 'gövde adı ayrışmış');
      // Can bilerek iki çözüm: fiyat referansı çıplak çözümü taşır (03.2),
      // gövde kaydı dolu referansınkini (08.5 s2). İkisi de kendi çapasına
      // bağlı; ayrışma kaydın değil tasarımın.
      expect(stats.maxHull, Turetilenler.govdeCapasi, reason: 'fiyat çapası');
      expect(
        hull.baseHull,
        closeTo(
          ReferansCozumu.govdeCapasi * Turetilenler.govdeKademeCarpanlari[0],
          1e-6,
        ),
        reason: 'gövde canı dolu referansın çözümünden ayrışmış',
      );
      expect(stats.maxShield, hull.baseShield, reason: 'kalkan ayrışmış');
      expect(stats.speed, hull.baseSpeed, reason: 'hız ayrışmış');

      // Namlu sayısı = yuva sayısı. Ayrıştıkları an silahın olmadığı yerden
      // mermi çıkıyor demektir — `ShipStats.bastion` yorumunun kendi kuralı.
      expect(
        stats.laserSlots,
        hull.laserSlots,
        reason: 'lazer yuvası ayrışmış: çizim ile katalog farklı namlu sayıyor',
      );

      // Ve `equippedLasers` DE bağlı olmak zorunda — asıl tuzak burası.
      // Çalışma zamanında okunan sayı bu: çizilen namlu, tele giden yaylım ve
      // hasar hep `equippedLasers`'tan geliyor, `laserSlots` yalnız kapasite.
      //
      // Bağ kopunca yuva sayısı büyür ama referans gemi eski yaylımı atmaya
      // devam eder: hangar altı yuva gösterir, gemi beş namlu ateşler, ve
      // referans yaylım bütün tasarım belgelerinde 1000'de donar.
      expect(
        stats.equippedLasers,
        hull.laserSlots,
        reason: 'referans build TAM donanımlı olmalı — kapasite doldurulmamış',
      );
    });
  });

  // ══ Girdi ↔ türetilen ayrımı ════════════════════════════════════════
  group('girdi ile türetilen ayrı', () {
    // KARAR 16.3 s1
    test('tepe tablo yalnız GİRDİ tutuyor — türetilen orada yok', () {
      final code = codeOf(
        'packages/voidspace_core/lib/src/design/tasarim_girdileri.dart',
      );
      for (final ad in [
        'kritikPrdSabiti',
        'kZirh',
        'kSiyirma',
        'BeklenenDeger',
      ]) {
        expect(
          code.contains(ad),
          isFalse,
          reason: '$ad türetilen bir değer; tepe tabloda duramaz',
        );
      }
    });

    test('türetilenlerin ÜSTÜNE yazılamaz — hepsi hesaplanan alan', () {
      // `Turetilenler` bir sınıf değil, bir hesap: yazılabilecek bir alanı
      // olmadığı için kimse üstüne yazamaz.
      final code = codeOf(
        'packages/voidspace_core/lib/src/design/turetilenler.dart',
      );
      expect(
        RegExp(r'static\s+(?!final|const)\w+\s+\w+\s*=').hasMatch(code),
        isFalse,
        reason: 'türetilenler dosyasında değiştirilebilir bir alan var',
      );
    });

    test('BEKLEYEN sabitler tahmin edilmemiş', () {
      // Bu test bir zamanlar `kZirh`in `null` olduğunu iddia ediyordu; alan 04
      // yazılınca sabit çözüldü ve o iddia geçersizleşti. Kalıcı olan kural
      // sabitin kendisi değil MEKANİZMA: bekleyenler listesindeki her sabit
      // hâlâ `null` olmak ZORUNDA, ve beklediği alan hâlâ `bekliyor` olmalı.
      //
      // Çözülmüş bir sabiti listede bırakmak, sistemin "bekliyorum" dediği
      // ama aslında tahmin ettiği bir sayı üretirdi — mekanizmanın tam olarak
      // engellemek için var olduğu şey.
      // Bugün bekleyen sabit YOK: hepsi çözüldü. Liste boşaldığında test
      // anlamsızlaşmıyor — yeni bir bekleyen eklendiğinde aynı kural onu
      // karşılıyor.
      for (final bekleyen in BekleyenGirdiler.bekleyenler.entries) {
        expect(
          TasarimHaritasi.byNo(bekleyen.value),
          isNotNull,
          reason: '${bekleyen.key} olmayan bir alanı bekliyor',
        );
        expect(
          TasarimHaritasi.byNo(bekleyen.value)!.durum,
          BelgeDurumu.bekliyor,
          reason:
              '${bekleyen.key} yazılmış bir alanı bekliyor — o alan geldiyse '
              'sabit çözülmüş olmalıydı',
        );
      }

      // Ve tersi: ÇÖZÜLMÜŞ bir sabit listede duramaz.
      expect(
        BekleyenGirdiler.bekleyenler.keys,
        isNot(anyElement(isIn(['kZirh', 'kSiyirma']))),
        reason: 'çözülmüş sabit hâlâ bekleyenler listesinde',
      );
    });
  });
}
