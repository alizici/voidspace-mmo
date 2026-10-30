/// OYUN İÇERİĞİNİN ADLARI — statlar, formasyonlar, bölgeler, ranklar.
///
/// **Neden çekirdekte değil.** `voidspace_core` sunucuyla PAYLAŞILAN paket ve
/// hiçbir paketi tanımıyor; ona dil sokmak, otorite sunucusunu ve belge
/// üreticisini de dil bilir hâle getirirdi. Oysa sunucunun bir dili yok:
/// oyuncuya metin değil KİMLİK gönderiyor (`taban_hasar`, `kabuk`, `df1`).
/// Çekirdekteki Türkçe etiket tasarım belgelerinin kanonik adı olarak
/// duruyor; oyuncunun gördüğü ad burada seçiliyor.
///
/// **Neden kimlikten çeviriyoruz.** Tablolar `spec.name` gibi GÖRÜNEN metne
/// değil, `spec.id` gibi kararlı kimliğe bakıyor. Görünen metne bakan bir
/// çeviri, çekirdekte bir etiket düzeltilir düzeltilmez sessizce Türkçeye
/// düşerdi — ve bunu ancak İtalyanca oynayan biri fark ederdi.
///
/// **Çevrilmeyenler kasıtlı.** Gövde adları (Bastion, Vanguard), yaratık
/// adları (Interdictor, Barraguda), ünvanlar (Squire, Knight), mermi ve roket
/// kodları (MR-1, RK-3) ve rank kodları (C-II, SSS-I) her dilde AYNI. Bunlar
/// özel ad ya da kod; çevirmek onları oyuncular arasında konuşulamaz hâle
/// getirirdi.
library;

import 'package:voidspace_core/voidspace_core.dart';

import 'dil.dart';
import 'metin.dart';

// ══ Statlar ══════════════════════════════════════════════════════════

const Map<String, (String, String, String)> _statlar = {
  'taban_hasar': ('Taban hasar', 'Base damage', 'Danno base'),
  'govde_cani': ('Gövde', 'Hull', 'Scafo'),
  'kalkan': ('Kalkan', 'Shield', 'Scudo'),
  'hasar_artisi': ('Hasar artışı', 'Damage boost', 'Aumento danno'),
  'atis_hizi': ('Atış hızı', 'Fire rate', 'Cadenza di fuoco'),
  'kalkan_yenilenmesi': (
    'Kalkan yenilenmesi',
    'Shield regen',
    'Rigenerazione scudo',
  ),
  'hiz': ('Hız', 'Speed', 'Velocità'),
  'itki_dolumu': ('İtki dolumu', 'Boost recharge', 'Ricarica spinta'),
  'menzil': ('Menzil', 'Range', 'Gittata'),
  'kritik_sansi': ('Kritik şansı', 'Crit chance', 'Probabilità critico'),
  'kritik_hasari': ('Kritik hasarı', 'Crit damage', 'Danno critico'),
  'zirh': ('Zırh', 'Armour', 'Armatura'),
  'kacinma': ('Kaçınma', 'Evasion', 'Evasione'),
  'son_hasar': ('Son hasar', 'Final damage', 'Danno finale'),
  'son_azaltma': ('Son azaltma', 'Final reduction', 'Riduzione finale'),
  'delici': ('Delici', 'Piercing', 'Perforante'),
  'sertlik': ('Sertlik', 'Hardness', 'Durezza'),
  'kirici': ('Kırıcı', 'Breaker', 'Frantumatore'),
  'zirh_katmani': ('Zırh katmanı', 'Armour layer', 'Strato di armatura'),
  'kritik_direnci': (
    'Kritik direnci',
    'Crit resistance',
    'Resistenza al critico',
  ),
  'durum_hasari': ('Durum hasarı', 'Status damage', 'Danno di stato'),
  'durum_azaltma': ('Durum azaltma', 'Status reduction', 'Riduzione di stato'),
};

/// Bir statın oyuncuya görünen adı. Tanınmayan kimlik AYNEN dönüyor — yeni
/// bir stat eklendiğinde arayüz boş kalmasın, kimliğiyle görünsün.
String statAdi(String statId, Dil dil) =>
    _uc(_statlar[statId], dil) ?? Catalogue.labelOf(statId);

// ══ Yuva türleri ═════════════════════════════════════════════════════

/// Yuva adı. Arayüz metinleriyle aynı sözlükte durması kasıtlı: "LAZER"
/// hem bir yuva türü hem bir başlık olarak geçiyor ve iki yerde ayrışamaz.
String yuvaAdi(SlotType tur, Dil dil) => switch (tur) {
  SlotType.laser => Metin.yuvaLazer(dil),
  SlotType.generator => Metin.yuvaJenerator(dil),
  SlotType.launcher => Metin.yuvaRoketatar(dil),
  SlotType.cpu => Metin.yuvaCpu(dil),
  SlotType.droid => Metin.yuvaDroid(dil),
};

// ══ Ranklar ══════════════════════════════════════════════════════════

/// Rank etiketi. Harf-basamak kodları (C-I … SSS-III) her dilde aynı; yalnız
/// iki kapak taşının ADI var ve o ad çevriliyor.
String rankEtiketi(ItemTier rank, Dil dil) => switch (rank) {
  ItemTier.kirmizi => switch (dil) {
    Dil.turkce => 'KIRMIZI',
    Dil.ingilizce => 'RED',
    Dil.italyanca => 'ROSSO',
  },
  ItemTier.parlayanPembe => switch (dil) {
    Dil.turkce => 'PARLAYAN PEMBE',
    Dil.ingilizce => 'GLOWING PINK',
    Dil.italyanca => 'ROSA BRILLANTE',
  },
  _ => rank.label,
};

// ══ Para birimleri ═══════════════════════════════════════════════════

/// Para biriminin adı. NOVA her dilde NOVA — ekonominin özel adı, çevrilirse
/// oyuncular birbirinin bahsettiği parayı tanımaz.
String paraAdi(Currency para, Dil dil) => switch (para) {
  Currency.credit => switch (dil) {
    Dil.turkce => creditName,
    Dil.ingilizce => 'CREDITS',
    Dil.italyanca => 'CREDITI',
  },
  Currency.premium => premiumName,
};

// ══ Malzemeler ═══════════════════════════════════════════════════════

String _malzemeTuruAdi(MalzemeTuru tur, Dil dil) => switch (tur) {
  MalzemeTuru.yukseltme => switch (dil) {
    Dil.turkce => 'Malzeme',
    Dil.ingilizce => 'Material',
    Dil.italyanca => 'Materiale',
  },
  MalzemeTuru.cevirme => switch (dil) {
    Dil.turkce => 'Çevirici',
    Dil.ingilizce => 'Reroller',
    Dil.italyanca => 'Ritiratore',
  },
};

/// Malzemenin adı — türü ve rankı, çekirdekteki `Malzeme.ad` ile aynı düzende.
String malzemeAdi(Malzeme malzeme, Dil dil) =>
    '${_malzemeTuruAdi(malzeme.tur, dil)} ${rankEtiketi(malzeme.rank, dil)}';

// ══ Formasyonlar ═════════════════════════════════════════════════════

const Map<String, (String, String, String)> _formasyonlar = {
  'kabuk': ('Kabuk', 'Shell', 'Guscio'),
  'ok': ('Ok', 'Arrow', 'Freccia'),
  'mizrak': ('Mızrak', 'Lance', 'Lancia'),
  'yildiz': ('Yıldız', 'Star', 'Stella'),
  'kiskac': ('Kıskaç', 'Pincer', 'Tenaglia'),
  'cift-ok': ('Çift Ok', 'Twin Arrow', 'Doppia Freccia'),
  'elmas': ('Elmas', 'Diamond', 'Diamante'),
  'kama': ('Kama', 'Wedge', 'Cuneo'),
  'guve': ('Güve', 'Moth', 'Falena'),
  'yengec': ('Yengeç', 'Crab', 'Granchio'),
  'kalp': ('Kalp', 'Heart', 'Cuore'),
  'baraj': ('Baraj', 'Barrage', 'Sbarramento'),
  'yarasa': ('Yarasa', 'Bat', 'Pipistrello'),
  'halka': ('Halka', 'Ring', 'Anello'),
  'burgu': ('Burgu', 'Spiral', 'Spirale'),
  'oncu': ('Öncü', 'Vanguard', 'Avanguardia'),
  'kubbe': ('Kubbe', 'Dome', 'Cupola'),
  'cark': ('Çark', 'Wheel', 'Ruota'),
  'capraz': ('Çapraz', 'Cross', 'Croce'),
  'dalga': ('Dalga', 'Wave', 'Onda'),
};

String formasyonAdi(Formasyon formasyon, Dil dil) =>
    _uc(_formasyonlar[formasyon.id], dil) ?? formasyon.ad;

String egilimAdi(FormasyonEgilimi egilim, Dil dil) => switch (egilim) {
  FormasyonEgilimi.saldiri => switch (dil) {
    Dil.turkce => 'Saldırı',
    Dil.ingilizce => 'Attack',
    Dil.italyanca => 'Attacco',
  },
  FormasyonEgilimi.savunma => switch (dil) {
    Dil.turkce => 'Savunma',
    Dil.ingilizce => 'Defence',
    Dil.italyanca => 'Difesa',
  },
  FormasyonEgilimi.denge => switch (dil) {
    Dil.turkce => 'Denge',
    Dil.ingilizce => 'Balance',
    Dil.italyanca => 'Equilibrio',
  },
};

// ══ ArGe ═════════════════════════════════════════════════════════════

/// ArGe DALININ adı (05.7). Dal bir tema değil bir YÖN, ve yön çevrilebilir:
/// "Filo" bir özel ad değil, oyuncunun droidlerinin toplu adı.
///
/// `switch` üstünde, sözlükte değil: `ArGeDali` kapalı bir enum, yani
/// dördüncü bir dal eklendiği gün bu satır DERLENMEZ. Kimliğe bakan bir
/// sözlük ise sessizce kimliği dönerdi.
String argeDaliAdi(ArGeDali dal, Dil dil) => switch (dal) {
  ArGeDali.filo => switch (dil) {
    Dil.turkce => 'Filo',
    Dil.ingilizce => 'Fleet',
    Dil.italyanca => 'Flotta',
  },
  ArGeDali.gemi => switch (dil) {
    Dil.turkce => 'Gemi',
    Dil.ingilizce => 'Ship',
    Dil.italyanca => 'Nave',
  },
};

/// ArGe DÜĞÜMLERİNİN adı — anahtar `ArGeDugumu.id`, `ArGeDugumu.ad` DEĞİL.
///
/// Çekirdekteki `ad` alanı tasarım belgelerinin kanonik Türkçesi ve orada
/// kalıyor; oyuncunun gördüğü ad burada seçiliyor. Kimlikten çevirmenin
/// bedeli bir satır, ADDAN çevirmenin bedeli sessiz bir bozulma: çekirdekte
/// `'Bağlaşım I'` düzeltildiği gün İtalyanca oynayan oyuncu Türkçe bir düğüm
/// adı görürdü ve bunu ne derleyici ne test söylerdi (borç defteri B36 aynı
/// tuzağın droid tasarımlarında yaşanmış hâliydi; kapandı).
///
/// Roma rakamları çevrilmiyor: zincirdeki sırayı gösteren bir sayı, bir
/// kelime değil.
const Map<String, (String, String, String)> _argeDugumleri = {
  'filo-1': ('Bağlaşım I', 'Coupling I', 'Accoppiamento I'),
  'filo-2': ('Bağlaşım II', 'Coupling II', 'Accoppiamento II'),
  'filo-3': ('Bağlaşım III', 'Coupling III', 'Accoppiamento III'),
  'filo-yuva': ('Ek Yuva', 'Extra Bay', 'Alloggiamento Extra'),
  'gemi-1': ('Yalıtım I', 'Insulation I', 'Isolamento I'),
  'gemi-2': ('Yalıtım II', 'Insulation II', 'Isolamento II'),
  'gemi-3': ('Yalıtım III', 'Insulation III', 'Isolamento III'),
  'gemi-profil': ('İkinci Profil', 'Second Profile', 'Secondo Profilo'),
};

/// Bir ArGe düğümünün adı. Tanınmayan kimlik çekirdeğin adına düşüyor —
/// ağaca yeni bir düğüm eklendiğinde ekran boş kalmasın.
String argeDugumAdi(ArGeDugumu dugum, Dil dil) =>
    _uc(_argeDugumleri[dugum.id], dil) ?? dugum.ad;

/// Bir ArGe İZNİNİN ne açtığı (05.7).
///
/// Cümle, ad değil: izin düğümü sayı vermiyor ve "Ek Yuva" tek başına neyin
/// ek olduğunu söylemiyor. Oyuncunun beş puanı harcamadan önce okuması
/// gereken şey düğümün adı değil SONUCU.
String argeIzniAciklamasi(ArGeIzni izin, Dil dil) => switch (izin) {
  ArGeIzni.filoYuvasi => switch (dil) {
    Dil.turkce => 'Filo tavanı +1',
    Dil.ingilizce => 'Fleet cap +1',
    Dil.italyanca => 'Limite flotta +1',
  },
  ArGeIzni.ikinciProfil => switch (dil) {
    Dil.turkce => 'İkinci donatım profili',
    Dil.ingilizce => 'Second loadout profile',
    // Kısa: dar pencerede düğüm kutusu 206 piksel ve tam ad oraya
    // sığmayıp üç noktaya kesiliyordu.
    Dil.italyanca => 'Secondo equipaggiamento',
  },
};

// ══ Bölgeler ve haritalar ════════════════════════════════════════════

/// Sekiz bölgenin adı — sıra `Bolge.adlar` ile BİREBİR.
///
/// Kimlikle değil sırayla eşleşiyor, çünkü bölgenin kimliği kademesi.
const List<(String, String, String)> _bolgeler = [
  ('Sığlık', 'The Shallows', 'Le Secche'),
  ('Kırık Halka', 'Broken Ring', 'Anello Spezzato'),
  ('Solgun Geçit', 'Pale Passage', 'Passo Pallido'),
  ('Kor Sahanlığı', 'Ember Shelf', 'Piana di Brace'),
  ('Yas Boşluğu', 'Mourning Void', 'Vuoto del Lutto'),
  ('Devrik Kule', 'Fallen Tower', 'Torre Caduta'),
  ('Sessiz Fener', 'Silent Beacon', 'Faro Silente'),
  ('Son Eşik', 'Last Threshold', 'Ultima Soglia'),
];

String bolgeAdi(Bolge bolge, Dil dil) =>
    (bolge.kademe >= 0 && bolge.kademe < _bolgeler.length
        ? _uc(_bolgeler[bolge.kademe], dil)
        : null) ??
    bolge.ad;

/// Haritanın tam adı. Tip (PvE · PvP · Boss) her dilde aynı: tür adı değil
/// oyun terimi.
String haritaAdi(Harita harita, Dil dil) =>
    '${bolgeAdi(harita.bolge, dil)} · ${harita.tip.ad}';

// ══ Ünvan çağları ════════════════════════════════════════════════════

/// Dört çağın adı — sıra `Unvan.cagAdlari` ile birebir. Ünvanların KENDİ
/// adları (Squire, Knight, Star Lord) çevrilmiyor: özel ad.
const List<(String, String, String)> _caglar = [
  ('Asalet', 'Nobility', 'Nobiltà'),
  ('Kutsallık', 'Sanctity', 'Santità'),
  ('Yıldız', 'Star', 'Stella'),
  ('Ölümsüzlük', 'Immortality', 'Immortalità'),
];

/// Çağ SIRASIYLA (0..3) — merdiven satırlarının etiketi.
String cagAdiSirali(int cagIndeksi, Dil dil) =>
    (cagIndeksi >= 0 && cagIndeksi < _caglar.length
        ? _uc(_caglar[cagIndeksi], dil)
        : null) ??
    Unvan.caglar[cagIndeksi.clamp(0, Unvan.caglar.length - 1)];

/// Bir UNVAN indeksinin (0..119) çağı.
String cagAdi(int unvanIndeksi, Dil dil) =>
    cagAdiSirali(Unvan.cagIndeksi(unvanIndeksi), dil);

// ══ Eşya adları ══════════════════════════════════════════════════════

/// Mağaza rafındaki eşyaların adı — kimlikle eşleşiyor.
///
/// Yalnız ADIN Türkçe parçası çevriliyor: "DF-1" bir model kodu ve her dilde
/// aynı kalıyor.
///
/// İki DROİD (`dr1` Delta, `dr5` Hilal) burada YOK ve bu bir eksik değil:
/// droidin adı tasarımının adı ve o ad [_droidTasarimi] içinde duruyor.
/// Buraya da yazılsaydı aynı isim iki tabloda olurdu; ikisinden biri
/// güncellenmeden kaldığı gün mağazadaki droid ile filodaki droid ayrı adlar
/// taşırdı.
const Map<String, (String, String, String)> _rafAdlari = {
  'df1': ('DF-1 Kalkan', 'DF-1 Shield', 'DF-1 Scudo'),
  'df3': ('DF-3 Kalkan', 'DF-3 Shield', 'DF-3 Scudo'),
  'df5': ('DF-5 Nova Kalkanı', 'DF-5 Nova Shield', 'DF-5 Scudo Nova'),
  'th1': ('TH-1 İtki', 'TH-1 Thruster', 'TH-1 Propulsore'),
  'th3': ('TH-3 İtki', 'TH-3 Thruster', 'TH-3 Propulsore'),
  'mk1': ('MK-1 Fırlatıcı', 'MK-1 Launcher', 'MK-1 Lanciarazzi'),
  'cpu_repair': ('Tamir Devresi', 'Repair Circuit', 'Circuito di Riparazione'),
  'cpu_scope': ('Nişan Devresi', 'Targeting Circuit', 'Circuito di Mira'),
};

/// On droid TASARIMININ adı — droidin görünüşü (05.8 s2).
///
/// **Anahtar KİMLİK, görünen ad DEĞİL.** Bu tablo bir zaman droidin Türkçe
/// ADIYLA anahtarlıydı (`'Halka' → …`) ve dosyanın başındaki kuralın tek
/// istisnasıydı; gerekçesi "tasarımın paylaşılan bir kimlik uzayı yok" idi.
/// Oysa var ve zaten kullanılıyor: kimlik `ItemSpec.variant` içinde telden
/// geliyor, çekirdekteki `DroidModeli` ile sanattaki `DroidCizimi` o kimlikte
/// birebir örtüşüyor ve örtüştüklerini `droid_ikonu_test.dart` kilitliyor.
/// Yani sanat katmanına bir alan eklemeden, çekirdeğin zaten gönderdiği
/// kimliği anahtar yapmak yetti — çizim katalogunda bir ad düzeltmek artık
/// çeviriyi ıskalatmıyor (borç defteri B36).
///
/// **`switch`, sözlük değil** — [argeDaliAdi] ile aynı gerekçe: `DroidModeli`
/// kapalı bir enum, yani on birinci tasarım eklendiği gün bu satır DERLENMEZ.
/// Sözlük olsaydı yeni tasarım sessizce çevrilmeden kalırdı, ki kapatılan
/// borcun asıl zararı tam olarak oydu.
(String, String, String)? _droidTasarimi(String? kimlik) =>
    switch (DroidModeli.values.where((m) => m.name == kimlik).firstOrNull) {
      null => null,
      DroidModeli.hilal => ('Hilal', 'Crescent', 'Crescente'),
      DroidModeli.halka => ('Halka', 'Ring', 'Anello'),
      DroidModeli.delta => ('Delta', 'Delta', 'Delta'),
      DroidModeli.elmas => ('Elmas', 'Diamond', 'Diamante'),
      DroidModeli.damla => ('Damla', 'Drop', 'Goccia'),
      DroidModeli.pusula => ('Pusula', 'Compass', 'Bussola'),
      DroidModeli.cerceve => ('Çerçeve', 'Frame', 'Cornice'),
      DroidModeli.prizma => ('Prizma', 'Prism', 'Prisma'),
      DroidModeli.parantez => ('Parantez', 'Bracket', 'Parentesi'),
      DroidModeli.jiroskop => ('Jiroskop', 'Gyroscope', 'Giroscopio'),
    };

/// Bir droid tasarımının adı. [kimlik] `ItemSpec.variant`taki tasarım kimliği
/// (`halka`), oyuncunun gördüğü ad değil.
///
/// [yedek] ÇAĞRI YERİNDEN geliyor ve bu bilinçli: tanınmayan bir kimliğin
/// yerine yazılacak şeyi bu dosya üretemiyor — tasarımın Türkçe adı çekirdekte
/// ve sanat katalogunda duruyor, ikisi de burada okunmuyor. Çağıranın elinde
/// ise hep bir şey var: çekirdeğin ürettiği ad ya da kimliğin kendisi. Ham
/// kimliği ("halka") oyuncuya göstermek boş bir hücreden iyi, çekirdeğin
/// Türkçe adını göstermek ondan da iyi.
String droidTasarimAdi(String? kimlik, Dil dil, {required String yedek}) =>
    _uc(_droidTasarimi(kimlik), dil) ?? yedek;

/// TÜRETİLEN eşyanın Türkçe ÖNEKİNİN çevirisi; `null` "çevrilecek bir şey
/// yok, önek aynen geçsin" demek.
///
/// Çekirdek üst rankları rafın en iyisinden türetiyor ve adı ŞABLONUN İLK
/// KELİMESİYLE kuruyor. Dört yuvada o kelime bir model kodu (PL-5, DF-5,
/// MK-1) ya da bir tasarım adı, yani burada işi yok; CPU'da ise düpedüz
/// Türkçe bir kelime — İngilizce oynayan biri "Tamir SS-I" görüyordu ve bunu
/// ne derleyici ne test söylüyordu.
///
/// Anahtar YUVA, önek metni değil: `SlotType` kapalı bir enum, yeni bir yuva
/// eklendiği gün bu satır derlenmez. [onek] yine de sınanıyor, çünkü şablonun
/// hangi eşya olduğunu seçen kural çekirdekte: CPU rafına yeni bir eşya
/// girerse önek "Tamir" olmaktan çıkar ve o gün adı ÇEVİRMEK değil OLDUĞU
/// GİBİ bırakmak doğru olur. Türkçe sütunun çekirdeğin ürettiği önekle aynı
/// kaldığını `dil_test.dart` ayrıca kilitliyor.
String? _turetilenOnek(SlotType yuva, String onek, Dil dil) => switch (yuva) {
  SlotType.laser ||
  SlotType.generator ||
  SlotType.launcher ||
  SlotType.droid => null,
  SlotType.cpu => onek == 'Tamir'
      ? switch (dil) {
          Dil.turkce => 'Tamir',
          Dil.ingilizce => 'Repair',
          Dil.italyanca => 'Riparazione',
        }
      : null,
};

/// Bir eşyanın oyuncuya görünen adı.
///
/// Üç yol var ve üçü de KİMLİKTEN geçiyor:
///  * RAFTAKİLER elle yazılmış ad taşıyor — `spec.id` ile eşleşiyorlar.
///  * DROİDLER adını TASARIMINDAN alıyor ve tasarımın kimliği `variant`ta.
///    Raftaki ikisi (`Delta`, `Hilal`) ile merdivenden türetilenler aynı
///    yerden okunuyor: ikisinin gösterdiği şey aynı çizim.
///  * ÖTEKİ TÜRETİLENLER `<önek> <rank>` biçiminde (`PL-5 SS-I`). Rank her
///    dilde yeniden yazılıyor; önek model kodu olduğu için aynen geçiyor,
///    kod olmayan tek yuvayı [_turetilenOnek] düzeltiyor.
///
/// Adı parçalayıp yeniden kurmak, çeviriyi çekirdeğin üretim kuralına bağımlı
/// kılmıyor: kural değişirse önek olduğu gibi geçer, ad yine okunur.
/// Bu eşya bir DROİD mi, öyleyse HANGİ tasarımı taşıyor.
///
/// Örneğin seçtiği tasarım şemanınkini EZİYOR: oyuncu droidinin görünüşünü
/// değiştirebiliyor (05.8 s2, borç defteri B24) ve gördüğü şey satın aldığı
/// şema değil elindeki droid.
///
/// **Kural TEK YERDE ve iki okuyucusu var:** hücrenin ÇİZİMİ
/// (`droidCizimiOf`) ve eşyanın ADI ([esyaAdi]). Uzun süre yalnız çizim bu
/// kuralı biliyordu; ad şemanın `variant`ından çevriliyordu ve örneği hiç
/// görmüyordu. Sonuç aynı hücrede iki ayrı droiddi: Delta'sına Jiroskop
/// görünüşü takan oyuncu Jiroskop çizimini görüyor ama ipucunda "Delta C-I"
/// okuyordu. İkinci bir kural yazmak yerine ikisi de buradan soruyor.
String? droidTasarimKimligi(ItemSpec? spec, ItemInstance? item) =>
    spec == null || spec.slot != SlotType.droid
    ? null
    : (item?.tasarim ?? spec.variant);

String esyaAdi(ItemSpec spec, Dil dil, {ItemInstance? item}) {
  final raf = _uc(_rafAdlari[spec.id], dil);
  if (raf != null) return raf;

  // Rank soneki OLMAYAN ad da çevriliyor: raftaki droidin adı çıplak bir
  // tasarım adı ("Hilal") ve eskiden bu satırda olduğu gibi dönerdi.
  final rank = spec.tier.label;
  final rankli = spec.name.endsWith(rank);
  final onek = rankli
      ? spec.name.substring(0, spec.name.length - rank.length).trim()
      : spec.name;
  final cevrilen = spec.slot == SlotType.droid
      ? droidTasarimAdi(
          droidTasarimKimligi(spec, item) ?? spec.variant,
          dil,
          yedek: onek,
        )
      : _turetilenOnek(spec.slot, onek, dil) ?? onek;
  return rankli ? '$cevrilen ${rankEtiketi(spec.tier, dil)}'.trim() : cevrilen;
}

// ══ Ortak ════════════════════════════════════════════════════════════

/// `(tr, en, it)` üçlüsünden dilin karşılığını seçer.
String? _uc((String, String, String)? kayit, Dil dil) => switch (dil) {
  Dil.turkce => kayit?.$1,
  Dil.ingilizce => kayit?.$2,
  Dil.italyanca => kayit?.$3,
};
