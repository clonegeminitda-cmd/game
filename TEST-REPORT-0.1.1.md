# Kiểm thử APK Tách Gốc 0.1.1 — ký lại APK có .so

Bản cài thử Android 8.0 trở lên, versionCode 2, cùng chữ ký APK công cụ 0.1.0 để có thể cài cập nhật. Đây là chức năng **ký lại giữ nguyên package**, không phải tách gốc native để cài song song.

## Kết quả đã chạy

- Build Kotlin/Android SDK 35 thành công; Android Lint 0 lỗi, 28 cảnh báo. Xác minh chữ ký APK công cụ hợp lệ.
- **10/10 kiểm thử JVM qua**, gồm toàn bộ kiểm thử cũ và APK native thật. Kiểm tra package không đổi, mọi DEX và thư viện `.so` giữ nguyên byte, chữ ký hợp lệ, đầu vào không đổi. APK không có package tài nguyên riêng cũng được nhận đúng.
- Instrumentation `resignRealNativeApkOnAndroid`: **PASS**, 28,902 giây trên emulator **Android 8.0.0 / API 26, x86_64**, không dùng KVM. APK được đọc, đóng gói, ký và xác minh ngay trong Android.
- APK mẫu có thư viện ELF/JNI thật, biên dịch từ C trong `native-sample/src/main/cpp/nativefixture.c`. Script `native-smoke.sh` cài và chạy bản gốc: lời gọi JNI trả về **73**. Sau khi thay bằng APK ký lại, JNI vẫn trả về **73**. Không có lỗi AndroidRuntime ở lần thử này.
- Thử cập nhật đè bản gốc bằng chữ ký khác: Android trả `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, đúng giới hạn đã thông báo. Script chỉ gỡ app mẫu trên emulator để tiếp tục kiểm tra APK ký lại.
- Thư viện `lib/x86_64/libnativefixture.so` trước/sau ký có cùng SHA-256: `0d95f37981c4cf68580e0766ddcc831e29659c139caaa12196ef607644ff6936`. Tất cả 3 DEX của APK mẫu cũng giữ nguyên byte.
- APK ký lại qua xác minh apksigner v2/v3 và kiểm tra căn chỉnh ZIP `zipalign -c -P 16 4`. `.so` không nén được căn chỉnh ở biên 16 KB; không sửa mã ELF hoặc các định danh bên trong.
- Thử giao diện: chọn `Mau-Native.apk` qua SAF; ứng dụng tự chọn **Ký lại APK (hỗ trợ .so)**, khóa lựa chọn tách gốc native và hiển thị rõ giữ nguyên package. Bấm **Ký lại APK có .so** tạo đầu ra thành công, có kết quả đối chiếu `.so`.
- APK tạo qua nút giao diện giống hệt byte với APK ký trong instrumentation. SHA-256 đầu ra: `42c68f1e98944891447cb50e2b8fda8b678d548f3e7f1d501108c25f5396b67d`. Package vẫn là `vn.apktachgoc.nativesample`.

## Thay đổi của bản này

- Tự chọn chế độ ký lại khi phát hiện `.so`, tránh lỗi do chọn nhầm chế độ tách gốc.
- Đối chiếu tên và SHA-256 của mọi thư viện native trước khi công bố thành công. Nếu mất/thay đổi một thư viện thì từ chối xuất kết quả.
- Lưu phần giải thích chế độ cùng kết quả để khi mở lại vẫn thấy APK đã ký lại giữ nguyên package.
- Giữ các giới hạn về split/sharedUserId/định dạng chưa hỗ trợ; không bỏ kiểm tra chỉ để báo thành công.

## Giới hạn kết luận

Chưa thử trên điện thoại vật lý hoặc chạy thư viện ARM/ARM64. Mẫu JNI x86_64 chỉ dành cho emulator; APK công cụ không giới hạn ABI khi ký lại vì chỉ giữ nguyên các thư viện đầu vào, không nạp chúng để chạy. Thử nghiệm không đảm bảo mọi APK/game hoạt động sau thay chữ ký: ứng dụng tự kiểm tra chữ ký hoặc đăng nhập Google có thể không hoạt động.

Tách gốc native vẫn chưa được hỗ trợ. APK ký lại giữ package nên không cài cạnh bản gốc cùng package và không cập nhật được app đang dùng khóa khác.

Log và ảnh kiểm tra mới nằm trong `verification/native-0.1.1/`. Báo cáo các chức năng tách gốc APK Java/Kotlin, kho khóa và dữ liệu riêng của 0.1.0 được giữ trong `TEST-REPORT-0.1.0.md`; không suy diễn các kết quả đó thành hỗ trợ tách gốc native.
