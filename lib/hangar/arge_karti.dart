import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../dil/sayi.dart' as bicim;
import '../net/hangar_view.dart';
import 'menu_cells.dart';
import 'menu_theme.dart';

const Key argeKartiKey = Key('arge-karti');
const Key argeKapatKey = Key('arge-kapat');
const Key argeSifirlaKey = Key('arge-sifirla');
Key argeDugumKey(String id) => Key('arge-dugum-$id');
Key argeDaliKey(ArGeDali dal) => Key('arge-dal-${dal.name}');

/// ARGE AĞACI — dallar, zincir, puan sayacı ve sıfırlama (05.7).
///
/// **Neden PİLOT KARTINDAN açılıyor.** ArGe puanı SEVİYEDEN geliyor (10.1) ve
/// pilot kartı zaten seviyeyi, unvanı ve sıradaki eşiği gösteren yüzey
/// (10.4 s2): "kaç puanım var" sorusunun cevabı orada duruyor, "onları nereye
/// harcarım" sorusununki de orada durmalı. Beşinci bir hangar sekmesi, dört
/// sekmelik ferah düzeni bir sistem için bozardı — üstelik oyuncunun günde bir
/// kez, seviye atladığında baktığı bir sistem için.
///
/// **Neden karta GÖMÜLMEDİ, ayrı pencere.** Kart bugün beş bölüm taşıyor
/// (amblem, kimlik, ilerleme çubuğu, ayırıcı, yirmi adlık merdiven) ve telefon
/// yatayda zaten kaydırılıyor. İki dal × dört düğüm, altına sıfırlama, o kartı
/// iki katına çıkarır ve merdiveni kimsenin ulaşamadığı bir yere iterdi.
/// Giriş noktası kart, yüzey ayrı: karttaki satır sayacı gösteriyor ve
/// dokunulunca burası açılıyor, kart altında AÇIK kalıyor — kapatınca oyuncu
/// geldiği yere dönüyor.
///
/// **Ağaç ÇEKİRDEKTEN okunuyor** (`ArGe.hepsi`), sunucudan gelmiyor: düğümler
/// sabit bir tablo ve hangar durumu her işlemde baştan gidiyor. Sunucunun
/// yolladığı tek şey hangi düğümlerin ALINDIĞI. Aynı sebeple dallar
/// `ArGeDali.values` üstünden değil, düğümlerin kendi dallarından çıkıyor:
/// bugün ağaçta iki dal dolu, üçüncüsü (izin dalı) tanımlı ama boş — boş bir
/// dalın başlığını çizmek, oyuncuya olmayan bir yolu göstermek olurdu.
///
/// **Kararlar ÇEKİRDEĞİN**: alınabilirlik [HangarView.argeAlinabilir]
/// üzerinden `ArGe.alinabilir`'e, puanlar `ArGe.puanFor` ve `ArGe.harcanan`'a
/// soruluyor. Burada ikinci bir kural yazmak, oyuncunun basabildiği bir
/// düğümden ret yemesi demekti.
/// KARAR 05.7 s2
class ArGeKarti extends StatelessWidget {
  const ArGeKarti({
    required this.hangar,
    required this.metrics,
    required this.onAl,
    required this.onSifirla,
    required this.onClose,
    super.key,
  });

  final HangarView hangar;
  final MenuMetrics metrics;

  /// Düğüm alma NİYETİ — sunucuya `arge_al` gidiyor, karar orada.
  final ValueChanged<String> onAl;

  /// Ağacı sıfırlama niyeti — `arge_sifirla`.
  final VoidCallback onSifirla;

  final VoidCallback onClose;

  /// Ağaçtaki dallar, düğümlerin kendi sırasında — boş dal listede yok.
  static List<ArGeDali> get dallar {
    final gorulen = <ArGeDali>[];
    for (final d in ArGe.hepsi) {
      if (!gorulen.contains(d.dal)) gorulen.add(d.dal);
    }
    return gorulen;
  }

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final dil = context.dil;
    // Ölçüt YÜKSEKLİK, genişlik değil — ve pilot kartından ayrılan tek yer
    // burası. O kart genişliğe bakıyor çünkü orada sıkışan şey amblemin
    // yanındaki başlık; burada sıkışan şey dört düğümlük zincir ve zincir
    // DİKEY. 560×620'lik pencere geniş sayılıp ferah çizildiğinde dördüncü
    // düğümün durum satırı kaydırma alanının altında kalıyordu — görsel
    // referansta ölçüldü.
    final dar = m.dense || m.height < 700;
    // Kısa ekranda boşluk 10'dan 7'ye: dört boşluk × 3 piksel, dördüncü
    // düğümün ikinci satırının kaydırmadan görünmesine yetiyor. Daha aşağı
    // inmiyor — 7'nin altında başlık, ağaç ve düğmeler tek bir blok gibi
    // okunmaya başlıyor.
    final bosluk = m.dense ? 7.0 : (dar ? 10.0 : m.gap);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: ColoredBox(
          color: Palette.perde,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: dar ? 6 : m.gutter),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    key: argeKartiKey,
                    // Pilot kartından GENİŞ: orada tek sütun var, burada iki
                    // dal yan yana. 460'a sıkıştırılan dallar düğüm adını
                    // ikinci satıra kırıyordu.
                    width: (m.width - m.gutter * 2).clamp(300.0, 640.0),
                    padding: EdgeInsets.all(
                      m.dense ? 10 : (dar ? 12 : m.gutter),
                    ),
                    decoration: BoxDecoration(
                      color: Palette.menuPanel,
                      border: Border.all(color: Palette.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    // İÇERİK KAYAR, DÜĞMELER SABİT — pilot kartındaki kuralın
                    // aynısı: iki dal 560×620'lik bir pencerede kartın altını
                    // ekranın dışına itiyor ve SIFIRLA ile KAPAT görünmez
                    // oluyordu.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _baslik(dil, m),
                        SizedBox(height: bosluk),
                        Divider(color: Palette.line, height: 1),
                        SizedBox(height: bosluk),
                        Flexible(
                          child: SingleChildScrollView(
                            child: _dallar(dil, dar, m.dense),
                          ),
                        ),
                        SizedBox(height: bosluk),
                        _altBilgi(dil, m.dense),
                        SizedBox(height: bosluk),
                        _dugmeler(dil),
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

  /// Başlık ve PUAN SAYACI — harcanan / toplam, altında kalan.
  ///
  /// İki sayı birden yazılıyor çünkü oyuncunun sorduğu iki ayrı soru var:
  /// "bu ağaca ne kadar yatırdım" ve "elimde ne kaldı". Tek bir sayı (kalan)
  /// yatırımı gizler, tek bir sayı (harcanan) da bir sonraki düğümün alınıp
  /// alınamayacağını söylemez.
  Widget _baslik(Dil dil, MenuMetrics m) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Metin.argeAgaci(dil),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MenuType.title(m),
            ),
            const SizedBox(height: 4),
            Text(
              Metin.argeGucVermez(dil),
              maxLines: 2,
              style: MenuType.label(color: Palette.muted),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Metin.argePuanSayaci.bicim(dil, {
              'harcanan': bicim.sayi(hangar.argeHarcanan, dil),
              'toplam': bicim.sayi(hangar.argePuani, dil),
            }),
            key: argePuanKey,
            style: MenuType.body(color: Palette.accent),
          ),
          const SizedBox(height: 4),
          Text(
            Metin.argeKalanPuan.bicim(dil, {
              'n': bicim.sayi(hangar.argeKalan, dil),
            }),
            style: MenuType.label(
              // Puanı bitmiş oyuncuya kalanı VURGULU yazmak, ona olmayan bir
              // şeyi işaret etmek olurdu.
              color: hangar.argeKalan > 0
                  ? Palette.accentBright
                  : Palette.faint,
            ),
          ),
        ],
      ),
    ],
  );

  /// Dallar YAN YANA, her dal bir zincir.
  ///
  /// Sütun değil satır: zincir DİKEY okunuyor (bir düğüm bir öncekini istiyor)
  /// ve iki dal arasındaki seçim YATAY. Dalları alt alta dizmek, aralarındaki
  /// "ya o ya bu" ilişkisini sıraya çevirirdi.
  Widget _dallar(Dil dil, bool dar, bool kisa) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, dal) in dallar.indexed) ...[
        if (i > 0) SizedBox(width: dar ? 8 : 12),
        Expanded(key: argeDaliKey(dal), child: _dal(dal, dil, dar, kisa)),
      ],
    ],
  );

  Widget _dal(ArGeDali dal, Dil dil, bool dar, bool kisa) {
    final dugumler = [
      for (final d in ArGe.hepsi)
        if (d.dal == dal) d,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(menuUpper(argeDaliAdi(dal, dil), dil)),
        // DAL AÇIKLAMASI KISA EKRANDA DÜŞÜYOR.
        //
        // "Güç droide kayar" ile düğümdeki `AKTARIM +0,033` aynı şeyi
        // söylüyor; biri kelimeyle, öteki sayıyla. 390 piksellik pencerede
        // ikisini birden tutmak dördüncü düğümü kaydırmanın altına itiyor,
        // ve zincirin görünmeyen ucu açıklamadan pahalı: oyuncu dalın
        // nereye çıktığını göremiyor. Başlıktaki "GÜÇ VERMEZ · GÜCÜ TAŞIR"
        // duruyor — ağacın güç ağacı SANILMAMASI o cümleye bağlı.
        if (!kisa) ...[
          const SizedBox(height: 4),
          Text(
            _dalEtkisi(dal, dil),
            maxLines: 2,
            style: MenuType.label(color: Palette.faint),
          ),
        ],
        SizedBox(height: kisa ? 5 : 8),
        for (final (i, dugum) in dugumler.indexed) ...[
          // ZİNCİR ÇİZGİSİ: iki düğüm arasındaki bağ. Yalnız boşluk bırakmak
          // dört düğümü dört bağımsız kutu gibi gösteriyordu; oysa aradaki
          // ilişki ağacın tek kuralı (05.7) — bir düğüm bir öncekini istiyor.
          if (i > 0) _zincir(dugumler[i - 1], dar || kisa),
          _dugum(dugum, dil, dar, kisa),
        ],
      ],
    );
  }

  /// Dalın ne yaptığı — σ'yı hangi yöne ittiği ya da izin açtığı.
  ///
  /// Dalın kendi düğümlerinden okunuyor, dalın ADINDAN değil: yeni bir dal
  /// eklendiğinde burası kendiliğinden doğru cümleyi yazıyor.
  String _dalEtkisi(ArGeDali dal, Dil dil) {
    final toplam = ArGe.hepsi
        .where((d) => d.dal == dal)
        .fold<double>(0, (t, d) => t + d.aktarimDeltasi);
    if (toplam > 0) return Metin.argeGucDroide(dil);
    if (toplam < 0) return Metin.argeGucGemide(dil);
    return Metin.argeSayiDegilIzin(dil);
  }

  /// İki düğüm arasındaki bağ — üstteki alınmışsa yanıyor.
  Widget _zincir(ArGeDugumu onceki, bool dar) => Center(
    child: Container(
      width: 2,
      height: dar ? 8 : 10,
      color: hangar.argeDugumleri.contains(onceki.id)
          ? Palette.accent
          : Palette.line,
    ),
  );

  Widget _dugum(ArGeDugumu dugum, Dil dil, bool dar, bool kisa) {
    final alinmis = hangar.argeDugumleri.contains(dugum.id);
    final alinabilir = hangar.argeAlinabilir(dugum.id);
    // ÖNKOŞUL ayrı soruluyor, alınabilirlikten TÜRETİLMİYOR: `ArGe.alinabilir`
    // tek bir "hayır" veriyor ve iki farklı sebebi var — zincir kopuk ya da
    // puan yetmiyor. Oyuncuya hangisi olduğunu söylemeyen bir kutu, kuralı
    // öğretmeden reddediyor. Sorulan şey düğümün KENDİ verisi (`onkosul`),
    // ikinci bir kural değil.
    final onkosulTamam =
        dugum.onkosul == null || hangar.argeDugumleri.contains(dugum.onkosul);

    final renk = alinmis
        ? Palette.accent
        : alinabilir
        ? Palette.accentBright
        : Palette.faint;
    final durum = alinmis
        ? Metin.argeAlindi(dil)
        : alinabilir
        ? Metin.argeMaliyet.bicim(dil, {'n': bicim.sayi(dugum.maliyet, dil)})
        : onkosulTamam
        ? Metin.argePuanYetmiyor(dil)
        : Metin.argeOncekiGerek(dil);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Yalnız ALINABİLİR düğüm dokunulabilir. Kilitli bir düğüme dokunmayı
      // sunucuya sormak, oyuncuya ekranın zaten yazdığı sebebi bir de hata
      // şeridinden okutmak olurdu.
      onTap: alinabilir ? () => onAl(dugum.id) : null,
      child: Container(
        key: argeDugumKey(dugum.id),
        // 48, dar ekranda bile iOS'un 44 piksellik dokunma alt sınırının
        // ÜSTÜNDE: kutu küçülüyor ama dokunulamaz olmuyor. 560×620'lik
        // pencerede kazanılan 22 piksel, dördüncü düğümün durum satırının
        // kaydırmadan görünmesine yetiyor.
        constraints: BoxConstraints(minHeight: kisa ? 44 : (dar ? 48 : 56)),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: dar ? 5 : 8),
        decoration: BoxDecoration(
          color: alinmis
              ? Palette.accent.withValues(alpha: 0.12)
              : const Color(0x07FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: alinmis
                ? Palette.accent.withValues(alpha: 0.55)
                : alinabilir
                ? Palette.accentBright.withValues(alpha: 0.4)
                : const Color(0x14FFFFFF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              argeDugumAdi(dugum, dil),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MenuType.tile(
                color: alinmis || alinabilir
                    ? Palette.inkBright
                    : Palette.muted,
              ),
            ),
            const SizedBox(height: 3),
            // TELEFON YATAYDA ETKİ VE DURUM AYNI SATIRDA.
            //
            // Üç satırlık düğüm 390 piksellik pencerede dört düğümlük iki
            // zinciri kaydırmaya sokuyordu. Kaydırma burada normalden pahalı:
            // ağacın tek kuralı zincir (05.7) ve zincirin görünmeyen ucu,
            // oyuncuya "bu dal nereye çıkıyor" sorusunu sordurmuyor bile.
            //
            // Satır birleştiriliyor, bilgi ATILMIYOR: durum sağa yaslanıyor
            // ve ikisi de kendi payında kısalıyor. Yalnız YÜKSEKLİK kısıtlı
            // ekranda (`dense`, 480 altı) yapılıyor — 560×620'lik dar
            // pencerede sütun zaten 260 piksel ve iki metin yan yana
            // sıkışırdı.
            if (kisa)
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _dugumEtkisi(dugum, dil),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MenuType.label(color: Palette.muted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      durum,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: MenuType.label(color: renk),
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                _dugumEtkisi(dugum, dil),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuType.label(color: Palette.muted),
              ),
              const SizedBox(height: 3),
              Text(
                durum,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuType.label(color: renk),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Düğümün NE YAPTIĞI: σ deltası ya da açtığı izin.
  ///
  /// İzin düğümünde sayı YOK ve olmamalı (05.7): açtığı şey bir kapı, ve o
  /// kapının adı "Ek Yuva" değil "filo tavanı +1" — oyuncunun beş puanı
  /// harcamadan önce okuması gereken düğümün adı değil sonucu.
  String _dugumEtkisi(ArGeDugumu dugum, Dil dil) {
    if (dugum.izin case final izin?) return argeIzniAciklamasi(izin, dil);
    final d = dugum.aktarimDeltasi;
    // Üç basamak: adım 0,033 ve iki basamağa yuvarlanınca üç düğüm de aynı
    // sayıyı gösterirdi. Artının işareti ELLE: `ondalikli` yalnız eksiyi
    // yazıyor ve işaretsiz bir sayı, dalın yönünü söylemeyen bir sayı.
    return Metin.argeAktarim.bicim(dil, {
      'n': '${d > 0 ? '+' : ''}${bicim.ondalikli(d, dil, basamak: 3)}',
    });
  }

  /// Ağacın iki kuralı, ekranın altında: puan nereden geliyor ve sıfırlamanın
  /// bedeli ne. İkisi de düğmeye basmadan önce okunması gereken şeyler.
  /// İki kural satırı — kısa ekranda BİRİ.
  ///
  /// Telefon yatayda ikisi birden dördüncü düğümün yerini yiyor. Düşen
  /// "puan seviyeden": onu sayaç zaten söylüyor (`HARCANAN 3 / 6`) ve
  /// oyuncunun puanı nereden aldığı ağacın önündeki karar değil. Kalan
  /// "sıfırlama bedava", çünkü onu söyleyen başka hiçbir şey yok — ve
  /// bilmeyen oyuncu ağaca hiç dokunmuyor (05.7'nin bedava sıfırlama
  /// gerekçesinin ta kendisi).
  Widget _altBilgi(Dil dil, bool kisa) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!kisa) ...[
        Text(
          Metin.argePuanSeviyeden(dil),
          maxLines: 2,
          style: MenuType.label(color: Palette.faint),
        ),
        const SizedBox(height: 3),
      ],
      Text(
        Metin.argeSifirlamaBedava(dil),
        maxLines: 2,
        style: MenuType.label(color: Palette.faint),
      ),
    ],
  );

  /// SIFIRLA ve KAPAT.
  ///
  /// **Onay penceresi YOK ve bu ölçülmüş bir karar.** `OnayPenceresi` geri
  /// ALINAMAZ işlemler için var (çevirme bir rolü siliyor, parçalama eşyayı
  /// yok ediyor); ArGe sıfırlaması geri alınabilir olanın ta kendisi — bedava
  /// ve sınırsız (05.7), harcanan puanların hepsi geri geliyor ve aynı düğümler
  /// tek tek yeniden alınabiliyor. Kaybedilen tek şey birkaç dokunuş. Bedelsiz
  /// bir işlemin önüne onay koymak, onayı refleksle geçilen bir adıma çevirir
  /// ve o refleks bir gün gerçekten yıkıcı bir pencerede işler.
  ///
  /// Yerine geçen koruma daha ucuz: ağaç BOŞKEN düğme kapalı. Yanlışlıkla
  /// basılan sıfırlama zaten hiçbir şey yapmıyor.
  Widget _dugmeler(Dil dil) => Row(
    children: [
      Expanded(
        child: MenuButton(
          key: argeSifirlaKey,
          label: Metin.argeSifirla(dil),
          filled: false,
          color: Palette.danger,
          expand: true,
          onTap: hangar.argeDugumleri.isEmpty ? null : onSifirla,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: MenuButton(
          key: argeKapatKey,
          label: Metin.kapat(dil),
          filled: false,
          expand: true,
          onTap: onClose,
        ),
      ),
    ],
  );
}

/// Puan sayacı — testin biçimden bağımsız tutunacağı yer.
const Key argePuanKey = Key('arge-puan');
