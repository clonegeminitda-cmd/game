"""Executable smoke test: actual GUI/import/export, synthetic DNS, no Gmail."""
import json
import os
import threading
import time
from pathlib import Path


def run(root):
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    os.environ['EMAILCHECK_DATA_DIR'] = str(root / 'user-data')
    from PySide6.QtWidgets import QApplication
    from openpyxl import Workbook, load_workbook
    from .store import Store
    from .core import check_session, export_xlsx
    from . import ui
    from .gmail import protect
    from .freefilters import PASS, REVIEW, REMOVE, list_info
    from . import __version__
    app = QApplication.instance() or QApplication([])
    report = {'ok':False,'version':__version__,'dns':'mock','gmail':'not connected; no real mail sent','paid_verification_api':'not integrated; no credits used'}
    window = None
    try:
        source = root/'Smoke-input-1000.xlsx'
        wb = Workbook()
        ws = wb.active
        ws.title='Danh sách'
        ws.append(['STT','Email','Ghi chú'])
        for i in range(1000):
            address = {1:'person@mailinator.com',2:'sales@example.com',3:'person@gmial.com',4:'user0@example.com'}.get(i,f'user{i}@example.com')
            ws.append([i+1,address,'Dữ liệu giả'])
        wb.save(source)
        wb.close()
        class SmokeDNS:
            def check(self,domain):
                return ('Có MX','MX_OK','DNS mô phỏng trong kiểm thử đóng gói')
        original = ui.check_session
        ui.check_session = lambda store,sid,cancel,progress: original(store,sid,cancel,progress,SmokeDNS())
        store = Store(root/'user-data'/'sessions.sqlite3')
        window = ui.MainWindow(store)
        window.show()
        app.processEvents()
        report['gui_visible']=window.isVisible()
        window.open_path(str(source))
        def wait(predicate,seconds=40):
            end=time.monotonic()+seconds
            while not predicate():
                app.processEvents()
                if time.monotonic()>end:
                    raise TimeoutError('Smoke test timed out')
                time.sleep(.01)
        wait(lambda: len(window.input_rows)==1000 and not window.busy())
        assert window.column.currentIndex()==1
        report['import_rows']=len(window.input_rows)
        window.start_check()
        wait(lambda: not window.busy() and window.model.rowCount()==1000)
        dest=root/'Smoke-output-1000.xlsx'
        export_xlsx(store,window.sid,dest)
        result=load_workbook(dest,read_only=True)
        report['export_rows']=result['Kết quả đầy đủ'].max_row-1
        assert report['export_rows']==1000
        assert len(result.sheetnames)==6
        assert result['Nên loại'].max_row==2
        assert result['Cần xem lại'].max_row==4
        assert result['Qua lọc cơ bản'].max_row==997
        report['free_filters']={'remove':1,'review':3,'basic_pass_not_mailbox_verification':996}
        report['disposable_snapshot']=list_info()
        assert window.model.headers[0]=='Sàng lọc miễn phí'
        result.close()
        store.recover()
        assert len(Store(store.path).rows(window.sid))==1000
        report['restore_rows']=1000
        assert store.jobs()==[]
        if os.name=='nt':
            encrypted=protect(b'smoke-test-token-only')
            assert b'smoke-test-token-only' not in encrypted
            assert protect(encrypted,True)==b'smoke-test-token-only'
            report['dpapi']='passed'
        report['ok']=True
    except Exception as exc:
        report['error_type']=type(exc).__name__
        report['error']=str(exc)
    finally:
        if window:
            window.close()
        (root/'smoke-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return 0 if report['ok'] else 1
