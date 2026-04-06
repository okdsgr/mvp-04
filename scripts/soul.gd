extends Area2D

@export var is_white : bool = true

enum State { ORBITING_ENEMY, HOMING_PLAYER, ORBITING_PLAYER, FIRING }

var state        : State   = State.ORBITING_ENEMY
var orbit_center : Node2D  = null
var orbit_angle  : float   = 0.0
var homing_target: Node2D  = null
var grav_velocity: Vector2 = Vector2.ZERO
var is_piercing  : bool    = false

const ENEMY_ORBIT_RADIUS  : float = 65.0
const PLAYER_ORBIT_RADIUS : float = 38.0
const ORBIT_SPEED         : float = 1.05
const FIRE_SPEED          : float = 540.0
const HOMING_MAX_SPEED    : float = 1200.0
const HOMING_STEER        : float = 12.0
const SLOWDOWN_RADIUS     : float = 180.0

const TAIL_LENGTH   : int   = 18
const TAIL_INTERVAL : float = 0.015
var _tail_positions : Array = []
var _tail_timer     : float = 0.0

var _laser_active : bool    = false
var _laser_timer  : float   = 0.0
var _laser_start  : Vector2 = Vector2.ZERO
var _laser_end    : Vector2 = Vector2.ZERO
const LASER_DURATION : float = 1.0
const LASER_HOLD     : float = 0.5

func _ready() -> void:
	add_to_group("bullets")

func _get_colors() -> Array:
	# [col_outer, col_mid, col_core, laser_glow, laser_core]
	if is_white:
		return [
			Color(0.6, 0.85, 1.0, 0.12),   # outer
			Color(0.7, 0.92, 1.0, 0.75),   # mid
			Color(1.0, 1.0,  1.0, 1.0),    # core
			Color(0.3, 0.7,  1.0, 1.0),    # laser glow（鮮やか青）
			Color(0.8, 0.95, 1.0, 1.0),    # laser core（白青）
		]
	else:
		return [
			Color(0.7, 0.1,  1.0, 0.18),   # outer
			Color(0.85, 0.3, 1.0, 0.8),    # mid
			Color(1.0, 0.8,  1.0, 1.0),    # core
			Color(1.0, 0.25, 0.1, 1.0),    # laser glow（鮮やかオレンジ赤）
			Color(1.0, 0.8,  0.4, 1.0),    # laser core（黄橙）
		]

func _draw() -> void:
	var r      : float  = 7.0
	var colors : Array  = _get_colors()
	var col_outer      : Color = colors[0]
	var col_mid        : Color = colors[1]
	var col_core       : Color = colors[2]
	var laser_glow     : Color = colors[3]
	var laser_core_col : Color = colors[4]

	# 彗星の尾びれ（FIRING・非PIERCE）
	if state == State.FIRING and _tail_positions.size() >= 2 and not is_piercing:
		for i: int in _tail_positions.size() - 1:
			var progress : float = float(i) / float(_tail_positions.size())
			var alpha    : float = progress * 0.7
			var width    : float = (1.0 - progress) * r * 1.2
			var p0 : Vector2 = to_local(_tail_positions[i])
			var p1 : Vector2 = to_local(_tail_positions[i + 1])
			draw_line(p0, p1, Color(col_mid.r, col_mid.g, col_mid.b, alpha), width)

	# レーザーエフェクト
	if _laser_active:
		var progress : float = clamp((_laser_timer - LASER_HOLD) / (LASER_DURATION - LASER_HOLD), 0.0, 1.0)
		var alpha    : float = 1.0 - progress
		var width    : float = maxf(1.0, 5.0 * (1.0 - progress))
		var lstart   : Vector2 = to_local(_laser_start)
		var lend     : Vector2 = to_local(_laser_end)

		# 外側グロー（色付き）
		draw_line(lstart, lend, Color(laser_glow.r, laser_glow.g, laser_glow.b, alpha * 0.45), width * 3.0)
		# 中心グロー
		draw_line(lstart, lend, Color(laser_glow.r, laser_glow.g, laser_glow.b, alpha * 0.8), width * 1.5)
		# コア（明るい）
		draw_line(lstart, lend, Color(laser_core_col.r, laser_core_col.g, laser_core_col.b, alpha), width)

		# 破線（後半）
		if progress > 0.5:
			var dash_alpha : float = alpha * 0.5
			var seg_len    : float = 14.0
			var total_len  : float = lstart.distance_to(lend)
			var dir        : Vector2 = (lend - lstart).normalized()
			var drawn      : float = 0.0
			var draw_seg   : bool  = true
			while drawn < total_len:
				var seg_end : float = minf(drawn + seg_len, total_len)
				if draw_seg:
					draw_line(
						lstart + dir * drawn,
						lstart + dir * seg_end,
						Color(laser_glow.r, laser_glow.g, laser_glow.b, dash_alpha),
						width * 0.6
					)
				drawn    += seg_len
				draw_seg  = not draw_seg
		return

	draw_circle(Vector2.ZERO, r * 2.2, col_outer)
	draw_circle(Vector2.ZERO, r,        col_mid)
	draw_circle(Vector2.ZERO, r * 0.38, col_core)

func _physics_process(delta: float) -> void:
	queue_redraw()

	if _laser_active:
		_laser_timer += delta
		if _laser_timer >= LASER_DURATION:
			queue_free()
		return

	match state:
		State.ORBITING_ENEMY:
			if not is_instance_valid(orbit_center):
				queue_free()
				return
			orbit_angle += ORBIT_SPEED * delta
			global_position = orbit_center.global_position + \
				Vector2(cos(orbit_angle), sin(orbit_angle)) * ENEMY_ORBIT_RADIUS

		State.HOMING_PLAYER:
			if not is_instance_valid(orbit_center):
				queue_free()
				return
			orbit_angle += ORBIT_SPEED * delta
			var target_pos : Vector2 = orbit_center.global_position + \
				Vector2(cos(orbit_angle), sin(orbit_angle)) * PLAYER_ORBIT_RADIUS
			var to_target  : Vector2 = target_pos - global_position
			var dist       : float   = to_target.length()
			if dist < 5.0:
				state = State.ORBITING_PLAYER
				grav_velocity = Vector2.ZERO
			else:
				var desired_speed : float = HOMING_MAX_SPEED
				if dist < SLOWDOWN_RADIUS:
					desired_speed = HOMING_MAX_SPEED * (dist / SLOWDOWN_RADIUS)
				desired_speed = maxf(desired_speed, 80.0)
				var desired_vel : Vector2 = to_target.normalized() * desired_speed
				var steering    : Vector2 = (desired_vel - grav_velocity) * HOMING_STEER * delta
				grav_velocity += steering
				if grav_velocity.length() > HOMING_MAX_SPEED:
					grav_velocity = grav_velocity.normalized() * HOMING_MAX_SPEED
				global_position += grav_velocity * delta

		State.ORBITING_PLAYER:
			if not is_instance_valid(orbit_center):
				queue_free()
				return
			orbit_angle += ORBIT_SPEED * 1.3 * delta
			global_position = orbit_center.global_position + \
				Vector2(cos(orbit_angle), sin(orbit_angle)) * PLAYER_ORBIT_RADIUS
			_tail_positions.clear()

		State.FIRING:
			if is_piercing:
				_update_laser(delta)
			else:
				_update_comet(delta)

func _update_comet(delta: float) -> void:
	if not is_instance_valid(homing_target):
		queue_free()
		return
	_tail_timer += delta
	if _tail_timer >= TAIL_INTERVAL:
		_tail_timer = 0.0
		_tail_positions.push_front(global_position)
		if _tail_positions.size() > TAIL_LENGTH:
			_tail_positions.pop_back()
	if global_position.distance_to(homing_target.global_position) < 22.0:
		homing_target.take_hit()
		queue_free()
		return
	global_position += (homing_target.global_position - global_position).normalized() * FIRE_SPEED * delta

func _update_laser(delta: float) -> void:
	if not is_instance_valid(homing_target):
		queue_free()
		return
	var dir       : Vector2 = (homing_target.global_position - global_position).normalized()
	var rect      : Rect2   = get_viewport_rect()
	var laser_end : Vector2 = _calc_screen_edge(global_position, dir, rect)

	var enemies : Array = get_tree().get_nodes_in_group("enemies")
	for e : Node in enemies:
		if not is_instance_valid(e):
			continue
		if is_white == e.is_white:
			continue
		var e2d : Node2D = e as Node2D
		if e2d == null:
			continue
		var closest : Vector2 = _closest_point_on_segment(global_position, laser_end, e2d.global_position)
		if closest.distance_to(e2d.global_position) < 40.0:
			e.take_hit()
			_start_laser_fade(global_position, laser_end)
			return

	global_position += dir * FIRE_SPEED * delta
	if not rect.has_point(global_position):
		queue_free()

func _start_laser_fade(start: Vector2, end: Vector2) -> void:
	_laser_active = true
	_laser_timer  = 0.0
	_laser_start  = start
	_laser_end    = end

func _calc_screen_edge(origin: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var best_t : float = 10000.0
	if abs(dir.x) > 0.001:
		var t1 : float = (rect.position.x - origin.x) / dir.x
		var t2 : float = (rect.end.x - origin.x) / dir.x
		if t1 > 0.0: best_t = minf(best_t, t1)
		if t2 > 0.0: best_t = minf(best_t, t2)
	if abs(dir.y) > 0.001:
		var t3 : float = (rect.position.y - origin.y) / dir.y
		var t4 : float = (rect.end.y - origin.y) / dir.y
		if t3 > 0.0: best_t = minf(best_t, t3)
		if t4 > 0.0: best_t = minf(best_t, t4)
	return origin + dir * best_t

func _closest_point_on_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab   : Vector2 = b - a
	var len2 : float   = ab.length_squared()
	if len2 < 0.001:
		return a
	var t : float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return a + ab * t

func attract_to_player(player: Node2D) -> void:
	orbit_center  = player
	grav_velocity = (player.global_position - global_position).normalized() * 200.0
	state         = State.HOMING_PLAYER
	_tail_positions.clear()

func fire_at(target: Node2D) -> void:
	homing_target = target
	orbit_center  = null
	grav_velocity = Vector2.ZERO
	state         = State.FIRING
	_tail_positions.clear()
