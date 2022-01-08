extends KinematicBody
signal on_fire

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

func _ready():
	$CamHing/BulletCast.cast_to *= max_fire_range
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	GameState.health = GameState.get_data("health", 100)
	GameState.clip_ammo = GameState.get_data("clip_ammo", max_ammo_per_clip)
	GameState.total_ammo = GameState.get_data("total_ammo", 50)
	look_rotation = GameState.get_vec2("look_rotation", look_rotation)
	
	velocity = GameState.get_vec3("velocity", velocity)
	translation = GameState.get_vec3("translation", translation)
	
	$UI/Game/Hurt.modulate.a = GameState.get_data("hurt_amount", $UI/Game/Hurt.modulate.a)
	
	_update_UI()

func _input(event):
	if event is InputEventMouseMotion:
		look_mouse = event.relative * (GameState.mouse_sensitivity / 100.0)
		look_mouse = -look_mouse

func _process(delta):
	is_firing = $AnimationTree["parameters/FireOneShot/active"]
	is_reloading = $AnimationTree["parameters/ReloadOneShot/active"]
	
	var look_joy := Vector2.ZERO
	
	look_joy.x -= Input.get_action_strength("joy_look_right")
	look_joy.x += Input.get_action_strength("joy_look_left")
	
	look_joy.y += Input.get_action_strength("joy_look_up")
	look_joy.y -= Input.get_action_strength("joy_look_down")
	
	var sensitivity := GameState.joy_sensitivity / 50.0
	look_rotation += look_joy * joy_strength * sensitivity * delta
	look_rotation += look_mouse * mouse_strength
	look_mouse = Vector2.ZERO
	
	look_rotation.y = min(90.0, max(-90.0, look_rotation.y))
	
	movement = Vector3.ZERO
	
	movement -= transform.basis.z * Input.get_action_strength("game_up")
	movement += transform.basis.z * Input.get_action_strength("game_down")
	movement -= transform.basis.x * Input.get_action_strength("game_left")
	movement += transform.basis.x * Input.get_action_strength("game_right")
	
	if movement.length() > 1.0:
		movement = movement.normalized()
	
	if Input.is_action_pressed("game_jump") and is_on_floor():
		movement.y = jump
		is_jumping = true
		$AnimationTree["parameters/Movement/playback"].start("JumpStart")
	
	elif is_on_floor():
		is_jumping = false
	
	var bullet_obj : Spatial = $CamHing/BulletCast.get_collider()
	
	if Input.is_action_just_pressed("game_interact") and bullet_obj:
		var distance = bullet_obj.translation.distance_squared_to(translation)
		if bullet_obj.has_method("interact") and (distance <= interact_max_distance_sqaured):
			print("Found interactable")
			bullet_obj.interact()
	
	if Input.is_action_just_pressed("game_reload") and not is_firing and not is_reloading:
		if (GameState.total_ammo != 0) and (GameState.clip_ammo != max_ammo_per_clip):
			$AnimationTree["parameters/ReloadOneShot/active"] = true
			is_reloading = true
		
			var needed = max_ammo_per_clip - GameState.clip_ammo
			var taken = min(needed, GameState.total_ammo)
			GameState.total_ammo -= taken
			GameState.clip_ammo += taken
		
			GameState.set_data("total_ammo", GameState.total_ammo)
			GameState.set_data("clip_ammo", GameState.clip_ammo)
		
			_update_UI()
	
	$CamHing/AttachmentPoint/FlashLight.visible = false
	if Input.is_action_pressed("game_fire") and not is_firing and not is_reloading:
		if GameState.clip_ammo != 0:
			$AnimationTree["parameters/FireOneShot/active"] = true
			$CamHing/AttachmentPoint/FlashParticles.emitting = true
			$CamHing/AttachmentPoint/FlashLight.visible = true
			is_firing = true
			GameState.clip_ammo -= 1
			
			if bullet_obj and bullet_obj.has_method("take_health"):
				var damage := GameState.player_damage
				damage += randi() % GameState.player_damage_rand
				bullet_obj.call("take_health", damage)
			
			emit_signal("on_fire")
			
			GameState.set_data("clip_ammo", GameState.clip_ammo)
			
			_update_UI()
	
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
		if is_on_floor():
			force *= deceleration * delta
		else:
			force *= air_deceleration * delta
		velocity.x -= force.x
		velocity.z -= force.y

	var movement_speed := Vector2(velocity.x, velocity.z)
	if movement_speed.length() > max_speed:
		movement_speed = movement_speed.normalized() * max_speed
	
	velocity.x = movement_speed.x
	velocity.z = movement_speed.y
	
	if movement.y <= 0.0:
		velocity.y += GameState.gravity * delta

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

	if is_on_floor() and not on_floor_last_tick and (on_floor_last_time >= 0.05):
		$AnimationTree["parameters/Movement/playback"].start("JumpEnd")

	elif not is_on_floor() and not on_floor_last_tick and (on_floor_last_time >= 0.05):
		$AnimationTree["parameters/Movement/playback"].travel("Air")

	var sway_delta := look_joy - sway
	if sway_delta.length() > sway_speed:
		sway_delta = sway_delta.normalized() * sway_speed
	
	sway += sway_delta * delta
	sway.x = min(max(sway.x, -1), 1)
	sway.y = min(max(sway.y, -1), 1)
	
	$AnimationTree["parameters/BlendLeftRight/blend_position"] = sway.x
	$AnimationTree["parameters/BlendUpDown/blend_position"] = sway.y
	
	if not is_on_floor():
		on_floor_last_time += delta
	else:
		on_floor_last_time = 0.0
	on_floor_last_tick = is_on_floor()

	if is_on_floor():
		var fall_height := last_place_on_ground - translation.y
			
		if fall_height >= fall_damage_distance:
			var damage := fall_damage_amount
			var additional_damage := fall_height - fall_damage_distance
			additional_damage /= additional_fall_damage_distance
			damage += int(floor(additional_damage))
			
			take_health(damage)
		
		last_place_on_ground = translation.y
	
	$CamHing.rotation_degrees.x = look_rotation.y
	rotation_degrees.y = look_rotation.x
	GameState.set_vec2("look_rotation", look_rotation)
	
	var a : float = $UI/Game/Hurt.modulate.a
	if increase_hurt_alpha:
		a += delta * show_hurt_effects_speed
	else:
		a -= delta * show_hurt_effects_speed
	
	a = min(max(a, 0.0), 1.0)
	$UI/Game/Hurt.modulate.a = a
	GameState.set_data("hurt_amount", a)

func _physics_process(delta):
	var new_velocity : Vector3
	new_velocity = move_and_slide(velocity * delta, Vector3.UP, true) / delta
	
	if (new_velocity.y > 0.0) and not is_jumping and (movement.length() <= 0.05):
		new_velocity = Vector3.ZERO
		new_velocity.y = -1.0
	
	if abs(velocity.y - new_velocity.y) >= 0.2:
		new_velocity.y -= 2.0
	
	velocity = new_velocity
	GameState.set_vec3("velocity", velocity)
	GameState.set_vec3("translation", translation)

func _update_UI():
	var ammo_text := str(GameState.clip_ammo) + "/" + str(GameState.total_ammo)
	$UI/Game/AmmoBar/CenterContainer/AmmoText.text = ammo_text
	
	var percent := float(GameState.health) / 100.0
	var health_amount : int = $UI/Game/HealthBar/HealthBar.max_value
	health_amount -= $UI/Game/HealthBar/HealthBar.min_value
	
	health_amount = int(health_amount * percent)
	health_amount += $UI/Game/HealthBar/HealthBar.min_value
	
	$UI/Game/HealthBar/HealthBar.value = health_amount
	
	increase_hurt_alpha = GameState.health <= show_hurt_effects_at

func give_health(amount : int) -> int:
	var needed : int = 100 - GameState.health
	var taken = min(amount, needed)
	GameState.health += taken
	
	GameState.set_data("health", GameState.health)
	
	_update_UI()
	
	return taken
	
func take_health(amount : int):
	GameState.health -= amount
	GameState.health = int(max(GameState.health, 0))
	
	GameState.set_data("health", GameState.health)
	
	_update_UI()
	
	if GameState.health == 0:
		pass # You be dead son


func _on_GunPickup_body_entered(body : Spatial):
	if body.name == "AttachmentPoint" and body.visible:
	
		var ammo := GameState.player_ammo_from_guns
		ammo += randi() % GameState.player_ammo_from_guns_rand
		GameState.total_ammo += ammo
		GameState.total_ammo = int(min(GameState.total_ammo, max_ammo))
		
		_update_UI()

	var parent := body.get_parent()
	parent.remove_child(body)
	
	body.queue_free()
