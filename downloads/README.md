# APK Tách Gốc 0.3.1

Ứng dụng Android viết bằng Kotlin, giao diện tiếng Việt, chạy hoàn toàn trên điện thoại và không cần root. Đây là bản APK cài thử (debug). Không có quyền Internet và không gửi APK hoặc khóa ký lên máy chủ.

## Kết quả sau khi lần tạo mới bị lỗi

Bản 0.3.1 sửa lỗi 0.3.0 có thể hiển thị APK ký lại cũ bên dưới thông báo lần tạo mới thất bại. Khi bắt đầu đọc/quét/tạo mới, công cụ bỏ con trỏ kết quả cũ; nếu chưa có kết quả mới thì ẩn thông tin APK và vô hiệu hóa nút lưu/chia sẻ/cài. Không xóa APK đã tạo, file đầu vào hay khóa ký. Khi mở lại, kết quả cũ còn trong bộ nhớ đệm của 0.3.0 cũng không được khôi phục nếu lịch sử cho thấy phiên mới hơn chưa tạo thành công.

Màn hình lỗi hiển thị tối đa 8 lỗi chặn đầu tiên kèm tệp/thuộc tính, và nút **Sao chép báo cáo lỗi lần này** ngay bên dưới. Nút này sao chép đúng phiên đang báo lỗi, gồm danh sách phát hiện đầy đủ được lưu; không cần chọn lại một phiên Đọc APK trong lịch sử. Các giới hạn xử lý native/game giữ nguyên; sửa hiển thị không có nghĩa đã sửa lỗi của một game chưa có báo cáo chi tiết.

## Kiểm tra toàn bộ và lịch sử sao chép

Bản 0.3.0 có nút **Kiểm tra toàn bộ APK**. Chọn APK, chọn chế độ/nhập package đích rồi bấm kiểm tra. Trình quét tiếp tục qua các lỗi độc lập trong ZIP/CRC, manifest, XML, DEX, asset/raw và từng `.so`. Manifest/tài nguyên hỏng vẫn có nhánh kiểm tra độc lập DEX/native khi ZIP đủ an toàn. Báo cáo ghi số mục đã khảo sát, lỗi theo tệp/thuộc tính và các phần chưa thể kết luận. Bước kiểm tra không tạo APK. **Tạo và ký APK** cũng quét trước, chỉ tiếp tục nếu không còn lỗi chặn.

Mở nút **Lịch sử và báo cáo** ở đầu màn hình, chọn phiên **Kiểm tra toàn bộ**, rồi bấm **Sao chép** để lấy cùng lúc mọi phát hiện trong báo cáo, hoặc **Lưu TXT** qua trình chọn tệp Android. Lịch sử gồm cả lần đọc/tạo lỗi và thành công, giữ tối đa 50 phiên trong bộ nhớ riêng của công cụ, không tự gửi. Báo cáo ghi tên file, package/phiên bản, SHA-256, cấu trúc APK/ABI/native, máy/Android, giai đoạn và lỗi kỹ thuật; không ghi khóa ký riêng, mật khẩu hay dữ liệu đăng nhập. Tối đa 100 mốc tiến trình gần nhất và 500 phát hiện/ khoảng 95.000 ký tự chi tiết cho mỗi lượt quét; nếu vượt giới hạn thì ghi rõ phần lược bớt. Gỡ công cụ xóa lịch sử chưa xuất.

Đã hỗ trợ `android:accountType="@string/..."` trong authenticator/sync-adapter, gồm bí danh và các cấu hình tài nguyên. Giữ ID tham chiếu, ánh xạ giá trị chuỗi đích theo cấu trúc. Phát hiện tài nguyên thiếu, vòng lặp, độ sâu quá mức hoặc kiểu chưa hỗ trợ; báo đường dẫn XML và chuỗi ID thay vì đổi chuỗi mù.

Quét tĩnh không phát hiện được mọi lỗi đóng gói hoặc hành vi khi chạy. Nếu ZIP vượt giới hạn/không an toàn, công cụ ghi phần chưa đọc thay vì khẳng định đã kiểm tra hết. Trường hợp Android dừng tiến trình giữ bản ghi chưa hoàn tất và giai đoạn cuối.

## Tạo ứng dụng khác để cài song song

Bản này mặc định chọn **Tạo bản tách gốc — cài song song**, kể cả APK có `.so`. Nhập tên mới và package mới. Android dùng package để xác định ứng dụng; đổi chữ ký mà giữ package sẽ vẫn mở màn hình cập nhật bản gốc.

Tách gốc native hỗ trợ thư viện không cần sửa định danh bên trong: giữ nguyên namespace lớp/JNI và mọi byte `.so`, đổi định danh Android trong manifest/tài nguyên/DEX. Kiểm tra ELF/ABI và quét các định danh đã biết dạng UTF-8, UTF-16LE/BE, gồm dạng package dùng dấu `/`. Chỉ miễn trừ tên lớp thật có trong DEX, vì đổi namespace lớp sẽ phá JNI. Nếu phát hiện định danh native còn cần sửa, công cụ từ chối và nêu tên thư viện; không tự chuyển sang ký lại. Kiểm tra tĩnh không chứng minh ứng dụng chạy được, không phát hiện được mọi chuỗi mã hóa hoặc định danh tạo lúc chạy. **Chưa kiểm thử Liên Quân**, vì chưa có APK gốc của người dùng.

Cài đè APK công cụ 0.3.1 để cập nhật từ bản cũ; không gỡ công cụ cũ để giữ khóa ký.

## Tải và cài

Mở thư mục `downloads` trên GitHub, chọn `APK-Tach-Goc-0.3.1-test.apk` rồi bấm **Download raw file**.

1. Cài APK, cho phép trình duyệt/trình quản lý tệp cài ứng dụng từ nguồn này nếu Android hỏi.
2. Mở **APK Tách Gốc → Chọn file APK**. Ứng dụng đọc tên, phiên bản và package từ bản sao nội bộ; không ghi vào tệp gốc.
3. Muốn cài cạnh bản gốc, chọn **Tạo bản tách gốc — cài song song** và nhập tên/package riêng. Ví dụ `vn.ghi_chu.banrieng`. Package phải khác bản gốc, viết thường. **Chỉ ký lại** không tạo ứng dụng khác.
4. Bấm **Kiểm tra toàn bộ APK**, đợi kết quả rồi mở **Lịch sử và báo cáo → chọn phiên → Sao chép** nếu cần gửi chẩn đoán. Khi không còn lỗi chặn, bấm **Tạo và ký APK**, đợi xác minh. Sau đó dùng **Lưu APK**, **Chia sẻ APK** hoặc **Cài bản sao (package mới)**. Android có thể yêu cầu quyền cho công cụ cài APK. Kết quả và nút cài ghi rõ loại đầu ra, kể cả sau mở lại công cụ.
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
- Từ chối split/config APK, base có dấu hiệu cần split, APKS/XAPK/AAB, sharedUserId, overlay/instrumentation/thư viện chia sẻ, nhiều package tài nguyên, tên lớp/định danh manifest qua tham chiếu tài nguyên chưa hỗ trợ (accountType trong XML đã có bộ giải @string riêng).
- Tách gốc `.so` thông thường khi kiểm tra ELF và tham chiếu định danh qua. Từ chối native cần sửa định danh, mã nhúng hoặc asset/raw có định danh gốc cần bộ xử lý riêng. Cả hai chế độ đều giữ byte native, đối chiếu SHA-256 và căn chỉnh thư viện không nén 16 KB; không sửa ELF hay đảm bảo tương thích mọi thiết bị 16 KB.
- Không thể phát hiện mọi phụ thuộc split bị nhà đóng gói xóa dấu hiệu; không đảm bảo xử lý được định danh tự sinh/ghép động, mã được mã hóa, framework đóng gói, phản xạ và đường dẫn hardcode. Nếu trường hợp chưa hỗ trợ được phát hiện thì trả lỗi cụ thể. APK hợp lệ về cấu trúc vẫn có thể không chạy do logic ứng dụng.
- Đăng nhập Google, app links, thông báo đẩy, DRM, dịch vụ ngoài app và kiểm tra chữ ký có thể không hoạt động sau ký lại. Không cam kết tương thích mọi game, không vượt chống gian lận.

## Build và kiểm tra

Yêu cầu JDK 21, Android SDK Platform 35 / Build Tools 35.0.0; có Android SDK qua `ANDROID_HOME` hoặc `local.properties`. Gradle Wrapper 8.11.1 được kèm theo; lần build đầu cần mạng tải SDK/thư viện. Ứng dụng đã cài chạy ngoại tuyến.

```sh
./gradlew :app:assembleDebug :core:test :app:lintDebug
```

APK công cụ: `app/build/outputs/apk/debug/app-debug.apk`.

`core:test` build app mẫu, tạo APK tách gốc thật, kiểm tra provider/quyền/task affinity/tên lớp/tài nguyên/DEX, chữ ký, ký lại, cùng khóa ký, vòng xuất/nhập khóa, mật khẩu sai và các trường hợp bị từ chối. Có APK mẫu dùng ELF/JNI thật để thử tách gốc/ký lại, giữ byte `.so` và namespace lớp JNI; thử từ chối định danh native ở UTF-8/UTF-16 qua ranh giới bộ đệm quét, kể cả APK không khai báo tài nguyên riêng. APK mẫu đầu ra nằm ở `core/build/test-artifacts/`.

Để chạy phần kiểm tra xử lý **ngay trong Android** trên thiết bị/emulator đã kết nối:

```sh
./gradlew :app:connectedDebugAndroidTest
```

Phần này thử Android Keystore, PKCS#12 và tạo APK clone/ký lại trên Android. App mẫu và APK do điện thoại tạo được lưu dưới `Android/data/vn.apktachgoc/files/device-test/`. `scripts/device-smoke.sh` (cần Bash, adb và ripgrep) dùng các tệp đó để cài song song, ghi hai marker riêng, kiểm tra UID riêng, mở hai app, gỡ bản gốc rồi gỡ công cụ, và kiểm tra dữ liệu của bản sao. Script mặc định chỉ chạy trên emulator để tránh xóa khóa của công cụ đang dùng trên máy thật.

`downloads/mau-goc.apk` và `mau-tach-goc.apk` là app thử nghiệm. Bản mẫu tách gốc ký sẵn dùng khóa thử riêng. Để thử tạo bản cập nhật, hãy tự tạo bản sao từ `mau-goc.apk` bằng khóa của công cụ trên điện thoại bạn.

Kết quả kiểm thử của bản bàn giao nằm trong `TEST-REPORT.md`, kèm log đã chạy. Không suy diễn kiểm tra JVM thành kết quả chạy trên Android.

## Kiểm thử native

`native-sample/` chứa app mẫu x86_64 có ELF/JNI thật. Hàm C gọi JNI `FindClass` với namespace lớp gốc rồi trả về 73; giao diện chỉ hiển thị kết quả khi nạp và gọi thư viện thành công. Mẫu có SharedPreferences và receiver thử nghiệm để kiểm tra dữ liệu riêng. Có mã C và `scripts/build-native-fixture.sh` để tái tạo bằng GCC trên Linux x86_64/JDK. Đây là fixture cho emulator x86_64, không phải mẫu cho điện thoại ARM; APK công cụ không chứa hoặc nạp thư viện thử này.

Chạy `OnDeviceTest#cloneRealNativeApkOnAndroid` để tách gốc ngay trong Android. `scripts/native-clone-smoke.sh` cài bản gốc và bản sao cùng lúc, mở JNI, kiểm tra UID/phiên riêng, gỡ bản gốc rồi công cụ và mở lạnh bản sao. Script chỉ cho chạy trên emulator và sẽ xóa khóa của công cụ thử nghiệm. `resignRealNativeApkOnAndroid` cùng `scripts/native-smoke.sh` vẫn kiểm tra ký lại. Không dùng script gỡ app với dữ liệu thật.

## Cấu trúc

- `app/`: giao diện tiếng Việt, foreground service, thông báo tiến trình, SAF, chia sẻ/cài APK, kho khóa Android Keystore.
- `core/`: quét nhiều lỗi, giải accountType qua tài nguyên, xử lý ZIP/manifest/tài nguyên/DEX, ký/xác minh và định dạng khóa; dùng lại cùng mã trên JVM và Android.
- `native-sample/`: app mẫu có `.so` thật, phục vụ kiểm thử tách gốc, ký lại và dữ liệu riêng.
- `sample/`: app mẫu có phiên đăng nhập mô phỏng, provider, quyền riêng và receiver phục vụ thử nghiệm. Receiver chỉ thuộc app mẫu, không có trong công cụ.
- `scripts/`: kiểm thử cài đặt Android.

Mã nguồn dùng giấy phép MIT; thư viện có giấy phép riêng, xem `THIRD-PARTY-NOTICES.md`.
