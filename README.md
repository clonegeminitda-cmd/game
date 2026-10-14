# DARK EVIDENCE · HỒ SƠ BÓNG TỐI

**Prototype Giai đoạn 1 — Tiếng Gõ Phòng 307**. Game điều tra góc nhìn thứ nhất bằng tiếng Việt, Godot **4.6.3**, renderer **Compatibility**, dành cho Windows 10/11 64-bit. Đây là lát cắt chơi đơn của dự án, chưa phải bản co-op hay vụ án đầy đủ dài 30 phút.

## Chơi ngay trên Windows

Giải nén `builds/DarkEvidence-Windows-x86_64-release.zip` rồi mở **DarkEvidence.exe**. Bản xuất đã đóng gói tài nguyên, máy người chơi không cần Godot, Python hoặc Blender. Yêu cầu driver đồ họa hỗ trợ OpenGL 3.3. Xem [hướng dẫn Windows](docs/RUN-WINDOWS.txt).

Nếu dùng mã nguồn: tải Godot **4.6.3 Standard** từ [godotengine.org](https://godotengine.org/download/windows/), chọn **Import → project.godot**, sau đó nhấn **F6** ở `scenes/main.tscn` hoặc **F5**. Không cần bản .NET. Mở project bằng Compatibility; không chuyển sang Forward+ trên laptop dùng Intel UHD.

## Nội dung có thể chơi

- Bản đồ 3D có va chạm: hành lang tầng 3, trạm y tá, phòng 307 và phòng camera; đồ đạc, biển phòng, ánh sáng và âm thanh không gian.
- Đi/chạy/cúi, chuột quan sát, đèn pin, tương tác trong tầm với; tường chặn tia tương tác.
- Sáu vật chứng. Mở vật chứng để đọc dấu vết, chọn nhận định, sửa nhận định sai và ghi vào hồ sơ. Có bài toán hiệu chỉnh thời gian, kiểm tra lời khai và phân biệt suy đoán với chứng cứ.
- Sổ điều tra: vật chứng, lời khai bằng biên bản, timeline, ghi chú cá nhân, gợi ý và nộp giả thuyết.
- Ba loại kết quả: đúng và đủ chứng cứ; đúng hướng nhưng chưa đủ chứng cứ; kết luận sai. Có thể tiếp tục điều tra sau kết luận.
- Tự lưu và tiếp tục phiên chơi, bốn mức đồ họa, giới hạn 30/45/60/90 FPS, âm lượng, độ nhạy chuột, độ phân giải/toàn màn hình và chỉ số hiệu năng.

**Chưa phát triển:** kết nối Internet/relay/lobby, đồng đội AI, chuyển giao AI cho bạn bè, ba nghề có cơ chế chuyên biệt, NPC người có animation và hội thoại phân nhánh, minigame pháp y, máy ảnh/UV, bảng kéo-thả nối chứng cứ, toàn bộ bệnh viện và các vụ án mở rộng. Không có nút online giả hoặc NPC giả đóng vai người chơi mạng. Vật chứng và báo cáo trong bản này là dữ liệu của câu đố, không phải kết quả mô phỏng chuyên môn.

## Điều khiển

| Phím | Thao tác |
|---|---|
| W A S D / Chuột | Di chuyển / nhìn |
| Shift / Ctrl | Chạy / cúi (giữ) |
| E | Khám xét vật chứng đang ngắm |
| F | Bật/tắt đèn pin |
| Tab | Sổ điều tra |
| M | Sơ đồ khu vực |
| Esc | Đóng bảng / tạm dừng |
| F3 | Bật/tắt thông số hiệu năng |

Quan sát bàn tiếp nhận phía sau điểm xuất phát, đồng hồ gần trạm y tá, phiếu trên vách hành lang, phòng 307 bên phải và phòng camera bên trái. Sổ điều tra có gợi ý tùy chọn. Lời giải có trong [hồ sơ thiết kế — có spoiler](docs/CASE_307.md).

## Cấu trúc mã nguồn

```text
project.godot                  Cấu hình engine, Compatibility, autoload
scenes/main.tscn               Scene khởi chạy
scripts/main.gd                Ghép các hệ thống, phiên chơi, autosave
scripts/core/game_state.gd     Dữ liệu vụ án, kiểm tra hành động, kết luận
scripts/core/save_store.gd     Đọc/ghi tiến độ có kiểm tra
scripts/core/settings.gd       Đồ họa, điều khiển, âm thanh
scripts/core/atmosphere.gd     Tiếng mưa, tiếng điện, sự kiện tiếng gõ
scripts/player/player.gd       CharacterBody3D, camera, raycast, đèn pin
scripts/world/                Bệnh viện dựng bằng mã và vật chứng
scripts/ui/                   Menu, HUD, hồ sơ, cài đặt, khám xét
data/cases/room_307.json        Nội dung tiếng Việt và lời giải xác định
assets/                       Font có giấy phép, âm thanh tự tạo, biểu tượng
tests/                        Kiểm thử hành vi và công cụ chụp hình
tools/                        Thiết lập Linux, chạy Godot, xuất Windows
docs/                         Kiến trúc, nội dung, quy trình tài sản và build
```

Geometry và UI được dựng trong các module riêng khi chạy `main.tscn`; không cần tự tạo node trong editor để chạy game. Có thể thay geometry bằng scene/glTF mà không đổi dữ liệu vụ án. [Hợp đồng module](docs/IMPLEMENTATION_CONTRACT.md) và [kiến trúc mở rộng](docs/ARCHITECTURE.md) mô tả ranh giới hệ thống.

## Phát triển và kiểm thử trong môi trường đám mây

Từ `/workspace/game`:

```bash
tools/setup.sh --with-xvfb
tools/godot.sh --headless --editor --import
bash tests/run.sh
bash tests/smoke.sh render
tools/export_windows.sh release
```

Trên desktop Linux có màn hình, chạy `tools/godot.sh` để chơi. Xvfb dùng cho kiểm thử đồ họa trong cloud. [BUILD.md](docs/BUILD.md) ghi phiên bản, kiểm tra checksum, vị trí công cụ và các yêu cầu hệ thống. Mỗi nhiệm vụ cloud đã biệt lập: sử dụng checkout hiện có, không cần tạo Git worktree.

[Kết quả kiểm thử](docs/VALIDATION.md): 92 kiểm tra hành vi đạt; đã kiểm tra ảnh OpenGL và gói Windows. Windows EXE chưa được chạy trên máy Windows thật.

## Lưu tiến độ và hiệu năng

Godot lưu dữ liệu tại `user://` trong thư mục dữ liệu ứng dụng của tài khoản. Trên Windows thường là `%APPDATA%\Godot\app_userdata\DARK EVIDENCE — Hồ Sơ Bóng Tối\`. Trong cloud, wrapper dùng `/workspace/.dark-evidence-tools/xdg/data/`. Bài kiểm thử dùng thư mục riêng để không ghi đè phiên chơi thật.

Bốn preset điều chỉnh render scale, khử răng cưa và LOD; đèn được giới hạn và không bật bóng động. 30/45/60/90 là **giới hạn FPS**, không phải cam kết đạt được. Chưa đo trên Intel UHD/i5-U hoặc máy Windows thật. Bản đồ nhỏ dùng ánh sáng đơn giản; chưa có pipeline bake ánh sáng, atlas và streaming khu vực của bản phát hành lớn. Đo trên phần cứng mục tiêu trước khi đặt chuẩn hiệu năng.

Tài sản 3D hiện tại là mô hình hình học gốc có thể thay thế, không phải nhân vật bán hiện thực hoàn chỉnh. Font Noto Sans và Liberation có thông báo giấy phép trong `assets/fonts/`; âm thanh được tạo bởi `tools/generate_audio.py`. Không sử dụng ảnh tham khảo trong yêu cầu làm tài sản game.
