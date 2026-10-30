import 'package:voidspace_core/voidspace_core.dart';

/// Hedef kilidi — Tab ile sıradaki gemiye geçme.
///
/// Saf ve oyun döngüsünden bağımsız: aday listesi ve konumlar girer, seçim
/// çıkar. Flame ya da ağ bilmediği için kuralları (sıra, döngü, düşen hedef)
/// doğrudan test edilebilir.
///
/// Seçim ÜÇ kuralla yönetiliyor:
///
///  1. **Yakınlık sırası, ve sıra SABİT.** Adaylar mesafeye göre sıralanır;
///     Tab bir sonrakine geçer. Rastgele ya da kimlik sırası, ekranda
///     gördüğünle listedeki sıra arasındaki bağı koparırdı. Liste bir kez
///     kurulduktan sonra aday kümesi değişene kadar korunuyor: uçarken
///     mesafeler kare kare değiştiği için her basışta yeniden sıralamak,
///     düğmeye üç kez basan oyuncuyu aynı iki hedef arasında gezdiriyordu.
///  2. **Döngüsel.** Son hedeften sonra başa döner — "hedef kalmadı" diye
///     kilidi bırakmak, kalabalıkta sürekli baştan başlamak demek olurdu.
///  3. **Kaybolan hedef düşer.** Ölen, ayrılan ya da ilgi alanından çıkan
///     hedefin kilidi bırakılır; sunucu da aynısını yapar ([ShipSimState]
///     `weaponTarget`), yani iki uç kendiliğinden aynı fikirde kalır.
class Targeting {
  int _selected = 0;

  /// Son kurulan gezinme sırası — aday kümesi değişene kadar KORUNUYOR.
  ///
  /// Sıranın kalıcı olması, sırayı her basışta yeniden kurmanın yarattığı
  /// hatayı kapatıyor: mesafeye göre sıralama uçarken kare kare değişiyor,
  /// yani iki basış arasında sıra kayabiliyordu. Oyuncu düğmeye üç kez
  /// bastığında üç ayrı hedef beklerken aynı ikisi arasında gidip geliyordu.
  /// Liste bir kez kurulup korununca düğme gerçekten "sıradaki" demeye
  /// başlıyor.
  List<int> _order = const [];

  /// Kilitli hedefin kimliği; 0 = yok.
  int get selected => _selected;

  bool get hasTarget => _selected != 0;

  /// Sıradaki hedefe geç. [candidates] ekranda görülebilen kimlikler,
  /// [positionOf] her birinin dünya konumu, [from] geminin konumu.
  void cycle(
    Iterable<int> candidates,
    Vec2 from,
    Vec2? Function(int id) positionOf,
  ) {
    final canli = <int>[];
    final distances = <int, double>{};
    for (final id in candidates) {
      final p = positionOf(id);
      if (p == null) continue;
      distances[id] = p.distanceSquaredTo(from);
      canli.add(id);
    }
    if (canli.isEmpty) {
      _order = const [];
      _selected = 0;
      return;
    }

    // Sıra yalnız KÜME değiştiğinde yeniden kuruluyor: biri öldü, biri
    // göründü. Aynı adaylar duruyorsa mesafeleri değişmiş olsa bile eski
    // sıra geçerli.
    final onceki = _order.toSet();
    if (canli.length != _order.length || !onceki.containsAll(canli)) {
      canli.sort((a, b) => distances[a]!.compareTo(distances[b]!));
      _order = canli;
    }

    final current = _order.indexOf(_selected);
    // Kilit yoksa ya da hedef listeden düştüyse EN YAKINDAN başla.
    _selected = current < 0
        ? _order.first
        : _order[(current + 1) % _order.length];
  }

  /// [at] noktasına TIKLANDI: oradaki hedefi seç. Seçildiyse `true`.
  ///
  /// Dönüş değeri çağıran için bir KARAR: `true` ise tıklama tüketildi,
  /// `false` ise boşluğa tıklanmıştır ve gemi oraya gitmelidir. Bu ayrım
  /// olmadan her hedef seçimi aynı zamanda bir hareket emri olurdu —
  /// canavara tıklayan oyuncu onun üstüne uçardı.
  ///
  /// Isabetsiz tıklama seçimi BOZMAZ: kilidi olan bir oyuncunun haritada
  /// gezinmek için attığı her tık hedefini düşürseydi, nişan almak ile yol
  /// almak birbirini iptal ederdi.
  ///
  /// Üst üste binen adaylarda EN YAKIN olan kazanır — parmak kalın, ve
  /// altındaki iki şeyden hangisini kastettiğinin tek makul cevabı o.
  bool pick(
    Vec2 at,
    Iterable<int> candidates,
    Vec2? Function(int id) positionOf,
    double Function(int id) radiusOf,
  ) {
    var bestId = 0;
    var best = double.infinity;
    for (final id in candidates) {
      final p = positionOf(id);
      if (p == null) continue;
      final d2 = p.distanceSquaredTo(at);
      final r = radiusOf(id);
      if (d2 > r * r || d2 >= best) continue;
      best = d2;
      bestId = id;
    }
    if (bestId == 0) return false;
    _selected = bestId;
    return true;
  }

  /// Hedef hâlâ geçerli mi; değilse kilidi bırak.
  void validate(bool Function(int id) isValid) {
    if (_selected != 0 && !isValid(_selected)) _selected = 0;
  }

  /// Kilidi bırak.
  ///
  /// Sıra da unutuluyor: kilidi bilerek bırakan oyuncunun bir sonraki basışta
  /// beklediği şey, eski turun kaldığı yer değil O ANDA en yakın olan hedef.
  void clear() {
    _selected = 0;
    _order = const [];
  }
}
