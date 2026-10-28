class_name SignboardCheckpoint
extends Area2D

signal activated(pos: Vector2)

var is_active: bool = false

@onready var label: Label = $Label
@onready var glow: Polygon2D = get_node_or_null("Glow")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	if label:
		label.modulate.a = 0.0
	if glow:
		glow.modulate.a = 0.0

func _on_body_entered(body: Node2D) -> void:
	if is_active or not (body is Player):
		return
	is_active = true
	
	# Set player respawn point
	if body.has_method("set_checkpoint"):
		body.set_checkpoint(global_position + Vector2(0, -6))
	activated.emit(global_position)
	
	# Checkpoint Juice: Shockwave, Camera Shake, Sparkles
	JuiceManager.spawn_shockwave(global_position + Vector2(0, -6), Color(0.25, 1.0, 0.65))
	JuiceManager.spawn_impact_sparks(global_position + Vector2(0, -10), Vector2.UP, Color(0.4, 1.0, 0.7))
	JuiceManager.add_trauma(0.2)
	
	# Squash & Stretch bounce on signboard
	var st = create_tween()
	st.tween_property(self, "scale", Vector2(1.28, 0.76), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	st.tween_property(self, "scale", Vector2(0.92, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Layered harmonic audio chime
	var sfx_stream = load("res://audio/sfx_twoTone.ogg") as AudioStream
	if sfx_stream:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx_stream
		asp.volume_db = -4.0
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	var sfx_chime = load("res://audio/sfx_shieldUp.ogg") as AudioStream
	if sfx_chime:
		var asp2 = AudioStreamPlayer2D.new()
		asp2.stream = sfx_chime
		asp2.volume_db = -6.0
		asp2.pitch_scale = 1.3
		add_child(asp2)
		asp2.play()
		asp2.finished.connect(asp2.queue_free)
	
	# Visual activation
	if glow:
		var gt = create_tween()
		gt.tween_property(glow, "modulate", Color(1.5, 2.0, 1.5, 0.95), 0.15)
		gt.tween_property(glow, "modulate", Color(0.5, 1.0, 0.6, 0.4), 0.5)
	
	if label:
		label.text = "CHECKPOINT SAVED!"
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.1, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(label, "position:y", -48.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.2)
		tween.tween_property(label, "modulate:a", 0.0, 0.3)
