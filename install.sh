#!/usr/bin/env bash
# HDMI キオスクをセットアップする。何度実行しても同じ状態になる。
# 使い方: sudo ./install.sh <URL>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIOSK_USER="${KIOSK_USER:-kiosk}"
KIOSK_URL="${1:-}"
LIB_DIR=/usr/local/lib/hdmi-kiosk
CONF_DIR=/etc/hdmi-kiosk

die() { echo "Error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "root で実行してください: sudo $0 <URL>"
[ -n "${KIOSK_URL}" ] || die "URL を指定してください: sudo $0 'https://example.com'"

# URL は RFC 3986 の文字だけを許可する (' " \ $ ` 空白は不可)。
# 設定ファイルや systemd に渡すときに壊れたり、別の意味に解釈されたりするのを防ぐ。
url_re='^https?://[]A-Za-z0-9._~:/?#@!&()*+,;=%[-]+$'
[[ "${KIOSK_URL}" =~ ${url_re} ]] || die "URL に使えない文字が含まれています: ${KIOSK_URL}"
[[ "${KIOSK_URL}" == https://* ]] || echo "Warning: http:// は通信が暗号化されません。可能なら https:// を使ってください。" >&2

[[ "${KIOSK_USER}" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "ユーザー名が不正です: ${KIOSK_USER}"

echo "==> Installing packages..."
apt-get update
apt-get install -y cage chromium-browser fonts-noto-cjk curl

echo "==> Preparing user '${KIOSK_USER}'..."
if ! id "${KIOSK_USER}" >/dev/null 2>&1; then
  # ブラウザ専用ユーザー。ログインシェルなし・パスワードなし・sudo なし。
  useradd --create-home --user-group --shell /usr/sbin/nologin "${KIOSK_USER}"
fi
for group in video render audio; do
  if getent group "${group}" >/dev/null; then
    usermod -aG "${group}" "${KIOSK_USER}"
  fi
done
if id -nG "${KIOSK_USER}" | grep -qwE 'sudo|admin|wheel'; then
  echo "Warning: '${KIOSK_USER}' は管理者権限を持っています。ブラウザが乗っ取られると OS 全体に影響します。" >&2
  echo "         KIOSK_USER を指定せず実行すると、専用ユーザー 'kiosk' が作られます。" >&2
fi
KIOSK_UID="$(id -u "${KIOSK_USER}")"
KIOSK_HOME="$(getent passwd "${KIOSK_USER}" | cut -d: -f6)"

echo "==> Setting up snap Chromium font access..."
snap connect chromium:fonts-config :fonts-config 2>/dev/null || true
snap connect chromium:desktop :desktop 2>/dev/null || true
# 親ディレクトリを root 所有にしないよう、ユーザー権限で作成する
SNAP_FONT_DIR="${KIOSK_HOME}/snap/chromium/common/.local/share/fonts"
runuser -u "${KIOSK_USER}" -- mkdir -p "${SNAP_FONT_DIR}"
for font in NotoSansCJK-Regular.ttc NotoSansCJK-Bold.ttc; do
  src="/usr/share/fonts/opentype/noto/${font}"
  if [ -f "${src}" ]; then
    install -o "${KIOSK_USER}" -g "$(id -gn "${KIOSK_USER}")" -m 0644 "${src}" "${SNAP_FONT_DIR}/"
  fi
done

echo "==> Installing files..."
# 実行ファイルは root 所有にして、キオスクユーザーからは書き換えられないようにする
install -d -m 0755 "${LIB_DIR}"
install -m 0755 "${SCRIPT_DIR}/kiosk-start.sh" "${LIB_DIR}/kiosk-start.sh"

# URL は秘密情報 (トークン付き URL など) の場合があるので root のみ読める
install -d -m 0755 "${CONF_DIR}"
printf "KIOSK_URL='%s'\n" "${KIOSK_URL}" > "${CONF_DIR}/kiosk.env.tmp"
chmod 0600 "${CONF_DIR}/kiosk.env.tmp"
mv "${CONF_DIR}/kiosk.env.tmp" "${CONF_DIR}/kiosk.env"

sed -e "s|@KIOSK_USER@|${KIOSK_USER}|g" -e "s|@KIOSK_UID@|${KIOSK_UID}|g" \
  "${SCRIPT_DIR}/hdmi-kiosk.service" > /etc/systemd/system/hdmi-kiosk.service
chmod 0644 /etc/systemd/system/hdmi-kiosk.service

echo "==> Enabling service..."
systemctl daemon-reload
systemctl disable --now getty@tty1.service 2>/dev/null || true
systemctl enable hdmi-kiosk.service
systemctl restart hdmi-kiosk.service

echo ""
echo "Done! Kiosk is now displaying: ${KIOSK_URL}"
echo "Check status: systemctl status hdmi-kiosk --no-pager"
echo "View logs:    journalctl -u hdmi-kiosk -f"
