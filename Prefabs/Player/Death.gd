extends Control

# Handles the death screen's fade in. After a period of time, the last save
# is loaded

export var fade_time := 2.0
export var show_time := 2.0

var time_fade := 0.0
var time_show := 0.0

func _ready():
	visible = false
	modulate.a = 0.0
	set_process(false)

# This is called by the player.gd. This allows the death screen to fade in
func set_dead():
	visible = true
	get_tree().paused = true
	set_process(true)

func _process(delta):
	# Keep track of how much time has passed since the death screen started
	time_fade += delta
	time_fade = min(time_fade, fade_time)
		
	var percent := time_fade / fade_time
		
	modulate.a = percent
		
	if time_fade >= fade_time:
		# Keep track of how long the death screen has been shown since it
		# finished the fade in
		time_show += delta
		
		if time_show >= show_time:
			GameState.load_game()
