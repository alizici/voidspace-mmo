import '../design/tasarim_girdileri.dart';
import '../domain/laser_stats.dart';
import '../domain/ship_stats.dart';
import 'budget.dart';
import '../combat/combat_glossary.dart';
import 'hull.dart';
import 'item.dart';
import 'referans_cozumu.dart';
import 'stat.dart';
import '../design/turetilenler.dart';
import '../domain/droid_grubu.dart';
import 'formasyon.dart';
import 'saglayici.dart';

/// Bir yuvanın adresi: tür + sıra.
///
/// `laser#0`, `generator#3`. Kararlı bir kimlik olmak zorunda çünkü donatım
/// diske yazılıyor ve yuva sayısı gövdeye göre değişiyor.
class SlotRef {
  const SlotRef(this.type, this.index);

  final SlotType type;
  final int index;

  String get id => '${type.name}#$index';

  static SlotRef? parse(String id) {
    final parts = id.split('#');
    if (parts.length != 2) return null;
    final index = int.tryParse(parts[1]);
    if (index == null) return null;
    for (final type in SlotType.values) {
      if (type.name == parts[0]) return SlotRef(type, index);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SlotRef && other.type == type && other.index == index;

  @override
  int get hashCode => Object.hash(type, index);

  @override
  String toString() => id;
}

/// Bir geminin DONATIMI: hangi yuvada hangi eşya örneği var.
class Loadout {
  Loadout({required this.hullId, Map<String, String>? slots})
    : _slots = {...?slots};

  final String hullId;

  /// Yuva kimliği → eşya örneği kimliği.
  final Map<String, String> _slots;

  HullClass get hull => HullClass.byId(hullId) ?? HullClass.starter;

  Map<String, String> get slots => Map.unmodifiable(_slots);

  String? itemAt(SlotRef slot) => _slots[slot.id];

  /// [slot] bu gövdede GERÇEKTEN var mı.
  ///
  /// Sunucu bunu doğrulamak zorunda: istemci uydurma bir yuvaya takmayı
  /// deneyebilir ve o yuva bütçe hesabında yok olduğu için bedava güç olurdu.
  bool hasSlot(SlotRef slot) =>
      slot.index >= 0 && slot.index < hull.slotCount(slot.type);

  void equip(SlotRef slot, String instanceId) => _slots[slot.id] = instanceId;

  void unequip(SlotRef slot) => _slots.remove(slot.id);

  /// Bu eşya örneği başka bir yuvada takılı mı.
  SlotRef? slotOf(String instanceId) {
    for (final entry in _slots.entries) {
      if (entry.value == instanceId) return SlotRef.parse(entry.key);
    }
    return null;
  }

  Map<String, Object?> toJson() => {'hullId': hullId, 'slots': _slots};

  static Loadout fromJson(Map<String, Object?> json) => Loadout(
    hullId: json['hullId']! as String,
    slots: {
      for (final e in (json['slots'] as Map? ?? {}).entries)
        e.key as String: e.value as String,
    },
  );
}

/// Donatımı ETKİN gemi statlarına çeviren tek yer.
///
/// **Neden ortak pakette:** sonucu sunucu hesaplıyor (otorite orada) ama
/// istemci de hangar ekranında "bu lazeri taksam ne olur" diye göstermek
/// zorunda. İki ayrı uygulama olsaydı, hangarda gösterilen sayı ile savaşta
/// inen hasar sessizce ayrışırdı — ve bu, oyuncunun asla affetmediği hata
/// türü.
abstract final class LoadoutResolver {
  /// Donatımdan stat vektörü üret.
  ///
  /// Her eşya, TAKILDIĞI YUVANIN kapsamına yazıyor — eşyanın kendi
  /// kapsamına değil. Aynı lazer hem gemiye hem (ileride) droide takılabilsin
  /// diye: statını hangi kapsama yazacağını eşya değil YUVA belirliyor.
  /// KARAR 05.3 s1
  /// Droid kapsamına yaz — AMA yalnız droidin kullanabildiğini.
  ///
  /// Droid bir taşıyıcı (05.4 s5) ve içine giren lazerle jeneratörün alt
  /// statları gemininkiyle aynı havuzdan geliyor: `hiz`, `kacinma`,
  /// `kalkan_yenilenmesi`, `son_azaltma`, `son_hasar`. Droid grubunun bunlara
  /// karşılığı yok — [droidGrubuOf] yedi statı okuyor, ötesini değil.
  ///
  /// Kaydın [StatDef.kapsam] alanı bu sorunun TEK yetkilisi: droid kapsamı
  /// yazmayan bir stat droidde yok demek. Eskiden bu ayrım yapılmıyordu ve
  /// kalkan jeneratörü takılmış bir droid [StatVector.add]'i patlatıyordu —
  /// kural jeneratörü droide sokmaya izin verirken (05.4 s5) kayıt kalkanı
  /// gemiye hapsettiği için. Sessizce yutmak yerine kaydın dediğine uyuluyor;
  /// bir statın droidde işlemesi isteniyorsa önce kaydı droid kapsamı
  /// almalı, sonra [droidGrubuOf] onu okumalı.
  /// KARAR 05.4 s5
  static void droidYaz(StatVector vector, String statId, double value) {
    final kayit = Stats.byId(statId);
    if (kayit != null && !kayit.kapsam.contains(StatScope.droid)) return;
    vector.add(statId, StatScope.droid, value);
  }

  static StatVector vectorOf(
    Loadout loadout,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue, {
    List<String> filo = const [],
    Map<String, List<String>> droidDonanimi = const {},
  }) {
    final vector = StatVector();
    final hull = loadout.hull;

    // Droid FİLOSU gövdeden bağımsız (04.10): filo yuvası droid kapsamına
    // yazar (05.4). Bütçesi gövdeye değil filo tavanına bölünüyor.
    for (final (instance, spec) in filoEsyalari(filo, inventory, catalogue)) {
      droidYaz(
        vector,
        spec.mainStat,
        ItemBudget.mainStatValue(spec, instance.level, hull),
      );
      for (final sub in altStatlariFor(instance, spec, hull).entries) {
        droidYaz(vector, sub.key, sub.value);
      }

      // DROİDİN İÇİNDEKİLER (05.4 s5): droid bir taşıyıcı, içine lazer ya da
      // jeneratör giriyor ve onlar da droid kapsamına yazıyor. Ağırlıkları
      // gemidekinden farklı: yuva katsayısı droidin, filo payının donanıma
      // ayrılan kısmından. Aynı lazer gemide başka, droidde başka değer
      // taşıyor ve bu 08.2'nin doğrudan sonucu.
      // KAPASİTE ÇÖZÜMDE DE GEÇERLİ — yalnız takarken değil.
      //
      // Yuva sayısı bir zamanlar sadece [Hangar.droideTak] içinde
      // sınanıyordu: kayda giren liste kapasiteyi aşamazdı, o yüzden çözüm
      // listeye güvenip hepsini okuyordu. Kapasite DEĞİŞTİĞİ gün o güven
      // kırıldı — merdiven droidleri elit sayılmaktan çıkıp tek yuvaya
      // inince (05.4 s5), diskteki her iki eşyalı droid ikisini birden
      // vermeye devam etti. Düzeltme sessizce atlanıyordu.
      //
      // Kapasite artık hesabın kendisinin kuralı: liste ne derse desin,
      // droid taşıyabildiği kadarını veriyor. Fazlası oyuncunun malı olarak
      // envanterde duruyor ([Hangar] yüklerken geri veriyor); burada yalnız
      // GÜCÜ kesiliyor.
      final tasiyabilir = Saglayici.droidYuvaSayisi(spec);
      for (final id
          in (droidDonanimi[instance.instanceId] ?? const <String>[]).take(
            tasiyabilir,
          )) {
        final takili = inventory[id];
        final takiliSpec = takili == null ? null : catalogue[takili.specId];
        if (takili == null || takiliSpec == null) continue;
        if (!Saglayici.droidDonanimTipleri.contains(takiliSpec.slot)) continue;
        // Oran: aynı eşyanın droid yuvasındaki ağırlığının gemi
        // yuvasındakine bölümü. Alt statlar da aynı oranla iniyor, yoksa
        // droide takılan eşyanın alt statları gemidekiyle aynı kalırdı.
        final gemiKatsayisi = ItemBudget.slotCoefficient(takiliSpec.slot, hull);
        final oran = gemiKatsayisi == 0
            ? 0.0
            : ItemBudget.droidDonanimKatsayisi(hull) / gemiKatsayisi;
        droidYaz(
          vector,
          takiliSpec.mainStat,
          ItemBudget.mainStatValue(takiliSpec, takili.level, hull) * oran,
        );
        for (final sub in altStatlariFor(takili, takiliSpec, hull).entries) {
          droidYaz(vector, sub.key, sub.value * oran);
        }
      }
    }

    for (final (slot, instance, spec) in _equipped(
      loadout,
      inventory,
      catalogue,
    )) {
      // Kapsamı EŞYA değil YUVA belirliyor (05.4): gemi yuvasındaysa gemi,
      // droid yuvasındaysa droid. Aynı eşya listesi iki yeri birden besliyor
      // ve çift sayım riski yok — bir eşya aynı anda iki yuvada olamaz.
      // KARAR 05.4 s5
      final scope = Saglayici.kapsamOf(slot.type);
      // Roketatarın ANA statı roket kapsamına (18.1): taban hasar orada
      // ikinci silahın tabanı, gemi kapsamında lazerin yaylımına karışmaz.
      // Alt statları gemiye: roketatar geminin silahı, bonusları herkesin.
      // KARAR 18.1 s1
      final anaKapsam = slot.type == SlotType.launcher
          ? StatScope.roket
          : scope;
      vector.add(
        spec.mainStat,
        anaKapsam,
        ItemBudget.mainStatValue(spec, instance.level, hull),
      );
      // Alt statlar TÜRETİLEN, saklanan değil — ta ki oyuncu çevirene kadar.
      //
      // `instance.subStats` bir zamanlar okunuyor ve serileştiriliyordu ama
      // hiçbir yerde YAZILMIYORDU: her eşyanın alt stat haritası boştu, yani
      // bütçenin alt statlara ayrılan payı hiç kimseye gitmiyordu.
      //
      // Saklanan boş DEĞİLSE o kazanıyor: alan 07'nin çevirmesi sonucunu oraya
      // yazacak ve türetilen ilk rolü ezecek.
      final altStatlar = altStatlariFor(instance, spec, hull);
      for (final sub in altStatlar.entries) {
        vector.add(sub.key, scope, sub.value);
      }
    }
    return vector;
  }

  /// GERÇEKTEN takılı ve geçerli yuvalar.
  ///
  /// Geçerlilik üç şeyi birden istiyor: yuva bu gövdede var, eşya envanterde
  /// duruyor, ve eşyanın tipi yuvanın tipiyle aynı. Üçü de sunucunun
  /// doğrulaması gereken şeyler — istemci uydurma bir yuvaya takmayı
  /// deneyebilir.
  ///
  /// Ayrı bir yordam çünkü iki cevap AYNI listeden çıkmak zorunda: statlar
  /// ([vectorOf]) ve namlu sayısı ([equippedCount]). İki ayrı döngü, bir gün
  /// birinde düzeltilip diğerinde unutulan bir geçerlilik kuralı demekti —
  /// ve o hâlde gemi, stat vermeyen bir silahı ÇİZERDİ.
  /// Bir örneğin GEÇERLİ alt statları.
  ///
  /// Saklanan boş DEĞİLSE o kazanıyor, boşsa kimlikten türetilen ilk roll.
  /// Öncelik TEK bir yerde: çevirme de aynı soruyu soruyor ve iki ayrı yerde
  /// yazılsaydı, biri değiştiğinde öteki sessizce eski kuralı uygulardı.
  /// [hull]'ün merdivendeki SIRASI — istemcinin hangi çizimi kullanacağı.
  ///
  /// Tanınmayan gövde başlangıç kademesine düşüyor: istemci onu Firebird
  /// çizer. Sessiz ama doğru taraf — bilinmeyen bir kademe numarası istemcide
  /// dizi sınırı taşırması olurdu.
  static int govdeKademesiOf(HullClass hull) {
    final k = HullClass.all.indexOf(hull);
    return k < 0 ? 0 : k;
  }

  static Map<String, double> altStatlariFor(
    ItemInstance instance,
    ItemSpec spec,
    HullClass hull,
  ) {
    // Taban eşya: alt stat YOK (15.2). Derinlik satılmıyor; raftan alınan
    // parça yuvayı doldurur, ganimetle yarışmaz. KARAR 15.2 s1
    if (instance.taban) return const {};
    final roller = instance.altStatRolleri;
    if (roller.isEmpty) {
      return ItemBudget.subStatValues(
        spec,
        instance.level,
        hull,
        instance.instanceId,
      );
    }
    // Çevrilmiş stat: rol × taban. Taban rankı, gövde katsayısını ve artı
    // adımını taşıyor; rol yalnız kaliteyi (07.5). Havuzda olmayan bir stat
    // (kayıt bozuk ya da tasarım değişti) sessizce düşüyor.
    final sonuc = <String, double>{};
    for (final e in roller.entries) {
      final taban = ItemBudget.altStatTabani(
        spec,
        instance.level,
        hull,
        e.key,
        instance.instanceId,
      );
      if (taban == null) continue;
      sonuc[e.key] = taban * e.value;
    }
    return sonuc;
  }

  static Iterable<(SlotRef, ItemInstance, ItemSpec)> _equipped(
    Loadout loadout,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue,
  ) sync* {
    for (final entry in loadout.slots.entries) {
      final slot = SlotRef.parse(entry.key);
      if (slot == null || !loadout.hasSlot(slot)) continue;
      final instance = inventory[entry.value];
      if (instance == null) continue;
      final spec = catalogue[instance.specId];
      if (spec == null || spec.slot != slot.type) continue;
      yield (slot, instance, spec);
    }
  }

  /// [type] tipinde kaç yuvanın DOLU olduğu.
  ///
  /// Gövdenin yuva SAYISI değil, oyuncunun gerçekten taktığı sayı. Aradaki
  /// fark ekranda görünüyor: gemi taktığın kadar namlu taşıyor.
  static int equippedCount(
    Loadout loadout,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue,
    SlotType type,
  ) {
    var n = 0;
    for (final (slot, _, _) in _equipped(loadout, inventory, catalogue)) {
      if (slot.type == type) n++;
    }
    return n;
  }

  /// Stat vektörünü simülasyonun anladığı [ShipStats]'a çevir.
  ///
  /// **Burada çarpma YOK, dağıtma var.** Eskiden bu yordam kendi katman
  /// matematiğini yapıyordu (`taban × (1 + bonus)`) ve zincirin bir kopyasıydı;
  /// kopya olduğu için de sessizce ayrışabilirdi. Artık her stat KENDİ
  /// katmanının alanına yazılıyor ve çarpımı tek bir yer yapıyor:
  /// `DamageChain`. İki yerde duran matematik, bir sonraki denge turunda iki
  /// farklı sonuç demek.
  ///
  /// Havuzlar (gövde, kalkan, hız) zincirin dışında: onlar hasar değil
  /// KAPASİTE, ve L0 + L1 biçimleri burada kalıyor.
  static ShipStats apply(
    HullClass hull,
    StatVector vector, {
    required int equippedLasers,
    List<double> droidCarpanlari = const [],
    Formasyon formasyon = Formasyon.varsayilan,
    double argeAktarim = 0,
  }) {
    double stat(StatDef def) => vector.get(def.id);
    // Kaydın BİRİMİYLE uygula — çağrı yeri karar vermiyor. Havuz statı
    // mutlaksa toplanır, oran ise çarpar; hangisi olduğunu kütüphane söylüyor
    // ve bir statın birimi değişirse burası kendiliğinden ona uyar. Eğri
    // statlar (zırh, kaçınma) ham puan olarak geçiyor; doyumdan gemi
    // statlarının içinde, alan 04'ün K'sıyla çıkıyorlar.
    // KARAR 02.2 s1 · KARAR 03.6 s1
    double uygula(StatDef def, double taban) =>
        def.birim.uygula(taban, stat(def));
    // Sürelere uygulanan ÇARPAN: hız artınca süre kısalır, yani bölünür.
    double carpan(StatDef def) => def.birim.uygula(1, stat(def));

    // ── Havuzlar: kayıt ne diyorsa ─────────────────────────────────────
    // Kalkan da gövde canı gibi MUTLAK: ikisi de havuzun kendisi
    // ([Stats.maxShield]'in birim sözleşmesi). Kalkan bir zamanlar
    // `× (1 + s)` idi ve bu, jeneratörün değerini gövde büyüklüğüne
    // bağlıyordu — aynı eşya Spectre'de bir bütçe puanı başına 1,9 kat güç
    // veriyordu.
    //
    // Hız FARKLI ve öyle kalıyor: `additive` katmanında, birimi oran, yani
    // sözleşmesi zaten çarpan. Hız bir havuz değil bir hız.
    final hullPoints = uygula(Stats.maxHull, hull.baseHull);
    final shield = uygula(Stats.maxShield, hull.baseShield);
    final speed = uygula(Stats.speed, hull.baseSpeed);

    // ── L0: Σ takılı lazerin taban hasarı ──────────────────────────────
    //
    // Vektör TOPLAMI taşıyor (her lazer kendi taban hasarını yazdı); silahın
    // kendi kimliği ise NAMLU BAŞINA sayı. Toplamı namlu sayısına bölmek, aynı
    // sayının iki kez çarpılmasını imkânsız kılıyor — `baseVolleyDamage`
    // yeniden namluyla çarpınca tam olarak toplama dönüyor.
    //
    // Eski hâli tam da bu hatayı yapıyordu: toplam hasar `laser.damage`a
    // yazılıyor, sonra `volleyDamage` onu yuva sayısıyla BİR KEZ DAHA
    // çarpıyordu. Beş lazerli bir gemide yaylım beş katına çıkıyordu ve
    // hiçbir belge o sayıyı öngörmüyordu.
    final totalBase = stat(Stats.baseDamage);
    final perBarrel = equippedLasers > 0 ? totalBase / equippedLasers : 0.0;

    const reference = ShipStats.bastion;
    final laser = LaserStats(
      id: reference.laser.id,
      name: reference.laser.name,
      // Lazer yuvası boşsa gemi ateş edemez: taban hasar eşyadan geliyor.
      damage: perBarrel,
      fireInterval: reference.laser.fireInterval / carpan(Stats.fireRate),
      range: uygula(Stats.range, reference.laser.range),
    );

    return ShipStats(
      name: hull.name,
      maxHull: hullPoints,
      maxShield: shield,
      shieldRegenPerSecond: uygula(
        Stats.shieldRegen,
        reference.shieldRegenPerSecond,
      ),
      shieldRegenDelay: reference.shieldRegenDelay,
      speed: speed,
      boostFactor: reference.boostFactor,
      boostDuration: reference.boostDuration,
      maxBoostCharges: reference.maxBoostCharges,
      // İtki dolumu: şarjın dolma SÜRESİ kısalıyor, oran bölüyor.
      boostRecharge: reference.boostRecharge / carpan(Stats.boostRecharge),
      laser: laser,
      laserSlots: hull.laserSlots,
      equippedLasers: equippedLasers,
      // Kademe = gövdenin merdivendeki SIRASI. Ayrı bir alan olarak
      // saklanmıyor çünkü `HullClass.all` zaten o sıra; ikinci bir kayıt
      // ayrışabilecek üçüncü bir gerçek olurdu.
      //
      // Tanınmayan gövde başlangıç kademesine düşüyor: istemci onu Firebird
      // çizer. Sessiz ama doğru taraf — bilinmeyen bir kademe numarası
      // istemcide dizi sınırı taşırması olurdu.
      govdeKademesi: govdeKademesiOf(hull),
      // L1 — zincire ÇİĞ giriyor, burada çarpılmıyor.
      damageBonus: stat(Stats.damageBonus),
      // L2 — ayrılmış. Kütüphanede koşullu stat olmadığı için bugün 0; katman
      // yine de zincirde duruyor.
      conditionalBonus: 0,
      // L3 — referans değerler tepe tablodan, ekipman üstüne EKLİYOR.
      critChance: TasarimGirdileri.kritikSansiReferans + stat(Stats.critChance),
      critMultiplier:
          TasarimGirdileri.kritikCarpaniReferans + stat(Stats.critMultiplier),
      // L4 — ham statlar; eğriye `ShipStats` içinde giriyorlar.
      armor: stat(Stats.armor),
      evasion: stat(Stats.evasion),
      // L5 — düz.
      flatDamage: stat(Stats.flatDamage),
      flatMitigation: stat(Stats.flatMitigation),
      // Sistem kanalı — ÇİĞ oranlar; savaş puanının sistem puanı bunlardan.
      // KARAR 09.5 s1
      rangeBonus: stat(Stats.range),
      speedBonus: stat(Stats.speed),
      boostRechargeBonus: stat(Stats.boostRecharge),
      // Salvo tabanı: roket kapsamındaki taban hasar × kadans oranı. Eşya
      // lazer kadansında fiyatlandı (03), roket seyrek atıyor, salvo o kadar
      // büyük; DPS payı bütçe payına eşit kalıyor (18.1).
      roketHasari:
          vector.get(Stats.baseDamage.id, StatScope.roket) *
          Turetilenler.roketKadansOrani,
      droidler: droidGrubuOf(
        vector,
        droidCarpanlari,
        formasyon,
        argeAktarim: argeAktarim,
        gemiHasarBonusu: stat(Stats.damageBonus),
        gemiKritikSansi: stat(Stats.critChance),
        gemiKritikCarpani: stat(Stats.critMultiplier),
      ),
    );
  }

  /// DROİD GRUBU — droid kapsamından ve σ bağlaşımından (05.1, 05.5).
  ///
  /// [droidCarpanlari] takılı her droidin rank × artı çarpanı: taban hasar
  /// ve havuz türetilen çapanın o katı. Droid kapsamına yazılan statlar
  /// (droid eşyalarının ana ve alt statları) grubun kendi bonusu; geminin
  /// çarpanlarından payı σ ile geliyor: `1 + σ · (gemi çarpanı − 1)`, yani
  /// bonus cinsinden `kendi + σ × gemininki`. Formasyon σ'yı ve havuzu iter.
  /// KARAR 05.5 s3 · KARAR 05.9 s1
  static DroidGrubu droidGrubuOf(
    StatVector vector,
    List<double> droidCarpanlari,
    Formasyon formasyon, {
    double argeAktarim = 0,
    required double gemiHasarBonusu,
    required double gemiKritikSansi,
    required double gemiKritikCarpani,
  }) {
    if (droidCarpanlari.isEmpty) return DroidGrubu.yok;
    double d(StatDef def) => vector.get(def.id, StatScope.droid);
    // σ üç kaynaktan: tepe tablo (05.5), formasyon takası (05.9) ve ArGe'nin
    // kapsam yönlendirmesi (05.7). Kelepçe burada, tek yerde: üç kaynak da
    // aynı sayıya biniyor ve ayrı ayrı kelepçelenselerdi biri ötekini
    // gizlerdi.
    final sigma = (formasyon.aktarim + argeAktarim).clamp(0.0, 1.0);
    var havuz = 0.0;
    for (final c in droidCarpanlari) {
      havuz += ReferansCozumu.droidHavuzu * c;
    }
    // YAYLIM ARTIK DROİDİN ÇAPASINDAN DEĞİL, İÇİNE TAKILANDAN (05.4 s5).
    //
    // Droid bir taşıyıcı: boş droid vurmuyor, lazer takılmış droid takılan
    // lazerin yaylımını taşıyor. Eskiden türetilen bir çapa vardı
    // (`droidTabanHasari`) ve donanım yokken de vuruyordu; artık filo ne
    // taşıyorsa onu veriyor. Çarpan uygulanmıyor: takılan eşyanın rankı ve
    // artısı zaten kendi değerinde, droidin rankı kendi statlarında.
    return DroidGrubu(
      sayi: droidCarpanlari.length,
      tabanHasar: d(Stats.baseDamage),
      damageBonus: d(Stats.damageBonus) + sigma * gemiHasarBonusu,
      critChance:
          TasarimGirdileri.kritikSansiReferans +
          d(Stats.critChance) +
          sigma * gemiKritikSansi,
      critMultiplier:
          TasarimGirdileri.kritikCarpaniReferans +
          d(Stats.critMultiplier) +
          sigma * gemiKritikCarpani,
      // Atış aralığı referansın; droidin kendi atış hızı oran olarak böler.
      atisAraligi:
          TasarimGirdileri.referansAtisAraligi /
          Stats.fireRate.birim.uygula(1, d(Stats.fireRate)),
      // Droidin havuzu TEK: gövde canı ile kalkan aynı yere biniyor, çünkü
      // 05.4 droid havuzunu zaten "gemi havuzunun (gövde artı kalkan)" payı
      // olarak ölçüyor. Droide ayrı bir kalkan havuzu açmak, ölçülen payı
      // ikiye bölerdi.
      havuz:
          (havuz + d(Stats.maxHull) + d(Stats.maxShield)) *
          formasyon.havuzCarpani,
      armor: d(Stats.armor),
    );
  }

  /// Filodaki GEÇERLİ droidler: envanterde var ve droid tasarımı.
  static Iterable<(ItemInstance, ItemSpec)> filoEsyalari(
    List<String> filo,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue,
  ) sync* {
    for (final id in filo) {
      final instance = inventory[id];
      if (instance == null) continue;
      final spec = catalogue[instance.specId];
      if (spec == null || spec.slot != SlotType.droid) continue;
      yield (instance, spec);
    }
  }

  /// Filodaki droidlerin rank × artı çarpanları — [apply]'a giden liste.
  static List<double> droidCarpanlariOf(
    List<String> filo,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue,
  ) => [
    for (final (instance, spec) in filoEsyalari(filo, inventory, catalogue))
      spec.tier.multiplier * ItemLevels.multiplier(instance.level),
  ];

  /// Donatımdan doğrudan gemi statlarına — sunucunun ve hangarın ortak yolu.
  /// [aday] [yuva]'ya takılırsa savaş puanı ARTAR mı.
  ///
  /// Ölçüt BR ve başka bir şey olamaz: "hangisi daha iyi" sorusunun oyundaki
  /// tek cevabı o (alan 09), ve kapıların açılıp açılmadığına karar veren de
  /// aynı sayı. Burada ikinci bir "güç" ölçüsü uydurmak — eşya bütçesi, ana
  /// stat, ne olursa — arayüzün "bu daha iyi" dediği ile gemiye inenin
  /// ayrışması demekti.
  ///
  /// **Karşılaştırma TAM DONATIM üzerinden.** Tek başına bir eşyanın gücüne
  /// bakmak yanlış cevap verirdi: statlar birbirini çarpıyor (yüzdeler),
  /// yani bir parçanın değeri yanındakilere bağlı. Aday takılmış hâlin BR'si
  /// ile bugünkü BR karşılaştırılıyor.
  ///
  /// Eşitlikte `false`: aynı gücü veren bir parça için oyuncuyu depoya
  /// çağırmak, işareti değersizleştirirdi.
  static bool yukseltmeMi(
    Loadout loadout,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue,
    SlotRef yuva,
    ItemInstance aday,
  ) {
    final simdiki = CombatGlossary.battleRating(
      resolve(loadout, inventory, catalogue),
    );
    final deneme = Loadout(hullId: loadout.hullId, slots: {...loadout.slots})
      ..equip(yuva, aday.instanceId);
    return CombatGlossary.battleRating(resolve(deneme, inventory, catalogue)) >
        simdiki;
  }

  /// OTOMATİK DONATIM — savaş puanını en çok artıran dizilimi bulur.
  ///
  /// **Neden var.** Donatmak tek tek yapılan bir işti: oyuncu bir yuva
  /// seçiyor, depodan bir parça seçiyor, TAK'a basıyor — ve bunu yirmi bir
  /// yuva için tekrarlıyordu. Yirmi bir yuvalık bir gövdede bu altmış üç
  /// dokunuş demek, üstelik hangi parçanın hangi yuvada daha iyi olduğunu
  /// oyuncunun kendi hesaplaması gerekiyordu. Kararın kendisi ilginç değil:
  /// "elimdekilerin en iyisini tak" sorusunun tek bir doğru cevabı var ve o
  /// cevabı makine daha hızlı buluyor.
  ///
  /// Elle donatma KALKMIYOR — kaldırılırsa oyuncu bilerek yaptığı bir takası
  /// (kalkan yerine hız) yapamaz olur. Kalkan şu: zorunlu olmaktan çıkıyor.
  ///
  /// **Algoritma açgözlü ve bilerek öyle.** Kusursuz cevap her yuva-parça
  /// eşlemesini denemek olurdu; yuva sayısı ve envanter büyüdükçe o kombinatorik
  /// patlıyor ve bir düğmeye basıp beklemek kabul edilebilir bir şey değil.
  /// Açgözlü sürüm her adımda savaş puanını en çok artıran tek hamleyi
  /// yapıyor ve iyileşme kalmayınca duruyor. Statlar toplamsal olduğu için
  /// bu, pratikte kusursuz cevabı veriyor — ayrıştığı yer yalnız stat
  /// eşiklerinin devreye girdiği kenar durumlar.
  ///
  /// **Aday listesi kırpılıyor.** Gerçek bir depoda binlerce parça olabiliyor
  /// (ölçüldü: 5.773). Hepsini her yuva için denemek yüz binlerce
  /// [battleRating] hesabı ederdi. Bir yuva tipinin adayları önce kaba bir
  /// anahtarla (rank, sonra artı) sıralanıp en iyi birkaçı alınıyor: daha
  /// düşük ranklı ve daha az yükseltilmiş bir parçanın kazanması için
  /// üstündeki her adayın kaybetmesi gerekirdi.
  ///
  /// Dönen şey UYGULANACAK DEĞİŞİKLİKLER — yuva → örnek kimliği. Boş dönmesi
  /// "zaten en iyisi takılı" demek.
  static Map<SlotRef, String> enIyiDonanim(
    Loadout loadout,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue,
  ) {
    final hull = loadout.hull;
    final takili = loadout.slots.values.toSet();

    // Yuva tipine göre aday havuzları — takılı olanlar hariç.
    final havuz = <SlotType, List<ItemInstance>>{};
    for (final item in inventory.values) {
      if (takili.contains(item.instanceId)) continue;
      final spec = catalogue[item.specId];
      if (spec == null) continue;
      if (hull.slotCount(spec.slot) == 0) continue;
      (havuz[spec.slot] ??= []).add(item);
    }
    for (final tip in havuz.keys) {
      final liste = havuz[tip]!;
      liste.sort((a, b) {
        final ra = catalogue[a.specId]!.tier.index;
        final rb = catalogue[b.specId]!.tier.index;
        return rb != ra ? rb.compareTo(ra) : b.level.compareTo(a.level);
      });
      // Yuva sayısı kadar + birkaç yedek: bir yuvaya giren aday ötekilerden
      // düşer, o yüzden havuz yuva sayısından geniş olmalı.
      final tavan = hull.slotCount(tip) + 4;
      if (liste.length > tavan) liste.removeRange(tavan, liste.length);
    }

    final calisma = Loadout(hullId: loadout.hullId, slots: {...loadout.slots});
    final degisiklikler = <SlotRef, String>{};
    var puan = CombatGlossary.battleRating(
      resolve(calisma, inventory, catalogue),
    );

    // Her turda TEK en iyi hamle. İyileşme kalmayınca duruyor; en fazla yuva
    // sayısı kadar tur dönebiliyor, çünkü her tur bir yuvayı dolduruyor.
    for (var tur = 0; tur < hull.totalSlots; tur++) {
      SlotRef? enIyiYuva;
      ItemInstance? enIyiParca;
      var enIyiPuan = puan;

      for (final tip in havuz.keys) {
        for (var i = 0; i < hull.slotCount(tip); i++) {
          final yuva = SlotRef(tip, i);
          final oncekiKimlik = calisma.slots[yuva.id];
          for (final aday in havuz[tip]!) {
            if (degisiklikler.containsValue(aday.instanceId)) continue;
            calisma.equip(yuva, aday.instanceId);
            final yeni = CombatGlossary.battleRating(
              resolve(calisma, inventory, catalogue),
            );
            if (yeni > enIyiPuan) {
              enIyiPuan = yeni;
              enIyiYuva = yuva;
              enIyiParca = aday;
            }
            if (oncekiKimlik == null) {
              calisma.unequip(yuva);
            } else {
              calisma.equip(yuva, oncekiKimlik);
            }
          }
        }
      }

      if (enIyiYuva == null || enIyiParca == null) break;
      calisma.equip(enIyiYuva, enIyiParca.instanceId);
      degisiklikler[enIyiYuva] = enIyiParca.instanceId;
      puan = enIyiPuan;
    }
    return degisiklikler;
  }

  static ShipStats resolve(
    Loadout loadout,
    Map<String, ItemInstance> inventory,
    Map<String, ItemSpec> catalogue, {
    List<String> filo = const [],
    Map<String, List<String>> droidDonanimi = const {},
    Formasyon formasyon = Formasyon.varsayilan,
    double argeAktarim = 0,
  }) => apply(
    loadout.hull,
    vectorOf(
      loadout,
      inventory,
      catalogue,
      filo: filo,
      droidDonanimi: droidDonanimi,
    ),
    equippedLasers: equippedCount(
      loadout,
      inventory,
      catalogue,
      SlotType.laser,
    ),
    droidCarpanlari: droidCarpanlariOf(filo, inventory, catalogue),
    formasyon: formasyon,
    argeAktarim: argeAktarim,
  );
}
