#!/bin/bash
	# mvp-04 Mac自動同期セットアップ
	# このファイルをMac上で一度だけ実行する
	
	CRON_JOB="0 */3 * * * cd ~/Dev/godot-projects/mvp-04 && git add -A && git commit -m 'auto-sync' --allow-empty && git push 2>/dev/null; git pull 2>/dev/null"
	
	# 既存のcrontabに追記（重複チェック付き）
	(crontab -l 2>/dev/null | grep -v 'mvp-04'; echo "$CRON_JOB") | crontab -
	
	echo "cron設定完了:"
	crontab -l | grep mvp-04
	