extends Area2D

signal collected(value: int)

@export var value: int = 1
var is_collected: bool = false
var start_y: float = 0.0
var time_passed: float = 0.0

@onready var visual: Node2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	start_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not is_collected:
		time_passed += delta * 3.0
		if visual:
			visual.position.y = sin(time_passed) * 4.0

func _on_body_entered(body: Node2D) -> void:
	if is_collected or not (body is Player):
		return
	is_collected = true
	collected.emit(value)
	
	# Pickup pop animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(1.6, 1.6), 0.2)
	tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
