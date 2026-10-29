# Báo cáo kiểm tra bản 0.1.0

Ngày 29/10/2026 (Asia/Saigon).

## Đã hoàn tất

- Build Kotlin / Android SDK 35 / Build Tools 35.0.0 / JDK 21 / Gradle 8.11.1: thành công.
- APK công cụ `vn.apktachgoc`, phiên bản `0.1.0 (1)`, minSdk 26, targetSdk 35.
- `apksigner verify --verbose --print-certs`: chữ ký APK công cụ hợp lệ, v2, một signer.
- `zipalign -c -P 16 4`: thành công.
- Android Lint: **0 lỗi, 28 cảnh báo**. Phần lớn là chuỗi tiếng Việt đặt trong Kotlin, gợi ý KTX, và mã TLS không dùng của thư viện Bouncy Castle. Công cụ không có quyền Internet. Log lint đầy đủ được kèm theo.
- **9/9 kiểm thử JVM qua** bằng APK mẫu build thật (3 DEX), không dùng manifest/DEX giả thay cho app mẫu. Có kiểm tra package đầu vào sai và giữ nguyên byte của DEX thư viện không có định danh cần đổi.
- Thử ký lại: package và nội dung DEX được giữ nguyên.
- Thử tách gốc: package/tên mới, tên lớp đầy đủ vẫn giữ namespace DEX, provider authorities tách riêng (kể cả authority không bắt đầu bằng package cũ), quyền định nghĩa/sử dụng và taskAffinity được ánh xạ. Hằng chuỗi/URI trong DEX và tài nguyên được sửa theo đúng bảng ánh xạ. APK đầu ra qua xác minh chữ ký, CRC và manifest. SHA-256 đầu vào không thay đổi.
- Cùng khóa ký tạo hai bản cập nhật có cùng chứng chỉ.
- Xuất/nhập PKCS#12 đúng mật khẩu giữ nguyên khóa; sai mật khẩu và mật khẩu xuất quá ngắn bị từ chối.
- Split/config APK, base yêu cầu split, clone có native và asset còn định danh gốc bị từ chối; không có APK cuối hoặc tệp tạm được báo thành công.
- APK đã tải lên GitHub và tải lại đối chiếu SHA-256 khớp bản build.

## Kiểm thử Android: đã chạy thành công

Môi trường: **emulator Android 8.0.0 / API 26, x86_64**, chạy bằng phần mềm, không có KVM. Chưa thử trên điện thoại vật lý. Lần thử Android 11 trước đó gặp hệ thống emulator khởi động lại; không tính lần đó là đạt.

- Kiểm thử instrumentation tạo/lưu/đọc khóa bằng Android Keystore AES-GCM, xuất/nhập PKCS#12, tạo APK tách gốc và ký lại ngay trên Android: **PASS**, 75,334 giây ở lần kiểm tra sau tối ưu. APK đầu vào giữ nguyên SHA-256; APK đầu ra kiểm tra lại bằng apksigner trên máy build, v2/v3 hợp lệ.
- Cập nhật APK công cụ bằng cùng chữ ký và chạy lại: chứng chỉ khóa ký trên máy vẫn là `8c028d7981c995fc3d791e3319caebbfa4b577ff2d7d575260aa63105bf6648b`.
- Kiểm thử instrumentation khôi phục tệp khóa `.bak` sau khi giả lập gián đoạn ghi: **PASS**, giữ nguyên khóa, không tự sinh khóa mới thay thế.
- Qua giao diện: chọn APK bằng trình chọn tệp Android; đọc được `Mẫu Tách Gốc`, phiên bản `1.0 (1)`, package `vn.apktachgoc.sample`. Bấm **Tạo và ký APK**, quan sát tiến trình DEX và kết quả được xác minh.
- Qua **Lưu APK vào điện thoại**: SAF ghi tệp ra Downloads, thông báo đã lưu. SHA-256 tệp lưu là `99fd22ed4dd14e68e4846f543bb61bbfbb69dee47584e9f1228f9456759fd91b`, trùng kết quả hiển thị và qua xác minh chữ ký. Đây là mẫu được tạo trong lần thử giao diện trước tối ưu; mẫu instrumentation cuối nằm trong `downloads/mau-tach-goc.apk`.
- Qua **Mở trình cài đặt Android**: mở đúng trang cho phép cài từ nguồn này, rồi mở trình cài đặt đọc được tên mới `Mẫu Tách Gốc • Bản riêng`; bấm Install và xác nhận package bản sao được cài.
- Qua **Chia sẻ APK**: gọi trình chia sẻ Android. Emulator không có ứng dụng nhận MIME APK, nên hệ thống hiện `No apps can perform this action`. Chưa kiểm tra giao tệp sang ứng dụng chia sẻ khác; không có tệp nào được gửi cho người khác.
- Script `device-smoke.sh`: **PASS**, dùng APK mẫu do công cụ xử lý ngay trên Android. Cài đồng thời bản gốc và bản sao thành công. UID gốc **10068**, UID bản sao **10067**. Ghi `ORIGINAL_SESSION` và `CLONE_SESSION` qua receiver thử nghiệm của hai app; đọc lại vùng SharedPreferences riêng và xác nhận không lẫn marker.
- Gỡ bản gốc, **force-stop rồi khởi động lạnh** bản sao: chạy được và vẫn có `CLONE_SESSION`.
- Gỡ công cụ `vn.apktachgoc`, **force-stop rồi khởi động lạnh** bản sao: chạy được và vẫn có `CLONE_SESSION`. Giao diện mẫu đọc được provider riêng, package/BuildConfig mới. Không có lỗi AndroidRuntime trong lần kiểm tra này.
- File APK gốc trong Downloads sau thao tác SAF được tải lại đối chiếu SHA-256 với bản gốc build.

Log instrumentation, thử khôi phục khóa, script cài/gỡ, các XML dữ liệu thử và ảnh sau khi gỡ được kèm trong `verification/`. Các marker là dữ liệu mô phỏng phục vụ thử nghiệm, không phải phiên đăng nhập Google thật.

## Giới hạn kết luận

Kiểm tra chữ ký/cấu trúc và app mẫu không đảm bảo ứng dụng bất kỳ chạy đúng. Chưa thử thao tác xuất/nhập khóa qua hộp thoại SAF; phần mã hóa, xuất/nhập và kho khóa đã được kiểm thử instrumentation. Không có kiểm thử Google login, game, DRM, native clone, split merging hoặc phiên bản Android khác. Không cam kết vượt chống gian lận. Xem README để biết phạm vi từ chối của bản đầu.
