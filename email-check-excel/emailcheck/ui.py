import json
import os
import threading
import time
from pathlib import Path

from PySide6.QtCore import Qt, QThread, Signal, QTimer, QAbstractTableModel, QModelIndex
from PySide6.QtGui import QColor, QFont
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QFileDialog, QComboBox, QTableView, QTabWidget, QProgressBar,
    QMessageBox, QDialog, QDialogButtonBox, QLineEdit, QPlainTextEdit,
    QCheckBox, QListWidget, QListWidgetItem, QSpinBox, QFormLayout, QGroupBox,
    QHeaderView, QSplitter, QAbstractItemView)

from .core import sheet_names, read_table, check_session, export_xlsx, RESULT_COLUMNS, RESULT_KEYS
from .store import Store, UNKNOWN, ABSENT, CONFIRMED, data_dir
from .gmail import Gmail, Outbox, draft, enqueue, monitor, reconcile_sent


class Worker(QThread):
    result = Signal(object)
    error = Signal(str)
    report = Signal(object)

    def __init__(self, task, parent=None):
        super().__init__(parent)
        self.task = task
        self.cancel = threading.Event()
        self.pause = threading.Event()

    def run(self):
        try:
            self.result.emit(self.task(self))
        except InterruptedError:
            self.report.emit('Đã hủy tác vụ.')
        except (ValueError, RuntimeError) as exc:
            self.error.emit(str(exc))
        except Exception as exc:
            # Never put OAuth tokens or Gmail raw response bodies into UI/logs.
            self.error.emit('Không hoàn tất tác vụ (' + type(exc).__name__ + '). Kiểm tra tệp, mạng hoặc kết nối Gmail rồi thử lại. Nhật ký gửi đã được giữ an toàn.')


class Table(QAbstractTableModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.headers, self.values, self.states = [], [], []

    def set_data(self, headers, values, states=None):
        self.beginResetModel()
        self.headers, self.values, self.states = headers, values, states or []
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.values)

    def columnCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.headers)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        if role in (Qt.DisplayRole, Qt.ToolTipRole):
            value = self.values[index.row()][index.column()]
            return '' if value is None else str(value)
        if role == Qt.BackgroundRole and self.states:
            state = self.states[index.row()]
            return QColor('#ffe7e7' if state == ABSENT else '#def5e6' if state == CONFIRMED else '#fff7df')

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if role == Qt.DisplayRole:
            if orientation == Qt.Horizontal:
                return str(self.headers[section] or f'Cột {section + 1}')
            return str(section + 1)


def button(text, function, layout):
    b = QPushButton(text)
    b.clicked.connect(function)
    layout.addWidget(b)
    return b


class SendDialog(QDialog):
    def __init__(self, store, rows, parent=None):
        super().__init__(parent)
        self.setWindowTitle('Chọn người nhận và xác nhận gửi')
        self.resize(900, 730)
        self.store, self.rows, self.drafts = store, rows, []
        layout = QVBoxLayout(self)
        note = QLabel('Chọn từng địa chỉ đã đồng ý hoặc đang mong đợi liên hệ. Mỗi thư chỉ có một người nhận.\nKhông mặc định chọn ai. Gửi thành công không chứng minh hộp thư tồn tại.')
        note.setWordWrap(True)
        layout.addWidget(note)
        self.list = QListWidget()
        existing = {j['dedup_key'] for j in store.jobs()}
        for row in rows:
            if row['syntax'] == 'Hợp lệ' and row['domain'] in ('Có MX','Có A/AAAA thay MX') and row['duplicate'] == 'Không trùng' and row['mailbox'] == UNKNOWN and row['dedup_key'] not in existing and row['normalized'].isascii():
                item = QListWidgetItem(f"Dòng {row['row_no']} · {row['normalized']}")
                item.setFlags(item.flags() | Qt.ItemIsUserCheckable)
                item.setCheckState(Qt.Unchecked)
                item.setData(Qt.UserRole, row)
                self.list.addItem(item)
        layout.addWidget(self.list, 2)
        self.count = QLabel('Đã chọn: 0 người nhận')
        layout.addWidget(self.count)
        self.subject = QLineEdit('Xác nhận địa chỉ liên hệ')
        self.body = QPlainTextEdit('Xin chào,\n\nChúng tôi liên hệ theo sự đồng ý hoặc đề nghị trước đó của bạn để xác nhận địa chỉ liên hệ. Nếu không mong đợi thư này, bạn có thể bỏ qua và thông báo cho người gửi để dừng liên hệ.\n\nCảm ơn bạn.')
        self.body.setMaximumHeight(120)
        form = QFormLayout()
        form.addRow('Tiêu đề:', self.subject)
        form.addRow('Nội dung:', self.body)
        layout.addLayout(form)
        self.preview = QPlainTextEdit()
        self.preview.setReadOnly(True)
        self.preview.setPlaceholderText('Bấm “Xem trước thư đã chọn” để xem nội dung đầy đủ, gồm dòng xác nhận riêng cho từng người.')
        layout.addWidget(self.preview, 2)
        self.consent = QCheckBox('Tôi xác nhận những người được chọn đã đồng ý nhận thư hoặc đang mong đợi liên hệ này.')
        layout.addWidget(self.consent)
        actions = QHBoxLayout()
        button('Xem trước thư đã chọn', self.make_preview, actions)
        self.confirm = button('Xác nhận — thêm vào hàng đợi', self.confirm_send, actions)
        self.confirm.setEnabled(False)
        button('Hủy', self.reject, actions)
        layout.addLayout(actions)
        self.list.itemChanged.connect(self.invalidate)
        self.subject.textChanged.connect(self.invalidate)
        self.body.textChanged.connect(self.invalidate)
        self.consent.toggled.connect(lambda: self.confirm.setEnabled(bool(self.drafts) and self.consent.isChecked()))

    def invalidate(self, *args):
        self.drafts = []
        self.preview.clear()
        self.confirm.setEnabled(False)
        count = sum(self.list.item(i).checkState() == Qt.Checked for i in range(self.list.count()))
        self.count.setText(f'Đã chọn: {count} người nhận')

    def make_preview(self):
        selected = [self.list.item(i).data(Qt.UserRole) for i in range(self.list.count()) if self.list.item(i).checkState() == Qt.Checked]
        if not selected or not self.subject.text().strip() or not self.body.toPlainText().strip():
            QMessageBox.information(self, 'Chưa đủ thông tin', 'Hãy chọn ít nhất một người nhận, nhập tiêu đề và nội dung.')
            return
        self.drafts = [draft(r, self.subject.text(), self.body.toPlainText()) for r in selected]
        self.preview.setPlainText('\n\n' + ('\n\n' + '─'*35 + '\n\n').join(f"Tới: {j['recipient']}\nTiêu đề: {j['subject']}\n\n{j['body']}" for j in self.drafts))
        self.confirm.setEnabled(self.consent.isChecked())

    def confirm_send(self):
        try:
            enqueue(self.store, self.drafts, self.consent.isChecked())
        except Exception as exc:
            QMessageBox.warning(self, 'Chưa tạo hàng đợi', str(exc))
            return
        self.accept()


OAUTH_HELP = '''KẾT NỐI GMAIL LẦN ĐẦU
1. Trong Google Cloud Console, tạo/chọn dự án của bạn và bật Gmail API.
2. Cấu hình Google Auth Platform / OAuth consent screen: tên ứng dụng, email hỗ trợ và đối tượng sử dụng. Nếu External đang ở Testing, thêm tài khoản Gmail của bạn vào Test users.
3. Tạo OAuth Client ID loại Desktop app (Ứng dụng dành cho máy tính), tải JSON. Không dùng Web application, không nhập mật khẩu Gmail.
4. Bấm “Nhập JSON OAuth Desktop”, sau đó “Kết nối Gmail”. Trình duyệt Google sẽ mở để bạn đăng nhập và đồng ý cấp quyền.

Ứng dụng xin gmail.send để gửi các thư bạn chọn và gmail.readonly để đọc thông báo lỗi/phản hồi, gồm nội dung và định danh thư cần đối chiếu. Không sửa, xóa thư hoặc quản lý tài khoản. Quyền đọc vẫn cho phép truy cập hộp thư: chỉ cấp cho ứng dụng bạn tin tưởng.

Ứng dụng External ở Testing có giới hạn test users và refresh token thường hết hạn sau 7 ngày khi dùng các quyền Gmail này. gmail.readonly là restricted scope; phát hành rộng có thể cần Google xác minh và các yêu cầu bổ sung tùy cách sử dụng. Chính sách/hạn mức Gmail thay đổi theo tài khoản. Giới hạn do app đặt không bảo đảm tránh spam và không bảo đảm gửi 1.000 thư trong một ngày.

Token chỉ lưu bằng Windows DPAPI, gắn với tài khoản Windows hiện tại. Không sao chép token sang máy khác. “Ngắt kết nối” xóa token cục bộ; bạn có thể thu hồi quyền trong Tài khoản Google > Bảo mật > Kết nối với ứng dụng bên thứ ba.

Theo dõi mặc định 48 giờ, cập nhật khoảng 5 phút khi app đang mở và Gmail đã kết nối. Đóng app sẽ tạm dừng; mở lại có thể cập nhật từ mốc đã lưu. Nút “Cập nhật cả thư quá 48 giờ” cho phép kiểm tra muộn hơn. Không có phản hồi vẫn là Chưa xác định. Phản hồi xác nhận dựa vào địa chỉ From, tham chiếu thư và dòng xác nhận riêng; không phải xác thực danh tính pháp lý và không chống được mọi trường hợp giả mạo email.

Dữ liệu nguồn, nội dung thư và nhật ký SQLite lưu trong thư mục dữ liệu người dùng. Hãy bảo vệ tài khoản Windows và sao lưu thư mục đó nếu cần. Không có dịch vụ máy chủ hay pixel theo dõi mở thư.
'''


class MainWindow(QMainWindow):
    def __init__(self, store=None):
        super().__init__()
        self.store = store or Store()
        self.store.recover()
        self.sid = None
        self.source = ''
        self.input_headers, self.input_rows = [], []
        self.worker = None
        self.workers = []
        self.connected = False
        self.queue_running = False
        self.started = 0
        self.setWindowTitle('Email Check Excel')
        self.resize(1240, 820)
        self.setMinimumSize(880, 620)
        root = QWidget()
        self.setCentralWidget(root)
        layout = QVBoxLayout(root)
        title = QLabel('Email Check Excel')
        title.setObjectName('title')
        layout.addWidget(title)
        tagline = QLabel('Kiểm tra danh sách email · Giữ nguyên dữ liệu · Gửi thử khi bạn chủ động chọn')
        layout.addWidget(tagline)
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs, 1)
        self.build_data_tab()
        self.build_gmail_tab()
        self.build_queue_tab()
        footer = QHBoxLayout()
        self.status = QLabel('Sẵn sàng. Chọn tệp Excel hoặc CSV để bắt đầu.')
        self.status.setWordWrap(True)
        footer.addWidget(self.status, 1)
        self.elapsed = QLabel('0 giây')
        footer.addWidget(self.elapsed)
        self.cancel_btn = button('Hủy tác vụ', self.cancel_task, footer)
        self.cancel_btn.setEnabled(False)
        layout.addLayout(footer)
        self.progress = QProgressBar()
        self.progress.setValue(0)
        layout.addWidget(self.progress)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.tick)
        self.timer.start(1000)
        self.monitor_timer = QTimer(self)
        self.monitor_timer.timeout.connect(self.auto_monitor)
        self.monitor_timer.start(300000)
        self.refresh_sessions()
        self.refresh_queue()
        if Gmail().token.exists():
            QTimer.singleShot(150, self.restore_gmail)
        self.setStyleSheet('''
          QMainWindow { background: #f4f7fb; }
          QWidget { font-family: "Segoe UI"; font-size: 10pt; color:#17324d; }
          QLabel#title { font-size:23pt; font-weight:700; padding-top:8px; }
          QPushButton { background:#e5edf5; border:1px solid #c4d2e1; border-radius:5px; padding:8px 13px; }
          QPushButton:hover { background:#d3e3f3; }
          QPushButton:disabled { color:#7e8b97; background:#edf0f4; }
          QPushButton#primary { color:white; background:#136c67; font-weight:600; }
          QLineEdit,QComboBox,QSpinBox { padding:5px; background:white; }
          QTableView { background:white; gridline-color:#e3e9ef; }
          QHeaderView::section { background:#dfeaf3; padding:7px; border:0; font-weight:600; }
          QTabBar::tab { padding:10px 18px; }
          QProgressBar { border:1px solid #d5dfe8; border-radius:3px; text-align:center; }
          QProgressBar::chunk { background:#278c81; }
        ''')

    def table_view(self, layout):
        view = QTableView()
        model = Table(view)
        view.setModel(model)
        view.setEditTriggers(QAbstractItemView.NoEditTriggers)
        view.setAlternatingRowColors(False)
        view.horizontalHeader().setSectionResizeMode(QHeaderView.Interactive)
        view.horizontalHeader().setDefaultSectionSize(200)
        layout.addWidget(view, 1)
        return view, model

    def build_data_tab(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        row = QHBoxLayout()
        self.open_btn = button('1. Chọn Excel / CSV', self.choose_file, row)
        self.file_label = QLabel('Chưa chọn tệp')
        row.addWidget(self.file_label, 1)
        layout.addLayout(row)
        row = QHBoxLayout()
        row.addWidget(QLabel('Sheet:'))
        self.sheet = QComboBox()
        self.sheet.currentIndexChanged.connect(self.load_sheet)
        row.addWidget(self.sheet)
        row.addWidget(QLabel('Cột email:'))
        self.column = QComboBox()
        self.column.currentIndexChanged.connect(self.reset_selection)
        row.addWidget(self.column, 1)
        self.check_btn = button('2. Kiểm tra', self.start_check, row)
        self.check_btn.setObjectName('primary')
        self.check_btn.setEnabled(False)
        layout.addLayout(row)
        row = QHBoxLayout()
        row.addWidget(QLabel('Phiên đã lưu:'))
        self.sessions_combo = QComboBox()
        row.addWidget(self.sessions_combo, 1)
        self.restore_btn = button('Khôi phục phiên', self.restore, row)
        layout.addLayout(row)
        self.counts = QLabel('Dòng 1 được dùng làm tiêu đề. Chưa có dữ liệu.')
        layout.addWidget(self.counts)
        self.view, self.model = self.table_view(layout)
        row = QHBoxLayout()
        row.addWidget(QLabel('Hiển thị:'))
        self.filter = QComboBox()
        self.filter.addItems(['Tất cả', 'Chưa xác định', 'Cú pháp không hợp lệ', 'Trùng lặp', 'Máy chủ báo không tồn tại', 'Đã có phản hồi xác nhận'])
        self.filter.currentIndexChanged.connect(self.render)
        row.addWidget(self.filter)
        row.addWidget(QLabel('Trang (1.000 dòng):'))
        self.page_no = QSpinBox()
        self.page_no.setRange(1, 1)
        self.page_no.valueChanged.connect(self.render)
        row.addWidget(self.page_no)
        row.addStretch()
        layout.addLayout(row)
        row = QHBoxLayout()
        self.export_btn = button('Không gửi — xuất kết quả', self.export, row)
        self.export_btn.setEnabled(False)
        self.select_btn = button('Chọn địa chỉ để gửi thử', self.select_recipients, row)
        self.select_btn.setEnabled(False)
        row.addStretch()
        layout.addLayout(row)
        note = QLabel('Cú pháp, DNS hợp lệ hoặc gửi thành công không chứng minh hộp thư tồn tại. Không gửi thư khi nhập hay kiểm tra tệp.')
        note.setWordWrap(True)
        layout.addWidget(note)
        self.tabs.addTab(page, 'Danh sách và kết quả')

    def build_gmail_tab(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        self.gmail_status = QLabel('Chưa kết nối. Chức năng kiểm tra và xuất Excel vẫn sử dụng được ngay.')
        layout.addWidget(self.gmail_status)
        row = QHBoxLayout()
        self.config_btn = button('Nhập JSON OAuth Desktop', self.import_oauth, row)
        self.connect_btn = button('Kết nối Gmail', self.connect_gmail, row)
        self.saved_btn = button('Dùng kết nối đã lưu', self.restore_gmail, row)
        self.disconnect_btn = button('Ngắt kết nối', self.disconnect_gmail, row)
        row.addStretch()
        layout.addLayout(row)
        help_view = QPlainTextEdit(OAUTH_HELP)
        help_view.setReadOnly(True)
        layout.addWidget(help_view, 1)
        self.tabs.addTab(page, 'Kết nối Gmail')

    def build_queue_tab(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        row = QHBoxLayout()
        row.addWidget(QLabel('Giới hạn lần thử gửi / 24 giờ:'))
        self.send_limit = QSpinBox()
        self.send_limit.setRange(1, 500)
        self.send_limit.setValue(int(self.store.get('send_limit', '50')))
        self.send_limit.valueChanged.connect(lambda value: self.store.set('send_limit', value))
        row.addWidget(self.send_limit)
        row.addWidget(QLabel('Khoảng cách tối thiểu (giây):'))
        self.interval = QSpinBox()
        self.interval.setRange(6, 3600)
        self.interval.setValue(int(self.store.get('send_interval', '30')))
        self.interval.valueChanged.connect(lambda value: self.store.set('send_interval', value))
        row.addWidget(self.interval)
        row.addStretch()
        layout.addLayout(row)
        note = QLabel('Giới hạn của app không bảo đảm tránh spam. Gmail có hạn mức riêng. Sau khi mở lại app, hàng đợi chỉ gửi khi bạn bấm tiếp tục.')
        note.setWordWrap(True)
        layout.addWidget(note)
        self.queue_view, self.queue_model = self.table_view(layout)
        row = QHBoxLayout()
        self.send_btn = button('Bắt đầu / tiếp tục gửi', self.start_queue, row)
        self.pause_btn = button('Tạm dừng', self.pause_queue, row)
        self.pause_btn.setEnabled(False)
        self.cancel_queue_btn = button('Hủy các thư chưa gửi', self.cancel_queue, row)
        self.monitor_btn = button('Cập nhật phản hồi (48 giờ)', lambda: self.start_monitor(False), row)
        layout.addLayout(row)
        row = QHBoxLayout()
        self.late_btn = button('Cập nhật cả thư quá 48 giờ', lambda: self.start_monitor(True), row)
        self.reconcile_btn = button('Đối soát thư chưa rõ trạng thái', self.reconcile, row)
        row.addStretch()
        layout.addLayout(row)
        self.log = QPlainTextEdit()
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(300)
        self.log.setMaximumHeight(130)
        layout.addWidget(self.log)
        self.tabs.addTab(page, 'Hàng đợi và phản hồi')

    def message(self, text):
        if isinstance(text, tuple):
            done, total = text
            self.progress.setRange(0, max(1, total))
            self.progress.setValue(done)
            self.status.setText(f'Đã kiểm tra {done:,} / {total:,} dòng')
        else:
            self.status.setText(str(text))
            self.log.appendPlainText(str(text))

    def busy(self):
        return bool(self.worker and self.worker.isRunning())

    def task(self, function, callback=None, name='Đang xử lý…'):
        if self.busy():
            QMessageBox.information(self, 'Đang xử lý', 'Hãy chờ hoặc hủy tác vụ hiện tại trước.')
            return False
        worker = Worker(function, self)
        self.worker = worker
        self.workers.append(worker)
        self.started = time.monotonic()
        self.message(name)
        self.progress.setRange(0, 0)
        self.set_busy(True)
        worker.report.connect(self.message)
        if callback:
            worker.result.connect(callback)
        worker.error.connect(lambda text: QMessageBox.warning(self, 'Không hoàn tất tác vụ', text))
        worker.finished.connect(lambda: self.task_finished(worker))
        worker.start()
        return True

    def set_busy(self, value):
        for control in [self.open_btn,self.sheet,self.column,self.restore_btn,self.check_btn,self.config_btn,self.connect_btn,self.saved_btn,self.disconnect_btn,self.select_btn,self.send_btn,self.monitor_btn,self.late_btn,self.reconcile_btn,self.send_limit,self.interval]:
            control.setEnabled(not value)
        self.cancel_btn.setEnabled(value)
        if not value:
            self.check_btn.setEnabled(bool(self.input_headers or self.sid))
            self.column.setEnabled(bool(self.input_headers))
            self.select_btn.setEnabled(bool(self.sid) and self.connected)
            for control in [self.send_btn,self.monitor_btn,self.late_btn,self.reconcile_btn]:
                control.setEnabled(self.connected)

    def task_finished(self, worker):
        if self.worker is worker:
            self.queue_running = False
            self.worker = None
            self.set_busy(False)
            self.progress.setRange(0, 100)
            self.progress.setValue(100 if not worker.cancel.is_set() else 0)
            self.pause_btn.setEnabled(False)
            self.pause_btn.setText('Tạm dừng')
            self.render()
            self.refresh_queue()
            self.refresh_sessions()
        self.workers.remove(worker)
        worker.deleteLater()

    def tick(self):
        if self.busy():
            self.elapsed.setText(f'{int(time.monotonic() - self.started)} giây')

    def cancel_task(self):
        if self.worker:
            self.worker.cancel.set()
            self.message('Đang hủy… yêu cầu mạng đang chạy sẽ kết thúc theo thời gian chờ.')

    def choose_file(self):
        path, _ = QFileDialog.getOpenFileName(self, 'Chọn tệp dữ liệu', '', 'Excel và CSV (*.xlsx *.csv)')
        if path:
            self.open_path(path)

    def open_path(self, path):
        self.source = path
        self.file_label.setText(Path(path).name)
        def loaded(names):
            self.sheet.blockSignals(True)
            self.sheet.clear()
            self.sheet.addItems(names)
            self.sheet.blockSignals(False)
            # Start after the sheet-name worker has completely finished.
            QTimer.singleShot(50, self.load_sheet)
        self.task(lambda w: sheet_names(path), loaded, 'Đang đọc danh sách sheet…')

    def load_sheet(self, *args):
        if not self.source or not self.sheet.currentText():
            return
        source, sheet = self.source, self.sheet.currentText()
        def loaded(result):
            self.sid = None
            self.input_headers, self.input_rows = result
            self.column.blockSignals(True)
            self.column.clear()
            self.column.addItems([f'{i+1}. {h if h is not None else "(không có tiêu đề)"}' for i, h in enumerate(self.input_headers)])
            best = next((i for i, h in enumerate(self.input_headers) if 'email' in str(h).lower() or 'e-mail' in str(h).lower()), 0)
            self.column.setCurrentIndex(best)
            self.column.blockSignals(False)
            self.model.set_data(self.input_headers, self.input_rows[:50])
            self.counts.setText(f'{len(self.input_rows):,} dòng · Xem trước 50 dòng đầu · Dòng 1 là tiêu đề. Chọn cột email rồi bấm Kiểm tra.')
            self.export_btn.setEnabled(False)
            self.message('Đã nhập dữ liệu. Chưa gửi thư nào.')
        self.task(lambda w: read_table(source, sheet, w.cancel), loaded, 'Đang nhập dữ liệu…')

    def reset_selection(self, *args):
        if self.input_headers:
            self.sid = None
            self.export_btn.setEnabled(False)
            self.select_btn.setEnabled(False)
            self.model.set_data(self.input_headers, self.input_rows[:50])

    def start_check(self):
        if not self.sid:
            if not self.input_headers or self.column.currentIndex() < 0:
                return
            self.sid = self.store.create_session(self.source, self.sheet.currentText(), self.input_headers, self.column.currentIndex(), self.input_rows)
        else:
            # Completed sessions can be checked again to refresh transient DNS.
            with self.store.connect() as c:
                c.execute("UPDATE rows SET checked='' WHERE session_id=? AND error IN ('DNS_TIMEOUT','TEMP_ERROR','BAD_MX')", (self.sid,))
        sid = self.sid
        self.export_btn.setEnabled(True)
        self.task(lambda w: check_session(self.store, sid, w.cancel, lambda a,b: w.report.emit((a,b))),
                  lambda ok: self.message('Đã kiểm tra xong. Bạn có thể xuất kết quả hoặc chủ động chọn địa chỉ gửi thử.' if ok else 'Đã hủy. Kết quả đã xử lý được giữ lại; bấm Kiểm tra để tiếp tục.'), 'Đang kiểm tra cú pháp và DNS…')

    def refresh_sessions(self):
        current = self.sessions_combo.currentData()
        self.sessions_combo.clear()
        for s in self.store.sessions():
            self.sessions_combo.addItem(f"#{s['id']} · {Path(s['source']).name} · {s['sheet']} · {s['created']}", s['id'])
        if current:
            self.sessions_combo.setCurrentIndex(max(0, self.sessions_combo.findData(current)))

    def restore(self):
        sid = self.sessions_combo.currentData()
        if not sid:
            return
        self.sid = sid
        s = self.store.session(sid)
        self.source = s['source']
        self.input_headers, self.input_rows = [], []
        self.sheet.blockSignals(True)
        self.sheet.clear()
        self.sheet.addItem(s['sheet'])
        self.sheet.blockSignals(False)
        self.column.blockSignals(True)
        self.column.clear()
        self.column.addItems([str(h or f'Cột {i+1}') for i,h in enumerate(s['headers'])])
        self.column.setCurrentIndex(s['email_col'])
        self.column.blockSignals(False)
        self.column.setEnabled(False)
        self.file_label.setText(Path(self.source).name)
        self.export_btn.setEnabled(True)
        self.check_btn.setEnabled(True)
        self.select_btn.setEnabled(self.connected)
        self.render()
        self.message('Đã khôi phục phiên từ SQLite. Hàng đợi không tự gửi; thư chưa rõ trạng thái cần đối soát.')

    def render(self, *args):
        if not self.sid:
            return
        rows = self.store.rows(self.sid)
        mode = self.filter.currentIndex()
        conditions = [lambda r: True, lambda r:r['mailbox']==UNKNOWN, lambda r:r['syntax']=='Không hợp lệ', lambda r:r['duplicate'].startswith('Trùng'), lambda r:r['mailbox']==ABSENT, lambda r:r['mailbox']==CONFIRMED]
        filtered = [r for r in rows if conditions[mode](r)]
        self.page_no.blockSignals(True)
        self.page_no.setMaximum(max(1, (len(filtered)+999)//1000))
        self.page_no.blockSignals(False)
        start = (self.page_no.value()-1)*1000
        group = filtered[start:start+1000]
        values = [json.loads(r['source'])+[r[k] for k in RESULT_KEYS] for r in group]
        self.model.set_data(self.store.session(self.sid)['headers']+RESULT_COLUMNS, values, [r['mailbox'] for r in group])
        checked = sum(bool(r['checked']) for r in rows)
        duplicates = sum(r['duplicate'].startswith('Trùng') for r in rows)
        unknown = sum(r['mailbox']==UNKNOWN for r in rows)
        self.counts.setText(f'{len(rows):,} dòng · Đã kiểm tra {checked:,} · Trùng {duplicates:,} · Chưa xác định {unknown:,} · Bộ lọc {len(filtered):,} dòng')

    def export(self):
        if not self.sid:
            return
        path, _ = QFileDialog.getSaveFileName(self, 'Xuất kết quả — không ghi đè nguồn', 'Ket-qua-email.xlsx', 'Excel (*.xlsx)')
        if not path:
            return
        if not path.lower().endswith('.xlsx'):
            path += '.xlsx'
        sid = self.sid
        # Export is independent and may run while validation is in progress.
        worker = Worker(lambda w: export_xlsx(self.store, sid, path), self)
        self.workers.append(worker)
        worker.result.connect(lambda p: QMessageBox.information(self, 'Đã xuất kết quả', 'Tệp kết quả đã lưu:\n'+p))
        worker.error.connect(lambda t: QMessageBox.warning(self, 'Không xuất được', t))
        worker.finished.connect(lambda: (self.workers.remove(worker), worker.deleteLater()))
        worker.start()

    def import_oauth(self):
        path, _ = QFileDialog.getOpenFileName(self, 'Chọn JSON OAuth Desktop', '', 'JSON (*.json)')
        if not path:
            return
        try:
            Gmail().configure(path)
            self.message('Đã nhập cấu hình OAuth Desktop. Bấm Kết nối Gmail để đăng nhập trên trình duyệt.')
        except Exception:
            QMessageBox.warning(self, 'Cấu hình không hợp lệ', 'Cần JSON OAuth Desktop chính thức của Google. Xem hướng dẫn trong tab này.')

    def connect_gmail(self):
        self.task(lambda w: Gmail().connect(interactive=True), self.gmail_connected, 'Đang chờ bạn hoàn tất đăng nhập Google trên trình duyệt (tối đa 3 phút)…')

    def restore_gmail(self):
        if self.busy():
            return
        self.task(lambda w: Gmail().connect(), self.gmail_connected, 'Đang khôi phục kết nối Gmail đã lưu an toàn…')

    def gmail_connected(self, account):
        self.connected = True
        self.gmail_status.setText('Đã kết nối Gmail: '+account+' · Token được bảo vệ bằng Windows DPAPI.')
        self.message('Kết nối Gmail thành công. Chưa gửi thư; hãy chủ động chọn người nhận và xác nhận.')
        QTimer.singleShot(150, self.auto_monitor)

    def disconnect_gmail(self):
        Gmail().token.unlink(missing_ok=True)
        self.connected = False
        self.gmail_status.setText('Đã xóa token trên máy. Có thể thu hồi quyền ứng dụng trong phần Bảo mật của Tài khoản Google.')
        self.set_busy(False)

    def select_recipients(self):
        if not self.sid or not self.connected:
            self.tabs.setCurrentIndex(1)
            return
        dialog = SendDialog(self.store, self.store.rows(self.sid), self)
        if dialog.exec() == QDialog.Accepted:
            self.refresh_queue()
            self.render()
            self.tabs.setCurrentIndex(2)
            self.message('Đã lưu hàng đợi có xác nhận. Bấm Bắt đầu / tiếp tục gửi để xử lý.')

    def refresh_queue(self):
        labels = {'queued':'Chờ gửi','sending':'Đang gửi','sent':'Đã gửi; chưa xác nhận hộp thư','failed':'Gửi lỗi','reconcile':'Cần đối soát','cancelled':'Đã hủy'}
        jobs = self.store.jobs()
        self.queue_model.set_data(['Người nhận','Trạng thái gửi','Tiêu đề','Thời điểm thử gửi (UTC)','Lỗi / ghi chú'], [[j['recipient'],labels.get(j['state'],j['state']),j['subject'],j['sent_at'] or '',j['error']] for j in jobs])
        self.set_busy(self.busy())

    def start_queue(self):
        if self.busy() and self.worker.pause.is_set():
            self.worker.pause.clear()
            self.pause_btn.setText('Tạm dừng')
            return
        if not self.connected or self.busy():
            return
        halt = self.store.get('queue_halt')
        if halt:
            answer = QMessageBox.question(self, 'Hàng đợi đang dừng', halt+'\n\nBạn đã kiểm tra nguyên nhân và muốn tiếp tục các thư chưa gửi? Thư lỗi hoặc cần đối soát sẽ không được gửi lại.', QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
            if answer != QMessageBox.Yes:
                return
            self.store.set('queue_halt', '')
        limit, interval = self.send_limit.value(), self.interval.value()
        def run(w):
            gmail = Gmail()
            gmail.connect()
            Outbox(self.store, gmail).run(w.cancel, w.pause, w.report.emit, limit, interval)
        if self.task(run, name='Đang xử lý hàng đợi đã được xác nhận…'):
            self.queue_running = True
            self.pause_btn.setEnabled(True)

    def pause_queue(self):
        if not self.worker:
            return
        if self.worker.pause.is_set():
            self.worker.pause.clear()
            self.pause_btn.setText('Tạm dừng')
            self.message('Đã tiếp tục hàng đợi.')
        else:
            self.worker.pause.set()
            self.pause_btn.setText('Tiếp tục')
            self.message('Đã yêu cầu tạm dừng. Thư đang gửi có thể đã được máy chủ chấp nhận.')

    def cancel_queue(self):
        if self.worker and self.queue_running:
            self.worker.cancel.set()
        Outbox(self.store, None).cancel_pending()
        self.refresh_queue()
        self.render()
        self.message('Đã hủy các thư chưa gửi. Không hủy được thư máy chủ đã nhận.')

    def start_monitor(self, include_expired=False, silent=False):
        if not self.connected or self.busy():
            return
        def run(w):
            gmail = Gmail()
            gmail.connect()
            return monitor(self.store, gmail, w.cancel, w.report.emit, include_expired)
        self.task(run, name='Đang đọc thư báo lỗi và phản hồi tương ứng…')

    def auto_monitor(self):
        if self.connected and not self.busy() and self.store.jobs(['sent','reconcile']):
            self.start_monitor(silent=True)

    def reconcile(self):
        if not self.connected:
            return
        def run(w):
            gmail = Gmail()
            gmail.connect()
            return reconcile_sent(self.store, gmail, w.cancel, w.report.emit)
        self.task(run, name='Đang đối soát định danh thư trong Thư đã gửi…')

    def closeEvent(self, event):
        running = [w for w in self.workers if w.isRunning()]
        if running:
            for w in running:
                w.cancel.set()
            self.message('Đang dừng tác vụ để đóng an toàn. Hãy chờ tác vụ mạng hoàn tất rồi đóng lại.')
            event.ignore()
        else:
            event.accept()
