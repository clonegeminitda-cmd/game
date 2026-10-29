# Báo cáo kiểm tra bản 0.1.0

Ngày 29/10/2026 (Asia/Saigon).

## Đã hoàn tất

- Build Kotlin / Android SDK 35 / Build Tools 35.0.0 / JDK 21 / Gradle 8.11.1: thành công.
- APK công cụ `vn.apktachgoc`, phiên bản `0.1.0 (1)`, minSdk 26, targetSdk 35.
- `apksigner verify --verbose --print-certs`: chữ ký APK công cụ hợp lệ, v2, một signer.
- `zipalign -c -P 16 4`: thành công.
- Android Lint: **0 lỗi, 28 cảnh báo**. Phần lớn là chuỗi tiếng Việt đặt trong Kotlin, gợi ý KTX, và mã TLS không dùng của thư viện Bouncy Castle. Công cụ không có quyền Internet. Log lint đầy đủ được kèm theo.
- **8/8 kiểm thử JVM qua** bằng APK mẫu build thật (3 DEX), không dùng manifest/DEX giả thay cho app mẫu.
- Thử ký lại: package và nội dung DEX được giữ nguyên.
- Thử tách gốc: package/tên mới, tên lớp đầy đủ vẫn giữ namespace DEX, provider authorities tách riêng (kể cả authority không bắt đầu bằng package cũ), quyền định nghĩa/sử dụng và taskAffinity được ánh xạ. Hằng chuỗi/URI trong DEX và tài nguyên được sửa theo đúng bảng ánh xạ. APK đầu ra qua xác minh chữ ký, CRC và manifest. SHA-256 đầu vào không thay đổi.
- Cùng khóa ký tạo hai bản cập nhật có cùng chứng chỉ.
- Xuất/nhập PKCS#12 đúng mật khẩu giữ nguyên khóa; sai mật khẩu và mật khẩu xuất quá ngắn bị từ chối.
- Split/config APK, base yêu cầu split, clone có native và asset còn định danh gốc bị từ chối; không có APK cuối hoặc tệp tạm được báo thành công.
- APK đã tải lên GitHub và tải lại đối chiếu SHA-256 khớp bản build.

## Kiểm thử Android

Chưa có kết quả chạy ứng dụng thành công để xác nhận. Đã cài SDK/emulator và thử emulator Android 11 bằng phần mềm (không có KVM); hệ thống Android khởi động lại trong khi cài APK, trả `Failure calling service package: Broken pipe (32)`. Đây là lỗi môi trường emulator, không được tính là đã cài hoặc chạy được công cụ.

Chưa xác nhận cài song song, UID/dữ liệu riêng hoặc tồn tại sau khi gỡ bản gốc/công cụ bằng kết quả chạy thực tế. Có kèm app mẫu, kiểm thử instrumentation và script adb để tái kiểm tra. Chức năng SAF lưu/chia sẻ, luồng cài đặt và kho khóa Android Keystore chưa được xác nhận qua thao tác thực tế.

## Giới hạn kết luận

Kiểm tra chữ ký/cấu trúc không đảm bảo ứng dụng bất kỳ chạy đúng. Không có kiểm thử Google login, game, DRM, native clone, split merging hoặc các phiên bản Android khác. Không cam kết vượt chống gian lận. Xem README để biết phạm vi từ chối của bản đầu.
