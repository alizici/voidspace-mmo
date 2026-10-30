/// KARAR İZLENEBİLİRLİĞİ — belge ile kodu birbirine bağlayan çözümleyici.
///
/// Belge mimarisinin omurgası. Üç kaynağı okur ve dört yönde karşılaştırır:
///
///  * `docs/NN-ad.md` kural belgeleri: numaralı, durumlu, sürümlü kararlar.
///  * `lib/` altındaki Dart kaynakları: `KARAR 06.5 s1` atıfları.
///  * `docs/karar-izi.json`: her kararın metin parmak izi (şüpheli bağlantı).
///
/// Mekanizmalar ödünç, uydurulmuş değil:
///
///  * **Sürümlü atıf** — OpenFastTrace'in `req~name~rev` kuralı. Karar
///    metni anlam değiştirince sürümü artar; eski sürümü anan her atıf
///    "kod eskimiş" olur ve gözden geçirilmeden geçemez.
///  * **Şüpheli bağlantı** — Doorstop'un parmak izi. Karar metni değişmiş
///    ama sürüm artmamışsa denetim durur: ya tasarım değişmiştir (sürümü
///    artır) ya yalnız anlatım düzelmiştir (izi onayla). Karar insanın.
///  * **Durum** — ADR'nin kabul/uygulandı ayrımı, uygulama kapsamına
///    uyarlanmış: `kodda · belgede · açık · kaldırıldı · ayrılmış`.
///
/// Bu dosya `test/belge_test.dart` ve `tool/belge/belge.dart` tarafından
/// paylaşılıyor; ikisi de aynı çözümleyiciyi çağırıyor, ikinci bir okuma
/// yazılmıyor.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:voidspace_core/voidspace_core.dart';

/// Bir kararın uygulama durumu.
enum KararDurumu {
  /// Kod uyguluyor; en az bir atıf ZORUNLU.
  kodda('kodda'),

  /// Tasarlandı, kod henüz izlemiyor; atıf OLAMAZ.
  belgede('belgede'),

  /// Karar verilmemiş; belge soruyu ve seçenekleri taşıyor; atıf OLAMAZ.
  acik('açık'),

  /// Geri alındı; tarih için duruyor; atıf OLAMAZ.
  kaldirildi('kaldırıldı'),

  /// Bilerek kodsuz: ileriye yer ayıran şema ya da süreç kuralı. Atıf
  /// OLAMAZ; kodlanacaklar listesine girmez, haritada ayrı sayılır.
  ayrilmis('ayrılmış');

  const KararDurumu(this.etiket);

  final String etiket;

  /// Atıf taşıması beklenen tek durum.
  bool get atifIster => this == kodda;

  static KararDurumu? parse(String s) {
    for (final d in values) {
      if (d.etiket == s) return d;
    }
    return null;
  }
}

/// Belgedeki tek bir karar.
class Karar {
  const Karar({
    required this.alan,
    required this.no,
    required this.baslik,
    required this.durum,
    required this.surum,
    required this.not,
    required this.dosya,
    required this.satir,
    required this.govde,
  });

  final int alan;
  final int no;
  final String baslik;
  final KararDurumu durum;
  final int surum;
  final String? not;
  final String dosya;
  final int satir;

  /// Durum satırından bir sonraki karara kadar olan metin — parmak izi
  /// bunun üstünden.
  final String govde;

  String get id => '${alan.toString().padLeft(2, '0')}.$no';

  String get iz => parmakIzi(govde);

  @override
  String toString() => '$id · $baslik';
}

/// Koddaki bir atıf: `KARAR 06.5 s1`.
class Atif {
  const Atif({
    required this.id,
    required this.surum,
    required this.dosya,
    required this.satir,
    this.test = false,
  });

  final String id;

  /// Sürümsüz atıf `null` — biçim hatası, kod eskimiş sayılır.
  final int? surum;
  final String dosya;
  final int satir;

  /// Test dosyasından mı: "kodda" için sayılmaz, "sınanmış" için sayılır
  /// (16.8).
  final bool test;

  String get yer => '$dosya:$satir';
}

/// Borç defterindeki bir madde (16.9): kimliği, durumu ve kaynağı.
class BorcMaddesi {
  const BorcMaddesi({
    required this.id,
    required this.baslik,
    required this.durum,
    required this.kararlar,
    required this.alanlar,
    required this.satir,
  });

  final String id;
  final String baslik;

  /// açık · izleniyor · kapandı
  final String durum;

  /// Kaynak satırındaki karar kimlikleri (`08.1`) ve alan numaraları (`14`).
  final List<String> kararlar;
  final List<int> alanlar;
  final int satir;

  bool get acik => durum != 'kapandı';
}

/// README'deki yan belge (16.9): `docs/` dışında yazılmış bir tasarım.
class YanBelge {
  const YanBelge({
    required this.ad,
    required this.adres,
    required this.durum,
    this.hedef,
  });

  final String ad;
  final String adres;

  /// `dışarıda` ya da `taşındı`.
  final String durum;

  /// Taşındıysa `docs/` altındaki dosya.
  final String? hedef;

  bool get disarida => durum == 'dışarıda';
}

/// `docs/` altındaki bir markdown dosyası.
class Belge {
  Belge({
    required this.yol,
    required this.onBilgi,
    required this.kararlar,
    required this.hatalar,
    required this.metin,
  });

  final String yol;
  final Map<String, String> onBilgi;
  final List<Karar> kararlar;

  /// Biçim hataları — çözümleyici bunları bulgu olarak geri veriyor.
  final List<String> hatalar;
  final String metin;

  int? get alan => int.tryParse(onBilgi['alan'] ?? '');
  String get tur => onBilgi['tur'] ?? '';
  String get ad => onBilgi['ad'] ?? yol;
  bool get kural => tur == 'kural';
  bool get uretilmis => metin.contains(BelgeUretici.damga);
}

/// Bir bulgu: kim eskimiş ve ne yapılmalı.
class Bulgu {
  const Bulgu(this.tur, this.mesaj);

  final BulguTuru tur;
  final String mesaj;

  @override
  String toString() => '[${tur.etiket}] $mesaj';
}

enum BulguTuru {
  /// Belgeyi düzelt.
  belgeEskimis('BELGE ESKİMİŞ'),

  /// Kodu düzelt.
  kodEskimis('KOD ESKİMİŞ'),

  /// İnsan bakmalı: metin değişti, sürüm artmadı.
  supheli('ŞÜPHELİ'),

  /// Belge biçimi bozuk.
  bicim('BİÇİM');

  const BulguTuru(this.etiket);

  final String etiket;
}

/// FNV-1a 32 bit, normalize edilmiş metin üstünden. Güvenlik değil değişim
/// tespiti; platformdan bağımsız olsun diye bit işleci yok
/// ([ItemBudget.kaliteRolu] ile aynı seçim).
String parmakIzi(String metin) {
  final normal = metin
      .split('\n')
      .map((s) => s.trim().replaceAll(RegExp(r'\s+'), ' '))
      .where((s) => s.isNotEmpty)
      .join('\n');
  var karma = 2166136261;
  for (final birim in normal.codeUnits) {
    karma = ((karma ^ birim) * 16777619) % 4294967296;
  }
  return karma.toRadixString(16).padLeft(8, '0');
}

/// Türkçe yazılmış sayı: `1.047,9` → 1047.9. Çözülemezse `null`.
double? turkceSayi(String s) =>
    double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));

/// Yazılan ondalık basamak sayısı — karşılaştırma toleransı bundan.
int ondalikSayisi(String s) {
  final i = s.indexOf(',');
  return i < 0 ? 0 : s.length - i - 1;
}

/// Bütün belgeler, atıflar ve parmak izleri — tek okuma.
class BelgeDeposu {
  BelgeDeposu._({
    required this.belgeler,
    required this.atiflar,
    required this.eskiIzler,
    required this.docs,
    required this.yanBelgeler,
    required this.yanHatalari,
  });

  final List<Belge> belgeler;

  /// Kod VE test atıfları; [Atif.test] ayırıyor.
  final List<Atif> atiflar;

  /// README'nin yan belge tablosu (16.9).
  final List<YanBelge> yanBelgeler;
  final List<String> yanHatalari;

  /// `karar-izi.json`'daki son onaylı izler: id → {s, iz}.
  final Map<String, Map<String, dynamic>> eskiIzler;
  final String docs;

  static const String izDosyasi = 'karar-izi.json';
  static const String haritaDosyasi = '00-harita.md';

  static final RegExp _baslik = RegExp(r'^## (\d{2})\.(\d+) [·\-–—] (.+)$');
  static final RegExp _durum = RegExp(
    r'^Durum:\s*(kodda|belgede|açık|kaldırıldı|ayrılmış)\s*[·\-–—]\s*s(\d+)'
    r'(?:\s*[·\-–—]\s*(.+))?\s*$',
  );
  static final RegExp _atif = RegExp(r'KARAR (\d{2}\.\d+)(?: s(\d+))?');

  /// `` `ad = 0,70` `` girdi; `` `ad(6) = 5` `` türetilen; `%` yüzde (16.7).
  static final RegExp _etiket = RegExp(
    r'`([A-Za-z][A-Za-z0-9_]*)(?:\(([^)`]*)\))? = (%?-?\d[\d.,]*)`',
  );

  /// Denetim kodu da kod: `tool/belge` atıf tarayıcısının kapsamında.
  static const List<String> kodKokleri = [
    'packages/voidspace_core/lib',
    'lib',
    'server/lib',
    'tool/belge',
  ];

  static final RegExp _borcBaslik = RegExp(r'^## (B\d+) [·\-–—] (.+)$');
  static final RegExp _borcDurum = RegExp(
    r'^Durum:\s*(açık|izleniyor|kapandı)',
  );
  static final RegExp _tarih = RegExp(r'\d{4}-\d{2}-\d{2}');
  static final RegExp _yanSatir = RegExp(
    r'^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|',
  );

  /// Tür olmayan etiketler — türün yanına yazılır, sayıma girmez (16.1).
  /// KARAR 16.1 s1
  static const Set<String> testNitelikleri = {'zaman'};

  /// Test dosyalarının kökleri — tür sayımı için (karar 16.1).
  static const List<String> testKokleri = [
    'packages/voidspace_core/test',
    'test',
    'server/test',
  ];

  static final RegExp _tagsAnnot = RegExp(
    r'^@Tags\(\[([^\]]*)\]\)',
    multiLine: true,
  );

  /// Her test dosyası ve ilan ettiği türler. Etiketsiz dosya boş liste ile.
  /// KARAR 16.1 s1
  static Map<String, List<String>> testTurleri() {
    final sonuc = <String, List<String>>{};
    for (final kok in testKokleri) {
      final d = Directory(kok);
      if (!d.existsSync()) continue;
      final dosyalar =
          d
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('_test.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in dosyalar) {
        final m = _tagsAnnot.firstMatch(f.readAsStringSync());
        sonuc[f.path] = m == null
            ? const []
            : m
                  .group(1)!
                  .split(',')
                  .map((s) => s.trim().replaceAll("'", '').replaceAll('"', ''))
                  .where((s) => s.isNotEmpty)
                  .toList();
      }
    }
    return sonuc;
  }

  /// Tür → o türü ilan eden test dosyası sayısı. Dışı ayrı sayılır.
  static Map<TestTuru, int> testTuruSayimi() {
    final sayim = {for (final t in TestTuru.values) t: 0};
    for (final etiketler in testTurleri().values) {
      for (final e in etiketler) {
        final t = TestTuru.parse(e);
        if (t != null) sayim[t] = sayim[t]! + 1;
      }
    }
    return sayim;
  }

  static BelgeDeposu oku({String docs = 'docs'}) {
    final belgeler = <Belge>[];
    final klasor = Directory(docs);
    if (klasor.existsSync()) {
      final dosyalar =
          klasor
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.md'))
              .where((f) => !f.path.endsWith('README.md'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in dosyalar) {
        belgeler.add(_belgeOku(f));
      }
    }

    final atiflar = <Atif>[];
    for (final kok in kodKokleri) {
      final d = Directory(kok);
      if (!d.existsSync()) continue;
      final dartlar =
          d
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in dartlar) {
        final satirlar = f.readAsLinesSync();
        for (var i = 0; i < satirlar.length; i++) {
          for (final m in _atif.allMatches(satirlar[i])) {
            atiflar.add(
              Atif(
                id: m.group(1)!,
                surum: m.group(2) == null ? null : int.parse(m.group(2)!),
                dosya: f.path,
                satir: i + 1,
              ),
            );
          }
        }
      }
    }

    // Test atıfları: "kodda" için değil "sınanmış" için (16.8).
    for (final kok in testKokleri) {
      final d = Directory(kok);
      if (!d.existsSync()) continue;
      final dartlar =
          d
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in dartlar) {
        final satirlar = f.readAsLinesSync();
        for (var i = 0; i < satirlar.length; i++) {
          for (final m in _atif.allMatches(satirlar[i])) {
            atiflar.add(
              Atif(
                id: m.group(1)!,
                surum: m.group(2) == null ? null : int.parse(m.group(2)!),
                dosya: f.path,
                satir: i + 1,
                test: true,
              ),
            );
          }
        }
      }
    }

    // Yan belgeler README'nin tablosundan (16.9).
    final yanBelgeler = <YanBelge>[];
    final yanHatalari = <String>[];
    final readme = File('$docs/README.md');
    if (readme.existsSync()) {
      var icinde = false;
      final satirlar = readme.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final s = satirlar[i];
        if (s.startsWith('## ')) {
          icinde = s.trim() == '## Yan belgeler';
          continue;
        }
        if (!icinde) continue;
        final m = _yanSatir.firstMatch(s);
        if (m == null) continue;
        final ad = m.group(1)!;
        if (ad == 'Belge' || ad.startsWith('---')) continue;
        final durum = m.group(3)!.trim();
        if (durum == 'dışarıda') {
          yanBelgeler.add(YanBelge(ad: ad, adres: m.group(2)!, durum: durum));
          continue;
        }
        final tas = RegExp(
          r'^taşındı\s*(?:→|->)\s*`?([\w\-. ]+\.md)`?',
        ).firstMatch(durum);
        if (tas == null) {
          yanHatalari.add(
            '$docs/README.md:${i + 1}: yan belge "$ad" durumu `dışarıda` ya da '
            '`taşındı → dosya.md` olmalı',
          );
          continue;
        }
        yanBelgeler.add(
          YanBelge(
            ad: ad,
            adres: m.group(2)!,
            durum: 'taşındı',
            hedef: tas.group(1),
          ),
        );
      }
    }

    final izYolu = File('$docs/$izDosyasi');
    final eskiIzler = <String, Map<String, dynamic>>{};
    if (izYolu.existsSync()) {
      final ham = jsonDecode(izYolu.readAsStringSync());
      if (ham is Map<String, dynamic>) {
        for (final e in ham.entries) {
          if (e.value is Map<String, dynamic>) {
            eskiIzler[e.key] = e.value as Map<String, dynamic>;
          }
        }
      }
    }

    return BelgeDeposu._(
      belgeler: belgeler,
      atiflar: atiflar,
      eskiIzler: eskiIzler,
      docs: docs,
      yanBelgeler: yanBelgeler,
      yanHatalari: yanHatalari,
    );
  }

  static Belge _belgeOku(File f) {
    final metin = f.readAsStringSync();
    final satirlar = metin.split('\n');
    final hatalar = <String>[];
    final onBilgi = <String, String>{};
    var i = 0;
    if (satirlar.isNotEmpty && satirlar.first.trim() == '---') {
      i = 1;
      while (i < satirlar.length && satirlar[i].trim() != '---') {
        final s = satirlar[i];
        final k = s.indexOf(':');
        if (k > 0) {
          onBilgi[s.substring(0, k).trim()] = s.substring(k + 1).trim();
        }
        i++;
      }
      i++;
    } else {
      hatalar.add('${f.path}: ön bilgi (---) yok');
    }
    for (final zorunlu in const ['alan', 'ad', 'tur']) {
      if (!onBilgi.containsKey(zorunlu)) {
        hatalar.add('${f.path}: ön bilgide `$zorunlu:` yok');
      }
    }

    final kararlar = <Karar>[];
    final belgeAlani = int.tryParse(onBilgi['alan'] ?? '');
    final gorulen = <String>{};
    // Karar yalnız kural belgesinde yaşar; tablo ve harita üretilir ve
    // onların `## 06 · …` başlıkları alan başlığıdır, karar değil.
    final kararTasir = onBilgi['tur'] == 'kural';
    for (var j = i; kararTasir && j < satirlar.length; j++) {
      final m = _baslik.firstMatch(satirlar[j]);
      if (m == null) {
        if (satirlar[j].startsWith('## ') &&
            RegExp(r'^## \d').hasMatch(satirlar[j])) {
          hatalar.add(
            '${f.path}:${j + 1}: karar başlığı biçimi '
            '`## 06.3 · Başlık` olmalı: "${satirlar[j]}"',
          );
        }
        continue;
      }
      final alan = int.parse(m.group(1)!);
      final no = int.parse(m.group(2)!);
      final baslik = m.group(3)!.trim();
      final id = '${m.group(1)}.$no';
      if (belgeAlani != null && alan != belgeAlani) {
        hatalar.add('${f.path}:${j + 1}: $id belgenin alanı $belgeAlani değil');
      }
      if (!gorulen.add(id)) {
        hatalar.add('${f.path}:${j + 1}: $id iki kez tanımlı');
      }
      // Durum satırı: başlıktan sonraki ilk boş olmayan satır.
      var k = j + 1;
      while (k < satirlar.length && satirlar[k].trim().isEmpty) {
        k++;
      }
      final d = k < satirlar.length ? _durum.firstMatch(satirlar[k]) : null;
      if (d == null) {
        hatalar.add(
          '${f.path}:${j + 1}: $id başlığının hemen altında '
          '`Durum: kodda · s1` satırı yok',
        );
        continue;
      }
      // Gövde: durumdan sonraki ilk `## ` başlığa kadar.
      var son = k + 1;
      while (son < satirlar.length && !satirlar[son].startsWith('## ')) {
        son++;
      }
      kararlar.add(
        Karar(
          alan: alan,
          no: no,
          baslik: baslik,
          durum: KararDurumu.parse(d.group(1)!)!,
          surum: int.parse(d.group(2)!),
          not: d.group(3)?.trim(),
          dosya: f.path,
          satir: j + 1,
          govde: satirlar.sublist(k + 1, son).join('\n'),
        ),
      );
    }
    return Belge(
      yol: f.path,
      onBilgi: onBilgi,
      kararlar: kararlar,
      hatalar: hatalar,
      metin: metin,
    );
  }

  Map<String, Karar> get kararlar => {
    for (final b in belgeler)
      for (final k in b.kararlar) k.id: k,
  };

  /// Yalnız KOD atıfları — "kodda" bunu sorar.
  Map<String, List<Atif>> get atifHaritasi {
    final m = <String, List<Atif>>{};
    for (final a in atiflar) {
      if (a.test) continue;
      m.putIfAbsent(a.id, () => []).add(a);
    }
    return m;
  }

  /// Yalnız TEST atıfları — "sınanmış" bunu sorar (16.8).
  Map<String, List<Atif>> get testAtifHaritasi {
    final m = <String, List<Atif>>{};
    for (final a in atiflar) {
      if (!a.test) continue;
      m.putIfAbsent(a.id, () => []).add(a);
    }
    return m;
  }

  /// Kodda ama hiçbir test anmıyor. Liste bir cırcır: kök test ilan edilen
  /// sayıyı aşmadığını sınıyor, atıf eklendikçe sayı düşürülüyor.
  /// KARAR 16.8 s1
  List<Karar> get sinanmamis {
    final testler = testAtifHaritasi;
    return kararlar.values
        .where(
          (k) =>
              k.durum == KararDurumu.kodda &&
              (testler[k.id] ?? const []).isEmpty,
        )
        .toList()
      ..sort(kararSirasi);
  }

  Iterable<Belge> get kurallar => belgeler.where((b) => b.kural);

  Iterable<Belge> get defterler => belgeler.where((b) => b.tur == 'defter');

  /// Borç defterinin maddeleri — biçim hataları ikinci listede (16.9).
  /// KARAR 16.9 s1
  (List<BorcMaddesi>, List<String>) borclariOku() {
    final maddeler = <BorcMaddesi>[];
    final hatalar = <String>[];
    for (final b in defterler) {
      final satirlar = b.metin.split('\n');
      for (var i = 0; i < satirlar.length; i++) {
        final m = _borcBaslik.firstMatch(satirlar[i]);
        if (m == null) continue;
        var j = i + 1;
        while (j < satirlar.length && satirlar[j].trim().isEmpty) {
          j++;
        }
        final durumSatiri = j < satirlar.length ? satirlar[j] : '';
        final d = _borcDurum.firstMatch(durumSatiri);
        if (d == null) {
          hatalar.add(
            '${b.yol}:${i + 1}: ${m.group(1)} durumsuz — başlığın altına '
            '`Durum: açık|izleniyor|kapandı · Kaynak: … · tarih` yaz',
          );
          continue;
        }
        if (!_tarih.hasMatch(durumSatiri)) {
          hatalar.add('${b.yol}:${j + 1}: ${m.group(1)} tarihsiz');
        }
        final kararlar = <String>[];
        final alanlar = <int>[];
        final kaynak = durumSatiri.contains('Kaynak:')
            ? durumSatiri.substring(durumSatiri.indexOf('Kaynak:') + 7)
            : '';
        for (final parca in kaynak.split(RegExp(r'\s*[·,]\s*'))) {
          final t = parca.trim();
          if (RegExp(r'^\d{2}\.\d+$').hasMatch(t)) {
            kararlar.add(t);
          } else if (RegExp(r'^\d{1,2}$').hasMatch(t)) {
            alanlar.add(int.parse(t));
          }
        }
        maddeler.add(
          BorcMaddesi(
            id: m.group(1)!,
            baslik: m.group(2)!.trim(),
            durum: d.group(1)!,
            kararlar: kararlar,
            alanlar: alanlar,
            satir: i + 1,
          ),
        );
      }
    }
    return (maddeler, hatalar);
  }

  /// Etiket sayımı: kaç girdi, kaç türetilen etiket doğrulanıyor (16.7).
  Map<String, int> etiketSayimi() {
    final girdiler = {for (final g in TasarimGirdileri.hepsi) g.ad};
    var girdi = 0;
    var turetilen = 0;
    for (final b in kurallar) {
      for (final m in _etiket.allMatches(b.metin)) {
        final ad = m.group(1)!;
        if (m.group(2) == null && girdiler.contains(ad)) {
          girdi++;
        } else if (TuretilenKaydi.islevler.containsKey(ad)) {
          turetilen++;
        }
      }
    }
    return {'girdi': girdi, 'turetilen': turetilen};
  }

  /// Dört yönlü denetim. Boş liste = iki taraf da taze.
  List<Bulgu> denetle() {
    final bulgular = <Bulgu>[];
    final kararlar = this.kararlar;
    final atifHaritasi = this.atifHaritasi;

    // SINANMAMIŞ KARAR BULGUDUR (16.8). Cırcır sıfıra indiği gün kural
    // sertleşiyor: bir karar "kodda" diyorsa onu sınayan bir test olmak
    // zorunda. Kod atıfı kararın kodlandığını söylüyor, testi ise kodun
    // hâlâ o cümleyi yaptığını.
    for (final k in sinanmamis) {
      bulgular.add(
        Bulgu(
          BulguTuru.kodEskimis,
          '${k.id} · ${k.baslik}: kodda ama hiçbir test anmıyor — kararı '
          'sınayan teste `// KARAR ${k.id} s${k.surum}` ekle',
        ),
      );
    }

    // Biçim.
    for (final b in belgeler) {
      for (final h in b.hatalar) {
        bulgular.add(Bulgu(BulguTuru.bicim, h));
      }
      if (b.tur == 'tablo' && !b.uretilmis) {
        bulgular.add(
          Bulgu(
            BulguTuru.bicim,
            '${b.yol}: tablo belgesi üretici damgası taşımıyor — tablolar elle '
            'yazılmaz, `BelgeUretici` basar',
          ),
        );
      }
    }

    // Test türleri: her test dosyası beş türden birini (ya da dışını) ilan
    // eder; ilan etmeyen ya da bilinmeyen tür yazan dosya biçim hatası.
    for (final e in testTurleri().entries) {
      if (e.value.isEmpty) {
        bulgular.add(
          Bulgu(
            BulguTuru.bicim,
            '${e.key}: test türü ilan etmiyor — dosyanın başına '
            "`@Tags(['aralik'])` ve `library;` yaz (karar 16.1)",
          ),
        );
        continue;
      }
      for (final etiket in e.value) {
        // Nitelik etiketi tür değil (16.1): `zaman` gerçek zamana bağlı
        // ölçümü işaretler, sayıma girmez ve yük altında ayrılır (B8).
        if (testNitelikleri.contains(etiket)) continue;
        if (TestTuru.parse(etiket) == null) {
          bulgular.add(
            Bulgu(
              BulguTuru.bicim,
              '${e.key}: `$etiket` bilinen bir test türü değil — '
              '${TestTuru.values.map((t) => t.etiket).join(' · ')}',
            ),
          );
        }
      }
    }

    // Kod → belge: andığı karar var mı, sürümü tutuyor mu.
    for (final a in atiflar) {
      final k = kararlar[a.id];
      if (k == null) {
        bulgular.add(
          Bulgu(
            BulguTuru.kodEskimis,
            '${a.yer}: KARAR ${a.id} belgede yok — karar kaldırıldıysa atıfı '
            'sil, yeni bir karar ise belgeye yaz',
          ),
        );
        continue;
      }
      if (a.surum == null) {
        bulgular.add(
          Bulgu(
            BulguTuru.kodEskimis,
            '${a.yer}: KARAR ${a.id} sürümsüz — `KARAR ${a.id} s${k.surum}` yaz',
          ),
        );
      } else if (a.surum != k.surum) {
        bulgular.add(
          Bulgu(
            BulguTuru.kodEskimis,
            '${a.yer}: KARAR ${a.id} s${a.surum} anıyor, belge s${k.surum}'
            '${a.surum! < k.surum ? ' — karar değişti, kodu gözden geçir ve uyuyorsa sürümü güncelle' : ' — belgede olmayan bir sürüm'}',
          ),
        );
      }
    }

    // Belge → kod: durum ile atıf tutarlı mı.
    for (final k in kararlar.values) {
      final atiflari = atifHaritasi[k.id] ?? const [];
      if (k.durum.atifIster && atiflari.isEmpty) {
        bulgular.add(
          Bulgu(
            BulguTuru.belgeEskimis,
            '${k.dosya}:${k.satir}: ${k.id} "kodda" diyor ama kod anmıyor — '
            'uygulandıysa koda `// KARAR ${k.id} s${k.surum}` yaz, '
            'uygulanmadıysa durumu `belgede` yap',
          ),
        );
      }
      if (!k.durum.atifIster && atiflari.isNotEmpty) {
        bulgular.add(
          Bulgu(
            BulguTuru.belgeEskimis,
            '${k.dosya}:${k.satir}: ${k.id} "${k.durum.etiket}" diyor ama kod '
            'anıyor (${atiflari.map((a) => a.yer).join(', ')}) — '
            'uygulandıysa durumu `kodda` yap',
          ),
        );
      }
    }

    // Etiketli sayılar ↔ tepe tablo.
    final girdiler = {for (final g in TasarimGirdileri.hepsi) g.ad: g};
    for (final b in kurallar) {
      final satirlar = b.metin.split('\n');
      Karar? icinde;
      for (var i = 0; i < satirlar.length; i++) {
        final s = satirlar[i];
        if (s.startsWith('## ')) {
          icinde = null;
          for (final k in b.kararlar) {
            if (k.satir == i + 1) icinde = k;
          }
        }
        for (final m in _etiket.allMatches(s)) {
          final ad = m.group(1)!;
          final argMetni = m.group(2);
          final ham = m.group(3)!;
          final yuzde = ham.startsWith('%');
          final yazilan = yuzde ? ham.substring(1) : ham;
          final etiket = m.group(0)!;
          final g = argMetni == null ? girdiler[ad] : null;
          final islev = TuretilenKaydi.islevler[ad];
          final kodda = icinde == null || icinde.durum == KararDurumu.kodda;
          if (g == null && islev == null) {
            if (kodda) {
              bulgular.add(
                Bulgu(
                  BulguTuru.belgeEskimis,
                  '${b.yol}:${i + 1}: `$ad` ne tepe tabloda ne türetilen '
                  'kaydında — ad değiştiyse etiketi düzelt, türetilense '
                  '`TuretilenKaydi.islevler`e ekle; henüz kodlanmadıysa karar '
                  '`belgede` olmalı',
                ),
              );
            }
            continue;
          }
          final deger = turkceSayi(yazilan);
          if (deger == null) {
            bulgular.add(
              Bulgu(BulguTuru.bicim, '${b.yol}:${i + 1}: $etiket sayı değil'),
            );
            continue;
          }
          // Türetilen: argümanları çöz, kayıttan hesapla (16.7).
          final num beklenen;
          final String kaynak;
          if (g != null) {
            beklenen = g.deger;
            kaynak = 'tepe tablo';
          } else {
            final args = <num>[];
            var bozuk = false;
            for (final a in (argMetni ?? '').split(',')) {
              if (a.trim().isEmpty) continue;
              final v = turkceSayi(a.trim());
              if (v == null) bozuk = true;
              args.add(v ?? 0);
            }
            final hesap = bozuk ? null : TuretilenKaydi.hesapla(ad, args);
            if (hesap == null) {
              bulgular.add(
                Bulgu(
                  BulguTuru.bicim,
                  '${b.yol}:${i + 1}: $etiket — `$ad` '
                  '${islev!.argSayisi} argüman ister',
                ),
              );
              continue;
            }
            beklenen = yuzde ? hesap * 100 : hesap;
            kaynak = 'türetilen kaydı';
          }
          final tolerans = 0.5 * math.pow(10, -ondalikSayisi(yazilan)) + 1e-12;
          if ((beklenen - deger).abs() > tolerans) {
            final gosterim = g != null
                ? BelgeUretici.girdiDegeri(g.deger)
                : BelgeUretici.sayi(
                    beklenen,
                    ondalik: ondalikSayisi(yazilan) + 1,
                  );
            bulgular.add(
              Bulgu(
                BulguTuru.belgeEskimis,
                '${b.yol}:${i + 1}: $etiket yazıyor, $kaynak '
                '${yuzde ? '%' : ''}$gosterim diyor',
              ),
            );
          }
        }
      }
    }

    // Alan kaydı ↔ belge: harita kodu belgeyi izler.
    for (final b in kurallar) {
      final alan = b.alan;
      if (alan == null) continue;
      final kayit = TasarimHaritasi.byNo(alan);
      if (kayit == null) {
        bulgular.add(
          Bulgu(BulguTuru.kodEskimis, '${b.yol}: alan $alan haritada yok'),
        );
        continue;
      }
      final belgedekiler = b.kararlar
          .where((k) => k.durum != KararDurumu.kaldirildi)
          .map((k) => k.baslik)
          .toList();
      if (!_ayni(kayit.sahiplendigi, belgedekiler)) {
        bulgular.add(
          Bulgu(
            BulguTuru.kodEskimis,
            'tasarim_alanlari.dart alan ${kayit.no} `sahiplendigi` belgeden '
            'ayrışmış; belge kaynak, listeyi şuna eşitle:\n'
            '${belgedekiler.map((s) => "  '$s',").join('\n')}',
          ),
        );
      }
      if (kayit.ad != b.ad) {
        bulgular.add(
          Bulgu(
            BulguTuru.kodEskimis,
            'tasarim_alanlari.dart alan ${kayit.no} adı "${kayit.ad}", '
            'belge "${b.ad}"',
          ),
        );
      }
      final tablo = b.onBilgi['tablo'];
      if (tablo != null && !File('$docs/$tablo').existsSync()) {
        bulgular.add(
          Bulgu(BulguTuru.belgeEskimis, '${b.yol}: tablo `$tablo` yok'),
        );
      }
    }

    // Borç defteri: her madde durumlu, tarihli ve bir karara ya da alana
    // bağlı; yabancı anahtar var olmalı (16.9).
    final (borclar, borcHatalari) = borclariOku();
    for (final h in borcHatalari) {
      bulgular.add(Bulgu(BulguTuru.bicim, h));
    }
    for (final m in borclar) {
      if (m.kararlar.isEmpty && m.alanlar.isEmpty) {
        bulgular.add(
          Bulgu(
            BulguTuru.belgeEskimis,
            'borç defteri ${m.id} kaynaksız — `Kaynak:` satırına en az bir '
            'karar (08.1) ya da alan (14) yaz',
          ),
        );
      }
      for (final id in m.kararlar) {
        if (!kararlar.containsKey(id)) {
          bulgular.add(
            Bulgu(
              BulguTuru.belgeEskimis,
              'borç defteri ${m.id}: karar $id yok — kaldırıldıysa kaynağı '
              'güncelle',
            ),
          );
        }
      }
      for (final no in m.alanlar) {
        if (TasarimHaritasi.byNo(no) == null) {
          bulgular.add(
            Bulgu(
              BulguTuru.belgeEskimis,
              'borç defteri ${m.id}: alan $no haritada yok',
            ),
          );
        }
      }
    }

    // Yan belgeler: taşındı denen hedef `docs/` altında olmalı (16.9).
    for (final h in yanHatalari) {
      bulgular.add(Bulgu(BulguTuru.bicim, h));
    }
    for (final y in yanBelgeler) {
      if (y.hedef != null && !File('$docs/${y.hedef}').existsSync()) {
        bulgular.add(
          Bulgu(
            BulguTuru.belgeEskimis,
            'README yan belge "${y.ad}" taşındı → `${y.hedef}` diyor ama dosya yok',
          ),
        );
      }
    }

    // Şüpheli bağlantı: metin değişti, sürüm artmadı.
    for (final k in kararlar.values) {
      final eski = eskiIzler[k.id];
      if (eski == null) continue;
      final eskiSurum = eski['s'];
      final eskiIz = eski['iz'];
      if (eskiSurum == k.surum && eskiIz != k.iz) {
        bulgular.add(
          Bulgu(
            BulguTuru.supheli,
            '${k.dosya}:${k.satir}: ${k.id} metni değişti ama sürüm s${k.surum} '
            'kaldı — tasarım değiştiyse sürümü artır (atıflar da eskir), yalnız '
            'anlatım düzeldiyse yeniden üretilen $izDosyasi dosyasını commit\'e '
            'ekle',
          ),
        );
      }
    }

    return bulgular;
  }

  /// Sayısal sıra: 06.2, 06.10 — sözlük sırası değil.
  static int kararSirasi(Karar a, Karar b) =>
      a.alan != b.alan ? a.alan.compareTo(b.alan) : a.no.compareTo(b.no);

  static bool _ayni(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// `karar-izi.json` içeriği — deterministik, sıralı.
  String izDosyasiUret() {
    final k = kararlar.values.toList()..sort(kararSirasi);
    final m = <String, dynamic>{
      for (final x in k) x.id: {'s': x.surum, 'iz': x.iz, 'baslik': x.baslik},
    };
    return '${const JsonEncoder.withIndent('  ').convert(m)}\n';
  }

  /// `00-harita.md` — izlenebilirlik matrisi. Elle yazılan haritanın yerine
  /// geçiyor: alanlar, kararlar, durumlar, atıflar ve kodlanacaklar listesi
  /// belgelerden ve koddan derleniyor.
  String haritaUret() {
    final kararlar = this.kararlar.values.toList()..sort(kararSirasi);
    final atifHaritasi = this.atifHaritasi;
    final sb = StringBuffer()
      ..writeln('---')
      ..writeln('alan: 0')
      ..writeln('ad: Tasarım Alanları Haritası')
      ..writeln('tur: harita')
      ..writeln('---')
      ..writeln(BelgeUretici.damga)
      ..writeln()
      ..writeln('# Tasarım Alanları Haritası')
      ..writeln()
      ..writeln(
        'Belgelerden ve koddan derlenen izlenebilirlik matrisi. Belge kaynak, '
        'kod uygulama; ikisinin arası bu tablo. Kural: [README](README.md). '
        'Kodlarken açığa çıkan sorular ve borçlar: '
        '[Borç Defteri](borc-defteri.md).',
      )
      ..writeln();

    int say(KararDurumu d) => kararlar.where((k) => k.durum == d).length;
    final testAtiflari = testAtifHaritasi;
    final kodAtifSayisi = atiflar.where((a) => !a.test).length;
    final testAtifSayisi = atiflar.length - kodAtifSayisi;
    final sinanmamisListe = sinanmamis;
    final etiketler = etiketSayimi();
    sb
      ..writeln(
        '**Kapsama:** ${kararlar.length} karar · kodda ${say(KararDurumu.kodda)} '
        '· belgede ${say(KararDurumu.belgede)} · açık ${say(KararDurumu.acik)} '
        '· kaldırıldı ${say(KararDurumu.kaldirildi)} '
        '· ayrılmış ${say(KararDurumu.ayrilmis)} · kod atıfı $kodAtifSayisi '
        '· test atıfı $testAtifSayisi · sınanmış '
        '${say(KararDurumu.kodda) - sinanmamisListe.length}/${say(KararDurumu.kodda)} kodda '
        '· etiket ${etiketler['girdi']} girdi, ${etiketler['turetilen']} türetilen.',
      )
      ..writeln();

    final alanlar = TasarimHaritasi.hepsi.toList()
      ..sort((a, b) => a.no.compareTo(b.no));
    final tasinmis = <int>{};
    for (final alan in alanlar) {
      Belge? kural;
      for (final b in kurallar) {
        if (b.alan == alan.no) kural = b;
      }
      if (kural == null) continue;
      tasinmis.add(alan.no);
      final no = alan.no.toString().padLeft(2, '0');
      final tablo = kural.onBilgi['tablo'];
      sb
        ..writeln('## $no · ${alan.ad}')
        ..writeln()
        ..write('[Kural](${_dosyaAdi(kural.yol)})');
      if (tablo != null) sb.write(' · [Tablo]($tablo)');
      sb
        ..writeln(' · katman: ${alan.katman.name}')
        ..writeln()
        ..writeln('| Karar | Durum | Sürüm | Kod | Test |')
        ..writeln('|---|---|---|---|---|');
      for (final k in kural.kararlar) {
        List<String> dosyalari(Map<String, List<Atif>> harita) =>
            (harita[k.id] ?? const <Atif>[])
                .map((a) => a.dosya)
                .toSet()
                .toList()
              ..sort();
        String hucre(List<String> d) =>
            d.isEmpty ? '—' : d.map((x) => '`${_kisa(x)}`').join(', ');
        sb.writeln(
          '| ${k.id} · ${k.baslik} | ${k.durum.etiket} | s${k.surum} | '
          '${hucre(dosyalari(atifHaritasi))} | ${hucre(dosyalari(testAtiflari))} |',
        );
      }
      sb.writeln();
    }

    final bekleyen = alanlar.where((a) => !tasinmis.contains(a.no)).toList();
    if (bekleyen.isNotEmpty) {
      sb
        ..writeln('## Taşınmamış alanlar')
        ..writeln()
        ..writeln(
          'Kural belgesi henüz `docs/` altında değil; haritanın kod kaydı '
          '(`tasarim_alanlari.dart`) tek kaynak. Eski belgeler README\'deki '
          'taşıma tablosunda.',
        )
        ..writeln();
      for (final a in bekleyen) {
        sb.writeln(
          '- ${a.no.toString().padLeft(2, '0')} · ${a.ad} — '
          '${a.sahiplendigi.length} karar',
        );
      }
      sb.writeln();
    }

    final is_ = kararlar
        .where(
          (k) => k.durum == KararDurumu.belgede || k.durum == KararDurumu.acik,
        )
        .toList();
    sb
      ..writeln('## Kodlanacaklar')
      ..writeln()
      ..writeln(
        is_.isEmpty
            ? 'Belgedeki her karar kodda.'
            : 'Belgede olup kodda olmayanlar. Liste derlenir, hatırlanmaz.',
      )
      ..writeln();
    for (final k in is_) {
      sb.writeln(
        '- **${k.id} · ${k.baslik}** — ${k.durum.etiket}'
        '${k.not == null ? '' : ' · ${k.not}'}',
      );
    }
    sb.writeln();

    sb
      ..writeln('## Sınanmamış')
      ..writeln()
      ..writeln(
        sinanmamisListe.isEmpty
            ? 'Kodda olan her kararı en az bir test anıyor (16.8).'
            : 'Kodda ama hiçbir test anmıyor (16.8). Bir cırcır: kök test '
                  'ilan edilen sayıyı aşmadığını sınıyor; her `// KARAR` '
                  'atıfı bir satır siliyor. ${sinanmamisListe.length} karar.',
      )
      ..writeln();
    for (final k in sinanmamisListe) {
      sb.writeln('- ${k.id} · ${k.baslik}');
    }
    sb.writeln();

    final (borclar, _) = borclariOku();
    final acikBorclar = borclar.where((m) => m.acik).toList();
    sb
      ..writeln('## Borç defteri')
      ..writeln()
      ..writeln(
        '[Defter](borc-defteri.md): ${borclar.length} madde, '
        '${acikBorclar.length} açık ya da izleniyor. Her madde bir karara ya '
        'da alana bağlı; denetim bağı sınıyor (16.9).',
      )
      ..writeln();
    for (final m in acikBorclar) {
      final kaynak = [
        ...m.kararlar,
        ...m.alanlar.map((a) => a.toString().padLeft(2, '0')),
      ];
      sb.writeln(
        '- **${m.id} · ${m.baslik}** — ${m.durum}'
        '${kaynak.isEmpty ? '' : ' · ${kaynak.join(' · ')}'}',
      );
    }
    sb.writeln();

    final disarida = yanBelgeler.where((y) => y.disarida).toList();
    sb
      ..writeln('## Dışarıda bekleyen')
      ..writeln()
      ..writeln(
        disarida.isEmpty
            ? 'README\'nin yan belge tablosunda dışarıda bekleyen tasarım yok; '
                  '${yanBelgeler.length} yan belgenin hepsi taşındı (16.9).'
            : '`docs/` dışında yazılmış, henüz taşınmamış tasarımlar (16.9). '
                  'Kodlanacaklar listesine girmezler: önce belge açılır.',
      )
      ..writeln();
    for (final y in disarida) {
      sb.writeln('- **${y.ad}** — ${y.adres}');
    }
    sb.writeln();

    final sayim = testTuruSayimi();
    final dosyaSayisi = testTurleri().length;
    sb
      ..writeln('## Test türleri')
      ..writeln()
      ..writeln(
        'Alan 16\'nın beş türü (16.1). Her test dosyası türünü başında ilan '
        'ediyor; bir dosya birden çok tür taşıyabilir. $dosyaSayisi test '
        'dosyası, ${sayim[TestTuru.disi]} tanesi denetim dışı.',
      )
      ..writeln()
      ..writeln('| Tür | Dosya |')
      ..writeln('|---|---:|');
    for (final t in TestTuru.besi) {
      sb.writeln('| ${t.ad} | ${sayim[t]} |');
    }
    sb.writeln();

    final ayrilmis = kararlar
        .where((k) => k.durum == KararDurumu.ayrilmis)
        .toList();
    if (ayrilmis.isNotEmpty) {
      sb
        ..writeln('## Ayrılmışlar')
        ..writeln()
        ..writeln(
          'Bilerek kodsuz: ileriye yer ayıran şemalar ve süreç kuralları. '
          'Kodlanacak iş değil; sistem geldiğinde önce belge açılır.',
        )
        ..writeln();
      for (final k in ayrilmis) {
        sb.writeln(
          '- **${k.id} · ${k.baslik}**'
          '${k.not == null ? '' : ' — ${k.not}'}',
        );
      }
      sb.writeln();
    }
    return sb.toString();
  }

  static String _dosyaAdi(String yol) => yol.split('/').last;

  static String _kisa(String yol) => yol
      .replaceFirst('packages/voidspace_core/lib/src/', 'core/')
      .replaceFirst('packages/voidspace_core/test/', 'core-test/');
}
