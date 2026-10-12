extends Area2D

signal reached

var is_reached: bool = false
var time_passed: float = 0.0

@onready var ring1: Polygon2D = $Ring1
@onready var ring2: Polygon2D = $Ring2
@onready var core: Polygon2D = $Core

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time_passed += delta
	if ring1:
		ring1.rotation += delta * 1.5
	if ring2:
		ring2.rotation -= delta * 2.2
	if core:
		var s = 1.0 + sin(time_passed * 4.0) * 0.15
		core.scale = Vector2(s, s)

func _on_body_entered(body: Node2D) -> void:
	if is_reached or not (body is Player):
		return
	is_reached = true
	reached.emit()
	
	# Epic victory flare
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", Vector2(2.5, 2.5), 0.5)
	tween.tween_property(core, "color", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	tween.tween_property(ring1, "scale", Vector2(2.0, 2.0), 0.5)
