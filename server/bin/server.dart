import 'dart:io';

import 'package:voidspace_core/voidspace_core.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/hangars.dart';
import 'package:voidspace_server/zone.dart';

/// Otorite sunucusu.
///
/// Kalıcı verinin yolu üç çevre değişkeniyle taşınabilir — `ACCOUNTS`,
/// `HANGARS`, `LEDGER` — ama bunları burası değil depoların kendisi okuyor
/// (`VeriYolu`), çünkü depoyu kuran tek yer burası değil.
///
/// ```bash
/// ALIENS=50 dart run server/bin/server.dart          # 50 alienli harita
/// dart run server/bin/server.dart                    # yalnız oyun
/// WEB_ROOT=build/web dart run server/bin/server.dart # oyun + istemci
/// TLS_CERT=cert.pem TLS_KEY=key.pem dart run server/bin/server.dart # wss://
/// dart compile exe server/bin/server.dart            # üretim (AOT)
/// ```
Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final host = Platform.environment['HOST'] ?? '0.0.0.0';

  // Haritadaki alien sayısı. Ayarlanabilir olması denemek içindir: yirmiyle
  // elli arasındaki fark ölçülmeden bilinmiyor.
  final aliens = int.tryParse(Platform.environment['ALIENS'] ?? '');

  // Zone kapasitesi. Ayarlanabilir olması ÖLÇÜM içindir: "200 gemi ne yapar"
  // sorusunun cevabı kodu değiştirmeden alınabilmeli. Varsayılan 64 kalıyor —
  // tavanı kaldırmak bir karar, bir yan etki değil.
  // Kelepçe `assert` DEĞİL: `assert` sürüm derlemesinde çalışmıyor ve bu değer
  // dışarıdan, ortamdan geliyor — yani korumanın gerektiği tek yer tam burası.
  // Kimlik uzayını aşan bir kapasite, gemilere alien kimliği dağıtır.
  final capacity = int.tryParse(
    Platform.environment['CAPACITY'] ?? '',
  )?.clamp(1, Protocol.maxShipId);

  // WEB_ROOT verilirse sunucu istemciyi de sunar — ve kritik olan, onu
  // Skwasm'ın ihtiyaç duyduğu çapraz köken izolasyonu başlıklarıyla sunar.
  // Hesap deposu. `ACCOUNTS` ile ayrı bir dosya verilebilir — yük testinin
  // botları gerçek oyuncuların yanına yazılmasın diye.
  //
  // Çevre değişkenini artık BURASI okumuyor, deponun kendisi okuyor
  // (`VeriYolu`). Buradan okunması, yolun giriş noktasına göre değişmesi
  // demekti: sunucudan geçen yol `ACCOUNTS`'a uyuyor, `Gateway`'in kendi
  // varsayılanından geçen yol uymuyordu — ve testler tam o ikinci yoldan
  // geçtiği için üretim dosyasına yazıyorlardı. Varsayılan DEĞİŞMEDİ:
  // çevre verilmemişse yine `data/accounts.json`.
  final accounts = AccountStore();
  await accounts.load();
  stdout.writeln('${accounts.count} hesap yüklendi');

  // Hangarlar: para, gemiler, envanter, donatım. Hesaplardan AYRI dosya —
  // biri kimlik, öteki ilerleme; ayrı hızlarda değişiyorlar ve ayrı
  // yedeklenmeleri gerekiyor.
  final hangars = HangarStore();
  await hangars.load();
  stdout.writeln('${hangars.count} hangar yüklendi');

  // Hata ayıklama komutları (`HASAR / ONAR`) ÜRETİMDE KAPALI.
  //
  // `ONAR` ölü bir gemiyi tam sağlıkla geri getiriyor ve bunu istemcinin
  // arayüzünden değil doğrudan protokolden yapmak mümkün. Açmak için bilinçli
  // bir çevre değişkeni gerekiyor; unutulup açık kalmasın diye varsayılan
  // "kapalı" ve açıldığında sunucu bunu ekrana basıyor.
  final debugCommands = Platform.environment['DEBUG_COMMANDS'] == 'true';

  // GELİŞTİRME kolaylığı: virgülle ayrılmış kullanıcı adları zengin başlar.
  //
  // Kod içinde bir isim listesi YOK ve olmamalı: "şu kullanıcının parası
  // yüksek olsun" isteğinin en kısa cevabı bir `if` yazmaktı ve o satır
  // üretime bir arka kapı olarak derlenirdi.
  final devRich = (Platform.environment['DEV_RICH'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  if (debugCommands) {
    stdout.writeln('⚠ hata ayıklama komutları AÇIK — üretimde kapatın');
  }
  final devFull = (Platform.environment['DEV_FULL'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  if (devFull.isNotEmpty) {
    stdout.writeln(
      '⚠ DEV_FULL AÇIK (${devFull.join(", ")}) — bu hesaplar TAM DONANIMLI '
      'başlıyor. ÜRETİMDE TANIMLAMAYIN.',
    );
  }
  if (devRich.isNotEmpty) {
    stdout.writeln(
      '⚠ DEV_RICH AÇIK (${devRich.join(", ")}) — bu hesaplar zengin '
      'başlıyor. ÜRETİMDE TANIMLAMAYIN.',
    );
  }

  final gateway = Gateway(
    accounts: accounts,
    hangars: hangars,
    allowDebugCommands: debugCommands,
    devRichAccounts: devRich,
    devFullAccounts: devFull,
    maxSessionsPerIp:
        int.tryParse(Platform.environment['MAX_PER_IP'] ?? '') ?? 64,
    webRoot: Platform.environment['WEB_ROOT'],
    zone: aliens == null && capacity == null
        ? null
        : Zone(alienCount: aliens ?? 36, capacity: capacity ?? 64),
  );
  // TLS sertifikası verilmişse `wss://`, verilmemişse düz `ws://`.
  //
  // Varsayılan olarak KAPALI olması kasıtlı: geliştirmede sertifika üretmeye
  // zorlamak, herkesin ilk iş kendi kendine imzalı bir sertifika üretip
  // doğrulamayı kapatmasına yol açar — yani TLS'i açıp güvenliği kapatmaya.
  final cert = Platform.environment['TLS_CERT'];
  final key = Platform.environment['TLS_KEY'];
  if ((cert == null) != (key == null)) {
    stderr.writeln('TLS_CERT ve TLS_KEY birlikte verilmeli');
    exit(2);
  }

  await gateway.start(
    host: host,
    port: port,
    certificatePath: cert,
    keyPath: key,
  );

  // Konteynerde SIGTERM tek kapanış sinyalidir; yakalamamak, oturumları
  // yarıda kesip istemcileri zaman aşımına bırakmak demek.
  //
  // Yorum bunu söylüyordu ama kod yalnız SIGINT'i dinliyordu — yani düzgün
  // kapanış tam da en çok gerektiği yerde, konteynerde, hiç çalışmıyordu.
  // `docker stop` SIGTERM yollar; SIGINT yalnız terminalde Ctrl-C ile gelir.
  Future<void> shutdown() async {
    stdout.writeln('\nkapanıyor…');
    await gateway.stop();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  ProcessSignal.sigterm.watch().listen((_) => shutdown());
}
