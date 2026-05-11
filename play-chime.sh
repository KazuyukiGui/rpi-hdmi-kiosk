#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHIME="${SCRIPT_DIR}/chime_s32.wav"

if [ ! -f "${CHIME}" ]; then
  echo "chime.wav not found at ${CHIME}" >&2
  exit 1
fi

aplay -D hdmi:CARD=vc4hdmi0,DEV=0 "${CHIME}"
