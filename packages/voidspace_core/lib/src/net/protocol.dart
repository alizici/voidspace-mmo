import '../design/tasarim_girdileri.dart';

/// Tel sözleşmesinin sabitleri. İki uç da BURADAN okur.
abstract final class Protocol {
  /// Uyumsuz istemciyi el sıkışmada reddetmek için. Mesaj düzeni her
  /// değiştiğinde artır — eski bir istemcinin yarı çözülmüş çöp okuması,
  /// hata almasından çok daha kötü.
  /// 10 → 11: iki tel TAVANI genişledi. `ShotEvent.damage` `u16` → `u32`
  /// (65.535'te sessizce kelepçeleniyordu) ve `ServerReward` bakiyeleri
  /// `u32` → `u64` (4,29 milyarda sessizce sarıyordu). İkisi de sekiz
  /// kademeli gövde merdiveninin gerektirdiği büyüklükleri taşıyamıyordu.
  ///
  /// Tek yükseltmede toplandılar: her tavan ayrı ayrı genişletilseydi her
  /// biri ayrı bir istemci/sunucu eşzamanlı dağıtımı gerektirirdi.
  ///
  /// 16 → 17: yeni sunucu mesajı [msgGanimet], düşen eşya ve malzeme. Eski
  /// istemci bilinmeyen tipi bozuk çerçeve sayıp bağlantıyı düşürürdü; el
  /// sıkışmada reddedilmek daha dürüst.
  /// 17 → 18: [ServerHarita] geminin YENİ KONUMUNU da taşıyor. Eskiden
  /// istemci onu tahmin ediyor (yeni dünyanın merkezi) ve ilk anlık görüntüde
  /// gerçek yere ışınlanıyordu — geçitten geçen her oyuncu iki sıçrama
  /// görüyordu. Sunucu kaynaklı bir taşımada otoriter konumu yollamamak,
  /// istemciyi tahmine zorlamaktı.
  static const int version = 18;

  /// Sunucu otorite tik hızı (Hz). Bkz. `ShipSim.tickRate` — aynı sayı olmak
  /// ZORUNDA, çünkü istemci tahmini o adımla koşuyor.
  static const int tickRate = 30;

  /// Kaç tikte bir snapshot yollanır. 1 = her tik.
  ///
  /// Neden 1: entity başına 14 bayt ve ilgi alanı filtresiyle oyuncu başına
  /// ~9 KB/s iniyor — 50 oyuncu için ~3.6 Mbit/s, herhangi bir VPS için
  /// önemsiz. Karşılığında interpolasyon gecikmesi 66 ms'de kalıyor. Bant
  /// genişliği sorun olursa çevrilecek ilk düğme burası.
  static const int snapshotEveryNTicks = 1;

  static int get snapshotRate => tickRate ~/ snapshotEveryNTicks;

  /// İstemcinin geçmişte kaç snapshot geriden oynattığının EN AZ değeri.
  ///
  /// İki snapshot şart: biri "şimdi", biri "sonraki" olmadan ara değer
  /// hesaplanamaz. Bunun altına inmek, tek bir geciken pakette uzak gemilerin
  /// donmasına yol açar.
  ///
  /// **Bu bir taban, sabit değer DEĞİL.** İstemci gerçek derinliği ölçtüğü
  /// titreşime göre büyütüyor (bkz. `RemoteEntities`). Sabit tutulduğunda
  /// ölçüldü: ±40 ms titreşimde karelerin %19.8'inde tampon boşalıyor ve uzak
  /// gemiler donuyordu. Taban burada duruyor çünkü "iki örnek gerekir" bir
  /// tercih değil, ara değerin tanımı.
  static const int interpolationDelayTicks = 2;

  /// İlgi alanına GİRME yarıçapı (dünya birimi).
  ///
  /// Bant genişliği İKİNCİL sebep. Asıl sebep hile: istemciye tüm haritayı
  /// göndermek, radarda herkesi gören bir istemci yazmayı mümkün kılar.
  /// Görüş alanı 0.6 zoom'da ~3200 birim; 2600 yarıçap ekranı ve kenar payını
  /// kapsar.
  static const double interestRadius = TasarimGirdileri.gorusYaricapi;

  /// İlgi alanından ÇIKMA yarıçapı — girişten kasıtlı olarak büyük.
  ///
  /// Tek bir yarıçap kullanmak, sınırda seyreden bir geminin saniyede onlarca
  /// kez görünür/görünmez olmasına yol açıyor: sunucu her seferinde onu
  /// snapshot'a alıp çıkarıyor, istemci de bileşenini kurup yıkıyor. Çin
  /// kaynaklarında bu, AOI'nin klasik tuzağı olarak "边界抖动" (sınır
  /// titremesi) adıyla geçiyor ve önerilen çözüm tam olarak bu: giriş ve çıkış
  /// için ayrı eşikler (histerezis).
  static const double interestExitRadius = interestRadius * 1.15;

  /// İki ardışık snapshot arasında bu kadar yol kat eden bir gemi UÇMUYOR,
  /// IŞINLANIYOR demektir (yeniden doğuş, ilgi alanına yeniden giriş).
  ///
  /// Meşru üst sınır: en hızlı gemi 320 birim/sn, itkiyle 1.9 katı = 608, yani
  /// tik başına ~20 birim. İki yüz, bunun ON KATI — hiçbir gerçek hareket
  /// buraya değmez, hiçbir ışınlanma da altında kalmaz (doğuş noktası ölüm
  /// yerinden binlerce birim uzakta).
  ///
  /// Ayrımın görünen karşılığı şu: ışınlanmayı ara değerle yumuşatmak, gemiyi
  /// enkazdan doğuş noktasına SÜZÜLEN bir hayalete çevirir.
  static const double teleportDistancePerTick = 200;

  /// Girdisi bu kadar süre gelmeyen oturum düşürülür (sn).
  static const double sessionTimeout = 10;

  /// Bir entity kaç tikte bir TAM kayıt olarak gönderilir.
  ///
  /// Delta'nın tek zayıf noktası, temelin bir yerde bozulmasıdır: o andan
  /// sonra istemci hatalı bir geçmişin üstüne fark uygular ve **hiçbir hata
  /// mesajı çıkmadan** yanlış konum çizer. Sunucu bugün temelin geçersiz
  /// olduğu üç durumu da ele alıyor (yeni entity, yeni oturum, atlanan
  /// snapshot) — ama dördüncü bir yolun olmadığının garantisi yok.
  ///
  /// Anahtar kare o garantiyi gerektirmez hâle getiriyor: ne olursa olsun her
  /// entity iki saniyede bir tam gider, yani her sapma en geç iki saniyede
  /// KENDİ KENDİNE onarılır. Video kodlayıcılarının anahtar karesiyle aynı
  /// fikir; Çin kaynaklarında da 关键帧 + 定时帧 olarak aynı gerekçeyle geçiyor.
  ///
  /// Maliyeti ihmal edilebilir çünkü kimlik başına KAYDIRILIYOR: tik başına
  /// görünür entity'lerin yalnız 1/60'ı tam gider, yani 60 gemilik bir
  /// kalabalıkta tikte bir entity — snapshot başına ~9 fazladan bayt.
  static const int keyframeTicks = 2 * tickRate;

  /// Alien kimlikleri BURADAN başlar; gemiler altında kalır.
  ///
  /// Hedef alanı (`ShipInput.weaponTarget`) TEK bir `u16` ve iki farklı
  /// varlığı göstermek zorunda. Ayrı bir "tür" baytı eklemek her girdi
  /// çerçevesine bir bayt yazardı; aralığı bölmek bedava ve kesin — bir
  /// kimlik ya gemi ya alien, ikisi birden olamaz.
  ///
  /// Gemilere 32767 kimlik kalıyor, alienlere de: ikisi de bu oyunun
  /// ufkunun çok ötesinde.
  static const int alienIdBase = 0x8000;

  /// Bir gemiye verilebilecek EN BÜYÜK kimlik.
  ///
  /// Tahsis tavanı `u16`'nın 65535'i DEĞİL, bölmenin sınırı: üstündeki her
  /// kimlik alien'in. Tavanı tip genişliğine bırakmak, kimlik uzaylarının
  /// sessizce çakışması demek — gemi bir alien'le aynı kimliği paylaşır ve
  /// istemci ikisini karıştırır.
  ///
  /// Quake 3'te de tahsis tavanı `MAX_GENTITIES` değil `ENTITYNUM_MAX_NORMAL`;
  /// aynı ayrım, aynı sebep.
  static const int maxShipId = alienIdBase - 1;

  /// Bu kimlik bir alien'e mi ait?
  static bool isAlienId(int id) => id >= alienIdBase;

  // ── İstemci → Sunucu ────────────────────────────────────────────────
  static const int msgHello = 0x01;
  static const int msgInput = 0x02;
  static const int msgPing = 0x03;
  static const int msgDebug = 0x04;
  static const int msgRegister = 0x05;
  static const int msgLogin = 0x06;

  /// Hangar komutu (satın al, tak, çıkar, yükselt, gemi seç).
  static const int msgHangar = 0x07;

  /// GEÇİT — oyuncu üstünde durduğu geçide girmek istiyor.
  ///
  /// **Yük yok, hangi geçit olduğunu SUNUCU buluyor.** İstemci geçidi
  /// adlandırsaydı, üstünde durmadığı bir geçidi adlandırabilirdi: ışınlanma
  /// tek çerçevede, BR kapısını da atlayarak. Konumdan çözmek o kapıyı
  /// baştan kapatıyor — sunucu zaten geminin nerede olduğunu biliyor.
  static const int msgGecit = 0x08;

  // ── Sunucu → İstemci ────────────────────────────────────────────────
  static const int msgWelcome = 0x81;
  static const int msgSnapshot = 0x82;
  static const int msgPong = 0x83;
  static const int msgEntityMeta = 0x84;
  static const int msgEntityGone = 0x85;
  static const int msgRejected = 0x86;
  static const int msgAuthOk = 0x87;
  static const int msgAuthError = 0x88;

  /// Hangarın tam durumu: para, gemiler, envanter, donatım.
  static const int msgHangarState = 0x89;

  /// Bir imhanın ödülü — YALNIZ öldürene gider.
  static const int msgReward = 0x8A;

  /// HARİTA DEĞİŞTİ — geçitten geçildi, dünya yeni.
  ///
  /// Ayrı bir mesaj, [msgWelcome] tekrarı DEĞİL: welcome el sıkışmanın
  /// parçası ve istemcide oturum kurulumunu tetikliyor. Harita değişimi
  /// oturumu değil yalnız dünyayı yeniliyor.
  static const int msgHarita = 0x8B;

  /// GEÇİŞ REDDİ — kapıdan geçilemedi.
  ///
  /// [msgRejected] DEĞİL ve bu ayrım bir hatadan öğrenildi: o mesaj el sıkışma
  /// reddi ve istemci onu alınca belirteci UNUTUYOR, oturumu düşürüyor.
  /// Geçide biraz uzak durmak, oyuncuyu oyundan atmak için bir sebep değil.
  static const int msgGecitRed = 0x8C;

  /// GANİMET — bir imhadan düşen eşya ve malzeme, düşene gider (14.1).
  ///
  /// [msgHangarState] ile birlikte: hangar durumu envanterin doğrusu, bu
  /// mesaj "ne düştü" sorusunun cevabı. Bakiyeyi taşıyan [msgReward]'a
  /// eklenmedi: o yalnız kazancı olan oyuncuya gidiyor ve iki musluk ayrı.
  static const int msgGanimet = 0x8D;
}

/// Geçici hata ayıklama komutları. HUD'daki `HASAR / ONAR` satırının ağ
/// karşılığı: silah katmanı yokken otorite döngüsünü uçtan uca kanıtlamanın
/// tek yolu. Silahlar gelince silinecek (`TODO(combat)`).
abstract final class DebugCommandKind {
  static const int damage = 0;
  static const int repair = 1;
}
