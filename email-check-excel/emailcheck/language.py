from PySide6.QtCore import QTranslator, Qt
from PySide6.QtWidgets import QApplication

TEXT = {
    'OK':'Đồng ý', '&OK':'Đồng ý', 'Cancel':'Hủy', '&Cancel':'Hủy',
    'Yes':'Có', '&Yes':'Có', 'No':'Không', '&No':'Không',
    'Open':'Mở', '&Open':'Mở', 'Save':'Lưu', '&Save':'Lưu',
    'Close':'Đóng', '&Close':'Đóng', 'Help':'Trợ giúp',
    'All Files (*)':'Tất cả tệp (*)', 'All files (*)':'Tất cả tệp (*)',
    'File name:':'Tên tệp:', 'Files of type:':'Loại tệp:', 'Look in:':'Tìm trong:',
    'Save in:':'Lưu tại:', 'File &name:':'Tên tệp:', 'File &type:':'Loại tệp:',
    'Name':'Tên', 'Size':'Kích thước', 'Type':'Loại', 'Date Modified':'Ngày sửa',
    'Date modified':'Ngày sửa', 'Computer':'Máy tính', 'My Computer':'Máy tính',
    'Directory':'Thư mục', 'Folder':'Thư mục', 'File':'Tệp',
    'Back':'Quay lại', 'Forward':'Tiến tới', 'Parent Directory':'Thư mục cha',
    'Create New Folder':'Tạo thư mục', 'List View':'Dạng danh sách', 'Detail View':'Dạng chi tiết',
    'Show hidden files':'Hiện tệp ẩn', '&Show hidden files':'Hiện tệp ẩn',
    'New Folder':'Thư mục mới', 'Rename':'Đổi tên', '&Rename':'Đổi tên',
    'Delete':'Xóa', '&Delete':'Xóa', 'Refresh':'Làm mới',
    'Undo':'Hoàn tác', '&Undo':'Hoàn tác', 'Redo':'Làm lại', '&Redo':'Làm lại',
    'Cut':'Cắt', 'Cu&t':'Cắt', 'Copy':'Sao chép', '&Copy':'Sao chép',
    'Paste':'Dán', '&Paste':'Dán', 'Select All':'Chọn tất cả', 'Select &All':'Chọn tất cả',
    'Show Details...':'Xem chi tiết…', 'Hide Details...':'Ẩn chi tiết…',
    'Confirm Save As':'Xác nhận lưu tệp', 'File not found':'Không tìm thấy tệp',
    '%1 already exists.\nDo you want to replace it?':'%1 đã tồn tại.\nBạn muốn thay thế tệp này?',
    '%1\nFile not found.\nPlease verify the correct file name was given.':'%1\nKhông tìm thấy tệp.\nHãy kiểm tra lại tên tệp.',
}


class Vietnamese(QTranslator):
    def translate(self, context, sourceText, disambiguation=None, n=-1):
        return TEXT.get(sourceText, '')


def install(app):
    app.vietnamese = Vietnamese(app)
    app.installTranslator(app.vietnamese)
