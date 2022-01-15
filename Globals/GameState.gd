extends Node

# Handles the game state/global variables

# Common variables

const gravity := -400.0

# Player variables

var mouse_sensitivity := 5
var joy_sensitivity := 2

var health := 100
var clip_ammo := 5
var total_ammo := 200

var player_damage := 8
var player_damage_rand := 2
var player_ammo_from_guns := 15
var player_ammo_from_guns_rand := 5

# Enemy variables

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
var enemy_look_max_height_angle := 0.10
var enemy_look_min_height_angle := -0.10
var enemy_look_time := 1.0
var enemy_look_time_random := 0.5

var enemy_move_rand_distance := 2.0

var enemy_gunshot_hear_distance := 25.0
var enemy_gunshot_guess_distance := 20.0

# GameState functions/variables

var config := {}

const save_name := "user://game.save"
var _load_path := ""

# Loads the loading screen and sets the scene to load
func load_level(path : String):
	_load_path = path
# warning-ignore:return_value_discarded
	get_tree().change_scene("Levels/Loading/Loading.tscn")
	_can_autosave = false

# Called by the loading screen. This resets the autosave timer
func _done_loading(scene):
	get_tree().current_scene = scene
	_can_autosave = true
	_autosave_timer = _autosave_time

# Empties config and saves the game
func new_game():
	config = {}
	save_game()

# Returns true if there is a save game
func has_save_game() -> bool:
	var file := File.new()
	return file.file_exists(save_name)

# Returns data from key in config or default is the key is not in config
func get_data(key : String, default = null):
	if not config.has(key):
		config[key] = default
	
	return config[key]

# Sets the data in the key in config
func set_data(key : String, value):
	config[key] = value

# A helper function to get a vector2 from config
func get_vec2(key : String, default := Vector2.ZERO) -> Vector2:
	var result := Vector2.ZERO
	result.x = get_data(key + ".x", default.x)
	result.y = get_data(key + ".y", default.y)
	return result

# A helper function to set a vector2 in config
func set_vec2(key : String, value : Vector2):
	set_data(key + ".x", value.x)
	set_data(key + ".y", value.y)

# A helper function to get a vector3 from config
func get_vec3(key : String, default := Vector3.ZERO) -> Vector3:
	var result := Vector3.ZERO
	result.x = get_data(key + ".x", default.x)
	result.y = get_data(key + ".y", default.y)
	result.z = get_data(key + ".z", default.z)
	return result

# A helper function to set a vector3 in config
func set_vec3(key : String, value : Vector3):
	set_data(key + ".x", value.x)
	set_data(key + ".y", value.y)
	set_data(key + ".z", value.z)

# A helper function to get a boolean from config
func get_flag(key : String, default := false) -> bool:
	return get_data(key, default)

# A helper function to set a boolean in config
func set_flag(key : String, value : bool):
	set_data(key, value)

# Generates a unique string to represent an object's data in config
func get_unique_id(node : Node) -> String:
	var node_path := node.get_path()
	var node_str := _load_path
	
	for i in range(node_path.get_name_count()):
		node_str += "/" + node_path.get_name(i)
		
	return node_str + "/"

# Sets the current level in config, then serialize and saves save file
func save_game():
	# Sets current level
	var level := _load_path
	if (level == "") or (level == null):
		level = get_tree().current_scene.filename
		
	set_data("current_level", level)
	
	# Open file and handle errors
	var file := File.new()
# warning-ignore:return_value_discarded
	file.open_compressed(save_name, File.WRITE, File.COMPRESSION_GZIP)
	if not file.is_open():
		push_warning("Could not save game")
		return
	
	# Serialize and save config
	file.store_string(JSON.print(config))
	file.close()

# Loads save file and parse config
func load_game():
	# Open save file and handle errors
	var file := File.new()
# warning-ignore:return_value_discarded
	file.open_compressed(save_name, File.READ, File.COMPRESSION_GZIP)
	if not file.is_open():
		push_warning("Could not load game")
		return
	
	# Parse file contents into config
	var result := JSON.parse(file.get_as_text())
	file.close()
	
	# Handle parsing errors
	if result.error != OK:
		var err := "Could not parse save game(" + str(result.error_line) + "): "
		err += result.error_string
		push_warning(err)
		return
	
	config = result.result
	
	# Loads the current level
	var level : String = get_data("current_level")
	if level:
		load_level(level)

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

# Opens difficulties file and parses GameState
func set_difficulty(difficulty : int):
	# Opens difficulties file and handle errors
	current_difficulty = difficulty
	var file = File.new()
	file.open("res://difficulties.json", File.READ)
	if not file.is_open():
		push_error("Could not open difficulties")
		get_tree().quit()
	
	# Parses file's content
	var result := JSON.parse(file.get_as_text())
	file.close()
	
	# Handle parsing errors
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

	# Update GameState based on difficulty settings
	for property in setting:
		if get(property) == null:
			push_warning("GameState does not have property " + property)
		
		else:
			set(property, setting[property])

const _autosave_time := 60 * 5 # 5 minutes
var _autosave_timer := float(_autosave_time)
var _can_autosave := true
# Autosaves game after 5 minutes
func _process(delta):
	if (not get_tree().paused) and (_load_path != "") and _can_autosave:
		_autosave_timer -= delta
		
		if _autosave_timer <= 0.0:
			save_game()
			_autosave_timer = _autosave_time
