import '../domain/vec2.dart';
import '../domain/world.dart';
import 'bolge.dart';

/// Bir geçidin durduğu KENAR.
///
/// Pusula, çünkü ağın tamamı tek bir kuraldan çıkıyor: **çıkış, girişin karşı
/// kenarıdır.** Doğu geçidinden giren, hedef haritanın batı geçidinde belirir
/// — ve o geçit zaten geri dönüş kapısıdır. İki yönü ayrı ayrı yerleştirmek
/// gerekmiyor; biri diğerini tanımlıyor.
///
/// Getirisi oyuncuda: yön bir kez öğreniliyor ve yirmi dört haritada geçerli
/// kalıyor. Doğu hep ileri, batı hep geri, kuzey hep PvP, güney hep boss.
enum GecitYonu {
  bati,
  dogu,
  kuzey,
  guney;

  GecitYonu get karsi => switch (this) {
    bati => dogu,
    dogu => bati,
    kuzey => guney,
    guney => kuzey,
  };

  /// Bu kenardaki geçidin konumu — [dunya]'nın ölçüsünden.
  ///
  /// [pay] kenardan uzaklık: geçidin tamamı haritanın içinde kalmalı, yoksa
  /// oyuncu kenara sıkışıp geçide giremez.
  Vec2 konumFor(GameWorld dunya, double pay) => switch (this) {
    bati => Vec2(pay, dunya.height / 2),
    dogu => Vec2(dunya.width - pay, dunya.height / 2),
    kuzey => Vec2(dunya.width / 2, pay),
    guney => Vec2(dunya.width / 2, dunya.height - pay),
  };
}

/// Tek bir harita — bölge ve tipin çifti.
///
/// Ayrı bir sınıf, çünkü geçit ağının düğümü bölge DEĞİL harita: bir bölgenin
/// üç haritası birbirine bağlı ama üçü ayrı yer.
/// KARAR 11.1 s1
class Harita {
  const Harita(this.bolge, this.tip);

  final Bolge bolge;
  final HaritaTipi tip;

  /// DÜNYANIN başladığı yer — ilk bölgenin PvE'si.
  ///
  /// Burada, sunucuda değil: hem sunucu (yeni oyuncuyu nereye koyacak) hem
  /// istemci (harita bilinmeden önce neyi varsayacak) aynı cevabı vermek
  /// zorunda. İki yerde yazılsaydı ikisi bir gün ayrışırdı.
  static final Harita baslangic = Harita(Bolge.ilk, HaritaTipi.pve);

  /// Bütün haritalar — merdivenin verdiği sırayla.
  static List<Harita> get hepsi => [
    for (final b in Bolge.hepsi)
      for (final t in HaritaTipi.values) Harita(b, t),
  ];

  /// Haritanın ölçüsü — bölgenin bant sayısından.
  GameWorld get dunya => bolge.harita;

  /// Girmek için gereken savaş puanı — bölgenin kapısı.
  double get girisEsigi => bolge.girisEsigi;

  bool kabulEder(double br, {int? seviye}) =>
      bolge.kabulEder(br, seviye: seviye);

  String get ad => '${bolge.ad} · ${tip.ad}';

  /// KALICI kimlik — `"3:pve"`.
  ///
  /// Ad değil kimlik: bölge adları oyuncuya görünen metin ve değişebilir;
  /// diskteki bir kayıt onlara bağlanamaz. Kademe + tip ikisi de yapısal.
  String get id => '${bolge.kademe}:${tip.name}';

  /// [id]'den harita — tanınmazsa `null`.
  ///
  /// Merdiven kısalırsa (ya da kayıt bozuksa) eski bir kimlik artık var olmayan
  /// bir bölgeyi gösterebilir. `null` dönmek çağıranı karar vermeye zorluyor;
  /// sessizce başlangıca düşmek, oyuncuya sebebini söylemeden yerini
  /// değiştirmek olurdu.
  static Harita? byId(String? id) {
    if (id == null) return null;
    final parca = id.split(':');
    if (parca.length != 2) return null;
    final kademe = int.tryParse(parca.first);
    final bolge = kademe == null ? null : Bolge.byKademe(kademe);
    if (bolge == null) return null;
    for (final tip in HaritaTipi.values) {
      if (tip.name == parca.last) return Harita(bolge, tip);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Harita && other.bolge == bolge && other.tip == tip;

  @override
  int get hashCode => Object.hash(bolge.kademe, tip);

  @override
  String toString() => ad;
}

/// İki haritayı bağlayan geçit.
///
/// Tek yönlü kayıt: A'dan B'ye. Karşılığı [GecitAgi.donusFor] ile bulunuyor ve
/// her zaman var — çıkmaz sokak yok.
class Gecit {
  const Gecit({required this.kaynak, required this.hedef, required this.yon});

  final Harita kaynak;
  final Harita hedef;

  /// Kaynak haritada hangi kenarda durduğu.
  final GecitYonu yon;

  /// Oyuncunun hedef haritada belireceği kenar — girişin KARŞISI.
  GecitYonu get cikisYonu => yon.karsi;

  /// Bu geçidin yarıçapı — durduğu haritanın kenar payından.
  double get yaricap => GecitAgi.yaricapFor(kaynak.dunya);

  /// Kaynak haritadaki konumu.
  Vec2 get konum =>
      yon.konumFor(kaynak.dunya, GecitAgi.kenarPayiFor(kaynak.dunya));

  /// Hedef haritada belirilen konum.
  Vec2 get cikisKonumu =>
      cikisYonu.konumFor(hedef.dunya, GecitAgi.kenarPayiFor(hedef.dunya));

  /// Geçmek için gereken savaş puanı.
  ///
  /// Aynı bölgenin haritaları arasında geçiş SERBEST: kapı bölgenin kapısı ve
  /// oyuncu zaten içeride. PvP'ye girmek bir karar, bir sınav değil.
  double get esik => hedef.bolge == kaynak.bolge ? 0 : hedef.girisEsigi;

  /// Geçmek için gereken seviye — aynı bölge içinde sıfır (11.4).
  int get seviyeEsigi =>
      hedef.bolge == kaynak.bolge ? 0 : hedef.bolge.seviyeEsigi;

  /// [seviye] `null` ise yalnız savaş puanı sınanır.
  bool acik(double br, {int? seviye}) =>
      br >= esik && (seviye == null || seviye >= seviyeEsigi);

  /// Kilitli bir geçit de ÇİZİLİYOR — bu bir karar.
  ///
  /// Oyuncu gidemeyeceği yeri görmeli: kapalı kapı bir hedef, görünmeyen kapı
  /// bir boşluk. Eşik de görünüyor, yani "ne kadar daha" sorusunun cevabı
  /// haritanın üstünde duruyor.
  bool get gorunur => true;

  @override
  String toString() => '${kaynak.ad} →${yon.name} ${hedef.ad}';
}

/// GEÇİT AĞI — yirmi dört haritanın bağlantı grafiği.
///
/// Hiçbir kenar elle yazılmıyor. Üç kuraldan çıkıyor:
///
/// * **Omurga** — bölge k'nın PvE'si, k+1'in PvE'sine doğu kenarından bağlı.
///   Merdiven sırayla yürünüyor; bölge atlanamıyor.
/// * **Yaprak** — her bölgenin PvP ve boss haritası yalnız kendi PvE'sine
///   bağlı. İkisi de çıkmaz: girmek bir karar, çıkmak aynı kapıdan.
/// * **Ayna** — her kenarın karşılığı hedef haritada karşı kenarda duruyor.
///
/// Neden PvP ve boss omurgada değil: omurga oyuncunun ZORUNLU yolu. PvP'yi
/// zorunlu yapmak, PvP'den kaçınmayı imkânsız kılardı; boss'u zorunlu yapmak
/// grup bulamayan oyuncuyu durdururdu. İkisi de 11'in "yavaşlamalı, DURMAMALI"
/// kuralını çiğnerdi.
abstract final class GecitAgi {
  /// [dunya]'nın KENAR PAYI kadar — geçidin yarıçapı.
  ///
  /// Kenar payı, `world.clamp`'in gemiyi uzak tuttuğu bant: haritanın
  /// girilemeyen duvar kalınlığı. Geçidin o kalınlıkta olması, kapının tam
  /// olarak duvar kadar derin olması demek — ve merkezi zaten kenardan iki
  /// kenar payı içeride duruyor ([kenarPayi]), yani kapının dış ağzı duvarın
  /// iç yüzüne değiyor.
  ///
  /// **Yeni bir girdi olmadan.** Bir süre `gecisSaniyesi` diye ayrı bir tepe
  /// tablo girdisi vardı ve gereksizdi: ölçüsü zaten var olan bir sayıdan
  /// çıkıyor. Sonuç da aynı yere düşüyor — referans hızda (320 birim/sn) çap
  /// 0,88 saniyede kat ediliyor, yani "kazara girilmeyecek kadar dar, nişan
  /// almayacak kadar geniş" hissi korunuyor.
  ///
  /// Parametrik, çünkü bağlayıcısıyla aynı satırda yazılsaydı bugünkü değerine
  /// (140) sabitlenmiş bir sürümden ayırt edilemezdi.
  static double yaricapFor(GameWorld dunya) => dunya.margin;

  /// GEÇİT YARIÇAPI — bütün haritalar aynı kenar payını taşıyor.
  ///
  /// Haritalar boyca farklı ama kenar payı [GameWorld]'ün varsayılanı ve
  /// hiçbiri onu değiştirmiyor; ayrıştıkları gün [Gecit.yaricap] kullanılmalı.
  static double get yaricap => yaricapFor(GameWorld.standard);

  /// Geçit merkezinin kenardan uzaklığı — [dunya]'da.
  ///
  /// Geçidin tamamı haritanın içinde kalmalı ve gemi de kenara sıkışmadan
  /// merkeze ulaşabilmeli. Yarıçap kenar payına eşit olduğu için sonuç
  /// TAM İKİ kenar payı: kapının dış ağzı duvarın iç yüzüne değiyor.
  static double kenarPayiFor(GameWorld dunya) =>
      dunya.margin + yaricapFor(dunya);

  static double get kenarPayi => kenarPayiFor(GameWorld.standard);

  /// Bütün geçitler — üç kuralın ürettiği kenarlar.
  static List<Gecit> get hepsi {
    final agir = <Gecit>[];
    for (final bolge in Bolge.hepsi) {
      final pve = Harita(bolge, HaritaTipi.pve);
      final onceki = Bolge.byKademe(bolge.kademe - 1);
      final sonraki = Bolge.byKademe(bolge.kademe + 1);

      // ── omurga ──
      if (onceki != null) {
        agir.add(
          Gecit(
            kaynak: pve,
            hedef: Harita(onceki, HaritaTipi.pve),
            yon: GecitYonu.bati,
          ),
        );
      }
      if (sonraki != null) {
        agir.add(
          Gecit(
            kaynak: pve,
            hedef: Harita(sonraki, HaritaTipi.pve),
            yon: GecitYonu.dogu,
          ),
        );
      }

      // ── yapraklar ve dönüşleri ──
      for (final (tip, yon) in [
        (HaritaTipi.pvp, GecitYonu.kuzey),
        (HaritaTipi.boss, GecitYonu.guney),
      ]) {
        final yaprak = Harita(bolge, tip);
        agir.add(Gecit(kaynak: pve, hedef: yaprak, yon: yon));
        agir.add(Gecit(kaynak: yaprak, hedef: pve, yon: yon.karsi));
      }
    }
    return agir;
  }

  /// [harita]'dan çıkan geçitler.
  static List<Gecit> gecitleriFor(Harita harita) => [
    for (final g in hepsi)
      if (g.kaynak == harita) g,
  ];

  /// [gecit]'in karşılığı — hedef haritadan geri gelen kenar.
  ///
  /// Her zaman var: ağda tek yönlü kenar yok, yoksa bir oyuncu giremediği
  /// değil ÇIKAMADIĞI bir haritada kalırdı.
  static Gecit donusFor(Gecit gecit) => hepsi.firstWhere(
    (g) => g.kaynak == gecit.hedef && g.hedef == gecit.kaynak,
    orElse: () => throw StateError('${gecit.hedef} çıkmaz sokak'),
  );

  /// [br] gücündeki oyuncunun girebildiği haritalar.
  static List<Harita> acikHaritalar(double br, {int? seviye}) => [
    for (final h in Harita.hepsi)
      if (h.kabulEder(br, seviye: seviye)) h,
  ];
}
