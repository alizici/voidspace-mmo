import 'messages.dart';

/// ÖNCELİKLİ REPLİKASYON — hangi entity bu snapshot'a girecek.
///
/// **Neden gerekli.** Ölçüldü: 240 oyuncuda oyuncu başına 52,5 KB/s, yani
/// saatte 190 MB. Mobil bir oyunda 5 GB'lık paket 26 saatte biter. Ve bant
/// genişliği CPU'dan ÖNCE bitiyor: tik bütçesi %80'deyken trafik çoktan
/// sorun.
///
/// **Neden kodlama değil ORAN.** Aynı ölçüm, kodlamanın yapabileceğini
/// yaptığını da gösterdi: alienler zaten delta ile gidiyor ve kavgada
/// kayıtların yalnız %10'u boş. Kalan baytlar gerçek bilgi — konum gerçekten
/// değişiyor. Küçültülebilecek tek şey, o bilginin NE SIKLIKTA gönderildiği.
///
/// Model Unreal'in replikasyon önceliğiyle aynı iskelette:
///
///  * **Oran filtresi** (`NetUpdateFrequency`): uzaktaki entity daha seyrek
///    aday oluyor. Ucuz ve adayların çoğunu baştan eliyor.
///  * **Öncelik × bekleme** (`GetNetPriority`): sıra beklemek önceliği
///    büyütüyor, yani hiçbir entity AÇ KALMIYOR. Bu çarpan olmadan uzaktaki
///    bir gemi sonsuza kadar sıranın sonunda kalırdı.
///  * **Bütçe**: doygunlukta öncelik sırasına göre doldur, kalanı bir sonraki
///    tike bırak.
///
/// **Ve bize özgü kısıt: PAYLAŞILAN TEMEL.** Delta'nın temeli herkes için
/// ortak (önceki tik). Bir entity'yi atladığımızda istemcinin temeli geri
/// kalıyor ve dönüşte TAM kayıt göndermek zorundayız. Yani atlamanın bir
/// bedeli var ve ancak yeterince uzun atlamalarda kâra geçiyor — bantlar bu
/// başa baş hesabından türedi, sezgiden değil.
///
/// İkinci mekanizma bu bedeli hiç ödemiyor: **maskesi BOŞ kayıt atlanabilir.**
/// Hiçbir şey değişmediyse sunucunun yeni temeli eskisiyle aynı, yani
/// istemcinin temeli hâlâ doğru. Ölçüldü: sakin dünyada kayıtların %89'u boş.
///
/// **Ve bize özgü kısıt: SESSİZLİK TAVANI.** İstemci bir entity'yi bir saniye
/// (`RemoteEntities._staleTicks` = 30 tik) duymazsa düşürüyor. Bütçe ne kadar
/// dolu olursa olsun, o eşiğe yaklaşan entity mutlaka gönderilmeli — yoksa
/// kalabalıkta gemiler ekrandan silinip geri gelirdi.
abstract final class Replication {
  /// Bir entity'nin sessiz kalabileceği EN FAZLA tik.
  ///
  /// İstemcinin eşiğinin (30) belirgin altında: ağ gecikmesi ve tik kayması
  /// için pay bırakıyor. Bu sayı aşıldığında bütçe yok sayılıyor —
  /// entity'nin ekrandan kaybolması, geç güncellenmesinden çok daha kötü.
  static const int maxSilenceTicks = 18;

  /// Uzaklık bandına göre EN AZ gönderim aralığı (tik).
  ///
  /// Bantlar ilgi yarıçapının oranı olarak tanımlı, mutlak mesafe değil:
  /// harita ya da yarıçap değiştiğinde politika kendiliğinden uyum sağlıyor.
  ///
  /// Yakın olan her tik gidiyor — kavgada olduğun gemi hiç seyrelmiyor. Bu
  /// önemli: öncelikli replikasyonun oyuncuya "takılıyor" diye görünmesinin
  /// tek yolu, yakındakini seyreltmek olurdu.
  /// Tam kaydın bayt boyu — bandların BAŞA BAŞ hesabı buradan.
  static const int fullRecordBytes = EntitySnapshot.wireSize;

  /// Boş olmayan bir delta kaydının ÖLÇÜLEN tipik boyu.
  ///
  /// 5 değildi ve 5 hiçbir zaman gerçek uçuşu tarif etmiyordu: o sayı yalnız
  /// EKSENE PARALEL uçuşun ortalaması (ölçüldü: 5,15 B). Gerçek uçuşta x ile y
  /// birlikte değişiyor, yani en sık maske ikisi birden.
  ///
  /// Ölçüm (960 kayıt): düz uçuşta **7,05 B** — baskın maske x+y (683 kayıt)
  /// = 3 çerçeve + 2 + 2. Dönen ve ateş eden gemide 7,94 B.
  static const int typicalDeltaBytes = 7;

  static int intervalFor(double distanceSquared, double interestRadius) {
    final r = interestRadius;
    // Bant 2 KALDIRILDI ve sebebi ölçüm.
    //
    // Atlamanın bedeli, paylaşılan temelin bayatlaması: dönüşte TAM kayıt
    // göndermek zorundayız (14 bayt). Kazanç ise atlanan kısmi kayıtlar.
    // Ölçülen kısmi kayıt 7 B, tam kayıt 14 B — yani başa baş noktası
    // aralık ≈ 2, ve bant 2 TAM O NOKTADA duruyor.
    //
    // Bandın kaldırılma sebebi bu yüzden başa baş değil MARJ. Gerçek maske
    // akışı yeniden oynatıldığında N=2'nin verdiği: duran gemide −%2, düz
    // uçuşta **+%1 (zarar)**, dönen+ateş edende −%13. İki tik ek bayatlığın
    // karşılığı ~%0.
    //
    // Aynı akışta N=4 −%50/−%56, N=6 −%67/−%71. Kural: bir bant, atlamanın
    // bedelinin en az İKİ KATINI kazanmalı.
    //
    // Bunu hesaplamadan üç bant yazmıştım (1/2/4/6) ve orta bant sessizce
    // bant genişliğini artırıyordu.
    if (distanceSquared <= r * r * 0.25) return 1; // < %50 → her tik
    if (distanceSquared <= r * r * 0.5625) return 4; // < %75
    return 6;
  }

  /// Seçim önceliği — büyük olan önce gider.
  ///
  /// İki çarpanın çarpımı:
  ///
  ///  * **Bekleme** ([sinceTicks]): doğrusal. Unreal'in "son replikasyondan
  ///    beri geçen süreyle çarp" kuralı ve sebebi aynı — açlığı önlemek.
  ///  * **Yakınlık**: 1 / (1 + normalize edilmiş uzaklık²). Yakındaki entity
  ///    aynı beklemede daha öncelikli.
  static double priority(
    int sinceTicks,
    double distanceSquared,
    double interestRadius,
  ) {
    final normalized = distanceSquared / (interestRadius * interestRadius);
    return sinceTicks / (1 + normalized);
  }

  /// Bu entity bu tikte ADAY mı — oran filtresi.
  ///
  /// Sessizlik tavanına ulaşan her zaman aday: bütçe onu eleyebilir ama
  /// filtre eleyemez.
  static bool isCandidate(
    int sinceTicks,
    double distanceSquared,
    double interestRadius,
  ) =>
      sinceTicks >= maxSilenceTicks ||
      sinceTicks >= intervalFor(distanceSquared, interestRadius);

  /// Bütçe ne olursa olsun GÖNDERİLMEK ZORUNDA.
  static bool mustSend(int sinceTicks) => sinceTicks >= maxSilenceTicks;
}
