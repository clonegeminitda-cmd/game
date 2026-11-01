"""Free local screening. Risk flags are never proof of mailbox existence."""
import json
from functools import lru_cache
from pathlib import Path

from .store import ABSENT, now

PASS = 'Qua bước lọc cơ bản — chưa xác minh hộp thư'
REVIEW = 'Cần xem lại'
REMOVE = 'Nên loại khỏi danh sách'
SYNTAX_OK = 'Đúng cú pháp'

DATA = Path(__file__).with_name('data')
ROLE_ACCOUNTS = frozenset('abuse admin administrator billing booking careers contact customerservice donotreply feedback help hr info jobs legal mailer-daemon marketing newsletter no-reply noreply notifications office orders postmaster privacy sales security service support team webmaster'.split())
TYPO_DOMAINS = {
    'gmial.com':'gmail.com', 'gamil.com':'gmail.com', 'gmai.com':'gmail.com',
    'gnail.com':'gmail.com', 'gmaill.com':'gmail.com', 'gmail.con':'gmail.com',
    'gmal.com':'gmail.com', 'yaho.com':'yahoo.com', 'yhaoo.com':'yahoo.com',
    'yahho.com':'yahoo.com', 'outllook.com':'outlook.com', 'outlok.com':'outlook.com',
    'outlook.con':'outlook.com', 'hotnail.com':'hotmail.com', 'hotmai.com':'hotmail.com',
    'hotmail.con':'hotmail.com', 'icloud.con':'icloud.com',
}


@lru_cache(maxsize=1)
def disposable_domains():
    path = DATA / 'disposable-domains.txt'
    # Missing bundled data is an error, never silently pretend the check passed.
    return frozenset(line.strip().lower() for line in path.read_text(encoding='utf-8').splitlines() if line.strip() and not line.startswith('#'))


def list_info():
    info = json.loads((DATA/'sources.json').read_text(encoding='utf-8'))
    return f"{len(disposable_domains()):,} tên miền · bản chụp {info['snapshot_date']} · nguồn cộng đồng, có thể thiếu hoặc lỗi thời"


def disposable_match(domain, blocklist=None):
    blocklist = disposable_domains() if blocklist is None else blocklist
    parts = domain.lower().rstrip('.').split('.')
    # Match complete domain labels, including subdomains, never a substring.
    return next(('.'.join(parts[i:]) for i in range(len(parts)-1) if '.'.join(parts[i:]) in blocklist), '')


def flags(address, blocklist=None):
    if not address or '@' not in address:
        return '', ''
    local, domain = address.rsplit('@',1)
    notes = []
    match = disposable_match(domain, blocklist)
    if match:
        notes.append('Tên miền có trong danh sách email tạm thời: ' + match + ' (cần xem lại, có thể lỗi thời)')
    if local.lower().split('+',1)[0] in ROLE_ACCOUNTS:
        notes.append('Địa chỉ chức năng / nhóm; không đồng nghĩa spam hoặc hộp thư không tồn tại')
    suggestion = TYPO_DOMAINS.get(domain, '')
    if suggestion:
        notes.append('Tên miền nghi gõ sai; chỉ gợi ý, không tự sửa')
    return '; '.join(notes), suggestion


def screening(row, blocklist=None):
    risk, suggestion = flags(row['normalized'], blocklist)
    reasons = []
    if row['syntax'] == 'Không hợp lệ':
        reasons.append('Sai cú pháp email')
    if row['duplicate'].startswith('Trùng'):
        reasons.append(row['duplicate'])
    if row['domain'] in ('Tên miền không tồn tại','Không nhận thư (Null MX)','Không có MX/A/AAAA'):
        reasons.append(row['domain'])
    if row['mailbox'] == ABSENT:
        reasons.append('Có thông báo hộp thư không tồn tại tương ứng')
    if reasons:
        decision = REMOVE
        risk = '; '.join(reasons + ([risk] if risk else []))
    elif risk or not row['checked'] or row['syntax'] != SYNTAX_OK or row['domain'] not in ('Có MX','Có A/AAAA thay MX'):
        decision = REVIEW
        if not risk:
            risk = 'Chưa kiểm tra xong hoặc DNS chưa xác định; không kết luận hộp thư không tồn tại'
    else:
        decision = PASS
        risk = 'Chưa thấy dấu hiệu trong các bộ lọc miễn phí; chưa xác minh hộp thư hay spamtrap'
    return dict(screening=decision, risk=risk, suggestion=suggestion, screened=now())


def screen_session(store, sid, cancel=None):
    updates = []
    for row in store.rows(sid):
        if cancel and cancel.is_set():
            break
        updates.append((row['id'], screening(row)))
        if len(updates) >= 100:
            store.update_rows(updates)
            updates.clear()
    if updates:
        store.update_rows(updates)


def export_groups(rows):
    return [('Nên loại', [r for r in rows if r['screening']==REMOVE]),
            ('Cần xem lại', [r for r in rows if r['screening']==REVIEW]),
            ('Qua lọc cơ bản', [r for r in rows if r['screening']==PASS])]
