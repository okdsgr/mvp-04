extends Node2D

# 汎用やられエフェクト
# type: "smoke"（通常敵）/ "explosion"（BOMBER）

var _time     : float = 0.0
var _duration : float = 0.6
var effect_type : String = "smoke"

var _tex : Texture2D = null

func setup(type: String, pos: Vector2) -> void:
	effect_type = type
	global_position = pos
	match type:
		"explosion":
			_duration = 0.5
			if ResourceLoader.exists("res://assets/sprites/effect_explosion.png"):
				_tex = load("res://assets/sprites/effect_explosion.png")
		"smoke":
			_duration = 0.6
			if ResourceLoader.exists("res://assets/sprites/effect_smoke.png"):
				_tex = load("res://assets/sprites/effect_smoke.png")

	if _tex:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = _tex
		sprite.scale = Vector2(0.5, 0.5)
		add_child(sprite)

func _process(delta: float) -> void:
	_time += delta
	var progress : float = _time / _duration

	if has_node("Sprite2D"):
		var sprite : Sprite2D = $Sprite2D
		sprite.scale = Vector2(1.0, 1.0) * (0.3 + progress * 0.8)
		sprite.modulate.a = 1.0 - progress

	queue_redraw()

	if _time >= _duration:
		queue_free()

func _draw() -> void:
	if _tex:
		return  # スプライトがあればdrawは不要
	var progress : float = _time / _duration
	var alpha    : float = 1.0 - progress
	var scale_f  : float = 0.4 + progress * 0.8

	match effect_type:
		"explosion":
			draw_circle(Vector2.ZERO, 60.0 * scale_f, Color(1.0, 0.6, 0.1, alpha * 0.6))
			draw_circle(Vector2.ZERO, 40.0 * scale_f, Color(1.0, 0.8, 0.2, alpha * 0.8))
			draw_circle(Vector2.ZERO, 22.0 * scale_f, Color(1.0, 1.0, 0.6, alpha))
		"smoke":
			draw_circle(Vector2.ZERO, 50.0 * scale_f, Color(0.8, 0.8, 0.8, alpha * 0.5))
			draw_circle(Vector2.ZERO, 32.0 * scale_f, Color(0.9, 0.9, 0.9, alpha * 0.7))
			draw_circle(Vector2.ZERO, 18.0 * scale_f, Color(1.0, 1.0, 1.0, alpha * 0.8))
