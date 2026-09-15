#!/usr/bin/env python3
"""Drive `plumesign account login` through a PTY so 2FA can be answered out-of-band.

Credentials are read from ~/.secrets (never passed in argv, never logged).
The 2FA code is read from /tmp/2fa_code, which is polled until it appears,
so the human never has to race an interactive prompt.

Usage:  python3 tools/apple-login.py
Then:   echo 123456 > /tmp/2fa_code      (when the code arrives)
"""
import os
import pty
import re
import select
import sys
import time

BIN = os.environ.get('PLUMESIGN_BIN') or os.path.join(os.path.dirname(os.path.abspath(__file__)), 'plumesign-linux-x86_64')
SECRETS = os.path.expanduser('~/.secrets')
CODE_FILE = '/tmp/2fa_code'
LOG = '/tmp/plumesign-login.log'
DEADLINE = time.time() + 420          # fail fast: 7 minutes total
CODE_WAIT = time.time() + 300         # 5 minutes for the human to supply the code


def load_secrets(path):
    creds = {}
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                k, v = line.split('=', 1)
                k = k.strip()
                if k.startswith('export '):
                    k = k[len('export '):].strip()
                creds[k] = v.strip().strip('"').strip("'")
    except OSError as exc:
        print('cannot read %s: %s' % (path, exc))
    return creds


def note(msg):
    """Log/print only things that are safe to see."""
    line = '[driver] %s' % msg
    print(line, flush=True)
    with open(LOG, 'a', encoding='utf-8') as fh:
        fh.write(line + '\n')


def main():
    creds = load_secrets(SECRETS)
    email = creds.get('APPLE_ID_EMAIL') or os.environ.get('APPLE_ID_EMAIL')
    password = creds.get('APPLE_ID_PASSWORD') or os.environ.get('APPLE_ID_PASSWORD')
    if not email or not password:
        # preferred form: a single APPLE_CREDENTIALS=user:pass entry (split at the FIRST colon)
        blob = creds.get('APPLE_CREDENTIALS') or os.environ.get('APPLE_CREDENTIALS') or ''
        if ':' in blob:
            email, password = (p.strip() for p in blob.split(':', 1))
    if not email or not password:
        print('MISSING CREDENTIALS.\n'
              'Add to %s either:\n'
              '  APPLE_CREDENTIALS=you@example.com:yourpassword\n'
              'or the two separate keys:\n'
              '  APPLE_ID_EMAIL=you@example.com\n'
              '  APPLE_ID_PASSWORD=yourpassword\n' % SECRETS)
        return 2

    if os.path.exists(CODE_FILE):
        os.unlink(CODE_FILE)
    try:
        os.truncate(LOG, 0)
    except OSError:
        pass

    note('logging in as %s (password masked)' % email)
    pid, fd = pty.fork()
    if pid == 0:                                    # child
        os.execv(BIN, [BIN, 'account', 'login', '-u', email])
        os._exit(127)

    # plumesign echoes typed input, which would dump the password into the log and onto the
    # terminal. Turn ECHO off on the shared line discipline before sending anything.
    try:
        import termios
        attrs = termios.tcgetattr(fd)
        attrs[3] &= ~termios.ECHO
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        note('pty echo disabled (password will not be logged)')
    except Exception as exc:
        note('could not disable pty echo: %s' % exc)

    sent = {'email': True, 'password': False, 'code': False}
    buf = ''
    waiting_announced = False

    def send(value, label):
        os.write(fd, value.encode() + b'\n')
        note('sent %s' % label)

    while True:
        if time.time() > DEADLINE:
            note('TIMEOUT - giving up')
            os.kill(pid, 9)
            return 1
        try:
            r, _, _ = select.select([fd], [], [], 2.0)
        except OSError:
            r = []
        # Poll for the 2FA code on every tick, not only when the child emits output.
        # plumesign prints its prompt once and then goes silent, so an output-gated
        # check never fires again and the code file is read too late (or never).
        if waiting_announced and not sent['code'] and os.path.exists(CODE_FILE):
            with open(CODE_FILE, 'r', encoding='utf-8') as fh:
                pending = fh.read().strip()
            os.unlink(CODE_FILE)
            if pending:
                send(pending, '2FA code (%d digits)' % len(pending))
                sent['code'] = True
                waiting_announced = False
                buf = ''
        if r:
            try:
                data = os.read(fd, 4096)
            except OSError:                          # EIO on child exit
                break
            if not data:
                break
            text = data.decode('utf-8', 'replace')
            with open(LOG, 'a', encoding='utf-8') as fh:
                fh.write(text)
            sys.stdout.write(text)
            sys.stdout.flush()
            buf = (buf + text)[-4000:]
            low = buf.lower()

            if not sent['password'] and 'password' in low:
                send(password, 'password')
                sent['password'] = True
                buf = ''
            elif not sent['code'] and re.search(r'code|verification|two.?factor|2fa', low):
                if not waiting_announced:
                    note('WAITING FOR 2FA CODE -> write it to %s' % CODE_FILE)
                    waiting_announced = True
                code = ''
                if os.path.exists(CODE_FILE):
                    with open(CODE_FILE, 'r', encoding='utf-8') as fh:
                        code = fh.read().strip()
                    os.unlink(CODE_FILE)
                if code:
                    send(code, '2FA code (%d digits)' % len(code))
                    sent['code'] = True
                    waiting_announced = False
                    buf = ''
                elif time.time() > CODE_WAIT:
                    note('no 2FA code supplied within the window')
                    os.kill(pid, 9)
                    return 1

    _, status = os.waitpid(pid, 0)
    code = os.waitstatus_to_exitcode(status) if hasattr(os, 'waitstatus_to_exitcode') else status
    note('plumesign exited with %s' % code)
    note('exit 0 = session cached in accounts.json; login is now reusable')
    return 0 if code == 0 else 3


if __name__ == '__main__':
    sys.exit(main())
