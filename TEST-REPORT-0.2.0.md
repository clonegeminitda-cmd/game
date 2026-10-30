# APK Tách Gốc 0.2.0 — tách gốc native có giới hạn

Bản cài thử Android 8.0 trở lên, versionCode 3. Cùng chữ ký công cụ 0.1.x để cài cập nhật và giữ khóa nội bộ. Bản 0.1.1 chỉ ký lại native, không đáp ứng mục tiêu cài song song; 0.2.0 thay đổi phạm vi này.

## Kết quả đã chạy

- Build Kotlin/Android SDK 35 thành công. 12/12 kiểm thử JVM qua, 0 lỗi. Android Lint bản cuối: 0 lỗi, 28 cảnh báo. APK công cụ qua xác minh chữ ký v2 và zipalign.
- Mẫu thật có ELF/JNI x86_64. C gọi `FindClass("vn/apktachgoc/nativesample/MainActivity")`, giữ namespace lớp gốc, sau đó trả về 73. Có SharedPreferences và receiver thử nghiệm chỉ trong mẫu.
- Instrumentation `cloneRealNativeApkOnAndroid`: PASS, 28,224 giây trên emulator Android 8.0.0/API 26 x86_64, phần mềm, không KVM. Đọc, đổi package, đóng gói, ký và xác minh ngay trong Android, không dùng máy chủ.
- Package mới `vn.apktachgoc.nativesample.tachgoc`, khác `vn.apktachgoc.nativesample`. APK đầu vào giữ nguyên SHA-256. Từng byte thư viện `.so` được giữ nguyên; SHA-256 thư viện trước/sau: `b099339b5ec55a38811103de469b2f00babc8fb1512b6cd073e2a66fb3d90adc`.
- APK do instrumentation tạo: SHA-256 `93e2c81d283ff96681d52f04dc3886fb8a59c9df34e44273ce2ee4affbaf8793`. Qua xác minh chữ ký v2/v3 và zipalign -c -P 16 4.
- Kho khóa trên emulator đã có từ 0.1.1 được giữ sau cập nhật: fingerprint chứng chỉ `2157660c631e77786091b977fc984f5eaf5f577b8c5a99cc4220cdd120c79004` vẫn trùng kết quả cũ.
- Thử giao diện thật: chọn APK native qua SAF; lựa chọn tách gốc vẫn được bật và chọn, không tự chuyển sang ký lại. Nút Tạo và ký APK tạo package mới. Đầu ra giao diện SHA-256 `12b445de60a43e3bddc3d0c6856fe9b442ce0a25c06ff45be58b42ef3f9c3536`; tên hiển thị khác mẫu instrumentation nên SHA khác.
- Trong khi bản gốc vẫn cài, nút Cài bản sao mở Android installer hỏi **Install**, không hỏi cập nhật. Bấm Install: App installed. Mở bản sao: JNI FindClass/nativeValue = 73.
- `native-clone-smoke.sh` PASS: cài hai package cùng lúc, ghi ORIGINAL_NATIVE và CLONE_NATIVE vào hai vùng dữ liệu riêng, mở cả hai và xác nhận JNI 73. UID bản gốc 10072, bản sao 10073. Gỡ bản gốc, force-stop và mở lại bản sao: JNI 73 và CLONE_NATIVE vẫn còn. Gỡ cả công cụ, force-stop/mở lại bản sao: JNI 73 và CLONE_NATIVE vẫn còn.
- APK công cụ cuối được cài cập nhật và mở thành công. Sau thử giao diện, chỉ sửa nhãn nút cài bị vô hiệu hóa khi chưa có kết quả để không lưu nhãn ký lại cũ; build/lint lại, cài và mở bản cuối trước khi kiểm tra gỡ công cụ.
- Kiểm thử JVM gồm: tách gốc mẫu Java/Kotlin và native, ký lại giữ package/DEX/.so, chữ ký, khóa/mật khẩu, split, định danh asset, package lỗi, ELF bị cắt cụt và native chứa định danh chưa xử lý. Các chuỗi native UTF-8/UTF-16LE/UTF-16BE vắt qua ranh giới bộ đệm đều bị từ chối, không công bố file hoặc để lại .pending/.unsigned.

## Giới hạn

Chưa có APK Liên Quân của người dùng; ảnh chụp màn hình không cho phép kiểm tra 37 thư viện bên trong. Không xác nhận trò chơi đó tách được hoặc chạy được. Chưa thử điện thoại vật lý hay chạy thư viện ARM/ARM64. Mẫu x86_64 là fixture emulator, APK công cụ không chứa thư viện mẫu.

Native chỉ được tách khi không cần sửa định danh bên trong ELF. Công cụ kiểm tra cấu trúc ELF/ABI, quét định danh đã biết dạng rõ và giữ nguyên lớp JNI/byte thư viện; nếu phát hiện tham chiếu chưa xử lý thì báo thư viện và dừng, không tự chuyển sang ký lại. Kiểm tra tĩnh không phát hiện mọi định danh mã hóa/tạo động và không chứng minh ứng dụng chạy được. APK hợp lệ vẫn có thể không chạy do kiểm tra chữ ký, DRM, dịch vụ tài khoản hoặc logic của ứng dụng. Không vượt chống gian lận hay bảo đảm Google login.

Còn từ chối split/sharedUserId/mã nhúng/tài nguyên hoặc asset cần bộ xử lý riêng. Ký lại vẫn giữ package, không cài song song. Không gỡ app thật của người dùng để thử.

Emulator không có tăng tốc phần cứng từng hiện System UI ANR lúc khởi động; đã chờ System UI và tiếp tục. Không dùng lỗi môi trường đó để suy diễn thành kết quả của app. Kết luận JNI/dữ liệu ở trên dựa trên APK đã cài, mở lạnh và kiểm tra sau từng lần gỡ. Ảnh/log/XML có trong `verification/native-0.2.0/`. Báo cáo 0.1.0 và 0.1.1 được lưu riêng để đối chiếu, không thay thế kiểm thử bản này.

APK công cụ SHA-256: `52ceed102ffcff7ccf4a3bf1645bb517d81a3a3ef1ae3b5d958cd43dc151d086`.
