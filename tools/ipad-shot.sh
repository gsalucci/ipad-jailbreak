#!/usr/bin/env bash
# Capture the iPad screen to a PNG (default: /tmp/ipad.png), downscaled for quick viewing.
#
# Requires a running RSD tunnel (iOS 17+):
#   sudo pymobiledevice3 remote tunneld &
# The DeveloperDiskImage must be mounted once per boot:
#   pymobiledevice3 mounter auto-mount
set -euo pipefail
OUT="${1:-/tmp/ipad.png}"
WIDTH="${2:-540}"
RAW="$(mktemp /tmp/ipad-raw-XXXX.png)"
trap 'rm -f "$RAW"' EXIT
pymobiledevice3 developer dvt screenshot "$RAW" >/dev/null 2>&1
ffmpeg -loglevel error -y -i "$RAW" -vf "scale=${WIDTH}:-1" "$OUT"
echo "$OUT ($(stat -c%s "$OUT") bytes)"
