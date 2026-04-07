extends Node2D

# ===== WAVE設定 =====
const WAVE_DEFINITIONS : Array = [
	[2.0, 2, 0.08, [0.85, 0.12, 0.03, 0.00], 20],
	[1.8, 2, 0.10, [0.78, 0.18, 0.04, 0.00], 20],
	[1.5, 3, 0.14, [0.65, 0.25, 0.08, 0.02], 25],
	[1.3, 3, 0.22, [0.55, 0.28, 0.12, 0.05], 25],
	[1.1, 3, 0.32, [0.45, 0.30, 0.18, 0.07], 30],
	[0.9, 4, 0.42, [0.38, 0.30, 0.22, 0.10], 30],
	[0.8, 4, 0.55, [0.30, 0.28, 0.28, 0.14], 35],
	[0.7, 5, 0.68, [0.25, 0.28, 0.30, 0.17], 35],
	[0.6, 5, 0.80, [0.20, 0.25, 0.35, 0.20], 999],
]

const MAX_ENEMIES : int = 200
const WIN_W       : int = 405
const WIN_H       : int = 720

var enemy_scene:  PackedScene = preload("res://scenes/enemy.tscn")
var bullet_scene: PackedScene = preload("res://scenes/soul.tscn")
var player_scene: PackedScene = preload("res://scenes/player.tscn")

var score            : int   = 0
var _timer           : float = 0.0
var _color_balance   : int   = 0
var combo_count      : int   = 0
var combo_last_white : bool  = true
var combo_multiplier : float = 1.0

var current_wave      : int   = 0
var _wave_timer       : float = 0.0
var _in_wave_break    : bool  = false
var _wave_break_timer : float = 0.0
const WAVE_BREAK_DURATION : float = 3.0

var _spawn_interval : float = 2.0
var _spawn_batch    : int   = 2
var _color_factor   : float = 0.08
var _type_weights   : Array = [0.85, 0.12, 0.03, 0.00]
var _wave_duration  : float = 20.0

func _apply_window_size() -> void:
	DisplayServer.window_set_size(Vector2i(WIN_W, WIN_H))
	var scr : Vector2i = DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i((scr.x - WIN_W) / 2, (scr.y - WIN_H) / 2))
	print("window: ", DisplayServer.window_get_size())

func _ready() -> void:
	call_deferred("_apply_window_size")
	randomize()
	add_to_group("main")

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(10, 36)
	hp_label.text = "HP: 3"
	$UI.add_child(hp_label)

	var combo_label := Label.new()
	combo_label.name = "ComboLabel"
	combo_label.position = Vector2(10, 62)
	combo_label.text = ""
	$UI.add_child(combo_label)

	var mult_label := Label.new()
	mult_label.name = "MultLabel"
	mult_label.position = Vector2(10, 88)
	mult_label.text = ""
	$UI.add_child(mult_label)

	var wave_label := Label.new()
	wave_label.name = "WaveLabel"
	wave_label.position = Vector2(10, 114)
	wave_label.text = "WAVE 1"
	$UI.add_child(wave_label)

	var wave_msg := Label.new()
	wave_msg.name          = "WaveMsg"
	wave_msg.anchor_left   = 0.5
	wave_msg.anchor_right  = 0.5
	wave_msg.anchor_top    = 0.5
	wave_msg.anchor_bottom = 0.5
	wave_msg.position      = Vector2(-80.0, -60.0)
	wave_msg.visible       = false
	wave_msg.add_theme_font_size_override("font_size", 28)
	$UI.add_child(wave_msg)

	var rect : Rect2 = get_viewport_rect()
	var p : CharacterBody2D = player_scene.instantiate()
	p.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.82)
	add_child(p)

	_show_skin_select()

func _show_skin_select() -> void:
	var overlay := ColorRect.new()
	overlay.name  = "SkinOverlay"
	overlay.color = Color(0.05, 0.05, 0.1, 0.95)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-120.0, -80.0)
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "キャラクターを選んでね"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(sep)

	var skins : Array = ["default", "cat_car", "dog_cow"]
	var labels : Array = ["おばけ & 少年", "車 & 猫", "牛 & 犬"]
	for i: int in skins.size():
		var skin_name : String = skins[i]
		var btn := Button.new()
		btn.text = labels[i]
		btn.custom_minimum_size = Vector2(240, 48)
		vbox.add_child(btn)
		btn.pressed.connect(_on_skin_selected.bind(skin_name, overlay))

func _on_skin_selected(skin_name: String, overlay: Node) -> void:
	var sm : Node = get_node_or_null("/root/SkinManager")
	if sm:
		sm.set_skin(skin_name)
	overlay.queue_free()
	_start_wave(0)

func _start_wave(wave_idx: int) -> void:
	current_wave   = wave_idx
	_wave_timer    = 0.0
	_color_balance = 0

	var def_idx : int = mini(wave_idx, WAVE_DEFINITIONS.size() - 1)
	var def     : Array = WAVE_DEFINITIONS[def_idx]
	_spawn_interval = def[0]
	_spawn_batch    = def[1]
	_color_factor   = def[2]
	_type_weights   = def[3]
	_wave_duration  = float(def[4])

	$UI/WaveLabel.text = "WAVE %d" % (current_wave + 1)
	_show_wave_message("WAVE %d" % (current_wave + 1))

	for i: int in _spawn_batch:
		_spawn_enemy()

func _process(delta: float) -> void:
	if _in_wave_break:
		_wave_break_timer += delta
		if _wave_break_timer >= WAVE_BREAK_DURATION:
			_in_wave_break = false
			_start_wave(current_wave + 1)
		return

	_wave_timer += delta
	_timer      += delta

	if _wave_timer >= _wave_duration:
		_begin_wave_break()
		return

	if _timer >= _spawn_interval:
		_timer = 0.0
		var count    : int = $Enemies.get_child_count()
		var to_spawn : int = mini(_spawn_batch, MAX_ENEMIES - count)
		for i: int in to_spawn:
			_spawn_enemy()

	var remaining : float = maxf(_wave_duration - _wave_timer, 0.0)
	$UI/WaveLabel.text = "WAVE %d  %d" % [current_wave + 1, int(remaining) + 1]

func _begin_wave_break() -> void:
	_in_wave_break    = true
	_wave_break_timer = 0.0
	_timer            = 0.0
	for e : Node in $Enemies.get_children():
		e.queue_free()
	for s : Node in $Souls.get_children():
		s.queue_free()
	_show_wave_message("WAVE CLEAR!")

func _show_wave_message(msg: String) -> void:
	var lbl : Label = $UI/WaveMsg
	lbl.text    = msg
	lbl.visible = true
	get_tree().create_timer(2.0).timeout.connect(func(): lbl.visible = false)

func _pick_is_white() -> bool:
	var white_prob : float = 0.5 - float(_color_balance) * _color_factor
	white_prob = clamp(white_prob, 0.05, 0.95)
	var result : bool = randf() < white_prob
	_color_balance += 1 if result else -1
	return result

func _pick_enemy_type() -> int:
	var roll : float = randf()
	var cum  : float = 0.0
	for i: int in _type_weights.size():
		cum += _type_weights[i]
		if roll < cum:
			return i
	return 0

func _spawn_enemy() -> void:
	var rect : Rect2 = get_viewport_rect()
	var e : CharacterBody2D = enemy_scene.instantiate()
	e.is_white   = _pick_is_white()
	e.enemy_type = _pick_enemy_type()
	e.position   = Vector2(
		randf_range(60.0, rect.size.x - 60.0),
		randf_range(-80.0, -10.0)
	)
	$Enemies.add_child(e)

	var bullet_count : int = 2 if e.enemy_type == 1 else 1
	for bi: int in bullet_count:
		var b : Area2D = bullet_scene.instantiate()
		b.is_white     = e.is_white
		$Souls.add_child(b)
		b.orbit_center = e
		b.orbit_angle  = float(bi) * (TAU / float(bullet_count))
		b.state        = b.State.ORBITING_ENEMY

func on_enemy_died(enemy: Node) -> void:
	var killed_white : bool = enemy.is_white
	if combo_count == 0 or killed_white == combo_last_white:
		combo_count += 1
	else:
		combo_count = 1
	combo_last_white = killed_white
	combo_multiplier = 1.0 + float(combo_count - 1) * 0.5

	var base_score : int = 10
	if enemy.enemy_type == 2:
		base_score = 25
	elif enemy.enemy_type == 1:
		base_score = 15
	elif enemy.enemy_type == 3:
		base_score = 20

	var gain : int = int(float(base_score) * combo_multiplier)
	score = score + gain
	$UI/ScoreLabel.text = "Score: %d" % score
	_update_combo_ui()

func break_combo() -> void:
	if combo_count > 0:
		combo_count      = 0
		combo_multiplier = 1.0
		_update_combo_ui()

func _update_combo_ui() -> void:
	var combo_label : Label = $UI/ComboLabel
	var mult_label  : Label = $UI/MultLabel
	if combo_count >= 2:
		combo_label.text = "Combo x%d" % combo_count
		mult_label.text  = "x%.1f" % combo_multiplier
	else:
		combo_label.text = ""
		mult_label.text  = ""

func update_hp(hp: int) -> void:
	$UI/HPLabel.text = "HP: %d" % hp
