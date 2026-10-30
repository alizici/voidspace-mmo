/// Bir gövdede kaç silahın GÖRÜNECEĞİNİ belirleyen kural — gövdeden bağımsız.
///
/// **Neden veri + tek kural, gövde başına `switch` değil.** İlk yazışta kural
/// `Bastion` içinde elle yazılmış bir merdivendi (`<=2 → merkez`, `<=4 →
/// ön çift + merkez`, …). İkinci gövde geldiğinde o merdivenin bir kopyası
/// daha yazılacaktı, ve kopyalanan her kural bir gün ayrışır: bir gövdede üç
/// lazerle üç top çıkarken diğerinde iki top çıkardı ve hangisinin doğru
/// olduğunu kimse söyleyemezdi.
///
/// Burada gövde yalnız KENDİ dizilişini bildiriyor ([Armament.active]'in
/// `groups` parametresi); hangi grubun ne zaman açılacağına karar veren tek
/// bir kural var ve o kural burada.
abstract final class Armament {
  /// [lasers] lazer takılıyken açık olan yuva indeksleri.
  ///
  /// [groups] gövdenin yuvalarını AÇILMA SIRASINA göre gruplar. Her grup
  /// kendi boyutu kadar lazer ister ve ya tamamen açılır ya da hiç açılmaz.
  ///
  /// **Neden grup, neden tek tek değil.** Yuvalar simetrik geliyor: bir çiftin
  /// yalnız yarısını yakmak, geminin bir kanadı eksikmiş gibi görünmesine yol
  /// açıyor. "Kaç lazer varsa o kadar top" kuralı iki lazerli bir gemide
  /// merkez top artı TEK bir yüzgeç topu çizerdi — oyuncunun "gemi bozuk
  /// görünüyor" dediği şey tam olarak bu.
  ///
  /// Fazla lazerin karşılığı yok ve olmamalı: gövdede çizili kaide sayısı
  /// sanatın kendisi. Yedi yuvalı bir gövdede yedinci lazer statını veriyor
  /// ama oturacağı bir kaide yok — olmayan bir kaideye silah koymak, silahın
  /// havada durması demek.
  static List<int> active(List<List<int>> groups, int lasers) {
    if (lasers <= 0) return const [];
    final open = <int>[];
    var left = lasers;
    for (final group in groups) {
      if (left < group.length) break;
      left -= group.length;
      open.addAll(group);
    }
    return open;
  }

  /// [groups] içindeki toplam yuva sayısı — sanatın taşıdığı kaide sayısı.
  static int mountCount(List<List<int>> groups) {
    var n = 0;
    for (final group in groups) {
      n += group.length;
    }
    return n;
  }
}
