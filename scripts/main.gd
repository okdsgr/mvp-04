extends Node2D

# =====================================================================
# SUMERAGI - MVP-05
# Turn-based battle: What beats what?
# =====================================================================

const WIN_W  : int    = 405
const WIN_H  : int    = 720
const N8N    : String = "https://okdsgr.app.n8n.cloud/webhook/"
const CLAUDE : String = "https://okdsgr.app.n8n.cloud/webhook/akinator-claude"

enum Phase { INIT, CPU_TURN, PLAYER_INPUT, BATTLE, RESULT }
var _phase : Phase = Phase.INIT

var _http      : HTTPRequest = null
var _ui        : CanvasLayer = null

var _cpu_entity    : String = ""   # CPU が出したもの（例: frog）
var _player_entity : String = ""   # プレイヤーが入力したもの（例: snake）
var _battle_log    : Array  = []   # バトルの演出テキスト
var _round         : int    = 0

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(WIN_W, WIN_H))
	var scr := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i((scr.x - WIN_W) / 2, (scr.y - WIN_H) / 2))
	RenderingServer.set_default_clear_color(Color(0.06, 0.06, 0.12))

	_ui = $UI
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	add_child(_http)

	_show_title()

func _show_title() -> void:
	_clear_ui()
	var lbl := Label.new()
	lbl.text = "SUMERAGI"
	lbl.add_theme_font_size_override("font_size", 60)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	lbl.position = Vector2(60, 260)
	_ui.add_child(lbl)

	var sub := Label.new()
	sub.text = "すめらぎ"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.7, 0.65, 0.45, 0.85))
	sub.position = Vector2(140, 350)
	_ui.add_child(sub)

	var btn := Button.new()
	btn.text = "▶  ゲーム開始"
	btn.custom_minimum_size = Vector2(280, 64)
	btn.add_theme_font_size_override("font_size", 20)
	btn.position = Vector2(62, 520)
	_ui.add_child(btn)
	btn.pressed.connect(_start_game)

func _start_game() -> void:
	_round = 0
	_battle_log = []
	_cpu_turn()

func _cpu_turn() -> void:
	_phase = Phase.CPU_TURN
	_round += 1
	_clear_ui()
	_show_status("CPUが考えています…")
	# TODO: n8n cpu-generate エンドポイントを呼ぶ
	# 仮実装：固定リスト
	var options := ["frog", "snake", "slug", "hawk", "mouse"]
	_cpu_entity = options[randi() % options.size()]
	await get_tree().create_timer(1.0).timeout
	_player_input_phase()

func _player_input_phase() -> void:
	_phase = Phase.PLAYER_INPUT
	_clear_ui()

	var cpu_lbl := Label.new()
	cpu_lbl.text = "CPU: %s" % _cpu_entity.to_upper()
	cpu_lbl.add_theme_font_size_override("font_size", 32)
	cpu_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	cpu_lbl.position = Vector2(20, 40)
	_ui.add_child(cpu_lbl)

	var prompt_lbl := Label.new()
	prompt_lbl.text = "「%s」に勝てるものを入力してください" % _cpu_entity
	prompt_lbl.add_theme_font_size_override("font_size", 16)
	prompt_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	prompt_lbl.custom_minimum_size = Vector2(360, 0)
	prompt_lbl.position = Vector2(20, 100)
	_ui.add_child(prompt_lbl)

	var input := LineEdit.new()
	input.name = "PlayerInput"
	input.placeholder_text = "例: ヘビ、タカ、塩..."
	input.custom_minimum_size = Vector2(300, 52)
	input.add_theme_font_size_override("font_size", 18)
	input.position = Vector2(20, 560)
	_ui.add_child(input)

	var btn := Button.new()
	btn.text = "決定"
	btn.custom_minimum_size = Vector2(80, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.position = Vector2(325, 560)
	_ui.add_child(btn)
	btn.pressed.connect(_on_player_submit)
	input.text_submitted.connect(func(_t): _on_player_submit())

func _on_player_submit() -> void:
	var input_node := _ui.get_node_or_null("PlayerInput")
	if input_node == null:
		return
	var text : String = (input_node as LineEdit).text.strip_edges()
	if text.is_empty():
		return
	_player_entity = text
	_battle_phase()

func _battle_phase() -> void:
	_phase = Phase.BATTLE
	_clear_ui()
	_show_status("バトル判定中…")
	# TODO: n8n battle-judge エンドポイントを呼ぶ
	await get_tree().create_timer(1.5).timeout
	# 仮結果
	_show_battle_result("PLAYER WIN", [
		"%s が現れた！" % _player_entity,
		"%s は %s を前に固まった…" % [_cpu_entity, _player_entity],
		"%s の勝利！" % _player_entity,
	], true)

func _show_battle_result(headline: String, log: Array, player_wins: bool) -> void:
	_phase = Phase.RESULT
	_clear_ui()

	var h := Label.new()
	h.text = headline
	h.add_theme_font_size_override("font_size", 36)
	h.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6) if player_wins else Color(1.0, 0.4, 0.4))
	h.position = Vector2(20, 40)
	_ui.add_child(h)

	var y := 110.0
	for line : String in log:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(360, 0)
		l.position = Vector2(20, y)
		_ui.add_child(l)
		y += 56.0

	var next_btn := Button.new()
	next_btn.text = "次のラウンド ▶"
	next_btn.custom_minimum_size = Vector2(280, 60)
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.position = Vector2(62, 580)
	_ui.add_child(next_btn)
	next_btn.pressed.connect(_cpu_turn)

func _show_status(msg: String) -> void:
	_clear_ui()
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 1.0))
	lbl.position = Vector2(60, 320)
	_ui.add_child(lbl)

func _clear_ui() -> void:
	for c : Node in _ui.get_children():
		c.queue_free()

func _post_json(url: String, body: Dictionary, callback: Callable) -> void:
	if _http.request_completed.is_connected(callback):
		_http.request_completed.disconnect(callback)
	_http.request_completed.connect(callback, CONNECT_ONE_SHOT)
	_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
