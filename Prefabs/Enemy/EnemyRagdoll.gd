extends Spatial

# Handles the enemy's static body

onready var visible_data_name = GameState.get_unique_id($VisibleShapes)
onready var attachment_data_name = GameState.get_unique_id($AttachmentPoint)

func _ready():
	set_process(false)

# Sets the initial state of all the rigid bodies and then enable processing
func start_ragdoll():
	# Gets the initial state of the rigid bodies from the GameState
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
	
	set_process(true)

# Records information about the rigid bodies to the GameState
func _process(_delta):
	if not $VisibleShapes.sleeping:
		# Sets GameState information about the VisibleShapes rigid body
		GameState.set_vec3(visible_data_name + "translation", $VisibleShapes.translation)
		GameState.set_vec3(visible_data_name + "linear_velocity", $VisibleShapes.linear_velocity)
		GameState.set_vec3(visible_data_name + "angular_velocity", $VisibleShapes.angular_velocity)
		GameState.set_vec3(visible_data_name + "rotation", $VisibleShapes.rotation)
	
	else:
		GameState.set_data(visible_data_name + "sleeping", true)
	
	if has_node("AttachmentPoint"):
		if not $AttachmentPoint.sleeping:
			# Sets GameState information about the AttachmentPoint rigid body
			GameState.set_vec3(attachment_data_name + "translation", $AttachmentPoint.translation)
			GameState.set_vec3(attachment_data_name + "linear_velocity", $AttachmentPoint.linear_velocity)
			GameState.set_vec3(attachment_data_name + "angular_velocity", $AttachmentPoint.angular_velocity)
			GameState.set_vec3(attachment_data_name + "rotation", $AttachmentPoint.rotation)
	
		else:
			GameState.set_data(attachment_data_name + "sleeping", true)
	else:
		GameState.set_data(attachment_data_name + "has_attachment_point", false)
