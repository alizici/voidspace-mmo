import 'currency.dart';

/// Bir para hareketinin SEBEBİ.
///
/// Serbest metin değil sayılabilir bir liste: defterin değeri sorgulanabilir
/// olmasında. "Bu hesap son bir saatte imhadan ne kazandı" sorusu ancak sebep
/// makine tarafından okunabiliyorsa cevaplanır.
enum LedgerReason {
  /// Alien imhası.
  kill,

  /// Mağazadan eşya ya da gemi alımı.
  purchase,

  /// Eşya yükseltme.
  upgrade,

  /// Yeni hesabın açılış bakiyesi.
  signup,

  /// Gerçek parayla satın alınan birim.
  topUp,

  /// Ters ibraz / iade — EKSİYE inebilir.
  clawback,

  /// Ölüm bedeli (tamir).
  repair,

  /// Geliştirme kolaylığı (`DEV_RICH`). Üretimde görülmemeli.
  devGrant;

  String get key => name;
}

/// Bir para hareketinin DEĞİŞMEZ kaydı.
///
/// **Neden defter.** Gerçek parayla satılacak bir birimde bakiye tek başına
/// yetmiyor: bakiye "şu an ne kadar var" der, defter "nasıl oldu" der.
/// Defter olmadan ne dolandırıcılık soruşturulur, ne bir açık geri alınır, ne
/// "param nereye gitti" cevaplanır, ne muhasebe yapılır. Sektör pratiği de bu:
/// her harekete benzersiz kimlik, öncesi/sonrası bakiye, sebep ve zaman.
///
/// **Neden `balanceAfter` de yazılıyor.** Yalnız `delta` yazmak, defteri
/// baştan toplamadan hiçbir soruyu cevaplayamaz hâle getirir; ve bir kayıp
/// kayıt sessizce fark edilmez. Sonraki bakiye ile bir önceki kaydın
/// bakiyesi tutmuyorsa arada bir kayıt kaybolmuş demektir — defterin kendi
/// kendini denetlemesi bundan ibaret.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.accountId,
    required this.currency,
    required this.delta,
    required this.balanceAfter,
    required this.reason,
    required this.atMillis,
    this.detail,
  });

  /// Benzersiz işlem kimliği.
  ///
  /// Tekrarlanan bir kimlik, aynı hareketin iki kez işlendiği anlamına gelir —
  /// çoğaltma açıklarının tel üzerindeki imzası. Depo bunu tespit edebilmeli.
  final String id;

  final String accountId;
  final Currency currency;

  /// Değişim: artı kazanç, eksi harcama.
  final int delta;

  /// Hareketten SONRAKİ bakiye.
  final int balanceAfter;

  final LedgerReason reason;

  /// Ne olduğu: alien türü, eşya kimliği, sipariş numarası…
  final String? detail;

  final int atMillis;

  Map<String, Object?> toJson() => {
    'id': id,
    'accountId': accountId,
    'currency': currency.key,
    'delta': delta,
    'balanceAfter': balanceAfter,
    'reason': reason.key,
    'at': atMillis,
    if (detail != null) 'detail': detail,
  };

  static LedgerEntry fromJson(Map<String, Object?> json) => LedgerEntry(
    id: json['id']! as String,
    accountId: json['accountId']! as String,
    currency: Currency.byKey(json['currency']! as String) ?? Currency.credit,
    delta: (json['delta']! as num).toInt(),
    balanceAfter: (json['balanceAfter']! as num).toInt(),
    reason: LedgerReason.values.firstWhere(
      (r) => r.key == json['reason'],
      orElse: () => LedgerReason.kill,
    ),
    atMillis: (json['at']! as num).toInt(),
    detail: json['detail'] as String?,
  );

  @override
  String toString() =>
      '${reason.key} ${delta >= 0 ? '+' : ''}$delta ${currency.key} '
      '→ $balanceAfter${detail != null ? ' ($detail)' : ''}';
}

/// Bir para hareketinin KİMLİĞİ ve ZAMANI.
///
/// Çekirdek paket saat tutmuyor ve kimlik üretmiyor: ikisi de dış dünyaya ait
/// ve ikisi de testi belirsizleştirir. Çağıran veriyor, çekirdek yalnız
/// kaydediyor — böylece aynı hangar işlemi testte de üretimde de aynı defteri
/// yazıyor.
class TxContext {
  const TxContext({required this.id, required this.atMillis});

  /// Benzersiz işlem kimliği. Tekrarı, aynı hareketin iki kez işlendiğinin
  /// imzasıdır ve depo bunu yakalayabilmeli.
  final String id;

  final int atMillis;

  /// Aynı işlemin ALT adımları için türetilmiş kimlik.
  ///
  /// Bir hangar komutu birden fazla para hareketi doğurabilir (ileride:
  /// takas, paket alım). Hepsine aynı kimliği vermek, tekrar tespitini
  /// bozardı.
  TxContext step(String suffix) =>
      TxContext(id: '$id:$suffix', atMillis: atMillis);
}
