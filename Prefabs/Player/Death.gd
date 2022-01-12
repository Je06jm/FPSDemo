extends Control

export var fade_time := 2.0
export var show_time := 2.0

var died := false
var time_fade := 0.0
var time_show := 0.0

func _ready():
	visible = false
	modulate.a = 0.0

func set_dead():
	visible = true
	died = true
	get_tree().paused = true

func _process(delta):
	if died:
		time_fade += delta
		time_fade = min(time_fade, fade_time)
		
		var percent := time_fade / fade_time
		
		modulate.a = percent
		
		if time_fade >= fade_time:
			time_show += delta
			
			if time_show >= show_time:
				GameState.load_game()
