extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var visible_data_name = GameState.get_unique_id($VisibleShapes)
onready var attachment_data_name = GameState.get_unique_id($AttachmentPoint)

var started := false
func start_ragdoll():
	$VisibleShapes.translation = GameState.get_vec3(visible_data_name + "translation", $VisibleShapes.translation)
	$VisibleShapes.sleeping = GameState.get_data(visible_data_name + "sleeping", $VisibleShapes.sleeping)
	$VisibleShapes.linear_velocity = GameState.get_vec3(visible_data_name + "linear_velocity", $VisibleShapes.linear_velocity)
	$VisibleShapes.angular_velocity = GameState.get_vec3(visible_data_name + "angular_velocity", $VisibleShapes.angular_velocity)
	$VisibleShapes.rotation = GameState.get_vec3(visible_data_name + "rotation", $VisibleShapes.rotation)
	
	if has_node("AttachmentPoint"):
		$AttachmentPoint.translation = GameState.get_vec3(attachment_data_name + "translation", $AttachmentPoint.translation)
		$AttachmentPoint.sleeping = GameState.get_data(attachment_data_name + "sleeping", $AttachmentPoint.sleeping)
		$AttachmentPoint.linear_velocity = GameState.get_vec3(attachment_data_name + "linear_velocity", $AttachmentPoint.linear_velocity)
		$AttachmentPoint.angular_velocity = GameState.get_vec3(attachment_data_name + "angular_velocity", $AttachmentPoint.angular_velocity)
		$AttachmentPoint.rotation = GameState.get_vec3(attachment_data_name + "rotation", $AttachmentPoint.rotation)
	
	var has_attachment_point = GameState.get_data(attachment_data_name + "has_attachment_point", true)
	
	if not has_attachment_point:
		$AttachmentPoint.call_deferred("queue_free")
		call_deferred("remove_child", $AttachmentPoint)
	
	started = true


func _process(_delta):
	if started:
		if not $VisibleShapes.sleeping:
			GameState.set_vec3(visible_data_name + "translation", $VisibleShapes.translation)
			GameState.set_vec3(visible_data_name + "linear_velocity", $VisibleShapes.linear_velocity)
			GameState.set_vec3(visible_data_name + "angular_velocity", $VisibleShapes.angular_velocity)
			GameState.set_vec3(visible_data_name + "rotation", $VisibleShapes.rotation)
	
		else:
			GameState.set_data(visible_data_name + "sleeping", true)
	
		if has_node("AttachmentPoint"):
			if not $AttachmentPoint.sleeping:
				GameState.set_vec3(attachment_data_name + "translation", $AttachmentPoint.translation)
				GameState.set_vec3(attachment_data_name + "linear_velocity", $AttachmentPoint.linear_velocity)
				GameState.set_vec3(attachment_data_name + "angular_velocity", $AttachmentPoint.angular_velocity)
				GameState.set_vec3(attachment_data_name + "rotation", $AttachmentPoint.rotation)
	
			else:
				GameState.set_data(attachment_data_name + "sleeping", true)
		else:
			GameState.set_data(attachment_data_name + "has_attachment_point", false)
