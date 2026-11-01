import json
import threading
import time
from types import SimpleNamespace
from pathlib import Path

import dns.resolver
import dns.exception
import pytest
from openpyxl import load_workbook

from emailcheck.core import normalize, DNSChecker, check_session, read_table, sheet_names, export_xlsx
from emailcheck.store import Store, UNKNOWN
from tools.make_sample import generate


class FakeDNS:
    def __init__(self):
        self.calls = []

    def check(self, domain):
        self.calls.append(domain)
        mapping = {
            'missing-example.net': ('Tên miền không tồn tại','NXDOMAIN','Tên miền không tồn tại'),
            'null-example.net': ('Không nhận thư (Null MX)','NULL_MX','Không nhận email'),
            'timeout-example.net': ('DNS quá thời gian','DNS_TIMEOUT','Lỗi tạm thời'),
            'implicit-example.net': ('Có A/AAAA thay MX','IMPLICIT_MX','Có địa chỉ dự phòng')}
        return mapping.get(domain, ('Có MX','MX_OK','Có MX; chưa biết hộp thư'))


def test_normalization():
    assert normalize('  Sample.Person+tag@GMAIL.com  ')[1] == 'sampleperson@gmail.com'
    assert normalize('sampleperson@googlemail.com')[1] == 'sampleperson@gmail.com'
    assert normalize('a.b@workspace-example.net')[1] != normalize('ab@workspace-example.net')[1]
    assert normalize('a+tag@workspace-example.net')[1] != normalize('a@workspace-example.net')[1]
    assert normalize('A@example.com')[1] != normalize('a@example.com')[1]
    assert normalize('x@bücher.de')[0].endswith('@xn--bcher-kva.de')
    for value in [None, '', 'a@@b.com', '=bad@example.com\nTo:x@example.com']:
        with pytest.raises(ValueError):
            normalize(value)


class Resolver:
    def __init__(self, mapping):
        self.mapping, self.calls = mapping, []

    def resolve(self, domain, kind):
        self.calls.append((domain, kind))
        value = self.mapping[kind]
        if isinstance(value, Exception):
            raise value
        class Answer(list):
            rrset = SimpleNamespace(ttl=600)
        return Answer(value)


@pytest.mark.parametrize('mapping,code', [
    ({'MX': [SimpleNamespace(exchange='mx.example.com.',preference=10)]}, 'MX_OK'),
    ({'MX': [SimpleNamespace(exchange='.',preference=0)]}, 'NULL_MX'),
    ({'MX': dns.resolver.NXDOMAIN()}, 'NXDOMAIN'),
    ({'MX': dns.exception.Timeout()}, 'DNS_TIMEOUT'),
    ({'MX': dns.resolver.NoNameservers()}, 'TEMP_ERROR'),
    ({'MX': dns.resolver.NoAnswer(), 'A':['127.0.0.1'], 'AAAA':dns.resolver.NoAnswer()}, 'IMPLICIT_MX'),
    ({'MX': dns.resolver.NoAnswer(), 'A':dns.resolver.NoAnswer(), 'AAAA':['::1']}, 'IMPLICIT_MX'),
    ({'MX': dns.resolver.NoAnswer(), 'A':dns.resolver.NoAnswer(), 'AAAA':dns.resolver.NoAnswer()}, 'NO_ADDRESS'),
    ({'MX': dns.resolver.NoAnswer(), 'A':dns.exception.Timeout(), 'AAAA':dns.resolver.NoAnswer()}, 'TEMP_ERROR'),
])
def test_dns_and_persistent_cache(store, mapping, code):
    resolver = Resolver(mapping)
    checker = DNSChecker(store, resolver)
    assert checker.check('example.com')[1] == code
    count = len(resolver.calls)
    assert DNSChecker(Store(store.path), resolver).check('example.com')[1] == code
    assert len(resolver.calls) == count
    with store.connect() as c:
        c.execute('UPDATE dns_cache SET expires=0')
    checker.check('example.com')
    assert len(resolver.calls) > count


def test_1000_import_check_export_restore(store, tmp_path):
    generate(tmp_path)
    source = tmp_path/'Du-lieu-gia-1000.xlsx'
    before = source.read_bytes()
    assert sheet_names(source) == ['Danh sách','Sheet khác']
    headers, rows = read_table(source, 'Danh sách')
    assert len(rows) == 1000
    csv_headers, csv_rows = read_table(tmp_path/'Du-lieu-gia-1000.csv','CSV')
    assert len(csv_rows) == 1000 and csv_headers == headers
    sid = store.create_session(source, 'Danh sách', headers, 2, rows)
    checker = FakeDNS()
    assert check_session(store, sid, threading.Event(), checker=checker)
    result = store.rows(sid)
    assert len(result) == 1000 and all(r['checked'] for r in result)
    assert all(r['mailbox'] == UNKNOWN and r['send_state']=='Chưa gửi' for r in result)
    assert len(checker.calls) == len(set(checker.calls)) == 7
    assert result[1]['duplicate'] == 'Trùng dòng 2'
    assert result[8]['duplicate'] == result[9]['duplicate'] == 'Không trùng'
    assert json.loads(result[0]['source']) == rows[0]
    restored = Store(store.path)
    assert restored.rows(sid) == result
    dest = tmp_path/'Ket-qua.xlsx'
    export_xlsx(restored,sid,dest)
    assert source.read_bytes() == before
    wb = load_workbook(dest, data_only=False)
    assert wb.sheetnames == ['Tổng hợp','Kết quả đầy đủ','Chưa xác định']
    ws = wb['Kết quả đầy đủ']
    assert ws.max_row == 1001 and ws.max_column == 13
    assert ws.freeze_panes == 'A2' and ws.auto_filter.ref == 'A1:M1001'
    assert ws['D2'].data_type == 's' and ws['D2'].value.startswith('=HYPERLINK')
    assert ws['D3'].data_type == 's' and ws['D3'].value == '+123'
    assert [ws.cell(i+2,1).value for i in range(1000)] == list(range(1,1001))
    assert wb['Chưa xác định'].max_row == 1001
    wb.close()
    with pytest.raises(ValueError):
        export_xlsx(store,sid,source)


def test_cancel_and_resume_1000(store,tmp_path):
    generate(tmp_path)
    h, rows = read_table(tmp_path/'Du-lieu-gia-1000.xlsx','Danh sách')
    sid = store.create_session(tmp_path/'source.xlsx','Danh sách',h,2,rows)
    event = threading.Event()
    def progress(a,b):
        if a > 50:
            event.set()
    assert not check_session(store,sid,event,progress,FakeDNS())
    assert store.session(sid)['state'] == 'cancelled'
    restored = Store(store.path)
    assert check_session(restored,sid,threading.Event(),checker=FakeDNS())
    assert all(r['checked'] for r in restored.rows(sid))


def test_import_cancel(store,tmp_path):
    generate(tmp_path)
    event = threading.Event()
    event.set()
    with pytest.raises(InterruptedError):
        read_table(tmp_path/'Du-lieu-gia-1000.xlsx','Danh sách',event)
