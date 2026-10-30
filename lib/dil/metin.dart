import 'dil.dart';

/// ARAYÜZ METİNLERİ — üç dil, tek satırda.
///
/// **Neden bir enum, neden `Map<String, String>` değil.** Anahtarı dize olan
/// bir sözlükte eksik çeviri ancak ÇALIŞIRKEN belli olur, ve yazım hatası
/// (`'kapat'` yerine `'kapt'`) derleyiciden geçer. Enum'da ikisi de imkânsız:
/// `Metin.kapat` yanlış yazılırsa derlenmez, ve üç dizeyi de vermeyen bir
/// değer TANIMLANAMAZ. "Bir dilde eksik metin" diye bir durum yok — çeviri
/// eksikse dosya derlenmiyor.
///
/// **Neden yan yana.** Aynı metnin üç karşılığı aynı satırda duruyor. Ayrı
/// dosyalara bölmek (`tr.dart`, `en.dart`) tek bir metni değiştirmek için üç
/// dosya açtırır ve birinde unutmayı kolaylaştırır; yan yana durduklarında
/// eksik olan göze çarpıyor.
///
/// **Yer tutucular.** Sayı ve ad taşıyan metinler `{ad}` biçiminde yer tutucu
/// kullanıyor ve [bicim] ile doldurulur. Dize birleştirmek (`'SEVİYE ' + n`)
/// çeviriyi imkânsız kılardı: İtalyanca'da sayı önce gelir, Türkçe'de sonra.
/// Yüzde işareti de aynı sebeple metnin İÇİNDE — Türkçe `%15` yazar,
/// İngilizce `15%`.
enum Metin {
  // ── Ortak eylemler ve durumlar ──────────────────────────────────────
  kapat('KAPAT', 'CLOSE', 'CHIUDI'),
  vazgec('VAZGEÇ', 'CANCEL', 'ANNULLA'),
  uygula('UYGULA', 'APPLY', 'APPLICA'),
  sec('SEÇ', 'SELECT', 'SELEZIONA'),
  tak('TAK', 'EQUIP', 'EQUIPAGGIA'),
  cikar('ÇIKAR', 'REMOVE', 'RIMUOVI'),
  aktif('AKTİF', 'ACTIVE', 'ATTIVA'),
  etkin('ETKİN', 'ACTIVE', 'ATTIVO'),
  kilitli('KİLİTLİ', 'LOCKED', 'BLOCCATO'),
  bos('BOŞ', 'EMPTY', 'VUOTO'),
  dolu('DOLU', 'FULL', 'PIENO'),
  maks('MAKS', 'MAX', 'MAX'),
  bilgi('BİLGİ', 'INFO', 'INFO'),
  yakinda('YAKINDA', 'COMING SOON', 'IN ARRIVO'),
  satista('SATIŞTA', 'ON SALE', 'IN VENDITA'),
  fiyat('FİYAT', 'PRICE', 'PREZZO'),
  satinAl('SATIN AL', 'BUY', 'ACQUISTA'),
  sahip('SAHİP', 'OWNED', 'POSSEDUTO'),
  sahipsin('SAHİPSİN', 'OWNED', 'GIÀ TUO'),
  seviye('SEVİYE', 'LEVEL', 'LIVELLO'),
  islem('İŞLEM', 'ACTION', 'AZIONE'),

  // ── Gemi ölçüleri ───────────────────────────────────────────────────
  govde('GÖVDE', 'HULL', 'SCAFO'),
  kalkan('KALKAN', 'SHIELD', 'SCUDO'),
  hiz('HIZ', 'SPEED', 'VELOCITÀ'),
  hasar('HASAR', 'DAMAGE', 'DANNO'),
  menzil('MENZİL', 'RANGE', 'GITTATA'),
  itki('İTKİ', 'BOOST', 'SPINTA'),
  silah('SİLAH', 'WEAPON', 'ARMA'),
  hedef('HEDEF', 'TARGET', 'BERSAGLIO'),
  ates('ATEŞ', 'FIRE', 'FUOCO'),

  // ── Yuva türleri ────────────────────────────────────────────────────
  yuvaLazer('LAZER', 'LASER', 'LASER'),
  yuvaJenerator('JENERATÖR', 'GENERATOR', 'GENERATORE'),
  yuvaRoketatar('ROKETATAR', 'LAUNCHER', 'LANCIARAZZI'),
  yuvaCpu('CPU', 'CPU', 'CPU'),
  yuvaDroid('DROİD', 'DROID', 'DROIDE'),

  // ── Hangar ──────────────────────────────────────────────────────────
  hangar('HANGAR', 'HANGAR', 'HANGAR'),
  magaza('MAĞAZA', 'STORE', 'NEGOZIO'),
  donanim('DONANIM', 'LOADOUT', 'EQUIPAGGIAMENTO'),
  depo('DEPO', 'STORAGE', 'DEPOSITO'),
  malzeme('MALZEME', 'MATERIALS', 'MATERIALI'),
  hangarYukleniyor(
    'HANGAR YÜKLENİYOR…',
    'LOADING HANGAR…',
    'CARICAMENTO HANGAR…',
  ),
  gemiDegistir('GEMİ DEĞİŞTİR', 'CHANGE SHIP', 'CAMBIA NAVE'),
  gemiKisa('GEMİ', 'SHIP', 'NAVE'),
  sokKisa('SÖK', 'STRIP', 'RIMUOVI'),
  tumunuSok('TÜMÜNÜ SÖK', 'UNEQUIP ALL', 'RIMUOVI TUTTO'),
  otomatikDonat('OTOMATİK DONAT', 'AUTO-EQUIP', 'EQUIP. AUTO'),
  donat('DONAT', 'AUTO', 'AUTO'),
  droidFilosu('DROİD FİLOSU', 'DROID FLEET', 'FLOTTA DROIDI'),
  filo('FİLO', 'FLEET', 'FLOTTA'),
  birYuvaSec('BİR YUVA SEÇ', 'SELECT A SLOT', 'SELEZIONA UNO SLOT'),
  depodaParcaYok(
    'DEPODA PARÇA YOK',
    'NO PARTS IN STORAGE',
    'NESSUN PEZZO IN DEPOSITO',
  ),
  yuvaBosSatiri(
    '{yuva} #{no} · BOŞ',
    '{yuva} #{no} · EMPTY',
    '{yuva} #{no} · VUOTO',
  ),
  govdeSinifYuva(
    '{rank} SINIF · {yuva} YUVA',
    '{rank} CLASS · {yuva} SLOTS',
    'CLASSE {rank} · {yuva} SLOT',
  ),
  govdeRankYuva(
    '{rank} · {yuva} YUVA',
    '{rank} · {yuva} SLOTS',
    '{rank} · {yuva} SLOT',
  ),
  tavanArti('TAVAN · +{n}', 'MAX · +{n}', 'LIMITE · +{n}'),
  yukselt('YÜKSELT', 'UPGRADE', 'POTENZIA'),
  filodanCikar('FİLODAN ÇIKAR', 'REMOVE FROM FLEET', 'RIMUOVI DALLA FLOTTA'),
  filoyaAl('FİLOYA AL', 'ADD TO FLEET', 'AGGIUNGI ALLA FLOTTA'),
  filoDolu('FİLO DOLU', 'FLEET FULL', 'FLOTTA PIENA'),
  filoBosYer('BOŞ YER {no}', 'EMPTY BAY {no}', 'POSTO LIBERO {no}'),
  droidSecBos('DEPODAN DROİD SEÇ', 'PICK A DROID', 'SCEGLI UN DROIDE'),
  malzemeTurSayisi('{n} TÜR', '{n} TYPES', '{n} TIPI'),
  malzemeYok(
    'MALZEME YOK · YARATIK ÖLDÜR YA DA PARÇA PARÇALA',
    'NO MATERIALS · KILL CREATURES OR SCRAP PARTS',
    'NIENTE MATERIALI · UCCIDI CREATURE O SMONTA PEZZI',
  ),
  parcaSayisi('{n} PARÇA', '{n} PARTS', '{n} PEZZI'),
  aktifGemiyiSec(
    'AKTİF GEMİYİ SEÇ',
    'SELECT ACTIVE SHIP',
    'SELEZIONA NAVE ATTIVA',
  ),
  kilitliGemilerMagazadan(
    'KİLİTLİ GEMİLER MAĞAZADAN ALINIR.',
    'LOCKED SHIPS ARE BOUGHT IN THE STORE.',
    'LE NAVI BLOCCATE SI ACQUISTANO NEL NEGOZIO.',
  ),

  // ── Sentez ve parçalama ─────────────────────────────────────────────
  sentez('SENTEZ', 'SYNTHESIS', 'SINTESI'),
  parcala('PARÇALA', 'SCRAP', 'SMONTA'),
  parcaSec('PARÇA SEÇ', 'SELECT PARTS', 'SELEZIONA PEZZI'),
  seciliSayisi('{n} SEÇİLİ', '{n} SELECTED', '{n} SELEZIONATI'),
  ayniRanktanSec(
    'AYNI RANKTAN {n} PARÇA SEÇ',
    'SELECT {n} PARTS OF THE SAME RANK',
    'SELEZIONA {n} PEZZI DELLO STESSO RANGO',
  ),
  merdiveninTepesi(
    'MERDİVENİN TEPESİ',
    'TOP OF THE LADDER',
    'CIMA DELLA SCALA',
  ),
  ranklarKarisik('RANKLAR KARIŞIK', 'MIXED RANKS', 'RANGHI MISTI'),
  parcalarsan('PARÇALARSAN', 'IF YOU SCRAP', 'SE SMONTI'),
  parcalamaKazanci(
    '{n} {rank} MALZEME',
    '{n} {rank} MATERIALS',
    '{n} MATERIALI {rank}',
  ),

  // ── Çevirme ─────────────────────────────────────────────────────────
  cevir('ÇEVİR', 'REROLL', 'RITIRA'),
  cevirici('ÇEVİRİCİ', 'REROLLER', 'RITIRATORE'),
  ceviriciKilitli(
    'ÇEVİRİCİ · {n} KİLİTLİ',
    'REROLLER · {n} LOCKED',
    'RITIRATORE · {n} BLOCCATE',
  ),
  cevirKalitesi('ÇEVİR KALİTESİ', 'REROLL QUALITY', 'QUALITÀ RITIRO'),
  buRoluSileceksin(
    'BU ROLÜ SİLECEKSİN',
    'YOU WILL ERASE THIS ROLL',
    'CANCELLERAI QUESTO TIRO',
  ),
  cevirmeUyarisi(
    'Son çevirme {statlar} değerini YÜKSELTTİ. Kilitlemeden yeniden '
        'çevirmek bu değeri siler ve geri getirilemez.',
    'The last reroll RAISED {statlar}. Rerolling without locking it '
        'erases that value for good.',
    "L'ultimo tiro ha AUMENTATO {statlar}. Ritirare senza bloccarla "
        'cancella quel valore per sempre.',
  ),
  yineDeCevir('YİNE DE ÇEVİR', 'REROLL ANYWAY', 'RITIRA COMUNQUE'),

  // ── Eşya sayfası ────────────────────────────────────────────────────
  gelistirme('GELİŞTİRME', 'DEVELOPMENT', 'SVILUPPO'),
  sonrakiSeviye('SONRAKİ SEVİYE', 'NEXT LEVEL', 'LIVELLO SUCCESSIVO'),
  altStatArtisi(
    'BİR ALT STAT +%{n}',
    'ONE SUB-STAT +{n}%',
    'UNA SOTTOSTAT +{n}%',
  ),
  dayaniklilik('DAYANIKLILIK', 'DURABILITY', 'DURABILITÀ'),
  olumSayisi('{n} ÖLÜM', '{n} DEATHS', '{n} MORTI'),
  onarimBasligi('ONARIM', 'REPAIR', 'RIPARAZIONE'),
  onar('ONAR', 'REPAIR', 'RIPARA'),
  droideTak('DROİDE TAK', 'EQUIP TO DROID', 'EQUIPAGGIA AL DROIDE'),
  droidYuvasi(
    'DROİD YUVASI · {dolu}/{tavan}',
    'DROID SLOTS · {dolu}/{tavan}',
    'SLOT DROIDE · {dolu}/{tavan}',
  ),
  bosYuvaLazerJenerator(
    'BOŞ YUVA · LAZER YA DA JENERATÖR',
    'EMPTY SLOT · LASER OR GENERATOR',
    'SLOT VUOTO · LASER O GENERATORE',
  ),
  rankCarpani('RANK ÇARPANI', 'RANK MULTIPLIER', 'MOLTIPLICATORE RANGO'),
  altStatSayaci(
    'ALT STAT  {dolu}/{derinlik}',
    'SUB-STAT  {dolu}/{derinlik}',
    'SOTTOSTAT  {dolu}/{derinlik}',
  ),
  kaliteBandi(
    'KALİTE BANDI %{taban}–100',
    'QUALITY BAND {taban}–100%',
    'FASCIA QUALITÀ {taban}–100%',
  ),
  kaliteBandiGarantili(
    'KALİTE BANDI %{taban}–100 · {garanti} GARANTİLİ',
    'QUALITY BAND {taban}–100% · {garanti} GUARANTEED',
    'FASCIA QUALITÀ {taban}–100% · {garanti} GARANTITE',
  ),

  // ── Mağaza ──────────────────────────────────────────────────────────
  magazaGemi('GEMİ', 'SHIPS', 'NAVI'),
  magazaSistem('SİSTEM', 'SYSTEMS', 'SISTEMI'),
  magazaMermi('MERMİ', 'AMMO', 'MUNIZIONI'),
  magazaRoket('ROKET', 'ROCKETS', 'RAZZI'),
  magazaTasarim('TASARIM', 'DESIGN', 'DESIGN'),
  magazaFormasyon('FORMASYON', 'FORMATION', 'FORMAZIONE'),
  kategoriler('KATEGORİLER', 'CATEGORIES', 'CATEGORIE'),
  fiyatlarSunucudan(
    'FİYATLAR SUNUCUNUN\nKATALOĞUNDAN.',
    'PRICES COME FROM THE\nSERVER CATALOGUE.',
    'I PREZZI VENGONO DAL\nCATALOGO DEL SERVER.',
  ),
  urunSayisi('{n} ÜRÜN', '{n} ITEMS', '{n} ARTICOLI'),
  tabanAltStatYok(
    'TABAN · ALT STAT YOK',
    'BASE · NO SUB-STATS',
    'BASE · NESSUNA SOTTOSTAT',
  ),
  salvoTabani('×{n} SALVO TABANI', '×{n} SALVO BASE', '×{n} BASE SALVA'),
  kalkanaCarpan(
    '×{n} KALKANA · GÖVDEYE 0',
    '×{n} TO SHIELD · 0 TO HULL',
    '×{n} ALLO SCUDO · 0 ALLO SCAFO',
  ),
  tabanHasarCarpan('×{n} TABAN HASAR', '×{n} BASE DAMAGE', '×{n} DANNO BASE'),
  bedavaSinirsiz(
    'BEDAVA · SINIRSIZ',
    'FREE · UNLIMITED',
    'GRATIS · ILLIMITATO',
  ),
  stokAdedi('STOK {n}', 'STOCK {n}', 'SCORTA {n}'),
  paketAl('{paket} AL', 'BUY {paket}', 'ACQUISTA {paket}'),

  // ── HUD ─────────────────────────────────────────────────────────────
  galaksi('GALAKSİ', 'GALAXY', 'GALASSIA'),
  gecitGec('GEÇ  →  {ad}', 'JUMP  →  {ad}', 'SALTA  →  {ad}'),
  gecitSeviyeGerek(
    '{ad}  ·  KİLİTLİ · SEVİYE {n} GEREK',
    '{ad}  ·  LOCKED · LEVEL {n} REQUIRED',
    '{ad}  ·  BLOCCATO · SERVE LIVELLO {n}',
  ),
  gecitBrGerek(
    '{ad}  ·  KİLİTLİ +{n} BR',
    '{ad}  ·  LOCKED +{n} BR',
    '{ad}  ·  BLOCCATO +{n} BR',
  ),
  reddedildi('REDDEDİLDİ', 'REJECTED', 'RIFIUTATO'),
  baglantiKoptu('BAĞLANTI KOPTU', 'CONNECTION LOST', 'CONNESSIONE PERSA'),
  baglaniliyorBuyuk('BAĞLANILIYOR', 'CONNECTING', 'CONNESSIONE'),
  yenidenDeneniyor('yeniden deneniyor…', 'retrying…', 'nuovo tentativo…'),
  mermiSeridiBasligi(
    'MERMİ · TABAN HASARI ÇARPAR · STOK MAĞAZADAN · BİTEN MR-1\'E DÜŞER',
    'AMMO · MULTIPLIES BASE DAMAGE · STOCK FROM THE STORE · '
        'FALLS BACK TO MR-1',
    'MUNIZIONI · MOLTIPLICA IL DANNO BASE · SCORTE DAL NEGOZIO · '
        'ESAURITE TORNA A MR-1',
  ),
  roketSeridiBasligi(
    'ROKET · SALVONUN TABANINI ÇARPAR · BİTEN RK-1\'E DÜŞER',
    'ROCKETS · MULTIPLY THE SALVO BASE · FALL BACK TO RK-1',
    'RAZZI · MOLTIPLICANO LA BASE DELLA SALVA · ESAURITI TORNA A RK-1',
  ),
  formasyonSeridiBasligi(
    'FORMASYON · {egilim}',
    'FORMATION · {egilim}',
    'FORMAZIONE · {egilim}',
  ),
  egilimSaldiri(
    'SALDIRI · σ YUKARI, HAVUZ AŞAĞI',
    'ATTACK · σ UP, POOL DOWN',
    'ATTACCO · σ SU, RISERVA GIÙ',
  ),
  egilimSavunma(
    'SAVUNMA · σ AŞAĞI, HAVUZ YUKARI',
    'DEFENCE · σ DOWN, POOL UP',
    'DIFESA · σ GIÙ, RISERVA SU',
  ),
  egilimDenge(
    'DENGE · TAKAS YOK',
    'BALANCE · NO TRADE-OFF',
    'EQUILIBRIO · NESSUNO SCAMBIO',
  ),
  cihaziYatayCevir(
    'CİHAZI YATAY ÇEVİR',
    'ROTATE YOUR DEVICE',
    'RUOTA IL DISPOSITIVO',
  ),
  dikeyEkranUyarisi(
    'dikey ekranda menzilinin yarısını göremezsin',
    'in portrait you cannot see half your range',
    'in verticale non vedi metà della tua gittata',
  ),

  // ── Hangar reddi — sunucudan `HangarError.name` olarak gelir ────────
  hataNotPurchasable(
    'Bu gemi henüz satışta değil',
    'This ship is not on sale yet',
    'Questa nave non è ancora in vendita',
  ),
  hataKilitli(
    'Bu sistem henüz açık değil',
    'This system is not unlocked yet',
    'Questo sistema non è ancora sbloccato',
  ),
  hataFiloDolu(
    'Droid filosu dolu',
    'The droid fleet is full',
    'La flotta droidi è piena',
  ),
  hataMermiYok(
    'Bu mermiden yok',
    'You have none of that ammo',
    'Non hai queste munizioni',
  ),
  hataRoketYok(
    'Bu roketten yok',
    'You have none of that rocket',
    'Non hai questi razzi',
  ),
  hataNovaYok('Yeterli NOVA yok', 'Not enough NOVA', 'NOVA insufficienti'),
  hataEsyaYok('Eşya bulunamadı', 'Item not found', 'Oggetto non trovato'),
  hataSendeYok(
    'Bu eşya sende yok',
    'You do not own that item',
    'Non possiedi questo oggetto',
  ),
  hataYanlisYuva(
    'Bu eşya o yuvaya girmiyor',
    'That item does not fit that slot',
    'Questo oggetto non entra in quello slot',
  ),
  hataYuvaYok(
    'Bu gemide öyle bir yuva yok',
    'This ship has no such slot',
    'Questa nave non ha quello slot',
  ),
  hataParaYetmiyor(
    'Yeterli paran yok',
    'Not enough money',
    'Fondi insufficienti',
  ),
  hataZatenSahip('Zaten sahipsin', 'You already own it', 'Lo possiedi già'),
  hataSonSeviye(
    'Bu eşya son seviyede',
    'This item is at max level',
    'Questo oggetto è al livello massimo',
  ),
  hataMalzemeYetmiyor(
    'Bu rankın malzemesi yetmiyor',
    'Not enough materials of that rank',
    'Materiali di questo rango insufficienti',
  ),
  hataTakili(
    'Takılı eşya için önce çıkar',
    'Unequip the item first',
    'Prima rimuovi l\'oggetto',
  ),
  hataYeterliEsyaYok(
    'Aynı ranktan yeterli eşya yok',
    'Not enough items of the same rank',
    'Non hai abbastanza oggetti dello stesso rango',
  ),
  hataTepedeSin(
    'Merdivenin tepesi — üstü yok',
    'Top of the ladder — nothing above',
    'Cima della scala — non c\'è altro',
  ),

  // ── Geçit reddi — sunucudan KOD olarak gelir (bkz. `GecitKodu`) ─────
  gecitMenzilDisi(
    'geçit menzilinde değilsin',
    'you are not in gate range',
    'non sei nel raggio del portale',
  ),
  gecitBrYetmiyor(
    'savaş puanı yetmiyor · {n} gerek',
    'battle rating too low · {n} required',
    'punteggio di combattimento troppo basso · servono {n}',
  ),
  gecitSeviyeYetmiyor(
    'seviye yetmiyor · {n} gerek',
    'level too low · {n} required',
    'livello troppo basso · serve {n}',
  ),
  gecitHaritaDolu('harita dolu', 'map is full', 'mappa piena'),
  gecitBasarisiz('geçiş başarısız', 'jump failed', 'salto fallito'),

  // ── Galaksi haritası ────────────────────────────────────────────────
  savasPuani(
    'SAVAŞ PUANI {n}',
    'BATTLE RATING {n}',
    'PUNTEGGIO DI COMBATTIMENTO {n}',
  ),
  haritaAcik(
    '{acik}/{hepsi} HARİTA AÇIK',
    '{acik}/{hepsi} MAPS OPEN',
    '{acik}/{hepsi} MAPPE APERTE',
  ),
  buradasin('BURADASIN', 'YOU ARE HERE', 'SEI QUI'),
  serbest('SERBEST', 'FREE', 'LIBERA'),
  galaksiEfsanesi(
    'ÇİZGİLER GEÇİT  ·  YUKARI PvP  ·  AŞAĞI BOSS  ·  SAĞA BİR SONRAKİ BÖLGE',
    'LINES ARE GATES  ·  UP PvP  ·  DOWN BOSS  ·  RIGHT NEXT REGION',
    'LE LINEE SONO PORTALI  ·  SU PvP  ·  GIÙ BOSS  ·  DESTRA REGIONE SUCCESSIVA',
  ),

  // ── Ünvan merdiveni ─────────────────────────────────────────────────
  merdiven('MERDİVEN', 'LADDER', 'SCALA'),
  cagKademe(
    '{cag} ÇAĞI · KADEME {kademe} / {tavan}',
    'AGE OF {cag} · TIER {kademe} / {tavan}',
    'ERA {cag} · GRADO {kademe} / {tavan}',
  ),
  merdiveninTepesiBr(
    'MERDİVENİN TEPESİ · {br} BR',
    'TOP OF THE LADDER · {br} BR',
    'CIMA DELLA SCALA · {br} BR',
  ),
  sonrakiUnvan('SONRAKİ · {ad}', 'NEXT · {ad}', 'PROSSIMO · {ad}'),
  seviyeVeBr(
    '· SEVİYE {seviye} · {br} BR',
    '· LEVEL {seviye} · {br} BR',
    '· LIVELLO {seviye} · {br} BR',
  ),

  // ── ArGe ağacı ──────────────────────────────────────────────────────
  //
  // Kısaltma her dilde KENDİ kısaltması: ArGe Türkçe "araştırma ve
  // geliştirme", İngilizce R&D, İtalyanca R&S. Kısaltmayı olduğu gibi
  // bırakmak, üç dilde de Türkçe bir terim göstermek olurdu.
  argeAgaci('ARGE AĞACI', 'R&D TREE', 'ALBERO R&S'),
  argeOzeti(
    'ARGE · {harcanan}/{toplam} PUAN',
    'R&D · {harcanan}/{toplam} POINTS',
    'R&S · {harcanan}/{toplam} PUNTI',
  ),
  argePuanSayaci(
    'HARCANAN {harcanan} / {toplam}',
    'SPENT {harcanan} / {toplam}',
    'SPESI {harcanan} / {toplam}',
  ),
  argeKalanPuan('KALAN {n}', '{n} LEFT', '{n} RIMASTI'),
  argeMaliyet('{n} PUAN', '{n} PTS', '{n} PT'),
  // Ağacın ne yaptığı TEK CÜMLEDE: oyuncu "hangi düğüm daha çok hasar
  // veriyor" diye bakıyor ve cevap "hiçbiri" (05.7). Bunu söylemeyen bir
  // ekran, ağacı zayıf bir güç ağacı gibi gösterirdi.
  argeGucVermez(
    'GÜÇ VERMEZ · GÜCÜ TAŞIR',
    'NO RAW POWER · IT MOVES POWER',
    'NESSUNA POTENZA · LA SPOSTA',
  ),
  // DALIN ETKİSİ, σ HARFİ OLMADAN.
  //
  // Belgeler ve HUD'un formasyon şeridi aktarım katsayısını `σ` diye yazıyor
  // (05.5) ve buraya da öyle yazılmıştı — görsel referans onu BOŞ KUTU olarak
  // çizdi: menünün tek aralıklı yüzünde Yunan harfi yok. Aynı sebeple '⇄' ve
  // '✓' de bir zamanlar kutu çıkmıştı. Kelime üstelik daha dürüst: oyuncu
  // σ'nın ne olduğunu bilmiyor, "gücün nereye gittiğini" biliyor — ve 05.7'nin
  // kendi cümlesi de bu: toplam güç değişmiyor, YERİ değişiyor.
  argeGucDroide(
    'GÜÇ DROİDE KAYAR',
    'POWER MOVES TO DROIDS',
    'POTENZA AI DROIDI',
  ),
  argeGucGemide(
    'GÜÇ GEMİDE KALIR',
    'POWER STAYS ON THE SHIP',
    'POTENZA SULLA NAVE',
  ),
  argeSayiDegilIzin(
    'SAYI DEĞİL İZİN',
    'A PERMIT, NOT A NUMBER',
    'UN PERMESSO, NON UN NUMERO',
  ),
  argeAktarim('AKTARIM {n}', 'TRANSFER {n}', 'TRASFERIMENTO {n}'),
  argeAlindi('ALINDI', 'TAKEN', 'PRESO'),
  argeOncekiGerek(
    'ÖNCEKİ DÜĞÜM GEREK',
    'NEEDS THE PREVIOUS NODE',
    'SERVE IL NODO PRECEDENTE',
  ),
  argePuanYetmiyor('PUAN YETMİYOR', 'NOT ENOUGH POINTS', 'PUNTI INSUFFICIENTI'),
  argeSifirla('AĞACI SIFIRLA', 'RESET TREE', 'AZZERA ALBERO'),
  argeSifirlamaBedava(
    'SIFIRLAMA BEDAVA VE SINIRSIZ',
    'RESETTING IS FREE AND UNLIMITED',
    'AZZERARE È GRATIS E ILLIMITATO',
  ),
  argePuanSeviyeden(
    'PUAN SEVİYEDEN · SEVİYE BAŞINA BİR',
    'POINTS COME FROM LEVELS · ONE PER LEVEL',
    'I PUNTI VENGONO DAI LIVELLI · UNO PER LIVELLO',
  ),

  // ── Kimlik ekranı ───────────────────────────────────────────────────
  eposta('E-POSTA', 'EMAIL', 'EMAIL'),
  epostaIpucu('ornek@posta.com', 'name@mail.com', 'nome@posta.com'),
  kullaniciAdi('KULLANICI ADI', 'USERNAME', 'NOME UTENTE'),
  kullaniciAdiVeyaEposta(
    'KULLANICI ADI VEYA E-POSTA',
    'USERNAME OR EMAIL',
    'NOME UTENTE O EMAIL',
  ),
  kullaniciIpucu(
    'harf, rakam, alt çizgi',
    'letters, digits, underscore',
    'lettere, cifre, trattino basso',
  ),
  gerekli('Gerekli', 'Required', 'Obbligatorio'),
  parola('PAROLA', 'PASSWORD', 'PASSWORD'),
  parolaTekrar('PAROLA TEKRAR', 'REPEAT PASSWORD', 'RIPETI PASSWORD'),
  parolalarEslesmiyor(
    'Parolalar eşleşmiyor',
    'Passwords do not match',
    'Le password non coincidono',
  ),
  kayitOl('KAYIT OL', 'SIGN UP', 'REGISTRATI'),
  girisYap('GİRİŞ YAP', 'LOG IN', 'ACCEDI'),
  giris('GİRİŞ', 'LOG IN', 'ACCESSO'),
  gelistirmeGirisi('GELİŞTİRME GİRİŞİ', 'DEV LOGIN', 'ACCESSO SVILUPPO'),
  sunucuyaBaglaniliyor(
    'sunucuya bağlanılıyor…',
    'connecting to server…',
    'connessione al server…',
  ),

  // ── Ağ durumu ───────────────────────────────────────────────────────
  agBaglaniliyor('bağlanılıyor…', 'connecting…', 'connessione…'),
  agKapandi('bağlantı kapandı', 'connection closed', 'connessione chiusa'),
  agHatasi('bağlantı hatası', 'connection error', 'errore di connessione'),
  agUlasilamadi(
    'sunucuya ulaşılamadı',
    'server unreachable',
    'server irraggiungibile',
  ),
  agBozukSnapshot(
    'sunucudan bozuk snapshot',
    'corrupt snapshot from server',
    'snapshot corrotto dal server',
  ),
  agBozukCerceve(
    'sunucudan bozuk çerçeve',
    'corrupt frame from server',
    'frame corrotto dal server',
  ),
  agGonderilemedi('gönderilemedi', 'send failed', 'invio fallito'),
  agArkaPlanda('arka planda', 'in background', 'in secondo piano'),
  agAtlasYuklenemedi(
    'gemi atlası yüklenemedi',
    'ship atlas failed to load',
    "impossibile caricare l'atlante navi",
  ),

  // ── Kimlik hataları — sunucudan KOD olarak gelir (bkz. `KimlikKodu`) ─
  hataKullaniciAlinmis(
    'Bu kullanıcı adı alınmış',
    'That username is taken',
    'Questo nome utente è già preso',
  ),
  hataEpostaAlinmis(
    'Bu e-posta ile bir hesap zaten var',
    'An account with that email already exists',
    'Esiste già un account con questa email',
  ),
  hataHataliGiris(
    'Kullanıcı adı ya da parola hatalı',
    'Wrong username or password',
    'Nome utente o password errati',
  ),
  hataSunucuHatasi(
    'Sunucu hatası, tekrar deneyin',
    'Server error, please try again',
    'Errore del server, riprova',
  ),
  hataSunucuDolu('sunucu dolu', 'server full', 'server pieno'),
  hataCokFazlaDeneme(
    'Çok fazla deneme',
    'Too many attempts',
    'Troppi tentativi',
  ),
  hataOturumDoldu(
    'oturum süresi doldu, yeniden giriş yapın',
    'session expired, please sign in again',
    'sessione scaduta, accedi di nuovo',
  ),
  hataBaskaCihaz(
    'başka bir cihazdan giriş yapıldı',
    'signed in from another device',
    'accesso effettuato da un altro dispositivo',
  ),
  hataSurumUyusmazligi(
    'protokol v{gerekli} gerekiyor, v{gelen} geldi',
    'protocol v{gerekli} required, got v{gelen}',
    'richiesto protocollo v{gerekli}, ricevuto v{gelen}',
  ),
  hataKullaniciKisa(
    'Kullanıcı adı en az {n} karakter olmalı',
    'Username must be at least {n} characters',
    'Il nome utente deve avere almeno {n} caratteri',
  ),
  hataKullaniciUzun(
    'Kullanıcı adı en fazla {n} karakter olabilir',
    'Username can be at most {n} characters',
    'Il nome utente può avere al massimo {n} caratteri',
  ),
  hataKullaniciBicim(
    'Yalnız harf, rakam ve alt çizgi kullanılabilir',
    'Only letters, digits and underscore are allowed',
    'Sono ammessi solo lettere, cifre e trattino basso',
  ),
  hataEpostaGerekli(
    'E-posta gerekli',
    'Email is required',
    'Email obbligatoria',
  ),
  hataEpostaUzun('E-posta çok uzun', 'Email is too long', 'Email troppo lunga'),
  hataEpostaBicim(
    'E-posta adresi geçersiz görünüyor',
    'That email address looks invalid',
    'Questo indirizzo email non sembra valido',
  ),
  hataParolaKisa(
    'Parola en az {n} karakter olmalı',
    'Password must be at least {n} characters',
    'La password deve avere almeno {n} caratteri',
  ),
  hataParolaUzun(
    'Parola en fazla {n} karakter olabilir',
    'Password can be at most {n} characters',
    'La password può avere al massimo {n} caratteri',
  ),

  // ── Kare ölçümü ─────────────────────────────────────────────────────
  //
  // Ölçüm ekranda KALICI (bkz. `_FrameStats`): bu projenin hedefi "akıcı
  // hissettiriyor" değil ölçülebilir akıcılık. Kalıcı olduğu için de
  // çevriliyor — ekranın köşesinde duran tek Türkçe satır olamaz.
  perfTakilma('takılma {oran}', 'jank {oran}', 'scatti {oran}'),
  perfGemi('gemi', 'ships', 'navi'),
  perfAlien('alien', 'aliens', 'alieni'),
  perfAlindi('alındı', 'received', 'ricevuti'),
  perfTuketildi('tüketildi/sn', 'consumed/s', 'consumati/s'),
  perfMermiSn('mermi/sn', 'bolts/s', 'colpi/s'),
  perfVurusSn('vuruş/sn', 'hits/s', 'colpi a segno/s'),
  perfHavada('havada', 'in flight', 'in volo'),

  // ── Dil seçici ──────────────────────────────────────────────────────
  dil('DİL', 'LANGUAGE', 'LINGUA');

  const Metin(this._tr, this._en, this._it);

  final String _tr;
  final String _en;
  final String _it;

  /// Metnin [dil] karşılığı.
  ///
  /// `call` olarak tanımlı: çağrı yerinde `Metin.kapat(dil)` yazılıyor ve
  /// araya bir `.of` ya da `.metni` girmiyor. Bu metin ekranda YÜZLERCE kez
  /// geçtiği için okunabilirliği önemsemeye değer.
  String call(Dil dil) => switch (dil) {
    Dil.turkce => _tr,
    Dil.ingilizce => _en,
    Dil.italyanca => _it,
  };

  /// Yer tutucuları doldurarak döner: `Metin.tavanArti.bicim(dil, {'n': 12})`.
  ///
  /// Eksik bir anahtar SESSİZ geçmiyor — `{n}` ekranda öylece kalıyor ve
  /// gözden kaçmıyor. Fazladan verilen anahtar ise zararsız: aynı metin
  /// başka bir dilde daha az yer tutucu kullanabilir.
  String bicim(Dil dil, Map<String, Object?> degerler) {
    var metin = call(dil);
    for (final giris in degerler.entries) {
      metin = metin.replaceAll('{${giris.key}}', '${giris.value}');
    }
    return metin;
  }
}
