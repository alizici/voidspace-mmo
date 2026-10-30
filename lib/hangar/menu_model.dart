import 'package:flutter/widgets.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import 'item_glyph.dart';
import 'menu_theme.dart';

/// Mağazanın RAF AĞACI.
///
/// Sekiz kategori (lazer, roketatar, füze, mühimmat, jeneratör, cpu, droid,
/// gemi) dikey bir rayda sığmıyor: 8×44 + boşluklar 408 piksel eder, telefon
/// yatayda kullanılabilir yükseklik 358. Kaydırılabilir bir ray iki kategoriyi
/// ekran altında bırakırdı — ilerlemede ne olduğunu göstermemek demek.
///
/// Bunun yerine İKİ KADEME: grup rayda, kategori içerik başlığında yatay
/// şeritte. Gruplama keyfî değil, kararın kendisine göre: mühimmat ve füze
/// silahla aynı karar setinde, droid ve cpu sistemle.
enum ShopGroup {
  silah('SİLAH', [
    ShopShelf.laser,
    ShopShelf.launcher,
    ShopShelf.rocket,
    ShopShelf.ammo,
  ]),
  sistem('SİSTEM', [ShopShelf.generator, ShopShelf.cpu, ShopShelf.droid]),
  gemi('GEMİ', [ShopShelf.hull]);

  const ShopGroup(this.label, this.shelves);

  final String label;
  final List<ShopShelf> shelves;
}

/// Mağazanın bir rafı.
///
/// `SlotType` tek başına yetmiyor: GEMİ bir yuva türü değil, füze/mühimmat/
/// droid ise henüz hiçbir şey değil. [slot] olanlarda katalogdan okunuyor,
/// olmayanlarda raf AÇIK AMA BOŞ çiziliyor.
///
/// **Neden açılmamış raf gösteriliyor.** Kategoriyi tamamen saklamak,
/// oyuncuya ilerlemede ne olduğunu göstermemek olurdu. Boş durum kategoriyi
/// gösterir ve içi olmadığını söyler — vaat değil takvim.
enum ShopShelf {
  laser(slot: SlotType.laser),
  launcher(slot: SlotType.launcher),
  rocket(label: 'FÜZE', color: Palette.slotRocket, empty: ShelfEmpty.rocket),
  ammo(label: 'MÜHİMMAT', color: Palette.boost, empty: ShelfEmpty.ammo),
  generator(slot: SlotType.generator),
  cpu(slot: SlotType.cpu),
  droid(label: 'DROİD', color: Palette.slotDroid, empty: ShelfEmpty.droid),
  hull(label: 'GEMİ', color: Palette.accent);

  const ShopShelf({this.slot, String? label, Color? color, this.empty})
    : _label = label,
      _color = color;

  /// Katalogdan okunan raflarda dolu.
  final SlotType? slot;

  final String? _label;
  final Color? _color;

  /// Rafın içi yoksa gösterilecek boş durum.
  final ShelfEmpty? empty;

  /// Etiket DİLE göre: sabit bir dize olsaydı uygulama açılırken bir kez
  /// dondurulur ve dil değişince eski dilde kalırdı.
  String etiket(Dil dil) => _label ?? slotLabel(slot!, dil);

  Color get color => _color ?? slotColor(slot!);
}

/// Açılmamış rafın boş durumu.
///
/// Metin GEREKÇE söylüyor, "yakında" demiyor: oyuncunun öğrenmesi gereken
/// şey rafın neden ayrı durduğu.
enum ShelfEmpty {
  rocket(
    'FÜZE RAFI KAPALI',
    'Füze sistemi henüz yok. Raf burada duruyor ki ilerledikçe nerede '
        'açılacağını bilesin.',
  ),
  ammo(
    'MÜHİMMAT RAFI KAPALI',
    'Mühimmat tüketilebilir bir kalem; silah rafıyla aynı kararın parçası '
        'olduğu için burada.',
  ),
  droid(
    'DROİD RAFI KAPALI',
    'Droid kendi canı olan bir varlık; statları gemiyle karışmadan ayrı bir '
        'kapsamda toplanıyor.',
  );

  const ShelfEmpty(this.title, this.body);

  final String title;
  final String body;
}

/// Hangar sayfasının sekmeleri.
enum HangarTab {
  ekipman('EKİPMAN', Palette.accent),
  droid('DROİD', Palette.slotDroid),
  materyal('MATERYAL', Palette.boost),
  gemi('GEMİ', Palette.accent);

  const HangarTab(this.label, this.color);

  final String label;
  final Color color;
}

/// Ray ve şeritteki seçim düğmesi.
///
/// [MenuTab]'dan ayrı: bunun solunda yuva rengini taşıyan bir nokta var.
/// Renk kategori kimliğinin kendisi — oyuncu LAZER'i turuncudan tanıyor —
/// ve seçili sekmenin zeminini o renge boyamak dört kategoriyi dört farklı
/// düğme gibi gösteriyordu. Nokta rengi taşır, zemin sabit kalır.
class ShelfChip extends StatelessWidget {
  const ShelfChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.expand = false,
    super.key,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  final bool expand;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 40),
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.11)
            : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.36)
              : const Color(0x17FFFFFF),
        ),
      ),
      // KÜÇÜLEBİLİR: çip dar bir paya düştüğünde içindekiler taşıyordu.
      //
      // İçerideki iki yazı zaten kısalabiliyor ama nokta, aralıklar ve
      // dolgu sabit — payı onların toplamının altına inen bir çip, hiçbir
      // yazı olmasa bile taşıyor. `FittedBox` o son adımı alıyor: çip
      // sığmıyorsa bir tık küçülüyor, satırı kırmızıya boyamıyor.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuType.button(
                  color: selected ? Palette.inkBright : Palette.inkDim,
                ),
              ),
            ),
            if (trailing case final count?) ...[
              const SizedBox(width: 8),
              // SAYAÇ DA ESNEK. Etiket kısalabiliyordu ama sayaç sabitti ve
              // dar bir çipte satırı taşırıyordu — çipin içindeki her şey
              // kısalabilmeli, yoksa kısalabilen tek parça bütün yükü taşıyor.
              Flexible(
                child: Text(
                  count,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MenuType.label(
                    color: selected ? color : Palette.faint,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Boş durum kutusu — açılmamış raf, boş depo.
class EmptyPane extends StatelessWidget {
  const EmptyPane({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0x1AFFFFFF)),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: MenuType.section()),
            const SizedBox(height: 10),
            SizedBox(
              width: 340,
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: MenuType.label(color: Palette.faint),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Eşyanın işareti — [ItemGlyph.ofSpec] için kısa yol.
ItemGlyph glyphOf(ItemSpec spec) => ItemGlyph.ofSpec(spec);
