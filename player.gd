class_name Player
extends CharacterBody2D

signal state_changed(old_state: int, new_state: int)
signal attack_performed(attack_name: String)
signal weapon_changed(new_weapon: int)
signal dashed(direction: Vector2)
signal jumped
signal respawned

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	LAND,
	DASH,
	PUNCH,
	KATANA,
	CROUCH
}

enum WeaponType {
	UNARMED,
	KATANA,
	GUN
}

# --- Weapon System ---
@export_group("Equipment")
@export var current_weapon: WeaponType = WeaponType.UNARMED
@export var has_katana: bool = false

# --- Movement Parameters ---
@export_group("Movement")
@export var speed: float = 140.0
@export var walk_speed: float = 85.0
@export var acceleration: float = 1200.0
@export var friction: float = 1100.0
@export var air_acceleration: float = 800.0
@export var air_friction: float = 250.0

@export_group("Jump")
@export var jump_velocity: float = -280.0
@export var min_jump_velocity: float = -110.0
@export var fall_gravity_multiplier: float = 1.6
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.14

@export_group("Dash")
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.20
@export var dash_cooldown: float = 0.35

@export_group("Combat")
@export var attack_timeout: float = 1.2

# --- Nodes ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var attack_collision: CollisionShape2D = get_node_or_null("AttackArea/AttackCollision")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

# --- Internal State ---
var current_state: State = State.IDLE
var is_dying: bool = false
var visual_squash: Vector2 = Vector2.ONE
var ghost_timer: float = 0.0
var was_on_floor: bool = true
var prev_velocity_y: float = 0.0
var facing_direction: int = 1 # 1 = right, -1 = left
var default_gravity: float = 980.0
var spawn_point: Vector2 = Vector2.ZERO

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var bounce_grace_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var attack_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

# Multi-hit tracking
var hit_1_fired: bool = false
var hit_2_fired: bool = false
var strike_hit_targets: Array[Node2D] = []

# Collider sizing
const STAND_HEIGHT: float = 28.0
const STAND_POS_Y: float = -14.0
const CROUCH_HEIGHT: float = 16.0
const CROUCH_POS_Y: float = -8.0

# --- Animation Normalization ---
const ANIM_CONFIGS: Dictionary = {
	"idle": { "scale": Vector2(0.075, 0.075), "offset": Vector2(0, -24.0) },
	"run": { "scale": Vector2(0.070, 0.070), "offset": Vector2(0, -22.4) },
	"walk": { "scale": Vector2(0.074, 0.074), "offset": Vector2(0, -17.7) },
	"punch": { "scale": Vector2(0.095, 0.095), "offset": Vector2(0, -16.0) },
	"air_attack": { "scale": Vector2(0.095, 0.095), "offset": Vector2(0, -20.8) },
	"katana": { "scale": Vector2(0.095, 0.095), "offset": Vector2(0, -30.2) },
	"jump_up": { "scale": Vector2(0.073, 0.073), "offset": Vector2(0, -22.4) },
	"fall": { "scale": Vector2(0.073, 0.073), "offset": Vector2(0, -22.4) },
	"dash": { "scale": Vector2(0.070, 0.070), "offset": Vector2(0, -22.4) },
	"crouch_idle": { "scale": Vector2(0.075, 0.075), "offset": Vector2(0, -24.0) },
	"crouch_walk": { "scale": Vector2(0.075, 0.075), "offset": Vector2(0, -24.0) },
	"death": { "scale": Vector2(0.080, 0.080), "offset": Vector2(0, -24.0) },
	"hurt": { "scale": Vector2(0.075, 0.075), "offset": Vector2(0, -24.0) },
	"land": { "scale": Vector2(0.073, 0.073), "offset": Vector2(0, -22.4) },
}

func _ready() -> void:
	default_gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	spawn_point = global_position
	
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	if attack_collision and attack_collision.shape:
		attack_collision.shape = attack_collision.shape.duplicate()
		attack_collision.disabled = true
	
	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_entered)
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	if camera:
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0
		camera.limit_left = -80
		camera.limit_top = -320
		camera.limit_right = 2440
		camera.limit_bottom = 140
		camera.reset_smoothing()
		JuiceManager.register_camera(camera)
	
	# Restore equipment state from previous level
	if SettingsManager.has_katana:
		unlock_katana()

	_warm_up_textures()
	if animated_sprite:
		animated_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("player")
	z_index = 10 # Elevate player above background layers in all scenes
	change_state(State.IDLE)
	_play_anim("idle")

# Pre-warms textures and GPU pipelines so first-time action never stutters
func _warm_up_textures() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var warm_box = Node2D.new()
	warm_box.modulate.a = 0.001
	add_child(warm_box)
	
	for anim in animated_sprite.sprite_frames.get_animation_names():
		var frames = animated_sprite.sprite_frames.get_frame_count(anim)
		for f in range(min(frames, 2)):
			var tex = animated_sprite.sprite_frames.get_frame_texture(anim, f)
			if tex:
				var spr = Sprite2D.new()
				spr.texture = tex
				spr.scale = Vector2(0.01, 0.01)
				warm_box.add_child(spr)
	
	get_tree().create_timer(0.08).timeout.connect(warm_box.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	# Quick weapon swap (Tab or Number keys 1, 2) - only if katana is unlocked
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_1:
			if has_katana:
				var next_weapon = WeaponType.KATANA if current_weapon == WeaponType.UNARMED else WeaponType.UNARMED
				equip_weapon(next_weapon)
		elif event.keycode == KEY_2:
			if has_katana:
				equip_weapon(WeaponType.KATANA)

func _physics_process(delta: float) -> void:
	if is_dying:
		move_and_slide()
		return

	_update_timers(delta)
	
	# Smooth squash & stretch decay
	visual_squash = visual_squash.lerp(Vector2.ONE, 12.0 * delta)
	
	# Landing detection for juice (squash + dust)
	if not was_on_floor and is_on_floor():
		if prev_velocity_y > 100.0:
			var impact = clamp(prev_velocity_y / 500.0, 0.1, 0.35)
			visual_squash = Vector2(1.0 + impact, 1.0 - impact * 0.7)
			JuiceManager.spawn_dust_puff(global_position, 5)
			if prev_velocity_y > 320.0:
				JuiceManager.add_trauma(0.12)
	was_on_floor = is_on_floor()
	prev_velocity_y = velocity.y
	
	match current_state:
		State.DASH:
			_process_dash_state(delta)
		State.PUNCH, State.KATANA:
			_process_attack_state(delta)
		_:
			_process_normal_movement(delta)

	move_and_slide()

	# Ceiling collision handling - cancel upward velocity immediately so head doesn't stick
	if is_on_ceiling() and velocity.y < 0.0:
		velocity.y = 0.0

	_update_animation()

# --- Ceiling Clearance Check ---
func is_under_ceiling() -> bool:
	var space_state = get_world_2d().direct_space_state
	# Cast vertical rays upward from inside the crouch bounds to standing head height.
	# Using local coordinates converted via to_global() accounts for player node scale.
	# Rays at x offsets -4, -2, 0, 2, 4 local units stay well inside the player's 6.0 radius,
	# avoiding false positives on adjacent vertical walls while ensuring any ceiling is detected.
	var x_offsets = [-4.0, -2.0, 0.0, 2.0, 4.0]
	var query = PhysicsRayQueryParameters2D.new()
	query.collision_mask = 1 # Solid terrain and barricades
	query.exclude = [get_rid()]
	
	for x_off in x_offsets:
		query.from = to_global(Vector2(x_off, -CROUCH_HEIGHT + 2.0))
		query.to = to_global(Vector2(x_off, -STAND_HEIGHT - 1.0))
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			# In Godot 2D (+Y is down), a ceiling has a downward-facing normal (normal.y > 0)
			if hit.normal.y > 0.1:
				return true
	return false

# --- Timer Management ---
func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)
	bounce_grace_timer = max(0.0, bounce_grace_timer - delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

func _get_horizontal_input() -> float:
	return Input.get_axis("move_left", "move_right")

# --- State Handlers ---
func _process_normal_movement(delta: float) -> void:
	# Single attack action trigger - strictly on floor only
	if Input.is_action_just_pressed("attack") and is_on_floor():
		perform_attack()
		return

	# Dash initiation (Ground or Air)
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		start_dash()
		return

	var input_x: float = _get_horizontal_input()
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	var under_ceiling: bool = is_under_ceiling()
	var crouching: bool = (wants_crouch or (current_state == State.CROUCH and under_ceiling)) and is_on_floor()

	# Drop-through one-way platforms: S + Jump
	if crouching and (Input.is_action_just_pressed("jump") or jump_buffer_timer > 0.0):
		position.y += 3.0
		jump_buffer_timer = 0.0
		return

	# Facing direction update
	if input_x != 0.0:
		facing_direction = 1 if input_x > 0 else -1
		if animated_sprite:
			animated_sprite.flip_h = (facing_direction < 0)
		if attack_area:
			attack_area.scale.x = facing_direction

	# Gravity calculation
	if not is_on_floor():
		var grav = default_gravity
		if velocity.y > 0.0:
			grav *= fall_gravity_multiplier
		velocity.y += grav * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	# Jump initiation (Jump buffering & Coyote time)
	if (Input.is_action_just_pressed("jump") or jump_buffer_timer > 0.0) and (coyote_timer > 0.0 or is_on_floor()):
		if not under_ceiling:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			visual_squash = Vector2(0.85, 1.25)
			JuiceManager.spawn_dust_puff(global_position, 4)
			JuiceManager.add_trauma(0.12) # Subtle punchy jump shake
			jumped.emit()
			change_state(State.JUMP)

	# Variable jump height - bypassed if actively bouncing from a jump pad
	if bounce_grace_timer <= 0.0 and not is_on_floor() and velocity.y < min_jump_velocity:
		if not Input.is_action_pressed("jump"):
			velocity.y = min_jump_velocity

# --- SLIPPERY TILE DETECTION ---
	var is_slippery := false
	if is_on_floor():
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider is TileMapLayer and collider.tile_set:
				if collider.tile_set.has_custom_data_layer_by_name("is_slippery"):
					var collision_point = collision.get_position() - (collision.get_normal() * 4.0)
					var tile_pos = collider.local_to_map(collider.to_local(collision_point))
					var tile_data = collider.get_cell_tile_data(tile_pos)
					if tile_data and tile_data.get_custom_data("is_slippery"):
						is_slippery = true
						break

	# Horizontal velocity calculation
	var target_speed = speed
	if crouching:
		target_speed = walk_speed * 0.7

	var target_vel_x = input_x * target_speed
	
	# Scale down acceleration and friction if on slippery ice
	var accel = (acceleration * 0.12) if is_slippery else (acceleration if is_on_floor() else air_acceleration)
	var decel = (friction * 0.06) if is_slippery else (friction if is_on_floor() else air_friction)

	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, target_vel_x, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	# Locomotion state transition
	if is_on_floor():
		if crouching:
			change_state(State.CROUCH)
		elif abs(velocity.x) > 10.0:
			change_state(State.RUN)
		else:
			change_state(State.IDLE)
	else:
		if velocity.y < 0.0:
			change_state(State.JUMP)
		else:
			change_state(State.FALL)

func _process_dash_state(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed
	
	# Spawn ninja dash ghost afterimage
	ghost_timer -= delta
	if ghost_timer <= 0.0:
		ghost_timer = 0.04
		_spawn_ghost_afterimage()

	if dash_timer <= 0.0:
		velocity.x = dash_direction.x * speed * 0.8
		velocity.y = 0.0
		change_state(State.IDLE if is_on_floor() else State.FALL)

# --- Multi-Hit Attack System ---
func _process_attack_state(delta: float) -> void:
	attack_timer += delta
	if not is_on_floor():
		velocity.y += default_gravity * 0.8 * delta
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if current_state == State.PUNCH:
		# Punch 1 (Left jab at ~0.12s)
		if attack_timer >= 0.12 and not hit_1_fired:
			hit_1_fired = true
			_fire_strike(Vector2(10.0, -13.0), Vector2(16.0, 18.0), 1)
		# Punch 2 (Right cross at ~0.38s)
		elif attack_timer >= 0.38 and not hit_2_fired:
			hit_2_fired = true
			_fire_strike(Vector2(12.0, -13.0), Vector2(18.0, 18.0), 1)

	elif current_state == State.KATANA:
		# Katana Slash 1 (First sweep at ~0.14s)
		if attack_timer >= 0.14 and not hit_1_fired:
			hit_1_fired = true
			_fire_strike(Vector2(14.0, -14.0), Vector2(25.0, 22.0), 2)
		# Katana Slash 2 (Second sweep at ~0.40s)
		elif attack_timer >= 0.40 and not hit_2_fired:
			hit_2_fired = true
			_fire_strike(Vector2(16.0, -14.0), Vector2(27.0, 22.0), 2)

	if attack_timer >= attack_timeout:
		_end_attack()

func _fire_strike(hitbox_pos: Vector2, hitbox_size: Vector2, damage: int) -> void:
	strike_hit_targets.clear()
	if attack_collision:
		attack_collision.position = hitbox_pos
		if attack_collision.shape is RectangleShape2D:
			attack_collision.shape.size = hitbox_size
		attack_collision.disabled = false
	
	if attack_area:
		attack_area.monitoring = true
		var overlapping = attack_area.get_overlapping_areas()
		for area in overlapping:
			_handle_strike_hit(area, damage)
	
	get_tree().create_timer(0.12).timeout.connect(func():
		if attack_collision and (current_state == State.PUNCH or current_state == State.KATANA):
			attack_collision.disabled = true
	)

func _handle_strike_hit(area: Area2D, damage: int) -> void:
	var target = area.get_parent()
	if target and not (target in strike_hit_targets):
		strike_hit_targets.append(target)
		
		# Combat Juice
		JuiceManager.hit_stop(0.05)
		JuiceManager.add_trauma(0.25 if current_weapon == WeaponType.KATANA else 0.15)
		JuiceManager.spawn_impact_sparks(area.global_position, Vector2(facing_direction, -0.4))
		JuiceManager.spawn_damage_number(area.global_position, damage, current_weapon == WeaponType.KATANA)
		
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif area.has_method("take_damage"):
			area.take_damage(damage)

func _on_attack_area_entered(area: Area2D) -> void:
	if current_state == State.PUNCH or current_state == State.KATANA:
		var dmg = 2 if current_weapon == WeaponType.KATANA else 1
		_handle_strike_hit(area, dmg)

func perform_attack() -> void:
	if not is_on_floor():
		return
	match current_weapon:
		WeaponType.UNARMED:
			start_punch()
		WeaponType.KATANA:
			start_katana()
		WeaponType.GUN:
			pass

func equip_weapon(weapon: WeaponType) -> void:
	if weapon == WeaponType.KATANA and not has_katana:
		return
	current_weapon = weapon
	weapon_changed.emit(current_weapon)

func bounce(bounce_vel: float) -> void:
	velocity.y = bounce_vel
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	bounce_grace_timer = 0.45 # Protect bounce from variable jump cutoff
	position.y -= 4.0 # Break floor snap immediately
	visual_squash = Vector2(0.85, 1.25)
	JuiceManager.add_trauma(0.14)
	change_state(State.JUMP)
	_play_anim("jump_up")

func unlock_katana() -> void:
	has_katana = true
	SettingsManager.has_katana = true
	equip_weapon(WeaponType.KATANA)

func start_dash() -> void:
	var input_x = _get_horizontal_input()
	var dir_x = input_x if input_x != 0.0 else float(facing_direction)
	dash_direction = Vector2(dir_x, 0.0).normalized()
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	ghost_timer = 0.0
	visual_squash = Vector2(1.25, 0.8)
	JuiceManager.add_trauma(0.18)
	JuiceManager.pulse_aberration(0.012, 0.22)
	JuiceManager.spawn_dust_puff(global_position + Vector2(-facing_direction * 8, 0), 6)
	dashed.emit(dash_direction)
	change_state(State.DASH)
	_play_anim("dash")

func start_punch() -> void:
	if not is_on_floor():
		return
	attack_timer = 0.0
	hit_1_fired = false
	hit_2_fired = false
	strike_hit_targets.clear()
	attack_performed.emit("punch")
	change_state(State.PUNCH)
	_play_anim("punch")
	velocity.x = 0.0

func start_katana() -> void:
	if not is_on_floor():
		return
	attack_timer = 0.0
	hit_1_fired = false
	hit_2_fired = false
	strike_hit_targets.clear()
	attack_performed.emit("katana")
	change_state(State.KATANA)
	_play_anim("katana")
	velocity.x = 0.0

func _end_attack() -> void:
	if attack_collision:
		attack_collision.disabled = true
	if is_on_floor():
		var input_x = _get_horizontal_input()
		if input_x != 0.0:
			change_state(State.RUN)
		else:
			change_state(State.IDLE)
	else:
		change_state(State.FALL)
	_update_animation()

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# Cannot exit CROUCH if still under a ceiling
	if current_state == State.CROUCH and new_state != State.CROUCH and is_under_ceiling():
		return

	var old_state = current_state
	current_state = new_state
	
	if collision_shape and collision_shape.shape is CapsuleShape2D:
		if new_state == State.CROUCH:
			collision_shape.shape.height = CROUCH_HEIGHT
			collision_shape.position = Vector2(0, CROUCH_POS_Y)
		elif old_state == State.CROUCH:
			collision_shape.shape.height = STAND_HEIGHT
			collision_shape.position = Vector2(0, STAND_POS_Y)
	
	state_changed.emit(old_state, new_state)

# --- Checkpoint & Respawn ---
func set_checkpoint(pos: Vector2) -> void:
	spawn_point = pos

func take_damage(_amount: int = 1) -> void:
	start_death_sequence()

func die() -> void:
	start_death_sequence()

func respawn() -> void:
	start_death_sequence()

func start_death_sequence() -> void:
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	
	# Hit-stop & screen impact
	JuiceManager.hit_stop(0.06)
	JuiceManager.add_trauma(0.32)
	JuiceManager.flash_crimson(0.38, 0.7)
	JuiceManager.pulse_aberration(0.02, 0.28)
	JuiceManager.spawn_death_burst(global_position + Vector2(0, -12), Color(1.0, 0.25, 0.25))
	
	# Audio cue
	var sfx = load("res://audio/sfx_lose.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.volume_db = -2.0
		get_parent().add_child(asp)
		asp.global_position = global_position
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		_play_anim("death")
	
	_trigger_death_shutter()

func _trigger_death_shutter() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 160
	add_child(canvas)
	
	var shutter_top = ColorRect.new()
	shutter_top.color = Color(0.06, 0.08, 0.12, 1.0)
	shutter_top.size = Vector2(1280, 362)
	shutter_top.position = Vector2(0, -362)
	canvas.add_child(shutter_top)
	
	var shutter_bottom = ColorRect.new()
	shutter_bottom.color = Color(0.06, 0.08, 0.12, 1.0)
	shutter_bottom.size = Vector2(1280, 362)
	shutter_bottom.position = Vector2(0, 720)
	canvas.add_child(shutter_bottom)
	
	# Close shutter over 0.32s
	var close_t = create_tween()
	close_t.parallel().tween_property(shutter_top, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	close_t.parallel().tween_property(shutter_bottom, "position:y", 358.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	close_t.chain().tween_callback(func():
		# Reset player position to checkpoint
		global_position = spawn_point
		velocity = Vector2.ZERO
		change_state(State.IDLE)
		_play_anim("idle")
		if camera:
			camera.reset_smoothing()
		respawned.emit()
		JuiceManager.spawn_shockwave(global_position + Vector2(0, -6), Color(0.3, 0.85, 1.0))
	)
	
	close_t.chain().tween_interval(0.12)
	
	# Open shutter over 0.28s
	close_t.chain().tween_property(shutter_top, "position:y", -362.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	close_t.parallel().tween_property(shutter_bottom, "position:y", 720.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	close_t.chain().tween_callback(func():
		canvas.queue_free()
		is_dying = false
		_play_respawn_invulnerability()
	)

func _play_respawn_invulnerability() -> void:
	if not animated_sprite:
		return
	var tween = create_tween()
	for i in range(4):
		tween.tween_property(animated_sprite, "modulate:a", 0.35, 0.09)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.09)

func _spawn_ghost_afterimage() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var cur_anim = animated_sprite.animation
	var cur_frame = animated_sprite.frame
	var tex = animated_sprite.sprite_frames.get_frame_texture(cur_anim, cur_frame)
	if not tex:
		return
	
	var ghost = Sprite2D.new()
	ghost.texture = tex
	ghost.scale = animated_sprite.scale
	ghost.global_position = animated_sprite.global_position
	ghost.flip_h = animated_sprite.flip_h
	ghost.modulate = Color(0.35, 0.85, 1.0, 0.7)
	ghost.z_index = 9 # Render in world 2D space above terrain/background (0) and behind player (10)
	scene.add_child(ghost)
	
	var gt = create_tween()
	gt.parallel().tween_property(ghost, "modulate:a", 0.0, 0.22)
	gt.parallel().tween_property(ghost, "scale", animated_sprite.scale * 1.12, 0.22)
	gt.chain().tween_callback(ghost.queue_free)

# --- Animation Control ---
func _play_anim(anim_to_play: String) -> void:
	if not animated_sprite:
		return
	if animated_sprite.animation != anim_to_play or not animated_sprite.is_playing():
		animated_sprite.play(anim_to_play)
	
	var cfg = ANIM_CONFIGS.get(anim_to_play, ANIM_CONFIGS["idle"])
	animated_sprite.scale = cfg["scale"] * visual_squash
	animated_sprite.position = cfg["offset"]
	animated_sprite.reset_physics_interpolation()

func _update_animation() -> void:
	if not animated_sprite:
		return

	if current_state == State.PUNCH or current_state == State.KATANA or current_state == State.DASH:
		return

	var anim_to_play: String = ""
	match current_state:
		State.IDLE:
			anim_to_play = "idle"
		State.RUN:
			anim_to_play = "run"
		State.JUMP:
			anim_to_play = "jump_up"
		State.FALL:
			anim_to_play = "fall"
		State.CROUCH:
			anim_to_play = "crouch_walk" if abs(velocity.x) > 10.0 else "crouch_idle"

	if anim_to_play != "":
		_play_anim(anim_to_play)

func _on_animation_finished() -> void:
	var anim_name = animated_sprite.animation
	match current_state:
		State.PUNCH:
			if anim_name == "punch" or anim_name == "air_attack":
				_end_attack()
		State.KATANA:
			if anim_name == "katana":
				_end_attack()
		State.DASH:
			if anim_name == "dash":
				if is_on_floor():
					change_state(State.IDLE)
				else:
					change_state(State.FALL)
				_update_animation()
