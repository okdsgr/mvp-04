extends CharacterBody2D

const ATTRACT_RADIUS := 120.0
const ATTRACT_SPEED  := 280.0

var is_holding: bool = false
var held_souls: Array = []

func _ready() -> void:
	add_to_group("player")
	$Sprite2D.texture = load("res://assets/sprites/player_v3.png")
	$Sprite2D.scale = Vector2(0.15, 0.15)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			is_holding = true
		else:
			is_holding = false
			_release_souls()
	elif event is InputEventMouseButton:
		var me: InputEventMouseButton = event as InputEventMouseButton
		if me.button_index == MOUSE_BUTTON_LEFT:
			if me.pressed:
				is_holding = true
			else:
				is_holding = false
				_release_souls()

func _physics_process(delta: float) -> void:
	if is_holding:
		_attract_souls(delta)
	queue_redraw()

func _attract_souls(delta: float) -> void:
	for soul: Node in get_tree().get_nodes_in_group("souls"):
		if not is_instance_valid(soul):
			continue
		var dist: float = global_position.distance_to(soul.global_position)
		if dist < ATTRACT_RADIUS:
			if soul not in held_souls:
				held_souls.append(soul)
				soul.set_state_attracted()
			var dir: Vector2 = (global_position - soul.global_position).normalized()
			soul.global_position += dir * ATTRACT_SPEED * delta

func _release_souls() -> void:
	for soul: Node in held_souls:
		if not is_instance_valid(soul):
			continue
		var target: Node2D = _find_target(soul)
		if target:
			soul.set_homing_target(target)
		else:
			soul.set_state_free()
	held_souls.clear()

func _find_target(soul: Node) -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if soul.is_white != enemy.is_white:
			var d: float = soul.global_position.distance_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				best = enemy
	return best

func _draw() -> void:
	if not is_holding:
		return
	for soul: Node in held_souls:
		if not is_instance_valid(soul):
			continue
		var target: Node2D = _find_target(soul)
		if target:
			draw_line(
				to_local(soul.global_position),
				to_local(target.global_position),
				Color(1.0, 1.0, 1.0, 0.5),
				1.5
			)
