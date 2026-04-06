extends CharacterBody2D

enum EnemyType { NORMAL, FAST, TOUGH, BOMBER }

@export var is_white    : bool      = true
@export var enemy_type  : EnemyType = EnemyType.NORMAL

const BASE_SPEED    : float = 84.0
const ATTRACT_DRIFT : float = 33.75
const DROP_CHANCE   : float = 0.115
const ANIM_INTERVAL : float = 0.35

var direction  : Vector2 = Vector2.DOWN
var hp         : int     = 1
var _radius    : float   = 44.0
var _speed     : float   = BASE_SPEED
var _anim_time : float   = 0.0
var _anim_frame: int     = 0
var _anim_timer: float   = 0.0
var _base_scale: Vector2 = Vector2(0.5, 0.5)  # スケールをキャッシュ

var _tex_a : Texture2D = null
var _tex_b : Texture2D = null

var item_scene : PackedScene = preload("res://scenes/item.tscn")

func _ready() -> void:
	add_to_group("enemies")

	match enemy_type:
		EnemyType.FAST:
			hp           = 1
			_radius      = 24.0
			_speed       = BASE_SPEED * 2.2
			_base_scale  = Vector2(0.28, 0.28)
		EnemyType.TOUGH:
			hp           = 2
			_radius      = 58.0
			_speed       = BASE_SPEED * 0.6
			_base_scale  = Vector2(0.68, 0.68)
		EnemyType.BOMBER:
			hp           = 1
			_radius      = 44.0
			_speed       = BASE_SPEED * 0.85
			_base_scale  = Vector2(0.5, 0.5)
		_:
			hp           = 1
			_radius      = 44.0
			_speed       = BASE_SPEED
			_base_scale  = Vector2(0.5, 0.5)

	direction = Vector2(randf_range(-0.4, 0.4), 1.0).normalized()

	if is_white:
		_tex_a = load("res://assets/sprites/ghost_detailed.png")
		_tex_b = load("res://assets/sprites/ghost_white_anim.png") if ResourceLoader.exists("res://assets/sprites/ghost_white_anim.png") else _tex_a
	else:
		_tex_a = load("res://assets/sprites/ghost_black_retro_v3.png")
		_tex_b = load("res://assets/sprites/ghost_black_anim.png") if ResourceLoader.exists("res://assets/sprites/ghost_black_anim.png") else _tex_a

	$Sprite2D.texture = _tex_a
	$Sprite2D.scale   = _base_scale  # 初期スケールを設定

	_anim_timer = randf_range(0.0, ANIM_INTERVAL)

func _draw() -> void:
	var base_alpha : float = 0.8 if enemy_type == EnemyType.TOUGH else 1.0
	if is_white:
		draw_circle(Vector2.ZERO, _radius * 1.1,  Color(1.0, 1.0, 1.0, 0.06 * base_alpha))
		draw_circle(Vector2.ZERO, _radius * 0.82, Color(1.0, 1.0, 1.0, 0.10 * base_alpha))
		draw_circle(Vector2.ZERO, _radius * 0.55, Color(1.0, 1.0, 1.0, 0.18 * base_alpha))
	else:
		draw_circle(Vector2.ZERO, _radius * 1.1,  Color(0.6, 0.0, 0.9, 0.08 * base_alpha))
		draw_circle(Vector2.ZERO, _radius * 0.82, Color(0.7, 0.1, 1.0, 0.14 * base_alpha))
		draw_circle(Vector2.ZERO, _radius * 0.55, Color(0.85, 0.3, 1.0, 0.22 * base_alpha))

	match enemy_type:
		EnemyType.FAST:
			draw_line(Vector2(-_radius, 0), Vector2(_radius, 0), Color(1.0, 1.0, 0.3, 0.5), 1.5)
			draw_line(Vector2(0, -_radius), Vector2(0, _radius), Color(1.0, 1.0, 0.3, 0.5), 1.5)
		EnemyType.TOUGH:
			draw_arc(Vector2.ZERO, _radius * 1.05, 0.0, TAU, 48, Color(1.0, 0.5, 0.1, 0.6), 2.0)
			if hp == 2:
				draw_arc(Vector2.ZERO, _radius * 0.9, 0.0, TAU, 48, Color(1.0, 0.7, 0.2, 0.35), 1.0)
		EnemyType.BOMBER:
			var pulse : float = abs(sin(_anim_time * 3.0))
			draw_arc(Vector2.ZERO, _radius * 1.05, 0.0, TAU, 48, Color(1.0, 0.2, 0.2, pulse * 0.7), 2.0)
			var s : float = _radius * 0.45
			draw_line(Vector2(-s, -s), Vector2( s,  s), Color(1.0, 0.3, 0.3, 0.6 + pulse * 0.3), 2.0)
			draw_line(Vector2( s, -s), Vector2(-s,  s), Color(1.0, 0.3, 0.3, 0.6 + pulse * 0.3), 2.0)

func _physics_process(delta: float) -> void:
	_anim_time  += delta
	_anim_timer += delta

	# フレーム切り替え：テクスチャのみ、スケールは絶対に変えない
	if _anim_timer >= ANIM_INTERVAL:
		_anim_timer = 0.0
		_anim_frame = (_anim_frame + 1) % 2
		$Sprite2D.texture = _tex_b if _anim_frame == 1 else _tex_a

	var rect : Rect2 = get_viewport_rect()
	position = position + direction * _speed * delta

	if position.x < 0.0 or position.x > rect.size.x:
		direction.x = direction.x * -1.0

	$Sprite2D.flip_h = direction.x > 0.0

	# ふわふわアニメ：positionのみ、scaleには絶対触れない
	match enemy_type:
		EnemyType.FAST:
			$Sprite2D.position = Vector2(0.0, sin(_anim_time * 5.0) * 2.0)
		EnemyType.TOUGH:
			$Sprite2D.position = Vector2(0.0, sin(_anim_time * 1.2) * 4.0)
			$Sprite2D.rotation = sin(_anim_time * 1.0) * 0.06
		_:
			$Sprite2D.position = Vector2(0.0, sin(_anim_time * 2.2) * 3.0)
			$Sprite2D.rotation = sin(_anim_time * 1.8) * 0.04

	if position.y > rect.size.y + 60.0:
		var main : Node = get_tree().get_first_node_in_group("main")
		if main and main.has_method("break_combo"):
			main.break_combo()
		queue_free()
		return

	var players : Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player : Node = players[0]
		if player.get("is_holding"):
			var player_pos : Vector2 = (player as Node2D).global_position
			var drift      : Vector2 = (player_pos - global_position).normalized()
			position = position + drift * ATTRACT_DRIFT * delta

	queue_redraw()

func take_hit() -> void:
	hp = hp - 1
	if hp > 0:
		queue_redraw()
		return

	if enemy_type == EnemyType.BOMBER:
		_explode()
		# 爆発はその場固定（velocity=ZERO）、大きめ
		_spawn_effect("explosion", Vector2.ZERO)
	else:
		# 煙は敵の移動ベクトルを引き継ぐ
		_spawn_effect("smoke", direction * _speed)

	_try_drop_item()
	var main : Node = get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_enemy_died"):
		main.on_enemy_died(self)
	queue_free()

func _spawn_effect(type: String, vel: Vector2) -> void:
	var effect : Node2D = Node2D.new()
	effect.set_script(load("res://scripts/effect.gd"))
	get_tree().current_scene.add_child(effect)
	effect.setup(type, global_position, vel)

func _explode() -> void:
	const BLAST_RADIUS : float = 160.0
	var bullets : Array = get_tree().get_nodes_in_group("bullets")
	for b : Node in bullets:
		if not is_instance_valid(b):
			continue
		var b2d : Node2D = b as Node2D
		if b2d == null:
			continue
		if global_position.distance_to(b2d.global_position) < BLAST_RADIUS:
			if b.state == b.State.HOMING_PLAYER or b.state == b.State.ORBITING_PLAYER:
				if b.has_method("set_state_free"):
					b.call("set_state_free")

func _try_drop_item() -> void:
	var chance : float = DROP_CHANCE
	if enemy_type == EnemyType.TOUGH:
		chance = 0.2
	elif enemy_type == EnemyType.BOMBER:
		chance = 0.15
	if randf() > chance:
		return
	var item : Area2D = item_scene.instantiate()
	var roll : float  = randf()
	if roll < 0.35:
		item.item_type = 0
	elif roll < 0.65:
		item.item_type = 1
	elif roll < 0.85:
		item.item_type = 2
	else:
		item.item_type = 3
	item.global_position = global_position
	get_tree().current_scene.add_child(item)
