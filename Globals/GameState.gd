extends Node

const gravity := -400.0

var mouse_sensitivity := 5
var joy_sensitivity := 2

var health := 100
var clip_ammo := 5
var total_ammo := 200

var player_damage := 8
var player_damage_rand := 2
var player_ammo_from_guns := 15
var player_ammo_from_guns_rand := 5

var enemy_damage := 1
var enemy_damage_rand := 1

var enemy_seeks_health_at := 0.25

var enemy_see_player_dot := 0.25
var enemy_see_player_virticaly := 1.5 # Human virtical FOV is 2.61799
var enemy_see_player_distance := 35.0

var enemy_remember_player_time := 15.0
var enemy_remember_player_time_random := 5.0

var enemy_fire_within_dot := 0.95
var enemy_wait_time_to_fire := 0.1
var enemy_wait_time_random := 0.2

var enemy_look_random_sphere_size := 0.25
var enemy_look_max_height_angle := 0.25
var enemy_look_min_height_angle := -0.15
var enemy_look_time := 1.0
var enemy_look_time_random := 0.5

var enemy_move_rand_distance := 2.0

var enemy_gunshot_hear_distance := 30.0
var enemy_gunshot_guess_distance := 20.0

var config := {}

const save_name := "user://game.save"
var _load_path := ""

func load_level(path : String):
	_load_path = path
# warning-ignore:return_value_discarded
	get_tree().change_scene("Levels/Loading/Loading.tscn")

func _done_loading(scene):
	get_tree().current_scene = scene

func new_game():
	config = {}
	save_game()

func has_save_game() -> bool:
	var file := File.new()
	return file.file_exists(save_name)

func get_data(key : String, default = null):
	if not config.has(key):
		config[key] = default
	
	return config[key]
	
func set_data(key : String, value):
	config[key] = value

func get_vec2(key : String, default := Vector2.ZERO) -> Vector2:
	var result := Vector2.ZERO
	result.x = get_data(key + ".x", default.x)
	result.y = get_data(key + ".y", default.y)
	return result

func set_vec2(key : String, value : Vector2):
	set_data(key + ".x", value.x)
	set_data(key + ".y", value.y)

func get_vec3(key : String, default := Vector3.ZERO) -> Vector3:
	var result := Vector3.ZERO
	result.x = get_data(key + ".x", default.x)
	result.y = get_data(key + ".y", default.y)
	result.z = get_data(key + ".z", default.z)
	return result

func set_vec3(key : String, value : Vector3):
	set_data(key + ".x", value.x)
	set_data(key + ".y", value.y)
	set_data(key + ".z", value.z)

func get_flag(key : String, default := false):
	return get_data(key, default)

func set_flag(key : String, value : bool):
	set_data(key, value)

func get_unique_id(node : Node) -> String:
	var node_path := node.get_path()
	var node_str := _load_path
	
	for i in range(node_path.get_name_count()):
		node_str += "/" + node_path.get_name(i)
		
	return node_str + "/"

func save_game():
	var file := File.new()
# warning-ignore:return_value_discarded
	file.open_compressed(save_name, File.WRITE, File.COMPRESSION_GZIP)
	if not file.is_open():
		push_warning("Could not save game")
		return
	
	file.store_string(JSON.print(config))
	file.close()

func load_game():
	var file := File.new()
# warning-ignore:return_value_discarded
	file.open_compressed(save_name, File.READ, File.COMPRESSION_GZIP)
	if not file.is_open():
		push_warning("Could not load game")
		return
	
	var result := JSON.parse(file.get_as_text())
	file.close()
	
	if result.error != OK:
		var err := "Could not parse save game(" + str(result.error_line) + "): "
		err += result.error_string
		push_warning(err)
		return
	
	config = result.result

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

const DifficultyStrings := [
	"Easy",
	"Normal",
	"Hard"
]

var current_difficulty : int = Difficulty.NORMAL

func set_difficulty(difficulty : int):
	current_difficulty = difficulty
	var file = File.new()
	file.open("res://difficulties.tres", File.READ)
	if not file.is_open():
		push_error("Could not open difficulties")
		get_tree().quit()
	
	var result := JSON.parse(file.get_as_text())
	file.close()
	
	if result.error != OK:
		var err = "Could not parse difficulties(" + str(result.error_line) + ")"
		err += ": " + result.error_string
		push_error(err)
		get_tree().quit()
		return
	
	var setting = {}
	if difficulty == Difficulty.EASY:
		setting = result.result["easy"]
	
	if difficulty == Difficulty.NORMAL:
		setting = result.result["normal"]
	
	if difficulty == Difficulty.HARD:
		setting = result.result["hard"]

	for property in setting:
		if get(property) == null:
			push_warning("GameState does not have property " + property)
		
		else:
			set(property, setting[property])

const autosave_time := 60 * 5 # 5 minutes
var autosave_timer := float(autosave_time)
func _process(delta):
	if (not get_tree().paused) and (_load_path != ""):
		autosave_timer -= delta
		
		if autosave_timer <= 0.0:
			save_game()
			autosave_timer = autosave_time
