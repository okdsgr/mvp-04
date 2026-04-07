extends CharacterBody2D

const MOVE_SPEED      : float = 144.0
const MAX_HP          : int   = 3
const INVINCIBLE_TIME : float = 1.5
const HIT_RADIUS      : float = 55.0
const ATTRACT_RADIUS  : float = 2000.0
const WALK_INTERVAL   : float = 0.18

var target_pos      : Vector2 = Vector2.ZERO
var is_holding      : bool    = false
var attract_time    : float   = 0.0
var hp              : int     = 3
var invincible_timer: float   = 0.0
var is_invincible   : bool    = false

var has_shield   : bool = false
var pierce_count : int  = 0

var _anim_time  : float    = 0.0
var _walk_frame : int      = 0
var _walk_timer : float    = 0.0
var _sprite     : Sprite2D = null

var _tex_idle       : Texture2D = null
var _tex_walk       : Texture2D = null
var _tex_raise      : Texture2D = null
var _tex_raise_walk : Texture2D = null

func _ready() -> void:
	add_to_group("player")
	target_pos = global_position

	# SkinManager からテクスチャを取得
	var sm = get_node_or_null("/root/SkinManager")
	if sm:
		_tex_idle       = sm.get_texture("player_idle")
		_tex_walk       = sm.get_texture("player_walk")
		_tex_raise      = sm.get_texture("player_raise")
		_tex_raise_walk = sm.get_texture("player_raise_walk")
	else:
		# フォールバック（SkinManager未登録時）
		if ResourceLoader.exists("res://assets/sprites/player_idle.png"):
			_tex_idle = load("res://assets/sprites/player_idle.png")
		if ResourceLoader.exists("res://assets/sprites/player_walk.png"):
			_tex_walk = load("res://assets/sprites/player_walk.png")
		if ResourceLoader.exists("res://assets/sprites/player_raise.png"):
			_tex_raise = load("res://assets/sprites/player_raise.png")
		if ResourceLoader.exists("res://assets/sprites/player_raise_walk.png"):
			_tex_raise_walk = load("res://assets/sprites/player_raise_walk.png")

	_sprite = Sprite2D.new()
	_sprite.name  = "PlayerSprite"
	_sprite.scale = Vector2(0.45, 0.45)
	if _tex_idle:
		_sprite.texture = _tex_idle
	add_child(_sprite)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var me: InputEventMouseButton = event as InputEventMouseButton
		if me.button_index == MOUSE_BUTTON_LEFT:
			if me.pressed:
				is_holding   = true
				attract_time = 0.0
				target_pos   = get_global_mouse_position()
			else:
				is_holding = false
				_fire_all_bullets()
	elif event is InputEventMouseMotion:
		if is_holding:
			target_pos = get_global_mouse_position()
	elif event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event as InputEventScreenTouch
		if te.pressed:
			is_holding   = true
			attract_time = 0.0
			target_pos   = te.position
		else:
			is_holding = false
			_fire_all_bullets()
	elif event is InputEventScreenDrag:
		if is_holding:
			var de: InputEventScreenDrag = event as InputEventScreenDrag
			target_pos = de.position

func _physics_process(delta: float) -> void:
	_anim_time += delta

	if is_invincible:
		invincible_timer -= delta
		if invincible_timer <= 0.0:
			is_invincible = false

	var is_moving : bool = false
	if is_holding:
		attract_time += delta
		_attract_bullets()
		var diff : Vector2 = target_pos - global_position
		if diff.length() > 5.0:
			global_position += diff.normalized() * MOVE_SPEED * delta
			is_moving = true
	else:
		attract_time = 0.0

	_update_sprite(delta, is_moving)

	if not is_invincible:
		var enemies : Array = get_tree().get_nodes_in_group("enemies")
		for i: int in enemies.size():
			var e   : Node   = enemies[i]
			if not is_instance_valid(e):
				continue
			var e2d : Node2D = e as Node2D
			if e2d == null:
				continue
			if global_position.distance_to(e2d.global_position) < HIT_RADIUS:
				_take_damage()
				break

	queue_redraw()

func _update_sprite(delta: float, is_moving: bool) -> void:
	if _sprite == null:
		return

	if is_invincible:
		_sprite.visible = fmod(invincible_timer, 0.2) >= 0.1
	else:
		_sprite.visible = true

	_walk_timer += delta
	if _walk_timer >= WALK_INTERVAL:
		_walk_timer = 0.0
		_walk_frame = (_walk_frame + 1) % 2

	if is_holding:
		if is_moving:
			var tex : Texture2D = _tex_raise_walk if (_walk_frame == 1 and _tex_raise_walk != null) else (_tex_raise if _tex_raise != null else _tex_idle)
			_sprite.texture  = tex
			_sprite.position = Vector2(0.0, sin(_anim_time * 8.0) * 2.5)
		else:
			if _tex_raise:
				_sprite.texture = _tex_raise
			_sprite.position = Vector2(0.0, sin(_anim_time * 2.0) * 1.5)
	else:
		if is_moving:
			var tex : Texture2D = _tex_walk if (_walk_frame == 1 and _tex_walk != null) else (_tex_idle if _tex_idle != null else _sprite.texture)
			_sprite.texture  = tex
			_sprite.position = Vector2(0.0, sin(_anim_time * 8.0) * 2.5)
		else:
			if _tex_idle:
				_sprite.texture = _tex_idle
			_sprite.position = Vector2(0.0, sin(_anim_time * 2.0) * 1.5)
			_walk_timer = 0.0

func _attract_bullets() -> void:
	var bullets : Array = get_tree().get_nodes_in_group("bullets")
	for i: int in bullets.size():
		var b   : Node = bullets[i]
		if not is_instance_valid(b):
			continue
		if b.state != b.State.ORBITING_ENEMY:
			continue
		var b2d : Node2D = b as Node2D
		if b2d == null:
			continue
		if global_position.distance_to(b2d.global_position) <= ATTRACT_RADIUS:
			b.attract_to_player(self)

func _fire_all_bullets() -> void:
	var targeted     : Array = []
	var bullets      : Array = get_tree().get_nodes_in_group("bullets")
	var all_piercing : bool  = pierce_count > 0

	for i: int in bullets.size():
		var b : Node = bullets[i]
		if not is_instance_valid(b):
			continue
		if b.state != b.State.ORBITING_PLAYER:
			continue
		var tgt : Node2D = _find_target_excluding(b, targeted)
		if tgt != null:
			if all_piercing:
				b.set("is_piercing", true)
			b.fire_at(tgt)
			targeted.append(tgt)

	if all_piercing:
		pierce_count = 0

func _find_target_excluding(bullet: Node, excluded: Array) -> Node2D:
	var best      : Node2D = null
	var best_dist : float  = INF
	var enemies   : Array  = get_tree().get_nodes_in_group("enemies")
	for i: int in enemies.size():
		var e   : Node   = enemies[i]
		if not is_instance_valid(e):
			continue
		if bullet.is_white == e.is_white:
			continue
		if excluded.has(e):
			continue
		var e2d : Node2D = e as Node2D
		if e2d == null:
			continue
		var d : float = bullet.global_position.distance_to(e2d.global_position)
		if d < best_dist:
			best_dist = d
			best      = e2d
	return best

func _take_damage() -> void:
	if has_shield:
		has_shield       = false
		is_invincible    = true
		invincible_timer = INVINCIBLE_TIME
		return
	hp               = hp - 1
	is_invincible    = true
	invincible_timer = INVINCIBLE_TIME
	var main : Node = get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("update_hp"):
		main.update_hp(hp)
	if hp <= 0:
		_on_death()

func _on_death() -> void:
	print("GAME OVER")
	get_tree().paused = true

func _draw() -> void:
	if has_shield:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color(0.2, 0.9, 0.4, 0.8), 2.0)
	if pierce_count > 0:
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.2, 0.2, 0.2))
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.3, 0.6), 1.5)
	draw_circle(Vector2.ZERO, 26.0, Color(0.2, 0.5, 1.0, 0.15))
	draw_circle(Vector2.ZERO, 18.0, Color(0.4, 0.7, 1.0, 0.22))
	if not is_holding:
		return
	for i: int in 3:
		var phase  : float = fmod(attract_time * 2.0 + float(i) * 0.33, 1.0)
		var ring_r : float = 220.0 * (1.0 - phase)
		var alpha  : float = phase * 0.5
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, alpha), 1.5)
	draw_circle(Vector2.ZERO, 28.0, Color(0.3, 0.6, 1.0, 0.28))
