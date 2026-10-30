#!/usr/bin/env bash
#
# GERÇEK CİHAZDA başarım ölçümü — sunucu, telefon ve kayıt tek komutta.
#
#   tool/olcum.sh                 # bağlı ilk gerçek iPhone'u bulur
#   tool/olcum.sh 00008150-XXXX   # belirli bir cihaz
#
# `dev.sh`i SARIYOR, kopyalamıyor. Sunucuyu başlatmak, cihazı çözmek ve
# gerçek telefon için Mac'in LAN adresini bulmak zaten orada ve sınanmış:
# `localhost` yalnız simülatörde çalışıyor, gerçek telefonda kendisine
# işaret ediyor ve oyun hiç bağlanmıyor. O mantığı burada ikinci kez yazmak,
# birinin sessizce eskimesi demekti.
#
# Eklediği üç şey: profil modu, `PERF_LOG` ve çıktının dosyaya kaydı.
#
# NEDEN PROFİL, RELEASE DEĞİL. Release'te ölçüm kancaları derlemeye hiç
# girmiyor, `[perf]` satırı çıkmıyor. Hata ayıklama modunda ise Dart
# yorumlanıyor: ölçtüğün şey oyun değil derleyici olur.
#
# NEDEN SİMÜLATÖR DEĞİL. Simülatör Mac'in işlemcisinde koşuyor ve Metal'i
# masaüstü GPU'suna çeviriyor; raster süreleri telefonunkiyle akraba bile
# değil. Yapısal sorunlar orada da görünür ama "kaç kare düşüyor" sorusunun
# cevabı yalnız cihazda.
set -euo pipefail
cd "$(dirname "$0")/.."

CIHAZ="${1-}"
if [ -z "$CIHAZ" ]; then
  CIHAZ="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = []
for x in d:
    if x.get('targetPlatform', '').startswith('ios') and not x.get('emulator'):
        print(x['id'])
        break
" || true)"
fi
if [ -z "$CIHAZ" ]; then
  echo "! bağlı gerçek iPhone bulunamadı." >&2
  echo "  Telefon ve Mac AYNI ağda olmalı; telefonun kilidi açık olsun." >&2
  flutter devices >&2
  exit 1
fi

KAYIT="olcum-$(date +%Y%m%d-%H%M%S).log"
cat <<BILGI

· cihaz : $CIHAZ
· kayıt : $KAYIT

OYNARKEN ŞUNLARI SIRAYLA YAP — her birinde ~15 saniye kal
(ölçüm penceresi 240 kare; daha kısası tek bir takılmayı yüzdeye çeviremez):

  1. Uzayda uç ve ATEŞ ET — kalabalık bir yere git
  2. HANGAR aç · DONANIM sekmesi · depoyu yukarı aşağı kaydır
  3. DROİD · MALZEME · GEMİ sekmeleri
  4. MAĞAZA aç, rafları gez
  5. Pilot kartı → ARGE ağacı
  6. Hangarı kapat, tekrar uç

Bitince Ctrl-C. Sonra bana "$KAYIT" dosyasını söyle.

BILGI

# `tee` boruda: Ctrl-C bütün ön plan grubuna gidiyor, dev.sh'in kendi
# `trap`i sunucuyu kapatıyor.
tool/dev.sh -d "$CIHAZ" --profile --dart-define=PERF_LOG=true 2>&1 | tee "$KAYIT"
