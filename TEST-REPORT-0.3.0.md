# APK Tách Gốc 0.3.0 — kiểm tra nhiều lỗi, lịch sử và accountType qua tài nguyên

Bản APK debug, versionCode 4, Android 8.0 trở lên. Cùng chứng chỉ công cụ các bản trước (`97488eff9cd99543af0bb4c9d5806d2950d5fd57551aed31558cc4ed36cb0296`) để cài cập nhật. Toàn bộ xử lý chạy trên Android, không quyền Internet/root.

## Kết quả đã chạy

- Kotlin/Android SDK 35 build thành công, Android Lint 0 lỗi / 27 cảnh báo. APK công cụ cuối qua apksigner v2 và zipalign. SHA-256: `3490316b5952bfe8704e8b5648f99ff4b8f5d9048dbb1b0b418c50ac18011900`.
- **16/16 kiểm thử JVM qua**, gồm hồi quy tách gốc/ký lại Java/Kotlin/native, khóa và các gói bị từ chối. Bổ sung @string/bí danh/cấu hình accountType, tài nguyên thiếu/vòng lặp, quét nhiều lỗi và tiếp tục DEX/native khi manifest hỏng.
- accountType được giải theo toàn bộ cấu hình và bí danh, giữ ID tham chiếu trong XML; ánh xạ chuỗi đích chính xác. Mẫu có account-authenticator và sync-adapter dùng @string, bí danh, cấu hình mặc định/tiếng Việt. Kiểm tra cả hai giá trị được chuyển sang định danh riêng. Tài nguyên thiếu/vòng lặp từ chối tạo file kết quả.
- Mẫu hỏng có **9 lỗi chặn độc lập**: sharedUserId; base cần split; tên lớp qua tham chiếu tài nguyên chưa hỗ trợ; vòng lặp accountType; hai asset chứa định danh; hai thư viện ELF có định danh cần sửa; một ELF bị cắt cụt. Cùng một lượt quét đọc đủ 20/20 mục ZIP/CRC, 2/2 XML, 3 DEX, 2 asset và 3 thư viện native. Không dừng sau lỗi accountType hoặc thư viện đầu.
- Manifest bị làm hỏng cũng được thử: báo lỗi manifest rồi tiếp tục khảo sát DEX/ELF độc lập; thư viện ELF hỏng vẫn có trong báo cáo. Định danh chưa đọc được được ghi là chưa thể đối chiếu, không suy đoán.
- **2/2 instrumentation Android qua**, thời gian 77,861 giây, emulator Android 8.0.0/API 26 x86_64, phần mềm không KVM. Log cuối `history-device-test-pass.log`.
- `collectsAllErrorsPersistsAndCopiesOneReport`: đọc APK lỗi vẫn giữ bản sao đầy đủ để quét; quét đủ 9 lỗi; đọc lại lịch sử từ đĩa; bấm nút Sao chép thật qua UI; đọc clipboard trên luồng chính và đối chiếu nguyên văn với báo cáo. Tất cả tên XML/asset/native và SHA-256 có trong một lần sao chép.
- `buildsAccountResourceApkThroughServiceAndRecordsSuccess`: chạy service INSPECT và BUILD thật. Service quét trước, sửa accountType, đóng gói/ký/xác minh trên Android; lịch sử SUCCESS với 0 lỗi chặn. APK đầu ra SHA-256 `9a419693622cca8182df8860785fc389d0d21d810d78846a52ddbaf3da8a0b58`, package mới `vn.apktachgoc.sample.tachgoc`. Qua apksigner v2/v3 và căn chỉnh ZIP.
- Thử giao diện trên APK công cụ cuối: force-stop rồi mở lạnh công cụ, mở Lịch sử; bản ghi 9 lỗi vẫn còn. Nút Lưu TXT mở SAF và xuất vào Downloads. Tệp TXT 5.321 byte **giống hệt từng byte** với báo cáo clipboard của kiểm thử, gồm đủ 9 lỗi.
- Cài đồng thời app mẫu gốc và app mẫu tách gốc trên emulator, mở cả hai. Android Resources đọc accountType qua bí danh: bản gốc `fixed.account.sample`, bản sao `vn.apktachgoc.sample.tachgoc.account.…`; bản sao mở được, kiểm tra package/BuildConfig/provider/tài nguyên trong MainActivity qua. Không tạo tài khoản thật hoặc kiểm thử đăng nhập dịch vụ ngoài.

## Hành vi và phạm vi

Nút Kiểm tra toàn bộ khảo sát các phần độc lập theo chế độ đã chọn, thu thập lỗi theo tệp/thuộc tính và số mục đã quét. Tạo và ký cũng quét trước; còn lỗi chặn thì chưa xuất APK. Mỗi thư viện native được kiểm tra riêng, lỗi của thư viện này không bỏ qua các thư viện khác. Khi manifest/tài nguyên hỏng, có nhánh kiểm tra độc lập bằng ZIP.

Lịch sử lưu AtomicFile trong vùng riêng không sao lưu, tối đa 50 phiên, gồm đọc/quét/tạo thành công hoặc lỗi. Có Sao chép và Lưu TXT thật. Ghi tên file, package/phiên bản/SHA-256, máy/Android/ABI/heap, chẩn đoán, giai đoạn và lỗi kỹ thuật; không ghi khóa riêng, mật khẩu hay dữ liệu đăng nhập, không tự gửi. Phiên chưa xong vẫn có bản ghi và mốc cuối. Giới hạn 100 mốc tiến trình gần nhất, 500 phát hiện/khoảng 95.000 ký tự chi tiết mỗi quét; phần lược bớt được nêu rõ.

Chưa có APK Liên Quân cụ thể của người dùng; không xác nhận game này chạy hoặc biết hết mọi điều kiện của nó. Chưa thử điện thoại vật lý/ARM ở bản này. Kiểm tra tĩnh không thể biết mọi lỗi chỉ lộ ra khi đóng gói/ký/chạy. ZIP không an toàn/quá lớn có thể không đọc hết; báo cáo ghi rõ phần chưa khảo sát. Không cố vượt giới hạn hoặc xuất APK lỗi rồi báo thành công. Native có định danh mã hóa/tạo động, chữ ký/DRM/Google login/chống gian lận có thể vẫn cần xử lý riêng.

Báo cáo các bản trước được giữ trong TEST-REPORT-0.1.0.md, TEST-REPORT-0.1.1.md và TEST-REPORT-0.2.0.md. Các log/ảnh/XML/TXT của bản này trong `verification/history-0.3.0/`.
