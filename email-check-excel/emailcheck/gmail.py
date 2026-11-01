"""Opt-in Gmail transport, durable outbox and conservative message correlation."""
import base64
import ctypes
import json
import os
import re
import secrets
import sys
import threading
import time
import uuid
from datetime import datetime, timedelta, timezone
from email import policy
from email.message import EmailMessage
from email.parser import BytesParser
from email.utils import getaddresses
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import google_auth_httplib2
import httplib2

from .core import normalize
from .store import ABSENT, CONFIRMED, UNKNOWN, data_dir, now

SCOPES = ['https://www.googleapis.com/auth/gmail.send', 'https://www.googleapis.com/auth/gmail.readonly']


class Blob(ctypes.Structure):
    _fields_ = [('size', ctypes.c_ulong), ('data', ctypes.POINTER(ctypes.c_ubyte))]


def protect(data, decrypt=False):
    if sys.platform != 'win32':
        raise RuntimeError('Kết nối Gmail cần Windows để bảo vệ token bằng DPAPI.')
    buffer = ctypes.create_string_buffer(data)
    source = Blob(len(data), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte)))
    dest = Blob()
    crypt = ctypes.windll.crypt32
    kernel = ctypes.windll.kernel32
    crypt.CryptProtectData.argtypes = [ctypes.POINTER(Blob), ctypes.c_wchar_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(Blob)]
    crypt.CryptProtectData.restype = ctypes.c_int
    crypt.CryptUnprotectData.argtypes = [ctypes.POINTER(Blob), ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(Blob)]
    crypt.CryptUnprotectData.restype = ctypes.c_int
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    kernel.LocalFree.restype = ctypes.c_void_p
    if decrypt:
        ok = crypt.CryptUnprotectData(ctypes.byref(source), None, None, None, None, 1, ctypes.byref(dest))
    else:
        ok = crypt.CryptProtectData(ctypes.byref(source), 'Email Check Excel', None, None, None, 1, ctypes.byref(dest))
    if not ok:
        raise OSError('Không thể bảo vệ/giải mã token bằng DPAPI của tài khoản Windows hiện tại.')
    try:
        return ctypes.string_at(dest.data, dest.size)
    finally:
        kernel.LocalFree(dest.data)


class Gmail:
    def __init__(self, root=None):
        self.root = Path(root or data_dir())
        self.token = self.root / 'gmail-token.dpapi'
        self.client = self.root / 'oauth-desktop.json'
        self.credentials = None
        self.service = None

    def save(self):
        payload = protect(self.credentials.to_json().encode())
        temp = self.token.with_suffix('.tmp')
        temp.write_bytes(payload)
        temp.replace(self.token)

    def configure(self, path):
        config = json.loads(Path(path).read_text(encoding='utf-8-sig'))
        installed = config.get('installed', {})
        if not installed.get('client_id') or not installed.get('client_secret'):
            raise ValueError('Cần tệp JSON OAuth loại Ứng dụng dành cho máy tính (Desktop app).')
        if installed.get('auth_uri') != 'https://accounts.google.com/o/oauth2/auth' or installed.get('token_uri') != 'https://oauth2.googleapis.com/token':
            raise ValueError('Cấu hình phải sử dụng điểm OAuth chính thức của Google.')
        self.client.write_text(json.dumps(config), encoding='utf-8')

    def connect(self, interactive=False):
        if sys.platform != 'win32':
            raise RuntimeError('Chức năng Gmail yêu cầu Windows và DPAPI.')
        if interactive:
            if not self.client.exists():
                raise ValueError('Chưa nhập JSON OAuth Desktop.')
            flow = InstalledAppFlow.from_client_secrets_file(str(self.client), SCOPES)
            self.credentials = flow.run_local_server(
                host='127.0.0.1', port=0, open_browser=True, timeout_seconds=180,
                authorization_prompt_message='Hãy hoàn tất đăng nhập Google trong trình duyệt.',
                success_message='Kết nối đã hoàn tất. Bạn có thể đóng trang này và trở lại Email Check Excel.',
                access_type='offline', prompt='consent')
        else:
            if not self.token.exists():
                raise ValueError('Chưa kết nối Gmail. Mở tab Kết nối Gmail.')
            self.credentials = Credentials.from_authorized_user_info(json.loads(protect(self.token.read_bytes(), True)), SCOPES)
        if self.credentials.expired and self.credentials.refresh_token:
            self.credentials.refresh(Request())
        if not self.credentials.valid:
            raise ValueError('Phiên OAuth không còn hiệu lực. Hãy kết nối lại Gmail.')
        if not self.credentials.has_scopes(SCOPES):
            raise ValueError('Chưa cấp đủ quyền gửi và đọc thư để theo dõi báo lỗi.')
        self.save()
        http = google_auth_httplib2.AuthorizedHttp(self.credentials, http=httplib2.Http(timeout=20))
        self.service = build('gmail', 'v1', http=http, cache_discovery=False, static_discovery=True)
        return self.service.users().getProfile(userId='me').execute(num_retries=0)['emailAddress']

    def send(self, raw):
        try:
            return self.service.users().messages().send(userId='me', body={'raw': base64.urlsafe_b64encode(raw).decode()}).execute(num_retries=0)
        finally:
            if self.credentials:
                self.save()

    def messages(self, query, page_token=None):
        return self.service.users().messages().list(userId='me', q=query, includeSpamTrash=True, maxResults=100, pageToken=page_token).execute(num_retries=0)

    def message(self, mid):
        result = self.service.users().messages().get(userId='me', id=mid, format='raw').execute(num_retries=0)
        return base64.urlsafe_b64decode(result['raw'] + '===')


def confirmation_text(job):
    code = job['message_id'].split('@')[0].strip('<>')
    return f"Tôi xác nhận {code}"


def compose(job):
    message = EmailMessage()
    message['To'] = job['recipient']
    message['Subject'] = job['subject']
    message['Message-ID'] = job['message_id']
    # One recipient, no tracking pixel or hidden open tracking.
    message.set_content(job['body'])
    return message.as_bytes(policy=policy.SMTP)


def draft(row, subject, body):
    mid = f'<ECE-{secrets.token_hex(12)}@emailcheck.local>'
    job = {'row_id': row['id'], 'dedup_key': row['dedup_key'], 'recipient': row['normalized'],
           'subject': subject.strip(), 'body': body.rstrip(), 'message_id': mid}
    job['body'] += '\n\nNếu bạn đồng ý xác nhận địa chỉ này, hãy trả lời thư bằng đúng dòng sau:\n' + confirmation_text(job)
    return job


def enqueue(store, drafts, consent):
    if not consent:
        raise ValueError('Cần xác nhận người nhận đã đồng ý hoặc đang mong đợi liên hệ.')
    if not drafts:
        raise ValueError('Chưa chọn người nhận.')
    with store.connect() as c:
        for job in drafts:
            row = c.execute('SELECT * FROM rows WHERE id=?', (job['row_id'],)).fetchone()
            if not row or row['syntax'] != 'Hợp lệ' or row['domain'] not in ('Có MX', 'Có A/AAAA thay MX') or row['duplicate'] != 'Không trùng' or row['mailbox'] != UNKNOWN:
                raise ValueError('Chỉ gửi dòng đã kiểm tra, không trùng, có tuyến nhận thư và hộp thư chưa xác định.')
            if row['normalized'] != job['recipient'] or row['dedup_key'] != job['dedup_key']:
                raise ValueError('Dữ liệu người nhận đã thay đổi. Hãy xem trước lại.')
            if not job['recipient'].isascii():
                raise ValueError('Chưa hỗ trợ gửi địa chỉ có ký tự Unicode ở phần trước @ (SMTPUTF8).')
            if not job['subject'] or '\n' in job['subject'] or '\r' in job['subject']:
                raise ValueError('Tiêu đề bắt buộc và không được xuống dòng.')
            if not job['body'].strip():
                raise ValueError('Nội dung không được trống.')
            if c.execute('SELECT 1 FROM jobs WHERE dedup_key=?', (job['dedup_key'],)).fetchone():
                raise ValueError('Một địa chỉ đã có trong nhật ký gửi. Không tạo lần gửi trùng.')
            c.execute('''INSERT INTO jobs(row_id,dedup_key,recipient,subject,body,message_id,created)
                         VALUES(:row_id,:dedup_key,:recipient,:subject,:body,:message_id,:created)''', {**job, 'created': now()})
            c.execute("UPDATE rows SET send_state='Trong hàng đợi' WHERE id=?", (job['row_id'],))


def failure(exc):
    if isinstance(exc, HttpError):
        status = exc.resp.status
        if status in (403, 429):
            return 'failed', 'GMAIL_LIMIT_OR_BLOCK', 'Gmail báo hạn mức hoặc từ chối quyền/chặn gửi. Hàng đợi đã dừng.'
        if status in (400, 404):
            return 'failed', 'GMAIL_REQUEST_REJECTED', 'Gmail từ chối yêu cầu. Không kết luận người nhận không tồn tại.'
        if status == 401:
            return 'failed', 'GMAIL_AUTH', 'Phiên Gmail hết hiệu lực. Hãy kết nối lại trước khi xử lý tiếp.'
    return 'reconcile', 'SEND_UNCERTAIN', 'Không rõ máy chủ đã nhận thư chưa. Cần đối soát; không tự gửi lại.'


class Outbox:
    def __init__(self, store, gmail):
        self.store, self.gmail = store, gmail

    def run(self, cancel, pause, progress=lambda s: None, limit=50, interval=30):
        limit = max(1, min(500, int(limit)))
        interval = max(6, int(interval))
        last_monitor = 0
        while not cancel.is_set():
            if pause.is_set():
                cancel.wait(0.2)
                continue
            if self.store.get('queue_halt'):
                progress('Hàng đợi đang dừng: ' + self.store.get('queue_halt'))
                break
            if time.monotonic() - last_monitor >= 60 and hasattr(self.gmail, 'messages'):
                try:
                    monitor(self.store, self.gmail, cancel)
                    last_monitor = time.monotonic()
                except Exception:
                    self.store.set('queue_halt', 'Không cập nhật được thư báo lỗi. Hãy kiểm tra kết nối Gmail trước khi gửi tiếp.')
                if self.store.get('queue_halt') or cancel.is_set():
                    progress(self.store.get('queue_halt') or 'Đã hủy tác vụ.')
                    break
            jobs = self.store.jobs(['queued'])
            if not jobs:
                progress('Đã xử lý xong hàng đợi.')
                break
            if cancel.is_set():
                break
            if pause.is_set():
                continue
            cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat(timespec='seconds')
            with self.store.connect() as c:
                used = c.execute('SELECT COUNT(*) FROM jobs WHERE sent_at>=?', (cutoff,)).fetchone()[0]
            if used >= limit:
                progress(f'Đã đạt giới hạn {limit} lần thử gửi / 24 giờ do ứng dụng đặt. Dừng hàng đợi.')
                break
            job = jobs[0]
            # Persist before network I/O; startup recovery turns sending into reconcile.
            with self.store.connect() as c:
                changed = c.execute("UPDATE jobs SET state='sending',sent_at=? WHERE id=? AND state='queued'", (now(), job['id'])).rowcount
                if changed:
                    c.execute("UPDATE rows SET send_state='Đang gửi' WHERE id=?", (job['row_id'],))
            if not changed:
                continue
            try:
                response = self.gmail.send(compose(job))
                if not response.get('id'):
                    raise ConnectionError('Thiếu định danh Gmail')
                with self.store.connect() as c:
                    c.execute("UPDATE jobs SET state='sent',gmail_id=?,thread_id=? WHERE id=?", (response['id'], response.get('threadId',''), job['id']))
                    c.execute("UPDATE rows SET send_state='Đã gửi (chưa xác nhận hộp thư)' WHERE id=?", (job['row_id'],))
                progress(f"Đã gửi một thư riêng tới {job['recipient']}; chưa xác định hộp thư.")
            except Exception as exc:
                state, code, reason = failure(exc)
                with self.store.connect() as c:
                    c.execute('UPDATE jobs SET state=?,error=? WHERE id=?', (state, code, job['id']))
                    c.execute('UPDATE rows SET send_state=?,error=?,reason=? WHERE id=?', ('Cần đối soát' if state == 'reconcile' else 'Gửi lỗi', code, reason, job['row_id']))
                self.store.set('queue_halt', reason)
                progress(reason)
                break
            end = time.monotonic() + interval
            while time.monotonic() < end and not cancel.is_set():
                if pause.is_set():
                    cancel.wait(0.2)
                    # Pause does not consume the interval then allow a burst.
                    end = time.monotonic() + interval
                else:
                    cancel.wait(min(0.2, max(0, end - time.monotonic())))
        if cancel.is_set():
            progress('Đã dừng xử lý. Thư đang gửi có thể đã được chấp nhận; xem nhật ký.')

    def cancel_pending(self):
        with self.store.connect() as c:
            c.execute("UPDATE rows SET send_state='Đã hủy gửi' WHERE id IN (SELECT row_id FROM jobs WHERE state='queued')")
            c.execute("UPDATE jobs SET state='cancelled' WHERE state='queued'")


def message_ids(message):
    ids = set()
    for name in ('In-Reply-To', 'References', 'Original-Message-ID'):
        ids.update(re.findall(r'<[^<>\s]+>', str(message.get(name, ''))))
    for part in message.walk():
        if part.get_content_type() in ('message/rfc822', 'text/rfc822-headers'):
            payload = part.get_payload()
            nested = payload if isinstance(payload, list) else [BytesParser(policy=policy.default).parsebytes((part.get_payload(decode=True) or b''))]
            for msg in nested:
                if msg.get('Message-ID'):
                    ids.add(str(msg['Message-ID']).strip())
        if part.get_content_type() == 'message/delivery-status':
            for block in part.get_payload() if isinstance(part.get_payload(), list) else []:
                ids.update(re.findall(r'<[^<>\s]+>', str(block.get('Original-Message-ID',''))))
    return ids


def correlate(raw, job):
    msg = BytesParser(policy=policy.default).parsebytes(raw)
    if job['message_id'] not in message_ids(msg):
        return None
    for part in msg.walk():
        if part.get_content_type() != 'message/delivery-status':
            continue
        for block in part.get_payload() if isinstance(part.get_payload(), list) else []:
            target = str(block.get('Final-Recipient', '')).split(';')[-1].strip()
            try:
                _, key, _ = normalize(target)
            except ValueError:
                continue
            if key != job['dedup_key']:
                continue
            status = str(block.get('Status', '')).strip()
            action = str(block.get('Action', '')).strip().lower()
            diagnostic = str(block.get('Diagnostic-Code', ''))
            # An enhanced status alone is insufficient; require corresponding
            # unknown-recipient text, exact original ID and matching recipient.
            nonexistent = re.search(r'(?i)(user unknown|unknown user|no such (?:user|mailbox)|mailbox (?:does not exist|not found)|recipient (?:not found|does not exist)|(?:email )?account (?:does not exist|not found)|address.*(?:not found|does not exist)|hộp thư không tồn tại)', diagnostic)
            if action == 'failed' and status == '5.1.1' and nonexistent:
                return ('absent', 'DSN_5.1.1', 'DSN 5.1.1 có nội dung hộp thư không tồn tại; khớp định danh thư và người nhận')
            if action in ('failed', 'delayed') and (status.startswith(('5.7.', '4.7.')) or re.search(r'(?i)(rate.?limit|quota|blocked|spam policy)', diagnostic)):
                return ('blocked', 'DSN_' + status, 'Thông báo tương ứng báo hạn mức hoặc bị chặn; dừng hàng đợi, chưa kết luận hộp thư không tồn tại')
            if action in ('failed', 'delayed'):
                return ('bounce', 'DSN_' + status, 'Thư báo lỗi/chậm gửi tương ứng; chưa đủ bằng chứng hộp thư không tồn tại')
    senders = getaddresses(msg.get_all('From', []))
    if len(senders) != 1 or msg.get('Auto-Submitted', 'no').lower() != 'no' or msg.get('Precedence', '').lower() in ('bulk','list','junk'):
        return None
    try:
        if normalize(senders[0][1])[1] != job['dedup_key']:
            return None
    except ValueError:
        return None
    # Only a new, explicit confirmation line, never a quoted original message.
    for part in msg.walk():
        if part.get_content_type() == 'text/plain' and part.get_content_disposition() != 'attachment':
            content = part.get_content()
            if isinstance(content, str):
                for line in content.splitlines():
                    if not line.strip():
                        continue
                    if line.startswith('>') or re.match(r'(?i)^On .+wrote:|^Vào .+đã viết:', line):
                        break
                    if line.strip() == confirmation_text(job):
                        return ('confirmed', 'EXPLICIT_REPLY', 'Phản hồi chứa dòng xác nhận riêng, khớp người gửi và định danh thư; dựa trên dữ liệu tiêu đề email')
                    # Require confirmation as the first nonempty new line;
                    # unquoted copies of the original do not count.
                    break
    return None


def monitor(store, gmail, cancel, progress=lambda s: None, include_expired=False):
    deadline = datetime.now(timezone.utc) - timedelta(hours=48)
    jobs = [job for job in store.jobs(['sent','reconcile'])
            if include_expired or datetime.fromisoformat(job['sent_at'] or job['created']) >= deadline]
    if not jobs:
        progress('Không có thư trong khoảng theo dõi. Không có phản hồi vẫn là Chưa xác định.')
        return 0
    # Read each Gmail message once per pass, even for a 1,000-recipient outbox.
    indexed = {job['message_id']: job for job in jobs}
    start = min(datetime.fromisoformat(j['last_scan'] or j['sent_at'] or j['created']) for j in jobs) - timedelta(minutes=5)
    query = f'after:{int(start.timestamp())}'
    scan_started, page, complete, total = now(), None, True, 0
    while True:
        if cancel.is_set():
            complete = False
            break
        listing = gmail.messages(query, page)
        for candidate in listing.get('messages', []):
            if cancel.is_set():
                complete = False
                break
            mid = candidate['id']
            raw = gmail.message(mid)
            parsed = BytesParser(policy=policy.default).parsebytes(raw)
            matches = [indexed[ref] for ref in message_ids(parsed) if ref in indexed]
            for job in matches:
                event_id = mid + ':' + str(job['id'])
                with store.connect() as c:
                    seen = c.execute('SELECT 1 FROM events WHERE gmail_id=?', (event_id,)).fetchone()
                if seen:
                    continue
                evidence = correlate(raw, job)
                if not evidence:
                    continue
                kind, code, detail = evidence
                with store.connect() as c:
                    c.execute('INSERT OR IGNORE INTO events VALUES(?,?,?,?,?)', (event_id, job['id'], kind, detail, now()))
                    if kind == 'absent':
                        c.execute('UPDATE rows SET mailbox=?,send_state=?,error=?,reason=? WHERE id=?', (ABSENT, 'Thư trả về', code, detail, job['row_id']))
                    elif kind == 'confirmed':
                        c.execute('UPDATE rows SET mailbox=?,error=?,reason=? WHERE id=?', (CONFIRMED, code, detail, job['row_id']))
                    else:
                        c.execute("UPDATE rows SET send_state='Thư trả về / chậm gửi',error=?,reason=? WHERE id=?", (code, detail, job['row_id']))
                if kind == 'blocked':
                    store.set('queue_halt', detail)
                total += 1
        page = listing.get('nextPageToken')
        if not page or not complete:
            break
    if complete:
        with store.connect() as c:
            c.executemany('UPDATE jobs SET last_scan=? WHERE id=?', [(scan_started, j['id']) for j in jobs])
    with store.connect() as c:
        bounces = c.execute("SELECT COUNT(DISTINCT job_id) FROM events WHERE kind IN ('absent','bounce','blocked') AND created>=?", ((datetime.now(timezone.utc)-timedelta(hours=24)).isoformat(timespec='seconds'),)).fetchone()[0]
    if bounces >= 3:
        store.set('queue_halt', 'Có ít nhất 3 thư trả về trong 24 giờ. Hãy kiểm tra danh sách và nội dung trước khi tiếp tục.')
    progress(f'Đã cập nhật {total} phản hồi tương ứng. Không có phản hồi vẫn là Chưa xác định.')
    return total


def reconcile_sent(store, gmail, cancel, progress=lambda s: None):
    """Find exact IDs in Sent. Absence never authorizes an automatic retry."""
    count = 0
    for job in store.jobs(['reconcile']):
        if cancel.is_set():
            break
        query = 'in:sent rfc822msgid:' + job['message_id'].strip('<>')
        listing = gmail.messages(query)
        for candidate in listing.get('messages', []):
            raw = gmail.message(candidate['id'])
            msg = BytesParser(policy=policy.default).parsebytes(raw)
            recipients = getaddresses(msg.get_all('To', []))
            if str(msg.get('Message-ID','')).strip() == job['message_id'] and len(recipients) == 1 and recipients[0][1] == job['recipient']:
                with store.connect() as c:
                    c.execute("UPDATE jobs SET state='sent',gmail_id=?,error='' WHERE id=?", (candidate['id'], job['id']))
                    c.execute("UPDATE rows SET send_state='Đã đối soát trong Thư đã gửi' WHERE id=?", (job['row_id'],))
                count += 1
                break
    progress(f'Đã đối soát {count} thư trong Thư đã gửi. Các thư còn lại không tự gửi lại.')
    return count
