extends Control

# Handles the win screen and scrolls the credits

export var fade_time := 2.0
export var scroll_speed := 60.0
export var scroll_finish := 3100.0

var time_fade := 0.0
var any_pressed := false

func _ready():
	visible = false
	modulate.a = 0.0
	set_process(false)

# If a key/button is pressed, set a variable the will skip the credits
func _input(event):
	var is_joy := event is InputEventJoypadButton
	var is_key := event is InputEventKey
	var is_mouse := event is InputEventMouseButton
	if (is_joy or is_key or is_mouse) and event.is_pressed():
		any_pressed = true

# Pauses the tree and starts the win screen
func set_win():
	visible = true
	get_tree().paused = true
	set_process(true)

# Fades in the win screen and the scroll the credits
func _process(delta):
	time_fade += delta
	time_fade = min(time_fade, fade_time)
		
	var percent := time_fade / fade_time
		
	modulate.a = percent
		
	if time_fade >= fade_time:
		# Scrolls the credits
		$Scroll.rect_position.y -= scroll_speed * delta
			
		if (abs($Scroll.rect_position.y) >= scroll_finish) or any_pressed:
			GameState.load_level("Levels/Menu/Menu.tscn")

	else:
		# You can't skip until the fade is finished
		any_pressed = false
