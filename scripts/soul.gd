extends Area2D

@export var is_white: bool = true

enum State { FREE, ATTRACTED, HOMING }

var state: State = State.FREE
var velocity: Vector2 = Vector2.ZERO
var homing_target: Node2D = null

const FLOAT_SPEED  := 50.0
const HOMING_SPEED := 350.0

func _ready() -> void:
	add_to_group("souls")
	var tex_path := "res://assets/sprites/soul_white_v3.png" if is_white else "res://assets/sprites/soul_black_v3.png"
	$Sprite2D.texture = load(tex_path)
	$Sprite2D.scale = Vector2(0.1, 0.1)
	var angle: float = randf_range(0.0, TAU)
	velocity = Vector2(cos(angle), sin(angle)) * FLOAT_SPEED

func _physics_process(delta: float) -> void:
	var rect: Rect2 = get_viewport_rect()
	match state:
		State.FREE:
			position += velocity * delta
			if position.x < 0.0 or position.x > rect.size.x:
				velocity.x *= -1.0
			if position.y < 0.0 or position.y > rect.size.y:
				velocity.y *= -1.0
		State.HOMING:
			if not is_instance_valid(homing_target):
				set_state_free()
				return
			var dir: Vector2 = (homing_target.global_position - global_position).normalized()
			global_position += dir * HOMING_SPEED * delta
			if global_position.distance_to(homing_target.global_position) < 20.0:
				homing_target.take_hit()
				queue_free()

func set_state_attracted() -> void:
	state = State.ATTRACTED
	velocity = Vector2.ZERO

func set_state_free() -> void:
	state = State.FREE
	var angle: float = randf_range(0.0, TAU)
	velocity = Vector2(cos(angle), sin(angle)) * FLOAT_SPEED

func set_homing_target(target: Node2D) -> void:
	homing_target = target
	state = State.HOMING
