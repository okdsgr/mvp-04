extends Node2D

const GAME_TITLE   : String = "GROSBREAK"
const N8N_URL      : String = "https://okdsgr.app.n8n.cloud/webhook/sprite-to-mvp04"
const CLAUDE_URL   : String = "https://okdsgr.app.n8n.cloud/webhook/akinator-claude"
const VP_W         : float  = 540.0
const VP_H         : float  = 960.0

const CHOICES    : Array = ["はい", "おそらくはい", "わからない", "おそらくいいえ", "いいえ"]
const STEP_NAMES : Array = ["自機（待機）", "自機（歩き）", "白い敵", "黒い敵", "背景"]

enum Screen { TITLE, MENU, PLAYER_AKI, ENEMY_AKI, BG_AKI, GENERATING, READY }
var _screen : Screen = Screen.TITLE
var _anim   : float  = 0.0
var _orbs   : Array  = []

var _http_ai  : HTTPRequest = null
var _http_gen : HTTPRequest = null
var _waiting  : bool = false

var _messages      : Array  = []
var _system_prompt : String = ""
var _cur_question  : String = ""

var _player_en  : String = ""
var _enemy_en   : String = ""
var _bg_prompt  : String = ""
var _player_msg : String = ""
var _enemy_msg  : String = ""

var _ui           : CanvasLayer   = null
var _history_vbox : VBoxContainer = null
var _question_lbl : Label         = null
var _choices_vbox : VBoxContainer = null
var _input_edit   : LineEdit      = null
var _progress_bar : ProgressBar   = null
var _progress_lbl : Label         = null
var _step_lbl     : Label         = null

var _gen_queue   : Array = []
var _gen_current : int   = 0

const PLAYER_SYSTEM : String = "あなたはアキネーターです。ユーザーが頭の中で思い浮かべているキャラクターを当てるゲームをします。テーマは「生まれ変わるとしたら？」です。ユーザーはすでにキャラクターを心の中で決めています。5〜8回のYes/No質問で絞り込んでください。ユーザーは「はい／おそらくはい／わからない／おそらくいいえ／いいえ」のどれかで答えます。質問は必ずこのフォーマットで出力：[Q]質問文（1文のみ）。キャラクターが決まったら：[PLAYER:英語名]日本語の決定メッセージ。英語名はシンプルな英単語（robot、ninja、bearなど）。最初の質問から始めてください。"

const ENEMY_SYSTEM : String = "あなたはアキネーターです。ユーザーが頭の中で思い浮かべているものを当てるゲームをします。テーマは「嫌いなもの、または怖いもの」です。ユーザーはすでにそれを心の中で決めています。5〜8回のYes/No質問で絞り込んでください。ユーザーは「はい／おそらくはい／わからない／おそらくいいえ／いいえ」のどれかで答えます。質問は必ずこのフォーマットで出力：[Q]質問文（1文のみ）。決まったら：[ENEMY:英語名]白い○○と黒い○○を敵として登場させますね！（英語名はシンプルな英単語）。最初の質問から始めてください。"

const BG_SYSTEM : String = "あなたはゲームアーティストのアシスタントです。ユーザーの自由回答から縦スクロールシューティングゲームの背景世界観を決定します。必要なら1〜2回追加質問し、背景プロンプトを生成してください。決定フォーマット（必須）：[BG:英語プロンプト]日本語の世界観説明。英語プロンプトはflux-schnell用。縦スクロールゲーム背景として映える情景を描写する短い英文。最初の質問から始めてください。"

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.10, 1.0))
	randomize()

	for i: int in 24:
		_orbs.append({
			"pos":      Vector2(randf() * VP_W, randf() * VP_H),
			"vel":      Vector2(randf_range(-12.0, 12.0), randf_range(-25.0, -8.0)),
			"r":        randf_range(3.0, 10.0),
			"is_white": randf() > 0.5,
			"phase":    randf() * TAU,
		})

	_ui = CanvasLayer.new()
	add_child(_ui)

	_http_ai = HTTPRequest.new()
	_http_ai.timeout = 40.0
	add_child(_http_ai)

	_http_gen = HTTPRequest.new()
	_http_gen.timeout = 120.0
	add_child(_http_gen)

	_show_title()

func _process(delta: float) -> void:
	_anim += delta
	for orb : Dictionary in _orbs:
		orb["pos"] += (orb["vel"] as Vector2) * delta
		if (orb["pos"] as Vector2).y < -20.0:
			orb["pos"] = Vector2(randf() * VP_W, VP_H + 10.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if _screen != Screen.TITLE:
		return
	var hit : bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hit = true
	elif event is InputEventKey and (event as InputEventKey).pressed:
		hit = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		hit = true
	if hit:
		_show_menu()

func _draw() -> void:
	for orb : Dictionary in _orbs:
		var pos   : Vector2 = orb["pos"]
		var r     : float   = orb["r"]
		var pulse : float   = sin(_anim * 1.5 + (orb["phase"] as float)) * 0.3 + 0.7
		if orb["is_white"]:
			draw_circle(pos, r * 2.0, Color(1.0, 1.0, 1.0, 0.05 * pulse))
			draw_circle(pos, r,       Color(1.0, 1.0, 1.0, 0.35 * pulse))
		else:
			draw_circle(pos, r * 2.0, Color(0.55, 0.0, 0.85, 0.07 * pulse))
			draw_circle(pos, r,       Color(0.75, 0.2, 1.0,  0.45 * pulse))

func _clear_ui() -> void:
	for c : Node in _ui.get_children():
		c.queue_free()
	_history_vbox = null
	_question_lbl = null
	_choices_vbox = null
	_input_edit   = null

# =====================================================================
# TITLE
# =====================================================================
func _show_title() -> void:
	_screen = Screen.TITLE
	_clear_ui()
	var cx : float = VP_W * 0.5

	var t := Label.new()
	t.text = GAME_TITLE
	t.add_theme_font_size_override("font_size", 72)
	t.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	t.position = Vector2(cx - 190.0, 260.0)
	_ui.add_child(t)

	var sub := Label.new()
	sub.text = "グロスブレイク"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.85, 0.9))
	sub.position = Vector2(cx - 83.0, 358.0)
	_ui.add_child(sub)

	var press := Label.new()
	press.text = "Tap or Press Any Key"
	press.add_theme_font_size_override("font_size", 18)
	press.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
	press.position = Vector2(cx - 105.0, 680.0)
	_ui.add_child(press)

	var tw := create_tween()
	tw.set_loops(-1)
	tw.tween_property(press, "modulate:a", 0.1, 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_property(press, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE)

# =====================================================================
# MENU
# =====================================================================
func _show_menu() -> void:
	_screen = Screen.MENU
	_clear_ui()
	var cx : float = VP_W * 0.5

	var t := Label.new()
	t.text = GAME_TITLE
	t.add_theme_font_size_override("font_size", 48)
	t.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	t.position = Vector2(cx - 128.0, 200.0)
	_ui.add_child(t)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 155.0, 420.0)
	vbox.add_theme_constant_override("separation", 22)
	_ui.add_child(vbox)

	var s_btn := Button.new()
	s_btn.text = "▶   すぐに始める"
	s_btn.custom_minimum_size = Vector2(310, 64)
	s_btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(s_btn)
	s_btn.pressed.connect(_on_start_default)

	var c_btn := Button.new()
	c_btn.text = "✦   カスタマイズ"
	c_btn.custom_minimum_size = Vector2(310, 64)
	c_btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(c_btn)
	c_btn.pressed.connect(_start_player_akinator)

func _on_start_default() -> void:
	var sm : Node = get_node_or_null("/root/SkinManager")
	if sm:
		sm.set_skin("default")
		sm.confirm_skin()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# =====================================================================
# AKINATOR 共通UI
# =====================================================================
func _show_aki_ui(phase_title: String, theme: String) -> void:
	_clear_ui()
	var cx : float = VP_W * 0.5

	var phase_lbl := Label.new()
	phase_lbl.text = phase_title
	phase_lbl.add_theme_font_size_override("font_size", 16)
	phase_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 1.0, 0.85))
	phase_lbl.position = Vector2(cx - 100.0, 30.0)
	_ui.add_child(phase_lbl)

	var theme_lbl := Label.new()
	theme_lbl.text = theme
	theme_lbl.add_theme_font_size_override("font_size", 19)
	theme_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.95))
	theme_lbl.position = Vector2(28.0, 68.0)
	theme_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	theme_lbl.custom_minimum_size = Vector2(VP_W - 56.0, 0)
	_ui.add_child(theme_lbl)

	var line := ColorRect.new()
	line.position = Vector2(28.0, 120.0)
	line.size = Vector2(VP_W - 56.0, 1.5)
	line.color = Color(0.4, 0.4, 0.7, 0.4)
	_ui.add_child(line)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28.0, 130.0)
	scroll.custom_minimum_size = Vector2(VP_W - 56.0, 340.0)
	_ui.add_child(scroll)

	_history_vbox = VBoxContainer.new()
	_history_vbox.add_theme_constant_override("separation", 8)
	_history_vbox.custom_minimum_size = Vector2(VP_W - 70.0, 0)
	scroll.add_child(_history_vbox)

	var line2 := ColorRect.new()
	line2.position = Vector2(28.0, 478.0)
	line2.size = Vector2(VP_W - 56.0, 1.5)
	line2.color = Color(0.4, 0.4, 0.7, 0.4)
	_ui.add_child(line2)

	_question_lbl = Label.new()
	_question_lbl.text = "考え中..."
	_question_lbl.add_theme_font_size_override("font_size", 20)
	_question_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_question_lbl.position = Vector2(28.0, 492.0)
	_question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_question_lbl.custom_minimum_size = Vector2(VP_W - 56.0, 80.0)
	_ui.add_child(_question_lbl)

	_choices_vbox = VBoxContainer.new()
	_choices_vbox.position = Vector2(cx - 145.0, 600.0)
	_choices_vbox.add_theme_constant_override("separation", 10)
	_ui.add_child(_choices_vbox)

	for choice : String in CHOICES:
		var btn := Button.new()
		btn.text = choice
		btn.custom_minimum_size = Vector2(290, 52)
		btn.add_theme_font_size_override("font_size", 17)
		btn.disabled = true
		_choices_vbox.add_child(btn)
		btn.pressed.connect(_on_choice_pressed.bind(choice))

# 背景専用UI
func _show_bg_ui() -> void:
	_clear_ui()
	var cx : float = VP_W * 0.5

	var phase_lbl := Label.new()
	phase_lbl.text = "背景を決めよう ③/③"
	phase_lbl.add_theme_font_size_override("font_size", 16)
	phase_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 1.0, 0.85))
	phase_lbl.position = Vector2(cx - 100.0, 30.0)
	_ui.add_child(phase_lbl)

	var theme_lbl := Label.new()
	theme_lbl.text = "どんな世界を飛び回りたいですか？"
	theme_lbl.add_theme_font_size_override("font_size", 19)
	theme_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.95))
	theme_lbl.position = Vector2(28.0, 68.0)
	theme_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	theme_lbl.custom_minimum_size = Vector2(VP_W - 56.0, 0)
	_ui.add_child(theme_lbl)

	var line := ColorRect.new()
	line.position = Vector2(28.0, 120.0)
	line.size = Vector2(VP_W - 56.0, 1.5)
	line.color = Color(0.4, 0.4, 0.7, 0.4)
	_ui.add_child(line)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28.0, 130.0)
	scroll.custom_minimum_size = Vector2(VP_W - 56.0, 300.0)
	_ui.add_child(scroll)

	_history_vbox = VBoxContainer.new()
	_history_vbox.add_theme_constant_override("separation", 8)
	_history_vbox.custom_minimum_size = Vector2(VP_W - 70.0, 0)
	scroll.add_child(_history_vbox)

	var line2 := ColorRect.new()
	line2.position = Vector2(28.0, 438.0)
	line2.size = Vector2(VP_W - 56.0, 1.5)
	line2.color = Color(0.4, 0.4, 0.7, 0.4)
	_ui.add_child(line2)

	_question_lbl = Label.new()
	_question_lbl.text = "考え中..."
	_question_lbl.add_theme_font_size_override("font_size", 18)
	_question_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_question_lbl.position = Vector2(28.0, 450.0)
	_question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_question_lbl.custom_minimum_size = Vector2(VP_W - 56.0, 80.0)
	_ui.add_child(_question_lbl)

	_input_edit = LineEdit.new()
	_input_edit.placeholder_text = "自由に回答を入力..."
	_input_edit.custom_minimum_size = Vector2(390.0, 52.0)
	_input_edit.add_theme_font_size_override("font_size", 16)
	_input_edit.position = Vector2(28.0, 600.0)
	_input_edit.editable = false
	_ui.add_child(_input_edit)

	var send_btn := Button.new()
	send_btn.name = "SendBtn"
	send_btn.text = "送信"
	send_btn.custom_minimum_size = Vector2(90.0, 52.0)
	send_btn.add_theme_font_size_override("font_size", 16)
	send_btn.position = Vector2(430.0, 600.0)
	send_btn.disabled = true
	_ui.add_child(send_btn)

	send_btn.pressed.connect(_on_bg_send_pressed)
	_input_edit.text_submitted.connect(func(_t: String): _on_bg_send_pressed())

func _on_bg_send_pressed() -> void:
	if _waiting or _input_edit == null:
		return
	var answer : String = _input_edit.text.strip_edges()
	if answer.is_empty():
		return
	_input_edit.text = ""
	_add_history("", answer)
	_messages.append({"role": "user", "content": answer})
	_set_waiting(true)
	_do_claude_request()

# =====================================================================
# AKINATOR フロー
# =====================================================================
func _start_player_akinator() -> void:
	_screen = Screen.PLAYER_AKI
	_messages = []
	_cur_question = ""
	_system_prompt = PLAYER_SYSTEM
	_show_aki_ui("自機を決めよう ①/③", "生まれ変わるとしたら、\nどんな存在になりたいですか？")
	_call_claude_start()

func _start_enemy_akinator() -> void:
	_screen = Screen.ENEMY_AKI
	_messages = []
	_cur_question = ""
	_system_prompt = ENEMY_SYSTEM
	_show_aki_ui("敵を決めよう ②/③", "嫌いなもの、または怖いものを\n頭の中で思い浮かべてください")
	_call_claude_start()

func _start_bg_akinator() -> void:
	_screen = Screen.BG_AKI
	_messages = []
	_cur_question = ""
	_system_prompt = BG_SYSTEM
	_show_bg_ui()
	_call_claude_start()

func _call_claude_start() -> void:
	_set_waiting(true)
	_messages.append({"role": "user", "content": "スタート"})
	_do_claude_request()

func _on_choice_pressed(choice: String) -> void:
	if _waiting:
		return
	_add_history(_cur_question, choice)
	_messages.append({"role": "user", "content": choice})
	_set_waiting(true)
	_do_claude_request()

# =====================================================================
# UI ヘルパー
# =====================================================================
func _set_waiting(on: bool) -> void:
	_waiting = on
	if is_instance_valid(_question_lbl) and on:
		_question_lbl.text = "考え中..."
	if is_instance_valid(_choices_vbox):
		for btn : Node in _choices_vbox.get_children():
			if btn is Button:
				(btn as Button).disabled = on
	if is_instance_valid(_input_edit):
		_input_edit.editable = not on
	var sbn := _ui.get_node_or_null("SendBtn")
	if sbn and sbn is Button:
		(sbn as Button).disabled = on

func _update_question(text: String) -> void:
	if is_instance_valid(_question_lbl):
		_question_lbl.text = text
	_cur_question = text
	_set_waiting(false)

func _add_history(question: String, answer: String) -> void:
	if _history_vbox == null:
		return
	var lbl := Label.new()
	if question.is_empty():
		lbl.text = "▶  " + answer
	else:
		lbl.text = "Q: " + question + "\n→  " + answer
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85, 0.75))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(VP_W - 80.0, 0)
	_history_vbox.add_child(lbl)

func _show_decision(text: String) -> void:
	if is_instance_valid(_question_lbl):
		_question_lbl.text = text
		_question_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))

# =====================================================================
# n8n PROXY 経由 CLAUDE 呼び出し
# =====================================================================
func _do_claude_request() -> void:
	# n8nプロキシに {system, messages} を送信（APIキー不要）
	var body : String = JSON.stringify({
		"system":   _system_prompt,
		"messages": _messages,
	})
	var headers : PackedStringArray = ["Content-Type: application/json"]

	if _http_ai.request_completed.is_connected(_on_claude_response):
		_http_ai.request_completed.disconnect(_on_claude_response)
	_http_ai.request_completed.connect(_on_claude_response, CONNECT_ONE_SHOT)
	_http_ai.request(CLAUDE_URL, headers, HTTPClient.METHOD_POST, body)

func _on_claude_response(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var text : String = body.get_string_from_utf8()
	print("[Claude] code=", code, " | ", text.substr(0, 150))

	var json = JSON.parse_string(text)
	var reply : String = ""

	if json == null:
		_update_question("エラー: JSON解析失敗 (%d)" % code)
		return

	# n8nプロキシは {"reply": "..."} を返す
	if json.has("reply"):
		reply = str(json["reply"])
	elif json.has("error"):
		_update_question("エラー: %s" % str(json["error"]))
		return
	else:
		_update_question("エラー (%d): %s" % [code, text.substr(0, 80)])
		return

	_messages.append({"role": "assistant", "content": reply})
	_parse_reply(reply)

func _parse_reply(reply: String) -> void:
	var re_q := RegEx.new()
	re_q.compile("\\[Q\\](.+)")
	var mq = re_q.search(reply)

	var re_p := RegEx.new()
	re_p.compile("\\[PLAYER:([a-zA-Z ]+)\\]")
	var mp = re_p.search(reply)

	var re_e := RegEx.new()
	re_e.compile("\\[ENEMY:([a-zA-Z ]+)\\]")
	var me = re_e.search(reply)

	var re_bg := RegEx.new()
	re_bg.compile("\\[BG:([^\\]]+)\\]")
	var mbg = re_bg.search(reply)

	if _screen == Screen.PLAYER_AKI and mp != null:
		_player_en  = mp.get_string(1).strip_edges()
		_player_msg = reply.replace(mp.get_string(), "").strip_edges()
		_show_decision(_player_msg)
		await get_tree().create_timer(2.5).timeout
		_start_enemy_akinator()
	elif _screen == Screen.ENEMY_AKI and me != null:
		_enemy_en  = me.get_string(1).strip_edges()
		_enemy_msg = reply.replace(me.get_string(), "").strip_edges()
		_show_decision(_enemy_msg)
		await get_tree().create_timer(2.5).timeout
		_start_bg_akinator()
	elif _screen == Screen.BG_AKI and mbg != null:
		_bg_prompt = mbg.get_string(1).strip_edges()
		var disp : String = reply.replace(mbg.get_string(), "").strip_edges()
		_show_decision(disp)
		await get_tree().create_timer(2.5).timeout
		_start_generation()
	elif mq != null:
		# [Q]タグ付き質問文だけを表示
		_update_question(mq.get_string(1).strip_edges())
	else:
		# フォールバック：最後の行を質問として表示
		var lines : Array = reply.strip_edges().split("\n")
		var last : String = ""
		for line : String in lines:
			if not line.strip_edges().is_empty():
				last = line.strip_edges()
		_update_question(last if not last.is_empty() else reply.strip_edges())

# =====================================================================
# GENERATING
# =====================================================================
func _start_generation() -> void:
	_screen = Screen.GENERATING
	_clear_ui()
	var cx : float = VP_W * 0.5

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 165.0, 340.0)
	vbox.add_theme_constant_override("separation", 18)
	_ui.add_child(vbox)

	var title := Label.new()
	title.text = "スプライトを生成中..."
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_progress_lbl = Label.new()
	_progress_lbl.text = "0 / 5"
	_progress_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_progress_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 5.0
	_progress_bar.value     = 0.0
	_progress_bar.custom_minimum_size = Vector2(330, 28)
	vbox.add_child(_progress_bar)

	_step_lbl = Label.new()
	_step_lbl.text = "準備中..."
	_step_lbl.add_theme_font_size_override("font_size", 14)
	_step_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vbox.add_child(_step_lbl)

	if _http_gen.request_completed.is_connected(_on_gen_done):
		_http_gen.request_completed.disconnect(_on_gen_done)
	_http_gen.request_completed.connect(_on_gen_done)

	_gen_queue   = _build_gen_queue()
	_gen_current = 0
	_send_gen_next()

func _build_gen_queue() -> Array:
	var p  : String = _player_en if not _player_en.is_empty() else "boy"
	var e  : String = _enemy_en  if not _enemy_en.is_empty()  else "ghost"
	var bg : String = _bg_prompt if not _bg_prompt.is_empty() else "fantasy sky landscape"
	return [
		{"filename": "player_custom_idle", "prompt": "cute chibi %s character, back view, standing idle pose, white background, game sprite pixel art" % p},
		{"filename": "player_custom_walk", "prompt": "cute chibi %s character, back view, walking mid-step, white background, game sprite pixel art" % p},
		{"filename": "enemy_custom_white", "prompt": "cute white %s, chibi style, round chubby body, bright white color, white background, game sprite pixel art" % e},
		{"filename": "enemy_custom_black", "prompt": "cute dark black %s, chibi style, round chubby body, dark color, white background, game sprite pixel art" % e},
		{"filename": "bg_custom",          "prompt": "%s, vertical scrolling game background, seamless tiling, pixel art style" % bg},
	]

func _send_gen_next() -> void:
	if _gen_current >= _gen_queue.size():
		_on_all_generated()
		return
	var item : Dictionary = _gen_queue[_gen_current]
	if is_instance_valid(_step_lbl):
		_step_lbl.text = "%s を生成中..." % STEP_NAMES[_gen_current]
	if is_instance_valid(_progress_lbl):
		_progress_lbl.text = "%d / %d" % [_gen_current, _gen_queue.size()]
	if is_instance_valid(_progress_bar):
		_progress_bar.value = float(_gen_current)
	var headers : PackedStringArray = ["Content-Type: application/json"]
	_http_gen.request(N8N_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(item))

func _on_gen_done(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_gen_current += 1
	if is_instance_valid(_progress_bar):
		_progress_bar.value = float(_gen_current)
	if is_instance_valid(_progress_lbl):
		_progress_lbl.text = "%d / %d" % [_gen_current, _gen_queue.size()]
	if is_instance_valid(_step_lbl) and _gen_current <= STEP_NAMES.size():
		_step_lbl.text = "✓ %s 完了" % STEP_NAMES[_gen_current - 1]
	_send_gen_next()

func _on_all_generated() -> void:
	_http_gen.request_completed.disconnect(_on_gen_done)
	if is_instance_valid(_step_lbl):
		_step_lbl.text = "スプライトを同期中..."
	var path : String = ProjectSettings.globalize_path("res://")
	var out   : Array  = []
	OS.execute("git", ["-C", path, "pull"], out, true)
	var sm : Node = get_node_or_null("/root/SkinManager")
	if sm:
		sm.register_skin("custom", {
			"player_idle":      "res://assets/sprites/player_custom_idle.png",
			"player_walk":      "res://assets/sprites/player_custom_walk.png",
			"player_raise":     "res://assets/sprites/player_custom_idle.png",
			"player_raise_walk":"res://assets/sprites/player_custom_walk.png",
			"enemy_white":      "res://assets/sprites/enemy_custom_white.png",
			"enemy_white_anim": "res://assets/sprites/enemy_custom_white.png",
			"enemy_black":      "res://assets/sprites/enemy_custom_black.png",
			"enemy_black_anim": "res://assets/sprites/enemy_custom_black.png",
			"bg":               "res://assets/sprites/bg_custom.png",
		})
		sm.set_skin("custom")
		sm.confirm_skin()
	_show_ready()

# =====================================================================
# READY
# =====================================================================
func _show_ready() -> void:
	_screen = Screen.READY
	_clear_ui()
	var cx : float = VP_W * 0.5

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(cx - 165.0, 360.0)
	vbox.add_theme_constant_override("separation", 20)
	_ui.add_child(vbox)

	var r_lbl := Label.new()
	r_lbl.text = "準備完了！ 🎮"
	r_lbl.add_theme_font_size_override("font_size", 36)
	r_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	vbox.add_child(r_lbl)

	if not _player_en.is_empty() or not _enemy_en.is_empty():
		var i_lbl := Label.new()
		i_lbl.text = "自機: %s  /  敵: %s" % [_player_en, _enemy_en]
		i_lbl.add_theme_font_size_override("font_size", 15)
		i_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
		vbox.add_child(i_lbl)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(sep)

	var start_btn := Button.new()
	start_btn.text = "▶  ゲームスタート！"
	start_btn.custom_minimum_size = Vector2(330, 70)
	start_btn.add_theme_font_size_override("font_size", 20)
	vbox.add_child(start_btn)
	start_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
