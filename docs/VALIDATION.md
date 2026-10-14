# Kết quả kiểm thử prototype 0.1

Kiểm thử trên cloud Linux x86_64, Godot **4.6.3 stable**, ngày **14/10/2026**. Không suy rộng kết quả này thành chứng nhận chạy trên Windows hoặc benchmark Intel UHD.

| Kiểm tra thực hiện | Kết quả |
|---|---|
| Import project và biên dịch GDScript | Thành công, không lỗi parser/phụ thuộc |
| `bash tests/run.sh --verbose` | **92 đạt, 0 thất bại**, không lỗi runtime/rò rỉ tài nguyên trong lần cuối |
| Dữ liệu và logic vụ án | Sáu vật chứng, ID/tham chiếu hợp lệ, chọn sai không thu được vật chứng, thu lặp không nhân đôi |
| Kết luận | Đúng đủ chứng cứ / đúng nhưng thiếu / sai; có thể tiếp tục và nộp lại |
| Save/load | Round trip ghi chú tiếng Việt, thời gian, tọa độ, vật chứng và kết luận; file hỏng/quá lớn/sai phiên bản bị từ chối mà giữ trạng thái cũ |
| Điều khiển và vật lý | WASD di chuyển thực, cúi/đứng, chạm sàn, tường chặn, hai cửa phòng đi qua được |
| Tương tác | Cả sáu vật chứng ở trong tầm ngắm từ vị trí có thể đứng; tường chặn raycast |
| UI tích hợp | Nút nhận định đúng/sai, Tab mở sổ, ghi chú lưu khi chuyển mục, sơ đồ, đóng bảng phục hồi điều khiển, F3 |
| Đồ họa | Bốn preset áp dụng và giới hạn FPS tới engine; không dùng FXAA không được Compatibility hỗ trợ |
| Dựng hình | Xvfb + OpenGL 4.5 Mesa llvmpipe, 11 ảnh chụp: menu, hành lang, phòng 307, camera, khám xét, hồ sơ, sơ đồ, cài đặt, kết quả và cửa sổ 960×540 |
| Xuất Windows release | Thành công; PE x86_64, tài nguyên PCK nhúng, ZIP CRC và mọi SHA-256 trong manifest đều hợp lệ |
| Nội dung bản xuất | Chạy chính pack nhúng trong EXE bằng Godot Linux headless và OpenGL với `--smoke`, kiểm tra dữ liệu, sáu vật chứng và UI khám xét, rồi thoát đúng quy trình; không dựa vào mã nguồn trong checkout |
| Thiết lập lặp lại | `tools/setup.sh --with-xvfb` kiểm tra lại checksum, dùng lại gói tải và import project thành công |

Phép chụp ảnh có cảnh báo V-Sync không được backend màn hình ảo hỗ trợ; ảnh vẫn được dựng bằng OpenGL. Thông số trên llvmpipe đo CPU software renderer, không đại diện laptop mục tiêu. Audio streams được nạp, chạy và giải phóng; chưa nghe qua thiết bị âm thanh thật trong môi trường cloud.

Các kiểm tra cần làm trên máy đích: giải nén ZIP và chạy EXE Windows 10/11, input chuột thực, Alt-Tab, toàn màn hình/đổi độ phân giải, nghe âm thanh, lưu/tiếp tục qua nhiều phiên và đo CPU/GPU/RAM/FPS trên i5-U/Intel UHD 8 GB. Multiplayer, AI đồng đội và các cơ chế giai đoạn sau chưa được triển khai nên không có kiểm thử đạt cho các tính năng đó.

## Tái hiện

```bash
cd /workspace/game
tools/setup.sh --with-xvfb
bash tests/run.sh
DARK_EVIDENCE_DATA_HOME="$(mktemp -d /tmp/dark-evidence-render.XXXXXX)" \
  DARK_EVIDENCE_CAPTURE_DIR=/workspace/game/builds/screenshots \
  tools/with_display.sh tools/godot.sh --audio-driver Dummy --script res://tests/capture.gd
tools/export_windows.sh release
```

Ảnh và gói xuất nằm trong `builds/` (không đưa vào Git). Script kiểm thử tạo thư mục save riêng, không ghi đè hồ sơ người chơi. Các bài kiểm tra kiểm soát đồng hồ game để kết quả ổn định; playtest thủ công vẫn cần để đánh giá độ khó và thời lượng.
