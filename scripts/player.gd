extends CharacterBody2D

const MOVE_SPEED      : float = 144.0
const MAX_HP          : int   = 3
const INVINCIBLE_TIME : float = 1.5
const HIT_RADIUS      : float = 55.0
const ATTRACT_RADIUS  : float = 2000.0

var target_pos      : Vector2 = Vector2.ZERO
var is_holding      : bool    = false
var attract_time    : float   = 0.0
var hp              : int     = 3
var invincible_timer: float   = 0.0
var is_invincible   : bool    = false

func _ready() -> void:
	add_to_group("player")
	target_pos = global_position

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
	if is_invincible:
		invincible_timer = invincible_timer - delta
		if invincible_timer <= 0.0:
			is_invincible = false

	if is_holding:
		attract_time = attract_time + delta
		_attract_bullets()
		var diff: Vector2 = target_pos - global_position
		var dist: float   = diff.length()
		if dist > 5.0:
			global_position = global_position + diff.normalized() * MOVE_SPEED * delta
	else:
		attract_time = 0.0

	if not is_invincible:
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		for i: int in enemies.size():
			var e: Node = enemies[i]
			if not is_instance_valid(e):
				continue
			var e2d: Node2D = e as Node2D
			if e2d == null:
				continue
			if global_position.distance_to(e2d.global_position) < HIT_RADIUS:
				_take_damage()
				break

	queue_redraw()

func _attract_bullets() -> void:
	var bullets: Array = get_tree().get_nodes_in_group("bullets")
	for i: int in bullets.size():
		var b: Node = bullets[i]
		if not is_instance_valid(b):
			continue
		if b.state != b.State.ORBITING_ENEMY:
			continue
		var b2d: Node2D = b as Node2D
		if b2d == null:
			continue
		if global_position.distance_to(b2d.global_position) <= ATTRACT_RADIUS:
			b.attract_to_player(self)

func _fire_all_bullets() -> void:
	# 発射済みの敵を記録して重複ターゲットを防ぐ
	var targeted: Array = []
	var bullets: Array = get_tree().get_nodes_in_group("bullets")
	for i: int in bullets.size():
		var b: Node = bullets[i]
		if not is_instance_valid(b):
			continue
		if b.state != b.State.ORBITING_PLAYER:
			continue
		var tgt: Node2D = _find_target_excluding(b, targeted)
		if tgt != null:
			b.fire_at(tgt)
			targeted.append(tgt)  # このターゲットを使用済みに

func _find_target_excluding(bullet: Node, excluded: Array) -> Node2D:
	var best: Node2D     = null
	var best_dist: float = INF
	var enemies: Array   = get_tree().get_nodes_in_group("enemies")
	for i: int in enemies.size():
		var e: Node = enemies[i]
		if not is_instance_valid(e):
			continue
		if bullet.is_white == e.is_white:
			continue
		if excluded.has(e):
			continue  # 既にターゲット済みの敵はスキップ
		var e2d: Node2D = e as Node2D
		if e2d == null:
			continue
		var d: float = bullet.global_position.distance_to(e2d.global_position)
		if d < best_dist:
			best_dist = d
			best      = e2d
	return best

func _take_damage() -> void:
	hp               = hp - 1
	is_invincible    = true
	invincible_timer = INVINCIBLE_TIME
	var main: Node = get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("update_hp"):
		main.update_hp(hp)
	if hp <= 0:
		_on_death()

func _on_death() -> void:
	print("GAME OVER")
	get_tree().paused = true

func _draw() -> void:
	if is_invincible:
		var t: float = fmod(invincible_timer, 0.2)
		if t < 0.1:
			return

	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.5, 1.0, 0.22))
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.7, 1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0, Color(0.7, 0.9, 1.0, 0.9))
	draw_circle(Vector2.ZERO,  5.0, Color(1.0, 1.0, 1.0, 1.0))

	if not is_holding:
		return

	for i: int in 3:
		var phase: float = fmod(attract_time * 2.0 + float(i) * 0.33, 1.0)
		var ring_r: float = 220.0 * (1.0 - phase)
		var alpha: float  = phase * 0.5
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48,
			Color(0.5, 0.8, 1.0, alpha), 1.5)

	draw_circle(Vector2.ZERO, 28.0, Color(0.3, 0.6, 1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.5, 0.8, 1.0, 0.4))
