extends Control

# Controls the loading screen and the loading in of new scenes

var loader : ResourceInteractiveLoader
var status := OK
var once := true
var load_path := ""

# Unpauses the tree and free the mouse. Also create a resource loader for
# the scene we are trying to load
func _ready():
	get_tree().paused = false
	load_path = GameState._load_path
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	loader = ResourceLoader.load_interactive(load_path)
	if loader == null:
		status = ERR_CANT_OPEN

# Handles loading the scene, updating the screen, and error handling
func _process(_delta):
	if status == OK:
		# Update the screen to show the percentage of the level that has been
		# loaded
		var percent := float(loader.get_stage()) / loader.get_stage_count()
		$CenterContainer/Text.text = str(int(percent*100.0)) + "%"
		status = loader.poll()
	
	elif status == ERR_FILE_EOF:
		if once:
			# Set the screen to show 100%
			once = false
			$CenterContainer/Text.text = "100%"
		else:
			# Creates an instance of the loaded scene. Add the new scene to the
			# tree and then free ourselfs
			var scene = loader.get_resource()
			scene = scene.instance()
			get_tree().root.call_deferred("add_child", scene)
			GameState.call_deferred("_done_loading", scene)
			queue_free()
	
	else:
		# Could not load scene. Push error and quit()
		push_error("Could not load scene " + load_path)
		get_tree().quit()
