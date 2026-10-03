#!/bin/bash
# Menjalankan API di dalam Ubuntu (proot). Harus tetap di latar depan: proot mematikan semua proses anaknya
# begitu skrip ini selesai.
cd /root/rentgear/rentgear_api || exit 1
pkill -f "artisan schedule:work" 2>/dev/null
pkill -f "artisan serve" 2>/dev/null
sleep 1
php artisan schedule:work >> storage/logs/schedule.log 2>&1 &
export PHP_CLI_SERVER_WORKERS=4
exec php artisan serve --host=127.0.0.1 --port=8000
