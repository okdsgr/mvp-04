extends Node

# 静的スキン定義
const BUILT_IN_SKINS : Dictionary = {
	"default": {
		"player_idle":      "res://assets/sprites/player_idle.png",
		"player_walk":      "res://assets/sprites/player_walk.png",
		"player_raise":     "res://assets/sprites/player_raise.png",
		"player_raise_walk":"res://assets/sprites/player_raise_walk.png",
		"enemy_white":      "res://assets/sprites/ghost_detailed.png",
		"enemy_white_anim": "res://assets/sprites/ghost_white_anim.png",
		"enemy_black":      "res://assets/sprites/ghost_black_retro_v3.png",
		"enemy_black_anim": "res://assets/sprites/ghost_black_anim.png",
		"display_name":     "おばけ & 少年",
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
		"display_name":     "車 & 猫",
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
		"display_name":     "牛 & 犬",
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
		"display_name":     "テレビ & UFO",
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
		"display_name":     "ケーキ & コップ",
	},
}

# 動的スキン（生成されたもの）
var _dynamic_skins : Dictionary = {}

var active_skin : String = "default"

func set_skin(skin_name: String) -> void:
	var all_skins := _get_all_skins()
	if skin_name in all_skins:
		active_skin = skin_name
		print("[SkinManager] skin: ", skin_name)
	else:
		push_warning("[SkinManager] unknown skin: " + skin_name)

func register_dynamic_skin(skin_name: String, display_name: String) -> void:
	# 生成されたスプライトのパスを自動構築
	_dynamic_skins[skin_name] = {
		"player_idle":      "res://assets/sprites/" + skin_name + "_player_idle.png",
		"player_walk":      "res://assets/sprites/" + skin_name + "_player_walk.png",
		"player_raise":     "res://assets/sprites/" + skin_name + "_player_idle.png",
		"player_raise_walk":"res://assets/sprites/" + skin_name + "_player_walk.png",
		"enemy_white":      "res://assets/sprites/" + skin_name + "_enemy_white.png",
		"enemy_white_anim": "res://assets/sprites/" + skin_name + "_enemy_white.png",
		"enemy_black":      "res://assets/sprites/" + skin_name + "_enemy_black.png",
		"enemy_black_anim": "res://assets/sprites/" + skin_name + "_enemy_black.png",
		"display_name":     display_name,
	}
	print("[SkinManager] registered dynamic skin: ", skin_name)

func get_all_skin_names() -> Array:
	return _get_all_skins().keys()

func get_display_name(skin_name: String) -> String:
	var all_skins := _get_all_skins()
	if skin_name in all_skins:
		return all_skins[skin_name].get("display_name", skin_name)
	return skin_name

func get_texture(key: String) -> Texture2D:
	var all_skins := _get_all_skins()
	var skin : Dictionary = all_skins.get(active_skin, BUILT_IN_SKINS["default"])
	var path : String = skin.get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		path = BUILT_IN_SKINS["default"].get(key, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

func _get_all_skins() -> Dictionary:
	var all := BUILT_IN_SKINS.duplicate()
	for k in _dynamic_skins:
		all[k] = _dynamic_skins[k]
	return all
