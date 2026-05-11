#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing audio tools..."
sudo apt install -y alsa-utils

echo "==> Testing HDMI audio..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x "${SCRIPT_DIR}/play-chime.sh"
bash "${SCRIPT_DIR}/play-chime.sh"

echo "==> Setting up cron (8:30 and 17:00)..."
CRON_LINE_AM="30 8 * * 1-5 ${SCRIPT_DIR}/play-chime.sh > /dev/null 2>&1"
CRON_LINE_PM="0 17 * * 1-5 ${SCRIPT_DIR}/play-chime.sh > /dev/null 2>&1"

(crontab -l 2>/dev/null | grep -v play-chime; echo "${CRON_LINE_AM}"; echo "${CRON_LINE_PM}") | crontab -

echo ""
echo "Done! Chime scheduled:"
echo "  - Mon-Fri 08:30"
echo "  - Mon-Fri 17:00"
echo ""
echo "Test now:  bash ${SCRIPT_DIR}/play-chime.sh"
echo "View cron: crontab -l"
