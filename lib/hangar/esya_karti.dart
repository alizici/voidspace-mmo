import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../dil/sayi.dart' as bicim;
import 'item_glyph.dart';
import 'menu_cells.dart';
import 'menu_theme.dart';
import 'rank_kutusu.dart';
import 'rank_plakasi.dart';

/// EŞYA KARTI — bir parçanın KİMLİĞİNİ anlatan blok.
///
/// **Neden ayrı bir bileşen.** Aynı bilgi üç yerde gerekiyor: bilgi
/// penceresinde, mağaza kartında ve uzun basınca çıkan önizlemede. Üçü ayrı
/// yazıldığında ayrışıyor — nitekim rank plakası tam olarak öyle ayrışmıştı.
/// Kart tek kaynak; onu saran pencere ve düğmeler çağıranın işi.
///
/// **İŞLEM taşımıyor ve taşımamalı.** Kart "bu ne" sorusunu cevaplıyor; "ne
/// yapayım" sorusu ekrana göre değişiyor — mağazada SATIN AL, hangarda TAK.
/// Düğmeleri karta koymak, kartı iki ekrandan birine mahkûm ederdi.
///
/// Üç kural üstünde duruyor:
///
/// 1. **Rank rengi BAŞLIĞI sahipleniyor, kartı değil.** Tüm kartı rank
///    rengine boyamak metni okunmaz yapıyor. Renk yalnız üst şeritte ve
///    kenar hattında; gövde nötr koyu kalıyor.
/// 2. **Hiyerarşi tek bakışta:** ana stat > alt statlar > meta. Ana stat
///    kartın en büyük sayısı, çünkü oyuncu kartı "ne kadar güçlü" sorusuyla
///    açıyor.
/// 3. **Çevir kararı için ARALIK şart.** Alt statın değerini tek başına
///    göstermek işe yaramıyor — "bu iyi mi" sorusu ancak min–maks görününce
///    cevaplanıyor. Çevir mekaniği olan bir oyunda kartın en çok bakılan
///    yeri bu satır.
/// Bir alt statın kilit düğmesi — testler ve ekran bununla buluyor.
Key kilitKey(String statId) => ValueKey('kilit-$statId');

/// Güçlenme rozetinin anahtarı — testler için.
Key guclenmeKey(String statId) => ValueKey('guclenme-$statId');

class EsyaKarti extends StatelessWidget {
  const EsyaKarti({
    this.altStatlariAyir = false,
    this.kilitler = const {},
    this.onKilit,
    required this.spec,
    required this.instance,
    required this.hull,
    required this.metrics,
    this.yuzey = true,
    super.key,
  });

  final ItemSpec spec;
  final ItemInstance instance;
  final HullClass hull;
  final MenuMetrics metrics;

  /// Kart KENDİ yüzeyini çizsin mi.
  ///
  /// Tek başına dururken (mağaza kartı, önizleme) evet. Bilgi penceresinin
  /// içindeyken hayır — orada yüzeyi pencere çiziyor, çünkü GELİŞTİRME
  /// satırları ve düğmeler de aynı kutunun içinde durmalı. Kart kendi
  /// kutusunu çizip pencere bir kutu daha çizseydi, kutu içinde kutu olurdu.
  final bool yuzey;

  /// Alt stat listesi kartın DIŞINDA mı çizilecek.
  ///
  /// `true` ise kart listeyi atlıyor ve çağıran [altStatListesi] ile onu
  /// istediği yere koyuyor. Pencere bunu dar ekranda kullanıyor: yedi alt
  /// statlık bir kapak taşı, kimlikle aynı sütuna sığmıyor.
  final bool altStatlariAyir;

  /// Alt stat listesi kartın DIŞINDA mı çizilecek.
  ///
  /// `true` ise kart listeyi atlıyor ve çağıran [altStatListesi] ile onu
  /// istediği yere koyuyor. Pencere bunu dar ekranda kullanıyor: yedi alt
  /// statlık bir kapak taşı, kimlikle aynı sütuna sığmıyor.

  /// KİLİTLİ alt statlar — satırda kilit işaretiyle gösterilir (karar 07.5).
  final Set<String> kilitler;

  /// Kilit düğmesi — verilmişse her alt stat satırının başında bir kilit var.
  /// Mağaza önizlemesi vermez: orada kilitlenecek eşya yok.
  final void Function(String statId, bool kilitli)? onKilit;

  /// Yüzey oranlarının referansı — bkz. [RankPlakasi.yuzey].
  ///
  /// Büyük ikonla AYNI (110): kartın köşe yarıçapı, kol uzunluğu ve kıl
  /// çizgisi ikonunkiyle birebir aynı ölçüde. Kart, ikonun dilinin büyüğü;
  /// ayrı bir dil değil.
  static const double yuzeyOlcegi = 110;

  RankGorseli get _rank => RankGorseli.of(spec.tier);

  /// Alt statların ORTALAMA roll'u — kartın "bu eşya iyi mi" özeti.
  ///
  /// Tek tek çubuklara bakmak zorunda kalmadan bir sayı: %70 bandın tabanı,
  /// %100 mükemmel. Aralığı OLMAYAN statlar hesaba girmiyor — onlarda roll
  /// yok, ortalamaya karışmaları oranı yalancı biçimde yukarı çekerdi.
  double? get _cevirKalitesi {
    final altStatlar = LoadoutResolver.altStatlariFor(instance, spec, hull);
    var toplam = 0.0;
    var sayi = 0;
    for (final e in altStatlar.entries) {
      final aralik = _aralik(e.key);
      if (aralik == null) continue;
      final (enAz, enCok) = aralik;
      toplam += enCok > enAz
          ? ((e.value - enAz) / (enCok - enAz)).clamp(0.0, 1.0)
          : 1.0;
      sayi++;
    }
    if (sayi == 0) return null;
    final oran = toplam / sayi;
    // Bant içindeki konumdan MUTLAK yüzdeye: oyuncunun gördüğü sayı
    // "%70–100 arasında neredeyim" değil "kaç kalitedeyim" olmalı.
    final taban = ItemBudget.kaliteAltSiniriFor(spec.tier);
    return taban + oran * (1 - taban);
  }

  /// Bir alt statın çekilebileceği `(en az, en çok)` — aralığı yoksa `null`.
  (double, double)? _aralik(String statId) {
    final taban = ItemBudget.altStatTabani(
      spec,
      instance.level,
      hull,
      statId,
      instance.instanceId,
    );
    if (taban == null) return null;
    return (taban * ItemBudget.kaliteAltSiniriFor(spec.tier), taban);
  }

  /// ALT STAT LİSTESİ — kartın dışında da çizilebilsin diye ayrı.
  ///
  /// Kapak taşı bir eşya YEDİ alt stat taşıyor ([ItemBudget.altStatSayisi]) ve
  /// her biri iki satır yer istiyor (ad + değer, sonra kalite çubuğu ve
  /// sınırları). Yedi tanesi ~315 piksel ediyor; yatay bir telefonda pencereye
  /// kalan yükseklik ~300. Yani en üst rankta liste, kimlikle aynı sütunda
  /// duramıyor ve kaydırmaya düşüyordu — oyuncunun ödediği derinliğin bir
  /// kısmı ekranda hiç görünmüyordu.
  ///
  /// Ayrı bir metod olması pencerenin listeyi KENDİ sütununa koyabilmesi
  /// için: kart yine tek parça çiziliyor, yalnız çağıran isterse listeyi
  /// dışarı alabiliyor.
  List<Widget> altStatListesi(BuildContext context) {
    final dil = context.dil;
    final altStatlar = LoadoutResolver.altStatlariFor(instance, spec, hull);
    if (altStatlar.isEmpty) return const [];
    return [
      _altStatBasligi(altStatlar.length, dil),
      const SizedBox(height: 6),
      for (final e in altStatlar.entries)
        Padding(
          // Dar ekranda satır arası kısılıyor: yedi satır × 3 piksel, listenin
          // son satırını ekranın içinde tutan farkın bir parçası.
          padding: EdgeInsets.only(bottom: metrics.dense ? 3 : 6),
          child: _altStatSatiri(e.key, e.value, dil),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dil = context.dil;
    final altStatlar = LoadoutResolver.altStatlariFor(instance, spec, hull);
    final ayriListe = altStatlariAyir && altStatlar.isNotEmpty;
    final govde = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baslik(dil),
        SizedBox(height: metrics.gap),
        _anaStat(dil),
        if (altStatlar.isNotEmpty && !ayriListe) ...[
          SizedBox(height: metrics.gap),
          ...altStatListesi(context),
        ],
        SizedBox(height: metrics.gap * 0.6),
        _meta(dil),
      ],
    );
    if (!yuzey) return govde;
    return RankYuzeyi(
      rank: spec.tier,
      child: Padding(padding: const EdgeInsets.all(14), child: govde),
    );
  }

  /// KURAL 1 — rank rengi kartın YÜZEYİNDE, ayrı bir şeritte değil.
  ///
  /// Kaynak tasarım başlığa dolu bir gradyan şerit koyuyordu ve o şerit
  /// kutunun dilinden değildi: kutuda rank rengi bir parıltı ve bir kıl
  /// çizgi, şeritte ise geniş bir dolgu. Aynı eşyanın ikonu ile kartı iki
  /// ayrı dil konuşuyordu. Şerit kalktı; rengi yüzey taşıyor
  /// ([RankPlakasi.yuzey]) ve başlık yalnız içeriğini koyuyor.
  Widget _baslik(Dil dil) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // İkon ızgaradakiyle AYNI bileşen: kartın kimliği ile hücrenin
      // kimliği ayrı çizimler olsaydı oyuncu aynı eşyayı iki ayrı şey
      // sanardı. Burada BÜYÜK ve pip şeridi açık — bu boyda dört çubuk
      // sayılabiliyor.
      RankKutusu(
        boy: 96,
        rank: spec.tier,
        arti: instance.level,
        pip: true,
        artiUstte: true,
        isaret: KutuIsareti.esya(ItemGlyph.ofSpec(spec), slotColor(spec.slot)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // Örnek geçiliyor: droidin ADI da seçilen tasarımı yansıtsın,
              // hücredeki çizimle aynı kuralla (05.8 s2).
              esyaAdi(spec, dil, item: instance),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MenuType.title(metrics),
            ),
            const SizedBox(height: 4),
            // Seviye OYUNUN kendi diliyle: "+N", "SEVİYE N" değil. Aynı
            // pencerede rozet "+2" yazıp başlık "SEVİYE 2" derse aynı gerçek
            // iki sözlükle söylenmiş olur. Sıfırda hiç yazılmıyor — "+0" bir
            // bilgi değil.
            Text(
              instance.level > 0
                  ? '${slotLabel(spec.slot, dil)} · +${instance.level}'
                  : slotLabel(spec.slot, dil),
              style: MenuType.label(color: slotColor(spec.slot)),
            ),
            const SizedBox(height: 8),
            _rankRozeti(dil),
          ],
        ),
      ),
    ],
  );

  /// Rank rozeti — kartın "ne kadar nadir" cevabı.
  ///
  /// Kapak taşları etiket TAŞIYOR burada, hücrede taşımıyor: 56 piksele
  /// sığmayan "PARLAYAN PEMBE" bu genişlikte rahat duruyor, ve kartın işi
  /// zaten tam adı söylemek.
  Widget _rankRozeti(Dil dil) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _rank.taban.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _rank.taban.withValues(alpha: 0.8)),
      ),
      child: Text(
        rankEtiketi(spec.tier, dil),
        style: MenuType.label(color: _rank.acik),
      ),
    ),
  );

  /// KURAL 2 — kartın en büyük sayısı.
  ///
  /// Yanında rank çarpanı duruyor ve orası bir süs değil: "bu sayı nereden
  /// geldi" sorusunu cevaplıyor. Merdiven görünür kalmazsa 146.713 hasar
  /// keyfî bir sayı gibi okunuyor; ×1.047,9 onu bir basamağa bağlıyor.
  Widget _anaStat(Dil dil) {
    final deger = ItemBudget.mainStatValue(spec, instance.level, hull);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // Dart'ın `toUpperCase()`'i "Menzil"i "MENZIL" yazıyordu;
                  // stat adları tek yerden [menuUpper]'dan geçiyor.
                  menuUpper(statAdi(spec.mainStat, dil), dil),
                  style: MenuType.label(color: Palette.faint),
                ),
                const SizedBox(height: 3),
                Text(
                  bicimliStat(spec.mainStat, deger, dil),
                  maxLines: 1,
                  softWrap: false,
                  style: MenuType.number(
                    metrics,
                  ).copyWith(color: Palette.inkBright),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '×${_carpan(spec.tier.multiplier, dil)}',
                style: MenuType.body(color: _rank.acik),
              ),
              Text(
                Metin.rankCarpani(dil),
                style: MenuType.label(color: Palette.faint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Rank çarpanını yazar — küçükken ondalıklı, büyükken binlik ayraçlı.
  ///
  /// `menuNumber` tam sayıya yuvarlıyor ve C ailesinde bu bir YALAN oluyordu:
  /// C-II'nin çarpanı 1,442 ama kart "×1" yazıyordu — C-I ile aynı. Merdivenin
  /// ilk basamakları tam da ondalıkta ayrışıyor (1 · 1,4 · 2,1 · 3,0); tepede
  /// ise ondalık gürültü (1.047,9 yerine 1.048 yeter).
  ///
  /// Eşik yüz: altında bir ondalık, üstünde binlik ayraç.
  static String _carpan(double c, Dil dil) {
    if (c >= 100) return menuNumber(c, dil);
    // Tam sayıya düşen çarpanda ondalık YAZILMIYOR: "×3,0" değil "×3".
    // Ondalık ayracı dilden geliyor (`,` Türkçe/İtalyanca, `.` İngilizce).
    if (c == c.roundToDouble()) return bicim.sayi(c, dil);
    return bicim.ondalikli(c, dil);
  }

  /// "ALT STAT 2/4" — kaçı dolu, rank kaçını taşıyabiliyor.
  ///
  /// İkinci sayı olmadan ilki bir şey söylemiyor: iki alt statlı bir eşyanın
  /// iyi mi kötü mü olduğu, o rankın kapasitesine bağlı.
  Widget _altStatBasligi(int dolu, Dil dil) => Text(
    Metin.altStatSayaci.bicim(dil, {'dolu': dolu, 'derinlik': _rank.derinlik}),
    style: MenuType.label(color: Palette.faint),
  );

  /// KURAL 3 — değer, aralık ve aralık içindeki konum.
  Widget _altStatSatiri(String statId, double deger, Dil dil) {
    final aralik = _aralik(statId);
    final kilitli = kilitler.contains(statId);
    // Artı basmada bu stata düşen adımlar (karar 07.6): oyuncu neyin
    // güçlendiğini görsün, sürpriz kartta okunsun.
    final guclenme = ItemBudget.guclenmeSayisiFor(
      spec,
      instance.level,
      statId,
      instance.instanceId,
    );
    final satir = Row(
      children: [
        if (onKilit != null) ...[
          GestureDetector(
            key: kilitKey(statId),
            behavior: HitTestBehavior.opaque,
            onTap: () => onKilit!(statId, !kilitli),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                kilitli ? Icons.lock : Icons.lock_open,
                size: 14,
                color: kilitli ? Palette.accentBright : Palette.faint,
              ),
            ),
          ),
        ],
        Expanded(
          child: Text(
            statAdi(statId, dil),
            style: MenuType.body(
              color: kilitli ? Palette.accentBright : Palette.ink,
            ),
          ),
        ),
        if (guclenme > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '▲$guclenme',
              key: guclenmeKey(statId),
              style: MenuType.label(color: Palette.accentBright),
            ),
          ),
        Text(
          bicimliStat(statId, deger, dil),
          style: MenuType.body(color: Palette.inkBright),
        ),
      ],
    );
    if (aralik == null) return satir;
    final (enAz, enCok) = aralik;
    final oran = enCok > enAz
        ? ((deger - enAz) / (enCok - enAz)).clamp(0.0, 1.0)
        : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        satir,
        const SizedBox(height: 3),
        Row(
          children: [
            Text(
              bicimliStat(statId, enAz, dil),
              style: MenuType.label(color: Palette.faint),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 4,
                child: CustomPaint(painter: _RollCubugu(oran, _rank)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              bicimliStat(statId, enCok, dil),
              style: MenuType.label(color: Palette.faint),
            ),
          ],
        ),
      ],
    );
  }

  /// META — kalite bandı ve çevir ortalaması.
  ///
  /// Bant RANKA göre: C–S geniş, SS–SSS dar, kapak taşları en dar (karar
  /// 06.10); kart hangi bantta olduğunu [ItemBudget.kaliteAltSiniriFor]'dan
  /// okuyor, tablodan değil. Garantili alt stat sayısı da aynı karardan.
  Widget _meta(Dil dil) {
    final kalite = _cevirKalitesi;
    final taban = (ItemBudget.kaliteAltSiniriFor(spec.tier) * 100).round();
    final garanti = ItemBudget.garantiliFor(spec.tier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: const Color(0xFF1E2836)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                garanti > 0
                    ? Metin.kaliteBandiGarantili.bicim(dil, {
                        'taban': taban,
                        'garanti': garanti,
                      })
                    : Metin.kaliteBandi.bicim(dil, {'taban': taban}),
                style: MenuType.label(color: Palette.muted),
              ),
            ),
            if (kalite != null) ...[
              Text(
                Metin.cevirKalitesi(dil),
                style: MenuType.label(color: Palette.faint),
              ),
              const SizedBox(width: 8),
              Text(
                bicim.yuzde((kalite * 100).round(), dil),
                style: MenuType.body(color: _rank.acik),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Roll çubuğu — aralık içindeki konum.
///
/// Rengi RANKTAN geliyor: kartın her yerinde aynı aile rengi, çubuk da dahil.
/// Sabit bir vurgu rengi, üst ranklarda kartın geri kalanıyla kavga ediyordu.
class _RollCubugu extends CustomPainter {
  const _RollCubugu(this.oran, this.rank);

  final double oran;
  final RankGorseli rank;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = const Color(0xFF0A0E15),
    );
    if (oran <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * oran, size.height),
        r,
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [rank.taban, rank.acik],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_RollCubugu old) =>
      old.oran != oran || old.rank.tier != rank.tier;
}

/// RANK YÜZEYİ — herhangi bir içeriğin arkasına ikonun kutusunu koyar.
///
/// Bilgi penceresi ve tek başına duran kart bunu kullanıyor. Yüzeyin
/// oranları [EsyaKarti.yuzeyOlcegi]'nden: kart ikonun dilinin büyüğü.
class RankYuzeyi extends StatelessWidget {
  const RankYuzeyi({required this.rank, required this.child, super.key});

  final ItemTier rank;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(
      EsyaKarti.yuzeyOlcegi * RankPlakasi.koseOrani,
    ),
    child: CustomPaint(
      painter: _YuzeyBoyacisi(RankGorseli.of(rank)),
      child: child,
    ),
  );
}

class _YuzeyBoyacisi extends CustomPainter {
  const _YuzeyBoyacisi(this.rank);

  final RankGorseli rank;

  @override
  void paint(Canvas canvas, Size size) => RankPlakasi.yuzey(
    canvas,
    Offset.zero & size,
    rank,
    olcek: EsyaKarti.yuzeyOlcegi,
  );

  @override
  bool shouldRepaint(_YuzeyBoyacisi old) => old.rank.tier != rank.tier;
}
