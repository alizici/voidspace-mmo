@Tags(['disi'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:voidspace_server/accounts.dart';
import 'package:voidspace_server/gateway.dart';
import 'package:voidspace_server/hangars.dart';
import 'package:voidspace_server/ledger_store.dart';
import 'package:voidspace_server/veri_yolu.dart';

/// Testin ÜRETİM verisine yazamaması.
///
/// Bu dosyanın koruduğu şey bir davranış değil, bir KAZA sınıfı. Olan şuydu:
/// `Gateway({accounts, hangars, ledger})` üçünü de isteğe bağlı tutuyor,
/// vermeyene kendi varsayılanını veriyordu ve o varsayılan üretim dosyasıydı.
/// `server/test/` altındaki on altı dosya `Gateway` kuruyor; hepsi `accounts:`
/// için geçici bir yol veriyor, hiçbiri `hangars:`/`ledger:` vermiyordu. Yani
/// koruma "yolu vermeyi hatırlamak"tan ibaretti ve tam da hatırlanmadığı için
/// kullanıcının gerçek `data/hangars.jsonl` dosyasına test kaydı düştü.
///
/// Buradaki testlerin hepsi tek bir cümlenin yüzleri: **koşucunun altında
/// üretim dosyasına giden bir yol üretilemez.**
void main() {
  test('koruma AÇIK — koşucu saptandı', () {
    // Bu sınama olmasaydı aşağıdaki her şey BOŞA geçebilirdi: koşucu
    // saptanmadığında varsayılan üretim yoluna döner ve "geçici dizinde"
    // diyen bir sınama sessizce yanlış olur. Önce saptamanın kendisi.
    expect(
      VeriYolu.testKosuyor,
      isTrue,
      reason: 'koşucu saptanamadı — koruma devrede değil, sızıntı geri döndü',
    );
  });

  test('ÜRETİM yolları olduğu gibi duruyor', () {
    // Korumayı "üretim sabitini geçici bir yola çevirerek" kurmak da mümkündü
    // ve testler yine yeşil kalırdı — ama sunucu artık hiçbir şeyi
    // hatırlamazdı. Sabitler bu yüzden ayrıca kilitleniyor.
    expect(VeriYolu.hangarlar, 'data/hangars.jsonl');
    expect(VeriYolu.defter, 'data/ledger.jsonl');
    expect(VeriYolu.hesaplar, 'data/accounts.json');
  });

  group('varsayılan yol', () {
    test('üç deponun hiçbiri üretim dosyasını göstermiyor', () {
      for (final (ad, yol, uretim) in [
        ('hangar', HangarStore().path, VeriYolu.hangarlar),
        ('defter', LedgerStore().path, VeriYolu.defter),
        ('hesap', AccountStore().path, VeriYolu.hesaplar),
      ]) {
        expect(yol, isNot(uretim), reason: '$ad üretim yolunu gösteriyor');
        expect(
          File(yol).absolute.path,
          isNot(File(uretim).absolute.path),
          reason: '$ad üretim dosyasını gösteriyor',
        );
        expect(
          yol,
          startsWith(Directory.systemTemp.path),
          reason: '$ad geçici dizinin dışına düşüyor',
        );
      }
    });

    test('GATEWAY kendi kurduğu depolarda da üretime yazamıyor', () {
      // Kusurun bire bir kaydı: `hangars:`/`ledger:` verilmeyen bir Gateway.
      // On altı test dosyası tam olarak böyle kuruyordu.
      final gateway = Gateway();
      expect(
        File(gateway.hangars.path).absolute.path,
        isNot(File(VeriYolu.hangarlar).absolute.path),
      );
      expect(
        File(gateway.ledger.path).absolute.path,
        isNot(File(VeriYolu.defter).absolute.path),
      );
      expect(
        File(gateway.accounts.path).absolute.path,
        isNot(File(VeriYolu.hesaplar).absolute.path),
      );
    });

    test('SÜREÇ boyunca aynı kalıyor', () {
      // Çağrı başına yeni bir dizin üretilseydi, yazıp sonra yeni bir depoyla
      // geri okuyan bir test kendi yazdığını bulamazdı.
      expect(HangarStore().path, HangarStore().path);
      expect(LedgerStore().path, LedgerStore().path);
    });

    test('gerçekten YAZILABİLİR ve yazılan yer geçici dizin', () async {
      // Yolun doğru olması yetmez; yönlendirilen yol çalışan bir yol olmalı,
      // yoksa on altı test dosyası yeşil kalmazdı.
      final store = LedgerStore();
      expect(File(store.path).parent.existsSync(), isTrue);
      await store.flush(); // boş kuyruk: patlamamalı
      expect(
        File(VeriYolu.defter).absolute.path,
        isNot(File(store.path).absolute.path),
      );
    });
  });

  group('açık yol', () {
    test('geçici bir yol OLDUĞU GİBİ kullanılıyor', () {
      final dir = Directory.systemTemp.createTempSync('voidspace_acik_yol');
      addTearDown(() => dir.deleteSync(recursive: true));
      final yol = '${dir.path}/h.jsonl';
      expect(HangarStore(path: yol).path, yol);
      expect(LedgerStore(path: yol).path, yol);
      expect(AccountStore(path: yol).path, yol);
    });

    test('ÜRETİM yolu açıkça istenirse REDDEDİLİYOR', () {
      // Varsayılanda yönlendirme, açık istekte ret. Ayrım niyette: yolu
      // vermeyen kişi bir şey söylemiyor, üretim yolunu yazan kişi
      // söylüyor — ve söylediği şey testte her zaman bir hata.
      expect(
        () => HangarStore(path: VeriYolu.hangarlar),
        throwsA(isA<StateError>()),
      );
      expect(
        () => LedgerStore(path: VeriYolu.defter),
        throwsA(isA<StateError>()),
      );
      expect(
        () => AccountStore(path: VeriYolu.hesaplar),
        throwsA(isA<StateError>()),
      );
    });

    test('MUTLAK ve dolambaçlı yazılışı da REDDEDİLİYOR', () {
      // Yol karşılaştırması metin değil DOSYA üstünden: üretim yolu göreli
      // ve testler `server/` dizininden koşuyor, yani aynı dosyayı gösteren
      // sonsuz yazılış var. Sızıntının bir kısmı `server/data/`, bir kısmı
      // kök `data/` altına düşmüştü — tam olarak bu yüzden.
      final mutlak = File(VeriYolu.hangarlar).absolute.path;
      expect(() => HangarStore(path: mutlak), throwsA(isA<StateError>()));
      expect(
        () => HangarStore(path: './${VeriYolu.hangarlar}'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => HangarStore(path: 'data/../${VeriYolu.hangarlar}'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('öncelik', () {
    // Çevre değişkenini süreç içinden kuramıyoruz (`Platform.environment` salt
    // okunur) ve bunun için bir alt süreç açmak, kuralı bir kez daha yazıp
    // saniyeler harcamak olurdu. Onun yerine ZATEN VAR OLAN bir değişken
    // kullanılıyor: `belirle` hangi ismi verirsek onu okuyor, yani okuduğu
    // ismin `HANGARS` mi `PATH` mi olduğu mantık açısından fark etmiyor.
    final mevcut = Platform.environment.containsKey('PATH') ? 'PATH' : 'HOME';

    test('ÇEVRE varsayılanı geçersiz kılıyor', () {
      expect(
        VeriYolu.belirle(
          null,
          uretim: 'data/olmayan-dosya.jsonl',
          cevre: mevcut,
        ),
        Platform.environment[mevcut],
        reason: 'çevre değişkeni okunmuyor — belgelenen geçersiz kılma ölü',
      );
    });

    test('AÇIK yol çevreyi de geçersiz kılıyor', () {
      expect(
        VeriYolu.belirle(
          '/tmp/acik.jsonl',
          uretim: 'data/olmayan-dosya.jsonl',
          cevre: mevcut,
        ),
        '/tmp/acik.jsonl',
      );
    });

    test('tanımsız çevre değişkeni varsayılana düşüyor', () {
      final yol = VeriYolu.belirle(
        null,
        uretim: VeriYolu.hangarlar,
        cevre: 'VOIDSPACE_KESINLIKLE_TANIMSIZ_DEGISKEN',
      );
      expect(yol, startsWith(Directory.systemTemp.path));
    });
  });
}
