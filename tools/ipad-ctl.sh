#!/usr/bin/env bash
# Drive the iPad: screenshots, taps, swipes, typing, hardware buttons.
#
# Layers, from least to most setup:
#   shot                  screenshot only -- needs the RSD tunnel + mounted DDI
#   tap/swipe/type/press  needs WebDriverAgent running (see 'wda-start')
#
# One-time per host boot:
#   sudo pymobiledevice3 remote tunneld &     # RSD tunnel (iOS 17+)
#   pymobiledevice3 mounter auto-mount        # DeveloperDiskImage
#
# One-time on the device:
#   Settings > Developer > Enable UI Automation
#   (without it XCUITest dies with initializationForUITestingDidFailWithError)
#
# Usage:
#   ./tools/ipad-ctl.sh shot [out.png]
#   ./tools/ipad-ctl.sh wda-start           # launches the XCUITest runner (stays running)
#   ./tools/ipad-ctl.sh wda-status
#   ./tools/ipad-ctl.sh items               # list tappable elements
#   ./tools/ipad-ctl.sh tap <selector>
#   ./tools/ipad-ctl.sh swipe <x1> <y1> <x2> <y2>
#   ./tools/ipad-ctl.sh type <text>
#   ./tools/ipad-ctl.sh press <home|lock|volumeup|volumedown>
#   ./tools/ipad-ctl.sh launch <bundle-id>
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WDA_BUNDLE="com.facebook.WebDriverAgentRunner.xctrunner.QQ52XUYS37"
LOG=/tmp/ipad-wda.log

cmd="${1:-help}"; shift || true

case "$cmd" in
  shot)     exec "$HERE/tools/ipad-shot.sh" "$@" ;;
  wda-start)
      nohup pymobiledevice3 developer dvt xcuitest "$WDA_BUNDLE" > "$LOG" 2>&1 &
      echo "xcuitest pid $! (log: $LOG)"
      ;;
  wda-status) pymobiledevice3 developer wda status ;;
  items)      pymobiledevice3 developer wda list-items ;;
  tap)        pymobiledevice3 developer wda tap "$@" ;;
  swipe)      pymobiledevice3 developer wda swipe "$@" ;;
  type)       pymobiledevice3 developer wda type "$@" ;;
  press)      pymobiledevice3 developer wda press "$@" ;;
  unlock)     pymobiledevice3 developer wda unlock ;;
  launch)     pymobiledevice3 developer wda launch "$@" ;;
  *) sed -n '2,26p' "$0" ;;
esac
