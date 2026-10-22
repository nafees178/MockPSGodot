

extends Node2D

## Time in seconds it takes for the platform to move from one side to the other
@export var duration: float = 2.0

@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D

func _ready() -> void:
	start_platform_movement()

func start_platform_movement() -> void:
	# Create a tween that loops infinitely
	var tween: Tween = create_tween().set_loops()
	
	# Ease in and out smoothly using a sine curve
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Move forward along the path (0.0 to 1.0)
	tween.tween_property(path_follow, "progress_ratio", 1.0, duration)
	
	# Move backward along the path (1.0 back to 0.0)
	tween.tween_property(path_follow, "progress_ratio", 0.0, duration)
