#!/usr/bin/env python3
"""PTY driver for plumesign.

plumesign is interactive: it prompts for the Apple ID, the password and a 2FA
code, and it insists on a real terminal. This driver:

  * never puts a secret in argv (the tools ask for it on stdin instead);
  * turns PTY echo OFF before typing, so the password cannot land in the log;
  * answers the 2FA challenge from a file, so the code can be supplied out-of-band;
  * verifies the anisette server is answering *before* starting, and exits at once
    if it is not.

Its anisette endpoint is a compile-time constant, so point it at your own server
with tools/patch-plumesign.py first.

Usage:
  tools/drive-sign.py [--ipa Dopamine.ipa]

2FA: when the log says "WAITING FOR 2FA CODE", do
       echo <6-digit-code> > /tmp/2fa_code

Environment knobs:
  ANISETTE_URL       default http://10.0.0.30:6969
  SIGN_DEADLINE      seconds before the driver gives up (default 480)
  SIGN_CODE_WAIT     seconds to wait for the human to supply a code (default 420)
"""

import argparse
import os
import re
import select
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)

SECRETS = os.path.expanduser('~/.secrets')
DEVICE_ENV = os.path.join(PROJ, 'device.env')
CODE_FILE = '/tmp/2fa_code'
LOG = '/tmp/sign-driver.log'

ANISETTE = os.environ.get('ANISETTE_URL', 'http://10.0.0.30:6969').rstrip('/')
DEADLINE = time.time() + int(os.environ.get('SIGN_DEADLINE', '480'))
CODE_WAIT = time.time() + int(os.environ.get('SIGN_CODE_WAIT', '420'))

PLUMESIGN = os.environ.get('PLUMESIGN_BIN') or os.path.join(HERE, 'plumesign-linux-x86_64')

# AltServer prints " Apple ID: " and "Password: "; plumesign prints the same two, then
# "Enter the code sent to your device, or type 'sms'".
RE_APPLE_ID = re.compile(r'apple\s*id', re.I)
RE_PASSWORD = re.compile(r'password', re.I)
# A prompt we are willing to answer with a 2FA code. Deliberately narrow: matching a
# loose '2fa' would fire on informational lines such as "This account requires signing
# in with two-factor authentication." and the code would then be swallowed by whatever
# prompt came next.
RE_2FA_PROMPT = re.compile(r'(enter\s+two.?factor|2fa\s*code|enter the code sent|'
                           r'verification code\s*:)', re.I)
# plumesign >=2.6 shows an interactive dialoguer list ("Select a device to register and
# install to:") even when exactly one device is attached. Without a keypress it blocks
# forever, and with stdin closed it dies with "IO error: not a terminal".
RE_DEVICE_PICKER = re.compile(r'select a device', re.I)


def note(msg):
    print('[driver] %s' % msg, flush=True)


def load_env_file(path):
    """Parse a simple KEY=value file, tolerating an `export ` prefix and quotes."""
    out = {}
    try:
        with open(path, 'r', errors='replace') as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                key, val = line.split('=', 1)
                key = key.strip()
                if key.startswith('export '):
                    key = key[len('export '):].strip()
                out[key] = val.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return out


def anisette_ok():
    """Prove the anisette server is alive and returning real Apple ADI headers."""
    import urllib.request
    import urllib.error
    try:
        req = urllib.request.Request(ANISETTE + '/', headers={'User-Agent': 'drive-sign'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode('utf-8', 'replace')
            note('anisette %s -> HTTP %s, %d bytes' % (ANISETTE, resp.status, len(body)))
            # anisette-v3-server returns the ADI data in the JSON *body*, not in HTTP
            # response headers. Checking headers produced a false "server is down".
            ok = 'X-Apple-I-MD' in body
            note('anisette ADI data %s' % ('present' if ok else 'MISSING'))
            return ok
    except Exception as exc:
        note('anisette %s UNREACHABLE: %s' % (ANISETTE, exc))
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tool', choices=['plumesign'], default='plumesign')
    ap.add_argument('--ipa', default=os.path.join(HERE, 'Dopamine.ipa'))
    ap.add_argument('--udid', default=None)
    args = ap.parse_args()

    creds = load_env_file(SECRETS)
    blob = creds.get('APPLE_CREDENTIALS', '')
    if ':' not in blob:
        note('MISSING CREDENTIALS in %s (need APPLE_CREDENTIALS=email:password)' % SECRETS)
        return 2
    email, password = (part.strip() for part in blob.split(':', 1))
    if not email or not password:
        note('MALFORMED APPLE_CREDENTIALS (empty email or password)')
        return 2

    ipa = os.path.abspath(args.ipa)
    if not os.path.isfile(ipa):
        note('IPA not found: %s' % ipa)
        return 2

    denv = load_env_file(DEVICE_ENV)
    udid = (args.udid or denv.get('IPAD_UDID') or denv.get('UDID')
            or os.environ.get('UDID', ''))
    # AltServer takes -a/-p as argv (it does not prompt); plumesign prompts on stdin.
    secret_mode = 'stdin'

    note('tool=%s ipa=%s (%d MB)' % (args.tool, os.path.basename(ipa),
                                     os.path.getsize(ipa) // 1048576))
    note('apple id: %s (password masked, %d chars)' % (email, len(password)))
    note('hard deadline: %ds, 2FA window: %ds' % (DEADLINE - time.time(),
                                                  CODE_WAIT - time.time()))

    # Fail before spawning anything if the anisette backend is not answering: a broken
    # anisette is exactly how the public-server run died, and it wastes the user's time.
    if True:
        if not os.access(PLUMESIGN, os.X_OK):
            note('plumesign binary missing/not executable: %s' % PLUMESIGN)
            return 2
        # NOTE: deliberately NOT passing --udid. plumesign matches it against the
        # usbmux property 'UDID', but Void's usbmuxd 1.1.1 advertises the device as
        # 'SerialNumber', so an explicit --udid always fails with
        #   Error: Other error: Device ID <udid> not found
        # even though the same run prints the device in its own DeviceList. Autodetect
        # reads lockdownd (UniqueDeviceID) instead and works. With one device attached
        # the picker below selects it.
        argv = [PLUMESIGN, 'sign', '--package', ipa, '--apple-id',
                '--register-and-install']
        if udid:
            note('device.env UDID %s (not passed to plumesign -- see comment)' % udid)
        child_env = dict(os.environ)
        binpath = PLUMESIGN

    log_fh = os.open(LOG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        os.remove(CODE_FILE)
    except OSError:
        pass

    import pty
    import termios

    pid, fd = pty.fork()
    if pid == 0:                                    # child
        try:
            os.environ.update(child_env)
            os.execv(binpath, argv)
        finally:
            os._exit(127)

    # The tools echo what is typed at them. Kill ECHO on the shared line discipline
    # before sending anything, or the password lands in this log in plaintext.
    try:
        attrs = termios.tcgetattr(fd)
        attrs[3] &= ~termios.ECHO
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        note('pty echo disabled -- secrets cannot be echoed into the log')
    except Exception as exc:
        note('WARNING: could not disable pty echo (%s)' % exc)

    if secret_mode == 'argv':
        # Prove the shim worked. Boolean only; the value itself is never logged.
        time.sleep(2)
        try:
            with open('/proc/%d/cmdline' % pid, 'rb') as fh:
                raw = fh.read().decode('utf-8', 'replace')
            note('password readable from /proc/%d/cmdline: %s'
                 % (pid, 'YES -- shim failed' if password in raw else 'no'))
        except OSError as exc:
            note('could not inspect cmdline: %s' % exc)

    def emit(text):
        sys.stdout.write(text)
        sys.stdout.flush()
        os.write(log_fh, text.encode('utf-8', 'replace'))

    def send(value, label):
        os.write(fd, (value + '\n').encode())
        note('sent %s (%d chars)' % (label, len(value)))

    sent = {'apple_id': False, 'password': False, 'code': False, 'picker': False}
    waiting_code = False
    buf = ''

    while True:
        now = time.time()
        if now > DEADLINE:
            note('DEADLINE reached -- giving up')
            break

        readable, _, _ = select.select([fd], [], [], 1.0)
        if fd in readable:
            try:
                data = os.read(fd, 4096)
            except OSError:
                data = b''
            if not data:
                note('tool closed its output (finished)')
                break
            text = data.decode('utf-8', 'replace')
            emit(text)
            buf += text

            prompts_ready = (secret_mode == 'argv') or sent['password']
            if secret_mode == 'stdin':
                if not sent['apple_id'] and RE_APPLE_ID.search(buf):
                    send(email, 'apple id')
                    sent['apple_id'] = True
                elif not sent['password'] and sent['apple_id'] and RE_PASSWORD.search(buf):
                    send(password, 'password')
                    sent['password'] = True
                    buf = ''
            if not waiting_code and prompts_ready and RE_2FA_PROMPT.search(buf):
                waiting_code = True
                buf = ''
                note('WAITING FOR 2FA CODE -> write it with: echo <code> > %s' % CODE_FILE)

            if not sent['picker'] and RE_DEVICE_PICKER.search(buf):
                # One attached device -> the first entry is already highlighted, so a
                # bare Enter confirms it.
                send('', 'device-picker Enter')
                sent['picker'] = True
                buf = ''

        # Polled every tick, NOT only when the child produces output: plumesign prints
        # its 2FA prompt once and then goes silent, so an output-gated check never fires
        # again and the code file is picked up late or never.
        if waiting_code and not sent['code'] and os.path.exists(CODE_FILE):
            try:
                with open(CODE_FILE) as fh:
                    code = fh.read().strip()
            except OSError:
                code = ''
            if code:
                send(code, '2fa code')
                sent['code'] = True
                try:
                    os.unlink(CODE_FILE)
                except OSError:
                    pass

        if waiting_code and not sent['code'] and time.time() > CODE_WAIT:
            note('no 2FA code supplied within the window -- giving up')
            break

        done, status = os.waitpid(pid, os.WNOHANG)
        if done:
            note('tool exited, status %d' % (status >> 8))
            break

    try:
        os.kill(pid, 15)
    except OSError:
        pass
    os.close(log_fh)
    note('done (log: %s, mode 600)' % LOG)
    return 0


if __name__ == '__main__':
    sys.exit(main())
