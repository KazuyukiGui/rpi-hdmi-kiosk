#!/usr/bin/env bash
# チャイムを HDMI 音声で 1 回再生する。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHIME_FILE="${CHIME_FILE:-${SCRIPT_DIR}/chime_s32.wav}"
CHIME_DEVICE="${CHIME_DEVICE:-hdmi:CARD=vc4hdmi0,DEV=0}"

if [ ! -f "${CHIME_FILE}" ]; then
  echo "Chime file not found: ${CHIME_FILE}" >&2
  exit 1
fi

exec aplay -q -D "${CHIME_DEVICE}" "${CHIME_FILE}"
