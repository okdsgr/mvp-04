extends Area2D

enum Type { SHIELD, PIERCE }

var item_type : Type  = Type.SHIELD
var _time     : float = 0.0

const FALL_SPEED  : float = 60.0
const FLOAT_AMP   : float = 6.0
const FLOAT_FREQ  : float = 2.0
const LIFESPAN    : float = 8.0

const TEXTURES : Array = [
	"res://assets/sprites/item_shield.png",
	"res://assets/sprites/item_pierce.png",
]

const COLORS : Array = [
	Color(0.2, 0.9, 0.4, 1.0),  # SHIELD 緑
	Color(1.0, 0.3, 0.3, 1.0),  # PIERCE 赤
]

func _ready() -> void:
	add_to_group("items")
	collision_layer = 0
	collision_mask  = 1
	monitoring      = true
	monitorable     = false
	body_entered.connect(_on_body_entered)

	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	col.shape = shape
	add_child(col)

	var sprite := Sprite2D.new()
	sprite.name    = "Sprite2D"
	sprite.texture = load(TEXTURES[item_type])
	sprite.scale   = Vector2(0.18, 0.18)
	add_child(sprite)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_apply_effect(body)
		queue_free()

func _draw() -> void:
	var col : Color = COLORS[item_type]
	draw_circle(Vector2.ZERO, 22.0, Color(col.r, col.g, col.b, 0.15))
	draw_circle(Vector2.ZERO, 14.0, Color(col.r, col.g, col.b, 0.25))

func _physics_process(delta: float) -> void:
	_time += delta
	position.y += FALL_SPEED * delta
	position.x += sin(_time * FLOAT_FREQ) * FLOAT_AMP * delta

	if has_node("Sprite2D"):
		$Sprite2D.rotation = _time * 1.2

	if _time >= LIFESPAN:
		queue_free()
		return

	var rect : Rect2 = get_viewport_rect()
	if position.y > rect.size.y + 40.0:
		queue_free()
		return

	queue_redraw()

func _apply_effect(player: Node) -> void:
	match item_type:
		Type.SHIELD:
			player.has_shield   = true
		Type.PIERCE:
			player.pierce_count = player.pierce_count + 1
