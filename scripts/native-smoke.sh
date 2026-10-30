#!/usr/bin/env bash
set -euo pipefail
TASK_ADB=${ADB:-adb}
TASK_OUTPUT=${1:-native-test-output}
mkdir -p "$TASK_OUTPUT"
if [[ "$($TASK_ADB shell getprop ro.kernel.qemu | tr -d '\r')" != "1" ]]; then
  echo 'Script chỉ chạy trên emulator dùng để thử nghiệm; nó gỡ app mẫu native.' >&2
  exit 2
fi
$TASK_ADB pull /sdcard/Android/data/vn.apktachgoc/files/device-native-test/. "$TASK_OUTPUT/"
$TASK_ADB uninstall vn.apktachgoc.nativesample > /dev/null 2>&1 || true
$TASK_ADB install "$TASK_OUTPUT/native-original.apk"
$TASK_ADB shell am start -W -n vn.apktachgoc.nativesample/.MainActivity
$TASK_ADB shell uiautomator dump /sdcard/native-original-ui.xml
$TASK_ADB pull /sdcard/native-original-ui.xml "$TASK_OUTPUT/original-ui.xml"
rg -q 'JNI nativeValue\(\) = 73' "$TASK_OUTPUT/original-ui.xml"
if $TASK_ADB install -r "$TASK_OUTPUT/native-resigned.apk" > "$TASK_OUTPUT/expected-update-rejection.log" 2>&1; then
  echo 'FAIL: bản ký bằng khóa khác đã cập nhật đè bản gốc ngoài dự kiến.' >&2
  exit 1
fi
rg -q 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' "$TASK_OUTPUT/expected-update-rejection.log"
$TASK_ADB uninstall vn.apktachgoc.nativesample
$TASK_ADB install "$TASK_OUTPUT/native-resigned.apk"
$TASK_ADB shell am start -W -n vn.apktachgoc.nativesample/.MainActivity
$TASK_ADB shell uiautomator dump /sdcard/native-resigned-ui.xml
$TASK_ADB pull /sdcard/native-resigned-ui.xml "$TASK_OUTPUT/resigned-ui.xml"
rg -q 'JNI nativeValue\(\) = 73' "$TASK_OUTPUT/resigned-ui.xml"
echo 'PASS: app mẫu gọi thư viện ELF/JNI thật trước và sau ký lại; cùng package, khác chữ ký không cập nhật đè bản gốc.'
