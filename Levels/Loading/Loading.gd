extends Control

var loader : ResourceInteractiveLoader
var status := OK
var once := true
var load_path := ""

func _ready():
	get_tree().paused = false
	load_path = GameState._load_path
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	loader = ResourceLoader.load_interactive(load_path)
	if loader == null:
		status = ERR_CANT_OPEN

func _process(_delta):
	if status == OK:
		var percent := float(loader.get_stage()) / loader.get_stage_count()
		$CenterContainer/Text.text = str(int(percent*100.0)) + "%"
		status = loader.poll()
	
	elif status == ERR_FILE_EOF:
		if once:
			once = false
			$CenterContainer/Text.text = "100%"
		else:
			var scene = loader.get_resource()
			scene = scene.instance()
			get_tree().current_scene.call_deferred("free")
			get_tree().root.call_deferred("add_child", scene)
			GameState.call_deferred("_done_loading", scene)
			queue_free()
	
	elif once:
		once = false
		push_error("Could not load scene " + load_path)
