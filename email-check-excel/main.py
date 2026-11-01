import sys
from PySide6.QtCore import QLockFile, Qt
from PySide6.QtWidgets import QApplication, QMessageBox
from emailcheck.store import data_dir
from emailcheck.ui import MainWindow


def main():
    if len(sys.argv)==3 and sys.argv[1]=='--self-test':
        from emailcheck.selftest import run
        return run(sys.argv[2])
    QApplication.setAttribute(Qt.AA_DontUseNativeDialogs, True)
    app = QApplication(sys.argv)
    from emailcheck.language import install
    install(app)
    app.setApplicationName('Email Check Excel')
    app.setOrganizationName('EmailCheckExcel')
    lock = QLockFile(str(data_dir() / 'application.lock'))
    lock.setStaleLockTime(0)
    if not lock.tryLock(100):
        QMessageBox.information(None, 'Email Check Excel', 'Ứng dụng đã mở trong tài khoản Windows này. Hãy dùng cửa sổ hiện tại.')
        return 1
    window = MainWindow()
    window.show()
    return app.exec()


if __name__ == '__main__':
    sys.exit(main())
