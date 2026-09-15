#!/usr/bin/env bash
# Re-sign and reinstall Dopamine on the iPad. Run this before the certificate expires.
#
# Free Apple ID certificates last 7 days. When one expires the Dopamine icon dims and
# will not launch -- and since the jailbreak is semi-untethered, a device that reboots
# after that point cannot be re-jailbroken until the app is signed again.
#
#   ./resign.sh                 re-sign tools/Dopamine.ipa
#   ./resign.sh path/to.ipa     re-sign something else (e.g. SideStore.ipa)
#
# No 2FA prompt: the Apple session is cached in plumesign's accounts.json by
# tools/apple-login.py. If Apple has invalidated it, this exits non-zero telling you to
# re-run the login -- have the iPad nearby for the code.
set -uo pipefail

# Host-specific values live in .env (see .env.example); it is gitignored.
[ -f "$(dirname "$0")/.env" ] && . "$(dirname "$0")/.env"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IPA="${1:-$HERE/tools/Dopamine.ipa}"
PLUMESIGN="$HERE/tools/plumesign-local"
ANISETTE_PROBE="${ANISETTE_URL:?ANISETTE_URL not set -- copy .env.example to .env}/v3/client_info"

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
info() { printf '  %-22s %s\n' "$1" "$2"; }

fail() { red "FAIL: $*"; exit 1; }

echo "── preflight ──────────────────────────────────────────"

[ -f "$IPA" ] || fail "IPA not found: $IPA"
info "ipa" "$(basename "$IPA") ($(( $(stat -c%s "$IPA") / 1048576 )) MB)"

# The patched binary is a build artefact, not checked-in state -- rebuild if absent.
if [ ! -x "$PLUMESIGN" ]; then
  echo "  plumesign-local missing, rebuilding from stock binary..."
  python3 "$HERE/tools/patch-plumesign.py" || fail "could not build plumesign-local"
fi
info "signer" "$(basename "$PLUMESIGN")"

pgrep -x usbmuxd >/dev/null || fail "usbmuxd is not running (sudo sv up usbmuxd)"
info "usbmuxd" "running"

# The device drops off usbmux briefly during a respring/userspace reboot, and lockdownd
# refuses connections while the screen is locked. Both are transient, so retry rather
# than failing a re-sign that would have worked five seconds later.
UDID=""
for _ in 1 2 3 4 5 6; do
  UDID="$(idevice_id -l 2>/dev/null | head -1)"
  [ -n "$UDID" ] && break
  sleep 2
done
[ -n "$UDID" ] || fail "no iPad detected over USB -- plug it in and unlock it"
info "device" "$UDID"

PAIRED=no
for _ in 1 2 3 4 5 6; do
  if idevicepair -u "$UDID" validate >/dev/null 2>&1; then PAIRED=yes; break; fi
  sleep 2
done
[ "$PAIRED" = yes ] || fail "device not paired/trusted -- unlock the iPad and tap Trust"
info "pairing" "validated"

# The anisette server is consulted on every Apple API call. If it is down the sign fails
# halfway through, which is a worse place to discover it.
CODE="$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$ANISETTE_PROBE" || true)"
[ "$CODE" = "200" ] || fail "anisette unreachable ($ANISETTE_PROBE -> HTTP $CODE)"
info "anisette" "HTTP 200"

ACCOUNTS="$("$PLUMESIGN" account list 2>&1 | grep -c 'selected' || true)"
[ "$ACCOUNTS" -ge 1 ] || fail "no Apple account cached -- run: python3 tools/apple-login.py"
info "apple account" "cached session"

# Verify the app we actually signed, not a hardcoded one: resign.sh takes an IPA
# argument, so checking for "dopamine" would report success after a failed SideStore run.
BUNDLE_ID="$(python3 - "$IPA" <<'PY'
import plistlib, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
n = [i for i in z.namelist()
     if i.startswith('Payload/') and i.count('/') == 2 and i.endswith('Info.plist')]
print(plistlib.loads(z.read(n[0])).get('CFBundleIdentifier', '') if n else '')
PY
)"
[ -n "$BUNDLE_ID" ] || fail "could not read CFBundleIdentifier from $IPA"
info "bundle id" "$BUNDLE_ID"

echo
echo "── signing + installing ───────────────────────────────"

# PIPESTATUS, not $?: the grep filter downstream would otherwise mask a signer failure.
PLUMESIGN_BIN="$PLUMESIGN" python3 "$HERE/tools/drive-sign.py" \
  --tool plumesign --ipa "$IPA" 2>&1 \
  | grep -viE 'DEBUG|goblin|hyper_util|reqwest::connect|tungstenite'
SIGN_RC=${PIPESTATUS[0]}

echo
[ "$SIGN_RC" -eq 0 ] || fail "signer exited $SIGN_RC"

# The driver exits 0 even when plumesign itself errored, so confirm against the device:
# free-tier installs are suffixed with the team id, hence the prefix match.
if ideviceinstaller -l -o list_user 2>/dev/null | grep -q "$BUNDLE_ID"; then
  grn "✔ $BUNDLE_ID present on the device."
  echo "  Certificate valid 7 days -- next re-sign due $(date -d '+7 days' +%Y-%m-%d)."
  echo "  After a full reboot: open Dopamine and tap Jailbreak to re-apply the exploit."
else
  red "FAIL: $BUNDLE_ID is not in the installed-app list -- the install did not take."
  red "      Scroll up for the signer's error."
  exit 1
fi
