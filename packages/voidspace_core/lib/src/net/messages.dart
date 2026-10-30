import 'dart:convert';
import 'dart:typed_data';

import '../combat/combat_glossary.dart';
import '../domain/ship_stats.dart';
import '../domain/world.dart';
import '../domain/vec2.dart';
import '../sim/ship_input.dart';
import '../sim/ship_sim_state.dart';
import 'byte_io.dart';
import 'entity_delta.dart';
import 'protocol.dart';
import 'quantize.dart';

/// Bozuk ya da tanınmayan bir çerçeve. Ağdan gelen HER şey düşmanca kabul
/// edilir: çözücü asla istisna fırlatmaz, tanımadığını bu tiple geri verir ve
/// çağıran bağlantıyı kapatır.
class MalformedMessage implements ClientMessage, ServerMessage {
  const MalformedMessage(this.reason);

  final String reason;

  @override
  Uint8List encode() => throw StateError('bozuk mesaj kodlanamaz');
}

// ═══════════════════════════════════════════════════════════════════════
// İstemci → Sunucu
// ═══════════════════════════════════════════════════════════════════════

sealed class ClientMessage {
  Uint8List encode();

  static ClientMessage decode(Uint8List bytes) {
    if (bytes.isEmpty) return const MalformedMessage('boş çerçeve');
    try {
      final r = ByteReader(bytes);
      return switch (r.u8()) {
        Protocol.msgHello => ClientHello._read(r),
        Protocol.msgRegister => ClientRegister._read(r),
        Protocol.msgLogin => ClientLogin._read(r),
        Protocol.msgInput => ClientInput._read(r),
        Protocol.msgPing => ClientPing._read(r),
        Protocol.msgHangar => ClientHangar._read(r),
        Protocol.msgGecit => ClientGecit._read(r),
        Protocol.msgDebug => ClientDebug._read(r),
        final id => MalformedMessage(
          'bilinmeyen tip 0x${id.toRadixString(16)}',
        ),
      };
    } on Object catch (e) {
      return MalformedMessage('çözülemedi: $e');
    }
  }
}

/// El sıkışma. Sunucunun oyuncuya bir entity ayırmadan önce gördüğü tek şey.
class ClientHello implements ClientMessage {
  const ClientHello({required this.protocolVersion, required this.token});

  final int protocolVersion;

  /// Oturum belirteci — [ClientRegister] ya da [ClientLogin] karşılığında
  /// alınır.
  ///
  /// Eskiden burada serbest bir AD vardı ve isteyen istediği adla girebiliyordu.
  /// Ad artık hesaptan geliyor: istemcinin söylediği bir şey değil, sunucunun
  /// bildiği bir şey. Taklit bu tek değişiklikle kapanıyor.
  final String token;

  @override
  Uint8List encode() =>
      (ByteWriter(80)
            ..u8(Protocol.msgHello)
            ..u16(protocolVersion)
            ..str(token))
          .take();

  static ClientHello _read(ByteReader r) =>
      ClientHello(protocolVersion: r.u16(), token: r.str());
}

/// Yeni hesap.
///
/// **Parola tel üzerinde AÇIK gider.** Bunu güvenli kılan tek şey TLS'tir
/// (`wss://`). İstemcide hash'lemek hiçbir şey çözmez: hash o zaman parolanın
/// kendisi olur ve çalan doğrudan kullanır. Global açılıştan önce TLS
/// zorunlu — bu bir tercih değil.
class ClientRegister implements ClientMessage {
  const ClientRegister({
    required this.protocolVersion,
    required this.email,
    required this.username,
    required this.password,
  });

  final int protocolVersion;
  final String email;
  final String username;
  final String password;

  @override
  Uint8List encode() =>
      (ByteWriter(256)
            ..u8(Protocol.msgRegister)
            ..u16(protocolVersion)
            ..str(email)
            ..str(username)
            ..str(password))
          .take();

  static ClientRegister _read(ByteReader r) => ClientRegister(
    protocolVersion: r.u16(),
    email: r.str(),
    username: r.str(),
    password: r.str(),
  );

  /// Günlüğe parola sızdırmamak için: varsayılan `toString` alanları basardı.
  @override
  String toString() => 'ClientRegister($username)';
}

class ClientLogin implements ClientMessage {
  const ClientLogin({
    required this.protocolVersion,
    required this.username,
    required this.password,
  });

  final int protocolVersion;

  /// Kullanıcı adı ya da e-posta — ikisi de kabul edilir.
  final String username;
  final String password;

  @override
  Uint8List encode() =>
      (ByteWriter(256)
            ..u8(Protocol.msgLogin)
            ..u16(protocolVersion)
            ..str(username)
            ..str(password))
          .take();

  static ClientLogin _read(ByteReader r) => ClientLogin(
    protocolVersion: r.u16(),
    username: r.str(),
    password: r.str(),
  );

  @override
  String toString() => 'ClientLogin($username)';
}

/// Tek bir simülasyon tiki için oyuncunun niyeti. Saniyede 30 tane.
class ClientInput implements ClientMessage {
  const ClientInput({required this.seq, required this.input});

  final int seq;
  final ShipInput input;

  @override
  Uint8List encode() {
    final w = ByteWriter(16)
      ..u8(Protocol.msgInput)
      ..u32(seq)
      // Eksen -1..1 → i8. Klavye yalnız -1/0/1 üretir ama analog bir çubuk
      // ya da dokunmatik joystick geldiğinde biçim değişmesin.
      ..i8((input.axis.x.clamp(-1.0, 1.0) * 127).round())
      ..i8((input.axis.y.clamp(-1.0, 1.0) * 127).round());

    final target = input.moveTarget;
    w
      ..u8(
        (input.boost ? 1 : 0) |
            (target != null ? 2 : 0) |
            (input.firing ? 4 : 0),
      )
      // Hedef kimliği HER çerçevede gider (0 = yok). Koşullu yazmak 2 bayt
      // kazandırırdı ama girdi zaten saniyede 30 × ~14 bayt; bu format bir
      // dal daha az demek.
      ..u16(input.weaponTarget);
    if (target != null) {
      // Hedef f32: tıklama tikte BİR KEZ gider, 4 baytı kısmanın anlamı yok
      // ve "tam tıklanan yerde dur" sözleşmesi kuantalamayı kaldırmaz.
      w
        ..f32(target.x)
        ..f32(target.y);
    }
    return w.take();
  }

  static ClientInput _read(ByteReader r) {
    final seq = r.u32();
    final axis = Vec2(r.i8() / 127, r.i8() / 127);
    final flags = r.u8();
    final weaponTarget = r.u16();
    final target = (flags & 2) != 0 ? Vec2(r.f32(), r.f32()) : null;
    return ClientInput(
      seq: seq,
      input: ShipInput(
        seq: seq,
        axis: axis,
        moveTarget: target,
        boost: (flags & 1) != 0,
        weaponTarget: weaponTarget,
        firing: (flags & 4) != 0,
      ),
    );
  }
}

/// Gidiş-dönüş ölçümü. Saat SENKRONİZASYONU değil: istemci yalnız kendi
/// gönderdiği damgayı geri alır, böylece sunucunun saatini bilmesine gerek
/// kalmadan RTT'yi hesaplar.
class ClientPing implements ClientMessage {
  const ClientPing(this.clientTimeMs);

  final int clientTimeMs;

  @override
  Uint8List encode() =>
      (ByteWriter(8)
            ..u8(Protocol.msgPing)
            ..u32(clientTimeMs))
          .take();

  static ClientPing _read(ByteReader r) => ClientPing(r.u32());
}

/// GEÇİT — üstünde durduğum geçitten geçmek istiyorum.
///
/// **Yük taşımıyor.** Hangi geçit olduğunu sunucu geminin konumundan
/// çözüyor; istemcinin adlandırması, üstünde durmadığı bir geçide ışınlanma
/// kapısı olurdu.
class ClientGecit implements ClientMessage {
  const ClientGecit();

  @override
  Uint8List encode() => (ByteWriter(2)..u8(Protocol.msgGecit)).take();

  static ClientGecit _read(ByteReader r) => const ClientGecit();
}

/// Hangar komutu.
///
/// **Neden JSON, oysa snapshot ikili.** İkili biçimin değeri saniyede otuz kez
/// giden pakette; hangar ise menü trafiği — oyuncu bir düğmeye bastığında bir
/// kez. Buna karşılık yapısı iç içe ve HENÜZ OTURMAMIŞ: yeni bir eylem, yeni
/// bir alan eklemek olağan. İkili kodlamak, her değişiklikte iki uçta el
/// yazımı çözücü güncellemek demekti — kazancı olmayan bir titizlik.
///
/// Sınır aynı kalıyor: gelen her şey düşman. Sunucu komutun kendisini değil,
/// SONUCUNU doğruluyor — hangar kuralları `HangarRules` içinde ve orada
/// çalışıyor.
class ClientHangar implements ClientMessage {
  const ClientHangar({required this.action, this.payload = const {}});

  /// `buy_item` | `buy_hull` | `equip` | `unequip` | `upgrade` | `select_hull`
  /// | `refresh`
  final String action;

  final Map<String, Object?> payload;

  @override
  Uint8List encode() =>
      (ByteWriter(256)
            ..u8(Protocol.msgHangar)
            ..str(jsonEncode({'action': action, ...payload})))
          .take();

  static ClientHangar _read(ByteReader r) {
    final decoded = jsonDecode(r.str());
    if (decoded is! Map) {
      throw const FormatException('hangar komutu nesne değil');
    }
    final map = decoded.cast<String, Object?>();
    final action = map.remove('action');
    if (action is! String) {
      throw const FormatException('hangar komutunda eylem yok');
    }
    return ClientHangar(action: action, payload: map);
  }
}

/// TODO(combat): silah katmanı gelince sil.
class ClientDebug implements ClientMessage {
  const ClientDebug(this.kind);

  final int kind;

  @override
  Uint8List encode() =>
      (ByteWriter(4)
            ..u8(Protocol.msgDebug)
            ..u8(kind))
          .take();

  static ClientDebug _read(ByteReader r) => ClientDebug(r.u8());
}

// ═══════════════════════════════════════════════════════════════════════
// Sunucu → İstemci
// ═══════════════════════════════════════════════════════════════════════

sealed class ServerMessage {
  Uint8List encode();

  static ServerMessage decode(Uint8List bytes) {
    if (bytes.isEmpty) return const MalformedMessage('boş çerçeve');
    try {
      final r = ByteReader(bytes);
      return switch (r.u8()) {
        Protocol.msgWelcome => ServerWelcome._read(r),
        Protocol.msgHarita => ServerHarita._read(r),
        Protocol.msgGecitRed => ServerGecitRed._read(r),
        Protocol.msgSnapshot => ServerSnapshot._read(r),
        Protocol.msgPong => ServerPong._read(r),
        Protocol.msgEntityMeta => ServerEntityMeta._read(r),
        Protocol.msgEntityGone => ServerEntityGone._read(r),
        Protocol.msgRejected => ServerRejected._read(r),
        Protocol.msgAuthOk => ServerAuthOk._read(r),
        Protocol.msgAuthError => ServerAuthError._read(r),
        Protocol.msgHangarState => ServerHangarState._read(r),
        Protocol.msgReward => ServerReward._read(r),
        Protocol.msgGanimet => ServerGanimet._read(r),
        final id => MalformedMessage(
          'bilinmeyen tip 0x${id.toRadixString(16)}',
        ),
      };
    } on Object catch (e) {
      return MalformedMessage('çözülemedi: $e');
    }
  }
}

/// Kabul. Dünya ölçüleri BURADAN gelir — istemci kendi sabitine güvenmez,
/// yoksa sunucu haritayı büyüttüğünde konum kuantalaması sessizce kayar.
class ServerWelcome implements ServerMessage {
  const ServerWelcome({
    required this.entityId,
    required this.tickRate,
    required this.snapshotRate,
    required this.worldWidth,
    required this.worldHeight,
    required this.worldMargin,
    this.bolgeKademe = 0,
    this.haritaTipi = 0,
  });

  final int entityId;
  final int tickRate;
  final int snapshotRate;
  final double worldWidth;
  final double worldHeight;
  final double worldMargin;


  /// Oyuncunun NEREDE uyandığı — bölge kademesi ve harita tipi.
  ///
  /// Karşılamada olması zorunlu. Harita kalıcı olduğu için dönen oyuncu
  /// başlangıçta DEĞİL bıraktığı yerde uyanıyor, ama istemci bunu yalnız
  /// [ServerHarita]'dan öğreniyordu — o da geçişte gidiyor. Sonuç: sunucu bir
  /// haritaya, istemci başkasına bakıyor; çizilen geçitler sunucuda yok ve
  /// oyuncu "geçit menzilinde değilsin" alıyordu, kapının tam üstünde.
  ///
  /// Dünyanın ÖLÇÜSÜ zaten burada taşınıyordu; eksik olan KİMLİĞİYDİ.
  final int bolgeKademe;
  final int haritaTipi;

  @override
  Uint8List encode() =>
      (ByteWriter(32)
            ..u8(Protocol.msgWelcome)
            ..u16(entityId)
            ..u8(tickRate)
            ..u8(snapshotRate)
            ..f32(worldWidth)
            ..f32(worldHeight)
            ..f32(worldMargin)
            ..u8(bolgeKademe)
            ..u8(haritaTipi))
          .take();

  static ServerWelcome _read(ByteReader r) => ServerWelcome(
    entityId: r.u16(),
    tickRate: r.u8(),
    snapshotRate: r.u8(),
    worldWidth: r.f32(),
    worldHeight: r.f32(),
    worldMargin: r.f32(),
    bolgeKademe: r.u8(),
    haritaTipi: r.u8(),
  );
}

/// HARİTA DEĞİŞTİ — geçitten geçildi.
///
/// [ServerWelcome] tekrarı DEĞİL: welcome el sıkışmanın parçası ve istemcide
/// oturum kurulumunu tetikliyor. Bu mesaj yalnız dünyayı yeniliyor.
///
/// [entityId] de gidiyor çünkü DEĞİŞİYOR: her haritanın kendi kimlik aralığı
/// var ve gemi yeni hücrede yeni bir kimlik alıyor. Eski kimlikle devam eden
/// bir istemci kendini snapshot'ta bulamaz ve ekranda kaybolurdu.
class ServerHarita implements ServerMessage {
  const ServerHarita({
    required this.entityId,
    required this.bolgeKademe,
    required this.haritaTipi,
    required this.worldWidth,
    required this.worldHeight,
    required this.worldMargin,
    required this.x,
    required this.y,
  });

  final int entityId;

  /// Bölgenin kademesi — istemci [Bolge.byKademe] ile çözüyor.
  final int bolgeKademe;

  /// [HaritaTipi] indeksi.
  final int haritaTipi;

  final double worldWidth;
  final double worldHeight;
  final double worldMargin;

  /// Geminin YENİ haritadaki yeri — sunucunun koyduğu yer.
  ///
  /// İstemci bunu TAHMİN ETMEMELİ. Ediyordu: geçişten sonra tahmin nesnesini
  /// yeni dünyanın MERKEZİNE kuruyordu, oysa sunucu gemiyi geçidin karşı
  /// kenarına koyuyor. Aradaki fark bu haritalarda 5.041–7.794 birim, yani
  /// ışınlanma eşiğinin (420) yirmi katı — sonuç iki ayrı sıçrama: önce
  /// merkeze, ilk anlık görüntü gelince oradan kapıya. Kamera da gemiyi
  /// takip ettiği için görüntü savruluyordu.
  ///
  /// Otoriter konum zaten bu mesajın gönderildiği anda sunucunun elinde;
  /// yollamamak için bir sebep yoktu. Sunucu kaynaklı bir taşımada istemcinin
  /// konumu kendi hesaplaması, kuralın ikinci bir kopyasını yazmak olurdu.
  final double x;
  final double y;

  @override
  Uint8List encode() =>
      (ByteWriter(40)
            ..u8(Protocol.msgHarita)
            ..u16(entityId)
            ..u8(bolgeKademe)
            ..u8(haritaTipi)
            ..f32(worldWidth)
            ..f32(worldHeight)
            ..f32(worldMargin)
            ..f32(x)
            ..f32(y))
          .take();

  static ServerHarita _read(ByteReader r) => ServerHarita(
    entityId: r.u16(),
    bolgeKademe: r.u8(),
    haritaTipi: r.u8(),
    worldWidth: r.f32(),
    worldHeight: r.f32(),
    worldMargin: r.f32(),
    x: r.f32(),
    y: r.f32(),
  );
}

/// GEÇİŞ REDDİ — geçitten geçilemedi, ama oyun sürüyor.
///
/// Ayrı bir mesaj olması zorunlu: [ServerRejected] el sıkışma reddi ve istemci
/// onu alınca belirteci unutup dünyadan çıkıyor. Geçide iki adım uzak durmanın
/// cezası oturumu kaybetmek olamaz.
///
/// İstemci zaten kendi tarafında menzili ve kapıyı biliyor; bu mesaj
/// geldiğinde iki uç AYRIŞMIŞ demektir. Sessizce yutmak yerine söylüyoruz —
/// ama oyunu bozmadan.
class ServerGecitRed implements ServerMessage {
  const ServerGecitRed(this.sebep);

  final String sebep;

  @override
  Uint8List encode() =>
      (ByteWriter(128)
            ..u8(Protocol.msgGecitRed)
            ..str(sebep))
          .take();

  static ServerGecitRed _read(ByteReader r) => ServerGecitRed(r.str());
}

/// Red — sürüm uyuşmazlığı, dolu sunucu, bozuk el sıkışma.
/// Kimlik doğrulandı.
class ServerAuthOk implements ServerMessage {
  const ServerAuthOk({required this.token, required this.username});

  /// Dünyaya girerken [ClientHello] ile geri gönderilir. İstemci bunu
  /// saklarsa yeniden bağlanmada parola sormaya gerek kalmaz.
  final String token;

  /// Hesabın KANONİK adı (kayıttaki büyük/küçük harfiyle). İstemcinin
  /// yazdığı değil, sunucunun bildiği.
  final String username;

  @override
  Uint8List encode() =>
      (ByteWriter(128)
            ..u8(Protocol.msgAuthOk)
            ..str(token)
            ..str(username))
          .take();

  static ServerAuthOk _read(ByteReader r) =>
      ServerAuthOk(token: r.str(), username: r.str());
}

/// Kimlik reddedildi — sebebi kullanıcıya gösterilecek metin.
/// Hangarın TAM durumu: para, sahip olunan gemiler, envanter, donatım.
///
/// Delta yok, tam durum: menü trafiği seyrek ve durum küçük. Kısmi güncelleme
/// burada kazanç değil, senkron kaybı riski olurdu.
class ServerHangarState implements ServerMessage {
  /// Gemiye takılı her şeyin çözülmüş hâli — hangar ekranının okuduğu harita.
  ///
  /// **Tek üretici olması şart.** Bu harita bir zamanlar İKİ yerde elle
  /// yazılıydı: sunucunun `_hangarJson`'ı ve `tool/menu_preview_test.dart`'ın
  /// kopyası. İkisi ayrı güncellenseydi görsel referans, oyuncunun gördüğünden
  /// başka bir gemiyi çizerdi — ve kimse fark etmezdi, çünkü ikisi de kendi
  /// içinde tutarlı kalırdı.
  static Map<String, Object?> effectiveOf(ShipStats stats) => {
    'hull': stats.maxHull,
    'shield': stats.maxShield,
    'speed': stats.speed,
    // YAYLIM — namlu başına DEĞİL.
    //
    // Buraya `stats.laser.damage` yazılıydı ve o sayı TEK namlunun ham L0
    // hasarı: hasar zincirinden hiç geçmiyor (oran bonusu, kritik, düz hasar
    // yok) ve namlu sayısıyla çarpılmıyor. Beş PL-4 takılı bir Bastion'da
    // hangar **420**, HUD **2.100** diyordu — aynı gemi için iki sayı.
    //
    // Asıl zarar orada değildi: `LoadoutResolver` toplam tabanı namlu sayısına
    // böldüğü için, ZAYIF ikinci bir lazer takmak gösterilen sayıyı
    // DÜŞÜRÜYORDU (PL-4 tek: 420 → PL-4 + PL-1: 310), oysa gerçek yaylım
    // 420'den 620'ye ÇIKIYOR. Arayüz, güçlenen oyuncuya zayıfladığını
    // söylüyordu.
    'damage': CombatGlossary.volley(stats),
    'range': stats.laser.range,
    'fireInterval': stats.laser.fireInterval,
  };

  const ServerHangarState(this.json);

  /// `Hangar.toJson()` çıktısı + sunucunun hesapladığı türev sayılar.
  final Map<String, Object?> json;

  @override
  Uint8List encode() =>
      (ByteWriter(1024)
            ..u8(Protocol.msgHangarState)
            ..str(jsonEncode(json)))
          .take();

  static ServerHangarState _read(ByteReader r) {
    final decoded = jsonDecode(r.str());
    if (decoded is! Map) {
      throw const FormatException('hangar durumu nesne değil');
    }
    return ServerHangarState(decoded.cast<String, Object?>());
  }
}

class ServerAuthError implements ServerMessage {
  const ServerAuthError(this.reason);

  final String reason;

  @override
  Uint8List encode() =>
      (ByteWriter(128)
            ..u8(Protocol.msgAuthError)
            ..str(reason))
          .take();

  static ServerAuthError _read(ByteReader r) => ServerAuthError(r.str());
}

class ServerRejected implements ServerMessage {
  const ServerRejected(this.reason);

  final String reason;

  @override
  Uint8List encode() =>
      (ByteWriter(64)
            ..u8(Protocol.msgRejected)
            ..str(reason))
          .take();

  static ServerRejected _read(ByteReader r) => ServerRejected(r.str());
}

class ServerPong implements ServerMessage {
  const ServerPong(this.clientTimeMs, this.serverTimeMs);

  final int clientTimeMs;
  final int serverTimeMs;

  @override
  Uint8List encode() =>
      (ByteWriter(12)
            ..u8(Protocol.msgPong)
            ..u32(clientTimeMs)
            ..u32(serverTimeMs))
          .take();

  static ServerPong _read(ByteReader r) => ServerPong(r.u32(), r.u32());
}

/// Bir oyuncunun NADİREN değişen bilgisi: adı ve kaç namlu taşıdığı.
///
/// Snapshot'ta yeri yok. Snapshot saniyede 30 kez gidiyor ve entity başına 14
/// bayt; ad ömürde bir kez, namlu sayısı ise ancak oyuncu hangarda lazer takıp
/// çıkardığında değişiyor. İkisini de otuz kez saniyede yollamak, hiç
/// değişmeyen veriyi bant genişliğine yazmak olurdu.
///
/// **Neden namlu sayısı da burada.** Uzak bir geminin kaç topu olduğu ÇİZİM
/// için gerekli: gemi taktığı kadar silah taşıyor ve bunu yalnız kendi gemin
/// için bilmek yetmez — yanındaki oyuncunun gemisinde beş top görünürken
/// seninkinde bir tane olması, ikisinden birinin yalan olduğunu söylerdi.
class ServerEntityMeta implements ServerMessage {
  const ServerEntityMeta(
    this.id,
    this.name,
    this.lasers,
    this.govde, {
    this.droidler = const [],
    this.droidModelleri = const [],
    this.formasyon = 0,
  });

  final int id;
  final String name;

  /// Takılı lazer sayısı (0..255). Gövdenin yuva sayısı DEĞİL — dolu olanlar.
  final int lasers;

  /// Gövde KADEMESİ (0..7) — hangi gemi çizimiyle görüneceği.
  ///
  /// **Neden snapshot'ta değil burada.** Snapshot alanları tik başına
  /// kuantalanıp maskeleniyor ve maske TAM DOLU: sekiz bitin sekizi de
  /// kullanımda. Dokuzuncu bir alan maskeyi iki bayta çıkarır ve bunu
  /// saniyede otuz kez, görünen her gemi için öderdik.
  ///
  /// Oysa gövde kademesi ara değerlenen bir şey değil: oyuncu hangarda gemi
  /// değiştirene kadar sabit. Namlu sayısıyla birebir aynı cins bir gerçek ve
  /// zaten onun yanına ait.
  final int govde;

  /// Takılı droidlerin GÖRSEL kademeleri (1..6), yuva sırasıyla. Boşsa droid
  /// yok. Kademe eşyanın artı seviyesinden (05.8) ve hangarda değişiyor —
  /// namlu sayısıyla aynı cins bir gerçek, aynı kanal.
  final List<int> droidler;

  /// Her droidin MODELİ (`DroidModeli` indeksi), [droidler] ile aynı sırada.
  final List<int> droidModelleri;

  /// Seçili formasyonun `Formasyon.hepsi` indeksi — geometri istemcide.
  final int formasyon;

  @override
  Uint8List encode() {
    final w = ByteWriter(64)
      ..u8(Protocol.msgEntityMeta)
      ..u16(id)
      ..u8(lasers)
      ..u8(govde)
      ..u8(droidler.length);
    for (var i = 0; i < droidler.length; i++) {
      w
        ..u8(droidler[i])
        ..u8(i < droidModelleri.length ? droidModelleri[i] : 0);
    }
    w
      ..u8(formasyon)
      ..str(name);
    return w.take();
  }

  /// Alanlar YEREL DEĞİŞKENE okunuyor, doğrudan yapıcıya değil.
  ///
  /// Tel sırası `id, lasers, govde, name`; yapıcı sırası `id, name, lasers,
  /// govde`. Dart argümanları soldan sağa değerlendirdiği için doğrudan çağrı
  /// baytları TERS sırada okurdu — ve okuyucu konumu ilerlediği için hata da
  /// vermezdi, yalnız çöp bir ad ve saçma sayılar çıkardı.
  static ServerEntityMeta _read(ByteReader r) {
    final id = r.u16();
    final lasers = r.u8();
    final govde = r.u8();
    final droidSayisi = r.u8();
    final droidler = <int>[];
    final modeller = <int>[];
    for (var i = 0; i < droidSayisi; i++) {
      droidler.add(r.u8());
      modeller.add(r.u8());
    }
    final formasyon = r.u8();
    return ServerEntityMeta(
      id,
      r.str(),
      lasers,
      govde,
      droidler: droidler,
      droidModelleri: modeller,
      formasyon: formasyon,
    );
  }
}

/// Oyuncu dünyadan AYRILDI. Snapshot'ta görünmemekle karıştırılmamalı: orada
/// yokluk "ilgi alanımın dışında" demektir, bu mesaj ise "artık yok".
class ServerEntityGone implements ServerMessage {
  const ServerEntityGone(this.id);

  final int id;

  @override
  Uint8List encode() =>
      (ByteWriter(4)
            ..u8(Protocol.msgEntityGone)
            ..u16(id))
          .take();

  static ServerEntityGone _read(ByteReader r) => ServerEntityGone(r.u16());
}

/// Uzak bir geminin kuantalanmış hâli — 14 bayt.
///
/// Kendi geminden farkı KASITLI: burada yalnız ÇİZMEK için gereken şeyler var.
/// Uzak geminin kalkan sayacını ya da hedefini bilmeye ihtiyacın yok, ve
/// bilmemen gerekiyor.
class EntitySnapshot {
  const EntitySnapshot({
    required this.id,
    required this.position,
    required this.angle,
    required this.thrust,
    required this.shieldFraction,
    required this.hullFraction,
    required this.alive,
    required this.boosting,
    this.weaponTarget = 0,
    this.firing = false,
  });

  /// 11 → 13: hedef kimliği (u16) eklendi, ateş bayrağı mevcut bayrak
  /// baytına sığdı. Entity başına 2 bayt, oyuncu başına ~0.6 KB/s — ışını
  /// ayrı bir olay kanalıyla göndermenin (sıralama, tekrar, kayıp) maliyeti
  /// bunun yanında çok daha yüksekti.
  ///
  /// SAYI DEĞİL, ATIF: elle yazıldığı sürece 13'te kalmıştı, oysa
  /// [EntityDelta.write] 14 bayt yazıyor. Fark sessizdi çünkü bu sabit yalnız
  /// tampon boyutu tahmini ve bant genişliği bütçesi için okunuyor — biri
  /// yeniden tahsisle, diğeri %7 eksik ölçümle yutuyordu.
  static const int wireSize = EntityDelta.fullWireSize;

  final int id;
  final Vec2 position;
  final double angle;
  final double thrust;
  final double shieldFraction;
  final double hullFraction;
  final bool alive;
  final bool boosting;

  /// Bu geminin nişan aldığı kimlik; 0 = yok.
  final int weaponTarget;

  /// Ateş ediyor mu. İstemci ışını bu ikisiyle çizer — atış OLAYI göndermeye
  /// gerek yok, durum kendi kendini senkronlar.
  final bool firing;

  /// Nesne kuran yol — TAM kayıt yazar (maske = hepsi).
  ///
  /// Sunucunun sıcak yolu bunu kullanmıyor ([writeFrom] kullanıyor); burası
  /// testlerin ve teşhisin yolu. `codec_test.dart` ikisinin BİREBİR aynı baytı
  /// ürettiğini kilitliyor — iki yazıcının ayrışması, sunucunun ürettiği
  /// paketin hiçbir testte görülmemesi demek olurdu.
  void write(ByteWriter w, double worldWidth, double worldHeight) {
    final v = Int32List(EntityDelta.fields)
      ..[EntityDelta.fx] = Quantize.position(position.x, worldWidth)
      ..[EntityDelta.fy] = Quantize.position(position.y, worldHeight)
      ..[EntityDelta.fAngle] = Quantize.angle(angle)
      ..[EntityDelta.fThrust] = Quantize.unit(thrust)
      ..[EntityDelta.fShield] = Quantize.unit(shieldFraction)
      ..[EntityDelta.fHull] = Quantize.unit(hullFraction)
      ..[EntityDelta.fFlags] =
          (alive ? 1 : 0) | (boosting ? 2 : 0) | (firing ? 4 : 0)
      ..[EntityDelta.fTarget] = weaponTarget;
    EntityDelta.write(w, id, v, EntityDelta.full);
  }

  /// Delta oku ve [baseline] üstüne uygula.
  ///
  /// [baseline] verilmezse her kayıt TAM olmak zorunda — testlerin ve tek
  /// seferlik çözümlerin yolu.
  static EntitySnapshot read(
    ByteReader r,
    double worldWidth,
    double worldHeight, [
    EntityBaseline? baseline,
  ]) {
    final id = r.u16();
    final mask = r.u8();
    if (baseline != null) {
      final (values, isNew) = baseline.slot(id);
      if (isNew && mask != EntityDelta.full) {
        // Temeli olmayan bir entity için kısmi kayıt gelemez; sunucu yeni
        // görünen her entity'yi TAM yollar. Buraya düşmek protokol hatasıdır
        // ve sessizce yanlış konum çizmektense çerçeveyi reddetmek doğru.
        throw const FormatException('temelsiz entity için kısmi delta');
      }
      EntityDelta.read(r, mask, values);
      return fromWire(id, values, worldWidth, worldHeight);
    }
    if (mask != EntityDelta.full) {
      throw const FormatException('temel olmadan kısmi delta çözülemez');
    }
    final scratch = Int32List(EntityDelta.fields);
    EntityDelta.read(r, mask, scratch);
    return fromWire(id, scratch, worldWidth, worldHeight);
  }

  /// Bir gemiyi ARA NESNE ÜRETMEDEN doğrudan tele yaz.
  ///
  /// [fromSim] + [write] ikilisiyle aynı baytları üretir; farkı, snapshot
  /// başına entity başına bir nesne tahsis etmemesi. Ölçek bunu gerektiriyor:
  /// 41 oyuncu birbirini görürken 30 Hz'de saniyede ~49.000 kısa ömürlü nesne
  /// demekti, ve Dart'ın çöp toplayıcısı duraklattığında duraklattığı şey
  /// otorite döngüsü.
  ///
  /// `codec_test.dart` iki yolun BİREBİR aynı baytı yazdığını kilitliyor —
  /// ayrışırlarsa hızlı yol sessizce bozuk snapshot üretirdi.
  /// Ara nesne üretmeden TAM kayıt yaz (maske = hepsi).
  ///
  /// Kuantalama tamponu çağırana ait: tik başına oyuncu × görünür entity kadar
  /// çağrılıyor ve her seferinde yeni bir dizi ayırmak saniyede on binlerce
  /// kısa ömürlü nesne ederdi.
  static void writeFrom(
    ByteWriter w,
    int id,
    ShipSimState s,
    double worldWidth,
    double worldHeight,
    Int32List scratch,
  ) {
    EntityDelta.quantize(scratch, s, worldWidth, worldHeight);
    EntityDelta.write(w, id, scratch, EntityDelta.full);
  }

  /// Kuantalanmış alanlardan nesne kur — çözücünün son adımı.
  static EntitySnapshot fromWire(
    int id,
    Int32List v,
    double worldWidth,
    double worldHeight,
  ) => EntitySnapshot(
    id: id,
    position: Vec2(
      Quantize.unposition(v[EntityDelta.fx], worldWidth),
      Quantize.unposition(v[EntityDelta.fy], worldHeight),
    ),
    angle: Quantize.unangle(v[EntityDelta.fAngle]),
    thrust: Quantize.ununit(v[EntityDelta.fThrust]),
    shieldFraction: Quantize.ununit(v[EntityDelta.fShield]),
    hullFraction: Quantize.ununit(v[EntityDelta.fHull]),
    alive: (v[EntityDelta.fFlags] & 1) != 0,
    boosting: (v[EntityDelta.fFlags] & 2) != 0,
    firing: (v[EntityDelta.fFlags] & 4) != 0,
    weaponTarget: v[EntityDelta.fTarget],
  );

  static EntitySnapshot fromSim(int id, ShipSimState s) => EntitySnapshot(
    id: id,
    position: s.position,
    angle: s.angle,
    thrust: s.thrust,
    shieldFraction: s.shieldFraction,
    hullFraction: s.hullFraction,
    alive: s.alive,
    boosting: s.boosting,
    weaponTarget: s.weaponTarget,
    firing: s.firing,
  );

  /// İki snapshot arasında ara değer. Uzak gemilerin pürüzsüz görünmesinin
  /// tamamı bu.
  ///
  /// Açı `lerp` DEĞİL: -179° ile +179° arasında düz ara değer gemiyi ters yöne
  /// tam tur attırır. En kısa yay üzerinden gitmek şart.
  static EntitySnapshot lerp(EntitySnapshot a, EntitySnapshot b, double t) =>
      EntitySnapshot(
        id: b.id,
        position: Vec2.lerp(a.position, b.position, t),
        angle: _lerpAngle(a.angle, b.angle, t),
        thrust: a.thrust + (b.thrust - a.thrust) * t,
        shieldFraction:
            a.shieldFraction + (b.shieldFraction - a.shieldFraction) * t,
        hullFraction: a.hullFraction + (b.hullFraction - a.hullFraction) * t,
        // Bayraklar ara değer almaz: en yeni gerçek doğru olandır. DÖRDÜ de
        // taşınmak zorunda — `firing` ile `weaponTarget` burada unutulduğunda
        // ara değer alınan her gemi ateş etmiyor görünüyordu: namlu parlaması
        // ve nişan çizgisi yalnız tam kare denk geldiğinde çiziliyordu.
        alive: b.alive,
        boosting: b.boosting,
        firing: b.firing,
        weaponTarget: b.weaponTarget,
      );

  /// En kısa yay üzerinden açı ara değeri.
  ///
  /// Açık: istemcinin çizim yolu ara değeri NESNE ÜRETMEDEN yapıyor (kare
  /// başına gemi başına bir `EntitySnapshot` ayırmak, 40 gemide saniyede
  /// binlerce kısa ömürlü nesne demek) ama bu matematiğin iki yerde
  /// yazılmasını istemiyoruz.
  static double lerpAngle(double a, double b, double t) => _lerpAngle(a, b, t);

  static double _lerpAngle(double a, double b, double t) {
    var delta = (b - a) % (2 * 3.141592653589793);
    if (delta > 3.141592653589793) delta -= 2 * 3.141592653589793;
    if (delta < -3.141592653589793) delta += 2 * 3.141592653589793;
    return a + delta * t;
  }
}

/// Sunucunun ÇÖZDÜĞÜ tek bir yaylım ateş — 9 bayt.
///
/// **Neden durum değil OLAY.** Bu projedeki kural, senkronu duruma yaptırmak:
/// kimin kime nişan aldığı ([EntitySnapshot.weaponTarget]) ve ateşin açık
/// olup olmadığı ([EntitySnapshot.firing]) her snapshot'ta tekrarlandığı için
/// kayıp bir paket hiçbir şeyi bozmuyor. Bir VURUŞ ise tekrarlanamaz: tek bir
/// anda olan tek bir sayı. Durum alanına yazılsaydı, iki snapshot arasında
/// düşen iki vuruş tek vuruşa iner ve ekrandaki hasar sayısı yalan söylerdi.
///
/// Maliyeti küçük tutan şey ATIŞ HIZI: 64 gemi tam kadro ateş etse bile
/// saniyede ~58 yaylım çıkıyor, yani snapshot başına ortalama iki olay.
///
/// Kaybı da bilerek göze alınıyor: WebSocket zaten güvenilir taşıyor, ama
/// oyuncu ilgi alanına yeni girdiyse kaçırdığı vuruşlar geri gelmez —
/// gelmemeli de, çünkü görmediğin bir çarpışmanın sayısı ekranına düşmemeli.
class ShotEvent {
  const ShotEvent({
    required this.shooterId,
    required this.targetId,
    required this.damage,
    required this.shieldHit,
    required this.killed,
    this.crit = false,
    this.grazed = false,
    this.roket = false,
  });

  /// 7 → 9: hasar `u16`'dan `u32`'ye genişledi.
  ///
  /// `u16`'nın tavanı 65.535 ve kelepçe SESSİZDİ. Sekiz gövde kademeli
  /// merdivende tepe yaylım ~1.220.000 — yani üst kademelerde ekrandaki her
  /// rakam 65.535'te donar, kritik ile sıradan vuruş aynı sayıyı gösterir ve
  /// oyuncu hasarının arttığını göremez. Hiçbir hata da düşmez.
  ///
  /// İki bayt, oyuncu başına saniyede birkaç yüz bayt: donan bir hasar
  /// göstergesinin yanında bedava.
  static const int wireSize = 9;

  /// Snapshot başına olay tavanı. Sayaç tek bayt olduğu için biçimsel sınır
  /// da bu; aşılırsa fazlası DÜŞER (bkz. `Gateway`), çünkü bir tikte 255
  /// yaylımın altında kalmak matematiksel olarak garanti.
  static const int maxPerSnapshot = 255;

  final int shooterId;
  final int targetId;

  /// Uygulanan toplam hasar (yaylımın tamamı). `u16` taşımaz: en ağır yaylım
  /// bugün 1000, tavan 65535.
  final int damage;

  /// Hasarın KALKANA çarpıp çarpmadığı — sayının rengi bundan geliyor.
  /// Kalkan kısmen emip taşan varsa yine `true`: oyuncunun gördüğü şey ilk
  /// temas.
  final bool shieldHit;

  /// Bu vuruş hedefi imha etti mi.
  final bool killed;

  /// KRİTİK vuruş — sarı, iri rakam.
  ///
  /// Zar SUNUCUDA atılıyor ve sonuç tel üzerinde geliyor. İstemcinin kendi
  /// statlarından hesaplaması bugün aynı sayıyı verirdi ama kritik bir ZAR:
  /// iki taraf ayrı zar atsaydı ekrandaki rakam ile inen hasar farklı olurdu.
  final bool crit;

  /// SIYIRMA — kaçınma hasarı düşürdü, soluk rakam.
  ///
  /// "Iskaladın" DEĞİL. Mermi çarptı ve oyuncu çarptığını gördü; hasar düşük
  /// geldi. Ekranın söylediğiyle sistemin söylediği çelişmiyor.
  final bool grazed;

  /// ROKET salvosu (18): istemci roketi ayrı çizer — büyük, yavaş, merkezden.
  /// Hasar aynı zincirden; olay yalnız "hangi silah" diyor.
  /// KARAR 18.6 s1
  final bool roket;

  // Bayrak baytı: 1 kalkan · 2 imha · 4 kritik · 8 sıyırma · 16 roket. Beşi
  // de aynı baytta, yani yeni bilgiler tel üzerinde SIFIR bayta mal oldu —
  // `wireSize` değişmedi.
  void write(ByteWriter w) => w
    ..u16(shooterId)
    ..u16(targetId)
    ..u32(damage.clamp(0, 0xFFFFFFFF))
    ..u8(
      (shieldHit ? 1 : 0) |
          (killed ? 2 : 0) |
          (crit ? 4 : 0) |
          (grazed ? 8 : 0) |
          (roket ? 16 : 0),
    );

  static ShotEvent read(ByteReader r) {
    final shooterId = r.u16();
    final targetId = r.u16();
    final damage = r.u32();
    final flags = r.u8();
    return ShotEvent(
      shooterId: shooterId,
      targetId: targetId,
      damage: damage,
      shieldHit: (flags & 1) != 0,
      killed: (flags & 2) != 0,
      crit: (flags & 4) != 0,
      grazed: (flags & 8) != 0,
      roket: (flags & 16) != 0,
    );
  }
}

/// Bir alien'in kuantalanmış hâli — 9 bayt.
///
/// Gemiden AYRI bir tip ve ayrı bir liste. Tek bir `EntitySnapshot`'a tür
/// baytı eklemek daha az kod olurdu ve her gemiye o baytı ödetirdi; oysa
/// gemiler zaten en kalabalık listeyi oluşturuyor.
///
/// AÇI YOK ve bu bir eksik değil: Void Spore bir küre. Kabuğu, detay podları ve
/// çekirdeği KENDİ hızlarında dönüyor ve o dönüş istemcinin saatinden
/// türetiliyor — tel üzerinde taşınacak bir yön yok.
class AlienSnapshot {
  const AlienSnapshot({
    required this.id,
    required this.kind,
    required this.position,
    required this.hullFraction,
  });

  /// [EntitySnapshot.wireSize] ile aynı sebeple atıf: elle 8 yazılmıştı,
  /// [AlienDelta.write] 9 bayt yazıyor.
  static const int wireSize = AlienDelta.fullWireSize;

  final int id;

  /// `AlienStats.kind` — hangi tür çizilecek.
  final int kind;

  final Vec2 position;

  /// Kalan can oranı. Kalkan yok — alien'in tek havuzu gövde.
  final double hullFraction;

  /// Nesne kuran yol — TAM kayıt yazar. Bkz. [EntitySnapshot.write].
  void write(ByteWriter w, double worldWidth, double worldHeight) {
    final v = Int32List(AlienDelta.fields);
    AlienDelta.quantize(
      v,
      kind,
      position.x,
      position.y,
      hullFraction,
      worldWidth,
      worldHeight,
    );
    AlienDelta.write(w, id, v, AlienDelta.full);
  }

  /// Delta oku ve [baseline] üstüne uygula.
  ///
  /// Gemilerle AYNI temel haritasını kullanıyor: alien kimlikleri
  /// [Protocol.alienIdBase] üstünde olduğu için çakışma imkânsız.
  static AlienSnapshot read(
    ByteReader r,
    double worldWidth,
    double worldHeight, [
    EntityBaseline? baseline,
  ]) {
    final id = r.u16();
    final mask = r.u8();
    final Int32List values;
    if (baseline != null) {
      final (slot, isNew) = baseline.slot(id);
      if (isNew && mask != AlienDelta.full) {
        throw const FormatException('temelsiz alien için kısmi delta');
      }
      values = slot;
    } else {
      if (mask != AlienDelta.full) {
        throw const FormatException('temel olmadan kısmi alien delta');
      }
      values = Int32List(AlienDelta.fields);
    }
    AlienDelta.read(r, mask, values);
    return AlienSnapshot(
      id: id,
      kind: values[AlienDelta.fKind],
      position: Vec2(
        Quantize.unposition(values[AlienDelta.fx], worldWidth),
        Quantize.unposition(values[AlienDelta.fy], worldHeight),
      ),
      hullFraction: Quantize.ununit(values[AlienDelta.fHull]),
    );
  }
}

/// Kendi geminin OTORİTER hâli — kuantalanmamış.
///
/// Uzak gemilerden farklı davranmasının sebebi: bu durum çizilmiyor, ÜZERİNE
/// YENİDEN OYNATILIYOR. 0.18 birimlik bir kuantalama hatası her snapshot'ta
/// yeniden uygulansaydı gemi durmadan seğirirdi.
class SelfSnapshot {
  const SelfSnapshot({
    required this.acknowledgedSeq,
    required this.state,
    this.pendingInputs = 0,
  });

  /// Sunucunun İŞLEDİĞİ son girdi sırası. Mutabakatın çivisi: istemci bu
  /// sıradan SONRAKİ girdilerini yeniden oynatır.
  final int acknowledgedSeq;

  final ShipSimState state;

  /// Sunucunun girdi kuyruğunda BEKLEYEN çerçeve sayısı.
  ///
  /// Tek baytlık bu alan, pürüzsüzlüğün büyük kısmını taşıyor. Sunucu tik
  /// başına TAM BİR girdi işler (fazlasını işlemek simüle edilen zamanı
  /// hızlandırırdı, yani hız hilesi olurdu). O yüzden istemci de tam o hızda
  /// üretmeli:
  ///
  ///  * Az üretirse kuyruk boşalır, sunucu son girdiyi TEKRARLAR ve istemcinin
  ///    tahmin etmediği bir adım atar → düzeltme.
  ///  * Çok üretirse kuyruk taşar, sunucu girdi DÜŞÜRÜR ve istemcinin tahmin
  ///    ettiği bir adım hiç olmaz → düzeltme.
  ///
  /// İkisi de saniyede onlarca kez küçük düzeltme demek — takılmanın kaynağı.
  /// Bu sayıyı geri söylemek, istemcinin üretim hızını ±%6 bandında
  /// ayarlayıp kuyruğu hedefte tutmasını sağlıyor (zaman genişletme).
  final int pendingInputs;

  void write(ByteWriter w) {
    final s = state;
    final target = s.target;
    w
      ..u32(acknowledgedSeq)
      ..u8(pendingInputs.clamp(0, 255))
      ..f32(s.position.x)
      ..f32(s.position.y)
      ..f32(s.angle)
      ..f32(s.thrust)
      ..f32(s.hull)
      ..f32(s.shield)
      // Sunucu hedefi düşürmüş olabilir (öldü, ayrıldı, menzil dışına çıktı).
      // Mutabakat bunu taşımazsa istemci olmayan bir hedefe nişan almaya
      // devam eder ve ışın boşluğa çizilir.
      ..u16(s.weaponTarget)
      ..boolean(s.firing)
      ..u8(s.boostCharges)
      ..f32(s.boostRemaining)
      ..f32(s.rechargeElapsed)
      ..f32(s.sinceHit)
      ..boolean(target != null);
    if (target != null) {
      w
        ..f32(target.x)
        ..f32(target.y);
    }
    // Nişan noktası: geminin BAKTIĞI yön bundan doğuyor. Taşımasaydık
    // istemcinin yeniden oynatması hedefsiz bir gemi simüle eder ve gövde her
    // snapshot'ta yön değiştirirdi — hem de tam ateş ederken.
    final aim = s.aimPoint;
    w.boolean(aim != null);
    if (aim != null) {
      w
        ..f32(aim.x)
        ..f32(aim.y);
    }
  }

  static SelfSnapshot read(ByteReader r, ShipStats stats) {
    final ack = r.u32();
    final pending = r.u8();
    final position = Vec2(r.f32(), r.f32());
    final angle = r.f32();
    final thrust = r.f32();
    final hull = r.f32();
    final shield = r.f32();
    final weaponTarget = r.u16();
    final firing = r.boolean();
    final charges = r.u8();
    final boostRemaining = r.f32();
    final rechargeElapsed = r.f32();
    final sinceHit = r.f32();
    final target = r.boolean() ? Vec2(r.f32(), r.f32()) : null;
    final aim = r.boolean() ? Vec2(r.f32(), r.f32()) : null;
    return SelfSnapshot(
      acknowledgedSeq: ack,
      pendingInputs: pending,
      state: ShipSimState(
        stats: stats,
        position: position,
        angle: angle,
        thrust: thrust,
        target: target,
        hull: hull,
        shield: shield,
        boostCharges: charges,
        boostRemaining: boostRemaining,
        rechargeElapsed: rechargeElapsed,
        sinceHit: sinceHit,
        weaponTarget: weaponTarget,
        firing: firing,
        aimPoint: aim,
      ),
    );
  }
}

/// Dünyanın tek bir andaki görüntüsü.
///
/// TAM snapshot, delta değil: ilgi alanı filtresinden sonra ~25 entity kalıyor
/// ve 14 baytla bu ~380 bayt ediyor. Delta sıkıştırma bunu belki üçte birine
/// indirir ama karşılığında "istemci hangi temeli gördü" muhasebesi gelir —
/// bu ölçekte ödenecek doğru bedel değil. (`TODO(perf)`: 200+ entity'li boss
/// odalarında yeniden bak.)
class ServerSnapshot implements ServerMessage {
  const ServerSnapshot({
    required this.serverTick,
    required this.self,
    required this.entities,
    required this.worldWidth,
    required this.worldHeight,
    this.shots = const [],
    this.aliens = const [],
  });

  final int serverTick;
  final SelfSnapshot self;
  final List<EntitySnapshot> entities;
  final double worldWidth;
  final double worldHeight;

  /// Bu tikte çözülen vuruşlar — İLGİ ALANINA göre süzülmüş. Görmediğin bir
  /// çarpışma sana hiç gelmez.
  final List<ShotEvent> shots;

  /// Görünür alien'ler — gemilerle aynı ilgi alanı kuralına tabi.
  final List<AlienSnapshot> aliens;

  @override
  Uint8List encode() {
    final w =
        ByteWriter(
            // Sabit pay 73: `SelfSnapshot`ın EN BÜYÜK hâli 63 bayt (hedef ve
            // nişan noktasının ikisi de dolu) + 10 bayt çerçeveleme (tip 1 +
            // tik 4 + entity sayacı 2 + atış sayacı 1 + alien sayacı 2).
            //
            // 64'ken her kodlamada taşıyordu: `_ensure` kapasiteyi iki katına
            // çıkarıp yazılanı kopyalıyor, ardından `take()` bir kez daha
            // kopyalıyordu. Tik başına oyuncu başına iki gereksiz kopya.
            73 +
                entities.length * EntitySnapshot.wireSize +
                shots.length * ShotEvent.wireSize +
                aliens.length * AlienSnapshot.wireSize,
          )
          ..u8(Protocol.msgSnapshot)
          ..u32(serverTick);
    self.write(w);
    w.u16(entities.length);
    for (final e in entities) {
      e.write(w, worldWidth, worldHeight);
    }
    final count = shots.length > ShotEvent.maxPerSnapshot
        ? ShotEvent.maxPerSnapshot
        : shots.length;
    w.u8(count);
    for (var i = 0; i < count; i++) {
      shots[i].write(w);
    }
    w.u16(aliens.length);
    for (final alien in aliens) {
      alien.write(w, worldWidth, worldHeight);
    }
    return w.take();
  }

  /// Çözme dünya ölçülerini bilmek zorunda ([ServerWelcome]'dan gelir) —
  /// kuantalama onlara göre yapıldı.
  /// [baseline] verilirse delta kayıtlar çözülebilir.
  ///
  /// Temeli çağıran tutuyor çünkü ömrü BAĞLANTIYA ait: yeniden bağlanan bir
  /// istemcinin eski temeli geçersizdir ve `clear()` edilmelidir. Çözücünün
  /// içinde saklanan bir temel, iki bağlantıyı birbirine karıştırırdı.
  static ServerSnapshot decodeWith(
    Uint8List bytes,
    double worldWidth,
    double worldHeight,
    ShipStats stats, [
    EntityBaseline? baseline,
  ]) {
    final r = ByteReader(bytes)..u8();
    return _read(r, worldWidth, worldHeight, stats, baseline);
  }

  static ServerSnapshot _read(
    ByteReader r, [
    // Varsayılan dünya ölçüsü, elle yazılmış bir kopya DEĞİL: harita alan
    // 11'den türetiliyor ve iki uç da aynı sabitten okumak zorunda, yoksa
    // kuantalama aralığı sessizce kayar.
    double worldWidth = GameWorld.tekBantGenislik,
    double worldHeight = GameWorld.tekBantYukseklik,
    ShipStats stats = ShipStats.bastion,
    EntityBaseline? baseline,
  ]) {
    final tick = r.u32();
    final self = SelfSnapshot.read(r, stats);
    final count = r.u16();
    final entities = <EntitySnapshot>[];
    for (var i = 0; i < count; i++) {
      entities.add(EntitySnapshot.read(r, worldWidth, worldHeight, baseline));
    }
    final shotCount = r.u8();
    final shots = <ShotEvent>[];
    for (var i = 0; i < shotCount; i++) {
      shots.add(ShotEvent.read(r));
    }
    final alienCount = r.u16();
    final aliens = <AlienSnapshot>[];
    for (var i = 0; i < alienCount; i++) {
      aliens.add(AlienSnapshot.read(r, worldWidth, worldHeight, baseline));
    }
    return ServerSnapshot(
      serverTick: tick,
      self: self,
      entities: entities,
      worldWidth: worldWidth,
      worldHeight: worldHeight,
      shots: shots,
      aliens: aliens,
    );
  }
}

/// Bir imhanın ödülü. YALNIZ öldüren oyuncuya gider.
///
/// **Neden ayrı bir mesaj, `ServerHangarState` değil.** Hangar durumu envanteri
/// ve donatımı taşıyan bir JSON; her imhada onu yollamak, saniyede onlarca
/// kilobayt eder ve değişen tek şey iki sayıdır. Bu mesaj 27 bayt.
///
/// **Neden hem kazanç hem BAKİYE var.** Kazanç arayüz için ("+400 KREDİ"
/// yazısı), bakiye ise gerçek için. İstemci kendi sayacını artırsaydı tek bir
/// kayıp mesaj cüzdanı kalıcı olarak ayrıştırırdı — ve para söz konusuyken
/// ayrışma, oyuncunun asla affetmediği hata türü. Sunucu ne diyorsa o.
/// İşaretli sayıyı işaretsiz alana sığdırır.
///
/// `(v << 1) ^ (v >> 63)`: küçük mutlak değerler küçük sayılara düşüyor. Ham
/// iki'ye tümleyen göndermek de çalışırdı ama −120 değeri 4.294.967.176 olarak
/// okunurdu; zigzag, hata hâlinde bile makul bir sayı bırakıyor.
int _zigzag(int v) => (v << 1) ^ (v >> 63);

/// Zigzag ÇÖZME — bit işleci YOK, ve bu bir üslup tercihi değil.
///
/// Doğal yazımı `(v >> 1) ^ -(v & 1)` ve VM'de doğru çalışıyor. Web'de
/// ÇALIŞMIYOR: dart2js her bit işlecini `(# ^ #) >>> 0` olarak derliyor, yani
/// sonuç DAİMA işaretsiz 32-bit. `-(v & 1)` ile üretilen −1, XOR'dan sonra
/// işaretini kaybediyor.
///
/// Somut: telden gelen 239, tamir bedeli −120'yi taşıyor. VM'de `119 ^ -1`
/// −120 veriyor; web'de `(-120) >>> 0` = **4.294.967.176**. Oyuncu, bakiyesi
/// 120 kredi DÜŞERKEN ekranda "+4.294.967.176 KREDİ" görüyor — ve hiçbir
/// istisna düşmüyor.
///
/// Kodlama yönü ([_zigzag]) güvenli: sonucu zaten işaretsiz, dolayısıyla
/// `>>> 0` bir şey değiştirmiyor. Bozulan yalnız ÇÖZME, ve çözmeyi hep
/// istemci yapıyor.
int _unzigzag(int v) => v.isOdd ? -(v ~/ 2) - 1 : v ~/ 2;

class ServerReward implements ServerMessage {
  const ServerReward({
    required this.sourceId,
    required this.credits,
    required this.premium,
    required this.balanceCredits,
    required this.balancePremium,
  });

  /// İmha edilen varlığın kimliği — arayüz yazıyı onun üstüne koyabilsin.
  final int sourceId;

  /// Bu olaydan kazanılan — EKSİ olabilir.
  ///
  /// Tamir bedeli aynı mesajla gidiyor: oyuncunun görmesi gereken şey aynı
  /// ("cüzdanım ne kadar değişti") ve ikinci bir mesaj tipi, arayüzde ikinci
  /// bir yol demekti. Eksi değer telde ZIGZAG kodlanıyor — `u32` eksiyi
  /// taşıyamaz ve maskeleyerek göndermek 4 milyarlık bir kazanç gibi
  /// görünürdü.
  final int credits;
  final int premium;

  /// Kazançtan SONRAKİ otoriter bakiye.
  ///
  /// `u64`, `u32` DEĞİL. Tavan sebebi: ömür boyu kredi musluğu **9.394.710.567**
  /// ve `u32` 4.294.967.295'te sarıyor — ölçüldü, 9.394.710.567 telden
  /// 804.775.975 olarak dönüyordu. Oyuncunun cüzdanı, hiçbir hata düşmeden,
  /// on ikide birine iniyordu.
  ///
  /// Kazanç ALANLARI (`credits` · `premium`) `u32` zigzag olarak kalıyor:
  /// onlar tek bir olayın kazancı, bakiyenin toplamı değil. En büyük tek olay
  /// son bandın boss ödülü (~12,6 milyon) ve zigzag `u32` ±2,1 milyar taşıyor
  /// — iki büyüklük mertebesi pay.
  final int balanceCredits;
  final int balancePremium;

  @override
  Uint8List encode() =>
      (ByteWriter(28)
            ..u8(Protocol.msgReward)
            ..u16(sourceId)
            ..u32(_zigzag(credits))
            ..u32(_zigzag(premium))
            ..u64(balanceCredits)
            ..u64(balancePremium))
          .take();

  static ServerReward _read(ByteReader r) => ServerReward(
    sourceId: r.u16(),
    credits: _unzigzag(r.u32()),
    premium: _unzigzag(r.u32()),
    balanceCredits: r.u64(),
    balancePremium: r.u64(),
  );
}

/// GANİMET — bir imhadan düşen eşya ve malzeme (14.1).
///
/// Ödülden AYRI bir mesaj, çünkü ayrı bir musluk: kredi yaratığın ödülü
/// olarak her öldürmede geliyor, eşya çekilişle ve seyrek. [ServerReward]
/// yalnız kazancı olan oyuncuya gidiyor; düşen eşya küçük pay alan oyuncuya
/// da düşebilir. Hangar durumu ayrıca gidiyor ve envanterin doğrusu o; bu
/// mesaj oyuncunun "ne düştü" sorusuna cevap. Görülmeyen ödül, olmayan
/// ödüldür: sunucu düşeni hangara yazıyordu ve HUD hiç söylemiyordu.
/// KARAR 14.1 s1
class ServerGanimet implements ServerMessage {
  const ServerGanimet({
    required this.sourceId,
    required this.esyalar,
    required this.malzemeRank,
    required this.malzeme,
  });

  /// İmha edilen varlığın kimliği.
  final int sourceId;

  /// Düşen eşyaların KATALOG kimlikleri, örnek kimliği değil. Arayüz adı ve
  /// rankı katalogdan okuyor; örnek kimliği hangar durumunda zaten var.
  final List<String> esyalar;

  /// Malzemenin rankı (`ItemTier` indeksi): bandın rankı, düşen eşyanınki
  /// gibi. [malzeme] sıfırsa anlamsız.
  final int malzemeRank;

  /// Düşen malzeme adedi.
  final int malzeme;

  /// Bir imhadan düşebilecek en çok eşya; sayaç tek bayt. Boss garantisi
  /// üç, tavanın çok altında.
  static const int maxEsya = 255;

  @override
  Uint8List encode() {
    assert(esyalar.length <= maxEsya, 'bir imhadan $maxEsya eşyadan fazla');
    final w = ByteWriter(32)
      ..u8(Protocol.msgGanimet)
      ..u16(sourceId)
      ..u8(esyalar.length);
    for (final id in esyalar) {
      w.str(id);
    }
    w
      ..u8(malzemeRank)
      ..u16(malzeme);
    return w.take();
  }

  static ServerGanimet _read(ByteReader r) {
    final sourceId = r.u16();
    final sayi = r.u8();
    final esyalar = [for (var i = 0; i < sayi; i++) r.str()];
    return ServerGanimet(
      sourceId: sourceId,
      esyalar: esyalar,
      malzemeRank: r.u8(),
      malzeme: r.u16(),
    );
  }
}
