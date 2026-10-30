import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../net/hangar_view.dart';
import 'menu_cells.dart';
import 'menu_theme.dart';
import 'rank_saati.dart';
import 'unvan_amblemi.dart';
import 'unvan_yazisi.dart';

const Key unvanKartiKey = Key('unvan-karti');
const Key unvanKartiKapatKey = Key('unvan-karti-kapat');

/// ArGe ağacını açan satır — pilot kartındaki GİRİŞ NOKTASI.
const Key unvanKartiArGeKey = Key('unvan-karti-arge');
Key unvanMerdiveniKey(int adIndeksi) => Key('unvan-merdiven-$adIndeksi');

/// PİLOT KARTI — unvanın tam hâli: amblem, çağ, kademe ve sıradaki eşik.
///
/// Unvan satırı (10.4) "kimim" sorusuna bir satırla cevap veriyor; bu kart
/// ikinci soruya: "sıradaki ne ve ne kadar kaldı". İkisi ayrı yerde durmak
/// zorunda — eşik ve merdiven başlığa sığmıyor, satır da bir karta
/// dönüştürülemez, çünkü HUD'da her karede çiziliyor.
///
/// **Eşik burada HESAPLANIYOR, sunucudan gelmiyor** ve bu bir istisna değil:
/// [CombatGlossary.unvanEsigi] sunucunun kapıda kullandığı fonksiyonun ta
/// kendisi (ortak paket), ikinci bir uygulama değil. Oyuncunun ŞU ANKİ
/// unvanı yine sunucudan; istemci onu puandan türetmiyor.
///
/// Merdiven şeridi yirmi adı birden gösteriyor: geçilenler yanık, sıradaki
/// vurgulu, kalanlar sönük. Oyuncu nerede olduğunu ancak bütünü görünce
/// anlıyor — tek bir amblem "ilerliyorum" der, şerit "ne kadar kaldı" der.
///
/// **ARGE'NİN GİRİŞİ DE BURADA** (05.7, borç defteri B33). ArGe puanı
/// SEVİYEDEN geliyor (10.1) ve seviyeyi gösteren yüzey bu kart: "kaç puanım
/// var" ile "onları nereye harcarım" aynı yerde durmalı. Alternatif beşinci
/// bir hangar sekmesiydi ve reddedildi — dört sekmelik ferah düzeni, oyuncunun
/// yalnız seviye atladığında baktığı bir sistem için bozmak pahalı bir takas.
/// Kartın kendisi ağacı TAŞIMIYOR: alt şeridindeki düğme sayacı gösteriyor ve
/// `ArGeKarti`'nı açıyor. İki dal × dört düğüm bu kartı iki katına çıkarır ve
/// merdiveni ulaşılmaz bir yere iterdi — ölçüldü: gövdeye konan bir ArGe bloğu
/// bile masaüstünde dördüncü çağın satırını şeridin altına düşürüyordu.
///
/// Düğme puan yokken de AÇIK: ağacı görmek onu kullanabilmeyi gerektirmiyor,
/// ve kapalı bir düğme oyuncuya neyin eksik olduğunu söylemiyor. Ağacın
/// içinde her düğümün altında sebebi yazıyor — orası sebebi söyleyebilen tek
/// yer.
class UnvanKarti extends StatefulWidget {
  const UnvanKarti({
    required this.hangar,
    required this.metrics,
    required this.onArGe,
    required this.onClose,
    super.key,
  });

  final HangarView hangar;
  final MenuMetrics metrics;

  /// ArGe ağacını açar — kart altında AÇIK kalıyor, oyuncu kapatınca buraya
  /// dönüyor.
  final VoidCallback onArGe;

  final VoidCallback onClose;

  @override
  State<UnvanKarti> createState() => _UnvanKartiState();
}

class _UnvanKartiState extends State<UnvanKarti>
    with SingleTickerProviderStateMixin {
  /// Amblemin saati. Tek denetleyici, tek faz: her glif kendi süresini bu
  /// saatten türetiyor, yani iki katman asla ayrı hızlarda kaymıyor.
  ///
  /// Süre uzun (bir dakika) ve bilerek: içindeki döngüler saniyeler
  /// mertebesinde ve hepsi bu tek sayacı okuyor.
  late final AnimationController _saat = AnimationController(
    vsync: this,
    duration: _turSuresi,
  )..repeat();

  static const Duration _turSuresi = Duration(seconds: 60);

  /// Amblemi MENÜ HIZINDA süren saat — bkz. [KisikFaz].
  ///
  /// Buradaki bedel plakalarınkinden ağır: [AnimatedBuilder] yalnız yeniden
  /// boyamıyor, amblem ağacını yeniden KURUYOR. Ekranın tazeleme hızında
  /// (bu telefonda 120 Hz) saniyede 120 kez yeniden kurulan bir ağaç, altmış
  /// saniyede bir tur atan bir animasyon için fazlasıyla pahalı.
  late final KisikFaz _kisikSaat = KisikFaz(
    _saat,
    saniye: _turSuresi.inMilliseconds / 1000,
  );

  @override
  void dispose() {
    _kisikSaat.dispose();
    _saat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hangar;
    final m = widget.metrics;
    final indeks = h.unvan.clamp(0, TasarimGirdileri.unvanSayisi - 1);
    final adIndeksi = Unvan.adIndeksi(indeks);
    final kademe = Unvan.kademe(indeks);
    final tepede = indeks >= TasarimGirdileri.unvanSayisi - 1;
    // Kartın boyu EKRANIN boyundan: telefon yatayda 390 piksel ve amblem
    // orada 84 olsaydı kart kaydırılmadan okunmazdı. Merdiven şeridi de
    // aynı sebeple küçülüyor — yirmi ikon dört satıra çıkıyor.
    final dar = m.dense || m.width < 520;
    final amblemBoyu = dar ? 46.0 : 84.0;
    final merdivenBoyu = dar ? 16.0 : 22.0;
    // Dar ekranda dikey boşluklar kısılıyor: kart 390 piksele KAPAT düğmesi
    // dahil sığmalı, yoksa oyuncu kartı kapatmak için kaydırmak zorunda.
    final bosluk = dar ? 10.0 : m.gap;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: ColoredBox(
          color: Palette.perde,
          // Kenar payı MERKEZİN DIŞINDA: içeride olduğunda `Center` çocuğa
          // ekran yüksekliği kadar yer veriyor, çocuk payını onun üstüne
          // ekliyor ve toplam ekranı aşıyordu — kart yukarıdan taşıyordu.
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: dar ? 6 : m.gutter),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    key: unvanKartiKey,
                    width: (m.width - m.gutter * 2).clamp(280.0, 460.0),
                    padding: EdgeInsets.all(dar ? 12 : m.gutter),
                    decoration: BoxDecoration(
                      color: Palette.menuPanel,
                      border: Border.all(color: Palette.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    // İÇERİK KAYAR, KAPAT SABİT.
                    //
                    // Düğme kaydırılan listenin sonundaydı ve içerik uzun
                    // olduğunda ekranın dışında kalıyordu: 560×620'lik bir
                    // pencerede kartın altı kesiliyor ve KAPAT'ın yalnız üst
                    // kenarı görünüyordu. Kartı kapatmanın tek yolu perdeye
                    // dokunmak oluyordu — o da öğrenilmesi gereken bir
                    // hareket, oysa düğme zaten oradaydı.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Amblem tek örnek: hareket bedeli bir kez ödeniyor
                                // (bkz. unvan_amblemi.dart). Dar ekranda YAN YANA,
                                // geniş ekranda üst üste — telefon yatayda kartın
                                // boyu 390 piksel ve alt alta dizilen bir amblem +
                                // başlık, merdiveni katlanan alanın altına itiyordu.
                                if (dar)
                                  Row(
                                    children: [
                                      _amblem(adIndeksi, kademe, amblemBoyu),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _kimlik(
                                          h,
                                          indeks,
                                          kademe,
                                          m,
                                          true,
                                          context.dil,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _amblem(adIndeksi, kademe, amblemBoyu),
                                  SizedBox(height: m.gap),
                                  _kimlik(
                                    h,
                                    indeks,
                                    kademe,
                                    m,
                                    false,
                                    context.dil,
                                  ),
                                ],
                                SizedBox(height: bosluk),
                                _ilerleme(h, indeks, tepede, m, context.dil),
                                SizedBox(height: bosluk),
                                Divider(color: Palette.line, height: 1),
                                SizedBox(height: bosluk),
                                SectionLabel(Metin.merdiven(context.dil)),
                                const SizedBox(height: 8),
                                _merdiven(adIndeksi, merdivenBoyu, context.dil),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: bosluk),
                        // ARGE, KAYDIRILAN İÇERİKTE DEĞİL SABİT ŞERİTTE.
                        //
                        // Önce merdivenin üstüne, kartın gövdesine konmuştu
                        // (bölüm etiketi + tam genişlikte düğme) ve görsel
                        // referans bedelini gösterdi: blok 105 piksel tutuyor,
                        // masaüstünde bile kartı kaydırılır yapıyor ve dördüncü
                        // çağın satırı şeridin altına düşüyordu — ArGe'yi
                        // eklemek merdiveni kırpıyordu.
                        //
                        // Alt şerit zaten orada ve zaten 44 piksel: ikinci
                        // düğme HİÇ yer eklemiyor. Üstelik kartın iki EYLEMİ
                        // yan yana duruyor ve ikisi de kaydırmadan görünüyor —
                        // görünmeyen bir eylem yok demektir.
                        Row(
                          children: [
                            Expanded(
                              child: MenuButton(
                                key: unvanKartiArGeKey,
                                // Sayaç DÜĞMENİN İÇİNDE: ayrı bir etiket satırı
                                // bu şeride sığmıyor ve "3/6 PUAN" o düğmenin
                                // neden basılacağını söyleyen tek şey.
                                label: Metin.argeOzeti.bicim(context.dil, {
                                  'harcanan': menuNumber(
                                    h.argeHarcanan,
                                    context.dil,
                                  ),
                                  'toplam': menuNumber(
                                    h.argePuani,
                                    context.dil,
                                  ),
                                }),
                                filled: false,
                                expand: true,
                                onTap: widget.onArGe,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: MenuButton(
                                key: unvanKartiKapatKey,
                                label: Metin.kapat(context.dil),
                                filled: false,
                                expand: true,
                                onTap: widget.onClose,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _amblem(int adIndeksi, int kademe, double boy) => AnimatedBuilder(
    animation: _kisikSaat,
    builder: (context, _) => UnvanAmblemi(
      unvanIndeksi: adIndeksi,
      kademe: kademe,
      boy: boy,
      zaman: _kisikSaat.value * _turSuresi.inSeconds,
    ),
  );

  /// Ad ve altındaki çağ/kademe satırı. Dar ekranda sola, geniş ekranda
  /// ortaya hizalı: yanında amblem varken ortalanmış metin kayık görünüyor.
  Widget _kimlik(
    HangarView h,
    int indeks,
    int kademe,
    MenuMetrics m,
    bool dar,
    Dil dil,
  ) => Column(
    crossAxisAlignment: dar
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Kartın başlığı da unvanın kendi tipografisiyle: satırdaki ad ile
      // buradaki ad aynı yazı, yalnız punto farklı.
      UnvanYazisi(ad: h.unvanAdi, unvanIndeksi: indeks, boy: dar ? 18 : 24),
      const SizedBox(height: 4),
      Text(
        Metin.cagKademe.bicim(dil, {
          'cag': menuUpper(cagAdi(indeks, dil), dil),
          'kademe': Unvan.roma(kademe),
          'tavan': Unvan.roma(Unvan.adBasinaBasamak - 1),
        }),
        style: MenuType.label(color: Palette.muted),
        textAlign: dar ? TextAlign.left : TextAlign.center,
      ),
    ],
  );

  /// Bu unvanın içindeki ilerleme: iki eşik arası, oran ve sıradaki ad.
  ///
  /// Eşikler geometrik (10.3), yani aradaki mesafe oranla okunuyor: doğrusal
  /// bir çubuk üst ranklarda hep dolu görünürdü.
  Widget _ilerleme(
    HangarView h,
    int indeks,
    bool tepede,
    MenuMetrics m,
    Dil dil,
  ) {
    if (tepede) {
      return Text(
        Metin.merdiveninTepesiBr.bicim(dil, {
          'br': menuNumber(h.br.round(), dil),
        }),
        style: MenuType.body(color: Palette.accentBright),
      );
    }
    final alt = CombatGlossary.unvanEsigi(indeks);
    final ust = CombatGlossary.unvanEsigi(indeks + 1);
    final oran = ust <= alt
        ? 1.0
        : ((h.br - alt) / (ust - alt)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${menuNumber(h.br.round(), dil)} BR',
              style: MenuType.body(color: Palette.accent),
            ),
            Text(
              '${menuNumber(ust.round(), dil)} BR',
              style: MenuType.label(color: Palette.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: oran,
            minHeight: 6,
            backgroundColor: Palette.space,
            valueColor: AlwaysStoppedAnimation(
              UnvanPaleti.of(Unvan.adIndeksi(indeks)).acik,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          Metin.sonrakiUnvan.bicim(dil, {
            // [menuUpper] DEĞİL: unvan adları (Squire, Knight, Star Lord)
            // çevrilmeyen özel adlar ve Türkçe kuralı onları bozardı —
            // "KNİGHT". Türkçeleşen tek şey çağ adı, o da yukarıda.
            'ad': Unvan.adi(indeks + 1).toUpperCase(),
          }),
          style: MenuType.label(color: Palette.muted),
        ),
      ],
    );
  }

  /// MERDİVEN: dört satır, her satır bir ÇAĞ, her satırda beş ad.
  ///
  /// Düz bir şerit yirmi ikonu tek sıraya diziyordu ve çağ sınırı
  /// görünmüyordu; oysa çağ atlamak merdivenin en büyük eşiği (aparat orada
  /// katman değiştiriyor). Satırlar çağın kendisi, etiketi de solda.
  Widget _merdiven(int adIndeksi, double boy, Dil dil) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var cag = 0; cag < Unvan.caglar.length; cag++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: boy * 3.4,
                child: Text(
                  menuUpper(cagAdiSirali(cag, dil), dil),
                  style: MenuType.label(
                    color: cag == adIndeksi ~/ Unvan.cagBasinaAd
                        ? Palette.accent
                        : Palette.faint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (var j = 0; j < Unvan.cagBasinaAd; j++)
                () {
                  final i = cag * Unvan.cagBasinaAd + j;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Opacity(
                      key: unvanMerdiveniKey(i),
                      // Üç durum, üç opaklık: geçilen yarı yanık, şu anki
                      // tam, kalan silik. Kalanları hiç çizmemek merdivenin
                      // uzunluğunu gizlerdi; fazla silik çizmek de.
                      opacity: i < adIndeksi
                          ? .6
                          : i == adIndeksi
                          ? 1
                          : .32,
                      child: UnvanIkonu(
                        unvanIndeksi: i,
                        // Geçilenler tam kademeyle: şerit "nereye kadar
                        // bitti" diyor, "kaç kademe kaldı" demiyor.
                        kademe: i < adIndeksi ? Unvan.adBasinaBasamak - 1 : 0,
                        boy: boy,
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
    ],
  );
}
