extends Node2D

const SPAWN_INTERVAL := 2.5

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var enemy_scene:  PackedScene = preload("res://scenes/enemy.tscn")
var soul_scene:   PackedScene = preload("res://scenes/soul.tscn")

var score: int = 0
var _timer: float = 0.0

func _ready() -> void:
	add_to_group("main")
	var p: CharacterBody2D = player_scene.instantiate()
	var rect: Rect2 = get_viewport_rect()
	p.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.85)
	add_child(p)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= SPAWN_INTERVAL:
		_timer = 0.0
		_spawn_enemy()

func _spawn_enemy() -> void:
	var e: CharacterBody2D = enemy_scene.instantiate()
	e.is_white = randf() > 0.5
	var rect: Rect2 = get_viewport_rect()
	e.position = Vector2(
		randf_range(40.0, rect.size.x - 40.0),
		randf_range(80.0, rect.size.y * 0.45)
	)
	$Enemies.add_child(e)

func spawn_soul_at(pos: Vector2, is_white: bool) -> void:
	var s: Area2D = soul_scene.instantiate()
	s.is_white = is_white
	s.global_position = pos
	$Souls.add_child(s)

func on_enemy_died(enemy: Node) -> void:
	spawn_soul_at(enemy.global_position, enemy.is_white)
	score += 10
	$UI/ScoreLabel.text = "Score: %d" % score
