extends Spatial

export var door : NodePath

var once := true

onready var door_node : Node = get_node(door)

# Called when the node enters the scene tree for the first time.
func _ready():
	if (door_node != null) and (door_node.has_method("register_switch")):
		door_node.register_switch()
	
	$AnimationPlayer.play("Off")

func interact():
	if (door_node != null) and (door_node.has_method("triggered_switch")) and once:
		once = false
		door_node.triggered_switch()
		$AnimationPlayer.play("OffToOn")
		print("Hello")


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "OffToOn":
		$AnimationPlayer.play("On")
