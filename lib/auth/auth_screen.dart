import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voidspace_core/voidspace_core.dart';

import '../app/palette.dart';
import '../dil/dil.dart';
import '../dil/dil_kapsami.dart';
import '../dil/durum_metni.dart';
import '../dil/kimlik_metni.dart';
import '../dil/metin.dart';
import '../net/net_client.dart';
import '../net/net_phase.dart';

/// Kayıt / giriş ekranı.
///
/// Doğrulama İKİ KEZ yapılıyor ve bu tekrar değil:
///  * Burada, kullanıcı yazarken anında geri bildirim için.
///  * Sunucuda, OTORİTE olduğu için.
///
/// İkisi de [Credentials]'ı kullanıyor — kurallar ortak pakette olduğu için
/// ayrışmaları imkânsız. Ayrışsalardı istemcinin kabul ettiği bir parolayı
/// sunucu reddeder ve kullanıcı sebebini asla göremezdi.
/// Bir hızlı giriş hesabı.
typedef DevGiris = ({String ad, String parola});

/// `ad:parola,ad:parola` çözümler.
///
/// Ayrı bir fonksiyon çünkü `String.fromEnvironment` DERLEME ZAMANI: alanın
/// içinde kalsaydı ayrıştırma yalnız `--dart-define` ile koşan bir testte
/// sınanabilirdi. Bozuk bir tanım sessizce boş liste vermeli — düğmelerin
/// çıkmaması, yanlış kimlikle giriş denemekten iyi.
List<DevGiris> devLoginCozumle(String tanim) => [
  for (final parca in tanim.split(',')) ?_hesap(parca),
];

DevGiris? _hesap(String parca) {
  final ayirac = parca.indexOf(':');
  if (ayirac <= 0) return null;
  final ad = parca.substring(0, ayirac).trim();
  // Parola KIRPILMIYOR: baştaki ya da sondaki boşluk parolanın parçası
  // olabilir ve kırpmak, çalışan bir parolayı sessizce bozardı.
  final parola = parca.substring(ayirac + 1);
  if (ad.isEmpty || parola.isEmpty) return null;
  return (ad: ad, parola: parola);
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.client, super.key});

  final NetClient client;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _registering = false;

  @override
  void initState() {
    super.initState();
    // Alanlar ilk geliştirme hesabıyla DOLU açılıyor: düğmeye basmadan da
    // giriş yapılabilsin, ve parola alanı boş bir kutu olarak durmasın.
    // Sürüm yapısında liste boş, yani hiçbir şey doldurulmuyor.
    final hesap = _devGirisler.firstOrNull;
    if (hesap == null) return;
    _username.text = hesap.ad;
    _password.text = hesap.parola;
    _confirm.text = hesap.parola;
    _email.text = '${hesap.ad.toLowerCase()}@dev.local';
  }

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Formu yolla.
  ///
  /// Beklenmiyor: kimlik akışı ölü bir kanalı geri getirmek için bağlantı
  /// kurabiliyor ve o bekleyiş boyunca arayüzün donması gerekmiyor. İlerleme
  /// zaten fazdan okunuyor — düğme `authenticating` boyunca kapalı.
  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final client = widget.client;
    unawaited(
      _registering
          ? client.register(
              email: _email.text,
              username: _username.text,
              password: _password.text,
            )
          : client.login(username: _username.text, password: _password.text),
    );
  }

  /// GELİŞTİRME hızlı girişleri — `--dart-define=DEV_LOGIN=ad:parola,...`.
  ///
  /// **Kimlik bilgisi kodda YOK ve olmayacak.** Sunucudaki `DEV_RICH` ile aynı
  /// gerekçe: gömülü bir parola, üretim paketine derlenen bir arka kapıdır.
  /// Tanımsızsa liste boş, düğmeler hiç çizilmiyor.
  ///
  /// Biçim `ad:parola`; virgülle ayrılmış. Parola bu depoda hiçbir yerde
  /// yazılı değil ve olmamalı — çalıştıran kişi kendi verir.
  /// Geliştirme hesapları — `--dart-define=DEV_LOGIN=ad:parola,ad:parola`.
  ///
  /// HATA AYIKLAMA yapısında varsayılanı var, sürüm yapısında YOK ve olamaz:
  /// `kDebugMode` derleme zamanı sabiti, yani sürüm derlemesinde bu dize
  /// ikiliye hiç girmiyor. Geliştirirken her koşuda kimlik yazmak, oyunu
  /// açmanın önündeki en sık engeldi.
  static const String _devLoginTanim = String.fromEnvironment(
    'DEV_LOGIN',
    defaultValue: kDebugMode ? 'CINAR:12345678' : '',
  );

  static final List<({String ad, String parola})> _devGirisler = [
    for (final parca in _devLoginTanim.split(','))
      if (parca.trim().split(':') case [
        final ad,
        final parola,
      ] when ad.trim().isNotEmpty && parola.isNotEmpty)
        (ad: ad.trim(), parola: parola),
  ];

  /// Hesap yoksa KAYDET, sonra gir.
  ///
  /// İki adım tek düğmede: geliştirme hesabı ilk tıklamada doğuyor, sonraki
  /// tıklamalarda giriş yapıyor. Ayrı bir "kayıt" adımı, kolaylığın kendisini
  /// yok ederdi.
  Future<void> _devGiris(DevGiris hesap) async {
    final client = widget.client;
    await client.login(username: hesap.ad, password: hesap.parola);
    if (client.authError == null) return;
    await client.register(
      email: '${hesap.ad}@dev.local',
      username: hesap.ad,
      password: hesap.parola,
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final dil = context.dil;
    return StreamBuilder<void>(
      stream: client.changes,
      builder: (context, _) {
        final busy = client.phase == NetPhase.authenticating;
        final offline =
            client.phase == NetPhase.connecting ||
            client.phase == NetPhase.disconnected ||
            client.phase == NetPhase.idle;

        return Scaffold(
          backgroundColor: Palette.space,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        // Oyunun ADI — çevrilmiyor.
                        'VOIDSPACE',
                        textAlign: TextAlign.center,
                        style: Palette.label(
                          22,
                        ).copyWith(color: Palette.ink, letterSpacing: 6),
                      ),
                      const SizedBox(height: 20),
                      _DilSecici(
                        secili: dil,
                        onSec: DilKapsami.of(context).degistir,
                      ),
                      const SizedBox(height: 20),
                      _Toggle(
                        registering: _registering,
                        // Sekme değişince hata TEMİZLENİR: "parola yanlış"
                        // uyarısının kayıt formunun üstünde durması anlamsız.
                        onChanged: busy
                            ? null
                            : (value) => setState(() {
                                _registering = value;
                                client.authError = null;
                              }),
                      ),
                      const SizedBox(height: 20),

                      if (_registering) ...[
                        _Field(
                          controller: _email,
                          label: Metin.eposta(dil),
                          hint: Metin.epostaIpucu(dil),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              kimlikMetni(Credentials.checkEmail(v)?.kod, dil),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _Field(
                        controller: _username,
                        label: _registering
                            ? Metin.kullaniciAdi(dil)
                            : Metin.kullaniciAdiVeyaEposta(dil),
                        hint: _registering ? Metin.kullaniciIpucu(dil) : '',
                        // Girişte kullanıcı adı kuralları uygulanmaz: eski bir
                        // hesabın adı bugünkü kurallara uymuyor olabilir ve
                        // onu kendi hesabından kilitlemek olurdu.
                        validator: _registering
                            ? (v) => kimlikMetni(
                                Credentials.checkUsername(v)?.kod,
                                dil,
                              )
                            : (v) =>
                                  v.trim().isEmpty ? Metin.gerekli(dil) : null,
                      ),
                      const SizedBox(height: 12),

                      _Field(
                        controller: _password,
                        label: Metin.parola(dil),
                        obscure: true,
                        validator: _registering
                            ? (v) => kimlikMetni(
                                Credentials.checkPassword(v)?.kod,
                                dil,
                              )
                            : (v) => v.isEmpty ? Metin.gerekli(dil) : null,
                      ),

                      if (_registering) ...[
                        const SizedBox(height: 12),
                        _Field(
                          controller: _confirm,
                          label: Metin.parolaTekrar(dil),
                          obscure: true,
                          validator: (v) => v == _password.text
                              ? null
                              : Metin.parolalarEslesmiyor(dil),
                        ),
                      ],

                      const SizedBox(height: 22),
                      _Submit(
                        label: _registering
                            ? Metin.kayitOl(dil)
                            : Metin.girisYap(dil),
                        busy: busy,
                        // Sunucuya ulaşılamıyorken düğme kapalı: tıklanınca
                        // hiçbir şey olmaması, kapalı olmasından daha kötü.
                        onTap: busy || offline ? null : _submit,
                      ),

                      const SizedBox(height: 14),
                      _Status(
                        error: kimlikMetni(client.authError, dil),
                        offline: offline,
                        message: durumMetni(client.statusMessage, dil),
                        bekleniyor: Metin.sunucuyaBaglaniliyor(dil),
                      ),

                      // Hızlı girişler yalnız `DEV_LOGIN` tanımlıyken.
                      if (_devGirisler.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _DevBaslik(metin: Metin.gelistirmeGirisi(dil)),
                        const SizedBox(height: 8),
                        for (final hesap in _devGirisler) ...[
                          _Submit(
                            label: hesap.ad.toUpperCase(),
                            busy: busy,
                            onTap: busy || offline
                                ? null
                                : () => unawaited(_devGiris(hesap)),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hızlı giriş bölümünün başlığı — bunun bir GELİŞTİRME kapısı olduğunu
/// söylüyor. Sessiz bir kolaylık, üretime sızdığında fark edilmeyen bir
/// kolaylıktır.
class _DevBaslik extends StatelessWidget {
  const _DevBaslik({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) => Text(
    metin,
    textAlign: TextAlign.center,
    style: Palette.label(10).copyWith(
      color: Palette.hull,
      letterSpacing: 2,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.registering, required this.onChanged});

  final bool registering;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Tab(
          label: Metin.giris(context.dil),
          selected: !registering,
          onTap: onChanged == null ? null : () => onChanged!(false),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _Tab(
          label: Metin.kayitOl(context.dil),
          selected: registering,
          onTap: onChanged == null ? null : () => onChanged!(true),
        ),
      ),
    ],
  );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: selected ? Palette.panel : Colors.transparent,
        border: Border.all(color: selected ? Palette.shield : Palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Palette.label().copyWith(
          color: selected ? Palette.ink : Palette.inkDim,
        ),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.validator,
    this.hint = '',
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String) validator;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    autocorrect: false,
    enableSuggestions: !obscure,
    style: const TextStyle(color: Palette.ink, fontSize: 14),
    // Boş alan için de çağrılır; `validator` boş metni kendi kurallarıyla
    // değerlendirir.
    validator: (value) => validator(value ?? ''),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: Palette.label(),
      hintText: hint.isEmpty ? null : hint,
      hintStyle: Palette.label().copyWith(color: Palette.inkDim),
      filled: true,
      fillColor: Palette.panel,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Palette.shield),
        borderRadius: BorderRadius.circular(8),
      ),
      errorStyle: Palette.label().copyWith(color: Palette.hull),
    ),
  );
}

class _Submit extends StatelessWidget {
  const _Submit({required this.label, required this.busy, this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: onTap == null ? Palette.panel : Palette.shield,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: busy
          // Parola türetmesi sunucuda ~100 ms sürüyor: bekleme GERÇEKTEN
          // görünür ve gösterilmezse düğme çalışmıyor sanılır.
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Palette.ink,
              ),
            )
          : Text(
              label,
              style: Palette.label(
                13,
              ).copyWith(color: onTap == null ? Palette.inkDim : Palette.space),
            ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({
    required this.error,
    required this.offline,
    required this.message,
    required this.bekleniyor,
  });

  final String? error;
  final bool offline;
  final String? message;

  /// Sunucudan henüz bir sebep gelmemişken gösterilen satır.
  final String bekleniyor;

  @override
  Widget build(BuildContext context) {
    // Sunucuya ulaşılamaması, parolanın yanlış olmasından farklı bir sorun ve
    // farklı görünmeli: biri kullanıcının düzeltebileceği, diğeri değil.
    final text = error ?? (offline ? (message ?? bekleniyor) : null);
    if (text == null) return const SizedBox(height: 18);
    return SizedBox(
      height: 18,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Palette.label().copyWith(
          color: error != null ? Palette.hull : Palette.inkDim,
        ),
      ),
    );
  }
}

/// DİL SEÇİCİ — üç dil, tek şerit.
///
/// Kimlik ekranında duruyor çünkü oyuncunun gördüğü İLK ekran burası: dili
/// hangar menüsünün derinine gömmek, yanlış dilde açılan oyunu okuyamayan
/// birinden onu bulmasını istemek olurdu.
///
/// Ad her dilde KENDİ dilinde yazılı ("Italiano", "Türkçe") — bkz. [Dil.ad].
class _DilSecici extends StatelessWidget {
  const _DilSecici({required this.secili, required this.onSec});

  final Dil secili;
  final ValueChanged<Dil> onSec;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final d in Dil.values) ...[
        if (d != Dil.values.first) const SizedBox(width: 8),
        Expanded(
          child: _Tab(
            label: d.ad.toUpperCase(),
            selected: d == secili,
            onTap: () => onSec(d),
          ),
        ),
      ],
    ],
  );
}
