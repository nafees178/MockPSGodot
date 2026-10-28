class_name MenuBackground
extends Control

enum LevelTheme {
	GRASSLAND = 0,
	AUTUMN = 1,
	WINTER = 2
}

class BgLayer:
	var texture: Texture2D
	var scroll_speed: float # auto-scroll speed (px/sec)
	var parallax_weight: float # mouse responsiveness (0.0 to 1.0)
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

var current_theme: int = LevelTheme.GRASSLAND
var previous_theme: int = LevelTheme.GRASSLAND
var is_crossfading: bool = false
var crossfade_progress: float = 1.0

# Textures and layers per theme
var theme_layers: Dictionary = {}
var weather_particles: Array[WeatherParticle] = []

var time_elapsed: float = 0.0
var mouse_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_load_theme_layers()
	_init_particles()

func _load_theme_layers() -> void:
	# 1. Grassland Theme
	var g_layers: Array[BgLayer] = []
	_add_layer(g_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/5 - Sky_color.png", 0.0, 0.0)
	_add_layer(g_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/4 - Cloud_cover_2.png", 4.0, 0.08, Color(1, 1, 1, 0.85))
	_add_layer(g_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/3 - Cloud_cover_1.png", 8.5, 0.16, Color(1, 1, 1, 0.95))
	_add_layer(g_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/2 - Hills.png", 1.8, 0.30)
	_add_layer(g_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/1 - Foreground_scenery.png", 3.2, 0.50)
	theme_layers[LevelTheme.GRASSLAND] = g_layers

	# 2. Autumn Forest Theme
	var a_layers: Array[BgLayer] = []
	_add_layer(a_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/6 - Distant_trees.png", 1.2, 0.12)
	_add_layer(a_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/5 - Tree_row_BG_2.png", 2.2, 0.22)
	_add_layer(a_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/4 - Tree_row_BG_1.png", 3.5, 0.35)
	_add_layer(a_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/2 - Trees.png", 5.0, 0.50)
	_add_layer(a_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/1 - Leaf_top.png", 0.8, 0.15)
	theme_layers[LevelTheme.AUTUMN] = a_layers

	# 3. Winter World Theme
	var w_layers: Array[BgLayer] = []
	_add_layer(w_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Background parts/3 - Big_mountain_BG.png", 1.0, 0.12)
	_add_layer(w_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Background parts/2 - Smaller_mountains.png", 2.6, 0.30)
	_add_layer(w_layers, "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Background parts/1 - Snowy_foreground_area.png", 4.8, 0.52)
	theme_layers[LevelTheme.WINTER] = w_layers

func _add_layer(arr: Array[BgLayer], path: String, speed: float, parallax: float, tint: Color = Color.WHITE) -> void:
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex:
			var l = BgLayer.new()
			l.texture = tex
			l.scroll_speed = speed
			l.parallax_weight = parallax
			l.modulate_tint = tint
			arr.append(l)

func _init_particles() -> void:
	weather_particles.clear()
	var rng = RandomNumberGenerator.new()
	var count = 50
	for i in range(count):
		var p = WeatherParticle.new()
		_spawn_particle(p, rng, true)
		weather_particles.append(p)

func _spawn_particle(p: WeatherParticle, rng: RandomNumberGenerator, initial: bool) -> void:
	var w = size.x if size.x > 0 else 1280.0
	var h = size.y if size.y > 0 else 720.0
	
	p.sway_phase = rng.randf_range(0, TAU)
	p.sway_freq = rng.randf_range(1.0, 2.5)
	
	match current_theme:
		LevelTheme.GRASSLAND:
			# Dandelion seed / pollen: floats slowly up and right
			p.pos = Vector2(rng.randf_range(0, w), rng.randf_range(0, h) if initial else h + 15.0)
			p.vel = Vector2(rng.randf_range(12.0, 30.0), -rng.randf_range(18.0, 42.0))
			p.size = rng.randf_range(2.0, 3.8)
			p.alpha = rng.randf_range(0.3, 0.7)
			p.color = Color(0.95, 0.98, 0.82, p.alpha)
			p.sway_amp = rng.randf_range(12.0, 24.0)
			
		LevelTheme.AUTUMN:
			# Falling leaves: drift down and sway
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
			# Snowflakes: flutter softly down
			p.pos = Vector2(rng.randf_range(-20, w + 20), rng.randf_range(0, h) if initial else -15.0)
			p.vel = Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(30.0, 65.0))
			p.size = rng.randf_range(1.8, 4.2)
			p.alpha = rng.randf_range(0.45, 0.85)
			p.color = Color(0.92, 0.96, 1.0, p.alpha)
			p.sway_amp = rng.randf_range(10.0, 25.0)

func set_level_theme(theme_idx: int) -> void:
	if theme_idx == current_theme:
		return
	previous_theme = current_theme
	current_theme = theme_idx
	is_crossfading = true
	crossfade_progress = 0.0
	
	var t = create_tween()
	t.tween_property(self, "crossfade_progress", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(func():
		is_crossfading = false
	)
	
	# Re-seed particles to match new atmosphere
	var rng = RandomNumberGenerator.new()
	for p in weather_particles:
		_spawn_particle(p, rng, true)

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Gentle mouse parallax smoothing
	var mouse_pos = get_viewport().get_mouse_position()
	var center = size * 0.5
	if size.x > 0 and size.y > 0:
		var target_offset = (mouse_pos - center) * 0.04
		mouse_offset = mouse_offset.lerp(target_offset, delta * 3.5)
	
	# Update scroll on all theme layers
	for t_idx in theme_layers.keys():
		var layers: Array[BgLayer] = theme_layers[t_idx]
		for l in layers:
			l.current_scroll += l.scroll_speed * delta
	
	# Update weather particles
	var w = size.x if size.x > 0 else 1280.0
	var h = size.y if size.y > 0 else 720.0
	var rng = RandomNumberGenerator.new()
	
	for p in weather_particles:
		p.pos.y += p.vel.y * delta
		p.pos.x += (p.vel.x + sin(time_elapsed * p.sway_freq + p.sway_phase) * p.sway_amp) * delta
		p.angle += p.rot_speed * delta
		
		var is_out = false
		if current_theme == LevelTheme.GRASSLAND:
			if p.pos.y < -20.0 or p.pos.x > w + 40.0:
				is_out = true
		else:
			if p.pos.y > h + 25.0 or p.pos.x < -40.0 or p.pos.x > w + 40.0:
				is_out = true
		
		if is_out:
			_spawn_particle(p, rng, false)
	
	queue_redraw()

func _draw() -> void:
	var w = size.x if size.x > 0 else 1280.0
	var h = size.y if size.y > 0 else 720.0
	
	if is_crossfading:
		_draw_theme_view(previous_theme, 1.0 - crossfade_progress, w, h)
		_draw_theme_view(current_theme, crossfade_progress, w, h)
	else:
		_draw_theme_view(current_theme, 1.0, w, h)
	
	# Draw weather particles
	_draw_particles()
	
	# Draw cinematic framing vignette (maintains perfect UI contrast)
	_draw_cinematic_vignette(w, h)

func _draw_theme_view(theme_idx: int, alpha: float, w: float, h: float) -> void:
	if alpha <= 0.001:
		return
	
	# 1. Base Atmospheric Sky Gradient
	_draw_sky_backdrop(theme_idx, alpha, w, h)
	
	# 2. Render pixel-art parallax layers
	var layers: Array[BgLayer] = theme_layers.get(theme_idx, [])
	var native_w = 288.0
	var native_h = 208.0
	var scale_factor = h / native_h
	var scaled_w = native_w * scale_factor
	var scaled_h = h
	
	for l in layers:
		if l.texture == null:
			continue
		
		# Parallax horizontal positioning
		var total_offset = l.current_scroll - mouse_offset.x * l.parallax_weight * 80.0
		var wrap_x = fmod(total_offset, scaled_w)
		if wrap_x > 0.0:
			wrap_x -= scaled_w
		
		var draw_x = wrap_x
		var col = l.modulate_tint
		col.a *= alpha
		
		while draw_x < w + scaled_w:
			draw_texture_rect(l.texture, Rect2(draw_x, 0.0, scaled_w, scaled_h), false, col)
			draw_x += scaled_w

func _draw_sky_backdrop(theme_idx: int, alpha: float, w: float, h: float) -> void:
	match theme_idx:
		LevelTheme.GRASSLAND:
			# Vibrant blue morning sky into soft horizon haze
			var colors = PackedColorArray([
				Color(0.24, 0.58, 0.88, alpha),
				Color(0.24, 0.58, 0.88, alpha),
				Color(0.68, 0.88, 0.96, alpha),
				Color(0.68, 0.88, 0.96, alpha)
			])
			var points = PackedVector2Array([
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
			])
			draw_polygon(points, colors)
			
		LevelTheme.AUTUMN:
			# Deep twilight purple into vibrant amber-coral sunset
			var colors = PackedColorArray([
				Color(0.20, 0.12, 0.22, alpha),
				Color(0.20, 0.12, 0.22, alpha),
				Color(0.92, 0.54, 0.26, alpha),
				Color(0.92, 0.54, 0.26, alpha)
			])
			var points = PackedVector2Array([
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
			])
			draw_polygon(points, colors)
			
		LevelTheme.WINTER:
			# Midnight navy into frosty alpine steel-blue
			var colors = PackedColorArray([
				Color(0.06, 0.10, 0.18, alpha),
				Color(0.06, 0.10, 0.18, alpha),
				Color(0.26, 0.44, 0.62, alpha),
				Color(0.26, 0.44, 0.62, alpha)
			])
			var points = PackedVector2Array([
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
			])
			draw_polygon(points, colors)

func _draw_particles() -> void:
	for p in weather_particles:
		var pt = p.pos - mouse_offset * 0.15
		if current_theme == LevelTheme.AUTUMN:
			# Draw rotating diamond leaf
			var rad = p.size
			var pts = PackedVector2Array([
				pt + Vector2(0, -rad * 1.3).rotated(p.angle),
				pt + Vector2(rad * 0.7, 0).rotated(p.angle),
				pt + Vector2(0, rad * 1.3).rotated(p.angle),
				pt + Vector2(-rad * 0.7, 0).rotated(p.angle)
			])
			draw_colored_polygon(pts, p.color)
		else:
			# Soft circular particle (snowflake or dandelion mote)
			draw_circle(pt, p.size, p.color)

func _draw_cinematic_vignette(w: float, h: float) -> void:
	# 1. Dark side backing on left behind menu buttons for crisp contrast
	var left_w = 400.0
	var left_colors = PackedColorArray([
		Color(0.05, 0.07, 0.10, 0.85),
		Color(0.05, 0.07, 0.10, 0.0),
		Color(0.05, 0.07, 0.10, 0.0),
		Color(0.05, 0.07, 0.10, 0.85)
	])
	var left_points = PackedVector2Array([
		Vector2(0, 0), Vector2(left_w, 0), Vector2(left_w, h), Vector2(0, h)
	])
	draw_polygon(left_points, left_colors)
	
	# 2. Dark top header bar background
	var top_h = 88.0
	var top_colors = PackedColorArray([
		Color(0.04, 0.06, 0.09, 0.82),
		Color(0.04, 0.06, 0.09, 0.82),
		Color(0.04, 0.06, 0.09, 0.0),
		Color(0.04, 0.06, 0.09, 0.0)
	])
	var top_points = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, top_h), Vector2(0, top_h)
	])
	draw_polygon(top_points, top_colors)
	
	# 3. Bottom grounding bar
	var bot_h = 45.0
	var bot_colors = PackedColorArray([
		Color(0.03, 0.04, 0.07, 0.0),
		Color(0.03, 0.04, 0.07, 0.0),
		Color(0.03, 0.04, 0.07, 0.78),
		Color(0.03, 0.04, 0.07, 0.78)
	])
	var bot_points = PackedVector2Array([
		Vector2(0, h - bot_h), Vector2(w, h - bot_h), Vector2(w, h), Vector2(0, h)
	])
	draw_polygon(bot_points, bot_colors)
	
	# 4. Subtle ambient tint across screen to harmonize palette
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.04, 0.08, 0.22))
