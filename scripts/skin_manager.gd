extends Node

var SKINS : Dictionary = {
	"default": {
		"player_idle":      "res://assets/sprites/player_idle.png",
		"player_walk":      "res://assets/sprites/player_walk.png",
		"player_raise":     "res://assets/sprites/player_raise.png",
		"player_raise_walk":"res://assets/sprites/player_raise_walk.png",
		"enemy_white":      "res://assets/sprites/ghost_detailed.png",
		"enemy_white_anim": "res://assets/sprites/ghost_white_anim.png",
		"enemy_black":      "res://assets/sprites/ghost_black_retro_v3.png",
		"enemy_black_anim": "res://assets/sprites/ghost_black_anim.png",
	},
	"cat_car": {
		"player_idle":      "res://assets/sprites/player_cat_idle.png",
		"player_walk":      "res://assets/sprites/player_cat_walk.png",
		"player_raise":     "res://assets/sprites/player_cat_idle.png",
		"player_raise_walk":"res://assets/sprites/player_cat_walk.png",
		"enemy_white":      "res://assets/sprites/enemy_white_car.png",
		"enemy_white_anim": "res://assets/sprites/enemy_white_car.png",
		"enemy_black":      "res://assets/sprites/enemy_black_car.png",
		"enemy_black_anim": "res://assets/sprites/enemy_black_car.png",
	},
	"dog_cow": {
		"player_idle":      "res://assets/sprites/player_dog_idle.png",
		"player_walk":      "res://assets/sprites/player_dog_walk.png",
		"player_raise":     "res://assets/sprites/player_dog_idle.png",
		"player_raise_walk":"res://assets/sprites/player_dog_walk.png",
		"enemy_white":      "res://assets/sprites/enemy_white_cow.png",
		"enemy_white_anim": "res://assets/sprites/enemy_white_cow.png",
		"enemy_black":      "res://assets/sprites/enemy_black_cow.png",
		"enemy_black_anim": "res://assets/sprites/enemy_black_cow.png",
	},
	"ufo_tv": {
		"player_idle":      "res://assets/sprites/player_ufo_idle.png",
		"player_walk":      "res://assets/sprites/player_ufo_walk.png",
		"player_raise":     "res://assets/sprites/player_ufo_idle.png",
		"player_raise_walk":"res://assets/sprites/player_ufo_walk.png",
		"enemy_white":      "res://assets/sprites/enemy_white_tv.png",
		"enemy_white_anim": "res://assets/sprites/enemy_white_tv.png",
		"enemy_black":      "res://assets/sprites/enemy_black_tv.png",
		"enemy_black_anim": "res://assets/sprites/enemy_black_tv.png",
	},
	"cup_cake": {
		"player_idle":      "res://assets/sprites/player_cup_idle.png",
		"player_walk":      "res://assets/sprites/player_cup_walk.png",
		"player_raise":     "res://assets/sprites/player_cup_idle.png",
		"player_raise_walk":"res://assets/sprites/player_cup_walk.png",
		"enemy_white":      "res://assets/sprites/enemy_white_cake.png",
		"enemy_white_anim": "res://assets/sprites/enemy_white_cake.png",
		"enemy_black":      "res://assets/sprites/enemy_black_cake.png",
		"enemy_black_anim": "res://assets/sprites/enemy_black_cake.png",
	},
}

var active_skin    : String = "default"
var skin_confirmed : bool   = false  # タイトル画面から確定したらtrue

func set_skin(skin_name: String) -> void:
	if skin_name in SKINS:
		active_skin = skin_name
		print("[SkinManager] skin: ", skin_name)
	else:
		push_warning("[SkinManager] unknown skin: " + skin_name)

func confirm_skin() -> void:
	skin_confirmed = true

func register_skin(skin_name: String, data: Dictionary) -> void:
	SKINS[skin_name] = data
	print("[SkinManager] registered: ", skin_name)

func get_texture(key: String) -> Texture2D:
	var skin : Dictionary = SKINS.get(active_skin, SKINS["default"])
	var path : String = skin.get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		path = SKINS["default"].get(key, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null
