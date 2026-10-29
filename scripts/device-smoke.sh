#!/usr/bin/env bash
set -euo pipefail
TASK_ADB=${ADB:-adb}
TASK_OUTPUT=${1:-device-test-output}
mkdir -p "$TASK_OUTPUT"
if [[ "$($TASK_ADB shell getprop ro.kernel.qemu | tr -d '\r')" != "1" ]]; then
  echo 'Script chỉ chạy trên emulator dùng để thử nghiệm; nó gỡ app mẫu và công cụ, làm mất khóa nội bộ.' >&2
  exit 2
fi
$TASK_ADB pull /sdcard/Android/data/vn.apktachgoc/files/device-test/. "$TASK_OUTPUT/"
$TASK_ADB install -r "$TASK_OUTPUT/sample-original.apk"
$TASK_ADB install -r "$TASK_OUTPUT/sample-clone.apk"
$TASK_ADB shell am broadcast -n vn.apktachgoc.sample/vn.apktachgoc.sample.SessionReceiver --es marker ORIGINAL_SESSION
$TASK_ADB shell am broadcast -n vn.apktachgoc.sample.tachgoc/vn.apktachgoc.sample.SessionReceiver --es marker CLONE_SESSION
$TASK_ADB shell am start -W -n vn.apktachgoc.sample/vn.apktachgoc.sample.MainActivity
$TASK_ADB shell am start -W -n vn.apktachgoc.sample.tachgoc/vn.apktachgoc.sample.MainActivity
$TASK_ADB shell run-as vn.apktachgoc.sample cat shared_prefs/session.xml > "$TASK_OUTPUT/original-before.xml"
$TASK_ADB shell run-as vn.apktachgoc.sample.tachgoc cat shared_prefs/session.xml > "$TASK_OUTPUT/clone-before.xml"
rg -q ORIGINAL_SESSION "$TASK_OUTPUT/original-before.xml"
rg -q CLONE_SESSION "$TASK_OUTPUT/clone-before.xml"
if rg -q ORIGINAL_SESSION "$TASK_OUTPUT/clone-before.xml"; then exit 1; fi
$TASK_ADB shell dumpsys package vn.apktachgoc.sample > "$TASK_OUTPUT/original-package.txt"
$TASK_ADB shell dumpsys package vn.apktachgoc.sample.tachgoc > "$TASK_OUTPUT/clone-package.txt"
TASK_ORIGINAL_UID=$(rg -m1 -o 'userId=[0-9]+' "$TASK_OUTPUT/original-package.txt")
TASK_CLONE_UID=$(rg -m1 -o 'userId=[0-9]+' "$TASK_OUTPUT/clone-package.txt")
[[ -n "$TASK_ORIGINAL_UID" && -n "$TASK_CLONE_UID" && "$TASK_ORIGINAL_UID" != "$TASK_CLONE_UID" ]]
echo "UID riêng: $TASK_ORIGINAL_UID / $TASK_CLONE_UID"
$TASK_ADB uninstall vn.apktachgoc.sample
$TASK_ADB shell am force-stop vn.apktachgoc.sample.tachgoc
$TASK_ADB shell am start -W -n vn.apktachgoc.sample.tachgoc/vn.apktachgoc.sample.MainActivity
$TASK_ADB shell run-as vn.apktachgoc.sample.tachgoc cat shared_prefs/session.xml > "$TASK_OUTPUT/clone-after-original-uninstall.xml"
rg -q CLONE_SESSION "$TASK_OUTPUT/clone-after-original-uninstall.xml"
$TASK_ADB uninstall vn.apktachgoc
$TASK_ADB shell am force-stop vn.apktachgoc.sample.tachgoc
$TASK_ADB shell am start -W -n vn.apktachgoc.sample.tachgoc/vn.apktachgoc.sample.MainActivity
$TASK_ADB shell run-as vn.apktachgoc.sample.tachgoc cat shared_prefs/session.xml > "$TASK_OUTPUT/clone-after-tool-uninstall.xml"
rg -q CLONE_SESSION "$TASK_OUTPUT/clone-after-tool-uninstall.xml"
echo 'PASS: cài song song; dữ liệu riêng; bản sao giữ dữ liệu sau gỡ bản gốc và công cụ.'
