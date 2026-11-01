# Thành phần bên thứ ba

Bản đóng gói sử dụng CPython, Qt/PySide6 và các thư viện Python không sửa đổi. Thư mục LICENSES kèm ZIP chứa thông báo giấy phép thu thập từ bản cài và văn bản LGPL/GPL của Qt. Mã ứng dụng và script build nằm trên nhánh email-check-excel-windows của kho GitHub bàn giao.

| Thành phần | Giấy phép / mã nguồn |
|---|---|
| CPython | PSF; https://github.com/python/cpython/tree/3.12 |
| Qt / PySide6 / shiboken6 6.8.3 | LGPLv3 hoặc GPLv3; https://code.qt.io/cgit/qt/qtbase.git/?h=v6.8.3 ; https://code.qt.io/cgit/pyside/pyside-setup.git/?h=v6.8.3 |
| openpyxl | MIT; https://foss.heptapod.net/openpyxl/openpyxl |
| email-validator | Unlicense; https://github.com/JoshData/python-email-validator |
| dnspython | ISC; https://github.com/rthalley/dnspython |
| Google API Python Client / google-auth / google-auth-oauthlib | Apache-2.0; https://github.com/googleapis/google-api-python-client ; https://github.com/googleapis/google-auth-library-python ; https://github.com/googleapis/google-auth-library-python-oauthlib |
| requests | Apache-2.0; https://github.com/psf/requests |
| PyInstaller bootloader | GPL với ngoại lệ phân phối ứng dụng; https://github.com/pyinstaller/pyinstaller |

Không sửa đổi Qt/PySide6. Có thể dùng mã nguồn và script build để tạo lại ứng dụng với thư viện tương thích được thay thế. Các quyền theo LGPL, gồm sửa đổi và phân tích ngược để gỡ lỗi thay đổi thư viện, không bị hạn chế bởi thông báo này. Mã nguồn Qt/PySide6 đúng phiên bản có tại các liên kết trên.

Danh sách tên miền email tạm thời: disposable-email-domains/disposable-email-domains, CC0 1.0, bản chụp 2026-11-01. Giấy phép có trong LICENSES/disposable-domains-CC0.txt; nguồn và commit trong DISPOSABLE-SOURCES.json.
