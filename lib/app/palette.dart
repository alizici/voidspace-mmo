import 'package:flutter/material.dart';

/// Arayüzün tek renk kaynağı. Bileşenler renk seçmez, buradan okur —
/// tema değişimi tek dosyada kalır.
abstract final class Palette {
  static const space = Color(0xFF03050C);
  static const panel = Color(0xCC0A1220);

  /// TAM EKRAN PERDESİ — pencerenin arkasını KAPATIYOR.
  ///
  /// Bir süre yarı saydamdı (%76) ve altındaki hangar okunuyordu: eşya
  /// penceresinin arkasından yuvalar, düğmeler ve stat satırları
  /// seçilebiliyordu. Bağlam vermek yerine ikinci bir katman üretiyordu —
  /// göz neye bakacağını seçmek zorunda kalıyor, ve pencerenin kendisi
  /// zaten bütün ilgiyi isteyen bir şey.
  ///
  /// Opak. Perde açıkken ekranda pencereden başka bir şey yok.
  static const perde = Color(0xFF040710);
  static const line = Color(0x334FE3FF);
  static const ink = Color(0xFFDCE8F5);
  static const inkDim = Color(0xFF7C93A6);

  /// Gövde — sıcak, kalkanla karışmaz.
  static const hull = Color(0xFFFFA24A);

  /// Kalkan — gemideki kabarcıkla AYNI mavi, ki çubuk ve efekt aynı şeyi
  /// söylediğini belli etsin.
  static const shield = Color(0xFF62D8FF);

  /// İtki — lav çekirdeğinin rengi.
  static const boost = Color(0xFFFFC247);

  // ── MENÜ YÜZEYİ (hangar / mağaza) ───────────────────────────────────
  //
  // Oyunun içi ile menü AYNI dünyada ama farklı işler yapıyor: oyun ekranı
  // koyu ve neredeyse boş olmalı (okunması gereken şey harita), menü ise
  // panelli ve okunaklı. Renkler yine BURADAN geliyor — ikinci bir palet
  // dosyası açmak, iki yüzeyin zamanla birbirinden ayrılması demekti.

  /// Menü zemini. Oyun zemininden bir tık açık: panel kenarları görünsün.
  static const menuBg = Color(0xFF0A0E1A);

  /// Menü panelinin üst rengi — alta doğru [menuBg]'ye iniyor.
  static const menuPanel = Color(0xFF0F1626);

  /// Vurgu. Kalkan mavisiyle aynı aileden: arayüz ile oyun aynı dili konuşsun.
  static const accent = Color(0xFF2FB8FF);
  static const accentBright = Color(0xFF9BE6FF);

  /// Zeminle en yüksek karşıtlığı veren metin — başlıklar.
  static const inkBright = Color(0xFFEEF3F7);

  /// Sönük metin: bölüm etiketleri, birimler.
  static const faint = Color(0xFF5A6675);
  static const muted = Color(0xFF7C8A99);

  static const good = Color(0xFF3DDB7D);
  static const danger = Color(0xFFFF4D5E);

  /// Yuva türü renkleri. Aynı türün yuvası, deposu ve mağaza kartı AYNI rengi
  /// taşıyor — oyuncu rengi bir kez öğreniyor, üç yerde işine yarıyor.
  static const slotLaser = Color(0xFFFF8A3D);
  static const slotGenerator = Color(0xFF5FD7E6);
  static const slotLauncher = Color(0xFFC15CFF);
  static const slotCpu = Color(0xFF8CFF5A);

  /// Droid yuvası — droid varlığı (04.10).
  static const slotDroid = Color(0xFF9AE6B4);

  /// FÜZE — roketatarla aynı aileden ama AYRI bir karar.
  ///
  /// Roketatar yuvası bir eşya taşıyor, füze ise tüketilen mühimmat: ikisi
  /// aynı renkte olsaydı "hangi rafa bakıyorum" sorusu renkten
  /// cevaplanamazdı.
  static const slotRocket = Color(0xFFFF6B8A);

  /// Menünün tipografisi TEK ARALIKLI.
  ///
  /// Süs değil: menüdeki her sayı bir başkasıyla karşılaştırılmak için orada
  /// (bu lazer ötekinden ne kadar iyi, bu gemi ne kadar pahalı). Orantılı bir
  /// yazı tipinde rakamlar farklı genişlikte olduğu için sütunlar kayıyor ve
  /// karşılaştırma gözle değil okuyarak yapılıyor.
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double spacing = 0,
    double? height,
  }) => TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );

  static TextStyle label([double size = 11]) => TextStyle(
    color: inkDim,
    fontSize: size,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w700,
  );
}
