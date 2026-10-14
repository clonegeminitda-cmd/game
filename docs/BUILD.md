# Thiết lập, kiểm tra và đóng gói

Dự án dùng **Godot 4.6.3 stable**, GDScript và bộ dựng hình Compatibility (OpenGL). Không cần .NET, dịch vụ trực tuyến, tài khoản hay khóa API để chạy giai đoạn 1. Môi trường cloud hiện tại là Debian 13, Linux x86_64; mỗi tác vụ đã được cô lập, dùng checkout hiện có, không tạo Git worktree trừ khi người dùng yêu cầu.

## Linux và môi trường cloud

Chạy từ thư mục gốc dự án:

```bash
tools/setup.sh --with-xvfb
tools/godot.sh --headless --editor --import
```

`setup.sh` tải bản Linux và bộ export templates chính thức từ Godot 4.6.3, kiểm tra **SHA-512** bằng giá trị cố định lấy từ `SHA512-SUMS.txt` của bản phát hành. Godot không phát hành `SHA256-SUMS.txt` cho phiên bản này. Chỉ các templates Windows x86_64 được giải nén. Script giữ kiểm tra TLS và không cần quyền quản trị. Cần `bash`, `curl`, `unzip`, `sha512sum`; đóng gói ZIP cần thêm Python 3.

Thêm `--with-xvfb` để chuẩn bị màn hình ảo khi cần kiểm tra dựng hình trên cloud. Nếu máy chưa có Xvfb, script tải `xvfb`, `xserver-common`, `libxfont2` qua metadata Debian đã ký, rồi giải nén cục bộ; bước này hỗ trợ Debian 13 và dùng các thư viện hệ thống có sẵn. Không ghi vào `/usr`, `/opt` hoặc thư mục cấu hình hệ thống. `xauth`, `xdpyinfo`, bộ thư viện Mesa/OpenGL và XKB phải có sẵn. Chạy không có `--with-xvfb` nếu chỉ cần kiểm tra headless và export.

Các tệp công cụ nằm ngoài checkout, mặc định tại thư mục `.dark-evidence-tools` cạnh dự án; trong cloud là `/workspace/.dark-evidence-tools`. Các gói tải về chiếm khoảng 1,1 GiB, tổng sau giải nén khoảng 1,5 GiB. Chạy lại setup sẽ kiểm tra gói đã tải, dùng lại chúng và làm mới các tệp đã giải nén. Không thêm engine, templates hay bộ nhớ đệm vào Git.

`tools/godot.sh` chọn engine đã cài và chuyển toàn bộ đường dẫn XDG sang thư mục công cụ có quyền ghi. Lưu game nằm ở `xdg/data/godot/app_userdata/DARK EVIDENCE — Hồ Sơ Bóng Tối/` bên dưới thư mục đó. Biến tùy chọn:

| Biến | Mục đích |
| --- | --- |
| `DARK_EVIDENCE_TOOLS` | Đổi vị trí engine, templates và XDG; dùng cùng giá trị cho setup và các script khác. |
| `DARK_EVIDENCE_DATA_HOME` | Đổi riêng thư mục dữ liệu người dùng, phù hợp với kiểm thử không chạm vào save thật. |
| `GODOT_BIN` | Chỉ định binary Godot riêng; phải dùng đúng 4.6.3. |
| `DARK_EVIDENCE_SCREEN` | Kích thước Xvfb, mặc định `1280x720x24`. |

Các đích mạng cần thiết: `github.com`, `release-assets.githubusercontent.com` cho engine/templates; `deb.debian.org` nếu cài Xvfb. Git clone dùng cấu hình xác thực sẵn có của cloud. Không lưu token hoặc proxy credentials trong script.

## Chạy và kiểm tra

Máy có màn hình desktop:

```bash
tools/godot.sh --editor
tools/godot.sh
```

Bộ kiểm thử tự động dùng thư mục lưu game riêng:

```bash
bash tests/run.sh
```

Kiểm tra startup ngắn trên màn hình ảo, có dựng hình OpenGL thực:

```bash
bash tests/smoke.sh render
```

`with_display.sh` mở một Xvfb riêng có cookie xác thực, tắt lắng nghe TCP, chờ màn hình sẵn sàng và dừng đúng tiến trình nó đã mở khi lệnh kết thúc. Mesa dùng CPU (`llvmpipe`) nên tốc độ ở đây **không phải** phép đo hiệu năng GPU/Windows. `--headless` phù hợp với logic và export, không xác nhận hình ảnh hoặc âm thanh. Các tiến trình không tồn tại qua lần khôi phục môi trường cloud; chạy lại lệnh cần thiết trong tác vụ mới.

Các kiểm tra bắt buộc cho thay đổi gameplay là import thành công, bộ kiểm thử logic và thử luồng chơi liên quan. Khi thay đổi UI/3D, cần thêm dựng hình và kiểm tra ảnh. Các phép đo FPS trên máy Windows thật, âm thanh qua thiết bị thật và kiểm tra điều khiển thủ công cần thực hiện trên máy mục tiêu.

## Xuất Windows x86_64

```bash
tools/export_windows.sh release
# Bản debug có console dành cho chẩn đoán:
tools/export_windows.sh debug
```

Script chạy import rồi export bằng preset `Windows Desktop`, nhúng dữ liệu vào EXE, sao chép hướng dẫn tiếng Việt và giấy phép Godot/font, tạo `SHA256SUMS.txt` cho các tệp và đóng gói:

```text
builds/windows-release/DarkEvidence.exe
builds/DarkEvidence-Windows-x86_64-release.zip
```

ZIP chỉ chứa bản xuất của lần chạy hiện tại. Thư mục `builds/` được bỏ qua bởi Git. Bản export chưa được ký mã. Export thành công trên Linux không chứng minh chương trình đã chạy trên Windows; cần giải nén ZIP và chạy EXE trên máy Windows để nghiệm thu nền tảng đó.

Trên Windows/macOS có thể cài Godot 4.6.3 bản chuẩn từ nguồn chính thức, import `project.godot`, cài export templates cùng phiên bản trong **Editor → Manage Export Templates**, rồi dùng preset **Windows Desktop**. Các shell script đi kèm dành cho Linux; mã dự án và preset dùng được từ Godot Editor trên các hệ điều hành này.

## Nguồn và giấy phép công cụ

- Bản phát hành và checksum: <https://github.com/godotengine/godot/releases/tag/4.6.3-stable>
- Giấy phép Godot: `assets/licenses/Godot.txt`, lấy từ tag `4.6.3-stable/LICENSE.txt`.
- Giấy phép thành phần Godot: `assets/licenses/Godot-ThirdParty.txt`, lấy từ `4.6.3-stable/COPYRIGHT.txt`.
- Giấy phép font: `assets/fonts/LICENSE-Noto.txt` và `assets/fonts/LICENSE-Liberation.txt`.

Các giấy phép này được cung cấp riêng trong ZIP để vẫn đọc được khi chưa mở game.
