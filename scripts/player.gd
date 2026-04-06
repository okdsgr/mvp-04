extends CharacterBody2D

const MOVE_SPEED       := 144.0  # 3倍速
const HOLD_THRESHOLD   := 0.2
const MAX_HP           := 3
const INVINCIBLE_TIME  := 1.5
const HIT_RADIUS       := 55.0

var target_pos: Vector2 = Vector2.ZERO
var is_holding: bool = false
var press_time: float = 0.0

var hp: int = MAX_HP
var invincible_timer: float = 0.0
var is_invincible: bool = false

func _ready() -> void:
	add_to_group("player")
	target_pos = position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var me: InputEventMouseButton = event as InputEventMouseButton
		if me.button_index == MOUSE_BUTTON_LEFT:
			if me.pressed:
				is_holding = true
				press_time = 0.0
				target_pos = get_canvas_transform().affine_inverse() * me.position
			else:
				is_holding = false
				if press_time < HOLD_THRESHOLD:
					_fire_one_bullet()
	elif event is InputEventMouseMotion and is_holding:
		target_pos = get_canvas_transform().affine_inverse() * event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_holding = true
			press_time = 0.0
			target_pos = event.position
		else:
			is_holding = false
			if press_time < HOLD_THRESHOLD:
				_fire_one_bullet()
	elif event is InputEventScreenDrag and is_holding:
		target_pos = event.position

func _physics_process(delta: float) -> void:
	if is_invincible:
		invincible_timer -= delta
		if invincible_timer <= 0.0:
			is_invincible = false

	if is_holding:
		press_time += delta
		_attract_bullets()
		var dist := global_position.distance_to(target_pos)
		if dist > 5.0:
			global_position += (target_pos - global_position).normalized() * MOVE_SPEED * delta

	if not is_invincible:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if global_position.distance_to(enemy.global_position) < HIT_RADIUS:
				_take_damage()
				break

	queue_redraw()

func _take_damage() -> void:
	hp -= 1
	is_invincible = true
	invincible_timer = INVINCIBLE_TIME
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("update_hp"):
		main.update_hp(hp)
	if hp <= 0:
		_on_death()

func _on_death() -> void:
	print("GAME OVER")
	get_tree().paused = true

func _attract_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("bullets"):
		if not is_instance_valid(bullet):
			continue
		if bullet.state == bullet.State.ORBITING_ENEMY:
			bullet.attract_to_player(self)

func _fire_one_bullet() -> void:
	for bullet in get_tree().get_nodes_in_group("bullets"):
		if not is_instance_valid(bullet):
			continue
		if bullet.state == bullet.State.ORBITING_PLAYER:
			var target := _find_target(bullet)
			if target:
				bullet.fire_at(target)
			return

func _find_target(bullet: Node) -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if bullet.is_white != enemy.is_white:
			var d: float = bullet.global_position.distance_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				best = enemy
	return best

func _draw() -> void:
	if is_invincible and fmod(invincible_timer, 0.2) < 0.1:
		return
	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.5, 1.0, 0.22))
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.7, 1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0, Color(0.7, 0.9, 1.0, 0.9))
	draw_circle(Vector2.ZERO,  5.0, Color(1.0, 1.0, 1.0, 1.0))
