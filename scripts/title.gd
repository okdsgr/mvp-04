extends Node2D

const GAME_TITLE : String = "SOUL PULL"
const N8N_URL    : String = "https://okdsgr.app.n8n.cloud/webhook/sprite-to-mvp04"
const VP_W       : float  = 540.0
const VP_H       : float  = 960.0

enum Screen { TITLE, MENU, CUSTOMIZE, GENERATING, READY }
var _screen : Screen = Screen.TITLE
var _anim   : float  = 0.0

# 背景オーブ
var _orbs : Array = []

# カスタム入力
var _player_text : String = ""
var _enemy_text  : String = ""

# 生成
var _gen_queue   : Array        = []
var _gen_current : int          = 0
var _http        : HTTPRequest  = null
var _progress_bar: ProgressBar  = null
var _progress_lbl: Label        = null
var _step_lbl    : Label        = null

var _ui : CanvasLayer = null

const STEP_NAMES : Array = ["自機（待機）を生成中", "自機（歩き）を生成中", "白い敵を生成中", "黒い敵を生成中"]

func _ready() -> void:
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
			draw_circle(pos, r,       Color(0.75, 0.2, 1.0,  0.45 * pulse))

func _clear_ui() -> void:
	for c : Node in _ui.get_children():
		c.queue_free()

# ================================================
# TITLE
# ================================================
func _show_title() -> void:
	_screen = Screen.TITLE
	_clear_ui()

	var cx : float = VP_W * 0.5

	var title_lbl := Label.new()
	title_lbl.text = GAME_TITLE
	title_lbl.add_theme_font_size_override("font_size", 64)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0, 1.0))
	title_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_lbl.position = Vector2(cx - 160.0, 220.0)
	_ui.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "— attract & release —"
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.9, 0.8))
	sub_lbl.position = Vector2(cx - 110.0, 310.0)
	_ui.add_child(sub_lbl)

	var press_lbl := Label.new()
	press_lbl.text = "Tap or Press Any Key"
	press_lbl.add_theme_font_size_override("font_size", 18)
	press_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1.0))
	press_lbl.position = Vector2(cx - 105.0, 560.0)
	_ui.add_child(press_lbl)

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(press_lbl, "modulate:a", 0.15, 0.75)
	tween.tween_property(press_lbl, "modulate:a", 1.0,  0.75)

# ================================================
# MENU
# ================================================
func _show_menu() -> void:
	_screen = Screen.MENU
	_clear_ui()

	var cx : float = VP_W * 0.5

	var title_lbl := Label.new()
	title_lbl.text = GAME_TITLE
	title_lbl.add_theme_font_size_override("font_size", 44)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0, 1.0))
	title_lbl.position = Vector2(cx - 112.0, 160.0)
	_ui.add_child(title_lbl)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 145.0, 320.0)
	vbox.add_theme_constant_override("separation", 20)
	_ui.add_child(vbox)

	var start_btn := Button.new()
	start_btn.text = "▶   すぐに始める"
	start_btn.custom_minimum_size = Vector2(290, 60)
	vbox.add_child(start_btn)
	start_btn.pressed.connect(_on_start_default)

	var custom_btn := Button.new()
	custom_btn.text = "✦   カスタマイズ"
	custom_btn.custom_minimum_size = Vector2(290, 60)
	vbox.add_child(custom_btn)
	custom_btn.pressed.connect(_show_customize)

func _on_start_default() -> void:
	var sm : Node = get_node_or_null("/root/SkinManager")
	if sm:
		sm.set_skin("default")
		sm.confirm_skin()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ================================================
# CUSTOMIZE
# ================================================
func _show_customize() -> void:
	_screen = Screen.CUSTOMIZE
	_clear_ui()

	var cx : float = VP_W * 0.5

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 150.0, 120.0)
	vbox.add_theme_constant_override("separation", 14)
	_ui.add_child(vbox)

	var title := Label.new()
	title.text = "キャラクターをカスタマイズ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var sep1 := Control.new()
	sep1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sep1)

	var player_lbl := Label.new()
	player_lbl.text = "自機（例：ロボット、忍者、うさぎ）"
	player_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(player_lbl)

	var player_edit := LineEdit.new()
	player_edit.name = "PlayerEdit"
	player_edit.placeholder_text = "自機のキャラクターを入力..."
	player_edit.custom_minimum_size = Vector2(300, 46)
	player_edit.add_theme_font_size_override("font_size", 16)
	vbox.add_child(player_edit)

	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(sep2)

	var enemy_lbl := Label.new()
	enemy_lbl.text = "敵（例：ドラゴン、ペンギン、ピザ）"
	enemy_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(enemy_lbl)

	var enemy_edit := LineEdit.new()
	enemy_edit.name = "EnemyEdit"
	enemy_edit.placeholder_text = "敵のキャラクターを入力..."
	enemy_edit.custom_minimum_size = Vector2(300, 46)
	enemy_edit.add_theme_font_size_override("font_size", 16)
	vbox.add_child(enemy_edit)

	var sep3 := Control.new()
	sep3.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(sep3)

	var gen_btn := Button.new()
	gen_btn.text = "✦  生成開始"
	gen_btn.custom_minimum_size = Vector2(300, 62)
	gen_btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(gen_btn)
	gen_btn.pressed.connect(func():
		_player_text = player_edit.text.strip_edges()
		_enemy_text  = enemy_edit.text.strip_edges()
		if _player_text.is_empty() or _enemy_text.is_empty():
			return
		_start_generation()
	)

	var back_btn := Button.new()
	back_btn.text = "← 戻る"
	back_btn.custom_minimum_size = Vector2(300, 44)
	vbox.add_child(back_btn)
	back_btn.pressed.connect(_show_menu)

# ================================================
# GENERATING
# ================================================
func _start_generation() -> void:
	_screen = Screen.GENERATING
	_clear_ui()

	var cx : float = VP_W * 0.5

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 150.0, 260.0)
	vbox.add_theme_constant_override("separation", 18)
	_ui.add_child(vbox)

	var title := Label.new()
	title.text = "スプライトを生成中..."
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_progress_lbl = Label.new()
	_progress_lbl.text = "0 / 4"
	_progress_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_progress_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 4.0
	_progress_bar.value     = 0.0
	_progress_bar.custom_minimum_size = Vector2(300, 28)
	vbox.add_child(_progress_bar)

	_step_lbl = Label.new()
	_step_lbl.text = "⏳ 準備中..."
	_step_lbl.add_theme_font_size_override("font_size", 14)
	_step_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	vbox.add_child(_step_lbl)

	# HTTPRequest
	_http = HTTPRequest.new()
	_http.timeout = 120.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_gen_current = 0
	_gen_queue   = _build_queue()
	_send_next()

func _build_queue() -> Array:
	return [
		{
			"filename": "player_custom_idle",
			"prompt":   "cute chibi %s character, back view, standing idle pose, white background, game sprite pixel art" % _player_text,
		},
		{
			"filename": "player_custom_walk",
			"prompt":   "cute chibi %s character, back view, walking pose mid-step, white background, game sprite pixel art" % _player_text,
		},
		{
			"filename": "enemy_custom_white",
			"prompt":   "cute white %s, chibi style, round chubby body, bright white color scheme, white background, game sprite pixel art" % _enemy_text,
		},
		{
			"filename": "enemy_custom_black",
			"prompt":   "cute dark black %s, chibi style, round chubby body, dark color scheme, white background, game sprite pixel art" % _enemy_text,
		},
	]

func _send_next() -> void:
	if _gen_current >= _gen_queue.size():
		_on_all_generated()
		return

	var item : Dictionary = _gen_queue[_gen_current]
	if is_instance_valid(_step_lbl):
		_step_lbl.text = "⏳ %s..." % STEP_NAMES[_gen_current]
	if is_instance_valid(_progress_lbl):
		_progress_lbl.text = "%d / %d" % [_gen_current, _gen_queue.size()]
	if is_instance_valid(_progress_bar):
		_progress_bar.value = float(_gen_current)

	var body    : String           = JSON.stringify(item)
	var headers : PackedStringArray = ["Content-Type: application/json"]
	_http.request(N8N_URL, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_gen_current += 1
	if is_instance_valid(_progress_bar):
		_progress_bar.value = float(_gen_current)
	if is_instance_valid(_progress_lbl):
		_progress_lbl.text = "%d / %d" % [_gen_current, _gen_queue.size()]
	if is_instance_valid(_step_lbl) and _gen_current < STEP_NAMES.size():
		_step_lbl.text = "✓ %s 完了" % STEP_NAMES[_gen_current - 1]
	_send_next()

func _on_all_generated() -> void:
	# git pull で新しいスプライトを取得
	if is_instance_valid(_step_lbl):
		_step_lbl.text = "⏳ スプライトを同期中..."
	var path : String = ProjectSettings.globalize_path("res://")
	var out   : Array  = []
	OS.execute("git", ["-C", path, "pull"], out, true)

	# SkinManager にカスタムスキンを登録
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
		})
		sm.set_skin("custom")
		sm.confirm_skin()

	_show_ready()

# ================================================
# READY
# ================================================
func _show_ready() -> void:
	_screen = Screen.READY
	_clear_ui()

	if is_instance_valid(_http):
		_http.queue_free()
		_http = null

	var cx : float = VP_W * 0.5

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 150.0, 280.0)
	vbox.add_theme_constant_override("separation", 20)
	_ui.add_child(vbox)

	var ready_lbl := Label.new()
	ready_lbl.text = "準備完了！ 🎮"
	ready_lbl.add_theme_font_size_override("font_size", 36)
	ready_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
	vbox.add_child(ready_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "自機: %s  /  敵: %s" % [_player_text, _enemy_text]
	info_lbl.add_theme_font_size_override("font_size", 15)
	info_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
	vbox.add_child(info_lbl)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(sep)

	var start_btn := Button.new()
	start_btn.text = "▶  ゲームスタート！"
	start_btn.custom_minimum_size = Vector2(300, 66)
	start_btn.add_theme_font_size_override("font_size", 20)
	vbox.add_child(start_btn)
	start_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
