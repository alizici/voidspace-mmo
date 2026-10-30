import '../combat/combat_glossary.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilen_tablolar.dart';
import '../design/turetilenler.dart';
import '../domain/world.dart';

/// Bir bölgedeki üç haritadan biri — alan 11.
///
/// Üçü oyunun üç tehdit biçimi: saldırı yalnız yaratıklardan gelir · yaratık
/// ve oyuncu birlikte · zamanlı tek hedef. Dördüncüsü yeni bir tehdit biçimi
/// icat etmeden eklenemez, bu yüzden [TasarimGirdileri.bolgeBasinaHarita]
/// ayarlanabilir bir kadran değil kategorik bir sayı.
/// KARAR 11.1 s1
enum HaritaTipi {
  /// Ana farm alanı. Saldırı yalnız yaratıklardan gelir.
  pve('PvE'),

  /// Aynı yaratıklar, daha yüksek ödül, ve başka oyuncular. Girmek bir karar.
  pvp('PvP'),

  /// Zamanlı doğan tek hedef. Grup gerektirir, ganimeti bölgenin tavanı.
  boss('Boss');

  const HaritaTipi(this.ad);

  final String ad;
}

/// BÖLGE — dünyanın bir parçası, bir gövde kademesine karşılık gelir.
///
/// Harita bir **zorluk kabı değil, bir eşleştirme aracı**. Görevi tek:
/// oyuncuyu, gücüne denk hedeflerin ve gücüne denk rakiplerin olduğu yere
/// koymak.
///
/// **Bölge sayısı burada bir girdi değil.** Alan 04 dünyayı zaten gövde
/// kademelerine bölmüştü ve bir kademe tam olarak "aynı ligde oynayan
/// oyuncular" demek — [Turetilenler.bolgeSayisi] o bölünmeyi ikinci kez
/// kullanıyor. Kademe eklenirse bölge de eklenir.
///
/// **Bir bölge birden çok rank taşıyor** ve o rankların gelirleri farklı olmak
/// zorunda, yoksa alan 10'un α eğrisi kırılır. Çözüm haritayı bölmek:
/// merkeze doğru gidildikçe bant değişiyor, yaratıklar sertleşiyor, ödül
/// yükseliyor. Yan etkisi bölge sınırının yumuşaması — yeni bölgeye geçmeden
/// önce eskinin en derin bandında oynuyorsun, yani geçiş bir uçurum değil bir
/// eğim.
/// KARAR 11.1 s1
class Bolge {
  const Bolge._(this.kademe, this.ad);

  /// Gövde kademesi ile birebir — 0 tabanlı.
  final int kademe;

  final String ad;

  /// Sekiz bölgenin adı.
  ///
  /// Liste [Turetilenler.bolgeSayisi]'ndan UZUN olabilir ve bugün öyle: gövde
  /// merdiveni beş kademede duruyor, adlar sekiz. Fazlası bekliyor — gövde
  /// çizimleri gibi, sayı yükseldiğinde adı hazır.
  static const adlar = [
    'Sığlık',
    'Kırık Halka',
    'Solgun Geçit',
    'Kor Sahanlığı',
    'Yas Boşluğu',
    'Devrik Kule',
    'Sessiz Fener',
    'Son Eşik',
  ];

  /// Bugün var olan bölgeler.
  ///
  /// Alan, getter DEĞİL: statik `final` Dart'ta zaten tembel kuruluyor, ama
  /// getter olsaydı her erişimde listeyi yeniden inşa ederdi — ve bu liste hem
  /// sunucu döngüsünden hem arayüzden okunuyor.
  static final List<Bolge> hepsi = [
    for (var k = 0; k < Turetilenler.bolgeSayisi; k++) Bolge._(k, adlar[k]),
  ];

  static Bolge get ilk => hepsi.first;

  static Bolge? byKademe(int kademe) =>
      kademe >= 0 && kademe < hepsi.length ? hepsi[kademe] : null;

  /// Bir oyuncunun savaş puanıyla girebileceği EN DERİN bölge.
  ///
  /// `null` değil ilk bölge dönüyor: kimse dünyasız kalmıyor, en zayıf oyuncu
  /// bile [ilk]'e girer.
  /// KARAR 11.3 s1
  static Bolge girilebilen(double br, {int? seviye}) {
    var sonuc = ilk;
    for (final b in hepsi) {
      if (b.kabulEder(br, seviye: seviye)) sonuc = b;
    }
    return sonuc;
  }

  // ══ Derinlik ═══════════════════════════════════════════════════════

  /// Bölgenin taşıdığı rank aralığı — `[başlangıç, bitiş)`.
  /// KARAR 11.2 s1
  (int, int) get rankAraligi => TuretilenTablolar.rankAraligiFor(
    kademe,
    rankSayisi: Turetilenler.rankSayisi,
    kademeSayisi: Turetilenler.bolgeSayisi,
  );

  /// Dış bandın rankı.
  int get ilkRank => rankAraligi.$1;

  /// İç bandın rankı.
  int get sonRank => rankAraligi.$2 - 1;

  /// Kaç derinlik bandı — taşıdığı rank sayısı kadar.
  int get bantSayisi => rankAraligi.$2 - rankAraligi.$1;

  /// [bant] numaralı bandın KÜRESEL rankı. 0 dış bant.
  int rankOf(int bant) {
    if (bant < 0 || bant >= bantSayisi) {
      throw ArgumentError.value(bant, 'bant', 'bu bölgede yok');
    }
    return ilkRank + bant;
  }

  // ══ Kapı ═══════════════════════════════════════════════════════════

  /// Girmek için gereken savaş puanı — dış bandın referans BR'sinin
  /// [TasarimGirdileri.girisPayi] kadarı.
  ///
  /// Kapı BR ile ölçülüyor, seviye ile değil: seviye zamanla artıyor, BR
  /// güçle. Bir harita zamanı değil GÜCÜ ölçmek zorunda — yoksa iki yıl
  /// oynamış ama hiç güçlenmemiş bir oyuncu, taşıyamayacağı bir bölgeye girer
  /// ve orada hiçbir şey yapamaz.
  /// İLK bölgenin kapısı YOK ve olamaz.
  ///
  /// Bulundu, tasarlanmadı. Formül ilk bölgeye **2.700** diyor: referans
  /// build'in savaş puanının (3.600) dörtte üçü. Ama yeni hesap referans
  /// build değil — başlangıç lazeriyle savaş puanı **1.050**. Yani oyuncu
  /// **içinde doğduğu bölgeye giremiyordu.**
  ///
  /// Kapı bir referansa göre ölçülüyor ve oyuncu oraya ancak oynayarak
  /// varıyor; ilk bölge tam da o oynamanın geçtiği yer. Kendi başlangıcını
  /// kapıyla korumak, merdivenin ilk basamağını havada bırakmak olurdu.
  ///
  /// Görünmesi zordu çünkü tek yönlü: dünyaya giriş kapıdan geçmiyor, oyuncu
  /// doğrudan oraya konuyor. Kapı ancak GERİ DÖNERKEN sınanıyor ve o yol
  /// (harita kalıcılığı) sonradan geldi.
  /// KARAR 11.3 s1
  double get girisEsigi => kademe == 0
      ? 0
      : CombatGlossary.referansBrFor(ilkRank) * TasarimGirdileri.girisPayi;

  /// İkincil kapı: SEVİYE (11.4). Savaş puanı para ile hızlanır, seviye
  /// hızlanmaz; ikisi birlikte ödeyerek çok öne fırlamayı sınırlıyor. Eşik
  /// bandın ilk rankının bir altı: referans oyuncu için hiç bağlayıcı değil,
  /// yalnız parayla öne geçen için. İlk bölge herkese açık.
  /// KARAR 11.4 s1
  int get seviyeEsigi => kademe == 0 || ilkRank == 0 ? 0 : ilkRank - 1;

  /// [seviye] `null` ise yalnız savaş puanı sınanır — istemcinin henüz
  /// bilmediği durumlar için; sunucu her zaman ikisini birden geçirir.
  bool kabulEder(double br, {int? seviye}) =>
      br >= girisEsigi && (seviye == null || seviye >= seviyeEsigi);

  // ══ Boyut ══════════════════════════════════════════════════════════

  /// Bölgenin haritası — üç harita tipinin üçü de aynı ölçüde.
  ///
  /// Boyut yalnız BANT SAYISINA bağlı, kademeye değil: sekizinci bölge
  /// birincisinden büyük değil, yalnız içindekiler yüzlerce kat güçlü.
  GameWorld get harita {
    final (genislik, yukseklik) = TuretilenTablolar.haritaBoyutuFor(
      bantSayisi,
      bantAlani: Turetilenler.bantAlani,
      enBoy: TasarimGirdileri.dunyaEnBoyOrani,
    );
    return GameWorld(width: genislik, height: yukseklik);
  }

  /// Haritada kaç yaratık — hedef yoğunluğu tutturan sayı.
  int get hedefSayisi => Turetilenler.bantBasinaHedef * bantSayisi;

  // ══ Gelir ══════════════════════════════════════════════════════════

  /// [bant]'ın gelir ÇARPANI — oyunun taban saatlik gelirine göre.
  ///
  /// Mutlak kredi değil çarpan, çünkü tabanın kendisi alan 11'in kararı değil:
  /// "saatte kaç kredi" sorusunu yaratıkların canı ve ödülü belirliyor
  /// (alan 12 ve 13). 11 yalnız kabı tanımlıyor — kabın hangi bandının
  /// ötekinden kaç kat verdiğini.
  ///
  /// Bölgeye değil BANDA bağlı: bir bölgenin içinde de gelir artıyor, yani
  /// yeni gemi almadan da ilerliyorsun — yalnız daha derine giriyorsun. Ve
  /// derine girmek bir yetenek sınavı, yeni bir satın alma değil.
  /// KARAR 11.2 s1
  double gelirCarpaniFor(int bant) => TuretilenTablolar.gelirFor(
    rankOf(bant),
    taban: 1,
    artis: TasarimGirdileri.rankArtisi,
    us: TasarimGirdileri.gelirUssu,
  );

  /// PvP haritasının gelir çarpanı — aynı bant, risk primi eklenmiş.
  double pvpGelirCarpaniFor(int bant) =>
      gelirCarpaniFor(bant) * Turetilenler.pvpBrutPrim;

  /// Bölgede geçirilecek toplam süre, saat.
  ///
  /// Bantların süreleri toplamı. Sekiz bölgenin süreleri toplandığında alan
  /// 10'un [TasarimGirdileri.hedefSure]'si birebir çıkıyor — beklenen bir
  /// sonuç, çünkü aynı nesil sürelerinin yeniden bölünmesinden ibaret; ama
  /// bölünmenin zaman KAYBETMEDİĞİNİ gösteriyor.
  double get sure {
    var toplam = 0.0;
    for (var b = 0; b < bantSayisi; b++) {
      toplam += Turetilenler.bantSuresi(rankOf(b));
    }
    return toplam;
  }

  @override
  String toString() =>
      '$ad (kademe $kademe · $bantSayisi bant · BR ${girisEsigi.round()})';
}
