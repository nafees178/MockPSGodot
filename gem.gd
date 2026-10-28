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
	
	# Gem Juice: Sparkles, Chime, Pop
	JuiceManager.spawn_impact_sparks(global_position, Vector2.UP, Color(0.3, 0.9, 1.0))
	var sfx = load("res://audio/sfx_twoTone.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.pitch_scale = randf_range(1.4, 1.6)
		asp.volume_db = -8.0
		get_parent().add_child(asp)
		asp.global_position = global_position
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	# Pickup pop animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(1.8, 1.8), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate", Color(2.0, 2.5, 3.0, 0.0), 0.18)
	tween.chain().tween_callback(queue_free)
