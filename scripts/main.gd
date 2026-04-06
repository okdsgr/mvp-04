extends Node2D

const SPAWN_INTERVAL       := 6.0
const MAX_ENEMIES          := 20   # 弾最大20個に対応
const BULLETS_PER_ENEMY    := 1
const COLOR_BALANCE_FACTOR := 0.12 # 平準値（高いほど色が均等になる）

var enemy_scene:  PackedScene = preload("res://scenes/enemy.tscn")
var bullet_scene: PackedScene = preload("res://scenes/soul.tscn")
var player_scene: PackedScene = preload("res://scenes/player.tscn")

var score: int = 0
var _timer: float = 0.0
var _color_balance: int = 0  # 正=白過多、負=黒過多

func _ready() -> void:
	randomize()
	add_to_group("main")

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.position = Vector2(10, 36)
	hp_label.text = "HP: 3"
	$UI.add_child(hp_label)

	var rect: Rect2 = get_viewport_rect()
	var p: CharacterBody2D = player_scene.instantiate()
	p.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.82)
	add_child(p)
	_spawn_enemy()

func _pick_is_white() -> bool:
	# 同じ色が続くほど反対色が出やすくなる
	var white_prob := 0.5 - (_color_balance * COLOR_BALANCE_FACTOR)
	white_prob = clamp(white_prob, 0.05, 0.95)
	var result := randf() < white_prob
	_color_balance += 1 if result else -1
	return result

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= SPAWN_INTERVAL:
		_timer = 0.0
		if $Enemies.get_child_count() < MAX_ENEMIES:
			_spawn_enemy()

func _spawn_enemy() -> void:
	var rect: Rect2 = get_viewport_rect()
	var e: CharacterBody2D = enemy_scene.instantiate()
	e.is_white = _pick_is_white()
	e.position = Vector2(
		randf_range(60.0, rect.size.x - 60.0),
		randf_range(-40.0, 40.0)
	)
	$Enemies.add_child(e)

	var b: Area2D = bullet_scene.instantiate()
	b.is_white = e.is_white
	$Souls.add_child(b)
	b.orbit_center = e
	b.orbit_angle = 0.0
	b.state = b.State.ORBITING_ENEMY

func on_enemy_died(_enemy: Node) -> void:
	score += 10
	$UI/ScoreLabel.text = "Score: %d" % score

func update_hp(hp: int) -> void:
	$UI/HPLabel.text = "HP: %d" % hp
