"""User-local SQLite journal. No OAuth credentials are stored here."""
import json
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

UNKNOWN = 'Chưa xác định'
ABSENT = 'Máy chủ báo hộp thư không tồn tại'
CONFIRMED = 'Đã nhận phản hồi xác nhận tương ứng của người nhận'


def now():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def data_dir():
    override = os.environ.get('EMAILCHECK_DATA_DIR')
    base = Path(override) if override else Path(os.environ.get('LOCALAPPDATA', str(Path.home() / '.local' / 'share'))) / 'EmailCheckExcel'
    base.mkdir(parents=True, exist_ok=True)
    return base


class Store:
    def __init__(self, path=None):
        self.path = Path(path or data_dir() / 'sessions.sqlite3')
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as c:
            c.executescript('''
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS sessions(
              id INTEGER PRIMARY KEY, source TEXT, sheet TEXT, headers TEXT,
              email_col INTEGER, created TEXT, state TEXT DEFAULT 'loaded');
            CREATE TABLE IF NOT EXISTS rows(
              id INTEGER PRIMARY KEY, session_id INTEGER REFERENCES sessions(id),
              row_no INTEGER, source TEXT, normalized TEXT DEFAULT '', dedup_key TEXT DEFAULT '',
              syntax TEXT DEFAULT 'Chưa kiểm tra', domain TEXT DEFAULT 'Chưa kiểm tra',
              duplicate TEXT DEFAULT '', mailbox TEXT DEFAULT 'Chưa xác định',
              send_state TEXT DEFAULT 'Chưa gửi', reason TEXT DEFAULT '',
              error TEXT DEFAULT '', checked TEXT DEFAULT '', UNIQUE(session_id,row_no));
            CREATE TABLE IF NOT EXISTS dns_cache(domain TEXT PRIMARY KEY, result TEXT, expires REAL);
            CREATE TABLE IF NOT EXISTS jobs(
              id INTEGER PRIMARY KEY, row_id INTEGER REFERENCES rows(id), dedup_key TEXT UNIQUE,
              recipient TEXT, subject TEXT, body TEXT, state TEXT DEFAULT 'queued',
              message_id TEXT UNIQUE, gmail_id TEXT, thread_id TEXT,
              created TEXT, sent_at TEXT, error TEXT DEFAULT '', last_scan TEXT DEFAULT '');
            CREATE TABLE IF NOT EXISTS events(
              gmail_id TEXT PRIMARY KEY, job_id INTEGER, kind TEXT, detail TEXT, created TEXT);
            CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
            CREATE INDEX IF NOT EXISTS rows_session ON rows(session_id,row_no);
            ''')

    @contextmanager
    def connect(self):
        c = sqlite3.connect(self.path, timeout=20)
        c.row_factory = sqlite3.Row
        c.execute('PRAGMA foreign_keys=ON')
        try:
            yield c
            c.commit()
        except BaseException:
            c.rollback()
            raise
        finally:
            c.close()

    def get(self, key, default=''):
        with self.connect() as c:
            row = c.execute('SELECT value FROM settings WHERE key=?', (key,)).fetchone()
            return row[0] if row else default

    def set(self, key, value):
        with self.connect() as c:
            c.execute('INSERT OR REPLACE INTO settings VALUES(?,?)', (key, str(value)))

    def create_session(self, source, sheet, headers, email_col, rows):
        with self.connect() as c:
            sid = c.execute('INSERT INTO sessions(source,sheet,headers,email_col,created) VALUES(?,?,?,?,?)',
                            (str(Path(source).resolve()), sheet, json.dumps(headers, ensure_ascii=False, default=str), email_col, now())).lastrowid
            c.executemany('INSERT INTO rows(session_id,row_no,source) VALUES(?,?,?)',
                          [(sid, i + 2, json.dumps(row, ensure_ascii=False, default=str)) for i, row in enumerate(rows)])
            return sid

    def sessions(self):
        with self.connect() as c:
            return [dict(r) for r in c.execute('SELECT * FROM sessions ORDER BY id DESC')]

    def session(self, sid):
        with self.connect() as c:
            r = dict(c.execute('SELECT * FROM sessions WHERE id=?', (sid,)).fetchone())
            r['headers'] = json.loads(r['headers'])
            return r

    def rows(self, sid):
        with self.connect() as c:
            return [dict(r) for r in c.execute('SELECT * FROM rows WHERE session_id=? ORDER BY row_no', (sid,))]

    def update_row(self, rid, **values):
        allowed = {'normalized','dedup_key','syntax','domain','duplicate','mailbox','send_state','reason','error','checked'}
        if not values or not set(values) <= allowed:
            raise ValueError('Cột cập nhật không hợp lệ')
        with self.connect() as c:
            c.execute('UPDATE rows SET ' + ','.join(k + '=?' for k in values) + ' WHERE id=?', (*values.values(), rid))

    def state(self, sid, state):
        with self.connect() as c:
            c.execute('UPDATE sessions SET state=? WHERE id=?', (state, sid))

    def recover(self):
        # A process may have died after the server accepted a message. Never retry it.
        with self.connect() as c:
            c.execute("UPDATE jobs SET state='reconcile',error='Ứng dụng đóng khi đang gửi; cần đối soát' WHERE state='sending'")
            c.execute("UPDATE rows SET send_state='Cần đối soát' WHERE id IN (SELECT row_id FROM jobs WHERE state='reconcile')")
            c.execute("UPDATE sessions SET state='cancelled' WHERE state='checking'")

    def jobs(self, states=None):
        with self.connect() as c:
            sql = 'SELECT * FROM jobs'
            args = ()
            if states:
                sql += ' WHERE state IN (' + ','.join('?' for _ in states) + ')'
                args = tuple(states)
            return [dict(r) for r in c.execute(sql + ' ORDER BY id', args)]
