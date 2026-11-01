# Email Check Excel 1.0.0

Ứng dụng Windows 10/11 x64 kiểm tra danh sách Excel/CSV, gửi thử có xác nhận qua Gmail và xuất kết quả trung thực.

## Mở ứng dụng

Nhấp đúp **EmailCheckExcel.exe**. Không cần cài Python, Excel, công cụ lập trình hay quyền Administrator. Nếu nhận ZIP, giải nén trước rồi mở EXE. Không tắt Defender. Bản phát hành chưa ký số; tùy chính sách Windows, hệ thống có thể yêu cầu kiểm tra nguồn tải hoặc chặn ứng dụng chưa được tin cậy.

## Kiểm tra Excel ngay, không cần Gmail

1. Chọn `.xlsx` hoặc `.csv`, chọn sheet và cột email. Dòng 1 là tiêu đề; xem trước 50 dòng.
2. Bấm **Kiểm tra**. Cú pháp và DNS được kiểm tra trên luồng nền, tối đa 8 tên miền đồng thời. Có tiến trình, số dòng, thời gian và hủy. DNS dùng cấu hình mạng của Windows; mạng chặn DNS sẽ cho kết quả lỗi tạm thời, không suy diễn hộp thư không tồn tại.
3. Mỗi trang kết quả chứa tối đa 1.000 dòng; dùng bộ lọc và chọn trang. Giới hạn nhập 100.000 dòng/1.000 cột; tệp lớn hơn bị từ chối, không bị cắt âm thầm. Có thể tiếp tục phiên đã hủy và khôi phục phiên đã lưu.
4. **Không gửi — xuất kết quả** lưu Excel mới bất cứ lúc nào sau khi bắt đầu kiểm tra, gồm tổng hợp, đầy đủ và chưa xác định. Không ghi đè nguồn. Dữ liệu đang kiểm tra được chụp tại lúc xuất; các dòng chưa xong giữ trạng thái chưa kiểm tra.

Giữ cột, thứ tự dòng và giá trị ô của sheet đã chọn; bổ sung các cột kết quả. Không sao chép định dạng, macro, công thức thực thi hay các sheet nguồn khác. Công thức nguồn được xuất thành văn bản an toàn, không được thực thi. Chuỗi bắt đầu bằng `=`, `+`, `-`, `@` được lưu rõ là kiểu văn bản OOXML. Ký tự điều khiển không hợp lệ trong XML bị loại khi xuất; dữ liệu gốc vẫn lưu trong SQLite. CSV đọc UTF-8/BOM hoặc dự phòng Windows-1258; không xuất CSV, chỉ xuất XLSX an toàn.

Địa chỉ nguồn không bị sửa. Địa chỉ chuẩn hóa nằm ở cột riêng. Gmail cá nhân / googlemail.com được gộp dấu chấm và +tag khi lọc trùng; Workspace dùng tên miền riêng không áp dụng quy tắc này. Phần trước @ ở nhà cung cấp khác giữ phân biệt hoa thường theo chuẩn. Địa chỉ nghi gõ sai không được tự sửa. Địa chỉ Unicode được kiểm tra nhưng chức năng gửi hiện yêu cầu phần trước @ là ASCII.

Cache DNS lưu SQLite, tôn trọng TTL dương (tối đa 24 giờ), lỗi tạm thời 60 giây và âm tính 5 phút. Phân biệt MX, Null MX, NXDOMAIN, timeout và lỗi tạm thời. Khi không có MX, kiểm tra A/AAAA theo tuyến nhận thư dự phòng RFC 5321. Không quét SMTP, không dò đăng nhập/đăng ký/khôi phục tài khoản Google.

## Ý nghĩa kết quả

- **Chưa xác định:** mặc định, kể cả cú pháp/DNS hợp lệ, Gmail chấp nhận thư hoặc không có thư báo lỗi sau 48 giờ.
- **Máy chủ báo hộp thư không tồn tại:** chỉ có DSN khớp định danh thư gốc, đúng người nhận, action failed, status 5.1.1 và chẩn đoán rõ hộp thư không tồn tại.
- **Đã nhận phản hồi xác nhận tương ứng của người nhận:** phản hồi từ địa chỉ tương ứng, tham chiếu đúng thư, chứa dòng xác nhận riêng. Không dùng pixel theo dõi. Đây là bằng chứng theo nội dung và tiêu đề email, không phải xác thực danh tính và không chống mọi kiểu giả mạo.

Đầy hộp thư, hạn mức, bị chặn, timeout và mất mạng không bị ghi thành hộp thư không tồn tại. DSN không theo chuẩn/không đủ định danh sẽ không được liên kết phỏng đoán; vẫn chưa xác định.

## Kết nối Gmail lần đầu

1. Tạo/chọn dự án trong [Google Cloud Console](https://console.cloud.google.com/) và bật Gmail API.
2. Cấu hình Google Auth Platform / OAuth consent screen. Nếu External ở Testing, thêm tài khoản của bạn vào Test users.
3. Tạo OAuth Client ID loại **Desktop app**, tải tệp JSON. Không sử dụng Web app.
4. Trong tab **Kết nối Gmail**, bấm **Nhập JSON OAuth Desktop**, sau đó **Kết nối Gmail**. Trình duyệt Google mở để đăng nhập và cấp quyền. Không nhập mật khẩu Gmail vào ứng dụng.

Quyền `gmail.send` dùng gửi các thư được chọn; `gmail.readonly` dùng đọc nội dung, thông báo lỗi và định danh để đối chiếu. Không xin quyền xóa/sửa thư hay quản lý tài khoản. Quyền readonly cho phép truy cập hộp thư, vì vậy chỉ cấp cho ứng dụng bạn tin cậy. Không có thông tin xác thực của nhà phát triển trong bản phát hành.

Testing có giới hạn test users; refresh token của External Testing thường hết hạn sau 7 ngày đối với các scope này. `gmail.readonly` là restricted scope; phát hành rộng có thể cần xác minh Google và các yêu cầu bổ sung tùy cách sử dụng. Hạn mức Gmail phụ thuộc tài khoản/chính sách Google. App không hứa gửi hết 1.000 thư/ngày.

Token được mã hóa **Windows DPAPI CurrentUser**; không lưu token văn bản hoặc ghi token vào log. Tệp OAuth Desktop do chính bạn cung cấp được lưu riêng (client secret Desktop không phải mật khẩu tài khoản). Sau khi mở lại app, kết nối đã lưu được phục hồi; token hết hạn/thu hồi cần kết nối lại. Ngắt kết nối xóa token cục bộ; thu hồi quyền trên trang Bảo mật của Tài khoản Google nếu cần.

## Gửi tùy chọn và theo dõi

Không ai được chọn mặc định. Chỉ dòng cú pháp hợp lệ, có tuyến nhận thư, không trùng và chưa có trong nhật ký gửi mới được chọn. Chọn từng địa chỉ, sửa tiêu đề/nội dung, **Xem trước thư đã chọn**, xác nhận người nhận đã đồng ý hoặc đang mong đợi liên hệ, rồi xác nhận thêm vào hàng đợi. Khi chỉnh nội dung, phải xem trước lại. Mỗi thư có một người nhận và dòng xác nhận riêng được hiển thị trong phần xem trước.

Tab **Hàng đợi và phản hồi** cho phép bắt đầu, tạm dừng, tiếp tục hoặc hủy thư chưa gửi. Mặc định tối đa 50 lần thử/24 giờ, cách nhau 30 giây; có thể cấu hình 1–500 và tối thiểu 6 giây. Đây là giới hạn thận trọng do app đặt, không bảo đảm tránh spam hoặc tăng hạn mức Google. Không xoay tài khoản/IP/proxy để vượt giới hạn.

SQLite ghi trạng thái trước khi gửi. Khi app dừng lúc đang gửi, hoặc lỗi kết nối khiến không rõ đã gửi chưa, thư chuyển **Cần đối soát**, không tự gửi lại. Nút đối soát tìm đúng Message-ID trong Thư đã gửi. Nếu không tìm thấy vẫn không tự gửi lại. Nhật ký ngăn gửi trùng trên các phiên; không có nút xóa nhật ký để tự động thử lại. Lỗi gửi rõ ràng cũng không tự thử lại. Hạn mức/bị chặn hoặc lỗi gửi làm hàng đợi dừng. Ít nhất 3 thư trả về khác nhau trong 24 giờ sẽ dừng hàng đợi. Xác nhận tiếp tục chỉ áp dụng những thư còn chờ, không gửi lại thư lỗi hoặc cần đối soát.

Theo dõi trong 48 giờ, khoảng 5 phút khi app mở/kết nối, và trong quá trình gửi. Lúc đóng app việc theo dõi tạm dừng; checkpoint SQLite tiếp tục lúc mở lại. Có nút cập nhật cả thư quá 48 giờ. Không có phản hồi thì vẫn Chưa xác định. Thư đến có thể chậm; DNS/DSN/phản hồi không bảo đảm tuyệt đối khả năng chuyển phát tương lai.

## Dữ liệu và quyền riêng tư

Lưu tại `%LOCALAPPDATA%\EmailCheckExcel`: SQLite (dữ liệu nguồn, kết quả, nội dung thư, hàng đợi, checkpoint), JSON OAuth của bạn và token `.dpapi`. Không yêu cầu Administrator. Bảo vệ tài khoản Windows, thư mục này và các bản sao lưu. App không gửi dữ liệu về máy chủ riêng. Kiểm tra DNS chỉ hỏi tên miền, Gmail được truy cập khi bạn đã kết nối. Khi xuất Excel, các dữ liệu có trong bảng nguồn vẫn có trong tệp xuất.

## Kiểm thử và build lại

`sample/` chứa dữ liệu GIẢ 1.000 dòng; tuyệt đối không chọn gửi thật tới các địa chỉ trong mẫu. Kiểm thử dùng DNS/Gmail mô phỏng để kiểm tra import, trùng, các nhánh DNS, hủy, khôi phục SQLite, xuất an toàn, Gmail hạn mức/bị chặn, lỗi mạng chưa rõ trạng thái, đối soát, DSN và phản hồi xác nhận. Không gửi thư thật hàng loạt.

Trên Windows x64 có Python 3.12, chạy `powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1` trong thư mục mã nguồn (ExecutionPolicy chỉ cho script build trong tiến trình này; không tắt Defender). Script cài phụ thuộc, chạy test, build PyInstaller một EXE, khởi động EXE thực tế để kiểm tra GUI/import/export 1.000 dòng và DPAPI, rồi tạo ZIP. `KIEM-THU-WINDOWS.json` là bằng chứng kiểm thử EXE khi build thành công; DNS trong smoke test là mô phỏng. Không có bằng chứng đó thì không suy ra đã chạy EXE thành công.

Chạy mã nguồn: `python -m pip install -r requirements.txt`, sau đó `python main.py`. Linux chỉ dùng để kiểm tra Excel/phát triển; Gmail dùng DPAPI yêu cầu Windows. CI ở `.github/workflows/email-check-windows.yml` dùng runner Windows x64 và tải artifact thực tế sau khi test/build/khởi động EXE thành công.
