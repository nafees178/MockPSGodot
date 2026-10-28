@tool
class_name LevelBackground
extends CanvasLayer

enum LevelTheme {
	GRASSLAND = 0,
	AUTUMN = 1,
	WINTER = 2
}

class BgLayer:
	var texture: Texture2D
	var scroll_speed: float # auto-scroll speed (px/sec)
	var parallax_weight: float # horizontal camera parallax factor (0.0 to 1.0)
	var current_scroll: float = 0.0
	var modulate_tint: Color = Color.WHITE

class WeatherParticle:
	var pos: Vector2
	var vel: Vector2
	var size: float
	var alpha: float
	var angle: float = 0.0
	var rot_speed: float = 0.0
	var sway_phase: float = 0.0
	var sway_freq: float = 1.0
	var sway_amp: float = 15.0
	var color: Color = Color.WHITE

@export var theme: LevelTheme = LevelTheme.GRASSLAND:
	set(val):
		theme = val
		_load_theme_layers()
		_init_particles()
		if canvas:
			canvas.queue_redraw()

@export var vertical_offset: float = 0.0:
	set(val):
		vertical_offset = val
		if canvas:
			canvas.queue_redraw()

@export var enable_particles: bool = true
@export var enable_autoscroll: bool = true
@export var parallax_intensity: float = 1.0

var layers: Array[BgLayer] = []
var weather_particles: Array[WeatherParticle] = []
var time_elapsed: float = 0.0

var canvas: Control = null

# Camera Tracking State
var start_cam_pos: Vector2 = Vector2.ZERO
var smoothed_cam_pos: Vector2 = Vector2.ZERO
var start_pos_initialized: bool = false
var last_frame_cam_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	layer = -100

func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Auto-detect theme based on scene name if still default
	if not Engine.is_editor_hint():
		_auto_detect_theme()
	
	_setup_canvas()
	_load_theme_layers()
	_init_particles()

func _auto_detect_theme() -> void:
	var scene_name = ""
	if get_tree() and get_tree().current_scene:
		scene_name = get_tree().current_scene.name.to_lower()
	elif get_parent():
		scene_name = get_parent().name.to_lower()
		
	if "level 2" in scene_name or "level_2" in scene_name or "level2" in scene_name or "autumn" in scene_name:
		theme = LevelTheme.AUTUMN
	elif "level 3" in scene_name or "level_3" in scene_name or "level3" in scene_name or "winter" in scene_name or "frost" in scene_name:
		theme = LevelTheme.WINTER
	elif "level 1" in scene_name or "level_1" in scene_name or "level1" in scene_name or "grass" in scene_name:
		theme = LevelTheme.GRASSLAND

func _setup_canvas() -> void:
	canvas = get_node_or_null("BackgroundCanvas") as Control
	if canvas == null:
		canvas = Control.new()
		canvas.name = "BackgroundCanvas"
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(canvas)
	else:
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	if not canvas.draw.is_connected(_on_canvas_draw):
		canvas.draw.connect(_on_canvas_draw)

func _load_theme_layers() -> void:
	layers.clear()
	match theme:
		LevelTheme.GRASSLAND:
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/5 - Sky_color.png", 0.0, 0.0)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/4 - Cloud_cover_2.png", 3.5, 0.04, Color(1, 1, 1, 0.88))
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/3 - Cloud_cover_1.png", 7.5, 0.08, Color(1, 1, 1, 0.96))
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/2 - Hills.png", 1.8, 0.20)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/1 - Foreground_scenery.png", 0.0, 0.38)
			
		LevelTheme.AUTUMN:
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/6 - Distant_trees.png", 1.0, 0.06)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/5 - Tree_row_BG_2.png", 1.8, 0.14)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/4 - Tree_row_BG_1.png", 2.8, 0.24)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/2 - Trees.png", 4.0, 0.38)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/1 - Leaf_top.png", 0.8, 0.12)
			
		LevelTheme.WINTER:
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Background parts/3 - Big_mountain_BG.png", 0.8, 0.07)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Background parts/2 - Smaller_mountains.png", 2.2, 0.20)
			_add_layer("res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Background parts/1 - Snowy_foreground_area.png", 0.0, 0.40)

func _add_layer(path: String, speed: float, parallax: float, tint: Color = Color.WHITE) -> void:
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex:
			var l = BgLayer.new()
			l.texture = tex
			l.scroll_speed = speed
			l.parallax_weight = parallax * parallax_intensity
			l.modulate_tint = tint
			layers.append(l)

func _init_particles() -> void:
	weather_particles.clear()
	var rng = RandomNumberGenerator.new()
	var count = 45
	for i in range(count):
		var p = WeatherParticle.new()
		_spawn_particle(p, rng, true)
		weather_particles.append(p)

func _spawn_particle(p: WeatherParticle, rng: RandomNumberGenerator, initial: bool) -> void:
	var viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	var w = viewport_size.x if viewport_size.x > 0 else 1280.0
	var h = viewport_size.y if viewport_size.y > 0 else 720.0
	
	p.sway_phase = rng.randf_range(0, TAU)
	p.sway_freq = rng.randf_range(1.0, 2.5)
	
	match theme:
		LevelTheme.GRASSLAND:
			# Dandelion seed / floating pollen
			p.pos = Vector2(rng.randf_range(0, w), rng.randf_range(0, h) if initial else h + 15.0)
			p.vel = Vector2(rng.randf_range(12.0, 28.0), -rng.randf_range(18.0, 38.0))
			p.size = rng.randf_range(2.0, 3.8)
			p.alpha = rng.randf_range(0.35, 0.75)
			p.color = Color(0.95, 0.98, 0.82, p.alpha)
			p.sway_amp = rng.randf_range(12.0, 22.0)
			
		LevelTheme.AUTUMN:
			# Falling autumn leaves drifting and rotating
			p.pos = Vector2(rng.randf_range(-40, w + 40), rng.randf_range(0, h) if initial else -20.0)
			p.vel = Vector2(rng.randf_range(-15.0, 25.0), rng.randf_range(35.0, 75.0))
			p.size = rng.randf_range(3.5, 6.5)
			p.alpha = rng.randf_range(0.55, 0.9)
			p.angle = rng.randf_range(0, TAU)
			p.rot_speed = rng.randf_range(-2.5, 2.5)
			p.sway_amp = rng.randf_range(20.0, 45.0)
			
			var leaf_pal = [
				Color(0.88, 0.35, 0.18), # rich red
				Color(0.95, 0.56, 0.16), # bright orange
				Color(0.96, 0.78, 0.22), # golden amber
				Color(0.72, 0.24, 0.16)  # deep burgundy
			]
			p.color = leaf_pal[rng.randi_range(0, leaf_pal.size() - 1)]
			p.color.a = p.alpha
			
		LevelTheme.WINTER:
			# Snowflakes softly fluttering down
			p.pos = Vector2(rng.randf_range(-20, w + 20), rng.randf_range(0, h) if initial else -15.0)
			p.vel = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(30.0, 65.0))
			p.size = rng.randf_range(1.8, 4.2)
			p.alpha = rng.randf_range(0.45, 0.85)
			p.color = Color(0.92, 0.96, 1.0, p.alpha)
			p.sway_amp = rng.randf_range(10.0, 24.0)

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Update active camera tracking
	if not Engine.is_editor_hint():
		var cam = get_viewport().get_camera_2d()
		if cam != null:
			var cur_pos = cam.get_screen_center_position()
			if not start_pos_initialized:
				start_cam_pos = cur_pos
				smoothed_cam_pos = cur_pos
				last_frame_cam_pos = cur_pos
				start_pos_initialized = true
			else:
				# Teleport / respawn detection: if player respawned, jump camera instantly
				if (cur_pos - last_frame_cam_pos).length() > 250.0:
					smoothed_cam_pos = cur_pos
				else:
					smoothed_cam_pos = smoothed_cam_pos.lerp(cur_pos, clampf(delta * 24.0, 0.0, 1.0))
				last_frame_cam_pos = cur_pos
	
	# Update layer auto-scroll
	if enable_autoscroll:
		for l in layers:
			l.current_scroll += l.scroll_speed * delta
	
	# Update weather particles
	if enable_particles:
		var viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
		var w = viewport_size.x if viewport_size.x > 0 else 1280.0
		var h = viewport_size.y if viewport_size.y > 0 else 720.0
		var rng = RandomNumberGenerator.new()
		
		for p in weather_particles:
			p.pos.y += p.vel.y * delta
			p.pos.x += (p.vel.x + sin(time_elapsed * p.sway_freq + p.sway_phase) * p.sway_amp) * delta
			p.angle += p.rot_speed * delta
			
			var is_out = false
			if theme == LevelTheme.GRASSLAND:
				if p.pos.y < -20.0 or p.pos.x > w + 40.0:
					is_out = true
			else:
				if p.pos.y > h + 25.0 or p.pos.x < -40.0 or p.pos.x > w + 40.0:
					is_out = true
			
			if is_out:
				_spawn_particle(p, rng, false)
	
	if canvas:
		canvas.queue_redraw()

func _on_canvas_draw() -> void:
	if canvas == null:
		return
	var viewport_size = canvas.get_viewport_rect().size
	var w = viewport_size.x if viewport_size.x > 0 else 1280.0
	var h = viewport_size.y if viewport_size.y > 0 else 720.0
	
	# 1. Base Atmospheric Sky Gradient (exact palette from main menu)
	_draw_sky_backdrop(w, h)
	
	# 2. Render pixel-art parallax layers
	var native_w = 288.0
	var native_h = 208.0
	
	# Height scaling and vertical anchoring:
	# Grassland (Level 1) is scaled and pushed up so the hills and trees rise behind the surface platform
	var theme_y_offset = 0.0
	var height_mult = 1.15
	if theme == LevelTheme.GRASSLAND:
		height_mult = 1.55
		theme_y_offset = -170.0
		
	var scale_factor = (h / native_h) * height_mult
	var scaled_w = native_w * scale_factor
	var scaled_h = native_h * scale_factor
	
	# Base Y positioning ensuring 100% vertical screen coverage
	var base_y = -(scaled_h - h) * 0.5 + theme_y_offset + vertical_offset
	
	var cam_delta = smoothed_cam_pos - start_cam_pos
	var cam_zoom = 2.5
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam_zoom = cam.zoom.x
	
	for l in layers:
		if l.texture == null:
			continue
		
		# Horizontal camera parallax + auto-scroll
		var cam_shift_x = cam_delta.x * cam_zoom * l.parallax_weight
		var total_offset_x = l.current_scroll - cam_shift_x
		
		var wrap_x = fmod(total_offset_x, scaled_w)
		if wrap_x > 0.0:
			wrap_x -= scaled_w
		
		# Vertical parallax: subtle depth shift, clamped within vertical headroom buffer
		var vert_shift = -cam_delta.y * cam_zoom * (l.parallax_weight * 0.08)
		var min_draw_y = -(scaled_h - h)
		var max_draw_y = 0.0
		var draw_y = clampf(base_y + vert_shift, min_draw_y, max_draw_y)
		
		var draw_x = wrap_x
		var col = l.modulate_tint
		
		while draw_x < w + scaled_w:
			canvas.draw_texture_rect(l.texture, Rect2(draw_x, draw_y, scaled_w, scaled_h), false, col)
			draw_x += scaled_w
	
	# 3. Weather Particles
	if enable_particles:
		_draw_particles()
	
	# 4. Subtle ambient tint to harmonize palette with foreground tiles
	canvas.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.04, 0.08, 0.16))

func _draw_sky_backdrop(w: float, h: float) -> void:
	match theme:
		LevelTheme.GRASSLAND:
			# Vibrant blue morning sky into soft horizon haze
			var colors = PackedColorArray([
				Color(0.24, 0.58, 0.88, 1.0),
				Color(0.24, 0.58, 0.88, 1.0),
				Color(0.68, 0.88, 0.96, 1.0),
				Color(0.68, 0.88, 0.96, 1.0)
			])
			var points = PackedVector2Array([
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
			])
			canvas.draw_polygon(points, colors)
			
		LevelTheme.AUTUMN:
			# Deep twilight purple into vibrant amber-coral sunset
			var colors = PackedColorArray([
				Color(0.20, 0.12, 0.22, 1.0),
				Color(0.20, 0.12, 0.22, 1.0),
				Color(0.92, 0.54, 0.26, 1.0),
				Color(0.92, 0.54, 0.26, 1.0)
			])
			var points = PackedVector2Array([
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
			])
			canvas.draw_polygon(points, colors)
			
		LevelTheme.WINTER:
			# Midnight navy into frosty alpine steel-blue
			var colors = PackedColorArray([
				Color(0.06, 0.10, 0.18, 1.0),
				Color(0.06, 0.10, 0.18, 1.0),
				Color(0.26, 0.44, 0.62, 1.0),
				Color(0.26, 0.44, 0.62, 1.0)
			])
			var points = PackedVector2Array([
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
			])
			canvas.draw_polygon(points, colors)

func _draw_particles() -> void:
	for p in weather_particles:
		var pt = p.pos
		if theme == LevelTheme.AUTUMN:
			# Rotating diamond leaf
			var rad = p.size
			var pts = PackedVector2Array([
				pt + Vector2(0, -rad * 1.3).rotated(p.angle),
				pt + Vector2(rad * 0.7, 0).rotated(p.angle),
				pt + Vector2(0, rad * 1.3).rotated(p.angle),
				pt + Vector2(-rad * 0.7, 0).rotated(p.angle)
			])
			canvas.draw_colored_polygon(pts, p.color)
		else:
			# Circular particle (snowflake or dandelion mote)
			canvas.draw_circle(pt, p.size, p.color)
