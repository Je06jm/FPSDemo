extends StaticBody
class_name HealthConsole

export var max_health := 20
export var current_health := 15
export var time_between_giving := 0.15

var giving_timer := 0.0
var bodies := []
var body_index := 0

onready var data_name = GameState.get_unique_id(self)

func _update_indicator():
	var percent := float(current_health) / max_health
	
	$HealthConsoleModel.set_indicator(percent)

func _ready():
	current_health = GameState.get_data(data_name + "current_health", current_health)
	_update_indicator()

func _process(delta):
	if (len(bodies) != 0) and (current_health != 0):
		if giving_timer <= 0.0:
			body_index += 1
			body_index = body_index % len(bodies)
			
			var taken : int = bodies[body_index].give_health(1)
			current_health -= taken
			GameState.set_data(data_name + "current_health", current_health)
			
			_update_indicator()
			
			giving_timer = time_between_giving
		
		else:
			giving_timer -= delta

func _on_Area_body_entered(body):
	if body.has_method("give_health"):
		bodies += [body]


func _on_Area_body_exited(body):
	if body in bodies:
		bodies.remove(bodies.find(body))
