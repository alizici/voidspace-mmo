import 'ganimet.dart';
import 'item.dart';

/// Malzemenin TÜRÜ — ne için harcandığı.
///
/// Rank tek başına yetmiyordu ve sebebi tasarımsal: yükseltme ile çevirme
/// AYNI kaynağı harcarsa biri ötekini yiyor — oyuncu her çevirmede bir
/// yükseltmeden vazgeçmiş oluyor ve ikisi arasında bir karar değil, bir ceza
/// hissediyor. Ayrı kaynaklar iki ekseni bağımsız kılıyor.
///
/// Ön ekler KALICI: eski kayıtlar `m-` taşıyor ve şema onlardan sonra
/// genişledi. `m-`yi korumak, hiçbir hangarın göç ettirilmesi gerekmemesi
/// demek.
/// KARAR 06.4 s1
enum MalzemeTuru {
  /// Yükseltmenin RANK KAPISI. Öldürmeden ve parçalamadan geliyor.
  yukseltme('m-', 'Malzeme'),

  /// Alt stat çevirmenin kaynağı. YALNIZ parçalamadan geliyor — ve nadirliği
  /// oradan çıkıyor: çevirmek, elindeki fazla eşyayı eritmeyi gerektiriyor.
  cevirme('c-', 'Çevirici');

  const MalzemeTuru(this.onEk, this.ad);

  final String onEk;
  final String ad;
}

/// MALZEME — alan 06'nın ikinci şeması.
///
/// Belgenin cümlesi: *"Malzemeler de eşya, ama **örneği yok**: yığılabilir ve
/// birbirinin aynısı. Kaydı daha kısa — kimlik, rank, yığılabilir. Alt statı,
/// artısı, kalitesi olmuyor."*
///
/// Bu üç eksiklik bir eksiklik DEĞİL, şemanın kendisi. Belgede değişmez olarak
/// duruyor ve kırılınca ne olacağı da yazılı: *"Malzeme eşya gibi davranmaya
/// başlamış; envanter ve mağaza karışıyor."* Bir malzemeye alt stat ya da artı
/// eklendiği an [ItemInstance] ile arasındaki fark kalmıyor, ve iki ayrı
/// envanterin var olma sebebi ortadan kalkıyor.
///
/// **Rank başına TEK malzeme.** Kimliği rankından türüyor, çünkü ayırt edici
/// başka bir özelliği yok — ve alan 14 bunu sayıyla da söylüyor:
/// *"1 malzeme ≡ 1 öldürme ≡ o bandın yaratık ödülü"* ([Ganimet.malzemeDegeriFor]).
/// Rank dışında bir eksen eklemek, o denkliği kıracak ikinci bir değişken
/// koymak olurdu.
/// KARAR 06.3 s1
class Malzeme {
  const Malzeme._(this.tur, this.rank);

  /// Ne için harcandığı.
  final MalzemeTuru tur;

  /// Bu malzemenin rankı.
  final ItemTier rank;

  /// Kalıcı kimlik. Envanterde ve telde bu duruyor.
  String get id => '${tur.onEk}${rank.name}';

  /// Oyuncunun gördüğü ad.
  String get ad => '${tur.ad} ${rank.label}';

  /// [rank] rankının YÜKSELTME malzemesi.
  static Malzeme forRank(ItemTier rank) =>
      _hepsi[MalzemeTuru.yukseltme.index * ItemTier.values.length + rank.index];

  /// [rank] rankının ÇEVİRİCİSİ.
  static Malzeme cevirmeFor(ItemTier rank) =>
      _hepsi[MalzemeTuru.cevirme.index * ItemTier.values.length + rank.index];

  /// Kimlikten malzeme. Tanınmayan kimlikte `null`.
  ///
  /// Envanterden okurken eşya kimlikleriyle karışmasın diye ön eki de
  /// denetliyor: `byId('pl4')` bir malzeme DEĞİL ve `null` dönmeli.
  static Malzeme? byId(String id) => _kimlikler[id];

  /// Her TÜRÜN her rankı.
  static final List<Malzeme> hepsi = _hepsi;

  static final List<Malzeme> _hepsi = [
    for (final tur in MalzemeTuru.values)
      for (final t in ItemTier.values) Malzeme._(tur, t),
  ];

  static final Map<String, Malzeme> _kimlikler = {
    for (final m in _hepsi) m.id: m,
  };

  @override
  String toString() => id;
}
