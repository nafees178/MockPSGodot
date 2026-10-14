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

# --- Movement Parameters ---
@export_group("Movement")
@export var speed: float = 190.0
@export var walk_speed: float = 110.0
@export var acceleration: float = 1600.0
@export var friction: float = 1400.0
@export var air_acceleration: float = 1000.0
@export var air_friction: float = 300.0

@export_group("Jump")
@export var jump_velocity: float = -380.0
@export var min_jump_velocity: float = -140.0
@export var fall_gravity_multiplier: float = 1.6
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.14

@export_group("Dash")
@export var dash_speed: float = 460.0
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
var facing_direction: int = 1 # 1 = right, -1 = left
var default_gravity: float = 980.0
var spawn_point: Vector2 = Vector2.ZERO

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var attack_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

# Multi-hit tracking
var hit_1_fired: bool = false
var hit_2_fired: bool = false
var strike_hit_targets: Array[Node2D] = []

# Collider sizing
const STAND_HEIGHT: float = 54.0
const STAND_POS_Y: float = -27.0
const CROUCH_HEIGHT: float = 28.0
const CROUCH_POS_Y: float = -14.0

# --- Animation Normalization ---
const ANIM_CONFIGS: Dictionary = {
	"idle": { "scale": Vector2(0.148, 0.148), "offset": Vector2(0, -47.2) },
	"run": { "scale": Vector2(0.138, 0.138), "offset": Vector2(0, -44.0) },
	"walk": { "scale": Vector2(0.145, 0.145), "offset": Vector2(0, -34.7) },
	"punch": { "scale": Vector2(0.186, 0.186), "offset": Vector2(0, -31.4) },
	"air_attack": { "scale": Vector2(0.186, 0.186), "offset": Vector2(0, -40.7) },
	"katana": { "scale": Vector2(0.186, 0.186), "offset": Vector2(0, -59.3) },
	"jump_up": { "scale": Vector2(0.144, 0.144), "offset": Vector2(0, -44.0) },
	"fall": { "scale": Vector2(0.144, 0.144), "offset": Vector2(0, -44.0) },
	"dash": { "scale": Vector2(0.138, 0.138), "offset": Vector2(0, -44.0) },
	"crouch_idle": { "scale": Vector2(0.148, 0.148), "offset": Vector2(0, -47.2) },
	"crouch_walk": { "scale": Vector2(0.148, 0.148), "offset": Vector2(0, -47.2) },
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
		camera.position_smoothing_enabled = false
		camera.limit_left = -300
		camera.limit_top = -400
		camera.limit_right = 3700
		camera.limit_bottom = 620
		camera.reset_smoothing()
	
	_warm_up_textures()
	if animated_sprite:
		animated_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	# Quick weapon swap (Tab or Number keys 1, 2)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_1:
			var next_weapon = WeaponType.KATANA if current_weapon == WeaponType.UNARMED else WeaponType.UNARMED
			equip_weapon(next_weapon)
		elif event.keycode == KEY_2:
			equip_weapon(WeaponType.KATANA)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	
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
	var query = PhysicsShapeQueryParameters2D.new()
	var standing_shape = CapsuleShape2D.new()
	standing_shape.radius = 11.0
	standing_shape.height = STAND_HEIGHT - 2.0
	query.shape = standing_shape
	query.transform = Transform2D(0.0, global_position + Vector2(0, STAND_POS_Y))
	query.collision_mask = 1 # Solid terrain and barricades
	query.exclude = [get_rid()]
	var results = space_state.intersect_shape(query, 1)
	return results.size() > 0

# --- Timer Management ---
func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)

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
	var crouching: bool = (wants_crouch or under_ceiling) and is_on_floor()

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
			jumped.emit()
			change_state(State.JUMP)

	# Variable jump height
	if not is_on_floor() and velocity.y < min_jump_velocity:
		if not Input.is_action_pressed("jump"):
			velocity.y = min_jump_velocity

	# Horizontal velocity calculation
	var target_speed = speed
	if crouching:
		target_speed = walk_speed * 0.7

	var target_vel_x = input_x * target_speed
	var accel = acceleration if is_on_floor() else air_acceleration
	var decel = friction if is_on_floor() else air_friction

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
			_fire_strike(Vector2(20.0, -25.0), Vector2(30.0, 36.0), 1)
		# Punch 2 (Right cross at ~0.38s)
		elif attack_timer >= 0.38 and not hit_2_fired:
			hit_2_fired = true
			_fire_strike(Vector2(24.0, -25.0), Vector2(34.0, 36.0), 1)

	elif current_state == State.KATANA:
		# Katana Slash 1 (First sweep at ~0.14s)
		if attack_timer >= 0.14 and not hit_1_fired:
			hit_1_fired = true
			_fire_strike(Vector2(28.0, -27.0), Vector2(48.0, 44.0), 2)
		# Katana Slash 2 (Second sweep at ~0.40s)
		elif attack_timer >= 0.40 and not hit_2_fired:
			hit_2_fired = true
			_fire_strike(Vector2(32.0, -27.0), Vector2(52.0, 44.0), 2)

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
		if target.has_method("take_damage"):
			target.take_damage(damage)

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
	current_weapon = weapon
	weapon_changed.emit(current_weapon)

func start_dash() -> void:
	var input_x = _get_horizontal_input()
	var dir_x = input_x if input_x != 0.0 else float(facing_direction)
	dash_direction = Vector2(dir_x, 0.0).normalized()
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
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

func respawn() -> void:
	velocity = Vector2.ZERO
	global_position = spawn_point
	change_state(State.IDLE)
	respawned.emit()
	if camera:
		camera.reset_smoothing()
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.08)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.08)
		tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.08)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.08)

# --- Animation Control ---
func _play_anim(anim_to_play: String) -> void:
	if not animated_sprite:
		return
	if animated_sprite.animation != anim_to_play or not animated_sprite.is_playing():
		animated_sprite.play(anim_to_play)
	
	var cfg = ANIM_CONFIGS.get(anim_to_play, ANIM_CONFIGS["idle"])
	animated_sprite.scale = cfg["scale"]
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
