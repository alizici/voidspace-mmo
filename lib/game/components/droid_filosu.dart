import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../art/droid_art.dart';

/// Filodaki bir droidin uzaydaki yeri.
class DroidBirimi {
  DroidBirimi({required this.konum, required this.seviye, required this.model});

  Offset konum;

  /// 3B formasyonlarda `[-1, 1]`: eksi arkada ve küçük, artı önde ve büyük.
  double derinlik = 0;
  int seviye;
  DroidModeli model;
}

/// FORMASYON GEOMETRİSİ — yirmi şeklin yuvaları, eski merdivenden.
///
/// Sanat, denge değil: hiçbir sayı güce girmiyor (05.9). Yerel çerçeve
/// geminin: +X sağ, +Y ARKA. Yedi şekil canlı (dönüyor, salınıyor) ve
/// derinlik üretiyor; kalanı sabit yuva.
abstract final class FormasyonGeometrisi {
  static const double referansUzunluk = 80;
  static const double yayilma = 1.7;
  static const int enCokDroid = 10;

  static bool canli(FormasyonSekli sekil) => switch (sekil) {
    FormasyonSekli.halka ||
    FormasyonSekli.cark ||
    FormasyonSekli.burgu ||
    FormasyonSekli.kubbe ||
    FormasyonSekli.capraz ||
    FormasyonSekli.oncu ||
    FormasyonSekli.dalga => true,
    _ => false,
  };

  static double _olcek(double gemiUzunlugu) =>
      math.max(0.5, gemiUzunlugu / referansUzunluk) * yayilma;

  /// Sabit yuvalar, gemi ölçeğinde.
  static List<Offset> yuvalar(
    FormasyonSekli sekil,
    int sayi,
    double gemiUzunlugu,
  ) {
    final olcek = _olcek(gemiUzunlugu);
    return [for (final p in sabitYuvalar(sekil, sayi)) p * olcek];
  }

  /// Canlı yuvalar: konumla birlikte derinlik.
  static List<({Offset konum, double derinlik})> canliYuvalar(
    FormasyonSekli sekil,
    int sayi,
    double gemiUzunlugu,
    double zaman,
  ) {
    if (sayi <= 0) return const [];
    final olcek = _olcek(gemiUzunlugu);
    final cikti = <({Offset konum, double derinlik})>[];
    void yay(double x, double y, double z, double yaricap) {
      cikti.add((
        konum: Offset(x * olcek, y * olcek),
        derinlik: (z / yaricap).clamp(-1.0, 1.0),
      ));
    }

    switch (sekil) {
      case FormasyonSekli.halka:
        const yaricap = 66.0;
        final egim = 0.95 + math.sin(zaman * 1.1) * 0.22;
        final cosE = math.cos(egim);
        final sinE = math.sin(egim);
        final donus = zaman * 0.6;
        for (var i = 0; i < sayi; i++) {
          final aci = donus + i / sayi * 2 * math.pi;
          final cemberY = math.sin(aci) * yaricap;
          yay(math.cos(aci) * yaricap, cemberY * cosE, cemberY * sinE, yaricap);
        }
      case FormasyonSekli.cark:
        const yaricap = 70.0;
        final donus = zaman * 0.9;
        final cosD = math.cos(donus);
        final sinD = math.sin(donus);
        for (var i = 0; i < sayi; i++) {
          final aci = i / sayi * 2 * math.pi;
          final x = math.cos(aci) * yaricap;
          yay(x * cosD, math.sin(aci) * yaricap, -x * sinD, yaricap);
        }
      case FormasyonSekli.burgu:
        const yaricap = 32.0;
        final donus = zaman * 1.4;
        for (var i = 0; i < sayi; i++) {
          final u = i / math.max(1, sayi - 1);
          final aci = donus + u * 4 * math.pi + (i.isEven ? 0.0 : math.pi);
          yay(
            math.cos(aci) * yaricap,
            (u - 0.5) * 168,
            math.sin(aci) * yaricap,
            yaricap,
          );
        }
      case FormasyonSekli.kubbe:
        final yaricap = 74 * (1 + math.sin(zaman * 1.3) * 0.05);
        final donus = zaman * 0.5;
        for (var i = 0; i < sayi; i++) {
          final u = (i + 0.5) / sayi;
          final phi = u * math.pi / 2 * 0.92;
          final boylam = donus + i * 2.39996323;
          final halkaYaricapi = yaricap * math.cos(phi);
          yay(
            math.cos(boylam) * halkaYaricapi,
            math.sin(boylam) * halkaYaricapi,
            yaricap * math.sin(phi),
            yaricap,
          );
        }
      case FormasyonSekli.capraz:
        const egim = 0.6;
        final cosE = math.cos(egim);
        final sinE = math.sin(egim);
        final donus = zaman * 0.7;
        final cosD = math.cos(donus);
        final sinD = math.sin(donus);
        const yonler = [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)];
        const yaricap = 96.0;
        for (var i = 0; i < sayi; i++) {
          final yon = yonler[i % 4];
          final uzunluk = (34 + (i ~/ 4) * 26) / math.sqrt2;
          final x = yon.$1 * uzunluk;
          final y = yon.$2 * uzunluk;
          final egikY = y * cosE;
          final z = y * sinE;
          yay(x * cosD + z * sinD, egikY, -x * sinD + z * cosD, yaricap);
        }
      case FormasyonSekli.oncu:
        const yaricap = 64.0;
        final donus = zaman * 0.6;
        final cosD = math.cos(donus);
        final sinD = math.sin(donus);
        final yarim = (sayi + 1) ~/ 2;
        for (var i = 0; i < sayi; i++) {
          final ilkHalka = i < yarim;
          final halkaSayisi = ilkHalka ? yarim : sayi - yarim;
          final indeks = ilkHalka ? i : i - yarim;
          final aci = indeks / math.max(1, halkaSayisi) * 2 * math.pi;
          final x = math.cos(aci) * yaricap;
          final y = ilkHalka ? math.sin(aci) * yaricap : 0.0;
          final z = ilkHalka ? 0.0 : math.sin(aci) * yaricap;
          yay(x * cosD + z * sinD, y, -x * sinD + z * cosD, yaricap);
        }
      case FormasyonSekli.dalga:
        const genlik = 72.0;
        for (var i = 0; i < sayi; i++) {
          final u = i / math.max(1, sayi - 1) - 0.5;
          final faz = u * 4 * math.pi + zaman * 2.2;
          yay(u * 168, math.cos(faz) * 12, math.sin(faz) * genlik, genlik);
        }
      default:
        return const [];
    }
    return cikti;
  }

  /// Sabit yuvalar — kaynak geometrinin +Y önü, buranın +Y arkası; sonda
  /// çevriliyor.
  static List<Offset> sabitYuvalar(FormasyonSekli sekil, int sayi) {
    if (sayi <= 0) return const [];
    if (sayi == 1 && sekil != FormasyonSekli.yarasa) {
      return const [Offset(0, 64)];
    }
    var noktalar = <Offset>[];
    switch (sekil) {
      case FormasyonSekli.kabuk:
        const sira = [
          Offset(0, -90),
          Offset(0, 90),
          Offset(-18, 50),
          Offset(18, 50),
          Offset(-18, -50),
          Offset(18, -50),
          Offset(-54, 50),
          Offset(54, 50),
          Offset(-54, -50),
          Offset(54, -50),
        ];
        noktalar = [for (final p in sira.take(sayi)) Offset(p.dy, -p.dx)];
      case FormasyonSekli.ok:
        noktalar = List.generate(sayi, (i) {
          final taraf = i.isEven ? -1.0 : 1.0;
          final indeks = (i ~/ 2 + 1).toDouble();
          return Offset(taraf * indeks * 18, -indeks * 22);
        });
      case FormasyonSekli.mizrak:
        final ust = (sayi / 2).ceil();
        final alt = sayi - ust;
        for (var i = 0; i < ust; i++) {
          noktalar.add(Offset((i - (ust - 1) / 2) * 38, 48));
        }
        for (var i = 0; i < alt; i++) {
          noktalar.add(Offset((i - (alt - 1) / 2) * 38, -48));
        }
      case FormasyonSekli.yildiz:
        noktalar = List.generate(sayi, (i) {
          final dis = i < 5;
          final indeks = dis ? i : i - 5;
          final aci =
              -math.pi / 2 + indeks / 5 * 2 * math.pi + (dis ? 0 : math.pi / 5);
          final yaricap = dis ? 92.0 : 42.0;
          return Offset(math.cos(aci) * yaricap, math.sin(aci) * yaricap);
        });
      case FormasyonSekli.kiskac:
        noktalar = List.generate(sayi, (i) {
          final taraf = i.isEven ? -1.0 : 1.0;
          final indeks = (i ~/ 2).toDouble();
          final aci = math.pi / 2 - (0.2 + indeks / 4 * 0.6);
          final yaricap = 70 + indeks * 6;
          return Offset(
            taraf * math.cos(aci) * yaricap,
            math.sin(aci) * yaricap,
          );
        });
      case FormasyonSekli.ciftOk:
        noktalar = List.generate(sayi, (i) {
          final yarim = (sayi / 2).ceil();
          final on = i < yarim;
          final yerel = on ? i : i - yarim;
          final taraf = yerel.isEven ? -1.0 : 1.0;
          final katman = (yerel ~/ 2 + 1).toDouble();
          final p = Offset(taraf * katman * 18, (on ? 1 : -1) * katman * 22);
          return Offset(p.dy, -p.dx);
        });
      case FormasyonSekli.elmas:
        const hepsi = [
          Offset(0, 88),
          Offset(88, 0),
          Offset(0, -88),
          Offset(-88, 0),
          Offset(0, 44),
          Offset(44, 0),
          Offset(0, -44),
          Offset(-44, 0),
          Offset(62, 62),
          Offset(-62, -62),
        ];
        noktalar = [
          for (final p in hepsi.take(sayi))
            Offset((p.dx + p.dy) * 0.70710678, -(p.dx - p.dy) * 0.70710678),
        ];
      case FormasyonSekli.kama:
        noktalar = List.generate(sayi, (i) {
          final taraf = i.isEven ? -1.0 : 1.0;
          final indeks = (i ~/ 2 + 1).toDouble();
          return Offset(taraf * indeks * 20, -indeks * 16);
        });
      case FormasyonSekli.guve:
        noktalar = List.generate(sayi, (i) {
          final taraf = i.isEven ? -1.0 : 1.0;
          final indeks = (i ~/ 2).toDouble();
          final yaricap = 56 + indeks * 16;
          final aci = 0.15 + indeks * 0.1;
          return Offset(
            taraf * math.cos(aci) * yaricap,
            -(math.sin(aci) * yaricap + indeks * 4),
          );
        });
      case FormasyonSekli.yengec:
        noktalar = List.generate(sayi, (i) {
          final taraf = i.isEven ? -1.0 : 1.0;
          final indeks = (i ~/ 2).toDouble();
          return Offset(taraf * (48 + indeks * 22), indeks * 10);
        });
      case FormasyonSekli.kalp:
        noktalar = List.generate(sayi, (i) {
          final aci = i / sayi * 2 * math.pi;
          final x = 16 * math.pow(math.sin(aci), 3).toDouble();
          final y =
              13 * math.cos(aci) -
              5 * math.cos(2 * aci) -
              2 * math.cos(3 * aci) -
              math.cos(4 * aci);
          return Offset(x * 4.4, y * 4.4);
        });
      case FormasyonSekli.baraj:
        final ilk = math.min((sayi / 2).ceil(), 5);
        final ikinci = sayi - ilk;
        for (var i = 0; i < ilk; i++) {
          noktalar.add(Offset((i - (ilk - 1) / 2) * 32, 82));
        }
        for (var i = 0; i < ikinci; i++) {
          noktalar.add(Offset((i - (ikinci - 1) / 2) * 32, 34));
        }
      case FormasyonSekli.yarasa:
        const yuvalar = [
          Offset(0, -78),
          Offset(0, 118),
          Offset(35, 98),
          Offset(-35, 98),
          Offset(75, 55),
          Offset(-75, 55),
          Offset(90, 10),
          Offset(-90, 10),
          Offset(62, -50),
          Offset(-62, -50),
        ];
        noktalar = yuvalar.take(sayi).toList();
      case FormasyonSekli.halka:
      case FormasyonSekli.cark:
        noktalar = List.generate(sayi, (i) {
          final aci = i / sayi * 2 * math.pi - math.pi / 2;
          return Offset(math.cos(aci) * 108, math.sin(aci) * 108);
        });
      case FormasyonSekli.burgu:
        noktalar = List.generate(sayi, (i) => Offset(0, 30 + i * 22));
      case FormasyonSekli.oncu:
        noktalar = List.generate(sayi, (i) {
          final aci =
              -math.pi * 0.25 + i / math.max(1, sayi - 1) * math.pi * 1.5;
          return Offset(math.cos(aci) * 92, -math.sin(aci) * 92);
        });
      case FormasyonSekli.kubbe:
        noktalar = List.generate(sayi, (i) {
          final aci = math.pi + i / math.max(1, sayi - 1) * math.pi;
          return Offset(math.cos(aci) * 84, -math.sin(aci) * 84);
        });
      case FormasyonSekli.capraz:
        const ceyrekler = [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)];
        noktalar = List.generate(sayi, (i) {
          final c = ceyrekler[i % 4];
          final katman = (i ~/ 4 + 1).toDouble();
          return Offset(c.$1 * katman * 32, c.$2 * katman * 32);
        });
      case FormasyonSekli.dalga:
        noktalar = List.generate(sayi, (i) {
          final indeks = i - (sayi - 1) / 2;
          return Offset(indeks * 26, math.cos(indeks * 1.05) * 28);
        });
    }
    return [for (final p in noktalar) Offset(p.dx, -p.dy)];
  }
}

/// DROİD FİLOSU — bir geminin droidlerini formasyonda taşıyan bileşen.
///
/// Gemiye bağlı değil, dünyaya bağlı: gemi geçitten geçince silinip
/// kurulan bileşen ağacıyla aynı hayatı yaşıyor. Her karede [hedefle] ile
/// geminin pozu ve meta bilgisi geliyor; birimler yuvalarına yumuşak
/// yerleşiyor (`stationRate` 8: geminin hareketini taşıyor, gecikmeyi
/// kapatıyor). Derinlik ölçek ve saydamlık veriyor; ayrı ön/arka katman yok.
class DroidFilosu extends PositionComponent {
  DroidFilosu() : super(priority: 3);

  static const double yerlesmeHizi = 8;
  static const double gemiUzunlugu = 80;

  final List<DroidBirimi> birimler = [];
  double _zaman = 0;
  Offset _gemi = Offset.zero;
  Offset _oncekiGemi = Offset.zero;
  double _aci = 0;
  FormasyonSekli _sekil = FormasyonSekli.kabuk;
  bool _pozVar = false;

  /// Kamera görüyor mu; görmüyorsa çizilmiyor.
  bool gorunur = true;

  /// Geminin bu karedeki pozu ve filo bilgisi.
  void hedefle({
    required double x,
    required double y,
    required double aci,
    required List<(int seviye, int model)> droidler,
    required int formasyon,
  }) {
    _oncekiGemi = _pozVar ? _gemi : Offset(x, y);
    _gemi = Offset(x, y);
    _aci = aci;
    _pozVar = true;
    _sekil =
        (formasyon >= 0 && formasyon < Formasyon.hepsi.length
                ? Formasyon.hepsi[formasyon]
                : Formasyon.varsayilan)
            .sekil;
    final sayi = droidler.length.clamp(0, FormasyonGeometrisi.enCokDroid);
    while (birimler.length > sayi) {
      birimler.removeLast();
    }
    while (birimler.length < sayi) {
      birimler.add(
        DroidBirimi(konum: _gemi, seviye: 1, model: DroidModeli.ucuz),
      );
    }
    for (var i = 0; i < sayi; i++) {
      birimler[i]
        ..seviye = droidler[i].$1
        ..model = DroidModeli.ofIndex(droidler[i].$2);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _zaman += dt;
    if (birimler.isEmpty || !_pozVar) return;
    final alpha = 1 - math.exp(-yerlesmeHizi * dt);
    final cosA = math.cos(_aci);
    final sinA = math.sin(_aci);
    final gemiDelta = _gemi - _oncekiGemi;
    _oncekiGemi = _gemi;

    final canli = FormasyonGeometrisi.canli(_sekil);
    final canliYuvalar = canli
        ? FormasyonGeometrisi.canliYuvalar(
            _sekil,
            birimler.length,
            gemiUzunlugu,
            _zaman,
          )
        : null;
    final sabit = canli
        ? null
        : FormasyonGeometrisi.yuvalar(_sekil, birimler.length, gemiUzunlugu);
    for (var i = 0; i < birimler.length; i++) {
      final Offset yerel;
      if (canliYuvalar != null) {
        yerel = canliYuvalar[i].konum;
        birimler[i].derinlik = canliYuvalar[i].derinlik;
      } else {
        yerel = sabit![i];
        birimler[i].derinlik = 0;
      }
      final hedef = Offset(
        _gemi.dx + yerel.dx * cosA - yerel.dy * sinA,
        _gemi.dy + yerel.dx * sinA + yerel.dy * cosA,
      );
      final tasinan = birimler[i].konum + gemiDelta;
      birimler[i].konum = tasinan + (hedef - tasinan) * alpha;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!gorunur) return;
    for (final birim in birimler) {
      final olcek = 1 + birim.derinlik * 0.35;
      final saydamlik = 0.5 + (birim.derinlik + 1) / 2 * 0.5;
      canvas.save();
      canvas.translate(birim.konum.dx, birim.konum.dy);
      canvas.rotate(_aci);
      canvas.scale(olcek);
      DroidArt.ofIndex(
        birim.model.index,
      ).draw(canvas, t: _zaman, level: birim.seviye, opacity: saydamlik);
      canvas.restore();
    }
  }
}
