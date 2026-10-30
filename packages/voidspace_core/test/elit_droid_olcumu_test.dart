@Tags(['aralik', 'kapsam'])
library;

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// B25'İN ÖLÇÜLMEMİŞ YARISI — elit droid, NOVA lazerinden büyük mü.
///
/// Borç defteri B25 iki okuma yazdı ve ikincisini ölçmedi: *"droid FİLO demek
/// ve filo on yuva; bir kademe fark on yuvada toplanınca lazerdeki bir
/// kademeden büyük çıkabilir."* Bu dosya o cümleyi bir sayıya çeviriyor.
///
/// **Kararı vermiyor.** "Para güç satıyor mu" bir tasarım sorusu ve sahibinin;
/// buradaki testler yalnız sayının bugün ne olduğunu ve kaydığında haber
/// vermeyi üstleniyor. Bu yüzden eşikler İKİ TARAFLI ve geniş: amaç bir dengeyi
/// dayatmak değil, "sayı yerinden oynadı, gelip bak" demek. Tek yönlü ve dar
/// bir eşik, dengeyi iyileştiren bir değişikliği de hata gibi gösterirdi.
///
/// Kurulum ve gerekçeler [ElitDroidOlcumu]'nun başında. Bugünkü tablo (BR,
/// tam filo, referans artı seviyesi, ikinci droid yuvasında BR'yi büyüten
/// kalem):
///
/// | bant | kredi rafı | yuva (B) | rank (C) | toplam (D) | NOVA lazeri | D ÷ L |
/// |---|---|---|---|---|---|---|
/// | 0 | C-I | %6,98 | %8,96 | %19,89 | %53,88 | 0,37 |
/// | 1 | C-II | %0,00 | %7,16 | %7,16 | %27,49 | 0,26 |
/// | 3 | A-I | %0,00 | −%15,71 | −%15,71 | −%13,49 | — |
/// | 7 | SSS-II | %0,00 | −%79,48 | −%79,48 | −%1,13 | — |
///
/// Cevap: HAYIR, büyük değil. On yuvada toplanan fark, beş lazerdeki farkın
/// ilk bantta 0,37 katı; ödenen NOVA başına 0,19 katı (droid alımı iki kat
/// pahalı). Sebebi 05.4 s5'in kendi kararında: droidin rankı taşıdığı lazerin
/// TABAN hasarını büyütmüyor, yalnız kendi statlarını ve havuzunu — oysa
/// gemideki lazerin rankı doğrudan yaylımın tabanına biniyor.
void main() {
  final bantlar = ElitDroidOlcumu.hepsi;
  final bant0 = bantlar[0];
  final bant1 = bantlar[1];
  final orta = bantlar[3];
  final yuksek = bantlar[7];

  // KARAR 15.7 s1
  test('kurulum ADİL: tek değişen NOVA rafının kalemi', () {
    // Bir karşılaştırma ancak tek şey değişirse ölçüm; bu test onu sınıyor.
    // Kırılırsa aşağıdaki bütün sayılar anlamını kaybeder, çünkü ölçülen fark
    // rafın değil kurulumun farkı olur.
    for (final b in [bant0, bant1, orta, yuksek]) {
      expect(
        b.rank,
        ReferansBuild.rankiFor(b.kademe),
        reason: 'bant kendi referans rankında ölçülmüyor',
      );
      expect(
        b.novaRanki,
        ElitDroidOlcumu.novaDroid.tier.index,
        reason: 'NOVA rafı banda göre kayıyor — raf SABİT (15.7)',
      );
      expect(
        b.rafRanki,
        Kazanc.tabanEsyaRankiFor(b.rank),
        reason: 'kredi rafı 15.2\'nin bir alt rankında değil',
      );
      // İki alım da aynı rafın aynı rankından: fiyat farkı yalnız yuva
      // sayısından geliyor (on droid, beş lazer), kalemin kendisinden değil.
      expect(
        b.elit.novaBedeli,
        b.novaLazer.novaBedeli * 2,
        reason: 'droid alımı lazer alımının tam iki katı olmalıydı',
      );
    }
    // Filo TAM: borcun iddiası "on yuvada toplanınca", yarım filo soruyu
    // değiştirirdi.
    expect(TasarimGirdileri.droidFiloTavani, 10);
    // İki raf da TABAN eşya satıyor, yani derinlik farkı sıfır ve roll
    // gürültüsü ölçüme hiç girmiyor (15.2, 15.7).
    expect(ElitDroidOlcumu.novaDroid.subStatPool, isNotEmpty);
    expect(
      LoadoutResolver.altStatlariFor(
        const ItemInstance(instanceId: 'x', specId: 'dr5', taban: true),
        ElitDroidOlcumu.novaDroid,
        HullClass.bastion,
      ),
      isEmpty,
    );
  });

  // KARAR 15.7 s1
  test('İLK BANT · droid alımı, lazer alımının 0,37 katı — BÜYÜK DEĞİL', () {
    // B25'in sorusunun kendisi. Yön (küçük) taşıyıcı iddia; sayı (0,37) drift
    // alarmı. Oran birin üstüne çıkarsa borcun ikinci okuması doğrulanmış
    // olur ve karar yeniden açılmalı.
    expect(
      bant0.droidLazerOrani,
      lessThan(1),
      reason: 'B25\'in ikinci okuması gerçekleşti: filo lazeri geçti',
    );
    expect(bant0.droidLazerOrani, inInclusiveRange(0.20, 0.60));
    expect(bant0.droidKazanci, inInclusiveRange(0.12, 0.30));
    expect(bant0.lazerKazanci, inInclusiveRange(0.40, 0.70));
    // Ödenen NOVA başına: droid alımı iki kat pahalı olduğu için oran ikiye
    // bölünüyor. Aynı parayla lazer almak beş kat verimli.
    expect(bant0.droidVerimi / bant0.lazerVerimi, lessThan(0.5));
    // İkinci ölçüt aynı yönü söylüyor mu: BR'nin geometrik ortalaması iki
    // kanala birden yazan droidi kayırabilirdi, toplamsal okuma o şüpheyi
    // kaldırıyor — orada fark daha da açık.
    expect(
      bant0.droidKazanciToplamsal / bant0.lazerKazanciToplamsal,
      lessThan(bant0.droidLazerOrani),
      reason: 'toplamsal okuma droidi BR\'den daha güçlü gösterdi',
    );
  });

  // KARAR 05.4 s5
  test('elit droidin İKİ farkı ayrı ayrı: rank %8,96 · yuva %6,98', () {
    // B25 yazıldığında elitin tek farkı rank sanılıyordu. 05.4 s5 ikinciyi
    // getirdi: elit droid İKİ ekipman yuvası taşıyor, standart bir. Ölçüm
    // ikisini bir arada verseydi "hangisi ne kadar" cevapsız kalırdı ve
    // düzeltme yönü de bilinmezdi — bugün rank ve taşıma neredeyse eşit
    // ağırlıkta, yani rafın rankını indirmek sorunun ancak yarısını çözer.
    expect(bant0.rankKazanci, inInclusiveRange(0.05, 0.15));
    expect(bant0.yuvaKazanci, inInclusiveRange(0.04, 0.12));
    // Etkileşim sıfır değil ve olmamalı: rank droidin kendi statlarını, yuva
    // taşınan eşyayı büyütüyor, ikisi aynı zincirde çarpılıyor. Toplamsal
    // okumak iki etkiyi olduğundan büyük gösterirdi.
    expect(bant0.etkilesim, greaterThan(0));
    expect(bant0.etkilesim, lessThan(0.10));
    expect(
      bant0.rankKazanci + bant0.yuvaKazanci + bant0.etkilesim,
      closeTo(bant0.droidKazanci, 1e-9),
      reason: '2×2 kapanmıyor: bir dördüncü etki var',
    );
    // İkinci yuvanın içeriği bir KARAR ve bugün bağlı değil: kural yalnız
    // "lazer ya da jeneratör" diyor (05.4 s5), "her tipten bir tane" demiyor.
    // Ölçüm en iyisini alıyor ve en iyi İKİ LAZER; 05.4'ün kendi cümlesinin
    // ("hem vurur hem dayanır") birebir hâli belirgin biçimde zayıf.
    expect(bant0.ikinciYuvaSecimi, SlotType.laser);
    expect(bant0.droidKazanciKalkanli, lessThan(bant0.droidKazanci));
    expect(bant0.droidKazanciKalkanli, inInclusiveRange(0.05, 0.16));
  });

  // KARAR 05.4 s5
  test('YUVA farkı HER bantta var: merdiven droidi kredi çeşidi', () {
    // Bu sınama bir zamanlar TERSİNİ kilitliyordu ve kilitlediği şey bir
    // kusurdu: `_turet` şablonun `currency` alanını kopyaladığı ve droid
    // şablonu NOVA rafındaki Hilal olduğu için merdivenin bütün droidleri
    // elit sayılıyor, katalogdaki yirmi droidin on dokuzu iki yuva
    // taşıyordu. "Elit olmanın tek anlamı" ilk banttan sonra buharlaşıyordu.
    //
    // Merdiven droidi ganimetten düşüyor, NOVA ile alınmıyor — elit değil.
    // Artık TEK elit droid Hilal ve yuva farkı her bantta duruyor.
    final elitler = [
      for (final s in Catalogue.items)
        if (s.slot == SlotType.droid &&
            Catalogue.droidYuvaSayisi(s) == TasarimGirdileri.elitDroidYuvasi)
          s.id,
    ];
    expect(
      elitler,
      ['dr5'],
      reason: 'elit droid sayısı değişti — yuva avantajının kapsamı kaydı',
    );
    for (final b in bantlar) {
      expect(
        b.krediDroidYuvasi,
        TasarimGirdileri.droidYuvasi,
        reason: 'kademe ${b.kademe}: kredi droidi elit sayılmış',
      );
      expect(
        b.yuvaKazanci,
        greaterThan(0),
        reason: 'kademe ${b.kademe}: yuva farkı kayboldu',
      );
    }
  });

  // KARAR 15.7 s1
  test('avantaj bantla ERİYOR; işaret rafın rankından türüyor', () {
    // "İlk bantlarda bir adım önde" cümlesinin ölçülmüş hâli. NOVA rafı SABİT
    // (B-I), kredi rafı bandı izliyor; ikisi kesiştikten sonra NOVA droidi
    // almak DÜŞÜŞ. Bunu bir bant numarasına çivilemek yerine türetilen
    // ilişkiye bağlamak doğrusu: merdiven ya da bant bölmesi oynarsa test
    // kendiliğinden doğru yerde kalır.
    // İŞARET ARTIK RANK TEK BAŞINA BELİRLEMİYOR — yuva onu ÖTELİYOR.
    //
    // Eskiden sınanan ilişki `droidKazanci < 0 ⟺ rafRanki > novaRanki` idi ve
    // o gün doğruydu: merdiven droidi de iki yuvalı sayıldığı için (bir
    // kusurdu, düzeltildi) NOVA'nın elinde yalnız rank farkı kalıyordu.
    // Artık NOVA droidinin İKİ farkı var (05.4 s5) ve ikincisi rank
    // kesişiminden sonra da yaşıyor: raf B-II'ye çıkıp Hilal'in B-I'ini
    // geçtiği bantta bile ikinci yuva öndeliği sürdürüyor.
    //
    // Kalan yön kuralı tek taraflı: rank henüz geride değilse avantaj
    // KESİNLİKLE artıda. Öteki yön artık bir eşitlik değil bir gecikme.
    for (final b in bantlar) {
      if (b.rafRanki <= b.novaRanki) {
        expect(
          b.droidKazanci,
          greaterThan(0),
          reason: 'kademe ${b.kademe}: rank önde ama avantaj yok',
        );
      }
    }
    // Kesişim rank kesişiminden SONRA geliyor; öteleme yuvanın işi.
    final ilkEksi = bantlar.indexWhere((b) => b.droidKazanci <= 0);
    final rankKesisimi = bantlar.indexWhere((b) => b.rafRanki > b.novaRanki);
    expect(
      ilkEksi,
      greaterThan(rankKesisimi),
      reason: 'yuva avantajı kesişimi ötelemiyor',
    );
    // Taşıyıcı iddia "ödeyenin önde olduğu bant sayısı azdır"; sayı drift
    // alarmı. Ölçülen: kademe 0·1·2'de artıda (%20 · %15 · %7), 3'te dönüyor.
    expect(
      ilkEksi,
      inInclusiveRange(2, 4),
      reason: 'ödeyen oyuncunun önde olduğu bant sayısı kaydı',
    );
    expect(bant1.droidLazerOrani, lessThan(1));
    // Üst bantlarda oran birin ÜSTÜNE çıkıyor ama bu bir avantaj değil: orada
    // iki sayı da eksi, yani ölçülen şey "hangi düşüş daha derin". Oranı
    // avantaj gibi okumamak için işaret ayrıca sınanıyor.
    expect(orta.droidKazanci, lessThan(0));
    expect(yuksek.droidKazanci, lessThan(0));
    expect(yuksek.droidKazanci, lessThan(yuksek.lazerKazanci));
  });

  // KARAR 15.4 s1
  test('kazanç merdivenin kendi birimine çevrildiğinde yarım rank adımı', () {
    // B25 "09'un savaş puanı bandının içinde mi" diye soruyor ama 09 bir BR
    // bandı ilan etmiyor — eşikleri 10'a ve 11'e bırakıyor. En yakın cetvel
    // 15.4'ün kendi kullandığı ikili: bir rank atlaması (%44,2) ve bir artı
    // seviyesi (%8–12). Kazançlar o birime çevriliyor.
    expect(Kazanc.rankAdimi, closeTo(TasarimGirdileri.rankArtisi - 1, 1e-9));
    // Droid alımı: yarım rank adımından az, ama bir artı seviyesinden fazla.
    expect(bant0.droidRankAdimi, lessThan(1));
    expect(bant0.droidRankAdimi, inInclusiveRange(0.30, 0.70));
    expect(bant0.droidKazanci, greaterThan(Kazanc.artiAdimAraligi.$2));
    // Ölçümün İKİNCİ bulgusu ve borcun beklemediği yön: aynı bantta NOVA
    // lazeri bir tam rank adımından fazlasını satıyor. B25 droidi sorguluyor,
    // ama bugünkü sayılarla rafın en büyük kalemi lazer. Eşik iki taraflı:
    // bu sayı düşerse de yükselirse de haber gelmeli.
    expect(bant0.lazerRankAdimi, inInclusiveRange(0.70, 1.60));
    expect(bant0.lazerRankAdimi, greaterThan(bant0.droidRankAdimi));
  });

  // KARAR 15.7 s1
  test('sonuç ARTI seviyesinden bağımsız: oran her seviyede birin altında', () {
    // Artı satılmıyor (15.1), yani iki taraf hep aynı seviyede. Yine de sonuç
    // seviyeye bir miktar duyarlı ve sebebi yapısal: droidin havuzu kendi
    // çarpanıyla büyüyor, gövdeninki sabit — artı yükseldikçe droid kanalı
    // ağırlaşıyor. Duyarlılık ölçülüyor ki "bu sayı hangi seviyede okundu"
    // sorusu açık kalmasın; sonucun YÖNÜ hiçbir seviyede değişmiyor.
    for (final seviye in [0, ItemLevels.max]) {
      final b = ElitDroidOlcumu.olc(0, arti: seviye);
      expect(
        b.droidLazerOrani,
        lessThan(1),
        reason: '+$seviye seviyesinde droid alımı lazeri geçti',
      );
      expect(b.droidLazerOrani, inInclusiveRange(0.15, 0.60));
    }
  });
}
