extends Spatial

export var open_height := 4.0
export var move_speed := 1.0

var body_count := 0
var can_open := true

onready var closed_height : float = $Door.translation.y
onready var opened_height : float = closed_height + open_height

func _physics_process(delta):
	if body_count > 0:
		$Door.translation.y += move_speed * delta
	else:
		$Door.translation.y -= move_speed * delta
	
	$Door.translation.y = min(max($Door.translation.y, closed_height), opened_height)


func _on_Area_body_entered(_body):
	body_count += 1


func _on_Area_body_exited(_body):
	body_count -= 1
