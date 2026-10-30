#!/usr/bin/env bash
#
# Sunucu + istemciyi BİRLİKTE başlatır, birlikte bitirir.
#
#   tool/dev.sh                 # varsayılan cihaz
#   tool/dev.sh -d macos        # belirli cihaz
#   tool/dev.sh -d ios          # AİLE ADI da olur — simülatör seçilir
#   tool/dev.sh -d "Cinar"      # gerçek telefon (adı ya da kimliği)
#   PORT=9000 tool/dev.sh       # başka port
#   BOTS=20 tool/dev.sh         # yanına 20 bot da koy
#   DEV_RICH= tool/dev.sh       # zengin hesap KAPALI (varsayılan: CINAR)
#   DEV_LOGIN= tool/dev.sh      # hızlı giriş düğmeleri KAPALI
#   DEV_ANA=cinar2 tool/dev.sh  # formu dolduran hesabı değiştir
#   DEBUG_COMMANDS= tool/dev.sh # hata ayıklama komutları ve /dev/para KAPALI
#
# Oyun AÇIKKEN bakiye vermek (hangar dosyası elle düzenlenemez, bkz.
# `Gateway._devPara`):
#   curl -X POST 'http://127.0.0.1:8080/dev/para?hesap=CINAR&kredi=1000000&nova=5000'
#   DEV_FULL= tool/dev.sh       # tam donanımlı hesap KAPALI (varsayılan: cinar3)
#   DEV_PASS=... tool/dev.sh    # hızlı giriş parolası
#
# Neden var: sunucuyu elle açıp elle kapatmak iki hataya yol açıyordu —
# unutulan sunucu portu tutuyor ("Address already in use"), ya da istemci
# kapanınca arkada koşmaya devam edip CPU yiyordu. Burada sunucu bu betiğin
# ÇOCUĞU: kabuk çıkarken `trap` onu kesin olarak öldürüyor.
set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${PORT:-8080}"
BOTS="${BOTS:-0}"
ACCOUNTS="${ACCOUNTS:-data/accounts.json}"

# GELİŞTİRME hesabı zengin başlar — mağazayı ve NOVA rafını sınamak için.
#
# YALNIZ bu betikte: `server/bin/server.dart` varsayılanı BOŞ, yani üretim
# derlemesi bu davranışı hiç görmüyor. Kapatmak için `DEV_RICH= tool/dev.sh`.
DEV_RICH="${DEV_RICH-CINAR}"

# GİRİŞ EKRANINDAKİ hızlı giriş düğmeleri ve kimin ne olduğu.
#
#   cinar2 → hiçbir listede yok: TAZE oyuncu. Kapıların, ilk lazerin ve
#            ilerlemenin gerçekten nasıl hissettirdiğini ancak o gösteriyor.
#   cinar3 → DEV_FULL: satıştaki en iyi gövde, bütün yuvalar +15, bütün
#            dünya açık, unvan merdiveninin tepesinde.
#
# İkisi de VARSA girmez, YOKSA ilk tıklamada kaydolur.
#
# **Parola bir sır DEĞİL** ve öyle davranılmamalı: yalnız bu betiğin
# başlattığı yerel sunucuda, bu betiğin ürettiği hesaplarda geçerli. Üretime
# giden bir `accounts.json` içinde bu hesaplar BULUNMAMALI — silin.
#
# Üretim derlemesi bunların hiçbirini görmüyor: `server/bin/server.dart` ve
# `AuthScreen` varsayılanları BOŞ, davranış yalnız burada açılıyor.
DEV_PASS="${DEV_PASS-gelistirme-hesabi}"
DEV_FULL="${DEV_FULL-cinar3}"

# ANA HESAP — giriş formu bununla DOLU açılıyor.
#
# Listenin BAŞINDA olması şart: istemci formu ilk hesapla dolduruyor
# (`AuthScreen.initState`), gerisi yalnız düğme. cinar2/cinar3 hâlâ listede,
# yani taze oyuncu ve tam donanım tek tıkla duruyor.
#
# cinar2 ve cinar3'ten farklı: bu hesap `data/accounts.json` içinde GERÇEKTEN
# var ve `DEV_RICH` onu zenginleştiriyor. Parolası bu yüzden atılabilir bir
# şey değil — üretime giden bir hesap dosyasında bu hesap BULUNMAMALI.
DEV_ANA="${DEV_ANA-CINAR}"
DEV_ANA_PASS="${DEV_ANA_PASS-12345678}"

DEV_LOGIN="${DEV_LOGIN-$DEV_ANA:$DEV_ANA_PASS,cinar2:$DEV_PASS,cinar3:$DEV_PASS}"

SERVER_PID=""
BOTS_PID=""

cleanup() {
  # `kill 0` DEĞİL: bu betiği çağıran terminali de düşürürdü. Yalnız kendi
  # başlattığımız süreçler.
  for pid in "$BOTS_PID" "$SERVER_PID"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      # Nazikçe sor, inat ederse zorla. SIGTERM sunucunun düzgün kapanış
      # yolunu tetikliyor (oturumlar kapanır, hesaplar diske yazılır).
      ( sleep 3; kill -9 "$pid" 2>/dev/null || true ) &
      wait "$pid" 2>/dev/null || true
    fi
  done
  echo "· sunucu kapatıldı"
}
trap cleanup EXIT INT TERM

# ÖNCEKİ koşudan sızmış sunucuyu topla.
#
# `trap` normal çıkışta ve Ctrl-C'de çalışıyor ama SIGKILL'i (ya da çöken bir
# terminali) yakalayamaz. O durumda port tutulu kalıyor ve bir sonraki koşu
# "Address already in use" ile ölüyordu — sebebi görünmeyen, teşhisi can sıkan
# bir hata. Burada baştan temizlemek onu imkânsız kılıyor.
STALE="$(pgrep -f 'server/bin/server.dart' || true)"
if [ -n "$STALE" ]; then
  echo "· önceki koşudan kalan sunucu kapatılıyor ($STALE)"
  # shellcheck disable=SC2086
  kill $STALE 2>/dev/null || true
  sleep 1
  # shellcheck disable=SC2086
  kill -9 $STALE 2>/dev/null || true
fi

# HATA AYIKLAMA KOMUTLARI: hasar/onarım tuşları ve `/dev/para` ucu.
#
# Yalnız bu betikte. Uç iki kapı istiyor — bu değişken ve isteğin YEREL
# makineden gelmesi — yani `dev.sh` ile açılan sunucu dışında kimse para
# basamıyor.
DEBUG_COMMANDS="${DEBUG_COMMANDS-true}"

echo "· sunucu başlatılıyor (port $PORT)"
ACCOUNTS="$ACCOUNTS" PORT="$PORT" DEV_RICH="$DEV_RICH" DEV_FULL="$DEV_FULL" \
  DEBUG_COMMANDS="$DEBUG_COMMANDS" \
  dart run server/bin/server.dart &
SERVER_PID=$!

# Sağlık ucu cevap verene kadar bekle — `flutter run` derlemesi uzun sürüyor
# ama yine de sunucudan ÖNCE bağlanmaya kalkabilir.
for _ in $(seq 1 40); do
  if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "! sunucu başlayamadı" >&2
    exit 1
  fi
  sleep 0.25
done
echo "· sunucu hazır: $(curl -s "http://127.0.0.1:$PORT/health")"

if [ "$BOTS" -gt 0 ]; then
  echo "· $BOTS bot ekleniyor"
  PREFIX=Bot PORT="$PORT" dart run server/bin/loadtest.dart "$BOTS" &
  BOTS_PID=$!
fi

# ── Cihazı çöz ve sunucu adresini ONA GÖRE seç ──────────────────────────
#
# İki ayrı tuzak vardı ve ikisi de "oyun açılmıyor" diye görünüyordu:
#
#  1. `-d ios` bir cihaz DEĞİL. `flutter devices` çıktısındaki `ios`, kimlik
#     değil PLATFORM sütunu; Flutter `-d` ile yalnız kimlik ve ad eşleştiriyor.
#     Sonuç: "No supported devices found with name or id matching 'ios'".
#     Burada aile adları (`ios`, `android`) da kabul ediliyor ve hangi cihazın
#     seçildiği YAZILIYOR — sessizce başka bir cihaza düşmek, sonraki yarım
#     saati "neden çalışmıyor" diye harcatır.
#
#  2. Sunucu adresi cihaza göre DEĞİŞİR ve sabit `localhost` yalnız bir
#     durumda doğru:
#       · macOS, iOS simülatörü, tarayıcı → `localhost` (aynı makine)
#       · Android emülatörü               → `10.0.2.2` (emülatörün ana makine
#                                            takma adı; `localhost` emülatörün
#                                            KENDİSİ)
#       · GERÇEK telefon                  → Mac'in yerel ağ adresi
#     Gerçek bir iPhone'da `ws://localhost:8080`, telefonun kendisine
#     bağlanmaya çalışmak demek — sunucu orada değil.
resolve_device() {
  DEVICE_ID=""
  DEVICE_NAME=""
  DEVICE_KIND=""

  local devices
  devices="$(flutter devices --machine --device-timeout 5 2>/dev/null)" || true
  if [ -z "$devices" ]; then
    echo "! cihaz listesi alınamadı" >&2
    return 1
  fi

  # Eşleştirme Python'da: JSON'u kabukta ayrıştırmak, tırnak ve boşluk içeren
  # cihaz adlarında ("iPhone 17 Pro") sessizce yanlış cihaz seçmenin yolu.
  local resolved
  resolved="$(printf '%s' "$devices" | REQUESTED="$1" python3 -c '
import json, os, sys

want = os.environ.get("REQUESTED", "").strip().lower()
devices = json.load(sys.stdin)

def kind(d):
    platform = (d.get("targetPlatform") or "").lower()
    if platform.startswith("darwin") or platform.startswith("web"):
        return "host"
    if d.get("emulator"):
        return "android-emulator" if platform.startswith("android") else "simulator"
    return "physical"

def family(d):
    platform = (d.get("targetPlatform") or "").lower()
    return "android" if platform.startswith("android") else platform.split("-")[0]

# 1) Kimlik ya da ad — Flutter ne kabul ediyorsa o.
for d in devices:
    if want in (d["id"].lower(), d["name"].lower()):
        print("\t".join([d["id"], d["name"], kind(d)])); sys.exit(0)

# 2) Aile adı: `ios`, `android`. SİMÜLATÖR öncelikli — geliştirmede olağan
#    hedef o, ve gerçek cihaz ek kurulum (imzalama, yerel ağ izni) istiyor.
same = [d for d in devices if family(d) == want]
if same:
    same.sort(key=lambda d: 0 if d.get("emulator") else 1)
    d = same[0]
    print("\t".join([d["id"], d["name"], kind(d)])); sys.exit(0)

sys.exit(1)
')" || {
    echo "! \"$1\" diye bir cihaz yok. Bağlı olanlar:" >&2
    flutter devices --device-timeout 5 2>/dev/null | sed 's/^/    /' >&2
    return 1
  }

  DEVICE_ID="${resolved%%$'\t'*}"
  local rest="${resolved#*$'\t'}"
  DEVICE_NAME="${rest%%$'\t'*}"
  DEVICE_KIND="${rest##*$'\t'}"
}

# Mac'in yerel ağ adresi — gerçek telefonun sunucuya ulaşacağı tek adres.
lan_address() {
  local ip
  for iface in $(route -n get default 2>/dev/null | awk '/interface:/{print $2}') en0 en1 en2; do
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    [ -n "$ip" ] && { printf '%s' "$ip"; return 0; }
  done
  return 1
}

# `-d` argümanını AYIKLA; gerisi `flutter run`'a olduğu gibi geçiyor.
ARGS=()
REQUESTED=""
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device-id)
      REQUESTED="${2:-}"
      shift 2
      ;;
    -d=*|--device-id=*)
      REQUESTED="${1#*=}"
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

HOST="localhost"
if [ -n "$REQUESTED" ]; then
  resolve_device "$REQUESTED" || exit 1
  echo "· cihaz: $DEVICE_NAME ($DEVICE_KIND)"
  ARGS+=(-d "$DEVICE_ID")

  case "$DEVICE_KIND" in
    android-emulator) HOST="10.0.2.2" ;;
    physical)
      HOST="$(lan_address)" || {
        echo "! yerel ağ adresi bulunamadı; gerçek cihaz sunucuya ulaşamaz" >&2
        exit 1
      }
      echo "· gerçek cihaz: telefon ve Mac AYNI ağda olmalı"
      ;;
  esac
fi

echo "· istemci sunucuyu ws://$HOST:$PORT adresinde arayacak"

# `flutter run` ÖN PLANDA: çıktığı an `trap` devreye giriyor. Ctrl-C de,
# `q` ile çıkmak da, derleme hatası da aynı yola çıkıyor.
if [ -n "$DEV_LOGIN" ]; then
  echo "· hızlı giriş açık: ${DEV_LOGIN//:$DEV_PASS/}"
fi

flutter run \
  --dart-define=VOIDSPACE_SERVER="ws://$HOST:$PORT" \
  --dart-define=DEV_LOGIN="$DEV_LOGIN" \
  "${ARGS[@]}"
