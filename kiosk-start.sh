#!/usr/bin/env bash
# cage (Wayland kiosk コンポジター) 上で Chromium を全画面表示する。
set -euo pipefail

URL="${KIOSK_URL:?KIOSK_URL が設定されていません}"

exec cage -s -- /snap/bin/chromium \
  --kiosk \
  --no-first-run \
  --noerrdialogs \
  --disable-session-crashed-bubble \
  --disable-features=Translate \
  --ozone-platform=wayland \
  "${URL}"
