/// Oturum belirtecinin kalıcı deposu.
///
/// **Arayüz burada, uygulaması değil.** [NetClient] bir eklentiye bağlanmıyor:
/// eklenti bağımlılığı, ağ testlerinin her birine platform kanalı taklidi
/// eklemek demek olurdu — oysa o testlerin belirteçle bir işi yok.
///
/// Uygulama kökü gerçek olanı geçiyor, testler [MemoryTokenStore] kullanıyor.
abstract interface class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Diske yazmayan depo — testlerin ve belirteç kalıcılığı istemeyen
/// bağlamların varsayılanı.
class MemoryTokenStore implements TokenStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String token) async => _value = token;

  @override
  Future<void> clear() async => _value = null;
}
