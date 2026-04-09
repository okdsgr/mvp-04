# GROSBREAK（グロスブレイク）
	
	> 自機は撃てない。吸って、溜めて、解き放て。
	
	![Godot](https://img.shields.io/badge/Godot-4.6.1-blue) ![Platform](https://img.shields.io/badge/Platform-Mobile-green) ![Status](https://img.shields.io/badge/Status-WIP-yellow)
	
	## 概要
	
	縦スクロール型モバイルシューター。斑鳩（IKARUGA）にインスパイアされた白黒反転システムを搭載。
	プレイヤーは弾を撃てない代わりに、敵の魂（弾）を引力で吸い寄せ、蓄積し、一斉放出することで戦う。
	
	## ゲームルール
	
	- **長押し** → 周囲の魂（敵弾）を引力で吸い寄せる
	- **離す** → 吸収した魂を全弾一斉放出（色が合った敵にホーミング）
	- 白い魂 → 黒い敵を狙う / 黒い魂 → 白い敵を狙う
	- 自機へのダメージは「敵との直接接触」のみ（弾は当たらない）
	
	## 特徴
	
	| 要素 | 内容 |
	|------|------|
	| 白黒バランスシステム | 白/黒敵の出現比率が動的に調整される |
	| WAVEシステム | 9段階のWAVEで難易度上昇 |
	| コンボシステム | 同色連続撃破で倍率UP（最大x∞） |
	| カスタマイズ | アキネーター形式で自機・敵・背景を生成 |
	| スキンシステム | プリセット5種 + AIによる完全カスタム |
	
	## AI生成パイプライン
	
	```
	ユーザー入力（アキネーター形式）
	↓
	Claude API（n8n経由）→ キャラクター決定
	↓
	Replicate / flux-schnell → スプライト生成
	↓
	GitHub commit + git pull → Godot に反映
	```
	
	## 技術スタック
	
	- **エンジン**: Godot 4.6.1
	- **AI**: Claude Haiku（n8n プロキシ経由）
	- **画像生成**: Replicate / flux-schnell
	- **自動化**: n8n Cloud（okdsgr.app.n8n.cloud）
	- **対応プラットフォーム**: iOS / Android（モバイル向け）
	
	## 定数・パラメータ
	
	```gdscript
	SPAWN_INTERVAL = 1.2s
	SPAWN_BATCH    = 3
	FIRE_SPEED     = 540
	ATTRACT_DRIFT  = 33.75
	```
	
	## プロジェクト構造
	
	```
	res://
	├── scenes/     # title.tscn, main.tscn, player.tscn, enemy.tscn, soul.tscn
	├── scripts/    # title.gd, main.gd, player.gd, enemy.gd, soul.gd, skin_manager.gd
	└── assets/sprites/  # AI生成スプライト（PNG）
	```
	
	## 開発者
	
	- **okdsgr** - メイン開発
	