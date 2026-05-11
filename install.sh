#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIOSK_USER="${KIOSK_USER:-admin}"
KIOSK_URL="${1:-}"

if [ -z "${KIOSK_URL}" ]; then
  echo "Usage: $0 <URL>"
  echo "Example: $0 'https://script.google.com/macros/s/xxx/exec'"
  exit 1
fi

echo "==> Installing packages..."
sudo apt update
sudo apt install -y cage chromium-browser fonts-noto-cjk

echo "==> Setting up snap Chromium font access..."
sudo snap connect chromium:fonts-config :fonts-config 2>/dev/null || true
sudo snap connect chromium:desktop :desktop 2>/dev/null || true

SNAP_FONT_DIR="/home/${KIOSK_USER}/snap/chromium/common/.local/share/fonts"
mkdir -p "${SNAP_FONT_DIR}"
cp /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc "${SNAP_FONT_DIR}/" 2>/dev/null || true
cp /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc "${SNAP_FONT_DIR}/" 2>/dev/null || true

echo "==> Installing kiosk script..."
sudo install -o "${KIOSK_USER}" -g "${KIOSK_USER}" -m 0755 \
  "${SCRIPT_DIR}/kiosk-start.sh" "/home/${KIOSK_USER}/kiosk-start.sh"

echo "==> Installing systemd service..."
sed "s|Environment=KIOSK_URL=.*|Environment=KIOSK_URL=${KIOSK_URL}|" \
  "${SCRIPT_DIR}/hdmi-kiosk.service" | \
  sed "s|User=admin|User=${KIOSK_USER}|; s|Group=admin|Group=${KIOSK_USER}|" | \
  sed "s|ExecStart=.*|ExecStart=/home/${KIOSK_USER}/kiosk-start.sh|" | \
  sudo tee /etc/systemd/system/hdmi-kiosk.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl disable --now getty@tty1.service 2>/dev/null || true
sudo systemctl enable --now hdmi-kiosk.service

echo ""
echo "Done! Kiosk is now displaying: ${KIOSK_URL}"
echo "Check status: systemctl status hdmi-kiosk --no-pager"
echo "View logs:    journalctl -u hdmi-kiosk -f"
