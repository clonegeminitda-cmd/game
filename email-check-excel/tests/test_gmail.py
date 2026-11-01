import json
import threading
from email.message import EmailMessage
from email import policy
from types import SimpleNamespace
from datetime import datetime, timedelta, timezone

import pytest
from googleapiclient.errors import HttpError

from emailcheck.core import check_session
from emailcheck.store import Store, UNKNOWN, ABSENT, CONFIRMED
from emailcheck.gmail import Outbox, draft, enqueue, correlate, confirmation_text, monitor, reconcile_sent, protect, Gmail
from tests.test_core import FakeDNS


def prepare(store, tmp_path, count=1):
    sid = store.create_session(tmp_path/'source.xlsx','Sheet',['Email'],0,[[f'user{i}@example.com'] for i in range(count)])
    check_session(store,sid,threading.Event(),checker=FakeDNS())
    jobs = [draft(r,'Thử nghiệm','Xin chào') for r in store.rows(sid)]
    return sid,jobs


class MockGmail:
    def __init__(self,error=None,raws=None):
        self.error,self.raws,self.calls = error,raws or {},[]

    def send(self,raw):
        self.calls.append(raw)
        if self.error:
            raise self.error
        return {'id':'gmail'+str(len(self.calls)), 'threadId':'thread1'}

    def messages(self,query,page_token=None):
        return {'messages':[{'id':k} for k in self.raws]}

    def message(self,mid):
        return self.raws[mid]


def test_consent_no_default_sending_and_no_duplicates(store,tmp_path):
    sid,jobs = prepare(store,tmp_path)
    with pytest.raises(ValueError):
        enqueue(store,jobs,False)
    assert store.jobs() == []
    enqueue(store,jobs,True)
    with pytest.raises(ValueError):
        enqueue(store,jobs,True)
    mock = MockGmail()
    cancel = threading.Event()
    Outbox(store,mock).run(cancel,threading.Event(),lambda s: cancel.set(),interval=6)
    assert len(mock.calls) == 1
    assert store.jobs()[0]['state'] == 'sent'
    assert store.rows(sid)[0]['mailbox'] == UNKNOWN
    assert b'Bcc:' not in mock.calls[0] and b'Cc:' not in mock.calls[0]
    Outbox(Store(store.path),mock).run(threading.Event(),threading.Event())
    assert len(mock.calls) == 1


@pytest.mark.parametrize('error,expected',[
    (TimeoutError(),'reconcile'),
    (ConnectionError(),'reconcile'),
    (HttpError(SimpleNamespace(status=429,reason='limit'),b'{"error":{"message":"quota"}}'),'failed'),
    (HttpError(SimpleNamespace(status=403,reason='blocked'),b'{}'),'failed'),
    (HttpError(SimpleNamespace(status=500,reason='temporary'),b'{}'),'reconcile'),
    (HttpError(SimpleNamespace(status=400,reason='bad request'),b'{}'),'failed'),
])
def test_send_failures_stop_and_never_infer_absent(store,tmp_path,error,expected):
    sid,jobs = prepare(store,tmp_path,2)
    enqueue(store,jobs,True)
    mock = MockGmail(error)
    Outbox(store,mock).run(threading.Event(),threading.Event(),interval=6)
    assert len(mock.calls)==1
    assert store.jobs()[0]['state'] == expected
    assert store.jobs()[1]['state'] == 'queued'
    assert store.get('queue_halt')
    assert all(r['mailbox']==UNKNOWN for r in store.rows(sid))
    Outbox(store,mock).run(threading.Event(),threading.Event())
    assert len(mock.calls)==1


def test_crash_recovery_limit_pause_and_cancel(store,tmp_path):
    sid,jobs = prepare(store,tmp_path,3)
    enqueue(store,jobs,True)
    with store.connect() as c:
        c.execute("UPDATE jobs SET state='sending' WHERE id=1")
    Store(store.path).recover()
    assert store.jobs()[0]['state']=='reconcile'
    mock = MockGmail()
    cancel,pause = threading.Event(),threading.Event()
    pause.set()
    thread = threading.Thread(target=Outbox(store,mock).run,args=(cancel,pause),kwargs={'interval':6})
    thread.start()
    cancel.wait(.25)
    assert not mock.calls
    pause.clear()
    for _ in range(100):
        if mock.calls:
            break
        cancel.wait(.02)
    cancel.set()
    thread.join(5)
    assert not thread.is_alive() and len(mock.calls)==1
    Outbox(store,mock).run(threading.Event(),threading.Event(),limit=1,interval=6)
    assert len(mock.calls)==1
    Outbox(store,mock).cancel_pending()
    assert store.jobs()[-1]['state']=='cancelled'


def dsn(job,status='5.1.1',diag='smtp; 550 5.1.1 The email account does not exist',recipient=None,mid=None):
    return (f'From: mailer-daemon@example.com\r\nTo: sender@example.net\r\nMIME-Version: 1.0\r\nContent-Type: multipart/report; report-type=delivery-status; boundary="bound"\r\n\r\n'
            f'--bound\r\nContent-Type: text/plain\r\n\r\nDelivery failed\r\n'
            f'--bound\r\nContent-Type: message/delivery-status\r\n\r\nReporting-MTA: dns; mx.example.com\r\n\r\nFinal-Recipient: rfc822; {recipient or job["recipient"]}\r\nAction: failed\r\nStatus: {status}\r\nDiagnostic-Code: {diag}\r\n\r\n'
            f'--bound\r\nContent-Type: text/rfc822-headers\r\n\r\nMessage-ID: {mid or job["message_id"]}\r\nTo: {job["recipient"]}\r\n\r\n--bound--\r\n').encode()


def reply(job,text=None,sender=None):
    msg=EmailMessage()
    msg['From']=sender or job['recipient']
    msg['In-Reply-To']=job['message_id']
    msg['Subject']='Re: Thử nghiệm'
    msg.set_content(text if text is not None else confirmation_text(job))
    return msg.as_bytes(policy=policy.SMTP)


def test_dsn_precise_evidence_and_no_false_conclusions(store,tmp_path):
    sid,jobs=prepare(store,tmp_path)
    job=jobs[0]
    assert correlate(dsn(job),job)[0]=='absent'
    assert correlate(dsn(job,diag='smtp; 550-5.1.1 The email account that you tried to reach does not exist.'),job)[0]=='absent'
    assert correlate(dsn(job,status='5.2.2',diag='smtp; 552 mailbox full'),job)[0]=='bounce'
    assert correlate(dsn(job,diag='smtp; 550 blocked by policy'),job)[0]=='blocked'
    assert correlate(dsn(job,recipient='other@example.com'),job) is None
    assert correlate(dsn(job,mid='<other@id>'),job) is None
    assert correlate(reply(job),job)[0]=='confirmed'
    assert correlate(reply(job,sender='impostor@example.com'),job) is None
    assert correlate(reply(job,text='> '+confirmation_text(job)),job) is None
    assert correlate(reply(job,text='Đây là tự động trả lời\n> '+confirmation_text(job)),job) is None
    assert correlate(reply(job,text='Nội dung tự động\n'+confirmation_text(job)),job) is None


def test_monitor_restart_48h_and_bounce_halt(store,tmp_path):
    sid,jobs=prepare(store,tmp_path,3)
    enqueue(store,jobs,True)
    with store.connect() as c:
        c.execute("UPDATE jobs SET state='sent',sent_at=?",(datetime.now(timezone.utc).isoformat(timespec='seconds'),))
    mock=MockGmail(raws={str(i):dsn(j) for i,j in enumerate(jobs)})
    assert monitor(store,mock,threading.Event())==3
    assert all(r['mailbox']==ABSENT for r in store.rows(sid))
    assert store.get('queue_halt')
    assert monitor(Store(store.path),mock,threading.Event())==0
    with store.connect() as c:
        c.execute('DELETE FROM events')
        c.execute('UPDATE jobs SET sent_at=?,last_scan=?',((datetime.now(timezone.utc)-timedelta(hours=49)).isoformat(timespec='seconds'),''))
    assert monitor(store,mock,threading.Event())==0
    assert monitor(store,mock,threading.Event(),include_expired=True)==3


def test_confirmation_and_no_response_unknown(store,tmp_path):
    sid,jobs=prepare(store,tmp_path,2)
    enqueue(store,jobs,True)
    with store.connect() as c:
        c.execute("UPDATE jobs SET state='sent',sent_at=?",(datetime.now(timezone.utc).isoformat(timespec='seconds'),))
    monitor(store,MockGmail(raws={'reply':reply(jobs[0])}),threading.Event())
    assert store.rows(sid)[0]['mailbox']==CONFIRMED
    assert store.rows(sid)[1]['mailbox']==UNKNOWN


def test_single_blocked_dsn_halts_queue_without_inference(store,tmp_path):
    sid,jobs=prepare(store,tmp_path)
    enqueue(store,jobs,True)
    with store.connect() as c:
        c.execute("UPDATE jobs SET state='sent',sent_at=?",(datetime.now(timezone.utc).isoformat(timespec='seconds'),))
    mock=MockGmail(raws={'blocked':dsn(jobs[0],status='5.7.1',diag='smtp; 550 blocked by policy')})
    monitor(store,mock,threading.Event())
    assert store.get('queue_halt')
    assert store.rows(sid)[0]['mailbox']==UNKNOWN


def test_reconcile_exact_sent_message_no_retry(store,tmp_path):
    from emailcheck.gmail import compose
    sid,jobs=prepare(store,tmp_path)
    enqueue(store,jobs,True)
    with store.connect() as c:
        c.execute("UPDATE jobs SET state='reconcile'")
    mock=MockGmail(raws={'sent1':compose(jobs[0])})
    assert reconcile_sent(store,mock,threading.Event())==1
    assert store.jobs()[0]['state']=='sent'
    assert not mock.calls
    assert store.rows(sid)[0]['mailbox']==UNKNOWN


@pytest.mark.skipif(__import__('sys').platform!='win32',reason='Windows DPAPI only')
def test_dpapi_encrypt_decrypt_and_no_plaintext(tmp_path):
    secret=b'test-token-only-not-a-real-token'
    encrypted=protect(secret)
    assert secret not in encrypted
    assert protect(encrypted,True)==secret


def test_bad_oauth_client_rejected(tmp_path):
    path=tmp_path/'bad.json'
    path.write_text(json.dumps({'web':{'client_id':'fake'}}))
    with pytest.raises(ValueError):
        Gmail(tmp_path).configure(path)
