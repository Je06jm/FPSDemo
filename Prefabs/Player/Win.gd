extends Control

export var fade_time := 2.0
export var scroll_speed := 60.0
export var scroll_finish := 3100.0

var win := false
var time_fade := 0.0
var any_pressed := false

func _ready():
	visible = false
	modulate.a = 0.0

func _input(event):
	if (event is InputEventJoypadButton) or (event is InputEventKey) or (event is InputEventMouseButton):
		any_pressed = true

func set_win():
	visible = true
	win = true
	get_tree().paused = true

func _process(delta):
	if win:
		time_fade += delta
		time_fade = min(time_fade, fade_time)
		
		var percent := time_fade / fade_time
		
		modulate.a = percent
		
		if time_fade >= fade_time:
			$Scroll.rect_position.y -= scroll_speed * delta
			
			if (abs($Scroll.rect_position.y) >= scroll_finish) or any_pressed:
				GameState.load_level("Levels/Menu/Menu.tscn")

		else:
			any_pressed = false
