class_name Player
extends CharacterBody2D

signal state_changed(old_state: int, new_state: int)
signal attack_performed(attack_name: String)
signal weapon_changed(new_weapon: int)
signal dashed(direction: Vector2)
signal jumped

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
@export var jump_velocity: float = -360.0
@export var min_jump_velocity: float = -140.0
@export var fall_gravity_multiplier: float = 1.6
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

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

# --- Internal State ---
var current_state: State = State.IDLE
var facing_direction: int = 1 # 1 = right, -1 = left
var default_gravity: float = 980.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var attack_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

# --- Animation Normalization ---
# Ensures 100% consistent character size (~55px) and grounded feet across all sheets
const ANIM_CONFIGS: Dictionary = {
	"idle": { "scale": Vector2(0.148, 0.148), "offset": Vector2(0, -47.2) },
	"run": { "scale": Vector2(0.138, 0.138), "offset": Vector2(0, -44.0) },
	"walk": { "scale": Vector2(0.145, 0.145), "offset": Vector2(0, -34.7) },
	"punch": { "scale": Vector2(0.186, 0.186), "offset": Vector2(0, -31.4) },
	"air_attack": { "scale": Vector2(0.186, 0.186), "offset": Vector2(0, -40.7) },
	"katana": { "scale": Vector2(0.186, 0.186), "offset": Vector2(0, -59.3) },
	"jump_up": { "scale": Vector2(0.142, 0.142), "offset": Vector2(0, -35.4) },
	"fall": { "scale": Vector2(0.142, 0.142), "offset": Vector2(0, -35.4) },
	"dash": { "scale": Vector2(0.138, 0.138), "offset": Vector2(0, -44.0) },
	"crouch_idle": { "scale": Vector2(0.148, 0.148), "offset": Vector2(0, -47.2) },
	"crouch_walk": { "scale": Vector2(0.148, 0.148), "offset": Vector2(0, -47.2) },
}

func _ready() -> void:
	default_gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	change_state(State.IDLE)
	_play_anim("idle")

func _unhandled_input(event: InputEvent) -> void:
	# Quick weapon swap for testing (Tab or Number keys 1, 2)
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

	# Dash initiation
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		start_dash()
		return

	var input_x: float = _get_horizontal_input()
	var crouching: bool = Input.is_action_pressed("crouch") and is_on_floor()

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

func _process_attack_state(delta: float) -> void:
	attack_timer += delta
	if not is_on_floor():
		velocity.y += default_gravity * 0.8 * delta
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if attack_timer >= attack_timeout:
		_end_attack()

# --- Attack System (Single Attack Button) ---
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
	attack_performed.emit("punch")
	change_state(State.PUNCH)
	_play_anim("punch")
	velocity.x = 0.0

func start_katana() -> void:
	if not is_on_floor():
		return
	attack_timer = 0.0
	attack_performed.emit("katana")
	change_state(State.KATANA)
	_play_anim("katana")
	velocity.x = 0.0

func _end_attack() -> void:
	if is_on_floor():
		var input_x = _get_horizontal_input()
		if input_x != 0.0:
			change_state(State.RUN)
		else:
			change_state(State.IDLE)
	else:
		change_state(State.FALL)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

# --- Animation Control ---
func _play_anim(anim_to_play: String) -> void:
	if not animated_sprite:
		return
	if animated_sprite.animation != anim_to_play or not animated_sprite.is_playing():
		animated_sprite.play(anim_to_play)
	
	# Apply normalized scale and offset so all animations match idle height and ground position
	var cfg = ANIM_CONFIGS.get(anim_to_play, ANIM_CONFIGS["idle"])
	animated_sprite.scale = cfg["scale"]
	animated_sprite.position = cfg["offset"]

func _update_animation() -> void:
	if not animated_sprite:
		return

	# If currently attacking or dashing, let that animation finish uninterrupted
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
