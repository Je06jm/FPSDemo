extends KinematicBody

export var max_speed := 300.0
export var acceleration := 1600.0
export var air_acceleration := 500.0
export var deceleration := 20.0
export var jump := 250.0

export var max_look_speed := 10.0
export var max_look_speed_standing := 20.0

export var max_ammo_per_clip := 50
export var max_health := 50
export var max_fire_range := 30.0
export var flee_ammo_amount := 10
export var min_seek_player_distance := 2.0
export var max_seek_player_distance := 7.0

export var look_for_gunshot_time := 5.0
export var look_for_gunshot_time_random := 1.0

export var can_see_player := true

export var navigation_path : NodePath
export var player_path : NodePath
export var navigation_nodes_path : NodePath
export var patrol_nodes_path : NodePath
export var health_nodes_path : NodePath

export var navigation_node_size := 1.0

export var stop_processing_ragdoll_distance := 30.0

var velocity := Vector3.ZERO
var on_floor_last_tick := true

var is_firing := false
var is_reloading := false

var look_at_pos := Vector3.ZERO
var last_look_point := translation

var last_seen_player := 0.0
var can_forget_player := false 

var patrol_wait_time := 0.0
var patrol_can_wait := false

var heard_gunshot := false
var heard_new_gunshot := false
var gunshot_location_guess := Vector3.ZERO

onready var ammo := max_ammo_per_clip
onready var health = max_health

var target_health := 0

var paths := []

onready var navigation : Navigation = get_node(navigation_path)
onready var player : Spatial = get_node(player_path)
onready var hide_distance := pow(stop_processing_ragdoll_distance, 2.0)

const look_timer_set := 0.1
const look_timer_rand := 0.35
var new_look_timer := 0.0
var look_sphere := Vector3.ZERO

const move_timer_set := 0.1
const move_timer_rand := 0.15
var new_move_timer := 0.0

var gunshot_timer := 0.0
var gunshot_can_look := false

var player_last_known_position := Vector3.ZERO

onready var data_name = GameState.get_unique_id(self)

func _ready():
	$CamHing/BulletCast.cast_to *= max_fire_range
	
	translation = GameState.get_vec3(data_name + "translation", translation)
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
	
	var last_move_to = GameState.get_vec3(data_name + "last_move_to", translation)
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

func _process(delta):
	if health > 0:
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
		
		is_firing = $AnimationTree["parameters/FireOneShot/active"]
		is_reloading = $AnimationTree["parameters/ReloadOneShot/active"]
	
		$CamHing/AttachmentPoint/FlashLight.visible = false
	
		var movement := _process_ai_movement(delta)
		var xzMovement := Vector2(movement.x, movement.z)
	
		xzMovement = xzMovement.normalized()
	
		movement.x = xzMovement.x
		movement.z = xzMovement.y
	
		if movement.length_squared() >= 0.01:
			if is_on_floor():
				velocity.x += movement.x * (acceleration * delta)
				velocity.z += movement.z * (acceleration * delta)
				velocity.y += movement.y
			else:
				velocity.x += movement.x * (air_acceleration * delta)
				velocity.z += movement.z * (air_acceleration * delta)
				velocity.y += movement.y
	
		else:
			var force : Vector2 = Vector2(velocity.x, velocity.z)
			force *= deceleration * delta
			velocity.x -= force.x
			velocity.z -= force.y

		var movement_speed := Vector2(velocity.x, velocity.z)
		if movement_speed.length() > max_speed:
			movement_speed = movement_speed.normalized() * max_speed
	
		velocity.x = movement_speed.x
		velocity.z = movement_speed.y
	
		if movement.y <= 0.0:
			velocity.y += GameState.gravity * delta

		var idle_walk : float = movement.length() * 2.0 - 1.0
		$AnimationTree.set("parameters/Movement/Idle-Walk/blend_position", idle_walk)

		if is_on_floor() and not on_floor_last_tick:
			$AnimationTree["parameters/Movement/playback"].start("JumpEnd")

		elif not is_on_floor():
			$AnimationTree["parameters/Movement/playback"].travel("Air")

		on_floor_last_tick = is_on_floor()
	else:
		var distance := player.translation.distance_squared_to(translation)
		if distance >= hide_distance:
			visible = false
		else:
			visible = true

func _physics_process(delta):
	if health > 0:
		var new_velocity : Vector3
		new_velocity = move_and_slide(velocity * delta, Vector3.UP, true) / delta
	
		if abs(velocity.y - new_velocity.y) >= 0.2:
			new_velocity.y -= 2.0
	
		velocity = new_velocity
		GameState.set_vec3(data_name + "translation", translation)
		GameState.set_vec3(data_name + "velocity", velocity)

func _ai_reload():
	$AnimationTree["parameters/ReloadOneShot/active"] = true
	ammo = max_ammo_per_clip
	GameState.set_data(data_name + "ammo", ammo)

func _ai_fire() -> bool:
	if not is_firing and not is_reloading and ammo != 0:
		$AnimationTree["parameters/FireOneShot/active"] = true
		$CamHing/AttachmentPoint/FlashParticles.emitting = true
		$CamHing/AttachmentPoint/FlashLight.visible = true
		ammo -= 1
		GameState.set_data(data_name + "ammo", ammo)
		return true
	
	return false

func _ai_look_at(world_pos : Vector3, delta : float):
	var xzPlane := Vector3(world_pos.x, translation.y, world_pos.z)
	var plane := Vector2(xzPlane.x, xzPlane.z)
	var current := Vector2(translation.x, translation.z)
	
	var angle := Vector2.ZERO
	
	angle.x = -current.angle_to_point(plane) + PI/2
	if angle.x > PI:
		angle.x -= 2*PI
	
	var base0 : float = xzPlane.distance_to(translation)
	var base1 : float = world_pos.y - translation.y
	
	if abs(base0) != 0.0:
		angle.y = atan(base1 / base0)
	
	var current_angle := Vector2(rotation.y, $CamHing.rotation.x)
	var delta_angle := angle - current_angle
	
	if abs(delta_angle.x) > abs(delta_angle.x - 2*PI):
		delta_angle.x = delta_angle.x - 2*PI
	
	elif abs(delta_angle.x) > abs(delta_angle.x + 2*PI):
		delta_angle.x = delta_angle.x + 2*PI
	
	var look_speed := 0.0
	
	var speed := Vector2(velocity.x, velocity.z).length_squared()
	var percent := speed / pow(max_speed, 2.0)
	
	look_speed = max_look_speed * percent + max_look_speed_standing * (1.0 - percent)
	
	look_speed = deg2rad(look_speed) * delta
	if delta_angle.length() > look_speed:
		delta_angle = delta_angle.normalized() * look_speed
	
	rotation.y += delta_angle.x
	$CamHing.rotation.x += delta_angle.y
	
	var look_rotation := Vector2($CamHing.rotation.x, rotation.y)
	GameState.set_vec2(data_name + "look_rotation", look_rotation)

func _ai_move_to(pos : Vector3):
	pos = navigation.get_closest_point(pos)
	paths = navigation.get_simple_path(translation, pos)
	GameState.set_vec3(data_name + "last_move_to", pos)

func _ai_reset_movement():
	paths = []
	GameState.set_data(data_name + "paths_count", 0)

func _ai_is_moving() -> bool:
	return len(paths) != 0

func _ai_look_randomly():
	new_look_timer = GameState.enemy_look_time
	new_look_timer += randf() * GameState.enemy_look_time_random
	GameState.set_data(data_name + "new_look_timer", new_look_timer)
	
	var rand_sphere := Vector3.ZERO
	var angle = randf() * 2 * PI
	rand_sphere.x = cos(angle)
	rand_sphere.z = sin(angle)
	
	var look_diff = GameState.enemy_look_max_height_angle
	look_diff -= GameState.enemy_look_min_height_angle
	
	angle = randf() * look_diff
	angle -= GameState.enemy_look_min_height_angle
	
	rand_sphere.y = sin(angle)
	
	rand_sphere = rand_sphere.normalized()
	var new_point = last_look_point + rand_sphere
	look_at_pos = last_look_point + rand_sphere
	GameState.set_vec3(data_name + "look_at_pos", look_at_pos)
	
	last_look_point = to_local(new_point)
	last_look_point = last_look_point.normalized()
	
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

func _ai_look_twords_movement():
	if len(paths) != 0:
		var next : Vector3 = velocity
		
		next.y = 0
		next = next.normalized()
		
		var diff = get_floor_normal() - Vector3.UP
		
		var looking := Vector2(next.x, next.z)
		var diff_plane := Vector2(diff.x, diff.z)
		
		looking = looking.normalized()
		diff_plane = diff_plane.normalized()
		
		next.y = diff.y * diff_plane.dot(looking) * 2.0
		
		next = translation + next
		
		look_at_pos = next
		GameState.set_vec3(data_name + "look_at_pos", look_at_pos)

func _ai_eye_cast(pos : Vector3) -> Spatial:
	$EyeCast.cast_to = to_local(pos)
	return $EyeCast.get_collider()

func _ai_bullet_cast() -> Spatial:
	return $CamHing/BulletCast.get_collider()

func _ai_find_all_nodes(root_node : Spatial, type : int, exclude := []) -> Array:
	var nodes := []
	
	if root_node:
		for _child in root_node.get_children():
			if exclude.find(_child) != -1:
				continue
		
			elif not (typeof(_child) == type):
				continue
		
			nodes += [_child]
	
	return nodes

func _ai_find_nearest_node(root_node : Spatial, type : int, exclude := []) -> Spatial:
	var nearest_node : Spatial = null
	var nearest_distance := 0.0
	
	var nodes := _ai_find_all_nodes(root_node, type, exclude)
	
	for _child in nodes:
		if not (_child is Spatial):
			continue
		
		var child : Spatial = _child
		var distance := child.translation.distance_squared_to(translation)
		
		if (distance < nearest_distance) or (nearest_node == null):
			nearest_node = child
			nearest_distance = distance
	
	return nearest_node

func _ai_find_all_navigation(root_node : Spatial, type : int, exclude := []) -> Array:
	var nodes := []
	
	if root_node:
		for _child in root_node.get_children():
			if exclude.find(_child) != -1:
				continue
		
			elif not (_child is NavigationNode):
				continue
			
			var child : NavigationNode = _child
		
			if not (child.type == type) and (type != NavigationNode.Type.NONE):
				continue
			
			nodes += [child]
	
	return nodes

func _ai_find_nearest_navigation(root_node : Spatial, type : int, exclude := []) -> NavigationNode:
	var nearest_node : NavigationNode = null
	var nearest_distance := 0.0
	
	var nodes := _ai_find_all_navigation(root_node, type, exclude)
	
	for child in nodes:
		var distance : float = child.translation.distance_squared_to(translation)
		
		if (distance < nearest_distance) or (nearest_node == null):
			nearest_node = child
			nearest_distance = distance
	
	return nearest_node

func _signal_on_fire():
	var gunshot_distance := player.translation.distance_squared_to(translation)
	if gunshot_distance <= pow(GameState.enemy_gunshot_hear_distance, 2.0):
		heard_new_gunshot = true
		GameState.set_data(data_name + "heard_new_gunshot", heard_new_gunshot)
		
		var guess := Vector3.ZERO
		var angle := randf() * 2 * PI
		guess.x = cos(angle)
		guess.y = sin(angle)
		angle = randf() * 2 * PI
		guess.z = sin(angle)
		
		guess *= randf() * GameState.enemy_gunshot_guess_distance
		
		gunshot_location_guess = player.translation + guess
		GameState.set_vec3(data_name + "gunshot_location_guess", gunshot_location_guess)

func task_condition_ai_seek_cover(task):
	if navigation_nodes_path == "":
		task.failed()
		return
		
	if ammo <= flee_ammo_amount or is_reloading:
		task.succeed()
	else:
		task.failed()

func task_ai_seek_cover(task):
	var cover : NavigationNode
	cover = _ai_find_nearest_navigation(get_node(navigation_nodes_path), NavigationNode.Type.COVER)
	if cover:
		_ai_move_to(cover.get_point_away_from(player.translation))
		_ai_look_twords_movement()
		task.succeed()
	
	else:
		task.failed()

func task_condition_ai_seek_player(task):
	if not can_see_player:
		task.failed()
		return
	
	var player_direction := translation.direction_to(player.translation)
	var forward := -transform.basis.z
	
	if forward.dot(player_direction) < GameState.enemy_see_player_dot:
		task.failed()
		return
	var player_distance := translation.distance_squared_to(player.translation)
	
	if player_distance > pow(GameState.enemy_see_player_distance, 2.0):
		task.failed()
		return
		
	var angle = asin(player_direction.y)
	if abs(angle) > GameState.enemy_see_player_virticaly:
		task.failed()
		return
	
	var eye_cast := _ai_eye_cast(player.translation)
	
	if eye_cast != player:
		task.failed()
	
	else:
		task.succeed()

func task_ai_seek_player(task):
	patrol_path = []
	
	var player_distance := translation.distance_to(player.translation)
	var farther_than_max := player_distance > max_seek_player_distance
	var closer_than_min := player_distance < min_seek_player_distance
	var out_of_bounds := farther_than_max or closer_than_min
	
	if out_of_bounds:
		var new_point := Vector3.ZERO
		var angle := randf() * (2 * PI)
		new_point.x = cos(angle)
		new_point.z = sin(angle)
		var distance := randf()
		distance *= max_seek_player_distance - min_seek_player_distance
		distance += min_seek_player_distance
			
		new_point *= distance
				
		var move_point := new_point + player.translation
				
		var direction_to_player = translation - player.translation
			
		if direction_to_player.dot(move_point) > 0.0:
			move_point = -new_point + player.translation
			
		_ai_move_to(new_point)
			
		new_move_timer = move_timer_set + randf() * move_timer_rand
		GameState.set_data(data_name + "new_move_timer", new_move_timer)
		
	elif new_move_timer <= 0.0:
		var new_point := Vector3.ZERO
		var angle := randf() * (2 * PI)
		new_point.x = cos(angle)
		new_point.z = sin(angle)
		var distance := randf() * GameState.enemy_move_rand_distance
			
		new_point *= distance
		new_point += translation
			
		_ai_move_to(new_point)
			
		new_move_timer = move_timer_set + randf() * move_timer_rand
		GameState.set_data(data_name + "new_move_timer", new_move_timer)
		
	if new_look_timer <= 0.0:
		new_look_timer = look_timer_set + randf() * look_timer_rand
		GameState.set_data(data_name + "new_look_timer", new_look_timer)
			
		look_sphere.x = rand_range(-1.0, 1.0)
		look_sphere.y = rand_range(-1.0, 1.0)
		look_sphere.z = rand_range(-1.0, 1.0)
		look_sphere = look_sphere.normalized()
		look_sphere *= GameState.enemy_look_random_sphere_size
		GameState.set_vec3(data_name + "look_sphere", look_sphere)
		
		look_at_pos = player.translation + look_sphere
		GameState.set_vec3(data_name + "look_at_pos", look_at_pos)
	
	player_last_known_position = player.translation
	can_forget_player = false
	GameState.set_data(data_name + "player_last_known_position", player_last_known_position)
	GameState.set_data(data_name + "can_forget_player", can_forget_player)
	
	task.succeed()

func task_condition_ai_seek_player_last_pos(task):
	if not can_see_player:
		task.failed()
		return
	
	if not can_forget_player:
		can_forget_player = true
		GameState.set_data(data_name + "can_forget_player", can_forget_player)
		last_seen_player = GameState.enemy_remember_player_time
		last_seen_player += randf() * GameState.enemy_remember_player_time_random
		GameState.set_data(data_name + "last_seen_player", last_seen_player)
	
	elif last_seen_player <= 0.0:
		task.failed()
	
	else:
		task.succeed()

func task_ai_seek_player_last_pos(task):
	_ai_move_to(player_last_known_position)
	
	task.succeed()

func task_condition_ai_seek_health(task):
	if health_nodes_path == "":
		task.failed()
		return
		
	var seek_health_at : int = int(max_health * GameState.enemy_seeks_health_at)
	var healths := _ai_find_all_nodes(get_node(health_nodes_path), typeof(HealthConsole))
	if ((health > seek_health_at) or (len(healths) == 0)) and (health >= target_health):
		target_health = 0
		GameState.set_data(data_name + "target_health", target_health)
		task.failed()
	
	else:
		target_health = max_health
		GameState.set_data(data_name + "target_health", target_health)
		task.succeed()

func task_ai_seek_health(task):
	# Reset patrol
	patrol_path = []
	
	var healths := _ai_find_all_nodes(get_node(health_nodes_path), typeof(HealthConsole))
	var closest_health : HealthConsole = null
	var closest_distance := 0.0
	
	for _health in healths:
		var health_node : HealthConsole = _health
		
		if health_node.current_health <= 0:
			continue
		
		var distance := translation.distance_squared_to(health_node.translation)
		if (distance < closest_distance) or (closest_health == null):
			closest_health = health_node
			closest_distance = distance
			
	if closest_health != null:
		_ai_look_twords_movement()
		
		var health_spot := closest_health.translation
		health_spot += -closest_health.transform.basis.z * 0.1
		
		_ai_move_to(health_spot)
		
		if len(paths) != 0:
			task.succeed()
			return
	
	task.failed()

var seek_weapon_start := false
func task_condition_ai_seek_weapon_source(task):
	if heard_new_gunshot:
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

func task_ai_seek_weapon_source(task):
	# Reset patrol
	patrol_path = []
	
	if seek_weapon_start:
		seek_weapon_start = false
		GameState.set_data(data_name + "seek_weapon_start", seek_weapon_start)
		
		_ai_move_to(gunshot_location_guess)
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
		heard_gunshot = false
		GameState.set_data(data_name + "heard_gunshot", heard_gunshot)
	
	elif not _ai_is_moving() and new_look_timer <= 0.0:
		gunshot_can_look = true
		GameState.set_data(data_name + "gunshot_can_look", gunshot_can_look)
		
		_ai_look_randomly()
		
	task.succeed()

func task_condition_ai_patrol(task):
	if patrol_nodes_path == "":
		task.failed()
		return
		
	var nav_patrol_path : NavigationNode
	nav_patrol_path = _ai_find_nearest_navigation(get_node(patrol_nodes_path), NavigationNode.Type.NONE)
	
	if nav_patrol_path == null:
		task.failed()
	
	else:
		task.succeed()

var patrol_load_tick := true
var patrol_path := []
var patrol_type : int = NavigationNode.Type.NONE
var patrol_current := 0
var patrol_reverse := false
func task_ai_patrol(task):
	if len(patrol_path) == 0:
		patrol_wait_time = 0.0
		GameState.set_data(data_name + "patrol_wait_time", patrol_wait_time)
		
		patrol_type = NavigationNode.Type.NONE
		patrol_path = _ai_find_all_navigation(get_node(patrol_nodes_path), NavigationNode.Type.PATROL)
		if len(patrol_path) != 0:
			if patrol_path[0].start_reversed:
				patrol_reverse = true
				GameState.set_data(data_name + "patrol_reverse", patrol_reverse)
				patrol_current = len(patrol_path) - 1
		else:
			patrol_path = _ai_find_all_navigation(get_node(patrol_nodes_path), NavigationNode.Type.PATROL_AREA)
			if len(patrol_path) == 0:
				task.failed()
				return
				
			patrol_current = randi() % len(patrol_path)
	
		if patrol_load_tick:
			patrol_load_tick = false
			patrol_type = GameState.get_data(data_name + "patrol_type", patrol_type)
			patrol_current = GameState.get_data(data_name + "patrol_current", patrol_current)
			
	
		GameState.set_data(data_name + "patrol_type", patrol_type)
		GameState.set_data(data_name + "patrol_current", patrol_current)
	
	else:
		_ai_look_twords_movement()
		
		if _ai_is_moving():
			last_look_point = translation + velocity
			last_look_point.y = 0
			GameState.set_vec3(data_name + "last_look_point", last_look_point)
		
		elif new_look_timer <= 0.0:
			_ai_look_randomly()
		
		if patrol_type == NavigationNode.Type.NONE:
			patrol_type = patrol_path[0].type
			GameState.set_data(data_name + "patrol_type", patrol_type)
		
		if patrol_type == NavigationNode.Type.PATROL:
			if (patrol_current == -1) or (patrol_current == len(patrol_path)):
				if not patrol_path[0].is_loop:
					patrol_reverse = not patrol_reverse
					GameState.set_data(data_name + "patrol_reverse", patrol_reverse)
				
					if patrol_reverse:
						patrol_current -= 2
				
					else:
						patrol_current += 2
				
				else:
					if patrol_path[0].start_reversed:
						patrol_current = len(patrol_path) - 1
					
					else:
						patrol_current = 0
					
				GameState.set_data(data_name + "patrol_current", patrol_current)
			
			var next_node : NavigationNode = patrol_path[patrol_current]
			var next_pos := next_node.translation
			next_pos.y = translation.y
			var next_distance := next_pos.distance_squared_to(translation)
			var check_distance := pow(next_node.radius + navigation_node_size, 2.0)
			if next_distance <= check_distance:
				if patrol_wait_time > 0.0:
					if not _ai_is_moving():
						patrol_can_wait = true
						GameState.set_data(data_name + "patrol_can_wait", patrol_can_wait)
				
				else:
					if patrol_reverse:
						patrol_current -= 1
					
					else:
						patrol_current += 1
					
					GameState.set_data(data_name + "patrol_current", patrol_current)
			
			elif patrol_wait_time <= 0.0:
				var patrol_next := next_node.get_random_point()
				_ai_move_to(patrol_next)
				
				patrol_wait_time = next_node.wait_time
				patrol_wait_time += randf() * next_node.wait_time_random
				GameState.set_data(data_name + "patrol_wait_time", patrol_wait_time)
				patrol_can_wait = false
				GameState.set_data(data_name + "patrol_can_wait", patrol_can_wait)
		
		elif patrol_type == NavigationNode.Type.PATROL_AREA:
			if patrol_wait_time > 0.0:
				var next_node : NavigationNode = patrol_path[patrol_current]
				var next_pos := next_node.translation
				next_pos.y = translation.y
				var next_distance := next_pos.distance_squared_to(translation)
				var check_distance := pow(next_node.radius + navigation_node_size, 2.0)
				
				if _ai_is_moving():
					last_look_point = translation + velocity
					last_look_point.y = 0
					GameState.set_vec3(data_name + "last_look_point", last_look_point)
				elif new_look_timer <= 0.0:
					_ai_look_randomly()
				
				if next_distance <= check_distance:
					if not _ai_is_moving():
						patrol_can_wait = true
						GameState.set_data(data_name + "patrol_can_wait", patrol_can_wait)
	
			else:
				patrol_current = randi() % len(patrol_path)
				GameState.set_data(data_name + "patrol_current", patrol_current)
				var patrol_next : NavigationNode = patrol_path[patrol_current]
				_ai_move_to(patrol_next.get_random_point())
			
				patrol_wait_time = patrol_next.wait_time
				patrol_wait_time += randf() * patrol_next.wait_time_random
				GameState.set_data(data_name + "patrol_wait_time", patrol_wait_time)
				patrol_can_wait = false
				GameState.set_data(data_name + "patrol_can_wait", patrol_can_wait)
	
	task.succeed()


func task_ai_reload(task):
	_ai_reload()
	task.succeed()

func task_ai_fire(task):
	var dir = translation.direction_to(player.translation)
	var bullet_direction := translation - to_global($CamHing/BulletCast.cast_to)
	bullet_direction = -bullet_direction.normalized()
	
	if (dir.dot(bullet_direction) >= GameState.enemy_fire_within_dot) and _ai_fire():
		var hit := _ai_bullet_cast()
		if hit and hit.has_method("take_health"):
			var damage := GameState.enemy_damage
			damage += randi() % GameState.enemy_damage_rand
			hit.take_health(damage)
			
	task.succeed()

func _process_ai_movement(_delta) -> Vector3:
	var movement := Vector3.ZERO
	if len(paths) != 0:
		var next : Vector3 = paths[0]
		var size := pow(navigation_node_size, 2.0)
		
		while next.distance_squared_to(translation) <= size:
			paths.pop_front()
				
			
			if len(paths) == 0:
				return Vector3.ZERO
			
			next = paths[0]
			
		movement = next - translation
		
	movement.y = 0
	return movement

func give_health(amount : int) -> int:
	if health <= 0:
		return 0
	
	var needed = max_health - health
	var given = min(needed, amount)
	health += given
	
	GameState.set_data(data_name + "health", health)
	
	return given
	
func take_health(amount : int):
	health -= amount
	
	GameState.set_data(data_name + "health", health)
	
	_check_health()
		

func _check_health():
	if health <= 0:
		$VisibleShapes.visible = false
		$CollisionShape.visible = false
		$CamHing.visible = false
		$EyeCast.visible = false
		
		$EnemyRagdoll.visible = true
		
		var angle = rand_range(-1.0, 1.0)
		$BTREE.enable = false
		
		for _child in $EnemyRagdoll.get_children():
			var child : RigidBody = _child
			
			child.linear_velocity = velocity.normalized()
			child.linear_velocity.y = 0
			
			if child.linear_velocity.length() <= 0.001:
				child.linear_velocity.x = cos(angle)
				child.linear_velocity.z = sin(angle)
				
			child.sleeping = false
			
		collision_mask &= ~1
		collision_layer = 0
		$EnemyRagdoll.start_ragdoll()
