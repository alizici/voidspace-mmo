import 'dart:io';

import 'package:voidspace_server/lag_proxy.dart';

/// Gecikme vekilinin komut satırı sarmalayıcısı.
///
/// ```bash
/// # 8080'deki sunucuyu 8081'de +160 ms RTT ve ±40 ms titreşimle yayınla
/// LAG_MS=160 JITTER_MS=40 UPSTREAM=8080 PORT=8081 \
///   dart run server/bin/lagproxy.dart
/// ```
Future<void> main() async {
  final proxy = LagProxy(
    upstreamPort: int.tryParse(Platform.environment['UPSTREAM'] ?? '') ?? 8080,
    upstreamHost: Platform.environment['UPSTREAM_HOST'] ?? '127.0.0.1',
    rttMs: int.tryParse(Platform.environment['LAG_MS'] ?? '') ?? 120,
    jitterMs: int.tryParse(Platform.environment['JITTER_MS'] ?? '') ?? 0,
    loss: double.tryParse(Platform.environment['LOSS'] ?? '') ?? 0,
  );
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8081;
  await proxy.start(host: '0.0.0.0', port: port);
  stdout.writeln(
    'gecikme vekili · ws://0.0.0.0:${proxy.port} → '
    '${proxy.upstreamHost}:${proxy.upstreamPort} · '
    'RTT +${proxy.rttMs} ms · titreşim ±${proxy.jitterMs} ms · '
    'kayıp %${(proxy.loss * 100).round()}',
  );
}
