/// SAYI BİÇİMİ — binlik ayracı, ondalık ayracı, yüzde işaretinin yeri.
///
/// **Neden dile bağlı.** `12.400` bir Türk ya da İtalyan için on iki bin dört
/// yüz, bir İngiliz için on iki nokta dört. Aynı dize iki dilde iki farklı
/// SAYI okunuyor — çeviri hatası değil, veri hatası. Yüzde de aynı: Türkçe
/// `%15` yazar, İngilizce ve İtalyanca `15%`.
///
/// **Neden `intl` değil.** `NumberFormat` bütün bunları yapar ve fazlasını:
/// para birimi, çoğul kuralları, yerel rakam sistemleri. Bu oyunun ihtiyacı
/// üç dil ve üç kural; bir biçimleyici paketi ile onun yerel veri tablolarını
/// paket boyutuna eklemek, kullanılmayan doksan dokuz kuralı taşımak olurdu.
/// İhtiyaç büyürse `intl` zaten `flutter_localizations` üzerinden bağımlılık
/// ağacında duruyor.
library;

import 'dil.dart';

/// Binlik ayracı.
String _binlik(Dil dil) => switch (dil) {
  Dil.turkce || Dil.italyanca => '.',
  Dil.ingilizce => ',',
};

/// Ondalık ayracı.
String _ondalik(Dil dil) => switch (dil) {
  Dil.turkce || Dil.italyanca => ',',
  Dil.ingilizce => '.',
};

/// Binlik ayraçlı tam sayı: `12.400` · `12,400`.
String sayi(num deger, Dil dil) {
  final rakamlar = deger.round().abs().toString();
  final ayrac = _binlik(dil);
  final cikti = StringBuffer(deger < 0 ? '-' : '');
  for (var i = 0; i < rakamlar.length; i++) {
    if (i > 0 && (rakamlar.length - i) % 3 == 0) cikti.write(ayrac);
    cikti.write(rakamlar[i]);
  }
  return cikti.toString();
}

/// Ondalıklı sayı: `2,4` · `2.4`.
///
/// Binlik ayracı da uygulanıyor — `1.234,5` gibi bir sayı bugün ekranda yok
/// ama iki kuralı ayrı yerlerde tutmak, bir gün birinin unutulması demek.
String ondalikli(num deger, Dil dil, {int basamak = 1}) {
  final metin = deger.abs().toStringAsFixed(basamak);
  final parcalar = metin.split('.');
  final tam = sayi(num.parse(parcalar.first), dil);
  final isaret = deger < 0 ? '-' : '';
  if (parcalar.length == 1) return '$isaret$tam';
  return '$isaret$tam${_ondalik(dil)}${parcalar[1]}';
}

/// Yüzde — işaret dilin koyduğu yerde: `%15` · `15%`.
///
/// [deger] YÜZDE PUANI (15 = %15), oran değil. Oranı yüzde puanına çevirmek
/// çağrı yerinin işi: bazı statlar zaten puan olarak tutuluyor.
String yuzde(num deger, Dil dil, {int basamak = 0}) {
  final govde = basamak == 0
      ? sayi(deger, dil)
      : ondalikli(deger, dil, basamak: basamak);
  return switch (dil) {
    Dil.turkce => '%$govde',
    Dil.ingilizce || Dil.italyanca => '$govde%',
  };
}
