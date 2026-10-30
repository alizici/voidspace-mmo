import 'package:voidspace_core/voidspace_core.dart';

import '../net/durum_kodu.dart';
import 'dil.dart';
import 'kimlik_metni.dart';
import 'metin.dart';

/// HUD perdesine düşen DURUM KODUNU okunur cümleye çevirir.
///
/// Perdede iki ayrı kaynaktan kod görünebiliyor ve ikisi de aynı satıra
/// yazılıyor: yerel olaylar ([DurumKodu]) ve sunucunun reddi (`KimlikKodu`).
/// Çağrı yerinin hangisinin geldiğini bilmesi gerekmiyor — o ayrımı burası
/// yapıyor.
///
/// Tanınmayan kod AYNEN dönüyor: yeni bir sunucunun bilmediğimiz bir kodu,
/// okunaksız görünmeli ama kaybolmamalı.
String? durumMetni(String? kod, Dil dil) {
  if (kod == null) return null;
  final durum = DurumKodu.koddan(kod);
  if (durum == null) return kimlikMetni(kod, dil);
  return switch (durum) {
    DurumKodu.arkaPlanda => Metin.agArkaPlanda(dil),
    DurumKodu.baglaniliyor => Metin.agBaglaniliyor(dil),
    DurumKodu.kapandi => Metin.agKapandi(dil),
    DurumKodu.hata => Metin.agHatasi(dil),
    DurumKodu.ulasilamadi => Metin.agUlasilamadi(dil),
    DurumKodu.bozukSnapshot => Metin.agBozukSnapshot(dil),
    DurumKodu.bozukCerceve => Metin.agBozukCerceve(dil),
    DurumKodu.gonderilemedi => Metin.agGonderilemedi(dil),
    DurumKodu.atlasYuklenemedi => Metin.agAtlasYuklenemedi(dil),
  };
}

/// Geçit reddinin KODUNU cümleye çevirir.
///
/// Ayrı bir işlev, ayrı bir kod uzayı: geçit reddi HUD perdesine değil geçit
/// isteminin üstüne yazılıyor ve orada başka hiçbir kod görünmüyor.
String? gecitMetni(String? kod, Dil dil) {
  if (kod == null) return null;
  final (gecit, argumanlar) = GecitKodu.coz(kod);
  if (gecit == null) return kod;
  final n = argumanlar.elementAtOrNull(0) ?? '?';
  return switch (gecit) {
    GecitKodu.menzilDisi => Metin.gecitMenzilDisi(dil),
    GecitKodu.brYetmiyor => Metin.gecitBrYetmiyor.bicim(dil, {'n': n}),
    GecitKodu.seviyeYetmiyor => Metin.gecitSeviyeYetmiyor.bicim(dil, {'n': n}),
    GecitKodu.haritaDolu => Metin.gecitHaritaDolu(dil),
    GecitKodu.basarisiz => Metin.gecitBasarisiz(dil),
  };
}

/// Hangar işleminin REDDİNİ cümleye çevirir.
///
/// Sunucu `HangarError`ün ADINI gönderiyor (`notEnoughMaterials`), metnini
/// değil: çekirdekteki `HangarError.message` tasarım belgelerinin ve sunucu
/// günlüğünün kanonik Türkçesi olarak duruyor, oyuncunun okuduğu cümle
/// burada kuruluyor.
String? hangarHataMetni(String? kod, Dil dil) {
  if (kod == null) return null;
  final hata = HangarError.values.where((h) => h.name == kod).firstOrNull;
  if (hata == null) return kod;
  return switch (hata) {
    HangarError.notPurchasable => Metin.hataNotPurchasable(dil),
    HangarError.kilitli => Metin.hataKilitli(dil),
    HangarError.filoDolu => Metin.hataFiloDolu(dil),
    HangarError.mermiYok => Metin.hataMermiYok(dil),
    HangarError.roketYok => Metin.hataRoketYok(dil),
    HangarError.novaYok => Metin.hataNovaYok(dil),
    HangarError.notFound => Metin.hataEsyaYok(dil),
    HangarError.notOwned => Metin.hataSendeYok(dil),
    HangarError.wrongSlot => Metin.hataYanlisYuva(dil),
    HangarError.noSuchSlot => Metin.hataYuvaYok(dil),
    HangarError.notEnoughCredits => Metin.hataParaYetmiyor(dil),
    HangarError.alreadyOwned => Metin.hataZatenSahip(dil),
    HangarError.maxLevel => Metin.hataSonSeviye(dil),
    HangarError.notEnoughMaterials => Metin.hataMalzemeYetmiyor(dil),
    HangarError.equipped => Metin.hataTakili(dil),
    HangarError.notEnoughItems => Metin.hataYeterliEsyaYok(dil),
    HangarError.atTopRank => Metin.hataTepedeSin(dil),
  };
}
