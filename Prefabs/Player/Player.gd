extends KinematicBody
signal on_fire

# Controls the player's movement and health

export var max_speed := 300.0
export var acceleration := 1600.0
export var air_acceleration := 500.0
export var deceleration := 20.0
export var air_deceleration := 0.1
export var jump := 250.0

export var joy_strength := 80.0
export var mouse_strength := 0.1

export var interact_max_distance := 5.0

export var max_ammo := 250
export var max_ammo_per_clip := 50
export var max_fire_range := 40.0

export var fall_damage_distance := 10.0
export var additional_fall_damage_distance := 0.75
export var fall_damage_amount := 5

export var show_hurt_effects_at := 20
export var show_hurt_effects_speed := 1.0

var look_mouse := Vector2.ZERO

var velocity := Vector3.ZERO
var movement := Vector3.ZERO

var look_rotation := Vector2.ZERO
var on_floor_last_tick := true
var on_floor_last_time := 0.0

const idle_walk_max_transition_time := 0.1
var last_idle_walk := 0.0

var is_firing := false
var is_reloading := false
var is_jumping := false

var last_place_on_ground := translation.y

var sway := Vector2.ZERO
const sway_speed := 1.0

var increase_hurt_alpha := true

onready var interact_max_distance_sqaured := pow(interact_max_distance, 2.0)

# Captures the mouse and sets up the initial player state
func _ready():
	$CamHing/BulletCast.cast_to *= max_fire_range
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.save_game()
	
	GameState.health = GameState.get_data("health", 100)
	GameState.clip_ammo = GameState.get_data("clip_ammo", max_ammo_per_clip)
	GameState.total_ammo = GameState.get_data("total_ammo", 50)
	look_rotation = GameState.get_vec2("look_rotation", look_rotation)
	
	velocity = GameState.get_vec3("velocity", velocity)
	translation = GameState.get_vec3("translation", translation)
	
	$UI/Game/Hurt.modulate.a = GameState.get_data("hurt_amount", $UI/Game/Hurt.modulate.a)
	
	_update_UI()
	
	$UI/Pause.set_process(true)

# Handles the mouse movement
func _input(event):
	if event is InputEventMouseMotion:
		look_mouse = event.relative * (GameState.mouse_sensitivity / 100.0)
		look_mouse = -look_mouse

# Handles the player's movement and input
func _process(delta):
	# Determin the state of the firing and reloading animations
	is_firing = $AnimationTree["parameters/FireOneShot/active"]
	is_reloading = $AnimationTree["parameters/ReloadOneShot/active"]
	
	# Calculate the look vector
	var look_joy := Vector2.ZERO
	
	look_joy.x -= Input.get_action_strength("joy_look_right")
	look_joy.x += Input.get_action_strength("joy_look_left")
	
	look_joy.y += Input.get_action_strength("joy_look_up")
	look_joy.y -= Input.get_action_strength("joy_look_down")
	
	var sensitivity := GameState.joy_sensitivity / 50.0
	# Apply joystick look
	look_rotation += look_joy * joy_strength * sensitivity * delta
	# Apply mouse look
	look_rotation += look_mouse * mouse_strength
	
	look_rotation.y = min(90.0, max(-90.0, look_rotation.y))
	
	# Calculate the movement vector
	
	movement = Vector3.ZERO
	
	movement -= transform.basis.z * Input.get_action_strength("game_up")
	movement += transform.basis.z * Input.get_action_strength("game_down")
	movement -= transform.basis.x * Input.get_action_strength("game_left")
	movement += transform.basis.x * Input.get_action_strength("game_right")
	
	# Clamp movement speed to one unit for now
	if movement.length() > 1.0:
		movement = movement.normalized()
	
	# Jump is the player is on the floor and play the jumping animation
	if Input.is_action_pressed("game_jump") and is_on_floor():
		movement.y = jump
		is_jumping = true
		$AnimationTree["parameters/Movement/playback"].start("JumpStart")
	
	elif is_on_floor():
		is_jumping = false
	
	var bullet_obj : Spatial = $CamHing/BulletCast.get_collider()
	
	# Handle the interact button being pressed
	if Input.is_action_just_pressed("game_interact") and bullet_obj:
		var distance = bullet_obj.translation.distance_squared_to(translation)
		# See if we are close enough to the object to interact and see if the
		# object is interactable
		if bullet_obj.has_method("interact") and (distance <= interact_max_distance_sqaured):
			bullet_obj.interact()
	
	# Reload if the reload button is pressed and we are not already reloading or
	# are firing. Play the reload animation
	if Input.is_action_just_pressed("game_reload") and not is_firing and not is_reloading:
		if (GameState.total_ammo != 0) and (GameState.clip_ammo != max_ammo_per_clip):
			$AnimationTree["parameters/ReloadOneShot/active"] = true
			is_reloading = true
		
			# Calculate the new clip ammo and total ammo
			var needed = max_ammo_per_clip - GameState.clip_ammo
			var taken = min(needed, GameState.total_ammo)
			GameState.total_ammo -= taken
			GameState.clip_ammo += taken
		
			GameState.set_data("total_ammo", GameState.total_ammo)
			GameState.set_data("clip_ammo", GameState.clip_ammo)
		
			_update_UI()
	
	# Setting the FlashLight visibility to false now allows it to be visible for
	# a single frame
	$CamHing/AttachmentPoint/FlashLight.visible = false
	# Fires if the fire button is pressed and we are not already reloading or
	# are firing. Play the fire animation
	if Input.is_action_pressed("game_fire") and not is_firing and not is_reloading:
		# Also don't fire if the clip ammo is zero
		if GameState.clip_ammo != 0:
			# Play fire animation, show particles, and enable FlashLight
			$AnimationTree["parameters/FireOneShot/active"] = true
			$CamHing/AttachmentPoint/FlashParticles.emitting = true
			$CamHing/AttachmentPoint/FlashLight.visible = true
			is_firing = true
			GameState.clip_ammo -= 1
			
			# Check the bullet ray cast. If the collider can receive damage,
			# apply damage to the collider
			if bullet_obj and bullet_obj.has_method("take_health"):
				var damage := GameState.player_damage
				damage += Utils.modi(randi(), GameState.player_damage_rand)
				bullet_obj.call("take_health", damage, translation)
			
			emit_signal("on_fire")
			
			GameState.set_data("clip_ammo", GameState.clip_ammo)
			
			_update_UI()
	
	# Apply movement force to velocity
	if movement.length_squared() >= 0.01:
		if is_on_floor():
			# Use the ground acceleration to apply movement
			velocity.x += movement.x * (acceleration * delta)
			velocity.z += movement.z * (acceleration * delta)
			velocity.y += movement.y
		else:
			# Use the air acceleration to apply movement
			velocity.x += movement.x * (air_acceleration * delta)
			velocity.z += movement.z * (air_acceleration * delta)
			velocity.y += movement.y
	
	# Apply friction force to velocity
	else:
		var force : Vector2 = Vector2(velocity.x, velocity.z)
		if is_on_floor():
			# Use ground friction to apply friction
			force *= deceleration * delta
		else:
			# Use air friction to apply friction
			force *= air_deceleration * delta
		velocity.x -= force.x
		velocity.z -= force.y

	# Clamp the velocity to the max speed
	var movement_speed := Vector2(velocity.x, velocity.z)
	if movement_speed.length() > max_speed:
		movement_speed = movement_speed.normalized() * max_speed
	
	velocity.x = movement_speed.x
	velocity.z = movement_speed.y
	
	# Apply gravity if we didn't just jump
	if movement.y <= 0.0:
		velocity.y += GameState.gravity * delta

	# Use movement speed to determing how much to blend between the idle and
	# walking animations
	var target_idle_walk : float = movement.length() * 2.0 - 1.0
	var idle_walk = $AnimationTree.get("parameters/Movement/Idle-Walk/blend_position")
	var delta_idle_walk = target_idle_walk - idle_walk
	var delta_transition_time = 2.0 / idle_walk_max_transition_time * delta
	
	if delta_idle_walk > delta_transition_time:
		delta_idle_walk = delta_transition_time
	
	elif -delta_idle_walk > delta_transition_time:
		delta_idle_walk = -delta_transition_time

	idle_walk += delta_idle_walk
	
	$AnimationTree.set("parameters/Movement/Idle-Walk/blend_position", idle_walk)

	# Play the landing animation if we just landed
	if is_on_floor() and not on_floor_last_tick and (on_floor_last_time >= 0.05):
		$AnimationTree["parameters/Movement/playback"].start("JumpEnd")

	# Play the in air animation if we are in the air
	elif not is_on_floor() and not on_floor_last_tick and (on_floor_last_time >= 0.05):
		$AnimationTree["parameters/Movement/playback"].travel("Air")
	
	# Use the change in look to determin how much to blend between each sway
	# animations
	var sway_delta := (look_joy - sway) + (look_mouse - sway)
	if sway_delta.length() > sway_speed:
		sway_delta = sway_delta.normalized() * sway_speed
	
	sway += sway_delta * delta
	sway.x = min(max(sway.x, -1), 1)
	sway.y = min(max(sway.y, -1), 1)
	
	$AnimationTree["parameters/BlendLeftRight/blend_position"] = sway.x
	$AnimationTree["parameters/BlendUpDown/blend_position"] = sway.y
	
	# Keep track of how long we've been in the air
	if not is_on_floor():
		on_floor_last_time += delta
	else:
		on_floor_last_time = 0.0
	on_floor_last_tick = is_on_floor()

	if is_on_floor():
		# Determin how far we have fell
		var fall_height := last_place_on_ground - translation.y
			
		if fall_height >= fall_damage_distance:
			# Apply fall damage
			var damage := fall_damage_amount
			var additional_damage := fall_height - fall_damage_distance
			additional_damage /= additional_fall_damage_distance
			damage += int(floor(additional_damage))
			
			take_health(damage)
		
		last_place_on_ground = translation.y
	
	# Apply look vector to the camera
	$CamHing.rotation_degrees.x = look_rotation.y
	rotation_degrees.y = look_rotation.x
	GameState.set_vec2("look_rotation", look_rotation)
	
	# Calculate how faded the hurt image is
	var a : float = $UI/Game/Hurt.modulate.a
	if increase_hurt_alpha:
		a += delta * show_hurt_effects_speed
	else:
		a -= delta * show_hurt_effects_speed
	
	a = min(max(a, 0.0), 1.0)
	$UI/Game/Hurt.modulate.a = a
	GameState.set_data("hurt_amount", a)
	
	look_mouse = Vector2.ZERO

# Since the movement is physics based, we actually apply the movement here
func _physics_process(delta):
	var new_velocity : Vector3
	new_velocity = move_and_slide(velocity * delta, Vector3.UP, true) / delta
	
	# Help the player not fly up when they stop moving up a ramp
	if (new_velocity.y > 0.0) and not is_jumping and (movement.length() <= 0.05):
		new_velocity = Vector3.ZERO
		new_velocity.y = -1.0
	
	# Applies a continues downward force to help the player stick to ramps when
	# moving downwards
	if abs(velocity.y - new_velocity.y) >= 0.2:
		new_velocity.y -= 2.0
	
	velocity = new_velocity
	GameState.set_vec3("velocity", velocity)
	GameState.set_vec3("translation", translation)

const health_max_value := 93
const health_min_value := 8
# Updates the player's health bar and ammo text
func _update_UI():
	var ammo_text := str(GameState.clip_ammo) + "/" + str(GameState.total_ammo)
	$UI/Game/AmmoBar/CenterContainer/AmmoText.text = ammo_text
	
	var percent := float(GameState.health) / 100.0
	# Changs to the health bar only appear between the values 8 and 93, so remap
	# the value
	var health_amount : int = health_max_value
	health_amount -= health_min_value
	
	health_amount = int(health_amount * percent)
	health_amount += health_min_value
	
	$UI/Game/HealthBar/HealthBar.value = health_amount
	
	increase_hurt_alpha = GameState.health <= show_hurt_effects_at

# This is called when something gives the player health
func give_health(amount : int) -> int:
	# Take health until we are at 100 health
	var needed : int = 100 - GameState.health
	var taken = min(amount, needed)
	GameState.health += taken
	
	GameState.set_data("health", GameState.health)
	
	_update_UI()
	
	return taken

# This is called when something does damage to the player
func take_health(amount : int):
	# Remove health until we are at 0 health
	GameState.health -= amount
	GameState.health = int(max(GameState.health, 0))
	
	GameState.set_data("health", GameState.health)
	
	_update_UI()
	
	if GameState.health == 0:
		# We are dead. Disable the pause menu and tell the death screen to start
		$UI/Pause.set_process(false)
		$UI/Death.set_dead()

# Disables the pause menu and notify the win menu that it should start
func set_win():
	$UI/Pause.set_process(false)
	$UI/Win.set_win()

# This function handles picking things up. Right now, there is only ammo
func _on_GunPickup_body_entered(body : Spatial):
	if body.name == "AttachmentPoint" and body.visible:
		# Give the player a random amount of ammo
		var ammo := GameState.player_ammo_from_guns
		ammo += Utils.modi(randi(), GameState.player_ammo_from_guns_rand)
		GameState.total_ammo += ammo
		GameState.total_ammo = int(min(GameState.total_ammo, max_ammo))
		
		_update_UI()

	# Deletes the body
	var parent := body.get_parent()
	parent.remove_child(body)
	
	body.queue_free()
