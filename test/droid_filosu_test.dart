@Tags(['disi'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/game/art/droid_art.dart';
import 'package:voidspace3/game/components/droid_filosu.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// Droid filosu: yirmi formasyonun geometrisi, altı kademenin çizimi.
void main() {
  test('her formasyon istenen sayıda yuva üretiyor, on droide kadar', () {
    for (final sekil in FormasyonSekli.values) {
      for (var n = 0; n <= FormasyonGeometrisi.enCokDroid; n++) {
        expect(
          FormasyonGeometrisi.sabitYuvalar(sekil, n),
          hasLength(n),
          reason: '${sekil.name} × $n',
        );
        expect(FormasyonGeometrisi.yuvalar(sekil, n, 80), hasLength(n));
        if (FormasyonGeometrisi.canli(sekil)) {
          final canli = FormasyonGeometrisi.canliYuvalar(sekil, n, 80, 1.7);
          expect(canli, hasLength(n), reason: '${sekil.name} canlı × $n');
          for (final y in canli) {
            expect(y.derinlik, inInclusiveRange(-1.0, 1.0));
          }
        } else {
          expect(FormasyonGeometrisi.canliYuvalar(sekil, n, 80, 0), isEmpty);
        }
      }
    }
  });

  test('yedi şekil canlı, on üçü sabit; yuvalar geminin ARKASINA düşüyor', () {
    final canli = FormasyonSekli.values.where(FormasyonGeometrisi.canli);
    expect(canli, hasLength(7));
    // Tek droid varsayılan yuvada: geminin arkası +Y.
    expect(FormasyonGeometrisi.sabitYuvalar(FormasyonSekli.ok, 1), [
      const Offset(0, 64),
    ]);
  });

  test('filo hedefe yerleşiyor ve meta ile boyutlanıyor', () {
    final filo = DroidFilosu();
    filo.hedefle(
      x: 100,
      y: 100,
      aci: 0,
      droidler: const [(1, 0), (6, 3)],
      formasyon: Formasyon.hepsi.indexWhere((f) => f.id == 'ok'),
    );
    expect(filo.birimler, hasLength(2));
    expect(filo.birimler[1].seviye, 6);
    expect(filo.birimler[1].model, DroidModeli.elmas);
    for (var i = 0; i < 120; i++) {
      filo.update(1 / 60);
    }
    // Yuvalar geminin çevresinde: hiçbiri gemiden 400 birimden uzak değil,
    // ve iki droid aynı yerde durmuyor.
    for (final b in filo.birimler) {
      expect((b.konum - const Offset(100, 100)).distance, lessThan(400));
    }
    expect(
      (filo.birimler[0].konum - filo.birimler[1].konum).distance,
      greaterThan(1),
    );
    filo.hedefle(x: 100, y: 100, aci: 0, droidler: const [], formasyon: 0);
    expect(filo.birimler, isEmpty);
  });

  test('dört model altı kademede çiziliyor — istisna yok', () {
    // Sanat katmanı çekirdeği okumuyor: model ve kademe sayısı iki yerde
    // ayrı duruyor, burada eşitleniyor.
    expect(DroidCizimi.values.length, DroidModeli.values.length);
    expect(DroidArt.maxLevel, DroidSeviyesi.tavan);
    for (final model in DroidModeli.values) {
      for (var lv = 1; lv <= DroidSeviyesi.tavan; lv++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        DroidArt.ofIndex(
          model.index,
        ).draw(canvas, t: 0.3, level: lv, opacity: 0.8);
        recorder.endRecording().dispose();
      }
    }
    expect(DroidArt.normalizeLevel(0), 1);
    expect(DroidArt.normalizeLevel(99), DroidSeviyesi.tavan);
  });
}
