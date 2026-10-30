import 'vec2.dart';

/// Oynanabilir alan. Saf veri — bir oyun döngüsüne ya da bileşene bağlı değil,
/// bu yüzden sınır kuralları hem sunucuda hem istemcide AYNI kodla çalışır.
///
/// Tek değişiklik `Offset` yerine [Vec2]: `dart:ui` Flutter'a ait ve bu tip
/// artık `dart:io` sunucusunda da yaşıyor.
class GameWorld {
  const GameWorld({
    this.width = ilkBolgeGenislik,
    this.height = ilkBolgeYukseklik,
    this.margin = 140,
  });

  /// Tek bantlık bir haritanın kenarları — ALAN 11'DEN TÜRETİLDİ.
  ///
  /// `bantAlanı = eşZamanlıOyuncu × π × görüş² × seyreklik`
  /// `= 8 × π × 2600² × 0,5 = 84.948.665 birim²`, 3:2 oranında dağıtılmış.
  /// Hesabın kendisi [TuretilenTablolar.haritaBoyutuFor] içinde; buradaki iki
  /// sayı onun ÖNBELLEĞİ, çünkü Dart'ta varsayılan parametre değeri `const`
  /// olmak zorunda ve `sqrt` `const` değil. Ayrışmayı bir test tutuyor.
  ///
  /// Önceki değer 12.000 × 8.000'di: elle konmuş, ve türetilene her iki
  /// kenarda %6 uzaktı. Gövde merdiveni, rank merdiveni, A=D dengesi ve gövde
  /// havuzundan sonra elle konmuş bir sayının tutarlı bir sistemin içinden
  /// geldiğinin beşinci örneği.
  /// KARAR 11.5 s1
  static const double tekBantGenislik = 11288;
  static const double tekBantYukseklik = 7525;

  /// İLK BÖLGENİN haritası — [standard]'ın önbelleği.
  ///
  /// Tek banttan √2 kat büyük ve bu bir seçim değil sonuç: yirmi rank sekiz
  /// bölgeye 2·3·2·3·2·3·2·3 diye bölünüyor (kademe normalizasyonu), ilk
  /// bölgeye iki bant düşüyor, alan bantla doğrusal büyüyor, kenar alanın
  /// karekökü.
  ///
  /// Ayrı sabit, çünkü tek bantlık ölçü hâlâ türetmenin çapası. İkisi bir
  /// süre AYNIYDI — rank ile gövde kademesi eşitken her bölge tek banttı — ve
  /// `standard` doğrudan tek bant sabitini okuyordu. Ayrıştıkları gün
  /// `bolge_test`'in "GameWorld.standard = ilk bölgenin haritası" testi
  /// yakaladı.
  static const double ilkBolgeGenislik = 15963.89664396522;
  static const double ilkBolgeYukseklik = 10642.59776264348;

  /// Varsayılan dünya — bugünkü tek bölgenin tek bandı.
  ///
  /// Tek doğruluk kaynağı: kamera sınırı, ızgara, gemi kelepçesi ve AĞDA
  /// KONUM KUANTALAMASI hepsi buradan okur.
  ///
  /// Bölge başına harita ölçüsü `Bolge.harita`'da ve bantla değişiyor; bu
  /// sabit yalnız kimsenin bölge seçmediği yol için — sunucunun ilk bölgesi.
  static const GameWorld standard = GameWorld();

  final double width;
  final double height;

  /// Geminin kenara ne kadar yaklaşabileceği. Gövde yarıçapından büyük olmalı,
  /// yoksa gemi görsel olarak sınırın dışına taşar.
  final double margin;

  Vec2 get centre => Vec2(width / 2, height / 2);

  /// [p]'yi oynanabilir alana çeker. Kelepçe hareketi ENGELLEMEZ, yalnız
  /// sonucunu sınırlar — girdiyi ezmemek bu projede genel kural.
  Vec2 clamp(Vec2 p) => Vec2(
    p.x.clamp(margin, width - margin),
    p.y.clamp(margin, height - margin),
  );
}
