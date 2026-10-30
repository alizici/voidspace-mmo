import 'package:shared_preferences/shared_preferences.dart';

import '../dil/dil_deposu.dart';

/// Dil tercihini uygulama kumbarasında tutan depo.
///
/// Okunamayan bir kumbara dili CİHAZ DİLİNE düşürüyor, oyunu durdurmuyor —
/// `PrefsTokenStore` ile aynı kural: bir tercihin kaybolması can sıkıcı, bir
/// açılışın engellenmesi ise arıza.
class PrefsDilDeposu implements DilDeposu {
  static const String _key = 'voidspace.dil';

  @override
  Future<String?> oku() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> yaz(String kod) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, kod);
    } on Object {
      // Yazamadıysak seçim bu oturum boyunca geçerli; oyunu durdurmaz.
    }
  }
}
