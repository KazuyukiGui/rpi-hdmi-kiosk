#!/usr/bin/env bash
# 平日 8:30 / 17:00 に HDMI からチャイムを鳴らす systemd タイマーを設定する。
# 使い方: sudo ./install-chime.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR=/usr/local/lib/hdmi-kiosk

die() { echo "Error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "root で実行してください: sudo $0"

echo "==> Installing audio tools..."
apt-get install -y alsa-utils

echo "==> Installing files..."
install -d -m 0755 "${LIB_DIR}"
install -m 0755 "${SCRIPT_DIR}/play-chime.sh" "${LIB_DIR}/play-chime.sh"
install -m 0644 "${SCRIPT_DIR}/chime_s32.wav" "${LIB_DIR}/chime_s32.wav"
install -m 0644 "${SCRIPT_DIR}/hdmi-chime.service" /etc/systemd/system/hdmi-chime.service
install -m 0644 "${SCRIPT_DIR}/hdmi-chime.timer" /etc/systemd/system/hdmi-chime.timer

echo "==> Removing old cron entries (if any)..."
for user in root ${SUDO_USER:+"${SUDO_USER}"}; do
  if crontab -u "${user}" -l 2>/dev/null | grep -q play-chime; then
    crontab -u "${user}" -l | grep -v play-chime | crontab -u "${user}" -
    echo "    removed from ${user}'s crontab"
  fi
done

echo "==> Testing HDMI audio..."
systemctl daemon-reload
systemctl start hdmi-chime.service

echo "==> Enabling timer..."
systemctl enable --now hdmi-chime.timer

echo ""
echo "Done! Chime scheduled: Mon-Fri 08:30 / 17:00"
echo "Timezone:   $(timedatectl show -p Timezone --value 2>/dev/null || echo unknown)"
echo "            (変更: sudo timedatectl set-timezone Asia/Tokyo)"
echo "Next run:   systemctl list-timers hdmi-chime.timer"
echo "Test now:   sudo systemctl start hdmi-chime.service"
