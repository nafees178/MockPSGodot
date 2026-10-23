extends Area2D

# Movement speed (pixels per second)
@export var speed: float = 200.0

# Direction: -1 moves LEFT (towards player from front), 1 moves RIGHT
@export var direction: float = -1.0

# Rotation speed for visual spinning effect
@export var rotation_speed: float = 10.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready() -> void:
	# Automatically connect the screen_exited signal
	notifier.screen_exited.connect(_on_screen_exited)
	
	# Connect collision with player/bodies
	body_entered.connect(_on_body_entered)
	
	# Start playing sprite animation if set
	if animated_sprite.sprite_frames:
		animated_sprite.play("default")

func _process(delta: float) -> void:
	# Move horizontally
	position.x += speed * direction * delta
	
	# Spin the saw blade visually
	animated_sprite.rotation += rotation_speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Check if the body hit is the player
	if body.is_in_group("player") or body.has_method("die") or body.has_method("take_damage"):
		if body.has_method("take_damage"):
			body.take_damage()
		elif body.has_method("die"):
			body.die()

func _on_screen_exited() -> void:
	# Delete the saw automatically once it goes off-screen
	queue_free()
	
