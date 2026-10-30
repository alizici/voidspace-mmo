import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../dil/sayi.dart' as bicim;
import 'esya_karti.dart';
import 'menu_cells.dart';
import 'menu_theme.dart';

/// EŞYA BİLGİ PENCERESİ — bir parçanın ne olduğunu tek bakışta söyleyen yer.
///
/// Türün standart deseni: parçaya dokun, ne olduğunu gör. Bu ekranda uzun süre
/// yoktu ve eksikliği somuttu — oyuncu bir parçayı takmadan önce **ne
/// verdiğini** hiçbir yerde okuyamıyordu. Depoda dokunmak doğrudan takıyordu,
/// yani kararı verdikten sonra öğreniyordu.
///
/// **Sayılar TEK kaynaktan.** Ana stat [ItemBudget.mainStatValue], alt statlar
/// [LoadoutResolver.altStatlariFor] — donatım çözücüsünün gemiye uyguladığı
/// aynı fonksiyonlar. İkinci bir hesap yazmak, pencerede yazan ile gemiye
/// inen arasında sessiz bir ayrışma üretirdi; ve o ayrışmayı kimse fark
/// etmezdi, çünkü ikisi de kendi içinde tutarlı kalırdı.
class ItemSheet extends StatelessWidget {
  const ItemSheet({
    required this.spec,
    required this.instance,
    required this.hull,
    required this.metrics,
    required this.malzemeStogu,
    required this.ceviriciStogu,
    required this.onClose,
    this.eylemEtiketi,
    this.onEylem,
    this.onYukselt,
    this.onCevir,
    this.cevirmeUyarisi = false,
    this.kilitler = const {},
    this.onKilit,
    this.onParcala,
    this.onOnar,
    this.novaStogu = 0,
    this.droidDonanimi = const [],
    this.droidYuvaSayisi = 0,
    this.onDroidenCikar,
    this.onDroideTak,
    super.key,
  });

  final ItemSpec spec;
  final ItemInstance instance;
  final HullClass hull;
  final MenuMetrics metrics;

  /// Bu rankın malzeme stoğu — yükseltme kapısının okunduğu sayı.
  final int malzemeStogu;

  /// Bu rankın ÇEVİRİCİ stoğu — çevirme kapısının okunduğu sayı.
  ///
  /// Ayrı bir sayı çünkü ayrı bir kaynak: yükseltme malzemesi öldürmeden de
  /// geliyor, çevirici YALNIZ parçalamadan. İkisini tek sayıda toplamak,
  /// çevirmenin nadirliğini görünmez yapardı.
  final int ceviriciStogu;

  final VoidCallback onClose;

  /// Bağlama göre değişen tek eylem: depoda TAK, yuvada ÇIKAR.
  ///
  /// Pencerenin kendi işi bilgi vermek; eylemi çağıran belirliyor çünkü ne
  /// yapılabileceği parçanın nerede durduğuna bağlı.
  final String? eylemEtiketi;
  final VoidCallback? onEylem;

  /// GELİŞTİRME eylemleri — hepsi burada, ayrıntı şeridinde değil.
  ///
  /// Şeritte de duruyorlardı ve ikizlenmişlerdi: aynı düğme iki yerde,
  /// maliyet iki yerde, malzeme kapısı iki yerde. Bir gün biri değişip öteki
  /// değişmezdi. Üstelik şeritte dört düğme grubu yan yana sığmıyordu ve
  /// taşmayı iki kez onarmak gerekti. Pencere zaten sayıları gösteriyor;
  /// eylemin de orada olması hem tekrarı hem taşmayı bitiriyor.
  final VoidCallback? onYukselt;
  final VoidCallback? onCevir;

  /// ÇEVİRME UYARISI — son çevirme değeri YÜKSELTTİYSE açık.
  ///
  /// Oyuncu iyi bir roll çektikten sonra alışkanlıkla bir kez daha basıyor ve
  /// onu kaybediyor. Çevirme geri alınamaz — yeni değer eskisinin üstüne
  /// yazılıyor — yani onay, kaybın tek savunması.
  final bool cevirmeUyarisi;

  /// Kilitli alt statlar ve kilit düğmesi — karta geçiyor (karar 07.5).
  final Set<String> kilitler;
  final void Function(String statId, bool kilitli)? onKilit;
  final VoidCallback? onParcala;

  /// DROİD ONARIMI — aşınmış dayanıklılığı NOVA ile geri alır (05.10).
  ///
  /// Yalnız aşınmış droidde dolu: tam sayaçlı bir droidde düğme yok, çünkü
  /// basacak bir şey yok.
  final VoidCallback? onOnar;

  /// Oyuncunun NOVA'sı — onarım bedelinin yanına, yeterli mi diye.
  final int novaStogu;

  /// DROİDİN İÇİNDEKİLER (05.4 s5): (örnek kimliği, görünen ad) çiftleri.
  /// Yalnız droid penceresinde dolu.
  final List<(String, String)> droidDonanimi;

  /// Bu droidin yuva sayısı; droid değilse sıfır.
  final int droidYuvaSayisi;

  /// Droidin içindeki eşyayı çıkar.
  final void Function(String instanceId)? onDroidenCikar;

  /// Bu eşyayı bir droide tak — yalnız lazer ve jeneratörde dolu (05.4 s5).
  final VoidCallback? onDroideTak;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final dil = context.dil;
    // İki sütunlu düzende pencere geniş olmalı, yoksa sütunlar 260 pikselde
    // sıkışıp kazanılan yeri geri verir.
    // Dar ekranda pencere neredeyse TAM GENİŞLİK.
    //
    // Üç sütuna bölünen bir içerikte her piksel bir sütunun üçte birine
    // gidiyor, ve sütun daraldığında yazılar kelime ORTASINDAN bölünüyor:
    // "GARANTİLİ" kelimesinin son harfi alt satıra düşüyordu. Kenarda
    // bırakılan boşluk, o boşluğun sağladığı hiçbir şeye değmiyor — pencere
    // zaten bütün ilgiyi isteyen bir perde.
    // UZUN İÇERİK pencereyi GENİŞLETİYOR.
    //
    // Alt stat sayısı ranktan çıkıyor: C ailesi bir tane, kapak taşları YEDİ
    // ([ItemBudget.altStatSayisi]). Yedi alt stat tek sütunda ~315 piksel
    // ediyor ve kimlik, maliyetler ve düğmelerle birlikte 770'i buluyor —
    // 720 piksellik bir masaüstü penceresinde bile taşıyordu, yani en üst
    // rankta TAK düğmesi ekranın dışında kalıyordu. Genişleyen pencere
    // sütunlara bölünebiliyor ve yükseklik ihtiyacı yarıya iniyor.
    final altStatlar = LoadoutResolver.altStatlariFor(instance, spec, hull);
    final cokAltStat = altStatlar.length >= 5;
    // İçerik SÜTUNLARA bölündüğünde maliyet satırları da daralıyor: adla
    // değeri yan yana zorlamak "PARÇALARSA / N" gibi kelime ortasından
    // bölünmeler üretiyor. Bölünen düzende satırlar alt alta.
    final darSutun = m.dense || cokAltStat;
    final width = (m.width - (m.dense ? 24 : m.gutter * 2)).clamp(
      280.0,
      m.dense
          ? 900.0
          : cokAltStat
          ? 780.0
          : 520.0,
    );
    final kilitliSayisi = altStatlar.keys.where(kilitler.contains).length;
    final cevirmeBedeli = Yukseltme.cevirmeBedeli(
      spec.tier,
      altStatlar.length,
      kilit: kilitliSayisi,
    );
    final tavanda = instance.level >= ItemLevels.max;
    final yukseltmeBedeli = tavanda
        ? 0
        : ItemLevels.upgradeCost(instance.level, spec.tier);
    final malzemeGereken = tavanda
        ? 0
        : Yukseltme.malzemeMaliyeti(instance.level, spec.tier);
    final droid = spec.slot == SlotType.droid;
    final eksikPuan = ItemInstance.tamDayaniklilik - instance.dayaniklilik;
    // Bedel eşyanın kendisinden: rank ve basılmış artı. Aynı fonksiyon
    // sunucuda da parayı kesiyor — ekran ikinci bir hesap yapmıyor.
    final onarimBedeli = droid && instance.asinmis
        ? Kazanc.droidOnarimNovaFor(
            spec.tier,
            level: instance.level,
            puan: eksikPuan,
          )
        : 0;

    // DÜĞMELER KAYDIRMANIN DIŞINDA.
    //
    // İçerikle aynı listedeydiler ve içerik uzadığında onlar da aşağı
    // kayıyordu: 560×620'lik bir pencerede ikinci düğme sırası ekranın
    // altında kalıyor, KAPAT'a bile ulaşılamıyordu — pencereyi kapatmanın
    // tek yolu perdeye dokunmaktı. Bir eylem penceresinin eylemleri her
    // zaman görünmeli; kaydırılacak şey BİLGİ.
    final dugmeler =
        //
        // Sıra niyete göre: geliştirmek (YÜKSELT · ÇEVİR),
        // yerini değiştirmek (TAK · ÇIKAR), sonra yok etmek
        // (PARÇALA). Yıkıcı olan en sonda ve kırmızı.
        // Her düğme KENDİ genişliğinde: `MenuButton`'ın
        // `Container`'ı `alignment` taşıyor ve sınırlı kısıt
        // aldığında genişleyebildiği kadar genişliyor. Sarmadan
        // önce beşi de tam genişlik kaplıyor ve pencere gereksiz
        // yere beş satır uzuyordu.
        // DÜĞMELER: eşit genişlik, hizalı satırlar.
        //
        // `Wrap` idi ve her düğme kendi etiketinin
        // genişliğindeydi: altı düğme dört-iki diye sarıyor,
        // sağ kenar tırtıklı çıkıyor, ve düzen eşyadan
        // eşyaya değişiyordu — "ÇEVİR" ile "DROİDE TAK" ayrı
        // genişlikte olduğu için satırlar hiç aynı yerde
        // bitmiyordu.
        //
        // SIRA da anlamlı: pencereyi AÇMA sebebi olan eylem
        // (TAK · ÇIKAR · FİLOYA AL) başta, onu değiştiren
        // eylemler ortada, YIKICI olan sonda, KAPAT en
        // sonda. Eskiden birincil eylem üçüncü sıradaydı.
        EsitIzgara(
          // Dar ekranda sütun daraldığı için düğme de
          // daralıyor; iki sütunluk ızgara korunuyor.
          enAzGenislik: m.dense ? 100 : 132,
          kutular: [
            if (onEylem case final eylem?)
              MenuButton(
                key: itemSheetActionKey,
                label: eylemEtiketi ?? Metin.uygula(dil),
                onTap: eylem,
              ),
            if (onYukselt != null || !tavanda)
              MenuButton(
                key: itemSheetUpgradeKey,
                label: tavanda ? Metin.maks(dil) : Metin.yukselt(dil),
                filled: onEylem == null,
                onTap: tavanda ? null : onYukselt,
              ),
            if (altStatlar.isNotEmpty)
              MenuButton(
                key: itemSheetRerollKey,
                label: Metin.cevir(dil),
                filled: false,
                // Uyarı varken düğme RENK değiştiriyor: onay
                // penceresi açılmadan önce de bir şeyin
                // değiştiği görünsün.
                color: cevirmeUyarisi ? Palette.danger : Palette.accent,
                onTap: onCevir,
              ),
            if (onOnar case final onar?)
              MenuButton(
                key: itemSheetOnarKey,
                label: Metin.onar(dil),
                filled: false,
                // NOVA rengi — cüzdandan düğmeye aynı
                // menekşe, hangi keseden çıktığı renkten
                // okunsun.
                color: currencyColor(Currency.premium),
                onTap: novaStogu < onarimBedeli ? null : onar,
              ),
            if (onDroideTak case final tak?)
              MenuButton(
                key: droideTakKey,
                label: Metin.droideTak(dil),
                filled: false,
                color: Palette.slotDroid,
                onTap: tak,
              ),
            if (onParcala case final parcala?)
              MenuButton(
                key: itemSheetScrapKey,
                label: Metin.parcala(dil),
                filled: false,
                color: Palette.danger,
                onTap: parcala,
              ),
            MenuButton(
              key: itemSheetCloseKey,
              label: Metin.kapat(dil),
              filled: false,
              color: Palette.inkDim,
              onTap: onClose,
            ),
          ],
        );

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: ColoredBox(
          color: Palette.perde,
          // BOŞLUK MERKEZİN DIŞINDA, İÇİNDE DEĞİL.
          //
          // Kenar payı pencerenin kendi `margin`'iydi ve bu, taşmayı
          // ÜRETEN şeydi: `Center` çocuğuna ekran yüksekliği kadar yer
          // veriyor, çocuk o kadar uzuyor, sonra üstüne kendi payını
          // ekliyordu — toplam ekranı aşıyor ve ortalama onu yukarıdan da
          // aşağıdan da dışarı taşırıyordu. Pay dışarıda olunca yer önce
          // kısılıyor, pencere kalanın içine sığıyor ve gerçekten
          // ortalanıyor.
          //
          // `SafeArea` da burada: yatay bir telefonda çentik ve alt çubuk
          // ekranın kullanılabilir alanını daraltıyor.
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: m.dense ? 5 : m.gutter,
                horizontal: 8,
              ),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  // Pencerenin yüzeyi İKONUN KUTUSU: aynı zemin, aynı parıltı,
                  // aynı köşe kolları — 110 piksellik plakanın büyüğü.
                  //
                  // Bir süre kendi gradyanı ve YUVA renginde bir kenarlığı vardı.
                  // Yuva rengi burada yanlış eksendi: pencere bir parçayı
                  // anlatıyor ve parçanın kimliği rankı. Yuva tipini zaten
                  // içerideki işaret söylüyor.
                  child: SizedBox(
                    width: width,
                    child: RankYuzeyi(
                      rank: spec.tier,
                      child: Padding(
                        padding: EdgeInsets.all(m.dense ? 11 : m.gutter),
                        child: _icerik(
                          m: m,
                          // Liste yalnız DAR ekranda dışarı alınıyor; geniş
                          // ekranda kartın kendi içinde kalıyor.
                          cokAltStat: cokAltStat,
                          altStatlar: m.dense
                              ? EsyaKarti(
                                  spec: spec,
                                  instance: instance,
                                  hull: hull,
                                  metrics: m,
                                  yuzey: false,
                                  kilitler: kilitler,
                                  onKilit: onKilit,
                                ).altStatListesi(context)
                              : const [],
                          kimlik: EsyaKarti(
                            spec: spec,
                            instance: instance,
                            hull: hull,
                            metrics: m,
                            // Yüzeyi pencere çiziyor — kart çizse kutu içinde
                            // kutu olurdu.
                            yuzey: false,
                            kilitler: kilitler,
                            onKilit: onKilit,
                            // Dar ekranda liste KENDİ sütununa gidiyor.
                            altStatlariAyir: m.dense && altStatlar.isNotEmpty,
                          ),
                          dugmeler: dugmeler,
                          kalanlar: [
                            SizedBox(height: m.gap),
                            _ayirac(),
                            SizedBox(height: m.gap),
                            _bolumBasligi(Metin.gelistirme(dil)),
                            const SizedBox(height: 6),
                            if (tavanda)
                              _bilgiSatiri(
                                Metin.seviye(dil),
                                Metin.tavanArti.bicim(dil, {
                                  'n': ItemLevels.max,
                                }),
                                alt: darSutun,
                              )
                            else ...[
                              _bilgiSatiri(
                                Metin.sonrakiSeviye(dil),
                                '${menuNumber(yukseltmeBedeli, dil)} '
                                '${paraAdi(Currency.credit, dil)}',
                                alt: darSutun,
                              ),
                              _bilgiSatiri(
                                Metin.malzeme(dil),
                                '$malzemeStogu / $malzemeGereken '
                                '${rankEtiketi(spec.tier, dil)}',
                                uyari: malzemeStogu < malzemeGereken,
                                alt: darSutun,
                              ),
                              // Adım seviyesi: bir alt stat güçlenecek; hangisi
                              // sürpriz, miktar sabit (karar 07.6).
                              if (altStatlar.isNotEmpty &&
                                  ItemLevels.isSubStatStep(instance.level + 1))
                                _bilgiSatiri(
                                  '+${instance.level + 1}',
                                  Metin.altStatArtisi.bicim(dil, {
                                    'n':
                                        (ItemBudget.guclenmeOrani(spec.tier) *
                                                100)
                                            .round(),
                                  }),
                                  alt: darSutun,
                                ),
                            ],
                            if (altStatlar.isNotEmpty)
                              // Bedel kilit sayısıyla artıyor: satır her kilit
                              // dokunuşunda değişiyor, oyuncu bedeli çevirmeden
                              // önce görüyor.
                              _bilgiSatiri(
                                kilitliSayisi > 0
                                    ? Metin.ceviriciKilitli.bicim(dil, {
                                        'n': kilitliSayisi,
                                      })
                                    : Metin.cevirici(dil),
                                '$ceviriciStogu / $cevirmeBedeli '
                                '${rankEtiketi(spec.tier, dil)}',
                                uyari: ceviriciStogu < cevirmeBedeli,
                                alt: darSutun,
                              ),
                            // DAYANIKLILIK yalnız droidde: gövde eşyası
                            // aşınmıyor ve her eşyada boş bir satır göstermek
                            // sayacı anlamsızlaştırırdı (05.10).
                            if (droid) ...[
                              _bilgiSatiri(
                                Metin.dayaniklilik(dil),
                                '${bicim.yuzde(instance.dayaniklilik, dil)} · '
                                '${Metin.olumSayisi.bicim(dil, {'n': instance.dayaniklilik ~/ TasarimGirdileri.droidAsinmaPayi})}',
                                uyari:
                                    instance.dayaniklilik <=
                                    TasarimGirdileri.droidAsinmaPayi * 3,
                                alt: darSutun,
                              ),
                              if (instance.asinmis)
                                _bilgiSatiri(
                                  Metin.onarimBasligi(dil),
                                  '${menuNumber(onarimBedeli, dil)} '
                                  '${paraAdi(Currency.premium, dil)}',
                                  uyari: novaStogu < onarimBedeli,
                                  alt: darSutun,
                                ),
                            ],
                            // DROİD YUVASI (05.4 s5): droid bir taşıyıcı ve
                            // içindekiler burada. Boş yuva da yazılıyor —
                            // görünmeyen bir yuva doldurulmaz.
                            if (droidYuvaSayisi > 0) ...[
                              SizedBox(height: m.gap),
                              _bolumBasligi(
                                Metin.droidYuvasi.bicim(dil, {
                                  'dolu': droidDonanimi.length,
                                  'tavan': droidYuvaSayisi,
                                }),
                              ),
                              const SizedBox(height: 6),
                              for (final (id, ad) in droidDonanimi)
                                Padding(
                                  // Tekrar eden kardeş satırların arası
                                  // ızgara hücrelerininkiyle aynı birim:
                                  // iki ayrı "yakın aralık" sayısı tutmak,
                                  // aynı ekranda iki ritim üretiyordu.
                                  padding: const EdgeInsets.only(
                                    bottom: Cells.gap,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ad,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: MenuType.body(),
                                        ),
                                      ),
                                      MenuButton(
                                        key: droidCikarKey(id),
                                        label: Metin.cikar(dil),
                                        filled: false,
                                        onTap: () => onDroidenCikar?.call(id),
                                      ),
                                    ],
                                  ),
                                ),
                              for (
                                var i = droidDonanimi.length;
                                i < droidYuvaSayisi;
                                i++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: Cells.gap,
                                  ),
                                  child: Text(
                                    Metin.bosYuvaLazerJenerator(dil),
                                    style: MenuType.label(color: Palette.faint),
                                  ),
                                ),
                            ],
                            _bilgiSatiri(
                              Metin.parcalarsan(dil),
                              Metin.parcalamaKazanci.bicim(dil, {
                                'n': GanimetCekilisi.parcalamaKazanci(
                                  spec.tier,
                                ),
                                'rank': rankEtiketi(spec.tier, dil),
                              }),
                              alt: darSutun,
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
        ),
      ),
    );
  }

  /// Pencerenin İÇERİĞİ — dar ekranda İKİ SÜTUN.
  ///
  /// **Neden iki sütun.** Alt şerit kalkınca bu pencere hangarın ana
  /// etkileşim yüzeyi oldu: tak, çıkar, yükselt, çevir, parçala — hepsi
  /// burada. Ama tek sütunluk içerik yatay bir telefona (844×390) sığmıyordu
  /// ve taşan şey en alttaki DÜĞMELERDİ. Ölçüldü: KAPAT düğmesi ekranın
  /// dışında kalıyordu, yani pencereyi kapatmanın tek yolu perdeye dokunmaktı
  /// ve TAK'a ulaşmak için kaydırmak gerekiyordu. Bir eylem penceresinin
  /// eylemleri görünmüyorsa o pencere çalışmıyor demektir.
  ///
  /// Kıt olan eksen yükseklik, bol olan genişlik — banner'da olduğu gibi.
  /// Kimlik solda, işlem sağda: iki sütun da kendi içinde kayıyor, ama
  /// pratikte kaymaları gerekmiyor.
  Widget _icerik({
    required MenuMetrics m,
    required Widget kimlik,
    required List<Widget> kalanlar,
    required List<Widget> altStatlar,
    required Widget dugmeler,
    required bool cokAltStat,
  }) {
    /// Bilgi KAYAR, düğmeler SABİT.
    Widget islemSutunu({int pay = 1}) => Expanded(
      flex: pay,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: kalanlar,
              ),
            ),
          ),
          SizedBox(height: m.gap),
          dugmeler,
        ],
      ),
    );
    Widget sutun(List<Widget> cocuklar, {int pay = 1}) => Expanded(
      flex: pay,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cocuklar,
        ),
      ),
    );

    if (!m.dense) {
      // GENİŞ EKRAN, KISA İÇERİK: tek sütun. Bölmek, yarısı boş iki sütun
      // üretirdi.
      if (!cokAltStat) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [kimlik, ...kalanlar],
                ),
              ),
            ),
            SizedBox(height: m.gap),
            dugmeler,
          ],
        );
      }
      // GENİŞ EKRAN, UZUN İÇERİK: kart solda (alt statlarıyla birlikte),
      // maliyetler ve düğmeler sağda. Üçe bölmeye gerek yok — yükseklik
      // burada kıt değil, yalnız yetmiyor.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sutun([kimlik], pay: 3),
          SizedBox(width: m.gap),
          islemSutunu(pay: 2),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sutun([kimlik], pay: 5),
        // ALT STATLAR KENDİ SÜTUNUNDA — yalnız varlarsa.
        //
        // Yedi alt statlık bir kapak taşında liste ~315 piksel ediyor ve
        // yatay telefonda pencereye kalan yükseklik ~300: kimlikle aynı
        // sütunda dururken son üç stat ekranın dışında kalıyordu. Alt statı
        // olmayan bir eşyada üçüncü sütun HİÇ açılmıyor, yoksa iki sütunluk
        // içerik üçe bölünüp boş bir şerit doğardı.
        if (altStatlar.isNotEmpty) ...[
          SizedBox(width: m.gap),
          // Alt stat sütunu EN GENİŞİ: satırında kilit kutusu, statın adı ve
          // değeri yan yana duruyor ve ad kısaltılamıyor — "Kritik hasarı"
          // kesildiğinde okunacak bir şey kalmıyor.
          sutun(altStatlar, pay: 6),
        ],
        SizedBox(width: m.gap),
        islemSutunu(pay: 5),
      ],
    );
  }

  Widget _bolumBasligi(String metin) =>
      Text(metin, style: MenuType.label(color: Palette.faint));

  Widget _ayirac() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.07));

  /// Bir maliyet/bilgi satırı — dar sütunda ALT ALTA.
  ///
  /// Ad solda, değer sağda duruyordu ve dar bir sütunda ad ezilip harf harf
  /// sarıyordu: "PARÇALARSAN" üç satıra bölünüyor, "PARÇA / LARSA / N" diye
  /// okunuyordu. Sığmayan bir satırı yan yana zorlamak yerine alt alta almak
  /// aynı yeri kullanıyor ve iki parçayı da bütün bırakıyor.
  Widget _bilgiSatiri(
    String ad,
    String deger, {
    bool uyari = false,
    bool alt = false,
  }) {
    final adYazi = Text(ad, style: MenuType.label(color: Palette.faint));
    final degerYazi = Text(
      deger,
      style: MenuType.label(color: uyari ? Palette.danger : Palette.ink),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: alt
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [adYazi, degerYazi],
            )
          : Row(
              children: [
                Expanded(child: adYazi),
                const SizedBox(width: 10),
                degerYazi,
              ],
            ),
    );
  }
}

/// Bilgi penceresinin düğmeleri.
const Key itemSheetActionKey = Key('item-sheet-action');
const Key itemSheetCloseKey = Key('item-sheet-close');
const Key itemSheetUpgradeKey = Key('item-sheet-upgrade');
const Key itemSheetRerollKey = Key('item-sheet-reroll');
const Key itemSheetScrapKey = Key('item-sheet-scrap');
const Key itemSheetOnarKey = Key('item-sheet-onar');
const Key droideTakKey = Key('item-sheet-droide-tak');
Key droidCikarKey(String id) => Key('item-sheet-droid-cikar-$id');
