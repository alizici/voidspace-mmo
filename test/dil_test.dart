@Tags(['disi'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/app/app.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/dil/dil_deposu.dart';
import 'package:voidspace3/dil/dil_kapsami.dart';
import 'package:voidspace3/dil/durum_metni.dart';
import 'package:voidspace3/dil/icerik.dart';
import 'package:voidspace3/dil/kimlik_metni.dart';
import 'package:voidspace3/dil/metin.dart';
import 'package:voidspace3/dil/sayi.dart';
import 'package:voidspace3/game/art/droid_art.dart';
import 'package:voidspace3/hangar/droid_ikonu.dart';
import 'package:voidspace3/net/durum_kodu.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// ÜÇ DİL — çeviri katmanının kilidi.
///
/// Burada sınanan şey çevirilerin GÜZELLİĞİ değil BÜTÜNLÜĞÜ: hiçbir metnin
/// boş kalmaması, hiçbir yer tutucunun bir dilde düşmemesi, ve çekirdeğin
/// bildiği her kimliğin bir karşılığı olması. Bunlar gözle yakalanmayan
/// hatalar — İtalyanca oynayan biri olmadan hiç fark edilmezler.
void main() {
  group('Dil.cozumle', () {
    test('bölgeli kodu tanır', () {
      expect(Dil.cozumle('tr_TR'), Dil.turkce);
      expect(Dil.cozumle('it-IT'), Dil.italyanca);
      expect(Dil.cozumle('en'), Dil.ingilizce);
    });

    test('tanınmayan ve bozuk kod varsayılana düşer', () {
      // Bozuk bir tercih dosyası oyunu açılmaz hâle getirmemeli.
      for (final kod in [null, '', 'x', 'de', 'zzzz']) {
        expect(Dil.cozumle(kod), Dil.varsayilan);
      }
    });
  });

  group('Metin', () {
    test('hiçbir dilde boş metin yok', () {
      for (final metin in Metin.values) {
        for (final dil in Dil.values) {
          expect(
            metin(dil).trim(),
            isNotEmpty,
            reason: '${metin.name} · ${dil.kod} boş',
          );
        }
      }
    });

    test('yer tutucular üç dilde AYNI', () {
      // Bir dilde `{n}` düşerse o dilde sayı hiç görünmez ve kimse fark
      // etmez: cümle yine dilbilgisel olarak doğru okunur, yalnız eksiktir.
      final yerTutucu = RegExp(r'\{(\w+)\}');
      for (final metin in Metin.values) {
        Set<String> anahtarlar(Dil dil) =>
            yerTutucu.allMatches(metin(dil)).map((m) => m.group(1)!).toSet();
        final beklenen = anahtarlar(Dil.turkce);
        for (final dil in Dil.values) {
          expect(
            anahtarlar(dil),
            beklenen,
            reason: '${metin.name} · ${dil.kod} yer tutucuları ayrışmış',
          );
        }
      }
    });

    test('bicim yer tutucuyu doldurur', () {
      expect(Metin.tavanArti.bicim(Dil.ingilizce, {'n': 15}), 'MAX · +15');
    });
  });

  group('Sayı biçimi', () {
    test('binlik ayracı dile göre', () {
      expect(sayi(12400, Dil.turkce), '12.400');
      expect(sayi(12400, Dil.italyanca), '12.400');
      expect(sayi(12400, Dil.ingilizce), '12,400');
    });

    test('ondalık ayracı dile göre', () {
      expect(ondalikli(2.45, Dil.turkce), '2,5');
      expect(ondalikli(2.45, Dil.ingilizce), '2.5');
    });

    test('yüzde işareti dile göre yer değiştirir', () {
      expect(yuzde(15, Dil.turkce), '%15');
      expect(yuzde(15, Dil.ingilizce), '15%');
      expect(yuzde(15, Dil.italyanca), '15%');
    });

    test('eksi işareti korunuyor', () {
      expect(sayi(-12400, Dil.turkce), '-12.400');
    });
  });

  group('İçerik adları', () {
    test('her stat üç dilde de çevrili', () {
      for (final stat in Stats.hepsi) {
        expect(
          statAdi(stat.id, Dil.turkce),
          stat.label,
          reason: '${stat.id} Türkçesi çekirdekle ayrışmış',
        );
        for (final dil in [Dil.ingilizce, Dil.italyanca]) {
          expect(
            statAdi(stat.id, dil),
            isNot(stat.label),
            reason: '${stat.id} ${dil.kod} çevirisi eksik — Türkçeye düşüyor',
          );
        }
      }
    });

    test('her formasyon üç dilde de çevrili', () {
      for (final f in Formasyon.hepsi) {
        expect(formasyonAdi(f, Dil.turkce), f.ad);
        for (final dil in [Dil.ingilizce, Dil.italyanca]) {
          expect(
            formasyonAdi(f, dil).isNotEmpty,
            isTrue,
            reason: '${f.id} ${dil.kod} eksik',
          );
        }
      }
    });

    test('her bölge üç dilde de çevrili', () {
      for (final b in Bolge.hepsi) {
        expect(bolgeAdi(b, Dil.turkce), b.ad);
        for (final dil in [Dil.ingilizce, Dil.italyanca]) {
          expect(
            bolgeAdi(b, dil),
            isNot(b.ad),
            reason: '${b.ad} ${dil.kod} çevirisi eksik',
          );
        }
      }
    });

    test('her ünvan ÇAĞI üç dilde de çevrili', () {
      // Ünvanların KENDİ adları (Squire, Knight) bilerek çevrilmiyor — özel
      // ad. Çağ ise bir aşama adı ve merdiven satırlarının başlığı: dört
      // satır, üç dil, ve İtalyanca oynayan biri o dördü okuyarak nerede
      // olduğunu anlıyor.
      for (var i = 0; i < Unvan.caglar.length; i++) {
        expect(cagAdiSirali(i, Dil.turkce), Unvan.caglar[i]);
        for (final dil in [Dil.ingilizce, Dil.italyanca]) {
          expect(
            cagAdiSirali(i, dil),
            isNot(Unvan.caglar[i]),
            reason: '${Unvan.caglar[i]} ${dil.kod} çevirisi eksik',
          );
        }
      }
    });

    test('kod ve özel adlar ÇEVRİLMİYOR', () {
      // Rank kodları oyuncular arasında konuşulan şeyler; çevrilirse iki
      // oyuncu aynı eşyaya iki ad verir.
      expect(rankEtiketi(ItemTier.cII, Dil.ingilizce), 'C-II');
      expect(rankEtiketi(ItemTier.cII, Dil.italyanca), 'C-II');
      // NOVA ekonominin özel adı.
      expect(paraAdi(Currency.premium, Dil.ingilizce), premiumName);
    });

    test('kapak taşları ve kredi çevriliyor', () {
      expect(rankEtiketi(ItemTier.kirmizi, Dil.ingilizce), 'RED');
      expect(paraAdi(Currency.credit, Dil.turkce), creditName);
      expect(paraAdi(Currency.credit, Dil.ingilizce), isNot(creditName));
    });

    test('harita adı bölge + tip', () {
      final harita = Harita(Bolge.ilk, HaritaTipi.pve);
      expect(harita.ad, contains(Bolge.ilk.ad));
      expect(haritaAdi(harita, Dil.ingilizce), contains('Shallows'));
      // Tip her dilde aynı: oyun terimi, tür adı değil.
      expect(haritaAdi(harita, Dil.italyanca), contains(HaritaTipi.pve.ad));
    });
  });

  // ── Eşya adları ─────────────────────────────────────────────────────
  //
  // Eşyanın adı çeviri katmanının EN KIRILGAN yeri, çünkü tek parça değil:
  // raftakiler elle yazılmış, üst ranklar `<önek> <rank>` diye türetiliyor ve
  // droidinki tasarımından geliyor. Üç yol da sessizce Türkçeye düşebiliyordu
  // ve düştüğünü yalnız İngilizce oynayan biri görürdü.
  group('Eşya adları', () {
    // KARAR 05.8 s2
    test('droidin ADI da örneğin seçtiği tasarımı yansıtıyor', () {
      // Aynı hücrede iki ayrı droid gösterilmesin: çizim örneğin tasarımını
      // seçiyordu (`droidCizimiOf`), ad ise şemanın `variant`ını. Delta'sına
      // Jiroskop görünüşü takan oyuncu Jiroskop çizimini görüyor ama ipucunda
      // "Delta C-I" okuyordu.
      const spec = Catalogue.dr1;
      final sema = esyaAdi(spec, Dil.turkce);
      // Şemanın kendi adı DEĞİŞMİYOR: örneksiz çağrı eskisi gibi.
      expect(sema, spec.name);

      // Örnek başka bir tasarım seçmişse ad onu söylüyor.
      final baska = DroidModeli.merdiven
          .firstWhere((m) => m.name != spec.variant)
          .name;
      final giydirilmis = ItemInstance(
        instanceId: 'd',
        specId: spec.id,
        tasarim: baska,
      );
      final ad = esyaAdi(spec, Dil.turkce, item: giydirilmis);
      expect(ad, isNot(sema), reason: 'ad şemada kaldı');
      expect(ad, contains(droidTasarimAdi(baska, Dil.turkce, yedek: '')));

      // ÇİZİMLE AYNI KURAL: ikisi de aynı tasarımı gösteriyor.
      expect(
        droidTasarimKimligi(spec, giydirilmis),
        baska,
        reason: 'ad ile çizim ayrı kural kullanıyor',
      );
      // Tasarımsız örnek şemaya düşüyor.
      expect(
        droidTasarimKimligi(
          spec,
          const ItemInstance(instanceId: 'x', specId: 'dr1'),
        ),
        spec.variant,
      );
      // Droid olmayanda kural YOK.
      expect(droidTasarimKimligi(Catalogue.pl1, giydirilmis), isNull);
    });


    // Tanınmayan kimlik çağrı yerinin YEDEĞİNE düşüyor. Testler o yedeği bir
    // nişan taşı olarak kullanıyor: "çeviri var mı" sorusu ancak yedeğin
    // görünmediği sınanarak sorulabilir — yedek çekirdeğin Türkçe adı
    // olsaydı, eksik çeviri ile doğru Türkçe çeviri aynı dizeyi verirdi.
    const yedek = '‹yedek›';

    ItemSpec esya(bool Function(ItemSpec) kosul) =>
        Catalogue.items.firstWhere(kosul);

    test('her droid TASARIMI üç dilde de çevrili', () {
      for (final tasarim in DroidModeli.values) {
        for (final dil in Dil.values) {
          expect(
            droidTasarimAdi(tasarim.name, dil, yedek: yedek),
            isNot(yedek),
            reason: '${tasarim.name} ${dil.kod} çevirisi yok',
          );
        }
        // Türkçe sütun ÇİZİM KATALOGUYLA aynı kalmak zorunda: droid statıyla
        // değil görünüşüyle tanınan tek eşya, ve mağazadaki ad ile filodaki
        // droidin adı ayrışırsa oyuncu iki ayrı şey satın aldığını sanır.
        expect(
          droidTasarimAdi(tasarim.name, Dil.turkce, yedek: yedek),
          DroidArt.of(droidCizimiAdiyla(tasarim.name)).ad,
          reason: '${tasarim.name} Türkçesi sanat kataloguyla ayrışmış',
        );
      }
    });

    test('droid adı KİMLİKTEN çevriliyor, görünen ADDAN değil', () {
      // Borç defteri B36: sözlük bir zaman droidin Türkçe ADIYLA
      // anahtarlıydı, yani çizim katalogunda bir ad düzeltmek çeviriyi
      // sessizce ıskalatıyordu. Görünen ad artık bir anahtar DEĞİL ve bu
      // satır o kapının kapalı kaldığını sınıyor.
      expect(droidTasarimAdi('Halka', Dil.ingilizce, yedek: yedek), yedek);
      expect(droidTasarimAdi(null, Dil.ingilizce, yedek: yedek), yedek);

      // Raftaki droidin adı çıplak bir tasarım adı (rank soneki yok);
      // merdivenden türetilenin adı `<tasarım> <rank>`. İkisi de aynı
      // kimlikten okunuyor.
      expect(esyaAdi(Catalogue.byId['dr5']!, Dil.ingilizce), 'Crescent');
      expect(esyaAdi(Catalogue.byId['dr1']!, Dil.italyanca), 'Delta');
      final turetilen = esya(
        (s) => s.slot == SlotType.droid && s.variant == 'halka',
      );
      expect(esyaAdi(turetilen, Dil.ingilizce), startsWith('Ring '));
      expect(esyaAdi(turetilen, Dil.italyanca), startsWith('Anello '));
    });

    test('türetilen eşyanın ÖNEKİ İngilizcede Türkçe kalmıyor', () {
      // Çekirdek üst rankları rafın en iyisinden türetiyor ve adı ŞABLONUN
      // İLK KELİMESİYLE kuruyor. Dört yuvada o kelime bir model kodu ve
      // çevrilecek bir şey yok; CPU'nunki ise düpedüz Türkçe.
      final cpu = esya((s) => s.slot == SlotType.cpu && s.id.contains('-'));
      expect(esyaAdi(cpu, Dil.turkce), startsWith('Tamir '));
      expect(esyaAdi(cpu, Dil.ingilizce), startsWith('Repair '));
      expect(esyaAdi(cpu, Dil.italyanca), startsWith('Riparazione '));

      // Model kodu AYNEN kalıyor — "PL-5"i çevirmek, iki oyuncuyu aynı
      // eşyaya iki ad vermeye zorlardı.
      final lazer = esya((s) => s.id == 'laser-ssI');
      expect(esyaAdi(lazer, Dil.italyanca), 'PL-5 SS-I');
    });

    test('her eşyanın TÜRKÇE adı çekirdeğinkiyle BİREBİR', () {
      // Türkçe kanonik: çekirdekteki `ItemSpec.name` tasarım belgelerinin adı
      // ve çeviri katmanı onu Türkçede yeniden ÜRETİYOR. Tek eşitlik üç ayrı
      // sessiz bozulmayı birden yakalıyor — sözlükte ölü ya da yanlış
      // yazılmış bir kimlik, rank sonekini yanlış kuran bir birleştirme, ve
      // çekirdeğin türetme kuralı değişince eskiyen bir önek.
      for (final spec in Catalogue.items) {
        expect(
          esyaAdi(spec, Dil.turkce),
          spec.name,
          reason: '${spec.id} Türkçesi çekirdekle ayrışmış',
        );
      }
    });

    test('hiçbir eşya adı BOŞ kalmıyor', () {
      for (final spec in Catalogue.items) {
        for (final dil in Dil.values) {
          expect(
            esyaAdi(spec, dil).trim(),
            isNotEmpty,
            reason: '${spec.id} ${dil.kod} boş',
          );
        }
      }
    });
  });

  group('Sunucu kodları cümleye dönüyor', () {
    test('her kimlik kodunun karşılığı var', () {
      for (final kod in KimlikKodu.values) {
        for (final dil in Dil.values) {
          final metin = kimlikMetni(kod.kod, dil);
          expect(metin, isNotNull);
          expect(
            metin,
            isNot(kod.kod),
            reason: '${kod.name} ${dil.kod} ham kod olarak görünüyor',
          );
        }
      }
    });

    test('sürüm uyuşmazlığı argümanları taşıyor', () {
      final ham = KimlikKodu.surumUyusmazligi.yaz([7, 5]);
      final metin = kimlikMetni(ham, Dil.ingilizce)!;
      expect(metin, contains('7'));
      expect(metin, contains('5'));
    });

    test('her ağ durumunun karşılığı var', () {
      for (final kod in DurumKodu.values) {
        for (final dil in Dil.values) {
          expect(durumMetni(kod.kod, dil), isNot(kod.kod));
        }
      }
    });

    test('her geçit reddinin karşılığı var', () {
      for (final kod in GecitKodu.values) {
        for (final dil in Dil.values) {
          expect(gecitMetni(kod.kod, dil), isNot(kod.kod));
        }
      }
    });

    test('her hangar hatasının karşılığı var', () {
      for (final hata in HangarError.values) {
        expect(hangarHataMetni(hata.name, Dil.turkce), hata.message);
        for (final dil in [Dil.ingilizce, Dil.italyanca]) {
          expect(hangarHataMetni(hata.name, dil), isNot(hata.name));
        }
      }
    });

    test('tanınmayan kod HAM gösteriliyor, yutulmuyor', () {
      // Bilinmeyen bir hata, görünmeyen bir hatadan iyidir.
      expect(durumMetni('bilinmeyen.kod', Dil.turkce), 'bilinmeyen.kod');
      expect(kimlikMetni('bilinmeyen.kod', Dil.turkce), 'bilinmeyen.kod');
    });
  });

  group('DilKapsami', () {
    testWidgets('kapsam yoksa Türkçeye düşer', (tester) async {
      late Dil okunan;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            okunan = context.dil;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(okunan, Dil.turkce);
    });

    testWidgets('cihaz dili kullanılıyor, kayıt onu eziyor', (tester) async {
      late Dil okunan;
      Widget kur(DilDeposu depo, String? cihaz) => DilSaglayici(
        depo: depo,
        cihazDili: cihaz,
        child: Builder(
          builder: (context) {
            okunan = context.dil;
            return const SizedBox.shrink();
          },
        ),
      );

      // Kayıt yokken cihazın dili.
      await tester.pumpWidget(kur(BellekDilDeposu(), 'it-IT'));
      await tester.pump();
      expect(okunan, Dil.italyanca);

      // Kayıtlı tercih cihazı EZİYOR: Türkçe bir telefonda İngilizce oynamak
      // isteyen biri her açılışta geri atılmamalı.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(kur(BellekDilDeposu('en'), 'tr'));
      await tester.pump();
      expect(okunan, Dil.ingilizce);
    });

    testWidgets('dil değişince tercih diske yazılıyor', (tester) async {
      final depo = BellekDilDeposu();
      late DilKapsami kapsam;
      await tester.pumpWidget(
        DilSaglayici(
          depo: depo,
          cihazDili: 'tr',
          child: Builder(
            builder: (context) {
              kapsam = DilKapsami.of(context);
              return Text(
                Metin.kapat(context.dil),
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );
      expect(find.text('KAPAT'), findsOneWidget);

      kapsam.degistir(Dil.italyanca);
      await tester.pump();
      expect(find.text('CHIUDI'), findsOneWidget);
      expect(await depo.oku(), 'it');
    });
  });

  testWidgets('uygulama kökü DilSaglayici kuruyor', (tester) async {
    await tester.pumpWidget(const VoidspaceApp(cihazDili: 'it'));
    await tester.pump();
    expect(
      find.byType(DilSaglayici),
      findsOneWidget,
      reason: 'kök kapsamı kurmazsa oyun sessizce tek dilde kalır',
    );
  });
}
