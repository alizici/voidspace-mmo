#!/usr/bin/env bash
#
# Sunucuyu İNTERNETE açar — uzaktaki bir arkadaşla birlikte oynamak için.
#
#   tool/tunel.sh               # sunucu + tünel, adresi yazar
#   tool/tunel.sh --apk         # üstüne o adrese bağlanan Android APK üretir
#   PORT=9000 tool/tunel.sh     # başka port
#
# Cloudflare'ın "quick tunnel"ı kullanılıyor: hesap, alan adı ve yapılandırma
# istemiyor, karşılığında ADRES HER KOŞUDA DEĞİŞİYOR. Adres derlemeye
# gömüldüğü için tünel yeniden açıldığında APK'nın da yeniden üretilmesi
# gerekiyor — sabit adres isteniyorsa Cloudflare hesabı ve adlandırılmış
# tünel gerekir.
#
# GÜVENLİK. Tünel açıkken sunucu dünyaya açık demek:
#   · Hesaplar parolayla korunuyor, oyun sunucusu yetkiyi kendisi denetliyor.
#   · `/dev/para` ucu vekilden gelen isteği reddediyor (tünel bir vekil), yani
#     dışarıdan para basılamıyor.
#   · DEV_RICH ve DEV_FULL yalnız ADI YAZILI hesapları zenginleştiriyor.
# Yine de bu bir GELİŞTİRME sunucusu: tüneli oyun bitince kapatın.
set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${PORT:-8080}"
ACCOUNTS="${ACCOUNTS:-data/accounts.json}"
DEV_RICH="${DEV_RICH-CINAR}"
DEV_FULL="${DEV_FULL-cinar3}"
# Hata ayıklama komutları tünelde de AÇIK kalabiliyor: `/dev/para` vekili
# zaten reddediyor, hasar/onarım komutları ise yalnız kendi gemine etki
# ediyor. Kapatmak için `DEBUG_COMMANDS= tool/tunel.sh`.
DEBUG_COMMANDS="${DEBUG_COMMANDS-true}"

APK=0
for arg in "$@"; do
  [ "$arg" = "--apk" ] && APK=1
done

SERVER_PID=""
TUNNEL_PID=""
LOG="$(mktemp -t voidspace-tunel)"

cleanup() {
  for pid in "$TUNNEL_PID" "$SERVER_PID"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      ( sleep 3; kill -9 "$pid" 2>/dev/null || true ) &
      wait "$pid" 2>/dev/null || true
    fi
  done
  rm -f "$LOG"
  echo "· tünel ve sunucu kapatıldı"
}
trap cleanup EXIT INT TERM

command -v cloudflared >/dev/null 2>&1 || {
  echo "! cloudflared yok: brew install cloudflared" >&2
  exit 1
}

# Önceki koşudan sızmış sunucuyu topla (dev.sh ile aynı sebep).
STALE="$(pgrep -f 'server/bin/server.dart' || true)"
if [ -n "$STALE" ]; then
  echo "· önceki koşudan kalan sunucu kapatılıyor ($STALE)"
  # shellcheck disable=SC2086
  kill $STALE 2>/dev/null || true
  sleep 1
fi

echo "· sunucu başlatılıyor (port $PORT)"
ACCOUNTS="$ACCOUNTS" PORT="$PORT" DEV_RICH="$DEV_RICH" DEV_FULL="$DEV_FULL" \
  DEBUG_COMMANDS="$DEBUG_COMMANDS" \
  dart run server/bin/server.dart &
SERVER_PID=$!

for _ in $(seq 1 40); do
  curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  kill -0 "$SERVER_PID" 2>/dev/null || { echo "! sunucu başlayamadı" >&2; exit 1; }
  sleep 0.25
done
echo "· sunucu hazır: $(curl -s "http://127.0.0.1:$PORT/health")"

echo "· tünel açılıyor"
cloudflared tunnel --url "http://127.0.0.1:$PORT" --no-autoupdate >"$LOG" 2>&1 &
TUNNEL_PID=$!

# Adres cloudflared'in kendi çıktısından okunuyor; başka yolu yok.
URL=""
for _ in $(seq 1 60); do
  URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" | head -1 || true)"
  [ -n "$URL" ] && break
  kill -0 "$TUNNEL_PID" 2>/dev/null || { echo "! tünel açılamadı:"; cat "$LOG"; exit 1; }
  sleep 0.5
done
[ -n "$URL" ] || { echo "! tünel adresi okunamadı:"; cat "$LOG" >&2; exit 1; }

WS="wss://${URL#https://}"

# Adres yazılmadan önce tünelin GERÇEKTEN WebSocket taşıdığı sınanıyor:
# `/health` düz HTTP ile geçer ama oyun yalnız yükseltmeyle çalışıyor, ve
# yükseltmenin kırıldığı bir tünel sağlıklı görünüp oyunu hiç açmaz. HTTP/2
# yükseltmeyi taşımadığı için istek 1.1'e sabitleniyor.
KOD="$(curl -s -o /dev/null -w '%{http_code}' --http1.1 --max-time 15 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  "$URL/" || true)"
if [ "$KOD" = "101" ]; then
  echo "· tünel WebSocket taşıyor (101)"
else
  echo "! tünel WebSocket taşımıyor (HTTP $KOD) — oyun bağlanmaz" >&2
fi

echo
echo "════════════════════════════════════════════════════════════"
echo "  ADRES : $URL"
echo "  OYUN  : $WS"
echo "════════════════════════════════════════════════════════════"
echo
echo "· macOS'ta bu sunucuya bağlanmak için BAŞKA bir terminalde:"
echo "    flutter run -d macos --dart-define=VOIDSPACE_SERVER=$WS"
echo

if [ "$APK" = "1" ]; then
  echo "· APK üretiliyor (adres derlemeye gömülüyor)"
  # Elden kurulacak paket: mağaza yükleme anahtarı yok sayılıyor, debug
  # anahtarıyla imzalanıyor. `set -e` ile derleme çökerse TÜNELİ DE
  # götürürdü; oysa tünel APK'dan bağımsız çalışıyor ve macOS istemcisi ona
  # bağlanabiliyor. Bu yüzden hata yutuluyor, yalnız bildiriliyor.
  if VOIDSPACE_YAN_YUKLEME=1 flutter build apk --release \
      --dart-define=VOIDSPACE_SERVER="$WS"; then
    echo "· APK: build/app/outputs/flutter-apk/app-release.apk"
    echo "  Bu APK YALNIZ bu tünel açıkken çalışır; tünel kapanınca adres ölür."
  else
    echo "! APK üretilemedi — tünel AÇIK kalıyor, macOS istemcisi bağlanabilir."
  fi
fi

echo "· Ctrl-C ile hepsi kapanır. Tünel açık kaldığı sürece adres geçerli."
wait "$SERVER_PID"
