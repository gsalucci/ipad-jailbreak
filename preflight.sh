#!/usr/bin/env bash
# preflight.sh — verify x570 can actually talk to an iPad and sign/install Dopamine.
# Read-mostly. Never modifies the device. Safe to run with or without the iPad attached.
#
#   ./preflight.sh            # full check
#   ./preflight.sh --json     # machine-readable
#   ./preflight.sh --fix      # print the exact remediation commands for failures
#
# Exit codes: 0 = all critical checks pass, 1 = at least one FAIL, 2 = bad usage.

set -u -o pipefail

JSON=0
FIX=0
for a in "$@"; do
  case "$a" in
    --json) JSON=1 ;;
    --fix)  FIX=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

# ---------- reporting ----------
FAILS=0; WARNS=0; SKIPS=0
declare -a RESULTS=()
declare -a REMEDIES=()

c() { # c <color-name>
  if [ "$JSON" = 1 ] || [ ! -t 1 ]; then printf ''; return; fi
  case "$1" in
    ok)   printf '\033[32m' ;; warn) printf '\033[33m' ;;
    bad)  printf '\033[31m' ;; dim)  printf '\033[2m'  ;;
    off)  printf '\033[0m'  ;;
  esac
}

# check <LEVEL> <name> <detail> [remedy]
check() {
  local lvl="$1" name="$2" detail="${3:-}" remedy="${4:-}"
  local col="ok"
  case "$lvl" in
    FAIL) col="bad"; FAILS=$((FAILS+1)); [ -n "$remedy" ] && REMEDIES+=("$name :: $remedy") ;;
    WARN) col="warn"; WARNS=$((WARNS+1)); [ -n "$remedy" ] && REMEDIES+=("$name :: $remedy") ;;
    SKIP) col="dim"; SKIPS=$((SKIPS+1)) ;;
  esac
  if [ "$JSON" = 1 ]; then
    RESULTS+=("{\"level\":\"$lvl\",\"check\":\"$(printf '%s' "$name" | sed 's/"/\\"/g')\",\"detail\":\"$(printf '%s' "$detail" | sed 's/"/\\"/g')\"}")
  else
    c "$col"; printf '%-5s' "$lvl"; c off
    printf ' %-34s ' "$name"
    c dim; printf '%s' "$detail"; c off; printf '\n'
  fi
}

hr() { [ "$JSON" = 1 ] || { c dim; printf '%s\n' "────────────────────────────────────────────────────────────────────"; c off; }; }
sec() { [ "$JSON" = 1 ] || { printf '\n'; c dim; printf '▌ %s\n' "$1"; c off; }; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- header ----------
if [ "$JSON" = 0 ]; then
  printf '\n'
  c dim; printf 'iPad jailbreak preflight — '; c off
  printf '%s\n' "$(date -Iseconds)"
  printf 'host=%s  user=%s  kernel=%s\n' "$(hostname)" "$(id -un)" "$(uname -r)"
fi

# ---------- 1. host platform ----------
sec "1. Host platform"

if [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_ID="${ID:-unknown}"; OS_NAME="${PRETTY_NAME:-unknown}"
else
  OS_ID=unknown; OS_NAME="unknown (no /etc/os-release)"
fi
if [ "$OS_ID" = "void" ]; then
  check PASS "distro" "$OS_NAME"
else
  check WARN "distro" "$OS_NAME" "guide is written for Void/xbps; package commands will differ"
fi

# glibc vs musl — decides AppImage viability
if have ldd; then
  if ldd --version 2>&1 | grep -qi musl; then
    check WARN "libc" "musl" "Impactor AppImage is glibc-linked: use --appimage-extract-and-run inside a glibc env, or the Flatpak (dev.khcrysalis.PlumeImpactor)"
  else
    check PASS "libc" "$(ldd --version 2>&1 | head -1)"
  fi
else
  check SKIP "libc" "ldd not present"
fi

# init system
if [ -d /etc/runit ] && [ -d /var/service ]; then
  check PASS "init" "runit (/etc/sv + /var/service)"
elif [ -d /run/systemd/system ]; then
  check WARN "init" "systemd" "service commands in the guide are runit; translate: systemctl enable --now usbmuxd"
else
  check WARN "init" "unrecognised" "verify how services are enabled on this host"
fi

# package manager
if have xbps-install; then check PASS "package manager" "xbps"; else check WARN "package manager" "no xbps-install" "install deps with your distro's manager"; fi

# sudo / doas
if have sudo; then
  if sudo -n true 2>/dev/null; then
    check PASS "privilege" "sudo (passwordless)"
  else
    check PASS "privilege" "sudo (password required)"
  fi
elif have doas; then
  check PASS "privilege" "doas"
else
  check FAIL "privilege" "neither sudo nor doas" "install sudo or doas; dependency install needs root"
fi

# ---------- 2. USB / device stack ----------
sec "2. Apple USB stack"

for p in usbmuxd libimobiledevice ideviceinstaller; do
  if have xbps-query && xbps-query -p pkgver "$p" >/dev/null 2>&1; then
    check PASS "installed: $p" "$(xbps-query -p pkgver "$p" 2>/dev/null)"
  elif have xbps-query && [ -n "$(xbps-query -R -p pkgver "$p" 2>/dev/null)" ]; then
    check FAIL "installed: $p" "absent (available in repo: $(xbps-query -R -p pkgver "$p" 2>/dev/null))" \
      "sudo xbps-install -Sy usbmuxd libimobiledevice ideviceinstaller"
  else
    check WARN "installed: $p" "cannot determine"
  fi
done

# usbmuxd daemon running?
if have pgrep; then
  if pgrep -x usbmuxd >/dev/null 2>&1; then
    check PASS "usbmuxd running" "pid $(pgrep -x usbmuxd | head -1)"
  else
    check FAIL "usbmuxd running" "not running" \
      "sudo ln -sfn /etc/sv/usbmuxd /var/service/ && sudo sv up usbmuxd"
  fi
fi

# runit service enabled?
if [ -e /var/service/usbmuxd ]; then
  check PASS "usbmuxd service linked" "/var/service/usbmuxd"
elif [ -e /etc/sv/usbmuxd ]; then
  check FAIL "usbmuxd service linked" "/etc/sv/usbmuxd exists but is not linked into /var/service" \
    "sudo ln -sfn /etc/sv/usbmuxd /var/service/ && sudo sv up usbmuxd"
else
  check FAIL "usbmuxd service" "/etc/sv/usbmuxd missing" "reinstall usbmuxd package"
fi

if have sv; then
  S=$(sv status usbmuxd 2>&1 | head -1)
  case "$S" in
    *"run:"*) check PASS "sv status usbmuxd" "$S" ;;
    *"access denied"*)
        # runit supervise dirs are root-only; retry unprivileged-passwordless, else infer.
        if sudo -n sv status usbmuxd >/dev/null 2>&1; then
          S2=$(sudo -n sv status usbmuxd 2>&1 | head -1)
          case "$S2" in
            *"run:"*) check PASS "sv status usbmuxd" "$S2 (via sudo)" ;;
            *)        check FAIL "sv status usbmuxd" "$S2" "sudo sv up usbmuxd" ;;
          esac
        elif pgrep -x usbmuxd >/dev/null 2>&1; then
          check PASS "sv status usbmuxd" "running (pid $(pgrep -x usbmuxd | head -1)); 'sv status' needs root to read the supervise dir"
        else
          check FAIL "sv status usbmuxd" "access denied and no usbmuxd process" "sudo sv up usbmuxd"
        fi ;;
    "")       check SKIP "sv status usbmuxd" "no output" ;;
    *)        check FAIL "sv status usbmuxd" "$S" "sudo sv up usbmuxd" ;;
  esac
fi

# socket
if [ -S /var/run/usbmuxd ]; then
  check PASS "usbmuxd socket" "$(ls -l /var/run/usbmuxd 2>/dev/null | awk '{print $1, $3":"$4}')"
else
  check FAIL "usbmuxd socket" "/var/run/usbmuxd absent" "start usbmuxd; the socket is created on daemon start"
fi

# udev rules for Apple vendor 05ac
if [ -d /etc/udev/rules.d ]; then
  if grep -rls --include='*.rules' -e '05ac' /etc/udev/rules.d /usr/lib/udev/rules.d 2>/dev/null | head -1 | grep -q .; then
    check PASS "udev apple rules" "05ac rules present"
  else
    check WARN "udev apple rules" "no rule mentioning Apple vendor id 05ac" \
      "usually fine: usbmuxd's own udev rule ships with the package; only add rules if the device is not detected"
  fi
fi

# ---------- 3. Signing / sideload tooling ----------
sec "3. Signing + sideload tooling"

if have libfuse2 2>/dev/null || [ -e /usr/lib/libfuse.so.2 ] || [ -e /usr/lib64/libfuse.so.2 ]; then
  check PASS "libfuse.so.2" "present (AppImages can self-mount)"
else
  check WARN "libfuse.so.2" "absent" \
    "sudo xbps-install -Sy fuse    # or run AppImages with --appimage-extract-and-run"
fi

if [ -e /dev/fuse ]; then check PASS "/dev/fuse" "present"; else check WARN "/dev/fuse" "absent" "load the fuse module, or use --appimage-extract-and-run"; fi

# Impactor artefacts anywhere obvious
FOUND_IMP=""
for d in "$HOME" "$HOME/Downloads" "$HOME/Sources/ipad-jailbreak" /tmp; do
  [ -d "$d" ] || continue
  f=$(find "$d" -maxdepth 2 -iname 'Impactor*linux*x86_64*.appimage' -o -maxdepth 2 -iname 'plumesign-linux*' 2>/dev/null | head -1)
  [ -n "$f" ] && { FOUND_IMP="$f"; break; }
done
if [ -n "$FOUND_IMP" ]; then
  [ -x "$FOUND_IMP" ] && check PASS "Impactor present" "$FOUND_IMP" || check WARN "Impactor not executable" "$FOUND_IMP" "chmod +x '$FOUND_IMP'"
else
  check WARN "Impactor present" "not found on disk" \
    "curl -LO https://github.com/claration/Impactor/releases/latest/download/Impactor-linux-x86_64.appimage && chmod +x Impactor-linux-x86_64.appimage"
fi

if have flatpak; then check PASS "flatpak" "$(flatpak --version 2>/dev/null)"; else check SKIP "flatpak" "not installed (alternate path for AppImage-hostile systems)"; fi

# pymobiledevice3
PMD=""
for cand in pymobiledevice3 "$HOME/.local/bin/pymobiledevice3"; do
  have "$cand" && { PMD="$cand"; break; }
done
if [ -z "$PMD" ] && [ -x "$HOME/.local/bin/pymobiledevice3" ]; then PMD="$HOME/.local/bin/pymobiledevice3"; fi
if [ -n "$PMD" ]; then
  PMDV=$(pipx list --short 2>/dev/null | awk '/^pymobiledevice3/{print $2}')
  [ -z "$PMDV" ] && PMDV="installed"
  check PASS "pymobiledevice3" "$PMDV  [$PMD]"
else
  check WARN "pymobiledevice3" "absent (optional: headless Developer Mode / DDI / pairing)" \
    "pipx install pymobiledevice3"
fi
if have pipx; then check PASS "pipx" "$(pipx --version 2>&1)"; else check WARN "pipx" "absent" "sudo xbps-install -Sy python3-pipx"; fi

# pipx builds some deps (pylzss) from source, which needs Python.h
PYH=$(find /usr/include -maxdepth 3 -name Python.h 2>/dev/null | head -1)
if [ -n "$PYH" ]; then
  check PASS "Python.h" "$PYH"
else
  check WARN "Python.h" "absent — pipx will fail to build pylzss/pyimg4" \
    "sudo xbps-install -Sy python3-devel"
fi

# ---------- 4. Network reachability ----------
sec "4. Network"

probe() { # probe <host> <port>
  if have timeout; then timeout 6 bash -c "cat < /dev/null > /dev/tcp/$1/$2" 2>/dev/null && return 0; fi
  return 1
}
probe github.com 443 && check PASS "github.com:443" "reachable" || check WARN "github.com:443" "unreachable" "Impactor/pymobiledevice3 downloads will fail; check proxy/DNS"
if have curl; then check PASS "curl" "$(curl --version 2>/dev/null | head -1 | cut -d' ' -f1-2)"; else check WARN "curl" "absent" "sudo xbps-install -Sy curl"; fi

# ---------- 5. Device (optional) ----------
sec "5. Attached device (optional)"

if have idevice_id; then
  IDS=$(idevice_id -l 2>/dev/null)
  if [ -n "$IDS" ]; then
    check PASS "device enumerated" "$(printf '%s' "$IDS" | tr '\n' ' ')"
    if have ideviceinfo; then
      for ud in $IDS; do
        PN=$(ideviceinfo -u "$ud" -k ProductType 2>/dev/null)
        PV=$(ideviceinfo -u "$ud" -k ProductVersion 2>/dev/null)
        PNM=$(ideviceinfo -u "$ud" -k ProductName 2>/dev/null)
        if [ -n "$PN" ]; then
          check PASS "device info" "$PNM $PN  iOS/iPadOS $PV  ($ud)"
          case "$PN" in
            iPad11,6|iPad11,7) check PASS "model supported" "iPad 8th gen (A2270/A2428) — A12, supported by Dopamine" ;;
            iPad11,1|iPad11,2) check PASS "model supported" "iPad mini 5 — A12, also supported by Dopamine" ;;
            iPad11,3|iPad11,4) check PASS "model supported" "iPad Air 3 — A12, also supported by Dopamine" ;;
            *) check WARN "model" "$PN" "not an A12 iPad this runbook was written for (iPad 8 = iPad11,6/11,7); verify the Dopamine support matrix" ;;
          esac
          case "${PV:-}" in
            18.5) check PASS "version supported" "18.5 within Dopamine range 15.0–18.7.1" ;;
            1[5-8].*|26.0*) check PASS "version in range" "$PV" ;;
            "")  check SKIP "version" "could not read (device locked?)" ;;
            *)   check WARN "version" "$PV" "verify against Dopamine support matrix (15.0–18.7.1, 26.0–26.0.1)" ;;
          esac
        else
          check WARN "device info" "could not query $ud" "unlock the iPad and accept the Trust prompt"
        fi
      done
    fi
    if have idevicepair; then
      PR=$(idevicepair -u "${IDS%%$'\n'*}" validate 2>&1)
      case "$PR" in
        *SUCCESS*) check PASS "pairing" "$PR" ;;
        *) check WARN "pairing" "$PR" "unlock the iPad, tap Trust; or: pymobiledevice3 lockdown pair" ;;
      esac
    fi
  else
    check SKIP "device enumerated" "no device on the USB bus (attach the iPad to run this section)"
  fi
else
  check SKIP "device enumerated" "idevice_id absent (install libimobiledevice)"
fi

if [ -n "$PMD" ]; then
  # NB: do not truncate this with head -3 — "Identifier" is not in the first lines of the JSON.
  out=$($PMD usbmux list 2>&1)
  if printf '%s' "$out" | grep -qiE 'Identifier|UniqueDeviceID'; then
    check PASS "pymobiledevice3 usbmux" "device visible"
  else
    check SKIP "pymobiledevice3 usbmux" "no device visible"
  fi
fi

# ---------- 6. Disk ----------
sec "6. Resources"
if have df; then
  AVAIL=$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{printf "%.1f", $4/1048576}')
  if [ -n "${AVAIL:-}" ] && awk -v a="$AVAIL" 'BEGIN{exit !(a>=2)}'; then
    check PASS "disk (home)" "${AVAIL} GiB free"
  else
    check WARN "disk (home)" "${AVAIL:-?} GiB free" "Impactor + IPAs need a few hundred MB; 2 GiB headroom recommended"
  fi
fi

# ---------- summary ----------
hr
if [ "$JSON" = 1 ]; then
  printf '{"host":"%s","kernel":"%s","fails":%d,"warns":%d,"skips":%d,"checks":[%s]}\n' \
    "$(hostname)" "$(uname -r)" "$FAILS" "$WARNS" "$SKIPS" "$(IFS=,; echo "${RESULTS[*]}")"
else
  printf 'FAIL: %d   WARN: %d   SKIP: %d\n' "$FAILS" "$WARNS" "$SKIPS"
  if [ "$FAILS" -eq 0 ]; then
    c ok; printf '\n✔ No blocking problems. Ready to proceed.\n'; c off
  else
    c bad; printf '\n✘ Blocking problems found.\n'; c off
    printf '\nRemediation:\n'
    for r in "${REMEDIES[@]}"; do printf '  • %s\n' "$r"; done
  fi
  if [ "$FIX" = 1 ] && [ "${#REMEDIES[@]}" -gt 0 ]; then
    printf '\n--fix commands:\n'
    for r in "${REMEDIES[@]}"; do printf '  %s\n' "${r#* :: }"; done
  fi
  printf '\nRe-run after fixing. Device section is SKIP-safe until the iPad is attached.\n\n'
fi

[ "$FAILS" -eq 0 ] && exit 0 || exit 1
