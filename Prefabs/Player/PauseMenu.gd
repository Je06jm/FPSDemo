extends Control

enum SettingsQuality {
	CUSTOM,
	LOW,
	MEDIUM,
	HIGH,
	HIGHEST
}

const SettingsQualityStrings := [
	"Custom",
	"Low",
	"Medium",
	"High",
	"Highest"
]

const config_path := "user://graphics.cfg"

var config := {}
var save_file := false

func _read_config():
	var file := File.new()
	if not file.file_exists(config_path):
		print("?")
		return false
		
# warning-ignore:return_value_discarded
	file.open(config_path, File.READ)
	
	if not file.is_open():
		push_warning("Could not open " + config_path + " for reading")
		return false
	
	var result = JSON.parse(file.get_as_text())
	file.close()
	
	if result.error != OK:
		var err := "Could not parse " + config_path + "("
		err += str(result.error_line) + "): " + result.error_string
		push_warning(err)
		return false
	
	config = result.result
	return true

func _write_config():
	var file := File.new()
# warning-ignore:return_value_discarded
	file.open(config_path, File.WRITE)
	
	if not file.is_open():
		push_warning("Could not open " + config_path + " for writting")
		return
	
	file.store_string(JSON.print(config, "", true))
	
	file.close()

func _ready():
	visible = false
	
	if not _read_config():
		print("No config")
		config["quality"] = SettingsQuality.MEDIUM
		config["shadows"] = SettingsQuality.MEDIUM
		config["reflections"] = SettingsQuality.MEDIUM
		config["lighting"] = SettingsQuality.MEDIUM
		config["textures"] = SettingsQuality.MEDIUM
		config["aliasing"] = SettingsQuality.MEDIUM
		config["joy_sensitivity"] = 10
		config["mouse_sensitivity"] = 10
	
	if config["quality"] != SettingsQuality.CUSTOM:
		config["shadows"] = config["quality"]
		config["reflections"] = config["quality"]
		config["lighting"] = config["quality"]
		config["textures"] = config["quality"]
		config["aliasing"] = config["quality"]
	
	_settings_set_sensitivity(config["joy_sensitivity"], true)
	_settings_set_sensitivity(config["mouse_sensitivity"], false)
	_settings_set_quality(config["quality"])
	_settings_set_shadows(config["shadows"])
	_settings_set_reflections(config["reflections"])
	_settings_set_lighting(config["lighting"])
	_settings_set_textures(config["textures"])
	_settings_set_aliasing(config["aliasing"])
	
	$Main/Difficulty/CenterContainer/Text.text = GameState.DifficultyStrings[GameState.current_difficulty]

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

func _process(_delta):
	if Input.is_action_just_pressed("ui_toggle_key"):
		_toggle_menu()

	elif Input.is_action_just_pressed("ui_toggle_joy"):
		_toggle_menu()
		

func _Main_on_Resume_pressed():
	_toggle_menu()

func _Main_on_Difficulty_pressed():
	GameState.current_difficulty += 1
	GameState.current_difficulty %= GameState.Difficulty.HARD + 1
	
	$Main/Difficulty/CenterContainer/Text.text = GameState.DifficultyStrings[GameState.current_difficulty]
	
	GameState.set_difficulty(GameState.current_difficulty)

func _Main_on_Settings_pressed():
	$Main.visible = false
	$Settings.visible = true
	$Settings/Quality.grab_focus()

func _Main_on_Menu_pressed():
	GameState.save_game()
	GameState.load_level("Levels/Menu/Menu.tscn")

func _settings_set_sensitivity(value : int, joy : bool):
	if joy:
		GameState.joy_sensitivity = value
		config["joy_sensitivity"] = value
		$Settings/ControllerSensitivity.value = value
	
	else:
		GameState.mouse_sensitivity = value
		config["mouse_sensitivity"] = value
		$Settings/MouseSensitivity.value = value

func _settings_set_quality(quality : int):
	$Settings/Quality/CenterContainer/Text.text = SettingsQualityStrings[quality]
	config["quality"] = quality
	
	var disable_buttons = quality != SettingsQuality.CUSTOM
	$Settings/Shadows.disabled = disable_buttons
	$Settings/Reflections.disabled = disable_buttons
	$Settings/Lighting.disabled = disable_buttons
	$Settings/Textures.disabled = disable_buttons
	$Settings/Aliasing.disabled = disable_buttons

func _settings_set_shadows(quality : int):
	if quality == SettingsQuality.CUSTOM:
		return
	
	$Settings/Shadows/CenterContainer/Text.text = SettingsQualityStrings[quality]
	config["shadows"] = quality

func _settings_set_reflections(quality : int):
	if quality == SettingsQuality.CUSTOM:
		return
	
	$Settings/Reflections/CenterContainer/Text.text = SettingsQualityStrings[quality]
	config["reflections"] = quality

func _settings_set_lighting(quality : int):
	if quality == SettingsQuality.CUSTOM:
		return
	
	$Settings/Lighting/CenterContainer/Text.text = SettingsQualityStrings[quality]
	config["lighting"] = quality

func _settings_set_textures(quality : int):
	if quality == SettingsQuality.CUSTOM:
		return
	
	$Settings/Textures/CenterContainer/Text.text = SettingsQualityStrings[quality]
	config["textures"] = quality

func _settings_set_aliasing(quality : int):
	if quality == SettingsQuality.CUSTOM:
		return
	
	$Settings/Aliasing/CenterContainer/Text.text = SettingsQualityStrings[quality]
	config["aliasing"] = quality

func _settings_inc(quality : int, can_be_zero := false) -> int:
	quality += 1
	quality %= SettingsQuality.HIGHEST + 1
	if not can_be_zero:
		quality = int(max(quality, 1))
	return quality

func _settings_value(quality : int, low, medium, high, highest):
	if config["quality"] != SettingsQuality.CUSTOM:
		quality = config["quality"]
	
	if quality == SettingsQuality.LOW:
		return low
	
	elif quality == SettingsQuality.MEDIUM:
		return medium
	
	elif quality == SettingsQuality.HIGH:
		return high
	
	elif quality == SettingsQuality.HIGHEST:
		return highest

func _settings_apply():
	var value = _settings_value(config["shadows"], 1024, 2048, 4096, 8192)
	ProjectSettings.set_setting("rendering/quality/directional_shadow/size", value)
	value = _settings_value(config["shadows"], 128, 256, 512, 1024)
	ProjectSettings.set_setting("rendering/quality/shadow_atlas/size", value)
	value = _settings_value(config["shadows"], 0, 1, 1, 2)
	ProjectSettings.set_setting("rendering/quality/shadow_filter/mode", value)
	
	value = _settings_value(config["reflections"], false, false, true, true)
	ProjectSettings.set_setting("rendering/quality/reflections/texture_array_reflections", value)
	value = _settings_value(config["reflections"], false, false, true, true)
	ProjectSettings.set_setting("rendering/quality/reflections/high_quality_ggx", value)
	value = _settings_value(config["reflections"], 512, 1024, 2048, 4096)
	ProjectSettings.set_setting("rendering/quality/reflections/atlas_size", value)
	
	value = _settings_value(config["lighting"], true, false, false, false)
	ProjectSettings.set_setting("rendering/quality/shading/force_vertex_shading", value)
	value = _settings_value(config["lighting"], true, true, false, false)
	ProjectSettings.set_setting("rendering/quality/shading/force_lambert_over_burley", value)
	value = _settings_value(config["lighting"], true, true, true, false)
	ProjectSettings.set_setting("rendering/quality/shading/force_blinn_over_gss", value)
	
	value = _settings_value(config["textures"], 0, 2, 8, 16)
	ProjectSettings.set_setting("rendering/quality/filters/anisotropic_filter_level", value)
	
	value = _settings_value(config["lighting"], 0, 1, 2, 3)
	ProjectSettings.set_setting("rendering/quality/filters/msaa", value)
	value = _settings_value(config["lighting"], true, false, false, false)
	ProjectSettings.set_setting("rendering/quality/filters/fxaa", value)
	
# warning-ignore:return_value_discarded
	ProjectSettings.save()

func _Settings_on_MouseSensitivity_value_changed(value):
	_settings_set_sensitivity(value, false)
	save_file = true

func _Settings_on_ControllerSensitivity_value_changed(value):
	_settings_set_sensitivity(value, true)
	save_file = true

func _Settings_on_Quality_pressed():
	var quality : int = _settings_inc(config["quality"], true)
	_settings_set_quality(quality)
	$Settings/Changes.visible = true

func _Settings_on_Shadows_pressed():
	var quality : int = _settings_inc(config["shadows"])
	_settings_set_shadows(quality)
	$Settings/Changes.visible = true

func _Settings_on_Reflections_pressed():
	var quality : int = _settings_inc(config["reflections"])
	_settings_set_reflections(quality)
	$Settings/Changes.visible = true

func _Settings_on_Lighting_pressed():
	var quality : int = _settings_inc(config["lighting"])
	_settings_set_lighting(quality)
	$Settings/Changes.visible = true

func _Settings_on_Textures_pressed():
	var quality : int = _settings_inc(config["textures"])
	_settings_set_textures(quality)
	$Settings/Changes.visible = true

func _Settings_on_Aliasing_pressed():
	var quality : int = _settings_inc(config["aliasing"])
	_settings_set_aliasing(quality)
	$Settings/Changes.visible = true

func _Settings_on_Back_pressed():
	$Settings.visible = false
	$Main.visible = true
	$Main/Resume.grab_focus()
	
	if $Settings/Changes.visible:
		_write_config()
		_settings_apply()
		
		GameState.load_level(get_tree().get_current_scene().filename)
	
	elif save_file:
		_write_config()
