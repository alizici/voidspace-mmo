@Tags(['kod-belge', 'kapsam'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// 15.2 · KREDİ MAĞAZASI: TABAN EŞYA — raf bandın bir altı.
///
/// Uzun süre raf sabit on altı tasarımdı ve fiyatı tasarımın kendi sayısıydı;
/// 15.2'nin modeli kodda vardı ama raf onu okumuyordu, ve raf ikinci ile
/// üçüncü rankı sattığı için açılış sırası (10.7) parayla atlanabiliyordu
/// (borç defteri B14). Burada ölçülen: rafın rankı, para birimi, fiyatı ve
/// alınan eşyanın taban oluşu.
void main() {
  TxContext tx() => const TxContext(id: 't', atMillis: 0);

  group('15.2 · raf bandın bir altı', () {
    // KARAR 15.2 s1
    test('her bantta her yuva tipi için taban eşya var, rankı bandın altı', () {
      for (final bolge in Bolge.hepsi) {
        final raf = Catalogue.rafFor(bolge.ilkRank);
        final beklenen =
            ItemTier.values[Kazanc.tabanEsyaRankiFor(bolge.ilkRank)];
        for (final tip in SlotType.values) {
          final olanlar = raf.where((s) => s.slot == tip).toList();
          expect(olanlar, isNotEmpty, reason: '${bolge.ad}: $tip için raf boş');
          for (final s in olanlar) {
            expect(
              s.tier,
              beklenen,
              reason: '${s.id} bandın bir altında değil',
            );
          }
        }
        // NOVA eşya satmıyor (15.1): raf hep kredi, tasarımın para birimi
        // ne olursa olsun.
        expect(
          Catalogue.rafFiyati(bolge.ilkRank).currency,
          Currency.credit,
          reason: '${bolge.ad}: raf NOVA istiyor',
        );
      }
    });

    test('ilk bantta raf C-I: C-II ve C-III raftan indi', () {
      final raf = Catalogue.rafFor(0).map((s) => s.id).toSet();
      expect(
        raf,
        containsAll([
          'pl1',
          'df1',
          'th1',
          'mk1',
          'cpu_repair',
          'cpu_scope',
          'dr1',
        ]),
      );
      expect(raf, isNot(contains('pl3')), reason: 'C-II lazer rafta');
      expect(raf, isNot(contains('pl4')), reason: 'C-III lazer rafta');
      expect(raf, isNot(contains('pl5')), reason: 'B-I lazer rafta');
    });

    test('raftan alınan eşya TABAN: alt statı yok, fiyatı modelin', () {
      final h = Hangar(accountId: 'a', credits: 1 << 40);
      final (item, hata) = HangarRules.raftanAl(
        h,
        'pl1',
        'x',
        tx(),
        bandRank: 0,
      );
      expect(hata, isNull);
      expect(item!.taban, isTrue);
      expect(
        LoadoutResolver.altStatlariFor(item, Catalogue.pl1, HullClass.starter),
        isEmpty,
        reason: 'taban eşyaya alt stat türedi — derinlik satılmış',
      );
      expect((1 << 40) - h.credits, Catalogue.rafFiyati(0).amount);
      expect(
        Catalogue.rafFiyati(0).amount,
        Kazanc.tabanEsyaFiyatiFor(0).round(),
        reason: 'raf fiyatı 15.2 modelinden ayrıştı',
      );
      // Kayıt: bayrak gidip geliyor, taban olmayanda hiç yazılmıyor.
      expect(ItemInstance.fromJson(item.toJson()).taban, isTrue);
      expect(
        const ItemInstance(instanceId: 'y', specId: 'pl1').toJson(),
        isNot(contains('taban')),
      );
    });

    // KARAR 10.7 s1
    test('bandın üstü raftan alınamaz; alınan eşya açılışı atlatmıyor', () {
      final h = Hangar(accountId: 'a', credits: 1 << 40);
      final (_, hata) = HangarRules.raftanAl(h, 'pl3', 'x', tx(), bandRank: 0);
      expect(hata, HangarError.notPurchasable);
      final (alinan, _) = HangarRules.raftanAl(
        h,
        'pl1',
        'y',
        tx(),
        bandRank: 0,
      );
      expect(alinan, isNotNull);
      // Artı basma ikinci rankın eşyası görülünce açılıyor (10.7); raf onu
      // gösteremez.
      expect(
        Acilis.acik(Sistem.artiBasma, h),
        isFalse,
        reason: 'raftan alınan eşya açılış sırasını atlattı',
      );
    });
  });

  /// 15.8 · BAŞLANGIÇ KREDİSİ RAFTAN TÜRÜYOR — borç defteri B21.
  ///
  /// Elle yazılmış 30.000 kredi rafın 94.522'lik taban eşyasını
  /// karşılamıyordu: yeni oyuncu ilk oturumunda raftan hiçbir şey alamıyor,
  /// mağaza ona kapalı bir kapı gösteriyordu. Ölçülen: kredinin türetilmiş
  /// olması ve gerçekten `baslangicEsyaSayisi` eşya alması.
  group('15.8 · başlangıç kredisi', () {
    // KARAR 15.8 s1
    test('ilk bandın raf fiyatının tam katı, elle yazılmış sayı değil', () {
      expect(
        Hangar.startingCredits,
        Catalogue.rafFiyati(0).amount * TasarimGirdileri.baslangicEsyaSayisi,
      );
      expect(
        TasarimGirdileri.baslangicEsyaSayisi,
        greaterThanOrEqualTo(1),
        reason: 'kapı kapalı: yeni oyuncu raftan hiçbir şey alamıyor',
      );
    });

    // KARAR 15.8 s1
    test('yeni hesap raftan tam o kadar eşya alabiliyor, bir fazlasını değil', () {
      final h = Hangar(accountId: 'a');
      expect(h.credits, Hangar.startingCredits);
      // Bir lazer, bir jeneratör: iki farklı yuva tipi, iki kanal.
      const raf = ['pl1', 'df1', 'th1', 'mk1', 'cpu_repair', 'cpu_scope'];
      for (var i = 0; i < TasarimGirdileri.baslangicEsyaSayisi; i++) {
        final (item, hata) = HangarRules.raftanAl(
          h,
          raf[i % raf.length],
          'i$i',
          tx(),
          bandRank: 0,
        );
        expect(hata, isNull, reason: '${i + 1}. taban eşya alınamadı');
        expect(item, isNotNull);
      }
      expect(
        h.credits,
        0,
        reason: 'başlangıç kredisi raf fiyatının tam katı değil',
      );
      final (_, son) = HangarRules.raftanAl(h, 'pl1', 'fazla', tx(), bandRank: 0);
      expect(
        son,
        HangarError.notEnoughCredits,
        reason: 'kredi ilan edilen eşya sayısından fazlasını alıyor',
      );
    });
  });
}
