import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/hangar/item_glyph.dart';
import 'package:voidspace3/hangar/malzeme_ikonu.dart';
import 'package:voidspace3/hangar/rank_kutusu.dart';
import 'package:voidspace3/hangar/rank_plakasi.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Görsel referans: yirmi rankın plakası, üç sınıfta.
///
/// Üst şerit EŞYA (plaka + işaret + artı rozeti), orta şerit YÜKSELTME
/// MALZEMESİ (fiyal), alt şerit ÇEVİRİCİ (kıvılcım). Üçü de aynı rank
/// zeminini paylaşıyor — oyuncu bir SSS malzemeyi bir SSS eşyayla aynı
/// renkten tanımalı.
Future<void> _loadMono() async {
  for (final yol in const [
    '/System/Library/Fonts/Monaco.ttf',
    '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
  ]) {
    final dosya = File(yol);
    if (!dosya.existsSync()) continue;
    await (FontLoader('monospace')
          ..addFont(Future.value(dosya.readAsBytesSync().buffer.asByteData())))
        .load();
    return;
  }
}

void main() {
  testWidgets('Rank ikonu görsel referansı', (tester) async {
    await _loadMono();
    tester.view
      ..physicalSize = const Size(1360, 620)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = ValueKey('rank-ikonlari');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: CustomPaint(size: Size(1360, 620), painter: _Painter()),
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(key), matchesGoldenFile('rank_ikonlari.png'));
  });
}

class _Painter extends CustomPainter {
  const _Painter();

  static const double _hucre = 64;
  static const double _bosluk = 3;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0F17),
    );
    final adim = _hucre + _bosluk;
    final sol = (size.width - ItemTier.values.length * adim) / 2 + adim / 2;

    void satir(double y, String etiket, void Function(RankGorseli r) ciz) {
      _yaz(canvas, etiket, Offset(12, y - _hucre / 2 - 15));
      for (final r in RankGorseli.hepsi) {
        canvas
          ..save()
          ..translate(sol + r.tier.index * adim, y);
        ciz(r);
        canvas.restore();
      }
    }

    // ── EŞYA ──────────────────────────────────────────────────────────
    satir(110, 'EŞYA · plaka + işaret + artı', (r) {
      RankPlakasi.ciz(canvas, _hucre, r);
      // Faz SABİT: golden deterministik olmalı. 0,08 seçildi çünkü 0'da tek
      // nokta tam tepede duruyor ve "dönüyor" izlenimi vermiyordu.
      RankPlakasi.yorunge(canvas, _hucre, r, 0.08);
      final boy = rankIsaretBoyu(_hucre);
      canvas
        ..save()
        ..translate(-boy / 2, -boy / 2);
      const ItemGlyphPainter(
        ItemGlyph.laser,
        Color(0xFFF2F6FB),
      ).paint(canvas, Size(boy, boy));
      canvas.restore();
      // Artı, rank ile birlikte tırmanıyor: merdivenin tepesinde +15.
      RankPlakasi.artiRozeti(
        canvas,
        _hucre,
        (r.tier.index * ItemLevels.max / (ItemTier.values.length - 1)).round(),
        altKose: false,
      );
    });

    // ── IZGARA KADEMESİ ───────────────────────────────────────────────
    satir(232, 'IZGARA · 42 px, pip YOK', (r) {
      RankPlakasi.ciz(canvas, 42, r, detay: false);
      RankPlakasi.yorunge(canvas, 42, r, 0.08);
    });

    // ── MALZEME ───────────────────────────────────────────────────────
    satir(354, 'MALZEME · fiyal', (r) {
      RankPlakasi.ciz(canvas, _hucre, r, detay: false);
      MalzemePlakasi.siluet(canvas, _hucre, MalzemeIkonu.fiyal, r);
      RankPlakasi.yorunge(canvas, _hucre, r, 0.08);
    });

    satir(476, 'ÇEVİRİCİ · kıvılcım', (r) {
      RankPlakasi.ciz(canvas, _hucre, r, detay: false);
      MalzemePlakasi.siluet(canvas, _hucre, MalzemeIkonu.kivilcim, r);
      RankPlakasi.yorunge(canvas, _hucre, r, 0.08);
    });

    // Rank etiketleri.
    for (final r in RankGorseli.hepsi) {
      _yaz(
        canvas,
        r.tier.label,
        Offset(sol + r.tier.index * adim - 34, 522),
        boyut: 7.5,
        genislik: 68,
        ortala: true,
      );
      _yaz(
        canvas,
        '${r.derinlik} stat · ${r.yorungeNoktasi} nokta',
        Offset(sol + r.tier.index * adim - 34, 546),
        boyut: 7.5,
        genislik: 68,
        ortala: true,
        renk: const Color(0xFF61708A),
      );
    }
    _yaz(
      canvas,
      'pip ŞERİDİ = ItemBudget.altStatSayisi — tavan '
      '${ItemBudget.altStatTavani}, tabloda 7 değil',
      const Offset(12, 578),
      renk: const Color(0xFF61708A),
    );
  }

  void _yaz(
    Canvas c,
    String metin,
    Offset at, {
    double boyut = 11,
    double genislik = 400,
    bool ortala = false,
    Color renk = const Color(0xFF94A3B9),
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: metin,
        style: TextStyle(
          color: renk,
          fontSize: boyut,
          fontFamily: 'monospace',
        ),
      ),
      textAlign: ortala ? TextAlign.center : TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: genislik, minWidth: ortala ? genislik : 0);
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(_Painter old) => false;
}
