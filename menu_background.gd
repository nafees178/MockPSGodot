class_name MenuBackground
extends Control

# Clean, modern dark aesthetic background with subtle layered shapes and ambient particles
var scroll_offset: float = 0.0
var time_elapsed: float = 0.0

class AmbientMote:
	var pos: Vector2
	var speed: float
	var size: float
	var alpha: float

var particles: Array[AmbientMote] = []
var mouse_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	
	var rng = RandomNumberGenerator.new()
	for i in range(45):
		var p = AmbientMote.new()
		p.pos = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		p.speed = rng.randf_range(15.0, 45.0)
		p.size = rng.randf_range(1.5, 3.0)
		p.alpha = rng.randf_range(0.15, 0.4)
		particles.append(p)

func _process(delta: float) -> void:
	time_elapsed += delta
	scroll_offset += delta * 20.0
	
	# Gentle mouse parallax
	var mouse_pos = get_viewport().get_mouse_position()
	var center = size * 0.5
	if size.x > 0 and size.y > 0:
		var target_offset = (mouse_pos - center) * 0.02
		mouse_offset = mouse_offset.lerp(target_offset, delta * 3.0)
	
	for p in particles:
		p.pos.y -= p.speed * delta
		p.pos.x += sin(time_elapsed * 0.8 + p.speed) * 8.0 * delta
		if p.pos.y < -10:
			p.pos.y = size.y + 10
			p.pos.x = randf_range(0, max(size.x, 1280))
	
	queue_redraw()

func _draw() -> void:
	var w = size.x if size.x > 0 else 1280.0
	var h = size.y if size.y > 0 else 720.0
	
	# 1. Base Dark Slate Gradient
	var bg_color = Color(0.10, 0.12, 0.16, 1.0)
	draw_rect(Rect2(0, 0, w, h), bg_color)
	
	# 2. Subtle architectural background panels (matching the platformer look)
	var panels = [
		{"x": 80.0, "w": 220.0, "h": 500.0, "col": Color(0.13, 0.15, 0.20)},
		{"x": 340.0, "w": 180.0, "h": 420.0, "col": Color(0.12, 0.14, 0.19)},
		{"x": 580.0, "w": 260.0, "h": 540.0, "col": Color(0.14, 0.16, 0.21)},
		{"x": 880.0, "w": 340.0, "h": 480.0, "col": Color(0.13, 0.15, 0.20)}
	]
	
	for p in panels:
		var px = p.x - mouse_offset.x * 0.4
		var ph = p.h
		var py = h - ph
		draw_rect(Rect2(px, py, p.w, ph), p.col)
		# Subtle muted border highlight
		draw_line(Vector2(px, py), Vector2(px + p.w, py), Color(0.22, 0.26, 0.34, 0.4), 1.0)
		draw_line(Vector2(px, py), Vector2(px, h), Color(0.22, 0.26, 0.34, 0.2), 1.0)
	
	# 3. Soft ambient grid / floor guide lines (low opacity, clean slate)
	var floor_y = h * 0.78
	draw_line(Vector2(0, floor_y), Vector2(w, floor_y), Color(0.22, 0.27, 0.35, 0.4), 1.5)
	
	var grid_step = 60.0
	var gx = 0.0
	while gx < w:
		draw_line(Vector2(gx, floor_y), Vector2(gx, h), Color(0.18, 0.22, 0.28, 0.3), 1.0)
		gx += grid_step
	
	# 4. Subtle ambient motes
	for p in particles:
		var pt = p.pos - mouse_offset * 0.2
		draw_circle(pt, p.size, Color(0.75, 0.82, 0.92, p.alpha))
