#!/usr/bin/env bash
# Bring up every channel to the iPad, idempotently. Safe to re-run at any time.
#
#   ./tools/ipad-up.sh          bring everything up, report what is live
#   ./tools/ipad-up.sh --status just report, change nothing
#
# What it starts, and why each is needed:
#
#   usbmuxd          the USB multiplexer. Everything below rides on it.
#   RSD tunnel       iOS 17+ moved developer services behind RemoteServiceDiscovery.
#                    Needs root. Without it: no screenshots, no XCUITest.
#   DeveloperDiskImage  personalised image fetched from Apple, mounted on the device.
#                    Screenshots work WITHOUT it; XCUITest does NOT. Lost on device reboot.
#   iproxy 2222->22  SSH over USB. usbmuxd has no Wi-Fi support on Linux, so there is no
#                    "just ssh to its IP" option while on USB.
#   WebDriverAgent   the XCUITest runner that provides tap/swipe/type. Needs
#                    "Settings > Developer > Enable UI Automation" ON, once, on the device.
#
# AFTER AN IPAD REBOOT the jailbreak is gone until Dopamine is opened and Jailbreak
# tapped. SSH will not come back before that -- sshd lives in /var/jb, which does not
# exist until the jailbreak is applied.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WDA_BUNDLE="com.facebook.WebDriverAgentRunner.xctrunner.QQ52XUYS37"
SSH_PORT=2222
STATUS_ONLY=0
[ "${1:-}" = "--status" ] && STATUS_ONLY=1

ok()   { printf '  \033[32m✔\033[0m %-22s %s\n' "$1" "${2:-}"; }
bad()  { printf '  \033[31m✘\033[0m %-22s %s\n' "$1" "${2:-}"; }
warn() { printf '  \033[33m!\033[0m %-22s %s\n' "$1" "${2:-}"; }

# Match on the full command line but never on this script's own pid, or the check
# matches itself and reports a phantom success.
running() { pgrep -f "$1" 2>/dev/null | grep -qv "^$$\$"; }

echo "── iPad channels ──────────────────────────────────────"

# 1. usbmuxd ----------------------------------------------------------------
if pgrep -x usbmuxd >/dev/null; then
  ok "usbmuxd" "pid $(pgrep -x usbmuxd | head -1)"
else
  bad "usbmuxd" "not running -- sudo sv up usbmuxd"
  exit 1
fi

# 2. device -----------------------------------------------------------------
UDID="$(idevice_id -l 2>/dev/null | head -1)"
if [ -z "$UDID" ]; then
  bad "device" "not attached (plug in over USB, unlock)"
  exit 1
fi
ok "device" "$UDID"

# 3. RSD tunnel -------------------------------------------------------------
TUNNEL_JSON="$(curl -s -m 3 http://127.0.0.1:49151/ 2>/dev/null)"
if echo "$TUNNEL_JSON" | grep -q tunnel-address; then
  ok "RSD tunnel" "tunneld up"
elif [ "$STATUS_ONLY" = 1 ]; then
  bad "RSD tunnel" "not running"
else
  PWD_VAL="$(sed -n 's/^\(export \)\?SUDO_PWD=//p' ~/.secrets | tr -d '"'"'"'' | head -1)"
  PMD="$(command -v pymobiledevice3)"
  if [ -n "$PWD_VAL" ] && [ -n "$PMD" ]; then
    printf '%s\n' "$PWD_VAL" | sudo -S -p '' nohup "$PMD" remote tunneld \
      >/tmp/ipad-tunneld.log 2>&1 &
    sleep 12
    if curl -s -m 3 http://127.0.0.1:49151/ | grep -q tunnel-address; then
      ok "RSD tunnel" "started"
    else
      bad "RSD tunnel" "failed -- see /tmp/ipad-tunneld.log"
    fi
  else
    bad "RSD tunnel" "need SUDO_PWD in ~/.secrets, or run: sudo pymobiledevice3 remote tunneld"
  fi
fi

# 4. DeveloperDiskImage -----------------------------------------------------
if pymobiledevice3 mounter list 2>/dev/null | grep -q Developer; then
  ok "DeveloperDiskImage" "mounted"
elif [ "$STATUS_ONLY" = 1 ]; then
  bad "DeveloperDiskImage" "not mounted"
else
  if pymobiledevice3 mounter auto-mount >/tmp/ipad-ddi.log 2>&1; then
    ok "DeveloperDiskImage" "mounted"
  else
    grep -qi "already mounted" /tmp/ipad-ddi.log \
      && ok "DeveloperDiskImage" "already mounted" \
      || bad "DeveloperDiskImage" "failed -- see /tmp/ipad-ddi.log"
  fi
fi

# 5. SSH port-forward -------------------------------------------------------
if ss -lnt 2>/dev/null | grep -q ":$SSH_PORT "; then
  ok "iproxy $SSH_PORT->22" "listening"
elif [ "$STATUS_ONLY" = 1 ]; then
  bad "iproxy $SSH_PORT->22" "not listening"
else
  nohup iproxy "$SSH_PORT" 22 >/tmp/ipad-iproxy.log 2>&1 &
  sleep 2
  ss -lnt 2>/dev/null | grep -q ":$SSH_PORT " \
    && ok "iproxy $SSH_PORT->22" "started" || bad "iproxy $SSH_PORT->22" "failed"
fi

# 6. SSH reachability -------------------------------------------------------
# Proves the jailbreak is actually applied: no /var/jb, no sshd.
if timeout 12 ssh -i ~/.ssh/id_ed25519_ipad -o StrictHostKeyChecking=no \
     -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes \
     -o ConnectTimeout=6 -p "$SSH_PORT" mobile@127.0.0.1 true 2>/dev/null; then
  ok "ssh mobile@ipad" "key auth ok"
else
  warn "ssh mobile@ipad" "unreachable -- is the jailbreak applied? (open Dopamine > Jailbreak)"
fi

# 7. WebDriverAgent ---------------------------------------------------------
if timeout 15 pymobiledevice3 developer wda status 2>/dev/null | grep -q '"ready": true'; then
  ok "WebDriverAgent" "ready"
elif [ "$STATUS_ONLY" = 1 ]; then
  bad "WebDriverAgent" "not running"
else
  nohup pymobiledevice3 developer dvt xcuitest "$WDA_BUNDLE" >/tmp/ipad-wda.log 2>&1 &
  sleep 18
  if timeout 15 pymobiledevice3 developer wda status 2>/dev/null | grep -q '"ready": true'; then
    ok "WebDriverAgent" "started"
  elif grep -qi 'initializationForUITestingDidFail' /tmp/ipad-wda.log; then
    bad "WebDriverAgent" "enable Settings > Developer > Enable UI Automation"
  else
    bad "WebDriverAgent" "failed -- see /tmp/ipad-wda.log"
  fi
fi

echo
echo "  screenshot : ./tools/ipad-shot.sh [out.png]"
echo "  control    : ./tools/ipad-ctl.sh tap|type|swipe|press|launch|items"
echo "  shell      : ./tools/ipad-ssh.sh [--root] '<cmd>'"
echo "  re-sign    : ./resign.sh            (cert expires 2026-09-22)"
