# APK Tách Gốc 0.1.0

Ứng dụng Android viết bằng Kotlin, giao diện tiếng Việt, chạy hoàn toàn trên điện thoại và không cần root. Đây là bản APK cài thử (debug). Không có quyền Internet và không gửi APK hoặc khóa ký lên máy chủ.

## Tải và cài

Mở thư mục `downloads` trên GitHub, chọn `APK-Tach-Goc-0.1.0-test.apk` rồi bấm **Download raw file**. Nếu dùng trang GitHub trên điện thoại, có thể mở liên kết tải trực tiếp trong phần bàn giao.

1. Cài APK, cho phép trình duyệt/trình quản lý tệp cài ứng dụng từ nguồn này nếu Android hỏi.
2. Mở **APK Tách Gốc → Chọn file APK**. Ứng dụng đọc tên, phiên bản và package từ bản sao nội bộ; không ghi vào tệp gốc.
3. Chọn **Ký lại APK**, hoặc **Tạo bản tách gốc** và nhập tên/package riêng. Ví dụ `vn.ghi_chu.banrieng`. Package phải khác bản gốc, viết thường.
4. Bấm **Tạo và ký APK**, đợi xác minh. Sau đó dùng **Lưu APK**, **Chia sẻ APK** hoặc **Mở trình cài đặt Android**. Android có thể yêu cầu quyền cho công cụ cài APK.
5. Cài và kiểm tra ứng dụng. Phiên đăng nhập trong bản sao bắt đầu mới. Không sao chép dữ liệu hoặc token đăng nhập của bản gốc.

**Ký lại APK** giữ nguyên package nên không cài cạnh bản gốc và thường không cập nhật được bản gốc có chữ ký khác. **Tách gốc** tạo package riêng, có UID/vùng dữ liệu riêng, được Android cài độc lập. Bản sao đã cài không phụ thuộc vòng đời của bản gốc hoặc công cụ.

## Giữ khóa để cập nhật

Khóa RSA 3072 bit được tạo và tái sử dụng trên máy. Khóa riêng được mã hóa AES-256-GCM; khóa bọc nằm trong Android Keystore. Tệp khóa nằm trong vùng không sao lưu của ứng dụng; không dựa vào việc sao lưu hệ thống để khôi phục khóa.

Trước khi gỡ công cụ, dùng **Xuất khóa có mật khẩu (.p12)**. Mật khẩu tối thiểu 10 ký tự, nên dùng mật khẩu ngẫu nhiên dài. Tệp PKCS#12 dùng AES-256-CBC, PBKDF2-HMAC-SHA256 với 210.000 vòng và MAC SHA-256 với 210.000 vòng. Khóa riêng được mã hóa; chứng chỉ trong tệp là thông tin công khai. Cất riêng tệp và mật khẩu. Nhập lại đúng khóa và dùng cùng package để tạo bản cập nhật; versionCode của APK nguồn cần phù hợp quy tắc cập nhật Android. Nếu công cụ biết package đã được tạo bằng khóa khác, nó chặn ký bằng khóa mới.

Gỡ công cụ xóa khóa lưu nội bộ và các APK chưa xuất. Ứng dụng bản sao đã **cài** và dữ liệu của nó vẫn còn. Muốn giữ tệp APK, hãy lưu ra thư mục do bạn chọn trước khi gỡ công cụ.

## Phạm vi bản đầu

- Nhận APK đơn hoàn chỉnh, DEX tiêu chuẩn, gồm cả nhiều DEX. Giới hạn tệp 512 MB, mỗi mục ZIP 200 MB, tổng giải nén 1 GB và 40.000 mục; giới hạn RAM của điện thoại vẫn có thể thấp hơn.
- Đọc/sửa manifest và tài nguyên nhị phân bằng ARSCLib. Giữ namespace lớp DEX và chuyển tên lớp tương đối sang tên đầy đủ trước khi đổi package.
- Tạo bảng ánh xạ cho package, provider authorities (kể cả authority không bắt đầu bằng package), quyền do app khai báo, account type trong XML authenticator/sync adapter, task affinity, process toàn cục, action/category/scheme thuộc package cũ. Sửa các giá trị định danh khớp toàn bộ và authority có ranh giới trong URI `content://`; sửa hằng chuỗi trong DEX, static values/annotations và tài nguyên. DEX thư viện không chứa giá trị cần đổi được giữ nguyên từng byte. Không thay thế chuỗi con hàng loạt trong mã hoặc dữ liệu.
- Xóa chữ ký cũ, đóng gói/căn chỉnh ZIP, ký v1/v2/v3 bằng apksig, rồi xác minh chữ ký v2, chứng chỉ, manifest, phiên bản, CRC và SHA-256 đầu vào. Kết quả chỉ được đổi tên thành APK cuối sau khi qua kiểm tra. Tệp lỗi không được công bố là thành công.
- Từ chối split/config APK, base có dấu hiệu cần split, APKS/XAPK/AAB, sharedUserId, overlay/instrumentation/thư viện chia sẻ, nhiều package tài nguyên, tên lớp/định danh manifest qua tham chiếu tài nguyên chưa hỗ trợ.
- **Chưa tách gốc APK chứa `.so`**, mã nhúng hoặc asset/raw có định danh gốc cần bộ xử lý riêng. Chế độ ký lại hỗ trợ giữ mã native và căn chỉnh thư viện không nén 16 KB; không sửa ELF hay đảm bảo thư viện tương thích mọi thiết bị 16 KB.
- Không thể phát hiện mọi phụ thuộc split bị nhà đóng gói xóa dấu hiệu; không đảm bảo xử lý được định danh tự sinh/ghép động, mã được mã hóa, framework đóng gói, phản xạ và đường dẫn hardcode. Nếu trường hợp chưa hỗ trợ được phát hiện thì trả lỗi cụ thể. APK hợp lệ về cấu trúc vẫn có thể không chạy do logic ứng dụng.
- Đăng nhập Google, app links, thông báo đẩy, DRM, dịch vụ ngoài app và kiểm tra chữ ký có thể không hoạt động sau ký lại. Không cam kết tương thích mọi game, không vượt chống gian lận.

## Build và kiểm tra

Yêu cầu JDK 21, Android SDK Platform 35 / Build Tools 35.0.0; có Android SDK qua `ANDROID_HOME` hoặc `local.properties`. Gradle Wrapper 8.11.1 được kèm theo; lần build đầu cần mạng tải SDK/thư viện. Ứng dụng đã cài chạy ngoại tuyến.

```sh
./gradlew :app:assembleDebug :core:test :app:lintDebug
```

APK công cụ: `app/build/outputs/apk/debug/app-debug.apk`.

`core:test` build app mẫu, tạo APK tách gốc thật, kiểm tra provider/quyền/task affinity/tên lớp/tài nguyên/DEX, chữ ký, ký lại, cùng khóa ký, vòng xuất/nhập khóa, mật khẩu sai và các trường hợp bị từ chối. APK mẫu đầu ra nằm ở `core/build/test-artifacts/`.

Để chạy phần kiểm tra xử lý **ngay trong Android** trên thiết bị/emulator đã kết nối:

```sh
./gradlew :app:connectedDebugAndroidTest
```

Phần này thử Android Keystore, PKCS#12 và tạo APK clone/ký lại trên Android. App mẫu và APK do điện thoại tạo được lưu dưới `Android/data/vn.apktachgoc/files/device-test/`. `scripts/device-smoke.sh` (cần Bash, adb và ripgrep) dùng các tệp đó để cài song song, ghi hai marker riêng, kiểm tra UID riêng, mở hai app, gỡ bản gốc rồi gỡ công cụ, và kiểm tra dữ liệu của bản sao. Script mặc định chỉ chạy trên emulator để tránh xóa khóa của công cụ đang dùng trên máy thật.

`downloads/mau-goc.apk` và `mau-tach-goc.apk` là app thử nghiệm. Bản mẫu tách gốc ký sẵn dùng khóa thử riêng. Để thử tạo bản cập nhật, hãy tự tạo bản sao từ `mau-goc.apk` bằng khóa của công cụ trên điện thoại bạn.

Kết quả kiểm thử của bản bàn giao nằm trong `TEST-REPORT.md`, kèm log đã chạy. Không suy diễn kiểm tra JVM thành kết quả chạy trên Android.

## Cấu trúc

- `app/`: giao diện tiếng Việt, foreground service, thông báo tiến trình, SAF, chia sẻ/cài APK, kho khóa Android Keystore.
- `core/`: xử lý ZIP/manifest/tài nguyên/DEX, ký/xác minh và định dạng khóa; dùng lại cùng mã trên JVM và Android.
- `sample/`: app mẫu có phiên đăng nhập mô phỏng, provider, quyền riêng và receiver phục vụ thử nghiệm. Receiver chỉ thuộc app mẫu, không có trong công cụ.
- `scripts/`: kiểm thử cài đặt Android.

Mã nguồn dùng giấy phép MIT; thư viện có giấy phép riêng, xem `THIRD-PARTY-NOTICES.md`.
