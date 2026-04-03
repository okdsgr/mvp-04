extends Node2D

const VP_W := 540.0
const VP_H := 960.0
const MOVE_SPEED := 80.0
const MAX_SOULS := 3  # LvアップでMCPから変更予定

var is_holding := false
var held_souls: Array = []

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			is_holding = true
		else:
			is_holding = false
			_release_souls()
	elif event is InputEventScreenDrag and is_holding:
		var target := event.position
		_move_toward(target)

func _move_toward(target: Vector2) -> void:
	var dir := (target - global_position)
	if dir.length() > 4.0:
		global_position += dir.normalized() * MOVE_SPEED * get_process_delta_time()
	global_position.x = clamp(global_position.x, 0.0, VP_W)
	global_position.y = clamp(global_position.y, 0.0, VP_H)

func _release_souls() -> void:
	# 後ほど実装：held_soulsを対応する敵に向けて発射
	pass

func add_soul(soul: Node2D) -> void:
	if held_souls.size() < MAX_SOULS:
		held_souls.append(soul)
