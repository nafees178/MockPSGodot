class_name LevelExit
extends Area2D

signal exit_reached

@export var next_scene_path: String = "res://Level_2.tscn"
var is_triggered: bool = false

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var aura: Polygon2D = get_node_or_null("Aura")

var time_passed: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	if prompt_label:
		if next_scene_path == "res://main_menu.tscn":
			prompt_label.text = "MISSION COMPLETE"
		elif "3" in next_scene_path:
			prompt_label.text = "LEVEL 2 EXIT"
		elif "2" in next_scene_path:
			prompt_label.text = "LEVEL 1 EXIT"

func _process(delta: float) -> void:
	time_passed += delta
	if aura:
		var s = 1.0 + sin(time_passed * 3.5) * 0.12
		aura.scale = Vector2(s, s)
		aura.rotation += delta * 0.8

func _on_body_entered(body: Node2D) -> void:
	if is_triggered or not (body is Player):
		return
	is_triggered = true
	exit_reached.emit()
	
	# Disable player controls
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO
		body.set_physics_process(false)
	
	# Audio feedback
	var sfx = load("res://audio/sfx_shieldUp.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.volume_db = -2.0
		add_child(asp)
		asp.play()
	
	_trigger_transition()

func _trigger_transition() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 150
	add_child(canvas)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0.06, 0.08, 0.12, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	canvas.add_child(overlay)
	
	var font = load("res://audio/kenvector_future.ttf") as Font
	
	var label = Label.new()
	var current_scene = get_tree().current_scene
	var sname = current_scene.name if current_scene else ""
	var is_lvl3 = "3" in sname or "Level3" in sname or next_scene_path == "res://main_menu.tscn"
	var is_lvl2 = ("2" in sname or "Level2" in sname or "Level_2" in sname) and not is_lvl3
	
	if is_lvl3:
		label.text = "LEVEL 3 CLEARED!\nALL MISSIONS COMPLETE - VICTORY!"
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	elif is_lvl2:
		label.text = "LEVEL 2 CLEARED!\nENTERING LEVEL 3..."
		label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3, 1.0))
	else:
		label.text = "LEVEL 1 CLEARED!\nENTERING LEVEL 2..."
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6, 1.0))
		
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.modulate.a = 0.0
	canvas.add_child(label)
	
	var t = create_tween()
	t.parallel().tween_property(overlay, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(label, "modulate:a", 1.0, 0.6)
	t.tween_interval(1.5)
	t.chain().tween_callback(func():
		get_tree().change_scene_to_file(next_scene_path)
	)
