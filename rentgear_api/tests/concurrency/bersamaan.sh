#!/usr/bin/env bash
# Uji pemesanan bersamaan terhadap server yang sedang berjalan (bukan bagian `php artisan test`).
#
# N penyewa baru memesan unit terakhir sebuah alat pada tanggal yang sama, semuanya dikirim serentak. Hasil yang benar:
# tepat satu booking berhasil, sisanya ditolak dengan SLOT_UNAVAILABLE, dan tidak ada galat server (500).
#
# Pakai: tests/concurrency/bersamaan.sh <alamat-api> <id-alat> [jumlah-penyewa]
#   Alat harus punya stok 1 pada tanggal uji (30 hari dari sekarang). Jalankan hanya di server uji, bukan server publik:
#   skrip ini membuat akun penyewa baru.
set -euo pipefail

API=${1:?alamat API, mis. http://127.0.0.1:8002}/api/v1
ITEM=${2:?id alat, mis. e-kompor}
N=${3:-6}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/bersamaan.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
DAY=$(date -v+30d +%Y-%m-%d 2>/dev/null || date -d '+30 days' +%Y-%m-%d)
STAMP=$(date +%s)

# Foto jaminan kecil (PNG 1x1).
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' > "$WORK/ktp.png"

for i in $(seq 1 "$N"); do
  curl -s -X POST "$API/auth/register" -H 'Accept: application/json' -H 'Content-Type: application/json' \
    -d "{\"role\":\"customer\",\"name\":\"Uji Bersamaan $i\",\"email\":\"bersamaan$i.$STAMP@rentgear.test\",\"password\":\"rahasia123\",\"phone\":\"08120000000$i\",\"city\":\"Malang\"}" \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["token"])' > "$WORK/token$i"
done

book() {
  local i=$1
  curl -s -o "$WORK/out$i" -w '%{http_code}' -X POST "$API/rentals" -H 'Accept: application/json' \
    -H "Authorization: Bearer $(cat "$WORK/token$i")" -H "Idempotency-Key: bersamaan-$STAMP-$i" \
    -F equipmentId="$ITEM" -F qty=1 -F startDate="$DAY" -F endDate="$DAY" \
    -F 'guarantees[0][type]=ktp' -F "guarantees[0][holderName]=Uji Bersamaan $i" \
    -F 'guarantees[0][documentNumber]=3573011204020001' -F "guarantees[0][photo]=@$WORK/ktp.png" > "$WORK/code$i"
}

# Semua permintaan dilepas pada saat yang sama.
for i in $(seq 1 "$N"); do book "$i" & done
wait

ok=0; slot=0; other=0
for i in $(seq 1 "$N"); do
  code=$(cat "$WORK/code$i")
  err=$(python3 -c 'import sys,json
try: d=json.load(open(sys.argv[1]))
except Exception: print("BUKAN_JSON"); sys.exit()
print("OK" if d.get("success") else (d.get("error") or {}).get("code") or "GALAT:" + str(d.get("message", d))[:120])' "$WORK/out$i")
  echo "penyewa $i: HTTP $code $err"
  case "$err" in OK) ok=$((ok+1));; SLOT_UNAVAILABLE) slot=$((slot+1));; *) other=$((other+1));; esac
done
echo "berhasil=$ok ditolak_stok_habis=$slot galat_lain=$other"
[ "$ok" -eq 1 ] && [ "$other" -eq 0 ] && echo "LULUS" || { echo "GAGAL"; exit 1; }
