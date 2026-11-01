import threading
from pathlib import Path
from PySide6.QtCore import Qt
from emailcheck.ui import MainWindow, SendDialog
from emailcheck.core import check_session
from tests.test_core import FakeDNS
from tools.make_sample import generate


def test_vietnamese_standard_controls_keep_unknown_labels(qapp):
    from PySide6.QtCore import QCoreApplication
    from emailcheck.language import Vietnamese
    translator=Vietnamese(qapp)
    qapp.installTranslator(translator)
    try:
        assert QCoreApplication.translate('QDialogButtonBox','Cancel')=='Hủy'
        assert QCoreApplication.translate('UntranslatedContext','Visible label')=='Visible label'
    finally:
        qapp.removeTranslator(translator)


def test_gui_import_check_restore_preview_no_recipients_selected(qtbot,store,tmp_path,monkeypatch):
    generate(tmp_path)
    window = MainWindow(store)
    qtbot.addWidget(window)
    window.show()
    assert window.windowTitle() == 'Email Check Excel'
    assert not window.select_btn.isEnabled()
    window.open_path(str(tmp_path/'Du-lieu-gia-1000.xlsx'))
    qtbot.waitUntil(lambda: len(window.input_rows)==1000 and not window.busy(),timeout=10000)
    assert window.model.rowCount()==50
    assert window.column.currentIndex()==2
    def mocked(store,sid,cancel,progress):
        return check_session(store,sid,cancel,progress,FakeDNS())
    monkeypatch.setattr('emailcheck.ui.check_session',mocked)
    window.start_check()
    qtbot.waitUntil(lambda: not window.busy() and window.model.rowCount()==1000,timeout=15000)
    sid=window.sid
    assert window.model.rowCount()==1000
    assert window.export_btn.isEnabled()
    assert store.jobs()==[]
    dialog=SendDialog(store,store.rows(sid),window)
    qtbot.addWidget(dialog)
    assert dialog.list.count()>0
    assert all(dialog.list.item(i).checkState()==Qt.Unchecked for i in range(dialog.list.count()))
    assert not dialog.confirm.isEnabled()
    dialog.list.item(0).setCheckState(Qt.Checked)
    dialog.make_preview()
    assert 'Tôi xác nhận ECE-' in dialog.preview.toPlainText()
    assert not dialog.confirm.isEnabled()
    dialog.consent.setChecked(True)
    assert dialog.confirm.isEnabled()
    dialog.subject.setText('Tiêu đề đã thay đổi')
    assert not dialog.confirm.isEnabled() and not dialog.drafts
    dialog.reject()
    window.refresh_sessions()
    window.sid=None
    window.restore()
    assert window.sid==sid and window.model.rowCount()==1000
    assert store.jobs()==[]
    window.close()
