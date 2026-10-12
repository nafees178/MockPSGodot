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
	
	# Visual activation
	if lamp:
		lamp.color = Color(0.2, 1.0, 0.6, 1.0)
	
	if label:
		label.text = "CHECKPOINT!"
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 1.0, 0.2)
		tween.tween_property(label, "position:y", -70.0, 0.6)
		tween.tween_interval(1.0)
		tween.tween_property(label, "modulate:a", 0.0, 0.3)
