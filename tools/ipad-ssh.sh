#!/usr/bin/env bash
# Run a command on the jailbroken iPad over SSH (USB, via usbmuxd).
#
#   ./tools/ipad-ssh.sh 'uname -a'            # as mobile
#   ./tools/ipad-ssh.sh --root 'id'           # as root (sudo, password from ~/.secrets)
#   ./tools/ipad-ssh.sh                       # interactive shell
#
# Setup that already happened (documented so it can be redone):
#   * openssh-server installed from Sileo (Procursus)
#   * ~/.ssh/id_ed25519_ipad installed into the DEVICE's $HOME/.ssh/authorized_keys
#   * NOTE: rootless jailbreak => $HOME is /var/jb/var/mobile, NOT /var/mobile.
#     Writing the key to /var/mobile/.ssh silently does nothing.
#   * The password Dopamine asks for during jailbreak is the *mobile* user's
#     ("Cambia password 'mobile'" in its settings), not root's. It is IPAD_ROOT_PWD
#     in ~/.secrets -- the name is a misnomer kept for compatibility.
set -uo pipefail

PORT=2222
KEY=~/.ssh/id_ed25519_ipad
JBPATH='/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin'

# usbmuxd gives no Wi-Fi on Linux, so everything rides a USB port-forward.
if ! ss -lnt 2>/dev/null | grep -q ":$PORT "; then
  nohup iproxy "$PORT" 22 >/tmp/ipad-iproxy.log 2>&1 &
  sleep 2
fi

SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o LogLevel=ERROR -o BatchMode=yes -p "$PORT" mobile@127.0.0.1)

if [ "${1:-}" = "--root" ]; then
  shift
  PWD_VAL="$(sed -n 's/^\(export \)\?IPAD_ROOT_PWD=//p' ~/.secrets | tr -d '"'"'"'' | head -1)"
  [ -n "$PWD_VAL" ] || { echo "IPAD_ROOT_PWD not found in ~/.secrets" >&2; exit 2; }
  # -S reads the password from stdin: it never appears in argv or in ps output.
  printf '%s\n' "$PWD_VAL" | "${SSH[@]}" "PATH=$JBPATH; sudo -S -p '' $*"
elif [ $# -eq 0 ]; then
  exec ssh -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o LogLevel=ERROR -p "$PORT" mobile@127.0.0.1
else
  "${SSH[@]}" "PATH=$JBPATH; $*"
fi
