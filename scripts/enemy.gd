extends CharacterBody2D

@export var is_white: bool = true

const SPEED         : float = 84.0
const ATTRACT_DRIFT : float = 33.75

var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("enemies")
	direction = Vector2(randf_range(-0.4, 0.4), 1.0).normalized()

func _draw() -> void:
	if is_white:
		draw_circle(Vector2.ZERO, 44.0, Color(1.0, 1.0, 1.0, 0.12))
		draw_circle(Vector2.ZERO, 32.0, Color(1.0, 1.0, 1.0, 0.35))
		draw_circle(Vector2.ZERO, 20.0, Color(1.0, 1.0, 1.0, 0.8))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 1.0, 1.0, 1.0))
		draw_arc(Vector2.ZERO, 65.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.15), 0.8)
	else:
		draw_circle(Vector2.ZERO, 44.0, Color(0.6, 0.0, 0.8, 0.18))
		draw_circle(Vector2.ZERO, 32.0, Color(0.7, 0.1, 0.9, 0.45))
		draw_circle(Vector2.ZERO, 20.0, Color(0.85, 0.3, 1.0, 0.85))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.7, 1.0, 1.0))
		draw_arc(Vector2.ZERO, 65.0, 0.0, TAU, 48, Color(0.85, 0.3, 1.0, 0.2), 0.8)

func _physics_process(delta: float) -> void:
	var rect: Rect2 = get_viewport_rect()

	position = position + direction * SPEED * delta
	if position.x < 0.0 or position.x > rect.size.x:
		direction.x = direction.x * -1.0

	if position.y > rect.size.y + 60.0:
		queue_free()
		return

	# 吸い寄せ中：自機の方向にじりじりとドリフト
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node = players[0]
		if player.get("is_holding"):
			var player_pos: Vector2 = (player as Node2D).global_position
			var drift: Vector2 = (player_pos - global_position).normalized()
			position = position + drift * ATTRACT_DRIFT * delta

	queue_redraw()

func take_hit() -> void:
	var main: Node = get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_enemy_died"):
		main.on_enemy_died(self)
	queue_free()
