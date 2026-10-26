# rpi-hdmi-kiosk

Raspberry Pi を HDMI キオスク端末にする最小構成。

- 起動時に指定した URL を全画面表示する
- 平日 8:30 / 17:00 に HDMI からチャイムを鳴らす (任意)
- SSH はそのまま使える

## 動作環境

- Raspberry Pi 4/5 (arm64)
- Ubuntu 24.04 LTS (Noble)
- HDMI 接続のモニター

## セットアップ

```bash
git clone https://github.com/<YOUR_USER>/rpi-hdmi-kiosk.git
cd rpi-hdmi-kiosk

# キオスク
sudo ./install.sh 'https://your-url-here.example.com'

# チャイム (任意)
sudo ./install-chime.sh
```

どちらも何度実行しても同じ状態になる。設定を変えたいときは再実行すればよい。

## pharmacy-cam (会計案内表示) との連携

このキオスクは [pharmacy-cam](https://github.com/KazuyukiGui/pharmacy-cam) の表示ページを映すために使う。

```
カメラ側ラズパイ (pharmacy-cam) ─ upload.php ─▶ Xserver: images/latest.jpg
                                                   │
                       index.html ◀────────────────┘
                         ├ スマホ・PC (通常表示)
                         └ このキオスク (?kiosk=1 で画像だけを全画面表示)
```

URL の末尾に `?kiosk=1` を付けて登録する:

```bash
sudo ./install.sh 'https://skgh.xsrv.jp/monitor/kaikei/?kiosk=1'
```

| 状況 | キオスクの表示 |
|---|---|
| 通常 | 会計の画像だけを黒背景で全画面表示 (見出し・ボタン・読み込み中の表示なし) |
| 画像が 10 分以上更新されない (カメラ停止・通信断) | 古い番号を隠して「表示を停止しています」と案内 |
| 起動直後にネットワーク未接続 | つながるまで最大 5 分待ってからブラウザを開く |

## 仕組み

```
電源 ON
 └ systemd
    ├ hdmi-kiosk.service ── kiosk-start.sh ── cage ── Chromium (URL を全画面表示)
    │    実行ユーザー: kiosk (専用・権限なし)
    └ hdmi-chime.timer (平日 8:30 / 17:00)
         └ hdmi-chime.service ── play-chime.sh ── aplay (HDMI 音声)
              実行ユーザー: 毎回使い捨ての一時ユーザー
```

| リポジトリのファイル | インストール先 | 役割 |
|---|---|---|
| `install.sh` | — | キオスクのセットアップ |
| `kiosk-start.sh` | `/usr/local/lib/hdmi-kiosk/` | cage + Chromium を起動 |
| `hdmi-kiosk.service` | `/etc/systemd/system/` | キオスクを常駐させる |
| (URL) | `/etc/hdmi-kiosk/kiosk.env` | 表示する URL |
| `install-chime.sh` | — | チャイムのセットアップ |
| `play-chime.sh`, `chime_s32.wav` | `/usr/local/lib/hdmi-kiosk/` | チャイムを 1 回鳴らす |
| `hdmi-chime.service` / `.timer` | `/etc/systemd/system/` | チャイムの実行と時刻 |

## セキュリティの考え方

キオスクは「外部の Web ページを無人で表示し続ける端末」なので、
**ブラウザが乗っ取られても被害を広げない**ことを重視している。

| 対策 | 内容 |
|---|---|
| 専用ユーザー | ブラウザは `kiosk` ユーザーで動く。sudo 不可・パスワードなし・ログインシェルなし |
| 実行ファイルは root 所有 | `/usr/local/lib/hdmi-kiosk/` は `kiosk` ユーザーから書き換えられない |
| URL は root のみ読める | `kiosk.env` は 0600。トークン付き URL でも他ユーザーから見えない |
| URL の文字チェック | URL として正当な文字以外 (`'` `"` `\` `$` 空白など) は拒否する |
| チャイムは隔離実行 | 一時ユーザー・ネットワークなし・音声デバイス以外アクセス不可 |
| Chromium | snap 版を使用。AppArmor で閉じ込められ、自動更新される |

キオスク側の systemd に `NoNewPrivileges=` などのサンドボックス設定を付けていないのは、
snap 版 Chromium が setuid の `snap-confine` で起動するため、付けると動かなくなるから。

あわせて、OS 側で以下も行うことを勧める:

- SSH は鍵認証のみにする (`/etc/ssh/sshd_config` で `PasswordAuthentication no`)
- `unattended-upgrades` を有効のままにする (Ubuntu の既定で有効)

## URL の変更

```bash
sudo ./install.sh 'https://new-url.example.com'
```

## チャイムの設定

時刻はシステムのタイムゾーンに従う。日本時間にするには:

```bash
sudo timedatectl set-timezone Asia/Tokyo
```

時刻を変えたいときは `hdmi-chime.timer` の `OnCalendar=` を編集して `sudo ./install-chime.sh` を再実行する。

```bash
systemctl list-timers hdmi-chime.timer   # 次回の予定
sudo systemctl start hdmi-chime.service  # 今すぐ鳴らす
```

## トラブルシューティング

```bash
# 状態とログ
systemctl status hdmi-kiosk --no-pager
journalctl -u hdmi-kiosk -n 50 --no-pager
journalctl -u hdmi-chime -n 20 --no-pager

# 音声デバイスの確認 (チャイムが鳴らないとき)
aplay -l
```

チャイムの出力先は `play-chime.sh` の `CHIME_DEVICE` (既定: `hdmi:CARD=vc4hdmi0,DEV=0`)。
HDMI 1 番ポートを使う場合は `vc4hdmi1` に変える。

## 以前の版からの移行

以前の版は `admin` ユーザーでブラウザを動かし、チャイムを cron で鳴らしていた。
新しい版を実行すると次のように切り替わる:

- `install.sh`: 専用ユーザー `kiosk` が作られ、ブラウザはそのユーザーで動く。
  ブラウザのログイン状態などは引き継がれないので、必要なら再ログインする。
  どうしても既存ユーザーで動かしたい場合は `sudo KIOSK_USER=admin ./install.sh '<URL>'`
  (警告が出るが動作はする)。
- `install-chime.sh`: 古い cron の登録は自動で削除され、systemd タイマーに置き換わる。
- 古い `/home/admin/kiosk-start.sh` は使われなくなるので削除してよい。

## アンインストール

```bash
sudo systemctl disable --now hdmi-kiosk.service hdmi-chime.timer
sudo rm -f /etc/systemd/system/hdmi-kiosk.service \
           /etc/systemd/system/hdmi-chime.service \
           /etc/systemd/system/hdmi-chime.timer
sudo rm -rf /usr/local/lib/hdmi-kiosk /etc/hdmi-kiosk
sudo systemctl daemon-reload
sudo systemctl enable --now getty@tty1.service
# 専用ユーザーも消す場合
sudo userdel -r kiosk
```

## 技術スタック

- **cage**: 軽量 Wayland kiosk コンポジター
- **Chromium (snap)**: ブラウザ
- **fonts-noto-cjk**: 日本語フォント
- **systemd timer**: チャイムのスケジュール
