import 'dart:math' as math;

import '../domain/vec2.dart';
import '../domain/world.dart';
import 'ship_input.dart';
import 'ship_sim_state.dart';

/// Geminin BİR simülasyon adımı. Saf: aynı girdi daima aynı çıktıyı verir.
///
/// Oyunun tamamındaki tek hareket ve havuz matematiği burada. Sunucu bunu
/// otorite olarak koşar, istemci de gecikmeyi gizlemek için AYNI fonksiyonla
/// önceden oynatır. Kod iki yerde olsaydı ikisi kaçınılmaz olarak ayrışırdı;
/// tek yerde olduğu için ayrışamaz.
///
/// **Neden sabit adım?** Değişken `dt` (kare süresi) ile `pos += v * dt`
/// sonucu makineye ve kare hızına bağlı olur — o zaman geri sarıp yeniden
/// oynatmak farklı bir sonuç üretir ve mutabakat işe yaramaz. [fixedDt] ile
/// yeniden oynatma birebir aynı yolu izler.
///
/// **Sınır:** `sin`/`cos`/`atan2` platformun libm'inden gelir; JS ile native
/// son bitte ayrışabilir. Bu KİLİTLİ ADIM (lockstep) bir oyun değil — her
/// snapshot'ta sunucu durumu yeniden çivilendiği için sapmanın birikecek
/// zamanı yok. Gereken şey "iki düzeltme arasında yeterince yakın", "bit
/// düzeyinde aynı" değil.
abstract final class ShipSim {
  /// Otorite tik hızı. Tıkla-git ve takipli ışın için 30 Hz fazlasıyla yeterli;
  /// 60 Hz iki kat CPU ve iki kat girdi trafiği demek olurdu.
  static const int tickRate = 30;

  /// Her adımın DEĞİŞMEZ süresi. Yeniden oynatmanın doğru çalışmasının şartı.
  static const double fixedDt = 1 / tickRate;

  /// Varışta yön 180° dönüp titremesin diye eşik ADIM kadardır (sabit küçük
  /// bir eşik kullanılırsa gemi eşiğin içine hiç giremez ve hedefin çevresinde
  /// sonsuza dek salınır).
  static const double turnRate = 7;

  /// Nişanın ANLAMLI olduğu en kısa mesafe.
  ///
  /// Bundan yakın bir hedefe dönmek, sıfıra yakın bir vektörün açısını sormak
  /// demek: sonuç gürültü, gemi titrer. Sayı iki yerde okunuyor — burada
  /// dönüş, `zone.dart`'ta ateşin nişan yayı — ve tek yerde durmak zorunda:
  /// dönüşün atladığı bir mesafede yay sınanırsa gemi ne döner ne ateş eder,
  /// yani kilitlenir.
  static const double nisanEsigi = 1;

  /// İtki rampasının yakınsama hızı. Anlık açıp kapatmak alevi çırpıştırır.
  static const double thrustRamp = 6;

  static ShipSimState step(
    ShipSimState s,
    ShipInput input,
    GameWorld world, [
    double dt = fixedDt,
  ]) {
    final stats = s.stats;

    // ── Ayrık zamanlayıcılar ───────────────────────────────────────────
    var boostRemaining = (s.boostRemaining - dt).clamp(0.0, double.infinity);
    // Gecikmede TAVANLA: sayaç sonsuza kadar büyümesin ve boştaki gemi her
    // tikte YENİ bir durum üretmesin (HUD'ın boşta yeniden kurulmamasının
    // sebebi bu tavan).
    final sinceHit = (s.sinceHit + dt).clamp(0.0, stats.shieldRegenDelay);

    // Kalkan yalnız gecikme dolduktan SONRA yenilenir; imha edilmiş gemi hiç
    // yenilenmez.
    var shield = s.shield;
    if (s.alive && sinceHit >= stats.shieldRegenDelay) {
      shield = (shield + stats.shieldRegenPerSecond * dt).clamp(
        0.0,
        stats.maxShield,
      );
    }

    // İtki şarjı: teker teker dolar, sayaç yalnız eksik şarj varken işler.
    var charges = s.boostCharges;
    var recharge = s.rechargeElapsed;
    if (charges < stats.maxBoostCharges) {
      recharge += dt;
      while (recharge >= stats.boostRecharge &&
          charges < stats.maxBoostCharges) {
        recharge -= stats.boostRecharge;
        charges++;
      }
      if (charges >= stats.maxBoostCharges) recharge = 0;
    }

    // İtki isteği zamanlayıcılardan SONRA: aynı tikte dolan bir şarj hemen
    // harcanabilsin.
    final wantsBoost = input.boost;
    final canBoost = s.alive && boostRemaining <= 0 && charges > 0;
    if (wantsBoost && canBoost) {
      charges -= 1;
      boostRemaining = stats.boostDuration;
    }

    // Silah niyeti duruma geçer. ÇÖZÜMÜ burada değil `Zone`'da: bir atış iki
    // gemi arasındaki etkileşimdir, bu fonksiyon ise tek gemiyi izole işler.
    // Menzil ve hasarı burada hesaplamak, saf adımın diğer gemileri görmesini
    // gerektirirdi — ve o kapı açıldığında determinizm biter.
    final weaponTarget = input.weaponTarget;
    final firing = input.firing && s.alive && weaponTarget != 0;

    // ── Ölü gemi uçmaz ─────────────────────────────────────────────────
    if (!s.alive) {
      return s.copyWith(
        clearTarget: true,
        weaponTarget: 0,
        firing: false,
        clearAim: true,
        thrust: _approach(s.thrust, 0, dt),
        shield: shield,
        boostCharges: charges,
        boostRemaining: boostRemaining,
        rechargeElapsed: recharge,
        sinceHit: sinceHit,
      );
    }

    // ── Hareket ────────────────────────────────────────────────────────
    final boosting = boostRemaining > 0;
    final speed = stats.speed * (boosting ? stats.boostFactor : 1);

    // Komut önce uygulanır, sonra klavye onu ezebilir — "klavye tıkla-git
    // hedefini ezer" kuralı bu sıralamadan doğar, ayrı bir dal değil.
    var target = input.moveTarget != null
        ? world.clamp(input.moveTarget!)
        : s.target;
    var position = s.position;
    Vec2? heading;

    if (!input.axis.isZero) {
      target = null;
      heading = input.axis.normalized();
      position += heading * (speed * dt);
    } else if (target != null) {
      final toTarget = target - position;
      final distance = toTarget.length;
      final step = speed * dt;
      if (distance <= step) {
        position = target; // tam hedefe otur ve DUR
        target = null;
      } else {
        heading = toTarget / distance;
        position += heading * step;
      }
    }

    // Sınır hareketi ENGELLEMEZ, yalnız sonucunu kelepçeler.
    position = world.clamp(position);

    // ── Yönelim ────────────────────────────────────────────────────────
    //
    // ÖNCELİK NİŞANDA. Kilitli bir hedef varsa gemi, yanından geçerken bile
    // ona bakar; namluların hedeften başka bir yöne dönmesi, silahların
    // gövdedeki yerinin anlamını bitirirdi.
    //
    // Hedef yoksa hareket yönüne döner. İki durumda da YUMUŞAK: kilit
    // düştüğünde gemi ani bir sıçramayla değil, dönerek serbest kalır.
    final aim = s.aimPoint;
    final Vec2? facing;
    if (aim != null) {
      final toAim = aim - position;
      // Üstünde durduğun hedefe dönmeye çalışmak, sıfıra yakın bir vektörün
      // açısını sormak demek: sonuç gürültü olur ve gemi titrer.
      facing = toAim.length > nisanEsigi ? toAim : null;
    } else {
      facing = heading;
    }
    final angle = facing == null
        ? s.angle
        : _turnToward(s.angle, math.atan2(facing.x, -facing.y), dt);

    final wantedThrust = heading == null ? 0.0 : (boosting ? 1.0 : 0.72);

    return ShipSimState(
      stats: stats,
      position: position,
      angle: angle,
      thrust: _approach(s.thrust, wantedThrust, dt),
      target: target,
      hull: s.hull,
      shield: shield,
      boostCharges: charges,
      boostRemaining: boostRemaining,
      rechargeElapsed: recharge,
      sinceHit: sinceHit,
      weaponTarget: weaponTarget,
      firing: firing,
      aimPoint: s.aimPoint,
    );
  }

  /// Hasar uygula. YALNIZ sunucu çağırır.
  ///
  /// Kalkan önce emer; TAŞAN kısım gövdeye iner. Tek vuruşta kalkanı bitirip
  /// gövdeye de vurabilmek, kalkanın "ekstra can" değil tampon olmasını sağlar.
  /// KARAR 01.3 s1
  static ShipSimState applyDamage(ShipSimState s, double amount) {
    if (!s.alive || amount <= 0) return s;
    final absorbed = amount.clamp(0.0, s.shield);
    final overflow = amount - absorbed;
    return s.copyWith(
      shield: s.shield - absorbed,
      hull: (s.hull - overflow).clamp(0.0, s.stats.maxHull),
      sinceHit: 0,
    );
  }

  /// YALNIZ KALKANA hasar — sifon mermisi (17.6). Kalkanı aşan pay gövdeye
  /// taşmaz, yok olur: sifon tek başına öldüremez, dövüşün ilk yarısını
  /// kazandırır.
  /// KARAR 17.6 s1
  static ShipSimState applyShieldDamage(ShipSimState s, double amount) {
    if (!s.alive || amount <= 0) return s;
    final absorbed = amount.clamp(0.0, s.shield);
    return s.copyWith(shield: s.shield - absorbed, sinceHit: 0);
  }

  /// Tam onarım (üs / test).
  static ShipSimState repair(ShipSimState s) =>
      ShipSimState.spawn(s.stats, s.position).copyWith(angle: s.angle);

  /// En kısa açı farkı üzerinden yumuşak dönüş — 180°'lik hedef değişiminde
  /// gövdenin tek karede ters yüz olmasını engeller.
  ///
  /// Sonuç [-π, π]'ye sarılır: açı sonsuza kadar büyürse `uint8` kuantalaması
  /// hassasiyet kaybetmeye başlar.
  static double _turnToward(double angle, double wanted, double dt) {
    final delta = math.atan2(
      math.sin(wanted - angle),
      math.cos(wanted - angle),
    );
    return normalizeAngle(angle + delta * math.min(1, dt * turnRate));
  }

  static double _approach(double value, double wanted, double dt) =>
      value + (wanted - value) * math.min(1, dt * thrustRamp);

  /// Açıyı [-π, π] aralığına sarar.
  static double normalizeAngle(double a) {
    final wrapped = (a + math.pi) % (2 * math.pi);
    return (wrapped < 0 ? wrapped + 2 * math.pi : wrapped) - math.pi;
  }
}
