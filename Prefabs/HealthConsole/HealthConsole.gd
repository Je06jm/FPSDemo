extends StaticBody
class_name HealthConsole

# Handles giving health to the player and enemies

export var max_health := 20
export var current_health := 15
export var time_between_giving := 0.15

var giving_timer := 0.0
var bodies := []
var body_index := 0

onready var data_name = GameState.get_unique_id(self)

# Helper function to call the function that updates the indicator
func _update_indicator():
	var percent := float(current_health) / max_health
	
	$HealthConsoleModel.set_indicator(percent)

# Gets the current health from the GameState
func _ready():
	current_health = GameState.get_data(data_name + "current_health", current_health)
	_update_indicator()

# Calculates how much health to give each body in the area
func _process(delta):
	if (len(bodies) != 0) and (current_health != 0):
		# Don't give health every frame, instead, give it every N seconds
		if giving_timer <= 0.0:
			# Only one body is given health each frame
			body_index += 1
			body_index = body_index % len(bodies)
			
			# Give the body health. The body returns the amount of health taken,
			# so we use that value to update how much health is left
			var taken : int = bodies[body_index].give_health(1)
			current_health -= taken
			GameState.set_data(data_name + "current_health", current_health)
			
			_update_indicator()
			
			giving_timer = time_between_giving
		
		else:
			giving_timer -= delta

# If the body can take health, add it to the list of bodies
func _on_Area_body_entered(body):
	if body.has_method("give_health"):
		bodies += [body]

# If the body is in the list of bodies, remove it
func _on_Area_body_exited(body):
	if body in bodies:
		bodies.remove(bodies.find(body))
