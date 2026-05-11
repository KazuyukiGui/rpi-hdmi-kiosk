#!/usr/bin/env bash
set -euo pipefail

URL="${KIOSK_URL:-https://example.com}"

exec cage -s -- /snap/bin/chromium \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=Translate \
  --ozone-platform=wayland \
  --enable-features=UseOzonePlatform \
  "${URL}"
