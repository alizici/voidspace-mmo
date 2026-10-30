@Tags(['disi'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidspace3/net/net_phase.dart';
import 'package:voidspace3/ship/ship_bloc.dart';
import 'package:voidspace3/ship/ship_event.dart';
import 'package:voidspace3/ship/ship_state.dart';
import 'package:voidspace_core/voidspace_core.dart';

/// HUD'a giden durumun REPLİKASYON sözleşmesi.
///
/// Bu dosya eskiden hasar emilimini, kalkan yenilenmesini ve itki şarjını
/// test ediyordu. Hepsi `packages/voidspace_core/test/ship_sim_test.dart`'a
/// taşındı — çünkü artık istemci onları hesaplamıyor, sunucu hesaplıyor.
/// Geriye kalan ve burada kilitlenen şey daha dar ama daha önemli: yansıtma
/// doğru mu, ve HUD boşuna yeniden kuruluyor mu.
void main() {
  const stats = ShipStats.bastion;
  const world = GameWorld.standard;

  ShipSynced sync(ShipSimState state) =>
      ShipSynced(phase: NetPhase.playing, state: state, pingMs: 42, nearby: 3);

  blocTest<ShipBloc, ShipState>(
    'sunucudan gelen durumu yansıtır',
    build: ShipBloc.new,
    act: (bloc) => bloc.add(
      sync(ShipSim.applyDamage(ShipSimState.spawn(stats, world.centre), 2600)),
    ),
    verify: (bloc) {
      expect(bloc.state.shield, stats.maxShield - 2600);
      expect(bloc.state.hull, stats.maxHull);
      expect(bloc.state.pingMs, 42);
      expect(bloc.state.nearby, 3);
      expect(bloc.state.online, isTrue);
    },
  );

  test('DEĞİŞMEYEN durum yeniden yayınlanmaz (HUD boşuna kurulmaz)', () async {
    // Oyun döngüsü 10 Hz senkron yolluyor. Boşta duran bir gemi saniyede 10
    // HUD kurulumuna yol açarsa, bu mimarinin en bilinen çöp üretme biçimini
    // ağ katmanı üzerinden geri getirmiş oluruz.
    final bloc = ShipBloc();
    addTearDown(bloc.close);
    var emissions = 0;
    final sub = bloc.stream.listen((_) => emissions++);

    final idle = ShipSimState.spawn(stats, world.centre);
    for (var i = 0; i < 60; i++) {
      bloc.add(sync(idle));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    // 1 taban: `Bloc.emit` ilk yayını eşit olsa da geçirir (`_emitted`).
    // Önemli olan 60 senkronun 60 yayın ÜRETMEMESİ.
    expect(
      emissions,
      lessThanOrEqualTo(1),
      reason: 'değişmeyen durum yayınlanıyor → HUD boşuna kuruluyor',
    );
  });

  blocTest<ShipBloc, ShipState>(
    'bağlantı koptuğunda havuzlar KORUNUR',
    build: ShipBloc.new,
    act: (bloc) => bloc
      ..add(
        sync(
          ShipSim.applyDamage(ShipSimState.spawn(stats, world.centre), 5000),
        ),
      )
      ..add(const ShipSynced(phase: NetPhase.disconnected, message: 'koptu')),
    verify: (bloc) {
      // Sıfırlamak, geçici bir kopmada oyuncuya "öldün" demek olurdu —
      // sunucudaki gemi ise yaşamaya devam ediyor.
      expect(bloc.state.shield, stats.maxShield - 5000);
      expect(bloc.state.online, isFalse);
      expect(bloc.state.message, 'koptu');
      expect(bloc.state.pingMs, 0, reason: 'kopukken ping anlamsız');
    },
  );

  blocTest<ShipBloc, ShipState>(
    'red sebebi HUD\'a ulaşır',
    build: ShipBloc.new,
    act: (bloc) => bloc.add(
      const ShipSynced(phase: NetPhase.rejected, message: 'sunucu dolu'),
    ),
    verify: (bloc) {
      expect(bloc.state.phase, NetPhase.rejected);
      expect(bloc.state.message, 'sunucu dolu');
    },
  );
}
