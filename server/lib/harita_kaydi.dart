import 'package:voidspace_core/voidspace_core.dart';

import 'zone.dart';

/// Bir haritanın KALICI kaydı — simülasyonu değil.
///
/// KBEngine'in **base/cell** ayrımı, harita ölçeğinde. Orada bir varlığın
/// `base` parçası kalıcı ve simülasyonsuz, `cell` parçası bir uzayda
/// yaratılıyor ve yok edilebiliyor. Burada aynı bölme haritaya uygulanıyor:
///
/// * **base** — bu sınıf. Yirmi dört tane, hep ayakta, neredeyse bedava.
/// * **cell** — [Zone]. İlk oyuncu girince yaratılıyor, son oyuncu çıkınca
///   yok ediliyor.
///
/// **Neden tembel.** Yirmi dört haritayı baştan kurmak, her tikte 24 × 16 =
/// 384 yaratık adımı döndürmek demek — hiçbirinde kimse olmasa bile. Tembel
/// kurulumda maliyet OYUNCUYA bağlanıyor, içeriğe değil: bölge 6–8
/// eklendiğinde çalışma zamanı maliyeti sıfır, yalnız birer kayıt daha.
///
/// **Neden base ayrı.** Hücre yok edilince içindeki her şey gider. Yaratık
/// diriliş saati için bu sorun değil (8–20 saniye, oyuncunun dönüşünden kısa)
/// ama **boss** için ölümcül: iki saatte bir doğması gereken bir şey, kimse
/// izlemediği için doğmamış olamaz. Bu yüzden boss saati burada duruyor,
/// hücrede değil.
class HaritaKaydi {
  /// [hucre] verilirse hücre baştan AÇIK kurulur.
  ///
  /// Yalnız test ve enjeksiyon için: sunucu hücreleri tembel açıyor. Açık
  /// kurulmuş bir hücre de normal ömrü izliyor — boşalınca kapanabiliyor.
  HaritaKaydi(this.harita, {Zone? hucre}) : _hucre = hucre;

  final Harita harita;

  Zone? _hucre;

  /// Simülasyon — yalnız oyuncu varken.
  Zone? get hucre => _hucre;

  bool get canli => _hucre != null;

  /// Boss'un en son doğduğu tik.
  ///
  /// Hücre yok edilse de yaşıyor. `null` ise bu haritada hiç boss doğmamış ve
  /// ilk oyuncu girdiğinde bir tane borçlu.
  int? bossSonDogusTik;

  /// Boss aralığı, TİK cinsinden — 12'nin türettiği saatten.
  /// KARAR 12.5 s1
  int get bossAraligiTik =>
      (DusmanTasarimi(
                rank: harita.bolge.ilkRank,
                sinif: DusmanSinifi.boss,
              ).bossAraligiSaat *
              3600 *
              Protocol.tickRate)
          .round();

  /// [tik] anında boss doğmayı HAK ETMİŞ mi.
  ///
  /// Harita boşken de işliyor: iki saat kimsenin girmediği bir haritaya giren
  /// oyuncu, bekleyen boss'u buluyor. Sayacın hücrede durduğu bir tasarımda bu
  /// imkânsızdı — sayaç hücreyle birlikte sıfırlanırdı ve boss ancak birileri
  /// iki saat boyunca haritada beklerse doğardı.
  bool bossBekliyor(int tik) {
    final son = bossSonDogusTik;
    return son == null || tik - son >= bossAraligiTik;
  }

  /// Boss doğdu — sayacı ilerlet.
  void bossDogdu(int tik) => bossSonDogusTik = tik;

  /// Hücreyi aç — zaten açıksa var olanı verir.
  ///
  /// [tik] sunucunun saati: yeni hücre sıfırdan değil oradan başlıyor, yoksa
  /// içine giren herkes anında "sessiz" sayılırdı.
  Zone ac(int tik) => _hucre ??= Zone(
    world: harita.dunya,
    alienCount: harita.bolge.hedefSayisi,
    // Tohum HARİTADAN, rastgele değil. İki şeyi birden tutuyor: aynı harita
    // her açılışta aynı sürüyü doğuruyor (bir hatayı iki kez görebilmek,
    // hücrenin ömürlü olmasıyla kaybolmamalı) ve farklı haritalar farklı sürü
    // doğuruyor (yoksa yirmi dört harita, ikisi kadar çeşit ederdi).
    diceSeed: _tohum,
    serpmeTohumu: _tohum,
    baslangicTik: tik,
    // Kimlik aralığı haritaya AYRILMIŞ — bölgeler arası çakışma olamaz.
    kimlikTabani: 1 + _tohum * kimlikAraligi,
    kimlikAraligi: kimlikAraligi,
    // Bölge kadroyu VE bant ölçeğini veriyor: her harita kendi yaratıklarını,
    // kendi bandının gücünde doğuruyor.
    bolge: harita.bolge,
  );

  /// Harita başına gemi kimliği payı — bölünen uzay, elle konmuş bir sayı DEĞİL.
  ///
  /// Merdiven uzayıp harita sayısı 15'ten 24'e çıktığında pay kendiliğinden
  /// daralıyor ve toplam yine uzaya sığıyor. Payın kapasiteden (64) büyük
  /// olması yeterli; bugünkü pay onun otuz katından fazla.
  static int get kimlikAraligi => Protocol.maxShipId ~/ Harita.hepsi.length;

  /// Haritanın kimliğinden çıkan tohum.
  int get _tohum =>
      harita.bolge.kademe * HaritaTipi.values.length + harita.tip.index;

  /// Hücreyi kapat — son oyuncu çıktığında.
  ///
  /// Boş olmayan bir hücreyi kapatmak, içindeki oyuncuları dünyadan silmek
  /// olurdu; çağıran karar veremesin diye kontrol BURADA.
  bool kapat() {
    final h = _hucre;
    if (h == null || h.ships.isNotEmpty) return false;
    _hucre = null;
    return true;
  }
}

/// BÜTÜN haritaların kaydı — dünyanın base katmanı.
class HaritaDefteri {
  /// [baslangicHucresi] verilirse başlangıç haritasının hücresi o olur.
  ///
  /// Enjeksiyon noktası: testler yaratıksız ya da az yaratıklı bir dünya
  /// kuruyor. Diğer haritalar yine tembel.
  HaritaDefteri({Zone? baslangicHucresi})
    : _kayitlar = {
        for (final h in Harita.hepsi)
          h: HaritaKaydi(h, hucre: h == baslangic ? baslangicHucresi : null),
      };

  final Map<Harita, HaritaKaydi> _kayitlar;

  HaritaKaydi operator [](Harita harita) =>
      _kayitlar[harita] ?? (throw ArgumentError.value(harita, 'harita', 'yok'));

  /// Şu anda simülasyonu dönen haritalar.
  Iterable<HaritaKaydi> get canlilar => _kayitlar.values.where((k) => k.canli);

  Iterable<HaritaKaydi> get hepsi => _kayitlar.values;

  /// Başlangıç haritası — tanımı [Harita.baslangic]'te.
  static Harita get baslangic => Harita.baslangic;
}
