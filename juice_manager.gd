extends Node

# Centralized Game Feel & Juice Manager
# Coordinates camera shake, hit-stop, screen flashes, post-processing, visual feedback,
# and controller haptic vibration.

class ShockwaveRing extends Node2D:
	var radius: float = 3.0
	var ring_color: Color = Color(0.3, 1.0, 0.6, 1.0)
	var line_width: float = 2.5
	
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring_color, line_width)

var _active_camera: Camera2D = null
var _base_cam_offset: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _trauma_power: float = 2.0
var _decay_rate: float = 1.8
var _max_offset: Vector2 = Vector2(16.0, 10.0)
var _max_roll: float = 0.024
var _noise_time: float = 0.0

var _rumble_priority: int = 0
var _rumble_end_time: float = 0.0
var _is_frozen: bool = false
var _post_layer: CanvasLayer = null
var _post_rect: ColorRect = null
var _post_mat: ShaderMaterial = null
var _world_env: WorldEnvironment = null

var _font: Font = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://audio/kenvector_future.ttf") as Font
	_setup_environment()
	_setup_post_processing()
	_setup_controller_inputs()

func _process(delta: float) -> void:
	_update_camera_shake(delta)

# --- Camera Shake System (Trauma Based) ---
func register_camera(cam: Camera2D) -> void:
	_active_camera = cam
	if _active_camera:
		_base_cam_offset = _active_camera.offset

func add_trauma(amount: float) -> void:
	if not SettingsManager.screen_shake:
		return
	_trauma = clamp(_trauma + amount, 0.0, 1.0)
	if SettingsManager.controller_vibration and amount >= 0.2:
		var strong_amt = clampf(amount * 0.8, 0.15, 0.9)
		var weak_amt = clampf(amount * 0.6, 0.1, 0.8)
		vibrate_controller(weak_amt, strong_amt, 0.14)

func _update_camera_shake(delta: float) -> void:
	if _trauma <= 0.0:
		if _active_camera and is_instance_valid(_active_camera):
			_active_camera.offset = _base_cam_offset
			_active_camera.rotation = 0.0
		return
	
	_trauma = max(0.0, _trauma - _decay_rate * delta)
	_noise_time += delta * 45.0
	
	if _active_camera and is_instance_valid(_active_camera):
		var shake = pow(_trauma, _trauma_power)
		var off_x = _max_offset.x * shake * sin(_noise_time * 1.3)
		var off_y = _max_offset.y * shake * cos(_noise_time * 1.7)
		var roll = _max_roll * shake * sin(_noise_time * 0.9)
		
		_active_camera.offset = _base_cam_offset + Vector2(off_x, off_y)
		_active_camera.rotation = roll

# --- Hit-Stop / Frame Freeze ---
func hit_stop(duration: float = 0.05, time_scale: float = 0.02) -> void:
	if _is_frozen:
		return
	_is_frozen = true
	Engine.time_scale = time_scale
	
	# Uses ignore_time_scale so the unfreeze timer fires in real time
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
		_is_frozen = false
	)

# --- Post-Processing & Screen Flashes ---
func flash_white(duration: float = 0.08, intensity: float = 0.6) -> void:
	if not _post_mat:
		return
	var t = create_tween().set_ignore_time_scale(true)
	_post_mat.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, intensity))
	t.tween_method(func(val: float):
		if _post_mat:
			_post_mat.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, val))
	, intensity, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func flash_crimson(duration: float = 0.35, intensity: float = 0.65) -> void:
	if not _post_mat:
		return
	var t = create_tween().set_ignore_time_scale(true)
	_post_mat.set_shader_parameter("flash_color", Color(0.85, 0.1, 0.1, intensity))
	t.tween_method(func(val: float):
		if _post_mat:
			_post_mat.set_shader_parameter("flash_color", Color(0.85, 0.1, 0.1, val))
	, intensity, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func pulse_aberration(amount: float = 0.015, duration: float = 0.22) -> void:
	if not _post_mat:
		return
	var t = create_tween().set_ignore_time_scale(true)
	_post_mat.set_shader_parameter("aberration_amount", amount)
	t.tween_method(func(val: float):
		if _post_mat:
			_post_mat.set_shader_parameter("aberration_amount", val)
	, amount, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# --- Controller Haptic Feedback (Vibration) ---
func vibrate_controller(weak: float = 0.5, strong: float = 0.5, duration: float = 0.2, priority: int = 0) -> void:
	if not SettingsManager.controller_vibration:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < _rumble_end_time and priority < _rumble_priority:
		return # Do not let lower-priority vibration interrupt an active high-priority rumble
	
	_rumble_priority = priority
	_rumble_end_time = current_time + duration
	
	var pads = Input.get_connected_joypads()
	if pads.is_empty():
		Input.start_joy_vibration(0, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)
	else:
		for pad in pads:
			Input.start_joy_vibration(pad, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)

func stop_controller_vibration() -> void:
	_rumble_priority = 0
	_rumble_end_time = 0.0
	var pads = Input.get_connected_joypads()
	if pads.is_empty():
		Input.stop_joy_vibration(0)
	else:
		for pad in pads:
			Input.stop_joy_vibration(pad)

# Tactile rumble presets
func rumble_death() -> void:
	# Maximum intensity violent controller shake when dead (priority 10)
	vibrate_controller(1.0, 1.0, 0.70, 10)
	# Secondary visceral aftershock pulse as shutter slams shut
	var tree = get_tree()
	if tree:
		tree.create_timer(0.28, true, false, true).timeout.connect(func():
			if SettingsManager.controller_vibration:
				vibrate_controller(0.95, 1.0, 0.45, 10)
		)

func rumble_respawn() -> void:
	# Punchy shockwave pop upon checkpoint respawn
	vibrate_controller(0.4, 0.2, 0.15)

func rumble_hit() -> void:
	# Impact hit-stop rumble for melee hits on enemies or crates
	vibrate_controller(0.7, 0.6, 0.16)

func rumble_dash() -> void:
	# High-frequency tactile zip
	vibrate_controller(0.65, 0.25, 0.14)

func rumble_land() -> void:
	# Low-frequency thud on hard impact landing
	vibrate_controller(0.2, 0.5, 0.16)

func rumble_bounce() -> void:
	# Springy pop for jump pads
	vibrate_controller(0.5, 0.4, 0.2)

func rumble_attack() -> void:
	# Subtle swing whoosh
	vibrate_controller(0.25, 0.1, 0.08)

func rumble_jump() -> void:
	# Crisp light tap on jump launch
	vibrate_controller(0.2, 0.0, 0.06)

# --- Automatic Controller Input Setup ---
func _setup_controller_inputs() -> void:
	_add_joy_motion("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	
	_add_joy_motion("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	
	_add_joy_button("jump", JOY_BUTTON_A)
	
	_add_joy_button("dash", JOY_BUTTON_B)
	_add_joy_button("dash", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_motion("dash", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	
	_add_joy_button("attack", JOY_BUTTON_X)
	_add_joy_button("attack", JOY_BUTTON_Y)
	_add_joy_button("attack", JOY_BUTTON_LEFT_SHOULDER)
	
	_add_joy_motion("crouch", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("crouch", JOY_BUTTON_DPAD_DOWN)
	
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_key("pause", KEY_ESCAPE)
	
	_add_joy_button("weapon_swap", JOY_BUTTON_Y)
	_add_joy_button("weapon_swap", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_key("weapon_swap", KEY_TAB)

func _add_joy_button(action_name: String, button_index: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return
	var btn_event = InputEventJoypadButton.new()
	btn_event.button_index = button_index
	btn_event.device = -1
	InputMap.action_add_event(action_name, btn_event)

func _add_joy_motion(action_name: String, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.axis == axis and signf(event.axis_value) == signf(axis_value):
			return
	var motion_event = InputEventJoypadMotion.new()
	motion_event.axis = axis
	motion_event.axis_value = axis_value
	motion_event.device = -1
	InputMap.action_add_event(action_name, motion_event)

func _add_joy_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var key_event = InputEventKey.new()
	key_event.physical_keycode = keycode
	key_event.device = -1
	InputMap.action_add_event(action_name, key_event)

# --- Floating Damage Numbers ---
func spawn_damage_number(world_pos: Vector2, amount: int, is_crit: bool = false) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var holder = Node2D.new()
	holder.global_position = world_pos + Vector2(randf_range(-6.0, 6.0), -6.0)
	holder.z_index = 100
	scene.add_child(holder)
	
	var label = Label.new()
	label.text = "%d" % amount
	if is_crit:
		label.text = "%d!" % amount
	
	if _font:
		label.add_theme_font_override("font", _font)
	
	var font_size = 11 if is_crit else 8
	label.add_theme_font_size_override("font_size", font_size)
	
	var text_color = Color(1.0, 0.45, 0.1, 1.0) if is_crit else Color(1.0, 0.9, 0.3, 1.0)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	
	label.position = Vector2(-15.0, -8.0)
	label.size = Vector2(30.0, 16.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(label)
	
	holder.scale = Vector2(0.4, 0.4)
	var end_y = holder.position.y - randf_range(16.0, 24.0)
	var end_x = holder.position.x + randf_range(-8.0, 8.0)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(holder, "scale", Vector2(1.25 if is_crit else 0.95, 1.25 if is_crit else 0.95), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(holder, "position:y", end_y, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(holder, "position:x", end_x, 0.55)
	
	var fade_t = create_tween()
	fade_t.tween_interval(0.35)
	fade_t.tween_property(holder, "modulate:a", 0.0, 0.2)
	fade_t.tween_callback(holder.queue_free)

# --- Particle Spawners (CPUParticles2D) ---
func spawn_impact_sparks(world_pos: Vector2, dir: Vector2 = Vector2.UP, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var p = CPUParticles2D.new()
	p.top_level = true
	p.global_position = world_pos
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 12
	p.lifetime = 0.28
	
	var angle_rad = dir.angle() if dir != Vector2.ZERO else -PI * 0.5
	p.direction = Vector2(cos(angle_rad), sin(angle_rad))
	p.spread = 65.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 300.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = color
	
	scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func spawn_dust_puff(world_pos: Vector2, count: int = 6, color: Color = Color(0.9, 0.9, 0.9, 0.6)) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var p = CPUParticles2D.new()
	p.top_level = true
	p.global_position = world_pos
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = 0.35
	p.direction = Vector2(0, -1.0)
	p.spread = 75.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, 50.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	
	scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func spawn_death_burst(world_pos: Vector2, color: Color = Color(1.0, 0.3, 0.3)) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var p = CPUParticles2D.new()
	p.top_level = true
	p.global_position = world_pos
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.98
	p.amount = 22
	p.lifetime = 0.45
	p.direction = Vector2(0, -0.5)
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 240.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	
	scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func spawn_shockwave(world_pos: Vector2, color: Color = Color(0.3, 1.0, 0.6, 0.9)) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	var ring = ShockwaveRing.new()
	ring.global_position = world_pos
	ring.z_index = 90
	ring.ring_color = color
	scene.add_child(ring)
	
	var t = create_tween().set_parallel(true)
	t.tween_method(func(val: float):
		ring.radius = val
		ring.queue_redraw()
	, 3.0, 36.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	t.tween_method(func(val: float):
		ring.ring_color.a = color.a * val
		ring.queue_redraw()
	, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	t.chain().tween_callback(ring.queue_free)

# --- Internal Setup: WorldEnvironment & Post-Processing ---
func _setup_environment() -> void:
	if _world_env:
		return
	_world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	
	# Forward+ 2D Glow / Bloom
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	
	_world_env.environment = env
	add_child(_world_env)

func _setup_post_processing() -> void:
	if _post_layer:
		return
	_post_layer = CanvasLayer.new()
	_post_layer.layer = 85
	add_child(_post_layer)
	
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = load("res://shaders/post_process.gdshader") as Shader
	if shader:
		_post_mat = ShaderMaterial.new()
		_post_mat.shader = shader
		_post_mat.set_shader_parameter("vignette_intensity", 0.35)
		_post_mat.set_shader_parameter("vignette_opacity", 0.28)
		_post_mat.set_shader_parameter("aberration_amount", 0.0)
		_post_mat.set_shader_parameter("flash_color", Color(0, 0, 0, 0))
		_post_rect.material = _post_mat
	
	_post_layer.add_child(_post_rect)
