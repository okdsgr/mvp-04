extends CharacterBody2D

@export var is_white: bool = true

const SPEED := 84.0  # 3倍速

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
		# 白敵：軌道リング
		draw_arc(Vector2.ZERO, 65.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.15), 0.8)
	else:
		draw_circle(Vector2.ZERO, 44.0, Color(0.6, 0.0, 0.8, 0.18))
		draw_circle(Vector2.ZERO, 32.0, Color(0.7, 0.1, 0.9, 0.45))
		draw_circle(Vector2.ZERO, 20.0, Color(0.85, 0.3, 1.0, 0.85))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.7, 1.0, 1.0))
		# 黒敵：軌道リング
		draw_arc(Vector2.ZERO, 65.0, 0.0, TAU, 48, Color(0.85, 0.3, 1.0, 0.2), 0.8)

func _physics_process(delta: float) -> void:
	var rect: Rect2 = get_viewport_rect()
	position += direction * SPEED * delta
	if position.x < 0.0 or position.x > rect.size.x:
		direction.x *= -1.0
	if position.y > rect.size.y + 60.0:
		position.y = -60.0
		position.x = randf_range(60.0, rect.size.x - 60.0)
	queue_redraw()

func take_hit() -> void:
	var main: Node = get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_enemy_died"):
		main.on_enemy_died(self)
	queue_free()
