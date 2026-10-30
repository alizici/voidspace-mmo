import 'dart:ui';

import 'atlas_layout.dart';
import 'bastion.dart';
import 'weapon_emitter.dart';

/// Bir gövde kademesinin GEMİ TASARIMI — hangi çizim hangi kademede duruyor.
///
/// Sekiz kademe var ([TasarimGirdileri.govdeKademeSayisi]) ve sekiz tasarım.
/// Yedisi `~/voidspace2` katalogundan geliyor, sekizincisi bu projenin kendi
/// prosedürel gemisi ([Bastion]).
///
/// **Bu dosya bir SANAT kaydı, bir stat kaydı değil.** Gövdenin canı, kalkanı,
/// hızı ve yuvaları `HullClass`'ta ve oradaki her sayı tepe tablodan türüyor.
/// Buradaki tek karar görsel: hangi silüet hangi güç kademesinde duruyor.
///
/// **Sıra neden bu.** İki uç oyuncunun kararı: en güçsüz Firebird, en güçlü bu
/// projenin eriyik-VFX Bastion'u. Aradaki altısı görsel AĞIRLIĞA göre
/// dizildi — motor sayısı, kaide açıklığı ve çizim yoğunluğu. Sıralamanın
/// kendisi türetilmiş bir sayı DEĞİL, sanat kararı; o yüzden burada duruyor ve
/// testi de sıralamayı değil kullanıcı kararlarını koruyor.
///
/// Ölçü tek yönlü: tasarım uzayı → dünya. Sprite'lar 512×512 RGBA ve
/// [ileri]/[geri] erişimine göre ölçekleniyor — dosyanın piksel boyu tasarımın
/// ölçüsünü belirlemiyor.
class GovdeTasarimi {
  const GovdeTasarimi({
    required this.kademe,
    required this.ad,
    required this.ileri,
    required this.geri,
    required this.motorSayisi,
    required this.kaideAcikligi,
    required this.cizildi,
    required this.prosedurel,
    required this.ikon,
    required this.kaideler,
    required this.kaideBoylari,
    required this.kaideGenislikleri,
    required this.not,
  });

  /// 0 tabanlı kademe — [HullClass.all] ile AYNI sıra.
  final int kademe;

  /// Tasarımın KOD adı. Oyuncuya görünen ad `HullClass.adlar[kademe]`.
  ///
  /// İkisi ayrı bilerek: oyuncu "Spectre" uçtuğunu görüyor, kod o gövdenin
  /// çiziminin voidspace2'deki `bastion` sprite'ı olduğunu biliyor.
  final String ad;

  /// Burun ve kuyruk erişimi (tasarım uzayı). Ekran ölçüsü bunlardan çıkıyor:
  /// `erisim = (ileri + geri) / 2` ve her gemi aynı ekran boyuna normalize
  /// ediliyor — yani bu sayılar gücü DEĞİL, çizimin kendi koordinat sistemini
  /// anlatıyor.
  final double ileri;
  final double geri;

  /// Egzoz jeti sayısı — silüetin görsel ağırlığının en okunur ölçüsü.
  final int motorSayisi;

  /// En dıştaki silah kaidesinin |x| değeri (tasarım uzayı).
  final double kaideAcikligi;

  /// Gövde çizimi BU projede var mı.
  ///
  /// Bugün yalnız kademe 8 için `true`. Kalan yedisinin tasarımı belli, yeri
  /// belli, sanatı taşınmadı — atlas mimarisi tek gövde bloğu pişiriyor
  /// (bkz. [AtlasLayout]).
  final bool cizildi;

  /// Gövdesi KODLA mı çiziliyor.
  ///
  /// [ikon] ile karıştırma: ikon her tasarımda var ve hepsi PNG. Bu bayrak
  /// gövdenin OYUNDAKİ çiziminin nereden geleceğini söylüyor — sprite'tan mı,
  /// koddan mı. İkisi ayrı: Dagon'un ikonu PNG ama gövdesi prosedürel.
  final bool prosedurel;

  /// Menüdeki İKON — hangar filo kartı ve mağaza gövde kartı bunu gösteriyor.
  ///
  /// Sekizinin de var ve sekizi de 512×512 saydam PNG. Yedisi voidspace2
  /// katalogundan geldi, sekizincisi `tool/govde_ikonu_test.dart` tarafından
  /// bu projenin kendi sanatından ÜRETİLİYOR.
  ///
  /// İkon olması, gövdenin ÇİZİLDİĞİ anlamına gelmiyor ([cizildi]): uzayda
  /// uçan gemi hâlâ tek atlas bloğundan geliyor. İkon menüde neyin
  /// bekleneceğini gösteriyor, oyunda ne uçtuğunu değil.
  final String ikon;

  /// SİLAH KAİDELERİ — tasarım uzayında, merminin doğduğu noktalar.
  ///
  /// Beşi de aynı topolojide ve bu bir tesadüf değil, bir KURAL: aynalı ön
  /// çift · omurga topu · aynalı arka çift. Ateş sırası ([atesGruplari]) ve
  /// yuva açılma sırası bu topolojiden TÜRÜYOR — hiçbir tasarım kendi grup
  /// listesini yazmıyor, sekiz kez tekrarlanacak bir liste olurdu.
  ///
  /// Koordinatlar tasarım uzayında, PİKSEL DEĞİL. Gemi ekranda `erisim`e göre
  /// normalize ediliyor, yani aynı liste her boyutta doğru yerde duruyor.
  final List<Offset> kaideler;

  /// [kaideler] ile aynı sırada projektör boyları.
  final List<double> kaideBoylari;

  /// [kaideler] ile aynı sırada projektör genişlikleri.
  ///
  /// Genişlik bir süs değil, SINIF: 12 ve üstü omurga topu demek ve o namlu
  /// daha yoğun bobinle çiziliyor. Sekiz tasarımın sekizinde de tek bir
  /// omurga topu var ve hep 2. indekste.
  final List<double> kaideGenislikleri;

  /// Omurga topunun indeksi — genişlikten TÜRETİLİYOR, yazılmıyor.
  int get omurgaKaidesi =>
      kaideGenislikleri.indexWhere((g) => g >= omurgaEsigi);

  /// Ağır/omurga topu eşiği. voidspace2'nin `HardpointSpec.isCentre`
  /// kuralıyla aynı sayı — iki depo aynı silahı farklı sınıflandırmasın.
  static const double omurgaEsigi = 12;

  /// Namlu AĞZI — merminin gerçekten çıktığı nokta, kaidenin kendisi değil.
  ///
  /// Kaide gövdeye oturuyor, namlu ondan `boy` kadar ileride bitiyor. İkisini
  /// karıştırmak ateşi silahtan değil gövdenin içinden çıkarıyor — bu proje o
  /// dersi bir kez aldı (`WeaponEmitter.muzzleOf`).
  List<Offset> get namluAgizlari => [
    for (var i = 0; i < kaideler.length; i++)
      kaideler[i] + WeaponEmitter.muzzleOf(kaideBoylari[i]),
  ];

  /// Kaideler GEMİ-YEREL DÜNYA biriminde — silahın gerçekten durduğu yer.
  ///
  /// İki dönüşüm var ve ikisi de gerekli. Biri tasarım uzayından dünyaya
  /// ([AtlasLayout.designToWorld]): gövde tasarım uzayında orijinde değil,
  /// burnu −y'de uzakta, ve `merkezKaydirmasi` onu ortalıyor. Diğeri
  /// NORMALİZASYON: her tasarımın çizimi ekranda aynı boya getiriliyor, kaide
  /// de onunla birlikte gelmek zorunda — yoksa Nemesis'in topları gövdesinin
  /// dışında durur.
  ///
  /// Tepe tasarımda çarpan 1 ve sonuç `Bastion.worldHardpoints` ile birebir
  /// aynı çıkıyor; testi bunu doğruluyor.
  List<Offset> get dunyaKaideleri {
    final olcek = GovdeTasarimlari.olcekFor(this);
    return [
      for (final k in kaideler)
        AtlasLayout.designToWorld(k, merkezKaydirmasi) * olcek,
    ];
  }

  /// ATEŞ GRUPLARI — yaylımın dalga sırası, topolojiden türetiliyor.
  ///
  /// Omurga önce, sonra ön çift, sonra arka çift: içten dışa. voidspace2 bunu
  /// dıştan içe yapıyordu (`[0,1] → [2] → [3,4]`) ve bu proje sırayı bilerek
  /// çevirdi — omurga topu ağır silah, yaylımı o açmalı.
  ///
  /// Gruplar ÇİFT: bir çiftin yalnız yarısını ateşlemek gemiyi tek kanadı
  /// eksik gösterirdi.
  List<List<int>> get atesGruplari {
    final omurga = omurgaKaidesi;
    // Çiftler BİRBİRİNE göre ayrılıyor, omurgaya göre DEĞİL.
    //
    // İlk yazışta omurgayla karşılaştırıyordu ve Firebird'de çöktü: onun
    // omurga topu burnun ucunda (y −37), iki çift de gerisinde kalıyor —
    // "ön çift" boş çıktı. Omurganın gövdedeki yeri tasarımdan tasarıma
    // değişiyor (Dagon'da +11, Nemesis'te −73), çiftlerin BİRBİRİNE göre
    // sırası ise değişmiyor.
    final yanlar = [
      for (var i = 0; i < kaideler.length; i++)
        if (i != omurga) i,
    ]..sort((a, b) => kaideler[a].dy.compareTo(kaideler[b].dy));
    return [
      [omurga],
      yanlar.take(2).toList()..sort(),
      yanlar.skip(2).toList()..sort(),
    ];
  }

  /// Yerleştirme gerekçesi. Süs değil: bir tasarım yer değiştirdiğinde neyin
  /// bozulduğunu okumak için tek kayıt burası.
  final String not;

  /// Ortalanmış yarı-açıklık.
  double get erisim => (ileri + geri) / 2;

  /// Gövdeyi orijine oturtan dikey kaydırma.
  double get merkezKaydirmasi => (ileri - geri) / 2;
}

/// Sekiz kademenin tasarım kaydı.
abstract final class GovdeTasarimlari {
  /// Kademe sırasıyla — indeks = kademe.
  ///
  /// `const` DEĞİL ve olamaz: tepe kademenin ölçüsü [Bastion] sanatından
  /// okunuyor, elle yazılmıyor. Elle yazılmış bir 47,6 ilk denemede tutmadı —
  /// gerçek erişim 48,72 ve o sayı zırh yolunun sınır kutusundan çalışma
  /// zamanında çıkıyor. Sanat büyüdüğünde kayıt kendiliğinden büyüyor.
  static final List<GovdeTasarimi> hepsi = [
    GovdeTasarimi(
      kademe: 0,
      ad: 'Firebird',
      kaideler: const [
        Offset(-13, -15),
        Offset(13, -15),
        Offset(0, -37),
        Offset(-15, 6),
        Offset(15, 6),
      ],
      kaideBoylari: const [13, 13, 18, 12, 12],
      kaideGenislikleri: const [7, 7, 12, 7, 7],
      prosedurel: false,
      ikon: 'assets/ships/firebird.png',
      ileri: 48,
      geri: 34,
      motorSayisi: 1,
      kaideAcikligi: 15,
      cizildi: false,
      not:
          'Merdivenin dibi. Tek jet ve en dar kaide açıklığı — katalogdaki '
          'en küçük silüet.',
    ),
    GovdeTasarimi(
      kademe: 1,
      ad: 'Lancer',
      kaideler: const [
        Offset(-11, -31),
        Offset(11, -31),
        Offset(0, -58),
        Offset(-18, 7),
        Offset(18, 7),
      ],
      kaideBoylari: const [16, 16, 24, 14, 14],
      kaideGenislikleri: const [7, 7, 12, 7, 7],
      prosedurel: false,
      ikon: 'assets/ships/lancer.png',
      ileri: 78,
      geri: 35,
      motorSayisi: 2,
      kaideAcikligi: 18,
      cizildi: false,
      not:
          'İki jet, uzun ince burun (omurga topu −58). Gövde adı "Vanguard" '
          've mızrak silueti öncü okumasını taşıyor.',
    ),
    GovdeTasarimi(
      kademe: 2,
      ad: 'Bastion (voidspace2 sprite)',
      kaideler: const [
        Offset(-23, -40),
        Offset(23, -40),
        Offset(0, -9),
        Offset(-19, 9),
        Offset(19, 9),
      ],
      kaideBoylari: const [16, 16, 23, 15, 15],
      kaideGenislikleri: const [9, 9, 14, 9, 9],
      prosedurel: false,
      ikon: 'assets/ships/bastion.png',
      ileri: 56,
      geri: 33,
      motorSayisi: 3,
      kaideAcikligi: 23,
      cizildi: false,
      not:
          'Üç jet, kompakt gövde. Bu projenin Bastion\'u DEĞİL — çakışma '
          'assets/ships/README.txt içinde yazılı.',
    ),
    GovdeTasarimi(
      kademe: 3,
      ad: 'Dagon',
      kaideler: const [
        Offset(-17.7, -22.2),
        Offset(17.7, -22.2),
        Offset(0, 11),
        Offset(-30.1, 2.5),
        Offset(30.1, 2.5),
      ],
      kaideBoylari: const [18, 18, 26, 18, 18],
      kaideGenislikleri: const [9, 9, 13, 9, 9],
      prosedurel: true,
      ikon: 'assets/ships/dagon.png',
      ileri: 40.1,
      geri: 32,
      motorSayisi: 3,
      kaideAcikligi: 30,
      cizildi: false,
      not:
          'Prosedürel: önü açık beşgen halka, çapraz kuyruk yüzgeçleri, '
          'jilet kanatlar. Halka silueti gövde adı "Aegis" ile örtüşüyor.',
    ),
    GovdeTasarimi(
      kademe: 4,
      ad: 'Yatagan',
      kaideler: const [
        Offset(-41, -35),
        Offset(41, -35),
        Offset(0, -28),
        Offset(-30, 4),
        Offset(30, 4),
      ],
      kaideBoylari: const [17, 17, 24, 15, 15],
      kaideGenislikleri: const [8, 8, 13, 8, 8],
      prosedurel: false,
      ikon: 'assets/ships/yatagan.png',
      ileri: 48,
      geri: 35,
      motorSayisi: 5,
      kaideAcikligi: 41,
      cizildi: false,
      not:
          'Beş jete ilk çıkan tasarım ve açıklık ±23\'ten ±41\'e sıçrıyor — '
          'merdivenin görsel kırılma noktası.',
    ),
    GovdeTasarimi(
      kademe: 5,
      ad: 'E-Ambassador',
      kaideler: const [
        Offset(-58, -16),
        Offset(58, -16),
        Offset(0, -70),
        Offset(-28, 6),
        Offset(28, 6),
      ],
      kaideBoylari: const [18, 18, 27, 16, 16],
      kaideGenislikleri: const [8, 8, 13, 8, 8],
      prosedurel: true,
      ikon: 'assets/ships/e-ambassador.png',
      ileri: 90,
      geri: 50,
      motorSayisi: 5,
      kaideAcikligi: 58,
      cizildi: false,
      not:
          'Prosedürel ve katalogdaki en hantal gövde: balta kanatları ±88\'e '
          'uzanıyor, modül podları ve roket rafları var. Gövde adı "Colossus".',
    ),
    GovdeTasarimi(
      kademe: 6,
      ad: 'Nemesis',
      kaideler: const [
        Offset(-49, -19),
        Offset(49, -19),
        Offset(0, -73),
        Offset(-28, 6),
        Offset(28, 6),
      ],
      kaideBoylari: const [18, 18, 27, 16, 16],
      kaideGenislikleri: const [8, 8, 13, 8, 8],
      prosedurel: false,
      ikon: 'assets/ships/nemesis.png',
      ileri: 96,
      geri: 48,
      motorSayisi: 5,
      kaideAcikligi: 49,
      cizildi: false,
      not:
          'En büyük sprite tuvali (96/48). Tasarım adı gövde adıyla ZATEN '
          'aynı — kademe 7 gövdesinin adı da "Nemesis".',
    ),
    GovdeTasarimi(
      kademe: 7,
      ad: 'Bastion (eriyik VFX)',
      // Elle KOPYALANMIYOR: sanatın kendisinden okunuyor. Kopya, namlu
      // noktalarının sanattan sessizce ayrışabileceği tek yer olurdu.
      kaideler: Bastion.hardpoints,
      kaideBoylari: Bastion.emitterLengths,
      kaideGenislikleri: Bastion.emitterWidths,
      prosedurel: true,
      ikon: 'assets/ships/bastion_molten.png',
      ileri: Bastion.reach + Bastion.centreOffset,
      geri: Bastion.reach - Bastion.centreOffset,
      motorSayisi: 3,
      kaideAcikligi: 27,
      cizildi: true,
      not:
          'Bu projenin kendi gemisi ve tek çizilmiş gövdesi. Açıklığı dar ama '
          'görsel ağırlığı silüetten değil emissive yığından geliyor: eriyik '
          'dikişler, korlar, ısı buğusu, tek gerçek bloom geçişi.',
    ),
  ];

  /// [kademe] numaralı gövdenin tasarımı.
  static GovdeTasarimi byKademe(int kademe) => hepsi[kademe];

  /// Kademe geçerli mi — arayüz sınır dışı bir indeksle çağırabilir.
  static bool gecerli(int kademe) => kademe >= 0 && kademe < hepsi.length;

  /// NORMALİZE erişim — bütün gemilerin ekranda kapladığı ortak yarı-açıklık.
  ///
  /// Tasarımların kendi erişimleri 36 ile 72 arasında (Dagon en dar, Nemesis
  /// en geniş) ama bu bir GÜÇ farkı değil, çizimin kendi koordinat sistemi.
  /// Ekranda hepsi aynı boyda durmak zorunda: uzayda süzülen bir Nemesis'in
  /// bir Dagon'un iki katı olması gemi seçimini bir boyut yarışına çevirirdi.
  ///
  /// Çapa tepe tasarım — atlasın canlı gövde bloğu zaten onun ölçüsüne göre
  /// pişiyor ([AtlasLayout.hullCellWorld]) ve silüetler o hücreye sığmak
  /// zorunda.
  static double get hedefErisim => hepsi.last.erisim;

  /// [tasarim]'ın çizimini hedef erişime getiren çarpan.
  static double olcekFor(GovdeTasarimi tasarim) => hedefErisim / tasarim.erisim;

  /// Önizleme PNG'sinin tasarım uzayında kapladığı KARE kenarı.
  ///
  /// Katalog PNG'leri gemiyi tuvalin %70'ine oturtuyor
  /// (`tool/govde_ikonu_test.dart` üretilen sekizinciyi de öyle kadrajlıyor),
  /// yani görünür gemi `erisim × 2` ise tuvalin tamamı onun 1/0,70 katı.
  static const double ikonKadraji = 0.70;

  /// [tasarim]'ın PNG'sinin tasarım uzayındaki kenar uzunluğu.
  static double ikonKutusuFor(GovdeTasarimi tasarim) =>
      tasarim.erisim * 2 / ikonKadraji;

  /// BU projede çizimi olan tasarımlar.
  ///
  /// Denetim katmanı (`çizilmiş gövde`) bu sayıyı ölçüyor. Bugün BİR: uzayda
  /// da hangarda da her gövde [Bastion] gibi görünüyor.
  static List<GovdeTasarimi> get cizilenler => [
    for (final t in hepsi)
      if (t.cizildi) t,
  ];

  /// Bütün ikon yolları — pubspec'te bildirilmesi gerekenler.
  static List<String> get ikonlar => [for (final t in hepsi) t.ikon];

  /// Her tasarımdaki silah kaidesi sayısı.
  ///
  /// Sekizinin de BEŞ kaidesi var ve bu bir tesadüf değil: atlas silah
  /// yuvalarını gövdeden ayrı bir blokta pişiriyor ve o bloğun genişliği
  /// [AtlasLayout.emitterMounts]. Bir tasarım altı kaideyle gelseydi atlas
  /// bloğu değişmek zorunda kalırdı.
  static int get kaideSayisi => AtlasLayout.emitterMounts;
}
