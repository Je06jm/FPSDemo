extends Spatial

# Handles the switch animation and notifies the door of the state

export var door : NodePath

var once := true

onready var door_node : Node = get_node(door)
onready var switch_id := GameState.get_unique_id(self)

# Notify the door that this switch is connected to it and play the off animation
func _ready():
	if (door_node != null) and (door_node.has_method("register_switch")):
		door_node.register_switch()
	
	if GameState.get_flag(switch_id, false):
		interact()
	
	else:
		$AnimationPlayer.play("Off")

# Notify the door that this switch was pulled and play the pulled animation
func interact():
	if (door_node != null) and (door_node.has_method("triggered_switch")) and once:
		once = false
		door_node.triggered_switch()
		
		if GameState.get_flag(switch_id, false):
			$AnimationPlayer.play("On")
		else:
			$AnimationPlayer.play("OffToOn")
			GameState.set_flag(switch_id, true)


# When the pull animation is finished, play the on animation
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "OffToOn":
		$AnimationPlayer.play("On")
