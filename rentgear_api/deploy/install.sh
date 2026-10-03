#!/bin/bash
# Memasang atau memperbarui RentGear di Ubuntu (proot) pada HP. Dijalankan sebagai root di dalam Ubuntu.
# Butuh di /sdcard/rg: api.tgz, web.zip, dan env (hanya saat pasang pertama atau ganti rahasia).
# Tambahkan argumen "seed" untuk mengosongkan database dan mengisi data demo.
exec > /sdcard/rg/install.log 2>&1
set -e
export DEBIAN_FRONTEND=noninteractive COMPOSER_ALLOW_SUPERUSER=1
SITE=/var/www/rentgear_serverbaik_my_id
CONF=/etc/nginx/sites-enabled/rentgear_serverbaik_my_id
APP=/root/rentgear/rentgear_api

echo "== paket"
if ! command -v php >/dev/null || ! command -v composer >/dev/null; then
  apt-get update -q
  apt-get install -y -q php-cli php-sqlite3 php-mbstring php-xml php-curl php-zip php-bcmath php-intl composer sqlite3 unzip
fi
php -v | head -1
INI=$(php -r 'echo PHP_CONFIG_FILE_SCAN_DIR;')
printf 'upload_max_filesize=10M\npost_max_size=12M\nmemory_limit=256M\n' > "$INI/99-rentgear.ini"

echo "== kode"
mkdir -p /root/rentgear/backup
# Data (database, foto unggahan, .env) tidak ikut ditimpa.
tar xzf /sdcard/rg/api.tgz -C /root/rentgear
cd "$APP"
if [ -f /sdcard/rg/env ]; then cp /sdcard/rg/env .env; chmod 600 .env; rm -f /sdcard/rg/env; fi
[ -f .env ] || { echo "GAGAL: .env tidak ada"; exit 1; }
mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs storage/app/private storage/app/public bootstrap/cache
composer install --no-dev --optimize-autoloader --no-interaction --no-progress
touch database/database.sqlite

echo "== database"
php artisan config:clear
if [ "$1" = "seed" ]; then php artisan migrate:fresh --seed --force; else php artisan migrate --force; fi
php artisan config:cache
php artisan route:cache

echo "== situs"
STAMP=$(date +%Y%m%d-%H%M%S)
tar czf /root/rentgear/backup/site-$STAMP.tgz -C /var/www rentgear_serverbaik_my_id
cp "$CONF" /root/rentgear/backup/nginx-$STAMP.conf
find "$SITE" -mindepth 1 -delete
unzip -q -o /sdcard/rg/web.zip -d "$SITE"
cp "$APP/deploy/nginx-rentgear.conf" "$CONF"
if nginx -t; then nginx -s reload; else cp /root/rentgear/backup/nginx-$STAMP.conf "$CONF"; echo "GAGAL: konfigurasi nginx ditolak, yang lama dikembalikan"; exit 1; fi

cp "$APP/deploy/start.sh" /root/rentgear/start.sh; chmod +x /root/rentgear/start.sh
echo "== selesai"
