#!/usr/bin/env bash
set -euo pipefail
TASK_ADB=${ADB:-adb}
TASK_OUTPUT=${1:-native-clone-test-output}
mkdir -p "$TASK_OUTPUT"
if [[ "$($TASK_ADB shell getprop ro.kernel.qemu | tr -d '\r')" != "1" ]]; then
  echo 'Chỉ dùng emulator thử nghiệm: script gỡ app mẫu và công cụ, làm mất khóa nội bộ.' >&2
  exit 2
fi
$TASK_ADB pull /sdcard/Android/data/vn.apktachgoc/files/device-native-clone-test/. "$TASK_OUTPUT/"
TASK_ORIGINAL=vn.apktachgoc.nativesample
TASK_CLONE=vn.apktachgoc.nativesample.tachgoc
TASK_CLASS=vn.apktachgoc.nativesample
$TASK_ADB uninstall "$TASK_ORIGINAL" > /dev/null 2>&1 || true
$TASK_ADB uninstall "$TASK_CLONE" > /dev/null 2>&1 || true
$TASK_ADB install "$TASK_OUTPUT/native-original.apk"
$TASK_ADB install "$TASK_OUTPUT/native-clone.apk"
$TASK_ADB shell am broadcast -n "$TASK_ORIGINAL/$TASK_CLASS.SessionReceiver" --es marker ORIGINAL_NATIVE
$TASK_ADB shell am broadcast -n "$TASK_CLONE/$TASK_CLASS.SessionReceiver" --es marker CLONE_NATIVE
check_launch() {
  local task_package=$1 task_name=$2 task_marker=$3
  $TASK_ADB shell am force-stop "$task_package"
  $TASK_ADB shell am start -W -n "$task_package/$TASK_CLASS.MainActivity"
  $TASK_ADB shell uiautomator dump /sdcard/native-clone-ui.xml
  $TASK_ADB pull /sdcard/native-clone-ui.xml "$TASK_OUTPUT/$task_name-ui.xml"
  rg -q 'JNI nativeValue\(\) = 73' "$TASK_OUTPUT/$task_name-ui.xml"
  rg -q "$task_marker" "$TASK_OUTPUT/$task_name-ui.xml"
  $TASK_ADB shell run-as "$task_package" cat shared_prefs/session.xml > "$TASK_OUTPUT/$task_name-data.xml"
  rg -q "$task_marker" "$TASK_OUTPUT/$task_name-data.xml"
}
check_launch "$TASK_ORIGINAL" original ORIGINAL_NATIVE
check_launch "$TASK_CLONE" clone CLONE_NATIVE
if rg -q ORIGINAL_NATIVE "$TASK_OUTPUT/clone-data.xml"; then exit 1; fi
$TASK_ADB shell dumpsys package "$TASK_ORIGINAL" > "$TASK_OUTPUT/original-package.txt"
$TASK_ADB shell dumpsys package "$TASK_CLONE" > "$TASK_OUTPUT/clone-package.txt"
TASK_ORIGINAL_UID=$(rg -m1 -o 'userId=[0-9]+' "$TASK_OUTPUT/original-package.txt")
TASK_CLONE_UID=$(rg -m1 -o 'userId=[0-9]+' "$TASK_OUTPUT/clone-package.txt")
[[ -n "$TASK_ORIGINAL_UID" && -n "$TASK_CLONE_UID" && "$TASK_ORIGINAL_UID" != "$TASK_CLONE_UID" ]]
echo "UID riêng: $TASK_ORIGINAL_UID / $TASK_CLONE_UID"
$TASK_ADB uninstall "$TASK_ORIGINAL"
check_launch "$TASK_CLONE" after-original-uninstall CLONE_NATIVE
$TASK_ADB uninstall vn.apktachgoc
check_launch "$TASK_CLONE" after-tool-uninstall CLONE_NATIVE
echo 'PASS: native clone cài cạnh bản gốc; JNI FindClass hoạt động; UID/dữ liệu riêng; vẫn chạy và giữ dữ liệu sau gỡ bản gốc và công cụ.'
