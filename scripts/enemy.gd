extends CharacterBody2D

@export var is_white: bool = true

const SPEED := 120.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	add_to_group("enemies")
	var tex_path := "res://assets/sprites/enemy_white_v3.png" if is_white else "res://assets/sprites/enemy_black_v3.png"
	$Sprite2D.texture = load(tex_path)
	$Sprite2D.scale = Vector2(0.15, 0.15)
	var angle: float = randf_range(0.0, TAU)
	direction = Vector2(cos(angle), sin(angle))

func _physics_process(delta: float) -> void:
	var rect: Rect2 = get_viewport_rect()
	position += direction * SPEED * delta
	if position.x < 0.0 or position.x > rect.size.x:
		direction.x *= -1.0
	if position.y < 0.0 or position.y > rect.size.y:
		direction.y *= -1.0
	position = position.clamp(Vector2.ZERO, rect.size)

func take_hit() -> void:
	var main: Node = get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_enemy_died"):
		main.on_enemy_died(self)
	queue_free()
