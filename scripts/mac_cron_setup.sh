#!/bin/bash
# mvp-04 Mac自動同期セットアップ
# 5分ごとにpull（pushはClaude MCPが担当）

CRON_JOB="*/5 * * * * cd ~/Dev/godot-projects/mvp-04 && git pull --ff-only 2>/dev/null"

# 既存のmvp-04エントリを削除して再登録
(crontab -l 2>/dev/null | grep -v 'mvp-04'; echo "$CRON_JOB") | crontab -

echo "cron設定完了:"
crontab -l | grep mvp-04
