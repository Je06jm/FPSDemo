extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	load_scene(GameState._load_path)

func load_scene(path : String):
	var loader := ResourceLoader.load_interactive(path)
	
	var status := OK
	
	while status == OK:
		var percent := float(loader.get_stage()) / loader.get_stage_count()
		$CenterContainer/Temp.text = str(int(percent*100.0)) + "%"
		status = loader.poll()
	
	if status != ERR_FILE_EOF:
		push_error("Could not load scene " + path)
		get_tree().quit()
	
	$CenterContainer/Temp.text = "100%"
	
	var scene = loader.get_resource()
	scene = scene.instance()
	get_tree().current_scene.call_deferred("free")
	get_tree().root.call_deferred("add_child", scene)
	GameState.call_deferred("_done_loading", scene)
	call_deferred("queue_free")

