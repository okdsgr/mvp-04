extends Node2D

const GAME_TITLE  : String = "GROSBREAK"
const N8N_URL     : String = "https://okdsgr.app.n8n.cloud/webhook/sprite-to-mvp04"
const CLAUDE_URL  : String = "https://api.anthropic.com/v1/messages"
const CLAUDE_MODEL: String = "claude-sonnet-4-20250514"
const VP_W        : float  = 540.0
const VP_H        : float  = 960.0

enum Screen { TITLE, MENU, PLAYER_AKI, ENEMY_AKI, BG_AKI, GENERATING, READY }
var _screen : Screen = Screen.TITLE
var _anim   : float  = 0.0
var _orbs   : Array  = []

# API
var _api_key  : String = ""
var _http_ai  : HTTPRequest = null  # Claude API用
var _http_gen : HTTPRequest = null  # n8n生成用
var _waiting  : bool = false

# Akinator会話履歴
var _messages      : Array  = []
var _system_prompt : String = ""

# 決定したキャラ
var _player_en : String = ""
var _enemy_en  : String = ""
var _bg_prompt : String = ""
var _player_display : String = ""
var _enemy_display  : String = ""

# UI
var _ui        : CanvasLayer  = null
var _chat_vbox : VBoxContainer = null
var _input_edit: LineEdit      = null
var _send_btn  : Button        = null
var _progress_bar : ProgressBar = null
var _progress_lbl : Label       = null
var _step_lbl     : Label       = null

# 生成キュー
var _gen_queue   : Array = []
var _gen_current : int   = 0
const STEP_NAMES : Array = ["自機（待機）", "自機（歩き）", "白い敵", "黒い敵", "背景"]

# ===== システムプロンプト =====
const PLAYER_SYSTEM : String = """あなたはアキネーターです。ユーザーとの会話から、縦スクロールシューティングゲームの「自機（プレイヤーキャラクター）」を3〜5回の質問で決定してください。
質問は日本語で1文のみ、簡潔に。余分な説明は不要。
キャラクターが決まったら必ず次のフォーマットで答えてください：
[PLAYER:英語名]○○を自機として登場させますね！
英語名はシンプルな英単語（例: robot, ninja, bear, rocket, cat）。"""

const ENEMY_SYSTEM : String = """あなたはアキネーターです。ユーザーとの会話から、縦スクロールシューティングゲームの「敵キャラクター」を3〜5回の質問で決定してください。
質問は日本語で1文のみ、簡潔に。余分な説明は不要。
キャラクターが決まったら必ず次のフォーマットで答えてください：
[ENEMY:英語名]白い○○と黒い○○を敵として登場させますね！
英語名はシンプルな英単語（例: dragon, ghost, mushroom, cake）。"""

const BG_SYSTEM : String = """あなたはゲームアーティストです。ユーザーの回答から縦スクロールシューティングゲームの背景世界観を2〜3回の質問で決定してください。
質問は日本語で1文のみ。
決定したら必ず次のフォーマットで答えてください：
[BG:英語プロンプト]世界観が決まりました！
英語プロンプトは画像生成AI用の短い英語プロンプト。縦スクロールゲームの背景として映える情景を描写してください。"""

# ===== 最初の質問 =====
const PLAYER_Q1 : String = "生まれ変わるとしたら、どんな存在になりたいですか？"
const ENEMY_Q1  : String = "嫌いなもの、または怖いものを思い浮かべてください。どんなものが頭に浮かびますか？"
const BG_Q1     : String = "子どもの頃、好きだった絵本や物語の世界を教えてください。"

# =====================================================================
func _ready() -> void:
	# API key読み込み（環境変数 → ファイル）
	_api_key = OS.get_environment("ANTHROPIC_API_KEY")
	if _api_key.is_empty():
		var f := FileAccess.open("res://config/api_key.txt", FileAccess.READ)
		if f:
			_api_key = f.get_line().strip_edges()
			f.close()

	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.10, 1.0))
	randomize()

	for i: int in 24:
		_orbs.append({
			"pos":      Vector2(randf() * VP_W, randf() * VP_H),
			"vel":      Vector2(randf_range(-12.0, 12.0), randf_range(-25.0, -8.0)),
			"r":        randf_range(3.0, 10.0),
			"is_white": randf() > 0.5,
			"phase":    randf() * TAU,
		})

	_ui = CanvasLayer.new()
	add_child(_ui)

	_http_ai = HTTPRequest.new()
	_http_ai.timeout = 40.0
	add_child(_http_ai)

	_http_gen = HTTPRequest.new()
	_http_gen.timeout = 120.0
	add_child(_http_gen)

	_show_title()

func _process(delta: float) -> void:
	_anim += delta
	for orb : Dictionary in _orbs:
		orb["pos"] += (orb["vel"] as Vector2) * delta
		if (orb["pos"] as Vector2).y < -20.0:
			orb["pos"] = Vector2(randf() * VP_W, VP_H + 10.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if _screen != Screen.TITLE:
		return
	var hit : bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hit = true
	elif event is InputEventKey and (event as InputEventKey).pressed:
		hit = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		hit = true
	if hit:
		_show_menu()

func _draw() -> void:
	for orb : Dictionary in _orbs:
		var pos   : Vector2 = orb["pos"]
		var r     : float   = orb["r"]
		var pulse : float   = sin(_anim * 1.5 + (orb["phase"] as float)) * 0.3 + 0.7
		if orb["is_white"]:
			draw_circle(pos, r * 2.0, Color(1.0, 1.0, 1.0, 0.05 * pulse))
			draw_circle(pos, r,       Color(1.0, 1.0, 1.0, 0.35 * pulse))
		else:
			draw_circle(pos, r * 2.0, Color(0.55, 0.0, 0.85, 0.07 * pulse))
			draw_circle(pos, r,       Color(0.75, 0.2, 1.0, 0.45 * pulse))

func _clear_ui() -> void:
	for c : Node in _ui.get_children():
		c.queue_free()
	_chat_vbox  = null
	_input_edit = null
	_send_btn   = null

# =====================================================================
# TITLE
# =====================================================================
func _show_title() -> void:
	_screen = Screen.TITLE
	_clear_ui()
	var cx : float = VP_W * 0.5

	var t := Label.new()
	t.text = GAME_TITLE
	t.add_theme_font_size_override("font_size", 72)
	t.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	t.position = Vector2(cx - 190.0, 260.0)
	_ui.add_child(t)

	var sub := Label.new()
	sub.text = "グロスブレイク"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.85, 0.9))
	sub.position = Vector2(cx - 83.0, 358.0)
	_ui.add_child(sub)

	var press := Label.new()
	press.text = "Tap or Press Any Key"
	press.add_theme_font_size_override("font_size", 18)
	press.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
	press.position = Vector2(cx - 105.0, 680.0)
	_ui.add_child(press)

	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(press, "modulate:a", 0.1, 0.75)
	tw.tween_property(press, "modulate:a", 1.0, 0.75)

# =====================================================================
# MENU
# =====================================================================
func _show_menu() -> void:
	_screen = Screen.MENU
	_clear_ui()
	var cx : float = VP_W * 0.5

	var t := Label.new()
	t.text = GAME_TITLE
	t.add_theme_font_size_override("font_size", 48)
	t.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	t.position = Vector2(cx - 128.0, 200.0)
	_ui.add_child(t)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 155.0, 420.0)
	vbox.add_theme_constant_override("separation", 22)
	_ui.add_child(vbox)

	var s_btn := Button.new()
	s_btn.text = "▶   すぐに始める"
	s_btn.custom_minimum_size = Vector2(310, 64)
	s_btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(s_btn)
	s_btn.pressed.connect(_on_start_default)

	var c_btn := Button.new()
	c_btn.text = "✦   カスタマイズ"
	c_btn.custom_minimum_size = Vector2(310, 64)
	c_btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(c_btn)
	c_btn.pressed.connect(_start_player_akinator)

func _on_start_default() -> void:
	var sm : Node = get_node_or_null("/root/SkinManager")
	if sm:
		sm.set_skin("default")
		sm.confirm_skin()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# =====================================================================
# AKINATOR 共通UI
# =====================================================================
func _show_akinator_ui(phase_title: String) -> void:
	_clear_ui()
	var cx : float = VP_W * 0.5

	var title_lbl := Label.new()
	title_lbl.text = phase_title
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0, 0.9))
	title_lbl.position = Vector2(cx - 100.0, 38.0)
	_ui.add_child(title_lbl)

	# チャット履歴エリア
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28.0, 80.0)
	scroll.custom_minimum_size = Vector2(VP_W - 56.0, 560.0)
	_ui.add_child(scroll)

	_chat_vbox = VBoxContainer.new()
	_chat_vbox.add_theme_constant_override("separation", 12)
	_chat_vbox.custom_minimum_size = Vector2(VP_W - 70.0, 0)
	scroll.add_child(_chat_vbox)

	# 入力エリア
	_input_edit = LineEdit.new()
	_input_edit.placeholder_text = "回答を入力..."
	_input_edit.custom_minimum_size = Vector2(390.0, 52.0)
	_input_edit.add_theme_font_size_override("font_size", 16)
	_input_edit.position = Vector2(28.0, 860.0)
	_ui.add_child(_input_edit)

	_send_btn = Button.new()
	_send_btn.text = "送信"
	_send_btn.custom_minimum_size = Vector2(90.0, 52.0)
	_send_btn.add_theme_font_size_override("font_size", 16)
	_send_btn.position = Vector2(430.0, 860.0)
	_ui.add_child(_send_btn)

	_send_btn.pressed.connect(_on_send_pressed)
	_input_edit.text_submitted.connect(func(_t: String): _on_send_pressed())

func _on_send_pressed() -> void:
	if _waiting or _input_edit == null:
		return
	var answer : String = _input_edit.text.strip_edges()
	if answer.is_empty():
		return
	_input_edit.text = ""
	_add_msg_user(answer)
	_call_claude(answer)

func _add_msg_claude(text: String) -> void:
	if _chat_vbox == null:
		return
	var lbl := Label.new()
	lbl.text = "🎮  " + text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(VP_W - 80.0, 0)
	_chat_vbox.add_child(lbl)

func _add_msg_user(text: String) -> void:
	if _chat_vbox == null:
		return
	var lbl := Label.new()
	lbl.text = "▶  " + text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(VP_W - 80.0, 0)
	_chat_vbox.add_child(lbl)

func _set_waiting(on: bool) -> void:
	_waiting = on
	if is_instance_valid(_send_btn):
		_send_btn.disabled = on
		_send_btn.text = "..." if on else "送信"
	if is_instance_valid(_input_edit):
		_input_edit.editable = not on

# =====================================================================
# PLAYER AKINATOR
# =====================================================================
func _start_player_akinator() -> void:
	_screen = Screen.PLAYER_AKI
	_messages = []
	_system_prompt = PLAYER_SYSTEM
	_show_akinator_ui("自機を決めよう ①/③")
	_messages.append({"role": "assistant", "content": PLAYER_Q1})
	_add_msg_claude(PLAYER_Q1)

# =====================================================================
# ENEMY AKINATOR
# =====================================================================
func _start_enemy_akinator() -> void:
	_screen = Screen.ENEMY_AKI
	_messages = []
	_system_prompt = ENEMY_SYSTEM
	_show_akinator_ui("敵を決めよう ②/③")
	_messages.append({"role": "assistant", "content": ENEMY_Q1})
	_add_msg_claude(ENEMY_Q1)

# =====================================================================
# BG AKINATOR
# =====================================================================
func _start_bg_akinator() -> void:
	_screen = Screen.BG_AKI
	_messages = []
	_system_prompt = BG_SYSTEM
	_show_akinator_ui("背景の世界観を決めよう ③/③")
	_messages.append({"role": "assistant", "content": BG_Q1})
	_add_msg_claude(BG_Q1)

# =====================================================================
# CLAUDE API
# =====================================================================
func _call_claude(user_answer: String) -> void:
	if _api_key.is_empty():
		_add_msg_claude("⚠ APIキーが設定されていません。\nres://config/api_key.txt にキーを記入してください。")
		return

	_set_waiting(true)
	_messages.append({"role": "user", "content": user_answer})

	var body : String = JSON.stringify({
		"model": CLAUDE_MODEL,
		"max_tokens": 400,
		"system": _system_prompt,
		"messages": _messages,
	})
	var headers : PackedStringArray = [
		"Content-Type: application/json",
		"x-api-key: " + _api_key,
		"anthropic-version: 2023-06-01",
	]

	if _http_ai.request_completed.is_connected(_on_claude_response):
		_http_ai.request_completed.disconnect(_on_claude_response)
	_http_ai.request_completed.connect(_on_claude_response, CONNECT_ONE_SHOT)
	_http_ai.request(CLAUDE_URL, headers, HTTPClient.METHOD_POST, body)

func _on_claude_response(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_set_waiting(false)

	var text : String = body.get_string_from_utf8()
	var json = JSON.parse_string(text)

	var reply : String = ""
	if json and json.has("content") and (json["content"] as Array).size() > 0:
		reply = ((json["content"] as Array)[0] as Dictionary)["text"]
	else:
		_add_msg_claude("⚠ エラーが発生しました（%d）。もう一度試してください。" % code)
		return

	_messages.append({"role": "assistant", "content": reply})

	match _screen:
		Screen.PLAYER_AKI: _parse_player(reply)
		Screen.ENEMY_AKI:  _parse_enemy(reply)
		Screen.BG_AKI:     _parse_bg(reply)

# ===== パース =====
func _parse_player(reply: String) -> void:
	var re := RegEx.new()
	re.compile("\\[PLAYER:([a-zA-Z _]+)\\]")
	var m = re.search(reply)
	var display : String = reply.replace(m.get_string() if m else "", "").strip_edges() if m else reply
	_add_msg_claude(display)
	if m:
		_player_en      = m.get_string(1).strip_edges()
		_player_display = _extract_quoted(reply)
		await get_tree().create_timer(2.0).timeout
		_start_enemy_akinator()

func _parse_enemy(reply: String) -> void:
	var re := RegEx.new()
	re.compile("\\[ENEMY:([a-zA-Z _]+)\\]")
	var m = re.search(reply)
	var display : String = reply.replace(m.get_string() if m else "", "").strip_edges() if m else reply
	_add_msg_claude(display)
	if m:
		_enemy_en      = m.get_string(1).strip_edges()
		_enemy_display = _extract_quoted(reply)
		await get_tree().create_timer(2.0).timeout
		_start_bg_akinator()

func _parse_bg(reply: String) -> void:
	var re := RegEx.new()
	re.compile("\\[BG:(.+?)\\]")
	var m = re.search(reply)
	var display : String = reply.replace(m.get_string() if m else "", "").strip_edges() if m else reply
	_add_msg_claude(display)
	if m:
		_bg_prompt = m.get_string(1).strip_edges()
		await get_tree().create_timer(2.0).timeout
		_start_generation()

func _extract_quoted(text: String) -> String:
	var re := RegEx.new()
	re.compile("「(.+?)」")
	var m = re.search(text)
	return m.get_string(1) if m else ""

# =====================================================================
# GENERATING
# =====================================================================
func _start_generation() -> void:
	_screen = Screen.GENERATING
	_clear_ui()
	var cx : float = VP_W * 0.5

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 165.0, 340.0)
	vbox.add_theme_constant_override("separation", 18)
	_ui.add_child(vbox)

	var title := Label.new()
	title.text = "スプライトを生成中..."
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_progress_lbl = Label.new()
	_progress_lbl.text = "0 / 5"
	_progress_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_progress_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 5.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(330, 28)
	vbox.add_child(_progress_bar)

	_step_lbl = Label.new()
	_step_lbl.text = "⏳ 準備中..."
	_step_lbl.add_theme_font_size_override("font_size", 14)
	_step_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vbox.add_child(_step_lbl)

	if _http_gen.request_completed.is_connected(_on_gen_done):
		_http_gen.request_completed.disconnect(_on_gen_done)
	_http_gen.request_completed.connect(_on_gen_done)

	_gen_queue   = _build_gen_queue()
	_gen_current = 0
	_send_gen_next()

func _build_gen_queue() -> Array:
	var p : String = _player_en if not _player_en.is_empty() else "boy"
	var e : String = _enemy_en  if not _enemy_en.is_empty()  else "ghost"
	var bg: String = _bg_prompt if not _bg_prompt.is_empty() else "fantasy sky landscape"
	return [
		{"filename": "player_custom_idle", "prompt": "cute chibi %s character, back view, standing idle pose, white background, game sprite pixel art" % p},
		{"filename": "player_custom_walk", "prompt": "cute chibi %s character, back view, walking mid-step, white background, game sprite pixel art" % p},
		{"filename": "enemy_custom_white", "prompt": "cute white %s, chibi style, round chubby body, bright white color, white background, game sprite pixel art" % e},
		{"filename": "enemy_custom_black", "prompt": "cute dark black %s, chibi style, round chubby body, dark color, white background, game sprite pixel art" % e},
		{"filename": "bg_custom",          "prompt": "%s, vertical scrolling game background, seamless tiling, pixel art style" % bg},
	]

func _send_gen_next() -> void:
	if _gen_current >= _gen_queue.size():
		_on_all_generated()
		return
	var item : Dictionary = _gen_queue[_gen_current]
	if is_instance_valid(_step_lbl):
		_step_lbl.text = "⏳ %s を生成中..." % STEP_NAMES[_gen_current]
	if is_instance_valid(_progress_lbl):
		_progress_lbl.text = "%d / %d" % [_gen_current, _gen_queue.size()]
	if is_instance_valid(_progress_bar):
		_progress_bar.value = float(_gen_current)
	var headers : PackedStringArray = ["Content-Type: application/json"]
	_http_gen.request(N8N_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(item))

func _on_gen_done(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_gen_current += 1
	if is_instance_valid(_progress_bar):
		_progress_bar.value = float(_gen_current)
	if is_instance_valid(_progress_lbl):
		_progress_lbl.text = "%d / %d" % [_gen_current, _gen_queue.size()]
	if is_instance_valid(_step_lbl) and _gen_current <= STEP_NAMES.size():
		_step_lbl.text = "✓ %s 完了" % STEP_NAMES[_gen_current - 1]
	_send_gen_next()

func _on_all_generated() -> void:
	_http_gen.request_completed.disconnect(_on_gen_done)
	if is_instance_valid(_step_lbl):
		_step_lbl.text = "⏳ スプライトを同期中..."

	var path : String = ProjectSettings.globalize_path("res://")
	var out   : Array  = []
	OS.execute("git", ["-C", path, "pull"], out, true)
	print("git pull: ", out)

	var sm : Node = get_node_or_null("/root/SkinManager")
	if sm:
		sm.register_skin("custom", {
			"player_idle":      "res://assets/sprites/player_custom_idle.png",
			"player_walk":      "res://assets/sprites/player_custom_walk.png",
			"player_raise":     "res://assets/sprites/player_custom_idle.png",
			"player_raise_walk":"res://assets/sprites/player_custom_walk.png",
			"enemy_white":      "res://assets/sprites/enemy_custom_white.png",
			"enemy_white_anim": "res://assets/sprites/enemy_custom_white.png",
			"enemy_black":      "res://assets/sprites/enemy_custom_black.png",
			"enemy_black_anim": "res://assets/sprites/enemy_custom_black.png",
			"bg":               "res://assets/sprites/bg_custom.png",
		})
		sm.set_skin("custom")
		sm.confirm_skin()

	_show_ready()

# =====================================================================
# READY
# =====================================================================
func _show_ready() -> void:
	_screen = Screen.READY
	_clear_ui()
	var cx : float = VP_W * 0.5

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 165.0, 360.0)
	vbox.add_theme_constant_override("separation", 20)
	_ui.add_child(vbox)

	var r_lbl := Label.new()
	r_lbl.text = "準備完了！ 🎮"
	r_lbl.add_theme_font_size_override("font_size", 36)
	r_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	vbox.add_child(r_lbl)

	if not _player_display.is_empty() or not _player_en.is_empty():
		var i_lbl := Label.new()
		var p_name : String = _player_display if not _player_display.is_empty() else _player_en
		var e_name : String = _enemy_display  if not _enemy_display.is_empty()  else _enemy_en
		i_lbl.text = "自機: %s  /  敵: %s" % [p_name, e_name]
		i_lbl.add_theme_font_size_override("font_size", 15)
		i_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
		vbox.add_child(i_lbl)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(sep)

	var start_btn := Button.new()
	start_btn.text = "▶  ゲームスタート！"
	start_btn.custom_minimum_size = Vector2(330, 70)
	start_btn.add_theme_font_size_override("font_size", 20)
	vbox.add_child(start_btn)
	start_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
