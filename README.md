# rpi-hdmi-kiosk

Raspberry Pi を HDMI キオスク端末にする最小構成。  
起動時に指定した URL を全画面表示する。SSH はそのまま維持。

## 動作環境

- Raspberry Pi 4/5 (arm64)
- Ubuntu 24.04 LTS (Noble)
- HDMI 接続のモニター

## セットアップ

```bash
git clone https://github.com/<YOUR_USER>/rpi-hdmi-kiosk.git
cd rpi-hdmi-kiosk
bash install.sh 'https://your-url-here.example.com'
```

## 構成ファイル

| ファイル | 役割 |
|---------|------|
| `install.sh` | パッケージ導入・サービス登録を一括実行 |
| `kiosk-start.sh` | cage + Chromium を kiosk モードで起動 |
| `hdmi-kiosk.service` | systemd サービス定義 |

## URL の変更

```bash
sudo systemctl edit hdmi-kiosk
```

Override に以下を追加:

```ini
[Service]
Environment=KIOSK_URL=https://new-url.example.com
```

```bash
sudo systemctl restart hdmi-kiosk
```

## トラブルシューティング

```bash
# サービス状態確認
systemctl status hdmi-kiosk --no-pager

# ログ確認
journalctl -u hdmi-kiosk -n 50 --no-pager

# 手動起動テスト
KIOSK_URL='https://example.com' ./kiosk-start.sh
```

## 技術スタック

- **cage**: 軽量 Wayland kiosk コンポジター
- **Chromium (snap)**: ブラウザ
- **fonts-noto-cjk**: 日本語フォント
