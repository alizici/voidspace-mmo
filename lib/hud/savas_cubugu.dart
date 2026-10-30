import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/app_scope.dart';
import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/metin.dart';
import '../hangar/menu_cells.dart';
import '../net/hangar_view.dart';
import '../net/net_client.dart';
import 'hud_dugmeleri.dart';

const hudMermiKey = Key('hud-mermi');
const hudRoketKey = Key('hud-roket');
const hudFormasyonKey = Key('hud-formasyon');
const hudSecimPaneliKey = Key('hud-secim-paneli');
Key hudMermiSecimKey(String id) => Key('hud-mermi-$id');
Key hudRoketSecimKey(String id) => Key('hud-roket-$id');
Key hudFormasyonSecimKey(String id) => Key('hud-formasyon-$id');

enum _Secim { mermi, roket, formasyon }

/// SAVAŞ ÇUBUĞU — dövüşün ortasında değişen iki seçim: mermi ve formasyon.
///
/// Hangar bir mod değişimi, bu çubuk değil: mermi (17.8) ve formasyon (05.9)
/// dövüş sırasında değişiyor ve ikisi de sunucuda bir hangar komutu; menüye
/// girip çıkmadan seçilebilmeli. Alt ortada: sol başparmak yön, sağ
/// başparmak eylem, orta ikisine de eşit uzaklıkta.
///
/// Seçenekler ŞERİT, ızgara değil: ilk hâli yirmi formasyonu bir ızgaraya
/// döküyordu ve telefonda oyunun ortasını kapatıyordu. Tek satır, yatay
/// kayıyor, genişliği iki yandaki kumandalara dokunmuyor.
///
/// Roket YOK ve bu bir eksik değil, karar: roketatar bir stat eşyası, mermi
/// atmıyor; seçilecek roket türü olmayan bir düğme boş bir kapı olurdu
/// (borç defteri B20).
class SavasCubugu extends StatefulWidget {
  const SavasCubugu({super.key});

  @override
  State<SavasCubugu> createState() => _SavasCubuguState();
}

class _SavasCubuguState extends State<SavasCubugu> {
  _Secim? _acik;

  void _degistir(_Secim secim) =>
      setState(() => _acik = _acik == secim ? null : secim);

  void _gonder(NetClient client, String action, Map<String, Object?> payload) {
    client.hangarAction(action, payload);
    // Şerit seçimle kapanıyor: onay sunucudan, düğmenin değeri onunla
    // değişiyor. Açık kalsaydı oyuncu "tuttu mu" diye ikinci kez basardı.
    setState(() => _acik = null);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final client = scope.client;
    final touch = scope.touchControls;
    final dil = context.dil;
    // Şerit genişliği ekrandan: ortalanıyor, iki yanda telefonda çubuğa
    // (8 + 118 + 8) ve eylem yığınına eşit pay bırakıyor; masaüstünde
    // alttaki İTKİ hapına. Bir kez 600'e çıkınca çubuğun kenarına
    // değiyordu — pay iki yandan, tek yandan değil.
    final kenar = touch ? 134.0 : 100.0;
    final seritGenisligi = (MediaQuery.sizeOf(context).width - 2 * kenar).clamp(
      240.0,
      600.0,
    );
    return StreamBuilder<void>(
      stream: client.changes,
      builder: (context, _) {
        final hangar = client.hangar;
        final mermi = hangar?.seciliMermi ?? Mermi.varsayilan;
        final formasyon = Formasyon.ofId(hangar?.formasyonId);
        final stok = hangar?.mermiSayisi(mermi.id) ?? 0;
        final roket = hangar?.seciliRoket ?? Roket.varsayilan;
        final roketStok = hangar?.roketSayisi(roket.id) ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_acik == _Secim.mermi)
              _mermiSeridi(client, hangar, mermi, seritGenisligi, dil),
            if (_acik == _Secim.roket)
              _roketSeridi(client, hangar, roket, seritGenisligi, dil),
            if (_acik == _Secim.formasyon)
              _formasyonSeridi(client, hangar, formasyon, seritGenisligi, dil),
            if (_acik != null) const SizedBox(height: 6),
            // `Wrap`, `Row` değil: üç hap dar pencerede (telefon dikey,
            // masaüstü dikey) tek satıra sığmıyor ve taşıyordu; sarınca
            // ikinci satıra iniyor, oyunun ortasını yine kapatmıyor.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                HudPill(
                  key: hudMermiKey,
                  glif: HudGlif.mermi,
                  label: Metin.magazaMermi(dil),
                  value: mermi.bedava ? '${mermi.id} ∞' : '${mermi.id} · $stok',
                  color: mermi.sifon ? Palette.shield : Palette.slotLaser,
                  active: _acik == _Secim.mermi,
                  compact: !touch,
                  onTap: () => _degistir(_Secim.mermi),
                ),
                // ROKET: roketatar bir silah (18), mermisi mermi gibi
                // seçiliyor. Uzun süre burada düğme yoktu, çünkü seçilecek
                // şey yoktu (borç defteri B20).
                HudPill(
                  key: hudRoketKey,
                  glif: HudGlif.roket,
                  label: Metin.magazaRoket(dil),
                  value: roket.bedava
                      ? '${roket.id} ∞'
                      : '${roket.id} · $roketStok',
                  color: Palette.slotLauncher,
                  active: _acik == _Secim.roket,
                  compact: !touch,
                  onTap: () => _degistir(_Secim.roket),
                ),
                HudPill(
                  key: hudFormasyonKey,
                  glif: HudGlif.formasyon,
                  label: Metin.magazaFormasyon(dil),
                  value: menuUpper(formasyonAdi(formasyon, dil), dil),
                  color: _egilimRengi(formasyon.egilim),
                  active: _acik == _Secim.formasyon,
                  compact: !touch,
                  onTap: () => _degistir(_Secim.formasyon),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _mermiSeridi(
    NetClient client,
    HangarView? hangar,
    Mermi secili,
    double genislik,
    Dil dil,
  ) => HudSecimSeridi(
    key: hudSecimPaneliKey,
    baslik: Metin.mermiSeridiBasligi(dil),
    maxWidth: genislik,
    children: [
      for (final m in Mermi.hepsi)
        HudSecenek(
          key: hudMermiSecimKey(m.id),
          label: m.bedava
              ? '${m.id} ∞'
              // [menuUpper] DEĞİL: etiket bir model kodu ("MR-3 ×3"),
              // çevrilmiyor ve Türkçe kuralının uygulanacağı harfi yok.
              : '${m.etiket.toUpperCase()} · ${hangar?.mermiSayisi(m.id) ?? 0}',
          color: m.sifon ? Palette.shield : Palette.slotLaser,
          secili: m.id == secili.id,
          // Stoksuz mermi görünüyor ama basılmıyor: oyuncu neyi
          // alabileceğini görmeli, sunucunun reddini beklememeli.
          etkin: m.bedava || (hangar?.mermiSayisi(m.id) ?? 0) > 0,
          onTap: () => _gonder(client, 'mermi_sec', {'id': m.id}),
        ),
    ],
  );

  Widget _roketSeridi(
    NetClient client,
    HangarView? hangar,
    Roket secili,
    double genislik,
    Dil dil,
  ) => HudSecimSeridi(
    key: hudSecimPaneliKey,
    baslik: Metin.roketSeridiBasligi(dil),
    maxWidth: genislik,
    children: [
      for (final r in Roket.hepsi)
        HudSecenek(
          key: hudRoketSecimKey(r.id),
          label: r.bedava
              ? '${r.id} ∞'
              : '${r.etiket.toUpperCase()} · ${hangar?.roketSayisi(r.id) ?? 0}',
          color: Palette.slotLauncher,
          secili: r.id == secili.id,
          etkin: r.bedava || (hangar?.roketSayisi(r.id) ?? 0) > 0,
          onTap: () => _gonder(client, 'roket_sec', {'id': r.id}),
        ),
    ],
  );

  Widget _formasyonSeridi(
    NetClient client,
    HangarView? hangar,
    Formasyon secili,
    double genislik,
    Dil dil,
  ) => HudSecimSeridi(
    key: hudSecimPaneliKey,
    baslik: Metin.formasyonSeridiBasligi.bicim(dil, {
      'egilim': _egilimMetni(secili.egilim, dil),
    }),
    maxWidth: genislik,
    children: [
      for (final f in Formasyon.hepsi)
        HudSecenek(
          key: hudFormasyonSecimKey(f.id),
          label: menuUpper(formasyonAdi(f, dil), dil),
          color: _egilimRengi(f.egilim),
          secili: f.id == secili.id,
          // Sahip olunmayan formasyon görünüyor ama basılmıyor (15.9):
          // mermide olduğu gibi, oyuncu neyi alabileceğini görmeli.
          etkin: hangar?.formasyonaSahip(f.id) ?? false,
          onTap: () => _gonder(client, 'formasyon', {'id': f.id}),
        ),
    ],
  );

  static Color _egilimRengi(FormasyonEgilimi egilim) => switch (egilim) {
    FormasyonEgilimi.saldiri => Palette.danger,
    FormasyonEgilimi.savunma => Palette.accent,
    FormasyonEgilimi.denge => Palette.slotDroid,
  };

  static String _egilimMetni(FormasyonEgilimi egilim, Dil dil) =>
      switch (egilim) {
        FormasyonEgilimi.saldiri => Metin.egilimSaldiri(dil),
        FormasyonEgilimi.savunma => Metin.egilimSavunma(dil),
        FormasyonEgilimi.denge => Metin.egilimDenge(dil),
      };
}
