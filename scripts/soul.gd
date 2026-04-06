extends Area2D

@export var is_white: bool = true

enum State { ORBITING_ENEMY, HOMING_PLAYER, ORBITING_PLAYER, FIRING }

var state: State = State.ORBITING_ENEMY
var orbit_center: Node2D = null
var orbit_angle: float = 0.0
var homing_target: Node2D = null
var grav_velocity: Vector2 = Vector2.ZERO

const ENEMY_ORBIT_RADIUS  := 65.0
const PLAYER_ORBIT_RADIUS := 38.0
const ORBIT_SPEED         := 1.05
const FIRE_SPEED          := 540.0
const HOMING_MAX_SPEED    := 1200.0   # 吸い寄せ最大速度
const HOMING_STEER        := 12.0     # ステアリング強度（高いほど即反応）
const SLOWDOWN_RADIUS     := 180.0    # この距離以下で減速開始

func _ready() -> void:
	add_to_group("bullets")

func _draw() -> void:
	var r := 7.0
	if is_white:
		draw_circle(Vector2.ZERO, r * 2.2, Color(1.0, 1.0, 1.0, 0.12))
		draw_circle(Vector2.ZERO, r,        Color(1.0, 1.0, 1.0, 0.75))
		draw_circle(Vector2.ZERO, r * 0.38, Color(1.0, 1.0, 1.0, 1.0))
	else:
		draw_circle(Vector2.ZERO, r * 2.2, Color(0.7, 0.1, 1.0, 0.18))
		draw_circle(Vector2.ZERO, r,        Color(0.85, 0.3, 1.0, 0.8))
		draw_circle(Vector2.ZERO, r * 0.38, Color(1.0, 0.8, 1.0, 1.0))

func _physics_process(delta: float) -> void:
	queue_redraw()
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
			var target_pos: Vector2 = orbit_center.global_position + \
				Vector2(cos(orbit_angle), sin(orbit_angle)) * PLAYER_ORBIT_RADIUS
			var to_target: Vector2 = target_pos - global_position
			var dist: float = to_target.length()

			if dist < 5.0:
				state = State.ORBITING_PLAYER
				grav_velocity = Vector2.ZERO
			else:
				# seek-with-arrival: 近づくほど速度を落とす
				var desired_speed: float = HOMING_MAX_SPEED
				if dist < SLOWDOWN_RADIUS:
					desired_speed = HOMING_MAX_SPEED * (dist / SLOWDOWN_RADIUS)
				desired_speed = max(desired_speed, 80.0)  # 最低速度

				var desired_vel: Vector2 = to_target.normalized() * desired_speed
				# 現在速度を目標速度へステアリング
				var steering: Vector2 = (desired_vel - grav_velocity) * HOMING_STEER * delta
				grav_velocity += steering
				# 最大速度クランプ
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

		State.FIRING:
			if not is_instance_valid(homing_target):
				queue_free()
				return
			if global_position.distance_to(homing_target.global_position) < 22.0:
				homing_target.take_hit()
				queue_free()
				return
			global_position += (homing_target.global_position - global_position).normalized() * FIRE_SPEED * delta

func attract_to_player(player: Node2D) -> void:
	orbit_center = player
	# 初速は控えめに（過去の問題: 初速が速すぎて画面外）
	var to_player: Vector2 = player.global_position - global_position
	grav_velocity = to_player.normalized() * 200.0
	state = State.HOMING_PLAYER

func fire_at(target: Node2D) -> void:
	homing_target = target
	orbit_center = null
	grav_velocity = Vector2.ZERO
	state = State.FIRING
