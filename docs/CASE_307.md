# Tiếng gõ phòng 307 — lời giải chính thức

**Có tiết lộ lời giải.** Dữ liệu chơi nằm trong `data/cases/room_307.json`. Đây là vụ điều tra rút gọn phục vụ prototype giai đoạn 1, không phải cam kết thời lượng 30 phút hay bộ mô phỏng pháp y. Hiện người chơi kiểm tra vật chứng và biên bản đã lập; hội thoại NPC nhiều nhánh, ba nghề, đồng đội AI và multiplayer chưa được triển khai.

## Sự thật cố định

Kỹ thuật viên **Trần Quốc Huy** gây ra cái chết của y tá **Nguyễn Thị Lan**, người đang yêu cầu giải trình hóa đơn sửa chữa trùng. Huy chủ động ngắt camera, dàn dựng cửa chốt và dùng bộ gõ thử chuông T-04 tạo âm thanh muộn để làm lệch nhận định về thời điểm tử vong. Người bảo vệ nghe một âm thanh có thật nhưng suy diễn rằng nó do Lan tạo ra. Đồng hồ ông dùng chậm bảy phút.

Lời giải không thay đổi theo lần chơi. Không có lựa chọn hung thủ ngẫu nhiên. Âm thanh rùng rợn trong môi trường chỉ tạo không khí; người chơi phải dùng bản ghi thời gian trong hồ sơ, không suy ra giờ vụ án từ lúc một hiệu ứng âm thanh chạy.

## Trình tự đã xác định

| Giờ chuẩn | Sự việc và căn cứ |
| --- | --- |
| 22:50 | Phiếu cấp dụng cụ ghi Huy nhận cước và T-04. |
| 23:12 | Mai rời tầng 3; cô thấy Lan mang hóa đơn chờ Huy. |
| 23:14 | Mai ký nhận thuốc ở tầng trệt, có người thứ hai xác nhận. |
| 23:15 | Ảnh camera cuối trước gián đoạn cho thấy mặt Huy cạnh phòng 307. |
| 23:16 | Tủ kỹ thuật ghi thẻ HUY-02 mở cửa tủ tầng 3. |
| 23:17 | Tài khoản KTH-02 gửi lệnh bảo trì trực tiếp tại tủ, ngắt đường hình. |
| 23:16–23:22 | Khoảng tử vong ước tính của Lan; hồ sơ không xác định chính xác từng phút. Huy gây án trong khoảng này. |
| Trước 23:28 | Huy dàn dựng chốt cửa và đặt T-04 ở khoang kỹ thuật cạnh vách 307. Không có bằng chứng định phút chính xác cho các thao tác này. |
| 23:28 | Camera khôi phục sau 11 phút gián đoạn. |
| 23:39 | T-04 tác động vào vách. Bình nghe ba tiếng gõ và đọc 23:32 trên đồng hồ tường chậm bảy phút. |
| 23:40 | Tổ điều tra tiếp nhận hiện trường; đồng hồ chuẩn chỉ 23:40, đồng hồ tường chỉ 23:33. |
| 23:50 | Báo cáo khám nghiệm sơ bộ được ký nhận. |

Giờ 23:40 trong briefing là lúc phát hiện vụ án. Lúc người chơi có thể đọc hồ sơ, các biên bản và báo cáo sơ bộ đã được lập. Thời gian trong bản lưu đo thời gian chơi, không phải đồng hồ diễn biến sự việc.

## Đường suy luận

| Vật chứng | Quan sát cần chọn | Điều hỗ trợ và giới hạn |
| --- | --- | --- |
| `door_thread` | `staged_lock` | Dấu kéo hướng về khe cửa làm giả thuyết dàn dựng chốt khả thi. Sợi cước không tự xác định hung thủ. |
| `ward_clock` | `add_offset` | Đồng hồ chậm bảy phút: 23:32 trở thành 23:39 giờ chuẩn. Không trừ bảy phút. |
| `cctv_log` | `manual_gap` | Lệnh bảo trì chủ động, ảnh Huy và thẻ được cấp bác lời khai không lên tầng. Không đồng nhất thời gian mất hình với thời điểm chết. |
| `medical_report` | `window_not_knock` | Khoảng tử vong ước tính kết thúc trước tiếng gõ ít nhất 17 phút. Báo cáo không cho một phút chính xác. |
| `maintenance_note` | `timed_knock` | Bản ghi T-04 giải thích nguồn tiếng gõ, phiếu cấp liên kết phương tiện với Huy, thư Lan cho động cơ. Hóa đơn riêng lẻ chưa chứng minh việc gây án. |
| `witness_statement` | `contradiction_huy` | Hai phủ nhận của Huy trái các nguồn độc lập. Bình chỉ nghe âm thanh; Mai có mốc được xác nhận. |

Mỗi vật chứng có ba nhận định. Mở vật chứng bằng E chỉ mở phần kiểm tra; người chơi phải chọn nhận định được chi tiết hỗ trợ để ghi nhận. Chọn sai không mất vật chứng, không tăng tiến độ và có thể đọc lại. Đáp án đúng ở vị trí khác nhau để tránh thói quen luôn chọn cùng một nút. Vật chứng đã ghi nhận vẫn xem lại được, không thu lần hai.

`timeline` trong JSON chứa các mốc có nguồn: trường `requires` chỉ rõ vật chứng cần ghi nhận trước khi hiển thị mốc đó. Mốc tiếp nhận 23:40 có sẵn; mốc hiệu chỉnh 23:39 cần đồng hồ, lời khai và báo cáo pháp y. Kết quả đầy đủ yêu cầu đủ sáu vật chứng và chọn `huy` + `staged_room`.

## Ba kết quả và thử lại

- `correct`: chọn đúng người, đúng cơ chế, đủ sáu nguồn chứng cứ; điểm 100.
- `insufficient`: đúng người và cơ chế nhưng thiếu chứng cứ; điểm từ 60 đến dưới 100 theo số nguồn đã ghi nhận.
- `wrong`: người hoặc cơ chế sai; tối đa 20 điểm cho chứng cứ đã ghi nhận, báo cáo chưa được chấp nhận.

Không kết quả nào khóa vĩnh viễn vụ án. Người chơi tiếp tục đi lại, bổ sung chứng cứ và nộp lại. Thu thêm vật chứng xóa đánh giá cũ để tránh hiển thị một kết quả đã hết phù hợp. Công thức điểm prototype chưa chấm thời gian hoặc chất lượng ghi chú; đây là giới hạn cố ý để không khuyến khích bấm vội. Các thao tác sai không làm hỏng file lưu.

## Hợp đồng dữ liệu và lưu tiến độ

`GameState` là nơi duy nhất nhận lệnh thu thập và nộp kết luận. Mỗi bản ghi lưu mã vật chứng, mã nhận định, người thu thập, thời gian tính từ đầu phiên và phương pháp. Mô tả, kết quả phân tích, vị trí và quan hệ chứng cứ được tra từ hồ sơ gốc theo ID.

`validate_case()` kiểm tra trường văn bản bắt buộc, kiểu danh sách, ID duy nhất, nhận định đúng có tồn tại, liên kết chứng cứ và tham chiếu lời giải. Thêm vụ án mới phải cung cấp dữ liệu và tích hợp vị trí vật chứng tương ứng; prototype hiện nạp một vụ án cố định.

Tiến độ lưu tại `user://case_307_save.json` (trên Windows thường trong `%APPDATA%/Godot/app_userdata/DARK EVIDENCE — Hồ Sơ Bóng Tối/`). JSON dùng schema `version: 1`, không deserialize đối tượng. Loader giới hạn 256 KiB, từ chối sai phiên bản, khác vụ án, trường lạ/thiếu, ID lạ, nhận định không đúng, phương pháp bị sửa, thời gian không hợp lệ, vị trí ngoài khu vực chơi và ghi chú quá 16.000 ký tự. Dữ liệu được kiểm tra toàn bộ trước khi thay trạng thái hiện tại. Một bản lưu hỏng không làm mất phiên đang chơi.

File tạm được ghi, flush, đọc lại và so sánh rồi đổi tên trong cùng thư mục. Nếu ghi hoặc xác minh thất bại, file cũ được giữ. Cơ chế này tránh bản ghi nửa chừng; không phải bảo đảm chống lỗi phần cứng hoặc mất điện ở tầng đĩa. Kết quả và điểm được tính lại từ lựa chọn + vật chứng khi tải, thay vì tin các trường điểm tự nhập. Đây là kiểm tra tính nhất quán của file cục bộ, không phải chống gian lận hay chữ ký xác thực. Ghi đè file JSON thủ công bằng một trạng thái hợp lệ vẫn có thể thay đổi tiến độ.

## Ranh giới cho giai đoạn multiplayer

Giai đoạn 1 không có kết nối mạng. `collect_evidence(id, observation_id)` và `submit_conclusion(suspect_id, mechanism_id)` tạo ranh giới lệnh rõ ràng để mở rộng. Giai đoạn 2 cần chuyển quyền quyết định sang host/server, gán danh tính collector từ phiên đã xác thực, kiểm tra quyền nghề/khoảng cách, kiểm tra ID lệnh chống gửi trùng, phát snapshot/sự kiện có thứ tự và hỗ trợ nối lại. Client không được tự sửa `collected` hoặc quyết định kết luận. File lưu hiện tại chỉ là định dạng offline; phải có migration rõ ràng khi schema online được thêm.
