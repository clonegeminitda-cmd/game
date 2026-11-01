import csv
import json
import time
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import dns.exception
import dns.resolver
from email_validator import validate_email, EmailNotValidError
from openpyxl import Workbook, load_workbook
from openpyxl.styles import PatternFill, Font
from openpyxl.utils import get_column_letter

from .store import UNKNOWN, ABSENT, CONFIRMED, now


def sheet_names(path):
    if Path(path).suffix.lower() == '.csv':
        return ['CSV']
    wb = load_workbook(path, read_only=True, data_only=False)
    try:
        return wb.sheetnames
    finally:
        wb.close()


def read_table(path, sheet, cancel=None):
    """First row is the header. Preserve empty rows and source cell values."""
    wb = None
    handle = None
    try:
        if Path(path).suffix.lower() == '.csv':
            try:
                handle = open(path, encoding='utf-8-sig', newline='')
                sample = handle.read(8192)
            except UnicodeDecodeError:
                if handle:
                    handle.close()
                handle = open(path, encoding='cp1258', newline='')
                sample = handle.read(8192)
            handle.seek(0)
            try:
                dialect = csv.Sniffer().sniff(sample, delimiters=',;\t|')
            except csv.Error:
                dialect = csv.excel
            iterator = iter(csv.reader(handle, dialect))
        else:
            wb = load_workbook(path, read_only=True, data_only=False)
            iterator = iter(wb[sheet].iter_rows(values_only=True))
        headers = list(next(iterator, []))
        data = []
        for row in iterator:
            if cancel and cancel.is_set():
                raise InterruptedError('Đã hủy nhập tệp')
            if len(data) >= 100000:
                raise ValueError('Tệp vượt 100.000 dòng. Hãy tách tệp; ứng dụng không cắt bỏ dữ liệu âm thầm.')
            if len(row) > 1000:
                raise ValueError('Tệp vượt 1.000 cột.')
            data.append(list(row))
        width = max([len(headers)] + [len(r) for r in data])
        headers += [None] * (width - len(headers))
        data = [r + [None] * (width - len(r)) for r in data]
        if not width:
            raise ValueError('Tệp không có cột dữ liệu.')
        return headers, data
    finally:
        if wb:
            wb.close()
        if handle:
            handle.close()


def normalize(value):
    if value is None:
        raise ValueError('Ô email trống')
    raw = str(value).strip()
    try:
        result = validate_email(raw, check_deliverability=False)
    except EmailNotValidError:
        raise ValueError('Địa chỉ không đúng cú pháp email; không tự sửa địa chỉ') from None
    address = result.normalized
    local, domain = address.rsplit('@', 1)
    domain = result.ascii_domain.lower()
    address = local + '@' + domain
    if domain in ('gmail.com', 'googlemail.com'):
        key = local.lower().split('+', 1)[0].replace('.', '') + '@gmail.com'
    else:
        # Local parts at arbitrary providers can be case sensitive.
        key = address
    return address, key, domain


class DNSChecker:
    def __init__(self, store, resolver=None):
        self.store = store
        self.resolver = resolver or dns.resolver.Resolver()
        self.resolver.timeout = 2
        self.resolver.lifetime = 4
        self.lock = threading.Lock()

    def check(self, domain):
        with self.store.connect() as c:
            row = c.execute('SELECT result FROM dns_cache WHERE domain=? AND expires>?', (domain, time.time())).fetchone()
        if row:
            return json.loads(row[0])
        ttl = 300
        try:
            try:
                mx = self.resolver.resolve(domain, 'MX')
                ttl = min(86400, max(1, mx.rrset.ttl))
                records = list(mx)
                if len(records) == 1 and str(records[0].exchange) == '.' and records[0].preference == 0:
                    result = ('Không nhận thư (Null MX)', 'NULL_MX', 'Tên miền công bố không nhận email')
                elif any(str(r.exchange) == '.' for r in records):
                    result = ('Lỗi DNS tạm thời', 'BAD_MX', 'Bản ghi MX chứa Null MX không hợp lệ')
                    ttl = 60
                else:
                    result = ('Có MX', 'MX_OK', 'DNS có MX; chưa chứng minh hộp thư tồn tại')
            except dns.resolver.NoAnswer:
                # RFC 5321 implicit MX: use A or AAAA of the domain itself.
                found, temporary, ttls = False, False, []
                for kind in ('A', 'AAAA'):
                    try:
                        answer = self.resolver.resolve(domain, kind)
                        if list(answer):
                            found = True
                            ttls.append(answer.rrset.ttl)
                    except dns.resolver.NoAnswer:
                        pass
                    except (dns.resolver.NoNameservers, dns.exception.Timeout):
                        temporary = True
                if found:
                    ttl = min(86400, max(1, min(ttls)))
                    result = ('Có A/AAAA thay MX', 'IMPLICIT_MX', 'Không có MX; có địa chỉ A/AAAA theo RFC 5321')
                elif temporary:
                    ttl = 60
                    result = ('Lỗi DNS tạm thời', 'TEMP_ERROR', 'Chưa xác định được A/AAAA dự phòng')
                else:
                    result = ('Không có MX/A/AAAA', 'NO_ADDRESS', 'Tên miền không có tuyến nhận thư')
        except dns.resolver.NXDOMAIN:
            result = ('Tên miền không tồn tại', 'NXDOMAIN', 'DNS trả về NXDOMAIN; trạng thái hộp thư vẫn chưa xác định')
        except dns.exception.Timeout:
            ttl = 60
            result = ('DNS quá thời gian', 'DNS_TIMEOUT', 'Có thể thử lại; không kết luận hộp thư không tồn tại')
        except (dns.resolver.NoNameservers, dns.exception.DNSException, OSError):
            ttl = 60
            result = ('Lỗi DNS tạm thời', 'TEMP_ERROR', 'Lỗi DNS hoặc mất mạng; có thể kiểm tra lại')
        with self.store.connect() as c:
            c.execute('INSERT OR REPLACE INTO dns_cache VALUES(?,?,?)', (domain, json.dumps(result, ensure_ascii=False), time.time() + ttl))
        return result


def check_session(store, sid, cancel, progress=lambda a, b: None, checker=None):
    checker = checker or DNSChecker(store)
    rows = store.rows(sid)
    col = store.session(sid)['email_col']
    seen, pending = {}, {}
    updates = []
    done = sum(bool(r['checked']) for r in rows)
    store.state(sid, 'checking')
    try:
        for i, row in enumerate(rows):
            if cancel.is_set():
                break
            source = json.loads(row['source'])
            try:
                address, key, domain = normalize(source[col])
                duplicate = f"Trùng dòng {seen[key]}" if key in seen else 'Không trùng'
                seen.setdefault(key, row['row_no'])
                updates.append((row['id'], dict(normalized=address, dedup_key=key, syntax='Hợp lệ', duplicate=duplicate)))
                if not row['checked']:
                    pending.setdefault(domain, []).append(row['id'])
            except ValueError as exc:
                if not row['checked']:
                    updates.append((row['id'], dict(syntax='Không hợp lệ', domain='Không kiểm tra', reason=str(exc), error='SYNTAX', checked=now())))
                    done += 1
            if len(updates) >= 50:
                store.update_rows(updates)
                updates.clear()
                progress(done, len(rows))
        if updates:
            store.update_rows(updates)
        progress(done, len(rows))
        if not cancel.is_set():
            # Bounded domain concurrency, one DNS query sequence per domain.
            with ThreadPoolExecutor(max_workers=8) as pool:
                futures = {pool.submit(checker.check, domain): ids for domain, ids in pending.items()}
                for future in as_completed(futures):
                    if cancel.is_set():
                        for f in futures:
                            f.cancel()
                        break
                    status, code, reason = future.result()
                    ids = futures[future]
                    for offset in range(0, len(ids), 100):
                        if cancel.is_set():
                            break
                        batch = ids[offset:offset+100]
                        stamp = now()
                        store.update_rows([(rid, dict(domain=status, reason=reason, error=code, checked=stamp)) for rid in batch])
                        done += len(batch)
                        progress(done, len(rows))
        store.state(sid, 'cancelled' if cancel.is_set() else 'done')
        return not cancel.is_set()
    except BaseException:
        store.state(sid, 'cancelled')
        raise


RESULT_COLUMNS = ['Email chuẩn hóa','Cú pháp','Tên miền','Trùng lặp','Trạng thái hộp thư','Trạng thái gửi','Lý do','Mã lỗi','Thời điểm kiểm tra (UTC)']
RESULT_KEYS = ['normalized','syntax','domain','duplicate','mailbox','send_state','reason','error','checked']


def text_cell(ws, row, col, value):
    cell = ws.cell(row, col)
    if isinstance(value, str):
        # Store an OOXML string explicitly: =,+,-,@ never become a formula.
        # Remove XML 1.0 forbidden controls only; original remains in SQLite.
        value = ''.join(ch for ch in value if ord(ch) >= 32 or ch in '\t\n\r')
        cell.value = value
        cell.data_type = 's'
    else:
        cell.value = value
    return cell


def export_xlsx(store, sid, path):
    path = Path(path).resolve()
    session = store.session(sid)
    if path == Path(session['source']).resolve():
        raise ValueError('Không được ghi đè tệp nguồn. Hãy chọn tên tệp mới.')
    rows = store.rows(sid)
    wb = Workbook()
    summary = wb.active
    summary.title = 'Tổng hợp'
    facts = [
        ('Email Check Excel', '1.0.0'), ('Nguồn', session['source']), ('Sheet nguồn', session['sheet']),
        ('Thời điểm xuất (UTC)', now()), ('Tổng số dòng', len(rows)),
        ('Đã kiểm tra', sum(bool(r['checked']) for r in rows)),
        ('Cú pháp hợp lệ', sum(r['syntax'] == 'Hợp lệ' for r in rows)),
        ('Dòng trùng', sum(r['duplicate'].startswith('Trùng') for r in rows)),
        ('Chưa xác định', sum(r['mailbox'] == UNKNOWN for r in rows)),
        ('Máy chủ báo không tồn tại', sum(r['mailbox'] == ABSENT for r in rows)),
        ('Phản hồi xác nhận tương ứng', sum(r['mailbox'] == CONFIRMED for r in rows)),
        ('Lưu ý', 'Cú pháp, DNS, gửi thành công hoặc không có thư báo lỗi không chứng minh hộp thư tồn tại.'),
        ('Bảo toàn', 'Giữ giá trị, cột và thứ tự dòng của sheet đã chọn; không sao chép định dạng, macro, công thức thực thi hay các sheet nguồn khác.')]
    for i, pair in enumerate(facts, 1):
        for j, value in enumerate(pair, 1):
            text_cell(summary, i, j, value)
    summary.column_dimensions['A'].width = 37
    summary.column_dimensions['B'].width = 100
    for name, group in [('Kết quả đầy đủ', rows), ('Chưa xác định', [r for r in rows if r['mailbox'] == UNKNOWN])]:
        ws = wb.create_sheet(name)
        headers = session['headers'] + RESULT_COLUMNS
        for j, value in enumerate(headers, 1):
            cell = text_cell(ws, 1, j, value)
            cell.font = Font(color='FFFFFF', bold=True)
            cell.fill = PatternFill('solid', fgColor='173B58')
        for i, row in enumerate(group, 2):
            values = json.loads(row['source']) + [row[k] for k in RESULT_KEYS]
            color = 'FEE2E2' if row['mailbox'] == ABSENT or row['syntax'] == 'Không hợp lệ' else 'DCFCE7' if row['mailbox'] == CONFIRMED else 'FFF4D6'
            for j, value in enumerate(values, 1):
                cell = text_cell(ws, i, j, value)
                if j > len(session['headers']):
                    cell.fill = PatternFill('solid', fgColor=color)
        ws.freeze_panes = 'A2'
        ws.auto_filter.ref = ws.dimensions
        for j in range(1, len(headers) + 1):
            ws.column_dimensions[get_column_letter(j)].width = 28 if j <= len(session['headers']) + 6 else 48
    # Atomic replacement avoids leaving a half-written export if interrupted.
    temp = path.with_name(path.name + '.tmp')
    try:
        wb.save(temp)
        temp.replace(path)
    finally:
        wb.close()
        temp.unlink(missing_ok=True)
    return str(path)
