import json
import sqlite3
import threading
from pathlib import Path

import pytest
from openpyxl import load_workbook
from emailcheck.core import check_session, export_xlsx
from emailcheck.freefilters import flags, disposable_match, disposable_domains, screening, list_info, PASS, REVIEW, REMOVE, SYNTAX_OK
from emailcheck.store import Store, UNKNOWN
from tests.test_core import FakeDNS


@pytest.mark.parametrize('address,flag,suggestion',[
    ('a@mailinator.com','email tạm thời',''),
    ('a@sub.mailinator.com','email tạm thời',''),
    ('sales@example.com','Địa chỉ chức năng',''),
    ('Support+tag@example.com','Địa chỉ chức năng',''),
    ('a@gmial.com','nghi gõ sai','gmail.com'),
    ('a@gmail.com','',''),
    ('a@realmailinator.com','',''),
    ('a@mailinator.com.example.org','',''),
    ('a+sales@example.com','',''),
])
def test_local_flags_and_label_boundaries(address,flag,suggestion):
    risk,guess=flags(address)
    assert flag in risk
    if not flag:
        assert not risk
    assert guess==suggestion


def test_snapshot_is_available_and_does_not_mark_main_providers():
    assert len(disposable_domains())>1000
    assert 'nguồn cộng đồng' in list_info()
    for domain in ['gmail.com','googlemail.com','outlook.com','hotmail.com','yahoo.com','icloud.com']:
        assert not disposable_match(domain)


def test_real_free_screening_separates_results_without_api_or_mail(store,tmp_path,monkeypatch):
    # No HTTP service, Gmail credential, API key or vendor credit is involved.
    import requests
    monkeypatch.setattr(requests.Session,'request',lambda *a,**kw: pytest.fail('Free screening must not call HTTP services'))
    source=[['plain@example.com'],['person@mailinator.com'],['sales@example.com'],['name@gmial.com'],['plain@example.com'],['bad@@example.com'],['a@null-example.net'],['a@timeout-example.net']]
    sid=store.create_session(tmp_path/'source.xlsx','Sheet',['Email'],0,source)
    check_session(store,sid,threading.Event(),checker=FakeDNS())
    rows=store.rows(sid)
    assert [r['screening'] for r in rows]==[PASS,REVIEW,REVIEW,REVIEW,REMOVE,REMOVE,REMOVE,REVIEW]
    assert all(r['mailbox']==UNKNOWN for r in rows)
    assert all(r['send_state']=='Chưa gửi' for r in rows)
    assert rows[3]['normalized']=='name@gmial.com'
    assert rows[3]['suggestion']=='gmail.com'
    assert [json.loads(r['source']) for r in rows]==source
    assert Store(store.path).rows(sid)==rows
    dest=tmp_path/'result.xlsx'
    export_xlsx(store,sid,dest)
    wb=load_workbook(dest,read_only=True)
    assert wb['Kết quả đầy đủ'].max_row==9
    assert wb['Chưa xác định'].max_row==9
    assert wb['Nên loại'].max_row==4
    assert wb['Cần xem lại'].max_row==5
    assert wb['Qua lọc cơ bản'].max_row==2
    wb.close()


def test_legacy_database_migration_preserves_rows_and_settings(tmp_path):
    path=tmp_path/'old.sqlite3'
    s=Store(path)
    sid=s.create_session(tmp_path/'source.xlsx','Sheet',['Email'],0,[['person@example.com']])
    s.set('send_limit','12')
    with s.connect() as c:
        c.execute("UPDATE rows SET syntax='Hợp lệ',normalized='person@example.com' WHERE session_id=?",(sid,))
        # Simulate the v1.0 schema, which has no free-screening fields.
        for field in ['screening','risk','suggestion','screened']:
            c.execute('ALTER TABLE rows DROP COLUMN '+field)
    migrated=Store(path)
    row=migrated.rows(sid)[0]
    assert row['syntax']==SYNTAX_OK
    assert json.loads(row['source'])==['person@example.com']
    assert row['mailbox']==UNKNOWN
    assert migrated.get('send_limit')=='12'
    assert row['screening']==''


def test_partial_or_temporary_dns_never_looks_verified():
    row={'normalized':'person@example.com','syntax':SYNTAX_OK,'duplicate':'Không trùng','domain':'DNS quá thời gian','checked':'2026-11-01','mailbox':UNKNOWN}
    assert screening(row)['screening']==REVIEW
    row.update(domain='Có MX',checked='')
    assert screening(row)['screening']==REVIEW
