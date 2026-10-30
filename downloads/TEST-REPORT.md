# APK Tách Gốc 0.3.1 — không hiển thị kết quả cũ sau lần tạo bị lỗi

Bản cài thử Android 8.0+, versionCode 5, cùng chứng chỉ APK công cụ các bản trước để cài cập nhật và giữ khóa. SHA-256 APK công cụ: `ed11068504f0b8e141caf46571a120b939eb5b6151e4118cdd0beb3e459e53ec`.

## Vấn đề và thay đổi

0.3.0 có thể giữ `currentReport` trong giao diện dù trạng thái của lần tạo mới đã xóa kết quả và báo lỗi. Con trỏ `last` cũng có thể khôi phục APK cũ khi mở lại. Vì vậy màn hình có thể vừa báo chưa tạo APK vừa hiện APK ký lại từ trước.

0.3.1 lấy kết quả hiển thị từ cùng một trạng thái hiện hành. Bắt đầu đọc/quét/tạo mới sẽ xóa con trỏ kết quả cũ; khi chưa có kết quả mới thì xóa nội dung kết quả, ẩn thẻ APK và vô hiệu hóa các nút lưu/chia sẻ/cài. Đây chỉ là bỏ con trỏ, không xóa APK đã tạo, file đầu vào hay khóa ký. Khi cập nhật từ 0.3.0, lịch sử mới hơn không thành công cũng ngăn khôi phục con trỏ cũ.

Có tối đa 8 lỗi chặn đầu tiên hiển thị ngay dưới thông báo đỏ kèm tên tệp/thuộc tính. Nút Sao chép báo cáo lỗi lần này lấy đúng bản ghi hiện hành, gồm phần kiểm tra đầy đủ đã lưu, không cần chọn một phiên khác trong danh sách.

## Kiểm tra đã chạy

- Kotlin/Android SDK 35 build và Lint thành công: 0 lỗi, 29 cảnh báo. APK qua apksigner v2 và zipalign, cùng chứng chỉ `97488eff9cd99543af0bb4c9d5806d2950d5fd57551aed31558cc4ed36cb0296`.
- Core xử lý APK không thay đổi; 16 kiểm thử JVM của 0.3.0 giữ nguyên, Gradle xác nhận task core:test UP-TO-DATE khi đóng gói assets cho kiểm thử Android.
- Instrumentation `ResultStateTest#failedCloneCannotResurrectPreviousResignedApk`: **PASS, 57,436 giây**, emulator Android 8.0.0/API 26 x86_64, không KVM.
- Tạo/ký lại APK mẫu thật qua ProcessingService, xác nhận Mode.RESIGN, kết quả hiện trên UI và khôi phục được khi đó là lần thành công gần nhất.
- Gửi yêu cầu tạo bản tách với hai lỗi chủ đích: package `bad` và tên rỗng. Trình kiểm tra gom đúng 2 lỗi, service báo FAILED và chưa xuất APK mới. Đây là mẫu thử, không xác nhận hai lỗi của APK Liên Quân là hai lỗi này.
- Kiểm tra trực tiếp view sau thất bại: hash kết quả cũ không còn trong giao diện, ba nút lưu/chia sẻ/cài đều bị vô hiệu hóa; hiện cả `[Package đích]` và `[Tên bản sao]` dưới thông báo lỗi.
- Bấm nút Sao chép báo cáo lỗi lần này trên UI; clipboard bằng nguyên văn báo cáo của phiên thất bại, có đủ 2 lỗi.
- Giả lập con trỏ cũ của 0.3.0 rồi tạo lại Activity với trạng thái trống: không khôi phục kết quả cũ, các nút đầu ra vẫn bị vô hiệu hóa.
- APK đã ký trước đó vẫn còn; fingerprint khóa ký trước/sau không đổi.

Log và báo cáo mẫu nằm trong `verification/result-state-0.3.1/`. Báo cáo 0.3.0 được giữ riêng ở `TEST-REPORT-0.3.0.md`.

## Giới hạn

Chưa có danh sách chi tiết hai lỗi chặn trên máy người dùng, cũng chưa có APK Liên Quân gốc. Bản này sửa lỗi hiển thị/trạng thái và giúp sao chép chẩn đoán; không khẳng định đã sửa hai lỗi bên trong game. Không bỏ kiểm tra chỉ để xuất APK lỗi.

Chưa chạy trên OnePlus/Android 16 hoặc điện thoại vật lý. Không thay đổi phạm vi native, Google/DRM/chống gian lận; APK hợp lệ về cấu trúc vẫn cần cài thử để kiểm tra hành vi.
