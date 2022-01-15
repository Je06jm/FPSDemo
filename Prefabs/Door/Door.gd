extends Spatial
tool

# Controls the opening and closing of the door

export var open_offset := Vector3.ZERO
export var open_speed := 2.5
export var show_open_animation := false

var door_open_amount := 0.0
var door_open_target := 0.0
var door_process := true

var bodies := 0

onready var door_closed_pos : Vector3 = $Door.translation

# Handles the opening and closing of the door
func _process(delta):
	if Engine.editor_hint and show_open_animation:
		# This shows how far the door opens while in the editor
		door_open_amount += delta * open_speed
		door_open_amount = fmod(door_open_amount, 1.0)
		door_process = true
	
	elif Engine.editor_hint:
		if door_process and (door_closed_pos != null):
			# While in the editor, this prevents the door from sliding from it's
			# inital placement
			$Door.translation = door_closed_pos
			door_open_amount = 0.0
		
		# This allows the door's placement to be changed in the editor
		door_closed_pos = $Door.translation
		door_process = false
	
	else:
		# This determins how far the door is opened in game
		var door_open_delta := door_open_target - door_open_amount
		door_open_delta = min(door_open_delta, open_speed * delta)
		door_open_delta = max(door_open_delta, -open_speed * delta)
		
		door_open_amount += door_open_delta
	
	if door_process:
		$Door.translation = door_closed_pos + open_offset * door_open_amount
	

# Increases the count of the bodies in the area. This allow opens the door
func _on_Area_body_entered(_body):
	bodies += 1
	door_open_target = 1.0

# Decreases the count of the bodies in the area and handles the closing of the
# door
func _on_Area_body_exited(_body):
	bodies -= 1
	
	if bodies == 0:
		# When the number of bodies is zero, close the door
		door_open_target = 0.0
