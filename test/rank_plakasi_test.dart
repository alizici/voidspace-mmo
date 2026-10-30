@Tags(['disi'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/dil/dil.dart';
import 'package:voidspace3/hangar/item_glyph.dart';
import 'package:voidspace3/hangar/menu_theme.dart';
import 'package:voidspace3/hangar/rank_kutusu.dart';
import 'package:voidspace3/hangar/rank_plakasi.dart';
import 'package:voidspace_core/voidspace_core.dart';

void main() {
  group('rank görseli · eksenler', () {
    test('yirmi rankın yirmisinin de görseli var', () {
      expect(RankGorseli.hepsi.length, ItemTier.values.length);
      for (final t in ItemTier.values) {
        expect(RankGorseli.of(t).tier, t);
      }
    });

    test('görsel aile SEKİZ adım, mekanik aile ALTI', () {
      // İkisi bilerek ayrı: çevirme maliyeti kapak taşlarında SSS ile aynı
      // (mekanik gruplama) ama onlar RENKLE adlandırılmış, yani görsel
      // eksende kendi zeminlerini almak zorundalar.
      final gorsel = RankGorseli.hepsi.map((r) => r.gorselAile).toSet();
      expect(gorsel.length, 8);
      expect(ItemTier.values.map((t) => t.aile).toSet().length, 6);
      expect(RankGorseli.of(ItemTier.kirmizi).gorselAile, 6);
      expect(RankGorseli.of(ItemTier.parlayanPembe).gorselAile, 7);
      expect(
        ItemTier.kirmizi.aile,
        ItemTier.sssIII.aile,
        reason: 'mekanik eksende kapak taşları SSS ile aynı ailede',
      );
    });

    test('kapak taşlarının basamağı EN ÜST çerçeve', () {
      for (final t in [ItemTier.kirmizi, ItemTier.parlayanPembe]) {
        final r = RankGorseli.of(t);
        expect(r.kapakTasi, isTrue);
        expect(r.basamak, 2);
      }
      // Kapak taşı olmayanlarda basamak merdivenden çıkıyor.
      expect(RankGorseli.of(ItemTier.cI).basamak, 0);
      expect(RankGorseli.of(ItemTier.cII).basamak, 1);
      expect(RankGorseli.of(ItemTier.cIII).basamak, 2);
      expect(RankGorseli.of(ItemTier.sI).basamak, 0);
    });

    test('derinlik KODDAN geliyor, tablodan değil', () {
      for (final t in ItemTier.values) {
        expect(RankGorseli.of(t).derinlik, ItemBudget.altStatSayisi(t));
      }
      // Belge tablosu bir zamanlar "renkler = 7" diyordu; kod dörtte kesiyor.
      expect(RankGorseli.of(ItemTier.parlayanPembe).derinlik, 7);
      expect(
        RankGorseli.hepsi
            .map((r) => r.derinlik)
            .reduce((a, b) => a > b ? a : b),
        ItemBudget.altStatTavani,
      );
    });
  });

  group('rank görseli · yörünge', () {
    test('S ve altında YOK, üstünde birer birer artıyor', () {
      const beklenen = {
        ItemTier.cIII: 0,
        ItemTier.bIII: 0,
        ItemTier.aIII: 0,
        ItemTier.sI: 1,
        ItemTier.ssI: 2,
        ItemTier.sssI: 3,
        ItemTier.kirmizi: 4,
        ItemTier.parlayanPembe: 5,
      };
      for (final e in beklenen.entries) {
        expect(
          RankGorseli.of(e.key).yorungeNoktasi,
          e.value,
          reason: e.key.label,
        );
      }
    });

    test('aynı ailenin üç basamağı AYNI sayıda nokta taşıyor', () {
      // Nokta AİLEYİ sayıyor, basamağı değil — basamağı köşe işaretleri
      // taşıyor. İkisi karışırsa S-III ile SS-I aynı görünürdü.
      for (final aile in [
        [ItemTier.sI, ItemTier.sII, ItemTier.sIII],
        [ItemTier.ssI, ItemTier.ssII, ItemTier.ssIII],
        [ItemTier.sssI, ItemTier.sssII, ItemTier.sssIII],
      ]) {
        final sayilar = aile.map((t) => RankGorseli.of(t).yorungeNoktasi);
        expect(sayilar.toSet().length, 1, reason: aile.first.label);
      }
    });

    test('nokta sayısı SAYILABİLİR kalıyor — en çok beş', () {
      final enCok = RankGorseli.hepsi
          .map((r) => r.yorungeNoktasi)
          .reduce((a, b) => a > b ? a : b);
      expect(
        enCok,
        5,
        reason: 'altı dönen nokta bir halkaya dönüşür ve sayı okunmaz',
      );
    });
  });

  group('rank plakası · çizim', () {
    test('dolgu alfası AİLEYE GÖRE ARTMIYOR', () {
      // Ölçüt "C-I nişan devresinin iç dolgusu". Artış geri gelirse üst
      // ranklarda plaka doygun bir renk lekesine dönüyor ve hücrenin konusu
      // olan eşya onun içinde kayboluyor.
      expect(RankPlakasi.dolguAlfasi, 0.16);
    });

    test('kıl çizgilerde 1 piksel TABANI yok', () {
      // Taban, oranı tam da korumak istediği yerde bozuyordu: 56 pikselde
      // kenarlık iki buçuk kat kalın çiziliyor, 110'da yalnız %30. Aynı
      // plaka küçükken "daha sıkı" görünüyor ve fark DOLGUDAN sanılıyordu.
      //
      // Tabana gerek de yok: Flutter alt-piksel bir konturu kendiliğinden
      // yumuşatıyor. Guard kaynağı okuyor çünkü `strokeWidth` çizim anında
      // dışarıdan ölçülemiyor.
      final kaynak = File('lib/hangar/rank_plakasi.dart')
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        kaynak,
        isNot(contains('strokeWidth = math.max(1, s *')),
        reason: 'kıl çizgi tabanı geri gelmiş — oran yine bozulur',
      );
    });
  });

  group('rank kutusu · bileşen', () {
    testWidgets('boş kutu · rank yok, işaret yok, çökme yok', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: RankKutusu(boy: 56)),
        ),
      );
      expect(find.byType(RankKutusu), findsOneWidget);
      expect(tester.getSize(find.byType(RankKutusu)), const Size(56, 56));
    });

    testWidgets('boy DEĞİŞTİĞİNDE içindeki her şey ölçekleniyor', (
      tester,
    ) async {
      // Bileşenin var olma sebebi bu: aynı kutu 30 ile 110 arasında dört
      // boyda çiziliyor ve tek bir sabit piksel taşımamalı.
      for (final boy in const [30.0, 56.0, 110.0]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RankKutusu(
                boy: boy,
                rank: ItemTier.parlayanPembe,
                arti: 15,
                pip: true,
                yukseltme: true,
                isaret: const KutuIsareti.esya(
                  ItemGlyph.laser,
                  Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(RankKutusu)), Size(boy, boy));
      }
    });

    test('işaret boyu yörünge yarıçapının İÇİNDE kalıyor', () {
      // Noktalar 0,32'de dönüyor ve yarıçapları 0,030. İşaret onlara
      // değerse dönen nokta glifin altından geçip kaybolur.
      for (final boy in const [30.0, 56.0, 110.0, 220.0]) {
        expect(
          rankIsaretiSigiyor(boy),
          isTrue,
          reason: '$boy pikselde işaret yörüngeye giriyor',
        );
      }
    });

    test('kapak taşları hücrede ETİKET yazmıyor', () {
      // "KIRMIZI" ve "PARLAYAN PEMBE" 56 piksele sığmıyor ve
      // kısaltılamıyorlar. Yazılmamaları kayıp değil: o iki rank RENKLE
      // adlandırılmış ve plakanın zemini tam o rengi taşıyor.
      expect(RankGorseli.of(ItemTier.kirmizi).kisaEtiket, isNull);
      expect(RankGorseli.of(ItemTier.parlayanPembe).kisaEtiket, isNull);
      for (final t in ItemTier.values.where((t) => t.index < 18)) {
        expect(RankGorseli.of(t).kisaEtiket, t.label);
      }
    });
  });

  group('bicimliStat · birim kütüphaneden', () {
    test('yüzde statı 1\'i aşınca da YÜZDE kalıyor', () {
      // Eski kural "1'den küçükse yüzde" idi. Parlayan Pembe'de hasar artışı
      // 52 (%5.200) ve kart onu birimsiz "52" yazıyordu; S-II'de 0,94 ile 1,0
      // aynı satırda "%94,0 – 1" diye iki farklı birimde okunuyordu.
      final yuzdeler = Stats.all.where((s) => s.percent).map((s) => s.id);
      expect(yuzdeler, isNotEmpty);
      for (final id in yuzdeler) {
        // %100'ün altında bir ondalık: C ailesinin aralığı orada yaşıyor.
        expect(bicimliStat(id, 0.028, Dil.turkce), '%2,8', reason: id);
        expect(bicimliStat(id, 0.94, Dil.turkce), '%94,0', reason: id);
        expect(
          bicimliStat(id, 1.0, Dil.turkce),
          '%100',
          reason: '$id — 1,0 yüzde değil mi',
        );
        expect(
          bicimliStat(id, 52, Dil.turkce),
          '%5.200',
          reason: '$id — tavan aşıldı',
        );
      }
    });

    test('mutlak stat tam sayı, yüzde işareti YOK', () {
      final mutlaklar = Stats.all.where((s) => !s.percent).map((s) => s.id);
      expect(mutlaklar, isNotEmpty);
      for (final id in mutlaklar) {
        expect(bicimliStat(id, 0.4, Dil.turkce), '0', reason: id);
        expect(bicimliStat(id, 366782.4, Dil.turkce), '366.782', reason: id);
      }
    });
  });
}
