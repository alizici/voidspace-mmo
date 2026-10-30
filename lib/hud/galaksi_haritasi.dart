import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
// Önekli: bu dosyada `bolgeAdi` adında bir alan da var (düğümün bölge adını
// yazıp yazmayacağı) ve önekiz bir import ikisini karıştırırdı.
import '../dil/icerik.dart' as icerik;
import '../dil/metin.dart';
import '../hangar/menu_cells.dart';
import '../hangar/menu_theme.dart';

/// GALAKSİ HARİTASI — bütün dünyanın tek ekranda görünümü.
///
/// Yerleşim keyfî değil, **geçidin pusulasının aynısı**: PvP yukarıda (kuzey),
/// boss aşağıda (güney), bir sonraki bölge sağda (doğu). Oyuncu haritayı bir
/// kez okuduğunda hangi kenara uçacağını da öğrenmiş oluyor; iki ayrı şey
/// ezberlemesi gerekmiyor.
///
/// Çizgiler süs değil GEÇİT: rengi kilidin durumu. Kapalı bir çizgi "oraya bir
/// yol var ama henüz geçemiyorsun" diyor — kapalı kapıyı hedefe çeviren şey o.
class GalaksiEkrani extends StatelessWidget {
  const GalaksiEkrani({
    required this.br,
    this.seviye,
    this.konum,
    this.onKapat,
    super.key,
  });

  /// Oyuncunun savaş puanı — sunucudan gelen.
  final double br;

  /// Seviye — ikincil kapı; bilinmiyorsa yalnız savaş puanı sınanır.
  final int? seviye;

  /// Şu anda bulunduğu harita.
  final Harita? konum;

  final VoidCallback? onKapat;

  @override
  Widget build(BuildContext context) => MenuSurface(
    builder: (context, m) {
      final satirlar = GalaksiHaritasi.satirlarFor(
        br: br,
        seviye: seviye,
        konum: konum,
      );
      return Padding(
        padding: EdgeInsets.all(m.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Baslik(
              metrics: m,
              br: br,
              seviye: seviye,
              konum: konum,
              onKapat: onKapat,
            ),
            SizedBox(height: m.gap),
            // Merdiven sığdığında ORTALANIYOR, sığmadığında kayıyor.
            // `minWidth` olmadan satır sola yapışıyordu ve masaüstünde sekiz
            // bölgelik bir dünyanın beşi ekranın solunda bir yığın gibi
            // duruyordu — merdivenin uzunluğu değil, kalabalığı okunuyordu.
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < satirlar.length; i++) ...[
                          if (i > 0) _Omurga(acik: satirlar[i][0].acik),
                          _BolgeSutunu(durumlar: satirlar[i], metrics: m),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: m.gap),
            const _Efsane(),
          ],
        ),
      );
    },
  );
}

class _Baslik extends StatelessWidget {
  const _Baslik({
    required this.metrics,
    required this.br,
    this.seviye,
    required this.konum,
    required this.onKapat,
  });

  final MenuMetrics metrics;
  final double br;

  /// Seviye — ikincil kapı; bilinmiyorsa yalnız savaş puanı sınanır.
  final int? seviye;
  final Harita? konum;
  final VoidCallback? onKapat;

  @override
  Widget build(BuildContext context) {
    final acik = GalaksiHaritasi.durumFor(
      br: br,
      seviye: seviye,
    ).where((d) => d.acik);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(Metin.galaksi(context.dil), style: MenuType.title(metrics)),
        const SizedBox(width: 14),
        // Esnek, çünkü telefon yatayda başlık satırı taşıyordu. Bulunulan
        // harita dar ekranda düşüyor: zaten düğümün üstünde "BURADASIN"
        // yazıyor, yani kaybolan bilgi değil TEKRAR.
        Flexible(
          child: Text(
            '${Metin.savasPuani.bicim(context.dil, {'n': menuNumber(br, context.dil)})}'
            '   ·   '
            '${Metin.haritaAcik.bicim(context.dil, {'acik': acik.length, 'hepsi': Harita.hepsi.length})}'
            '${konum == null || metrics.tightText ? "" : "   ·   ${menuUpper(icerik.haritaAdi(konum!, context.dil), context.dil)}"}',
            style: MenuType.subtitle(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 14),
        if (onKapat != null)
          MenuButton(label: Metin.kapat(context.dil), onTap: onKapat),
      ],
    );
  }
}

/// Bir bölgenin üç haritası — pusula düzeninde.
class _BolgeSutunu extends StatelessWidget {
  const _BolgeSutunu({required this.durumlar, required this.metrics});

  final List<HaritaDurumu> durumlar;
  final MenuMetrics metrics;

  HaritaDurumu _tipin(HaritaTipi tip) =>
      durumlar.firstWhere((d) => d.harita.tip == tip);

  @override
  Widget build(BuildContext context) {
    final pve = _tipin(HaritaTipi.pve);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dugum(durum: _tipin(HaritaTipi.pvp), metrics: metrics),
        // Yaprak geçidi: bölge içi olduğu için kapısı yok — bölge açıksa açık.
        _Dal(acik: pve.acik),
        _Dugum(durum: pve, metrics: metrics, bolgeAdi: true),
        _Dal(acik: pve.acik),
        _Dugum(durum: _tipin(HaritaTipi.boss), metrics: metrics),
      ],
    );
  }
}

/// Bölgeler arası geçit — omurga.
class _Omurga extends StatelessWidget {
  const _Omurga({required this.acik});

  final bool acik;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 2,
    color: acik ? Palette.accent : Palette.faint.withValues(alpha: 0.45),
  );
}

/// Bölge içi geçit — yaprak dalı.
class _Dal extends StatelessWidget {
  const _Dal({required this.acik});

  final bool acik;

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    height: 14,
    color: acik ? Palette.accent : Palette.faint.withValues(alpha: 0.45),
  );
}

/// Tek bir harita.
class _Dugum extends StatelessWidget {
  const _Dugum({
    required this.durum,
    required this.metrics,
    this.bolgeAdi = false,
  });

  final HaritaDurumu durum;
  final MenuMetrics metrics;

  /// Bölge adı yalnız omurga düğümünde yazılıyor: üç kutuya üç kez yazmak
  /// aynı bilgiyi üç kez göstermek olurdu.
  final bool bolgeAdi;

  /// Düğümün alt satırı: neredesin · ne gerekiyordu · ne eksik.
  static String _durumMetni(HaritaDurumu d, Dil dil) {
    if (d.burada) return Metin.buradasin(dil);
    if (!d.acik) return '+${menuNumber(d.eksikBr, dil)} BR';
    // Serbest bölge: ilk bölgenin kapısı yok (bkz. `Bolge.girisEsigi`).
    if (d.harita.girisEsigi <= 0) return Metin.serbest(dil);
    // Simge YOK. Mono yazı tipinde '✓' boş kutu çiziliyor — bu projede daha
    // önce de yaşandı. Ayrımı `+` öneki taşıyor: kilitlide "daha gerekiyor",
    // açıkta yalnız neyin karşılığında açıldığı.
    return '${menuNumber(d.harita.girisEsigi, dil)} BR';
  }

  static Color _durumRengi(HaritaDurumu d) {
    if (d.burada) return Palette.accentBright;
    return d.acik ? Palette.muted : Palette.danger;
  }

  static const _renkler = {
    HaritaTipi.pve: Palette.good,
    HaritaTipi.pvp: Palette.danger,
    HaritaTipi.boss: Palette.boost,
  };

  @override
  Widget build(BuildContext context) {
    final acik = durum.acik;
    final renk = acik
        ? _renkler[durum.harita.tip]!
        : Palette.faint.withValues(alpha: 0.55);
    return Container(
      width: metrics.dense ? 104 : 124,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: acik
            ? Palette.menuPanel
            : Palette.menuPanel.withValues(alpha: 0.45),
        border: Border.all(
          color: durum.burada
              ? Palette.accentBright
              : renk.withValues(alpha: 0.5),
          width: durum.burada ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bolgeAdi)
            Text(
              menuUpper(icerik.bolgeAdi(durum.harita.bolge, context.dil), context.dil),
              style: MenuType.tile(color: acik ? Palette.ink : Palette.faint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            // [menuUpper] DEĞİL: PvE · PvP · Boss oyun terimi, her dilde
            // aynı — Türkçe büyük harf kuralının uygulanacağı bir harf yok.
            durum.harita.tip.ad.toUpperCase(),
            style: MenuType.label(color: renk),
          ),
          const SizedBox(height: 4),
          // Kapı HER ZAMAN yazıyor, yalnız kilitliyken değil.
          //
          // Önce açık haritalarda sadece "AÇIK" yazıyordu ve güçlenen bir
          // oyuncuda ekran tamamen bilgisizleşiyordu: hepsi açık, hiçbiri
          // neyin karşılığında açıldığını söylemiyor. Eşiği göstermek
          // merdiveni görünür tutuyor — geçilmiş basamaklar da basamaktır.
          Text(
            _durumMetni(durum, context.dil),
            style: MenuType.label(color: _durumRengi(durum)),
          ),
        ],
      ),
    );
  }
}

class _Efsane extends StatelessWidget {
  const _Efsane();

  @override
  Widget build(BuildContext context) => Text(
    Metin.galaksiEfsanesi(context.dil),
    style: MenuType.label(color: Palette.faint),
  );
}
