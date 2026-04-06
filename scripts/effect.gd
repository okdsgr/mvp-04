extends Node2D

var _time       : float   = 0.0
var _duration   : float   = 0.6
var effect_type : String  = "smoke"
var velocity    : Vector2 = Vector2.ZERO  # 煙は敵の速度を引き継ぐ

var _tex : Texture2D = null
var _sprite : Sprite2D = null

func setup(type: String, pos: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	effect_type      = type
	global_position  = pos
	velocity         = vel

	match type:
		"explosion":
			_duration = 0.55
			if ResourceLoader.exists("res://assets/sprites/effect_explosion.png"):
				_tex = load("res://assets/sprites/effect_explosion.png")
		"smoke":
			_duration = 0.65
			if ResourceLoader.exists("res://assets/sprites/effect_smoke.png"):
				_tex = load("res://assets/sprites/effect_smoke.png")

	if _tex:
		_sprite = Sprite2D.new()
		_sprite.texture = _tex
		# 爆発は最初から大きめ、煙は小さめスタート
		var init_scale : float = 0.8 if type == "explosion" else 0.35
		_sprite.scale = Vector2(init_scale, init_scale)
		add_child(_sprite)

func _process(delta: float) -> void:
	_time += delta
	var progress : float = _time / _duration

	# 煙：敵のベクトルを引き継いで動く
	if effect_type == "smoke":
		global_position += velocity * delta

	if _sprite:
		match effect_type:
			"smoke":
				# サイズはほぼ変えずアルファだけ落とす（透明度は元の半分）
				_sprite.scale = Vector2(0.4, 0.4)
				_sprite.modulate.a = (1.0 - progress) * 0.25  # 薄め
			"explosion":
				# 膨らんで消える
				var s : float = 0.8 + progress * 1.4
				_sprite.scale = Vector2(s, s)
				_sprite.modulate.a = 1.0 - progress

	queue_redraw()

	if _time >= _duration:
		queue_free()

func _draw() -> void:
	if _tex:
		return  # スプライトがあればdrawは不要

	var progress : float = _time / _duration
	var alpha    : float = 1.0 - progress

	match effect_type:
		"explosion":
			var s : float = 0.6 + progress * 1.2
			draw_circle(Vector2.ZERO, 80.0 * s, Color(1.0, 0.5, 0.1, alpha * 0.3))
			draw_circle(Vector2.ZERO, 55.0 * s, Color(1.0, 0.75, 0.2, alpha * 0.5))
			draw_circle(Vector2.ZERO, 32.0 * s, Color(1.0, 1.0, 0.5, alpha * 0.7))
		"smoke":
			draw_circle(Vector2.ZERO, 40.0, Color(0.85, 0.85, 0.85, alpha * 0.13))
			draw_circle(Vector2.ZERO, 26.0, Color(0.92, 0.92, 0.92, alpha * 0.18))
