import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../game/art/droid_art.dart';
import 'item_glyph.dart';
import 'malzeme_ikonu.dart';
import 'plaka_onbellegi.dart';
import 'rank_plakasi.dart';
import 'rank_saati.dart';

/// Kutunun İÇİNDEKİ işaret.
///
/// Eşya glifi ile malzeme silüeti apayrı çizimler ama aynı yere giriyorlar,
/// bu yüzden tek bir tip: çağıran ne koyacağını söylüyor, kutu nasıl
/// çizileceğini biliyor. Widget değil VERİ — kutu her şeyi tek boyacıda
/// çiziyor ve içeriye bir widget katmanı sokmak her hücreye bir `RenderObject`
/// daha eklerdi.
sealed class KutuIsareti {
  const KutuIsareti();

  /// Eşya işareti — lazer, kalkan, itki, roketatar, onarım, nişan.
  const factory KutuIsareti.esya(ItemGlyph glif, Color renk) = EsyaIsareti;

  /// Malzeme silüeti — fiyal (yükseltme) ya da kıvılcım (çevirici).
  const factory KutuIsareti.malzeme(MalzemeIkonu ikon) = MalzemeIsareti;

  /// Droid çizimi — hücrede droidin KENDİ görünüşü, jenerik bir glif değil.
  ///
  /// Oyuncu droidinin görünüşünü değiştirebiliyor (05.8 s2) ve envanterde
  /// görmesi gereken şey satın aldığı şema değil elindeki droid.
  const factory KutuIsareti.droid(DroidCizimi model) = DroidIsareti;
}

class EsyaIsareti extends KutuIsareti {
  const EsyaIsareti(this.glif, this.renk);
  final ItemGlyph glif;
  final Color renk;
}

class MalzemeIsareti extends KutuIsareti {
  const MalzemeIsareti(this.ikon);
  final MalzemeIkonu ikon;
}

class DroidIsareti extends KutuIsareti {
  const DroidIsareti(this.model);
  final DroidCizimi model;
}

/// RANK KUTUSU — bir eşyanın, malzemenin ya da boş bir yuvanın tek gösterimi.
///
/// **Neden tek bir bileşen.** Aynı kutu dört yerde çiziliyordu: donanım
/// yuvası, depo kutucuğu, malzeme çipi ve bilgi ekranı. Dördü ayrı yazılmıştı
/// ve ayrı yazıldıkları için ayrışıyorlardı — birinde yuva rengi halkası
/// vardı, diğerinde yoktu; birinde artı rozeti üstte, diğerinde altta; kıl
/// çizgi tabanı üçünde vardı birinde yoktu. Oyuncunun gördüğü şey "aynı eşya
/// iki ekranda iki farklı renk" oluyordu.
///
/// Artık tek kaynak var ve farklar PARAMETRE: hangi ekranın neye ihtiyacı
/// olduğu çağrı yerinde okunuyor, çizim mantığında değil.
///
/// ```
/// RankKutusu(boy: 56, rank: spec.tier, arti: item.level, child: isaret)
/// RankKutusu(boy: 110, rank: spec.tier, arti: item.level, pip: true, ...)
/// RankKutusu(boy: 30, rank: malzeme.rank, child: MalzemeSimgesi(...))
/// RankKutusu(boy: 56)                                    // boş yuva
/// ```
class RankKutusu extends StatelessWidget {
  const RankKutusu({
    required this.boy,
    this.rank,
    this.arti = 0,
    this.pip = false,
    this.yukseltme = false,
    this.secili = false,
    this.secimRengi,
    this.artiUstte = false,
    this.isaret,
    super.key,
  });

  /// Kenar uzunluğu. İçindeki her şey buna göre ölçekleniyor — tek bir sabit
  /// piksel yok, çünkü aynı kutu 30 ile 110 arasında dört boyda çiziliyor.
  final double boy;

  /// `null` — BOŞ kutu. Plaka yok, yalnız nötr bir çerçeve.
  final ItemTier? rank;

  /// Artı seviyesi (0..15). 0 ise rozet çizilmiyor.
  final int arti;

  /// Derinlik şeridi görünsün mü.
  ///
  /// Küçük kutuda KAPALI olmalı: 56 pikselde şerit 2 piksel yüksekliğinde
  /// dört çubuk ve okunmuyor. Okunmayan bir işaret bilgi vermiyor, yalnız
  /// kontrastı düşürüyor.
  final bool pip;

  /// Takılı olandan İYİ — depoda bunu gören oyuncu değişimi yapmalı.
  final bool yukseltme;

  /// Seçili — ayrıntı şeridinin anlattığı kutu.
  final bool secili;

  /// Seçim çerçevesinin rengi. `null` ise vurgu rengi.
  final Color? secimRengi;

  /// Artı rozeti ÜST köşede mi.
  ///
  /// Izgarada alt: üst köşe dolu (yükseltme işareti ve takılı halkası orada).
  /// Bilgi ekranında üst: orada o işaretler yok ama pip şeridi alt kenarda.
  /// Yani ikisinde de kural aynı — rozet BOŞ köşeye gidiyor.
  final bool artiUstte;

  /// Ortadaki işaret — eşya glifi, malzeme silüeti ya da hiçbir şey.
  final KutuIsareti? isaret;

  @override
  Widget build(BuildContext context) {
    final r = rank;
    final gorsel = r == null ? null : RankGorseli.of(r);
    final yorungeli = (gorsel?.yorungeNoktasi ?? 0) > 0;
    return SizedBox(
      width: boy,
      height: boy,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(boy * RankPlakasi.koseOrani),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // DURAN KATMAN — plaka, işaret, rozetler.
            //
            // Saati OKUMUYOR: bu katmanın içinde kare kare değişen hiçbir şey
            // yok, o yüzden bir kez kaydediliyor. Yörüngeli ranklarda
            // [RepaintBoundary] ile kendi katmanına ayrılıyor ki üstündeki
            // nokta döndüğünde bu yüzey yeniden rasterize edilmesin;
            // yörüngesiz ranklarda sınır KOYULMUYOR, çünkü orada kıpırdayan
            // bir şey yok ve boş yere katman açmak bedelin kendisi olurdu.
            _sinirla(
              yorungeli,
              CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _KutuBoyacisi(
                  gorsel: gorsel,
                  isaret: isaret,
                  arti: arti,
                  pip: pip,
                  yukseltme: yukseltme,
                  artiUstte: artiUstte,
                  oran: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
                ),
              ),
            ),
            // DÖNEN KATMAN — yalnız yörünge noktaları.
            //
            // Ayrı bir boyacı, çünkü saate abone olan tek şey bu. Eskiden
            // ikisi tek boyacıdaydı ve nokta döndükçe plakanın tamamı —
            // gradyanlı zemin, kenarlık, kademe şeridi, işaret — yeniden
            // çiziliyordu.
            if (yorungeli)
              CustomPaint(
                painter: _YorungeBoyacisi(
                  gorsel: gorsel!,
                  faz: RankSaati.of(context),
                ),
              ),
            if (secili)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    boy * RankPlakasi.koseOrani,
                  ),
                  border: Border.all(
                    color: secimRengi ?? Palette.accentBright,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Katman sınırı — yalnız [gerek] doğruyken.
///
/// `RepaintBoundary` bedava değil: her sınır bir katman, her katman
/// birleştirme maliyeti. Kırk hücrenin kırkına birden koymak, çözdüğü
/// sorundan pahalıya mal olurdu. Yalnız üstünde kıpırdayan bir şey olan
/// hücreler ayrılıyor.
Widget _sinirla(bool gerek, Widget cocuk) =>
    gerek ? RepaintBoundary(child: cocuk) : cocuk;

/// DÖNEN katman — yörünge noktaları ve başka hiçbir şey.
class _YorungeBoyacisi extends CustomPainter {
  _YorungeBoyacisi({required this.gorsel, required this.faz})
    : super(repaint: faz);

  final RankGorseli gorsel;
  final ValueListenable<double>? faz;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    RankPlakasi.yorunge(canvas, size.shortestSide, gorsel, faz?.value ?? 0);
  }

  @override
  bool shouldRepaint(_YorungeBoyacisi old) =>
      old.gorsel != gorsel || old.faz != faz;
}

class _KutuBoyacisi extends CustomPainter {
  const _KutuBoyacisi({
    required this.gorsel,
    required this.isaret,
    required this.arti,
    required this.pip,
    required this.yukseltme,
    required this.artiUstte,
    required this.oran,
  });

  final RankGorseli? gorsel;
  final KutuIsareti? isaret;
  final int arti;
  final bool pip;
  final bool yukseltme;
  final bool artiUstte;

  /// Cihazın piksel oranı — pişmiş zemin gerçek piksel sayısında pişsin diye.
  final double oran;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);
    final g = gorsel;
    if (g == null) {
      RankPlakasi.bosKutu(canvas, s);
      _isaretCiz(canvas, s, null);
      return;
    }
    // Zemin PİŞMİŞ dokudan: aynı rank ve boydaki bütün hücreler tek dokuyu
    // paylaşıyor (bkz. [PlakaOnbellegi]).
    PlakaOnbellegi.zemin(canvas, s, g, detay: pip, oran: oran);
    // Malzeme silüeti plakanın ÜSTÜNDE: silüet büyük ve noktaları yerdi, ama
    // plakanın parıltısını da örtmemeli. Yörünge artık ÜSTTEKİ katmanda.
    _isaretCiz(canvas, s, g);
    if (yukseltme) RankPlakasi.yukseltmeIsareti(canvas, s);
    RankPlakasi.artiRozeti(canvas, s, arti, altKose: !artiUstte);
  }

  /// İşareti merkeze çizer. Eşya glifi kendi kutusuna ölçekleniyor, malzeme
  /// silüeti zaten orijine göre çiziliyor.
  void _isaretCiz(Canvas c, double s, RankGorseli? g) {
    switch (isaret) {
      case null:
        return;
      case EsyaIsareti(:final glif, :final renk):
        final boy = rankIsaretBoyu(s);
        c
          ..save()
          ..translate(-boy / 2, -boy / 2);
        ItemGlyphPainter(glif, renk).paint(c, Size(boy, boy));
        c.restore();
      case MalzemeIsareti(:final ikon):
        // Malzemenin rankı yoksa nötr bir gri ile çiziliyor: kutu boş
        // olabilir ama silüet yine de ne olduğunu söylemeli.
        MalzemePlakasi.siluet(c, s, ikon, g ?? RankGorseli.of(ItemTier.cI));
      case DroidIsareti(:final model):
        // Eşya glifiyle AYNI boy: aynı ızgarada bir droid ile bir lazer yan
        // yana duruyor ve ikisinin farklı büyüklükte çizilmesi, kutuların
        // tek kaynaktan gelmesinin amacını bozardı. `draw` YARIÇAP alıyor,
        // glif ise kenar — arasındaki iki katı fark burada.
        DroidArt.of(model).draw(c, size: rankIsaretBoyu(s) / 2);
    }
  }

  @override
  bool shouldRepaint(_KutuBoyacisi old) =>
      old.oran != oran ||
      old.isaret != isaret ||
      old.gorsel?.tier != gorsel?.tier ||
      old.arti != arti ||
      old.pip != pip ||
      old.yukseltme != yukseltme ||
      old.artiUstte != artiUstte;
}

/// Kutunun İÇİNDEKİ işaretin ölçüsü — çağrı yerlerinin ortak oranı.
///
/// Elle 0,52 yazmak yerine burada: dört ekran aynı oranı kullanıyor ve biri
/// kaydığında fark ediliyor.
double rankIsaretBoyu(double kutu) => kutu * 0.52;

/// Yörünge noktalarının çarpmadığı en büyük işaret — teşhis için.
double rankIsaretTavani(double kutu) => kutu * 2 * (0.32 - 0.030);

/// İki oranın ayrışmadığını doğrulamak testin işi; burada yalnız hesap.
bool rankIsaretiSigiyor(double kutu) =>
    rankIsaretBoyu(kutu) <= rankIsaretTavani(kutu) + math.pow(10, -9);
