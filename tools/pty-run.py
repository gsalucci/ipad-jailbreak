#!/usr/bin/env python3
"""Run a plumesign command under a PTY, auto-answering its interactive device picker.

plumesign uses dialoguer for device selection and prints

    Select a device to register and install to:
    > [USB] <device name>

even when exactly one device is attached. With stdin closed it dies with
"IO error: not a terminal"; with stdin open but unattended it blocks forever. Both make
it unusable from a script. This wrapper gives it a real PTY and presses Enter on the
already-highlighted first entry.

    python3 tools/pty-run.py -- ./tools/plumesign-local device --pairing ...

Exits with the child's exit status. Not for `account login` -- that needs 2FA handling,
which tools/apple-login.py does.
"""
import os
import pty
import re
import select
import sys
import termios
import time

RE_PICKER = re.compile(r'select a device', re.I)
TIMEOUT = int(os.environ.get('PTY_RUN_TIMEOUT', '300'))


def main():
    argv = sys.argv[1:]
    if argv and argv[0] == '--':
        argv = argv[1:]
    if not argv:
        sys.exit('usage: pty-run.py -- <command> [args...]')

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(argv[0], argv)
        os._exit(127)

    # dialoguer redraws its list with ANSI cursor moves; echoing our keypress back would
    # corrupt the captured output for no benefit.
    try:
        attrs = termios.tcgetattr(fd)
        attrs[3] &= ~termios.ECHO
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
    except Exception:
        pass

    answered = False
    buf = ''
    deadline = time.time() + TIMEOUT

    while True:
        if time.time() > deadline:
            print('\n[pty-run] timeout after %ds -- killing child' % TIMEOUT)
            os.kill(pid, 9)
            os.waitpid(pid, 0)
            return 124
        try:
            r, _, _ = select.select([fd], [], [], 1.0)
        except OSError:
            break
        if fd in r:
            try:
                data = os.read(fd, 4096)
            except OSError:      # EIO when the child exits
                break
            if not data:
                break
            text = data.decode('utf-8', 'replace')
            sys.stdout.write(text)
            sys.stdout.flush()
            buf += text
            if not answered and RE_PICKER.search(buf):
                os.write(fd, b'\n')
                print('\n[pty-run] device picker: sent Enter (first entry)')
                answered = True
                buf = ''
        done, status = os.waitpid(pid, os.WNOHANG)
        if done:
            return os.waitstatus_to_exitcode(status)

    _, status = os.waitpid(pid, 0)
    return os.waitstatus_to_exitcode(status)


if __name__ == '__main__':
    sys.exit(main())
