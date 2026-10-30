import 'dart:math' as math;

import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../domain/ship_stats.dart';
import '../progression/catalogue.dart';
import '../progression/currency.dart';
import '../progression/saglayici.dart';
import '../progression/item.dart';
import '../progression/loadout.dart';
import '../progression/referans_build.dart';
import '../progression/stat.dart';

/// NOVA rafının bir alımının ÖLÇÜLEN sonucu — tek bant, tek kalem.
class RafKazanci {
  const RafKazanci({
    required this.ad,
    required this.br,
    required this.toplamsalGuc,
    required this.novaBedeli,
  });

  final String ad;

  /// Savaş puanı — 09'un ölçüsü, kapıların okuduğu sayı.
  final double br;

  /// Aynı iki kanal, geometrik ortalama yerine TOPLAMLA. Ölçüm aracı, ikinci
  /// bir güç tanımı değil (aşağıdaki gerekçeye bakın).
  final double toplamsalGuc;

  /// Alımın kaç NOVA ettiği — raf fiyatı × doldurulan yuva sayısı.
  final int novaBedeli;
}

/// Bir bandın 2×2 çarpanlı deneyi artı lazer karşılaştırması.
class ElitDroidBandi {
  const ElitDroidBandi({
    required this.kademe,
    required this.rank,
    required this.rafRanki,
    required this.novaRanki,
    required this.krediDroidYuvasi,
    required this.elitDroidYuvasi,
    required this.taban,
    required this.yalnizYuva,
    required this.yalnizRank,
    required this.elit,
    required this.elitKalkanli,
    required this.ikinciYuvaSecimi,
    required this.ikinciYuvaSecimiKredi,
    required this.novaLazer,
  });

  /// Gövde kademesi (0..7) — bant.
  final int kademe;

  /// Bandın referans rankı.
  final int rank;

  /// Kredi rafının o banttaki rankı (`bant − 1`, 15.2).
  final int rafRanki;

  /// NOVA rafının rankı — SABİT, B-I (15.7).
  final int novaRanki;

  /// O bandın KREDİ droidinin ekipman yuvası (05.4 s5).
  ///
  /// Elitle arasındaki fark her bantta bir DEĞİL: yalnız ilk bantta, çünkü
  /// merdivenden türetilen droidler şablonu elit droidden alıyor ve
  /// `currency`'yi de onunla birlikte devralıyor ([Catalogue.droidYuvaSayisi]
  /// para birimine bakıyor). Ölçüm bunu gizlemiyor, ilan ediyor.
  final int krediDroidYuvasi;

  /// NOVA droidinin ekipman yuvası — `elitDroidYuvasi = 2`.
  final int elitDroidYuvasi;

  /// A · kredi droidi, taşıdığı kadar donanım.
  final RafKazanci taban;

  /// B · kredi droidi, ELİT kadar donanım — yalnız TAŞIMA farkı.
  final RafKazanci yalnizYuva;

  /// C · NOVA droidi, kredi droidi kadar donanım — yalnız RANK farkı.
  final RafKazanci yalnizRank;

  /// D · NOVA droidi, elit kadar donanım — rafın gerçek alımı, EN İYİ okuma.
  final RafKazanci elit;

  /// D′ · aynı droid ama ikinci yuvada jeneratör — 05.4 s5'in "hem vurur hem
  /// dayanır" cümlesinin birebir hâli.
  ///
  /// Ayrıca ilan ediliyor çünkü aradaki fark küçük değil ve hangisinin
  /// ölçüleceği bir KARAR: kural ikinci yuvaya tip şartı koymuyor, yani
  /// bugün iki lazer yasal. Şart konursa ölçüm bu satıra düşer.
  final RafKazanci elitKalkanli;

  /// Elit droidin ikinci yuvasında BR'yi büyüten kalem.
  final SlotType ikinciYuvaSecimi;

  /// Aynı seçim kredi droidi için — iki yuvalı olduğu bantlarda anlamlı.
  final SlotType ikinciYuvaSecimiKredi;

  /// Aynı bantta NOVA LAZERİ alan oyuncu — karşılaştırma noktası.
  final RafKazanci novaLazer;

  double _oran(RafKazanci k) => k.br / taban.br - 1;
  double _oranG(RafKazanci k) => k.toplamsalGuc / taban.toplamsalGuc - 1;

  /// Yalnız taşıma farkının BR kazancı (B − A).
  double get yuvaKazanci => _oran(yalnizYuva);

  /// Yalnız rank farkının BR kazancı (C − A).
  double get rankKazanci => _oran(yalnizRank);

  /// NOVA droidinin toplam BR kazancı (D − A).
  double get droidKazanci => _oran(elit);

  /// NOVA lazerinin BR kazancı.
  double get lazerKazanci => _oran(novaLazer);

  /// D′ okumasının kazancı — ikinci yuvaya jeneratör konursa.
  double get droidKazanciKalkanli => _oran(elitKalkanli);

  /// Çarpanların ETKİLEŞİMİ: toplam eksi iki tekil etki.
  ///
  /// Sıfırdan farklı olması beklenir ve okunmalı: rank droidin kendi
  /// statlarını, yuva taşınan eşyayı büyütüyor ve ikisi aynı zincirde
  /// çarpılıyor. Toplamsal bir okuma iki etkiyi olduğundan büyük gösterirdi.
  double get etkilesim => droidKazanci - yuvaKazanci - rankKazanci;

  /// Aynı sorunun toplamsal güçteki cevabı — BR'nin geometrik ortalaması
  /// tek kanala yazan bir kalemi bastırıyor mu diye.
  double get droidKazanciToplamsal => _oranG(elit);
  double get lazerKazanciToplamsal => _oranG(novaLazer);

  /// **BORCUN SORUSU:** droid alımının kazancı, lazer alımınınkinin kaç katı.
  ///
  /// Payda sıfıra yakınsa (lazer alımı bir şey kazandırmıyorsa) oran
  /// anlamsız; o yüzden mutlak farklar da ilan ediliyor.
  double get droidLazerOrani =>
      lazerKazanci == 0 ? double.nan : droidKazanci / lazerKazanci;

  /// Ödenen NOVA başına BR kazancı — droid alımı lazerinkinin İKİ KATI
  /// pahalı (on yuva, beş yuva), yani "büyük mü" sorusunun ikinci hâli.
  double get droidVerimi => droidKazanci / elit.novaBedeli * 1000;
  double get lazerVerimi => lazerKazanci / novaLazer.novaBedeli * 1000;

  /// Bir BR kazancının kaç RANK ADIMI ettiği.
  ///
  /// 09'un ilan ettiği bir "savaş puanı bandı" yok (belgenin sınır satırı
  /// eşikleri 10'a ve 11'e bırakıyor), o yüzden B25'in "bandın içinde mi"
  /// sorusu merdivenin kendi birimine çevriliyor: bütün build bir rank
  /// yukarı çıktığında BR tam `rankArtisi` katına çıkar
  /// ([CombatGlossary.referansBrFor] rank çarpanının doğrusalı), yani bir
  /// kazancın rank adımı cinsinden karşılığı `ln(1+g) ÷ ln(rankArtisi)`.
  /// 15.4 zaten aynı iki cetveli kullanıyor: bir rank atlaması ve bir artı
  /// seviyesi.
  static double rankAdimiCinsinden(double kazanc) =>
      math.log(1 + kazanc) / math.log(TasarimGirdileri.rankArtisi);

  double get droidRankAdimi => rankAdimiCinsinden(droidKazanci);
  double get lazerRankAdimi => rankAdimiCinsinden(lazerKazanci);
}

/// ELİT DROİDİN ÖLÇÜMÜ — borç defteri B25'in ölçülmemiş yarısı.
///
/// **Soru bu ölçümün konusu değil; sayı öyle.** B25 bir tasarım sorusu soruyor
/// ("para güç mü satıyor") ve kararı sahibinin. Burada ölçülen tek şey, borcun
/// "ikincisi ölçülmedi" dediği okuma: *droid FİLO demek ve filo on yuva; bir
/// kademe fark on yuvada toplanınca lazerdeki bir kademeden büyük çıkabilir.*
///
/// ## Neyin sabit tutulduğu
///
/// Karşılaştırma ancak tek bir şey değişirse adil. Sabitler:
/// * **Bant** — her ölçüm noktası bir gövde kademesi; rank o bandın referans
///   rankı ([ReferansBuild.rankiFor]), gövde o bandın gövdesi.
/// * **Artı seviyesi** — her eşyada [ReferansBuild.arti]; ödeyen oyuncunun
///   eşyası daha yükseltilmiş DEĞİL, 15.1 artıyı satmıyor.
/// * **Alt stat** — hiçbir eşyada yok. İki raf da TABAN eşya satıyor (15.2,
///   15.7), yani derinlik farkı zaten sıfır ve roll gürültüsü ölçüme girmiyor.
/// * **Filo doluluğu** — hep TAM filo ([TasarimGirdileri.droidFiloTavani]).
///   Borcun iddiası "on yuvada toplanınca" olduğu için yarım filo ölçmek
///   soruyu değiştirmek olurdu.
/// * **Droidin TAŞIDIĞI eşya** — her varyantta kredi rafından. Değişen şey
///   droidin kendisi; taşınan kanal sabit tutulmasaydı ölçülen fark droidin
///   değil içindekinin farkı olurdu.
/// * **Öteki yuvalar** — lazer karşılaştırması dışında bütün gemi yuvaları
///   kredi rafından, 04.5'in reçetesiyle (jeneratörler yarı yarıya kalkan ve
///   hız, CPU'lar tamir ve nişan).
///
/// ## Neden BR birincil ölçüt
///
/// Çünkü oyunun kendi cevabı o. "Hangisi daha iyi" sorusunun tek yetkilisi
/// savaş puanı ([LoadoutResolver.yukseltmeMi] aynı gerekçeyle onu okuyor),
/// harita kapıları da (11.3) onu okuyor — B25'in "bu fark 09'un savaş puanı
/// bandının içinde mi" sorusu doğrudan bu birimde soruluyor. Ham DPS tek
/// kanal ölçer ve droidin havuz katkısını görmez; eşya bütçesi ise ilan
/// edilen payı ölçer, GERÇEKLEŞENİ değil.
///
/// BR'nin bir zayıflığı var ve ikinci ölçüt tam onun için: geometrik ortalama
/// tek kanala yazan bir kalemi bastırıyor. NOVA lazeri saf saldırı, NOVA
/// droidi iki kanala birden yazıyor (09.6) — yani BR ikisini FARKLI ölçüyor
/// ve bu fark gerçek, ama tek başına okunursa "droid neden öne geçti"
/// sorusunun cevabı formülün biçiminde saklı kalır. [RafKazanci.toplamsalGuc]
/// aynı iki kanalı toplamla okuyor (08.3'ün Shapley ölçümündeki birim:
/// A + D ÷ T, kur cinsinden). İkinci bir güç TANIMI değil — oyunun hiçbir
/// yeri onu okumuyor — yalnız birincinin gölgesine tutulan bir fener.
///
/// ## Neden 2×2
///
/// Elit droidin farkı tek değil İKİ (05.4 s5): rankı bir kademe üstte (B-I)
/// ve **iki** ekipman yuvası taşıyor, standart droid bir. B25 yazıldığında
/// yalnız birincisi görülüyordu. İkisini bir arada ölçmek "hangisi ne kadar"
/// sorusunu cevapsız bırakırdı, o yüzden dört köşe ölçülüyor ve etkileşim
/// ayrıca ilan ediliyor.
/// KARAR 15.7 s1 · KARAR 05.4 s5 · KARAR 15.2 s1
abstract final class ElitDroidOlcumu {
  /// NOVA rafının droidi ve lazeri — ölçümün konusu.
  static ItemSpec get novaDroid =>
      Catalogue.novaRafi.singleWhere((s) => s.slot == SlotType.droid);
  static ItemSpec get novaLazer =>
      Catalogue.novaRafi.singleWhere((s) => s.slot == SlotType.laser);

  /// [kademe] bandının kredi rafı — 15.2'nin "bir alt rank" rafı.
  static List<ItemSpec> rafFor(int kademe) =>
      Catalogue.rafFor(ReferansBuild.rankiFor(kademe));

  /// Raftan [tip] tasarımı; [anaStat] verilirse o ana stata sahip olanı.
  ///
  /// Merdivenin üstünde her (yuva, rank) çiftinde TEK tasarım var (türetme
  /// şablondan tek eşya üretiyor), yani hız jeneratörü yalnız ilk iki bantta
  /// bulunuyor. Bulunamazsa ilk tasarıma düşülüyor: reçeteyi bozmak yerine
  /// bandın gerçekten sattığı şeyle ölçmek doğru olan.
  static ItemSpec _rafTan(List<ItemSpec> raf, SlotType tip, {String? anaStat}) {
    final adaylar = raf.where((s) => s.slot == tip).toList();
    if (anaStat != null) {
      for (final s in adaylar) {
        if (s.mainStat == anaStat) return s;
      }
    }
    return adaylar.first;
  }

  /// Bir varyantın statları.
  ///
  /// [droid] filodaki on droidin tasarımı, [droidDonanimYuvasi] her droidin
  /// kaç şey taşıdığı — 2×2'nin iki ekseni. [lazerYerine] verilirse GEMİNİN
  /// bütün lazer yuvaları onunla doluyor (droidin taşıdığı lazer değişmiyor).
  static ShipStats statlariFor(
    int kademe, {
    required ItemSpec droid,
    required int droidDonanimYuvasi,
    SlotType ikinciKalem = SlotType.laser,
    ItemSpec? lazerYerine,
    int? arti,
  }) {
    final govde = ReferansBuild.govdeFor(kademe);
    final raf = rafFor(kademe);
    // Artı seviyesi HER eşyada aynı; hangi seviye olduğu sonucu değiştirmemeli
    // (15.1 artı satmıyor, iki taraf da aynı merdivenden çıkıyor). Varsayılan
    // referansın seviyesi; [arti] yalnız o bağımsızlığı SINAMAK için var.
    final seviye = arti ?? ReferansBuild.arti;
    final rafLazer = _rafTan(raf, SlotType.laser);
    final kalkanJen = _rafTan(raf, SlotType.generator, anaStat: Stats.maxShield.id);
    final hizJen = _rafTan(raf, SlotType.generator, anaStat: Stats.speed.id);

    final envanter = <String, ItemInstance>{};
    final loadout = Loadout(hullId: govde.id);

    void koy(String id, ItemSpec spec) {
      // TABAN eşya: iki raf da alt statsız satıyor (15.2, 15.7). Roll'ü
      // dışarıda bırakmak ölçümü belirlenimci yapıyor — ve zaten adil,
      // çünkü fark ölçülen iki kalem de alt stat taşımıyor.
      envanter[id] = ItemInstance(
        instanceId: id,
        specId: spec.id,
        level: seviye,
        taban: true,
      );
    }

    for (final tip in SlotType.values) {
      for (var i = 0; i < govde.slotCount(tip); i++) {
        final spec = switch (tip) {
          SlotType.laser => lazerYerine ?? rafLazer,
          // 04.5'in reçetesi: jeneratörler yarı yarıya kalkan ve hız.
          SlotType.generator => i.isEven ? kalkanJen : hizJen,
          _ => _rafTan(raf, tip),
        };
        final id = 'gemi-${tip.name}-$i';
        koy(id, spec);
        loadout.equip(SlotRef(tip, i), id);
      }
    }

    final filo = <String>[];
    final donanim = <String, List<String>>{};
    for (var i = 0; i < TasarimGirdileri.droidFiloTavani; i++) {
      final id = 'filo-$i';
      koy(id, droid);
      filo.add(id);
      final tasidiklari = <String>[];
      for (var j = 0; j < droidDonanimYuvasi; j++) {
        // İLK yuva hep lazer ve bu bir seçim değil: tek yuvalı droid 05.4
        // s5'in dediği seçimi yapmak zorunda, ve jeneratörü seçen droid hiç
        // vurmaz (boş droid vurmuyor) — o zaman ölçülen şey taşıma farkı
        // değil bir build hatası olurdu.
        //
        // İKİNCİ yuva ölçümün açık ucu, çünkü kural onu bağlamıyor: droid
        // donanımı lazer ya da jeneratör ([Saglayici.droidDonanimTipleri]) ve
        // hiçbir yer "her tipten bir tane" demiyor. 05.4 s5 eliti "hem vurur
        // hem dayanır" diye anlatıyor, ama İKİ LAZER de yasal ve ölçüldüğünde
        // çok daha güçlü. Ölçüm ikisini de koşup BR'yi büyüteni alıyor
        // ([ElitDroidOlcumu.olc]): "para ne kadar güç satabiliyor" sorusunun
        // cevabı, ödeyen oyuncunun yapabileceğinin EN İYİSİ olmalı; en zayıf
        // okumayı ilan etmek soruyu kendi lehine çözmek olurdu.
        final spec = j == 0
            ? rafLazer
            : (ikinciKalem == SlotType.generator ? kalkanJen : rafLazer);
        final did = 'filo-$i-tasima-$j';
        koy(did, spec);
        tasidiklari.add(did);
      }
      donanim[id] = tasidiklari;
    }

    // VARSAYIMSAL KAPASİTE YEREL KATALOGDA KURULUYOR.
    //
    // Ölçüm 2×2: elit droidin rank farkı ile yuva farkını ayırmak için
    // "kredi droidi İKİ yuvalı olsaydı" köşesi gerekiyor. Çözüm kapasiteyi
    // artık kendisi uyguluyor ([Saglayici.droidYuvaSayisi]) — ki doğrusu o,
    // yoksa diskteki fazla eşya sessizce güç vermeye devam ederdi — bu
    // yüzden köşe listeye fazladan eşya koyarak KURULAMAZ; çözüm onu keser.
    //
    // Bunun yerine köşe, o rankın droidinin iki yuvalı bir KOPYASIYLA
    // kuruluyor: aynı kimlik, aynı rank, aynı statlar, yalnız çeşidi elit.
    // Kopya yerel haritada duruyor, gerçek katalog değişmiyor.
    final istenen = droidDonanimYuvasi;
    final dogal = Saglayici.droidYuvaSayisi(droid);
    final katalog = istenen == dogal
        ? Catalogue.byId
        : {
            ...Catalogue.byId,
            droid.id: ItemSpec(
              id: droid.id,
              name: droid.name,
              slot: droid.slot,
              tier: droid.tier,
              mainStat: droid.mainStat,
              subStatPool: droid.subStatPool,
              variant: droid.variant,
              currency: istenen > dogal
                  ? Currency.premium
                  : Currency.credit,
            ),
          };
    return LoadoutResolver.resolve(
      loadout,
      envanter,
      katalog,
      filo: filo,
      droidDonanimi: donanim,
    );
  }

  /// Toplamsal güç — BR'nin İKİ KANALI, geometrik ortalama yerine toplamla.
  ///
  /// 08.3'ün Shapley ölçümüyle aynı birim (kur: 1 DPS ≡ T EHP, 09.2) ve aynı
  /// sebeple: pay muhasebesinde geometrik ortalama bir kanalı veto oyuncusu
  /// yapar. Sistem çarpanı burada da uygulanıyor, çünkü BR'de de çarpan.
  static double toplamsalGuc(ShipStats stats) {
    final saldiri =
        CombatGlossary.saldiriDps(stats) + CombatGlossary.droidDps(stats);
    final dayaniklilik =
        (CombatGlossary.ehp(stats) +
            TasarimGirdileri.droidDayaniklilikKatsayisi *
                CombatGlossary.droidEhp(stats)) /
        TasarimGirdileri.referansTTK;
    return (saldiri + dayaniklilik) *
        CombatGlossary.sistemCarpani(CombatGlossary.sistemPuaniOf(stats));
  }

  static RafKazanci _kazanc(
    String ad,
    ShipStats stats, {
    required int novaBedeli,
  }) => RafKazanci(
    ad: ad,
    br: CombatGlossary.battleRating(stats),
    toplamsalGuc: toplamsalGuc(stats),
    novaBedeli: novaBedeli,
  );

  /// Bir droid tasarımının kaç ekipman yuvası taşıdığı (05.4 s5).
  static int yuvaSayisi(ItemSpec droid) => Catalogue.droidYuvaSayisi(droid);

  /// [kademe] bandının bütün ölçümü. [arti] yalnız bağımsızlık sınaması için.
  static ElitDroidBandi olc(int kademe, {int? arti}) {
    final raf = rafFor(kademe);
    final krediDroid = _rafTan(raf, SlotType.droid);
    final elitYuva = yuvaSayisi(novaDroid);
    final krediYuva = yuvaSayisi(krediDroid);
    final govde = ReferansBuild.govdeFor(kademe);
    final droidBedeli =
        Catalogue.priceOf(novaDroid).amount * TasarimGirdileri.droidFiloTavani;
    final lazerBedeli =
        Catalogue.priceOf(novaLazer).amount * govde.slotCount(SlotType.laser);

    // İkinci yuvanın iki okumasından BR'yi büyüteni. Tek yuvalı droidde
    // `ikinciKalem` hiç okunmuyor, yani seçim yalnız iki yuvalıda anlamlı.
    (RafKazanci, SlotType) enIyisi(String ad, ItemSpec droid, int yuva) {
      var secim = SlotType.laser;
      var iyi = _kazanc(
        ad,
        statlariFor(
          kademe,
          droid: droid,
          droidDonanimYuvasi: yuva,
          arti: arti,
        ),
        novaBedeli: 0,
      );
      if (yuva > 1) {
        final kalkanli = _kazanc(
          ad,
          statlariFor(
            kademe,
            droid: droid,
            droidDonanimYuvasi: yuva,
            ikinciKalem: SlotType.generator,
            arti: arti,
          ),
          novaBedeli: 0,
        );
        if (kalkanli.br > iyi.br) {
          iyi = kalkanli;
          secim = SlotType.generator;
        }
      }
      return (iyi, secim);
    }

    final (bYalnizYuva, bSecim) = enIyisi(
      'B · kredi droidi ×$elitYuva',
      krediDroid,
      elitYuva,
    );
    final (dElit, dSecim) = enIyisi(
      'D · NOVA droidi ×$elitYuva',
      novaDroid,
      elitYuva,
    );

    return ElitDroidBandi(
      kademe: kademe,
      rank: ReferansBuild.rankiFor(kademe),
      rafRanki: krediDroid.tier.index,
      novaRanki: novaDroid.tier.index,
      krediDroidYuvasi: krediYuva,
      elitDroidYuvasi: elitYuva,
      taban: _kazanc(
        'A · kredi droidi ×$krediYuva',
        statlariFor(
          kademe,
          droid: krediDroid,
          droidDonanimYuvasi: krediYuva,
          arti: arti,
        ),
        novaBedeli: 0,
      ),
      yalnizYuva: bYalnizYuva,
      ikinciYuvaSecimi: dSecim,
      ikinciYuvaSecimiKredi: bSecim,
      elitKalkanli: _kazanc(
        'D′ · NOVA droidi, ikinci yuvada jeneratör',
        statlariFor(
          kademe,
          droid: novaDroid,
          droidDonanimYuvasi: elitYuva,
          ikinciKalem: SlotType.generator,
          arti: arti,
        ),
        novaBedeli: droidBedeli,
      ),
      yalnizRank: _kazanc(
        'C · NOVA droidi ×$krediYuva',
        statlariFor(
          kademe,
          droid: novaDroid,
          droidDonanimYuvasi: krediYuva,
          arti: arti,
        ),
        novaBedeli: droidBedeli,
      ),
      elit: RafKazanci(
        ad: dElit.ad,
        br: dElit.br,
        toplamsalGuc: dElit.toplamsalGuc,
        novaBedeli: droidBedeli,
      ),
      novaLazer: _kazanc(
        'NOVA lazeri',
        statlariFor(
          kademe,
          droid: krediDroid,
          droidDonanimYuvasi: krediYuva,
          lazerYerine: novaLazer,
          arti: arti,
        ),
        novaBedeli: lazerBedeli,
      ),
    );
  }

  /// Bütün bantlar.
  static List<ElitDroidBandi> get hepsi => [
    for (var k = 0; k < TasarimGirdileri.govdeKademeSayisi; k++) olc(k),
  ];
}
