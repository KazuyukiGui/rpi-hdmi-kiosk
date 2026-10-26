#!/usr/bin/env bash
# cage (Wayland kiosk コンポジター) 上で Chromium を全画面表示する。
set -euo pipefail

URL="${KIOSK_URL:?KIOSK_URL が設定されていません}"

# 起動直後はネットワークがまだ使えないことがある。その状態で Chromium を開くと
# エラー画面のまま止まるので、表示先に接続できるまで最大 5 分待つ。
for _ in $(seq 60); do
  curl -fsS -o /dev/null --max-time 5 "${URL}" && break
  sleep 5
done

exec cage -s -- /snap/bin/chromium \
  --kiosk \
  --no-first-run \
  --noerrdialogs \
  --disable-session-crashed-bubble \
  --disable-features=Translate \
  --ozone-platform=wayland \
  "${URL}"
