extends Control

# Handles the pause menu and setting the game's settings

const config_path := "user://settings.cfg"

var config := {}

# Reads the settings file and then parse it
func _read_config():
	# Opens file and check for errors
	var file := File.new()
	if not file.file_exists(config_path):
		return false
		
# warning-ignore:return_value_discarded
	file.open(config_path, File.READ)
	
	if not file.is_open():
		push_warning("Could not open " + config_path + " for reading")
		return false
	
	# Parse the file's contents
	var result = JSON.parse(file.get_as_text())
	file.close()
	
	if result.error != OK:
		var err := "Could not parse " + config_path + "("
		err += str(result.error_line) + "): " + result.error_string
		push_warning(err)
		return false
	
	config = result.result
	return true

# Serialize config and then save it into the settings file
func _write_config():
	# Opens the settings for writting
	var file := File.new()
# warning-ignore:return_value_discarded
	file.open(config_path, File.WRITE)
	
	if not file.is_open():
		push_warning("Could not open " + config_path + " for writting")
		return
	
	# Serialize and save  config
	file.store_string(JSON.print(config, "", true))
	
	file.close()

# Reads the settings file and then update the GameState
func _ready():
	visible = false
	
	if not _read_config():
		push_warning("No config found, generating a new config")
		
		config["joy_sensitivity"] = 10
		config["mouse_sensitivity"] = 10
	
	# These will update the GameState
	_settings_set_sensitivity(config["joy_sensitivity"], true)
	_settings_set_sensitivity(config["mouse_sensitivity"], false)
	
	# Update difficulty text to reflect the current difficulty
	$Main/Difficulty/CenterContainer/Text.text = GameState.DifficultyStrings[GameState.current_difficulty]

# Pauses/unpauses the tree and uncaptures/captures the mouse. Also shows/hides
# the menu
func _toggle_menu():
	visible = not visible
	get_tree().paused = visible
		
	if visible:
		$Main.visible = true
		$Settings.visible = false
		
		$Main/Resume.grab_focus()
		
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_exit_menu()

# Handles input
func _process(_delta):
	if Input.is_action_just_pressed("ui_toggle_key"):
		_toggle_menu()

	elif Input.is_action_just_pressed("ui_toggle_joy"):
		_toggle_menu()
		

# Hides the menu when the resume button is pressed
func _Main_on_Resume_pressed():
	_toggle_menu()

# Changes difficulty when the difficulty button is pressed
func _Main_on_Difficulty_pressed():
	GameState.current_difficulty += 1
	GameState.current_difficulty %= GameState.Difficulty.HARD + 1
	
	$Main/Difficulty/CenterContainer/Text.text = GameState.DifficultyStrings[GameState.current_difficulty]
	
	GameState.set_difficulty(GameState.current_difficulty)

# Shows the settings menu when the settings button is pressed
func _Main_on_Settings_pressed():
	$Main.visible = false
	$Settings.visible = true
	$Settings/MouseSensitivity.grab_focus()

# Goto the main menu when the menu button is pressed
func _Main_on_Menu_pressed():
	GameState.save_game()
	GameState.load_level("Levels/Menu/Menu.tscn")

# Sets the sensitivity of the mouse and joysick
func _settings_set_sensitivity(value : int, joy : bool):
	if joy:
		# Sets the joystick sensitivity
		GameState.joy_sensitivity = value
		config["joy_sensitivity"] = value
		$Settings/ControllerSensitivity.value = value
	
	else:
		# Sets the mouse sensitivity
		GameState.mouse_sensitivity = value
		config["mouse_sensitivity"] = value
		$Settings/MouseSensitivity.value = value

# Updates the mouse sensitivity when the mouse sensitivity slider is changed
func _Settings_on_MouseSensitivity_value_changed(value):
	_settings_set_sensitivity(value, false)

# Updates the joystick sensitivity when the joystick sensitivity slider is
# changed
func _Settings_on_ControllerSensitivity_value_changed(value):
	_settings_set_sensitivity(value, true)

# Hides the settings menu when the back button is pressed in the settings menu
func _Settings_on_Back_pressed():
	$Settings.visible = false
	$Main.visible = true
	$Main/Resume.grab_focus()
	_exit_menu()

# Writes the settings
func _exit_menu():
	_write_config()
