extends Node2D

var _time       : float   = 0.0
var _duration   : float   = 0.6
var effect_type : String  = "smoke"
var _velocity   : Vector2 = Vector2.ZERO
var _tex        : Texture2D = null
var _sprite     : Sprite2D  = null

func setup(type: String, pos: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	effect_type     = type
	global_position = pos
	_velocity       = vel

	match type:
		"explosion":
			_duration = 0.5
			if ResourceLoader.exists("res://assets/sprites/effect_explosion.png"):
				_tex = load("res://assets/sprites/effect_explosion.png")
		"smoke":
			_duration = 0.7
			if ResourceLoader.exists("res://assets/sprites/effect_smoke.png"):
				_tex = load("res://assets/sprites/effect_smoke.png")

	if _tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = _tex
		_sprite.scale   = Vector2(0.3, 0.3)
		add_child(_sprite)

func _process(delta: float) -> void:
	_time += delta
	# 速度でドリフト（煙が流れる）
	global_position += _velocity * delta * (1.0 - _time / _duration)

	var progress : float = clamp(_time / _duration, 0.0, 1.0)

	if _sprite != null:
		match effect_type:
			"smoke":
				var s : float = 0.3 + progress * 0.9
				_sprite.scale    = Vector2(s, s)
				_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - progress)
			"explosion":
				var s : float = 0.2 + progress * 1.2
				_sprite.scale    = Vector2(s, s)
				_sprite.modulate = Color(1.0, 1.0 - progress * 0.4, 0.5 - progress * 0.5, 1.0 - progress)
	else:
		queue_redraw()

	if _time >= _duration:
		queue_free()

func _draw() -> void:
	if _sprite != null:
		return
	var progress : float = clamp(_time / _duration, 0.0, 1.0)
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
