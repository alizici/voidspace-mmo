import 'dart:math' as math;

import '../design/prd.dart';
import '../design/tasarim_girdileri.dart';
import 'acilis.dart';
import 'arge.dart';
import 'budget.dart';
import 'catalogue.dart';
import 'currency.dart';
import 'fatigue.dart';
import 'formasyon.dart';
import 'ganimet_cekilisi.dart';
import 'hull.dart';
import 'item.dart';
import 'kazanc.dart';
import 'ledger.dart';
import 'loadout.dart';
import 'malzeme.dart';
import 'mermi.dart';
import 'roket.dart';
import 'saglayici.dart';
import 'seviye.dart';
import 'yukseltme.dart';

/// Bir hesabın KALICI ilerlemesi.
///
/// Gemi konumu, kalkanı, canı BURADA YOK — onlar kare başına değişen savaş
/// durumu ve `Zone`'a ait. Buraya yalnız oturumlar arasında yaşaması gereken
/// şeyler giriyor: para, sahip olunan gemiler, envanter, donatım.
///
/// Ayrım keskin olmak zorunda: kare başına değişen bir şeyi kalıcı depoya
/// yazmak, veritabanını saniyede otuz kez döven bir sisteme yol açar.
class Hangar {
  Hangar({
    required this.accountId,
    // Varsayılan `null`: [startingCredits] artık türetiliyor (15.2) ve
    // türetilen bir sayı `const` olamaz, yani varsayılan parametre olamaz.
    int? credits,
    int premium = startingPremium,
    int premiumPurchased = 0,
    Fatigue? fatigue,
    int ganimetKacirma = 0,
    int xp = 0,
    List<String>? hulls,
    Map<String, ItemInstance>? inventory,
    Map<String, int>? malzemeler,
    Map<String, Loadout>? loadouts,
    String? activeHullId,
    this.haritaId,
    this.formasyonId,
    List<String>? filo,
    Map<String, List<String>>? droidDonanimi,
    Set<String>? argeDugumleri,
    Set<String>? tasarimlar,
    Set<String>? formasyonlar,
    Map<String, int>? mermi,
    String? seciliMermiId,
    Map<String, int>? roket,
    String? seciliRoketId,
  }) : fatigue = fatigue ?? Fatigue(),
       _filo = [...?filo],
       _droidDonanimi = {
         for (final e in (droidDonanimi ?? const {}).entries)
           e.key: [...e.value],
       },
       _argeDugumleri = {...?argeDugumleri},
       _tasarimlar = {...?tasarimlar},
       _formasyonlar = {...?formasyonlar},
       _mermi = {...?mermi},
       _seciliMermiId = seciliMermiId,
       _roket = {...?roket},
       _seciliRoketId = seciliRoketId,
       _ganimetPrd = PrdRoller(TasarimGirdileri.ustRankSansi)
         ..kacirmayiGeriYukle(ganimetKacirma),
       _credits = credits ?? startingCredits,
       _xp = xp,
       _premiumEarned = premium,
       _premiumPurchased = premiumPurchased,
       _hulls = {...?hulls, HullClass.starter.id},
       _inventory = {...?inventory},
       _malzemeler = {...?malzemeler},
       _loadouts = {...?loadouts},
       _activeHullId = activeHullId ?? HullClass.starter.id;

  /// Oyuncunun en son bulunduğu HARİTA — `"3:pve"` biçiminde.
  ///
  /// Opak bir dize ve bilerek: hangar bir kayıt defteri, dünya bilgisi taşıması
  /// gerekmiyor. Çözmek çağıranın işi (bkz. `Harita.byId`), ve kapının hâlâ
  /// açık olup olmadığına karar vermek de öyle — hangar "buradaydı" der,
  /// "buraya girebilir" demez.
  ///
  /// `null` ise oyuncu hiç geçitten geçmemiş ya da kayıt bu alandan eski.
  String? haritaId;

  /// Seçili droid FORMASYONU — aynı anda yalnız biri (05.9). `null` ya da
  /// tanınmayan kimlik varsayılan formasyon demek.
  String? formasyonId;

  Formasyon get formasyon => Formasyon.ofId(formasyonId);

  /// DROİD FİLOSU — gemiye değil oyuncuya bağlı (04.10). Sıralı örnek
  /// kimlikleri, en çok [TasarimGirdileri.droidFiloTavani]; gemi değişince
  /// kalıyor. Envanterden silinen droid filodan da düşüyor.
  /// KARAR 04.10 s3
  final List<String> _filo;

  List<String> get filo => List.unmodifiable(_filo);

  bool filodaMi(String instanceId) => _filo.contains(instanceId);

  /// Bu oyuncunun FİLO TAVANI — ilan edilen tavan artı ArGe izni (05.7).
  ///
  /// Tavan ilan edilen sayı (04.10) ama ArGe'nin izin dalı onu bir artırıyor:
  /// sayı değil izin — ağaç güç vermiyor, bir sınırı gevşetiyor. Hesap
  /// [ArGe.filoTavani]'nda duruyor çünkü aynı soruyu istemcinin okunur
  /// görünümü de soruyor ve iki ayrı toplama iki farklı tavan demek.
  /// KARAR 05.7 s2 · KARAR 04.10 s3
  int get filoTavani => ArGe.filoTavani(_argeDugumleri);

  /// Filoya al — yer varsa; zaten filodaysa olduğu gibi.
  bool filoyaAl(String instanceId) {
    if (_filo.contains(instanceId)) return true;
    if (_filo.length >= filoTavani) return false;
    _filo.add(instanceId);
    return true;
  }

  bool filodanCikar(String instanceId) => _filo.remove(instanceId);

  /// ALINAN ArGe DÜĞÜMLERİ (05.7).
  ///
  /// Puan seviyeden geliyor ve seviye düşmediği için harcanan puan da
  /// düşmüyor; sıfırlama bedava, o yüzden burada tutulan tek şey hangi
  /// düğümlerin açık olduğu.
  /// KARAR 05.7 s2
  final Set<String> _argeDugumleri;

  Set<String> get argeDugumleri => Set.unmodifiable(_argeDugumleri);

  void argeEkle(String id) => _argeDugumleri.add(id);

  /// Ağacı SIFIRLA — bedava ve sınırsız (05.7).
  void argeSifirla() => _argeDugumleri.clear();

  /// SAHİP OLUNAN GÖRÜNÜŞLER — tasarım ve formasyon kimlikleri (15.9).
  ///
  /// Görünüş NOVA ile alınıyor ve HESABA yazılıyor, eşyaya değil: bir
  /// tasarım alındıktan sonra oyuncunun bütün droidlerine takılabiliyor.
  /// Eşyaya bağlansaydı aynı görünüşü on kez almak gerekirdi.
  /// KARAR 15.9 s1
  final Set<String> _tasarimlar;
  final Set<String> _formasyonlar;

  Set<String> get tasarimlar => Set.unmodifiable(_tasarimlar);
  Set<String> get formasyonlar => Set.unmodifiable(_formasyonlar);

  /// Bu tasarıma sahip mi. Satın alınan iki droidin KENDİ görünüşü hep
  /// sahipli: onu alan zaten droidi almış.
  bool tasarimaSahip(String id) =>
      _tasarimlar.contains(id) ||
      id == DroidModeli.ucuz.name ||
      id == DroidModeli.elit.name;

  /// Bu formasyona sahip mi. Varsayılan hep sahipli: formasyon seçeneksiz
  /// bırakılamaz, yoksa filo dizilemez.
  bool formasyonaSahip(String id) =>
      _formasyonlar.contains(id) || id == Formasyon.varsayilan.id;

  void tasarimEkle(String id) => _tasarimlar.add(id);
  void formasyonEkle(String id) => _formasyonlar.add(id);

  /// DROİD DONANIMI — droid örneği → içine takılı eşya kimlikleri (05.4 s5).
  ///
  /// Droid artık bir taşıyıcı: standart olanda bir, elitte iki yuva ve
  /// yalnız lazer ile jeneratör giriyor. Donanım droidin KENDİSİNE bağlı,
  /// filo sırasına değil: droid filodan çıkıp geri girdiğinde içindekiler
  /// yerinde kalıyor.
  /// KARAR 05.4 s5
  final Map<String, List<String>> _droidDonanimi;

  Map<String, List<String>> get droidDonanimi => {
    for (final e in _droidDonanimi.entries) e.key: List.unmodifiable(e.value),
  };

  /// [droidId]'nin içindeki eşyalar; boşsa boş liste.
  List<String> droidinDonanimi(String droidId) =>
      List.unmodifiable(_droidDonanimi[droidId] ?? const []);

  /// Bu eşya HERHANGİ bir droidin içinde mi.
  bool droiddeMi(String instanceId) =>
      _droidDonanimi.values.any((l) => l.contains(instanceId));

  /// Eşyayı droide TAK — yer varsa. Kurallar [HangarRules.droideTak]'ta.
  bool droideTak(String droidId, String instanceId, int yuvaSayisi) {
    final liste = _droidDonanimi.putIfAbsent(droidId, () => []);
    if (liste.contains(instanceId)) return true;
    if (liste.length >= yuvaSayisi) return false;
    liste.add(instanceId);
    return true;
  }

  /// Eşyayı droidden çıkar; hangi droidde olduğunu aramak çağıranın işi
  /// değil, burada aranıyor.
  bool droidenCikar(String instanceId) {
    var bulundu = false;
    for (final liste in _droidDonanimi.values) {
      if (liste.remove(instanceId)) bulundu = true;
    }
    _droidDonanimi.removeWhere((_, l) => l.isEmpty);
    return bulundu;
  }

  /// MERMİ STOKU — kimlik → adet (17.8). Eşya değil: örneği yok, yığılıyor;
  /// gemi değişince kalıyor. MR-1 stokta durmaz: bedava ve sınırsız.
  final Map<String, int> _mermi;

  String? _seciliMermiId;

  Map<String, int> get mermiStoku => Map.unmodifiable(_mermi);

  int mermiSayisi(String id) => _mermi[id] ?? 0;

  String? get seciliMermiId => _seciliMermiId;

  /// SEÇİLİ mermi — stoğu bitmiş bir seçim MR-1'e düşer: mermi yoksa silah
  /// susmaz, bedava olana geçer.
  /// KARAR 17.8 s1
  Mermi get seciliMermi {
    final m = Mermi.byId(_seciliMermiId);
    if (m == null) return Mermi.varsayilan;
    if (!m.bedava && mermiSayisi(m.id) <= 0) return Mermi.varsayilan;
    return m;
  }

  /// Seçimi yaz — kural [HangarRules.mermiSec]'te; `null` varsayılan.
  void mermiSec(String? id) => _seciliMermiId = id;

  void mermiEkle(String id, int adet) {
    if (adet <= 0) return;
    _mermi[id] = mermiSayisi(id) + adet;
  }

  /// Mermi HARCA — namlu atışı başına bir birim; harcananı döner. Bedava
  /// mermi tükenmez; stok yetmezse kalanı harcanır, seçim sonra düşer.
  /// KARAR 17.8 s1
  int mermiHarca(String id, int adet) {
    final m = Mermi.byId(id);
    if (m == null || adet <= 0) return 0;
    if (m.bedava) return adet;
    final eldeki = mermiSayisi(id);
    final harcanan = adet < eldeki ? adet : eldeki;
    final kalan = eldeki - harcanan;
    if (kalan <= 0) {
      _mermi.remove(id);
    } else {
      _mermi[id] = kalan;
    }
    return harcanan;
  }

  // ── Roket mermisi — 17'nin ikizi (18.4) ────────────────────────────

  /// Roket STOKU: kimlik → adet. RK-1 stokta durmaz, bedava ve sınırsız.
  final Map<String, int> _roket;
  String? _seciliRoketId;

  Map<String, int> get roketStoku => Map.unmodifiable(_roket);
  int roketSayisi(String id) => _roket[id] ?? 0;
  String? get seciliRoketId => _seciliRoketId;

  /// Seçili roket; stoğu biten seçim RK-1'e düşer (18.4).
  Roket get seciliRoket {
    final r = Roket.byId(_seciliRoketId);
    if (r == null) return Roket.varsayilan;
    if (!r.bedava && roketSayisi(r.id) <= 0) return Roket.varsayilan;
    return r;
  }

  void roketSec(String? id) => _seciliRoketId = id;

  void roketEkle(String id, int adet) {
    if (adet <= 0) return;
    _roket[id] = roketSayisi(id) + adet;
  }

  /// [adet] birim harcar, harcananı döndürür; bedava roket stok yemez.
  int roketHarca(String id, int adet) {
    final r = Roket.byId(id);
    if (r == null || adet <= 0) return 0;
    if (r.bedava) return adet;
    final eldeki = roketSayisi(id);
    final harcanan = adet < eldeki ? adet : eldeki;
    final kalan = eldeki - harcanan;
    if (kalan <= 0) {
      _roket.remove(id);
    } else {
      _roket[id] = kalan;
    }
    return harcanan;
  }

  /// Yeni hesabın başlangıç parası — RAFTAN TÜRÜYOR, elle yazılmıyor.
  ///
  /// Sıfır olamaz: ilk oturumda mağazada hiçbir şey alamayan oyuncu, sistemin
  /// var olduğunu bile görmüyor. Uzun süre elle yazılmış 30.000 durdu ve
  /// gerekçesi "bir C tier lazer alacak kadar"dı; raf 15.2'nin fiyat modeline
  /// geçince o cümle yalan oldu, çünkü ilk bandın taban eşyası 94.522 kredi
  /// (borç defteri B21). Artık sayı değil ORAN ilan ediliyor: ilk bandın raf
  /// fiyatı × [TasarimGirdileri.baslangicEsyaSayisi]. Raf fiyatı 13'ün
  /// mağaza payından türediği için başlangıç kredisi de nesil bütçesiyle
  /// birlikte kayıyor; elle güncellenecek bir sayı kalmıyor.
  /// KARAR 15.8 s1
  static int get startingCredits => Kazanc.baslangicKredisi;

  /// Yeni hesabın başlangıç [Currency.premium] bakiyesi.
  ///
  /// Sıfır DEĞİL ve sebebi kredininkiyle aynı değil. Kredi başlangıçta var ki
  /// mağaza çalışsın; NOVA başlangıçta var ki oyuncu ikinci bir para
  /// biriminin VAR OLDUĞUNU görsün. Görmediği bir birimi kazanmaya
  /// çalışmıyor. Miktar kasten az: bir premium eşyanın küçük bir kısmı.
  static const int startingPremium = 500;

  /// Yeni hesabın TAKILI gelen lazeri.
  static const String starterLaser = 'pl1';

  /// Sıfırdan bir hangar: başlangıç gemisi, parası ve TAKILI bir lazer.
  ///
  /// Lazerin takılı gelmesi zorunlu, bir incelik değil: donatım savaşa
  /// girdiğinden beri boş yuva "ateş edemeyen gemi" demek. Ateş edemeyen
  /// oyuncu kredi kazanamaz, kredi kazanamayan lazer alamaz — kilitli bir
  /// başlangıç. Testlerde de tam olarak böyle yakalandı: üç dövüş testi birden
  /// "hasar inmedi" dedi.
  /// [tx] açılış bakiyesini deftere yazmak için.
  ///
  /// Başlangıç parası da bir MUSLUK: ekonomiye giren her birim kayıtlı
  /// olmalı, yoksa "toplam üretim" hiçbir zaman doğru hesaplanamaz — ve
  /// enflasyon denetiminin tamamı o toplama dayanıyor.
  factory Hangar.fresh(String accountId, TxContext tx) {
    final hangar = Hangar(accountId: accountId, credits: 0, premium: 0);
    hangar
      ..earn(
        Currency.credit,
        startingCredits,
        reason: LedgerReason.signup,
        txId: tx.id,
        atMillis: tx.atMillis,
      )
      ..earn(
        Currency.premium,
        startingPremium,
        reason: LedgerReason.signup,
        txId: '${tx.id}:p',
        atMillis: tx.atMillis,
      );
    const item = ItemInstance(
      instanceId: 'starter_laser',
      specId: starterLaser,
    );
    hangar.addItem(item);
    hangar.activeLoadout.equip(
      const SlotRef(SlotType.laser, 0),
      item.instanceId,
    );
    return hangar;
  }

  final String accountId;

  // ── CÜZDAN ─────────────────────────────────────────────────────────────
  //
  // Alanlar GİZLİ ve bu, kütüphane içi bir incelik değil kuralın kendisi:
  // bakiyeyi değiştirmenin tek yolu [spend] / [earn] / [adjust], ve üçü de
  // deftere ([_journal]) bir kayıt yazıyor. Alan açık olsaydı `credits += x`
  // yazan her satır defterin dışında kalırdı — ve defterin dışında kalan tek
  // bir hareket, defteri kanıt olmaktan çıkarır.

  int _credits;

  /// OYNAYARAK kazanılan kıt para.
  int _premiumEarned;

  /// GERÇEK PARAYLA alınan kıt para.
  ///
  /// **Neden ayrı duruyor.** Ters ibrazda (chargeback) geri alınması gereken
  /// şey satın alınandır; kazanılan değil. Birleşik bir bakiyede hangisinin
  /// hangisi olduğu bilinemez ve oyuncunun oynayarak kazandığı NOVA, birinin
  /// kartını iptal etmesi yüzünden silinir.
  int _premiumPurchased;

  int get credits => _credits;

  /// XP — öldürmeden kazanılan ÖMÜR BOYU kredi, yorgunluk sonrası.
  ///
  /// Ayrı bir kaynak değil, ayrı bir SAYAÇ: harcanan para geri alınmaz,
  /// seviye düşmez. Seviye XP'nin karşıladığı rank ([Seviye]).
  /// KARAR 10.1 s1
  int _xp;

  int get xp => _xp;

  /// İçeriğe kapı — asla geri gitmez.
  int get seviye => Seviye.of(_xp);

  void xpEkle(int miktar) {
    if (miktar > 0) _xp += miktar;
  }

  /// Toplam kıt para — oyuncunun gördüğü sayı.
  int get premium => _premiumEarned + _premiumPurchased;

  int get premiumEarned => _premiumEarned;
  int get premiumPurchased => _premiumPurchased;

  /// [currency] cinsinden bakiye.
  int balanceOf(Currency currency) => switch (currency) {
    Currency.credit => _credits,
    Currency.premium => premium,
  };

  /// Farm sınırı — bkz. [Fatigue]. Hesapla birlikte diske yazılıyor:
  /// sunucu yeniden başlayınca sıfırlanan bir sınır, sınır değildir.
  final Fatigue fatigue;

  /// ÜST RANK acıma sayacı — hesabın kendi serisi.
  ///
  /// Kalıcı olmak ZORUNDA: PRD'nin tek işi kuru seriyi kırmak, ve seri
  /// oturumlardan uzun. Oturumda sıfırlansaydı her giriş oyuncuyu en düşük
  /// şansa geri atardı — yani acıma sistemi, en çok ihtiyaç duyulduğu anda
  /// tam olarak hiçbir şey yapmazdı.
  ///
  /// [Fatigue] ile aynı gerekçe, aynı yer: ikisi de hesabın oyun boyunca
  /// taşıdığı sayaçlar.
  final PrdRoller _ganimetPrd;

  PrdRoller get ganimetPrd => _ganimetPrd;

  /// Deftere yazılmış ama HENÜZ KALICI HÂLE GETİRİLMEMİŞ hareketler.
  ///
  /// Sunucu bunu boşaltıp diske yazıyor. Boşaltmayı unutan bir yol, listeyi
  /// büyütür — yani hata sessiz kalmaz. `economy_test.dart` her para
  /// hareketinin deftere düştüğünü buradan doğruluyor.
  final List<LedgerEntry> _journal = [];

  /// Defteri boşaltıp döndürür.
  List<LedgerEntry> takeJournal() {
    if (_journal.isEmpty) return const [];
    final out = List<LedgerEntry>.of(_journal);
    _journal.clear();
    return out;
  }

  /// Boşaltılmamış kayıt sayısı — testler ve teşhis için.
  int get pendingLedgerEntries => _journal.length;

  /// [currency] bakiyesinden [amount] düş.
  ///
  /// Yetmezse `false` döner ve HİÇBİR ŞEY değişmez — ne bakiye ne defter.
  /// Kısmi düşüm, oyuncunun parasını yiyen türden bir hata olurdu.
  ///
  /// Kıt parada ÖNCE KAZANILAN harcanıyor. Sebep ters ibraz: satın alınan
  /// birim cüzdanda ne kadar uzun kalırsa, iade gerektiğinde geri alınacak
  /// bakiye o kadar sağlam olur.
  bool spend(
    Currency currency,
    int amount, {
    required LedgerReason reason,
    required String txId,
    required int atMillis,
    String? detail,
  }) {
    if (amount < 0 || balanceOf(currency) < amount) return false;
    switch (currency) {
      case Currency.credit:
        _credits -= amount;
      case Currency.premium:
        final fromEarned = amount < _premiumEarned ? amount : _premiumEarned;
        _premiumEarned -= fromEarned;
        _premiumPurchased -= amount - fromEarned;
    }
    _record(currency, -amount, reason, txId, atMillis, detail);
    return true;
  }

  /// [currency] bakiyesine [amount] ekle — OYNAYARAK kazanılan.
  ///
  /// Eksi miktar yok sayılıyor: ödül yolundan gelen bir eksi, ekonomiyi ters
  /// yönde besler. Geri alma için [adjust] var ve o eksiye inebiliyor.
  void earn(
    Currency currency,
    int amount, {
    required LedgerReason reason,
    required String txId,
    required int atMillis,
    String? detail,
  }) {
    if (amount <= 0) return;
    switch (currency) {
      case Currency.credit:
        _credits += amount;
      case Currency.premium:
        _premiumEarned += amount;
    }
    _record(currency, amount, reason, txId, atMillis, detail);
  }

  /// Gerçek parayla alınan birimi yükler.
  void topUp(
    int amount, {
    required String txId,
    required int atMillis,
    String? detail,
  }) {
    if (amount <= 0) return;
    _premiumPurchased += amount;
    _record(
      Currency.premium,
      amount,
      LedgerReason.topUp,
      txId,
      atMillis,
      detail,
    );
  }

  /// EKSİYE İNEBİLEN düzeltme — ters ibraz, iade, açık kapatma.
  ///
  /// [earn] ile aynı şey değil ve olmamalı: orada eksi yutuluyor (kaza
  /// korumasi), burada eksi işin kendisi. Gerçek sistemler de böyle yapıyor —
  /// kullanılmış bir birimin ters ibrazında bakiye eksiye düşebilir ve oyuncu
  /// yeniden satın alana kadar öyle kalır.
  ///
  /// Kıt parada önce SATIN ALINAN geri alınıyor: iade edilen şey odur.
  void adjust(
    Currency currency,
    int delta, {
    required LedgerReason reason,
    required String txId,
    required int atMillis,
    String? detail,
  }) {
    if (delta == 0) return;
    switch (currency) {
      case Currency.credit:
        _credits += delta;
      case Currency.premium:
        if (delta > 0) {
          _premiumPurchased += delta;
        } else {
          final take = -delta;
          final fromPurchased = take < _premiumPurchased
              ? take
              : _premiumPurchased;
          _premiumPurchased -= fromPurchased;
          _premiumEarned -= take - fromPurchased;
        }
    }
    _record(currency, delta, reason, txId, atMillis, detail);
  }

  /// [spend]'in kısa hâli — sebep ve kimlik bağlamdan.
  ///
  /// Üretim yolu tam imzayı kullanıyor; bu, sebebin ayrı bir düşünce olduğu
  /// yerler (test, tek adımlı işlem) için.
  bool spendFor(
    Currency currency,
    int amount,
    TxContext tx, {
    LedgerReason reason = LedgerReason.purchase,
    String? detail,
  }) => spend(
    currency,
    amount,
    reason: reason,
    txId: tx.id,
    atMillis: tx.atMillis,
    detail: detail,
  );

  /// [earn]'ün kısa hâli.
  void earnFrom(
    Currency currency,
    int amount,
    TxContext tx, {
    LedgerReason reason = LedgerReason.kill,
    String? detail,
  }) => earn(
    currency,
    amount,
    reason: reason,
    txId: tx.id,
    atMillis: tx.atMillis,
    detail: detail,
  );

  void _record(
    Currency currency,
    int delta,
    LedgerReason reason,
    String txId,
    int atMillis,
    String? detail,
  ) => _journal.add(
    LedgerEntry(
      id: txId,
      accountId: accountId,
      currency: currency,
      delta: delta,
      balanceAfter: balanceOf(currency),
      reason: reason,
      atMillis: atMillis,
      detail: detail,
    ),
  );

  final Set<String> _hulls;
  final Map<String, ItemInstance> _inventory;

  /// MALZEME envanteri — kimlik → adet.
  ///
  /// Eşyalardan AYRI bir kap ve bu şemanın gereği: malzemenin örneği yok,
  /// yığılabilir ve birbirinin aynısı (alan 06). Aynı haritada tutmak, her
  /// malzeme için sahte bir [ItemInstance] üretmek demekti — ve o an
  /// malzemenin artısı, alt statı, kalitesi olabilir hâle gelirdi.
  final Map<String, int> _malzemeler;
  final Map<String, Loadout> _loadouts;
  String _activeHullId;

  Set<String> get hulls => Set.unmodifiable(_hulls);
  Map<String, ItemInstance> get inventory => Map.unmodifiable(_inventory);

  Map<String, int> get malzemeler => Map.unmodifiable(_malzemeler);

  /// [malzeme] stoğu.
  int malzemeSayisi(Malzeme malzeme) => _malzemeler[malzeme.id] ?? 0;

  /// Stoğa ekle. [adet] eksi olabilir — harcama da aynı kapıdan geçiyor.
  ///
  /// Sıfıra düşen kayıt SİLİNİYOR: kalsaydı envanter, oyuncunun bir zamanlar
  /// dokunduğu her malzemeyi sonsuza kadar taşırdı ve kayıt dosyası oyun
  /// süresiyle büyürdü.
  void malzemeEkle(Malzeme malzeme, int adet) {
    final yeni = malzemeSayisi(malzeme) + adet;
    if (yeni <= 0) {
      _malzemeler.remove(malzeme.id);
    } else {
      _malzemeler[malzeme.id] = yeni;
    }
  }

  String get activeHullId => _activeHullId;

  HullClass get activeHull =>
      HullClass.byId(_activeHullId) ?? HullClass.starter;

  /// Etkin geminin donatımı. Yoksa boş bir tane kurulur.
  Loadout get activeLoadout =>
      _loadouts[_activeHullId] ??= Loadout(hullId: _activeHullId);

  Loadout loadoutFor(String hullId) =>
      _loadouts[hullId] ??= Loadout(hullId: hullId);

  bool owns(String hullId) => _hulls.contains(hullId);

  void addItem(ItemInstance item) => _inventory[item.instanceId] = item;

  /// Eşyayı envanterden çıkar — parçalama ve sentez tüketiyor. Filodan da
  /// düşüyor: olmayan bir droid uçamaz.
  void removeItem(String instanceId) {
    _inventory.remove(instanceId);
    _filo.remove(instanceId);
    // Silinen eşya bir droidin İÇİNDEYSE oradan da düşüyor; silinen DROİD
    // ise içindekiler envanterde kalıyor, yalnız bağ kopuyor (05.4 s5).
    droidenCikar(instanceId);
    _droidDonanimi.remove(instanceId);
  }

  ItemInstance? itemOf(String instanceId) => _inventory[instanceId];

  /// FİLOYU AŞINDIR — ana gemi bir kez öldü (05.10).
  ///
  /// Yalnız FİLODAKİ droidler aşınıyor: hangarda bekleyen yedek droid
  /// yıpranmıyor, çünkü o dövüşte değildi. Sıfıra düşen droid yok oluyor ve
  /// envanterden siliniyor; geri dönen liste yok olanların kimliği, çağıran
  /// oyuncuya haber versin diye.
  ///
  /// Bir ölüm bir çağrı: sayaç zamanla değil OLAYLA iniyor, o yüzden
  /// çağrının tekrarı da tekrar aşındırıyor. Sunucu bu yüzden ölüm anını
  /// bir kez okuyor ([Zone.deaths]).
  /// KARAR 05.10 s1
  List<String> filoyuAsindir({int puan = TasarimGirdileri.droidAsinmaPayi}) {
    final yokOlanlar = <String>[];
    for (final id in [..._filo]) {
      final droid = _inventory[id];
      if (droid == null) continue;
      final kalan = droid.dayaniklilik - puan;
      if (kalan <= 0) {
        yokOlanlar.add(id);
        removeItem(id);
        continue;
      }
      _inventory[id] = droid.copyWith(dayaniklilik: kalan);
    }
    return yokOlanlar;
  }

  /// Etkin gemiyi değiştir. Sahip olunmayan gemiye geçilemez.
  bool selectHull(String hullId) {
    if (!_hulls.contains(hullId)) return false;
    _activeHullId = hullId;
    return true;
  }

  void grantHull(String hullId) => _hulls.add(hullId);

  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'credits': _credits,
    // Sıfırken yazılmıyor: eski kayıtların biçimi değişmesin.
    if (_xp > 0) 'xp': _xp,
    'premium': _premiumEarned,
    'premiumPurchased': _premiumPurchased,
    'fatigue': fatigue.toJson(),
    'ganimetKacirma': _ganimetPrd.misses,
    'hulls': _hulls.toList(),
    'activeHullId': _activeHullId,
    'inventory': {for (final e in _inventory.entries) e.key: e.value.toJson()},
    'malzemeler': {..._malzemeler},
    'loadouts': {for (final e in _loadouts.entries) e.key: e.value.toJson()},
    if (haritaId != null) 'haritaId': haritaId,
    if (formasyonId != null) 'formasyonId': formasyonId,
    if (_filo.isNotEmpty) 'filo': [..._filo],
    if (_argeDugumleri.isNotEmpty) 'argeDugumleri': [..._argeDugumleri],
    if (_tasarimlar.isNotEmpty) 'tasarimlar': [..._tasarimlar],
    if (_formasyonlar.isNotEmpty) 'formasyonlar': [..._formasyonlar],
    if (_droidDonanimi.isNotEmpty)
      'droidDonanimi': {
        for (final e in _droidDonanimi.entries) e.key: [...e.value],
      },
    if (_mermi.isNotEmpty) 'mermi': {..._mermi},
    if (_seciliMermiId != null) 'seciliMermi': _seciliMermiId,
    if (_roket.isNotEmpty) 'roket': {..._roket},
    if (_seciliRoketId != null) 'seciliRoket': _seciliRoketId,
  };

  static Hangar fromJson(Map<String, Object?> json) {
    final hangar = _fromJson(json);
    _altStatGocu(hangar);
    _droidKapasiteGocu(hangar);
    return hangar;
  }

  /// ESKİ kayıt: kapasitesini aşan droidin fazlasını oyuncuya GERİ VERİR.
  ///
  /// Yuva sayısı takarken sınanıyor, yani kayda kapasiteyi aşan bir liste
  /// hiç girmemeli. Girdiği tek yol kapasitenin SONRADAN değişmesi — ve
  /// değişti: merdivenden gelen droidler elit sayılmaktan çıkıp tek yuvaya
  /// indi (05.4 s5). O günden önce iki eşya takılmış her droid, kaydında
  /// hâlâ ikisini taşıyor.
  ///
  /// Fazlası SİLİNMİYOR, yalnız droidden çıkıyor: eşya oyuncunun malı ve
  /// envanterde duruyor, buradaki liste ona yalnız bir referans. Silmek,
  /// bir kural değişikliğinin bedelini oyuncunun envanterinden ödetmek
  /// olurdu.
  ///
  /// Çözüm tarafı da ayrıca kelepçeli ([LoadoutResolver.vectorOf]): göç
  /// çalışmasa bile fazla eşya güç vermiyor. İkisi birden var çünkü ikisi
  /// ayrı şeyi düzeltiyor — biri kaydı, öteki hesabı.
  /// KARAR 05.4 s5
  static void _droidKapasiteGocu(Hangar hangar) {
    for (final droidId in hangar.droidDonanimi.keys.toList()) {
      final droid = hangar.itemOf(droidId);
      final spec = droid == null ? null : Catalogue.byId[droid.specId];
      // Droidi katalogdan düşmüşse taşıdığı da yetim: hepsi geri veriliyor.
      final tavan = spec == null ? 0 : Saglayici.droidYuvaSayisi(spec);
      final liste = hangar.droidinDonanimi(droidId);
      if (liste.length <= tavan) continue;
      for (final fazla in liste.skip(tavan)) {
        hangar.droidenCikar(fazla);
      }
    }
  }

  /// ESKİ kayıt: mutlak alt stat değerlerini o anki gövdeyle role çevirir.
  ///
  /// Değer çevirme anındaki gövdenin katsayısını taşıyordu ve gövde
  /// değişince donuyordu (borç defteri B3). Rol = değer ÷ bugünkü taban,
  /// banda kelepçeli; canlı oyuncu yok, geliştirme kayıtları en iyi tahminle
  /// taşınıyor. Taşınan kayıt bir daha bu yoldan geçmiyor: yeni biçim rolü
  /// yazıyor, eski anahtarı yazmıyor.
  static void _altStatGocu(Hangar hangar) {
    final hull = HullClass.byId(hangar.activeHullId) ?? HullClass.starter;
    for (final item in hangar.inventory.values.toList()) {
      if (item.eskiAltStatlar.isEmpty || item.altStatRolleri.isNotEmpty) {
        continue;
      }
      final spec = Catalogue.byId[item.specId];
      if (spec == null) continue;
      final roller = <String, double>{};
      for (final e in item.eskiAltStatlar.entries) {
        final taban = ItemBudget.altStatTabani(
          spec,
          item.level,
          hull,
          e.key,
          item.instanceId,
        );
        if (taban == null || taban <= 0) continue;
        roller[e.key] = (e.value / taban).clamp(0.0, 1.0);
      }
      if (roller.isEmpty) continue;
      hangar.addItem(item.copyWith(altStatRolleri: roller));
    }
  }

  static Hangar _fromJson(Map<String, Object?> json) => Hangar(
    accountId: json['accountId']! as String,
    credits: (json['credits'] as num?)?.toInt() ?? startingCredits,
    // Seviye sistemi sonradan geldi: alan yoksa sıfır, oyuncu ilk seviyede.
    xp: (json['xp'] as num?)?.toInt() ?? 0,
    // Eski kayıtlarda alan YOK ve olmaması normal: ikinci birim sonradan
    // geldi. Varsayılan başlangıç bakiyesi, çünkü sıfır vermek eski
    // oyuncuları yeni oyunculardan geride bırakırdı.
    premium: (json['premium'] as num?)?.toInt() ?? startingPremium,
    premiumPurchased: (json['premiumPurchased'] as num?)?.toInt() ?? 0,
    fatigue: Fatigue.fromJson(json['fatigue'] as Map<String, Object?>?),
    ganimetKacirma: (json['ganimetKacirma'] as num?)?.toInt() ?? 0,
    hulls: [for (final h in (json['hulls'] as List? ?? [])) h as String],
    activeHullId: json['activeHullId'] as String?,
    inventory: {
      for (final e in (json['inventory'] as Map? ?? {}).entries)
        e.key as String: ItemInstance.fromJson(
          (e.value as Map).cast<String, Object?>(),
        ),
    },
    // Alan YOKSA boş: malzeme şeması eşya envanterinden SONRA geldi ve o
    // günden önce kaydedilmiş her hangar bu alanı taşımıyor.
    malzemeler: {
      for (final e in (json['malzemeler'] as Map? ?? {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    loadouts: {
      for (final e in (json['loadouts'] as Map? ?? {}).entries)
        e.key as String: Loadout.fromJson(
          (e.value as Map).cast<String, Object?>(),
        ),
    },
    // Eski kayıtlarda alan YOK: geçit sistemi sonradan geldi. `null` "bilmiyoruz"
    // demek ve başlangıca düşmek doğru cevap — yanlış bir haritaya koymaktan iyi.
    haritaId: json['haritaId'] as String?,
    formasyonId: json['formasyonId'] as String?,
    filo: [for (final id in (json['filo'] as List? ?? const [])) id as String],
    droidDonanimi: {
      for (final e in (json['droidDonanimi'] as Map? ?? const {}).entries)
        e.key as String: [for (final v in e.value as List) v as String],
    },
    argeDugumleri: {
      for (final v in (json['argeDugumleri'] as List? ?? const []))
        v as String,
    },
    tasarimlar: {
      for (final v in (json['tasarimlar'] as List? ?? const [])) v as String,
    },
    formasyonlar: {
      for (final v in (json['formasyonlar'] as List? ?? const [])) v as String,
    },
    mermi: {
      for (final e in (json['mermi'] as Map? ?? {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    seciliMermiId: json['seciliMermi'] as String?,
    roket: {
      for (final e in (json['roket'] as Map? ?? {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    seciliRoketId: json['seciliRoket'] as String?,
  );
}

/// Hangar işlemlerinin sonucu.
///
/// `bool` yerine sebep döndürüyor: "takılamadı" bir hata mesajı değil, arayüzün
/// oyuncuya göstereceği cümle. Sunucunun reddettiği her işlemin oyuncunun
/// anlayacağı bir karşılığı olmalı.
enum HangarError {
  notFound,
  notOwned,
  wrongSlot,
  noSuchSlot,
  notEnoughCredits,
  alreadyOwned,
  maxLevel,

  /// Yükseltmenin RANK KAPISI kapalı: kredi yetiyor, malzeme yetmiyor.
  ///
  /// `notEnoughCredits`ten ayrı ve ayrı olması şart: oyuncuya "paran yetmiyor"
  /// demek yanlış yönlendirme olurdu — eksik olan para değil, o rankın
  /// içeriğinde geçirilmiş zaman.
  notEnoughMaterials,

  /// Takılı eşya parçalanamaz ya da sentezlenemez.
  equipped,

  /// Sentez için yeterli sayıda AYNI RANK eşya yok.
  notEnoughItems,

  /// Sentez merdivenin tepesinde: çıkılacak üst rank yok.
  atTopRank,

  /// Gövde TANIMLI ama satışta değil.
  ///
  /// `notFound`dan ayrı: gemi var, merdivenden türetildi, statları belli — ama
  /// ona uygun içerik (harita kademesi, yaratık kademesi) yok. İki hatayı
  /// birleştirmek, oyuncuya "böyle bir gemi yok" demek olurdu; oysa doğrusu
  /// "henüz alınamıyor".
  notPurchasable,

  /// Droid filosu DOLU: tavan oyuncu başına, gövdeye değil (04.10).
  filoDolu,

  /// Bu mermiden STOK yok: önce mağazadan alınır (17.8).
  mermiYok,

  /// Seçilen roketten stok yok (18.4).
  roketYok,

  /// NOVA yetmiyor — droid onarımı (05.10).
  ///
  /// [notEnoughCredits]'ten ayrı: eksik olan kredi değil kıt para. İkisini
  /// tek mesajda toplamak oyuncuya yanlış kasayı işaret etmek olurdu.
  novaYok,

  /// Sistem henüz AÇIK değil: açılış sırası ranka bağlı (karar 10.7).
  ///
  /// Para ya da malzeme hatası değil; oyuncuya "önce şu rankın eşyasını gör"
  /// demenin karşılığı.
  kilitli,
}

extension HangarErrorMessage on HangarError {
  String get message => switch (this) {
    HangarError.notPurchasable => 'Bu gemi henüz satışta değil',
    HangarError.kilitli => 'Bu sistem henüz açık değil',
    HangarError.filoDolu => 'Droid filosu dolu',
    HangarError.mermiYok => 'Bu mermiden yok',
    HangarError.roketYok => 'Bu roketten yok',
    HangarError.novaYok => 'Yeterli NOVA yok',
    HangarError.notFound => 'Eşya bulunamadı',
    HangarError.notOwned => 'Bu eşya sende yok',
    HangarError.wrongSlot => 'Bu eşya o yuvaya girmiyor',
    HangarError.noSuchSlot => 'Bu gemide öyle bir yuva yok',
    HangarError.notEnoughCredits => 'Yeterli paran yok',
    HangarError.alreadyOwned => 'Zaten sahipsin',
    HangarError.maxLevel => 'Bu eşya son seviyede',
    // "Paran yetmiyor" DEMİYOR ve dememeli: eksik olan para değil, o rankın
    // içeriğinde geçirilmiş zaman.
    HangarError.notEnoughMaterials => 'Bu rankın malzemesi yetmiyor',
    HangarError.equipped => 'Takılı eşya için önce çıkar',
    HangarError.notEnoughItems => 'Aynı ranktan yeterli eşya yok',
    HangarError.atTopRank => 'Merdivenin tepesi — üstü yok',
  };
}

/// Hangar kuralları — **otorite bunları sunucuda koşturuyor**.
///
/// İstemci aynı kodu hangar ekranında önizleme için kullanıyor, ama kararı
/// veren orası değil. Ortak pakette olmasının sebebi tam olarak bu: iki ayrı
/// uygulama, hangarda gösterilen ile sunucunun kabul ettiği arasında sessiz
/// ayrışma demekti.
abstract final class HangarRules {
  /// Eşyayı yuvaya tak.
  /// KARAR 04.2 s1
  static HangarError? equip(Hangar hangar, SlotRef slot, String instanceId) {
    final item = hangar.itemOf(instanceId);
    if (item == null) return HangarError.notOwned;
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return HangarError.notFound;

    final loadout = hangar.activeLoadout;
    if (!loadout.hasSlot(slot)) return HangarError.noSuchSlot;
    if (spec.slot != slot.type) return HangarError.wrongSlot;

    // Aynı eşya iki yuvada olamaz: olsaydı tek bir lazeri bütün yuvalara
    // takmak bedava güç olurdu.
    final existing = loadout.slotOf(instanceId);
    if (existing != null) loadout.unequip(existing);

    loadout.equip(slot, instanceId);
    return null;
  }

  /// MERMİ AL — yalnız kredi, adetle. MR-1 satılmaz: bedava ve sınırsız
  /// (17.2). NOVA yolu yok; kilit 17.7'de.
  /// KARAR 17.2 s1 · KARAR 17.7 s1
  static HangarError? mermiAl(
    Hangar hangar,
    String mermiId,
    int adet,
    TxContext tx,
  ) {
    if (adet <= 0) return HangarError.notFound;
    final mermi = Mermi.byId(mermiId);
    if (mermi == null) return HangarError.notFound;
    if (mermi.bedava) return HangarError.notPurchasable;
    if (!hangar.spend(
      Currency.credit,
      mermi.fiyatFor(adet),
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: mermiId,
    )) {
      return HangarError.notEnoughCredits;
    }
    hangar.mermiEkle(mermiId, adet);
    return null;
  }

  /// MERMİ SEÇ — stokta olmalı; MR-1 her zaman. Seçim anında gemiye geçer,
  /// sunucu yaylım başına okuyor (17.8).
  /// KARAR 17.8 s1
  static HangarError? mermiSec(Hangar hangar, String mermiId) {
    final mermi = Mermi.byId(mermiId);
    if (mermi == null) return HangarError.notFound;
    if (!mermi.bedava && hangar.mermiSayisi(mermiId) <= 0) {
      return HangarError.mermiYok;
    }
    hangar.mermiSec(mermiId);
    return null;
  }

  /// Roket mermisi al — krediyle, RK-1 satılmıyor (18.3, 18.5).
  /// KARAR 18.3 s1
  static HangarError? roketAl(
    Hangar hangar,
    String roketId,
    int adet,
    TxContext tx,
  ) {
    if (adet <= 0) return HangarError.notFound;
    final roket = Roket.byId(roketId);
    if (roket == null) return HangarError.notFound;
    if (roket.bedava) return HangarError.notPurchasable;
    if (!hangar.spend(
      Currency.credit,
      roket.fiyatFor(adet),
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: roketId,
    )) {
      return HangarError.notEnoughCredits;
    }
    hangar.roketEkle(roketId, adet);
    return null;
  }

  /// Roket seç — stoksuz seçilemez (18.4).
  /// KARAR 18.4 s1
  static HangarError? roketSec(Hangar hangar, String roketId) {
    final roket = Roket.byId(roketId);
    if (roket == null) return HangarError.notFound;
    if (!roket.bedava && hangar.roketSayisi(roketId) <= 0) {
      return HangarError.roketYok;
    }
    hangar.roketSec(roketId);
    return null;
  }

  /// Droidi FİLOYA al — gövdeden bağımsız, en çok filo tavanı kadar.
  ///
  /// Açılış sırası (10.7): droid üçüncü rankta. Takılı bir eşya gibi: filodaki
  /// droid parçalanamaz ve sentezlenemez ([HangarError.equipped]), önce
  /// çıkarılır.
  /// KARAR 04.10 s3 · KARAR 05.8 s2
  static HangarError? filoyaAl(Hangar hangar, String instanceId) {
    final item = hangar.itemOf(instanceId);
    if (item == null) return HangarError.notOwned;
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return HangarError.notFound;
    if (spec.slot != SlotType.droid) return HangarError.wrongSlot;
    if (!Acilis.acik(Sistem.droid, hangar)) return HangarError.kilitli;
    return hangar.filoyaAl(instanceId) ? null : HangarError.filoDolu;
  }

  static HangarError? filodanCikar(Hangar hangar, String instanceId) =>
      hangar.filodanCikar(instanceId) ? null : HangarError.notFound;

  /// Eşyayı DROİDE tak (05.4 s5).
  ///
  /// Dört kapı: eşya ve droid var mı, eşya droide girebilen bir tip mi
  /// (lazer ya da jeneratör), eşya başka bir yerde takılı mı (gemide ya da
  /// başka droidde), droidin boş yuvası var mı. Beşincisi yok: droidin
  /// filoda olması ŞART DEĞİL — hangarda bekleyen droid de donatılabiliyor,
  /// yoksa oyuncu her donatım için droidi filoya alıp çıkarırdı.
  /// KARAR 05.4 s5
  static HangarError? droideTak(
    Hangar hangar,
    String droidId,
    String instanceId,
  ) {
    final droid = hangar.itemOf(droidId);
    final item = hangar.itemOf(instanceId);
    if (droid == null || item == null) return HangarError.notOwned;
    final droidSpec = Catalogue.byId[droid.specId];
    final spec = Catalogue.byId[item.specId];
    if (droidSpec == null || spec == null) return HangarError.notFound;
    if (droidSpec.slot != SlotType.droid) return HangarError.wrongSlot;
    if (!Saglayici.droidDonanimTipleri.contains(spec.slot)) {
      return HangarError.wrongSlot;
    }
    if (hangar.activeLoadout.slots.containsValue(instanceId)) {
      return HangarError.equipped;
    }
    if (hangar.droiddeMi(instanceId)) return HangarError.equipped;
    if (!Acilis.acik(Sistem.droid, hangar)) return HangarError.kilitli;
    return hangar.droideTak(
      droidId,
      instanceId,
      Catalogue.droidYuvaSayisi(droidSpec),
    )
        ? null
        : HangarError.filoDolu;
  }

  /// Eşyayı droidden çıkar.
  /// KARAR 05.4 s5
  static HangarError? droidenCikar(Hangar hangar, String instanceId) =>
      hangar.droidenCikar(instanceId) ? null : HangarError.notFound;

  /// Droidi ONAR — dayanıklılığı NOVA ile tam sayaca döndürür (05.10).
  ///
  /// Kısmi onarım yok: eksik puanın tamamı bir işlemde kapanıyor. Parça
  /// parça onarım aynı toplamı ödetip oyuncuya ek bir karar yaratırdı ve o
  /// karar hep aynı: elde NOVA varsa onar.
  ///
  /// Filodaki droid de onarılıyor, envanterdeki de: aşınma dövüşten geliyor
  /// ama onarım hangarda, ve filodan çıkarıp onarmaya zorlamak yalnız fazla
  /// tıklama olurdu.
  /// KARAR 05.10 s1 · KARAR 15.3 s3
  static HangarError? droidOnar(
    Hangar hangar,
    String instanceId,
    TxContext tx,
  ) {
    final item = hangar.itemOf(instanceId);
    if (item == null) return HangarError.notOwned;
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return HangarError.notFound;
    if (spec.slot != SlotType.droid) return HangarError.wrongSlot;
    // Zaten tam: hata değil, iş de değil. Sunucuya boşuna gelen bir tık
    // oyuncuya kırmızı mesaj göstermemeli.
    if (!item.asinmis) return null;
    final fiyat = Kazanc.droidOnarimNovaFor(
      spec.tier,
      level: item.level,
      puan: ItemInstance.tamDayaniklilik - item.dayaniklilik,
    );
    if (!hangar.spend(
      Currency.premium,
      fiyat,
      reason: LedgerReason.repair,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: instanceId,
    )) {
      return HangarError.novaYok;
    }
    hangar.addItem(item.copyWith(dayaniklilik: ItemInstance.tamDayaniklilik));
    return null;
  }

  /// ArGe DÜĞÜMÜ AL — puan seviyeden, önkoşul zincirden (05.7).
  ///
  /// Para YOK: ArGe kredi ya da NOVA istemiyor, seviye istiyor. Paraya
  /// bağlansaydı ağaç ikinci bir mağaza olurdu ve 15'in yasak listesi
  /// yeniden açılırdı.
  /// KARAR 05.7 s2
  static HangarError? argeAl(Hangar hangar, String dugumId) {
    final dugum = ArGe.byId[dugumId];
    if (dugum == null) return HangarError.notFound;
    if (hangar.argeDugumleri.contains(dugumId)) return null;
    if (dugum.onkosul != null &&
        !hangar.argeDugumleri.contains(dugum.onkosul)) {
      return HangarError.kilitli;
    }
    if (!ArGe.alinabilir(hangar.argeDugumleri, dugumId, hangar.seviye)) {
      // Önkoşul tamam ama puan yetmiyor: eksik olan para değil SEVİYE.
      return HangarError.notEnoughMaterials;
    }
    hangar.argeEkle(dugumId);
    return null;
  }

  /// Ağacı sıfırla — bedava ve sınırsız (05.7).
  /// KARAR 05.7 s2
  static HangarError? argeSifirla(Hangar hangar) {
    hangar.argeSifirla();
    return null;
  }

  /// GÖRÜNÜŞ satın al — tasarım ya da formasyon, NOVA ile (15.9).
  ///
  /// Sahip olunan bir görünüşü ikinci kez almak hata DEĞİL, işlemsiz: iki
  /// kez basılan bir düğmenin oyuncuya iki kez ödetmesi kabul edilemez.
  /// KARAR 15.9 s1
  static HangarError? gorunusAl(
    Hangar hangar,
    GorunusKalemi kalem,
    String id,
    TxContext tx,
  ) {
    final gecerli = switch (kalem) {
      GorunusKalemi.tasarim => DroidModeli.values.any((m) => m.name == id),
      GorunusKalemi.formasyon => Formasyon.byId(id) != null,
    };
    if (!gecerli) return HangarError.notFound;
    final sahip = switch (kalem) {
      GorunusKalemi.tasarim => hangar.tasarimaSahip(id),
      GorunusKalemi.formasyon => hangar.formasyonaSahip(id),
    };
    if (sahip) return null;
    if (!hangar.spend(
      Currency.premium,
      Kazanc.gorunusFiyati(kalem),
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: id,
    )) {
      return HangarError.novaYok;
    }
    switch (kalem) {
      case GorunusKalemi.tasarim:
        hangar.tasarimEkle(id);
      case GorunusKalemi.formasyon:
        hangar.formasyonEkle(id);
    }
    return null;
  }

  /// Droide TASARIM giydir — sahip olunan bir çizim (15.9).
  ///
  /// Seçim örneğe yazılıyor: aynı oyuncunun iki droidi iki ayrı tasarım
  /// giyebiliyor. Sahip olunmayan tasarım seçilemiyor; sunucu reddediyor,
  /// istemci zaten göstermiyor.
  /// KARAR 15.9 s1
  static HangarError? droidTasarimSec(
    Hangar hangar,
    String droidId,
    String tasarimId,
  ) {
    final droid = hangar.itemOf(droidId);
    if (droid == null) return HangarError.notOwned;
    final spec = Catalogue.byId[droid.specId];
    if (spec == null || spec.slot != SlotType.droid) {
      return HangarError.wrongSlot;
    }
    if (!DroidModeli.values.any((m) => m.name == tasarimId)) {
      return HangarError.notFound;
    }
    if (!hangar.tasarimaSahip(tasarimId)) return HangarError.notPurchasable;
    hangar.addItem(droid.copyWith(tasarim: tasarimId));
    return null;
  }

  /// FORMASYON seç — aynı anda yalnız biri; bedava ve her an değişir.
  /// KARAR 05.9 s1
  static HangarError? formasyonSec(Hangar hangar, String id) {
    if (Formasyon.byId(id) == null) return HangarError.notFound;
    // Sahip olunmayan formasyon seçilemiyor (15.9): varsayılan hep sahipli,
    // gerisi NOVA rafından.
    if (!hangar.formasyonaSahip(id)) return HangarError.notPurchasable;
    hangar.formasyonId = id;
    return null;
  }

  static HangarError? unequip(Hangar hangar, SlotRef slot) {
    final loadout = hangar.activeLoadout;
    if (!loadout.hasSlot(slot)) return HangarError.noSuchSlot;
    loadout.unequip(slot);
    return null;
  }

  /// Mağazadan eşya al.
  /// RAFTAN satın alma — oyunun yolu (15.2).
  ///
  /// [buyItem] kataloğun herhangi bir tasarımını kendi fiyatına alır ve
  /// testlerle geliştirme doldurmasının aracıdır; oyuncu yalnız raftan alır.
  /// Raf oyuncunun bandına bağlı, fiyat 15.2'nin modeli, alınan eşya taban:
  /// alt statsız. Bandın üstü raftan alınamaz; açılış sırası (10.7) böyle
  /// korunuyor (borç defteri B14).
  /// KARAR 15.2 s1 · KARAR 10.7 s1
  static (ItemInstance?, HangarError?) raftanAl(
    Hangar hangar,
    String specId,
    String instanceId,
    TxContext tx, {
    required int bandRank,
  }) {
    final spec = Catalogue.byId[specId];
    if (spec == null) return (null, HangarError.notFound);
    if (!Catalogue.rafFor(bandRank).contains(spec)) {
      return (null, HangarError.notPurchasable);
    }
    final price = Catalogue.rafFiyati(bandRank);
    if (!hangar.spend(
      price.currency,
      price.amount,
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: specId,
    )) {
      return (null, HangarError.notEnoughCredits);
    }
    final item = ItemInstance(
      instanceId: instanceId,
      specId: specId,
      taban: true,
    );
    hangar.addItem(item);
    return (item, null);
  }

  /// NOVA RAFINDAN AL — kıt parayla, banttan bağımsız (15.7).
  ///
  /// Kredi rafından iki farkı var ve ikisi de bilinçli: fiyat tasarımın
  /// kendi NOVA fiyatı (rafın kredi modeli değil), ve raf oyuncunun bandına
  /// bakmıyor — NOVA rafı üç tasarımdan ibaret ve hepsi merdivenin dibinde.
  /// Aynı kalan şey: gelen eşya TABAN, yani alt statsız. NOVA derinlik
  /// satmıyor (15.1).
  /// KARAR 15.7 s1
  static (ItemInstance?, HangarError?) novaRafindanAl(
    Hangar hangar,
    String specId,
    String instanceId,
    TxContext tx,
  ) {
    final spec = Catalogue.byId[specId];
    if (spec == null) return (null, HangarError.notFound);
    if (!Catalogue.novaRafi.contains(spec)) {
      return (null, HangarError.notPurchasable);
    }
    final price = Catalogue.priceOf(spec);
    if (!hangar.spend(
      price.currency,
      price.amount,
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: specId,
    )) {
      return (null, HangarError.novaYok);
    }
    final item = ItemInstance(
      instanceId: instanceId,
      specId: specId,
      taban: true,
    );
    hangar.addItem(item);
    return (item, null);
  }

  static (ItemInstance?, HangarError?) buyItem(
    Hangar hangar,
    String specId,
    String instanceId,
    TxContext tx,
  ) {
    final spec = Catalogue.byId[specId];
    if (spec == null) return (null, HangarError.notFound);
    final price = Catalogue.priceOf(spec);
    // Düşüm CÜZDANA göre: `spend` hangi keseden alacağını fiyattan okuyor ve
    // yetmezse hiçbir şey değiştirmiyor.
    if (!hangar.spend(
      price.currency,
      price.amount,
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: specId,
    )) {
      return (null, HangarError.notEnoughCredits);
    }
    final item = ItemInstance(instanceId: instanceId, specId: specId);
    hangar.addItem(item);
    return (item, null);
  }

  /// Hangardan gemi al.
  static HangarError? buyHull(Hangar hangar, String hullId, TxContext tx) {
    final hull = HullClass.byId(hullId);
    if (hull == null) return HangarError.notFound;
    if (hangar.owns(hullId)) return HangarError.alreadyOwned;
    final price = Catalogue.hullPrice(hull);
    // Merdivenden türetilen kademeler tanımlı ama satışta değil.
    if (price == null) return HangarError.notPurchasable;
    if (!hangar.spend(
      price.currency,
      price.amount,
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: hullId,
    )) {
      return HangarError.notEnoughCredits;
    }
    hangar.grantHull(hullId);
    return null;
  }

  /// Eşyayı bir seviye yükselt.
  ///
  /// **Başarısızlık şansı yok.** Garantili başarı, katlanarak artan maliyet.
  /// KARAR 07.1 s1
  static HangarError? upgrade(Hangar hangar, String instanceId, TxContext tx) {
    final item = hangar.itemOf(instanceId);
    if (item == null) return HangarError.notOwned;
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return HangarError.notFound;
    if (item.level >= ItemLevels.max) return HangarError.maxLevel;
    // Açılış sırası (10.7): artı basma ilk rankın sonunda.
    if (!Acilis.acik(Sistem.artiBasma, hangar)) return HangarError.kilitli;

    // Yükseltme HER ZAMAN kredi.
    //
    // NOVA ile alınan bir eşyanın yükseltmesini de NOVA'ya bağlamak,
    // oyuncuyu aldığı şeyi kullanamaz hâle getirirdi: kıt para eşyaya
    // gitmişken yükseltmeye kalmıyor. Kıt para EŞYAYI satıyor, eşyanın
    // ömrünü değil.
    final cost = ItemLevels.upgradeCost(item.level, spec.tier);

    // RANK KAPISI — kredi yakıt, malzeme kapı (alan 07).
    //
    // Kredi biriktiren bir oyuncu üst rank eşyasını yine de yükseltemiyor:
    // eksik olan para değil, o rankın içeriğinde geçirilmiş zaman. Malzeme
    // ikinci bir para birimi olmuyor çünkü miktarı krediyle orantılı;
    // kapıyı yapan şey mübadele EDİLEMEZ olması.
    //
    // Kontrol harcamadan ÖNCE: sırayı ters kurmak, malzemesi olmayan
    // oyuncunun kredisini yakardı.
    final malzeme = Malzeme.forRank(spec.tier);
    final gereken = Yukseltme.malzemeMaliyeti(item.level, spec.tier);
    if (hangar.malzemeSayisi(malzeme) < gereken) {
      return HangarError.notEnoughMaterials;
    }

    if (!hangar.spend(
      Currency.credit,
      cost,
      reason: LedgerReason.upgrade,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: instanceId,
    )) {
      return HangarError.notEnoughCredits;
    }
    // Malzeme kredi harcandıktan SONRA düşülüyor: kredi yetmezse kapı da
    // kapanmamış oluyor ve iki kaynak ayrı ayrı sızmıyor.
    hangar.malzemeEkle(malzeme, -gereken);
    // Çevrilmiş statlar ROL olarak saklı (07.5): seviye artınca değer
    // tabandan yeniden türer, taşınacak bir şey yok.
    hangar.addItem(item.copyWith(level: item.level + 1));
    return null;
  }

  /// Mağazadan MALZEME al.
  ///
  /// Yalnız [Catalogue.malzemeRafi]'ndakiler: üst rank malzeme mağazada yok
  /// ve olmayacak — o, üst rank eşyanın gerçek kapısı. Kredi biriktiren
  /// oyuncunun kapıyı parayla açamamasını sağlayan tek şey bu satır.
  static HangarError? malzemeAl(
    Hangar hangar,
    String malzemeId,
    int adet,
    TxContext tx,
  ) {
    if (adet <= 0) return HangarError.notFound;
    final malzeme = Malzeme.byId(malzemeId);
    if (malzeme == null) return HangarError.notFound;
    if (!Catalogue.malzemeRafi.contains(malzeme)) {
      return HangarError.notPurchasable;
    }
    final fiyat = Catalogue.malzemeFiyati(malzeme);
    if (!hangar.spend(
      fiyat.currency,
      fiyat.amount * adet,
      reason: LedgerReason.purchase,
      txId: tx.id,
      atMillis: tx.atMillis,
      detail: malzemeId,
    )) {
      return HangarError.notEnoughCredits;
    }
    hangar.malzemeEkle(malzeme, adet);
    return null;
  }

  /// ALT STATLARI YENİDEN ÇEVİR — kilitli olmayanların hepsini birden.
  ///
  /// Karar 07.5: oyuncu iyi çıkan rolü KİLİTLER ([kilitle]), kalanı çevirir;
  /// bir çevirme açık statların hepsini yeniden rolluyor. Hangi statın
  /// değişeceği rastgele değil (açık olanların hepsi), ne kadar değişeceği
  /// rastgele: tek rastgele, çift değil.
  ///
  /// Eşya YOK OLMUYOR ve sonuç her zaman geliyor (kötü olabilir). Yeni değer
  /// saklanan haritaya yazılıyor; `ItemBudget` saklanan boş değilse onu
  /// kazandırıyor, yani türetilen ilk roll oyuncunun değiştirdiği hâliyle
  /// örtülüyor. Garantili alt statlar (karar 06.10) da çevrilir; korumak
  /// isteyen kilitler.
  ///
  /// Bedel ÇEVİRİCİ, kredi değil, ve kilit sayısıyla doğrusal artıyor
  /// ([Yukseltme.cevirmeBedeli]). Katlanma yok, sayaç yok: kovalamayı
  /// sınırlayan şey fiyat değil, çeviricinin sonlu olması.
  /// KARAR 07.1 s1 · KARAR 07.5 s2
  static HangarError? cevir(
    Hangar hangar,
    String instanceId,
    math.Random zar,
    TxContext tx,
  ) {
    final item = hangar.itemOf(instanceId);
    if (item == null) return HangarError.notOwned;
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return HangarError.notFound;
    // Açılış sırası (10.7): çevirme ikinci rankta.
    if (!Acilis.acik(Sistem.cevirme, hangar)) return HangarError.kilitli;
    final hull = HullClass.byId(hangar.activeHullId) ?? HullClass.starter;
    final mevcut = LoadoutResolver.altStatlariFor(item, spec, hull);
    if (mevcut.isEmpty) return HangarError.wrongSlot;
    final kilitli = item.kilitler.where(mevcut.containsKey).toSet();
    final acik = mevcut.keys.where((id) => !kilitli.contains(id)).toList();
    // Hepsi kilitliyse çevrilecek bir şey yok — ve bedel de yok.
    if (acik.isEmpty) return HangarError.wrongSlot;
    final cevirici = Malzeme.cevirmeFor(spec.tier);
    final bedel = Yukseltme.cevirmeBedeli(
      spec.tier,
      mevcut.length,
      kilit: kilitli.length,
    );
    if (hangar.malzemeSayisi(cevirici) < bedel) {
      return HangarError.notEnoughMaterials;
    }
    hangar.malzemeEkle(cevirici, -bedel);
    // Yeni değer aynı BÜTÇEDEN, yalnız kalite rolü yeniden çekiliyor: çevirme
    // bir stat büyütme değil, aynı payı yeniden dağıtma. Taban DOĞRUDAN
    // hesaplanıyor ([ItemBudget.altStatTabani]); mevcut değerden geri
    // çözmek yaklaşıktı ve değeri sessizce ortalamaya kaydırıyordu.
    final bant = ItemBudget.kaliteAltSiniriFor(spec.tier);
    // ROL saklanıyor (07.5): açık stat bandın içinden yeni bir rol çeker,
    // kilitli stat bugünkü rolünü korur; ilk çevirmede kilitli statın rolü
    // türetilen değerinden okunur ki kilit gerçekten korusun.
    final roller = <String, double>{};
    for (final statId in mevcut.keys) {
      if (acik.contains(statId)) {
        roller[statId] = bant + zar.nextDouble() * (1 - bant);
        continue;
      }
      final eski = item.altStatRolleri[statId];
      if (eski != null) {
        roller[statId] = eski;
        continue;
      }
      final taban = ItemBudget.altStatTabani(
        spec,
        item.level,
        hull,
        statId,
        item.instanceId,
      );
      roller[statId] = taban == null || taban <= 0
          ? 1.0
          : (mevcut[statId]! / taban).clamp(0.0, 1.0);
    }
    hangar.addItem(item.copyWith(altStatRolleri: roller));
    return null;
  }

  /// Bir alt statı KİLİTLE ya da aç — çevirme kilitliye dokunmaz.
  ///
  /// Bedava ve her an geri alınabilir; bedeli çevirme anında ödeniyor (kilit
  /// sayısı çevirmeyi pahalılaştırıyor). Kilit eşyada kalıcı, kayda yazılıyor.
  /// KARAR 07.5 s2
  static HangarError? kilitle(
    Hangar hangar,
    String instanceId,
    String statId, {
    required bool kilitli,
  }) {
    final item = hangar.itemOf(instanceId);
    if (item == null) return HangarError.notOwned;
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return HangarError.notFound;
    final mevcut = LoadoutResolver.altStatlariFor(
      item,
      spec,
      HullClass.byId(hangar.activeHullId) ?? HullClass.starter,
    );
    if (!mevcut.containsKey(statId)) return HangarError.wrongSlot;
    final kilitler = Set<String>.from(item.kilitler);
    if (kilitli) {
      kilitler.add(statId);
    } else {
      kilitler.remove(statId);
    }
    hangar.addItem(item.copyWith(kilitler: kilitler));
    return null;
  }

  /// Eşyayı PARÇALA — envanterden çıkar, rankının malzemesini ver.
  ///
  /// Takılı eşya parçalanamaz: gemiden bir parçayı sökmek ayrı bir karar ve
  /// oyuncu onu bilerek vermeli. Sessizce sökmek, "yanlışlıkla silahımı
  /// erittim" demenin en kısa yolu.
  static (int, HangarError?) parcala(Hangar hangar, String instanceId) {
    final item = hangar.itemOf(instanceId);
    if (item == null) return (0, HangarError.notOwned);
    final spec = Catalogue.byId[item.specId];
    if (spec == null) return (0, HangarError.notFound);
    if (hangar.activeLoadout.slots.containsValue(instanceId) ||
        hangar.filodaMi(instanceId) ||
        hangar.droiddeMi(instanceId)) {
      return (0, HangarError.equipped);
    }
    final kazanc = GanimetCekilisi.parcalamaKazanci(spec.tier);
    hangar.removeItem(instanceId);
    hangar.malzemeEkle(Malzeme.forRank(spec.tier), kazanc);
    // ÇEVİRİCİ de düşüyor ve YALNIZ buradan düşüyor.
    //
    // Çevirmenin nadirliği tam olarak bu satırdan geliyor: kaynak öldürmeden
    // gelmiyor, yani sonsuz farm edilemiyor. Elindeki fazla eşya bitince
    // çevirme de bitiyor.
    hangar.malzemeEkle(
      Malzeme.cevirmeFor(spec.tier),
      GanimetCekilisi.parcalamaCeviriciKazanci,
    );
    return (kazanc, null);
  }

  /// SENTEZ — aynı rankta [Yukseltme.sentezOrani] eşya, bir üst rank bir eşya.
  ///
  /// **Her zaman başarılı.** Alan 07'nin kuralı: kayıp ORANDA, sonuçta değil.
  /// Başarısızlık koymak koruma tılsımı satmanın kapısını açardı ve "tavanlı
  /// orta P2W" sözünü delerdi — delindiği an geri alınamaz, çünkü koruma
  /// satın almış oyuncular olur.
  ///
  /// Girdiler AYNI RANKTA olmak zorunda ama aynı yuva tipinde değil: sentez
  /// bir rank merdiveni işlemi, yuva kimliği eşyanın kendi meselesi. Çıkan
  /// eşya girdilerin ilkinin yuva tipinde — oyuncu neyi verdiğini biliyorsa
  /// ne alacağını da bilmeli.
  /// KARAR 07.1 s1
  static (ItemInstance?, HangarError?) sentezle(
    Hangar hangar,
    List<String> instanceIds,
    String yeniInstanceId,
  ) {
    if (instanceIds.length != Yukseltme.sentezOrani) {
      return (null, HangarError.notEnoughItems);
    }
    if (instanceIds.toSet().length != instanceIds.length) {
      // Aynı eşyayı iki kez saymak, sentezi bedava rank atlatma yoluna
      // çevirirdi.
      return (null, HangarError.notEnoughItems);
    }

    final specler = <ItemSpec>[];
    for (final id in instanceIds) {
      final item = hangar.itemOf(id);
      if (item == null) return (null, HangarError.notOwned);
      if (hangar.activeLoadout.slots.containsValue(id) ||
          hangar.filodaMi(id) ||
          hangar.droiddeMi(id)) {
        return (null, HangarError.equipped);
      }
      final spec = Catalogue.byId[item.specId];
      if (spec == null) return (null, HangarError.notFound);
      specler.add(spec);
    }

    final rank = specler.first.tier;
    if (specler.any((s) => s.tier != rank)) {
      return (null, HangarError.notEnoughItems);
    }
    // Açılış sırası (10.7): sentez fazla eşya birikince — girdiler geçerliyse
    // zaten birikmiş demek; kilit burada yalnız kuralın adını koyuyor.
    if (!Acilis.acik(Sistem.sentez, hangar)) {
      return (null, HangarError.kilitli);
    }
    if (rank.index + 1 >= ItemTier.values.length) {
      return (null, HangarError.atTopRank);
    }

    final ustRank = ItemTier.values[rank.index + 1];
    final hedef = Catalogue.items.firstWhere(
      (s) => s.tier == ustRank && s.slot == specler.first.slot,
      orElse: () => Catalogue.items.firstWhere((s) => s.tier == ustRank),
    );

    for (final id in instanceIds) {
      hangar.removeItem(id);
    }
    final yeni = ItemInstance(instanceId: yeniInstanceId, specId: hedef.id);
    hangar.addItem(yeni);
    return (yeni, null);
  }
}
