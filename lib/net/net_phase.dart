/// Bağlantının nerede olduğu.
///
/// Kendi dosyasında, çünkü HUD ve `ShipBloc` bunu okumak zorunda ama
/// [NetClient]'ı — yani `web_socket_channel`'ı ve tüm taşıma katmanını —
/// içeri almamalı. Bir enum'un ayrı dosyada durması için fazla küçük olduğu
/// doğru; bir katman sınırını ayakta tutmak için yeterince büyük.
enum NetPhase {
  /// Henüz bağlanılmadı.
  idle,

  /// Soket açılıyor.
  connecting,

  /// Soket açık ama KİMLİK yok: kayıt ya da giriş bekleniyor.
  needsAuth,

  /// Kayıt/giriş isteği yolda. Parola türetmesi sunucuda ~100 ms sürüyor,
  /// yani bu durum gerçekten görünür — arayüz beklemeyi göstermeli.
  authenticating,

  /// Dünyadayız.
  playing,

  /// Sunucu reddetti (sürüm uyuşmazlığı, dolu). Yeniden denemek anlamsız.
  rejected,

  /// Bağlantı koptu; yeniden deneniyor.
  disconnected,
}
