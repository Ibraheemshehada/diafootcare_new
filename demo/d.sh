#!/usr/bin/env bash
# tiny adb driver for demo capture.  usage:
#   d.sh cap <name>        screenshot -> demo/screenshots/<name>.png
#   d.sh tap <x> <y>       tap
#   d.sh back | home       key events
#   d.sh dump              uiautomator xml -> stdout (clickable nodes)
#   d.sh demo              re-apply clean status bar
set -e
ADB="${ADB:-$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe}"
DIR="$(cd "$(dirname "$0")" && pwd)"
SHOTS="$DIR/screenshots"; mkdir -p "$SHOTS"
case "$1" in
  cap)  "$ADB" exec-out screencap -p > "$SHOTS/$2.png"; echo "saved $2.png";;
  tap)  "$ADB" shell input tap "$2" "$3"; sleep 0.8;;
  swipe)"$ADB" shell input swipe "$2" "$3" "$4" "$5" "${6:-300}"; sleep 0.6;;
  back) "$ADB" shell input keyevent 4; sleep 0.8;;
  home) "$ADB" shell input keyevent 3; sleep 0.6;;
  dump) MSYS_NO_PATHCONV=1 "$ADB" shell uiautomator dump /sdcard/u.xml >/dev/null 2>&1; MSYS_NO_PATHCONV=1 "$ADB" shell cat /sdcard/u.xml;;
  demo)
    "$ADB" shell settings put global sysui_demo_allowed 1 >/dev/null
    B(){ "$ADB" shell am broadcast -a com.android.systemui.demo "$@" >/dev/null 2>&1; }
    B -e command enter
    B -e command clock -e hhmm 1200
    B -e command battery -e level 100 -e plugged false
    B -e command network -e wifi show -e level 4
    B -e command network -e mobile show -e datatype none -e level 4
    B -e command notifications -e visible false
    echo "demo status bar applied";;
  *) echo "unknown: $1"; exit 1;;
esac
