/// BAĞLANTI VE AÇILIŞ DURUMLARININ KODLARI.
///
/// Kendi dosyasında ve `NetPhase` ile aynı gerekçeyle: HUD bunu okumak zorunda
/// ama [NetClient]'ı — yani taşıma katmanının tamamını — içeri almamalı.
///
/// **Neden kod, neden metin değil.** Ağ katmanı Flutter bilmiyor, dolayısıyla
/// oyuncunun seçtiği dili de bilmiyor ve bilmemeli. Metin üretseydi tek bir
/// dilde üretirdi; kod üretince cümleyi dili bilen taraf kuruyor
/// (`lib/dil/durum_metni.dart`). Sunucunun kimlik hatalarında verilen kararın
/// aynısı — orada da telde metin değil `KimlikKodu` gidiyor.
///
/// Kodlar `ag.`/`oyun.` önekli: HUD'a düşen dize bir kimlik hatası (`kimlik.`)
/// da olabiliyor ve iki uzayın karışmaması gerekiyor.
enum DurumKodu {
  /// Uygulama arka planda — soket BİLEREK kapatıldı.
  arkaPlanda('ag.arka-planda'),

  baglaniliyor('ag.baglaniliyor'),
  kapandi('ag.kapandi'),
  hata('ag.hata'),
  ulasilamadi('ag.ulasilamadi'),
  bozukSnapshot('ag.bozuk-snapshot'),
  bozukCerceve('ag.bozuk-cerceve'),
  gonderilemedi('ag.gonderilemedi'),

  /// Gemi atlası yüklenemedi — ağ değil AÇILIŞ arızası, ama aynı perdede
  /// görünüyor. Sebebin ayrıntısı günlüğe yazılıyor; oyuncuya yalnız neyin
  /// olmadığı söyleniyor.
  atlasYuklenemedi('oyun.atlas');

  const DurumKodu(this.kod);

  final String kod;

  static DurumKodu? koddan(String? kod) {
    if (kod == null) return null;
    for (final d in values) {
      if (d.kod == kod) return d;
    }
    return null;
  }
}
