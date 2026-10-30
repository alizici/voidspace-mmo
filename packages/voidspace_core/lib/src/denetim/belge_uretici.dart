import 'dart:math' as math;

import '../combat/combat_glossary.dart';
import '../design/prd.dart';
import '../design/tasarim_alanlari.dart';
import '../design/tasarim_girdileri.dart';
import '../design/turetilenler.dart';
import '../domain/alien_stats.dart';
import '../domain/ship_stats.dart';
import '../domain/world.dart';
import '../progression/budget.dart';
import '../progression/catalogue.dart';
import '../progression/fatigue.dart';
import '../progression/ganimet.dart';
import '../progression/ganimet_cekilisi.dart';
import '../progression/hull.dart';
import '../progression/item.dart';
import '../progression/kaynak_akisi.dart';
import '../progression/kazanc.dart';
import '../progression/mermi.dart';
import '../progression/referans_build.dart';
import '../progression/referans_cozumu.dart';
import '../progression/roket.dart';
import '../progression/stat.dart';
import '../progression/yukseltme.dart';
import '../world/bolge.dart';
import '../world/dusman.dart';
import '../world/yaratik_kadrosu.dart';
import 'denge_denetimi.dart';
import 'pay_olcumu.dart';

/// BELGE ÜRETİCİ — sayı tablolarını koddan basar.
///
/// Belge mimarisinin ikinci yarısı. Kural belgeleri (`docs/NN-ad.md`) elle
/// yazılır ve KAYNAKTIR; sayı tabloları (`docs/NN-ad-tablosu.md`) buradan
/// üretilir. Projenin kuralı "tepe tabloda olmayan hiçbir sayı elle
/// yazılamaz" — bir tabloyu HTML'e elle kopyalamak o kuralın belgedeki
/// ihlaliydi ve gövde oranındaki hata oradan çıktı.
///
/// `test/belge_test.dart` dosyadaki tabloyu buradan yeniden üretir; ayrışmışsa
/// dosyayı yeniden yazar ve DÜŞER. Düşmesi bilerek: eskiyen belge sessizce
/// düzelmemeli, commit'te görünmeli.
///
/// Denetim katmanında duruyor, tasarım katmanında değil: tepe tablo alt
/// katmanı okuyamaz, üretici ise kataloğu ve merdiveni okumak zorunda.
abstract final class BelgeUretici {
  /// Üretilen her dosyanın ilk satırı. Denetim bu damgayı arıyor; elle
  /// yazılmış bir tablo bu damgayı taşıyamaz.
  static const String damga =
      '<!-- ÜRETİLDİ · BelgeUretici · elle düzenlenmez, test yeniden basar -->';

  /// Üretilen dosyalar: yol → üretici. Denetim bu haritayı geziyor.
  static final Map<String, String Function()> dosyalar = {
    'docs/06-esya-tablosu.md': esyaTablosu,
    'docs/07-guclendirme-tablosu.md': guclendirmeTablosu,
    'docs/04-govde-tablosu.md': govdeTablosu,
    'docs/02-stat-kaydi.md': statKaydiTablosu,
    'docs/03-deger-tablosu.md': degerTablosu,
    'docs/08-pay-tablosu.md': payTablosu,
    'docs/09-br-tablosu.md': brTablosu,
    'docs/01-savas-sayilari.md': savasSayilariTablosu,
    'docs/10-merdiven-olcegi.md': merdivenOlcegiTablosu,
    'docs/11-bolge-tablosu.md': bolgeTablosu,
    'docs/12-dusman-tablosu.md': dusmanTablosu,
    'docs/13-akis-tablosu.md': akisTablosu,
    'docs/14-ganimet-tablosu.md': ganimetTablosu,
    'docs/15-kazanc-tablosu.md': kazancTablosu,
    'docs/16-tepe-tablo.md': tepeTablo,
    'docs/17-mermi-tablosu.md': mermiTablosu,
    'docs/18-roket-tablosu.md': roketTablosu,
  };

  /// Türkçe sayı: binlik nokta, ondalık virgül. `1047.9` → `1.047,9`.
  static String sayi(num v, {int ondalik = 1}) {
    final negatif = v < 0;
    final mutlak = v.abs();
    if (ondalik == 0) {
      return '${negatif ? '-' : ''}${_binlik(mutlak.round())}';
    }
    final sabit = mutlak.toStringAsFixed(ondalik); // "1047.9"
    final nokta = sabit.indexOf('.');
    final tam = int.parse(sabit.substring(0, nokta));
    final kesir = sabit.substring(nokta + 1);
    return '${negatif ? '-' : ''}${_binlik(tam)},$kesir';
  }

  /// Girdi değeri: tam sayı ise binlikli, değilse gereksiz sıfırsız.
  static String girdiDegeri(num v) {
    if (v is int || v == v.roundToDouble()) return sayi(v, ondalik: 0);
    var metin = v.toStringAsFixed(4);
    while (metin.endsWith('0')) {
      metin = metin.substring(0, metin.length - 1);
    }
    return metin.replaceAll('.', ',');
  }

  static String _binlik(int n) {
    final ham = n.toString();
    final sb = StringBuffer();
    for (var i = 0; i < ham.length; i++) {
      if (i > 0 && (ham.length - i) % 3 == 0) sb.write('.');
      sb.write(ham[i]);
    }
    return sb.toString();
  }

  static String _yuva(SlotType tip) => switch (tip) {
    SlotType.laser => 'Lazer',
    SlotType.generator => 'Jeneratör',
    SlotType.launcher => 'Roketatar',
    SlotType.cpu => 'CPU',
    SlotType.droid => 'Droid',
  };

  static void _onBilgi(StringBuffer sb, int alan, String ad, String kural) {
    sb
      ..writeln('---')
      ..writeln('alan: $alan')
      ..writeln('ad: $ad')
      ..writeln('tur: tablo')
      ..writeln('kural: $kural')
      ..writeln('---')
      ..writeln(damga)
      ..writeln();
  }

  static void _girdiler(StringBuffer sb, int alan) {
    sb
      ..writeln('## Tepe tabloya katkı')
      ..writeln()
      ..writeln('| Girdi | Değer | Gerekçe |')
      ..writeln('|---|---:|---|');
    for (final g in TasarimGirdileri.hepsi.where((g) => g.alan == alan)) {
      sb.writeln('| `${g.ad}` | ${girdiDegeri(g.deger)} | ${g.gerekce} |');
    }
    sb.writeln();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 06 · Eşya Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Rank merdiveni, gerçekleşen derinlik, havuzlar, tepe tabloya katkı.
  static String esyaTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 6, 'Eşya Tablosu', '06-esya-kurgusu.md');
    sb
      ..writeln('# 06 · Eşya Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [06 · Eşya Kurgusu](06-esya-kurgusu.md). '
        'Bu dosya koddan üretilir; burada görünen her sayı bugün oyunun '
        'yaptığı şeydir, tasarlanan değil. Tasarlananla farkı kural '
        'belgesindeki kararların durumu söyler.',
      )
      ..writeln();

    // ── Rank merdiveni ────────────────────────────────────────────────
    sb
      ..writeln('## Rank merdiveni')
      ..writeln()
      ..writeln(
        'Çarpan `rankArtisi = ${girdiDegeri(TasarimGirdileri.rankArtisi)}` '
        'üssü. Kapasite `ItemBudget.altStatSayisi`: aile + 1, '
        '${ItemBudget.altStatTavani} ile kesik; kapak taşları tavanda. Kalite '
        'bandı üç kademe: `kaliteAltSiniri = ${girdiDegeri(TasarimGirdileri.kaliteAltSiniri)}` · '
        '`kaliteAltSiniriSS = ${girdiDegeri(TasarimGirdileri.kaliteAltSiniriSS)}` · '
        '`kaliteAltSiniriRenk = ${girdiDegeri(TasarimGirdileri.kaliteAltSiniriRenk)}`; '
        'garantili alt stat bandın tepesinden gelir.',
      )
      ..writeln()
      ..writeln(
        '| Rank | Çarpan | Aile | Alt stat kapasitesi | Kalite bandı | Garantili |',
      )
      ..writeln('|---|---:|---:|---:|---|---:|');
    for (final t in ItemTier.values) {
      final bant =
          '%${sayi(ItemBudget.kaliteAltSiniriFor(t) * 100, ondalik: 0)}–100';
      sb.writeln(
        '| ${t.label} | ${sayi(t.multiplier)} | ${t.aile} '
        '| ${ItemBudget.altStatSayisi(t)} | $bant | ${ItemBudget.garantiliFor(t)} |',
      );
    }
    sb.writeln();

    // ── Gerçekleşen derinlik ──────────────────────────────────────────
    sb
      ..writeln('## Gerçekleşen derinlik')
      ..writeln()
      ..writeln(
        'Bir eşyanın gerçekten taşıdığı alt stat sayısı '
        '`min(kapasite, havuz.length)`. Hücre biçimi `havuz→gerçek`; aynı '
        'yuvada birden çok tasarım varsa nokta ile ayrılır.',
      )
      ..writeln()
      ..writeln(
        '| Rank | Kapasite | ${SlotType.values.where((t) => t != SlotType.droid).map(_yuva).join(' | ')} |',
      )
      ..writeln(
        '|---|---:|${SlotType.values.where((t) => t != SlotType.droid).map((_) => '---').join('|')}|',
      );
    for (final t in ItemTier.values) {
      final kap = ItemBudget.altStatSayisi(t);
      final hucreler = SlotType.values.where((t) => t != SlotType.droid).map((
        tip,
      ) {
        final specs = Catalogue.items.where(
          (s) => s.tier == t && s.slot == tip,
        );
        if (specs.isEmpty) return '—';
        return specs
            .map(
              (s) =>
                  '${s.subStatPool.length}→'
                  '${math.min(kap, s.subStatPool.length)}',
            )
            .join(' · ');
      });
      sb.writeln('| ${t.label} | $kap | ${hucreler.join(' | ')} |');
    }
    int gercek(ItemSpec s) =>
        math.min(ItemBudget.altStatSayisi(s.tier), s.subStatPool.length);
    final enDerin = Catalogue.items.map(gercek).reduce(math.max);
    final enGenis = Catalogue.items
        .map((s) => s.subStatPool.length)
        .reduce(math.max);
    final tavana = Catalogue.items
        .where((s) => gercek(s) == ItemBudget.altStatTavani)
        .length;
    sb
      ..writeln()
      ..writeln(
        'En geniş havuz $enGenis stat, en çok gerçekleşen alt stat $enDerin. '
        'Kapasite tavanına (${ItemBudget.altStatTavani}) ulaşan tasarım '
        'sayısı: $tavana.',
      )
      ..writeln();

    // ── Havuzlar ──────────────────────────────────────────────────────
    sb
      ..writeln('## Alt stat havuzları')
      ..writeln()
      ..writeln(
        'Raftaki tasarımlar elle yazılmış; üst ranklar yuvanın raftaki en '
        'iyi tasarımının havuzunu aynen kopyalar (`Catalogue._turet`).',
      )
      ..writeln()
      ..writeln('| Tasarım | Yuva | Rank | Ana stat | Havuz |')
      ..writeln('|---|---|---|---|---|');
    for (final s in Catalogue.rafta) {
      sb.writeln(
        '| `${s.id}` ${s.name} | ${_yuva(s.slot)} | ${s.tier.label} '
        '| `${s.mainStat}` | ${s.subStatPool.map((p) => '`$p`').join(' · ')} |',
      );
    }
    sb
      ..writeln()
      ..writeln('Türetilen rankların şablonu, yuva başına:')
      ..writeln();
    for (final tip in SlotType.values) {
      final ust = Catalogue.items.where(
        (s) => s.slot == tip && !Catalogue.rafta.contains(s),
      );
      if (ust.isEmpty) continue;
      final ornek = ust.first;
      sb.writeln(
        '- ${_yuva(tip)}: ${ornek.subStatPool.map((p) => '`$p`').join(' · ')} '
        '(${ust.length} rank)',
      );
    }
    sb.writeln();
    _girdiler(sb, 6);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 07 · Güçlendirme Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Artı merdiveni, maliyet eğrisi, rank başına +15, sentez, çevirme.
  static String guclendirmeTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 7, 'Güçlendirme Tablosu', '07-guclendirme.md');
    sb
      ..writeln('# 07 · Güçlendirme Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [07 · Güçlendirme](07-guclendirme.md). Koddan '
        'üretilir; bugün oyunun yaptığı şey.',
      )
      ..writeln();

    // ── Artı merdiveni (C-I) ──────────────────────────────────────────
    const taban = ItemTier.cI;
    sb
      ..writeln('## Artı merdiveni · ${taban.label}')
      ..writeln()
      ..writeln(
        'Kazanç biçimi `${TasarimGirdileri.artiKazancBicimi.name}`; maliyet '
        '`maliyetHacmi = ${girdiDegeri(TasarimGirdileri.maliyetHacmi)}` × rank '
        'çarpanı × `maliyetSekli = ${girdiDegeri(TasarimGirdileri.maliyetSekli)}`'
        ' ^ seviye. Kredi/kat = maliyet ÷ kazanç adımı; değer eğrisi bu '
        'sütundan okunur.',
      )
      ..writeln()
      ..writeln(
        '| Seviye | Kazanç adımı | Çarpan | Maliyet | Kümülatif | Kredi/kat |',
      )
      ..writeln('|---:|---:|---:|---:|---:|---:|');
    for (var l = 1; l <= ItemLevels.max; l++) {
      sb.writeln(
        '| +$l | +%${sayi(ItemLevels.stepFor(l) * 100, ondalik: 0)} '
        '| ${sayi(ItemLevels.multiplier(l), ondalik: 2)} '
        '| ${sayi(ItemLevels.upgradeCost(l - 1, taban), ondalik: 0)} '
        '| ${sayi(ItemLevels.totalCost(l, taban), ondalik: 0)} '
        '| ${sayi(ItemLevels.kredilikKat(l - 1, taban), ondalik: 0)} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Değer bozulması (son ÷ ilk kredi/kat): '
        '**${sayi(ItemLevels.degerBozulmasi)} kat**. '
        '+${ItemLevels.max} çarpanı ${sayi(ItemLevels.multiplier(ItemLevels.max), ondalik: 2)}×.',
      )
      ..writeln();

    // ── Alt stat güçlenmesi (07.6) ─────────────────────────────────────
    final adimSeviyeleri = [
      for (var l = 1; l <= ItemLevels.max; l++)
        if (ItemLevels.isSubStatStep(l)) '+$l',
    ];
    sb
      ..writeln('## Alt stat güçlenmesi')
      ..writeln()
      ..writeln(
        'Seviye ${adimSeviyeleri.join(' · ')}: bir alt stat güçlenir. Hangisi '
        'örneğin kimliğinden, saklanmıyor; miktar sabit: her adım alt stat '
        'bütçesinin ${ItemLevels.adimSayisi} adımda tam bir payını '
        'tamamlayacak kadar, tek stata. Havuz genişledikçe tek statın '
        'sıçraması büyür, toplam değişmez.',
      )
      ..writeln()
      ..writeln('| Alt stat sayısı | Ranklar | Adım başına tek stata |')
      ..writeln('|---:|---|---:|');
    final gruplar = <int, List<String>>{};
    for (final t in ItemTier.values) {
      gruplar.putIfAbsent(ItemBudget.altStatSayisi(t), () => []).add(t.label);
    }
    for (final e in gruplar.entries) {
      final ranklar = e.value.length > 1
          ? '${e.value.first} … ${e.value.last}'
          : e.value.first;
      sb.writeln(
        '| ${e.key} | $ranklar '
        '| +%${sayi(ItemBudget.guclenmeOrani(ItemTier.values.firstWhere((t) => ItemBudget.altStatSayisi(t) == e.key)) * 100, ondalik: 0)} |',
      );
    }
    sb.writeln();

    // ── Rank başına +15 ───────────────────────────────────────────────
    sb
      ..writeln('## Rank başına +${ItemLevels.max}')
      ..writeln()
      ..writeln(
        'Kredi rank çarpanıyla ölçekleniyor; malzeme kredinin malzeme '
        'değerine bölümü, yukarı yuvarlı (`Yukseltme.malzemeMaliyeti`).',
      )
      ..writeln()
      ..writeln('| Rank | Toplam kredi | Toplam malzeme |')
      ..writeln('|---|---:|---:|');
    for (final t in ItemTier.values) {
      var malzeme = 0;
      for (var l = 0; l < ItemLevels.max; l++) {
        malzeme += Yukseltme.malzemeMaliyeti(l, t);
      }
      sb.writeln(
        '| ${t.label} | ${sayi(ItemLevels.totalCost(ItemLevels.max, t), ondalik: 0)} '
        '| ${sayi(malzeme, ondalik: 0)} |',
      );
    }
    sb.writeln();

    // ── Sentez ────────────────────────────────────────────────────────
    sb
      ..writeln('## Sentez')
      ..writeln()
      ..writeln(
        '`sentezOrani = ${Yukseltme.sentezOrani}`; verim rank çarpanı ÷ oran = '
        '**%${sayi(Yukseltme.sentezVerimi * 100)}**. Ufuk '
        '${Yukseltme.sentezUfku} kademe (${Yukseltme.ufukSiniri} eşyanın '
        'altında kalan son kademe).',
      )
      ..writeln()
      ..writeln('| Kademe yukarı | Gereken eşya |')
      ..writeln('|---:|---:|');
    for (var k = 1; k <= Yukseltme.sentezUfku + 1; k++) {
      sb.writeln('| $k | ${sayi(Yukseltme.sentezMaliyeti(k), ondalik: 0)} |');
    }
    sb
      ..writeln()
      ..writeln('Oran seçenekleri, verim = rank çarpanı ÷ oran:')
      ..writeln()
      ..writeln('| Oran | Verim |')
      ..writeln('|---:|---:|');
    for (var n = 2; n <= 5; n++) {
      final secili = n == Yukseltme.sentezOrani ? ' ◀ seçili' : '';
      sb.writeln(
        '| $n → 1 | %${sayi(TasarimGirdileri.rankArtisi / n * 100)}$secili |',
      );
    }
    sb.writeln();

    // ── Çevirme ───────────────────────────────────────────────────────
    sb
      ..writeln('## Çevirme')
      ..writeln()
      ..writeln(
        'Kredi almaz. Bir çevirme kilitli olmayan bütün alt statları çevirir; '
        'bedel = stat başına (aile + 1) × stat sayısı × (1 + kilit). Mükemmel '
        'roll `cevirmeKaliteHedefi = ${girdiDegeri(TasarimGirdileri.cevirmeKaliteHedefi)}` '
        'dilimi, stat başına beklenen ${Yukseltme.yuvaBasinaCevirme} deneme; '
        'yuva başına beklenen çevirici açgözlü kilitle.',
      )
      ..writeln()
      ..writeln(
        '| Rank | Stat başına | Alt stat | Bedel · 0 kilit | 3 kilit | n−1 kilit | Yuva başına beklenen çevirici | Nesilde yuva | Nesilde gereken |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final t in ItemTier.values) {
      final rank = Yukseltme.rankOf(t);
      final n = ItemBudget.altStatSayisi(t);
      final yuva = HullClass.yuvaSayisi(ReferansBuild.kademeOf(rank));
      String bedel(int kilit) => kilit >= n
          ? '—'
          : sayi(Yukseltme.cevirmeBedeli(t, n, kilit: kilit), ondalik: 0);
      sb.writeln(
        '| ${t.label} | ${Yukseltme.statBasinaCevirici(t)} | $n '
        '| ${bedel(0)} | ${bedel(3)} | ${bedel(n - 1)} '
        '| ${sayi(Yukseltme.yuvaBasinaCevirici(t), ondalik: 0)} | $yuva '
        '| ${sayi(Yukseltme.nesildeGerekenCevirici(rank), ondalik: 0)} |',
      );
    }
    sb.writeln();
    _girdiler(sb, 7);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 04 · Gövde Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Gövde merdiveni, yuva haritası, referans build.
  static String govdeTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 4, 'Gövde Tablosu', '04-gemi-ve-yuvalar.md');
    sb
      ..writeln('# 04 · Gövde Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [04 · Gemi ve Yuvalar](04-gemi-ve-yuvalar.md). '
        'Koddan üretilir; bugün oyunun yaptığı şey.',
      )
      ..writeln();

    final carpanlar = Turetilenler.govdeKademeCarpanlari;
    sb
      ..writeln('## Gövde merdiveni')
      ..writeln()
      ..writeln(
        'Sekiz gövde de çapa × kademe çarpanı '
        '(`Turetilenler.govdeKademeCarpanlari`, rank merdiveninin kademe '
        'normalizasyonu); ilk ${HullClass.cizilenler.length} gövdenin elle '
        'duran tek şeyi yuva toplamı ve fiyatı. Çapa: gövde canı TTK '
        'kısıtından çözülen ${sayi(ReferansCozumu.govdeCapasi, ondalik: 0)} '
        '(08.5) · `kalkanCapasi = '
        '${girdiDegeri(TasarimGirdileri.kalkanCapasi)}` · `hizCapasi = '
        '${girdiDegeri(TasarimGirdileri.hizCapasi)}`. Fiyatı olmayan gövde '
        'satın alınamaz.',
      )
      ..writeln()
      ..writeln(
        '| Kademe | Gövde | Rank | N | Gövde canı | Kalkan | Hız | Fiyat | Kaynak |',
      )
      ..writeln('|---:|---|---|---:|---:|---:|---:|---:|---|');
    for (var k = 0; k < HullClass.all.length; k++) {
      final h = HullClass.all[k];
      final elle = k < HullClass.cizilenler.length;
      sb.writeln(
        '| ${k + 1} | ${h.name} | ${h.tier.label} | ${sayi(carpanlar[k], ondalik: 2)} '
        '| ${sayi(h.baseHull, ondalik: 0)} | ${sayi(h.baseShield, ondalik: 0)} '
        '| ${sayi(h.baseSpeed, ondalik: 0)} '
        '| ${h.price == null ? '—' : sayi(h.price!, ondalik: 0)} '
        '| ${elle ? 'elle' : 'türetilen'} |',
      );
    }
    sb.writeln();

    sb
      ..writeln('## Yuva haritası')
      ..writeln()
      ..writeln(
        'İlk ${HullClass.cizilenler.length} gövde sanata kilitli; sonrası '
        'kademe başına `yuvaArtisi = ${TasarimGirdileri.yuvaArtisi}` yuva, '
        'lazer sabit (`lazerYuvaSayisi = ${TasarimGirdileri.lazerYuvaSayisi}`), kalanı '
        'jeneratör ve CPU\'ya. Droid yuvası yok (04.10).',
      )
      ..writeln()
      ..writeln('| Gövde | Lazer | Jeneratör | Roketatar | CPU | Toplam |')
      ..writeln('|---|---:|---:|---:|---:|---:|');
    for (final h in HullClass.all) {
      sb.writeln(
        '| ${h.name} | ${h.laserSlots} | ${h.generatorSlots} | ${h.launcherSlots} '
        '| ${h.cpuSlots} | ${h.totalSlots} |',
      );
    }
    sb.writeln();

    final ref = ReferansCozumu.stats;
    sb
      ..writeln('## Referans build')
      ..writeln()
      ..writeln('| Bileşen | Değer |')
      ..writeln('|---|---:|')
      ..writeln(
        '| Gövde | ${HullClass.starter.name} · ${HullClass.starter.tier.label} |',
      )
      ..writeln(
        '| Jeneratör bölünmesi | kalkan '
        '%${sayi(TasarimGirdileri.referansJeneratorKalkan * 100, ondalik: 0)} |',
      )
      ..writeln('| Referans zırh | ${sayi(ref.armor, ondalik: 0)} |')
      ..writeln('| Referans kaçınma | ${sayi(ref.evasion, ondalik: 0)} |')
      ..writeln('| Zırh azaltması | %${sayi(ref.armorReduction * 100)} |')
      ..writeln('| Sıyırma | %${sayi(ref.graze * 100)} |')
      ..writeln('| K zırh | ${sayi(Turetilenler.kZirh)} |')
      ..writeln('| K sıyırma | ${sayi(Turetilenler.kSiyirma)} |')
      ..writeln(
        '| Beklenen DPS | ${sayi(CombatGlossary.expectedDps(ref), ondalik: 0)} |',
      )
      ..writeln('| EHP | ${sayi(CombatGlossary.ehp(ref), ondalik: 0)} |')
      ..writeln('| BR tabanı | ${sayi(CombatGlossary.brTabani, ondalik: 0)} |')
      ..writeln();
    _girdiler(sb, 4);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 02 · Stat Kaydı
  // ═══════════════════════════════════════════════════════════════════

  /// Kütüphanenin bugünkü hâli: kimlik, katman, kanal, birim, havuz, fiyat.
  static String statKaydiTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 2, 'Stat Kaydı', '02-stat-kutuphanesi.md');
    String kapsam(StatDef s) => s.kapsam.map((k) => k.name).join(' · ');
    String satir(StatDef s) =>
        '| `${s.id}` | ${s.label} | ${s.layer.code} | ${_kanalAdi(s.channel)} '
        '| ${s.birim.name} | ${kapsam(s)} | ${s.es} | ${s.altStat ? '✓' : '—'} ';
    sb
      ..writeln('# 02 · Stat Kaydı')
      ..writeln()
      ..writeln(
        'Kural belgesi: [02 · Stat Kütüphanesi](02-stat-kutuphanesi.md). '
        'Koddan üretilir: kütüphanenin bugünkü hâli, sekiz alanıyla. '
        'Tasarlanan tablo kural belgesinde (02.7); test ikisini satır satır '
        'karşılaştırır.',
      )
      ..writeln()
      ..writeln('## Açık · ${Stats.all.length} kimlik')
      ..writeln()
      ..writeln(
        '| Kimlik | Etiket | Katman | Kanal | Birim | Kapsam | Eş | Alt stat '
        '| Havuzda | Fiyatlı |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|---|---|');
    for (final s in Stats.all) {
      final havuzlar = Catalogue.rafta
          .where((sp) => sp.subStatPool.contains(s.id))
          .map((sp) => sp.id)
          .toList();
      sb.writeln(
        '${satir(s)}| ${havuzlar.isEmpty ? '—' : havuzlar.join(' · ')} '
        '| ${ItemBudget.birimFiyati(s.id) > 0 ? 'evet' : 'hayır'} |',
      );
    }
    sb
      ..writeln()
      ..writeln('## Ayrılmış · ${Stats.ayrilmis.length} kimlik')
      ..writeln()
      ..writeln(
        'Kayıtta yazılı, kapalı (02.6): kimlik aramasında yok, hiçbir havuzda '
        'yok, fiyatsız. Katman ve eş ilk yerleşim; kafes yazılırken yeniden '
        'açılır.',
      )
      ..writeln()
      ..writeln(
        '| Kimlik | Etiket | Katman | Kanal | Birim | Kapsam | Eş | Alt stat |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|');
    for (final s in Stats.ayrilmis) {
      sb.writeln('${satir(s)}|');
    }
    sb
      ..writeln()
      ..writeln(
        'Kapsamlar (`StatScope`): '
        '${StatScope.values.map((s) => '`${s.name}`').join(' · ')}. '
        'Anahtar `kimlik@kapsam`; kayıt dışı kapsama yazmak reddedilir.',
      )
      ..writeln();
    return sb.toString();
  }

  static String _kanalAdi(StatChannel c) => switch (c) {
    StatChannel.attack => 'saldırı',
    StatChannel.defence => 'savunma',
    StatChannel.system => 'sistem',
  };

  // ═══════════════════════════════════════════════════════════════════
  // 03 · Değer Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Marjinal değerler (zincirden sayısal türev) ve bugünkü birim fiyatları.
  static String degerTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 3, 'Değer Tablosu', '03-stat-degeri.md');
    final ref = ShipStats.bastion;
    final dps = CombatGlossary.expectedDps(ref);
    final ehp = CombatGlossary.ehp(ref);
    double dDps(ShipStats degisik, double adim) =>
        (CombatGlossary.expectedDps(degisik) - dps) / adim;
    double dEhp(ShipStats degisik, double adim) =>
        (CombatGlossary.ehp(degisik) - ehp) / adim;
    sb
      ..writeln('# 03 · Değer Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [03 · Stat Değeri](03-stat-degeri.md). Koddan '
        'üretilir. Marjinal değer referans build üzerinde sayısal türev; '
        'birim fiyatı bugün kodun bir bütçe puanına verdiği miktar.',
      )
      ..writeln()
      ..writeln('## Referans')
      ..writeln()
      ..writeln(
        '| Beklenen DPS | EHP | Ölçülen TTK | `referansTTK` |\n|---:|---:|---:|---:|\n'
        '| ${sayi(dps)} | ${sayi(ehp, ondalik: 0)} | ${sayi(ehp / dps)} sn '
        '| ${sayi(TasarimGirdileri.referansTTK)} sn |',
      )
      ..writeln()
      ..writeln('## Saldırı · ΔDPS')
      ..writeln()
      ..writeln(
        '| Stat | Birim | Marjinal değer (ΔDPS) | Birim fiyatı (puan başına) | Puan başına ΔDPS |',
      )
      ..writeln('|---|---|---:|---:|---:|');
    const kucuk = 0.001;
    final saldiri = <(String, String, double)>[
      (
        'hasar_artisi',
        'oran 1,0',
        dDps(ref.copyWith(damageBonus: ref.damageBonus + kucuk), kucuk),
      ),
      (
        'kritik_sansi',
        'oran 1,0',
        dDps(ref.copyWith(critChance: ref.critChance + kucuk), kucuk),
      ),
      (
        'kritik_hasari',
        'oran 1,0',
        dDps(ref.copyWith(critMultiplier: ref.critMultiplier + kucuk), kucuk),
      ),
      (
        'son_hasar',
        '1 puan',
        dDps(ref.copyWith(flatDamage: ref.flatDamage + 1), 1),
      ),
    ];
    for (final (id, birim, deger) in saldiri) {
      final fiyat = ItemBudget.birimFiyati(id);
      sb.writeln(
        '| `$id` | $birim | ${sayi(deger, ondalik: 2)} '
        '| ${fiyat == 0 ? '—' : girdiDegeri(fiyat)} '
        '| ${fiyat == 0 ? '—' : sayi(deger * fiyat, ondalik: 3)} |',
      );
    }
    final tabanFiyat = ItemBudget.birimFiyati('taban_hasar');
    sb
      ..writeln(
        '| `taban_hasar` | 1 puan | ${sayi(Turetilenler.saldiriPuaniDps, ondalik: 3)} '
        '| ${girdiDegeri(tabanFiyat)} | ${sayi(Turetilenler.saldiriPuaniDps * tabanFiyat, ondalik: 3)} |',
      )
      ..writeln()
      ..writeln(
        'Çapa taban hasar; bütün fiyatlar zincirin türevinden türüyor (03.1). '
        'Hasar artışı ile atış hızı aynı değerde: kanarya, bozulursa sorun '
        'zincirde.',
      )
      ..writeln()
      ..writeln('## Savunma · ΔEHP')
      ..writeln()
      ..writeln(
        '| Stat | Birim | Marjinal değer (ΔEHP) | Birim fiyatı (puan başına) | Puan başına ΔEHP |',
      )
      ..writeln('|---|---|---:|---:|---:|');
    final savunma = <(String, String, double)>[
      ('govde_cani', '1 puan', dEhp(ref.copyWith(maxHull: ref.maxHull + 1), 1)),
      ('kalkan', '1 puan', dEhp(ref.copyWith(maxShield: ref.maxShield + 1), 1)),
      ('zirh', '1 puan', dEhp(ref.copyWith(armor: ref.armor + 1), 1)),
      ('kacinma', '1 puan', dEhp(ref.copyWith(evasion: ref.evasion + 1), 1)),
    ];
    for (final (id, birim, deger) in savunma) {
      final fiyat = ItemBudget.birimFiyati(id);
      sb.writeln(
        '| `$id` | $birim | ${sayi(deger, ondalik: 3)} '
        '| ${fiyat == 0 ? '—' : sayi(fiyat, ondalik: 3)} '
        '| ${fiyat == 0 ? '—' : sayi(deger * fiyat, ondalik: 2)} |',
      );
    }
    sb
      ..writeln(
        '| `kalkan_yenilenmesi` | oran 1,0 | — '
        '| ${sayi(ItemBudget.birimFiyati('kalkan_yenilenmesi'), ondalik: 5)} | — |',
      )
      ..writeln()
      ..writeln(
        'Savunma çapası `Turetilenler.savunmaCapasi` = '
        '${sayi(Turetilenler.savunmaCapasi, ondalik: 2)} havuz/puan; kurdan '
        'türüyor (09.4). Bir saldırı puanı '
        '${sayi(Turetilenler.saldiriPuaniDps * TasarimGirdileri.referansTTK, ondalik: 2)} '
        'EHP değerinde.',
      )
      ..writeln();
    _girdiler(sb, 3);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 08 · Pay Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// İlan edilen paylar, gövde başına türetilen katsayılar, TTK sınavı.
  static String payTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 8, 'Pay Tablosu', '08-guc-butcesi.md');
    final ref = ShipStats.bastion;
    final dps = CombatGlossary.expectedDps(ref);
    final ehp = CombatGlossary.ehp(ref);
    sb
      ..writeln('# 08 · Pay Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [08 · Güç Bütçesi](08-guc-butcesi.md). Koddan '
        'üretilir; paylar tepe tabloda, katsayılar türetilen.',
      )
      ..writeln()
      ..writeln('## Paylar')
      ..writeln()
      ..writeln('| Grup | Pay |')
      ..writeln('|---|---:|')
      ..writeln('| Gövde | %${sayi(ItemBudget.hullShare, ondalik: 2)} |');
    var toplam = ItemBudget.hullShare;
    for (final e in ItemBudget.shares.entries) {
      sb.writeln('| ${_yuva(e.key)} | %${sayi(e.value, ondalik: 2)} |');
      toplam += e.value;
    }
    sb
      ..writeln('| **Toplam** | %${sayi(toplam, ondalik: 2)} |')
      ..writeln()
      ..writeln(
        'Bütçe çapası `butceCapasi = ${girdiDegeri(TasarimGirdileri.butceCapasi)}`: '
        '${HullClass.starter.name} üstünde sıfırıncı seviye C-I lazerin bütçesi '
        '${sayi(ItemBudget.budgetFor(Catalogue.pl1, 0, HullClass.starter), ondalik: 0)} puan.',
      )
      ..writeln()
      ..writeln('## Yuva katsayıları · gövde başına')
      ..writeln()
      ..writeln(
        'Katsayı = (grup payı ÷ yuva sayısı) ÷ (lazer payı ÷ lazer sayısı); '
        'lazer 1,00. Aynı pay daha çok yuvaya bölününce katsayı düşer.',
      )
      ..writeln()
      ..writeln(
        '| Gövde | ${SlotType.values.where((t) => t != SlotType.droid).map(_yuva).join(' | ')} | C-I lazer bütçesi |',
      )
      ..writeln(
        '|---|${SlotType.values.where((t) => t != SlotType.droid).map((_) => '---:').join('|')}|---:|',
      );
    for (final h in HullClass.all) {
      final k = SlotType.values
          .where((t) => t != SlotType.droid)
          .map((t) => sayi(ItemBudget.slotCoefficient(t, h), ondalik: 3));
      sb.writeln(
        '| ${h.name} | ${k.join(' | ')} '
        '| ${sayi(ItemBudget.budgetFor(Catalogue.pl1, 0, h), ondalik: 1)} |',
      );
    }
    // ── Ölçülen paylar · Shapley (08.3) ──
    final olculen = PayOlcumu.olculenPaylar();
    sb
      ..writeln()
      ..writeln('## Ölçülen paylar · Shapley')
      ..writeln()
      ..writeln(
        '08 dağıtır, 16 ölçer (08.3). Gerçekleşen güç kur biriminde '
        'toplamsal: saldırı + dayanıklılık ÷ T + sistem. Referans kit C-I '
        'rafı, +0. Fark bir doğrulama, ayar kolu değil; en büyük fark '
        '${sayi(PayOlcumu.enBuyukFark)} puan.',
      )
      ..writeln()
      ..writeln('| Grup | İlan | Ölçülen | Fark |')
      ..writeln('|---|---:|---:|---:|');
    for (final g in PayGrubu.values) {
      sb.writeln(
        '| ${g.ad} | %${sayi(g.ilanEdilen, ondalik: 2)} '
        '| %${sayi(olculen[g]!, ondalik: 2)} '
        '| ${sayi(olculen[g]! - g.ilanEdilen, ondalik: 2)} |',
      );
    }
    sb
      ..writeln()
      ..writeln('## Gövde havuzu · TTK kısıtından')
      ..writeln()
      ..writeln(
        'Gövde çapası girdi değil, çözüm: `A × T × kayıp − kalkan − eşya '
        'havuzu` (08.5). Saldırı büyüdükçe çapa kendiliğinden büyür.',
      )
      ..writeln()
      ..writeln(
        '| Referans DPS (A) | T | Kayıp çarpanı | Gereken ham havuz '
        '| Kalkan çapası | Eşya havuzu | Gövde çapası |',
      )
      ..writeln('|---:|---:|---:|---:|---:|---:|---:|')
      ..writeln(
        '| ${sayi(ReferansCozumu.referansDps)} '
        '| ${sayi(TasarimGirdileri.referansTTK)} sn '
        '| ${sayi(Turetilenler.referansKayipCarpani, ondalik: 3)} '
        '| ${sayi(ReferansCozumu.referansDps * TasarimGirdileri.referansTTK * Turetilenler.referansKayipCarpani, ondalik: 0)} '
        '| ${sayi(TasarimGirdileri.kalkanCapasi, ondalik: 0)} '
        '| ${sayi(ReferansCozumu.referansEsyaHavuzu, ondalik: 0)} '
        '| **${sayi(ReferansCozumu.govdeCapasi, ondalik: 0)}** |',
      )
      ..writeln()
      ..writeln(
        'Eşya havuzu bugün sıfır: referans build çıplak gövde + beş lazer, '
        'kalkan jeneratörlerinin katkısı referansa girmiyor. Referans tam '
        'donanımı taşıdığında (04.5) bu sütun dolar ve gövde ↔ eşya kolu '
        '(08.6) doğar.',
      )
      ..writeln()
      ..writeln('## TTK sınavı')
      ..writeln()
      ..writeln('| Referans DPS | EHP | Ölçülen TTK | İlan edilen T | Sapma |')
      ..writeln('|---:|---:|---:|---:|---:|')
      ..writeln(
        '| ${sayi(dps)} | ${sayi(ehp, ondalik: 0)} | ${sayi(ehp / dps)} sn '
        '| ${sayi(TasarimGirdileri.referansTTK)} sn '
        '| %${sayi((ehp / dps / TasarimGirdileri.referansTTK - 1) * 100)} |',
      )
      ..writeln();
    _girdiler(sb, 8);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 09 · BR Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Kur, A = D, savunma çapası, sistem kanalı, K.
  static String brTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 9, 'BR Tablosu', '09-savas-puani.md');
    final ref = ReferansCozumu.stats;
    final dps = CombatGlossary.expectedDps(ref);
    final ehp = CombatGlossary.ehp(ref);
    final d = ehp / TasarimGirdileri.referansTTK;
    sb
      ..writeln('# 09 · BR Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [09 · Savaş Puanı](09-savas-puani.md). Koddan üretilir.',
      )
      ..writeln()
      ..writeln('## Kur ve A = D')
      ..writeln()
      ..writeln('| Büyüklük | Değer |')
      ..writeln('|---|---:|')
      ..writeln('| Referans DPS (A) | ${sayi(dps)} |')
      ..writeln('| Referans EHP | ${sayi(ehp, ondalik: 0)} |')
      ..writeln('| Ölçülen TTK | ${sayi(ehp / dps)} sn |')
      ..writeln(
        '| `referansTTK` (T) | ${sayi(TasarimGirdileri.referansTTK)} sn |',
      )
      ..writeln('| D = EHP ÷ T | ${sayi(d)} |')
      ..writeln('| A ÷ D | ${sayi(dps / d, ondalik: 3)} |')
      ..writeln(
        '| Kur: 1 DPS ≡ | ${sayi(TasarimGirdileri.referansTTK, ondalik: 0)} EHP |',
      )
      ..writeln()
      ..writeln('## Savunma çapası')
      ..writeln()
      ..writeln(
        '1 saldırı puanı = ${sayi(Turetilenler.saldiriPuaniDps, ondalik: 4)} DPS = '
        '${sayi(Turetilenler.saldiriPuaniDps * TasarimGirdileri.referansTTK, ondalik: 2)} EHP; '
        '1 savunma puanı = ${sayi(Turetilenler.savunmaCapasi, ondalik: 2)} havuz '
        '(EHP çarpanı ${sayi(Turetilenler.referansEhpCarpani, ondalik: 3)}).',
      )
      ..writeln()
      ..writeln('| Stat | Puan başına |')
      ..writeln('|---|---:|');
    for (final id in const [
      'govde_cani',
      'kalkan',
      'kalkan_yenilenmesi',
      'zirh',
      'kacinma',
    ]) {
      final f = ItemBudget.birimFiyati(id);
      sb.writeln(
        '| `$id` | ${f == 0 ? '— (fiyatsız)' : sayi(f, ondalik: 5)} |',
      );
    }
    sb
      ..writeln()
      ..writeln('## Sistem kanalı')
      ..writeln()
      ..writeln(
        '`sistemKatsayisiMenzil = ${girdiDegeri(TasarimGirdileri.sistemKatsayisiMenzil)}` · '
        '`sistemKatsayisiHiz = ${girdiDegeri(TasarimGirdileri.sistemKatsayisiHiz)}` · '
        '`sistemKatsayisiItki = ${girdiDegeri(TasarimGirdileri.sistemKatsayisiItki)}` · '
        'tavan `sistemTavani = ${girdiDegeri(TasarimGirdileri.sistemTavani)}` puan → '
        'çarpan en fazla ${sayi(CombatGlossary.sistemCarpani(TasarimGirdileri.sistemTavani), ondalik: 2)}. '
        'Örnek: %20 hız + %20 menzil = '
        '${sayi(CombatGlossary.sistemPuani(menzilYuzde: 20, hizYuzde: 20))} puan → '
        '×${sayi(CombatGlossary.sistemCarpani(CombatGlossary.sistemPuani(menzilYuzde: 20, hizYuzde: 20)), ondalik: 2)}.',
      )
      ..writeln()
      ..writeln('## Ölçek')
      ..writeln()
      ..writeln(
        '`brOlcegi = ${girdiDegeri(TasarimGirdileri.brOlcegi)}`; referans BR '
        '(merdivenin tabanı) ${sayi(CombatGlossary.brTabani, ondalik: 0)}.',
      )
      ..writeln();
    _girdiler(sb, 9);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 01 · Savaş Sayıları
  // ═══════════════════════════════════════════════════════════════════

  /// Ölçülen referans, türetilen sabitler, yaratık TTK'ları.
  static String savasSayilariTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 1, 'Savaş Sayıları', '01-savas-formulu.md');
    final ref = ReferansCozumu.stats;
    final yaylim = CombatGlossary.volley(ref);
    final dps = CombatGlossary.expectedDps(ref);
    final ehp = CombatGlossary.ehp(ref);
    final ciplakEhp = ref.maxHull + ref.maxShield;
    sb
      ..writeln('# 01 · Savaş Sayıları')
      ..writeln()
      ..writeln(
        'Kural belgesi: [01 · Savaş Formülü](01-savas-formulu.md). Koddan '
        'üretilir: ölçülen referanstan okunur, türetilen formülden çıkar.',
      )
      ..writeln()
      ..writeln('## Ölçülen · referans build')
      ..writeln()
      ..writeln('| Büyüklük | Değer |')
      ..writeln('|---|---:|')
      ..writeln('| Yaylım (beklenen kritikle) | ${sayi(yaylim, ondalik: 0)} |')
      ..writeln(
        '| Atış aralığı `referansAtisAraligi` | ${sayi(TasarimGirdileri.referansAtisAraligi, ondalik: 2)} sn |',
      )
      ..writeln('| Beklenen DPS | ${sayi(dps)} |')
      ..writeln(
        '| Gövde · kalkan | ${sayi(ref.maxHull, ondalik: 0)} · ${sayi(ref.maxShield, ondalik: 0)} |',
      )
      ..writeln('| Ham havuz | ${sayi(ciplakEhp, ondalik: 0)} |')
      ..writeln(
        '| Zırh azaltması · sıyırma | %${sayi(ref.armorReduction * 100)} · %${sayi(ref.graze * 100)} |',
      )
      ..writeln('| EHP | ${sayi(ehp, ondalik: 0)} |')
      ..writeln('| Kalkanı düşürme | ${sayi(ref.maxShield / dps)} sn |')
      ..writeln('| Oyuncu ↔ oyuncu TTK | ${sayi(ehp / dps)} sn |')
      ..writeln()
      ..writeln('## Türetilen')
      ..writeln()
      ..writeln('| Sabit | Değer | Formül |')
      ..writeln('|---|---:|---|')
      ..writeln(
        '| Kritik beklenen değeri | ${sayi(Turetilenler.kritikBeklenenDeger, ondalik: 3)} '
        '| 1 + k(d − 1) |',
      )
      ..writeln(
        '| Kritik PRD sabiti C | ${sayi(Prd.constantFor(TasarimGirdileri.kritikSansiReferans), ondalik: 6)} '
        '| etkin şans = k olacak şekilde çözüm; garantili kritik '
        '${Prd.guaranteedAt(Prd.constantFor(TasarimGirdileri.kritikSansiReferans))}. yaylımda |',
      )
      ..writeln(
        '| K zırh | ${sayi(Turetilenler.kZirh)} | referans zırh × (1 ÷ hedef − 1) |',
      )
      ..writeln(
        '| K sıyırma | ${sayi(Turetilenler.kSiyirma)} | referans kaçınma × (1 ÷ hedef − 1) |',
      )
      ..writeln()
      ..writeln('## Yaratıklar')
      ..writeln()
      ..writeln('| Yaratık | Can | Zırh · kaçınma | EHP | TTK | Yaylım |')
      ..writeln('|---|---:|---:|---:|---:|---:|');
    for (final a in AlienStats.all) {
      final azaltma = SavunmaEgrileri.doyum(a.armor, Turetilenler.kZirh);
      final siyirma = SavunmaEgrileri.siyirma(a.evasion, Turetilenler.kSiyirma);
      final aEhp = a.maxHull / ((1 - azaltma) * (1 - siyirma));
      sb.writeln(
        '| ${a.name} | ${sayi(a.maxHull, ondalik: 0)} '
        '| ${sayi(a.armor, ondalik: 0)} · ${sayi(a.evasion, ondalik: 0)} '
        '| ${sayi(aEhp, ondalik: 0)} | ${sayi(CombatGlossary.ttk(aEhp, dps), ondalik: 2)} sn '
        '| ${CombatGlossary.volleysToKill(ref, aEhp)} |',
      );
    }
    sb.writeln();
    _girdiler(sb, 1);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 10 · Merdiven Ölçeği
  // ═══════════════════════════════════════════════════════════════════

  /// Yirmi rank: süre, nesil bütçesi, referans BR; unvan eşikleri; tavan.
  static String merdivenOlcegiTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 10, 'Merdiven Ölçeği', '10-ilerleme-ve-unvan.md');
    sb
      ..writeln('# 10 · Merdiven Ölçeği')
      ..writeln()
      ..writeln(
        'Kural belgesi: [10 · İlerleme ve Unvan](10-ilerleme-ve-unvan.md). '
        'Koddan üretilir. Hedef `hedefSure = ${girdiDegeri(TasarimGirdileri.hedefSure)}` '
        'saat, gelir üssü `gelirUssu = ${girdiDegeri(TasarimGirdileri.gelirUssu)}`. '
        'Referans build (10.6): kademenin gövdesi, rank, artı '
        '+${ReferansBuild.arti}; savaş puanı sütunu bugün rank çarpanını '
        'taşıyor, artıyı ve tam donanımı değil (borç defteri B1).',
      )
      ..writeln()
      ..writeln('## Rank merdiveni')
      ..writeln()
      ..writeln(
        '| # | Rank | Çarpan | Kademe | Gövde | Nesil süresi | Kümülatif | Nesil bütçesi | Referans BR |',
      )
      ..writeln('|---:|---|---:|---:|---|---:|---:|---:|---:|');
    var kumulatif = 0.0;
    for (final t in ItemTier.values) {
      final rank = t.index;
      final sure = Turetilenler.bantSuresi(rank);
      kumulatif += sure;
      final ref = ReferansBuild.of(rank);
      sb.writeln(
        '| ${rank + 1} | ${t.label} | ${sayi(t.multiplier)} '
        '| ${ref.kademe + 1} | ${ref.govde.name} '
        '| ${sayi(sure, ondalik: 0)} sa | ${sayi(kumulatif, ondalik: 0)} sa '
        '| ${sayi(KaynakAkisi.neselButcesi(rank), ondalik: 0)} '
        '| ${sayi(ref.br, ondalik: 0)} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Toplam ${sayi(kumulatif, ondalik: 0)} saat; hedef '
        '${sayi(TasarimGirdileri.hedefSure, ondalik: 0)}. Endgame dahil toplam '
        '${sayi(KaynakAkisi.toplamSure, ondalik: 0)} saat.',
      )
      ..writeln()
      ..writeln('## Unvan merdiveni')
      ..writeln()
      ..writeln(
        '`unvanSayisi = ${TasarimGirdileri.unvanSayisi}` basamak, unvan başına '
        '×${sayi(CombatGlossary.unvanAdimi, ondalik: 4)}; taban '
        '${sayi(CombatGlossary.brTabani, ondalik: 0)}, tavan '
        '${sayi(CombatGlossary.brTavani, ondalik: 0)}.',
      )
      ..writeln()
      ..writeln('| # | BR eşiği |')
      ..writeln('|---:|---:|');
    for (final i in const [1, 5, 20, 40, 60, 80, 100, 115, 120]) {
      if (i > TasarimGirdileri.unvanSayisi) continue;
      sb.writeln(
        '| $i | ${sayi(CombatGlossary.unvanEsigi(i - 1), ondalik: 0)} |',
      );
    }
    sb.writeln();
    _girdiler(sb, 10);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 11 · Bölge Tablosu
  // ═══════════════════════════════════════════════════════════════════

  static List<int> _ranklar(int kademe) => [
    for (final t in ItemTier.values)
      if (ReferansBuild.kademeOf(t.index) == kademe) t.index,
  ];

  /// Sekiz bölge, yirmi bant, boyut, PvP primi.
  static String bolgeTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 11, 'Bölge Tablosu', '11-haritalar.md');
    final prim = Turetilenler.pvpBrutPrim;
    sb
      ..writeln('# 11 · Bölge Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [11 · Haritalar](11-haritalar.md). Koddan üretilir.',
      )
      ..writeln()
      ..writeln('## Bölgeler')
      ..writeln()
      ..writeln(
        '| # | Bölge | Gövde | Ranklar | Bant | BR eşiği | Boyut | Hedef | Süre | PvE kr/sa (dış → iç) |',
      )
      ..writeln('|---:|---|---|---|---:|---:|---|---:|---:|---|');
    for (final b in Bolge.hepsi) {
      final ranklar = _ranklar(b.kademe);
      final bant = ranklar.length;
      final kenar = math.sqrt(bant);
      final sure = ranklar.fold<double>(
        0,
        (s, r) => s + Turetilenler.bantSuresi(r),
      );
      final dis = DusmanTasarimi(
        rank: ranklar.first,
        sinif: DusmanSinifi.siradan,
      ).saatlikHedef;
      final ic = DusmanTasarimi(
        rank: ranklar.last,
        sinif: DusmanSinifi.siradan,
      ).saatlikHedef;
      sb.writeln(
        '| ${b.kademe + 1} | ${b.ad} | ${HullClass.all[b.kademe].name} '
        '| ${ItemTier.values[ranklar.first].label} – ${ItemTier.values[ranklar.last].label} '
        '| $bant | ${sayi(b.girisEsigi, ondalik: 0)} '
        '| ${sayi(GameWorld.tekBantGenislik * kenar, ondalik: 0)} × ${sayi(GameWorld.tekBantYukseklik * kenar, ondalik: 0)} '
        '| ${Turetilenler.bantBasinaHedef * bant} | ${sayi(sure, ondalik: 0)} sa '
        '| ${sayi(dis, ondalik: 0)} → ${sayi(ic, ondalik: 0)} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Bant alanı = `esZamanliOyuncu = ${TasarimGirdileri.esZamanliOyuncu}` × π × '
        '`gorusYaricapi = ${girdiDegeri(TasarimGirdileri.gorusYaricapi)}`² × '
        '`gorusPaylasimi = ${girdiDegeri(TasarimGirdileri.gorusPaylasimi)}` = '
        '${sayi(Turetilenler.bantAlani / 1e6)}M birim²; tek bant '
        '${sayi(GameWorld.tekBantGenislik, ondalik: 0)} × ${sayi(GameWorld.tekBantYukseklik, ondalik: 0)}, '
        'bant başına ${Turetilenler.bantBasinaHedef} hedef.',
      )
      ..writeln()
      ..writeln(
        'PvP: kayıp oranı %${sayi(Turetilenler.pvpKayipOrani * 100)} '
        '(`pvpOlumSikligi = ${girdiDegeri(TasarimGirdileri.pvpOlumSikligi)}` × '
        '`olumMaliyetiDk = ${girdiDegeri(TasarimGirdileri.olumMaliyetiDk)}` ÷ 60), '
        'brüt prim ×${sayi(prim, ondalik: 3)} ile net '
        '`pvpNetPrim = ${girdiDegeri(TasarimGirdileri.pvpNetPrim)}`.',
      )
      ..writeln()
      ..writeln('## Bantlar')
      ..writeln()
      ..writeln(
        '| Rank | Bölge | Bant | Çarpan | PvE kr/sa | PvP kr/sa | Yorgunluk eşiği | Eşik ÷ gelir |',
      )
      ..writeln('|---|---|---:|---:|---:|---:|---:|---:|');
    for (final t in ItemTier.values) {
      final k = ReferansBuild.kademeOf(t.index);
      final ranklar = _ranklar(k);
      final gelir = DusmanTasarimi(
        rank: t.index,
        sinif: DusmanSinifi.siradan,
      ).saatlikHedef;
      final esik = Fatigue.softCapFor(t.index);
      sb.writeln(
        '| ${t.label} | ${Bolge.hepsi[k].ad} | ${ranklar.indexOf(t.index) + 1} / ${ranklar.length} '
        '| ${sayi(t.multiplier)} | ${sayi(gelir, ondalik: 0)} | ${sayi(gelir * prim, ondalik: 0)} '
        '| ${sayi(esik, ondalik: 0)} | ${sayi(esik / gelir, ondalik: 2)} |',
      );
    }
    sb.writeln();
    _girdiler(sb, 11);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 12 · Düşman Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Yirmi bant × üç sınıf, kadro.
  static String dusmanTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 12, 'Düşman Tablosu', '12-dusman-kurgusu.md');
    sb
      ..writeln('# 12 · Düşman Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [12 · Düşman Kurgusu](12-dusman-kurgusu.md). Koddan '
        'üretilir; her sütun bandın referans DPS\'inden (09) ve saatlik '
        'hedefinden (11) türüyor.',
      )
      ..writeln()
      ..writeln('## Merdiven')
      ..writeln()
      ..writeln(
        '| Bant | Bölge | Sıradan can | ödül | Güçlü can | ödül | Yaratık DPS | Boss canı | Boss ödülü | Boss aralığı |',
      )
      ..writeln('|---|---|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final t in ItemTier.values) {
      final r = t.index;
      final s = DusmanTasarimi(rank: r, sinif: DusmanSinifi.siradan);
      final g = DusmanTasarimi(rank: r, sinif: DusmanSinifi.guclu);
      final b = DusmanTasarimi(rank: r, sinif: DusmanSinifi.boss);
      sb.writeln(
        '| ${t.label} | ${Bolge.hepsi[ReferansBuild.kademeOf(r)].ad} '
        '| ${sayi(s.can, ondalik: 0)} | ${sayi(s.kredi, ondalik: 0)} '
        '| ${sayi(g.can, ondalik: 0)} | ${sayi(g.kredi, ondalik: 0)} '
        '| ${sayi(s.hasarDps, ondalik: 0)} '
        '| ${sayi(b.can, ondalik: 0)} | ${sayi(b.kredi, ondalik: 0)} '
        '| ${sayi(b.bossAraligiSaat)} sa |',
      );
    }
    final ilk = DusmanTasarimi(rank: 0, sinif: DusmanSinifi.siradan);
    sb
      ..writeln()
      ..writeln(
        'NOVA ödülü her bantta ${ilk.nova}; saatte '
        '${sayi(Kazanc.saatlikNova, ondalik: 0)} NOVA. Sınıf oranları: hız '
        '${DusmanSinifi.values.map((s) => '${s.name} ${sayi(s.hizOrani, ondalik: 2)}').join(' · ')}; '
        'menzil ${DusmanSinifi.values.map((s) => '${s.name} ${sayi(s.menzilOrani, ondalik: 2)}').join(' · ')}.',
      )
      ..writeln()
      ..writeln('## Kadro · ${YaratikKadrosu.hepsi.length} yaratık')
      ..writeln()
      ..writeln('| Bölge | Sıradan | Güçlü | Boss |')
      ..writeln('|---|---|---|---|');
    for (final b in Bolge.hepsi) {
      final k = YaratikKadrosu.bolgenin(b.kademe);
      String adlar(DusmanSinifi s) =>
          k.where((y) => y.sinif == s).map((y) => y.ad).join(' · ');
      sb.writeln(
        '| ${b.kademe + 1} · ${b.ad} | ${adlar(DusmanSinifi.siradan)} '
        '| ${adlar(DusmanSinifi.guclu)} | ${adlar(DusmanSinifi.boss)} |',
      );
    }
    sb.writeln();
    _girdiler(sb, 12);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 13 · Akış Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Gider payları, artı erişimi, endgame, NOVA kuru.
  static String akisTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 13, 'Akış Tablosu', '13-kaynak-akisi.md');
    sb
      ..writeln('# 13 · Akış Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [13 · Kaynak Akışı](13-kaynak-akisi.md). Koddan üretilir.',
      )
      ..writeln()
      ..writeln('## Gider payları')
      ..writeln()
      ..writeln('| Kalem | Pay | Bant 1 nesil | Bant 20 nesil |')
      ..writeln('|---|---:|---:|---:|');
    final ilkButce = KaynakAkisi.neselButcesi(0);
    final sonButce = KaynakAkisi.neselButcesi(ItemTier.values.length - 1);
    var toplam = 0.0;
    for (final k in GiderKalemi.values) {
      final pay = KaynakAkisi.payFor(k);
      toplam += pay;
      sb.writeln(
        '| ${k.name}${k == GiderKalemi.onarim ? ' (türetilen)' : ''} '
        '| %${sayi(pay * 100)} | ${sayi(ilkButce * pay, ondalik: 0)} '
        '| ${sayi(sonButce * pay, ondalik: 0)} |',
      );
    }
    sb
      ..writeln('| **Toplam** | %${sayi(toplam * 100)} | | |')
      ..writeln()
      ..writeln(
        'Onarım payı `genelOlumSikligi = ${girdiDegeri(TasarimGirdileri.genelOlumSikligi)}` × '
        'ölüm maliyeti ÷ 60 = %${sayi(KaynakAkisi.onarimPayi * 100)}; kalan '
        '%${sayi(KaynakAkisi.bolunenPay * 100)} dört kaleme bölünüyor.',
      )
      ..writeln()
      ..writeln('## Artı erişimi')
      ..writeln()
      ..writeln(
        '| Rank | Nesil bütçesi | Yuva | Yuva başına artı | Ulaşılan | Filo başına artı | Filo ulaşılan | +${ItemLevels.max} maliyeti | Kat |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final t in ItemTier.values) {
      final r = t.index;
      final tam = ItemLevels.totalCost(ItemLevels.max, t);
      final yuvaBasina = KaynakAkisi.yuvaBasinaArti(r);
      sb.writeln(
        '| ${t.label} | ${sayi(KaynakAkisi.neselButcesi(r), ondalik: 0)} '
        '| ${HullYuva.sayisiFor(r)} | ${sayi(yuvaBasina, ondalik: 0)} '
        '| +${KaynakAkisi.ulasilanSeviye(r, t)} '
        '| ${sayi(KaynakAkisi.droidBasinaArti(r), ondalik: 0)} '
        '| +${KaynakAkisi.droidUlasilanSeviye(r, t)} | ${sayi(tam, ondalik: 0)} '
        '| ×${sayi(tam / yuvaBasina)} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Endgame kuyruğu ${sayi(KaynakAkisi.endgameSuresi, ondalik: 0)} saat; '
        'toplam ${sayi(KaynakAkisi.toplamSure, ondalik: 0)} saat.',
      )
      ..writeln()
      ..writeln('## NOVA kuru')
      ..writeln()
      ..writeln('| Rank | Kredi/sa | NOVA/sa | 1 NOVA ≡ kredi |')
      ..writeln('|---|---:|---:|---:|');
    for (final r in [0, 9, 17, ItemTier.values.length - 1]) {
      final gelir = DusmanTasarimi(
        rank: r,
        sinif: DusmanSinifi.siradan,
      ).saatlikHedef;
      sb.writeln(
        '| ${ItemTier.values[r].label} | ${sayi(gelir, ondalik: 0)} '
        '| ${sayi(Kazanc.saatlikNova, ondalik: 0)} '
        '| ${sayi(gelir / Kazanc.saatlikNova, ondalik: 0)} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Bu tablo bir çevirme oranı değil: `paraCevirmeAcik` kapalı, çevirme yok.',
      )
      ..writeln();
    _girdiler(sb, 13);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 14 · Ganimet Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Yirmi bantta arz ve talep, PRD, sınıf başına ganimet.
  static String ganimetTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 14, 'Ganimet Tablosu', '14-ganimet.md');
    sb
      ..writeln('# 14 · Ganimet Tablosu')
      ..writeln()
      ..writeln(
        'Kural belgesi: [14 · Ganimet](14-ganimet.md). Koddan üretilir.',
      )
      ..writeln()
      ..writeln(
        'Düşme şansı %${sayi(Ganimet.dusmeSansi * 100, ondalik: 2)} '
        '(`kaliteHedefi = ${girdiDegeri(TasarimGirdileri.kaliteHedefi)}`, '
        '`dusmeGuvenligi = ${girdiDegeri(TasarimGirdileri.dusmeGuvenligi)}`); '
        'eşya aralığı ${sayi(Ganimet.dusmeAraligiDk)} dakika; bir eşya '
        '${sayi(Ganimet.esyaMaliyeti, ondalik: 0)} öldürmeye mal oluyor. '
        'Filo yuvaları ayrı kalem: droid düşme şansı '
        '%${sayi(Ganimet.droidDusmeSansi * 100, ondalik: 2)} '
        '(`droidFiloTavani = ${girdiDegeri(TasarimGirdileri.droidFiloTavani)}` '
        'yuva, aynı kural).',
      )
      ..writeln()
      ..writeln('## Arz ve talep')
      ..writeln()
      ..writeln(
        '| Rank | Nesil | Öldürme | Düşen eşya | Bolluk | Düşen droid | Malzeme arzı | Talep | Oran |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final t in ItemTier.values) {
      final r = t.index;
      sb.writeln(
        '| ${t.label} | ${sayi(Turetilenler.bantSuresi(r), ondalik: 0)} sa '
        '| ${sayi(Ganimet.oldurmeSayisiFor(r), ondalik: 0)} '
        '| ${sayi(Ganimet.esyaSayisiFor(r), ondalik: 0)} '
        '| ×${sayi(Ganimet.esyaBollugFor(r), ondalik: 2)} '
        '| ${sayi(Ganimet.droidEsyaSayisiFor(r), ondalik: 0)} '
        '| ${sayi(Ganimet.malzemeArziFor(r), ondalik: 0)} '
        '| ${sayi(Ganimet.malzemeTalebiFor(r), ondalik: 0)} '
        '| ×${sayi(Ganimet.malzemeOraniFor(r), ondalik: 2)} |',
      );
    }
    sb
      ..writeln()
      ..writeln('## Rank çekilişi ve PRD')
      ..writeln()
      ..writeln('| Sonuç | Olasılık | Yöntem |')
      ..writeln('|---|---:|---|');
    for (final g in GanimetRanki.values) {
      sb.writeln(
        '| ${g.name} | %${sayi(Ganimet.sansFor(g) * 100)} '
        '| ${g == GanimetRanki.ust ? 'PRD' : 'bağımsız'} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'PRD sabiti C = ${sayi(Ganimet.ustRankPrdSabiti, ondalik: 5)}; garanti '
        '${Ganimet.prdGarantisi}. düşmede, yaklaşık '
        '${sayi(Ganimet.prdGarantisiSaat)} saat.',
      )
      ..writeln()
      ..writeln('## Kaynak başına')
      ..writeln()
      ..writeln('| Sınıf | Eşya şansı | Malzeme |')
      ..writeln('|---|---:|---:|');
    for (final s in DusmanSinifi.values) {
      sb.writeln(
        '| ${s.name} | %${sayi(Ganimet.esyaSansiFor(s) * 100, ondalik: 2)} '
        '| ${sayi(Ganimet.malzemeFor(s), ondalik: 0)} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Boss: `bossEsyaSayisi = ${TasarimGirdileri.bossEsyaSayisi}` eşya, üst rank '
        '%${sayi(Ganimet.bossUstRankSansi * 100, ondalik: 0)}, kalite tabanı '
        '%${sayi(Ganimet.bossKaliteAltSiniri * 100, ondalik: 0)}. Parçalama verimi '
        '${sayi(Ganimet.parcalamaVerimi)} malzeme (C-I: '
        '${GanimetCekilisi.parcalamaKazanci(ItemTier.cI)}, Parlayan Pembe: '
        '${GanimetCekilisi.parcalamaKazanci(ItemTier.parlayanPembe)}) ve '
        '${GanimetCekilisi.parcalamaCeviriciKazanci} çevirici.',
      )
      ..writeln();
    _girdiler(sb, 14);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 15 · Kazanç Tablosu
  // ═══════════════════════════════════════════════════════════════════

  /// Taban eşya fiyatları, NOVA giderleri, paketler, tavan.
  static String kazancTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 15, 'Kazanç Tablosu', '15-kazanc.md');
    sb
      ..writeln('# 15 · Kazanç Tablosu')
      ..writeln()
      ..writeln('Kural belgesi: [15 · Kazanç](15-kazanc.md). Koddan üretilir.')
      ..writeln()
      ..writeln('## Taban eşya')
      ..writeln()
      ..writeln(
        '| Rank | Nesil bütçesi | Taban eşya fiyatı | Taban eşyanın rankı | Bütçenin |',
      )
      ..writeln('|---|---:|---:|---|---:|');
    for (final t in ItemTier.values) {
      final r = t.index;
      final butce = KaynakAkisi.neselButcesi(r);
      final fiyat = Kazanc.tabanEsyaFiyatiFor(r);
      sb.writeln(
        '| ${t.label} | ${sayi(butce, ondalik: 0)} | ${sayi(fiyat, ondalik: 0)} '
        '| ${ItemTier.values[Kazanc.tabanEsyaRankiFor(r)].label} '
        '| %${sayi(fiyat / butce * 100)} |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Taban eşyanın kalitesi %${sayi(Kazanc.tabanEsyaKalitesi * 100, ondalik: 0)}, '
        'alt statı ${Kazanc.tabanEsyaAltStatSayisi}. Satılabilir kaynaklar: '
        '${Kaynak.values.map((k) => '${k.name} ${Kazanc.satilabilir(k) ? 'evet' : 'hayır'}').join(' · ')}; '
        'NOVA eşya satıyor mu: ${Kazanc.esyaSatilabilir ? 'evet' : 'hayır'}.',
      )
      ..writeln()
      ..writeln('## NOVA giderleri')
      ..writeln()
      ..writeln(
        'Saatte ${sayi(Kazanc.saatlikNova, ondalik: 0)} NOVA; bir NOVA '
        '${sayi(Kazanc.novaSaniyesi)} saniye oyun. Fiyat = kazandırdığı dakika ÷ 60 × saatlik NOVA.',
      )
      ..writeln()
      ..writeln('| Kalem | Kazandırdığı dakika | Fiyat |')
      ..writeln('|---|---:|---:|');
    for (final k in NovaKalemi.values) {
      if (k == NovaKalemi.cevirme) {
        for (final t in [ItemTier.cI, ItemTier.aI, ItemTier.parlayanPembe]) {
          sb.writeln(
            '| cevirme · ${t.label} | ${sayi(Kazanc.kazandirdigiDakika(k, tier: t))} '
            '| ${sayi(Kazanc.fiyatiFor(k, tier: t), ondalik: 0)} |',
          );
        }
        continue;
      }
      sb.writeln(
        '| ${k.name} | ${sayi(Kazanc.kazandirdigiDakika(k))} '
        '| ${sayi(Kazanc.fiyatiFor(k), ondalik: 0)} |',
      );
    }
    sb.writeln(
      '| cevirme · PARLAYAN PEMBE, 6 kilit | '
      '${sayi(Kazanc.cevirmeNovaFor(ItemTier.parlayanPembe, kilit: 6) / Kazanc.saatlikNova * 60)} '
      '| ${sayi(Kazanc.cevirmeNovaFor(ItemTier.parlayanPembe, kilit: 6), ondalik: 0)} |',
    );
    sb
      ..writeln()
      ..writeln(
        'Ömür boyu NOVA musluğu ${sayi(KaynakAkisi.omurBoyuNova, ondalik: 0)}. '
        'Zorunlu gider (onarım, envanter) '
        '${sayi(Kazanc.zorunluGiderFor(rankSayisi: Turetilenler.rankSayisi), ondalik: 0)}, '
        'musluğun %${sayi(Kazanc.zorunluGiderOrani * 100)}\'i. Çevirme dahil '
        '(her nesilde her yuva için bir tam çevirme) '
        '${sayi(Kazanc.omurBoyuNovaGideri, ondalik: 0)}, oran '
        '%${sayi(Kazanc.novaGiderOrani * 100)}: çevirme lüks, tavanı yok (15.3).',
      )
      ..writeln()
      ..writeln('## Paketler')
      ..writeln()
      ..writeln('| Fiyat | Bonus | NOVA | Oyun saati |')
      ..writeln('|---:|---:|---:|---:|');
    for (final (dolar, bonus) in [
      (0.99, 1.0),
      (TasarimGirdileri.hedefARPPU, TasarimGirdileri.paketBonusTavani),
    ]) {
      final nova = Kazanc.paketNova(dolar, bonus);
      sb.writeln(
        '| \$${sayi(dolar, ondalik: 2)} | ×${sayi(bonus, ondalik: 2)} | ${sayi(nova, ondalik: 0)} '
        '| ${sayi(nova / Kazanc.saatlikNova, ondalik: 0)} sa |',
      );
    }
    sb
      ..writeln()
      ..writeln(
        'Ödeyen oyuncunun payı musluğun %${sayi(Kazanc.odeyeninPayi * 100)}\'i; '
        'ARPU \$${sayi(Kazanc.arpu, ondalik: 2)}.',
      )
      ..writeln()
      ..writeln('## Paranın tavanı')
      ..writeln()
      ..writeln(
        'Kalite tabanı `kaliteAltSiniri = ${girdiDegeri(TasarimGirdileri.kaliteAltSiniri)}` ile '
        '**%${sayi(Kazanc.tavan * 100)}**; bir rank adımı %${sayi(Kazanc.rankAdimi * 100)}. '
        'SS–SSS bandında (`kaliteAltSiniriSS = ${girdiDegeri(TasarimGirdileri.kaliteAltSiniriSS)}`) '
        '%${sayi(Kazanc.tavanForTier(ItemTier.ssI) * 100)}, kapak taşlarında '
        '(`kaliteAltSiniriRenk = ${girdiDegeri(TasarimGirdileri.kaliteAltSiniriRenk)}`) '
        '%${sayi(Kazanc.tavanForTier(ItemTier.parlayanPembe) * 100)}; tavan yukarı '
        'çıktıkça daralıyor.',
      )
      ..writeln();
    _girdiler(sb, 15);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 17 · Mermi
  // ═══════════════════════════════════════════════════════════════════

  /// Fiyat eğrisi, PvE kazancı, PvP TTK, gider payı ve net prim — hepsi
  /// koddan; yan belgenin elle hesapladığı sayılar buradan basılıyor.
  /// 18 · Roket Tablosu — kadans, salvo, pay ve roket mermisi fiyatları.
  static String roketTablosu() {
    final sb = StringBuffer();
    _onBilgi(sb, 18, 'Roket Tablosu', '18-roket.md');
    final ref = ReferansCozumu.stats;
    sb
      ..writeln('# 18 · Roket Tablosu')
      ..writeln()
      ..writeln('Kural belgesi: [18 · Roket](18-roket.md). Koddan üretilir.')
      ..writeln()
      ..writeln('## Kadans ve pay')
      ..writeln()
      ..writeln(
        'Aralık `roketAraligi = ${girdiDegeri(TasarimGirdileri.roketAraligi)}` sn; '
        'kadans oranı ${sayi(Turetilenler.roketKadansOrani)}; roketatar yuva '
        'katsayısı ${sayi(Turetilenler.roketatarYuvaKatsayisi, ondalik: 3)}; '
        'birim oranı ${sayi(Turetilenler.roketBirimOrani)}.',
      )
      ..writeln()
      ..writeln('| Referans | Değer |')
      ..writeln('|---|---:|')
      ..writeln('| Salvo tabanı | ${sayi(ref.roketHasari, ondalik: 0)} |')
      ..writeln(
        '| Beklenen salvo (kritik dahil) | ${sayi(CombatGlossary.expectedRoketSalvo(ref), ondalik: 0)} |',
      )
      ..writeln('| Roket DPS | ${sayi(RoketOlcumu.dps, ondalik: 0)} |')
      ..writeln(
        '| Lazer DPS | ${sayi(CombatGlossary.expectedDps(ref), ondalik: 0)} |',
      )
      ..writeln(
        '| Roketin saldırı payı | %${sayi(RoketOlcumu.dpsPayi * 100)} |',
      )
      ..writeln(
        '| Bütçe payı (08.1) | %${sayi(TasarimGirdileri.payRoketatar / (TasarimGirdileri.payRoketatar + TasarimGirdileri.payLazer) * 100)} |',
      )
      ..writeln()
      ..writeln('## Roket mermisi')
      ..writeln()
      ..writeln(
        'Fiyat mermi eğrisinin (17.4) birim oranı katı; hasar başına bedel '
        'mermiyle aynı. Birim bir salvo (18.4).',
      )
      ..writeln()
      ..writeln(
        '| Roket | Çarpan | Birim fiyat | Hasar başına | Mermi karşılığı |',
      )
      ..writeln('|---|---:|---:|---:|---:|');
    for (final r in Roket.hepsi) {
      final c = r.carpan;
      sb.writeln(
        '| ${r.id} | ×$c '
        '| ${r.bedava ? 'bedava' : sayi(r.fiyat)} '
        '| ${r.bedava ? '—' : sayi(Turetilenler.roketHasarBedeli(c))} '
        '| ${r.bedava ? '—' : sayi(Turetilenler.mermiHasarBedeli(c))} |',
      );
    }
    return sb.toString();
  }

  static String mermiTablosu() {
    String isaretliYuzde(double p) =>
        '${p >= 0 ? '+' : '−'}%${sayi(p.abs() * 100)}';
    final sb = StringBuffer();
    _onBilgi(sb, 17, 'Mermi Tablosu', '17-mermi.md');
    sb
      ..writeln('# 17 · Mermi Tablosu')
      ..writeln()
      ..writeln('Kural belgesi: [17 · Mermi](17-mermi.md). Koddan üretilir.')
      ..writeln()
      ..writeln('## Fiyat ve kazanç')
      ..writeln()
      ..writeln(
        'Fiyat(m) = `mermiTabanFiyati` × m^`mermiFiyatUssu`; birim bir namlu '
        'atışı (17.8). Saatlik gider sıradan çevrimde sürekli farm: öldürme '
        'başına ${sayi(MermiOlcumu.atisBasinaOldurme)} atış ÷ çarpan × fiyat; '
        'gelir payı referans saatlik gelire '
        '(${sayi(TasarimGirdileri.tabanSaatlikGelir, ondalik: 0)}) göre.',
      )
      ..writeln()
      ..writeln(
        '| Mermi | Çarpan | Birim fiyat | Hasar başına | Sıradan öldürme/sa '
        '| PvE kazancı | Güçlü kazancı | PvP TTK | Saatlik gider | Gelirin '
        '| PvP net prim |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final m in Mermi.hepsi) {
      if (m.sifon) continue;
      final c = m.carpan;
      sb.writeln(
        '| ${m.id} | ×$c '
        '| ${m.bedava ? 'bedava' : sayi(m.fiyat)} '
        '| ${m.bedava ? '—' : sayi(Turetilenler.mermiHasarBedeli(c))} '
        '| ${sayi(Turetilenler.mermiOldurmeSa(c), ondalik: 0)} '
        '| ×${sayi(1 + Turetilenler.mermiPveKazanci(c), ondalik: 2)} '
        '| ×${sayi(1 + Turetilenler.mermiPveKazanci(c, guclu: true), ondalik: 2)} '
        '| ${sayi(Turetilenler.mermiPvpTtk(c))} sn '
        '| ${sayi(MermiOlcumu.saatlikGider(c), ondalik: 0)} '
        '| %${sayi(MermiOlcumu.gelirPayi(c) * 100)} '
        '| ${isaretliYuzde(MermiOlcumu.pvpNetPrim(c))} |',
      );
    }
    final sifon = Mermi.sf1;
    sb
      ..writeln(
        '| ${sifon.id} · sifon | ×${sifon.carpan} kalkan '
        '| ${sayi(sifon.fiyat)} '
        '| ${sayi(Turetilenler.mermiHasarBedeli(sifon.carpan))} '
        '| — | — | — | yalnız kalkan | — | — | — |',
      )
      ..writeln()
      ..writeln(
        'Sifonun kalkan yenilenmesine karşı etkin çarpanı '
        '×${sayi(MermiOlcumu.sifonEtkinCarpani, ondalik: 2)} '
        '(nominal ×${sifon.carpan}). Üs ankrajı '
        '${sayi(Turetilenler.mermiUsAnkraji, ondalik: 3)}; tepe tablodaki üs '
        '${girdiDegeri(TasarimGirdileri.mermiFiyatUssu)}. Kilitler: MR-1 '
        'bedava ${TasarimGirdileri.mr1Bedava ? 'evet' : 'hayır'} · NOVA mermi '
        'satıyor ${Mermi.novaIleSatilir ? 'evet' : 'hayır'}. Savaş puanı '
        'mermiyi saymıyor: patlama gücü BR\'yi '
        '${TasarimGirdileri.mermiCarpanTavani} kat aşabilir (17.7).',
      )
      ..writeln();
    _girdiler(sb, 17);
    return sb.toString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 16 · Tepe Tablo
  // ═══════════════════════════════════════════════════════════════════

  /// Bütün girdiler alan alan, dağılım, döngüler, sistem durumu.
  static String tepeTablo() {
    final sb = StringBuffer();
    _onBilgi(sb, 16, 'Tepe Tablo', '16-denge-denetimi.md');
    final girdiler = TasarimGirdileri.hepsi;
    sb
      ..writeln('# 16 · Tepe Tablo')
      ..writeln()
      ..writeln(
        'Kural belgesi: [16 · Denge Denetimi](16-denge-denetimi.md). Koddan '
        'üretilir: ${DengeDenetimi.girdiSayisi} girdi, alan başına '
        '${sayi(DengeDenetimi.ortalamaGirdi)}. Çakışan girdi: '
        '${DengeDenetimi.cakisanGirdiler.isEmpty ? 'yok' : DengeDenetimi.cakisanGirdiler.join(', ')}; '
        'gerekçesiz girdi: '
        '${DengeDenetimi.gerekcesizGirdiler.isEmpty ? 'yok' : DengeDenetimi.gerekcesizGirdiler.join(', ')}.',
      )
      ..writeln()
      ..writeln('## Girdiler')
      ..writeln()
      ..writeln('| Alan | Girdi | Değer | Gerekçe |')
      ..writeln('|---|---|---:|---|');
    for (final g in girdiler) {
      sb.writeln(
        '| ${g.alan.toString().padLeft(2, '0')} | `${g.ad}` | ${girdiDegeri(g.deger)} | ${g.gerekce} |',
      );
    }
    sb
      ..writeln()
      ..writeln('## Dağılım')
      ..writeln()
      ..writeln('| Alan | Ad | Katman | Girdi |')
      ..writeln('|---|---|---|---:|');
    final dagilim = DengeDenetimi.girdiDagilimi;
    for (final a in TasarimHaritasi.hepsi) {
      sb.writeln(
        '| ${a.no.toString().padLeft(2, '0')} | ${a.ad} | ${a.katman.name} | ${dagilim[a.no] ?? 0} |',
      );
    }
    sb
      ..writeln()
      ..writeln('## Karar döngüleri')
      ..writeln()
      ..writeln('| Soran → cevaplayan | Soru | Karar |')
      ..writeln('|---|---|---|');
    for (final d in DengeDenetimi.dongular) {
      sb.writeln(
        '| ${d.soran.toString().padLeft(2, '0')} → ${d.cevaplayan.toString().padLeft(2, '0')} '
        '| ${d.soru} | ${d.karar} |',
      );
    }
    sb
      ..writeln()
      ..writeln('## Sistem durumu')
      ..writeln()
      ..writeln(
        'Tamamlanma %${sayi(DengeDenetimi.tamamlanmaOrani * 100)}, sistem oranı '
        '%${sayi(DengeDenetimi.sistemOrani * 100)}. Eksik: '
        '${DengeDenetimi.eksikler.isEmpty ? 'yok' : DengeDenetimi.eksikler.map((e) => e.ad).join(', ')}.',
      )
      ..writeln()
      ..writeln('| Sistem | Mevcut | Hedef | Alan |')
      ..writeln('|---|---:|---:|---|');
    for (final s in DengeDenetimi.sistemler) {
      sb.writeln(
        '| ${s.ad} | ${s.mevcut} | ${s.hedef} | ${s.alan.toString().padLeft(2, '0')} |',
      );
    }
    sb.writeln();
    return sb.toString();
  }
}
