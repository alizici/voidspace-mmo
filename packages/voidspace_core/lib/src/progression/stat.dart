import '../combat/stat_layer.dart';
import '../design/turetilenler.dart';

/// Bir statın KİME ait olduğu.
///
/// Tasarım belgelerindeki en sinsi hataya karşı tek savunma: droid'e takılan
/// "%15 hasar" çipinin yanlışlıkla geminin de hasarını artırması — ya da
/// tersi, geminin bonusunun droid sayısıyla çarpılıp patlaması.
///
/// **Kural:** stat kimliği tek başına yeterli değil. `hasar@gemi` ile
/// `hasar@droid` İKİ FARKLI sayıdır; ayrı toplanır, ayrı gösterilir. Bir
/// sağlayıcı yalnız kendi kapsamına yazabilir; kapsamlar arası tek geçiş yolu
/// aktarım katsayısıdır (σ) ve başka hiçbir sızıntı yolu yoktur.
///
/// Adlar tasarımın dilinde. Bir süre `pilot · drone · pet · global` idi;
/// P.E.T. tasarımdan düştü, pilot gemi oldu. Kapsam diske yazılmadığı için
/// ad değişikliği veri kırmadı.
/// KARAR 02.3 s2
enum StatScope {
  /// Geminin kendisi.
  gemi,

  /// Droid'ler — kendi canı olan varlıklar. Henüz yok, kapsam hazır.
  droid,

  /// Roket — geminin ikinci silahı (18.1). Roketatar yuvasının ana statı
  /// buraya yazar: taban hasar gemi kapsamında lazerin tekelinde (04.2),
  /// roket kapsamında roketatarın. Zincirin geri kalanı geminin; kapsam
  /// yalnız tabanı ayırıyor ki lazerin yaylımına karışmasın.
  roket,

  /// Gerçekten HER ŞEYE uygulananlar (sezon etkisi, unvan erişimi).
  ///
  /// Hiçbir hasar statı küresel olamaz: küresel bir hasar statı, kapsam
  /// ayrımını tek satırda anlamsız kılar.
  kuresel,
}

/// Bir statın BİRİMİ — nasıl uygulanacağını kayıt söyler, çağıran değil.
///
/// | birim  | uygulama           | ne için                                 |
/// |--------|--------------------|-----------------------------------------|
/// | mutlak | havuz += değer     | taban hasar, gövde canı, kalkan         |
/// | oran   | × (1 + Σ)          | hasar artışı, atış hızı, hız            |
/// | egri   | d ÷ (d + K) → oran | zırh, kaçınma: mutlak girer, oran çıkar |
///
/// Üçlü ayrım bir incelik değil, aynı anda yaşanan iki hatanın panzehiri:
/// kalkan mutlak ilan edilip oran gibi uygulanıyor, gövde canı mutlak
/// uygulanıp oran gibi fiyatlanıyordu. Uygulama TEK yerde (bu enum); fiyat
/// türevinin adımı da aynı kaydı okuyor (`ItemBudget.turevAdimi`).
/// KARAR 02.2 s1 · KARAR 03.6 s1
enum StatBirimi {
  mutlak,
  oran,
  egri;

  /// [taban]a [deger]i kaydın söylediği biçimde uygula.
  ///
  /// Eğri için [taban] anlamsız ve [k] zorunlu: ham puan girer, azaltma
  /// ORANI çıkar — çağıran onu `1 − oran` olarak çarpar.
  double uygula(double taban, double deger, {double k = 0}) => switch (this) {
    StatBirimi.mutlak => taban + deger,
    StatBirimi.oran => taban * (1 + deger),
    StatBirimi.egri => SavunmaEgrileri.doyum(deger, k),
  };
}

/// Eşleşme türü — bir statın uzun ömürlü olmasının üç yolu.
/// KARAR 02.4 s1
enum EsTuru {
  /// İki stat aynı çarpımda buluşur; birine yatırım diğerinin türevini
  /// büyütür.
  buildIci,

  /// Rakibin statını doğrudan iptal eder; ikisi bir fark olarak hesaplanır.
  /// Fark hesabı kafesle gelecek; ilan bugünden.
  karsi,

  /// Doyan statın fazlası tanımlı oranla başka stata akar. Kafesle gelecek.
  tasma,
}

/// Bir statın EŞİ: marjinal değerini büyüten öteki stat.
///
/// Eşi olmayan stat doyar, doyduğu an ölür ve kütüphanede ölü satır kalır.
/// Bu yüzden eş kayıtta ZORUNLU: eşsiz bir stat derlenmez. Eşin kütüphanede
/// gerçekten var olduğunu test doğruluyor.
/// KARAR 02.4 s1
class StatEsi {
  const StatEsi.buildIci(this.id) : tur = EsTuru.buildIci;
  const StatEsi.karsi(this.id) : tur = EsTuru.karsi;
  const StatEsi.tasma(this.id) : tur = EsTuru.tasma;

  final EsTuru tur;

  /// Eşin kimliği.
  final String id;

  /// Belgedeki yazımı: `kritik_hasari`, `karşı: son_azaltma`.
  @override
  String toString() => switch (tur) {
    EsTuru.buildIci => id,
    EsTuru.karsi => 'karşı: $id',
    EsTuru.tasma => 'taşma: $id',
  };
}

/// Kütüphanedeki bir stat — SEKİZ alan.
///
/// Motor stat İSİMLERİNİ bilmez, yalnız bu kaydı okur. Yeni bir stat eklemek
/// motoru değiştirmiyorsa, kütüphane doğru kurulmuş demektir. Kayıt sekiz
/// alan: kimlik, etiket, katman, kanal, birim, kapsam, eş, alt stat. Katman,
/// kanal, birim ve eş kurucuda zorunlu — eksik kayıt derlenmez (02.5).
/// KARAR 02.1 s1 · KARAR 02.2 s1 · KARAR 02.5 s1 · KARAR 02.8 s3
class StatDef {
  const StatDef({
    required this.id,
    required this.label,
    required this.layer,
    required this.channel,
    required this.birim,
    required this.kapsam,
    required this.es,
    required this.altStat,
  });

  /// Kararlı kimlik. Kaydedilen veri buna bağlı, etikete değil.
  final String id;

  /// Arayüzde görünen ad. Serbestçe değişir; diske yazılmaz.
  final String label;

  /// Zincirde nereye çarpıldığı — alan 01'in katmanı.
  final StatLayer layer;

  /// Hangi kanalı besliyor — savaş gücü (BR) hesabı buradan geçiyor.
  final StatChannel channel;

  /// Nasıl uygulanacağı. Çağrı yeri değil, kayıt söyler.
  final StatBirimi birim;

  /// Yazılabileceği kapsamlar. Vektör kapsam dışına yazmayı reddediyor.
  final Set<StatScope> kapsam;

  /// Eşi — giriş şartı (02.4).
  final StatEsi es;

  /// Eşyada alt stat olarak çıkabilir mi. Taban hasar çıkamaz: lazerin
  /// tekelinde (04.2).
  final bool altStat;

  /// Değer yüzde mi (0.15 = %15) yoksa mutlak mı (240 hasar).
  ///
  /// Arayüzün sorduğu soru; cevabı birimden türüyor, ayrı bir bayrak değil.
  /// Eğri statın HAM puanı gösterilir, azaltma oranı değil.
  bool get percent => birim == StatBirimi.oran;
}

/// Bir statın beslediği kanal.
///
/// BR = √(SALDIRI × DAYANIKLILIK) geometrik ortalaması yalnız A = D
/// noktasında iki tarafa simetrik davranır; bütçe payının güç payına
/// dönüşmesinin şartı bu.
enum StatChannel { attack, defence, system }

/// Statların KAPSAMLA birlikte tutulduğu vektör.
///
/// `Map<String, double>` değil: anahtar `stat@kapsam`. Kapsamı anahtarın
/// parçası yapmak, çift sayımı bir hata olmaktan çıkarıp İMKÂNSIZ hâle
/// getiriyor — yanlış kapsama yazmak isteyen kodun anahtarı da yanlış üretmesi
/// gerekir. İkinci kilit kayıtta: stat o kapsamı tanımıyorsa yazma reddedilir.
/// KARAR 02.3 s2
class StatVector {
  StatVector();

  final Map<String, double> _values = {};

  static String key(String statId, StatScope scope) => '$statId@${scope.name}';

  double get(String statId, [StatScope scope = StatScope.gemi]) =>
      _values[key(statId, scope)] ?? 0;

  /// [statId]'yi [scope] kapsamına yaz.
  ///
  /// Kayıt o kapsamı tanımıyorsa yazma REDDEDİLİR: yanlış kapsama yazmak
  /// isteyen kodun önce kaydı değiştirmesi gerekir. Kütüphanede olmayan bir
  /// kimlik burada serbest — yabancı anahtar testinin işi, buranın değil.
  void add(String statId, StatScope scope, double value) {
    final kayit = Stats.byId(statId);
    if (kayit != null && !kayit.kapsam.contains(scope)) {
      throw ArgumentError(
        '$statId kaydı ${scope.name} kapsamını tanımıyor '
        '(${kayit.kapsam.map((s) => s.name).join(' · ')})',
      );
    }
    final k = key(statId, scope);
    _values[k] = (_values[k] ?? 0) + value;
  }

  void addAll(StatVector other) {
    for (final entry in other._values.entries) {
      _values[entry.key] = (_values[entry.key] ?? 0) + entry.value;
    }
  }

  bool get isEmpty => _values.isEmpty;

  Iterable<MapEntry<String, double>> get entries => _values.entries;

  @override
  String toString() => 'StatVector($_values)';
}

/// Bu oyunun statları: on beş AÇIK, yedi AYRILMIŞ.
///
/// Motor stat İSİMLERİNİ bilmez, yalnız bu kaydı okur: her stat kimliği bir
/// [StatLayer] taşıyor ve zincir ([DamageChain]) o katmana göre çarpıyor,
/// birimi ne diyorsa öyle uygulanıyor ([StatBirimi]). Yeni bir stat eklemek
/// motorun hiçbir yerini değiştirmiyor.
///
/// **Her stat TAM BİR katmana ait.** Katmansız bir stat, nereye çarpıldığı
/// belirsiz bir sayıdır — ve bu, değişmez testinin ilk yakaladığı şey.
///
/// L2 (koşullu) açık kütüphanede BOŞ ve bilerek boş: ayrılmış bir katmana
/// stat koymak, koşulu ölçen bir simülasyon olmadan ölü stat üretir. Oraya
/// yazılı iki kimlik kapalı listede duruyor.
/// KARAR 02.7 s2
abstract final class Stats {
  // ── L0 · taban ─────────────────────────────────────────────────────

  /// Lazerin tekelinde: alt stat olarak ÇIKMAZ (04.2).
  static const baseDamage = StatDef(
    id: 'taban_hasar',
    label: 'Taban hasar',
    layer: StatLayer.base,
    channel: StatChannel.attack,
    birim: StatBirimi.mutlak,
    kapsam: {StatScope.gemi, StatScope.droid, StatScope.roket},
    es: StatEsi.buildIci('hasar_artisi'),
    altStat: false,
  );

  static const maxHull = StatDef(
    id: 'govde_cani',
    label: 'Gövde',
    layer: StatLayer.base,
    channel: StatChannel.defence,
    // MUTLAK — bkz. [maxShield]'in birim sözleşmesi. Kardeşler: ikisi de
    // havuzun kendisi, ikisi de aynı birimde, ikisi de aynı fiyatta.
    birim: StatBirimi.mutlak,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('zirh'),
    altStat: true,
  );

  /// KALKAN — havuza eklenen MUTLAK miktar, gövdenin yüzdesi DEĞİL.
  ///
  /// Birim sözleşmesi alan 02'nin kararı ve tek bir ölçümle veriliyor. Oran
  /// biçimindeyken (`taban × (1 + s)`) aynı DF-1 jeneratörü şunu üretiyordu:
  ///
  /// | gövde    | bütçe | kalkan | puan başına |
  /// |----------|-------|--------|-------------|
  /// | Bastion  | 210,3 |  +841  |    4,00     |
  /// | Vanguard | 168,2 |  +925  |    5,50     |
  /// | Spectre  | 168,2 | +1.262 |    7,50     |
  ///
  /// Yani DAHA AZ bütçeyle DAHA ÇOK kalkan: bir bütçe puanı Spectre'de
  /// Bastion'dakinin 1,9 katı güç alıyordu. Oysa bütçenin tek sözü, bir
  /// puanın hangi stata konursa konsun aynı marjinal gücü almasıydı — ve
  /// eşyanın bütçe MALİYETİ gövdeden bağımsız olduğuna göre değeri de öyle
  /// olmak zorunda.
  ///
  /// İkinci sebep katmanda: [StatLayer.base] "havuzun kendisi" demek. Havuzun
  /// yüzdesi bir taban stat değil, bir çarpandır — o `additive` katmanının işi
  /// ([shieldRegen], [speed] öyle).
  ///
  /// Gövdenin büyüklük avantajı kayboluyor değil: Spectre'nin üstünlüğü kendi
  /// 15.000'lik taban havuzunda, taktığı jeneratörde değil.
  static const maxShield = StatDef(
    id: 'kalkan',
    label: 'Kalkan',
    layer: StatLayer.base,
    channel: StatChannel.defence,
    birim: StatBirimi.mutlak,
    // Droid de yazıyor: droide giren iki eşyadan biri kalkan jeneratörü
    // (05.4 s5). Droidin TEK havuzu var ve o havuz zaten "gövde artı kalkan"
    // olarak ölçülüyor (05.4) — jeneratörün kalkanı oraya biniyor, ayrı bir
    // droid kalkan havuzu açılmıyor.
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('kalkan_yenilenmesi'),
    altStat: true,
  );

  // ── L1 · toplamsal ─────────────────────────────────────────────────

  static const damageBonus = StatDef(
    id: 'hasar_artisi',
    label: 'Hasar artışı',
    layer: StatLayer.additive,
    channel: StatChannel.attack,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('taban_hasar'),
    altStat: true,
  );

  static const fireRate = StatDef(
    id: 'atis_hizi',
    label: 'Atış hızı',
    layer: StatLayer.additive,
    channel: StatChannel.attack,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('taban_hasar'),
    altStat: true,
  );

  static const shieldRegen = StatDef(
    id: 'kalkan_yenilenmesi',
    label: 'Kalkan yenilenmesi',
    layer: StatLayer.additive,
    channel: StatChannel.defence,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi},
    es: StatEsi.buildIci('kalkan'),
    altStat: true,
  );

  /// Hız bir havuz değil bir hız: `additive` + oran.
  static const speed = StatDef(
    id: 'hiz',
    label: 'Hız',
    layer: StatLayer.additive,
    channel: StatChannel.system,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi},
    es: StatEsi.buildIci('itki_dolumu'),
    altStat: true,
  );

  /// İtki dolumu — bir itki şarjının dolma SÜRESİNİ kısaltıyor. Hızın eşi:
  /// hızlı gemi daha sık itki ister.
  static const boostRecharge = StatDef(
    id: 'itki_dolumu',
    label: 'İtki dolumu',
    layer: StatLayer.additive,
    channel: StatChannel.system,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi},
    es: StatEsi.buildIci('hiz'),
    altStat: true,
  );

  static const range = StatDef(
    id: 'menzil',
    label: 'Menzil',
    layer: StatLayer.additive,
    // SİSTEM kanalı, saldırı DEĞİL — ve bu bir sınıflandırma zevki değil bir
    // ölçüm sonucu: ∂DPS/∂menzil = 0. Menzil hasarı büyütmüyor, hedefte KALMA
    // süresini uzatıyor; yani saldırı kanalında fiyatlanırsa bedava güç gibi
    // görünür, oysa verdiği şey konumsal bir avantaj.
    //
    // Aynı sebeple hem saldırıya hem kaçışa yarıyor, ve alan 09 onu tam olarak
    // bu yüzden sistem katsayılarının en değerlisi yapıyor (0,50).
    channel: StatChannel.system,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('hiz'),
    altStat: true,
  );

  // ── L3 · kritik ────────────────────────────────────────────────────

  /// Kritik ŞANSI (k). Zar PRD ile atılıyor — bağımsız değil.
  static const critChance = StatDef(
    id: 'kritik_sansi',
    label: 'Kritik şansı',
    layer: StatLayer.critical,
    channel: StatChannel.attack,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('kritik_hasari'),
    altStat: true,
  );

  /// Kritik ÇARPANI (d). Beklenen değer `1 + k(d − 1)` ikisinden çıkıyor.
  static const critMultiplier = StatDef(
    id: 'kritik_hasari',
    label: 'Kritik hasarı',
    layer: StatLayer.critical,
    channel: StatChannel.attack,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('kritik_sansi'),
    altStat: true,
  );

  // ── L4 · savunma ───────────────────────────────────────────────────

  /// Zırh. Doyum eğrisinden geçip AZALTMAYA dönüşüyor; kendisi bir oran değil
  /// ham bir stat — birimi EĞRİ.
  static const armor = StatDef(
    id: 'zirh',
    label: 'Zırh',
    layer: StatLayer.mitigation,
    channel: StatChannel.defence,
    birim: StatBirimi.egri,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.buildIci('govde_cani'),
    altStat: true,
  );

  /// Kaçınma. Zırhın kardeşi: aynı biçim, farklı K.
  ///
  /// **Iskalama üretmez.** Mermiler gerçek zamanlı uçuyor ve oyuncu merminin
  /// gemiye çarptığını görüyor; çarpan bir merminin "ıskaladın" demesi ekranın
  /// söylediğiyle sistemin söylediğinin çelişmesi demek. Kaçınma hasarı
  /// SIYIRIYOR — azaltıyor, sıfırlamıyor.
  static const evasion = StatDef(
    id: 'kacinma',
    label: 'Kaçınma',
    layer: StatLayer.mitigation,
    channel: StatChannel.defence,
    birim: StatBirimi.egri,
    kapsam: {StatScope.gemi},
    es: StatEsi.buildIci('zirh'),
    altStat: true,
  );

  // ── L5 · düz ───────────────────────────────────────────────────────

  /// Son hasar — bütün çarpanlardan sonra eklenen düz sayı. Karşısı son
  /// azaltma; fark hesabı kafesle gelecek, ilan bugünden.
  static const flatDamage = StatDef(
    id: 'son_hasar',
    label: 'Son hasar',
    layer: StatLayer.flat,
    channel: StatChannel.attack,
    birim: StatBirimi.mutlak,
    kapsam: {StatScope.gemi},
    es: StatEsi.karsi('son_azaltma'),
    altStat: true,
  );

  /// Son azaltma — bütün çarpanlardan sonra düşülen düz sayı.
  static const flatMitigation = StatDef(
    id: 'son_azaltma',
    label: 'Son azaltma',
    layer: StatLayer.flat,
    channel: StatChannel.defence,
    birim: StatBirimi.mutlak,
    kapsam: {StatScope.gemi},
    es: StatEsi.karsi('son_hasar'),
    altStat: true,
  );

  /// AÇIK kütüphane: on beş kimlik. Kimlikten kayda ulaşan her yer buradan
  /// okur; sağlayıcılar yalnız bunları verebilir.
  static const List<StatDef> all = [
    baseDamage,
    damageBonus,
    fireRate,
    range,
    maxHull,
    maxShield,
    shieldRegen,
    speed,
    boostRecharge,
    critChance,
    critMultiplier,
    armor,
    evasion,
    flatDamage,
    flatMitigation,
  ];

  // ── AYRILMIŞ · kafesle gelecek, bugün KAPALI ───────────────────────
  //
  // Kimlikleri şimdiden rezerve: kafes geldiğinde çakışma ya da yeniden
  // adlandırma olmayacak, o güne kadar hangi boşluğun doldurulacağı görünür
  // kalacak. Katman ve eş İLK YERLEŞİM; kafes yazılırken 02.6 yeniden açılır.
  // Üç karşı-stat çifti (delici ↔ sertlik, kırıcı ↔ zırh katmanı, durum
  // hasarı ↔ durum azaltma) ve kritik şansının karşısı.
  // KARAR 02.6 s1

  static const delici = StatDef(
    id: 'delici',
    label: 'Delici',
    layer: StatLayer.mitigation,
    channel: StatChannel.attack,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.karsi('sertlik'),
    altStat: true,
  );

  static const sertlik = StatDef(
    id: 'sertlik',
    label: 'Sertlik',
    layer: StatLayer.mitigation,
    channel: StatChannel.defence,
    birim: StatBirimi.egri,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.karsi('delici'),
    altStat: true,
  );

  static const kirici = StatDef(
    id: 'kirici',
    label: 'Kırıcı',
    layer: StatLayer.mitigation,
    channel: StatChannel.attack,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.karsi('zirh_katmani'),
    altStat: true,
  );

  static const zirhKatmani = StatDef(
    id: 'zirh_katmani',
    label: 'Zırh katmanı',
    layer: StatLayer.mitigation,
    channel: StatChannel.defence,
    birim: StatBirimi.egri,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.karsi('kirici'),
    altStat: true,
  );

  static const kritikDirenci = StatDef(
    id: 'kritik_direnci',
    label: 'Kritik direnci',
    layer: StatLayer.critical,
    channel: StatChannel.defence,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.karsi('kritik_sansi'),
    altStat: true,
  );

  /// Koşullu katmanın ilk kiracısı — açık kütüphanede L2 boş kalıyor.
  static const durumHasari = StatDef(
    id: 'durum_hasari',
    label: 'Durum hasarı',
    layer: StatLayer.conditional,
    channel: StatChannel.attack,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.karsi('durum_azaltma'),
    altStat: true,
  );

  static const durumAzaltma = StatDef(
    id: 'durum_azaltma',
    label: 'Durum azaltma',
    layer: StatLayer.conditional,
    channel: StatChannel.defence,
    birim: StatBirimi.oran,
    kapsam: {StatScope.gemi, StatScope.droid},
    es: StatEsi.karsi('durum_hasari'),
    altStat: true,
  );

  /// Ayrılmış yedi kimlik. [byId] bunları BULMAZ: hiçbir sağlayıcı ulaşamaz,
  /// havuza ya da ana stata yazıldıkları an yabancı anahtar testi kırılır,
  /// fiyatları yok.
  /// KARAR 02.6 s1
  static const List<StatDef> ayrilmis = [
    delici,
    sertlik,
    kirici,
    zirhKatmani,
    kritikDirenci,
    durumHasari,
    durumAzaltma,
  ];

  /// Kayıt tablosunun tamamı: açık + ayrılmış, yirmi iki kimlik.
  /// KARAR 02.7 s2
  static List<StatDef> get hepsi => [...all, ...ayrilmis];

  /// AÇIK kütüphanede arama. Ayrılmış kimlik bulunmaz — bilerek.
  static StatDef? byId(String id) {
    for (final stat in all) {
      if (stat.id == id) return stat;
    }
    return null;
  }

  /// Açık ya da ayrılmış — belge tablosunun ve eş doğrulamasının aradığı yer.
  static StatDef? kayit(String id) {
    for (final stat in ayrilmis) {
      if (stat.id == id) return stat;
    }
    return byId(id);
  }

  /// [layer] katmanına giren AÇIK statlar. Değişmez testinin ("koşullu
  /// statların hepsi L2'de" ve "L2 bugün boş") okuduğu yer.
  static Iterable<StatDef> inLayer(StatLayer layer) =>
      all.where((s) => s.layer == layer);
}
