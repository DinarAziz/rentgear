#!/data/data/com.termux/files/usr/bin/sh
# Dijalankan di Termux (bukan di dalam Ubuntu): menyalakan API dan memasangnya ke skrip boot.
# Sejak 26 Oktober 2026 API diawasi runit (termux-services): cukup restart layanannya.
if [ -d "$PREFIX/var/service/rentgear" ]; then sv restart rentgear; sleep 6; echo selesai > /sdcard/rg/api.done; exit; fi
LINE='nohup proot-distro login ubuntu -- bash /root/rentgear/start.sh > ~/rentgear-api.log 2>&1 &'
BOOT=$HOME/.termux/boot/start-nginx.sh
if [ -f "$BOOT" ] && ! grep -q "rentgear/start.sh" "$BOOT"; then echo "$LINE" >> "$BOOT"; fi
nohup proot-distro login ubuntu -- bash /root/rentgear/start.sh > $HOME/rentgear-api.log 2>&1 &
sleep 6
echo selesai > /sdcard/rg/api.done
