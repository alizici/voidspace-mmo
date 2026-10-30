import '../design/tasarim_girdileri.dart';

/// Formasyonun EĞİLİMİ — imzalı takasın yönü.
enum FormasyonEgilimi {
  /// Aktarım yukarı, dayanıklılık aşağı: droidler geminin çarpanlarından
  /// daha çok pay alır, daha kolay erir.
  saldiri('Saldırı'),

  /// Aktarım aşağı, dayanıklılık yukarı.
  savunma('Savunma'),

  /// Takas yok; tepe tablodaki σ ve çıplak dayanıklılık.
  denge('Denge');

  const FormasyonEgilimi(this.ad);

  final String ad;
}

/// Formasyonun GEOMETRİSİ — istemcinin çizdiği yuvalar. Sanat, denge değil.
enum FormasyonSekli {
  kabuk,
  ok,
  mizrak,
  yildiz,
  kiskac,
  ciftOk,
  elmas,
  kama,
  guve,
  yengec,
  kalp,
  baraj,
  yarasa,
  halka,
  burgu,
  oncu,
  kubbe,
  cark,
  capraz,
  dalga,
}

/// FORMASYON — droid grubunun DAVRANIŞI (05.1'in üçüncü sağlayıcı tipi).
///
/// Aynı anda yalnız BİRİ aktif. Etkisi imzalı bir takas: eğilim aktarım
/// katsayısını bir yöne, droid dayanıklılığını öteki yöne `formasyonTakasi`
/// kadar iter. Yirmi formasyon, tek girdi: her formasyona ayrı yüzdeler
/// yazmak tepe tabloya kırk sayı koymak olurdu ve kırk sayı kırk ayar kolu
/// demek. Formasyonlar birbirinden geometriyle ve eğilimle ayrılıyor, sayıyla
/// değil. Geometri sanatın; burada yalnız adı var.
/// KARAR 05.9 s1
class Formasyon {
  const Formasyon(this.id, this.ad, this.sekil, this.egilim);

  final String id;
  final String ad;
  final FormasyonSekli sekil;
  final FormasyonEgilimi egilim;

  /// Bu formasyondaki AKTARIM katsayısı (σ), `[0, 1]` içinde.
  double get aktarim => switch (egilim) {
    FormasyonEgilimi.saldiri =>
      TasarimGirdileri.aktarimKatsayisi + TasarimGirdileri.formasyonTakasi,
    FormasyonEgilimi.savunma =>
      TasarimGirdileri.aktarimKatsayisi - TasarimGirdileri.formasyonTakasi,
    FormasyonEgilimi.denge => TasarimGirdileri.aktarimKatsayisi,
  }.clamp(0.0, 1.0);

  /// Droid HAVUZUNUN çarpanı — takasın öteki yüzü.
  ///
  /// Adı "dayanıklılık" değil ve olamaz: o ad 05.10'da droidin ömür
  /// sayacının. Bu, dövüşte soğurulan hasar.
  double get havuzCarpani => switch (egilim) {
    FormasyonEgilimi.saldiri => 1 - TasarimGirdileri.formasyonTakasi,
    FormasyonEgilimi.savunma => 1 + TasarimGirdileri.formasyonTakasi,
    FormasyonEgilimi.denge => 1.0,
  };

  /// Varsayılan: takas yok. Formasyon seçmemiş oyuncu bununla uçuyor.
  static const Formasyon varsayilan = Formasyon(
    'kabuk',
    'Kabuk',
    FormasyonSekli.kabuk,
    FormasyonEgilimi.denge,
  );

  /// Yirmi formasyon. Adlar eski merdivenden (turtle, arrow, lance …).
  static const List<Formasyon> hepsi = [
    varsayilan,
    Formasyon('ok', 'Ok', FormasyonSekli.ok, FormasyonEgilimi.saldiri),
    Formasyon(
      'mizrak',
      'Mızrak',
      FormasyonSekli.mizrak,
      FormasyonEgilimi.saldiri,
    ),
    Formasyon(
      'yildiz',
      'Yıldız',
      FormasyonSekli.yildiz,
      FormasyonEgilimi.denge,
    ),
    Formasyon(
      'kiskac',
      'Kıskaç',
      FormasyonSekli.kiskac,
      FormasyonEgilimi.saldiri,
    ),
    Formasyon(
      'cift-ok',
      'Çift Ok',
      FormasyonSekli.ciftOk,
      FormasyonEgilimi.saldiri,
    ),
    Formasyon('elmas', 'Elmas', FormasyonSekli.elmas, FormasyonEgilimi.savunma),
    Formasyon('kama', 'Kama', FormasyonSekli.kama, FormasyonEgilimi.saldiri),
    Formasyon('guve', 'Güve', FormasyonSekli.guve, FormasyonEgilimi.denge),
    Formasyon(
      'yengec',
      'Yengeç',
      FormasyonSekli.yengec,
      FormasyonEgilimi.savunma,
    ),
    Formasyon('kalp', 'Kalp', FormasyonSekli.kalp, FormasyonEgilimi.savunma),
    Formasyon('baraj', 'Baraj', FormasyonSekli.baraj, FormasyonEgilimi.saldiri),
    Formasyon(
      'yarasa',
      'Yarasa',
      FormasyonSekli.yarasa,
      FormasyonEgilimi.denge,
    ),
    Formasyon('halka', 'Halka', FormasyonSekli.halka, FormasyonEgilimi.savunma),
    Formasyon('burgu', 'Burgu', FormasyonSekli.burgu, FormasyonEgilimi.saldiri),
    Formasyon('oncu', 'Öncü', FormasyonSekli.oncu, FormasyonEgilimi.denge),
    Formasyon('kubbe', 'Kubbe', FormasyonSekli.kubbe, FormasyonEgilimi.savunma),
    Formasyon('cark', 'Çark', FormasyonSekli.cark, FormasyonEgilimi.denge),
    Formasyon(
      'capraz',
      'Çapraz',
      FormasyonSekli.capraz,
      FormasyonEgilimi.saldiri,
    ),
    Formasyon('dalga', 'Dalga', FormasyonSekli.dalga, FormasyonEgilimi.savunma),
  ];

  static Formasyon? byId(String? id) {
    for (final f in hepsi) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Kimlik tanınmazsa varsayılan: kayıtta eski ya da bozuk bir ad, oyuncuyu
  /// formasyonsuz bırakmamalı.
  static Formasyon ofId(String? id) => byId(id) ?? varsayilan;
}
