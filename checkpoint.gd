extends Area2D

signal activated(pos: Vector2)

var is_active: bool = false

@onready var pole: ColorRect = $Pole
@onready var lamp: Polygon2D = $Lamp
@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if label:
		label.modulate.a = 0.0

func _on_body_entered(body: Node2D) -> void:
	if is_active or not (body is Player):
		return
	is_active = true
	if body.has_method("set_checkpoint"):
		body.set_checkpoint(global_position + Vector2(0, -10))
	activated.emit(global_position)
	
	# Checkpoint Juice: Shockwave, Camera Shake, Sparkles
	JuiceManager.spawn_shockwave(global_position + Vector2(0, -10), Color(0.25, 1.0, 0.65))
	JuiceManager.spawn_impact_sparks(global_position + Vector2(0, -14), Vector2.UP, Color(0.4, 1.0, 0.7))
	JuiceManager.add_trauma(0.2)
	
	# Squash & Stretch bounce on pole
	var st = create_tween()
	st.tween_property(self, "scale", Vector2(1.22, 0.8), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	st.tween_property(self, "scale", Vector2(0.94, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Audio chime
	var sfx = load("res://audio/sfx_twoTone.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.volume_db = -4.0
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	# Visual activation
	if lamp:
		lamp.color = Color(0.3, 1.8, 0.8, 1.0) # High energy glow
	
	if label:
		label.text = "CHECKPOINT SAVED!"
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.1, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(label, "position:y", -72.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.2)
		tween.tween_property(label, "modulate:a", 0.0, 0.3)
