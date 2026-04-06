extends Node2D

const SPAWN_INTERVAL       : float = 1.2
const SPAWN_BATCH          : int   = 3
const MAX_ENEMIES          : int   = 200
const COLOR_BALANCE_FACTOR : float = 0.12

var enemy_scene:  PackedScene = preload("res://scenes/enemy.tscn")
var bullet_scene: PackedScene = preload("res://scenes/soul.tscn")
var player_scene: PackedScene = preload("res://scenes/player.tscn")

var score          : int   = 0
var _timer         : float = 0.0
var _color_balance : int   = 0

var combo_count      : int   = 0
var combo_last_white : bool  = true
var combo_multiplier : float = 1.0

func _ready() -> void:
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

	var rect : Rect2 = get_viewport_rect()
	var p : CharacterBody2D = player_scene.instantiate()
	p.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.82)
	add_child(p)

	for i: int in SPAWN_BATCH:
		_spawn_enemy()

func _pick_is_white() -> bool:
	var white_prob : float = 0.5 - float(_color_balance) * COLOR_BALANCE_FACTOR
	white_prob = clamp(white_prob, 0.05, 0.95)
	var result : bool = randf() < white_prob
	_color_balance += 1 if result else -1
	return result

func _pick_enemy_type() -> int:
	# NORMAL:55% FAST:25% TOUGH:12% BOMBER:8%
	var roll : float = randf()
	if roll < 0.55:
		return 0  # NORMAL
	elif roll < 0.80:
		return 1  # FAST
	elif roll < 0.92:
		return 2  # TOUGH
	else:
		return 3  # BOMBER

func _process(delta: float) -> void:
	_timer = _timer + delta
	if _timer >= SPAWN_INTERVAL:
		_timer = 0.0
		var count    : int = $Enemies.get_child_count()
		var to_spawn : int = mini(SPAWN_BATCH, MAX_ENEMIES - count)
		for i: int in to_spawn:
			_spawn_enemy()

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

	# FASTは弾2個、それ以外は1個
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
	if enemy.enemy_type == 2:   # TOUGH
		base_score = 25
	elif enemy.enemy_type == 1: # FAST
		base_score = 15
	elif enemy.enemy_type == 3: # BOMBER
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
