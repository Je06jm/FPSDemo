extends KinematicBody

export var max_speed := 200.0
export var acceleration := 800.0
export var air_acceleration := 500.0
export var deceleration := 20.0
export var jump := 250.0

export var max_look_speed := 100.0
export var max_look_speed_standing := 500.0

export var max_ammo_per_clip := 50
export var max_health := 50
export var max_fire_range := 30.0
export var flee_ammo_amount := 10
export var min_seek_player_distance := 5.0
export var max_seek_player_distance := 10.0

export var look_for_gunshot_time := 5.0
export var look_for_gunshot_time_random := 1.0

export var can_see_player := true

export var navigation_path : NodePath
export var player_path : NodePath
export var navigation_nodes_path : NodePath
export var patrol_nodes_path : NodePath
export var health_nodes_path : NodePath

export var navigation_node_size := 1.5

export var stop_processing_ragdoll_distance := 50.0

var velocity := Vector3.ZERO

var is_firing := false
var is_reloading := false

var look_at_pos := Vector3.ZERO
var last_look_point := Vector3.ZERO

var last_seen_player := 0.0
var can_forget_player := true 

var patrol_wait_time := 0.0
var patrol_can_wait := false

var heard_gunshot := false
var heard_new_gunshot := false
var gunshot_location_guess := Vector3.ZERO
var seeking_health := false

onready var ammo := max_ammo_per_clip
onready var health = max_health

var target_health := 0

var paths := []

onready var navigation : Navigation = get_node(navigation_path)
onready var player : Spatial = get_node(player_path)
onready var hide_distance := pow(stop_processing_ragdoll_distance, 2.0)

const look_timer_set := 0.1
const look_timer_rand := 0.35
const look_timer_set_hit := 1.0
const look_timer_rand_hit := 0.5
var new_look_timer := 0.1
var look_sphere := Vector3.ZERO

const move_timer_set := 0.1
const move_timer_rand := 0.15
var new_move_timer := 0.1

var gunshot_timer := 0.1
var gunshot_can_look := false

var player_last_known_position := Vector3.ZERO

onready var data_name = GameState.get_unique_id(self)

# Sets up the enemy initial state
func _ready():
	$CamHing/BulletCast.cast_to *= max_fire_range
	
	global_transform.origin = GameState.get_vec3(data_name + "translation", global_transform.origin)
	var look_rotation := Vector2($CamHing.rotation.x, rotation.y)
	look_rotation = GameState.get_vec2(data_name + "look_rotation", look_rotation)
	$CamHing.rotation.x = look_rotation.x
	rotation.y = look_rotation.y
	
	velocity = GameState.get_vec3(data_name + "velocity", velocity)
	
	look_at_pos = GameState.get_vec3(data_name + "look_at_pos", look_at_pos)
	last_look_point = GameState.get_vec3(data_name + "last_look_point", last_look_point)
	
	last_seen_player = GameState.get_data(data_name + "last_seen_player", last_seen_player)
	can_forget_player = GameState.get_data(data_name + "can_forget_player", can_forget_player)
	
	patrol_wait_time = GameState.get_data(data_name + "patrol_wait_time", patrol_wait_time)
	patrol_can_wait = GameState.get_data(data_name + "patrol_can_wait", patrol_can_wait)
	
	heard_gunshot = GameState.get_data(data_name + "heard_gunshot", heard_gunshot)
	heard_new_gunshot = GameState.get_data(data_name + "heard_new_gunshot", heard_new_gunshot)
	gunshot_location_guess = GameState.get_vec3(data_name + "gunshot_location_guess", gunshot_location_guess)
	
	health = GameState.get_data(data_name + "health", health)
	ammo = GameState.get_data(data_name + "ammo", ammo)
	
	target_health = GameState.get_data(data_name + "target_health", target_health)
	
	var last_move_to = GameState.get_vec3(data_name + "last_move_to", global_transform.origin)
# warning-ignore:return_value_discarded
	_ai_move_to(last_move_to)

	new_look_timer = GameState.get_data(data_name + "new_look_timer", new_look_timer)
	look_sphere = GameState.get_vec3(data_name + "look_sphere", look_sphere)
	
	new_move_timer = GameState.get_data(data_name + "new_move_timer", new_move_timer)
	
	gunshot_timer = GameState.get_data(data_name + "gunshot_timer", gunshot_timer)
	gunshot_can_look = GameState.get_data(data_name + "gunshot_can_look", gunshot_can_look)
	
	player_last_known_position = GameState.get_vec3(data_name + "player_last_known_position", player_last_known_position)
	
	
	seek_weapon_start = GameState.get_data(data_name + "seek_weapon_start", seek_weapon_start)
	
	patrol_type = GameState.get_data(data_name + "patrol_type", patrol_type)
	patrol_current = GameState.get_data(data_name + "patrol_current", patrol_current)
	patrol_reverse = GameState.get_data(data_name + "patrol_reverse", patrol_reverse)
	
# warning-ignore:return_value_discarded
	player.connect("on_fire", self, "_signal_on_fire")
	
	_check_health()

# Handles enemy movement. This is based on the player's movement script
func _process(delta):
	# Only calculate movement and animations if the enemy is not dead
	if health > 0:
		# Update various timers
		new_move_timer -= delta
		new_look_timer -= delta
		GameState.set_data(data_name + "new_move_timer", new_move_timer)
		GameState.set_data(data_name + "new_look_timer", new_look_timer)
		
		if can_forget_player:
			last_seen_player -= delta
			GameState.set_data(data_name + "last_seen_player", last_seen_player)
		
		if patrol_can_wait:
			patrol_wait_time -= delta
			GameState.set_data(data_name + "patrol_wait_time", patrol_wait_time)
			
		if gunshot_can_look:
			gunshot_timer -= delta
			GameState.set_data(data_name + "gunshot_timer", gunshot_timer)
			
		_ai_look_at(look_at_pos, delta)
		
		# Get the state of the firing and reloading annimations
		is_firing = $AnimationTree["parameters/FireOneShot/active"]
		is_reloading = $AnimationTree["parameters/ReloadOneShot/active"]
		
		# Setting the FlashLight visibility to false now allows it to be visible for
		# a single frame
		$CamHing/AttachmentPoint/FlashLight.visible = false
		
		# Calculate movement vector
		var movement := _process_ai_movement(delta)
		var xzMovement := Vector2(movement.x, movement.z)
		xzMovement = xzMovement.normalized()
		movement.x = xzMovement.x
		movement.z = xzMovement.y
	
		# Apply movement force to velocity
		if movement.length_squared() >= 0.01:
			velocity.x += movement.x * (acceleration * delta)
			velocity.z += movement.z * (acceleration * delta)
			velocity.y += movement.y
	
		# Apply friction force to velocity
		else:
			var force : Vector2 = Vector2(velocity.x, velocity.z)
			force *= deceleration * delta
			velocity.x -= force.x
			velocity.z -= force.y
			
		# Clamps the movement speed to the max_speed
		var movement_speed := Vector2(velocity.x, velocity.z)
		if movement_speed.length() > max_speed:
			movement_speed = movement_speed.normalized() * max_speed
	
		velocity.x = movement_speed.x
		velocity.z = movement_speed.y
	
		# Apply gravity
		if movement.y <= 0.0:
			velocity.y += GameState.gravity * delta

		# Use movement speed to determing how much to blend between the idle and
		# walking animations
		var idle_walk : float = movement.length() * 2.0 - 1.0
		$AnimationTree.set("parameters/Movement/Idle-Walk/blend_position", idle_walk)
		
	else:
		# Fade out the ragdoll when the player is far enough. When compleatly
		# faded out, set the visibility to false. Otherwise, set visibility to
		# true
		var distance := player.global_transform.origin.distance_squared_to(global_transform.origin)
		if distance >= hide_distance:
			visible = false
		else:
			visible = true
	
# Since the movement is physics based, we actually apply the movement here
func _physics_process(delta):
	# Again, don't do anything when dead
	if health > 0:
		var new_velocity : Vector3
		new_velocity = move_and_slide(velocity * delta, Vector3.UP, true) / delta
	
		# Applies a continues downward force to help the player stick to ramps
		# when moving downwards
		if abs(velocity.y - new_velocity.y) >= 0.2:
			new_velocity.y -= 2.0
	
		velocity = new_velocity
		GameState.set_vec3(data_name + "translation", global_transform.origin)
		GameState.set_vec3(data_name + "velocity", velocity)

# Reloads gun and playes the reload animation
func _ai_reload():
	$AnimationTree["parameters/ReloadOneShot/active"] = true
	ammo = max_ammo_per_clip
	GameState.set_data(data_name + "ammo", ammo)

# Fires the gun and playes the fire animation
func _ai_fire() -> bool:
	if not is_firing and not is_reloading and ammo != 0:
		$AnimationTree["parameters/FireOneShot/active"] = true
		$CamHing/AttachmentPoint/FlashParticles.emitting = true
		$CamHing/AttachmentPoint/FlashLight.visible = true
		ammo -= 1
		GameState.set_data(data_name + "ammo", ammo)
		return true
	
	return false

# Changes the enemy/gun rotation to point twords the given point
func _ai_look_at(world_pos : Vector3, delta : float):
	# Extract the required information to create two plains
	var xzPlane := Vector3(world_pos.x, global_transform.origin.y, world_pos.z)
	var plane := Vector2(xzPlane.x, xzPlane.z)
	var current := Vector2(global_transform.origin.x, global_transform.origin.z)
	
	# Calculate the difference between the current look direction and the
	# required direction
	var angle := Vector2.ZERO
	
	angle.x = -current.angle_to_point(plane) + PI/2
	if angle.x > PI:
		angle.x -= 2*PI
	
	var base0 : float = xzPlane.distance_to(global_transform.origin)
	var base1 : float = world_pos.y - global_transform.origin.y
	
	if abs(base0) != 0.0:
		angle.y = atan(base1 / base0)
	
	# Clamp the delta of the new look direction
	var current_angle := Vector2(rotation.y, $CamHing.rotation.x)
	var delta_angle := angle - current_angle
	
	if abs(delta_angle.x) > abs(delta_angle.x - 2*PI):
		delta_angle.x = delta_angle.x - 2*PI
	
	elif abs(delta_angle.x) > abs(delta_angle.x + 2*PI):
		delta_angle.x = delta_angle.x + 2*PI
	
	var look_speed := 0.0
	
	# Calculate the current look speed
	var speed := Vector2(velocity.x, velocity.z).length_squared()
	var percent := speed / pow(max_speed, 2.0)
	
	look_speed = max_look_speed * percent + max_look_speed_standing * (1.0 - percent)
	
	look_speed = deg2rad(look_speed) * delta
	
	# Clamp the delta angle to the look speed
	if delta_angle.length() > look_speed:
		delta_angle = delta_angle.normalized() * look_speed
	
	# Apply delta angle
	rotation.y += delta_angle.x
	$CamHing.rotation.x += delta_angle.y
	
	var look_rotation := Vector2($CamHing.rotation.x, rotation.y)
	GameState.set_vec2(data_name + "look_rotation", look_rotation)

# Calculates a new path for the enemy to move along
func _ai_move_to(pos : Vector3) -> bool:
	pos = navigation.get_closest_point(pos)
	paths = navigation.get_simple_path(global_transform.origin, pos)
	if len(paths) == 0:
		return false
	else:
		GameState.set_vec3(data_name + "last_move_to", pos)
		return true

# Empties the movement path resulting in the enemy's movement stopping
func _ai_reset_movement():
	paths = []
	GameState.set_data(data_name + "paths_count", 0)

# Returns true when the enemy is moving
func _ai_is_moving() -> bool:
	return len(paths) != 0

# Calculates a random point for the enemy to look at
func _ai_look_randomly():
	# Calculates a new timer value
	new_look_timer = GameState.enemy_look_time
	new_look_timer += randf() * GameState.enemy_look_time_random
	GameState.set_data(data_name + "new_look_timer", new_look_timer)
	
	# Creates a random point on a sphere
	var rand_sphere := Vector3.ZERO
	var angle = randf() * 2 * PI
	rand_sphere.x = cos(angle)
	rand_sphere.z = sin(angle)
	
	var look_diff = GameState.enemy_look_max_height_angle
	look_diff -= GameState.enemy_look_min_height_angle
	
	angle = randf() * look_diff
	angle -= GameState.enemy_look_min_height_angle
	
	rand_sphere.y = sin(angle)
	
	# Add random sphere to the last look pos
	rand_sphere = rand_sphere.normalized()
	var new_point = last_look_point + rand_sphere
	look_at_pos = last_look_point + rand_sphere
	GameState.set_vec3(data_name + "look_at_pos", look_at_pos)
	
	# Set the last look point
	last_look_point = to_local(new_point)
	last_look_point = last_look_point.normalized()
	
	# Clamp the new random look pos to min and max look height angle
	angle = asin(last_look_point.y)
	if angle > GameState.enemy_look_max_height_angle:
		angle -= GameState.enemy_look_max_height_angle
		angle += GameState.enemy_look_min_height_angle
	
	elif angle < GameState.enemy_look_min_height_angle:
		angle += GameState.enemy_look_min_height_angle
		angle = GameState.enemy_look_max_height_angle + angle
	
	last_look_point.y = sin(angle)
	
	last_look_point = to_global(last_look_point)
	GameState.set_vec3(data_name + "last_look_point", last_look_point)

# Makes the enemy look twords the direction of movement
func _ai_look_twords_movement():
	# Check to see if we are actually moving
	if _ai_is_moving():
		# Using velocity is easier then calculating direction from the movement
		# path
		var next : Vector3 = velocity
		
		next.y = 0
		next = next.normalized()
		
		# Calculate how up and down the look vector will be
		var diff = get_floor_normal() - Vector3.UP
		
		var looking := Vector2(next.x, next.z)
		var diff_plane := Vector2(diff.x, diff.z)
		
		looking = looking.normalized()
		diff_plane = diff_plane.normalized()
		
		# Calculate forward vector
		next.y = diff.y * diff_plane.dot(looking) * 2.0
		
		next = global_transform.origin + next
		
		# Set look at pos
		look_at_pos = next
		GameState.set_vec3(data_name + "look_at_pos", look_at_pos)

# A helper function to set where the eye cast is pointing to
func _ai_eye_cast(pos : Vector3) -> Spatial:
	$EyeCast.cast_to = to_local(pos)
	return $EyeCast.get_collider()

# A helper funcction that returns the collider for the bullet ray cast
func _ai_bullet_cast() -> Spatial:
	return $CamHing/BulletCast.get_collider()

# Finds all the subnodes of a given type for the given node
func _ai_find_all_nodes(root_node : Spatial, type : int, exclude := []) -> Array:
	var nodes := []
	
	for _child in root_node.get_children():
		if exclude.find(_child) != -1:
			continue
		
		elif not (typeof(_child) == type):
			continue
		
		nodes += [_child]
	
	return nodes

# Finds the nearest subnode of a given type for the given node
func _ai_find_nearest_node(root_node : Spatial, type : int, exclude := []) -> Spatial:
	var nearest_node : Spatial = null
	var nearest_distance := 0.0
	
	var nodes := _ai_find_all_nodes(root_node, type, exclude)
	
	for _child in nodes:
		if not (_child is Spatial):
			continue
		
		var child : Spatial = _child
		var distance := child.global_transform.origin.distance_squared_to(global_transform.origin)
		
		# Check to see if the current child node is closer then what we have so
		# far
		if (distance < nearest_distance) or (nearest_node == null):
			nearest_node = child
			nearest_distance = distance
	
	return nearest_node

# Similar to _ai_find_all_nodes, but it checks for AI navigation node of type
func _ai_find_all_navigation(root_node : Spatial, type : int, exclude := []) -> Array:
	var nodes := []
	
	for _child in root_node.get_children():
		if exclude.find(_child) != -1:
			continue
		
		elif not (_child is NavigationNode):
			continue
			
		var child : NavigationNode = _child
		
		# Check navigation node type
		if not (child.type == type) and (type != NavigationNode.Type.NONE):
			continue
			
		nodes += [child]
	
	return nodes

# Similar to _ai_find_nearest_node, but it checks for AI navigation node of type
func _ai_find_nearest_navigation(root_node : Spatial, type : int, exclude := []) -> NavigationNode:
	var nearest_node : NavigationNode = null
	var nearest_distance := 0.0
	
	var nodes := _ai_find_all_navigation(root_node, type, exclude)
	
	for child in nodes:
		var distance : float = child.global_transform.origin.distance_squared_to(global_transform.origin)
		
		# Check to see if the current child node is closer then what we have so
		# far
		if (distance < nearest_distance) or (nearest_node == null):
			nearest_node = child
			nearest_distance = distance
	
	return nearest_node

# This is called when the player fires a bullet. If the enemy is close enough,
# it will guess where the player is
func _signal_on_fire():
	# See if the enemy is close enough to hear the player fire
	var gunshot_distance := player.global_transform.origin.distance_squared_to(global_transform.origin)
	if gunshot_distance <= pow(GameState.enemy_gunshot_hear_distance, 2.0):
		heard_new_gunshot = true
		GameState.set_data(data_name + "heard_new_gunshot", heard_new_gunshot)
		
		# Generate a random point on a sphere
		var guess := Vector3.ZERO
		var angle := randf() * 2 * PI
		guess.x = cos(angle)
		guess.y = sin(angle)
		angle = randf() * 2 * PI
		guess.z = sin(angle)
		
		# Calculate the final guess
		guess *= randf() * GameState.enemy_gunshot_guess_distance
		
		gunshot_location_guess = player.global_transform.origin + guess
		GameState.set_vec3(data_name + "gunshot_location_guess", gunshot_location_guess)

# Determin if the enemy should seek cover
func task_condition_ai_seek_cover(task):
	# Can't seek cover while seeking health
	if seeking_health:
		task.failed()
	
	else:
		if ammo <= flee_ammo_amount or is_reloading:
			task.succeed()
		else:
			task.failed()

# Move the enemy to the nearest cover
func task_ai_seek_cover(task):
	# Get the nearest cover node
	var cover : NavigationNode
	cover = _ai_find_nearest_navigation(get_node(navigation_nodes_path), NavigationNode.Type.COVER)
	if cover:
		# Move twords a random point from the cover node
# warning-ignore:return_value_discarded
		_ai_move_to(cover.get_point_away_from(player.global_transform.origin))
		_ai_look_twords_movement()
		task.succeed()
	
	else:
		# There are no cover nodes
		task.failed()

# Determin if the enemy can see the player
func task_condition_ai_seek_player(task):
	# The enemy can be blind, but this is only useful in debugging other
	# behaviors
	if not can_see_player:
		task.failed()
		return
	
	# Get the player's direction
	var player_direction := global_transform.origin.direction_to(player.global_transform.origin)
	var forward := -transform.basis.z
	
	# Determin if the player is in the enemy's FOV
	if forward.dot(player_direction) < GameState.enemy_see_player_dot:
		task.failed()
		return
	
	# Get the player's distance
	var player_distance := global_transform.origin.distance_squared_to(player.global_transform.origin)
	
	# Determin if the player is close enough to be seen
	if player_distance > pow(GameState.enemy_see_player_distance, 2.0):
		task.failed()
		return
	
	# Another check to see if the player is in the enemy's FOV
	var angle = asin(player_direction.y)
	if abs(angle) > GameState.enemy_see_player_virticaly:
		task.failed()
		return
	
	# Check the eye ray cast to see if it returns the player
	var eye_cast := _ai_eye_cast(player.global_transform.origin)
	
	if eye_cast != player:
		task.failed()
	
	else:
		task.succeed()

# Move
func task_ai_seek_player(task):
	patrol_path = []
	
	# Only move if we are not seeking health
	if not seeking_health:
		# Do a check to see if the player is at a wanted distance
		var player_distance := global_transform.origin.distance_to(player.global_transform.origin)
		var farther_than_max := player_distance > max_seek_player_distance
		var closer_than_min := player_distance < min_seek_player_distance
		var out_of_bounds := farther_than_max or closer_than_min
	
		if out_of_bounds:
			# Determin a new point to make the player be at a wanted distance
			
			# Create a random point within a sphere
			var new_point := Vector3.ZERO
			var angle := randf() * (2 * PI)
			new_point.x = cos(angle)
			new_point.z = sin(angle)
			var distance := randf()
			distance *= max_seek_player_distance - min_seek_player_distance
			distance += min_seek_player_distance
			
			new_point *= distance
				
			# Calculate the new point
			var move_point := new_point + player.global_transform.origin
			
			# Make sure that the new point is not on the other side of the
			# player. If so, just move the point to this size
			var direction_to_player = global_transform.origin - player.global_transform.origin
			
			if direction_to_player.dot(move_point) > 0.0:
				move_point = -new_point + player.global_transform.origin
		
			# Move to the new point
			if _ai_move_to(new_point):
				new_move_timer = move_timer_set + randf() * move_timer_rand
				GameState.set_data(data_name + "new_move_timer", new_move_timer)
		
		# The enemy moves a small amount every little bit of time
		elif new_move_timer <= 0.0:
			# Creates a random point within a sphere
			var new_point := Vector3.ZERO
			var angle := randf() * (2 * PI)
			new_point.x = cos(angle)
			new_point.z = sin(angle)
			var distance := randf() * GameState.enemy_move_rand_distance
			
			# Calculates the new point
			new_point *= distance
			new_point += global_transform.origin
			
			# Move to the new point
			if _ai_move_to(new_point):
				new_move_timer = move_timer_set + randf() * move_timer_rand
				GameState.set_data(data_name + "new_move_timer", new_move_timer)
		
		# The enemy looks around a little bit every little bit of time
		if new_look_timer <= 0.0:
			new_look_timer = look_timer_set + randf() * look_timer_rand
			GameState.set_data(data_name + "new_look_timer", new_look_timer)
			
			# Creates a random point withing a sphere
			look_sphere.x = rand_range(-1.0, 1.0)
			look_sphere.y = rand_range(-1.0, 1.0)
			look_sphere.z = rand_range(-1.0, 1.0)
			look_sphere = look_sphere.normalized()
			look_sphere *= GameState.enemy_look_random_sphere_size
			GameState.set_vec3(data_name + "look_sphere", look_sphere)
			
			# Look at the sphere
			look_at_pos = player.global_transform.origin + look_sphere
			GameState.set_vec3(data_name + "look_at_pos", look_at_pos)
	
	player_last_known_position = player.global_transform.origin
	can_forget_player = false
	GameState.set_data(data_name + "player_last_known_position", player_last_known_position)
	GameState.set_data(data_name + "can_forget_player", can_forget_player)
	
	task.succeed()

# Determin if the enemy should look for the player where the enemy last saw them
func task_condition_ai_seek_player_last_pos(task):
	if not can_see_player or seeking_health:
		task.failed()
		return
	
	if not can_forget_player:
		# Calculates how long it will take for the enemy to forget the player
		can_forget_player = true
		GameState.set_data(data_name + "can_forget_player", can_forget_player)
		last_seen_player = GameState.enemy_remember_player_time
		last_seen_player += randf() * GameState.enemy_remember_player_time_random
		GameState.set_data(data_name + "last_seen_player", last_seen_player)
		task.succeed()
	
	elif last_seen_player <= 0.0:
		task.failed()
	
	else:
		task.succeed()

# Moves twords the last point the player was seen at
func task_ai_seek_player_last_pos(task):
# warning-ignore:return_value_discarded
	_ai_move_to(player_last_known_position)
	_ai_look_twords_movement()
	
	task.succeed()

# Determin if the enemy should look twords where it was hit from
var seek_hit_source := false
var seek_set_timer := true
func task_condition_ai_seek_hit_source(task):
	if seek_hit_source:
		# Sets how long the enemy will look for
		if seek_set_timer:
			seek_set_timer = false
			new_look_timer = look_timer_set_hit
			new_look_timer += randf() * look_timer_rand_hit
			
		task.succeed()
	
	else:
		task.failed()

# Looks twords where the enemy was hit from
var hit_source := Vector3.ZERO
func task_ai_seek_hit_source(task):
	look_at_pos = hit_source
	# Stop moving
	_ai_reset_movement()
	if new_look_timer <= 0.0:
		seek_set_timer = true
		seek_hit_source = false
		task.failed()
	else:
		task.succeed()

# Determin if the enemy should look for the gunshot source
var seek_weapon_start := false
func task_condition_ai_seek_weapon_source(task):
	if seeking_health:
		task.failed()
	else:
		if heard_new_gunshot:
			# Handles some variables used to comunicate with other parts of the
			# AI
			heard_new_gunshot = false
			heard_gunshot = true
			seek_weapon_start = true
			GameState.set_data(data_name + "heard_new_gunshot", heard_new_gunshot)
			GameState.set_data(data_name + "heard_gunshot", heard_gunshot)
			GameState.set_data(data_name + "seek_weapon_start", seek_weapon_start)
	
		if heard_gunshot:
			task.succeed()
		else:
			task.failed()
			seek_weapon_start = true
			GameState.set_data(data_name + "seek_weapon_start", seek_weapon_start)

# Look for the gunshot source
func task_ai_seek_weapon_source(task):
	# Reset patrol
	patrol_path = []
	
	if seek_weapon_start:
		if _ai_move_to(gunshot_location_guess):
			# Setup look timer
			seek_weapon_start = false
			GameState.set_data(data_name + "seek_weapon_start", seek_weapon_start)
			
			last_look_point = Vector3.ZERO
			GameState.set_vec3(data_name + "last_look_point", last_look_point)
		
			gunshot_can_look = false
			GameState.set_data(data_name + "gunshot_can_look", gunshot_can_look)
			gunshot_timer = look_for_gunshot_time
			gunshot_timer += randf() * look_for_gunshot_time_random
			GameState.set_data(data_name + "gunshot_timer", gunshot_timer)
	
	else:
		_ai_look_twords_movement()
	
	if gunshot_timer <= 0.0:
		# The enemy should move on from looking for gunshot source
		heard_gunshot = false
		GameState.set_data(data_name + "heard_gunshot", heard_gunshot)
	
	
	elif not _ai_is_moving() and new_look_timer <= 0.0:
		# The enemy is where it thought the gunshot came from, so look around
		gunshot_can_look = true
		GameState.set_data(data_name + "gunshot_can_look", gunshot_can_look)
		
		_ai_look_randomly()
		
	task.succeed()

# Determin if the enemy should patrol
func task_condition_ai_patrol(task):
	if seeking_health:
		task.failed()
	else:
		# Find the closest navigation node
		var nav_patrol_path : NavigationNode
		nav_patrol_path = _ai_find_nearest_navigation(get_node(navigation_nodes_path), NavigationNode.Type.NONE)
	
		if nav_patrol_path == null:
			task.failed()
	
		else:
			task.succeed()

var patrol_load_tick := true
var patrol_path := []
var patrol_type : int = NavigationNode.Type.NONE
var patrol_current := 0
var patrol_reverse := false
# Move along patrol and look around
func task_ai_patrol(task):
	# The patrol path is not currently set up
	if len(patrol_path) == 0:
		patrol_wait_time = 0.0
		patrol_can_wait = true
		GameState.set_data(data_name + "patrol_wait_time", patrol_wait_time)
		
		# Get the patrol information from the first navigation node
		patrol_type = NavigationNode.Type.NONE
		patrol_path = _ai_find_all_navigation(get_node(patrol_nodes_path), NavigationNode.Type.PATROL)
		if len(patrol_path) != 0:
			# Get information about PATROL node
			if patrol_path[0].start_reversed:
				patrol_reverse = true
				GameState.set_data(data_name + "patrol_reverse", patrol_reverse)
				patrol_current = len(patrol_path) - 1
		else:
			# Get information about PATROL_AREA node
			patrol_path = _ai_find_all_navigation(get_node(patrol_nodes_path), NavigationNode.Type.PATROL_AREA)
			if len(patrol_path) == 0:
				task.failed()
				return
			
			patrol_current = Utils.modi(randi(), len(patrol_path))
		
		# Because of how much code that needs to be ran everytime the patrol
		# resets, it's more practical to initialize the patrol here
		if patrol_load_tick:
			patrol_load_tick = false
			patrol_type = GameState.get_data(data_name + "patrol_type", patrol_type)
			patrol_current = GameState.get_data(data_name + "patrol_current", patrol_current)
			
	
		GameState.set_data(data_name + "patrol_type", patrol_type)
		GameState.set_data(data_name + "patrol_current", patrol_current)
	
	else:
		if _ai_is_moving():
			# Update last look pos
			last_look_point = global_transform.origin + velocity
			last_look_point.y = 0
			GameState.set_vec3(data_name + "last_look_point", last_look_point)
		
		elif new_look_timer <= 0.0:
			# Look randomly
			_ai_look_randomly()
		
		if patrol_type == NavigationNode.Type.NONE:
			# Set the patrol type to the type of the first navigation node
			patrol_type = patrol_path[0].type
			GameState.set_data(data_name + "patrol_type", patrol_type)
		
		if patrol_type == NavigationNode.Type.PATROL:
			# Check to see if we are at the begining or the end of the patrol
			if (patrol_current == -1) or (patrol_current == len(patrol_path)):
				# Check to see if the patrol is a loot
				if not patrol_path[0].is_loop:
					# Go back to the previous node
					patrol_reverse = not patrol_reverse
					GameState.set_data(data_name + "patrol_reverse", patrol_reverse)
				
					if patrol_reverse:
						patrol_current -= 2
				
					else:
						patrol_current += 2
				
				else:
					if patrol_path[0].start_reversed:
						# Go to the end
						patrol_current = len(patrol_path) - 1
					
					else:
						# Go to the start
						patrol_current = 0
					
				GameState.set_data(data_name + "patrol_current", patrol_current)
			
			# Get the next node
			var next_node : NavigationNode = patrol_path[patrol_current]
			var next_pos := next_node.global_transform.origin
			next_pos.y = global_transform.origin.y
			var next_distance := next_pos.distance_squared_to(global_transform.origin)
			var check_distance := pow(next_node.radius + navigation_node_size, 2.0)
			# See if the enemy are close enough to the node
			if next_distance <= check_distance:
				# The enemy is close enought to the node so the enemy will wait
				# there for a bit
				if patrol_wait_time > 0.0:
					if not _ai_is_moving():
						patrol_can_wait = true
						GameState.set_data(data_name + "patrol_can_wait", patrol_can_wait)
				
				else:
					# Set the current patrol to the next one
					if patrol_reverse:
						patrol_current -= 1
					
					else:
						patrol_current += 1
					
					GameState.set_data(data_name + "patrol_current", patrol_current)
			
			elif patrol_wait_time <= 0.0:
				# Move twords the navigation node
				var patrol_next := next_node.get_random_point()
				if _ai_move_to(patrol_next):
					# Set wait timer
					patrol_wait_time = next_node.wait_time
					patrol_wait_time += randf() * next_node.wait_time_random
					GameState.set_data(data_name + "patrol_wait_time", patrol_wait_time)
					patrol_can_wait = false
					GameState.set_data(data_name + "patrol_can_wait", patrol_can_wait)
		
		elif patrol_type == NavigationNode.Type.PATROL_AREA:
			# The enemy will randomly look while it's not moving for a bit, then
			# it will chose a new destination
			if patrol_wait_time > 0.0:
				# Get the next patrol node
				var next_node : NavigationNode = patrol_path[patrol_current]
				var next_pos := next_node.global_transform.origin
				next_pos.y = global_transform.origin.y
				var next_distance := next_pos.distance_squared_to(global_transform.origin)
				var check_distance := pow(next_node.radius + navigation_node_size, 2.0)
				
				if (new_look_timer <= 0.0) and (not _ai_is_moving()):
					_ai_look_randomly()
				
				if next_distance <= check_distance:
					if not _ai_is_moving():
						# Start waiting
						patrol_can_wait = true
						GameState.set_data(data_name + "patrol_can_wait", patrol_can_wait)
					
	if _ai_is_moving():
		_ai_look_twords_movement()
	
	task.succeed()

# Reloads the enemy's gun
func task_ai_reload(task):
	_ai_reload()
	task.succeed()

# Fires the enemy's gun
func task_ai_fire(task):
	# Get the direction of the player and the bullet ray cast
	var dir = global_transform.origin.direction_to(player.global_transform.origin)
	var bullet_direction := global_transform.origin - to_global($CamHing/BulletCast.cast_to)
	bullet_direction = -bullet_direction.normalized()
	
	# Check to see if the enemy's gun is aligned enough to shoot and shoot
	if (dir.dot(bullet_direction) >= GameState.enemy_fire_within_dot) and _ai_fire():
		# See if the bullet ray cast's collider can take damage
		var hit := _ai_bullet_cast()
		if hit and hit.has_method("take_health"):
			# Apply damage to the collider
			var damage := GameState.enemy_damage
			var rand_damage := Utils.modi(randi(), GameState.enemy_damage_rand)
			print(rand_damage)
			print(GameState.enemy_damage_rand)
			damage += rand_damage
			hit.take_health(damage)
			
	task.succeed()

# This is the idle task, which results in the AI's BTree root always succeed
func task_ai_idle(task):
	task.succeed()
	
# Determin if the enemy should seek out health packs
func task_condition_ai_seek_health(task):
	# Calculate at what health the enemy should start seeking health at
	var seek_health_at : int = int(max_health * GameState.enemy_seeks_health_at)
	var healths := _ai_find_all_nodes(get_node(health_nodes_path), typeof(HealthConsole))
	
	# Check to see if the enemy needs more health and if there are health packs
	# available
	if ((health > seek_health_at) or (len(healths) == 0)) and (health >= target_health):
		# The enemy won't/can't seek health packs
		target_health = 0
		GameState.set_data(data_name + "target_health", target_health)
		seeking_health = false
		task.failed()
	
	else:
		# The enemy will seek health packs
		target_health = max_health
		GameState.set_data(data_name + "target_health", target_health)
		seeking_health = true
		task.succeed()

# Seeks out the nearest health pack with health
func task_ai_seek_health(task):
	# Reset patrol
	patrol_path = []
	
	# Get all the health packs
	var healths := _ai_find_all_nodes(get_node(health_nodes_path), typeof(HealthConsole))
	var closest_health : HealthConsole = null
	var closest_distance := 0.0
	
	for _health in healths:
		var health_node : HealthConsole = _health
		
		# See if the pack has health
		if health_node.current_health <= 0:
			continue
		
		# Check to see if the health pack is closer then the one found so far
		var distance := global_transform.origin.distance_squared_to(health_node.global_transform.origin)
		if (distance < closest_distance) or (closest_health == null):
			closest_health = health_node
			closest_distance = distance
			
	if closest_health != null:
		# Gets a point just in front of the health pack and move there
		var health_spot := closest_health.global_transform.origin
		health_spot += -closest_health.transform.basis.z * 0.1
		
# warning-ignore:return_value_discarded
		_ai_move_to(health_spot)
		
		if len(paths) != 0:
			task.succeed()
			return
	
	task.failed()

# Processes the movement path and outputs a movement vector
func _process_ai_movement(_delta) -> Vector3:
	var movement := Vector3.ZERO
	# No movement if the path is empty
	if len(paths) != 0:
		var next : Vector3 = paths[0]
		var size := pow(navigation_node_size, 2.0)
		# Check to see if we are close enough to a path's point to remove it
		# from the path
		while next.distance_squared_to(global_transform.origin) <= size:
			paths.remove(0)
			#paths.pop_front() crashes the release build for some reason
				
			if len(paths) == 0:
				return Vector3.ZERO
			
			next = paths[0]
		
		movement = next - global_transform.origin
		
	movement.y = 0
	return movement

# This is called when something gives the enemy health
func give_health(amount : int) -> int:
	if health <= 0:
		return 0
	
	# Take health until we are at the max health
	var needed = max_health - health
	var given = min(needed, amount)
	health += given
	
	GameState.set_data(data_name + "health", health)
	
	return given

# This is called when something does damage to the player
func take_health(amount : int, position : Vector3):
	# Remove health until we are at 0 health
	health -= amount
	
	GameState.set_data(data_name + "health", health)
	
	_check_health()
	seek_hit_source = true
	hit_source = position

# Check the enemy health to see if the enemy is dead
func _check_health():
	if health <= 0:
		# The enemy is dead
		
		# Hide the enemy, disable the AI, and show the ragdoll
		$VisibleShapes.visible = false
		$CollisionShape.visible = false
		$CamHing.visible = false
		$EyeCast.visible = false
		$BTREE.enable = false
		
		$EnemyRagdoll.visible = true
		
		# Create a random angle to use when applying a random force to the
		# ragdoll
		var angle = rand_range(-1.0, 1.0)
		
		for _child in $EnemyRagdoll.get_children():
			var child : RigidBody = _child
			
			# Apply the current velocity to the ragdoll
			child.linear_velocity = velocity.normalized()
			child.linear_velocity.y = 0
			
			if child.linear_velocity.length() <= 0.001:
				# Adds a random force if the ragdoll is not moving
				child.linear_velocity.x = cos(angle)
				child.linear_velocity.z = sin(angle)
				
			child.sleeping = false
		
		# Disable the collision on the enemy
		collision_mask &= ~1
		collision_layer = 0
		
		# Notify the ragdoll to start
		$EnemyRagdoll.start_ragdoll()
