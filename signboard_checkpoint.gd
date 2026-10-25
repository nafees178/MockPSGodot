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
	
	# Audio feedback
	var sfx_stream = load("res://audio/sfx_twoTone.ogg") as AudioStream
	if sfx_stream:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx_stream
		asp.volume_db = -6.0
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	# Visual activation
	if glow:
		var gt = create_tween()
		gt.tween_property(glow, "modulate:a", 0.9, 0.2)
		gt.tween_property(glow, "modulate:a", 0.35, 0.5)
	
	if label:
		label.text = "CHECKPOINT!"
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.2)
		tween.tween_property(label, "position:y", -45.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.2)
		tween.tween_property(label, "modulate:a", 0.0, 0.3)
