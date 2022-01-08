extends CSGBox
tool

export var open_offset := Vector3.ZERO
export var open_speed := 1.0
export var show_open_animation := false

var required_switches := 0
var triggered_switches := 0
var door_open_amount := 0.0
var door_open_target := 0.0

onready var door_closed_pos := translation

func register_switch():
	required_switches += 1

func triggered_switch():
	triggered_switches += 1
	
	if triggered_switches == required_switches:
		door_open_target = 1.0

func _process(delta):
	if Engine.editor_hint and show_open_animation:
		door_open_amount += delta * open_speed
		door_open_amount = fmod(door_open_amount, 1.0)
		print("Hi")
	
	else:
		var door_open_delta := door_open_target - door_open_amount
		door_open_delta = min(door_open_delta, open_speed)
		
		door_open_amount += delta * door_open_delta
	
	translation = translation + open_offset * door_open_amount
	
	
