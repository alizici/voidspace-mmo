@Tags(['disi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/zone.dart';

/// META YAYINI — hangarda değişen şey dünyaya ANINDA yansır.
///
/// Bulunan hata: oyuncu formasyon seçiyor ya da filoya droid alıyor, ekranda
/// hiçbir şey olmuyor; geçitten geçince (ışınlanınca) düzeliyor, çünkü o yol
/// meta'yı yeniden yolluyor. Sebep: donatım uygulanınca meta yalnız NAMLU
/// SAYISI değiştiyse yayınlanıyordu; formasyon ve filo aynı yoldan geçiyor
/// ama namluya dokunmuyor. Ölçü artık meta'nın tamamı.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('voidspace_meta'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<(Gateway, WebSocket, List<Uint8List>, Account)> kur() async {
    final gateway = Gateway(
      zone: Zone(alienCount: 0),
      accounts: AccountStore(path: '${temp.path}/a.json'),
    );
    await gateway.start(host: '127.0.0.1', port: 0);
    addTearDown(gateway.stop);

    final socket = await WebSocket.connect('ws://127.0.0.1:${gateway.port}');
    final account = await gateway.accounts.register(
      email: 'ada@test.local',
      username: 'Ada',
      password: 'yeterince-uzun-parola',
    );
    final gelen = <Uint8List>[];
    socket.listen(
      (d) => gelen.add(Uint8List.fromList(d as List<int>)),
      onError: (_) {},
      onDone: () {},
    );
    socket.add(
      ClientHello(
        protocolVersion: Protocol.version,
        token: gateway.accounts.issueToken(account),
      ).encode(),
    );
    await _until(() => gateway.zone.ships.isNotEmpty);
    return (gateway, socket, gelen, account);
  }

  /// Gelen paketlerdeki, [id]'li geminin meta kayıtları — sırayla.
  List<ServerEntityMeta> metalar(List<Uint8List> gelen, int id) => [
    for (final b in gelen)
      if (b.isNotEmpty && b[0] == Protocol.msgEntityMeta)
        if (ServerMessage.decode(b) case ServerEntityMeta(:final id) && final m
            when id == id)
          m,
  ];

  bool hangarDurumuGeldi(List<Uint8List> gelen) => gelen.any(
    (b) => b.isNotEmpty && ServerMessage.decode(b) is ServerHangarState,
  );

  test('formasyon seçince meta ANINDA geliyor — geçit beklemeden', () async {
    final (gateway, socket, gelen, hesap) = await kur();
    final kimlik = gateway.zone.ships.keys.single;
    const secim = 3;
    // Formasyon NOVA rafından (15.9): seçilebilmesi için önce sahiplenmeli.
    gateway.hangars.of(hesap.id).formasyonEkle(Formasyon.hepsi[secim].id);
    gelen.clear();

    socket.add(
      ClientHangar(
        action: 'formasyon',
        payload: {'id': Formasyon.hepsi[secim].id},
      ).encode(),
    );
    await _until(() => metalar(gelen, kimlik).any((m) => m.formasyon == secim));
  });

  test('filoya alıp çıkarınca droid sayısı meta\'da değişiyor', () async {
    final (gateway, socket, gelen, account) = await kur();
    final kimlik = gateway.zone.ships.keys.single;
    // Droid kapısı rank indeksi üçte (10.7): bir B-I eşya kapıyı açıyor.
    gateway.hangars.of(account.id)
      ..addItem(const ItemInstance(instanceId: 'kapi-pl5', specId: 'pl5'))
      ..addItem(const ItemInstance(instanceId: 'filo-dr1', specId: 'dr1'));
    gelen.clear();

    socket.add(
      const ClientHangar(
        action: 'filo_al',
        payload: {'instanceId': 'filo-dr1'},
      ).encode(),
    );
    await _until(
      () => metalar(gelen, kimlik).any((m) => m.droidler.length == 1),
    );
    gelen.clear();

    socket.add(
      const ClientHangar(
        action: 'filo_cikar',
        payload: {'instanceId': 'filo-dr1'},
      ).encode(),
    );
    await _until(() => metalar(gelen, kimlik).any((m) => m.droidler.isEmpty));
  });

  test(
    'değişmeyen meta YOLLANMIYOR — aynı formasyonu yeniden seçmek',
    () async {
      // Yayın "her hangar tıklaması" değil "meta değişti" demek: menüde
      // gezinen tek oyuncu bütün kadroya paket göndermemeli.
      final (gateway, socket, gelen, hesap) = await kur();
      final kimlik = gateway.zone.ships.keys.single;
      final secim = Formasyon.hepsi[2].id;
      // Sahiplenmeden seçilemiyor (15.9).
      gateway.hangars.of(hesap.id).formasyonEkle(secim);
      socket.add(
        ClientHangar(action: 'formasyon', payload: {'id': secim}).encode(),
      );
      await _until(() => metalar(gelen, kimlik).any((m) => m.formasyon == 2));
      gelen.clear();

      socket.add(
        ClientHangar(action: 'formasyon', payload: {'id': secim}).encode(),
      );
      await _until(() => hangarDurumuGeldi(gelen));
      expect(
        metalar(gelen, kimlik),
        isEmpty,
        reason: 'değişmeyen meta yollandı',
      );
    },
  );
}

Future<void> _until(bool Function() ready, {Duration? timeout}) async {
  final limit = timeout ?? const Duration(seconds: 5);
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > limit) throw StateError('koşul gerçekleşmedi');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
