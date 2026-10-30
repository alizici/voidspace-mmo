import 'package:voidspace_core/voidspace_core.dart';

import 'dil.dart';
import 'metin.dart';

/// Sunucudan gelen kimlik hatası KODUNU okunur cümleye çevirir.
///
/// Sunucu `kimlik.hatali-giris` gönderiyor, oyuncu "Nome utente o password
/// errati" okuyor. Aradaki tek adım bu işlev.
///
/// **Tanınmayan kod ham gösteriliyor.** Yeni bir sunucu, bu istemcinin
/// bilmediği bir kod gönderebilir; onu yutmak, hatanın sessizce kaybolması
/// demek olurdu. Okunaksız bir hata, görünmeyen bir hatadan iyidir.
///
/// Sayılar TELDEN GELMİYOR, `Credentials`ten okunuyor: kurallar sunucuyla
/// paylaşılan pakette, yani istemcinin bildiği sınır sunucunun uyguladığı
/// sınırla aynı olmak zorunda.
String? kimlikMetni(String? ham, Dil dil) {
  if (ham == null) return null;
  final (kod, argumanlar) = KimlikKodu.coz(ham);
  if (kod == null) return ham;

  return switch (kod) {
    KimlikKodu.kullaniciKisa => Metin.hataKullaniciKisa.bicim(dil, {
      'n': Credentials.usernameMin,
    }),
    KimlikKodu.kullaniciUzun => Metin.hataKullaniciUzun.bicim(dil, {
      'n': Credentials.usernameMax,
    }),
    KimlikKodu.kullaniciBicim => Metin.hataKullaniciBicim(dil),
    KimlikKodu.epostaGerekli => Metin.hataEpostaGerekli(dil),
    KimlikKodu.epostaUzun => Metin.hataEpostaUzun(dil),
    KimlikKodu.epostaBicim => Metin.hataEpostaBicim(dil),
    KimlikKodu.parolaKisa => Metin.hataParolaKisa.bicim(dil, {
      'n': Credentials.passwordMin,
    }),
    KimlikKodu.parolaUzun => Metin.hataParolaUzun.bicim(dil, {
      'n': Credentials.passwordMax,
    }),
    KimlikKodu.kullaniciAlinmis => Metin.hataKullaniciAlinmis(dil),
    KimlikKodu.epostaAlinmis => Metin.hataEpostaAlinmis(dil),
    KimlikKodu.hataliGiris => Metin.hataHataliGiris(dil),
    KimlikKodu.sunucuHatasi => Metin.hataSunucuHatasi(dil),
    KimlikKodu.cokFazlaDeneme => Metin.hataCokFazlaDeneme(dil),
    KimlikKodu.oturumDoldu => Metin.hataOturumDoldu(dil),
    KimlikKodu.sunucuDolu => Metin.hataSunucuDolu(dil),
    KimlikKodu.baskaCihaz => Metin.hataBaskaCihaz(dil),
    // Tek argümanlı kod. Sunucu eski bir sürümse argüman gelmeyebilir —
    // o zaman bilinen tek sayı istemcinin kendisininki.
    KimlikKodu.surumUyusmazligi => Metin.hataSurumUyusmazligi.bicim(dil, {
      'gerekli': argumanlar.elementAtOrNull(0) ?? '?',
      'gelen': argumanlar.elementAtOrNull(1) ?? Protocol.version,
    }),
  };
}
