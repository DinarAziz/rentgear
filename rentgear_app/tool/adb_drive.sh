#!/bin/bash
# usage: p.sh name [tap x y | text s | key k | swipe ...] ...
A="$HOME/Library/Android/sdk/platform-tools/adb -s ${ADB_SERIAL:-AIFMWOTWAMMRJBPR}"
D=${SHOT_DIR:-/tmp}; name=$1; shift
while [ $# -gt 0 ]; do
  case $1 in
    tap) $A shell input tap $2 $3; shift 3;;
    text) $A shell input text "$2"; shift 2;;
    key) $A shell input keyevent $2; shift 2;;
    swipe) $A shell input swipe $2 $3 $4 $5 400; shift 5;;
    wait) sleep $2; shift 2;;
  esac
  sleep 1
done
sleep 2; $A exec-out screencap -p > "$D/$name.png"; echo saved
