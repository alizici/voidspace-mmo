import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil_kapsami.dart';
import '../dil/icerik.dart';
import '../dil/sayi.dart' as bicim;
import '../hangar/menu_cells.dart';
import '../hangar/rank_plakasi.dart';
import '../net/net_client.dart';

/// Cüzdan ve "ne kazandım" bildirimi.
///
/// **Oyunun döngüsünü kapatan parça bu.** Ateş etmek, öldürmek ve para
/// kazanmak sunucuda çalışıyordu; oyuncunun bunu GÖRDÜĞÜ hiçbir yer yoktu.
/// Görülmeyen ödül, olmayan ödüldür — hangara girip bakiyenin değiştiğini
/// fark etmek bir geri bildirim değil, bir keşif.
///
/// Ganimet de burada (14.1): düşen eşya rank renginde adıyla, malzeme
/// adediyle. Aynı hata ikinci kez yaşanmıştı — sunucu düşeni hangara
/// yazıyor, ekran susuyordu. Ne düştüğünü sunucu söylüyor
/// (`ServerGanimet`); istemci hangar durumunu diff'lemiyor, çünkü envanter
/// başka yollardan da değişiyor ve satın alınan bir parça ganimet değil.
///
/// **Sayaç istemcide artmıyor.** Bakiye [NetClient.credits] / [NetClient.premium]
/// üzerinden geliyor ve onu yalnız sunucu yazıyor. İstemci kendi toplamını
/// tutsaydı tek bir kayıp mesaj cüzdanı kalıcı olarak ayrıştırırdı.
class RewardFeed extends StatefulWidget {
  const RewardFeed({required this.client, this.compact = false, super.key});

  final NetClient client;

  /// Telefonda: birim adları düşer, yalnız renk ve sayı kalır.
  final bool compact;

  @override
  State<RewardFeed> createState() => _RewardFeedState();
}

class _RewardFeedState extends State<RewardFeed>
    with SingleTickerProviderStateMixin {
  /// Ekranda duran bildirimler.
  final List<_Toast> _toasts = [];

  /// Saat `initState`'te kuruluyor, `late final` ile TEMBEL değil.
  ///
  /// Tembel kurulunca ilk erişim `dispose()` içinde oluyordu (çünkü `build`
  /// ona hiç dokunmuyor) ve `createTicker` orada `TickerMode.of(context)`
  /// arıyor — ağacı sökülmüş bir elemanın atasına bakmak. Hata mesajı
  /// "Looking up a deactivated widget's ancestor is unsafe" ve sebebi
  /// widget'ın kendisiyle hiç ilgili görünmüyor.
  late final Ticker _ticker;
  StreamSubscription<void>? _watch;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // `NetClient` bir `ChangeNotifier` DEĞİL: ağ katmanının Flutter bilmemesi
    // mimari bir kural (`architecture_test.dart`). Bildirim `dart:async`
    // yayınından geliyor.
    _watch = widget.client.changes.listen((_) => _drain());
  }

  @override
  void dispose() {
    _watch?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  /// Ödül kuyruğunu boşaltıp bildirime çevirir.
  ///
  /// Kuyruk `build` içinde okunmuyor: `takeRewards` durumu DEĞİŞTİRİYOR ve
  /// çizim sırasında durum değiştirmek, Flutter'ın en zor teşhis edilen hata
  /// sınıflarından biri.
  void _drain() {
    final rewards = widget.client.takeRewards();
    final ganimetler = widget.client.takeGanimetler();
    if (rewards.isEmpty && ganimetler.isEmpty) {
      // Bakiye başka bir yoldan değişmiş olabilir (mağazadan alım).
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    setState(() {
      for (final reward in rewards) {
        _toasts.add(_KazancToast(reward.credits, reward.premium));
      }
      // Düşen her eşya kendi satırında: bir boss üç eşya düşürüyor ve üçü
      // farklı rankta olabiliyor; tek satırda "3 eşya" rankı gizlerdi.
      // KARAR 14.1 s1
      for (final ganimet in ganimetler) {
        for (final specId in ganimet.esyalar) {
          final spec = Catalogue.byId[specId];
          if (spec != null) _toasts.add(_EsyaToast(spec));
        }
        if (ganimet.malzeme > 0) {
          final rank = ganimet.malzemeRank.clamp(0, ItemTier.values.length - 1);
          _toasts.add(
            _MalzemeToast(
              Malzeme.forRank(ItemTier.values[rank]),
              ganimet.malzeme,
            ),
          );
        }
      }
      // Üst üste binen imhalarda liste sınırsız büyümesin: ekranda dörtten
      // fazlası zaten okunmuyor. En eskisi düşer; boss'ta o kredi satırı,
      // ve boss'un asıl haberi eşyası.
      while (_toasts.length > 4) {
        _toasts.removeAt(0);
      }
    });
    // Saat YALNIZ sönecek bir şey varken dönüyor. Sürekli açık bir ticker,
    // hiçbir şey olmazken de kare başına bir `setState` demek.
    if (!_ticker.isTicking) _ticker.start();
  }

  Duration _last = Duration.zero;

  void _onTick(Duration elapsed) {
    // Gerçek geçen süre: sabit 1/60 varsaymak, 120 Hz'de yazıyı iki kat
    // yavaş, düşük kare hızında iki kat hızlı söndürürdü.
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_toasts.isEmpty) {
      _ticker.stop();
      _last = Duration.zero;
      return;
    }
    setState(() {
      for (final toast in _toasts) {
        toast.age += dt;
      }
      _toasts.removeWhere((t) => t.age >= t.life);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Balance(
            value: widget.client.credits,
            currency: Currency.credit,
            compact: widget.compact,
          ),
          const SizedBox(width: 12),
          _Balance(
            value: widget.client.premium,
            currency: Currency.premium,
            compact: widget.compact,
          ),
        ],
      ),
      for (final toast in _toasts) ...[
        const SizedBox(height: 4),
        Opacity(
          opacity: toast.opacity,
          child: _ToastRow(toast: toast),
        ),
      ],
    ],
  );
}

/// Sönen bir bildirim satırı: kazanç, düşen eşya ya da malzeme.
sealed class _Toast {
  /// Ekranda kalma süresi (sn). Kısa: bu bir bildirim, bir panel değil.
  double get life;

  double age = 0;

  /// Son üçte birinde soluyor — hemen kaybolan bir yazı okunmuyor, yavaşça
  /// kaybolan bir yazı ise ekranı kirletiyor.
  double get opacity {
    final fade = life / 3;
    if (age <= life - fade) return 1;
    return ((life - age) / fade).clamp(0.0, 1.0);
  }
}

/// Bir imhanın kazancı.
class _KazancToast extends _Toast {
  _KazancToast(this.credits, this.premium);

  @override
  double get life => 2.2;

  final int credits;
  final int premium;
}

/// Düşen bir eşya. Kazançtan uzun kalıyor: on üç dakikada bir gelen haber,
/// iki saniyede sönerse oyuncu başını çevirdiğinde kaçırır.
class _EsyaToast extends _Toast {
  _EsyaToast(this.spec);

  @override
  double get life => 3.4;

  final ItemSpec spec;
}

/// Düşen malzeme — her imhada, kazançla aynı ömürde.
class _MalzemeToast extends _Toast {
  _MalzemeToast(this.malzeme, this.adet);

  @override
  double get life => 2.2;

  final Malzeme malzeme;
  final int adet;
}

class _ToastRow extends StatelessWidget {
  const _ToastRow({required this.toast});

  final _Toast toast;

  @override
  Widget build(BuildContext context) => switch (toast) {
    _KazancToast(:final credits, :final premium) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (credits != 0) _Gain(amount: credits, currency: Currency.credit),
        // NOVA düşmediyse hiç yazılmıyor: her imhada "+0 NOVA" görmek, kıt
        // paranın kıt olduğu bilgisini gürültüye çevirirdi.
        if (premium != 0) ...[
          const SizedBox(width: 8),
          _Gain(amount: premium, currency: Currency.premium),
        ],
      ],
    ),
    // Eşya RANK renginde: rank eşyanın rengidir (10.2) ve oyuncu düşenin
    // değerini adından önce renginden okur. Plakanın paletiyle aynı.
    _EsyaToast(:final spec) => _Dusen(
      key: hudGanimetKey(spec.id),
      metin:
          '${rankEtiketi(spec.tier, context.dil)} '
          '${menuUpper(esyaAdi(spec, context.dil), context.dil)}',
      tier: spec.tier,
    ),
    _MalzemeToast(:final malzeme, :final adet) => _Dusen(
      key: hudGanimetKey(malzeme.id),
      metin: '+$adet ${menuUpper(malzemeAdi(malzeme, context.dil), context.dil)}',
      tier: malzeme.rank,
    ),
  };
}

/// Düşen bir şey: rank renginde nokta ve ad.
class _Dusen extends StatelessWidget {
  const _Dusen({required this.metin, required this.tier, super.key});

  final String metin;
  final ItemTier tier;

  @override
  Widget build(BuildContext context) {
    final gorsel = RankGorseli.of(tier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: gorsel.taban,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gorsel.taban.withValues(alpha: 0.7),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          metin,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: gorsel.acik,
          ),
        ),
      ],
    );
  }
}

/// HUD'daki bir ganimet satırı — katalog ya da malzeme kimliğiyle.
Key hudGanimetKey(String id) => Key('hud-ganimet-$id');

class _Gain extends StatelessWidget {
  const _Gain({required this.amount, required this.currency});

  final int amount;
  final Currency currency;

  @override
  Widget build(BuildContext context) => Text(
    // Tamir bedeli aynı yoldan geliyor ve EKSİ: işareti gizlemek, oyuncuya
    // para kaybettiğini kazanç gibi göstermek olurdu.
    '${amount >= 0 ? '+' : '−'}${bicim.sayi(amount.abs(), context.dil)}',
    style: TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: amount >= 0 ? hudCurrencyColor(currency) : Palette.danger,
    ),
  );
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.value,
    required this.currency,
    required this.compact,
  });

  final int value;
  final Currency currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = hudCurrencyColor(currency);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        if (!compact) ...[
          Text(
            paraAdi(currency, context.dil),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1,
              color: Palette.inkDim,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          bicim.sayi(value, context.dil),
          key: hudBalanceKey(currency),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// HUD'daki bir bakiye — testler metni değil bunu arıyor.
Key hudBalanceKey(Currency currency) => Key('hud-balance-${currency.key}');

/// Menüdeki `currencyColor` ile AYNI eşleme.
///
/// HUD `lib/hangar`'ı içeri alamaz (menü, oyun ekranının parçası değil), o
/// yüzden eşleme iki yerde duruyor. `test/economy_test.dart` ikisinin
/// ayrışmadığını doğruluyor: aynı paranın iki ekranda iki renk olması,
/// oyuncunun neye baktığını karıştırması demek.
Color hudCurrencyColor(Currency currency) => switch (currency) {
  Currency.credit => Palette.boost,
  Currency.premium => Palette.slotLauncher,
};
